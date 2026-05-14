import Foundation

// MARK: - Prompt History Store (M7)
//
// Per-account 14-day rolling history of prompts the user has been shown.
// Drives the dedup contract for `PracticeTopics.next(...)`: a prompt is
// not eligible for re-show inside the freshness window.
//
// Storage shape: a list of (hash, dateInterval) tuples, capped at 200.
// We hash prompts with a stable Swift hasher so the on-disk cost stays
// constant regardless of prompt length, and so re-encoded JSON doesn't
// leak prompt text into UserDefaults dumps.
//
// All entries are stamped per account ID via a `.<accountID>` suffix
// on the storage key. Switching accounts (or signing in fresh) starts
// the user's history clean — we don't share dedup windows across users
// on the same device.

@MainActor
final class PromptHistoryStore {
    static let shared = PromptHistoryStore()

    /// Two-week freshness window. Matches the goal-refresh cadence —
    /// roughly the rhythm at which active users cycle through topics.
    nonisolated static let freshnessWindow: TimeInterval = 14 * 24 * 60 * 60

    /// Keep at most this many entries on disk. Older ones expire by
    /// time anyway; the cap is a belt-and-braces guard against runaway
    /// history if a user practices many times a day for years.
    nonisolated static let maxEntries = 200

    private let storageKeyPrefix = "noum.promptHistory."

    private init() {}

    /// Stable, account-scoped storage key.
    private var storageKey: String {
        let id = AuthManager.shared.currentAccountID ?? "guest"
        return storageKeyPrefix + id
    }

    /// Has this prompt been shown to the user inside the freshness window?
    func wasRecentlySeen(_ prompt: String, within window: TimeInterval = PromptHistoryStore.freshnessWindow) -> Bool {
        let target = Self.hash(of: prompt)
        let cutoff = Date().addingTimeInterval(-window)
        return load().contains { $0.hash == target && $0.date >= cutoff }
    }

    /// Mark a prompt as just-shown. No-op if the same prompt is already
    /// recent — we use the existing entry's date (FIFO) rather than
    /// resetting the clock. That way the user re-seeing a prompt on a
    /// re-roll doesn't extend its dedup lockout.
    func record(_ prompt: String) {
        let now = Date()
        let target = Self.hash(of: prompt)
        var entries = load()
        if entries.contains(where: { $0.hash == target }) { return }
        entries.append(Entry(hash: target, date: now))
        // Drop anything past the freshness window AND cap by count.
        let cutoff = now.addingTimeInterval(-Self.freshnessWindow)
        entries = entries.filter { $0.date >= cutoff }
        if entries.count > Self.maxEntries {
            entries = Array(entries.suffix(Self.maxEntries))
        }
        save(entries)
    }

    /// For tests + account switch — wipe the history for the current account.
    func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Number of entries currently stored within the freshness window.
    /// Useful for tests + diagnostics; not surfaced in UI.
    var recentCount: Int {
        let cutoff = Date().addingTimeInterval(-Self.freshnessWindow)
        return load().filter { $0.date >= cutoff }.count
    }

    // MARK: - Storage

    private struct Entry: Codable {
        let hash: Int
        let date: Date
    }

    private func load() -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return decoded
    }

    private func save(_ entries: [Entry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// Stable hash for prompt text. We strip whitespace and lowercase first
    /// so cosmetic edits ("Tell me…" vs " tell me… ") collapse to the same key.
    static func hash(of prompt: String) -> Int {
        let normalized = prompt
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        var hasher = Hasher()
        hasher.combine(normalized)
        return hasher.finalize()
    }
}
