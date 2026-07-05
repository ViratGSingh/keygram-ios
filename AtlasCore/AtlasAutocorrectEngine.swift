import Foundation

struct AtlasAutocorrectDecision: Equatable {
    var original: String
    var replacement: String
    var confidence: Double
    var margin: Double
}

final class AtlasAutocorrectEngine {
    private struct RankedCandidate {
        var word: String
        var score: Double
        var distance: Int
        var keyboardPenalty: Double
    }

    private struct SplitPartCandidate {
        var word: String
        var distance: Int
        var keyboardPenalty: Double
    }

    private struct SplitCorrectionCandidate {
        var replacement: String
        var score: Double
        var totalDistance: Int
        var confidence: Double
        var margin: Double

        var isExactJoin: Bool {
            totalDistance == 0
        }
    }

    private let lexicon: AtlasAutocorrectLexicon

    init(bundle: Bundle = .main) {
        lexicon = AtlasAutocorrectLexicon(bundle: bundle)
    }

    var diagnosticsDescription: String {
        lexicon.diagnosticsDescription
    }

    static func quickJoinedWordCorrection(for typedWord: String, leftContext: String, bundle: Bundle = .main) -> AtlasAutocorrectDecision? {
        let token = AtlasAutocorrectToken(rawValue: typedWord)
        guard token.isEligible(in: leftContext) else { return nil }
        let normalized = token.normalized
        guard normalized.count >= 6, normalized.count <= 18 else { return nil }
        let quickLexicon = AtlasQuickSplitLexicon.shared(bundle: bundle)
        guard quickLexicon.isAvailable else { return nil }
        guard !quickLexicon.isDictionaryWord(normalized) else { return nil }
        guard !quickLexicon.isProtected(normalized) else { return nil }
        guard let decision = quickSplitCorrection(for: normalized, lexicon: quickLexicon) else { return nil }
        if quickLexicon.hasDictionaryWordNear(normalized, maxDistance: 1),
           !decision.isExactJoin {
            return nil
        }
        return AtlasAutocorrectDecision(
            original: typedWord,
            replacement: token.preserveCase(applying: decision.replacement),
            confidence: decision.confidence,
            margin: decision.margin
        )
    }

    func correction(
        for typedWord: String,
        leftContext: String,
        sessionEngram: Engram,
        globalEngram: Engram,
        feedback: AutocorrectFeedbackSnapshot
    ) -> AtlasAutocorrectDecision? {
        let token = AtlasAutocorrectToken(rawValue: typedWord)
        guard token.isEligible(in: leftContext) else { return nil }

        let normalized = token.normalized
        // Romanized-Hindi (and other non-English) words the next-word model knows are
        // intentional; never rewrite them to a nearby English word.
        guard !lexicon.isProtected(normalized) else { return nil }
        let isDictionaryWord = lexicon.contains(normalized)
        let isPersonalKnownWord = sessionEngram.containsConfirmed(normalized) || globalEngram.containsConfirmed(normalized)

        var candidates = candidates(for: normalized, sessionEngram: sessionEngram, globalEngram: globalEngram)
        candidates.removeAll {
            feedback.shouldSuppressCorrection(typed: normalized, candidate: $0)
                && !shouldOverrideSuppressionForStrongDirectTypo(typed: normalized, candidate: $0)
        }
        if isDictionaryWord {
            guard !isPersonalKnownWord else { return nil }
            candidates = candidates.filter { candidate in
                shouldCorrectKnownDictionaryWord(typed: normalized, candidate: candidate)
            }
            guard !candidates.isEmpty else { return nil }
        }
        if isPersonalKnownWord {
            let hasCloseDictionaryCandidate = candidates.contains { candidate in
                lexicon.contains(candidate)
                    && AtlasSpellingMetrics.editDistance(normalized, candidate, maxDistance: 1) != nil
            }
            guard hasCloseDictionaryCandidate else { return nil }
        }
        var splitDecision = exactSplitCorrection(for: normalized)
        if !candidates.isEmpty {
            var ranked: [RankedCandidate] = []
            ranked.reserveCapacity(candidates.count)
            for candidate in candidates {
                let distance = AtlasSpellingMetrics.editDistance(normalized, candidate)
                let keyboardPenalty = keyboardDistancePenalty(typed: normalized, candidate: candidate)
                let channelScore = typoChannelScore(
                    typed: normalized,
                    candidate: candidate,
                    distance: distance,
                    keyboardPenalty: keyboardPenalty
                )
                let score = channelScore
                    + 0.1 * log(lexicon.frequency(for: candidate))
                    + sessionEngram.bias(for: candidate, context: leftContext)
                    + globalEngram.bias(for: candidate, context: leftContext) * 0.75
                    + feedbackBoost(typed: normalized, candidate: candidate, leftContext: leftContext, feedback: feedback)
                ranked.append(
                    RankedCandidate(
                        word: candidate,
                        score: score,
                        distance: distance,
                        keyboardPenalty: keyboardPenalty
                    )
                )
            }
            ranked.sort { $0.score > $1.score }

            if let best = ranked.first {
                let probabilities = softmax(ranked.prefix(10).map { $0.score })
                let bestProbability = probabilities.first ?? 0
                let secondProbability = probabilities.dropFirst().first ?? 0
                let margin = bestProbability - secondProbability
                let scoreGap = best.score - (ranked.dropFirst().first?.score ?? (best.score - 1.0))
                let directTypo = best.distance == 1 && best.keyboardPenalty <= 0.35
                let adjacentTransposition = isAdjacentTransposition(normalized, best.word)
                let onlyStrongCandidate = ranked.count == 1 && best.score >= 2.45
                let acceptedByProbability = ranked.count > 1
                    && bestProbability >= 0.55
                    && margin >= 0.20
                let acceptedByScoreGap = best.score >= 2.7
                    && scoreGap >= 0.18
                    && (directTypo || best.distance == 1 || adjacentTransposition)
                let acceptedStrongDirectTypo = directTypo
                    && !isDictionaryWord
                    && lexicon.contains(best.word)
                    && lexicon.frequency(for: best.word) >= 45_000
                    && best.score >= 2.55
                    && scoreGap >= 0.08
                let acceptedStrongKnownTypo = isDictionaryWord
                    && lexicon.contains(best.word)
                    && lexicon.frequency(for: best.word) >= 90_000
                    && best.score >= 3.0
                    && (directTypo || adjacentTransposition)

                splitDecision = splitCorrection(for: normalized)
                if let splitDecision,
                   !feedback.shouldSuppressCorrection(
                       typed: normalized,
                       candidate: splitDecision.replacement
                   ),
                   shouldPreferSplit(splitDecision, over: best) {
                    return AtlasAutocorrectDecision(
                        original: typedWord,
                        replacement: token.preserveCase(applying: splitDecision.replacement),
                        confidence: splitDecision.confidence,
                        margin: splitDecision.margin
                    )
                }

                if acceptedByProbability
                    || acceptedByScoreGap
                    || onlyStrongCandidate
                    || acceptedStrongDirectTypo
                    || acceptedStrongKnownTypo {
                    return AtlasAutocorrectDecision(
                        original: typedWord,
                        replacement: token.preserveCase(applying: best.word),
                        confidence: max(bestProbability, min(0.95, 0.55 + scoreGap * 0.6)),
                        margin: max(margin, scoreGap)
                    )
                }
            }
        }

        if splitDecision == nil {
            splitDecision = splitCorrection(for: normalized)
        }
        if let splitDecision,
           !feedback.shouldSuppressCorrection(
               typed: normalized,
               candidate: splitDecision.replacement
           ) {
            return AtlasAutocorrectDecision(
                original: typedWord,
                replacement: token.preserveCase(applying: splitDecision.replacement),
                confidence: splitDecision.confidence,
                margin: splitDecision.margin
            )
        }

        return nil
    }

