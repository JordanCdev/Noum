import Foundation

// MARK: - AI Insights Service
//
// Generates *narrative* coaching insight from a window of sessions. This is
// the layer that turns "here are your numbers" into "here's what's actually
// changing in how you speak." The output is structured so the UI can render
// a card without playing wordsmith with raw model output.
//
// Reuses the same provider plumbing as the other AI services (Gemini /
// OpenAI / DeepSeek) via `AISettingsManager.activeProvider`. Falls back to a
// rich template-derived insight when no provider is configured — the card
// stays useful offline; the AI version is just sharper.
//
// Caching: results are keyed by a hash of the input shape (last-session ID
// + session count + week bucket). The same hash on the same week means the
// same call won't re-spend AI quota.

// MARK: - Public types

/// Insight kind — drives icon + colour on the card.
enum AIInsightKind: String, Codable {
    case weeklyNarrative   // "Your week" digest
    case sessionDebrief    // post-session "what just changed"
    case patternBreak      // a habit just shifted (good or bad)

    var symbolName: String {
        switch self {
        case .weeklyNarrative: return "calendar.badge.clock"
        case .sessionDebrief:  return "quote.bubble.fill"
        case .patternBreak:    return "wand.and.stars"
        }
    }
}

/// A single piece of structured insight. The headline is the verdict, the
/// body is one paragraph (≤ 80 words), the evidence is the concrete data
/// the model hung the verdict on, and the action is the next-rep nudge.
struct AIInsight: Codable, Equatable {
    let kind: AIInsightKind
    let headline: String          // ≤ 8 words, sentence case
    let body: String              // ≤ 80 words, plain text
    let evidence: [String]        // 1–3 short bullets, e.g. "12 fillers down to 4"
    let action: String?           // optional one-line next-step nudge
    let isAIBacked: Bool          // false ⇒ template fallback was used
    let generatedAt: Date

    static let placeholder = AIInsight(
        kind: .weeklyNarrative,
        headline: "Your week starts here",
        body: "Run a few sessions to give the coach something to say.",
        evidence: [],
        action: nil,
        isAIBacked: false,
        generatedAt: Date()
    )
}

// MARK: - Inputs

/// Self-contained snapshot of the data the AI needs to generate one insight.
/// Built once on the call site so the service stays pure (no fetching
/// singletons inside the actor — easier to test).
struct AIInsightInput {
    let kind: AIInsightKind
    let sessions: [PracticeSession]
    let baseline: CommunicationBaseline
    let rating: SpeakingRating
    let weeklyDelta: Int
    let weeklyReps: Int
    let topFillerWord: String?
    let goalParaphrase: String?
    let currentStreak: Int
    /// Normalized 0–1 distance from the user's coaching goal (from
    /// CommunicationBaseline.distanceFromGoal). nil if no goal is set.
    let goalDistance: Double?
    /// Voice the user is training. Drives the per-voice register added
    /// to the system prompt — same authoritative/warm/concise/persuasive/
    /// executive/storytelling switch the live coach uses. nil = cold
    /// start; caller supplies it from CoachingProfileStore.profile.
    var voice: SpeakingStyleGoal? = nil
    /// Verbatim quotes from the user's banked Proof Moments — past reps
    /// where the coach caught something worth remembering. Lets the AI
    /// reference real growth ("three weeks ago you said X") instead of
    /// generic week-over-week framing. Empty for cold-start users.
    var recentProofQuotes: [String] = []
    /// Optional explicit question override for the sessionDebrief read. When
    /// nil, the service reads `focusSessions.first?.prompt` (single source of
    /// truth — the same stored prompt the deterministic Relevance rating and
    /// the post-rep note use). Exists so tests can drive the question without
    /// constructing a full PracticeSession.
    var promptOverride: String? = nil
    /// Sessions to focus on inside the prompt — usually the last 3–5.
    /// Trimmed by the caller so the prompt stays small.
    var focusSessions: [PracticeSession] {
        Array(sessions.prefix(5))
    }
}

// MARK: - Service

