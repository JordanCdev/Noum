import Foundation
import Testing
@testable import Noum

@Suite("V3 onboarding and shell contracts")
struct V3OnboardingShellTests {
    @Test("Fast lane choices carry semantic identity and one training promise")
    func fastLaneChoicesAreAuthored() {
        let contextChoices = SpeakingContext.allCases.map(FastLaneChoicePresentation.context)
        let challengeChoices = SpeakingChallenge.allCases.map(FastLaneChoicePresentation.challenge)

        #expect(contextChoices.allSatisfy { !$0.symbol.isEmpty && !$0.detail.isEmpty })
        #expect(challengeChoices.allSatisfy { !$0.symbol.isEmpty && !$0.detail.isEmpty })
        #expect(Set(contextChoices.map(\.symbol)).count == SpeakingContext.allCases.count)
        #expect(Set(challengeChoices.map(\.symbol)).count == SpeakingChallenge.allCases.count)
        #expect((contextChoices + challengeChoices).allSatisfy { !$0.detail.contains("!") })
    }

    @Test("Full setup gives every choice a distinct visual role")
    @available(iOS 17.0, macOS 12.0, *)
    func coachingChoicesAreAuthored() {
        let contextChoices = SpeakingContext.allCases.map(CoachingOnboardingChoicePresentation.context)
        let challengeChoices = SpeakingChallenge.allCases.map(CoachingOnboardingChoicePresentation.challenge)
        let styleChoices = SpeakingStyleGoal.allCases.map(CoachingOnboardingChoicePresentation.style)

        #expect(contextChoices.allSatisfy { !$0.symbol.isEmpty && !$0.detail.isEmpty })
        #expect(challengeChoices.allSatisfy { !$0.symbol.isEmpty && !$0.detail.isEmpty })
        #expect(styleChoices.allSatisfy { !$0.symbol.isEmpty && !$0.detail.isEmpty })
        #expect(Set(styleChoices.map(\.symbol)).count == SpeakingStyleGoal.allCases.count)
    }

    @Test("Fast lane presents one bounded choice per step")
    func fastLaneIsBiteSizedAndTruthful() throws {
        let source = try repositorySource("Noum/FastLaneOnboardingView.swift")

        #expect(source.contains("case context"))
        #expect(source.contains("case challenge"))
        #expect(source.contains("fastLane.contextContinue"))
        #expect(source.contains("Structure only · not saved"))
        #expect(source.contains("A written rehearsal can show answer shape"))
        #expect(source.contains("fastLane.otherOptions"))
        #expect(source.contains("Not ready to record?"))
        #expect(source.contains("NoumSemanticGraphic"))
        #expect(!source.contains("NoumWaveformMark"))
        #expect(source.contains("NoumProgressTrack"))
        #expect(source.contains("startingHypothesisNote"))
        #expect(source.contains("FastLaneChoicePresentation"))
        #expect(source.contains(".id(phase.rawValue)"))
        #expect(source.contains(".buttonStyle(.pressable)"))
        #expect(!source.contains("buttonStyle(.borderedProminent)"))
        #expect(!source.contains("LinearGradient"))
    }

    @Test("Full setup uses semantic graphics and calm motion")
    func coachingSetupUsesFoundation() throws {
        let source = try repositorySource("Noum/CoachingOnboardingView.swift")

        #expect(source.contains("NoumSemanticGraphic"))
        #expect(!source.contains("NoumWaveformMark"))
        #expect(source.contains("NoumSurface(.quiet)"))
        #expect(source.contains("NoumProgressTrack"))
        #expect(source.contains("NoumMotion.animation(for: .calm"))
        #expect(source.contains("@State private var speakingContext: SpeakingContext?"))
        #expect(source.contains("@State private var biggestChallenge: SpeakingChallenge?"))
        #expect(source.contains("_screen = State(initialValue: .question(.style))"))
        #expect(source.contains("Final choice"))
        #expect(source.contains("KeychainHelper.uiAutomationLaunchMode("))
        #expect(source.contains("saveForOnboarding("))
        #expect(source.contains("CoachingOnboardingChoicePresentation"))
        #expect(source.contains("One focus. One first rep."))
        #expect(source.contains(".id(stage.rawValue)"))
        #expect(!source.contains("LinearGradient"))
        #expect(!source.contains("matchedGeometryEffect"))
        #expect(!source.contains("symbolEffect"))
    }

    @Test("Shell keeps route ownership while adopting quiet V3 chrome")
    func shellKeepsNavigationTruth() throws {
        let source = try repositorySource("Noum/AppShellView.swift")

        #expect(source.contains("DeepLinkRouter.shared"))
        #expect(source.contains("@State private var homePath = NavigationPath()"))
        #expect(source.contains("@State private var trainPath = NavigationPath()"))
        #expect(source.contains("@State private var reviewPath = NavigationPath()"))
        #expect(source.contains("@State private var profilePath = NavigationPath()"))
        #expect(source.contains("mic.fill"))
        #expect(!source.contains("NoumWaveformMark("))
        #expect(source.contains("NoumMotion.animation(for: .calm"))
        #expect(source.contains("SocialReleaseCapabilities.friendConnections.isAvailable"))
        #expect(source.contains("SocialReleaseCapabilities.peerProgress.isAvailable"))
        #expect(source.contains("size: 11, weight: isSelected"))
    }

    private func repositorySource(_ relativePath: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
        let root = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
