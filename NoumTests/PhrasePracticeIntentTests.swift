import Foundation
import Testing
@testable import Noum

@MainActor
@Suite("Saved phrase practice intent", .serialized)
struct PhrasePracticeIntentTests {
    @Test func promptIsDeterministicAndBounded() throws {
        let text = String(repeating: "clear ", count: 80)
        let entry = PhraseBankEntry(
            id: UUID(uuidString: "9EB75D97-640C-418A-A595-B7111A672B66")!,
            text: text,
            voice: .concise,
            weakness: .structure,
            intensity: .medium,
            savedAt: Date(timeIntervalSince1970: 10)
        )

        let first = try #require(PhrasePracticeIntent(entry: entry))
        let second = try #require(PhrasePracticeIntent(entry: entry))

        #expect(first == second)
        #expect(first.sourceEntryID == entry.id)
        #expect(first.suggestedPrompt.hasPrefix(PhrasePracticeIntent.promptPrefix))
        #expect(first.suggestedPrompt.count <= PhrasePracticeIntent.maximumSuggestedPromptCharacters)
        #expect(first.suggestedPrompt.count == PhrasePracticeIntent.maximumSuggestedPromptCharacters)
    }

    @Test func identifierShapedTextIsRejectedAtSaveAndProjectionBoundaries() throws {
        let suite = "PhrasePracticeIntentTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PhraseBankStore(defaults: defaults, accountIDProvider: { "account-a" })

        #expect(store.save(
            text: "Email jordan@example.com after the meeting.",
            voice: .warm,
            weakness: .closing,
            intensity: .light
        ) == nil)

        let unsafeEntry = PhraseBankEntry(
            text: "Call +44 7700 900123 after the meeting.",
            voice: .warm,
            weakness: .closing,
            intensity: .light
        )
        #expect(PhrasePracticeIntent(entry: unsafeEntry) == nil)
    }

    @Test func practiceActionAppearsOnlyWhenCallbackIsWired() throws {
        let entry = PhraseBankEntry(
            text: "State the decision, then give one reason.",
            voice: .executive,
            weakness: .opening,
            intensity: .strong
        )

        #expect(PhraseBankSheet.practiceIntent(
            for: entry,
            onPracticePhrase: nil
        ) == nil)
        #expect(PhraseBankSheet.practiceIntent(
            for: entry,
            onPracticePhrase: { _ in }
        ) != nil)
    }

    @Test func practiceActionEmitsIntentBeforeDismissing() throws {
        let entry = PhraseBankEntry(
            text: "Name the ask, then stop.",
            voice: .concise,
            weakness: .closing,
            intensity: .light
        )
        let intent = try #require(PhrasePracticeIntent(entry: entry))
        var events: [String] = []
        var received: PhrasePracticeIntent?

        PhraseBankSheet.performPractice(
            intent,
            onPracticePhrase: {
                received = $0
                events.append("callback")
            },
            dismiss: { events.append("dismiss") }
        )

        #expect(received == intent)
        #expect(events == ["callback", "dismiss"])
    }

    @Test func constructingIntentCreatesNoPersistenceOwner() throws {
        let suite = "PhrasePracticeIntentTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PhraseBankStore(defaults: defaults, accountIDProvider: { "account-a" })
        let entry = try #require(store.save(
            text: "Lead with the outcome, then explain the tradeoff.",
            voice: .executive,
            weakness: .structure,
            intensity: .medium
        ))
        let before = defaults.dictionaryRepresentation()

        _ = try #require(PhrasePracticeIntent(entry: entry))

        #expect(defaults.dictionaryRepresentation() as NSDictionary == before as NSDictionary)
        #expect(defaults.dictionaryRepresentation().keys.filter {
            $0.hasPrefix(PhraseBankStore.storageKeyPrefix)
        }.count == 1)
    }
}
