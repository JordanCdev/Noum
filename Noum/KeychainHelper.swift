#if canImport(Security)
import Foundation
import Security

enum KeychainHelper {
    private static let productionService = "Noum"
    private static let uiTestingService = "Noum.UITesting"
    private static let accountKey = "NoumAccountID"
    private static let accountProviderKey = "NoumAccountProvider"

    #if DEBUG
    struct UIAutomationIdentity: Equatable, Sendable {
        let accountID: String
        let providerRawValue: String
    }

    /// One precedence-ordered launch contract for UI automation. Test flags
    /// sometimes accumulate across relaunch helpers; resolving them once keeps
    /// credential reset, hydration, rendered auth state, and seed ownership
    /// from interpreting the same process differently.
    enum UIAutomationLaunchMode: Equatable, Sendable {
        case production
        case signedOut
        case realFirstRun
        case restorePersistedAccount
        case authenticatedCoach
        case seeded
        case empty
    }

    static func uiAutomationLaunchMode(
        arguments: [String]
    ) -> UIAutomationLaunchMode {
        guard arguments.contains("UI_TESTING") else { return .production }
        if arguments.contains("UI_TESTING_SIGNED_OUT") {
            return .signedOut
        }
        if arguments.contains("UI_TESTING_REAL_FIRST_RUN") {
            return .realFirstRun
        }
        if arguments.contains("UI_TESTING_RESTORE_PERSISTED_ACCOUNT") {
            return .restorePersistedAccount
        }
        if arguments.contains("UI_TESTING_AUTHENTICATED_COACH") {
            return .authenticatedCoach
        }
        if arguments.contains("UI_TESTING_SEED")
            || arguments.contains("UI_TESTING_SEED_FORCE") {
            return .seeded
        }
        return .empty
    }

    /// UI automation must never read or mutate the credentials used by a
    /// normal app launch. The dedicated service remains durable across UI-test
    /// process relaunches, so real-first-run coverage can still verify account
    /// restoration without sharing the production credential namespace.
    static func storageService(arguments: [String]) -> String {
        arguments.contains("UI_TESTING") ? uiTestingService : productionService
    }

    /// Resolves the durable identity that rendered fixtures write into the
    /// isolated service before any account-scoped singleton initializes.
    /// AuthManager remains the sole runtime identity owner: this is only the
    /// test storage setup that its normal Keychain reads consume.
    static func uiAutomationIdentity(
        arguments: [String]
    ) -> UIAutomationIdentity? {
        switch uiAutomationLaunchMode(arguments: arguments) {
        case .authenticatedCoach:
            return UIAutomationIdentity(
                accountID: "ui-test-coach-account",
                providerRawValue: "guest"
            )
        case .seeded:
            return UIAutomationIdentity(
                accountID: "local-guest-ui-test-seeded-account",
                providerRawValue: "guest"
            )
        case .production, .signedOut, .realFirstRun,
             .restorePersistedAccount, .empty:
            return nil
        }
    }

    static func shouldResetUIAutomationStorage(arguments: [String]) -> Bool {
        switch uiAutomationLaunchMode(arguments: arguments) {
        case .production, .restorePersistedAccount:
            return false
        case .signedOut, .realFirstRun, .authenticatedCoach, .seeded, .empty:
            return true
        }
    }

    /// Establishes the UI-test Keychain before `AuthManager.shared` or any
    /// account-scoped store is created. Every non-restore process gets a clean
    /// service. Relaunch coverage explicitly keeps that service and exercises
    /// the normal durable-identity hydration path.
    @discardableResult
    static func prepareUIAutomationStorage(arguments: [String]) -> Bool {
        guard arguments.contains("UI_TESTING") else { return true }
        let service = storageService(arguments: arguments)
        if shouldResetUIAutomationStorage(arguments: arguments),
           !deleteAll(service: service) {
            return false
        }
        guard let identity = uiAutomationIdentity(arguments: arguments) else {
            return true
        }
        guard save(identity.accountID, key: accountKey, service: service),
              save(
                identity.providerRawValue,
                key: accountProviderKey,
                service: service
              ),
              hasPreparedUIAutomationIdentity(arguments: arguments) else {
            // A partial fixture identity is more dangerous than no identity:
            // account-scoped stores could otherwise bind to a fallback while
            // the rendered auth state claims a different signed-in account.
            _ = deleteAll(service: service)
            return false
        }
        return true
    }

    /// Reads the exact isolated Security items back before a fixture may
    /// publish signed-in state or seed account-scoped stores.
    static func hasPreparedUIAutomationIdentity(arguments: [String]) -> Bool {
        guard let expected = uiAutomationIdentity(arguments: arguments) else {
            return false
        }
        let service = storageService(arguments: arguments)
        return load(key: accountKey, service: service) == expected.accountID
            && load(key: accountProviderKey, service: service)
                == expected.providerRawValue
    }
    #else
    static func storageService(arguments: [String]) -> String {
        productionService
    }
    #endif

    static func save(_ value: String, key: String) -> Bool {
        save(
            value,
            key: key,
            service: storageService(arguments: ProcessInfo.processInfo.arguments)
        )
    }

    private static func save(
        _ value: String,
        key: String,
        service: String
    ) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        if updateStatus == errSecSuccess { return true }
        guard updateStatus == errSecItemNotFound else { return false }

        var newItem = query
        newItem[kSecValueData as String] = data
        return SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess
    }

    static func load(key: String) -> String? {
        load(
            key: key,
            service: storageService(
                arguments: ProcessInfo.processInfo.arguments
            )
        )
    }

    private static func load(key: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecSuccess, let data = result as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: storageService(
                arguments: ProcessInfo.processInfo.arguments
            ),
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    @discardableResult
    private static func deleteAll(service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
#endif
