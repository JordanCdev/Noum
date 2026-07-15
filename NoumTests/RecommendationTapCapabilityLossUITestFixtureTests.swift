import Testing
@testable import Noum

struct RecommendationTapCapabilityLossUITestFixtureTests {
    private let available = NextActionModeAvailability.allAvailable

    private var timedBlueprint: RecommendationBiasBlueprint {
        RecommendationBiasBlueprint(
            recommendedMode: .timed,
            recommendedTone: nil,
            recommendedScenario: nil,
            focus: "Original focus",
            target: "Original target",
            modeBenefit: "Original benefit",
            whyMode: "Original mode reason",
            whyNow: "Original timing reason",
            suggestedTimedDifficulty: .medium,
            suggestedTheme: .workCareer,
            source: .goalBias
        )
    }

    @Test func ordinaryLaunchPreservesTheLiveSnapshot() {
        let arguments = ["Noum", "UI_TESTING"]

        #expect(
            RecommendationTapCapabilityLossUITestFixture.availabilityAtTap(
                available,
                arguments: arguments
            ) == available
        )
        #expect(
            RecommendationTapCapabilityLossUITestFixture.imAvailableAtTap(
                true,
                arguments: arguments
            )
        )
        #expect(
            RecommendationTapCapabilityLossUITestFixture.blueprintForRendering(
                timedBlueprint,
                arguments: arguments
            ).recommendedMode == .timed
        )
        #expect(
            RecommendationTapCapabilityLossUITestFixture.summaryActionForRendering(
                nil,
                arguments: arguments
            ) == nil
        )
        #expect(
            RecommendationTapCapabilityLossUITestFixture.interruptedQuickStartMode(
                arguments: arguments
            ) == nil
        )
    }

    @Test func pressureLossChangesOnlyPressureAvailability() {
        let arguments = [
            "Noum",
            "UI_TESTING",
            RecommendationTapCapabilityLossUITestFixture.argumentName,
            RecommendationTapCapabilityLossUITestFixture.Capability.pressure.rawValue,
        ]
        let projected = RecommendationTapCapabilityLossUITestFixture.availabilityAtTap(
            available,
            arguments: arguments
        )

        #expect(!projected.suddenDeathAvailable)
        #expect(projected.imConversationAvailable)
        let rendered = RecommendationTapCapabilityLossUITestFixture.blueprintForRendering(
            timedBlueprint,
            arguments: arguments
        )
        #expect(rendered.recommendedMode == .suddenDeath)
        #expect(rendered.recommendedScenario == nil)
        #expect(rendered.recommendedTone == nil)
        #expect(rendered.suggestedTimedDifficulty == nil)
        #expect(rendered.suggestedTheme == .workCareer)
        #expect(
            RecommendationTapCapabilityLossUITestFixture.imAvailableAtTap(
                true,
                arguments: arguments
            )
        )

        guard let summaryAction = RecommendationTapCapabilityLossUITestFixture
            .summaryActionForRendering(nil, arguments: arguments) else {
            Issue.record("Expected the Summary fixture to provide a Pressure action")
            return
        }
        guard case .pressureExposure(let mode, _) = summaryAction.primary else {
            Issue.record("Expected a Pressure exposure action")
            return
        }
        #expect(mode == .suddenDeath)
        #expect(summaryAction.goalAttribution == nil)
        #expect(summaryAction.availabilityFallbackFrom == nil)
        #expect(
            RecommendationTapCapabilityLossUITestFixture.interruptedQuickStartMode(
                arguments: arguments
            ) == nil
        )

        let interruptedArguments = arguments + [
            RecommendationTapCapabilityLossUITestFixture
                .interruptedQuickStartArgumentName,
        ]
        #expect(
            RecommendationTapCapabilityLossUITestFixture.interruptedQuickStartMode(
                arguments: interruptedArguments
            ) == .timed
        )
    }

    @Test func conversationLossChangesBothConversationGuards() {
        let arguments = [
            "Noum",
            "UI_TESTING",
            RecommendationTapCapabilityLossUITestFixture.argumentName,
            RecommendationTapCapabilityLossUITestFixture.Capability.conversation.rawValue,
        ]
        let projected = RecommendationTapCapabilityLossUITestFixture.availabilityAtTap(
            available,
            arguments: arguments
        )

        #expect(projected.suddenDeathAvailable)
        #expect(!projected.imConversationAvailable)
        #expect(
            !RecommendationTapCapabilityLossUITestFixture.imAvailableAtTap(
                true,
                arguments: arguments
            )
        )
    }

    @Test func fixtureRequiresTheUITestingGateAndExactValue() {
        let missingGate = [
            "Noum",
            RecommendationTapCapabilityLossUITestFixture.argumentName,
            RecommendationTapCapabilityLossUITestFixture.Capability.pressure.rawValue,
        ]
        let unknownValue = [
            "Noum",
            "UI_TESTING",
            RecommendationTapCapabilityLossUITestFixture.argumentName,
            "timed",
        ]

        #expect(
            RecommendationTapCapabilityLossUITestFixture.availabilityAtTap(
                available,
                arguments: missingGate
            ) == available
        )
        #expect(
            RecommendationTapCapabilityLossUITestFixture.interruptedQuickStartMode(
                arguments: missingGate + [
                    RecommendationTapCapabilityLossUITestFixture
                        .interruptedQuickStartArgumentName,
                ]
            ) == nil
        )
        #expect(
            RecommendationTapCapabilityLossUITestFixture.availabilityAtTap(
                available,
                arguments: unknownValue
            ) == available
        )
    }
}
