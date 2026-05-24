import Foundation
#if canImport(Security)
import Security
#endif
import AWSSDKIdentity
import protocol SmithyIdentity.AWSCredentialIdentityResolver
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
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
    case guest

    var title: String {
        switch self {
        case .apple: return "Apple"
        case .google: return "Google"
        case .guest: return "Guest"
        }
    }
}

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    static let missingCredentialsMessage =
        "Speech-to-text is not configured. For local development, add AWS credentials to your Xcode scheme environment or a local Transcribe.plist that stays out of git."

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
    var currentAuthProviderRawValue: String? { KeychainHelper.load(key: accountProviderKey) }

    /// `true` when the signed-in account matches a developer ID listed in `AIConfig.plist`.
    var isDeveloper: Bool {
        guard let accountID = currentAccountID else { return false }
        return Self.developerAccountIDs.contains(accountID)
    }

    private static let developerAccountIDs: Set<String> = {
        guard let url = Bundle.main.url(forResource: "AIConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let ids = dict["DEVELOPER_ACCOUNT_IDS"] as? [String] else {
            return []
        }
        return Set(ids.filter { !$0.isEmpty })
    }()
#if canImport(GoogleSignIn)
    private var googleConfig: GIDConfiguration?
#endif
#if canImport(FirebaseAuth)
    private var currentNonce: String?
#endif

    private init() {
        initializeInstallStateIfNeeded()
#if canImport(GoogleSignIn)
        configureGoogleSignInIfAvailable()
#endif
        loadCredentialsAndAccount()
        restoreFirebaseSessionIfAvailable()
    }

#if canImport(GoogleSignIn) && canImport(UIKit)
    func startGoogleSignIn() {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
            signInError = "Google sign-in is temporarily unavailable right now. Please try again in a moment."
            return
        }
        signInWithGoogle(presenting: root)
    }

    private func signInWithGoogle(presenting controller: UIViewController) {
        guard let config = googleConfig else {
            signInError = "Google sign-in is temporarily unavailable for this build. Please try again later."
            return
        }
        GIDSignIn.sharedInstance.configuration = config
        GIDSignIn.sharedInstance.signIn(withPresenting: controller) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.signInError = self.friendlyGoogleSignInMessage(for: error)
                    print("Google sign in failed: \(error)")
                    return
                }
                guard let userID = result?.user.userID else {
                    self.signInError = "Google sign-in could not be completed. Please try again."
                    return
                }
#if canImport(FirebaseAuth)
                guard
                    let idToken = result?.user.idToken?.tokenString,
                    let accessToken = result?.user.accessToken.tokenString
                else {
                    self.signInError = "Google sign-in returned incomplete credentials. Please try again."
                    return
                }

                guard self.isFirebaseAuthConfigured else {
                    self.signInError = self.missingFirebaseConfigurationMessage
                    return
                }

                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                do {
                    let authResult = try await self.signInWithFirebase(credential: credential)
                    let user = authResult.user
                    self.completeSignIn(
                        accountID: user.uid,
                        name: user.displayName ?? result?.user.profile?.name,
                        provider: .google
                    )
                } catch {
                    self.signInError = self.friendlyGoogleSignInMessage(for: error)
                }
#else
                self.completeSignIn(
                    accountID: userID,
                    name: result?.user.profile?.name,
                    provider: .google
                )
#endif
            }
        }
    }
#else
#if canImport(GoogleSignIn)
    func startGoogleSignIn() {}
#endif
#endif

#if canImport(AuthenticationServices)
    func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName]
#if canImport(FirebaseAuth) && canImport(CryptoKit)
        let nonce = randomNonceString()
        currentNonce = nonce
        request.nonce = sha256(nonce)
#endif
    }
