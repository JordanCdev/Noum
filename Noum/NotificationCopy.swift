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
//
// Voice-goal awareness (M14 — closes the goal-aware loop on its 7th surface):
// `dailyReminder` and `weeklyDigest` accept an optional `SpeakingStyleGoal`.
// When set AND the streak / rep tier has room without crowding the lock
// screen, the body picks up a one-clause "toward your <voice> voice" thread
// that mirrors the in-app surfaces (VoiceAnchorBanner, LiveEloquenceHUD,
// Coach Note momentum, GoalProgressView, VoiceAlignmentChip on home + the
// looking-ahead card). The enum's `shortVoiceLabel` is the source — never
// user-typed goal text. Silent when the goal is nil (no fake personalization).

struct NotificationLine {
    let title: String
    let body: String
}

enum NotificationCopy {

    // MARK: - Daily reminder

    /// User picked a specific time. We have no information about whether
    /// they've already practiced today (the `todayDone` flag is filled by
    /// the caller from `SharedNoumState`).
    ///
    /// `voice` — the user's chosen `SpeakingStyleGoal` if set. When provided
    /// and the streak/rep tier supports it, the body picks up a one-clause
    /// voice-alignment thread. Defaulted to `nil` so legacy callers compile
    /// unchanged; behavior is identical to the prior shape when nil.
    static func dailyReminder(
        streakDays: Int,
        todayDone: Bool,
        voice: SpeakingStyleGoal? = nil
    ) -> NotificationLine {
        if todayDone {
            // They've already practiced — soft "double-down" pull, not a guilt nudge.
            return NotificationLine(
                title: "Stack a second rep",
                body: "Today's already counts. A second rep is where the muscle gets built."
            )
        }

        switch streakDays {
        case 0:
            // Cold-start: no signal yet, no voice clause (over-claiming).
            return NotificationLine(
                title: "Today is rep one",
                body: "One short drill sets your baseline. Two minutes is enough."
            )
        case 1...2:
            // Mid-tier with room: append the voice thread when set.
            // Stem "Closer to" mirrors the profile's `GoalProgressTrend`
            // chip copy ("Closer this week") so the same grounding word
            // shows up on every loop surface.
            let body = appendingVoiceClause(
                base: "Two days don't make a habit. Today's rep is the one that does.",
                voice: voice,
                stem: "Closer to"
            )
            return NotificationLine(
                title: "Day \(streakDays + 1) starts now",
                body: body
            )
        case 3...6:
            // Mid-tier with room: append the voice thread when set.
            let baseBody = "You're \(7 - streakDays) day\(7 - streakDays == 1 ? "" : "s") from a full week. One short rep keeps it going."
            let body = appendingVoiceClause(
                base: baseBody,
                voice: voice,
                stem: "Closer to"
            )
            return NotificationLine(
                title: "Hold your \(streakDays)-day streak",
                body: body
            )
        case 7...:
            // High-streak: copy is already punchy at lock-screen length. No append.
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
                title: "\(streakDays)-day streak — keep it",
                body: "A short rep before midnight protects the streak. \(freezeLine)"
            )
        case 3...6:
            return NotificationLine(
                title: "\(streakDays) days in a row at risk",
                body: "Two minutes saves it. \(freezeLine)"
            )
        case 7...13:
            return NotificationLine(
                title: "Your \(streakDays)-day streak ends tonight",
                body: "Habits this old are worth two minutes. \(freezeLine)"
            )
        case 14...29:
            return NotificationLine(
                title: "\(streakDays) days, all on the line",
                body: "Two weeks of work hangs on one short rep. \(freezeLine)"
            )
        case 30...:
            return NotificationLine(
                title: "Don't lose \(streakDays) days at the buzzer",
                body: "A streak this long doesn't deserve a footnote. \(freezeLine)"
            )
        default:
            return NotificationLine(
                title: "Streak ends tonight",
                body: "A short rep keeps it alive. \(freezeLine)"
            )
        }
    }

    // MARK: - Weekly digest

    /// `voice` — the user's chosen `SpeakingStyleGoal` if set. When provided
    /// and the user has earned a strong-week tier (≥ 5 reps), the body picks
    /// up the voice-alignment thread. Quiet / light weeks stay neutral —
    /// claiming voice progress on a 1-rep week would over-claim with weak
    /// signal. Defaulted to `nil` for legacy call-site compatibility.
    static func weeklyDigest(
        weeklyReps: Int,
        voice: SpeakingStyleGoal? = nil
    ) -> NotificationLine {
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
            // Earned tier: append voice-alignment thread when set.
            let body = appendingVoiceClause(
                base: "Open Noum to see your week. Score and pace are working together when reps stack like this.",
                voice: voice,
                stem: "This is what working toward"
            ) { stem, label in
                // Strong-week variant reads better as a complete sentence,
                // not the standard "Closer to your …" suffix.
                "\(stem) your \(label) looks like."
            }
            return NotificationLine(
                title: "Strong week — \(weeklyReps) reps in",
                body: body
            )
        case 7...:
            // Top tier: same treatment. The base copy already lands the rep-
            // a-day frame; the voice clause grounds it in the user's goal.
            let body = appendingVoiceClause(
                base: "Speakers who hit a rep a day are the ones whose voices change. Open Noum for the read.",
                voice: voice,
                stem: "Yours is moving toward"
            ) { stem, label in
                "\(stem) your \(label)."
            }
            return NotificationLine(
                title: "Top week — \(weeklyReps) reps cleared",
                body: body
            )
        default:
            return NotificationLine(
                title: "Your week, summed up",
                body: "Open Noum to see how this week shaped up — reps, score, and what's trending."
            )
        }
    }

    // MARK: - Voice clause helper
    //
    // The "toward your <voice> voice" thread mirrors VoiceAlignmentChip /
    // VoiceAnchorBanner / Coach Note momentum copy. Keeping the construction
    // here means every notification surface that picks up the voice picks it
    // up the same way — and a future copy edit lands in one place.

    /// Appends a voice-alignment clause to `base` when `voice` is set.
    /// Returns `base` unchanged when nil so the legacy paths stay byte-identical.
    ///
    /// `stem` is the verb-phrase prefix; the helper handles `shortVoiceLabel`
    /// composition + trailing punctuation. Callers can pass a custom `format`
    /// closure for surface-specific phrasing (e.g. the weekly digest, where
    /// the clause reads better as its own sentence).
    private static func appendingVoiceClause(
        base: String,
        voice: SpeakingStyleGoal?,
        stem: String,
        format: ((_ stem: String, _ label: String) -> String)? = nil
    ) -> String {
        guard let voice else { return base }
        let label = voice.shortVoiceLabel
        let clause = format?(stem, label) ?? "\(stem) your \(label)."
        return "\(base) \(clause)"
    }
}