actor AIInsightsService {
    static let shared = AIInsightsService()

    private init() {}

    private var cache: [String: AIInsight] = [:]
    /// 6h max age — long enough that the same week reuses, short enough
    /// that a fresh week always re-runs.
    private let maxCacheAge: TimeInterval = 6 * 60 * 60

    // MARK: - Public API

    /// Generate (or return cached) insight for the given input. Always
    /// returns *something* — the template fallback stands in for the AI
    /// when no provider is configured, when network fails, or when the
    /// model returns garbage.
    func insight(for input: AIInsightInput) async -> AIInsight {
        let cacheKey = cacheKey(for: input)
        if let cached = cache[cacheKey], !isStale(cached) {
            return cached
        }

        let templated = templatedFallback(for: input)

        // M13: AI insight surfaces are English-only in this milestone.
        // Non-English practice sessions get the deterministic template
        // fallback so the card stays useful but never produces English
        // coaching text on a Spanish or French session.
        guard await activeLocaleSupportsAI() else {
            cache[cacheKey] = templated
            return templated
        }

        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider)
        else {
            cache[cacheKey] = templated
            return templated
        }

        do {
            let prompt = Self.userPrompt(from: input)
            let body = requestBody(for: provider, prompt: prompt, system: Self.systemPrompt(for: input.kind, voice: input.voice))
            // Gemini insights run on the stronger 2.5-pro model. Inputs
            // are short and the JSON shape is fixed, so the latency hit
            // (well inside the 14s timeout) buys sharper diagnosis on
            // the surface that already drives the weekly digest card.
            let geminiInsightsModel = "gemini-2.5-pro"
            var request = URLRequest(url: insightsEndpoint(
                for: provider,
                geminiModelOverride: geminiInsightsModel
            ) ?? endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 14
            switch provider {
            case .openAI, .deepSeek:
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            case .gemini, .agentPlatform:                request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            case .none:
                cache[cacheKey] = templated
                return templated
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let parsed = parse(data: data, provider: provider, kind: input.kind)
            else {
                cache[cacheKey] = templated
                return templated
            }

            cache[cacheKey] = parsed
            return parsed
        } catch {
            cache[cacheKey] = templated
            return templated
        }
    }

    /// Drop a cached insight so the next call regenerates. Used by
    /// pull-to-refresh.
    func invalidate(for input: AIInsightInput) {
        cache.removeValue(forKey: cacheKey(for: input))
    }

    // MARK: - Provider plumbing

    @MainActor
    private func currentProvider() -> AIProvider? {
        AISettingsManager.shared.activeProvider
    }

    /// True when the active practice locale has AI surfaces enabled.
    @MainActor
    private func activeLocaleSupportsAI() -> Bool {
        LocaleSettingsManager.shared.current.aiSupported
    }

    private func apiKey(for provider: AIProvider) -> String? {
        guard let keyName = provider.environmentKey else { return nil }
        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")
    }

    // MARK: - Prompt construction

    /// Exposed `static` + `internal` so the test suite can assert the
    /// per-voice register clause without standing up the actor.
    static func systemPrompt(for kind: AIInsightKind, voice: SpeakingStyleGoal?) -> String {
        // Voice rules pulled directly from .claude/skills/noum-design:
        // direct, second-person, imperative-leaning, never chirpy, no emoji,
        // no exclamation marks. Always tied to concrete numbers.
        let voiceRegister = registerClause(for: voice)
        let common = """
        You are a senior speaking coach. Voice: direct, warm, and specific. \
        You speak in second person, address the user as "you", and never \
        use chirpy filler ("Awesome!", "Great job!"). No emoji. No \
        exclamation marks. Sentences land in 18 words or fewer. Reference \
        the user's actual numbers — never invent statistics. If a number \
        isn't given, don't claim a number.
        \(voiceRegister)
        Output strict JSON with keys: headline (≤ 8 words), body \
        (≤ 80 words, 1 paragraph), evidence (array of 1-3 short strings, \
        each ≤ 60 chars, citing real numbers from the input), action \
        (single short imperative sentence, ≤ 20 words, naming a concrete \
        next-rep goal — or null if no clear next rep).
        """
        switch kind {
        case .weeklyNarrative:
            return common + "\nThe goal is a one-paragraph narrative summary of the user's last 7 days of speaking practice. If a user goal is provided, open with one sentence connecting the week's trend to that goal."
        case .sessionDebrief:
            return common + "\nThe goal is a coaching read of one specific session. PRIORITY: when the transcript is provided, your headline OR body MUST reference a SPECIFIC phrase or moment from the user's actual words — quote them, paraphrase them, name what they did structurally. Stats are context, not the read. When THE QUESTION ASKED is provided, your read must address whether the answer engaged it and where the main point landed — grounded in their words, association not verdict. If a user goal is provided, connect the session to it in plain language. Banked proofs (if listed) let you say 'this is the second time…' or 'last week you also…' — only when genuinely true. Never invent past behavior."
        case .patternBreak:
            return common + "\nA pattern just shifted. Surface what changed and whether it was good or bad. If a user goal is provided, frame the shift in terms of that goal."
        }
    }

    /// Per-voice register line. Matches the authoritative=verdict, warm=mentor,
    /// concise=clipped, persuasive=premise→evidence, executive=chief-of-staff,
    /// storytelling=arcs pattern from `CoachContextBuilder.systemPrompt`. The
    /// model uses this to shape the headline / body register on top of the
    /// shared JSON contract — same advice, different voice.
    static func registerClause(for voice: SpeakingStyleGoal?) -> String {
        switch voice {
        case .authoritative:
            return "Register: a steady, considered verdict. Declarative sentences. Confident. No hedging. The user is training authority — your insight reads like one."
        case .warm:
            return "Register: a trusted mentor. Soft warmth — not saccharine. Notice small wins. The user is training warmth — your insight reads like a felt observation, not a metric report."
        case .concise:
            return "Register: clipped and useful. One idea. Short sentences. No throat-clearing. The user is training conciseness — your insight reads tight."
        case .persuasive:
            return "Register: premise, evidence, recommendation — in that order. Show the reasoning briefly. The user is training persuasion — your insight reads structured."
        case .executive:
            return "Register: chief-of-staff briefing a busy principal. Top-line first. Calm, decisive. The user is training executive presence — your insight leads with the verdict."
        case .storytelling:
            return "Register: a narrative coach. Frame the week as a chapter. Quote the user's growth as an arc, not a metric. The user is training storytelling — your insight reads with shape."
        case .none:
            return "Register: calm and direct. No voice has been set yet — favour specifics over generalities."
        }
    }

    /// Optional model override for Gemini insights. Returns nil for non-
    /// Gemini providers (caller falls back to the provider's default
    /// endpoint). Gemini's endpoint URL embeds the model name, so the
    /// override is wired here rather than in the request body.
    private func insightsEndpoint(for provider: AIProvider, geminiModelOverride: String) -> URL? {
        guard provider == .gemini else { return nil }
        return URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(geminiModelOverride):generateContent")
    }

    static func userPrompt(from input: AIInsightInput) -> String {
        var lines: [String] = []
        // Goal goes first — for sessionDebrief the system prompt requires leading with it.
        if let goal = input.goalParaphrase, !goal.isEmpty {
            lines.append("User's stated goal: \(goal)")
            if let d = input.goalDistance {
                let pct = Int((1.0 - d) * 100)
                lines.append("Goal progress (higher = closer to goal): \(pct)%")
            }
        }
        lines.append("Sessions logged this week: \(input.weeklyReps)")
        lines.append("Rating delta this week: \(input.weeklyDelta >= 0 ? "+" : "")\(input.weeklyDelta)")
        lines.append("Current streak: \(input.currentStreak) day\(input.currentStreak == 1 ? "" : "s")")
        if let filler = input.topFillerWord {
            lines.append("Top filler word: \(filler)")
        }
        lines.append("Average score baseline: \(String(format: "%.1f", input.baseline.averageScore.value))/10")
        lines.append("Filler rate baseline: \(String(format: "%.1f", input.baseline.fillerRate.value)) per minute")
        lines.append("Pace baseline: \(String(format: "%.0f", input.baseline.pace.value)) WPM")
        if !input.baseline.topStrengths.isEmpty {
            lines.append("Strengths: \(input.baseline.topStrengths.joined(separator: ", "))")
        }
        if !input.baseline.persistentBlockers.isEmpty {
            lines.append("Blockers: \(input.baseline.persistentBlockers.joined(separator: ", "))")
        }

        if !input.focusSessions.isEmpty {
            lines.append("Recent sessions (newest first):")
            for (idx, session) in input.focusSessions.enumerated() {
                let scoreText = session.score.map { "\($0)/10" } ?? "n/a"
                let durText = String(format: "%.0fs", session.duration)
                lines.append("  \(idx + 1). \(session.mode.displayLabel) | score \(scoreText) | duration \(durText) | fillers \(session.fillerWordCount)")
            }
        }

        // For session debrief, surface the actual transcript so the AI
        // can quote / reference what the user said. Without this the
        // model can only restate metrics — which is exactly the
        // "dashboard, not a coach" output users complained about.
        if input.kind == .sessionDebrief,
           let mostRecent = input.focusSessions.first,
           !mostRecent.transcript.isEmpty {
            // The question this rep answered — single source of truth is the
            // session's stored prompt; promptOverride lets tests drive it.
            // Omitted entirely when unknown (no placeholder injected).
            let question = input.promptOverride ?? mostRecent.prompt
            if let q = question, !q.isEmpty {
                let trimmedQ = q.trimmingCharacters(in: .whitespacesAndNewlines)
                let cappedQ = trimmedQ.count > 200 ? String(trimmedQ.prefix(199)) + "…" : trimmedQ
                lines.append("")
                lines.append("THE QUESTION ASKED: \(cappedQ)")
            }
            lines.append("")
            lines.append("TRANSCRIPT OF THIS REP (quote a specific phrase; state whether it answered THE QUESTION ASKED and where the point landed):")
            let trimmed = mostRecent.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            let capped = trimmed.count > 900
                ? String(trimmed.prefix(899)) + "…"
                : trimmed
            lines.append(capped)
        }

        if !input.recentProofQuotes.isEmpty {
            lines.append("")
            lines.append("BANKED PROOFS (reference for continuity, never invent):")
            for quote in input.recentProofQuotes.prefix(2) {
                let capped = quote.count > 140
                    ? String(quote.prefix(139)) + "…"
                    : quote
                lines.append("- \"\(capped)\"")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func requestBody(for provider: AIProvider, prompt: String, system: String) -> [String: Any] {
        // Token budget — headline + ~80-word body + 3 evidence bullets +
        // action sentence comfortably fits in ~320 tokens. The earlier
        // unbounded shape risked silent truncation on the JSON close
        // brace, which caused the parser to reject otherwise-valid
        // insights and drop to the template fallback.
        switch provider {
        case .openAI, .deepSeek:
            return [
                "model": provider.model,
                "temperature": 0.5,
                "max_tokens": 320,
                "response_format": ["type": "json_object"],
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": prompt]
                ]
            ]
        case .gemini, .agentPlatform:            return [
                "systemInstruction": ["parts": [["text": system]]],
                "contents": [["parts": [["text": prompt]]]],
                "generationConfig": [
                    "temperature": 0.5,
                    "maxOutputTokens": 320,
                    "responseMimeType": "application/json"
                ]
            ]
        case .none:
            return [:]
        }
    }

    // MARK: - Response parsing

    private func parse(data: Data, provider: AIProvider, kind: AIInsightKind) -> AIInsight? {
        guard let raw = extractContent(from: data, provider: provider),
              let payload = decodeJSON(from: raw) else {
            return nil
        }
        let headline = (payload["headline"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let body = (payload["body"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let evidence = (payload["evidence"] as? [String])?
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        let action: String?
        if let value = payload["action"] as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            action = trimmed.isEmpty ? nil : trimmed
        } else {
            action = nil
        }
        guard !headline.isEmpty, !body.isEmpty else { return nil }
        return AIInsight(
            kind: kind,
            headline: headline,
            body: body,
            evidence: evidence,
            action: action,
            isAIBacked: true,
            generatedAt: Date()
        )
    }

    private func extractContent(from data: Data, provider: AIProvider) -> String? {
        switch provider {
        case .openAI, .deepSeek:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = object["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return nil }
            return content
        case .gemini, .agentPlatform:            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = object["candidates"] as? [[String: Any]],
                let first = candidates.first,
                let content = first["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]]
            else { return nil }
            return parts.compactMap { $0["text"] as? String }.joined(separator: " ")
        case .none:
            return nil
        }
    }

    private func decodeJSON(from raw: String) -> [String: Any]? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return dict
        }
        // Strip ``` fences and try again.
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

    // MARK: - Templated fallback

    private func templatedFallback(for input: AIInsightInput) -> AIInsight {
        switch input.kind {
        case .weeklyNarrative:
            return weeklyTemplate(input: input)
        case .sessionDebrief:
            return debriefTemplate(input: input)
        case .patternBreak:
            return patternBreakTemplate(input: input)
        }
    }

    private func weeklyTemplate(input: AIInsightInput) -> AIInsight {
        let evidence: [String] = [
            "\(input.weeklyReps) rep\(input.weeklyReps == 1 ? "" : "s") this week",
            "\(input.weeklyDelta >= 0 ? "+" : "")\(input.weeklyDelta) rating",
            input.topFillerWord.map { "Top filler: \u{201C}\($0)\u{201D}" } ?? ""
        ].filter { !$0.isEmpty }

        let headline: String
        let body: String
        let action: String?
        if input.weeklyReps == 0 {
            headline = "Quiet week"
            body = "No reps logged in the last seven days. The path is still here, the streak isn't lost yet."
            action = "Run one rep today to keep the streak open."
        } else if input.weeklyDelta > 5 {
            headline = "Strong upward week"
            body = "Your rating moved up notably and the reps came in steady. Pace and structure are doing the work."
            action = "Push one harder rep — Sudden Death or a longer Timed answer."
        } else if input.weeklyDelta < -5 {
            headline = "Pressure caught you"
            body = "Rating slipped this week. Most likely cause is fillers under pressure. The fix is calmer pacing, not more reps."
            action = "Run a Land the Pause drill to reset filler control."
        } else if input.weeklyReps >= 4 {
            headline = "Consistent week"
            body = "Reps came in steady and the rating held. That's the platform improvement gets built on."
            action = "Pick one weak skill and aim for two clean reps in it."
        } else {
            headline = "Light week, still moving"
            body = "A handful of reps kept the rating steady. The next gain comes from one extra session this week."
            action = "Add one rep tomorrow — same time, same prompt length."
        }
        return AIInsight(
            kind: .weeklyNarrative,
            headline: headline,
            body: body,
            evidence: evidence,
            action: action,
            isAIBacked: false,
            generatedAt: Date()
        )
    }

    private func debriefTemplate(input: AIInsightInput) -> AIInsight {
        guard let session = input.focusSessions.first else {
            return AIInsight(
                kind: .sessionDebrief,
                headline: "Run a rep",
                body: "Once you log a session the coach will surface what just changed.",
                evidence: [],
                action: nil,
                isAIBacked: false,
                generatedAt: Date()
            )
        }
        let score = session.score ?? 0
        let evidence: [String] = [
            "Score \(score)/10",
            "\(session.fillerWordCount) filler\(session.fillerWordCount == 1 ? "" : "s")",
            String(format: "%.0fs duration", session.duration)
        ]
        let headline: String
        let body: String
        let action: String
        if score >= 8 {
            headline = "Clean delivery landed"
            body = "Score of \(score) with low filler count means structure and pace held under load. That's the rep that proves the technique works."
            action = "Repeat the same mode at higher pressure tomorrow."
        } else if session.fillerWordCount >= 5 {
            headline = "Fillers crept in"
            body = "Score \(score) with \(session.fillerWordCount) fillers means pacing was rushed. The fix is intentional pauses, not faster delivery."
            action = "Try Land the Pause as your next rep."
        } else {
            headline = "Steady rep"
            body = "Score of \(score) and clean enough delivery. The next gain is in opening or close — pick one and tighten it."
            action = "Open your next rep with the answer in the first sentence."
        }
        return AIInsight(
            kind: .sessionDebrief,
            headline: headline,
            body: body,
            evidence: evidence,
            action: action,
            isAIBacked: false,
            generatedAt: Date()
        )
    }

    private func patternBreakTemplate(input: AIInsightInput) -> AIInsight {
        AIInsight(
            kind: .patternBreak,
            headline: "Pattern hold",
            body: "Nothing has shifted enough to call out yet. Keep running reps and the coach will catch the change when it lands.",
            evidence: [],
            action: nil,
            isAIBacked: false,
            generatedAt: Date()
        )
    }

    // MARK: - Cache key

    private func cacheKey(for input: AIInsightInput) -> String {
        var hasher = Hasher()
        hasher.combine(input.kind.rawValue)
        hasher.combine(input.weeklyReps)
        hasher.combine(input.weeklyDelta)
        hasher.combine(input.currentStreak)
        hasher.combine(input.topFillerWord ?? "")
        hasher.combine(input.focusSessions.first?.id)
        let calendar = Calendar.current
        let week = calendar.component(.weekOfYear, from: Date())
        hasher.combine(week)
        return "\(hasher.finalize())"
    }

    private func isStale(_ insight: AIInsight) -> Bool {
        Date().timeIntervalSince(insight.generatedAt) > maxCacheAge
    }
}
