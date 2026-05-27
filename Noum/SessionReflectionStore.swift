import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Session Reflection
//
// "How did that feel?" — the post-rep mirror of SessionIntent's pre-rep
// "What are we working on today?". A human coach asks what felt hard,
// where nerves showed up, what the user held back, and whether a
// technically clean answer actually felt like them. Noum can measure
// fillers and pace, but it cannot hear the inner experience — only the
// user can report it.
//
// Design rules (mirroring SessionIntent):
//   • Pure-data model — `SessionReflection` carries the user's self-
//     reported feeling + an optional note + when it was recorded. No I/O
//     on the struct; all state lives in the store.
//   • Recorded against a known session — unlike intent (pre-rep pending →
//     consumed at finalize), a reflection is captured on the summary
//     screen when the session already exists, so it links directly to a
//     session ID. No pending/consume dance.
//   • Honest about provenance — the feeling is always the USER's report,
//     never an inference from telemetry. The coach surfaces it as "the
//     user said …", never as a fact Noum detected.
//   • Opt-in — the inline card self-hides once a session is reflected on
//     and never blocks anything. Skipping leaves no reflection and the
//     coach context omits the line.

/// The user's self-reported subjective experience of a rep, captured in a
/// single tap. Deliberately small and feeling-led: this is the inner read
/// telemetry can't see, not another metric.
enum ReflectionFeeling: String, Codable, CaseIterable, Identifiable {
    case strong       // felt in control
    case nervous      // nerves showed up
    case heldBack     // played it safe / avoided
    case notLikeMe    // technically ok but not authentic

    var id: String { rawValue }

    /// First-person chip label the prompt shows. The user is reporting
    /// their own experience, so the voice is "Felt strong", not a verdict.
    var chipLabel: String {
        switch self {
        case .strong:    return "Felt strong"
        case .nervous:   return "Nerves got me"
        case .heldBack:  return "Held back"
        case .notLikeMe: return "Didn't feel like me"
        }
    }

    /// SF Symbol for the chip.
    var symbolName: String {
        switch self {
        case .strong:    return "bolt.fill"
        case .nervous:   return "wind"
        case .heldBack:  return "hand.raised.fill"
        case .notLikeMe: return "theatermasks.fill"
        }
    }

    /// A clause that completes "the user said …" in the coach context.
    /// Framed as the user's own report — never as something Noum inferred.
    var coachClause: String {
        switch self {
        case .strong:    return "it felt strong and in control"
        case .nervous:   return "nerves affected their delivery"
        case .heldBack:  return "they held back and played it safe"
        case .notLikeMe: return "the answer didn't feel like them"
        }
    }
}

/// One recorded post-rep reflection, linked to the session it describes.
struct SessionReflection: Codable, Identifiable, Equatable {
    static let noteCharacterLimit = 160

    let id: UUID
    let sessionID: UUID
    let feeling: ReflectionFeeling
    let note: String?
    let recordedAt: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        feeling: ReflectionFeeling,
        note: String? = nil,
        recordedAt: Date = Date()
    ) {
        self.id = id
        self.sessionID = sessionID
        self.feeling = feeling
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = trimmedNote.flatMap { value in
            guard !value.isEmpty else { return nil }
            return String(value.prefix(Self.noteCharacterLimit))
        }
        self.recordedAt = recordedAt
    }

    /// The clause the coach reads, e.g. "it felt strong and in control".
    /// Appends a quoted note when the user added one.
    var coachClause: String {
        if let note = note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            return "\(feeling.coachClause) — \"\(note)\""
        }
        return feeling.coachClause
    }
}

// MARK: - SessionReflectionStore

/// Per-account persistent store for post-rep reflections. `history` is
/// bounded at 30 entries and persists across launches so the coach can
/// reference how recent reps felt ("last week you said the close felt
/// shaky — how was it this time?"). Mirrors `SessionIntentStore`'s
/// per-account UserDefaults pattern.
@MainActor
final class SessionReflectionStore: ObservableObject {
    static let shared = SessionReflectionStore()

    /// Bounded historical record of reflections, most-recent first.
    @Published private(set) var history: [SessionReflection] = []

    static let historyCap = 30
    private let accountKey = "NoumAccountID"
    private let historyKeyPrefix = "sessionReflection.history."

    private init() {}

    // MARK: - Lifecycle

    func reloadForCurrentAccount() {
        guard let accountID = currentAccountID else {
            history = []
            return
        }
        history = Self.loadHistory(forKey: historyKey(for: accountID))
    }

    func endSession() {
        history = []
    }

    // MARK: - API

    /// The most-recent reflection across all sessions, if any.
    var latest: SessionReflection? { history.first }

    /// The reflection recorded for a specific session, if the user gave one.
    func reflection(for sessionID: UUID) -> SessionReflection? {
        history.first { $0.sessionID == sessionID }
    }

    /// Whether the user has already reflected on a given session — used by
    /// the inline card to show its "noted" confirmation instead of the
    /// prompt, so the question is never asked twice.
    func hasReflected(for sessionID: UUID) -> Bool {
        history.contains { $0.sessionID == sessionID }
    }

    /// Record the user's reflection for a finished session. Replaces any
    /// earlier reflection for the same session (the user can change their
    /// mind). Returns the stored reflection so the caller can feed its
    /// coach clause straight into durable memory.
    @discardableResult
    func record(sessionID: UUID, feeling: ReflectionFeeling, note: String? = nil) -> SessionReflection {
        let reflection = SessionReflection(sessionID: sessionID, feeling: feeling, note: note)
        var updated = history.filter { $0.sessionID != sessionID }
        updated.insert(reflection, at: 0)
        if updated.count > Self.historyCap {
            updated = Array(updated.prefix(Self.historyCap))
        }
        history = updated
        persist(updated)
        return reflection
    }

    // MARK: - Auth wipe

    func deleteAllData(for accountID: String) {
        UserDefaults.standard.removeObject(forKey: historyKey(for: accountID))
        if currentAccountID == accountID {
            history = []
        }
    }

    // MARK: - Private

    private func persist(_ reflections: [SessionReflection]) {
        guard let accountID = currentAccountID,
              let data = try? JSONEncoder().encode(reflections) else { return }
        UserDefaults.standard.set(data, forKey: historyKey(for: accountID))
    }

    private func historyKey(for accountID: String) -> String {
        "\(historyKeyPrefix)\(accountID)"
    }

    private var currentAccountID: String? {
        KeychainHelper.load(key: accountKey)
    }

    private static func loadHistory(forKey key: String) -> [SessionReflection] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let reflections = try? JSONDecoder().decode([SessionReflection].self, from: data) else {
            return []
        }
        return reflections
    }
}
