import Foundation
import CoreFoundation
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
#if canImport(FirebaseSharedSwift)
import FirebaseSharedSwift
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
    /// Authentication failed before account-deletion transport could begin,
    /// or the checked callable rejected authentication before creating any
    /// deletion state. This is safe to surface as a normal reauthentication
    /// prompt only for the request prepared by the current invocation.
    case verifiedPreflightRequiresRecentAuthentication
    /// A legacy REST server returned 401 after receiving the DELETE request.
    /// Because that response is not durable completion evidence, it remains
    /// ambiguous and must keep the deletion fence closed.
    case requiresRecentAuthentication
    case appleRevocationUnavailable
    /// The checked callable proved that the guarded social-reference cutover
    /// is incomplete before it created deletion state or mutated account data.
    /// This may reopen admission only for the request started by the current
    /// deletion invocation; a resumed request remains ambiguous.
    case socialReferenceCutoverIncomplete
    case serviceUnavailable
    case rejected
    case invalidResponse
}

struct DeleteAccountCallableRequest: Codable, Sendable {
    static let schemaVersion = 2
    let schemaVersion: Int
    /// A request binding, never authority. The callable compares it with the
    /// verified `request.auth.uid` before performing any account work.
    let expectedAccountID: String
    let requestID: String

    init(expectedAccountID: String, requestID: UUID) {
        self.schemaVersion = Self.schemaVersion
        self.expectedAccountID = expectedAccountID
        self.requestID = requestID.uuidString
    }
}

private struct DeleteAccountCallableResponse: Codable, Sendable {
    let deleted: Bool
    let requestID: String
}

enum GrowthAggregateTransportError: Error, Equatable {
    case notConfigured
    case unauthenticated
    case invalidResponse
}

struct GrowthAggregateCallableRequest: Codable, Sendable {
    static let schemaVersion = GrowthAggregateBatch.schemaVersion

    let schemaVersion: Int
    let batchID: String
    let appVersion: String
    let buildNumber: String
    let generatedAtMilliseconds: Int64
    let periodStartMilliseconds: Int64
    let periodEndMilliseconds: Int64
    let activationCohortDay: String
    let eventCounts: [String: Int]
    let paywallSourceCounts: [String: Int]
    let planSelectionCounts: [String: Int]
    let trialEligibilityCounts: [String: Int]
    let inactiveReasonCounts: [String: Int]
    let notificationOpenCounts: [String: Int]
    let activeDayIndexCounts: [String: Int]
    let firstWrittenValueDurationBucketCounts: [String: Int]
    let secondPracticeWithin48HoursCount: Int
    let weeklyReadAmongDay1ReturnersCount: Int
    let estimatedAICostMicros: Int64
    let estimatedAICostCurrency: String
    let unpricedAIUsageCount: Int
    let aiBudgetReservationCount: Int

    init(batch: GrowthAggregateBatch) {
        schemaVersion = Self.schemaVersion
        batchID = batch.batchID.uuidString.lowercased()
        appVersion = batch.appVersion
        buildNumber = batch.buildNumber
        generatedAtMilliseconds = Self.milliseconds(batch.generatedAt)
        periodStartMilliseconds = Self.milliseconds(batch.periodStart)
        periodEndMilliseconds = Self.milliseconds(batch.periodEnd)
        activationCohortDay = batch.activationCohortDay
        eventCounts = Dictionary(uniqueKeysWithValues: batch.eventCounts.map {
            ($0.key.rawValue, $0.value)
        })
        paywallSourceCounts = Self.integerKeyed(batch.paywallSourceCounts)
        planSelectionCounts = Self.integerKeyed(batch.planSelectionCounts)
        trialEligibilityCounts = Self.integerKeyed(batch.trialEligibilityCounts)
        inactiveReasonCounts = Self.integerKeyed(batch.inactiveReasonCounts)
        notificationOpenCounts = Self.integerKeyed(batch.notificationOpenCounts)
        activeDayIndexCounts = Dictionary(uniqueKeysWithValues: batch.activeDayIndexCounts.map {
            (String($0.key), $0.value)
        })
        firstWrittenValueDurationBucketCounts = batch.firstWrittenValueDurationBucketCounts
        secondPracticeWithin48HoursCount = batch.secondPracticeWithin48HoursCount
        weeklyReadAmongDay1ReturnersCount = batch.weeklyReadAmongDay1ReturnersCount
        estimatedAICostMicros = batch.estimatedAICostMicros
        estimatedAICostCurrency = batch.estimatedAICostCurrency.rawValue
        unpricedAIUsageCount = batch.unpricedAIUsageCount
        aiBudgetReservationCount = batch.aiBudgetReservationCount
    }

    private static func milliseconds(_ date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1_000).rounded())
    }

    private static func integerKeyed<Key: RawRepresentable>(
        _ values: [Key: Int]
    ) -> [String: Int] where Key.RawValue == Int, Key: Hashable {
        Dictionary(uniqueKeysWithValues: values.map {
            (String($0.key.rawValue), $0.value)
        })
    }
}

private struct GrowthAggregateCallableResponse: Codable, Sendable {
    let accepted: Bool
    let duplicate: Bool
    let batchID: String
}

/// The only production implementation of `GrowthAggregateTransport`. Firebase
/// Auth and App Check protect the callable, but the request body deliberately
/// contains no UID, installation ID, device ID, event UUID, or user content.
struct BackendGrowthAggregateTransport: GrowthAggregateTransport {
    func upload(_ batch: GrowthAggregateBatch) async throws {
        try await BackendSyncManager.shared.uploadGrowthAggregate(batch)
    }
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
    /// Versioned Firebase documents carry the server CAS cursor. Legacy
    /// recommendation documents decode at revision zero; REST payloads that do
    /// not implement the contract leave this nil and cannot acknowledge writes.
    let recommendationRemoteRevision: Int?

