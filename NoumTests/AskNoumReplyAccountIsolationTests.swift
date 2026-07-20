import Foundation
import Testing
@testable import Noum

@MainActor
@Suite("Ask Noum reply account isolation")
struct AskNoumReplyAccountIsolationTests {
    private final class AccountState {
        var accountID: String?
        var lifecycle: UInt64
        var isReady: Bool
        var providerWorkAllowed: Bool

        init(
            accountID: String? = "alpha",
            lifecycle: UInt64 = 1,
            isReady: Bool = true,
            providerWorkAllowed: Bool = true
        ) {
            self.accountID = accountID
            self.lifecycle = lifecycle
            self.isReady = isReady
            self.providerWorkAllowed = providerWorkAllowed
        }

        @MainActor
        func makeStore(defaults: UserDefaults) -> AskNoumStore {
            AskNoumStore(
                defaults: defaults,
                accountIDProvider: { self.accountID },
                accountLifecycleGenerationProvider: { self.lifecycle },
                accountIsReadyProvider: { self.isReady },
                providerWorkAllowedProvider: { accountID in
                    self.providerWorkAllowed && accountID == self.accountID
                }
            )
        }
    }

    @Test("Checked provisional and final writes stay on the originating account")
    func checkedReplyLifecyclePersistsOnlyOriginatingAccount() throws {
        let defaults = isolatedDefaults()
        let state = AccountState()
        let store = state.makeStore(defaults: defaults)
        let admission = try #require(store.sendAdmission())
        let dispatch = try #require(store.appendUserTurn(
            "Help me make this update clearer.",
            expected: admission
        ))

        #expect(store.setProvisionalCoachRead(
            id: dispatch.coachID,
            text: "Lead with the decision.",
            expected: dispatch.lease
        ))
        #expect(store.messages.last?.isPending == true)
        #expect(store.completeCoachTurn(
            id: dispatch.coachID,
            outcome: .reply("Lead with the decision, then give one reason."),
            expected: dispatch.lease
        ))
        #expect(store.messages.last?.isPending == false)
        #expect(defaults.data(forKey: "askNoum.thread.alpha") != nil)
        #expect(defaults.data(forKey: "askNoum.thread.guest") == nil)
        #expect(defaults.data(forKey: "askNoum.thread.beta") == nil)
        #expect(!store.cancelPendingCoachTurn(
            id: dispatch.coachID,
            expected: dispatch.lease
        ))
    }

    @Test("A detailed three-thousand-character turn survives acceptance and reload")
    func detailedTurnPersistsWithoutSilentLoss() throws {
        let defaults = isolatedDefaults()
        let state = AccountState()
        let store = state.makeStore(defaults: defaults)
        let detailedTurn = String(repeating: "Detailed context with a decision, constraint, and intended meaning. ", count: 48)
            .prefix(3_000)
        let exactTurn = String(detailedTurn)
        #expect(exactTurn.count == 3_000)

        let admission = try #require(store.sendAdmission())
        _ = try #require(store.appendUserTurn(exactTurn, expected: admission))

        let reloadedStore = state.makeStore(defaults: defaults)
        let persistedUserTurn = reloadedStore.messages.last(where: { $0.role == .user })
        #expect(persistedUserTurn?.text == exactTurn)
        #expect(reloadedStore.messages.allSatisfy { !$0.isPending })
    }

    @Test("Identity change before registry reload rejects every old-row mutation")
    func accountSwitchBeforeReloadRejectsOldLease() throws {
        let defaults = isolatedDefaults()
        let state = AccountState()
        let store = state.makeStore(defaults: defaults)
        let admission = try #require(store.sendAdmission())
        let dispatch = try #require(store.appendUserTurn(
            "This belongs to alpha.",
            expected: admission
        ))

        state.accountID = "beta"
        state.lifecycle = 2

        #expect(!store.setProvisionalCoachRead(
            id: dispatch.coachID,
            text: "Stale read",
            expected: dispatch.lease
        ))
        #expect(!store.completeCoachTurn(
            id: dispatch.coachID,
            outcome: .reply("Stale reply"),
            expected: dispatch.lease
        ))
        #expect(!store.cancelPendingCoachTurn(
            id: dispatch.coachID,
            expected: dispatch.lease
        ))
        #expect(defaults.data(forKey: "askNoum.thread.beta") == nil)
        #expect(defaults.data(forKey: "askNoum.thread.guest") == nil)

        store.reloadForCurrentAccount()
        #expect(store.loadedAccountScope == "beta")
        #expect(store.messages.isEmpty)
    }

    @Test("Nil identity fails closed without creating a shared guest key")
    func signOutNeverWritesLiteralGuestBucket() throws {
        let defaults = isolatedDefaults()
        let state = AccountState()
        let store = state.makeStore(defaults: defaults)
        let admission = try #require(store.sendAdmission())
        let dispatch = try #require(store.appendUserTurn(
            "Do not move this turn.",
            expected: admission
        ))

        state.accountID = nil
        state.lifecycle = 2
        state.isReady = false
        state.providerWorkAllowed = false

        #expect(store.sendAdmission() == nil)
        #expect(!store.completeCoachTurn(
            id: dispatch.coachID,
            outcome: .reply("Must not land"),
            expected: dispatch.lease
        ))
        store.completeCoachTurn(
            id: dispatch.coachID,
            outcome: .reply("The compatibility API must also reject this.")
        )
        store.clearThread()
        #expect(defaults.data(forKey: "askNoum.thread.guest") == nil)
        #expect(defaults.dictionaryRepresentation().keys.allSatisfy {
            $0 != "askNoum.thread.guest"
        })
    }

    @Test("Rapid return to the same account cannot reuse an old lifecycle lease")
    func sameAccountReturnRejectsOldLifecycle() throws {
        let defaults = isolatedDefaults()
        let state = AccountState(lifecycle: 7)
        let store = state.makeStore(defaults: defaults)
        let admission = try #require(store.sendAdmission())
        let dispatch = try #require(store.appendUserTurn(
            "Original lifecycle",
            expected: admission
        ))

        state.accountID = nil
        state.isReady = false
        state.providerWorkAllowed = false
        state.lifecycle = 8
        state.accountID = "alpha"
        state.isReady = true
        state.providerWorkAllowed = true

        #expect(!store.replyLeaseIsCurrent(dispatch.lease))
        #expect(!store.completeCoachTurn(
            id: dispatch.coachID,
            outcome: .reply("Wrong lifecycle"),
            expected: dispatch.lease
        ))
        #expect(defaults.data(forKey: "askNoum.thread.guest") == nil)
    }

    @Test("Same-account reload changes store generation and rejects the old row")
    func reloadInvalidatesReplyGeneration() throws {
        let defaults = isolatedDefaults()
        let state = AccountState()
        let store = state.makeStore(defaults: defaults)
        let admission = try #require(store.sendAdmission())
        let dispatch = try #require(store.appendUserTurn(
            "Pending before reload",
            expected: admission
        ))

        store.reloadForCurrentAccount()

        #expect(!store.replyLeaseIsCurrent(dispatch.lease))
        #expect(!store.setProvisionalCoachRead(
            id: dispatch.coachID,
            text: "Must not reappear",
            expected: dispatch.lease
        ))
        #expect(store.messages.count == 1)
        #expect(store.messages.first?.role == .user)
    }

    @Test("Deletion suspension cancels provider work and preserves completed rows")
    func deletionSuspensionCancelsAndPreservesCompletedRows() throws {
        let defaults = isolatedDefaults()
        let state = AccountState()
        let store = state.makeStore(defaults: defaults)

        let firstAdmission = try #require(store.sendAdmission())
        let completed = try #require(store.appendUserTurn(
            "Give me one practical change.",
            expected: firstAdmission
        ))
        #expect(store.completeCoachTurn(
            id: completed.coachID,
            outcome: .reply("Pause after the headline, then give one reason."),
            expected: completed.lease
        ))

        let secondAdmission = try #require(store.sendAdmission())
        let pending = try #require(store.appendUserTurn(
            "This provider request is still running.",
            expected: secondAdmission
        ))
        var cancellationObserved = false
        #expect(store.registerProviderWorkCancellation(
            expected: pending.lease,
            cancel: { cancellationObserved = true }
        ))

        // Auth closes the provider gate before invoking the synchronous hook.
        state.providerWorkAllowed = false
        store.suspendProviderWorkForDeletion(accountID: "alpha")

        #expect(cancellationObserved)
        #expect(!store.isAwaitingReply)
        #expect(store.messages.allSatisfy { !$0.isPending })
        #expect(store.messages.contains {
            $0.role == .coach && $0.text.contains("Pause after the headline")
        })
        #expect(!store.completeCoachTurn(
            id: pending.coachID,
            outcome: .reply("Late completion"),
            expected: pending.lease
        ))
        #expect(defaults.data(forKey: "askNoum.thread.alpha") != nil)
        #expect(defaults.data(forKey: "askNoum.thread.guest") == nil)

        // A remote deletion failure can reopen the same account and recover
        // only durable, non-pending rows from the explicitly scoped key.
        state.providerWorkAllowed = true
        store.reloadForCurrentAccount()
        #expect(store.messages.allSatisfy { !$0.isPending })
        #expect(store.messages.contains {
            $0.role == .coach && $0.text.contains("Pause after the headline")
        })
    }

    @Test("Availability-era admission cannot append after lifecycle drift")
    func stalePreflightAdmissionCannotAppend() throws {
        let defaults = isolatedDefaults()
        let state = AccountState()
        let store = state.makeStore(defaults: defaults)
        let admission = try #require(store.sendAdmission())

        state.lifecycle = 2

        #expect(store.appendUserTurn(
            "Captured before availability returned",
            expected: admission
        ) == nil)
        #expect(store.messages.isEmpty)
        #expect(defaults.data(forKey: "askNoum.thread.alpha") == nil)
        #expect(defaults.data(forKey: "askNoum.thread.guest") == nil)
    }

    @Test("Provider-work gate denies new sends and leases during deletion")
    func providerGateDeniesAdmission() {
        let defaults = isolatedDefaults()
        let state = AccountState(providerWorkAllowed: false)
        let store = state.makeStore(defaults: defaults)

        #expect(store.sendAdmission() == nil)
        _ = store.appendUserTurn("Legacy production caller must fail closed")
        #expect(store.messages.isEmpty)
        #expect(defaults.data(forKey: "askNoum.thread.alpha") == nil)
        #expect(defaults.data(forKey: "askNoum.thread.guest") == nil)
    }

    @Test("Deletion closes auxiliary provider work before transport starts")
    func deletionClosesAuxiliaryProviderWorkBeforeTransportStart() async throws {
        let defaults = isolatedDefaults()
        let state = AccountState()
        let store = state.makeStore(defaults: defaults)
        let admission = try #require(store.sendAdmission())
        let lease = try #require(store.auxiliaryProviderLease(expected: admission))
        var cancellationObserved = false

        #expect(store.registerAuxiliaryProviderWorkCancellation(
            expected: lease,
            cancel: { cancellationObserved = true }
        ))

        state.providerWorkAllowed = false
        store.suspendProviderWorkForDeletion(accountID: "alpha")

        #expect(cancellationObserved)
        #expect(!store.auxiliaryProviderWorkIsCurrent(lease))

        var transportStarted = false
        let request = URLRequest(url: URL(string: "https://example.invalid/chips")!)
        do {
            _ = try await store.performAuxiliaryProviderRequest(
                request,
                expected: lease,
                transport: { _ in
                    transportStarted = true
                    throw URLError(.badServerResponse)
                }
            )
            Issue.record("A revoked auxiliary lease crossed the transport boundary")
        } catch is CancellationError {
            // Expected: the final MainActor gate rejects before transport.
        } catch {
            Issue.record("A revoked auxiliary lease returned the wrong error: \(error)")
        }
        #expect(!transportStarted)
    }

    @Test("Coach service checks deletion admission before secure transport")
    func coachServiceChecksDeletionAdmissionBeforeSecureTransport() async {
        let probe = AskNoumProviderStartProbe()
        let service = AICoachChatService(
            secureTransport: AskNoumAdmissionProbeTransport(probe: probe)
        )

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "What should I fix first?")],
            systemPrompt: "Give one grounded coaching move.",
            userContext: "Deletion admission is closed.",
            providerWorkAllowed: { false }
        )

        guard case .failure(.unauthenticated) = outcome else {
            Issue.record("A closed deletion admission returned \(outcome)")
            return
        }
        #expect(await probe.availabilityCallCount() == 0)
    }

    @Test("Checked cancellation removes only its exact pending coach row")
    func checkedCancellationUsesExactPendingRow() throws {
        let defaults = isolatedDefaults()
        let state = AccountState()
        let store = state.makeStore(defaults: defaults)
        let admission = try #require(store.sendAdmission())
        let dispatch = try #require(store.appendUserTurn(
            "Keep my user turn for retry.",
            expected: admission
        ))
        let wrongLease = AskNoumReplyLease(
            accountScope: dispatch.lease.accountScope,
            accountLifecycleGeneration: dispatch.lease.accountLifecycleGeneration,
            threadStoreGeneration: dispatch.lease.threadStoreGeneration,
            coachID: UUID()
        )

        #expect(!store.cancelPendingCoachTurn(
            id: dispatch.coachID,
            expected: wrongLease
        ))
        #expect(store.cancelPendingCoachTurn(
            id: dispatch.coachID,
            expected: dispatch.lease
        ))
        #expect(store.messages.count == 1)
        #expect(store.messages.first?.role == .user)
        #expect(!store.isAwaitingReply)
    }

    @Test("Pipeline rejects a stale expected lease before provider work")
    func pipelineRejectsStaleLeaseBeforeProviderWork() async throws {
        let defaults = isolatedDefaults()
        let state = AccountState()
        let store = state.makeStore(defaults: defaults)
        let admission = try #require(store.sendAdmission())
        let dispatch = try #require(store.appendUserTurn(
            "Do not start a provider for this stale request.",
            expected: admission
        ))
        state.lifecycle = 2

        let outcome = await CoachReplyPipeline.generate(
            coachID: dispatch.coachID,
            store: store,
            expectedReplyLease: dispatch.lease,
            sessionsOverride: []
        )

        if case .failure(.unauthenticated) = outcome {
            // Expected.
        } else {
            Issue.record("A stale reply lease must fail before provider work")
        }
        #expect(defaults.data(forKey: "askNoum.thread.guest") == nil)
    }

    @Test("Production Ask call sites require admissions and reply leases")
    func productionCallSitesUseCheckedMutations() throws {
        let root = repositoryRoot()
        let view = try source("Noum/AskNoumView.swift", root: root)
        let pipeline = try source("Noum/CoachReplyPipeline.swift", root: root)
        let live = try source("Noum/LiveCoachCallView.swift", root: root)
        let store = try source("Noum/AskNoumStore.swift", root: root)
        let coachService = try source("Noum/AICoachChatService.swift", root: root)

        for (label, text) in [
            ("AskNoumView", view),
            ("CoachReplyPipeline", pipeline),
            ("LiveCoachCallView", live),
        ] {
            for mutation in [
                "appendUserTurn",
                "prepareRetry",
                "completeCoachTurn",
                "cancelPendingCoachTurn",
                "setProvisionalCoachRead",
                "setAIChips",
                "setStarterChips",
            ] {
                for arguments in callArguments(
                    in: text,
                    callee: "store.\(mutation)"
                ) {
                    #expect(
                        arguments.contains("expected:"),
                        "\(label) has an unchecked production \(mutation) call"
                    )
                }
            }
            for arguments in callArguments(
                in: text,
                callee: "CoachReplyPipeline.generate"
            ) {
                #expect(
                    arguments.contains("expectedReplyLease:"),
                    "\(label) starts the reply pipeline without its captured lease"
                )
            }
        }

        let leaseCapture = try #require(pipeline.range(of: "let replyLease: AskNoumReplyLease"))
        let firstSuspension = try #require(pipeline.range(of: "coachingExpertise = await"))
        #expect(leaseCapture.lowerBound < firstSuspension.lowerBound)
        let contextSelection = try #require(pipeline.range(of: "let context: String"))
        let contextSnapshot = try #require(pipeline.range(
            of: "let contextSnapshot = context"
        ))
        let providerContext = try #require(pipeline.range(
            of: "userContext: contextSnapshot"
        ))
        let finalVisionContext = try #require(pipeline.range(
            of: "systemContext: contextSnapshot"
        ))
        #expect(contextSelection.lowerBound < contextSnapshot.lowerBound)
        #expect(contextSnapshot.lowerBound < providerContext.lowerBound)
        #expect(providerContext.lowerBound < finalVisionContext.lowerBound)
        #expect(!pipeline.contains("context +="))
        #expect(!pipeline.contains("userContext: context,"))
        #expect(!pipeline.contains("systemContext: context,"))
        #expect(pipeline.contains("registerProviderWorkCancellation("))
        #expect(pipeline.contains("withTaskCancellationHandler("))
        #expect(pipeline.contains("guard !Task.isCancelled"))
        #expect(pipeline.contains("providerWorkAllowed:"))
        #expect(view.contains("store.sendAdmissionIsCurrent(sendAdmission)"))
        #expect(view.contains("registerAuxiliaryProviderWorkCancellation("))
        #expect(view.contains("performAuxiliaryProviderRequest("))
        #expect(!view.contains("URLSession.shared.data(for:"))
        #expect(live.contains("store.replyLeaseScopeIsCurrent(dispatch.lease)"))
        #expect(coachService.contains("await providerWorkAllowed()"))
        #expect(!store.contains("?? \"guest\""))
        #expect(!store.contains("\"askNoum.thread.guest\""))
    }

    private func isolatedDefaults() -> UserDefaults {
        let name = "AskNoumReplyAccountIsolationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func repositoryRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String, root: URL) throws -> String {
        try String(
            contentsOf: root.appendingPathComponent(path),
            encoding: .utf8
        )
    }

    /// Small balanced-parenthesis scanner for source contracts. It avoids a
    /// regex that would stop at nested `.failure(...)` arguments and ensures
    /// every production mutation call—not merely one exemplar—carries a token.
    private func callArguments(in source: String, callee: String) -> [String] {
        let needle = callee + "("
        var results: [String] = []
        var searchStart = source.startIndex
        while let range = source.range(
            of: needle,
            range: searchStart..<source.endIndex
        ) {
            var cursor = range.upperBound
            let argumentsStart = cursor
            var depth = 1
            while cursor < source.endIndex, depth > 0 {
                switch source[cursor] {
                case "(": depth += 1
                case ")": depth -= 1
                default: break
                }
                cursor = source.index(after: cursor)
            }
            guard depth == 0 else { break }
            let argumentsEnd = source.index(before: cursor)
            results.append(String(source[argumentsStart..<argumentsEnd]))
            searchStart = cursor
        }
        return results
    }
}

private actor AskNoumProviderStartProbe {
    private var availabilityCalls = 0

    func recordAvailabilityCall() {
        availabilityCalls += 1
    }

    func availabilityCallCount() -> Int {
        availabilityCalls
    }
}

private struct AskNoumAdmissionProbeTransport: CoachChatTransport {
    let probe: AskNoumProviderStartProbe

    func availability() async -> CoachChatTransportAvailability {
        await probe.recordAvailabilityCall()
        return .available
    }

    func stream(
        _ request: CoachChatRequest
    ) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        throw CoachChatTransportError.serviceUnavailable
    }
}
