import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Session Finalization Result

/// All computed state from committing the post-session coaching lifecycle.
/// Produced once by `SessionFinalizer.finalize()`, then rendered by SummaryView.
struct SessionFinalizationResult {
    let previousXP: Int
    let newXP: Int
    let previousLevel: String
    let newLevel: String
    let isLevelUp: Bool
    let achievementDeltas: [AchievementProgressDelta]
    let newUnlocks: [AchievementTier]
    let milestone: MilestoneEvent?
    let isPersonalBest: Bool
    let showProgressionScreen: Bool

    // New systems
    let nextAction: NextAction?
    let baselineComparisons: [String: String]
    let pressureLevel: PressureLevel
    let coachNote: CoachNote?

    /// M3+: rhetorical devices detected on the transcript. Surfaced as a
    /// positive coaching card in the summary. Empty array when nothing
    /// noteworthy was detected.
    let eloquenceFindings: [EloquenceFinding]

    /// Bonus XP awarded for the eloquence findings. Already added to
    /// `newXP`; surfaced separately so the summary can label it
    /// ("+12 XP for shape").
    let eloquenceBonusXP: Int
}

// MARK: - Durable coaching evidence

/// The pure decision behind the session-to-coaching evidence handoff.
///
/// `PracticeSessionFinalizer` owns durable session completion. Summary may be
/// skipped, interrupted, or reconstructed after a relaunch, so neither the
/// skill snapshot nor the coach's current lever can use view presentation as
/// their commit receipt. The existing stores already carry the two receipts we
/// need: `SkillSnapshot.sessionId` and `CoachMemory.lastSessionID`.
struct DurableCoachingEvidencePlan: Equatable {
    let sessionID: UUID
    let shouldRecordSkillSnapshot: Bool
    let shouldRefreshCoachMemory: Bool
}

enum DurableCoachingEvidencePlanner {
    static func make(
        triggeringSessionID: UUID?,
        sessions: [PracticeSession],
        snapshots: [SkillSnapshot],
        memory: CoachMemory?
    ) -> DurableCoachingEvidencePlan? {
        makeFromEvaluatedSessions(
            triggeringSessionID: triggeringSessionID,
            sessions: evaluatedSessions(in: sessions),
            snapshots: snapshots,
            memory: memory
        )
    }

    static func evaluatedSessions(
        in sessions: [PracticeSession]
    ) -> [PracticeSession] {
        // Persistence precedes evaluation for microphone-backed modes. A row
        // in that crash window is useful Review history, but it cannot become
        // scored coaching evidence until its annotation lands.
        PracticeProgressEligibility.eligibleSessions(in: sessions)
            .filter { $0.score != nil }
    }

    /// Internal projection for a set already admitted through
    /// `evaluatedSessions(in:)`. Reconciliation uses this overload so the same
    /// exact rows drive planning, lookup, and coach-memory refresh.
    static func makeFromEvaluatedSessions(
        triggeringSessionID: UUID?,
        sessions: [PracticeSession],
        snapshots: [SkillSnapshot],
        memory: CoachMemory?
    ) -> DurableCoachingEvidencePlan? {
        guard let latest = latestEligibleSession(in: sessions) else { return nil }

        let target: PracticeSession
        if let triggeringSessionID {
            guard let exact = sessions.first(where: { $0.id == triggeringSessionID }) else {
                return nil
            }
            target = exact
        } else {
            target = latest
        }

        let shouldRecord = !snapshots.contains(where: { $0.sessionId == target.id })
        let shouldRefresh = target.id == latest.id
            && (shouldRecord
                || memoryNeedsRefresh(
                    latestSession: latest,
                    eligibleSessions: sessions,
                    memory: memory
                ))
        return DurableCoachingEvidencePlan(
            sessionID: target.id,
            shouldRecordSkillSnapshot: shouldRecord,
            shouldRefreshCoachMemory: shouldRefresh
        )
    }

