import Foundation

/// Stable callable routing for every server-authored peer surface.
///
/// Keeping the names in one non-UI type prevents a view or manager from
/// silently selecting a different Functions region or falling back to direct
/// Firestore writes.
enum SocialAuthorityCallable {
    static let region = "europe-west2"
    static let recordPeerSession = "recordPeerSession"
    static let getPeerProfile = "getPeerProfile"
    static let listLeagueMembers = "listLeagueMembers"
    static let createChallenge = "createChallenge"
    static let submitChallengeResult = "submitChallengeResult"
    static let setChallengeReaction = "setChallengeReaction"
}

struct SocialCapabilityAvailability: Equatable, Sendable {
    let isAvailable: Bool
    let message: String
}

/// Release gate for server-authoritative social features. The backend correctly
/// rejects client-owned evidence and local-only friendships, but their trusted
/// producers do not exist yet. Keeping these gates false prevents every rep or
/// tap from generating a predictable failed callable and one-off error card.
enum SocialReleaseCapabilities {
    static let peerProgress = SocialCapabilityAvailability(
        isAvailable: false,
        message: "Peer comparisons are unavailable while Noum finishes secure evidence verification. Your private coaching progress is unaffected."
    )

    static let friendProfiles = SocialCapabilityAvailability(
        isAvailable: false,
        message: "Shared friend stats are unavailable while Noum finishes secure connection verification."
    )

    static let speakOffs = SocialCapabilityAvailability(
        isAvailable: false,
        message: "Speak-offs are unavailable while Noum finishes secure evidence and friend verification."
    )
}

/// Captured before an async social operation. Managers increment their local
/// generation on both teardown and reload; a response may mutate state only
/// when both the durable account ID and generation still match.
struct SocialAccountOperationContext: Equatable, Sendable {
    let accountID: String
    let generation: UInt64

    func matches(accountID: String?, generation: UInt64) -> Bool {
        self.accountID == accountID && self.generation == generation
    }
}

enum SocialAuthorityError: Error, Equatable, LocalizedError {
    case notConfigured
    case unauthenticated
    case sessionUnavailable
    case verifiedEvidenceUnavailable
    case friendAuthorizationUnavailable
    case trustedSocialStateUnavailable
    case accountDeletionPending
    case notFound
    case invalidRequest
    case invalidResponse
    case conflict
    case rateLimited
    case serviceUnavailable
    case rejected

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Peer sync is not configured in this build."
        case .unauthenticated:
            return "Sign in again before syncing this peer activity."
        case .sessionUnavailable:
            return "The recorded rep could not be found. Nothing was submitted."
        case .verifiedEvidenceUnavailable:
            return "Competitive peer results are unavailable because this rep does not yet have server-verified evidence. Your private coaching history is unchanged."
        case .friendAuthorizationUnavailable:
            return "Speak-offs are unavailable for this connection because Noum cannot yet verify a reciprocal friend link."
        case .trustedSocialStateUnavailable:
            return "Peer comparisons are unavailable until Noum has server-verified progress for this account."
        case .accountDeletionPending:
            return "This peer action is unavailable while account deletion is pending."
        case .notFound:
            return "The requested peer data is no longer available."
        case .invalidRequest:
            return "This peer action is incomplete. Review it and try again."
        case .invalidResponse:
            return "Noum could not verify the server result. Nothing local was marked complete."
        case .conflict:
            return "This peer action changed on another device. Refresh and try again."
        case .rateLimited:
            return "Too many peer requests were made in a short time. Wait a moment, then try again."
        case .serviceUnavailable:
            return "Peer sync is temporarily unavailable. Your local coaching history is unchanged."
        case .rejected:
            return "The server did not accept this peer action. Refresh and try again."
        }
    }

    /// Capability failures are deliberately not presented as transient retry
    /// errors. Re-sending the same client-owned session or local friendship
    /// cannot create the missing server-owned evidence.
    var isRetryable: Bool {
        switch self {
        case .rateLimited, .serviceUnavailable, .invalidResponse:
            return true
        case .notConfigured, .unauthenticated, .sessionUnavailable,
             .verifiedEvidenceUnavailable, .friendAuthorizationUnavailable,
             .trustedSocialStateUnavailable, .accountDeletionPending,
             .notFound, .invalidRequest, .conflict, .rejected:
            return false
        }
    }

    static func capabilityFailure(reason: String?) -> SocialAuthorityError? {
        switch reason {
        case "verified-evidence-unavailable":
            return .verifiedEvidenceUnavailable
        case "friend-authorization-unavailable":
            return .friendAuthorizationUnavailable
        case "trusted-social-state-unavailable":
            return .trustedSocialStateUnavailable
        case "account-deletion-pending":
            return .accountDeletionPending
        default:
            return nil
        }
    }
}

