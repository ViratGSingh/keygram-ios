import Foundation
import NaturalLanguage

final class PersonalEngramEmbedder {
    static let shared = PersonalEngramEmbedder()

    private let lock = NSLock()
    private var embedding: NLContextualEmbedding?
    private var isLoaded = false
    private var assetsRequested = false
    private var cache: [String: [Float]] = [:]

    private init() {}

    func vector(for text: String) -> [Float]? {
        let key = cacheKey(for: text)
        guard !key.isEmpty else { return nil }

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard let vector = embed(key) else { return nil }

        lock.lock()
        cache[key] = vector
        lock.unlock()

        return vector
    }

    func vectors(for texts: [String]) -> [String: [Float]] {
        var result: [String: [Float]] = [:]
        for text in texts {
            guard let vector = vector(for: text) else { continue }
            result[cacheKey(for: text)] = vector
        }
        return result
    }

    private func embed(_ text: String) -> [Float]? {
        guard let embedding = loadedEmbedding() else { return nil }

        do {
            let result = try embedding.embeddingResult(for: text, language: .english)
            return averageVector(from: result)
        } catch {
            return nil
        }
    }

    private func loadedEmbedding() -> NLContextualEmbedding? {
        lock.lock()
        if isLoaded, let embedding {
            lock.unlock()
            return embedding
        }
        let existing = embedding
        lock.unlock()

        guard let resolved = existing ?? NLContextualEmbedding(language: .english) else { return nil }

        guard resolved.hasAvailableAssets else {
            requestAssetsIfNeeded(for: resolved)
            return nil
        }

        do {
            try resolved.load()
            lock.lock()
            embedding = resolved
            isLoaded = true
            lock.unlock()
            return resolved
        } catch {
            return nil
        }
    }

    private func requestAssetsIfNeeded(for embedding: NLContextualEmbedding) {
        lock.lock()
        guard !assetsRequested else {
            lock.unlock()
            return
        }
        assetsRequested = true
        lock.unlock()

        embedding.requestAssets { _, _ in }
    }

    private func averageVector(from result: NLContextualEmbeddingResult) -> [Float]? {
        var sum: [Double] = []
        var count = 0

        result.enumerateTokenVectors(in: result.string.startIndex..<result.string.endIndex) { vector, _ in
            if sum.isEmpty {
                sum = Array(repeating: 0, count: vector.count)
            }
            guard sum.count == vector.count else { return true }
            for index in vector.indices {
                sum[index] += vector[index]
            }
            count += 1
            return true
        }

        guard count > 0 else { return nil }
        let averaged = sum.map { Float($0 / Double(count)) }
        return normalized(averaged)
    }

    private func normalized(_ vector: [Float]) -> [Float]? {
        let magnitude = sqrt(vector.reduce(Float(0)) { $0 + $1 * $1 })
        guard magnitude > 0 else { return nil }
        return vector.map { $0 / magnitude }
    }

    private func cacheKey(for text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
