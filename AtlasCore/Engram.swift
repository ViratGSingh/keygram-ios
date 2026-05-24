import Foundation

struct Engram: Codable, Equatable {
    struct LearningAssessment: Equatable {
        var isDictionaryWord: Bool = false
        var nearestDictionaryDistance: Int?
    }

    private enum LearningThreshold {
        static let separateMomentInterval: TimeInterval = 60 * 60
        static let normalPromotionMoments = 3
        static let nearDictionaryPromotionMoments = 5
    }

    private(set) var entries: [String: EngramEntry] = [:]

    var sortedEntries: [EngramEntry] {
        entries.values.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
    }

    mutating func learn(_ word: String, sessionName: String) {
        let normalized = EngramNormalizer.normalize(word)
        guard EngramNormalizer.shouldLearnConfirmed(normalized) else { return }

        record(
            normalized,
            sessionName: sessionName,
            vector: PersonalEngramEmbedder.shared.vector(for: normalized),
            confirmation: .explicit
        )
    }

    mutating func learnMessage(_ text: String, sessionName: String) {
        let words = EngramNormalizer.contentWords(in: text)
        guard !words.isEmpty else { return }

        let uniqueWords = Array(Set(words)).sorted()
        let vectors = PersonalEngramEmbedder.shared.vectors(for: uniqueWords)
        for word in uniqueWords {
            observe(
                word,
                sessionName: sessionName,
                assessment: LearningAssessment(),
                vector: vectors[word]
            )
        }
    }

    mutating func observeTyped(
        _ word: String,
        sessionName: String,
        assessment: LearningAssessment = LearningAssessment()
    ) {
        let normalized = EngramNormalizer.normalize(word)
        guard EngramNormalizer.shouldObserve(normalized) else { return }
        guard !assessment.isDictionaryWord else { return }

        observe(
            normalized,
            sessionName: sessionName,
            assessment: assessment,
            vector: PersonalEngramEmbedder.shared.vector(for: normalized)
        )
    }

    mutating func demoteAfterAcceptedCorrection(_ word: String) {
        let normalized = EngramNormalizer.normalize(word)
        guard var entry = entries[normalized] else { return }
        entry.rejectedCount += 1
        entry.learningState = .provisional
        entry.lastSeenAt = Date()
        entries[normalized] = entry
    }

    mutating func merge(_ other: Engram) {
        for (word, incoming) in other.entries {
            guard EngramNormalizer.shouldObserve(word) else { continue }
            if var existing = entries[word] {
                existing.acceptedCount += incoming.acceptedCount
                existing.rejectedCount += incoming.rejectedCount
                existing.observedMomentCount += incoming.observedMomentCount
                existing.learningState = existing.learningState.merged(with: incoming.learningState)
                existing.lastSeenAt = max(existing.lastSeenAt, incoming.lastSeenAt)
                existing.lastObservedMomentAt = max(existing.lastObservedMomentAt, incoming.lastObservedMomentAt)
                existing.sessionHints.formUnion(incoming.sessionHints)
                if existing.vector.isEmpty {
                    existing.vector = incoming.vector
                }
                entries[word] = existing
            } else {
                entries[word] = incoming
            }
        }
    }

    mutating func remove(_ word: String) {
        let normalized = EngramNormalizer.normalize(word)
        entries[normalized] = nil
    }

    func bias(for candidate: String, context: String) -> Double {
        let normalized = EngramNormalizer.normalize(candidate)
        guard let entry = entries[normalized] else { return 0 }
        guard entry.isConfirmed else { return 0 }

        if let semanticBias = semanticBias(for: entry, context: context) {
            return semanticBias
        }

        let recency = max(0.1, 1.0 - Date().timeIntervalSince(entry.lastSeenAt) / 2_592_000)
        let contextMatch = context.localizedCaseInsensitiveContains(normalized) ? 0.6 : 0
        return min(1.25, log(Double(entry.acceptedCount + 1)) * 0.18 + recency * 0.22 + contextMatch)
    }

