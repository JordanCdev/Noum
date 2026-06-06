#if canImport(SwiftUI)
import Foundation
import Combine

// MARK: - PostRepCoachNoteStore
//
// Per-account persistence for `PostRepCoachNote` records. Mirrors the
// `AskNoumStore` testable-init pattern (defaults + accountIDProvider)
// instead of the pure-singleton pattern other stores use, because the
// service path needs hermetic tests and a custom UserDefaults suite
// makes that trivial without touching `KeychainHelper`.
//
// Lifecycle hooks (`reloadForCurrentAccount`, `endSession`,
// `deleteAllData(for:)`) are wired through `AuthManager` so the store
// behaves identically to the other per-account stores from the user's
// perspective.
//
// Capacity contract: 30 notes max, dropped by `generatedAt` (oldest
// first) when the cap is exceeded. That's plenty for the coach to
// quote back the most recent reflection in the chat context AND for
// the Summary card to render the active rep's note; older sessions
// can still display the note as long as it's within the 30-window.

@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class PostRepCoachNoteStore: ObservableObject {

    static let shared = PostRepCoachNoteStore()

    /// Maximum number of notes held per account. 30 covers ~a month
    /// of daily reps without bloating the per-account UserDefaults
    /// blob.
    static let capacity = 30

    /// Storage key prefix. Joined with the account ID the same way
    /// every other per-account value is keyed.
    private static let storagePrefix = "postRepCoachNote."

    @Published private(set) var notes: [PostRepCoachNote] = []

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
        notes = []
    }

    // MARK: - Public API

    /// Persist a note, evicting the oldest entry when the cap is hit
    /// and de-duping on `sessionID` so re-finalizing the same session
    /// (deterministic → AI upgrade) replaces the previous record
    /// rather than stacking.
    func record(_ note: PostRepCoachNote) {
        var working = notes
        working.removeAll { $0.sessionID == note.sessionID }
        working.append(note)
        working.sort { $0.generatedAt > $1.generatedAt }
        if working.count > Self.capacity {
            working = Array(working.prefix(Self.capacity))
        }
        notes = working
        persist()
    }

    /// Fetch the note tied to a session, if one exists.
    func note(for sessionID: UUID) -> PostRepCoachNote? {
        notes.first { $0.sessionID == sessionID }
    }

    /// Most recent note across all sessions (by `generatedAt`). Nil
    /// when the store is empty. Used by `CoachContextBuilder.userContext`
    /// to surface the LAST REP NOTE section.
    func latestNote() -> PostRepCoachNote? {
        notes.max { $0.generatedAt < $1.generatedAt }
    }

    /// Drop every note for the current account. Used by Settings →
    /// "Clear coach memory" if it ever lands.
    func clearAll() {
        guard let accountID = accountIDProvider() else {
            notes = []
            return
        }
        notes = []
        defaults.removeObject(forKey: storageKey(for: accountID))
    }

    // MARK: - Auth wipe

    func deleteAllData(for accountID: String) {
        defaults.removeObject(forKey: storageKey(for: accountID))
        if accountIDProvider() == accountID {
            notes = []
        }
    }

    // MARK: - Private

    private func persist() {
        guard let accountID = accountIDProvider() else { return }
        do {
            let data = try JSONEncoder().encode(notes)
            defaults.set(data, forKey: storageKey(for: accountID))
        } catch {
            // Encoder failure on Codable structs is effectively
            // impossible; silently skip rather than crash.
        }
    }

    private func loadFromDisk() {
        guard let accountID = accountIDProvider(),
              let data = defaults.data(forKey: storageKey(for: accountID)),
              let decoded = try? JSONDecoder().decode([PostRepCoachNote].self, from: data) else {
            notes = []
            return
        }
        notes = decoded.sorted { $0.generatedAt > $1.generatedAt }
    }

    private func storageKey(for accountID: String) -> String {
        "\(Self.storagePrefix)\(accountID)"
    }

    private static func defaultAccountIDProvider() -> String? {
        KeychainHelper.load(key: "NoumAccountID")
    }
}
#endif
