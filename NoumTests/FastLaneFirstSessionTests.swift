import Foundation
import Testing
@testable import Noum

@MainActor
@Suite(.serialized)
struct FastLaneFirstSessionTests {
    private final class AccountBox {
        var id: String?
        init(_ id: String?) { self.id = id }
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suite = "FastLaneFirstSessionTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (defaults, suite)
    }

    private func makeStore(
        defaults: UserDefaults,
        account: AccountBox
    ) -> CoachingProfileStore {
        CoachingProfileStore(
            defaults: defaults,
            accountIDProvider: { account.id },
            providerRawValueProvider: { nil }
        )
    }

    private func completeProfile(
        context: SpeakingContext = .work,
        challenge: SpeakingChallenge = .rambling
    ) -> CoachingProfile {
        CoachingProfile(
            speakingContext: context,
            primaryGoal: challenge.recommendedPriority,
            confidenceLevel: .rebuilding,
            biggestChallenge: challenge,
            desiredOutcome: .concise,
            speakingStyleGoal: .concise,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: "",
            chosenStyleGoal: .concise
        )
    }

    private let qualifyingResponses: [SpeakingContext: String] = [
        .work: "The launch needs attention because one dependency is late, so I will reset the date today.",
        .interviews: "I chose the smaller release because the data showed lower risk, and I learned to test earlier.",
        .presentations: "The main message is retention because renewals rose twelve percent, so approve the next trial.",
        .social: "I hear that this week was difficult. What would feel most helpful from me right now?",
    ]

    @Test func authoredCatalogCoversEveryContextExactlyOnce() {
        #expect(StructuredFirstValueCatalog.prompts.count == SpeakingContext.allCases.count)
        #expect(Set(StructuredFirstValueCatalog.prompts.map(\.context)) == Set(SpeakingContext.allCases))
        #expect(Set(StructuredFirstValueCatalog.prompts.map(\.id)).count == SpeakingContext.allCases.count)
        for context in SpeakingContext.allCases {
            let prompt = StructuredFirstValueCatalog.prompt(for: context)
            #expect(prompt.context == context)
            #expect(prompt.rubric.count >= 2)
            #expect(!prompt.prompt.isEmpty)
        }
    }

    @Test func socialPromptStaysTruthfulToARealSocialContext() {
        let prompt = StructuredFirstValueCatalog.prompt(for: .social).prompt.lowercased()
        #expect(prompt.contains("friend"))
        for forbidden in ["client", "customer", "prospect", "discovery call", "stakeholder"] {
            #expect(!prompt.contains(forbidden))
        }
    }

