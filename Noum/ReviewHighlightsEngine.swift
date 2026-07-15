import Foundation

// MARK: - Review Highlights Engine

/// Picks the handful of past reps a coach would pull out of the pile and
/// say "go re-read this one" — the engine behind the Review home's
/// "Worth a second look" section.
///
/// Honesty contract:
/// - Nothing surfaces below `minimumScoredSessions` scored reps — a pick
///   from three data points is noise dressed as insight.
/// - The goal-fit pick exists only when the user has actively chosen a
///   voice (`hasChosenVoice`), and only when a rep genuinely fits it
///   (`goalFitFloor` against the same delivery read the evaluator uses).
/// - Every pick names the evidence it was chosen on.
enum ReviewHighlightsEngine {

    /// Below this many scored reps, no picks are made.
    static let minimumScoredSessions = 5

    /// Floor for "this rep genuinely fits your chosen voice". Reads through
    /// `PracticeEvaluator.voiceDeliveryBonus` (max 0.5–0.6), so 0.4 means
    /// the rep hit most of the voice's delivery markers, not one by luck.
    static let goalFitFloor = 0.4

    /// A breakthrough must beat the runner's own prior average by this much.
    static let breakthroughJump = 2.0

    struct Highlight: Identifiable, Equatable {
        enum Kind: String {
            case breakthrough
            case goalExample
            case recentBest
        }

        let kind: Kind
        let sessionID: UUID
        let title: String
        let line: String

        var id: String { "\(kind.rawValue).\(sessionID.uuidString)" }

        var icon: String {
            switch kind {
            case .breakthrough: return "chart.line.uptrend.xyaxis"
            case .goalExample: return "scope"
            case .recentBest: return "star.fill"
            }
        }
    }

    static func highlights(
        sessions: [PracticeSession],
        profile: CoachingProfile?,
        now: Date = Date()
    ) -> [Highlight] {
        let scored = eligibleScoredSessions(in: sessions)
        guard scored.count >= minimumScoredSessions else { return [] }

        var picks: [Highlight] = []
        var usedSessionIDs: Set<UUID> = []

        if let pick = breakthrough(in: scored) {
            picks.append(pick)
            usedSessionIDs.insert(pick.sessionID)
        }
        if let pick = goalExample(in: scored, profile: profile),
           !usedSessionIDs.contains(pick.sessionID) {
            picks.append(pick)
            usedSessionIDs.insert(pick.sessionID)
        }
        if let pick = recentBest(in: scored, now: now),
           !usedSessionIDs.contains(pick.sessionID) {
            picks.append(pick)
        }

        return picks
    }

    // MARK: - Picks

    /// The most recent rep that jumped well clear of the user's own average
    /// at the time — the "what changed here?" rep a coach replays with you.
    /// Compared against the up-to-5 scored reps immediately before it;
    /// needs at least 3 priors so the average means something.
    static func breakthrough(in scoredNewestFirst: [PracticeSession]) -> Highlight? {
        let eligible = eligibleScoredSessions(in: scoredNewestFirst)
        for (index, session) in eligible.enumerated() {
            guard let score = session.score, score >= 7 else { continue }
            let priors = eligible.dropFirst(index + 1).prefix(5).compactMap(\.score)
            guard priors.count >= 3 else { continue }
            let priorAverage = Double(priors.reduce(0, +)) / Double(priors.count)
            guard Double(score) - priorAverage >= breakthroughJump else { continue }

            let day = session.date.formatted(date: .abbreviated, time: .omitted)
            return Highlight(
                kind: .breakthrough,
                sessionID: session.id,
                title: "The rep where it jumped",
                line: "\(score)/10, up from a \(String(format: "%.1f", priorAverage)) prior average. \(day)."
            )
        }
        return nil
    }

    /// The rep whose delivery best fits the voice the user chose — ranked
    /// by the same delivery read the evaluator scores with, so "closest to
    /// your authoritative voice" is grounded, not vibes.
    static func goalExample(in scoredNewestFirst: [PracticeSession], profile: CoachingProfile?) -> Highlight? {
        guard let profile, profile.hasChosenVoice, let voice = profile.chosenStyleGoal else { return nil }

        let ranked: [(session: PracticeSession, fit: Double)] = eligibleScoredSessions(in: scoredNewestFirst)
            .compactMap { session in
                guard let score = session.score, score >= 7,
                      session.imConversationDetails == nil else { return nil }
                let fit = PracticeEvaluator.voiceDeliveryBonus(
                    profile: profile,
                    wordCount: session.wordCount,
                    duration: session.duration,
                    fillerCount: session.fillerWordCount,
                    wordsPerMinute: Double(session.wordsPerMinute)
                )
                guard fit >= goalFitFloor else { return nil }
                return (session, fit)
            }
            .sorted { lhs, rhs in
                if lhs.fit != rhs.fit { return lhs.fit > rhs.fit }
                if let l = lhs.session.score, let r = rhs.session.score, l != r { return l > r }
                return lhs.session.date > rhs.session.date
            }

        guard let best = ranked.first, let score = best.session.score else { return nil }
        return Highlight(
            kind: .goalExample,
            sessionID: best.session.id,
            title: "Closest to your \(voice.title.lowercased()) voice",
            line: "\(score)/10 · \(best.session.fillerWordCount) fillers · \(best.session.wordsPerMinute) WPM — re-read how it landed"
        )
    }

    /// The strongest rep of the last two weeks — recency keeps it
    /// motivating rather than nostalgic.
    static func recentBest(in scoredNewestFirst: [PracticeSession], now: Date = Date()) -> Highlight? {
        let cutoff = now.addingTimeInterval(-14 * 86_400)
        let candidates = eligibleScoredSessions(in: scoredNewestFirst)
            .filter { $0.date >= cutoff && ($0.score ?? 0) >= 8 }
        let best = candidates.max { lhs, rhs in
            let l = lhs.score ?? 0
            let r = rhs.score ?? 0
            if l != r { return l < r }
            return lhs.date < rhs.date
        }
        guard let best, let score = best.score else { return nil }

        let day = best.date.formatted(date: .abbreviated, time: .omitted)
        return Highlight(
            kind: .recentBest,
            sessionID: best.id,
            title: "Best rep this fortnight",
            line: "\(best.headline ?? "Strong rep") · \(score)/10 · \(day)"
        )
    }

    private static func eligibleScoredSessions(in sessions: [PracticeSession]) -> [PracticeSession] {
        PracticeProgressEligibility.eligibleSessions(in: sessions)
            .filter { $0.score != nil }
            .sorted { $0.date > $1.date }
    }
}
