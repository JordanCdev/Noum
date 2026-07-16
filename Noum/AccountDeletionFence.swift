import Foundation

#if canImport(Security)
import Security
#endif

/// Durable, monotonic account-deletion progress. The phase is intentionally
/// small: it records only enough to keep provider admission closed and retain
/// a stable server-correlation ID. It is not evidence that the backend
/// completed deletion or that a backend request can be resumed.
enum AccountDeletionFencePhase: String, Codable, CaseIterable, Equatable, Sendable {
    case admissionClosed
    case remoteRequested
    case remoteCommitted
    case localCleanupStarted

    fileprivate var ordinal: Int {
        switch self {
        case .admissionClosed: return 0
        case .remoteRequested: return 1
        case .remoteCommitted: return 2
        case .localCleanupStarted: return 3
        }
    }
}

struct AccountDeletionFence: Codable, Equatable, Sendable {
    static let schemaVersion = 2

    let schemaVersion: Int
    let accountID: String
    /// Recovery identity only. The backend still derives authority from its
    /// verified Firebase token and compares that UID with the request binding.
    let providerRawValue: String
    let requestID: UUID
    let phase: AccountDeletionFencePhase

    init(
        accountID: String,
        providerRawValue: String,
        requestID: UUID,
        phase: AccountDeletionFencePhase
    ) {
        self.schemaVersion = Self.schemaVersion
        self.accountID = accountID
        self.providerRawValue = providerRawValue
        self.requestID = requestID
        self.phase = phase
    }

    func advancing(to phase: AccountDeletionFencePhase) -> AccountDeletionFence {
        AccountDeletionFence(
            accountID: accountID,
            providerRawValue: providerRawValue,
            requestID: requestID,
            phase: phase
        )
    }
}

enum AccountDeletionFenceStorageRead: Equatable {
    case missing
    case value(String)
    case unavailable
}

/// The protocol exists to prove phase and recovery behavior without pretending
/// a fake store proves Keychain durability. Production always uses the Security
/// implementation below; focused tests exercise the repository contract.
protocol AccountDeletionFenceStorage {
    func read(key: String) -> AccountDeletionFenceStorageRead
    func write(_ value: String, key: String) -> Bool
    func remove(key: String) -> Bool
}

struct KeychainAccountDeletionFenceStorage: AccountDeletionFenceStorage {
    private static let service = "Noum"

    func read(key: String) -> AccountDeletionFenceStorageRead {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecItemNotFound:
            return .missing
        case errSecSuccess:
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                return .unavailable
            }
            return .value(value)
        default:
            // `KeychainHelper.load` intentionally has a convenient optional
            // API, but deletion admission must distinguish absence from an
            // unreadable Keychain and fail closed on the latter.
            return .unavailable
        }
        #else
        return .unavailable
        #endif
    }

    func write(_ value: String, key: String) -> Bool {
        #if canImport(Security)
        return KeychainHelper.save(value, key: key)
        #else
        return false
        #endif
    }

    func remove(key: String) -> Bool {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
        #else
        return false
        #endif
    }
}

enum AccountDeletionFenceLookup: Equatable {
    case missing
    case present(AccountDeletionFence)
    /// Includes an unavailable Keychain, corrupt payload, wrong account, or
    /// unsupported schema. All are ambiguous and therefore deny provider work.
    case ambiguous
}

enum AccountDeletionFenceRepositoryError: Error, Equatable {
    case invalidAccountID
    case invalidProvider
    case unavailableOrCorrupt
    case persistenceFailed
    case invalidPhaseTransition
    case requestMismatch
    case pendingAccountMismatch
    case removalFailed
}

enum AccountDeletionFailureDisposition: Equatable {
    /// Nothing destructive can have crossed the process boundary. The fence may
    /// be removed after read verification and provider work explicitly resumed.
    case clearFenceAndResumeProviderWork
    /// A remote request may have been observed, or local cleanup may have begun.
    /// Keep the durable fence. The current server exposes neither a durable
    /// completion receipt nor an unauthenticated recovery endpoint after Auth
    /// deletion, so a client retry must not be treated as completion proof.
    case retainFenceAndKeepProviderWorkSuspended

    static func after(_ phase: AccountDeletionFencePhase) -> Self {
        switch phase {
        case .admissionClosed:
            return .clearFenceAndResumeProviderWork
        case .remoteRequested, .remoteCommitted, .localCleanupStarted:
            return .retainFenceAndKeepProviderWorkSuspended
        }
    }
}

/// Pure persistence boundary used by AuthManager. A single discoverable record
/// is authoritative because AuthManager supports one active identity at a
/// time. Storing the recovery identity and fence together avoids a torn
/// two-key index/fence write that could orphan an account after sign-out.
/// Every mutation is immediately read back before the caller may advance.
struct AccountDeletionFenceRepository {
    static let keyPrefix = "noum.accountDeletionFence."
    static let activeKey = keyPrefix + "active"

    private let storage: any AccountDeletionFenceStorage
    private let makeRequestID: () -> UUID

    init(
        storage: any AccountDeletionFenceStorage,
        makeRequestID: @escaping () -> UUID = UUID.init
    ) {
        self.storage = storage
        self.makeRequestID = makeRequestID
    }

