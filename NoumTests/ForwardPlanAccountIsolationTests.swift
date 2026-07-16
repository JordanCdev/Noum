import Foundation
import Testing
@testable import Noum

@MainActor
@Suite("Forward Plan account/source isolation")
struct ForwardPlanAccountIsolationTests {
    private final class LeaseState {
        var accountID: String?
        var lifecycle: UInt64
        var isReady: Bool
        var sessionStoreEpoch: PracticeSessionStoreEpoch?
        var executionAuthorization: ForwardPlanExecutionAuthorization

        init(
            accountID: String?,
            lifecycle: UInt64,
            isReady: Bool = true,
            sessionStoreGeneration: UInt64 = 1,
            executionAuthorization: ForwardPlanExecutionAuthorization? = nil
        ) {
            self.accountID = accountID
            self.lifecycle = lifecycle
            self.isReady = isReady
            self.executionAuthorization = executionAuthorization
                ?? Self.allowedAuthorization()
            if let accountID {
                sessionStoreEpoch = PracticeSessionStoreEpoch(
                    accountScope: accountID,
                    generation: sessionStoreGeneration
                )
            }
        }

        @MainActor
        func makePlanStore(defaults: UserDefaults) -> ForwardPlanStore {
            let store = ForwardPlanStore(
                defaults: defaults,
                accountIDProvider: { self.accountID },
                accountLifecycleGenerationProvider: { self.lifecycle },
                accountIsReadyProvider: { self.isReady },
                providerWorkAllowedProvider: { _ in true },
                sessionStoreEpochProvider: { self.sessionStoreEpoch },
                executionAuthorizationProvider: {
                    self.executionAuthorization
                }
            )
            store.reloadForCurrentAccount()
            return store
        }

        @MainActor
        func makeAskStore(defaults: UserDefaults) -> AskNoumStore {
            AskNoumStore(
                defaults: defaults,
                accountIDProvider: { self.accountID }
            )
        }

        func switchAccount(
            to accountID: String?,
            lifecycle: UInt64,
            sessionStoreGeneration: UInt64
        ) {
            self.accountID = accountID
            self.lifecycle = lifecycle
            if let accountID {
                sessionStoreEpoch = PracticeSessionStoreEpoch(
                    accountScope: accountID,
                    generation: sessionStoreGeneration
                )
            } else {
                sessionStoreEpoch = nil
            }
        }

        static func allowedAuthorization(
            decidedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
        ) -> ForwardPlanExecutionAuthorization {
            ForwardPlanExecutionAuthorization(
                locale: .enUS,
                cloudProcessingConsent: CloudProcessingConsent(
                    decision: .allowed,
                    decidedAt: decidedAt,
                    disclosureVersion: AISettingsManager.disclosureVersion,
                    processorManifestVersion: AISettingsManager.processorManifestVersion
                ),
                activeProvider: .openAI
            )
        }

        static func deniedAuthorization(
            locale: PracticeLocale = .enUS
        ) -> ForwardPlanExecutionAuthorization {
            ForwardPlanExecutionAuthorization(
                locale: locale,
                cloudProcessingConsent: CloudProcessingConsent(
                    decision: .declined,
                    decidedAt: Date(timeIntervalSince1970: 1_700_000_100),
                    disclosureVersion: AISettingsManager.disclosureVersion,
                    processorManifestVersion: AISettingsManager.processorManifestVersion
                ),
                activeProvider: nil
            )
        }
    }

