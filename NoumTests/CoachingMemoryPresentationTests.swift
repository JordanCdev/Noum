import Foundation
import Testing
@testable import Noum

@Suite("Coaching memory presentation")
struct CoachingMemoryPresentationTests {
    @Test func presentsStableKindsInApprovedOrder() {
        let presentation = CoachingMemoryPresentation.make(
            memory: nil,
            profile: nil
        )

        #expect(presentation.items.map(\.kind) == [
            .currentLever,
            .workContext,
            .voicePreference
        ])
    }

    @Test func observedLeverNamesEvidenceDepthAndUncertainty() throws {
        let presentation = CoachingMemoryPresentation.make(
            memory: memory(
                evidenceCount: 2,
                statedGoal: nil,
                lever: .openingStrength,
                confidence: .low
            ),
            profile: nil
        )
        let item = try #require(
            presentation.items.first(where: { $0.kind == .currentLever })
        )

        #expect(item.value == "Open with the answer")
        #expect(item.provenance == "Observed from 2 eligible reps · still testing")
    }

    @Test func userAuthoredGoalTakesPriorityOverProfileTaxonomy() throws {
        let presentation = CoachingMemoryPresentation.make(
            memory: memory(
                evidenceCount: 3,
                statedGoal: "Tighten answers in stakeholder meetings",
                lever: .structure,
                confidence: .medium
            ),
            profile: profile(chosenVoice: .warm)
        )
        let item = try #require(
            presentation.items.first(where: { $0.kind == .workContext })
        )

        #expect(item.value == "Tighten answers in stakeholder meetings")
        #expect(item.provenance == "Added by you")
    }

    @Test func unchosenCompatibilityVoiceNeverAppearsAsConfirmed() throws {
        let presentation = CoachingMemoryPresentation.make(
            memory: nil,
            profile: profile(chosenVoice: nil)
        )
        let item = try #require(
            presentation.items.first(where: { $0.kind == .voicePreference })
        )

        #expect(item.value == "Not chosen yet")
        #expect(item.provenance == "No voice preference confirmed by you")
    }

    @Test func explicitVoiceBlendKeepsUserChoiceProvenance() throws {
        var coachingProfile = profile(chosenVoice: .warm)
        coachingProfile.secondaryStyleGoal = .concise
        let presentation = CoachingMemoryPresentation.make(
            memory: nil,
            profile: coachingProfile
        )
        let item = try #require(
            presentation.items.first(where: { $0.kind == .voicePreference })
        )

        #expect(item.value == "Warm and welcoming + Concise and sharp")
        #expect(item.provenance == "Confirmed by you")
    }

    @Test func profileLibraryAlwaysIncludesCoachingMemoryNearEvidence() {
        let rows = ProfileLibraryPresentation.make(
            showsPeerComparison: false,
            isPremium: true
        ).rows

        #expect(Array(rows.prefix(3)) == [
            .coachingEvidence,
            .coachingMemory,
            .growthLibrary
        ])
    }

    @Test func coachingMemoryDestinationIsStableAndDistinct() {
        let first: AppDestination = .coachingMemory
        let second: AppDestination = .coachingMemory

        #expect(first == second)
        #expect(first != .growthLibrary)
        #expect(Set([first, second]).count == 1)
    }

    private func memory(
        evidenceCount: Int,
        statedGoal: String?,
        lever: SkillArea?,
        confidence: TrendConfidence?
    ) -> CoachMemory {
        CoachMemory(
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            evidenceCount: evidenceCount,
            evidenceConfidence: .tentative,
            statedGoalSummary: statedGoal,
            currentLever: lever,
            currentLeverConfidence: confidence,
            goalFit: .noVoice,
            strengths: [],
            blockers: []
        )
    }

    private func profile(chosenVoice: SpeakingStyleGoal?) -> CoachingProfile {
        CoachingProfile(
            speakingContext: .work,
            primaryGoal: .moreConcise,
            confidenceLevel: .inconsistent,
            biggestChallenge: .rambling,
            desiredOutcome: .concise,
            speakingStyleGoal: .concise,
            styleReference: "Stakeholder meetings",
            coachingBrief: "Land the point cleanly",
            motivationWhyNow: "More leadership meetings",
            successVision: "Make the decision clear",
            chosenStyleGoal: chosenVoice
        )
    }
}
