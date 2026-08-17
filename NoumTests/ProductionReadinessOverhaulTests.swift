import Foundation
import Testing
@testable import Noum
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

@Suite("Otherpath release identity contract")
struct OtherpathReleaseIdentityContractTests {
    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    @Test func sourceOwnedReleaseAndLaunchContractsUseTheMigratedIdentity() throws {
        let activeIdentityPaths = [
            "Noum.xcodeproj/project.pbxproj",
            "functions/src/appStoreServerNotifications.ts",
            "scripts/release_cloud_operations_validator.py",
            "scripts/release_testflight_preflight.py",
            "scripts/release-materialize-ci-config.sh",
            "scripts/run-noum-with-ai.sh",
            "scripts/tests/test_release_testflight_preflight.py",
            "maestro/chat_reject_smoke.yaml",
            "maestro/chat_smoke.yaml",
            "maestro/run_chat_demo_smoke.sh",
            ".agents/skills/noum-screenshots/SKILL.md",
            ".agents/skills/noum-screenshots/capture.sh",
            ".claude/skills/noum-screenshots/SKILL.md",
            ".claude/skills/noum-screenshots/capture.sh",
            "docs/MANUAL_LAUNCH_ACTIONS.md",
            "artifacts/interaction-polish/REVIEW.md",
            "Noum-Debug.entitlements",
            "Noum/SharedNoumState.swift",
            "NoumMessages/NoumMessages.swift",
            "NoumMessages/SharedNoumState.swift",
            "NoumWatch/SharedNoumState.swift",
            "NoumWidget/NoumWidget.swift",
            "NoumWidget/SharedNoumState.swift",
        ]
        let legacyIdentityFragments = [
            "com.jordancoaten.noum",
            "group.com.jordancoaten.noum",
            #"com\.jordancoaten\.noum"#,
            #"group\.com\.jordancoaten\.noum"#,
        ]

        for relativePath in activeIdentityPaths {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            for legacyIdentity in legacyIdentityFragments {
                #expect(!source.contains(legacyIdentity))
            }
        }

        let project = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum.xcodeproj/project.pbxproj"),
            encoding: .utf8
        )
        let requiredProjectContracts = [
            "PRODUCT_BUNDLE_IDENTIFIER = uk.co.otherpath.noum;",
            "PRODUCT_BUNDLE_IDENTIFIER = uk.co.otherpath.noum.NoumTests;",
            "PRODUCT_BUNDLE_IDENTIFIER = uk.co.otherpath.noum.NoumUITests;",
            "PRODUCT_BUNDLE_IDENTIFIER = uk.co.otherpath.noum.widget;",
            "PRODUCT_BUNDLE_IDENTIFIER = uk.co.otherpath.noum.NoumMessages;",
            "PRODUCT_BUNDLE_IDENTIFIER = uk.co.otherpath.noum.watchkitapp;",
            "INFOPLIST_KEY_WKCompanionAppBundleIdentifier = uk.co.otherpath.noum;",
        ]
        for contract in requiredProjectContracts {
            #expect(project.contains(contract))
        }

        let entitlementPaths = [
            "Noum.entitlements",
            "NoumMessages/NoumMessages.entitlements",
            "NoumWatch/NoumWatch.entitlements",
            "NoumWidget/NoumWidget.entitlements",
        ]
        for relativePath in entitlementPaths {
            let source = try String(
                contentsOf: repositoryRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            #expect(source.contains("group.uk.co.otherpath.noum"))
            for legacyIdentity in legacyIdentityFragments {
                #expect(!source.contains(legacyIdentity))
            }
        }
    }
}

@Suite("Production app shell routing")
struct ProductionAppShellRoutingTests {
    @Test func deepLinksSelectTheirOwningTab() throws {
        let expected: [(String, AppTab)] = [
            ("noum://home", .home),
            ("noum://ask/type", .home),
            ("noum://practice/timed", .train),
            ("noum://projects/ice_breaker", .train),
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

        let project = try #require(URL(string: "noum://projects/ice_breaker"))
        guard case .speechProject(let projectID)? = AppTab.rootDestination(for: project) else {
            Issue.record("Known Speech Project did not resolve through AppDestination")
            return
        }
        #expect(projectID == SpeechProjects.iceBreaker.id)
    }
}

@Suite("Speech Project practice contract")
struct SpeechProjectPracticeContractTests {
    @Test func everyProjectCarriesCuratedPromptsAndCanReachItsOwnTarget() {
        for project in SpeechProjects.all {
            #expect(!project.prompts.isEmpty)
            #expect(project.prompts.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })

            let timing = TimedPracticeTimingPolicy.project(project)
            #expect(timing.targetSeconds == Int(project.durationTarget))
            #expect(timing.greenStart == Int(project.durationMinimum))
            #expect(timing.automaticStopSeconds == nil)
            #expect(timing.state(for: timing.greenStart) == .green)
            #expect(timing.state(for: timing.redStart) == .red)

            let target = project.timedDurationTarget
            #expect(target.assessment(for: project.durationMinimum - 1) == .tooShort)
            #expect(target.assessment(for: project.durationMinimum) == .onTarget)
            #expect(target.assessment(for: project.durationTarget + 120) == .tooLong)
            #expect(target.progress(for: project.durationMinimum - 1) < target.progress(for: project.durationMinimum))
            #expect(target.progress(for: project.durationTarget) == 1)
            #expect(target.progress(for: project.durationTarget + 1) < target.progress(for: project.durationTarget))
        }
    }

    @Test func ordinaryTimedPolicyPreservesTheExistingThresholdsAndHardStop() {
        let policy = TimedPracticeTimingPolicy.standard
        #expect(policy.targetSeconds == 150)
        #expect(policy.automaticStopSeconds == 150)
        #expect(policy.state(for: 59) == .neutral)
        #expect(policy.state(for: 60) == .green)
        #expect(policy.state(for: 90) == .yellow)
        #expect(policy.state(for: 120) == .red)
        #expect(policy.state(for: 150) == .overtime)
    }

    @Test func preparedSpeechEvaluationUsesTheProjectDurationRange() {
        let project = SpeechProjects.iceBreaker
        let transcript = Array(repeating: "One clear idea with supporting detail.", count: 80)
            .joined(separator: " ")

        let belowMinimum = PracticeEvaluator.evaluateTimedPractice(
            transcript: transcript,
            fillerCount: 0,
            duration: project.durationMinimum - 1,
            difficulty: .easy,
            recentSessions: [],
            profile: nil,
            question: project.prompts[0],
            durationTarget: project.timedDurationTarget
        )
        #expect(belowMinimum.durationAssessment == .tooShort)

        let beyondTarget = PracticeEvaluator.evaluateTimedPractice(
            transcript: transcript,
            fillerCount: 0,
            duration: project.durationTarget + 90,
            difficulty: .easy,
            recentSessions: [],
            profile: nil,
            question: project.prompts[0],
            durationTarget: project.timedDurationTarget
        )
        #expect(beyondTarget.durationAssessment == .tooLong)
        #expect(beyondTarget.feedback.localizedCaseInsensitiveContains("went well past"))
        #expect(beyondTarget.targetRange.min == project.durationMinimum)
        #expect(beyondTarget.targetRange.target == project.durationTarget)
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
            "July 21, 2026",
            "Noum itself does not store your email address, phone number, or password in Noum profile or session records.",
            "Guest access first attempts anonymous Firebase Authentication during a bounded launch window.",
            "If that attempt cannot complete, Noum creates a Keychain-backed local-only guest so practice can continue on this device.",
            "Noum may automatically retry anonymous authentication and replace the local identifier with a newly created anonymous Firebase UID.",
            "The identity transfer is copy-first and keeps the original on-device namespace until the new identity is verified.",
            "Creating the Firebase identity does not by itself upload the local guest's coaching profile, transcripts, sessions, XP, or recommendation state.",
            "Noum sends the supported account-data subset to Firebase only after the current account has allowed cloud processing.",
            "If permission is declined, missing, or stale, that content remains on the device.",
            "Google's bundled sign-in SDK declares that it may process linked name, email address, phone number, coarse location, user ID, device ID, other usage data, and other data types.",
            "Its manifest lists name, email address, phone number, and coarse location for app functionality; user ID and other data types for app functionality and analytics; and device ID and other usage data for analytics.",
            "It declares no tracking",
            "The Firebase Authentication SDK manifest declares linked user ID for app functionality; Firebase Authentication, Firestore, Remote Config, and Firebase Installations SDK manifests declare unlinked other diagnostic data for analytics purposes.",
            "Firebase Remote Config can deliver an exact, versioned first-run experience token to an eligible new account.",
            "Missing, empty, unknown, or not-yet-active configuration does not assign an experiment, and developer, automated-test, returning, and already-started accounts are excluded from new assignment.",
            "In production, Ask Noum sends your current message, bounded recent conversation turns, and bounded coaching context and session evidence through a Firebase Functions endpoint.",
            "The function then sends the bounded request to Google Vertex AI (Gemini).",
            "Firebase Authentication and Firebase App Check tokens accompany that request to authenticate the caller, verify the app request, and protect the service from abuse.",
            "production Ask Noum messages, bounded recent turns, and bounded coaching context/session evidence sent through Firebase Functions; Firebase Authentication and App Check tokens or attestation data used to secure that transport.",
            "Delete your Firebase Authentication account, if one exists",
            "Noum does not include a dedicated Firebase Analytics SDK, advertising SDK, or cross-app tracking SDK.",
            "Required Google Sign-In, Firebase Authentication, Firestore, Remote Config, and Firebase Installations SDKs carry vendor-declared analytics-purpose processing as described above.",
            "Noum does not use that processing for advertising or cross-app tracking.",
            "Noum does not share data with advertising networks or data brokers.",
            "A minimal deletion-security record contains only the account identifier, opaque request identifier, deletion status, and timestamps; it contains no audio, transcript, session, or coaching content.",
            "A completed deletion-security record is scheduled for automatic cleanup after two hours; that cleanup depends on the Firestore TTL policy being deployed and working.",
            "If finalization or earlier cleanup is interrupted, the pending write fence remains; the scheduled server reconciler retries the full deletion work for the exact request and only then converts it to a fresh completed record.",
            "If TTL is unavailable, the completed record remains until authorized cleanup.",
        ]