// MARK: - Public profile authority

/// The only client-authored fields used to publish a completed rep.
/// Rating, streak, league, and timestamp are deliberately absent.
struct RecordPeerSessionRequest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let sessionID: String
    let displayName: String

    init(sessionID: UUID, displayName: String) {
        schemaVersion = Self.currentSchemaVersion
        self.sessionID = sessionID.uuidString
        self.displayName = SocialAuthorityText.displayName(displayName)
    }
}

struct PublicProfileAuthorityEnvelope: Codable, Equatable, Sendable {
    let accountID: String
    let displayName: String
    let rating: Int
    let peakRating: Int
    let currentStreak: Int
    let weeklyReps: Int
    let weeklyDelta: Int
    let leagueTier: String?
    let updatedAt: Double

    func snapshot() throws -> PublicProfileSnapshot {
        guard !accountID.isEmpty,
              !displayName.isEmpty,
              (100...1000).contains(rating),
              (100...1000).contains(peakRating),
              peakRating >= rating,
              currentStreak >= 0,
              weeklyReps >= 0,
              updatedAt.isFinite,
              updatedAt > 0 else {
            throw SocialAuthorityError.invalidResponse
        }
        if let leagueTier, LeagueTier(rawValue: leagueTier) == nil {
            throw SocialAuthorityError.invalidResponse
        }
        return PublicProfileSnapshot(
            accountID: accountID,
            displayName: displayName,
            rating: rating,
            peakRating: peakRating,
            currentStreak: currentStreak,
            weeklyReps: weeklyReps,
            weeklyDelta: weeklyDelta,
            leagueTier: leagueTier,
            updatedAt: Date(timeIntervalSince1970: updatedAt)
        )
    }
}

struct RecordPeerSessionResponse: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let sessionID: String
    /// False means the server recognized a replay and returned the already
    /// committed envelope. Both values are successful, authoritative reads.
    let processed: Bool
    let profile: PublicProfileAuthorityEnvelope

    func result(expectedSessionID: UUID) throws -> PeerSessionAuthorityResult {
        guard schemaVersion == RecordPeerSessionRequest.currentSchemaVersion,
              sessionID == expectedSessionID.uuidString else {
            throw SocialAuthorityError.invalidResponse
        }
        return PeerSessionAuthorityResult(
            sessionID: expectedSessionID,
            profile: try profile.snapshot(),
            processedNow: processed
        )
    }
}

struct PeerSessionAuthorityResult: Equatable, Sendable {
    let sessionID: UUID
    let profile: PublicProfileSnapshot
    let processedNow: Bool
}

/// Reciprocal-friend-authorized profile read. The caller identity is derived
/// from Firebase Auth and is deliberately absent from the request.
struct GetPeerProfileRequest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let accountID: String

    init(accountID: String) {
        schemaVersion = Self.currentSchemaVersion
        self.accountID = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isValid: Bool {
        !accountID.isEmpty && accountID.count <= 128 && !accountID.contains("/")
    }
}

struct GetPeerProfileResponse: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let profile: PublicProfileAuthorityEnvelope

    func result(expectedAccountID: String) throws -> PublicProfileSnapshot {
        guard schemaVersion == GetPeerProfileRequest.currentSchemaVersion else {
            throw SocialAuthorityError.invalidResponse
        }
        let snapshot = try profile.snapshot()
        guard snapshot.accountID == expectedAccountID else {
            throw SocialAuthorityError.invalidResponse
        }
        return snapshot
    }
}

/// The server derives the only league bucket the caller may read. No client
/// tier, rating, week, or bucket identifier crosses the callable boundary.
struct ListLeagueMembersRequest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let limit: Int

    init(limit: Int) {
        schemaVersion = Self.currentSchemaVersion
        self.limit = limit
    }

    var isValid: Bool { (1...50).contains(limit) }
}

