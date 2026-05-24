import Foundation
import UIKit

/// One observed tap, with everything we need to label it later.
private struct PendingTap {
    let x: Double
    let y: Double
    let orientation: DeviceOrientation
    /// The model's best guess at the time the tap occurred. This is what the user
    /// sees on screen as they type. May be replaced by autocorrect later.
    let liveGuess: String
}

/// Orchestrates the spatial decoding pipeline:
///   1. Receives raw taps from the keyboard view.
///   2. Picks a live letter guess (so the user sees something instantly).
///   3. Buffers taps until a word boundary (space, punctuation).
///   4. At the word boundary, runs autocorrect (joint with the LM — wired separately).
///   5. Uses the final committed word to label each tap with its true intended key.
///   6. Updates the touch model from those labeled taps.
///
/// The decoder is the only thing that calls `TouchModel.observe()` — this keeps
/// label quality high (only confirmed taps update the model).
final class KeygramDecoder {

    private enum DecodingPolicy {
        static let likelihoodMargin = 2.0
    }

    private let touchModel: TouchModel
    private let store: TouchModelStore?
    private var pendingTaps: [PendingTap] = []
    private var overrideCount = 0
    private var disagreeNoopCount = 0
    private var summaryDay = Calendar.current.startOfDay(for: Date())

    /// Set of characters that terminate a "word" for the purposes of labeling and committing.
    private let wordBoundaryChars: Set<String> = [" ", ".", ",", "!", "?", ";", ":", "\n"]

    init(touchModel: TouchModel, store: TouchModelStore?) {
        self.touchModel = touchModel
        self.store = store
    }

    deinit {
        logDailySummary(force: true)
    }

    /// Called by the keyboard view when the user taps somewhere.
    /// Returns the best-guess character to display immediately.
    ///
    /// `x`, `y` are in keyboard-local point coordinates.
    func handleTap(x: Double, y: Double, orientation: DeviceOrientation) -> String? {
        let candidates = touchModel.topKeys(
            x: x, y: y, orientation: orientation, count: 5
        )
        guard let best = candidates.first else { return nil }
        let guess = best.keyID

        // If this tap is a word boundary, commit the buffered word first,
        // then commit the boundary character separately.
        if wordBoundaryChars.contains(guess) {
            commitPendingWord(actualWord: nil)  // nil = accept the live guesses as-is
            // The boundary character itself goes through with its own update below.
            touchModel.observe(x: x, y: y, keyID: guess, orientation: orientation)
            persist()
            return guess
        }

        // Otherwise buffer it; we'll label and update once the word commits.
        pendingTaps.append(PendingTap(
            x: x, y: y, orientation: orientation, liveGuess: guess
        ))
        return guess
    }

    /// Observation-mode entry point. The keyboard surface has already resolved
    /// which key was tapped via standard hit-testing; this records the real tap
    /// point under that resolved key without changing what gets inserted.
    func observeTap(x: Double, y: Double, resolvedKey: String, orientation: DeviceOrientation) {
        if wordBoundaryChars.contains(resolvedKey) {
            observeBoundaryTap(
                x: x,
                y: y,
                resolvedKey: resolvedKey,
                orientation: orientation,
                actualWord: nil
            )
            return
        }

        pendingTaps.append(PendingTap(
            x: x,
            y: y,
            orientation: orientation,
            liveGuess: resolvedKey
        ))
    }

    func resolveTap(
        x: Double,
        y: Double,
        visibleKey: String,
        orientation: DeviceOrientation,
        personalizedTypingEnabled: Bool
    ) -> String {
        #if DEBUG
        NSLog(
            "[Keygram TouchModel] personalizationCheck enabled=%@ learnedTaps=%d threshold=%d completeLayout=%@ visible=%@ orientation=%@",
            personalizedTypingEnabled ? "true" : "false",
            totalLearnedTaps,
            AtlasConfiguration.personalizedTypingActivationThreshold,
            touchModel.hasCompleteLetterLayout ? "true" : "false",
            visibleKey,
            orientation.rawValue
        )
        #endif

        let resolvedKey = decodedKey(
            x: x,
            y: y,
            visibleKey: visibleKey,
            orientation: orientation,
            personalizedTypingEnabled: personalizedTypingEnabled
        )
        observeTap(x: x, y: y, resolvedKey: resolvedKey, orientation: orientation)
        return resolvedKey
    }

    /// Records a word-boundary tap and labels the buffered word with the final
    /// committed text when available.
    func observeBoundaryTap(
        x: Double,
        y: Double,
        resolvedKey: String,
        orientation: DeviceOrientation,
        actualWord: String?
    ) {
        commitPendingWord(actualWord: actualWord)
        touchModel.observe(x: x, y: y, keyID: resolvedKey, orientation: orientation)
        persist()
    }

