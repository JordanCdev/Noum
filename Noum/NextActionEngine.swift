import Foundation

// MARK: - Next Action

/// The single unified recommendation produced after every session.
/// Represents the ONE thing the user should do next, with reasoning.
struct NextAction {
    let primary: ActionRecommendation      // The one thing to do
    let secondary: ActionRecommendation?   // Optional alternative
    let reasoning: String                  // Why this was chosen
    let confidenceLevel: BaselineConfidence // How much data backs this recommendation
    /// Explicit provenance for an operational capability fallback. The
    /// original gated mode is retained so downstream trust UI never has to
    /// infer fallback state from mutable display copy.
    let availabilityFallbackFrom: PracticeMode?

    init(
        primary: ActionRecommendation,
        secondary: ActionRecommendation?,
        reasoning: String,
        confidenceLevel: BaselineConfidence,
        availabilityFallbackFrom: PracticeMode? = nil
    ) {
        self.primary = primary
        self.secondary = secondary
        self.reasoning = reasoning
        self.confidenceLevel = confidenceLevel
        self.availabilityFallbackFrom = availabilityFallbackFrom
    }
}

/// A specific recommended action.
enum ActionRecommendation: Equatable {
    /// A targeted drill for a specific skill area.
    case drill(DrillRecommendationV2)
    /// Practice again in a specific mode (general improvement).
    case practiceMode(PracticeMode, reason: String)
    /// Expose to pressure — user is strong casually but hasn't been tested under pressure.
    case pressureExposure(PracticeMode, reason: String)
    /// Another rep to stabilize a recently improved skill.
    case stabilizingRep(PracticeMode, reason: String)
    /// Confidence rebuilding — user's performance dipped and needs a win.
    case confidenceRebuilding(DrillRecommendationV2)

    var displayTitle: String {
        switch self {
        case .drill(let rec): return rec.title
        case .practiceMode(let mode, _): return mode.displayLabel
        case .pressureExposure(let mode, _): return "\(mode.displayLabel) · Pressure"
        case .stabilizingRep(let mode, _): return "\(mode.displayLabel) · Steady the gain"
        case .confidenceRebuilding(let rec): return rec.title
        }
    }

    var displayReason: String {
        switch self {
        case .drill(let rec): return rec.reason
        case .practiceMode(_, let reason): return reason
        case .pressureExposure(_, let reason): return reason
        case .stabilizingRep(_, let reason): return reason
        case .confidenceRebuilding(let rec): return rec.reason
        }
    }

    static func == (lhs: ActionRecommendation, rhs: ActionRecommendation) -> Bool {
        lhs.displayTitle == rhs.displayTitle
    }
}

/// Pure snapshot of practice-mode capabilities at recommendation time.
/// Callers combine the current rated-evidence gate with the live IM
/// capability; the engine never reaches into either state owner itself.
struct NextActionModeAvailability: Equatable {
    let suddenDeathAvailable: Bool
    let imConversationAvailable: Bool

    /// Safe default for any caller that has not yet supplied rated evidence.
    /// Explicitly unlocked tests and trusted contexts can use `allAvailable`.
    static let failClosed = NextActionModeAvailability(
        suddenDeathAvailable: false,
        imConversationAvailable: false
    )
    static let allAvailable = NextActionModeAvailability(
        suddenDeathAvailable: true,
        imConversationAvailable: true
    )

    static var suddenDeathFallbackReason: String {
        "\(PracticeModePrescriptionCopy.pressureLockedHint) Start with Timed Practice."
    }

    static let imConversationFallbackReason =
        "Conversation Practice isn't available here yet. Start with Timed Practice."

    init(
        suddenDeathAvailable: Bool,
        imConversationAvailable: Bool
    ) {
        self.suddenDeathAvailable = suddenDeathAvailable
        self.imConversationAvailable = imConversationAvailable
    }

    init(
        rating: SpeakingRating,
        imConversationAvailable: Bool = false
    ) {
        suddenDeathAvailable = PracticeModeAvailability.isUnlocked(
            .suddenDeath,
            rating: rating
        )
        self.imConversationAvailable = imConversationAvailable
    }

