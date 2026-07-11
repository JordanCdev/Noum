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

/// Initial identity + local-store readiness consumed by `NoumApp` before it
/// chooses onboarding or the main shell. This is account lifecycle state, not
/// a second onboarding flag.
enum InitialAccountHydrationState: Equatable {
    case needsIdentity
    case establishingGuest
    case hydratingStores
    case ready
    case failed(message: String)

    var hasHydratedAccountStores: Bool {
        self == .ready
    }

    var isWorking: Bool {
        switch self {
        case .needsIdentity, .establishingGuest, .hydratingStores:
            return true
        case .ready, .failed:
            return false
        }
    }
}

enum AnonymousFirebaseBootstrapOutcome {
    case account(id: String, name: String?)
    case unavailable
    case superseded
}

/// Main-actor one-shot used to race Firebase's callback against a bounded
/// timeout without leaving a checked continuation unresolved. A late Firebase
/// callback is handled separately by AuthManager's generation guard.
@MainActor
private final class AnonymousFirebaseBootstrapRace {
    private var continuation: CheckedContinuation<AnonymousFirebaseBootstrapOutcome, Never>?
    private var pendingOutcome: AnonymousFirebaseBootstrapOutcome?

    func wait() async -> AnonymousFirebaseBootstrapOutcome {
        if let pendingOutcome {
            return pendingOutcome
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resolve(_ outcome: AnonymousFirebaseBootstrapOutcome) {
        guard pendingOutcome == nil else { return }
        if let continuation {
            self.continuation = nil
            pendingOutcome = outcome
            continuation.resume(returning: outcome)
        } else {
            pendingOutcome = outcome
        }
    }
}

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    static let missingCredentialsMessage =
        "Live transcription isn't available in this build."

    @Published var isSignedIn: Bool = false
    @Published var signInError: String?
    @Published private(set) var authProvider: AuthProvider?
    @Published private(set) var isGoogleSignInAvailable = false
    @Published private(set) var initialAccountHydrationState: InitialAccountHydrationState = .needsIdentity
    private var credentialIdentity: AWSCredentialIdentity?
    private(set) var region: String = "eu-west-2"
    private let accountKey = "NoumAccountID"
    private let accountNameKey = "NoumAccountName"
    private let accountProviderKey = "NoumAccountProvider"
    private let installInitializedKey = "NoumHasInitializedInstallState"
    private var activeGuestBootstrapGeneration: UUID?
    private var activeGuestBootstrapRace: AnonymousFirebaseBootstrapRace?
    private var activeAccountHydrationGeneration: UUID?
    private static let localGuestPrefix = "local-guest-"
    private static let guestBootstrapTimeoutNanoseconds: UInt64 = 4_000_000_000
    var currentAccountID: String? { KeychainHelper.load(key: accountKey) }
    var currentAccountName: String? { KeychainHelper.load(key: accountNameKey) }
    var currentAuthProviderTitle: String? { authProvider?.title }
    var currentAuthProviderRawValue: String? { KeychainHelper.load(key: accountProviderKey) }

    nonisolated static func hasDurableIdentity(
        accountID: String?,
        providerRawValue: String?
    ) -> Bool {
        guard let accountID = accountID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !accountID.isEmpty,
              let providerRawValue,
              AuthProvider(rawValue: providerRawValue) != nil else {
            return false
        }
        return true
    }

    nonisolated static func shouldAcceptGuestBootstrapCompletion(
        generation: UUID,
        activeGeneration: UUID?
    ) -> Bool {
        generation == activeGeneration
    }

    nonisolated static func shouldEstablishLocalGuest(
        after outcome: AnonymousFirebaseBootstrapOutcome
    ) -> Bool {
        if case .superseded = outcome { return false }
        return true
    }

    /// A verified Keychain identity is authoritative across launches. Firebase
    /// may finish an anonymous request after our timeout/fallback or even after
    /// process death; that stale SDK session must never replace the local guest
    /// that owns the persisted profile.
    nonisolated static func shouldAdoptFirebaseSession(
        persistedAccountID: String?,
        persistedProviderRawValue: String?
    ) -> Bool {
        !hasDurableIdentity(
            accountID: persistedAccountID,
            providerRawValue: persistedProviderRawValue
        )
    }

    nonisolated static func userFacingDisplayName(
        from rawName: String?,
        fallback: String = "Your profile"
    ) -> String {
        let trimmed = rawName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return fallback }

        switch trimmed.lowercased() {
        case "guest speaker", "speaker":
            return fallback
        default:
            return trimmed
        }
    }

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
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if Self.shouldUseCleanLocalGuestForFirstRunUITesting(arguments: arguments) {
            // The real-first-run UI path must prove the empty-Keychain contract,
            // not inherit a prior simulator account. It deliberately avoids
            // Firebase so the test has no network dependency.
            clearStoredSession()
            #if canImport(FirebaseAuth)
            if isFirebaseAuthConfigured {
                try? Auth.auth().signOut()
            }
            #endif
            isSignedIn = false
            authProvider = nil
            initialAccountHydrationState = .needsIdentity
            return
        }
        // UI automation owns its process-local account and seeded stores. A
        // normal credential restore schedules an account reload/reset on the
        // next actor turn; that can erase `DevSeedData` immediately after the
        // app seeds it and make evidence-gated screens nondeterministic. Keep
        // the real Keychain and Firebase session untouched for the next normal
        // launch while the automation process starts signed out.
        if !Self.shouldRestorePersistedSession(
            arguments: arguments
        ) {
            isSignedIn = false
            authProvider = nil
            initialAccountHydrationState = .ready
            return
        }
        #endif
        loadCredentialsAndAccount()
        restoreFirebaseSessionIfAvailable()
    }

    #if DEBUG
    nonisolated static func shouldRestorePersistedSession(
        arguments: [String]
    ) -> Bool {
        !arguments.contains("UI_TESTING")
    }

    nonisolated static func shouldUseCleanLocalGuestForFirstRunUITesting(
        arguments: [String]
    ) -> Bool {
        arguments.contains("UI_TESTING")
            && arguments.contains("UI_TESTING_REAL_FIRST_RUN")
    }
    #endif

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

    /// Establishes the initial durable guest identity before app-level
    /// onboarding is allowed to save a profile. Firebase anonymous auth is the
    /// preferred production path; a bounded failure/timeout falls back to a
    /// Keychain-backed local guest so first run never depends on the network.
    func bootstrapInitialAccountIfNeeded() async {
        if Self.hasDurableIdentity(
            accountID: currentAccountID,
            providerRawValue: currentAuthProviderRawValue
        ), let accountID = currentAccountID,
           let providerRawValue = currentAuthProviderRawValue {
            if initialAccountHydrationState == .needsIdentity {
                hydrateStoresForCurrentAccount(
                    accountID: accountID,
                    providerRawValue: providerRawValue,
                    fetchRemote: true
                )
            }
            return
        }
        if currentAccountID != nil || currentAuthProviderRawValue != nil {
            clearStoredSession()
        }
        guard initialAccountHydrationState == .needsIdentity
                || isInitialBootstrapFailure else {
            return
        }

        signInError = nil
        initialAccountHydrationState = .establishingGuest

        #if DEBUG
        let useLocalOnly = Self.shouldUseCleanLocalGuestForFirstRunUITesting(
            arguments: ProcessInfo.processInfo.arguments
        )
        #else
        let useLocalOnly = false
        #endif

        if !useLocalOnly {
            #if canImport(FirebaseAuth)
            if isFirebaseAuthConfigured {
                cancelActiveGuestBootstrap()
                let generation = UUID()
                activeGuestBootstrapGeneration = generation
                let outcome = await boundedFirebaseAnonymousIdentity(generation: generation)
                if case let .account(accountID, name) = outcome {
                    if completeSignIn(
                        accountID: accountID,
                        name: name,
                        provider: .guest,
                        fetchRemote: true
                    ) {
                        return
                    }
                    if Auth.auth().currentUser?.uid == accountID {
                        try? Auth.auth().signOut()
                    }
                }
                guard Self.shouldEstablishLocalGuest(after: outcome) else {
                    return
                }
            }
            #endif
        }

        establishDurableLocalGuest()
    }

    func retryInitialAccountBootstrap() async {
        guard currentAccountID == nil else { return }
        initialAccountHydrationState = .needsIdentity
        await bootstrapInitialAccountIfNeeded()
    }

    func startAnonymousSession() {
        initialAccountHydrationState = .needsIdentity
        Task { @MainActor in
            await bootstrapInitialAccountIfNeeded()
        }
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
            initialAccountHydrationState = .needsIdentity
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
        hydrateStoresForCurrentAccount(
            accountID: accountID,
            providerRawValue: provider.rawValue,
            fetchRemote: !Self.isLocalGuestAccountID(accountID)
        )
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
        await BackendAuthHeaders.applyCurrent(
            to: &request,
            accountID: accountID,
            providerRawValue: providerRawValue
        )

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
        cancelActiveGuestBootstrap()
        activeAccountHydrationGeneration = nil
        AutoGuidedFirstRep.cancelPendingLaunch()
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
        // Sign-out is an explicit user choice, not an initial-launch failure.
        // Keep the app usable in its signed-out state; the next cold launch can
        // establish a fresh guest identity.
        initialAccountHydrationState = .ready
        deferStoreSessionReset()
    }

