import Foundation
import Testing
@testable import Noum

@MainActor
@Suite("Apple account deletion authorization")
struct AppleAccountDeletionAuthorizationTests {
    private enum FixtureError: Error {
        case failed
    }

    private let accountID = "firebase-user-a"

    @Test("Only an Apple-linked Firebase identity requires revocation")
    func requirementUsesLinkedProviders() {
        #expect(!AppleAccountDeletionAuthorizationGate.isRequired(
            linkedProviderIDs: ["google.com", "password"]
        ))
        #expect(AppleAccountDeletionAuthorizationGate.isRequired(
            linkedProviderIDs: ["google.com", "apple.com"]
        ))
    }

    @Test("Only a missing fence acquires a new Apple authorization")
    func durableFenceDisposition() {
        let fence = AccountDeletionFence(
            accountID: accountID,
            providerRawValue: AuthProvider.apple.rawValue,
            appleAuthorizationRevoked: true,
            requestID: UUID(),
            phase: .admissionClosed
        )
        #expect(AuthManager.appleDeletionAuthorizationDisposition(
            fenceLookup: .missing,
            accountID: accountID,
            providerRawValue: AuthProvider.apple.rawValue
        ) == .acquireFresh)
        #expect(AuthManager.appleDeletionAuthorizationDisposition(
            fenceLookup: .present(fence),
            accountID: accountID,
            providerRawValue: AuthProvider.apple.rawValue
        ) == .resumeVerifiedFence(appleAuthorizationRevoked: true))
        #expect(AuthManager.appleDeletionAuthorizationDisposition(
            fenceLookup: .present(fence),
            accountID: accountID,
            providerRawValue: AuthProvider.google.rawValue
        ) == .failClosed)
        #expect(AuthManager.appleDeletionAuthorizationDisposition(
            fenceLookup: .ambiguous,
            accountID: accountID,
            providerRawValue: AuthProvider.apple.rawValue
        ) == .failClosed)
    }

    @Test("Cancellation stops before reauthentication or revocation")
    func cancellationFailsClosed() async {
        var calls: [String] = []
        let error = await captureError {
            try await AppleAccountDeletionAuthorizationGate.authorizeAndRevoke(
                expectedAccountID: accountID,
                linkedProviderIDs: ["apple.com"],
                acquireCredential: {
                    calls.append("acquire")
                    throw AppleAccountDeletionAuthorizationError.cancelled
                },
                reauthenticate: { _ in
                    calls.append("reauthenticate")
                    return self.accountID
                },
                revokeAuthorizationCode: { _ in
                    calls.append("revoke")
                }
            )
        }

        #expect(error == .cancelled)
        #expect(calls == ["acquire"])
        #expect(AuthManager.accountDeletionError(for: .cancelled) == .safeToRetry)
    }

    @Test("A missing authorization code cannot enter Firebase")
    func missingCodeFailsClosed() async {
        var calls: [String] = []
        let error = await captureError {
            try await AppleAccountDeletionAuthorizationGate.authorizeAndRevoke(
                expectedAccountID: accountID,
                linkedProviderIDs: ["apple.com"],
                acquireCredential: {
                    calls.append("acquire")
                    return credential(authorizationCode: "  \n")
                },
                reauthenticate: { _ in
                    calls.append("reauthenticate")
                    return self.accountID
                },
                revokeAuthorizationCode: { _ in
                    calls.append("revoke")
                }
            )
        }

        #expect(error == .missingAuthorizationCode)
        #expect(calls == ["acquire"])
    }

    @Test("A different provider or Firebase UID cannot be deleted")
    func providerMismatchFailsClosed() async {
        var calls: [String] = []
        var error = await captureError {
            try await AppleAccountDeletionAuthorizationGate.authorizeAndRevoke(
                expectedAccountID: accountID,
                linkedProviderIDs: ["apple.com"],
                acquireCredential: {
                    calls.append("acquire")
                    return credential(providerID: "google.com")
                },
                reauthenticate: { _ in
                    calls.append("reauthenticate")
                    return self.accountID
                },
                revokeAuthorizationCode: { _ in
                    calls.append("revoke")
                }
            )
        }
        #expect(error == .providerMismatch)
        #expect(calls == ["acquire"])

        calls = []
        error = await captureError {
            try await AppleAccountDeletionAuthorizationGate.authorizeAndRevoke(
                expectedAccountID: accountID,
                linkedProviderIDs: ["apple.com"],
                acquireCredential: {
                    calls.append("acquire")
                    return credential()
                },
                reauthenticate: { _ in
                    calls.append("reauthenticate")
                    return "firebase-user-b"
                },
                revokeAuthorizationCode: { _ in
                    calls.append("revoke")
                }
            )
        }
        #expect(error == .providerMismatch)
        #expect(calls == ["acquire", "reauthenticate"])
    }

    @Test("Firebase revocation failure retains the signed-in boundary")
    func serverFailureFailsClosed() async {
        var calls: [String] = []
        let error = await captureError {
            try await AppleAccountDeletionAuthorizationGate.authorizeAndRevoke(
                expectedAccountID: accountID,
                linkedProviderIDs: ["apple.com"],
                acquireCredential: {
                    calls.append("acquire")
                    return credential()
                },
                reauthenticate: { _ in
                    calls.append("reauthenticate")
                    return self.accountID
                },
                revokeAuthorizationCode: { code in
                    calls.append("revoke:\(code)")
                    throw FixtureError.failed
                }
            )
        }

        #expect(error == .revocationFailed)
        #expect(calls == [
            "acquire",
            "reauthenticate",
            "revoke:authorization-code"
        ])
        #expect(AuthManager.accountDeletionError(for: .revocationFailed)
            == .appleRevocationUnavailable)
    }

    @Test("Firebase reauthentication failure never reaches revocation")
    func reauthenticationFailureFailsClosed() async {
        var calls: [String] = []
        let error = await captureError {
            try await AppleAccountDeletionAuthorizationGate.authorizeAndRevoke(
                expectedAccountID: accountID,
                linkedProviderIDs: ["apple.com"],
                acquireCredential: {
                    calls.append("acquire")
                    return credential()
                },
                reauthenticate: { _ in
                    calls.append("reauthenticate")
                    throw FixtureError.failed
                },
                revokeAuthorizationCode: { _ in
                    calls.append("revoke")
                }
            )
        }

        #expect(error == .reauthenticationFailed)
        #expect(calls == ["acquire", "reauthenticate"])
    }

    @Test("Success reauthenticates before consuming the authorization code")
    func successIsStrictlyOrdered() async throws {
        var calls: [String] = []
        try await AppleAccountDeletionAuthorizationGate.authorizeAndRevoke(
            expectedAccountID: accountID,
            linkedProviderIDs: ["google.com", "apple.com"],
            acquireCredential: {
                calls.append("acquire")
                return credential()
            },
            reauthenticate: { value in
                calls.append("reauthenticate:\(value.identityToken ?? "nil")")
                return self.accountID
            },
            revokeAuthorizationCode: { code in
                calls.append("revoke:\(code)")
            }
        )

        #expect(calls == [
            "acquire",
            "reauthenticate:identity-token",
            "revoke:authorization-code"
        ])
    }

    @Test("Production wiring revokes before durable deletion admission")
    func productionWiringOrder() throws {
        let authSource = try repositorySource("Noum/AuthManager.swift")
        let deletion = try sourceSlice(
            authSource,
            from: "    func deleteCurrentAccount() async throws {",
            to: "    private func persistedDeletionRecovery("
        )
        let revocation = try #require(deletion.range(
            of: "revokeAppleAuthorizationForDeletionIfNeeded("
        ))
        let admission = try #require(deletion.range(of: ".beginOrResume("))
        let suspension = try #require(deletion.range(
            of: "AskNoumStore.shared.suspendProviderWorkForDeletion"
        ))
        #expect(revocation.lowerBound < admission.lowerBound)
        #expect(admission.lowerBound < suspension.lowerBound)
        #expect(deletion.contains("case .resumeVerifiedFence("))
        #expect(deletion.contains(
            "appleAuthorizationRevoked = persistedRevocation"
        ))
        #expect(deletion.contains(
            "appleAuthorizationRevoked: appleAuthorizationRevoked"
        ))
        #expect(deletion.contains(
            "appleAuthorizationRevoked:\n                            fence.appleAuthorizationRevoked"
        ))

        let adapter = try sourceSlice(
            authSource,
            from: "    private func revokeAppleAuthorizationForDeletionIfNeeded(",
            to: "    #if canImport(FirebaseAuth)\n    private func reauthenticateFirebaseAppleUser("
        )
        #expect(adapter.contains("user.providerData.map(\\.providerID)"))
        #expect(adapter.contains("OAuthProvider.appleCredential("))
        #expect(adapter.contains("reauthenticateFirebaseAppleUser("))
        #expect(adapter.contains("revokeFirebaseAppleAuthorization("))
        #expect(adapter.contains(".userMismatch"))

        let firebaseAdapter = try sourceSlice(
            authSource,
            from: "    private func reauthenticateFirebaseAppleUser(",
            to: "    private func deleteFirebaseUserIfNeeded("
        )
        #expect(firebaseAdapter.contains("user.reauthenticate(with: credential)"))
        #expect(firebaseAdapter.contains("Auth.auth().revokeToken("))
        #expect(firebaseAdapter.contains("withAuthorizationCode:"))

        let serverSource = try repositorySource("functions/src/index.ts")
        let serverDeletion = try sourceSlice(
            serverSource,
            from: "async function executeAccountDeletion(",
            to: "export const deleteAccount = onCall("
        )
        #expect(serverDeletion.contains("assertAppleRevocationAttested("))
        #expect(serverDeletion.contains("providerData.map"))
        #expect(serverDeletion.contains("deletionRequest"))
        let providerRead = try #require(serverDeletion.range(
            of: "user.providerData.map"
        ))
        let serverGate = try #require(serverDeletion.range(
            of: "assertAppleRevocationAttested("
        ))
        let pendingState = try #require(serverDeletion.range(
            of: "transaction.set(deletionStateRef"
        ))
        #expect(providerRead.lowerBound < serverGate.lowerBound)
        #expect(serverGate.lowerBound < pendingState.lowerBound)
    }

    private func credential(
        providerID: String = "apple.com",
        authorizationCode: String? = "authorization-code"
    ) -> AppleAccountDeletionCredential {
        AppleAccountDeletionCredential(
            providerID: providerID,
            identityToken: "identity-token",
            authorizationCode: authorizationCode,
            rawNonce: "raw-nonce"
        )
    }

    private func captureError(
        _ operation: () async throws -> Void
    ) async -> AppleAccountDeletionAuthorizationError? {
        do {
            try await operation()
            return nil
        } catch let error as AppleAccountDeletionAuthorizationError {
            return error
        } catch {
            Issue.record("Unexpected error: \(error)")
            return nil
        }
    }

    private func repositorySource(_ relativePath: String) throws -> String {
        let testFile = URL(fileURLWithPath: #filePath)
        let root = testFile.deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }

    private func sourceSlice(
        _ source: String,
        from start: String,
        to end: String
    ) throws -> String {
        let startRange = try #require(source.range(of: start))
        let endRange = try #require(
            source.range(of: end, range: startRange.upperBound..<source.endIndex)
        )
        return String(source[startRange.lowerBound..<endRange.lowerBound])
    }
}
