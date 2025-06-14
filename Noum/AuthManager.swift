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

private let regionType = ((ProcessInfo.processInfo.environment["AWS_REGION"] ?? "eu-west-2") as NSString).aws_regionTypeValue()
private let identityPoolId = ProcessInfo.processInfo.environment["AWS_IDENTITY_POOL_ID"] ?? "eu-west-2:b72cffc1-2949-4be0-80b5-df2713295f9e"

/// Authentication manager that loads AWS credentials from environment variables
/// or a bundled `Transcribe.plist` file. Google or Apple sign-in actions are
/// stubbed so the code compiles on non-Apple platforms used for testing.

@MainActor
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()
    @Published var isSignedIn: Bool = false
    private(set) var credentialsProvider: AWSCredentialsProvider?

    private let cognitoProvider = AWSCognitoCredentialsProvider(regionType: regionType,
                                                                identityPoolId: identityPoolId)

    /// Load AWS credentials from environment variables or Transcribe.plist.
    private func loadCredentials() {
        let env = ProcessInfo.processInfo.environment
        var accessKey = env["AWS_ACCESS_KEY_ID"]
        var secretKey = env["AWS_SECRET_ACCESS_KEY"]
        var token = env["AWS_SESSION_TOKEN"]

        #if canImport(Foundation)
        if (accessKey == nil || secretKey == nil),
           let url = Bundle.main.url(forResource: "Transcribe", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            if accessKey == nil { accessKey = plist["AWS_ACCESS_KEY_ID"] as? String }
            if secretKey == nil { secretKey = plist["AWS_SECRET_ACCESS_KEY"] as? String }
            if token == nil { token = plist["AWS_SESSION_TOKEN"] as? String }
        }
        #endif

        if let a = accessKey, let s = secretKey {
            credentialsProvider = AWSStaticCredentialsProvider(accessKey: a, secretKey: s)
            isSignedIn = true
        }
    }

    /// Ensure credentials are loaded or throw an error.
    func currentCredentials() async throws {
        if credentialsProvider == nil { loadCredentials() }
        if credentialsProvider == nil {
            struct CredError: LocalizedError { var errorDescription: String? { "Missing AWS credentials" } }
            throw CredError()
        }
    }

    override private init() {
        super.init()
    }

    // MARK: - Sign in/out stubs
    #if canImport(UIKit) && canImport(GoogleSignIn)
    func signInWithGoogle(presenting viewController: UIViewController) {
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { _, _ in
            self.loadCredentials()
        }
    }
    #else
    func signInWithGoogle(presenting viewController: Any? = nil) {
        // On platforms without GoogleSignIn simply load credentials from environment
        loadCredentials()
    }
    #endif

    func signInWithApple() {
            #if canImport(AuthenticationServices)
            let provider = ASAuthorizationAppleIDProvider()
            let request = provider.createRequest()
            request.requestedScopes = []  // e.g. [.fullName, .email] if you need them
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self  // provide window for presentation if needed
            controller.performRequests()
            #else
            // Non-UI platforms: no action
            #endif
    }
    
    func signOut() {
        if let cognito = credentialsProvider as? AWSCognitoCredentialsProvider {
            cognito.clearCredentials()
            cognito.clearKeychain()
        }
        credentialsProvider = nil
        isSignedIn = false
    }
}

#if canImport(AuthenticationServices)
extension AuthManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        loadCredentials()
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple sign-in failed: \(error.localizedDescription)")
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
#if canImport(UIKit)
        return UIApplication.shared.windows.first ?? UIWindow()
#elseif canImport(AppKit)
        return NSApplication.shared.windows.first ?? NSWindow()
#else
        return ASPresentationAnchor()
#endif
    }
}
#endif

