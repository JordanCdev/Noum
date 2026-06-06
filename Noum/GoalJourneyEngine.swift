import Foundation

// MARK: - Goal Journey Engine
//
// Pure producer of THIS user's goal journey. Sibling of `CoachMemoryEngine`
// and `BaselineEngine` — no state, no @MainActor, fully unit-testable.
//
// Decides the ordered step set for the user's stated goal and CALIBRATES each
// step's threshold from the per-metric baseline so the bars fit where the user
// actually is. Steps come from curated per-goal TEMPLATES (never free-form
// generation) so the engine can never emit an incoherent step.
//
// Cold-start honesty: the user-facing copy is qualitative, and the calibrated
// number lives only in the criterion. When the backing stat is `.insufficient`
// the calibrated value falls back to the goal's target (a sane number), and the
// criterion self-suppresses to "forming" anyway — so no fabricated bar ever
// reaches the user.
//
// NOTE: `intervention` is accepted for forward-compatibility (a later phase will
// source a step's rationale from the active `CoachIntervention` so the journey
// renders the case the coach already maintains). v1 templates own their copy.

@available(iOS 17.0, macOS 12.0, *)
enum GoalJourneyEngine {

    // MARK: Build

    /// Build the ordered, calibrated journey for a goal. Always returns the full
    /// template so the user always sees their path; the overclaiming guard lives
    /// one level down (the criterion returns nil below the metric floor).
    static func build(
        goal: CoachingPriority,
        baseline: CommunicationBaseline,
        intervention: CoachIntervention? = nil,
        recentSessions: [PracticeSession] = [],
        now: Date = Date()
    ) -> [GoalStep] {
        switch goal {
        case .reduceFillers:  return reduceFillersSteps(baseline)
        case .moreConcise:    return moreConciseSteps(baseline)
        case .thinkFaster:    return thinkFasterSteps(baseline)
        case .calmerDelivery: return calmerDeliverySteps(baseline)
        }
    }

    // MARK: Evaluate

    /// Evaluate a built journey into ordered statuses. "current" = first
    /// incomplete (mirrors `PathProgressManager.currentNode`). A
    /// persisted-complete step is FORCED complete even if the live signal
    /// regressed — the no-relock invariant.
    static func evaluate(
        steps: [GoalStep],
        input: GoalStepInput,
        persistedComplete: Set<String>
    ) -> [GoalStepStatus] {
        var firstCurrentSet = false
        return steps.map { step in
            let persisted = persistedComplete.contains(step.id)
            let read = step.criterion.evaluate(input)        // may be nil (below floor)
            let liveComplete = read?.isComplete ?? false
            let isComplete = persisted || liveComplete
            let isCurrent = !isComplete && !firstCurrentSet
            if isCurrent { firstCurrentSet = true }
            return GoalStepStatus(
                step: step,
                progress: isComplete ? 1.0 : (read?.progress ?? 0),
                isComplete: isComplete,
                isCurrent: isCurrent,
                hasReadableProgress: persisted || read != nil
            )
        }
    }

    /// First incomplete step for the (goal, baseline, sessions) tuple — the
    /// chat-context + landscape read.
    static func firstIncompleteStep(
        goal: CoachingPriority,
        baseline: CommunicationBaseline,
        intervention: CoachIntervention? = nil,
        sessions: [PracticeSession],
        persistedComplete: Set<String>,
        now: Date = Date()
    ) -> GoalStepStatus? {
        let steps = build(goal: goal, baseline: baseline, intervention: intervention, recentSessions: sessions, now: now)
        let input = GoalStepInput(sessions: sessions, baseline: baseline, goal: goal, now: now)
        return evaluate(steps: steps, input: input, persistedComplete: persistedComplete)
            .first { !$0.isComplete }
    }

    // MARK: Coach-context lines (GOAL JOURNEY block)

    /// Lines for the GOAL JOURNEY context block: the single next step + why +
    /// (evidence-gated) progress + guidance. The progress line is OMITTED when
    /// `measuredDistanceFromGoal` is nil (no fabricated reading), and the
    /// percentage is `(1 - distance) * 100` because distance is 0=at-goal /
    /// 1=far.
    static func contextLines(
        for status: GoalStepStatus,
        goal: CoachingPriority,
        baseline: CommunicationBaseline
    ) -> [String] {
        var lines: [String] = []
        lines.append("- Next step: \(status.step.title) — \(status.step.coachRationale)")
        if let distance = baseline.measuredDistanceFromGoal(goal) {
            let pct = max(0, min(100, Int((1 - distance) * 100)))
            lines.append("- Target: \(status.step.successCriterionSummary) Progress: \(pct)% toward your goal.")
        }
        lines.append("- Name only this next step; the rest of the journey stays out of view until earned. Steps never relock.")
        return lines
    }