    func isAvailable(_ mode: PracticeMode) -> Bool {
        switch mode {
        case .timed, .ahCounter:
            return true
        case .suddenDeath:
            return suddenDeathAvailable
        case .imConversation:
            return imConversationAvailable
        }
    }

    static func fallbackReason(for mode: PracticeMode) -> String? {
        switch mode {
        case .suddenDeath:
            return suddenDeathFallbackReason
        case .imConversation:
            return imConversationFallbackReason
        case .timed, .ahCounter:
            return nil
        }
    }

    private static func fallbackDisplayReason(for mode: PracticeMode) -> String? {
        switch mode {
        case .suddenDeath:
            return PracticeModePrescriptionCopy.pressureLockedDisplayHint
        case .imConversation:
            return imConversationFallbackReason
        case .timed, .ahCounter:
            return nil
        }
    }

    /// Applies the same availability snapshot to recommendation blueprints
    /// used outside the post-rep engine. This keeps Home, Ask Noum, and Train
    /// copy aligned with the destination instead of merely rerouting a locked
    /// Pressure Drill card to Timed Practice.
    func resolving(_ blueprint: RecommendationBiasBlueprint) -> RecommendationBiasBlueprint {
        let unavailableMode = blueprint.recommendedMode
        guard isAvailable(unavailableMode) else {
            let timedBenefit = RecommendationBiasEngine.playbook.first {
                $0.mode == .timed
            }
            let fallbackFocus: String
            let fallbackTarget: String
            switch unavailableMode {
            case .imConversation:
                // A missing IM provider is an operational constraint, not a
                // loss of coaching evidence. Keep the established focus and
                // target while moving the rep to Timed Practice; only the
                // mode-specific setup and benefit copy are replaced.
                fallbackFocus = Self.normalized(blueprint.focus)
                    ?? "Rehearse the same conversational focus"
                fallbackTarget = Self.normalized(blueprint.target)
                    ?? "Complete one focused Timed rep"
            case .suddenDeath, .timed, .ahCounter:
                fallbackFocus = "First clear read"
                fallbackTarget = "Complete one rated rep"
            }
            return RecommendationBiasBlueprint(
                recommendedMode: .timed,
                recommendedTone: nil,
                recommendedScenario: nil,
                focus: fallbackFocus,
                target: fallbackTarget,
                modeBenefit: timedBenefit?.benefit ?? "Builds a clean, rated speaking baseline.",
                whyMode: timedBenefit?.bestFor ?? "Timed Practice creates a clear rated starting point.",
                whyNow: Self.fallbackDisplayReason(for: unavailableMode)
                    ?? "Timed Practice is ready now.",
                suggestedTimedDifficulty: nil,
                suggestedTheme: blueprint.suggestedTheme,
                source: blueprint.source
            )
        }
        return blueprint
    }

    private static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension ActionRecommendation {
    var recommendedMode: PracticeMode? {
        switch self {
        case .drill, .confidenceRebuilding:
            return nil
        case .practiceMode(let mode, _),
             .pressureExposure(let mode, _),
             .stabilizingRep(let mode, _):
            return mode
        }
    }

    func resolvingModeAvailability(
        _ availability: NextActionModeAvailability
    ) -> (action: ActionRecommendation, didFallback: Bool) {
        guard let recommendedMode,
              !availability.isAvailable(recommendedMode) else {
            return (self, false)
        }
        return (
            .practiceMode(
                .timed,
                reason: NextActionModeAvailability.fallbackReason(for: recommendedMode)
                    ?? "Timed Practice is ready now."
            ),
            true
        )
    }
}

// MARK: - Summary Prescription Projection

/// Presentation projection for the one adaptive action shown on an active
/// Summary. `SessionFinalizer` / `NextActionEngine` keep strategic ownership;
/// this type only translates that decision into one of the two renderers the
/// Summary already supports: a focused drill or a full practice rep.
///
/// A nil `NextAction` deliberately falls back to the caller's existing
/// `DrillEngineV2` recommendation. That preserves first-rep, below-evidence-
/// floor and legacy Summary paths without allowing a second engine result to
/// replace a finalized recommendation.
struct SummaryPrescriptionProjection {
    enum Source: Equatable {
        case finalizedNextAction
        case drillFallback
    }

