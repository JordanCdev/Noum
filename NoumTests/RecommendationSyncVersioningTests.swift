import Foundation
import Testing
@testable import Noum

@Suite("Recommendation sync versioning")
struct RecommendationSyncVersioningTests {
    @Test func legacyAndVersionedBootstrapMetadataStayDistinct() throws {
        let legacy = try JSONDecoder().decode(
            BackendBootstrap.self,
            from: Data("{\"recommendationStateExists\":true,\"recommendationOutcomes\":[]}".utf8)
        )
        let versioned = try JSONDecoder().decode(
            BackendBootstrap.self,
            from: Data("{\"recommendationStateExists\":true,\"recommendationRemoteRevision\":7,\"recommendationOutcomes\":[]}".utf8)
        )

        #expect(legacy.recommendationRemoteRevision == nil)
        #expect(versioned.recommendationRemoteRevision == 7)
        #expect(legacy.hasAuthoritativeRecommendationState)
        #expect(versioned.hasAuthoritativeRecommendationState)
    }

    @Test func firebaseMetadataAcceptsLegacyAndCompleteVersionedShapes() {
        let mutationID = UUID()
        let legacy: [String: Any] = [
            "pendingExposure": NSNull(),
            "outcomes": [],
        ]
        let versioned: [String: Any] = [
            "schemaVersion": 1,
            "remoteRevision": 4,
            "lastMutationID": mutationID.uuidString,
            "pendingExposure": NSNull(),
            "outcomes": [],
        ]

        #expect(BackendSyncManager.recommendationStatePayloadIsWellFormed(legacy))
        #expect(BackendSyncManager.recommendationRemoteRevision(from: legacy) == 0)
        #expect(BackendSyncManager.recommendationStatePayloadIsWellFormed(versioned))
        #expect(BackendSyncManager.recommendationRemoteRevision(from: versioned) == 4)
    }

