import Foundation

/// Stable callable routing for every server-authored peer surface.
///
/// Keeping the names in one non-UI type prevents a view or manager from
/// silently selecting a different Functions region or falling back to direct
/// Firestore writes.
enum SocialAuthorityCallable {
    static let region = "europe-west2"
    static let recordPeerSession = "recordPeerSession"
    static let createChallenge = "createChallenge"
    static let submitChallengeResult = "submitChallengeResult"
    static let setChallengeReaction = "setChallengeReaction"
}

enum SocialAuthorityError: Error, Equatable, LocalizedError {
    case notConfigured
    case unauthenticated
    case sessionUnavailable
    case verifiedEvidenceUnavailable
    case friendAuthorizationUnavailable
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
             .invalidRequest, .conflict, .rejected:
            return false
        }
    }

    static func capabilityFailure(reason: String?) -> SocialAuthorityError? {
        switch reason {
        case "verified-evidence-unavailable":
            return .verifiedEvidenceUnavailable
        case "friend-authorization-unavailable":
            return .friendAuthorizationUnavailable
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
