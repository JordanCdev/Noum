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

/// Simple credentials structure used for signing requests to Amazon Transcribe.
struct AWSCredentials {
    let accessKey: String
    let secretKey: String
    let sessionToken: String?
}

/// Authentication manager that loads AWS credentials from environment variables
/// or a bundled `Transcribe.plist` file. Google or Apple sign-in actions are
/// stubbed so the code compiles on non-Apple platforms used for testing.

@MainActor
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()
    @Published var isSignedIn: Bool = false
    private var credentials: AWSCredentials?

    override private init() {
        super.init()
    }

    /// Retrieve AWS credentials from the environment or Transcribe.plist.
    private func loadCredentials() {
        let env = ProcessInfo.processInfo.environment
        var accessKey = env["AWS_ACCESS_KEY_ID"]
        var secretKey = env["AWS_SECRET_ACCESS_KEY"]
        var token = env["AWS_SESSION_TOKEN"]

        if (accessKey == nil || secretKey == nil),
           let url = Bundle.main.url(forResource: "Transcribe", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
            if accessKey == nil { accessKey = plist["AWS_ACCESS_KEY_ID"] as? String }
            if secretKey == nil { secretKey = plist["AWS_SECRET_ACCESS_KEY"] as? String }
            if token == nil { token = plist["AWS_SESSION_TOKEN"] as? String }
        }

        if let a = accessKey, let s = secretKey {
            credentials = AWSCredentials(accessKey: a, secretKey: s, sessionToken: token)
            isSignedIn = true
        }
    }

    /// Current AWS credentials or an error if none are configured.
    func currentCredentials() async throws -> AWSCredentials {
        if credentials == nil { loadCredentials() }
        if let creds = credentials {
            return creds
        } else {
            struct CredError: LocalizedError { var errorDescription: String? { "Missing AWS credentials" } }
            throw CredError()
        }
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
        loadCredentials()
    }
    #endif

    func signInWithApple() {
        #if canImport(AuthenticationServices)
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.performRequests()
        loadCredentials()
        #else
        loadCredentials()
        #endif
    }

    func signOut() {
        credentials = nil
        isSignedIn = false
    }
}

