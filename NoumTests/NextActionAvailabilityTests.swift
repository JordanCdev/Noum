import Foundation
import Testing
@testable import Noum

@Suite("Next action mode availability")
struct NextActionAvailabilityTests {
    @Test func snapshotUsesTheExistingRatedEvidenceGate() {
        let unrated = NextActionModeAvailability(rating: .initial)
        #expect(!unrated.suddenDeathAvailable)
        #expect(!unrated.imConversationAvailable)

        let rated = RatingEngine.processRatedSession(
            rating: .initial,
            sessionScore: 8,
            sessionId: UUID(),
            pressureLevel: .elevated
        )

        let available = NextActionModeAvailability(
            rating: rated,
            imConversationAvailable: true
        )
        #expect(available.suddenDeathAvailable)
        #expect(available.imConversationAvailable)
    }

    @Test func lockedStretchFallsBackToTimedWithMatchingCopy() {
        let result = NextActionEngine.recommend(
            input: stretchInput()
        )

        guard case .practiceMode(let mode, let reason) = result.primary else {
            Issue.record("Expected locked Pressure Drill to fall back to Timed Practice")
            return
        }
        #expect(mode == .timed)
        #expect(result.primary.displayTitle == PracticeMode.timed.displayLabel)
        #expect(reason == NextActionModeAvailability.suddenDeathFallbackReason)
        #expect(result.reasoning == reason)
        #expect(result.availabilityFallbackFrom == .suddenDeath)
        #expect(!result.primary.displayTitle.localizedCaseInsensitiveContains("pressure"))
    }

    @Test func unlockedStretchStillPrescribesSuddenDeath() {
        let rated = RatingEngine.processRatedSession(
            rating: .initial,
            sessionScore: 8,
            sessionId: UUID(),
            pressureLevel: .elevated
        )
        let result = NextActionEngine.recommend(
            input: stretchInput(
                availability: NextActionModeAvailability(rating: rated)
            )
        )

        guard case .pressureExposure(let mode, _) = result.primary else {
            Issue.record("Expected the unlocked stretch to preserve Pressure Drill")
            return
        }
        #expect(mode == .suddenDeath)
        #expect(result.availabilityFallbackFrom == nil)
    }

    @Test func lockedBlueprintFallsBackWithTimedCopyAndNoPressureSetup() {
        let original = pressureBlueprint()
        let resolved = NextActionModeAvailability.failClosed.resolving(original)

        #expect(resolved.recommendedMode == .timed)
        #expect(resolved.recommendedTone == nil)
        #expect(resolved.recommendedScenario == nil)
        #expect(resolved.focus == "First clear read")
        #expect(resolved.target == "Complete one rated rep")
        #expect(resolved.whyNow == PracticeModePrescriptionCopy.pressureLockedDisplayHint)
        #expect(resolved.suggestedTheme == original.suggestedTheme)
        #expect(resolved.source == original.source)
    }

    @Test func unavailableConversationBlueprintFallsBackWithoutStaleSetupOrCopy() {
        let original = conversationBlueprint()
        let resolved = NextActionModeAvailability(
            suddenDeathAvailable: true,
            imConversationAvailable: false
        ).resolving(original)

        #expect(resolved.recommendedMode == .timed)
        #expect(resolved.recommendedTone == nil)
        #expect(resolved.recommendedScenario == nil)
        #expect(resolved.focus == original.focus)
        #expect(resolved.target == original.target)
        #expect(resolved.focus != "First clear read")
        #expect(resolved.whyNow == NextActionModeAvailability.imConversationFallbackReason)
        #expect(!resolved.whyNow.localizedCaseInsensitiveContains("live exchange"))
        #expect(resolved.source == original.source)
    }

