import Foundation
import Testing
@testable import Noum

@MainActor
@Suite("Forward Plan deletion fence")
struct ForwardPlanDeletionFenceTests {
    private final class StoreLeaseState {
        var accountID: String?
        var lifecycle: UInt64 = 1
        var isReady = true
        var providerWorkAllowedAccounts: Set<String>
        var sessionStoreEpoch: PracticeSessionStoreEpoch?

        init(accountID: String) {
            self.accountID = accountID
            providerWorkAllowedAccounts = [accountID]
            sessionStoreEpoch = PracticeSessionStoreEpoch(
                accountScope: accountID,
                generation: 1
            )
        }

        @MainActor
        func makeStore(defaults: UserDefaults) -> ForwardPlanStore {
            let store = ForwardPlanStore(
                defaults: defaults,
                accountIDProvider: { self.accountID },
                accountLifecycleGenerationProvider: { self.lifecycle },
                accountIsReadyProvider: { self.isReady },
                providerWorkAllowedProvider: {
                    self.providerWorkAllowedAccounts.contains($0)
                },
                sessionStoreEpochProvider: { self.sessionStoreEpoch },
                executionAuthorizationProvider: { Self.authorization }
            )
            store.reloadForCurrentAccount()
            return store
        }

        func switchAccount(to accountID: String, generation: UInt64) {
            self.accountID = accountID
            lifecycle &+= 1
            sessionStoreEpoch = PracticeSessionStoreEpoch(
                accountScope: accountID,
                generation: generation
            )
        }

        static let authorization = ForwardPlanExecutionAuthorization(
            locale: .enUS,
            cloudProcessingConsent: CloudProcessingConsent(
                decision: .allowed,
                decidedAt: Date(timeIntervalSince1970: 1_700_000_000),
                disclosureVersion: AISettingsManager.disclosureVersion,
                processorManifestVersion: AISettingsManager.processorManifestVersion
            ),
            activeProvider: .openAI
        )
    }

    @Test("Matching account suspension invalidates its lease without erasing an installed plan")
    func matchingAccountGatePreservesInstalledPlan() throws {
        let defaults = isolatedDefaults()
        let state = StoreLeaseState(accountID: "alpha")
        let input = makeInput()
        let installedPlan = ForwardPlanService.deterministicPlan(input: input)
        defaults.set(
            try JSONEncoder().encode(installedPlan),
            forKey: "forwardPlan.alpha"
        )
        let store = state.makeStore(defaults: defaults)
        let captured = try #require(store.generationRequest(for: input))

        store.suspendProviderWorkForDeletion(accountID: "alpha")

        #expect(!store.tokenIsCurrent(captured.saveToken, currentInput: input))
        #expect(store.activePlan == installedPlan)
        #expect(defaults.data(forKey: "forwardPlan.alpha") != nil)

        state.providerWorkAllowedAccounts.remove("alpha")
        #expect(store.generationRequest(for: input) == nil)
    }

    @Test("A different account suspension cannot invalidate the loaded account")
    func differentAccountRemainsUsable() throws {
        let defaults = isolatedDefaults()
        let state = StoreLeaseState(accountID: "alpha")
        state.providerWorkAllowedAccounts.insert("beta")
        let store = state.makeStore(defaults: defaults)
        let input = makeInput()
        let alphaRequest = try #require(store.generationRequest(for: input))

        store.suspendProviderWorkForDeletion(accountID: "beta")

        #expect(store.tokenIsCurrent(alphaRequest.saveToken, currentInput: input))

        state.switchAccount(to: "beta", generation: 2)
        store.reloadForCurrentAccount()
        #expect(store.generationRequest(for: input) != nil)
    }

    @Test("An account closed before generation cannot create a transport")
    func closeBeforeRegistrationRejectsTransport() async {
        let service = ForwardPlanService(apiKeyProvider: { _ in "test-key" })
        let transport = ControlledTransport()
        await service.suspendProviderWorkForDeletion(accountID: "alpha")

        let result = await service.generate(
            request: makeRequest(accountScope: "alpha"),
            startTransportIfCurrent: { transport.start($0) },
            isCurrent: { true }
        )

        #expect(result == nil)
        #expect(transport.callCount == 0)
    }

