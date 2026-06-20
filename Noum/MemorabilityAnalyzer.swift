#if canImport(Foundation)
import Foundation

/// "Make It Stick" — a memorability + structure read drawn from Patrick
/// Winston's *How to Speak* (MIT OpenCourseWare).
///
/// Pure + deterministic so it is unit-testable without a model, and feeds the
/// coach the SAME way `PracticeEvaluator`'s pace read does. It judges only what
/// can be read RELIABLY from a transcript:
///
///   • the OPENING — does it orient the listener (an "empowerment promise" /
///     why-this-matters frame), or dive in cold; and
///   • the CLOSE — does it land a committed final point, or trail off / end on
///     a weak "thanks, that's it" (Winston: never end on "thank you").
///
/// The SUBJECTIVE Winston-Star elements (symbol, slogan, surprise, salient
/// idea, story) are deliberately NOT keyword-faked here — a brittle keyword
/// match would be exactly the placeholder logic this project bans. They are
/// instead taught to the AI coach as a lens (see `CoachContextBuilder`
/// "make it stick"), which can read them in context. This analyzer's only job
/// is the two structural bookends a heuristic can call honestly.
enum MemorabilityAnalyzer {

    /// How the rep opened.
    enum Opening: Equatable {
        /// Orients the listener up front (promise / framing / the question).
        case oriented
        /// Dives straight into detail with no framing — a cold open.
        case cold
        /// Not enough speech to judge.
        case insufficient
    }

    /// How the rep closed.
    enum Closing: Equatable {
        /// Lands on a clear, committed final statement.
        case landed
        /// Trails off / ends weak. Carries the matched weak tail for the coach
        /// to name precisely ("your close trailed off on 'yeah'").
        case trailedOff(tail: String)
        /// Not enough speech to judge.
        case insufficient
    }

    struct Read: Equatable {
        let opening: Opening
        let closing: Closing

        /// True only when there is a RELIABLE structural fault worth coaching:
        /// a trailed-off close (an explicit weak-tail match). The opening read
        /// is deliberately NOT actionable — "no framing cue found" is an
        /// ABSENCE, not proof of a cold open (a strong direct open like "We
        /// doubled revenue last quarter" carries no cue yet isn't cold), and
        /// asserting a fault from absence would overclaim. So opening framing
        /// and the subjective Winston-Star elements are left to the AI lens
        /// (CoachContextBuilder item 18), which can judge them from the actual
        /// transcript; the deterministic read only asserts the close, which a
        /// heuristic can call honestly.
        var hasActionableSignal: Bool {
            if case .trailedOff = closing { return true }
            return false
        }
    }

    /// Minimum word count before either bookend can be judged. Below this a
    /// rep is too short to read structure from (a one-liner has no real
    /// opening/closing arc), so both reads return `.insufficient`.
    static let minimumWordsToJudge = 12

    /// Weak ways to END a turn (Winston: a "thank you" close is a weak move;
    /// trailing off squanders the landing). Matched only against the TAIL of
    /// the transcript so a mid-talk "thank you for that" never false-flags.
    static let weakClosingTails: [String] = [
        "thank you", "thanks", "thank you for listening", "thanks for listening",
        "that's it", "that's all", "that's about it", "that's pretty much it",
        "i guess that's it", "i think that's it", "yeah", "so yeah",
        "i don't know", "i'm not sure", "or something", "or something like that",
        "anyway", "that's everything", "i guess"
    ]

    /// Cues that an opening ORIENTS the listener — an empowerment promise, a
    /// framing of why-this-matters, or the central question. Matched against
    /// the opening window only.
    static let openingOrientationCues: [String] = [
        "today", "by the end", "what i want", "what i'm going to", "the point is",
        "here's why", "here's the", "the key", "what matters", "i'll show you",
        "let me show", "imagine", "the question is", "the big idea", "what you'll",
        "the reason", "my goal", "i want to", "the thing is", "first", "this matters"
    ]

    /// Analyze a transcript into a structural read.
    static func analyze(transcript rawTranscript: String) -> Read {
        let transcript = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = transcript.split { $0 == " " || $0 == "\n" || $0 == "\t" }
        guard words.count >= minimumWordsToJudge else {
            return Read(opening: .insufficient, closing: .insufficient)
        }
        return Read(
            opening: openingRead(transcript: transcript, words: words),
            closing: closingRead(transcript: transcript)
        )
    }

    // MARK: - Opening

    private static func openingRead(transcript: String, words: [Substring]) -> Opening {
        // Look at the first sentence, capped at the opening window so a long
        // first sentence can't drag in cues from deep in the talk.
        let firstSentence = firstSentence(in: transcript)
        let window = firstSentence.isEmpty ? transcript : firstSentence
        let openingWindow = window
            .split { $0 == " " || $0 == "\n" || $0 == "\t" }
            .prefix(20)
            .joined(separator: " ")
            .lowercased()
        // A question as the very first beat orients (it frames what's at stake).
        if openingWindow.contains("?") { return .oriented }
        if openingOrientationCues.contains(where: { openingWindow.contains($0) }) {
            return .oriented
        }
        return .cold
    }

    // MARK: - Closing

    private static func closingRead(transcript: String) -> Closing {
        let lower = transcript.lowercased()
        // The tail = the last sentence, else the whole thing if unpunctuated.
        let lastSentence = lastSentence(in: lower)
        let tail = lastSentence.isEmpty ? lower : lastSentence
        let trimmedTail = tail.trimmingCharacters(in: CharacterSet(charactersIn: " .!?,\n\t"))

        // Whole-tail-is-weak: the final sentence IS a weak closer ("yeah.",
        // "that's it.", "thanks."). Strongest signal.
        if weakClosingTails.contains(trimmedTail) {
            return .trailedOff(tail: trimmedTail)
        }
        // Tail ENDS on a weak closer ("...so that's pretty much it",
        // "...and yeah", "...thank you"). Check suffix so the weak phrase has
        // to be the actual ending, not buried mid-sentence.
        if let match = weakClosingTails.first(where: { trimmedTail.hasSuffix($0) }) {
            return .trailedOff(tail: match)
        }
        return .landed
    }

    // MARK: - Sentence helpers

    private static func firstSentence(in text: String) -> String {
        guard let range = text.rangeOfCharacter(from: CharacterSet(charactersIn: ".!?")) else {
            return text
        }
        return String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func lastSentence(in text: String) -> String {
        // Split on terminal punctuation; take the last non-empty segment.
        let segments = text
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return segments.last ?? ""
    }
}
#endif
