import Foundation

// MARK: - Coach Letter Generator
//
// Deterministic, rule-based generator for monthly coach letters.
// Reads the user's actual data for the covered month + their
// baseline / trends / voice and composes a structured letter:
//
//   • Verdict (one sentence) — was this month forward, flat, back
//   • Improvement (one sentence with a real number) — the strongest
//     measurable change
//   • Blocker (one sentence) — what's still in the way
//   • Next focus (one sentence) — what next month should hold
//
// When fewer than 5 sessions land in the window, the generator
// honest-paths: it acknowledges the thin data instead of fabricating
// a verdict. This is the inverse of the anti-goal "fake certainty
// from small sample sizes".
//
// Pure function — no I/O, no singletons. Easy to unit test. An AI
// path can wrap this later (mirror `ForwardPlanService`) but the
// deterministic path stays as the safety net.

/// Self-contained input. The coordinator builds this from live
/// stores so the generator stays pure.
struct CoachLetterInput {
    let monthKey: String               // e.g. "2026-05"
    let voice: SpeakingStyleGoal?
    let baseline: CommunicationBaseline
    /// Sessions that fall inside the covered month [start, end).
    let sessionsInMonth: [PracticeSession]
    /// All sessions (older + in-month) so we can compare to the
    /// previous month for trend direction.
    let allSessions: [PracticeSession]
    let bigMoment: BigMoment?
    let bigMomentDaysUntil: Int?
}

enum CoachLetterGenerator {

    /// Minimum sessions in the month to produce a confident letter.
    /// Below this, the letter explicitly states it's a partial read.
    static let minimumSessionsForConfidentRead = 5

    /// Generate the letter. Always returns a CoachLetter — the thin-
    /// data path produces an honest "not enough reps" letter rather
    /// than fabricating numbers.
    static func generate(input: CoachLetterInput, now: Date = Date()) -> CoachLetter {
        let sessions = input.sessionsInMonth
        let monthName = displayMonth(forKey: input.monthKey)
        let content: String

        if sessions.count < minimumSessionsForConfidentRead {
            content = thinDataLetter(
                monthName: monthName,
                sessionCount: sessions.count,
                voice: input.voice,
                bigMoment: input.bigMoment,
                bigMomentDaysUntil: input.bigMomentDaysUntil
            )
        } else {
            content = fullLetter(
                input: input,
                monthName: monthName,
                now: now
            )
        }

        return CoachLetter(
            month: input.monthKey,
            content: content,
            voiceAtGeneration: input.voice,
            generatedAt: now,
            isAIBacked: false
        )
    }

    // MARK: - Letter shapes

    private static func thinDataLetter(
        monthName: String,
        sessionCount: Int,
        voice: SpeakingStyleGoal?,
        bigMoment: BigMoment?,
        bigMomentDaysUntil: Int?
    ) -> String {
        let repWord = sessionCount == 1 ? "rep" : "reps"
        var lines: [String] = []
        lines.append("Your \(monthName) read.")
        lines.append("")
        if sessionCount == 0 {
            lines.append("Not enough reps this month for a full read — you had no rated sessions. Next month is a fresh slate.")
        } else {
            lines.append("Not enough reps this month for a full read — \(sessionCount) \(repWord) is below the floor I trust for a verdict. What I can see: every rep counts, and showing up is the move.")
        }
        if let moment = bigMoment, let days = bigMomentDaysUntil, days >= 0 {
            let category = moment.category.displayName
            if days <= 7 {
                lines.append("")
                lines.append("Your \(category) is \(days) day\(days == 1 ? "" : "s") away. The next few reps matter more than the count this month did.")
            } else if days <= 30 {
                lines.append("")
                lines.append("Your \(category) is \(days) days out. Block time for two reps a week between now and then.")
            }
        }
        lines.append("")
        lines.append(nextFocusLine(voice: voice, generic: true))
        return lines.joined(separator: "\n")
    }

    private static func fullLetter(
        input: CoachLetterInput,
        monthName: String,
        now: Date
    ) -> String {
        let sessions = input.sessionsInMonth
        let previousMonth = previousMonthSessions(
            allSessions: input.allSessions,
            monthKey: input.monthKey,
            now: now
        )

        let verdict = verdictLine(
            sessions: sessions,
            previousMonth: previousMonth,
            voice: input.voice
        )
        let improvement = improvementLine(
            sessions: sessions,
            previousMonth: previousMonth,
            baseline: input.baseline,
            voice: input.voice
        )
        let blocker = blockerLine(
            baseline: input.baseline,
            voice: input.voice
        )
        let nextFocus = nextFocusLine(
            voice: input.voice,
            bigMoment: input.bigMoment,
            bigMomentDaysUntil: input.bigMomentDaysUntil,
            baseline: input.baseline
        )

        var lines: [String] = []
        lines.append("Your \(monthName) read.")
        lines.append("")
        lines.append(verdict)
        lines.append("")
        lines.append(improvement)
        lines.append("")
        lines.append(blocker)
        lines.append("")
        lines.append(nextFocus)
        return lines.joined(separator: "\n")
    }

    // MARK: - Section composers

