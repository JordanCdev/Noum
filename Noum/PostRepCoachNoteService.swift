import Foundation

// MARK: - PostRepCoachNoteService
//
// Generates a short, voice-shaped coaching note right after a rep
// finalizes — the £130/hr coach turning toward the user and saying
// "here's what I just saw." Two sentences max, no chirpy filler, no
// exclamation marks (brand-voice contract), and always honest about
// provenance (`isAIBacked: false` on the deterministic path so the
// surface can label accordingly).
//
// Mirrors the `ForwardPlanService` shape: actor for the async AI
// surface, `nonisolated static` deterministic fallback exposed for
// tests, JSON-strict response shape for the AI path, locale + provider
// guards so an English-only AI surface never produces English text on
// a Spanish or French rep.
//
// Design rules:
//   • The deterministic path is the source of truth. The AI path is a
//     polish layer that improves wording — never invents data.
//   • Voice carries through `CoachPersona.persona(for:)`. The same
//     facts produce different phrasing for an authoritative-voice user
//     vs. a warm-voice user vs. a concise-voice user.
//   • Never overclaim — the deterministic path cites only what the
//     session input contains. If filler count is zero, it says "clean
//     run." If filler count is high, it acknowledges it without
//     punishing.
//   • Bounded length — `noteText` ≤ 200 chars across both paths so the
//     hero card never has to truncate.

/// Self-contained input snapshot. Constructed once on the call site
/// (typically inside `PracticeSessionFinalizer.finalize`) so the
/// service stays pure — no singleton reads inside the actor, which
/// keeps the deterministic fallback unit-testable without provider
/// stubs.
struct PostRepCoachNoteInput {
    let sessionID: UUID
    let mode: PracticeMode
    let score: Int?
    let fillerCount: Int
    let duration: TimeInterval
    let wordCount: Int
    let voice: SpeakingStyleGoal?
    let intentLabel: String?
    let baselineFillerRate: Double?     // per-minute, nil when insufficient data
    let baselinePaceWPM: Double?        // average WPM, nil when insufficient data
    let bigMoment: BigMoment?
    let bigMomentDaysUntil: Int?
    /// What the user actually said in this rep. Empty when the rep didn't
    /// produce a transcript (silence, IM mode pre-finalize). When present,
    /// the AI path is required to reference a specific phrase or moment
    /// rather than restate the stats above.
    let transcript: String
    /// The question this rep answered (`PracticeSession.prompt`). Lets the AI
    /// path judge "did you answer it / where did the point land" instead of
    /// only quoting a phrase — the one thing a coach checks first. Empty when
    /// unknown (IM, silence, legacy). Defaulted in the init so every existing
    /// call site + test fixture compiles unchanged.
    let prompt: String
    /// Short descriptors of the last few sessions (mode, score, key signal)
    /// so the AI can write "this rep" vs "the last few" continuity copy.
    /// Empty for first-rep users; deterministic fallback handles that case.
    let recentSessionSummaries: [String]
    /// Verbatim quotes from the user's banked Proof Moments — past reps
    /// where the coach caught something worth remembering. Lets the AI
    /// say "three weeks ago you said X" instead of generic motivational
    /// framing. Empty for cold-start users.
    let recentProofQuotes: [String]

    // MARK: - Momentum signals (cross-session trajectory)
    //
    // Added to make the deterministic note feel like a coach who tracks
    // trajectory, not just this rep's metrics. Each field is computed by
    // `MomentumComputer.compute(...)` and defaults to a safe zero/nil
    // so every existing call site compiles unchanged.

    /// How many consecutive recent reps had fillers at or below half the
    /// baseline rate (i.e. "clean" reps). 0 when no streak or baseline
    /// is insufficient.
    let consecutiveCleanReps: Int
    /// Direction of the filler rate across the last 6 sessions (last 3
    /// vs prior 3). Nil when fewer than 6 sessions exist.
    let fillerTrendDirection: TrendDirection?
    /// Direction of scores across the last 6 scored sessions. Nil when
    /// fewer than 6 scored sessions exist.
    let scoreTrendDirection: TrendDirection?
    /// Number of reps completed in the current ISO week.
    let weeklyRepCount: Int
    /// True when this session's score exceeds all prior same-mode scores
    /// and there are at least 3 prior scored sessions in the same mode.
    let isPersonalBest: Bool
    /// Total number of sessions across all time. Guards against thin-data
    /// overclaiming ("third clean rep" when the user has 3 total reps).
    let totalSessionCount: Int

    // MARK: - IM tone-drill Adaptation read
    //
    // When the just-finished rep was an IM conversation, the Adaptation read
    // for that rep's scenario — whether the committed tone is recovering or
    // slipping across the user's recent reps in it. Lets the post-rep note
    // speak to whether the tone work is landing ("your calm tone is
    // recovering"), the same Adaptation signal the next-practice card and
    // the chat coach now read. nil for non-IM reps and for thin histories
    // (fewer than the 4 evaluated reps the read needs). The scenario + tone
    // titles travel as plain strings so the service stays decoupled from the
    // IM enums.

    /// Tone-match trajectory for the just-finished IM rep's scenario, or nil
    /// for non-IM reps / thin histories.
    let imToneDrillProgress: IMToneDrillProgress?
    /// Display title of the just-finished IM rep's scenario (e.g. "Difficult
    /// Conversation"). nil when `imToneDrillProgress` is nil.
    let imToneDrillScenarioTitle: String?
    /// Display title of the tone the user committed to in that rep (e.g.
    /// "Calm"). nil when `imToneDrillProgress` is nil.
    let imToneDrillToneTitle: String?

    // MARK: - IM tone-drill SOLVED read (the win, on the crossing rep)
    //
    // The terminal state of the tone-drill loop. `imToneDrillProgress`
    // above speaks to a drill still *in flight* (recovering / slipping);
    // this fires the moment the just-finished rep is the one that pushes a
    // scenario's committed tone across the drill bar — newly resolved this
    // rep, holding above the bar. A human coach who pushed you on a tone
    // for weeks names the win once when it finally holds, then moves you on
    // — so this branch outranks every other note signal but is gated
    // upstream (the finalizer's resolved-with-vs-without-this-rep crossing
    // check) to fire exactly once, never repeating on later reps in the
    // same scenario. nil on every non-crossing rep.

    /// Resolved read for the just-finished IM rep's scenario, set only when
    /// this rep is the crossing rep. nil otherwise (including all non-IM
    /// reps and every rep after the one that crossed).
    let imToneDrillResolved: IMToneDrillResolved?
    /// Display title of the resolved scenario. nil when `imToneDrillResolved`
    /// is nil. Carried as a string so the service stays decoupled from the
    /// IM enums, mirroring the in-flight trajectory trio above.
    let imToneDrillResolvedScenarioTitle: String?
    /// Display title of the dominant committed tone in that scenario — the
    /// tone the drill was working — which can differ from this single rep's
    /// committed tone. nil when `imToneDrillResolved` is nil.
    let imToneDrillResolvedToneTitle: String?

