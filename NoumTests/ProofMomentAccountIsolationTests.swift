import Foundation
import Testing
@testable import Noum

@MainActor
@Suite("Proof Moment account/source isolation")
struct ProofMomentAccountIsolationTests {
    private final class LeaseState {
        var accountID: String?
        var lifecycle: UInt64
        var isReady: Bool
        var loadedAccountScope: String?
        var storeGeneration: UInt64
        var liveSession: PracticeSession?

        init(
            accountID: String?,
            lifecycle: UInt64,
            isReady: Bool = true,
            loadedAccountScope: String? = nil,
            storeGeneration: UInt64 = 1,
            liveSession: PracticeSession?
        ) {
            self.accountID = accountID
            self.lifecycle = lifecycle
            self.isReady = isReady
            self.loadedAccountScope = loadedAccountScope ?? accountID
            self.storeGeneration = storeGeneration
            self.liveSession = liveSession
        }

        @MainActor
        func makeStore(defaults: UserDefaults) -> ProofMomentStore {
            ProofMomentStore(
                defaults: defaults,
                accountIDProvider: { self.accountID },
                accountLifecycleGenerationProvider: { self.lifecycle },
                accountIsReadyProvider: { self.isReady },
                sourceProvider: { id in
                    guard let accountScope = self.loadedAccountScope,
                          let session = self.liveSession,
                          session.id == id else {
                        return nil
                    }
                    return AccountScopedPracticeSession(
                        epoch: PracticeSessionStoreEpoch(
                            accountScope: accountScope,
                            generation: self.storeGeneration
                        ),
                        session: session
                    )
                }
            )
        }
    }

