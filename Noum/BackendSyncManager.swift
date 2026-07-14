import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

enum BackendAccountDeletionOutcome: Equatable {
    /// The callable removed Noum-controlled data and the Firebase Auth record.
    case accountAndAuthDeleted
    /// A legacy REST backend removed its data; the client must still remove
    /// the Firebase Auth record before local state can be cleared.
    case dataDeleted
}

enum BackendAccountDeletionError: Error, Equatable {
    case notConfigured
    case requiresRecentAuthentication
    case appleRevocationUnavailable
    case serviceUnavailable
    case rejected
    case invalidResponse
}

private struct DeleteAccountCallableRequest: Codable, Sendable {
    static let schemaVersion = 1
    let schemaVersion: Int
    let requestID: String

    init(requestID: UUID = UUID()) {
        self.schemaVersion = Self.schemaVersion
        self.requestID = requestID.uuidString
    }
}

private struct DeleteAccountCallableResponse: Codable, Sendable {
    let deleted: Bool
    let requestID: String
}

struct BackendBootstrap: Codable {
    let xp: Int?
    let profile: CoachingProfile?
    let sessions: [PracticeSession]?
    let recommendationPending: RecommendationExposure?
    let recommendationOutcomes: [RecommendationOutcome]?
    /// Firebase can distinguish an absent recommendation document from an
    /// explicit empty state. Older REST payloads omit this field; in that case
    /// non-nil pending/outcome fields remain the only evidence of remote state.
    let recommendationStateExists: Bool?

    init(
        xp: Int?,
        profile: CoachingProfile?,
        sessions: [PracticeSession]?,
        recommendationPending: RecommendationExposure?,
        recommendationOutcomes: [RecommendationOutcome]?,
        recommendationStateExists: Bool? = nil
    ) {
        self.xp = xp
        self.profile = profile
        self.sessions = sessions
        self.recommendationPending = recommendationPending
        self.recommendationOutcomes = recommendationOutcomes
        self.recommendationStateExists = recommendationStateExists
    }

    var hasAuthoritativeRecommendationState: Bool {
        if let recommendationStateExists {
            return recommendationStateExists
        }
        return recommendationPending != nil || recommendationOutcomes != nil
    }
}

enum BackendBootstrapFetchResult {
    /// The backend answered successfully. A nil profile in this payload is a
    /// confirmed absence and may legitimately lead to onboarding.
    case success(BackendBootstrap)
    /// Configuration, transport, authorization, or decoding did not produce
    /// an authoritative answer. This must never be treated as an empty account.
    case unavailable
}

struct BackendAsyncChallengeSnapshot: Equatable, Sendable {
    let challenges: [AsyncChallenge]
    let seenChallengeIDs: Set<String>
    let failedChallengeIDs: Set<String>
    let metadataQueryIsComplete: Bool

    init(
        challenges: [AsyncChallenge],
        seenChallengeIDs: Set<String>,
        failedChallengeIDs: Set<String>,
        metadataQueryIsComplete: Bool
    ) {
        let normalizedChallengeIDs = Set(challenges.map { Self.normalizedID($0.id.uuidString) })
        let normalizedFailures = Set(failedChallengeIDs.map(Self.normalizedID))
        self.challenges = challenges
        self.seenChallengeIDs = Set(seenChallengeIDs.map(Self.normalizedID))
            .union(normalizedChallengeIDs)
            .union(normalizedFailures)
        self.failedChallengeIDs = normalizedFailures
        self.metadataQueryIsComplete = metadataQueryIsComplete
    }

    var isAuthoritativeForRemovals: Bool {
        metadataQueryIsComplete && failedChallengeIDs.isEmpty
    }

    func contains(_ challengeID: UUID) -> Bool {
        seenChallengeIDs.contains(Self.normalizedID(challengeID.uuidString))
    }

