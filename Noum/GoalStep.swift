import Foundation

// MARK: - Goal Step model
//
// One concrete step on the user's path to THEIR stated goal
// (`CoachingProfile.primaryGoal`). Mirrors `PathNode` (PathNode.swift:11) but
// is engine-produced PER USER: the criterion's numeric thresholds are
// calibrated off the user's per-metric baseline by `GoalJourneyEngine`, not
// authored as global constants.
//
// Honesty contracts (enforced here + in the engine):
// - The user-facing copy (`title` / `observableTarget`) is QUALITATIVE — it
//   never embeds a calibrated number, so a cold-start user (no baseline yet)
//   never reads a fabricated bar like "under 0.0/min". The number lives only
//   in the `criterion` (completion math) and the progress line (which
//   self-suppresses below the evidence floor — see `GoalJourneyEngine`).
// - Like `PathNode`, once a step is complete it NEVER relocks. Persistence of
//   completed IDs lives in `GoalJourneyStore`, keyed per account.

@available(iOS 17.0, macOS 12.0, *)
struct GoalStep: Identifiable, Equatable {
    /// Stable, goal-namespaced id, e.g. "reduceFillers.clean_once". Namespacing
    /// by goal means switching `primaryGoal` swaps the whole step set without id
    /// collisions in the persisted completed-set.
    let id: String
    let order: Int
    /// Which goal this step belongs to — lets the store ignore completed IDs
    /// from a previously-active goal when building the current journey.
    let goal: CoachingPriority

    /// Short on-voice title — what this step is.
    let title: String
    /// One-sentence observable target the user reads (qualitative — no number).
    let observableTarget: String
    /// One-line coach-voice rationale — why this step matters.
    let coachRationale: String
    /// Human-readable success-criterion summary (the "what done looks like").
    let successCriterionSummary: String

    /// CTA copy for the action button.
    let actionLabel: String
    /// Where one-tap CTA pushes. Reuses the existing `AppDestination` enum.
    let actionDestination: AppDestination
    /// SF Symbol for the step (brand rule: symbol only, never illustration).
    let symbolName: String

    /// Calibrated, pure progress evaluator.
    let criterion: GoalStepCriterion

    static func == (lhs: GoalStep, rhs: GoalStep) -> Bool { lhs.id == rhs.id }
}

// MARK: - Goal metric

/// Which baseline stat backs a goal. Used for the per-metric evidence floor and
/// the "read your baseline" step.
enum GoalMetric {
    case filler, duration, score, calm
}

extension CoachingPriority {
    /// The single `BaselineStat` that measures progress toward this goal.
    var backingMetric: GoalMetric {
        switch self {
        case .reduceFillers:   return .filler
        case .moreConcise:     return .duration
        case .thinkFaster:     return .score
        case .calmerDelivery:  return .calm
        }
    }
}

// MARK: - Goal Step input
//
// Snapshot of every signal a criterion can read, built once per pass (mirrors
// `PathProgressInput`, PathNode.swift:35). The PER-METRIC readability flags are
// the honest evidence floor — each gates on its OWN backing `BaselineStat`
// confidence (the same per-dimension gate `measuredDistanceFromGoal` uses),
// NOT an aggregate session count, so e.g. a calm reading is never fabricated
// for a terse speaker whose reps carry no pauses.

@available(iOS 17.0, macOS 12.0, *)
struct GoalStepInput {
    /// Newest-first (store convention: `sessions[0]` is the most recent rep).
    let sessions: [PracticeSession]
    let baseline: CommunicationBaseline
    let goal: CoachingPriority
    let now: Date

    init(
        sessions: [PracticeSession],
        baseline: CommunicationBaseline,
        goal: CoachingPriority,
        now: Date = Date()
    ) {
        self.sessions = sessions
        self.baseline = baseline
        self.goal = goal
        self.now = now
    }

    var fillerReadable: Bool   { baseline.fillerRate.confidence != .insufficient }
    var durationReadable: Bool { baseline.durationTendency.confidence != .insufficient }
    var scoreReadable: Bool    { baseline.averageScore.confidence != .insufficient }
    var calmReadable: Bool     { baseline.pauseFilledRatio.confidence != .insufficient }

    func readable(_ metric: GoalMetric) -> Bool {
        switch metric {
        case .filler:   return fillerReadable
        case .duration: return durationReadable
        case .score:    return scoreReadable
        case .calm:     return calmReadable
        }
    }

    var sessionsLast7Days: [PracticeSession] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: now) ?? now
        return sessions.filter { $0.date >= cutoff }
    }

    /// A rep that clears the same floor `SessionQualifier` uses for baseline
    /// stats (≥15s, ≥20 words) — so a 3-word throwaway can't trivially clear a
    /// filler/concision step.
    func isQualifying(_ s: PracticeSession) -> Bool {
        s.duration >= SessionQualifier.minimumDuration
            && s.wordCount >= SessionQualifier.minimumWordCount
    }

    /// Fillers per minute — the exact formula `BaselineEngine` uses.
    static func fillersPerMinute(_ s: PracticeSession) -> Double {
        guard s.duration > 0 else { return 0 }
        return Double(s.fillerWordCount) / (s.duration / 60.0)
    }
}

