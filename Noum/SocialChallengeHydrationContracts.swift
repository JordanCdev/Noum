import CryptoKit
import Foundation

enum ChallengeParticipantSide: String, Codable, Equatable, Sendable {
    case creator
    case opponent
}

/// Server-owned metadata stored at `challenges/{challengeID}`. Results,
/// reactions, and session identifiers are intentionally absent.
struct ChallengeMetadataDocument: Codable, Equatable, Sendable {
    static let expectedKeys: Set<String> = [
        "schemaVersion", "id", "prompt", "promptDigest", "createdAt",
        "expiresAt", "creatorID", "creatorName", "creatorAccountID",
        "opponentID", "opponentName", "opponentAccountID",
        "participantIDs", "completedAt",
    ]

    let schemaVersion: Int
    let id: String
    let prompt: String
    let promptDigest: String
    let createdAt: Double
    let expiresAt: Double
    let creatorID: String
    let creatorName: String
    let creatorAccountID: String
    let opponentID: String
    let opponentName: String
    let opponentAccountID: String
    let participantIDs: [String]
    let completedAt: Double?

    func validate(forDocumentID documentID: String, accountID: String) throws {
        let digest = SHA256.hash(data: Data(prompt.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        guard schemaVersion == 2,
              id == documentID,
              UUID(uuidString: id) != nil,
              !prompt.isEmpty,
              prompt.count <= 500,
              promptDigest == digest,
              promptDigest.count == 64,
              createdAt.isFinite,
              createdAt > 0,
              expiresAt.isFinite,
              expiresAt > createdAt,
              UUID(uuidString: creatorID) != nil,
              UUID(uuidString: opponentID) != nil,
              !creatorName.isEmpty,
              creatorName.count <= 60,
              !opponentName.isEmpty,
              opponentName.count <= 60,
              !creatorAccountID.isEmpty,
              !opponentAccountID.isEmpty,
              creatorAccountID != opponentAccountID,
              participantIDs == [creatorAccountID, opponentAccountID],
              participantIDs.contains(accountID),
              completedAt.map({ $0.isFinite && $0 >= createdAt }) ?? true else {
            throw SocialAuthorityError.invalidResponse
        }
    }
}

/// Caller-private result stored at
/// `challenges/{challengeID}/submissions/{currentUID}`. The client never lists
/// this collection and never constructs an opponent submission path.
struct ChallengeOwnSubmissionDocument: Codable, Equatable, Sendable {
    static let expectedKeys: Set<String> = [
        "schemaVersion", "challengeID", "accountID", "side", "sessionID",
        "score", "duration", "summary", "submittedAt", "reaction",
        "reactedAt",
    ]

    let schemaVersion: Int
    let challengeID: String
    let accountID: String
    let side: ChallengeParticipantSide
    let sessionID: String
    let score: Int
    let duration: Double
    let summary: String?
    let submittedAt: Double
    let reaction: String?
    let reactedAt: Double?

    func validate(metadata: ChallengeMetadataDocument, callerAccountID: String) throws {
        let expectedSide: ChallengeParticipantSide = callerAccountID == metadata.creatorAccountID
            ? .creator
            : .opponent
        guard schemaVersion == 1,
              challengeID == metadata.id,
              accountID == callerAccountID,
              side == expectedSide,
              UUID(uuidString: sessionID) != nil,
              (0...10).contains(score),
              duration.isFinite,
              duration > 0,
              duration <= 14_400,
              summary.map({ $0.count <= 240 }) ?? true,
              submittedAt.isFinite,
              submittedAt >= metadata.createdAt,
              Self.validReaction(reaction),
              (reaction == nil) == (reactedAt == nil),
              reactedAt.map({ $0.isFinite && $0 >= submittedAt }) ?? true else {
            throw SocialAuthorityError.invalidResponse
        }
    }

    private static func validReaction(_ value: String?) -> Bool {
        guard let value else { return true }
        return AsyncChallenge.Reaction(rawValue: value) != nil
    }
}

/// Participant-readable result materialized only after both private
/// submissions exist. It is the sole source of an opponent score or reaction.
struct ChallengeCombinedResultDocument: Codable, Equatable, Sendable {
    static let expectedKeys: Set<String> = [
        "schemaVersion", "challengeID",
        "creatorSessionID", "creatorScore", "creatorDuration",
        "creatorSummary", "creatorSubmittedAt", "creatorReaction",
        "creatorReactedAt",
        "opponentSessionID", "opponentScore", "opponentDuration",
        "opponentSummary", "opponentSubmittedAt", "opponentReaction",
        "opponentReactedAt", "completedAt",
    ]

    let schemaVersion: Int
    let challengeID: String
    let creatorSessionID: String
    let creatorScore: Int
    let creatorDuration: Double
    let creatorSummary: String?
    let creatorSubmittedAt: Double
    let creatorReaction: String?
    let creatorReactedAt: Double?
    let opponentSessionID: String
    let opponentScore: Int
    let opponentDuration: Double
    let opponentSummary: String?
    let opponentSubmittedAt: Double
    let opponentReaction: String?
    let opponentReactedAt: Double?
    let completedAt: Double

    func validate(metadata: ChallengeMetadataDocument) throws {
        guard schemaVersion == 1,
              challengeID == metadata.id,
              UUID(uuidString: creatorSessionID) != nil,
              UUID(uuidString: opponentSessionID) != nil,
              (0...10).contains(creatorScore),
              (0...10).contains(opponentScore),
              Self.validDuration(creatorDuration),
              Self.validDuration(opponentDuration),
              creatorSummary.map({ $0.count <= 240 }) ?? true,
              opponentSummary.map({ $0.count <= 240 }) ?? true,
              creatorSubmittedAt.isFinite,
              creatorSubmittedAt >= metadata.createdAt,
              opponentSubmittedAt.isFinite,
              opponentSubmittedAt >= metadata.createdAt,
              Self.validReaction(creatorReaction),
              Self.validReaction(opponentReaction),
              (creatorReaction == nil) == (creatorReactedAt == nil),
              (opponentReaction == nil) == (opponentReactedAt == nil),
              creatorReactedAt.map({ $0.isFinite && $0 >= creatorSubmittedAt }) ?? true,
              opponentReactedAt.map({ $0.isFinite && $0 >= opponentSubmittedAt }) ?? true,
              completedAt.isFinite,
              completedAt >= max(creatorSubmittedAt, opponentSubmittedAt),
              metadata.completedAt == completedAt else {
            throw SocialAuthorityError.invalidResponse
        }
    }

    private static func validDuration(_ value: Double) -> Bool {
        value.isFinite && value > 0 && value <= 14_400
    }

    private static func validReaction(_ value: String?) -> Bool {
        guard let value else { return true }
        return AsyncChallenge.Reaction(rawValue: value) != nil
    }
}

enum ChallengeDocumentHydrator {
    static func hydrate(
        metadata: ChallengeMetadataDocument,
        ownSubmission: ChallengeOwnSubmissionDocument?,
        combinedResult: ChallengeCombinedResultDocument?,
        accountID: String
    ) throws -> AsyncChallenge {
        try metadata.validate(forDocumentID: metadata.id, accountID: accountID)

        var creatorScore: Int?
        var creatorDuration: Double?
        var creatorSummary: String?
        var creatorReaction: AsyncChallenge.Reaction?
        var opponentScore: Int?
        var opponentDuration: Double?
        var opponentSummary: String?
        var opponentReaction: AsyncChallenge.Reaction?

        if let combinedResult {
            try combinedResult.validate(metadata: metadata)
            creatorScore = combinedResult.creatorScore
            creatorDuration = combinedResult.creatorDuration
            creatorSummary = combinedResult.creatorSummary
            creatorReaction = combinedResult.creatorReaction.flatMap(AsyncChallenge.Reaction.init(rawValue:))
            opponentScore = combinedResult.opponentScore
            opponentDuration = combinedResult.opponentDuration
            opponentSummary = combinedResult.opponentSummary
            opponentReaction = combinedResult.opponentReaction.flatMap(AsyncChallenge.Reaction.init(rawValue:))
        } else {
            guard metadata.completedAt == nil else {
                throw SocialAuthorityError.invalidResponse
            }
            if let ownSubmission {
                try ownSubmission.validate(metadata: metadata, callerAccountID: accountID)
                let reaction = ownSubmission.reaction.flatMap(AsyncChallenge.Reaction.init(rawValue:))
                switch ownSubmission.side {
                case .creator:
                    creatorScore = ownSubmission.score
                    creatorDuration = ownSubmission.duration
                    creatorSummary = ownSubmission.summary
                    creatorReaction = reaction
                case .opponent:
                    opponentScore = ownSubmission.score
                    opponentDuration = ownSubmission.duration
                    opponentSummary = ownSubmission.summary
                    opponentReaction = reaction
                }
            }
        }

        guard let id = UUID(uuidString: metadata.id),
              let creatorID = UUID(uuidString: metadata.creatorID),
              let opponentID = UUID(uuidString: metadata.opponentID) else {
            throw SocialAuthorityError.invalidResponse
        }
        return AsyncChallenge(
            id: id,
            prompt: metadata.prompt,
            createdAt: Date(timeIntervalSince1970: metadata.createdAt),
            expiresAt: Date(timeIntervalSince1970: metadata.expiresAt),
            creatorID: creatorID,
            creatorName: metadata.creatorName,
            creatorAccountID: metadata.creatorAccountID,
            opponentID: opponentID,
            opponentName: metadata.opponentName,
            opponentAccountID: metadata.opponentAccountID,
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
}
