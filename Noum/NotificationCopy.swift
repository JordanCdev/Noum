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
                title: "Hold your \(streakDays)-day streak",
                body: "You're \(7 - streakDays) day\(7 - streakDays == 1 ? "" : "s") from a full week. One short rep keeps it going."
            )
        case 7...:
            return NotificationLine(
                title: "Your \(streakDays)-day streak is yours to keep",
                body: "Habits this old are worth one more rep today."
            )
        default:
            return NotificationLine(
                title: "Today's rep is waiting",
                body: "A short drill keeps the rhythm."
            )
        }
    }

    // MARK: - Streak warning (loss-aversion)

    /// Fired late evening only when the user has a real streak to lose.
    /// Phrased as a deadline, with a stronger frame as the streak gets longer.
    static func streakWarning(streakDays: Int, freezesAvailable: Int) -> NotificationLine {
        let freezeLine = freezesAvailable > 0
            ? "Or your weekly freeze covers a single miss."
            : "No freeze left this week — only a rep saves it."

        switch streakDays {
        case 0:
            // Should never reach here per the scheduling guard, but be safe.
            return NotificationLine(
                title: "Today's rep is waiting",
                body: "A short drill keeps the rhythm."
            )
        case 1...2:
            return NotificationLine(
                title: "Today's rep is ready",
                body: "A short rep keeps your \(streakDays)-day streak going. \(freezeLine)"
            )
        case 3...6:
            return NotificationLine(
                title: "Keep your \(streakDays)-day streak going",
                body: "Two focused minutes adds today to the run. \(freezeLine)"
            )
        case 7...13:
            return NotificationLine(
                title: "\(streakDays) days of steady practice",
                body: "A short rep adds today to your streak. \(freezeLine)"
            )
        case 14...29:
            return NotificationLine(
                title: "\(streakDays) days in — nice rhythm",
                body: "Two minutes keeps the rhythm going. \(freezeLine)"
            )
        case 30...:
            return NotificationLine(
                title: "\(streakDays) days of steady practice",
                body: "One short rep continues the habit. \(freezeLine)"
            )
        default:
            return NotificationLine(
                title: "Today's rep is ready",
                body: "A short rep keeps your rhythm going. \(freezeLine)"
            )
        }
    }

    // MARK: - Daily challenge expiry (informational, never punish-shame)
    //
    // Fired at 8:30 PM local when at least one of today's three daily
    // challenges is still unclaimed. Tone is informational — naming
    // what's open, never threatening loss. Anti-goal-aligned with the
    // "we never punish-shame a miss" rule from VISION. No "Don't lose
    // your streak", no "Hurry", no exclamation marks.
    //
    // Schedule guard: caller MUST check `unclaimedCount > 0` before
    // arming. Firing this with zero unclaimed would be a lie — the
    // user has already done the work.
    static func dailyChallengeExpiry(unclaimedCount: Int) -> NotificationLine {
        switch unclaimedCount {
        case 1:
            return NotificationLine(
                title: "One quick challenge open",
                body: "One of today's three is still claimable. A short rep before midnight unlocks it."
            )
        case 2:
            return NotificationLine(
                title: "Two quick challenges open",
                body: "Two of today's three are still claimable. One focused rep usually clears at least one."
            )
        case 3:
            return NotificationLine(
                title: "Today's three are open",
                body: "All three of today's challenges are still claimable. A short rep is enough to start."
            )
        default:
            return NotificationLine(
                title: "Today's challenges are open",
                body: "Still claimable until midnight. A short rep moves them forward."
            )
        }
    }

    /// Brief acknowledgement line when a claim lands. The home tile
    /// already plays a celebration toast — this copy is reserved for
    /// any future surface (notification action, watch glance) that
    /// wants a one-line read of "you just claimed X". Living here so
    /// the voice rules apply uniformly.
    static func dailyChallengeClaimed(title: String, xp: Int) -> NotificationLine {
        return NotificationLine(
            title: "Claimed — \(title.lowercased())",
            body: "Logged. +\(xp) XP toward your rank."
        )
    }

    // MARK: - Weekly digest

    static func weeklyDigest(weeklyReps: Int) -> NotificationLine {
        switch weeklyReps {
        case 0:
            return NotificationLine(
                title: "Your week, summed up",
                body: "Quiet week. The path is still here when you are."
            )
        case 1...2:
            return NotificationLine(
                title: "Light week — \(weeklyReps) rep\(weeklyReps == 1 ? "" : "s")",
                body: "One more rep next week and you're at four. Open Noum to see what's trending."
            )
        case 3...4:
            return NotificationLine(
                title: "Steady week — \(weeklyReps) reps in",
                body: "Open Noum to see how this week shaped up — score, pace, and what's trending."
            )
        case 5...6:
            return NotificationLine(
                title: "Strong week — \(weeklyReps) reps in",
                body: "Open Noum to see your week. Score and pace are working together when reps stack like this."
            )
        case 7...:
            return NotificationLine(
                title: "Top week — \(weeklyReps) reps cleared",
                body: "Speakers who hit a rep a day are the ones whose voices change. Open Noum for the read."
            )
        default:
            return NotificationLine(
                title: "Your week, summed up",
                body: "Open Noum to see how this week shaped up — reps, score, and what's trending."
            )
        }
    }
}