#if DEBUG
    /// Presents a deterministic signed-out UI state without changing the
    /// Keychain, Firebase session, or any account-scoped stores. The next
    /// normal launch restores the real session unchanged.
    func useProcessLocalSignedOutStateForUITesting(arguments: [String]) {
        guard arguments.contains("UI_TESTING"),
              arguments.contains("UI_TESTING_SIGNED_OUT") else { return }

        signInError = nil
        isSignedIn = false
        authProvider = nil
    }
#endif

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
            // Legacy onboarding completion flag. The profile itself is now the
            // sole completion truth, but deletion still removes older writes.
            "coachingProfileOnboardingComplete.\(accountID)",
            "\(FirstRunOnboardingGate.legacyCompletedKeyPrefix)\(accountID)",
            "\(AutoGuidedFirstRep.completedKeyPrefix)\(accountID)",
            "practiceSessions.\(accountID)",
            "skillTrendSnapshots.\(accountID)",
            "communicationBaseline.\(accountID)",
            "pressureProfile.\(accountID)",
            "speakingRating.\(accountID)",
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
            // M14: NoumCharacter lifetime-stage ratchet
            "noumCharacter.peakStage.\(accountID)",
            // Journey day-bloom ratchet (last-seen practiced days)
            "noum.journey.lastSeenPracticedDays.\(accountID)",
            // M19: Big Moment intake + archive of past moments
            "bigMoment.\(accountID)",
            "bigMomentArchive.\(accountID)",
            "bigMomentOutcomes.\(accountID)",
            // M20: Forward Plan (4-week coach program)
            "forwardPlan.\(accountID)",
            // M21: Session Intent — bounded history of declared focuses
            "sessionIntent.history.\(accountID)",
            // Session Reflection — bounded history of post-rep felt experience
            "sessionReflection.history.\(accountID)",
            // M24: Post-rep coach note — bounded history of coach reads
            "postRepCoachNote.\(accountID)",
            // M25: Coach memory — durable working formulation for Ask Noum
            "coachMemory.\(accountID)",
            // Transcript-anchored quote archive used by Ask Noum.
            "proofMoment.archive.\(accountID)",
            // Ask Noum coach thread — the full per-account chat/call dialogue.
            // Must be wiped on account deletion (GDPR) like every other store.
            "askNoum.thread.\(accountID)",
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
        defaults.removeObject(forKey: "skillTrendSnapshots")
        defaults.removeObject(forKey: "aiMonthlyAnalysisCount")
        defaults.removeObject(forKey: "aiMonthlyAnalysisMonth")
        defaults.removeObject(forKey: "hasAcknowledgedAIDisclosure.\(accountID)")
        AutoGuidedFirstRep.cancelPendingLaunch()
        // Legacy device-local account sighting flags. They no longer drive any
        // runtime decision, but must not survive account deletion.
        for provider in [AuthProvider.apple, .google, .guest] {
            defaults.removeObject(forKey: "hasSeenAccount.\(provider.rawValue).\(accountID)")
        }
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

    @discardableResult
    private func completeSignIn(
        accountID: String,
        name: String?,
        provider: AuthProvider,
        fetchRemote: Bool = true
    ) -> Bool {
        cancelActiveGuestBootstrap()
        guard persistIdentity(accountID: accountID, name: name, provider: provider) else {
            let message = "Noum couldn't save this account on this device. Try again."
            signInError = message
            initialAccountHydrationState = .failed(message: message)
            return false
        }

        #if DEBUG
        print("Saved \(provider.title) user ID: \(accountID)")
        #endif
        signIn()
        authProvider = provider
        isSignedIn = true
        hydrateStoresForCurrentAccount(
            accountID: accountID,
            providerRawValue: provider.rawValue,
            fetchRemote: fetchRemote
        )
        return true
    }

    private func hydrateStoresForCurrentAccount(
        accountID: String,
        providerRawValue: String,
        fetchRemote: Bool
    ) {
        let generation = UUID()
        activeAccountHydrationGeneration = generation
        initialAccountHydrationState = .hydratingStores

        Task { @MainActor in
            await Task.yield()
            guard self.isCurrentHydration(
                generation: generation,
                accountID: accountID,
                providerRawValue: providerRawValue
            ) else { return }

            self.reloadAccountScopedStores()

            // A locally saved profile is enough to route immediately. When a
            // non-guest account has no local profile (for example, first use on
            // a second device), finish one backend bootstrap read before
            // deciding that onboarding is genuinely needed.
            let shouldAwaitRemoteProfile = fetchRemote
                && providerRawValue != AuthProvider.guest.rawValue
                && CoachingProfileStore.shared.profile == nil

            if shouldAwaitRemoteProfile {
                await self.fetchAndApplyBackendBootstrap(
                    accountID: accountID,
                    providerRawValue: providerRawValue
                )
            } else if fetchRemote {
                Task { @MainActor in
                    await self.fetchAndApplyBackendBootstrap(
                        accountID: accountID,
                        providerRawValue: providerRawValue
                    )
                }
            }

            guard self.isCurrentHydration(
                generation: generation,
                accountID: accountID,
                providerRawValue: providerRawValue
            ) else { return }
            self.initialAccountHydrationState = .ready
        }
    }

    private func reloadAccountScopedStores() {
        CoachingProfileStore.shared.reloadForCurrentAccount()
        PracticeSessionStore.shared.reloadForCurrentAccount()
        SkillTrendStore.shared.reloadForCurrentAccount()
        BaselineStore.shared.reloadForCurrentAccount()
        RatingStore.shared.reloadForCurrentAccount()
        ProfileManager.shared.reloadForCurrentAccount()
        IMRelationshipStore.shared.reloadForCurrentAccount()
        RecommendationLearningStore.shared.reloadForCurrentAccount()
        BigMomentStore.shared.reloadForCurrentAccount()
        ForwardPlanStore.shared.reloadForCurrentAccount()
        SessionIntentStore.shared.reloadForCurrentAccount()
        SessionReflectionStore.shared.reloadForCurrentAccount()
        CoachCheckInStore.shared.reloadForCurrentAccount()
        CoachLetterStore.shared.reloadForCurrentAccount()
        PostRepCoachNoteStore.shared.reloadForCurrentAccount()
        CoachMemoryStore.shared.reloadForCurrentAccount()
        if #available(iOS 17.0, *) {
            ProofMomentStore.shared.reloadForCurrentAccount()
        }
        AskNoumStore.shared.reloadForCurrentAccount()
        SuddenDeathRunHistoryStore.shared.reloadForCurrentAccount()
    }

    private var isInitialBootstrapFailure: Bool {
        if case .failed = initialAccountHydrationState { return true }
        return false
    }

    private func establishDurableLocalGuest() {
        cancelActiveGuestBootstrap()
        let accountID = Self.localGuestPrefix + UUID().uuidString.lowercased()
        _ = completeSignIn(
            accountID: accountID,
            name: nil,
            provider: .guest,
            fetchRemote: false
        )
    }

    private func persistIdentity(
        accountID: String,
        name: String?,
        provider: AuthProvider
    ) -> Bool {
        let previousID = KeychainHelper.load(key: accountKey)
        let previousProvider = KeychainHelper.load(key: accountProviderKey)
        let previousName = KeychainHelper.load(key: accountNameKey)

        guard KeychainHelper.save(accountID, key: accountKey),
              KeychainHelper.save(provider.rawValue, key: accountProviderKey),
              KeychainHelper.load(key: accountKey) == accountID,
              KeychainHelper.load(key: accountProviderKey) == provider.rawValue else {
            restoreIdentity(
                accountID: previousID,
                providerRawValue: previousProvider,
                name: previousName
            )
            return false
        }

        let trimmedName = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedName.isEmpty {
            KeychainHelper.delete(key: accountNameKey)
        } else {
            // A display name is optional. Identity durability rests on the
            // verified account ID + provider pair above.
            _ = KeychainHelper.save(trimmedName, key: accountNameKey)
        }
        return true
    }

    private func restoreIdentity(
        accountID: String?,
        providerRawValue: String?,
        name: String?
    ) {
        if let accountID {
            _ = KeychainHelper.save(accountID, key: accountKey)
        } else {
            KeychainHelper.delete(key: accountKey)
        }
        if let providerRawValue {
            _ = KeychainHelper.save(providerRawValue, key: accountProviderKey)
        } else {
            KeychainHelper.delete(key: accountProviderKey)
        }
        if let name {
            _ = KeychainHelper.save(name, key: accountNameKey)
        } else {
            KeychainHelper.delete(key: accountNameKey)
        }
    }

    private func isCurrentHydration(
        generation: UUID,
        accountID: String,
        providerRawValue: String
    ) -> Bool {
        activeAccountHydrationGeneration == generation
            && Self.shouldApplyBackendBootstrap(
                requestedAccountID: accountID,
                requestedProviderRawValue: providerRawValue,
                currentAccountID: currentAccountID,
                currentProviderRawValue: currentAuthProviderRawValue
            )
    }

    private static func isLocalGuestAccountID(_ accountID: String) -> Bool {
        accountID.hasPrefix(localGuestPrefix)
    }

    #if canImport(FirebaseAuth)
    private func boundedFirebaseAnonymousIdentity(
        generation: UUID
    ) async -> AnonymousFirebaseBootstrapOutcome {
        let race = AnonymousFirebaseBootstrapRace()
        activeGuestBootstrapRace = race

        Auth.auth().signInAnonymously { [weak self, weak race] authResult, _ in
            Task { @MainActor in
                guard let self, let race else { return }
                guard Self.shouldAcceptGuestBootstrapCompletion(
                    generation: generation,
                    activeGeneration: self.activeGuestBootstrapGeneration
                ) else {
                    if let staleUID = authResult?.user.uid,
                       Auth.auth().currentUser?.uid == staleUID {
                        try? Auth.auth().signOut()
                    }
                    race.resolve(.superseded)
                    if self.activeGuestBootstrapRace === race {
                        self.activeGuestBootstrapRace = nil
                    }
                    return
                }

                self.activeGuestBootstrapGeneration = nil
                if self.activeGuestBootstrapRace === race {
                    self.activeGuestBootstrapRace = nil
                }
                if let user = authResult?.user {
                    race.resolve(.account(id: user.uid, name: user.displayName))
                } else {
                    race.resolve(.unavailable)
                }
            }
        }

        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.guestBootstrapTimeoutNanoseconds)
            guard let self else {
                race.resolve(.superseded)
                return
            }
            guard Self.shouldAcceptGuestBootstrapCompletion(
                    generation: generation,
                    activeGeneration: self.activeGuestBootstrapGeneration
                  ) else {
                race.resolve(.superseded)
                if self.activeGuestBootstrapRace === race {
                    self.activeGuestBootstrapRace = nil
                }
                return
            }
            // Clearing the generation before resolving makes any callback that
            // arrives after the timeout a stale completion; it is ignored and
            // its Firebase session is signed back out above.
            self.activeGuestBootstrapGeneration = nil
            if self.activeGuestBootstrapRace === race {
                self.activeGuestBootstrapRace = nil
            }
            race.resolve(.unavailable)
        }

        return await race.wait()
    }
    #endif

    private func cancelActiveGuestBootstrap() {
        activeGuestBootstrapGeneration = nil
        activeGuestBootstrapRace?.resolve(.superseded)
        activeGuestBootstrapRace = nil
    }

    private func deferStoreSessionReset() {
        Task { @MainActor in
            await Task.yield()
            // A clean-launch guest bootstrap or a new sign-in may have won the
            // next actor turn. Never let a stale signed-out reset erase the
            // newly active account's hydrated stores.
            guard self.currentAccountID == nil else { return }
            CoachingProfileStore.shared.endSession()
            PracticeSessionStore.shared.endSession()
            SkillTrendStore.shared.endSession()
            BaselineStore.shared.endSession()
            RatingStore.shared.endSession()
            ProfileManager.shared.endSession()
            IMRelationshipStore.shared.endSession()
            BigMomentStore.shared.endSession()
            ForwardPlanStore.shared.endSession()
            SessionIntentStore.shared.endSession()
            SessionReflectionStore.shared.endSession()
            CoachCheckInStore.shared.endSession()
            CoachLetterStore.shared.endSession()
            PostRepCoachNoteStore.shared.endSession()
            CoachMemoryStore.shared.endSession()
            if #available(iOS 17.0, *) {
                ProofMomentStore.shared.endSession()
            }
            AskNoumStore.shared.endSession()
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
        let persistedAccountID = currentAccountID
        let persistedProviderRawValue = currentAuthProviderRawValue
        guard Self.shouldAdoptFirebaseSession(
            persistedAccountID: persistedAccountID,
            persistedProviderRawValue: persistedProviderRawValue
        ) else {
            if persistedAccountID != user.uid
                || persistedProviderRawValue != provider.rawValue {
                // Most importantly: clear a Firebase-anonymous completion that
                // arrived after the bounded local-guest fallback won.
                try? Auth.auth().signOut()
            }
            return
        }
        completeSignIn(accountID: user.uid, name: user.displayName ?? currentAccountName, provider: provider)
#endif
    }

    private func fetchAndApplyBackendBootstrap(
        accountID: String,
        providerRawValue: String
    ) async {
        guard let bootstrap = await BackendSyncManager.shared.fetchBootstrap(
            accountID: accountID,
            providerRawValue: providerRawValue
        ) else {
            return
        }

        guard Self.shouldApplyBackendBootstrap(
            requestedAccountID: accountID,
            requestedProviderRawValue: providerRawValue,
            currentAccountID: currentAccountID,
            currentProviderRawValue: currentAuthProviderRawValue
        ) else {
            return
        }

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

    nonisolated static func shouldApplyBackendBootstrap(
        requestedAccountID: String,
        requestedProviderRawValue: String,
        currentAccountID: String?,
        currentProviderRawValue: String?
    ) -> Bool {
        requestedAccountID == currentAccountID
            && requestedProviderRawValue == currentProviderRawValue
    }

    private func initializeInstallStateIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: installInitializedKey) else { return }
        clearStoredSession()
        #if canImport(FirebaseAuth)
        if isFirebaseAuthConfigured {
            try? Auth.auth().signOut()
        }
        #endif
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
            return "Sign in with Apple isn't available in this build. Try Google or continue without an account."
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
        "Google sign-in isn't available in this build. Try Apple or continue without an account."
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
        "Live transcription isn't available in this build."
    private(set) var region: String = "eu-west-2"
    var isSignedIn: Bool = false
    var signInError: String?
    var currentAccountID: String? { nil }
    var currentAuthProviderRawValue: String? { nil }
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

