import Foundation
import Testing
@testable import Noum

@Suite("Coaching content sync journal")
struct CoachingContentSyncJournalTests {
    @Test("Pending work survives repository recreation and exact acknowledgement")
    func relaunchAndExactAcknowledgement() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let accountID = "firebase-relaunch"

        let firstJournal = CoachingContentSyncJournal(defaults: defaults)
        let mutation = try #require(firstJournal.enqueue(
            .profile,
            accountID: accountID
        ))
        #expect(firstJournal.status(for: accountID) == .pending(
            CoachingContentPendingSnapshot(documentIDs: [.profile])
        ))

        let relaunchedJournal = CoachingContentSyncJournal(defaults: defaults)
        #expect(relaunchedJournal.pendingMutations(for: accountID) == [mutation])
        #expect(relaunchedJournal.acknowledge(
            mutation,
            accountID: accountID
        ))
        #expect(relaunchedJournal.status(for: accountID) == .clean)
    }

    @Test("A stale completion cannot clear newer work for the same document")
    func staleAcknowledgementCannotClearNewerWork() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let accountID = "firebase-newest"
        let journal = CoachingContentSyncJournal(defaults: defaults)

        let older = try #require(journal.enqueue(
            .progression,
            accountID: accountID
        ))
        let newer = try #require(journal.enqueue(
            .progression,
            accountID: accountID
        ))

        #expect(newer.revision > older.revision)
        #expect(newer.mutationID != older.mutationID)
        #expect(!journal.acknowledge(older, accountID: accountID))
        #expect(journal.pendingMutations(for: accountID) == [newer])
        #expect(journal.acknowledge(newer, accountID: accountID))
        #expect(journal.status(for: accountID) == .clean)
    }

    @Test("Snapshot enqueue is deterministic, deduplicated, and account isolated")
    func deterministicSnapshotAndAccountIsolation() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let accountA = "firebase-a"
        let accountB = "firebase-b"
        let sessionA = try #require(UUID(
            uuidString: "00000000-0000-0000-0000-000000000001"
        ))
        let sessionB = try #require(UUID(
            uuidString: "00000000-0000-0000-0000-000000000002"
        ))
        let journal = CoachingContentSyncJournal(defaults: defaults)

        let mutations = journal.enqueue(
            [
                .session(sessionB),
                .profile,
                .session(sessionA),
                .progression,
                .session(sessionA)
            ],
            accountID: accountA
        )
        #expect(mutations.map(\.documentID) == [
            .profile,
            .progression,
            .session(sessionA),
            .session(sessionB)
        ])
        #expect(journal.status(for: accountB) == .clean)
        #expect(journal.enqueue(.profile, accountID: accountB) != nil)
        #expect(journal.status(for: accountA) == .pending(
            CoachingContentPendingSnapshot(documentIDs: [
                .profile,
                .progression,
                .session(sessionA),
                .session(sessionB)
            ])
        ))
        #expect(journal.status(for: accountB) == .pending(
            CoachingContentPendingSnapshot(documentIDs: [.profile])
        ))
    }

    @Test("Concurrent admissions serialize to one newest pending mutation")
    func concurrentAdmissionsRemainOrdered() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let accountID = "firebase-concurrent"
        let journal = CoachingContentSyncJournal(defaults: defaults)
        let collector = MutationCollector()

        DispatchQueue.concurrentPerform(iterations: 32) { _ in
            if let mutation = journal.enqueue(
                .profile,
                accountID: accountID
            ) {
                collector.append(mutation)
            }
        }

        let admitted = collector.values
        #expect(admitted.count == 32)
        #expect(Set(admitted.map(\.revision)).count == 32)
        let newest = try #require(admitted.max { $0.revision < $1.revision })
        #expect(journal.pendingMutations(for: accountID) == [newest])
    }

    @Test("Unreadable bytes fail closed and are never overwritten")
    func corruptionFailsClosed() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let accountID = "firebase-corrupt"
        let key = CoachingContentSyncJournal.storageKeyPrefix + accountID
        let corrupt = Data("not-json".utf8)
        defaults.set(corrupt, forKey: key)
        let journal = CoachingContentSyncJournal(defaults: defaults)

        #expect(journal.status(for: accountID) == .unreadable)
        #expect(journal.pendingMutations(for: accountID) == nil)
        #expect(journal.enqueue(.profile, accountID: accountID) == nil)
        #expect(defaults.data(forKey: key) == corrupt)
    }

    @Test("Hydration combines dirty documents and treats corruption as authoritative")
    func hydrationStatusCombination() throws {
        let sessionID = try #require(UUID(
            uuidString: "00000000-0000-0000-0000-000000000003"
        ))
        let profile = CoachingContentSyncJournalStatus.pending(
            CoachingContentPendingSnapshot(documentIDs: [.profile])
        )
        let sessions = CoachingContentSyncJournalStatus.pending(
            CoachingContentPendingSnapshot(documentIDs: [.session(sessionID)])
        )

        #expect(AuthManager.combinedCoachingContentJournalStatus(
            profile,
            sessions
        ) == .pending(CoachingContentPendingSnapshot(documentIDs: [
            .profile,
            .session(sessionID)
        ])))
        #expect(AuthManager.combinedCoachingContentJournalStatus(
            .clean,
            .clean
        ) == .clean)
        #expect(AuthManager.combinedCoachingContentJournalStatus(
            profile,
            .unreadable
        ) == .unreadable)
    }

    private func makeDefaults() throws -> UserDefaults {
        let suiteName = "CoachingContentSyncJournalTests.\(UUID().uuidString)"
        return try #require(UserDefaults(suiteName: suiteName))
    }

    private func clear(_ defaults: UserDefaults) {
        if let suiteName = defaults.volatileDomainNames.first(where: {
            $0.hasPrefix("CoachingContentSyncJournalTests.")
        }) {
            defaults.removePersistentDomain(forName: suiteName)
        }
        for key in defaults.dictionaryRepresentation().keys {
            defaults.removeObject(forKey: key)
        }
    }

    private final class MutationCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var storage: [PendingCoachingContentMutation] = []

        var values: [PendingCoachingContentMutation] {
            lock.lock()
            defer { lock.unlock() }
            return storage
        }

        func append(_ mutation: PendingCoachingContentMutation) {
            lock.lock()
            storage.append(mutation)
            lock.unlock()
        }
    }
}
