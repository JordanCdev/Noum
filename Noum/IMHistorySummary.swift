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
        let toneMatches = evaluated.map { matches(targetTone: $0.target, actualTone: $0.actual) }
        let matchCount = toneMatches.filter { $0 }.count
        let matchRate: Double? = evaluated.isEmpty
            ? nil
            : (Double(matchCount) / Double(evaluated.count) * 100).rounded() / 100

        let recent = zip(evaluated, toneMatches)
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

    // MARK: - Per-scenario relational trend (trust + tension direction)
    //
    // Reduces the per-rep trace into a single one-glance read: across
    // this scenario, is trust rising and tension falling, or the
    // reverse? The trace chart shows the *shape*; this carries the
    // *read* in two small chips on the scenario header.
    //
    // Method: compare the mean of the earliest `window` reps against
    // the mean of the latest `window` reps, where `window =
    // min(3, count / 2)`. That bound guarantees the two windows never
    // overlap (2·window ≤ count for all counts), so the early stretch
    // and the recent stretch are genuinely disjoint — no rep is
    // double-counted on both sides of the comparison.
    //
    // `Movement` is the *raw numeric* direction of each metric (up /
    // down / flat). The caller maps it to good/bad coloring knowing
    // trust-up is good and tension-down is good — the helper stays
    // honest about what the numbers did and leaves the value judgment
    // to the view. A delta smaller than `relationalTrendThreshold`
    // (0.5 on the 1–10 scale) reads as `.flat`: below that the line is
    // noise, not a trend.
    //
    // Defensive contracts (locked by `IMScenarioRelationalTrendTests`):
    //   • reuses `tracePoints(from:scenario:)` so it inherits the same
    //     `.imConversation` filter, final-state requirement, scenario
    //     filter, and oldest→newest ordering
    //   • returns nil below 4 contributing reps — fewer than that can't
    //     separate a "first stretch" from a "recent stretch" honestly
    //   • the two averaging windows never overlap
    //   • `.flat` when |delta| < 0.5 (per metric, independently)
    struct IMScenarioRelationalTrend: Equatable {
        enum Movement: Equatable { case up, down, flat }
        let trust: Movement
        let tension: Movement
        /// Latest-window mean − earliest-window mean, rounded to 0.1.
        let trustDelta: Double
        let tensionDelta: Double
        /// Reps averaged in each window (the `min(3, count / 2)` bound).
        let windowSize: Int
        /// True when at least one of trust / tension carries a non-flat
        /// read — the header chips self-hide entirely when this is false.
        var hasSignal: Bool { trust != .flat || tension != .flat }
    }

    /// Minimum mean delta (on the 1–10 scale) for a metric to read as a
    /// trend rather than flat. Shared with the test suite so the
    /// boundary is asserted, not guessed.
    static let relationalTrendThreshold = 0.5

    static func relationalTrend(
        from sessions: [PracticeSession],
        scenario: IMConversationScenario
    ) -> IMScenarioRelationalTrend? {
        let points = tracePoints(from: sessions, scenario: scenario)
        guard points.count >= 4 else { return nil }

        let window = min(3, points.count / 2)
        let early = points.prefix(window)
        let late = points.suffix(window)

        let earlyTrust = Double(early.map(\.trust).reduce(0, +)) / Double(early.count)
        let lateTrust = Double(late.map(\.trust).reduce(0, +)) / Double(late.count)
        let earlyTension = Double(early.map(\.tension).reduce(0, +)) / Double(early.count)
        let lateTension = Double(late.map(\.tension).reduce(0, +)) / Double(late.count)

        let trustDelta = ((lateTrust - earlyTrust) * 10).rounded() / 10
        let tensionDelta = ((lateTension - earlyTension) * 10).rounded() / 10

        func movement(_ delta: Double) -> IMScenarioRelationalTrend.Movement {
            if delta >= relationalTrendThreshold { return .up }
            if delta <= -relationalTrendThreshold { return .down }
            return .flat
        }

        return IMScenarioRelationalTrend(
            trust: movement(trustDelta),
            tension: movement(tensionDelta),
            trustDelta: trustDelta,
            tensionDelta: tensionDelta,
            windowSize: window
        )
    }

    // MARK: - Cross-scenario tone-drill signal
    //
    // Scans every scenario's tone-match stats and surfaces the single
    // scenario where the user most reliably misses the tone they
    // committed to — the highest-leverage place for the recommendation
    // engine to prescribe a focused re-rep. This is the *act* half of
    // the loop whose *read* half (the trust/tension + tone-match chips)
    // already lives on the IM History list and scenario detail: the
    // chips tell the user "your tone keeps slipping in Difficult
    // Conversation"; this lets the coach card answer "so drill exactly
    // that, with that tone, right now."
    //
    // Honest evidence bar (the only thing that makes this a coaching
    // signal rather than noise): a scenario qualifies only with
    // `evaluatedCount >= minEvaluatedReps` AND `matchRate <
    // matchRateThreshold`. A low hit rate on one or two reps is not a
    // pattern; an undefined rate (no evaluated reps) is not a miss.
    // Returns nil when nothing clears the bar — the engine then falls
    // back to its normal goal-based bias.
    //
    // Selection when several scenarios qualify: worst hit rate first
    // (most coaching leverage), tiebreak by evaluatedCount (more
    // evidence is more trustworthy), then by the most-recent evaluated
    // rep (freshest read). `targetTone` is the tone the user committed
    // to most often in that scenario's evaluated reps (tiebreak
    // most-recent) — the exact target the drill should re-set.
    //
    // Defensive contracts (locked by `IMToneDrillSignalTests`):
    //   • reuses `toneMatchStats` so it inherits the same
    //     `.imConversation` filter, scenario filter, and
    //     missing/whitespace-`actualTone` exclusion
    //   • nil below the rep bar and at/above the rate threshold
    //   • `targetTone` is computed over the same evaluated reps that
    //     produced the hit rate, never a profile default
    struct IMToneDrillCandidate: Equatable {
        let signal: IMToneDrillSignal
        let lastEvaluatedDate: Date
    }

    /// Hit rate (0.0–1.0) a scenario must fall *below* to read as a
    /// tone gap worth drilling. 0.4 == "lands less than 40% of the
    /// time." Shared with the test suite so the boundary is asserted.
    static let toneDrillMatchRateThreshold = 0.4

    /// Minimum evaluated (actual-tone-bearing) reps a scenario needs
    /// before a low hit rate counts as a pattern rather than noise.
    static let toneDrillMinEvaluatedReps = 3

    static func toneDrillSignal(
        from sessions: [PracticeSession],
        matchRateThreshold: Double = toneDrillMatchRateThreshold,
        minEvaluatedReps: Int = toneDrillMinEvaluatedReps
    ) -> IMToneDrillSignal? {
        let candidates: [IMToneDrillCandidate] = IMConversationScenario.allCases.compactMap { scenario in
            let stats = toneMatchStats(from: sessions, scenario: scenario)
            guard stats.evaluatedCount >= minEvaluatedReps,
                  let rate = stats.matchRate,
                  rate < matchRateThreshold,
                  let dominant = dominantEvaluatedTone(from: sessions, scenario: scenario)
            else { return nil }
            return IMToneDrillCandidate(
                signal: IMToneDrillSignal(
                    scenario: scenario,
                    targetTone: dominant.tone,
                    matchRate: rate,
                    evaluatedCount: stats.evaluatedCount
                ),
                lastEvaluatedDate: dominant.lastDate
            )
        }

        let winner = candidates.sorted { lhs, rhs in
            if lhs.signal.matchRate != rhs.signal.matchRate {
                return lhs.signal.matchRate < rhs.signal.matchRate          // worst hit rate first
            }
            if lhs.signal.evaluatedCount != rhs.signal.evaluatedCount {
                return lhs.signal.evaluatedCount > rhs.signal.evaluatedCount // more evidence first
            }
            return lhs.lastEvaluatedDate > rhs.lastEvaluatedDate            // freshest read first
        }.first

        guard let winner else { return nil }
        // Attach the Adaptation read for the selected scenario so the
        // engine can reinforce a recovering drill or change a slipping
        // one. Computed only for the winner — the other candidates are
        // never prescribed, so their trajectory isn't needed.
        let base = winner.signal
        return IMToneDrillSignal(
            scenario: base.scenario,
            targetTone: base.targetTone,
            matchRate: base.matchRate,
            evaluatedCount: base.evaluatedCount,
            progress: toneDrillProgress(from: sessions, scenario: base.scenario)
        )
    }

    // MARK: - Tone-drill Adaptation read (is the drill working?)
    //
    // The *Adaptation* half of the IM tone-drill loop (docs/VISION.md
    // coach-parity stage #4). `toneDrillSignal` prescribes the scenario +
    // tone to re-rep; this reads whether the user's hit rate in that
    // scenario is actually recovering across their recent reps, so the
    // coach can reinforce a drill that is landing or change the approach
    // on one that is stuck — rather than giving the identical "you missed
    // X%" line every time regardless of response.
    //
    // Method mirrors `relationalTrend`: compare the tone-match rate of the
    // earliest `window` evaluated reps against the latest `window`, where
    // `window = min(3, count / 2)` so the two windows are always disjoint.
    // A swing of at least `toneDrillProgressThreshold` reads as
    // recovering / slipping; anything smaller is stalled. Because each
    // window holds 2–3 reps, the smallest possible non-zero swing (one rep
    // flipping in a 2-rep window) is 0.5 — comfortably above the 0.15
    // threshold — so the boundary is robust to fractional rounding.
    //
    // Defensive contracts (locked by `IMToneDrillProgressTests`):
    //   • reuses the same `.imConversation` + scenario filter and the same
    //     missing/whitespace-`actualTone` exclusion as `toneMatchStats`
    //   • orders evaluated reps oldest → newest so "earlier" really is the
    //     first stretch in time
    //   • nil below 4 evaluated reps (fewer can't separate two windows)
    //   • windows never overlap
    //   • `.stalled` when |recentRate − earlierRate| < threshold

    /// Minimum swing in tone-match rate (0.0–1.0) between the earliest and
    /// latest windows for the trajectory to read as recovering/slipping
    /// rather than stalled. Shared with the test suite so the boundary is
    /// asserted, not guessed.
    static let toneDrillProgressThreshold = 0.15

    static func toneDrillProgress(
        from sessions: [PracticeSession],
        scenario: IMConversationScenario
    ) -> IMToneDrillProgress? {
        let outcomes: [Bool] = sessions
            .compactMap { session -> (date: Date, matched: Bool)? in
                guard session.mode == .imConversation,
                      let details = session.imConversationDetails,
                      details.setup.scenario == scenario,
                      let actual = details.actualTone,
                      !actual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { return nil }
                return (session.date, matches(targetTone: details.setup.targetTone, actualTone: actual))
            }
            .sorted { $0.date < $1.date }   // oldest → newest
            .map { $0.matched }

        guard outcomes.count >= 4 else { return nil }

        let window = min(3, outcomes.count / 2)
        let earlier = outcomes.prefix(window)
        let recent = outcomes.suffix(window)

        let earlierRate = Double(earlier.filter { $0 }.count) / Double(earlier.count)
        let recentRate = Double(recent.filter { $0 }.count) / Double(recent.count)
        let delta = recentRate - earlierRate

        let direction: IMToneDrillProgress.Direction
        if delta >= toneDrillProgressThreshold {
            direction = .recovering
        } else if delta <= -toneDrillProgressThreshold {
            direction = .slipping
        } else {
            direction = .stalled
        }

        return IMToneDrillProgress(
            direction: direction,
            earlierRate: (earlierRate * 100).rounded() / 100,
            recentRate: (recentRate * 100).rounded() / 100,
            windowSize: window
        )
    }

    /// The tone the user committed to most often among a scenario's
    /// evaluated reps (those that produced a non-empty `actualTone`),
    /// with the date of the most-recent rep that used it. Tiebreak on
    /// count is the most-recent use, so a 2-2 split picks the tone the
    /// user is reaching for *now*. Returns nil when no evaluated rep
    /// exists — the caller already gates on `evaluatedCount`, so this
    /// is belt-and-suspenders.
    private static func dominantEvaluatedTone(
        from sessions: [PracticeSession],
        scenario: IMConversationScenario
    ) -> (tone: IMTargetTone, lastDate: Date)? {
        let evaluated: [(tone: IMTargetTone, date: Date)] = sessions.compactMap { session in
            guard session.mode == .imConversation,
                  let details = session.imConversationDetails,
                  details.setup.scenario == scenario,
                  let actual = details.actualTone,
                  !actual.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return nil }
            return (details.setup.targetTone, session.date)
        }
        guard !evaluated.isEmpty else { return nil }

        let grouped = Dictionary(grouping: evaluated, by: { $0.tone })
        let best = grouped.max { lhs, rhs in
            if lhs.value.count != rhs.value.count { return lhs.value.count < rhs.value.count }
            let lhsLatest = lhs.value.map(\.date).max() ?? .distantPast
            let rhsLatest = rhs.value.map(\.date).max() ?? .distantPast
            return lhsLatest < rhsLatest
        }
        guard let tone = best?.key,
              let lastDate = best?.value.map(\.date).max() else { return nil }
        return (tone, lastDate)
    }
}