    @Test("A close after MainActor creation cancels before actor registration")
    func closeBetweenCreationAndRegistrationCancelsHandle() async {
        let registrationGate = TransportRegistrationGate()
        let service = ForwardPlanService(
            apiKeyProvider: { _ in "test-key" },
            transportCreatedHook: {
                await registrationGate.pauseAfterCreation()
            }
        )
        let transport = ControlledTransport()
        let generation = Task {
            await service.generate(
                request: makeRequest(accountScope: "alpha"),
                startTransportIfCurrent: { transport.start($0) },
                isCurrent: { true }
            )
        }

        await registrationGate.waitUntilPaused()
        await service.suspendProviderWorkForDeletion(accountID: "alpha")
        await registrationGate.resumeRegistration()
        await transport.waitUntilCancelled()
        let result = await generation.value
        let cancellationCount = await transport.cancellationCount

        #expect(result == nil)
        #expect(transport.callCount == 1)
        #expect(cancellationCount == 1)
    }

    @Test("Finish cannot reopen while a revoked admission is awaiting registration")
    func finishBeforeRegistrationKeepsAdmissionClosed() async {
        let registrationGate = TransportRegistrationGate()
        let service = ForwardPlanService(
            apiKeyProvider: { _ in "test-key" },
            transportCreatedHook: {
                await registrationGate.pauseAfterCreation()
            }
        )
        let delayedTransport = ControlledTransport(returnsImmediately: true)
        let duringGapTransport = ControlledTransport(returnsImmediately: true)
        let generation = Task {
            await service.generate(
                request: makeRequest(accountScope: "alpha"),
                startTransportIfCurrent: { delayedTransport.start($0) },
                isCurrent: { true }
            )
        }

        await registrationGate.waitUntilPaused()
        await service.suspendProviderWorkForDeletion(accountID: "alpha")
        await service.finishProviderWorkDeletion(accountID: "alpha")

        let duringGap = await service.generate(
            request: makeRequest(accountScope: "alpha"),
            startTransportIfCurrent: { duringGapTransport.start($0) },
            isCurrent: { true }
        )
        #expect(duringGap == nil)
        #expect(duringGapTransport.callCount == 0)

        await registrationGate.resumeRegistration()
        await delayedTransport.waitUntilCancelled()
        let result = await generation.value
        let cancellationCount = await delayedTransport.cancellationCount

        #expect(result == nil)
        #expect(delayedTransport.callCount == 1)
        #expect(cancellationCount == 1)
    }

    @Test("Closing after registration cancels the matching active transport")
    func closeAfterRegistrationCancelsTransport() async {
        let service = ForwardPlanService(apiKeyProvider: { _ in "test-key" })
        let transport = ControlledTransport()
        let generation = Task {
            await service.generate(
                request: makeRequest(accountScope: "alpha"),
                startTransportIfCurrent: { transport.start($0) },
                isCurrent: { true }
            )
        }

        await transport.waitUntilStarted()
        await service.suspendProviderWorkForDeletion(accountID: "alpha")
        await transport.waitUntilCancelled()
        let result = await generation.value
        let cancellationCount = await transport.cancellationCount

        #expect(result == nil)
        #expect(cancellationCount == 1)
    }

    @Test("A cancellation-ignoring transport cannot pass store or service postflight")
    func cancellationIgnoringTransportCannotCommit() async throws {
        let defaults = isolatedDefaults()
        let state = StoreLeaseState(accountID: "alpha")
        let store = state.makeStore(defaults: defaults)
        let input = makeInput()
        let request = try #require(store.generationRequest(for: input))
        let service = ForwardPlanService(apiKeyProvider: { _ in "test-key" })
        let transport = ControlledTransport(ignoresCancellation: true)
        let generation = Task {
            await service.generate(
                request: request,
                startTransportIfCurrent: { urlRequest in
                    guard store.tokenIsCurrent(
                        request.saveToken,
                        currentInput: input
                    ) else {
                        return nil
                    }
                    return transport.start(urlRequest)
                },
                isCurrent: {
                    store.tokenIsCurrent(
                        request.saveToken,
                        currentInput: input
                    )
                }
            )
        }

        await transport.waitUntilStarted()
        state.providerWorkAllowedAccounts.remove("alpha")
        store.suspendProviderWorkForDeletion(accountID: "alpha")
        await service.suspendProviderWorkForDeletion(accountID: "alpha")
        await transport.waitUntilCancelled()
        await transport.complete()
        let result = await generation.value

        #expect(result == nil)
        #expect(!store.tokenIsCurrent(request.saveToken, currentInput: input))
        #expect(store.activePlan == nil)
        #expect(defaults.data(forKey: "forwardPlan.alpha") == nil)
    }