    private static func verdictLine(
        sessions: [PracticeSession],
        previousMonth: [PracticeSession],
        voice: SpeakingStyleGoal?
    ) -> String {
        let currentAvg = averageScore(sessions)
        let previousAvg = averageScore(previousMonth)
        let count = sessions.count
        let repWord = count == 1 ? "rep" : "reps"

        if previousMonth.isEmpty {
            return "You ran \(count) \(repWord) at \(scoreText(currentAvg)) average — call this your baseline month."
        }

        let delta = currentAvg - previousAvg
        if delta >= 0.5 {
            return "Forward month. \(count) \(repWord) at \(scoreText(currentAvg)) average, up from \(scoreText(previousAvg)). That's real movement."
        }
        if delta <= -0.5 {
            // Anti-goal: never punish-shame regression. Factual, not lecturing.
            return "\(count) \(repWord) at \(scoreText(currentAvg)) average, down from \(scoreText(previousAvg)). Not a collapse — a slip worth naming."
        }
        return "Stable month. \(count) \(repWord) at \(scoreText(currentAvg)) average — within range of \(scoreText(previousAvg))."
    }

    private static func improvementLine(
        sessions: [PracticeSession],
        previousMonth: [PracticeSession],
        baseline: CommunicationBaseline,
        voice: SpeakingStyleGoal?
    ) -> String {
        let currentFiller = averageFillerRate(sessions)
        let previousFiller = averageFillerRate(previousMonth)

        if !previousMonth.isEmpty, currentFiller < previousFiller - 0.3, currentFiller >= 0 {
            return "Filler rate dropped from \(fillerText(previousFiller)) to \(fillerText(currentFiller)) per minute. Whatever you changed, hold onto it."
        }

        if let strength = baseline.topStrengths.first {
            return "Strongest signal: \(strength.lowercased()). It held across the month."
        }

        // No prior month, no clear strength — name the streak.
        if sessions.count >= 8 {
            return "You showed up \(sessions.count) times this month. Consistency is the rep that makes the others count."
        }
        return "You showed up \(sessions.count) times. Every rep widens the read for next month."
    }

    private static func blockerLine(
        baseline: CommunicationBaseline,
        voice: SpeakingStyleGoal?
    ) -> String {
        if let blocker = baseline.persistentBlockers.first {
            return "Still in the way: \(blocker.lowercased()). That's where the next month earns its weight."
        }
        return "Nothing chronic flagged. The next bottleneck will reveal itself as you push harder."
    }

    private static func nextFocusLine(
        voice: SpeakingStyleGoal?,
        bigMoment: BigMoment? = nil,
        bigMomentDaysUntil: Int? = nil,
        baseline: CommunicationBaseline? = nil,
        generic: Bool = false
    ) -> String {
        if let moment = bigMoment, let days = bigMomentDaysUntil, days >= 0, days <= 60 {
            let category = moment.category.displayName
            return "Next month: every rep aims at the \(category) (\(days) day\(days == 1 ? "" : "s") away). Pick the mode that targets your weakest dimension and run three a week."
        }
        if generic {
            return "Next month: pick three days a week, run one rep, hold the line. Read this letter again at the end of it."
        }
        if let blocker = baseline?.persistentBlockers.first {
            return "Next month: anchor every rep to \(blocker.lowercased()). Three reps a week, no exceptions."
        }
        return "Next month: pick three days, run one rep each. The verdict next month will be honest about what changed."
    }

    // MARK: - Helpers

    private static func averageScore(_ sessions: [PracticeSession]) -> Double {
        let scored = sessions.compactMap { $0.score }
        guard !scored.isEmpty else { return 0 }
        let total = scored.reduce(0.0) { $0 + Double($1) }
        return total / Double(scored.count)
    }

    private static func averageFillerRate(_ sessions: [PracticeSession]) -> Double {
        guard !sessions.isEmpty else { return 0 }
        var totalRate = 0.0
        var weighted = 0
        for s in sessions {
            // Filler rate is per-minute. Duration in seconds.
            let minutes = max(s.duration / 60.0, 0.1)
            let rate = Double(s.fillerWordCount) / minutes
            totalRate += rate
            weighted += 1
        }
        return weighted > 0 ? totalRate / Double(weighted) : 0
    }

    private static func previousMonthSessions(
        allSessions: [PracticeSession],
        monthKey: String,
        now: Date
    ) -> [PracticeSession] {
        let cal = Calendar.current
        guard let (start, _) = CoachLetter.dateRange(forMonthKey: monthKey),
              let prevStart = cal.date(byAdding: .month, value: -1, to: start) else { return [] }
        return allSessions.filter { $0.date >= prevStart && $0.date < start }
    }

    private static func scoreText(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func fillerText(_ rate: Double) -> String {
        String(format: "%.1f", rate)
    }

    static func displayMonth(forKey key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 2, let m = Int(parts[1]) else { return key }
        let names = ["January", "February", "March", "April", "May", "June",
                     "July", "August", "September", "October", "November", "December"]
        guard m >= 1, m <= 12 else { return key }
        return names[m - 1]
    }
}