    func relevantWords(for context: String, limit: Int = 10, threshold: Float = 0.25) -> [(word: String, score: Double)] {
        guard shouldUseSemanticContext(context) else { return [] }

        var results: [(word: String, score: Double)] = []
        if let contextVector = PersonalEngramEmbedder.shared.vector(for: context) {
            results = entries.values.compactMap { entry -> (word: String, score: Double)? in
                guard entry.isConfirmed else { return nil }
                guard !entry.vector.isEmpty, entry.vector.count == contextVector.count else { return nil }
                let similarity = cosineSimilarity(entry.vector, contextVector)
                let frequencyBoost = Float(1.0 + 0.1 * log(Double(entry.acceptedCount + 1)))
                let score = similarity * frequencyBoost
                guard score >= threshold else { return nil }
                return (word: entry.word, score: Double(score))
            }
        }

        let wordsWithSemanticScores = Set(results.map(\.word))
        let fallback = sortedEntries
            .filter { $0.isConfirmed }
            .filter { !wordsWithSemanticScores.contains($0.word) }
            .prefix(limit)
            .map { (word: $0.word, score: fallbackRelevanceScore(for: $0)) }

        results += fallback
        return Array(results.sorted(by: { lhs, rhs in lhs.score > rhs.score }).prefix(limit))
    }

    func completions(matching prefix: String, limit: Int = 24) -> [String] {
        let normalizedPrefix = EngramNormalizer.normalize(prefix)
        guard !normalizedPrefix.isEmpty else { return [] }
        return Array(
            sortedEntries
                .map(\.word)
                .filter { word in
                    guard let entry = entries[word], entry.isConfirmed else { return false }
                    return word.hasPrefix(normalizedPrefix) && word != normalizedPrefix
                }
                .prefix(limit)
        )
    }

    func correctionCandidates(for word: String, maxDistance: Int = 2, limit: Int = 32) -> [String] {
        let normalized = EngramNormalizer.normalize(word)
        guard !normalized.isEmpty else { return [] }
        return Array(
            sortedEntries
                .map(\.word)
                .filter { candidate in
                    guard let entry = entries[candidate], entry.isConfirmed else { return false }
                    return candidate != normalized
                        && abs(candidate.count - normalized.count) <= maxDistance + 1
                        && AtlasSpellingMetrics.editDistance(candidate, normalized) <= maxDistance
                }
                .prefix(limit)
        )
    }

    func containsConfirmed(_ word: String) -> Bool {
        let normalized = EngramNormalizer.normalize(word)
        return entries[normalized]?.isConfirmed == true
    }

    func contains(_ word: String) -> Bool {
        entries[EngramNormalizer.normalize(word)] != nil
    }

    func entry(for word: String) -> EngramEntry? {
        entries[EngramNormalizer.normalize(word)]
    }

    private enum ConfirmationSource {
        case explicit
        case observed(LearningAssessment)
    }

    private mutating func record(_ word: String, sessionName: String, vector: [Float]?, confirmation: ConfirmationSource) {
        var entry = entries[word] ?? EngramEntry(word: word)
        entry.acceptedCount += 1
        entry.lastSeenAt = Date()
        entry.sessionHints.insert(sessionName)
        if entry.vector.isEmpty, let vector {
            entry.vector = vector
        }
        switch confirmation {
        case .explicit:
            entry.learningState = .confirmed
            entry.observedMomentCount = max(entry.observedMomentCount, 1)
            entry.lastObservedMomentAt = entry.lastSeenAt
        case .observed(let assessment):
            entry.learningState = promotionState(for: entry, assessment: assessment)
        }
        entries[word] = entry
    }

    private mutating func observe(_ word: String, sessionName: String, assessment: LearningAssessment, vector: [Float]?) {
        var entry = entries[word] ?? EngramEntry(word: word)
        let now = Date()
        if now.timeIntervalSince(entry.lastObservedMomentAt) >= LearningThreshold.separateMomentInterval {
            entry.observedMomentCount += 1
            entry.lastObservedMomentAt = now
        }
        entries[word] = entry
        record(word, sessionName: sessionName, vector: vector, confirmation: .observed(assessment))
    }

    private func promotionState(for entry: EngramEntry, assessment: LearningAssessment) -> EngramLearningState {
        if entry.rejectedCount >= entry.acceptedCount {
            return .provisional
        }

        let requiredMoments: Int
        if EngramNormalizer.isProtectedPersonalToken(entry.word) {
            requiredMoments = LearningThreshold.normalPromotionMoments
        } else if assessment.nearestDictionaryDistance == 1 {
            requiredMoments = LearningThreshold.nearDictionaryPromotionMoments + entry.rejectedCount
        } else {
            requiredMoments = LearningThreshold.normalPromotionMoments + min(entry.rejectedCount, 3)
        }

        return entry.observedMomentCount >= requiredMoments ? .confirmed : .provisional
    }

