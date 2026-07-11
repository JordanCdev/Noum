import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)
import SwiftUI

// MARK: - Summary interstitial policy

/// The only full-screen beat allowed between a completed rep and its summary.
/// Priority favors evidence of speaking improvement over volume/progression
/// furniture. The first rep always lands directly on its coaching read.
enum SummaryInterstitial: Hashable, CaseIterable {
    case personalBest
    case skillProgress
    case achievementProgress
    case practiceVolume
}

struct SummaryInterstitialPolicy {
    /// Highest-value first. Kept public to the module so tests can pin future
    /// additions to an intentional place in the attention budget.
    static let priority: [SummaryInterstitial] = [
        .personalBest,
        .skillProgress,
        .achievementProgress,
        .practiceVolume,
    ]

    static func select(
        completedRepCount: Int,
        hasPersonalBest: Bool,
        hasSkillProgress: Bool,
        hasAchievementProgress: Bool,
        hasPracticeVolumeLevel: Bool
    ) -> SummaryInterstitial? {
        guard completedRepCount > 1 else { return nil }
        var available: Set<SummaryInterstitial> = []
        if hasPersonalBest { available.insert(.personalBest) }
        if hasSkillProgress { available.insert(.skillProgress) }
        if hasAchievementProgress { available.insert(.achievementProgress) }
        if hasPracticeVolumeLevel { available.insert(.practiceVolume) }
        return priority.first(where: available.contains)
    }
}

/// Keeps the status-area cover tied to the container's measured safe area.
/// The clamp is defensive for previews or transient layout passes that can
/// briefly report a negative inset while a navigation transition settles.
enum SummaryTopSafeAreaCoverLayout {
    static func height(for topInset: CGFloat) -> CGFloat {
        max(0, topInset)
    }
}

private enum SummaryCloudProcessingAction {
    case coachRead
    case videoAnalysis
}

// MARK: - SummaryView (Redesigned)

struct SummaryView: View {
    let transcript: AttributedString
    let fillerCount: Int
    let duration: TimeInterval
    let score: Int?
    let progressSegments: Int
    let xpEarned: Int
    var committedFinalization: SessionFinalizationResult? = nil
    var suddenDeathGamePoints: Int? = nil
    var suddenDeathMultiplierLabels: [String] = []
    var suddenDeathTotalWords: Int? = nil
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
    /// Bridge into Ask Noum with a session-anchored opener already in
    /// the thread. The owning ContentView wires this to inject the
    /// opener into `AskNoumStore` then push `AppDestination.askNoum`,
    /// so the user lands inside a coach reply already in flight.
    var onAskNoumAboutRep: ((String) -> Void)?
    /// Optional launch callback for the post-rep "Looking ahead"
    /// recommendation. The path-based init wires this to pop the
    /// summary + the prior practice screen and push the destination
    /// produced by `SummaryLookingAheadRouter` — same shape as
    /// `onPracticeAgain` (the user is launching a new full rep, so
    /// the stale summary shouldn't be reachable via the back chevron).
    /// Receives the `AppDestination` rather than recomputing it inside
    /// the path closure because the destination depends on view-side
    /// state (`summaryRecommendation` + `IMModeAvailability.isAvailable`)
    /// the init doesn't have in scope. Defaults nil → the
    /// `LookingAheadCard` stays the pre-round-19 descriptive-only nudge.
    var onStartLookingAhead: ((AppDestination) -> Void)?

    @StateObject private var profile = ProfileManager.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var premium = PremiumManager.shared
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var skillProgression = SkillProgressionStore.shared
    @StateObject private var postRepCoachNoteStore = PostRepCoachNoteStore.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @State private var showPaywall = false
    @State private var displayedXP: Int = 0
    @State private var progress: Double = 0
    @State private var currentLevel: String = ""
    @State private var nextLevel: String = ""
    @State private var xpToNext: Int = 0
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
    @State private var personalBestMilestone: MilestoneEvent?
    /// Skill level-up sequence played between PersonalBest (or
    /// LevelUp / Progression) and the standard summary content. The
    /// snapshot is locked at setup so the pre-summary celebration
    /// plays the exact set of events that was pending at finalize
    /// time, not whatever's pending the moment the user scrolls back.
    /// Empty array = no celebration; the parent skips straight to
    /// summary content without rendering the overlay.
    @State private var preSummaryEvents: [SkillLevelUpEvent] = []
    @State private var selectedInterstitial: SummaryInterstitial?
    @State private var activeMiniDrill: DrillRecommendationV2?
    @State private var miniDrillOutcome: MiniDrillOutcome?
    @State private var miniDrillAwardedXP: Int = 0
    @State private var miniDrillXPBreakdown: DrillXPEngine.Breakdown?
    @State private var showSecondaryDetails = false
    @State private var coachNoteRevealed = false
    @State private var enhancedCoachNote: CoachNote?
    @State private var eloquenceFindings: [EloquenceFinding] = []
    @State private var showAIDisclosure = false
    @State private var pendingCloudProcessingAction: SummaryCloudProcessingAction = .coachRead
    /// Proof moment loaded for the personal-best celebration. Hydrated
    /// async after the milestone fires; if it doesn't resolve in time
    /// the celebration renders without the proof line.
    @State private var personalBestProof: ProofMoment? = nil
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

    private var currentMode: PracticeMode {
        if let explicitMode { return explicitMode }
        if imConversationDetails != nil { return .imConversation }
        let title = practiceTitle.lowercased()
        if title.contains("sudden") { return .suddenDeath }
        if title.contains("ah-counter") || title.contains("ah counter") { return .ahCounter }
        return .timed
    }

    private var isIMSummary: Bool { currentMode == .imConversation }
    private var isSuddenDeathSummary: Bool { currentMode == .suddenDeath }

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
    /// Maps the drill recommendation's primary skill area to a Weakness
    /// the AIRewriteService can act on. Returns nil for skill areas that
    /// don't have a rewrite path yet (filler reduction, pace, pauses,
    /// emphasis, confidence) — those are practice-mode interventions,
    /// not rewrite-the-script ones.
    private var primaryWeakness: AIRewriteService.Weakness? {
        switch drillRecommendationV2.skillArea {
        case .openingStrength:    return .opening
        case .closingStrength:    return .closing
        case .structure:          return .structure
        case .conciseSpeaking:    return .concise
        case .answerDevelopment:  return .structure
        case .fillerReduction, .paceControl, .pauseUsage, .vocalEmphasis, .confidence:
            return nil
        }
    }

    private var drillRecommendationV2: DrillRecommendationV2 {
        let categoryTuples = feedbackCategories.map { ($0.dimension, $0.rating.rawValue) }
        return DrillEngineV2.recommend(
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            wordCount: transcriptWordCount,
            score: scoreValue,
            feedbackCategories: categoryTuples,
            styleGoal: coachingProfileStore.profile?.speakingStyleGoal
        )
    }

    /// Skill trends across recent sessions.
    private var skillTrends: [SkillTrend] {
        TrendAnalyzer.analyze(snapshots: SkillTrendStore.shared.snapshots)
    }

