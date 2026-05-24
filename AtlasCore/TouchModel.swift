import Foundation
import CoreGraphics

/// One key's position and dimensions in the keyboard layout.
struct KeyLayout: Codable {
    let id: String              // e.g. "h", "shift", "space"
    let centerX: Double         // points, keyboard-local
    let centerY: Double
    let width: Double
    let height: Double
}

/// Which physical orientation the device is in. Tap distributions differ between these
/// (different reach, different thumb angles), so we keep a separate touch model per orientation.
enum DeviceOrientation: String, Codable {
    case portrait
    case landscape
}

/// The touch model — the heart of the spatial decoder.
/// It holds a `KeyGaussian` per key per orientation, scores incoming taps,
/// and updates from confirmed taps.
final class TouchModel: Codable {
    /// gaussians[orientation][keyID] -> KeyGaussian
    private var gaussians: [DeviceOrientation: [String: KeyGaussian]]
    /// Layout per orientation — needed to initialize new keys lazily and to
    /// know which keys exist when scoring.
    private var layouts: [DeviceOrientation: [String: KeyLayout]]

    init(portraitLayout: [KeyLayout], landscapeLayout: [KeyLayout]) {
        var portraitGaussians: [String: KeyGaussian] = [:]
        for key in portraitLayout {
            portraitGaussians[key.id] = KeyGaussian(
                centerX: key.centerX, centerY: key.centerY,
                keyWidth: key.width, keyHeight: key.height
            )
        }
        var landscapeGaussians: [String: KeyGaussian] = [:]
        for key in landscapeLayout {
            landscapeGaussians[key.id] = KeyGaussian(
                centerX: key.centerX, centerY: key.centerY,
                keyWidth: key.width, keyHeight: key.height
            )
        }
        self.gaussians = [
            .portrait: portraitGaussians,
            .landscape: landscapeGaussians,
        ]
        var portraitLayoutDict: [String: KeyLayout] = [:]
        for key in portraitLayout { portraitLayoutDict[key.id] = key }
        var landscapeLayoutDict: [String: KeyLayout] = [:]
        for key in landscapeLayout { landscapeLayoutDict[key.id] = key }
        self.layouts = [
            .portrait: portraitLayoutDict,
            .landscape: landscapeLayoutDict,
        ]
    }

    /// Score every key against an incoming tap.
    /// Returns log-likelihoods (not probabilities) for use in further decoding.
    /// Higher = more likely the user meant that key.
    func scoreTap(x: Double, y: Double, orientation: DeviceOrientation) -> [String: Double] {
        guard let keys = gaussians[orientation] else { return [:] }
        var scores: [String: Double] = [:]
        scores.reserveCapacity(keys.count)
        for (keyID, gaussian) in keys {
            scores[keyID] = gaussian.logLikelihood(x: x, y: y)
        }
        return scores
    }

    /// Convenience: just return the top-N most likely keys for a tap.
    /// Useful for the beam search downstream — it doesn't need all 30 keys, just the top few.
    func topKeys(x: Double, y: Double, orientation: DeviceOrientation, count: Int = 5)
        -> [(keyID: String, logLikelihood: Double)]
    {
        let scores = scoreTap(x: x, y: y, orientation: orientation)
        return scores
            .sorted { $0.value > $1.value }
            .prefix(count)
            .map { ($0.key, $0.value) }
    }

    func isInsideVisibleBounds(x: Double, y: Double, keyID: String, orientation: DeviceOrientation) -> Bool {
        guard let key = layouts[orientation]?[keyID] else { return false }
        return abs(x - key.centerX) <= key.width / 2
            && abs(y - key.centerY) <= key.height / 2
    }

    @discardableResult
    func repairLayouts(portraitLayout: [KeyLayout], landscapeLayout: [KeyLayout]) -> [String] {
        let repairedPortrait = repairLayout(portraitLayout, orientation: .portrait)
        let repairedLandscape = repairLayout(landscapeLayout, orientation: .landscape)
        return Array(Set(repairedPortrait + repairedLandscape)).sorted()
    }

