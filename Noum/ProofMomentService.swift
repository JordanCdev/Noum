import Foundation

// MARK: - Proof Moment Service
//
// "Proof moments" are short, transcript-anchored evidence of growth tied
// to the user's stated speaking style goal. Instead of a generic "score
// went up", the user sees:
//
//   > "In your Wed rep, you waited 4 seconds before answering: 'On
//   > revenue: 14%.' That's a Power Pause + BLUF — both authority moves."
//
// The proof binds (a) a moment in their actual rep, (b) the technique
// that moment demonstrates, (c) a one-line claim tying the technique
// back to their voice goal. That's what makes rating numbers feel
// *earned* instead of arbitrary.
//
// Design rules:
//   • Per-session cache — one ProofMoment per session, keyed by
//     session.id. Invalidation happens only when the source session's
//     transcript changes (never, in practice — sessions are immutable
//     once finalized). This keeps AI quota bounded.
//   • Fallback to deterministic extraction — if no AI provider is
//     configured (M13 non-English locale, or the user has not set up
//     keys), the service falls back to a template that picks the
//     highest-scoring session in the window and surfaces the actual
//     numbers. The proof always renders something useful.
//   • Voice-tied claims — the technique-to-claim mapping varies per
//     SpeakingStyleGoal. The same "3-second pause" reads as an
//     authority move under .authoritative and as a composure move
//     under .executive.
//   • No fabrication — the quote field MUST come verbatim from the
//     session transcript. If the model returns a quote we can't find
//     in the transcript, we fall back to the template path.

/// A single piece of transcript-anchored evidence of growth.
struct ProofMoment: Codable, Equatable {
    /// Verbatim slice of the user's actual transcript that demonstrates
    /// the technique. Must be present in the source session's transcript
    /// (we verify before caching).
    let quote: String
    /// Short label for the technique demonstrated, e.g. "Power Pause",
    /// "Strip the Softeners", "BLUF". Drives the small chip in the UI.
    let technique: String
    /// One-line coach voice claim tying the technique to the user's
    /// stated voice goal, e.g. "That's authority — you've earned it."
    let claim: String
    /// Date of the source session (used for the "In your Wed rep, …"
    /// framing in the UI).
    let sessionDate: Date
    /// True if this proof came from an AI call. False = deterministic
    /// template fallback. Lets the UI show the AI/Live chip honestly.
    let isAIBacked: Bool
    /// Generated timestamp — used for stale checks if we ever extend
    /// invalidation rules.
    let generatedAt: Date

    /// Cold-start placeholder shown while a real proof is loading.
    /// Never written to the cache; UI-only.
    static let placeholder = ProofMoment(
        quote: "",
        technique: "",
        claim: "",
        sessionDate: Date(),
        isAIBacked: false,
        generatedAt: Date()
    )
}

/// Input shape for a proof extraction request. Mirrors the pattern
/// `AIInsightInput` uses — bundling the user state needed for the
/// model to make a grounded claim.
struct ProofMomentInput {
    /// The session to mine. Its `transcript` is the only place a quote
    /// can come from.
    let session: PracticeSession
    /// The user's stated voice goal. Drives the technique-to-claim
    /// mapping and the system prompt.
    let voice: SpeakingStyleGoal?
    /// One-sentence paraphrase of the user's goal — feeds into the
    /// claim line so the proof reads in *their* words, not generic.
    let goalParaphrase: String?
    /// Optional rolling baseline numbers for context (so the model can
    /// frame the moment in terms of the user's normal).
    let baselineFillerRate: Double?
    let baselinePace: Double?
}

