import Foundation

struct NextWordEvaluationSnapshot: Codable, Equatable {
    var predictionCount: Int = 0
    var top1HitCount: Int = 0
    var top3HitCount: Int = 0
    var selectedSuggestionCount: Int = 0
    var inferenceCount: Int = 0
    var totalInferenceMilliseconds: Double = 0
    var latencyBuckets: [Int] = Array(repeating: 0, count: 7)

    var top1Accuracy: Double {
        predictionCount > 0 ? Double(top1HitCount) / Double(predictionCount) : 0
    }

    var top3Accuracy: Double {
        predictionCount > 0 ? Double(top3HitCount) / Double(predictionCount) : 0
    }

    var suggestionSelectionRate: Double {
        predictionCount > 0 ? Double(selectedSuggestionCount) / Double(predictionCount) : 0
    }

    var averageInferenceMilliseconds: Double {
        inferenceCount > 0 ? totalInferenceMilliseconds / Double(inferenceCount) : 0
    }

    var p95InferenceMilliseconds: Int {
        guard inferenceCount > 0 else { return 0 }
        let threshold = Int(ceil(Double(inferenceCount) * 0.95))
        let upperBounds = [5, 10, 20, 40, 80, 160, 320]
        var cumulative = 0
        for (index, count) in latencyBuckets.enumerated() {
            cumulative += count
            if cumulative >= threshold {
                return upperBounds[min(index, upperBounds.count - 1)]
            }
        }
        return upperBounds.last ?? 0
    }
}

struct NextWordFeedbackSnapshot: Equatable {
    fileprivate var wordStats: [String: NextWordFeedbackStore.FeedbackStats] = [:]
    fileprivate var contextStats: [String: NextWordFeedbackStore.FeedbackStats] = [:]

    func rankingBoost(for word: String, context: String) -> Double {
        let normalized = EngramNormalizer.normalize(word)
        guard !normalized.isEmpty else { return 0 }
        let globalBoost = Self.boost(for: wordStats[normalized])
        let contextKey = NextWordFeedbackStore.contextKey(for: context)
        let contextualBoost = Self.boost(
            for: contextStats[NextWordFeedbackStore.contextWordKey(contextKey: contextKey, word: normalized)]
        )
        return max(-0.65, min(0.65, globalBoost * 0.55 + contextualBoost * 0.8))
    }

    private static func boost(for stats: NextWordFeedbackStore.FeedbackStats?) -> Double {
        guard let stats, stats.exposures >= 3 else { return 0 }
        let successes = Double(stats.selectedCount) + Double(stats.typedMatchCount) * 0.65
        let posteriorRate = (successes + 1.25) / (Double(stats.exposures) + 5.0)
        let priorRate = 0.25
        let posteriorLogOdds = log(posteriorRate / max(1e-6, 1 - posteriorRate))
        let priorLogOdds = log(priorRate / (1 - priorRate))
        let evidence = min(1.0, log(Double(stats.exposures + 1)) / log(20.0))
        return max(-0.55, min(0.55, (posteriorLogOdds - priorLogOdds) * 0.22 * evidence))
    }
}

final class NextWordFeedbackStore {
    static let shared = NextWordFeedbackStore()

    struct FeedbackStats: Codable, Equatable {
        var exposures: Int = 0
        var selectedCount: Int = 0
        var typedMatchCount: Int = 0
        var lastSeenAt: Date = Date()
    }

    private struct State: Codable {
        var evaluation = NextWordEvaluationSnapshot()
        var wordStats: [String: FeedbackStats] = [:]
        var contextStats: [String: FeedbackStats] = [:]
    }

    private let fileName = "atlas-next-word-feedback-v1.json"
    private let queue = DispatchQueue(label: "com.wooshir.keygram.next-word-feedback", qos: .utility)
    private var cachedState: State?
    /// Modification date of `fileURL` as of our last load/save. The metrics file is
    /// shared between the app and the keyboard extension (two processes), so this
    /// lets each side notice writes made by the other and drop its stale cache
    /// before reading or merging — e.g. so a reset in the app isn't resurrected by
    /// the extension writing its old cached counts back.
    private var lastKnownModificationDate: Date?

