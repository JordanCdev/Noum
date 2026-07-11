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
}

enum BackendBootstrapFetchResult {
    /// The backend answered successfully. A nil profile in this payload is a
    /// confirmed absence and may legitimately lead to onboarding.
    case success(BackendBootstrap)
    /// Configuration, transport, authorization, or decoding did not produce
    /// an authoritative answer. This must never be treated as an empty account.
    case unavailable
}

private struct RecommendationSyncPayload: Codable {
    let pendingExposure: RecommendationExposure?
    let outcomes: [RecommendationOutcome]
}

actor BackendSyncManager {
    static let shared = BackendSyncManager()
    static let functionsRegion = SocialAuthorityCallable.region
    static let deleteAccountFunctionName = "deleteAccount"
    static let recordPeerSessionFunctionName = SocialAuthorityCallable.recordPeerSession
    static let createChallengeFunctionName = SocialAuthorityCallable.createChallenge
    static let submitChallengeResultFunctionName = SocialAuthorityCallable.submitChallengeResult
    static let setChallengeReactionFunctionName = SocialAuthorityCallable.setChallengeReaction

    private init() {}

    nonisolated static func authorizedChallengeParticipantID(
        requestedID: String,
        firebaseUID: String?
    ) -> String? {
        guard let firebaseUID, requestedID == firebaseUID else { return nil }
        return firebaseUID
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
        providerRawValue: String
    ) async {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            await syncFirebaseRecommendationState(
                pendingExposure: pendingExposure,
                outcomes: outcomes,
                accountID: accountID,
                providerRawValue: providerRawValue
            )
            return
        }
#endif
        try? await send(
            RecommendationSyncPayload(
                pendingExposure: pendingExposure,
                outcomes: outcomes
            ),
            path: "/v1/me/recommendations",
            accountID: accountID,
            providerRawValue: providerRawValue
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
            let nsError = error as NSError
            guard nsError.domain == FunctionsErrorDomain,
                  let code = FunctionsErrorCode(rawValue: nsError.code) else {
                throw BackendAccountDeletionError.serviceUnavailable
            }
            switch code {
            case .unauthenticated:
                throw BackendAccountDeletionError.requiresRecentAuthentication
            case .failedPrecondition:
                throw BackendAccountDeletionError.appleRevocationUnavailable
            case .unavailable, .deadlineExceeded, .cancelled:
                throw BackendAccountDeletionError.serviceUnavailable
            default:
                throw BackendAccountDeletionError.rejected
            }
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

    /// Fetch a peer's public-readable snapshot. Returns nil if the peer
    /// hasn't synced yet, the network failed, or the doc is missing.
    func fetchPublicProfile(accountID: String) async -> PublicProfileSnapshot? {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            return await fetchFirebasePublicProfile(accountID: accountID)
        }
#endif
        return nil
    }

    /// Read the top members of a league bucket, ordered by rating descending.
    /// Caller is responsible for clamping to a UI-friendly count.
    func fetchLeagueMembers(bucket: String, limit: Int = 20) async -> [PublicProfileSnapshot] {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            return await fetchFirebaseLeagueMembers(bucket: bucket, limit: limit)
        }
#endif
        return []
    }

    func createChallenge(_ request: CreateChallengeRequest) async throws -> ChallengeMutationAuthorityResult {
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
    func fetchAsyncChallenges(forParticipant participantID: String) async -> [AsyncChallenge] {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            return await fetchFirebaseAsyncChallenges(forParticipant: participantID)
        }
#endif
        return []
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
               reason: socialAuthorityFailureReason(from: nsError)
           ) {
            return capabilityFailure
        }
        switch code {
        case .unauthenticated:
            return .unauthenticated
        case .invalidArgument:
            return .invalidRequest
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

    nonisolated private static func socialAuthorityFailureReason(from error: NSError) -> String? {
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
            return
        }

        request.httpBody = try JSONEncoder().encode(payload)
        _ = try await URLSession.shared.data(for: request)
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

            guard let profileSnapshot else { return .unavailable }
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
            let recommendationPending = try decodeDocument(
                RecommendationExposure.self,
                from: recommendationStateSnapshot?.data()?["pendingExposure"] as? [String: Any]
            )
            let recommendationOutcomes = try decodeArray(
                RecommendationOutcome.self,
                from: recommendationStateSnapshot?.data()?["outcomes"] as? [[String: Any]]
            )

            return .success(BackendBootstrap(
                xp: xp,
                profile: profile,
                sessions: sessions.isEmpty ? nil : sessions,
                recommendationPending: recommendationPending,
                recommendationOutcomes: recommendationOutcomes.isEmpty ? nil : recommendationOutcomes
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
    ) async {
        do {
            await ensureFirebaseUserDocument(accountID: accountID, providerRawValue: providerRawValue)
            let pendingData = try pendingExposure.map(encodeDocument)
            let outcomesData = try outcomes.map(encodeDocument)
            try await setDocument(
                userDocument(accountID: accountID).collection("recommendations").document("state"),
                data: [
                    "pendingExposure": pendingData as Any,
                    "outcomes": outcomesData
                ],
                merge: true
            )
        } catch { print("[BackendSync] Error: \(error.localizedDescription)") }
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

    // MARK: - Peer (M2: Peer Pull v1)

    func fetchFirebasePublicProfile(accountID: String) async -> PublicProfileSnapshot? {
        do {
            let snapshot = try await getDocument(
                Firestore.firestore().collection("profiles_public").document(accountID)
            )
            let data = snapshot?.data().map { normalizeTimestamps(in: $0, fields: ["updatedAt"]) }
            return try decodeDocument(PublicProfileSnapshot.self, from: data)
        } catch {
            return nil
        }
    }

    func fetchFirebaseLeagueMembers(bucket: String, limit: Int) async -> [PublicProfileSnapshot] {
        do {
            let documents = try await getDocuments(
                Firestore.firestore()
                    .collection("leagues").document(bucket)
                    .collection("members")
                    .order(by: "rating", descending: true)
                    .limit(to: limit)
            )
            return documents.compactMap {
                let data = normalizeTimestamps(in: $0.data(), fields: ["updatedAt"])
                return try? decodeDocument(PublicProfileSnapshot.self, from: data)
            }.compactMap { $0 }
        } catch {
            return []
        }
    }

    func fetchFirebaseAsyncChallenges(forParticipant participantID: String) async -> [AsyncChallenge] {
        #if canImport(FirebaseAuth)
        // Firestore rules prove query safety from `request.auth.uid in
        // participantIDs`. Refuse a legacy local UUID here rather than issuing
        // a query that can never satisfy that authorization contract.
        guard Self.authorizedChallengeParticipantID(
            requestedID: participantID,
            firebaseUID: Auth.auth().currentUser?.uid
        ) != nil else { return [] }
        #endif
        do {
            let documents = try await getDocuments(
                Firestore.firestore().collection("challenges")
                    .whereField("participantIDs", arrayContains: participantID)
                    .order(by: "createdAt", descending: true)
                    .limit(to: 50)
            )
            return documents.compactMap { document -> AsyncChallenge? in
                var raw = normalizeTimestamps(
                    in: document.data(),
                    fields: ["createdAt", "expiresAt"]
                )
                raw.removeValue(forKey: "participantIDs")
                return (try? decodeDocument(AsyncChallenge.self, from: raw)) ?? nil
            }
        } catch {
            return []
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
