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

    nonisolated static func retrievalTrace(
        cards: [CoachKnowledgeCard],
        retrievalQuery: String?,
        activeLever: SkillArea?,
        voice: SpeakingStyleGoal?,
        hasDiagnosis: Bool,
        semanticRerankAllowed: Bool
    ) -> CoachRetrievalTrace {
        let trimmedTurn = retrievalQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return CoachRetrievalTrace(
            strategy: semanticRerankAllowed ? "BM25 + semantic rerank" : "BM25",
            queryPresent: !trimmedTurn.isEmpty,
            queryCharacterCount: trimmedTurn.count,
            hasDiagnosis: hasDiagnosis,
            activeLever: activeLever?.rawValue,
            voice: voice?.rawValue,
            semanticRerankAllowed: semanticRerankAllowed,
            retrievedCardCount: cards.count,
            retrievedCardIDs: cards.map(\.id),
            diagnosticReason: brainDiagnosticReason(
                cards: cards,
                latestUserTurn: retrievalQuery,
                hasDiagnosis: hasDiagnosis
            )
        )
    }

    /// Resolve short follow-ups against the user's own recent turns before
    /// asking the local knowledge retriever for a technique. Retrieval used to
    /// see only text such as "What should I check after?", which discarded the
    /// leadership/interview context already present in the shared chat history.
    /// Keep this bounded and user-authored: two prior user turns, 240 characters
    /// each, only when the current turn is genuinely elliptical.
    nonisolated static func knowledgeRetrievalQuery(
        latestUserTurn: String?,
        history: [CoachMessage],
        maxPriorUserTurns: Int = 2
    ) -> String {
        let current = latestUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !current.isEmpty,
              maxPriorUserTurns > 0,
              wordCount(in: current) <= 12 else {
            return current
        }

        let normalized = " \(current.lowercased()) "
        let continuationPhrases = [
            "what should i check", "what should i listen for",
            "what do i do next", "what next", "after?", " after ",
            " that ", " this ", " it ", " same ", " again ",
            "how do i make that", "how do i do that"
        ]
        guard continuationPhrases.contains(where: { normalized.contains($0) }),
              let latestUserIndex = history.lastIndex(where: { $0.role == .user }),
              latestUserIndex > history.startIndex else {
            return current
        }

        let priorTurns = history[..<latestUserIndex]
            .reversed()
            .filter { $0.role == .user }
            .prefix(maxPriorUserTurns)
            .reversed()
            .map { message in
                String(message.text.prefix(240))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        guard !priorTurns.isEmpty else { return current }
        return ([current] + priorTurns.map { "Earlier user context: \($0)" })
            .joined(separator: "\n")
    }

    nonisolated static func shouldShowProvisionalCoachRead(
        turnDepth: CoachTurnDepth,
        surface: CoachReplySurface,
        responseMode: CoachAssessment.ResponseMode,
        realtimeCoachModeEnabled: Bool
    ) -> Bool {
        guard realtimeCoachModeEnabled else { return false }
        if surface == .live { return true }
        if responseMode == .expandable { return true }
        return turnDepth == .deepAssessment || turnDepth == .trustRepair
    }

    nonisolated static func shouldUseSemanticKnowledgeRerank(
        surface: CoachReplySurface,
        semanticRerankEnabled: Bool = KnowledgeBrainFlags.semanticRerankEnabled
    ) -> Bool {
        semanticRerankEnabled && surface != .live
    }

    /// Assemble context from the shared stores, call the model, and hydrate the
    /// pending coach row identified by `coachID`. Returns the outcome so the
    /// caller can decide whether to speak it. `@MainActor`: the store reads run
    /// on main before the single `await`, exactly as the original prologue did.
    @MainActor
    @discardableResult
    static func generate(
        coachID: UUID,
        pendingGoalIntent: CoachContextBuilder.GoalIntent? = nil,
        surface: CoachReplySurface = .text,
        store: AskNoumStore? = nil,
        coachService: AICoachChatService = .shared,
        judgementPassEnabled: Bool = CoachBrainFlags.judgementPassEnabled,
        realtimeCoachModeEnabled: Bool = CoachBrainFlags.realtimeCoachModeEnabled,
        // Test-only evidence injection (mirrors the existing `store`/`coachService`
        // injectable params). When nil (production + every real caller) the pipeline
        // reads sessions from PracticeSessionStore.shared exactly as before. The
        // app-path evaluation harness passes a conversation's real source-fixture
        // sessions so the trajectory carries genuine evidence coverage — matching the
        // shipping precondition that Ask Noum chat happens after a baseline exists.
        sessionsOverride: [PracticeSession]? = nil,
        onProvisionalCoachReadVisible: (@MainActor (String) -> Void)? = nil,
        onQualityGateEvent: (@MainActor (CoachTurnQualityGateEvent) -> Void)? = nil
    ) async -> ChatOutcome {
        let turnStartedAt = Date()
        let store = store ?? AskNoumStore.shared
        let profileStore = CoachingProfileStore.shared
        let systemPrompt = CoachContextBuilder.systemPrompt(
            for: profileStore.profile,
            structuredReplyShapeEnabled: CoachContextBuilder.structuredAskNoumReplyShapeEnabled(),
            judgmentLayerRuleEnabled: CoachContextBuilder.judgmentLayerRuleEnabled()
        )

        // Trend analysis at call time — cheap pure work over the snapshot store.
        let snapshots = SkillTrendStore.shared.snapshots
        let trends = TrendAnalyzer.analyze(snapshots: snapshots)

        let sessions = sessionsOverride ?? PracticeSessionStore.shared.sessions
        let coachMemoryStore = CoachMemoryStore.shared
        let weeklyCheckInDue = !sessions.isEmpty && CoachCheckInStore.shared.isCheckInDue()
        let recentProofs = ProofMomentStore.shared.recent(limit: 3)
        let history = store.replayForModel
        let latestUserIndex = history.lastIndex { $0.role == .user }
        let latestUserTurn = latestUserIndex.map { history[$0].text }
        let turnDepth = judgementPassEnabled
            ? TurnDepthClassifier.classify(
                userText: latestUserTurn ?? "",
                recentTurns: history,
                liveMode: surface == .live
            )
            : .groundedRead
        let preferredTier = CoachPromptBundle.preferredProviderTier(
            for: turnDepth,
            surface: surface,
            realtimeCoachModeEnabled: realtimeCoachModeEnabled
        )
        let previousCoachReply = latestUserIndex.flatMap { index in
            history[..<index].last { $0.role == .coach }?.text
        }
        let recentCoachReplies = latestUserIndex.map { index in
            Array(
                history[..<index]
                    .reversed()
                    .filter { $0.role == .coach }
                    .map(\.text)
                    .prefix(4)
            )
        } ?? []
        let recentProofTests = Self.recentProofTests(
            beforeLatestUserIndex: latestUserIndex,
            in: history
        )
        let recentProofTestHashes = Self.recentProofTestHashes(
            beforeLatestUserIndex: latestUserIndex,
            in: history
        )
        // EQ — recent user turns for sustained emotional pattern detection.
        // Newest-first, capped at 6 so the arc detector can scan a meaningful
        // window without unbounded history reads.
        let recentUserTurns = history
            .filter { $0.role == .user }
            .suffix(6)
            .map { $0.text }

        // BRAIN — retrieve the coaching expertise most worth grounding this turn
        // in. Text chat can use the optional semantic rerank; live mode stays
        // on pure BM25 so it never kicks embedding warmup or waits on the actor
        // path inside a spoken-response budget.
        let activeLever = coachMemoryStore.currentMemory?.currentLever
        let hasDiagnosis = activeLever != nil
        let retrievalQuery = knowledgeRetrievalQuery(
            latestUserTurn: latestUserTurn,
            history: history
        )
        let semanticRerankAllowed = Self.shouldUseSemanticKnowledgeRerank(surface: surface)
        if semanticRerankAllowed {
            Task { await KnowledgeSemanticReranker.shared.warmUpIfNeeded() }
        }
        let coachingExpertise: [CoachKnowledgeCard]
        if semanticRerankAllowed {
            coachingExpertise = await KnowledgeRetriever.retrieveReranked(
                query: retrievalQuery,
                lever: activeLever,
                voice: profileStore.profile?.speakingStyleGoal,
                hasDiagnosis: hasDiagnosis
            )
        } else {
            coachingExpertise = KnowledgeRetriever.retrieve(
                query: retrievalQuery,
                lever: activeLever,
                voice: profileStore.profile?.speakingStyleGoal,
                hasDiagnosis: hasDiagnosis
            )
        }
        AICallDiagnostics.record(
            surface: "Coach brain retrieval",
            providerName: "On-device brain",
            model: semanticRerankAllowed ? "BM25 + semantic rerank" : "BM25",
            outcome: coachingExpertise.isEmpty ? .skipped : .success,
            reason: Self.brainDiagnosticReason(
                cards: coachingExpertise,
                latestUserTurn: retrievalQuery,
                hasDiagnosis: hasDiagnosis
            )
        )
        let retrievalTrace = Self.retrievalTrace(
            cards: coachingExpertise,
            retrievalQuery: retrievalQuery,
            activeLever: activeLever,
            voice: profileStore.profile?.speakingStyleGoal,
            hasDiagnosis: hasDiagnosis,
            semanticRerankAllowed: semanticRerankAllowed
        )

        let trajectoryResult = UserTrajectoryCache.shared.snapshot(
            profile: profileStore.profile,
            baseline: BaselineStore.shared.baseline,
            rating: RatingStore.shared.rating,
            sessions: sessions,
            coachMemory: coachMemoryStore.currentMemory
        )
        let activeRubric = GoalRubricStore.activeRubric(for: profileStore.profile)
        let reasoningStartedAt = Date()
        let assessmentResult: CoachAssessmentCacheResult? = judgementPassEnabled
            ? CoachAssessmentCache.shared.assessment(
                turnDepth: turnDepth,
                userQuestion: latestUserTurn ?? "",
                trajectory: trajectoryResult.snapshot,
                rubric: activeRubric,
                surface: surface,
                recentProofTests: recentProofTests,
                previousCoachReply: previousCoachReply,
                build: {
                    CoachReasoningPass.assess(
                        turnDepth: turnDepth,
                        userQuestion: latestUserTurn ?? "",
                        trajectory: trajectoryResult.snapshot,
                        rubric: activeRubric,
                        surface: surface,
                        recentProofTests: recentProofTests,
                        previousCoachReply: previousCoachReply
                    )
                }
            )
            : nil
        let assessment = assessmentResult?.assessment
        let assessmentProofTestHash = assessment.map {
            Self.proofTestHash(for: $0.nextProofTest)
        }
        let proofTestRecentlyRepeated = assessmentProofTestHash.map {
            recentProofTestHashes.contains($0)
        }
        let assessmentCacheAgeMsAt: (Date) -> Int? = { date in
            assessmentResult.map { Self.latencyMs(from: $0.generatedAt, to: date) }
        }
        let assessmentCacheAgeAtReasoning = assessmentCacheAgeMsAt(Date())
        var firstVisibleAt: Date?
        var firstVisibleSource: CoachFirstVisibleTokenSource?
        var immediateCoachReadShown = false
        if let assessment {
            AICallDiagnostics.record(
                surface: "Coach judgement pass",
                providerName: "On-device coach brain",
                model: "CoachReasoningPass",
                outcome: .success,
                reason: "turnDepth=\(turnDepth.rawValue) trajectoryCacheHit=\(trajectoryResult.cacheHit) assessmentCacheHit=\(assessmentResult?.cacheHit ?? false) assessmentCacheAgeMs=\(assessmentCacheAgeAtReasoning ?? -1) reasoningEvidence=\(assessment.evidenceReferenceCount)",
                startedAt: reasoningStartedAt
            )
            if Self.shouldShowProvisionalCoachRead(
                turnDepth: turnDepth,
                surface: surface,
                responseMode: assessment.responseMode,
                realtimeCoachModeEnabled: realtimeCoachModeEnabled
            ) {
                let provisionalVisibleAt = Date()
                let immediateCoachRead = CoachDisplayCopy.normalized(
                    CoachReplyTextSanitizer.coachReplyText(
                        from: assessment.immediateCoachRead
                    )
                )
                let provisionalMetadata = CoachTurnMetadata(
                    turnDepth: turnDepth,
                    providerTier: preferredTier,
                    semanticGateOutcome: .notEvaluated,
                    evidenceCoverage: trajectoryResult.snapshot.evidenceCoverage,
                    assessment: assessment,
                    assessmentConfidence: assessment.confidence,
                    proofTestHash: assessmentProofTestHash,
                    proofTestRecentlyRepeated: proofTestRecentlyRepeated,
                    retrievalTrace: retrievalTrace,
                    assessmentCacheHit: assessmentResult?.cacheHit,
                    assessmentCacheAgeMs: assessmentCacheAgeMsAt(provisionalVisibleAt),
                    immediateCoachReadShown: true,
                    ttftMs: Self.latencyMs(from: turnStartedAt, to: provisionalVisibleAt),
                    timeToFirstVisibleTokenMs: Self.latencyMs(from: turnStartedAt, to: provisionalVisibleAt),
                    timeToFirstVisibleTokenSource: .localImmediateRead,
                    trajectoryCacheHit: trajectoryResult.cacheHit,
                    surface: surface
                )
                if store.setProvisionalCoachRead(
                    id: coachID,
                    text: immediateCoachRead,
                    metadata: provisionalMetadata
                ) {
                    firstVisibleAt = provisionalVisibleAt
                    firstVisibleSource = .localImmediateRead
                    immediateCoachReadShown = true
                    onProvisionalCoachReadVisible?(immediateCoachRead)
                }
                AICallDiagnostics.record(
                    surface: "Coach immediate read",
                    providerName: "On-device coach brain",
                    model: "CoachAssessment",
                    outcome: .success,
                    reason: "turnDepth=\(turnDepth.rawValue) cacheHit=\(trajectoryResult.cacheHit) timeToFirstVisibleToken=local",
                    startedAt: turnStartedAt
                )
            }
        } else {
            AICallDiagnostics.record(
                surface: "Coach judgement pass",
                providerName: "On-device coach brain",
                model: "CoachReasoningPass",
                outcome: .skipped,
                reason: "judgementPassEnabled=false turnDepth=\(turnDepth.rawValue)"
            )
        }
        var providerChoice: CoachTurnProviderChoice?

        var context = CoachContextBuilder.userContext(
            profile: profileStore.profile,
            baseline: BaselineStore.shared.baseline,
            rating: RatingStore.shared.rating,
            sessions: sessions,
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
        if let assessment {
            context += "\n" + CoachPromptBundle.contextBlock(
                assessment: assessment,
                rubric: activeRubric,
                surface: surface
            )
        }
        let promptTrace = CoachPromptTrace.make(
            systemPrompt: systemPrompt,
            userContext: context
        )

        // Quote-grounding context — assembled in the same main-actor prologue
        // so the live model can reference recent rep/proof text without
        // fabricating quotes.
        // The genuinely most-recent timed rep, by date. NOT `sessions.last(...)`:
        // the store is newest-first (`sessions.insert(at: 0)` + descending
        // sorts), so `.last(where:)` returned the OLDEST timed rep and sourced
        // the quote guard from a stale transcript. Pick by date so the model's
        // verified quote sources match the newest-rep context builder reads.
        let recentTimed = sessions
            .filter { $0.mode == .timed }
            .max(by: { $0.date < $1.date })
        let groundingContext = ChatGroundingContext(
            recentTimedTranscript: recentTimed?.transcript,
            verifiedProofQuotes: recentProofs.map(\.proof.quote)
        )

        var qualityGateEvents: [CoachTurnQualityGateEvent] = []
        var providerAttemptEvents: [CoachProviderAttemptEvent] = []
        Self.log.debug("generating coach reply history=\(history.count, privacy: .public) sessions=\(sessions.count, privacy: .public) proofs=\(recentProofs.count, privacy: .public) weeklyCheckInDue=\(weeklyCheckInDue, privacy: .public)")
        let outcome = await coachService.reply(
            history: history,
            systemPrompt: systemPrompt,
            userContext: context,
            grounding: groundingContext,
            turnDepth: turnDepth,
            assessment: assessment,
            surface: surface,
            preferredTier: preferredTier,
            onStreamedPartialVisible: { partialText in
                // Withhold raw un-vetted provider tokens from the visible row
                // unless explicitly opted in. Default off means the user sees
                // the local deterministic read while the model verbalises, then
                // the committed (gate-approved) final — never a rich draft that
                // is silently downgraded to a shorter substituted final.
                guard CoachBrainFlags.streamRawPartialsToUI else { return }
                let streamedVisibleAt = Date()
                let streamedTTFT = Self.latencyMs(from: turnStartedAt, to: firstVisibleAt ?? streamedVisibleAt)
                let streamedFirstVisibleSource = firstVisibleSource ?? CoachFirstVisibleTokenSource.streamedProviderPartial
                let streamedMetadata = CoachTurnMetadata(
                    turnDepth: turnDepth,
                    providerTier: preferredTier,
                    semanticGateOutcome: .notEvaluated,
                    evidenceCoverage: trajectoryResult.snapshot.evidenceCoverage,
                    assessment: assessment,
                    assessmentConfidence: assessment?.confidence,
                    proofTestHash: assessmentProofTestHash,
                    proofTestRecentlyRepeated: proofTestRecentlyRepeated,
                    retrievalTrace: retrievalTrace,
                    promptTrace: promptTrace,
                    assessmentCacheHit: assessmentResult?.cacheHit,
                    assessmentCacheAgeMs: assessmentCacheAgeMsAt(streamedVisibleAt),
                    immediateCoachReadShown: immediateCoachReadShown,
                    ttftMs: streamedTTFT,
                    timeToFirstVisibleTokenMs: streamedTTFT,
                    timeToFirstVisibleTokenSource: streamedFirstVisibleSource,
                    trajectoryCacheHit: trajectoryResult.cacheHit,
                    surface: surface
                )
                if store.setProvisionalCoachRead(
                    id: coachID,
                    text: partialText,
                    metadata: streamedMetadata
                ) {
                    if firstVisibleAt == nil {
                        firstVisibleAt = streamedVisibleAt
                        firstVisibleSource = .streamedProviderPartial
                        FlowLog.log(
                            correlationId: coachID,
                            flow: .chatTurn,
                            stage: "chat.draftShown",
                            reason: "streamed provider partials made visible (pre-gate)",
                            numerics: ["ttftMs": streamedTTFT]
                        )
                    }
                }
            },
            onProviderChosen: { choice in
                providerChoice = choice
            },
            onProviderAttemptEvent: { event in
                providerAttemptEvents.append(event)
            },
            onQualityGateEvent: { event in
                qualityGateEvents.append(event)
                onQualityGateEvent?(event)
            }
        )
        guard !Task.isCancelled else {
            store.cancelPendingCoachTurn(id: coachID)
            return .failure(.network)
        }
        let completionAt = Date()

        // Last-mile reliability gate: after the provider chain and its internal
        // repair loops, catch a final reply that is empty, a verbatim repeat of
        // the previous coach turn, a placeholder stub, or a leaked scaffold, and
        // substitute a truthful coach-shaped fallback before it reaches the UI.
        // Missing attunement on trust repair is treated as a user-facing defect:
        // if the user pushes back and the final answer opens by prescribing, the
        // gate substitutes the deterministic repair read. Softer calibration
        // smells (near-duplicate phrasing, floor-pinned confidence) are
        // recorded in metadata but never replace an otherwise-fine reply.
        // Repeated proof tests and repeated prescription-only discourse moves
        // are user-facing loop defects, so they block. Flag-guarded; off keeps
        // the pre-gate behaviour.
        let reliabilityVerdict: CoachReliabilityVerdict
        if CoachBrainFlags.reliabilityGateEnabled, case .reply(let rawText) = outcome {
            reliabilityVerdict = CoachReliabilityGate.evaluate(
                replyText: CoachReplyTextSanitizer.coachReplyText(from: rawText),
                previousCoachReply: previousCoachReply,
                recentCoachReplies: recentCoachReplies,
                latestUserTurn: latestUserTurn,
                turnDepth: turnDepth,
                assessment: assessment,
                evidenceCoverage: trajectoryResult.snapshot.evidenceCoverage,
                proofTestRecentlyRepeated: proofTestRecentlyRepeated ?? false,
                surface: surface
            )
        } else {
            reliabilityVerdict = .clean
        }
        let contentRejectedFallback = Self.contentRejectedFallbackText(
            for: outcome,
            assessment: assessment,
            turnDepth: turnDepth,
            surface: surface,
            previousCoachReply: previousCoachReply,
            recentCoachReplies: recentCoachReplies,
            latestUserTurn: latestUserTurn
        )
        if contentRejectedFallback != nil {
            qualityGateEvents.append(.fallback("deterministicAssessmentAfterContentRejected"))
            AICallDiagnostics.record(
                surface: "Coach content rejection fallback",
                providerName: "CoachReplyPipeline",
                model: "CoachReliabilityGate",
                outcome: .fallback,
                reason: "turnDepth=\(turnDepth.rawValue) surface=\(surface.rawValue)"
            )
        }
        let effectiveOutcome: ChatOutcome = reliabilityVerdict.fallbackText.map { .reply($0) } ??
            contentRejectedFallback.map { .reply($0) } ??
            outcome
        let finalizedOutcome = Self.finalizedOutcome(
            effectiveOutcome,
            latestUserTurn: latestUserTurn,
            turnDepth: turnDepth
        )
        // Observability: record whether the reply the user finally sees is the
        // streamed one or a gate substitution — this is what makes the
        // "rich draft quietly replaced by a shorter final" incident legible.
        let draftWasReplaced = reliabilityVerdict.fallbackText != nil || contentRejectedFallback != nil
        FlowLog.log(
            correlationId: coachID,
            flow: .chatTurn,
            stage: draftWasReplaced ? "chat.finalSubstituted" : "chat.finalCommitted",
            outcome: draftWasReplaced ? .fallback : .success,
            reason: draftWasReplaced
                ? "a downstream gate replaced the streamed reply the user already saw"
                : "streamed reply committed unchanged",
            numerics: ["blocked": reliabilityVerdict.blocked ? 1 : 0]
        )
        if reliabilityVerdict.blocked {
            AICallDiagnostics.record(
                surface: "Coach reliability gate",
                providerName: "CoachReplyPipeline",
                model: "CoachReliabilityGate",
                outcome: .fallback,
                reason: "blocked=\(reliabilityVerdict.blockingIssues.map(\.rawValue).joined(separator: ",")) issues=\(reliabilityVerdict.issues.map(\.rawValue).joined(separator: ",")) turnDepth=\(turnDepth.rawValue) surface=\(surface.rawValue)"
            )
            Self.log.notice("reliability gate replaced reply blocking=\(reliabilityVerdict.blockingIssues.map(\.rawValue).joined(separator: ","), privacy: .public)")
        } else if !reliabilityVerdict.issues.isEmpty {
            AICallDiagnostics.record(
                surface: "Coach reliability gate",
                providerName: "CoachReplyPipeline",
                model: "CoachReliabilityGate",
                outcome: .success,
                reason: "softIssues=\(reliabilityVerdict.issues.map(\.rawValue).joined(separator: ",")) turnDepth=\(turnDepth.rawValue) surface=\(surface.rawValue)"
            )
        }

        let finalVision: CoachVisionEvaluationResult? = {
            guard case .reply(let rawText) = finalizedOutcome else { return nil }
            let reply = CoachReplyTextSanitizer.coachReplyText(from: rawText)
            guard !reply.isEmpty else { return nil }
            return AICoachChatService.coachVisionEvaluation(
                reply: reply,
                latestUserTurn: latestUserTurn,
                quoteGuard: CoachChatQuoteGuardContext(
                    transcripts: [groundingContext.recentTimedTranscript],
                    verifiedProofQuotes: groundingContext.verifiedProofQuotes,
                    latestUserTurn: latestUserTurn,
                    recentUserTurns: recentUserTurns
                ),
                systemContext: context,
                recentCoachReplies: recentCoachReplies,
                turnDepth: turnDepth,
                assessment: assessment,
                surface: surface
            )
        }()
        let finalReplyWordCount: Int? = {
            guard case .reply(let rawText) = finalizedOutcome else { return nil }
            return Self.wordCount(in: CoachReplyTextSanitizer.coachReplyText(from: rawText))
        }()
        let finalSemanticGateOutcome = Self.semanticGateOutcome(
            for: finalizedOutcome,
            latestUserTurn: latestUserTurn,
            turnDepth: turnDepth,
            assessment: assessment
        )
        let finalTTFT = Self.latencyMs(from: turnStartedAt, to: firstVisibleAt ?? completionAt)
        let finalLatency = Self.latencyMs(from: turnStartedAt, to: completionAt)
        let finalFirstVisibleSource: CoachFirstVisibleTokenSource? = {
            if let firstVisibleSource {
                return firstVisibleSource
            }
            if case .reply = finalizedOutcome {
                return .finalReplyCommit
            }
            return nil
        }()
        let finalMetadata = CoachTurnMetadata(
            turnDepth: turnDepth,
            providerTier: preferredTier,
            providerTierChosen: Self.providerTierChosen(
                for: providerChoice,
                requestedTier: preferredTier
            ),
            semanticGateOutcome: finalSemanticGateOutcome,
            semanticGateIssue: Self.semanticGateIssue(
                for: finalSemanticGateOutcome,
                qualityGateEvents: qualityGateEvents
            ),
            evidenceCoverage: trajectoryResult.snapshot.evidenceCoverage,
            assessment: assessment,
            assessmentConfidence: assessment?.confidence,
            proofTestHash: assessmentProofTestHash,
            proofTestRecentlyRepeated: proofTestRecentlyRepeated,
            retrievalTrace: retrievalTrace,
            promptTrace: promptTrace,
            visionScore: finalVision?.score,
            visionCriticalMisses: finalVision?.criticalMisses,
            visionPassesProductionFloor: finalVision?.passesProductionFloor,
            qualityGateOutcome: Self.qualityGateOutcome(
                for: qualityGateEvents,
                outcome: outcome
            ),
            qualityGateFailureCount: Self.qualityGateFailureCount(qualityGateEvents),
            qualityGateRepairCount: Self.qualityGateRepairCount(qualityGateEvents),
            qualityGateEvents: qualityGateEvents.isEmpty
                ? nil
                : qualityGateEvents.map(Self.qualityGateEventLogValue),
            assessmentCacheHit: assessmentResult?.cacheHit,
            assessmentCacheAgeMs: assessmentCacheAgeMsAt(completionAt),
            immediateCoachReadShown: immediateCoachReadShown,
            replyWordCount: finalReplyWordCount,
            providerRetryCount: Self.providerRetryCount(providerAttemptEvents),
            providerAttemptCount: Self.providerAttemptCount(providerAttemptEvents),
            providerRefusalCount: Self.providerRefusalCount(providerAttemptEvents),
            ttftMs: finalTTFT,
            fullLatencyMs: finalLatency,
            timeToFirstVisibleTokenMs: finalTTFT,
            timeToFirstVisibleTokenSource: finalFirstVisibleSource,
            timeToCompleteReplyMs: finalLatency,
            providerName: providerChoice?.providerName,
            providerModel: providerChoice?.model,
            trajectoryCacheHit: trajectoryResult.cacheHit,
            surface: surface,
            reliabilityIssues: reliabilityVerdict.issues.isEmpty ? nil : reliabilityVerdict.issues,
            reliabilityFallbackApplied: reliabilityVerdict.blocked ? true : nil
        )
        AICallDiagnostics.record(
            surface: "Coach response timing",
            providerName: "CoachReplyPipeline",
            model: "Shared coach pipeline",
            outcome: {
                if case .reply = outcome { return .success }
                return .failure
            }(),
            reason: [
                "turnDepth=\(turnDepth.rawValue)",
                "cacheHit=\(trajectoryResult.cacheHit)",
                "surface=\(surface.rawValue)",
                "providerTier=\(preferredTier.rawValue)",
                "providerTierChosen=\(finalMetadata.providerTierChosen?.rawValue ?? "none")",
                "providerChosen=\(providerChoice?.providerName ?? "none")",
                "providerModel=\(providerChoice?.model ?? "none")",
                "ttftMs=\(finalMetadata.ttftMs ?? -1)",
                "fullLatencyMs=\(finalMetadata.fullLatencyMs ?? -1)",
                "timeToFirstVisibleTokenMs=\(finalMetadata.timeToFirstVisibleTokenMs ?? -1)",
                "timeToFirstVisibleTokenSource=\(finalMetadata.timeToFirstVisibleTokenSource?.rawValue ?? "none")",
                "timeToCompleteReplyMs=\(finalMetadata.timeToCompleteReplyMs ?? -1)",
                "assessmentCacheHit=\(assessmentResult.map { "\($0.cacheHit)" } ?? "unknown")",
                "assessmentConfidence=\(assessment.map { String(format: "%.2f", $0.confidence) } ?? "none")",
                "proofTestHash=\(finalMetadata.proofTestHash ?? "none")",
                "proofTestRepeated=\(finalMetadata.proofTestRecentlyRepeated.map { "\($0)" } ?? "unknown")",
                "visionScore=\(finalMetadata.visionScore.map { "\($0)" } ?? "none")",
                "visionPassesFloor=\(finalMetadata.visionPassesProductionFloor.map { "\($0)" } ?? "unknown")",
                "qualityGate=\(finalMetadata.qualityGateOutcome?.logValue ?? "notEvaluated")",
                "qualityGateFailures=\(finalMetadata.qualityGateFailureCount ?? 0)",
                "qualityGateRepairs=\(finalMetadata.qualityGateRepairCount ?? 0)",
                "assessmentCacheAgeMs=\(finalMetadata.assessmentCacheAgeMs ?? -1)",
                "immediateCoachReadShown=\(finalMetadata.immediateCoachReadShown.map { "\($0)" } ?? "unknown")",
                "replyWordCount=\(finalMetadata.replyWordCount ?? -1)",
                "providerRetryCount=\(finalMetadata.providerRetryCount ?? 0)",
                "providerAttemptCount=\(finalMetadata.providerAttemptCount ?? 0)",
                "providerRefusalCount=\(finalMetadata.providerRefusalCount ?? 0)",
                "semanticGateIssue=\(finalMetadata.semanticGateIssue ?? "none")",
                "semanticGate=\(finalMetadata.semanticGateOutcome?.logValue ?? "notEvaluated")",
                "reliabilityFallback=\(reliabilityVerdict.blocked)",
                "reliabilityIssues=\(reliabilityVerdict.issues.isEmpty ? "none" : reliabilityVerdict.issues.map(\.rawValue).joined(separator: ","))"
            ].joined(separator: " "),
            startedAt: turnStartedAt,
            now: completionAt
        )
        switch finalizedOutcome {
        case .reply(let text):
            Self.log.info("coach pipeline produced live reply chars=\(text.count, privacy: .public)")
        case .failure(let failure):
            Self.log.notice("coach pipeline produced failure=\(String(describing: failure), privacy: .public)")
        }
        store.completeCoachTurn(
            id: coachID,
            outcome: finalizedOutcome,
            metadata: finalMetadata
        )
        return finalizedOutcome
    }

    nonisolated static func finalizedOutcome(
        _ outcome: ChatOutcome,
        latestUserTurn: String?,
        turnDepth: CoachTurnDepth
    ) -> ChatOutcome {
        switch outcome {
        case .reply(let text):
            return .reply(AICoachChatService.finalizedCoachReply(
                from: text,
                latestUserTurn: latestUserTurn,
                turnDepth: turnDepth
            ))
        case .failure:
            return outcome
        }
    }

    private static func semanticGateOutcome(
        for outcome: ChatOutcome,
        latestUserTurn: String?,
        turnDepth: CoachTurnDepth,
        assessment: CoachAssessment?
    ) -> CoachTurnSemanticGateOutcome {
        guard let assessment else { return .notEvaluated }
        switch outcome {
        case .reply(let text):
            let normalized = CoachReplyTextSanitizer.coachReplyText(from: text)
            guard !normalized.isEmpty else { return .notEvaluated }
            if let issue = AICoachChatService.semanticQualityIssue(
                in: normalized,
                latestUserTurn: latestUserTurn,
                turnDepth: turnDepth,
                assessment: assessment
            ) {
                return .failed(issue.rawValue)
            }
            return .passed
        case .failure:
            return .notEvaluated
        }
    }

    nonisolated static func contentRejectedFallbackText(
        for outcome: ChatOutcome,
        assessment: CoachAssessment?,
        turnDepth: CoachTurnDepth,
        surface: CoachReplySurface,
        previousCoachReply: String?,
        recentCoachReplies: [String] = [],
        latestUserTurn: String? = nil
    ) -> String? {
        guard case .failure(.contentRejected) = outcome,
              let assessment else {
            return nil
        }
        let fallback = CoachReliabilityGate.truthfulFallback(
            turnDepth: turnDepth,
            assessment: assessment,
            surface: surface,
            previousCoachReply: previousCoachReply,
            recentCoachReplies: recentCoachReplies,
            latestUserTurn: latestUserTurn
        )
        return CoachReliabilityGate.isCleanCandidate(
            fallback,
            previousCoachReply: previousCoachReply,
            recentCoachReplies: recentCoachReplies
        ) ? fallback : nil
    }

    nonisolated static func qualityGateOutcome(
        for events: [CoachTurnQualityGateEvent],
        outcome: ChatOutcome
    ) -> CoachTurnQualityGateOutcome {
        guard !events.isEmpty else { return .notEvaluated }

        if let fallback = events.reversed().compactMap(Self.fallbackGate).first {
            return .fallback(fallback)
        }
        if let repaired = events.reversed().compactMap(Self.repairedGate).first {
            return .repaired(repaired)
        }
        if case .failure = outcome,
           let failed = events.reversed().compactMap(Self.failedGate).first {
            return .failed(failed)
        }
        if case .failure = outcome,
           let rejected = events.reversed().compactMap(Self.rejectedGate).first {
            return .failed(rejected)
        }
        if events.contains(.passed) {
            return .passed
        }
        if let failed = events.reversed().compactMap(Self.failedGate).first {
            return .failed(failed)
        }
        if let rejected = events.reversed().compactMap(Self.rejectedGate).first {
            return .failed(rejected)
        }
        return .notEvaluated
    }

    nonisolated static func qualityGateFailureCount(
        _ events: [CoachTurnQualityGateEvent]
    ) -> Int {
        events.reduce(0) { count, event in
            switch event {
            case .rejected, .failed:
                return count + 1
            case .passed, .repaired, .fallback:
                return count
            }
        }
    }

    nonisolated static func qualityGateRepairCount(
        _ events: [CoachTurnQualityGateEvent]
    ) -> Int {
        events.reduce(0) { count, event in
            switch event {
            case .repaired, .fallback:
                return count + 1
            case .passed, .rejected, .failed:
                return count
            }
        }
    }

    nonisolated static func semanticGateIssue(
        for semanticOutcome: CoachTurnSemanticGateOutcome,
        qualityGateEvents events: [CoachTurnQualityGateEvent]
    ) -> String? {
        if case .failed(let issue) = semanticOutcome {
            return issue
        }

        for event in events.reversed() {
            guard let label = gateLabel(event) else { continue }
            if label.hasPrefix("semanticDryRun:") {
                return String(label.dropFirst("semanticDryRun:".count))
            }
            if label.hasPrefix("semantic:") {
                return String(label.dropFirst("semantic:".count))
            }
        }
        return nil
    }

    nonisolated static func providerAttemptCount(
        _ events: [CoachProviderAttemptEvent]
    ) -> Int {
        events.reduce(0) { count, event in
            switch event {
            case .started:
                return count + 1
            case .retry, .refused:
                return count
            }
        }
    }

    nonisolated static func providerRefusalCount(
        _ events: [CoachProviderAttemptEvent]
    ) -> Int {
        events.reduce(0) { count, event in
            switch event {
            case .refused:
                return count + 1
            case .started, .retry:
                return count
            }
        }
    }

    nonisolated static func providerRetryCount(
        _ events: [CoachProviderAttemptEvent]
    ) -> Int {
        let chainFailoverCount = max(0, providerAttemptCount(events) - 1)
        let sameProviderRetryCount = events.reduce(0) { count, event in
            switch event {
            case .retry:
                return count + 1
            case .started, .refused:
                return count
            }
        }
        return chainFailoverCount + sameProviderRetryCount
    }

    nonisolated static func providerTierChosen(
        for choice: CoachTurnProviderChoice?,
        requestedTier: CoachProviderTier
    ) -> CoachProviderTier? {
        guard let choice else { return nil }
        if let resolvedTier = choice.resolvedTier {
            return resolvedTier
        }
        let provider = choice.providerName.lowercased()
        let model = choice.model.lowercased()
        if model.contains("gemini-2.5-pro") || model.contains("ultra") {
            return .claudeReasoning
        }
        if model.contains("flash") || model.contains("fast") {
            return .geminiFast
        }
        if provider.contains("claude") {
            return .claudeReasoning
        }
        if provider.contains("gemini") || provider.contains("google cloud") {
            return .geminiFast
        }
        if provider.contains("typed judgement fallback") {
            return requestedTier
        }
        if provider.contains("vertex") || provider.contains("firebase") {
            return requestedTier
        }
        return nil
    }

    private static func repairedGate(_ event: CoachTurnQualityGateEvent) -> String? {
        if case .repaired(let gate) = event { return gate }
        return nil
    }

    private static func fallbackGate(_ event: CoachTurnQualityGateEvent) -> String? {
        if case .fallback(let gate) = event { return gate }
        return nil
    }

    private static func rejectedGate(_ event: CoachTurnQualityGateEvent) -> String? {
        if case .rejected(let gate) = event { return gate }
        return nil
    }

    private static func failedGate(_ event: CoachTurnQualityGateEvent) -> String? {
        if case .failed(let gate) = event { return gate }
        return nil
    }

    private static func gateLabel(_ event: CoachTurnQualityGateEvent) -> String? {
        switch event {
        case .passed:
            return nil
        case .repaired(let gate),
             .fallback(let gate),
             .rejected(let gate),
             .failed(let gate):
            return gate
        }
    }

    nonisolated static func qualityGateEventLogValue(
        _ event: CoachTurnQualityGateEvent
    ) -> String {
        switch event {
        case .passed:
            return "passed"
        case .repaired(let gate):
            return "repaired:\(gate)"
        case .fallback(let gate):
            return "fallback:\(gate)"
        case .rejected(let gate):
            return "rejected:\(gate)"
        case .failed(let gate):
            return "failed:\(gate)"
        }
    }

    private static func latencyMs(from start: Date, to end: Date) -> Int {
        max(0, Int(end.timeIntervalSince(start) * 1_000))
    }

    private static func wordCount(in text: String) -> Int {
        text.split { $0.isWhitespace || $0.isNewline }.count
    }

    private static func recentProofTests(
        beforeLatestUserIndex latestUserIndex: Int?,
        in history: [CoachMessage],
        limit: Int = 6
    ) -> [String] {
        let upperBound = latestUserIndex ?? history.endIndex
        guard upperBound > history.startIndex else { return [] }
        return Array(history[..<upperBound]
            .reversed()
            .compactMap { $0.metadata?.assessment?.nextProofTest }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(limit))
    }

    private static func recentProofTestHashes(
        beforeLatestUserIndex latestUserIndex: Int?,
        in history: [CoachMessage],
        limit: Int = 6
    ) -> Set<String> {
        let upperBound = latestUserIndex ?? history.endIndex
        guard upperBound > history.startIndex else { return [] }
        let hashes = history[..<upperBound]
            .reversed()
            .compactMap { message -> String? in
                guard let metadata = message.metadata else { return nil }
                if let proofTestHash = metadata.proofTestHash,
                   !proofTestHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return proofTestHash
                }
                if let proofTest = metadata.assessment?.nextProofTest {
                    return Self.proofTestHash(for: proofTest)
                }
                return nil
            }
            .prefix(limit)
        return Set(hashes)
    }

    nonisolated static func proofTestHash(for proofTest: String) -> String {
        let normalized = proofTest
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in normalized.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
    }
}

#endif