    init(
        xp: Int?,
        profile: CoachingProfile?,
        sessions: [PracticeSession]?,
        recommendationPending: RecommendationExposure?,
        recommendationOutcomes: [RecommendationOutcome]?,
        recommendationStateExists: Bool? = nil,
        recommendationRemoteRevision: Int? = nil
    ) {
        self.xp = xp
        self.profile = profile
        self.sessions = sessions
        self.recommendationPending = recommendationPending
        self.recommendationOutcomes = recommendationOutcomes
        self.recommendationStateExists = recommendationStateExists
        self.recommendationRemoteRevision = recommendationRemoteRevision
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

struct RecommendationSyncCallableRequest: Codable, Sendable {
    static let schemaVersion = 2

    let schemaVersion: Int
    /// Request binding only. The callable must compare this with verified Auth
    /// before writing so an ambient Auth switch cannot redirect another
    /// account's recommendation state.
    let expectedAccountID: String
    let mutationID: UUID
    let expectedRemoteRevision: Int
    let pendingExposure: RecommendationExposure?
    let outcomes: [RecommendationOutcome]

    init(snapshot: RecommendationSyncSnapshot) {
        schemaVersion = Self.schemaVersion
        expectedAccountID = snapshot.accountID
        mutationID = snapshot.mutationID
        expectedRemoteRevision = snapshot.expectedRemoteRevision
        pendingExposure = snapshot.pendingExposure
        outcomes = snapshot.outcomes
    }
}

enum RecommendationSyncCallableStatus: String, Codable, Sendable {
    case committed
    case alreadyCommitted
    case conflict
}

struct RecommendationSyncRemoteState: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let remoteRevision: Int
    let lastMutationID: UUID?
    let pendingExposure: RecommendationExposure?
    let outcomes: [RecommendationOutcome]
}

struct RecommendationSyncCallableResponse: Codable, Sendable {
    let status: RecommendationSyncCallableStatus
    let state: RecommendationSyncRemoteState
}

struct RecommendationSyncSnapshot: Equatable, Sendable {
    let pendingExposure: RecommendationExposure?
    let outcomes: [RecommendationOutcome]
    let accountID: String
    let providerRawValue: String
    let revision: Int
    let expectedRemoteRevision: Int
    let mutationID: UUID
    let sourceLifecycleGeneration: UInt64
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

private struct CoachingContentSyncLease: Equatable, Sendable {
    let accountID: String
    let providerRawValue: String
    let accountLifecycleGeneration: UInt64
    let consentReceipt: CloudProcessingConsent
    let allowsRecommendationHydration: Bool
}

private struct CoachingContentDrainAuthority: Equatable, Sendable {
    let providerRawValue: String
    let sourceLifecycleGeneration: UInt64
}

private enum CoachingContentMutationWriteOutcome {
    case committed
    /// The local source document disappeared or is a forbidden fixture. There
    /// is no payload left to retry; deletion sync remains a separate contract.
    case discard
    /// Identity, hydration, consent, deletion, or promotion admission is not
    /// currently open. Retain every journal entry for an explicit later retry.
    case paused
    /// The transport or encoding failed. Retain this exact entry, but allow a
    /// different document in the same pass to make progress.
    case retry
}

actor BackendSyncManager {
    static let shared = BackendSyncManager()
    static let functionsRegion = SocialAuthorityCallable.region
    static let deleteAccountFunctionName = "deleteAccount"
    static let syncRecommendationStateFunctionName = "syncRecommendationState"
    static let recordGrowthAggregateFunctionName = "recordGrowthAggregate"
    static let beginCompetitiveObservationFunctionName = SocialAuthorityCallable.beginCompetitiveObservation
    static let completeCompetitiveObservationFunctionName = SocialAuthorityCallable.completeCompetitiveObservation
    static let recordPeerSessionFunctionName = SocialAuthorityCallable.recordPeerSession
    static let getPeerProfileFunctionName = SocialAuthorityCallable.getPeerProfile
    static let listLeagueMembersFunctionName = SocialAuthorityCallable.listLeagueMembers
    static let createChallengeFunctionName = SocialAuthorityCallable.createChallenge
    static let submitChallengeResultFunctionName = SocialAuthorityCallable.submitChallengeResult
    static let setChallengeReactionFunctionName = SocialAuthorityCallable.setChallengeReaction
    static let createFriendInviteFunctionName = SocialAuthorityCallable.createFriendInvite
    static let acceptFriendInviteFunctionName = SocialAuthorityCallable.acceptFriendInvite
    static let listFriendLinksFunctionName = SocialAuthorityCallable.listFriendLinks
    static let removeFriendLinkFunctionName = SocialAuthorityCallable.removeFriendLink
    static let appleRevocationUnavailableReason = "apple-revocation-unavailable"
    static let socialReferenceCutoverIncompleteReason = "social-reference-cutover-incomplete"
    static let recommendationSyncWaitNanoseconds: UInt64 = 4_000_000_000
    static let coachingContentSyncWaitNanoseconds: UInt64 = 4_000_000_000

    private var recommendationSyncLanes: [String: RecommendationSyncLane] = [:]
    private var recommendationSyncClosedAccounts: Set<String> = []
    private var recommendationHydrationTokens: [String: UUID] = [:]
    private var recommendationHydrationPending: [String: RecommendationSyncSnapshot] = [:]
    nonisolated private let coachingContentSyncJournal: CoachingContentSyncJournal
    private var activeCoachingContentDrainAccounts: Set<String> = []
    private var coachingContentSyncClosedAccounts: Set<String> = []
    private var coachingContentDrainIdleWaiters: [
        String: [CheckedContinuation<Void, Never>]
    ] = [:]
    private var requestedCoachingContentDrainAuthority: [
        String: CoachingContentDrainAuthority
    ] = [:]

    private init() {
        coachingContentSyncJournal = CoachingContentSyncJournal()
    }

    /// BackendSyncManager's process-local lane state is intentionally not
    /// durable. Every recommendation admission therefore reuses AuthManager's
    /// Keychain-backed deletion authority so relaunch cannot reopen transport.
    private func durableRecommendationProviderWorkAllowed(
        for accountID: String
    ) async -> Bool {
        await MainActor.run {
            AuthManager.shared.isProviderWorkAllowed(for: accountID)
        }
    }

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
        let legacyKeys: Set<String> = ["pendingExposure", "outcomes"]
        let metadataKeys = ["schemaVersion", "remoteRevision", "lastMutationID"]
        let presentMetadataCount = metadataKeys.filter { data.keys.contains($0) }.count
        if presentMetadataCount == 0 {
            return Set(data.keys).isSubset(of: legacyKeys)
        }
        let versionedKeys = legacyKeys.union(metadataKeys).union(["updatedAt"])
        guard presentMetadataCount == metadataKeys.count,
              Set(data.keys).isSubset(of: versionedKeys),
              integerValue(data["schemaVersion"]) == RecommendationSyncRemoteState.schemaVersion,
              let remoteRevision = integerValue(data["remoteRevision"]),
              remoteRevision > 0,
              let mutation = data["lastMutationID"] as? String,
              UUID(uuidString: mutation) != nil else {
            return false
        }
        return true
    }

    nonisolated static func recommendationRemoteRevision(
        from data: [String: Any]?
    ) -> Int? {
        guard let data else { return 0 }
        guard recommendationStatePayloadIsWellFormed(data) else { return nil }
        return integerValue(data["remoteRevision"]) ?? 0
    }

