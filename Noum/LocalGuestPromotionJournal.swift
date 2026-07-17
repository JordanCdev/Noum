import Foundation

#if canImport(Security)
import Security
#endif

/// Durable progress for the one supported local-guest promotion route:
/// `local-guest-*` -> a newly minted anonymous Firebase UID. The journal holds
/// identity metadata only; coaching content remains in its account-scoped
/// UserDefaults namespace until the verified copy has completed.
enum LocalGuestPromotionPhase: String, Codable, CaseIterable, Equatable, Sendable {
    case authorityAcquired
    case dataCopied
    case identityCommitted

    fileprivate var ordinal: Int {
        switch self {
        case .authorityAcquired: return 0
        case .dataCopied: return 1
        case .identityCommitted: return 2
        }
    }
}

struct LocalGuestPromotionJournal: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let requestID: UUID
    let sourceAccountID: String
    let targetAccountID: String
    let phase: LocalGuestPromotionPhase

    init(
        requestID: UUID,
        sourceAccountID: String,
        targetAccountID: String,
        phase: LocalGuestPromotionPhase
    ) {
        self.schemaVersion = Self.schemaVersion
        self.requestID = requestID
        self.sourceAccountID = sourceAccountID
        self.targetAccountID = targetAccountID
        self.phase = phase
    }

    func advancing(to phase: LocalGuestPromotionPhase) -> Self {
        Self(
            requestID: requestID,
            sourceAccountID: sourceAccountID,
            targetAccountID: targetAccountID,
            phase: phase
        )
    }
}

enum LocalGuestPromotionJournalStorageRead: Equatable {
    case missing
    case value(String)
    case unavailable
}

protocol LocalGuestPromotionJournalStorage {
    func read(key: String) -> LocalGuestPromotionJournalStorageRead
    func write(_ value: String, key: String) -> Bool
    func remove(key: String) -> Bool
}

struct KeychainLocalGuestPromotionJournalStorage: LocalGuestPromotionJournalStorage {
    private static let service = "Noum"

    func read(key: String) -> LocalGuestPromotionJournalStorageRead {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        switch SecItemCopyMatching(query as CFDictionary, &result) {
        case errSecItemNotFound:
            return .missing
        case errSecSuccess:
            guard let data = result as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                return .unavailable
            }
            return .value(value)
        default:
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
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
        #else
        return false
        #endif
    }
}

enum LocalGuestPromotionJournalLookup: Equatable {
    case missing
    case present(LocalGuestPromotionJournal)
    /// An unavailable Keychain, corrupt payload, or unsupported schema is not
    /// equivalent to no migration. Provider work must fail closed.
    case ambiguous
}

enum LocalGuestPromotionJournalError: Error, Equatable {
    case invalidSource
    case invalidTarget
    case unavailableOrCorrupt
    case persistenceFailed
    case invalidPhaseTransition
    case requestMismatch
    case activePromotionMismatch
    case removalFailed
}

struct LocalGuestPromotionJournalRepository {
    static let activeKey = "noum.localGuestPromotion.active"

    private let storage: any LocalGuestPromotionJournalStorage
    private let makeRequestID: () -> UUID

    init(
        storage: any LocalGuestPromotionJournalStorage,
        makeRequestID: @escaping () -> UUID = UUID.init
    ) {
        self.storage = storage
        self.makeRequestID = makeRequestID
    }

    func pendingLookup() -> LocalGuestPromotionJournalLookup {
        switch storage.read(key: Self.activeKey) {
        case .missing:
            return .missing
        case .unavailable:
            return .ambiguous
        case .value(let value):
            guard let data = value.data(using: .utf8),
                  let journal = try? JSONDecoder().decode(
                    LocalGuestPromotionJournal.self,
                    from: data
                  ),
                  Self.isValid(journal) else {
                return .ambiguous
            }
            return .present(journal)
        }
    }

