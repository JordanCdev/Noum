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

        do {
            let body = requestBody(for: provider, input: input)
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
        let closing = persona.closing(seed: seed)

        let metricSentence = metricSentence(for: input, persona: persona)

        // Compose: "<lead> <metric>. <closing>."
        // Trim trailing punctuation defensively so we never double-period.
        var text = "\(lead) \(metricSentence) \(closing)"
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
    nonisolated static func metricSentence(
        for input: PostRepCoachNoteInput,
        persona: CoachPersona
    ) -> String {
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

        // 6) Fallback — neutral steady-delivery note.
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

    private func userPrompt(from input: PostRepCoachNoteInput) -> String {
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
        return lines.joined(separator: "\n")
    }

    private func systemPrompt(persona: CoachPersona) -> String {
        return """
        You are a senior speaking coach writing a 2-sentence note to your \
        client right after a practice rep. Voice register: \
        \(persona.signatureTone)

        Hard rules:
        - Exactly 2 sentences. Total length ≤ 180 characters.
        - No exclamation marks. No chirpy filler ("Awesome", "Great job", \
        "Let's"). No emoji.
        - Cite at least one concrete fact from the input — a score, a \
        filler count, a pace number, a duration. Never invent stats.
        - Never punish-shame a low score. If a number dropped, acknowledge \
        it factually and name a small next move.
        - Output STRICT JSON: {"note": "..."} — nothing else. The note \
        field carries the two sentences.
        """
    }

    private func requestBody(for provider: AIProvider, input: PostRepCoachNoteInput) -> [String: Any] {
        let persona = CoachPersona.persona(for: input.voice)
        let system = systemPrompt(persona: persona)
        let user = userPrompt(from: input)
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
        case .gemini:
            return [
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
        case .gemini:
            guard
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

    private func apiKey(for provider: AIProvider) -> String? {
        guard let keyName = provider.environmentKey else { return nil }
        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")
    }
}