    @Test func trainHeroProjectionFallsBackAsOneCoherentConversationSnapshot() {
        let original = conversationBlueprint()
        let available = TrainRecommendationProjection.resolve(
            blueprint: original,
            availability: .allAvailable,
            visibleModes: [.timed, .suddenDeath, .ahCounter, .imConversation]
        )
        #expect(available.mode == .imConversation)
        #expect(available.title == PracticeMode.imConversation.displayLabel)
        #expect(available.reason == original.whyNow)
        #expect(available.focus == original.focus)
        #expect(available.target == original.target)
        #expect(available.scenario == original.recommendedScenario)
        #expect(available.tone == original.recommendedTone)

        let rendered = TrainRecommendationProjection.resolve(
            blueprint: original,
            availability: .failClosed,
            visibleModes: [.timed, .suddenDeath, .ahCounter]
        )

        #expect(rendered.mode == .timed)
        #expect(rendered.blueprint.recommendedMode == rendered.mode)
        #expect(rendered.title == PracticeMode.timed.displayLabel)
        #expect(rendered.reason == NextActionModeAvailability.imConversationFallbackReason)
        #expect(rendered.reason != original.whyNow)
        #expect(rendered.focus == original.focus)
        #expect(rendered.target == original.target)
        #expect(rendered.scenario == nil)
        #expect(rendered.tone == nil)
        #expect(rendered.suggestedTheme == original.suggestedTheme)
    }

    @Test func trainHeroProjectionFallsBackAsOneCoherentPressureSnapshot() {
        let original = pressureBlueprint()
        let rendered = TrainRecommendationProjection.resolve(
            blueprint: original,
            availability: .failClosed,
            visibleModes: [.timed, .suddenDeath, .ahCounter]
        )

        #expect(rendered.mode == .timed)
        #expect(rendered.blueprint.recommendedMode == rendered.mode)
        #expect(rendered.title == PracticeMode.timed.displayLabel)
        #expect(rendered.reason == PracticeModePrescriptionCopy.pressureLockedDisplayHint)
        #expect(rendered.focus == "First clear read")
        #expect(rendered.target == "Complete one rated rep")
        #expect(rendered.scenario == nil)
        #expect(rendered.tone == nil)
        #expect(rendered.suggestedTheme == original.suggestedTheme)
    }

    @Test func unavailableConversationActionFallsBackWithConversationSpecificReason() {
        let result = NextActionEngine.recommend(
            input: improvingConversationInput()
        )

        guard case .practiceMode(let mode, let reason) = result.primary else {
            Issue.record("Expected unavailable Conversation Practice to fall back to Timed Practice")
            return
        }
        #expect(mode == .timed)
        #expect(reason == NextActionModeAvailability.imConversationFallbackReason)
        #expect(result.reasoning == reason)
        #expect(result.availabilityFallbackFrom == .imConversation)
        #expect(!reason.localizedCaseInsensitiveContains("pressure drill"))
    }