    enum Kind {
        case drill(DrillRecommendationV2)
        case fullRep(
            mode: PracticeMode,
            scenario: IMConversationScenario?,
            tone: IMTargetTone?
        )
    }

    let source: Source
    let kind: Kind
    let title: String
    /// The action-specific reason (for example the observed pressure gap).
    let reason: String
    /// The decision engine's wider evidence read. Nil for a legacy fallback or
    /// when it would merely repeat `reason`.
    let evidence: String?
    /// Human-readable evidence depth from the finalized baseline. A fallback
    /// drill has no finalized evidence claim, so this stays nil.
    let confidenceLabel: String?
    /// The exact capability snapshot used to shape this projection. Keeping
    /// it beside the rendered action lets the tap route enforce the same
    /// decision instead of reinterpreting availability later.
    let modeAvailability: NextActionModeAvailability

    static func resolve(
        nextAction: NextAction?,
        fallbackDrill: DrillRecommendationV2,
        existingScenario: IMConversationScenario? = nil,
        existingTone: IMTargetTone? = nil,
        modeAvailability: NextActionModeAvailability = .failClosed
    ) -> SummaryPrescriptionProjection {
        guard let nextAction else {
            return SummaryPrescriptionProjection(
                source: .drillFallback,
                kind: .drill(fallbackDrill),
                title: fallbackDrill.title,
                reason: fallbackDrill.reason,
                evidence: normalized(fallbackDrill.trendContext),
                confidenceLabel: nil,
                modeAvailability: modeAvailability
            )
        }

        let resolution = nextAction.primary.resolvingModeAvailability(modeAvailability)
        let action = resolution.action
        let kind: Kind
        switch action {
        case .drill(let drill), .confidenceRebuilding(let drill):
            kind = .drill(drill)
        case .practiceMode(let mode, _),
             .pressureExposure(let mode, _),
             .stabilizingRep(let mode, _):
            kind = .fullRep(
                mode: mode,
                scenario: mode == .imConversation ? existingScenario : nil,
                tone: mode == .imConversation ? existingTone : nil
            )
        }

        let reason = normalized(action.displayReason) ?? action.displayTitle
        let isAvailabilityFallback = resolution.didFallback
            || nextAction.availabilityFallbackFrom != nil
        // A stale finalized Pressure Drill action must not leave pressure copy
        // attached to the Timed fallback. The fallback reason is already the
        // complete explanation, so suppress the now-inapplicable evidence line.
        let widerEvidence = isAvailabilityFallback
            ? nil
            : normalized(nextAction.reasoning)
        return SummaryPrescriptionProjection(
            source: .finalizedNextAction,
            kind: kind,
            title: action.displayTitle,
            reason: reason,
            evidence: isSameCopy(reason, widerEvidence) ? nil : widerEvidence,
            confidenceLabel: isAvailabilityFallback
                ? nil
                : nextAction.confidenceLevel.label,
            modeAvailability: modeAvailability
        )
    }

    /// Full-rep actions route through the existing shared mapping. Drill
    /// actions return nil because their mini/full behavior stays with
    /// `SummaryDrillActionCard` and the existing drill callbacks.
    func launch(imAvailable: Bool) -> PracticeModeLaunchProjection? {
        guard case .fullRep(let mode, let scenario, let tone) = kind else {
            return nil
        }
        return PracticeModeLaunchProjection.resolve(
            displayedMode: mode,
            scenario: scenario,
            tone: tone,
            imAvailable: imAvailable,
            modeAvailability: modeAvailability
        )
    }

    func destination(imAvailable: Bool) -> AppDestination? {
        launch(imAvailable: imAvailable)?.destination
    }

    var fullRepMode: PracticeMode? {
        guard case .fullRep(let mode, _, _) = kind else { return nil }
        return mode
    }

    private static func normalized(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    private static func isSameCopy(_ lhs: String, _ rhs: String?) -> Bool {
        guard let rhs else { return false }
        return lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }
}

// MARK: - Input Bundle

/// All the data the decision engine considers.
struct NextActionInput {
    let fillerCount: Int
    let duration: TimeInterval
    let wordCount: Int
    let wpm: Double
    let score: Int
    let categoryRatings: [String: String]
    let mode: PracticeMode
    let pressureLevel: PressureLevel

