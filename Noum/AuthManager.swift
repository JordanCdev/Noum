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
enum AuthProvider: String, Equatable {
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

enum FirebaseCredentialStrategy: Equatable {
    case signIn
    case linkAnonymousUser
    case preserveLocalGuest
}

enum AccountUpgradeConflict: LocalizedError, Equatable, Identifiable {
    case credentialAlreadyInUse(AuthProvider)
    case localGuestMigrationRequired(AuthProvider)

    var id: String {
        switch self {
        case .credentialAlreadyInUse(let provider):
            return "credential-in-use-\(provider.rawValue)"
        case .localGuestMigrationRequired(let provider):
            return "local-guest-migration-\(provider.rawValue)"
        }
    }

    var errorDescription: String? {
        switch self {
        case .credentialAlreadyInUse(let provider):
            return "That \(provider.title) account already exists. Your guest practice is unchanged; Noum won't switch accounts until you choose how to handle both histories."
        case .localGuestMigrationRequired(let provider):
            return "Your guest practice is stored only on this device. Noum won't replace it with \(provider.title) until a safe account transfer is available."
        }
    }
}

enum AccountDeletionError: LocalizedError, Equatable {
    case noActiveAccount
    case safeToRetry
    case requiresRecentAuthentication
    case appleRevocationUnavailable
    case secureDataUpgradeIncomplete
    case serviceUnavailable
    case remoteRejected
    case localCleanupFailed
    case completionUncertain
    case completionUncertainRequiresReauthentication

    var errorDescription: String? {
        switch self {
        case .noActiveAccount:
            return "No active account was found."
        case .safeToRetry:
            return "Noum paused before contacting the account service. Your account and local data are unchanged. You can retry account deletion."
        case .requiresRecentAuthentication:
            return "Sign in again, then retry account deletion. Your data has not been cleared from this device."
        case .appleRevocationUnavailable:
            return "Deletion is not available for this Apple-linked account until Noum can revoke its Apple authorization safely. Your data is unchanged."
        case .secureDataUpgradeIncomplete:
            return "Account deletion is temporarily unavailable while Noum finishes a secure account-data upgrade. Nothing was deleted and your data is unchanged. Try again later."
        case .serviceUnavailable:
            return "Noum couldn't reach the account service. Your account and local data are unchanged. Try again when you're connected."
        case .remoteRejected:
            return "Noum couldn't complete account deletion. Your local data is unchanged and you can retry."
        case .localCleanupFailed:
            return "Noum reached the device-cleanup step but couldn't finish clearing this device. Retry to finish local cleanup. Only local cleanup will run again."
        case .completionUncertain:
            return "Noum couldn't confirm that account deletion finished. Ask Noum, Forward Plan, and recommendation sync stay paused for this account. Contact deletion support so the account's status can be verified before you sign in or create another account."
        case .completionUncertainRequiresReauthentication:
            return "Noum couldn't confirm that account deletion finished. Ask Noum, Forward Plan, and recommendation sync stay paused for this account. Contact deletion support so the account's status can be verified; a new account cannot replace this pending deletion."
        }
    }

    var requiresReauthentication: Bool {
        // Once a remote request may have crossed the boundary, authentication
        // is not completion evidence and the UI must not present retry as the
        // recovery action. Same-account authentication remains accepted at the
        // identity boundary if support needs it, but is never prompted here.
        self == .requiresRecentAuthentication
    }
}

enum AccountDeletionState: Equatable {
    case idle
    case deleting
    case failed(AccountDeletionError)
    case completed
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

enum InitialRemoteProfileHydrationOutcome {
    case fetched(BackendBootstrapFetchResult)
    case timedOut
    case superseded
}

enum InitialRemoteProfileHydrationDisposition: Equatable {
    case ready
    case retry
    case superseded
}

enum GuestIdentityHydrationOrigin {
    case freshlyCreated
    case restored
}

/// One-shot boundary for the initial remote profile read. Firestore writes may
/// never call their completion while offline, so the app root must not await
/// that callback directly.
@MainActor
final class InitialRemoteProfileHydrationRace {
    private var continuation: CheckedContinuation<InitialRemoteProfileHydrationOutcome, Never>?
    private var pendingOutcome: InitialRemoteProfileHydrationOutcome?

    func wait() async -> InitialRemoteProfileHydrationOutcome {
        if let pendingOutcome {
            return pendingOutcome
        }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    @discardableResult
    func resolve(_ outcome: InitialRemoteProfileHydrationOutcome) -> Bool {
        guard pendingOutcome == nil else { return false }
        pendingOutcome = outcome
        if let continuation {
            self.continuation = nil
            continuation.resume(returning: outcome)
        }
        return true
    }
}

@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    static let missingCredentialsMessage =
        "Live transcription isn't available in this build."
    static let remoteProfileRecoveryMessage =
        "Noum couldn't confirm your saved coaching profile. Check your connection and try again."

    @Published var isSignedIn: Bool = false
    @Published var signInError: String?
    @Published private(set) var authProvider: AuthProvider?
    @Published private(set) var accountUpgradeConflict: AccountUpgradeConflict?
    @Published private(set) var accountDeletionState: AccountDeletionState = .idle
    @Published private(set) var isGoogleSignInAvailable = false
    @Published private(set) var initialAccountHydrationState: InitialAccountHydrationState = .needsIdentity
    private var credentialIdentity: AWSCredentialIdentity?
    private(set) var region: String = "eu-west-2"
    private let accountKey = "NoumAccountID"
    private let accountNameKey = "NoumAccountName"
    private let accountProviderKey = "NoumAccountProvider"
    private let installInitializedKey = "NoumHasInitializedInstallState"
    private let accountDataRegistry: AccountDataRegistry
    private let accountDataExportService: AccountDataExportService
    private let accountDeletionFenceRepository: AccountDeletionFenceRepository
    private var activeGuestBootstrapGeneration: UUID?
    private var activeGuestBootstrapRace: AnonymousFirebaseBootstrapRace?
    private var activeAccountHydrationGeneration: UUID?
    private var activeInitialRemoteProfileHydrationRace: InitialRemoteProfileHydrationRace?
    /// Monotonic process-local identity epoch. Async consumers that handle
    /// sensitive transient data capture this value and reject completions
    /// after teardown or hydration, including a rapid sign-out/sign-in to the
    /// same Firebase UID.
    private(set) var accountLifecycleGeneration: UInt64 = 0
    private nonisolated static let localGuestPrefix = "local-guest-"
    private static let guestBootstrapTimeoutNanoseconds: UInt64 = 4_000_000_000
    private static let initialRemoteProfileTimeoutNanoseconds: UInt64 = 4_000_000_000
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

    nonisolated static func shouldRehydrateDurableIdentityOnRetry(
        accountID: String?,
        providerRawValue: String?
    ) -> Bool {
        hasDurableIdentity(accountID: accountID, providerRawValue: providerRawValue)
    }

