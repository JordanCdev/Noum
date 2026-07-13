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

    @Test func deepLinkCarriesOnlyTheOpaquePromptToken() throws {
        let token = UUID()
        let url = try #require(URL(string:
            "noum://practice/timed?\(AppTab.timedPromptTokenQueryName)=\(token.uuidString)"
        ))

        #expect(AppTab.rootDestination(for: url) == .timedPracticePrompt(token: token))
        #expect(!url.absoluteString.contains("prompt text"))
    }
}