#endif

    func reloadCredentials() {
        loadCredentialsAndAccount()
    }

    func startAnonymousSession() {
#if canImport(FirebaseAuth)
        Task {
            guard isFirebaseAuthConfigured else {
                completeSignIn(accountID: UUID().uuidString, name: "Guest Speaker", provider: .guest)
                return
            }
            do {
                let authResult = try await signInAnonymouslyWithFirebase()
                await MainActor.run {
                    self.completeSignIn(
                        accountID: authResult.user.uid,
                        name: "Guest Speaker",
                        provider: .guest
                    )
                }
            } catch {
                await MainActor.run {
                    self.signInError = "Guest access could not be started right now. Please try again."
                }
            }
        }
#else
        completeSignIn(accountID: UUID().uuidString, name: "Guest Speaker", provider: .guest)
#endif
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
#if canImport(FirebaseAuth)
            guard
                let identityToken = credential.identityToken,
                let tokenString = String(data: identityToken, encoding: .utf8),
                let nonce = currentNonce
            else {
                signInError = "Apple sign-in could not be completed. Please try again."
                return
            }

            guard isFirebaseAuthConfigured else {
                signInError = missingFirebaseConfigurationMessage
                currentNonce = nil
                return
            }

            let firebaseCredential = OAuthProvider.appleCredential(
                withIDToken: tokenString,
                rawNonce: nonce,
                fullName: credential.fullName
            )

            Task {
                do {
                    let authResult = try await signInWithFirebase(credential: firebaseCredential)
                    await MainActor.run {
                        self.completeSignIn(
                            accountID: authResult.user.uid,
                            name: authResult.user.displayName ?? (displayName.isEmpty ? self.currentAccountName : displayName),
                            provider: .apple
                        )
                        self.currentNonce = nil
                    }
                } catch {
                    await MainActor.run {
                        self.signInError = self.friendlyAppleSignInMessage(for: error)
                        self.currentNonce = nil
                    }
                }
            }
#else
            completeSignIn(
                accountID: credential.user,
                name: displayName.isEmpty ? currentAccountName : displayName,
                provider: .apple
            )
#endif
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
            deferStoreSessionReset()
            if let creds = Self.loadCredentials() {
                self.credentialIdentity = creds.identity
                self.region = creds.region
            }
            return
        }

        #if DEBUG
        print("Restored signed in account: \(accountID)")
        #endif
        isSignedIn = true
        authProvider = provider
        deferStoreReloadForCurrentAccount()
        if let creds = Self.loadCredentials() {
            self.credentialIdentity = creds.identity
            self.region = creds.region
        }
    }

    func credentialResolver() throws -> any AWSCredentialIdentityResolver {
        if let cred = credentialIdentity, !isCredentialExpired {
            return try StaticAWSCredentialIdentityResolver(cred)
        }
        return DefaultAWSCredentialIdentityResolverChain()
    }

    func currentCredentials() async throws -> AWSCredentialIdentity {
        // 1. Use cached credentials if available and not expired
        if let cred = credentialIdentity, !isCredentialExpired {
            return cred
        }

        // 2. Try backend-vended temporary credentials (production path)
        if let backendCreds = try? await fetchBackendCredentials() {
            self.credentialIdentity = backendCreds.identity
            self.region = backendCreds.region
            self.credentialExpiresAt = backendCreds.expiresAt
            return backendCreds.identity
        }

        // 3. Fall back to local credentials (development path)
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

    // MARK: - Backend-Vended Temporary Credentials

    private var credentialExpiresAt: Date?

    private var isCredentialExpired: Bool {
        guard let expiresAt = credentialExpiresAt else { return false }
        // Refresh 60 seconds before expiry to avoid mid-stream failures
        return Date().addingTimeInterval(60) >= expiresAt
    }

    /// Fetches short-lived AWS credentials from your backend.
    /// Backend endpoint: GET /v1/transcribe/credentials
    /// Expected response: { "accessKeyId": "...", "secretAccessKey": "...", "sessionToken": "...", "region": "...", "expiresAt": "ISO8601" }
    private func fetchBackendCredentials() async throws -> (identity: AWSCredentialIdentity, region: String, expiresAt: Date)? {
        guard let accountID = currentAccountID,
              let providerRawValue = currentAuthProviderRawValue else {
            return nil
        }

        let baseURLString = ProcessInfo.processInfo.environment["BACKEND_BASE_URL"]
            ?? LocalConfigLoader.value(forKey: "BACKEND_BASE_URL", plistNamed: "BackendConfig")

        guard let baseURLString, !baseURLString.isEmpty,
              let baseURL = URL(string: baseURLString) else {
            return nil
        }

        let endpoint = baseURL.appending(path: "/v1/transcribe/credentials")
        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.setValue(accountID, forHTTPHeaderField: "X-Noum-Account-ID")
        request.setValue(providerRawValue, forHTTPHeaderField: "X-Noum-Auth-Provider")

        let backendAPIKey = ProcessInfo.processInfo.environment["BACKEND_API_KEY"]
            ?? LocalConfigLoader.value(forKey: "BACKEND_API_KEY", plistNamed: "BackendConfig")
        if let backendAPIKey, !backendAPIKey.isEmpty {
            request.setValue(backendAPIKey, forHTTPHeaderField: "X-Noum-API-Key")
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            return nil
        }

        let decoded = try JSONDecoder().decode(TemporaryCredentialsResponse.self, from: data)
        let identity = AWSCredentialIdentity(
            accessKey: decoded.accessKeyId,
            secret: decoded.secretAccessKey,
            sessionToken: decoded.sessionToken
        )
        return (identity: identity, region: decoded.region, expiresAt: decoded.expiresAt)
    }

    private struct TemporaryCredentialsResponse: Decodable {
        let accessKeyId: String
        let secretAccessKey: String
        let sessionToken: String
        let region: String
        let expiresAt: Date

        enum CodingKeys: String, CodingKey {
            case accessKeyId, secretAccessKey, sessionToken, region
            case expiresAt, expiration
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            accessKeyId = try container.decode(String.self, forKey: .accessKeyId)
            secretAccessKey = try container.decode(String.self, forKey: .secretAccessKey)
            sessionToken = try container.decode(String.self, forKey: .sessionToken)
            region = try container.decode(String.self, forKey: .region)
            // Accept either "expiresAt" or "expiration" from the backend
            let dateString = try (container.decodeIfPresent(String.self, forKey: .expiresAt)
                ?? container.decode(String.self, forKey: .expiration))
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            guard let date = formatter.date(from: dateString)
                    ?? ISO8601DateFormatter().date(from: dateString) else {
                throw DecodingError.dataCorrupted(
                    .init(codingPath: [CodingKeys.expiresAt], debugDescription: "Invalid ISO8601 date")
                )
            }
            expiresAt = date
        }
    }

    func signOut() {
        credentialIdentity = nil
#if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
#endif
#if canImport(FirebaseAuth)
        if isFirebaseAuthConfigured {
            try? Auth.auth().signOut()
        }
#endif
        clearStoredSession()
        isSignedIn = false
        authProvider = nil
        deferStoreSessionReset()
    }

    func deleteCurrentAccount() {
        guard let accountID = currentAccountID, let providerRawValue = currentAuthProviderRawValue else {
            signOut()
            return
        }

        Task {
            // 1. Delete server-side data (Firebase Firestore or REST backend)
            await BackendSyncManager.shared.deleteAccount(accountID: accountID, providerRawValue: providerRawValue)

            // 2. Delete Firebase Auth user
#if canImport(FirebaseAuth)
            if isFirebaseAuthConfigured, let user = Auth.auth().currentUser {
                try? await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    user.delete { error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else {
                            continuation.resume(returning: ())
                        }
                    }
                }
            }
#endif

            // 3. Clear all per-account UserDefaults data BEFORE signOut
            await MainActor.run {
                Self.clearAllUserData(for: accountID)
                self.signOut()
            }
        }
    }

    /// Removes all per-account UserDefaults keys so no personal data remains on device.
    private static func clearAllUserData(for accountID: String) {
        let defaults = UserDefaults.standard
        let keysToRemove = [
            "coachingProfile.\(accountID)",
            "coachingProfileOnboardingComplete.\(accountID)",
            "practiceSessions.\(accountID)",
            "imRelationshipProfiles.\(accountID)",
            "recommendation.pending.\(accountID)",
            "recommendation.outcomes.\(accountID)",
            "profileXP.\(accountID)",
            // Daily Goal
            "noum.dailyGoal.reps.\(accountID)",
            "noum.dailyGoal.drillCompletions.\(accountID)",
            "noum.dailyGoal.lastCelebrationDay.\(accountID)",
            // Streak Freeze
            "noum.streakFreeze.available.\(accountID)",
            "noum.streakFreeze.lastEarnedWeek.\(accountID)",
            "noum.streakFreeze.consumedDates.\(accountID)",
            // Path progression (M3)
            "noum.pathProgress.unlocked.\(accountID)",
            "noum.pathProgress.initialized.\(accountID)",
            // Lessons (M3+: teaching layer)
            "noum.lessons.progress.\(accountID)",
            // First-rep celebration (one-shot per account)
            "noum.firstRep.seen.\(accountID)",
            // Deferred profile capture (one-shot per prompt per account)
            "noum.deferredCapture.seen.goal.\(accountID)",
            "noum.deferredCapture.seen.whyNow.\(accountID)",
            "noum.deferredCapture.seen.successVision.\(accountID)",
            // Notification preferences
            "noum.notifications.dailyReminderEnabled.\(accountID)",
            "noum.notifications.dailyReminderTime.\(accountID)",
            "noum.notifications.streakWarningEnabled.\(accountID)",
            "noum.notifications.weeklyDigestEnabled.\(accountID)",
            // M14: peak-glow cursor (Home-only post-session celebration).
            "speakingRating.lastShownWeekPeak.\(accountID)",
            // M19: Big Moment intake + archive of past moments
            "bigMoment.\(accountID)",
            "bigMomentArchive.\(accountID)",
            // M20: Forward Plan (4-week coach program)
            "forwardPlan.\(accountID)",
            // M21: Session Intent — bounded history of declared focuses
            "sessionIntent.history.\(accountID)",
            // M24: Post-rep coach note — bounded history of coach reads
            "postRepCoachNote.\(accountID)",
            // M25: Coach memory — durable working formulation for Ask Noum
            "coachMemory.\(accountID)",
            // M24 Track 3: Sudden Death run history — bounded per-account
            "suddenDeath.runHistory.\(accountID)",
        ]
        for key in keysToRemove {
            defaults.removeObject(forKey: key)
        }
        // Global keys that are not per-account but should be cleared on deletion
        defaults.removeObject(forKey: "NoumFriendsList")
        defaults.removeObject(forKey: "NoumChallenges")
        defaults.removeObject(forKey: "NoumCompletedChallenges")
        defaults.removeObject(forKey: "NoumAsyncChallenges")
        defaults.removeObject(forKey: "aiMonthlyAnalysisCount")
        defaults.removeObject(forKey: "aiMonthlyAnalysisMonth")
        defaults.removeObject(forKey: "hasAcknowledgedAIDisclosure.\(accountID)")
        // AIRateLimiter day-bucketed counters — keys roll daily, so
        // they're cleared via the store's own 30-day rolling sweep
        // rather than enumerated by name here.
        AIRateLimiter.shared.deleteAllData(for: accountID)
    }

    func supportReportPayload() -> String {
        let provider = currentAuthProviderTitle ?? "Signed out"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let issue = signInError ?? "Unknown sign-in error"
        return """
        Noum Sign-In Report
        Timestamp: \(timestamp)
        Active provider: \(provider)
        Google configured: \(isGoogleSignInAvailable ? "yes" : "no")
        Error: \(issue)
        """
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

        #if DEBUG
        print("Saved \(provider.title) user ID: \(accountID)")
        #endif
        signIn()
        authProvider = provider
        isSignedIn = true
        deferStoreReloadForCurrentAccount {
            CoachingProfileStore.shared.beginSession(isNewAccount: isNewAccount)
        }
        syncFromBackendIfPossible(accountID: accountID, providerRawValue: provider.rawValue)
    }

    private func deferStoreReloadForCurrentAccount(
        completion: (@MainActor () -> Void)? = nil
    ) {
        Task { @MainActor in
            await Task.yield()
            CoachingProfileStore.shared.reloadForCurrentAccount()
            PracticeSessionStore.shared.reloadForCurrentAccount()
            ProfileManager.shared.reloadForCurrentAccount()
            IMRelationshipStore.shared.reloadForCurrentAccount()
            RecommendationLearningStore.shared.reloadForCurrentAccount()
            BigMomentStore.shared.reloadForCurrentAccount()
            ForwardPlanStore.shared.reloadForCurrentAccount()
            SessionIntentStore.shared.reloadForCurrentAccount()
            CoachLetterStore.shared.reloadForCurrentAccount()
            PostRepCoachNoteStore.shared.reloadForCurrentAccount()
            CoachMemoryStore.shared.reloadForCurrentAccount()
            SuddenDeathRunHistoryStore.shared.reloadForCurrentAccount()
            completion?()
        }
    }

    private func deferStoreSessionReset() {
        Task { @MainActor in
            await Task.yield()
            CoachingProfileStore.shared.endSession()
            PracticeSessionStore.shared.endSession()
            ProfileManager.shared.endSession()
            IMRelationshipStore.shared.endSession()
            BigMomentStore.shared.endSession()
            ForwardPlanStore.shared.endSession()
            SessionIntentStore.shared.endSession()
            CoachLetterStore.shared.endSession()
            PostRepCoachNoteStore.shared.endSession()
            CoachMemoryStore.shared.endSession()
            SuddenDeathRunHistoryStore.shared.endSession()
            AIRateLimiter.shared.endSession()
        }
    }

    private func clearStoredSession() {
        KeychainHelper.delete(key: accountKey)
        KeychainHelper.delete(key: accountNameKey)
        KeychainHelper.delete(key: accountProviderKey)
    }

    private func restoreFirebaseSessionIfAvailable() {
#if canImport(FirebaseAuth)
        guard isFirebaseAuthConfigured, let user = Auth.auth().currentUser else { return }
        let provider = firebaseProvider(for: user) ?? authProvider ?? .google
        completeSignIn(accountID: user.uid, name: user.displayName ?? currentAccountName, provider: provider)
#endif
    }

    private func syncFromBackendIfPossible(accountID: String, providerRawValue: String) {
        Task {
            guard let bootstrap = await BackendSyncManager.shared.fetchBootstrap(
                accountID: accountID,
                providerRawValue: providerRawValue
            ) else {
                return
            }

            await MainActor.run {
                if let xp = bootstrap.xp {
                    ProfileManager.shared.replaceFromRemote(xp)
                }
                if let profile = bootstrap.profile {
                    CoachingProfileStore.shared.replaceFromRemote(profile, for: accountID)
                }
                if let sessions = bootstrap.sessions {
                    PracticeSessionStore.shared.replaceFromRemote(sessions)
                }
                RecommendationLearningStore.shared.replaceFromRemote(
                    pendingExposure: bootstrap.recommendationPending,
                    outcomes: bootstrap.recommendationOutcomes ?? []
                )
            }
        }
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

#if canImport(GoogleSignIn)
    private func friendlyGoogleSignInMessage(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == "com.google.GIDSignIn" {
            switch nsError.code {
            case -2:
                return "Google sign-in was cancelled."
            default:
                break
            }
        }

        return "Google sign-in could not be completed right now. Please try again."
    }
#endif

#if canImport(FirebaseAuth)
    private var isFirebaseAuthConfigured: Bool {
        FirebaseApp.app() != nil
    }

    private var missingFirebaseConfigurationMessage: String {
        "Firebase is not configured on this Mac yet. Add your local GoogleService-Info.plist to the app target, then try again."
    }
#endif

#if canImport(FirebaseAuth)
    private func signInWithFirebase(credential: FirebaseAuth.AuthCredential) async throws -> FirebaseAuth.AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let authResult else {
                    continuation.resume(throwing: NSError(
                        domain: "AuthManager",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Firebase sign-in returned no user."]
                    ))
                    return
                }

                continuation.resume(returning: authResult)
            }
        }
    }

    private func signInAnonymouslyWithFirebase() async throws -> FirebaseAuth.AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            Auth.auth().signInAnonymously { authResult, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let authResult else {
                    continuation.resume(throwing: NSError(
                        domain: "AuthManager",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Anonymous sign-in returned no user."]
                    ))
                    return
                }

                continuation.resume(returning: authResult)
            }
        }
    }

    private func firebaseProvider(for user: FirebaseAuth.User) -> AuthProvider? {
        if user.isAnonymous {
            return .guest
        }
        if user.providerData.contains(where: { $0.providerID == "apple.com" }) {
            return .apple
        }
        if user.providerData.contains(where: { $0.providerID == "google.com" }) {
            return .google
        }
        return nil
    }
#endif

#if canImport(CryptoKit)
    private func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            let randoms: [UInt8] = (0..<16).map { _ in
                var random: UInt8 = 0
                let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
                if errorCode != errSecSuccess {
                    fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
                }
                return random
            }

            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }

                if random < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
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
        "AWS Transcribe credentials are missing. For local development, add AWS credentials to your Xcode scheme environment, Info.plist, or a local Transcribe.plist that stays out of git. Do not ship static AWS secrets in a public app."
    private(set) var region: String = "eu-west-2"
    var isSignedIn: Bool = false
    var signInError: String?
    var currentAccountID: String? { nil }
    var isDeveloper: Bool { false }
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