    /// Selects the only non-lossy Firebase credential operation. A Firebase
    /// anonymous user is linked in place so its UID and account-scoped history
    /// remain stable. A Keychain-only guest cannot be merged safely on-device,
    /// so the operation is blocked rather than silently replacing that guest.
    nonisolated static func firebaseCredentialStrategy(
        persistedAccountID: String?,
        persistedProviderRawValue: String?,
        firebaseUID: String?,
        firebaseUserIsAnonymous: Bool
    ) -> FirebaseCredentialStrategy {
        guard persistedProviderRawValue == AuthProvider.guest.rawValue,
              let persistedAccountID else {
            return .signIn
        }
        if firebaseUserIsAnonymous, firebaseUID == persistedAccountID {
            return .linkAnonymousUser
        }
        return .preserveLocalGuest
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
        let registry = AccountDataRegistry.production()
        accountDataRegistry = registry
        accountDataExportService = AccountDataExportService(registry: registry)
        accountDeletionFenceRepository = AccountDeletionFenceRepository(
            storage: KeychainAccountDeletionFenceStorage()
        )
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
        guard allowPendingDeletionSignInIntent(provider: .google) else { return }
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
            .first?.rootViewController else {
            signInError = "Google sign-in is temporarily unavailable right now. Please try again in a moment."
            return
        }
        signInWithGoogle(presenting: root)
    }

