import Foundation
#if canImport(UIKit)
import UIKit
#endif

#if canImport(SwiftUI)
import SwiftUI

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
    var finalizedSessionID: UUID? = nil
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
    /// state (the resolved Summary prescription + live IM availability)
    /// the init doesn't have in scope. Defaults nil → the
    /// `LookingAheadCard` stays the pre-round-19 descriptive-only nudge.
    var onStartLookingAhead: ((AppDestination) -> Void)?

    @StateObject private var profile = ProfileManager.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var localeSettings = LocaleSettingsManager.shared
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
    @StateObject private var flowEventLog = FlowEventLog.shared
    @StateObject private var streakFreeze = StreakFreezeManager.shared
    @State private var showPaywall = false
    @State private var displayedXP: Int = 0
    @State private var progress: Double = 0
    @State private var currentLevel: String = ""
    @State private var nextLevel: String = ""
    @State private var xpToNext: Int = 0
    @State private var didApplyXP = false
    /// One-shot guard + settle state for the score receipt's payoff beat
    /// (fires when `resultOverviewCard` first mounts — immediately for
    /// Pressure Drill, on Details expand otherwise).
    @State private var scoreRevealHasRun = false
    @State private var scoreCardSettled = false
    @State private var aiFeedback: AICoachFeedback?
    @State private var isRequestingAIFeedback = false
    @State private var aiError: String?
    @State private var showVideoPlayback = false
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
    @State private var sessionMilestone: MilestoneEvent?
    /// Snapshot the pending skill events at setup so the inline Results receipt
    /// describes exactly what the completed rep earned.
    @State private var preSummaryEvents: [SkillLevelUpEvent] = []
    @State private var activeMiniDrill: DrillRecommendationV2?
    @State private var miniDrillOutcome: MiniDrillOutcome?
    @State private var miniDrillAwardedXP: Int = 0
    @State private var miniDrillXPBreakdown: DrillXPEngine.Breakdown?
    @State private var committedMiniDrillOutcomeIDs: Set<UUID> = []
    @State private var showSecondaryDetails = false
    @State private var enhancedCoachNote: CoachNote?
    /// The strategic recommendation returned by the same finalization pass
    /// that committed this rep. Retained for immediate-finalization paths;
    /// precommitted modes can read the same value directly from
    /// `committedFinalization` before `setup()` runs.
    @State private var finalizedNextAction: NextAction? = nil
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
    @State private var showAllProgressUpdates = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.requestReview) private var requestReview
    @State private var reviewPromptExitGate = SummaryReviewPromptExitGate()
    @State private var transcriptUpgradeState: TranscriptUpgradePresentationState?
    /// Page-19 C1 → C2 earned beat. Ephemeral by design: it appears once for
    /// the just-finished Summary mount, then yields to the durable evidence
    /// card and Updated-Today receipt.
    @State private var dismissedRetryMilestoneOutcomeIDs: Set<UUID> = []
    @State private var resolvedRetryMilestonePresentation: TranscriptRetryMilestonePresentation?
    @State private var didResolveRetryMilestonePresentation = false

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

    /// Every stored-evidence projection on Summary is bound to the exact row
    /// represented by this presentation. A missing or unmatched identifier
    /// must not borrow the newest row: coach notes, delivery reads, analytics,
    /// and durable follow-up effects all fail closed together.
    private var currentStoredSession: PracticeSession? {
        SummaryMetricSessionResolver.resolve(
            finalizedSessionID: finalizedSessionID,
            storedSessions: sessionStore.sessions
        )
    }

    /// Filler, pace, and coach-score evidence must resolve to the exact row
    /// represented by this Summary. This alias makes mechanic-specific call
    /// sites explicit while retaining the single exact-session owner above.
    private var currentMetricSession: PracticeSession? {
        currentStoredSession
    }

    private var currentTranscriptRetryOutcome: RecommendationOutcome? {
        guard let sessionID = currentStoredSession?.id else { return nil }
        return recommendationLearningStore.outcomes.first {
            $0.sessionID == sessionID && $0.transcriptRetryTarget != nil
        }
    }

    private var currentTranscriptRetrySource: PracticeSession? {
        guard let sourceID = currentTranscriptRetryOutcome?.sourceSessionID else {
            return nil
        }
        return sessionStore.sessions.first { $0.id == sourceID }
    }

    private var currentTranscriptRetryMilestonePresentation: TranscriptRetryMilestonePresentation? {
        guard let outcome = currentTranscriptRetryOutcome,
              let retrySession = currentStoredSession else {
            return nil
        }
        return TranscriptRetryMilestonePresentation.make(
            outcome: outcome,
            sourceSession: currentTranscriptRetrySource,
            retrySession: retrySession,
            priorHolds: leverTally(excluding: outcome).holds
        )
    }

    private var effectiveTranscriptRetryMilestonePresentation: TranscriptRetryMilestonePresentation? {
        didResolveRetryMilestonePresentation
            ? resolvedRetryMilestonePresentation
            : currentTranscriptRetryMilestonePresentation
    }

    private var displayedTranscriptRetryMilestone: TranscriptRetryMilestonePresentation? {
        guard let presentation = effectiveTranscriptRetryMilestonePresentation,
              !dismissedRetryMilestoneOutcomeIDs.contains(presentation.id),
              !showPaywall,
              !showVideoPlayback,
              !showShareMenu,
              !showFeedbackRequestSheet,
              !showAIDisclosure,
              activeMiniDrill == nil,
              miniDrillOutcome == nil else {
            return nil
        }
        return presentation
    }

    private var coachScoreEvidence: Int? {
        lockedScore ?? score ?? currentMetricSession?.score
    }

    /// Summary is a second presentation/AI boundary after persistence. A raw
    /// Review row may render here, but it cannot display earned credit, start
    /// cloud coaching, or alter a durable coaching ledger.
    private var currentRepIsProgressEligible: Bool {
        guard let currentStoredSession else { return false }
        return PracticeProgressEligibility.qualifies(currentStoredSession)
    }

    /// A path receipt is transient post-rep context, so Summary must only use
    /// it when it was produced by the exact session this screen represents.
    /// A pending receipt from an older rep remains available for Home to
    /// acknowledge, but cannot relabel a newer Summary.
    private var currentRepUnlockedPathStep: Bool {
        guard let sessionID = currentStoredSession?.id else { return false }
        return PathProgressManager.shared.pendingCelebrationSessionID == sessionID
    }

    private var progressEligibleRecentSessions: [PracticeSession] {
        PracticeProgressEligibility.eligibleSessions(in: recentSessions)
    }

    private var previousProgressSessions: [PracticeSession] {
        sessionStore.progressEligibleSessions.filter { $0.id != latestSessionID }
    }

    private var earnedXPForPresentation: Int {
        currentRepIsProgressEligible ? xpEarned : 0
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
    private var isSuddenDeathSummary: Bool { currentMode == .suddenDeath }

    private var scoreValue: Int {
        if !currentRepIsProgressEligible {
            return transcriptWordCount == 0 ? 0 : 1
        }
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
        #if DEBUG
        // The deterministic transcript-ladder UI fixture needs a rewriteable
        // dimension even if the surrounding seeded trend would prescribe a
        // delivery drill. Production continues to take the live drill-engine
        // result below; eligibility and rewrite guards are never bypassed.
        if ProcessInfo.processInfo.arguments.contains("UI_TESTING_REWRITE_LADDER") {
            return .opening
        }
        #endif
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

    /// The immediate post-rep contract must offer one lever, not a transcript
    /// upgrade and a separate plan prescription at the same time. While this
    /// lane is loading or ready, the source-bound Review ladder owns the next
    /// action. If it fails honestly, Summary restores the finalized plan card.
    private var hasTranscriptUpgradeLane: Bool {
        currentTranscriptRetryOutcome == nil
            && currentRepIsProgressEligible
            && premium.isPremium
            && onStartLookingAhead != nil
            && primaryWeakness != nil
            && AIRewriteService.eligibility(
                transcript: transcriptText,
                confidence: currentStoredSession?.transcriptConfidence,
                locale: localeSettings.current
            ) == .eligible
    }

    private var transcriptUpgradeOwnsNextAction: Bool {
        hasTranscriptUpgradeLane && transcriptUpgradeState != .unavailable
    }

    /// When Review owns the immediate action, keep the summary observation on
    /// that exact language lever. A generic duration or momentum claim beside
    /// an opening rewrite makes the coach appear to change its mind between
    /// cards even when both statements are independently evidence-safe.
    private var transcriptUpgradeObservation: String? {
        guard transcriptUpgradeOwnsNextAction, let weakness = primaryWeakness else {
            return nil
        }
        switch weakness {
        case .opening:
            return "The opening uses a tentative marker before the recommendation. The retry removes only that marker."
        case .closing:
            return "The ending softens after the main point. The retry keeps the point and removes only that softener."
        case .structure:
            return "The answer contains the point and its support, but not in the clearest order. The retry changes only that order."
        case .concise:
            return "The main point arrives after a longer lead-in. The retry brings it forward without changing the meaning."
        }
    }

    /// Transcript → a stronger version of the user's own words.
    ///
    /// This used to mount inside `expandableDetailsSection`, which defaults
    /// closed — the same failure the deep-read path already hit (see the
    /// comment on `deepReadCard`): a Pro feature the pitch advertises but the
    /// user never reaches. It renders directly beneath the debrief now, so the
    /// screen reads as one arc: here is the read, here is a stronger version of
    /// what you actually said, here is the drill.
    ///
    /// Self-suppressing. `primaryWeakness` is nil for filler, pace, pauses,
    /// emphasis and confidence — those are trained by practice modes, not by
    /// rewriting a script — so most reps show nothing here at all.
    @ViewBuilder
    private var rewriteSection: some View {
        if currentTranscriptRetryOutcome == nil,
           currentRepIsProgressEligible,
           let weakness = primaryWeakness,
           AIRewriteService.eligibility(
               transcript: transcriptText,
               confidence: currentStoredSession?.transcriptConfidence,
               locale: localeSettings.current
           ) == .eligible {
            if premium.isPremium {
                RewriteSuggestionCard(
                    transcript: transcriptText,
                    weakness: weakness,
                    sourceSessionID: currentStoredSession?.id,
                    sourcePrompt: sessionPrompt ?? currentStoredSession?.prompt,
                    sourceDuration: effectiveDuration,
                    targetDimension: goalOutcomeRead?.nextDimension?.label,
                    targetDimensionID: goalOutcomeRead?.nextDimension?.dimensionID,
                    goal: goalOutcomeRead?.style,
                    transcriptConfidence: currentStoredSession?.transcriptConfidence,
                    savedSnapshot: currentStoredSession?.transcriptRewriteSnapshot,
                    onPracticePhrase: onStartLookingAhead.map { launch in
                        { intent in
                            guard let token = TimedPracticePromptHandoff.shared.offerToken(
                                intent.suggestedPrompt
                            ) else { return }
                            launch(.timedPracticePrompt(token: token))
                        }
                    },
                    onPracticeRewrite: onStartLookingAhead.map { launch in
                        { prescription in
                            guard let token = TimedPracticePromptHandoff.shared
                                .offerTranscriptRetryToken(prescription) else { return }
                            recommendationLearningStore.recordShown(
                                fingerprint: prescription.fingerprint,
                                title: prescription.title,
                                focus: prescription.focus,
                                target: prescription.target,
                                mode: .timed,
                                isAIBacked: true,
                                goal: prescription.goal,
                                targetDimensionID: prescription.targetDimensionID,
                                sourceSessionID: prescription.sourceSessionID,
                                observabilityID: prescription.correlationID,
                                transcriptRetryTarget: prescription.retryTarget
                            )
                            recommendationLearningStore.markTapped(mode: .timed)
                            launch(.timedPracticePrompt(token: token))
                        }
                    },
                    onPresentationStateChange: { state in
                        transcriptUpgradeState = state
                    }
                )
            } else {
                // Quotes the user's real sentence and states the rewrite is
                // Pro. Never calls the service — no provider cost for a user
                // who cannot read the result.
                LockedRewritePreviewCard(
                    transcript: transcriptText,
                    weakness: weakness,
                    onUpgrade: { showPaywall = true }
                )
            }
        }
    }

    @ViewBuilder
    private var transcriptRetryComparisonSection: some View {
        if displayedTranscriptRetryMilestone == nil,
           let outcome = currentTranscriptRetryOutcome,
           let retrySession = currentStoredSession {
            TranscriptRetryComparisonCard(
                outcome: outcome,
                sourceSession: currentTranscriptRetrySource,
                retrySession: retrySession,
                intervention: coachMemoryStore.currentMemory?.activeIntervention,
                priorHolds: leverTally(excluding: outcome).holds,
                priorTries: leverTally(excluding: outcome).tries,
                nextClockSeconds: summaryRecommendation.suggestedTimedDifficulty?.duration
                    .map { Int($0) },
                playsPayoffFeedback: effectiveTranscriptRetryMilestonePresentation == nil
            )
        }
    }

    /// Ledger tally for the current retry's lever, from the recommendation
    /// outcome history (this outcome excluded — the card adds itself). Real
    /// counts only; the card hides the sentence when nothing is countable.
    private func leverTally(excluding current: RecommendationOutcome) -> (holds: Int, tries: Int) {
        let lever = current.transcriptRetryTarget?.lever
            ?? current.transcriptRetryComparison?.lever
        guard let lever else { return (0, 0) }
        let priors = recommendationLearningStore.outcomes.filter {
            $0.id != current.id
                && $0.transcriptRetryComparison?.lever == lever
                && $0.transcriptRetryComparison?.isComparable == true
        }
        let holds = priors.filter {
            let result = $0.transcriptRetryComparison?.result
            return result == .improved || result == .held
        }.count
        return (holds, priors.count)
    }

    private var drillRecommendationV2: DrillRecommendationV2 {
        let categoryTuples = feedbackCategories.map { ($0.dimension, $0.rating.rawValue) }
        return DrillEngineV2.recommend(
            fillerCount: effectiveFillerCount,
            duration: effectiveDuration,
            wordCount: transcriptWordCount,
            score: scoreValue,
            feedbackCategories: categoryTuples,
            styleGoal: chosenStyleGoalEngineInputs.goal,
            transcriptConfidence: currentStoredSession?.transcriptConfidence,
            comparisonMetricSchemaVersion: currentStoredSession?.comparisonMetricSchemaVersion,
            isEvaluationFixture: currentStoredSession?.isEvaluationFixture ?? false
        )
    }

    private var chosenStyleGoalEngineInputs: ChosenStyleGoalEngineInputs {
        ChosenStyleGoalEngineInputs.make(profile: coachingProfileStore.profile)
    }

    /// The finalized decision wins whenever it exists. `DrillEngineV2` is
    /// consulted only as the explicit first-rep / below-floor / legacy
    /// fallback encoded by `SummaryPrescriptionProjection`.
    private var renderedActionForSummary: NextAction? {
        RecommendationTapCapabilityLossUITestFixture
            .summaryActionForRendering(finalizedActionForSummary)
    }

    private func summaryPrescription(
        for action: NextAction?
    ) -> SummaryPrescriptionProjection {
        let existingSetup = existingIMPrescriptionSetup(for: action)
        return SummaryPrescriptionProjection.resolve(
            nextAction: action,
            fallbackDrill: drillRecommendationV2,
            existingScenario: existingSetup?.scenario,
            existingTone: existingSetup?.tone,
            modeAvailability: NextActionModeAvailability(
                rating: ratingStore.rating,
                imConversationAvailable: IMModeAvailability.isAvailable
            )
        )
    }

    /// Full tap-time capability snapshot for the active Summary action. This
    /// mirrors Home and Train: live state can remove a rendered capability,
    /// but it cannot reinterpret or upgrade the prescription the user saw.
    private var recommendationModeAvailabilityAtTap: NextActionModeAvailability {
        let imAvailable = RecommendationTapCapabilityLossUITestFixture
            .imAvailableAtTap(IMModeAvailability.isAvailable)
        let live = NextActionModeAvailability(
            rating: ratingStore.rating,
            imConversationAvailable: imAvailable
        )
        return RecommendationTapCapabilityLossUITestFixture
            .availabilityAtTap(live)
    }

    /// Keeps the existing prescribed-rep UI fixture deterministic after the
    /// Summary moved from a separate goal card action to the finalizer-owned
    /// projection. Production always returns the actual finalized decision.
    private var finalizedActionForSummary: NextAction? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UI_TESTING_GOAL_OUTCOME_TIMED") {
            return NextAction(
                primary: .practiceMode(
                    .timed,
                    reason: "Run one comparable Timed rep against the same target."
                ),
                secondary: nil,
                reasoning: "The established goal read has enough evidence for one comparable follow-up.",
                confidenceLevel: .established
            )
        }
        #endif
        return committedFinalization?.nextAction ?? finalizedNextAction
    }

    /// Preserve an already-computed IM scenario/tone only when the finalized
    /// action and the existing recommendation blueprint agree on IM. Every
    /// other mode action routes with nil setup through the shared router.
    private func existingIMPrescriptionSetup(
        for action: NextAction?
    ) -> (scenario: IMConversationScenario?, tone: IMTargetTone?)? {
        guard let action else { return nil }
        let mode: PracticeMode
        switch action.primary {
        case .practiceMode(let prescribedMode, _),
             .pressureExposure(let prescribedMode, _),
             .stabilizingRep(let prescribedMode, _):
            mode = prescribedMode
        case .drill, .confidenceRebuilding:
            return nil
        }
        guard mode == .imConversation else { return nil }
        let blueprint = summaryRecommendation
        guard blueprint.recommendedMode == .imConversation else { return nil }
        return (blueprint.recommendedScenario, blueprint.recommendedTone)
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
            score: coachScoreEvidence,
            categoryRatings: categoryRatings,
            trends: skillTrends,
            primaryFocus: drillRecommendationV2.skillArea,
            drillHistory: DrillHistoryStore.shared.entries,
            styleGoal: chosenStyleGoalEngineInputs.title,
            promptRelevance: promptRelevanceRead,
            metricSession: currentMetricSession
        )
    }

    private var currentPostRepCoachNote: PostRepCoachNote? {
        guard currentRepIsProgressEligible,
              let sessionID = currentStoredSession?.id else { return nil }
        return postRepCoachNoteStore.note(
            for: sessionID,
            chosenStyleGoal: coachingProfileStore.profile?.chosenStyleGoal
        )
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
            customFillerWords: ClutchWordStore.shared.customFillerWords,
            metricSession: currentMetricSession
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
        guard currentRepIsProgressEligible,
              let session = currentStoredSession else { return nil }
        let baseline = baselineStore.baseline
        // Both engines take optionals precisely so an absent channel can be
        // skipped, and both enforce a minimum number of contributing channels.
        // Passing `.value` unconditionally defeated that: a brand-new user's
        // baseline is `BaselineStat.empty` (value 0, sampleCount 0, confidence
        // .insufficient), and 0 hedges/min maps to a perfect composure score
        // that then counts as real evidence. The floor was being met by a
        // channel that had measured nothing.
        let hedgingPerMinute: Double? = baseline.hedgingRate.isReliable
            ? baseline.hedgingRate.value
            : nil
        let paceWPM: Double? = baseline.pace.isReliable ? baseline.pace.value : nil
        let composure = ComposureReadEngine.derive(
            session: session,
            hedgingPerMinute: hedgingPerMinute
        )
        let confidence = ConfidenceMarkerEngine.derive(
            session: session,
            hedgingPerMinute: hedgingPerMinute,
            paceWPM: paceWPM,
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
            deliveryReadLine: postRepDeliveryReadLine,
            sourceDuration: effectiveDuration
        )
    }

    private var headline: String {
        if !currentRepIsProgressEligible { return "Just getting started" }
        if let lockedHeadlineOverride { return lockedHeadlineOverride }
        if let headlineOverride { return headlineOverride }
        if transcriptWordCount == 0 { return "No response detected" }
        if isMinimalEffort { return "Just getting started" }
        // If a Path step just unlocked on this rep, the headline confirms
        // that progress was saved without exposing internal journey jargon.
        // PathProgressManager queues the exact triggering session when a path
        // step unlocks. Read it without consuming; Home's unified progress
        // receipt still owns acknowledgement.
        if currentRepUnlockedPathStep {
            return "Progress saved"
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
        Array(sessionStore.progressEligibleSessions.prefix(5))
    }

    /// One strict filler read owns every Summary comparison. The persisted
    /// store remains the history owner; index zero is the just-finished rep,
    /// matching the established recent-window contract.
    private var summaryFillerPresentation: SummaryFillerPresentation {
        SummaryFillerPresentation.make(
            metricSession: currentMetricSession,
            fallbackFillerCount: effectiveFillerCount,
            fallbackDuration: effectiveDuration,
            previousSessions: previousProgressSessions
        )
    }

    private var strongestMode: PracticeMode? {
        CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)?.strongestMode
    }

    private var summaryRecommendation: RecommendationBiasBlueprint {
        let plan = CoachingPlanner.plan(
            for: sessionStore.sessions,
            profile: coachingProfileStore.profile
        )
        let resolved = RecommendationBiasEngine.blueprint(
            profile: coachingProfileStore.profile,
            input: RecommendationBiasContextBuilder.input(
                profile: coachingProfileStore.profile,
                sessions: sessionStore.sessions,
                plan: plan,
                sessionStreak: sessionStreak,
                daysSinceLastSession: daysSinceLastSession,
                summaryStyle: .compact,
                preferredModeBias: "",
                preferredToneBias: "",
                preferredScenarioBias: "",
                modeBenefitBias: ""
            ),
            plan: plan,
            imToneSignal: imToneDrillSignal,
            coachMemory: coachMemoryStore.currentMemory,
            recommendationOutcomes: recommendationLearningStore.outcomes
        )
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("UI_TESTING_GOAL_OUTCOME_TIMED") {
            return RecommendationBiasBlueprint(
                recommendedMode: .timed,
                recommendedTone: nil,
                recommendedScenario: nil,
                focus: resolved.focus,
                target: resolved.target,
                modeBenefit: resolved.modeBenefit,
                whyMode: resolved.whyMode,
                whyNow: resolved.whyNow,
                suggestedTimedDifficulty: resolved.suggestedTimedDifficulty ?? .easy,
                suggestedTheme: resolved.suggestedTheme,
                source: resolved.source
            )
        }
        #endif
        return resolved
    }

    private var goalOutcomeRead: GoalOutcomeRead? {
        guard currentRepIsProgressEligible else { return nil }
        return GoalOutcomeEngine.read(
            profile: coachingProfileStore.profile,
            baseline: baselineStore.baseline,
            rating: ratingStore.rating,
            sessions: sessionStore.progressEligibleSessions,
            coachMemory: coachMemoryStore.currentMemory,
            outcomes: recommendationLearningStore.outcomes
        )
    }

    private var reviewExperimentPresentation: ReviewExperimentPresentation {
        ReviewExperimentContract.presentation(in: flowEventLog.events)
    }

    /// The only Test B presentation gate. Unassigned accounts and the explicit
    /// treatment keep the shipping finalizer-owned prescription; only an exact
    /// control assignment substitutes a neutral replay that writes no adaptive
    /// recommendation exposure or acceptance.
    @ViewBuilder
    private var reviewExperimentActionCard: some View {
        switch reviewExperimentPresentation {
        case .genericReview:
            SummaryGenericReviewActionCard(
                presentation: .make(for: currentMode),
                onStart: onPracticeAgain
            )
        case .outcomeLoop:
            let action = renderedActionForSummary
            let prescription = summaryPrescription(for: action)
            SummaryPrescriptionActionCard(
                prescription: prescription,
                legacyDrill: drillRecommendation,
                onStartMiniDrill: { drill in
                    activeMiniDrill = drill
                },
                onStartDrill: onStartDrill,
                resolveModeAvailability: { recommendationModeAvailabilityAtTap },
                onShowFullRep: fullRepShownHandler(
                    prescription: prescription,
                    goalAttribution: action?.goalAttribution
                ),
                onStartFullRep: fullRepStartHandler(
                    prescription: prescription,
                    goalAttribution: action?.goalAttribution
                )
            )
        }
    }

    /// Closes the gap between "a rep finished" and "the coaching was read".
    /// Keyed on the stored session's id so it joins `rep.saved`, which uses the
    /// same id. Only fires for a rep that actually persisted — an interstitial
    /// or a below-floor rep never renders this summary, so it must not count
    /// toward the denominator.
    private func recordSummaryViewedIfNeeded() {
        guard let sessionID = currentStoredSession?.id else { return }
        AutoGuidedFirstRep.markSummaryPresented(sessionID: sessionID)
        flowEventLog.recordSummaryViewed(correlationId: sessionID)
        guard !flowEventLog.growthEvents().contains(where: {
            $0.name == .summaryViewed && $0.correlationID == sessionID
        }) else { return }
        FlowEventGrowthEventSink.shared.record(
            GrowthEvent(
                correlationID: sessionID,
                name: .summaryViewed,
                entryPoint: .postPractice
            )
        )
        // The structured fast lane records its own permissionless first value.
        // A full-onboarding/control journey reaches first useful value only
        // when the first persisted spoken rep's coaching summary is visible.
        // Recording here prevents that cohort from being undercounted while
        // preserving the prove-value-before-paywall boundary.
        guard !flowEventLog.growthEvents().contains(where: {
            $0.name == .firstValueDelivered
        }) else { return }
        FlowEventGrowthEventSink.shared.record(
            GrowthEvent(
                correlationID: sessionID,
                name: .firstValueDelivered,
                entryPoint: .postPractice
            )
        )
    }

    private func recordReviewExperimentExposureIfNeeded() {
        guard let assignment = ReviewExperimentContract.persistedAssignment(
            in: flowEventLog.events
        ) else { return }
        flowEventLog.recordReviewExperimentExposure(
            assignment: assignment,
            presentation: reviewExperimentPresentation,
            context: ActivationExperimentExposureContext.capture(
                practiceLocale: localeSettings.current
            )
        )
    }

    /// The per-scenario tone-drill signal, shared with Home and the mode
    /// picker. When set, the post-rep "Looking ahead" card prescribes the
    /// exact scenario + tone to re-drill instead of a generic mode nudge.
    /// `if #available` guards the iOS-17 summary type so this unannotated
    /// view still compiles; `IMToneDrillSignal` itself is non-gated.
    private var imToneDrillSignal: IMToneDrillSignal? {
        guard currentRepIsProgressEligible,
              IMModeAvailability.isAvailable else { return nil }
        if #available(iOS 17.0, *) {
            return IMHistorySummary.toneDrillSignal(from: sessionStore.progressEligibleSessions)
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
        guard currentRepIsProgressEligible,
              let details = imConversationDetails else { return nil }
        if #available(iOS 17.0, *) {
            // Latest session in the store is the just-finalized rep
            // (`PracticeSessionStore` prepends). Pass its id to the
            // helper so the with-vs-without-this-rep comparison is
            // order-independent — same primitive the finalizer uses.
            guard let currentRepId = currentStoredSession?.id else { return nil }
            let scenario = details.setup.scenario
            guard let crossed = IMHistorySummary.toneDrillCrossing(
                in: sessionStore.progressEligibleSessions,
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
        guard let last = sessionStore.progressEligibleSessions.first?.date else { return 99 }
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
        finalizedSessionID
    }

    private var derivedInsights: [String] {
        if !lockedInsights.isEmpty { return lockedInsights }
        if !insights.isEmpty { return insights }
        let previousSessions = previousProgressSessions
        guard !previousSessions.isEmpty else {
            return ["First rep saved. Complete another rep to start comparing."]
        }
        let averageDuration = previousSessions.map(\.duration).reduce(0, +) / Double(previousSessions.count)
        var messages: [String] = []
        if effectiveDuration > averageDuration {
            messages.append("You stayed with this answer longer than your recent average.")
        } else {
            messages.append("This answer ended sooner than your recent average, so push the middle section further next time.")
        }
        if let fillerInsight = summaryFillerPresentation.derivedInsight {
            messages.append(fillerInsight)
        }
        let eligibleCount = sessionStore.progressEligibleSessionCount
        messages.append("You now have \(eligibleCount) saved practice session\(eligibleCount == 1 ? "" : "s") to compare against.")
        return Array(messages.prefix(3))
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                    VStack(spacing: 16) {
                        // MODE CONSISTENCY NOTE (M20):
                        // IM, Sudden Death and Timed/other share TalkToNoumCTACard
                        // as the single Ask Noum entry point. Every mode now opens
                        // on the useful coaching read and prescribed next rep;
                        // score/mode receipts are secondary. Remaining divergences:
                        //   - IM lacks BaselineComparisonCard equivalents for
                        //     WhatYouDidWell / WhatToImprove (uses IMReadCard instead)
                        //   - Ah-Counter has no dedicated mode-specific verdict card
                        //     (falls into the Timed/other path — acceptable for now)
                        if isIMSummary {
                            // IM has no verified ProofMoment surface, so the
                            // exact-session debrief leads without inventing a
                            // quote. The finalized prescription immediately
                            // follows it; the numeric verdict is available in
                            // Details with the rest of the analytical record.
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
                            reviewExperimentActionCard
                                .onAppear(perform: recordReviewExperimentExposureIfNeeded)
                            transcriptRetryComparisonSection
                            rewriteSection
                            postRepProgressReceipt
                            TalkToNoumCTACard(
                                isPremium: premium.isPremium,
                                speakingStyleGoal: coachingProfileStore.profile?.chosenStyleGoal,
                                onAskNoum: {
                                    onAskNoumAboutRep?(talkToNoumOpener)
                                },
                                onUpgradePrompt: {
                                    showPaywall = true
                                }
                            )
                            expandableDetailsSection
                            SummaryExitPanel(onDone: completeSummaryReview)
                        } else {
                            // TIMED / AH-COUNTER / SUDDEN DEATH all spend the
                            // first attention slot on source-bound evidence.
                            // `PostRepVerdictContent` is still fed by the exact
                            // persisted session and remains honest below the
                            // evidence floor.
                            // The coaching payoff arrives in reading order
                            // rather than as one fully-rendered wall. This is
                            // the most-repeated screen in the product, and a
                            // coach delivers the evidence, then the read, then
                            // the next move — the stagger carries that sequence.
                            // `cardEntrance` caps the total and collapses to an
                            // instant appearance under Reduce Motion.
                            PostRepDebriefCard(
                                content: postRepVerdictContent,
                                revisedChange: freshRevisedReadChange,
                                reviewIntervention: activeReviewDueIntervention,
                                onReview: activeReviewDueIntervention.map { intervention in
                                    { onAskNoumAboutRep?(interventionReviewOpener(for: intervention)) }
                                },
                                suppressesNextMove: transcriptUpgradeOwnsNextAction,
                                observationOverride: transcriptUpgradeObservation
                            )
                            .cardEntrance(0)
                            transcriptRetryComparisonSection
                                .cardEntrance(1)
                            rewriteSection
                                .cardEntrance(2)
                            if !transcriptUpgradeOwnsNextAction {
                                reviewExperimentActionCard
                                    .onAppear(perform: recordReviewExperimentExposureIfNeeded)
                                    .cardEntrance(3)
                            }
                            // Pressure Drill keeps its mode receipt visible for
                            // the existing run-completion contract, but only
                            // after the evidence and next action. Standard score
                            // and metrics move behind Details.
                            if isSuddenDeathSummary {
                                resultOverviewCard
                                    .cardEntrance(4)
                            }
                            postRepProgressReceipt
                                .cardEntrance(5)
                            TalkToNoumCTACard(
                                isPremium: premium.isPremium,
                                speakingStyleGoal: coachingProfileStore.profile?.chosenStyleGoal,
                                onAskNoum: {
                                    onAskNoumAboutRep?(talkToNoumOpener)
                                },
                                onUpgradePrompt: {
                                    showPaywall = true
                                }
                            )
                            .cardEntrance(6)
                            expandableDetailsSection
                                .cardEntrance(6)
                            SummaryExitPanel(onDone: completeSummaryReview)
                                .cardEntrance(6)
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
                // Preserve the named rotor action as an equivalent non-visual
                // escape whenever the Summary content is the active layer.
                .accessibilityAction(named: Text("Done")) {
                    completeSummaryReview()
                }
                .allowsHitTesting(displayedTranscriptRetryMilestone == nil)
                .accessibilityHidden(displayedTranscriptRetryMilestone != nil)
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))

            if let presentation = displayedTranscriptRetryMilestone {
                TranscriptRetryMilestoneView(
                    presentation: presentation,
                    earnedXP: earnedXPForPresentation,
                    unlockedNextStep: currentRepUnlockedPathStep
                ) {
                    withAnimation(reduceMotion ? .v46ReduceMotionFade : .v46Dissolve) {
                        dismissedRetryMilestoneOutcomeIDs.insert(presentation.id)
                    }
                }
                .id(presentation.id)
                .transition(.opacity)
                .zIndex(10)
            }
        }
        .overlay {
            // Summary intentionally hides navigation chrome. Keep a quiet,
            // persistent safe-area scrim so coaching never competes with the
            // status-bar clock and indicators.
            if displayedTranscriptRetryMilestone == nil {
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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(CohesiveSummaryCopy.done) {
                    completeSummaryReview()
                }
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .accessibilityIdentifier("summary.toolbar.done")
                .accessibilityHint("Finishes the review and returns to your journey.")
            }
        }
        .toolbar(
            displayedTranscriptRetryMilestone == nil ? .visible : .hidden,
            for: .navigationBar
        )
        .toolbarBackground(AppColor.screenBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .disableSwipeBack()
        .onAppear(perform: setup)
        .onAppear(perform: recordSummaryViewedIfNeeded)
        // Review prompting is deliberately absent from mount/elapsed-time
        // effects. The one armed satisfaction moment is consumed only by the
        // explicit Done action after the user has reached or chosen to exit
        // the results.
        .task { await loadPersonalBestProof() }
        .sheet(isPresented: $showVideoPlayback) {
            if let recordingURL {
                VideoPlaybackView(url: recordingURL)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(entryPoint: .postPractice)
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
                styleGoal: coachingProfileStore.profile?.chosenStyleGoal,
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
    }

    /// The only StoreKit review-request boundary on Summary. Consume the
    /// one-shot intent before navigation so rapid repeated activation cannot
    /// issue more than one request, then preserve the existing exit route.
    private func completeSummaryReview() {
        if let moment = reviewPromptExitGate.consumeForExplicitExit() {
            _ = AppReviewPromptCoordinator().requestIfEligible(
                moment: moment,
                qualifyingRepCount: sessionStore.progressEligibleSessionCount,
                using: requestReview
            )
        }
        onHome()
    }

    /// Filler tint comes from the same quantity-qualified rate projection as
    /// the hero badge, fallback insight, and details comparison.
    private var fillerTint: Color {
        switch summaryFillerPresentation.tone {
        case .insufficient: return .secondary
        case .positive: return AppColor.positive
        case .caution: return AppColor.caution
        case .warning: return AppColor.warning
        }
    }

    /// Fillers-per-minute delta vs repeated qualified history.
    private var fillerDelta: Double? {
        summaryFillerPresentation.meaningfulDeltaRatePerMinute
    }

    /// Delta vs recent average duration (positive = improved)
    private var durationDelta: Int? {
        guard currentRepIsProgressEligible else { return nil }
        let past = previousProgressSessions.map(\.duration)
        guard !past.isEmpty else { return nil }
        let avg = past.reduce(0, +) / Double(past.count)
        let delta = Int(effectiveDuration) - Int(avg.rounded())
        return abs(delta) >= 3 ? delta : nil // only show if meaningful (3+ seconds)
    }

    // MARK: - Expandable Details Section

    /// The single presentation language for every post-rep progression event.
    /// It sits inside Results after the coaching read; no achievement, level,
    /// skill crossing, or personal best earns a separate mandatory screen.
    private var postRepReceiptProjection: PostRepReceiptProjection? {
        PostRepReceiptProjection.resolve(
            milestone: sessionMilestone,
            reachedNewPracticeLevel: progressionReachedNewPracticeLevel,
            practiceLevelTitle: PracticeVolumeNarration.title(forXP: profile.xp),
            skillEvents: preSummaryEvents,
            newUnlocks: progressionNewUnlocks,
            practiceCredit: PracticeVolumeNarration.verdictCreditLine(
                xpEarned: earnedXPForPresentation,
                eloquenceBonus: currentRepIsProgressEligible
                    ? EloquenceXP.totalXP(for: eloquenceFindings)
                    : 0
            )
        )
    }

    @ViewBuilder
    private var postRepProgressReceipt: some View {
        if let projection = postRepReceiptProjection {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Progress from this rep")
                            .font(Typography.cardLabel)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("Recorded with this coaching read")
                            .font(Typography.captionSmall)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }

                progressReceiptRow(projection.primary)

                if let credit = projection.practiceCredit {
                    Label(credit, systemImage: "waveform.path")
                        .font(Typography.caption.monospacedDigit())
                        .foregroundStyle(AppColor.textSecondary)
                        .accessibilityLabel("Practice volume. \(credit)")
                }

                if !projection.additional.isEmpty {
                    Button {
                        withAnimation(reduceMotion ? nil : .standardSpring) {
                            showAllProgressUpdates.toggle()
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(
                                showAllProgressUpdates
                                    ? "Hide additional updates"
                                    : "Show \(projection.additional.count) more update\(projection.additional.count == 1 ? "" : "s")"
                            )
                            .font(Typography.caption.weight(.semibold))
                            Spacer(minLength: Spacing.xs)
                            Image(systemName: showAllProgressUpdates ? "chevron.up" : "chevron.down")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("summary.progressReceipt.disclosure")
                    .accessibilityLabel(
                        showAllProgressUpdates
                            ? "Hide additional progress updates"
                            : "Show \(projection.additional.count) additional progress update\(projection.additional.count == 1 ? "" : "s")"
                    )
                    .accessibilityValue(showAllProgressUpdates ? "Expanded" : "Collapsed")

                    if showAllProgressUpdates {
                        VStack(spacing: Spacing.sm) {
                            ForEach(projection.additional) { update in
                                progressReceiptRow(update)
                            }
                        }
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColor.brandBlue.opacity(0.06),
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(AppColor.brandBlue.opacity(0.14), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("summary.progressReceipt")
        }
    }

    private func progressReceiptRow(_ update: PostRepReceiptProjection.Update) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: update.systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(width: 28, height: 28)
                .background(AppColor.brandBlue.opacity(0.09), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(update.title)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(update.detail)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(update.title). \(update.detail)")
    }

    private var progressionReachedNewPracticeLevel: Bool {
        PracticeVolumeNarration.level(forXP: profile.xp)
            > PracticeVolumeNarration.level(forXP: progressionPreviousXP)
    }

    /// The mode/score receipt remains available without claiming the first
    /// attention slot. Standard and IM summaries reveal it through Details;
    /// Pressure Drill shows it below the evidence-first coaching loop because
    /// its run-completion screenshot and replay contract depend on that
    /// dedicated receipt being mounted immediately.
    @ViewBuilder
    private var resultOverviewCard: some View {
        Group {
            resultOverviewCardContent
        }
        // V4.6.1 score-settle beat: the receipt lands on `payoffReveal`
        // timing with the result-lands haptic + verdict brush on the settle
        // frame. Pre-state stays visible (0.85/0.98) so existence and the
        // run-completion screenshot contract are never delayed.
        .opacity(scoreCardSettled ? 1 : 0.85)
        .scaleEffect(scoreCardSettled ? 1 : 0.98)
        .onAppear(perform: runScoreReveal)
    }

    /// One-shot per summary. Under Reduce Motion the receipt appears
    /// instantly (entrance-choreography RM contract) while the haptic and
    /// cue still land — sound and haptics are not motion. Below the
    /// evidence floor the card settles silently: an empty ring is not a
    /// verdict worth punctuating.
    private func runScoreReveal() {
        guard !scoreRevealHasRun else { return }
        scoreRevealHasRun = true
        if reduceMotion {
            scoreCardSettled = true
            guard !isMinimalEffort else { return }
            CoachHaptic.scoreReveal()
            InteractionSoundEngine.cue(.verdictReveal)
            return
        }
        withAnimation(.payoffReveal, completionCriteria: .logicallyComplete) {
            scoreCardSettled = true
        } completion: {
            guard !isMinimalEffort else { return }
            CoachHaptic.scoreReveal()
            InteractionSoundEngine.cue(.verdictReveal)
        }
    }

    @ViewBuilder
    private var resultOverviewCardContent: some View {
        if isIMSummary {
            IMVerdictCard(
                scoreValue: scoreValue,
                scoreAccent: scoreAccent,
                scoreEmoji: scoreEmoji,
                headline: headline,
                effectiveFillerCount: effectiveFillerCount,
                effectiveDuration: effectiveDuration,
                imConversationDetails: imConversationDetails
            )
        } else if isSuddenDeathSummary {
            SuddenDeathReviewCard(
                points: suddenDeathGamePoints ?? 0,
                multiplierLabels: suddenDeathMultiplierLabels,
                tiersCleared: progressSegments,
                fillerCount: effectiveFillerCount,
                duration: effectiveDuration,
                wordCount: suddenDeathTotalWords ?? transcriptWordCount
            )
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
                fillerAccessibilityLabel: summaryFillerPresentation.accessibilityLabel,
                effectiveDuration: effectiveDuration,
                durationAssessment: durationAssessment,
                belowEvidenceFloor: isMinimalEffort,
                toneDrillResolvedRibbon: heroToneDrillResolvedRibbon
            )
        }
    }

    private var expandableDetailsSection: some View {
        VStack(spacing: 12) {
            // "More from this rep" (collapsed by default) — the ONE
            // disclosure every demoted surface lives behind.
            //
            // Holds the score/mode receipt and analytical pass: per-skill breakdowns (eloquence,
            // pauses, pitch, word-choice, grammar, filler chips), the IM
            // signal pills + baseline comparison (demoted from above the
            // fold), the premium deep read + rewrite, video playback +
            // AI analysis, the share row, the session comparison, the
            // looking-ahead nudge and the deferred reflection prompt.
            // None of these are wrong to see — they just shouldn't fight
            // source-bound evidence, the coach's read, and the next move for the
            // user's first three seconds.
            if showSecondaryDetails {
                VStack(spacing: 14) {
                    if !isSuddenDeathSummary {
                        resultOverviewCard
                    }

                    fullCoachReadDetail

                    // Practice credit — visible-but-demoted (progression
                    // spine): the primary loop stays evidence + restrained
                    // read + prescribed retry; the XP that accrued this rep
                    // reads as a quiet volume caption in here. Self-hides
                    // when nothing accrued (never renders "+0").
                    if postRepReceiptProjection == nil,
                       let credit = PracticeVolumeNarration.verdictCreditLine(
                        xpEarned: earnedXPForPresentation,
                        eloquenceBonus: currentRepIsProgressEligible
                            ? EloquenceXP.totalXP(for: eloquenceFindings)
                            : 0
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
                            pressureLevel: currentStoredSession?.pressureLevel ?? .standard
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
                        if let pauseMetrics = currentStoredSession?.pauseMetrics {
                            PauseSummaryCard(metrics: pauseMetrics)
                        }
                        if let pitchMetrics = currentStoredSession?.pitchMetrics {
                            PitchSummaryCard(metrics: pitchMetrics)
                        }
                        // Positional read — WHERE the rep's notable moments
                        // fell (opening/middle/close). The visible companion
                        // to the coach's positional prompt block; self-hides
                        // (engine returns nil) when no credible positional
                        // signal exists, so it never pads a non-finding.
                        if let eventLocations = currentStoredSession?.repEventLocations {
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
                        GrammarPolishCard(session: currentStoredSession)

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
                            repCount: sessionStore.progressEligibleSessionCount,
                            signals: SummaryAnalyticsEmptyState.Signals(
                                hasEloquence: !eloquenceFindings.isEmpty,
                                hasPause: currentStoredSession?.pauseMetrics != nil,
                                hasPitch: currentStoredSession?.pitchMetrics != nil,
                                hasPositional: currentStoredSession?.repEventLocations != nil,
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

                        // The rewrite card used to live here, behind a
                        // disclosure that defaults closed. It now renders
                        // above the fold as `rewriteSection` — see its
                        // definition for why.

                        // Premium deep read — the rescued entry point for
                        // `requestDeeperFeedback`. The old standalone
                        // "Generate Coach Read" card was only mounted from
                        // dead code, which left the whole AI deeper-read
                        // path unreachable while the Pro pitch still
                        // advertised it. It lives here as quiet premium
                        // depth behind the chevron.
                        if currentRepIsProgressEligible && premium.isPremium {
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
                    if currentRepIsProgressEligible && recordingURL != nil {
                        videoPlaybackButton
                        if premium.isPremium {
                            videoAnalysisSection
                        }
                    }

                    if reviewExperimentPresentation.showsGoalOutcome,
                       let goalOutcomeRead {
                        // This card is evidence and goal movement, not a second
                        // prescription. The finalized NextAction above owns the
                        // Summary's only launch.
                        GoalOutcomeCard(read: goalOutcomeRead)
                    }

                    // Session comparison
                    sessionComparisonCard

                    // Share / request feedback — re-homed from the cut
                    // pinned action bar. The confirmation dialog (share
                    // card + request feedback) hangs off the scroll view.
                    shareRow

                }
                .padding(.top, 8)
            }

            Button {
                if reduceMotion {
                    showSecondaryDetails.toggle()
                } else {
                    withAnimation(.standardSpring) { showSecondaryDetails.toggle() }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(CohesiveSummaryCopy.seeDetails)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: showSecondaryDetails ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("summary.details.toggle")
            .accessibilityLabel(showSecondaryDetails ? "Hide details" : CohesiveSummaryCopy.seeDetails)
            .tint(.secondary)
            .padding(.horizontal, Spacing.xs)
        }
    }

    private var fullCoachReadDetail: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "text.magnifyingglass")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .accessibilityHidden(true)
                Text("Full coach read")
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
            }

            Text(postRepVerdictContent.readText)
                .font(Typography.body)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            if let deliveryLine = postRepVerdictContent.deliveryReadLine {
                Text(deliveryLine)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(AppColor.subtleBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Full coach read. \(postRepVerdictContent.readText)")
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
        // The tap opens a chooser, not a share sheet — and one of the choices
        // is "request feedback", which the label doesn't hint at.
        .accessibilityHint("Opens options to share a score card or request feedback.")
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
            // "Analyze delivery" doesn't say WHAT gets analysed. The action
            // reads the video recording (and may ask for cloud-processing
            // consent first), which a non-visual user cannot infer.
            .accessibilityHint("Reviews your video recording for posture, eye contact, and gestures.")
            .accessibilityIdentifier("summary.details.analyzeVideo")

            if let result = videoAnalysisResult {
                videoAnalysisResultView(result)
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
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 16) {
                        if let fd = fillerDelta {
                            comparisonStat(label: "Filler rate", delta: fd, inverted: true, unit: "/min", fractionDigits: 1)
                        }
                        if let dd = durationDelta {
                            comparisonStat(label: "Duration", delta: Double(dd), inverted: false, unit: "s", fractionDigits: 0)
                        }
                    }
                }
            }
        }
    }

    private func comparisonStat(
        label: String,
        delta: Double,
        inverted: Bool,
        unit: String,
        fractionDigits: Int
    ) -> some View {
        let improved = inverted ? delta < 0 : delta > 0
        let value = String(format: "%.*f", fractionDigits, abs(delta))
        return HStack(spacing: 4) {
            Image(systemName: improved ? "arrow.down" : "arrow.up")
                .font(.caption2.weight(.bold))
            Text("\(value)\(unit)")
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
                .accessibilityAddTraits(.isHeader)

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
                .accessibilityAddTraits(.isHeader)

            if let aiFeedback {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What you did well")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
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
                        .accessibilityAddTraits(.isHeader)
                    Text(aiFeedback.keyImprovement)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Suggested drill")
                        .font(.subheadline.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text(aiFeedback.suggestedDrill)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !aiFeedback.revisedOpening.isEmpty {
                        Text("Try this opening")
                            .font(.subheadline.weight(.semibold))
                            .accessibilityAddTraits(.isHeader)
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
                    Text("You've used this month's coaching analyses. Fresh ones will be available \(aiSettings.resetDateFormatted).")
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
                // The monthly analysis budget is only visible on screen once
                // the user is near the limit. Naming the cost before the tap
                // is the honest read of what the button spends.
                .accessibilityHint("Uses one of your monthly coaching analyses.")
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
            voice: coachingProfileStore.profile?.chosenStyleGoal
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
                    voice: coachingProfileStore.profile?.chosenStyleGoal
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
                voice: coachingProfileStore.profile?.chosenStyleGoal,
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

    /// Production milestones now use the unified inline receipt. This legacy
    /// hook remains for source compatibility and deliberately never mounts the
    /// old particle overlay.
    static func shouldShowCelebration(hasMilestoneCrossing: Bool, score: Int, xpEarned: Int) -> Bool {
        _ = hasMilestoneCrossing
        _ = score
        _ = xpEarned
        return false
    }

    /// The proof-extraction input for the just-finished session, or nil
    /// when no qualifying session exists (empty transcript or a ≤8s misfire
    /// rep). Resolve through the same exact finalized row every other Summary
    /// projection uses; a newer sync/imported row must never replace the rep
    /// currently on screen. Shared by the synchronous first-frame proof and
    /// the async upgrade so both read identical state.
    private var proofInput: ProofMomentInput? {
        guard let session = currentStoredSession,
              !session.transcript.isEmpty,
              PracticeProgressEligibility.qualifies(session),
              session.duration > 8 else {
            return nil
        }
        let baseline = BaselineStore.shared.baseline
        let profile = CoachingProfileStore.shared.profile
        return ProofMomentInput(
            session: session,
            voice: profile?.chosenStyleGoal,
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
        guard let request = ProofMomentStore.shared.generationRequest(for: input) else {
            personalBestProof = nil
            return
        }
        let result = await ProofMomentService.shared.proof(for: request)
        await MainActor.run {
            guard !Task.isCancelled,
                  let result,
                  result.saveToken.source.sessionID == input.session.id,
                  ProofMomentStore.shared.tokenIsCurrent(result.saveToken) else {
                personalBestProof = nil
                return
            }
            withAnimation(reduceMotion ? nil : .standardSpring) {
                personalBestProof = result.proof
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
        // The recording view owns terminal-evidence construction; Summary is
        // the sole durable reward sink and independently enforces quantity,
        // parent-session provenance, and process-local idempotency before it
        // builds the durable receipt.
        guard outcome.isProgressEligible,
              let parentSession = currentStoredSession,
              committedMiniDrillOutcomeIDs.insert(outcome.id).inserted else {
            return
        }

        let drillHistory = DrillHistoryStore.shared
        let awardedStreak = drillHistory.streakAfterRecording(
            for: outcome.drill.skillArea,
            succeeded: outcome.succeeded
        )
        let xpBreakdown = DrillXPEngine.breakdown(
            outcome: outcome,
            streak: awardedStreak
        )
        let receipt = DrillHistoryStore.Entry.verified(
            outcomeID: outcome.id,
            variationId: outcome.drill.variation.id,
            skillArea: outcome.drill.skillArea,
            succeeded: outcome.succeeded,
            parentSessionId: parentSession.id,
            terminalWordCount: outcome.wordCount,
            recorderDuration: outcome.duration,
            awardedXP: xpBreakdown.total
        )

        // Durable outcome identity is authoritative across Summary instances
        // and process launches. Nothing else may mutate or present unless the
        // exact evidence receipt was inserted successfully.
        guard drillHistory.record(receipt) else { return }

        print("[QuickDrill] Complete: succeeded=\(outcome.succeeded) fillers=\(outcome.fillerCount) words=\(outcome.wordCount) type=\(outcome.drillType)")
        miniDrillAwardedXP = xpBreakdown.total
        miniDrillXPBreakdown = xpBreakdown
        ProfileManager.shared.addXP(xpBreakdown.total)
        RewardEngine.shared.evaluateDrill(
            skillArea: outcome.drill.skillArea,
            succeeded: outcome.succeeded,
            streak: awardedStreak
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

    /// Active Summary is the causal prescription surface. Only finalized
    /// full-rep recommendations enter the existing learning ledger; the
    /// fallback is always a drill, and historical Review replays never call
    /// this path.
    private func fullRepShownHandler(
        prescription: SummaryPrescriptionProjection,
        goalAttribution: NextActionGoalAttribution?
    ) -> ((PracticeMode) -> Void)? {
        guard onStartLookingAhead != nil else { return nil }
        return { mode in
            recordFullRepPrescriptionShown(
                prescription: prescription,
                goalAttribution: goalAttribution,
                mode: mode
            )
        }
    }

    private func fullRepStartHandler(
        prescription: SummaryPrescriptionProjection,
        goalAttribution: NextActionGoalAttribution?
    ) -> ((PracticeModeLaunchProjection) -> Void)? {
        guard onStartLookingAhead != nil else { return nil }
        return { launch in
            startFullRepPrescription(
                launch: launch,
                prescription: prescription,
                goalAttribution: goalAttribution
            )
        }
    }

    private func recordFullRepPrescriptionShown(
        prescription: SummaryPrescriptionProjection,
        goalAttribution: NextActionGoalAttribution?,
        mode: PracticeMode
    ) {
        guard prescription.source == .finalizedNextAction,
              prescription.fullRepMode == mode,
              onStartLookingAhead != nil else { return }
        recommendationLearningStore.recordShown(
            fingerprint: [
                "summary-next-action",
                latestSessionID?.uuidString ?? "legacy",
                mode.rawValue,
                prescription.title,
                goalAttribution?.targetDimensionID ?? "general",
                goalAttribution?.sourceSessionID.uuidString ?? "no-goal-source",
            ].joined(separator: "|"),
            title: prescription.title,
            focus: prescription.reason,
            target: goalAttribution?.proofTest
                ?? prescription.evidence
                ?? prescription.reason,
            mode: mode,
            isAIBacked: false,
            goal: goalAttribution?.goal,
            targetDimensionID: goalAttribution?.targetDimensionID,
            sourceSessionID: goalAttribution?.sourceSessionID ?? latestSessionID
        )
    }

    private func startFullRepPrescription(
        launch: PracticeModeLaunchProjection,
        prescription: SummaryPrescriptionProjection,
        goalAttribution: NextActionGoalAttribution?
    ) {
        guard let onStartLookingAhead else { return }
        RecommendationTapAttribution.apply(
            launch: launch,
            recordShown: {
                // Idempotent with the card's onAppear path and authoritative
                // for a fast tap even when the live route must fall back.
                recordFullRepPrescriptionShown(
                    prescription: prescription,
                    goalAttribution: goalAttribution,
                    mode: launch.displayedMode
                )
            },
            recordAccepted: { mode in
                recommendationLearningStore.markTapped(mode: mode)
            }
        )
        if !launch.acceptsDisplayedPrescription {
            // An operational fallback is manual setup, never a continuation
            // of an interrupted one-tap launch from another surface.
            PracticeModeQuickStart.clear()
        }
        onStartLookingAhead(launch.destination)
    }

    // MARK: - Setup & Logic

    private func setup() {
        guard !didApplyXP else { return }
        didApplyXP = true
        let retryMilestonePresentation = currentTranscriptRetryMilestonePresentation
        resolvedRetryMilestonePresentation = retryMilestonePresentation
        didResolveRetryMilestonePresentation = true
        lockedTranscriptText = String(transcript.characters)
        lockedFillerCount = fillerCount
        lockedDuration = duration
        lockedScore = score
        lockedFeedbackOverride = feedbackOverride
        lockedHeadlineOverride = headlineOverride
        lockedScoreBreakdown = scoreBreakdown
        lockedInsights = insights
        aiFeedback = currentRepIsProgressEligible
            ? currentStoredSession?.evidenceSafeAICoachFeedback
            : nil
        progressionPreviousXP = profile.xp
        displayedXP = profile.xp
        currentLevel = ProfileManager.levelTitle(forXP: profile.xp)
        nextLevel = ProfileManager.levelTitle(forXP: ((profile.xp / 1000) + 1) * 1000)
        xpToNext = ProfileManager.xpNeededToNextLevel(forXP: profile.xp)
        progress = ProfileManager.progressTowardsNextLevel(forXP: profile.xp)

        // Sudden Death commits lifecycle effects on run completion so replay
        // can never skip earned progress. Other modes still commit here.
        let result: SessionFinalizationResult
        if currentRepIsProgressEligible {
            result = committedFinalization ?? SessionFinalizer.finalize(
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
                pressureLevel: currentStoredSession?.pressureLevel ?? .standard,
                transcript: transcriptText
            )
        } else {
            result = SessionFinalizer.withheldResult()
        }

        progressionDeltas = result.achievementDeltas
        progressionNewUnlocks = result.newUnlocks
        enhancedCoachNote = result.coachNote
        finalizedNextAction = result.nextAction
        eloquenceFindings = result.eloquenceFindings
        // Source of truth for pre-rep XP is the finalizer result — for
        // Sudden Death the commit happened at run completion, so the
        // setup()-time profile.xp snapshot would already include the rep.
        progressionPreviousXP = result.previousXP

        animateXP(
            to: result.newXP,
            playsCompletionHaptic: retryMilestonePresentation == nil
        )
        // Results now opens as one calm coaching receipt. Progress and score
        // remain visible immediately without a separate sound or fanfare beat.

        // Capture every earned event for the single inline Results receipt.
        sessionMilestone = result.milestone
        preSummaryEvents = currentRepIsProgressEligible
            ? skillProgression.pendingLevelUps
            : []
        let completedRepCount = sessionStore.progressEligibleSessionCount

        // App review is earned at a satisfaction moment, never at launch,
        // after an error, or from a historical replay. A personal best after
        // an earlier rep is the strongest verified-improvement signal;
        // otherwise the pure policy first permits the third qualifying rep.
        if currentRepIsProgressEligible, onStartLookingAhead != nil {
            reviewPromptExitGate.arm(
                result.isPersonalBest && completedRepCount > 1
                    ? .firstVerifiedImprovement
                    : .qualifyingRepCompleted
            )
        }

        // First-rep celebration used to stack on top of the summary. The
        // cohesive pass deliberately starts with the useful coaching read;
        // dismissing here also marks the once-only manager so it cannot leak
        // into a later rep.
        if completedRepCount == 1 {
            FirstRepCelebrationManager.shared.dismiss()
        }

        // The receipt owns presentation. Drain the pending overlay queue now so
        // no old full-screen event can leak into the next rep.
        skillProgression.consumeAll()

        #if DEBUG
        presentRequestedMiniDrillCompletionFixtureIfNeeded()
        #endif

    }

    #if DEBUG
    /// Enters the real Summary-owned mini-drill route for rendered integrity
    /// tests. The fixture does not assign a result or reward: eligible evidence
    /// must still return through `handleDrillComplete(_:)`, whose durable
    /// receipt insertion is the gate in front of every visible result/effect.
    private func presentRequestedMiniDrillCompletionFixtureIfNeeded() {
        guard MiniDrillCompletionUITestFixture.requested() != nil,
              let variation = DrillCatalog.allVariations.first(where: {
                $0.id == MiniDrillCompletionUITestFixture.variationID
              }) else {
            return
        }
        let drill = DrillRecommendationV2(
            variation: variation,
            reason: "Rendered mini-drill completion integrity",
            trendContext: nil,
            alternateFormat: nil
        )
        DispatchQueue.main.async {
            guard activeMiniDrill == nil, miniDrillOutcome == nil else { return }
            activeMiniDrill = drill
        }
    }
    #endif

    private func requestDeeperFeedback() async {
        aiError = nil

        guard currentRepIsProgressEligible else {
            aiError = "This capture is saved for review, but there isn't enough speech for a deeper read."
            return
        }

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

        guard let sessionID = latestSessionID,
              let currentSession = sessionStore.sessions.first(where: { $0.id == sessionID }),
              let saveToken = sessionStore.coachReadSaveToken(sessionID: sessionID),
              saveToken.source == currentSession.coachReadSourceSnapshot else {
            aiError = "This session has not been saved yet. Finish one more rep and try again."
            return
        }

        let text = currentSession.transcript
        let wordCount = currentSession.wordCount
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
            // THE QUESTION ASKED — the stored prompt of this rep, the single
            // source of truth the deterministic verdict + the rubric both read.
            let repPrompt = currentSession.prompt ?? ""
            // Continuity is deliberately mode + score only. Historical filler
            // and pace mechanics need a durable typed receipt before free-form
            // prose can compare them safely across replay.
            let priorSummaries = AICoachService.recentCoachReadSummaries(
                sessions: sessionStore.sessions,
                currentRepID: sessionID
            )
            let feedback = try await aiCoachService.generateDeeperFeedback(
                input: AICoachSessionInput(
                    transcript: text,
                    mode: currentSession.mode,
                    score: currentSession.score,
                    duration: currentSession.duration,
                    speakingIdentity: styleSnapshot.identity,
                    prompt: repPrompt,
                    voice: coachingProfileStore.profile?.chosenStyleGoal,
                    recentSessionSummaries: priorSummaries,
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
            guard let savedFeedback = sessionStore.saveAIFeedback(
                expected: saveToken,
                feedback: feedback
            ) else {
                aiError = "This Coach Read could not be attached to the saved rep. Try again from Review."
                return
            }
            aiFeedback = savedFeedback
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
        guard currentRepIsProgressEligible else {
            aiError = "This capture is saved for review, but there isn't enough speech for a delivery read."
            return
        }
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

    private func animateXP(to endXP: Int, playsCompletionHaptic: Bool) {
        let shouldReduceMotion = reduceMotion
        Task {
            if shouldReduceMotion {
                await MainActor.run {
                    let earned = endXP > displayedXP
                    displayedXP = endXP
                    progress = ProfileManager.progressTowardsNextLevel(forXP: endXP)
                    currentLevel = ProfileManager.levelTitle(forXP: endXP)
                    nextLevel = ProfileManager.levelTitle(forXP: ((endXP / 1000) + 1) * 1000)
                    xpToNext = ProfileManager.xpNeededToNextLevel(forXP: endXP)
                    if earned && playsCompletionHaptic { CoachHaptic.xpEarned() }
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
                if endXP > startXP && playsCompletionHaptic { CoachHaptic.xpEarned() }
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
        self.finalizedSessionID = entry?.finalizedSessionID
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
        let journeyOrigin = store.journeyOrigin(for: payload.id)
        // Captured for "Practice Again" so IM reps re-arm the just-finished
        // scenario + tone instead of dropping back on the picker. The
        // other modes have no per-rep setup, so the router ignores this.
        let practiceAgainIMSetup = entry?.imConversationDetails?.setup
        self.onHome = {
            SummaryDataStore.shared.remove(for: payloadId)
            let disposition = SummaryJourneyExitRouter.disposition(
                origin: journeyOrigin,
                activeBigMomentID: BigMomentStore.shared.activeMoment?.id
            )
            guard disposition == .resumePreparation else {
                pathBinding.wrappedValue = NavigationPath()
                return
            }

            // Expected stack: preparation → practice → Summary. Pop the two
            // transient destinations and leave the existing PrepSessionView
            // in place so its observed stores refresh the readiness receipt.
            var path = pathBinding.wrappedValue
            guard path.count >= 3 else {
                pathBinding.wrappedValue = NavigationPath()
                return
            }
            path.removeLast()
            path.removeLast()
            pathBinding.wrappedValue = path
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
