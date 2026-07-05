import Foundation

final class AtlasSuggestionRanker {
    func rank(
        logits: [String: Double],
        partialWord: String?,
        vocabulary: AtlasVocabularyIndex,
        context: String,
        sessionEngram: Engram,
        globalEngram: Engram
    ) -> [AtlasSuggestion] {
        if let partialWord, !partialWord.isEmpty {
            let lowerPartial = partialWord.lowercased()
            let completions = Set(
                vocabulary.completions(for: lowerPartial)
                + sessionEngram.completions(matching: lowerPartial)
                + globalEngram.completions(matching: lowerPartial)
                + logits.keys.filter {
                $0.lowercased().hasPrefix(lowerPartial) && $0.lowercased() != lowerPartial
                }
            )
            let ranked = completions.map {
                scoredSuggestion($0, kind: .completion, logits: logits, context: context, sessionEngram: sessionEngram, globalEngram: globalEngram)
            }
            let topCompletions = ranked.sorted { $0.score > $1.score }
            if !topCompletions.isEmpty {
                return Array(topCompletions.prefix(AtlasConfiguration.maxSuggestions))
            }
        }

        var candidates = logits.keys.map {
            scoredSuggestion($0, kind: .nextWord, logits: logits, context: context, sessionEngram: sessionEngram, globalEngram: globalEngram)
        }
        candidates += sessionEngram.relevantWords(for: context).map {
            scoredSuggestion($0.word, kind: .personal, logits: logits, context: context, sessionEngram: sessionEngram, globalEngram: globalEngram)
        }
        candidates += globalEngram.relevantWords(for: context).map {
            scoredSuggestion($0.word, kind: .personal, logits: logits, context: context, sessionEngram: sessionEngram, globalEngram: globalEngram)
        }

        let deduped = Dictionary(grouping: candidates, by: \.text).compactMap { $0.value.max { $0.score < $1.score } }
        return Array(deduped.sorted { $0.score > $1.score }.prefix(AtlasConfiguration.maxSuggestions))
    }

    func rankCorrections(
        for selectedWord: String,
        leftContext: String,
        rightContext: String,
        prefixLogits: [String: Double],
        fullWordLogits: [String: Double],
        vocabulary: AtlasVocabularyIndex,
        sessionEngram: Engram,
        globalEngram: Engram
    ) -> [AtlasSuggestion] {
        let normalized = EngramNormalizer.normalize(selectedWord)
        guard isCorrectable(normalized) else { return [] }

        let maxDistance = max(2, min(4, normalized.count / 3))
        var candidates = Set<String>()
        candidates.formUnion(vocabulary.correctionCandidates(for: normalized, maxDistance: maxDistance))
        candidates.formUnion(sessionEngram.correctionCandidates(for: normalized, maxDistance: maxDistance))
        candidates.formUnion(globalEngram.correctionCandidates(for: normalized, maxDistance: maxDistance))
        candidates.formUnion(contextualCorrectionCandidates(from: prefixLogits.keys, for: normalized, maxDistance: maxDistance))
        candidates.formUnion(contextualCorrectionCandidates(from: fullWordLogits.keys, for: normalized, maxDistance: maxDistance))

        for prefixLength in correctionPrefixLengths(for: normalized) {
            let prefix = String(normalized.prefix(prefixLength))
            candidates.formUnion(vocabulary.completions(for: prefix).filter {
                isSimilarLength($0, to: normalized, maxDistance: maxDistance)
            })
        }

        let ranked = candidates.compactMap { candidate -> AtlasSuggestion? in
            let candidate = EngramNormalizer.normalize(candidate)
            guard isUsableCorrectionCandidate(candidate, for: normalized, maxDistance: maxDistance, prefixLogits: prefixLogits, fullWordLogits: fullWordLogits) else {
                return nil
            }

            let editDistance = AtlasSpellingMetrics.editDistance(candidate, normalized)
            let spellingScore = max(0, 1.0 - Double(editDistance) / Double(max(candidate.count, normalized.count)))
            let prefixScore = Double(min(4, AtlasSpellingMetrics.commonPrefixLength(candidate, normalized))) / 4.0
            let modelScore = max(
                normalizedModelScore(for: candidate, in: prefixLogits),
                normalizedModelScore(for: candidate, in: fullWordLogits)
            )
            let engramBias = sessionEngram.bias(for: candidate, context: leftContext)
                + globalEngram.bias(for: candidate, context: leftContext) * 0.75
            let lengthPenalty = Double(abs(candidate.count - normalized.count)) * 0.05
            let validWordPenalty = vocabulary.contains(normalized) ? 0.45 : 0
            let strongModelBoost = modelScore > 0.7 ? 0.15 : 0

            let score = modelScore * 0.45
                + spellingScore * 0.3
                + prefixScore * 0.15
                + engramBias * 0.1
                + strongModelBoost
                - lengthPenalty
                - validWordPenalty

            guard score > 0.32 else { return nil }
            return AtlasSuggestion(
                text: preserveCase(from: selectedWord, applyingTo: candidate),
                kind: .correction,
                score: score
            )
        }

        let deduped = Dictionary(grouping: ranked, by: { $0.text.lowercased() })
            .compactMap { $0.value.max { $0.score < $1.score } }
        return Array(deduped.sorted { $0.score > $1.score }.prefix(AtlasConfiguration.maxSuggestions))
    }