    let baseline: CommunicationBaseline
    let pressureProfile: PressureProfile
    let trends: [SkillTrend]
    let drillHistory: [DrillHistoryStore.Entry]

    let sessionCount: Int
    let streakDays: Int
    let styleGoal: String?

    /// Pure snapshot supplied by the current rating owner. It fails closed so
    /// an omitted argument cannot prescribe a still-locked Pressure Drill.
    var modeAvailability: NextActionModeAvailability = .failClosed

    /// The recommendation outcome ledger, passed IN so the engine stays a pure
    /// value-transform (it never reaches `RecommendationLearningStore.shared`).
    /// Defaulted empty: every existing call site compiles unchanged, and an empty
    /// ledger yields a nil verdict, so the engine behaves exactly as before until
    /// ≥3 measurable reps exist for a mode.
    var recommendationOutcomes: [RecommendationOutcome] = []
}

// MARK: - Next Action Engine

/// The unified decision engine. After every session, it produces ONE strategic recommendation.
///
/// Decision priority (highest → lowest):
/// 1. Severe session issue (qualifying filler burden ≥ 8/min, duration < 8s, qualifying WPM > 200)
/// 2. Persistent blocker (same issue for 10+ sessions)
/// 3. Pressure gap (strong casually but untested under pressure)
/// 4. Declining trend with high confidence
/// 5. New issue detected
/// 6. Improving trend (reinforcing rep)
/// 7. Stable + strong (stretch challenge)
/// 8. Default (TrendAnalyzer primary focus)
enum NextActionEngine {

    static func recommend(input: NextActionInput) -> NextAction {
        applyingModeAvailability(
            to: recommendWithoutModeAvailability(input: input),
            availability: input.modeAvailability
        )
    }

    /// Finalization entry point. Thin baseline evidence still suppresses the
    /// adaptive cascade, but a directly observed severe issue can prescribe
    /// one immediate corrective rep without pretending a trend exists.
    static func recommendAfterSession(input: NextActionInput) -> NextAction? {
        if input.baseline.qualifyingSessionCount >= 2 {
            return recommend(input: input)
        }
        guard let immediate = severeRecommendation(input: input) else {
            return nil
        }
        return applyingModeAvailability(
            to: immediate,
            availability: input.modeAvailability
        )
    }

