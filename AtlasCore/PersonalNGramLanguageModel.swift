import Foundation

struct EngramNGramObservation: Codable, Equatable {
    var count: Int
    var lastSeenAt: Date

    nonisolated init(count: Int = 0, lastSeenAt: Date = Date()) {
        self.count = count
        self.lastSeenAt = lastSeenAt
    }

    nonisolated mutating func observe(at date: Date) {
        count += 1
        lastSeenAt = date
    }

    nonisolated mutating func merge(_ other: EngramNGramObservation) {
        count += other.count
        lastSeenAt = max(lastSeenAt, other.lastSeenAt)
    }
}

struct PersonalNGramCandidate: Equatable {
    var text: String
    var logProbability: Double
    var order: Int
    var hitCount: Int
    var recencyBoost: Double
    var effortScore: Double
    var isPhrase: Bool
}

struct PersonalNGramLanguageModel: Codable, Equatable {
    private enum Constants {
        nonisolated static let separator = "\u{1F}"
        nonisolated static let maxOrder = 5
        nonisolated static let katzDiscount = 0.75
        nonisolated static let backoffPenalty = 0.42
        nonisolated static let recencyHalfLife: TimeInterval = 7 * 24 * 60 * 60
    }

    private(set) var unigrams: [String: EngramNGramObservation] = [:]
    private(set) var bigrams: [String: EngramNGramObservation] = [:]
    private(set) var trigrams: [String: EngramNGramObservation] = [:]
    private(set) var fourgrams: [String: EngramNGramObservation] = [:]
    private(set) var fivegrams: [String: EngramNGramObservation] = [:]
    private(set) var continuationsByContext: [String: [String: EngramNGramObservation]] = [:]
    private(set) var totalUnigramCount: Int = 0
    private(set) var preferredSurfaceForms: [String: String] = [:]

    init() {}

    private enum CodingKeys: String, CodingKey {
        case unigrams
        case bigrams
        case trigrams
        case fourgrams
        case fivegrams
        case continuationsByContext
        case totalUnigramCount
        case preferredSurfaceForms
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unigrams = try container.decodeIfPresent([String: EngramNGramObservation].self, forKey: .unigrams) ?? [:]
        bigrams = try container.decodeIfPresent([String: EngramNGramObservation].self, forKey: .bigrams) ?? [:]
        trigrams = try container.decodeIfPresent([String: EngramNGramObservation].self, forKey: .trigrams) ?? [:]
        fourgrams = try container.decodeIfPresent([String: EngramNGramObservation].self, forKey: .fourgrams) ?? [:]
        fivegrams = try container.decodeIfPresent([String: EngramNGramObservation].self, forKey: .fivegrams) ?? [:]
        continuationsByContext = try container.decodeIfPresent(
            [String: [String: EngramNGramObservation]].self,
            forKey: .continuationsByContext
        ) ?? [:]
        totalUnigramCount = try container.decodeIfPresent(Int.self, forKey: .totalUnigramCount) ?? 0
        preferredSurfaceForms = try container.decodeIfPresent([String: String].self, forKey: .preferredSurfaceForms) ?? [:]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(unigrams, forKey: .unigrams)
        try container.encode(bigrams, forKey: .bigrams)
        try container.encode(trigrams, forKey: .trigrams)
        try container.encode(fourgrams, forKey: .fourgrams)
        try container.encode(fivegrams, forKey: .fivegrams)
        try container.encode(continuationsByContext, forKey: .continuationsByContext)
        try container.encode(totalUnigramCount, forKey: .totalUnigramCount)
        try container.encode(preferredSurfaceForms, forKey: .preferredSurfaceForms)
    }

    mutating func learn(tokens rawTokens: [String], now: Date = Date()) {
        let tokenPairs = normalizedTokenPairs(from: rawTokens)
        let tokens = tokenPairs.map(\.normalized)
        guard !tokens.isEmpty else { return }
        rememberSurfaceForms(tokenPairs)

        for index in tokens.indices {
            for order in 1...Constants.maxOrder {
                let end = index + order
                guard end <= tokens.count else { break }
                let ngram = Array(tokens[index..<end])
                observe(ngram, at: now)
            }
        }

        pruneIfNeeded()
    }

    mutating func learnLatest(tokens rawTokens: [String], now: Date = Date()) {
        let tokenPairs = normalizedTokenPairs(from: rawTokens)
        let tokens = tokenPairs.map(\.normalized)
        guard tokens.count >= 2 else { return }
        rememberSurfaceForms(tokenPairs)

        for order in 2...min(Constants.maxOrder, tokens.count) {
            observe(Array(tokens.suffix(order)), at: now)
        }

        pruneIfNeeded()
    }