    func isKnownWord(_ word: String, sessionEngram: Engram = Engram(), globalEngram: Engram = Engram()) -> Bool {
        let normalized = AtlasAutocorrectToken(rawValue: word).normalized
        return lexicon.contains(normalized) || sessionEngram.containsConfirmed(normalized) || globalEngram.containsConfirmed(normalized)
    }

    func completions(
        for partialWord: String,
        leftContext: String,
        sessionEngram: Engram,
        globalEngram: Engram
    ) -> [AtlasSuggestion] {
        let normalized = AtlasAutocorrectToken(rawValue: partialWord).normalized
        guard !normalized.isEmpty else { return [] }

        let lexiconCandidates = lexicon.completions(for: normalized, limit: AtlasConfiguration.maxSuggestions * 4)
        let sessionCandidates = sessionEngram.completions(matching: normalized, limit: AtlasConfiguration.maxSuggestions)
        let globalCandidates = globalEngram.completions(matching: normalized, limit: AtlasConfiguration.maxSuggestions)
        let engramCandidates = Set(sessionCandidates + globalCandidates)
        let candidates = lexiconCandidates + sessionCandidates + globalCandidates

        let ranked: [AtlasSuggestion] = candidates.map { candidate in
            let frequencyScore = min(0.35, log(lexicon.frequency(for: candidate)) * 0.03)
            let personalScore = sessionEngram.bias(for: candidate, context: leftContext)
            let globalScore = globalEngram.bias(for: candidate, context: leftContext) * 0.75
            let score = 0.4 + frequencyScore + personalScore + globalScore
            let isEngramCandidate = engramCandidates.contains(candidate)
                || sessionEngram.containsConfirmed(candidate)
                || globalEngram.containsConfirmed(candidate)
            return AtlasSuggestion(text: candidate, kind: isEngramCandidate ? .personal : .completion, score: score)
        }

        let deduped = Dictionary(grouping: ranked, by: { $0.text.lowercased() })
            .compactMap { $0.value.max { $0.score < $1.score } }
        return Array(deduped.sorted { $0.score > $1.score }.prefix(AtlasConfiguration.maxSuggestions))
    }

    func learningAssessment(for word: String) -> Engram.LearningAssessment {
        let normalized = AtlasAutocorrectToken(rawValue: word).normalized
        guard !normalized.isEmpty else { return Engram.LearningAssessment() }
        if lexicon.contains(normalized) {
            return Engram.LearningAssessment(isDictionaryWord: true, nearestDictionaryDistance: 0)
        }

        let nearestDistance: Int?
        if !lexicon.correctionCandidates(for: normalized, maxDistance: 1, limit: 1).isEmpty {
            nearestDistance = 1
        } else if !lexicon.correctionCandidates(for: normalized, maxDistance: 2, limit: 1).isEmpty {
            nearestDistance = 2
        } else {
            nearestDistance = nil
        }

        return Engram.LearningAssessment(isDictionaryWord: false, nearestDictionaryDistance: nearestDistance)
    }

    func likelyCorruptPersonalWords(in engram: Engram, limit: Int = 256) -> [String] {
        var words: [String] = []
        for entry in engram.sortedEntries {
            guard words.count < limit else { break }
            guard !EngramNormalizer.isProtectedPersonalToken(entry.word) else { continue }
            guard !lexicon.contains(entry.word) else { continue }
            guard entry.acceptedCount <= 1 || !entry.isConfirmed || entry.rejectedCount > 0 else { continue }
            guard !lexicon.correctionCandidates(for: entry.word, maxDistance: 2, limit: 1).isEmpty else { continue }
            words.append(entry.word)
        }
        return words
    }

    private func candidates(for word: String, sessionEngram: Engram, globalEngram: Engram) -> [String] {
        var candidates = Set(lexicon.correctionCandidates(for: word, maxDistance: 1, limit: 16))
        candidates.formUnion(lexicon.correctionCandidates(for: word, maxDistance: 2, limit: 24))
        candidates.formUnion(sessionEngram.correctionCandidates(for: word, maxDistance: 2, limit: 12))
        candidates.formUnion(globalEngram.correctionCandidates(for: word, maxDistance: 2, limit: 12))

        return Array(candidates)
            .filter { $0 != word && abs($0.count - word.count) <= 2 }
            .sorted { lhs, rhs in
                let leftDistance = AtlasSpellingMetrics.editDistance(lhs, word)
                let rightDistance = AtlasSpellingMetrics.editDistance(rhs, word)
                if leftDistance != rightDistance { return leftDistance < rightDistance }
                return lexicon.frequency(for: lhs) > lexicon.frequency(for: rhs)
            }
            .prefix(18)
            .map(\.self)
    }

    private func shouldCorrectKnownDictionaryWord(typed: String, candidate: String) -> Bool {
        guard lexicon.contains(candidate), typed.count == candidate.count else { return false }
        let isDirectTypo = AtlasSpellingMetrics.editDistance(typed, candidate, maxDistance: 1) == 1
            && keyboardDistancePenalty(typed: typed, candidate: candidate) <= 0.35
        let isTranspositionTypo = isAdjacentTransposition(typed, candidate)
        guard isDirectTypo || isTranspositionTypo else { return false }

        let typedFrequency = lexicon.frequency(for: typed)
        let candidateFrequency = lexicon.frequency(for: candidate)
        let adjacentTranspositionToVeryCommonWord = isTranspositionTypo
            && candidateFrequency >= 90_000
            && candidateFrequency >= typedFrequency * 1.15
        let adjacentTypoToVeryCommonWord = candidateFrequency >= 90_000
            && candidateFrequency >= typedFrequency * 1.25
        let strongFrequencyAdvantage = candidateFrequency >= typedFrequency * 3
            || candidateFrequency - typedFrequency >= 50_000
        let rareTypedWordToCommonCandidate = typedFrequency < 25_000 && candidateFrequency >= 45_000
        return adjacentTranspositionToVeryCommonWord
            || adjacentTypoToVeryCommonWord
            || strongFrequencyAdvantage
            || rareTypedWordToCommonCandidate
    }