    /// Persisted history is normally newest-first, but remote reconciliation
    /// and tests are allowed to provide another ordering. Date is authoritative;
    /// equal dates preserve store order so the result stays deterministic.
    private static func latestEligibleSession(
        in eligibleSessions: [PracticeSession]
    ) -> PracticeSession? {
        eligibleSessions.enumerated().max { lhs, rhs in
            if lhs.element.date != rhs.element.date {
                return lhs.element.date < rhs.element.date
            }
            return lhs.offset > rhs.offset
        }?.element
    }

    private static func memoryNeedsRefresh(
        latestSession: PracticeSession,
        eligibleSessions: [PracticeSession],
        memory: CoachMemory?
    ) -> Bool {
        guard let memory else { return true }
        guard memory.lastSessionID != latestSession.id else { return false }
        guard let previousID = memory.lastSessionID,
              let previousSession = eligibleSessions.first(where: { $0.id == previousID }) else {
            // The persisted session list is the evidence authority. A memory
            // without a resolvable source cannot suppress repair indefinitely.
            return true
        }
        return previousSession.date <= latestSession.date
    }
}

// MARK: - Session Finalizer

/// Extracts lifecycle logic into a single service shared by completion and summary flows.
/// Handles XP application, achievement evaluation, milestone detection, and trend recording.
@MainActor
enum SessionFinalizer {

    /// Commits the evidence needed for cross-session trend and current-lever
    /// continuity from an exact persisted row. Repeated calls are harmless:
    /// the existing session IDs in SkillTrendStore and CoachMemory are the
    /// durable receipts, so Summary, annotation, and relaunch repair cannot
    /// append duplicate snapshots or repeatedly rewrite the same memory.
    @discardableResult
    static func reconcileDurableCoachingEvidence(
        triggeringSessionID: UUID? = nil
    ) -> DurableCoachingEvidencePlan? {
        let sessionStore = PracticeSessionStore.shared
        let trendStore = SkillTrendStore.shared
        let memoryStore = CoachMemoryStore.shared
        let sessions = DurableCoachingEvidencePlanner.evaluatedSessions(
            in: sessionStore.sessions
        )
        guard let plan = DurableCoachingEvidencePlanner.makeFromEvaluatedSessions(
            triggeringSessionID: triggeringSessionID,
            sessions: sessions,
            snapshots: trendStore.snapshots,
            memory: memoryStore.currentMemory
        ),
              let session = sessions.first(where: { $0.id == plan.sessionID }) else {
            return nil
        }

        if plan.shouldRecordSkillSnapshot {
            guard let snapshot = skillSnapshot(from: session) else { return nil }
            trendStore.record(snapshot)
        }

        if plan.shouldRefreshCoachMemory {
            let trends = TrendAnalyzer.analyze(snapshots: trendStore.snapshots)
            let profile = CoachingProfileStore.shared.profile
            let currentForwardPlan = ForwardPlanStore.shared.currentPlan(
                activeBigMomentID: BigMomentStore.shared.activeMoment?.id,
                chosenStyleGoal: profile?.chosenStyleGoal
            )
            memoryStore.refresh(
                profile: profile,
                baseline: BaselineStore.shared.baseline,
                sessions: sessions,
                trends: trends,
                forwardPlan: currentForwardPlan,
                lastSessionID: session.id,
                pendingIntervention: RecommendationLearningStore.shared.pendingExposure,
                recommendationOutcomes: RecommendationLearningStore.shared.outcomes,
                latestReflection: SessionReflectionStore.shared.latest,
                reflectionHistory: SessionReflectionStore.shared.history,
                latestTransferReport: BigMomentStore.shared.recentOutcomeReports(limit: 1).first,
                upcomingMoment: BigMomentStore.shared.activeMoment
            )
        }

        if plan.shouldRecordSkillSnapshot || plan.shouldRefreshCoachMemory {
            _ = UserTrajectoryCache.shared.invalidateAndWarmFromCurrentStores()
            FlowLog.log(
                correlationId: session.id,
                flow: .practiceRep,
                stage: "coaching-evidence.reconciled",
                reason: plan.shouldRefreshCoachMemory
                    ? "durable skill snapshot and coach memory current"
                    : "durable skill snapshot current",
                numerics: [
                    "snapshotInserted": plan.shouldRecordSkillSnapshot ? 1 : 0,
                    "memoryRefreshed": plan.shouldRefreshCoachMemory ? 1 : 0,
                ]
            )
        }
        return plan
    }