struct ListLeagueMembersResponse: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let bucket: String
    let members: [PublicProfileAuthorityEnvelope]

    func result(requestedLimit: Int) throws -> LeagueMembersAuthorityResult {
        guard schemaVersion == ListLeagueMembersRequest.currentSchemaVersion,
              !bucket.isEmpty,
              bucket.count <= 128,
              members.count <= requestedLimit else {
            throw SocialAuthorityError.invalidResponse
        }
        let snapshots = try members.map { try $0.snapshot() }
        guard Set(snapshots.map(\.accountID)).count == snapshots.count else {
            throw SocialAuthorityError.invalidResponse
        }
        return LeagueMembersAuthorityResult(bucket: bucket, members: snapshots)
    }
}

struct LeagueMembersAuthorityResult: Equatable, Sendable {
    let bucket: String
    let members: [PublicProfileSnapshot]
}

// MARK: - Challenge authority

/// Challenge creation carries the chosen opponent and prompt only. Creator
/// identity, participant arrays, dates, and all result fields are server-owned.
struct CreateChallengeRequest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let challengeID: String
    let opponentAccountID: String
    let prompt: String

    init(
        challengeID: UUID,
        opponentAccountID: String,
        prompt: String
    ) {
        schemaVersion = Self.currentSchemaVersion
        self.challengeID = challengeID.uuidString
        self.opponentAccountID = opponentAccountID.trimmingCharacters(in: .whitespacesAndNewlines)
        self.prompt = SocialAuthorityText.prompt(prompt)
    }

    var isValid: Bool {
        UUID(uuidString: challengeID) != nil
            && !opponentAccountID.isEmpty
            && !prompt.isEmpty
    }
}

/// The server reads the stored rep and derives score, duration, and summary.
struct SubmitChallengeResultRequest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let challengeID: String
    let sessionID: String

    init(challengeID: UUID, sessionID: UUID) {
        schemaVersion = Self.currentSchemaVersion
        self.challengeID = challengeID.uuidString
        self.sessionID = sessionID.uuidString
    }
}

struct SetChallengeReactionRequest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let challengeID: String
    let reaction: String

    init(challengeID: UUID, reaction: AsyncChallenge.Reaction) {
        schemaVersion = Self.currentSchemaVersion
        self.challengeID = challengeID.uuidString
        self.reaction = reaction.rawValue
    }
}

/// Numeric seconds are explicit at the callable boundary; Foundation `Date`
/// encoding is intentionally not relied on across Firebase SDK versions.
struct AsyncChallengeAuthorityEnvelope: Codable, Equatable, Sendable {
    let id: String
    let prompt: String
    let createdAt: Double
    let expiresAt: Double
    let creatorID: String
    let creatorName: String
    let creatorAccountID: String
    let opponentID: String
    let opponentName: String
    let opponentAccountID: String
    let creatorScore: Int?
    let creatorDuration: Double?
    let creatorSummary: String?
    let opponentScore: Int?
    let opponentDuration: Double?
    let opponentSummary: String?
    let creatorReaction: String?
    let opponentReaction: String?

    func challenge() throws -> AsyncChallenge {
        guard let challengeID = UUID(uuidString: id),
              let creatorID = UUID(uuidString: creatorID),
              let opponentID = UUID(uuidString: opponentID),
              !prompt.isEmpty,
              !creatorName.isEmpty,
              !creatorAccountID.isEmpty,
              !opponentName.isEmpty,
              !opponentAccountID.isEmpty,
              creatorAccountID != opponentAccountID,
              createdAt.isFinite,
              expiresAt.isFinite,
              expiresAt > createdAt else {
            throw SocialAuthorityError.invalidResponse
        }
        let creatorReaction = try decodedReaction(creatorReaction)
        let opponentReaction = try decodedReaction(opponentReaction)
        return AsyncChallenge(
            id: challengeID,
            prompt: prompt,
            createdAt: Date(timeIntervalSince1970: createdAt),
            expiresAt: Date(timeIntervalSince1970: expiresAt),
            creatorID: creatorID,
            creatorName: creatorName,
            creatorAccountID: creatorAccountID,
            opponentID: opponentID,
            opponentName: opponentName,
            opponentAccountID: opponentAccountID,
            creatorScore: creatorScore,
            creatorDuration: creatorDuration,
            creatorSummary: creatorSummary,
            opponentScore: opponentScore,
            opponentDuration: opponentDuration,
            opponentSummary: opponentSummary,
            creatorReaction: creatorReaction,
            opponentReaction: opponentReaction
        )
    }

