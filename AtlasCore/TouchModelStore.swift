import Foundation

/// Saves and loads the touch model from disk.
///
/// Uses the App Group shared container so the main app and the keyboard extension
/// share the same model. The main app can read the model to show personalization
/// stats; the keyboard extension is the only thing that writes to it.
///
/// Usage:
///   let store = TouchModelStore(appGroupID: "group.com.keygram.shared")
///   let model = store.load() ?? TouchModel(portraitLayout: ..., landscapeLayout: ...)
///   // ... use model ...
///   store.save(model)
final class TouchModelStore {

    private let fileURL: URL
    private let queue = DispatchQueue(label: "com.keygram.touchmodel.persist", qos: .utility)

    /// `appGroupID` should match the App Group you've enabled on both the main app
    /// and the keyboard extension target in Xcode (e.g. "group.com.keygram.shared").
    init?(appGroupID: String, filename: String = "touch_model.json") {
        guard let containerURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
        else {
            // App Group not set up — caller should fall back to in-memory model.
            return nil
        }
        self.fileURL = containerURL.appendingPathComponent(filename)
    }

    /// Load the model from disk. Returns nil if no saved model exists or if loading failed.
    /// The caller should construct a fresh `TouchModel` from layouts in that case.
    func load() -> TouchModel? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(TouchModel.self, from: data)
        } catch {
            // Don't crash on a corrupt model file — log and start fresh.
            // In production you'd want to send this to your error reporter.
            NSLog("Keygram: failed to load touch model: \(error)")
            return nil
        }
    }

    /// Save asynchronously off the main thread. Safe to call frequently
    /// (e.g. once per committed word).
    func save(_ model: TouchModel) {
        let data: Data
        do {
            data = try JSONEncoder().encode(model)
        } catch {
            NSLog("Keygram: failed to encode touch model: \(error)")
            return
        }

        queue.async { [fileURL] in
            do {
                // Atomic write: writes to a temp file, then renames into place.
                // This means we never end up with a half-written corrupted file
                // even if the keyboard extension is killed mid-save.
                try data.write(to: fileURL, options: [.atomic])
            } catch {
                NSLog("Keygram: failed to save touch model: \(error)")
            }
        }
    }

    /// For "reset personalization" in settings.
    func deleteSavedModel() {
        queue.async { [fileURL] in
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    /// For migrations that must not race with a following save.
    func deleteSavedModelSynchronously() {
        queue.sync { [fileURL] in
            try? FileManager.default.removeItem(at: fileURL)
        }
    }
}