    static func skillSnapshot(from session: PracticeSession) -> SkillSnapshot? {
        guard let score = session.score else { return nil }
        let qualifiedFillerRate = FillerBurden.quantityQualified(session)?.ratePerMinute
        let qualifiedPaceWPM = SessionQualifier.quantityQualifiedWordsPerMinute(session)
        let comparisonMetricSchemaVersion: Int? = if qualifiedFillerRate != nil,
                                                     qualifiedPaceWPM != nil {
            session.comparisonMetricSchemaVersion
        } else {
            nil
        }
        let pauseFilledRatio: Double? = if let metrics = session.pauseMetrics,
                                               metrics.count > 0 {
            metrics.filledRatio
        } else {
            nil
        }
        let pitchMonotone = session.pitchMetrics.flatMap { metrics in
            metrics.isReliable ? metrics.monotoneScore : nil
        }
        let wpm = session.duration > 0
            ? Double(session.wordCount) / session.duration * 60
            : 0
        return SkillSnapshot(
            sessionId: session.id,
            date: session.date,
            fillerCount: session.fillerWordCount,
            duration: session.duration,
            wordCount: session.wordCount,
            wpm: wpm,
            qualifiedFillerRatePerMinute: qualifiedFillerRate,
            qualifiedPaceWPM: qualifiedPaceWPM,
            comparisonMetricSchemaVersion: comparisonMetricSchemaVersion,
            score: score,
            categoryRatings: session.categoryRatings,
            pauseRate: pauseRateForTrend(session: session),
            pitchMonotone: pitchMonotone,
            pauseFilledRatio: pauseFilledRatio
        )
    }

    /// Neutral result for a Summary that cannot be tied to an eligible saved
    /// row. Keeping this construction beside the mutation owner ensures the
    /// view can fail closed without manufacturing a second lifecycle path.
    static func withheldResult(
        pressureLevel: PressureLevel = .standard
    ) -> SessionFinalizationResult {
        let profile = ProfileManager.shared
        let currentXP = profile.xp
        let level = ProfileManager.levelTitle(forXP: currentXP)
        return SessionFinalizationResult(
            previousXP: currentXP,
            newXP: currentXP,
            previousLevel: level,
            newLevel: level,
            isLevelUp: false,
            achievementDeltas: [],
            newUnlocks: [],
            milestone: nil,
            isPersonalBest: false,
            showProgressionScreen: false,
            nextAction: nil,
            baselineComparisons: [:],
            pressureLevel: pressureLevel,
            coachNote: nil,
            eloquenceFindings: [],
            eloquenceBonusXP: 0
        )
    }

    /// Pause timing and its denominator come from the same persisted row.
    /// Presentation duration is intentionally not an input, preventing a
    /// mismatched payload from creating a hybrid trend measurement.
    static func pauseRateForTrend(session: PracticeSession) -> Double? {
        guard let metrics = session.pauseMetrics,
              session.duration.isFinite,
              session.duration > 0 else { return nil }
        let rate = Double(metrics.count) / (session.duration / 60.0)
        return rate.isFinite ? rate : nil
    }

