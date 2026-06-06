import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Session Intent
//
// "What are we working on today?" — the first question a £130/hr coach
// asks before a rep. Noum has always picked the drill for the user;
// `SessionIntent` lets the user declare a focus that the post-rep
// summary and the persistent coach (Ask Noum) can reference.
//
// Design rules:
//   • Pure-data model — `SessionIntent` carries the priority + display
//     label + a record of when the user declared it. No I/O on the
//     struct itself; all state lives in the store.
//   • Pending vs history — `pendingIntent` is the just-declared,
//     not-yet-attached intent for the next rep. After
//     `PracticeSessionFinalizer.finalize(...)` runs, the intent is
//     consumed: linked to the session ID and moved into the bounded
//     history.
//   • Honest about opt-in — when the user dismisses the sheet without
//     selecting a focus, `pendingIntent` stays nil and the rep
//     finalizes with `intentFocus: nil`. The summary cards + coach
//     context silently omit the chip / line. No fake "Open rep" intent
//     is persisted just because the prompt was shown.

/// One declared focus for an upcoming rep. Carries the priority the user
/// selected, the display label the chip showed, the kind of option
/// (plan-week / trend-focus / goal / generic), and (after the rep
/// finalizes) the session it ended up attached to.
struct SessionIntent: Codable, Identifiable, Equatable {
    let id: UUID
    let priority: CoachingPriority
    let label: String
    let kind: SessionIntentOptionKind
    let declaredAt: Date
    var sessionID: UUID?

    init(
        id: UUID = UUID(),
        priority: CoachingPriority,
        label: String,
        kind: SessionIntentOptionKind,
        declaredAt: Date = Date(),
        sessionID: UUID? = nil
    ) {
        self.id = id
        self.priority = priority
        self.label = label
        self.kind = kind
        self.declaredAt = declaredAt
        self.sessionID = sessionID
    }
}

/// How an intent option was sourced. Used by the engine to surface the
/// most-earned-feeling option first and by the prompt UI to label the
/// reason a given chip is on screen ("from your plan" vs "your goal").
enum SessionIntentOptionKind: String, Codable, Equatable {
    case planWeek    // surfaced from active ForwardPlan's current week
    case trendFocus  // surfaced from TrendAnalyzer.primaryFocus
    case voiceGoal   // surfaced from CoachingProfile.primaryGoal
    case generic     // the always-present "Open rep" fallback

    var reasonLabel: String? {
        switch self {
        case .planWeek:   return "From your plan"
        case .trendFocus: return "Your weakest area"
        case .voiceGoal:  return "Your stated goal"
        case .generic:    return nil
        }
    }
}

// MARK: - Priority ↔ SkillArea bridge
//
// `TrendAnalyzer.primaryFocus(...) -> SkillArea` and
// `ForwardPlan.PlanWeek.focusSkillArea` live in the SkillArea space;
// `CoachingPriority` is the user-facing 4-way bucket. This bridge
// lets the engine speak both languages without leaking SkillArea
// into the intent UI.

extension CoachingPriority {
    /// The CoachingPriority most-aligned with a measured SkillArea.
    /// Used to translate `TrendAnalyzer.primaryFocus(...)` outputs and
    /// `PlanWeek.focusSkillArea` values into the priority space the
    /// SessionIntent options live in.
    static func aligned(with area: SkillArea) -> CoachingPriority {
        switch area {
        case .fillerReduction:
            return .reduceFillers
        case .conciseSpeaking, .structure, .answerDevelopment:
            return .moreConcise
        case .openingStrength, .closingStrength:
            return .thinkFaster
        case .paceControl, .pauseUsage, .vocalEmphasis, .confidence:
            return .calmerDelivery
        }
    }

    /// Voice-shaped chip label for the intent prompt. Shorter than
    /// `title` so the chip fits in a single row; first-person framing
    /// ("Cut fillers" not "Reduce filler words") because the user is
    /// declaring their own intent.
    var intentChipLabel: String {
        switch self {
        case .reduceFillers:  return "Cut fillers"
        case .moreConcise:    return "Tighten structure"
        case .thinkFaster:    return "Think faster"
        case .calmerDelivery: return "Stay composed"
        }
    }
}

// MARK: - Intent match — pure
//
// Used by the summary cards (`WhatYouDidWellCard` /
// `WhatToImproveCard`) to render a quiet "You aimed for this" chip
// adjacent to bullets that align with the declared intent. The mapping
// is keyed on the bullets' existing ID conventions
// (`category-<Dimension>`, `filler`, `pace-fast`, `pace-slow`,
// `leverage`, `momentum`, etc.) so neither card needs structural
// changes beyond reading a `SessionIntentMatcher.aligns(...)` boolean.

