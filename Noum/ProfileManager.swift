import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@MainActor
final class ProfileManager: ObservableObject {
    static let shared = ProfileManager()

    @Published private(set) var xp: Int

    private let accountKey = "NoumAccountID"
    private let providerKey = "NoumAccountProvider"

    private init() {
        xp = Self.loadXP(forKey: Self.storageKey(for: KeychainHelper.load(key: "NoumAccountID")))
    }

    func addXP(_ amount: Int) {
        guard amount > 0 else { return }
        xp += amount
        persist()
        syncXPIfPossible()
    }

    func reloadForCurrentAccount() {
        xp = Self.loadXP(forKey: Self.storageKey(for: currentAccountID))
    }

    func replaceFromRemote(_ remoteXP: Int) {
        xp = max(0, remoteXP)
        persist()
    }

    func endSession() {
        xp = 0
    }

    var progressTowardsNextLevel: Double {
        Double(xp % 1000) / 1000.0
    }

    private let mainLevels = [
        "Beginner Speaker",
        "Novice Speaker",
        "Average Speaker",
        "Professional Speaker",
        "World Class Speaker"
    ]

    var levelTitle: String {
        let totalLevel = xp / 1000
        let mainIndex = min(totalLevel / 3, mainLevels.count - 1)
        let subIndex = totalLevel % 3
        let roman = ["I", "II", "III"][min(subIndex, 2)]
        return "\(mainLevels[mainIndex]) \(roman)"
    }

    static func levelTitle(forXP xp: Int) -> String {
        let manager = ProfileManager.shared
        let totalLevel = xp / 1000
        let mainIndex = min(totalLevel / 3, manager.mainLevels.count - 1)
        let subIndex = totalLevel % 3
        let roman = ["I", "II", "III"][min(subIndex, 2)]
        return "\(manager.mainLevels[mainIndex]) \(roman)"
    }

    static func progressTowardsNextLevel(forXP xp: Int) -> Double {
        Double(xp % 1000) / 1000.0
    }

    static func xpNeededToNextLevel(forXP xp: Int) -> Int {
        1000 - (xp % 1000)
    }

    private var currentAccountID: String? {
        KeychainHelper.load(key: accountKey)
    }

    private var currentProviderRawValue: String? {
        KeychainHelper.load(key: providerKey)
    }

    private func persist() {
        UserDefaults.standard.set(xp, forKey: Self.storageKey(for: currentAccountID))
    }

    private func syncXPIfPossible() {
        guard let accountID = currentAccountID, let providerRawValue = currentProviderRawValue else { return }
        let value = xp
        Task {
            await BackendSyncManager.shared.syncXP(value, accountID: accountID, providerRawValue: providerRawValue)
        }
    }

    private static func storageKey(for accountID: String?) -> String {
        if let accountID, !accountID.isEmpty {
            return "profileXP.\(accountID)"
        }
        return "profileXP.guest"
    }

    private static func loadXP(forKey key: String) -> Int {
        UserDefaults.standard.integer(forKey: key)
    }
}
#endif
