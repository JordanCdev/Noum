import Foundation

// MARK: - IMHistorySummary
//
// Pure helper for summarizing IM (conversation) reps by scenario.
// Mirrors the per-difficulty shape of `SuddenDeathHistorySummary`,
// adapted for IM: instead of the Sudden Death difficulty axis the IM
// breakdown is keyed by `IMConversationScenario` — the four built-in
// social/professional setups (Social Catch-Up, Work Update,
// Difficult Conversation, Networking).
//
// IM is the mode where the user's job is to hold a conversation under
// social pressure — so the per-scenario signal is composite: how
// well they scored, plus the relational state they left the
// conversation in (trust + tension at the final beat). Surfacing
// scenario-level averages tells the user "you do well on networking
// chats, but Difficult Conversation is where you lose composure" —
// the kind of read the £130/hr human coach would give after
// reviewing the last 10 reps across all four setups.
//
// Vision-aligned (docs/VISION.md pillar #3 — Conversational
// intelligence + pillar #4 — Believable progress): every number
// surfaced here came from the engine at finalize time. No invented
// narrative; no AI-generated copy. The user's own track record.

@available(iOS 17.0, *)
struct IMScenarioBreakdown: Equatable, Identifiable {
    let scenario: IMConversationScenario
    let runCount: Int
    /// Mean `session.score` across scored reps in this scenario,
    /// rounded to one decimal place. `nil` when no rep is scored
    /// (older sessions can carry `score == nil`).
    let averageScore: Double?
    /// Highest scored rep in this scenario. `nil` when no rep is
    /// scored. Tiebreak by most-recent date so the user reads
    /// "today's best" before "last month's best."
    let bestScore: Int?
    /// Session date of the best-scoring rep, when present. Surfaced
    /// alongside `bestScore` on the row so the user can read "9/10
    /// last week" — concrete and time-anchored.
    let bestScoreDate: Date?
    /// Mean of `finalState.trust` across reps that have a final
    /// state, rounded to one decimal place. `nil` when no rep
    /// produced a final state (early-abandoned conversations).
    let averageFinalTrust: Double?
    /// Mean of `finalState.tension` across reps that have a final
    /// state, rounded to one decimal place. `nil` when no rep
    /// produced a final state.
    let averageFinalTension: Double?
    /// `completedAt`-equivalent of the most-recent rep in this
    /// scenario. Used to sort the breakdown so the scenario the
    /// user touched last renders first.
    let lastPlayed: Date

    var id: IMConversationScenario { scenario }
}

@available(iOS 17.0, *)
enum IMHistorySummary {