enum SessionIntentMatcher {

    /// Returns true when a summary-card bullet aligns with the user's
    /// declared coaching priority. Keyed on the bullet's `id` so the
    /// match can be computed without changing the bullet model itself.
    /// The dimension-bullet IDs follow the `category-<Dimension>`
    /// convention from the two summary cards.
    static func aligns(bulletID: String, with priority: CoachingPriority) -> Bool {
        switch priority {
        case .reduceFillers:
            return bulletID == "filler" || bulletID == "category-Clarity"
        case .moreConcise:
            return bulletID == "category-Structure"
                || bulletID == "category-Clarity"
                || bulletID == "category-Depth"
                || bulletID == "category-Relevance"
        case .thinkFaster:
            return bulletID == "category-Opening"
                || bulletID == "pace-fast"
        case .calmerDelivery:
            return bulletID == "pace-fast"
                || bulletID == "pace-slow"
                || bulletID == "category-Pace"
        }
    }
}

// MARK: - SessionIntentStore

/// Per-account persistent store for declared session intents. The
/// `pendingIntent` is transient (cleared every `consume` /
/// `clearPending` / `endSession`), while `history` is bounded at 30
/// entries and persists across launches so the persistent coach can
/// reference past declarations ("you said you'd train pauses last
/// week — did you?").
@MainActor
final class SessionIntentStore: ObservableObject {
    static let shared = SessionIntentStore()

    /// The user's just-declared focus for the next rep. Cleared when the
    /// session finalizes via `consume(sessionID:)`, or explicitly via
    /// `clearPending()` when the user backs out of the rep.
    @Published private(set) var pendingIntent: SessionIntent?

    /// Bounded historical record of declared intents (linked to the
    /// session that consumed them). Most-recent first.
    @Published private(set) var history: [SessionIntent] = []

    static let historyCap = 30
    private let accountKey = "NoumAccountID"
    private let historyKeyPrefix = "sessionIntent.history."

    private init() {}

    // MARK: - Lifecycle

    func reloadForCurrentAccount() {
        pendingIntent = nil
        guard let accountID = currentAccountID else {
            history = []
            return
        }
        history = Self.loadHistory(forKey: historyKey(for: accountID))
    }

    func endSession() {
        pendingIntent = nil
        history = []
    }

    // MARK: - API

    /// Record the user's declared intent for the next rep. Replaces any
    /// existing pending intent (the user can change their mind before
    /// the rep starts).
    func setPending(_ intent: SessionIntent) {
        pendingIntent = intent
    }

    /// Drop a pending intent without attaching it to a session. Used
    /// when the user backs out of the prompt or abandons the rep
    /// without finishing.
    func clearPending() {
        pendingIntent = nil
    }

    /// Attach the pending intent to a freshly-finalized session. Writes
    /// the intent into the bounded history, clears `pendingIntent`,
    /// and returns the consumed intent (so the caller can attach the
    /// `priority`/`label` to the session row itself). Returns nil when
    /// no intent was pending — the most common path.
    @discardableResult
    func consume(sessionID: UUID) -> SessionIntent? {
        guard var intent = pendingIntent else { return nil }
        intent.sessionID = sessionID
        appendToHistory(intent)
        pendingIntent = nil
        return intent
    }

    // MARK: - Auth wipe

    func deleteAllData(for accountID: String) {
        UserDefaults.standard.removeObject(forKey: historyKey(for: accountID))
        if currentAccountID == accountID {
            pendingIntent = nil
            history = []
        }
    }

    // MARK: - Private

    private func appendToHistory(_ intent: SessionIntent) {
        var updated = history
        updated.insert(intent, at: 0)
        if updated.count > Self.historyCap {
            updated = Array(updated.prefix(Self.historyCap))
        }
        history = updated
        guard let accountID = currentAccountID,
              let data = try? JSONEncoder().encode(updated) else { return }
        UserDefaults.standard.set(data, forKey: historyKey(for: accountID))
    }

    private func historyKey(for accountID: String) -> String {
        "\(historyKeyPrefix)\(accountID)"
    }

    private var currentAccountID: String? {
        KeychainHelper.load(key: accountKey)
    }

    private static func loadHistory(forKey key: String) -> [SessionIntent] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let intents = try? JSONDecoder().decode([SessionIntent].self, from: data) else {
            return []
        }
        return intents
    }
}