    private func shouldOverrideSuppressionForStrongDirectTypo(typed: String, candidate: String) -> Bool {
        guard !lexicon.contains(typed), lexicon.contains(candidate) else { return false }
        guard AtlasSpellingMetrics.editDistance(typed, candidate, maxDistance: 1) == 1 else { return false }
        guard keyboardDistancePenalty(typed: typed, candidate: candidate) <= 0.35 else { return false }
        return lexicon.frequency(for: candidate) >= 45_000
    }

    private func exactSplitCorrection(for word: String) -> SplitCorrectionCandidate? {
        guard word.count >= 6, word.count <= 24 else { return nil }

        var ranked: [SplitCorrectionCandidate] = []
        var splitIndex = word.index(word.startIndex, offsetBy: 2)
        let lastSplitIndex = word.index(word.endIndex, offsetBy: -2)
        while splitIndex <= lastSplitIndex {
            let left = String(word[..<splitIndex])
            let right = String(word[splitIndex...])
            if isStrongSplitWord(left), isStrongSplitWord(right) {
                let score = splitScore(
                    left: SplitPartCandidate(word: left, distance: 0, keyboardPenalty: 0),
                    right: SplitPartCandidate(word: right, distance: 0, keyboardPenalty: 0)
                )
                ranked.append(
                    SplitCorrectionCandidate(
                        replacement: "\(left) \(right)",
                        score: score,
                        totalDistance: 0,
                        confidence: 0,
                        margin: 0
                    )
                )
            }
            splitIndex = word.index(after: splitIndex)
        }

        return bestSplitDecision(from: ranked, minimumConfidence: 0.78)
    }

    private func splitCorrection(for word: String) -> SplitCorrectionCandidate? {
        guard word.count >= 6, word.count <= 24 else { return nil }

        var ranked: [SplitCorrectionCandidate] = []
        var splitIndex = word.index(word.startIndex, offsetBy: 2)
        let lastSplitIndex = word.index(word.endIndex, offsetBy: -2)
        while splitIndex <= lastSplitIndex {
            let left = String(word[..<splitIndex])
            let right = String(word[splitIndex...])
            let leftCandidates = splitPartCandidates(for: left)
            let rightCandidates = splitPartCandidates(for: right)
            for leftCandidate in leftCandidates {
                for rightCandidate in rightCandidates {
                    let totalDistance = leftCandidate.distance + rightCandidate.distance
                    guard totalDistance <= 1 else { continue }

                    let score = splitScore(left: leftCandidate, right: rightCandidate)
                    ranked.append(
                        SplitCorrectionCandidate(
                            replacement: "\(leftCandidate.word) \(rightCandidate.word)",
                            score: score,
                            totalDistance: totalDistance,
                            confidence: 0,
                            margin: 0
                        )
                    )
                }
            }
            splitIndex = word.index(after: splitIndex)
        }

        return bestSplitDecision(from: ranked, minimumConfidence: 0.74)
    }

    private func splitScore(left: SplitPartCandidate, right: SplitPartCandidate) -> Double {
        let totalDistance = left.distance + right.distance
        let totalKeyboardPenalty = left.keyboardPenalty + right.keyboardPenalty
        return log(lexicon.frequency(for: left.word))
            + log(lexicon.frequency(for: right.word))
            - Double(totalDistance) * 0.9
            - totalKeyboardPenalty * 0.7
            - abs(Double(left.word.count - right.word.count)) * 0.04
    }

    private func bestSplitDecision(
        from candidates: [SplitCorrectionCandidate],
        minimumConfidence: Double
    ) -> SplitCorrectionCandidate? {
        var ranked = candidates
        ranked.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.totalDistance < rhs.totalDistance
        }
        guard var best = ranked.first else { return nil }