    // MARK: - Calibration helpers

    /// Filler/min bar: step down toward ≤1/min; mid bar = max(1.0, B*0.6).
    private static func fillerMidBar(_ baseline: CommunicationBaseline) -> Double {
        max(1.0, baseline.fillerRate.value * 0.6)
    }
    /// Length bar: step down toward ≤45s; mid bar = max(45, B*0.8).
    private static func concisionMidBar(_ baseline: CommunicationBaseline) -> Double {
        max(45, baseline.durationTendency.value * 0.8)
    }
    /// "Beat your average" bar on the 1–10 score scale: ceil(B + 0.5), clamped.
    private static func beatAverageScore(_ baseline: CommunicationBaseline) -> Int {
        min(10, max(1, Int(ceil(baseline.averageScore.value + 0.5))))
    }
    /// Filled-pause ratio bar: step down toward ≤0.2; mid bar = max(0.2, B*0.6).
    private static func calmMidBar(_ baseline: CommunicationBaseline) -> Double {
        max(0.2, baseline.pauseFilledRatio.value * 0.6)
    }

    // MARK: - Templates

    private static func make(
        _ goal: CoachingPriority, _ order: Int, _ idSuffix: String,
        title: String, target: String, why: String, success: String,
        symbol: String, dest: AppDestination, action: String,
        criterion: GoalStepCriterion
    ) -> GoalStep {
        GoalStep(
            id: "\(goal.rawValue).\(idSuffix)", order: order, goal: goal,
            title: title, observableTarget: target, coachRationale: why,
            successCriterionSummary: success, actionLabel: action,
            actionDestination: dest, symbolName: symbol, criterion: criterion
        )
    }

    private static func reduceFillersSteps(_ b: CommunicationBaseline) -> [GoalStep] {
        let g = CoachingPriority.reduceFillers
        let bar = fillerMidBar(b)
        return [
            make(g, 0, "finish_rep", title: "Finish a rep",
                 target: "Complete one practice rep.", why: "Every journey starts with one rep on the board.",
                 success: "One rep recorded.", symbol: "play.circle", dest: .practiceSelection, action: "Start a rep",
                 criterion: .completeReps(count: 1)),
            make(g, 1, "read_baseline", title: "Read your filler baseline",
                 target: "Practise enough for a reliable filler read.", why: "A few reps in and I can tell you where your fillers actually sit.",
                 success: "Your filler baseline becomes readable.", symbol: "waveform", dest: .practiceSelection, action: "Practise",
                 criterion: .goalMetricReadable),
            make(g, 2, "clean_once", title: "One clean rep",
                 target: "Land a rep with no filler words.", why: "Proof you can do it once — then we make it repeatable.",
                 success: "A qualifying rep with zero fillers.", symbol: "checkmark.circle", dest: .practiceSelection, action: "Practise",
                 criterion: .fillerRatePerRepAtMost(maxPerMinute: 0)),
            make(g, 3, "hold_bar", title: "Hold under your bar",
                 target: "Keep a rep below your usual filler rate.", why: "Not perfect every time — just better than your baseline, on demand.",
                 success: "A qualifying rep under your calibrated filler rate.", symbol: "gauge.with.dots.needle.33percent", dest: .practiceSelection, action: "Practise",
                 criterion: .fillerRatePerRepAtMost(maxPerMinute: bar)),
            make(g, 4, "three_clean", title: "Three clean reps in a week",
                 target: "Three low-filler reps within seven days.", why: "One good rep is luck; three in a week is a pattern.",
                 success: "Three qualifying reps under your bar in a rolling week.", symbol: "calendar", dest: .practiceSelection, action: "Practise",
                 criterion: .fillerRateCleanRunsInWindow(count: 3, maxPerMinute: bar)),
            make(g, 5, "under_pressure", title: "A clean rep under pressure",
                 target: "A zero-filler rep at elevated pressure.", why: "Fillers spike under pressure — clearing one there means it'll hold when it counts.",
                 success: "A zero-filler qualifying rep at elevated pressure.", symbol: "bolt.heart", dest: .suddenDeathPractice, action: "Try Sudden Death",
                 criterion: .cleanRepUnderPressure(minLevel: .elevated)),
            make(g, 6, "transfer", title: "Carry it into a conversation",
                 target: "Hold your intended delivery in a live conversation.", why: "The point was never clean reps — it's clean conversations.",
                 success: "Your committed tone holds across an IM conversation.", symbol: "bubble.left.and.bubble.right", dest: .imPractice(scenario: nil, tone: nil), action: "Open a conversation",
                 criterion: .imToneTransferCleared),
        ]
    }

