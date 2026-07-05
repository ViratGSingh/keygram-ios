import Foundation

protocol AtlasTokenizing {
    func encodeLatestTokens(from context: String) -> [Int64]
    func candidateScores(from logits: [Float], limit: Int) -> [String: Double]
    func vocabularyWords() -> [String]
    func tokenIDs(forWord word: String) -> [Int]
    func tokenPiece(forTokenID tokenID: Int) -> String?
    func candidateScores(from logits: [Float], candidates: [String]) -> [String: Double]
    func resetTokenizationState()
}

extension AtlasTokenizing {
    func tokenIDs(forWord word: String) -> [Int] {
        []
    }

    func tokenPiece(forTokenID tokenID: Int) -> String? {
        nil
    }

    func candidateScores(from logits: [Float], candidates: [String]) -> [String: Double] {
        var scores: [String: Double] = [:]
        for candidate in candidates {
            guard let firstTokenID = tokenIDs(forWord: candidate).first,
                  logits.indices.contains(firstTokenID)
            else {
                continue
            }
            scores[candidate] = Double(logits[firstTokenID])
        }
        return scores
    }

    func resetTokenizationState() {}
}

final class AtlasTokenizer: AtlasTokenizing {
    private var lastContext = ""

    func encodeLatestTokens(from context: String) -> [Int64] {
        defer { lastContext = context }
        guard context.hasPrefix(lastContext) else {
            return context.unicodeScalars.suffix(8).map { Int64($0.value % UInt32(AtlasConfiguration.vocabularySize)) }
        }

        let delta = context.dropFirst(lastContext.count)
        return delta.unicodeScalars.map { Int64($0.value % UInt32(AtlasConfiguration.vocabularySize)) }
    }

    func candidateScores(from logits: [Float], limit: Int) -> [String: Double] {
        [:]
    }

    func vocabularyWords() -> [String] {
        []
    }

    func resetTokenizationState() {
        lastContext = ""
    }
}

final class AtlasVocabularyIndex {
    private let words: [String]
    private let wordSet: Set<String>
    private let fallbackScoresByWord: [String: Double]
    private let fallbackProbabilitiesByWord: [String: Double]
    let diagnosticsDescription: String

    init(bundle: Bundle = .main, extraWords: [String] = []) {
        let overlayWords = EngramNormalizer.commonWordsForAutocorrect.map { $0.lowercased() }
            + extraWords.map { $0.lowercased() }

        if let compiled = try? AtlasCompiledAutocorrectLexicon(bundle: bundle) {
            let ranked = compiled.rankedCandidates(limit: AtlasConfiguration.suggestionVocabularyLimit)
            let rankedWords = ranked.map(\.word)
            let frequencyByWord = Dictionary(uniqueKeysWithValues: ranked.map { ($0.word, $0.frequency) })
            let mergedWords = Self.orderedUnique(rankedWords + overlayWords)
            let maxFrequency = ranked.map(\.frequency).max() ?? Double(max(mergedWords.count, 1))
            let rawScores = Dictionary(
                uniqueKeysWithValues: mergedWords.enumerated().map { index, word in
                    let rawScore = frequencyByWord[word] ?? Double(max(mergedWords.count - index, 1))
                    return (word, max(rawScore, 1))
                }
            )
            let totalFrequency = max(rawScores.values.reduce(0, +), 1)

            words = mergedWords
            wordSet = Set(mergedWords)
            fallbackScoresByWord = Dictionary(
                uniqueKeysWithValues: mergedWords.map { word in
                    let rawScore = rawScores[word] ?? 1
                    return (word, max(0.05, min(1.0, rawScore / maxFrequency)))
                }
            )
            fallbackProbabilitiesByWord = Dictionary(
                uniqueKeysWithValues: mergedWords.map { word in
                    (word, (rawScores[word] ?? 1) / totalFrequency)
                }
            )
            diagnosticsDescription = "source=compiled autocorrect lexicon limit=\(AtlasConfiguration.suggestionVocabularyLimit) words=\(mergedWords.count); tokenizerOverlay=\(extraWords.count)"
            return
        }

        let frequencyTable = AtlasAutocorrectDataLoader.loadFrequencyTable(named: "frequency_table", bundle: bundle)
        let frequencyTableIsValid = frequencyTable.map(AtlasAutocorrectDataLoader.isPlausibleFrequencyTable) ?? false
        let importedWords = AtlasAutocorrectDataLoader.loadWordList(named: "english_words", bundle: bundle) ?? []
        let importedWordSet = Set(importedWords)
        let rankedDictionaryWords: [String]
        let frequencyStatus: String

        if let frequencyTable, frequencyTableIsValid {
            rankedDictionaryWords = AtlasAutocorrectDataLoader
                .topFrequencyWords(from: frequencyTable, limit: frequencyTable.count)
                .filter { importedWordSet.contains($0) }
                .prefix(AtlasConfiguration.suggestionVocabularyLimit)
                .map(\.self)
            let topWords = Array(rankedDictionaryWords.prefix(5)).joined(separator: ",")
            frequencyStatus = "loaded entries=\(frequencyTable.count) top=\(topWords)"
        } else if let frequencyTable {
            rankedDictionaryWords = Array(importedWords.prefix(AtlasConfiguration.suggestionVocabularyLimit))
            frequencyStatus = "rejected entries=\(frequencyTable.count); fallback=english_words order"
        } else {
            rankedDictionaryWords = Array(importedWords.prefix(AtlasConfiguration.suggestionVocabularyLimit))
            frequencyStatus = "missing; fallback=english_words order"
        }

        let merged = Self.orderedUnique(rankedDictionaryWords + overlayWords)
        let mergedWords = merged
        words = mergedWords
        wordSet = Set(mergedWords)

        let maxFrequency = frequencyTable?.values.max() ?? Double(max(mergedWords.count, 1))
        let rawScores = Dictionary(
            uniqueKeysWithValues: mergedWords.enumerated().map { index, word in
                let rawScore = frequencyTable?[word] ?? Double(max(mergedWords.count - index, 1))
                return (word, max(rawScore, 1))
            }
        )
        let totalFrequency = max(rawScores.values.reduce(0, +), 1)
        fallbackScoresByWord = Dictionary(
            uniqueKeysWithValues: mergedWords.map { word in
                let rawScore = rawScores[word] ?? 1
                let score = max(0.05, min(1.0, rawScore / maxFrequency))
                return (word, score)
            }
        )
        fallbackProbabilitiesByWord = Dictionary(
            uniqueKeysWithValues: mergedWords.map { word in
                (word, (rawScores[word] ?? 1) / totalFrequency)
            }
        )
        diagnosticsDescription = "source=frequency-ranked english_words.bin limit=\(AtlasConfiguration.suggestionVocabularyLimit) words=\(mergedWords.count); frequency_table.bin \(frequencyStatus); tokenizerOverlay=\(extraWords.count)"
    }