    private static func recommendWithoutModeAvailability(input: NextActionInput) -> NextAction {
        let confidence = input.baseline.overallConfidence
        let style = SpeakingStyleGoal.resolve(input.styleGoal)

        // --- Priority 1: Severe session issue ---
        if let immediate = severeRecommendation(input: input) {
            return immediate
        }

        // --- Priority 2: Persistent blocker ---
        if confidence >= .moderate, let blocker = checkPersistentBlocker(input: input) {
            return NextAction(
                primary: blocker,
                secondary: nil,
                reasoning: groundInGoal("This is a persistent pattern across many sessions, so focused work here is the clearest next step.", action: blocker, style: style),
                confidenceLevel: confidence
            )
        }

        // --- Priority 3: Pressure gap ---
        if confidence >= .moderate, let pressureAction = checkPressureGap(input: input) {
            return NextAction(
                primary: pressureAction,
                secondary: standardDrill(input: input),
                reasoning: "Your casual reps have read stronger than your pressure reps. One pressure rep can test that gap.",
                confidenceLevel: confidence
            )
        }

        // --- Priority 4: Declining trend ---
        if let declining = checkDecliningTrend(input: input) {
            let base = ConfidencePhrasing.frame("A previously stronger skill read lower recently. One focused drill can test whether the pattern responds.", confidence: confidence)
            return NextAction(
                primary: declining,
                secondary: nil,
                reasoning: groundInGoal(base, action: declining, style: style),
                confidenceLevel: confidence
            )
        }

        // --- Priority 5: New issue ---
        if let newIssue = checkNewIssue(input: input) {
            return NextAction(
                primary: newIssue,
                secondary: nil,
                reasoning: groundInGoal("This just appeared in the latest evidence. One focused rep can test whether it repeats.", action: newIssue, style: style),
                confidenceLevel: confidence
            )
        }

        // --- Priority 6: Improving trend ---
        // A confidently-replaced mode is NOT re-handed as a stabilizing rep:
        // when the ledger shows this mode's metric trending down over ≥6
        // measurable reps, the coach varies the modality instead of repeating
        // it, so we fall through to a targeted drill below. Pure tie-breaker —
        // the cascade past here is always total.
        if let reinforcing = checkImprovingTrend(input: input),
           !shouldDeferReinforcement(reinforcing, input: input) {
            let base = ConfidencePhrasing.frame("Recent evidence shows progress in the right direction. One more rep can test whether it holds.", confidence: confidence)
            return NextAction(
                primary: reinforcing,
                secondary: stretchChallenge(input: input),
                reasoning: groundInGoal(base, action: reinforcing, style: style),
                confidenceLevel: confidence
            )
        }

        // --- Priority 7: Stable + strong ---
        if input.score >= 7, let stretch = stretchChallenge(input: input) {
            return NextAction(
                primary: stretch,
                secondary: standardDrill(input: input),
                reasoning: "Recent performance has held up. A stretch rep can test the next edge.",
                confidenceLevel: confidence
            )
        }

        // --- Priority 8: Default ---
        let defaultDrill = standardDrill(input: input)
        return NextAction(
            primary: defaultDrill ?? .practiceMode(.timed, reason: "Keep building your baseline with another practice session."),
            secondary: nil,
            reasoning: "Continued practice builds your baseline and reveals where to focus next.",
            confidenceLevel: confidence
        )
    }

    /// Apply availability once, after the strategic cascade, so every current
    /// and future action shape is covered. The engine changes the action, copy,
    /// and secondary coherently instead of relying on a downstream route guard.
    private static func applyingModeAvailability(
        to recommendation: NextAction,
        availability: NextActionModeAvailability
    ) -> NextAction {
        let primaryResolution = recommendation.primary
            .resolvingModeAvailability(availability)
        let resolvedSecondary = recommendation.secondary?
            .resolvingModeAvailability(availability)
            .action
        let secondary = resolvedSecondary == primaryResolution.action
            ? nil
            : resolvedSecondary

        return NextAction(
            primary: primaryResolution.action,
            secondary: secondary,
            reasoning: primaryResolution.didFallback
                ? primaryResolution.action.displayReason
                : recommendation.reasoning,
            confidenceLevel: recommendation.confidenceLevel,
            availabilityFallbackFrom: primaryResolution.didFallback
                ? recommendation.primary.recommendedMode
                : recommendation.availabilityFallbackFrom
        )
    }

    /// Append a short goal-grounded suffix when the recommended drill targets
    /// a skill that's directly aligned with the user's chosen voice goal.
    /// Silent when the action isn't a drill or the skill isn't aligned —
    /// staying quiet beats forcing a connection that isn't there.
    private static func groundInGoal(_ base: String, action: ActionRecommendation, style: SpeakingStyleGoal?) -> String {
        guard let style else { return base }
        let skill: SkillArea? = {
            switch action {
            case .drill(let rec): return rec.skillArea
            case .confidenceRebuilding(let rec): return rec.skillArea
            case .practiceMode, .pressureExposure, .stabilizingRep: return nil
            }
        }()
        guard let skill, style.aligns(with: skill) else { return base }
        return base + " It's a direct step toward your \(style.shortVoiceLabel)."
    }

    // MARK: - Adaptation bias