    @Test func homeExposureIdentityUsesTheResolvedAvailableBlueprint() {
        let unavailable = NextActionModeAvailability.failClosed

        for original in [pressureBlueprint(), conversationBlueprint()] {
            let resolved = unavailable.resolving(original)
            let exposure = HomeCoachRecommendationExposure.make(
                blueprint: resolved,
                title: resolved.focus,
                profile: nil,
                recentSessions: []
            )

            #expect(exposure.mode == .timed)
            #expect(exposure.scenario == nil)
            #expect(exposure.tone == nil)
            #expect(exposure.suggestedTheme == original.suggestedTheme)
            if original.recommendedMode == .suddenDeath {
                #expect(exposure.focus == "First clear read")
                #expect(exposure.target == "Complete one rated rep")
            } else {
                #expect(exposure.focus == original.focus)
                #expect(exposure.target == original.target)
            }
            #expect(exposure.fingerprint.contains(PracticeMode.timed.rawValue))
            #expect(
                exposure.fingerprint.contains(original.focus)
                    == (original.recommendedMode == .imConversation)
            )
        }
    }

    @Test func launchProjectionSeparatesVisibleAcceptanceFromOperationalFallback() {
        let lockedPressure = PracticeModeLaunchProjection.resolve(
            displayedMode: .suddenDeath,
            imAvailable: true,
            modeAvailability: .failClosed
        )
        #expect(lockedPressure.launchedMode == .timed)
        #expect(lockedPressure.destination == .timedPractice)
        #expect(!lockedPressure.acceptsDisplayedPrescription)

        let availablePressure = PracticeModeLaunchProjection.resolve(
            displayedMode: .suddenDeath,
            imAvailable: false,
            modeAvailability: .allAvailable
        )
        #expect(availablePressure.launchedMode == .suddenDeath)
        #expect(availablePressure.destination == .suddenDeathPractice)
        #expect(availablePressure.acceptsDisplayedPrescription)

        let lostConversationProvider = PracticeModeLaunchProjection.resolve(
            displayedMode: .imConversation,
            scenario: .difficultConversation,
            tone: .calm,
            imAvailable: false,
            modeAvailability: .allAvailable
        )
        #expect(lostConversationProvider.launchedMode == .timed)
        #expect(lostConversationProvider.destination == .timedPractice)
        #expect(!lostConversationProvider.acceptsDisplayedPrescription)

        let availableConversation = PracticeModeLaunchProjection.resolve(
            displayedMode: .imConversation,
            scenario: .difficultConversation,
            tone: .calm,
            imAvailable: true,
            modeAvailability: .allAvailable
        )
        #expect(availableConversation.launchedMode == .imConversation)
        #expect(availableConversation.destination == .imPractice(
            scenario: .difficultConversation,
            tone: .calm
        ))
        #expect(availableConversation.acceptsDisplayedPrescription)

        for mode in [PracticeMode.timed, .ahCounter] {
            let launch = PracticeModeLaunchProjection.resolve(
                displayedMode: mode,
                imAvailable: false,
                modeAvailability: .failClosed
            )
            #expect(launch.launchedMode == mode)
            #expect(launch.acceptsDisplayedPrescription)
        }
    }

    @Test func unlockedBlueprintIsPreserved() {
        let original = pressureBlueprint()
        let resolved = NextActionModeAvailability.allAvailable.resolving(original)

        #expect(resolved.recommendedMode == original.recommendedMode)
        #expect(resolved.focus == original.focus)
        #expect(resolved.target == original.target)
        #expect(resolved.whyNow == original.whyNow)
    }

    private func stretchInput(
        availability: NextActionModeAvailability? = nil
    ) -> NextActionInput {
        var input = NextActionInput(
            fillerCount: 0,
            duration: 50,
            wordCount: 140,
            wpm: 135,
            score: 8,
            categoryRatings: ["Opening": "Good", "Structure": "Good"],
            mode: .timed,
            pressureLevel: .standard,
            baseline: .empty,
            pressureProfile: .empty,
            trends: [],
            drillHistory: [],
            sessionCount: 1,
            streakDays: 1,
            styleGoal: nil
        )
        if let availability {
            input.modeAvailability = availability
        }
        return input
    }

    private func pressureBlueprint() -> RecommendationBiasBlueprint {
        RecommendationBiasBlueprint(
            recommendedMode: .suddenDeath,
            recommendedTone: .assertive,
            recommendedScenario: .difficultConversation,
            focus: "Hold structure under pressure",
            target: "Finish one clean pressure rep",
            modeBenefit: "Tests control under a tighter clock.",
            whyMode: "Pressure Drill exposes rushed openings.",
            whyNow: "Your casual reps are ahead of your pressure reps.",
            suggestedTimedDifficulty: nil,
            suggestedTheme: .workCareer,
            source: .caseIntervention
        )
    }

    private func improvingConversationInput() -> NextActionInput {
        NextActionInput(
            fillerCount: 2,
            duration: 40,
            wordCount: 100,
            wpm: 130,
            score: 7,
            categoryRatings: ["Opening": "Good", "Structure": "OK"],
            mode: .imConversation,
            pressureLevel: .standard,
            baseline: .empty,
            pressureProfile: .empty,
            trends: [
                SkillTrend(
                    skillArea: .fillerReduction,
                    direction: .improving,
                    confidence: .medium,
                    windowSize: 8,
                    currentLevel: .solid,
                    recentDelta: "2 fewer fillers than 5 sessions ago"
                )
            ],
            drillHistory: [
                DrillHistoryStore.Entry(
                    variationId: "conversation-availability",
                    skillArea: .fillerReduction,
                    succeeded: true,
                    sessionId: UUID()
                )
            ],
            sessionCount: 8,
            streakDays: 3,
            styleGoal: nil
        )
    }

    private func conversationBlueprint() -> RecommendationBiasBlueprint {
        RecommendationBiasBlueprint(
            recommendedMode: .imConversation,
            recommendedTone: .calm,
            recommendedScenario: .difficultConversation,
            focus: "Hold one point through a live exchange",
            target: "Complete the conversation without retreating",
            modeBenefit: "Tests tone under realistic pushback.",
            whyMode: "Conversation Practice reveals relational pressure.",
            whyNow: "Your last live exchange lost the central point.",
            suggestedTimedDifficulty: nil,
            suggestedTheme: .workCareer,
            source: .caseIntervention
        )
    }
}