    @Test func partialOrUnknownFirebaseMetadataFailsClosed() {
        let base: [String: Any] = [
            "pendingExposure": NSNull(),
            "outcomes": [],
        ]
        #expect(!BackendSyncManager.recommendationStatePayloadIsWellFormed(
            base.merging(["unexpected": true]) { _, rhs in rhs }
        ))
        #expect(!BackendSyncManager.recommendationStatePayloadIsWellFormed(
            base.merging(["schemaVersion": 1]) { _, rhs in rhs }
        ))
        #expect(!BackendSyncManager.recommendationStatePayloadIsWellFormed(
            base.merging([
                "schemaVersion": 2,
                "remoteRevision": 1,
                "lastMutationID": UUID().uuidString,
            ]) { _, rhs in rhs }
        ))
        #expect(!BackendSyncManager.recommendationStatePayloadIsWellFormed(
            base.merging([
                "schemaVersion": 1,
                "remoteRevision": 0,
                "lastMutationID": UUID().uuidString,
            ]) { _, rhs in rhs }
        ))
        #expect(!BackendSyncManager.recommendationStatePayloadIsWellFormed(
            base.merging([
                "schemaVersion": true,
                "remoteRevision": true,
                "lastMutationID": UUID().uuidString,
            ]) { _, rhs in rhs }
        ))
        #expect(!BackendSyncManager.recommendationStatePayloadIsWellFormed(
            base.merging([
                "schemaVersion": 1,
                "remoteRevision": 1,
                "lastMutationID": UUID().uuidString,
                "unexpected": true,
            ]) { _, rhs in rhs }
        ))
    }

    @Test func acknowledgementsRequireTheExactLocalRevisionAndMutation() {
        let mutationID = UUID()
        #expect(RecommendationLearningStore.acknowledgementMatches(
            expectedRevision: 4,
            currentRevision: 4,
            expectedMutationID: mutationID,
            currentMutationID: mutationID
        ))
        #expect(!RecommendationLearningStore.acknowledgementMatches(
            expectedRevision: 4,
            currentRevision: 5,
            expectedMutationID: mutationID,
            currentMutationID: mutationID
        ))
        #expect(!RecommendationLearningStore.acknowledgementMatches(
            expectedRevision: 4,
            currentRevision: 4,
            expectedMutationID: mutationID,
            currentMutationID: UUID()
        ))
    }

    @Test func conflictRetryIsBoundedToOneImmediateRebase() {
        #expect(RecommendationLearningStore.shouldRetryConflictImmediately(
            previousImmediateRetries: 0
        ))
        #expect(!RecommendationLearningStore.shouldRetryConflictImmediately(
            previousImmediateRetries: 1
        ))
        #expect(!RecommendationLearningStore.shouldRetryConflictImmediately(
            previousImmediateRetries: 2
        ))
    }

    @Test func identicalHydrationBodyPreservesCrashReplayIdentity() {
        let exposure = RecommendationExposure(
            fingerprint: "timed|fillers",
            title: "Clean the opening",
            focus: "Filler control",
            target: "Below 2 fillers/min",
            mode: .timed,
            isAIBacked: false,
            shownAt: Date(timeIntervalSince1970: 1_720_000_000)
        )
        #expect(!RecommendationLearningStore.reconciledStateDiffers(
            localPendingExposure: exposure,
            localOutcomes: [],
            reconciledPendingExposure: exposure,
            reconciledOutcomes: []
        ))
        #expect(RecommendationLearningStore.reconciledStateDiffers(
            localPendingExposure: exposure,
            localOutcomes: [],
            reconciledPendingExposure: nil,
            reconciledOutcomes: []
        ))
    }

    @MainActor @Test func remoteCursorKeysAreAccountScoped() {
        #expect(RecommendationLearningStore.remoteRevisionKey(for: "account-a") ==
            "recommendation.remoteRevision.account-a")
        #expect(RecommendationLearningStore.pendingMutationKey(for: "account-a") ==
            "recommendation.pendingMutationID.account-a")
        #expect(RecommendationLearningStore.remoteRevisionKey(for: nil) ==
            "recommendation.remoteRevision.guest")
    }

    @Test func callableRemoteStateRoundTripsMutationIdentity() throws {
        let mutationID = UUID()
        let state = RecommendationSyncRemoteState(
            schemaVersion: 1,
            remoteRevision: 3,
            lastMutationID: mutationID,
            pendingExposure: nil,
            outcomes: []
        )
        let decoded = try JSONDecoder().decode(
            RecommendationSyncRemoteState.self,
            from: JSONEncoder().encode(state)
        )

        #expect(decoded == state)
        #expect(decoded.lastMutationID == mutationID)
    }

#if canImport(FirebaseSharedSwift)
    @Test func callableWireDatesRoundTripAsUnixSeconds() throws {
        let shownAt = Date(timeIntervalSince1970: 1_720_000_123.5)
        let exposure = RecommendationExposure(
            fingerprint: "timed|fillers",
            title: "Clean the opening",
            focus: "Filler control",
            target: "Below 2 fillers/min",
            mode: .timed,
            isAIBacked: false,
            shownAt: shownAt,
            tappedAt: shownAt.addingTimeInterval(2)
        )
        let request = RecommendationSyncCallableRequest(snapshot: .init(
            pendingExposure: exposure,
            outcomes: [],
            accountID: "account-a",
            providerRawValue: "apple",
            revision: 2,
            expectedRemoteRevision: 1,
            mutationID: UUID()
        ))
        let encoded = try BackendSyncManager.recommendationCallableEncoder()
            .encode(request)
        let decoded = try BackendSyncManager.recommendationCallableDecoder()
            .decode(RecommendationSyncCallableRequest.self, from: encoded)

        #expect(decoded.pendingExposure?.shownAt == shownAt)
        let payload = try #require(encoded as? [String: Any])
        let pending = try #require(payload["pendingExposure"] as? [String: Any])
        #expect(pending["shownAt"] as? Double == shownAt.timeIntervalSince1970)
    }
#endif
}
