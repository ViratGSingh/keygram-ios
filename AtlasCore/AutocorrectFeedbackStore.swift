import Foundation

struct AutocorrectFeedbackSnapshot: Equatable {
    var accepted: [String: [String: Int]] = [:]
    var rejected: [String: [String: Int]] = [:]
    var contextAccepted: [String: [String: Int]] = [:]

    func acceptedCount(typed: String, candidate: String) -> Int {
        accepted[typed]?[candidate] ?? 0
    }

    func rejectedCount(typed: String, candidate: String) -> Int {
        rejected[typed]?[candidate] ?? 0
    }

    func contextAcceptedCount(contextKey: String, typed: String, candidate: String) -> Int {
        contextAccepted[Self.contextMapKey(contextKey: contextKey, typed: typed)]?[candidate] ?? 0
    }

    static func contextMapKey(contextKey: String, typed: String) -> String {
        "\(contextKey)|\(typed)"
    }
}

struct AutocorrectFeedbackSummary: Identifiable, Equatable {
    var id: String { "\(typed)->\(candidate)" }
    var typed: String
    var candidate: String
    var acceptedCount: Int
    var rejectedCount: Int
    var lastSeenAt: Date
}

final class AutocorrectFeedbackStore {
    static let shared = AutocorrectFeedbackStore()

    private struct State: Codable {
        var accepted: [String: [String: FeedbackEntry]] = [:]
        var rejected: [String: [String: FeedbackEntry]] = [:]
        var contextAccepted: [String: [String: FeedbackEntry]] = [:]
    }

    private struct FeedbackEntry: Codable {
        var count: Int
        var lastSeenAt: Date
    }

    private let fileName = "atlas-autocorrect-feedback-v1.json"
    private let queue = DispatchQueue(label: "com.wooshir.keygram.autocorrect-feedback", qos: .utility)

    private var baseURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AtlasConfiguration.appGroupIdentifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private var fileURL: URL {
        baseURL.appendingPathComponent(fileName)
    }

    func snapshot() -> AutocorrectFeedbackSnapshot {
        let state = loadState()
        return AutocorrectFeedbackSnapshot(
            accepted: state.accepted.mapValues { $0.mapValues(\.count) },
            rejected: state.rejected.mapValues { $0.mapValues(\.count) },
            contextAccepted: state.contextAccepted.mapValues { $0.mapValues(\.count) }
        )
    }

    func recordAccepted(typed: String, correction: String, contextKey: String) {
        update { state in
            Self.increment(typed: typed, correction: correction, in: &state.accepted)
            if !contextKey.isEmpty {
                Self.increment(
                    typed: AutocorrectFeedbackSnapshot.contextMapKey(contextKey: contextKey, typed: typed),
                    correction: correction,
                    in: &state.contextAccepted
                )
            }
            Self.prune(&state)
        }
    }

    func recordRejected(typed: String, correction: String, contextKey: String) {
        update { state in
            Self.increment(typed: typed, correction: correction, in: &state.rejected)
            Self.prune(&state)
        }
    }

    func summaries(limit: Int = 50) -> [AutocorrectFeedbackSummary] {
        let state = loadState()
        var rows: [AutocorrectFeedbackSummary] = []
        for (typed, candidates) in state.accepted {
            for (candidate, entry) in candidates {
                rows.append(
                    AutocorrectFeedbackSummary(
                        typed: typed,
                        candidate: candidate,
                        acceptedCount: entry.count,
                        rejectedCount: state.rejected[typed]?[candidate]?.count ?? 0,
                        lastSeenAt: entry.lastSeenAt
                    )
                )
            }
        }
        for (typed, candidates) in state.rejected {
            for (candidate, entry) in candidates where state.accepted[typed]?[candidate] == nil {
                rows.append(
                    AutocorrectFeedbackSummary(
                        typed: typed,
                        candidate: candidate,
                        acceptedCount: 0,
                        rejectedCount: entry.count,
                        lastSeenAt: entry.lastSeenAt
                    )
                )
            }
        }
        return Array(rows.sorted { $0.lastSeenAt > $1.lastSeenAt }.prefix(limit))
    }

    func reset() {
        queue.sync {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    func remove(typed: String, candidate: String) {
        queue.sync {
            var state = loadState()
            state.accepted[typed]?[candidate] = nil
            state.rejected[typed]?[candidate] = nil
            if state.accepted[typed]?.isEmpty == true {
                state.accepted[typed] = nil
            }
            if state.rejected[typed]?.isEmpty == true {
                state.rejected[typed] = nil
            }
            saveState(state)
        }
    }

    private func update(_ mutate: @escaping (inout State) -> Void) {
        queue.async { [self] in
            var state = self.loadState()
            mutate(&state)
            self.saveState(state)
        }
    }

    private func loadState() -> State {
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(State.self, from: data)
        } catch {
            return State()
        }
    }

    private func saveState(_ state: State) {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            NSLog("Keygram: failed to save autocorrect feedback: \(error)")
        }
    }

    private static func increment(typed: String, correction: String, in table: inout [String: [String: FeedbackEntry]]) {
        let now = Date()
        var candidates = table[typed] ?? [:]
        var entry = candidates[correction] ?? FeedbackEntry(count: 0, lastSeenAt: now)
        entry.count += 1
        entry.lastSeenAt = now
        candidates[correction] = entry
        table[typed] = candidates
    }

    private static func prune(_ state: inout State) {
        pruneTable(&state.accepted)
        pruneTable(&state.rejected)
        pruneTable(&state.contextAccepted, maxKeys: 3_000)
    }

    private static func pruneTable(_ table: inout [String: [String: FeedbackEntry]], maxKeys: Int = 5_000) {
        let cutoff = Date().addingTimeInterval(-90 * 24 * 60 * 60)
        for key in table.keys {
            table[key] = table[key]?.filter { $0.value.lastSeenAt >= cutoff }
            if table[key]?.isEmpty == true {
                table[key] = nil
            }
        }

        guard table.count > maxKeys else { return }
        let sortedKeys = Set(table
            .map { key, candidates in
                (key, candidates.values.map(\.lastSeenAt).max() ?? .distantPast)
            }
            .sorted { $0.1 > $1.1 }
            .prefix(maxKeys)
            .map(\.0))
        table = table.filter { sortedKeys.contains($0.key) }
    }
}
