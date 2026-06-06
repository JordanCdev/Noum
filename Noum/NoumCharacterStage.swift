import Foundation
#if canImport(Security)
import Security
#endif

// MARK: - NoumCharacter.Stage
//
// The "lifetime arc" register of the NoumCharacter. Each stage is a small
// upgrade to the character's silhouette — a new ring, a brighter inner
// glow, a non-dotted outer band, a slow rotating gradient. The user
// notices over weeks of use, not minutes; the change reads as "the
// character earned that," not as a level-up celebration.
//
// Composition rules (brand non-negotiables):
//   • All visual upgrades are built from waveform-family SF Symbols +
//     Circle + LinearGradient. No new symbol types, no mascots.
//   • Every animated upgrade respects reduce-motion (the mastery
//     rotating ring + 60s sparkle ribbon are gated at the call site).
//   • Stage is a one-way ratchet — it never regresses, even if XP
//     somehow decreases. "Never punish-shame" is invariant.
//
// `Stage` is intentionally a plain enum derived from a pure function
// of XP. Easy to unit-test, no async, no side-effects. The ratchet
// (`ProgressionRatchet`) is the only piece that touches storage, and
// it lives in a separate enum so the stage math itself stays pure.

import SwiftUI

@available(iOS 17.0, macOS 12.0, *)
extension NoumCharacter {

    /// Stages of the NoumCharacter as the user progresses. Backed by XP
    /// gates that align with the existing level math
    /// (`ProfileManager.levelTitle` reads `xp / 1000`):
    ///
    ///   • `awakening`  — 0–499 XP (~0 levels): single glyph, faint halo.
    ///   • `voice`      — 500–1499 XP (~level 0 mid-to-1): brighter inner glow.
    ///   • `composure`  — 1500–3499 XP (~levels 1–3): dotted outer ring.
    ///   • `command`    — 3500–7999 XP (~levels 3–7): solid outer ring + 3 halo rings.
    ///   • `mastery`    — 8000+ XP (~level 8+): rotating outer gradient + idle sparkle.
    ///
    /// Pure-function derivation lives in `current(xp:)` so unit tests can
    /// pin the gates without going through any singleton.
    enum Stage: String, Codable, CaseIterable, Comparable, Sendable {
        case awakening
        case voice
        case composure
        case command
        case mastery

        /// Stable ordering used by both `Comparable` and the ratchet's
        /// `max` operation. Lower = earlier in the user's arc.
        private var rank: Int {
            switch self {
            case .awakening: return 0
            case .voice:     return 1
            case .composure: return 2
            case .command:   return 3
            case .mastery:   return 4
            }
        }

        static func < (lhs: Stage, rhs: Stage) -> Bool {
            lhs.rank < rhs.rank
        }

        /// XP gate this stage *enters* at. Inclusive lower bound — used
        /// by both `current(xp:)` and unit tests so the contract has a
        /// single source of truth.
        var xpEntryThreshold: Int {
            switch self {
            case .awakening: return 0
            case .voice:     return 500
            case .composure: return 1500
            case .command:   return 3500
            case .mastery:   return 8000
            }
        }

        /// Pure-function derivation. Given a raw XP value, returns the
        /// stage the user is currently in (ignoring the ratchet). The
        /// final render-time stage is `max(currentStage, ratchetedStage)`.
        ///
        /// Walks the stages in descending order and picks the first one
        /// whose entry threshold the XP meets. Negative XP clamps to
        /// `.awakening` (defensive — XP should never be negative).
        static func current(xp: Int) -> Stage {
            let clamped = max(0, xp)
            // Descending so we hit the highest qualifying stage first.
            for stage in Stage.allCases.reversed() {
                if clamped >= stage.xpEntryThreshold {
                    return stage
                }
            }
            return .awakening
        }

        /// Accessibility-friendly label used by the full character's
        /// VoiceOver string when a non-`awakening` stage is active. The
        /// resting `awakening` stage doesn't add a suffix — calling it
        /// out on every read would draw attention to "just arriving."
        var accessibilitySuffix: String? {
            switch self {
            case .awakening: return nil
            case .voice:     return "finding their voice"
            case .composure: return "settled in composure"
            case .command:   return "in command"
            case .mastery:   return "carrying mastery"
            }
        }
    }
}