    /// Three-part coach note: momentum, leverage, next step.
    /// Prefers the enhanced version from SessionFinalizer (baseline + pressure + style aware),
    /// falls back to simple computation before setup() has run. The fallback still
    /// passes `styleGoal` so the goal-aware enrichments (momentum / leverage /
    /// nextStep) fire even before SessionFinalizer's richer pass lands.
    private var coachNote: CoachNote {
        if let enhancedCoachNote { return enhancedCoachNote }
        let wpm = effectiveDuration > 0 ? Double(transcriptWordCount) / effectiveDuration * 60 : 0
        let categoryRatings = Dictionary(uniqueKeysWithValues: feedbackCategories.map { ($0.dimension, $0.rating.rawValue) })
        // Prompt-grounded relevance (initiative #8 follow-on): same read the
        // Relevance rating uses, so this pre-finalize fallback note shares the
        // "answered vs buried" signal with the richer SessionFinalizer pass +
        // the chat coach. Timed only; nil elsewhere keeps the note unchanged.
        let promptRelevanceRead: PracticeEvaluator.PromptRelevanceRead? =
            currentMode == .timed
            ? PracticeEvaluator.promptRelevance(prompt: sessionPrompt, transcript: transcriptText)
            : nil
        return VerdictEngine.generate(
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            wordCount: transcriptWordCount,
            wpm: wpm,
            score: scoreValue,
            categoryRatings: categoryRatings,
            trends: skillTrends,
            primaryFocus: drillRecommendationV2.skillArea,
            drillHistory: DrillHistoryStore.shared.entries,
            styleGoal: coachingProfileStore.profile?.speakingStyleGoal.title,
            promptRelevance: promptRelevanceRead
        )
    }

    private var currentPostRepCoachNote: PostRepCoachNote? {
        guard let sessionID = sessionStore.sessions.first?.id else { return nil }
        return postRepCoachNoteStore.note(for: sessionID)
    }

    private var postRepWinBullets: [WhatYouDidWellCard.Bullet] {
        WhatYouDidWellCard.computeBullets(
            coachNote: coachNote,
            feedbackCategories: feedbackCategories,
            eloquenceFindings: eloquenceFindings,
            aiFeedback: aiFeedback,
            isMinimalEffort: isMinimalEffort
        )
    }

    private var postRepFixBullets: [WhatToImproveCard.Bullet] {
        WhatToImproveCard.computeBullets(
            coachNote: coachNote,
            feedbackCategories: feedbackCategories,
            aiFeedback: aiFeedback,
            transcriptText: transcriptText,
            effectiveFillerCount: effectiveFillerCount,
            effectiveDuration: effectiveDuration,
            transcriptWordCount: transcriptWordCount,
            isMinimalEffort: isMinimalEffort,
            customFillerWords: ClutchWordStore.shared.customFillerWords
        )
    }

    /// Move #8 — ONE bounded delivery read for the verdict card. Fuses the
    /// SAME per-rep composure + confidence-marker engines the chat context
    /// reads for the most-recent rep (each self-suppresses below its
    /// 2-channel evidence floor; hedging + pace are relative to the user's
    /// own baseline, mirroring `CoachMemoryEngine.build`'s calibration).
    /// Nil whenever the finalized session isn't available yet or either
    /// read failed to form — the card simply omits the line. Never numeric.
    private var postRepDeliveryReadLine: String? {
        guard let session = sessionStore.sessions.first else { return nil }
        let baseline = baselineStore.baseline
        let composure = ComposureReadEngine.derive(
            session: session,
            hedgingPerMinute: baseline.hedgingRate.value
        )
        let confidence = ConfidenceMarkerEngine.derive(
            session: session,
            hedgingPerMinute: baseline.hedgingRate.value,
            paceWPM: baseline.pace.value,
            composure: composure
        )
        return PostRepDeliveryReadLine.make(
            composure: composure,
            confidence: confidence,
            mode: session.mode
        )
    }

    private var postRepVerdictContent: PostRepVerdictContent {
        PostRepVerdictContent.make(
            note: currentPostRepCoachNote,
            coachNote: coachNote,
            winBullets: postRepWinBullets,
            fixBullets: postRepFixBullets,
            proof: resolvedProof,
            isMinimalEffort: isMinimalEffort,
            deliveryReadLine: postRepDeliveryReadLine
        )
    }

