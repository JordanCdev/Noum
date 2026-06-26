import Foundation

// MARK: - Grammar Feedback Service (M11 → M16)
//
// VISION future-milestone #7. The product framing is the whole product:
// "risks feeling pedantic." We surface findings ONLY when they materially
// affect clarity; we skip stylistic preferences entirely; we go silent
// when nothing crosses the bar.
//
// Coaching invariants (these are not negotiable):
//
// 1. Pro-gated. Free users never trigger this. Caller pre-checks
//    `PremiumManager.canViewCoachingInsights`; the service double-checks
//    via the `isPro` parameter.
// 2. Skip-first. Speech is conversational, not written prose. The rubric
//    rejects sentence-end prepositions, split infinitives, Oxford-comma
//    nits, "less vs fewer", "who vs whom", contractions, sentence length,
//    and single-instance minor agreement. The model is told this verbatim.
// 3. Threshold gate. After the model runs, we drop the result unless it
//    contains at least one HIGH-IMPACT finding (confused subject that
//    obscures meaning) OR ≥3 instances across the rep. Better silent than
//    pedantic.
// 4. Skips low-signal sessions: < 12 seconds, < 25 words, transcript
//    confidence < 0.55, ≥30% filler ratio. Same rules as M11 — they were
//    right then and they're right now.
// 5. Cached per session ID inside the actor AND persisted on the session
//    (M16: `PracticeSession.grammarFindings`). Re-asking the model for
//    the same transcript wastes quota and risks drift.
// 6. No template fallback. If no AI provider is configured, return nil
//    and the card self-hides. A regex grammar nag would be wrong half
//    the time on real speech.
// 7. English-only. Non-English locales hide the card cleanly.

/// One persisted grammar finding pinned to a real excerpt from the user's
/// transcript. This is the wire format stored on `PracticeSession` and
/// rendered by `GrammarPolishCard`.
struct GrammarFinding: Codable, Equatable, Identifiable {
    /// What kind of clarity issue this is. We only ship categories whose
    /// presence materially affects how a listener parses the sentence.
    enum Pattern: String, Codable, Equatable {
        case agreement       // subject/verb, pronoun/antecedent
        case runOn           // ≥3 fused clauses in one breath
        case pronounSwap     // mid-sentence "you" ↔ "one" ↔ "they"
        case tenseShift      // verb tense changes inside a single thought
        case repetition      // same 3+ word phrase used twice in close proximity
        case other           // anything else the model judges high-impact

        var label: String {
            switch self {
            case .agreement:   return "Agreement"
            case .runOn:       return "Run-on"
            case .pronounSwap: return "Pronoun"
            case .tenseShift:  return "Tense"
            case .repetition:  return "Repetition"
            case .other:       return "Clarity"
            }
        }
    }

    /// Severity drives the threshold gate and the tint chip on the card.
    /// `highImpact` alone is enough to surface a finding. `routine` only
    /// surfaces when ≥3 of them stack up in one rep.
    enum Severity: String, Codable, Equatable {
        case highImpact   // confused subject, dropped agreement that obscures meaning
        case routine      // pattern worth noting, but not a comprehension issue
    }

    var id: String { "\(pattern.rawValue):\(excerpt)" }
    let pattern: Pattern
    let severity: Severity
    /// Verbatim substring of the transcript (≤ 80 chars). Required — every
    /// finding pins to real speech the coach can show.
    let excerpt: String
    /// Coach voice. NEVER "incorrect", NEVER "wrong". Observational, e.g.
    /// "could read clearer as 'the list is'" or "pattern: three pronoun
    /// swaps in your closer". Sentence case, no exclamation marks, no emoji.
    let note: String
}

/// Result of one grammar pass. `findings` empty means "ran successfully
/// but nothing crossed the threshold" — the card self-hides on this case
/// (silence is the right move, not a forced positive). `aiBacked == false`
/// means the service skipped or fell back; card also self-hides.
struct GrammarPolishResult: Codable, Equatable {
    let findings: [GrammarFinding]
    let aiBacked: Bool
    let generatedAt: Date

    static let empty = GrammarPolishResult(
        findings: [],
        aiBacked: false,
        generatedAt: Date(timeIntervalSince1970: 0)
    )
}

