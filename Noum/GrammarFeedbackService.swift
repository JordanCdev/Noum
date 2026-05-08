import Foundation

// MARK: - Grammar Feedback Service (M11)
//
// Light, post-session "polish notes" — surfaces objective grammar / English-
// usage issues a coach would flag (subject-verb agreement, run-on sentences,
// redundant phrasing, missing preposition, dangling modifier). Returns at
// most three notes per session, each pinned to a real excerpt from the
// transcript.
//
// Design rules — these are coaching invariants:
//
// 1. Pro-gated. Free users never trigger this. Caller is expected to check
//    `PremiumManager.shared.canViewCoachingInsights` before calling.
// 2. Conservative. Speaking practice is conversational, not written prose.
//    The model is instructed to skip stylistic preferences ("don't start a
//    sentence with 'And'"), to skip filler ("um", "uh") since FillerWordDetector
//    owns that surface, and to refuse anything below "this is clearly wrong
//    in formal speech" confidence. When in doubt, return zero notes.
// 3. Skips obviously-conversational sessions: very short reps (< 12 seconds
//    or < 25 words), low transcript confidence (< 0.55), and sessions whose
//    transcript looks like throat-clearing (≥30% filler ratio).
// 4. Cached per session ID. Caller should treat the result as authoritative
//    for the session — never re-call. The ProgressionCard / SummaryView are
//    the only callers.
// 5. Falls back to "no notes" rather than "AI fallback notes" when no
//    provider is configured. We never invent grammar issues from a template,
//    because we'd be wrong half the time on real speech.

enum GrammarNoteSeverity: String, Codable, Equatable {
    case minor       // Stylistic — would polish but didn't break the sentence.
    case moderate    // Reader/listener would notice. Worth fixing.
    case material    // Clear error that changed meaning or broke grammar.
}

enum GrammarNoteCategory: String, Codable, Equatable {
    case agreement       // Subject/verb, pronoun/antecedent
    case tense           // Tense shifts inside one clause
    case runOn           // Two clauses fused without punctuation/conjunction
    case fragment        // Missing subject or verb
    case redundancy      // "ATM machine", "free gift", obvious doubles
    case preposition     // Wrong / missing preposition
    case modifier        // Dangling or misplaced modifier
    case wordChoice      // Confused homonyms (their/there/they're, etc.)
    case other           // Anything else the model spots

    var label: String {
        switch self {
        case .agreement:    return "Agreement"
        case .tense:        return "Tense"
        case .runOn:        return "Run-on"
        case .fragment:     return "Fragment"
        case .redundancy:   return "Redundancy"
        case .preposition:  return "Preposition"
        case .modifier:     return "Modifier"
        case .wordChoice:   return "Word choice"
        case .other:        return "Polish"
        }
    }
}

/// One concrete grammar note. The card surfaces these as a short list with
/// the excerpt highlighted and the suggestion alongside.
struct GrammarNote: Codable, Equatable, Identifiable {
    var id: String { "\(category.rawValue):\(excerpt)" }
    let category: GrammarNoteCategory
    let severity: GrammarNoteSeverity
    /// Short excerpt from the user's actual transcript (≤ 80 chars). Required
    /// — every note must be pinned to real speech so the coach can show what
    /// they're talking about.
    let excerpt: String
    /// One-line suggestion in the user's voice (≤ 90 chars). Imperative,
    /// concrete, no chirpy filler.
    let suggestion: String
    /// One-line "why" in the user's voice (≤ 90 chars). Optional — the model
    /// only includes it when the rule isn't obvious from the suggestion.
    let rationale: String?
}

/// Result of one grammar pass. `notes` empty means "looks clean" — show a
/// soft positive in the card rather than hiding it. `aiBacked == false`
/// means the service skipped or fell back; the card then shows nothing.
struct GrammarPolishResult: Codable, Equatable {
    let notes: [GrammarNote]
    let aiBacked: Bool
    let generatedAt: Date

    static let empty = GrammarPolishResult(
        notes: [],
        aiBacked: false,
        generatedAt: Date(timeIntervalSince1970: 0)
    )

    /// True when the service ran successfully and the transcript was clean.
    var isCleanRun: Bool { aiBacked && notes.isEmpty }
}