    @Test("Safe pre-remote resume reopens only the explicitly named account")
    func safeResumeIsAccountScoped() async {
        let service = ForwardPlanService(apiKeyProvider: { _ in "test-key" })
        let alphaTransport = ControlledTransport(returnsImmediately: true)
        let betaTransport = ControlledTransport(returnsImmediately: true)
        await service.suspendProviderWorkForDeletion(accountID: "alpha")
        await service.suspendProviderWorkForDeletion(accountID: "beta")

        await service.resumeProviderWorkAfterSafeDeletionFailure(
            accountID: "alpha"
        )

        let alphaResult = await service.generate(
            request: makeRequest(accountScope: "alpha"),
            startTransportIfCurrent: { alphaTransport.start($0) },
            isCurrent: { true }
        )
        let betaResult = await service.generate(
            request: makeRequest(accountScope: "beta"),
            startTransportIfCurrent: { betaTransport.start($0) },
            isCurrent: { true }
        )

        #expect(alphaResult?.isAIBacked == false)
        #expect(alphaTransport.callCount == 1)
        #expect(betaResult == nil)
        #expect(betaTransport.callCount == 0)
    }

    @Test("Finish retains the fence until cancellation-ignoring work drains")
    func finishRetainsFenceUntilTransportDrains() async {
        let service = ForwardPlanService(apiKeyProvider: { _ in "test-key" })
        let drainingTransport = ControlledTransport(ignoresCancellation: true)
        let blockedTransport = ControlledTransport(returnsImmediately: true)
        let afterDrainTransport = ControlledTransport(returnsImmediately: true)
        let generation = Task {
            await service.generate(
                request: makeRequest(accountScope: "alpha"),
                startTransportIfCurrent: { drainingTransport.start($0) },
                isCurrent: { true }
            )
        }

        await drainingTransport.waitUntilStarted()
        await service.suspendProviderWorkForDeletion(accountID: "alpha")
        await service.finishProviderWorkDeletion(accountID: "alpha")
        await service.resumeProviderWorkAfterSafeDeletionFailure(
            accountID: "alpha"
        )

        let whileDraining = await service.generate(
            request: makeRequest(accountScope: "alpha"),
            startTransportIfCurrent: { blockedTransport.start($0) },
            isCurrent: { true }
        )
        #expect(whileDraining == nil)
        #expect(blockedTransport.callCount == 0)

        await drainingTransport.complete()
        #expect(await generation.value == nil)

        let afterDrain = await service.generate(
            request: makeRequest(accountScope: "alpha"),
            startTransportIfCurrent: { afterDrainTransport.start($0) },
            isCurrent: { true }
        )
        #expect(afterDrain?.isAIBacked == false)
        #expect(afterDrainTransport.callCount == 1)
    }

    private func makeInput() -> ForwardPlanInput {
        ForwardPlanInput(
            profile: nil,
            baseline: .empty,
            sessions: [],
            weeklyDelta: 0,
            weeklyReps: 0,
            currentStreak: 0,
            bigMoment: nil,
            bigMomentDaysUntil: nil,
            trends: [],
            recentDrills: [],
            recommendationOutcomes: [],
            transferOutcomes: []
        )
    }

