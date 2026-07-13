import Foundation

// MARK: - AI Rewrite Service (Pro)
//
// Takes the user's actual transcript + the specific weakness category +
// observable signals about their voice (sentence length, vocabulary
// shape, contraction usage), and returns a rewritten version of the
// **weak section only** — preserving the rest of the user's voice.
//
// The defining design constraint, per direct user feedback during M14
// real-device QA: "don't want them to learn how to speak like
// chatgpt/AI right, THIS IS VERY IMPORTANT."
//
// What that means in practice for the prompt:
//   • Re-use the user's vocabulary set wherever possible. If they said
//     "kind of" three times, the rewrite is allowed to say "kind of" too.
//     If they didn't say "leverage", the rewrite must not say "leverage".
//   • Match their sentence rhythm. Average sentence length stays close
//     to theirs; we don't turn a clipped speaker into a flowing one.
//   • Keep contractions if they used contractions ("I'm", "don't").
//   • Don't add corporate jargon the user didn't use ("strategic",
//     "leverage", "synergize", "value-add", "stakeholder", "ecosystem").
//   • Output is ONE replacement sentence/clause for the targeted weak
//     section — not a rewrite of the whole rep.
//
// Same provider plumbing as GoalParaphraseService / AIPromptGeneratorService:
// reads `AISettingsManager.activeProvider`, falls back silently when
// no provider is configured.
//
// Pro gating happens at the call site, not in this service — keeps the
// service reusable for future surfaces.

