import CryptoKit
import Foundation
import Testing
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif
@testable import Noum

@Suite("Social lifecycle integrity")
struct SocialLifecycleIntegrityTests {
    @Test("Operation contexts require both account and generation")
    func operationContextMatchesBothDimensions() {
        let context = SocialAccountOperationContext(accountID: "account-a", generation: 7)

        #expect(context.matches(accountID: "account-a", generation: 7))
        #expect(!context.matches(accountID: "account-b", generation: 7))
        #expect(!context.matches(accountID: "account-a", generation: 8))
        #expect(!context.matches(accountID: nil, generation: 7))
    }

    @Test("Release-disabled capabilities have stable user-facing explanations")
    func releaseCapabilitiesAreStableAndUnavailable() {
        #expect(!SocialReleaseCapabilities.peerProgress.isAvailable)
        #expect(!SocialReleaseCapabilities.friendProfiles.isAvailable)
        #expect(!SocialReleaseCapabilities.friendConnections.isAvailable)
        #expect(!SocialReleaseCapabilities.speakOffs.isAvailable)
        #expect(!SocialReleaseCapabilities.competitiveObservation.isAvailable)
        #expect(!SocialReleaseCapabilities.peerProgress.message.isEmpty)
        #expect(!SocialReleaseCapabilities.friendProfiles.message.isEmpty)
        #expect(!SocialReleaseCapabilities.friendConnections.message.isEmpty)
        #expect(!SocialReleaseCapabilities.speakOffs.message.isEmpty)
        #expect(!SocialReleaseCapabilities.competitiveObservation.message.isEmpty)
    }

    @Test("Disabled social actions fail before Firebase configuration is consulted")
    func disabledActionsFailBeforeNetwork() async {
        let challengeRequest = CreateChallengeRequest(
            challengeID: challengeID,
            opponentAccountID: "account-b",
            prompt: prompt
        )

        do {
            _ = try await BackendSyncManager.shared.createChallenge(challengeRequest)
            Issue.record("Disabled speak-offs must not reach the callable")
        } catch {
            #expect(error as? SocialAuthorityError == .friendAuthorizationUnavailable)
        }

        do {
            _ = try await BackendSyncManager.shared.fetchPeerProfile(accountID: "account-b")
            Issue.record("Disabled friend profiles must not reach the callable")
        } catch {
            #expect(error as? SocialAuthorityError == .friendAuthorizationUnavailable)
        }

        do {
            _ = try await BackendSyncManager.shared.fetchLeagueMembers(limit: 20)
            Issue.record("Disabled league reads must not reach the callable")
        } catch {
            #expect(error as? SocialAuthorityError == .trustedSocialStateUnavailable)
        }
    }

    @Test("Disabled backend challenge reads stop before Firestore")
    func disabledBackendChallengeReadStopsBeforeFirestore() async {
        let result = await BackendSyncManager.shared.fetchAsyncChallenges(
            forParticipant: "account-a"
        )

        #expect(result == .capabilityUnavailable)
    }

    @Test("Disabled challenge refresh never invokes its backend fetcher")
    @MainActor
    func disabledManagerChallengeReadStopsBeforeFetcher() async {
        let probe = ChallengeRefreshProbe()

        await ChallengesManager.shared.refreshFromBackend { participantID in
            await probe.record(participantID: participantID)
            return .unavailable
        }

        let callCount = await probe.callCount
        #expect(callCount == 0)
    }

    @Test("Replacement peer read contracts expose no client authority fields")
    func replacementReadContractsAreNarrow() throws {
        let peer = try jsonObject(GetPeerProfileRequest(accountID: "account-b"))
        let league = try jsonObject(ListLeagueMembersRequest(limit: 20))

        #expect(BackendSyncManager.getPeerProfileFunctionName == "getPeerProfile")
        #expect(BackendSyncManager.listLeagueMembersFunctionName == "listLeagueMembers")
        #expect(Set(peer.keys) == ["schemaVersion", "accountID"])
        #expect(Set(league.keys) == ["schemaVersion", "limit"])
        #expect(peer["bucket"] == nil)
        #expect(league["bucket"] == nil)
        #expect(league["rating"] == nil)
        #expect(league["week"] == nil)
    }

