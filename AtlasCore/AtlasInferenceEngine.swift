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
    /// A call-to-action shown in place of next-word predictions when the keyboard
    /// extension lacks Full Access (which the next-word model requires). Tapping it
    /// routes the user to Settings instead of inserting text.
    case enableFullAccess
}

private struct NextWordCandidateFeatures {
    var text: String
    var personalLogProbability: Double?
    var personalHitCount: Int = 0
    var personalOrder: Int = 0
    var effortScore: Double = 0
    var recencyBoost: Double = 0
    var baseFrequencyScore: Double = 0
    var marginalPersonalizationBoost: Double = 0
    var feedbackBoost: Double = 0
    var isPhrase: Bool = false
    var isEngramSourced: Bool = false

    mutating func absorbPersonalCandidate(_ candidate: PersonalNGramCandidate, weight: Double = 1.0) {
        let weightedLogProbability = candidate.logProbability - max(0, 1.0 - weight) * 0.65
        personalLogProbability = max(personalLogProbability ?? -.infinity, weightedLogProbability)
        personalHitCount = max(personalHitCount, candidate.hitCount)
        personalOrder = max(personalOrder, candidate.order)
        effortScore = max(effortScore, candidate.effortScore * weight)
        recencyBoost = max(recencyBoost, candidate.recencyBoost * weight)
        isPhrase = isPhrase || candidate.isPhrase
        isEngramSourced = true
    }
}

private struct CandidatePrefixState {
    var inferenceState: AtlasInferenceState
    var logits: [Float]
    var logNormalizer: Double
    var cumulativeLogProbability: Double
}

private struct NeuralWordBeam {
    var tokenIDs: [Int]
    var text: String
    var rawLogProbability: Double
}

private struct RankedNextWordCandidate {
    var suggestion: AtlasSuggestion
    var isPhrase: Bool
    var diagnostic: String
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
        vocabulary = AtlasVocabularyIndex(bundle: bundle)
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