    private static func moreConciseSteps(_ b: CommunicationBaseline) -> [GoalStep] {
        let g = CoachingPriority.moreConcise
        let sec = concisionMidBar(b)
        return [
            make(g, 0, "finish_rep", title: "Finish a rep",
                 target: "Complete one practice rep.", why: "Every journey starts with one rep on the board.",
                 success: "One rep recorded.", symbol: "play.circle", dest: .practiceSelection, action: "Start a rep",
                 criterion: .completeReps(count: 1)),
            make(g, 1, "read_baseline", title: "Read your length baseline",
                 target: "Practise enough for a reliable length read.", why: "A few reps in and I can see how long you tend to run.",
                 success: "Your length baseline becomes readable.", symbol: "ruler", dest: .practiceSelection, action: "Practise",
                 criterion: .goalMetricReadable),
            make(g, 2, "tight_once", title: "Land one tight rep",
                 target: "One rep under your usual length, still substantive.", why: "Short isn't the goal — tight-but-complete is.",
                 success: "A rep under your calibrated length with real content.", symbol: "scissors", dest: .practiceSelection, action: "Practise",
                 criterion: .conciseRepAtMost(maxSeconds: sec, minWords: 20)),
            make(g, 3, "two_tight", title: "Two tight reps in a row",
                 target: "Two consecutive reps that stay tight.", why: "Doing it twice in a row means it's a habit forming, not a fluke.",
                 success: "Two back-to-back reps under your length bar.", symbol: "arrow.right.to.line", dest: .practiceSelection, action: "Practise",
                 criterion: .consecutiveConciseReps(count: 2, maxSeconds: sec, minWords: 20)),
            make(g, 4, "tight_scored", title: "A tight rep that still scores",
                 target: "Stay tight without dropping quality.", why: "Cutting length shouldn't cost you the point — this proves it doesn't.",
                 success: "A rep under your length bar that still scores well.", symbol: "star.circle", dest: .practiceSelection, action: "Practise",
                 criterion: .conciseRepWithScore(maxSeconds: sec, minScore: 6)),
            make(g, 5, "under_pressure", title: "Stay tight under a hard clock",
                 target: "Hold your length at elevated pressure.", why: "Pressure makes people over-talk — staying tight there is the real win.",
                 success: "A tight rep at elevated pressure.", symbol: "bolt.heart", dest: .suddenDeathPractice, action: "Try Sudden Death",
                 criterion: .conciseRepUnderPressure(maxSeconds: sec, minLevel: .elevated, minWords: 20)),
            make(g, 6, "transfer", title: "Carry it into a conversation",
                 target: "Keep it tight in a live conversation.", why: "The payoff is conversations that don't ramble.",
                 success: "Your committed tone holds across an IM conversation.", symbol: "bubble.left.and.bubble.right", dest: .imPractice(scenario: nil, tone: nil), action: "Open a conversation",
                 criterion: .imToneTransferCleared),
        ]
    }

