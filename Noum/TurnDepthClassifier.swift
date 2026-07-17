import Foundation

// MARK: - Deterministic turn-depth classifier

enum TurnDepthClassifier {

    /// Classify the user's current turn without provider calls or retrieval.
    /// Ordering matters: trust repair outranks all other intents because a
    /// human coach repairs the miss before continuing the plan.
    static func classify(
        userText: String,
        recentTurns: [CoachMessage] = [],
        liveMode: Bool = false
    ) -> CoachTurnDepth {
        let lower = normalized(userText)
        guard !lower.isEmpty else { return liveMode ? .groundedRead : .quickMove }

        if isTrustRepair(lower) {
            return .trustRepair
        }

        if recentTurns.last(where: { $0.role == .coach }) != nil,
           isSoftPushback(lower) {
            return .trustRepair
        }

        if isDeepAssessment(lower) {
            return .deepAssessment
        }

        if isMemoryHandoff(lower) {
            return .groundedRead
        }

        if isGroundedRead(lower) {
            return .groundedRead
        }

        if isQuickMove(lower) {
            return .quickMove
        }

        if liveMode {
            // In a call, vague turns usually want the coach to read the latest
            // thing and keep the conversation moving, not hand back a generic
            // text-chat move.
            return .groundedRead
        }

        // A short follow-up after a coach reply usually asks for a move, unless
        // it was already caught as trust repair or deep assessment.
        if recentTurns.last(where: { $0.role == .coach }) != nil,
           wordCount(lower) <= 6 {
            return .quickMove
        }

        return .quickMove
    }

    /// A bare greeting or social pleasantry ("hi", "hey Noum", "how's it going",
    /// "thanks") — NOT a coaching question. These must get a warm, brief human
    /// hello, never a diagnostic drill. Deliberately tight (<=5 words, exact
    /// openers or short social phrases) so a real coaching turn that merely opens
    /// with "hey, what should I..." is never swallowed. Used by the reliability
    /// gate to catch the fallback path handing "hi" a Pressure-Drill read when no
    /// live model answered.
    static func isGreetingOrSmallTalk(_ userText: String) -> Bool {
        let lower = normalized(userText)
        guard !lower.isEmpty, wordCount(lower) <= 5 else { return false }
        let stripped = lower.trimmingCharacters(in: CharacterSet(charactersIn: " .!?,'\""))
        let exact: Set<String> = [
            "hi", "hey", "hello", "yo", "hiya", "heya", "sup", "howdy",
            "hey there", "hi there", "hello there", "hey noum", "hi noum",
            "hello noum", "morning", "good morning", "good afternoon",
            "good evening", "evening", "gm", "hey again", "hi again",
            "im back", "i'm back", "back again"
        ]
        if exact.contains(stripped) { return true }
        // Short social pleasantries: greeting-y intent, no coaching content.
        if containsAny(stripped, [
            "how are you", "how's it going", "hows it going", "how are things",
            "how you doing", "how's things", "what's up", "whats up",
            "good to be back", "nice to meet", "thanks", "thank you", "cheers"
        ]) {
            // Guard: a coaching ask riding on a pleasantry ("thanks, what should
            // I do next?") still routes normally. Match ask PHRASES, not the bare
            // word "what" (which would wrongly reject the greeting "what's up").
            if containsAny(stripped, [
                "what should", "what do i", "what next", "how do i",
                "help me", "fix my", "improve my", "should i", "work on"
            ]) {
                return false
            }
            return true
        }
        return false
    }