    init(
        sessionID: UUID,
        mode: PracticeMode,
        score: Int?,
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        voice: SpeakingStyleGoal?,
        intentLabel: String?,
        baselineFillerRate: Double?,
        baselinePaceWPM: Double?,
        bigMoment: BigMoment?,
        bigMomentDaysUntil: Int?,
        transcript: String = "",
        prompt: String = "",
        recentSessionSummaries: [String] = [],
        recentProofQuotes: [String] = [],
        consecutiveCleanReps: Int = 0,
        fillerTrendDirection: TrendDirection? = nil,
        scoreTrendDirection: TrendDirection? = nil,
        weeklyRepCount: Int = 0,
        isPersonalBest: Bool = false,
        totalSessionCount: Int = 0,
        imToneDrillProgress: IMToneDrillProgress? = nil,
        imToneDrillScenarioTitle: String? = nil,
        imToneDrillToneTitle: String? = nil,
        imToneDrillResolved: IMToneDrillResolved? = nil,
        imToneDrillResolvedScenarioTitle: String? = nil,
        imToneDrillResolvedToneTitle: String? = nil
    ) {
        self.sessionID = sessionID
        self.mode = mode
        self.score = score
        self.fillerCount = fillerCount
        self.duration = duration
        self.wordCount = wordCount
        self.voice = voice
        self.intentLabel = intentLabel
        self.baselineFillerRate = baselineFillerRate
        self.baselinePaceWPM = baselinePaceWPM
        self.bigMoment = bigMoment
        self.bigMomentDaysUntil = bigMomentDaysUntil
        self.transcript = transcript
        self.prompt = prompt
        self.recentSessionSummaries = recentSessionSummaries
        self.recentProofQuotes = recentProofQuotes
        self.consecutiveCleanReps = consecutiveCleanReps
        self.fillerTrendDirection = fillerTrendDirection
        self.scoreTrendDirection = scoreTrendDirection
        self.weeklyRepCount = weeklyRepCount
        self.isPersonalBest = isPersonalBest
        self.totalSessionCount = totalSessionCount
        self.imToneDrillProgress = imToneDrillProgress
        self.imToneDrillScenarioTitle = imToneDrillScenarioTitle
        self.imToneDrillToneTitle = imToneDrillToneTitle
        self.imToneDrillResolved = imToneDrillResolved
        self.imToneDrillResolvedScenarioTitle = imToneDrillResolvedScenarioTitle
        self.imToneDrillResolvedToneTitle = imToneDrillResolvedToneTitle
    }
}

// MARK: - MomentumSignals
//
// Pure data snapshot of cross-session trajectory signals. Computed once
// at finalization time by `MomentumComputer` and projected into the
// `PostRepCoachNoteInput` momentum fields. Keeps the computation
// testable and the input struct construction straightforward.

struct MomentumSignals {
    let consecutiveCleanReps: Int
    let fillerTrendDirection: TrendDirection?
    let scoreTrendDirection: TrendDirection?
    let weeklyRepCount: Int
    let isPersonalBest: Bool
    let totalSessionCount: Int
}

// MARK: - MomentumComputer
//
// Pure functions that derive momentum signals from session history.
// No singletons, no I/O, no async — inputs in, signals out. Each
// method is exposed at internal visibility for unit tests.

enum MomentumComputer {

    /// Compute all momentum signals from the finalized session + full
    /// session history + baseline. Clock and calendar are injectable
    /// for testing.
    static func compute(
        currentSession: PracticeSession,
        allSessions: [PracticeSession],
        baselineFillerRate: Double?,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> MomentumSignals {
        let sorted = allSessions.sorted { $0.date > $1.date }
        return MomentumSignals(
            consecutiveCleanReps: Self.consecutiveCleanReps(
                sorted: sorted,
                baselineFillerRate: baselineFillerRate
            ),
            fillerTrendDirection: Self.fillerTrend(sorted: sorted),
            scoreTrendDirection: Self.scoreTrend(sorted: sorted),
            weeklyRepCount: Self.weeklyRepCount(
                sorted: sorted, now: now, calendar: calendar
            ),
            isPersonalBest: Self.isPersonalBest(
                current: currentSession, allSessions: sorted
            ),
            totalSessionCount: sorted.count
        )
    }

    // MARK: - Individual signal computations

    /// Count consecutive recent reps where the filler rate is at or below
    /// half the baseline (or ≤1 filler total). Stops at the first rep
    /// that exceeds. Returns 0 when baseline is unavailable.
    static func consecutiveCleanReps(
        sorted: [PracticeSession],
        baselineFillerRate: Double?
    ) -> Int {
        guard let baseRate = baselineFillerRate, baseRate > 0 else { return 0 }
        var count = 0
        for session in sorted {
            let durationMinutes = max(session.duration / 60.0, 1.0 / 60.0)
            let sessionRate = Double(session.fillerWordCount) / durationMinutes
            let threshold = max(baseRate * 0.5, 0.5)
            if sessionRate <= threshold || session.fillerWordCount <= 1 {
                count += 1
            } else {
                break
            }
        }
        return count
    }

    /// Filler rate direction: last 3 sessions vs prior 3. Nil when fewer
    /// than 6 sessions exist. "Improving" = recent avg is ≤70% of prior.
    static func fillerTrend(sorted: [PracticeSession]) -> TrendDirection? {
        guard sorted.count >= 6 else { return nil }
        let recent = sorted.prefix(3)
        let prior = sorted.dropFirst(3).prefix(3)

        func avgRate(_ sessions: some Collection<PracticeSession>) -> Double {
            let rates = sessions.map { s -> Double in
                let mins = max(s.duration / 60.0, 1.0 / 60.0)
                return Double(s.fillerWordCount) / mins
            }
            guard !rates.isEmpty else { return 0 }
            return rates.reduce(0, +) / Double(rates.count)
        }

        let recentAvg = avgRate(recent)
        let priorAvg = avgRate(prior)
        guard priorAvg > 0 else { return .stable }

        if recentAvg <= priorAvg * 0.7 { return .improving }
        if recentAvg >= priorAvg * 1.3 { return .declining }
        return .stable
    }

    /// Score direction: last 3 scored sessions vs prior 3. Nil when fewer
    /// than 6 scored sessions exist.
    static func scoreTrend(sorted: [PracticeSession]) -> TrendDirection? {
        let scored = sorted.filter { $0.score != nil }
        guard scored.count >= 6 else { return nil }
        let recent = scored.prefix(3).compactMap(\.score).map(Double.init)
        let prior = scored.dropFirst(3).prefix(3).compactMap(\.score).map(Double.init)
        guard !recent.isEmpty, !prior.isEmpty else { return nil }
        let recentAvg = recent.reduce(0, +) / Double(recent.count)
        let priorAvg = prior.reduce(0, +) / Double(prior.count)
        if recentAvg >= priorAvg + 1.0 { return .improving }
        if recentAvg <= priorAvg - 1.0 { return .declining }
        return .stable
    }

    /// Reps completed in the current ISO week.
    static func weeklyRepCount(
        sorted: [PracticeSession],
        now: Date,
        calendar: Calendar
    ) -> Int {
        let currentWeek = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear], from: now
        )
        return sorted.filter { session in
            let sessionWeek = calendar.dateComponents(
                [.yearForWeekOfYear, .weekOfYear], from: session.date
            )
            return sessionWeek.yearForWeekOfYear == currentWeek.yearForWeekOfYear
                && sessionWeek.weekOfYear == currentWeek.weekOfYear
        }.count
    }

    /// True when this session's score exceeds all prior same-mode scores
    /// and there are at least 3 prior scored sessions in the same mode.
    static func isPersonalBest(
        current: PracticeSession,
        allSessions: [PracticeSession]
    ) -> Bool {
        guard let currentScore = current.score else { return false }
        let priorScores = allSessions
            .filter { $0.id != current.id && $0.mode == current.mode }
            .compactMap(\.score)
        guard priorScores.count >= 3 else { return false }
        guard let priorMax = priorScores.max() else { return false }
        return currentScore > priorMax
    }

    // MARK: - IM tone-drill note fields anchored on the just-finished rep (round 43)
    //
    // The post-rep coach note's TRAJECTORY branch (recovering / slipping) and
    // SOLVED branch (the crossing win) both read from the just-finished rep's
    // scenario — never from a "freshest trajectory anywhere" global read. The
    // finalizer used to inline this block; round 43 lifts it into a pure
    // helper so the anchoring contract is testable in isolation.
    //
    // The defensive symmetric pin to round 41 (SOLVED freshness on the chat-
    // coach context surface) and round 42 (TRAJECTORY freshness on the chat-
    // coach context surface): the post-rep note doesn't need a freshness gate
    // because, by construction, the read IS the just-finished rep's scenario
    // — the user just produced the rep that anchors the read. The contract
    // worth locking is that the helper NEVER picks up scenario B's trajectory
    // when the just-finished rep is in scenario A, even when scenario B is
    // the user's loudest active sub-bar slip. `IMHistorySummary.toneDrillProgress`
    // already filters strictly by scenario; this helper threads the just-
    // finished rep's scenario through and surfaces the per-rep titles, so the
    // structural impossibility of cross-rep cold opens reads in one place.
    static func imToneDrillNoteFields(
        forJustFinished session: PracticeSession,
        in allSessions: [PracticeSession]
    ) -> IMToneDrillNoteFields {
        guard session.mode == .imConversation,
              let details = session.imConversationDetails else {
            return .empty
        }
        let scenario = details.setup.scenario
        let progress = IMHistorySummary.toneDrillProgress(
            from: allSessions, scenario: scenario
        )
        let scenarioTitle = scenario.title
        let toneTitle = details.setup.targetTone.title

        // Crossing detection routes through the same primitive as the hero
        // SOLVED ribbon (round 21) so the two surfaces can never drift. A
        // scenario already across the bar before this rep returns nil here —
        // SOLVED headlines exactly once, not on every rep after the crossing.
        if let crossed = IMHistorySummary.toneDrillCrossing(
            in: allSessions,
            scenario: scenario,
            currentRepId: session.id
        ) {
            return IMToneDrillNoteFields(
                progress: progress,
                scenarioTitle: scenarioTitle,
                toneTitle: toneTitle,
                resolved: crossed,
                resolvedScenarioTitle: scenarioTitle,
                resolvedToneTitle: crossed.targetTone.title
            )
        }
        return IMToneDrillNoteFields(
            progress: progress,
            scenarioTitle: scenarioTitle,
            toneTitle: toneTitle,
            resolved: nil,
            resolvedScenarioTitle: nil,
            resolvedToneTitle: nil
        )
    }
}

