import Foundation
import Testing
@testable import Noum

@Suite("Social authority client contracts")
struct SocialAuthorityClientTests {
    @Test("Every social callable uses the production region and exact name")
    func callableRouting() {
        #expect(BackendSyncManager.functionsRegion == "europe-west2")
        #expect(BackendSyncManager.recordPeerSessionFunctionName == "recordPeerSession")
        #expect(BackendSyncManager.createChallengeFunctionName == "createChallenge")
        #expect(BackendSyncManager.submitChallengeResultFunctionName == "submitChallengeResult")
        #expect(BackendSyncManager.setChallengeReactionFunctionName == "setChallengeReaction")
    }

    @Test("Peer-session request omits every client-authored authority field")
    func peerRequestIsNarrow() throws {
        let request = RecordPeerSessionRequest(
            sessionID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            displayName: "  Speaker  "
        )
        let payload = try jsonObject(request)

        #expect(Set(payload.keys) == ["schemaVersion", "sessionID", "displayName"])
        #expect(payload["displayName"] as? String == "Speaker")
        assertForbiddenAuthorityFieldsAreAbsent(payload)
    }

    @Test("Challenge creation sends only opponent account, prompt, and stable ID")
    func createRequestIsNarrow() throws {
        let request = CreateChallengeRequest(
            challengeID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            opponentAccountID: "firebase-opponent",
            prompt: "Name one decision you would defend under pressure?"
        )
        let payload = try jsonObject(request)

        #expect(Set(payload.keys) == [
            "schemaVersion", "challengeID", "opponentAccountID", "prompt"
        ])
        assertForbiddenAuthorityFieldsAreAbsent(payload)
    }

    @Test("Challenge submission never sends score, summary, side, or timestamp")
    func submitRequestIsNarrow() throws {
        let request = SubmitChallengeResultRequest(
            challengeID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            sessionID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        )
        let payload = try jsonObject(request)

        #expect(Set(payload.keys) == ["schemaVersion", "challengeID", "sessionID"])
        assertForbiddenAuthorityFieldsAreAbsent(payload)
    }

    @Test("Reaction request carries one bounded enum value")
    func reactionRequestIsNarrow() throws {
        let request = SetChallengeReactionRequest(
            challengeID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            reaction: .clap
        )
        let payload = try jsonObject(request)

        #expect(Set(payload.keys) == ["schemaVersion", "challengeID", "reaction"])
        #expect(payload["reaction"] as? String == AsyncChallenge.Reaction.clap.rawValue)
        assertForbiddenAuthorityFieldsAreAbsent(payload)
    }

    @Test("Lost peer-session response can replay without a second mutation")
    func peerReplayIsSuccess() throws {
        let sessionID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let response = RecordPeerSessionResponse(
            schemaVersion: 1,
            sessionID: sessionID.uuidString,
            processed: false,
            profile: profileEnvelope
        )
        let result = try response.result(expectedSessionID: sessionID)

        #expect(!result.processedNow)
        #expect(result.sessionID == sessionID)
        #expect(result.profile.rating == 612)
    }

    @Test("Duplicate challenge create is a successful authoritative replay")
    func createReplayIsSuccess() throws {
        let challengeID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let response = CreateChallengeResponse(
            schemaVersion: 1,
            created: false,
            challenge: challengeEnvelope(id: challengeID)
        )
        let result = try response.result(expectedChallengeID: challengeID)

        #expect(!result.changedNow)
        #expect(result.challenge.id == challengeID)
        #expect(!result.challenge.bothHavePlayed)
    }

    @Test("Challenge envelopes preserve only the server's exact bounded prompt shape")
    func challengePromptShapeIsExact() throws {
        let challengeID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let valid = challengeEnvelope(id: challengeID)
        let decoded = try valid.challenge()
        #expect(decoded.prompt == valid.prompt)

        var invalid = valid
        invalid = AsyncChallengeAuthorityEnvelope(
            id: invalid.id,
            prompt: " \(invalid.prompt)",
            createdAt: invalid.createdAt,
            expiresAt: invalid.expiresAt,
            creatorID: invalid.creatorID,
            creatorName: invalid.creatorName,
            creatorAccountID: invalid.creatorAccountID,
            opponentID: invalid.opponentID,
            opponentName: invalid.opponentName,
            opponentAccountID: invalid.opponentAccountID,
            creatorScore: invalid.creatorScore,
            creatorDuration: invalid.creatorDuration,
            creatorSummary: invalid.creatorSummary,
            opponentScore: invalid.opponentScore,
            opponentDuration: invalid.opponentDuration,
            opponentSummary: invalid.opponentSummary,
            creatorReaction: invalid.creatorReaction,
            opponentReaction: invalid.opponentReaction
        )
        #expect(throws: SocialAuthorityError.invalidResponse) {
            try invalid.challenge()
        }
    }

    @Test("Same challenge submission replay stays successful and complete only from server envelope")
    func submissionReplayUsesEnvelope() throws {
        let challengeID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let sessionID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        var envelope = challengeEnvelope(id: challengeID)
        envelope = AsyncChallengeAuthorityEnvelope(
            id: envelope.id,
            prompt: envelope.prompt,
            createdAt: envelope.createdAt,
            expiresAt: envelope.expiresAt,
            creatorID: envelope.creatorID,
            creatorName: envelope.creatorName,
            creatorAccountID: envelope.creatorAccountID,
            opponentID: envelope.opponentID,
            opponentName: envelope.opponentName,
            opponentAccountID: envelope.opponentAccountID,
            creatorScore: 8,
            creatorDuration: 42,
            creatorSummary: "Clear opening",
            opponentScore: 7,
            opponentDuration: 45,
            opponentSummary: "Measured pace",
            creatorReaction: nil,
            opponentReaction: nil
        )
        let response = SubmitChallengeResultResponse(
            schemaVersion: 1,
            sessionID: sessionID.uuidString,
            submitted: false,
            challenge: envelope
        )
        let result = try response.result(
            expectedChallengeID: challengeID,
            expectedSessionID: sessionID
        )

        #expect(!result.changedNow)
        #expect(result.challenge.bothHavePlayed)
        #expect(result.challenge.creatorScore == 8)
        #expect(result.challenge.opponentScore == 7)
    }

    @Test("Mismatched replay echo is rejected rather than applied")
    func mismatchedEchoIsRejected() {
        let expected = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let other = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let response = RecordPeerSessionResponse(
            schemaVersion: 1,
            sessionID: other.uuidString,
            processed: true,
            profile: profileEnvelope
        )

        do {
            _ = try response.result(expectedSessionID: expected)
            Issue.record("A mismatched session echo must fail closed")
        } catch {
            #expect(error as? SocialAuthorityError == .invalidResponse)
        }
    }

    @Test("Retry intent preserves the exact idempotency keys")
    func retryIntentIsStable() {
        let request = SubmitChallengeResultRequest(
            challengeID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            sessionID: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        )
        let first = AsyncChallengeAuthorityIntent.submit(request)
        let retry = AsyncChallengeAuthorityIntent.submit(request)

        #expect(first == retry)
        #expect(first.operationID == retry.operationID)
    }

    @Test("Server capability failures are honest and non-retryable")
    func capabilityFailuresDoNotSuggestClientRetry() {
        let evidence = SocialAuthorityError.capabilityFailure(
            reason: "verified-evidence-unavailable"
        )
        let friendship = SocialAuthorityError.capabilityFailure(
            reason: "friend-authorization-unavailable"
        )

        #expect(evidence == .verifiedEvidenceUnavailable)
        #expect(friendship == .friendAuthorizationUnavailable)
        #expect(evidence?.isRetryable == false)
        #expect(friendship?.isRetryable == false)
        #expect(SocialAuthorityError.rateLimited.isRetryable)
        #expect(SocialAuthorityError.serviceUnavailable.isRetryable)
    }

    @Test("An own-only private result never manufactures an opponent score")
    func ownPrivateResultKeepsOpponentPending() throws {
        let challengeID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let base = challengeEnvelope(id: challengeID)
        let ownOnly = AsyncChallengeAuthorityEnvelope(
            id: base.id,
            prompt: base.prompt,
            createdAt: base.createdAt,
            expiresAt: base.expiresAt,
            creatorID: base.creatorID,
            creatorName: base.creatorName,
            creatorAccountID: base.creatorAccountID,
            opponentID: base.opponentID,
            opponentName: base.opponentName,
            opponentAccountID: base.opponentAccountID,
            creatorScore: 8,
            creatorDuration: 42,
            creatorSummary: "Clear opening",
            opponentScore: nil,
            opponentDuration: nil,
            opponentSummary: nil,
            creatorReaction: nil,
            opponentReaction: nil
        )
        let challenge = try ownOnly.challenge()

        #expect(challenge.creatorScore == 8)
        #expect(challenge.opponentScore == nil)
        #expect(!challenge.bothHavePlayed)
        #expect(challenge.status(forParticipantID: "firebase-speaker") == .waitingForOpponent)
    }

    @Test("Challenge queries cannot be redirected to another account")
    func crossAccountQueryIsRejected() {
        #expect(BackendSyncManager.authorizedChallengeParticipantID(
            requestedID: "firebase-a",
            firebaseUID: "firebase-a"
        ) == "firebase-a")
        #expect(BackendSyncManager.authorizedChallengeParticipantID(
            requestedID: "firebase-b",
            firebaseUID: "firebase-a"
        ) == nil)
        #expect(BackendSyncManager.authorizedChallengeParticipantID(
            requestedID: "firebase-a",
            firebaseUID: nil
        ) == nil)
    }

    @Test("Challenge persistence keys are isolated by account")
    func challengeKeysAreAccountScoped() {
        #expect(ChallengesManager.accountKey(base: "NoumAsyncChallenges", accountID: "a")
                == "NoumAsyncChallenges.a")
        #expect(ChallengesManager.accountKey(base: "NoumAsyncChallenges", accountID: "a")
                != ChallengesManager.accountKey(base: "NoumAsyncChallenges", accountID: "b"))
        #expect(FriendsManager.accountKey(base: "NoumFriendsList", accountID: "a")
                != FriendsManager.accountKey(base: "NoumFriendsList", accountID: "b"))
        #expect(ClubsManager.accountKey(base: "NoumSavedClubs", accountID: "a")
                != ClubsManager.accountKey(base: "NoumSavedClubs", accountID: "b"))
    }

    @Test("Only the rep carrying the exact armed speak-off bytes may submit")
    func armedPromptMatchIsByteExact() {
        let prompt = "Name one decision you would defend under pressure?"
        #expect(ChallengesManager.repMatchesArmedPrompt(
            sessionPrompt: prompt,
            armedPrompt: prompt
        ))
        #expect(!ChallengesManager.repMatchesArmedPrompt(
            sessionPrompt: "  NAME one decision you would defend under pressure?  ",
            armedPrompt: prompt
        ))
        #expect(!ChallengesManager.repMatchesArmedPrompt(
            sessionPrompt: "Describe a recent presentation.",
            armedPrompt: prompt
        ))
        #expect(!ChallengesManager.repMatchesArmedPrompt(
            sessionPrompt: nil,
            armedPrompt: prompt
        ))

        let decomposed = "Defend Cafe\u{301}."
        #expect(!ChallengesManager.repMatchesArmedPrompt(
            sessionPrompt: "Defend Café.",
            armedPrompt: decomposed
        ))
    }

    private var profileEnvelope: PublicProfileAuthorityEnvelope {
        PublicProfileAuthorityEnvelope(
            accountID: "firebase-speaker",
            displayName: "Speaker",
            rating: 612,
            peakRating: 640,
            currentStreak: 4,
            weeklyReps: 3,
            weeklyDelta: 18,
            leagueTier: LeagueTier.gold.rawValue,
            updatedAt: 1_800_000_000
        )
    }

    private func challengeEnvelope(id: UUID) -> AsyncChallengeAuthorityEnvelope {
        AsyncChallengeAuthorityEnvelope(
            id: id.uuidString,
            prompt: "Name one decision you would defend under pressure?",
            createdAt: 1_800_000_000,
            expiresAt: 1_800_259_200,
            creatorID: "55555555-5555-5555-5555-555555555555",
            creatorName: "Speaker",
            creatorAccountID: "firebase-speaker",
            opponentID: "66666666-6666-6666-6666-666666666666",
            opponentName: "Partner",
            opponentAccountID: "firebase-partner",
            creatorScore: nil,
            creatorDuration: nil,
            creatorSummary: nil,
            opponentScore: nil,
            opponentDuration: nil,
            opponentSummary: nil,
            creatorReaction: nil,
            opponentReaction: nil
        )
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func assertForbiddenAuthorityFieldsAreAbsent(_ payload: [String: Any]) {
        let forbidden = [
            "accountID", "creatorAccountID", "creatorID", "creatorName",
            "opponentID", "opponentName", "participantIDs",
            "rating", "peakRating", "currentStreak", "weeklyReps",
            "weeklyDelta", "leagueTier", "updatedAt", "createdAt", "expiresAt",
            "score", "creatorScore", "opponentScore", "duration", "summary"
        ]
        for key in forbidden {
            #expect(payload[key] == nil, "Forbidden authority field: \(key)")
        }
    }
}