actor GrammarFeedbackService {
    static let shared = GrammarFeedbackService()

    private init() {}

    /// Cache keyed by session ID. The result is authoritative for that
    /// session — re-asking would just re-spend AI quota for the same input.
    private var cache: [UUID: GrammarPolishResult] = [:]

    // MARK: - Public API

    /// Run the grammar pass for the given session. Returns nil ONLY when the
    /// session was skipped (too short, too noisy, free user). A successful
    /// run with no issues returns `.empty` with `aiBacked == true`.
    ///
    /// Caller should pre-check `PremiumManager.canViewCoachingInsights`. The
    /// service double-checks via the `isPro` parameter to keep the boundary
    /// explicit.
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
            // No provider — never invent template "grammar issues".
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
            case .gemini:
                request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
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

    /// Decides whether the session is grammar-readable. Same rules tested
    /// directly so the conservative behavior is locked.
    static func shouldRun(
        transcript: String,
        duration: TimeInterval,
        wordCount: Int,
        fillerWordCount: Int,
        transcriptConfidence: Double?
    ) -> Bool {
        // Too short — conversational fragments, not enough signal.
        guard duration >= 12 else { return false }
        guard wordCount >= 25 else { return false }
        // Noisy transcript — provider had a bad time. Wrong to grade grammar.
        if let confidence = transcriptConfidence, confidence < 0.55 { return false }
        // Throat-clearing — mostly fillers, no sentence structure to grade.
        if wordCount > 0 {
            let fillerRatio = Double(fillerWordCount) / Double(wordCount)
            if fillerRatio >= 0.30 { return false }
        }
        // Empty / whitespace-only transcripts (defensive).
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return true
    }

    // Instance-level convenience used by `polish` callsites (keeps the
    // call site readable while still honoring the static rule set).
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

    private func apiKey(for provider: AIProvider) -> String? {
        guard let keyName = provider.environmentKey else { return nil }
        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")
    }

    // MARK: - Prompt construction

    static let systemPrompt: String = """
    You are a careful English-usage editor reviewing a single spoken-practice \
    transcript. Your job is to surface up to THREE objective grammar / usage \
    issues the speaker would want to clean up in formal speech — and ONLY those.

    Hard rules:
    - SKIP filler words (um, uh, like, you know, so) — a separate system tracks those.
    - SKIP stylistic preferences (sentence-initial 'And/But', contractions, sentence length).
    - SKIP anything you are not confident is objectively wrong in formal English.
    - SKIP politeness, content, opinion, accuracy, or whether the answer is "good".
    - SKIP transcription artefacts (homophone confusion that's clearly the transcriber, \
    not the speaker — flag only when the transcript text itself is what would be wrong if \
    written down).
    - The transcript is conversational speech. Be VERY conservative. If nothing clear is \
    wrong, return an empty notes array.

    Allowed categories: agreement, tense, runOn, fragment, redundancy, preposition, \
    modifier, wordChoice, other.

    Severity:
    - "material" — clearly wrong, a listener notices.
    - "moderate" — bothers a careful listener.
    - "minor" — would polish but tolerable.

    Output strict JSON: { "notes": [ { "category": ..., "severity": ..., \
    "excerpt": ..., "suggestion": ..., "rationale": ... } ] }

    Each excerpt MUST be a verbatim substring of the transcript, ≤ 80 chars. \
    Each suggestion ≤ 90 chars, imperative, in the user's voice, no chirpy \
    filler ("Great job!"), no emoji, no exclamation marks. Rationale is \
    optional — include only when the rule isn't obvious from the suggestion.

    If nothing meets the bar, return {"notes": []}.
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
        case .gemini:
            return [
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

    func parse(data: Data, provider: AIProvider, transcript: String) -> GrammarPolishResult? {
        guard let raw = extractContent(from: data, provider: provider),
              let payload = decodeJSON(from: raw),
              let rawNotes = payload["notes"] as? [[String: Any]] else { return nil }

        let lowercaseTranscript = transcript.lowercased()
        let notes: [GrammarNote] = rawNotes.compactMap { dict -> GrammarNote? in
            guard
                let categoryRaw = dict["category"] as? String,
                let severityRaw = dict["severity"] as? String,
                let excerpt = (dict["excerpt"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                let suggestion = (dict["suggestion"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            else { return nil }

            // Excerpt must actually appear in the transcript — otherwise
            // the model fabricated quotes. Drop it.
            guard !excerpt.isEmpty,
                  excerpt.count <= 80,
                  lowercaseTranscript.contains(excerpt.lowercased()) else { return nil }

            guard let category = GrammarNoteCategory(rawValue: categoryRaw),
                  let severity = GrammarNoteSeverity(rawValue: severityRaw) else { return nil }
            guard !suggestion.isEmpty, suggestion.count <= 120 else { return nil }

            let rationale: String? = {
                guard let raw = (dict["rationale"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                      !raw.isEmpty,
                      raw.count <= 120 else { return nil }
                return raw
            }()

            return GrammarNote(
                category: category,
                severity: severity,
                excerpt: excerpt,
                suggestion: suggestion,
                rationale: rationale
            )
        }

        // Cap at 3 — the card can't carry more without becoming a wall.
        let capped = Array(notes.prefix(3))
        return GrammarPolishResult(
            notes: capped,
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