        let secondScore = ranked.dropFirst().first?.score ?? (best.score - 1)
        best.margin = best.score - secondScore
        best.confidence = min(0.93, max(0.74, 0.74 + best.margin * 0.05 - Double(best.totalDistance) * 0.05))
        guard best.confidence >= minimumConfidence, best.margin >= 0.10 else { return nil }
        return best
    }

    private func shouldPreferSplit(_ split: SplitCorrectionCandidate, over candidate: RankedCandidate) -> Bool {
        guard split.isExactJoin else { return false }
        guard split.confidence >= 0.78, split.margin >= 0.10 else { return false }

        // Exact joins like "howare" -> "how are" should beat an edit-distance-1
        // dictionary neighbor like "howard"; fuzzy split guesses should not.
        if candidate.distance >= 1 {
            return true
        }
        return false
    }

    private func splitPartCandidates(for raw: String) -> [SplitPartCandidate] {
        var seen = Set<String>()
        var candidates: [SplitPartCandidate] = []

        func append(_ candidate: String) {
            guard seen.insert(candidate).inserted, isStrongSplitWord(candidate) else { return }
            candidates.append(
                SplitPartCandidate(
                    word: candidate,
                    distance: AtlasSpellingMetrics.editDistance(raw, candidate),
                    keyboardPenalty: keyboardDistancePenalty(typed: raw, candidate: candidate)
                )
            )
        }

        append(raw)
        for candidate in lexicon.correctionCandidates(for: raw, maxDistance: 1, limit: 8) {
            append(candidate)
        }

        return candidates
            .filter { $0.distance <= 1 }
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
                if lhs.keyboardPenalty != rhs.keyboardPenalty { return lhs.keyboardPenalty < rhs.keyboardPenalty }
                return lexicon.frequency(for: lhs.word) > lexicon.frequency(for: rhs.word)
            }
            .prefix(4)
            .map(\.self)
    }

    private func isStrongSplitWord(_ word: String) -> Bool {
        if word.count == 1 {
            guard word == "a" || word == "i" else { return false }
        } else if word.count == 2 {
            guard Self.strongTwoLetterSplitWords.contains(word) else { return false }
        } else {
            guard word.count >= 3 else { return false }
            guard AtlasSplitWordPolicy.commonSplitWords.contains(word) else { return false }
        }

        return lexicon.contains(word) && lexicon.frequency(for: word) >= 16_000
    }

    private static let strongTwoLetterSplitWords: Set<String> = [
        "am", "an", "as", "at", "be", "by", "do", "go", "he", "if", "in", "is",
        "it", "me", "my", "no", "of", "on", "or", "so", "to", "up", "us", "we"
    ]

    /// How strongly typing-vs-candidate finger travel is weighted. A single key slip to
    /// an adjacent key (e.g. "hwr" for "her") should clearly out-rank same-frequency
    /// candidates that require a farther reach, so the raw keyboard penalty is amplified.
    private static let keyboardPenaltyWeight = 2.5

    private func typoChannelScore(
        typed: String,
        candidate: String,
        distance: Int,
        keyboardPenalty: Double
    ) -> Double {
        let prefixBoost = AtlasSpellingMetrics.commonPrefixLength(typed, candidate) >= 2 ? 0.25 : 0
        let isTransposition = isAdjacentTransposition(typed, candidate)
        let transpositionBoost = isTransposition ? 2.8 : 0
        // Swapped-letter typos are scored by the transposition boost; their two differing
        // characters are naturally far apart on the keyboard, so charging finger travel on
        // top would wrongly penalise the correct word.
        let effectiveKeyboardPenalty = isTransposition ? 0 : keyboardPenalty * Self.keyboardPenaltyWeight
        return 3.2 - Double(distance) * 1.15 - effectiveKeyboardPenalty + prefixBoost + transpositionBoost
    }

    private func feedbackBoost(
        typed: String,
        candidate: String,
        leftContext: String,
        feedback: AutocorrectFeedbackSnapshot
    ) -> Double {
        let accepted = feedback.acceptedCount(typed: typed, candidate: candidate)
        let rejected = feedback.rejectedCount(typed: typed, candidate: candidate)
        let contextAccepted = feedback.contextAcceptedCount(
            contextKey: Self.contextKey(from: leftContext),
            typed: typed,
            candidate: candidate
        )

        let netAccepted = max(0, accepted - rejected)
        let netRejected = max(0, rejected - accepted)
        let acceptedBoost = min(2.0, log(Double(netAccepted + 1)) * 0.8)
        let contextBoost = min(1.5, log(Double(contextAccepted + 1)) * 0.9)
        let rejectedPenalty = min(3.0, log(Double(netRejected + 1)) * 1.2)
        return acceptedBoost + contextBoost - rejectedPenalty
    }

    static func contextKey(from leftContext: String) -> String {
        leftContext
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .last
            .map { EngramNormalizer.normalize(String($0)) } ?? ""
    }

    private func keyboardDistancePenalty(typed: String, candidate: String) -> Double {
        let typedChars = Array(typed)
        let candidateChars = Array(candidate)
        guard typedChars.count == candidateChars.count else { return 0.25 * Double(abs(typedChars.count - candidateChars.count)) }

        var penalty = 0.0
        for (left, right) in zip(typedChars, candidateChars) where left != right {
            penalty += AtlasQWERTYKeyboard.distancePenalty(from: left, to: right)
        }
        return penalty
    }

    private func isAdjacentTransposition(_ typed: String, _ candidate: String) -> Bool {
        let typedChars = Array(typed)
        let candidateChars = Array(candidate)
        guard typedChars.count == candidateChars.count else { return false }

        var differences: [Int] = []
        for index in typedChars.indices where typedChars[index] != candidateChars[index] {
            differences.append(index)
        }

        guard differences.count == 2,
              differences[1] == differences[0] + 1
        else {
            return false
        }

        let first = differences[0]
        let second = differences[1]
        return typedChars[first] == candidateChars[second] && typedChars[second] == candidateChars[first]
    }

    private func softmax(_ scores: [Double]) -> [Double] {
        guard let maxScore = scores.max() else { return [] }
        let exps = scores.map { exp($0 - maxScore) }
        let total = exps.reduce(0, +)
        guard total > 0 else { return Array(repeating: 0, count: scores.count) }
        return exps.map { $0 / total }
    }

    private static func quickSplitCorrection(
        for word: String,
        lexicon: AtlasQuickSplitLexicon
    ) -> SplitCorrectionCandidate? {
        var ranked: [SplitCorrectionCandidate] = []
        var splitIndex = word.index(word.startIndex, offsetBy: 2)
        let lastSplitIndex = word.index(word.endIndex, offsetBy: -2)
        while splitIndex <= lastSplitIndex {
            let left = String(word[..<splitIndex])
            let right = String(word[splitIndex...])
            let leftCandidates = quickSplitPartCandidates(for: left, lexicon: lexicon)
            let rightCandidates = quickSplitPartCandidates(for: right, lexicon: lexicon)
            for leftCandidate in leftCandidates {
                for rightCandidate in rightCandidates {
                    let totalDistance = leftCandidate.distance + rightCandidate.distance
                    guard totalDistance <= 1 else { continue }
                    let score = log(lexicon.frequency(for: leftCandidate.word))
                        + log(lexicon.frequency(for: rightCandidate.word))
                        - Double(totalDistance) * 0.9
                        - abs(Double(leftCandidate.word.count - rightCandidate.word.count)) * 0.04
                    ranked.append(
                        SplitCorrectionCandidate(
                            replacement: "\(leftCandidate.word) \(rightCandidate.word)",
                            score: score,
                            totalDistance: totalDistance,
                            confidence: 0,
                            margin: 0
                        )
                    )
                }
            }
            splitIndex = word.index(after: splitIndex)
        }

        ranked.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.totalDistance < rhs.totalDistance
        }
        guard var best = ranked.first else { return nil }

        let secondScore = ranked.dropFirst().first?.score ?? (best.score - 1)
        best.margin = best.score - secondScore
        best.confidence = min(0.92, max(0.72, 0.72 + best.margin * 0.06 - Double(best.totalDistance) * 0.04))
        guard best.confidence >= 0.72, best.margin >= 0.10 else { return nil }

        return best
    }

    private static func quickSplitPartCandidates(
        for raw: String,
        lexicon: AtlasQuickSplitLexicon
    ) -> [SplitPartCandidate] {
        var candidates: [SplitPartCandidate] = []

        func append(_ word: String) {
            guard lexicon.isStrongSplitWord(word) else { return }
            candidates.append(
                SplitPartCandidate(
                    word: word,
                    distance: AtlasSpellingMetrics.editDistance(raw, word),
                    keyboardPenalty: 0
                )
            )
        }

        append(raw)
        for word in lexicon.correctionCandidates(for: raw, maxDistance: 1, limit: 8) {
            append(word)
        }

        return candidates
            .filter { $0.distance <= 1 }
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
                return lexicon.frequency(for: lhs.word) > lexicon.frequency(for: rhs.word)
            }
            .prefix(4)
            .map(\.self)
    }
}