struct BackendAuthHeaders: Equatable, Sendable {
    static let accountIDHeader = "X-Noum-Account-ID"
    static let authProviderHeader = "X-Noum-Auth-Provider"
    static let apiKeyHeader = "X-Noum-API-Key"
    static let authorizationHeader = "Authorization"

    let accountID: String?
    let providerRawValue: String?
    let apiKey: String?
    let firebaseIDToken: String?

    init(
        accountID: String?,
        providerRawValue: String?,
        apiKey: String?,
        firebaseIDToken: String?
    ) {
        self.accountID = Self.cleaned(accountID)
        self.providerRawValue = Self.cleaned(providerRawValue)
        self.apiKey = Self.cleaned(apiKey)
        self.firebaseIDToken = Self.cleaned(firebaseIDToken)
    }

    func apply(to request: inout URLRequest) {
        if let apiKey {
            request.setValue(apiKey, forHTTPHeaderField: Self.apiKeyHeader)
        }
        if let firebaseIDToken {
            request.setValue("Bearer \(firebaseIDToken)", forHTTPHeaderField: Self.authorizationHeader)
            return
        }

        // Legacy REST-backend fallback only. In Firebase-authenticated mode the
        // server must derive identity from the bearer token, never from these
        // client-provided transition headers.
        if let accountID {
            request.setValue(accountID, forHTTPHeaderField: Self.accountIDHeader)
        }
        if let providerRawValue {
            request.setValue(providerRawValue, forHTTPHeaderField: Self.authProviderHeader)
        }
    }