    var hasCompleteLetterLayout: Bool {
        completeLetterCount == Self.requiredLetterIDs.count
    }

    var completeLetterCount: Int {
        guard let portrait = gaussians[.portrait],
              let landscape = gaussians[.landscape]
        else { return 0 }

        return Self.requiredLetterIDs.filter { letter in
            portrait[letter] != nil && landscape[letter] != nil
        }.count
    }

    static var requiredLetterCount: Int {
        requiredLetterIDs.count
    }

    func debugDump(label: String) {
        #if DEBUG
        NSLog("[Keygram TouchModel] dump %@", label)
        for orientation in [DeviceOrientation.portrait, .landscape] {
            guard let keys = gaussians[orientation] else { continue }
            for keyID in Self.requiredLetterIDs.sorted() {
                guard let gaussian = keys[keyID] else {
                    NSLog("[Keygram TouchModel] %@ key='%@' missing", orientation.rawValue, keyID)
                    continue
                }
                NSLog(
                    "[Keygram TouchModel] %@ key='%@' mean=(%.1f, %.1f) initial=(%.1f, %.1f) drift=(%.1f, %.1f) varX=%.1f varY=%.1f n=%d",
                    orientation.rawValue,
                    keyID,
                    gaussian.meanX,
                    gaussian.meanY,
                    gaussian.initialCenterX,
                    gaussian.initialCenterY,
                    gaussian.meanX - gaussian.initialCenterX,
                    gaussian.meanY - gaussian.initialCenterY,
                    gaussian.varX,
                    gaussian.varY,
                    gaussian.sampleCount
                )
            }
        }
        #endif
    }

    /// Update the model with a confirmed tap (one we're confident was meant for `keyID`).
    /// Call this only when:
    ///   - The tap survived without correction (user didn't backspace), AND
    ///   - The word containing this tap was committed as expected
    /// Don't call this on every tap — bad labels poison the model fast.
    func observe(x: Double, y: Double, keyID: String, orientation: DeviceOrientation) {
        guard var keyGaussian = gaussians[orientation]?[keyID] else { return }
        keyGaussian.update(x: x, y: y)
        gaussians[orientation]?[keyID] = keyGaussian
    }

    /// Total observed taps across all keys/orientations. Useful for telling the user
    /// "your keyboard has learned from N taps" and for deciding when personalization
    /// is "ready".
    var totalSamples: Int {
        var total = 0
        for (_, keys) in gaussians {
            for (_, g) in keys { total += g.sampleCount }
        }
        return total
    }

    /// Reset the model back to factory defaults (for "reset personalization" in settings).
    func reset() {
        for (orientation, layout) in layouts {
            var resetKeys: [String: KeyGaussian] = [:]
            for (id, key) in layout {
                resetKeys[id] = KeyGaussian(
                    centerX: key.centerX, centerY: key.centerY,
                    keyWidth: key.width, keyHeight: key.height
                )
            }
            gaussians[orientation] = resetKeys
        }
    }

    private static let requiredLetterIDs = Set("abcdefghijklmnopqrstuvwxyz".map(String.init))

    private func repairLayout(_ layout: [KeyLayout], orientation: DeviceOrientation) -> [String] {
        let layoutDictionary = Dictionary(uniqueKeysWithValues: layout.map { ($0.id, $0) })
        layouts[orientation] = layoutDictionary
        var keys = gaussians[orientation] ?? [:]
        var repairedKeys: [String] = []

        for key in layout {
            if var gaussian = keys[key.id] {
                gaussian.repairLayoutAnchor(
                    centerX: key.centerX,
                    centerY: key.centerY,
                    keyWidth: key.width,
                    keyHeight: key.height
                )
                keys[key.id] = gaussian
            } else {
                keys[key.id] = KeyGaussian(
                    centerX: key.centerX,
                    centerY: key.centerY,
                    keyWidth: key.width,
                    keyHeight: key.height
                )
                repairedKeys.append(key.id)
            }
        }

        gaussians[orientation] = keys
        return repairedKeys
    }
}
