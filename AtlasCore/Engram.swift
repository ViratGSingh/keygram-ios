import Foundation

struct Engram: Codable, Equatable {
    struct LearningAssessment: Equatable {
        var isDictionaryWord: Bool = false
        var nearestDictionaryDistance: Int?
    }

    private enum LearningThreshold {
        static let separateMomentInterval: TimeInterval = 60 * 60
        static let fullCreditTypingsPerWindow = 3
        static let fullTypingCredit = 1.0
        static let repeatedTypingCredit = 0.25
        static let newWindowBonus = 3.0
        static let suggestionAcceptanceCredit = 4.0
        static let minimumActualTypings = 6
        static let normalEvidence = 12.0
        static let distanceTwoEvidence = 16.0
        static let distanceOneEvidence = 24.0
        static let rejectionEvidencePenalty = 4.0
    }

    private(set) var entries: [String: EngramEntry] = [:]
    private(set) var ngramLanguageModel = PersonalNGramLanguageModel()

    init(
        entries: [String: EngramEntry] = [:],
        ngramLanguageModel: PersonalNGramLanguageModel = PersonalNGramLanguageModel()
    ) {
        self.entries = entries
        self.ngramLanguageModel = ngramLanguageModel
    }

    enum CodingKeys: String, CodingKey {
        case entries
        case ngramLanguageModel
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        entries = try container.decodeIfPresent([String: EngramEntry].self, forKey: .entries) ?? [:]
        ngramLanguageModel = try container.decodeIfPresent(PersonalNGramLanguageModel.self, forKey: .ngramLanguageModel)
            ?? PersonalNGramLanguageModel()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(entries, forKey: .entries)
        try container.encode(ngramLanguageModel, forKey: .ngramLanguageModel)
    }

    var sortedEntries: [EngramEntry] {
        entries.values.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.word.localizedCaseInsensitiveCompare(rhs.word) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
    }

    mutating func acceptSuggestion(
        _ word: String,
        sessionName: String,
        assessment: LearningAssessment = LearningAssessment()
    ) {
        let normalized = EngramNormalizer.normalize(word)
        let tokens = EngramNormalizer.ngramSurfaceTokens(in: word)
        let shouldLearnNGramImmediately = Self.shouldLearnNGramToken(normalized, assessment: assessment)
        if shouldLearnNGramImmediately {
            for token in tokens {
                ngramLanguageModel.learn(tokens: [token])
            }
        }
        guard EngramNormalizer.shouldObserve(normalized) else { return }
        guard !assessment.isDictionaryWord else { return }

        recordEvidence(
            normalized,
            sessionName: sessionName,
            vector: PersonalEngramEmbedder.shared.vector(for: normalized),
            source: .suggestion,
            assessment: assessment
        )
        if !shouldLearnNGramImmediately, entries[normalized]?.isConfirmed == true {
            for token in tokens {
                ngramLanguageModel.learn(tokens: [token])
            }
        }
    }

    mutating func confirmAfterAutocorrectionUndo(
        _ word: String,
        sessionName: String,
        assessment: LearningAssessment = LearningAssessment()
    ) {
        confirm(word, sessionName: sessionName, source: .autocorrectionUndo, assessment: assessment)
    }

    mutating func confirmManually(_ word: String, sessionName: String) {
        confirm(word, sessionName: sessionName, source: .manual, assessment: LearningAssessment())
    }

    mutating func learnMessage(_ text: String, sessionName: String, includeNGrams: Bool = true) {
        if includeNGrams {
            for tokenSequence in EngramNormalizer.ngramSurfaceTokenSequences(in: text) {
                ngramLanguageModel.learn(tokens: tokenSequence)
            }
        }
    }

    mutating func observeTyped(
        _ word: String,
        sessionName: String,
        assessment: LearningAssessment = LearningAssessment()
    ) {
        let normalized = EngramNormalizer.normalize(word)
        let tokens = EngramNormalizer.ngramSurfaceTokens(in: word)
        let shouldLearnNGramImmediately = Self.shouldLearnNGramToken(normalized, assessment: assessment)
        if tokens.count == 1, shouldLearnNGramImmediately {
            ngramLanguageModel.learn(tokens: tokens)
        }
        guard EngramNormalizer.shouldObserve(normalized) else { return }
        guard !assessment.isDictionaryWord else { return }

        observe(
            normalized,
            sessionName: sessionName,
            assessment: assessment,
            vector: PersonalEngramEmbedder.shared.vector(for: normalized)
        )
        if tokens.count == 1,
           !shouldLearnNGramImmediately,
           entries[normalized]?.isConfirmed == true {
            ngramLanguageModel.learn(tokens: tokens)
        }
    }

