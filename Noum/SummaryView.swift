import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)
import SwiftUI

// MARK: - SummaryView (Redesigned)

struct SummaryView: View {
    let transcript: AttributedString
    let fillerCount: Int
    let duration: TimeInterval
    let score: Int?
    let progressSegments: Int
    let xpEarned: Int
    var showDuration: Bool = true
    var practiceTitle: String = "Practice Summary"
    var feedbackOverride: String?
    var headlineOverride: String?
    var scoreBreakdown: [PracticeScoreSegment] = []
    var insights: [String] = []
    var recentSessions: [PracticeSession] = []
    var imConversationDetails: IMConversationDetails? = nil
    var explicitMode: PracticeMode? = nil
    var recordingURL: URL? = nil
    var sessionPrompt: String? = nil
    var sessionTheme: PromptTheme? = nil
    var feedbackCategories: [FeedbackCategory] = []
    var strongMoments: [String] = []
    var weakMoments: [String] = []
    var durationAssessment: DurationAssessment = .onTarget
    var targetRange: (min: Double, target: Double, max: Double) = (30, 60, 120)
    var onSelectPracticeMode: () -> Void = {}
    var onHome: () -> Void = {}
    var onPracticeAgain: () -> Void = {}
    var onStartDrill: ((DrillRecommendation) -> Void)?

    @StateObject private var profile = ProfileManager.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var premium = PremiumManager.shared
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @State private var showPaywall = false
    @State private var displayedXP: Int = 0
    @State private var progress: Double = 0
    @State private var currentLevel: String = ""
    @State private var nextLevel: String = ""
    @State private var xpToNext: Int = 0
    @State private var visibleSegments = 0
    @State private var didApplyXP = false
    @State private var aiFeedback: AICoachFeedback?
    @State private var isRequestingAIFeedback = false
    @State private var aiError: String?
    @State private var showVideoPlayback = false
    @State private var celebrationVisible = false
    @State private var lockedTranscriptText: String?
    @State private var lockedFillerCount: Int?
    @State private var lockedDuration: TimeInterval?
    @State private var lockedScore: Int?
    @State private var lockedFeedbackOverride: String?
    @State private var lockedHeadlineOverride: String?
    @State private var lockedScoreBreakdown: [PracticeScoreSegment] = []
    @State private var lockedInsights: [String] = []
    @State private var showShareSheet = false
    @State private var showShareMenu = false
    @State private var showFeedbackRequestSheet = false
    @State private var feedbackRequestURL: URL?
    @State private var videoAnalysisResult: VideoAnalysisResult?
    @State private var isAnalyzingVideo = false
    @State private var activeMilestone: MilestoneEvent?
    @State private var personalBestMilestone: MilestoneEvent?
    @State private var showPersonalBestScreen = false
    @State private var showLevelUpScreen = false
    @State private var levelUpPreviousLevel: String = ""
    @State private var levelUpNewLevel: String = ""
    @State private var activeMiniDrill: DrillRecommendationV2?
    @State private var miniDrillOutcome: MiniDrillOutcome?
    @State private var miniDrillAwardedXP: Int = 0
    @State private var miniDrillXPBreakdown: DrillXPEngine.Breakdown?
    @State private var showSecondaryDetails = false
    @State private var nextAction: NextAction?
    @State private var coachNoteRevealed = false
    @State private var enhancedCoachNote: CoachNote?
    @State private var eloquenceFindings: [EloquenceFinding] = []
    @State private var showAIDisclosure = false
    @State private var showProgressionScreen = false
    @State private var progressionDeltas: [AchievementProgressDelta] = []
    @State private var progressionNewUnlocks: [AchievementTier] = []
    @State private var progressionPreviousXP: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let aiCoachService: AICoachServicing = AICoachService()

    // MARK: - Computed Properties

    private var transcriptText: String {
        lockedTranscriptText ?? String(transcript.characters)
    }

    private var transcriptWordCount: Int {
        transcriptText.split { !$0.isLetter && !$0.isNumber }.count
    }

    private var effectiveFillerCount: Int { lockedFillerCount ?? fillerCount }
    private var effectiveDuration: TimeInterval { lockedDuration ?? duration }

    private var effectiveScoreBreakdown: [PracticeScoreSegment] {
        lockedScoreBreakdown.isEmpty ? scoreBreakdown : lockedScoreBreakdown
    }

    private var currentMode: PracticeMode {
        if let explicitMode { return explicitMode }
        if imConversationDetails != nil { return .imConversation }
        let title = practiceTitle.lowercased()
        if title.contains("sudden") { return .suddenDeath }
        if title.contains("ah-counter") || title.contains("ah counter") { return .ahCounter }
        return .timed
    }

    private var isIMSummary: Bool { currentMode == .imConversation }

    private var currentStreak: Int {
        PracticeSession.calculateStreak(from: sessionStore.sessions)
    }

    private var scoreValue: Int {
        if let lockedScore { return lockedScore }
        if let score { return score }
        // No words spoken at all = 0
        if transcriptWordCount == 0 { return 0 }
        if effectiveDuration < 4 || transcriptWordCount < 4 { return 1 }
        if effectiveDuration < 8 || transcriptWordCount < 8 { return max(2, 5 - effectiveFillerCount) }
        return max(3, min(8, 7 - effectiveFillerCount))
    }

    /// True when the user barely said anything — don't give credit for zero fillers etc.
    private var isMinimalEffort: Bool {
        transcriptWordCount < 5 || effectiveDuration < 5
    }

    /// The single "Next Rep" drill recommendation for this session (legacy v1).
    private var drillRecommendation: DrillRecommendation {
        DrillEngine.recommend(
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            wordCount: transcriptWordCount,
            score: scoreValue,
            feedbackCategories: feedbackCategories,
            durationAssessment: durationAssessment
        )
    }

    // MARK: - v2 Drill System

    /// The v2 drill recommendation using trend intelligence and drill catalog.
    private var drillRecommendationV2: DrillRecommendationV2 {
        let categoryTuples = feedbackCategories.map { ($0.dimension, $0.rating.rawValue) }
        return DrillEngineV2.recommend(
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            wordCount: transcriptWordCount,
            score: scoreValue,
            feedbackCategories: categoryTuples
        )
    }

    /// Skill trends across recent sessions.
    private var skillTrends: [SkillTrend] {
        TrendAnalyzer.analyze(snapshots: SkillTrendStore.shared.snapshots)
    }

    /// Three-part coach note: momentum, leverage, next step.
    /// Prefers the enhanced version from SessionFinalizer (baseline + pressure + style aware),
    /// falls back to simple computation before setup() has run.
    private var coachNote: CoachNote {
        if let enhancedCoachNote { return enhancedCoachNote }
        let wpm = effectiveDuration > 0 ? Double(transcriptWordCount) / effectiveDuration * 60 : 0
        let categoryRatings = Dictionary(uniqueKeysWithValues: feedbackCategories.map { ($0.dimension, $0.rating.rawValue) })
        return VerdictEngine.generate(
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            wordCount: transcriptWordCount,
            wpm: wpm,
            score: scoreValue,
            categoryRatings: categoryRatings,
            trends: skillTrends,
            primaryFocus: drillRecommendationV2.skillArea,
            drillHistory: DrillHistoryStore.shared.entries
        )
    }

    private var headline: String {
        if let lockedHeadlineOverride { return lockedHeadlineOverride }
        if let headlineOverride { return headlineOverride }
        if transcriptWordCount == 0 { return "No response detected" }
        if isMinimalEffort { return "Just getting started" }
        switch scoreValue {
        case 9...10: return "Strong delivery"
        case 7...8: return "Good control"
        case 4...6: return "Building momentum"
        default: return "Room to grow"
        }
    }

    private var verdict: String {
        if let lockedFeedbackOverride { return lockedFeedbackOverride }
        if let feedbackOverride { return feedbackOverride }
        if transcriptWordCount == 0 {
            return "No words were captured. Make sure your microphone is working and try speaking clearly. Tap Retry to give it another go."
        }
        if effectiveDuration < 4 || transcriptWordCount < 4 {
            return "That was barely a start. Hit Retry and commit to at least 15 seconds — even a rough answer counts more than silence."
        }
        if effectiveDuration < 8 || transcriptWordCount < 8 {
            return "Brief answer — try pushing past the opening sentence next time. Even 10 more seconds makes a difference."
        }
        switch scoreValue {
        case 8...10: return "A convincing rep. Keep that same control while raising the difficulty."
        case 6...7: return "There is a solid response in here. One stronger opening sentence would make it feel more complete."
        case 4...5: return "The idea started to form, but it needs more structure and follow-through."
        default: return "Every rep builds the habit. Go again and focus on one strong opening sentence."
        }
    }

