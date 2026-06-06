import Testing
import Foundation
@testable import Noum

// MARK: - Fixtures

private func readableBaseline(
    filler: Double? = nil,
    durationSec: Double? = nil,
    score: Double? = nil,
    calmRatio: Double? = nil
) -> CommunicationBaseline {
    var b = CommunicationBaseline.empty
    func stat(_ v: Double) -> BaselineStat {
        BaselineStat(value: v, sampleCount: 12, confidence: .established, trend: .stable, percentile25: v, percentile75: v)
    }
    if let filler { b.fillerRate = stat(filler) }
    if let durationSec { b.durationTendency = stat(durationSec) }
    if let score { b.averageScore = stat(score) }
    if let calmRatio { b.pauseFilledRatio = stat(calmRatio) }
    return b
}

private func session(
    secondsAgo: Double = 0,
    fillers: Int = 0,
    duration: Double = 60,
    words: Int = 30,
    mode: PracticeMode = .timed,
    score: Int? = nil,
    pressure: PressureLevel = .standard,
    pauses: PauseMetrics? = nil
) -> PracticeSession {
    let transcript = Array(repeating: "word", count: max(words, 0)).joined(separator: " ")
    var s = PracticeSession(
        transcript: transcript,
        fillerWordCount: fillers,
        duration: duration,
        date: Date(timeIntervalSince1970: 2_000_000 - secondsAgo),
        mode: mode,
        score: score
    )
    s.pressureLevel = pressure
    s.pauseMetrics = pauses
    return s
}

// MARK: - GoalStepCriterion

@Suite struct GoalStepCriterionTests {

    private func input(_ sessions: [PracticeSession], _ baseline: CommunicationBaseline, goal: CoachingPriority = .reduceFillers) -> GoalStepInput {
        GoalStepInput(sessions: sessions, baseline: baseline, goal: goal, now: Date(timeIntervalSince1970: 2_000_000))
    }

    @Test func completeRepsAlwaysReadableAndFractional() {
        let crit = GoalStepCriterion.completeReps(count: 2)
        #expect(crit.evaluate(input([], .empty))?.isComplete == false)
        #expect(crit.evaluate(input([session()], .empty))?.progress == 0.5)
        #expect(crit.evaluate(input([session(), session()], .empty))?.isComplete == true)
    }

    @Test func goalMetricReadableTracksBackingStat() {
        let crit = GoalStepCriterion.goalMetricReadable
        #expect(crit.evaluate(input([], .empty, goal: .reduceFillers))?.isComplete == false)
        #expect(crit.evaluate(input([], readableBaseline(filler: 3), goal: .reduceFillers))?.isComplete == true)
        // honors the goal's own backing metric, not a different one
        #expect(crit.evaluate(input([], readableBaseline(score: 7), goal: .reduceFillers))?.isComplete == false)
    }

    @Test func metricStepsSelfSuppressBelowFloor() {
        // PER-METRIC floor: a filler step reads nil on a cold baseline even with
        // a perfect rep present — never a fabricated 0% bar. (FIX, engine verdict.)
        let perfect = session(fillers: 0, duration: 60, words: 30)
        #expect(GoalStepCriterion.fillerRatePerRepAtMost(maxPerMinute: 1).evaluate(input([perfect], .empty)) == nil)
        // crosses the floor → real read
        let r = GoalStepCriterion.fillerRatePerRepAtMost(maxPerMinute: 1).evaluate(input([perfect], readableBaseline(filler: 3)))
        #expect(r?.isComplete == true)
    }

    @Test func fillerQualifyingFloorRejectsThrowawayReps() {
        let base = readableBaseline(filler: 3)
        // 0 fillers but too few words → not qualifying → not complete
        let tooShort = session(fillers: 0, duration: 60, words: 5)
        #expect(GoalStepCriterion.fillerRatePerRepAtMost(maxPerMinute: 0).evaluate(input([tooShort], base))?.isComplete == false)
        // 0 fillers, qualifying → complete
        let real = session(fillers: 0, duration: 60, words: 30)
        #expect(GoalStepCriterion.fillerRatePerRepAtMost(maxPerMinute: 0).evaluate(input([real], base))?.isComplete == true)
    }

    @Test func cleanRepUnderPressureNeedsElevated() {
        let base = readableBaseline(filler: 3)
        let standard = session(fillers: 0, duration: 60, words: 30, pressure: .standard)
        let elevated = session(fillers: 0, duration: 60, words: 30, pressure: .elevated)
        #expect(GoalStepCriterion.cleanRepUnderPressure(minLevel: .elevated).evaluate(input([standard], base))?.isComplete == false)
        #expect(GoalStepCriterion.cleanRepUnderPressure(minLevel: .elevated).evaluate(input([elevated], base))?.isComplete == true)
    }