    func suggestions(
        for context: String, 
        session: AtlasSession,
        globalEngram: Engram,
        feedback: NextWordFeedbackSnapshot = NextWordFeedbackSnapshot(),
        neuralOnly: Bool = false
    ) -> [AtlasSuggestion] {
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

        let shortlist = applyingFeedback(
            to: applyingMarginalPersonalization(
                to: nextWordShortlist(for: context, session: session, globalEngram: globalEngram),
                session: session,
                globalEngram: globalEngram
            ),
            context: context,
            feedback: feedback
        )
        guard !shortlist.isEmpty else {
            return fallbackNextWordSuggestions(context: context, session: session, globalEngram: globalEngram)
        }

        if !neuralOnly, shouldSkipAtlasRerank(shortlist) {
            return rankNextWordShortlist(shortlist, atlasScores: [:], atlasWasAvailable: false)
        }

        advanceRuntime(to: context)
        let neuralResult = lastRuntimeLogits.map {
            neuralCandidatesAndScores(from: $0, shortlist: shortlist)
        }
        let expandedShortlist = applyingFeedback(
            to: applyingMarginalPersonalization(
                to: neuralResult?.shortlist ?? shortlist,
                session: session,
                globalEngram: globalEngram
            ),
            context: context,
            feedback: feedback
        )
        let atlasScores = neuralResult?.scores ?? [:]
        let suggestions = neuralOnly
            ? rankNeuralOnly(atlasScores)
            : rankNextWordShortlist(
                expandedShortlist,
                atlasScores: atlasScores,
                atlasWasAvailable: runtime != nil
            )
        logInference(
            "next-word mode=\(neuralOnly ? "neural-only" : "blended") top=\(suggestions.map(\.text).joined(separator: ",")) neural=\(topLogitSummary(atlasScores))"
        )
        return suggestions
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
            feature.isEngramSourced = true
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
        if atlasWasAvailable, bestAtlasScore != nil {
            let rejectedUnsupported = shortlist.values
                .filter { atlasScores[$0.text] == nil && $0.personalOrder < 2 }
                .sorted { preAtlasScore($0) > preAtlasScore($1) }
                .prefix(12)
                .map {
                    String(
                        format: "%@ personal=%.3f order=%d hits=%d marginal=%.3f feedback=%.3f",
                        $0.text,
                        personalEvidenceScore($0),
                        $0.personalOrder,
                        $0.personalHitCount,
                        $0.marginalPersonalizationBoost,
                        $0.feedbackBoost
                    )
                }
            if !rejectedUnsupported.isEmpty {
                logInference("candidate-rejected-no-neural " + rejectedUnsupported.joined(separator: " | "))
            }
        }

        let ranked = shortlist.values.compactMap { feature -> RankedNextWordCandidate? in
            let rawAtlasScore = atlasScores[feature.text]
            let hasAtlasScore = rawAtlasScore != nil
            if atlasWasAvailable,
               bestAtlasScore != nil,
               !hasAtlasScore,
               feature.personalOrder < 2 {
                return nil
            }

            let weights = interpolationWeights(for: feature, atlasWasAvailable: atlasWasAvailable && bestAtlasScore != nil)
            let personalScore = personalEvidenceScore(feature)
            let atlasScore = rawAtlasScore.map { rawScore -> Double in
                guard let bestAtlasScore else { return -4.0 }
                return max(-4.0, rawScore - bestAtlasScore)
            } ?? (atlasWasAvailable ? -4.0 : 0)
            let baseScore = feature.baseFrequencyScore > 0
                ? log(max(0.0001, feature.baseFrequencyScore))
                : 0
            let contextualPersonalBoost = feature.personalOrder >= 2
                ? 0.8 + min(0.6, log(Double(feature.personalHitCount + 1)) * 0.35)
                : 0
            let supplementalLimit = feature.personalOrder >= 2 ? 0.85 : 0.3
            let supplementalBoost = max(
                -supplementalLimit,
                min(
                    supplementalLimit,
                    feature.marginalPersonalizationBoost + feature.feedbackBoost
                )
            )

            let score = personalScore * weights.personal
                + atlasScore * weights.atlas
                + baseScore * weights.baseFrequency
                + feature.effortScore * weights.effort
                + feature.recencyBoost * weights.recency
                + supplementalBoost
                + contextualPersonalBoost
                + (feature.isPhrase ? 0.06 : 0)

            let diagnostic = String(
                format: "%@ total=%.3f neuralRaw=%@ neuralRel=%.3f personal=%.3f order=%d hits=%d base=%.3f marginal=%.3f feedback=%.3f supplemental=%.3f context=%.3f",
                feature.text,
                score,
                rawAtlasScore.map { String(format: "%.3f", $0) } ?? "none",
                atlasScore,
                personalScore,
                feature.personalOrder,
                feature.personalHitCount,
                baseScore,
                feature.marginalPersonalizationBoost,
                feature.feedbackBoost,
                supplementalBoost,
                contextualPersonalBoost
            )

            return RankedNextWordCandidate(
                suggestion: AtlasSuggestion(
                    text: feature.text,
                    kind: feature.isEngramSourced ? .personal : .nextWord,
                    score: score
                ),
                isPhrase: feature.isPhrase,
                diagnostic: diagnostic
            )
        }

        let deduped = Dictionary(grouping: ranked, by: { $0.suggestion.text.lowercased() })
            .compactMap { $0.value.max { $0.suggestion.score < $1.suggestion.score } }
            .sorted { $0.suggestion.score > $1.suggestion.score }
        logInference(
            "candidate-scores " + deduped.prefix(12).map(\.diagnostic).joined(separator: " | ")
        )

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

    private func rankNeuralOnly(_ atlasScores: [String: Double]) -> [AtlasSuggestion] {
        let ranked = atlasScores
            .filter { isUsableNextWordCandidate($0.key) }
            .sorted { $0.value > $1.value }
        logInference(
            "candidate-scores neural-only " + ranked.prefix(12)
                .map { "\($0.key)=\(String(format: "%.3f", $0.value))" }
                .joined(separator: " | ")
        )
        return ranked.prefix(AtlasConfiguration.maxSuggestions).map {
            AtlasSuggestion(text: $0.key, kind: .nextWord, score: $0.value)
        }
    }

    private func neuralCandidatesAndScores(
        from logits: [Float],
        shortlist: [String: NextWordCandidateFeatures]
    ) -> (shortlist: [String: NextWordCandidateFeatures], scores: [String: Double]) {
        guard let runtime, !logits.isEmpty else { return (shortlist, [:]) }

        var expanded = shortlist
        let baseLogNormalizer = logSumExp(logits)
        let baseState = CandidatePrefixState(
            inferenceState: state,
            logits: logits,
            logNormalizer: baseLogNormalizer,
            cumulativeLogProbability: 0
        )
        var prefixCache: [[Int]: CandidatePrefixState] = [[]: baseState]
        var remainingStepBudget = AtlasConfiguration.exactNeuralRescoreStepBudget
        var beamStepBudget = min(
            AtlasConfiguration.neuralWordBeamStepBudget,
            remainingStepBudget
        )
        let initialBeamStepBudget = beamStepBudget
        var scores: [String: Double] = [:]

        var initialBeams: [NeuralWordBeam] = []
        for tokenID in topTokenIDs(
            from: logits,
            limit: AtlasConfiguration.neuralNextWordCandidateLimit * 4
        ) {
            guard let piece = tokenizer.tokenPiece(forTokenID: tokenID),
                  let word = startingWord(from: piece)
            else {
                continue
            }

            let rawScore = Double(logits[tokenID]) - baseLogNormalizer
            if vocabulary.contains(word), isUsableNextWordCandidate(word) {
                scores[word] = max(scores[word] ?? -.infinity, rawScore)
                if expanded[word] == nil {
                    expanded[word] = NextWordCandidateFeatures(text: word)
                }
            }
            initialBeams.append(NeuralWordBeam(tokenIDs: [tokenID], text: word, rawLogProbability: rawScore))
            if initialBeams.count == AtlasConfiguration.neuralNextWordCandidateLimit {
                break
            }
        }

        var beams = Array(
            initialBeams
                .sorted { $0.rawLogProbability > $1.rawLogProbability }
                .prefix(AtlasConfiguration.neuralWordBeamWidth)
        )
        for _ in 1..<AtlasConfiguration.neuralWordBeamDepth {
            var nextBeams: [NeuralWordBeam] = []
            for beam in beams {
                guard let prefixState = candidatePrefixState(
                    after: beam.tokenIDs,
                    runtime: runtime,
                    prefixCache: &prefixCache,
                    remainingStepBudget: &beamStepBudget
                ) else {
                    continue
                }

                for tokenID in topTokenIDs(
                    from: prefixState.logits,
                    limit: AtlasConfiguration.neuralWordBeamWidth * 8
                ) {
                    guard let piece = tokenizer.tokenPiece(forTokenID: tokenID),
                          !piece.hasPrefix("\u{2581}"),
                          let text = appendingContinuationPiece(piece, to: beam.text)
                    else {
                        continue
                    }

                    let rawScore = prefixState.cumulativeLogProbability
                        + Double(prefixState.logits[tokenID])
                        - prefixState.logNormalizer
                    let tokenIDs = beam.tokenIDs + [tokenID]
                    let candidate = NeuralWordBeam(
                        tokenIDs: tokenIDs,
                        text: text,
                        rawLogProbability: rawScore
                    )
                    nextBeams.append(candidate)

                    if vocabulary.contains(text), isUsableNextWordCandidate(text) {
                        if expanded[text] == nil {
                            expanded[text] = NextWordCandidateFeatures(text: text)
                        }
                    }
                }
            }

            guard !nextBeams.isEmpty else { break }
            beams = Array(
                nextBeams
                    .sorted {
                        normalizedSequenceScore($0.rawLogProbability, tokenCount: $0.tokenIDs.count)
                            > normalizedSequenceScore($1.rawLogProbability, tokenCount: $1.tokenIDs.count)
                    }
                    .prefix(AtlasConfiguration.neuralWordBeamWidth)
            )
        }
        remainingStepBudget -= initialBeamStepBudget - beamStepBudget

        let tokenized = expanded.values.compactMap { feature -> (feature: NextWordCandidateFeatures, tokenIDs: [Int])? in
            let tokenIDs = tokenizer.tokenIDs(forWord: feature.text)
            guard !tokenIDs.isEmpty,
                  tokenIDs.count <= AtlasConfiguration.exactNeuralRescoreTokenLimit,
                  tokenIDs.allSatisfy({ logits.indices.contains($0) })
            else {
                return nil
            }
            return (feature, tokenIDs)
        }

        var multiTokenCandidates: [(feature: NextWordCandidateFeatures, tokenIDs: [Int], firstTokenScore: Double)] = []

        for candidate in tokenized {
            let firstTokenScore = Double(logits[candidate.tokenIDs[0]]) - baseLogNormalizer
            if candidate.tokenIDs.count == 1 {
                scores[candidate.feature.text] = max(scores[candidate.feature.text] ?? -.infinity, firstTokenScore)
            } else {
                multiTokenCandidates.append((candidate.feature, candidate.tokenIDs, firstTokenScore))
            }
        }

        let candidatesToRescore = multiTokenCandidates
            .sorted {
                neuralRescoreShortlistScore(firstTokenScore: $0.firstTokenScore, feature: $0.feature)
                    > neuralRescoreShortlistScore(firstTokenScore: $1.firstTokenScore, feature: $1.feature)
            }
            .prefix(AtlasConfiguration.exactNeuralRescoreCandidateLimit)

        for candidate in candidatesToRescore {
            if let score = exactSequenceLogProbability(
                tokenIDs: candidate.tokenIDs,
                runtime: runtime,
                prefixCache: &prefixCache,
                remainingStepBudget: &remainingStepBudget
            ) {
                scores[candidate.feature.text] = score
            }
        }

        return (expanded, scores)
    }

    private func applyingMarginalPersonalization(
        to shortlist: [String: NextWordCandidateFeatures],
        session: AtlasSession,
        globalEngram: Engram
    ) -> [String: NextWordCandidateFeatures] {
        var personalized = shortlist
        for word in personalized.keys {
            guard var feature = personalized[word] else { continue }
            let globalProbability = vocabulary.frequencyProbability(for: word)
            feature.marginalPersonalizationBoost = session.engram.marginalFrequencyBoost(
                for: word,
                globalProbability: globalProbability
            ) + globalEngram.marginalFrequencyBoost(
                for: word,
                globalProbability: globalProbability
            ) * 0.65
            personalized[word] = feature
        }
        return personalized
    }

    private func applyingFeedback(
        to shortlist: [String: NextWordCandidateFeatures],
        context: String,
        feedback: NextWordFeedbackSnapshot
    ) -> [String: NextWordCandidateFeatures] {
        var reranked = shortlist
        for word in reranked.keys {
            guard var feature = reranked[word] else { continue }
            feature.feedbackBoost = feedback.rankingBoost(for: word, context: context)
            reranked[word] = feature
        }
        return reranked
    }

    private func neuralRescoreShortlistScore(
        firstTokenScore: Double,
        feature: NextWordCandidateFeatures
    ) -> Double {
        firstTokenScore + preAtlasScore(feature) * 0.2
    }

    private func exactSequenceLogProbability(
        tokenIDs: [Int],
        runtime: AtlasModelRuntime,
        prefixCache: inout [[Int]: CandidatePrefixState],
        remainingStepBudget: inout Int
    ) -> Double? {
        guard !tokenIDs.isEmpty, var prefixState = prefixCache[[]] else { return nil }
        var prefix: [Int] = []

        for (index, tokenID) in tokenIDs.enumerated() {
            guard prefixState.logits.indices.contains(tokenID) else { return nil }
            let sequenceScore = prefixState.cumulativeLogProbability
                + Double(prefixState.logits[tokenID])
                - prefixState.logNormalizer
            prefix.append(tokenID)

            if index == tokenIDs.count - 1 {
                return sequenceScore
            }

            if let cachedState = prefixCache[prefix] {
                prefixState = cachedState
                continue
            }

            guard let nextPrefixState = advanceCandidatePrefix(
                tokenID: tokenID,
                sequenceScore: sequenceScore,
                from: prefixState,
                runtime: runtime,
                remainingStepBudget: &remainingStepBudget
            ) else { return nil }
            prefixCache[prefix] = nextPrefixState
            prefixState = nextPrefixState
        }

        return nil
    }

    private func candidatePrefixState(
        after tokenIDs: [Int],
        runtime: AtlasModelRuntime,
        prefixCache: inout [[Int]: CandidatePrefixState],
        remainingStepBudget: inout Int
    ) -> CandidatePrefixState? {
        guard var prefixState = prefixCache[[]] else { return nil }
        var prefix: [Int] = []

        for tokenID in tokenIDs {
            prefix.append(tokenID)
            if let cached = prefixCache[prefix] {
                prefixState = cached
                continue
            }
            guard prefixState.logits.indices.contains(tokenID) else { return nil }
            let sequenceScore = prefixState.cumulativeLogProbability
                + Double(prefixState.logits[tokenID])
                - prefixState.logNormalizer
            guard let next = advanceCandidatePrefix(
                tokenID: tokenID,
                sequenceScore: sequenceScore,
                from: prefixState,
                runtime: runtime,
                remainingStepBudget: &remainingStepBudget
            ) else { return nil }
            prefixCache[prefix] = next
            prefixState = next
        }

        return prefixState
    }

    private func advanceCandidatePrefix(
        tokenID: Int,
        sequenceScore: Double,
        from prefixState: CandidatePrefixState,
        runtime: AtlasModelRuntime,
        remainingStepBudget: inout Int
    ) -> CandidatePrefixState? {
        guard remainingStepBudget > 0 else { return nil }
        remainingStepBudget -= 1

        var branchState = prefixState.inferenceState
        if branchState.positionID >= Int64(AtlasConfiguration.maxContextTokens) {
            branchState = AtlasInferenceState()
        }

        do {
            let output = try runtime.step(
                AtlasModelStepInput(
                    tokenID: Int64(tokenID),
                    positionID: branchState.positionID,
                    kvCache: branchState.kvCache,
                    glaState: branchState.glaState
                )
            )
            branchState.positionID += 1
            branchState.kvCache = output.kvCache
            branchState.glaState = output.glaState
            return CandidatePrefixState(
                inferenceState: branchState,
                logits: output.logits,
                logNormalizer: logSumExp(output.logits),
                cumulativeLogProbability: sequenceScore
            )
        } catch {
            logInference("candidate prefix inference failed: \(error)")
            return nil
        }
    }

    private func normalizedSequenceScore(_ rawScore: Double, tokenCount: Int) -> Double {
        guard tokenCount > 1 else { return rawScore }
        return rawScore / pow(
            Double(tokenCount),
            AtlasConfiguration.neuralLengthNormalizationExponent
        )
    }

    private func topTokenIDs(from logits: [Float], limit: Int) -> [Int] {
        guard limit > 0 else { return [] }
        var best: [(id: Int, logit: Float)] = []
        best.reserveCapacity(limit)

        for (id, logit) in logits.enumerated() {
            if best.count < limit {
                best.append((id, logit))
                if best.count == limit {
                    best.sort { $0.logit > $1.logit }
                }
                continue
            }
            guard let last = best.last, logit > last.logit else { continue }
            best[best.count - 1] = (id, logit)
            var index = best.count - 1
            while index > 0, best[index].logit > best[index - 1].logit {
                best.swapAt(index, index - 1)
                index -= 1
            }
        }

        return best.map(\.id)
    }

    private func appendingContinuationPiece(_ piece: String, to word: String) -> String? {
        let cleaned = piece.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).lowercased()
        guard !cleaned.isEmpty,
              cleaned.rangeOfCharacter(from: .letters) != nil,
              cleaned.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
        else {
            return nil
        }
        return word + cleaned
    }

    private func startingWord(from piece: String) -> String? {
        guard piece.hasPrefix("\u{2581}") else { return nil }
        let cleaned = piece
            .replacingOccurrences(of: "\u{2581}", with: "")
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()
        guard !cleaned.isEmpty,
              cleaned.rangeOfCharacter(from: .letters) != nil,
              cleaned.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
        else {
            return nil
        }
        return cleaned
    }

    private func logSumExp(_ logits: [Float]) -> Double {
        guard let maximum = logits.max() else { return 0 }
        let maximumDouble = Double(maximum)
        let exponentialSum = logits.reduce(0.0) { partialResult, logit in
            partialResult + exp(Double(logit) - maximumDouble)
        }
        return maximumDouble + log(max(exponentialSum, Double.leastNonzeroMagnitude))
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
            + feature.marginalPersonalizationBoost
            + feature.feedbackBoost
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
