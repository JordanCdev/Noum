import Foundation
import Testing

@Suite("V3 onboarding and shell contracts")
struct V3OnboardingShellTests {
    @Test("Fast lane presents one bounded choice per step")
    func fastLaneIsBiteSizedAndTruthful() throws {
        let source = try repositorySource("Noum/FastLaneOnboardingView.swift")

        #expect(source.contains("case context"))
        #expect(source.contains("case challenge"))
        #expect(source.contains("fastLane.contextContinue"))
        #expect(source.contains("Structure only · not saved"))
        #expect(source.contains("A written rehearsal can show answer shape"))
        #expect(source.contains("NoumWaveformMark"))
        #expect(source.contains("NoumProgressTrack"))
        #expect(!source.contains("buttonStyle(.borderedProminent)"))
        #expect(!source.contains("LinearGradient"))
    }

    @Test("Full setup uses shared V3 identity and calm motion")
    func coachingSetupUsesFoundation() throws {
        let source = try repositorySource("Noum/CoachingOnboardingView.swift")

        #expect(source.contains("NoumWaveformMark"))
        #expect(source.contains("NoumSurface(.quiet)"))
        #expect(source.contains("NoumProgressTrack"))
        #expect(source.contains("NoumMotion.animation(for: .calm"))
        #expect(source.contains("@State private var speakingContext: SpeakingContext?"))
        #expect(source.contains("@State private var biggestChallenge: SpeakingChallenge?"))
        #expect(source.contains("KeychainHelper.uiAutomationLaunchMode("))
        #expect(source.contains("saveForOnboarding("))
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
        #expect(source.contains("NoumWaveformMark("))
        #expect(source.contains("NoumMotion.animation(for: .calm"))
        #expect(source.contains("SocialReleaseCapabilities.friendConnections.isAvailable"))
        #expect(source.contains("SocialReleaseCapabilities.peerProgress.isAvailable"))
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