    @Test("Unchanged account and exact source commit plan and coach turn once")
    func unchangedRequestCommitsExactlyOnce() throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 11)
        let planStore = state.makePlanStore(defaults: defaults)
        let askStore = state.makeAskStore(defaults: defaults)
        let input = makeInput(weeklyDelta: 2, weeklyReps: 4)
        let request = try #require(planStore.generationRequest(for: input))
        let plan = ForwardPlanService.deterministicPlan(input: input)

        #expect(ForwardPlanCoordinator.commit(
            plan,
            request: request,
            currentInput: input,
            planStore: planStore,
            askStore: askStore
        ))
        #expect(planStore.activePlan == plan)
        #expect(askStore.messages.count == 1)
        #expect(askStore.messages.first?.role == .coach)
        #expect(defaults.data(forKey: "forwardPlan.alpha") != nil)
        #expect(defaults.data(forKey: "askNoum.thread.alpha") != nil)

        #expect(!ForwardPlanCoordinator.commit(
            plan,
            request: request,
            currentInput: input,
            planStore: planStore,
            askStore: askStore
        ))
        #expect(askStore.messages.count == 1)
    }

    @Test("Account switch rejects account A completion without writing account B")
    func accountSwitchRejectsDestinationCommit() throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 1)
        let planStore = state.makePlanStore(defaults: defaults)
        let askStore = state.makeAskStore(defaults: defaults)
        let input = makeInput(weeklyDelta: 3)
        let request = try #require(planStore.generationRequest(for: input))
        let plan = ForwardPlanService.deterministicPlan(input: input)

        state.switchAccount(
            to: "beta",
            lifecycle: 2,
            sessionStoreGeneration: 2
        )
        planStore.reloadForCurrentAccount()
        askStore.reloadForCurrentAccount()

        #expect(!ForwardPlanCoordinator.commit(
            plan,
            request: request,
            currentInput: input,
            planStore: planStore,
            askStore: askStore
        ))
        #expect(planStore.activePlan == nil)
        #expect(askStore.messages.isEmpty)
        #expect(defaults.data(forKey: "forwardPlan.beta") == nil)
        #expect(defaults.data(forKey: "askNoum.thread.beta") == nil)
    }

    @Test("Denied account snapshot never borrows a destination account's consent")
    func deniedSnapshotNeverCrossesTransport() async throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(
            accountID: "alpha",
            lifecycle: 1,
            executionAuthorization: LeaseState.deniedAuthorization()
        )
        let planStore = state.makePlanStore(defaults: defaults)
        let input = makeInput()
        let request = try #require(planStore.generationRequest(for: input))
        let transport = ControlledTransport()
        let service = ForwardPlanService(apiKeyProvider: { _ in "test-key" })

        state.switchAccount(
            to: "beta",
            lifecycle: 2,
            sessionStoreGeneration: 2
        )
        state.executionAuthorization = LeaseState.allowedAuthorization()
        planStore.reloadForCurrentAccount()

        let result = await service.generate(
            request: request,
            startTransportIfCurrent: { urlRequest in
                guard planStore.tokenIsCurrent(
                    request.saveToken,
                    currentInput: input
                ) else {
                    return nil
                }
                return transport.start(urlRequest)
            },
            isCurrent: {
                planStore.tokenIsCurrent(
                    request.saveToken,
                    currentInput: input
                )
            }
        )
        let callCount = transport.callCount

        #expect(result?.isAIBacked == false)
        #expect(callCount == 0)
        #expect(defaults.data(forKey: "forwardPlan.beta") == nil)
    }

    @Test("Consent record, revocation, or locale drift fails before transport")
    func executionAuthorizationDriftFailsBeforeTransport() async throws {
        let refreshedConsent = LeaseState.allowedAuthorization(
            decidedAt: Date(timeIntervalSince1970: 1_700_000_200)
        )
        let unsupportedLocale = ForwardPlanExecutionAuthorization(
            locale: .frFR,
            cloudProcessingConsent: LeaseState.allowedAuthorization()
                .cloudProcessingConsent,
            activeProvider: .openAI
        )

        for driftedAuthorization in [
            refreshedConsent,
            LeaseState.deniedAuthorization(),
            unsupportedLocale,
        ] {
            let (_, defaults) = isolatedDefaults()
            let state = LeaseState(accountID: "alpha", lifecycle: 1)
            let planStore = state.makePlanStore(defaults: defaults)
            let input = makeInput()
            let request = try #require(planStore.generationRequest(for: input))
            let transport = ControlledTransport()
            let service = ForwardPlanService(apiKeyProvider: { _ in "test-key" })

            state.executionAuthorization = driftedAuthorization
            let result = await service.generate(
                request: request,
                startTransportIfCurrent: { urlRequest in
                    guard planStore.tokenIsCurrent(
                        request.saveToken,
                        currentInput: input
                    ) else {
                        return nil
                    }
                    return transport.start(urlRequest)
                },
                isCurrent: {
                    planStore.tokenIsCurrent(
                        request.saveToken,
                        currentInput: input
                    )
                }
            )
            let callCount = transport.callCount

            #expect(result == nil)
            #expect(callCount == 0)
            #expect(defaults.data(forKey: "forwardPlan.alpha") == nil)
        }
    }

    @Test("Authorization revoked while awaiting transport cannot produce a result")
    func authorizationDriftDuringTransportRejectsResult() async throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 1)
        let planStore = state.makePlanStore(defaults: defaults)
        let askStore = state.makeAskStore(defaults: defaults)
        let input = makeInput()
        let request = try #require(planStore.generationRequest(for: input))
        let transport = ControlledTransport(suspendsUntilCompleted: true)
        let service = ForwardPlanService(apiKeyProvider: { _ in "test-key" })

        let generation = Task {
            await service.generate(
                request: request,
                startTransportIfCurrent: { urlRequest in
                    guard planStore.tokenIsCurrent(
                        request.saveToken,
                        currentInput: input
                    ) else {
                        return nil
                    }
                    return transport.start(urlRequest)
                },
                isCurrent: {
                    planStore.tokenIsCurrent(
                        request.saveToken,
                        currentInput: input
                    )
                }
            )
        }
        await transport.waitUntilStarted()
        state.executionAuthorization = LeaseState.deniedAuthorization()
        await transport.complete()
        let result = await generation.value

        #expect(result == nil)
        #expect(planStore.activePlan == nil)
        #expect(askStore.messages.isEmpty)
        #expect(defaults.data(forKey: "forwardPlan.alpha") == nil)
        #expect(defaults.data(forKey: "askNoum.thread.alpha") == nil)
    }

    @Test("Cancellation stops an in-flight transport without returning fallback coaching")
    func cancellationStopsTransportAndReturnsNoCandidate() async throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 1)
        let planStore = state.makePlanStore(defaults: defaults)
        let input = makeInput()
        let request = try #require(planStore.generationRequest(for: input))
        let transport = ControlledTransport(suspendsUntilCompleted: true)
        let service = ForwardPlanService(apiKeyProvider: { _ in "test-key" })
        let generation = Task {
            await service.generate(
                request: request,
                startTransportIfCurrent: { urlRequest in
                    guard planStore.tokenIsCurrent(
                        request.saveToken,
                        currentInput: input
                    ) else {
                        return nil
                    }
                    return transport.start(urlRequest)
                },
                isCurrent: {
                    planStore.tokenIsCurrent(
                        request.saveToken,
                        currentInput: input
                    )
                }
            )
        }

        await transport.waitUntilStarted()
        generation.cancel()
        let result = await generation.value

        #expect(result == nil)
        #expect(transport.callCount == 1)
        #expect(planStore.activePlan == nil)
        #expect(defaults.data(forKey: "forwardPlan.alpha") == nil)
    }

    @Test("Sign-out rejects completion instead of creating guest coaching history")
    func signOutRejectsGuestCommit() throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 4)
        let planStore = state.makePlanStore(defaults: defaults)
        let askStore = state.makeAskStore(defaults: defaults)
        let input = makeInput()
        let request = try #require(planStore.generationRequest(for: input))
        let plan = ForwardPlanService.deterministicPlan(input: input)

        state.switchAccount(
            to: nil,
            lifecycle: 5,
            sessionStoreGeneration: 2
        )
        planStore.endSession()
        askStore.endSession()

        #expect(!ForwardPlanCoordinator.commit(
            plan,
            request: request,
            currentInput: input,
            planStore: planStore,
            askStore: askStore
        ))
        #expect(defaults.data(forKey: "forwardPlan.alpha") == nil)
        #expect(defaults.data(forKey: "askNoum.thread.guest") == nil)
    }

    @Test("Rapid return to the same account ID still rejects old lifecycle")
    func sameAccountNewLifecycleRejectsOldRequest() throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 7)
        let planStore = state.makePlanStore(defaults: defaults)
        let askStore = state.makeAskStore(defaults: defaults)
        let input = makeInput()
        let request = try #require(planStore.generationRequest(for: input))
        let plan = ForwardPlanService.deterministicPlan(input: input)

        state.lifecycle = 8

        #expect(!ForwardPlanCoordinator.commit(
            plan,
            request: request,
            currentInput: input,
            planStore: planStore,
            askStore: askStore
        ))
        #expect(planStore.activePlan == nil)
        #expect(askStore.messages.isEmpty)
    }

    @Test("Hydration and loaded-account mismatch cannot lease stale state")
    func hydrationBoundaryRejectsRequest() {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 1)
        let planStore = state.makePlanStore(defaults: defaults)
        let input = makeInput()

        state.isReady = false
        #expect(planStore.generationRequest(for: input) == nil)

        state.isReady = true
        state.accountID = "beta"
        #expect(planStore.generationRequest(for: input) == nil)

        state.accountID = "alpha"
        state.sessionStoreEpoch = PracticeSessionStoreEpoch(
            accountScope: "beta",
            generation: 2
        )
        #expect(planStore.generationRequest(for: input) == nil)
    }

    @Test("Any source drift rejects the pending plan before announcement")
    func sourceDriftRejectsCommit() throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 3)
        let planStore = state.makePlanStore(defaults: defaults)
        let askStore = state.makeAskStore(defaults: defaults)
        let original = makeInput(weeklyDelta: 1)
        let changed = makeInput(weeklyDelta: 2)
        let request = try #require(planStore.generationRequest(for: original))
        let plan = ForwardPlanService.deterministicPlan(input: original)

        #expect(!ForwardPlanCoordinator.commit(
            plan,
            request: request,
            currentInput: changed,
            planStore: planStore,
            askStore: askStore
        ))
        #expect(planStore.activePlan == nil)
        #expect(askStore.messages.isEmpty)
        #expect(defaults.data(forKey: "forwardPlan.alpha") == nil)
    }

    @Test("Newest request wins when completions arrive in reverse order")
    func supersededRequestCannotOverwriteNewestIntent() throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 9)
        let planStore = state.makePlanStore(defaults: defaults)
        let askStore = state.makeAskStore(defaults: defaults)
        let input = makeInput()
        let older = try #require(planStore.generationRequest(for: input))
        let newer = try #require(planStore.generationRequest(for: input))
        let olderPlan = ForwardPlanService.deterministicPlan(input: input)
        let newerPlan = ForwardPlanService.deterministicPlan(input: input)

        #expect(!ForwardPlanCoordinator.commit(
            olderPlan,
            request: older,
            currentInput: input,
            planStore: planStore,
            askStore: askStore
        ))
        #expect(askStore.messages.isEmpty)

        #expect(ForwardPlanCoordinator.commit(
            newerPlan,
            request: newer,
            currentInput: input,
            planStore: planStore,
            askStore: askStore
        ))
        #expect(planStore.activePlan?.id == newerPlan.id)
        #expect(askStore.messages.count == 1)
    }

    @Test("Ask loaded-account rejection leaves the plan untouched")
    func splitCommitFailsClosed() throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 12)
        let planStore = state.makePlanStore(defaults: defaults)
        let wrongAskStore = AskNoumStore(
            defaults: defaults,
            accountIDProvider: { "beta" }
        )
        let input = makeInput()
        let request = try #require(planStore.generationRequest(for: input))
        let plan = ForwardPlanService.deterministicPlan(input: input)

        #expect(!ForwardPlanCoordinator.commit(
            plan,
            request: request,
            currentInput: input,
            planStore: planStore,
            askStore: wrongAskStore
        ))
        #expect(planStore.activePlan == nil)
        #expect(wrongAskStore.messages.isEmpty)
        #expect(defaults.data(forKey: "forwardPlan.alpha") == nil)
    }

    @Test("Reload and end-session invalidate outstanding request generations")
    func lifecycleHooksInvalidateRequests() throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 2)
        let planStore = state.makePlanStore(defaults: defaults)
        let input = makeInput()
        let beforeReload = try #require(planStore.generationRequest(for: input))

        planStore.reloadForCurrentAccount()
        #expect(!planStore.tokenIsCurrent(
            beforeReload.saveToken,
            currentInput: input
        ))

        let beforeEnd = try #require(planStore.generationRequest(for: input))
        planStore.endSession()
        #expect(!planStore.tokenIsCurrent(
            beforeEnd.saveToken,
            currentInput: input
        ))
    }

    @Test("Newer phrase reconciliation defeats a pending generated plan")
    func phraseMutationInvalidatesPendingRequest() throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 2)
        let input = makeInput()
        let phraseID = UUID()
        let basePlan = ForwardPlanService.deterministicPlan(input: input)
        let installedPlan = ForwardPlan(
            id: basePlan.id,
            weeks: basePlan.weeks,
            generatedAt: basePlan.generatedAt,
            bigMomentID: basePlan.bigMomentID,
            voiceAtGeneration: basePlan.voiceAtGeneration,
            isAIBacked: basePlan.isAIBacked,
            practicePhraseEntryIDsByWeek: [1: phraseID]
        )
        defaults.set(
            try JSONEncoder().encode(installedPlan),
            forKey: "forwardPlan.alpha"
        )
        let planStore = state.makePlanStore(defaults: defaults)
        let askStore = state.makeAskStore(defaults: defaults)
        let request = try #require(planStore.generationRequest(for: input))
        let staleCompletion = ForwardPlanService.deterministicPlan(input: input)

        planStore.reconcilePracticePhraseReferences(validEntryIDs: [])

        #expect(!planStore.tokenIsCurrent(
            request.saveToken,
            currentInput: input
        ))
        #expect(!ForwardPlanCoordinator.commit(
            staleCompletion,
            request: request,
            currentInput: input,
            planStore: planStore,
            askStore: askStore
        ))
        #expect(planStore.activePlan?.id == installedPlan.id)
        #expect(planStore.activePlan?.practicePhraseEntryID(forWeek: 1) == nil)
        let persistedData = try #require(
            defaults.data(forKey: "forwardPlan.alpha")
        )
        let persisted = try JSONDecoder().decode(
            ForwardPlan.self,
            from: persistedData
        )
        #expect(persisted.id == installedPlan.id)
        #expect(persisted.practicePhraseEntryID(forWeek: 1) == nil)
        #expect(askStore.messages.isEmpty)
    }

    @Test("User phrase assignment defeats a pending generated plan")
    func phraseAssignmentInvalidatesPendingRequest() throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 2)
        let input = makeInput()
        let installedPlan = ForwardPlanService.deterministicPlan(input: input)
        defaults.set(
            try JSONEncoder().encode(installedPlan),
            forKey: "forwardPlan.alpha"
        )
        let planStore = state.makePlanStore(defaults: defaults)
        let askStore = state.makeAskStore(defaults: defaults)
        let phraseBank = PhraseBankStore(
            defaults: defaults,
            accountIDProvider: { state.accountID }
        )
        let entry = try #require(phraseBank.save(
            text: "Lead with the decision, then give one reason.",
            voice: .executive,
            weakness: .concise,
            intensity: .light
        ))
        let renderedTarget = try #require(
            ForwardPlanPhraseProjection.target(plan: planStore.activePlan)
        )
        let request = try #require(planStore.generationRequest(for: input))
        let staleCompletion = ForwardPlanService.deterministicPlan(input: input)

        #expect(ForwardPlanPhraseCoordinator.assign(
            entryID: entry.id,
            renderedTarget: renderedTarget,
            currentPlan: planStore.activePlan,
            phraseBank: phraseBank,
            planStore: planStore
        ))

        #expect(!planStore.tokenIsCurrent(
            request.saveToken,
            currentInput: input
        ))
        #expect(!ForwardPlanCoordinator.commit(
            staleCompletion,
            request: request,
            currentInput: input,
            planStore: planStore,
            askStore: askStore
        ))
        #expect(planStore.activePlan?.id == installedPlan.id)
        #expect(
            planStore.activePlan?.practicePhraseEntryID(
                forWeek: renderedTarget.weekIndex
            ) == entry.id
        )
        let persistedData = try #require(
            defaults.data(forKey: "forwardPlan.alpha")
        )
        let persisted = try JSONDecoder().decode(
            ForwardPlan.self,
            from: persistedData
        )
        #expect(
            persisted.practicePhraseEntryID(
                forWeek: renderedTarget.weekIndex
            ) == entry.id
        )
        #expect(askStore.messages.isEmpty)
    }

    @Test("Account deletion invalidates leases and clears loaded ownership")
    func deletionInvalidatesRequestAndLoadedScope() throws {
        let (_, defaults) = isolatedDefaults()
        let state = LeaseState(accountID: "alpha", lifecycle: 2)
        let input = makeInput()
        let installedPlan = ForwardPlanService.deterministicPlan(input: input)
        defaults.set(
            try JSONEncoder().encode(installedPlan),
            forKey: "forwardPlan.alpha"
        )
        let planStore = state.makePlanStore(defaults: defaults)
        #expect(planStore.activePlan == installedPlan)
        let request = try #require(planStore.generationRequest(for: input))

        planStore.deleteAllData(for: "alpha")

        #expect(planStore.loadedAccountScope == nil)
        #expect(planStore.activePlan == nil)
        #expect(!planStore.tokenIsCurrent(
            request.saveToken,
            currentInput: input
        ))
        #expect(defaults.data(forKey: "forwardPlan.alpha") == nil)
    }

    @Test("Generation identity covers every plan-shaping input family")
    func inputIdentityCoversAllInputFamilies() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let base = makeInput()
        let baseIdentity = try #require(base.generationIdentity)
        var changedBaseline = CommunicationBaseline.empty
        changedBaseline.sessionCount = 1
        let session = PracticeSession(
            transcript: "One exact source sentence for the plan.",
            fillerWordCount: 1,
            duration: 20,
            date: date,
            mode: .timed,
            score: 6
        )
        let moment = BigMoment(
            title: "Board review",
            date: date,
            category: .review,
            createdAt: date
        )
        let trend = SkillTrend(
            skillArea: .structure,
            direction: .declining,
            confidence: .high,
            windowSize: 5,
            currentLevel: .developing,
            recentDelta: "Less structured"
        )
        let drill = DrillHistoryStore.Entry(
            variationId: "structure-1",
            skillArea: .structure,
            date: date,
            succeeded: true,
            sessionId: session.id
        )
        let outcome = RecommendationOutcome(
            id: UUID(),
            fingerprint: "recommendation-1",
            title: "Pressure rehearsal",
            focus: "Structure",
            target: "Lead with the decision",
            mode: .timed,
            sessionID: session.id,
            followed: true,
            completedAt: date,
            scoreDelta: 1,
            hasComparableScore: true,
            fillerDelta: -1,
            durationDelta: 0
        )
        let transfer = BigMomentOutcomeReport(
            moment: moment,
            outcome: .mixed,
            audienceResponse: .unclear,
            drillTransfer: .partly,
            recordedAt: date
        )

        let variants = [
            makeInput(profile: makeProfile()),
            makeInput(baseline: changedBaseline),
            makeInput(sessions: [session]),
            makeInput(weeklyDelta: 1),
            makeInput(weeklyReps: 1),
            makeInput(currentStreak: 1),
            makeInput(bigMoment: moment),
            makeInput(bigMomentDaysUntil: 3),
            makeInput(trends: [trend]),
            makeInput(recentDrills: [drill]),
            makeInput(recommendationOutcomes: [outcome]),
            makeInput(transferOutcomes: [transfer]),
        ]
        let identities = variants.compactMap(\.generationIdentity)

        #expect(identities.count == variants.count)
        #expect(identities.allSatisfy { $0 != baseIdentity })
        #expect(Set(identities).count == identities.count)
    }

    private func makeInput(
        profile: CoachingProfile? = nil,
        baseline: CommunicationBaseline = .empty,
        sessions: [PracticeSession] = [],
        weeklyDelta: Int = 0,
        weeklyReps: Int = 0,
        currentStreak: Int = 0,
        bigMoment: BigMoment? = nil,
        bigMomentDaysUntil: Int? = nil,
        trends: [SkillTrend] = [],
        recentDrills: [DrillHistoryStore.Entry] = [],
        recommendationOutcomes: [RecommendationOutcome] = [],
        transferOutcomes: [BigMomentOutcomeReport] = []
    ) -> ForwardPlanInput {
        ForwardPlanInput(
            profile: profile,
            baseline: baseline,
            sessions: sessions,
            weeklyDelta: weeklyDelta,
            weeklyReps: weeklyReps,
            currentStreak: currentStreak,
            bigMoment: bigMoment,
            bigMomentDaysUntil: bigMomentDaysUntil,
            trends: trends,
            recentDrills: recentDrills,
            recommendationOutcomes: recommendationOutcomes,
            transferOutcomes: transferOutcomes
        )
    }

    private func makeProfile() -> CoachingProfile {
        CoachingProfile(
            speakingContext: .work,
            primaryGoal: .moreConcise,
            confidenceLevel: .beginner,
            biggestChallenge: .rambling,
            desiredOutcome: .concise,
            speakingStyleGoal: .executive,
            styleReference: "Direct and composed",
            coachingBrief: "Lead with the decision",
            motivationWhyNow: "A board review is coming",
            successVision: "A clear recommendation",
            chosenStyleGoal: .executive
        )
    }

    private func isolatedDefaults() -> (String, UserDefaults) {
        let name = "ForwardPlanAccountIsolationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (name, defaults)
    }

    @MainActor
    private final class ControlledTransport {
        private(set) var callCount = 0
        private let suspendsUntilCompleted: Bool
        private let gate = ControlledTransportGate()

        init(suspendsUntilCompleted: Bool = false) {
            self.suspendsUntilCompleted = suspendsUntilCompleted
        }

        func start(_ request: URLRequest) -> ForwardPlanTransportHandle {
            callCount += 1
            let suspends = suspendsUntilCompleted
            let gate = self.gate
            return ForwardPlanTransportHandle(
                response: {
                    try await gate.response(
                        url: request.url,
                        suspendsUntilCompleted: suspends
                    )
                },
                cancellation: {
                    Task {
                        await gate.cancel()
                    }
                }
            )
        }

        func waitUntilStarted() async {
            await gate.waitUntilStarted()
        }

        func complete() async {
            await gate.complete()
        }
    }

    private actor ControlledTransportGate {
        private var started = false
        private var pendingURL: URL?
        private var completion: CheckedContinuation<(Data, URLResponse), Error>?
        private var startWaiters: [CheckedContinuation<Void, Never>] = []

        func response(
            url: URL?,
            suspendsUntilCompleted: Bool
        ) async throws -> (Data, URLResponse) {
            started = true
            pendingURL = url
            let waiters = startWaiters
            startWaiters.removeAll()
            waiters.forEach { $0.resume() }

            guard suspendsUntilCompleted else {
                return successResponse(url: url)
            }
            return try await withCheckedThrowingContinuation { continuation in
                completion = continuation
            }
        }

        func waitUntilStarted() async {
            guard !started else { return }
            await withCheckedContinuation { continuation in
                startWaiters.append(continuation)
            }
        }

        func complete() {
            guard let completion else { return }
            self.completion = nil
            completion.resume(returning: successResponse(url: pendingURL))
        }

        func cancel() {
            guard let completion else { return }
            self.completion = nil
            completion.resume(throwing: URLError(.cancelled))
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
}
