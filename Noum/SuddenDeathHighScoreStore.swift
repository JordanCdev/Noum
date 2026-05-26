import Foundation

// MARK: - Sudden Death High Score Store

/// Per-account, per-difficulty high score persistence for Sudden Death mode.
/// Uses the same UserDefaults keying pattern as RatingStore / AchievementStore.
final class SuddenDeathHighScoreStore: ObservableObject {
    static let shared = SuddenDeathHighScoreStore()

    private let keyPrefix = "suddenDeath.highScore"

    private init() {}

    /// Returns the best rounds survived for a difficulty. 0 = no run recorded.
    func bestRounds(difficulty: SuddenDeathDifficulty) -> Int {
        let key = storageKey(for: difficulty)
        return UserDefaults.standard.integer(forKey: key)
    }

    /// Records a run. Returns true if this is a new best for the difficulty.
    @discardableResult
    func recordRun(roundsSurvived: Int, difficulty: SuddenDeathDifficulty) -> Bool {
        let key = storageKey(for: difficulty)
        let current = UserDefaults.standard.integer(forKey: key)
        guard roundsSurvived > current else { return false }
        UserDefaults.standard.set(roundsSurvived, forKey: key)
        return true
    }

    // MARK: - Single-track game points (no difficulty bucketing)

    /// Best game points across all runs, regardless of difficulty.
    func bestPoints() -> Int {
        let key = "\(keyPrefix).bestPoints.\(accountID())"
        return UserDefaults.standard.integer(forKey: key)
    }

    /// Records game points for a run. Returns true if this is a new best.
    @discardableResult
    func recordPoints(_ points: Int) -> Bool {
        let key = "\(keyPrefix).bestPoints.\(accountID())"
        let current = UserDefaults.standard.integer(forKey: key)
        guard points > current else { return false }
        UserDefaults.standard.set(points, forKey: key)
        return true
    }

    private func storageKey(for difficulty: SuddenDeathDifficulty) -> String {
        let account = accountID()
        return "\(keyPrefix).\(difficulty.rawValue).\(account)"
    }

    private func accountID() -> String {
        if let id = KeychainHelper.load(key: "NoumAccountID"), !id.isEmpty {
            return id
        }
        return "guest"
    }
}