    private func scoredSuggestion(
        _ word: String,
        kind: AtlasSuggestionKind,
        logits: [String: Double],
        context: String,
        sessionEngram: Engram,
        globalEngram: Engram
    ) -> AtlasSuggestion {
        let base = logits[word] ?? 0.12
        let engramBias = sessionEngram.bias(for: word, context: context) + globalEngram.bias(for: word, context: context) * 0.75
        let isEngramWord = sessionEngram.containsConfirmed(word) || globalEngram.containsConfirmed(word)
        return AtlasSuggestion(text: word, kind: isEngramWord ? .personal : kind, score: base + engramBias)
    }

    private func isCorrectable(_ word: String) -> Bool {
        word.count >= 3
            && word.rangeOfCharacter(from: .letters) != nil
            && word.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil
    }

    private func correctionPrefixLengths(for word: String) -> [Int] {
        let maximum = min(3, word.count)
        guard maximum > 0 else { return [] }
        return Array(1...maximum).reversed()
    }

    private func isSimilarLength(_ candidate: String, to word: String, maxDistance: Int) -> Bool {
        abs(candidate.count - word.count) <= maxDistance + 2
    }

    private func isUsableCorrectionCandidate(
        _ candidate: String,
        for word: String,
        maxDistance: Int,
        prefixLogits: [String: Double],
        fullWordLogits: [String: Double]
    ) -> Bool {
        guard candidate != word, isCorrectable(candidate), isSimilarLength(candidate, to: word, maxDistance: maxDistance) else {
            return false
        }

        let editDistance = AtlasSpellingMetrics.editDistance(candidate, word)
        let commonPrefix = AtlasSpellingMetrics.commonPrefixLength(candidate, word)
        let modelScore = max(
            normalizedModelScore(for: candidate, in: prefixLogits),
            normalizedModelScore(for: candidate, in: fullWordLogits)
        )
        return editDistance <= maxDistance
            || commonPrefix >= min(2, word.count)
            || (candidate.first == word.first && modelScore > 0.75 && editDistance <= maxDistance + 2)
    }

    private func contextualCorrectionCandidates(
        from words: Dictionary<String, Double>.Keys,
        for typo: String,
        maxDistance: Int
    ) -> [String] {
        words.filter { candidate in
            let normalized = EngramNormalizer.normalize(candidate)
            guard normalized.first == typo.first else { return false }
            guard isSimilarLength(normalized, to: typo, maxDistance: maxDistance) else { return false }
            return AtlasSpellingMetrics.editDistance(normalized, typo) <= maxDistance + 1
                || AtlasSpellingMetrics.commonPrefixLength(normalized, typo) >= min(3, typo.count)
        }
    }

    private func normalizedModelScore(for candidate: String, in logits: [String: Double]) -> Double {
        guard let rawScore = logits[candidate] else { return 0 }
        guard let bestScore = logits.values.max() else { return 0 }
        if bestScore <= 0 {
            return exp(max(-8, rawScore - bestScore))
        }
        return max(0, min(1, rawScore / bestScore))
    }

    private func preserveCase(from original: String, applyingTo candidate: String) -> String {
        guard original != original.lowercased() else { return candidate }
        if original == original.uppercased() {
            return candidate.uppercased()
        }
        if let first = original.first, String(first) == String(first).uppercased() {
            return candidate.prefix(1).uppercased() + candidate.dropFirst()
        }
        return candidate
    }
}

enum PartialWordDetector {
    static func partialWord(in text: String) -> String? {
        guard let last = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).last else {
            return nil
        }
        let word = String(last).trimmingCharacters(in: CharacterSet.letters.inverted)
        return text.last?.isWhitespace == true ? nil : word
    }

    static func lastCompletedWord(in text: String) -> String? {
        guard text.last?.isWhitespace == true else { return nil }
        return text.split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .last
            .map(String.init)
    }
}