    private func decodedReaction(_ value: String?) throws -> AsyncChallenge.Reaction? {
        guard let value else { return nil }
        guard let reaction = AsyncChallenge.Reaction(rawValue: value) else {
            throw SocialAuthorityError.invalidResponse
        }
        return reaction
    }
}

struct CreateChallengeResponse: Codable, Equatable, Sendable {
    let schemaVersion: Int
    /// False is an idempotent replay of the same create request.
    let created: Bool
    let challenge: AsyncChallengeAuthorityEnvelope

    func result(expectedChallengeID: UUID) throws -> ChallengeMutationAuthorityResult {
        guard schemaVersion == CreateChallengeRequest.currentSchemaVersion else {
            throw SocialAuthorityError.invalidResponse
        }
        let challenge = try challenge.challenge()
        guard challenge.id == expectedChallengeID else {
            throw SocialAuthorityError.invalidResponse
        }
        return ChallengeMutationAuthorityResult(challenge: challenge, changedNow: created)
    }
}

struct SubmitChallengeResultResponse: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let sessionID: String
    /// False is an idempotent replay of the same session submission.
    let submitted: Bool
    let challenge: AsyncChallengeAuthorityEnvelope

    func result(
        expectedChallengeID: UUID,
        expectedSessionID: UUID
    ) throws -> ChallengeMutationAuthorityResult {
        guard schemaVersion == SubmitChallengeResultRequest.currentSchemaVersion,
              sessionID == expectedSessionID.uuidString else {
            throw SocialAuthorityError.invalidResponse
        }
        let challenge = try challenge.challenge()
        guard challenge.id == expectedChallengeID else {
            throw SocialAuthorityError.invalidResponse
        }
        return ChallengeMutationAuthorityResult(challenge: challenge, changedNow: submitted)
    }
}

struct SetChallengeReactionResponse: Codable, Equatable, Sendable {
    let schemaVersion: Int
    /// False is an idempotent replay of the same reaction.
    let updated: Bool
    let challenge: AsyncChallengeAuthorityEnvelope

    func result(expectedChallengeID: UUID) throws -> ChallengeMutationAuthorityResult {
        guard schemaVersion == SetChallengeReactionRequest.currentSchemaVersion else {
            throw SocialAuthorityError.invalidResponse
        }
        let challenge = try challenge.challenge()
        guard challenge.id == expectedChallengeID else {
            throw SocialAuthorityError.invalidResponse
        }
        return ChallengeMutationAuthorityResult(challenge: challenge, changedNow: updated)
    }
}

struct ChallengeMutationAuthorityResult: Equatable, Sendable {
    let challenge: AsyncChallenge
    let changedNow: Bool
}

/// Stable retry intent. Reusing the same challenge/session IDs makes retries
/// idempotent rather than creating duplicate social results.
enum AsyncChallengeAuthorityIntent: Equatable, Sendable {
    case create(CreateChallengeRequest)
    case submit(SubmitChallengeResultRequest)
    case reaction(SetChallengeReactionRequest)

    var operationID: String {
        switch self {
        case .create(let request): return "create:\(request.challengeID)"
        case .submit(let request): return "submit:\(request.challengeID):\(request.sessionID)"
        case .reaction(let request): return "reaction:\(request.challengeID):\(request.reaction)"
        }
    }

    var challengeID: String {
        switch self {
        case .create(let request): return request.challengeID
        case .submit(let request): return request.challengeID
        case .reaction(let request): return request.challengeID
        }
    }
}

struct AsyncChallengeAuthorityFailure: Equatable, Identifiable, Sendable {
    let intent: AsyncChallengeAuthorityIntent
    let message: String
    let isRetryable: Bool

    var id: String { intent.operationID }
}

private enum SocialAuthorityText {
    static func displayName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return String((trimmed.isEmpty ? "Speaker" : trimmed).prefix(60))
    }

    static func prompt(_ value: String) -> String {
        String(value.trimmingCharacters(in: .whitespacesAndNewlines).prefix(500))
    }
}
