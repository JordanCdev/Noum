import Foundation
#if canImport(Security)
import Security
#endif

// MARK: - Journey day-bloom ratchet
//
// Remembers the practiced-day count the journey page showed the user
// last time they looked, per account. The page compares the live count
// against this on appear and plays the day-bloom settle beat (reveal
// band advances, a flower or two blooms, the walker steps forward) only
// when the count has genuinely risen since the user last saw the page.
//
// Invariants (the league-promotion-guard lesson):
//   • First sight seeds to the CURRENT count and reports `.seeded` —
//     a fresh install, or the first open after this feature ships,
//     must never animate progress the user didn't just earn.
//   • Decreases (the rolling 21-day window sliding past old practice
//     days) commit silently and report `.regressed` — no animation,
//     no copy. Never punish-shame.
//   • The new value commits atomically inside `evaluate` — an
//     interrupted bloom is dropped, never replayed. A missed beat is
//     cheaper than a double celebration.
//
// Storage mirrors `ProgressionRatchet`: UserDefaults keyed
// `noum.journey.lastSeenPracticedDays.<accountID>` with a `"guest"`
// fallback, accountID read from the Keychain. The key is enumerated in
// `AuthManager.clearAllUserData(for:)`.

enum JourneyDayBloomRatchet {

    /// Storage key prefix. Joined with the active account ID (or
    /// `"guest"`) the same way every other per-account value is keyed.
    private static let storagePrefix = "noum.journey.lastSeenPracticedDays"

    /// What the page should do after comparing the live count against
    /// the stored one. Only `.advanced` plays anything.
    enum Outcome: Equatable {
        /// First sight for this account — the current count was stored
        /// without animation.
        case seeded
        /// The count rose since the page was last seen. Play the settle
        /// beat from `previousDays` to the current count.
        case advanced(previousDays: Int)
        /// No change.
        case unchanged
        /// The rolling window slid backwards. Stored silently.
        case regressed
    }

    /// Compare `currentDays` against the stored last-seen count and
    /// commit the new value in the same step. Negative input clamps to
    /// zero (defensive — the snapshot never produces one).
    @discardableResult
    static func evaluate(
        currentDays: Int,
        defaults: UserDefaults = .standard
    ) -> Outcome {
        let clamped = max(0, currentDays)
        let key = storageKey(for: currentAccountID())
        guard let stored = defaults.object(forKey: key) as? Int else {
            defaults.set(clamped, forKey: key)
            return .seeded
        }
        if clamped > stored {
            defaults.set(clamped, forKey: key)
            return .advanced(previousDays: stored)
        }
        if clamped < stored {
            defaults.set(clamped, forKey: key)
            return .regressed
        }
        return .unchanged
    }

    // MARK: - Per-account key construction

    /// Per-account storage key. Mirrors the `<feature>.<accountID>`
    /// convention; falls back to `"guest"` when signed out so
    /// pre-sign-in progress isn't lost.
    static func storageKey(for accountID: String?) -> String {
        if let accountID, !accountID.isEmpty {
            return "\(storagePrefix).\(accountID)"
        }
        return "\(storagePrefix).guest"
    }

    /// Active account ID from the Keychain via the same key every other
    /// manager uses; nil falls through to the `"guest"` key.
    private static func currentAccountID() -> String? {
        #if canImport(Security)
        return KeychainHelper.load(key: "NoumAccountID")
        #else
        return nil
        #endif
    }

    #if DEBUG
    /// Test helper: wipe the ratchet for the active account so unit
    /// tests can exercise first-sight seeding without leaking state.
    static func resetForTesting(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: storageKey(for: currentAccountID()))
    }
    #endif
}