    private func signInWithGoogle(presenting controller: UIViewController) {
        accountUpgradeConflict = nil
        resetDeletionStateForSignInIntent()
        signInError = nil
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
                    let authResult = try await self.authenticateWithFirebase(
                        credential: credential,
                        provider: .google
                    )
                    let user = authResult.user
                    self.completeSignIn(
                        accountID: user.uid,
                        name: user.displayName ?? result?.user.profile?.name,
                        provider: .google
                    )
                } catch {
                    self.presentCredentialError(error, provider: .google)
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
        accountUpgradeConflict = nil
        resetDeletionStateForSignInIntent()
        signInError = nil
        guard allowPendingDeletionSignInIntent(provider: .apple) else {
            #if canImport(FirebaseAuth)
            currentNonce = nil
            #endif
            return
        }
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

    /// The durable deletion-admission authority for provider work. Missing is
    /// the only allowing state; an unreadable, corrupt, or other-account active
    /// fence fails closed globally. Transient UI state is not sufficient here.
    func isProviderWorkAllowed(for accountID: String) -> Bool {
        accountDeletionFenceRepository.isProviderWorkAllowed(for: accountID)
    }

    /// Establishes the initial durable guest identity before app-level
    /// onboarding is allowed to save a profile. Firebase anonymous auth is the
    /// preferred production path; a bounded failure/timeout falls back to a
    /// Keychain-backed local guest so first run never depends on the network.
    func bootstrapInitialAccountIfNeeded() async {
        guard !restorePendingDeletionIdentityIfNeeded() else { return }

        if Self.hasDurableIdentity(
            accountID: currentAccountID,
            providerRawValue: currentAuthProviderRawValue
        ), let accountID = currentAccountID,
           let providerRawValue = currentAuthProviderRawValue {
            if initialAccountHydrationState == .needsIdentity {
                hydrateStoresForCurrentAccount(
                    accountID: accountID,
                    providerRawValue: providerRawValue,
                    fetchRemote: Self.shouldFetchRemoteForDurableIdentity(accountID: accountID)
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
                        fetchRemote: Self.shouldFetchRemoteForGuestIdentity(
                            accountID: accountID,
                            origin: .freshlyCreated
                        )
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
        guard isInitialBootstrapFailure else { return }
        signInError = nil
        if Self.shouldRehydrateDurableIdentityOnRetry(
            accountID: currentAccountID,
            providerRawValue: currentAuthProviderRawValue
        ), let accountID = currentAccountID,
           let providerRawValue = currentAuthProviderRawValue {
            hydrateStoresForCurrentAccount(
                accountID: accountID,
                providerRawValue: providerRawValue,
                fetchRemote: Self.shouldFetchRemoteForDurableIdentity(accountID: accountID)
            )
            return
        }
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
                    let authResult = try await authenticateWithFirebase(
                        credential: firebaseCredential,
                        provider: .apple
                    )
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
                        self.presentCredentialError(error, provider: .apple)
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
        // The fixed pending-deletion record is authoritative over ordinary
        // identity keys. Generic sign-out may clear those keys, and a stale
        // Firebase session may belong to another account, but neither may
        // orphan or replace the account whose deletion is unresolved.
        if restorePendingDeletionIdentityIfNeeded() {
            if let creds = Self.loadCredentials() {
                self.credentialIdentity = creds.identity
                self.region = creds.region
            }
            return
        }

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
            fetchRemote: Self.shouldFetchRemoteForDurableIdentity(accountID: accountID)
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
        cancelActiveAccountHydration()
        AutoGuidedFirstRep.cancelPendingLaunch()
        credentialIdentity = nil
        accountDataExportService.cleanupAll()
#if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
#endif
#if canImport(FirebaseAuth)
        if isFirebaseAuthConfigured {
            try? Auth.auth().signOut()
        }
#endif
        // Deliberately does not clear an account-deletion fence. A generic
        // sign-out cannot prove whether a remote deletion request committed.
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

    /// Deletes one account behind a durable admission fence. The fence and its
    /// stable request ID survive sign-out, relaunch, and reauthentication. Only
    /// a verified pre-remote failure may reopen provider work; an ambiguous
    /// remote outcome remains fail-closed. The checked-in callable has no
    /// durable completion receipt or unauthenticated post-deletion recovery
    /// route, so this client state must not be described as backend resumability.
    func deleteCurrentAccount() async throws {
        _ = restorePendingDeletionIdentityIfNeeded()
        guard let accountID = currentAccountID,
              let providerRawValue = currentAuthProviderRawValue else {
            accountDeletionState = .failed(.noActiveAccount)
            throw AccountDeletionError.noActiveAccount
        }

        let admittedFence: AccountDeletionFence
        do {
            admittedFence = try accountDeletionFenceRepository
                .beginOrResume(
                    for: accountID,
                    providerRawValue: providerRawValue
                )
                .get()
        } catch {
            // A definitively missing key means admission never happened and
            // the unchanged-data recovery remains honest. A present or
            // unreadable key is ambiguous: close process-local work as well as
            // the repository's durable admission check, but make no backend
            // call and do not advance deletion.
            if accountDeletionFenceRepository.lookup(for: accountID) == .missing {
                accountDeletionState = .failed(.serviceUnavailable)
                throw AccountDeletionError.serviceUnavailable
            }
            accountDeletionState = .failed(.completionUncertain)
            accountLifecycleGeneration &+= 1
            cancelActiveAccountHydration()
            AskNoumStore.shared.suspendProviderWorkForDeletion(accountID: accountID)
            ForwardPlanStore.shared.suspendProviderWorkForDeletion(accountID: accountID)
            await ForwardPlanService.shared.suspendProviderWorkForDeletion(
                accountID: accountID
            )
            throw AccountDeletionError.completionUncertain
        }

        // No suspension occurs between publishing deletion, rotating the
        // lifecycle epoch, and closing the two MainActor mutation boundaries.
        accountDeletionState = .deleting
        accountLifecycleGeneration &+= 1
        cancelActiveAccountHydration()
        AskNoumStore.shared.suspendProviderWorkForDeletion(accountID: accountID)
        ForwardPlanStore.shared.suspendProviderWorkForDeletion(accountID: accountID)

        let backendSync = BackendSyncManager.shared
        var fence = admittedFence
        // A preflight rejection may safely reopen admission only when this
        // invocation created the remote-request phase. A fence resumed in that
        // phase could represent an earlier ambiguous or partially destructive
        // attempt, so a later preflight response cannot clear it retroactively.
        var preparedRemoteRequestInCurrentAttempt = false
        var recommendationSyncWasClosed = false
        do {
            // Actor-owned transport admission closes only after the synchronous
            // store leases above have already been invalidated.
            await ForwardPlanService.shared.suspendProviderWorkForDeletion(
                accountID: accountID
            )

            guard await backendSync.suspendRecommendationSyncForDeletion(accountID: accountID) else {
                throw AccountDeletionError.serviceUnavailable
            }
            recommendationSyncWasClosed = true

            guard currentAccountID == accountID,
                  currentAuthProviderRawValue == providerRawValue else {
                throw AccountDeletionError.serviceUnavailable
            }

            if fence.phase == .admissionClosed {
                // A verified remoteRequested phase is the final local action
                // before transport. If this write cannot be read back, no
                // backend method is invoked.
                fence = try accountDeletionFenceRepository
                    .advance(fence, to: .remoteRequested)
                    .get()
                preparedRemoteRequestInCurrentAttempt = true
            }

            if fence.phase == .remoteRequested {
                if Self.shouldSyncBackend(accountID: accountID) {
                    guard currentAccountID == accountID,
                          currentAuthProviderRawValue == providerRawValue else {
                        throw AccountDeletionError.serviceUnavailable
                    }
                    let outcome = try await backendSync.deleteAccount(
                        accountID: accountID,
                        providerRawValue: providerRawValue,
                        requestID: fence.requestID
                    )
                    if outcome == .dataDeleted {
                        try await deleteFirebaseUserIfNeeded(expectedAccountID: accountID)
                    }
                }

                // Reusing this UUID preserves correlation across authenticated
                // calls only. The callable overwrites and finally removes its
                // deletion state, then deletes Auth; it exposes no durable
                // status receipt or unauthenticated resume route. A lost reply
                // therefore remains fail-closed, not proven backend recovery.
                fence = try accountDeletionFenceRepository
                    .advance(fence, to: .remoteCommitted)
                    .get()
            }

            guard currentAccountID == accountID,
                  currentAuthProviderRawValue == providerRawValue else {
                throw AccountDeletionError.completionUncertain
            }

            if fence.phase == .remoteCommitted {
                fence = try accountDeletionFenceRepository
                    .advance(fence, to: .localCleanupStarted)
                    .get()
            }

            guard fence.phase == .localCleanupStarted else {
                throw AccountDeletionError.completionUncertain
            }

            try accountDataRegistry.deleteAllData(for: accountID)
            // Clear every published account projection synchronously while the
            // Keychain identity still names the deleted account. `signOut()`'s
            // deferred reset is now only an idempotent backstop.
            accountDataRegistry.endSession()
            signOut()

            try accountDeletionFenceRepository.clearVerified(fence).get()
            accountDeletionState = .completed
            await ForwardPlanService.shared.finishProviderWorkDeletion(
                accountID: accountID
            )
        } catch {
            let mapped = Self.mapAccountDeletionError(error)
            let persistedRecovery = persistedDeletionRecovery(
                expectedRequestID: fence.requestID,
                accountID: accountID
            )
            let persistedPhase: AccountDeletionFencePhase?
            if case .present(let persistedFence) = persistedRecovery {
                persistedPhase = persistedFence.phase
            } else {
                persistedPhase = nil
            }

            var disposition: AccountDeletionFailureDisposition =
                .retainFenceAndKeepProviderWorkSuspended
            if case .present(let persistedFence) = persistedRecovery {
                disposition = Self.accountDeletionFailureDisposition(
                    for: error,
                    persistedPhase: persistedFence.phase,
                    preparedRemoteRequestInCurrentAttempt:
                        preparedRemoteRequestInCurrentAttempt
                )
            }
            if case .present(let persistedFence) = persistedRecovery,
               disposition == .clearFenceAndResumeProviderWork {
                if case .success = accountDeletionFenceRepository.clearVerified(persistedFence) {
                    await ForwardPlanService.shared.resumeProviderWorkAfterSafeDeletionFailure(
                        accountID: accountID
                    )
                    if recommendationSyncWasClosed {
                        await backendSync.resumeRecommendationSyncAfterFailedDeletion(
                            accountID: accountID
                        )
                    }
                    if currentAccountID == accountID,
                       currentAuthProviderRawValue == providerRawValue {
                        RecommendationLearningStore.shared.syncCurrentState()
                    }
                } else {
                    // Failure to verify fence removal turns an otherwise safe
                    // error into an ambiguous, still-closed deletion.
                    disposition = .retainFenceAndKeepProviderWorkSuspended
                }
            }

            let surfaced = Self.accountDeletionError(
                for: mapped,
                disposition: disposition,
                persistedPhase: persistedPhase
            )
            accountDeletionState = .failed(surfaced)
            throw surfaced
        }
    }

    private func persistedDeletionRecovery(
        expectedRequestID: UUID,
        accountID: String
    ) -> AccountDeletionFenceLookup {
        let lookup = accountDeletionFenceRepository.lookup(for: accountID)
        guard case .present(let fence) = lookup else { return lookup }
        guard fence.requestID == expectedRequestID else { return .ambiguous }
        return .present(fence)
    }

    nonisolated static func accountDeletionError(
        for underlying: AccountDeletionError,
        disposition: AccountDeletionFailureDisposition,
        persistedPhase: AccountDeletionFencePhase? = nil
    ) -> AccountDeletionError {
        switch disposition {
        case .clearFenceAndResumeProviderWork:
            return underlying
        case .retainFenceAndKeepProviderWorkSuspended:
            switch persistedPhase {
            case .admissionClosed:
                return .safeToRetry
            case .remoteCommitted, .localCleanupStarted:
                return .localCleanupFailed
            case .remoteRequested, nil:
                return underlying == .requiresRecentAuthentication
                    ? .completionUncertainRequiresReauthentication
                    : .completionUncertain
            }
        }
    }

    /// A valid durable phase is stronger recovery evidence than transient UI
    /// state. Pre-remote admission can safely retry; committed phases can run
    /// only local cleanup; only a remote-request phase has an unknown outcome.
    nonisolated static func accountDeletionRecoveryError(
        for phase: AccountDeletionFencePhase
    ) -> AccountDeletionError {
        switch phase {
        case .admissionClosed:
            return .safeToRetry
        case .remoteRequested:
            return .completionUncertain
        case .remoteCommitted, .localCleanupStarted:
            return .localCleanupFailed
        }
    }

    /// Exact typed preflight responses are known to occur before deletion
    /// state is created or destructive work begins. They can reopen admission
    /// only for a remote-request phase prepared by this same invocation. Every
    /// transport/service error, legacy REST 401, and resumed request remains
    /// fenced because none is durable completion evidence.
    nonisolated static func accountDeletionFailureDisposition(
        for error: Error,
        persistedPhase: AccountDeletionFencePhase,
        preparedRemoteRequestInCurrentAttempt: Bool
    ) -> AccountDeletionFailureDisposition {
        guard persistedPhase == .remoteRequested,
              preparedRemoteRequestInCurrentAttempt,
              let backendError = error as? BackendAccountDeletionError else {
            return AccountDeletionFailureDisposition.after(persistedPhase)
        }
        switch backendError {
        case .appleRevocationUnavailable,
             .socialReferenceCutoverIncomplete,
             .verifiedPreflightRequiresRecentAuthentication:
            return .clearFenceAndResumeProviderWork
        case .notConfigured, .requiresRecentAuthentication,
             .serviceUnavailable, .rejected, .invalidResponse:
            return .retainFenceAndKeepProviderWorkSuspended
        }
    }

    /// Compatibility entry point for diagnostics and older tests. Production
    /// deletion uses the registry owned by this AuthManager instance.
    static func clearAllUserData(for accountID: String) {
        try? AccountDataRegistry.production().deleteAllData(for: accountID)
        AutoGuidedFirstRep.cancelPendingLaunch()
    }

    nonisolated static func isAccountScopedDefaultsKey(
        _ key: String,
        accountID: String
    ) -> Bool {
        AccountDataRegistry.isAccountScopedDefaultsKey(key, accountID: accountID)
    }

    /// JSON-safe export of every account-scoped UserDefaults value currently
    /// present. Data values are decoded as JSON when possible and otherwise
    /// represented as base64 with an explicit encoding marker.
    nonisolated static func accountScopedDefaultsSnapshot(
        for accountID: String,
        defaults: UserDefaults = .standard
    ) -> [String: Any] {
        defaults.dictionaryRepresentation().reduce(into: [:]) { result, entry in
            guard isAccountScopedDefaultsKey(entry.key, accountID: accountID) else { return }
            result[entry.key] = jsonSafeDefaultsValue(entry.value)
        }
    }

    var accountDataParticipantIDs: [String] {
        accountDataRegistry.participantIDs
    }

    var accountDataCoverage: AccountDataCoverage {
        accountDataRegistry.coverage
    }

    func exportCurrentAccountData() async throws -> URL {
        guard let accountID = currentAccountID else {
            throw AccountDataExportError.noActiveAccount
        }
        return try await accountDataExportService.createExport(for: accountID)
    }

    func cleanupAccountDataExport(at url: URL?) {
        accountDataExportService.cleanupExport(at: url)
    }

    nonisolated private static func jsonSafeDefaultsValue(_ value: Any) -> Any {
        if let data = value as? Data {
            if let object = try? JSONSerialization.jsonObject(with: data),
               JSONSerialization.isValidJSONObject(object) {
                return object
            }
            return [
                "encoding": "base64",
                "value": data.base64EncodedString()
            ]
        }
        if let date = value as? Date {
            return ISO8601DateFormatter().string(from: date)
        }
        if JSONSerialization.isValidJSONObject(["value": value]) {
            return value
        }
        return String(describing: value)
    }

    private static func mapAccountDeletionError(_ error: Error) -> AccountDeletionError {
        if let error = error as? AccountDeletionError { return error }
        if error is AccountDataRegistryError { return .localCleanupFailed }
        guard let backendError = error as? BackendAccountDeletionError else {
            #if canImport(FirebaseAuth)
            if AuthErrorCode(rawValue: (error as NSError).code) == .requiresRecentLogin {
                return .requiresRecentAuthentication
            }
            #endif
            return .remoteRejected
        }
        switch backendError {
        case .verifiedPreflightRequiresRecentAuthentication,
             .requiresRecentAuthentication:
            return .requiresRecentAuthentication
        case .appleRevocationUnavailable:
            return .appleRevocationUnavailable
        case .socialReferenceCutoverIncomplete:
            return .secureDataUpgradeIncomplete
        case .notConfigured, .serviceUnavailable:
            return .serviceUnavailable
        case .rejected, .invalidResponse:
            return .remoteRejected
        }
    }

    private func deleteFirebaseUserIfNeeded(expectedAccountID: String) async throws {
        #if canImport(FirebaseAuth)
        guard isFirebaseAuthConfigured, let user = Auth.auth().currentUser else { return }
        guard user.uid == expectedAccountID else {
            throw AccountDeletionError.remoteRejected
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            user.delete { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
        #endif
    }

    var accountDeletionSupportURL: URL {
        let context = pendingDeletionSupportContext
        return NoumWebURLs.deletionSupportMail(
            requestReference: context?.requestReference,
            phase: context?.phase
        )
    }

    private var pendingDeletionSupportContext: (
        requestReference: String,
        phase: String
    )? {
        guard case .present(let fence) =
                accountDeletionFenceRepository.pendingLookup() else {
            return nil
        }
        return (fence.requestID.uuidString, fence.phase.rawValue)
    }

    func supportReportPayload() -> String {
        let provider = currentAuthProviderTitle ?? "Signed out"
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let issue = signInError ?? "Unknown sign-in error"
        let deletionContext = pendingDeletionSupportContext
        return """
        Noum Sign-In Report
        Timestamp: \(timestamp)
        Active provider: \(provider)
        Google configured: \(isGoogleSignInAvailable ? "yes" : "no")
        Deletion reference: \(deletionContext?.requestReference ?? "none")
        Local deletion phase: \(deletionContext?.phase ?? "none")
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
        guard admitSignInAgainstPendingDeletion(
            accountID: accountID,
            provider: provider
        ) else {
            return false
        }
        guard persistIdentity(accountID: accountID, name: name, provider: provider) else {
            let message = "Noum couldn't save this account on this device. Try again."
            signInError = message
            initialAccountHydrationState = .failed(message: message)
            return false
        }

        #if DEBUG
        print("Saved \(provider.title) user ID: \(accountID)")
        #endif
        accountUpgradeConflict = nil
        if let deletionError = pendingDeletionRecoveryError(for: accountID) {
            accountDeletionState = .failed(deletionError)
        } else {
            accountDeletionState = .idle
        }
        signInError = nil
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
        guard isProviderWorkAllowed(for: accountID) else {
            // Exact-account authentication may be needed for support-assisted
            // verification, but it cannot hydrate, sync, or republish account
            // data while the durable fence remains ambiguous.
            cancelActiveAccountHydration()
            accountDeletionState = .failed(
                pendingDeletionRecoveryError(for: accountID)
                    ?? .completionUncertain
            )
            initialAccountHydrationState = .ready
            deferFencedStoreSessionReset(accountID: accountID)
            return
        }
        cancelActiveAccountHydration()
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
            let recommendationStore = RecommendationLearningStore.shared
            let expectedRecommendationRevision = recommendationStore.stateRevision
            let recommendationHydrationRequiresMerge =
                recommendationStore.hasUnconfirmedDestructiveReset
                || recommendationStore.hasUnconfirmedSync
            var recommendationHydrationIsSafe = true
            if fetchRemote {
                recommendationHydrationIsSafe = await BackendSyncManager.shared.beginRecommendationHydration(
                    accountID: accountID,
                    hydrationToken: generation
                )
                // Register every mutation task before raising the lane's
                // hydration watermark. A durable reset also re-enqueues its
                // empty state after relaunch until remote confirmation.
                if recommendationHydrationIsSafe,
                   recommendationHydrationRequiresMerge {
                    recommendationStore.syncCurrentState()
                }
                await recommendationStore.waitForScheduledSyncs()
                if recommendationHydrationIsSafe {
                    recommendationHydrationIsSafe = await BackendSyncManager.shared.fenceRecommendationSync(
                        accountID: accountID,
                        revision: expectedRecommendationRevision,
                        hydrationToken: generation
                    )
                }
                guard self.isCurrentHydration(
                    generation: generation,
                    accountID: accountID,
                    providerRawValue: providerRawValue
                ) else {
                    await BackendSyncManager.shared.finishRecommendationHydration(
                        accountID: accountID,
                        hydrationToken: generation
                    )
                    return
                }
                if !recommendationHydrationIsSafe {
                    // The local whole-state write did not commit. Retry the
                    // current snapshot, but never let an older bootstrap
                    // replace it during this hydration generation.
                    RecommendationLearningStore.shared.syncCurrentState()
                } else if !recommendationHydrationRequiresMerge {
                    recommendationStore.confirmCurrentStateSync(
                        accountID: accountID,
                        revision: expectedRecommendationRevision
                    )
                }
            }

            // A locally saved profile is enough to route immediately. When a
            // remote-backed account has no local profile (for example, first
            // use on a second device), finish one authoritative backend read
            // before deciding that onboarding is genuinely needed.
            let shouldAwaitRemoteProfile = Self.shouldAwaitAuthoritativeRemoteProfile(
                fetchRemote: fetchRemote,
                hasLocalProfile: CoachingProfileStore.shared.profile != nil
            )

            if shouldAwaitRemoteProfile {
                let outcome = await self.boundedInitialRemoteProfileHydration(
                    accountID: accountID,
                    providerRawValue: providerRawValue
                )
                switch Self.initialRemoteProfileHydrationDisposition(for: outcome) {
                case .ready:
                    guard self.isCurrentHydration(
                        generation: generation,
                        accountID: accountID,
                        providerRawValue: providerRawValue
                    ) else {
                        await BackendSyncManager.shared.finishRecommendationHydration(
                            accountID: accountID,
                            hydrationToken: generation
                        )
                        return
                    }
                    guard case .fetched(.success(let bootstrap)) = outcome else {
                        await self.finishRecommendationHydration(
                            accountID: accountID,
                            generation: generation
                        )
                        return
                    }
                    self.applyBackendBootstrap(
                        bootstrap,
                        accountID: accountID,
                        providerRawValue: providerRawValue,
                        generation: generation,
                        expectedProfile: nil,
                        expectedRecommendationRevision: expectedRecommendationRevision,
                        recommendationHydrationIsSafe: recommendationHydrationIsSafe,
                        recommendationHydrationRequiresMerge: recommendationHydrationRequiresMerge
                    )
                    await self.finishRecommendationHydration(
                        accountID: accountID,
                        generation: generation
                    )
                case .retry:
                    guard self.isCurrentHydration(
                        generation: generation,
                        accountID: accountID,
                        providerRawValue: providerRawValue
                    ) else {
                        await BackendSyncManager.shared.finishRecommendationHydration(
                            accountID: accountID,
                            hydrationToken: generation
                        )
                        return
                    }
                    await self.finishRecommendationHydration(
                        accountID: accountID,
                        generation: generation
                    )
                    self.signInError = Self.remoteProfileRecoveryMessage
                    self.initialAccountHydrationState = .failed(
                        message: Self.remoteProfileRecoveryMessage
                    )
                    return
                case .superseded:
                    await BackendSyncManager.shared.finishRecommendationHydration(
                        accountID: accountID,
                        hydrationToken: generation
                    )
                    return
                }
            } else if fetchRemote {
                let expectedProfile = CoachingProfileStore.shared.profile
                Task { @MainActor in
                    await self.fetchAndApplyBackendBootstrap(
                        accountID: accountID,
                        providerRawValue: providerRawValue,
                        generation: generation,
                        expectedProfile: expectedProfile,
                        expectedRecommendationRevision: expectedRecommendationRevision,
                        recommendationHydrationIsSafe: recommendationHydrationIsSafe,
                        recommendationHydrationRequiresMerge: recommendationHydrationRequiresMerge
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
        accountLifecycleGeneration &+= 1
        NotificationPrePromptManager.shared.pendingPrompt = false
        DeferredProfileCaptureManager.shared.pendingPrompt = nil
        GoalRefreshManager.shared.shouldPresent = false
        accountDataRegistry.reloadForCurrentAccount()
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
        Self.shouldApplyHydrationBootstrap(
            requestedGeneration: generation,
            activeGeneration: activeAccountHydrationGeneration,
            requestedAccountID: accountID,
            requestedProviderRawValue: providerRawValue,
            currentAccountID: currentAccountID,
            currentProviderRawValue: currentAuthProviderRawValue
        )
    }

    nonisolated static func shouldApplyHydrationBootstrap(
        requestedGeneration: UUID,
        activeGeneration: UUID?,
        requestedAccountID: String,
        requestedProviderRawValue: String,
        currentAccountID: String?,
        currentProviderRawValue: String?
    ) -> Bool {
        requestedGeneration == activeGeneration
            && shouldApplyBackendBootstrap(
                requestedAccountID: requestedAccountID,
                requestedProviderRawValue: requestedProviderRawValue,
                currentAccountID: currentAccountID,
                currentProviderRawValue: currentProviderRawValue
            )
    }

    private nonisolated static func isLocalOnlyAccountID(_ accountID: String) -> Bool {
        accountID.hasPrefix(localGuestPrefix)
    }

    /// Local fallback guests own durable, account-scoped data on this device,
    /// but they have no Firebase identity that can authorize backend reads or
    /// writes. Keep this policy beside guest creation/hydration so every store
    /// uses the same identity boundary instead of inferring it from provider
    /// labels or waiting for Firestore to reject the request.
    nonisolated static func shouldSyncBackend(accountID: String) -> Bool {
        !isLocalOnlyAccountID(accountID)
    }

    static func shouldFetchRemoteForDurableIdentity(accountID: String) -> Bool {
        shouldFetchRemoteForGuestIdentity(accountID: accountID, origin: .restored)
    }

    static func shouldFetchRemoteForGuestIdentity(
        accountID: String,
        origin: GuestIdentityHydrationOrigin
    ) -> Bool {
        switch origin {
        case .freshlyCreated:
            return false
        case .restored:
            return shouldSyncBackend(accountID: accountID)
        }
    }

    nonisolated static func shouldAwaitAuthoritativeRemoteProfile(
        fetchRemote: Bool,
        hasLocalProfile: Bool
    ) -> Bool {
        fetchRemote && !hasLocalProfile
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

    private func cancelActiveAccountHydration() {
        activeAccountHydrationGeneration = nil
        activeInitialRemoteProfileHydrationRace?.resolve(.superseded)
        activeInitialRemoteProfileHydrationRace = nil
    }

    /// Provider choice is the only identity fact available before an OAuth UI
    /// returns. A matching provider may proceed to reauthenticate, but the
    /// resulting account is checked exactly before any durable identity write.
    private func allowPendingDeletionSignInIntent(provider: AuthProvider) -> Bool {
        switch accountDeletionFenceRepository.pendingLookup() {
        case .missing:
            return true
        case .present(let fence) where fence.providerRawValue == provider.rawValue:
            accountDeletionState = .failed(
                Self.accountDeletionRecoveryError(for: fence.phase)
            )
            return true
        case .present:
            accountDeletionState = .failed(.completionUncertain)
            signInError = "A different account cannot replace an unresolved deletion. Contact deletion support."
            return false
        case .ambiguous:
            accountDeletionState = .failed(.completionUncertain)
            signInError = "Noum couldn't read the pending deletion securely. Contact deletion support before signing in."
            return false
        }
    }

    /// Exact post-authentication admission. A same-account reauthentication is
    /// allowed to restore credentials, but a second account is never persisted
    /// over the durable deletion identity.
    private func admitSignInAgainstPendingDeletion(
        accountID: String,
        provider: AuthProvider
    ) -> Bool {
        switch accountDeletionFenceRepository.pendingLookup() {
        case .missing:
            return true
        case .present(let fence)
            where fence.accountID == accountID
                && fence.providerRawValue == provider.rawValue:
            return true
        case .present(let fence):
            signOutAttemptedFirebaseIdentity(accountID: accountID)
            _ = restorePendingDeletionIdentity(fence)
            signInError = "Noum kept the account with a pending deletion isolated. Contact deletion support before using another account."
            return false
        case .ambiguous:
            signOutAttemptedFirebaseIdentity(accountID: accountID)
            presentUnreadablePendingDeletion()
            return false
        }
    }

    /// Recovers the pending account after generic sign-out or relaunch. This is
    /// local identity recovery only; it does not claim the backend completed,
    /// resume provider work, or issue a deletion retry.
    @discardableResult
    private func restorePendingDeletionIdentityIfNeeded() -> Bool {
        switch accountDeletionFenceRepository.pendingLookup() {
        case .missing:
            return false
        case .present(let fence):
            _ = restorePendingDeletionIdentity(fence)
            return true
        case .ambiguous:
            presentUnreadablePendingDeletion()
            return true
        }
    }

    @discardableResult
    private func restorePendingDeletionIdentity(
        _ fence: AccountDeletionFence
    ) -> Bool {
        guard let provider = AuthProvider(rawValue: fence.providerRawValue) else {
            presentUnreadablePendingDeletion()
            return false
        }

        #if canImport(FirebaseAuth)
        if isFirebaseAuthConfigured,
           let firebaseUID = Auth.auth().currentUser?.uid,
           firebaseUID != fence.accountID {
            // A stale or newly authenticated B session is not deletion
            // authority for A. Signing B out is non-destructive.
            try? Auth.auth().signOut()
        }
        #endif

        let retainedName = currentAccountID == fence.accountID
            ? currentAccountName
            : nil
        guard persistIdentity(
            accountID: fence.accountID,
            name: retainedName,
            provider: provider
        ) else {
            presentUnreadablePendingDeletion()
            return false
        }

        accountLifecycleGeneration &+= 1
        cancelActiveGuestBootstrap()
        cancelActiveAccountHydration()
        isSignedIn = true
        authProvider = provider
        accountDeletionState = .failed(
            Self.accountDeletionRecoveryError(for: fence.phase)
        )
        initialAccountHydrationState = .ready
        deferPendingDeletionStoreSessionReset()
        return true
    }

    private func signOutAttemptedFirebaseIdentity(accountID: String) {
        #if canImport(FirebaseAuth)
        guard isFirebaseAuthConfigured,
              Auth.auth().currentUser?.uid == accountID else { return }
        try? Auth.auth().signOut()
        #endif
    }

    private func presentUnreadablePendingDeletion() {
        cancelActiveGuestBootstrap()
        cancelActiveAccountHydration()
        accountDeletionState = .failed(.completionUncertain)
        signInError = "Noum couldn't read the pending deletion securely. Contact deletion support before signing in."
        initialAccountHydrationState = .ready
        if let accountID = currentAccountID,
           let providerRawValue = currentAuthProviderRawValue,
           let provider = AuthProvider(rawValue: providerRawValue) {
            isSignedIn = true
            authProvider = provider
            deferFencedStoreSessionReset(accountID: accountID)
        } else {
            isSignedIn = false
            authProvider = nil
            deferPendingDeletionStoreSessionReset()
        }
    }

    private func resetDeletionStateForSignInIntent() {
        if let accountID = currentAccountID,
           let deletionError = pendingDeletionRecoveryError(for: accountID) {
            accountDeletionState = .failed(deletionError)
        } else {
            accountDeletionState = .idle
        }
    }

    private func pendingDeletionRecoveryError(
        for accountID: String
    ) -> AccountDeletionError? {
        switch accountDeletionFenceRepository.lookup(for: accountID) {
        case .missing:
            return nil
        case .present(let fence):
            return Self.accountDeletionRecoveryError(for: fence.phase)
        case .ambiguous:
            return .completionUncertain
        }
    }

    private func deferFencedStoreSessionReset(accountID: String) {
        Task { @MainActor in
            await Task.yield()
            guard self.currentAccountID == accountID,
                  !self.isProviderWorkAllowed(for: accountID) else {
                return
            }
            self.accountDataRegistry.endSession()
        }
    }

    private func deferStoreSessionReset() {
        Task { @MainActor in
            await Task.yield()
            // A clean-launch guest bootstrap or a new sign-in may have won the
            // next actor turn. Never let a stale signed-out reset erase the
            // newly active account's hydrated stores.
            guard self.currentAccountID == nil else { return }
            NotificationPrePromptManager.shared.pendingPrompt = false
            DeferredProfileCaptureManager.shared.pendingPrompt = nil
            GoalRefreshManager.shared.shouldPresent = false
            self.accountDataRegistry.endSession()
        }
    }

    private func deferPendingDeletionStoreSessionReset() {
        Task { @MainActor in
            await Task.yield()
            guard self.accountDeletionFenceRepository.pendingLookup() != .missing else {
                return
            }
            NotificationPrePromptManager.shared.pendingPrompt = false
            DeferredProfileCaptureManager.shared.pendingPrompt = nil
            GoalRefreshManager.shared.shouldPresent = false
            self.accountDataRegistry.endSession()
        }
    }

    private func clearStoredSession() {
        accountLifecycleGeneration &+= 1
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

    private func boundedInitialRemoteProfileHydration(
        accountID: String,
        providerRawValue: String
    ) async -> InitialRemoteProfileHydrationOutcome {
        let race = InitialRemoteProfileHydrationRace()
        activeInitialRemoteProfileHydrationRace = race

        // Deliberately unstructured. A structured timeout race would still
        // wait for a cancelled Firestore continuation that never resumes.
        Task { @MainActor in
            let bootstrap = await BackendSyncManager.shared.fetchBootstrap(
                accountID: accountID,
                providerRawValue: providerRawValue
            )
            race.resolve(.fetched(bootstrap))
        }

        let outcome = await Self.waitForInitialRemoteProfileHydration(
            race: race,
            timeoutNanoseconds: Self.initialRemoteProfileTimeoutNanoseconds
        )
        if activeInitialRemoteProfileHydrationRace === race {
            activeInitialRemoteProfileHydrationRace = nil
        }
        return outcome
    }

    static func waitForInitialRemoteProfileHydration(
        race: InitialRemoteProfileHydrationRace,
        timeoutNanoseconds: UInt64
    ) async -> InitialRemoteProfileHydrationOutcome {
        // This timer is intentionally unstructured so resolving the deadline
        // never waits for the remote operation to acknowledge cancellation.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: timeoutNanoseconds)
            race.resolve(.timedOut)
        }
        return await race.wait()
    }

    static func shouldReplaceHydratedProfile(
        expectedProfile: CoachingProfile?,
        currentProfile: CoachingProfile?
    ) -> Bool {
        expectedProfile == currentProfile
    }

    static func initialRemoteProfileHydrationDisposition(
        for outcome: InitialRemoteProfileHydrationOutcome
    ) -> InitialRemoteProfileHydrationDisposition {
        switch outcome {
        case .fetched(.success):
            return .ready
        case .fetched(.unavailable), .timedOut:
            return .retry
        case .superseded:
            return .superseded
        }
    }

    private func fetchAndApplyBackendBootstrap(
        accountID: String,
        providerRawValue: String,
        generation: UUID,
        expectedProfile: CoachingProfile?,
        expectedRecommendationRevision: Int,
        recommendationHydrationIsSafe: Bool,
        recommendationHydrationRequiresMerge: Bool
    ) async {
        let outcome = await boundedInitialRemoteProfileHydration(
            accountID: accountID,
            providerRawValue: providerRawValue
        )
        guard isCurrentHydration(
            generation: generation,
            accountID: accountID,
            providerRawValue: providerRawValue
        ) else {
            await BackendSyncManager.shared.finishRecommendationHydration(
                accountID: accountID,
                hydrationToken: generation
            )
            return
        }
        if case .fetched(.success(let bootstrap)) = outcome {
            applyBackendBootstrap(
                bootstrap,
                accountID: accountID,
                providerRawValue: providerRawValue,
                generation: generation,
                expectedProfile: expectedProfile,
                expectedRecommendationRevision: expectedRecommendationRevision,
                recommendationHydrationIsSafe: recommendationHydrationIsSafe,
                recommendationHydrationRequiresMerge: recommendationHydrationRequiresMerge
            )
        }
        await finishRecommendationHydration(
            accountID: accountID,
            generation: generation
        )
    }

    private func finishRecommendationHydration(
        accountID: String,
        generation: UUID
    ) async {
        await RecommendationLearningStore.shared.waitForScheduledSyncs()
        await BackendSyncManager.shared.finishRecommendationHydration(
            accountID: accountID,
            hydrationToken: generation
        )
    }

    private func applyBackendBootstrap(
        _ bootstrap: BackendBootstrap,
        accountID: String,
        providerRawValue: String,
        generation: UUID,
        expectedProfile: CoachingProfile?,
        expectedRecommendationRevision: Int,
        recommendationHydrationIsSafe: Bool,
        recommendationHydrationRequiresMerge: Bool
    ) {

        guard Self.shouldApplyHydrationBootstrap(
            requestedGeneration: generation,
            activeGeneration: activeAccountHydrationGeneration,
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
        // If onboarding or Settings saved while this request was in flight,
        // that newer local profile owns the decision and must not be replaced.
        if let profile = bootstrap.profile,
           Self.shouldReplaceHydratedProfile(
               expectedProfile: expectedProfile,
               currentProfile: CoachingProfileStore.shared.profile
           ) {
            CoachingProfileStore.shared.replaceFromRemote(profile, for: accountID)
        }
        if let sessions = bootstrap.sessions {
            PracticeSessionStore.shared.replaceFromRemote(sessions)
        }
        let recommendationStore = RecommendationLearningStore.shared
        if recommendationHydrationIsSafe,
           bootstrap.hasAuthoritativeRecommendationState {
            if recommendationStore.hasUnconfirmedDestructiveReset {
                let remoteResetIsConfirmed = recommendationStore.unconfirmedDestructiveResetAt.map {
                    Self.recommendationResetIsConfirmed(
                        resetAt: $0,
                        pendingExposure: bootstrap.recommendationPending,
                        outcomes: bootstrap.recommendationOutcomes ?? []
                    )
                } ?? false
                if remoteResetIsConfirmed {
                    recommendationStore.confirmDestructiveReset()
                } else {
                    // The local destructive intent remains newer than this
                    // bootstrap. Keep the empty ledger and retry it.
                    recommendationStore.syncCurrentState()
                    return
                }
            }
            let didReplace = !recommendationHydrationRequiresMerge
                && recommendationStore.replaceFromRemote(
                    pendingExposure: bootstrap.recommendationPending,
                    outcomes: bootstrap.recommendationOutcomes ?? [],
                    remoteRevision: bootstrap.recommendationRemoteRevision,
                    ifUnchangedSince: expectedRecommendationRevision
                )
            if !didReplace,
               recommendationStore.reconcileRemoteState(
                   pendingExposure: bootstrap.recommendationPending,
                   outcomes: bootstrap.recommendationOutcomes ?? [],
                   remoteRevision: bootstrap.recommendationRemoteRevision,
                   changedSince: expectedRecommendationRevision,
                   force: recommendationHydrationRequiresMerge
               ) {
                // Local work happened during the fetch. Restore any unseen
                // remote outcomes into that newer state before syncing it.
                recommendationStore.syncCurrentState()
            }
        } else if recommendationHydrationIsSafe,
                  !bootstrap.hasAuthoritativeRecommendationState,
                  recommendationStore.hasStateToSync {
            // A confirmed absent document can happen on a legacy install or
            // after backend migration. Preserve and seed real local evidence;
            // the hydration queue prevents an in-flight local write from
            // racing ahead of this read.
            recommendationStore.syncCurrentState()
        }
    }

    nonisolated static func recommendationResetIsConfirmed(
        resetAt: Date,
        pendingExposure: RecommendationExposure?,
        outcomes: [RecommendationOutcome]
    ) -> Bool {
        let pendingIsCurrent = pendingExposure.map { $0.shownAt >= resetAt } ?? true
        return pendingIsCurrent && outcomes.allSatisfy { $0.completedAt >= resetAt }
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
    private func authenticateWithFirebase(
        credential: FirebaseAuth.AuthCredential,
        provider: AuthProvider
    ) async throws -> FirebaseAuth.AuthDataResult {
        let firebaseUser = Auth.auth().currentUser
        switch Self.firebaseCredentialStrategy(
            persistedAccountID: currentAccountID,
            persistedProviderRawValue: currentAuthProviderRawValue,
            firebaseUID: firebaseUser?.uid,
            firebaseUserIsAnonymous: firebaseUser?.isAnonymous == true
        ) {
        case .linkAnonymousUser:
            guard let firebaseUser else {
                throw AccountUpgradeConflict.localGuestMigrationRequired(provider)
            }
            return try await linkFirebaseUser(firebaseUser, with: credential)
        case .preserveLocalGuest:
            throw AccountUpgradeConflict.localGuestMigrationRequired(provider)
        case .signIn:
            return try await signInWithFirebase(credential: credential)
        }
    }

    private func signInWithFirebase(
        credential: FirebaseAuth.AuthCredential
    ) async throws -> FirebaseAuth.AuthDataResult {
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

    private func linkFirebaseUser(
        _ user: FirebaseAuth.User,
        with credential: FirebaseAuth.AuthCredential
    ) async throws -> FirebaseAuth.AuthDataResult {
        try await withCheckedThrowingContinuation { continuation in
            user.link(with: credential) { authResult, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let authResult else {
                    continuation.resume(throwing: NSError(
                        domain: "AuthManager",
                        code: -2,
                        userInfo: [NSLocalizedDescriptionKey: "Firebase account linking returned no user."]
                    ))
                    return
                }
                continuation.resume(returning: authResult)
            }
        }
    }

    private func presentCredentialError(_ error: Error, provider: AuthProvider) {
        let conflict: AccountUpgradeConflict?
        if let typed = error as? AccountUpgradeConflict {
            conflict = typed
        } else {
            let code = AuthErrorCode(rawValue: (error as NSError).code)
            switch code {
            case .credentialAlreadyInUse, .emailAlreadyInUse, .accountExistsWithDifferentCredential:
                conflict = .credentialAlreadyInUse(provider)
            default:
                conflict = nil
            }
        }

        if let conflict {
            accountUpgradeConflict = conflict
            signInError = conflict.errorDescription
            return
        }

        switch provider {
        case .apple:
            #if canImport(AuthenticationServices)
            signInError = friendlyAppleSignInMessage(for: error)
            #else
            signInError = error.localizedDescription
            #endif
        case .google:
            #if canImport(GoogleSignIn)
            signInError = friendlyGoogleSignInMessage(for: error)
            #else
            signInError = error.localizedDescription
            #endif
        case .guest:
            signInError = error.localizedDescription
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

    /// Builds deletion headers from one captured Firebase user and verifies
    /// ambient auth still names that exact account after token refresh. Unlike
    /// ordinary headers, this never falls back to client identity headers when
    /// Firebase is configured but the expected user cannot be proven.
    static func deletionBound(
        accountID: String,
        providerRawValue: String,
        env: [String: String] = ProcessInfo.processInfo.environment,
        configValue: (String) -> String? = { key in
            LocalConfigLoader.value(forKey: key, plistNamed: "BackendConfig")
        }
    ) async -> BackendAuthHeaders? {
        let normalizedAccountID = cleaned(accountID)
        let normalizedProvider = cleaned(providerRawValue)
        guard normalizedAccountID == accountID,
              normalizedProvider == providerRawValue else {
            return nil
        }

        #if canImport(FirebaseAuth) && canImport(FirebaseCore)
        if FirebaseApp.app() != nil {
            guard let user = Auth.auth().currentUser,
                  deletionIdentityMatches(
                    expectedAccountID: accountID,
                    capturedUserID: user.uid,
                    currentUserID: user.uid
                  ) else {
                return nil
            }
            let token: String
            do {
                token = try await withCheckedThrowingContinuation { continuation in
                    user.getIDTokenForcingRefresh(true) { token, error in
                        if let error {
                            continuation.resume(throwing: error)
                        } else if let token {
                            continuation.resume(returning: token)
                        } else {
                            continuation.resume(throwing: URLError(.userAuthenticationRequired))
                        }
                    }
                }
            } catch {
                return nil
            }
            guard let currentUserID = Auth.auth().currentUser?.uid,
                  deletionIdentityMatches(
                    expectedAccountID: accountID,
                    capturedUserID: user.uid,
                    currentUserID: currentUserID
                  ), cleaned(token) != nil else {
                return nil
            }
            return BackendAuthHeaders(
                accountID: accountID,
                providerRawValue: providerRawValue,
                apiKey: configuredAPIKey(env: env, configValue: configValue),
                firebaseIDToken: token
            )
        }
        #endif

        return BackendAuthHeaders(
            accountID: accountID,
            providerRawValue: providerRawValue,
            apiKey: configuredAPIKey(env: env, configValue: configValue),
            firebaseIDToken: nil
        )
    }

    nonisolated static func deletionIdentityMatches(
        expectedAccountID: String,
        capturedUserID: String?,
        currentUserID: String?
    ) -> Bool {
        guard let expected = cleaned(expectedAccountID),
              expected == expectedAccountID else { return false }
        return capturedUserID == expected && currentUserID == expected
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