    /// True iff the outcome ledger confidently says to REPLACE `mode`: a
    /// `.replace`/`.confident` adaptation verdict (the analyzer's ≥6-measurable-rep
    /// + genuinely-negative-recent-window bar). This is the single tie-breaker
    /// predicate shared across the selection cascade.
    ///
    /// It is a pure read of `input.recommendationOutcomes` (the defaulted-empty
    /// ledger passed IN — the engine never reaches the store), so an empty or
    /// below-floor ledger ALWAYS returns `false`: every tie-breaker built on it is
    /// a guaranteed no-op until ≥6 measurable reps for the mode exist, and the
    /// analyzer's own floors mean `.vary`/`.reinforce`/tentative verdicts also
    /// return `false`. Only a confident `.replace` — the one verdict that says a
    /// mode's metric has trended down across the window — ever biases selection.
    private static func confidentReplace(forMode mode: PracticeMode, input: NextActionInput) -> Bool {
        RecommendationAdaptationAnalyzer.confidentlyReplaces(
            mode: mode,
            in: input.recommendationOutcomes
        )
    }

    /// Whether a Priority-6 reinforcement should be deferred because the outcome
    /// ledger confidently says to REPLACE the mode it would repeat. Only a
    /// `.stabilizingRep` (the one action that concretely re-prescribes the
    /// just-practiced mode) is gated, and only on a confident `.replace` verdict
    /// (≥6 measurable reps trending down, via `confidentReplace`) — a `.vary` or
    /// `.reinforce` verdict, or thin evidence, never defers. Falling through hands
    /// the user a targeted drill for the improving skill instead of repeating a
    /// mode the evidence says is not moving the metric.
    ///
    /// Scope of the adaptation verdict across the cascade: it is a TIE-BREAKER
    /// over P3 (pressure), P6 (this reinforcement) and P7 (stretch) ONLY — and
    /// only ever biases AWAY from a confidently-replaced mode (never INTO one,
    /// never toward `nil` where an action was previously returned). The hard
    /// real-time signals P1/P2/P4/P5 (severe/blocker/declining/new-issue) return
    /// before any tie-breaker and are never suppressed; the skill-keyed P8 `.drill`
    /// is likewise never overridden — a per-MODE verdict must not veto a
    /// SKILL-keyed drill (P8 stays inert; at most its fallback `.practiceMode`
    /// could bias away from `input.mode`). `.vary` is inert and an empty ledger is
    /// a guaranteed no-op, so `recommend()` stays a total function throughout.
    private static func shouldDeferReinforcement(_ action: ActionRecommendation, input: NextActionInput) -> Bool {
        let mode: PracticeMode
        switch action {
        case .stabilizingRep(let m, _), .pressureExposure(let m, _):
            mode = m
        case .drill, .confidenceRebuilding, .practiceMode:
            return false
        }
        return confidentReplace(forMode: mode, input: input)
    }

    // MARK: - Priority Checks

    private static func severeRecommendation(input: NextActionInput) -> NextAction? {
        guard let severe = checkSevereIssue(input: input) else { return nil }
        return NextAction(
            primary: severe,
            secondary: severe.recommendedMode == .ahCounter
                ? nil
                : fallbackDrill(input: input),
            reasoning: "This rep showed one clear constraint, so the next rep should isolate it.",
            confidenceLevel: .stable
        )
    }

    /// Priority 1: Severe session issues that need immediate correction.
    private static func checkSevereIssue(input: NextActionInput) -> ActionRecommendation? {
        let fillerBurden = FillerBurden(
            fillerCount: input.fillerCount,
            duration: input.duration
        )
        if fillerBurden.meets(.severe) {
            return .practiceMode(
                .ahCounter,
                reason: "Fillers carried too much of this rep. Use Filler Control to replace the next one with a pause."
            )
        }
        if input.duration < 8 && input.wordCount > 0 {
            if let drill = selectDrill(for: .answerDevelopment, input: input) {
                return .drill(drill)
            }
        }
        if SessionQualifier.meetsQuantityFloor(
            duration: input.duration,
            wordCount: input.wordCount
        ), input.wpm.isFinite, input.wpm > 200 {
            if let drill = selectDrill(for: .paceControl, input: input) {
                return .drill(drill)
            }
        }
        return nil
    }

