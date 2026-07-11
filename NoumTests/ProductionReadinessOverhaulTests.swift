import Foundation
import Testing
@testable import Noum

@Suite("Production app shell routing")
struct ProductionAppShellRoutingTests {
    @Test func deepLinksSelectTheirOwningTab() throws {
        let expected: [(String, AppTab)] = [
            ("noum://home", .home),
            ("noum://ask/type", .home),
            ("noum://practice/timed", .train),
            ("noum://lessons", .train),
            ("noum://path", .train),
            ("noum://review", .review),
            ("noum://growth", .review),
            ("noum://profile", .profile),
            ("noum://league", .profile),
            ("noum://friend/example-account", .profile),
            ("noum://settings", .settings)
        ]

        for (rawURL, tab) in expected {
            let url = try #require(URL(string: rawURL))
            #expect(AppTab.topLevelRoute(for: url) == tab)
        }
    }

    @Test func singularFriendDeepLinkKeepsTheFeatureReachable() throws {
        let url = try #require(URL(string: "noum://friend/example-account"))
        #expect(AppTab.topLevelRoute(for: url) == .profile)
        #expect(AppTab.rootDestination(for: url) == .friendLeaderboard)
    }

    @Test func nestedDeepLinksResolveWithoutDuplicatingRouters() throws {
        let lesson = try #require(LessonsCatalog.all.first)
        let lessonURL = try #require(URL(string: "noum://lesson/\(lesson.id)"))
        guard case .lesson(let resolvedID)? = AppTab.rootDestination(for: lessonURL) else {
            Issue.record("Known lesson did not resolve through AppDestination")
            return
        }
        #expect(resolvedID == lesson.id)

        let typed = try #require(URL(string: "noum://ask/type"))
        guard case .askNoumTyped? = AppTab.rootDestination(for: typed) else {
            Issue.record("Typed Ask Noum did not resolve")
            return
        }

        let pace = try #require(URL(string: "noum://practice/pace"))
        guard case .paceTrainingPractice? = AppTab.rootDestination(for: pace) else {
            Issue.record("Pace did not resolve")
            return
        }
    }
}

@Suite("Privacy production contracts")
struct PrivacyProductionContractTests {
    @Test func appTargetDoesNotExplicitlyLinkFirebaseAnalytics() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let projectFile = repositoryRoot
            .appendingPathComponent("Noum.xcodeproj")
            .appendingPathComponent("project.pbxproj")
        let project = try String(contentsOf: projectFile, encoding: .utf8)

        #expect(!project.contains("FirebaseAnalytics"))
    }

    @Test func topLevelPrivacyManifestDeclaresOnlyNoumFunctionalityData() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manifestFile = repositoryRoot
            .appendingPathComponent("Noum")
            .appendingPathComponent("PrivacyInfo.xcprivacy")
        let manifestData = try Data(contentsOf: manifestFile)
        let manifest = try #require(
            try PropertyListSerialization.propertyList(
                from: manifestData,
                options: [],
                format: nil
            ) as? [String: Any]
        )
        let collectedTypes = try #require(
            manifest["NSPrivacyCollectedDataTypes"] as? [[String: Any]]
        )

        let declaredTypes = Set(collectedTypes.compactMap { entry in
            entry["NSPrivacyCollectedDataType"] as? String
        })
        let expectedTypes: Set<String> = [
            "NSPrivacyCollectedDataTypeAudioData",
            "NSPrivacyCollectedDataTypeName",
            "NSPrivacyCollectedDataTypeOtherUserContent",
            "NSPrivacyCollectedDataTypePhotosorVideos",
            "NSPrivacyCollectedDataTypeProductInteraction",
            "NSPrivacyCollectedDataTypeUserID",
        ]
        #expect(declaredTypes == expectedTypes)

        let declaredPurposes = collectedTypes.flatMap { entry in
            entry["NSPrivacyCollectedDataTypePurposes"] as? [String] ?? []
        }
        #expect(!declaredPurposes.contains("NSPrivacyCollectedDataTypePurposeAnalytics"))
        #expect(collectedTypes.allSatisfy { entry in
            entry["NSPrivacyCollectedDataTypePurposes"] as? [String]
                == ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]
        })
        #expect(collectedTypes.allSatisfy { entry in
            entry["NSPrivacyCollectedDataTypeLinked"] as? Bool == true
                && entry["NSPrivacyCollectedDataTypeTracking"] as? Bool == false
        })

        let accessedAPITypes = try #require(
            manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]]
        )
        let reasonsByAPI: [String: Set<String>] = Dictionary(
            uniqueKeysWithValues: accessedAPITypes.compactMap { entry -> (String, Set<String>)? in
                guard let api = entry["NSPrivacyAccessedAPIType"] as? String,
                      let reasons = entry["NSPrivacyAccessedAPITypeReasons"] as? [String] else {
                    return nil
                }
                return (api, Set(reasons))
            }
        )
        let expectedReasonsByAPI: [String: Set<String>] = [
            "NSPrivacyAccessedAPICategoryFileTimestamp": ["C617.1"],
            "NSPrivacyAccessedAPICategorySystemBootTime": ["35F9.1"],
            "NSPrivacyAccessedAPICategoryUserDefaults": ["CA92.1"],
        ]
        #expect(reasonsByAPI == expectedReasonsByAPI)
        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [String])?.isEmpty == true)
    }

    @Test func sourcePoliciesDiscloseRequiredSDKProcessing() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let policyFiles = [
            repositoryRoot.appendingPathComponent("Noum/PrivacyPolicy.md"),
            repositoryRoot.appendingPathComponent("public/privacy.html"),
        ]
        let requiredDisclosures = [
            "July 11, 2026",
            "Noum itself does not store your email address, phone number, or password in Noum profile or session records.",
            "Google's bundled sign-in SDK declares that it may process linked name, email address, phone number, coarse location, user ID, device ID, other usage data, and other data types.",
            "Its manifest lists name, email address, phone number, and coarse location for app functionality; user ID and other data types for app functionality and analytics; and device ID and other usage data for analytics.",
            "It declares no tracking",
            "The Firebase Authentication SDK manifest declares linked user ID for app functionality; Firebase Authentication and Firestore SDK manifests declare unlinked other diagnostic data for analytics purposes",
            "Noum does not include a dedicated Firebase Analytics SDK, advertising SDK, or cross-app tracking SDK.",
            "Required Google Sign-In, Firebase Authentication, and Firestore SDKs carry vendor-declared analytics-purpose processing as described above.",
            "Noum does not use that processing for advertising or cross-app tracking.",
            "Noum does not share data with advertising networks or data brokers.",
        ]

        for policyFile in policyFiles {
            let policy = try String(contentsOf: policyFile, encoding: .utf8)
            for disclosure in requiredDisclosures {
                #expect(policy.contains(disclosure))
            }
            #expect(!policy.contains("No data is shared with analytics providers"))
        }
    }
}

