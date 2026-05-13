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
        // M14 polish: pass the active practice locale into the template so
        // a Spanish / French user gets a Spanish / French fallback debrief
        // instead of English boilerplate. Cache key includes the locale so
        // switching language doesn't serve a cached fallback in the
        // previous locale's wording.
        let activeLocale = await currentPracticeLocale()
        let cacheKey = cacheKey(for: input, locale: activeLocale)
        if let cached = cache[cacheKey], !isStale(cached) {
            return cached
        }

        let templated = templatedFallback(for: input, locale: activeLocale)

        // M13: AI insight surfaces are English-only in this milestone.
        // Non-English practice sessions get the deterministic template
        // fallback so the card stays useful but never produces English
        // coaching text on a Spanish or French session.
        guard activeLocale.aiSupported else {
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
            let prompt = userPrompt(from: input)
            let body = requestBody(for: provider, prompt: prompt, system: systemPrompt(for: input.kind))
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 14
            switch provider {
            case .openAI, .deepSeek:
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            case .gemini:
                request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
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
    /// pull-to-refresh. Invalidates every locale slot for this input so
    /// a forced refresh re-runs regardless of which locale produced
    /// the prior cached result.
    func invalidate(for input: AIInsightInput) {
        for locale in PracticeLocale.allCases {
            cache.removeValue(forKey: cacheKey(for: input, locale: locale))
        }
    }

    // MARK: - Provider plumbing

    @MainActor
    private func currentProvider() -> AIProvider? {
        AISettingsManager.shared.activeProvider
    }

    /// The currently selected practice locale. Drives the template
    /// fallback's output language and gates the AI hop — non-en-US
    /// locales fall through to the locale-aware template.
    @MainActor
    private func currentPracticeLocale() -> PracticeLocale {
        LocaleSettingsManager.shared.current
    }

    private func apiKey(for provider: AIProvider) -> String? {
        guard let keyName = provider.environmentKey else { return nil }
        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")
    }

    // MARK: - Prompt construction

    private func systemPrompt(for kind: AIInsightKind) -> String {
        // Voice rules pulled directly from .claude/skills/noum-design:
        // direct, second-person, imperative-leaning, never chirpy, no emoji,
        // no exclamation marks. Always tied to concrete numbers.
        let common = """
        You are a senior speaking coach. Voice: direct, warm, and specific. \
        You speak in second person, address the user as "you", and never \
        use chirpy filler ("Awesome!", "Great job!"). No emoji. No \
        exclamation marks. Sentences land in 18 words or fewer. Reference \
        the user's actual numbers — never invent statistics. If a number \
        isn't given, don't claim a number.
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
            return common + "\nThe goal is a coaching read of one specific session. If a user goal is provided, your first sentence MUST connect this session to that goal — e.g. 'You said you wanted to X — this session moved toward/away from that because…'. Then name what concretely changed."
        case .patternBreak:
            return common + "\nA pattern just shifted. Surface what changed and whether it was good or bad. If a user goal is provided, frame the shift in terms of that goal."
        }
    }

    private func userPrompt(from input: AIInsightInput) -> String {
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
        return lines.joined(separator: "\n")
    }

    private func requestBody(for provider: AIProvider, prompt: String, system: String) -> [String: Any] {
        switch provider {
        case .openAI, .deepSeek:
            return [
                "model": provider.model,
                "temperature": 0.5,
                "response_format": ["type": "json_object"],
                "messages": [
                    ["role": "system", "content": system],
                    ["role": "user", "content": prompt]
                ]
            ]
        case .gemini:
            return [
                "systemInstruction": ["parts": [["text": system]]],
                "contents": [["parts": [["text": prompt]]]],
                "generationConfig": [
                    "temperature": 0.5,
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
        case .gemini:
            guard
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

    private func templatedFallback(for input: AIInsightInput, locale: PracticeLocale) -> AIInsight {
        switch input.kind {
        case .weeklyNarrative:
            return weeklyTemplate(input: input, locale: locale)
        case .sessionDebrief:
            return debriefTemplate(input: input, locale: locale)
        case .patternBreak:
            return patternBreakTemplate(input: input, locale: locale)
        }
    }

    private func weeklyTemplate(input: AIInsightInput, locale: PracticeLocale) -> AIInsight {
        let copy = TemplateCopy.weekly(for: locale)
        let evidence: [String] = [
            input.weeklyReps == 1 ? copy.repSingular(input.weeklyReps) : copy.repPlural(input.weeklyReps),
            copy.ratingDelta(input.weeklyDelta),
            input.topFillerWord.map { copy.topFiller($0) } ?? ""
        ].filter { !$0.isEmpty }

        let phrase: TemplateCopy.WeeklyPhrase
        if input.weeklyReps == 0 {
            phrase = copy.quietWeek
        } else if input.weeklyDelta > 5 {
            phrase = copy.strongUp
        } else if input.weeklyDelta < -5 {
            phrase = copy.pressureCaught
        } else if input.weeklyReps >= 4 {
            phrase = copy.consistent
        } else {
            phrase = copy.lightWeek
        }
        return AIInsight(
            kind: .weeklyNarrative,
            headline: phrase.headline,
            body: phrase.body,
            evidence: evidence,
            action: phrase.action,
            isAIBacked: false,
            generatedAt: Date()
        )
    }

    private func debriefTemplate(input: AIInsightInput, locale: PracticeLocale) -> AIInsight {
        let copy = TemplateCopy.debrief(for: locale)
        guard let session = input.focusSessions.first else {
            return AIInsight(
                kind: .sessionDebrief,
                headline: copy.empty.headline,
                body: copy.empty.body,
                evidence: [],
                action: nil,
                isAIBacked: false,
                generatedAt: Date()
            )
        }
        let score = session.score ?? 0
        let evidence: [String] = [
            copy.scoreLine(score),
            session.fillerWordCount == 1 ? copy.fillerSingular(session.fillerWordCount) : copy.fillerPlural(session.fillerWordCount),
            copy.durationLine(session.duration)
        ]
        let phrase: TemplateCopy.DebriefPhrase
        if score >= 8 {
            phrase = copy.clean(score)
        } else if session.fillerWordCount >= 5 {
            phrase = copy.fillers(score, session.fillerWordCount)
        } else {
            phrase = copy.steady(score)
        }
        return AIInsight(
            kind: .sessionDebrief,
            headline: phrase.headline,
            body: phrase.body,
            evidence: evidence,
            action: phrase.action,
            isAIBacked: false,
            generatedAt: Date()
        )
    }

    private func patternBreakTemplate(input: AIInsightInput, locale: PracticeLocale) -> AIInsight {
        let copy = TemplateCopy.patternBreak(for: locale)
        return AIInsight(
            kind: .patternBreak,
            headline: copy.headline,
            body: copy.body,
            evidence: [],
            action: nil,
            isAIBacked: false,
            generatedAt: Date()
        )
    }

    // MARK: - Cache key

    private func cacheKey(for input: AIInsightInput, locale: PracticeLocale) -> String {
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
        hasher.combine(locale.rawValue)
        return "\(hasher.finalize())"
    }

    private func isStale(_ insight: AIInsight) -> Bool {
        Date().timeIntervalSince(insight.generatedAt) > maxCacheAge
    }
}

// MARK: - Template Copy (locale-aware fallback)

/// Curated copy used by the template fallback when no AI provider is
/// configured or when the user's practice locale is not en-US. Each
/// locale's translations are hand-written, not machine-translated —
/// the coaching voice has to survive the switch.
///
/// Voice rules carry through (see `.claude/skills/noum-design`): direct,
/// second-person, no chirpy filler, no emoji, no exclamation marks.
/// Spanish + French follow the same constraints in their own register.
private enum TemplateCopy {

    // MARK: Weekly narrative

    struct WeeklyPhrase {
        let headline: String
        let body: String
        let action: String
    }

    struct Weekly {
        let quietWeek: WeeklyPhrase
        let strongUp: WeeklyPhrase
        let pressureCaught: WeeklyPhrase
        let consistent: WeeklyPhrase
        let lightWeek: WeeklyPhrase
        let repSingular: (Int) -> String
        let repPlural: (Int) -> String
        let ratingDelta: (Int) -> String
        let topFiller: (String) -> String
    }

    static func weekly(for locale: PracticeLocale) -> Weekly {
        switch locale {
        case .enUS:
            return Weekly(
                quietWeek: WeeklyPhrase(
                    headline: "Quiet week",
                    body: "No reps logged in the last seven days. The path is still here, the streak isn't lost yet.",
                    action: "Run one rep today to keep the streak open."
                ),
                strongUp: WeeklyPhrase(
                    headline: "Strong upward week",
                    body: "Your rating moved up notably and the reps came in steady. Pace and structure are doing the work.",
                    action: "Push one harder rep — Sudden Death or a longer Timed answer."
                ),
                pressureCaught: WeeklyPhrase(
                    headline: "Pressure caught you",
                    body: "Rating slipped this week. Most likely cause is fillers under pressure. The fix is calmer pacing, not more reps.",
                    action: "Run a Land the Pause drill to reset filler control."
                ),
                consistent: WeeklyPhrase(
                    headline: "Consistent week",
                    body: "Reps came in steady and the rating held. That's the platform improvement gets built on.",
                    action: "Pick one weak skill and aim for two clean reps in it."
                ),
                lightWeek: WeeklyPhrase(
                    headline: "Light week, still moving",
                    body: "A handful of reps kept the rating steady. The next gain comes from one extra session this week.",
                    action: "Add one rep tomorrow — same time, same prompt length."
                ),
                repSingular: { n in "\(n) rep this week" },
                repPlural: { n in "\(n) reps this week" },
                ratingDelta: { d in "\(d >= 0 ? "+" : "")\(d) rating" },
                topFiller: { w in "Top filler: \u{201C}\(w)\u{201D}" }
            )
        case .esES:
            return Weekly(
                quietWeek: WeeklyPhrase(
                    headline: "Semana tranquila",
                    body: "Sin sesiones en los últimos siete días. El camino sigue ahí, la racha aún no se ha roto.",
                    action: "Haz una sesión hoy para mantener la racha viva."
                ),
                strongUp: WeeklyPhrase(
                    headline: "Semana en alza",
                    body: "Tu puntuación subió con claridad y las sesiones fueron constantes. El ritmo y la estructura están haciendo el trabajo.",
                    action: "Sube la presión — Sudden Death o una respuesta Timed más larga."
                ),
                pressureCaught: WeeklyPhrase(
                    headline: "La presión te alcanzó",
                    body: "La puntuación bajó esta semana. Lo más probable: muletillas bajo presión. La solución es un ritmo más calmado, no más sesiones.",
                    action: "Haz un drill Land the Pause para recuperar el control."
                ),
                consistent: WeeklyPhrase(
                    headline: "Semana constante",
                    body: "Las sesiones llegaron con regularidad y la puntuación se mantuvo. Esa es la base sobre la que se construye la mejora.",
                    action: "Elige una habilidad débil y apunta a dos sesiones limpias."
                ),
                lightWeek: WeeklyPhrase(
                    headline: "Semana ligera, sin frenar",
                    body: "Unas pocas sesiones mantuvieron la puntuación estable. La próxima ganancia llega con una sesión extra esta semana.",
                    action: "Añade una sesión mañana — misma hora, misma duración."
                ),
                repSingular: { n in "\(n) sesión esta semana" },
                repPlural: { n in "\(n) sesiones esta semana" },
                ratingDelta: { d in "\(d >= 0 ? "+" : "")\(d) puntos" },
                topFiller: { w in "Muletilla principal: \u{201C}\(w)\u{201D}" }
            )
        case .frFR:
            return Weekly(
                quietWeek: WeeklyPhrase(
                    headline: "Semaine calme",
                    body: "Aucune séance ces sept derniers jours. Le parcours est toujours là, la série n'est pas encore perdue.",
                    action: "Lance une séance aujourd'hui pour garder la série en vie."
                ),
                strongUp: WeeklyPhrase(
                    headline: "Semaine en hausse",
                    body: "Ta note a nettement progressé et les séances ont été régulières. Le rythme et la structure font le travail.",
                    action: "Pousse une séance plus dure — Sudden Death ou un Timed plus long."
                ),
                pressureCaught: WeeklyPhrase(
                    headline: "La pression t'a rattrapé",
                    body: "Ta note a baissé cette semaine. La cause la plus probable : des tics de langage sous pression. Le remède est un rythme plus calme, pas plus de séances.",
                    action: "Fais un drill Land the Pause pour reprendre le contrôle."
                ),
                consistent: WeeklyPhrase(
                    headline: "Semaine régulière",
                    body: "Les séances sont arrivées avec constance et la note s'est tenue. C'est la base sur laquelle se bâtit la progression.",
                    action: "Choisis une compétence faible et vise deux séances propres."
                ),
                lightWeek: WeeklyPhrase(
                    headline: "Semaine légère, toujours en route",
                    body: "Quelques séances ont maintenu la note. Le prochain gain viendra d'une séance supplémentaire cette semaine.",
                    action: "Ajoute une séance demain — même heure, même durée."
                ),
                repSingular: { n in "\(n) séance cette semaine" },
                repPlural: { n in "\(n) séances cette semaine" },
                ratingDelta: { d in "\(d >= 0 ? "+" : "")\(d) points" },
                topFiller: { w in "Tic principal : \u{201C}\(w)\u{201D}" }
            )
        }
    }

    // MARK: Session debrief

    struct DebriefPhrase {
        let headline: String
        let body: String
        let action: String
    }

    struct DebriefEmpty {
        let headline: String
        let body: String
    }

    struct Debrief {
        let empty: DebriefEmpty
        let clean: (Int) -> DebriefPhrase
        let fillers: (Int, /* count */ Int) -> DebriefPhrase
        let steady: (Int) -> DebriefPhrase
        let scoreLine: (Int) -> String
        let fillerSingular: (Int) -> String
        let fillerPlural: (Int) -> String
        let durationLine: (TimeInterval) -> String
    }

    static func debrief(for locale: PracticeLocale) -> Debrief {
        switch locale {
        case .enUS:
            return Debrief(
                empty: DebriefEmpty(
                    headline: "Run a rep",
                    body: "Once you log a session the coach will surface what just changed."
                ),
                clean: { score in
                    DebriefPhrase(
                        headline: "Clean delivery landed",
                        body: "Score of \(score) with low filler count means structure and pace held under load. That's the rep that proves the technique works.",
                        action: "Repeat the same mode at higher pressure tomorrow."
                    )
                },
                fillers: { score, count in
                    DebriefPhrase(
                        headline: "Fillers crept in",
                        body: "Score \(score) with \(count) fillers means pacing was rushed. The fix is intentional pauses, not faster delivery.",
                        action: "Try Land the Pause as your next rep."
                    )
                },
                steady: { score in
                    DebriefPhrase(
                        headline: "Steady rep",
                        body: "Score of \(score) and clean enough delivery. The next gain is in opening or close — pick one and tighten it.",
                        action: "Open your next rep with the answer in the first sentence."
                    )
                },
                scoreLine: { s in "Score \(s)/10" },
                fillerSingular: { n in "\(n) filler" },
                fillerPlural: { n in "\(n) fillers" },
                durationLine: { d in String(format: "%.0fs duration", d) }
            )
        case .esES:
            return Debrief(
                empty: DebriefEmpty(
                    headline: "Haz una sesión",
                    body: "Cuando registres una sesión, el coach mostrará qué acaba de cambiar."
                ),
                clean: { score in
                    DebriefPhrase(
                        headline: "Entrega limpia",
                        body: "Puntuación de \(score) con pocas muletillas: estructura y ritmo aguantaron bajo presión. Esa es la sesión que demuestra que la técnica funciona.",
                        action: "Repite el mismo modo mañana con más presión."
                    )
                },
                fillers: { score, count in
                    DebriefPhrase(
                        headline: "Aparecieron las muletillas",
                        body: "Puntuación \(score) con \(count) muletillas: el ritmo se aceleró. La solución son pausas intencionales, no hablar más rápido.",
                        action: "Prueba Land the Pause como próxima sesión."
                    )
                },
                steady: { score in
                    DebriefPhrase(
                        headline: "Sesión sólida",
                        body: "Puntuación de \(score) y entrega bastante limpia. La próxima ganancia está en la apertura o el cierre — elige una y ajústala.",
                        action: "Abre la próxima sesión con la respuesta en la primera frase."
                    )
                },
                scoreLine: { s in "Puntuación \(s)/10" },
                fillerSingular: { n in "\(n) muletilla" },
                fillerPlural: { n in "\(n) muletillas" },
                durationLine: { d in String(format: "%.0fs de duración", d) }
            )
        case .frFR:
            return Debrief(
                empty: DebriefEmpty(
                    headline: "Lance une séance",
                    body: "Dès que tu enregistres une séance, le coach montrera ce qui vient de changer."
                ),
                clean: { score in
                    DebriefPhrase(
                        headline: "Livraison nette",
                        body: "Note de \(score) avec peu de tics : la structure et le rythme ont tenu sous pression. C'est la séance qui prouve que la technique fonctionne.",
                        action: "Refais le même mode demain avec plus de pression."
                    )
                },
                fillers: { score, count in
                    DebriefPhrase(
                        headline: "Les tics se sont glissés",
                        body: "Note \(score) avec \(count) tics : le rythme a accéléré. Le remède, ce sont des pauses intentionnelles, pas un débit plus rapide.",
                        action: "Essaie Land the Pause pour ta prochaine séance."
                    )
                },
                steady: { score in
                    DebriefPhrase(
                        headline: "Séance solide",
                        body: "Note de \(score) et livraison assez propre. Le prochain gain se trouve dans l'ouverture ou la clôture — choisis une et resserre-la.",
                        action: "Ouvre ta prochaine séance par la réponse dès la première phrase."
                    )
                },
                scoreLine: { s in "Note \(s)/10" },
                fillerSingular: { n in "\(n) tic" },
                fillerPlural: { n in "\(n) tics" },
                durationLine: { d in String(format: "%.0fs de durée", d) }
            )
        }
    }

    // MARK: Pattern break

    struct PatternBreak {
        let headline: String
        let body: String
    }

    static func patternBreak(for locale: PracticeLocale) -> PatternBreak {
        switch locale {
        case .enUS:
            return PatternBreak(
                headline: "Pattern hold",
                body: "Nothing has shifted enough to call out yet. Keep running reps and the coach will catch the change when it lands."
            )
        case .esES:
            return PatternBreak(
                headline: "Patrón estable",
                body: "Nada ha cambiado lo suficiente para destacarlo. Sigue practicando y el coach captará el cambio cuando ocurra."
            )
        case .frFR:
            return PatternBreak(
                headline: "Schéma stable",
                body: "Rien n'a assez bougé pour être souligné. Continue à pratiquer et le coach captera le changement quand il arrivera."
            )
        }
    }
}
