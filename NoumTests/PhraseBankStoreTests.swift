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

    @Test func capEvictionPublishesTheExactRemainingEntryIDs() throws {
        let suite = "PhraseBankStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var validSnapshots: [Set<UUID>] = []
        let store = PhraseBankStore(
            defaults: defaults,
            accountIDProvider: { "account-a" },
            entriesDidChange: { validSnapshots.append($0) }
        )
        var firstID: UUID?

        for index in 0...PhraseBankStore.maximumEntries {
            let entry = try #require(store.save(
                text: "Carry the decision line number \(index) into the room.",
                voice: .executive,
                weakness: .structure,
                intensity: .medium,
                now: Date(timeIntervalSince1970: TimeInterval(index))
            ))
            if index == 0 { firstID = entry.id }
        }

        let validIDs = try #require(validSnapshots.last)
        #expect(validIDs == Set(store.entries.map(\.id)))
        #expect(validIDs.count == PhraseBankStore.maximumEntries)
        #expect(firstID.map { !validIDs.contains($0) } == true)
    }

    @Test func loadFilteringPublishesOnlySafePersistedEntryIDs() throws {
        let suite = "PhraseBankStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let safe = PhraseBankEntry(
            text: "Lead with the recommendation, then give one reason.",
            voice: .executive,
            weakness: .opening,
            intensity: .medium
        )
        let unsafe = PhraseBankEntry(
            text: "Email jordan@example.com after the meeting.",
            voice: .warm,
            weakness: .closing,
            intensity: .light
        )
        defaults.set(
            try JSONEncoder().encode([safe, unsafe]),
            forKey: "\(PhraseBankStore.storageKeyPrefix).account-a"
        )
        var validSnapshots: [Set<UUID>] = []

        let store = PhraseBankStore(
            defaults: defaults,
            accountIDProvider: { "account-a" },
            entriesDidChange: { validSnapshots.append($0) }
        )

        #expect(store.entries.map(\.id) == [safe.id])
        #expect(validSnapshots.last == Set([safe.id]))
        let persisted = try #require(defaults.data(
            forKey: "\(PhraseBankStore.storageKeyPrefix).account-a"
        ))
        #expect(try JSONDecoder().decode([PhraseBankEntry].self, from: persisted).map(\.id) == [safe.id])
    }
}
