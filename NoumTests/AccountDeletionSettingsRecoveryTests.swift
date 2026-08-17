import Foundation
import Testing
@testable import Noum

@Suite("Account deletion Settings recovery")
struct AccountDeletionSettingsRecoveryTests {
    @Test("Ambiguous completion exposes support-only recovery")
    func ambiguousCompletionIsSupportOnly() {
        for error in [
            AccountDeletionError.completionUncertain,
            .completionUncertainRequiresReauthentication
        ] {
            let presentation = AccountDeletionConfirmationPresentation.resolve(
                after: error
            )

            #expect(presentation == .supportOnly)
            #expect(!presentation.allowsDestructiveConfirmation)
            #expect(presentation.dismissButtonTitle == "Close")
            #expect(
                presentation.dismissAccessibilityHint
                    .localizedCaseInsensitiveContains("deletion support")
            )
        }

        #expect(
            AccountDeletionConfirmationPresentation.initialError(
                from: .failed(.completionUncertain)
            ) == .completionUncertain
        )
        #expect(
            AccountDeletionConfirmationPresentation.initialError(from: .idle)
                == nil
        )
    }

    @Test("Definitive and preflight failures retain the confirmation path")
    func recoverableFailuresRemainActionable() {
        let recoverableErrors: [AccountDeletionError?] = [
            nil,
            .noActiveAccount,
            .deletionAlreadyInProgress,
            .safeToRetry,
            .requiresRecentAuthentication,
            .appleRevocationUnavailable,
            .secureDataUpgradeIncomplete,
            .serviceUnavailable,
            .remoteRejected
        ]

        for error in recoverableErrors {
            let presentation = AccountDeletionConfirmationPresentation.resolve(
                after: error
            )

            #expect(presentation == .confirmation)
            #expect(presentation.allowsDestructiveConfirmation)
            #expect(presentation.dismissButtonTitle == "Cancel")
            #expect(
                !presentation.dismissAccessibilityHint
                    .localizedCaseInsensitiveContains("deletion support")
            )
        }

        let localCleanup = AccountDeletionConfirmationPresentation.resolve(
            after: .localCleanupFailed
        )
        #expect(localCleanup == .localCleanup)
        #expect(localCleanup.allowsDestructiveConfirmation)
        #expect(!localCleanup.requiresTypedConfirmation)
        #expect(localCleanup.actionIsEnabled(matchesRequiredPhrase: false))
        #expect(localCleanup.primaryActionTitle == "Finish device cleanup")
        #expect(localCleanup.primaryActionAccessibilityHint
            .localizedCaseInsensitiveContains("without sending another remote"))
    }

    @Test("Durable phases expose only their safe recovery action")
    func durablePhasesDriveRecovery() {
        #expect(AuthManager.accountDeletionRecoveryError(for: .admissionClosed)
            == .safeToRetry)
        #expect(AuthManager.accountDeletionRecoveryError(for: .remoteRequested)
            == .completionUncertain)
        #expect(AuthManager.accountDeletionRecoveryError(for: .remoteCommitted)
            == .localCleanupFailed)
        #expect(AuthManager.accountDeletionRecoveryError(for: .localCleanupStarted)
            == .localCleanupFailed)

        let retainedCleanup = AuthManager.accountDeletionError(
            for: .localCleanupFailed,
            disposition: .retainFenceAndKeepProviderWorkSuspended,
            persistedPhase: .localCleanupStarted
        )
        #expect(retainedCleanup == .localCleanupFailed)
        #expect(!retainedCleanup.localizedDescription
            .localizedCaseInsensitiveContains("support"))
        #expect(retainedCleanup.localizedDescription
            .localizedCaseInsensitiveContains("only local cleanup"))
    }

    @Test("Deletion support mail carries an opaque server correlation reference")
    func deletionSupportMailCarriesCorrelationReference() throws {
        let requestID = UUID(uuidString: "C56A4180-65AA-42EC-A945-5FD21DEC0538")!
        let url = NoumWebURLs.deletionSupportMail(
            requestReference: requestID.uuidString,
            phase: AccountDeletionFencePhase.remoteRequested.rawValue
        )
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
            ($0.name, $0.value ?? "")
        })

        #expect(components.scheme == "mailto")
        #expect(components.path == NoumWebURLs.supportEmail)
        #expect(query["subject"] == "Noum account deletion support")
        #expect(query["body"]?.contains(requestID.uuidString) == true)
        #expect(query["body"]?.contains("remoteRequested") == true)
        #expect(query["body"]?.localizedCaseInsensitiveContains("transcripts") == true)
    }

    @Test("Settings restores durable deletion recovery when the sheet reopens")
    func settingsSheetReceivesDurableDeletionState() throws {
        let testsDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let repositoryRoot = testsDirectory.deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("Noum/SettingsView.swift"),
            encoding: .utf8
        )

        #expect(source.contains(
            "from: authManager.accountDeletionState"
        ))
        #expect(source.contains(
            "supportURLProvider: {"
        ))
        #expect(source.contains(
            "authManager.accountDeletionSupportURL"
        ))
        #expect(source.contains(
            "Link(\"Contact deletion support\", destination: supportURLProvider())"
        ))
        #expect(source.contains(
            "content-free deletion-security record"
        ))
        #expect(source.contains(
            "automatic cleanup and server reconciliation manage that record"
        ))
    }
}
