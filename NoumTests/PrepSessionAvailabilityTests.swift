import Foundation
import Testing
@testable import Noum

@Suite("Prep session availability")
struct PrepSessionAvailabilityTests {
    private let moment = BigMoment(
        title: "Board pitch",
        category: .presentation
    )
    private let momentCreatedAt = Date(timeIntervalSince1970: 1_000)

    private func plan(
        _ availability: NextActionModeAvailability
    ) -> PrepSessionPlan {
        PrepSessionPlanner.plan(
            bigMoment: moment,
            daysRemaining: 5,
            modeAvailability: availability
        )
    }

    private func step(
        _ mode: PracticeMode,
        in plan: PrepSessionPlan
    ) -> PrepRepStep {
        guard let step = plan.steps.first(where: { $0.mode == mode }) else {
            Issue.record("Missing prep step for \(mode.rawValue)")
            return plan.steps[0]
        }
        return step
    }

    private func rep(_ mode: PracticeMode, minutesAfter: Int) -> PracticeSession {
        PracticeSession(
            transcript: "One complete rehearsal",
            fillerWordCount: 0,
            duration: 60,
            date: momentCreatedAt.addingTimeInterval(Double(minutesAfter) * 60),
            mode: mode
        )
    }

    private func statuses(
        _ plan: PrepSessionPlan,
        reps: [PracticeSession]
    ) -> [PrepStepStatus] {
        PrepSessionPlanner.stepStatuses(
            plan: plan,
            sessions: reps,
            momentCreatedAt: momentCreatedAt
        )
    }

    // MARK: - Rendered plan + availability fallbacks