    /// Priority 2: Issues that have persisted for 10+ sessions.
    private static func checkPersistentBlocker(input: NextActionInput) -> ActionRecommendation? {
        let blockers = input.baseline.persistentBlockers
        guard !blockers.isEmpty else { return nil }

        // Map blocker names back to skill areas
        // Keys must match exactly what BaselineEngine.identifyBlockers() produces
        let blockerToSkill: [String: SkillArea] = [
            "Filler words": .fillerReduction,
            "Pace control": .paceControl,
            "Opening strength": .openingStrength,
            "Structure": .structure,
            "Hedging language": .confidence,
        ]

        for blocker in blockers {
            if let skillArea = blockerToSkill[blocker],
               let drill = selectDrill(for: skillArea, input: input) {
                // For persistent blockers, suggest a deeper approach
                return .confidenceRebuilding(drill)
            }
        }
        return nil
    }

    /// Priority 3: Strong casually but untested or weak under pressure.
    private static func checkPressureGap(input: NextActionInput) -> ActionRecommendation? {
        guard let resilience = input.pressureProfile.pressureResilience,
              resilience < 0.6 else { return nil }

        // Only suggest pressure exposure if user has enough casual data and is doing well casually
        guard input.baseline.qualifyingSessionCount >= 8,
              input.baseline.averageScore.isReliable,
              input.baseline.averageScore.value >= 6.0 else { return nil }

        // Don't suggest pressure exposure if the user just did a high-pressure session
        guard input.pressureLevel < .elevated else { return nil }

        let mode: PracticeMode = input.mode == .suddenDeath ? .timed : .suddenDeath

        // Adaptation tie-breaker: if the ledger confidently says to REPLACE this
        // pressure mode, bias AWAY — flip to the other pressure mode. If THAT one
        // is also confidently-replaced (both pressure modes not moving the metric),
        // fall through (return nil) so the cascade hands a drill/stretch instead of
        // re-prescribing a pressure mode the evidence says is stalled. An empty or
        // below-floor ledger makes both checks `false`, so this preserves today's
        // chosen mode byte-for-byte until ≥6 measurable reps exist.
        if confidentReplace(forMode: mode, input: input) {
            let flipped: PracticeMode = mode == .suddenDeath ? .timed : .suddenDeath
            guard !confidentReplace(forMode: flipped, input: input) else { return nil }
            return .pressureExposure(flipped, reason: "Your casual delivery has read stronger than your pressure reps. One pressure rep can test the gap.")
        }

        return .pressureExposure(mode, reason: "Your casual delivery has read stronger than your pressure reps. One pressure rep can test the gap.")
    }

    /// Priority 4: A skill that was strong is now declining.
    private static func checkDecliningTrend(input: NextActionInput) -> ActionRecommendation? {
        let declining = input.trends.filter { $0.direction == .declining }
        guard !declining.isEmpty else { return nil }

        // Pick the most important declining trend
        let priorityOrder: [SkillArea] = [
            .fillerReduction, .paceControl, .structure,
            .openingStrength, .closingStrength, .answerDevelopment,
            .confidence, .conciseSpeaking
        ]

        for area in priorityOrder {
            if declining.contains(where: { $0.skillArea == area }) {
                if let drill = selectDrill(for: area, input: input) {
                    return .drill(drill)
                }
            }
        }
        return nil
    }

    /// Priority 5: A new issue just appeared.
    private static func checkNewIssue(input: NextActionInput) -> ActionRecommendation? {
        let newIssues = input.trends.filter { $0.direction == .newIssue }
        guard !newIssues.isEmpty else { return nil }

        if let first = newIssues.first, let drill = selectDrill(for: first.skillArea, input: input) {
            return .drill(drill)
        }
        return nil
    }

    /// Priority 6: A skill is improving — reinforce with a stabilizing rep.
    private static func checkImprovingTrend(input: NextActionInput) -> ActionRecommendation? {
        let improving = input.trends.filter { $0.direction == .improving }
        guard !improving.isEmpty else { return nil }

        // If the improving area matches a recent drill, suggest another rep
        if let recentDrillArea = input.drillHistory.first?.skillArea,
           improving.contains(where: { $0.skillArea == recentDrillArea }) {
            return .stabilizingRep(input.mode, reason: "Your \(recentDrillArea.displayName.lowercased()) has read stronger recently. Another rep can test whether it holds.")
        }

        // Otherwise suggest a drill for the improving area
        if let first = improving.first, let drill = selectDrill(for: first.skillArea, input: input) {
            return .drill(drill)
        }
        return nil
    }

