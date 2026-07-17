import Foundation
import Testing
import XCTest
@testable import Noum

@Suite("Local guest promotion journal")
struct LocalGuestPromotionJournalTests {
    private let requestID = UUID(
        uuidString: "4ad31417-8dc4-428f-913e-f38cc684a102"
    )!

    @Test("Journal phases are monotonic, durable, and target admitted only after commit")
    func journalPhases() throws {
        let storage = MemoryPromotionStorage()
        let repository = makeRepository(storage)
        var journal = try repository.beginOrResume(
            sourceAccountID: "local-guest-source",
            targetAccountID: "firebase-target"
        ).get()

        #expect(journal.phase == .authorityAcquired)
        #expect(!repository.isProviderWorkAllowed(for: "local-guest-source"))
        #expect(!repository.isProviderWorkAllowed(for: "firebase-target"))
        #expect(repository.advance(
            journal,
            to: .identityCommitted
        ) == .failure(.invalidPhaseTransition))

        journal = try repository.advance(journal, to: .dataCopied).get()
        journal = try repository.advance(journal, to: .identityCommitted).get()
        #expect(repository.isProviderWorkAllowed(for: "firebase-target"))
        #expect(!repository.isProviderWorkAllowed(for: "local-guest-source"))

        let relaunched = makeRepository(storage)
        #expect(relaunched.pendingLookup() == .present(journal))
        try relaunched.clearVerified(journal).get()
        #expect(relaunched.pendingLookup() == .missing)
        #expect(relaunched.isProviderWorkAllowed(for: "firebase-target"))
    }

    @Test("Corrupt or unreadable journal fails provider work closed")
    func corruptionFailsClosed() {
        let storage = MemoryPromotionStorage()
        storage.values[LocalGuestPromotionJournalRepository.activeKey] = "{}"
        let repository = makeRepository(storage)
        #expect(repository.pendingLookup() == .ambiguous)
        #expect(!repository.isProviderWorkAllowed(for: "firebase-target"))

        storage.unavailable = true
        #expect(repository.pendingLookup() == .ambiguous)
        #expect(!repository.isProviderWorkAllowed(for: "firebase-target"))
    }

    @Test("Only the exact source and newly minted target can resume")
    func exactIdentityResume() throws {
        let storage = MemoryPromotionStorage()
        let repository = makeRepository(storage)
        let journal = try repository.beginOrResume(
            sourceAccountID: "local-guest-source",
            targetAccountID: "firebase-target"
        ).get()
        #expect(try repository.beginOrResume(
            sourceAccountID: "local-guest-source",
            targetAccountID: "firebase-target"
        ).get() == journal)
        #expect(repository.beginOrResume(
            sourceAccountID: "local-guest-other",
            targetAccountID: "firebase-target"
        ) == .failure(.activePromotionMismatch))
        #expect(repository.beginOrResume(
            sourceAccountID: "not-local",
            targetAccountID: "firebase-target"
        ) == .failure(.invalidSource))
        #expect(repository.beginOrResume(
            sourceAccountID: "local-guest-source",
            targetAccountID: "local-guest-other"
        ) == .failure(.invalidTarget))
    }

    @Test("Journal persistence and removal failures never masquerade as completion")
    func storageFailuresFailClosed() throws {
        let writeFailure = MemoryPromotionStorage()
        writeFailure.writeSucceeds = false
        #expect(makeRepository(writeFailure).beginOrResume(
            sourceAccountID: "local-guest-source",
            targetAccountID: "firebase-target"
        ) == .failure(.persistenceFailed))

        let removalFailure = MemoryPromotionStorage()
        let repository = makeRepository(removalFailure)
        let journal = try repository.beginOrResume(
            sourceAccountID: "local-guest-source",
            targetAccountID: "firebase-target"
        ).get()
        removalFailure.removeSucceeds = false
        switch repository.clearVerified(journal) {
        case .failure(let error):
            #expect(error == .removalFailed)
        case .success:
            Issue.record("Journal removal unexpectedly succeeded")
        }
        #expect(repository.pendingLookup() == .present(journal))
        #expect(!repository.isProviderWorkAllowed(for: "firebase-target"))
    }

    @Test("Committed target is authoritative during relaunch recovery")
    func committedTargetAuthority() {
        #expect(!AuthManager.localGuestPromotionTargetIsAuthoritative(
            phase: .authorityAcquired
        ))
        #expect(!AuthManager.localGuestPromotionTargetIsAuthoritative(
            phase: .dataCopied
        ))
        #expect(AuthManager.localGuestPromotionTargetIsAuthoritative(
            phase: .identityCommitted
        ))
    }

    private func makeRepository(
        _ storage: MemoryPromotionStorage
    ) -> LocalGuestPromotionJournalRepository {
        LocalGuestPromotionJournalRepository(
            storage: storage,
            makeRequestID: { requestID }
        )
    }

    private final class MemoryPromotionStorage:
        LocalGuestPromotionJournalStorage {
        var values: [String: String] = [:]
        var unavailable = false
        var writeSucceeds = true
        var removeSucceeds = true

        func read(key: String) -> LocalGuestPromotionJournalStorageRead {
            if unavailable { return .unavailable }
            return values[key].map(
                LocalGuestPromotionJournalStorageRead.value
            ) ?? .missing
        }

        func write(_ value: String, key: String) -> Bool {
            guard writeSucceeds else { return false }
            values[key] = value
            return true
        }

        func remove(key: String) -> Bool {
            guard removeSucceeds else { return false }
            values.removeValue(forKey: key)
            return true
        }
    }
}