    mutating func demoteAfterAcceptedCorrection(_ word: String) {
        let normalized = EngramNormalizer.normalize(word)
        guard var entry = entries[normalized] else { return }
        entry.rejectedCount += 1
        entry.learningState = .provisional
        entry.confirmationSource = nil
        entry.lastSeenAt = Date()
        entries[normalized] = entry
    }

    mutating func merge(_ other: Engram) {
        for (word, incoming) in other.entries {
            guard EngramNormalizer.shouldObserve(word) else { continue }
            if var existing = entries[word] {
                let existingLastSeenAt = existing.lastSeenAt
                existing.acceptedCount += incoming.acceptedCount
                existing.rejectedCount += incoming.rejectedCount
                existing.observedMomentCount += incoming.observedMomentCount
                existing.actualTypingCount += incoming.actualTypingCount
                existing.suggestionAcceptanceCount += incoming.suggestionAcceptanceCount
                existing.evidencePoints += incoming.evidencePoints
                existing.learningState = existing.learningState.merged(with: incoming.learningState)
                existing.lastSeenAt = max(existing.lastSeenAt, incoming.lastSeenAt)
                existing.lastObservedMomentAt = max(existing.lastObservedMomentAt, incoming.lastObservedMomentAt)
                if incoming.typingWindowStartedAt > existing.typingWindowStartedAt {
                    existing.typingWindowStartedAt = incoming.typingWindowStartedAt
                    existing.typingsInCurrentWindow = incoming.typingsInCurrentWindow
                }
                if incoming.lastSeenAt >= existingLastSeenAt {
                    existing.lastEvidenceSource = incoming.lastEvidenceSource
                }
                if existing.confirmationSource == nil {
                    existing.confirmationSource = incoming.confirmationSource
                }
                existing.sessionHints.formUnion(incoming.sessionHints)
                if existing.vector.isEmpty {
                    existing.vector = incoming.vector
                }
                entries[word] = existing
            } else {
                entries[word] = incoming
            }
        }
        ngramLanguageModel.merge(other.ngramLanguageModel)
        pruneEntriesIfNeeded()
    }

    mutating func remove(_ word: String) {
        let normalized = EngramNormalizer.normalize(word)
        entries[normalized] = nil
    }

    /// Fully forgets a personalized word so it stops surfacing as a suggestion: drops the
    /// learned entry and purges every n-gram that references it from the language model.
    mutating func forget(_ word: String) {
        let normalized = EngramNormalizer.normalize(word)
        guard !normalized.isEmpty else { return }
        entries[normalized] = nil
        ngramLanguageModel.removeWords([normalized])
    }

    mutating func resetNGramLanguageModel() {
        ngramLanguageModel = PersonalNGramLanguageModel()
    }

    @discardableResult
    mutating func removeLikelyMistypedNGramWords(
        assessmentFor: (String) -> LearningAssessment
    ) -> [String] {
        let wordsToRemove = ngramLanguageModel.learnedWords().filter { word in
            let normalized = EngramNormalizer.normalize(word)
            guard !normalized.isEmpty else { return false }
            guard !EngramNormalizer.isProtectedPersonalToken(normalized) else { return false }
            let entry = entries[normalized]
            guard entry?.confirmationSource?.isExplicit != true else { return false }
            guard entry?.isConfirmed != true else { return false }
            let assessment = assessmentFor(normalized)
            return !assessment.isDictionaryWord && Self.isDictionaryNearMiss(assessment)
        }
        let uniqueWords = Set(wordsToRemove)
        ngramLanguageModel.removeWords(uniqueWords)
        return Array(uniqueWords).sorted()
    }