// MARK: - IMToneDrillNoteFields (round 43)
//
// Pure data snapshot of the IM tone-drill trio (trajectory + titles) and the
// SOLVED trio (resolved + titles) routed into the post-rep note's
// `PostRepCoachNoteInput`. Mirrors the `MomentumSignals` shape: inputs in,
// fields out, no I/O. The structural invariant: every non-nil field on this
// struct is derived from the just-finished rep's `imConversationDetails`
// (scenario + targetTone) — never from another scenario's history.

struct IMToneDrillNoteFields {
    let progress: IMToneDrillProgress?
    let scenarioTitle: String?
    let toneTitle: String?
    let resolved: IMToneDrillResolved?
    let resolvedScenarioTitle: String?
    let resolvedToneTitle: String?

    static let empty = IMToneDrillNoteFields(
        progress: nil,
        scenarioTitle: nil,
        toneTitle: nil,
        resolved: nil,
        resolvedScenarioTitle: nil,
        resolvedToneTitle: nil
    )
}

@available(iOS 17.0, macOS 12.0, *)
actor PostRepCoachNoteService {

    static let shared = PostRepCoachNoteService()

    private init() {}

    // MARK: - Public API

    /// Generate a note. Always returns something — the deterministic
    /// fallback runs when no AI provider is configured, when the
    /// locale doesn't support AI surfaces, or when the network fails.
    /// Callers use `result.isAIBacked` to know which path ran.
    func generate(input: PostRepCoachNoteInput) async -> PostRepCoachNote {
        let fallback = Self.deterministicNote(input: input)

        guard await activeLocaleSupportsAI() else {
            return fallback
        }
        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider) else {
            return fallback
        }

        // Rate-limit hidden polish-layer calls. Catches the burst
        // path (multiple voice changes in onboarding → multiple
        // regen requests) and the heavy-day path (a user grinding
        // 15+ reps). On a deny, the deterministic fallback is
        // already what the surface would have shown without an AI
        // provider configured — silent, honest degradation.
        guard await rateLimiterAllows() else {
            return fallback
        }

        do {
            let body = requestBody(for: provider, input: input)
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 14
            switch provider {
            case .openAI, .deepSeek:
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            case .gemini, .agentPlatform:                request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            case .none:
                return fallback
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return fallback
            }
            guard let noteText = parseNoteText(from: data, provider: provider) else {
                return fallback
            }
            // Validate brand-voice contract: no exclamations, no chirpy
            // filler, length cap. If the model misbehaves, fall back
            // rather than render policy-violating text.
            guard Self.passesBrandVoiceContract(noteText) else {
                return fallback
            }
            // Presence gate (mirrors GrammarFeedbackService's excerpt-must-
            // appear check): when there's a real rep to quote, the note must
            // actually engage the transcript — share a content word or a
            // verbatim slice — else it's a stat-restate dressed as a coach
            // read and we fall back to the deterministic note. Empty
            // transcript (IM / silent rep) -> nothing to quote -> gate passes.
            guard Self.engagesTranscript(noteText, input: input) else {
                return fallback
            }
            return PostRepCoachNote(
                sessionID: input.sessionID,
                voice: input.voice,
                noteText: noteText,
                isAIBacked: true
            )
        } catch {
            return fallback
        }
    }

    // MARK: - Deterministic fallback (pure, exposed for tests)

    /// Pure deterministic generation. Produces a voice-shaped 2-sentence
    /// note from session metrics + baseline + voice. Honest about being
    /// rule-based (`isAIBacked: false`).
    ///
    /// Shape: `<reflectionLead> <metric sentence>. <closing>.` where
    /// the metric sentence is built from a priority chain:
    ///
    /// 1. Filler count vs baseline → "Three fillers — half your usual."
    /// 2. Score band → "Clean read — that was an 8."
    /// 3. Pace outside 100-160 → "Pace ran 180 WPM — leaner is louder."
    /// 4. Duration < 20s → "Short rep, but the structure was clean."
    /// 5. Fallback → "Steady delivery. The fundamentals held."
    ///
    /// The chain ends as soon as one branch produces a sentence so the
    /// note stays focused on one thing — coach voice rule #1 of the
    /// PLAN.md.
    nonisolated static func deterministicNote(input: PostRepCoachNoteInput) -> PostRepCoachNote {
        let persona = CoachPersona.persona(for: input.voice)
        let seed = Int(input.sessionID.uuidString.hashValue)
        let lead = persona.reflectionLead
        let defaultClosing = persona.closing(seed: seed)

        let metric = metricSentence(for: input, persona: persona)

        // Suffix priority: BigMoment > weekly rhythm > default closing.
        // BigMoment anchors the user to their upcoming event; weekly rhythm
        // reinforces cadence. Only one suffix fires.
        let suffix: String = {
            if let days = input.bigMomentDaysUntil,
               let moment = input.bigMoment,
               let bigSuffix = bigMomentSuffix(
                   daysUntil: days,
                   category: moment.category,
                   persona: persona
               ) {
                return bigSuffix
            }
            if input.weeklyRepCount > 0,
               let rhythmSuffix = weeklyRhythmSuffix(
                   weeklyRepCount: input.weeklyRepCount,
                   persona: persona
               ) {
                return rhythmSuffix
            }
            return defaultClosing
        }()

        // Compose: "<lead> <metric> <suffix>"
        // Character budget check: if lead + metric + suffix exceeds 200,
        // fall back to default closing to avoid truncating mid-thought.
        var text: String
        let candidate = "\(lead) \(metric) \(suffix)"
        if candidate.count <= 200 || suffix == defaultClosing {
            text = candidate
        } else {
            text = "\(lead) \(metric) \(defaultClosing)"
        }
        text = collapseWhitespace(in: text)
        text = ensureNoExclamations(in: text)
        text = truncate(text, max: 200)

        return PostRepCoachNote(
            sessionID: input.sessionID,
            voice: input.voice,
            noteText: text,
            isAIBacked: false
        )
    }

    /// Priority chain that picks the one sentence to feature. Pure,
    /// exposed for tests.
    ///
    /// Momentum branches (0a–0d) sit above the per-rep metric branches
    /// (1–6) because they carry multi-session evidence — the coach
    /// quoting trajectory is higher-signal than quoting today's stats.
    nonisolated static func metricSentence(
        for input: PostRepCoachNoteInput,
        persona: CoachPersona
    ) -> String {
        // 0) IM tone-drill SOLVED — the rarest, most coaching-significant
        // signal: the just-finished rep is the one that pushed a scenario's
        // committed tone across the drill bar after a real gap. Outranks
        // every other branch (a closed prescribed-drill loop is the moment a
        // coach earns trust) but is gated upstream to fire exactly once, on
        // the crossing rep — so it never crowds the other branches on later
        // reps. Names the win and points the user on; the copy never
        // re-prescribes the beaten drill or claims a drill *caused* the
        // recovery (observed hit rate only — the same honesty bar as the
        // chat-coach SOLVED read).
        if let resolved = input.imToneDrillResolved,
           let scenario = input.imToneDrillResolvedScenarioTitle,
           let tone = input.imToneDrillResolvedToneTitle {
            return imToneResolvedSentence(
                resolved: resolved, scenario: scenario, tone: tone, persona: persona
            )
        }

        // 0a) Personal best — strongest momentum signal. Only fires when
        // there are enough prior sessions to make "best" meaningful.
        if input.isPersonalBest, input.totalSessionCount >= 5,
           let score = input.score {
            return personalBestSentence(score: score, persona: persona)
        }

        // 0b) Consecutive clean reps — the user is on a filler-free run.
        // Requires totalSessionCount >= 5 to avoid "3 clean in a row"
        // when the user has 3 total reps ever.
        if input.consecutiveCleanReps >= 3, input.totalSessionCount >= 5 {
            return consecutiveCleanSentence(count: input.consecutiveCleanReps, persona: persona)
        }

        // 0c) Filler trend improving — the rate is genuinely declining
        // across the last 6 sessions. Lower priority than personal best
        // and consecutive clean because it's a softer signal.
        if input.fillerTrendDirection == .improving, input.totalSessionCount >= 6 {
            return fillerTrendImprovingSentence(persona: persona)
        }

        // 0d) IM tone-drill trajectory — when this rep was an IM
        // conversation and the committed tone in its scenario is recovering
        // or slipping across recent reps, speak to that response (the
        // Adaptation read) ahead of the per-rep metrics. Multi-session
        // evidence specific to IM, so it sits with the other momentum
        // branches. Stalled reads fall through — a flat trajectory isn't
        // worth bumping the metric note.
        if let progress = input.imToneDrillProgress,
           progress.direction != .stalled,
           let scenario = input.imToneDrillScenarioTitle,
           let tone = input.imToneDrillToneTitle {
            return imToneTrajectorySentence(
                progress: progress, scenario: scenario, tone: tone, persona: persona
            )
        }

        // 1) Filler comparison vs baseline (when both signals exist).
        if let baselineRate = input.baselineFillerRate,
           baselineRate > 0,
           input.duration > 0 {
            let durationMinutes = max(input.duration / 60.0, 1.0 / 60.0)
            let sessionRate = Double(input.fillerCount) / durationMinutes
            if sessionRate <= max(baselineRate * 0.5, 0.5), input.fillerCount <= 2 {
                return fillerWinSentence(fillerCount: input.fillerCount, persona: persona)
            }
            if sessionRate >= baselineRate * 1.5, input.fillerCount >= 3 {
                return fillerLossSentence(fillerCount: input.fillerCount, persona: persona)
            }
        }

        // 2) Zero fillers — universal clean-run marker.
        if input.fillerCount == 0 && input.wordCount >= 20 {
            return fillerWinSentence(fillerCount: 0, persona: persona)
        }

        // 3) Score band when available.
        if let score = input.score {
            if score >= 8 {
                return strongScoreSentence(score: score, persona: persona)
            }
            if score <= 4 {
                return weakScoreSentence(score: score, persona: persona)
            }
        }

        // 4) Pace outside conversational range when measurable.
        if input.duration >= 15, input.wordCount >= 20 {
            let wpm = Double(input.wordCount) / (input.duration / 60.0)
            if wpm > 170 {
                return rushedPaceSentence(wpm: Int(wpm.rounded()), persona: persona)
            }
            if wpm < 95 {
                return slowPaceSentence(wpm: Int(wpm.rounded()), persona: persona)
            }
        }

        // 5) Short rep — honest about brevity without scolding.
        if input.duration < 20 {
            return shortRepSentence(persona: persona)
        }

        // 6) Transcript-anchored opener — quotes the user's own words
        // rather than falling back to generic copy. Only fires when the
        // transcript has a quotable opening phrase.
        if let opener = extractOpener(from: input.transcript) {
            return openerAnchoredSentence(opener: opener, persona: persona)
        }

        // 7) Fallback — neutral steady-delivery note.
        return steadyDeliverySentence(persona: persona)
    }

    // MARK: - Per-branch sentences (voice-shaped)

    nonisolated static func fillerWinSentence(fillerCount: Int, persona: CoachPersona) -> String {
        switch persona.voice {
        case .authoritative:
            return fillerCount == 0
                ? "Zero fillers — that's authority on tape."
                : "\(fillerCount) filler\(fillerCount == 1 ? "" : "s") — well below your usual rate."
        case .warm:
            return fillerCount == 0
                ? "No fillers came through — your composure was holding."
                : "Only \(fillerCount) — feels like a settled rep."
        case .concise:
            return fillerCount == 0 ? "Zero fillers. Clean." : "\(fillerCount) fillers. Tight."
        case .persuasive:
            return fillerCount == 0
                ? "Zero fillers — the case landed clean."
                : "\(fillerCount) fillers — well inside your usual range."
        case .executive:
            return fillerCount == 0
                ? "Zero fillers. Boardroom-clean delivery."
                : "\(fillerCount) fillers — under your baseline."
        case .storytelling:
            return fillerCount == 0
                ? "Not a single filler — the through-line held all the way."
                : "Only \(fillerCount) filler\(fillerCount == 1 ? "" : "s") — the arc carried itself."
        case .none:
            return fillerCount == 0 ? "Zero fillers — clean run." : "\(fillerCount) fillers — under your usual."
        }
    }

    nonisolated static func fillerLossSentence(fillerCount: Int, persona: CoachPersona) -> String {
        switch persona.voice {
        case .authoritative:
            return "\(fillerCount) fillers — above your baseline. Slow the open next time."
        case .warm:
            return "\(fillerCount) fillers landed — common under pressure. Breath between sentences resets it."
        case .concise:
            return "\(fillerCount) fillers. Slow the open."
        case .persuasive:
            return "\(fillerCount) fillers — the evidence is clear, slower pacing closes it."
        case .executive:
            return "\(fillerCount) fillers. Recommend a slower opening next rep."
        case .storytelling:
            return "\(fillerCount) fillers crowded the arc. Hold the first beat longer next time."
        case .none:
            return "\(fillerCount) fillers — slow the opening to settle it."
        }
    }

    nonisolated static func strongScoreSentence(score: Int, persona: CoachPersona) -> String {
        switch persona.voice {
        case .authoritative:
            return "Verdict: that was a \(score). Composure carried the rep."
        case .warm:
            return "That rep scored \(score) — and it sounded like it felt right too."
        case .concise:
            return "\(score). Repeat."
        case .persuasive:
            return "Scored \(score). The structure earned it — clear premise, clean close."
        case .executive:
            return "Top-line: \(score) of 10. Recommend repeating this shape."
        case .storytelling:
            return "An \(score) — the arc had a beginning, a middle, and a landing."
        case .none:
            return "Scored \(score). The fundamentals held."
        }
    }

    nonisolated static func weakScoreSentence(score: Int, persona: CoachPersona) -> String {
        switch persona.voice {
        case .authoritative:
            return "Scored \(score) — the volume was there, the shape wasn't yet."
        case .warm:
            return "A \(score) this time — and that's okay. The next rep is the real test."
        case .concise:
            return "\(score). Tighten the open."
        case .persuasive:
            return "Scored \(score). The premise needs a tighter setup before the evidence lands."
        case .executive:
            return "Top-line: \(score) of 10. Recommend a structural reset next rep."
        case .storytelling:
            return "A \(score) — the moments were there but the arc didn't close."
        case .none:
            return "Scored \(score). Reset the structure next rep."
        }
    }

    nonisolated static func rushedPaceSentence(wpm: Int, persona: CoachPersona) -> String {
        switch persona.voice {
        case .authoritative:
            return "Pace ran \(wpm) WPM — slower lands harder."
        case .warm:
            return "\(wpm) WPM is quick — give yourself a beat between points."
        case .concise:
            return "\(wpm) WPM. Pull back."
        case .persuasive:
            return "Pace at \(wpm) WPM — the evidence rushed past before it landed."
        case .executive:
            return "Pace \(wpm) WPM. Recommend dropping 20 WPM next rep."
        case .storytelling:
            return "\(wpm) WPM rushed the story — let the moments breathe."
        case .none:
            return "Pace ran \(wpm) WPM. Slow the connective material."
        }
    }

    nonisolated static func slowPaceSentence(wpm: Int, persona: CoachPersona) -> String {
        switch persona.voice {
        case .authoritative:
            return "Pace \(wpm) WPM — push the engine a little faster."
        case .warm:
            return "\(wpm) WPM came in measured — a touch more momentum next time."
        case .concise:
            return "\(wpm) WPM. Lift it."
        case .persuasive:
            return "\(wpm) WPM slowed the case — confident pacing closes it harder."
        case .executive:
            return "Pace \(wpm) WPM. Recommend +20 WPM for conversational lift."
        case .storytelling:
            return "\(wpm) WPM dragged the arc — push the through-line forward."
        case .none:
            return "Pace \(wpm) WPM. Lean a touch faster on the connective material."
        }
    }

    nonisolated static func shortRepSentence(persona: CoachPersona) -> String {
        switch persona.voice {
        case .authoritative:
            return "Short rep — the shape was there. Build it longer next time."
        case .warm:
            return "A quick one — keep the seed, give it more room next rep."
        case .concise:
            return "Short. Extend it."
        case .persuasive:
            return "Brief rep — the premise needs more evidence to land."
        case .executive:
            return "Brief delivery. Recommend extending the answer next rep."
        case .storytelling:
            return "A short scene — the next rep is where the arc unfolds."
        case .none:
            return "Short rep — extend the answer next time."
        }
    }

    nonisolated static func steadyDeliverySentence(persona: CoachPersona) -> String {
        switch persona.voice {
        case .authoritative:
            return "Steady delivery. The fundamentals held."
        case .warm:
            return "A steady rep — the foundation is doing its work."
        case .concise:
            return "Steady. Hold the line."
        case .persuasive:
            return "Steady case — the premise held its weight."
        case .executive:
            return "Steady. Carry the shape forward."
        case .storytelling:
            return "A steady chapter — the through-line carried."
        case .none:
            return "Steady delivery. The fundamentals held."
        }
    }

    // MARK: - Momentum sentences (cross-session trajectory)

    nonisolated static func personalBestSentence(score: Int, persona: CoachPersona) -> String {
        switch persona.voice {
        case .authoritative:
            return "New personal best — \(score) of 10. That's the benchmark now."
        case .warm:
            return "That \(score) is a new best for you — real evidence of the work."
        case .concise:
            return "Personal best. \(score). New floor."
        case .persuasive:
            return "Highest score yet — \(score). The case is getting sharper."
        case .executive:
            return "New personal best: \(score) of 10. This is your new standard."
        case .storytelling:
            return "A \(score) — your highest chapter yet. The arc is climbing."
        case .none:
            return "New personal best — \(score) of 10."
        }
    }

    nonisolated static func consecutiveCleanSentence(count: Int, persona: CoachPersona) -> String {
        switch persona.voice {
        case .authoritative:
            return "That's \(count) clean runs in a row. This is becoming your baseline."
        case .warm:
            return "\(count) clean reps running — something has genuinely shifted."
        case .concise:
            return "\(count) clean. Pattern, not accident."
        case .persuasive:
            return "\(count) consecutive clean reps — the evidence is compounding."
        case .executive:
            return "\(count) consecutive clean deliveries. This is the operating standard now."
        case .storytelling:
            return "\(count) clean runs in sequence — a through-line is forming."
        case .none:
            return "\(count) clean reps in a row — this is becoming consistent."
        }
    }

    nonisolated static func fillerTrendImprovingSentence(persona: CoachPersona) -> String {
        switch persona.voice {
        case .authoritative:
            return "Filler rate is genuinely declining — multiple sessions of evidence."
        case .warm:
            return "Your filler rate has been dropping across recent sessions — the work is landing."
        case .concise:
            return "Filler trend: down. Sustained."
        case .persuasive:
            return "Filler rate declining across sessions — the discipline is compounding."
        case .executive:
            return "Filler rate trending down over recent deliveries. Recommend maintaining pace."
        case .storytelling:
            return "The filler pattern is fading — your voice is finding its clean rhythm."
        case .none:
            return "Filler rate declining across recent sessions."
        }
    }

    /// IM tone-drill Adaptation read, voice-shaped. Reports the climb (or
    /// drop) in the committed tone's hit rate for the just-finished
    /// scenario. Only called for `.recovering` / `.slipping` — a recovering
    /// read reinforces the drill, a slipping read points at a different
    /// opening. Percentages come straight off the progress windows; no
    /// reframe, no shame — a slip is data plus a constructive next move.
    nonisolated static func imToneTrajectorySentence(
        progress: IMToneDrillProgress,
        scenario: String,
        tone: String,
        persona: CoachPersona
    ) -> String {
        let lower = tone.lowercased()
        let earlierPct = Int((progress.earlierRate * 100).rounded())
        let recentPct = Int((progress.recentRate * 100).rounded())
        let recovering = progress.direction == .recovering
        switch persona.voice {
        case .authoritative:
            return recovering
                ? "Your \(lower) tone in \(scenario) is landing more — \(earlierPct)% to \(recentPct)%. Hold that line."
                : "Your \(lower) tone in \(scenario) slipped — \(earlierPct)% to \(recentPct)%. Change how you open it."
        case .warm:
            return recovering
                ? "Your \(lower) tone in \(scenario) is finding its footing — \(earlierPct)% to \(recentPct)%. That's real progress."
                : "Your \(lower) tone in \(scenario) dipped — \(earlierPct)% to \(recentPct)%. A softer opening can reset it."
        case .concise:
            return recovering
                ? "\(scenario): \(lower) tone \(earlierPct)% to \(recentPct)%. Climbing. Hold it."
                : "\(scenario): \(lower) tone \(earlierPct)% to \(recentPct)%. Slipping. Reopen it."
        case .persuasive:
            return recovering
                ? "Your \(lower) tone in \(scenario) is recovering — \(earlierPct)% to \(recentPct)%. The drill is working; one more locks it."
                : "Your \(lower) tone in \(scenario) dropped — \(earlierPct)% to \(recentPct)%. Same scenario, a different opening closes it."
        case .executive:
            return recovering
                ? "\(scenario) \(lower) tone: \(earlierPct)% to \(recentPct)%. Recovering. Recommend one more rep."
                : "\(scenario) \(lower) tone: \(earlierPct)% to \(recentPct)%. Slipping. Recommend changing the open."
        case .storytelling:
            return recovering
                ? "Your \(lower) tone in \(scenario) is climbing — \(earlierPct)% to \(recentPct)%. The arc is turning."
                : "Your \(lower) tone in \(scenario) lost the thread — \(earlierPct)% to \(recentPct)%. Reopen the scene."
        case .none:
            return recovering
                ? "Your \(lower) tone in \(scenario) is recovering — \(earlierPct)% to \(recentPct)%. Hold it."
                : "Your \(lower) tone in \(scenario) slipped — \(earlierPct)% to \(recentPct)%. Change how you open it."
        }
    }

    /// IM tone-drill SOLVED sentence, voice-shaped. Reports the climb in the
    /// committed tone's hit rate for the just-resolved scenario and points
    /// the user at the next target — the terminal complement to
    /// `imToneTrajectorySentence`'s in-flight read. Percentages come straight
    /// off the resolved windows. Names the outcome ("solved", "turned
    /// around") as an observation of the user's own hit rate; never claims a
    /// drill caused it, and never re-prescribes the beaten scenario.
    nonisolated static func imToneResolvedSentence(
        resolved: IMToneDrillResolved,
        scenario: String,
        tone: String,
        persona: CoachPersona
    ) -> String {
        let lower = tone.lowercased()
        let earlierPct = Int((resolved.earlierRate * 100).rounded())
        let recentPct = Int((resolved.recentRate * 100).rounded())
        switch persona.voice {
        case .authoritative:
            return "Your \(lower) tone in \(scenario) is solved — \(earlierPct)% to \(recentPct)%, holding now. Target met; next one's open."
        case .warm:
            return "You've turned your \(lower) tone in \(scenario) around — \(earlierPct)% to \(recentPct)%, and it's holding. That one's yours now."
        case .concise:
            return "\(scenario): \(lower) tone solved. \(earlierPct)% to \(recentPct)%, held. Next target."
        case .persuasive:
            return "Your \(lower) tone in \(scenario) is solved — \(earlierPct)% to \(recentPct)%, holding. The gap's closed; the next one's open."
        case .executive:
            return "\(scenario) \(lower) tone: \(earlierPct)% to \(recentPct)%. Solved and holding. Recommend moving to the next target."
        case .storytelling:
            return "Your \(lower) tone in \(scenario) found its footing — \(earlierPct)% to \(recentPct)%, holding now. That arc closed; the next opens."
        case .none:
            return "Your \(lower) tone in \(scenario) is solved — \(earlierPct)% to \(recentPct)%, holding now. Next target's open."
        }
    }

    // MARK: - Suffix sentences (BigMoment, weekly rhythm, transcript opener)

    /// BigMoment suffix replaces the standard closing when a big moment
    /// is within 14 days. Keeps the user anchored to their upcoming event.
    nonisolated static func bigMomentSuffix(
        daysUntil: Int,
        category: BigMomentCategory,
        persona: CoachPersona
    ) -> String? {
        guard daysUntil <= 14, daysUntil >= 0 else { return nil }
        let event = category.displayName
        switch persona.voice {
        case .authoritative:
            return daysUntil == 0
                ? "\(event.capitalized) is today — you're ready."
                : "\(event.capitalized) in \(daysUntil) day\(daysUntil == 1 ? "" : "s") — hold that pace."
        case .warm:
            return daysUntil == 0
                ? "Your \(event) is today — carry this with you."
                : "Your \(event) is \(daysUntil) day\(daysUntil == 1 ? "" : "s") out — carry this."
        case .concise:
            return daysUntil == 0
                ? "\(event.capitalized) today. Ready."
                : "\(daysUntil) day\(daysUntil == 1 ? "" : "s"). Hold it."
        case .persuasive:
            return daysUntil == 0
                ? "\(event.capitalized) is today — the preparation has landed."
                : "\(event.capitalized) in \(daysUntil) day\(daysUntil == 1 ? "" : "s") — the reps are banking."
        case .executive:
            return daysUntil == 0
                ? "\(event.capitalized) today. Prepared."
                : "\(event.capitalized) in \(daysUntil) day\(daysUntil == 1 ? "" : "s"). Maintain."
        case .storytelling:
            return daysUntil == 0
                ? "The \(event) is today — your arc is ready."
                : "The \(event) is \(daysUntil) day\(daysUntil == 1 ? "" : "s") away — the rehearsal is doing its work."
        case .none:
            return daysUntil == 0
                ? "\(event.capitalized) is today."
                : "\(event.capitalized) in \(daysUntil) day\(daysUntil == 1 ? "" : "s")."
        }
    }

    /// Weekly rhythm suffix fires at milestone rep counts (3, 5, 7) on
    /// positive or neutral branches. Absent when BigMoment suffix fires.
    nonisolated static func weeklyRhythmSuffix(
        weeklyRepCount: Int,
        persona: CoachPersona
    ) -> String? {
        guard [3, 5, 7].contains(weeklyRepCount) else { return nil }
        switch persona.voice {
        case .authoritative:
            return weeklyRepCount == 3
                ? "Third rep this week. The rhythm is set."
                : "Rep \(weeklyRepCount) this week. The rhythm is doing its work."
        case .warm:
            return weeklyRepCount == 3
                ? "Third one this week — the habit is settling in."
                : "\(weeklyRepCount) reps this week — the rhythm is real."
        case .concise:
            return "\(weeklyRepCount) this week. Rhythm."
        case .persuasive:
            return "Rep \(weeklyRepCount) this week — consistency is the strongest argument."
        case .executive:
            return "\(weeklyRepCount) reps this week. Cadence is strong."
        case .storytelling:
            return "\(weeklyRepCount) chapters this week — the story keeps building."
        case .none:
            return "\(weeklyRepCount) reps this week."
        }
    }

    /// Extract the user's opening phrase from their transcript. Returns
    /// the first sentence (up to 60 chars). Nil when transcript is empty
    /// or the opener is too short to quote meaningfully.
    nonisolated static func extractOpener(from transcript: String) -> String? {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // Find first sentence boundary (. ? — or 15 words, whichever is shorter)
        let sentenceEnders: [Character] = [".", "?"]
        var endIndex = trimmed.endIndex
        for (i, char) in trimmed.enumerated() {
            if sentenceEnders.contains(char) {
                endIndex = trimmed.index(trimmed.startIndex, offsetBy: i + 1)
                break
            }
        }

        var opener = String(trimmed[trimmed.startIndex..<endIndex])
        // Cap at 15 words
        let words = opener.split(separator: " ")
        if words.count > 15 {
            opener = words.prefix(15).joined(separator: " ")
        }
        // Cap at 60 chars
        if opener.count > 60 {
            opener = String(opener.prefix(57)) + "..."
        }
        // Too short to quote meaningfully
        guard opener.count >= 10 else { return nil }
        return opener
    }

    /// Transcript-anchored opener sentence. Fires only on the
    /// steady-delivery fallback, replacing generic copy with a quote.
    nonisolated static func openerAnchoredSentence(
        opener: String,
        persona: CoachPersona
    ) -> String {
        let quoted = "'\(opener.trimmingCharacters(in: CharacterSet(charactersIn: ".'\"")))"
        switch persona.voice {
        case .authoritative:
            return "Your opener — \(quoted)' — landed clean."
        case .warm:
            return "You opened with \(quoted)' — it set the right tone."
        case .concise:
            return "Opener: \(quoted).' Landed."
        case .persuasive:
            return "The opener — \(quoted)' — set the premise well."
        case .executive:
            return "Opening with \(quoted)' — effective framing."
        case .storytelling:
            return "You opened with \(quoted)' — the first line drew the listener in."
        case .none:
            return "Your opener — \(quoted)' — landed well."
        }
    }

    // MARK: - Brand-voice contract

    /// Returns true when the candidate note text honors the brand voice
    /// contract: no exclamation marks, no chirpy filler, no leading
    /// "Great job" / "Let's", and bounded length.
    nonisolated static func passesBrandVoiceContract(_ text: String) -> Bool {
        let lower = text.lowercased()
        if text.contains("!") { return false }
        if lower.contains("let's") || lower.contains("lets ") { return false }
        if lower.contains("awesome") { return false }
        if lower.contains("great job") { return false }
        if text.count > 220 { return false }
        if text.count < 12 { return false }
        return true
    }

    nonisolated static func ensureNoExclamations(in text: String) -> String {
        text.replacingOccurrences(of: "!", with: ".")
    }

    /// Local content-word stop set for the presence gate. Same established
    /// local-set pattern used elsewhere; kept private to this type. Tokens
    /// in this set don't count as "engaging the transcript" so a note that
    /// only shares filler words like "the"/"with" still falls back.
    private nonisolated static let engagementStopWords: Set<String> = [
        "the", "and", "for", "are", "but", "not", "you", "your", "with",
        "this", "that", "they", "them", "from", "have", "what", "when",
        "were", "will", "would", "should", "could", "about", "there",
        "their", "then", "than", "into", "more", "some", "such", "only",
        "very", "just", "most", "over", "also", "been", "being", "which",
        "while", "these", "those", "here", "make", "made", "much", "many",
        "like", "well", "even", "ever", "because", "really", "it's"
    ]

    /// Presence gate for the AI note (mirrors
    /// `GrammarFeedbackService`'s excerpt-must-appear substring check at
    /// :358-360). Returns true when the note genuinely engages the rep's
    /// transcript, so a stat-restate that ignores what the user said gets
    /// rejected and the deterministic note is shown instead.
    ///
    /// True if EITHER:
    /// - the note shares at least one content word (>= 4 chars, non-stop)
    ///   with the transcript, OR
    /// - the note contains a >= 12-char verbatim substring of the transcript
    ///   (case-insensitive).
    /// Empty transcript -> passes (nothing to quote; never blocks IM/silent
    /// reps).
    nonisolated static func engagesTranscript(_ note: String, input: PostRepCoachNoteInput) -> Bool {
        let transcript = input.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcript.isEmpty else { return true }

        let lowerTranscript = transcript.lowercased()
        let lowerNote = note.lowercased()

        // 1) Shared content word.
        let transcriptWords = Set(
            lowerTranscript
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 4 && !engagementStopWords.contains($0) }
        )
        let noteWords = lowerNote
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count >= 4 && !engagementStopWords.contains($0) }
        if noteWords.contains(where: { transcriptWords.contains($0) }) {
            return true
        }

        // 2) >= 12-char verbatim slice of the transcript appears in the note.
        // Slide a 12-char window across the transcript; cheap and bounded
        // (transcript is capped well under 1k chars on this path).
        let window = 12
        let chars = Array(lowerTranscript)
        if chars.count >= window {
            for start in 0...(chars.count - window) {
                let slice = String(chars[start..<(start + window)])
                if lowerNote.contains(slice) {
                    return true
                }
            }
        }
        return false
    }

    nonisolated static func collapseWhitespace(in text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = ""
        var lastWasSpace = false
        for char in trimmed {
            if char.isWhitespace {
                if !lastWasSpace { result.append(" ") }
                lastWasSpace = true
            } else {
                result.append(char)
                lastWasSpace = false
            }
        }
        return result
    }

    nonisolated static func truncate(_ text: String, max maxLen: Int) -> String {
        guard text.count > maxLen else { return text }
        let cutoffIndex = text.index(text.startIndex, offsetBy: maxLen - 1)
        return String(text[..<cutoffIndex]) + "…"
    }

    // MARK: - AI prompt + parsing

    nonisolated static func userPrompt(from input: PostRepCoachNoteInput) -> String {
        var lines: [String] = []
        if let voice = input.voice {
            lines.append("User's voice goal: \(voice.title) (\(voice.coachingDescription))")
        }
        if let intent = input.intentLabel, !intent.isEmpty {
            lines.append("User declared focus: \(intent)")
        }
        lines.append("Mode: \(input.mode.displayLabel)")
        if let score = input.score {
            lines.append("Score: \(score)/10")
        }
        lines.append("Filler count: \(input.fillerCount)")
        lines.append("Duration: \(Int(input.duration.rounded()))s")
        lines.append("Word count: \(input.wordCount)")
        if let baselineRate = input.baselineFillerRate {
            lines.append(String(format: "Baseline filler rate: %.1f per minute", baselineRate))
        }
        if let baselinePace = input.baselinePaceWPM {
            lines.append(String(format: "Baseline pace: %.0f WPM", baselinePace))
        }
        if let moment = input.bigMoment, let days = input.bigMomentDaysUntil {
            lines.append("Upcoming big moment: \(moment.category.rawValue), \(days) day(s) out")
        }
        // What they actually said. The transcript is the spine — quoting
        // a real phrase is what separates "coach who heard you" from
        // "dashboard reading numbers." Capped so the prompt stays bounded.
        let trimmedTranscript = Self.collapseWhitespace(in: input.transcript)
        // The question the rep answered — lets the model judge "did you
        // answer it / where did the point land" instead of only quoting a
        // phrase. Omitted entirely when unknown (no placeholder injected).
        let trimmedPrompt = Self.collapseWhitespace(in: input.prompt)
        if !trimmedPrompt.isEmpty {
            lines.append("")
            lines.append("THE QUESTION ASKED: \(Self.truncate(trimmedPrompt, max: 200))")
        }
        if !trimmedTranscript.isEmpty {
            lines.append("")
            lines.append("THIS REP — TRANSCRIPT (quote a specific phrase, and say whether it answered THE QUESTION ASKED and where the main point landed):")
            lines.append(Self.truncate(trimmedTranscript, max: 900))
        }
        if !input.recentSessionSummaries.isEmpty {
            lines.append("")
            lines.append("RECENT REPS (reference for continuity, never invent):")
            for summary in input.recentSessionSummaries.prefix(3) {
                lines.append("- \(summary)")
            }
        }
        if !input.recentProofQuotes.isEmpty {
            lines.append("")
            lines.append("BANKED PROOFS (past moments worth referencing):")
            for quote in input.recentProofQuotes.prefix(2) {
                lines.append("- \"\(Self.truncate(quote, max: 140))\"")
            }
        }

        // Momentum signals — lets the AI reference trajectory, not just
        // this rep's numbers. Only appended when meaningful signals exist.
        var momentumLines: [String] = []
        if input.consecutiveCleanReps >= 2, input.totalSessionCount >= 5 {
            momentumLines.append("- \(input.consecutiveCleanReps) consecutive clean reps (fillers at or below half baseline).")
        }
        if input.isPersonalBest, input.totalSessionCount >= 5 {
            if let score = input.score {
                momentumLines.append("- This session was a personal best (score \(score)).")
            }
        }
        if let fillerTrend = input.fillerTrendDirection, fillerTrend == .improving {
            momentumLines.append("- Filler rate improving over last 6 sessions.")
        }
        if let scoreTrend = input.scoreTrendDirection, scoreTrend == .improving {
            momentumLines.append("- Scores improving over last 6 sessions.")
        }
        if input.weeklyRepCount >= 2 {
            momentumLines.append("- Reps this week: \(input.weeklyRepCount).")
        }
        if let progress = input.imToneDrillProgress,
           progress.direction != .stalled,
           let scenario = input.imToneDrillScenarioTitle,
           let tone = input.imToneDrillToneTitle {
            let earlierPct = Int((progress.earlierRate * 100).rounded())
            let recentPct = Int((progress.recentRate * 100).rounded())
            let word = progress.direction == .recovering ? "recovering" : "slipping"
            momentumLines.append("- \(tone) tone in \(scenario): tone-match \(earlierPct)% to \(recentPct)% across recent reps (\(word)).")
        }
        if let resolved = input.imToneDrillResolved,
           let scenario = input.imToneDrillResolvedScenarioTitle,
           let tone = input.imToneDrillResolvedToneTitle {
            let earlierPct = Int((resolved.earlierRate * 100).rounded())
            let recentPct = Int((resolved.recentRate * 100).rounded())
            momentumLines.append("- \(tone) tone in \(scenario): SOLVED this rep — tone-match \(earlierPct)% to \(recentPct)%, now holding above the bar. Name this win once and point to the next target; never re-prescribe it, restate it as still-open, or claim a drill caused it.")
        }
        if !momentumLines.isEmpty {
            lines.append("")
            lines.append("MOMENTUM (cross-session trajectory — reference when it adds coaching value):")
            lines.append(contentsOf: momentumLines)
        }

        return lines.joined(separator: "\n")
    }

    private func systemPrompt(persona: CoachPersona) -> String {
        return """
        You are a senior £130/hr speaking coach writing a 2-sentence note \
        to your client immediately after their practice rep. Voice register: \
        \(persona.signatureTone)

        What makes a good note (in priority order):
        1. Reference a SPECIFIC moment from THEIR TRANSCRIPT below — a \
        phrase they used, a structural choice, an opener, an ending. \
        Quote it in their words when possible.
        1b. If a QUESTION ASKED is given, your note must reflect whether the \
        rep actually answered it and where the main point landed (lead vs \
        buried) — grounded in their words, never a generic relevance claim.
        2. Connect this rep to prior sessions or banked proofs when that \
        adds genuine continuity — "this is the second time you've leaned \
        on…", "the pause game from last week showed up again here." \
        Never invent past behavior.
        3. Stats (score, filler count, duration) are CONTEXT, not the \
        point. If you can write the note without quoting a stat, do. \
        Stat-restating reads as a dashboard, not a coach.

        Hard rules:
        - Exactly 2 sentences. Total length ≤ 200 characters.
        - No exclamation marks. No chirpy filler ("Awesome", "Great job", \
        "Let's"). No emoji.
        - Never invent stats, quotes, or past behavior. Only reference what \
        the input actually contains.
        - Never punish-shame. If a number dropped, name it factually and \
        anchor a small next move.
        - Output STRICT JSON: {"note": "..."} — nothing else.
        """
    }

    private func requestBody(for provider: AIProvider, input: PostRepCoachNoteInput) -> [String: Any] {
        let persona = CoachPersona.persona(for: input.voice)
        let system = systemPrompt(persona: persona)
        let user = Self.userPrompt(from: input)
        switch provider {
        case .openAI, .deepSeek:
            return [
                "model": provider.model,
                "temperature": 0.5,
                "response_format": ["type": "json_object"],
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": user]
                ]
            ]
        case .gemini, .agentPlatform:            return [
                "systemInstruction": ["parts": [["text": system]]],
                "contents": [["parts": [["text": user]]]],
                "generationConfig": [
                    "temperature": 0.5,
                    "responseMimeType": "application/json"
                ]
            ]
        case .none:
            return [:]
        }
    }

    private func parseNoteText(from data: Data, provider: AIProvider) -> String? {
        let raw: String?
        switch provider {
        case .openAI, .deepSeek:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = object["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return nil }
            raw = content
        case .gemini, .agentPlatform:            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = object["candidates"] as? [[String: Any]],
                let first = candidates.first,
                let content = first["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]]
            else { return nil }
            raw = parts.compactMap { $0["text"] as? String }.joined(separator: " ")
        case .none:
            return nil
        }

        guard let raw, let dict = decodeJSON(from: raw),
              let note = dict["note"] as? String else {
            return nil
        }
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func decodeJSON(from raw: String) -> [String: Any]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        let unfenced = trimmed
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = unfenced.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        return nil
    }

    // MARK: - Provider plumbing

    @MainActor
    private func currentProvider() -> AIProvider? {
        AISettingsManager.shared.activeProvider
    }

    @MainActor
    private func activeLocaleSupportsAI() -> Bool {
        LocaleSettingsManager.shared.current.aiSupported
    }

    @MainActor
    private func rateLimiterAllows() -> Bool {
        AIRateLimiter.shared.consumeIfAllowed(kind: .postRepCoachNote)
    }

    private func apiKey(for provider: AIProvider) -> String? {
        guard let keyName = provider.environmentKey else { return nil }
        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")
    }
}
