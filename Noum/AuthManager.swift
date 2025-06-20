import Foundation
#if canImport(Security)
import Security
#endif
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
import AWSSDKIdentity
import protocol SmithyIdentity.AWSCredentialIdentityResolver
#if canImport(Combine)
import Combine
#endif

#if canImport(Combine)
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isSignedIn: Bool = false
    private var credentialIdentity: AWSCredentialIdentity?
    private(set) var region: String = "eu-west-2"
    private let accountKey = "NoumAccountID"
    var currentAccountID: String? { KeychainHelper.load(key: accountKey) }

    private init() {
        if let id = KeychainHelper.load(key: accountKey) {
            print("Loaded account ID: \(id)")
            self.isSignedIn = true
        }
        if let creds = Self.loadCredentials() {
            self.credentialIdentity = creds.identity
            self.region = creds.region
        }
    }

    func signInWithGoogle(presenting: Any? = nil) {
        loadCredentialsAndAccount()
    }

    #if canImport(AuthenticationServices)
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest, isSignUp: Bool) {
        if isSignUp {
            request.requestedScopes = [.fullName, .email]
            request.requestedOperation = .operationCreateAccount
        } else {
            request.requestedOperation = .operationLogin
        }
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                let user = credential.user
                _ = KeychainHelper.save(user, key: accountKey)
                print("Saved account ID: \(user)")
                loadCredentialsAndAccount()
            }
        case .failure(let error):
            print("Apple sign in failed: \(error)")
        }
    }
    #else
    func configureAppleRequest(_ request: Any, isSignUp: Bool) {}
    func handleAppleAuthorization(_ result: Result<Any, Error>) {}
    #endif

    func reloadCredentials() {
        loadCredentialsAndAccount()
    }

    private func signIn() {
        if let creds = Self.loadCredentials() {
            self.credentialIdentity = creds.identity
            self.region = creds.region
        }
    }

    private func loadCredentialsAndAccount() {
        if KeychainHelper.load(key: accountKey) == nil {
            let id = UUID().uuidString
            _ = KeychainHelper.save(id, key: accountKey)
            print("Created new account ID: \(id)")
        }
        self.isSignedIn = KeychainHelper.load(key: accountKey) != nil
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
        throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "AWS credentials not configured"])
    }

    func signOut() {
        credentialIdentity = nil
        KeychainHelper.delete(key: accountKey)
        isSignedIn = false
    }

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
    private(set) var region: String = "eu-west-2"
    var currentAccountID: String? { nil }
    func credentialResolver() throws -> any AWSCredentialIdentityResolver {
        DefaultAWSCredentialIdentityResolverChain()
    }
    func currentCredentials() async throws -> AWSCredentialIdentity {
        throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "AWS credentials not configured"])
    }
    func configureAppleRequest(_ request: Any, isSignUp: Bool) {}
    func handleAppleAuthorization(_ result: Result<Any, Error>) {}
    func signOut() {}
    func reloadCredentials() {}
}
#endif