    private var baseURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AtlasConfiguration.appGroupIdentifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private var fileURL: URL {
        baseURL.appendingPathComponent(fileName)
    }

    func feedbackSnapshot() -> NextWordFeedbackSnapshot {
        queue.sync {
            let state = state()
            return NextWordFeedbackSnapshot(wordStats: state.wordStats, contextStats: state.contextStats)
        }
    }

    func evaluationSnapshot() -> NextWordEvaluationSnapshot {
        queue.sync { state().evaluation }
    }

    /// Drops the in-memory cache and re-reads the shared app-group file. The
    /// evaluation metrics are written by the keyboard extension (a separate
    /// process), so the containing app must reload from disk to observe updates —
    /// otherwise it keeps serving the frozen snapshot it first loaded. Call this
    /// before reading a fresh `evaluationSnapshot()` for display.
    func reloadFromDisk() {
        queue.sync {
            cachedState = loadState()
        }
    }

    func recordInference(milliseconds: Double) {
        update { state in
            state.evaluation.inferenceCount += 1
            state.evaluation.totalInferenceMilliseconds += max(0, milliseconds)
            let index: Int
            switch milliseconds {
            case ..<5: index = 0
            case ..<10: index = 1
            case ..<20: index = 2
            case ..<40: index = 3
            case ..<80: index = 4
            case ..<160: index = 5
            default: index = 6
            }
            state.evaluation.latencyBuckets[index] += 1
        }
    }

    func recordExposure(predictions: [String], context: String) {
        let normalizedPredictions = Self.normalizedFirstWords(predictions)
        guard !normalizedPredictions.isEmpty else { return }
        let contextKey = Self.contextKey(for: context)
        update { state in
            for word in normalizedPredictions {
                Self.incrementExposure(word: word, in: &state.wordStats)
                Self.incrementExposure(
                    word: Self.contextWordKey(contextKey: contextKey, word: word),
                    in: &state.contextStats
                )
            }
            Self.prune(&state)
        }
    }

    func recordOutcome(
        predictions: [String],
        actualText: String,
        selectedSuggestion: Bool,
        context: String
    ) {
        let normalizedPredictions = Self.normalizedFirstWords(predictions)
        guard let actualWord = EngramNormalizer.ngramTokens(in: actualText).first,
              !normalizedPredictions.isEmpty
        else {
            return
        }

        let contextKey = Self.contextKey(for: context)
        update { state in
            let matchedPrediction = normalizedPredictions.contains(actualWord)
            state.evaluation.predictionCount += 1
            if normalizedPredictions.first == actualWord {
                state.evaluation.top1HitCount += 1
            }
            if normalizedPredictions.prefix(3).contains(actualWord) {
                state.evaluation.top3HitCount += 1
            }
            if selectedSuggestion, matchedPrediction {
                state.evaluation.selectedSuggestionCount += 1
            }

            if matchedPrediction {
                Self.incrementPositive(
                    word: actualWord,
                    selectedSuggestion: selectedSuggestion,
                    in: &state.wordStats
                )
                Self.incrementPositive(
                    word: Self.contextWordKey(contextKey: contextKey, word: actualWord),
                    selectedSuggestion: selectedSuggestion,
                    in: &state.contextStats
                )
            }
            Self.prune(&state)
        }
    }

    /// Raw JSON snapshot of the persisted state (metrics + word/context stats),
    /// for cloud backup. Opaque `Data` so the private `State` schema stays internal.
    func exportData() -> Data? {
        queue.sync {
            try? JSONEncoder().encode(state())
        }
    }

    /// Replaces the persisted state from a backup snapshot produced by `exportData()`.
    /// Malformed data is ignored so a bad restore can't wipe local data.
    func importData(_ data: Data) {
        queue.sync {
            guard let decoded = try? JSONDecoder().decode(State.self, from: data) else { return }
            cachedState = decoded
            saveState(decoded)
        }
    }

