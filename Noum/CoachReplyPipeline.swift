#if canImport(SwiftUI)
import SwiftUI

// MARK: - Coach reply pipeline
//
// The single shared path that turns a pending coach turn into a reply: assemble
// the full coach CONTEXT from the shared stores, call the model (with a grounded
// deterministic fallback), and hydrate the pending row on `AskNoumStore`.
//
// Extracted from `AskNoumView.runReply` so the chat (`AskNoumView`) and the live
// call (`LiveCoachCallView`) use ONE brain — same context, same fallback, same
// model call. The caller owns the spoken-reply decision (it differs by surface),
// so this returns the `ChatOutcome` rather than speaking itself.

@available(iOS 17.0, macOS 12.0, *)
enum CoachReplyPipeline {

    /// Assemble context from the shared stores, call the model, and hydrate the
    /// pending coach row identified by `coachID`. Returns the outcome so the
    /// caller can decide whether to speak it. `@MainActor`: the store reads run
    /// on main before the single `await`, exactly as the original prologue did.
    @MainActor
    @discardableResult
    static func generate(
        coachID: UUID,
        pendingGoalIntent: CoachContextBuilder.GoalIntent? = nil
    ) async -> ChatOutcome {
        let profileStore = CoachingProfileStore.shared
        let systemPrompt = CoachContextBuilder.systemPrompt(for: profileStore.profile)

        // Trend analysis at call time — cheap pure work over the snapshot store.
        let snapshots = SkillTrendStore.shared.snapshots
        let trends = TrendAnalyzer.analyze(snapshots: snapshots)

        let sessionStore = PracticeSessionStore.shared
        let coachMemoryStore = CoachMemoryStore.shared
        let history = AskNoumStore.shared.replayForModel
        let latestUserIndex = history.lastIndex { $0.role == .user }
        let latestUserTurn = latestUserIndex.map { history[$0].text }
        let previousCoachReply = latestUserIndex.flatMap { index in
            history[..<index].last { $0.role == .coach }?.text
        }
        // EQ — recent user turns for sustained emotional pattern detection.
        // Newest-first, capped at 6 so the arc detector can scan a meaningful
        // window without unbounded history reads.
        let recentUserTurns = history
            .filter { $0.role == .user }
            .suffix(6)
            .map { $0.text }

        // BRAIN — retrieve the coaching expertise most worth grounding this
        // turn in. Boosted by the user's active lever + chosen voice; gated so
        // a cold-start user only gets technique when they explicitly ask for it
        // (otherwise the coach reads the person, not a card). Pure + fast +
        // deterministic — same single brain, just better-informed.
        let activeLever = coachMemoryStore.currentMemory?.currentLever
        let expertise = KnowledgeRetriever.retrieve(
            query: latestUserTurn ?? "",
            lever: activeLever,
            voice: profileStore.profile?.speakingStyleGoal,
            hasDiagnosis: activeLever != nil
        )

        let context = CoachContextBuilder.userContext(
            profile: profileStore.profile,
            baseline: BaselineStore.shared.baseline,
            rating: RatingStore.shared.rating,
            sessions: sessionStore.sessions,
            currentStreak: StreakFreezeManager.shared.currentStreak,
            pathStatus: PathProgressManager.shared.currentNode,
            pathGatingPhrase: PathProgressManager.shared.currentNodeGatingPhrase,
            recentProofs: ProofMomentStore.shared.recent(limit: 3),
            bigMoment: BigMomentStore.shared.activeMoment,
            recentMomentOutcomes: BigMomentStore.shared.recentOutcomeReports(limit: 2),
            forwardPlan: ForwardPlanStore.shared.activePlan,
            latestRepNote: PostRepCoachNoteStore.shared.latestNote(),
            coachMemory: coachMemoryStore.currentMemory,
            pendingRecommendation: RecommendationLearningStore.shared.pendingExposure,
            recommendationOutcomes: RecommendationLearningStore.shared.outcomes,
            trends: trends,
            latestSnapshot: snapshots.last,
            snapshotsForTrends: snapshots,
            pendingGoalIntent: pendingGoalIntent,
            recentCheckIns: CoachCheckInStore.shared.recentForContext(limit: 2),
            latestUserTurn: latestUserTurn,
            previousCoachReply: previousCoachReply,
            recentUserTurns: recentUserTurns,
            coachingExpertise: expertise
        )

        // Deterministic-fallback context — assembled in the same main-actor
        // prologue so an offline / no-provider / locale-blocked turn still gets a
        // grounded, in-voice reply rather than an error notice.
        let voice = profileStore.profile?.chosenStyleGoal
        let recentTimed = sessionStore.sessions.last(where: { $0.mode == .timed })
        let recentTimedWPM: Int = recentTimed.map {
            PracticeEvaluator.paceSnapshot(forTranscript: $0.transcript, duration: $0.duration).wordsPerMinute
        } ?? 0
        let fallbackCaseFile = coachMemoryStore.currentMemory?.caseFile
        let fallbackContext = ChatFallbackContext(
            voice: voice,
            recentTimedTranscript: recentTimed?.transcript,
            recentTimedPrompt: recentTimed?.prompt,
            recentWordsPerMinute: recentTimedWPM,
            recentFillerCount: recentTimed?.fillerWordCount ?? 0,
            hypothesis: fallbackCaseFile?.hypothesis,
            observableTarget: fallbackCaseFile?.observableTarget,
            successMeasure: fallbackCaseFile?.successMeasure,
            nextQuestion: fallbackCaseFile?.nextQuestion
        )

        let outcome = await AICoachChatService.shared.reply(
            history: history,
            systemPrompt: systemPrompt,
            userContext: context,
            fallback: fallbackContext
        )
        AskNoumStore.shared.completeCoachTurn(id: coachID, outcome: outcome)
        return outcome
    }
}

#endif