// MARK: - Progression ratchet
//
// One-way ratchet on the user's highest-ever Stage. Backed by UserDefaults
// keyed `noumCharacter.peakStage.<accountID>` so it scopes per-account
// (matching every other persisted user value — see
// `AuthManager.clearAllUserData(for:)` for the canonical list).
//
// Why a ratchet at all: if a user's XP somehow regressed (account
// migration, devtool reset, etc.), the character must not visibly
// regress. The "Never punish-shame on regression — only celebrate
// upward" invariant applies to every detection in the app; the stage
// is no different.

@available(iOS 17.0, macOS 12.0, *)
enum ProgressionRatchet {

    /// Storage key prefix. Joined with the active account ID (or
    /// `"guest"`) the same way every other per-account value in the
    /// app is keyed.
    private static let storagePrefix = "noumCharacter.peakStage"

    /// Read the highest stage the active account has ever reached.
    /// Returns `.awakening` when nothing has been persisted yet — the
    /// resting state for a brand-new user.
    static func peakStage(defaults: UserDefaults = .standard) -> NoumCharacter.Stage {
        let key = storageKey(for: currentAccountID())
        guard let raw = defaults.string(forKey: key),
              let stage = NoumCharacter.Stage(rawValue: raw) else {
            return .awakening
        }
        return stage
    }

    /// Update the persisted peak stage if `candidate` is strictly
    /// greater than the currently stored peak. Lower-or-equal values
    /// are dropped silently — the ratchet only moves up.
    ///
    /// Returns the resolved peak (max of stored + candidate) so the
    /// caller can render against it without a second read.
    @discardableResult
    static func recordIfHigher(
        _ candidate: NoumCharacter.Stage,
        defaults: UserDefaults = .standard
    ) -> NoumCharacter.Stage {
        let stored = peakStage(defaults: defaults)
        guard candidate > stored else { return stored }
        let key = storageKey(for: currentAccountID())
        defaults.set(candidate.rawValue, forKey: key)
        return candidate
    }

    /// Resolve the render-time stage for a given XP value: the max of
    /// `Stage.current(xp:)` and the persisted ratchet. Bumps the
    /// ratchet on the way out so subsequent reads see the new floor.
    ///
    /// Call from the view layer — this is the canonical "what stage
    /// should the character render as?" entry point.
    static func resolvedStage(
        forXP xp: Int,
        defaults: UserDefaults = .standard
    ) -> NoumCharacter.Stage {
        let derived = NoumCharacter.Stage.current(xp: xp)
        let stored = peakStage(defaults: defaults)
        let resolved = max(derived, stored)
        if resolved > stored {
            // Persist the new floor so we never regress visually.
            recordIfHigher(resolved, defaults: defaults)
        }
        return resolved
    }

    // MARK: - Per-account key construction

    /// Per-account storage key. Mirrors the convention used by every
    /// other persisted user value (`<feature>.<accountID>`); falls
    /// back to `"guest"` when the user is signed out / anonymous so
    /// pre-sign-in progress isn't lost.
    static func storageKey(for accountID: String?) -> String {
        if let accountID, !accountID.isEmpty {
            return "\(storagePrefix).\(accountID)"
        }
        return "\(storagePrefix).guest"
    }

    /// Read the active account ID from the Keychain via the same key
    /// (`"NoumAccountID"`) every other manager uses. Returns nil when
    /// no account is bound; the storage helper falls back to `"guest"`
    /// in that case.
    private static func currentAccountID() -> String? {
        #if canImport(Security)
        return KeychainHelper.load(key: "NoumAccountID")
        #else
        return nil
        #endif
    }

    #if DEBUG
    /// Test helper: wipe the ratchet for the active account. Lets unit
    /// tests use the real ratchet without leaking state across runs.
    /// Behind `DEBUG` so it never ships in release builds.
    static func resetForTesting(defaults: UserDefaults = .standard) {
        let key = storageKey(for: currentAccountID())
        defaults.removeObject(forKey: key)
    }
    #endif
}
