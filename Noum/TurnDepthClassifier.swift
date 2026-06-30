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
        containsAny(lower, [
            "how far off", "how close am i", "am i close",
            "am i far", "where am i really", "how far away",
            "overall", "be honest", "honest verdict",
            "real verdict", "tell me straight", "give it to me straight",
            "am i ready", "ready for", "close to my goal",
            "close to sounding", "from sounding",
            "how much more", "distance from", "where do i stand",
            "where am i at", "in terms of my sessions"
        ])
    }

    static func isGroundedRead(_ lower: String) -> Bool {
        containsAny(lower, [
            "what happened", "what did you notice", "what do you notice",
            "read this rep", "read my rep", "last rep",
            "latest rep", "use my last rep", "what am i doing wrong",
            "why did that happen", "why did my score",
            "what went wrong", "what went well", "how did that land"
        ])
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

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    private static func wordCount(_ value: String) -> Int {
        value.split { $0.isWhitespace || $0.isNewline }.count
    }
}