// MARK: - Goal Step criterion
//
// Pure, calibrated progress evaluator over `GoalStepInput`. Unlike
// `PathNodeCriterion` (PathNode.swift:68) whose cases hold app-authored
// constants, a `GoalStepCriterion`'s numeric thresholds are baked in by
// `GoalJourneyEngine` from THIS user's per-metric baseline.
//
// HARD INVARIANT (no overclaiming): `evaluate` returns `nil` when the backing
// metric is below its evidence floor (per-metric `.insufficient`) — the engine
// renders the step as "forming", never a fabricated 0% bar. The count-based
// cases (`completeReps`, `modeReps`, `pressureSurvived`) and the floor-probe
// (`goalMetricReadable`) are always readable.

@available(iOS 17.0, macOS 12.0, *)
enum GoalStepCriterion: Equatable {
    /// Complete `count` reps at all. Always readable.
    case completeReps(count: Int)
    /// `count` reps in a given mode. Always readable.
    case modeReps(mode: PracticeMode, count: Int)
    /// Completes when the goal's backing stat crosses `.insufficient` — the
    /// honesty floor made VISIBLE as its own step ("read your baseline").
    case goalMetricReadable

    /// One qualifying rep at ≤ `maxPerMinute` fillers. Gated on `fillerReadable`.
    case fillerRatePerRepAtMost(maxPerMinute: Double)
    /// `count` qualifying reps within a rolling 7 days, each ≤ `maxPerMinute`.
    case fillerRateCleanRunsInWindow(count: Int, maxPerMinute: Double)
    /// One zero-filler qualifying rep at ≥ `minLevel` pressure. Gated on filler.
    case cleanRepUnderPressure(minLevel: PressureLevel)

    /// One rep ≤ `maxSeconds` AND ≥ `minWords` (tight but substantive).
    case conciseRepAtMost(maxSeconds: Double, minWords: Int)
    /// `count` consecutive (by date) reps each ≤ `maxSeconds` & ≥ `minWords`.
    case consecutiveConciseReps(count: Int, maxSeconds: Double, minWords: Int)
    /// One rep ≤ `maxSeconds` that still scores ≥ `minScore`.
    case conciseRepWithScore(maxSeconds: Double, minScore: Int)
    /// One rep ≤ `maxSeconds` at ≥ `minLevel` pressure, ≥ `minWords`.
    case conciseRepUnderPressure(maxSeconds: Double, minLevel: PressureLevel, minWords: Int)

    /// One rep scoring ≥ `min` (1–10 session scale). Gated on `scoreReadable`.
    case scoreAtLeastOnce(min: Int)

    /// One rep with ≥ `minPauses` and filled-ratio ≤ `maxFilledRatio`.
    case composedPausesOnce(maxFilledRatio: Double, minPauses: Int)
    /// `composedPausesOnce` at ≥ `minLevel` pressure.
    case composedPausesUnderPressure(maxFilledRatio: Double, minPauses: Int, minLevel: PressureLevel)
    /// One unfilled pause ≥ `seconds`. Gated on `calmReadable`.
    case heldSilentPauseOnce(seconds: Double)

    /// Survive into `rounds` of a Sudden-Death rep (duration heuristic, mirrors
    /// `PathNodeCriterion.pressureSurvived`). Always readable.
    case pressureSurvived(rounds: Int)

    /// Live-conversation transfer: at least one IM scenario with ≥3 evaluated
    /// reps (positive evidence gate) AND no scenario still sitting below the
    /// tone-drill bar. Returns nil (forming, NOT complete) on thin/zero IM
    /// evidence so it can never fire from nothing.
    case imToneTransferCleared