    @Test func scoreAtLeastOnceGatedAndOnTenScale() {
        let crit = GoalStepCriterion.scoreAtLeastOnce(min: 6)
        #expect(crit.evaluate(input([session(score: 8)], .empty, goal: .thinkFaster)) == nil) // floor
        let base = readableBaseline(score: 5)
        #expect(crit.evaluate(input([session(score: 5)], base, goal: .thinkFaster))?.isComplete == false)
        #expect(crit.evaluate(input([session(score: 6)], base, goal: .thinkFaster))?.isComplete == true)
    }

    @Test func composedPausesGatedOnCalm() {
        let crit = GoalStepCriterion.composedPausesOnce(maxFilledRatio: 0.25, minPauses: 2)
        let calmRep = session(pauses: PauseMetrics(count: 3, meanSeconds: 1, longestSeconds: 2, filledRatio: 0.1))
        #expect(crit.evaluate(input([calmRep], .empty, goal: .calmerDelivery)) == nil) // floor
        let base = readableBaseline(calmRatio: 0.4)
        #expect(crit.evaluate(input([calmRep], base, goal: .calmerDelivery))?.isComplete == true)
        let jitteryRep = session(pauses: PauseMetrics(count: 3, meanSeconds: 1, longestSeconds: 2, filledRatio: 0.5))
        #expect(crit.evaluate(input([jitteryRep], base, goal: .calmerDelivery))?.isComplete == false)
    }

    @Test func heldSilentPauseNeedsUnfilled() {
        let base = readableBaseline(calmRatio: 0.4)
        let crit = GoalStepCriterion.heldSilentPauseOnce(seconds: 1.5)
        let silent = session(pauses: PauseMetrics(count: 1, meanSeconds: 2, longestSeconds: 2, filledRatio: 0))
        #expect(crit.evaluate(input([silent], base, goal: .calmerDelivery))?.isComplete == true)
        let filled = session(pauses: PauseMetrics(count: 1, meanSeconds: 2, longestSeconds: 2, filledRatio: 0.3))
        #expect(crit.evaluate(input([filled], base, goal: .calmerDelivery))?.isComplete == false)
    }

    @Test func imToneTransferFormsOnThinEvidence() {
        // Invariant-3 guard: never fires from zero/thin IM evidence.
        let crit = GoalStepCriterion.imToneTransferCleared
        #expect(crit.evaluate(input([], .empty)) == nil)               // no sessions
        #expect(crit.evaluate(input([session(mode: .timed)], .empty)) == nil) // no IM evidence
    }

    @Test func pressureSurvivedAlwaysReadable() {
        let crit = GoalStepCriterion.pressureSurvived(rounds: 3) // needs ≥36s
        #expect(crit.evaluate(input([], .empty)) != nil) // always readable
        let long = session(duration: 40, mode: .suddenDeath, pressure: .elevated)
        #expect(crit.evaluate(input([long], .empty))?.isComplete == true)
        let short = session(duration: 30, mode: .suddenDeath, pressure: .elevated)
        #expect(crit.evaluate(input([short], .empty))?.isComplete == false)
    }
}

// MARK: - GoalJourneyEngine

@Suite struct GoalJourneyEngineTests {

    @Test func buildReturnsSevenOrderedNamespacedStepsPerGoal() {
        for goal in CoachingPriority.allCases {
            let steps = GoalJourneyEngine.build(goal: goal, baseline: .empty)
            #expect(steps.count == 7)
            #expect(steps.map(\.order) == Array(0..<7))
            #expect(steps.allSatisfy { $0.id.hasPrefix(goal.rawValue + ".") })
            #expect(steps.allSatisfy { $0.goal == goal })
        }
    }

    @Test func coldStartLeavesMetricStepsForming() {
        let steps = GoalJourneyEngine.build(goal: .reduceFillers, baseline: .empty)
        let input = GoalStepInput(sessions: [], baseline: .empty, goal: .reduceFillers, now: Date(timeIntervalSince1970: 2_000_000))
        let statuses = GoalJourneyEngine.evaluate(steps: steps, input: input, persistedComplete: [])
        // The "read your baseline" floor step is readable (count/floor probe).
        let floorStep = statuses.first { $0.step.id == "reduceFillers.read_baseline" }
        #expect(floorStep?.hasReadableProgress == true)
        // A calibrated metric step self-suppresses to "forming".
        let metricStep = statuses.first { $0.step.id == "reduceFillers.hold_bar" }
        #expect(metricStep?.hasReadableProgress == false)
        #expect(metricStep?.progress == 0)
    }