    private func semanticBias(for entry: EngramEntry, context: String) -> Double? {
        guard shouldUseSemanticContext(context) else { return nil }
        guard !entry.vector.isEmpty,
              let contextVector = PersonalEngramEmbedder.shared.vector(for: context),
              entry.vector.count == contextVector.count
        else {
            return nil
        }

        let similarity = max(0, cosineSimilarity(entry.vector, contextVector))
        let frequencyBoost = Float(1.0 + 0.1 * log(Double(entry.acceptedCount + 1)))
        let semantic = Double(similarity * frequencyBoost)
        let recency = max(0.1, 1.0 - Date().timeIntervalSince(entry.lastSeenAt) / 2_592_000)
        return min(1.8, semantic + recency * 0.12)
    }

    private func fallbackRelevanceScore(for entry: EngramEntry) -> Double {
        let recency = max(0.1, 1.0 - Date().timeIntervalSince(entry.lastSeenAt) / 604_800)
        return min(1.0, log(Double(entry.acceptedCount + 1)) * 0.2 + recency * 0.35)
    }

    private func cosineSimilarity(_ lhs: [Float], _ rhs: [Float]) -> Float {
        guard lhs.count == rhs.count else { return 0 }
        return zip(lhs, rhs).reduce(Float(0)) { $0 + $1.0 * $1.1 }
    }

    private func shouldUseSemanticContext(_ context: String) -> Bool {
        context.last?.isWhitespace == true
    }
}

struct EngramEntry: Codable, Equatable, Identifiable {
    var id: String { word }
    var word: String
    var acceptedCount: Int = 0
    var rejectedCount: Int = 0
    var lastSeenAt: Date = Date()
    var learningState: EngramLearningState = .provisional
    var observedMomentCount: Int = 0
    var lastObservedMomentAt: Date = .distantPast
    var sessionHints: Set<String> = []
    var vector: [Float] = []

    init(
        word: String,
        acceptedCount: Int = 0,
        rejectedCount: Int = 0,
        lastSeenAt: Date = Date(),
        learningState: EngramLearningState = .provisional,
        observedMomentCount: Int = 0,
        lastObservedMomentAt: Date = .distantPast,
        sessionHints: Set<String> = [],
        vector: [Float] = []
    ) {
        self.word = word
        self.acceptedCount = acceptedCount
        self.rejectedCount = rejectedCount
        self.lastSeenAt = lastSeenAt
        self.learningState = learningState
        self.observedMomentCount = observedMomentCount
        self.lastObservedMomentAt = lastObservedMomentAt
        self.sessionHints = sessionHints
        self.vector = vector
    }

    enum CodingKeys: String, CodingKey {
        case word
        case acceptedCount
        case rejectedCount
        case lastSeenAt
        case learningState
        case observedMomentCount
        case lastObservedMomentAt
        case sessionHints
        case vector
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        word = try container.decode(String.self, forKey: .word)
        acceptedCount = try container.decodeIfPresent(Int.self, forKey: .acceptedCount) ?? 0
        rejectedCount = try container.decodeIfPresent(Int.self, forKey: .rejectedCount) ?? 0
        lastSeenAt = try container.decodeIfPresent(Date.self, forKey: .lastSeenAt) ?? Date()
        learningState = try container.decodeIfPresent(EngramLearningState.self, forKey: .learningState)
            ?? (acceptedCount >= 3 && rejectedCount == 0 ? .confirmed : .provisional)
        observedMomentCount = try container.decodeIfPresent(Int.self, forKey: .observedMomentCount) ?? acceptedCount
        lastObservedMomentAt = try container.decodeIfPresent(Date.self, forKey: .lastObservedMomentAt) ?? lastSeenAt
        sessionHints = try container.decodeIfPresent(Set<String>.self, forKey: .sessionHints) ?? []
        vector = try container.decodeIfPresent([Float].self, forKey: .vector) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(word, forKey: .word)
        try container.encode(acceptedCount, forKey: .acceptedCount)
        try container.encode(rejectedCount, forKey: .rejectedCount)
        try container.encode(lastSeenAt, forKey: .lastSeenAt)
        try container.encode(learningState, forKey: .learningState)
        try container.encode(observedMomentCount, forKey: .observedMomentCount)
        try container.encode(lastObservedMomentAt, forKey: .lastObservedMomentAt)
        try container.encode(sessionHints, forKey: .sessionHints)
        try container.encode(vector, forKey: .vector)
    }

