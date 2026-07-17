import Foundation
import Testing
@testable import Noum

@Suite("Recommendation deletion admission")
struct RecommendationDeletionAdmissionTests {
    @Test("Local sync admission and dirty bookkeeping use the durable fence")
    func localAdmissionUsesDurableFence() throws {
        let source = try source(named: "PracticeSupport.swift")

        let syncCurrentState = try sourceSlice(
            in: source,
            from: "    func syncCurrentState() {",
            to: "    @discardableResult\n    func reconcileRemoteConflict("
        )
        try expectOrdered([
            "AuthManager.shouldSyncBackend(accountID: accountID)",
            "AuthManager.shared.isProviderWorkAllowed(for: accountID)",
            "Self.unconfirmedSyncKey(for: accountID)",
            "syncIfPossible()",
        ], in: syncCurrentState)

        let syncIfPossible = try sourceSlice(
            in: source,
            from: "    private func syncIfPossible() {",
            to: "    private var currentRevisionScope: String {"
        )
        try expectOrdered([
            "AuthManager.shared.isProviderWorkAllowed(for: accountID)",
            "let mutationID = ensurePendingMutation()",
            "await previousTask?.value",
            "AuthManager.shared.isProviderWorkAllowed(for: accountID)",
            "BackendSyncManager.shared.syncRecommendationState("
        ], in: syncIfPossible)

        let advanceRevision = try sourceSlice(
            in: source,
            from: "    private func advanceStateRevision(",
            to: "    private func clearRemoteSyncBookkeeping("
        )
        try expectOrdered([
            "AuthManager.shouldSyncBackend(accountID: accountID)",
            "AuthManager.shared.isProviderWorkAllowed(for: accountID)",
            "persistPendingMutation(UUID())",
            "Self.unconfirmedSyncKey("
        ], in: advanceRevision)
    }

