import Foundation
import Testing
@testable import Noum

@Suite("Release product trust")
struct ReleaseProductTrustTests {
    @Test func proofClaimsRejectSingleRepInnerStateAssertions() {
        let unsupported = [
            "You spoke from a real place.",
            "That was your authentic voice.",
            "You meant it this time.",
            "Your confidence carried the close.",
            "You felt in control.",
        ]

        for claim in unsupported {
            #expect(!ProofMomentService.claimStaysObservable(claim))
        }
    }

    @Test func proofClaimsAllowObservableEvidenceLanguage() {
        let supported = [
            "No fillers across this rep.",
            "This line came from a high-scoring rep.",
            "You sustained the rep beyond 45 seconds.",
        ]

        for claim in supported {
            #expect(ProofMomentService.claimStaysObservable(claim))
        }
    }

    @Test func dayZeroQuarantinesPersistedCoachHistory() {
        #expect(!AskNoumDayZeroGreeting.canDisplayPersistedThread(sessionCount: 0))
        #expect(AskNoumDayZeroGreeting.canDisplayPersistedThread(sessionCount: 1))
        #expect(AskNoumDayZeroGreeting.canDisplayPersistedThread(sessionCount: 12))
    }

    @Test @MainActor func askNoumStopsBeforeTransportWithoutCloudConsent() async {
        let service = AICoachChatService(
            secureTransport: ConsentProbeCoachTransport(),
            cloudProcessingAllowed: { false }
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "What should I practise next?")],
            systemPrompt: "Give one grounded coaching move.",
            userContext: "No cloud processing permission."
        )

        guard case .failure(.consentRequired) = outcome else {
            Issue.record("Ask Noum crossed the cloud boundary without consent")
            return
        }
        #expect(AskNoumStore.noticeCopy(for: .consentRequired).contains("Settings > Cloud Processing"))
    }
}

private enum ConsentProbeError: Error {
    case transportWasCalled
}

private struct ConsentProbeCoachTransport: CoachChatTransport {
    func availability() async -> CoachChatTransportAvailability { .available }

    func stream(
        _ request: CoachChatRequest
    ) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        throw ConsentProbeError.transportWasCalled
    }
}