private final class AtlasQuickSplitLexicon {
    private static var cachedByBundlePath: [String: AtlasQuickSplitLexicon] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.wooshir.keygram.quick-split-lexicon")

    private let compiled: AtlasCompiledAutocorrectLexicon?

    var isAvailable: Bool {
        compiled != nil
    }

    static func shared(bundle: Bundle) -> AtlasQuickSplitLexicon {
        let key = bundle.bundlePath
        return cacheQueue.sync {
            if let cached = cachedByBundlePath[key] {
                return cached
            }
            let loaded = AtlasQuickSplitLexicon(bundle: bundle)
            cachedByBundlePath[key] = loaded
            return loaded
        }
    }

    private init(bundle: Bundle) {
        compiled = try? AtlasCompiledAutocorrectLexicon(bundle: bundle)
    }

    func isDictionaryWord(_ word: String) -> Bool {
        compiled?.contains(word) == true
    }

    func isProtected(_ word: String) -> Bool {
        compiled?.isProtected(word) == true
    }

    func hasDictionaryWordNear(_ word: String, maxDistance: Int) -> Bool {
        compiled?.correctionCandidates(
            forNormalizedWord: word,
            maxDistance: maxDistance,
            limit: 1
        ).isEmpty == false
    }

    func isStrongSplitWord(_ word: String) -> Bool {
        if word.count == 1 {
            return word == "a" || word == "i"
        }
        if word.count >= 3, !AtlasSplitWordPolicy.commonSplitWords.contains(word) {
            return false
        }
        guard let compiled,
              compiled.contains(word),
              let rank = compiled.candidateRank(for: word)
        else {
            return false
        }
        if word.count == 2 {
            return rank <= 500
        }
        return rank <= AtlasConfiguration.suggestionVocabularyLimit
    }

    func correctionCandidates(for raw: String, maxDistance: Int, limit: Int) -> [String] {
        compiled?.correctionCandidates(
            forNormalizedWord: raw,
            maxDistance: maxDistance,
            limit: limit
        ) ?? []
    }

    func frequency(for word: String) -> Double {
        compiled?.frequency(for: word) ?? 1
    }
}

final class LiveWordDecoder {
    struct Snapshot: Equatable {
        var rawWord: String
        var leftContext: String
        var generation: Int
    }

    private(set) var rawWord = ""
    private var leftContext = ""
    private var generation = 0
    private var cachedDecision: AtlasAutocorrectDecision?

    func append(_ text: String, leftContextBeforeInput: String) {
        guard text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              text.rangeOfCharacter(from: .letters) != nil
        else {
            reset()
            return
        }

        if rawWord.isEmpty {
            leftContext = leftContextBeforeInput
        }
        rawWord.append(contentsOf: text)
        generation += 1
        cachedDecision = nil
    }

    func backspace() {
        guard !rawWord.isEmpty else {
            reset()
            return
        }
        rawWord.removeLast()
        generation += 1
        cachedDecision = nil
        if rawWord.isEmpty {
            leftContext = ""
        }
    }

    func reset() {
        rawWord = ""
        leftContext = ""
        generation += 1
        cachedDecision = nil
    }

    func snapshot() -> Snapshot? {
        guard rawWord.count >= 2 else { return nil }
        return Snapshot(rawWord: rawWord, leftContext: leftContext, generation: generation)
    }

    func storeDecision(_ decision: AtlasAutocorrectDecision?, for snapshot: Snapshot) {
        guard snapshot.generation == generation,
              snapshot.rawWord.localizedCaseInsensitiveCompare(rawWord) == .orderedSame
        else {
            return
        }
        cachedDecision = decision
    }

    func commitDecision(minimumConfidence: Double = 0.55) -> AtlasAutocorrectDecision? {
        guard let cachedDecision,
              cachedDecision.confidence >= minimumConfidence,
              cachedDecision.original.localizedCaseInsensitiveCompare(rawWord) == .orderedSame,
              cachedDecision.replacement.localizedCaseInsensitiveCompare(rawWord) != .orderedSame
        else {
            return nil
        }
        return cachedDecision
    }
}

private struct AtlasAutocorrectToken {
    var rawValue: String

    var normalized: String {
        rawValue
            .trimmingCharacters(in: CharacterSet.letters.inverted.union(CharacterSet(charactersIn: "'")))
            .lowercased()
    }

    func isEligible(in leftContext: String) -> Bool {
        let word = normalized
        guard word.count >= 2 else { return false }
        guard rawValue.rangeOfCharacter(from: .decimalDigits) == nil else { return false }
        guard !rawValue.contains("@"), !rawValue.contains(".") else { return false }
        guard word.rangeOfCharacter(from: .letters) != nil else { return false }
        guard word.rangeOfCharacter(from: CharacterSet.letters.union(CharacterSet(charactersIn: "'")).inverted) == nil else { return false }
        guard !isAllUppercase, !isMixedCaseProtected else { return false }
        guard !isLeadingCapitalProtected || isSentenceInitial(leftContext) else { return false }
        return true
    }

    var isAllUppercase: Bool {
        let letters = rawValue.filter { $0.isLetter }
        guard !letters.isEmpty else { return false }
        return letters.allSatisfy { String($0) == String($0).uppercased() }
    }

    var isMixedCaseProtected: Bool {
        let chars = Array(rawValue)
        guard chars.count > 1 else { return false }
        return chars.dropFirst().contains { $0.isUppercase }
    }

    var isLeadingCapitalProtected: Bool {
        guard rawValue.count >= 2, let first = rawValue.first else { return false }
        return first.isUppercase
    }

    func preserveCase(applying replacement: String) -> String {
        guard rawValue != rawValue.lowercased() else { return replacement }
        if isAllUppercase {
            return replacement.uppercased()
        }
        if let first = rawValue.first, first.isUppercase {
            return replacement.prefix(1).uppercased() + replacement.dropFirst()
        }
        return replacement
    }

    private func isSentenceInitial(_ leftContext: String) -> Bool {
        let trimmed = leftContext.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return true }
        return ".!?".contains(last)
    }
}

private enum AtlasQWERTYKeyboard {
    private static let positions: [Character: (x: Int, y: Int)] = {
        let rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
        var values: [Character: (x: Int, y: Int)] = [:]
        for (y, row) in rows.enumerated() {
            for (x, character) in row.enumerated() {
                values[character] = (x, y)
            }
        }
        return values
    }()

    static func distancePenalty(from lhs: Character, to rhs: Character) -> Double {
        guard let left = positions[Character(String(lhs).lowercased())],
              let right = positions[Character(String(rhs).lowercased())]
        else {
            return 0.6
        }

        let distance = abs(left.x - right.x) + abs(left.y - right.y)
        switch distance {
        case 0:
            return 0
        case 1:
            return 0.1
        case 2:
            return 0.3
        default:
            return 0.55
        }
    }
}