    func lookup(for accountID: String) -> AccountDeletionFenceLookup {
        guard let accountID = Self.normalizedAccountID(accountID) else {
            return .ambiguous
        }
        switch pendingLookup() {
        case .missing:
            return .missing
        case .ambiguous:
            return .ambiguous
        case .present(let fence):
            // A different pending account is not "missing". Treat it as an
            // admission conflict so no second identity can start provider
            // work while the first account remains unresolved.
            guard fence.accountID == accountID else { return .ambiguous }
            return .present(fence)
        }
    }

    /// Discovers the pending account without relying on the ordinary identity
    /// keys, which generic sign-out is allowed to clear.
    func pendingLookup() -> AccountDeletionFenceLookup {
        switch storage.read(key: Self.activeKey) {
        case .missing:
            return .missing
        case .unavailable:
            return .ambiguous
        case .value(let value):
            guard let data = value.data(using: .utf8),
                  let fence = try? JSONDecoder().decode(AccountDeletionFence.self, from: data),
                  Self.isValid(fence, expectedAccountID: fence.accountID) else {
                return .ambiguous
            }
            return .present(fence)
        }
    }

    func isProviderWorkAllowed(for accountID: String) -> Bool {
        guard Self.normalizedAccountID(accountID) != nil else { return false }
        // Globally fail closed while the one supported Auth identity has a
        // pending deletion. This is stronger than account-key lookup and
        // prevents a new account from bootstrapping into active provider work.
        return pendingLookup() == .missing
    }

    /// Reuses the one verified in-flight request. A new request is created only
    /// when the globally discoverable record is authoritatively absent.
    func beginOrResume(
        for accountID: String,
        providerRawValue: String
    ) -> Result<AccountDeletionFence, AccountDeletionFenceRepositoryError> {
        guard let accountID = Self.normalizedAccountID(accountID) else {
            return .failure(.invalidAccountID)
        }
        guard let providerRawValue = Self.normalizedProvider(providerRawValue) else {
            return .failure(.invalidProvider)
        }
        switch pendingLookup() {
        case .present(let fence) where fence.accountID == accountID
                && fence.providerRawValue == providerRawValue:
            return .success(fence)
        case .present:
            return .failure(.pendingAccountMismatch)
        case .ambiguous:
            return .failure(.unavailableOrCorrupt)
        case .missing:
            let requestID = makeRequestID()
            guard requestID != Self.zeroUUID else {
                return .failure(.persistenceFailed)
            }
            let fence = AccountDeletionFence(
                accountID: accountID,
                providerRawValue: providerRawValue,
                requestID: requestID,
                phase: .admissionClosed
            )
            return persistAndVerify(fence).map { _ in fence }
        }
    }

    /// Advances exactly one phase. Rewriting the same phase performs only a
    /// read verification; regression and skipped phases are rejected.
    func advance(
        _ fence: AccountDeletionFence,
        to phase: AccountDeletionFencePhase
    ) -> Result<AccountDeletionFence, AccountDeletionFenceRepositoryError> {
        guard Self.isValid(fence, expectedAccountID: fence.accountID) else {
            return .failure(.unavailableOrCorrupt)
        }
        switch pendingLookup() {
        case .present(let stored) where stored == fence:
            break
        case .ambiguous:
            return .failure(.unavailableOrCorrupt)
        case .missing, .present:
            // A stale in-memory request must never overwrite a newer durable
            // request or advance from a phase that was not actually observed.
            return .failure(.requestMismatch)
        }
        if phase == fence.phase {
            return .success(fence)
        }
        guard phase.ordinal == fence.phase.ordinal + 1 else {
            return .failure(.invalidPhaseTransition)
        }
        let advanced = fence.advancing(to: phase)
        return persistAndVerify(advanced).map { _ in advanced }
    }

    /// Clears only the exact completed request, then verifies authoritative
    /// absence. A generic sign-out never calls this API.
    func clearVerified(_ fence: AccountDeletionFence) -> Result<Void, AccountDeletionFenceRepositoryError> {
        switch pendingLookup() {
        case .missing:
            return .success(())
        case .ambiguous:
            return .failure(.unavailableOrCorrupt)
        case .present(let stored):
            guard stored.requestID == fence.requestID else {
                return .failure(.requestMismatch)
            }
            guard stored == fence else {
                return .failure(.requestMismatch)
            }
            guard storage.remove(key: Self.activeKey),
                  pendingLookup() == .missing else {
                return .failure(.removalFailed)
            }
            return .success(())
        }
    }

    private func persistAndVerify(
        _ fence: AccountDeletionFence
    ) -> Result<Void, AccountDeletionFenceRepositoryError> {
        guard let value = Self.encoded(fence),
              storage.write(value, key: Self.activeKey) else {
            return .failure(.persistenceFailed)
        }
        guard storage.read(key: Self.activeKey) == .value(value),
              lookup(for: fence.accountID) == .present(fence) else {
            return .failure(.persistenceFailed)
        }
        return .success(())
    }

    private static func encoded(_ fence: AccountDeletionFence) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(fence) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func isValid(
        _ fence: AccountDeletionFence,
        expectedAccountID: String
    ) -> Bool {
        fence.schemaVersion == AccountDeletionFence.schemaVersion
            && fence.accountID == expectedAccountID
            && normalizedAccountID(fence.accountID) == fence.accountID
            && normalizedProvider(fence.providerRawValue) == fence.providerRawValue
            && fence.requestID != zeroUUID
    }

    private static func normalizedAccountID(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func normalizedProvider(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static let zeroUUID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
}
