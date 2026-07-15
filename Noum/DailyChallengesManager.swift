#if canImport(SwiftUI)
import Foundation
import SwiftUI
import Combine

// MARK: - Daily Challenges Manager (M8)
//
// Owns the day's three rotating challenges:
//   • Generates them deterministically from today's ISO date so every
//     launch on the same day shows the same trio.
//   • Auto-rolls at local midnight (recompute on scenePhase active +
//     after every session finalize).
//   • Evaluates each unclaimed challenge against the latest finalized
//     PracticeSession so the user can see "ready to claim" state without
//     re-running anything.
//   • Hands out the XP only when the user explicitly taps "Claim" — the
//     tap is the celebration moment.
//
// Intentionally NOT auto-claiming: removing the user-agency moment would
// turn the feature into a passive checklist. The whole point is the
// "I did it → claim → small celebration" pull mechanic.
//
// Per-account storage; falls back to a "guest" namespace pre-auth.

@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class DailyChallengesManager: ObservableObject {
    static let shared = DailyChallengesManager()

    /// Today's three challenges. Always exactly 3 once `ensureForToday()`
    /// has run; empty pre-init.
    @Published private(set) var todays: [DailyChallengeKind] = []

    /// Subset of `todays` that the user has already claimed.
    @Published private(set) var claimedKinds: Set<DailyChallengeKind> = []

    /// Subset of unclaimed challenges that the latest session has now
    /// satisfied — the UI surfaces these as "ready to claim" rows.
    @Published private(set) var readyToClaim: Set<DailyChallengeKind> = []

    /// Set when a fresh challenge is satisfied so the home tile can play
    /// a brief notification animation. UI clears via `consumeReadySignal()`.
    @Published private(set) var pendingReadySignal: DailyChallengeKind?

    /// Set when a claim XP award lands. Sheet/overlay reads this to
    /// drive the small claim celebration.
    @Published var pendingClaim: DailyChallengeKind?

    private let storageKeyPrefix = "noum.dailyChallenges."
    private var sessionsSubscription: AnyCancellable?

    private init() {
        ensureForToday()
        observeSessionStore()
    }

    // MARK: - Public API

    /// Recompute current-day challenges. Safe to call on every scenePhase
    /// active. If the stored dayKey is stale, regenerates the trio.
    func ensureForToday() {
        let todayKey = Self.todayKey()
        let stored = load()

        let rolledOver: Bool
        if stored?.dayKey == todayKey {
            todays = stored!.kinds
            claimedKinds = stored!.claimedKinds
            rolledOver = false
        } else {
            // Per (date, accountID) seed so two users on the same day
            // see different trios (small win against guess-the-pool
            // gaming) and a single user sees the same trio across app
            // restarts on the same day (the persistence layer already
            // guarantees this within a session; the seed makes it
            // honest at the generator layer too).
            let accountID = AuthManager.shared.currentAccountID
            todays = DailyChallengeGenerator.threeKinds(for: todayKey, accountID: accountID)
            claimedKinds = []
            save(DailyChallengeSet(dayKey: todayKey, kinds: todays, claimedKinds: []))
            rolledOver = true
        }
        recomputeReady()

        // After a day rollover the expiry warning needs to re-arm against
        // the new day's three (the count returns to 3 and the body must
        // reflect that). Safe to call unconditionally — the scheduler
        // bails on its own when nothing's actionable.
        if rolledOver {
            NotificationManager.shared.refreshScheduledNotifications()
        }
    }

    /// Re-evaluate readiness against the latest session. Called after
    /// every session finalize via the PracticeSessionStore subscription.
    func recomputeReady() {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let nextDayStart = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? Date()
        let sessionsToday = PracticeSessionStore.shared.progressEligibleSessions
            .filter { $0.date >= todayStart && $0.date < nextDayStart }

        guard let latest = sessionsToday.first else {
            readyToClaim = []
            return
        }

        var ready: Set<DailyChallengeKind> = []
        for kind in todays where !claimedKinds.contains(kind) {
            if Self.isSatisfied(kind: kind, latest: latest, sessionsToday: sessionsToday) {
                ready.insert(kind)
            }
        }

        let newlySatisfied = ready.subtracting(readyToClaim)
        readyToClaim = ready

        // Surface the FIRST newly-satisfied challenge as a one-shot signal
        // so the home tile can flash + haptic. UI consumes via
        // `consumeReadySignal()`.
        if let signal = newlySatisfied.first {
            pendingReadySignal = signal
        }
    }

    /// Day-aware predicate evaluator. Most kinds answer from a single
    /// `PracticeSession`; a few (notably `.secondRepToday`) need a wider
    /// view across "everything finalized today" — those cases are handled
    /// here so the `DailyChallengeKind.isSatisfied(by:)` switch can stay
    /// pure-per-session. Anything not specifically overridden falls
    /// through to the per-session evaluator.
    static func isSatisfied(
        kind: DailyChallengeKind,
        latest: PracticeSession,
        sessionsToday: [PracticeSession]
    ) -> Bool {
        switch kind {
        case .secondRepToday:
            // Honest evaluation: rep #2+ for today. Two finalized
            // sessions inside the same local day is the bar — drill
            // completions intentionally don't count here because the
            // claim language says "rep" and drills aren't called reps
            // anywhere else in the product.
            return sessionsToday.count >= 2
        default:
            return kind.isSatisfied(by: latest)
        }
    }

    /// Mark a challenge as claimed by the user. Awards XP through the
    /// reward engine, and nudges the league rating so daily-challenge
    /// engagement keeps the user moving inside their tier even on days
    /// they don't run a full rated session. Safe to call multiple times —
    /// subsequent calls for the same kind are no-ops.
    @discardableResult
    func claim(_ kind: DailyChallengeKind) -> Bool {
        guard todays.contains(kind), !claimedKinds.contains(kind), readyToClaim.contains(kind) else {
            return false
        }
        claimedKinds.insert(kind)
        readyToClaim.remove(kind)
        save(currentSet())
        // Award XP via the profile manager — same path session XP uses.
        ProfileManager.shared.addXP(kind.xpReward)
        // Feed the league. Per-claim rating bump is small by design (see
        // `LeagueManager.recordDailyChallengeCompletion`) so completing
        // all three daily challenges adds up to a meaningful but not
        // gameable nudge — strictly less than a real session at a
        // moderate score.
        LeagueManager.shared.recordDailyChallengeCompletion(kind)
        pendingClaim = kind
        CoachHaptic.skillLevelUp()

        // Re-arm the daily-rhythm notifications so the expiry warning's
        // body reflects the new unclaimed count — or gets removed
        // entirely once nothing's open. Honest count, no stale body.
        NotificationManager.shared.refreshScheduledNotifications()
        return true
    }

    /// View calls this once after rendering the claim celebration.
    func consumePendingClaim() {
        pendingClaim = nil
    }

    /// View calls this once after rendering the "ready to claim" flash.
    func consumeReadySignal() {
        pendingReadySignal = nil
    }

    /// Account switch — wipe today's claim state so the new account starts
    /// fresh. Re-runs ensureForToday() to regenerate from the (per-account)
    /// stored set.
    func reloadForCurrentAccount() {
        ensureForToday()
    }

    // MARK: - Derived

    var allClaimedToday: Bool {
        !todays.isEmpty && claimedKinds.count == todays.count
    }

    var unclaimedCount: Int {
        max(0, todays.count - claimedKinds.count)
    }

    /// Soft-expiry: 9pm local. UI uses this to show a softer "fading"
    /// treatment (no shame), still claimable until midnight.
    var isPastSoftExpiry: Bool {
        currentSet().isPastSoftExpiry
    }

    // MARK: - Storage

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }

    private var storageKey: String {
        let id = AuthManager.shared.currentAccountID ?? "guest"
        return storageKeyPrefix + id
    }

    private func load() -> DailyChallengeSet? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return nil }
        return try? JSONDecoder().decode(DailyChallengeSet.self, from: data)
    }

    private func save(_ set: DailyChallengeSet) {
        guard let data = try? JSONEncoder().encode(set) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func currentSet() -> DailyChallengeSet {
        DailyChallengeSet(dayKey: Self.todayKey(), kinds: todays, claimedKinds: claimedKinds)
    }

    // MARK: - Session subscription

    private func observeSessionStore() {
        sessionsSubscription = PracticeSessionStore.shared.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.ensureForToday()  // also rolls over date if needed
                self?.recomputeReady()
            }
    }
}

#endif