        for policyFile in policyFiles {
            let policy = try String(contentsOf: policyFile, encoding: .utf8)
            for disclosure in requiredDisclosures {
                #expect(policy.contains(disclosure))
            }
            #expect(!policy.contains("No data is shared with analytics providers"))
            #expect(!policy.contains(
                "This fallback applies to account sign-in and persistence only"
            ))
        }
    }

    @Test func legacyPrivacyDocumentsCannotMasqueradeAsCurrentOperations() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let auditURL = repositoryRoot.appendingPathComponent("Noum/PRIVACY_AUDIT.md")
        let audit = try String(contentsOf: auditURL, encoding: .utf8)

        #expect(audit.contains("Historical Noum Privacy & Data Audit — Superseded"))
        #expect(audit.contains("Historical snapshot only. Do not use this file as the current operational"))
        #expect(audit.contains("[PrivacyPolicy.md](PrivacyPolicy.md)"))
        #expect(audit.contains("[processor manifest](../privacy/processors.json)"))
        #expect(audit.contains("[production-readiness runbook](../docs/PRODUCTION_READINESS_RUNBOOK.md)"))
        #expect(audit.contains("explicit cloud consent"))
        #expect(audit.contains("short-lived authenticated"))
        #expect(audit.contains("Apple's on-device Speech fallback"))
        #expect(!audit.contains("Status:** Operational reference"))

        let historicalCompanions = [
            (
                "Noum/PRIVACY_REMEDIATION.md",
                "Historical Noum Privacy Remediation Plan — Superseded",
                "Do not execute this plan against the current"
            ),
            (
                "Noum/PRIVACY_EXECUTION.md",
                "Historical Noum Privacy Execution Package — Superseded",
                "Do not execute these tickets against the current"
            ),
        ]
        for (relativePath, title, warning) in historicalCompanions {
            let document = try String(
                contentsOf: repositoryRoot.appendingPathComponent(relativePath),
                encoding: .utf8
            )
            #expect(document.contains(title))
            #expect(document.contains(warning))
            #expect(document.contains("[PrivacyPolicy.md](PrivacyPolicy.md)"))
            #expect(document.contains("[processor manifest](../privacy/processors.json)"))
            #expect(document.contains("[production-readiness runbook](../docs/PRODUCTION_READINESS_RUNBOOK.md)"))
        }
    }

    @Test func unscopedTimedSeedKeysHaveOnePurgeOnlyOwner() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceRoot = repositoryRoot.appendingPathComponent("Noum")
        let keys = [
            TimedPracticePromptHandoff.legacyDefaultsKey,
            TimedPracticePromptHandoff.legacySuggestedWordDefaultsKey,
        ]
        let enumerator = try #require(
            FileManager.default.enumerator(
                at: sourceRoot,
                includingPropertiesForKeys: nil
            )
        )
        var owners: Set<String> = []
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "swift" {
            let source = try String(contentsOf: fileURL, encoding: .utf8)
            if keys.contains(where: source.contains) {
                owners.insert(fileURL.lastPathComponent)
            }
        }

        #expect(owners == Set(["TimedPracticePromptHandoff.swift"]))
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
    @Test func automationUsesADurableKeychainNamespaceSeparateFromProduction() {
        #expect(KeychainHelper.storageService(arguments: ["Noum"]) == "Noum")
        #expect(KeychainHelper.storageService(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE"]
        ) == "Noum.UITesting")
        #expect(KeychainHelper.storageService(
            arguments: [
                "Noum",
                "UI_TESTING",
                "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
            ]
        ) == "Noum.UITesting")
    }

    @Test func safetyJournalsUseTheSameIsolatedKeychainService() {
        let seeded = ["Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE"]
        let restore = [
            "Noum",
            "UI_TESTING",
            "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
        ]
        for arguments in [seeded, restore] {
            let expected = KeychainHelper.storageService(arguments: arguments)
            #expect(KeychainAccountDeletionFenceStorage.storageService(
                arguments: arguments
            ) == expected)
            #expect(KeychainLocalGuestPromotionJournalStorage.storageService(
                arguments: arguments
            ) == expected)
        }
        #expect(KeychainAccountDeletionFenceStorage.storageService(
            arguments: ["Noum"]
        ) == "Noum")
        #expect(KeychainLocalGuestPromotionJournalStorage.storageService(
            arguments: ["Noum"]
        ) == "Noum")
    }

    @Test func testBootstrapNeverConsumesTheProductionInstallCleanup() {
        #expect(!AuthManager.shouldInitializeProductionInstallState(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE"]
        ))
        #expect(!AuthManager.shouldInitializeProductionInstallState(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_REAL_FIRST_RUN"]
        ))
        #expect(AuthManager.shouldInitializeProductionInstallState(
            arguments: ["Noum"]
        ))
    }

    @Test func automationForbidsFirebaseSDKSessionAccess() {
        #expect(!AuthManager.shouldRestoreFirebaseSDKSession(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE"]
        ))
        #expect(!AuthManager.shouldRestoreFirebaseSDKSession(
            arguments: [
                "Noum",
                "UI_TESTING",
                "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
            ]
        ))
        #expect(!AuthManager.shouldRestoreFirebaseSDKSession(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_REAL_FIRST_RUN"]
        ))
        #expect(AuthManager.shouldRestoreFirebaseSDKSession(
            arguments: ["Noum"]
        ))
        #expect(!AuthManager.firebaseSDKSessionAccessAllowed(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_SIGNED_OUT"]
        ))
        #expect(AuthManager.firebaseSDKSessionAccessAllowed(
            arguments: ["Noum"]
        ))
    }

    @Test func renderedFixturePreparationRoundTripsTheIsolatedSecurityService() {
        let resetArguments = [
            "Noum",
            "UI_TESTING",
            "UI_TESTING_SIGNED_OUT",
        ]
        let seededArguments = [
            "Noum",
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
        ]
        defer {
            _ = KeychainHelper.prepareUIAutomationStorage(
                arguments: resetArguments
            )
        }

        #expect(KeychainHelper.prepareUIAutomationStorage(
            arguments: resetArguments
        ))
        #expect(!KeychainHelper.hasPreparedUIAutomationIdentity(
            arguments: seededArguments
        ))
        #expect(KeychainHelper.prepareUIAutomationStorage(
            arguments: seededArguments
        ))
        #expect(KeychainHelper.hasPreparedUIAutomationIdentity(
            arguments: seededArguments
        ))
    }

    @Test func criticalFirebaseSDKEntryPointsFailClosedBeforeGlobalSessionAccess() throws {
        let source = try authManagerSource()

        let initializer = try sourceSlice(
            in: source,
            from: "    private init() {",
            to: "    #if DEBUG\n    /// Seeded UI tests skip credential hydration"
        )
        let initPolicy = try #require(initializer.range(
            of: "guard allowsFirebaseSDKSessionAccess else"
        ))
        let initRestore = try #require(initializer.range(
            of: "restoreFirebaseSessionIfAvailable()"
        ))
        #expect(initPolicy.lowerBound < initRestore.lowerBound)

        let bootstrapCaller = try sourceSlice(
            in: source,
            from: "    func bootstrapInitialAccountIfNeeded() async {",
            to: "    /// Returns true when the provider either established"
        )
        #expect(bootstrapCaller.contains(
            "remoteGuestBootstrapOwnsOutcomeIfAllowed()"
        ))
        #expect(!bootstrapCaller.contains("Auth.auth()"))
        #expect(!bootstrapCaller.contains("GIDSignIn.sharedInstance"))

        let bootstrapLeaf = try sourceSlice(
            in: source,
            from: "    private func remoteGuestBootstrapOwnsOutcomeIfAllowed() async -> Bool {",
            to: "    func retryInitialAccountBootstrap() async {"
        )
        try expectNoGlobalSessionAccess(
            before: "guard allowsFirebaseSDKSessionAccess else",
            in: bootstrapLeaf
        )

        let signOutCaller = try sourceSlice(
            in: source,
            from: "    private func performSignOut(allowAnonymousGuest: Bool) {",
            to: "    private func signOutProviderSessionsIfAllowed() {"
        )
        #expect(signOutCaller.contains("signOutProviderSessionsIfAllowed()"))
        #expect(!signOutCaller.contains("Auth.auth()"))
        #expect(!signOutCaller.contains("GIDSignIn.sharedInstance"))

        let tokenFunctionStart = try #require(source.range(
            of: "    private static func currentFirebaseIDToken() async -> String? {"
        ))
        let guardedSlices: [(String, String)] = [
            (
                try sourceSlice(
                    in: source,
                    from: "    func connectLocalGuestToCloud(force: Bool = false) async {",
                    to: "    /// Establishes the initial durable guest identity"
                ),
                "guard allowsFirebaseSDKSessionAccess else"
            ),
            (
                try sourceSlice(
                    in: source,
                    from: "    private func signOutAttemptedFirebaseIdentity(accountID: String) {",
                    to: "    private func presentUnreadablePendingDeletion()"
                ),
                "guard allowsFirebaseSDKSessionAccess,"
            ),
            (
                try sourceSlice(
                    in: source,
                    from: "    private func signInWithGoogle(presenting controller: UIViewController) {",
                    to: "#else\n#if canImport(GoogleSignIn)"
                ),
                "guard allowsFirebaseSDKSessionAccess else"
            ),
            (
                try sourceSlice(
                    in: source,
                    from: "    private func authenticateWithFirebase(",
                    to: "    private func signInWithFirebase("
                ),
                "guard allowsFirebaseSDKSessionAccess else"
            ),
            (
                try sourceSlice(
                    in: source,
                    from: "    private func signOutProviderSessionsIfAllowed() {",
                    to: "#if DEBUG\n    /// Activates the AuthManager state"
                ),
                "guard allowsFirebaseSDKSessionAccess else"
            ),
            (
                try sourceSlice(
                    in: source,
                    from: "    private func deleteFirebaseUserIfNeeded(expectedAccountID: String) async throws {",
                    to: "    var accountDeletionSupportURL: URL {"
                ),
                "guard allowsFirebaseSDKSessionAccess else"
            ),
            (
                try sourceSlice(
                    in: source,
                    from: "    private func beginLocalGuestPromotionFinalizationIfReady(",
                    to: "    /// Called by the existing account-scoped consent owner"
                ),
                "guard allowsFirebaseSDKSessionAccess else"
            ),
            (
                try sourceSlice(
                    in: source,
                    from: "    static func identityBound(",
                    to: "    /// Builds deletion headers"
                ),
                "guard AuthManager.firebaseSDKSessionAccessAllowed("
            ),
            (
                try sourceSlice(
                    in: source,
                    from: "    static func deletionBound(",
                    to: "    nonisolated static func deletionIdentityMatches("
                ),
                "guard AuthManager.firebaseSDKSessionAccessAllowed("
            ),
            (
                String(source[tokenFunctionStart.lowerBound...]),
                "guard AuthManager.firebaseSDKSessionAccessAllowed("
            ),
        ]
        for (slice, guardNeedle) in guardedSlices {
            try expectNoGlobalSessionAccess(
                before: guardNeedle,
                in: slice
            )
        }

        let apple = try sourceSlice(
            in: source,
            from: "    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {",
            to: "    private func signIn() {"
        )
        let appleGuard = try #require(apple.range(
            of: "guard allowsFirebaseSDKSessionAccess else"
        ))
        let appleAuthentication = try #require(apple.range(
            of: "authenticateWithFirebase("
        ))
        #expect(appleGuard.lowerBound < appleAuthentication.lowerBound)
    }

    @Test func deepgramCallableFailsClosedBeforeGlobalFirebaseAccess() throws {
        let source = try repositorySource(at: "DeepgramProvider.swift")
        let callableLeaf = try sourceSlice(
            in: source,
            from: "    private func fetchCallableToken() async throws -> DeepgramAccessToken {",
            to: "private struct TranscriptionTokenRequest"
        )
        let guardNeedle =
            "guard AuthManager.firebaseSDKSessionAccessAllowed("
        let guardRange = try #require(callableLeaf.range(of: guardNeedle))
        let prefix = callableLeaf[..<guardRange.lowerBound]
        #expect(!prefix.contains("Auth.auth()"))
        #expect(!prefix.contains("Functions.functions("))

        let guardedLeaf = callableLeaf[guardRange.upperBound...]
        #expect(guardedLeaf.contains("Auth.auth()"))
        #expect(guardedLeaf.contains("Functions.functions("))
    }

    @Test func renderedFixturesResolveOneIdentityBeforeSingletonInitialization() {
        #expect(KeychainHelper.uiAutomationIdentity(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE"]
        ) == KeychainHelper.UIAutomationIdentity(
            accountID: "local-guest-ui-test-seeded-account",
            providerRawValue: "guest"
        ))

        let coachArguments = [
            "Noum",
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_AUTHENTICATED_COACH",
        ]
        #expect(KeychainHelper.uiAutomationIdentity(
            arguments: coachArguments
        ) == KeychainHelper.UIAutomationIdentity(
            accountID: "ui-test-coach-account",
            providerRawValue: "guest"
        ))
    }

    @Test func persistedFirstRunIdentityIsOnlyReadByExplicitRestoreJourneys() {
        #expect(KeychainHelper.uiAutomationIdentity(
            arguments: ["Noum", "UI_TESTING"]
        ) == nil)
        #expect(KeychainHelper.uiAutomationIdentity(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_SIGNED_OUT"]
        ) == nil)
        #expect(KeychainHelper.uiAutomationIdentity(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_REAL_FIRST_RUN"]
        ) == nil)
        #expect(KeychainHelper.uiAutomationIdentity(
            arguments: [
                "Noum",
                "UI_TESTING",
                "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
            ]
        ) == nil)
        #expect(KeychainHelper.shouldResetUIAutomationStorage(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_REAL_FIRST_RUN"]
        ))
        #expect(!KeychainHelper.shouldResetUIAutomationStorage(
            arguments: [
                "Noum",
                "UI_TESTING",
                "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
            ]
        ))
    }

    @Test func automationDoesNotRaceSeededStoresWithCredentialRestore() {
        #expect(!AuthManager.shouldRestorePersistedSession(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE"]
        ))
        #expect(AuthManager.shouldRestorePersistedSession(
            arguments: [
                "Noum",
                "UI_TESTING",
                "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
            ]
        ))
        #expect(AuthManager.shouldRestorePersistedSession(
            arguments: ["Noum"]
        ))
    }

    @Test func signedOutModeOverridesPersistedRestoreAcrossEveryOwner() throws {
        let arguments = [
            "Noum",
            "UI_TESTING",
            "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
            "UI_TESTING_SIGNED_OUT",
            // Conflicting fixture flags must not weaken the signed-out fence.
            "UI_TESTING_REAL_FIRST_RUN",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_AUTHENTICATED_COACH",
        ]

        #expect(KeychainHelper.uiAutomationLaunchMode(
            arguments: arguments
        ) == .signedOut)
        #expect(KeychainHelper.shouldResetUIAutomationStorage(
            arguments: arguments
        ))
        #expect(KeychainHelper.uiAutomationIdentity(
            arguments: arguments
        ) == nil)
        #expect(!AuthManager.shouldRestorePersistedSession(
            arguments: arguments
        ))
        #expect(!AuthManager.shouldUseProcessLocalSeededAccount(
            arguments: arguments
        ))
        #expect(!AuthManager.shouldUseCleanLocalGuestForFirstRunUITesting(
            arguments: arguments
        ))
        #expect(DevSeedData.requestedProfileForUITesting(
            arguments: arguments
        ) == nil)

        // Render owners must consume the resolved precedence contract instead
        // of independently treating any accumulated raw flag as authoritative.
        for relativePath in [
            "Noum/NoumApp.swift",
            "Noum/CoachingOnboardingView.swift",
        ] {
            let source = try repositorySource(at: relativePath)
            #expect(source.contains(
                "KeychainHelper.uiAutomationLaunchMode("
            ))
            #expect(!source.contains(
                "contains(\"UI_TESTING_REAL_FIRST_RUN\")"
            ))
        }
    }

    @Test func preRenderAndPostHydrationSeedingResolveTheSamePersona() {
        #expect(DevSeedData.requestedProfileForUITesting(
            arguments: ["Noum", "UI_TESTING"]
        ) == nil)
        #expect(DevSeedData.requestedProfileForUITesting(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE"]
        ) == .improvingIntermediate)
        #expect(DevSeedData.requestedProfileForUITesting(
            arguments: [
                "Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE",
                "UI_TESTING_SEED_PROFILE", "plateauedAdvanced"
            ]
        ) == .plateauedAdvanced)
        for exclusiveMode in [
            "UI_TESTING_REAL_FIRST_RUN",
            "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
            "UI_TESTING_SIGNED_OUT",
        ] {
            #expect(DevSeedData.requestedProfileForUITesting(
                arguments: [
                    "Noum",
                    "UI_TESTING",
                    "UI_TESTING_SEED_FORCE",
                    exclusiveMode,
                ]
            ) == nil)
        }
    }

    @Test func firstWeekReadSeedRequiresTheExactSeededJourney() {
        let exact = [
            "Noum",
            "UI_TESTING",
            "UI_TESTING_SEED_FORCE",
            "UI_TESTING_FIRST_WEEK_READ",
        ]
        #expect(DevSeedData.requestsFirstWeekReadForUITesting(arguments: exact))
        #expect(!DevSeedData.requestsFirstWeekReadForUITesting(
            arguments: Array(exact.dropLast())
        ))
        #expect(!DevSeedData.requestsFirstWeekReadForUITesting(
            arguments: exact + ["UI_TESTING_SIGNED_OUT"]
        ))
        #expect(!DevSeedData.requestsFirstWeekReadForUITesting(
            arguments: ["Noum", "UI_TESTING_FIRST_WEEK_READ"]
        ))
    }

    @Test func firstWeekReadSeedUsesOnlyContractBoundedQualifiedSessions() throws {
        let calendar = Calendar(identifier: .gregorian)
        let sessions = DevSeedData.sessions(for: .improvingIntermediate)
        let now = try #require(sessions.map(\.date).max()).addingTimeInterval(86_400)
        let seededSessions = DevSeedData.firstWeekEvidenceSessionsForUITesting(
            sessions: sessions,
            now: now,
            calendar: calendar
        )
        #expect(seededSessions.count >= 3)
        #expect(seededSessions.count < sessions.count)
        let snapshot = try #require(
            DevSeedData.firstWeekReadFixtureSnapshotForUITesting(
                accountID: "first-week-ui-test-account",
                profile: .improvingIntermediate,
                sessions: seededSessions,
                now: now,
                calendar: calendar
            )
        )
        #expect(snapshot.nextAction == .reviewFirstWeekRead)
        let read = try #require(snapshot.firstWeekRead)
        let eligible = PracticeProgressEligibility
            .eligibleSessions(in: sessions)
            .sorted { $0.date < $1.date }
        let earliest = try #require(eligible.first)
        let end = try #require(calendar.date(
            byAdding: .day,
            value: FirstWeekCoachingContract.finalDay + 1,
            to: calendar.startOfDay(for: earliest.date)
        ))
        let boundedIDs = Set(eligible.filter { $0.date < end }.map(\.id))
        let laterIDs = Set(eligible.filter { $0.date >= end }.map(\.id))

        switch read.whatChanged {
        case .verifiedComparison(let trend):
            let referencedIDs = Set(trend.comparableSessionIDs + [trend.sourceSessionID])
            #expect(!referencedIDs.isEmpty)
            #expect(referencedIDs.isSubset(of: boundedIDs))
            #expect(referencedIDs.isDisjoint(with: laterIDs))
        case .notYetProven:
            Issue.record("The fixture must earn its read through a qualified bounded comparison.")
        }
    }

    @Test func renderedJourneySelectorsAndCoachReadLayoutStayPinned() throws {
        let goalLoop = try repositorySource(at: "NoumUITests/GoalOutcomeLoopUITests.swift")
        let journeyAudit = try repositorySource(at: "NoumUITests/JourneyAccessibilityAuditUITests.swift")
        let screenshotTour = try repositorySource(at: "NoumUITests/ScreenshotTour.swift")
        let profile = try repositorySource(at: "ProfileView.swift")
        let coachReadHeader = try sourceSlice(
            in: profile,
            from: "    private func profileCoachReadHeader(",
            to: "    private func profileTransferStatusRow"
        )

        #expect(goalLoop.contains("app.buttons[\"transcriptRetry.milestone\"]"))
        #expect(screenshotTour.contains("app.buttons[\"transcriptRetry.milestone\"]"))
        #expect(!goalLoop.contains("app.buttons[\"transcriptRetry.continueToEvidence\"]"))
        #expect(!screenshotTour.contains("app.buttons[\"transcriptRetry.continueToEvidence\"]"))
        #expect(goalLoop.contains("isHittableAboveFloatingDock"))
        #expect(goalLoop.contains("app.v46TabBar"))
        #expect(journeyAudit.contains("Start with what you're working on."))
        #expect(screenshotTour.contains("UI_TESTING_FIRST_WEEK_READ"))
        #expect(coachReadHeader.contains("if dynamicTypeSize.isAccessibilitySize"))
        #expect(coachReadHeader.contains(".frame(maxWidth: .infinity, alignment: .leading)"))
        #expect(coachReadHeader.contains(".padding(.vertical, 1)"))
        #expect(coachReadHeader.contains(".lineLimit(nil)"))
        #expect(coachReadHeader.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(coachReadHeader.contains(".foregroundStyle(readTint)"))
    }

    @Test func seededJourneysUseAnIsolatedAccountScopeOnlyWhenAppropriate() {
        #expect(AuthManager.shouldUseProcessLocalSeededAccount(
            arguments: ["Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE"]
        ))
        #expect(!AuthManager.shouldUseProcessLocalSeededAccount(
            arguments: ["Noum", "UI_TESTING"]
        ))
        #expect(!AuthManager.shouldUseProcessLocalSeededAccount(
            arguments: [
                "Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE",
                "UI_TESTING_REAL_FIRST_RUN",
            ]
        ))
        #expect(!AuthManager.shouldUseProcessLocalSeededAccount(
            arguments: [
                "Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE",
                "UI_TESTING_RESTORE_PERSISTED_ACCOUNT",
            ]
        ))
        #expect(!AuthManager.shouldUseProcessLocalSeededAccount(
            arguments: [
                "Noum", "UI_TESTING", "UI_TESTING_SEED_FORCE",
                "UI_TESTING_SIGNED_OUT",
            ]
        ))
    }

    private func authManagerSource() throws -> String {
        try repositorySource(at: "Noum/AuthManager.swift")
    }

    private func repositorySource(at relativePath: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(relativePath),
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

    private func expectNoGlobalSessionAccess(
        before guardNeedle: String,
        in source: String
    ) throws {
        let guardRange = try #require(source.range(of: guardNeedle))
        let prefix = source[..<guardRange.lowerBound]
        #expect(!prefix.contains("Auth.auth()"))
        #expect(!prefix.contains("GIDSignIn.sharedInstance"))
        let suffix = source[guardRange.upperBound...]
        #expect(
            suffix.contains("Auth.auth()")
                || suffix.contains("GIDSignIn.sharedInstance")
        )
    }
}
#endif