    func completions(for prefix: String) -> [String] {
        guard !prefix.isEmpty else { return words }
        let lower = prefix.lowercased()
        return words.filter { $0.hasPrefix(lower) && $0 != lower }
    }

    func correctionCandidates(for word: String) -> [String] {
        correctionCandidates(for: word, maxDistance: 2)
    }

    func correctionCandidates(for word: String, maxDistance: Int) -> [String] {
        let lower = word.lowercased()
        return words.filter { candidate in
            candidate != lower && AtlasSpellingMetrics.editDistance(candidate, lower) <= maxDistance
        }
    }

    func contains(_ word: String) -> Bool {
        wordSet.contains(word.lowercased())
    }

    func allWords() -> [String] {
        words
    }

    func fallbackScores(limit: Int) -> [String: Double] {
        Dictionary(
            uniqueKeysWithValues: words.prefix(limit).compactMap { word in
                fallbackScoresByWord[word].map { (word, $0) }
            }
        )
    }

    func frequencyProbability(for word: String) -> Double {
        fallbackProbabilitiesByWord[word.lowercased()]
            ?? 1.0 / Double(max(words.count * 20, 1))
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
}

enum AtlasSpellingMetrics {
    static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs)
        let b = Array(rhs)
        guard !a.isEmpty else { return b.count }
        guard !b.isEmpty else { return a.count }

        var distance = Array(
            repeating: Array(repeating: 0, count: b.count + 1),
            count: a.count + 1
        )

        for i in 0...a.count {
            distance[i][0] = i
        }
        for j in 0...b.count {
            distance[0][j] = j
        }

        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                distance[i][j] = min(
                    distance[i - 1][j] + 1,
                    distance[i][j - 1] + 1,
                    distance[i - 1][j - 1] + cost
                )

                if i > 1,
                   j > 1,
                   a[i - 1] == b[j - 2],
                   a[i - 2] == b[j - 1] {
                    distance[i][j] = min(distance[i][j], distance[i - 2][j - 2] + 1)
                }
            }
        }

        return distance[a.count][b.count]
    }

    static func editDistance(_ lhs: String, _ rhs: String, maxDistance: Int) -> Int? {
        let a = Array(lhs)
        let b = Array(rhs)
        guard abs(a.count - b.count) <= maxDistance else { return nil }
        guard !a.isEmpty else { return b.count <= maxDistance ? b.count : nil }
        guard !b.isEmpty else { return a.count <= maxDistance ? a.count : nil }

        var previousPrevious = Array(repeating: 0, count: b.count + 1)
        var previous = Array(0...b.count)
        var current = Array(repeating: 0, count: b.count + 1)

        for i in 1...a.count {
            current[0] = i
            var rowMinimum = current[0]

            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                var value = min(
                    previous[j] + 1,
                    current[j - 1] + 1,
                    previous[j - 1] + cost
                )

                if i > 1,
                   j > 1,
                   a[i - 1] == b[j - 2],
                   a[i - 2] == b[j - 1] {
                    value = min(value, previousPrevious[j - 2] + 1)
                }

                current[j] = value
                rowMinimum = min(rowMinimum, value)
            }

            guard rowMinimum <= maxDistance else { return nil }
            previousPrevious = previous
            previous = current
        }

        let distance = previous[b.count]
        return distance <= maxDistance ? distance : nil
    }

    static func commonPrefixLength(_ lhs: String, _ rhs: String) -> Int {
        var count = 0
        for (left, right) in zip(lhs, rhs) {
            guard left == right else { break }
            count += 1
        }
        return count
    }
}
