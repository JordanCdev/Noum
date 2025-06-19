import Foundation
import AWSCore

@MainActor
class AuthManager: NSObject, ObservableObject {
    
    static let shared = AuthManager()
    @Published var isSignedIn: Bool = true  // Always true for unauthenticated flow
    
    private let identityPoolId = "eu-west-2:b72cffc1-2949-4be0-80b5-df2713295f9e"
    
    private(set) var credentialsProvider: AWSCognitoCredentialsProvider
    
    override private init() {
        let regionType = AWSRegionType.EUWest2
        
        self.credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: regionType,
            identityPoolId: identityPoolId
        )
        
        let configuration = AWSServiceConfiguration(
            region: regionType,
            credentialsProvider: self.credentialsProvider
        )
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        super.init()
    }
    
    func currentCredentials() async throws {
        let task = credentialsProvider.credentials()
        task.waitUntilFinished()
        
        if let error = task.error {
            throw error
        }
    }
    
    func signOut() {
        credentialsProvider.clearCredentials()
        credentialsProvider.clearKeychain()
        isSignedIn = false
    }
}

