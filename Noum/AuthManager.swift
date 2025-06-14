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
// ... inside AuthManager:
private let regionType = (ProcessInfo.processInfo.environment["AWS_REGION"] ?? "eu-west-2" as NSString).aws_regionTypeValue()
private let identityPoolId = ProcessInfo.processInfo.environment["AWS_IDENTITY_POOL_ID"] ?? "eu-west-2:b72cffc1-2949-4be0-80b5-df2713295f9e"
private lazy var credentialsProvider = AWSCognitoCredentialsProvider(regionType: regionType, identityPoolId: identityPoolId)

/// Authentication manager that loads AWS credentials from environment variables
/// or a bundled `Transcribe.plist` file. Google or Apple sign-in actions are
/// stubbed so the code compiles on non-Apple platforms used for testing.

@MainActor
class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()
    @Published var isSignedIn: Bool = false

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
        GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
            if let result = result, error == nil {
                // Obtain the Google user’s ID token
                guard let idToken = result.user.idToken?.tokenString else {
                    print("Google sign-in succeeded but no ID token found")
                    return
                }
                // Provide the token to AWS Cognito
                self.credentialsProvider.logins = [ AWSCognitoLoginProviderKey.Google.rawValue: idToken ]
                self.credentialsProvider.clearCredentials()  // clear old creds, if any
                self.credentialsProvider.getIdentityId().continueWith { _ in
                    // Optionally handle identity id fetch completion
                    return
                }
                DispatchQueue.main.async {
                    self.isSignedIn = true
                }
            } else {
                print("Google sign-in failed: \(error?.localizedDescription ?? "Unknown error")")
            }
        }

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
        credentialsProvider.clearCredentials()
        credentialsProvider.clearKeychain()
        isSignedIn = false
    }
}