enum AtlasAutocorrectDataLoader {
    nonisolated static func loadWordList(named name: String, bundle: Bundle) -> [String]? {
        guard let data = resourceData(named: name, bundle: bundle) else { return nil }
        if let words = parseJSONWordList(data), !words.isEmpty {
            return words
        }
        if let words = parseTextWordList(data), !words.isEmpty {
            return words
        }
        return nil
    }

    nonisolated static func loadFrequencyTable(named name: String, bundle: Bundle) -> [String: Double]? {
        guard let data = resourceData(named: name, bundle: bundle) else { return nil }
        if let table = parseJSONFrequencyTable(data), !table.isEmpty {
            return normalizeFrequencyTable(table)
        }
        if let table = parseTextFrequencyTable(data), !table.isEmpty {
            return normalizeFrequencyTable(table)
        }
        return nil
    }

    nonisolated static func isPlausibleFrequencyTable(_ table: [String: Double]) -> Bool {
        let topWords = topFrequencyWords(from: table, limit: 10)
        guard topWords.count >= 5 else { return false }
        let expected = Set(["the", "and", "for", "that", "this", "with", "you", "of", "to"])
        return topWords.prefix(10).filter { expected.contains($0) }.count >= 4
    }

    nonisolated static func topFrequencyWords(from table: [String: Double], limit: Int) -> [String] {
        table
            .sorted { lhs, rhs in
                if lhs.value != rhs.value { return lhs.value > rhs.value }
                return lhs.key < rhs.key
            }
            .prefix(limit)
            .map(\.key)
    }

    nonisolated private static func resourceData(named name: String, bundle: Bundle) -> Data? {
        if let url = bundle.url(forResource: name, withExtension: "bin"),
           let data = try? Data(contentsOf: url) {
            return data
        }
        if let url = bundle.url(forResource: "\(name).bin", withExtension: nil),
           let data = try? Data(contentsOf: url) {
            return data
        }
        return nil
    }

    nonisolated private static func parseJSONWordList(_ data: Data) -> [String]? {
        guard data.first == UInt8(ascii: "["),
              let rawWords = try? JSONSerialization.jsonObject(with: data) as? [String]
        else {
            return nil
        }
        let words = rawWords.compactMap(normalizedWord)
        return words.isEmpty ? nil : words
    }

    nonisolated private static func parseJSONFrequencyTable(_ data: Data) -> [String: Double]? {
        guard data.first == UInt8(ascii: "{"),
              let rawTable = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }

        var table: [String: Double] = [:]
        table.reserveCapacity(rawTable.count)
        for (rawWord, rawValue) in rawTable {
            guard let word = normalizedWord(rawWord) else { continue }
            if let value = rawValue as? Double {
                table[word] = value
            } else if let value = rawValue as? Int {
                table[word] = Double(value)
            } else if let value = rawValue as? NSNumber {
                table[word] = value.doubleValue
            }
        }
        return table.isEmpty ? nil : table
    }

    nonisolated private static func parseTextWordList(_ data: Data) -> [String]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        let words = text
            .split(whereSeparator: \.isNewline)
            .compactMap { normalizedWord(String($0)) }
        return words.isEmpty ? nil : words
    }

    nonisolated private static func parseTextFrequencyTable(_ data: Data) -> [String: Double]? {
        guard let text = String(data: data, encoding: .utf8), text.contains("\n") else { return nil }
        var table: [String: Double] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line
                .split { $0 == "," || $0 == "\t" || $0 == " " || $0 == ":" }
                .map(String.init)
            guard parts.count >= 2,
                  let word = normalizedWord(parts[0]),
                  let value = Double(parts[1])
            else {
                continue
            }
            table[word] = value
        }
        return table.isEmpty ? nil : table
    }

    nonisolated private static func normalizeFrequencyTable(_ table: [String: Double]) -> [String: Double] {
        guard let maxValue = table.values.max(), let minValue = table.values.min() else { return table }

        // The generated file is usually rank-based: 1 is the most frequent word.
        // Convert that to larger-is-better so log(frequency) works as a prior.
        if minValue <= 1, maxValue <= Double(table.count * 10) {
            return table.mapValues { max(1, maxValue - $0 + 1) }
        }
        return table
    }

    nonisolated private static func normalizedWord(_ raw: String) -> String? {
        let word = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !word.isEmpty,
              word.count <= 64,
              word.rangeOfCharacter(from: .letters) != nil,
              word.rangeOfCharacter(from: CharacterSet.letters.union(CharacterSet(charactersIn: "'")).inverted) == nil
        else {
            return nil
        }
        return word
    }
}

private final class AtlasAutocorrectLexicon {
    private struct RuntimeStorage {
        var wordSet: Set<String>
        var completionWords: [String]
        var deleteIndexByKey: [String: [String]]
        var frequencies: [String: Double]
        var diagnosticsDescription: String
    }

    private enum Storage {
        case compiled(AtlasCompiledAutocorrectLexicon)
        case runtime(RuntimeStorage)
    }

    private let storage: Storage
    let diagnosticsDescription: String

    init(bundle: Bundle = .main) {
        do {
            let compiled = try AtlasCompiledAutocorrectLexicon(bundle: bundle)
            storage = .compiled(compiled)
            diagnosticsDescription = compiled.diagnosticsDescription
            return
        } catch {
            let runtime = Self.makeRuntimeStorage(bundle: bundle)
            storage = .runtime(runtime)
            diagnosticsDescription = "runtimeFallback=true reason=\(error); \(runtime.diagnosticsDescription)"
        }
    }

