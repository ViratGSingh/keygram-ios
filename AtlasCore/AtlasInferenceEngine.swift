import Foundation

struct AtlasKVCache {
    var keys: [AtlasFloatTensor] = (0..<AtlasConfiguration.attentionLayerCount).map { _ in .emptyKV() }
    var values: [AtlasFloatTensor] = (0..<AtlasConfiguration.attentionLayerCount).map { _ in .emptyKV() }

    mutating func reset() {
        keys = (0..<AtlasConfiguration.attentionLayerCount).map { _ in .emptyKV() }
        values = (0..<AtlasConfiguration.attentionLayerCount).map { _ in .emptyKV() }
    }
}

struct AtlasInferenceState {
    var positionID: Int64 = 0
    var kvCache = AtlasKVCache()
    var glaState = AtlasGLAState.empty()
}

struct AtlasModelStepInput {
    var tokenID: Int64
    var positionID: Int64
    var kvCache: AtlasKVCache
    var glaState: AtlasGLAState
}

struct AtlasModelStepOutput {
    var logits: [Float]
    var kvCache: AtlasKVCache
    var glaState: AtlasGLAState
}

protocol AtlasModelRuntime {
    func step(_ input: AtlasModelStepInput) throws -> AtlasModelStepOutput
}

struct AtlasSuggestion: Identifiable, Equatable {
    var id: String { text }
    var text: String
    var kind: AtlasSuggestionKind
    var score: Double
}

enum AtlasSuggestionKind: String {
    case nextWord
    case completion
    case correction
    case personal
    case undoAutocorrection
}

final class AtlasInferenceEngine {
    private var state = AtlasInferenceState()
    private let tokenizer: AtlasTokenizing
    private let vocabulary: AtlasVocabularyIndex
    private let ranker = AtlasSuggestionRanker()
    private let modelBundle: AtlasModelBundle?
    private let runtime: AtlasModelRuntime?
    private var lastRuntimeLogits: [Float]?
    private var lastProcessedContext = ""

    init(bundle: Bundle = .main, runtime: AtlasModelRuntime? = nil, tokenizer: AtlasTokenizing = AtlasTokenizer()) {
        modelBundle = try? AtlasModelBundle.resolve(in: bundle)
        self.runtime = runtime
        self.tokenizer = tokenizer
        vocabulary = AtlasVocabularyIndex(bundle: bundle, extraWords: tokenizer.vocabularyWords())
    }

    var isModelBundleAvailable: Bool {
        modelBundle != nil
    }

    var diagnosticsDescription: String {
        let runtimeStatus = runtime == nil ? "nil" : "loaded"
        let modelStatus = modelBundle == nil ? "missing" : "available"
        let suggestionPath = runtime == nil ? "frequency-fallback" : "onnx"
        return "ONNX runtime=\(runtimeStatus); modelBundle=\(modelStatus); suggestionPath=\(suggestionPath); vocabulary={\(vocabulary.diagnosticsDescription)}"
    }

    func restore(glaState: AtlasGLAState) {
        state.glaState = glaState.isCompatibleWithCurrentModel ? glaState : .empty()
        state.kvCache.reset()
        state.positionID = 0
    }

    func currentGLAState() -> AtlasGLAState {
        state.glaState
    }

    func resetCurrentDraftMemory() {
        state.kvCache.reset()
        state.positionID = 0
        lastRuntimeLogits = nil
        lastProcessedContext = ""
        tokenizer.resetTokenizationState()
    }

    func suggestions(for context: String, session: AtlasSession, globalEngram: Engram) -> [AtlasSuggestion] {
        if !context.hasPrefix(lastProcessedContext) {
            resetCurrentDraftMemory()
        }

        let tokens = tokenizer.encodeLatestTokens(from: context).suffix(AtlasConfiguration.maxContextTokens)
        for token in tokens {
            step(tokenID: token)
        }
        lastProcessedContext = context

        let partial = PartialWordDetector.partialWord(in: context)
        let logits = candidateScores(from: lastRuntimeLogits, context: context, limit: 512, session: session, globalEngram: globalEngram)
        return ranker.rank(
            logits: logits,
            partialWord: partial,
            vocabulary: vocabulary,
            context: context,
            sessionEngram: session.engram,
            globalEngram: globalEngram
        )
    }