    private var scoreAccent: Color {
        switch scoreValue {
        case 8...10: return AppColor.positive
        case 5...7: return AppColor.caution
        default: return AppColor.warning
        }
    }

    private var scoreEmoji: String {
        switch scoreValue {
        case 9...10: return "flame.fill"
        case 7...8: return "hand.thumbsup.fill"
        case 4...6: return "arrow.up.right"
        default: return "arrow.clockwise"
        }
    }

    private var recentWindow: [PracticeSession] {
        Array(sessionStore.sessions.prefix(5))
    }

    private var strongestMode: PracticeMode? {
        CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)?.strongestMode
    }

    private var summaryRecommendation: RecommendationBiasBlueprint {
        RecommendationBiasEngine.blueprint(
            profile: coachingProfileStore.profile,
            input: AIHomeRecommendationInput(
                recentSessionSummary: recentWindowSummary,
                averageFillers: averageFillers,
                averageDuration: averageDuration,
                averageWordsPerMinute: averagePace,
                fillerTrendDelta: 0,
                durationTrendDelta: 0,
                paceTrendDelta: 0,
                averageWordCount: averageWordCount,
                strongestMode: strongestMode,
                currentIdentity: currentIdentity.identity,
                currentIdentityEvidence: currentIdentity.evidence,
                styleAlignmentScore: 0,
                sessionStreak: sessionStreak,
                daysSinceLastSession: daysSinceLastSession,
                preferredModeBias: "",
                preferredToneBias: "",
                preferredScenarioBias: "",
                modeBenefitBias: ""
            ),
            plan: CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)
        )
    }

    private var retentionSnapshot: RetentionLoopSnapshot {
        RetentionLoopEngine.snapshot(
            sessions: sessionStore.sessions,
            profile: coachingProfileStore.profile
        )
    }

    private var recentWindowSummary: String {
        guard !recentWindow.isEmpty else { return "No recent sessions yet." }
        return recentWindow.map { session in
            let label: String
            switch session.mode {
            case .timed: label = "Timed"
            case .suddenDeath: label = "Sudden Death"
            case .ahCounter: label = "Ah-Counter"
            case .imConversation: label = "IM"
            }
            return "\(label): \(session.fillerWordCount) fillers, \(Int(session.duration))s"
        }.joined(separator: " • ")
    }

    private var averageFillers: Double {
        guard !recentWindow.isEmpty else { return 0 }
        return Double(recentWindow.map(\.fillerWordCount).reduce(0, +)) / Double(recentWindow.count)
    }

    private var averageDuration: Double {
        guard !recentWindow.isEmpty else { return 0 }
        return recentWindow.map(\.duration).reduce(0, +) / Double(recentWindow.count)
    }

    private var averagePace: Double {
        guard !recentWindow.isEmpty else { return 0 }
        return Double(recentWindow.map(\.wordsPerMinute).reduce(0, +)) / Double(recentWindow.count)
    }

    private var averageWordCount: Double {
        guard !recentWindow.isEmpty else { return 0 }
        return Double(recentWindow.map(\.wordCount).reduce(0, +)) / Double(recentWindow.count)
    }

    private var daysSinceLastSession: Int {
        guard let last = sessionStore.sessions.first?.date else { return 99 }
        return Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: last), to: Calendar.current.startOfDay(for: Date())).day ?? 0
    }

    private var sessionStreak: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(sessionStore.sessions.map { calendar.startOfDay(for: $0.date) })
        guard !uniqueDays.isEmpty else { return 0 }
        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        while uniqueDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }

    private var currentIdentity: SpeakingIdentitySnapshot {
        PracticeEvaluator.speakingIdentity(for: transcriptText, profile: coachingProfileStore.profile)
    }

    private var latestSessionID: UUID? {
        recentSessions.first?.id ?? sessionStore.sessions.first?.id
    }

    private var derivedInsights: [String] {
        if !lockedInsights.isEmpty { return lockedInsights }
        if !insights.isEmpty { return insights }
        let previousSessions = Array(recentSessions.dropFirst())
        guard !previousSessions.isEmpty else {
            return ["First rep complete — your baseline is set. From here, every session gives you something to compare against."]
        }
        let averageDuration = previousSessions.map(\.duration).reduce(0, +) / Double(previousSessions.count)
        let averageFillers = previousSessions.map(\.fillerWordCount).reduce(0, +) / previousSessions.count
        var messages: [String] = []
        if duration > averageDuration {
            messages.append("You stayed with this answer longer than your recent average.")
        } else {
            messages.append("This answer ended sooner than your recent average, so push the middle section further next time.")
        }
        if fillerCount < averageFillers {
            messages.append("Your filler count improved against your recent baseline.")
        } else if fillerCount > averageFillers {
            messages.append("Filler words rose above your recent baseline. Try a slower opening.")
        }
        messages.append("You now have \(recentSessions.count) saved practice session\(recentSessions.count == 1 ? "" : "s") to compare against.")
        return Array(messages.prefix(3))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            if showProgressionScreen {
                // Post-session progression: XP, achievement progress, unlock celebrations
                PostSessionProgressionView(
                    xpEarned: xpEarned,
                    previousXP: progressionPreviousXP,
                    newXP: profile.xp,
                    previousLevel: currentLevel,
                    newLevel: ProfileManager.levelTitle(forXP: profile.xp),
                    achievementProgress: progressionDeltas,
                    newUnlocks: progressionNewUnlocks,
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showProgressionScreen = false
                            // Chain: level-up → personal best → summary
                            if levelUpPreviousLevel != levelUpNewLevel && !levelUpNewLevel.isEmpty {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        showLevelUpScreen = true
                                    }
                                }
                            } else if personalBestMilestone != nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        showPersonalBestScreen = true
                                    }
                                }
                            }
                        }
                    }
                )
                .transition(.opacity)
            } else if showLevelUpScreen {
                // Full-screen level up celebration
                LevelUpCelebrationScreen(
                    newLevel: levelUpNewLevel,
                    previousLevel: levelUpPreviousLevel,
                    xpProgress: progress,
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            showLevelUpScreen = false
                            // Chain to personal best if needed
                            if personalBestMilestone != nil {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        showPersonalBestScreen = true
                                    }
                                }
                            }
                        }
                    }
                )
                .transition(.opacity)
            } else if showPersonalBestScreen, let milestone = personalBestMilestone {
                // Full-screen personal best celebration (intermediary before summary)
                personalBestCelebration(milestone: milestone)
                    .transition(.opacity)
            } else {
                // Normal summary content — redesigned hierarchy
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        if isIMSummary {
                            // IM MODE — conversation-first hierarchy
                            IMVerdictCard(
                                scoreValue: scoreValue,
                                scoreAccent: scoreAccent,
                                scoreEmoji: scoreEmoji,
                                headline: headline,
                                effectiveFillerCount: effectiveFillerCount,
                                effectiveDuration: effectiveDuration,
                                xpEarned: xpEarned,
                                imConversationDetails: imConversationDetails
                            )
                            IMReadCard(
                                coachNote: coachNote,
                                effectiveDuration: effectiveDuration,
                                imConversationDetails: imConversationDetails
                            )
                            IMOneMoveCard(
                                coachNote: coachNote,
                                onPracticeAgain: onPracticeAgain,
                                onSelectPracticeMode: onSelectPracticeMode
                            )
                            if let details = imConversationDetails {
                                IMSignalsCard(details: details)
                            }
                            BaselineComparisonCard(
                                baseline: baselineStore.baseline,
                                transcriptText: transcriptText,
                                effectiveFillerCount: effectiveFillerCount,
                                effectiveDuration: effectiveDuration,
                                explicitMode: explicitMode,
                                score: score,
                                scoreValue: scoreValue,
                                rating: ratingStore.rating,
                                pressureLevel: recentSessions.first?.pressureLevel ?? .standard
                            )
                            expandableDetailsSection
                        } else {
                            // TIMED / OTHER MODES — score-first hierarchy
                            HeroScoreCard(
                                scoreValue: scoreValue,
                                practiceTitle: practiceTitle,
                                scoreAccent: scoreAccent,
                                scoreEmoji: scoreEmoji,
                                headline: headline,
                                sessionPrompt: sessionPrompt,
                                effectiveFillerCount: effectiveFillerCount,
                                fillerTint: fillerTint,
                                fillerDelta: fillerDelta,
                                effectiveDuration: effectiveDuration,
                                durationAssessment: durationAssessment,
                                xpEarned: xpEarned,
                                celebrationVisible: celebrationVisible
                            )
                            CoachNoteCard(
                                coachNote: coachNote,
                                coachNoteRevealed: coachNoteRevealed
                            )
                            AISessionDebriefCard(
                                session: sessionStore.sessions.first,
                                recentSessions: Array(sessionStore.sessions.prefix(5))
                            )
                            EloquenceFindingsCard(findings: eloquenceFindings)
                            if let pauseMetrics = sessionStore.sessions.first?.pauseMetrics {
                                PauseSummaryCard(metrics: pauseMetrics)
                            }
                            WordChoiceCard(metrics: WordChoiceMetrics.compute(transcript: transcriptText))
                            FillerBreakdownCard(transcriptText: transcriptText)
                            YourNextMoveCard(
                                drill: drillRecommendationV2,
                                legacyDrill: drillRecommendation,
                                aiFeedback: aiFeedback,
                                nextAction: nextAction,
                                onStartMiniDrill: { drill in
                                    print("[QuickDrill] Trigger: \(drill.title) | skill=\(drill.skillArea) | format=\(drill.format)")
                                    activeMiniDrill = drill
                                },
                                onStartDrill: onStartDrill
                            )
                            BaselineComparisonCard(
                                baseline: baselineStore.baseline,
                                transcriptText: transcriptText,
                                effectiveFillerCount: effectiveFillerCount,
                                effectiveDuration: effectiveDuration,
                                explicitMode: explicitMode,
                                score: score,
                                scoreValue: scoreValue,
                                rating: ratingStore.rating,
                                pressureLevel: recentSessions.first?.pressureLevel ?? .standard
                            )
                            expandableDetailsSection
                        }

                        // Pro Preview (free users only)
                        if !premium.isPremium {
                            proPreviewCard
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
                .safeAreaInset(edge: .bottom) {
                    actionBar
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            AppColor.cardBackground
                                .shadow(.drop(color: .black.opacity(0.06), radius: 12, y: -4))
                        )
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))

                if celebrationVisible && !reduceMotion {
                    celebrationOverlay
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

                // Non-personal-best milestones (level-up, streak, first session)
                if let milestone = activeMilestone {
                    MilestoneCelebrationOverlay(
                        icon: milestone.icon,
                        tint: milestone.tint,
                        title: milestone.title,
                        subtitle: milestone.subtitle,
                        detail: milestone.detail,
                        onDismiss: { activeMilestone = nil }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .disableSwipeBack()
        .onAppear(perform: setup)
        .sheet(isPresented: $showVideoPlayback) {
            if let recordingURL {
                VideoPlaybackView(url: recordingURL)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        // First-rep celebration — fires *once* on the user's very first
        // session. The manager handles the once-only logic; we just
        // present whatever it yields.
        .fullScreenCover(
            item: Binding(
                get: { FirstRepCelebrationManager.shared.pendingSession },
                set: { newValue in
                    if newValue == nil { FirstRepCelebrationManager.shared.dismiss() }
                }
            )
        ) { session in
            FirstRepCelebration(session: session) {
                FirstRepCelebrationManager.shared.dismiss()
            }
        }
        .fullScreenCover(item: $activeMiniDrill) { drill in
            let _ = print("[QuickDrill] Present: \(drill.title) | id=\(drill.id) | type=\(MiniDrillType.from(variationId: drill.variation.id))")
            drillView(for: drill)
        }
        .fullScreenCover(item: $miniDrillOutcome) { outcome in
            let _ = print("[QuickDrill] Result: succeeded=\(outcome.succeeded) type=\(outcome.drillType)")
            MiniDrillResultView(
                outcome: outcome,
                xpEarned: miniDrillAwardedXP,
                xpBreakdown: miniDrillXPBreakdown,
                streak: DrillHistoryStore.shared.currentStreak(for: outcome.drill.skillArea),
                onDone: {
                    print("[QuickDrill] Done — dismissing result")
                    miniDrillOutcome = nil
                },
                onTryAnother: {
                    print("[QuickDrill] Try another — loading next variation")
                    miniDrillOutcome = nil
                    if let freshVariation = DrillSelector.select(for: outcome.drill.skillArea) {
                        let nextDrill = DrillRecommendationV2(
                            variation: freshVariation,
                            reason: "Keep building on this skill",
                            trendContext: nil,
                            alternateFormat: nil
                        )
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            activeMiniDrill = nextDrill
                        }
                    } else {
                        print("[QuickDrill] ERROR: No fresh variation found for \(outcome.drill.skillArea)")
                    }
                }
            )
        }
#if canImport(UIKit)
        .onChange(of: celebrationVisible) { _, visible in
            if visible {
                CoachHaptic.personalBest()
            }
        }
#endif
    }
    /// Filler count tint: green if zero or better than average, orange if slightly above, red only if significantly worse.
    /// Gray if no words were spoken — zero fillers isn't an achievement when you said nothing.
    private var fillerTint: Color {
        if isMinimalEffort { return .secondary }
        if effectiveFillerCount == 0 { return AppColor.positive }
        let pastFillers = recentWindow.dropFirst().map(\.fillerWordCount)
        guard !pastFillers.isEmpty else { return AppColor.caution }
        let avg = Double(pastFillers.reduce(0, +)) / Double(pastFillers.count)
        if Double(effectiveFillerCount) <= avg { return AppColor.positive }
        if Double(effectiveFillerCount) <= avg + 2 { return AppColor.caution }
        return AppColor.warning
    }

    /// Delta vs recent average fillers (negative = improved)
    private var fillerDelta: Int? {
        let past = recentWindow.dropFirst().map(\.fillerWordCount)
        guard !past.isEmpty else { return nil }
        let avg = Double(past.reduce(0, +)) / Double(past.count)
        let delta = effectiveFillerCount - Int(avg.rounded())
        return delta
    }

    /// Delta vs recent average duration (positive = improved)
    private var durationDelta: Int? {
        let past = recentWindow.dropFirst().map(\.duration)
        guard !past.isEmpty else { return nil }
        let avg = past.reduce(0, +) / Double(past.count)
        let delta = Int(effectiveDuration) - Int(avg.rounded())
        return abs(delta) >= 3 ? delta : nil // only show if meaningful (3+ seconds)
    }

    // MARK: - Expandable Details Section

    private var expandableDetailsSection: some View {
        VStack(spacing: 12) {
            // Session Details (collapsed by default)
            DisclosureGroup(isExpanded: $showSecondaryDetails) {
                VStack(spacing: 14) {
                    // Category grid
                    if !feedbackCategories.isEmpty {
                        categoryGrid
                    }

                    // AI Moments
                    if !strongMoments.isEmpty || !weakMoments.isEmpty {
                        aiMomentsContent
                    }

                    // Coach Read (premium)
                    if premium.canViewCoachingInsights {
                        coachReadCard
                    }

                    // Video playback
                    if recordingURL != nil {
                        videoPlaybackButton
                    }

                    // Session comparison
                    sessionComparisonCard
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("Session Details")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                }
            }
            .tint(.secondary)
            .padding(Spacing.lg)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 8, y: 3)

            // Skill Progress (always visible if trend data exists)
            if !skillTrends.isEmpty {
                SkillProgressView(
                    trends: skillTrends,
                    drillHistory: DrillHistoryStore.shared.entries
                )
            }

            // XP Progress
            xpProgressCard
        }
    }

    // MARK: - Pro Preview Card (Free Users)

    private var proPreviewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.pro)
                Text("Unlock deeper insights")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                SparkleRibbon(tint: AppColor.pro)
            }

            Text("Pro members get personalized coach reads, video body language analysis, trend tracking, and detailed drills after every session.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Preview glimpse — show what a coach read looks like
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Coach read preview")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Your opening was strong — direct and grounded...")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.5))
                    Text("Filler pattern suggests rehearsal on transitions...")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.3))
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    LinearGradient(
                        colors: [.clear, AppColor.cardBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            Button {
                showPaywall = true
            } label: {
                HStack {
                    Text("See what Pro unlocks")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [AppColor.pro, AppColor.proLight],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.lg)
        .background(
            // Subtle purple wash so the Pro card reads as visually
            // distinct from the default white cards. Stays inside the
            // motion+color rule (no illustration), and uses the brand's
            // existing purple tokens.
            LinearGradient(
                colors: [
                    AppColor.pro.opacity(0.06),
                    AppColor.cardBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.pro.opacity(0.18), lineWidth: 1)
        )
    }

    /// AI Moments content (extracted from the old aiMomentsCard for reuse inside DisclosureGroup)
    private var aiMomentsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !strongMoments.isEmpty {
                Text("Strong Moments")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.positive)
                    .textCase(.uppercase)
                    .tracking(0.6)
                ForEach(strongMoments, id: \.self) { moment in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColor.positive)
                        Text(moment)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
            if !weakMoments.isEmpty {
                Text("Areas to Watch")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.caution)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .padding(.top, weakMoments.isEmpty ? 0 : 4)
                ForEach(weakMoments, id: \.self) { moment in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption2)
                            .foregroundStyle(AppColor.caution)
                        Text(moment)
                            .font(.caption)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    /// Video playback button for the expandable section
    private var videoPlaybackButton: some View {
        Button {
            showVideoPlayback = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.rectangle.fill")
                    .font(.caption.weight(.semibold))
                Text("Watch recording")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppColor.brandBlue)
        }
    }

    /// Session comparison card
    private var sessionComparisonCard: some View {
        Group {
            if recentSessions.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    Text("vs. Recent Average")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                    HStack(spacing: 16) {
                        if let fd = fillerDelta {
                            comparisonStat(label: "Fillers", delta: fd, inverted: true)
                        }
                        if let dd = durationDelta {
                            comparisonStat(label: "Duration", delta: dd, inverted: false)
                        }
                    }
                }
            }
        }
    }

    private func comparisonStat(label: String, delta: Int, inverted: Bool) -> some View {
        let improved = inverted ? delta < 0 : delta > 0
        return HStack(spacing: 4) {
            Image(systemName: improved ? "arrow.down" : "arrow.up")
                .font(.caption2.weight(.bold))
            Text("\(abs(delta))")
                .font(.caption.weight(.bold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(improved ? AppColor.positive : AppColor.caution)
    }

    // MARK: - Legacy Verdict Card (kept for backward compatibility)

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verdict")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            Text(verdict)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    // MARK: - Next Rep Card

    private var nextRepCard: some View {
        let drill = drillRecommendation
        return VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: drill.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(drill.tint)
                Text("Next Rep")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(drill.tint.opacity(0.5))
            }

            // Drill title
            Text(drill.title)
                .font(.headline)
                .foregroundStyle(.primary)

            // Why this drill
            Text(drill.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // The constraint / rule
            VStack(alignment: .leading, spacing: 6) {
                Text("Your rule")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(drill.tint)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(drill.constraint)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(drill.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            // Success goal
            HStack(spacing: 6) {
                Image(systemName: "target")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(drill.successGoal)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // CTA Button
            if onStartDrill != nil {
                Button {
                    onStartDrill?(drill)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                        Text("Start rep")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(drill.tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }

    private struct FreeInsight {
        let icon: String
        let tint: Color
        let message: String
        let action: String
    }

    private var primaryFreeInsight: FreeInsight {
        let wpm = effectiveDuration > 0 ? Int(Double(transcriptWordCount) / effectiveDuration * 60) : 0
        let fillers = effectiveFillerCount
        let dur = effectiveDuration

        // No words at all — the only insight is to actually speak
        if transcriptWordCount == 0 {
            return FreeInsight(
                icon: "mic.slash",
                tint: .secondary,
                message: "No speech was detected. This could be a microphone issue, or the session ended before you started speaking.",
                action: "Tap Retry, take a breath, and start talking — even a rough answer is better than none."
            )
        }

        // Minimal effort
        if isMinimalEffort {
            return FreeInsight(
                icon: "timer",
                tint: .orange,
                message: "You only spoke for about \(Int(dur)) seconds. That's not enough to practice any real speaking skill.",
                action: "Next time, commit to at least 20 seconds. Structure it: opening thought, one example, then a close."
            )
        }

        // High filler count is the most impactful thing to fix
        if fillers >= 5 {
            return FreeInsight(
                icon: "waveform.path",
                tint: .red,
                message: "You used \(fillers) filler words. Most appeared in quick transitions between ideas — the moments where your brain is searching for the next thought.",
                action: "Try this: pause silently for one beat before each new point. Silence feels longer to you than to your audience."
            )
        }

        // Very short answers
        if dur < 15 {
            return FreeInsight(
                icon: "timer",
                tint: .orange,
                message: "Your answer was only \(Int(dur)) seconds. That's too short to develop a complete thought and show control.",
                action: "Try this: after your opening sentence, add one concrete example and then close with a summary."
            )
        }

        // Rushed pace
        if wpm > 160 {
            return FreeInsight(
                icon: "hare.fill",
                tint: .orange,
                message: "Your pace hit \(wpm) words per minute — noticeably fast. Rapid delivery can undermine clarity even when the content is strong.",
                action: "Try this: deliberately slow your first two sentences. That sets a calmer tempo for the rest."
            )
        }

        // Moderate fillers
        if fillers >= 2 {
            return FreeInsight(
                icon: "waveform.path",
                tint: AppColor.caution,
                message: "You used \(fillers) filler words. They tend to cluster when you're transitioning between ideas or thinking out loud.",
                action: "Try this: replace each \"um\" with a silent pause. The silence sounds confident to your audience."
            )
        }

        // Very slow pace
        if wpm > 0 && wpm < 100 && dur >= 15 {
            return FreeInsight(
                icon: "tortoise.fill",
                tint: .blue,
                message: "Your pace was \(wpm) WPM — quite slow. While pausing is good, too much hesitation can make you sound uncertain.",
                action: "Try this: commit to each sentence before starting it, then deliver it at a natural conversational speed."
            )
        }

        // Clean session — reinforce what worked
        if fillers == 0 && dur >= 20 {
            return FreeInsight(
                icon: "checkmark.circle.fill",
                tint: AppColor.positive,
                message: "Zero filler words and \(Int(dur)) seconds of clean delivery. That's genuine control under pressure.",
                action: "Next step: try a harder mode or a longer duration to push this control further."
            )
        }

        // Default — general improvement
        return FreeInsight(
            icon: "lightbulb.fill",
            tint: .blue,
            message: "Your delivery had \(fillers) filler\(fillers == 1 ? "" : "s") across \(Int(dur)) seconds at \(wpm) WPM.",
            action: "Try this: focus on a strong opening sentence. A confident start sets the tone for everything after."
        )
    }

    // MARK: - Category Grid (7 dimensions)

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Breakdown")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(feedbackCategories) { category in
                HStack(spacing: 12) {
                    // Rating indicator
                    Image(systemName: category.rating.icon)
                        .font(.subheadline)
                        .foregroundStyle(ratingColor(category.rating))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.dimension)
                            .font(.subheadline.weight(.semibold))
                        Text(category.note)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(category.rating.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(ratingColor(category.rating))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(ratingColor(category.rating).opacity(0.08), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func ratingColor(_ rating: FeedbackRating) -> Color {
        switch rating {
        case .good: return AppColor.positive
        case .ok: return AppColor.caution
        case .couldImprove: return AppColor.caution
        }
    }

    // MARK: - Legacy Breakdown (fallback when no categories)

    private var breakdownCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Breakdown")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            ForEach(Array(effectiveScoreBreakdown.prefix(visibleSegments))) { segment in
                HStack {
                    Text(segment.title)
                    Spacer()
                    Text(segment.value)
                        .fontWeight(.semibold)
                        .foregroundStyle(color(for: segment.tintName))
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    // MARK: - AI Moments (Strong + Weak)

    private var aiMomentsCard: some View {
        let hasStrong = !strongMoments.isEmpty
        let hasWeak = !weakMoments.isEmpty
        let hasInsights = !derivedInsights.isEmpty

        return Group {
            if hasStrong || hasWeak || hasInsights {
                VStack(alignment: .leading, spacing: 14) {
                    if hasStrong {
                        momentSection(title: "What was strong", icon: "checkmark.seal.fill", tint: .green, items: strongMoments)
                    }

                    if hasWeak {
                        if hasStrong { Divider() }
                        momentSection(title: "What needs work", icon: "exclamationmark.triangle.fill", tint: .orange, items: weakMoments)
                    }

                    if hasInsights && !hasStrong && !hasWeak {
                        momentSection(title: "Signals", icon: "lightbulb.fill", tint: .blue, items: Array(derivedInsights.prefix(2)))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Spacing.lg)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            }
        }
    }

    private func momentSection(title: String, icon: String, tint: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.subheadline.weight(.bold))
            }

            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(tint.opacity(0.4))
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Recording Card

    private func recordingCard(url: URL) -> some View {
        let videoManager = VideoRecordingManager.shared
        return VStack(alignment: .leading, spacing: 12) {
            Text("Session Recording")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            // Watch recording button
            Button {
                showVideoPlayback = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                    Text("Watch recording")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(Spacing.cardGap)
                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                // Save recording
                if videoManager.savedRecordingURL == nil {
                    Button {
                        videoManager.saveRecording()
                    } label: {
                        HStack(spacing: 6) {
                            if videoManager.isSaving {
                                ProgressView()
                                    .tint(.secondary)
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.caption)
                            }
                            Text(videoManager.isSaving ? "Saving..." : "Save")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(videoManager.isSaving)
                } else {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppColor.positive)
                        Text("Saved")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                }

                // AI Video Analysis
                Button {
                    analyzeVideo()
                } label: {
                    HStack(spacing: 6) {
                        if isAnalyzingVideo {
                            ProgressView()
                                .tint(.secondary)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.caption)
                        }
                        Text(isAnalyzingVideo ? "Analyzing..." : "AI Analysis")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .foregroundStyle(.primary)
                }
                .buttonStyle(.plain)
                .disabled(isAnalyzingVideo)
            }

            // Video analysis results
            if let result = videoAnalysisResult {
                videoAnalysisResultView(result)
            }

            // Recording error display
            if let error = videoManager.recordingError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(.red)
            }

            if videoManager.savedRecordingURL == nil && !videoManager.isSaving {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                    Text("Recordings are temporary unless saved.")
                        .font(.caption)
                }
                .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private func videoAnalysisResultView(_ result: VideoAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text("AI Video Analysis")
                .font(.subheadline.weight(.bold))

            videoAnalysisRow(label: "Posture", rating: result.posture, note: result.postureNote)
            videoAnalysisRow(label: "Eye Contact", rating: result.eyeContact, note: result.eyeContactNote)
            videoAnalysisRow(label: "Expression", rating: result.facialExpression, note: result.facialExpressionNote)
            videoAnalysisRow(label: "Gestures", rating: result.gestureUse, note: result.gestureNote)
            videoAnalysisRow(label: "Energy", rating: result.energyConfidence, note: result.energyNote)
            videoAnalysisRow(label: "Presence", rating: result.presenceDelivery, note: result.presenceNote)

            Text(result.overallNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        }
    }

    private func videoAnalysisRow(label: String, rating: FeedbackRating, note: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: rating.icon)
                .font(.caption)
                .foregroundStyle(ratingColor(rating))
            Text(label)
                .font(.caption.weight(.semibold))
                .frame(width: 70, alignment: .leading)
            Text(note)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    // MARK: - Coach Read Card

    private var coachReadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            if let aiFeedback {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What you did well")
                        .font(.subheadline.weight(.semibold))
                    ForEach(aiFeedback.strengths, id: \.self) { strength in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                                .padding(.top, 3)
                            Text(strength)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    Text("Key improvement")
                        .font(.subheadline.weight(.semibold))
                    Text(aiFeedback.keyImprovement)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Suggested drill")
                        .font(.subheadline.weight(.semibold))
                    Text(aiFeedback.suggestedDrill)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !aiFeedback.revisedOpening.isEmpty {
                        Text("Try this opening")
                            .font(.subheadline.weight(.semibold))
                        Text("\"\(aiFeedback.revisedOpening)\"")
                            .font(.subheadline.italic())
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    }
                }
            } else {
                Text("Generate a deeper coaching read from this session's transcript.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let aiError {
                Text(aiError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Gentle approaching-limit note (only when ≥90% used and no feedback yet generated)
            if aiFeedback == nil && aiSettings.isApproachingLimit && !aiSettings.hasReachedLimit {
                Text("\(aiSettings.remainingAnalyses) coaching \(aiSettings.remainingAnalyses == 1 ? "analysis" : "analyses") remaining this month")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if aiSettings.hasReachedLimit && aiFeedback == nil {
                // Graceful at-limit experience — warm, not punitive
                VStack(spacing: 8) {
                    Text("Monthly coaching limit reached")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("You've made great use of AI coaching this month. Fresh analyses will be available \(aiSettings.resetDateFormatted).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .padding(.horizontal, Spacing.md)
                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            } else {
                Button {
                    if aiSettings.hasAcknowledgedAIDisclosure {
                        Task { await requestDeeperFeedback() }
                    } else {
                        showAIDisclosure = true
                    }
                } label: {
                    HStack {
                        if isRequestingAIFeedback {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(aiFeedback == nil ? "Generate Coach Read" : "Refresh Coach Read")
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isRequestingAIFeedback ? Color(.systemGray4) : Color.primary.opacity(0.85), in: Capsule())
                    .foregroundStyle(Color(.systemBackground))
                }
                .buttonStyle(.plain)
                .disabled(isRequestingAIFeedback)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    // MARK: - Secondary Details Section (Collapsed by Default)

    private var secondaryDetailsSection: some View {
        VStack(spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showSecondaryDetails.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("Details")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer()
                    Image(systemName: showSecondaryDetails ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            if showSecondaryDetails {
                VStack(spacing: 14) {
                    if !feedbackCategories.isEmpty {
                        categoryGrid
                    } else if !effectiveScoreBreakdown.isEmpty {
                        breakdownCard
                    }

                    if let recordingURL {
                        recordingCard(url: recordingURL)
                    }

                    if let comparison = smartComparison {
                        sessionComparisonCard(comparison)
                    }

                    xpProgressCard
                    retentionCard
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - XP Progress Card

    private var xpProgressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(currentLevel)
                Spacer()
                Text(nextLevel)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            ShimmerProgressBar(progress: progress, tint: AppColor.brandBlue)

            HStack {
                Text("\(displayedXP) XP")
                Spacer()
                Text("\(xpToNext) to level up")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - Retention Card

    private var retentionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                PulseBadge(systemImage: "sparkles", tint: .orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text(retentionSnapshot.activeChallenge.title)
                        .font(.subheadline.weight(.semibold))
                    Text(retentionSnapshot.activeChallenge.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            ShimmerProgressBar(progress: retentionSnapshot.activeChallenge.progress, tint: .orange)

            HStack {
                Text(retentionSnapshot.activeChallenge.progressLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                Spacer()
                HStack(spacing: 6) {
                    SparkleRibbon(tint: .orange)
                    Text(retentionSnapshot.activeChallenge.rewardLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                }
            }
        }
        .padding(16)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - Action Bar (Icon-based)

    private var actionBar: some View {
        HStack(spacing: 0) {
            // Home
            Button { onHome() } label: {
                actionBarItem(icon: "house.fill", label: "Home")
            }
            .buttonStyle(.pressable)

            // Retry Same Prompt
            Button { onPracticeAgain() } label: {
                actionBarItem(icon: "arrow.clockwise", label: "Retry", highlighted: true)
            }
            .buttonStyle(.pressable)

            // New Prompt
            Button { onSelectPracticeMode() } label: {
                actionBarItem(icon: "sparkles", label: "New")
            }
            .buttonStyle(.pressable)

            // Share (opens dual-flow menu)
            Button { showShareMenu = true } label: {
                actionBarItem(icon: "square.and.arrow.up", label: "Share")
            }
            .buttonStyle(.pressable)
        }
        .confirmationDialog("Share Session", isPresented: $showShareMenu) {
            ShareLink(item: shareImage, preview: SharePreview("My Noum Score", image: shareImage)) {
                Label("Share Achievement Card", systemImage: "photo.fill")
            }
            Button {
                showFeedbackRequestSheet = true
            } label: {
                Label("Request Feedback", systemImage: "person.2.fill")
            }
        } message: {
            Text("Choose how to share this session")
        }
        .sheet(isPresented: $showFeedbackRequestSheet) {
            FeedbackRequestComposer(
                transcript: transcriptText,
                fillerCount: effectiveFillerCount,
                duration: effectiveDuration,
                score: scoreValue,
                headline: headline,
                prompt: sessionPrompt,
                theme: sessionTheme,
                mode: currentMode,
                feedbackCategories: feedbackCategories,
                aiFeedback: aiFeedback,
                recordingURL: recordingURL
            )
        }
        .alert("AI Coaching Disclosure", isPresented: $showAIDisclosure) {
            Button("Continue") {
                aiSettings.acknowledgeAIDisclosure()
                Task { await requestDeeperFeedback() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To generate coaching feedback, your speech transcript is sent to \(aiSettings.activeProviderDisplayName) for analysis. Your transcript is processed under their API data terms and is not used to train their AI models. Noum does not sell or share your data with advertisers.")
        }
    }

    private func actionBarItem(icon: String, label: String, highlighted: Bool = false) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(highlighted ? .white : .primary.opacity(0.6))
                .frame(width: 44, height: 44)
                .background(
                    highlighted
                        ? AnyShapeStyle(Color.primary.opacity(0.85))
                        : AnyShapeStyle(Color(.systemGray6)),
                    in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                )
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(highlighted ? .blue : .secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Share Achievement Card (Premium Visual)

    @MainActor
    private var shareImage: Image {
        let renderer = ImageRenderer(content: shareCardContent)
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            return Image(uiImage: uiImage)
        }
        return Image(systemName: "square.fill")
    }

    private var shareCardContent: some View {
        VStack(spacing: 0) {
            // Top brand bar
            HStack {
                Text("NOUM")
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .tracking(4)
                Spacer()
                Text(currentMode.displayLabel.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(shareModeTint.opacity(0.8))
                    .tracking(1.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(shareModeTint.opacity(0.15), in: Capsule())
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 20)

            // Hero score
            ZStack {
                // Outer glow ring
                Circle()
                    .stroke(shareModeTint.opacity(0.12), lineWidth: 3)
                    .frame(width: 140, height: 140)

                // Score ring
                Circle()
                    .trim(from: 0, to: Double(scoreValue) / 10.0)
                    .stroke(
                        AngularGradient(
                            colors: [shareModeTint, shareModeTint.opacity(0.6), shareModeTint],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                // Track
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 8)
                    .frame(width: 120, height: 120)

                VStack(spacing: 0) {
                    Text("\(scoreValue)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("out of 10")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(.bottom, 16)

            // Headline
            Text(headline)
                .font(Typography.cardTitle)
                .foregroundStyle(.white.opacity(0.9))
                .padding(.bottom, 6)

            // Prompt
            if let sessionPrompt {
                Text("\"\(sessionPrompt)\"")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            // Stats row
            HStack(spacing: 0) {
                shareStatCell(value: "\(effectiveFillerCount)", label: "Fillers", tint: fillerTint)
                shareDivider
                shareStatCell(value: "\(Int(effectiveDuration))s", label: "Duration", tint: AppColor.brandBlue)
                shareDivider
                shareStatCell(value: "\(shareWPM)", label: "WPM", tint: AppColor.modeSuddenDeath)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // Footer
            HStack {
                Text("noum.app")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.25))
                Spacer()
                Text(Date().formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.2))
            }
            .padding(.horizontal, 28)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .frame(width: 360)
        .background(
            ZStack {
                // Base dark gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.06, green: 0.06, blue: 0.14),
                        Color(red: 0.10, green: 0.08, blue: 0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                // Accent glow
                RadialGradient(
                    colors: [shareModeTint.opacity(0.15), .clear],
                    center: .center,
                    startRadius: 20,
                    endRadius: 220
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var shareModeTint: Color {
        AppColor.tint(for: currentMode)
    }

    private var shareWPM: Int {
        guard effectiveDuration > 0 else { return 0 }
        return Int((Double(transcriptWordCount) / effectiveDuration * 60).rounded())
    }

    private func shareStatCell(value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Typography.headline)
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(maxWidth: .infinity)
    }

    private var shareDivider: some View {
        Rectangle()
            .fill(.white.opacity(0.08))
            .frame(width: 1, height: 30)
    }

    // MARK: - Smart Session Comparison

    private struct SessionComparison {
        let reason: String
        let previousScore: Int
        let currentScore: Int
        let previousWPM: Int
        let currentWPM: Int
        let previousFillers: Int
        let currentFillers: Int
        let previousDate: Date
    }

    private var smartComparison: SessionComparison? {
        guard let currentScore = lockedScore ?? score,
              let prompt = sessionPrompt else { return nil }

        let past = recentSessions.dropFirst()

        // Same prompt match — always show when available
        if let match = past.first(where: { $0.prompt == prompt && $0.score != nil }) {
            let currentWPM = effectiveDuration > 0 ? Int(Double(transcriptWordCount) / effectiveDuration * 60) : 0
            let matchWPM = match.duration > 0 ? Int(Double(match.transcript.split { !$0.isLetter }.count) / match.duration * 60) : 0
            return SessionComparison(
                reason: "Same prompt",
                previousScore: match.score ?? 0,
                currentScore: currentScore,
                previousWPM: matchWPM,
                currentWPM: currentWPM,
                previousFillers: match.fillerWordCount,
                currentFillers: lockedFillerCount ?? fillerCount,
                previousDate: match.date
            )
        }

        // Same theme match — show whenever there's a theme match
        if let theme = sessionTheme, theme != .all {
            if let match = past.first(where: { $0.theme == theme && $0.score != nil }) {
                let currentWPM = effectiveDuration > 0 ? Int(Double(transcriptWordCount) / effectiveDuration * 60) : 0
                let matchWPM = match.duration > 0 ? Int(Double(match.transcript.split { !$0.isLetter }.count) / match.duration * 60) : 0
                return SessionComparison(
                    reason: "Same theme: \(theme.rawValue)",
                    previousScore: match.score ?? 0,
                    currentScore: currentScore,
                    previousWPM: matchWPM,
                    currentWPM: currentWPM,
                    previousFillers: match.fillerWordCount,
                    currentFillers: lockedFillerCount ?? fillerCount,
                    previousDate: match.date
                )
            }
        }

        // Same mode match — fallback comparison
        if let match = past.first(where: { $0.mode == currentMode && $0.score != nil }) {
            let currentWPM = effectiveDuration > 0 ? Int(Double(transcriptWordCount) / effectiveDuration * 60) : 0
            let matchWPM = match.duration > 0 ? Int(Double(match.transcript.split { !$0.isLetter }.count) / match.duration * 60) : 0
            return SessionComparison(
                reason: "Previous \(currentMode.displayLabel) session",
                previousScore: match.score ?? 0,
                currentScore: currentScore,
                previousWPM: matchWPM,
                currentWPM: currentWPM,
                previousFillers: match.fillerWordCount,
                currentFillers: lockedFillerCount ?? fillerCount,
                previousDate: match.date
            )
        }

        return nil
    }

    private func sessionComparisonCard(_ comparison: SessionComparison) -> some View {
        let scoreDelta = comparison.currentScore - comparison.previousScore
        let improved = scoreDelta > 0
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: improved ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .foregroundStyle(improved ? .green : .orange)
                Text(comparison.reason)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(formatter.localizedString(for: comparison.previousDate, relativeTo: Date()))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            HStack(spacing: 16) {
                comparisonMetric(label: "Score", previous: "\(comparison.previousScore)", current: "\(comparison.currentScore)", improved: scoreDelta > 0)
                comparisonMetric(label: "WPM", previous: "\(comparison.previousWPM)", current: "\(comparison.currentWPM)", improved: comparison.currentWPM >= comparison.previousWPM)
                comparisonMetric(label: "Fillers", previous: "\(comparison.previousFillers)", current: "\(comparison.currentFillers)", improved: comparison.currentFillers <= comparison.previousFillers)
            }

            if improved {
                Text("You're improving. Keep going.")
                    .font(.caption)
                    .foregroundStyle(AppColor.positive)
            } else if scoreDelta == 0 {
                Text("Consistency is progress. Same score, building the habit.")
                    .font(.caption)
                    .foregroundStyle(AppColor.brandBlue)
            }
        }
        .padding(Spacing.cardGap)
        .background(
            (improved ? Color.green : Color.orange).opacity(0.06),
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke((improved ? Color.green : Color.orange).opacity(0.12), lineWidth: 1)
        )
    }

    private func comparisonMetric(label: String, previous: String, current: String, improved: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text(previous)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .strikethrough()
                Image(systemName: "arrow.right")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Text(current)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(improved ? .green : .orange)
            }
        }
        .frame(maxWidth: .infinity)
    }
    // MARK: - Personal Best Celebration (Full-Screen Intermediary)

    private func personalBestCelebration(milestone: MilestoneEvent) -> some View {
        PersonalBestCelebrationScreen(
            scoreValue: scoreValue,
            scoreAccent: scoreAccent,
            modeName: currentMode.displayLabel,
            previousBest: milestone.detail,
            onContinue: {
                withAnimation(.easeInOut(duration: 0.4)) {
                    showPersonalBestScreen = false
                }
            }
        )
    }

    // MARK: - Celebration Overlay

    private var celebrationOverlay: some View {
        GeometryReader { geometry in
            TimelineView(.animation(minimumInterval: 1 / 22.0)) { timeline in
                let phase = timeline.date.timeIntervalSinceReferenceDate

                ZStack {
                    ForEach(0..<14, id: \.self) { index in
                        let x = geometry.size.width * (0.10 + (Double(index % 7) * 0.13))
                        let travel = (phase.truncatingRemainder(dividingBy: 1.6)) / 1.6
                        let y = geometry.size.height * (0.22 + Double(index / 7) * 0.08) - travel * 120

                        Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                            .font(.system(size: index.isMultiple(of: 2) ? 10 : 8, weight: .bold))
                            .foregroundStyle(scoreAccent.opacity(0.28))
                            .position(x: x, y: y)
                            .opacity(1 - travel)
                            .scaleEffect(0.7 + travel * 0.4)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func color(for tintName: String) -> Color {
        switch tintName {
        case "blue": return .blue
        case "orange": return .orange
        case "green": return .green
        case "red": return .red
        case "purple": return .purple
        case "indigo": return .indigo
        default: return .primary
        }
    }

    // MARK: - Drill Routing

    @ViewBuilder
    private func drillView(for drill: DrillRecommendationV2) -> some View {
        let drillType = MiniDrillType.from(variationId: drill.variation.id)
        switch drillType {
        case .beatTheBrake:
            BeatTheBrakeView(drill: drill, prompt: sessionPrompt, onComplete: handleDrillComplete, onCancel: handleDrillCancel)
        case .landThePause:
            LandThePauseView(drill: drill, prompt: sessionPrompt, onComplete: handleDrillComplete, onCancel: handleDrillCancel)
        case .prepStack:
            PREPStackView(drill: drill, prompt: sessionPrompt, onComplete: handleDrillComplete, onCancel: handleDrillCancel)
        case .standard:
            MiniDrillView(drill: drill, prompt: sessionPrompt, onComplete: handleDrillComplete, onCancel: handleDrillCancel)
        }
    }

    private func handleDrillComplete(_ outcome: MiniDrillOutcome) {
        print("[QuickDrill] Complete: succeeded=\(outcome.succeeded) fillers=\(outcome.fillerCount) words=\(outcome.wordCount) type=\(outcome.drillType)")
        DrillHistoryStore.shared.record(
            .init(variationId: outcome.drill.variation.id,
                  skillArea: outcome.drill.skillArea,
                  succeeded: outcome.succeeded,
                  sessionId: UUID())
        )

        let xpBreakdown = DrillXPEngine.breakdown(outcome: outcome)
        miniDrillAwardedXP = xpBreakdown.total
        miniDrillXPBreakdown = xpBreakdown
        ProfileManager.shared.addXP(xpBreakdown.total)
        RewardEngine.shared.evaluateDrill(
            skillArea: outcome.drill.skillArea,
            succeeded: outcome.succeeded,
            streak: DrillHistoryStore.shared.currentStreak(for: outcome.drill.skillArea)
        )

        if !outcome.transcript.isEmpty {
            BaselineStore.shared.recordMiniDrillOutcome(outcome, prompt: sessionPrompt)
        }

        activeMiniDrill = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            miniDrillOutcome = outcome
        }
    }

    private func handleDrillCancel() {
        print("[QuickDrill] Cancelled")
        activeMiniDrill = nil
    }

    // MARK: - Setup & Logic

    private func setup() {
        guard !didApplyXP else { return }
        didApplyXP = true
        lockedTranscriptText = String(transcript.characters)
        lockedFillerCount = fillerCount
        lockedDuration = duration
        lockedScore = score
        lockedFeedbackOverride = feedbackOverride
        lockedHeadlineOverride = headlineOverride
        lockedScoreBreakdown = scoreBreakdown
        lockedInsights = insights
        aiFeedback = recentSessions.first?.aiCoachFeedback
        progressionPreviousXP = profile.xp
        displayedXP = profile.xp
        currentLevel = ProfileManager.levelTitle(forXP: profile.xp)
        nextLevel = ProfileManager.levelTitle(forXP: ((profile.xp / 1000) + 1) * 1000)
        xpToNext = ProfileManager.xpNeededToNextLevel(forXP: profile.xp)
        progress = ProfileManager.progressTowardsNextLevel(forXP: profile.xp)

        // Delegate XP, achievements, milestones, and trend recording to SessionFinalizer
        let result = SessionFinalizer.finalize(
            xpEarned: xpEarned,
            scoreValue: scoreValue,
            effectiveFillerCount: effectiveFillerCount,
            effectiveDuration: effectiveDuration,
            transcriptWordCount: transcriptWordCount,
            scoreBreakdown: lockedScoreBreakdown,
            currentMode: currentMode,
            sessionPrompt: sessionPrompt,
            latestSessionID: latestSessionID,
            recentSessions: recentSessions,
            imConversationDetails: imConversationDetails,
            practiceTitle: practiceTitle,
            derivedInsightsFirst: derivedInsights.first,
            pressureLevel: recentSessions.first?.pressureLevel ?? .standard
        )

        progressionDeltas = result.achievementDeltas
        progressionNewUnlocks = result.newUnlocks
        nextAction = result.nextAction
        enhancedCoachNote = result.coachNote
        eloquenceFindings = result.eloquenceFindings

        if result.showProgressionScreen {
            showProgressionScreen = true
        }

        animateXP(to: result.newXP)
        animateSegments()
        CoachHaptic.scoreReveal()

        // Milestone routing — personal bests and level-ups get full intermediary screens,
        // other milestones (streak, first session) use the compact overlay.
        if let milestone = result.milestone {
            if milestone.title == "New Personal Best!" {
                personalBestMilestone = milestone
                if !showProgressionScreen {
                    showPersonalBestScreen = true
                }
            } else if milestone.title == "Level Up!" {
                levelUpPreviousLevel = result.previousLevel
                levelUpNewLevel = result.newLevel
                if !showProgressionScreen {
                    showLevelUpScreen = true
                }
            } else {
                Task {
                    try? await Task.sleep(for: .seconds(showProgressionScreen ? 0.5 : 2.2))
                    await MainActor.run {
                        withAnimation(.standardSpring) { activeMilestone = milestone }
                    }
                }
            }
        }

        // Score celebration + coach note reveal (delayed if progression screen is showing)
        let celebrationDelay: Double = showProgressionScreen ? 0.5 : 0
        Task {
            if celebrationDelay > 0 {
                try? await Task.sleep(for: .seconds(celebrationDelay))
            }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.35)) {
                    celebrationVisible = scoreValue >= 7 || xpEarned >= 100
                }
            }
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.4)) { coachNoteRevealed = true }
            }
            try? await Task.sleep(for: .seconds(0.8))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.35)) { celebrationVisible = false }
            }
        }
    }

    private func requestDeeperFeedback() async {
        aiError = nil

        // Check API configuration with specific error messages
        if aiSettings.activeProvider == nil {
            aiError = "Add an AI API key in Settings to enable Coach Read."
            return
        }
        if aiSettings.hasReachedLimit {
            aiError = "You've used all \(aiSettings.monthlyLimit) coaching analyses this month. Fresh analyses available \(aiSettings.resetDateFormatted)."
            return
        }

        guard let sessionID = latestSessionID else {
            aiError = "This session has not been saved yet. Finish one more rep and try again."
            return
        }

        let text = transcriptText
        let wordCount = text.split(whereSeparator: \.isWhitespace).count
        if wordCount < 10 {
            aiError = "Speak at least 10 words to generate coaching feedback."
            return
        }

        isRequestingAIFeedback = true
        defer { isRequestingAIFeedback = false }

        do {
            let plan = CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)
            let styleSnapshot = PracticeEvaluator.speakingIdentity(
                for: text,
                profile: coachingProfileStore.profile
            )
            let feedback = try await aiCoachService.generateDeeperFeedback(
                input: AICoachSessionInput(
                    transcript: text,
                    mode: recentSessions.first?.mode ?? .timed,
                    score: score,
                    fillerCount: fillerCount,
                    duration: duration,
                    wordsPerMinute: PracticeEvaluator.paceSnapshot(
                        forTranscript: text,
                        duration: duration
                    ).wordsPerMinute,
                    speakingIdentity: styleSnapshot.identity
                ),
                profile: coachingProfileStore.profile,
                plan: plan
            )
            sessionStore.saveAIFeedback(sessionID: sessionID, feedback: feedback)
            aiFeedback = feedback
        } catch {
            let desc = error.localizedDescription
            if desc.contains("transcriptTooShort") || desc.contains("too short") {
                aiError = "Speak at least 10 words to generate coaching feedback."
            } else if desc.contains("API key") || desc.contains("apiKey") {
                aiError = "API key issue — check your AI provider settings."
            } else {
                aiError = "Coach Read failed: \(desc)"
            }
        }
    }

    private func analyzeVideo() {
        guard let url = recordingURL else { return }
        isAnalyzingVideo = true

        Task {
            do {
                let result = try await VideoAnalysisService.shared.analyzeRecording(at: url)
                await MainActor.run {
                    videoAnalysisResult = result
                    isAnalyzingVideo = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzingVideo = false
                    let desc = error.localizedDescription
                    if desc.contains("API key") || desc.contains("apiKey") || desc.contains("configured") {
                        aiError = "Add an AI API key in Settings to analyze video."
                    } else {
                        aiError = "Video analysis failed: \(desc)"
                    }
                }
            }
        }
    }

    private func animateXP(to endXP: Int) {
        Task {
            let startXP = displayedXP
            for xp in stride(from: startXP, through: endXP, by: 1) {
                await MainActor.run {
                    displayedXP = xp
                    progress = ProfileManager.progressTowardsNextLevel(forXP: xp)
                }
                try? await Task.sleep(for: .milliseconds(6))
            }
            await MainActor.run {
                currentLevel = ProfileManager.levelTitle(forXP: endXP)
                nextLevel = ProfileManager.levelTitle(forXP: ((endXP / 1000) + 1) * 1000)
                xpToNext = ProfileManager.xpNeededToNextLevel(forXP: endXP)
                CoachHaptic.xpEarned()
            }
        }
    }

    private func animateSegments() {
        guard !scoreBreakdown.isEmpty else { return }
        Task {
            for index in 1...scoreBreakdown.count {
                try? await Task.sleep(for: .milliseconds(180))
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        visibleSegments = index
                    }
                }
            }
        }
    }
}

#endif

// MARK: - Path-based Navigation Init (in extension to preserve memberwise init)
#if canImport(SwiftUI)
extension SummaryView {
    /// Path-based navigation initializer. Pulls all heavy data from SummaryDataStore.
    init(payload: SummaryPayload, navigationPath: Binding<NavigationPath>) {
        let store = SummaryDataStore.shared
        let entry = store.retrieve(for: payload.id)

        self.transcript = entry?.transcript ?? AttributedString("")
        self.fillerCount = entry?.fillerCount ?? 0
        self.duration = entry?.duration ?? 0
        self.score = entry?.score
        self.progressSegments = entry?.progressSegments ?? 0
        self.xpEarned = entry?.xpEarned ?? 0
        self.showDuration = entry?.showDuration ?? true
        self.practiceTitle = entry?.practiceTitle ?? "Practice Summary"
        self.feedbackOverride = entry?.feedbackOverride
        self.headlineOverride = entry?.headlineOverride
        self.scoreBreakdown = entry?.scoreBreakdown ?? []
        self.insights = entry?.insights ?? []
        self.recentSessions = entry?.recentSessions ?? []
        self.imConversationDetails = entry?.imConversationDetails
        self.explicitMode = entry?.explicitMode ?? payload.mode
        self.recordingURL = entry?.recordingURL
        self.sessionPrompt = entry?.sessionPrompt
        self.sessionTheme = entry?.sessionTheme
        self.feedbackCategories = entry?.feedbackCategories ?? []
        self.strongMoments = entry?.strongMoments ?? []
        self.weakMoments = entry?.weakMoments ?? []
        self.durationAssessment = entry?.durationAssessment ?? .onTarget
        self.targetRange = entry?.targetRange ?? (30, 60, 120)

        // Path-based navigation callbacks
        let pathBinding = navigationPath
        let payloadId = payload.id
        let payloadMode = payload.mode
        self.onHome = {
            SummaryDataStore.shared.remove(for: payloadId)
            pathBinding.wrappedValue = NavigationPath()
        }
        self.onSelectPracticeMode = {
            SummaryDataStore.shared.remove(for: payloadId)
            pathBinding.wrappedValue = NavigationPath()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pathBinding.wrappedValue.append(AppDestination.practiceSelection)
            }
        }
        self.onPracticeAgain = {
            SummaryDataStore.shared.remove(for: payloadId)
            var path = pathBinding.wrappedValue
            if path.count > 0 { path.removeLast() }
            if path.count > 0 { path.removeLast() }
            pathBinding.wrappedValue = path
            let destination: AppDestination
            switch payloadMode {
            case .timed: destination = .timedPractice
            case .suddenDeath: destination = .suddenDeathPractice
            case .ahCounter: destination = .ahCounterPractice
            case .imConversation: destination = .imPractice(scenario: nil, tone: nil)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pathBinding.wrappedValue.append(destination)
            }
        }
        self.onStartDrill = entry?.onStartDrill
    }
}
#endif

#if canImport(SwiftUI)
#Preview {
    SummaryView(
        transcript: AttributedString("This was a concise practice answer with a strong opening, clear middle, and a tidy finish."),
        fillerCount: 1,
        duration: 28,
        score: 8,
        progressSegments: 3,
        xpEarned: 74,
        practiceTitle: "Impromptu Practice",
        feedbackOverride: "Clear answer overall. Push for a little more depth or time on the next rep.",
        headlineOverride: "Solid response",
        scoreBreakdown: [
            PracticeScoreSegment(title: "Depth", value: "+2", tintName: "blue"),
            PracticeScoreSegment(title: "Content", value: "+3", tintName: "orange"),
            PracticeScoreSegment(title: "Pace", value: "+2", tintName: "green"),
            PracticeScoreSegment(title: "Filler penalty", value: "-1", tintName: "red")
        ],
        insights: [
            "You used fewer filler words than your recent average.",
            "You stayed with the answer longer than your recent average.",
            "Your pace was calm. Keep that control while expanding the middle of the answer."
        ],
        explicitMode: .timed,
        feedbackCategories: [
            FeedbackCategory(dimension: "Opening", rating: .good, note: "Clear, confident start"),
            FeedbackCategory(dimension: "Structure", rating: .good, note: "Well-organized answer"),
            FeedbackCategory(dimension: "Relevance", rating: .good, note: "Stayed on topic"),
            FeedbackCategory(dimension: "Depth", rating: .ok, note: "Push for more examples"),
            FeedbackCategory(dimension: "Clarity", rating: .good, note: "Clean, minimal fillers"),
            FeedbackCategory(dimension: "Pace", rating: .good, note: "Comfortable, natural pace"),
            FeedbackCategory(dimension: "Close", rating: .ok, note: "Ended a bit abruptly"),
        ],
        strongMoments: ["Zero filler words — clean delivery", "Natural, well-paced delivery"],
        weakMoments: []
    )
}


#endif
