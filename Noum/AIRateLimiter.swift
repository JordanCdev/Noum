import Foundation
import Combine

// MARK: - AIRateLimiter
//
// Per-account, per-day budget for outbound AI calls on the surfaces
// that fire on every rep (and now on every voice change too). The
// post-rep Coach Note service was the immediate motivator — a user
// finishing 10 reps in a day plus switching between voices in
// onboarding can fire 15+ provider calls in minutes. Each call is
// cheap individually; the integral is not.
//
// Design rules:
//   • The limiter SOFT-degrades — when the cap is hit (or the
//     debounce floor is active) the caller returns its deterministic
//     fallback, which is the same content the surface would have
//     rendered if no provider were configured at all. No surface ever
//     fails because of a rate decision; the worst case is "rule-based
//     coach voice today instead of AI-polished one."
//   • Atomic check-and-record: `consumeIfAllowed(kind:)` both checks
//     the cap and records the consumption in one call. Callers don't
//     need a separate `record()` step (which would create a race in
//     the burst path).
//   • Per-account scoped + per-day bucketed. Day boundary is the
//     local calendar's `dateComponents([.year, .month, .day])` — same
//     rollover semantics as `AISettingsManager.resetIfNeeded` so a
//     user crossing midnight sees both counters reset together.
//   • Test seam: `defaults`, `accountIDProvider`, `now`, and the
//     premium check are injectable so the rate logic can run hermetic
//     against a custom `UserDefaults` suite + frozen clock.
//   • Read-side observability — `ObservableObject` + `@Published
//     changeToken` so SwiftUI surfaces (Settings AI-usage card,
//     `CoachReadCard` daily-budget hint) refresh mid-view as the
//     budget is consumed elsewhere. The token bumps on writes that
//     change what `remainingToday(kind:)` would return: a successful
//     `consumeIfAllowed` and `deleteAllData(for:)`. `endSession`
//     does not bump — it only clears the in-memory debounce window,
//     which views don't observe.
//
// Vision-aligned (docs/VISION.md anti-goals): we don't introduce a
// hard cap that visibly blocks the user — that would conflict with
// the "no hearts-and-lives gating" anti-goal. The limiter only
// throttles a hidden polish layer; the user always gets a coach
// note, just sometimes the deterministic one instead of the AI one.

