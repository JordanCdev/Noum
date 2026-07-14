import Foundation
import CryptoKit

/// Stable callable routing for every server-authored peer surface.
///
/// Keeping the names in one non-UI type prevents a view or manager from
/// silently selecting a different Functions region or falling back to direct
/// Firestore writes.
enum SocialAuthorityCallable {
    static let region = "europe-west2"
    static let beginCompetitiveObservation = "beginCompetitiveObservation"
    static let completeCompetitiveObservation = "completeCompetitiveObservation"
    static let recordPeerSession = "recordPeerSession"
    static let getPeerProfile = "getPeerProfile"
    static let listLeagueMembers = "listLeagueMembers"
    static let createChallenge = "createChallenge"
    static let submitChallengeResult = "submitChallengeResult"
    static let setChallengeReaction = "setChallengeReaction"
}

// MARK: - Competitive observation authority

enum CompetitiveObservationPromptSource: String, Codable, Equatable, Sendable {
    case none
    case curated
    case aiGenerated = "ai-generated"
    case userAuthored = "user-authored"
    case speechProject = "speech-project"
    case challenge
}

/// Content-free provenance bound before microphone capture starts. Prompt text
/// never crosses this contract; only the server-comparable SHA-256 digest does.
struct CompetitiveObservationPromptProvenance: Codable, Equatable, Sendable {
    let source: CompetitiveObservationPromptSource
    let promptDigest: String?

    static let none = CompetitiveObservationPromptProvenance(
        source: .none,
        promptDigest: nil
    )

    /// The backend uses SHA-256 over the prompt's exact UTF-8 bytes. Do not
    /// trim, normalize, fold case, or collapse whitespace here: changing even
    /// one byte must break a challenge/prompt binding rather than silently
    /// authorize a different exercise.
    static func bound(
        source: CompetitiveObservationPromptSource,
        exactPrompt: String
    ) -> CompetitiveObservationPromptProvenance? {
        guard source != .none, !exactPrompt.isEmpty else { return nil }
        let digest = SHA256.hash(data: Data(exactPrompt.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return CompetitiveObservationPromptProvenance(
            source: source,
            promptDigest: digest
        )
    }

    init(source: CompetitiveObservationPromptSource, promptDigest: String?) {
        self.source = source
        self.promptDigest = promptDigest?.lowercased()
    }

    var isValid: Bool {
        switch source {
        case .none:
            return promptDigest == nil
        case .curated, .aiGenerated, .userAuthored, .speechProject, .challenge:
            guard let promptDigest, promptDigest.count == 64 else { return false }
            return promptDigest.unicodeScalars.allSatisfy {
                CharacterSet(charactersIn: "0123456789abcdef").contains($0)
            }
        }
    }

    enum CodingKeys: String, CodingKey { case source, promptDigest }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source, forKey: .source)
        if let promptDigest {
            try container.encode(promptDigest, forKey: .promptDigest)
        } else {
            try container.encodeNil(forKey: .promptDigest)
        }
    }
}

/// Prepared by the route that owns the exact prompt provenance. The speech
/// view model accepts this value rather than guessing whether visible text was
/// curated, generated, user-authored, project-owned, or challenge-owned.
struct CompetitiveObservationIntent: Equatable, Sendable {
    let promptProvenance: CompetitiveObservationPromptProvenance
    let challengeID: UUID?

    static let noPrompt = CompetitiveObservationIntent(
        promptProvenance: .none,
        challengeID: nil
    )

    static func bound(
        source: CompetitiveObservationPromptSource,
        exactPrompt: String,
        challengeID: UUID? = nil
    ) -> CompetitiveObservationIntent? {
        guard let provenance = CompetitiveObservationPromptProvenance.bound(
            source: source,
            exactPrompt: exactPrompt
        ) else { return nil }
        guard (source == .challenge) == (challengeID != nil) else { return nil }
        return CompetitiveObservationIntent(
            promptProvenance: provenance,
            challengeID: challengeID
        )
    }

