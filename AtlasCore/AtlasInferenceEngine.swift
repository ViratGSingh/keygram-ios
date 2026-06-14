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

private struct NextWordCandidateFeatures {
    var text: String
    var personalLogProbability: Double?
    var personalHitCount: Int = 0
    var personalOrder: Int = 0
    var effortScore: Double = 0
    var recencyBoost: Double = 0
    var baseFrequencyScore: Double = 0
    var isPhrase: Bool = false

    mutating func absorbPersonalCandidate(_ candidate: PersonalNGramCandidate, weight: Double = 1.0) {
        let weightedLogProbability = candidate.logProbability - max(0, 1.0 - weight) * 0.65
        personalLogProbability = max(personalLogProbability ?? -.infinity, weightedLogProbability)
        personalHitCount = max(personalHitCount, candidate.hitCount)
        personalOrder = max(personalOrder, candidate.order)
        effortScore = max(effortScore, candidate.effortScore * weight)
        recencyBoost = max(recencyBoost, candidate.recencyBoost * weight)
        isPhrase = isPhrase || candidate.isPhrase
    }
}

final class AtlasInferenceEngine {
    private var state = AtlasInferenceState()
    private let tokenizer: AtlasTokenizing
    private let vocabulary: AtlasVocabularyIndex
    private let ranker = AtlasSuggestionRanker()
    private let modelBundle: AtlasModelBundle?
    private var runtime: AtlasModelRuntime?
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

    func discardRuntimeForMemoryPressure() {
        runtime = nil
        resetCurrentDraftMemory()
    }

    func suggestions(for context: String, session: AtlasSession, globalEngram: Engram) -> [AtlasSuggestion] {
        if !context.hasPrefix(lastProcessedContext) {
            resetCurrentDraftMemory()
        }

        let partial = PartialWordDetector.partialWord(in: context)
        if let partial, !partial.isEmpty {
            advanceRuntime(to: context)
            let logits = candidateScores(from: lastRuntimeLogits, context: context, limit: 128, session: session, globalEngram: globalEngram)
            return ranker.rank(
                logits: logits,
                partialWord: partial,
                vocabulary: vocabulary,
                context: context,
                sessionEngram: session.engram,
                globalEngram: globalEngram
            )
        }

        let shortlist = nextWordShortlist(for: context, session: session, globalEngram: globalEngram)
        guard !shortlist.isEmpty else {
            return fallbackNextWordSuggestions(context: context, session: session, globalEngram: globalEngram)
        }

        if shouldSkipAtlasRerank(shortlist) {
            return rankNextWordShortlist(shortlist, atlasScores: [:], atlasWasAvailable: false)
        }

        advanceRuntime(to: context)
        let atlasScores = lastRuntimeLogits.map {
            tokenizer.candidateScores(from: $0, candidates: Array(shortlist.keys))
        } ?? [:]
        return rankNextWordShortlist(shortlist, atlasScores: atlasScores, atlasWasAvailable: runtime != nil)
    }

    private func advanceRuntime(to context: String) {
        if !context.hasPrefix(lastProcessedContext) {
            resetCurrentDraftMemory()
        }

        let tokens = tokenizer.encodeLatestTokens(from: context).suffix(AtlasConfiguration.maxContextTokens)
        for token in tokens {
            step(tokenID: token)
        }
        lastProcessedContext = context
    }

    private func fallbackNextWordSuggestions(context: String, session: AtlasSession, globalEngram: Engram) -> [AtlasSuggestion] {
        let fallbackScores = vocabulary.fallbackScores(limit: AtlasConfiguration.maxSuggestions)
        guard !fallbackScores.isEmpty else { return [] }
        return ranker.rank(
            logits: fallbackScores,
            partialWord: nil,
            vocabulary: vocabulary,
            context: context,
            sessionEngram: session.engram,
            globalEngram: globalEngram
        )
    }

    private func nextWordShortlist(
        for context: String,
        session: AtlasSession,
        globalEngram: Engram
    ) -> [String: NextWordCandidateFeatures] {
        var candidates: [String: NextWordCandidateFeatures] = [:]

        func feature(for text: String) -> NextWordCandidateFeatures {
            candidates[text] ?? NextWordCandidateFeatures(text: text)
        }

        func store(_ feature: NextWordCandidateFeatures) {
            candidates[feature.text] = feature
        }

        for candidate in session.engram.personalNextWordCandidates(for: context, limit: 72) {
            var feature = feature(for: candidate.text)
            feature.absorbPersonalCandidate(candidate)
            store(feature)
        }

        for candidate in session.engram.personalPhraseCandidates(for: context, limit: 8) {
            var feature = feature(for: candidate.text)
            feature.absorbPersonalCandidate(candidate)
            store(feature)
        }

        for candidate in globalEngram.personalNextWordCandidates(for: context, limit: 24) {
            var feature = feature(for: candidate.text)
            feature.absorbPersonalCandidate(candidate, weight: 0.72)
            store(feature)
        }

        for entry in session.engram.confirmedWords(limit: 28) {
            var feature = feature(for: entry.word)
            feature.effortScore = max(feature.effortScore, min(1.0, log(Double(entry.acceptedCount + 1)) * 0.24))
            feature.recencyBoost = max(feature.recencyBoost, session.engram.bias(for: entry.word, context: context) * 0.2)
            store(feature)
        }

        for (word, score) in vocabulary.fallbackScores(limit: AtlasConfiguration.personalNGramCandidateLimit) {
            var feature = feature(for: word)
            feature.baseFrequencyScore = max(feature.baseFrequencyScore, score)
            store(feature)
        }

        let ranked = candidates.values
            .filter { isUsableNextWordCandidate($0.text) }
            .sorted { preAtlasScore($0) > preAtlasScore($1) }
            .prefix(AtlasConfiguration.personalNGramCandidateLimit)
        return Dictionary(uniqueKeysWithValues: ranked.map { ($0.text, $0) })
    }