@Suite("Coach chat wire contract")
struct CoachChatWireContractTests {
    @Test func strictClientUsesAdditiveV2Callable() {
        #expect(FirebaseCoachChatTransport.region == "europe-west2")
        #expect(FirebaseCoachChatTransport.functionName == "coachChatV2")
    }

    @Test func composerAdmissionUsesLocalSecureSessionNotAFalseHealthProbe() {
        #expect(FirebaseCoachChatTransport.localAvailability(
            firebaseConfigured: true,
            firebaseUID: "firebase-guest",
            durableAccountID: "firebase-guest",
            accountIsHydrated: true,
            providerWorkAllowed: true
        ) == .available)
        #expect(FirebaseCoachChatTransport.localAvailability(
            firebaseConfigured: false,
            firebaseUID: "firebase-guest",
            durableAccountID: "firebase-guest",
            accountIsHydrated: true,
            providerWorkAllowed: true
        ) == .unavailable(.service))
        #expect(FirebaseCoachChatTransport.localAvailability(
            firebaseConfigured: true,
            firebaseUID: nil,
            durableAccountID: "firebase-guest",
            accountIsHydrated: true,
            providerWorkAllowed: true
        ) == .unavailable(.secureSessionMissing))
        #expect(FirebaseCoachChatTransport.localAvailability(
            firebaseConfigured: true,
            firebaseUID: "firebase-b",
            durableAccountID: "firebase-a",
            accountIsHydrated: true,
            providerWorkAllowed: true
        ) == .unavailable(.secureSessionMissing))
        #expect(FirebaseCoachChatTransport.localAvailability(
            firebaseConfigured: true,
            firebaseUID: "local-guest-a",
            durableAccountID: "local-guest-a",
            accountIsHydrated: true,
            providerWorkAllowed: true
        ) == .unavailable(.localOnlyGuest))
        #expect(FirebaseCoachChatTransport.localAvailability(
            firebaseConfigured: true,
            firebaseUID: "firebase-guest",
            durableAccountID: nil,
            accountIsHydrated: true,
            providerWorkAllowed: true
        ) == .unavailable(.authenticationPending))
        #expect(FirebaseCoachChatTransport.localAvailability(
            firebaseConfigured: true,
            firebaseUID: "firebase-guest",
            durableAccountID: "firebase-guest",
            accountIsHydrated: false,
            providerWorkAllowed: true
        ) == .unavailable(.authenticationPending))
        #expect(FirebaseCoachChatTransport.localAvailability(
            firebaseConfigured: true,
            firebaseUID: "firebase-guest",
            durableAccountID: "firebase-guest",
            accountIsHydrated: true,
            providerWorkAllowed: false
        ) == .unavailable(.authenticationPending))
        #expect(FirebaseCoachChatTransport.requestIdentityMatches(
            requestAccountID: "firebase-a",
            firebaseUID: "firebase-a",
            durableAccountID: "firebase-a"
        ))
        #expect(!FirebaseCoachChatTransport.requestIdentityMatches(
            requestAccountID: "firebase-a",
            firebaseUID: "firebase-b",
            durableAccountID: "firebase-b"
        ))
    }

    @Test func localGuestHasTruthfulConnectionAction() {
        let localGuest = AskNoumAvailabilityPresentation.resolve(.localOnlyGuest)
        #expect(localGuest.message == "Connect this guest once to use live coaching. Your practice stays on this device if the connection fails.")
        #expect(!localGuest.showsCheckAgain)
        #expect(localGuest.connectsLocalGuest)

        let missingSession = AskNoumAvailabilityPresentation.resolve(.secureSessionMissing)
        #expect(missingSession.message == "Your coaching history is loaded, but Ask Noum needs its secure session reconnected. Your practice is unchanged.")
        #expect(missingSession.showsCheckAgain)
        #expect(!missingSession.connectsLocalGuest)

        #expect(AskNoumAvailabilityPresentation.resolve(
            .authenticationPending
        ).showsCheckAgain)
        #expect(AskNoumAvailabilityPresentation.resolve(.service).showsCheckAgain)
    }

    @Test func coachCapabilityMustAdvertiseTheExactV2Contract() {
        #expect(FirebaseCoachChatTransport.capabilityAvailability(
            available: true,
            functionName: "coachChatV2",
            requestSchemaVersion: 2,
            policyVersion: "noum-coach-v2"
        ) == .available)
        #expect(FirebaseCoachChatTransport.capabilityAvailability(
            available: true,
            functionName: nil,
            requestSchemaVersion: nil,
            policyVersion: nil
        ) == .unavailable(.backendVersionMissing))
        #expect(FirebaseCoachChatTransport.capabilityAvailability(
            available: true,
            functionName: "coachChat",
            requestSchemaVersion: 1,
            policyVersion: nil
        ) == .unavailable(.backendVersionMissing))
        #expect(FirebaseCoachChatTransport.capabilityAvailability(
            available: false,
            functionName: "coachChatV2",
            requestSchemaVersion: 2,
            policyVersion: "noum-coach-v2"
        ) == .unavailable(.service))
    }

    @MainActor
    @Test func missingV2BackendUsesSpecificRecoverableCopy() {
        let presentation = AskNoumAvailabilityPresentation.resolve(
            .backendVersionMissing
        )
        #expect(presentation.message ==
            "This build’s Ask Noum service isn’t live yet. Updating the app won’t fix it.")
        #expect(presentation.showsCheckAgain)
        #expect(!presentation.connectsLocalGuest)
        let retainedDraftCopy = "This build’s Ask Noum service isn’t live yet. Updating the app won’t fix it. Your message is still here."
        #expect(AskNoumStore.noticeCopy(for: .backendVersionMissing) ==
            retainedDraftCopy)
        #expect(AskNoumStore.noticeCopy(for: .coachUnavailable(
            .backendVersionMissing
        )) == retainedDraftCopy)
    }

    @Test func personalProviderContextDoesNotRepeatTheCaseFile() {
        let context = CoachContextBuilder.personalTurnContext(
            profile: nil,
            coachingExpertise: [],
            hasCoachingBrief: true
        )
        #expect(context.contains("complete personal evidence allowance"))
        #expect(context.contains("State its useful decision once"))
        #expect(!context.contains("CASE FORMULATION"))
        #expect(!context.contains("ACTIVE PRESCRIPTION"))
        #expect(!context.contains("FORWARD PLAN"))
        #expect(!context.contains("COACH JUDGEMENT PASS"))
    }

    @Test func settingsDoesNotPresentLocalGuestAsRecoverableCloudAccount() {
        let localGuest = SettingsAccountPresentation.resolve(
            accountID: "local-guest-a",
            displayName: "Your profile",
            providerTitle: "Guest",
            providerRawValue: AuthProvider.guest.rawValue
        )
        #expect(localGuest.identityTitle == "Account")
        #expect(localGuest.identityValue == "On-device guest")
        #expect(localGuest.providerTitle == nil)
        #expect(localGuest.isOnDeviceGuest)
        #expect(!localGuest.showsSignOut)
        #expect(localGuest.showsConnectCoaching)
        #expect(localGuest.deletionAccessibilityHint.contains("local practice data"))

        let firebaseGuest = SettingsAccountPresentation.resolve(
            accountID: "firebase-guest",
            displayName: "Your profile",
            providerTitle: "Guest",
            providerRawValue: AuthProvider.guest.rawValue
        )
        #expect(firebaseGuest.identityTitle == "Signed in as")
        #expect(firebaseGuest.identityValue == "Your profile")
        #expect(firebaseGuest.providerTitle == "Guest")
        #expect(!firebaseGuest.isOnDeviceGuest)
        #expect(!firebaseGuest.showsSignOut)
        #expect(!firebaseGuest.showsConnectCoaching)
        #expect(firebaseGuest.deletionAccessibilityHint.contains("remote account service"))

        let linkedAccount = SettingsAccountPresentation.resolve(
            accountID: "firebase-apple",
            displayName: "Jordan",
            providerTitle: "Apple",
            providerRawValue: AuthProvider.apple.rawValue
        )
        #expect(linkedAccount.showsSignOut)
    }

    @Test func requestBoundsContextHistoryAndTotalMessageCharacters() throws {
        var messages: [CoachChatWireMessage] = []
        for index in 0..<14 {
            messages.append(CoachChatWireMessage(
                role: index.isMultiple(of: 2) ? .assistant : .user,
                content: String(repeating: "m", count: 5_000)
            ))
        }
        let request = CoachChatRequest(
            accountID: "firebase-guest",
            surface: "text",
            qualityTier: "fast",
            coachingContext: String(repeating: "c", count: 14_000),
            messages: messages
        )

        #expect(request.schemaVersion == 2)
        #expect(request.accountID == "firebase-guest")
        #expect(UUID(uuidString: request.requestID) != nil)
        #expect(request.coachVoice == nil)
        #expect(request.turnDepth == CoachTurnDepth.groundedRead.rawValue)
        #expect(request.turnIntent == CoachChatTurnIntent.unknown.rawValue)
        #expect(request.responseKind == CoachChatResponseKind.generalCoaching.rawValue)
        #expect(request.verifiedQuoteSources.isEmpty)
        #expect(request.coachingContext.count == CoachChatRequest.maxContextCharacters)
        #expect(request.messages.count <= 12)
        #expect(request.messages.allSatisfy {
            $0.content.count <= CoachChatRequest.maxMessageCharacters
        })
        #expect(request.messages.reduce(0) { $0 + $1.content.count }
            <= CoachChatRequest.totalMessageCharacterBudget)
        #expect(request.messages.last?.role == .user)
    }

    @Test func coachingBriefIsBoundedInsideTheSharedRequestEnvelope() {
        let long = String(repeating: "e", count: 1_000)
        let brief = CoachChatBrief(assessment: CoachAssessment(
            turnDepth: .deepAssessment,
            surface: .text,
            questionRestatement: "How am I doing?",
            directVerdict: long,
            confidence: 0.61,
            evidenceUsed: ["latest rep: \(long)"],
            rubricScores: [RubricScore(
                dimensionID: "verdict_first",
                label: "Verdict-first structure",
                score: 0.61,
                confidence: 0.61,
                evidence: [long],
                missingEvidence: nil
            )],
            nextProofDimensionID: "verdict_first",
            missingEvidence: [long],
            nextProofTest: long,
            responseMode: .expandable,
            repairFocus: long
        ))
        let request = CoachChatRequest(
            accountID: "firebase-guest",
            surface: "text",
            qualityTier: "ultra",
            coachingBrief: brief,
            verifiedQuoteSources: Array(
                repeating: String(repeating: "q", count: 5_000),
                count: 5
            ),
            coachingContext: String(repeating: "c", count: 12_000),
            messages: Array(repeating: CoachChatWireMessage(
                role: .user,
                content: String(repeating: "m", count: 4_000)
            ), count: 12)
        )

        #expect(brief.directVerdict.count <= CoachChatBrief.maxFieldCharacters)
        #expect(brief.decisiveEvidence?.count == CoachChatBrief.maxFieldCharacters)
        #expect(request.verifiedQuoteSources.count == CoachChatRequest.maxQuoteSources)
        #expect(request.verifiedQuoteSources.allSatisfy {
            $0.count == CoachChatRequest.maxQuoteSourceCharacters
        })
        #expect(request.messages.last?.role == .user)
        #expect(request.coachingContext.count + brief.characterCount +
            request.verifiedQuoteSources.reduce(0) { $0 + $1.count } +
            request.messages.reduce(0) { $0 + $1.content.count } <=
            CoachChatRequest.totalRequestCharacterBudget)
    }

    @Test func coachingBriefRejectsAbsenceEvidenceForItsActualMove() {
        let brief = CoachChatBrief(assessment: CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: "What should I fix first?",
            directVerdict: "The opening is the next lever.",
            confidence: 0.62,
            evidenceUsed: [
                "latest rep: Timed, 7/10, 60s",
                "filler evidence was not quantity-qualified"
            ],
            rubricScores: [RubricScore(
                dimensionID: "verdict_first",
                label: "Verdict-first structure",
                score: 0.42,
                confidence: 0.62,
                evidence: [
                    "the available excerpt did not clearly put the answer first"
                ],
                missingEvidence: nil
            )],
            nextProofDimensionID: "verdict_first",
            missingEvidence: [],
            nextProofTest: "Put the recommendation in sentence one.",
            responseMode: .immediateOnly
        ))

        #expect(brief.decisiveEvidence == nil)
        #expect(brief.evidenceStrength == .missing)
    }

    @Test func turnIntentClassificationKeepsSocialAndSensitiveTurnsOutOfDrills() {
        #expect(CoachChatTurnIntent.classify("hi") == .greeting)
        #expect(CoachChatTurnIntent.classify("banana") == .offTopic)
        #expect(CoachChatTurnIntent.classify("Keep the coaching concise") == .preference)
        let reporterStyleFeedback = "it just says weird wording and too much redundant wording, doesn’t feel like a human expert communications coach at all"
        #expect(CoachChatTurnIntent.classify(reporterStyleFeedback) == .preference)
        #expect(CoachChatTurnIntent.classify("You're repeating yourself.") == .preference)
        #expect(CoachChatTurnIntent.classify("That's not informative.") == .preference)
        #expect(CoachChatTurnIntent.classify("That wasn't helpful.") == .preference)
        #expect(CoachChatTurnIntent.classify("You missed the point.") == .preference)
        #expect(CoachChatTurnIntent.classify("Stop telling me to practice.") == .preference)
        #expect(CoachChatTurnIntent.classify("I keep repeating myself.") == .coaching)
        #expect(CoachChatTurnIntent.classify("My answer is not informative.") == .coaching)
        #expect(CoachChatTurnIntent.classify("I'm nervous about this") == .vulnerable)
        #expect(CoachChatTurnIntent.classify("What should I fix first?") == .coaching)
        #expect(CoachChatTurnIntent.classify(
            "How do I read aloud more naturally?"
        ) == .coaching)
        #expect(CoachChatResponseKind.classify(
            "How do I read aloud more naturally?"
        ) == .generalCoaching)
        #expect(CoachChatTurnIntent.classify(
            "Please don't use markdown in your replies."
        ) == .preference)
        #expect(CoachChatTurnIntent.classify(
            "How do I sound more authoritative in tomorrow’s update?"
        ) == .coaching)
        #expect(CoachChatTurnIntent.classify("I’m nervous—how should I open?") == .coaching)
        #expect(CoachChatTurnIntent.classify(nil) == .unknown)
    }

    @Test func responseKindSeparatesCraftPersonalMemoryAndConversation() {
        #expect(CoachChatResponseKind.classify(
            "How do I structure a presentation?"
        ) == .generalCoaching)
        #expect(CoachChatResponseKind.classify(
            "How can I cut filler words without sounding stiff?"
        ) == .generalCoaching)
        #expect(CoachChatResponseKind.classify(
            "How did I do?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "How am I doing?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "Am I improving?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "What were my exact stats?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "How many fillers did I use?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "How did I do that?"
        ) == .generalCoaching)
        #expect(CoachChatResponseKind.classify(
            "What is a good speaking pace?"
        ) == .generalCoaching)
        #expect(CoachChatResponseKind.classify(
            "What should I fix first?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "What is the one move?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "What do you know about me?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "What have you noticed about me?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "What pattern do you see?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "Based on my reps, what should I change?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "What stands out for me in my answers?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "Am I afraid to disagree?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "You counted 'like', but I meant it as a comparison."
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "Did I actually say that?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "This week felt harder even though my score improved."
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "Is 7/10 bad?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "How should a coach explain a ten-point scale?"
        ) == .generalCoaching)
        #expect(CoachChatResponseKind.classify(
            "My interview answer landed better than practice. What do we learn?"
        ) == .personalEvidenceRead)
        #expect(CoachChatResponseKind.classify(
            "What should Noum remember?"
        ) == .memoryHandoff)
        #expect(CoachChatResponseKind.classify("hi") == .conversational)
        #expect(CoachChatResponseKind.classify(
            "it just says weird wording and too much redundant wording, doesn’t feel like a human expert communications coach at all"
        ) == .conversational)
        #expect(CoachChatResponseKind.classify("You're repeating yourself.") == .conversational)
        #expect(CoachChatResponseKind.classify("That's not informative.") == .conversational)
        #expect(CoachChatResponseKind.classify("That wasn't helpful.") == .conversational)
        #expect(CoachChatResponseKind.classify("You missed the point.") == .conversational)
        #expect(CoachChatResponseKind.classify("Stop telling me to practice.") == .conversational)
        #expect(CoachChatResponseKind.classify("I keep repeating myself.") == .generalCoaching)

        let directEvaluationKind = CoachChatResponseKind.classify("How did I do?")
        #expect(CoachReplyPipeline.shouldBuildAssessment(
            judgementPassEnabled: true,
            turnIntent: .coaching,
            responseKind: directEvaluationKind
        ))
    }

    @Test func typedBriefWithdrawsOnlyUngroundedGeneralAssessment() throws {
        let ungrounded = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "How do I structure a presentation?",
            directVerdict: "The opening is the next lever.",
            confidence: 0.62,
            evidenceUsed: ["latest rep: no usable transcript signal"],
            rubricScores: [],
            nextProofDimensionID: nil,
            missingEvidence: ["A quantity-qualified transcript is missing."],
            nextProofTest: "Open with the decision.",
            responseMode: .immediateOnly
        )
        let personalBrief = try #require(CoachChatBrief.applicable(
            assessment: ungrounded,
            responseKind: .personalEvidenceRead
        ))
        let generalBrief = CoachChatBrief.applicable(
            assessment: ungrounded,
            responseKind: .generalCoaching
        )
        let unrelatedGroundedAssessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "How do I structure a presentation?",
            directVerdict: "The last answer delayed its recommendation.",
            confidence: 0.68,
            evidenceUsed: ["latest rep: the recommendation followed setup"],
            rubricScores: [RubricScore(
                dimensionID: "verdict_first",
                label: "Verdict-first structure",
                score: 0.42,
                confidence: 0.68,
                evidence: ["the recommendation followed setup"],
                missingEvidence: nil
            )],
            nextProofDimensionID: "verdict_first",
            missingEvidence: [],
            nextProofTest: "Put the recommendation in sentence one.",
            responseMode: .immediateOnly
        )
        #expect(personalBrief.nextMove == nil)
        #expect(generalBrief == nil)
        #expect(CoachChatBrief.applicable(
            assessment: unrelatedGroundedAssessment,
            responseKind: .generalCoaching
        ) == nil)
        #expect(CoachChatBrief.applicable(
            assessment: ungrounded,
            responseKind: .conversational
        ) == nil)
        #expect(CoachReplyPipeline.assessmentForProvider(
            ungrounded,
            coachingBrief: generalBrief,
            responseKind: .generalCoaching
        ) == nil)
        #expect(CoachReplyPipeline.assessmentForProvider(
            ungrounded,
            coachingBrief: personalBrief,
            responseKind: .personalEvidenceRead
        ) != nil)

        let memoryAssessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "What should Noum remember?",
            directVerdict: "What I’d carry forward for now is one possible pattern, not a fixed label.",
            confidence: 0.62,
            evidenceUsed: [
                "conversation hypothesis: the point may arrive after setup"
            ],
            rubricScores: [],
            nextProofDimensionID: nil,
            missingEvidence: [],
            nextProofTest: "Use two pressure reps to check it; drop this read if the point lands first.",
            responseMode: .immediateOnly
        )
        let memoryBrief = try #require(CoachChatBrief.applicable(
            assessment: memoryAssessment,
            responseKind: .memoryHandoff
        ))
        #expect(memoryBrief.directVerdict == memoryAssessment.directVerdict)
        #expect(memoryBrief.decisiveEvidence == memoryAssessment.evidenceUsed.first)
        #expect(memoryBrief.nextMove == memoryAssessment.nextProofTest)
        #expect(CoachReplyPipeline.assessmentForProvider(
            memoryAssessment,
            coachingBrief: memoryBrief,
            responseKind: .memoryHandoff
        ) != nil)

        let firstTurnMemoryAssessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "What should Noum remember?",
            directVerdict: "I don't have a clear pattern to carry forward yet.",
            confidence: 0.20,
            evidenceUsed: ["latest rep: an ordinary unconsented observation"],
            rubricScores: [],
            nextProofDimensionID: nil,
            missingEvidence: ["No consent-bound conversation hypothesis."],
            nextProofTest: "Run another rep.",
            responseMode: .immediateOnly
        )
        let incompleteMemoryBrief = CoachChatBrief.applicable(
            assessment: firstTurnMemoryAssessment,
            responseKind: .memoryHandoff
        )
        #expect(incompleteMemoryBrief == nil)
        #expect(CoachReplyPipeline.assessmentForProvider(
            firstTurnMemoryAssessment,
            coachingBrief: incompleteMemoryBrief,
            responseKind: .memoryHandoff
        ) == nil)
    }

    @Test func clientGateRejectsPrescriptionsOnNonCoachingTurns() {
        for turn in [
            "hi",
            "banana",
            "Keep the coaching concise",
            "I'm nervous about this"
        ] {
            for reply in [
                "Because the recommendation matters, you should put it first.",
                "You should pause.",
                "You can start."
            ] {
                #expect(AICoachChatService.replyQualityIssue(
                    in: reply,
                    latestUserTurn: turn
                ) == .nonCoachingPrescription)
            }
        }
    }

    @Test func clientGateAllowsOneBoundedActionWhenAVulnerableTurnExplicitlyAsksForHelp() {
        let reply = "Hold one silent beat before sentence one, then say only the opener; check whether its first five words stay clean."

        #expect(AICoachChatService.replyQualityIssue(
            in: reply,
            latestUserTurn: "I panic before answering. What do I do?"
        ) == nil)
        #expect(AICoachChatService.replyQualityIssue(
            in: "You're right—this isn't easy. The setup carries social risk under pressure, so make it smaller: say the disagreement and one calm reason, then stop.",
            latestUserTurn: "It's not easy."
        ) == nil)
        #expect(AICoachChatService.replyQualityIssue(
            in: reply,
            latestUserTurn: "I'm nervous about this"
        ) == .nonCoachingPrescription)
    }

    @Test func personalEvidenceReadDoesNotLeakAStoredMoveIntoAnObservationTurn() throws {
        let assessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "What have you noticed about me?",
            directVerdict: "The recommendation arrived after the setup.",
            confidence: 0.68,
            evidenceUsed: ["latest rep: the recommendation followed setup"],
            rubricScores: [RubricScore(
                dimensionID: "verdict_first",
                label: "Verdict-first structure",
                score: 0.42,
                confidence: 0.68,
                evidence: ["the recommendation followed setup"],
                missingEvidence: nil
            )],
            nextProofDimensionID: "verdict_first",
            missingEvidence: [],
            nextProofTest: "Put the recommendation in sentence one.",
            responseMode: .immediateOnly
        )
        let brief = try #require(CoachChatBrief.applicable(
            assessment: assessment,
            responseKind: .personalEvidenceRead
        ))
        #expect(brief.nextMove == assessment.nextProofTest)

        let observationTurn = "What have you noticed about me?"
        let descriptiveRead = "Your last rep put the recommendation after the setup, which softened the opening."
        #expect(AICoachChatService.replyQualityIssue(
            in: descriptiveRead,
            latestUserTurn: observationTurn,
            responseKind: .personalEvidenceRead,
            coachingBrief: brief
        ) == nil)

        let prescribedMove = "Your last rep put the recommendation after the setup, which softened the opening. Put the recommendation first in the next rep."
        #expect(AICoachChatService.replyQualityIssue(
            in: prescribedMove,
            latestUserTurn: observationTurn,
            responseKind: .personalEvidenceRead,
            coachingBrief: brief
        ) == .nonCoachingPrescription)

        #expect(AICoachChatService.replyQualityIssue(
            in: prescribedMove,
            latestUserTurn: "Based on my reps, what should I change?",
            responseKind: .personalEvidenceRead,
            coachingBrief: brief
        ) == nil)
        #expect(AICoachChatService.replyQualityIssue(
            in: prescribedMove,
            latestUserTurn: observationTurn,
            responseKind: .personalEvidenceRead,
            coachingBrief: nil
        ) != .nonCoachingPrescription)
        #expect(AICoachChatService.replyQualityIssue(
            in: prescribedMove,
            latestUserTurn: "What should Noum remember?",
            responseKind: .memoryHandoff,
            coachingBrief: brief
        ) != .nonCoachingPrescription)
        #expect(AICoachChatService.replyQualityIssue(
            in: "Open with the decision, then give one reason and one example; that order separates the point from its support.",
            latestUserTurn: "How do I structure a presentation?",
            responseKind: .generalCoaching,
            coachingBrief: brief
        ) != .nonCoachingPrescription)
    }

    @Test func clientGateUsesTheTypedResponseLane() {
        let general = "Open with the decision, then give one reason and one example; that order separates the point from its support."
        #expect(AICoachChatService.replyQualityIssue(
            in: general,
            latestUserTurn: "How do I structure a presentation?",
            systemContext: "RECENT (most-recent first): setup came first",
            responseKind: .generalCoaching,
            coachingBrief: nil
        ) == nil)
        #expect(AICoachChatService.replyQualityIssue(
            in: "Your recent reps show the setup before the recommendation.",
            latestUserTurn: "How do I structure a presentation?",
            systemContext: "RECENT (most-recent first): setup came first",
            responseKind: .generalCoaching,
            coachingBrief: nil
        ) == .overclaimsEvidence)
        #expect(AICoachChatService.replyQualityIssue(
            in: "You’re right—I repeated myself and sounded templated. I’ll answer with one specific point in plain language.",
            latestUserTurn: "Your wording is too redundant and robotic.",
            turnDepth: .trustRepair,
            responseKind: .conversational,
            coachingBrief: nil
        ) == nil)
        let reporterTurn = "it just says weird wording and too much redundant wording, doesn’t feel like a human expert communications coach at all"
        let coachCommitment = "You’re right—I repeated myself and sounded templated. I’ll answer with one specific point in plain language."
        #expect(AICoachChatService.replyQualityIssue(
            in: coachCommitment,
            latestUserTurn: reporterTurn,
            recentCoachReplies: [coachCommitment],
            turnDepth: .trustRepair,
            responseKind: .conversational,
            coachingBrief: nil
        ) == nil)
        #expect(AICoachChatService.replyQualityIssue(
            in: CoachChatBrief.insufficientEvidenceVerdict,
            latestUserTurn: "How do I structure a presentation?",
            responseKind: .generalCoaching,
            coachingBrief: nil
        ) != nil)
        #expect(AICoachChatService.replyQualityIssue(
            in: CoachChatBrief.insufficientEvidenceVerdict,
            latestUserTurn: "What should I fix first?",
            responseKind: .personalEvidenceRead,
            coachingBrief: nil
        ) == nil)
        #expect(AICoachChatService.replyQualityIssue(
            in: "That sounds hard. We can slow this down.",
            latestUserTurn: "I'm nervous about this.",
            responseKind: .conversational,
            coachingBrief: nil
        ) == nil)
        #expect(AICoachChatService.replyQualityIssue(
            in: "I don't have enough evidence to answer that honestly yet. What did you say first in the answer you want me to read?",
            latestUserTurn: "What should I fix first?",
            systemContext: "RECENT (most-recent first): no typed observation",
            responseKind: .personalEvidenceRead,
            coachingBrief: nil
        ) == nil)
        #expect(AICoachChatService.replyQualityIssue(
            in: "I don't have a clear pattern to carry forward yet.",
            latestUserTurn: "What should Noum remember?",
            responseKind: .memoryHandoff,
            coachingBrief: nil
        ) == nil)

        let alternateMemoryAssessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "What should Noum remember?",
            directVerdict: "What I’d carry forward for now is that fillers may cluster after the close.",
            confidence: 0.60,
            evidenceUsed: [
                "conversation hypothesis: fillers may cluster after the close"
            ],
            rubricScores: [],
            nextProofDimensionID: nil,
            missingEvidence: [],
            nextProofTest: "Use two comparable reps to check whether that still happens; drop this read if it does not.",
            responseMode: .immediateOnly
        )
        let alternateMemoryBrief = CoachChatBrief.applicable(
            assessment: alternateMemoryAssessment,
            responseKind: .memoryHandoff
        )
        #expect(AICoachChatService.replyQualityIssue(
            in: "What I’d carry forward for now is one possible pattern: fillers may cluster after the close. Use two comparable reps to check whether that still happens; drop this read if it does not.",
            latestUserTurn: "What should Noum remember?",
            responseKind: .memoryHandoff,
            coachingBrief: alternateMemoryBrief
        ) == nil)
    }

    @Test func nonPersonalContextCannotLeakRepHistory() {
        let general = CoachContextBuilder.nonPersonalContext(
            profile: nil,
            responseKind: .generalCoaching,
            coachingExpertise: []
        )
        #expect(general.contains("Answer the communication craft question directly"))
        #expect(general.contains("Coaching voice: Neutral"))
        #expect(!general.contains("RECENT"))
        #expect(!general.lowercased().contains("transcript"))
        #expect(!general.lowercased().contains("filler"))
        #expect(!general.lowercased().contains("score"))
    }

    @Test func pendingGoalAndPersuasiveCapabilitiesReachNonPersonalContext() {
        var profile = CoachingProfile(
            speakingContext: .work,
            primaryGoal: .moreConcise,
            confidenceLevel: .rebuilding,
            biggestChallenge: .rambling,
            desiredOutcome: .persuasive,
            speakingStyleGoal: .persuasive,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: "",
            chosenStyleGoal: .persuasive
        )
        profile.chosenStyleGoal = .persuasive
        let context = CoachContextBuilder.nonPersonalContext(
            profile: profile,
            responseKind: .generalCoaching,
            coachingExpertise: [],
            pendingGoalIntent: .init(requestedVoice: nil, kind: .change)
        )

        #expect(context.contains("GOAL INTENT (this turn)"))
        #expect(context.contains("Claim, Evidence, Warrant"))
        #expect(context.contains("Persuade with Structure"))
        #expect(context.contains("Chat cannot submit a product or roadmap request"))
    }

    @Test func authorizedMoveVocabularyIsAcceptedAndRepeatableAcrossTheClientGate() {
        let moves = [
            "Advance the read: keep the prior target, but change the proof to the next observable sentence.",
            "Repair the same answer in plain speech: no markdown, one specific read, one move.",
            "Log the outcome as a field note, then repeat one pressure rep and check the same observable target.",
            "Replay the answer once and replace one hedge with a direct recommendation.",
            "Place one silent beat after the verdict, then finish the reason in one sentence.",
            "Add one concrete example after the verdict, then stop before a second example.",
            "Test a smaller version in the next rep: say only the disagreement and one calm reason, then stop before defending it.",
            "Keep the prior target and test it in the next pressure rep."
        ]
        for move in moves {
            let rawReply = move + " This fits because the latest rep showed setup before the recommendation."
            let reply = AICoachChatService.finalizedCoachReply(
                from: rawReply,
                latestUserTurn: "What should I fix first?",
                turnDepth: .groundedRead
            )
            #expect(AICoachChatService.replyQualityIssue(
                in: reply,
                latestUserTurn: "What should I fix first?",
                turnDepth: .groundedRead
            ) == nil, Comment(rawValue: move))
            #expect(AICoachChatService.replyQualityIssue(
                in: reply,
                latestUserTurn: "What should I fix first?",
                recentCoachReplies: [reply],
                turnDepth: .groundedRead
            ) == .repeatedProofTest, Comment(rawValue: move))
        }
    }

    @Test func completionMetadataRoundTripsThroughTheWire() throws {
        let completion = CoachChatCompletion(
            requestID: UUID().uuidString,
            text: "Lead with the answer.",
            model: "gemini-2.5-flash",
            qualityTier: "fast",
            finishReason: "STOP",
            inputTokens: 120,
            outputTokens: 18,
            policyVersion: "noum-coach-v2",
            generationMode: .deterministicBrief
        )
        let data = try JSONEncoder().encode(completion)
        #expect(try JSONDecoder().decode(CoachChatCompletion.self, from: data) == completion)
        #expect(try JSONDecoder().decode(
            CoachChatCompletion.self,
            from: data
        ).policyVersion == "noum-coach-v2")
        #expect(try JSONDecoder().decode(
            CoachChatCompletion.self,
            from: data
        ).generationMode == .deterministicBrief)
    }

    @Test func legacyCompletionAndPromptTraceRemainDecodable() throws {
        let legacyCompletion = try JSONSerialization.data(withJSONObject: [
            "requestID": UUID().uuidString,
            "text": "Lead with the answer.",
            "model": "gemini-2.5-flash",
            "qualityTier": "fast",
            "finishReason": "STOP"
        ])
        #expect(try JSONDecoder().decode(
            CoachChatCompletion.self,
            from: legacyCompletion
        ).policyVersion == nil)
        #expect(try JSONDecoder().decode(
            CoachChatCompletion.self,
            from: legacyCompletion
        ).generationMode == nil)

        let legacyTrace = try JSONSerialization.data(withJSONObject: [
            "moduleCount": 1,
            "cacheableModuleCount": 0,
            "totalCharacterCount": 4,
            "modules": [[
                "name": "userContext",
                "cachePolicy": "none",
                "characterCount": 4,
                "nonEmptyLineCount": 1
            ]]
        ])
        let trace = try JSONDecoder().decode(CoachPromptTrace.self, from: legacyTrace)
        #expect(trace.modules.first?.secureTransportTransmitted == nil)
    }

    @Test func promptTraceDoesNotClaimTheClientPolicyCrossesSecureWire() throws {
        let trace = CoachPromptTrace.make(
            systemPrompt: "Client direct-debug policy",
            userContext: "Bounded user context"
        )
        let system = try #require(
            trace.modules.first { $0.name == "coachSystemPrompt" }
        )
        let context = try #require(
            trace.modules.first { $0.name == "userContext" }
        )
        #expect(system.secureTransportTransmitted == false)
        #expect(context.secureTransportTransmitted == true)
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
        let assessment = CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: "What should I fix first?",
            directVerdict: "The recommendation arrives after the setup.",
            confidence: 0.68,
            evidenceUsed: ["The latest practice opens with background."],
            rubricScores: [],
            missingEvidence: ["A comparable follow-up rep is missing."],
            nextProofTest: "Put the recommendation first in the next practice.",
            responseMode: .immediateOnly
        )
        for tier in [CoachProviderTier.geminiFast, .claudeReasoning] {
            let transport = CapturingCoachTransport()
            let service = AICoachChatService(secureTransport: transport)
            var landedChoice: CoachTurnProviderChoice?

            let outcome = await service.reply(
                history: [CoachMessage(role: .user, text: "What should I fix first?")],
                systemPrompt: "Coach the next observable move.",
                userContext: "RECENT: latest rep 7/10, 1 filler.",
                accountID: "firebase-guest",
                grounding: ChatGroundingContext(
                    recentTimedTranscript: "The risk is manageable. We should decide before we explain.",
                    verifiedProofQuotes: ["The risk is manageable."]
                ),
                turnDepth: .quickMove,
                assessment: assessment,
                coachVoice: .executive,
                preferredTier: tier,
                onProviderChosen: { landedChoice = $0 }
            )

            let request = try #require(transport.capturedRequest())
            #expect(request.accountID == "firebase-guest")
            #expect(request.qualityTier == tier.transportQualityTier)
            #expect(request.coachVoice == SpeakingStyleGoal.executive.rawValue)
            #expect(request.turnDepth == CoachTurnDepth.quickMove.rawValue)
            #expect(request.turnIntent == CoachChatTurnIntent.coaching.rawValue)
            #expect(request.responseKind ==
                CoachChatResponseKind.personalEvidenceRead.rawValue)
            #expect(request.coachingBrief?.evidenceStrength == .missing)
            #expect(request.coachingBrief?.directVerdict ==
                "I don’t have enough evidence to choose your next move yet.")
            #expect(request.coachingBrief?.decisiveEvidence == nil)
            #expect(request.coachingBrief?.nextMove == nil)
            #expect(request.verifiedQuoteSources == [
                "The risk is manageable."
            ])
            guard case .reply = outcome else {
                Issue.record("A valid secure reply did not land")
                continue
            }
            #expect(landedChoice?.resolvedTier == tier)
            #expect(landedChoice?.model == transport.model(for: tier))
            #expect(landedChoice?.policyVersion == "noum-coach-v2")
            #expect(landedChoice?.generationMode == .model)
        }
    }

    @MainActor
    @Test func typedLatestRepReadSurvivesSecureWireAndLandsWithoutADrill() async throws {
        let sourceID = UUID()
        let projection = try #require(CoachLatestRepMetricProjection(
            evidencePack: LatestRepEvidencePack(
                mode: "Ah Counter",
                score: 8,
                fillerCount: 3,
                durationSeconds: 60,
                wordsPerMinute: 120,
                transcriptWordCount: 120,
                transcriptConfidence: 0.90,
                transcriptExcerpt: nil,
                evidenceLines: [],
                sourceSessionID: sourceID,
                comparisonMetricSchemaVersion: 2,
                isEvaluationFixture: false
            )
        ))
        let assessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "How many fillers did I use?",
            directVerdict: "",
            confidence: 0.60,
            evidenceUsed: [],
            rubricScores: [],
            evidenceReadKind: .latestRepMetrics,
            requestedMetrics: [.fillerCount],
            latestRepMetrics: projection,
            missingEvidence: [],
            nextProofTest: "A drill must not enter this evidence-only turn.",
            responseMode: .immediateOnly
        )
        let expected = CoachChatBrief(assessment: assessment).directVerdict
        let transport = CapturingCoachTransport(
            completionText: expected,
            generationMode: .deterministicBrief
        )
        let service = AICoachChatService(secureTransport: transport)

        let outcome = await service.reply(
            history: [CoachMessage(
                role: .user,
                text: "How many fillers did I use?"
            )],
            systemPrompt: "Answer only from typed evidence.",
            userContext: "The coaching brief is the complete personal allowance.",
            accountID: "firebase-guest",
            turnDepth: .groundedRead,
            assessment: assessment,
            preferredTier: .geminiFast
        )

        let request = try #require(transport.capturedRequest())
        #expect(request.responseKind ==
            CoachChatResponseKind.personalEvidenceRead.rawValue)
        #expect(request.coachingBrief?.evidenceReadKind == .latestRepMetrics)
        #expect(request.coachingBrief?.requestedMetrics == [.fillerCount])
        #expect(request.coachingBrief?.latestRepMetrics?.sourceSessionID == sourceID)
        #expect(request.coachingBrief?.nextMove == nil)
        #expect(transport.callCounts().availability == 1)
        #expect(transport.callCounts().stream == 1)
        guard case .reply(let landed) = outcome else {
            Issue.record("Typed latest-rep evidence did not land")
            return
        }
        #expect(landed == expected)
        #expect(!landed.lowercased().contains("drill"))
        #expect(!landed.lowercased().contains("qualified"))
    }

    @MainActor
    @Test func typedLongitudinalReadSurvivesSecureWireInPlainLanguage() async throws {
        let sourceID = UUID()
        let priorIDs = [UUID(), UUID()]
        let trend = CoachLongitudinalTrendProjection(
            sourceSessionID: sourceID,
            comparisonMetricSchemaVersion: 2,
            mode: "Ah Counter",
            comparableSessionIDs: priorIDs,
            metrics: [CoachLongitudinalMetricTrend(
                metric: .score,
                direction: .improving,
                currentValue: 8,
                priorAverage: 7
            )]
        )
        let assessment = CoachAssessment(
            turnDepth: .deepAssessment,
            surface: .text,
            questionRestatement: "Am I improving?",
            directVerdict: "",
            confidence: 0.70,
            evidenceUsed: [],
            rubricScores: [],
            evidenceReadKind: .longitudinalTrend,
            longitudinalTrend: trend,
            missingEvidence: [],
            nextProofTest: "A drill must not enter this evidence-only turn.",
            responseMode: .expandable
        )
        let expected = CoachChatBrief(assessment: assessment).directVerdict
        let transport = CapturingCoachTransport(
            completionText: expected,
            generationMode: .deterministicBrief
        )
        let service = AICoachChatService(secureTransport: transport)
        var gateEvents: [CoachTurnQualityGateEvent] = []

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "Am I improving?")],
            systemPrompt: "Answer only from typed evidence.",
            userContext: "The coaching brief is the complete personal allowance.",
            accountID: "firebase-guest",
            turnDepth: .deepAssessment,
            assessment: assessment,
            preferredTier: .claudeReasoning,
            onQualityGateEvent: { gateEvents.append($0) }
        )

        let request = try #require(transport.capturedRequest())
        #expect(request.coachingBrief?.evidenceReadKind == .longitudinalTrend)
        #expect(request.coachingBrief?.longitudinalTrend?.sourceSessionID == sourceID)
        #expect(request.coachingBrief?.longitudinalTrend?.comparableSessionIDs == priorIDs)
        #expect(request.coachingBrief?.nextMove == nil)
        guard case .reply(let landed) = outcome else {
            Issue.record("Typed longitudinal evidence did not land: \(gateEvents)")
            return
        }
        #expect(landed == expected)
        #expect(landed.contains("same setup"))
        #expect(gateEvents == [.passed])
        #expect(landed.contains("not proof"))
        #expect(!landed.lowercased().contains("qualified"))
        #expect(!landed.lowercased().contains("comparable"))
    }

    @MainActor
    @Test func generalCraftQuestionReachesTransportWithoutPersonalBrief() async throws {
        let reply = "Open with the decision, then give one reason and one example; that order separates the point from its support."
        let transport = CapturingCoachTransport(completionText: reply)
        let service = AICoachChatService(secureTransport: transport)

        let outcome = await service.reply(
            history: [CoachMessage(
                role: .user,
                text: "How do I structure a presentation?"
            )],
            systemPrompt: "Answer the communication question directly.",
            userContext: "COACHING EXPERTISE: decision, reason, example.",
            turnDepth: .groundedRead,
            assessment: nil,
            preferredTier: .geminiFast
        )

        let request = try #require(transport.capturedRequest())
        #expect(request.responseKind ==
            CoachChatResponseKind.generalCoaching.rawValue)
        #expect(request.coachingBrief == nil)
        guard case .reply(let landed) = outcome else {
            Issue.record("General coaching did not reach a usable provider reply")
            return
        }
        #expect(landed == reply)
    }

    @MainActor
    @Test func secureGeneralCoachingQualityRejectionHasPipelineRecovery() async throws {
        let userTurn = "How do I add depth without rambling?"
        let rejectedReply = "Based on your data, here are a few tips to communicate more clearly."
        let transport = CapturingCoachTransport(completionText: rejectedReply)
        let service = AICoachChatService(secureTransport: transport)

        let secureOutcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "Answer the communication question directly.",
            userContext: "GENERAL COACHING ONLY",
            turnDepth: .quickMove,
            assessment: nil,
            responseKind: .generalCoaching,
            preferredTier: .geminiFast
        )

        guard case .failure(.contentRejected) = secureOutcome else {
            Issue.record("The secure client gate did not reject the generic draft")
            return
        }
        let fallback = try #require(CoachReplyPipeline.safeFailureFallbackText(
            for: secureOutcome,
            assessment: nil,
            turnDepth: .quickMove,
            surface: .text,
            previousCoachReply: nil,
            latestUserTurn: userTurn,
            responseKind: .generalCoaching
        ))
        #expect(fallback.contains("one layer only"))
        #expect(fallback.contains("one concrete example"))
        #expect(!fallback.lowercased().contains("based on your data"))
        #expect(AICoachChatService.replyQualityIssue(
            in: fallback,
            latestUserTurn: userTurn,
            turnDepth: .quickMove,
            responseKind: .generalCoaching
        ) == nil)
        #expect(AICoachChatService.semanticQualityIssue(
            in: fallback,
            latestUserTurn: userTurn,
            turnDepth: .quickMove,
            assessment: nil,
            responseKind: .generalCoaching
        ) == nil)

        // A malformed/empty transport result remains an explicit operational
        // failure; this recovery is for rejected wording, not for hiding a
        // broken backend contract.
        #expect(CoachReplyPipeline.safeFailureFallbackText(
            for: .failure(.empty),
            assessment: nil,
            turnDepth: .quickMove,
            surface: .text,
            previousCoachReply: nil,
            latestUserTurn: userTurn,
            responseKind: .generalCoaching
        ) == nil)
        #expect(CoachReplyPipeline.safeFailureFallbackText(
            for: .failure(.contentRejected),
            assessment: nil,
            turnDepth: .groundedRead,
            surface: .text,
            previousCoachReply: nil,
            latestUserTurn: "How should I communicate better?",
            responseKind: .generalCoaching
        ) == nil)
    }

    @MainActor
    @Test func secureCompactScorecardUsesCompleteTypedFallbackBeforeClauseSurgery() async throws {
        let userTurn = "What should I work on next?"
        let rawScorecard = "7/10, 3 fillers, 60s. Your recommendation arrived after the setup, so the listener had to wait for it. Next rep, put the recommendation in sentence one, give one reason, then stop."
        let assessment = CoachAssessment(
            turnDepth: .quickMove,
            surface: .text,
            questionRestatement: userTurn,
            directVerdict: "The recommendation arrives after the setup.",
            confidence: 0.72,
            evidenceUsed: ["The latest rep opens with background before the recommendation."],
            rubricScores: [],
            missingEvidence: ["A comparable follow-up rep is missing."],
            nextProofTest: "Put the recommendation first in the next equivalent rep, give one reason, then stop.",
            responseMode: .immediateOnly
        )
        let transport = CapturingCoachTransport(completionText: rawScorecard)
        let service = AICoachChatService(secureTransport: transport)
        var providerChoice: CoachTurnProviderChoice?
        var gateEvents: [CoachTurnQualityGateEvent] = []

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "Coach the next observable move.",
            userContext: "RECENT: latest rep 7/10, 3 fillers, 60s. The recommendation arrived after the setup.",
            accountID: "firebase-guest",
            turnDepth: .quickMove,
            assessment: assessment,
            preferredTier: .geminiFast,
            onProviderChosen: { providerChoice = $0 },
            onQualityGateEvent: { gateEvents.append($0) }
        )

        guard case .reply(let landed) = outcome else {
            Issue.record("The secure path did not recover the rejected scorecard")
            return
        }
        #expect(landed != rawScorecard)
        #expect(!landed.hasPrefix("."))
        #expect(!landed.lowercased().hasPrefix("scorecard"))
        #expect(!landed.contains("7/10"))
        #expect(!landed.contains("3 fillers"))
        #expect(landed.contains("recommendation"))
        #expect(providerChoice?.providerName == "Typed judgement fallback")
        #expect(providerChoice?.model == "CoachAssessment")
        #expect(providerChoice?.resolvedTier == .geminiFast)
        #expect(providerChoice?.generationMode == .deterministicBrief)
        #expect(gateEvents == [
            .rejected("professional:roboticPhrase"),
            .fallback("professional:roboticPhrase"),
        ])
    }

    @MainActor
    @Test func secureInAppTechniqueFollowUpUsesSourceBackedLocalRepair() async throws {
        let userTurn = "So how can I do that in this app???"
        let previousReply = "It sounds like you want to make a stronger impression and connect more deeply with your colleagues. To do that, practice active listening by focusing on what others say and asking clarifying questions."
        let rejectedReply = "Use active listening in a practice session and review the result."
        let context = """
        === NON-PERSONAL COACH CONTEXT ===
        TURN CONTRACT
        - Answer the communication craft question directly.

        COACHING EXPERTISE
        - Warmth plus a real question [practitioner guidance]. Why: connection comes more from genuine interest. Apply it: instead of topping their story, ask the one thing you actually want to know about it. Working when: the other person opens up because you got curious about them.

        === END CONTEXT ===
        """
        #expect(AICoachChatService.replyQualityIssue(
            in: rejectedReply,
            latestUserTurn: userTurn,
            systemContext: context,
            turnDepth: .quickMove,
            responseKind: .generalCoaching
        ) == .ignoredCoachingExpertise)

        let quoteGuard = CoachChatQuoteGuardContext(
            transcripts: [nil],
            verifiedProofQuotes: [],
            latestUserTurn: userTurn,
            recentUserTurns: [
                "I feel ignored in team meetings and usually only have surface-level conversations.",
                userTurn,
            ]
        )
        let referenceShape = try #require(AICoachChatService.repairReferenceShape(
            issue: .ignoredCoachingExpertise,
            latestUserTurn: userTurn,
            system: context
        ))
        #expect(AICoachChatService.replyQualityIssue(
            in: referenceShape,
            latestUserTurn: userTurn,
            quoteGuard: quoteGuard,
            systemContext: context,
            recentCoachReplies: [previousReply],
            turnDepth: .quickMove,
            responseKind: .generalCoaching
        ) == nil)
        #expect(AICoachChatService.semanticQualityIssue(
            in: referenceShape,
            latestUserTurn: userTurn,
            systemContext: context,
            turnDepth: .quickMove,
            assessment: nil,
            responseKind: .generalCoaching
        ) == nil)
        #expect(AICoachChatService.visionQualityIssue(
            in: referenceShape,
            latestUserTurn: userTurn,
            quoteGuard: quoteGuard,
            systemContext: context,
            recentCoachReplies: [previousReply],
            turnDepth: .quickMove,
            assessment: nil,
            responseKind: .generalCoaching
        ) == nil)
        let expectedRepair = try #require(AICoachChatService.safeReferenceRepairReply(
            issue: .ignoredCoachingExpertise,
            latestUserTurn: userTurn,
            system: context,
            quoteGuard: quoteGuard,
            recentCoachReplies: [previousReply],
            turnDepth: .quickMove,
            responseKind: .generalCoaching
        ))
        #expect(expectedRepair.contains("Use Conversation Practice"))

        let transport = CapturingCoachTransport(completionText: rejectedReply)
        let service = AICoachChatService(secureTransport: transport)
        var providerChoice: CoachTurnProviderChoice?
        var gateEvents: [CoachTurnQualityGateEvent] = []
        let outcome = await service.reply(
            history: [
                CoachMessage(
                    role: .user,
                    text: "I feel ignored in team meetings and usually only have surface-level conversations."
                ),
                CoachMessage(role: .coach, text: previousReply),
                CoachMessage(role: .user, text: userTurn),
            ],
            systemPrompt: "Answer the communication question directly.",
            userContext: context,
            turnDepth: .quickMove,
            assessment: nil,
            responseKind: .generalCoaching,
            preferredTier: .geminiFast,
            onProviderChosen: { providerChoice = $0 },
            onQualityGateEvent: { gateEvents.append($0) }
        )

        guard case .reply(let landed) = outcome else {
            Issue.record("The secure path did not recover the in-app follow-up")
            return
        }
        #expect(landed.contains("Use Conversation Practice"))
        #expect(landed.contains("ask the one thing you actually want to know"))
        #expect(AskNoumModeSuggestion.detect(in: landed) == .imPractice(
            scenario: nil,
            tone: nil
        ))
        #expect(providerChoice?.providerName == "Deterministic quality fallback")
        #expect(providerChoice?.model == "SafeReferenceCoachGuard")
        #expect(gateEvents == [
            .rejected("professional:ignoredCoachingExpertise"),
            .fallback("professional:ignoredCoachingExpertise"),
        ])
        #expect(AICoachChatService.replyQualityIssue(
            in: landed,
            latestUserTurn: userTurn,
            systemContext: context,
            recentCoachReplies: [previousReply],
            turnDepth: .quickMove,
            responseKind: .generalCoaching
        ) == nil)
    }

    @MainActor
    @Test func reporterStyleFeedbackGetsCoachOwnedRepairWithoutADrill() async throws {
        let userTurn = "it just says weird wording and too much redundant wording, doesn’t feel like a human expert communications coach at all"
        let reply = "You’re right—I repeated myself and sounded templated. I’ll answer with one specific point in plain language."
        let transport = CapturingCoachTransport(completionText: reply)
        let service = AICoachChatService(secureTransport: transport)

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: userTurn)],
            systemPrompt: "Own coach-side style misses.",
            userContext: "RECENT: personal metrics that must not enter this turn.",
            turnDepth: .trustRepair,
            assessment: nil,
            preferredTier: .geminiFast
        )

        let request = try #require(transport.capturedRequest())
        #expect(request.turnIntent == CoachChatTurnIntent.preference.rawValue)
        #expect(request.responseKind == CoachChatResponseKind.conversational.rawValue)
        #expect(request.coachingBrief == nil)
        guard case .reply(let landed) = outcome else {
            Issue.record("Coach-style feedback did not land as conversation repair")
            return
        }
        #expect(landed == reply)
    }

    @MainActor
    @Test func nonPersonalSecureLanesUseBoundedPurposeSpecificReplay() async throws {
        struct Fixture {
            let turn: String
            let reply: String
            let kind: CoachChatResponseKind
            let depth: CoachTurnDepth
        }
        let fixtures = [
            Fixture(
                turn: "How do I structure a presentation?",
                reply: "Open with the decision, then give one reason and one example; that order separates the point from its support.",
                kind: .generalCoaching,
                depth: .groundedRead
            ),
            Fixture(
                turn: "it just says weird wording and too much redundant wording, doesn’t feel like a human expert communications coach at all",
                reply: "You’re right—I repeated myself and sounded templated. I’ll answer with one specific point in plain language.",
                kind: .conversational,
                depth: .trustRepair
            ),
            Fixture(
                turn: "What should Noum remember?",
                reply: "I don't have a clear pattern to carry forward yet.",
                kind: .memoryHandoff,
                depth: .groundedRead
            )
        ]

        for fixture in fixtures {
            let transport = CapturingCoachTransport(completionText: fixture.reply)
            let service = AICoachChatService(secureTransport: transport)
            let outcome = await service.reply(
                history: [
                    CoachMessage(role: .user, text: "What did my last rep show?"),
                    CoachMessage(
                        role: .coach,
                        text: "Your recent rep was 7/10 with two fillers and a late recommendation."
                    ),
                    CoachMessage(role: .user, text: fixture.turn)
                ],
                systemPrompt: "Follow the typed response lane.",
                userContext: "NON-PERSONAL CONTEXT",
                grounding: ChatGroundingContext(
                    recentTimedTranscript: "Personal transcript that must stay local.",
                    verifiedProofQuotes: ["Personal proof quote that must stay local."]
                ),
                turnDepth: fixture.depth,
                assessment: nil,
                preferredTier: .geminiFast
            )

            let request = try #require(transport.capturedRequest())
            #expect(request.responseKind == fixture.kind.rawValue)
            let expectedMessages: [CoachChatWireMessage]
            if fixture.kind == .conversational && fixture.depth == .trustRepair {
                expectedMessages = [
                    CoachChatWireMessage(
                        role: .assistant,
                        content: "Your recent rep was 7/10 with two fillers and a late recommendation."
                    ),
                    CoachChatWireMessage(role: .user, content: fixture.turn)
                ]
            } else {
                expectedMessages = [
                    CoachChatWireMessage(role: .user, content: fixture.turn)
                ]
            }
            #expect(request.messages == expectedMessages)
            #expect(request.verifiedQuoteSources.isEmpty)
            guard case .reply(let landed) = outcome else {
                Issue.record("\(fixture.kind.rawValue) did not land after replay filtering")
                continue
            }
            #expect(landed == fixture.reply)
        }

        let personalReply = "I don’t have enough evidence to choose your next move yet."
        let personalTransport = CapturingCoachTransport(completionText: personalReply)
        let personalService = AICoachChatService(secureTransport: personalTransport)
        let personalHistory = [
            CoachMessage(role: .user, text: "What did my previous rep show?"),
            CoachMessage(role: .coach, text: "The earlier read stayed evidence-bound."),
            CoachMessage(role: .user, text: "What should I fix first?")
        ]
        _ = await personalService.reply(
            history: personalHistory,
            systemPrompt: "Use personal evidence only when authorized.",
            userContext: "No typed observation is available.",
            turnDepth: .quickMove,
            assessment: nil,
            preferredTier: .geminiFast
        )
        let personalRequest = try #require(personalTransport.capturedRequest())
        #expect(personalRequest.responseKind ==
            CoachChatResponseKind.personalEvidenceRead.rawValue)
        #expect(personalRequest.messages.count == personalHistory.count)
    }

    @MainActor
    @Test func memoryHandoffReachesTransportWithConsentBoundBrief() async throws {
        let assessment = CoachAssessment(
            turnDepth: .groundedRead,
            surface: .text,
            questionRestatement: "What should Noum remember?",
            directVerdict: "What I’d carry forward for now is that disagreement may be getting softened by setup.",
            confidence: 0.62,
            evidenceUsed: [
                "prior coach read: the disagreement arrived after too much setup"
            ],
            rubricScores: [],
            nextProofDimensionID: nil,
            missingEvidence: [],
            nextProofTest: "Use two pressure reps to see whether the point still arrives late; drop this read if verdict-first solves it.",
            responseMode: .immediateOnly
        )
        let reply = "What I’d carry forward for now is one possible pattern: disagreement may be getting softened by setup. Use two pressure reps to see whether the point still arrives late; drop this read if verdict-first solves it."
        let transport = CapturingCoachTransport(completionText: reply)
        let service = AICoachChatService(secureTransport: transport)

        let outcome = await service.reply(
            history: [CoachMessage(
                role: .user,
                text: "What should Noum remember?"
            )],
            systemPrompt: "Keep memory consent-bound.",
            userContext: "The user asked what Noum should remember.",
            turnDepth: .groundedRead,
            assessment: assessment,
            preferredTier: .geminiFast
        )

        let request = try #require(transport.capturedRequest())
        #expect(request.responseKind ==
            CoachChatResponseKind.memoryHandoff.rawValue)
        #expect(request.coachingBrief?.directVerdict == assessment.directVerdict)
        #expect(request.coachingBrief?.decisiveEvidence ==
            assessment.evidenceUsed.first)
        #expect(request.coachingBrief?.nextMove == assessment.nextProofTest)
        guard case .reply(let landed) = outcome else {
            Issue.record("Memory handoff did not reach a usable provider reply")
            return
        }
        #expect(landed == reply)
    }

    @MainActor
    @Test func ellipticalGeneralFollowUpKeepsBoundedUserAndCoachReferent() async throws {
        let transport = CapturingCoachTransport(
            completionText: "Check whether the decision is still in sentence one after the rehearsal."
        )
        let service = AICoachChatService(secureTransport: transport)
        let priorUserTurn = "How do I structure a client update?"
        let followUp = "What should I check after?"

        _ = await service.reply(
            history: [
                CoachMessage(role: .user, text: priorUserTurn),
                CoachMessage(
                    role: .coach,
                    text: "Lead with the decision, give one reason, then stop."
                ),
                CoachMessage(role: .user, text: followUp)
            ],
            systemPrompt: "Answer the bounded follow-up.",
            userContext: "GENERAL COACHING ONLY",
            turnDepth: .quickMove,
            assessment: nil,
            responseKind: .generalCoaching,
            preferredTier: .geminiFast
        )

        let request = try #require(transport.capturedRequest())
        #expect(request.messages == [
            CoachChatWireMessage(role: .user, content: priorUserTurn),
            CoachChatWireMessage(
                role: .assistant,
                content: "Lead with the decision, give one reason, then stop."
            ),
            CoachChatWireMessage(role: .user, content: followUp)
        ])
    }

    @MainActor
    @Test func detailedPersuasiveFollowUpKeepsReferentAndSharedTrace() async throws {
        let transport = CapturingCoachTransport(
            completionText: "Use Claim, Evidence, Warrant because it keeps the proof and ask visible."
        )
        let service = AICoachChatService(secureTransport: transport)
        let traceID = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
        let followUp = "Ok what’s the best way to practice this? And honestly? Does this app have it? If not can we suggest it for future development?"

        _ = await service.reply(
            history: [
                CoachMessage(role: .user, text: "I want to practise being more persuasive."),
                CoachMessage(
                    role: .coach,
                    text: "Lead with the claim, support it with evidence, then make one clear ask."
                ),
                CoachMessage(role: .user, text: followUp)
            ],
            systemPrompt: "Answer the bounded follow-up.",
            userContext: "GENERAL COACHING ONLY",
            traceID: traceID,
            turnDepth: .quickMove,
            assessment: nil,
            responseKind: .generalCoaching,
            preferredTier: .geminiFast
        )

        let request = try #require(transport.capturedRequest())
        #expect(request.requestID == traceID.uuidString)
        #expect(request.messages == [
            CoachChatWireMessage(role: .user, content: "I want to practise being more persuasive."),
            CoachChatWireMessage(
                role: .assistant,
                content: "Lead with the claim, support it with evidence, then make one clear ask."
            ),
            CoachChatWireMessage(role: .user, content: followUp)
        ])
    }

    @MainActor
    @Test func bareQuestionMarkKeepsOnlyImmediateConversationReferent() async throws {
        let transport = CapturingCoachTransport(completionText: "By sharp, I mean quicker in the moment.")
        let service = AICoachChatService(secureTransport: transport)

        _ = await service.reply(
            history: [
                CoachMessage(role: .user, text: "I want to be more witty"),
                CoachMessage(role: .coach, text: "Do you mean playful and memorable, or quicker and sharper?"),
                CoachMessage(role: .user, text: "?")
            ],
            systemPrompt: "Clarify the preceding question.",
            userContext: "CONVERSATION ONLY",
            turnDepth: .quickMove,
            assessment: nil,
            responseKind: .conversational,
            preferredTier: .geminiFast
        )

        let request = try #require(transport.capturedRequest())
        #expect(request.messages == [
            CoachChatWireMessage(role: .user, content: "I want to be more witty"),
            CoachChatWireMessage(role: .assistant, content: "Do you mean playful and memorable, or quicker and sharper?"),
            CoachChatWireMessage(role: .user, content: "?")
        ])
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

    @MainActor
    @Test func secureNoMoveVerdictUsesTheHonestEvidenceLane() async {
        let reply = "I don’t have enough evidence to choose your next move yet."
        let transport = CapturingCoachTransport(
            completionText: reply,
            generationMode: .deterministicBrief
        )
        let service = AICoachChatService(secureTransport: transport)
        var landedChoice: CoachTurnProviderChoice?
        var gateEvents: [CoachTurnQualityGateEvent] = []

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "What should I fix first?")],
            systemPrompt: "Coach only from available evidence.",
            userContext: "No comparable rep is available.",
            turnDepth: .quickMove,
            preferredTier: .geminiFast,
            onProviderChosen: { landedChoice = $0 },
            onQualityGateEvent: { gateEvents.append($0) }
        )

        guard case .reply(let landed) = outcome else {
            Issue.record("The honest no-move verdict was rejected by the client gate: \(gateEvents)")
            return
        }
        #expect(landed == reply)
        #expect(landedChoice?.providerName == "Noum deterministic coach")
        #expect(landedChoice?.generationMode == .deterministicBrief)
        #expect(gateEvents == [.passed])
    }

    @MainActor
    @Test func secureCompatibilityReplyKeepsGroundedMoveAfterPromiseRemoval() async {
        let reply = "In your recent rep, the recommendation arrived after the setup, so put it first in the next practice."
        let transport = CapturingCoachTransport(completionText: reply)
        let service = AICoachChatService(secureTransport: transport)

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "What should I fix first?")],
            systemPrompt: "Coach only from available evidence.",
            userContext: "RECENT (most-recent first)\nThe recommendation arrived after the setup.",
            turnDepth: .quickMove,
            preferredTier: .geminiFast
        )

        guard case .reply(let landed) = outcome else {
            Issue.record("The grounded compatibility repair was rejected by the client gate")
            return
        }
        #expect(landed == reply)
    }

    @MainActor
    @Test func secureGroundedBriefFallbackPassesTheClientGate() async {
        let reply = "Put the recommendation first in the next practice because the recent rep placed the setup before the recommendation."
        let transport = CapturingCoachTransport(
            completionText: reply,
            generationMode: .deterministicBrief
        )
        let service = AICoachChatService(secureTransport: transport)
        var landedChoice: CoachTurnProviderChoice?

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "What should I fix first?")],
            systemPrompt: "Coach only from available evidence.",
            userContext: "RECENT (most-recent first)\nThe recent rep placed the setup before the recommendation.",
            turnDepth: .quickMove,
            preferredTier: .geminiFast,
            onProviderChosen: { landedChoice = $0 }
        )

        guard case .reply(let landed) = outcome else {
            Issue.record("The deterministic grounded brief was rejected by the client gate")
            return
        }
        #expect(landed == reply)
        #expect(landedChoice?.providerName == "Noum deterministic coach")
        #expect(landedChoice?.generationMode == .deterministicBrief)
    }

    @Test func injectedAvailabilityPreservesTypedFailureReason() async {
        let service = AICoachChatService(secureTransport: StubCoachTransport(
            availabilityState: .unavailable(.service),
            events: []
        ))
        #expect(await service.availability() == .unavailable(.service))
    }

    @MainActor
    @Test func secureTurnPerformsOneCapabilityPreflight() async {
        let transport = CapturingCoachTransport()
        let service = AICoachChatService(secureTransport: transport)

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "What should I fix first?")],
            systemPrompt: "Coach only from available evidence.",
            userContext: "RECENT (most-recent first)\nThe setup came before the recommendation.",
            turnDepth: .quickMove
        )

        guard case .reply = outcome else {
            Issue.record("The counted secure turn did not complete")
            return
        }
        let calls = transport.callCounts()
        #expect(calls.availability == 1)
        #expect(calls.stream == 1)
    }

    @MainActor
    @Test func secureTurnPreservesCapabilityFailureReason() async {
        let service = AICoachChatService(secureTransport: StubCoachTransport(
            availabilityState: .unavailable(.backendVersionMissing),
            events: []
        ))

        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "How do I structure an update?")],
            systemPrompt: "Coach communication craft.",
            userContext: "No personal evidence requested."
        )

        guard case .failure(.coachUnavailable(.backendVersionMissing)) = outcome else {
            Issue.record("The capability reason was collapsed during send")
            return
        }
    }

    #if canImport(FirebaseFunctions)
    @Test func callableContractFailuresDoNotMasqueradeAsNetworkOutages() {
        #expect(FirebaseCoachChatTransport.mapFunctionsErrorCode(
            .invalidArgument
        ) == .invalidRequest)
        #expect(FirebaseCoachChatTransport.mapFunctionsErrorCode(
            .failedPrecondition,
            reason: "coach-quality-rejected"
        ) == .qualityRejected)
        #expect(FirebaseCoachChatTransport.mapFunctionsErrorCode(
            .failedPrecondition
        ) == .network)
        #expect(FirebaseCoachChatTransport.mapFunctionsErrorCode(
            .permissionDenied
        ) == .permissionDenied)
        #expect(FirebaseCoachChatTransport.mapStreamError(
            CoachChatTransportError.unauthenticated
        ) == .unauthenticated)
        #expect(FirebaseCoachChatTransport.mapStreamError(
            CoachChatTransportError.invalidResponse
        ) == .invalidResponse)
    }
    #endif

    @MainActor
    @Test func invalidSecureCompletionBecomesAnIncompleteRead() async {
        let service = AICoachChatService(
            secureTransport: FailingCoachTransport(error: .invalidResponse)
        )
        let outcome = await service.reply(
            history: [CoachMessage(role: .user, text: "What should I fix first?")],
            systemPrompt: "Coach the next observable move.",
            userContext: "Evidence remains early."
        )

        guard case .failure(.empty) = outcome else {
            Issue.record("Invalid secure output was mislabeled as a network outage")
            return
        }
        #expect(AskNoumStore.noticeCopy(for: .empty).contains("couldn’t complete"))
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

private struct FailingCoachTransport: CoachChatTransport {
    let error: CoachChatTransportError

    func availability() async -> CoachChatTransportAvailability { .available }

    func stream(_ request: CoachChatRequest) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
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
    private var availabilityCalls = 0
    private var streamCalls = 0
    private let completionTierOverride: String?
    private let completionText: String
    private let completionTextProvider: ((CoachChatRequest) -> String)?
    private let generationMode: CoachChatGenerationMode?

    init(
        completionTierOverride: String? = nil,
        completionText: String = "Put the recommendation first in the next practice, because it currently arrives after the setup.",
        generationMode: CoachChatGenerationMode? = .model,
        completionTextProvider: ((CoachChatRequest) -> String)? = nil
    ) {
        self.completionTierOverride = completionTierOverride
        self.completionText = completionText
        self.completionTextProvider = completionTextProvider
        self.generationMode = generationMode
    }

    func availability() async -> CoachChatTransportAvailability {
        recordAvailabilityCall()
        return .available
    }

    func stream(_ request: CoachChatRequest) throws -> AsyncThrowingStream<CoachChatEvent, Error> {
        lock.lock()
        self.request = request
        streamCalls += 1
        lock.unlock()
        let model = request.qualityTier == "ultra" ? "gemini-2.5-pro" : "gemini-2.5-flash"
        let completion = CoachChatCompletion(
            requestID: request.requestID,
            text: completionTextProvider?(request) ?? completionText,
            model: model,
            qualityTier: completionTierOverride ?? request.qualityTier,
            finishReason: "STOP",
            inputTokens: 40,
            outputTokens: 12,
            policyVersion: "noum-coach-v2",
            generationMode: generationMode
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

    func callCounts() -> (availability: Int, stream: Int) {
        lock.lock()
        defer { lock.unlock() }
        return (availabilityCalls, streamCalls)
    }

    private func recordAvailabilityCall() {
        lock.lock()
        availabilityCalls += 1
        lock.unlock()
    }

    func model(for tier: CoachProviderTier) -> String {
        tier == .claudeReasoning ? "gemini-2.5-pro" : "gemini-2.5-flash"
    }
}

@MainActor
@Suite("Typed coach evidence pipeline wire", .serialized)
struct TypedCoachEvidencePipelineWireTests {
    @Test func evidenceFlowsFromSessionsThroughPipelineAndSecureWire() async throws {
        let now = Date(timeIntervalSince1970: 1_780_000_000)
        func session(
            id: UUID = UUID(),
            daysAgo: Int,
            score: Int,
            fillers: Int
        ) -> PracticeSession {
            PracticeSession(
                id: id,
                transcript: Array(repeating: "word", count: 120)
                    .joined(separator: " "),
                fillerWordCount: fillers,
                duration: 60,
                date: now.addingTimeInterval(-Double(daysAgo) * 86_400),
                mode: .ahCounter,
                score: score,
                transcriptConfidence: 0.90,
                comparisonMetricSchemaVersion:
                    PracticeSession.currentComparisonMetricSchemaVersion,
                isEvaluationFixture: false
            )
        }

        let latestID = UUID()
        let firstPriorID = UUID()
        let secondPriorID = UUID()
        let latest = session(id: latestID, daysAgo: 0, score: 8, fillers: 3)
        let firstPrior = session(
            id: firstPriorID,
            daysAgo: 1,
            score: 7,
            fillers: 4
        )
        let secondPrior = session(
            id: secondPriorID,
            daysAgo: 2,
            score: 7,
            fillers: 5
        )

        struct Fixture {
            let turn: String
            let sessions: [PracticeSession]
            let expectedKind: CoachEvidenceReadKind
        }
        let fixtures = [
            Fixture(
                turn: "How many fillers did I use?",
                sessions: [latest],
                expectedKind: .latestRepMetrics
            ),
            Fixture(
                turn: "Am I improving?",
                sessions: [latest, firstPrior, secondPrior],
                expectedKind: .longitudinalTrend
            ),
        ]

        for fixture in fixtures {
            let suiteName = "CoachTypedEvidencePipelineTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defaults.removePersistentDomain(forName: suiteName)
            defer { defaults.removePersistentDomain(forName: suiteName) }
            CoachAssessmentCache.shared.invalidate()
            UserTrajectoryCache.shared.invalidate()

            let store = AskNoumStore(
                defaults: defaults,
                accountIDProvider: { "pipeline-typed-evidence" }
            )
            let ids = store.appendUserTurn(fixture.turn)
            let transport = CapturingCoachTransport(
                generationMode: .deterministicBrief,
                completionTextProvider: { request in
                    request.coachingBrief?.directVerdict ?? "Missing typed brief."
                }
            )
            let service = AICoachChatService(secureTransport: transport)

            let outcome = await CoachReplyPipeline.generate(
                coachID: ids.coachID,
                store: store,
                coachService: service,
                judgementPassEnabled: true,
                realtimeCoachModeEnabled: true,
                sessionsOverride: fixture.sessions,
                coachMemoryOverride: { nil }
            )

            let request = try #require(transport.capturedRequest())
            let brief = try #require(request.coachingBrief)
            #expect(request.responseKind ==
                CoachChatResponseKind.personalEvidenceRead.rawValue)
            #expect(brief.evidenceReadKind == fixture.expectedKind)
            #expect(brief.nextMove == nil)
            #expect(AICoachChatService.replyQualityIssue(
                in: brief.directVerdict,
                latestUserTurn: fixture.turn,
                turnDepth: TurnDepthClassifier.classify(userText: fixture.turn),
                responseKind: .personalEvidenceRead,
                coachingBrief: brief
            ) == nil)
            let encoded = try JSONEncoder().encode(request)
            let object = try #require(JSONSerialization.jsonObject(
                with: encoded
            ) as? [String: Any])
            let wireBrief = try #require(
                object["coachingBrief"] as? [String: Any]
            )
            #expect(wireBrief["evidenceReadKind"] as? String ==
                fixture.expectedKind.rawValue)

            switch fixture.expectedKind {
            case .latestRepMetrics:
                #expect(brief.requestedMetrics == [.fillerCount])
                #expect(brief.latestRepMetrics?.sourceSessionID == latestID)
                #expect(brief.latestRepMetrics?.fillerCount == 3)
                #expect(brief.longitudinalTrend == nil)
                #expect(wireBrief["requestedMetrics"] as? [String] == [
                    CoachMetricKind.fillerCount.rawValue
                ])
                #expect(wireBrief["latestRepMetrics"] != nil)
                #expect(wireBrief["longitudinalTrend"] == nil)
            case .longitudinalTrend:
                #expect(brief.requestedMetrics == nil)
                #expect(brief.latestRepMetrics == nil)
                #expect(brief.longitudinalTrend?.sourceSessionID == latestID)
                #expect(Set(
                    brief.longitudinalTrend?.comparableSessionIDs ?? []
                ) == Set([firstPriorID, secondPriorID]))
                #expect(brief.longitudinalTrend?.metrics.isEmpty == false)
                #expect(wireBrief["requestedMetrics"] == nil)
                #expect(wireBrief["latestRepMetrics"] == nil)
                #expect(wireBrief["longitudinalTrend"] != nil)
            }

            guard case .reply(let landed) = outcome else {
                Issue.record("Typed evidence pipeline failed for \(fixture.turn)")
                continue
            }
            #expect(landed == brief.directVerdict)
            #expect(!landed.lowercased().contains("drill"))
            #expect(!landed.lowercased().contains("qualified"))
        }
    }

    // Resets the process-global `FlowEventLog.shared`, which a concurrently
    // running suite also asserts on. `.serialized` does not order across suites,
    // so exclusive access has to be held for the whole body. See
    // `FlowEventLogTestGate`. The body is extracted verbatim so the gate can wrap
    // it without re-indenting the assertions.
    @Test func detailedThreeThousandCharacterTurnReachesProviderAndCommitsOneTerminalReply() async throws {
        try await FlowEventLogTestGate.shared.withExclusiveAccess {
            try await detailedThreeThousandCharacterTurnBody()
        }
    }

    private func detailedThreeThousandCharacterTurnBody() async throws {
        let suiteName = "CoachLongPromptPipelineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        FlowEventLog.shared.reset()
        defer { FlowEventLog.shared.reset() }
        CoachAssessmentCache.shared.invalidate()
        UserTrajectoryCache.shared.invalidate()

        let opening = "I need help preparing a leadership update. Recommend whether we delay by two weeks. "
        let ending = " Existing beta users remain exposed; keep customer demos on a controlled build and give support one message today."
        let paddingCount = 3_000 - opening.count - ending.count
        let middle = String(String(repeating: "Operational context remains relevant. ", count: 120).prefix(paddingCount))
        let turn = opening + middle + ending
        #expect(turn.count == 3_000)
        #expect(CoachChatTurnIntent.classify(turn) == .coaching)
        #expect(CoachChatResponseKind.classify(turn) == .generalCoaching)
        #expect(TurnDepthClassifier.classify(userText: turn) == .quickMove)

        let landedReply = "Recommend the two-week delay first because existing beta users remain exposed. Keep the demos on a controlled build and give support one message today."
        let store = AskNoumStore(
            defaults: defaults,
            accountIDProvider: { "pipeline-long-prompt" }
        )
        let ids = store.appendUserTurn(turn)
        let transport = CapturingCoachTransport(completionText: landedReply)
        let service = AICoachChatService(secureTransport: transport)
        var gateEvents: [CoachTurnQualityGateEvent] = []

        let outcome = await CoachReplyPipeline.generate(
            coachID: ids.coachID,
            store: store,
            coachService: service,
            judgementPassEnabled: true,
            realtimeCoachModeEnabled: true,
            sessionsOverride: [],
            coachMemoryOverride: { nil },
            onQualityGateEvent: { gateEvents.append($0) }
        )

        let request = try #require(transport.capturedRequest())
        #expect(request.messages.last == CoachChatWireMessage(role: .user, content: turn))
        #expect(request.responseKind == CoachChatResponseKind.generalCoaching.rawValue)
        #expect(request.turnDepth == CoachTurnDepth.quickMove.rawValue)
        guard case .reply(let reply) = outcome else {
            Issue.record("Long prompt did not finish with a live reply: \(gateEvents)")
            return
        }
        #expect(reply == landedReply)
        #expect(gateEvents == [.passed])

        let committed = try #require(store.messages.first(where: { $0.id == ids.coachID }))
        #expect(!committed.isPending)
        #expect(committed.role == .coach)
        #expect(committed.text == landedReply)
        #expect(committed.metadata?.traceID == ids.coachID)
        #expect((committed.metadata?.providerAttemptCount ?? 0) >= 1)
        #expect(committed.metadata?.qualityGateOutcome != nil)
        #expect((committed.metadata?.timeToCompleteReplyMs ?? -1) >= 0)
        #expect(committed.metadata?.terminalState == .accepted)

        let trace = try #require(FlowEventLog.shared.recentCoachTraces(limit: 20)
            .first(where: { $0.correlationId == ids.coachID }))
        let orderedStages = trace.events.map(\.stage)
        let stages = Set(orderedStages)
        for expectedStage in [
            CoachTraceStage.accepted,
            CoachTraceStage.classified,
            CoachTraceStage.providerStarted,
            CoachTraceStage.finalSanitized,
            CoachTraceStage.persisted,
            CoachTraceStage.uiCommitted,
            CoachTraceStage.terminal,
        ] {
            #expect(stages.contains(expectedStage), "Missing trace stage \(expectedStage)")
        }
        let semanticPath = [
            CoachTraceStage.classified,
            CoachTraceStage.goalResolved,
            CoachTraceStage.memoryLoaded,
            CoachTraceStage.evidenceLoaded,
            CoachTraceStage.rubricSelected,
            CoachTraceStage.promptAssembled,
        ]
        let semanticIndexes = try semanticPath.map { stage in
            try #require(orderedStages.firstIndex(of: stage), "Missing trace stage \(stage)")
        }
        #expect(semanticIndexes == semanticIndexes.sorted())
        #expect(CoachTraceStage.all.isSuperset(of: [
            CoachTraceStage.streamFirstBuffered,
            CoachTraceStage.streamFirstVisible,
        ]))
        let classified = try #require(trace.events.first(where: { $0.stage == CoachTraceStage.classified }))
        #expect(classified.numerics["userCharacters"] == 3_000)
        #expect(trace.terminalState == .accepted)
        #expect(trace.terminalEventCount == 1)
        #expect((trace.latencyMs ?? -1) >= 0)
    }
}

@Suite("Production copy contracts")
struct ProductionCopyContractTests {
    @MainActor
    @Test func infrastructureFailuresNeverSendUsersToSettings() {
        let failures: [ChatFailure] = [
            .noProvider, .unauthenticated, .rateLimited, .network,
            .cancelled, .timedOut, .empty, .contentRejected,
            .invalidRequest, .permissionDenied,
            .backendVersionMissing, .coachUnavailable(.backendVersionMissing)
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
