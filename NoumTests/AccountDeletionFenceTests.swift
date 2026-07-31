import Foundation
import Testing
@testable import Noum

@Suite("Account deletion admission fence")
struct AccountDeletionFenceTests {
    private let requestID = UUID(uuidString: "2cb446d8-4f39-43a6-a95c-2486e47155bc")!

    @Test("Every phase persists and read-verifies from the account key")
    func phaseRoundTrip() throws {
        let storage = MemoryFenceStorage()
        let repository = makeRepository(storage: storage)

        var fence = try repository.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        ).get()
        #expect(fence.accountID == "alpha")
        #expect(fence.providerRawValue == "google")
        #expect(fence.requestID == requestID)
        #expect(fence.phase == .admissionClosed)
        #expect(repository.lookup(for: "alpha") == .present(fence))

        for phase in [
            AccountDeletionFencePhase.remoteRequested,
            .remoteCommitted,
            .localCleanupStarted,
        ] {
            fence = try repository.advance(fence, to: phase).get()
            #expect(repository.lookup(for: "alpha") == .present(fence))
        }

        #expect(storage.writeCount == 4)
        let raw = try #require(storage.values[AccountDeletionFenceRepository.activeKey])
        #expect(raw.contains("\"accountID\":\"alpha\""))
        #expect(raw.contains("\"requestID\":\"" + requestID.uuidString + "\""))
        #expect(raw.contains("\"phase\":\"localCleanupStarted\""))
    }

    @Test("A failed admission write returns no fence and does not progress")
    func persistenceFailureDoesNotProgress() {
        let storage = MemoryFenceStorage()
        storage.writeBehavior = .fail
        let repository = makeRepository(storage: storage)

        let result = repository.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        )

        #expect(result == .failure(.persistenceFailed))
        #expect(repository.lookup(for: "alpha") == .missing)
        #expect(repository.isProviderWorkAllowed(for: "alpha"))
        #expect(storage.writeCount == 1)
        #expect(storage.removeCount == 0)
    }

    @Test("A write that cannot be read back is ambiguous and fails closed")
    func readbackFailureFailsClosed() {
        let storage = MemoryFenceStorage()
        storage.writeBehavior = .replaceWithCorruptPayload
        let repository = makeRepository(storage: storage)

        let result = repository.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        )

        #expect(result == .failure(.persistenceFailed))
        #expect(repository.lookup(for: "alpha") == .ambiguous)
        #expect(!repository.isProviderWorkAllowed(for: "alpha"))
    }

    @Test("A pending fence globally closes provider work")
    func matchingVersusOtherAccountAdmission() throws {
        let storage = MemoryFenceStorage()
        let repository = makeRepository(storage: storage)
        _ = try repository.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        ).get()

        #expect(!repository.isProviderWorkAllowed(for: "alpha"))
        #expect(!repository.isProviderWorkAllowed(for: "beta"))
        #expect(repository.lookup(for: "beta") == .ambiguous)

        storage.unavailableKeys.insert(AccountDeletionFenceRepository.activeKey)
        #expect(!repository.isProviderWorkAllowed(for: "beta"))
    }

    @Test("Repository recreation preserves phase and server correlation ID")
    func recreationPreservesCorrelationIdentity() throws {
        let storage = MemoryFenceStorage()
        let firstRepository = makeRepository(storage: storage)
        let admitted = try firstRepository.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        ).get()
        let requested = try firstRepository.advance(
            admitted,
            to: .remoteRequested
        ).get()

        let replacementID = UUID(uuidString: "6713738e-d9ed-4337-986e-09205089d42e")!
        let relaunchedRepository = AccountDeletionFenceRepository(
            storage: storage,
            makeRequestID: { replacementID }
        )
        let resumed = try relaunchedRepository.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        ).get()

        #expect(resumed == requested)
        #expect(resumed.requestID == requestID)
        #expect(resumed.phase == .remoteRequested)
        #expect(storage.writeCount == 2)
    }

    @Test("A second account cannot replace the discoverable pending identity")
    func pendingAccountCannotBeReplaced() throws {
        let storage = MemoryFenceStorage()
        let repository = makeRepository(storage: storage)
        let pending = try repository.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        ).get()

        #expect(repository.beginOrResume(
            for: "beta",
            providerRawValue: "google"
        ) == .failure(.pendingAccountMismatch))
        #expect(repository.beginOrResume(
            for: "alpha",
            providerRawValue: "apple"
        ) == .failure(.pendingAccountMismatch))
        #expect(repository.pendingLookup() == .present(pending))
        #expect(storage.writeCount == 1)
    }

    @Test("Phase regression and skipped progress are rejected")
    func phaseIsMonotonic() throws {
        let storage = MemoryFenceStorage()
        let repository = makeRepository(storage: storage)
        let admitted = try repository.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        ).get()

        #expect(repository.advance(admitted, to: .remoteCommitted)
            == .failure(.invalidPhaseTransition))
        let requested = try repository.advance(admitted, to: .remoteRequested).get()
        #expect(repository.advance(requested, to: .admissionClosed)
            == .failure(.invalidPhaseTransition))
    }

    @Test("A stale request cannot overwrite the durable request")
    func staleRequestCannotAdvance() throws {
        let storage = MemoryFenceStorage()
        let repository = makeRepository(storage: storage)
        let admitted = try repository.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        ).get()
        let stale = AccountDeletionFence(
            accountID: admitted.accountID,
            providerRawValue: admitted.providerRawValue,
            requestID: UUID(),
            phase: admitted.phase
        )

        #expect(repository.advance(stale, to: .remoteRequested)
            == .failure(.requestMismatch))
        #expect(repository.lookup(for: "alpha") == .present(admitted))
        #expect(storage.writeCount == 1)
    }

    @Test("Only a pre-remote fence has a safe resume disposition")
    func failureDisposition() {
        #expect(AccountDeletionFailureDisposition.after(.admissionClosed)
            == .clearFenceAndResumeProviderWork)
        for phase in [
            AccountDeletionFencePhase.remoteRequested,
            .remoteCommitted,
            .localCleanupStarted,
        ] {
            #expect(AccountDeletionFailureDisposition.after(phase)
                == .retainFenceAndKeepProviderWorkSuspended)
        }
    }

    @Test("Generic identity removal and reauthentication cannot bypass a fence")
    func lifecycleRecreationKeepsAdmissionClosed() throws {
        let storage = MemoryFenceStorage()
        let repository = makeRepository(storage: storage)
        let admitted = try repository.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        ).get()
        let requested = try repository.advance(admitted, to: .remoteRequested).get()

        // Mirrors generic sign-out touching identity keys, never the separate
        // account-scoped deletion key.
        storage.values["NoumAccountID"] = "alpha"
        _ = storage.remove(key: "NoumAccountID")

        let afterSignOut = makeRepository(storage: storage)
        #expect(afterSignOut.pendingLookup() == .present(requested))
        #expect(!afterSignOut.isProviderWorkAllowed(for: "alpha"))
        #expect(!afterSignOut.isProviderWorkAllowed(for: "beta"))

        // A new repository represents a fresh Auth lifecycle after the same
        // account reauthenticates. It must recover, not replace, the request.
        let afterReauthentication = try afterSignOut.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        ).get()
        #expect(afterReauthentication == requested)
    }

    @Test("Only the exact request can clear the durable fence")
    func exactRequestClearing() throws {
        let storage = MemoryFenceStorage()
        let repository = makeRepository(storage: storage)
        let fence = try repository.beginOrResume(
            for: "alpha",
            providerRawValue: "google"
        ).get()
        let stale = AccountDeletionFence(
            accountID: "alpha",
            providerRawValue: "google",
            requestID: UUID(),
            phase: .admissionClosed
        )

        switch repository.clearVerified(stale) {
        case .failure(.requestMismatch):
            break
        default:
            Issue.record("A different request ID cleared the deletion fence")
        }
        #expect(!repository.isProviderWorkAllowed(for: "alpha"))
        try repository.clearVerified(fence).get()
        #expect(repository.isProviderWorkAllowed(for: "alpha"))
    }

    @Test("Caller-provided backend request identity preserves the server contract")
    func callableUsesCallerRequestID() {
        let request = DeleteAccountCallableRequest(
            expectedAccountID: "alpha",
            requestID: requestID
        )

        #expect(request.schemaVersion == 2)
        #expect(request.expectedAccountID == "alpha")
        #expect(request.requestID == requestID.uuidString)
    }

    @Test("Ambiguous failures use honest fail-closed copy")
    func ambiguousFailureCopy() {
        let safe = AuthManager.accountDeletionError(
            for: .serviceUnavailable,
            disposition: .clearFenceAndResumeProviderWork
        )
        let ambiguous = AuthManager.accountDeletionError(
            for: .requiresRecentAuthentication,
            disposition: .retainFenceAndKeepProviderWorkSuspended
        )

        #expect(safe == .serviceUnavailable)
        #expect(ambiguous == .completionUncertainRequiresReauthentication)
        #expect(!ambiguous.requiresReauthentication)
        #expect(!ambiguous.localizedDescription.localizedCaseInsensitiveContains("unchanged"))
        #expect(ambiguous.localizedDescription.localizedCaseInsensitiveContains("Ask Noum"))
        #expect(ambiguous.localizedDescription.localizedCaseInsensitiveContains("Forward Plan"))
        #expect(ambiguous.localizedDescription.localizedCaseInsensitiveContains("recommendation sync"))
        #expect(!ambiguous.localizedDescription.localizedCaseInsensitiveContains("Provider work"))
        #expect(!ambiguous.localizedDescription.localizedCaseInsensitiveContains("retry"))
        #expect(ambiguous.localizedDescription.localizedCaseInsensitiveContains("deletion support"))
    }

    @Test("Only verified first-attempt preflights reopen admission")
    func verifiedPreflightDisposition() {
        let applePreflight = AuthManager.accountDeletionFailureDisposition(
            for: BackendAccountDeletionError.appleRevocationUnavailable,
            persistedPhase: .remoteRequested,
            preparedRemoteRequestInCurrentAttempt: true
        )
        let recentAuthenticationPreflight = AuthManager.accountDeletionFailureDisposition(
            for: BackendAccountDeletionError
                .verifiedPreflightRequiresRecentAuthentication,
            persistedPhase: .remoteRequested,
            preparedRemoteRequestInCurrentAttempt: true
        )
        let socialCutoverPreflight = AuthManager.accountDeletionFailureDisposition(
            for: BackendAccountDeletionError.socialReferenceCutoverIncomplete,
            persistedPhase: .remoteRequested,
            preparedRemoteRequestInCurrentAttempt: true
        )
        let legacyRESTAuthenticationAmbiguity = AuthManager
            .accountDeletionFailureDisposition(
                for: BackendAccountDeletionError.requiresRecentAuthentication,
                persistedPhase: .remoteRequested,
                preparedRemoteRequestInCurrentAttempt: true
            )
        let serviceAmbiguity = AuthManager.accountDeletionFailureDisposition(
            for: BackendAccountDeletionError.serviceUnavailable,
            persistedPhase: .remoteRequested,
            preparedRemoteRequestInCurrentAttempt: true
        )
        let resumedAppleRequest = AuthManager.accountDeletionFailureDisposition(
            for: BackendAccountDeletionError.appleRevocationUnavailable,
            persistedPhase: .remoteRequested,
            preparedRemoteRequestInCurrentAttempt: false
        )
        let resumedAuthenticationRequest = AuthManager.accountDeletionFailureDisposition(
            for: BackendAccountDeletionError
                .verifiedPreflightRequiresRecentAuthentication,
            persistedPhase: .remoteRequested,
            preparedRemoteRequestInCurrentAttempt: false
        )
        let resumedSocialCutoverRequest = AuthManager.accountDeletionFailureDisposition(
            for: BackendAccountDeletionError.socialReferenceCutoverIncomplete,
            persistedPhase: .remoteRequested,
            preparedRemoteRequestInCurrentAttempt: false
        )
        let unverifiedLookalike = AuthManager.accountDeletionFailureDisposition(
            for: AccountDeletionError.appleRevocationUnavailable,
            persistedPhase: .remoteRequested,
            preparedRemoteRequestInCurrentAttempt: true
        )

        #expect(applePreflight == .clearFenceAndResumeProviderWork)
        #expect(recentAuthenticationPreflight == .clearFenceAndResumeProviderWork)
        #expect(socialCutoverPreflight == .clearFenceAndResumeProviderWork)
        #expect(legacyRESTAuthenticationAmbiguity
            == .retainFenceAndKeepProviderWorkSuspended)
        #expect(serviceAmbiguity == .retainFenceAndKeepProviderWorkSuspended)
        #expect(resumedAppleRequest == .retainFenceAndKeepProviderWorkSuspended)
        #expect(resumedAuthenticationRequest
            == .retainFenceAndKeepProviderWorkSuspended)
        #expect(resumedSocialCutoverRequest
            == .retainFenceAndKeepProviderWorkSuspended)
        #expect(unverifiedLookalike == .retainFenceAndKeepProviderWorkSuspended)

        let surfaced = AuthManager.accountDeletionError(
            for: .appleRevocationUnavailable,
            disposition: applePreflight
        )
        #expect(surfaced == .appleRevocationUnavailable)
        #expect(surfaced.localizedDescription
            == AccountDeletionError.appleRevocationUnavailable.localizedDescription)
        #expect(surfaced.localizedDescription.localizedCaseInsensitiveContains("unchanged"))

        let authenticationSurface = AuthManager.accountDeletionError(
            for: .requiresRecentAuthentication,
            disposition: recentAuthenticationPreflight
        )
        #expect(authenticationSurface == .requiresRecentAuthentication)
        #expect(authenticationSurface.requiresReauthentication)
        #expect(authenticationSurface.localizedDescription
            .localizedCaseInsensitiveContains("sign in again"))

        let socialCutoverSurface = AuthManager.accountDeletionError(
            for: .secureDataUpgradeIncomplete,
            disposition: socialCutoverPreflight
        )
        #expect(socialCutoverSurface == .secureDataUpgradeIncomplete)
        #expect(socialCutoverSurface.localizedDescription
            .localizedCaseInsensitiveContains("nothing was deleted"))
        #expect(socialCutoverSurface.localizedDescription
            .localizedCaseInsensitiveContains("try again later"))
    }

    @Test("Auth deletion wiring preserves the durable ordering contract")
    func authDeletionOrderingContract() throws {
        let source = try authManagerSource()
        let method = try sourceSlice(
            in: source,
            from: "    func deleteCurrentAccount() async throws {",
            to: "    private func persistedDeletionRecovery("
        )

        try expectOrdered([
            ".beginOrResume(",
            "for: accountID",
            "providerRawValue: providerRawValue",
            "await ForwardPlanService.shared.suspendProviderWorkForDeletion",
        ], in: method)

        let mainFlow = try sourceSlice(
            in: method,
            from: "// No suspension occurs between publishing deletion",
            to: "        } catch {"
        )
        try expectOrdered([
            "accountDeletionState = .deleting",
            "accountLifecycleGeneration &+= 1",
            "AskNoumStore.shared.suspendProviderWorkForDeletion",
            "ForwardPlanStore.shared.suspendProviderWorkForDeletion",
            "await ForwardPlanService.shared.suspendProviderWorkForDeletion",
            "await backendSync.suspendRecommendationSyncForDeletion",
            ".advance(fence, to: .remoteRequested)",
            "preparedRemoteRequestInCurrentAttempt = true",
            "backendSync.deleteAccount(",
            "requestID: fence.requestID",
            ".advance(fence, to: .remoteCommitted)",
            ".advance(fence, to: .localCleanupStarted)",
            "accountDataRegistry.deleteAllData(for: accountID)",
            "accountDataRegistry.endSession()",
            "performSignOut(allowAnonymousGuest: true)",
            "accountDeletionFenceRepository.clearVerified(fence)",
            "accountDeletionState = .completed",
            "ForwardPlanService.shared.finishProviderWorkDeletion",
        ], in: mainFlow)

        let afterClear = try #require(
            mainFlow.range(of: "accountDeletionFenceRepository.clearVerified(fence)")
        ).upperBound
        #expect(!mainFlow[afterClear...].contains("accountDeletionFenceRepository."))

        let failureStart = try #require(method.range(
            of: "        } catch {\n            let mapped"
        ))
        let failureFlow = String(method[failureStart.lowerBound...])
        try expectOrdered([
            "Self.accountDeletionFailureDisposition(",
            "for: error",
            "preparedRemoteRequestInCurrentAttempt:",
            "disposition == .clearFenceAndResumeProviderWork",
            "accountDeletionFenceRepository.clearVerified(persistedFence)",
            "resumeProviderWorkAfterSafeDeletionFailure",
            "Self.accountDeletionError(",
        ], in: failureFlow)
    }

    @Test("Sign-out and same-account reauthentication preserve actionable fencing")
    func authLifecycleWiringKeepsFence() throws {
        let source = try authManagerSource()
        let signOut = try sourceSlice(
            in: source,
            from: "    func signOut() {",
            to: "#if DEBUG"
        )
        #expect(!signOut.contains("clearVerified"))
        #expect(!signOut.contains(AccountDeletionFenceRepository.keyPrefix))

        let completeSignIn = try sourceSlice(
            in: source,
            from: "    private func completeSignIn(",
            to: "    private func hydrateStoresForCurrentAccount("
        )
        #expect(completeSignIn.contains(
            "pendingDeletionRecoveryError(for: accountID)"
        ))
        try expectOrdered([
            "admitSignInAgainstPendingDeletion(",
            "persistIdentity(accountID: accountID",
        ], in: completeSignIn)

        let bootstrap = try sourceSlice(
            in: source,
            from: "    func bootstrapInitialAccountIfNeeded() async {",
            to: "    /// Returns true when the provider either established"
        )
        try expectOrdered([
            "restorePendingDeletionIdentityIfNeeded()",
            "hasDurableIdentity(",
            "remoteGuestBootstrapOwnsOutcomeIfAllowed()",
            "establishDurableLocalGuest()",
        ], in: bootstrap)
        let remoteBootstrap = try sourceSlice(
            in: source,
            from: "    private func remoteGuestBootstrapOwnsOutcomeIfAllowed() async -> Bool {",
            to: "    func retryInitialAccountBootstrap() async {"
        )
        try expectNoGlobalAuthAccess(
            before: "guard allowsFirebaseSDKSessionAccess else",
            in: remoteBootstrap
        )
        try expectOrdered([
            "guard allowsFirebaseSDKSessionAccess else",
            "boundedFirebaseAnonymousIdentity",
            "Auth.auth().currentUser",
        ], in: remoteBootstrap)

        let restore = try sourceSlice(
            in: source,
            from: "    private func loadCredentialsAndAccount() {",
            to: "    func credentialResolver() throws"
        )
        try expectOrdered([
            "restorePendingDeletionIdentityIfNeeded()",
            "KeychainHelper.load(key: accountKey)",
            "hydrateStoresForCurrentAccount(",
        ], in: restore)

        let promotionRecovery = try sourceSlice(
            in: source,
            from: "    private func recoverLocalGuestPromotionBeforeCredentialHydration() {",
            to: "    private func rollbackLocalGuestPromotionBeforeHydration("
        )
        try expectNoGlobalAuthAccess(
            before: "guard allowsFirebaseSDKSessionAccess else { return }",
            in: promotionRecovery
        )
        try expectOrdered([
            "guard allowsFirebaseSDKSessionAccess else { return }",
            "Auth.auth().currentUser",
        ], in: promotionRecovery)

        let pendingDeletionRecovery = try sourceSlice(
            in: source,
            from: "    private func restorePendingDeletionIdentity(",
            to: "    private func signOutAttemptedFirebaseIdentity("
        )
        try expectNoGlobalAuthAccess(
            before: "if allowsFirebaseSDKSessionAccess,",
            in: pendingDeletionRecovery
        )
        try expectOrdered([
            "if allowsFirebaseSDKSessionAccess,",
            "Auth.auth().currentUser",
            "Auth.auth().signOut()",
        ], in: pendingDeletionRecovery)

        let hydration = try sourceSlice(
            in: source,
            from: "    private func hydrateStoresForCurrentAccount(",
            to: "    private func reloadAccountScopedStores()"
        )
        try expectOrdered([
            "guard isProviderWorkAllowed(for: accountID) else",
            "pendingDeletionRecoveryError(for: accountID)",
            "deferFencedStoreSessionReset(accountID: accountID)",
            "return",
            "activeAccountHydrationGeneration = generation",
        ], in: hydration)
    }

    @Test("Deletion transports bind and recheck the exact Firebase identity")
    func deletionTransportIdentityContract() throws {
        #expect(BackendAuthHeaders.deletionIdentityMatches(
            expectedAccountID: "alpha",
            capturedUserID: "alpha",
            currentUserID: "alpha"
        ))
        #expect(!BackendAuthHeaders.deletionIdentityMatches(
            expectedAccountID: "alpha",
            capturedUserID: "alpha",
            currentUserID: "beta"
        ))
        #expect(!BackendAuthHeaders.deletionIdentityMatches(
            expectedAccountID: "alpha",
            capturedUserID: "beta",
            currentUserID: "beta"
        ))

        let source = try backendSyncManagerSource()
        let callable = try sourceSlice(
            in: source,
            from: "    private func deleteFirebaseAccountThroughCallable(",
            to: "    nonisolated static func accountDeletionError("
        )
        let afterRefresh = try #require(
            callable.range(of: "user.getIDTokenForcingRefresh(true)")
        ).upperBound
        try expectOrdered([
            "guard Auth.auth().currentUser?.uid == expectedAccountID",
            "expectedAccountID: expectedAccountID",
            "guard Auth.auth().currentUser?.uid == expectedAccountID",
            "callable.call(request)",
        ], in: String(callable[afterRefresh...]))
        #expect(callable.contains(
            "BackendAccountDeletionError.verifiedPreflightRequiresRecentAuthentication"
        ))

        let deletionEntry = try sourceSlice(
            in: source,
            from: "    func deleteAccount(",
            to: "    private func deleteFirebaseAccountThroughCallable("
        )
        #expect(deletionEntry.contains("try await deletionRequest("))
        #expect(deletionEntry.contains(
            "throw BackendAccountDeletionError.requiresRecentAuthentication"
        ))
        #expect(!deletionEntry.contains("await request("))
    }

    private func makeRepository(
        storage: MemoryFenceStorage
    ) -> AccountDeletionFenceRepository {
        AccountDeletionFenceRepository(
            storage: storage,
            makeRequestID: { requestID }
        )
    }

    private func authManagerSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/AuthManager.swift"),
            encoding: .utf8
        )
    }

    private func backendSyncManagerSource() throws -> String {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testsDirectory.deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/BackendSyncManager.swift"),
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

    private func expectNoGlobalAuthAccess(
        before guardNeedle: String,
        in source: String
    ) throws {
        let guardRange = try #require(source.range(of: guardNeedle))
        let prefix = source[..<guardRange.lowerBound]
        #expect(!prefix.contains("Auth.auth()"))
        #expect(!prefix.contains("GIDSignIn.sharedInstance"))
    }

    private final class MemoryFenceStorage: AccountDeletionFenceStorage {
        enum WriteBehavior {
            case persist
            case fail
            case replaceWithCorruptPayload
        }

        var values: [String: String] = [:]
        var unavailableKeys: Set<String> = []
        var writeBehavior: WriteBehavior = .persist
        private(set) var writeCount = 0
        private(set) var removeCount = 0

        func read(key: String) -> AccountDeletionFenceStorageRead {
            if unavailableKeys.contains(key) { return .unavailable }
            return values[key].map(AccountDeletionFenceStorageRead.value) ?? .missing
        }

        func write(_ value: String, key: String) -> Bool {
            writeCount += 1
            switch writeBehavior {
            case .persist:
                values[key] = value
                return true
            case .fail:
                return false
            case .replaceWithCorruptPayload:
                values[key] = "{}"
                return true
            }
        }

        func remove(key: String) -> Bool {
            removeCount += 1
            values.removeValue(forKey: key)
            return true
        }
    }
}