    @Test("Only the caller-private result hydrates before both speakers submit")
    func ownSubmissionHydrationIsPrivate() throws {
        let challenge = try ChallengeDocumentHydrator.hydrate(
            metadata: metadata(),
            ownSubmission: ownSubmission(side: .creator),
            combinedResult: nil,
            accountID: "account-a"
        )

        #expect(challenge.creatorScore == 8)
        #expect(challenge.creatorDuration == 42)
        #expect(challenge.creatorReaction == .clap)
        #expect(challenge.opponentScore == nil)
        #expect(challenge.opponentDuration == nil)
        #expect(challenge.opponentReaction == nil)
        #expect(!challenge.bothHavePlayed)
    }

    @Test("A private submission for the other side is rejected")
    func opponentSubmissionPathCannotBeMergedAsOwn() {
        do {
            _ = try ChallengeDocumentHydrator.hydrate(
                metadata: metadata(),
                ownSubmission: ownSubmission(side: .opponent),
                combinedResult: nil,
                accountID: "account-a"
            )
            Issue.record("The caller must never accept an opponent submission document")
        } catch {
            #expect(error as? SocialAuthorityError == .invalidResponse)
        }
    }

    @Test("Combined result is the sole source of both speakers' results")
    func combinedHydrationRevealsBothSides() throws {
        let challenge = try ChallengeDocumentHydrator.hydrate(
            metadata: metadata(completedAt: completedAt),
            ownSubmission: ownSubmission(side: .creator),
            combinedResult: combinedResult(),
            accountID: "account-a"
        )

        #expect(challenge.creatorScore == 8)
        #expect(challenge.opponentScore == 7)
        #expect(challenge.creatorReaction == .clap)
        #expect(challenge.opponentReaction == .strong)
        #expect(challenge.bothHavePlayed)
    }

    @Test("Incomplete metadata hydration cannot downgrade cached results")
    func incompleteHydrationPreservesCachedEvidence() throws {
        let completed = try ChallengeDocumentHydrator.hydrate(
            metadata: metadata(completedAt: completedAt),
            ownSubmission: nil,
            combinedResult: combinedResult(),
            accountID: "account-a"
        )
        let metadataOnly = try ChallengeDocumentHydrator.hydrate(
            metadata: metadata(),
            ownSubmission: nil,
            combinedResult: nil,
            accountID: "account-a"
        )

        let merged = ChallengesManager.mergeHydratedChallenges(
            cached: [completed],
            remote: [metadataOnly]
        )

        #expect(merged.count == 1)
        #expect(merged.first?.bothHavePlayed == true)
        #expect(merged.first?.creatorScore == 8)
        #expect(merged.first?.opponentScore == 7)
    }

    @Test("Only a complete successful refresh reconciles authoritative removals")
    func challengeRefreshSeparatesEmptyFromFailures() throws {
        let cached = try ChallengeDocumentHydrator.hydrate(
            metadata: metadata(completedAt: completedAt),
            ownSubmission: nil,
            combinedResult: combinedResult(),
            accountID: "account-a"
        )

        let trueEmpty = BackendAsyncChallengeFetchResult.success(
            BackendAsyncChallengeSnapshot(
                challenges: [],
                seenChallengeIDs: [],
                failedChallengeIDs: [],
                metadataQueryIsComplete: true
            )
        )
        let emptyResult = try #require(
            ChallengesManager.reconcileHydratedChallenges(
                cached: [cached],
                result: trueEmpty
            )
        )
        #expect(emptyResult.isEmpty)