    nonisolated private static func integerValue(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        guard CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite,
              double.rounded(.towardZero) == double,
              double >= Double(Int.min),
              double <= Double(Int.max) else { return nil }
        return number.intValue
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

    /// Persists retry intent synchronously before scheduling transport. The
    /// profile store remains the content owner; this records only its document
    /// identity and exact acknowledgement token.
    @discardableResult
    nonisolated func enqueueProfileSync(
        _ profile: CoachingProfile,
        accountID: String,
        providerRawValue: String,
        sourceLifecycleGeneration: UInt64
    ) -> Bool {
        _ = profile
        return enqueueCoachingContentSync(
            .profile,
            accountID: accountID,
            providerRawValue: providerRawValue,
            sourceLifecycleGeneration: sourceLifecycleGeneration
        )
    }

    @discardableResult
    nonisolated func enqueueXPSync(
        _ xp: Int,
        accountID: String,
        providerRawValue: String,
        sourceLifecycleGeneration: UInt64
    ) -> Bool {
        guard xp >= 0 else { return false }
        return enqueueCoachingContentSync(
            .progression,
            accountID: accountID,
            providerRawValue: providerRawValue,
            sourceLifecycleGeneration: sourceLifecycleGeneration
        )
    }

    @discardableResult
    nonisolated func enqueueSessionSync(
        _ session: PracticeSession,
        accountID: String,
        providerRawValue: String,
        sourceLifecycleGeneration: UInt64
    ) -> Bool {
        guard !session.isEvaluationFixture else { return false }
        return enqueueCoachingContentSync(
            .session(session.id),
            accountID: accountID,
            providerRawValue: providerRawValue,
            sourceLifecycleGeneration: sourceLifecycleGeneration
        )
    }

    nonisolated func coachingContentSyncJournalStatus(
        for accountID: String
    ) -> CoachingContentSyncJournalStatus {
        coachingContentSyncJournal.status(for: accountID)
    }

    /// Relaunch, hydration completion, foreground activation, and consent
    /// enablement all use this same retry trigger. Authority is reacquired by
    /// the actor; no persisted lifecycle or consent value is future authority.
    nonisolated func resumeCoachingContentSync(
        accountID: String,
        providerRawValue: String,
        sourceLifecycleGeneration: UInt64
    ) {
        guard Self.coachingContentSyncEnvelopeIsWellFormed(
            accountID: accountID,
            providerRawValue: providerRawValue
        ) else { return }
        Task {
            await requestCoachingContentDrain(
                accountID: accountID,
                authority: CoachingContentDrainAuthority(
                    providerRawValue: providerRawValue,
                    sourceLifecycleGeneration: sourceLifecycleGeneration
                )
            )
        }
    }

    @discardableResult
    nonisolated private func enqueueCoachingContentSync(
        _ documentID: CoachingContentDocumentID,
        accountID: String,
        providerRawValue: String,
        sourceLifecycleGeneration: UInt64
    ) -> Bool {
        guard Self.coachingContentSyncEnvelopeIsWellFormed(
            accountID: accountID,
            providerRawValue: providerRawValue
        ), coachingContentSyncJournal.enqueue(
            documentID,
            accountID: accountID
        ) != nil else {
            return false
        }
        resumeCoachingContentSync(
            accountID: accountID,
            providerRawValue: providerRawValue,
            sourceLifecycleGeneration: sourceLifecycleGeneration
        )
        return true
    }

    nonisolated private static func coachingContentSyncEnvelopeIsWellFormed(
        accountID: String,
        providerRawValue: String
    ) -> Bool {
        let normalizedAccountID = accountID.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        return !normalizedAccountID.isEmpty
            && !providerRawValue.isEmpty
            && AuthManager.shouldSyncBackend(accountID: normalizedAccountID)
    }

    /// Consent-gated synchronization reserved for the proved-empty anonymous
    /// target created by local-guest promotion. Every document enters the same
    /// durable queue as ordinary writes; this method succeeds only after the
    /// account queue is empty. Existing accounts must never call this as a
    /// blind whole-state consent flush.
    func syncCoachingContentSnapshot(
        profile: CoachingProfile?,
        xp: Int,
        sessions: [PracticeSession],
        accountID: String,
        providerRawValue: String,
        sourceLifecycleGeneration: UInt64
    ) async -> Bool {
        guard await acquireCoachingContentSyncLease(
            accountID: accountID,
            providerRawValue: providerRawValue,
            expectedLifecycleGeneration: sourceLifecycleGeneration
        ) != nil,
              !Task.isCancelled else { return false }

        var documentIDs: [CoachingContentDocumentID] = [.progression]
        if profile != nil { documentIDs.append(.profile) }
        documentIDs.append(contentsOf: sessions.compactMap { session in
            session.isEvaluationFixture ? nil : .session(session.id)
        })
        let enqueued = coachingContentSyncJournal.enqueue(
            documentIDs,
            accountID: accountID
        )
        guard enqueued.count == Set(documentIDs).count else { return false }

        let race = RecommendationSyncWaitRace()
        let authority = CoachingContentDrainAuthority(
            providerRawValue: providerRawValue,
            sourceLifecycleGeneration: sourceLifecycleGeneration
        )
        Task {
            await requestCoachingContentDrain(
                accountID: accountID,
                authority: authority
            )
            await race.resolve(
                coachingContentSyncJournal.status(for: accountID) == .clean
            )
        }
        Task {
            try? await Task.sleep(
                nanoseconds: Self.coachingContentSyncWaitNanoseconds
            )
            await race.resolve(false)
        }
        return await race.wait()
    }

    func syncRecommendationState(
        pendingExposure: RecommendationExposure?,
        outcomes: [RecommendationOutcome],
        accountID: String,
        providerRawValue: String,
        revision: Int,
        expectedRemoteRevision: Int,
        mutationID: UUID,
        sourceLifecycleGeneration: UInt64
    ) async {
        let hydrationAdmission = recommendationHydrationTokens[accountID] != nil
        guard await acquireCoachingContentSyncLease(
                accountID: accountID,
                providerRawValue: providerRawValue,
                expectedLifecycleGeneration: sourceLifecycleGeneration,
                allowsRecommendationHydration: hydrationAdmission
              ) != nil,
              !recommendationSyncClosedAccounts.contains(accountID) else { return }
        let snapshot = RecommendationSyncSnapshot(
            pendingExposure: pendingExposure,
            outcomes: outcomes,
            accountID: accountID,
            providerRawValue: providerRawValue,
            revision: revision,
            expectedRemoteRevision: expectedRemoteRevision,
            mutationID: mutationID,
            sourceLifecycleGeneration: sourceLifecycleGeneration
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

    /// Sends one already-sanitized aggregate batch. The active account is
    /// checked locally against Firebase Auth for consent/lifecycle coherence,
    /// but is intentionally omitted from the callable payload and storage.
    func uploadGrowthAggregate(_ batch: GrowthAggregateBatch) async throws {
#if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else {
            throw GrowthAggregateTransportError.notConfigured
        }
        guard let accountID = await MainActor.run(body: {
            AuthManager.shared.currentAccountID
        }), AuthManager.shouldSyncBackend(accountID: accountID) else {
            throw GrowthAggregateTransportError.unauthenticated
        }
        do {
            try requireFirebaseAccount(accountID)
        } catch {
            throw GrowthAggregateTransportError.unauthenticated
        }
        let request = GrowthAggregateCallableRequest(batch: batch)
        let functions = Functions.functions(region: Self.functionsRegion)
        let callable: Callable<
            GrowthAggregateCallableRequest,
            GrowthAggregateCallableResponse
        > = functions.httpsCallable(Self.recordGrowthAggregateFunctionName)
        let response = try await callable.call(request)
        guard response.accepted,
              response.batchID.caseInsensitiveCompare(request.batchID) == .orderedSame else {
            throw GrowthAggregateTransportError.invalidResponse
        }
#else
        _ = batch
        throw GrowthAggregateTransportError.notConfigured
#endif
    }

    nonisolated static func shouldSyncCoachingContent(
        accountID: String,
        cloudProcessingAllowed: Bool
    ) -> Bool {
        cloudProcessingAllowed
            && AuthManager.shouldSyncBackend(accountID: accountID)
    }

    private func coachingContentSyncAllowed(
        for accountID: String
    ) async -> Bool {
        let providerRawValue: String? = await MainActor.run { () -> String? in
            let auth = AuthManager.shared
            guard auth.currentAccountID == accountID else { return nil }
            return auth.currentAuthProviderRawValue
        }
        guard let providerRawValue else { return false }
        return await acquireCoachingContentSyncLease(
            accountID: accountID,
            providerRawValue: providerRawValue
        ) != nil
    }

    nonisolated static func coachingContentSyncAuthorityMatches(
        requestedAccountID: String,
        requestedProviderRawValue: String,
        sourceLifecycleGeneration: UInt64?,
        currentAccountID: String?,
        currentProviderRawValue: String?,
        currentLifecycleGeneration: UInt64,
        hydrationReady: Bool,
        providerWorkAllowed: Bool,
        cloudProcessingAllowed: Bool,
        firebaseIsConfigured: Bool,
        firebaseUID: String?
    ) -> Bool {
        shouldSyncCoachingContent(
            accountID: requestedAccountID,
            cloudProcessingAllowed: cloudProcessingAllowed
        )
            && !requestedProviderRawValue.isEmpty
            && currentAccountID == requestedAccountID
            && currentProviderRawValue == requestedProviderRawValue
            && (sourceLifecycleGeneration == nil
                || sourceLifecycleGeneration == currentLifecycleGeneration)
            && hydrationReady
            && providerWorkAllowed
            && (!firebaseIsConfigured || firebaseUID == requestedAccountID)
    }

    private func acquireCoachingContentSyncLease(
        accountID: String,
        providerRawValue: String,
        expectedLifecycleGeneration: UInt64? = nil,
        allowsRecommendationHydration: Bool = false
    ) async -> CoachingContentSyncLease? {
        let state = await MainActor.run { () -> (
            currentAccountID: String?,
            currentProviderRawValue: String?,
            hydrationState: InitialAccountHydrationState,
            providerWorkAllowed: Bool,
            lifecycleGeneration: UInt64,
            consentReceipt: CloudProcessingConsent?
        ) in
            let auth = AuthManager.shared
            return (
                currentAccountID: auth.currentAccountID,
                currentProviderRawValue: auth.currentAuthProviderRawValue,
                hydrationState: auth.initialAccountHydrationState,
                providerWorkAllowed: auth.isProviderWorkAllowed(for: accountID),
                lifecycleGeneration: auth.accountLifecycleGeneration,
                consentReceipt: AISettingsManager.shared
                    .currentCloudProcessingReceipt(for: accountID)
            )
        }
        #if canImport(FirebaseAuth)
        let firebaseUID = firebaseIsConfigured ? Auth.auth().currentUser?.uid : nil
        #else
        let firebaseUID: String? = nil
        #endif
        let hydrationReady = state.hydrationState == .ready
            || (allowsRecommendationHydration
                && state.hydrationState == .hydratingStores
                && recommendationHydrationTokens[accountID] != nil)
        guard let consentReceipt = state.consentReceipt,
              Self.coachingContentSyncAuthorityMatches(
                requestedAccountID: accountID,
                requestedProviderRawValue: providerRawValue,
                sourceLifecycleGeneration: expectedLifecycleGeneration,
                currentAccountID: state.currentAccountID,
                currentProviderRawValue: state.currentProviderRawValue,
                currentLifecycleGeneration: state.lifecycleGeneration,
                hydrationReady: hydrationReady,
                providerWorkAllowed: state.providerWorkAllowed,
                cloudProcessingAllowed: true,
                firebaseIsConfigured: firebaseIsConfigured,
                firebaseUID: firebaseUID
              ) else {
            return nil
        }
        return CoachingContentSyncLease(
            accountID: accountID,
            providerRawValue: providerRawValue,
            accountLifecycleGeneration: state.lifecycleGeneration,
            consentReceipt: consentReceipt,
            allowsRecommendationHydration: allowsRecommendationHydration
        )
    }

    private func coachingContentSyncLeaseIsCurrent(
        _ lease: CoachingContentSyncLease
    ) async -> Bool {
        await acquireCoachingContentSyncLease(
            accountID: lease.accountID,
            providerRawValue: lease.providerRawValue,
            expectedLifecycleGeneration: lease.accountLifecycleGeneration,
            allowsRecommendationHydration: lease.allowsRecommendationHydration
        ) == lease
    }

    private func requestCoachingContentDrain(
        accountID: String,
        authority: CoachingContentDrainAuthority
    ) async {
        guard !coachingContentSyncClosedAccounts.contains(accountID) else {
            return
        }
        if let existing = requestedCoachingContentDrainAuthority[accountID],
           existing.sourceLifecycleGeneration > authority.sourceLifecycleGeneration {
            return
        }
        requestedCoachingContentDrainAuthority[accountID] = authority
        guard activeCoachingContentDrainAccounts.insert(accountID).inserted else {
            return
        }
        defer { finishCoachingContentDrain(accountID: accountID) }

        var attemptedMutationIDs: Set<UUID> = []
        while !Task.isCancelled {
            guard !coachingContentSyncClosedAccounts.contains(accountID) else {
                return
            }
            guard let mutations = coachingContentSyncJournal.pendingMutations(
                for: accountID,
                excluding: attemptedMutationIDs
            ) else {
                print("[BackendSync] Coaching-content journal is unreadable for this account.")
                return
            }
            guard let mutation = mutations.first,
                  let currentAuthority = requestedCoachingContentDrainAuthority[
                    accountID
                  ] else {
                return
            }
            attemptedMutationIDs.insert(mutation.mutationID)

            switch await writePendingCoachingContentMutation(
                mutation,
                accountID: accountID,
                authority: currentAuthority
            ) {
            case .committed, .discard:
                _ = coachingContentSyncJournal.acknowledge(
                    mutation,
                    accountID: accountID
                )
            case .paused:
                return
            case .retry:
                continue
            }
        }
    }

    private func writePendingCoachingContentMutation(
        _ mutation: PendingCoachingContentMutation,
        accountID: String,
        authority: CoachingContentDrainAuthority
    ) async -> CoachingContentMutationWriteOutcome {
        guard !coachingContentSyncClosedAccounts.contains(accountID),
              let lease = await acquireCoachingContentSyncLease(
            accountID: accountID,
            providerRawValue: authority.providerRawValue,
            expectedLifecycleGeneration: authority.sourceLifecycleGeneration
        ) else {
            return .paused
        }

        do {
            switch mutation.documentID {
            case .profile:
                guard let profile = CoachingProfileStore.persistedProfile(
                    for: accountID
                ) else {
                    return .discard
                }
                #if canImport(FirebaseFirestore)
                if firebaseIsConfigured {
                    try await writeFirebaseProfile(profile, lease: lease)
                } else {
                    try await send(
                        profile,
                        path: "/v1/me/profile",
                        lease: lease
                    )
                }
                #else
                try await send(profile, path: "/v1/me/profile", lease: lease)
                #endif
            case .progression:
                let xp = ProfileManager.persistedXP(for: accountID)
                #if canImport(FirebaseFirestore)
                if firebaseIsConfigured {
                    try await writeFirebaseXP(xp, lease: lease)
                } else {
                    try await send(
                        ["xp": xp],
                        path: "/v1/me/progression",
                        lease: lease
                    )
                }
                #else
                try await send(
                    ["xp": xp],
                    path: "/v1/me/progression",
                    lease: lease
                )
                #endif
            case .session(let sessionID):
                guard let session = PracticeSessionStore.persistedSession(
                    id: sessionID,
                    accountID: accountID
                ), !session.isEvaluationFixture else {
                    return .discard
                }
                #if canImport(FirebaseFirestore)
                if firebaseIsConfigured {
                    try await writeFirebaseSession(session, lease: lease)
                } else {
                    try await send(
                        session,
                        path: "/v1/me/sessions",
                        lease: lease
                    )
                }
                #else
                try await send(
                    session,
                    path: "/v1/me/sessions",
                    lease: lease
                )
                #endif
            }
            // Account deletion waits for this drain to become idle before it
            // advances to remote destruction. A write that was already in
            // flight may finish, but it must not be acknowledged after the
            // durable deletion fence has closed.
            guard !coachingContentSyncClosedAccounts.contains(accountID),
                  await coachingContentSyncLeaseIsCurrent(lease) else {
                return .paused
            }
            return .committed
        } catch {
            print("[BackendSync] Coaching-content retry retained: \(error.localizedDescription)")
            return .retry
        }
    }

    private func finishCoachingContentDrain(accountID: String) {
        activeCoachingContentDrainAccounts.remove(accountID)
        let waiters = coachingContentDrainIdleWaiters.removeValue(
            forKey: accountID
        ) ?? []
        waiters.forEach { $0.resume() }
    }

    private func waitUntilCoachingContentDrainIsIdle(
        accountID: String
    ) async {
        guard activeCoachingContentDrainAccounts.contains(accountID) else {
            return
        }
        await withCheckedContinuation { continuation in
            if activeCoachingContentDrainAccounts.contains(accountID) {
                coachingContentDrainIdleWaiters[
                    accountID,
                    default: []
                ].append(continuation)
            } else {
                continuation.resume()
            }
        }
    }

    /// Closes local admission and waits for any direct content write to
    /// settle before account deletion is allowed to reach its remote phase.
    /// Pending journal metadata is retained until the account registry owns
    /// verified local cleanup.
    func suspendCoachingContentSyncForDeletion(
        accountID: String
    ) async -> Bool {
        coachingContentSyncClosedAccounts.insert(accountID)
        requestedCoachingContentDrainAuthority.removeValue(forKey: accountID)
        guard activeCoachingContentDrainAccounts.contains(accountID) else {
            return true
        }
        let didClose = await Self.boundedRecommendationSyncWait {
            await self.waitUntilCoachingContentDrainIsIdle(
                accountID: accountID
            )
            return true
        }
        if !didClose {
            // Deletion has not advanced beyond local admission. Reopen only
            // this process-local gate; the durable Auth fence still denies
            // transport until verified rollback or a later deletion retry.
            coachingContentSyncClosedAccounts.remove(accountID)
        }
        return didClose
    }

    func resumeCoachingContentSyncAfterFailedDeletion(accountID: String) {
        coachingContentSyncClosedAccounts.remove(accountID)
    }

    func fenceRecommendationSync(
        accountID: String,
        revision: Int,
        hydrationToken: UUID
    ) async -> Bool {
        guard recommendationHydrationTokens[accountID] == hydrationToken,
              !recommendationSyncClosedAccounts.contains(accountID) else {
            return false
        }
        let identity = await MainActor.run { () -> (String, UInt64)? in
            let auth = AuthManager.shared
            guard auth.currentAccountID == accountID,
                  let provider = auth.currentAuthProviderRawValue else {
                return nil
            }
            return (provider, auth.accountLifecycleGeneration)
        }
        guard let identity,
              await acquireCoachingContentSyncLease(
                accountID: accountID,
                providerRawValue: identity.0,
                expectedLifecycleGeneration: identity.1,
                allowsRecommendationHydration: true
              ) != nil else {
            return false
        }
        let lane = recommendationSyncLane(for: accountID)
        return await Self.boundedRecommendationSyncWait {
            await lane.fence(at: revision)
        }
    }

    func beginRecommendationHydration(
        accountID: String,
        hydrationToken: UUID
    ) async -> Bool {
        guard !recommendationSyncClosedAccounts.contains(accountID) else {
            return false
        }
        let identity = await MainActor.run { () -> (String, UInt64)? in
            let auth = AuthManager.shared
            guard auth.currentAccountID == accountID,
                  let provider = auth.currentAuthProviderRawValue else {
                return nil
            }
            return (provider, auth.accountLifecycleGeneration)
        }
        guard let identity else { return false }
        recommendationHydrationTokens[accountID] = hydrationToken
        guard await acquireCoachingContentSyncLease(
            accountID: accountID,
            providerRawValue: identity.0,
            expectedLifecycleGeneration: identity.1,
            allowsRecommendationHydration: true
        ) != nil else {
            recommendationHydrationTokens.removeValue(forKey: accountID)
            return false
        }
        return true
    }

    func finishRecommendationHydration(
        accountID: String,
        hydrationToken: UUID
    ) async {
        guard recommendationHydrationTokens[accountID] == hydrationToken else { return }
        guard !recommendationSyncClosedAccounts.contains(accountID),
              let pending = recommendationHydrationPending.removeValue(
                forKey: accountID
              ) else {
            recommendationHydrationTokens.removeValue(forKey: accountID)
            recommendationHydrationPending.removeValue(forKey: accountID)
            return
        }
        guard await acquireCoachingContentSyncLease(
            accountID: accountID,
            providerRawValue: pending.providerRawValue,
            expectedLifecycleGeneration: pending.sourceLifecycleGeneration,
            allowsRecommendationHydration: true
        ) != nil else {
            recommendationHydrationTokens.removeValue(forKey: accountID)
            recommendationHydrationPending[accountID] = pending
            return
        }
        let lane = recommendationSyncLane(for: accountID)
        await lane.enqueue(
            pending,
            allowAtWatermark: true
        )
        let drained = await Self.boundedRecommendationSyncWait {
            await lane.fence(at: pending.revision)
        }
        recommendationHydrationTokens.removeValue(forKey: accountID)
        if !drained {
            recommendationHydrationPending[accountID] = pending
        }
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
        } else {
            // `closeAndWait` marks the old lane closed before waiting for an
            // in-flight writer. A bounded timeout occurs before deletion has
            // advanced beyond local admission, so detach that closed lane and
            // reopen only the process-local gate. The durable Auth fence still
            // denies new work until the caller verifies safe rollback.
            recommendationSyncLanes.removeValue(forKey: accountID)
            recommendationSyncClosedAccounts.remove(accountID)
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
        let hydrationAdmission = recommendationHydrationTokens[
            snapshot.accountID
        ] != nil
        guard let lease = await acquireCoachingContentSyncLease(
                accountID: snapshot.accountID,
                providerRawValue: snapshot.providerRawValue,
                expectedLifecycleGeneration:
                    snapshot.sourceLifecycleGeneration,
                allowsRecommendationHydration: hydrationAdmission
              ),
              !recommendationSyncClosedAccounts.contains(snapshot.accountID) else {
            return false
        }
#if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth) && canImport(FirebaseSharedSwift)
        if firebaseIsConfigured {
            do {
                try requireFirebaseAccount(snapshot.accountID)
                let functions = Functions.functions(region: Self.functionsRegion)
                let callable: Callable<RecommendationSyncCallableRequest, RecommendationSyncCallableResponse> = functions
                    .httpsCallable(
                        Self.syncRecommendationStateFunctionName,
                        encoder: Self.recommendationCallableEncoder(),
                        decoder: Self.recommendationCallableDecoder()
                    )
                let response = try await callable.call(
                    RecommendationSyncCallableRequest(snapshot: snapshot)
                )
                // The callable suspension can overlap deletion admission. Do
                // not acknowledge or reconcile that response once the durable
                // fence has closed, even if the remote write won the race.
                guard await coachingContentSyncLeaseIsCurrent(lease),
                      !recommendationSyncClosedAccounts.contains(snapshot.accountID) else {
                    return false
                }
                return await applyRecommendationSyncResponse(response, to: snapshot)
            } catch {
                return false
            }
        }
#endif
        // The optional REST server is not present in this repository and its
        // legacy 2xx whole-state endpoint has no compare-and-swap contract.
        // Keep the durable dirty marker instead of acknowledging an overwrite.
        return false
    }

    private func applyRecommendationSyncResponse(
        _ response: RecommendationSyncCallableResponse,
        to snapshot: RecommendationSyncSnapshot
    ) async -> Bool {
        guard response.state.schemaVersion == RecommendationSyncRemoteState.schemaVersion,
              response.state.remoteRevision >= 0,
              response.state.outcomes.count <= 40 else {
            return false
        }
        switch response.status {
        case .committed:
            guard response.state.lastMutationID == snapshot.mutationID,
                  snapshot.expectedRemoteRevision < Int.max,
                  response.state.remoteRevision == snapshot.expectedRemoteRevision + 1 else {
                return false
            }
            await RecommendationLearningStore.shared.confirmCurrentStateSync(
                accountID: snapshot.accountID,
                revision: snapshot.revision,
                mutationID: snapshot.mutationID,
                remoteRevision: response.state.remoteRevision
            )
            return true
        case .alreadyCommitted:
            guard response.state.lastMutationID == snapshot.mutationID,
                  response.state.remoteRevision >= snapshot.expectedRemoteRevision else {
                return false
            }
            await RecommendationLearningStore.shared.confirmCurrentStateSync(
                accountID: snapshot.accountID,
                revision: snapshot.revision,
                mutationID: snapshot.mutationID,
                remoteRevision: response.state.remoteRevision
            )
            return true
        case .conflict:
            return await RecommendationLearningStore.shared.reconcileRemoteConflict(
                accountID: snapshot.accountID,
                pendingExposure: response.state.pendingExposure,
                outcomes: response.state.outcomes,
                remoteRevision: response.state.remoteRevision
            )
        }
    }

#if canImport(FirebaseFunctions) && canImport(FirebaseSharedSwift)
    nonisolated static func recommendationCallableEncoder() -> FirebaseDataEncoder {
        let encoder = FirebaseDataEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        return encoder
    }

    nonisolated static func recommendationCallableDecoder() -> FirebaseDataDecoder {
        let decoder = FirebaseDataDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
#endif

    func deleteAccount(
        accountID: String,
        providerRawValue: String,
        requestID: UUID = UUID()
    ) async throws -> BackendAccountDeletionOutcome {
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions)
        if firebaseIsConfigured {
            return try await deleteFirebaseAccountThroughCallable(
                expectedAccountID: accountID,
                requestID: requestID
            )
        }
        #endif

        // REST backend path: send a DELETE request to remove server-side data
        let request: URLRequest
        do {
            request = try await deletionRequest(
            path: "/v1/me",
            method: "DELETE",
            accountID: accountID,
            providerRawValue: providerRawValue
            )
        } catch let error as BackendAccountDeletionError {
            throw error
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
    private func deleteFirebaseAccountThroughCallable(
        expectedAccountID: String,
        requestID: UUID
    ) async throws -> BackendAccountDeletionOutcome {
        guard FirebaseApp.app() != nil else {
            throw BackendAccountDeletionError.notConfigured
        }
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw BackendAccountDeletionError.verifiedPreflightRequiresRecentAuthentication
        }
        guard user.uid == expectedAccountID else {
            // Never let a sign-out/sign-in interleave redirect account A's
            // durable deletion request through account B's Firebase token.
            throw BackendAccountDeletionError.verifiedPreflightRequiresRecentAuthentication
        }
        do {
            _ = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                user.getIDTokenForcingRefresh(true) { token, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else if let token {
                        continuation.resume(returning: token)
                    } else {
                        continuation.resume(
                            throwing: BackendAccountDeletionError
                                .verifiedPreflightRequiresRecentAuthentication
                        )
                    }
                }
            }
        } catch {
            throw BackendAccountDeletionError.verifiedPreflightRequiresRecentAuthentication
        }
        #endif
        #if canImport(FirebaseAuth)
        guard Auth.auth().currentUser?.uid == expectedAccountID else {
            // This is intentionally adjacent to callable construction and
            // dispatch. The versioned server request also binds and verifies
            // the expected UID because client checks alone are not atomic with
            // Firebase Functions attaching ambient auth.
            throw BackendAccountDeletionError.verifiedPreflightRequiresRecentAuthentication
        }
        #endif
        let request = DeleteAccountCallableRequest(
            expectedAccountID: expectedAccountID,
            requestID: requestID
        )
        do {
            let functions = Functions.functions(region: Self.functionsRegion)
            let callable: Callable<DeleteAccountCallableRequest, DeleteAccountCallableResponse> = functions
                .httpsCallable(Self.deleteAccountFunctionName)
            #if canImport(FirebaseAuth)
            guard Auth.auth().currentUser?.uid == expectedAccountID else {
                throw BackendAccountDeletionError.verifiedPreflightRequiresRecentAuthentication
            }
            #endif
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
            // The checked function performs every unauthenticated/recent-auth
            // rejection before it creates deletion state or starts work.
            return .verifiedPreflightRequiresRecentAuthentication
        case .failedPrecondition:
            switch functionsFailureReason(from: nsError) {
            case appleRevocationUnavailableReason:
                return .appleRevocationUnavailable
            case socialReferenceCutoverIncompleteReason:
                return .socialReferenceCutoverIncomplete
            default:
                return .rejected
            }
        case .unavailable, .deadlineExceeded, .cancelled:
            return .serviceUnavailable
        default:
            return .rejected
        }
    }
    #endif

    // MARK: - Peer (M2: Peer Pull v1)

    /// Opens the server-owned observation window before the microphone starts.
    /// The request contains exercise provenance but no transcript, score,
    /// duration, filler count, or rated result.
    func beginCompetitiveObservation(
        _ request: BeginCompetitiveObservationRequest,
        accountID: String
    ) async throws -> CompetitiveObservationBinding {
        guard SocialReleaseCapabilities.competitiveObservation.isAvailable else {
            throw SocialAuthorityError.verifiedEvidenceUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount(accountID)
        guard UUID(uuidString: request.sessionID) != nil else {
            throw SocialAuthorityError.invalidRequest
        }
        let response: BeginCompetitiveObservationResponse = try await callSocialAuthority(
            Self.beginCompetitiveObservationFunctionName,
            request: request
        )
        guard let sessionID = UUID(uuidString: request.sessionID) else {
            throw SocialAuthorityError.invalidRequest
        }
        return try response.binding(expectedSessionID: sessionID)
        #else
        throw SocialAuthorityError.notConfigured
        #endif
    }

    /// Sends only the bounded microphone bytes captured after a successful
    /// begin response. The server transcript is returned as an observation;
    /// no client-authored evaluation field exists in this request.
    func completeCompetitiveObservation(
        _ request: CompleteCompetitiveObservationRequest,
        accountID: String
    ) async throws -> CompetitiveObservationResult {
        guard SocialReleaseCapabilities.competitiveObservation.isAvailable else {
            throw SocialAuthorityError.verifiedEvidenceUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount(accountID)
        guard let sessionID = UUID(uuidString: request.sessionID) else {
            throw SocialAuthorityError.invalidRequest
        }
        let response: CompleteCompetitiveObservationResponse = try await callSocialAuthority(
            Self.completeCompetitiveObservationFunctionName,
            request: request
        )
        return try response.result(expectedSessionID: sessionID)
        #else
        throw SocialAuthorityError.notConfigured
        #endif
    }

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

    /// Creates a short-lived reciprocal invitation. The current Firebase UID
    /// is the inviting identity; no account identifier is accepted from UI.
    func createFriendInvite(
        displayName: String,
        accountID: String
    ) async throws -> FriendInviteAuthorityResult {
        guard SocialReleaseCapabilities.friendConnections.isAvailable else {
            throw SocialAuthorityError.friendAuthorizationUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount(accountID)
        let request = CreateFriendInviteRequest(displayName: displayName)
        guard request.isValid else { throw SocialAuthorityError.invalidRequest }
        let response: CreateFriendInviteResponse = try await callSocialAuthority(
            Self.createFriendInviteFunctionName,
            request: request
        )
        return try response.result()
        #else
        throw SocialAuthorityError.notConfigured
        #endif
    }

    /// Accepts an opaque invitation and trusts only the server-returned peer
    /// envelope. The token is never written by this backend client.
    func acceptFriendInvite(
        inviteToken: String,
        displayName: String,
        accountID: String
    ) async throws -> FriendAuthorityLink {
        guard SocialReleaseCapabilities.friendConnections.isAvailable else {
            throw SocialAuthorityError.friendAuthorizationUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount(accountID)
        let request = AcceptFriendInviteRequest(
            inviteToken: inviteToken,
            displayName: displayName
        )
        guard request.isValid else { throw SocialAuthorityError.invalidRequest }
        let response: AcceptFriendInviteResponse = try await callSocialAuthority(
            Self.acceptFriendInviteFunctionName,
            request: request
        )
        return try response.result(currentAccountID: accountID)
        #else
        throw SocialAuthorityError.notConfigured
        #endif
    }

    /// Lists the exact reciprocal set for the current caller. This is the only
    /// authoritative membership reconciliation input used by FriendsManager.
    func listFriendLinks(
        limit: Int = 50,
        accountID: String
    ) async throws -> [FriendAuthorityLink] {
        guard SocialReleaseCapabilities.friendConnections.isAvailable else {
            throw SocialAuthorityError.friendAuthorizationUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount(accountID)
        let request = ListFriendLinksRequest(limit: limit)
        guard request.isValid else { throw SocialAuthorityError.invalidRequest }
        let response: ListFriendLinksResponse = try await callSocialAuthority(
            Self.listFriendLinksFunctionName,
            request: request
        )
        return try response.result(
            requestedLimit: request.limit,
            currentAccountID: accountID
        )
        #else
        throw SocialAuthorityError.notConfigured
        #endif
    }

    /// Removes one reciprocal relationship. A false `removed` value is a
    /// successful idempotent response: the link is already absent server-side.
    func removeFriendLink(
        pairID: UUID,
        friendAccountID: String,
        accountID: String
    ) async throws -> FriendRemovalAuthorityResult {
        guard SocialReleaseCapabilities.friendConnections.isAvailable else {
            throw SocialAuthorityError.friendAuthorizationUnavailable
        }
        #if canImport(FirebaseCore) && canImport(FirebaseFunctions) && canImport(FirebaseAuth)
        guard firebaseIsConfigured else { throw SocialAuthorityError.notConfigured }
        try requireFirebaseAccount(accountID)
        let request = RemoveFriendLinkRequest(
            pairID: pairID,
            friendAccountID: friendAccountID
        )
        guard request.isValid, request.friendAccountID != accountID else {
            throw SocialAuthorityError.invalidRequest
        }
        let response: RemoveFriendLinkResponse = try await callSocialAuthority(
            Self.removeFriendLinkFunctionName,
            request: request
        )
        return try response.result(
            expectedPairID: request.pairID,
            expectedFriendAccountID: request.friendAccountID
        )
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
        lease: CoachingContentSyncLease
    ) async throws {
        guard await coachingContentSyncLeaseIsCurrent(lease),
              let baseURL,
              let headers = await BackendAuthHeaders.identityBound(
                accountID: lease.accountID,
                providerRawValue: lease.providerRawValue
              ) else {
            throw URLError(.unsupportedURL)
        }
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.apply(to: &request)
        request.httpBody = try JSONEncoder().encode(payload)
        guard await coachingContentSyncLeaseIsCurrent(lease) else {
            throw URLError(.userAuthenticationRequired)
        }
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

    private func deletionRequest(
        path: String,
        method: String,
        accountID: String,
        providerRawValue: String
    ) async throws -> URLRequest {
        guard let baseURL else {
            throw BackendAccountDeletionError.notConfigured
        }
        guard let headers = await BackendAuthHeaders.deletionBound(
            accountID: accountID,
            providerRawValue: providerRawValue
        ) else {
            throw BackendAccountDeletionError.verifiedPreflightRequiresRecentAuthentication
        }
        let endpoint = baseURL.appending(path: path)
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        headers.apply(to: &request)
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
                recommendationStateExists: recommendationStateSnapshot.exists,
                recommendationRemoteRevision: recommendationStateSnapshot.exists
                    ? Self.recommendationRemoteRevision(from: recommendationData)
                    : 0
            ))
        } catch {
            return .unavailable
        }
    }

    private func writeFirebaseProfile(
        _ profile: CoachingProfile,
        lease: CoachingContentSyncLease
    ) async throws {
        try await ensureFirebaseUserDocument(lease: lease)
        guard await coachingContentSyncLeaseIsCurrent(lease) else {
            throw URLError(.userAuthenticationRequired)
        }
        let data = try encodeDocument(profile)
        try await setDocument(
            userDocument(accountID: lease.accountID)
                .collection("profile").document("main"),
            data: data,
            // Whole-profile replacement is intentional: Codable omits nil
            // optionals, and merge writes would otherwise preserve a voice,
            // goal reference, or coaching brief the user explicitly cleared.
            merge: false
        )
    }

    private func writeFirebaseXP(
        _ xp: Int,
        lease: CoachingContentSyncLease
    ) async throws {
        try await ensureFirebaseUserDocument(lease: lease)
        guard await coachingContentSyncLeaseIsCurrent(lease) else {
            throw URLError(.userAuthenticationRequired)
        }
        try await setDocument(
            userDocument(accountID: lease.accountID)
                .collection("progress").document("main"),
            data: ["xp": max(0, xp)],
            merge: false
        )
    }

    /// Throwing form reserved for a server-authority callable that must not
    /// run until its referenced session is durably visible to Functions.
    func syncFirebaseSessionForAuthority(
        _ session: PracticeSession,
        accountID: String,
        providerRawValue: String
    ) async throws {
        guard let lease = await acquireCoachingContentSyncLease(
            accountID: accountID,
            providerRawValue: providerRawValue
        ) else {
            throw URLError(.userAuthenticationRequired)
        }
        try await writeFirebaseSession(session, lease: lease)
    }

    private func writeFirebaseSession(
        _ session: PracticeSession,
        lease: CoachingContentSyncLease
    ) async throws {
        guard await coachingContentSyncLeaseIsCurrent(lease) else {
            throw URLError(.userAuthenticationRequired)
        }
        try await setDocument(
            userDocument(accountID: lease.accountID),
            data: [
                "accountID": lease.accountID,
                "provider": lease.providerRawValue,
                "updatedAt": Date().timeIntervalSince1970
            ],
            merge: true
        )
        guard await coachingContentSyncLeaseIsCurrent(lease) else {
            throw URLError(.userAuthenticationRequired)
        }
        let data = try encodeDocument(session)
        try await setDocument(
            userDocument(accountID: lease.accountID)
                .collection("sessions").document(session.id.uuidString),
            data: data,
            // Session annotations intentionally replace the complete row so a
            // cleared optional field cannot be resurrected by merge semantics.
            merge: false
        )
    }

    func ensureFirebaseUserDocument(
        lease: CoachingContentSyncLease
    ) async throws {
        guard await coachingContentSyncLeaseIsCurrent(lease) else {
            throw URLError(.userAuthenticationRequired)
        }
        try await setDocument(
            userDocument(accountID: lease.accountID),
            data: [
                "accountID": lease.accountID,
                "provider": lease.providerRawValue,
                "updatedAt": Date().timeIntervalSince1970
            ],
            merge: true
        )
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
