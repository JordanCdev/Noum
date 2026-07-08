import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// One persisted turn from a pressure-ladder roleplay run. Carries exactly
/// the fields the roadmap's data contract requires per turn, plus a `date`
/// for ordering/history and a `sessionID` grouping turns from the same run.
struct RoleplayTurnRecord: Codable, Identifiable, Equatable {
    var id: UUID
    var sessionID: UUID
    var date: Date
    var scenarioId: String
    var pressureLevel: RoleplayPressureLevel
    var objectionType: RoleplayObjectionType
    var objectionId: String
    var responseQuality: Double
    var recommendedRetryMode: RoleplayRetryMode

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        date: Date,
        result: RoleplayTurnResult
    ) {
        self.id = id
        self.sessionID = sessionID
        self.date = date
        self.scenarioId = result.scenarioId
        self.pressureLevel = result.pressureLevel
        self.objectionType = result.objectionType
        self.objectionId = result.objectionId
        self.responseQuality = result.responseQuality
        self.recommendedRetryMode = result.recommendedRetryMode
    }
}

#if canImport(SwiftUI)
/// Per-account persisted history for the pressure-ladder roleplay feature.
/// Mirrors `PracticeSessionStore`'s shape (singleton, Keychain-derived
/// account ID, `UserDefaults`-backed JSON, account-scoped key) so the two
/// stores stay recognizably the same pattern.
///
/// Unlike `PracticeSessionStore`, this loads its persisted state directly
/// in `init()` rather than waiting for `AuthManager.deferStoreReloadForCurrentAccount()`
/// to call `reloadForCurrentAccount()` — wiring a new store into
/// `AuthManager`'s reload cycle is out of scope for this feature (that file
/// isn't owned by this change), so `reloadForCurrentAccount()` is exposed
/// as a public entry point for a future integration pass rather than
/// silently depending on one that doesn't exist yet.
@MainActor
final class RoleplayStore: ObservableObject {
    static let shared = RoleplayStore()

    @Published private(set) var turns: [RoleplayTurnRecord]

    private let accountKey = "NoumAccountID"

    private init() {
        // Phase-1 init: can't call `self.currentAccountID` (an instance
        // computed property) before `turns` has a value, so the Keychain
        // read is inlined here instead of routed through the shared helper.
        let accountID = KeychainHelper.load(key: "NoumAccountID")
        turns = Self.loadTurns(forKey: Self.storageKey(for: accountID))
    }

    /// IDs of every objection already served to this account, across every
    /// scenario and every past run. `RoleplayEngine.nextObjection` uses this
    /// as its exclusion set so the same drill doesn't recur across unrelated
    /// roleplays.
    var usedObjectionIDs: Set<String> {
        Set(turns.map { $0.objectionId })
    }

    func reload() {
        turns = Self.loadTurns(forKey: Self.storageKey(for: currentAccountID))
    }

    func reloadForCurrentAccount() {
        reload()
    }

    @discardableResult
    func record(sessionID: UUID, result: RoleplayTurnResult, date: Date) -> RoleplayTurnRecord {
        let record = RoleplayTurnRecord(sessionID: sessionID, date: date, result: result)
        turns.insert(record, at: 0)
        persist()
        return record
    }

    func turns(forSession sessionID: UUID) -> [RoleplayTurnRecord] {
        turns.filter { $0.sessionID == sessionID }.sorted { $0.date < $1.date }
    }

    func endSession() {
        turns = []
        UserDefaults.standard.removeObject(forKey: Self.storageKey(for: currentAccountID))
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(turns) {
            UserDefaults.standard.set(data, forKey: Self.storageKey(for: currentAccountID))
        }
    }

    private var currentAccountID: String? {
        KeychainHelper.load(key: accountKey)
    }

    private static func storageKey(for accountID: String?) -> String {
        if let accountID, !accountID.isEmpty {
            return "roleplayTurns.\(accountID)"
        }
        return "roleplayTurns.guest"
    }

    private static func loadTurns(forKey key: String) -> [RoleplayTurnRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RoleplayTurnRecord].self, from: data) else {
            return []
        }
        return decoded.sorted { $0.date > $1.date }
    }
}
#endif