@Suite("Firestore production contracts")
struct FirestoreProductionContractTests {
    @Test func challengeQueriesRequireTheAuthenticatedFirebaseUID() {
        #expect(BackendSyncManager.authorizedChallengeParticipantID(
            requestedID: "firebase-user",
            firebaseUID: "firebase-user"
        ) == "firebase-user")
        #expect(BackendSyncManager.authorizedChallengeParticipantID(
            requestedID: "legacy-local-uuid",
            firebaseUID: "firebase-user"
        ) == nil)
        #expect(BackendSyncManager.authorizedChallengeParticipantID(
            requestedID: "firebase-user",
            firebaseUID: nil
        ) == nil)
    }
}

#if DEBUG
@Suite("UI automation account isolation")
struct UIAutomationAccountIsolationTests {
    @Test func automationDoesNotRaceSeededStoresWithCredentialRestore() {
        #expect(!AuthManager.shouldRestorePersistedSession(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE"]
        ))
        #expect(AuthManager.shouldRestorePersistedSession(
            arguments: ["Noum"]
        ))
    }
}
#endif

@Suite("Coach chat wire contract")
struct CoachChatWireContractTests {
    @Test func requestBoundsContextHistoryAndTotalMessageCharacters() throws {
        var messages: [CoachChatWireMessage] = []
        for index in 0..<14 {
            messages.append(CoachChatWireMessage(
                role: index.isMultiple(of: 2) ? .assistant : .user,
                content: String(repeating: "m", count: 5_000)
            ))
        }
        let request = CoachChatRequest(
            surface: "text",
            qualityTier: "fast",
            coachingContext: String(repeating: "c", count: 14_000),
            messages: messages
        )

        #expect(request.schemaVersion == 1)
        #expect(UUID(uuidString: request.requestID) != nil)
        #expect(request.coachingContext.count == CoachChatRequest.maxContextCharacters)
        #expect(request.messages.count <= 12)
        #expect(request.messages.allSatisfy {
            $0.content.count <= CoachChatRequest.maxMessageCharacters
        })
        #expect(request.messages.reduce(0) { $0 + $1.content.count }
            <= CoachChatRequest.totalMessageCharacterBudget)
        #expect(request.messages.last?.role == .user)
    }

    @Test func completionMetadataRoundTripsThroughTheWire() throws {
        let completion = CoachChatCompletion(
            requestID: UUID().uuidString,
            text: "Lead with the answer.",
            model: "gemini-2.5-flash",
            qualityTier: "fast",
            finishReason: "STOP",
            inputTokens: 120,
            outputTokens: 18
        )
        let data = try JSONEncoder().encode(completion)
        #expect(try JSONDecoder().decode(CoachChatCompletion.self, from: data) == completion)
    }

    @Test func providerTiersMapToFastAndUltraTransportModes() {
        #expect(CoachProviderTier.geminiFast.transportQualityTier == "fast")
        #expect(CoachProviderTier.claudeReasoning.transportQualityTier == "ultra")
    }

    @Test func providerTiersAcceptCanonicalAndLegacyTransportSpellings() {
        #expect(CoachProviderTier(transportQualityTier: "fast") == .geminiFast)
        #expect(CoachProviderTier(transportQualityTier: "geminiFast") == .geminiFast)
        #expect(CoachProviderTier(transportQualityTier: "ultra") == .claudeReasoning)
        #expect(CoachProviderTier(transportQualityTier: "claudeReasoning") == .claudeReasoning)
        #expect(CoachProviderTier(transportQualityTier: "unknown") == nil)

        #expect(CoachProviderTier.transportQualityTiersMatch("fast", "geminiFast"))
        #expect(CoachProviderTier.transportQualityTiersMatch("claudeReasoning", "ultra"))
        #expect(!CoachProviderTier.transportQualityTiersMatch("fast", "ultra"))
        #expect(!CoachProviderTier.transportQualityTiersMatch("fast", "unknown"))
    }

    @Test func serverResolvedTierWinsOverDeploymentModelNameHeuristics() {
        let ultraUsingFlashNamedSuccessor = CoachTurnProviderChoice(
            providerName: "Firebase / Vertex AI",
            model: "gemini-next-flash",
            resolvedTier: .claudeReasoning
        )

        #expect(CoachReplyPipeline.providerTierChosen(
            for: ultraUsingFlashNamedSuccessor,
            requestedTier: .geminiFast
        ) == .claudeReasoning)
    }

    @Test func liveDeepAssessmentEscalatesWhenRealtimeModeIsDisabled() {
        #expect(CoachPromptBundle.preferredProviderTier(
            for: .deepAssessment,
            surface: .live,
            realtimeCoachModeEnabled: false
        ) == .claudeReasoning)
    }

    @MainActor
    @Test func secureTransportCarriesFastAndUltraThroughLandedMetadata() async throws {
        for tier in [CoachProviderTier.geminiFast, .claudeReasoning] {
            let transport = CapturingCoachTransport()
            let service = AICoachChatService(secureTransport: transport)
            var landedChoice: CoachTurnProviderChoice?

            let outcome = await service.reply(
                history: [CoachMessage(role: .user, text: "What should I fix first?")],
                systemPrompt: "Coach the next observable move.",
                userContext: "RECENT: latest rep 7/10, 1 filler.",
                turnDepth: .quickMove,
                preferredTier: tier,
                onProviderChosen: { landedChoice = $0 }
            )

            let request = try #require(transport.capturedRequest())
            #expect(request.qualityTier == tier.transportQualityTier)
            guard case .reply = outcome else {
                Issue.record("A valid secure reply did not land")
                continue
            }
            #expect(landedChoice?.resolvedTier == tier)
            #expect(landedChoice?.model == transport.model(for: tier))
        }
    }

    @MainActor
    @Test func secureTransportRejectsMismatchedCompletionTier() async {
        let transport = CapturingCoachTransport(completionTierOverride: "ultra")
        let service = AICoachChatService(secureTransport: transport)
        var landedChoice: CoachTurnProviderChoice?

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "What should I fix first?")],
            systemPrompt: "Coach the next observable move.",
            userContext: "RECENT: latest rep 7/10, 1 filler.",
            turnDepth: .quickMove,
            preferredTier: .geminiFast,
            onProviderChosen: { landedChoice = $0 }
        )

        guard case .failure(.empty) = outcome else {
            Issue.record("A mismatched server tier was not rejected")
            return
        }
        #expect(transport.capturedRequest()?.qualityTier == "fast")
        #expect(landedChoice == nil)
    }

    @Test func injectedAvailabilityPreservesTypedFailureReason() async {
        let service = AICoachChatService(secureTransport: StubCoachTransport(
            availabilityState: .unavailable(.service),
            events: []
        ))
        #expect(await service.availability() == .unavailable(.service))
    }

    #if DEBUG
    @Test func directDebugTransportIsUnavailableWithoutAProvider() async {
        let transport = DirectProviderDebugTransport(
            isConfigured: { false },
            operation: { _ in throw CoachChatTransportError.serviceUnavailable }
        )
        #expect(await transport.availability() == .unavailable(.debugProviderMissing))
    }
    #endif
}