    /// Finalize a session: apply XP, evaluate achievements, detect milestones, record trends,
    /// and compute next-action recommendation with baseline-aware coaching.
    /// Call exactly once per session. Modes with a replay-first result screen may
    /// call this when the run ends and pass the resulting value into SummaryView.
    static func finalize(
        xpEarned: Int,
        scoreValue: Int,
        effectiveFillerCount: Int,
        effectiveDuration: TimeInterval,
        transcriptWordCount: Int,
        scoreBreakdown: [PracticeScoreSegment],
        currentMode: PracticeMode,
        sessionPrompt: String?,
        latestSessionID: UUID?,
        recentSessions: [PracticeSession],
        imConversationDetails: IMConversationDetails?,
        practiceTitle: String,
        derivedInsightsFirst: String?,
        pressureLevel: PressureLevel = .standard,
        transcript: String = ""
    ) -> SessionFinalizationResult {
        let profile = ProfileManager.shared
        let sessionStore = PracticeSessionStore.shared
        let coachingProfileStore = CoachingProfileStore.shared
        let notificationManager = NotificationManager.shared

        let previousXP = profile.xp

        // Finalization is an earned-progress boundary, not a presentation
        // fallback. The payload and its exact persisted row must both clear
        // the shared floor before any XP, achievement, reminder, trend, path,
        // or coach-memory mutation can begin. A nil, stale, or unrelated ID
        // therefore fails closed instead of borrowing the newest saved rep.
        guard PracticeProgressEligibility.qualifies(
                  wordCount: transcriptWordCount,
                  duration: effectiveDuration
              ),
              let latestSessionID,
              let finalizedSession = sessionStore.sessions.first(where: { $0.id == latestSessionID }),
              PracticeProgressEligibility.qualifies(finalizedSession) else {
            FlowLog.log(
                correlationId: latestSessionID ?? UUID(),
                flow: .practiceRep,
                stage: "finalize.skipped",
                outcome: .skipped,
                reason: "missing exact eligible saved row — no XP, achievements, trend, path, or coach note",
                numerics: ["words": transcriptWordCount, "durationMs": Int(effectiveDuration * 1000), "score": scoreValue]
            )
            return withheldResult(pressureLevel: pressureLevel)
        }

        // Raw history can contain a transport-valid short capture kept only so
        // Review can explain it. Once the current rep clears the shared floor,
        // every longitudinal/reward input below still uses only progress-
        // eligible history so an older thin row cannot tip a count or verdict.
        let progressSessions = sessionStore.progressEligibleSessions
        let progressRecentSessions = PracticeProgressEligibility.eligibleSessions(
            in: recentSessions
        )

        // Streak ownership: anything the USER reads (streak milestones,
        // achievement progress) uses the freeze-aware displayed streak from
        // StreakFreezeManager — the single displayed-streak owner — so the
        // celebration can never name a number Home/Profile don't show.
        // Recompute explicitly: the session was just appended and the
        // manager's Combine sink fires on a later runloop turn.
        StreakFreezeManager.shared.recompute()
        let displayedStreak = StreakFreezeManager.shared.currentStreak
        // Raw history streak — kept ONLY as a model input (NextAction
        // heuristics), mirroring the baseline-pressure call sites.
        let rawHistoryStreak = PracticeSession.calculateStreak(from: progressSessions)

        // Capture achievement state BEFORE applying session
        let achievementsBefore: [String: (current: Int, target: Int)] = {
            var map: [String: (Int, Int)] = [:]
            for tier in AchievementStore.allTiers {
                map[tier.id] = tier.evaluate(progressRecentSessions, displayedStreak)
            }
            return map
        }()

        // Compute eloquence findings + XP bonus first so we can roll the
        // bonus into the session XP that goes through the rank ladder. The
        // base xpEarned still drives the headline number; the bonus is
        // labelled separately on the summary.
        let preliminaryEloquenceFindings = EloquenceEngine.analyse(transcript: transcript)
        let eloquenceBonus = EloquenceXP.totalXP(for: preliminaryEloquenceFindings)

        let levelBefore = ProfileManager.levelTitle(forXP: profile.xp)
        profile.addXP(xpEarned + eloquenceBonus)
        let levelAfter = ProfileManager.levelTitle(forXP: profile.xp)
        let newXP = profile.xp

        // Re-evaluate achievements after XP (session already recorded by PracticeSessionFinalizer)
        let newlyUnlockedIDs = AchievementStore.shared.evaluate(
            sessions: progressSessions,
            streak: displayedStreak
        )

        // Compute achievement progress deltas
        var deltas: [AchievementProgressDelta] = []
        for tier in AchievementStore.allTiers {
            let before = achievementsBefore[tier.id] ?? (0, 1)
            let (current, target) = tier.evaluate(progressSessions, displayedStreak)
            let prevProgress = target > 0 ? min(1.0, Double(before.0) / Double(target)) : 0
            let newProgress = target > 0 ? min(1.0, Double(current) / Double(target)) : 0
            let delta = newProgress - prevProgress
            if newlyUnlockedIDs.contains(tier.id) || delta >= 0.05 {
                deltas.append(AchievementProgressDelta(
                    id: tier.id,
                    title: tier.title,
                    previousProgress: prevProgress,
                    newProgress: newProgress,
                    progressLabel: "\(current)/\(target)"
                ))
            }
        }
        let sortedDeltas = deltas.sorted { ($0.newProgress >= 1.0 ? 1 : 0) > ($1.newProgress >= 1.0 ? 1 : 0) }
        let newUnlocks = newlyUnlockedIDs.compactMap { AchievementStore.tier(for: $0) }

        // Progression-spine gate (S2): the full-screen interstitial is
        // reserved for real achievement unlocks. Ordinary reps go straight
        // to the verdict — XP credit lands as a quiet caption in the
        // Details drawer instead of pre-empting the coach's read.
        let showProgression = PostRepProgressionGate.shouldShowInterstitial(newUnlockCount: newUnlocks.count)

        var categoryMap: [String: String] = [:]
        for seg in scoreBreakdown {
            categoryMap[seg.title] = seg.value
        }
        // Persist duration-derived evidence only when it can be tied back to
        // the exact saved session and that row clears the historical metric
        // boundary. Skill snapshot persistence itself already happened at the
        // durable session boundary; these values remain Summary-local inputs
        // for its verdict and next-action projection.
        let qualifiedFillerRate = FillerBurden.quantityQualified(finalizedSession)?.ratePerMinute
        let qualifiedPaceWPM = SessionQualifier.quantityQualifiedWordsPerMinute(finalizedSession)
        let comparisonMetricSchemaVersion: Int? = if qualifiedFillerRate != nil,
                                                     qualifiedPaceWPM != nil {
            finalizedSession.comparisonMetricSchemaVersion
        } else {
            nil
        }
        // Schedule follow-up reminder
        Task {
            await notificationManager.scheduleFollowUpReminder(
                profile: coachingProfileStore.profile,
                relationship: imConversationDetails?.relationshipSnapshot,
                sessions: progressSessions,
                practiceTitle: practiceTitle,
                nextMove: derivedInsightsFirst
            )
        }

        // Sync the public-readable subset of the user's stats so peers
        // (friends + league) can see updated rating, streak, and weekly reps.
        // Best-effort: any failure is silent. The local UI is unaffected.
        syncPeerSurfaces(latestSessionID: latestSessionID)

        // First-rep magic — a once-only celebration when the user finishes
        // their very first session. Driven by `FirstRepCelebrationManager`
        // so duplicate triggers across reload/relaunch can't fire twice.
        FirstRepCelebrationManager.shared.consider(
            session: finalizedSession,
            totalSessionCount: progressSessions.count
        )

        // Goal refresh — every 14 days, surface a lightweight "still your
        // goal?" confirmation so coach memory stays current.
        GoalRefreshManager.shared.consider(
            sessionCount: progressSessions.count,
            profile: coachingProfileStore.profile
        )

        // Word of the day (M9) — scan the latest transcript for today's
        // word and flip the home tile to "Used" if the user worked it
        // into their rep naturally.
        WordOfTheDayManager.shared.ensureForToday()
        WordOfTheDayManager.shared.evaluateAgainstTodaysSessions()

        // Notification pre-prompt — soft sell before iOS's hard system
        // dialog. Fires once on session 1, then respects 30-day cooldown
        // on decline.
        NotificationPrePromptManager.shared.consider(
            sessionCount: progressSessions.count
        )

        // Milestone detection
        let skillTrends = TrendAnalyzer.analyze(snapshots: SkillTrendStore.shared.snapshots)

        // Skill-progression level-up detection (M14). Compares the new
        // trend levels against the per-account snapshot from the last
        // session. Any upward crossing (e.g., developing → solid)
        // queues a SkillLevelUpEvent that the summary inline-celebrates.
        // Downward crossings are stored silently — we never punish-shame.
        SkillProgressionStore.shared.record(trends: skillTrends)

        let milestone = detectMilestone(
            levelBefore: levelBefore,
            levelAfter: levelAfter,
            newXP: newXP,
            scoreValue: scoreValue,
            currentMode: currentMode,
            currentStreak: displayedStreak,
            sessions: progressSessions,
            skillTrends: skillTrends
        )

        let isPersonalBest = milestone?.title == "New personal best."
        let isLevelUp = levelBefore != levelAfter

        // --- New systems: baseline, next action, enhanced coach note ---

        // Baseline is already updated by PracticeSessionFinalizer.finalize() before we get here.
        // Read the current state — don't double-update.
        let baselineStore = BaselineStore.shared
        let baseline = baselineStore.baseline
        let wpm = effectiveDuration > 0 ? Double(transcriptWordCount) / effectiveDuration * 60 : 0
        let explicitStyleGoal = ChosenStyleGoalEngineInputs.make(
            profile: coachingProfileStore.profile
        )

        // Baseline comparisons
        let comparisons: [String: String]
        comparisons = BaselineEngine.sessionComparison(session: finalizedSession, baseline: baseline)

        let currentCoachMemory = CoachMemoryStore.shared.currentMemory
        let latestFinalizedSession = finalizedSession
        let currentGoalOutcomeRead = GoalOutcomeEngine.read(
            profile: coachingProfileStore.profile,
            baseline: baseline,
            rating: RatingStore.shared.rating,
            sessions: progressSessions,
            coachMemory: currentCoachMemory,
            outcomes: RecommendationLearningStore.shared.outcomes
        )

        // NextAction recommendation
        let nextAction: NextAction? = {
            let input = NextActionInput(
                fillerCount: effectiveFillerCount,
                duration: effectiveDuration,
                wordCount: transcriptWordCount,
                wpm: wpm,
                score: scoreValue,
                categoryRatings: categoryMap,
                mode: currentMode,
                pressureLevel: pressureLevel,
                baseline: baselineStore.baseline,
                pressureProfile: baselineStore.pressureProfile,
                trends: skillTrends,
                drillHistory: DrillHistoryStore.shared.entries,
                sessionCount: progressSessions.count,
                streakDays: rawHistoryStreak,
                styleGoal: explicitStyleGoal.title,
                transcriptConfidence: latestFinalizedSession.transcriptConfidence,
                modeAvailability: NextActionModeAvailability(
                    rating: RatingStore.shared.rating,
                    imConversationAvailable: IMModeAvailability.isAvailable
                ),
                recommendationOutcomes: RecommendationLearningStore.shared.outcomes,
                coachMemory: currentCoachMemory,
                goalOutcomeRead: currentGoalOutcomeRead,
                latestSessionID: latestSessionID,
                latestSessionQualifies: SessionQualifier.qualifies(latestFinalizedSession)
            )
            return NextActionEngine.recommendAfterSession(input: input)
        }()

        // Enhanced coach note with baseline + style
        let coachNote: CoachNote? = {
            // Same goal-aware bias the drill picker uses — keeps the Coach
            // Note's "leverage" line aligned with the skill the drill is
            // about to train, so the user never reads "structure is your
            // biggest opportunity" while the drill works pace control.
            let primaryFocus = TrendAnalyzer.primaryFocus(
                trends: skillTrends,
                currentSessionSnapshot: SkillSnapshot(
                    sessionId: latestSessionID,
                    fillerCount: effectiveFillerCount,
                    duration: effectiveDuration,
                    wordCount: transcriptWordCount,
                    wpm: wpm,
                    qualifiedFillerRatePerMinute: qualifiedFillerRate,
                    qualifiedPaceWPM: qualifiedPaceWPM,
                    comparisonMetricSchemaVersion: comparisonMetricSchemaVersion,
                    score: scoreValue,
                    categoryRatings: categoryMap
                ),
                recentDrills: DrillHistoryStore.shared.entries,
                styleGoal: explicitStyleGoal.goal
            )
            // Prompt-grounded relevance (initiative #8 follow-on): the SAME
            // read the 7-dimension Relevance rating consumes, threaded into
            // the Timed three-part note so the post-rep coach note shares one
            // "answered vs buried" substance read with the rating + the chat
            // coach. Timed only — the mode whose `sessionPrompt` is a question
            // to answer; nil elsewhere keeps the note byte-identical for IM /
            // Sudden Death / Ah-Counter.
            let promptRelevanceRead: PracticeEvaluator.PromptRelevanceRead? =
                currentMode == .timed
                ? PracticeEvaluator.promptRelevance(prompt: sessionPrompt, transcript: transcript)
                : nil
            return VerdictEngine.generate(
                fillerCount: effectiveFillerCount,
                duration: effectiveDuration,
                wordCount: transcriptWordCount,
                wpm: wpm,
                score: latestFinalizedSession.score,
                categoryRatings: categoryMap,
                trends: skillTrends,
                primaryFocus: primaryFocus,
                drillHistory: DrillHistoryStore.shared.entries,
                baseline: baselineStore.baseline,
                pressureProfile: baselineStore.pressureProfile,
                pressureLevel: pressureLevel,
                styleGoal: explicitStyleGoal.title,
                promptRelevance: promptRelevanceRead,
                metricSession: latestFinalizedSession
            )
        }()

        // Rhetorical devices on the transcript — positive coaching surface.
        // Conservative thresholds inside the engine keep false positives down.
        // Reuse the findings already computed earlier for the XP bonus —
        // running the analyser twice would be wasteful and could (in
        // theory) drift if the engine grew side effects.
        let eloquenceFindings = preliminaryEloquenceFindings

        FlowLog.log(
            correlationId: latestSessionID,
            flow: .practiceRep,
            stage: "finalize.applied",
            reason: newUnlocks.isEmpty ? "progress applied" : "progress applied + \(newUnlocks.count) achievement(s) unlocked",
            numerics: [
                "score": scoreValue,
                "xpEarned": max(0, newXP - previousXP),
                "unlocks": newUnlocks.count,
                "words": transcriptWordCount,
            ]
        )

        return SessionFinalizationResult(
            previousXP: previousXP,
            newXP: newXP,
            previousLevel: levelBefore,
            newLevel: levelAfter,
            isLevelUp: isLevelUp,
            achievementDeltas: sortedDeltas,
            newUnlocks: newUnlocks,
            milestone: milestone,
            isPersonalBest: isPersonalBest,
            showProgressionScreen: showProgression,
            nextAction: nextAction,
            baselineComparisons: comparisons,
            pressureLevel: pressureLevel,
            coachNote: coachNote,
            eloquenceFindings: eloquenceFindings,
            eloquenceBonusXP: eloquenceBonus
        )
    }

