import Foundation
import Testing
@testable import Noum

@Suite("Drill history integrity", .serialized)
struct DrillHistoryIntegrityTests {
    @Test("History is isolated by account")
    func accountIsolation() throws {
        try withDefaults { defaults in
            var accountID = "account-a"
            let store = DrillHistoryStore(
                defaults: defaults,
                accountIDProvider: { accountID }
            )
            let accountAEntry = verifiedEntry(
                outcomeID: UUID(),
                variationID: "filler.account-a"
            )
            #expect(store.record(accountAEntry))

            accountID = "account-b"
            store.reloadForCurrentAccount()
            #expect(store.entries.isEmpty)

            let accountBEntry = verifiedEntry(
                outcomeID: UUID(),
                variationID: "pace.account-b"
            )
            #expect(store.record(accountBEntry))

            accountID = "account-a"
            store.reloadForCurrentAccount()
            #expect(store.entries == [accountAEntry])

            accountID = "account-b"
            store.reloadForCurrentAccount()
            #expect(store.entries == [accountBEntry])
        }
    }

    @Test("The device-global legacy key is never imported")
    func legacyGlobalHistoryIsQuarantined() throws {
        try withDefaults { defaults in
            let globalEntry = verifiedEntry(
                outcomeID: UUID(),
                variationID: "legacy.global"
            )
            defaults.set(
                try JSONEncoder().encode([globalEntry]),
                forKey: DrillHistoryStore.storageKeyPrefix
            )

            let store = DrillHistoryStore(
                defaults: defaults,
                accountIDProvider: { "account-a" }
            )

            #expect(store.entries.isEmpty)
            #expect(defaults.data(forKey: DrillHistoryStore.storageKeyPrefix) != nil)
            #expect(defaults.data(forKey: scopedKey("account-a")) == nil)
        }
    }

    @Test("Unverified rows in an account archive are filtered fail closed")
    func accountScopedLegacyRowsAreFiltered() throws {
        try withDefaults { defaults in
            let legacy = DrillHistoryStore.Entry(
                variationId: "legacy.account-row",
                skillArea: .fillerReduction,
                succeeded: true,
                sessionId: UUID()
            )
            defaults.set(
                try JSONEncoder().encode([legacy]),
                forKey: scopedKey("account-a")
            )

            let store = DrillHistoryStore(
                defaults: defaults,
                accountIDProvider: { "account-a" }
            )

            #expect(store.entries.isEmpty)
            let rewrittenData = try #require(defaults.data(forKey: scopedKey("account-a")))
            let rewritten = try JSONDecoder().decode(
                [DrillHistoryStore.Entry].self,
                from: rewrittenData
            )
            #expect(rewritten.isEmpty)
        }
    }

    @Test("Invalid terminal evidence is rejected before mutation")
    func invalidEvidenceIsRejected() throws {
        try withDefaults { defaults in
            let store = DrillHistoryStore(
                defaults: defaults,
                accountIDProvider: { "account-a" }
            )
            let invalidEntries = [
                verifiedEntry(
                    outcomeID: UUID(),
                    variationID: "invalid.words",
                    wordCount: MiniDrillCompletionEvidence.minimumWordCount - 1
                ),
                verifiedEntry(
                    outcomeID: UUID(),
                    variationID: "invalid.duration",
                    duration: MiniDrillCompletionEvidence.minimumDuration - 0.1
                ),
                verifiedEntry(
                    outcomeID: UUID(),
                    variationID: "invalid.nonfinite-duration",
                    duration: .nan
                ),
                verifiedEntry(
                    outcomeID: UUID(),
                    variationID: "invalid.xp",
                    awardedXP: 0
                ),
                verifiedEntry(
                    outcomeID: UUID(),
                    variationID: "invalid.excessive-xp",
                    awardedXP: 81
                ),
                verifiedEntry(
                    outcomeID: UUID(),
                    variationID: "   "
                ),
            ]

            for entry in invalidEntries {
                #expect(!store.record(entry))
            }

            #expect(store.entries.isEmpty)
            #expect(defaults.data(forKey: scopedKey("account-a")) == nil)
        }
    }