    static func current(
        accountID: String? = nil,
        providerRawValue: String? = nil,
        env: [String: String] = ProcessInfo.processInfo.environment,
        configValue: (String) -> String? = { key in
            LocalConfigLoader.value(forKey: key, plistNamed: "BackendConfig")
        }
    ) async -> BackendAuthHeaders {
        let legacy = await MainActor.run {
            (
                accountID: accountID ?? AuthManager.shared.currentAccountID,
                providerRawValue: providerRawValue ?? AuthManager.shared.currentAuthProviderRawValue
            )
        }
        let token = await currentFirebaseIDToken()
        return BackendAuthHeaders(
            accountID: legacy.accountID,
            providerRawValue: legacy.providerRawValue,
            apiKey: configuredAPIKey(env: env, configValue: configValue),
            firebaseIDToken: token
        )
    }

    static func applyCurrent(
        to request: inout URLRequest,
        accountID: String? = nil,
        providerRawValue: String? = nil
    ) async {
        let headers = await current(
            accountID: accountID,
            providerRawValue: providerRawValue
        )
        headers.apply(to: &request)
    }

    static func configuredAPIKey(
        env: [String: String] = ProcessInfo.processInfo.environment,
        configValue: (String) -> String? = { key in
            LocalConfigLoader.value(forKey: key, plistNamed: "BackendConfig")
        }
    ) -> String? {
        cleaned(env["BACKEND_API_KEY"]) ?? cleaned(configValue("BACKEND_API_KEY"))
    }

    static func cleaned(_ raw: String?) -> String? {
        let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func currentFirebaseIDToken() async -> String? {
        #if canImport(FirebaseAuth)
        #if canImport(FirebaseCore)
        guard FirebaseApp.app() != nil else { return nil }
        #endif
        guard let user = Auth.auth().currentUser else { return nil }
        return try? await withCheckedThrowingContinuation { continuation in
            user.getIDToken { token, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: token ?? "")
            }
        }
        #else
        return nil
        #endif
    }
}