    nonisolated private static func normalizedID(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

enum BackendAsyncChallengeFetchResult: Equatable, Sendable {
    /// The release capability is intentionally unavailable. No configuration
    /// or Firestore access was attempted.
    case capabilityUnavailable
    /// Authentication, configuration, or the metadata query failed. Cached
    /// rows are not authoritative in this state and must remain untouched.
    case unavailable
    /// The metadata query succeeded. Row failures are carried separately so
    /// they cannot be mistaken for a genuinely empty authoritative result.
    case success(BackendAsyncChallengeSnapshot)
}

private struct RecommendationSyncPayload: Codable {
    let pendingExposure: RecommendationExposure?
    let outcomes: [RecommendationOutcome]
}

struct RecommendationSyncSnapshot: Equatable, Sendable {
    let pendingExposure: RecommendationExposure?
    let outcomes: [RecommendationOutcome]
    let accountID: String
    let providerRawValue: String
    let revision: Int
}

/// One lane per account keeps whole-state recommendation writes ordered while
/// coalescing bursts to their newest snapshot. Revision rejection also covers
/// tasks that reach the backend actor out of launch order.
actor RecommendationSyncLane {
    typealias Writer = @Sendable (RecommendationSyncSnapshot) async -> Bool

    private let writer: Writer
    private var pending: RecommendationSyncSnapshot?
    private var failedSnapshot: RecommendationSyncSnapshot?
    private var highestEnqueuedRevision = -1
    private var isDraining = false
    private var isClosed = false
    private var idleWaiters: [CheckedContinuation<Bool, Never>] = []

    init(writer: @escaping Writer) {
        self.writer = writer
    }

    func enqueue(
        _ snapshot: RecommendationSyncSnapshot,
        allowAtWatermark: Bool = false
    ) {
        guard !isClosed else { return }
        let isRetryAtWatermark = snapshot.revision == highestEnqueuedRevision
            && failedSnapshot != nil
        let isExplicitAtWatermark = allowAtWatermark
            && snapshot.revision == highestEnqueuedRevision
        guard snapshot.revision > highestEnqueuedRevision
                || isRetryAtWatermark
                || isExplicitAtWatermark else {
            return
        }
        highestEnqueuedRevision = max(highestEnqueuedRevision, snapshot.revision)
        failedSnapshot = nil
        pending = snapshot
        guard !isDraining else { return }
        isDraining = true
        Task { await drain() }
    }

    func fence(at revision: Int) async -> Bool {
        guard !isClosed else { return false }
        if revision > highestEnqueuedRevision {
            highestEnqueuedRevision = revision
        }
        // A hydration fence is an ordering barrier, not cancellation. Drain
        // work that already reached the lane before reading remote state so
        // an accepted local prescription cannot be replaced by an older
        // bootstrap snapshot. The revision watermark still rejects older
        // tasks that arrive after the barrier.
        return await waitUntilIdle()
    }

    func closeAndWait() async {
        isClosed = true
        pending = nil
        failedSnapshot = nil
        _ = await waitUntilIdle()
    }

    func waitUntilIdle() async -> Bool {
        guard isDraining || pending != nil else {
            return !isClosed && failedSnapshot == nil
        }
        return await withCheckedContinuation { continuation in
            idleWaiters.append(continuation)
        }
    }

    private func drain() async {
        while let snapshot = pending {
            pending = nil
            guard await writer(snapshot) else {
                // Preserve the newest complete state as retryable work. Do
                // not spin on a failing transport; a later current-state
                // enqueue can retry at the existing watermark.
                failedSnapshot = pending ?? snapshot
                pending = nil
                break
            }
        }
        isDraining = false
        let succeeded = !isClosed && failedSnapshot == nil
        let waiters = idleWaiters
        idleWaiters.removeAll()
        waiters.forEach { $0.resume(returning: succeeded) }
    }
}

/// Unstructured one-shot used for Firestore operations whose completion may
/// never arrive while offline. The losing task is allowed to finish later;
/// the first result alone owns the caller's decision.
actor RecommendationSyncWaitRace {
    private var continuation: CheckedContinuation<Bool, Never>?
    private var result: Bool?

    func wait() async -> Bool {
        if let result { return result }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resolve(_ value: Bool) {
        guard result == nil else { return }
        result = value
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: value)
        }
    }
}

actor BackendSyncManager {
    static let shared = BackendSyncManager()
    static let functionsRegion = SocialAuthorityCallable.region
    static let deleteAccountFunctionName = "deleteAccount"
    static let recordPeerSessionFunctionName = SocialAuthorityCallable.recordPeerSession
    static let getPeerProfileFunctionName = SocialAuthorityCallable.getPeerProfile
    static let listLeagueMembersFunctionName = SocialAuthorityCallable.listLeagueMembers
    static let createChallengeFunctionName = SocialAuthorityCallable.createChallenge
    static let submitChallengeResultFunctionName = SocialAuthorityCallable.submitChallengeResult
    static let setChallengeReactionFunctionName = SocialAuthorityCallable.setChallengeReaction
    static let appleRevocationUnavailableReason = "apple-revocation-unavailable"
    static let recommendationSyncWaitNanoseconds: UInt64 = 4_000_000_000

    private var recommendationSyncLanes: [String: RecommendationSyncLane] = [:]
    private var recommendationSyncClosedAccounts: Set<String> = []
    private var recommendationHydrationTokens: [String: UUID] = [:]
    private var recommendationHydrationPending: [String: RecommendationSyncSnapshot] = [:]

    private init() {}

    nonisolated static func authorizedChallengeParticipantID(
        requestedID: String,
        firebaseUID: String?
    ) -> String? {
        guard let firebaseUID, requestedID == firebaseUID else { return nil }
        return firebaseUID
    }

    nonisolated static func recommendationStatePayloadIsWellFormed(
        _ data: [String: Any]
    ) -> Bool {
        guard data.keys.contains("pendingExposure"),
              data.keys.contains("outcomes") else { return false }
        if let pending = data["pendingExposure"],
           !(pending is NSNull),
           !(pending is [String: Any]) {
            return false
        }
        if let outcomes = data["outcomes"],
           !(outcomes is [[String: Any]]) {
            return false
        }
        return true
    }

    var isConfigured: Bool {
        firebaseIsConfigured || baseURL != nil
    }

    func fetchBootstrap(accountID: String, providerRawValue: String) async -> BackendBootstrapFetchResult {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            return await fetchFirebaseBootstrap(accountID: accountID)
        }
#endif
        guard var request = await request(
            path: "/v1/me/bootstrap",
            method: "GET",
            accountID: accountID,
            providerRawValue: providerRawValue
        ) else {
            return .unavailable
        }
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                return .unavailable
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                return .unavailable
            }
            return .success(try JSONDecoder().decode(BackendBootstrap.self, from: data))
        } catch {
            return .unavailable
        }
    }

    func syncProfile(_ profile: CoachingProfile, accountID: String, providerRawValue: String) async {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            await syncFirebaseProfile(profile, accountID: accountID, providerRawValue: providerRawValue)
            return
        }
