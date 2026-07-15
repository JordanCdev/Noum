import Foundation

// MARK: - Notification Copy
//
// All notification title + body strings live here so the voice rules apply
// uniformly. Each helper returns the copy variant most fitting for the
// user's current state — we never ship "Don't break the streak" to a user
// at streak 0, never ship a generic "open the app" body when we can name
// the actual numbers.
//
// Voice rules (lifted from `.claude/skills/noum-design`):
// - No "Let's", no chirpy filler
// - No emoji
// - Sentence case (titles can be Title Case)
// - Concrete numbers when available
// - Lock-screen-safe: never quote the user's typed goal text directly

struct NotificationLine {
    let title: String
    let body: String
}

enum NotificationCopy {

    // MARK: - Daily reminder

    /// User picked a specific time. We have no information about whether
    /// they've already practiced today (the `todayDone` flag is filled by
    /// the caller from `SharedNoumState`).
    static func dailyReminder(streakDays: Int, todayDone: Bool) -> NotificationLine {
        if todayDone {
            // They've already practiced — soft "double-down" pull, not a guilt nudge.
            return NotificationLine(
                title: "Stack a second rep",
                body: "Today's already counts. A second rep is where the muscle gets built."
            )
        }

        switch streakDays {
        case 0:
            return NotificationLine(
                title: "Today is rep one",
                body: "One short drill sets your baseline. Two minutes is enough."
            )
        case 1...2:
            return NotificationLine(
                title: "Day \(streakDays + 1) starts now",
                body: "Two days don't make a habit. Today's rep is the one that does."
            )
        case 3...6:
            return NotificationLine(
                title: "Keep your \(streakDays)-day streak going",
                body: "You're \(7 - streakDays) day\(7 - streakDays == 1 ? "" : "s") from a full week — one short rep adds today."
            )
        case 7...:
            return NotificationLine(
                title: "\(streakDays) days of steady practice",
                body: "Habits this old are worth one more rep today."
            )
        default:
            return NotificationLine(
                title: "Today's rep is waiting",
                body: "A short drill keeps the rhythm."
            )
        }
    }

    // MARK: - Evening practice nudge

    /// Fired late evening only when the user has an established rhythm and
    /// has not practiced today. Copy stays neutral: no countdown and no
    /// last-chance pressure.
    static func streakWarning(streakDays: Int, freezesAvailable: Int) -> NotificationLine {
        let freezeLine = freezesAvailable > 0
            ? "Your weekly freeze can cover one quiet day."
            : "Two minutes is enough when you want to keep the rhythm active."

        switch streakDays {
        case 0:
            // Should never reach here per the scheduling guard, but be safe.
            return NotificationLine(
                title: "Today's rep is waiting",
                body: "A short drill keeps the rhythm."
            )
        case 1...2:
            return NotificationLine(
                title: "Evening practice nudge",
                body: "You've started a speaking rhythm. One short rep adds today. \(freezeLine)"
            )
        case 3...6:
            return NotificationLine(
                title: "\(streakDays) days of steady practice",
                body: "One focused rep adds today to the rhythm. \(freezeLine)"
            )
        case 7...13:
            return NotificationLine(
                title: "\(streakDays) days of steady practice",
                body: "Your habit is established. A short rep keeps it active. \(freezeLine)"
            )
        case 14...29:
            return NotificationLine(
                title: "\(streakDays) days in — nice rhythm",
                body: "A focused rep today keeps the practice line connected. \(freezeLine)"
            )
        case 30...:
            return NotificationLine(
                title: "\(streakDays) days of steady practice",
                body: "One short rep continues the habit. \(freezeLine)"
            )
        default:
            return NotificationLine(
                title: "Evening practice nudge",
                body: "A short rep keeps your rhythm active. \(freezeLine)"
            )
        }
    }

    // MARK: - Big Moment day-after check-in (neutral invite, never guilt)
    //
    // Fired the morning after a dated Big Moment passes. Closes the
    // prepare → event → reflect loop: the user prepped for a real
    // moment; the day after, the coach asks how it went so the Home
    // outcome card can collect their read of the room.
    //
    // Contracts:
    //   • Privacy — takes only the category, by construction. The
    //     user-authored moment title must NEVER reach the lock screen
    //     (same rule as the T-7 / T-1 countdown copy).
    //   • Never guilt — a pure invite. No "don't forget", no urgency,
    //     no implication that skipping the check-in costs anything.
    //     "No rush" is the register: the check-in waits for them.
    static func bigMomentCheckIn(category: BigMomentCategory) -> NotificationLine {
        NotificationLine(
            title: "How did your \(category.displayName) go?",
            body: "When you're ready, a short check-in tells your coach how the room felt. No rush."
        )
    }

    // MARK: - Weekly digest

    /// Weekly practice read with optional context from the voice goal the user
    /// explicitly chose. `nil` stays fully generic: callers must never pass the
    /// profile's always-populated effective/default style as if it were a
    /// deliberate choice.
    static func weeklyDigest(
        weeklyReps: Int,
        chosenStyleGoal: SpeakingStyleGoal? = nil
    ) -> NotificationLine {
        let line: NotificationLine

        switch weeklyReps {
        case 0:
            line = NotificationLine(
                title: "Your week, summed up",
                body: "No reps recorded this week. The path is still here when you are."
            )
        case 1...2:
            line = NotificationLine(
                title: "Light week — \(weeklyReps) rep\(weeklyReps == 1 ? "" : "s")",
                body: "\(weeklyReps) rep\(weeklyReps == 1 ? " is" : "s are") on the record. Open Noum to review the week when it suits you."
            )
        case 3...4:
            line = NotificationLine(
                title: "Steady week — \(weeklyReps) reps in",
                body: "Open Noum to review this week's reps, pace, and score when it suits you."
            )
        case 5...6:
            line = NotificationLine(
                title: "Strong week — \(weeklyReps) reps in",
                body: "Open Noum to review this week's evidence across reps, pace, and score."
            )
        case 7...:
            line = NotificationLine(
                title: "Top week — \(weeklyReps) reps cleared",
                body: "A week of regular practice is on the record. Open Noum to review the evidence."
            )
        default:
            line = NotificationLine(
                title: "Your week, summed up",
                body: "Open Noum to review your latest practice record when it suits you."
            )
        }

        guard let chosenStyleGoal else { return line }

        return NotificationLine(
            title: line.title,
            body: "\(line.body) \(weeklyGoalFocus(for: chosenStyleGoal))"
        )
    }

    /// Names the selected direction without claiming that a thin week proved
    /// improvement. Canonical goal labels are lock-screen safe; authored goal
    /// text never enters this path.
    private static func weeklyGoalFocus(for goal: SpeakingStyleGoal) -> String {
        switch goal {
        case .authoritative:
            return "Your authoritative goal stays focused on steadiness and decisive endings."
        case .warm:
            return "Your warm-voice goal stays focused on natural pace and connection."
        case .concise:
            return "Your concise goal stays focused on clean structure and fewer extra words."
        case .persuasive:
            return "Your persuasive goal stays focused on clear structure and support."
        case .executive:
            return "Your executive-presence goal stays focused on composure and concise decisions."
        case .storytelling:
            return "Your storytelling goal stays focused on a clear narrative turn and vocal emphasis."
        }
    }
}