@Suite("Coaching content sync authority")
struct CoachingContentSyncAuthorityTests {
    private func isAllowed(
        requestedAccountID: String = "firebase-a",
        requestedProviderRawValue: String = "guest",
        sourceLifecycleGeneration: UInt64? = 7,
        currentAccountID: String? = "firebase-a",
        currentProviderRawValue: String? = "guest",
        currentLifecycleGeneration: UInt64 = 7,
        hydrationReady: Bool = true,
        providerWorkAllowed: Bool = true,
        cloudProcessingAllowed: Bool = true,
        firebaseIsConfigured: Bool = true,
        firebaseUID: String? = "firebase-a"
    ) -> Bool {
        BackendSyncManager.coachingContentSyncAuthorityMatches(
            requestedAccountID: requestedAccountID,
            requestedProviderRawValue: requestedProviderRawValue,
            sourceLifecycleGeneration: sourceLifecycleGeneration,
            currentAccountID: currentAccountID,
            currentProviderRawValue: currentProviderRawValue,
            currentLifecycleGeneration: currentLifecycleGeneration,
            hydrationReady: hydrationReady,
            providerWorkAllowed: providerWorkAllowed,
            cloudProcessingAllowed: cloudProcessingAllowed,
            firebaseIsConfigured: firebaseIsConfigured,
            firebaseUID: firebaseUID
        )
    }

    @Test("Only the exact hydrated consented Firebase identity can write")
    func exactAuthority() {
        #expect(isAllowed())
        #expect(!isAllowed(currentAccountID: "firebase-b"))
        #expect(!isAllowed(currentProviderRawValue: "apple"))
        #expect(!isAllowed(currentLifecycleGeneration: 8))
        #expect(!isAllowed(hydrationReady: false))
        #expect(!isAllowed(providerWorkAllowed: false))
        #expect(!isAllowed(cloudProcessingAllowed: false))
        #expect(!isAllowed(firebaseUID: "firebase-b"))
        #expect(!isAllowed(firebaseUID: nil))
    }