    @Test("Delayed response bookkeeping rechecks durable deletion admission")
    func delayedResponseBookkeepingUsesDurableFence() throws {
        let source = try source(named: "PracticeSupport.swift")

        let conflict = try sourceSlice(
            in: source,
            from: "    func reconcileRemoteConflict(",
            to: "    func waitForScheduledSyncs() async {"
        )
        #expect(conflict.contains(
            "AuthManager.shared.isProviderWorkAllowed(for: accountID)"
        ))

        let acknowledgement = try sourceSlice(
            in: source,
            from: "    func confirmCurrentStateSync(",
            to: "    nonisolated static func acknowledgementMatches("
        )
        try expectOrdered([
            "resolvedAccountID",
            "AuthManager.shared.isProviderWorkAllowed(for: resolvedAccountID)",
            "persistRemoteRevision(remoteRevision)",
            "clearPendingMutation()",
        ], in: acknowledgement)
    }

    @Test("Backend queue, hydration, and transport reuse exact content authority")
    func backendBoundariesUseDurableFence() throws {
        let source = try source(named: "BackendSyncManager.swift")

        let authority = try sourceSlice(
            in: source,
            from: "    private func acquireCoachingContentSyncLease(",
            to: "    private func coachingContentSyncLeaseIsCurrent("
        )
        try expectOrdered([
            "auth.currentAccountID",
            "auth.currentAuthProviderRawValue",
            "auth.initialAccountHydrationState",
            "auth.isProviderWorkAllowed(for: accountID)",
            "auth.accountLifecycleGeneration",
            "currentCloudProcessingReceipt(for: accountID)",
            "firebaseUID",
            "coachingContentSyncAuthorityMatches(",
        ], in: authority)

        let admission = try sourceSlice(
            in: source,
            from: "    func syncRecommendationState(",
            to: "    func fenceRecommendationSync("
        )
        try expectOrdered([
            "await acquireCoachingContentSyncLease(",
            "!recommendationSyncClosedAccounts.contains(accountID)",
            "let snapshot = RecommendationSyncSnapshot(",
            "await lane.enqueue(snapshot)",
        ], in: admission)

        for method in [
            "    func fenceRecommendationSync(",
            "    func beginRecommendationHydration(",
            "    func finishRecommendationHydration("
        ] {
            let start = try #require(source.range(of: method))
            let nextMethod = try #require(source.range(
                of: "\n    func ",
                range: start.upperBound..<source.endIndex
            ))
            let body = String(source[start.lowerBound..<nextMethod.lowerBound])
            #expect(body.contains("acquireCoachingContentSyncLease"))
        }

        let transport = try sourceSlice(
            in: source,
            from: "    private func writeRecommendationState(",
            to: "    private func applyRecommendationSyncResponse("
        )
        try expectOrdered([
            "let lease = await acquireCoachingContentSyncLease(",
            "callable.call(",
            "await coachingContentSyncLeaseIsCurrent(lease)",
            "applyRecommendationSyncResponse(response, to: snapshot)",
        ], in: transport)

        let suspension = try sourceSlice(
            in: source,
            from: "    func suspendRecommendationSyncForDeletion(",
            to: "    func resumeRecommendationSyncAfterFailedDeletion("
        )
        try expectOrdered([
            "recommendationSyncClosedAccounts.insert(accountID)",
            "await lane.closeAndWait()",
            "if didClose",
            "} else {",
            "recommendationSyncLanes.removeValue(forKey: accountID)",
            "recommendationSyncClosedAccounts.remove(accountID)",
        ], in: suspension)
    }

    @Test("Account deletion drains coaching content before remote destruction")
    func coachingContentDeletionBoundary() throws {
        let backend = try source(named: "BackendSyncManager.swift")
        let drain = try sourceSlice(
            in: backend,
            from: "    private func requestCoachingContentDrain(",
            to: "    private func writePendingCoachingContentMutation("
        )
        #expect(drain.contains(
            "!coachingContentSyncClosedAccounts.contains(accountID)"
        ))

        let write = try sourceSlice(
            in: backend,
            from: "    private func writePendingCoachingContentMutation(",
            to: "    private func finishCoachingContentDrain("
        )
        try expectOrdered([
            "let lease = await acquireCoachingContentSyncLease(",
            "switch mutation.documentID",
            "!coachingContentSyncClosedAccounts.contains(accountID)",
            "await coachingContentSyncLeaseIsCurrent(lease)",
            "return .committed",
        ], in: write)

        let suspension = try sourceSlice(
            in: backend,
            from: "    func suspendCoachingContentSyncForDeletion(",
            to: "    func resumeCoachingContentSyncAfterFailedDeletion("
        )
        try expectOrdered([
            "coachingContentSyncClosedAccounts.insert(accountID)",
            "requestedCoachingContentDrainAuthority.removeValue(forKey: accountID)",
            "await self.waitUntilCoachingContentDrainIsIdle(",
            "if !didClose",
            "coachingContentSyncClosedAccounts.remove(accountID)",
        ], in: suspension)

        let auth = try source(named: "AuthManager.swift")
        let deletion = try sourceSlice(
            in: auth,
            from: "    func deleteCurrentAccount() async throws {",
            to: "    private func persistedDeletionRecovery("
        )
        try expectOrdered([
            "accountLifecycleGeneration &+= 1",
            "backendSync.suspendCoachingContentSyncForDeletion(",
            "backendSync.suspendRecommendationSyncForDeletion(",
            "let outcome = try await backendSync.deleteAccount(",
        ], in: deletion)
    }

    private func source(named name: String) throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/\(name)"),
            encoding: .utf8
        )
    }

    private func sourceSlice(
        in source: String,
        from startNeedle: String,
        to endNeedle: String
    ) throws -> String {
        let start = try #require(source.range(of: startNeedle))
        let end = try #require(source.range(
            of: endNeedle,
            range: start.upperBound..<source.endIndex
        ))
        return String(source[start.lowerBound..<end.lowerBound])
    }

    private func expectOrdered(
        _ needles: [String],
        in source: String
    ) throws {
        var cursor = source.startIndex
        for needle in needles {
            let range = try #require(source.range(
                of: needle,
                range: cursor..<source.endIndex
            ))
            cursor = range.upperBound
        }
    }
}
