import Foundation
#if canImport(SwiftUI)
import SwiftUI
#if canImport(Security)
import Security
#endif

// MARK: - Saved rewrite phrase bank

/// A user-saved rewrite that can be reused as a speaking prompt later. The
/// bank stores only the phrase the user explicitly chose to keep, never the
/// source transcript or a hidden copy of the full session.
struct PhraseBankEntry: Codable, Equatable, Identifiable {
    let id: UUID
    let text: String
    let voice: SpeakingStyleGoal?
    let weakness: AIRewriteService.Weakness
    let intensity: AIRewriteService.Intensity
    let savedAt: Date

    init(
        id: UUID = UUID(),
        text: String,
        voice: SpeakingStyleGoal?,
        weakness: AIRewriteService.Weakness,
        intensity: AIRewriteService.Intensity,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.text = text
        self.voice = voice
        self.weakness = weakness
        self.intensity = intensity
        self.savedAt = savedAt
    }
}

/// Account-scoped saved rewrites. This is intentionally a small, explicit
/// store rather than an extension of session history: a saved phrase belongs
/// to the user's reusable practice library, not to one transcript.
@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class PhraseBankStore: ObservableObject {
    static let shared = PhraseBankStore()
    static let maximumEntries = 40
    static let storageKeyPrefix = "phraseBank.entries"

    @Published private(set) var entries: [PhraseBankEntry] = []

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil
    ) {
        self.defaults = defaults
        self.accountIDProvider = accountIDProvider ?? { Self.defaultAccountIDProvider() }
        load()
    }

    /// Saves only a phrase the user explicitly selected. Duplicate text updates
    /// the existing entry instead of creating a noisy bank of repeated model
    /// responses. Invalid or identifier-shaped text is never persisted.
    @discardableResult
    func save(
        text: String,
        voice: SpeakingStyleGoal?,
        weakness: AIRewriteService.Weakness,
        intensity: AIRewriteService.Intensity,
        now: Date = Date()
    ) -> PhraseBankEntry? {
        guard let sanitized = Self.sanitizedText(text) else { return nil }
        let comparisonKey = Self.comparisonKey(for: sanitized)
        if let index = entries.firstIndex(where: {
            Self.comparisonKey(for: $0.text) == comparisonKey
        }) {
            let existing = entries[index]
            let refreshed = PhraseBankEntry(
                id: existing.id,
                text: sanitized,
                voice: voice,
                weakness: weakness,
                intensity: intensity,
                savedAt: now
            )
            entries[index] = refreshed
            sortAndPersist()
            return refreshed
        }

        let entry = PhraseBankEntry(
            text: sanitized,
            voice: voice,
            weakness: weakness,
            intensity: intensity,
            savedAt: now
        )
        entries.append(entry)
        sortAndPersist()
        return entry
    }

    func contains(text: String) -> Bool {
        guard let sanitized = Self.sanitizedText(text) else { return false }
        let comparisonKey = Self.comparisonKey(for: sanitized)
        return entries.contains { Self.comparisonKey(for: $0.text) == comparisonKey }
    }

    func remove(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    func reloadForCurrentAccount() {
        load()
    }

    func endSession() {
        entries = []
    }

    func deleteAllData(for accountID: String) {
        defaults.removeObject(forKey: key(for: accountID))
        if accountIDProvider() == accountID {
            entries = []
        }
    }

    /// The bank is an explicit-save surface, but still rejects obvious likely
    /// identifiers as a defense-in-depth backstop for imperfect provider output.
    nonisolated static func sanitizedText(_ value: String) -> String? {
        let normalized = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count >= 3 else { return nil }
        let bounded = String(normalized.prefix(320))
        let sensitivePatterns = [
            #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            #"(?:\+?\d[\s().-]*){8,}"#,
            #"\b\d{3}[- ]?\d{2}[- ]?\d{4}\b"#,
        ]
        guard !sensitivePatterns.contains(where: {
            bounded.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }) else {
            return nil
        }
        return bounded
    }

    private static func comparisonKey(for text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentKey: String {
        key(for: accountIDProvider() ?? "guest")
    }

    private func key(for accountID: String) -> String {
        "\(Self.storageKeyPrefix).\(accountID)"
    }

    private func load() {
        guard let data = defaults.data(forKey: currentKey),
              let decoded = try? JSONDecoder().decode([PhraseBankEntry].self, from: data) else {
            entries = []
            return
        }
        entries = Array(decoded
            .filter { Self.sanitizedText($0.text) != nil }
            .sorted { $0.savedAt > $1.savedAt }
            .prefix(Self.maximumEntries))
    }

    private func sortAndPersist() {
        entries.sort { $0.savedAt > $1.savedAt }
        if entries.count > Self.maximumEntries {
            entries.removeLast(entries.count - Self.maximumEntries)
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        defaults.set(data, forKey: currentKey)
    }

    private static func defaultAccountIDProvider() -> String? {
        #if canImport(Security)
        KeychainHelper.load(key: "NoumAccountID")
        #else
        nil
        #endif
    }
}
#endif