    var isConfirmed: Bool {
        learningState == .confirmed
    }

    var score: Double {
        let stateBoost = isConfirmed ? 10.0 : 0
        return stateBoost + Double(acceptedCount * 3 - rejectedCount * 2) + max(0, 30 - Date().timeIntervalSince(lastSeenAt) / 86_400)
    }
}

enum EngramLearningState: String, Codable, Equatable {
    case provisional
    case confirmed

    func merged(with other: EngramLearningState) -> EngramLearningState {
        self == .confirmed || other == .confirmed ? .confirmed : .provisional
    }
}

enum EngramNormalizer {
    private static let protectedPersonalTokens: Set<String> = [
        "af", "brb", "btw", "dm", "fr", "fyi", "gg", "idc", "idk", "ikr", "imo",
        "irl", "jk", "lmao", "lol", "ngl", "np", "omw", "rn", "smh", "tbh",
        "tfw", "wyd"
    ]

    private static let blockedWords: Set<String> = [
        "i", "me", "my", "mine", "we", "us", "our", "you", "your", "he", "him",
        "his", "she", "her", "it", "its", "they", "them", "their", "this", "that",
        "these", "those", "who", "what", "which", "is", "are", "was", "were", "be",
        "been", "being", "have", "has", "had", "do", "did", "does", "will", "would",
        "could", "should", "may", "might", "must", "shall", "can", "need", "let",
        "get", "got", "go", "went", "come", "came", "make", "made", "know", "think",
        "want", "use", "find", "give", "tell", "ask", "seem", "feel", "try", "leave",
        "call", "keep", "put", "send", "done", "finish", "work", "working", "almost",
        "include", "attach", "check", "sure", "also", "just", "now", "still",
        "already", "always", "never", "please", "okay", "yeah", "the", "a", "an",
        "to", "of", "in", "on", "at", "for", "and", "or", "but", "so", "as", "if",
        "not", "no", "nor", "yet", "with", "from", "by", "about", "into", "through",
        "during", "before", "after", "above", "below", "between", "out", "up", "down",
        "off", "over", "under", "again", "then", "once", "good", "new", "first",
        "last", "long", "great", "little", "own", "right", "big", "high", "small",
        "large", "next", "early", "young", "important", "few", "public", "bad",
        "same", "able", "ok", "hey", "hi", "lol", "omg", "yes", "yep", "nope",
        "like", "really", "very", "too", "much", "more", "most", "some", "any",
        "many", "well", "even", "back", "only", "both", "each", "here", "there",
        "when", "where", "how", "all", "whole", "lot", "place", "main", "street",
        "road", "area", "thing", "stuff", "time", "day", "week", "month", "year",
        "today", "tonight", "free", "coming", "works", "final", "number", "numbers",
        "team", "group", "people", "person", "someone", "something", "quarter", "end",
        "part", "point", "side", "start", "way", "case", "fact", "kind", "type",
        "set", "bit"
    ]

    static func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()
    }

    static func shouldLearn(_ word: String) -> Bool {
        shouldLearnConfirmed(word)
    }

    static func shouldLearnConfirmed(_ word: String) -> Bool {
        if isProtectedPersonalToken(word) {
            return true
        }
        guard word.count >= 4 else { return false }
        guard !blockedWords.contains(word) else { return false }
        return isWordLike(word)
    }

    static func shouldObserve(_ word: String) -> Bool {
        if isProtectedPersonalToken(word) {
            return true
        }
        guard word.count >= 4 else { return false }
        guard !blockedWords.contains(word) else { return false }
        return isWordLike(word)
    }

    static func isProtectedPersonalToken(_ word: String) -> Bool {
        protectedPersonalTokens.contains(word)
    }

    private static func isWordLike(_ word: String) -> Bool {
        word.rangeOfCharacter(from: .letters) != nil
            && word.rangeOfCharacter(from: CharacterSet.letters.union(CharacterSet(charactersIn: "'")).inverted) == nil
    }

    static var commonWordsForAutocorrect: Set<String> {
        blockedWords
    }

    static func contentWords(in text: String) -> [String] {
        let pattern = #"[A-Za-z']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let wordRange = Range(match.range, in: text) else { return nil }
            let normalized = normalize(String(text[wordRange]))
            return shouldLearn(normalized) ? normalized : nil
        }
    }
}
