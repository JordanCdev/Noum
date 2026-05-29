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
//
// Sibling text store: a small LRU of recent prompt *texts* lives
// alongside the hash store under `noum.promptHistory.texts.<accountID>`.
// The hash store remains the dedup source of truth — the text store is
// only the AI generator's "don't echo these" seed so generated prompts
// don't become near-clones of last week's. `reset()` clears both.

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

    /// LRU cap for the sibling text store. The AI generator only needs a
    /// handful of recents to dodge near-clones; we never feed it more
    /// than ~5 in practice, so keeping ~10 on disk leaves headroom
    /// without bloating UserDefaults.
    nonisolated static let maxTextEntries = 10

    private let storageKeyPrefix = "noum.promptHistory."
    private let textStorageKeyPrefix = "noum.promptHistory.texts."

    private init() {}

    /// Stable, account-scoped storage key.
    private var storageKey: String {
        let id = AuthManager.shared.currentAccountID ?? "guest"
        return storageKeyPrefix + id
    }

    /// Account-scoped key for the sibling text store.
    private var textStorageKey: String {
        let id = AuthManager.shared.currentAccountID ?? "guest"
        return textStorageKeyPrefix + id
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
    /// re-roll doesn't extend its dedup lockout. Also appends the prompt
    /// text to the sibling LRU text store consumed by the AI generator.
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

        recordText(prompt, at: now)
    }

    /// The N most recently shown prompts, newest first, within the
    /// freshness window. Used to seed `AIPromptGeneratorService` so the
    /// model can avoid near-clones of prompts the user just saw. Returns
    /// an empty array when nothing's been recorded yet.
    func recentTexts(limit: Int = 5) -> [String] {
        guard limit > 0 else { return [] }
        let cutoff = Date().addingTimeInterval(-Self.freshnessWindow)
        let fresh = loadTexts().filter { $0.date >= cutoff }
        return fresh.suffix(limit).reversed().map { $0.text }
    }

    /// For tests + account switch — wipe the history for the current
    /// account. Clears both the hash store and the sibling text store
    /// so a fresh account starts with zero AI-seed leakage.
    func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        UserDefaults.standard.removeObject(forKey: textStorageKey)
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

    // MARK: - Text store (AI-seed)

    private struct TextEntry: Codable {
        let text: String
        let date: Date
    }

    /// Append a prompt's text to the LRU text store. Dedups by normalised
    /// equality (matching the hash store's collapse rules) so case-only
    /// variants don't duplicate, then caps to `maxTextEntries` newest.
    private func recordText(_ prompt: String, at now: Date) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalizedTarget = trimmed.lowercased()

        var texts = loadTexts()
        texts.removeAll { $0.text.lowercased() == normalizedTarget }
        texts.append(TextEntry(text: trimmed, date: now))

        let cutoff = now.addingTimeInterval(-Self.freshnessWindow)
        texts = texts.filter { $0.date >= cutoff }
        if texts.count > Self.maxTextEntries {
            texts = Array(texts.suffix(Self.maxTextEntries))
        }
        saveTexts(texts)
    }

    private func loadTexts() -> [TextEntry] {
        guard let data = UserDefaults.standard.data(forKey: textStorageKey),
              let decoded = try? JSONDecoder().decode([TextEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveTexts(_ entries: [TextEntry]) {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: textStorageKey)
    }
}
