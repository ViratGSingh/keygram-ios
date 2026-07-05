import CryptoKit
import Foundation

final class AtlasSessionStore {
    static let shared = AtlasSessionStore()

    private let fileName = "atlas-sessions-v1.json"
    private let keyTag = "atlas-local-dev-key-v1"

    private var baseURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AtlasConfiguration.appGroupIdentifier)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    }

    private var fileURL: URL { baseURL.appendingPathComponent(fileName) }

    func loadSessions() -> [AtlasSession] {
        do {
            let data = try Data(contentsOf: fileURL)
            let plaintext = try decrypt(data)
            let sessions = try JSONDecoder().decode([AtlasSession].self, from: plaintext)
            return ensureSingleUserSession(in: sessions)
        } catch {
            return seedSessions()
        }
    }

    func saveSessions(_ sessions: [AtlasSession]) {
        do {
            try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
            let encoded = try JSONEncoder().encode(ensureSingleUserSession(in: sessions))
            let encrypted = try encrypt(encoded)
            try encrypted.write(to: fileURL, options: [.atomic, .completeFileProtection])
        } catch {
            // Writing to the shared App Group container fails with a permission error when the
            // keyboard extension runs without Full Access. Persistence is best-effort, so degrade
            // quietly for that expected case and only trap on genuinely unexpected failures.
            if Self.isPermissionError(error) {
                NSLog("Keygram: skipped ATLAS session save; shared container not writable (Full Access off)")
            } else {
                assertionFailure("Failed to save ATLAS sessions: \(error)")
            }
        }
    }

    private static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain,
           nsError.code == NSFileWriteNoPermissionError || nsError.code == NSFileWriteVolumeReadOnlyError {
            return true
        }
        if nsError.domain == NSPOSIXErrorDomain,
           nsError.code == Int(EPERM) || nsError.code == Int(EACCES) {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            return isPermissionError(underlying)
        }
        return false
    }

    func activeSession(named name: String?) -> AtlasSession {
        let sessions = loadSessions()
        if let name, let session = sessions.first(where: { $0.name == name }) {
            return session
        }
        return sessions.first(where: { $0.name == AtlasSession.defaultName }) ?? .fresh(name: AtlasSession.defaultName)
    }

    func upsert(_ session: AtlasSession) {
        saveSessions([session])
    }

    private func ensureSingleUserSession(in sessions: [AtlasSession]) -> [AtlasSession] {
        guard var userSession = sessions.first(where: { isUserSessionName($0.name) }) ?? sessions.first else {
            return seedSessions()
        }

        for session in sessions where session.id != userSession.id {
            userSession.engram.merge(session.engram)
            if session.updatedAt > userSession.updatedAt {
                userSession.updatedAt = session.updatedAt
                userSession.glaState = session.glaState
            }
        }

        userSession.name = AtlasSession.defaultName
        userSession.avatarSeed = AtlasSession.defaultName
        if !userSession.glaState.isCompatibleWithCurrentModel {
            userSession.glaState = .empty()
        }
        return [userSession]
    }

    private func seedSessions() -> [AtlasSession] {
        [.fresh(name: AtlasSession.defaultName)]
    }

    private func isUserSessionName(_ name: String) -> Bool {
        name.localizedCaseInsensitiveCompare(AtlasSession.defaultName) == .orderedSame
            || name.localizedCaseInsensitiveCompare("Default") == .orderedSame
    }

    private func encrypt(_ data: Data) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: localKey())
        return sealedBox.combined ?? data
    }

    private func decrypt(_ data: Data) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(box, using: localKey())
    }

    private func localKey() -> SymmetricKey {
        let material = Data(keyTag.utf8)
        let digest = SHA256.hash(data: material)
        return SymmetricKey(data: Data(digest))
    }
}