    @Test func structuredProjectionRequiresEightWords() {
        let prompt = StructuredFirstValueCatalog.prompt(for: .work)
        #expect(RoleplayEngine.evaluateStructuredFirstValue(
            response: "One two three four five six seven",
            prompt: prompt
        ) == nil)
        #expect(RoleplayEngine.evaluateStructuredFirstValue(
            response: "One two three four five six seven eight",
            prompt: prompt
        ) != nil)
    }

    @Test func structuredProjectionIsDeterministicAcrossEveryContext() throws {
        for context in SpeakingContext.allCases {
            let prompt = StructuredFirstValueCatalog.prompt(for: context)
            let response = try #require(qualifyingResponses[context])
            let first = try #require(RoleplayEngine.evaluateStructuredFirstValue(
                response: response,
                prompt: prompt
            ))
            let second = try #require(RoleplayEngine.evaluateStructuredFirstValue(
                response: response,
                prompt: prompt
            ))
            #expect(first == second)
            #expect(prompt.rubric.contains(first.strengthAxis))
            #expect(prompt.rubric.contains(first.nextAxis))
            #expect(first.metadata.promptID == prompt.id)
        }
    }

    @Test func structuredFeedbackNeverClaimsDeliveryEvidence() throws {
        let banned = [
            "filler", "pace", "wpm", "tone", "voice", "pause",
            "composure", "vocal", "microphone", "transcript", "spoken",
        ]
        for context in SpeakingContext.allCases {
            let response = try #require(qualifyingResponses[context])
            let result = try #require(RoleplayEngine.evaluateStructuredFirstValue(
                response: response,
                prompt: StructuredFirstValueCatalog.prompt(for: context)
            ))
            let copy = [result.strength, result.nextMove, StructuredFirstValueResult.scopeNote]
                .joined(separator: " ")
                .lowercased()
            for word in banned {
                #expect(!copy.contains(word))
            }
        }
    }

    @Test func structuredProjectionExcludesSpokenOnlyAxes() {
        let allowed = Set(StructuredFirstValueAxis.allCases)
        #expect(allowed == Set([
            .directness, .evidence, .listening, .ownership,
            .constructiveness, .inquiry,
        ]))
    }

    @Test func persistedStructuredWordCountIsBounded() {
        #expect(StructuredFirstValueMetadata(
            promptID: "bounded",
            wordCount: -10
        ).wordCount == 0)
        #expect(StructuredFirstValueMetadata(
            promptID: "bounded",
            wordCount: 10_000
        ).wordCount == 600)
    }

    @Test func encodedDraftContainsNoRawResponseOrSyntheticScore() throws {
        let response = "Zebra quartz evidence stays transient and must never enter the saved onboarding draft."
        let result = try #require(RoleplayEngine.evaluateStructuredFirstValue(
            response: response,
            prompt: StructuredFirstValueCatalog.prompt(for: .work)
        ))
        let draft = CoachingProfileDraft(
            correlationID: UUID(),
            speakingContext: .work,
            speakingChallenge: .rambling,
            firstValueReceipt: .structured(result)
        )
        let encoded = String(decoding: try JSONEncoder().encode(draft), as: UTF8.self).lowercased()
        #expect(!encoded.contains("zebra"))
        #expect(!encoded.contains("quartz"))
        #expect(!encoded.contains("response"))
        #expect(!encoded.contains("score"))
        #expect(encoded.contains(result.metadata.promptID.lowercased()))
    }

    @Test func receiptCoherenceSeparatesWrittenAndSpokenValue() throws {
        let response = try #require(qualifyingResponses[.work])
        let result = try #require(RoleplayEngine.evaluateStructuredFirstValue(
            response: response,
            prompt: StructuredFirstValueCatalog.prompt(for: .work)
        ))
        let structured = FirstValueReceipt.structured(result)
        let sessionID = UUID()
        let spoken = FirstValueReceipt.spokenTimed(sessionID: sessionID)
        #expect(structured.isCoherent)
        #expect(structured.sessionID == nil)
        #expect(structured.structuredResult != nil)
        #expect(spoken.isCoherent)
        #expect(spoken.sessionID == sessionID)
        #expect(spoken.structuredResult == nil)
    }

    @Test func thinOrUnidentifiedStructuredReceiptIsIncoherent() {
        let thin = FirstValueReceipt.structured(
            metadata: StructuredFirstValueMetadata(promptID: "work", wordCount: 7)
        )
        let unidentified = FirstValueReceipt.structured(
            metadata: StructuredFirstValueMetadata(promptID: "   ", wordCount: 12)
        )
        #expect(!thin.isCoherent)
        #expect(!unidentified.isCoherent)

        let invalidDraft = CoachingProfileDraft(
            speakingContext: .work,
            speakingChallenge: .rambling,
            firstValueReceipt: thin
        )
        #expect(FirstRunOnboardingGate.rootRoute(
            hasCoachingProfile: false,
            draft: invalidDraft,
            isUITesting: false
        ) == .fastLane)
    }

    @Test func rootRouteMatrixKeepsProfileAsFullOnboardingTruth() {
        let incomplete = CoachingProfileDraft(
            speakingContext: .work,
            speakingChallenge: .rambling
        )
        let complete = incomplete.recording(.structured(
            metadata: StructuredFirstValueMetadata(promptID: "work-clear-update", wordCount: 12)
        ))

        #expect(FirstRunOnboardingGate.rootRoute(
            hasCoachingProfile: false, draft: nil, isUITesting: false
        ) == .fastLane)
        #expect(FirstRunOnboardingGate.rootRoute(
            hasCoachingProfile: false, draft: incomplete, isUITesting: false
        ) == .fastLane)
        #expect(FirstRunOnboardingGate.rootRoute(
            hasCoachingProfile: false,
            draft: complete,
            postValueChoice: .completeCoachingSetup,
            isUITesting: false
        ) == .fullOnboarding)
        #expect(FirstRunOnboardingGate.rootRoute(
            hasCoachingProfile: false,
            draft: complete,
            postValueChoice: .enterApp,
            isUITesting: false
        ) == .appShell)
        #expect(FirstRunOnboardingGate.rootRoute(
            hasCoachingProfile: false, draft: complete, isUITesting: false
        ) == .appShell)
        #expect(FirstRunOnboardingGate.rootRoute(
            hasCoachingProfile: true, draft: incomplete, isUITesting: false
        ) == .appShell)
        #expect(FirstRunOnboardingGate.rootRoute(
            hasCoachingProfile: false, draft: nil, isUITesting: true
        ) == .appShell)
    }

    @Test func saveReloadEndSessionAndAccountIsolation() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let account = AccountBox("account-a")
        let store = makeStore(defaults: defaults, account: account)

        #expect(store.saveDraft(context: .work, challenge: .rambling, now: Date(timeIntervalSince1970: 10)))
        let accountACorrelation = try #require(store.onboardingDraft?.correlationID)
        #expect(store.recordStructuredFirstValue(wordCount: 12, now: Date(timeIntervalSince1970: 20)))
        store.endSession()
        #expect(store.onboardingDraft == nil)
        store.reloadForCurrentAccount()
        #expect(store.onboardingDraft?.correlationID == accountACorrelation)
        #expect(store.onboardingDraft?.firstValueReceipt?.structuredResult?.wordCount == 12)

        account.id = "account-b"
        store.reloadForCurrentAccount()
        #expect(store.onboardingDraft == nil)
        #expect(store.saveDraft(context: .social, challenge: .freezing))
        let accountBCorrelation = try #require(store.onboardingDraft?.correlationID)
        #expect(accountBCorrelation != accountACorrelation)

        account.id = "account-a"
        store.reloadForCurrentAccount()
        #expect(store.onboardingDraft?.correlationID == accountACorrelation)
        #expect(store.onboardingDraft?.speakingContext == .work)
    }

    @Test func sameChoicesKeepCorrelationAndChangedChoicesRestartIt() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let account = AccountBox("account-a")
        let store = makeStore(defaults: defaults, account: account)
        #expect(store.saveDraft(context: .work, challenge: .rambling))
        let first = try #require(store.onboardingDraft?.correlationID)
        #expect(store.saveDraft(context: .work, challenge: .rambling))
        #expect(store.onboardingDraft?.correlationID == first)
        #expect(store.saveDraft(context: .presentations, challenge: .rambling))
        #expect(store.onboardingDraft?.correlationID != first)
    }

    @Test func structuredResultMustMatchDraftPromptAndRubric() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let account = AccountBox("account-a")
        let store = makeStore(defaults: defaults, account: account)
        #expect(store.saveDraft(context: .work, challenge: .rambling))

        let wrongPrompt = StructuredFirstValueResult(
            promptID: StructuredFirstValueCatalog.prompt(for: .social).id,
            wordCount: 12,
            strengthAxis: .listening,
            nextAxis: .inquiry,
            strength: "Supported written strength.",
            nextMove: "Supported written next move."
        )
        #expect(!store.recordStructuredFirstValue(result: wrongPrompt))
        #expect(store.onboardingDraft?.firstValueReceipt == nil)

        let draft = try #require(store.onboardingDraft)
        let mismatchedPersistedDraft = draft.recording(.structured(wrongPrompt))
        #expect(!mismatchedPersistedDraft.isCoherent)
        #expect(!store.saveDraft(mismatchedPersistedDraft))
        #expect(store.onboardingDraft?.firstValueReceipt == nil)

        let wrongRubric = StructuredFirstValueResult(
            promptID: StructuredFirstValueCatalog.prompt(for: .work).id,
            wordCount: 12,
            strengthAxis: .listening,
            nextAxis: .directness,
            strength: "Supported written strength.",
            nextMove: "Supported written next move."
        )
        #expect(!store.recordStructuredFirstValue(result: wrongRubric))
        #expect(store.onboardingDraft?.firstValueReceipt == nil)
    }

    @Test func corruptDraftRecoversToCleanFastLane() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let account = AccountBox("account-a")
        let key = CoachingProfileStore.draftKey(for: "account-a")
        defaults.set(Data("not-json".utf8), forKey: key)
        let store = makeStore(defaults: defaults, account: account)
        store.reloadForCurrentAccount()
        #expect(store.onboardingDraft == nil)
        #expect(defaults.data(forKey: key) == nil)
    }

    @Test func debugResetClearsOnlyTheCurrentAccountDraftAndKeepsProfile() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let account = AccountBox("account-a")
        let store = makeStore(defaults: defaults, account: account)
        let keyA = CoachingProfileStore.draftKey(for: "account-a")
        let keyB = CoachingProfileStore.draftKey(for: "account-b")

        #expect(store.saveDraft(context: .work, challenge: .rambling))
        let profile = completeProfile()
        #expect(store.save(profile))
        let staleDraft = CoachingProfileDraft(
            speakingContext: .work,
            speakingChallenge: .rambling
        )
        defaults.set(try JSONEncoder().encode(staleDraft), forKey: keyA)
        defaults.set(Data("another-account".utf8), forKey: keyB)
        store.resetOnboardingDraftForDebug()

        #expect(store.onboardingDraft == nil)
        #expect(store.profile == profile)
        #expect(defaults.data(forKey: keyA) == nil)
        #expect(defaults.data(forKey: keyB) == Data("another-account".utf8))

        store.endSession()
        store.reloadForCurrentAccount()
        #expect(store.profile == profile)
    }

    @Test func debugResetUsesGuestNamespaceWithoutAnAccount() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let account = AccountBox(nil)
        let store = makeStore(defaults: defaults, account: account)
        let guestKey = CoachingProfileStore.draftKey(for: "guest")
        defaults.set(Data("guest-draft".utf8), forKey: guestKey)

        store.resetOnboardingDraftForDebug()

        #expect(store.onboardingDraft == nil)
        #expect(defaults.data(forKey: guestKey) == nil)
    }

    @Test func verifiedProfileSaveClearsDraftAndFailedSavePreservesIt() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let account = AccountBox("account-a")
        let store = makeStore(defaults: defaults, account: account)
        #expect(store.saveDraft(context: .work, challenge: .rambling))
        let draftKey = CoachingProfileStore.draftKey(for: "account-a")

        account.id = nil
        #expect(!store.save(completeProfile()))
        #expect(defaults.data(forKey: draftKey) != nil)

        account.id = "account-a"
        #expect(store.save(completeProfile()))
        #expect(store.profile != nil)
        #expect(store.onboardingDraft == nil)
        #expect(defaults.data(forKey: draftKey) == nil)
    }

    @Test func profileWinsAndCleansStaleDraftOnReloadAndRemoteReplace() {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let account = AccountBox("account-a")
        let store = makeStore(defaults: defaults, account: account)
        #expect(store.saveDraft(context: .work, challenge: .rambling))
        store.replaceFromRemote(completeProfile(), for: "account-a")
        #expect(store.profile != nil)
        #expect(store.onboardingDraft == nil)
        #expect(defaults.data(forKey: CoachingProfileStore.draftKey(for: "account-a")) == nil)
        #expect(!store.saveDraft(context: .social, challenge: .freezing))

        // Reintroduce a stale draft to simulate a crash after profile write but
        // before cleanup; reload must still let the complete profile win.
        let stale = CoachingProfileDraft(speakingContext: .social, speakingChallenge: .freezing)
        defaults.set(try? JSONEncoder().encode(stale), forKey: CoachingProfileStore.draftKey(for: "account-a"))
        store.endSession()
        store.reloadForCurrentAccount()
        #expect(store.profile != nil)
        #expect(store.onboardingDraft == nil)
        #expect(defaults.data(forKey: CoachingProfileStore.draftKey(for: "account-a")) == nil)
    }

    @Test func draftKeyAndRegistryExportDeletionAreAccountScoped() throws {
        let (defaults, suite) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let keyA = CoachingProfileStore.draftKey(for: "account-a")
        let keyB = CoachingProfileStore.draftKey(for: "account-b")
        #expect(keyA == "\(CoachingProfileStore.draftKeyPrefix)account-a")
        #expect(keyA != keyB)
        defaults.set(Data("a".utf8), forKey: keyA)
        defaults.set(Data("b".utf8), forKey: keyB)

        let registry = AccountDataRegistry.production(defaults: defaults)
        let entries = try registry.exportEntries(for: "account-a")
        let coachingEntry = try #require(entries.first { $0.relativePath == "data/coaching-profile.json" })
        let payloadData: Data
        switch coachingEntry.source {
        case .data(let data): payloadData = data
        case .file: Issue.record("Expected defaults-backed data export"); return
        }
        let payload = String(decoding: payloadData, as: UTF8.self)
        #expect(payload.contains(keyA))
        #expect(!payload.contains(keyB))

        try registry.deleteAllData(for: "account-a")
        #expect(defaults.data(forKey: keyA) == nil)
        #expect(defaults.data(forKey: keyB) != nil)
    }

    @Test func deferredProfilePromptsWaitForACompleteProfile() {
        let manager = DeferredProfileCaptureManager.shared
        manager.resetForUITesting()
        defer { manager.resetForUITesting() }

        manager.consider(sessionCount: 1, profile: nil)

        #expect(manager.pendingPrompt == nil)
    }
}