    @Test("A queued account-A payload cannot inherit account B authority")
    func queuedPayloadCannotCrossAccounts() {
        #expect(!isAllowed(
            currentAccountID: "firebase-b",
            currentProviderRawValue: "google",
            firebaseUID: "firebase-b"
        ))
    }

    @Test("Legacy REST still requires exact durable identity and consent")
    func legacyRestIdentityBinding() {
        #expect(isAllowed(
            firebaseIsConfigured: false,
            firebaseUID: nil
        ))
        #expect(!isAllowed(
            currentAccountID: "firebase-b",
            firebaseIsConfigured: false,
            firebaseUID: nil
        ))
        #expect(!isAllowed(
            cloudProcessingAllowed: false,
            firebaseIsConfigured: false,
            firebaseUID: nil
        ))
    }

    @Test("A durable local guest never becomes backend-writable")
    func localGuestRemainsLocal() {
        #expect(!isAllowed(
            requestedAccountID: "local-guest-a",
            currentAccountID: "local-guest-a",
            firebaseUID: "local-guest-a"
        ))
    }

    @Test("A failed revocation cannot reuse an older persisted allow receipt")
    func failedRevocationFailsClosed() {
        let allow = CloudProcessingConsent(
            decision: .allowed,
            decidedAt: Date(timeIntervalSince1970: 1_720_000_000),
            disclosureVersion: AISettingsManager.disclosureVersion,
            processorManifestVersion:
                AISettingsManager.processorManifestVersion
        )
        let decline = CloudProcessingConsent(
            decision: .declined,
            decidedAt: allow.decidedAt.addingTimeInterval(1),
            disclosureVersion: AISettingsManager.disclosureVersion,
            processorManifestVersion:
                AISettingsManager.processorManifestVersion
        )

        #expect(AISettingsManager.durableConsentReceiptIsUsable(
            published: allow,
            persisted: allow
        ))
        #expect(!AISettingsManager.durableConsentReceiptIsUsable(
            published: nil,
            persisted: allow
        ))
        #expect(!AISettingsManager.durableConsentReceiptIsUsable(
            published: decline,
            persisted: decline
        ))
    }
}

@MainActor
final class LocalGuestPromotionRegistryTests: XCTestCase {
    func testCopyIsExactIdempotentAndAccountIsolated() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let source = "local-guest-source"
        let target = "firebase-target"
        defaults.set(Data([0, 1, 255]), forKey: "coachMemory.\(source)")
        defaults.set(7, forKey: "aiRateLimiter.\(source).coachRead.2026-07")
        defaults.set("other", forKey: "coachMemory.other-account")
        let registry = try AccountDataRegistry(
            participants: [],
            defaults: defaults
        )

        let first = try registry.copyAccountScopedDefaultsForPromotion(
            from: source,
            to: target
        )
        let second = try registry.copyAccountScopedDefaultsForPromotion(
            from: source,
            to: target
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(
            defaults.data(forKey: "coachMemory.\(target)"),
            Data([0, 1, 255])
        )
        XCTAssertEqual(
            defaults.integer(forKey: "aiRateLimiter.\(target).coachRead.2026-07"),
            7
        )
        XCTAssertEqual(defaults.string(forKey: "coachMemory.other-account"), "other")
        XCTAssertNotNil(defaults.object(forKey: "coachMemory.\(source)"))
    }

    func testConflictingTargetFailsBeforeAnyNewWrites() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let source = "local-guest-source"
        let target = "firebase-target"
        defaults.set("source A", forKey: "a.\(source)")
        defaults.set("source B", forKey: "b.\(source)")
        defaults.set("different", forKey: "b.\(target)")
        let registry = try AccountDataRegistry(
            participants: [],
            defaults: defaults
        )