actor GrammarFeedbackService {
    static let shared = GrammarFeedbackService()

    private init() {}

    /// In-actor cache keyed by session ID. Belt-and-braces with the
    /// per-session persistence on `PracticeSession.grammarFindings` —
    /// callers that already have the session should prefer the persisted
    /// field; this cache only matters for the freshly-completed rep.
    private var cache: [UUID: GrammarPolishResult] = [:]

    // MARK: - Public API

    /// Run the grammar pass for the given session. Returns nil when the
    /// session was skipped (too short, too noisy, free user, non-English
    /// locale, no AI provider). A successful run that surfaces nothing
    /// returns `.empty` with `aiBacked == true` — caller can persist the
    /// empty array so we don't re-call on subsequent visits to the same
    /// session.
    ///
    /// Caller MUST pre-check `PremiumManager.canViewCoachingInsights`. The
    /// service double-checks via `isPro` to keep the boundary explicit.
    func polish(
        sessionId: UUID,
        transcript: String,
        duration: TimeInterval,
        wordCount: Int,
        fillerWordCount: Int,
        transcriptConfidence: Double?,
        isPro: Bool
    ) async -> GrammarPolishResult? {
        if let cached = cache[sessionId] { return cached }
        guard isPro else { return nil }
        // M13: English-only — Spanish/French transcripts would produce
        // English-rules feedback on non-English speech (noise, not coaching).
        guard await activeLocaleSupportsAI() else { return nil }
        guard shouldRun(
            transcript: transcript,
            duration: duration,
            wordCount: wordCount,
            fillerWordCount: fillerWordCount,
            transcriptConfidence: transcriptConfidence
        ) else { return nil }

        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider) else {
            // No provider — never invent template grammar findings.
            return nil
        }

        do {
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 14

            let body = requestBody(for: provider, transcript: transcript)
            switch provider {
            case .openAI, .deepSeek:
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            case .gemini, .agentPlatform:                request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            case .none:
                return nil
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard let parsed = parse(data: data, provider: provider, transcript: transcript) else {
                return nil
            }
            cache[sessionId] = parsed
            return parsed
        } catch {
            return nil
        }
    }

    /// Drop a cached entry. Used by tests; not exposed to UI.
    func invalidate(sessionId: UUID) {
        cache.removeValue(forKey: sessionId)
    }

    // MARK: - Skip rules

    /// Decides whether the session is grammar-readable. Lifted as a static
    /// so the UI can mirror the check and hide the skeleton fast on
    /// obviously-too-short reps, instead of flashing.
    static func shouldRun(
        transcript: String,
        duration: TimeInterval,
        wordCount: Int,
        fillerWordCount: Int,
        transcriptConfidence: Double?
    ) -> Bool {
        guard duration >= 12 else { return false }
        guard wordCount >= 25 else { return false }
        if let confidence = transcriptConfidence, confidence < 0.55 { return false }
        if wordCount > 0 {
            let fillerRatio = Double(fillerWordCount) / Double(wordCount)
            if fillerRatio >= 0.30 { return false }
        }
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return true
    }

    private func shouldRun(
        transcript: String,
        duration: TimeInterval,
        wordCount: Int,
        fillerWordCount: Int,
        transcriptConfidence: Double?
    ) -> Bool {
        Self.shouldRun(
            transcript: transcript,
            duration: duration,
            wordCount: wordCount,
            fillerWordCount: fillerWordCount,
            transcriptConfidence: transcriptConfidence
        )
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

    // MARK: - Prompt construction
    //
    // The system prompt is the product. We bake the pedantic-avoidance
    // rubric in verbatim and tell the model the threshold so it doesn't
    // pad its output to look helpful.

    static let systemPrompt: String = """
    You are a speaking coach reviewing one spoken-practice transcript. Your job is to \
    surface English-usage patterns that materially affect how a listener parses \
    the speaker's meaning — and ONLY those. The bar is HIGH. Skip-first is the \
    operating mode. If nothing crosses the bar, return an empty array.

    SURFACE these (only when they materially affect clarity):
    - Subject-verb agreement that obscures meaning (e.g. "the list of items are…" → "is")
    - Run-on sentences with 3+ fused clauses in one breath
    - Mid-sentence pronoun swaps ("when you start, one should…")
    - Confused or mismatched verb tenses inside a single thought
    - Same 3+ word phrase repeated twice in close proximity

    SKIP these (would feel nagging — never include them):
    - Missing Oxford commas
    - Sentence-end prepositions ("the place I came from")
    - Split infinitives ("to really understand")
    - "Less vs fewer", "who vs whom", "which vs that"
    - Single isolated minor agreement breaks (informal speech is fine)
    - Contractions, sentence length, sentence-initial "And"/"But"
    - Filler words (um, uh, like) — tracked by a separate system
    - Politeness, content, opinion, accuracy, whether the answer is "good"
    - Transcription artefacts (homophone confusion that's clearly the transcriber)
    - Anything that's a stylistic preference, not a clarity issue

    THRESHOLD: only surface findings that meet ONE of:
    - At least one finding has severity "highImpact" (confused subject that obscures \
    meaning, or a tense/pronoun shift that breaks comprehension), OR
    - At least 3 findings of any severity stack up in this single transcript.

    If you cannot meet the threshold, return {"findings": []}. Do NOT pad. Do NOT \
    invent findings.

    VOICE for the `note` field — this is critical:
    - NEVER "incorrect" or "wrong" — observational only.
    - Phrase as "could read clearer as <X>" or "pattern: <Y>".
    - Coach voice: observational, not corrective. Sentence case. No emoji. \
    No exclamation marks. ≤ 90 chars.
    - Examples:
      * agreement: "could read clearer as 'the list is' — singular subject"
      * runOn: "three clauses fused — splitting at 'and then' lands cleaner"
      * pronounSwap: "pattern: you → one mid-sentence; pick one and hold it"
      * repetition: "phrase 'at the end of the day' lands twice in the closer"

    ALLOWED pattern values: agreement, runOn, pronounSwap, tenseShift, repetition, other.
    ALLOWED severity values: highImpact, routine.

    Output strict JSON: { "findings": [ { "pattern": ..., "severity": ..., \
    "excerpt": ..., "note": ... } ] }

    Each `excerpt` MUST be a verbatim substring of the transcript (≤ 80 chars). \
    Each `note` ≤ 90 chars, observational coach voice, no emoji, no exclamation marks.

    Maximum 3 findings per transcript even when more meet the bar — pick the \
    most clarity-affecting three. If zero meet the bar, return {"findings": []}.
    """

    private func requestBody(for provider: AIProvider, transcript: String) -> [String: Any] {
        let userPrompt = "Transcript:\n\(transcript)"
        switch provider {
        case .openAI, .deepSeek:
            return [
                "model": provider.model,
                // Low temperature — we want consistent, conservative reads.
                "temperature": 0.2,
                "response_format": ["type": "json_object"],
                "messages": [
                    ["role": "system", "content": Self.systemPrompt],
                    ["role": "user", "content": userPrompt]
                ]
            ]
        case .gemini, .agentPlatform:            return [
                "systemInstruction": ["parts": [["text": Self.systemPrompt]]],
                "contents": [["parts": [["text": userPrompt]]]],
                "generationConfig": [
                    "temperature": 0.2,
                    "responseMimeType": "application/json"
                ]
            ]
        case .none:
            return [:]
        }
    }

    // MARK: - Response parsing
    //
    // We re-enforce the threshold on our side too: the model is told the
    // rule but we don't trust it to obey under all prompts. If the model
    // surfaces e.g. one routine-severity finding, we drop the whole result.

    func parse(data: Data, provider: AIProvider, transcript: String) -> GrammarPolishResult? {
        guard let raw = extractContent(from: data, provider: provider),
              let payload = decodeJSON(from: raw),
              let rawFindings = payload["findings"] as? [[String: Any]] else { return nil }

        let lowercaseTranscript = transcript.lowercased()
        let findings: [GrammarFinding] = rawFindings.compactMap { dict -> GrammarFinding? in
            guard
                let patternRaw = dict["pattern"] as? String,
                let severityRaw = dict["severity"] as? String,
                let excerpt = (dict["excerpt"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                let note = (dict["note"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            else { return nil }

            // Excerpt must actually appear in the transcript — otherwise
            // the model fabricated quotes. Drop it.
            guard !excerpt.isEmpty,
                  excerpt.count <= 80,
                  lowercaseTranscript.contains(excerpt.lowercased()) else { return nil }

            guard let pattern = GrammarFinding.Pattern(rawValue: patternRaw),
                  let severity = GrammarFinding.Severity(rawValue: severityRaw) else { return nil }
            guard !note.isEmpty, note.count <= 120 else { return nil }

            // Voice guard: reject any note that uses the words "incorrect"
            // or "wrong" — the model knows the rule but slips. A finding
            // that calls the user wrong is worse than no finding.
            let lowercaseNote = note.lowercased()
            if lowercaseNote.contains("incorrect") || lowercaseNote.contains("wrong") {
                return nil
            }

            return GrammarFinding(
                pattern: pattern,
                severity: severity,
                excerpt: excerpt,
                note: note
            )
        }

        // Re-enforce the threshold: at least one highImpact, OR ≥3 findings.
        // If neither, drop the whole result and let the card stay silent.
        let hasHighImpact = findings.contains { $0.severity == .highImpact }
        let hasThreeOrMore = findings.count >= 3
        guard hasHighImpact || hasThreeOrMore else {
            return GrammarPolishResult(
                findings: [],
                aiBacked: true,
                generatedAt: Date()
            )
        }

        // Cap at 3 — the card can't carry more without becoming a wall.
        let capped = Array(findings.prefix(3))
        return GrammarPolishResult(
            findings: capped,
            aiBacked: true,
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
}
