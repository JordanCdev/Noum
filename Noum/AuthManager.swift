import Foundation
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

    private init() {
        if let creds = Self.loadCredentials() {
            self.credentialIdentity = creds.identity
            self.region = creds.region
            self.isSignedIn = true
        }
    }

    func signInWithGoogle(presenting: Any? = nil) {
        signIn()
    }

    func signInWithApple() {
        signIn()
    }

    private func signIn() {
        if let creds = Self.loadCredentials() {
            self.credentialIdentity = creds.identity
            self.region = creds.region
            self.isSignedIn = true
        }
    }

    func credentialResolver() -> any AWSCredentialIdentityResolver {
        if let cred = credentialIdentity {
            return StaticAWSCredentialIdentityResolver(cred)
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
            self.isSignedIn = true
            return creds.identity
        }
        throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "AWS credentials not configured"])
    }

    func signOut() {
        credentialIdentity = nil
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
    func credentialResolver() -> any AWSCredentialIdentityResolver {
        DefaultAWSCredentialIdentityResolverChain()
    }
    func currentCredentials() async throws -> AWSCredentialIdentity {
        throw NSError(domain: "AuthManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "AWS credentials not configured"])
    }
    func signInWithGoogle(presenting: Any? = nil) {}
    func signInWithApple() {}
    func signOut() {}
}
#endif