    // MARK: - Peer surface sync

    /// Upload only when the server-side evidence/friend producers are enabled.
    /// Release-disabled social capabilities do not create one predictable
    /// failure per rep. Captured manager generations silently discard any
    /// response that returns after an account transition.
    private static func syncPeerSurfaces(latestSessionID: UUID?) {
        let shouldSyncPeerProgress = SocialReleaseCapabilities.peerProgress.isAvailable
        let shouldSubmitSpeakOff = SocialReleaseCapabilities.speakOffs.isAvailable
        guard shouldSyncPeerProgress || shouldSubmitSpeakOff else { return }
        guard let latestSessionID,
              let session = PracticeSessionStore.shared.sessions.first(where: { $0.id == latestSessionID }) else {
            return
        }
        let leagueContext = shouldSyncPeerProgress
            ? LeagueManager.shared.captureSocialOperationContext()
            : nil
        let providerRawValue = AuthManager.shared.currentAuthProviderRawValue
        let displayName = AuthManager.shared.currentAccountName ?? "Speaker"
        Task {
            if let context = leagueContext, let providerRawValue {
                do {
                    let result = try await BackendSyncManager.shared.recordPeerSession(
                        session: session,
                        accountID: context.accountID,
                        providerRawValue: providerRawValue,
                        displayName: displayName
                    )
                    guard LeagueManager.shared.isSocialOperationContextCurrent(context) else {
                        return
                    }
                    LeagueManager.shared.reconcileAuthoritativeProfile(
                        result.profile,
                        context: context
                    )
                } catch {
                    guard LeagueManager.shared.isSocialOperationContextCurrent(context) else {
                        return
                    }
                    let authorityError = error as? SocialAuthorityError
                    LeagueManager.shared.recordPeerSyncFailure(
                        sessionID: latestSessionID,
                        message: error.localizedDescription,
                        isRetryable: authorityError?.isRetryable ?? true,
                        context: context
                    )
                }
            }
            if shouldSubmitSpeakOff {
                await ChallengesManager.shared.submitArmedResultIfMatching(
                    sessionID: latestSessionID
                )
            }
        }
    }

