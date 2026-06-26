#if canImport(SwiftUI)
import SwiftUI
import os

// MARK: - Coach reply pipeline
//
// The single shared path that turns a pending coach turn into a reply: assemble
// the full coach context from the shared stores, call the model, and hydrate
// the pending row on `AskNoumStore`.
//
// Extracted from `AskNoumView.runReply` so the chat (`AskNoumView`) and the live
// call (`LiveCoachCallView`) use one brain — same context, same grounding,
// same model call. The caller owns the spoken-reply decision (it differs by
// surface), so this returns the `ChatOutcome` rather than speaking itself.

@available(iOS 17.0, macOS 12.0, *)
enum CoachReplyPipeline {

    private static let log = Logger(subsystem: "com.jordancoaten.noum", category: "CoachReplyPipeline")

    nonisolated static func brainDiagnosticReason(
        cards: [CoachKnowledgeCard],
        latestUserTurn: String?,
        hasDiagnosis: Bool
    ) -> String {
        if !cards.isEmpty {
            let ids = cards.prefix(3).map(\.id).joined(separator: ", ")
            let remaining = cards.count > 3 ? " +\(cards.count - 3)" : ""
            let noun = cards.count == 1 ? "card" : "cards"
            return "Retrieved \(cards.count) \(noun): \(ids)\(remaining)"
        }

        let turn = latestUserTurn?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if turn.isEmpty {
            return "No cards: empty user turn"
        }
        if !hasDiagnosis && !KnowledgeRetriever.isTechniqueSeekingTurn(turn) {
            return "No cards: cold non-technique turn"
        }
        return "No cards matched turn"
    }

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
        let systemPrompt = CoachContextBuilder.systemPrompt(
            for: profileStore.profile,
            structuredReplyShapeEnabled: CoachContextBuilder.structuredAskNoumReplyShapeEnabled(),
            judgmentLayerRuleEnabled: CoachContextBuilder.judgmentLayerRuleEnabled()
        )

        // Trend analysis at call time — cheap pure work over the snapshot store.
        let snapshots = SkillTrendStore.shared.snapshots
        let trends = TrendAnalyzer.analyze(snapshots: snapshots)

        let sessionStore = PracticeSessionStore.shared
        let coachMemoryStore = CoachMemoryStore.shared
        let weeklyCheckInDue = !sessionStore.sessions.isEmpty && CoachCheckInStore.shared.isCheckInDue()
        let recentProofs = ProofMomentStore.shared.recent(limit: 3)
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

        // BRAIN — retrieve the coaching expertise most worth grounding this turn
        // in. Boosted by the user's active lever + chosen voice; gated so a
        // cold-start user only gets technique when they explicitly ask for it.
        // Warmup for the optional on-device embedding rerank is kicked OFF the
        // reply path (it can't load in the Simulator); retrieval never waits on
        // it and degrades to BM25 until it's ready.
        let activeLever = coachMemoryStore.currentMemory?.currentLever
        let hasDiagnosis = activeLever != nil
        if KnowledgeBrainFlags.semanticRerankEnabled {
            Task { await KnowledgeSemanticReranker.shared.warmUpIfNeeded() }
        }
        let coachingExpertise = await KnowledgeRetriever.retrieveReranked(
            query: latestUserTurn ?? "",
            lever: activeLever,
            voice: profileStore.profile?.speakingStyleGoal,
            hasDiagnosis: hasDiagnosis
        )
        AICallDiagnostics.record(
            surface: "Coach brain retrieval",
            providerName: "On-device brain",
            model: KnowledgeBrainFlags.semanticRerankEnabled ? "BM25 + semantic rerank" : "BM25",
            outcome: coachingExpertise.isEmpty ? .skipped : .success,
            reason: Self.brainDiagnosticReason(
                cards: coachingExpertise,
                latestUserTurn: latestUserTurn,
                hasDiagnosis: hasDiagnosis
            )
        )

        let context = CoachContextBuilder.userContext(
            profile: profileStore.profile,
            baseline: BaselineStore.shared.baseline,
            rating: RatingStore.shared.rating,
            sessions: sessionStore.sessions,
            currentStreak: StreakFreezeManager.shared.currentStreak,
            pathStatus: PathProgressManager.shared.currentNode,
            pathGatingPhrase: PathProgressManager.shared.currentNodeGatingPhrase,
            recentProofs: recentProofs,
            bigMoment: BigMomentStore.shared.activeMoment,
            recentMomentOutcomes: BigMomentStore.shared.recentOutcomeReports(limit: BigMomentStore.outcomeReportCap),
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
            weeklyCheckInDue: weeklyCheckInDue,
            latestUserTurn: latestUserTurn,
            previousCoachReply: previousCoachReply,
            recentUserTurns: recentUserTurns,
            coachingExpertise: coachingExpertise
        )

        // Quote-grounding context — assembled in the same main-actor prologue
        // so the live model can reference recent rep/proof text without
        // fabricating quotes.
        // The genuinely most-recent timed rep, by date. NOT `sessions.last(...)`:
        // the store is newest-first (`sessions.insert(at: 0)` + descending
        // sorts), so `.last(where:)` returned the OLDEST timed rep and sourced
        // the quote guard from a stale transcript. Pick by date so the model's
        // verified quote sources match the newest-rep context builder reads.
        let recentTimed = sessionStore.sessions
            .filter { $0.mode == .timed }
            .max(by: { $0.date < $1.date })
        let groundingContext = ChatGroundingContext(
            recentTimedTranscript: recentTimed?.transcript,
            verifiedProofQuotes: recentProofs.map(\.proof.quote)
        )

        Self.log.debug("generating coach reply history=\(history.count, privacy: .public) sessions=\(sessionStore.sessions.count, privacy: .public) proofs=\(recentProofs.count, privacy: .public) weeklyCheckInDue=\(weeklyCheckInDue, privacy: .public)")
        let outcome = await AICoachChatService.shared.reply(
            history: history,
            systemPrompt: systemPrompt,
            userContext: context,
            grounding: groundingContext
        )
        switch outcome {
        case .reply(let text):
            Self.log.info("coach pipeline produced live reply chars=\(text.count, privacy: .public)")
        case .failure(let failure):
            Self.log.notice("coach pipeline produced failure=\(String(describing: failure), privacy: .public)")
        }
        AskNoumStore.shared.completeCoachTurn(id: coachID, outcome: outcome)
        return outcome
    }
}

#endif
