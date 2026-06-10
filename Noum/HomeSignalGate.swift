import Foundation

/// Visibility flags for every conditional card on Home.
/// `coachCard` is always true — kept on the struct so the call site has
/// one place to read every gate, no special-casing.
struct HomeCardGate: Equatable {
    var coachCard: Bool
    var utilityStrip: Bool
    var journey: Bool
    var askNoumShortcut: Bool
    var dailyChallenge: Bool
    var voiceMetrics: Bool
    var aiWeeklyInsight: Bool
    /// Quiet streak status line under the coach hero. Owner decision
    /// (roadmap §12.1): the streak is a gentle, no-countdown marker —
    /// never a pressure anchor. Defaults false so older call sites that
    /// don't pass `streakDays` fail quiet (hidden), never fabricated.
    var streakStatus: Bool = false

    static let allVisible = HomeCardGate(
        coachCard: true,
        utilityStrip: false,
        journey: true,
        askNoumShortcut: true,
        dailyChallenge: false,
        voiceMetrics: false,
        aiWeeklyInsight: true,
        streakStatus: true
    )
}

/// Signal-gated Home composition for M15 Phase 4.
///
/// Cards aren't deleted — noisy dashboard cards stay behind the explicit
/// Settings override. The Coach Card is the cold-start floor; the in-card
/// Ask Noum shortcut, Journey and the AI Weekly Insight unlock as signal
/// accrues. The former utility, daily challenge and metrics cards are
/// retired from Home; their underlying tools stay owned by their existing
/// managers/routes.
///
/// The whole gate is reversible for developer inspection via
/// `practice.showAllHomeCards = true`, excluding surfaces intentionally
/// retired from Home. Normal user accounts always follow the signal gate.
enum HomeSignalGate {
    /// Pure evaluation. Take primitives — no store handles — so this stays
    /// trivially testable. Call sites pass current store state in.
    ///
    /// - Parameters:
    ///   - sessionCount: total finished reps for the current account.
    ///   - sessionsThisWeekCount: finished reps inside the current ISO week.
    ///   - hasUnlockedPathNode: true once PathProgressManager has at least
    ///     one persisted unlock.
    ///   - hasCoachingProfile: true once the user has set a voice goal.
    ///   - showAllOverride: Developer Settings escape hatch for active
    ///     optional cards. Retired Home surfaces remain off even when true.
    ///   - overrideEligible: True only for developer accounts. A stale
    ///     stored override from a normal account must not bypass the gate.
    ///   - streakDays: freeze-aware displayed streak from
    ///     `StreakFreezeManager.currentStreak` (the single displayed-streak
    ///     owner). The quiet status line needs >= 2 days — a single rep is
    ///     not a "streak", and rendering "1 day streak" on rep 1 would be
    ///     low-confidence progress furniture. Defaults 0 (hidden) so older
    ///     call sites stay honest by construction.
    static func evaluate(
        sessionCount: Int,
        sessionsThisWeekCount: Int,
        hasUnlockedPathNode: Bool,
        hasCoachingProfile: Bool,
        showAllOverride: Bool,
        overrideEligible: Bool,
        streakDays: Int = 0
    ) -> HomeCardGate {
        if showAllOverride && overrideEligible { return .allVisible }
        let hasCompletedRep = sessionCount >= 1
        return HomeCardGate(
            coachCard: true,
            utilityStrip: false,
            journey: hasCompletedRep && (hasUnlockedPathNode || hasCoachingProfile),
            askNoumShortcut: hasCompletedRep,
            dailyChallenge: false,
            voiceMetrics: false,
            aiWeeklyInsight: sessionsThisWeekCount >= 3,
            streakStatus: hasCompletedRep && streakDays >= 2
        )
    }

    /// Count of sessions whose `date` falls inside the current ISO-8601
    /// week. Mirrors the weekly bucketing the rest of the app uses
    /// (LeagueManager, weekly digest) so "3 sessions in current week"
    /// matches what the user sees elsewhere.
    static func sessionsInCurrentISOWeek(
        sessionDates: [Date],
        now: Date = Date()
    ) -> Int {
        let iso = Calendar(identifier: .iso8601)
        guard let interval = iso.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return sessionDates.reduce(0) { count, date in
            interval.contains(date) ? count + 1 : count
        }
    }
}