#endif
        try? await send(profile, path: "/v1/me/profile", accountID: accountID, providerRawValue: providerRawValue)
    }

    func syncXP(_ xp: Int, accountID: String, providerRawValue: String) async {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            await syncFirebaseXP(xp, accountID: accountID, providerRawValue: providerRawValue)
            return
        }
#endif
        try? await send(["xp": xp], path: "/v1/me/progression", accountID: accountID, providerRawValue: providerRawValue)
    }

    func syncSession(_ session: PracticeSession, accountID: String, providerRawValue: String) async {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            await syncFirebaseSession(session, accountID: accountID, providerRawValue: providerRawValue)
            return
        }
#endif
        try? await send(session, path: "/v1/me/sessions", accountID: accountID, providerRawValue: providerRawValue)
    }

    func syncRecommendationState(
        pendingExposure: RecommendationExposure?,
        outcomes: [RecommendationOutcome],
        accountID: String,
        providerRawValue: String,
        revision: Int
    ) async {
        guard !recommendationSyncClosedAccounts.contains(accountID) else { return }
        let snapshot = RecommendationSyncSnapshot(
            pendingExposure: pendingExposure,
            outcomes: outcomes,
            accountID: accountID,
            providerRawValue: providerRawValue,
            revision: revision
        )
        if recommendationHydrationTokens[accountID] != nil {
            if let existing = recommendationHydrationPending[accountID],
               existing.revision >= snapshot.revision {
                return
            }
            recommendationHydrationPending[accountID] = snapshot
            return
        }
        let lane = recommendationSyncLane(for: accountID)
        await lane.enqueue(snapshot)
    }

    func fenceRecommendationSync(
        accountID: String,
        revision: Int,
        hydrationToken: UUID
    ) async -> Bool {
        guard !recommendationSyncClosedAccounts.contains(accountID) else { return false }
        guard recommendationHydrationTokens[accountID] == hydrationToken else { return false }
        let lane = recommendationSyncLane(for: accountID)
        return await Self.boundedRecommendationSyncWait {
            await lane.fence(at: revision)
        }
    }

    func beginRecommendationHydration(
        accountID: String,
        hydrationToken: UUID
    ) -> Bool {
        guard !recommendationSyncClosedAccounts.contains(accountID) else { return false }
        recommendationHydrationTokens[accountID] = hydrationToken
        return true
    }

    func finishRecommendationHydration(
        accountID: String,
        hydrationToken: UUID
    ) async {
        guard recommendationHydrationTokens[accountID] == hydrationToken else { return }
        recommendationHydrationTokens.removeValue(forKey: accountID)
        guard !recommendationSyncClosedAccounts.contains(accountID),
              let pending = recommendationHydrationPending.removeValue(forKey: accountID) else {
            recommendationHydrationPending.removeValue(forKey: accountID)
            return
        }
        await recommendationSyncLane(for: accountID).enqueue(
            pending,
            allowAtWatermark: true
        )
    }

    func suspendRecommendationSyncForDeletion(accountID: String) async -> Bool {
        recommendationSyncClosedAccounts.insert(accountID)
        recommendationHydrationTokens.removeValue(forKey: accountID)
        recommendationHydrationPending.removeValue(forKey: accountID)
        guard let lane = recommendationSyncLanes[accountID] else { return true }
        let didClose = await Self.boundedRecommendationSyncWait {
            await lane.closeAndWait()
            return true
        }
        if didClose {
            recommendationSyncLanes.removeValue(forKey: accountID)
        }
        return didClose
    }

    func resumeRecommendationSyncAfterFailedDeletion(accountID: String) {
        recommendationSyncClosedAccounts.remove(accountID)
    }

    private func recommendationSyncLane(for accountID: String) -> RecommendationSyncLane {
        if let existing = recommendationSyncLanes[accountID] {
            return existing
        }
        let created = RecommendationSyncLane { [weak self] snapshot in
            guard let self else { return false }
            return await self.writeRecommendationState(snapshot)
        }
        recommendationSyncLanes[accountID] = created
        return created
    }

    nonisolated static func boundedRecommendationSyncWait(
        timeoutNanoseconds: UInt64 = recommendationSyncWaitNanoseconds,
        operation: @escaping @Sendable () async -> Bool
    ) async -> Bool {
        let race = RecommendationSyncWaitRace()
        Task {
            await race.resolve(await operation())
        }
        Task {
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            await race.resolve(false)
        }
        return await race.wait()
    }

    private func writeRecommendationState(
        _ snapshot: RecommendationSyncSnapshot
    ) async -> Bool {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            let succeeded = await syncFirebaseRecommendationState(
                pendingExposure: snapshot.pendingExposure,
                outcomes: snapshot.outcomes,
                accountID: snapshot.accountID,
                providerRawValue: snapshot.providerRawValue
            )
            if succeeded {
                await acknowledgeRecommendationSync(snapshot)
            }
            return succeeded
        }
