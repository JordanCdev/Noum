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

    static let allVisible = HomeCardGate(
        coachCard: true,
        utilityStrip: false,
        journey: true,
        askNoumShortcut: true,
        dailyChallenge: false,
        voiceMetrics: false,
        aiWeeklyInsight: true
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
/// The whole gate is reversible by `practice.showAllHomeCards = true` —
/// returning users who want the dense home get optional cards back from
/// Settings, excluding surfaces intentionally retired from Home.
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
    ///   - showAllOverride: Settings escape hatch for active optional cards.
    ///     Retired Home surfaces remain off even when this is true.
    static func evaluate(
        sessionCount: Int,
        sessionsThisWeekCount: Int,
        hasUnlockedPathNode: Bool,
        hasCoachingProfile: Bool,
        showAllOverride: Bool
    ) -> HomeCardGate {
        if showAllOverride { return .allVisible }
        let hasCompletedRep = sessionCount >= 1
        return HomeCardGate(
            coachCard: true,
            utilityStrip: false,
            journey: hasCompletedRep && (hasUnlockedPathNode || hasCoachingProfile),
            askNoumShortcut: hasCompletedRep,
            dailyChallenge: false,
            voiceMetrics: false,
            aiWeeklyInsight: sessionsThisWeekCount >= 3
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
