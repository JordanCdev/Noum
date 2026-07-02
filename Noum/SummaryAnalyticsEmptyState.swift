//
//  SummaryAnalyticsEmptyState.swift
//  Noum
//
//  Honesty affordance for the "More from this rep" disclosure.
//
//  The disclosure holds the rep's analytical pass — eloquence findings,
//  pause + pitch summaries, the positional read, the recurring-position
//  trend, and word choice. Every one of those cards self-hides when it
//  lacks the signal to read honestly (each returns `EmptyView` / nil), which
//  is the correct restraint — but it leaves the disclosure hollow on a short
//  first rep, so "More from this rep" reads like a bug rather than patience.
//
//  This names the restraint out loud, but ONLY on the genuinely-early reps
//  where a recurring-position read cannot have formed yet. A mature user
//  whose one rep happened to be quiet is deliberately NOT told "we're still
//  analysing" — that would be a small-sample lie in the other direction, and
//  a nag. Past the pattern floor, silence stays the honest default.
//
//  Pure + testable by construction (mirrors `RepEventTrendCopy` /
//  `RepTimelineCopy`): the view layer only renders what `message` returns.
enum SummaryAnalyticsEmptyState {
    /// Rep count below which a recurring-position read cannot honestly exist.
    /// Mirrors the occurrence floor `RepEventTrendEngine` enforces before it
    /// will name a habit, so the two honesty gates stay aligned.
    static let patternFloor = 3

    /// Whether each speech-quality card in the disclosure has enough signal
    /// to render. If ANY is present the disclosure isn't hollow, so the
    /// empty-state stays silent.
    struct Signals {
        var hasEloquence: Bool
        var hasPause: Bool
        var hasPitch: Bool
        var hasPositional: Bool
        var hasTrend: Bool
        var hasWordChoice: Bool

        var anyPresent: Bool {
            hasEloquence || hasPause || hasPitch || hasPositional || hasTrend || hasWordChoice
        }
    }

    /// The honest note to render, or `nil` to stay silent.
    ///
    /// - Parameters:
    ///   - isIMSummary: the disclosure's analytical block is timed-only; never
    ///     speak on the IM-conversation summary.
    ///   - repCount: total saved reps *including* this one.
    ///   - signals: which speech-quality cards actually rendered.
    static func message(isIMSummary: Bool, repCount: Int, signals: Signals) -> String? {
        guard !isIMSummary else { return nil }            // wrong surface
        guard !signals.anyPresent else { return nil }     // real analytics rendered → not hollow
        guard repCount < patternFloor else { return nil } // mature quiet rep → stay silent, never nag/lie

        return "Your speech-pattern read builds over your first few reps. "
            + "Noum waits until a position has actually recurred before it "
            + "names a habit — so what surfaces here stays honest, not guessed."
    }
}