    @Test func allAvailablePreservesEveryPlannedExerciseAndSetup() {
        let plan = plan(.allAvailable)

        #expect(plan.steps.map(\.mode) == [.timed, .suddenDeath, .imConversation])
        #expect(plan.steps.map(\.renderedMode) == [.timed, .suddenDeath, .imConversation])
        #expect(plan.steps.allSatisfy { !$0.isAvailabilityFallback })
        #expect(plan.steps.allSatisfy { $0.fallbackMarkerLine == nil })
        #expect(step(.timed, in: plan).renderedLaunch.destination == .timedPractice(difficulty: nil))
        #expect(step(.suddenDeath, in: plan).renderedLaunch.destination == .suddenDeathPractice)
        #expect(
            step(.imConversation, in: plan).renderedLaunch.destination
                == .imPractice(scenario: nil, tone: nil)
        )
        #expect(plan.imScenario?.persona == "Skeptical board member")
        #expect(plan.introductionCopy.contains("hold up under pressure"))
        #expect(plan.introductionCopy.contains("rehearse what you'll actually face"))
    }

    @Test func lockedPressureRendersAnHonestTimedFallbackWithStableShapeIdentity() {
        let plan = plan(NextActionModeAvailability(
            suddenDeathAvailable: false,
            imConversationAvailable: true
        ))
        let pressure = step(.suddenDeath, in: plan)

        #expect(pressure.mode == .suddenDeath)
        #expect(pressure.renderedMode == .timed)
        #expect(pressure.renderedLaunch.destination == .timedPractice(difficulty: nil))
        #expect(pressure.isAvailabilityFallback)
        #expect(pressure.displayLabel == "Build-up rep: Timed Practice")
        #expect(pressure.rationale == NextActionModeAvailability.suddenDeathFallbackReason)
        // The intro's arc must not promise the gated pressure round.
        #expect(!plan.introductionCopy.contains("hold up under pressure"))
        #expect(plan.introductionCopy.contains("build up in Timed Practice"))
        #expect(step(.imConversation, in: plan).renderedMode == .imConversation)
        #expect(plan.imScenario != nil)
    }

    @Test func unavailableConversationRendersTimedAndDropsConversationSetup() {
        let plan = plan(NextActionModeAvailability(
            suddenDeathAvailable: true,
            imConversationAvailable: false
        ))
        let audience = step(.imConversation, in: plan)

        #expect(audience.mode == .imConversation)
        #expect(audience.renderedMode == .timed)
        #expect(audience.renderedLaunch.destination == .timedPractice(difficulty: nil))
        #expect(audience.isAvailabilityFallback)
        #expect(audience.displayLabel == "Question rehearsal: Timed Practice")
        #expect(audience.rationale == NextActionModeAvailability.imConversationFallbackReason)
        #expect(plan.imScenario == nil)
        // The intro's arc must not promise the unavailable audience round.
        #expect(!plan.introductionCopy.contains("rehearse what you'll actually face"))
        #expect(plan.introductionCopy.contains("rehearse a likely question in Timed Practice"))
    }

    @Test func timedFallbackPromptsKeepTheVisibleRehearsalPromise() throws {
        let pressurePrompt = try #require(
            PrepSessionPlanner.timedFallbackPrompt(
                for: .suddenDeath,
                category: .presentation
            )
        )
        let audiencePrompt = try #require(
            PrepSessionPlanner.timedFallbackPrompt(
                for: .imConversation,
                category: .presentation
            )
        )

        #expect(pressurePrompt.contains("60-second opening"))
        #expect(pressurePrompt.contains("presentation"))
        #expect(audiencePrompt.contains("likely question"))
        #expect(audiencePrompt.contains("Walk me through the key risk"))
        #expect(pressurePrompt.count <= TimedPracticePromptHandoff.maximumPromptCharacters)
        #expect(audiencePrompt.count <= TimedPracticePromptHandoff.maximumPromptCharacters)
        #expect(PrepSessionPlanner.timedFallbackPrompt(
            for: .timed,
            category: .presentation
        ) == nil)
    }

    @Test func bothUnavailableKeepThreeStableShapesWithoutFalseReadinessCredit() {
        let plan = plan(.failClosed)

        #expect(plan.steps.map(\.mode) == [.timed, .suddenDeath, .imConversation])
        #expect(plan.steps.map(\.renderedMode) == [.timed, .timed, .timed])
        #expect(plan.steps.map(\.renderedLaunch.destination) == [
            .timedPractice(difficulty: nil),
            .timedPractice(difficulty: nil),
            .timedPractice(difficulty: nil),
        ])
        #expect(plan.imScenario == nil)
        #expect(plan.introductionCopy.contains("two focused Timed Practice passes"))

        // Readiness stays the honest shape-coverage read: one timed rep
        // covers the warm-up shape only, never a gated shape.
        let readiness = PrepSessionPlanner.readiness(
            plan: plan,
            sessions: [rep(.timed, minutesAfter: 1)],
            momentCreatedAt: momentCreatedAt
        )
        #expect(readiness.coveredModes == [.timed])
        #expect(readiness.coveredCount == 1)
        #expect(readiness.level == .underway)
        #expect(
            readiness.line
                == "You've covered 1 of 3 rehearsal steps. Next: pressure round and audience simulation."
        )
        #expect(
            step(.suddenDeath, in: plan).fallbackMarkerLine
                == "Pressure round unavailable — a Timed fallback is offered."
        )
        #expect(step(.timed, in: plan).fallbackMarkerLine == nil)
    }

    @Test func tapResolutionDefendsCapabilityLossAndNeverUpgradesRenderedFallback() {
        let availablePlan = plan(.allAvailable)
        let pressure = step(.suddenDeath, in: availablePlan)
        let acceptedPressure = pressure.resolvingLaunchForTap(
            modeAvailability: .allAvailable,
            imAvailable: true
        )
        #expect(acceptedPressure.destination == .suddenDeathPractice)
        #expect(acceptedPressure.acceptsDisplayedPrescription)

        let lostPressure = pressure.resolvingLaunchForTap(
            modeAvailability: .failClosed,
            imAvailable: true
        )
        #expect(lostPressure.displayedMode == .suddenDeath)
        #expect(lostPressure.launchedMode == .timed)
        #expect(lostPressure.destination == .timedPractice(difficulty: nil))
        #expect(!lostPressure.acceptsDisplayedPrescription)

        let conversation = step(.imConversation, in: availablePlan)
        let lostConversation = conversation.resolvingLaunchForTap(
            modeAvailability: NextActionModeAvailability(
                suddenDeathAvailable: true,
                imConversationAvailable: false
            ),
            imAvailable: false
        )
        #expect(lostConversation.displayedMode == .imConversation)
        #expect(lostConversation.launchedMode == .timed)
        #expect(!lostConversation.acceptsDisplayedPrescription)

        let renderedFallback = step(.suddenDeath, in: plan(.failClosed))
        let capabilityReturned = renderedFallback.resolvingLaunchForTap(
            modeAvailability: .allAvailable,
            imAvailable: true
        )
        #expect(capabilityReturned.displayedMode == .timed)
        #expect(capabilityReturned.launchedMode == .timed)
        #expect(capabilityReturned.destination == .timedPractice(difficulty: nil))
        #expect(capabilityReturned.acceptsDisplayedPrescription)
    }

    // MARK: - Step statuses (ordered attribution lock state)

    @Test func happySequentialPathUnlocksInOrder() {
        let plan = plan(.allAvailable)

        // No reps: the warm-up is current; everything else waits on it.
        var s = statuses(plan, reps: [])
        #expect(s.map(\.phase) == [.current, .locked, .locked])
        #expect(s[1].unlockLine == "Unlocks after the warm-up.")
        #expect(s[2].unlockLine == "Unlocks after the warm-up.")

        // Warm-up covered: the pressure round opens, audience waits on IT.
        s = statuses(plan, reps: [rep(.timed, minutesAfter: 1)])
        #expect(s.map(\.phase) == [.done, .current, .locked])
        #expect(!s[0].coveredViaFallback)
        #expect(s[2].unlockLine == "Unlocks after the pressure round.")

        // Pressure covered too: the audience round is the open step.
        s = statuses(plan, reps: [
            rep(.timed, minutesAfter: 1),
            rep(.suddenDeath, minutesAfter: 2),
        ])
        #expect(s.map(\.phase) == [.done, .done, .current])
    }

    @Test func outOfOrderCoverageNamesTheFirstUncoveredStep() {
        let plan = plan(.allAvailable)

        // An out-of-band Train pressure rep covers step 2 before step 1: the
        // locked last step must name the warm-up, not blindly index − 1.
        let s = statuses(plan, reps: [rep(.suddenDeath, minutesAfter: 1)])
        #expect(s.map(\.phase) == [.current, .done, .locked])
        #expect(!s[1].coveredViaFallback)
        #expect(s[2].unlockShapeName == "warm-up")
        #expect(s[2].unlockLine == "Unlocks after the warm-up.")
    }

    @Test func gatedStepCoveredViaFallbackUnlocksTheNextStep() {
        let plan = plan(NextActionModeAvailability(
            suddenDeathAvailable: false,
            imConversationAvailable: true
        ))

        // One timed rep credits the warm-up only; the gated step stays open
        // and the locked step names the fallback as a valid way through.
        var s = statuses(plan, reps: [rep(.timed, minutesAfter: 1)])
        #expect(s.map(\.phase) == [.done, .current, .locked])
        #expect(
            s[2].unlockLine
                == "Unlocks after the pressure round — its Timed fallback counts."
        )

        // A second timed rep is the offered fallback: the gated step
        // completes (honestly marked) and the audience round opens instead
        // of dead-ending forever.
        s = statuses(plan, reps: [
            rep(.timed, minutesAfter: 1),
            rep(.timed, minutesAfter: 2),
        ])
        #expect(s.map(\.phase) == [.done, .done, .current])
        #expect(!s[0].coveredViaFallback)
        #expect(s[1].coveredViaFallback)
        #expect(
            step(.suddenDeath, in: plan).coveredViaFallbackLine
                == "Covered with the Timed fallback — the pressure round itself is still untested."
        )

        // Readiness keeps the honest read: the fallback rep never claims the
        // pressure shape was rehearsed.
        let readiness = PrepSessionPlanner.readiness(
            plan: plan,
            sessions: [rep(.timed, minutesAfter: 1), rep(.timed, minutesAfter: 2)],
            momentCreatedAt: momentCreatedAt
        )
        #expect(readiness.coveredModes == [.timed])
    }

    @Test func plannedShapeRepIsPreferredOverAnEarlierFallbackRep() {
        let plan = plan(NextActionModeAvailability(
            suddenDeathAvailable: false,
            imConversationAvailable: true
        ))

        // A real pressure rep exists (e.g. logged before the gate moved):
        // it must credit the pressure step, never be mislabelled as
        // fallback coverage because an earlier timed rep also matched.
        let s = statuses(plan, reps: [
            rep(.timed, minutesAfter: 1),
            rep(.timed, minutesAfter: 2),
            rep(.suddenDeath, minutesAfter: 3),
        ])
        #expect(s.map(\.phase) == [.done, .done, .current])
        #expect(!s[1].coveredViaFallback)
    }

    @Test func allCoveredReadsThreeDoneSteps() {
        let plan = plan(.allAvailable)
        let s = statuses(plan, reps: [
            rep(.timed, minutesAfter: 1),
            rep(.suddenDeath, minutesAfter: 2),
            rep(.imConversation, minutesAfter: 3),
        ])
        #expect(s.map(\.phase) == [.done, .done, .done])
        #expect(s.allSatisfy { !$0.coveredViaFallback })
        #expect(s.allSatisfy { $0.unlockLine == nil })
    }

    @Test func fallbackLastStepSurfacesItsOwnMarkerAndHonestCoverage() {
        let plan = plan(NextActionModeAvailability(
            suddenDeathAvailable: true,
            imConversationAvailable: false
        ))
        let audience = step(.imConversation, in: plan)

        // The last step has no later row's lock line to carry its fallback
        // status — the marker must live on its own row.
        #expect(
            audience.fallbackMarkerLine
                == "Audience simulation unavailable — a Timed fallback is offered."
        )

        // While locked it still names its real unlock condition.
        var s = statuses(plan, reps: [rep(.timed, minutesAfter: 1)])
        #expect(s[2].phase == .locked)
        #expect(s[2].unlockLine == "Unlocks after the pressure round.")

        // Covered via its fallback: done, honestly marked.
        s = statuses(plan, reps: [
            rep(.timed, minutesAfter: 1),
            rep(.suddenDeath, minutesAfter: 2),
            rep(.timed, minutesAfter: 3),
        ])
        #expect(s.map(\.phase) == [.done, .done, .done])
        #expect(s[2].coveredViaFallback)
        #expect(
            audience.coveredViaFallbackLine
                == "Covered with the Timed fallback — the audience simulation itself is still untested."
        )
    }

    // MARK: - Intro copy casing + day-of branch

    @Test func introReadsCleanlyMidSentenceAndOnTheDay() {
        let tomorrow = PrepSessionPlanner.introCopy(
            category: .presentation,
            title: "Board pitch",
            days: 1
        )
        #expect(tomorrow.contains("Tomorrow is your presentation (Board pitch)."))
        #expect(!tomorrow.contains("is Your"))

        let today = PrepSessionPlanner.introCopy(
            category: .presentation,
            title: "Board pitch",
            days: 0
        )
        #expect(today.hasPrefix("Today is the day"))
        #expect(today.contains("your presentation (Board pitch)"))

        let sentenceStart = PrepSessionPlanner.introCopy(
            category: .presentation,
            title: "Board pitch",
            days: 5
        )
        #expect(sentenceStart.hasPrefix("Your presentation (Board pitch)"))
    }
}