    /// Produce per-scenario breakdowns from a list of IM
    /// `PracticeSession` rows. Callers pass already-filtered IM
    /// sessions; defensive in any case — sessions whose `mode !=
    /// .imConversation` are dropped silently so an upstream filter
    /// mistake produces an empty result, not a mixed-mode aggregate.
    /// Sessions without `imConversationDetails` (the conversation
    /// metadata) are also dropped — we can't classify a scenario for
    /// a rep that didn't record one.
    ///
    /// Sort order: most-recently played first (so a user who's been
    /// grinding "Difficult Conversation" sees it at the top even when
    /// they have older "Networking" runs).
    static func breakdowns(from sessions: [PracticeSession]) -> [IMScenarioBreakdown] {
        let runs: [(PracticeSession, IMConversationDetails)] = sessions.compactMap { session in
            guard session.mode == .imConversation,
                  let details = session.imConversationDetails else { return nil }
            return (session, details)
        }
        guard !runs.isEmpty else { return [] }

        let grouped = Dictionary(grouping: runs) { $0.1.setup.scenario }

        let summaries: [IMScenarioBreakdown] = grouped.compactMap { (scenario, scenarioRuns) in
            guard let lastPlayed = scenarioRuns.map({ $0.0.date }).max() else { return nil }

            // Average score across scored reps.
            let scored = scenarioRuns.compactMap { $0.0.score }
            let averageScore: Double? = {
                guard !scored.isEmpty else { return nil }
                let mean = Double(scored.reduce(0, +)) / Double(scored.count)
                return (mean * 10).rounded() / 10
            }()

            // Best scored rep + date — used for the row subtitle so
            // the user reads "9/10 last week" not just "9/10."
            let bestPair: (Int, Date)? = scenarioRuns
                .compactMap { (session, _) -> (Int, Date)? in
                    guard let score = session.score else { return nil }
                    return (score, session.date)
                }
                .sorted { lhs, rhs in
                    if lhs.0 != rhs.0 { return lhs.0 > rhs.0 }
                    return lhs.1 > rhs.1
                }
                .first

            // Average relational state across reps that recorded a
            // final state.
            let finalStates = scenarioRuns.compactMap { $0.1.finalState }
            let averageFinalTrust: Double? = {
                guard !finalStates.isEmpty else { return nil }
                let mean = Double(finalStates.map(\.normalizedTrust).reduce(0, +)) / Double(finalStates.count)
                return (mean * 10).rounded() / 10
            }()
            let averageFinalTension: Double? = {
                guard !finalStates.isEmpty else { return nil }
                let mean = Double(finalStates.map(\.normalizedTension).reduce(0, +)) / Double(finalStates.count)
                return (mean * 10).rounded() / 10
            }()

            return IMScenarioBreakdown(
                scenario: scenario,
                runCount: scenarioRuns.count,
                averageScore: averageScore,
                bestScore: bestPair?.0,
                bestScoreDate: bestPair?.1,
                averageFinalTrust: averageFinalTrust,
                averageFinalTension: averageFinalTension,
                lastPlayed: lastPlayed
            )
        }
        return summaries.sorted { $0.lastPlayed > $1.lastPlayed }
    }

    /// Total IM run count across every scenario. Used by the card
    /// header so the user can read "8 total reps" at a glance.
    static func totalRunCount(from sessions: [PracticeSession]) -> Int {
        sessions.reduce(0) { count, session in
            (session.mode == .imConversation && session.imConversationDetails != nil) ? count + 1 : count
        }
    }

    /// Most recent IM rep date across the entire set, or nil when
    /// empty. Used to decide whether to render the card at all.
    static func mostRecentDate(from sessions: [PracticeSession]) -> Date? {
        sessions
            .filter { $0.mode == .imConversation && $0.imConversationDetails != nil }
            .map(\.date)
            .max()
    }

    /// "Best rep of the current 7-day window" — the highest-scoring
    /// IM rep whose `date` lands inside the most-recent 7 days from
    /// `now`. Tiebreak by most-recent date so the user reads "today's
    /// best" before "Tuesday's best" when both tie at the same score.
    /// Returns nil when no scored rep falls inside the window — the
    /// breakdown card omits the chip rather than fabricating one.
    /// Mirrors the shape of `SuddenDeathHistorySummary.bestThisWeek`
    /// so SD + IM read as one design language on the History surface.
    static func bestThisWeek(
        from sessions: [PracticeSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (session: PracticeSession, scenario: IMConversationScenario, score: Int)? {
        guard let windowStart = calendar.date(byAdding: .day, value: -7, to: now) else {
            return nil
        }
        let inWindow = sessions.compactMap { session -> (PracticeSession, IMConversationScenario, Int)? in
            guard session.mode == .imConversation,
                  let details = session.imConversationDetails,
                  let score = session.score,
                  session.date >= windowStart,
                  session.date <= now else { return nil }
            return (session, details.setup.scenario, score)
        }
        guard !inWindow.isEmpty else { return nil }
        return inWindow.sorted { lhs, rhs in
            if lhs.2 != rhs.2 { return lhs.2 > rhs.2 }
            return lhs.0.date > rhs.0.date
        }.first
    }
}