private struct StubCoachTransport: CoachChatTransport {
    let availabilityState: CoachChatTransportAvailability
    let events: [CoachChatEvent]

    func availability() async -> CoachChatTransportAvailability {
        availabilityState
    }

    func stream(_ request: CoachChatRequest) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            continuation.finish()
        }
    }
}

private final class CapturingCoachTransport: CoachChatTransport, @unchecked Sendable {
    private let lock = NSLock()
    private var request: CoachChatRequest?
    private let completionTierOverride: String?

    init(completionTierOverride: String? = nil) {
        self.completionTierOverride = completionTierOverride
    }

    func availability() async -> CoachChatTransportAvailability { .available }

    func stream(_ request: CoachChatRequest) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        lock.lock()
        self.request = request
        lock.unlock()
        let model = request.qualityTier == "ultra" ? "gemini-2.5-pro" : "gemini-2.5-flash"
        let completion = CoachChatCompletion(
            requestID: request.requestID,
            text: "Your last rep was 7/10 with 1 filler, so lead with the recommendation in sentence one and stop after one proof point. Run one 60-second rep with that shape.",
            model: model,
            qualityTier: completionTierOverride ?? request.qualityTier,
            finishReason: "STOP",
            inputTokens: 40,
            outputTokens: 12
        )
        return AsyncThrowingStream { continuation in
            continuation.yield(.completion(completion))
            continuation.finish()
        }
    }

    func capturedRequest() -> CoachChatRequest? {
        lock.lock()
        defer { lock.unlock() }
        return request
    }

    func model(for tier: CoachProviderTier) -> String {
        tier == .claudeReasoning ? "gemini-2.5-pro" : "gemini-2.5-flash"
    }
}