    private var headline: String {
        if let lockedHeadlineOverride { return lockedHeadlineOverride }
        if let headlineOverride { return headlineOverride }
        if transcriptWordCount == 0 { return "No response detected" }
        if isMinimalEffort { return "Just getting started" }
        // If a Path landmark just unlocked on this rep, the headline
        // reads "Landmark reached." to anchor the story/progression
        // register the rest of the app uses. PathProgressManager queues
        // an unlocked node celebration via `pendingCelebrationNodeID`
        // when a session causes a node to satisfy its criteria. We read
        // it here without consuming — the PathNodeCelebration overlay
        // still consumes on its own fullScreenCover dismissal.
        if PathProgressManager.shared.pendingCelebrationNodeID != nil {
            return "Landmark reached"
        }
        switch scoreValue {
        case 9...10: return "Strong delivery"
        case 7...8: return "Good control"
        case 4...6: return "Building momentum"
        default: return "Room to grow"
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
            plan: CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile),
            imToneSignal: imToneDrillSignal,
            coachMemory: coachMemoryStore.currentMemory,
            recommendationOutcomes: recommendationLearningStore.outcomes
        )
    }

    /// The per-scenario tone-drill signal, shared with Home and the mode
    /// picker. When set, the post-rep "Looking ahead" card prescribes the
    /// exact scenario + tone to re-drill instead of a generic mode nudge.
    /// `if #available` guards the iOS-17 summary type so this unannotated
    /// view still compiles; `IMToneDrillSignal` itself is non-gated.
    private var imToneDrillSignal: IMToneDrillSignal? {
        guard IMModeAvailability.isAvailable else { return nil }
        if #available(iOS 17.0, *) {
            return IMHistorySummary.toneDrillSignal(from: sessionStore.sessions)
        }
        return nil
    }

    /// IM tone-drill SOLVED ribbon for the hero score card, gated to the
    /// *crossing rep* only — the rep that pushed a scenario's hit rate
    /// over the bar. Routes through `IMHistorySummary.toneDrillCrossing`
    /// (round 21) so this surface and the post-rep coach-note (the prose
    /// SOLVED-headlined sentence in `PracticeSessionFinalizer.
    /// recordPostRepCoachNote`) share one tested crossing primitive and
    /// can never drift apart — both light up on the same rep and never
    /// double-celebrate.
    ///
    /// Returns the display strings (scenario title + tone title) so the
    /// card can render without depending on the iOS-17-gated
    /// `IMHistorySummary` / `IMToneDrillResolved` types — the lookup
    /// happens here, the card stays pure presentation.
    ///
    /// nil when the just-finished rep isn't IM, when no scenario crosses
    /// on this rep, or when IM Mode is unavailable. The ribbon stays
    /// quiet rather than inventing a victory — same honesty contract as
    /// every other vision-aligned coach surface.
    private var heroToneDrillResolvedRibbon: HeroScoreCard.ToneDrillResolvedRibbon? {
        guard IMModeAvailability.isAvailable else { return nil }
        // Only IM reps can resolve an IM tone drill. The summary view's
        // own `imConversationDetails` carries the just-finished scenario,
        // matching how the finalizer scopes the crossing read.
        guard let details = imConversationDetails else { return nil }
        if #available(iOS 17.0, *) {
            // Latest session in the store is the just-finalized rep
            // (`PracticeSessionStore` prepends). Pass its id to the
            // helper so the with-vs-without-this-rep comparison is
            // order-independent — same primitive the finalizer uses.
            guard let currentRepId = sessionStore.sessions.first?.id else { return nil }
            let scenario = details.setup.scenario
            guard let crossed = IMHistorySummary.toneDrillCrossing(
                in: sessionStore.sessions,
                scenario: scenario,
                currentRepId: currentRepId
            ) else { return nil }
            return HeroScoreCard.ToneDrillResolvedRibbon(
                scenarioTitle: scenario.title,
                toneTitle: crossed.targetTone.title
            )
        }
        return nil
    }

    private var recentWindowSummary: String {
        guard !recentWindow.isEmpty else { return "No recent sessions yet." }
        return recentWindow.map { session in
            let label: String
            label = session.mode.displayLabel
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

    /// Feeds the recommendation engine's input. Reads the freeze-aware
    /// displayed streak (StreakFreezeManager is the single displayed-streak
    /// owner) so any coach copy that references a streak can never claim a
    /// number the user doesn't see on Home/Profile.
    private var sessionStreak: Int {
        streakFreeze.currentStreak
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
            return ["First rep saved. Complete another rep to start comparing."]
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

    /// Parent-level choreography delay. Child celebration views already
    /// collapse their own motion; this also removes the otherwise invisible
    /// waits between them when Reduce Motion is enabled.
    private func motionDelay(_ fullMotionDuration: Double) -> Double {
        reduceMotion ? 0 : fullMotionDuration
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            if let selectedInterstitial {
                switch selectedInterstitial {
                case .personalBest:
                    if let milestone = personalBestMilestone {
                        personalBestCelebration(milestone: milestone)
                            .transition(reduceMotion ? .identity : .opacity)
                    }
                case .skillProgress:
                    PreSummaryCelebration(events: preSummaryEvents) {
                        finishInterstitial()
                    }
                    .transition(reduceMotion ? .identity : .opacity)
                case .achievementProgress:
                    PostSessionProgressionView(
                        xpEarned: xpEarned,
                        previousXP: progressionPreviousXP,
                        newXP: profile.xp,
                        previousLevel: currentLevel,
                        newLevel: ProfileManager.levelTitle(forXP: profile.xp),
                        achievementProgress: progressionDeltas,
                        newUnlocks: progressionNewUnlocks,
                        onContinue: finishInterstitial
                    )
                    .transition(reduceMotion ? .identity : .opacity)
                case .practiceVolume:
                    LevelUpCelebrationScreen(
                        newLevel: PracticeVolumeNarration.title(forXP: profile.xp),
                        previousLevel: PracticeVolumeNarration.title(forXP: progressionPreviousXP),
                        xp: profile.xp,
                        xpProgress: progress,
                        onContinue: finishInterstitial
                    )
                    .transition(reduceMotion ? .identity : .opacity)
                }
            } else {
                // Normal summary content — redesigned hierarchy
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // MODE CONSISTENCY NOTE (M20):
                        // IM, Sudden Death and Timed/other share TalkToNoumCTACard
                        // as the single Ask Noum entry point. Sudden Death keeps an
                        // arcade-style result hero while its cards below remain
                        // coaching-first. Remaining divergences to address later:
                        //   - IM lacks BaselineComparisonCard equivalents for
                        //     WhatYouDidWell / WhatToImprove (uses IMReadCard instead)
                        //   - Ah-Counter has no dedicated mode-specific verdict card
                        //     (falls into the Timed/other path — acceptable for now)
                        if isIMSummary {
                            // IM MODE — same 5-slot order as the timed
                            // path (hero / read / move / one Ask door /
                            // exit). IM has no verified ProofMoment
                            // surface, so there is no WIN slot — known
                            // gap; never fabricate one. The revised-read
                            // acknowledgment folds into the read and a
                            // due case review becomes the named next
                            // move, mirroring the timed fold.
                            IMVerdictCard(
                                scoreValue: scoreValue,
                                scoreAccent: scoreAccent,
                                scoreEmoji: scoreEmoji,
                                headline: headline,
                                effectiveFillerCount: effectiveFillerCount,
                                effectiveDuration: effectiveDuration,
                                imConversationDetails: imConversationDetails
                            )
                            .cardEntrance(0)
                            IMDebriefCard(
                                coachNote: coachNote,
                                effectiveDuration: effectiveDuration,
                                imConversationDetails: imConversationDetails,
                                revisedChange: freshRevisedReadChange,
                                reviewIntervention: activeReviewDueIntervention,
                                onReview: activeReviewDueIntervention.map { intervention in
                                    { onAskNoumAboutRep?(interventionReviewOpener(for: intervention)) }
                                }
                            )
                            .cardEntrance(1)
                            SummaryRepeatActionCard(
                                exerciseName: currentMode.displayLabel,
                                onStart: onPracticeAgain,
                                onAdjust: onSelectPracticeMode
                            )
                            .cardEntrance(2)
                            TalkToNoumCTACard(
                                isPremium: premium.isPremium,
                                speakingStyleGoal: coachingProfileStore.profile?.speakingStyleGoal,
                                onAskNoum: {
                                    onAskNoumAboutRep?(talkToNoumOpener)
                                },
                                onUpgradePrompt: {
                                    showPaywall = true
                                }
                            )
                            .cardEntrance(3)
                            expandableDetailsSection.cardEntrance(4)
                            SummaryExitPanel(onDone: onHome).cardEntrance(5)
                        } else {
                            // TIMED / AH-COUNTER / SUDDEN DEATH hierarchy.
                            // The post-rep attention budget is small; only the
                            // signals that fight for "what happened, what was
                            // proven, what to do next" stay above the fold.
                            // Everything analytical/secondary lives inside
                            // `expandableDetailsSection` below.
                            if isSuddenDeathSummary {
                                SuddenDeathReviewCard(
                                    points: suddenDeathGamePoints ?? 0,
                                    multiplierLabels: suddenDeathMultiplierLabels,
                                    tiersCleared: progressSegments,
                                    fillerCount: effectiveFillerCount,
                                    duration: effectiveDuration,
                                    wordCount: suddenDeathTotalWords ?? transcriptWordCount
                                )
                                .cardEntrance(0)
                            } else {
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
                                    celebrationVisible: celebrationVisible,
                                    belowEvidenceFloor: isMinimalEffort,
                                    toneDrillResolvedRibbon: heroToneDrillResolvedRibbon
                                )
                                .cardEntrance(0)
                            }
                            // One bounded coaching pass. The existing read,
                            // proof and fix selectors still feed
                            // PostRepVerdictContent; presentation is composed
                            // into one surface so the user reads it as a story.
                            PostRepDebriefCard(
                                content: postRepVerdictContent,
                                revisedChange: freshRevisedReadChange,
                                reviewIntervention: activeReviewDueIntervention,
                                onReview: activeReviewDueIntervention.map { intervention in
                                    { onAskNoumAboutRep?(interventionReviewOpener(for: intervention)) }
                                }
                            )
                            .cardEntrance(1)
                            SummaryDrillActionCard(
                                drill: drillRecommendationV2,
                                legacyDrill: drillRecommendation,
                                onStartMiniDrill: { drill in
                                    activeMiniDrill = drill
                                },
                                onStartDrill: onStartDrill
                            )
                            .cardEntrance(2)
                            TalkToNoumCTACard(
                                isPremium: premium.isPremium,
                                speakingStyleGoal: coachingProfileStore.profile?.speakingStyleGoal,
                                onAskNoum: {
                                    onAskNoumAboutRep?(talkToNoumOpener)
                                },
                                onUpgradePrompt: {
                                    showPaywall = true
                                }
                            )
                            .cardEntrance(3)
                            expandableDetailsSection.cardEntrance(4)
                            SummaryExitPanel(onDone: onHome).cardEntrance(5)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .confirmationDialog("Share Session", isPresented: $showShareMenu) {
                    ShareLink(
                        item: shareImage,
                        preview: SharePreview(isSuddenDeathSummary ? "My Pressure Drill Run" : "My Noum Score", image: shareImage)
                    ) {
                        Label(isSuddenDeathSummary ? "Share Run Card" : "Share Achievement Card", systemImage: "photo.fill")
                    }
                    if !isSuddenDeathSummary {
                        Button {
                            // SwiftUI guards against two presentations at once — if we
                            // flip the sheet binding here, it races the dialog dismissal
                            // and the runtime drops the sheet with "Currently, only
                            // presenting a single sheet is supported." Defer the binding
                            // flip until the dialog has fully dismissed.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                                showFeedbackRequestSheet = true
                            }
                        } label: {
                            Label("Request feedback", systemImage: "person.2.fill")
                        }
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
                .sheet(isPresented: $showAIDisclosure) {
                    CloudProcessingConsentDisclosure(
                        isCurrentlyAllowed: aiSettings.isCloudProcessingAllowed,
                        onAllow: {
                            aiSettings.recordCloudProcessingDecision(.allowed)
                            showAIDisclosure = false
                            switch pendingCloudProcessingAction {
                            case .coachRead:
                                Task { await requestDeeperFeedback() }
                            case .videoAnalysis:
                                analyzeVideo()
                            }
                        },
                        onNotNow: {
                            aiSettings.recordCloudProcessingDecision(.declined)
                            showAIDisclosure = false
                        }
                    )
                }
                // VoiceOver escape: back-nav is hidden and swipe-back is
                // disabled by design, and the only Done now lives at the
                // END of the scroll. Expose a rotor action so a
                // non-visual user is never trapped scrolling to exit.
                .accessibilityAction(named: Text("Done")) {
                    onHome()
                }
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))

                if celebrationVisible && !reduceMotion {
                    celebrationOverlay
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }

            }
        }
        .overlay {
            if selectedInterstitial == nil {
                // Summary intentionally hides navigation chrome. Keep a
                // quiet, persistent safe-area scrim so scrolled coaching
                // never competes with the status-bar clock and indicators.
                GeometryReader { geometry in
                    VStack(spacing: 0) {
                        AppColor.screenBackground
                            .frame(maxWidth: .infinity)
                            .frame(
                                height: SummaryTopSafeAreaCoverLayout.height(
                                    for: geometry.safeAreaInsets.top
                                )
                            )
                        Spacer(minLength: 0)
                    }
                    .ignoresSafeArea(edges: .top)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .disableSwipeBack()
        .onAppear(perform: setup)
        .onDisappear {
            if selectedInterstitial != nil {
                skillProgression.consumeAll()
            }
        }
        // Iteration 1: load the transcript-verified proof moment on every
        // summary (not just the personal-best celebration) so the WIN card
        // can lead with the user's own strongest line. Nil on a miss.
        .task { await loadPersonalBestProof() }
        .sheet(isPresented: $showVideoPlayback) {
            if let recordingURL {
                VideoPlaybackView(url: recordingURL)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
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
                styleGoal: coachingProfileStore.profile?.speakingStyleGoal,
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
            // "More from this rep" (collapsed by default) — the ONE
            // disclosure every demoted surface lives behind.
            //
            // Holds the analytical pass: per-skill breakdowns (eloquence,
            // pauses, pitch, word-choice, grammar, filler chips), the IM
            // signal pills + baseline comparison (demoted from above the
            // fold), the premium deep read + rewrite, video playback +
            // AI analysis, the share row, the session comparison, the
            // looking-ahead nudge and the deferred reflection prompt.
            // None of these are wrong to see — they just shouldn't fight
            // the coach's read, the score, and the next move for the
            // user's first three seconds.
            DisclosureGroup(isExpanded: $showSecondaryDetails) {
                VStack(spacing: 14) {
                    // Practice credit — visible-but-demoted (progression
                    // spine): the verdict above the fold stays score +
                    // read + win + fix; the XP that accrued this rep
                    // reads as a quiet volume caption in here. Self-hides
                    // when nothing accrued (never renders "+0").
                    if let credit = PracticeVolumeNarration.verdictCreditLine(
                        xpEarned: xpEarned,
                        eloquenceBonus: EloquenceXP.totalXP(for: eloquenceFindings)
                    ) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus.circle")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.secondary)
                            Text(credit)
                                .font(Typography.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Practice credit: \(credit)")
                    }

                    // Inline reflection prompt — kept discoverable but
                    // out of the hero block so it never interrupts the
                    // coach's read. Self-hides when nothing is pending.
                    if !isIMSummary {
                        DeferredCaptureInlineCard()
                        // One-tap "how did that rep feel?" intake — feeds
                        // SessionReflectionStore -> CoachReflectionPattern so
                        // the coach's case carries the user's own read, not
                        // just telemetry. Optional (scrolling past declines);
                        // collapses to a quiet "Noted" line once answered.
                        ReflectionCaptureRow(sessionID: latestSessionID)
                    }

                    // IM analytics — demoted behind the chevron in the
                    // same pass that demoted them for the timed path
                    // (M25 dropped BaselineComparisonCard from timed for
                    // blurring this-rep signal; the live IM rep already
                    // cut its numeric trust/tension chips). Post-rep
                    // pills are the dashboard echo, not the read.
                    if isIMSummary {
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
                    }

                    // M25: AISessionDebriefCard removed as a standalone
                    // surface — its content (post-hoc AI insight) now
                    // folds into the hero CoachReadCard's "Deep analysis"
                    // tap-to-reveal. One coach voice card, one source
                    // of truth.

                    // Speech-quality cards — each self-hides when there
                    // isn't enough signal to read, so the disclosure
                    // collapses to whatever the rep actually produced.
                    if !isIMSummary {
                        EloquenceFindingsCard(findings: eloquenceFindings)
                        if let pauseMetrics = sessionStore.sessions.first?.pauseMetrics {
                            PauseSummaryCard(metrics: pauseMetrics)
                        }
                        if let pitchMetrics = sessionStore.sessions.first?.pitchMetrics {
                            PitchSummaryCard(metrics: pitchMetrics)
                        }
                        // Positional read — WHERE the rep's notable moments
                        // fell (opening/middle/close). The visible companion
                        // to the coach's positional prompt block; self-hides
                        // (engine returns nil) when no credible positional
                        // signal exists, so it never pads a non-finding.
                        if let eventLocations = sessionStore.sessions.first?.repEventLocations {
                            RepTimelineCard(locations: eventLocations)
                        }
                        // Recurring-position trend — the LONGITUDINAL companion
                        // to the per-rep positional card above. Self-hides
                        // (engine returns []) until a position has recurred
                        // across the recent window past the honesty floors, so
                        // it names a habit only when one has genuinely earned it.
                        let positionalTrends = RepEventTrendEngine.compute(sessions: sessionStore.sessions)
                        if !positionalTrends.isEmpty {
                            RepEventTrendCard(trends: positionalTrends)
                        }
                        let wordChoiceMetrics = WordChoiceMetrics.compute(transcript: transcriptText)
                        WordChoiceCard(metrics: wordChoiceMetrics)
                        GrammarPolishCard(session: sessionStore.sessions.first)

                        // Honest empty-state — when the rep produced no
                        // readable speech-quality analytics AND the user is
                        // early enough that a recurring-position read can't
                        // have formed, name the restraint out loud instead of
                        // leaving "More from this rep" hollow (reads like a
                        // bug). Self-hides the instant any card gains signal;
                        // stays silent for a mature user's quiet rep so it
                        // never nags or overclaims (`SummaryAnalyticsEmptyState`).
                        if let analyticsEmptyState = SummaryAnalyticsEmptyState.message(
                            isIMSummary: isIMSummary,
                            repCount: sessionStore.sessions.count,
                            signals: SummaryAnalyticsEmptyState.Signals(
                                hasEloquence: !eloquenceFindings.isEmpty,
                                hasPause: sessionStore.sessions.first?.pauseMetrics != nil,
                                hasPitch: sessionStore.sessions.first?.pitchMetrics != nil,
                                hasPositional: sessionStore.sessions.first?.repEventLocations != nil,
                                hasTrend: !positionalTrends.isEmpty,
                                hasWordChoice: wordChoiceMetrics.contentWordCount >= WordChoiceMetrics.minContentWords
                            )
                        ) {
                            HStack(alignment: .top, spacing: Spacing.sm) {
                                Image(systemName: "hourglass")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                Text(analyticsEmptyState)
                                    .font(Typography.body)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                            .padding(Spacing.lg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(analyticsEmptyState)
                            .accessibilityIdentifier("summary.analyticsEmptyState")
                        }
                        // M25: FillerBreakdownCard dropped — its top-6 chips
                        // duplicated the top-3 chips WhatToImproveCard already
                        // surfaces in its filler bullet, and the "fillers tend
                        // to cluster at transitions" coaching note now lives
                        // in CoachReadCard's voice-shaped read.

                        // Pro-gated rewrite card — preserves the user's
                        // voice instead of producing AI-default coaching
                        // text. Only renders when there's a clear
                        // weakness category to act on AND the user is Pro.
                        if let weakness = primaryWeakness, premium.isPremium {
                            RewriteSuggestionCard(
                                transcript: transcriptText,
                                weakness: weakness
                            )
                        }

                        // Premium deep read — the rescued entry point for
                        // `requestDeeperFeedback`. The old standalone
                        // "Generate Coach Read" card was only mounted from
                        // dead code, which left the whole AI deeper-read
                        // path unreachable while the Pro pitch still
                        // advertised it. It lives here as quiet premium
                        // depth behind the chevron.
                        if premium.isPremium {
                            deepReadCard
                        }

                        // M25: BaselineComparisonCard dropped here —
                        // its data (rating, peak, strengths, baseline
                        // pace/fillers) lives in Profile and the Trends
                        // chart. Reading it on every summary blurred the
                        // signal of THIS rep's read.
                    }

                    // M25: transcriptDetailCard dropped — transcript is
                    // available via the recording playback (Pro) and
                    // history detail view. Surfacing the raw paragraph
                    // on every summary added a heavy block users
                    // skimmed past. Privacy posture also benefits.

                    // M25: categoryGrid dropped — the 7-dimension chip
                    // grid restated what WhatToImproveCard already
                    // distilled into a coach-voice bullet. The grid
                    // read as a dashboard, not a coach.

                    // M25: aiMomentsContent dropped — strong/weak moment
                    // lists overlapped with WhatYouDidWellCard +
                    // WhatToImproveCard. The hero cards carry the same
                    // arc in voice; the lists were the dashboard echo.

                    // M25: Pro `coachReadCard` (strengths + key improvement)
                    // dropped — it was the third coach-voice surface on the
                    // same screen (after CoachReadCard at hero and
                    // AISessionDebriefCard inside this disclosure). Its data
                    // is already represented by WhatYouDidWellCard +
                    // WhatToImproveCard above the fold.

                    // Video playback + (premium) AI video analysis. The
                    // analyze entry is the rescued counterpart of the Pro
                    // pitch's "video analysis" claim — the old recording
                    // card that carried it was only mounted from dead code.
                    if recordingURL != nil {
                        videoPlaybackButton
                        if premium.isPremium {
                            videoAnalysisSection
                        }
                    }

                    // Session comparison
                    sessionComparisonCard

                    // Share / request feedback — re-homed from the cut
                    // pinned action bar. The confirmation dialog (share
                    // card + request feedback) hangs off the scroll view.
                    shareRow

                    // Quiet "what to do next session" hint — demoted
                    // INSIDE the chevron so it never competes with FIX
                    // FIRST or the exit panel's drill CTA for "what next."
                    //
                    // Round 19: when an `onStartLookingAhead` callback is
                    // wired, the card renders a subordinate "Start <Mode>"
                    // CTA. The destination is computed *inside the per-tap
                    // closure* (not at init time) because
                    // `summaryRecommendation` depends on view-side
                    // `@StateObject`s the path init doesn't have in scope.
                    // The router stays the single source of truth for the
                    // mode → destination mapping (same router the home
                    // coach card + ContentView suggestion tile call into).
                    if let lookingAhead = lookingAheadHint {
                        LookingAheadCard(
                            hint: lookingAhead,
                            onStart: onStartLookingAhead.map { callback in
                                {
                                    let destination = SummaryLookingAheadRouter.destination(
                                        for: summaryRecommendation,
                                        imAvailable: IMModeAvailability.isAvailable
                                    )
                                    callback(destination)
                                }
                            }
                        )
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(CohesiveSummaryCopy.seeDetails)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .tint(.secondary)
            .padding(.horizontal, Spacing.xs)
        }
    }

    /// Quiet share entry inside More-from-this-rep — the surviving home
    /// of the action-bar Share button. Opens the same confirmation
    /// dialog (achievement card + request feedback).
    private var shareRow: some View {
        Button {
            showShareMenu = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "square.and.arrow.up")
                    .font(.caption.weight(.semibold))
                Text("Share this rep")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppColor.brandBlue)
        }
        .accessibilityIdentifier("summary.details.share")
    }

    /// Premium AI video analysis entry + result, next to Watch recording.
    private var videoAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                analyzeVideo()
            } label: {
                HStack(spacing: 8) {
                    if isAnalyzingVideo {
                        ProgressView()
                            .tint(.secondary)
                            .scaleEffect(0.7)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.caption.weight(.semibold))
                    }
                    Text(isAnalyzingVideo ? "Analyzing…" : "Analyze delivery")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(AppColor.brandBlue)
                .frame(minHeight: 44, alignment: .leading)
            }
            .disabled(isAnalyzingVideo)
            .accessibilityIdentifier("summary.details.analyzeVideo")

            if let result = videoAnalysisResult {
                videoAnalysisResultView(result)
            }
        }
    }

    /// Computed "next session" suggestion derived from the existing
    /// `RecommendationBiasBlueprint`. Returns nil when there's no useful
    /// hint — staying quiet beats forcing advice the data can't back.
    private var lookingAheadHint: LookingAheadCard.Hint? {
        // Need at least 3 sessions of signal before nudging direction —
        // checked first so we skip the blueprint computation on early reps.
        guard sessionStore.sessions.count >= 3 else { return nil }
        let blueprint = summaryRecommendation
        // No need to suggest the mode the user just finished.
        guard blueprint.recommendedMode != currentMode || blueprint.source == .caseIntervention else { return nil }
        return LookingAheadCard.Hint(
            mode: blueprint.recommendedMode,
            whyMode: blueprint.modeBenefit,
            whyNow: blueprint.whyNow,
            styleGoal: coachingProfileStore.profile?.speakingStyleGoal
        )
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

    private func ratingColor(_ rating: FeedbackRating) -> Color {
        switch rating {
        case .good: return AppColor.positive
        case .ok: return AppColor.caution
        case .couldImprove: return AppColor.caution
        }
    }

    private func videoAnalysisResultView(_ result: VideoAnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()

            Text("Delivery analysis")
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

    // MARK: - Deep Read (premium, inside More-from-this-rep)

    /// S2: the empty-state line for the deep-read card (shown before an AI read
    /// has been generated). When the user has EXPLICITLY chosen a voice, lead
    /// with the CoachPersona-derived chosen-voice line so the card reflects the
    /// choice even with no model output yet; otherwise keep the original generic
    /// CTA verbatim. Single source of truth = `chosenStyleGoal` (the helper
    /// returns nil for an un-chosen profile). Deterministic, no model call, no
    /// numeric score touched.
    private var coachReadEmptyStateLine: String {
        let genericCTA = "Generate a deeper coaching read from this session's transcript."
        if let voiceLead = coachingProfileStore.profile?.chosenVoiceCoachingLead {
            return voiceLead + " " + genericCTA
        }
        return genericCTA
    }

    /// The rescued premium deep-read surface (entry + result for
    /// `requestDeeperFeedback`). Lives behind the More-from-this-rep
    /// chevron so it reads as depth, not a competing coach voice.
    private var deepReadCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Deep read")
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
                // S2: voice-shape the empty-state line when the user has
                // EXPLICITLY chosen a voice, so even before the AI read is
                // generated the card reflects the chosen voice. Gated via the
                // nil-returning helper on `chosenStyleGoal` (NOT the always-
                // populated `speakingStyleGoal`), so an un-chosen profile keeps
                // the original generic line. AICoachFeedback content + the
                // numeric score are untouched; this is the empty-state copy only.
                Text(coachReadEmptyStateLine)
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
                    if aiSettings.isCloudProcessingAllowed {
                        Task { await requestDeeperFeedback() }
                    } else {
                        pendingCloudProcessingAction = .coachRead
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

    // MARK: - Ask Noum session-anchored opener

    private var sessionAnchoredOpener: String {
        CoachContextBuilder.sessionOpener(
            mode: currentMode,
            score: isSuddenDeathSummary ? nil : score,
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            voice: coachingProfileStore.profile?.speakingStyleGoal
        )
    }

    // MARK: - Talk-to-Noum opener gate
    //
    // Round 29 — when the same `freshRevisedReadChange` gate that mounts the
    // `RevisedReadCard` on the summary screen is hot, a tap on the
    // `TalkToNoumCTACard` dispatches the case-anchored revised-read opener
    // instead of the generic `sessionOpener`. Picking up the chat thread
    // where the post-rep card left off — the user already saw "you flagged
    // the prior read as off; here's the revised one" on the summary; the
    // chat seed names the same shift and invites the coach to pick up the
    // case file. Falls back to `sessionAnchoredOpener` on any rep where no
    // fresh user-pushback adaptation landed, so the generic-rep behaviour
    // is unchanged. Pure routing — eligibility logic lives in one place
    // (`freshRevisedReadChange`), the opener composition lives on
    // `CoachContextBuilder`, this property is the one home that picks
    // between them.
    //
    // Round 35 — the call routes through the `revisedReadOpener(for:…)`
    // overload, passing the `change` itself so the second-cycle composer
    // fires when `change.documentsSecondCyclePushback` is true (round 33's
    // marker). The chat seed mirrors the post-rep card's round-34
    // second-cycle copy split: the user reads "I flagged the rebuilt read
    // as off too" on the same rep the card named the same pushback in
    // user-verdict voice. The eligibility predicate
    // (`freshRevisedReadChange`) is unchanged — only the composition
    // splits per cycle.

    private var talkToNoumOpener: String {
        if let change = freshRevisedReadChange {
            return CoachDisplayCopy.normalized(
                CoachContextBuilder.revisedReadOpener(
                    for: change,
                    workingHypothesis: coachMemoryStore.currentMemory?.workingHypothesis,
                    voice: coachingProfileStore.profile?.speakingStyleGoal
                )
            )
        }
        return sessionAnchoredOpener
    }

    // MARK: - Intervention-review prompt
    //
    // Returns the active case-file intervention when the review
    // cadence has elapsed AND the followed-rep evidence threshold is
    // met. Both gates are inside `CoachIntervention.isReviewDue(at:)`
    // — this surface stays a thin reader so a future tweak to the
    // predicate (e.g. an additional confidence floor) lands in one
    // place. Returns nil when there is no memory, no active
    // intervention, or the predicate falls.

    private var activeReviewDueIntervention: CoachIntervention? {
        guard let memory = coachMemoryStore.currentMemory,
              let intervention = memory.activeIntervention,
              intervention.isReviewDue(at: Date()) else { return nil }
        return intervention
    }

    // MARK: - Revised-read card (post-rep user-pushback surface)
    //
    // Returns the latest `CoachCourseChange` iff it both (a) documents a
    // user-tapped rejection of the prior working hypothesis and (b) was
    // appended on the same rebuild that produced the current memory.
    // Round 34 collapses the local predicate through
    // `CoachContextBuilder.freshRevisedReadChange(in:)` (round 31's
    // pure-function lift) so the eligibility contract is shared with
    // the chat-coach context block, the round-29 revised-read opener,
    // and the round-30 follow-up chip row — one call site away. The
    // engine-side predicates (`documentsUserPushback`, `isFresh`) still
    // live on `CoachCourseChange`, so an edit there ripples to every
    // surface that gates on the same pair. See `RevisedReadCard` for
    // the rendering contract.

    private var freshRevisedReadChange: CoachCourseChange? {
        guard let memory = coachMemoryStore.currentMemory else { return nil }
        return CoachContextBuilder.freshRevisedReadChange(in: memory)
    }

    /// Build the case-anchored opener for the review CTA. Routes
    /// through `CoachContextBuilder.interventionReviewOpener` so the
    /// voice-mapping contract lives next to the existing
    /// `sessionOpener` voice mapping — one home for both.
    private func interventionReviewOpener(for intervention: CoachIntervention) -> String {
        CoachDisplayCopy.normalized(
            CoachContextBuilder.interventionReviewOpener(
                intervention: intervention,
                voice: coachingProfileStore.profile?.speakingStyleGoal,
                reflectionPattern: coachMemoryStore.currentMemory?.reflectionPattern
            )
        )
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

            if isSuddenDeathSummary {
                VStack(spacing: 2) {
                    Text((suddenDeathGamePoints ?? 0).formatted())
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(shareModeTint)
                    Text("POINTS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1.2)
                }
                .padding(.bottom, 16)
            } else {
                // Hero score
                ZStack {
                    Circle()
                        .stroke(shareModeTint.opacity(0.12), lineWidth: 3)
                        .frame(width: 140, height: 140)

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
            }

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
                if isSuddenDeathSummary {
                    shareStatCell(value: "\(progressSegments)", label: "Cleared", tint: shareModeTint)
                    shareDivider
                    shareStatCell(value: "\(Int(effectiveDuration))s", label: "Time", tint: AppColor.brandBlue)
                    shareDivider
                    shareStatCell(value: "\(suddenDeathTotalWords ?? transcriptWordCount)", label: "Words", tint: .white)
                } else {
                    shareStatCell(value: "\(effectiveFillerCount)", label: "Fillers", tint: fillerTint)
                    shareDivider
                    shareStatCell(value: "\(Int(effectiveDuration))s", label: "Duration", tint: AppColor.brandBlue)
                    shareDivider
                    shareStatCell(value: "\(shareWPM)", label: "WPM", tint: AppColor.modeSuddenDeath)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.top, 12)

            // Footer
            HStack {
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

    // MARK: - Personal Best Celebration (Full-Screen Intermediary)

    /// Honesty gate for the full post-rep celebration (Iteration 1 / reward
    /// ownership). Returns true ONLY when SessionFinalizer detected a real
    /// crossing. `score` and `xpEarned` are accepted but intentionally ignored
    /// so a test can pin that neither a high score nor an XP threshold triggers
    /// a celebration on its own (the prior `score>=7 || xp>=100` bug).
    static func shouldShowCelebration(hasMilestoneCrossing: Bool, score: Int, xpEarned: Int) -> Bool {
        hasMilestoneCrossing
    }

    private func personalBestCelebration(milestone: MilestoneEvent) -> some View {
        PersonalBestCelebrationScreen(
            scoreValue: scoreValue,
            scoreAccent: scoreAccent,
            modeName: currentMode.displayLabel,
            previousBest: milestone.detail,
            onContinue: finishInterstitial,
            proof: resolvedProof
        )
        .onAppear {
            Task { await loadPersonalBestProof() }
        }
    }

    /// Clears the complete post-rep interstitial budget in one transition.
    /// Pending skill events are consumed whether or not they won priority so
    /// an unshown event can never leak into the next rep.
    private func finishInterstitial() {
        skillProgression.consumeAll()
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            selectedInterstitial = nil
        }
    }

    /// The proof-extraction input for the just-finished session, or nil
    /// when no qualifying session exists (empty transcript or a ≤8s misfire
    /// rep). The most recent session in the store is the one we just
    /// finalized. Shared by the synchronous first-frame proof and the async
    /// upgrade so both read identical state.
    private var proofInput: ProofMomentInput? {
        let recent = PracticeSessionStore.shared.sessions
            .sorted { $0.date > $1.date }
            .first
        guard let session = recent,
              !session.transcript.isEmpty,
              session.duration > 8 else {
            return nil
        }
        let baseline = BaselineStore.shared.baseline
        let profile = CoachingProfileStore.shared.profile
        return ProofMomentInput(
            session: session,
            voice: profile?.speakingStyleGoal,
            goalParaphrase: profile?.displayableGoal,
            baselineFillerRate: baseline.fillerRate.confidence != .insufficient
                ? baseline.fillerRate.value : nil,
            baselinePace: baseline.pace.confidence != .insufficient
                ? baseline.pace.value : nil
        )
    }

    /// The proof shown in the post-rep beat. Prefers the hydrated (possibly
    /// AI-upgraded) `personalBestProof`; otherwise falls back to the
    /// synchronous, network-free deterministic extraction so the verified
    /// quote and its "Your words" provenance line paint on the FIRST frame
    /// instead of staggering in ~0.5s after the WIN card — Noum quoting the
    /// user's own verified words is the single most coach-like beat and must
    /// not fracture. `deterministicProof` is a pure static function (no actor
    /// hop, no network, no main-actor blocking), so there is zero added risk
    /// on the finalize/summary path. The async `loadPersonalBestProof` still
    /// runs to upgrade the claim wording when an AI provider is live; the
    /// verbatim quote is identical on both paths.
    private var resolvedProof: ProofMoment? {
        if let personalBestProof { return personalBestProof }
        guard let input = proofInput else { return nil }
        return ProofMomentService.deterministicProof(for: input)
    }

    /// Upgrade the first-frame deterministic proof to an AI-backed claim when
    /// a provider is live. Falls through to nil on miss; `resolvedProof`
    /// keeps showing the deterministic proof (or nothing) in that case.
    private func loadPersonalBestProof() async {
        guard let input = proofInput else {
            personalBestProof = nil
            return
        }
        let proof = await ProofMomentService.shared.proof(for: input)
        await MainActor.run {
            withAnimation(reduceMotion ? nil : .standardSpring) {
                personalBestProof = proof
            }
        }
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
        case .standard, .frameworkCheck:
            // Framework drills (STAR turn / claim-counter / elevator pitch) reuse
            // the standard recording UI; the named-framework structural verdict
            // is computed post-hoc in `finishDrill` and surfaces in the result
            // copy — no dedicated screen.
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

        // Sudden Death commits lifecycle effects on run completion so replay
        // can never skip earned progress. Other modes still commit here.
        let result = committedFinalization ?? SessionFinalizer.finalize(
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
            pressureLevel: recentSessions.first?.pressureLevel ?? .standard,
            transcript: transcriptText
        )

        progressionDeltas = result.achievementDeltas
        progressionNewUnlocks = result.newUnlocks
        enhancedCoachNote = result.coachNote
        eloquenceFindings = result.eloquenceFindings
        // Source of truth for pre-rep XP is the finalizer result — for
        // Sudden Death the commit happened at run completion, so the
        // setup()-time profile.xp snapshot would already include the rep.
        progressionPreviousXP = result.previousXP

        animateXP(to: result.newXP)
        // HeroScoreCard now owns the score-reveal beat — its ring draws in
        // on appear and the haptic + verdict thump fire on the settle
        // frame so the channels land together. The two verdicts without
        // an animated ring (IM, Pressure Drill) keep the immediate
        // punctuation here — same moment, same two channels.
        if isIMSummary || isSuddenDeathSummary {
            CoachHaptic.scoreReveal()
            InteractionSoundEngine.cue(.verdictReveal)
        }

        // Capture milestone payloads first, then let one pure policy decide
        // which (if any) earns the full-screen attention budget.
        if let milestone = result.milestone {
            if milestone.title == "New personal best." {
                personalBestMilestone = milestone
            }
        }

        preSummaryEvents = skillProgression.pendingLevelUps
        let completedRepCount = sessionStore.sessions.count
        selectedInterstitial = SummaryInterstitialPolicy.select(
            completedRepCount: completedRepCount,
            hasPersonalBest: personalBestMilestone != nil,
            hasSkillProgress: !preSummaryEvents.isEmpty,
            hasAchievementProgress: result.showProgressionScreen && !isSuddenDeathSummary,
            hasPracticeVolumeLevel: result.isLevelUp
        )

        // First-rep celebration used to stack on top of the summary. The
        // cohesive pass deliberately starts with the useful coaching read;
        // dismissing here also marks the once-only manager so it cannot leak
        // into a later rep.
        if completedRepCount == 1 {
            FirstRepCelebrationManager.shared.dismiss()
        }

        // Only the skill-progress interstitial consumes events as it renders.
        // Every other choice (including no choice) records progression
        // silently and drains pending presentation state immediately.
        if selectedInterstitial != .skillProgress {
            skillProgression.consumeAll()
        }

        // The hero's restrained score beat waits until the single earned
        // interstitial has cleared. It never adds a second celebration on top
        // of the selected full-screen beat.
        let celebrationDelay = motionDelay(selectedInterstitial == nil ? 0 : 0.5)
        let revealDelay = motionDelay(0.8)
        Task {
            if celebrationDelay > 0 {
                try? await Task.sleep(for: .seconds(celebrationDelay))
            }
            await MainActor.run {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                    // Reward ownership (Iteration 1): the full celebration fires
                    // ONLY on a real crossing detected by SessionFinalizer (personal
                    // best / level-up / streak / count milestone) — never on a score
                    // or XP threshold, and never on the first rep (count milestones
                    // start at 10, streak at 3, no PB on rep 1). The score-ring
                    // count-up + haptic stays the honest per-rep beat.
                    celebrationVisible = selectedInterstitial == nil && completedRepCount > 1 && Self.shouldShowCelebration(
                        hasMilestoneCrossing: result.milestone != nil,
                        score: scoreValue,
                        xpEarned: xpEarned
                    )
                }
            }
            if revealDelay > 0 {
                try? await Task.sleep(for: .seconds(revealDelay))
            }
            await MainActor.run {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { coachNoteRevealed = true }
            }
            if revealDelay > 0 {
                try? await Task.sleep(for: .seconds(revealDelay))
            }
            await MainActor.run {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) { celebrationVisible = false }
            }
        }

    }

    private func requestDeeperFeedback() async {
        aiError = nil

        guard aiSettings.isCloudProcessingAllowed else {
            pendingCloudProcessingAction = .coachRead
            showAIDisclosure = true
            return
        }

        // Provider configuration is an operational concern, not a user task.
        // Keep the rep intact and describe availability honestly.
        if aiSettings.activeProvider == nil {
            aiError = "Noum's deeper read is temporarily unavailable. This rep is still here."
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
            let currentMode = recentSessions.first?.mode ?? .timed
            // THE QUESTION ASKED — the stored prompt of this rep, the single
            // source of truth the deterministic verdict + the rubric both read.
            let repPrompt = recentSessions.first?.prompt ?? sessionPrompt ?? ""
            // Continuity — drop the current rep, map the next 3 prior reps to
            // the same shape AIInsights renders. Never invented. Pure helper so
            // the exclude-current-rep + bound-to-3 logic is unit-tested.
            let priorSummaries = AICoachService.recentSessionSummaries(
                sessions: sessionStore.sessions,
                currentRepID: latestSessionID
            )
            // Confidence-gated baseline (nil on insufficient data — never a
            // fake number). Same gate as PostRepCoachNote (:7182-7185).
            let coachBaseline = baselineStore.baseline
            let baselineFiller: Double? = coachBaseline.fillerRate.confidence == .insufficient
                ? nil : coachBaseline.fillerRate.value
            let baselinePace: Double? = coachBaseline.pace.confidence == .insufficient
                ? nil : coachBaseline.pace.value
            let feedback = try await aiCoachService.generateDeeperFeedback(
                input: AICoachSessionInput(
                    transcript: text,
                    mode: currentMode,
                    score: score,
                    fillerCount: fillerCount,
                    duration: duration,
                    wordsPerMinute: PracticeEvaluator.paceSnapshot(
                        forTranscript: text,
                        duration: duration
                    ).wordsPerMinute,
                    speakingIdentity: styleSnapshot.identity,
                    prompt: repPrompt,
                    voice: coachingProfileStore.profile?.speakingStyleGoal,
                    recentSessionSummaries: priorSummaries,
                    baselineFillerRate: baselineFiller,
                    baselinePaceWPM: baselinePace,
                    // STANDING CASE (SUBSTANCE-4) — the durable working
                    // hypothesis + the already-built case-file target/measure/cadence
                    // (single source of truth: reuse caseFile.observableTarget/
                    // successMeasure/reviewDueAt, never re-derive from activeIntervention).
                    standingHypothesis: coachMemoryStore.currentMemory?.workingHypothesis,
                    standingObservableTarget: coachMemoryStore.currentMemory?.caseFile?.observableTarget,
                    standingSuccessMeasure: coachMemoryStore.currentMemory?.caseFile?.successMeasure,
                    standingReviewDueAt: coachMemoryStore.currentMemory?.caseFile?.reviewDueAt
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
            } else {
                aiError = "Noum couldn't complete the deeper read right now. This rep is still here."
            }
        }
    }

    private func analyzeVideo() {
        guard aiSettings.isCloudProcessingAllowed else {
            pendingCloudProcessingAction = .videoAnalysis
            showAIDisclosure = true
            return
        }
        guard let url = recordingURL else { return }
        isAnalyzingVideo = true

        Task {
            do {
                let result = try await VideoAnalysisService.shared.analyzeRecording(at: url)
                await MainActor.run {
                    videoAnalysisResult = result
                    coachMemoryStore.noteVisualDeliveryRead(from: result, sessionID: latestSessionID)
                    isAnalyzingVideo = false
                }
            } catch {
                await MainActor.run {
                    isAnalyzingVideo = false
                    aiError = "Delivery analysis is temporarily unavailable. Your recording is still here."
                }
            }
        }
    }

    private func animateXP(to endXP: Int) {
        let shouldReduceMotion = reduceMotion
        Task {
            if shouldReduceMotion {
                await MainActor.run {
                    displayedXP = endXP
                    progress = ProfileManager.progressTowardsNextLevel(forXP: endXP)
                    currentLevel = ProfileManager.levelTitle(forXP: endXP)
                    nextLevel = ProfileManager.levelTitle(forXP: ((endXP / 1000) + 1) * 1000)
                    xpToNext = ProfileManager.xpNeededToNextLevel(forXP: endXP)
                    CoachHaptic.xpEarned()
                }
                return
            }

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
        self.committedFinalization = entry?.committedFinalization
        self.suddenDeathGamePoints = entry?.suddenDeathGamePoints
        self.suddenDeathMultiplierLabels = entry?.suddenDeathMultiplierLabels ?? []
        self.suddenDeathTotalWords = entry?.suddenDeathTotalWords
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
        // Captured for "Practice Again" so IM reps re-arm the just-finished
        // scenario + tone instead of dropping back on the picker. The
        // other modes have no per-rep setup, so the router ignores this.
        let practiceAgainIMSetup = entry?.imConversationDetails?.setup
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
            let destination = SummaryPracticeAgainRouter.destination(
                for: payloadMode,
                imSetup: practiceAgainIMSetup
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pathBinding.wrappedValue.append(destination)
            }
        }
        self.onStartDrill = entry?.onStartDrill

        // Ask-Noum bridge — drops the session-anchored opener into the
        // store, then pushes the AskNoum destination. A small async
        // hop separates the store mutation from the nav push so the
        // store's @Published flush settles before AskNoumView's
        // onAppear consumes the pending coachID. Same pattern the
        // onPracticeAgain wiring uses for its push.
        self.onAskNoumAboutRep = { opener in
            _ = AskNoumStore.shared.injectUserTurn(opener)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pathBinding.wrappedValue.append(AppDestination.askNoum)
            }
        }

        // Round 19 — "Looking ahead" launch closure. Mirrors the
        // `onPracticeAgain` shape: pop the summary + the prior practice
        // screen, then push the destination the view computed via
        // `SummaryLookingAheadRouter` (which it already does at tap time
        // because the blueprint depends on view-side state). The user is
        // launching a NEW rep in a different mode, so the stale summary
        // shouldn't be reachable via the back chevron — same UX as
        // Practice Again.
        self.onStartLookingAhead = { destination in
            SummaryDataStore.shared.remove(for: payloadId)
            var path = pathBinding.wrappedValue
            if path.count > 0 { path.removeLast() }
            if path.count > 0 { path.removeLast() }
            pathBinding.wrappedValue = path
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                pathBinding.wrappedValue.append(destination)
            }
        }
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
        practiceTitle: PracticeMode.timed.displayLabel,
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