    private static func makeRuntimeStorage(bundle: Bundle) -> RuntimeStorage {
        var mergedFrequencies = Self.seedFrequencies
        let loadedFrequencyTable = AtlasAutocorrectDataLoader.loadFrequencyTable(named: "frequency_table", bundle: bundle)
        let frequencyTableStatus: String
        if let loadedFrequencyTable,
           AtlasAutocorrectDataLoader.isPlausibleFrequencyTable(loadedFrequencyTable) {
            for (word, frequency) in loadedFrequencyTable {
                mergedFrequencies[word, default: frequency] = max(mergedFrequencies[word] ?? 0, frequency)
            }
            let topWords = AtlasAutocorrectDataLoader.topFrequencyWords(from: loadedFrequencyTable, limit: 5).joined(separator: ",")
            frequencyTableStatus = "loaded entries=\(loadedFrequencyTable.count) top=\(topWords)"
        } else if let loadedFrequencyTable {
            frequencyTableStatus = "rejected entries=\(loadedFrequencyTable.count)"
        } else {
            frequencyTableStatus = "missing"
        }

        for word in EngramNormalizer.commonWordsForAutocorrect {
            mergedFrequencies[word, default: 22_000] = max(mergedFrequencies[word] ?? 0, 22_000)
        }
        for word in Self.additionalCommonWords {
            mergedFrequencies[word, default: 16_000] = max(mergedFrequencies[word] ?? 0, 16_000)
        }

        var importedWords = AtlasAutocorrectDataLoader.loadWordList(named: "english_words", bundle: bundle) ?? []
        let importedDictionaryCount = importedWords.count
        importedWords.append(contentsOf: mergedFrequencies.keys)
        let dictionaryWords = Self.orderedUnique(importedWords.filter(Self.isUsableWord)).sorted()
        let dictionaryWordSet = Set(dictionaryWords)

        var importedCandidateWords = AtlasAutocorrectDataLoader.loadWordList(named: "english_bktree_words", bundle: bundle) ?? []
        let importedCandidateCount = importedCandidateWords.count
        importedCandidateWords.append(contentsOf: Self.seedFrequencies.keys)
        importedCandidateWords.append(contentsOf: Self.additionalCommonWords)
        importedCandidateWords.append(contentsOf: EngramNormalizer.commonWordsForAutocorrect)
        let candidateWords = Self.orderedUnique(importedCandidateWords.filter(Self.isUsableCandidate))
            .filter { dictionaryWordSet.contains($0) || mergedFrequencies[$0] != nil }

        let candidateCount = candidateWords.count
        for (index, word) in candidateWords.enumerated() {
            let rankScore = Double(max(1, candidateCount - index))
            mergedFrequencies[word, default: rankScore] = max(mergedFrequencies[word] ?? 0, rankScore)
        }

        var deleteIndex: [String: [String]] = [:]
        for word in candidateWords {
            for key in Self.deletionKeys(for: word, maxDeletes: 1) {
                deleteIndex[key, default: []].append(word)
            }
        }
        return RuntimeStorage(
            wordSet: dictionaryWordSet,
            completionWords: candidateWords,
            deleteIndexByKey: deleteIndex,
            frequencies: mergedFrequencies,
            diagnosticsDescription: "dictionary=english_words.bin entries=\(importedDictionaryCount) usable=\(dictionaryWords.count); candidates=english_bktree_words.bin entries=\(importedCandidateCount) usable=\(candidateWords.count); frequency_table.bin \(frequencyTableStatus)"
        )
    }

    func contains(_ word: String) -> Bool {
        switch storage {
        case .compiled(let compiled):
            compiled.contains(word)
        case .runtime(let runtime):
            runtime.wordSet.contains(word)
        }
    }

    func isProtected(_ word: String) -> Bool {
        switch storage {
        case .compiled(let compiled):
            compiled.isProtected(word)
        case .runtime:
            false
        }
    }

    func frequency(for word: String) -> Double {
        switch storage {
        case .compiled(let compiled):
            compiled.frequency(for: word)
        case .runtime(let runtime):
            max(1, runtime.frequencies[word] ?? 8)
        }
    }

    func completions(for prefix: String, limit: Int) -> [String] {
        let normalized = AtlasAutocorrectToken(rawValue: prefix).normalized
        guard normalized.count >= 1 else { return [] }
        switch storage {
        case .compiled(let compiled):
            return compiled.completions(forNormalizedPrefix: normalized, limit: limit)
        case .runtime(let runtime):
            return Array(
                runtime.completionWords
                    .lazy
                    .filter { $0.hasPrefix(normalized) && $0 != normalized }
                    .prefix(limit)
            )
        }
    }

    func correctionCandidates(for word: String, maxDistance: Int, limit: Int) -> [String] {
        if case .compiled(let compiled) = storage {
            return compiled.correctionCandidates(forNormalizedWord: word, maxDistance: maxDistance, limit: limit)
        }

        guard case .runtime(let runtime) = storage else { return [] }
        var results: [(word: String, distance: Int)] = []
        results.reserveCapacity(limit)
        var seen = Set<String>()

        for key in Self.deletionKeys(for: word, maxDeletes: min(maxDistance, 1)) {
            for candidate in runtime.deleteIndexByKey[key] ?? [] where seen.insert(candidate).inserted {
                guard candidate != word, abs(candidate.count - word.count) <= maxDistance else { continue }
                guard let distance = AtlasSpellingMetrics.editDistance(candidate, word, maxDistance: maxDistance) else { continue }
                results.append((candidate, distance))
            }
        }

        return sortedCandidates(results, limit: limit)
    }