    @Test func calibrationStepsDownFromBaseline() {
        // B=6 → hold-bar = max(1, 6*0.6) = 3.6/min.
        let base = readableBaseline(filler: 6)
        let steps = GoalJourneyEngine.build(goal: .reduceFillers, baseline: base)
        let holdBar = steps.first { $0.id == "reduceFillers.hold_bar" }!
        func inputWith(fillersPerMin: Int) -> GoalStepInput {
            // duration 60s → fillerWordCount == fillers/min
            GoalStepInput(sessions: [session(fillers: fillersPerMin, duration: 60, words: 30)], baseline: base, goal: .reduceFillers, now: Date(timeIntervalSince1970: 2_000_000))
        }
        #expect(holdBar.criterion.evaluate(inputWith(fillersPerMin: 3))?.isComplete == true)   // 3.0 ≤ 3.6
        #expect(holdBar.criterion.evaluate(inputWith(fillersPerMin: 4))?.isComplete == false)  // 4.0 > 3.6
    }

    @Test func noRelockForcesPersistedComplete() {
        let steps = GoalJourneyEngine.build(goal: .reduceFillers, baseline: .empty)
        let input = GoalStepInput(sessions: [], baseline: .empty, goal: .reduceFillers, now: Date(timeIntervalSince1970: 2_000_000))
        // "clean_once" is NOT live-complete on empty input, but persist it:
        let persisted: Set<String> = ["reduceFillers.clean_once"]
        let statuses = GoalJourneyEngine.evaluate(steps: steps, input: input, persistedComplete: persisted)
        let forced = statuses.first { $0.step.id == "reduceFillers.clean_once" }
        #expect(forced?.isComplete == true)
        #expect(forced?.progress == 1.0)
    }

    @Test func firstIncompleteIsTheCurrentStep() {
        // One rep completes "finish_rep" (order 0); next incomplete is order 1.
        let base = CommunicationBaseline.empty
        let status = GoalJourneyEngine.firstIncompleteStep(
            goal: .reduceFillers, baseline: base, sessions: [session()],
            persistedComplete: [], now: Date(timeIntervalSince1970: 2_000_000)
        )
        #expect(status?.step.order == 1)
        #expect(status?.isCurrent == true)
    }

    @Test func goalNamespacesIsolateCompletions() {
        // A reduceFillers completion never marks a moreConcise step complete.
        let steps = GoalJourneyEngine.build(goal: .moreConcise, baseline: .empty)
        let input = GoalStepInput(sessions: [], baseline: .empty, goal: .moreConcise, now: Date(timeIntervalSince1970: 2_000_000))
        let statuses = GoalJourneyEngine.evaluate(steps: steps, input: input, persistedComplete: ["reduceFillers.clean_once", "reduceFillers.finish_rep"])
        #expect(statuses.allSatisfy { !$0.isComplete })
    }
}

// MARK: - GoalJourney context lines

@Suite struct GoalJourneyContextTests {

    private func currentStatus(_ goal: CoachingPriority, _ baseline: CommunicationBaseline) -> GoalStepStatus {
        let steps = GoalJourneyEngine.build(goal: goal, baseline: baseline)
        let input = GoalStepInput(sessions: [], baseline: baseline, goal: goal, now: Date(timeIntervalSince1970: 2_000_000))
        return GoalJourneyEngine.evaluate(steps: steps, input: input, persistedComplete: []).first!
    }

    @Test func progressLineOmittedWhenUnmeasured() {
        let status = currentStatus(.reduceFillers, .empty)
        let lines = GoalJourneyEngine.contextLines(for: status, goal: .reduceFillers, baseline: .empty)
        #expect(lines.count == 2) // next-step + guidance, NO progress line
        #expect(!lines.joined().contains("Progress:"))
    }

    @Test func progressPercentIsNotInverted() {
        // At-goal user (low filler rate) reads HIGH percent, not low.
        let atGoal = readableBaseline(filler: 0.5)      // distance ≈ 0.06 → ~93%
        let s1 = currentStatus(.reduceFillers, atGoal)
        let near = GoalJourneyEngine.contextLines(for: s1, goal: .reduceFillers, baseline: atGoal).joined(separator: "\n")
        #expect(near.contains("Progress:"))
        #expect(near.contains("93%"))                   // (1 - 0.0625) * 100 = 93, NOT 6
        // Far user reads 0%, not 100%.
        let farOff = readableBaseline(filler: 8)         // distance 1.0 → 0%
        let s2 = currentStatus(.reduceFillers, farOff)
        let far = GoalJourneyEngine.contextLines(for: s2, goal: .reduceFillers, baseline: farOff).joined(separator: "\n")
        #expect(far.contains("Progress: 0% toward your goal."))
    }

    @Test func nextStepLineNamesTheStep() {
        let status = currentStatus(.calmerDelivery, .empty)
        let lines = GoalJourneyEngine.contextLines(for: status, goal: .calmerDelivery, baseline: .empty)
        #expect(lines.first?.contains(status.step.title) == true)
        #expect(lines.first?.hasPrefix("- Next step:") == true)
    }
}