    mutating func merge(_ other: PersonalNGramLanguageModel) {
        Self.mergeTable(&unigrams, other.unigrams)
        Self.mergeTable(&bigrams, other.bigrams)
        Self.mergeTable(&trigrams, other.trigrams)
        Self.mergeTable(&fourgrams, other.fourgrams)
        Self.mergeTable(&fivegrams, other.fivegrams)
        for (context, incomingContinuations) in other.continuationsByContext {
            var existingContinuations = continuationsByContext[context] ?? [:]
            Self.mergeTable(&existingContinuations, incomingContinuations)
            continuationsByContext[context] = existingContinuations
        }
        totalUnigramCount += other.totalUnigramCount
        for (word, surface) in other.preferredSurfaceForms {
            preferredSurfaceForms[word] = preferredSurfaceForm(
                existing: preferredSurfaceForms[word],
                incoming: surface,
                normalized: word
            )
        }
        pruneIfNeeded()
    }

    func predictions(for context: String, limit: Int = 60) -> [PersonalNGramCandidate] {
        let contextTokens = EngramNormalizer.ngramTokens(in: context)
        var bestByText: [String: PersonalNGramCandidate] = [:]

        let maximumContextLength = min(Constants.maxOrder - 1, contextTokens.count)
        if maximumContextLength > 0 {
            for contextLength in stride(from: maximumContextLength, through: 1, by: -1) {
                let suffix = Array(contextTokens.suffix(contextLength))
                addContinuations(
                    after: suffix,
                    contextTokens: contextTokens,
                    limit: limit,
                    into: &bestByText
                )
            }
        }

        addContinuations(
            after: [],
            contextTokens: contextTokens,
            limit: max(12, limit / 4),
            into: &bestByText
        )

        return Array(bestByText.values)
            .sorted { lhs, rhs in
                rankingScore(lhs) > rankingScore(rhs)
            }
            .prefix(limit)
            .map(\.self)
    }

    func phrasePredictions(for context: String, limit: Int = 6) -> [PersonalNGramCandidate] {
        let contextTokens = EngramNormalizer.ngramTokens(in: context)
        let firstWords = predictions(for: context, limit: 18)
            .filter { !$0.isPhrase && $0.order >= 3 && $0.hitCount >= 3 }

        var phrases: [PersonalNGramCandidate] = []
        for first in firstWords {
            let secondContext = contextTokens + [EngramNormalizer.normalize(first.text)]
            guard let second = bestContinuation(after: secondContext),
                  second.order >= 3,
                  second.hitCount >= 3
            else {
                continue
            }

            let phraseText = first.text + " " + second.text
            let phraseScore = first.logProbability + second.logProbability + 0.28
            phrases.append(
                PersonalNGramCandidate(
                    text: phraseText,
                    logProbability: phraseScore,
                    order: max(first.order, second.order),
                    hitCount: min(first.hitCount, second.hitCount),
                    recencyBoost: max(first.recencyBoost, second.recencyBoost),
                    effortScore: min(1.2, first.effortScore + second.effortScore * 0.55),
                    isPhrase: true
                )
            )

            let thirdContext = secondContext + [EngramNormalizer.normalize(second.text)]
            if let third = bestContinuation(after: thirdContext),
               third.order >= 4,
               third.hitCount >= 4 {
                phrases.append(
                    PersonalNGramCandidate(
                        text: phraseText + " " + third.text,
                        logProbability: phraseScore + third.logProbability + 0.16,
                        order: max(second.order, third.order),
                        hitCount: min(first.hitCount, second.hitCount, third.hitCount),
                        recencyBoost: max(first.recencyBoost, second.recencyBoost, third.recencyBoost),
                        effortScore: min(1.35, first.effortScore + second.effortScore * 0.45 + third.effortScore * 0.35),
                        isPhrase: true
                    )
                )
            }
        }

        return Array(
            Dictionary(grouping: phrases, by: \.text)
                .compactMap { $0.value.max { rankingScore($0) < rankingScore($1) } }
                .sorted { rankingScore($0) > rankingScore($1) }
                .prefix(limit)
        )
    }

