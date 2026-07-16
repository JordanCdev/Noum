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
//   1. Calls `ForwardPlanService.shared.generate(...)` with an inseparable
//      input + account authorization snapshot and a live lease preflight.
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
        let sessions = PracticeSessionStore.shared.progressEligibleSessions
        let rating = RatingStore.shared.rating
        let bigMoment = BigMomentStore.shared.activeMoment
        let bigMomentDays = bigMoment.flatMap { BigMomentStore.daysUntil($0) }
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
            recentDrills: recentDrills,
            recommendationOutcomes: RecommendationLearningStore.shared.outcomes,
            transferOutcomes: BigMomentStore.shared.outcomeReports
        )
    }

    /// Generate (or regenerate) the active plan and drop the rendered coach
    /// message into the Ask Noum thread. Nil means the request lost its account,
    /// lifecycle, source, latest-request, or cancellation lease while suspended;
    /// stale work is deliberately invisible and non-persistent.
    @discardableResult
    static func generateAndAnnounce() async -> ForwardPlan? {
        guard !Task.isCancelled else { return nil }
        let input = buildInput()
        guard let request = ForwardPlanStore.shared.generationRequest(
            for: input
        ) else {
            return nil
        }
        guard let plan = await ForwardPlanService.shared.generate(
            request: request,
            startTransportIfCurrent: { urlRequest in
                guard ForwardPlanStore.shared.tokenIsCurrent(
                    request.saveToken,
                    currentInput: buildInput()
                ) else {
                    return nil
                }
                return ForwardPlanTransportHandle.start(urlRequest)
            },
            isCurrent: {
                ForwardPlanStore.shared.tokenIsCurrent(
                    request.saveToken,
                    currentInput: buildInput()
                )
            }
        ) else {
            return nil
        }
        guard !Task.isCancelled else { return nil }
        let currentInput = buildInput()
        guard commit(
            plan,
            request: request,
            currentInput: currentInput,
            planStore: .shared,
            askStore: .shared
        ) else {
            return nil
        }
        return plan
    }

    /// One synchronous MainActor commit boundary for the two user-visible effects.
    /// The plan store owns the authoritative compare-and-save; its announcement
    /// closure uses Ask Noum's independently checked loaded-account boundary.
    /// No actor hop can interleave another account event during validation and
    /// the two in-process writes; the separate durable writes are not crash-atomic.
    static func commit(
        _ plan: ForwardPlan,
        request: ForwardPlanGenerationRequest,
        currentInput: ForwardPlanInput,
        planStore: ForwardPlanStore,
        askStore: AskNoumStore
    ) -> Bool {
        let message = ForwardPlanRenderer.coachMessage(
            for: plan,
            voice: request.input.profile?.chosenStyleGoal,
            bigMoment: request.input.bigMoment
        )
        return planStore.commit(
            plan,
            currentInput: currentInput,
            expected: request.saveToken
        ) {
            askStore.injectCoachTurn(
                message,
                expectedAccountScope: request.saveToken.accountScope
            ) != nil
        }
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