    @discardableResult
    mutating func reevaluateLearningStates(
        assessmentFor: (String) -> LearningAssessment
    ) -> (promoted: Int, demoted: Int) {
        var promoted = 0
        var demoted = 0
        var trustedPersonalWords: [String] = []
        let orderedWords = entries.values.sorted { lhs, rhs in
            let lhsExplicit = lhs.confirmationSource?.isExplicit == true
            let rhsExplicit = rhs.confirmationSource?.isExplicit == true
            if lhsExplicit != rhsExplicit {
                return lhsExplicit
            }
            if lhs.evidencePoints != rhs.evidencePoints {
                return lhs.evidencePoints > rhs.evidencePoints
            }
            return lhs.acceptedCount > rhs.acceptedCount
        }.map(\.word)

        for word in orderedWords {
            guard var entry = entries[word] else { continue }
            let oldState = entry.learningState
            let newState = promotionState(
                for: entry,
                assessment: assessmentFor(word),
                confirmedPersonalWords: trustedPersonalWords
            )
            entry.learningState = newState
            if newState == .confirmed {
                trustedPersonalWords.append(word)
            }
            if oldState != newState {
                if newState == .confirmed {
                    promoted += 1
                } else {
                    demoted += 1
                    entry.confirmationSource = nil
                }
            }
            entries[word] = entry
        }
        return (promoted, demoted)
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

    func confirmedWords(limit: Int = 32) -> [EngramEntry] {
        Array(sortedEntries.filter(\.isConfirmed).prefix(limit))
    }

    func personalNextWordCandidates(for context: String, limit: Int = 60) -> [PersonalNGramCandidate] {
        ngramLanguageModel.predictions(for: context, limit: limit)
    }

    func personalPhraseCandidates(for context: String, limit: Int = 6) -> [PersonalNGramCandidate] {
        ngramLanguageModel.phrasePredictions(for: context, limit: limit)
    }

    mutating func learnLatestContext(
        _ text: String,
        finalWordAssessment: LearningAssessment? = nil
    ) {
        guard let latestSequence = EngramNormalizer.ngramSurfaceTokenSequences(in: text).last else { return }
        if let finalWordAssessment,
           let finalWord = latestSequence.last {
            let normalized = EngramNormalizer.normalize(finalWord)
            guard Self.shouldLearnNGramToken(normalized, assessment: finalWordAssessment) else {
                return
            }
        }
        ngramLanguageModel.learnLatest(tokens: latestSequence)
    }

    func nextWordConfidence(for context: String) -> (hitCount: Int, order: Int, margin: Double) {
        ngramLanguageModel.confidence(for: context)
    }

    func marginalFrequencyBoost(for word: String, globalProbability: Double) -> Double {
        ngramLanguageModel.marginalFrequencyBoost(for: word, globalProbability: globalProbability)
    }

    func entry(for word: String) -> EngramEntry? {
        entries[EngramNormalizer.normalize(word)]
    }

    private mutating func recordEvidence(
        _ word: String,
        sessionName: String,
        vector: [Float]?,
        source: EngramEvidenceSource,
        assessment: LearningAssessment
    ) {
        var entry = entries[word] ?? EngramEntry(word: word)
        entry.acceptedCount += 1
        entry.lastSeenAt = Date()
        entry.sessionHints.insert(sessionName)
        if entry.vector.isEmpty, let vector {
            entry.vector = vector
        }

        switch source {
        case .typed:
            applyTypedEvidence(to: &entry, now: entry.lastSeenAt)
        case .suggestion:
            entry.suggestionAcceptanceCount += 1
            entry.evidencePoints += LearningThreshold.suggestionAcceptanceCredit
        case .autocorrectionUndo, .manual:
            break
        }
        entry.lastEvidenceSource = source

        let newState = promotionState(for: entry, assessment: assessment)
        if newState == .confirmed, entry.learningState != .confirmed {
            entry.confirmationSource = source
        }
        entry.learningState = newState
        entries[word] = entry
        pruneEntriesIfNeeded()
    }

    private mutating func observe(_ word: String, sessionName: String, assessment: LearningAssessment, vector: [Float]?) {
        recordEvidence(
            word,
            sessionName: sessionName,
            vector: vector,
            source: .typed,
            assessment: assessment
        )
    }

    private static func shouldLearnNGramToken(
        _ normalized: String,
        assessment: LearningAssessment
    ) -> Bool {
        guard !normalized.isEmpty else { return false }
        if assessment.isDictionaryWord || EngramNormalizer.isProtectedPersonalToken(normalized) {
            return true
        }
        guard EngramNormalizer.isWordLike(normalized) else { return false }
        guard !isDictionaryNearMiss(assessment) else { return false }
        return true
    }

    private static func isDictionaryNearMiss(_ assessment: LearningAssessment) -> Bool {
        guard let distance = assessment.nearestDictionaryDistance else { return false }
        return distance <= 2
    }

    private mutating func confirm(
        _ word: String,
        sessionName: String,
        source: EngramEvidenceSource,
        assessment: LearningAssessment
    ) {
        let normalized = EngramNormalizer.normalize(word)
        guard EngramNormalizer.shouldLearnConfirmed(normalized) else { return }
        let tokens = EngramNormalizer.ngramSurfaceTokens(in: word)

        // Manual confirmations and genuinely novel words (proper nouns, slang —
        // not within edit distance 2 of any real word) are trusted explicitly and
        // confirmed permanently. A word that merely looks like a typo of a real
        // word (e.g. "sould" near "should") is NOT enshrined from a single undo:
        // it is recorded as one ordinary typing and stays provisional until it
        // earns confirmation through repeated real use, so a stray undo can't
        // permanently pollute the personal dictionary or next-word model.
        let isTrusted = source == .manual
            || assessment.isDictionaryWord
            || !Self.isDictionaryNearMiss(assessment)

        var entry = entries[normalized] ?? EngramEntry(word: normalized)
        entry.acceptedCount += 1
        entry.lastSeenAt = Date()
        entry.lastEvidenceSource = source
        entry.sessionHints.insert(sessionName)
        if entry.vector.isEmpty,
           let vector = PersonalEngramEmbedder.shared.vector(for: normalized) {
            entry.vector = vector
        }

        if isTrusted {
            for token in tokens {
                ngramLanguageModel.learn(tokens: [token])
            }
            entry.confirmationSource = source
            entry.learningState = .confirmed
        } else {
            applyTypedEvidence(to: &entry, now: entry.lastSeenAt)
            entry.learningState = promotionState(for: entry, assessment: assessment)
        }
        entries[normalized] = entry
        pruneEntriesIfNeeded()
    }

    private mutating func pruneEntriesIfNeeded() {
        let limit = AtlasConfiguration.personalEngramMaxEntries
        guard entries.count > limit else { return }

        let kept = entries.values
            .sorted { lhs, rhs in
                let lhsExplicit = lhs.confirmationSource?.isExplicit == true
                let rhsExplicit = rhs.confirmationSource?.isExplicit == true
                if lhsExplicit != rhsExplicit { return lhsExplicit }
                if lhs.isConfirmed != rhs.isConfirmed { return lhs.isConfirmed }
                if lhs.evidencePoints != rhs.evidencePoints {
                    return lhs.evidencePoints > rhs.evidencePoints
                }
                if lhs.acceptedCount != rhs.acceptedCount {
                    return lhs.acceptedCount > rhs.acceptedCount
                }
                return lhs.lastSeenAt > rhs.lastSeenAt
            }
            .prefix(limit)
        entries = Dictionary(uniqueKeysWithValues: kept.map { ($0.word, $0) })
    }

    private func applyTypedEvidence(to entry: inout EngramEntry, now: Date) {
        let startsNewWindow = entry.typingWindowStartedAt == .distantPast
            || now.timeIntervalSince(entry.typingWindowStartedAt) >= LearningThreshold.separateMomentInterval
        if startsNewWindow {
            if entry.actualTypingCount > 0 {
                entry.evidencePoints += LearningThreshold.newWindowBonus
            }
            entry.typingWindowStartedAt = now
            entry.typingsInCurrentWindow = 0
            entry.observedMomentCount += 1
            entry.lastObservedMomentAt = now
        }

        if entry.typingsInCurrentWindow < LearningThreshold.fullCreditTypingsPerWindow {
            entry.evidencePoints += LearningThreshold.fullTypingCredit
        } else {
            entry.evidencePoints += LearningThreshold.repeatedTypingCredit
        }
        entry.typingsInCurrentWindow += 1
        entry.actualTypingCount += 1
    }

    private func promotionState(
        for entry: EngramEntry,
        assessment: LearningAssessment,
        confirmedPersonalWords: [String]? = nil
    ) -> EngramLearningState {
        if entry.confirmationSource?.isExplicit == true {
            return .confirmed
        }
        guard entry.actualTypingCount >= LearningThreshold.minimumActualTypings else {
            return .provisional
        }

        let personalWords = confirmedPersonalWords ?? entries.values.compactMap {
            $0.isConfirmed && $0.word != entry.word ? $0.word : nil
        }
        let personalDistance = personalWords.lazy.compactMap {
            AtlasSpellingMetrics.editDistance(entry.word, $0, maxDistance: 2)
        }.min()
        let nearestDistance = [assessment.nearestDictionaryDistance, personalDistance]
            .compactMap { $0 }
            .min()

        let baseThreshold: Double
        switch nearestDistance {
        case 1:
            baseThreshold = LearningThreshold.distanceOneEvidence
        case 2:
            baseThreshold = LearningThreshold.distanceTwoEvidence
        default:
            baseThreshold = LearningThreshold.normalEvidence
        }
        let requiredEvidence = baseThreshold
            + Double(entry.rejectedCount) * LearningThreshold.rejectionEvidencePenalty
        return entry.evidencePoints >= requiredEvidence ? .confirmed : .provisional
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
    var actualTypingCount: Int = 0
    var suggestionAcceptanceCount: Int = 0
    var evidencePoints: Double = 0
    var typingWindowStartedAt: Date = .distantPast
    var typingsInCurrentWindow: Int = 0
    var lastEvidenceSource: EngramEvidenceSource?
    var confirmationSource: EngramEvidenceSource?
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
        actualTypingCount: Int = 0,
        suggestionAcceptanceCount: Int = 0,
        evidencePoints: Double = 0,
        typingWindowStartedAt: Date = .distantPast,
        typingsInCurrentWindow: Int = 0,
        lastEvidenceSource: EngramEvidenceSource? = nil,
        confirmationSource: EngramEvidenceSource? = nil,
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
        self.actualTypingCount = actualTypingCount
        self.suggestionAcceptanceCount = suggestionAcceptanceCount
        self.evidencePoints = evidencePoints
        self.typingWindowStartedAt = typingWindowStartedAt
        self.typingsInCurrentWindow = typingsInCurrentWindow
        self.lastEvidenceSource = lastEvidenceSource
        self.confirmationSource = confirmationSource
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
        case actualTypingCount
        case suggestionAcceptanceCount
        case evidencePoints
        case typingWindowStartedAt
        case typingsInCurrentWindow
        case lastEvidenceSource
        case confirmationSource
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
            ?? .provisional
        observedMomentCount = try container.decodeIfPresent(Int.self, forKey: .observedMomentCount)
            ?? (acceptedCount > 0 ? 1 : 0)
        lastObservedMomentAt = try container.decodeIfPresent(Date.self, forKey: .lastObservedMomentAt) ?? lastSeenAt
        actualTypingCount = try container.decodeIfPresent(Int.self, forKey: .actualTypingCount) ?? acceptedCount
        suggestionAcceptanceCount = try container.decodeIfPresent(Int.self, forKey: .suggestionAcceptanceCount) ?? 0
        evidencePoints = try container.decodeIfPresent(Double.self, forKey: .evidencePoints)
            ?? Self.legacyEvidence(
                typingCount: actualTypingCount,
                observedMoments: observedMomentCount
            )
        typingWindowStartedAt = try container.decodeIfPresent(Date.self, forKey: .typingWindowStartedAt)
            ?? lastObservedMomentAt
        typingsInCurrentWindow = try container.decodeIfPresent(Int.self, forKey: .typingsInCurrentWindow)
            ?? (observedMomentCount <= 1 ? actualTypingCount : min(actualTypingCount, 3))
        lastEvidenceSource = try container.decodeIfPresent(EngramEvidenceSource.self, forKey: .lastEvidenceSource)
            ?? (acceptedCount > 0 ? .typed : nil)
        confirmationSource = try container.decodeIfPresent(EngramEvidenceSource.self, forKey: .confirmationSource)
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
        try container.encode(actualTypingCount, forKey: .actualTypingCount)
        try container.encode(suggestionAcceptanceCount, forKey: .suggestionAcceptanceCount)
        try container.encode(evidencePoints, forKey: .evidencePoints)
        try container.encode(typingWindowStartedAt, forKey: .typingWindowStartedAt)
        try container.encode(typingsInCurrentWindow, forKey: .typingsInCurrentWindow)
        try container.encodeIfPresent(lastEvidenceSource, forKey: .lastEvidenceSource)
        try container.encodeIfPresent(confirmationSource, forKey: .confirmationSource)
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

    private static func legacyEvidence(typingCount: Int, observedMoments: Int) -> Double {
        guard typingCount > 0 else { return 0 }
        let moments = max(1, min(typingCount, observedMoments))
        let fullCreditTypings = min(typingCount, moments + 2)
        let repeatedTypings = max(0, typingCount - fullCreditTypings)
        return Double(fullCreditTypings)
            + Double(repeatedTypings) * 0.25
            + Double(moments - 1) * 3.0
    }
}

enum EngramEvidenceSource: String, Codable, Equatable {
    case typed
    case suggestion
    case autocorrectionUndo
    case manual

    var isExplicit: Bool {
        self == .autocorrectionUndo || self == .manual
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
    nonisolated private static let protectedPersonalTokens: Set<String> = [
        "af", "brb", "btw", "dm", "fr", "fyi", "gg", "idc", "idk", "ikr", "imo",
        "irl", "jk", "lmao", "lol", "ngl", "np", "omw", "rn", "smh", "tbh",
        "tfw", "wyd"
    ]

    nonisolated private static let blockedWords: Set<String> = [
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

    nonisolated static func normalize(_ word: String) -> String {
        word.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
            .lowercased()
    }

    nonisolated static func shouldLearn(_ word: String) -> Bool {
        shouldLearnConfirmed(word)
    }

    nonisolated static func shouldLearnConfirmed(_ word: String) -> Bool {
        if isProtectedPersonalToken(word) {
            return true
        }
        guard word.count >= 4 else { return false }
        guard !blockedWords.contains(word) else { return false }
        return isWordLike(word)
    }

    nonisolated static func shouldObserve(_ word: String) -> Bool {
        if isProtectedPersonalToken(word) {
            return true
        }
        guard word.count >= 4 else { return false }
        guard !blockedWords.contains(word) else { return false }
        return isWordLike(word)
    }

    nonisolated static func isProtectedPersonalToken(_ word: String) -> Bool {
        protectedPersonalTokens.contains(word)
    }

    nonisolated static func isWordLike(_ word: String) -> Bool {
        word.rangeOfCharacter(from: .letters) != nil
            && word.rangeOfCharacter(from: CharacterSet.letters.union(CharacterSet(charactersIn: "'")).inverted) == nil
    }

    nonisolated static var commonWordsForAutocorrect: Set<String> {
        blockedWords
    }

    nonisolated static func contentWords(in text: String) -> [String] {
        let pattern = #"[A-Za-z']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let wordRange = Range(match.range, in: text) else { return nil }
            let normalized = normalize(String(text[wordRange]))
            return shouldLearn(normalized) ? normalized : nil
        }
    }

    nonisolated static func ngramTokens(in text: String) -> [String] {
        ngramSurfaceTokens(in: text).map(normalize)
    }

    nonisolated static func ngramSurfaceTokens(in text: String) -> [String] {
        let pattern = #"[A-Za-z']+"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: range).compactMap { match in
            guard let wordRange = Range(match.range, in: text) else { return nil }
            let surface = String(text[wordRange])
            let normalized = normalize(surface)
            guard !normalized.isEmpty else { return nil }
            guard normalized.rangeOfCharacter(from: .letters) != nil else { return nil }
            return surface
        }
    }

    nonisolated static func ngramSurfaceTokenSequences(in text: String) -> [[String]] {
        let boundaryPattern = #"[.!?;\n\r]+"#
        guard let boundaryRegex = try? NSRegularExpression(pattern: boundaryPattern) else {
            let tokens = ngramSurfaceTokens(in: text)
            return tokens.isEmpty ? [] : [tokens]
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let separated = boundaryRegex.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: "\u{1E}"
        )
        return separated
            .split(separator: "\u{1E}", omittingEmptySubsequences: true)
            .map { ngramSurfaceTokens(in: String($0)) }
            .filter { !$0.isEmpty }
    }
}