    @Test("Account switch rejects a pending proof without writing the destination archive")
    func accountSwitchRejectsCommit() throws {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let state = LeaseState(
            accountID: "alpha",
            lifecycle: 1,
            liveSession: session()
        )
        let store = state.makeStore(defaults: suite)
        let source = try #require(state.liveSession)
        let request = try #require(store.generationRequest(for: input(for: source)))

        state.accountID = "beta"
        state.lifecycle = 2
        state.loadedAccountScope = "beta"
        state.storeGeneration = 2

        #expect(store.record(
            proof(for: source),
            expected: request.saveToken,
            voiceAtGeneration: .authoritative
        ) == nil)
        #expect(store.records.isEmpty)
        #expect(suite.data(forKey: "proofMoment.archive.beta") == nil)
        #expect(!store.tokenIsCurrent(request.saveToken))
    }

    @Test("Rapid return to the same account still rejects the old lifecycle")
    func lifecycleEpochRejectsCommit() throws {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let source = session()
        let state = LeaseState(
            accountID: "alpha",
            lifecycle: 7,
            liveSession: source
        )
        let store = state.makeStore(defaults: suite)
        let request = try #require(store.generationRequest(for: input(for: source)))

        state.lifecycle = 8

        #expect(store.record(proof(for: source), expected: request.saveToken) == nil)
        #expect(store.records.isEmpty)
        #expect(!store.tokenIsCurrent(request.saveToken))
    }

    @Test("Source mutation and deletion reject the pending proof")
    func sourceDriftRejectsCommit() throws {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let source = session()
        let state = LeaseState(
            accountID: "alpha",
            lifecycle: 3,
            liveSession: source
        )
        let store = state.makeStore(defaults: suite)
        let request = try #require(store.generationRequest(for: input(for: source)))

        state.liveSession = session(
            id: source.id,
            transcript: "The source transcript changed while the provider request was pending."
        )
        #expect(store.record(proof(for: source), expected: request.saveToken) == nil)
        #expect(!store.tokenIsCurrent(request.saveToken))

        state.liveSession = nil
        #expect(store.record(proof(for: source), expected: request.saveToken) == nil)
        #expect(store.records.isEmpty)
    }

    @Test("An unchanged account and exact source commit idempotently")
    func unchangedTokenCommitsOnce() throws {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let source = session()
        let state = LeaseState(
            accountID: "alpha",
            lifecycle: 11,
            liveSession: source
        )
        let store = state.makeStore(defaults: suite)
        let request = try #require(store.generationRequest(for: input(for: source)))
        let first = proof(for: source, claim: "First grounded claim.")
        let replacement = proof(for: source, claim: "Replacement grounded claim.")

        #expect(store.record(first, expected: request.saveToken, voiceAtGeneration: .executive) != nil)
        #expect(store.record(replacement, expected: request.saveToken, voiceAtGeneration: .executive) != nil)
        #expect(store.records.count == 1)
        #expect(store.records.first?.proof.claim == "Replacement grounded claim.")
        #expect(store.records.first?.sessionID == source.id)
        #expect(store.tokenIsCurrent(request.saveToken))
    }

    @Test("Archive CAS rejects a quote or date outside the leased source")
    func archiveRevalidatesProofGrounding() throws {
        let source = session()
        let state = LeaseState(
            accountID: "alpha",
            lifecycle: 1,
            liveSession: source
        )
        let store = state.makeStore(
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let request = try #require(store.generationRequest(for: input(for: source)))
        let fabricated = ProofMoment(
            quote: "Words that were never spoken.",
            technique: "Direct Move",
            claim: "A claim.",
            sessionDate: source.date,
            isAIBacked: true,
            generatedAt: Date()
        )
        let wrongDate = ProofMoment(
            quote: "One clear decision",
            technique: "Direct Move",
            claim: "A claim.",
            sessionDate: source.date.addingTimeInterval(1),
            isAIBacked: true,
            generatedAt: Date()
        )

        #expect(store.record(fabricated, expected: request.saveToken) == nil)
        #expect(store.record(wrongDate, expected: request.saveToken) == nil)
        #expect(store.records.isEmpty)
    }

    @Test("Signed-out transition cannot lease an old account row or write guest archive")
    func signedOutTransitionRejectsStaleRow() {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let source = session()
        let state = LeaseState(
            accountID: nil,
            lifecycle: 2,
            isReady: true,
            loadedAccountScope: "alpha",
            liveSession: source
        )
        let store = state.makeStore(defaults: suite)

        #expect(store.generationRequest(for: input(for: source)) == nil)
        #expect(store.records.isEmpty)
        #expect(suite.data(forKey: "proofMoment.archive.guest") == nil)
    }

    @Test("New identity before session reload cannot relabel the prior account source")
    func preReloadIdentityTransitionRejectsStaleRow() {
        let source = session()
        let state = LeaseState(
            accountID: "beta",
            lifecycle: 2,
            isReady: false,
            loadedAccountScope: "alpha",
            liveSession: source
        )
        let store = state.makeStore(
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )

        #expect(store.generationRequest(for: input(for: source)) == nil)

        state.isReady = true
        #expect(store.generationRequest(for: input(for: source)) == nil)
    }

    @Test("A captured request cannot be relabelled after another account hydrates an identical row")
    func capturedRequestRejectsIdenticalDestinationRow() throws {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let source = session()
        let state = LeaseState(
            accountID: "alpha",
            lifecycle: 4,
            storeGeneration: 8,
            liveSession: source
        )
        let store = state.makeStore(defaults: suite)
        let request = try #require(store.generationRequest(for: input(for: source)))

        state.accountID = "beta"
        state.lifecycle = 5
        state.loadedAccountScope = "beta"
        state.storeGeneration = 9

        #expect(store.record(proof(for: source), expected: request.saveToken) == nil)
        #expect(!store.tokenIsCurrent(request.saveToken))
        #expect(store.records.isEmpty)
        #expect(suite.data(forKey: "proofMoment.archive.beta") == nil)
    }

    @Test("A same-account session-store reload invalidates the prior row epoch")
    func sessionStoreEpochRejectsOldRequest() throws {
        let source = session()
        let state = LeaseState(
            accountID: "alpha",
            lifecycle: 6,
            storeGeneration: 12,
            liveSession: source
        )
        let store = state.makeStore(
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        let request = try #require(store.generationRequest(for: input(for: source)))

        state.storeGeneration = 13

        #expect(store.record(proof(for: source), expected: request.saveToken) == nil)
        #expect(!store.tokenIsCurrent(request.saveToken))
    }

    @Test("Cache identity separates account, lifecycle, and exact source revision")
    func cacheIdentityIsFullyScoped() {
        let original = session()
        let revised = session(
            id: original.id,
            transcript: original.transcript + " Revised source."
        )
        let originalInput = input(for: original)
        let revisedInput = input(for: revised)

        let alpha = ProofMomentService.cacheIdentity(
            for: originalInput,
            accountScope: "alpha",
            accountLifecycleGeneration: 1
        )
        let beta = ProofMomentService.cacheIdentity(
            for: originalInput,
            accountScope: "beta",
            accountLifecycleGeneration: 1
        )
        let nextEpoch = ProofMomentService.cacheIdentity(
            for: originalInput,
            accountScope: "alpha",
            accountLifecycleGeneration: 2
        )
        let sourceRevision = ProofMomentService.cacheIdentity(
            for: revisedInput,
            accountScope: "alpha",
            accountLifecycleGeneration: 1
        )
        let storeEpoch = ProofMomentService.cacheIdentity(
            for: originalInput,
            accountScope: "alpha",
            accountLifecycleGeneration: 1,
            sessionStoreGeneration: 1
        )

        #expect(Set([alpha, beta, nextEpoch, sourceRevision, storeEpoch]).count == 5)
        #expect(ProofMomentService.cacheKey(alpha, belongsTo: original.id))
        #expect(ProofMomentService.cacheKey(sourceRevision, belongsTo: original.id))
    }

    @Test("A delayed old lifecycle hook cannot clear newer cache entries")
    func lifecycleInvalidationOrderingFailsClosed() {
        #expect(ProofMomentService.shouldApplyLifecycleInvalidation(
            currentGeneration: 5,
            cachedGenerations: [4, 5]
        ))
        #expect(!ProofMomentService.shouldApplyLifecycleInvalidation(
            currentGeneration: 5,
            cachedGenerations: [6]
        ))
    }

    private func session(
        id: UUID = UUID(),
        transcript: String = "One clear decision gives the team a concrete direction for the next quarter."
    ) -> PracticeSession {
        PracticeSession(
            id: id,
            transcript: transcript,
            fillerWordCount: 0,
            duration: 30,
            date: Date(timeIntervalSince1970: 1_800_000_000),
            mode: .timed,
            score: 8
        )
    }

    private func input(for session: PracticeSession) -> ProofMomentInput {
        ProofMomentInput(
            session: session,
            voice: .authoritative,
            goalParaphrase: "Lead with the decision.",
            baselineFillerRate: 1.2,
            baselinePace: 132
        )
    }

    private func proof(
        for session: PracticeSession,
        claim: String = "This line states one observable decision."
    ) -> ProofMoment {
        ProofMoment(
            quote: "One clear decision",
            technique: "Direct Move",
            claim: claim,
            sessionDate: session.date,
            isAIBacked: true,
            generatedAt: Date()
        )
    }
}
