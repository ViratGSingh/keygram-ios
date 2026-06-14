import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// Snapshot of how far the user has progressed through enabling the Keygram keyboard.
///
/// The containing app can read two independent signals:
/// 1. Whether the keyboard has been added, by inspecting the system `AppleKeyboards` list.
/// 2. Whether Full Access is granted, by reading a flag the extension writes into the
///    shared App Group. A keyboard extension can only reach the shared container when
///    Full Access is on, so the presence of a `true` flag is itself proof of access.
struct KeyboardSetupStatus: Equatable {
    var isKeyboardAdded: Bool
    var hasFullAccess: Bool

    /// All onboarding requirements satisfied.
    var isComplete: Bool {
        isKeyboardAdded && hasFullAccess
    }

    /// The step the user currently needs to act on.
    var currentStep: OnboardingStep {
        if !isKeyboardAdded { return .addKeyboard }
        if !hasFullAccess { return .allowFullAccess }
        return .activate
    }

    static func current() -> KeyboardSetupStatus {
        KeyboardSetupStatus(
            isKeyboardAdded: detectKeyboardAdded(),
            hasFullAccess: detectFullAccess()
        )
    }

    private static func detectKeyboardAdded() -> Bool {
        guard let activeKeyboards = UserDefaults.standard.array(forKey: "AppleKeyboards") as? [String] else {
            return false
        }
        return activeKeyboards.contains { identifier in
            identifier == AtlasConfiguration.keyboardExtensionBundleIdentifier
                || identifier.hasPrefix(AtlasConfiguration.keyboardExtensionBundleIdentifier)
        }
    }

    private static func detectFullAccess() -> Bool {
        guard let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) else {
            return false
        }
        return defaults.bool(forKey: AtlasConfiguration.keyboardFullAccessGrantedKey)
    }

    /// Persisted marker so a user who finished setup is never sent back to onboarding
    /// even if a live signal momentarily reads stale.
    static var hasCompletedOnboarding: Bool {
        get {
            guard let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) else {
                return false
            }
            return defaults.bool(forKey: AtlasConfiguration.onboardingCompletedKey)
        }
        set {
            guard let defaults = UserDefaults(suiteName: AtlasConfiguration.appGroupIdentifier) else { return }
            defaults.set(newValue, forKey: AtlasConfiguration.onboardingCompletedKey)
        }
    }
}

enum OnboardingStep: Int, CaseIterable {
    case addKeyboard
    case allowFullAccess
    case activate

    var index: Int { rawValue }
    static var totalCount: Int { allCases.count }
}
