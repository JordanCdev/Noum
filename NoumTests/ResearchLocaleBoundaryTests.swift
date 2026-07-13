import Foundation
import Testing
@testable import Noum

@Suite("Research locale trust boundary")
struct ResearchLocaleBoundaryTests {
    private static let eligibleTranscript = "Um, so I think the release should start next week because the support team has time to prepare. The customer message needs one clear decision."

    @Test func englishRewriteRemainsEligibleForProviderAndOnDevicePaths() throws {
        #expect(AIRewriteService.eligibility(
            transcript: Self.eligibleTranscript,
            confidence: 0.9,
            locale: .enUS
        ) == .eligible)

        let rewrite = try #require(AIRewriteService.onDeviceRewrite(
            transcript: Self.eligibleTranscript,
            weakness: .opening,
            voice: .authoritative,
            intensity: .medium,
            confidence: 0.9,
            locale: .enUS
        ))
        #expect(rewrite.source == .onDevice)
    }

    @Test(arguments: [PracticeLocale.esES, .frFR])
    func unsupportedLocaleSuppressesProviderAndOnDeviceRewriteBeforeProviderResolution(
        locale: PracticeLocale
    ) async {
        let probe = ProviderResolutionProbe()
        let service = AIRewriteService(providerResolver: {
            probe.resolve()
        })

        #expect(AIRewriteService.eligibility(
            transcript: Self.eligibleTranscript,
            confidence: 0.9,
            locale: locale
        ) == .unsupportedLocale)
        #expect(AIRewriteService.onDeviceRewrite(
            transcript: Self.eligibleTranscript,
            weakness: .opening,
            voice: .authoritative,
            intensity: .medium,
            confidence: 0.9,
            locale: locale
        ) == nil)

        let rewrite = await service.rewrite(
            transcript: Self.eligibleTranscript,
            weakness: .opening,
            voice: .authoritative,
            transcriptConfidence: 0.9,
            locale: locale
        )
        #expect(rewrite == nil)
        #expect(probe.resolutionCount == 0)
    }

    @Test func goalOutcomeReadUsesTheSameHonestLocaleBoundary() throws {
        let fixture = DevSeedData.coachIntelligenceFixture(for: .improvingIntermediate)

        let englishRead = try #require(goalRead(fixture: fixture, locale: .enUS))
        #expect(englishRead.style == .warm)
        #expect(englishRead.evidenceLevel == .established)
        #expect(englishRead.movement == .improving)

        #expect(goalRead(fixture: fixture, locale: .esES) == nil)
        #expect(goalRead(fixture: fixture, locale: .frFR) == nil)
    }

    private func goalRead(
        fixture: DevSeedData.CoachIntelligenceFixture,
        locale: PracticeLocale
    ) -> GoalOutcomeRead? {
        GoalOutcomeEngine.read(
            profile: fixture.profile,
            baseline: fixture.baseline,
            rating: fixture.rating,
            sessions: fixture.sessions,
            coachMemory: fixture.memory,
            outcomes: fixture.recommendationOutcomes,
            locale: locale
        )
    }
}

private final class ProviderResolutionProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    var resolutionCount: Int {
        lock.withLock { count }
    }

    func resolve() -> AIProvider? {
        lock.withLock { count += 1 }
        return .openAI
    }
}