    func confidence(for context: String) -> (hitCount: Int, order: Int, margin: Double) {
        let candidates = predictions(for: context, limit: 2)
        guard let best = candidates.first else { return (0, 0, 0) }
        let runnerUpScore = candidates.dropFirst().first.map(rankingScore) ?? -.infinity
        return (best.hitCount, best.order, rankingScore(best) - runnerUpScore)
    }

    private mutating func observe(_ ngram: [String], at date: Date) {
        let key = Self.key(for: ngram)
        switch ngram.count {
        case 1:
            Self.increment(&unigrams, key: key, at: date)
            totalUnigramCount += 1
            addContinuation(word: ngram[0], after: [], at: date)
        case 2:
            Self.increment(&bigrams, key: key, at: date)
            addContinuation(word: ngram[1], after: Array(ngram.prefix(1)), at: date)
        case 3:
            Self.increment(&trigrams, key: key, at: date)
            addContinuation(word: ngram[2], after: Array(ngram.prefix(2)), at: date)
        case 4:
            Self.increment(&fourgrams, key: key, at: date)
            addContinuation(word: ngram[3], after: Array(ngram.prefix(3)), at: date)
        case 5:
            Self.increment(&fivegrams, key: key, at: date)
            addContinuation(word: ngram[4], after: Array(ngram.prefix(4)), at: date)
        default:
            break
        }
    }

    private mutating func addContinuation(word: String, after context: [String], at date: Date) {
        let contextKey = Self.key(for: context)
        var continuations = continuationsByContext[contextKey] ?? [:]
        Self.increment(&continuations, key: word, at: date)
        continuationsByContext[contextKey] = continuations
    }

    private func addContinuations(
        after context: [String],
        contextTokens: [String],
        limit: Int,
        into bestByText: inout [String: PersonalNGramCandidate]
    ) {
        let contextKey = Self.key(for: context)
        guard let continuations = continuationsByContext[contextKey], !continuations.isEmpty else {
            return
        }

        let ranked = continuations
            .sorted { Self.observationRank($0.value) > Self.observationRank($1.value) }
            .prefix(limit)

        for (word, _) in ranked {
            let candidate = candidate(for: word, contextTokens: contextTokens)
            if let existing = bestByText[word], rankingScore(existing) >= rankingScore(candidate) {
                continue
            }
            bestByText[word] = candidate
        }
    }

    private func bestContinuation(after contextTokens: [String]) -> PersonalNGramCandidate? {
        let contextLength = min(Constants.maxOrder - 1, contextTokens.count)
        guard contextLength > 0 else { return nil }
        for length in stride(from: contextLength, through: 1, by: -1) {
            let context = Array(contextTokens.suffix(length))
            let contextKey = Self.key(for: context)
            guard let continuations = continuationsByContext[contextKey],
                  let best = continuations.max(by: { Self.observationRank($0.value) < Self.observationRank($1.value) })
            else {
                continue
            }
            return candidate(for: best.key, contextTokens: contextTokens)
        }
        return nil
    }

    private func candidate(for word: String, contextTokens: [String]) -> PersonalNGramCandidate {
        let scored = katzBackoffLogProbability(word: word, contextTokens: contextTokens)
        let recency = scored.lastSeenAt.map(Self.recencyBoost) ?? 0
        return PersonalNGramCandidate(
            text: preferredSurfaceForms[word] ?? word,
            logProbability: scored.logProbability,
            order: scored.order,
            hitCount: scored.hitCount,
            recencyBoost: recency,
            effortScore: min(1.0, log(Double(scored.hitCount + 1)) * 0.22 + Double(scored.order) * 0.035),
            isPhrase: false
        )
    }

    private func katzBackoffLogProbability(
        word: String,
        contextTokens: [String]
    ) -> (logProbability: Double, order: Int, hitCount: Int, lastSeenAt: Date?) {
        let maximumContextLength = min(Constants.maxOrder - 1, contextTokens.count)
        var backoff = 1.0

        if maximumContextLength > 0 {
            for length in stride(from: maximumContextLength, through: 1, by: -1) {
                let context = Array(contextTokens.suffix(length))
                let contextKey = Self.key(for: context)
                guard let continuations = continuationsByContext[contextKey], !continuations.isEmpty else {
                    backoff *= Constants.backoffPenalty
                    continue
                }

                if let observation = continuations[word], observation.count > 0 {
                    let contextTotal = max(1, continuations.values.reduce(0) { $0 + $1.count })
                    let discountedCount = max(0.1, Double(observation.count) - Constants.katzDiscount)
                    let probability = max(1e-9, backoff * discountedCount / Double(contextTotal))
                    return (log(probability), length + 1, observation.count, observation.lastSeenAt)
                }

                backoff *= Constants.backoffPenalty
            }
        }

        let total = max(totalUnigramCount, unigrams.values.reduce(0) { $0 + $1.count }, 1)
        let observation = unigrams[word]
        let count = observation?.count ?? 0
        let probability = backoff * max(0.25, Double(count)) / Double(total + max(unigrams.count, 1))
        return (log(max(1e-9, probability)), 1, count, observation?.lastSeenAt)
    }