        let rowFailure = BackendAsyncChallengeFetchResult.success(
            BackendAsyncChallengeSnapshot(
                challenges: [],
                seenChallengeIDs: [challengeID.uuidString],
                failedChallengeIDs: [challengeID.uuidString],
                metadataQueryIsComplete: true
            )
        )
        let partialResult = try #require(
            ChallengesManager.reconcileHydratedChallenges(
                cached: [cached],
                result: rowFailure
            )
        )
        #expect(partialResult == [cached])

        let truncated = BackendAsyncChallengeFetchResult.success(
            BackendAsyncChallengeSnapshot(
                challenges: [],
                seenChallengeIDs: [],
                failedChallengeIDs: [],
                metadataQueryIsComplete: false
            )
        )
        let truncatedResult = try #require(
            ChallengesManager.reconcileHydratedChallenges(
                cached: [cached],
                result: truncated
            )
        )
        #expect(truncatedResult == [cached])

        #expect(
            ChallengesManager.reconcileHydratedChallenges(
                cached: [cached],
                result: .unavailable
            ) == nil
        )
    }

    #if canImport(FirebaseFunctions)
    @Test("Only the explicit Apple detail maps deletion to revocation unavailable")
    func deletionFailedPreconditionRequiresExplicitAppleReason() {
        let generic = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.failedPrecondition.rawValue
        )
        let unrelated = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.failedPrecondition.rawValue,
            userInfo: [
                FunctionsErrorDetailsKey: ["reason": "account-deletion-pending"]
            ]
        )
        let apple = NSError(
            domain: FunctionsErrorDomain,
            code: FunctionsErrorCode.failedPrecondition.rawValue,
            userInfo: [
                FunctionsErrorDetailsKey: [
                    "reason": BackendSyncManager.appleRevocationUnavailableReason
                ]
            ]
        )

        #expect(BackendSyncManager.accountDeletionError(from: generic) == .rejected)
        #expect(BackendSyncManager.accountDeletionError(from: unrelated) == .rejected)
        #expect(
            BackendSyncManager.accountDeletionError(from: apple)
                == .appleRevocationUnavailable
        )
    }
    #endif

    private let challengeID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
    private let creatorID = "55555555-5555-4555-8555-555555555555"
    private let opponentID = "66666666-6666-4666-8666-666666666666"
    private let creatorSessionID = "33333333-3333-4333-8333-333333333333"
    private let opponentSessionID = "44444444-4444-4444-8444-444444444444"
    private let prompt = "Name one decision you would defend under pressure?"
    private let createdAt = 1_800_000_000.0
    private let completedAt = 1_800_000_100.0

    private func metadata(completedAt: Double? = nil) -> ChallengeMetadataDocument {
        let digest = SHA256.hash(data: Data(prompt.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return ChallengeMetadataDocument(
            schemaVersion: 2,
            id: challengeID.uuidString,
            prompt: prompt,
            promptDigest: digest,
            createdAt: createdAt,
            expiresAt: createdAt + 259_200,
            creatorID: creatorID,
            creatorName: "Speaker",
            creatorAccountID: "account-a",
            opponentID: opponentID,
            opponentName: "Partner",
            opponentAccountID: "account-b",
            participantIDs: ["account-a", "account-b"],
            completedAt: completedAt
        )
    }

    private func ownSubmission(side: ChallengeParticipantSide) -> ChallengeOwnSubmissionDocument {
        ChallengeOwnSubmissionDocument(
            schemaVersion: 1,
            challengeID: challengeID.uuidString,
            accountID: "account-a",
            side: side,
            sessionID: creatorSessionID,
            score: 8,
            duration: 42,
            summary: "Clear opening",
            submittedAt: createdAt + 50,
            reaction: AsyncChallenge.Reaction.clap.rawValue,
            reactedAt: createdAt + 60
        )
    }

    private func combinedResult() -> ChallengeCombinedResultDocument {
        ChallengeCombinedResultDocument(
            schemaVersion: 1,
            challengeID: challengeID.uuidString,
            creatorSessionID: creatorSessionID,
            creatorScore: 8,
            creatorDuration: 42,
            creatorSummary: "Clear opening",
            creatorSubmittedAt: createdAt + 50,
            creatorReaction: AsyncChallenge.Reaction.clap.rawValue,
            creatorReactedAt: createdAt + 60,
            opponentSessionID: opponentSessionID,
            opponentScore: 7,
            opponentDuration: 45,
            opponentSummary: "Measured pace",
            opponentSubmittedAt: createdAt + 90,
            opponentReaction: AsyncChallenge.Reaction.strong.rawValue,
            opponentReactedAt: createdAt + 95,
            completedAt: completedAt
        )
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

private actor ChallengeRefreshProbe {
    private(set) var callCount = 0

    func record(participantID: String) {
        _ = participantID
        callCount += 1
    }
}