    private static func thinkFasterSteps(_ b: CommunicationBaseline) -> [GoalStep] {
        let g = CoachingPriority.thinkFaster
        let beat = beatAverageScore(b)
        return [
            make(g, 0, "finish_rep", title: "Finish a rep",
                 target: "Complete one practice rep.", why: "Every journey starts with one rep on the board.",
                 success: "One rep recorded.", symbol: "play.circle", dest: .practiceSelection, action: "Start a rep",
                 criterion: .completeReps(count: 1)),
            make(g, 1, "unscripted", title: "Try an unscripted rep",
                 target: "Run one Sudden Death rep.", why: "On-the-spot speaking is a muscle — Sudden Death is where it grows.",
                 success: "One Sudden Death rep recorded.", symbol: "bolt", dest: .suddenDeathPractice, action: "Try Sudden Death",
                 criterion: .modeReps(mode: .suddenDeath, count: 1)),
            make(g, 2, "read_baseline", title: "Read your on-the-spot baseline",
                 target: "Practise enough for a reliable quality read.", why: "A few reps in and I can see how well you do when you can't prepare.",
                 success: "Your answer-quality baseline becomes readable.", symbol: "brain", dest: .suddenDeathPractice, action: "Practise",
                 criterion: .goalMetricReadable),
            make(g, 3, "score_six", title: "Score 6 on a rep",
                 target: "Land a solid answer under time.", why: "A clear 6 means the thought landed — not just words filling the clock.",
                 success: "A rep scoring 6 or better.", symbol: "6.circle", dest: .practiceSelection, action: "Practise",
                 criterion: .scoreAtLeastOnce(min: 6)),
            make(g, 4, "beat_avg", title: "Beat your own average",
                 target: "Score above your usual.", why: "Improvement is personal — clearing your own average is the honest win.",
                 success: "A rep scoring above your calibrated average.", symbol: "chart.line.uptrend.xyaxis", dest: .practiceSelection, action: "Practise",
                 criterion: .scoreAtLeastOnce(min: beat)),
            make(g, 5, "hold_warmup", title: "Hold past the warm-up",
                 target: "Stay in a Sudden Death rep past the early rounds.", why: "The first answers are easy — composure shows up a few rounds in.",
                 success: "Survive into the later rounds of a Sudden Death rep.", symbol: "bolt.heart", dest: .suddenDeathPractice, action: "Try Sudden Death",
                 criterion: .pressureSurvived(rounds: 3)),
            make(g, 6, "transfer", title: "Respond smoothly in a conversation",
                 target: "Hold your delivery in a live, unscripted exchange.", why: "Thinking fast is for real conversations — this is where it counts.",
                 success: "Your committed tone holds across an IM conversation.", symbol: "bubble.left.and.bubble.right", dest: .imPractice(scenario: nil, tone: nil), action: "Open a conversation",
                 criterion: .imToneTransferCleared),
        ]
    }

    private static func calmerDeliverySteps(_ b: CommunicationBaseline) -> [GoalStep] {
        let g = CoachingPriority.calmerDelivery
        let ratio = calmMidBar(b)
        return [
            make(g, 0, "finish_rep", title: "Finish a rep",
                 target: "Complete one practice rep.", why: "Every journey starts with one rep on the board.",
                 success: "One rep recorded.", symbol: "play.circle", dest: .practiceSelection, action: "Start a rep",
                 criterion: .completeReps(count: 1)),
            make(g, 1, "read_baseline", title: "Read your composure baseline",
                 target: "Practise enough for a reliable pause read.", why: "Composure shows up in your pauses — a few reps and I can read them.",
                 success: "Your composure baseline becomes readable.", symbol: "wind", dest: .practiceSelection, action: "Practise",
                 criterion: .goalMetricReadable),
            make(g, 2, "silent_beat", title: "Hold one silent beat",
                 target: "Hold a real, quiet pause mid-rep.", why: "A held silence reads as control — the opposite of rushing.",
                 success: "One unfilled pause of about a second and a half.", symbol: "pause.circle", dest: .practiceSelection, action: "Practise",
                 criterion: .heldSilentPauseOnce(seconds: 1.5)),
            make(g, 3, "cut_filled", title: "Cut filled pauses below your bar",
                 target: "Keep your pauses mostly silent in a rep.", why: "Filled pauses ('um', 'uh') leak nerves — silent ones project calm.",
                 success: "A rep with pauses kept under your calibrated filled-ratio.", symbol: "speaker.slash", dest: .practiceSelection, action: "Practise",
                 criterion: .composedPausesOnce(maxFilledRatio: ratio, minPauses: 2)),
            make(g, 4, "composed_rep", title: "A composed-pause rep",
                 target: "Several clean pauses in one rep.", why: "Real composure is repeatable across a whole rep, not one lucky beat.",
                 success: "A rep with three-plus pauses, mostly silent.", symbol: "leaf", dest: .practiceSelection, action: "Practise",
                 criterion: .composedPausesOnce(maxFilledRatio: 0.25, minPauses: 3)),
            make(g, 5, "under_pressure", title: "Stay composed under a hard clock",
                 target: "Keep your pauses clean at elevated pressure.", why: "Anyone's calm in practice — holding it under pressure is the skill.",
                 success: "A composed-pause rep at elevated pressure.", symbol: "bolt.heart", dest: .suddenDeathPractice, action: "Try Sudden Death",
                 criterion: .composedPausesUnderPressure(maxFilledRatio: 0.25, minPauses: 3, minLevel: .elevated)),
            make(g, 6, "transfer", title: "Stay composed in a conversation",
                 target: "Hold a calm delivery in a live conversation.", why: "The goal is composure when it's real — not just when it's safe.",
                 success: "Your committed tone holds across an IM conversation.", symbol: "bubble.left.and.bubble.right", dest: .imPractice(scenario: nil, tone: nil), action: "Open a conversation",
                 criterion: .imToneTransferCleared),
        ]
    }
}