@available(iOS 17.0, macOS 12.0, *)
actor ProofMomentService {

    static let shared = ProofMomentService()

    /// In-memory cache keyed by session ID. Sessions are immutable
    /// once finalized, so we never need to invalidate by content — a
    /// cache hit is always still valid.
    private var cache: [UUID: ProofMoment] = [:]

    private init() {}

    /// Extract (or return cached) proof for a session. Returns nil if
    /// the session has no transcript or its duration is too short to
    /// produce a meaningful proof (≤8 seconds — likely a misfire rep).
    func proof(for input: ProofMomentInput) async -> ProofMoment? {
        if let cached = cache[input.session.id] {
            return cached
        }

        guard !input.session.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              input.session.duration > 8 else {
            return nil
        }

        // Always have a deterministic fallback ready. Even if the AI
        // path fails, the user sees something grounded.
        let fallback = Self.deterministicProof(for: input)

        // M13: AI surfaces are English-only. Non-English locales get
        // the deterministic proof, no model call.
        guard await activeLocaleSupportsAI() else {
            if let fallback = fallback {
                cache[input.session.id] = fallback
                await persistToArchive(fallback, sessionID: input.session.id)
            }
            return fallback
        }

        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider)
        else {
            if let fallback = fallback {
                cache[input.session.id] = fallback
                await persistToArchive(fallback, sessionID: input.session.id)
            }
            return fallback
        }

        do {
            let body = requestBody(
                for: provider,
                prompt: Self.userPrompt(from: input),
                system: Self.systemPrompt(for: input.voice)
            )
            var request = URLRequest(url: endpoint)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 14
            switch provider {
            case .openAI, .deepSeek:
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            case .gemini:
                request.setGoogleAPIKey(key)
            case .none:
                if let fallback = fallback {
                    cache[input.session.id] = fallback
                    await persistToArchive(fallback, sessionID: input.session.id)
                }
                return fallback
            }
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let parsed = Self.parse(data: data, provider: provider, input: input)
            else {
                if let fallback = fallback {
                    cache[input.session.id] = fallback
                    await persistToArchive(fallback, sessionID: input.session.id)
                }
                return fallback
            }
            cache[input.session.id] = parsed
            await persistToArchive(parsed, sessionID: input.session.id)
            return parsed
        } catch {
            if let fallback = fallback {
                cache[input.session.id] = fallback
                await persistToArchive(fallback, sessionID: input.session.id)
            }
            return fallback
        }
    }

    /// Persist a generated proof to the per-account archive so the Ask
    /// Noum coach can quote the user's actual past words on later turns.
    /// Hops to MainActor — the archive is `@MainActor` to stay SwiftUI-
    /// safe for the upcoming Profile library card. Best-effort: a save
    /// failure never blocks the proof from reaching the calling UI.
    @MainActor
    private func persistToArchive(_ proof: ProofMoment, sessionID: UUID) {
        ProofMomentStore.shared.record(proof, for: sessionID)
    }

    /// Invalidate the cached proof for a session — call when a user
    /// pulls to refresh, or when the transcript is ever mutated post
    /// finalize (not currently a thing).
    func invalidate(sessionID: UUID) {
        cache.removeValue(forKey: sessionID)
    }

    // MARK: - Provider plumbing (mirrors AIInsightsService)

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

    private static func systemPrompt(for voice: SpeakingStyleGoal?) -> String {
        let voiceFrame: String
        if let voice = voice {
            voiceFrame = "The user is training their \(voice.title.lowercased()) voice — they want to \(voice.coachingDescription)."
        } else {
            voiceFrame = "The user has not set a voice yet; pick a technique that is generally good speaking."
        }
        return """
        You are a senior speaking coach. \(voiceFrame)

        Given the transcript of a single practice rep, find ONE short moment \
        (5–14 words) where the user demonstrated a real speaking technique. \
        Return strict JSON with three string keys:
        - "quote": a VERBATIM slice of the user's transcript, 5–14 words long. \
        Must appear in the transcript exactly as written (case-insensitive, \
        whitespace-flexible). Do not paraphrase. Do not invent.
        - "technique": a 1–3 word label for the technique, e.g. "Power Pause", \
        "Strip the Softeners", "BLUF", "Triad", "Declarative Close", \
        "Open-Ended Question", "Sensory Detail".
        - "claim": ONE coach-voice sentence (≤ 20 words) tying the technique \
        to the user's goal voice. No emoji, no exclamation marks, no chirpy \
        filler. Sentence case. End in a period.

        If the transcript shows no clear technique, return JSON with all \
        three keys empty: {"quote":"","technique":"","claim":""}.

        Only return the JSON object. No prose. No code fences.
        """
    }

    private static func userPrompt(from input: ProofMomentInput) -> String {
        var lines: [String] = []
        let s = input.session
        let day = Self.dayLabel(for: s.date)
        lines.append("Session day: \(day)")
        lines.append("Mode: \(s.mode.displayLabel)")
        if let score = s.score {
            lines.append("Score: \(score)/10")
        }
        lines.append("Filler count: \(s.fillerWordCount)")
        lines.append("Duration: \(Int(s.duration.rounded()))s")
        if let fillers = input.baselineFillerRate {
            lines.append("User's baseline filler rate: \(String(format: "%.1f", fillers))/min")
        }
        if let pace = input.baselinePace {
            lines.append("User's baseline pace: \(Int(pace.rounded())) WPM")
        }
        if let paraphrase = input.goalParaphrase, !paraphrase.isEmpty {
            lines.append("User's stated goal: \(paraphrase)")
        }
        lines.append("")
        lines.append("--- TRANSCRIPT (the only source for the quote) ---")
        lines.append(s.transcript)
        lines.append("--- END TRANSCRIPT ---")
        return lines.joined(separator: "\n")
    }

    private func requestBody(for provider: AIProvider, prompt: String, system: String) -> [String: Any] {
        switch provider {
        case .openAI, .deepSeek:
            return [
                "model": provider.model,
                "temperature": 0.4,
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
                    "temperature": 0.4,
                    "responseMimeType": "application/json"
                ]
            ]
        case .none:
            return [:]
        }
    }

    // MARK: - Parsing

    private static func parse(data: Data, provider: AIProvider, input: ProofMomentInput) -> ProofMoment? {
        guard let raw = Self.extractContent(from: data, provider: provider),
              let payload = Self.decodeJSON(from: raw) else {
            return nil
        }
        let quote = (payload["quote"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let technique = (payload["technique"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let claim = (payload["claim"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !quote.isEmpty, !technique.isEmpty, !claim.isEmpty else { return nil }
        // Guard against fabrication — the quote MUST appear in the
        // session's transcript (case-insensitive, whitespace-flexible).
        // If not, the model is hallucinating; fall through to template.
        guard transcriptContains(quote, in: input.session.transcript) else {
            return nil
        }
        return ProofMoment(
            quote: quote,
            technique: technique,
            claim: claim,
            sessionDate: input.session.date,
            isAIBacked: true,
            generatedAt: Date()
        )
    }

    private static func extractContent(from data: Data, provider: AIProvider) -> String? {
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

    private static func decodeJSON(from raw: String) -> [String: Any]? {
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

    // MARK: - Fabrication guard

    /// True when the candidate quote appears in the transcript with
    /// flexible whitespace + case-insensitive matching. Strict enough
    /// to catch real fabrication, loose enough that "you know" vs
    /// "you  know" doesn't accidentally fail. Internal so the test
    /// target can probe this directly.
    static func transcriptContains(_ candidate: String, in transcript: String) -> Bool {
        let normalize: (String) -> String = { input in
            input
                .lowercased()
                .replacingOccurrences(of: "\u{2019}", with: "'")
                .replacingOccurrences(of: "\u{201C}", with: "\"")
                .replacingOccurrences(of: "\u{201D}", with: "\"")
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        let n1 = normalize(candidate)
        let n2 = normalize(transcript)
        guard !n1.isEmpty else { return false }
        return n2.contains(n1)
    }

    // MARK: - Deterministic fallback

    /// Template proof for the offline / no-provider path. Picks a quote
    /// from the transcript by heuristic: the longest "thought" (sentence
    /// or comma-separated clause) under 14 words. Pairs it with a
    /// voice-specific technique label + claim. Always renders something
    /// useful — the AI version is just sharper.
    static func deterministicProof(for input: ProofMomentInput) -> ProofMoment? {
        let s = input.session
        let candidate = longestThought(in: s.transcript, maxWords: 14)
        guard let quote = candidate, !quote.isEmpty else { return nil }

        let mapping = templateMapping(for: input.voice, session: s)
        guard let mapping = mapping else { return nil }

        return ProofMoment(
            quote: quote,
            technique: mapping.technique,
            claim: mapping.claim,
            sessionDate: s.date,
            isAIBacked: false,
            generatedAt: Date()
        )
    }

    /// Pick the longest clause in the transcript that fits in maxWords.
    /// We prefer sentences over comma-clauses, and skip the very first
    /// word if it's a filler ("um," / "uh,"). Returns nil if no clause
    /// qualifies (transcript is short or noise-only).
    private static func longestThought(in transcript: String, maxWords: Int) -> String? {
        let cleaned = transcript
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\u{2019}", with: "'")
        // Split on terminal punctuation first; fall back to commas if
        // the rep has no sentence boundaries.
        var pieces = cleaned
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        if pieces.isEmpty {
            pieces = cleaned
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
        }
        let qualified = pieces.compactMap { piece -> String? in
            let words = piece.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            guard words.count >= 4, words.count <= maxWords else { return nil }
            return words.joined(separator: " ")
        }
        return qualified.max(by: { $0.count < $1.count })
    }

    /// Voice-specific (technique, claim) for the deterministic path.
    /// The score / filler count drive which lever we frame the proof
    /// around — e.g. a clean rep gets "Filler-Free Run", a long rep
    /// gets "Sustained Composure", etc.
    private static func templateMapping(
        for voice: SpeakingStyleGoal?,
        session s: PracticeSession
    ) -> (technique: String, claim: String)? {
        let cleanRep = s.fillerWordCount == 0 && s.duration >= 20
        let strongRep = (s.score ?? 0) >= 8
        let longRep = s.duration >= 45

        switch voice {
        case .authoritative:
            if cleanRep {
                return ("Declarative Close", "That's a clean, certain line. Authority reads as commitment, and you committed.")
            } else if strongRep {
                return ("Steady Frame", "You held the frame. That's how authority shows up — without rushing or hedging.")
            } else if longRep {
                return ("Sustained Voice", "You held the room for the full duration. Authority is endurance.")
            } else {
                return ("Direct Move", "A direct claim, no softeners. That's the authoritative move.")
            }
        case .warm:
            if cleanRep {
                return ("Open Delivery", "Calm, unhurried. That reads as warmth — you let the listener in.")
            } else {
                return ("Personal Anchor", "You spoke from a real place. Warmth lives in specifics, not platitudes.")
            }
        case .concise:
            if cleanRep || strongRep {
                return ("BLUF", "Bottom line up front. Crisp. That's concision earning its keep.")
            } else {
                return ("Trim Move", "You cut to the point. The next move is doing it in one fewer word.")
            }
        case .persuasive:
            if strongRep {
                return ("Structured Claim", "Premise, evidence, recommendation — in that order. That's a persuasive frame.")
            } else if longRep {
                return ("Argument Arc", "You held the through-line. Persuasion is about not losing the thread.")
            } else {
                return ("Anchor Phrase", "A clear claim to hang the rest on. That's the move persuasion needs first.")
            }
        case .executive:
            if cleanRep || strongRep {
                return ("Top-Line First", "You led with the verdict. That's executive presence in one move.")
            } else {
                return ("Composed Delivery", "Steady, no rush. Executive register is calm under attention — you had it.")
            }
        case .storytelling:
            if longRep {
                return ("Scene Set", "You painted the scene. Stories live in the specifics you chose to surface.")
            } else if strongRep {
                return ("Vivid Choice", "A specific image, not an abstraction. That's the storytelling move.")
            } else {
                return ("Anchor Detail", "One concrete detail. That's the foundation a story needs.")
            }
        case .none:
            if cleanRep {
                return ("Clean Rep", "No fillers across the full duration. That's a solid baseline move.")
            } else if strongRep {
                return ("Strong Delivery", "A high-score rep — the moves you made this time hold up.")
            } else {
                return ("Forward Motion", "A real attempt at the move. Repetition turns this into instinct.")
            }
        }
    }

    /// Compact day label used in the user prompt + UI ("Today", "Wed",
    /// "Apr 14"). Same shape `CoachContextBuilder` uses for symmetry.
    private static func dayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let now = Date()
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if days < 7 {
            let f = DateFormatter()
            f.dateFormat = "EEE"
            return f.string(from: date)
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}