@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class AIRateLimiter: ObservableObject {

    static let shared = AIRateLimiter()

    /// Bumps whenever a write changes what `remainingToday(kind:)`
    /// would return for any kind — i.e. on a successful
    /// `consumeIfAllowed` and on `deleteAllData(for:)`. SwiftUI
    /// surfaces that hold an `@StateObject = AIRateLimiter.shared`
    /// re-evaluate their body when this changes, so the Settings
    /// AI-usage card and the `CoachReadCard` daily-budget hint
    /// refresh mid-view as the budget is consumed elsewhere (e.g.
    /// the user finishes a rep in another tab while Settings is
    /// open).
    ///
    /// `UInt64` + wrapping addition (`&+=`) means the token never
    /// throws on overflow — a user practising every second for
    /// 580 billion years would still bump the counter cleanly.
    @Published private(set) var changeToken: UInt64 = 0

    // MARK: - Surfaces
    //
    // Adding a new case is the opt-in step for any AI surface that
    // wants budget protection. Keep this list small — only surfaces
    // that fire on per-rep or per-interaction frequency belong here.
    // One-shot or user-initiated surfaces (Forward Plan, Coach Letter,
    // Ask Noum chat) don't need it.

    enum Kind: String, CaseIterable {
        case postRepCoachNote
    }

    // MARK: - Caps
    //
    // Generous on premium so heavy users never feel a difference;
    // honest on free so a runaway loop can't burn the project budget.
    // The free cap was chosen against "10 reps/day max + a handful of
    // voice-change regens during onboarding" — the heavy-user envelope.
    static let freeDailyCap: Int = 12
    static let premiumDailyCap: Int = 40

    /// Minimum seconds between consecutive calls of the same kind.
    /// Catches the onboarding burst (user switches voice A→B→C→D in
    /// a few seconds; the deterministic note is rewritten each time,
    /// but only the first AI regen actually fires).
    static let debounceSeconds: TimeInterval = 1.5

    // MARK: - Private state

    private static let storagePrefix = "aiRateLimiter."

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?
    private let now: () -> Date
    private let premiumProvider: () -> Bool

    /// In-memory only — debounce is best-effort and resets on cold
    /// launch (which is the right behaviour: a fresh launch is a
    /// fresh user intention, not a continuation of a burst).
    private var lastCallTimestamp: [Kind: Date] = [:]

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil,
        now: @escaping () -> Date = Date.init,
        premiumProvider: (() -> Bool)? = nil
    ) {
        self.defaults = defaults
        if let provider = accountIDProvider {
            self.accountIDProvider = provider
        } else {
            self.accountIDProvider = { KeychainHelper.load(key: "NoumAccountID") }
        }
        self.now = now
        if let provider = premiumProvider {
            self.premiumProvider = provider
        } else {
            self.premiumProvider = { PremiumManager.shared.isPremium }
        }
    }

    // MARK: - Public API

    /// Atomically check the cap + debounce floor for `kind`, and if
    /// both allow, record the consumption and return `true`. Returns
    /// `false` when the daily cap is reached or the debounce window
    /// is still active — the caller is expected to soft-degrade
    /// (return its deterministic fallback).
    func consumeIfAllowed(kind: Kind) -> Bool {
        let now = now()

        // Debounce floor first — cheaper than a defaults read.
        if let last = lastCallTimestamp[kind],
           now.timeIntervalSince(last) < Self.debounceSeconds {
            return false
        }

        // Day cap second.
        let dayKey = Self.dayKey(for: now)
        let countKey = storageCountKey(kind: kind, dayKey: dayKey)
        let current = defaults.integer(forKey: countKey)
        let cap = currentCap()
        guard current < cap else { return false }

        // Record. Persist immediately so a process kill mid-burst
        // doesn't reset the count.
        defaults.set(current + 1, forKey: countKey)
        lastCallTimestamp[kind] = now
        // Bump the publication token AFTER the persisted write lands
        // so any observer's body recomputation reads the post-consume
        // remainingToday number, never the pre-consume one.
        changeToken &+= 1
        return true
    }

    /// Remaining calls for `kind` in the current day bucket. Used by
    /// future settings surfaces that want to surface the user's
    /// remaining budget. Always ≥ 0.
    func remainingToday(kind: Kind) -> Int {
        let dayKey = Self.dayKey(for: now())
        let used = defaults.integer(forKey: storageCountKey(kind: kind, dayKey: dayKey))
        return max(0, currentCap() - used)
    }

    /// Current daily cap based on subscription tier. Read at call
    /// time so a mid-day upgrade unlocks headroom immediately.
    func currentCap() -> Int {
        premiumProvider() ? Self.premiumDailyCap : Self.freeDailyCap
    }

    // MARK: - Lifecycle hooks (mirrors PostRepCoachNoteStore pattern)

    func endSession() {
        // Only the in-memory debounce window — views don't read this,
        // so no `changeToken` bump. Bumping here would spuriously
        // re-render every observing surface every time the user
        // signs out, with no read-side change to show.
        lastCallTimestamp = [:]
    }

    func deleteAllData(for accountID: String) {
        // Strip every (kind × day-key) entry that belongs to this
        // account. We don't know which day-keys exist without
        // scanning, so iterate the recent rolling window — anything
        // older than 30 days is irrelevant anyway and will be
        // overwritten by the next day-keyed write.
        let calendar = Calendar.current
        let today = now()
        for offset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let dayKey = Self.dayKey(for: day)
            for kind in Kind.allCases {
                let key = storageCountKeyExplicit(accountID: accountID, kind: kind, dayKey: dayKey)
                defaults.removeObject(forKey: key)
            }
        }
        if accountIDProvider() == accountID {
            lastCallTimestamp = [:]
            // The active-account counters just reset to 0 across
            // every (kind × day) — observing surfaces should re-read
            // and surface the wider remaining budget. Other-account
            // deletes don't affect what `remainingToday(kind:)` would
            // return for the current account, so the bump is gated
            // behind the active-account check.
            changeToken &+= 1
        }
    }

    // MARK: - Private helpers

    private func storageCountKey(kind: Kind, dayKey: String) -> String {
        let accountID = accountIDProvider() ?? "guest"
        return storageCountKeyExplicit(accountID: accountID, kind: kind, dayKey: dayKey)
    }

    private func storageCountKeyExplicit(accountID: String, kind: Kind, dayKey: String) -> String {
        "\(Self.storagePrefix)\(accountID).\(kind.rawValue).\(dayKey)"
    }

    /// `yyyy-MM-dd` in the user's local calendar. Matches the
    /// rollover semantics of `AISettingsManager.resetIfNeeded` so a
    /// midnight crossing resets both counters together.
    static func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
