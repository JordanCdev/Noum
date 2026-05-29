import Foundation

/// Visibility flags for every conditional card on Home.
/// `coachCard` and `utilityStrip` are always true — kept on the struct so
/// the call site has one place to read every gate, no special-casing.
struct HomeCardGate: Equatable {
    var coachCard: Bool
    var utilityStrip: Bool
    var journey: Bool
    var askNoumPromo: Bool
    var dailyChallenge: Bool
    var voiceMetrics: Bool
    var aiWeeklyInsight: Bool

    static let allVisible = HomeCardGate(
        coachCard: true,
        utilityStrip: true,
        journey: true,
        askNoumPromo: true,
        dailyChallenge: true,
        voiceMetrics: true,
        aiWeeklyInsight: true
    )
}

/// Signal-gated Home composition for M15 Phase 4.
///
/// Cards aren't deleted — they unlock as signal accrues. Coach + Utility +
/// Ask Noum form the cold-start floor; Daily Challenge, Voice Metrics, the
/// Journey card and the AI Weekly Insight each have their own threshold.
///
/// The whole gate is reversible by `practice.showAllHomeCards = true` —
/// returning users who want the dense home get it back from Settings.
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
    ///   - showAllOverride: Settings escape hatch. When true, every flag
    ///     returns true — the gate becomes a no-op.
    static func evaluate(
        sessionCount: Int,
        sessionsThisWeekCount: Int,
        hasUnlockedPathNode: Bool,
        hasCoachingProfile: Bool,
        showAllOverride: Bool
    ) -> HomeCardGate {
        if showAllOverride { return .allVisible }
        return HomeCardGate(
            coachCard: true,
            utilityStrip: true,
            journey: hasUnlockedPathNode || hasCoachingProfile,
            askNoumPromo: true,
            dailyChallenge: sessionCount >= 1,
            voiceMetrics: sessionCount >= 1,
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
