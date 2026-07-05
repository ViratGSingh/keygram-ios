import Foundation

#if canImport(SentencepieceTokenizer)
import SentencepieceTokenizer

final class AtlasSentencePieceTokenizer: AtlasTokenizing {
    private let tokenizer: SentencepieceTokenizer
    private var lastContext = ""

    init(bundle: Bundle = .main) throws {
        let modelBundle = try AtlasModelBundle.resolve(in: bundle)
        tokenizer = try SentencepieceTokenizer(modelPath: modelBundle.tokenizerURL.path, tokenOffset: 0)
    }

    func encodeLatestTokens(from context: String) -> [Int64] {
        defer { lastContext = context }
        guard context.hasPrefix(lastContext) else {
            return (try? tokenizer.encode(context).map(Int64.init)) ?? []
        }

        let delta = String(context.dropFirst(lastContext.count))
        guard !delta.isEmpty else { return [] }
        return (try? tokenizer.encode(delta).map(Int64.init)) ?? []
    }

    func candidateScores(from logits: [Float], limit: Int) -> [String: Double] {
        let ranked = logits.indices.sorted { logits[$0] > logits[$1] }

        var scores: [String: Double] = [:]
        for index in ranked {
            guard let word = displayWord(forTokenID: index, requireWordBoundary: true) else { continue }
            scores[word] = max(scores[word] ?? -.infinity, Double(logits[index]))
            if scores.count == limit {
                break
            }
        }
        return scores
    }

    func vocabularyWords() -> [String] {
        var words: Set<String> = []
        for index in 0..<AtlasConfiguration.vocabularySize {
            guard let word = displayWord(forTokenID: index, requireWordBoundary: true) else { continue }
            words.insert(word)
        }
        return Array(words)
    }

    func tokenIDs(forWord word: String) -> [Int] {
        let normalized = word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted).lowercased()
        guard !normalized.isEmpty else { return [] }
        return (try? tokenizer.encode(" " + normalized).map { Int($0) }) ?? []
    }

    func tokenPiece(forTokenID tokenID: Int) -> String? {
        guard let token = try? tokenizer.idToToken(tokenID) else { return nil }
        guard !token.hasPrefix("<"), !token.hasSuffix(">") else { return nil }
        return token
    }

    func resetTokenizationState() {
        lastContext = ""
    }

    private func displayWord(forTokenID id: Int, requireWordBoundary: Bool) -> String? {
        guard let token = try? tokenizer.idToToken(id) else { return nil }
        guard !token.hasPrefix("<"), !token.hasSuffix(">") else { return nil }
        guard !requireWordBoundary || token.hasPrefix("\u{2581}") else { return nil }

        let word = token
            .replacingOccurrences(of: "\u{2581}", with: "")
            .trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()

        guard word.count >= 2 else { return nil }
        guard word.rangeOfCharacter(from: .letters) != nil else { return nil }
        guard word.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted) == nil else { return nil }
        return word
    }
}

#else

final class AtlasSentencePieceTokenizer: AtlasTokenizing {
    private let fallback = AtlasTokenizer()

    init(bundle: Bundle = .main) throws {}

    func encodeLatestTokens(from context: String) -> [Int64] {
        fallback.encodeLatestTokens(from: context)
    }

    func candidateScores(from logits: [Float], limit: Int) -> [String: Double] {
        fallback.candidateScores(from: logits, limit: limit)
    }

    func vocabularyWords() -> [String] {
        fallback.vocabularyWords()
    }

    func tokenIDs(forWord word: String) -> [Int] {
        fallback.tokenIDs(forWord: word)
    }

    func tokenPiece(forTokenID tokenID: Int) -> String? {
        fallback.tokenPiece(forTokenID: tokenID)
    }

    func resetTokenizationState() {
        fallback.resetTokenizationState()
    }
}

#endif
