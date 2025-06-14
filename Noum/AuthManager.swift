import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import AWSCore

@MainActor
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()
    @Published var isSignedIn: Bool = false
    private let credentialsProvider: AWSCognitoCredentialsProvider

    override private init() {
        let env = ProcessInfo.processInfo.environment
        var regionString = env["AWS_REGION"]
        var pool = env["COGNITO_IDENTITY_POOL_ID"]

        if regionString == nil || pool == nil {
            if let url = Bundle.main.url(forResource: "Transcribe", withExtension: "plist"),
               let data = try? Data(contentsOf: url),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                if regionString == nil { regionString = plist?["AWS_REGION"] as? String }
                if pool == nil { pool = plist?["COGNITO_IDENTITY_POOL_ID"] as? String }
            }
        }

        let region = AWSRegionType(rawValue: regionString ?? "eu-west-2") ?? .EUWest2
        credentialsProvider = AWSCognitoCredentialsProvider(regionType: region, identityPoolId: pool ?? "")
        super.init()
        AWSServiceManager.default().defaultServiceConfiguration = AWSServiceConfiguration(region: region, credentialsProvider: credentialsProvider)
    }

    func currentCredentials() async throws -> (accessKey: String, secretKey: String, sessionToken: String?) {
        let cred = try await credentialsProvider.getIdentityId()
        _ = cred // avoid unused
        let credentials = try await withCheckedThrowingContinuation { continuation in
            credentialsProvider.getCredentials { creds, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let c = creds {
                    continuation.resume(returning: c)
                }
            }
        }
        self.isSignedIn = true
        return (credentials.accessKey, credentials.secretKey, credentials.sessionKey)
    }

    func signInWithGoogle(presenting viewController: UIViewController) {
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
            if let token = result?.user.idToken?.tokenString, error == nil {
                self.credentialsProvider.logins = ["accounts.google.com": token]
                Task { try? await self.credentialsProvider.refresh() }
                self.isSignedIn = true
            }
        }
        #endif
    }

    func signInWithApple() {
        #if canImport(AuthenticationServices)
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
        #endif
    }

    func signOut() {
        credentialsProvider.logins = nil
        credentialsProvider.clearKeychain() // remove cached creds
        isSignedIn = false
    }
}

#if canImport(AuthenticationServices)
extension AuthManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
           let tokenData = appleIDCredential.identityToken,
           let token = String(data: tokenData, encoding: .utf8) {
            credentialsProvider.logins = ["appleid.apple.com": token]
            Task { try? await credentialsProvider.refresh() }
            self.isSignedIn = true
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        // handle error
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if canImport(UIKit)
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
#endif