    func corrections(
        for selectedWord: String,
        leftContext: String,
        rightContext: String,
        session: AtlasSession,
        globalEngram: Engram
    ) -> [AtlasSuggestion] {
        let normalized = EngramNormalizer.normalize(selectedWord)
        guard normalized.count >= 3 else { return [] }

        let baseGLAState = state.glaState
        let prefixLength = min(2, normalized.count)
        let prefixProbeContext = leftContext + String(normalized.prefix(prefixLength))
        let fullWordProbeContext = leftContext + selectedWord
        logAutocorrect(
            "start selected='\(selectedWord)' normalized='\(normalized)' prefixProbe='\(logSnippet(prefixProbeContext))' fullProbe='\(logSnippet(fullWordProbeContext))'"
        )

        let prefixLogits = scoresByReplaying(
            context: prefixProbeContext,
            baseGLAState: baseGLAState,
            session: session,
            globalEngram: globalEngram
        )
        logAutocorrect("prefix probe candidates=\(prefixLogits.count) top=\(topLogitSummary(prefixLogits))")
        let fullWordLogits = scoresByReplaying(
            context: fullWordProbeContext,
            baseGLAState: baseGLAState,
            session: session,
            globalEngram: globalEngram
        )
        logAutocorrect("full-word probe candidates=\(fullWordLogits.count) top=\(topLogitSummary(fullWordLogits))")

        resetCurrentDraftMemory()
        state.glaState = baseGLAState

        let corrections = ranker.rankCorrections(
            for: selectedWord,
            leftContext: leftContext,
            rightContext: rightContext,
            prefixLogits: prefixLogits,
            fullWordLogits: fullWordLogits,
            vocabulary: vocabulary,
            sessionEngram: session.engram,
            globalEngram: globalEngram
        )
        logAutocorrect("ranked corrections=\(corrections.map { "\($0.text):\(String(format: "%.3f", $0.score))" }.joined(separator: ", "))")
        return corrections
    }

    private func applyEngramBias(to logits: [Float], context: String, session: AtlasSession, globalEngram: Engram) -> [Float] {
        var biased = logits
        addTokenBias(from: session.engram, context: context, weight: 1.0, logits: &biased)
        addTokenBias(from: globalEngram, context: context, weight: 0.75, logits: &biased)
        return biased
    }

    private func addTokenBias(from engram: Engram, context: String, weight: Float, logits: inout [Float]) {
        for bias in engram.relevantWords(for: context, limit: 24) {
            let boost = Float(bias.score) * weight
            for tokenID in tokenizer.tokenIDs(forWord: bias.word) where logits.indices.contains(tokenID) {
                logits[tokenID] += boost
            }
        }
    }

    private func scoresByReplaying(
        context: String,
        baseGLAState: AtlasGLAState,
        session: AtlasSession,
        globalEngram: Engram
    ) -> [String: Double] {
        state = AtlasInferenceState(positionID: 0, kvCache: AtlasKVCache(), glaState: baseGLAState)
        lastRuntimeLogits = nil
        lastProcessedContext = ""
        tokenizer.resetTokenizationState()

        let tokens = tokenizer.encodeLatestTokens(from: context).suffix(AtlasConfiguration.maxContextTokens)
        for token in tokens {
            step(tokenID: token)
        }

        return candidateScores(from: lastRuntimeLogits, context: context, limit: 1024, session: session, globalEngram: globalEngram)
    }

    private func candidateScores(
        from logits: [Float]?,
        context: String,
        limit: Int,
        session: AtlasSession,
        globalEngram: Engram
    ) -> [String: Double] {
        let runtimeLogits = logits.map { applyEngramBias(to: $0, context: context, session: session, globalEngram: globalEngram) }
        if let scores = runtimeLogits.map({ tokenizer.candidateScores(from: $0, limit: limit) }),
           !scores.isEmpty {
            return scores
        }

        let fallbackScores = vocabulary.fallbackScores(limit: limit)
        if !fallbackScores.isEmpty {
            return fallbackScores
        }

        #if DEBUG
        logInference("no model logits and no frequency fallback; suggestions disabled")
        #endif
        return [:]
    }

    private func step(tokenID: Int64) {
        if state.positionID >= Int64(AtlasConfiguration.maxContextTokens) {
            state.kvCache.reset()
            state.glaState = .empty()
            state.positionID = 0
        }

        if let runtime {
            do {
                let output = try runtime.step(
                    AtlasModelStepInput(
                        tokenID: tokenID,
                        positionID: state.positionID,
                        kvCache: state.kvCache,
                        glaState: state.glaState
                    )
                )
                lastRuntimeLogits = output.logits
                state.kvCache = output.kvCache
                state.glaState = output.glaState
                state.positionID += 1
                return
            } catch {
                assertionFailure("ATLAS ONNX step failed: \(error)")
            }
        }

        state.positionID += 1
    }

    private func logAutocorrect(_ message: String) {
        #if DEBUG
        NSLog("[Keygram Autocorrect Engine] %@", message)
        #endif
    }

    private func logInference(_ message: String) {
        #if DEBUG
        NSLog("[Keygram Inference] %@", message)
        #endif
    }

    private func logSnippet(_ text: String, limit: Int = 80) -> String {
        let collapsed = text.replacingOccurrences(of: "\n", with: "\\n")
        guard collapsed.count > limit else { return collapsed }
        return "..." + String(collapsed.suffix(limit))
    }

    private func topLogitSummary(_ logits: [String: Double], limit: Int = 5) -> String {
        logits
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { "\($0.key):\(String(format: "%.3f", $0.value))" }
            .joined(separator: ", ")
    }
}