@Suite("Production copy contracts")
struct ProductionCopyContractTests {
    @MainActor
    @Test func infrastructureFailuresNeverSendUsersToSettings() {
        let failures: [ChatFailure] = [
            .noProvider, .unauthenticated, .rateLimited, .network,
            .empty, .contentRejected
        ]
        let copy = failures.map { AskNoumStore.noticeCopy(for: $0) }
        let banned = [
            "check ai setup", "configure ai", "api key", "provider",
            "open settings", "add a key"
        ]
        for line in copy {
            let lowered = line.lowercased()
            #expect(!banned.contains(where: lowered.contains))
        }
    }

    @Test func momentTitleAppearsOnceAndObjectiveStaysSeparate() {
        let title = HomeMomentCopy.title(momentTitle: "Stakeholder review", days: 7)
        #expect(title == "Stakeholder review · 7 days")
        #expect(title.components(separatedBy: "Stakeholder review").count - 1 == 1)
        #expect(!title.lowercased().contains("authority under pressure"))
    }

    @Test func evidenceLanguageStrengthensOnlyAtModerateConfidence() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let tentative = try #require(CoachCaseFile.evidenceDepthLine(
            evidenceCount: 3,
            confidence: .tentative,
            watchingSince: now.addingTimeInterval(-86_400),
            now: now
        ))
        let moderate = try #require(CoachCaseFile.evidenceDepthLine(
            evidenceCount: 5,
            confidence: .moderate,
            watchingSince: now.addingTimeInterval(-86_400),
            now: now
        ))
        #expect(tentative.hasPrefix("Early read"))
        #expect(tentative.contains("still forming"))
        #expect(moderate == "Seen across 5 recent reps.")
    }

    @Test func smallRatingMovementReadsAsHoldingSteady() {
        let snapshots = [2, -3, 4].map { delta in
            RatingSnapshot(
                rating: 500 + delta,
                delta: delta,
                sessionId: UUID(),
                pressureLevel: .standard
            )
        }
        let rating = SpeakingRating(
            overall: 503,
            peakRating: 510,
            ratingHistory: snapshots,
            personalBests: [],
            totalRatedSessions: 3,
            weekPeakRating: 510,
            weekPeakISOWeek: 1,
            weekPeakISOYear: 2026
        )
        #expect(rating.currentTrend == .stable)
        #expect(RatingTrendCopy.label(for: rating.currentTrend) == "Holding steady")
    }

    @MainActor
    @Test func coreProductionCopyAvoidsUrgencyAndCelebrationLanguage() {
        let lines = [
            HomeAskNoumEvidenceCopy.line(sessionCount: 0),
            HomeAskNoumEvidenceCopy.line(sessionCount: 2),
            RatingTrendCopy.label(for: .stable),
            AskNoumStore.noticeCopy(for: .network)
        ]
        let banned = ["great job", "amazing", "hurry", "last chance", "at risk"]
        for line in lines {
            let lowered = line.lowercased()
            #expect(!line.contains("!"))
            #expect(!banned.contains(where: lowered.contains))
        }
    }
}