    func matches(exactPrompt: String?) -> Bool {
        switch promptProvenance.source {
        case .none:
            return exactPrompt == nil && challengeID == nil
        case .curated, .aiGenerated, .userAuthored, .speechProject, .challenge:
            guard let exactPrompt,
                  let expected = CompetitiveObservationPromptProvenance.bound(
                    source: promptProvenance.source,
                    exactPrompt: exactPrompt
                  ) else { return false }
            return expected == promptProvenance
                && ((promptProvenance.source == .challenge) == (challengeID != nil))
        }
    }
}

/// Exact wire projection of `PracticeSessionDemand`. Custom encoding retains
/// explicit nulls because the callable rejects ambiguous/partial demand maps.
struct CompetitiveObservationDemand: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let timedDifficulty: TimedPracticeDifficulty?
    let suddenDeathDifficulty: SuddenDeathDifficulty?
    let speechProjectID: String?

    init?(_ demand: PracticeSessionDemand, mode: PracticeMode) {
        guard demand.isValid(for: mode) else { return nil }
        schemaVersion = PracticeSessionDemand.currentSchemaVersion
        timedDifficulty = demand.timedDifficulty
        suddenDeathDifficulty = demand.suddenDeathDifficulty
        speechProjectID = demand.speechProjectID
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, timedDifficulty, suddenDeathDifficulty, speechProjectID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        if let timedDifficulty {
            try container.encode(timedDifficulty, forKey: .timedDifficulty)
        } else {
            try container.encodeNil(forKey: .timedDifficulty)
        }
        if let suddenDeathDifficulty {
            try container.encode(suddenDeathDifficulty, forKey: .suddenDeathDifficulty)
        } else {
            try container.encodeNil(forKey: .suddenDeathDifficulty)
        }
        if let speechProjectID {
            try container.encode(speechProjectID, forKey: .speechProjectID)
        } else {
            try container.encodeNil(forKey: .speechProjectID)
        }
    }
}

struct BeginCompetitiveObservationRequest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let sessionID: String
    let locale: String
    let mode: PracticeMode
    let demand: CompetitiveObservationDemand?
    let promptProvenance: CompetitiveObservationPromptProvenance
    let challengeID: String?

    init?(
        sessionID: UUID,
        locale: PracticeLocale,
        mode: PracticeMode,
        demand: PracticeSessionDemand?,
        promptProvenance: CompetitiveObservationPromptProvenance,
        challengeID: UUID?
    ) {
        let wireDemand = demand.flatMap { CompetitiveObservationDemand($0, mode: mode) }
        switch mode {
        case .timed, .suddenDeath:
            guard wireDemand != nil else { return nil }
        case .ahCounter, .imConversation:
            guard demand == nil else { return nil }
        }
        guard promptProvenance.isValid else { return nil }
        switch promptProvenance.source {
        case .none:
            guard challengeID == nil else { return nil }
        case .challenge:
            guard challengeID != nil else { return nil }
        case .speechProject:
            guard challengeID == nil,
                  wireDemand?.speechProjectID != nil else { return nil }
        case .curated, .aiGenerated, .userAuthored:
            guard challengeID == nil else { return nil }
        }

        schemaVersion = Self.currentSchemaVersion
        self.sessionID = sessionID.uuidString
        self.locale = locale.code
        self.mode = mode
        self.demand = wireDemand
        self.promptProvenance = promptProvenance
        self.challengeID = challengeID?.uuidString
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion, sessionID, locale, mode, demand, promptProvenance, challengeID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(locale, forKey: .locale)
        try container.encode(mode, forKey: .mode)
        if let demand {
            try container.encode(demand, forKey: .demand)
        } else {
            try container.encodeNil(forKey: .demand)
        }
        try container.encode(promptProvenance, forKey: .promptProvenance)
        if let challengeID {
            try container.encode(challengeID, forKey: .challengeID)
        } else {
            try container.encodeNil(forKey: .challengeID)
        }
    }
}

