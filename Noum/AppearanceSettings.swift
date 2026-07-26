#if canImport(SwiftUI)
import SwiftUI

// MARK: - Appearance override (Settings → Appearance)
//
// The V4.6 semantic theme is trait-resolving, so the app follows the iOS
// system appearance by default — which iOS can itself schedule by time of
// day (Display & Brightness → Automatic). This override exists for users
// who want Noum pinned light or dark independent of the system. Stored as
// a plain string so the root can read it with @AppStorage before any
// store spins up.

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    /// nil = follow the system (including its time-of-day schedule).
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var symbolName: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    static let storageKey = "appearance.mode"
}
#endif