    /// Before the identity commit, neither account may start provider work.
    /// Once the durable owner and Firebase UID are the target, normal provider
    /// work is safe even while best-effort backend seeding/source cleanup is
    /// finishing; identity-sensitive account mutations remain separately
    /// blocked by AuthManager until the journal clears.
    func isProviderWorkAllowed(for accountID: String) -> Bool {
        guard let accountID = Self.normalized(accountID) else { return false }
        switch pendingLookup() {
        case .missing:
            return true
        case .present(let journal):
            return journal.phase == .identityCommitted
                && journal.targetAccountID == accountID
        case .ambiguous:
            return false
        }
    }

    func beginOrResume(
        sourceAccountID: String,
        targetAccountID: String
    ) -> Result<LocalGuestPromotionJournal, LocalGuestPromotionJournalError> {
        guard let source = Self.normalized(sourceAccountID),
              source.hasPrefix("local-guest-") else {
            return .failure(.invalidSource)
        }
        guard let target = Self.normalized(targetAccountID),
              target != source,
              !target.hasPrefix("local-guest-") else {
            return .failure(.invalidTarget)
        }
        switch pendingLookup() {
        case .ambiguous:
            return .failure(.unavailableOrCorrupt)
        case .present(let existing):
            guard existing.sourceAccountID == source,
                  existing.targetAccountID == target else {
                return .failure(.activePromotionMismatch)
            }
            return .success(existing)
        case .missing:
            let requestID = makeRequestID()
            guard requestID != Self.zeroUUID else {
                return .failure(.persistenceFailed)
            }
            let journal = LocalGuestPromotionJournal(
                requestID: requestID,
                sourceAccountID: source,
                targetAccountID: target,
                phase: .authorityAcquired
            )
            return persistAndVerify(journal).map { journal }
        }
    }

    func advance(
        _ journal: LocalGuestPromotionJournal,
        to phase: LocalGuestPromotionPhase
    ) -> Result<LocalGuestPromotionJournal, LocalGuestPromotionJournalError> {
        guard Self.isValid(journal) else {
            return .failure(.unavailableOrCorrupt)
        }
        guard case .present(let persisted) = pendingLookup() else {
            return .failure(.unavailableOrCorrupt)
        }
        guard persisted.requestID == journal.requestID,
              persisted.sourceAccountID == journal.sourceAccountID,
              persisted.targetAccountID == journal.targetAccountID else {
            return .failure(.requestMismatch)
        }
        if persisted.phase == phase {
            return .success(persisted)
        }
        guard phase.ordinal == persisted.phase.ordinal + 1 else {
            return .failure(.invalidPhaseTransition)
        }
        let advanced = persisted.advancing(to: phase)
        return persistAndVerify(advanced).map { advanced }
    }

    func clearVerified(
        _ journal: LocalGuestPromotionJournal
    ) -> Result<Void, LocalGuestPromotionJournalError> {
        guard case .present(let persisted) = pendingLookup(),
              persisted == journal else {
            return .failure(.requestMismatch)
        }
        guard storage.remove(key: Self.activeKey) else {
            return .failure(.removalFailed)
        }
        guard storage.read(key: Self.activeKey) == .missing else {
            return .failure(.removalFailed)
        }
        return .success(())
    }

    private func persistAndVerify(
        _ journal: LocalGuestPromotionJournal
    ) -> Result<Void, LocalGuestPromotionJournalError> {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(journal),
              let value = String(data: data, encoding: .utf8),
              storage.write(value, key: Self.activeKey),
              storage.read(key: Self.activeKey) == .value(value),
              pendingLookup() == .present(journal) else {
            return .failure(.persistenceFailed)
        }
        return .success(())
    }

    private static func isValid(_ journal: LocalGuestPromotionJournal) -> Bool {
        journal.schemaVersion == LocalGuestPromotionJournal.schemaVersion
            && journal.requestID != zeroUUID
            && normalized(journal.sourceAccountID) == journal.sourceAccountID
            && journal.sourceAccountID.hasPrefix("local-guest-")
            && normalized(journal.targetAccountID) == journal.targetAccountID
            && !journal.targetAccountID.hasPrefix("local-guest-")
            && journal.sourceAccountID != journal.targetAccountID
    }

    private static func normalized(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static let zeroUUID = UUID(
        uuidString: "00000000-0000-0000-0000-000000000000"
    )!
}