    private func rankingScore(_ candidate: PersonalNGramCandidate) -> Double {
        candidate.logProbability
            + candidate.recencyBoost
            + candidate.effortScore * 0.18
            + (candidate.isPhrase ? 0.22 : 0)
    }

    nonisolated private static func observationRank(_ observation: EngramNGramObservation) -> Double {
        Double(observation.count) + recencyBoost(for: observation.lastSeenAt) * 2.0
    }

    nonisolated private static func recencyBoost(for date: Date) -> Double {
        let age = max(0, Date().timeIntervalSince(date))
        return 0.45 * pow(0.5, age / Constants.recencyHalfLife)
    }

    nonisolated private static func increment(_ table: inout [String: EngramNGramObservation], key: String, at date: Date) {
        var observation = table[key] ?? EngramNGramObservation(lastSeenAt: date)
        observation.observe(at: date)
        table[key] = observation
    }

    nonisolated private static func mergeTable(
        _ table: inout [String: EngramNGramObservation],
        _ incoming: [String: EngramNGramObservation]
    ) {
        for (key, observation) in incoming {
            var existing = table[key] ?? EngramNGramObservation()
            existing.merge(observation)
            table[key] = existing
        }
    }

    private mutating func pruneIfNeeded() {
        let limit = AtlasConfiguration.personalNGramMaxTypesPerOrder
        Self.prune(&unigrams, limit: limit)
        Self.prune(&bigrams, limit: limit)
        Self.prune(&trigrams, limit: limit)
        Self.prune(&fourgrams, limit: limit)
        Self.prune(&fivegrams, limit: limit)

        let contextLimit = AtlasConfiguration.personalNGramMaxContinuationContexts
        if continuationsByContext.count > contextLimit {
            let keptContextKeys = Set(
                continuationsByContext
                    .sorted { Self.contextRank($0.value) > Self.contextRank($1.value) }
                    .prefix(contextLimit)
                    .map(\.key)
            )
            continuationsByContext = continuationsByContext.filter { keptContextKeys.contains($0.key) }
        }

        for context in continuationsByContext.keys {
            var continuations = continuationsByContext[context] ?? [:]
            Self.prune(&continuations, limit: AtlasConfiguration.personalNGramMaxContinuationsPerContext)
            continuationsByContext[context] = continuations
        }

        preferredSurfaceForms = preferredSurfaceForms.filter { unigrams[$0.key] != nil }
    }

    private func normalizedTokenPairs(from rawTokens: [String]) -> [(surface: String, normalized: String)] {
        rawTokens.compactMap { surface in
            let normalized = EngramNormalizer.normalize(surface)
            guard !normalized.isEmpty else { return nil }
            return (surface, normalized)
        }
    }

    private mutating func rememberSurfaceForms(_ tokenPairs: [(surface: String, normalized: String)]) {
        for pair in tokenPairs {
            preferredSurfaceForms[pair.normalized] = preferredSurfaceForm(
                existing: preferredSurfaceForms[pair.normalized],
                incoming: pair.surface,
                normalized: pair.normalized
            )
        }
    }

    private func preferredSurfaceForm(existing: String?, incoming: String, normalized: String) -> String {
        guard incoming != normalized else { return existing ?? normalized }
        guard incoming.lowercased() == normalized else { return existing ?? normalized }
        guard let existing else { return incoming }
        return existing == normalized ? incoming : existing
    }

    nonisolated private static func prune(_ table: inout [String: EngramNGramObservation], limit: Int) {
        guard table.count > limit else { return }
        let kept = table
            .sorted { observationRank($0.value) > observationRank($1.value) }
            .prefix(limit)
        table = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
    }

    nonisolated private static func contextRank(_ continuations: [String: EngramNGramObservation]) -> Double {
        continuations.values.reduce(0) { $0 + observationRank($1) }
    }

    nonisolated private static func key(for tokens: [String]) -> String {
        tokens.joined(separator: Constants.separator)
    }
}
