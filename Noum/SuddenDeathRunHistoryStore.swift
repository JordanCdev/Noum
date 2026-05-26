#if canImport(SwiftUI)
import Foundation
import Combine

// MARK: - SuddenDeathRunHistoryStore
//
// Per-account, bounded persistence for completed Sudden Death runs.
// Mirrors the `PostRepCoachNoteStore` testable-init pattern so the
// service path can run hermetic tests against a custom UserDefaults
// suite without touching `KeychainHelper`.
//
// Capacity contract: 60 runs total per account. With three
// difficulties active, that's ~20 per difficulty before the oldest
// rolls off — plenty for the Result-screen "Recent Runs" section
// (shows last 5 for the current difficulty) and for the History tab
// to surface trends. Bounded to keep the per-account UserDefaults
// blob light.
//
// The store sits ALONGSIDE the existing `SuddenDeathHighScoreStore`
// (which is the single source of truth for the best round count per
// difficulty). The high-score store stays the API for "what's the
// peak"; this store is the API for "what did the last N runs look
// like." Both are written from the same `recordRun` call site in
// `SuddenDeathResultView.resolveHighScore` so they can't drift.

@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class SuddenDeathRunHistoryStore: ObservableObject {

    static let shared = SuddenDeathRunHistoryStore()

    /// Maximum number of runs held per account. Older runs drop by
    /// `completedAt` when the cap is hit.
    static let capacity = 60

    private static let storagePrefix = "suddenDeath.runHistory."

    @Published private(set) var runs: [SuddenDeathRunRecord] = []

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil
    ) {
        self.defaults = defaults
        if let provider = accountIDProvider {
            self.accountIDProvider = provider
        } else {
            self.accountIDProvider = { Self.defaultAccountIDProvider() }
        }
        loadFromDisk()
    }

    // MARK: - Lifecycle

    func reloadForCurrentAccount() {
        loadFromDisk()
    }

    func endSession() {
        runs = []
    }

    // MARK: - Public API

    /// Persist a completed run. De-dupes on `id` (a re-record of the
    /// same run replaces rather than stacks — guards against the
    /// recordRun call site firing twice on a fast double-mount).
    /// Sorted newest-first by `completedAt`; oldest evicted when the
    /// cap is hit.
    func record(_ run: SuddenDeathRunRecord) {
        var working = runs
        working.removeAll { $0.id == run.id }
        working.append(run)
        working.sort { $0.completedAt > $1.completedAt }
        if working.count > Self.capacity {
            working = Array(working.prefix(Self.capacity))
        }
        runs = working
        persist()
    }

    /// Returns the most recent runs for a difficulty, newest first.
    /// Pass `limit: nil` for the full history at that difficulty.
    func recentRuns(difficulty: SuddenDeathDifficulty, limit: Int? = nil) -> [SuddenDeathRunRecord] {
        let filtered = runs.filter { $0.difficulty == difficulty }
        guard let limit, limit > 0, filtered.count > limit else {
            return filtered
        }
        return Array(filtered.prefix(limit))
    }

    /// Returns the most recent runs across all difficulties, newest first.
    func recentRuns(limit: Int? = nil) -> [SuddenDeathRunRecord] {
        guard let limit, limit > 0, runs.count > limit else {
            return runs
        }
        return Array(runs.prefix(limit))
    }

    /// All runs across all difficulties, newest first. Used by the
    /// Profile/History surfaces if they ever want to render a full
    /// run history; the Result screen uses `recentRuns(difficulty:)`.
    var allRuns: [SuddenDeathRunRecord] { runs }

    /// Drop every run for the current account. Mirrors the
    /// `PostRepCoachNoteStore.clearAll` contract for a future Settings
    /// → "Clear practice history" affordance if it lands.
    func clearAll() {
        guard let accountID = accountIDProvider() else {
            runs = []
            return
        }
        runs = []
        defaults.removeObject(forKey: storageKey(for: accountID))
    }

    // MARK: - Auth wipe

    func deleteAllData(for accountID: String) {
        defaults.removeObject(forKey: storageKey(for: accountID))
        if accountIDProvider() == accountID {
            runs = []
        }
    }

    // MARK: - Private

    private func persist() {
        guard let accountID = accountIDProvider() else { return }
        do {
            let data = try JSONEncoder().encode(runs)
            defaults.set(data, forKey: storageKey(for: accountID))
        } catch {
            // Encoder failure on a Codable struct is effectively
            // impossible; silently skip rather than crash.
        }
    }

    private func loadFromDisk() {
        guard let accountID = accountIDProvider(),
              let data = defaults.data(forKey: storageKey(for: accountID)),
              let decoded = try? JSONDecoder().decode([SuddenDeathRunRecord].self, from: data) else {
            runs = []
            return
        }
        runs = decoded.sorted { $0.completedAt > $1.completedAt }
    }

    private func storageKey(for accountID: String) -> String {
        "\(Self.storagePrefix)\(accountID)"
    }

    private static func defaultAccountIDProvider() -> String? {
        KeychainHelper.load(key: "NoumAccountID")
    }
}
#endif
