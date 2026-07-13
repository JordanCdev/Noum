import Foundation
import Testing
@testable import Noum

@Suite("Prep session availability")
struct PrepSessionAvailabilityTests {
    private let moment = BigMoment(
        title: "Board pitch",
        category: .presentation
    )

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

    @Test func allAvailablePreservesEveryPlannedExerciseAndSetup() {
        let plan = plan(.allAvailable)

        #expect(plan.steps.map(\.mode) == [.timed, .suddenDeath, .imConversation])
        #expect(plan.steps.map(\.renderedMode) == [.timed, .suddenDeath, .imConversation])
        #expect(plan.steps.allSatisfy { !$0.isAvailabilityFallback })
        #expect(step(.timed, in: plan).renderedLaunch.destination == .timedPractice)
        #expect(step(.suddenDeath, in: plan).renderedLaunch.destination == .suddenDeathPractice)
        #expect(
            step(.imConversation, in: plan).renderedLaunch.destination
                == .imPractice(scenario: nil, tone: nil)
        )
        #expect(plan.imScenario?.persona == "Skeptical board member")
        #expect(plan.introductionCopy.contains("run a pressure round"))
        #expect(plan.introductionCopy.contains("take questions"))
    }

    @Test func lockedPressureRendersAnHonestTimedFallbackWithStableShapeIdentity() {
        let plan = plan(NextActionModeAvailability(
            suddenDeathAvailable: false,
            imConversationAvailable: true
        ))
        let pressure = step(.suddenDeath, in: plan)

        #expect(pressure.mode == .suddenDeath)
        #expect(pressure.renderedMode == .timed)
        #expect(pressure.renderedLaunch.destination == .timedPractice)
        #expect(pressure.isAvailabilityFallback)
        #expect(pressure.displayLabel == "Build-up rep: Timed Practice")
        #expect(pressure.rationale == NextActionModeAvailability.suddenDeathFallbackReason)
        #expect(!plan.introductionCopy.contains("run a pressure round"))
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
        #expect(audience.renderedLaunch.destination == .timedPractice)
        #expect(audience.isAvailabilityFallback)
        #expect(audience.displayLabel == "Question rehearsal: Timed Practice")
        #expect(audience.rationale == NextActionModeAvailability.imConversationFallbackReason)
        #expect(plan.imScenario == nil)
        #expect(!plan.introductionCopy.contains("take questions from the kind of audience"))
        #expect(plan.introductionCopy.contains("likely question in Timed Practice"))
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
            .timedPractice,
            .timedPractice,
            .timedPractice,
        ])
        #expect(plan.imScenario == nil)
        #expect(plan.introductionCopy.contains("two focused Timed Practice passes"))

        let momentCreatedAt = Date(timeIntervalSince1970: 1_000)
        let timedRep = PracticeSession(
            transcript: "One rehearsal",
            fillerWordCount: 0,
            duration: 60,
            date: momentCreatedAt.addingTimeInterval(60),
            mode: .timed
        )
        let readiness = PrepSessionPlanner.readiness(
            plan: plan,
            sessions: [timedRep],
            momentCreatedAt: momentCreatedAt
        )

        #expect(readiness.coveredModes == [.timed])
        #expect(readiness.coveredCount == 1)
        #expect(readiness.level == .underway)
        #expect(readiness.displayLine(for: plan.steps).contains("remain untested"))
        #expect(step(.suddenDeath, in: plan).readinessLabel.contains("Timed fallback offered"))
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
        #expect(lostPressure.destination == .timedPractice)
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
        #expect(capabilityReturned.destination == .timedPractice)
        #expect(capabilityReturned.acceptsDisplayedPrescription)
    }
}