    func resetEvaluation() {
        queue.sync {
            var current = state()
            current.evaluation = NextWordEvaluationSnapshot()
            cachedState = current
            saveState(current)
        }
    }

    func resetFeedback() {
        queue.sync {
            var current = state()
            current.wordStats = [:]
            current.contextStats = [:]
            cachedState = current
            saveState(current)
        }
    }

    static func contextKey(for context: String) -> String {
        EngramNormalizer.ngramTokens(in: context).suffix(2).joined(separator: " ")
    }

    fileprivate static func contextWordKey(contextKey: String, word: String) -> String {
        "\(contextKey)|\(word)"
    }

    private func update(_ mutate: @escaping (inout State) -> Void) {
        queue.async { [self] in
            var current = state()
            mutate(&current)
            cachedState = current
            saveState(current)
        }
    }

    private func state() -> State {
        if let cachedState, !fileChangedExternally() {
            return cachedState
        }
        let loaded = loadState()
        cachedState = loaded
        return loaded
    }

    /// True when the shared file has been modified since we last loaded/saved it,
    /// i.e. the other process wrote to it. A cheap `stat`; the expensive decode in
    /// `loadState()` only runs when this actually reports a change.
    private func fileChangedExternally() -> Bool {
        guard let current = fileModificationDate() else { return false }
        guard let last = lastKnownModificationDate else { return true }
        return current > last
    }

    private func fileModificationDate() -> Date? {
        (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    private func loadState() -> State {
        var loaded = State()
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: fileURL, options: [], error: &coordinationError) { url in
            guard let data = try? Data(contentsOf: url),
                  let decoded = try? JSONDecoder().decode(State.self, from: data)
            else {
                return
            }
            loaded = decoded
        }
        lastKnownModificationDate = fileModificationDate()
        return loaded
    }

    private func saveState(_ state: State) {
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: fileURL, options: [], error: &coordinationError) { url in
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(state)
                try data.write(to: url, options: [.atomic])
            } catch {
                NSLog("Keygram: failed to save next-word feedback: \(error)")
            }
        }
        lastKnownModificationDate = fileModificationDate()
    }

    private static func normalizedFirstWords(_ predictions: [String]) -> [String] {
        var seen = Set<String>()
        return predictions.compactMap { prediction in
            guard let word = EngramNormalizer.ngramTokens(in: prediction).first,
                  seen.insert(word).inserted
            else {
                return nil
            }
            return word
        }
    }

    private static func incrementExposure(word: String, in table: inout [String: FeedbackStats]) {
        var stats = table[word] ?? FeedbackStats()
        stats.exposures += 1
        stats.lastSeenAt = Date()
        table[word] = stats
    }

    private static func incrementPositive(
        word: String,
        selectedSuggestion: Bool,
        in table: inout [String: FeedbackStats]
    ) {
        var stats = table[word] ?? FeedbackStats()
        if selectedSuggestion {
            stats.selectedCount += 1
        } else {
            stats.typedMatchCount += 1
        }
        stats.lastSeenAt = Date()
        table[word] = stats
    }

    private static func prune(_ state: inout State) {
        pruneTable(&state.wordStats, limit: 4_000)
        pruneTable(&state.contextStats, limit: 8_000)
    }

    private static func pruneTable(_ table: inout [String: FeedbackStats], limit: Int) {
        let cutoff = Date().addingTimeInterval(-120 * 24 * 60 * 60)
        table = table.filter { $0.value.lastSeenAt >= cutoff }
        guard table.count > limit else { return }
        let kept = table
            .sorted {
                if $0.value.exposures == $1.value.exposures {
                    return $0.value.lastSeenAt > $1.value.lastSeenAt
                }
                return $0.value.exposures > $1.value.exposures
            }
            .prefix(limit)
        table = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
    }
}