    private func shouldSkipAtlasRerank(_ shortlist: [String: NextWordCandidateFeatures]) -> Bool {
        let personal = shortlist.values
            .filter { $0.personalHitCount > 0 }
            .sorted { preAtlasScore($0) > preAtlasScore($1) }
        guard let best = personal.first else { return false }
        let runnerUp = personal.dropFirst().first.map(preAtlasScore) ?? -.infinity
        let margin = preAtlasScore(best) - runnerUp
        return best.personalOrder >= 3
            && best.personalHitCount >= 4
            && margin >= 0.18
    }

    private func rankNextWordShortlist(
        _ shortlist: [String: NextWordCandidateFeatures],
        atlasScores: [String: Double],
        atlasWasAvailable: Bool
    ) -> [AtlasSuggestion] {
        let bestAtlasScore = atlasScores.values.max()
        let ranked = shortlist.values.map { feature -> (suggestion: AtlasSuggestion, isPhrase: Bool) in
            let weights = interpolationWeights(for: feature, atlasWasAvailable: atlasWasAvailable && bestAtlasScore != nil)
            let personalScore = personalEvidenceScore(feature)
            let atlasScore = atlasScores[feature.text].map { rawScore -> Double in
                guard let bestAtlasScore else { return -4.0 }
                return max(-4.0, rawScore - bestAtlasScore)
            } ?? 0
            let baseScore = feature.baseFrequencyScore > 0
                ? log(max(0.0001, feature.baseFrequencyScore))
                : 0
            let contextualPersonalBoost = feature.personalOrder >= 2
                ? 0.8 + min(0.6, log(Double(feature.personalHitCount + 1)) * 0.35)
                : 0

            let score = personalScore * weights.personal
                + atlasScore * weights.atlas
                + baseScore * weights.baseFrequency
                + feature.effortScore * weights.effort
                + feature.recencyBoost * weights.recency
                + contextualPersonalBoost
                + (feature.isPhrase ? 0.06 : 0)

            return (
                AtlasSuggestion(
                    text: feature.text,
                    kind: feature.personalHitCount > 0 || feature.effortScore > 0.2 ? .personal : .nextWord,
                    score: score
                ),
                feature.isPhrase
            )
        }

        let deduped = Dictionary(grouping: ranked, by: { $0.suggestion.text.lowercased() })
            .compactMap { $0.value.max { $0.suggestion.score < $1.suggestion.score } }
            .sorted { $0.suggestion.score > $1.suggestion.score }

        var result: [AtlasSuggestion] = []
        var includedPhrase = false
        for candidate in deduped {
            if candidate.isPhrase {
                guard !includedPhrase else { continue }
                includedPhrase = true
            }
            result.append(candidate.suggestion)
            if result.count == AtlasConfiguration.maxSuggestions {
                break
            }
        }
        return result
    }

    private func interpolationWeights(
        for feature: NextWordCandidateFeatures,
        atlasWasAvailable: Bool
    ) -> (personal: Double, atlas: Double, baseFrequency: Double, effort: Double, recency: Double) {
        let atlas: Double
        let personal: Double
        let base: Double

        if feature.personalOrder >= 4 && feature.personalHitCount >= 6 {
            personal = 0.82
            atlas = 0.06
            base = 0.06
        } else if feature.personalOrder >= 3 && feature.personalHitCount >= 3 {
            personal = 0.68
            atlas = 0.18
            base = 0.08
        } else if feature.personalOrder >= 2 && feature.personalHitCount > 0 {
            personal = 0.64
            atlas = 0.18
            base = 0.08
        } else if feature.personalHitCount > 0 {
            personal = 0.3
            atlas = 0.4
            base = 0.2
        } else {
            personal = 0.12
            atlas = 0.52
            base = 0.28
        }

        if atlasWasAvailable {
            return (personal, atlas, base, 0.08, 0.06)
        }

        return (personal + atlas * 0.45, 0, base + atlas * 0.45, 0.08, 0.06)
    }

    private func preAtlasScore(_ feature: NextWordCandidateFeatures) -> Double {
        personalEvidenceScore(feature)
            + log(max(0.0001, feature.baseFrequencyScore)) * 0.18
            + feature.effortScore * 0.22
            + feature.recencyBoost * 0.18
            + (feature.isPhrase ? 0.06 : 0)
    }

    private func personalEvidenceScore(_ feature: NextWordCandidateFeatures) -> Double {
        guard let logProbability = feature.personalLogProbability,
              feature.personalHitCount > 0
        else {
            return 0
        }

        let boundedLogProbability = max(-4.0, min(0, logProbability))
        let contextualOrderBoost = Double(max(0, feature.personalOrder - 1)) * 0.5
        let hitBoost = log(Double(feature.personalHitCount + 1)) * 0.55
        return boundedLogProbability * 0.3 + contextualOrderBoost + hitBoost
    }

    private func isUsableNextWordCandidate(_ candidate: String) -> Bool {
        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed == candidate, !candidate.isEmpty else { return false }
        let words = EngramNormalizer.ngramTokens(in: candidate)
        guard !words.isEmpty, words.count <= 3 else { return false }
        return words.joined(separator: " ") == candidate.lowercased()
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
