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

    // MARK: - Per-scenario trace points (trust + tension sparkline)
    //
    // One point per rep in the scenario, ordered oldest-to-newest so a
    // Chart consumer reads left-to-right as time-moves-forward. Only
    // reps with a recorded `finalState` contribute — early-abandoned
    // conversations have no relational state to plot. Used by
    // `IMScenarioDetailView` to surface the per-scenario trust +
    // tension trace beneath the summary header.
    //
    // Defensive contracts (locked by `IMScenarioTracePointsTests`):
    //   • filters to `.imConversation` internally — an upstream filter
    //     mistake produces an empty result, not a mixed-mode trace
    //   • ignores reps with `imConversationDetails == nil` or
    //     `finalState == nil` (can't plot a non-existent state)
    //   • drops cross-scenario reps so the caller can pass the whole
    //     `PracticeSessionStore` and still get one scenario's trace
    //   • orders oldest → newest so chart `x` axis reads forward in time
    //   • uses normalized 1–10 values via `IMConversationState.
    //     normalizedTrust`/`normalizedTension` — out-of-range engine
    //     output can never produce a chart point past the visible band
    struct IMScenarioTracePoint: Equatable, Identifiable {
        let id: UUID
        let date: Date
        let trust: Int
        let tension: Int
    }

    static func tracePoints(
        from sessions: [PracticeSession],
        scenario: IMConversationScenario
    ) -> [IMScenarioTracePoint] {
        sessions
            .compactMap { session -> IMScenarioTracePoint? in
                guard session.mode == .imConversation,
                      let details = session.imConversationDetails,
                      details.setup.scenario == scenario,
                      let final = details.finalState else { return nil }
                return IMScenarioTracePoint(
                    id: session.id,
                    date: session.date,
                    trust: final.normalizedTrust,
                    tension: final.normalizedTension
                )
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Per-scenario tone-match stats
    //
    // Compares each rep's free-form `actualTone` (the post-rep
    // evaluator's reading of how the user actually sounded) against
    // the `targetTone` the user committed to at setup, and surfaces
    // a per-scenario hit rate. The pure helper exists so the visual
    // strip on `IMScenarioDetailView` and any test fixture read the
    // same matcher; the matcher itself is also testable.
    //
    // Match logic: case-insensitive substring containment of the
    // target tone's English title (e.g., "confident") inside the
    // lowercased `actualTone` string. This is the same shape the
    // server-side evaluator uses when producing the `actualTone`
    // readout, so the match rate is honest about what the engine
    // observed — not an interpretation the user has to read between.
    //
    // Defensive contracts (locked by `IMScenarioToneMatchStatsTests`):
    //   • filters to `.imConversation` internally
    //   • ignores reps where `actualTone == nil` (the evaluator didn't
    //     produce a reading — that's not a miss, it's missing data)
    //   • drops cross-scenario reps so callers can pass the whole
    //     session list
    //   • `lastFive` is ordered newest-first so the visual strip's
    //     leftmost chip reads as "the most recent rep"
    //   • `matchRate` is `nil` when `evaluatedCount == 0` (no honest
    //     denominator → no fabricated zero percent)
    struct IMScenarioToneMatchStats: Equatable {
        let evaluatedCount: Int
        let matchCount: Int
        let matchRate: Double?
        /// Newest-first; bounded at 5 so the strip reads as a quick
        /// recency cue, not a deep history.
        let lastFive: [LastFiveEntry]

        struct LastFiveEntry: Equatable, Identifiable {
            let id: UUID
            let matched: Bool
            let date: Date
        }
    }

    static func toneMatchStats(
        from sessions: [PracticeSession],
        scenario: IMConversationScenario
    ) -> IMScenarioToneMatchStats {
        let evaluated: [(session: PracticeSession, target: IMTargetTone, actual: String)] = sessions
            .compactMap { session in
                guard session.mode == .imConversation,
                      let details = session.imConversationDetails,
                      details.setup.scenario == scenario,
                      let actual = details.actualTone,
                      !actual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { return nil }
                return (session, details.setup.targetTone, actual)
            }
        let matches = evaluated.map { matches(targetTone: $0.target, actualTone: $0.actual) }
        let matchCount = matches.filter { $0 }.count
        let matchRate: Double? = evaluated.isEmpty
            ? nil
            : (Double(matchCount) / Double(evaluated.count) * 100).rounded() / 100

        let recent = zip(evaluated, matches)
            .sorted { $0.0.session.date > $1.0.session.date }
            .prefix(5)
            .map { pair in
                IMScenarioToneMatchStats.LastFiveEntry(
                    id: pair.0.session.id,
                    matched: pair.1,
                    date: pair.0.session.date
                )
            }

        return IMScenarioToneMatchStats(
            evaluatedCount: evaluated.count,
            matchCount: matchCount,
            matchRate: matchRate,
            lastFive: Array(recent)
        )
    }

    /// Exposed as a pure static for testability — the matcher rule the
    /// chart strip relies on. Case-insensitive substring containment
    /// of the target tone's English title in `actualTone`. Whitespace
    /// is trimmed; empty `actualTone` is always a non-match (the test
    /// fixtures exercise it, but the higher-level helper filters those
    /// out first so the visual strip doesn't render a fabricated cell).
    static func matches(targetTone: IMTargetTone, actualTone: String) -> Bool {
        let trimmed = actualTone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return trimmed.lowercased().contains(targetTone.title.lowercased())
    }
}