    /// A tiny non-sequitur / probe turn ("egg", "asdf", "test") rather than a
    /// coaching ask. Kept deliberately narrow so odd wording inside a real
    /// question still flows through normal coaching.
    static func isLowSignalOffTopicTest(_ userText: String) -> Bool {
        let normalized = normalized(userText)
            .replacingOccurrences(
                of: #"[^a-z0-9\s]"#,
                with: "",
                options: .regularExpression
            )
            .split { $0.isWhitespace }
            .joined(separator: " ")
        guard !normalized.isEmpty else { return false }
        if ["egg", "banana", "asdf", "test", "lol", "huh"].contains(normalized) {
            return true
        }
        // Short human-state disclosures are low word-count, not low signal.
        // Treating "I'm exhausted" like a probe produces a dismissive
        // "tiny test" response at exactly the moment the coach should soften.
        if containsAny(normalized, [
            "exhausted", "tired", "overwhelmed", "anxious", "nervous",
            "scared", "frustrated", "discouraged", "defeated", "stuck",
            "freeze", "froze", "panic", "blank"
        ]) {
            return false
        }
        guard normalized.count <= 18,
              wordCount(normalized) <= 2 else {
            return false
        }
        return !containsAny(normalized, [
            "score", "filler", "voice", "rate", "plan", "help", "practice",
            "interview", "meeting", "presentation", "pitch", "better",
            "improve", "why", "what", "how", "data", "stats", "metrics",
            "numbers", "pace", "wpm", "duration", "rating"
        ])
    }

    static func isTrustRepair(_ lower: String) -> Bool {
        containsAny(lower, [
            "that wasn't helpful", "that wasnt helpful",
            "not helpful", "not informative", "not useful",
            "it's not easy", "its not easy", "not that easy",
            "easier said than done", "harder than that",
            "you missed the point", "missed the point",
            "that is wrong", "that's wrong", "thats wrong",
            "that doesn't answer", "that does not answer",
            "you're repeating yourself", "you are repeating yourself",
            "repeating yourself", "same thing again", "said that already",
            "you already said that",
            "too much writing", "too long", "get to the point",
            "too generic", "generic ai", "generic tips",
            "stop saying practice more", "stop telling me to practice",
            "do not just tell me to practice", "don't just tell me to practice",
            "robotic", "low eq", "not high eq",
            "try again", "you are just saying", "you're just saying",
            "that doesn't mean", "that does not mean",
            "no where near", "nowhere near",
            // Unambiguous "you didn't answer my real ask" pushback. The bare
            // "what i meant" / "actual question" / "real question" forms are
            // deliberately excluded: they fire on benign self-clarification
            // ("what I meant was…", "my real question is about pace"), which
            // would misroute to trust repair and emit a phantom "you're right
            // to push me" attunement opener. Intent mismatch on a non-pushback
            // turn is already handled at reply level by the `missingIntentFit`
            // semantic gate, not by faking an apology here.
            "answered what i meant", "answer what i meant"
        ])
    }

    static func isSoftPushback(_ lower: String) -> Bool {
        let acknowledgesPriorPoint = containsAny(lower, [
            "okay", "ok", "cool", "that's cool", "thats cool",
            "that is cool", "i get", "i hear", "makes sense",
            "fair enough"
        ])
        let pivotsAgainstIt = containsAny(lower, [
            "however", "but", "though", "still", "except"
        ])
        return acknowledgesPriorPoint && pivotsAgainstIt
    }

    static func isDeepAssessment(_ lower: String) -> Bool {
        if isHowToSoundMoreIntent(lower) {
            return false
        }
        if isLongitudinalPerformanceRead(lower) {
            return true
        }
        return containsAny(lower, [
            "how far off", "how close am i", "am i close",
            "am i far", "where am i really", "how far away",
            "overall", "be honest", "honest verdict",
            "real verdict", "tell me straight", "give it to me straight",
            "am i ready", "ready for", "close to my goal",
            "close to sounding", "from sounding",
            "how much more", "distance from", "where do i stand",
            "where am i at", "in terms of my sessions"
        ]) || asksForJudgementVerdict(lower)
    }

    /// Meta-judgement turns are often phrased as identity or perception
    /// questions, not just "how far off am I". Route those to the deeper
    /// assessment path so the coach must calibrate verdict, evidence, missing
    /// evidence, and proof test instead of answering like a quick drill.
    private static func asksForJudgementVerdict(_ lower: String) -> Bool {
        guard containsAny(lower, [
            "do i lack", "am i lacking", "do i have",
            "do i sound", "does this sound", "does it sound",
            "could this sound", "could i sound", "would this sound",
            "would i sound", "am i sounding", "is this sounding",
            "do i come across", "does this come across",
            "could this come across", "am i coming across",
            "is this coming across", "could this be", "does this read",
            "would this read", "is this too"
        ]) else {
            return false
        }

        return containsAny(lower, [
            "conviction", "convincing", "credible", "credibility",
            "authoritative", "authority", "executive", "leadership",
            "confident", "confidence", "evasive", "polished",
            "prepared", "ready"
        ])
    }

