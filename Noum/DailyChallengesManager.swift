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

        if stored?.dayKey == todayKey {
            todays = stored!.kinds
            claimedKinds = stored!.claimedKinds
        } else {
            todays = DailyChallengeGenerator.threeKinds(for: todayKey)
            claimedKinds = []
            save(DailyChallengeSet(dayKey: todayKey, kinds: todays, claimedKinds: []))
        }
        recomputeReady()
    }

    /// Re-evaluate readiness against the latest session. Called after
    /// every session finalize via the PracticeSessionStore subscription.
    func recomputeReady() {
        guard let latest = PracticeSessionStore.shared.sessions.first else {
            readyToClaim = []
            return
        }
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard latest.date >= todayStart else {
            // Today's challenges should only resolve from today's sessions.
            // Pulling from yesterday would be a lie.
            readyToClaim = []
            return
        }

        var ready: Set<DailyChallengeKind> = []
        for kind in todays where !claimedKinds.contains(kind) {
            if kind.isSatisfied(by: latest) {
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

    /// Mark a challenge as claimed by the user. Awards XP through the
    /// reward engine. Safe to call multiple times — subsequent calls
    /// for the same kind are no-ops.
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
        pendingClaim = kind
        CoachHaptic.skillLevelUp()
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