#endif
        do {
            try await send(
                RecommendationSyncPayload(
                    pendingExposure: snapshot.pendingExposure,
                    outcomes: snapshot.outcomes
                ),
                path: "/v1/me/recommendations",
                accountID: snapshot.accountID,
                providerRawValue: snapshot.providerRawValue
            )
            await acknowledgeRecommendationSync(snapshot)
            return true
        } catch {
            return false
        }
    }

    private func acknowledgeRecommendationSync(
        _ snapshot: RecommendationSyncSnapshot
    ) async {
        await RecommendationLearningStore.shared.confirmCurrentStateSync(
            accountID: snapshot.accountID,
            revision: snapshot.revision
        )
    }

    func deleteAccount(
        accountID: String,
        providerRawValue: String
    ) async throws -> BackendAccountDeletionOutcome {
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions)
        if firebaseIsConfigured {
            return try await deleteFirebaseAccountThroughCallable()
        }
        #endif

        // REST backend path: send a DELETE request to remove server-side data
        guard let request = await request(
            path: "/v1/me",
            method: "DELETE",
            accountID: accountID,
            providerRawValue: providerRawValue
        ) else {
            throw BackendAccountDeletionError.notConfigured
        }
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw BackendAccountDeletionError.invalidResponse
            }
            guard (200..<300).contains(http.statusCode) else {
                if http.statusCode == 401 {
                    throw BackendAccountDeletionError.requiresRecentAuthentication
                }
                throw BackendAccountDeletionError.rejected
            }
            return .dataDeleted
        } catch let error as BackendAccountDeletionError {
            throw error
        } catch {
            throw BackendAccountDeletionError.serviceUnavailable
        }
    }

    #if canImport(FirebaseCore) && canImport(FirebaseFunctions)
    private func deleteFirebaseAccountThroughCallable() async throws -> BackendAccountDeletionOutcome {
        guard FirebaseApp.app() != nil else {
            throw BackendAccountDeletionError.notConfigured
        }
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw BackendAccountDeletionError.requiresRecentAuthentication
        }
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                user.getIDTokenForcingRefresh(true) { token, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let token {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(throwing: BackendAccountDeletionError.requiresRecentAuthentication)
                    }
                }
            }
        } catch {
            throw BackendAccountDeletionError.requiresRecentAuthentication
        }
        #endif
        let request = DeleteAccountCallableRequest()
        do {
            let functions = Functions.functions(region: Self.functionsRegion)
            let callable: Callable<DeleteAccountCallableRequest, DeleteAccountCallableResponse> = functions
                .httpsCallable(Self.deleteAccountFunctionName)
            let response = try await callable.call(request)
            guard response.deleted, response.requestID == request.requestID else {
                throw BackendAccountDeletionError.invalidResponse
            }
            return .accountAndAuthDeleted
        } catch let error as BackendAccountDeletionError {
            throw error
        } catch {
            throw Self.accountDeletionError(from: error)
        }
    }

    nonisolated static func accountDeletionError(from error: Error) -> BackendAccountDeletionError {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return .serviceUnavailable
        }
        switch code {
        case .unauthenticated:
            return .requiresRecentAuthentication
        case .failedPrecondition:
            guard functionsFailureReason(from: nsError) == appleRevocationUnavailableReason else {
                return .rejected
            }
            return .appleRevocationUnavailable
        case .unavailable, .deadlineExceeded, .cancelled:
            return .serviceUnavailable
        default:
            return .rejected
        }
    }
    #endif

    // MARK: - Peer (M2: Peer Pull v1)

    /// Upload a fully annotated session, wait for the Firestore commit, then
    /// ask the server to derive every public statistic from that stored rep.
    /// The ordering is deliberate: the callable never races the background
    /// sync launched by `PracticeSessionStore`.
    func recordPeerSession(
        session: PracticeSession,
        accountID: String,
        providerRawValue: String,
        displayName: String
    ) async throws -> PeerSessionAuthorityResult {
        guard SocialReleaseCapabilities.peerProgress.isAvailable else {
            throw SocialAuthorityError.verifiedEvidenceUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount(accountID)
        try await syncFirebaseSessionForAuthority(
            session,
            accountID: accountID,
            providerRawValue: providerRawValue
        )
        let request = RecordPeerSessionRequest(
            sessionID: session.id,
            displayName: displayName
        )
        let response: RecordPeerSessionResponse = try await callSocialAuthority(
            Self.recordPeerSessionFunctionName,
            request: request
        )
        return try response.result(expectedSessionID: session.id)
        #else
        throw SocialAuthorityError.notConfigured
        #endif
    }

    /// Reciprocal-friend-authorized replacement for direct public-profile
    /// reads. The release capability gate prevents a callable attempt until
    /// the server-only friendship producer exists.
    func fetchPeerProfile(accountID: String) async throws -> PublicProfileSnapshot {
        guard SocialReleaseCapabilities.friendProfiles.isAvailable else {
            throw SocialAuthorityError.friendAuthorizationUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount()
        let request = GetPeerProfileRequest(accountID: accountID)
        guard request.isValid else { throw SocialAuthorityError.invalidRequest }
        let response: GetPeerProfileResponse = try await callSocialAuthority(
            Self.getPeerProfileFunctionName,
            request: request
        )
        return try response.result(expectedAccountID: request.accountID)
        #else
        throw SocialAuthorityError.notConfigured
        #endif
    }

    /// Server-derived current-bucket replacement for direct league reads.
    /// No bucket or rating state is accepted from the client.
    func fetchLeagueMembers(limit: Int = 20) async throws -> LeagueMembersAuthorityResult {
        guard SocialReleaseCapabilities.peerProgress.isAvailable else {
            throw SocialAuthorityError.trustedSocialStateUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount()
        let request = ListLeagueMembersRequest(limit: limit)
        guard request.isValid else { throw SocialAuthorityError.invalidRequest }
        let response: ListLeagueMembersResponse = try await callSocialAuthority(
            Self.listLeagueMembersFunctionName,
            request: request
        )
        return try response.result(requestedLimit: request.limit)
        #else
        throw SocialAuthorityError.notConfigured
        #endif
    }

    func createChallenge(_ request: CreateChallengeRequest) async throws -> ChallengeMutationAuthorityResult {
        guard SocialReleaseCapabilities.speakOffs.isAvailable else {
            throw SocialAuthorityError.friendAuthorizationUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount()
        guard request.isValid else { throw SocialAuthorityError.invalidRequest }
        let response: CreateChallengeResponse = try await callSocialAuthority(
            Self.createChallengeFunctionName,
            request: request
        )
        guard let challengeID = UUID(uuidString: request.challengeID) else {
            throw SocialAuthorityError.invalidRequest
        }
        return try response.result(expectedChallengeID: challengeID)
        #else
        throw SocialAuthorityError.notConfigured
        #endif
    }

    /// A challenge result can reference a rep only after the final annotated
    /// session document has committed. No client-authored score or summary is
    /// present in the callable request.
    func submitChallengeResult(
        _ request: SubmitChallengeResultRequest,
        session: PracticeSession,
        accountID: String,
        providerRawValue: String
    ) async throws -> ChallengeMutationAuthorityResult {
        guard SocialReleaseCapabilities.speakOffs.isAvailable else {
            throw SocialAuthorityError.verifiedEvidenceUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFirestore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount(accountID)
        guard request.sessionID == session.id.uuidString,
              let challengeID = UUID(uuidString: request.challengeID),
              let sessionID = UUID(uuidString: request.sessionID) else {
            throw SocialAuthorityError.invalidRequest
        }
        try await syncFirebaseSessionForAuthority(
            session,
            accountID: accountID,
            providerRawValue: providerRawValue
        )
        let response: SubmitChallengeResultResponse = try await callSocialAuthority(
            Self.submitChallengeResultFunctionName,
            request: request
        )
        return try response.result(
            expectedChallengeID: challengeID,
            expectedSessionID: sessionID
        )
        #else
        throw SocialAuthorityError.notConfigured
        #endif
    }

    func setChallengeReaction(
        _ request: SetChallengeReactionRequest
    ) async throws -> ChallengeMutationAuthorityResult {
        guard SocialReleaseCapabilities.speakOffs.isAvailable else {
            throw SocialAuthorityError.friendAuthorizationUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount()
        guard let challengeID = UUID(uuidString: request.challengeID),
              AsyncChallenge.Reaction(rawValue: request.reaction) != nil else {
            throw SocialAuthorityError.invalidRequest
        }
        let response: SetChallengeReactionResponse = try await callSocialAuthority(
            Self.setChallengeReactionFunctionName,
            request: request
        )
        return try response.result(expectedChallengeID: challengeID)
        #else
        throw SocialAuthorityError.notConfigured
        #endif
    }

    /// Fetch all async challenges where the given accountID is a participant.
    /// Returns most-recent-first, capped server-side at 50.
    func fetchAsyncChallenges(
        forParticipant participantID: String
    ) async -> BackendAsyncChallengeFetchResult {
        guard SocialReleaseCapabilities.speakOffs.isAvailable else {
            return .capabilityUnavailable
        }
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            return await fetchFirebaseAsyncChallenges(forParticipant: participantID)
        }
#endif
        return .unavailable
    }

    #if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
    private func requireFirebaseAccount(_ expectedAccountID: String? = nil) throws {
        guard FirebaseApp.app() != nil,
              let firebaseUID = Auth.auth().currentUser?.uid else {
            throw SocialAuthorityError.unauthenticated
        }
        if let expectedAccountID, firebaseUID != expectedAccountID {
            throw SocialAuthorityError.unauthenticated
        }
    }

    private func callSocialAuthority<Request, Response>(
        _ name: String,
        request: Request
    ) async throws -> Response where Request: Encodable, Response: Decodable {
        do {
            let functions = Functions.functions(region: Self.functionsRegion)
            let callable: Callable<Request, Response> = functions.httpsCallable(name)
            return try await callable.call(request)
        } catch let error as SocialAuthorityError {
            throw error
        } catch {
            throw Self.socialAuthorityError(from: error)
        }
    }

    nonisolated private static func socialAuthorityError(from error: Error) -> SocialAuthorityError {
        let nsError = error as NSError
        guard nsError.domain == FunctionsErrorDomain,
              let code = FunctionsErrorCode(rawValue: nsError.code) else {
            return .serviceUnavailable
        }
        if code == .failedPrecondition,
           let capabilityFailure = SocialAuthorityError.capabilityFailure(
               reason: functionsFailureReason(from: nsError)
           ) {
            return capabilityFailure
        }
        switch code {
        case .unauthenticated:
            return .unauthenticated
        case .invalidArgument:
            return .invalidRequest
        case .notFound:
            return .notFound
        case .alreadyExists, .failedPrecondition, .aborted:
            return .conflict
        case .resourceExhausted:
            return .rateLimited
        case .unavailable, .deadlineExceeded, .cancelled:
            return .serviceUnavailable
        default:
            return .rejected
        }
    }

    nonisolated private static func functionsFailureReason(from error: NSError) -> String? {
        guard let details = error.userInfo[FunctionsErrorDetailsKey] else { return nil }
        if let dictionary = details as? [String: Any] {
            return dictionary["reason"] as? String
        }
        if let dictionary = details as? NSDictionary {
            return dictionary["reason"] as? String
        }
        return nil
    }
    #endif

    private func send<Payload: Encodable>(
        _ payload: Payload,
        path: String,
        accountID: String,
        providerRawValue: String
    ) async throws {
        guard var request = await request(
            path: path,
            method: "POST",
            accountID: accountID,
            providerRawValue: providerRawValue
        ) else {
            throw URLError(.unsupportedURL)
        }

        request.httpBody = try JSONEncoder().encode(payload)
        let (_, response) = try await URLSession.shared.data(for: request)
        guard Self.restWriteResponseIsSuccessful(response) else {
            throw URLError(.badServerResponse)
        }
    }

    nonisolated static func restWriteResponseIsSuccessful(
        _ response: URLResponse?
    ) -> Bool {
        guard let response = response as? HTTPURLResponse else { return false }
        return (200..<300).contains(response.statusCode)
    }

    private func request(
        path: String,
        method: String,
        accountID: String,
        providerRawValue: String
    ) async -> URLRequest? {
        guard let baseURL else { return nil }
        let endpoint = baseURL.appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        await BackendAuthHeaders.applyCurrent(
            to: &request,
            accountID: accountID,
            providerRawValue: providerRawValue
        )
        return request
    }

    private var baseURL: URL? {
        let rawValue =
            ProcessInfo.processInfo.environment["BACKEND_BASE_URL"] ??
            LocalConfigLoader.value(forKey: "BACKEND_BASE_URL", plistNamed: "BackendConfig")

        guard let rawValue, !rawValue.isEmpty else { return nil }
        return URL(string: rawValue)
    }

    private var firebaseIsConfigured: Bool {
#if canImport(FirebaseCore) && canImport(FirebaseFirestore)
        return FirebaseApp.app() != nil
#else
        return false
#endif
    }
}

#if canImport(FirebaseFirestore)
private extension BackendSyncManager {
    func fetchFirebaseBootstrap(accountID: String) async -> BackendBootstrapFetchResult {
        let userRef = userDocument(accountID: accountID)

        do {
            // Server-only reads make a successful missing profile authoritative.
            // Cached absence while offline remains `.unavailable`, never a cue
            // to overwrite a delayed cloud profile through onboarding.
            async let profileDocument = getDocument(
                userRef.collection("profile").document("main"),
                source: .server
            )
            async let progressionDocument = getDocument(
                userRef.collection("progress").document("main"),
                source: .server
            )
            async let sessionDocuments = getDocuments(
                userRef.collection("sessions").order(by: "date", descending: true).limit(to: 100),
                source: .server
            )
            async let recommendationStateDocument = getDocument(
                userRef.collection("recommendations").document("state"),
                source: .server
            )

            let profileSnapshot = try await profileDocument
            let progressionSnapshot = try await progressionDocument
            let sessionSnapshots = try await sessionDocuments
            let recommendationStateSnapshot = try await recommendationStateDocument

            guard let profileSnapshot,
                  let recommendationStateSnapshot else { return .unavailable }
            let profile: CoachingProfile?
            if profileSnapshot.exists {
                guard let decoded = try decodeDocument(CoachingProfile.self, from: profileSnapshot.data()) else {
                    return .unavailable
                }
                profile = decoded
            } else {
                profile = nil
            }
            let xp = progressionSnapshot?.data()?["xp"] as? Int
            let sessions = try sessionSnapshots.compactMap { try decodeDocument(PracticeSession.self, from: $0.data()) }
            let recommendationData = recommendationStateSnapshot.data()
            if recommendationStateSnapshot.exists {
                guard let recommendationData,
                      Self.recommendationStatePayloadIsWellFormed(recommendationData) else {
                    return .unavailable
                }
            }
            let recommendationPending = try decodeDocument(
                RecommendationExposure.self,
                from: recommendationData?["pendingExposure"] as? [String: Any]
            )
            let recommendationOutcomes = try decodeArray(
                RecommendationOutcome.self,
                from: recommendationData?["outcomes"] as? [[String: Any]]
            )

            return .success(BackendBootstrap(
                xp: xp,
                profile: profile,
                sessions: sessions.isEmpty ? nil : sessions,
                recommendationPending: recommendationPending,
                recommendationOutcomes: recommendationOutcomes.isEmpty ? nil : recommendationOutcomes,
                recommendationStateExists: recommendationStateSnapshot.exists
            ))
        } catch {
            return .unavailable
        }
    }

    func syncFirebaseProfile(_ profile: CoachingProfile, accountID: String, providerRawValue: String) async {
        do {
            await ensureFirebaseUserDocument(accountID: accountID, providerRawValue: providerRawValue)
            let data = try encodeDocument(profile)
            try await setDocument(
                userDocument(accountID: accountID).collection("profile").document("main"),
                data: data,
                merge: true
            )
        } catch { print("[BackendSync] Error: \(error.localizedDescription)") }
    }

    func syncFirebaseXP(_ xp: Int, accountID: String, providerRawValue: String) async {
        do {
            await ensureFirebaseUserDocument(accountID: accountID, providerRawValue: providerRawValue)
            try await setDocument(
                userDocument(accountID: accountID).collection("progress").document("main"),
                data: ["xp": xp],
                merge: true
            )
        } catch { print("[BackendSync] Error: \(error.localizedDescription)") }
    }

    func syncFirebaseSession(_ session: PracticeSession, accountID: String, providerRawValue: String) async {
        do {
            try await syncFirebaseSessionForAuthority(
                session,
                accountID: accountID,
                providerRawValue: providerRawValue
            )
        } catch { print("[BackendSync] Error: \(error.localizedDescription)") }
    }

    /// Throwing form reserved for a server-authority callable that must not
    /// run until its referenced session is durably visible to Functions.
    func syncFirebaseSessionForAuthority(
        _ session: PracticeSession,
        accountID: String,
        providerRawValue: String
    ) async throws {
        try await setDocument(
            userDocument(accountID: accountID),
            data: [
                "accountID": accountID,
                "provider": providerRawValue,
                "updatedAt": Date().timeIntervalSince1970
            ],
            merge: true
        )
        let data = try encodeDocument(session)
        try await setDocument(
            userDocument(accountID: accountID).collection("sessions").document(session.id.uuidString),
            data: data,
            merge: true
        )
    }

    func syncFirebaseRecommendationState(
        pendingExposure: RecommendationExposure?,
        outcomes: [RecommendationOutcome],
        accountID: String,
        providerRawValue: String
    ) async -> Bool {
        do {
            await ensureFirebaseUserDocument(accountID: accountID, providerRawValue: providerRawValue)
            let pendingData = try pendingExposure.map(encodeDocument)
            let outcomesData = try outcomes.map(encodeDocument)
            try await setDocument(
                userDocument(accountID: accountID).collection("recommendations").document("state"),
                data: [
                    "pendingExposure": (pendingData as Any?) ?? NSNull(),
                    "outcomes": outcomesData
                ],
                merge: true
            )
            return true
        } catch {
            print("[BackendSync] Error: \(error.localizedDescription)")
            return false
        }
    }

    func ensureFirebaseUserDocument(accountID: String, providerRawValue: String) async {
        let userRef = userDocument(accountID: accountID)
        do {
            try await setDocument(
                userRef,
                data: [
                    "accountID": accountID,
                    "provider": providerRawValue,
                    "updatedAt": Date().timeIntervalSince1970
                ],
                merge: true
            )
        } catch { print("[BackendSync] Error: \(error.localizedDescription)") }
    }

    func userDocument(accountID: String) -> DocumentReference {
        Firestore.firestore().collection("users").document(accountID)
    }

    func encodeDocument<T: Encodable>(_ value: T) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        return object as? [String: Any] ?? [:]
    }

    func decodeDocument<T: Decodable>(_ type: T.Type, from dictionary: [String: Any]?) throws -> T? {
        guard let dictionary else { return nil }
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode(T.self, from: data)
    }

    func decodeExactDocument<T: Decodable>(
        _ type: T.Type,
        from dictionary: [String: Any],
        expectedKeys: Set<String>
    ) throws -> T {
        guard Set(dictionary.keys) == expectedKeys,
              let decoded = try decodeDocument(type, from: dictionary) else {
            throw SocialAuthorityError.invalidResponse
        }
        return decoded
    }

    func decodeArray<T: Decodable>(_ type: T.Type, from array: [[String: Any]]?) throws -> [T] {
        guard let array else { return [] }
        let data = try JSONSerialization.data(withJSONObject: array)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return try decoder.decode([T].self, from: data)
    }

    func getDocument(
        _ reference: DocumentReference,
        source: FirestoreSource = .default
    ) async throws -> DocumentSnapshot? {
        try await withCheckedThrowingContinuation { continuation in
            reference.getDocument(source: source) { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: snapshot)
                }
            }
        }
    }

    func getDocuments(
        _ query: Query,
        source: FirestoreSource = .default
    ) async throws -> [QueryDocumentSnapshot] {
        try await withCheckedThrowingContinuation { continuation in
            query.getDocuments(source: source) { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: snapshot?.documents ?? [])
                }
            }
        }
    }

    func setDocument(_ reference: DocumentReference, data: [String: Any], merge: Bool) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.setData(data, merge: merge) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func fetchFirebaseAsyncChallenges(
        forParticipant participantID: String
    ) async -> BackendAsyncChallengeFetchResult {
        #if canImport(FirebaseAuth)
        // Firestore rules prove query safety from `request.auth.uid in
        // participantIDs`. Refuse a legacy local UUID here rather than issuing
        // a query that can never satisfy that authorization contract.
        guard Self.authorizedChallengeParticipantID(
            requestedID: participantID,
            firebaseUID: Auth.auth().currentUser?.uid
        ) != nil else { return .unavailable }
        #endif
        do {
            let documents = try await getDocuments(
                Firestore.firestore().collection("challenges")
                    .whereField("participantIDs", arrayContains: participantID)
                    .order(by: "createdAt", descending: true)
                    .limit(to: 50)
            )
            let rows = await withTaskGroup(
                of: (Int, String, AsyncChallenge?).self
            ) { group in
                for (index, document) in documents.enumerated() {
                    let documentID = document.documentID
                    let metadata = document.data()
                    group.addTask {
                        let challenge = await self.hydrateFirebaseChallenge(
                            documentID: documentID,
                            metadata: metadata,
                            participantID: participantID
                        )
                        return (index, documentID, challenge)
                    }
                }
                var hydrated: [(Int, String, AsyncChallenge?)] = []
                for await row in group {
                    hydrated.append(row)
                }
                return hydrated.sorted { $0.0 < $1.0 }
            }
            let challenges = rows.compactMap(\.2)
            let seenIDs = Set(rows.map(\.1))
            let failedIDs = Set(rows.compactMap { _, documentID, challenge in
                challenge == nil ? documentID : nil
            })
            return .success(
                BackendAsyncChallengeSnapshot(
                    challenges: challenges,
                    seenChallengeIDs: seenIDs,
                    failedChallengeIDs: failedIDs,
                    // The query is capped to bound read cost. Exactly 50 rows
                    // may mean there are older rows outside this snapshot, so
                    // unseen cached history cannot be treated as deleted.
                    metadataQueryIsComplete: documents.count < 50
                )
            )
        } catch {
            return .unavailable
        }
    }

    /// Hydrates metadata with exactly the caller's private submission and the
    /// participant-readable combined result. Any non-absence read/decode
    /// failure omits this row so the manager preserves its last authoritative
    /// cache rather than replacing it with incomplete metadata.
    func hydrateFirebaseChallenge(
        documentID: String,
        metadata: [String: Any],
        participantID: String
    ) async -> AsyncChallenge? {
        do {
            let normalizedMetadata = normalizeTimestamps(
                in: metadata,
                fields: ["createdAt", "expiresAt", "completedAt"]
            )
            let metadataDocument = try decodeExactDocument(
                ChallengeMetadataDocument.self,
                from: normalizedMetadata,
                expectedKeys: ChallengeMetadataDocument.expectedKeys
            )
            try metadataDocument.validate(
                forDocumentID: documentID,
                accountID: participantID
            )

            let challengeReference = Firestore.firestore()
                .collection("challenges")
                .document(documentID)
            async let ownSnapshot = getDocument(
                challengeReference.collection("submissions").document(participantID)
            )
            async let combinedSnapshot = getDocument(
                challengeReference.collection("combined").document("result")
            )
            guard let ownDocumentSnapshot = try await ownSnapshot,
                  let combinedDocumentSnapshot = try await combinedSnapshot else {
                throw SocialAuthorityError.invalidResponse
            }

            let ownSubmission: ChallengeOwnSubmissionDocument? = try ownDocumentSnapshot
                .data()
                .map {
                    let normalized = normalizeTimestamps(
                        in: $0,
                        fields: ["submittedAt", "reactedAt"]
                    )
                    return try decodeExactDocument(
                        ChallengeOwnSubmissionDocument.self,
                        from: normalized,
                        expectedKeys: ChallengeOwnSubmissionDocument.expectedKeys
                    )
                }
            let combinedResult: ChallengeCombinedResultDocument? = try combinedDocumentSnapshot
                .data()
                .map {
                    let normalized = normalizeTimestamps(
                        in: $0,
                        fields: [
                            "creatorSubmittedAt", "creatorReactedAt",
                            "opponentSubmittedAt", "opponentReactedAt",
                            "completedAt",
                        ]
                    )
                    return try decodeExactDocument(
                        ChallengeCombinedResultDocument.self,
                        from: normalized,
                        expectedKeys: ChallengeCombinedResultDocument.expectedKeys
                    )
                }
            return try ChallengeDocumentHydrator.hydrate(
                metadata: metadataDocument,
                ownSubmission: ownSubmission,
                combinedResult: combinedResult,
                accountID: participantID
            )
        } catch {
            return nil
        }
    }

    /// Admin-authored documents use Firestore Timestamp while legacy client
    /// documents stored numeric seconds. Normalize both to the numeric wire
    /// representation consumed by the existing JSON decoder.
    func normalizeTimestamps(
        in document: [String: Any],
        fields: [String]
    ) -> [String: Any] {
        var normalized = document
        for field in fields {
            if let timestamp = normalized[field] as? Timestamp {
                normalized[field] = timestamp.dateValue().timeIntervalSince1970
            }
        }
        return normalized
    }
}
#endif
