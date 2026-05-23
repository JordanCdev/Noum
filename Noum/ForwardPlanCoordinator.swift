#if canImport(SwiftUI)
import Foundation
import SwiftUI

// MARK: - Forward Plan Coordinator
//
// Bridge between the M20 plan-generation pipeline and the live SwiftUI
// surfaces. Lives on the MainActor so it can read every store the
// plan input needs (sessions, baseline, rating, coaching profile, big
// moment, trends, drill history) without per-view threading.
//
// One method, two effects:
//   1. Calls `ForwardPlanService.shared.generate(...)` with a fully
//      assembled input snapshot.
//   2. On the returned plan: persists to `ForwardPlanStore.shared` AND
//      injects a coach-voice rendering into the Ask Noum thread via
//      `AskNoumStore.injectCoachTurn(_:)`.
//
// The "two effects" shape mirrors the M19 `BigMomentStore.setMoment`
// + intake-view-on-dismiss pattern: state and conversational artifact
// land together so the Profile card lights up the same moment the
// chat thread shows the plan.

@available(iOS 17.0, macOS 12.0, *)
@MainActor
enum ForwardPlanCoordinator {

    /// Build an input snapshot from the live stores. Pure-ish — the
    /// only side effect is reading published properties.
    static func buildInput() -> ForwardPlanInput {
        let profile = CoachingProfileStore.shared.profile
        let baseline = BaselineStore.shared.baseline
        let sessions = PracticeSessionStore.shared.sessions
        let rating = RatingStore.shared.rating
        let bigMoment = BigMomentStore.shared.activeMoment
        let bigMomentDays = bigMoment.flatMap { BigMomentStore.shared.daysUntil($0) }
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weeklyReps = sessions.filter { $0.date >= cutoff }.count
        let weeklyDelta = rating.weeklyDelta
        let currentStreak = StreakFreezeManager.shared.currentStreak
        // TrendAnalyzer reads SkillSnapshots, not raw sessions. The home
        // surfaces use the live snapshot store; the plan input mirrors that
        // path so the trend signal feeding the planner is the same one
        // surfacing on the rest of the app.
        let snapshots = SkillTrendStore.shared.snapshots
        let trends = TrendAnalyzer.analyze(snapshots: snapshots)
        let recentDrills = DrillHistoryStore.shared.entries
        return ForwardPlanInput(
            profile: profile,
            baseline: baseline,
            sessions: sessions,
            weeklyDelta: weeklyDelta,
            weeklyReps: weeklyReps,
            currentStreak: currentStreak,
            bigMoment: bigMoment,
            bigMomentDaysUntil: bigMomentDays,
            trends: trends,
            recentDrills: recentDrills
        )
    }

    /// Generate (or regenerate) the active plan and drop the rendered
    /// coach message into the Ask Noum thread. Returns the new plan so
    /// the caller can present feedback (e.g. toast / nav push).
    @discardableResult
    static func generateAndAnnounce() async -> ForwardPlan {
        let input = buildInput()
        let plan = await ForwardPlanService.shared.generate(input: input)
        ForwardPlanStore.shared.replace(plan)
        let voice = input.profile?.speakingStyleGoal
        let message = ForwardPlanRenderer.coachMessage(
            for: plan,
            voice: voice,
            bigMoment: input.bigMoment
        )
        AskNoumStore.shared.injectCoachTurn(message)
        return plan
    }

    /// True when the user has enough qualifying sessions to merit
    /// generating a plan — three sessions is the threshold matching
    /// the M20 design ("after the user's third rated session"). Lower
    /// counts can still generate, but the Profile card surfaces a
    /// "keep practicing" pre-prompt instead of the "ask for your plan"
    /// CTA so the coach doesn't over-claim on thin data.
    static func hasEnoughDataForPlan(sessionCount: Int) -> Bool {
        sessionCount >= 3
    }
}

#endif