    // MARK: - Milestone Detection

    private static func detectMilestone(
        levelBefore: String,
        levelAfter: String,
        newXP: Int,
        scoreValue: Int,
        currentMode: PracticeMode,
        currentStreak: Int,
        sessions: [PracticeSession],
        skillTrends: [SkillTrend]
    ) -> MilestoneEvent? {
        // 1. Level-up (highest priority — gets full-screen celebration)
        if levelBefore != levelAfter {
            // NOTE: the title "Level up." is a string-equality routing ID
            // consumed by SummaryView's milestone routing — it must stay
            // byte-identical. Subtitle/detail re-narrate XP as practice
            // VOLUME (ProgressionSpineNarration), never a skill rank.
            return MilestoneEvent(
                icon: "arrow.up.circle.fill",
                tint: .blue,
                title: "Level up.",
                subtitle: PracticeVolumeNarration.title(forXP: newXP),
                detail: PracticeVolumeNarration.levelUpDetail(forXP: newXP)
            )
        }

        // 2. Personal best score (across all sessions in the same mode)
        let pastScores = sessions
            .filter { $0.mode == currentMode }
            .dropFirst() // exclude the session we just saved
            .compactMap(\.score)
        let previousBest = pastScores.max() ?? 0
        if scoreValue > previousBest && scoreValue >= 6 && !pastScores.isEmpty {
            return MilestoneEvent(
                icon: "star.fill",
                tint: .orange,
                title: "New personal best.",
                subtitle: "\(scoreValue)/10 in \(currentMode.displayLabel)",
                detail: previousBest > 0 ? "Previous best: \(previousBest)/10" : nil
            )
        }

        // 3. Streak milestones (3, 7, 14, 30 days)
        if [3, 7, 14, 30].contains(currentStreak) {
            let copy = MilestoneCopy.streakMilestone(currentStreak)
            return MilestoneEvent(
                icon: "flame.fill",
                tint: .orange,
                title: copy.title,
                subtitle: copy.subtitle,
                detail: copy.detail
            )
        }

        // 4. Session count milestones (10, 25, 50, 100)
        let count = sessions.count
        if [10, 25, 50, 100].contains(count) {
            let copy = MilestoneCopy.sessionCount(count)
            return MilestoneEvent(
                icon: "number.circle.fill",
                tint: .blue,
                title: copy.title,
                subtitle: copy.subtitle,
                detail: copy.detail
            )
        }

        // 5. Skill resolved (a previously problematic skill is now resolved)
        if let resolved = skillTrends.first(where: { $0.direction == .resolved }) {
            let copy = MilestoneCopy.skillResolved(resolved.skillArea)
            return MilestoneEvent(
                icon: "checkmark.seal.fill",
                tint: AppColor.positive,
                title: copy.title,
                subtitle: copy.subtitle,
                detail: copy.detail
            )
        }

        return nil
    }
}

#endif