    static func isGroundedRead(_ lower: String) -> Bool {
        if isHowToSoundMoreIntent(lower) {
            return false
        }
        if isBroadPerformanceRead(lower) ||
            explicitlyRequestsMetrics(lower) ||
            isSpecificAnswerLandingRead(lower) {
            return true
        }
        return containsAny(lower, [
            "what happened", "what did you notice", "what do you notice",
            "read this rep", "read my rep", "last rep",
            "latest rep", "use my last rep", "what am i doing wrong",
            "why did that happen", "why did my score",
            "what went wrong", "what went well", "how did that land",
            "how did i sound", "how do i sound", "do i sound",
            "did i sound", "does this sound", "does it sound",
            "how does this sound", "do i come across",
            "how do i come across"
        ])
    }

    /// A question about why one specific answer failed is a request to read
    /// that answer, not generic communication advice. Requiring both "why" and
    /// a bounded landing phrase avoids turning "How did I do that?" into an
    /// unsupported personal evaluation.
    static func isSpecificAnswerLandingRead(_ userText: String) -> Bool {
        let lower = normalized(userText)
        guard lower.contains("why") else { return false }
        return containsAny(lower, [
            "that answer landed badly", "that answer land badly",
            "that answer landed bad", "that answer did not land",
            "that answer didn't land", "that answer didn’t land",
            "that answer not land", "that answer did not work",
            "that answer didn't work", "that answer didn’t work",
            "that answer fell flat", "that answer came across wrong"
        ])
    }

    /// A bounded personal evaluation ask, distinct from both a how-to question
    /// and a request for telemetry. Exact matching is intentional: substring
    /// matching would turn "How did I do that?" into a claimed performance read.
    static func isBroadPerformanceRead(_ userText: String) -> Bool {
        let turn = canonicalQuestion(userText)
        let latestRepReads: Set<String> = [
            "how did i do", "how'd i do", "how did i do overall",
            "honestly how did i do", "how was my answer", "how was that",
            "was that any good", "what did you think of my answer",
            "what do you think of my answer"
        ]
        return latestRepReads.contains(turn) || isLongitudinalPerformanceRead(turn)
    }

    /// Longitudinal evaluation needs the deeper evidence-calibration path. It
    /// still does not ask for raw statistics or implicitly request another drill.
    static func isLongitudinalPerformanceRead(_ userText: String) -> Bool {
        let turn = canonicalQuestion(userText)
        let exact: Set<String> = [
            "how am i doing", "how am i doing overall",
            "am i improving", "am i actually improving", "am i really improving",
            "have i improved", "have i actually improved",
            "am i getting better", "am i actually getting better",
            "am i making progress", "what progress am i making"
        ]
        if exact.contains(turn) { return true }
        let boundedProgressPattern =
            #"^am i (?:actually |really )?improving or am i just (?:doing|repeating) reps$"#
        return turn.range(of: boundedProgressPattern, options: .regularExpression) != nil
    }

    /// True only for an explicit personal readout request. Mentioning progress,
    /// improvement, a score concept, or metrics in a craft question is not
    /// permission to dump dashboard telemetry into the coaching conversation.
    static func explicitlyRequestsMetrics(_ userText: String) -> Bool {
        !requestedPersonalMetrics(userText).isEmpty
    }

