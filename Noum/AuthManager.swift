import Foundation
#if canImport(Security)
import Security
#endif
import AWSSDKIdentity
import protocol SmithyIdentity.AWSCredentialIdentityResolver
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#if canImport(UIKit)
import UIKit
#endif
#endif
#if canImport(Combine)
import Combine
#endif

#if canImport(Combine)
enum AuthProvider: String {
    case apple
    case google

    var title: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        }
    }
}

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    static let missingCredentialsMessage =
        "AWS Transcribe credentials are missing. For local development, add AWS credentials to your Xcode scheme environment or create a local Transcribe.plist that stays out of git. Do not ship static AWS secrets in a public app."

    @Published var isSignedIn: Bool = false
    @Published var signInError: String?
    @Published private(set) var authProvider: AuthProvider?
    @Published private(set) var isGoogleSignInAvailable = false
    private var credentialIdentity: AWSCredentialIdentity?
    private(set) var region: String = "eu-west-2"
    private let accountKey = "NoumAccountID"
    private let accountNameKey = "NoumAccountName"
    private let accountProviderKey = "NoumAccountProvider"
    private let installInitializedKey = "NoumHasInitializedInstallState"
    var currentAccountID: String? { KeychainHelper.load(key: accountKey) }
    var currentAccountName: String? { KeychainHelper.load(key: accountNameKey) }
    var currentAuthProviderTitle: String? { authProvider?.title }
#if canImport(GoogleSignIn)
    private var googleConfig: GIDConfiguration?
#endif

    private init() {
        initializeInstallStateIfNeeded()
        loadCredentialsAndAccount()
#if canImport(GoogleSignIn)
        configureGoogleSignInIfAvailable()
#endif
    }

#if canImport(GoogleSignIn) && canImport(UIKit)
    func startGoogleSignIn() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
            signInError = "Unable to find root view controller"
            return
        }
        signInWithGoogle(presenting: root)
    }

    private func signInWithGoogle(presenting controller: UIViewController) {
        guard let config = googleConfig else {
            signInError = "Google sign in is not configured for this build yet."
            return
        }
        GIDSignIn.sharedInstance.configuration = config
        GIDSignIn.sharedInstance.signIn(withPresenting: controller) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.signInError = error.localizedDescription
                    print("Google sign in failed: \(error)")
                    return
                }
                guard let userID = result?.user.userID else {
                    self.signInError = "Google sign in failed"
                    return
                }
                self.completeSignIn(
                    accountID: userID,
                    name: result?.user.profile?.name,
                    provider: .google
                )
            }
        }
    }
#else
#if canImport(GoogleSignIn)
    func startGoogleSignIn() {}
#endif
#endif

    func reloadCredentials() {
        loadCredentialsAndAccount()
    }

#if canImport(AuthenticationServices)
    func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                signInError = "Apple sign in failed"
                return
            }

            let formatter = PersonNameComponentsFormatter()
            let formattedName = formatter.string(from: credential.fullName ?? PersonNameComponents())
            let displayName = formattedName.trimmingCharacters(in: .whitespacesAndNewlines)
            completeSignIn(
                accountID: credential.user,
                name: displayName.isEmpty ? currentAccountName : displayName,
                provider: .apple
            )
        case .failure(let error):
            signInError = friendlyAppleSignInMessage(for: error)
        }
    }