    /// Returns nil below the metric's evidence floor (self-suppress → forming);
    /// else `(progress 0...1, isComplete)`.
    func evaluate(_ input: GoalStepInput) -> (progress: Double, isComplete: Bool)? {
        switch self {
        case .completeReps(let count):
            return done(input.sessions.count, count)

        case .modeReps(let mode, let count):
            return done(input.sessions.filter { $0.mode == mode }.count, count)

        case .goalMetricReadable:
            let ready = input.readable(input.goal.backingMetric)
            return (progress: ready ? 1.0 : 0.0, isComplete: ready)

        case .fillerRatePerRepAtMost(let maxPM):
            guard input.fillerReadable else { return nil }
            return hit(input.sessions.contains {
                input.isQualifying($0) && GoalStepInput.fillersPerMinute($0) <= maxPM
            })

        case .fillerRateCleanRunsInWindow(let count, let maxPM):
            guard input.fillerReadable else { return nil }
            let n = input.sessionsLast7Days.filter {
                input.isQualifying($0) && GoalStepInput.fillersPerMinute($0) <= maxPM
            }.count
            return done(n, count)

        case .cleanRepUnderPressure(let minLevel):
            guard input.fillerReadable else { return nil }
            return hit(input.sessions.contains {
                input.isQualifying($0) && $0.fillerWordCount == 0 && $0.pressureLevel >= minLevel
            })

        case .conciseRepAtMost(let maxSeconds, let minWords):
            guard input.durationReadable else { return nil }
            return hit(input.sessions.contains { $0.duration <= maxSeconds && $0.wordCount >= minWords })

        case .consecutiveConciseReps(let count, let maxSeconds, let minWords):
            guard input.durationReadable else { return nil }
            // Sessions are newest-first; walk chronologically for a real run.
            var run = 0
            var best = 0
            for s in input.sessions.reversed() {
                if s.duration <= maxSeconds && s.wordCount >= minWords {
                    run += 1
                    best = max(best, run)
                } else {
                    run = 0
                }
            }
            return done(best, count)

        case .conciseRepWithScore(let maxSeconds, let minScore):
            guard input.durationReadable else { return nil }
            return hit(input.sessions.contains { $0.duration <= maxSeconds && ($0.score ?? 0) >= minScore })

        case .conciseRepUnderPressure(let maxSeconds, let minLevel, let minWords):
            guard input.durationReadable else { return nil }
            return hit(input.sessions.contains {
                $0.duration <= maxSeconds && $0.pressureLevel >= minLevel && $0.wordCount >= minWords
            })

        case .scoreAtLeastOnce(let minScore):
            guard input.scoreReadable else { return nil }
            return done(input.sessions.compactMap(\.score).max() ?? 0, minScore)

        case .composedPausesOnce(let maxRatio, let minPauses):
            guard input.calmReadable else { return nil }
            return hit(input.sessions.contains { s in
                guard let m = s.pauseMetrics, m.count >= minPauses else { return false }
                return m.filledRatio <= maxRatio
            })

        case .composedPausesUnderPressure(let maxRatio, let minPauses, let minLevel):
            guard input.calmReadable else { return nil }
            return hit(input.sessions.contains { s in
                guard let m = s.pauseMetrics, m.count >= minPauses, s.pressureLevel >= minLevel else { return false }
                return m.filledRatio <= maxRatio
            })

        case .heldSilentPauseOnce(let seconds):
            guard input.calmReadable else { return nil }
            let best = input.sessions.compactMap { s -> Double? in
                guard let m = s.pauseMetrics, m.count > 0, m.filledRatio == 0 else { return nil }
                return m.longestSeconds
            }.max() ?? 0
            return (progress: seconds > 0 ? min(1.0, best / seconds) : 1.0, isComplete: best >= seconds)

        case .pressureSurvived(let rounds):
            return hit(input.sessions.contains {
                $0.mode == .suddenDeath
                    && $0.pressureLevel >= .elevated
                    && $0.duration >= Double(rounds) * 12
            })

        case .imToneTransferCleared:
            // Positive evidence gate FIRST: ≥1 scenario with ≥3 evaluated reps.
            let hasEvidence = IMConversationScenario.allCases.contains { scenario in
                IMHistorySummary.toneMatchStats(from: input.sessions, scenario: scenario)
                    .evaluatedCount >= IMHistorySummary.toneDrillMinEvaluatedReps
            }
            guard hasEvidence else { return nil }   // thin/zero IM evidence ⇒ forming
            let cleared = IMHistorySummary.toneDrillSignal(from: input.sessions) == nil
            return (progress: cleared ? 1.0 : 0.0, isComplete: cleared)
        }
    }

    /// Two-method parity with `PathNodeCriterion`. Treats nil (below floor) as
    /// 0 / false so the recompute loop reads cleanly.
    func progress(for input: GoalStepInput) -> Double { evaluate(input)?.progress ?? 0 }
    func isComplete(for input: GoalStepInput) -> Bool { evaluate(input)?.isComplete ?? false }

    // MARK: Helpers
    private func done(_ value: Int, _ target: Int) -> (progress: Double, isComplete: Bool) {
        guard target > 0 else { return (1.0, true) }
        return (progress: min(1.0, Double(value) / Double(target)), isComplete: value >= target)
    }
    private func hit(_ value: Bool) -> (progress: Double, isComplete: Bool) {
        (progress: value ? 1.0 : 0.0, isComplete: value)
    }
}

// MARK: - Goal Step status
//
// Render-friendly state for a single step (mirrors `PathNodeStatus`).

@available(iOS 17.0, macOS 12.0, *)
struct GoalStepStatus: Identifiable, Equatable {
    let step: GoalStep
    let progress: Double
    let isComplete: Bool
    let isCurrent: Bool
    /// false when the step is below its evidence floor (overclaiming guard) —
    /// the UI shows "forming", not a 0% bar implying a real read.
    let hasReadableProgress: Bool

    var id: String { step.id }
}
