import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Complete, restorable snapshot of everything Keygram has personalized for a user.
///
/// Assembled from the on-device stores and mirrored to the cloud (Firestore) so a
/// user's learned data follows them across devices and reinstalls. Lives in the main
/// app target only — the keyboard extension never syncs.
struct KeygramBackup: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    /// When this snapshot was produced. Drives last-write-wins on restore.
    var updatedAt: Date
    /// Vendor device identifier that produced the snapshot (diagnostics / conflict origin).
    var deviceId: String

    /// Persona: personal vocabulary (`Engram`), n-gram language model, and GLA neural
    /// state. Kept structured because `AtlasSession` is already `Codable` and we merge it
    /// field-wise on restore rather than overwriting.
    var sessions: [AtlasSession]

    /// Opaque JSON blobs exported by the feedback / touch stores. Base64-encoded inside
    /// JSON; treated as whole-value last-write-wins on restore.
    var autocorrectFeedback: Data?
    var nextWordFeedback: Data?
    var touchModel: Data?

    /// User-facing preference toggles from the App Group `UserDefaults`.
    var settings: SettingsSnapshot
}

/// Typed capture of the App Group `UserDefaults` preference keys, grouped by value kind
/// so the whole thing stays `Codable`. Device-specific flags (Full Access granted, last
/// active timestamp) and on-device migration/schema versions are intentionally excluded —
/// those are per-device state, not user preference.
struct SettingsSnapshot: Codable, Equatable {
    var bools: [String: Bool] = [:]

    /// Preference keys worth carrying between a user's devices.
    static let backedUpBoolKeys: [String] = [
        AtlasConfiguration.hapticsEnabledKey,
        AtlasConfiguration.autocorrectEnabledKey,
        AtlasConfiguration.aiRewriteEnabledKey,
        AtlasConfiguration.aiRewriteDisclosureAcceptedKey,
        AtlasConfiguration.inferenceSuggestionsEnabledKey,
        AtlasConfiguration.neuralOnlyEvaluationEnabledKey,
        AtlasConfiguration.personalizedAutocorrectEnabledKey,
        AtlasConfiguration.personalizedTypingEnabledKey,
        AtlasConfiguration.learnNewWordsEnabledKey,
        AtlasConfiguration.onboardingCompletedKey,
    ]
}

/// Builds a `KeygramBackup` from the current on-device state and applies a restored
/// backup back into the local stores. All work reuses the stores' existing public APIs.
enum KeygramBackupAssembler {
    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) ?? .standard
    }

    /// Snapshot everything Keygram has learned on this device right now.
    static func makeCurrentBackup() -> KeygramBackup {
        KeygramBackup(
            schemaVersion: KeygramBackup.currentSchemaVersion,
            updatedAt: Date(),
            deviceId: currentDeviceId(),
            sessions: AtlasSessionStore.shared.loadSessions(),
            autocorrectFeedback: AutocorrectFeedbackStore.shared.exportData(),
            nextWordFeedback: NextWordFeedbackStore.shared.exportData(),
            touchModel: TouchModelStore(appGroupID: AtlasConfiguration.appGroupIdentifier)?.exportData(),
            settings: currentSettings()
        )
    }

    /// Write a restored backup into the local stores.
    ///
    /// - Persona sessions are **merged** (not overwritten): the remote sessions are unioned
    ///   with the local ones and handed to `AtlasSessionStore.saveSessions`, whose
    ///   `ensureSingleUserSession` already merges `Engram`s and keeps the newest GLA state.
    /// - Feedback, touch model, and settings are whole-value **last-write-wins**; the caller
    ///   (`BackupSyncService`) decides direction by comparing timestamps before calling this.
    static func apply(_ backup: KeygramBackup) {
        let merged = AtlasSessionStore.shared.loadSessions() + backup.sessions
        AtlasSessionStore.shared.saveSessions(merged)

        if let data = backup.autocorrectFeedback {
            AutocorrectFeedbackStore.shared.importData(data)
        }
        if let data = backup.nextWordFeedback {
            NextWordFeedbackStore.shared.importData(data)
        }
        if let data = backup.touchModel {
            TouchModelStore(appGroupID: AtlasConfiguration.appGroupIdentifier)?.importData(data)
        }

        applySettings(backup.settings)
    }

    // MARK: - Settings

    private static func currentSettings() -> SettingsSnapshot {
        var snapshot = SettingsSnapshot()
        let defaults = sharedDefaults
        for key in SettingsSnapshot.backedUpBoolKeys where defaults.object(forKey: key) != nil {
            snapshot.bools[key] = defaults.bool(forKey: key)
        }
        return snapshot
    }

    private static func applySettings(_ settings: SettingsSnapshot) {
        let defaults = sharedDefaults
        for (key, value) in settings.bools where SettingsSnapshot.backedUpBoolKeys.contains(key) {
            defaults.set(value, forKey: key)
        }
    }

    // MARK: - Device id

    private static let deviceIdKey = "atlas.backupDeviceId"

    private static func currentDeviceId() -> String {
        #if canImport(UIKit)
        if let id = UIDevice.current.identifierForVendor?.uuidString {
            return id
        }
        #endif
        let defaults = sharedDefaults
        if let existing = defaults.string(forKey: deviceIdKey) {
            return existing
        }
        let generated = UUID().uuidString
        defaults.set(generated, forKey: deviceIdKey)
        return generated
    }
}