    private func makeRequest(
        accountScope: String
    ) -> ForwardPlanGenerationRequest {
        let input = makeInput()
        return ForwardPlanGenerationRequest(
            input: input,
            saveToken: ForwardPlanSaveToken(
                requestID: UUID(),
                accountScope: accountScope,
                accountLifecycleGeneration: 1,
                planStoreGeneration: 1,
                sessionStoreEpoch: PracticeSessionStoreEpoch(
                    accountScope: accountScope,
                    generation: 1
                ),
                inputIdentity: input.generationIdentity!,
                executionAuthorization: StoreLeaseState.authorization
            )
        )
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "ForwardPlanDeletionFenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @MainActor
    private final class ControlledTransport {
        private(set) var callCount = 0
        private let returnsImmediately: Bool
        private let gate: ControlledTransportGate

        init(
            ignoresCancellation: Bool = false,
            returnsImmediately: Bool = false
        ) {
            self.returnsImmediately = returnsImmediately
            gate = ControlledTransportGate(
                ignoresCancellation: ignoresCancellation
            )
        }

        var cancellationCount: Int {
            get async { await gate.cancellationCount }
        }

        func start(_ request: URLRequest) -> ForwardPlanTransportHandle {
            callCount += 1
            let gate = self.gate
            let returnsImmediately = self.returnsImmediately
            return ForwardPlanTransportHandle(
                response: {
                    try await gate.response(
                        url: request.url,
                        returnsImmediately: returnsImmediately
                    )
                },
                cancellation: {
                    Task { await gate.cancel() }
                }
            )
        }

        func waitUntilStarted() async {
            await gate.waitUntilStarted()
        }

        func waitUntilCancelled() async {
            await gate.waitUntilCancelled()
        }

        func complete() async {
            await gate.complete()
        }
    }

    private actor ControlledTransportGate {
        private let ignoresCancellation: Bool
        private var responseContinuation: CheckedContinuation<
            (Data, URLResponse), Error
        >?
        private var pendingURL: URL?
        private var hasStarted = false
        private var startWaiters: [CheckedContinuation<Void, Never>] = []
        private var cancelWaiters: [CheckedContinuation<Void, Never>] = []
        private(set) var cancellationCount = 0

        init(ignoresCancellation: Bool) {
            self.ignoresCancellation = ignoresCancellation
        }

        func response(
            url: URL?,
            returnsImmediately: Bool
        ) async throws -> (Data, URLResponse) {
            hasStarted = true
            pendingURL = url
            let waiters = startWaiters
            startWaiters.removeAll()
            waiters.forEach { $0.resume() }
            if returnsImmediately {
                return successResponse(url: url)
            }
            return try await withCheckedThrowingContinuation { continuation in
                responseContinuation = continuation
            }
        }

        func waitUntilStarted() async {
            guard !hasStarted else { return }
            await withCheckedContinuation { continuation in
                startWaiters.append(continuation)
            }
        }

        func waitUntilCancelled() async {
            guard cancellationCount == 0 else { return }
            await withCheckedContinuation { continuation in
                cancelWaiters.append(continuation)
            }
        }

        func cancel() {
            cancellationCount += 1
            let waiters = cancelWaiters
            cancelWaiters.removeAll()
            waiters.forEach { $0.resume() }
            guard !ignoresCancellation, let responseContinuation else {
                return
            }
            self.responseContinuation = nil
            responseContinuation.resume(throwing: URLError(.cancelled))
        }

        func complete() {
            guard let responseContinuation else { return }
            self.responseContinuation = nil
            responseContinuation.resume(returning: successResponse(url: pendingURL))
        }

        private func successResponse(url: URL?) -> (Data, URLResponse) {
            let resolvedURL = url ?? URL(string: "https://example.invalid")!
            let response = HTTPURLResponse(
                url: resolvedURL,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (Data(), response)
        }
    }

    private actor TransportRegistrationGate {
        private var isPaused = false
        private var hasPausedCreation = false
        private var pauseContinuation: CheckedContinuation<Void, Never>?
        private var pauseWaiters: [CheckedContinuation<Void, Never>] = []

        func pauseAfterCreation() async {
            guard !hasPausedCreation else { return }
            hasPausedCreation = true
            isPaused = true
            let waiters = pauseWaiters
            pauseWaiters.removeAll()
            waiters.forEach { $0.resume() }
            await withCheckedContinuation { continuation in
                pauseContinuation = continuation
            }
        }

        func waitUntilPaused() async {
            guard !isPaused else { return }
            await withCheckedContinuation { continuation in
                pauseWaiters.append(continuation)
            }
        }

        func resumeRegistration() {
            isPaused = false
            pauseContinuation?.resume()
            pauseContinuation = nil
        }
    }
}
