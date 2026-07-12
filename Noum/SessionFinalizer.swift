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

// MARK: - Session Finalizer

/// Extracts lifecycle logic into a single service shared by completion and summary flows.
/// Handles XP application, achievement evaluation, milestone detection, and trend recording.
@MainActor
enum SessionFinalizer {

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

        // Evidence floor: a rep too short to read (accidental instant-stop,
        // empty transcript) must not manufacture progress. Below the floor we
        // award no XP, unlock no achievements, record no skill-trend snapshot,
        // advance no path, and generate no coach note — the summary shows a
        // neutral "too short" state instead. Threshold matches the evaluator's
        // own score-floor boundary (PracticeEvaluator, wordCount/duration < 3)
        // so no rep that already scored normally is affected.
        if transcriptWordCount < 3 || effectiveDuration < 3 {
            FlowLog.log(
                correlationId: latestSessionID ?? UUID(),
                flow: .practiceRep,
                stage: "finalize.skipped",
                outcome: .skipped,
                reason: "below evidence floor — no XP, achievements, trend, path, or coach note",
                numerics: ["words": transcriptWordCount, "durationMs": Int(effectiveDuration * 1000), "score": scoreValue]
            )
            let level = ProfileManager.levelTitle(forXP: profile.xp)
            return SessionFinalizationResult(
                previousXP: previousXP,
                newXP: previousXP,
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
        let rawHistoryStreak = PracticeSession.calculateStreak(from: sessionStore.sessions)

        // Capture achievement state BEFORE applying session
        let achievementsBefore: [String: (current: Int, target: Int)] = {
            var map: [String: (Int, Int)] = [:]
            for tier in AchievementStore.allTiers {
                map[tier.id] = tier.evaluate(recentSessions, displayedStreak)
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
            sessions: sessionStore.sessions,
            streak: displayedStreak
        )

        // Compute achievement progress deltas
        var deltas: [AchievementProgressDelta] = []
        for tier in AchievementStore.allTiers {
            let before = achievementsBefore[tier.id] ?? (0, 1)
            let (current, target) = tier.evaluate(sessionStore.sessions, displayedStreak)
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

        // Record skill snapshot for trend analysis
        var categoryMap: [String: String] = [:]
        for seg in scoreBreakdown {
            categoryMap[seg.title] = seg.value
        }
        // Pull pause-rate from the freshly-finalized session so the trend
        // analyzer can pick up pause progress without re-tokenising the
        // transcript. nil for sessions whose provider didn't emit timings.
        let pauseRate: Double? = {
            guard let metrics = sessionStore.sessions.first?.pauseMetrics,
                  effectiveDuration > 0 else { return nil }
            return Double(metrics.count) / (effectiveDuration / 60.0)
        }()
        // Pull pitch monotone score for the trend analyzer — only when the
        // PitchAnalyzer reading was reliable (≥10 voiced windows, mean inside
        // 70–400Hz). Hides M10's noisy reads from the trend pill.
        let pitchMonotone: Double? = {
            guard let metrics = sessionStore.sessions.first?.pitchMetrics,
                  metrics.isReliable else { return nil }
            return metrics.monotoneScore
        }()
        // Pull the filled-pause ratio so calmer-delivery users get a real
        // week-over-week reading on the profile goal-progress ring. Only
        // emit when the session actually contained pauses — a zero-pause
        // rep would falsely look like "perfect calmness" (filledRatio = 0
        // by definition when count = 0).
        let pauseFilledRatio: Double? = {
            guard let metrics = sessionStore.sessions.first?.pauseMetrics,
                  metrics.count > 0 else { return nil }
            return metrics.filledRatio
        }()
        SkillTrendStore.shared.recordFromSession(
            sessionId: latestSessionID ?? UUID(),
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            wordCount: transcriptWordCount,
            score: scoreValue,
            categoryRatings: categoryMap,
            pauseRate: pauseRate,
            pitchMonotone: pitchMonotone,
            pauseFilledRatio: pauseFilledRatio
        )

        // Schedule follow-up reminder
        Task {
            await notificationManager.scheduleFollowUpReminder(
                profile: coachingProfileStore.profile,
                relationship: imConversationDetails?.relationshipSnapshot,
                sessions: sessionStore.sessions,
                practiceTitle: practiceTitle,
                nextMove: derivedInsightsFirst
            )
        }

        // Sync the public-readable subset of the user's stats so peers
        // (friends + league) can see updated rating, streak, and weekly reps.
        // Best-effort: any failure is silent. The local UI is unaffected.
        syncPeerSurfaces(latestSessionID: latestSessionID)

        // M3: surface the path node celebration if this session unlocked one.
        PathProgressManager.shared.evaluateAfterSession()

        // First-rep magic — a once-only celebration when the user finishes
        // their very first session. Driven by `FirstRepCelebrationManager`
        // so duplicate triggers across reload/relaunch can't fire twice.
        if let latestSession = sessionStore.sessions.first {
            FirstRepCelebrationManager.shared.consider(
                session: latestSession,
                totalSessionCount: sessionStore.sessions.count
            )
        }

        // Deferred profile capture — fire the goal / why-now / success
        // prompts after the user has done a rep, not during onboarding.
        DeferredProfileCaptureManager.shared.consider(
            sessionCount: sessionStore.sessions.count,
            profile: coachingProfileStore.profile
        )

        // Goal refresh — every 14 days, surface a lightweight "still your
        // goal?" confirmation so coach memory stays current.
        GoalRefreshManager.shared.consider(
            sessionCount: sessionStore.sessions.count,
            profile: coachingProfileStore.profile
        )

        // Daily challenges (M8) — re-evaluate the day's three challenges
        // against the latest session so any newly-satisfied ones flip to
        // "ready to claim" on the home tile. Manager also auto-rolls the
        // day at midnight, so this doubles as the daily refresh trigger.
        DailyChallengesManager.shared.ensureForToday()
        DailyChallengesManager.shared.recomputeReady()

        // Word of the day (M9) — scan the latest transcript for today's
        // word and flip the home tile to "Used" if the user worked it
        // into their rep naturally.
        WordOfTheDayManager.shared.ensureForToday()
        WordOfTheDayManager.shared.evaluateAgainstTodaysSessions()

        // Notification pre-prompt — soft sell before iOS's hard system
        // dialog. Fires once on session 1, then respects 30-day cooldown
        // on decline.
        NotificationPrePromptManager.shared.consider(
            sessionCount: sessionStore.sessions.count
        )

        // Milestone detection
        let skillTrends = TrendAnalyzer.analyze(snapshots: SkillTrendStore.shared.snapshots)

        // Skill-progression level-up detection (M14). Compares the new
        // trend levels against the per-account snapshot from the last
        // session. Any upward crossing (e.g., developing → solid)
        // queues a SkillLevelUpEvent that the summary inline-celebrates.
        // Downward crossings are stored silently — we never punish-shame.
        SkillProgressionStore.shared.record(trends: skillTrends)

        // Persistent coach memory — the durable working read that Ask Noum
        // carries between conversations. Updated after trend recording so
        // the stored formulation can notice focus shifts from the latest rep.
        CoachMemoryStore.shared.refresh(
            profile: coachingProfileStore.profile,
            baseline: BaselineStore.shared.baseline,
            sessions: sessionStore.sessions,
            trends: skillTrends,
            forwardPlan: ForwardPlanStore.shared.activePlan,
            lastSessionID: latestSessionID,
            pendingIntervention: RecommendationLearningStore.shared.pendingExposure,
            recommendationOutcomes: RecommendationLearningStore.shared.outcomes,
            latestReflection: SessionReflectionStore.shared.latest,
            reflectionHistory: SessionReflectionStore.shared.history,
            latestTransferReport: BigMomentStore.shared.recentOutcomeReports(limit: 1).first,
            upcomingMoment: BigMomentStore.shared.activeMoment
        )
        _ = UserTrajectoryCache.shared.invalidateAndWarmFromCurrentStores()

        let milestone = detectMilestone(
            levelBefore: levelBefore,
            levelAfter: levelAfter,
            newXP: newXP,
            scoreValue: scoreValue,
            currentMode: currentMode,
            currentStreak: displayedStreak,
            sessions: sessionStore.sessions,
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

        // Baseline comparisons
        let comparisons: [String: String]
        if let latestSession = sessionStore.sessions.first {
            comparisons = BaselineEngine.sessionComparison(session: latestSession, baseline: baseline)
        } else {
            comparisons = [:]
        }

        // NextAction recommendation
        let nextAction: NextAction? = {
            guard baseline.qualifyingSessionCount >= 2 else { return nil }
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
                sessionCount: sessionStore.sessions.count,
                streakDays: rawHistoryStreak,
                styleGoal: coachingProfileStore.profile?.speakingStyleGoal.title,
                recommendationOutcomes: RecommendationLearningStore.shared.outcomes
            )
            let action = NextActionEngine.recommend(input: input)
            LastNextActionSnapshot.save(action)
            return action
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
                    sessionId: latestSessionID ?? UUID(),
                    fillerCount: effectiveFillerCount,
                    duration: effectiveDuration,
                    wordCount: transcriptWordCount,
                    wpm: wpm,
                    score: scoreValue,
                    categoryRatings: categoryMap
                ),
                recentDrills: DrillHistoryStore.shared.entries,
                styleGoal: coachingProfileStore.profile?.speakingStyleGoal
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
                score: scoreValue,
                categoryRatings: categoryMap,
                trends: skillTrends,
                primaryFocus: primaryFocus,
                drillHistory: DrillHistoryStore.shared.entries,
                baseline: baselineStore.baseline,
                pressureProfile: baselineStore.pressureProfile,
                pressureLevel: pressureLevel,
                styleGoal: coachingProfileStore.profile?.speakingStyleGoal.title,
                promptRelevance: promptRelevanceRead
            )
        }()

        // Rhetorical devices on the transcript — positive coaching surface.
        // Conservative thresholds inside the engine keep false positives down.
        // Reuse the findings already computed earlier for the XP bonus —
        // running the analyser twice would be wasteful and could (in
        // theory) drift if the engine grew side effects.
        let eloquenceFindings = preliminaryEloquenceFindings

        FlowLog.log(
            correlationId: latestSessionID ?? UUID(),
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
