import Foundation

/// Canonical global gate for haptic feedback across the app.
/// CoachHaptic and `.sensoryFeedback` rows check `isEnabled` before firing.
@MainActor
final class HapticsSettings: ObservableObject {
    static let shared = HapticsSettings()

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: storageKey) }
    }

    private let storageKey = "noum.haptics.enabled"

    private init() {
        if UserDefaults.standard.object(forKey: storageKey) == nil {
            UserDefaults.standard.set(true, forKey: storageKey)
        }
        isEnabled = UserDefaults.standard.bool(forKey: storageKey)
    }

    /// Synchronous, non-isolated read used by `CoachHaptic` from any context.
    /// Reads `UserDefaults` directly so non-MainActor callers don't have to hop.
    nonisolated static var isEnabledSync: Bool {
        // Default true: if the key has never been set we treat it as on.
        if UserDefaults.standard.object(forKey: "noum.haptics.enabled") == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: "noum.haptics.enabled")
    }
}
