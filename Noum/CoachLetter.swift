import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Coach Letter
//
// The £130/hr coach sends a written end-of-month review: what
// improved, what's still blocking, what next month should look like.
// `CoachLetter` is that artifact in Noum's voice — one per calendar
// month, persisted per-account, surfaced in the Ask Noum thread on
// first open of each new month.
//
// This is the longitudinal artifact that creates the "coach who has
// been watching" feeling. The chat thread becomes a scrollable
// history of monthly reviews — a user opening Noum after three months
// sees their full coaching arc, not just isolated rep debriefs.
//
// Design rules:
//   • Pure-data model — all generation logic lives in
//     `CoachLetterGenerator`. The struct stays test-friendly.
//   • Bounded — capped at 24 letters (2 years). Older letters fall
//     off; the most recent always survives.
//   • Honest about source — `isAIBacked: Bool` flows from the
//     generator so the UI can label deterministic fallbacks as
//     "rule-based" rather than presenting template copy as AI insight.

/// A monthly coach letter. `month` is the calendar month the letter
/// covers (format "YYYY-MM"). `content` is the rendered text ready
/// to drop into the chat thread.
struct CoachLetter: Codable, Equatable, Identifiable {
    let id: UUID
    /// "YYYY-MM" — the calendar month this letter covers (NOT the
    /// month it was generated, which is always the next month after).
    let month: String
    let content: String
    let voiceAtGeneration: SpeakingStyleGoal?
    let generatedAt: Date
    /// `nil` until the letter has been injected as an Ask Noum coach
    /// turn. Once set, the bubble carries the same UUID so future
    /// surfaces could deep-link to the message.
    var injectedMessageID: UUID?
    /// True when an AI provider produced the letter; false when the
    /// deterministic rule-based path ran. UI surfaces should label
    /// false as "rule-based" rather than presenting it as AI insight.
    let isAIBacked: Bool

    init(
        id: UUID = UUID(),
        month: String,
        content: String,
        voiceAtGeneration: SpeakingStyleGoal? = nil,
        generatedAt: Date = Date(),
        injectedMessageID: UUID? = nil,
        isAIBacked: Bool
    ) {
        self.id = id
        self.month = month
        self.content = content
        self.voiceAtGeneration = voiceAtGeneration
        self.generatedAt = generatedAt
        self.injectedMessageID = injectedMessageID
        self.isAIBacked = isAIBacked
    }

    /// Month key for "right now" — what month the next-letter generation
    /// would cover. Letters generated on the 1st of June would carry
    /// `month: "2026-05"` (the May review).
    static func previousMonthKey(now: Date = Date(), calendar: Calendar = .current) -> String {
        let previous = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        let comps = calendar.dateComponents([.year, .month], from: previous)
        let y = comps.year ?? 1970
        let m = comps.month ?? 1
        return String(format: "%04d-%02d", y, m)
    }

    /// Inclusive [start, end) date range for a "YYYY-MM" month key.
    /// Used by the generator to filter sessions into the right window.
    static func dateRange(forMonthKey key: String, calendar: Calendar = .current) -> (start: Date, end: Date)? {
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1]) else { return nil }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let start = calendar.date(from: comps),
              let end = calendar.date(byAdding: .month, value: 1, to: start) else { return nil }
        return (calendar.startOfDay(for: start), calendar.startOfDay(for: end))
    }
}

// MARK: - CoachLetterStore

/// Per-account persistent store for monthly coach letters. Same
/// singleton + reload/end-session shape as every other store.
/// Capped at 24 letters (2 years) — older drops off oldest-first.
@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class CoachLetterStore: ObservableObject {
    static let shared = CoachLetterStore()

    @Published private(set) var letters: [CoachLetter] = []

    /// Hard cap. 24 months = 2 years of monthly history. A user
    /// scrolling back further is unusual; if it matters we'd surface
    /// archive search instead of expanding the cap.
    static let maxLetters = 24

    private let accountKey = "NoumAccountID"
    private let archiveKeyPrefix = "coachLetter.archive."

    private init() {}

    // MARK: - Lifecycle

    func reloadForCurrentAccount() {
        guard let accountID = currentAccountID else {
            letters = []
            return
        }
        letters = Self.loadLetters(forKey: archiveKey(for: accountID))
    }

    func endSession() {
        letters = []
    }

    // MARK: - API

    /// Append a new letter and persist. Newest-first ordering on read;
    /// internal storage is newest-first too so the cap drops the oldest.
    func record(_ letter: CoachLetter) {
        guard let accountID = currentAccountID else { return }
        var next = letters
        // Idempotency by month — if a letter for this month already
        // exists (e.g. user triggered manually + auto-fire both ran),
        // replace it instead of duplicating.
        if let existingIndex = next.firstIndex(where: { $0.month == letter.month }) {
            next[existingIndex] = letter
        } else {
            next.insert(letter, at: 0)
        }
        if next.count > Self.maxLetters {
            next = Array(next.prefix(Self.maxLetters))
        }
        letters = next
        persist(next, accountID: accountID)
    }

    /// True when a letter for `monthKey` exists. The auto-fire trigger
    /// consults this so we never generate twice in the same calendar
    /// month, even if the user opens the app multiple times on day 1.
    func hasLetter(for monthKey: String) -> Bool {
        letters.contains { $0.month == monthKey }
    }

    /// The most recent letter (or nil). Used by Profile / future
    /// "most recent review" surfaces.
    var latest: CoachLetter? { letters.first }

    // MARK: - Auth wipe

    func deleteAllData(for accountID: String) {
        UserDefaults.standard.removeObject(forKey: archiveKey(for: accountID))
        if currentAccountID == accountID {
            letters = []
        }
    }

    // MARK: - Private

    private func persist(_ letters: [CoachLetter], accountID: String) {
        guard let data = try? JSONEncoder().encode(letters) else { return }
        UserDefaults.standard.set(data, forKey: archiveKey(for: accountID))
    }

    private func archiveKey(for accountID: String) -> String {
        "\(archiveKeyPrefix)\(accountID)"
    }

    private var currentAccountID: String? {
        KeychainHelper.load(key: accountKey)
    }

    private static func loadLetters(forKey key: String) -> [CoachLetter] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CoachLetter].self, from: data) else { return [] }
        return decoded
    }
}
