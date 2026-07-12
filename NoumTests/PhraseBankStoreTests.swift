import Foundation
import Testing
@testable import Noum

@MainActor
@Suite("Saved rewrite phrase bank", .serialized)
struct PhraseBankStoreTests {
    @Test func entriesAreAccountScopedAndDeduplicated() throws {
        let suite = "PhraseBankStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        var accountID = "account-a"
        let store = PhraseBankStore(defaults: defaults, accountIDProvider: { accountID })
        let original = try #require(store.save(
            text: "  Start with the decision, then give one reason.  ",
            voice: .executive,
            weakness: .opening,
            intensity: .medium,
            now: Date(timeIntervalSince1970: 10)
        ))
        let refreshed = try #require(store.save(
            text: "start with the decision, then give one reason.",
            voice: .executive,
            weakness: .opening,
            intensity: .strong,
            now: Date(timeIntervalSince1970: 20)
        ))
        #expect(store.entries.count == 1)
        #expect(refreshed.id == original.id)
        #expect(refreshed.intensity == .strong)

        accountID = "account-b"
        store.reloadForCurrentAccount()
        #expect(store.entries.isEmpty)
        _ = store.save(
            text: "Name the ask, then stop.",
            voice: .concise,
            weakness: .closing,
            intensity: .light
        )

        accountID = "account-a"
        store.reloadForCurrentAccount()
        #expect(store.entries.map(\.id) == [original.id])
        #expect(store.entries.first?.text == "start with the decision, then give one reason.")
    }

    @Test func rejectsIdentifierShapedPhrasesAndBoundsTheArchive() throws {
        let suite = "PhraseBankStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = PhraseBankStore(defaults: defaults, accountIDProvider: { "account-a" })

        #expect(store.save(
            text: "Email jordan@example.com after the meeting.",
            voice: .warm,
            weakness: .structure,
            intensity: .medium
        ) == nil)

        for index in 0..<(PhraseBankStore.maximumEntries + 3) {
            _ = store.save(
                text: "State the decision number \(index), then stop.",
                voice: .authoritative,
                weakness: .closing,
                intensity: .light,
                now: Date(timeIntervalSince1970: TimeInterval(index))
            )
        }
        #expect(store.entries.count == PhraseBankStore.maximumEntries)
        #expect(store.entries.first?.text.contains("number \(PhraseBankStore.maximumEntries + 2)") == true)
        #expect(store.entries.last?.text.contains("number 3") == true)
    }

    @Test func intensityPromptsRemainMeaningfullyDistinct() {
        let light = AIRewriteService.systemPrompt(for: .opening, voice: .concise, intensity: .light)
        let medium = AIRewriteService.systemPrompt(for: .opening, voice: .concise, intensity: .medium)
        let strong = AIRewriteService.systemPrompt(for: .opening, voice: .concise, intensity: .strong)
        #expect(light.contains("smallest useful edit"))
        #expect(medium.contains("clear, practical edit"))
        #expect(strong.contains("may reorder the targeted slice"))
        #expect(Set([light, medium, strong]).count == 3)
    }
}