    /// Called by the autocorrect layer when a word commits.
    /// `actualWord` is the final string the user saw committed (post-autocorrect).
    /// If nil, we trust the live guesses (no correction happened).
    ///
    /// This is the labeling step: we map each tap in the word to a character of
    /// the committed string, then use that as ground truth to update the model.
    func commitPendingWord(actualWord: String?) {
        defer { pendingTaps.removeAll(keepingCapacity: true) }
        guard !pendingTaps.isEmpty else { return }

        // Determine the labels for each pending tap.
        let labels: [String]
        if let actual = actualWord {
            let chars = Array(actual).map { String($0) }
            // Only use the actual word for labels if its length matches the tap count.
            // If lengths differ (autocorrect inserted/deleted a character), we don't
            // know how to align taps to letters reliably — skip the update entirely
            // rather than train on bad labels.
            guard chars.count == pendingTaps.count else { return }
            labels = chars
        } else {
            // No correction happened — the live guesses ARE the ground truth.
            labels = pendingTaps.map { $0.liveGuess }
        }

        // Update the touch model with each labeled tap.
        for (tap, label) in zip(pendingTaps, labels) {
            // Skip whitespace/special characters that aren't in our key layout.
            // The model only cares about letter keys.
            touchModel.observe(
                x: tap.x, y: tap.y, keyID: label, orientation: tap.orientation
            )
        }
        persist()
    }

    /// Called when the user backspaces. The most recently buffered tap is discarded
    /// — we don't want to learn from taps the user immediately corrected.
    func handleBackspace() {
        if !pendingTaps.isEmpty {
            pendingTaps.removeLast()
        }
    }

    /// How many taps the model has learned from. Show this in the settings UI as
    /// a "personalization progress" indicator.
    var totalLearnedTaps: Int {
        touchModel.totalSamples
    }

    /// "Reset my personalization" from settings.
    func resetPersonalization() {
        touchModel.reset()
        pendingTaps.removeAll()
        store?.deleteSavedModel()
    }

    /// Persist the model. Called after each word commit so we don't lose
    /// learned state if the extension is killed (extensions get killed a lot).
    private func persist() {
        store?.save(touchModel)
    }

    private func decodedKey(
        x: Double,
        y: Double,
        visibleKey: String,
        orientation: DeviceOrientation,
        personalizedTypingEnabled: Bool
    ) -> String {
        guard personalizedTypingEnabled,
              totalLearnedTaps >= AtlasConfiguration.personalizedTypingActivationThreshold,
              touchModel.hasCompleteLetterLayout,
              Self.isSingleLetter(visibleKey)
        else {
            return visibleKey
        }

        logDailySummaryIfNeeded()

        let topKeys = touchModel.topKeys(x: x, y: y, orientation: orientation, count: 3)
        guard let top = topKeys.first,
              Self.isSingleLetter(top.keyID),
              top.keyID != visibleKey
        else {
            return visibleKey
        }

        let visibleScore = touchModel.scoreTap(x: x, y: y, orientation: orientation)[visibleKey] ?? -Double.infinity
        let margin = top.logLikelihood - visibleScore
        guard margin.isFinite else {
            disagreeNoopCount += 1
            logTouchModel(String(format: "disagree-noop visible=%@ model=%@ margin=nonfinite", visibleKey, top.keyID))
            return visibleKey
        }

        let canOverride = margin >= DecodingPolicy.likelihoodMargin
            && topKeys.contains { $0.keyID == visibleKey }
            && !touchModel.isInsideVisibleBounds(x: x, y: y, keyID: visibleKey, orientation: orientation)

        if canOverride {
            overrideCount += 1
            logTouchModel(String(format: "override visible=%@ model=%@ margin=%.3f", visibleKey, top.keyID, margin))
            return top.keyID
        }

        disagreeNoopCount += 1
        logTouchModel(String(format: "disagree-noop visible=%@ model=%@ margin=%.3f", visibleKey, top.keyID, margin))
        return visibleKey
    }

    private static func isSingleLetter(_ keyID: String) -> Bool {
        keyID.count == 1 && keyID.rangeOfCharacter(from: .letters) != nil
    }

    private func logDailySummaryIfNeeded() {
        let today = Calendar.current.startOfDay(for: Date())
        guard today > summaryDay else { return }
        logDailySummary(force: true)
        overrideCount = 0
        disagreeNoopCount = 0
        summaryDay = today
    }

    private func logDailySummary(force: Bool = false) {
        #if DEBUG
        guard force || overrideCount > 0 || disagreeNoopCount > 0 else { return }
        NSLog(
            "[Keygram TouchModel] daily-summary totalTaps=%d overrides=%d disagreeNoops=%d",
            totalLearnedTaps,
            overrideCount,
            disagreeNoopCount
        )
        #endif
    }

    private func logTouchModel(_ message: String) {
        #if DEBUG
        NSLog("[Keygram TouchModel] %@", message)
        #endif
    }
}
