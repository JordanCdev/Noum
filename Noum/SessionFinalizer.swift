import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Session Finalization Result

/// All computed state from finalizing a post-session view.
/// Produced once by `SessionFinalizer.finalize()`, consumed by SummaryView to drive display.
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

/// Extracts the lifecycle logic from SummaryView's `setup()` into a testable service.
/// Handles XP application, achievement evaluation, milestone detection, and trend recording.
@MainActor
enum SessionFinalizer {

    /// Finalize a session: apply XP, evaluate achievements, detect milestones, record trends,
    /// and compute next-action recommendation with baseline-aware coaching.
    /// Call once from SummaryView's `onAppear`.
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
        let currentStreak = PracticeSession.calculateStreak(from: sessionStore.sessions)

        // Capture achievement state BEFORE applying session
        let achievementsBefore: [String: (current: Int, target: Int)] = {
            var map: [String: (Int, Int)] = [:]
            for tier in AchievementStore.allTiers {
                map[tier.id] = tier.evaluate(recentSessions, currentStreak)
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
            streak: currentStreak
        )

        // Compute achievement progress deltas
        var deltas: [AchievementProgressDelta] = []
        for tier in AchievementStore.allTiers {
            let before = achievementsBefore[tier.id] ?? (0, 1)
            let (current, target) = tier.evaluate(sessionStore.sessions, currentStreak)
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

        let showProgression = xpEarned > 0 || !sortedDeltas.isEmpty

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
        syncPeerSurfaces()

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
            latestReflection: SessionReflectionStore.shared.latest
        )

        let milestone = detectMilestone(
            levelBefore: levelBefore,
            levelAfter: levelAfter,
            scoreValue: scoreValue,
            currentMode: currentMode,
            currentStreak: currentStreak,
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
                streakDays: currentStreak,
                styleGoal: coachingProfileStore.profile?.speakingStyleGoal.title
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
                styleGoal: coachingProfileStore.profile?.speakingStyleGoal.title
            )
        }()

        // Rhetorical devices on the transcript — positive coaching surface.
        // Conservative thresholds inside the engine keep false positives down.
        // Reuse the findings already computed earlier for the XP bonus —
        // running the analyser twice would be wasteful and could (in
        // theory) drift if the engine grew side effects.
        let eloquenceFindings = preliminaryEloquenceFindings

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

    /// Push the user's public-readable snapshot to `profiles_public/{id}`
    /// and to the current league bucket. Called once after a session is
    /// fully recorded so rating, streak, and weekly reps reflect the new
    /// state. Fire-and-forget on a detached task.
    private static func syncPeerSurfaces() {
        guard let accountID = AuthManager.shared.currentAccountID else { return }
        let displayName = AuthManager.shared.currentAccountName ?? "Speaker"
        let snapshot = PublicProfileBuilder.build(accountID: accountID, displayName: displayName)
        Task {
            await BackendSyncManager.shared.syncPublicProfile(snapshot)
            await LeagueManager.shared.syncSelf(snapshot: snapshot)
        }
    }

    // MARK: - Milestone Detection

    private static func detectMilestone(
        levelBefore: String,
        levelAfter: String,
        scoreValue: Int,
        currentMode: PracticeMode,
        currentStreak: Int,
        sessions: [PracticeSession],
        skillTrends: [SkillTrend]
    ) -> MilestoneEvent? {
        // 1. Level-up (highest priority — gets full-screen celebration)
        if levelBefore != levelAfter {
            return MilestoneEvent(
                icon: "arrow.up.circle.fill",
                tint: .blue,
                title: "Level up.",
                subtitle: levelAfter,
                detail: "Keep practicing to reach the next rank."
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

        // 6. First session ever
        if sessions.count == 1 {
            return MilestoneEvent(
                icon: "sparkles",
                tint: .blue,
                title: "First rep on the books.",
                subtitle: "Your speaking journey starts here.",
                detail: "The app learns your patterns over time — it gets smarter the more you use it."
            )
        }

        return nil
    }
}

#endif