        XCTAssertThrowsError(try registry.copyAccountScopedDefaultsForPromotion(
            from: source,
            to: target
        )) { error in
            XCTAssertEqual(
                error as? AccountDataRegistryError,
                .promotionTargetConflict("b.\(target)")
            )
        }
        XCTAssertNil(defaults.object(forKey: "a.\(target)"))
        XCTAssertEqual(defaults.string(forKey: "b.\(target)"), "different")
    }

    func testDerivedRemoteBookkeepingIsDiscardedButUserEvidenceMoves() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let source = "local-guest-source"
        let target = "firebase-target"
        defaults.set("evidence", forKey: "recommendation.outcomes.\(source)")
        defaults.set(9, forKey: "recommendation.remoteRevision.\(source)")
        defaults.set("cache", forKey: "homeRecommendation.\(source).fingerprint")
        defaults.set("gold", forKey: "league.lastSeenTier.\(source)")
        defaults.set("outbox", forKey: "coachingContent.syncJournal.\(source)")
        let registry = try AccountDataRegistry(
            participants: [],
            defaults: defaults
        )

        let report = try registry.copyAccountScopedDefaultsForPromotion(
            from: source,
            to: target
        )
        XCTAssertEqual(report.discoveredSourceKeys, 5)
        XCTAssertEqual(report.copiedKeys, 1)
        XCTAssertEqual(report.skippedDerivedKeys, 4)
        XCTAssertEqual(
            defaults.string(forKey: "recommendation.outcomes.\(target)"),
            "evidence"
        )
        XCTAssertNil(defaults.object(forKey: "recommendation.remoteRevision.\(target)"))
        XCTAssertNil(defaults.object(forKey: "homeRecommendation.\(target).fingerprint"))
        XCTAssertNil(defaults.object(forKey: "league.lastSeenTier.\(target)"))
        XCTAssertNil(defaults.object(forKey: "coachingContent.syncJournal.\(target)"))
    }

    func testAsyncChallengeRebindsOnlyThePromotedParticipant() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let source = "local-guest-source"
        let target = "firebase-target"
        let challenge = AsyncChallenge(
            id: UUID(),
            prompt: "Make the opening direct.",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            expiresAt: Date(timeIntervalSince1970: 1_700_086_400),
            creatorID: UUID(),
            creatorName: "Me",
            creatorAccountID: source,
            opponentID: UUID(),
            opponentName: "Peer",
            opponentAccountID: "peer-account"
        )
        defaults.set(
            try JSONEncoder().encode([challenge]),
            forKey: "NoumAsyncChallenges.\(source)"
        )
        let registry = try AccountDataRegistry(
            participants: [],
            defaults: defaults
        )

        _ = try registry.copyAccountScopedDefaultsForPromotion(
            from: source,
            to: target
        )
        let copied = try XCTUnwrap(defaults.data(
            forKey: "NoumAsyncChallenges.\(target)"
        ))
        let decoded = try JSONDecoder().decode([AsyncChallenge].self, from: copied)
        XCTAssertEqual(decoded.first?.creatorAccountID, target)
        XCTAssertEqual(decoded.first?.opponentAccountID, "peer-account")
    }

    func testRetirementRemovesOnlyExactAccountDefaults() throws {
        let defaults = try makeDefaults()
        defer { clear(defaults) }
        let source = "local-guest-source"
        defaults.set("owned", forKey: "practiceSessions.\(source)")
        defaults.set("bucket", forKey: "aiRateLimiter.\(source).coach")
        defaults.set("other", forKey: "practiceSessions.other")
        defaults.set("legacy", forKey: "drillHistory")
        let registry = try AccountDataRegistry(
            participants: [],
            defaults: defaults
        )

        try registry.removeRetiredAccountDefaults(for: source)
        XCTAssertNil(defaults.object(forKey: "practiceSessions.\(source)"))
        XCTAssertNil(defaults.object(forKey: "aiRateLimiter.\(source).coach"))
        XCTAssertEqual(defaults.string(forKey: "practiceSessions.other"), "other")
        XCTAssertEqual(defaults.string(forKey: "drillHistory"), "legacy")
    }

    private func makeDefaults() throws -> UserDefaults {
        try XCTUnwrap(UserDefaults(
            suiteName: "LocalGuestPromotionTests.\(UUID().uuidString)"
        ))
    }

    private func clear(_ defaults: UserDefaults) {
        defaults.dictionaryRepresentation().keys.forEach(
            defaults.removeObject(forKey:)
        )
    }
}