#endif

    private func signIn() {
        if let creds = Self.loadCredentials() {
            self.credentialIdentity = creds.identity
            self.region = creds.region
        }
    }

    private func loadCredentialsAndAccount() {
        guard
            let accountID = KeychainHelper.load(key: accountKey),
            let providerRawValue = KeychainHelper.load(key: accountProviderKey),
            let provider = AuthProvider(rawValue: providerRawValue)
        else {
            clearStoredSession()
            isSignedIn = false
            authProvider = nil
            CoachingProfileStore.shared.endSession()
            if let creds = Self.loadCredentials() {
                self.credentialIdentity = creds.identity
                self.region = creds.region
            }
            return
        }

        print("Restored signed in account: \(accountID)")
        isSignedIn = true
        authProvider = provider
        CoachingProfileStore.shared.reloadForCurrentAccount()
        if let creds = Self.loadCredentials() {
            self.credentialIdentity = creds.identity
            self.region = creds.region
        }
    }

    func credentialResolver() throws -> any AWSCredentialIdentityResolver {
        if let cred = credentialIdentity {
            return try StaticAWSCredentialIdentityResolver(cred)
        }
        return DefaultAWSCredentialIdentityResolverChain()
    }

    func currentCredentials() async throws -> AWSCredentialIdentity {
        if let cred = credentialIdentity {
            return cred
        }
        if let creds = Self.loadCredentials() {
            self.credentialIdentity = creds.identity
            self.region = creds.region
            return creds.identity
        }
        throw NSError(
            domain: "AuthManager",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: Self.missingCredentialsMessage]
        )
    }

    func signOut() {
        credentialIdentity = nil
        clearStoredSession()
        isSignedIn = false
        authProvider = nil
        CoachingProfileStore.shared.endSession()
    }

    private func completeSignIn(accountID: String, name: String?, provider: AuthProvider) {
        let hasSeenAccountKey = "hasSeenAccount.\(provider.rawValue).\(accountID)"
        let isNewAccount = !UserDefaults.standard.bool(forKey: hasSeenAccountKey)

        _ = KeychainHelper.save(accountID, key: accountKey)
        _ = KeychainHelper.save(provider.rawValue, key: accountProviderKey)

        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedName.isEmpty {
            KeychainHelper.delete(key: accountNameKey)
        } else {
            _ = KeychainHelper.save(trimmedName, key: accountNameKey)
        }

        UserDefaults.standard.set(true, forKey: hasSeenAccountKey)

        print("Saved \(provider.title) user ID: \(accountID)")
        signIn()
        authProvider = provider
        isSignedIn = true
        CoachingProfileStore.shared.reloadForCurrentAccount()
        CoachingProfileStore.shared.beginSession(isNewAccount: isNewAccount)
    }

    private func clearStoredSession() {
        KeychainHelper.delete(key: accountKey)
        KeychainHelper.delete(key: accountNameKey)
        KeychainHelper.delete(key: accountProviderKey)
    }

    private func initializeInstallStateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: installInitializedKey) else { return }
        clearStoredSession()
        UserDefaults.standard.set(true, forKey: installInitializedKey)
    }

#if canImport(GoogleSignIn)
    private func configureGoogleSignInIfAvailable() {
        let env = ProcessInfo.processInfo.environment
        let clientID =
            env["GOOGLE_CLIENT_ID"] ??
            LocalConfigLoader.value(forKey: "GOOGLE_CLIENT_ID", plistNamed: "AIConfig") ??
            LocalConfigLoader.value(forKey: "CLIENT_ID", plistNamed: "GoogleService-Info")

        if let clientID, !clientID.isEmpty {
            googleConfig = GIDConfiguration(clientID: clientID)
            isGoogleSignInAvailable = true
        } else {
            googleConfig = nil
            isGoogleSignInAvailable = false
        }
    }
#endif

#if canImport(AuthenticationServices)
    private func friendlyAppleSignInMessage(for error: Error) -> String {
        if let authorizationError = error as? ASAuthorizationError, authorizationError.code == .unknown {
            return "Sign in with Apple is not configured for this build yet. Add the Sign in with Apple capability in Xcode Signing & Capabilities, then try again."
        }

        return error.localizedDescription
    }
#endif

    private static func loadCredentials() -> (identity: AWSCredentialIdentity, region: String)? {
        let env = ProcessInfo.processInfo.environment
        if let access = env["AWS_ACCESS_KEY_ID"],
           let secret = env["AWS_SECRET_ACCESS_KEY"] {
            let token = env["AWS_SESSION_TOKEN"]
            let region = env["AWS_REGION"] ?? "eu-west-2"
            return (AWSCredentialIdentity(accessKey: access, secret: secret, sessionToken: token), region)
        }
        #if canImport(Foundation)
        if let url = Bundle.main.url(forResource: "Transcribe", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
           let access = plist["AWS_ACCESS_KEY_ID"] as? String,
           let secret = plist["AWS_SECRET_ACCESS_KEY"] as? String {
            let token = plist["AWS_SESSION_TOKEN"] as? String
            let region = plist["AWS_REGION"] as? String ?? "eu-west-2"
            return (AWSCredentialIdentity(accessKey: access, secret: secret, sessionToken: token), region)
        }
        #endif
        return nil
    }
}
#else
@MainActor
class AuthManager {
    static let shared = AuthManager()
    static let missingCredentialsMessage =
        "AWS Transcribe credentials are missing. For local development, add AWS credentials to your Xcode scheme environment or create a local Transcribe.plist that stays out of git. Do not ship static AWS secrets in a public app."
    private(set) var region: String = "eu-west-2"
    var isSignedIn: Bool = false
    var signInError: String?
    var currentAccountID: String? { nil }
    func credentialResolver() throws -> any AWSCredentialIdentityResolver {
        DefaultAWSCredentialIdentityResolverChain()
    }
    func currentCredentials() async throws -> AWSCredentialIdentity {
        throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: Self.missingCredentialsMessage])
    }
    func signOut() { isSignedIn = false }
    func reloadCredentials() {}
}
#endif