actor AIRewriteService {
    typealias ProviderResolver = @MainActor @Sendable () -> AIProvider?

    static let shared = AIRewriteService()

    private let providerResolver: ProviderResolver

    /// Provider resolution is injectable so locale-boundary tests can prove
    /// unsupported locales stop before provider configuration or transport is
    /// touched. Production continues to read the existing settings owner.
    init(
        providerResolver: @escaping ProviderResolver = {
            AISettingsManager.shared.activeProvider
        }
    ) {
        self.providerResolver = providerResolver
    }

    /// Rewrite register is optional coaching context, never an inferred
    /// identity. The profile's effective style has a legacy fallback so older
    /// screens can render; only an explicit choice is safe to inject into a
    /// user-facing rewrite prompt.
    nonisolated static func selectedVoice(from profile: CoachingProfile?) -> SpeakingStyleGoal? {
        profile?.chosenStyleGoal
    }

    enum Weakness: String, Sendable, Codable {
        case opening
        case closing
        case structure
        case concise

        var humanLabel: String {
            switch self {
            case .opening:   return "opening"
            case .closing:   return "closing"
            case .structure: return "structure"
            case .concise:   return "tightening"
            }
        }

        /// Specific instruction the model gets about what to fix.
        var fixInstruction: String {
            switch self {
            case .opening:
                return "Rewrite ONLY the user's opening (first 1-2 sentences). The rest of the rep stays untouched. Make the opening declarative — replace tentative starts ('I think maybe', 'so basically') with a confident first sentence that uses the user's own words and arrives at the point in 8-12 words."
            case .closing:
                return "Rewrite ONLY the user's closing (last 1-2 sentences). The rest stays untouched. Make the close land — replace trail-off endings ('and yeah', 'so that's it') with a deliberate final sentence in 8-12 words. The close should restate the point, not introduce new ideas."
            case .structure:
                return "Rewrite the rep with light structural anchors — add one transition phrase the user didn't use originally (e.g., 'the second thing', 'here's why'), without otherwise changing their words. Preserve their exact sentences; insert at most one short connective."
            case .concise:
                return "Cut the rep down by 30-40% by removing redundant phrasing the user repeated, hedging language ('kind of', 'sort of', 'just'), and filler words. Keep every original idea. Use only words the user actually said."
            }
        }
    }

    /// The amount of editorial movement a user asks the rewrite to make.
    /// It controls arrangement and directness, never whether their intent or
    /// vocabulary is preserved. The medium option retains the original
    /// behavior for callers that have not yet exposed the control.
    enum Intensity: String, CaseIterable, Codable, Sendable {
        case light
        case medium
        case strong

        var title: String {
            switch self {
            case .light: return "Light"
            case .medium: return "Medium"
            case .strong: return "Strong"
            }
        }

        var instruction: String {
            switch self {
            case .light:
                return "Make the smallest useful edit. Preserve the user's sentence shape whenever possible and change only the words that block the target."
            case .medium:
                return "Make a clear, practical edit while preserving the user's wording, rhythm, and meaning."
            case .strong:
                return "Make the clearest version that still sounds like this user. You may reorder the targeted slice, but do not add a new claim, example, or point."
            }
        }
    }

    enum Eligibility: Equatable, Sendable {
        case eligible
        case unsupportedLocale
        case tooShort
        case lowConfidence
        case semanticallyAmbiguous
        case containsSensitiveIdentifier
    }

    /// Conservative, deterministic gate used by both the surface and service.
    /// A rewrite is optional coaching depth, so withholding it is safer than
    /// uploading a fragment, garbled recognition, or likely personal identifier.
    nonisolated static func eligibility(
        transcript: String,
        confidence: Double?,
        locale: PracticeLocale = .enUS
    ) -> Eligibility {
        guard locale.aiSupported else { return .unsupportedLocale }
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 40 else { return .tooShort }
        guard confidence.map({ $0 >= 0.55 }) ?? true else { return .lowConfidence }

        let sensitivePatterns = [
            #"[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}"#,
            #"(?:\+?\d[\s().-]*){8,}"#,
            #"\b\d{3}[- ]?\d{2}[- ]?\d{4}\b"#
        ]
        if sensitivePatterns.contains(where: {
            trimmed.range(of: $0, options: [.regularExpression, .caseInsensitive]) != nil
        }) {
            return .containsSensitiveIdentifier
        }

        let words = trimmed.lowercased().split(whereSeparator: { !$0.isLetter })
        guard words.count >= 8 else { return .semanticallyAmbiguous }
        let distinct = Set(words)
        guard distinct.count >= 5,
              Double(distinct.count) / Double(words.count) >= 0.30 else {
            return .semanticallyAmbiguous
        }
        return .eligible
    }

    // MARK: - Public API

    /// Generate a rewritten version of the targeted weak section.
    /// Returns nil if no provider is configured, the call fails, the
    /// content filter rejects the output, or the rewrite drifts too
    /// far from the user's original voice.
    ///
    /// `voice` (optional) injects the per-voice register clause so the
    /// rewrite drifts toward the user's voice goal while still anchored
    /// to their actual vocabulary signals. nil = no voice context (the
    /// rewrite still preserves the user's voice via VoiceSignals; the
    /// voice register only colours register, not vocabulary).
    func rewrite(
        transcript: String,
        weakness: Weakness,
        voice: SpeakingStyleGoal? = nil,
        targetDimension: String? = nil,
        transcriptConfidence: Double? = nil,
        intensity: Intensity = .medium,
        locale: PracticeLocale? = nil
    ) async -> Rewrite? {
        func record(
            _ outcome: AICallDiagnosticOutcome,
            _ reason: String,
            provider: AIProvider? = nil,
            statusCode: Int? = nil,
            startedAt: Date? = nil
        ) {
            AICallDiagnostics.record(
                surface: "Rewrite suggestion",
                provider: provider,
                outcome: outcome,
                reason: reason,
                statusCode: statusCode,
                startedAt: startedAt
            )
        }

        let effectiveLocale = if let locale {
            locale
        } else {
            await currentLocale()
        }
        guard effectiveLocale.aiSupported else {
            record(.skipped, "Locale not AI-supported")
            return nil
        }

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.eligibility(
            transcript: trimmed,
            confidence: transcriptConfidence,
            locale: effectiveLocale
        ) == .eligible else {
            record(.skipped, "Transcript failed deterministic rewrite eligibility")
            return nil
        }
        let onDeviceFallback = Self.onDeviceRewrite(
            transcript: trimmed,
            weakness: weakness,
            voice: voice,
            intensity: intensity,
            confidence: transcriptConfidence,
            locale: effectiveLocale
        )
        let configuredProvider = await currentProvider()
        guard let provider = configuredProvider,
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider) else {
            record(
                onDeviceFallback == nil ? .skipped : .fallback,
                configuredProvider == nil ? "No active provider; using on-device rewrite when safe" : "Missing key or endpoint; using on-device rewrite when safe",
                provider: configuredProvider
            )
            return onDeviceFallback
        }

        let signals = VoiceSignals.compute(transcript: trimmed)
        let userPrompt = buildUserPrompt(
            transcript: trimmed,
            weakness: weakness,
            signals: signals,
            targetDimension: targetDimension
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 12

        do {
            switch provider {
            case .none:
                record(.skipped, "Provider set to off", provider: provider)
                return nil
            case .openAI, .deepSeek:
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                let body: [String: Any] = [
                    "model": provider.model,
                    "temperature": 0.5,  // lower than prompt-gen — we want fidelity, not creativity
                    "messages": [
                        ["role": "system", "content": Self.systemPrompt(for: weakness, voice: voice, intensity: intensity)],
                        ["role": "user", "content": userPrompt]
                    ]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            case .gemini:
                request.setGoogleAPIKey(key)
                let body: [String: Any] = [
                    "systemInstruction": ["parts": [["text": Self.systemPrompt(for: weakness, voice: voice, intensity: intensity)]]],
                    "contents": [["role": "user", "parts": [["text": userPrompt]]]],
                    "generationConfig": [
                        "temperature": 0.5,
                        "thinkingConfig": ["thinkingBudget": 0]
                    ]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }

            let startedAt = Date()
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                let statusCode = (response as? HTTPURLResponse)?.statusCode
                record(
                    .fallback,
                    statusCode.map { "Provider returned HTTP \($0)" } ?? "Non-HTTP response",
                    provider: provider,
                    statusCode: statusCode,
                    startedAt: startedAt
                )
                return onDeviceFallback
            }
            guard let raw = decodeText(from: data, provider: provider) else {
                record(.fallback, "Missing response content", provider: provider, statusCode: http.statusCode, startedAt: startedAt)
                return onDeviceFallback
            }
            guard let cleaned = RewriteContentFilter.accept(raw, signals: signals) else {
                record(.fallback, "Rewrite failed voice-preservation filter", provider: provider, statusCode: http.statusCode, startedAt: startedAt)
                return onDeviceFallback
            }
            guard RewriteSemanticGuard.preservesMeaning(
                originalTranscript: trimmed,
                candidate: cleaned,
                weakness: weakness
            ) else {
                record(.fallback, "Rewrite failed semantic-preservation guard", provider: provider, statusCode: http.statusCode, startedAt: startedAt)
                return onDeviceFallback
            }
            record(.success, "Rewrite accepted", provider: provider, statusCode: http.statusCode, startedAt: startedAt)
            return Rewrite(text: cleaned, weakness: weakness, intensity: intensity)
        } catch {
            record(.failure, "Transport or decode error", provider: provider)
            return onDeviceFallback
        }
    }

    /// Conservative, deterministic rewrite for a no-provider or failed-provider
    /// path. It only removes transcript-derived disfluencies, duplicate words,
    /// and context-free lead-ins; it never adds vocabulary or a new claim.
    /// Returning nil is intentional when no safe edit can be made.
    nonisolated static func onDeviceRewrite(
        transcript: String,
        weakness: Weakness,
        voice: SpeakingStyleGoal?,
        intensity: Intensity,
        confidence: Double? = nil,
        locale: PracticeLocale = .enUS
    ) -> Rewrite? {
        guard eligibility(
            transcript: transcript,
            confidence: confidence,
            locale: locale
        ) == .eligible,
              let candidate = OnDeviceRewriteHeuristics.rewrite(
                  transcript: transcript,
                  weakness: weakness,
                  voice: voice,
                  intensity: intensity
              ),
              let cleaned = RewriteContentFilter.accept(
                  candidate,
                  signals: VoiceSignals.compute(transcript: transcript)
              ) else {
            return nil
        }
        return Rewrite(
            text: cleaned,
            weakness: weakness,
            intensity: intensity,
            source: .onDevice
        )
    }

    // MARK: - Prompts

    /// Exposed `static` + `internal` so the test suite can assert that
    /// the voice register clause is present per voice.
    static func systemPrompt(
        for weakness: Weakness,
        voice: SpeakingStyleGoal?,
        intensity: Intensity = .medium
    ) -> String {
        let voiceRegister = voiceRegisterClause(for: voice)
        return """
        You are a speaking coach who rewrites a small slice of a user's transcript to fix a specific weakness — without making them sound like a different person. The user's existing voice is the asset; you protect it. The user is also training a specific voice goal — you nudge the rewrite toward that goal while keeping their vocabulary intact.

        \(voiceRegister)

        Hard rules:
        1. Use the user's own words. Pull from the vocabulary the user actually used in their transcript. Do not introduce jargon, buzzwords, or corporate phrasing the user did not use ("leverage", "ecosystem", "stakeholder", "value-add", "strategic", "synergy", "actionable", "disrupt", "robust", "scalable").
        2. Match their cadence. Stay within ±25% of the user's average sentence length. If they speak in short sentences, you write short sentences.
        3. Match their formality. If they use contractions, you use contractions. If they use casual fillers like "kind of", you can keep them where they actually help.
        4. Fix only the targeted slice. Do not rewrite the whole rep. Do not generalise the topic. Stay on the exact subject the user was talking about.
        5. Voice nudge takes second place to vocabulary fidelity. The voice register colours how you arrange the words, never which words you use.
        6. Rewrite strength: \(intensity.instruction)
        7. \(weakness.fixInstruction)
        8. Preserve factual meaning exactly: keep negation polarity, every numeric fact (including currency and percentages), and every named person, organisation, product, place, or acronym in the targeted slice unchanged.
        9. Output ONLY the rewritten slice. No preface, no explanation, no quotes. Plain text. 8-26 words maximum.
        """
    }

    /// Per-voice register line for the rewrite system prompt. Mirrors the
    /// authoritative=verdict, warm=mentor, concise=clipped, persuasive=
    /// premise→evidence, executive=chief-of-staff, storytelling=arcs pattern
    /// in `CoachContextBuilder`. The rewrite moves *toward* the user's voice
    /// goal — never overshoots into a different person.
    static func voiceRegisterClause(for voice: SpeakingStyleGoal?) -> String {
        switch voice {
        case .authoritative:
            return "Voice the user is training: authoritative. Rewrite leans declarative — no hedging, no rising endings."
        case .warm:
            return "Voice the user is training: warm. Rewrite keeps a felt, human edge — soft warmth, not saccharine."
        case .concise:
            return "Voice the user is training: concise. Rewrite cuts filler, favours short sentences, skips preamble."
        case .persuasive:
            return "Voice the user is training: persuasive. Rewrite arranges premise → evidence → point."
        case .executive:
            return "Voice the user is training: executive. Rewrite leads with the top line, then one short support."
        case .storytelling:
            return "Voice the user is training: storytelling. Rewrite shapes the slice with scene, move, meaning."
        case .none:
            return "Voice the user is training: not set. Rewrite stays calm and direct."
        }
    }

    private func buildUserPrompt(
        transcript: String,
        weakness: Weakness,
        signals: VoiceSignals,
        targetDimension: String?
    ) -> String {
        var lines: [String] = []
        lines.append("Original transcript:")
        lines.append("---")
        if let targetDimension,
           !targetDimension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("Coaching target: \(String(targetDimension.prefix(80)))")
        }
        lines.append(transcript)
        lines.append("---")
        lines.append("")
        lines.append("Voice signals (preserve these):")
        lines.append("- Avg sentence length: \(signals.avgSentenceLength) words")
        lines.append("- Uses contractions: \(signals.usesContractions ? "yes" : "no")")
        lines.append("- Uses hedging ('kind of', 'sort of'): \(signals.usesHedging ? "yes" : "no")")
        lines.append("- First-person heavy: \(signals.firstPersonHeavy ? "yes" : "no")")
        if !signals.distinctiveWords.isEmpty {
            lines.append("- Words they actually used to convey the point: \(signals.distinctiveWords.joined(separator: ", "))")
        }
        lines.append("")
        lines.append("Now rewrite the \(weakness.humanLabel) only. Plain text. No preface.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Provider plumbing (same pattern as GoalParaphraseService)

    @MainActor
    private func currentProvider() -> AIProvider? {
        providerResolver()
    }

    @MainActor
    private func currentLocale() -> PracticeLocale {
        LocaleSettingsManager.shared.current
    }

    private func apiKey(for provider: AIProvider) -> String? {
        AIProviderCredential.apiKey(for: provider)
    }

    private func decodeText(from data: Data, provider: AIProvider) -> String? {
        switch provider {
        case .none: return nil
        case .openAI, .deepSeek:
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = object["choices"] as? [[String: Any]],
                  let first = choices.first,
                  let message = first["message"] as? [String: Any],
                  let content = message["content"] as? String else { return nil }
            return content
        case .gemini:
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = object["candidates"] as? [[String: Any]],
                  let first = candidates.first,
                  let content = first["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]] else { return nil }
            return parts.compactMap { $0["text"] as? String }.joined(separator: " ")
        }
    }
}

// MARK: - Output type

struct Rewrite: Sendable, Equatable {
    enum Source: String, Sendable, Equatable {
        case provider
        case onDevice
    }

    let text: String
    let weakness: AIRewriteService.Weakness
    let intensity: AIRewriteService.Intensity
    let source: Source

    init(
        text: String,
        weakness: AIRewriteService.Weakness,
        intensity: AIRewriteService.Intensity,
        source: Source = .provider
    ) {
        self.text = text
        self.weakness = weakness
        self.intensity = intensity
        self.source = source
    }
}

// MARK: - On-device rewrite fallback

/// This is deliberately narrower than the provider-backed rewrite. It avoids
/// treating semantic hedges or a distinctive speaking rhythm as "filler" and
/// only makes a suggestion when a textual edit is clearly safe.
private enum OnDeviceRewriteHeuristics {
    static func rewrite(
        transcript: String,
        weakness: AIRewriteService.Weakness,
        voice: SpeakingStyleGoal?,
        intensity: AIRewriteService.Intensity
    ) -> String? {
        let source = targetSlice(from: transcript, weakness: weakness)
        guard !source.isEmpty else { return nil }

        var candidate = source
        candidate = removeDisfluencies(from: candidate)
        candidate = collapseImmediateDuplicates(in: candidate)

        if intensity != .light {
            candidate = removeContextFreeLeadIn(from: candidate)
            if weakness == .closing {
                candidate = removeContextFreeClosing(from: candidate)
            }
        }

        if intensity == .strong,
           directnessGoal(voice),
           weakness == .opening || weakness == .closing {
            candidate = removeDirectnessHedge(from: candidate)
        }

        if weakness == .structure, intensity != .light {
            candidate = moveMostInformativeSentenceFirst(in: candidate)
        }

        candidate = normalizedSentence(candidate)
        guard meaningfullyDiffers(candidate, from: source) else { return nil }
        return candidate
    }

    private static func targetSlice(
        from transcript: String,
        weakness: AIRewriteService.Weakness
    ) -> String {
        let sentences = transcript
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !sentences.isEmpty else { return "" }

        switch weakness {
        case .opening:
            return Array(sentences.prefix(2)).joined(separator: ". ")
        case .closing:
            return Array(sentences.suffix(2)).joined(separator: ". ")
        case .structure, .concise:
            return Array(sentences.prefix(2)).joined(separator: ". ")
        }
    }

    private static func removeDisfluencies(from value: String) -> String {
        value.replacingOccurrences(
            of: #"\b(?:um+|uh+|erm|er|ah+)\b[,.\s]*"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private static func collapseImmediateDuplicates(in value: String) -> String {
        let words = value.split(whereSeparator: { $0.isWhitespace })
        var result: [String] = []
        for word in words {
            let normalized = word
                .lowercased()
                .trimmingCharacters(in: .punctuationCharacters)
            if let previous = result.last,
               previous.lowercased().trimmingCharacters(in: .punctuationCharacters) == normalized,
               !normalized.isEmpty {
                continue
            }
            result.append(String(word))
        }
        return result.joined(separator: " ")
    }

    private static func removeContextFreeLeadIn(from value: String) -> String {
        value.replacingOccurrences(
            of: #"^\s*(?:so|well|okay|ok|right|basically|actually)[,\s]+"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private static func removeContextFreeClosing(from value: String) -> String {
        value.replacingOccurrences(
            of: #"(?:[,\s]+(?:and\s+)?yeah|[,\s]+so\s+yeah)\.?\s*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private static func removeDirectnessHedge(from value: String) -> String {
        value.replacingOccurrences(
            of: #"^\s*(?:i\s+(?:think|guess)\s+|maybe\s+|probably\s+)"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
    }

    private static func directnessGoal(_ voice: SpeakingStyleGoal?) -> Bool {
        switch voice {
        case .authoritative, .executive, .persuasive:
            return true
        default:
            return false
        }
    }

    private static func moveMostInformativeSentenceFirst(in value: String) -> String {
        var sentences = value
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard sentences.count > 1 else { return value }

        let bestIndex = sentences.indices.max { lhs, rhs in
            informationScore(sentences[lhs]) < informationScore(sentences[rhs])
        } ?? sentences.startIndex
        let best = sentences.remove(at: bestIndex)
        return ([best] + sentences).joined(separator: ". ")
    }

    private static func informationScore(_ value: String) -> Int {
        value.split(whereSeparator: { !$0.isLetter }).reduce(into: 0) { score, word in
            if word.count >= 4 { score += 1 }
        }
    }

    private static func normalizedSentence(_ value: String) -> String {
        let collapsed = value
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
        guard !collapsed.isEmpty else { return "" }
        return collapsed + "."
    }

    private static func meaningfullyDiffers(_ candidate: String, from original: String) -> Bool {
        normalizedComparison(candidate) != normalizedComparison(original)
    }

    private static func normalizedComparison(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}

// MARK: - Voice signals

/// Observable signals about how the user actually speaks, derived from
/// their transcript. Fed to the rewrite prompt so the model anchors on
/// the user's voice instead of regressing to an LLM "default voice."
struct VoiceSignals: Sendable {
    let avgSentenceLength: Int
    let usesContractions: Bool
    let usesHedging: Bool
    let firstPersonHeavy: Bool
    let distinctiveWords: [String]

    static let empty = VoiceSignals(
        avgSentenceLength: 0,
        usesContractions: false,
        usesHedging: false,
        firstPersonHeavy: false,
        distinctiveWords: []
    )

    static func compute(transcript: String) -> VoiceSignals {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        // Sentences split on terminal punctuation.
        let sentences = trimmed
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Words split on whitespace + punctuation that isn't an apostrophe.
        let words = trimmed
            .split(whereSeparator: { !$0.isLetter && $0 != "'" })
            .map { String($0).lowercased() }

        let avgLen: Int = {
            guard !sentences.isEmpty else { return words.count }
            let lengths = sentences.map { $0.split(whereSeparator: { !$0.isLetter && $0 != "'" }).count }
            return max(1, lengths.reduce(0, +) / lengths.count)
        }()

        let contractionMarkers: Set<String> = ["i'm", "don't", "can't", "won't", "it's", "you're", "they're", "we're", "i've", "i'll", "that's", "there's", "what's", "didn't", "isn't", "wasn't", "haven't"]
        let usesContractions = words.contains(where: { contractionMarkers.contains($0) })

        let hedgingPhrases = ["kind", "sort", "maybe", "probably", "i guess", "i think"]
        let usesHedging = hedgingPhrases.contains(where: { trimmed.lowercased().contains($0) })

        let firstPersonCount = words.filter { $0 == "i" || $0 == "me" || $0 == "my" || $0 == "i'm" || $0 == "i've" || $0 == "i'll" }.count
        let firstPersonHeavy = words.count >= 20 && (Double(firstPersonCount) / Double(words.count)) >= 0.06

        // Pull out content words (≥6 chars, non-stop) that the user
        // actually used. The model uses these as a vocabulary anchor.
        let stopWords: Set<String> = ["because", "really", "actually", "everything", "something", "nothing", "anything", "people", "though", "before", "always", "around", "between", "without", "another"]
        let distinctiveSorted: [String] = Array(Set(words.filter { $0.count >= 6 && !stopWords.contains($0) })).sorted()
        let distinctive: [String] = Array(distinctiveSorted.prefix(8))

        return VoiceSignals(
            avgSentenceLength: avgLen,
            usesContractions: usesContractions,
            usesHedging: usesHedging,
            firstPersonHeavy: firstPersonHeavy,
            distinctiveWords: distinctive
        )
    }
}

// MARK: - Content Filter

/// Rejects model output that drifts from the user's voice or produces
/// off-brand text. Fully deterministic — testable without hitting the
/// network.
enum RewriteContentFilter {
    /// List of corporate / AI-default words that signal the model
    /// regressed to its house style. If the rewrite contains any of
    /// these AND the user didn't, we reject the output. The user's
    /// quote: "don't want them to learn how to speak like chatgpt/AI".
    static let aiTellWords: Set<String> = [
        "leverage", "leveraging", "ecosystem", "stakeholder", "stakeholders",
        "value-add", "value add", "strategic", "synergy", "synergize",
        "actionable", "actionables", "disrupt", "disruptive", "robust",
        "scalable", "innovate", "innovative", "paradigm", "holistic",
        "synergistic", "deliverables", "bandwidth", "circle back",
        "deep dive", "double click", "north star", "best-in-class",
        "world-class", "moving forward", "going forward", "at the end of the day"
    ]

    /// Min/max characters for an acceptable rewrite slice.
    static let minLength = 18
    static let maxLength = 220

    /// Returns the cleaned rewrite if it passes all filters. nil otherwise.
    static func accept(_ raw: String, signals: VoiceSignals) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip enclosing quotes / smart quotes.
        if (text.hasPrefix("\"") && text.hasSuffix("\"")) ||
           (text.hasPrefix("\u{201C}") && text.hasSuffix("\u{201D}")) {
            if text.count >= 2 { text = String(text.dropFirst().dropLast()) }
        }

        // Collapse whitespace.
        text = text.replacingOccurrences(of: "\n", with: " ")
        while text.contains("  ") { text = text.replacingOccurrences(of: "  ", with: " ") }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard (minLength...maxLength).contains(text.count) else { return nil }

        // AI-tell check: if the rewrite contains corporate jargon AND the
        // user didn't, reject.
        let lowered = text.lowercased()
        for tell in aiTellWords where lowered.contains(tell) {
            // OK to keep if the user actually said it themselves.
            if !signals.distinctiveWords.contains(tell) {
                return nil
            }
        }

        // If the user uses contractions and the model dropped them, the
        // rewrite reads more formal than them. Reject.
        if signals.usesContractions {
            let hasAnyContraction = lowered.contains("'")
            if !hasAnyContraction { return nil }
        }

        return text
    }
}

// MARK: - Semantic preservation

/// Source-aware validation for provider rewrites. Prompt instructions are not
/// evidence that a model obeyed them, so high-confidence meaning anchors are
/// checked again before provider text can reach the user. The guard stays
/// deliberately narrow: it does not attempt general semantic similarity and
/// therefore does not penalise legitimate reordering, tightening, or cadence
/// changes across the light / medium / strong rewrite intensities.
enum RewriteSemanticGuard {
    static func preservesMeaning(
        originalTranscript: String,
        candidate: String,
        weakness: AIRewriteService.Weakness
    ) -> Bool {
        let source = targetSlice(from: originalTranscript, weakness: weakness)
        guard !source.isEmpty, !candidate.isEmpty else { return false }

        return negationSignature(in: source) == negationSignature(in: candidate)
            && numericFacts(in: source) == numericFacts(in: candidate)
            && preservesEntityAnchors(source: source, candidate: candidate)
    }

    /// Opening and closing rewrites operate on the same bounded section named
    /// in their prompt. Structure and concision are whole-rep transformations,
    /// so every high-signal fact in the source remains part of their contract.
    private static func targetSlice(
        from transcript: String,
        weakness: AIRewriteService.Weakness
    ) -> String {
        let sentences = sentences(in: transcript)
        guard !sentences.isEmpty else { return "" }

        switch weakness {
        case .opening:
            return Array(sentences.prefix(2)).joined(separator: ". ")
        case .closing:
            return Array(sentences.suffix(2)).joined(separator: ". ")
        case .structure, .concise:
            return transcript
        }
    }

    /// Keeps decimal points inside numeric facts while still bounding opening
    /// and closing slices. A character scan is more predictable here than
    /// splitting on every period (`$1.25 million` must remain one fact).
    private static func sentences(in text: String) -> [String] {
        var result: [String] = []
        var start = text.startIndex
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let next = text.index(after: index)
            let isDecimalPoint: Bool = {
                guard character == ".", index > text.startIndex, next < text.endIndex else {
                    return false
                }
                return text[text.index(before: index)].isNumber && text[next].isNumber
            }()

            if ".!?".contains(character), !isDecimalPoint {
                let sentence = String(text[start...index]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !sentence.isEmpty { result.append(sentence) }
                start = next
            }
            index = next
        }

        if start < text.endIndex {
            let remainder = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !remainder.isEmpty { result.append(remainder) }
        }
        return result
    }

    /// Contractions and their expanded `not` form share one signature so a
    /// stylistic edit such as “didn't” → “did not” is accepted. Stronger
    /// negative terms stay distinct because “never” and “not” are not factual
    /// equivalents.
    private static func negationSignature(in text: String) -> [String: Int] {
        var signature: [String: Int] = [:]
        for token in lexicalTokens(in: text) {
            let lowered = token.value
                .lowercased()
                .replacingOccurrences(of: "’", with: "'")
                .trimmingCharacters(in: .punctuationCharacters)
            let marker: String?
            if lowered.hasSuffix("n't") || lowered == "cannot" || lowered == "not" {
                marker = "not"
            } else if ["never", "no", "none", "neither", "nor", "without"].contains(lowered) {
                marker = lowered
            } else {
                marker = nil
            }
            if let marker { signature[marker, default: 0] += 1 }
        }
        return signature
    }

    /// Literal numeric anchors are normalized across harmless formatting
    /// changes (`92%` / `92 percent`, `$1,250` / `$ 1,250`). Currency and
    /// magnitude remain part of the identity, so dropping `$` or changing
    /// `million` is rejected rather than treated as cosmetic.
    private static func numericFacts(in text: String) -> Set<String> {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return Set(numericRegex.matches(in: text, range: range).compactMap { match in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            return normalizedNumericFact(String(text[matchRange]))
        })
    }

    private static func normalizedNumericFact(_ raw: String) -> String {
        var value = raw
            .lowercased()
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)

        var currency = ""
        let currencies: [(markers: [String], canonical: String)] = [
            (["$", "dollar", "dollars"], "usd"),
            (["£", "pound", "pounds"], "gbp"),
            (["€", "euro", "euros"], "eur"),
            (["¥", "yen"], "yen")
        ]
        for entry in currencies where entry.markers.contains(where: value.contains) {
            currency = entry.canonical
            for marker in entry.markers {
                value = value.replacingOccurrences(of: marker, with: "")
            }
            break
        }

        var unit = ""
        if value.hasSuffix("percent") {
            value.removeLast("percent".count)
            unit = "percent"
        } else if value.hasSuffix("%") {
            value.removeLast()
            unit = "percent"
        }

        let magnitudes: [(markers: [String], canonical: String)] = [
            (["thousand", "k"], "thousand"),
            (["million", "m"], "million"),
            (["billion", "b"], "billion")
        ]
        var magnitude = ""
        for entry in magnitudes {
            if let marker = entry.markers.first(where: value.hasSuffix) {
                value.removeLast(marker.count)
                magnitude = entry.canonical
                break
            }
        }

        return [currency, value, magnitude, unit].joined(separator: "|")
    }

    /// Names are intentionally heuristic rather than an invented NLP stack.
    /// Acronyms, mixed-case/product tokens, letter-number labels, and
    /// non-initial title-case words (including multi-word name continuations)
    /// are high-signal enough to require exact case-insensitive preservation.
    /// Ordinary sentence-start capitalization remains free to change.
    private static func preservesEntityAnchors(source: String, candidate: String) -> Bool {
        let sourceAnchors = entityLikeTokens(in: source)
        let candidateAnchors = entityLikeTokens(in: candidate)
        let sourceWords = canonicalWords(in: source)
        let candidateWords = canonicalWords(in: candidate)
        return sourceAnchors.isSubset(of: candidateWords)
            && candidateAnchors.isSubset(of: sourceWords)
    }

    private static func entityLikeTokens(in text: String) -> Set<String> {
        let tokens = lexicalTokens(in: text)
        var result: Set<String> = []

        for token in tokens {
            let letters = token.value.unicodeScalars.filter(CharacterSet.letters.contains)
            let hasLowercase = letters.contains(where: CharacterSet.lowercaseLetters.contains)
            let uppercaseCount = letters.filter(CharacterSet.uppercaseLetters.contains).count
            let isAcronym = letters.count >= 2 && uppercaseCount == letters.count
            let isMixedCase = hasLowercase && uppercaseCount > 0 && !token.isTitleCase
            let isLetterNumberLabel = token.value.unicodeScalars.contains(where: CharacterSet.decimalDigits.contains)
                && !letters.isEmpty
            let isPotentialName = token.isTitleCase
                && !commonCapitalizedWords.contains(canonicalEntity(token.value))
            let isNonInitialTitleCase = isPotentialName && !token.isSentenceInitial
            let isSentenceInitialName = isPotentialName && token.isSentenceInitial

            if isAcronym || isMixedCase || isLetterNumberLabel || isNonInitialTitleCase || isSentenceInitialName {
                result.insert(canonicalEntity(token.value))
            }
        }
        return result
    }

    private static func canonicalWords(in text: String) -> Set<String> {
        Set(lexicalTokens(in: text).map { canonicalEntity($0.value) })
    }

    private static func canonicalEntity(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .punctuationCharacters)
            .replacingOccurrences(of: #"(?:'s|’s)$"#, with: "", options: .regularExpression)
    }

    private struct LexicalToken {
        let value: String
        let isSentenceInitial: Bool

        var isTitleCase: Bool {
            let letters = value.unicodeScalars.filter(CharacterSet.letters.contains)
            guard letters.count > 1,
                  let firstLetter = letters.first,
                  CharacterSet.uppercaseLetters.contains(firstLetter) else { return false }
            return letters.dropFirst().allSatisfy(CharacterSet.lowercaseLetters.contains)
        }
    }

    private static func lexicalTokens(in text: String) -> [LexicalToken] {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return lexicalRegex.matches(in: text, range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: text) else { return nil }
            return LexicalToken(
                value: String(text[tokenRange]),
                isSentenceInitial: isSentenceInitial(tokenRange.lowerBound, in: text)
            )
        }
    }

    private static func isSentenceInitial(_ index: String.Index, in text: String) -> Bool {
        var cursor = index
        while cursor > text.startIndex {
            cursor = text.index(before: cursor)
            let character = text[cursor]
            if character.isWhitespace || "\"'“”‘’([{—–-".contains(character) { continue }
            return ".!?".contains(character)
        }
        return true
    }

    private static let numericRegex = try! NSRegularExpression(
        pattern: #"(?<![\p{L}\p{N}_])(?:[$£€¥]\s*)?[+-]?(?:\d{1,3}(?:,\d{3})+|\d+)(?:\.\d+)?(?:\s*(?:%|percent\b|per\s+cent\b|[kmb]\b|thousand\b|million\b|billion\b|dollars?\b|pounds?\b|euros?\b|yen\b))?"#,
        options: [.caseInsensitive]
    )

    private static let lexicalRegex = try! NSRegularExpression(
        pattern: #"[\p{L}][\p{L}\p{M}\p{N}'’.-]*"#
    )

    private static let commonCapitalizedWords: Set<String> = [
        "a", "an", "and", "as", "at", "because", "but", "by", "do",
        "finally", "first", "for", "from", "give", "he", "her", "here",
        "his", "how", "i", "if", "in", "it", "its", "keep", "lead",
        "make", "my", "name", "no", "not", "of", "on", "or", "our",
        "overall", "say", "second", "she", "so", "start", "stop", "that",
        "the", "their", "then", "there", "these", "they", "third", "this",
        "those", "to", "we", "what", "when", "where", "which", "while",
        "who", "why", "with", "you", "your"
    ]
}