    private func sortedCandidates(_ results: [(word: String, distance: Int)], limit: Int) -> [String] {
        return results
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
                return frequency(for: lhs.word) > frequency(for: rhs.word)
            }
            .prefix(limit)
            .map(\.word)
    }

    private static func deletionKeys(for word: String, maxDeletes: Int) -> Set<String> {
        let characters = Array(word)
        guard !characters.isEmpty else { return [] }

        var keys: Set<String> = [word]
        var frontier: Set<String> = [word]
        guard maxDeletes > 0 else { return keys }

        for _ in 0..<maxDeletes {
            var next: Set<String> = []
            for value in frontier {
                let valueCharacters = Array(value)
                guard valueCharacters.count > 1 else { continue }
                for index in valueCharacters.indices {
                    var deleted = valueCharacters
                    deleted.remove(at: index)
                    let key = String(deleted)
                    if keys.insert(key).inserted {
                        next.insert(key)
                    }
                }
            }
            frontier = next
            if frontier.isEmpty { break }
        }

        return keys
    }

    nonisolated private static func isUsableWord(_ word: String) -> Bool {
        word.count >= 1
            && word.count <= 24
            && word.rangeOfCharacter(from: .letters) != nil
            && word.rangeOfCharacter(from: CharacterSet.letters.union(CharacterSet(charactersIn: "'")).inverted) == nil
    }

    nonisolated private static func isUsableCandidate(_ word: String) -> Bool {
        word.count >= 2 && isUsableWord(word)
    }

    private static func orderedUnique(_ words: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        result.reserveCapacity(words.count)
        for word in words where seen.insert(word).inserted {
            result.append(word)
        }
        return result
    }

    private static let seedFrequencies: [String: Double] = [
        "a": 50000, "about": 35000, "after": 32000, "again": 24000, "all": 50000,
        "also": 42000, "am": 45000, "amazing": 9500, "an": 46000, "and": 80000,
        "are": 65000, "as": 62000, "ask": 19000, "at": 69000, "atlas": 12000,
        "be": 70000, "because": 37000, "been": 42000, "before": 30000, "but": 67000,
        "by": 52000, "can": 52000, "check": 24000, "come": 25000, "could": 40000,
        "day": 33000, "definitely": 21000, "did": 36000, "dinner": 12000, "do": 62000,
        "does": 29000, "doing": 26000, "done": 26000, "don't": 36000, "draft": 9000,
        "email": 16000, "for": 76000, "forget": 18000, "forward": 13000, "from": 62000,
        "get": 48000, "github": 11000, "gmail": 10000, "gnat": 1200, "go": 40000,
        "going": 39000, "good": 43000, "great": 30000, "had": 42000, "has": 44000,
        "have": 68000, "he": 49000, "her": 37000, "here": 30000, "him": 26000,
        "his": 38000, "how": 39000, "i": 90000, "if": 50000, "in": 80000,
        "ios": 9000, "is": 78000, "it": 74000, "json": 9000, "just": 42000,
        "keyboard": 11000, "know": 43000, "knot": 3200, "later": 23000, "like": 48000,
        "london": 10000, "made": 26000, "make": 36000, "me": 52000, "meeting": 18000,
        "message": 16000, "my": 59000, "need": 43000, "no": 48000, "not": 62000,
        "now": 42000, "of": 79000, "okay": 26000, "on": 69000, "one": 50000,
        "or": 56000, "our": 38000, "please": 36000, "probably": 21000, "qbr": 7000,
        "report": 22000, "reservation": 9000, "right": 36000, "said": 36000,
        "sarita": 8000, "see": 38000, "send": 26000, "session": 9000, "she": 44000,
        "so": 59000, "swift": 12000, "swiftui": 10000, "than": 43000, "thanks": 30000,
        "that": 72000, "the": 100000, "their": 42000, "them": 40000, "then": 36000,
        "there": 46000, "they": 53000, "thing": 27000, "think": 36000, "this": 70000,
        "time": 47000, "to": 90000, "today": 30000, "tomorrow": 24000, "tonight": 22000,
        "travel": 12000, "use": 32000, "virat": 9000, "want": 52000, "wart": 900,
        "was": 62000, "we": 64000, "well": 37000, "were": 47000, "what": 52000,
        "when": 41000, "where": 36000, "who": 38000, "will": 60000, "with": 70000,
        "work": 35000, "would": 47000, "xcode": 10000, "yeah": 26000, "you": 85000,
        "your": 57000
    ]

    private static let additionalCommonWords: Set<String> = [
        "accept", "account", "across", "actually", "add", "address", "ago", "air",
        "allow", "answer", "app", "appear", "around", "arrive", "away", "baby",
        "bank", "base", "believe", "best", "better", "book", "bring", "build",
        "business", "buy", "care", "change", "chat", "city", "class", "clear",
        "close", "company", "complete", "copy", "correct", "create", "current",
        "date", "different", "early", "easy", "else", "enough", "every", "example",
        "expect", "explain", "family", "far", "fast", "file", "follow", "food",
        "friend", "full", "game", "given", "group", "guess", "hand", "happen",
        "hard", "head", "help", "home", "house", "idea", "important", "inside",
        "issue", "job", "keep", "kind", "last", "learn", "leave", "less", "life",
        "line", "list", "live", "long", "look", "lot", "love", "man", "maybe",
        "mean", "mind", "minute", "money", "month", "morning", "move", "name",
        "night", "open", "order", "page", "part", "pay", "person", "phone",
        "pick", "place", "plan", "play", "problem", "project", "put", "question",
        "read", "ready", "real", "reason", "remember", "reply", "run", "same",
        "school", "second", "show", "side", "since", "someone", "something",
        "soon", "sorry", "speak", "start", "state", "stay", "stop", "story",
        "study", "system", "take", "talk", "tell", "test", "thank", "these",
        "thought", "together", "told", "took", "true", "turn", "type", "understand",
        "until", "wait", "walk", "watch", "water", "week", "while", "word", "world",
        "write", "wrong", "yesterday"
    ]
}

private enum AtlasSplitWordPolicy {
    static let commonSplitWords: Set<String> = EngramNormalizer.commonWordsForAutocorrect.union([
        "accept", "account", "actually", "address", "answer", "around", "away",
        "baby", "believe", "birthday", "business", "change", "class", "company",
        "complete", "correct", "different", "enough", "every", "family", "friend",
        "happy", "happen", "important", "inside", "learn", "leave", "maybe",
        "minute", "money", "morning", "night", "person", "phone", "problem",
        "project", "question", "ready", "reason", "remember", "reply", "school",
        "someone", "something", "sorry", "speak", "story", "study", "system",
        "thank", "thanks", "together", "tomorrow", "understand", "until",
        "wait", "water", "while", "world", "write", "wrong", "yesterday"
    ])
}

private final class AtlasBKTreeUnused {
    private final class Node {
        let word: String
        var children: [Int: Node] = [:]

        init(word: String) {
            self.word = word
        }
    }

    private var rootsByLength: [Int: Node] = [:]

    init(words: [String]) {
        for word in words {
            insert(word)
        }
    }

    func search(_ word: String, maxDistance: Int, limit: Int) -> [String] {
        var results: [(word: String, distance: Int)] = []
        for length in (word.count - maxDistance)...(word.count + maxDistance) {
            guard let root = rootsByLength[length] else { continue }
            search(node: root, word: word, maxDistance: maxDistance, results: &results)
        }

        return results
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
                return lhs.word < rhs.word
            }
            .prefix(limit)
            .map(\.word)
    }

    private func insert(_ word: String) {
        let length = word.count
        guard let root = rootsByLength[length] else {
            rootsByLength[length] = Node(word: word)
            return
        }

        var node = root
        while true {
            let distance = AtlasSpellingMetrics.editDistance(word, node.word)
            if distance == 0 { return }
            if let child = node.children[distance] {
                node = child
            } else {
                node.children[distance] = Node(word: word)
                return
            }
        }
    }

    private func search(node: Node, word: String, maxDistance: Int, results: inout [(word: String, distance: Int)]) {
        let distance = AtlasSpellingMetrics.editDistance(word, node.word)
        if distance <= maxDistance {
            results.append((node.word, distance))
        }

        let lower = distance - maxDistance
        let upper = distance + maxDistance
        for (edge, child) in node.children where edge >= lower && edge <= upper {
            search(node: child, word: word, maxDistance: maxDistance, results: &results)
        }
    }
}

private extension Array where Element == String {
    func binarySearch(_ value: String) -> Bool {
        var lower = startIndex
        var upper = endIndex
        while lower < upper {
            let middle = lower + distance(from: lower, to: upper) / 2
            if self[middle] == value {
                return true
            }
            if self[middle] < value {
                lower = middle + 1
            } else {
                upper = middle
            }
        }
        return false
    }
}