    // MARK: - Helpers

    /// Select a drill from the catalog for a given skill area.
    private static func selectDrill(for area: SkillArea, input: NextActionInput) -> DrillRecommendationV2? {
        return DrillEngineV2.recommend(
            fillerCount: input.fillerCount,
            duration: input.duration,
            wordCount: input.wordCount,
            score: input.score,
            feedbackCategories: input.categoryRatings.map { (dimension: $0.key, rating: $0.value) },
            targetArea: area
        )
    }

    /// A standard drill recommendation using DrillEngineV2. Passes through the
    /// resolved style goal so the focus picker can prefer goal-aligned skills
    /// when otherwise-equivalent candidates are tied — the only path where
    /// the engine picks the skill itself (priority 1–7 hand it a `targetArea`).
    private static func standardDrill(input: NextActionInput) -> ActionRecommendation? {
        let style = SpeakingStyleGoal.resolve(input.styleGoal)
        let rec = DrillEngineV2.recommend(
            fillerCount: input.fillerCount,
            duration: input.duration,
            wordCount: input.wordCount,
            score: input.score,
            feedbackCategories: input.categoryRatings.map { (dimension: $0.key, rating: $0.value) },
            styleGoal: style
        )
        return .drill(rec)
    }

    /// A fallback drill recommendation when the primary action is severe.
    private static func fallbackDrill(input: NextActionInput) -> ActionRecommendation? {
        if input.score >= 5 {
            return .practiceMode(.timed, reason: "Or just practice again — the habit itself is valuable.")
        }
        return nil
    }

    /// A stretch challenge for users who are performing well.
    ///
    /// Adaptation tie-breaker: each mode-keyed branch checks `confidentReplace` for
    /// the mode it is about to prescribe and, on a confident `.replace`, biases to
    /// an ALTERNATIVE stretch (the `.practiceMode(.imConversation)` modality switch,
    /// or the other pressure mode when IM is itself the replaced candidate) rather
    /// than handing back a mode the ledger says is stalled. Every branch still
    /// returns a stretch action — the tie-breaker only redirects WHICH one — so the
    /// function stays total. An empty/below-floor ledger makes every check `false`,
    /// leaving today's branches byte-for-byte unchanged.
    private static func stretchChallenge(input: NextActionInput) -> ActionRecommendation? {
        let imSwitch: ActionRecommendation = .practiceMode(.imConversation, reason: "Try a conversation rep to test a different communication demand.")
        let fillerBurden = FillerBurden(
            fillerCount: input.fillerCount,
            duration: input.duration
        )

        // If they haven't tried sudden death much, suggest it
        let recentSuddenDeath = input.drillHistory.filter { $0.skillArea == .fillerReduction }.count
        if recentSuddenDeath < 3 && fillerBurden.isAtMost(.elevated) {
            if confidentReplace(forMode: .suddenDeath, input: input) {
                // Sudden death is the candidate but the ledger says replace it →
                // switch modality instead of repeating a not-moving pressure mode.
                return imSwitch
            }
            return .pressureExposure(.suddenDeath, reason: "Your recent filler read is controlled. A Pressure Drill can test it under more demand.")
        }

        // If the session was in timed mode, suggest IM mode
        if input.mode == .timed && input.score >= 7 {
            return .practiceMode(.imConversation, reason: "Your timed reps have read well. Try a conversation rep to test a different demand.")
        }

        // Otherwise suggest pressure mode
        if input.pressureLevel < .elevated {
            if confidentReplace(forMode: input.mode, input: input) {
                // The just-practiced mode is confidently replaced. Prefer the IM
                // modality switch; if IM is itself the replaced mode, bias to the
                // other pressure mode so we never re-offer the stalled one.
                if input.mode != .imConversation {
                    return imSwitch
                }
                let alt: PracticeMode = input.mode == .suddenDeath ? .timed : .suddenDeath
                return .pressureExposure(alt, reason: "Use pressure mode for the next rep to test how the skill holds.")
            }
            return .pressureExposure(input.mode, reason: "Use pressure mode for the next rep to test how the skill holds.")
        }

        return nil
    }
}
