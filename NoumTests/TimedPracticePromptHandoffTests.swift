import Foundation
import Testing
@testable import Noum

@MainActor
@Suite("Timed practice prompt handoff", .serialized)
struct TimedPracticePromptHandoffTests {
    @Test func promptIsAccountBoundAndConsumedExactlyOnce() throws {
        var accountID: String? = "account-a"
        let handoff = TimedPracticePromptHandoff(accountIDProvider: { accountID })

        let firstToken = try #require(
            handoff.offerToken("  Lead with the decision, then stop.  ")
        )
        #expect(handoff.pendingPrompt(accountID: "account-a") == "Lead with the decision, then stop.")
        #expect(handoff.pendingPrompt(accountID: "account-b") == nil)
        #expect(handoff.consume(token: firstToken) == "Lead with the decision, then stop.")
        #expect(handoff.consume(token: firstToken) == nil)

        let secondToken = try #require(handoff.offerToken("One more line."))
        accountID = "account-b"
        #expect(handoff.consume(token: secondToken) == nil)
        accountID = "account-a"
        #expect(handoff.consume(token: secondToken) == nil)
    }

    @Test func invalidAccountOrEmptyPromptFailsClosedAndClearsPendingValue() {
        let handoff = TimedPracticePromptHandoff(accountIDProvider: { nil })

        #expect(handoff.offerToken("A real prompt") == nil)
        #expect(handoff.offerToken("   ", accountID: "account-a") == nil)
        #expect(handoff.consume(token: UUID(), accountID: "account-a") == nil)
    }

    @Test func promptIsBoundedInMemoryAndLegacyGlobalKeyIsRemoved() {
        UserDefaults.standard.set(
            "unscoped legacy content",
            forKey: TimedPracticePromptHandoff.legacyDefaultsKey
        )
        UserDefaults.standard.set(
            "unscoped legacy word",
            forKey: TimedPracticePromptHandoff.legacySuggestedWordDefaultsKey
        )
        let handoff = TimedPracticePromptHandoff(accountIDProvider: { "account-a" })
        let oversized = String(repeating: "x", count: TimedPracticePromptHandoff.maximumPromptCharacters + 50)

        #expect(UserDefaults.standard.object(
            forKey: TimedPracticePromptHandoff.legacyDefaultsKey
        ) == nil)
        #expect(UserDefaults.standard.object(
            forKey: TimedPracticePromptHandoff.legacySuggestedWordDefaultsKey
        ) == nil)
        let token = handoff.offerToken(oversized)
        #expect(token != nil)
        #expect(token.flatMap { handoff.consume(token: $0) }?.count == TimedPracticePromptHandoff.maximumPromptCharacters)
        #expect(UserDefaults.standard.object(
            forKey: TimedPracticePromptHandoff.legacyDefaultsKey
        ) == nil)
    }

    @Test func staleRouteCannotConsumeOrEraseANewerPrompt() throws {
        let handoff = TimedPracticePromptHandoff(
            accountIDProvider: { "account-a" }
        )
        let staleToken = try #require(handoff.offerToken("Older prompt"))
        let liveToken = try #require(handoff.offerToken("Current prompt"))

        #expect(handoff.consume(token: staleToken) == nil)
        #expect(handoff.pendingPrompt(accountID: "account-a") == "Current prompt")
        #expect(handoff.consume(token: liveToken) == "Current prompt")
    }

    @Test func challengePayloadPreservesExactBytesAndObservationBinding() throws {
        let challengeID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let exactPrompt = "Résumé  update:\tname the risk.\nThen stop."
        let handoff = TimedPracticePromptHandoff(
            accountIDProvider: { "account-a" }
        )
        let token = try #require(handoff.offerChallengeToken(
            exactPrompt: exactPrompt,
            challengeID: challengeID
        ))

        let payload = try #require(handoff.consumePayload(token: token))

        #expect(payload.text == exactPrompt)
        #expect(payload.competitiveObservationIntent?.challengeID == challengeID)
        #expect(payload.competitiveObservationIntent?.matches(exactPrompt: exactPrompt) == true)
        #expect(payload.competitiveObservationIntent?.matches(
            exactPrompt: "Résumé update: name the risk. Then stop."
        ) == false)
        #expect(payload.observationIntent(
            matchingDisplayedPrompt: exactPrompt,
            activeAccountID: "account-a"
        )?.challengeID == challengeID)
        #expect(payload.observationIntent(
            matchingDisplayedPrompt: "Résumé update: name the risk. Then stop.",
            activeAccountID: "account-a"
        ) == nil)
        #expect(payload.observationIntent(
            matchingDisplayedPrompt: exactPrompt,
            activeAccountID: "account-b"
        ) == nil)
        #expect(handoff.consumePayload(token: token) == nil)
    }

    @Test func challengePayloadDoesNotNormalizeUnicodeOrCase() throws {
        let challengeID = UUID()
        let decomposedPrompt = "Defend THIS decision — Cafe\u{301}?"
        let originalBytes = Data(decomposedPrompt.utf8)
        let handoff = TimedPracticePromptHandoff(
            accountIDProvider: { "account-a" }
        )
        let token = try #require(handoff.offerChallengeToken(
            exactPrompt: decomposedPrompt,
            challengeID: challengeID
        ))
        let payload = try #require(handoff.consumePayload(token: token))

        #expect(Data(payload.text.utf8) == originalBytes)
        #expect(payload.observationIntent(
            matchingDisplayedPrompt: "Defend THIS decision — Café?",
            activeAccountID: "account-a"
        ) == nil)
        #expect(payload.observationIntent(
            matchingDisplayedPrompt: "Defend this decision — Cafe\u{301}?",
            activeAccountID: "account-a"
        ) == nil)
    }

    @Test func staleRouteCannotConsumeOrEraseNewerChallengeAuthority() throws {
        let handoff = TimedPracticePromptHandoff(
            accountIDProvider: { "account-a" }
        )
        let staleToken = try #require(handoff.offerToken("Older prompt"))
        let challengeID = UUID()
        let liveToken = try #require(handoff.offerChallengeToken(
            exactPrompt: "Current  challenge prompt",
            challengeID: challengeID
        ))

        #expect(handoff.consumePayload(token: staleToken) == nil)
        let live = try #require(handoff.consumePayload(token: liveToken))
        #expect(live.text == "Current  challenge prompt")
        #expect(live.competitiveObservationIntent?.challengeID == challengeID)
    }

    @Test func challengePayloadFailsClosedWithoutMutatingExactAuthority() throws {
        let challengeID = UUID()
        let handoff = TimedPracticePromptHandoff(
            accountIDProvider: { "account-a" }
        )
        let oversized = String(
            repeating: "x",
            count: AsyncChallengeAuthorityEnvelope.maximumPromptUTF16CodeUnits + 1
        )

        #expect(handoff.offerChallengeToken(
            exactPrompt: "   \n\t",
            challengeID: challengeID
        ) == nil)
        #expect(handoff.offerChallengeToken(
            exactPrompt: " Prompt with outer whitespace ",
            challengeID: challengeID
        ) == nil)
        #expect(handoff.offerChallengeToken(
            exactPrompt: oversized,
            challengeID: challengeID
        ) == nil)
        #expect(handoff.offerChallengeToken(
            exactPrompt: "Exact prompt",
            challengeID: challengeID,
            accountID: nil
        ) == nil)

        let token = try #require(handoff.offerChallengeToken(
            exactPrompt: "Exact  prompt",
            challengeID: challengeID
        ))
        #expect(handoff.consumePayload(token: token, accountID: "account-b") == nil)
        #expect(handoff.consumePayload(token: token, accountID: "account-a") == nil)
    }

    @Test func ordinaryPromptPayloadCarriesNoCompetitiveAuthorityAndClearDropsChallenge() throws {
        let handoff = TimedPracticePromptHandoff(
            accountIDProvider: { "account-a" }
        )
        let ordinaryToken = try #require(handoff.offerToken("  Ordinary   prompt  "))
        let ordinary = try #require(handoff.consumePayload(token: ordinaryToken))
        #expect(ordinary.text == "Ordinary prompt")
        #expect(ordinary.competitiveObservationIntent == nil)

        let challengeToken = try #require(handoff.offerChallengeToken(
            exactPrompt: "Exact challenge prompt",
            challengeID: UUID()
        ))
        handoff.clear()
        #expect(handoff.consumePayload(token: challengeToken) == nil)
    }

    @Test func deepLinkCarriesOnlyTheOpaquePromptToken() throws {
        let token = UUID()
        let url = try #require(URL(string:
            "noum://practice/timed?\(AppTab.timedPromptTokenQueryName)=\(token.uuidString)"
        ))

        #expect(AppTab.rootDestination(for: url) == .timedPracticePrompt(token: token))
        #expect(!url.absoluteString.contains("prompt text"))
    }
}
