import Foundation

protocol AtlasTokenizing {
    func encodeLatestTokens(from context: String) -> [Int64]
    func candidateScores(from logits: [Float], limit: Int) -> [String: Double]
    func vocabularyWords() -> [String]
    func tokenIDs(forWord word: String) -> [Int]
    func resetTokenizationState()
}

extension AtlasTokenizing {
    func tokenIDs(forWord word: String) -> [Int] {
        []
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

    init(extraWords: [String] = []) {
        let seedWords = [
        "about", "after", "amazing", "atlas", "because", "before", "definitely",
        "check", "dinner", "draft", "forward", "great", "keyboard", "meeting", "personal", "probably",
        "qbr", "report", "reservation", "sarita", "session", "thanks", "today",
        "tomorrow", "tonight", "travel", "work", "you"
        ]
        let merged = Set(seedWords + extraWords.map { $0.lowercased() })
        words = merged.sorted()
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
        words.contains(word.lowercased())
    }

    func allWords() -> [String] {
        words
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

    static func commonPrefixLength(_ lhs: String, _ rhs: String) -> Int {
        var count = 0
        for (left, right) in zip(lhs, rhs) {
            guard left == right else { break }
            count += 1
        }
        return count
    }
}