    /// Returns the exact metric kinds the user authorized. A broad "stats" ask
    /// requests the complete bounded rep projection; a filler-count question
    /// does not silently authorize score, pace, or duration narration.
    static func requestedPersonalMetrics(_ userText: String) -> [CoachMetricKind] {
        let turn = canonicalQuestion(userText)
        let metricNounPattern =
            #"(?:words per minute|filler count|filler rate|statistics|metrics?|stats|numbers|duration|rating|score|data|wpm|pace)"#
        let readoutSubjectPattern = #"(?:my (?:exact )?|the exact |exact )"#
        let readoutLeadPatterns = [
            #"^what(?:'s|s| is| was| were| are) "#,
            #"^(?:please )?(?:show|give|report)(?: me)? "#,
            #"^(?:please )?tell me "#,
            #"^(?:can|could|would|will) you (?:please )?(?:show|give|report)(?: me)? "#,
            #"^(?:can|could|would|will) you (?:please )?tell me "#,
            #"^(?:can|could) i (?:see|get) "#
        ]
        let readoutLead = readoutLeadPatterns.contains { lead in
            let pattern = lead + readoutSubjectPattern + metricNounPattern + #"(?:$| )"#
            return turn.range(of: pattern, options: .regularExpression) != nil
        }
        let trimmedQuestion = userText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        // A bare "My data?" could mean privacy or account data. Only concrete
        // speech measures are safe to resolve as an elliptical personal read;
        // broad telemetry nouns require an explicit readout verb.
        let ellipticalMetricNounPattern =
            #"(?:words per minute|filler count|filler rate|duration|rating|score|wpm|pace)"#
        let ellipticalPattern = #"^(?:and |what about )?my (?:exact )?"# +
            ellipticalMetricNounPattern + #"$"#
        let ellipticalMetricQuestion = trimmedQuestion.hasSuffix("?") &&
            turn.range(
                of: ellipticalPattern,
                options: .regularExpression
            ) != nil
        let personalCountQuestion = [
            "how many fillers did i", "how many filler words did i",
            "how many ums did i", "how many uhs did i",
            "how many fillers were in my", "how many filler words were in my"
        ].contains(where: turn.contains)

        guard readoutLead || ellipticalMetricQuestion ||
                personalCountQuestion else {
            return []
        }

        let asksForCompleteReadout = [
            "stats", "statistics", "numbers", "data", "metrics", "metric"
        ].contains(where: turn.contains) &&
            ![
                "filler", "pace", "wpm", "words per minute", "duration",
                "score", "rating"
            ].contains(where: turn.contains)
        if asksForCompleteReadout {
            return CoachMetricKind.allCases
        }

        var requested: [CoachMetricKind] = []
        if ["score", "rating"].contains(where: turn.contains) {
            requested.append(.score)
        }
        if personalCountQuestion ||
            ["filler count", "how many fillers", "how many filler words", "how many ums", "how many uhs"]
                .contains(where: turn.contains) {
            requested.append(.fillerCount)
        }
        if turn.contains("filler rate") {
            requested.append(.fillerRatePerMinute)
        }
        if ["pace", "wpm", "words per minute"].contains(where: turn.contains) {
            requested.append(.paceWordsPerMinute)
        }
        if turn.contains("duration") {
            requested.append(.durationSeconds)
        }
        return requested.isEmpty ? CoachMetricKind.allCases : requested
    }

    static func isMemoryHandoff(_ lower: String) -> Bool {
        containsAny(lower, [
            "what should noum remember", "what should you remember",
            "what do you remember", "remember next time",
            "what should we remember", "what should i save",
            "what do we keep", "what should we keep",
            "what should i keep from this", "what should you keep from this"
        ])
    }

    static func isQuickMove(_ lower: String) -> Bool {
        containsAny(lower, [
            "what should i do next", "what do i do next",
            "what next", "next move", "what should i work on",
            "what should i focus on", "give me one move",
            "one move", "quick move", "what should i do",
            "how do i", "help me", "fix my", "improve my"
        ])
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .replacingOccurrences(of: "\u{2018}", with: "'")
            .replacingOccurrences(of: "\u{201c}", with: "\"")
            .replacingOccurrences(of: "\u{201d}", with: "\"")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func canonicalQuestion(_ value: String) -> String {
        normalized(value)
            .replacingOccurrences(
                of: #"[^a-z0-9'\s]"#,
                with: " ",
                options: .regularExpression
            )
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private static func isHowToSoundMoreIntent(_ lower: String) -> Bool {
        containsAny(lower, [
            "how do i sound more",
            "how can i sound more",
            "sound more confident",
            "sound more authoritative"
        ])
    }

    private static func wordCount(_ value: String) -> Int {
        value.split { $0.isWhitespace || $0.isNewline }.count
    }
}
