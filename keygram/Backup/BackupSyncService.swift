import Foundation
import Combine
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Pushes the local `KeygramBackup` to Firestore and restores/merges it back.
///
/// Document layout: `users/{uid}` holds a single compressed backup payload plus metadata.
/// The `KeygramBackup` JSON is zlib-compressed before upload to stay well under Firestore's
/// 1 MiB document ceiling (GLA tensors + n-gram tables compress heavily). If a heavy user's
/// payload ever approaches that ceiling, migrate the blob to Firebase Storage and keep only
/// metadata here — see the setup doc.
///
/// Firestore code is `canImport`-guarded so the app compiles before the SDK is added.
@MainActor
final class BackupSyncService: ObservableObject {
    static let shared = BackupSyncService()

    /// Which user-facing operation is currently running, so the UI can show a spinner on the
    /// specific button that was tapped rather than on all of them.
    enum Operation { case backUp, restore, sync }

    @Published private(set) var isSyncing = false
    @Published private(set) var activeOperation: Operation?
    @Published private(set) var lastSyncedAt: Date?
    @Published var lastError: String?

    private let lastSyncedKey = "atlas.backupLastSyncedAt"

    private init() {
        let stored = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier)?
            .double(forKey: lastSyncedKey) ?? 0
        if stored > 0 {
            lastSyncedAt = Date(timeIntervalSince1970: stored)
        }
    }

    /// One-shot "Back up now": snapshot the device and push it.
    func backUpNow(uid: String) async {
        await withSyncing(.backUp) {
            let backup = KeygramBackupAssembler.makeCurrentBackup()
            try await push(backup, uid: uid)
            recordSynced(backup.updatedAt, uid: uid)
        }
    }

    /// Full reconcile: pull remote, apply it if it should win, then push the merged result
    /// so both sides converge. Called on sign-in and app-foreground.
    ///
    /// The first time this device syncs a given account, an existing cloud backup always
    /// wins: we restore it before pushing so a fresh / just-installed device can never
    /// overwrite that account's data with an empty local snapshot. After that first sync we
    /// fall back to last-write-wins by timestamp.
    func sync(uid: String) async {
        await withSyncing(.sync) {
            let firstSyncForAccount = !hasSynced(uid: uid)
            if let remote = try await pull(uid: uid),
               firstSyncForAccount || remote.updatedAt > (lastSyncedAt ?? .distantPast) {
                KeygramBackupAssembler.apply(remote)
            }
            let merged = KeygramBackupAssembler.makeCurrentBackup()
            try await push(merged, uid: uid)
            recordSynced(merged.updatedAt, uid: uid)
        }
    }

    /// Force-pull the cloud backup and apply it over local data, ignoring timestamps.
    /// Backs the manual "Restore from cloud" action, which the user confirms first.
    func restore(uid: String) async {
        await withSyncing(.restore) {
            guard let remote = try await pull(uid: uid) else {
                throw AuthManager.SimpleError(message: "No cloud backup found for this account yet.")
            }
            KeygramBackupAssembler.apply(remote)
            recordSynced(remote.updatedAt, uid: uid)
        }
    }

    // MARK: - Firestore transport

    #if canImport(FirebaseFirestore)
    private func document(uid: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(uid)
    }

    private func push(_ backup: KeygramBackup, uid: String) async throws {
        let json = try JSONEncoder().encode(backup)
        let payload = (try? (json as NSData).compressed(using: .zlib) as Data) ?? json
        try await document(uid: uid).setData([
            "schemaVersion": backup.schemaVersion,
            "updatedAt": backup.updatedAt,
            "deviceId": backup.deviceId,
            "compressed": true,
            "payload": payload,
        ])
    }

    private func pull(uid: String) async throws -> KeygramBackup? {
        let snapshot = try await document(uid: uid).getDocument()
        guard let data = snapshot.data(), let payload = data["payload"] as? Data else {
            return nil
        }
        let compressed = (data["compressed"] as? Bool) ?? false
        let json = compressed ? ((try? (payload as NSData).decompressed(using: .zlib) as Data) ?? payload) : payload
        return try JSONDecoder().decode(KeygramBackup.self, from: json)
    }
    #else
    private func push(_ backup: KeygramBackup, uid: String) async throws {
        throw AuthManager.SimpleError(message: "Cloud backup isn't configured in this build yet.")
    }

    private func pull(uid: String) async throws -> KeygramBackup? {
        throw AuthManager.SimpleError(message: "Cloud backup isn't configured in this build yet.")
    }
    #endif

    // MARK: - Helpers

    private func withSyncing(_ operation: Operation, _ work: () async throws -> Void) async {
        guard !isSyncing else { return }
        isSyncing = true
        activeOperation = operation
        lastError = nil
        do {
            try await work()
        } catch {
            lastError = (error as? AuthManager.SimpleError)?.message ?? error.localizedDescription
        }
        isSyncing = false
        activeOperation = nil
    }

    private func recordSynced(_ date: Date, uid: String) {
        lastSyncedAt = date
        let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier)
        defaults?.set(date.timeIntervalSince1970, forKey: lastSyncedKey)
        defaults?.set(true, forKey: syncedFlagKey(uid: uid))
    }

    /// Whether this device has ever completed a successful backup/restore for `uid`.
    /// Drives the "existing cloud data wins on first sign-in" rule in `sync`.
    private func hasSynced(uid: String) -> Bool {
        UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier)?
            .bool(forKey: syncedFlagKey(uid: uid)) ?? false
    }

    private func syncedFlagKey(uid: String) -> String { "atlas.backupSynced.\(uid)" }
}
