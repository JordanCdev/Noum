import Foundation
#if canImport(AuthenticationServices) && canImport(CryptoKit) && canImport(Security) && canImport(UIKit)
import AuthenticationServices
import CryptoKit
import Security
import UIKit
#endif

/// Provider credential material captured only for the account-deletion
/// authorization boundary. Nothing is persisted and the authorization code is
/// consumed exactly once by Firebase Auth's revocation endpoint.
struct AppleAccountDeletionCredential: Equatable, Sendable {
    let providerID: String
    let identityToken: String?
    let authorizationCode: String?
    let rawNonce: String?
}

/// Typed, content-free failures for the pre-deletion Apple authorization gate.
/// Every case is known to occur before Noum's durable deletion fence begins.
enum AppleAccountDeletionAuthorizationError: Error, Equatable, Sendable {
    case cancelled
    case missingIdentityToken
    case missingAuthorizationCode
    case providerMismatch
    case authorizationFailed
    case reauthenticationFailed
    case revocationFailed
}

enum AppleAccountDeletionAuthorizationDisposition: Equatable, Sendable {
    /// No durable deletion exists, so an Apple-linked identity must obtain and
    /// revoke a fresh authorization before admission can be published.
    case acquireFresh
    /// This exact account/provider already has a verified durable fence. The
    /// fence could only be created after the revocation gate completed.
    case resumeVerifiedFence(appleAuthorizationRevoked: Bool)
    /// Unreadable or mismatched durable state must reach the existing
    /// fail-closed fence recovery without prompting Apple or contacting the
    /// deletion backend.
    case failClosed
}

/// Pure orchestration for Apple's deletion-specific authorization sequence.
/// SDK objects stay in `AuthManager`; this gate owns ordering and fail-closed
/// behavior so cancellation and transport failures can be tested without live
/// Apple or Firebase accounts.
enum AppleAccountDeletionAuthorizationGate {
    static let providerID = "apple.com"

    static func isRequired(linkedProviderIDs: [String]) -> Bool {
        linkedProviderIDs.contains(providerID)
    }

    static func trimmedCredentialValue(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @MainActor
    static func authorizeAndRevoke(
        expectedAccountID: String,
        linkedProviderIDs: [String],
        acquireCredential: () async throws -> AppleAccountDeletionCredential,
        reauthenticate: (AppleAccountDeletionCredential) async throws -> String,
        revokeAuthorizationCode: (String) async throws -> Void
    ) async throws {
        guard isRequired(linkedProviderIDs: linkedProviderIDs) else { return }

        let credential: AppleAccountDeletionCredential
        do {
            credential = try await acquireCredential()
        } catch let error as AppleAccountDeletionAuthorizationError {
            throw error
        } catch {
            throw AppleAccountDeletionAuthorizationError.authorizationFailed
        }

        guard credential.providerID == providerID else {
            throw AppleAccountDeletionAuthorizationError.providerMismatch
        }
        guard trimmedCredentialValue(credential.identityToken) != nil,
              trimmedCredentialValue(credential.rawNonce) != nil else {
            throw AppleAccountDeletionAuthorizationError.missingIdentityToken
        }
        guard let authorizationCode = trimmedCredentialValue(
            credential.authorizationCode
        ) else {
            throw AppleAccountDeletionAuthorizationError.missingAuthorizationCode
        }

        let reauthenticatedAccountID: String
        do {
            reauthenticatedAccountID = try await reauthenticate(credential)
        } catch let error as AppleAccountDeletionAuthorizationError {
            throw error
        } catch {
            throw AppleAccountDeletionAuthorizationError.reauthenticationFailed
        }
        guard reauthenticatedAccountID == expectedAccountID else {
            throw AppleAccountDeletionAuthorizationError.providerMismatch
        }

        do {
            try await revokeAuthorizationCode(authorizationCode)
        } catch let error as AppleAccountDeletionAuthorizationError {
            throw error
        } catch {
            throw AppleAccountDeletionAuthorizationError.revocationFailed
        }
    }
}

#if canImport(AuthenticationServices) && canImport(CryptoKit) && canImport(Security) && canImport(UIKit)
@MainActor
final class AppleAccountDeletionAuthorizationRequest: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private let presentationAnchor: ASPresentationAnchor
    private let rawNonce: String
    private let controller: ASAuthorizationController
    private var continuation:
        CheckedContinuation<AppleAccountDeletionCredential, Error>?
    private var terminalResult: Result<AppleAccountDeletionCredential, Error>?

    static func activePresentationAnchor() -> ASPresentationAnchor? {
        let scenes = UIApplication.shared.connectedScenes.compactMap {
            $0 as? UIWindowScene
        }.filter { $0.activationState == .foregroundActive }
        return scenes.lazy.compactMap { scene in
            scene.windows.first(where: \.isKeyWindow) ?? scene.windows.first
        }.first
    }

    init(presentationAnchor: ASPresentationAnchor) throws {
        self.presentationAnchor = presentationAnchor
        rawNonce = try Self.secureNonce()

        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.nonce = Self.sha256(rawNonce)
        controller = ASAuthorizationController(authorizationRequests: [request])
        super.init()
        controller.delegate = self
        controller.presentationContextProvider = self
    }

    func credential() async throws -> AppleAccountDeletionCredential {
        if let terminalResult {
            return try terminalResult.get()
        }
        guard continuation == nil else {
            throw AppleAccountDeletionAuthorizationError.authorizationFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        presentationAnchor
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let appleCredential =
                authorization.credential as? ASAuthorizationAppleIDCredential else {
            finish(.failure(
                AppleAccountDeletionAuthorizationError.providerMismatch
            ))
            return
        }

        let identityToken = appleCredential.identityToken.flatMap {
            String(data: $0, encoding: .utf8)
        }
        let authorizationCode = appleCredential.authorizationCode.flatMap {
            String(data: $0, encoding: .utf8)
        }
        finish(.success(AppleAccountDeletionCredential(
            providerID: AppleAccountDeletionAuthorizationGate.providerID,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            rawNonce: rawNonce
        )))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        if let authorizationError = error as? ASAuthorizationError,
           authorizationError.code == .canceled {
            finish(.failure(
                AppleAccountDeletionAuthorizationError.cancelled
            ))
        } else {
            finish(.failure(
                AppleAccountDeletionAuthorizationError.authorizationFailed
            ))
        }
    }

    private func finish(
        _ result: Result<AppleAccountDeletionCredential, Error>
    ) {
        guard terminalResult == nil else { return }
        terminalResult = result
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(with: result)
    }

    private static func secureNonce(length: Int = 32) throws -> String {
        precondition(length > 0)
        let characterSet = Array(
            "0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._"
        )
        var result = ""
        result.reserveCapacity(length)

        while result.count < length {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            guard status == errSecSuccess else {
                throw AppleAccountDeletionAuthorizationError
                    .authorizationFailed
            }
            guard random < characterSet.count else { continue }
            result.append(characterSet[Int(random)])
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map {
            String(format: "%02x", $0)
        }.joined()
    }
}
#endif