    @Test("A duplicate outcome is rejected without replacing the first receipt")
    func duplicateOutcomeIsRejectedBeforeMutation() throws {
        try withDefaults { defaults in
            let outcomeID = UUID()
            let store = DrillHistoryStore(
                defaults: defaults,
                accountIDProvider: { "account-a" }
            )
            let original = verifiedEntry(
                outcomeID: outcomeID,
                variationID: "filler.original",
                date: Date(timeIntervalSince1970: 10),
                awardedXP: 33
            )
            let duplicate = verifiedEntry(
                outcomeID: outcomeID,
                variationID: "filler.duplicate",
                date: Date(timeIntervalSince1970: 20),
                awardedXP: 80
            )

            #expect(store.record(original))
            let persistedBeforeDuplicate = defaults.data(forKey: scopedKey("account-a"))
            #expect(!store.record(duplicate))

            #expect(store.entries == [original])
            #expect(defaults.data(forKey: scopedKey("account-a")) == persistedBeforeDuplicate)
        }
    }

    @Test("Verified receipts persist and reload newest first")
    func persistenceAndReload() throws {
        try withDefaults { defaults in
            let older = verifiedEntry(
                outcomeID: UUID(),
                variationID: "filler.older",
                date: Date(timeIntervalSince1970: 10)
            )
            let newer = verifiedEntry(
                outcomeID: UUID(),
                variationID: "filler.newer",
                date: Date(timeIntervalSince1970: 20)
            )
            let writer = DrillHistoryStore(
                defaults: defaults,
                accountIDProvider: { "account-a" }
            )
            #expect(writer.record(older))
            #expect(writer.record(newer))

            let reader = DrillHistoryStore(
                defaults: defaults,
                accountIDProvider: { "account-a" }
            )
            #expect(reader.entries == [newer, older])
            #expect(reader.currentStreak(for: .fillerReduction) == 2)
            #expect(reader.streakAfterRecording(for: .fillerReduction, succeeded: true) == 3)
            #expect(reader.streakAfterRecording(for: .fillerReduction, succeeded: false) == 0)
        }
    }

    @Test("Ending a session clears memory without deleting account history")
    func endSessionDoesNotDeleteHistory() throws {
        try withDefaults { defaults in
            let entry = verifiedEntry(
                outcomeID: UUID(),
                variationID: "filler.persisted"
            )
            let store = DrillHistoryStore(
                defaults: defaults,
                accountIDProvider: { "account-a" }
            )
            #expect(store.record(entry))
            let persistedBeforeEnd = defaults.data(forKey: scopedKey("account-a"))

            store.endSession()

            #expect(store.entries.isEmpty)
            #expect(defaults.data(forKey: scopedKey("account-a")) == persistedBeforeEnd)

            store.reloadForCurrentAccount()
            #expect(store.entries == [entry])
        }
    }

    @Test("History remains capped at thirty receipts")
    func capacityIsBoundedNewestFirst() throws {
        try withDefaults { defaults in
            let store = DrillHistoryStore(
                defaults: defaults,
                accountIDProvider: { "account-a" }
            )

            for index in 0..<(DrillHistoryStore.capacity + 3) {
                #expect(store.record(verifiedEntry(
                    outcomeID: UUID(),
                    variationID: "filler.\(index)",
                    date: Date(timeIntervalSince1970: TimeInterval(index))
                )))
            }

            #expect(store.entries.count == DrillHistoryStore.capacity)
            #expect(store.entries.first?.variationId == "filler.32")
            #expect(store.entries.last?.variationId == "filler.3")
        }
    }

    private func withDefaults(
        _ body: (UserDefaults) throws -> Void
    ) throws {
        let suite = "DrillHistoryIntegrityTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    private func verifiedEntry(
        outcomeID: UUID,
        variationID: String,
        date: Date = Date(timeIntervalSince1970: 100),
        wordCount: Int = 12,
        duration: TimeInterval = 8,
        awardedXP: Int = 33
    ) -> DrillHistoryStore.Entry {
        DrillHistoryStore.Entry.verified(
            outcomeID: outcomeID,
            variationId: variationID,
            skillArea: .fillerReduction,
            date: date,
            succeeded: true,
            parentSessionId: UUID(),
            terminalWordCount: wordCount,
            recorderDuration: duration,
            awardedXP: awardedXP
        )
    }

    private func scopedKey(_ accountID: String) -> String {
        "\(DrillHistoryStore.storageKeyPrefix).\(accountID)"
    }
}