struct BeginCompetitiveObservationResponse: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let sessionID: String
    let expiresAt: String
    let replayed: Bool

    func binding(expectedSessionID: UUID, now: Date = Date()) throws -> CompetitiveObservationBinding {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard schemaVersion == BeginCompetitiveObservationRequest.currentSchemaVersion,
              sessionID == expectedSessionID.uuidString,
              let expiry = fractional.date(from: expiresAt)
                ?? ISO8601DateFormatter().date(from: expiresAt),
              expiry > now else {
            throw SocialAuthorityError.invalidResponse
        }
        return CompetitiveObservationBinding(
            sessionID: expectedSessionID,
            expiresAt: expiry,
            replayed: replayed
        )
    }
}

struct CompetitiveObservationBinding: Equatable, Sendable {
    let sessionID: UUID
    let expiresAt: Date
    let replayed: Bool
}

struct CompetitiveObservationAudioEnvelope: Codable, Equatable, Sendable {
    let encoding: String
    let sampleRateHertz: Int
    let channelCount: Int
    let sampleWidthBits: Int
    let dataBase64: String

    init(_ payload: CompetitiveObservationAudioPayload) {
        encoding = "linear16"
        sampleRateHertz = CompetitiveObservationAudioPayload.sampleRate
        channelCount = CompetitiveObservationAudioPayload.channelCount
        sampleWidthBits = CompetitiveObservationAudioPayload.bytesPerSample * 8
        dataBase64 = payload.pcm16Mono.base64EncodedString()
    }
}

struct CompleteCompetitiveObservationRequest: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let sessionID: String
    let audio: CompetitiveObservationAudioEnvelope

    init?(sessionID: UUID, audio: CompetitiveObservationAudioPayload) {
        guard audio.isCanonical else { return nil }
        schemaVersion = Self.currentSchemaVersion
        self.sessionID = sessionID.uuidString
        self.audio = CompetitiveObservationAudioEnvelope(audio)
    }
}

struct CompleteCompetitiveObservationResponse: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let sessionID: String
    let transcript: String
    let durationSeconds: Double
    let wordCount: Int
    let competitiveEligible: Bool
    let replayed: Bool

    func result(expectedSessionID: UUID) throws -> CompetitiveObservationResult {
        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard schemaVersion == CompleteCompetitiveObservationRequest.currentSchemaVersion,
              sessionID == expectedSessionID.uuidString,
              !cleanTranscript.isEmpty,
              cleanTranscript.count <= 12_000,
              durationSeconds.isFinite,
              durationSeconds > 0,
              durationSeconds <= CompetitiveObservationAudioPayload.maximumDuration,
              wordCount > 0,
              wordCount <= 3_000,
              competitiveEligible == false else {
            throw SocialAuthorityError.invalidResponse
        }
        return CompetitiveObservationResult(
            sessionID: expectedSessionID,
            transcript: cleanTranscript,
            duration: durationSeconds,
            wordCount: wordCount,
            replayed: replayed
        )
    }
}

struct CompetitiveObservationResult: Equatable, Sendable {
    let sessionID: UUID
    let transcript: String
    let duration: TimeInterval
    let wordCount: Int
    let replayed: Bool
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
    /// Server-observed competitive reps remain dark until the capture,
    /// evaluator calibration, deployment, and privacy evidence all pass the
    /// release gate. This flag is intentionally independent from peer UI:
    /// enabling a social surface must never silently authorize microphone
    /// bytes to leave the established transcription path.
    static let competitiveObservation = SocialCapabilityAvailability(
        isAvailable: false,
        message: "Verified competitive reps are unavailable while Noum finishes secure observation and evaluator calibration. Private practice is unaffected."
    )

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
