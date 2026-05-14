import Foundation
#if canImport(SwiftUI)
import SwiftUI
import Combine
#endif

// MARK: - Practice Locale (M12)
//
// Selectable practice language for the speaking-coach loop. Affects:
//   • Transcription provider language code (AWS / Deepgram / Google).
//   • Filler-word lexicon used for detection + scoring.
//   • Prompt pool source in `PracticeTopics`.
//
// Coaching copy (summary, profile, settings, AI feedback) stays English
// for v1 — the practice surfaces switch language; UI localisation is a
// follow-up milestone documented in VISION.md.
//
// Default: en-US. Persisted per-account so signing into a different
// account doesn't carry the previous user's language preference.

enum PracticeLocale: String, CaseIterable, Codable, Identifiable, Sendable {
    case enUS = "en-US"
    case esES = "es-ES"
    case frFR = "fr-FR"

    var id: String { rawValue }

    /// IETF BCP-47 code as used by speech providers.
    var code: String { rawValue }

    /// User-facing label in Settings.
    var displayName: String {
        switch self {
        case .enUS: return "English (US)"
        case .esES: return "Spanish (Spain)"
        case .frFR: return "French (France)"
        }
    }

    /// Short two-letter label for compact rows.
    var shortLabel: String {
        switch self {
        case .enUS: return "EN"
        case .esES: return "ES"
        case .frFR: return "FR"
        }
    }

    /// Locale-aware native flag-style emoji is intentionally avoided —
    /// the brand rule is "no emoji decorations". UI uses `shortLabel`
    /// inside an `AppColor` capsule instead.
    var systemSymbol: String { "globe" }

    /// True when the AI coaching surfaces (prompt generation, grammar
    /// polish, insights debrief) are available in this locale. M12/M13
    /// ship the practice loop in es-ES + fr-FR but the AI services are
    /// English-only — calling them on a non-English transcript would
    /// produce confused output that gets shown to the user as if it
    /// were valid coaching. We skip honestly until those surfaces are
    /// localised in a future milestone.
    var aiSupported: Bool {
        switch self {
        case .enUS: return true
        case .esES, .frFR: return false
        }
    }
}

// MARK: - Settings Manager

#if canImport(SwiftUI)

@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class LocaleSettingsManager: ObservableObject {
    static let shared = LocaleSettingsManager()

    /// Currently selected practice locale. Changes persist immediately
    /// per-account; new sessions pick it up at the next `startRecording()`.
    @Published var current: PracticeLocale {
        didSet { persist() }
    }

    private let storageKeyPrefix = "noum.practiceLocale."

    private init() {
        let key = Self.storageKey()
        if let raw = UserDefaults.standard.string(forKey: key),
           let locale = PracticeLocale(rawValue: raw) {
            current = locale
        } else {
            current = .enUS
        }
    }

    func reloadForCurrentAccount() {
        let key = Self.storageKey()
        if let raw = UserDefaults.standard.string(forKey: key),
           let locale = PracticeLocale(rawValue: raw) {
            current = locale
        } else {
            current = .enUS
        }
    }

    private static func storageKey() -> String {
        let id = AuthManager.shared.currentAccountID ?? "guest"
        return "noum.practiceLocale." + id
    }

    private func persist() {
        UserDefaults.standard.set(current.rawValue, forKey: Self.storageKey())
    }
}

#endif
