import Foundation
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

struct BackendBootstrap: Codable {
    let xp: Int?
    let profile: CoachingProfile?
    let sessions: [PracticeSession]?
    let recommendationPending: RecommendationExposure?
    let recommendationOutcomes: [RecommendationOutcome]?
}

private struct RecommendationSyncPayload: Codable {
    let pendingExposure: RecommendationExposure?
    let outcomes: [RecommendationOutcome]
}

actor BackendSyncManager {
    static let shared = BackendSyncManager()

    private init() {}

    var isConfigured: Bool {
        firebaseIsConfigured || baseURL != nil
    }

    func fetchBootstrap(accountID: String, providerRawValue: String) async -> BackendBootstrap? {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            return await fetchFirebaseBootstrap(accountID: accountID, providerRawValue: providerRawValue)
        }
#endif
        guard let request = request(
            path: "/v1/me/bootstrap",
            method: "GET",
            accountID: accountID,
            providerRawValue: providerRawValue
        ) else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                return nil
            }
            return try JSONDecoder().decode(BackendBootstrap.self, from: data)
        } catch {
            return nil
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

    func deleteAccount(accountID: String, providerRawValue: String) async {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            await deleteFirebaseAccount(accountID: accountID)
            return
        }
#endif
        // REST backend path: send a DELETE request to remove server-side data
        guard let request = request(
            path: "/v1/me",
            method: "DELETE",
            accountID: accountID,
            providerRawValue: providerRawValue
        ) else {
            return
        }
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - Peer (M2: Peer Pull v1)

    /// Write the public-readable subset of the user's stats. Called whenever
    /// a session changes rating, streak, or weekly reps.
    func syncPublicProfile(_ snapshot: PublicProfileSnapshot) async {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            await syncFirebasePublicProfile(snapshot)
            return
        }
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

    /// Write the user's league snapshot for the current tier+week bucket.
    func syncLeagueMember(snapshot: PublicProfileSnapshot, bucket: String) async {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            await syncFirebaseLeagueMember(snapshot, bucket: bucket)
            return
        }
#endif
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

    /// Write the user's own slice of an async challenge. The doc is shared
    /// between two participants and writers are limited (by Firestore rules)
    /// to setting only their own fields.
    func syncAsyncChallenge(_ challenge: AsyncChallenge) async {
#if canImport(FirebaseFirestore)
        if firebaseIsConfigured {
            await syncFirebaseAsyncChallenge(challenge)
            return
        }
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

    private func send<Payload: Encodable>(
        _ payload: Payload,
        path: String,
        accountID: String,
        providerRawValue: String
    ) async throws {
        guard var request = request(
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
    ) -> URLRequest? {
        guard let baseURL else { return nil }
        let endpoint = baseURL.appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(accountID, forHTTPHeaderField: "X-Noum-Account-ID")
        request.setValue(providerRawValue, forHTTPHeaderField: "X-Noum-Auth-Provider")
        if let apiKey = backendAPIKey {
            request.setValue(apiKey, forHTTPHeaderField: "X-Noum-API-Key")
        }
        return request
    }

    private var baseURL: URL? {
        let rawValue =
            ProcessInfo.processInfo.environment["BACKEND_BASE_URL"] ??
            LocalConfigLoader.value(forKey: "BACKEND_BASE_URL", plistNamed: "BackendConfig")

        guard let rawValue, !rawValue.isEmpty else { return nil }
        return URL(string: rawValue)
    }

    private var backendAPIKey: String? {
        ProcessInfo.processInfo.environment["BACKEND_API_KEY"] ??
        LocalConfigLoader.value(forKey: "BACKEND_API_KEY", plistNamed: "BackendConfig")
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
    func fetchFirebaseBootstrap(accountID: String, providerRawValue: String) async -> BackendBootstrap? {
        let userRef = userDocument(accountID: accountID)
        await ensureFirebaseUserDocument(accountID: accountID, providerRawValue: providerRawValue)

        do {
            async let profileDocument = getDocument(userRef.collection("profile").document("main"))
            async let progressionDocument = getDocument(userRef.collection("progress").document("main"))
            async let sessionDocuments = getDocuments(
                userRef.collection("sessions").order(by: "date", descending: true).limit(to: 100)
            )
            async let recommendationStateDocument = getDocument(
                userRef.collection("recommendations").document("state")
            )

            let profileSnapshot = try await profileDocument
            let progressionSnapshot = try await progressionDocument
            let sessionSnapshots = try await sessionDocuments
            let recommendationStateSnapshot = try await recommendationStateDocument

            let profile = try decodeDocument(CoachingProfile.self, from: profileSnapshot?.data())
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

            return BackendBootstrap(
                xp: xp,
                profile: profile,
                sessions: sessions.isEmpty ? nil : sessions,
                recommendationPending: recommendationPending,
                recommendationOutcomes: recommendationOutcomes.isEmpty ? nil : recommendationOutcomes
            )
        } catch {
            return nil
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
            await ensureFirebaseUserDocument(accountID: accountID, providerRawValue: providerRawValue)
            let data = try encodeDocument(session)
            try await setDocument(
                userDocument(accountID: accountID).collection("sessions").document(session.id.uuidString),
                data: data,
                merge: true
            )
        } catch { print("[BackendSync] Error: \(error.localizedDescription)") }
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

    func deleteFirebaseAccount(accountID: String) async {
        let userRef = userDocument(accountID: accountID)
        do {
            // Paginate session deletion to handle accounts with >200 sessions
            let sessionsCollection = userRef.collection("sessions")
            var hasMore = true
            while hasMore {
                let batch = try await getDocuments(sessionsCollection.limit(to: 200))
                guard !batch.isEmpty else { break }
                try await deleteDocuments(batch.map(\.reference))
                hasMore = batch.count == 200
            }
            try await deleteDocument(userRef.collection("profile").document("main"))
            try await deleteDocument(userRef.collection("progress").document("main"))
            try await deleteDocument(userRef.collection("recommendations").document("state"))
            try await deleteDocument(userRef)

            // M2 peer surfaces. The public profile is the user's own doc.
            // League membership across past buckets and challenges where they
            // were a participant are pruned by best-effort delete: any doc
            // missing a participant becomes the opponent's snapshot only and
            // should be GC'd by a server-side cleanup job.
            try await deleteDocument(
                Firestore.firestore().collection("profiles_public").document(accountID)
            )
            await deleteParticipantSliceFromChallenges(accountID: accountID)
        } catch { print("[BackendSync] Error: \(error.localizedDescription)") }
    }

    /// Strip the user's own slice (scores, summary, reaction) from any
    /// shared challenge doc where they were a participant. We don't delete
    /// the challenge entirely — the opponent's data is still theirs.
    func deleteParticipantSliceFromChallenges(accountID: String) async {
        do {
            let documents = try await getDocuments(
                Firestore.firestore().collection("challenges")
                    .whereField("participantIDs", arrayContains: accountID)
                    .limit(to: 200)
            )
            for document in documents {
                let data = document.data()
                let creatorIDString = data["creatorAccountID"] as? String ?? data["creatorID"] as? String
                let isCreator = creatorIDString == accountID
                let nullifiedFields: [String: Any] = isCreator
                    ? [
                        "creatorScore": NSNull(),
                        "creatorDuration": NSNull(),
                        "creatorSummary": NSNull(),
                        "creatorReaction": NSNull(),
                        "creatorName": "Removed user"
                    ]
                    : [
                        "opponentScore": NSNull(),
                        "opponentDuration": NSNull(),
                        "opponentSummary": NSNull(),
                        "opponentReaction": NSNull(),
                        "opponentName": "Removed user"
                    ]
                try await setDocument(document.reference, data: nullifiedFields, merge: true)
            }
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

    func getDocument(_ reference: DocumentReference) async throws -> DocumentSnapshot? {
        try await withCheckedThrowingContinuation { continuation in
            reference.getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: snapshot)
                }
            }
        }
    }

    func getDocuments(_ query: Query) async throws -> [QueryDocumentSnapshot] {
        try await withCheckedThrowingContinuation { continuation in
            query.getDocuments { snapshot, error in
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

    func deleteDocument(_ reference: DocumentReference) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reference.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    func deleteDocuments(_ references: [DocumentReference]) async throws {
        for reference in references {
            try await deleteDocument(reference)
        }
    }

    // MARK: - Peer (M2: Peer Pull v1)

    func syncFirebasePublicProfile(_ snapshot: PublicProfileSnapshot) async {
        do {
            let data = try encodeDocument(snapshot)
            try await setDocument(
                Firestore.firestore().collection("profiles_public").document(snapshot.accountID),
                data: data,
                merge: true
            )
        } catch { print("[BackendSync] Error: \(error.localizedDescription)") }
    }

    func fetchFirebasePublicProfile(accountID: String) async -> PublicProfileSnapshot? {
        do {
            let snapshot = try await getDocument(
                Firestore.firestore().collection("profiles_public").document(accountID)
            )
            return try decodeDocument(PublicProfileSnapshot.self, from: snapshot?.data())
        } catch {
            return nil
        }
    }

    func syncFirebaseLeagueMember(_ snapshot: PublicProfileSnapshot, bucket: String) async {
        do {
            let data = try encodeDocument(snapshot)
            try await setDocument(
                Firestore.firestore()
                    .collection("leagues").document(bucket)
                    .collection("members").document(snapshot.accountID),
                data: data,
                merge: true
            )
        } catch { print("[BackendSync] Error: \(error.localizedDescription)") }
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
            return documents.compactMap { try? decodeDocument(PublicProfileSnapshot.self, from: $0.data()) }.compactMap { $0 }
        } catch {
            return []
        }
    }

    func syncFirebaseAsyncChallenge(_ challenge: AsyncChallenge) async {
        do {
            var data = try encodeDocument(challenge)
            // Index field so query-by-participant works without a composite index.
            data["participantIDs"] = challenge.participantIDs
            try await setDocument(
                Firestore.firestore().collection("challenges").document(challenge.id.uuidString),
                data: data,
                merge: true
            )
        } catch { print("[BackendSync] Error: \(error.localizedDescription)") }
    }

    func fetchFirebaseAsyncChallenges(forParticipant participantID: String) async -> [AsyncChallenge] {
        do {
            let documents = try await getDocuments(
                Firestore.firestore().collection("challenges")
                    .whereField("participantIDs", arrayContains: participantID)
                    .order(by: "createdAt", descending: true)
                    .limit(to: 50)
            )
            return documents.compactMap { document -> AsyncChallenge? in
                var raw = document.data()
                raw.removeValue(forKey: "participantIDs")
                return (try? decodeDocument(AsyncChallenge.self, from: raw)) ?? nil
            }
        } catch {
            return []
        }
    }
}
#endif
