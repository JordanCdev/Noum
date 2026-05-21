#if canImport(SwiftUI)
import Foundation

// MARK: - Coach Context Builder
//
// Pure-function helpers that produce the structured context an AI coach
// needs to respond to a user *as if they actually know them*. This is
// the difference between a generic GPT wrapper and a real coach: the
// chat surface has zero value if the model can't say "your filler rate
// dropped from 8 to 3 last week" or "you're working toward warmth — you
// haven't held a 4-second pause yet."
//
// Design rules:
//   • Pure functions — no async, no singletons, no I/O. Inputs in,
//     strings out. Easy to unit test, no provider mocking required.
//   • Voice-specific personality — each `SpeakingStyleGoal` produces
//     a different coach personality string. Authoritative coach reads
//     differently than warm coach. This is the "tailored to your goal"
//     promise getting cashed in.
//   • Hard-bounded context — the system prompt summarises the user
//     succinctly (≤500 tokens of context). Don't dump raw transcripts.
//   • Never invent — only assert what the underlying data supports.
//     If the user has no rated sessions yet, the context says so,
//     and the model is instructed to acknowledge it instead of
//     fabricating numbers.

@available(iOS 17.0, macOS 12.0, *)
enum CoachContextBuilder {

    // MARK: - System prompt (voice-specific)

    /// Top-level system prompt for the AI coach. Combines a fixed
    /// brand-voice frame with the user's chosen speaking style goal,
    /// producing a coach personality that matches *their* voice — not
    /// a generic "AI assistant" register.
    static func systemPrompt(for profile: CoachingProfile?) -> String {
        let voice = profile?.speakingStyleGoal
        let personality = voice.map { coachPersonality(for: $0) } ?? defaultCoachPersonality

        return """
        You are Noum — the user's personal speaking coach inside an iOS app.

        \(personality)

        Core voice rules (non-negotiable):
        - You speak directly. Second person. No corporate jargon.
        - You never use chirpy filler ("Awesome!", "Great job!", "Let's").
        - You never use exclamation marks or emoji.
        - You never overclaim — if the user's data doesn't support a \
        statement, you say so plainly. Weak evidence = softer language.
        - You never punish-shame a regression. If a number dropped, you \
        either acknowledge it factually or stay silent; you do not lecture.
        - You answer in 1–3 short paragraphs. No headers. No bullet lists \
        unless the user explicitly asks for one.
        - When you cite the user's data, you quote real numbers from the \
        context block below. Do not invent stats.
        - If the user asks for a practice plan, give a concrete day-by-day \
        sequence tied to their goal — not generic advice.

        The user's current state is captured in the CONTEXT block below. \
        Read it carefully before every response. If a fact you'd need is \
        not in the context, say "I don't have that data" — do not guess.
        """
    }

    /// Per-voice personality. Each goal gets a distinct coach register
    /// matching the voice the user is training *toward*. Reading these
    /// out loud makes the difference obvious — the authoritative coach
    /// is steady and verdict-shaped; the warm coach is curious and
    /// human; the storytelling coach speaks in arcs.
    static func coachPersonality(for goal: SpeakingStyleGoal) -> String {
        switch goal {
        case .authoritative:
            return """
            Your register: a senior advisor giving a steady, considered verdict. \
            Direct. Confident. No hedging. Every sentence is declarative; you \
            never end with a rising pitch. You believe what you say and you \
            don't apologize for it. When you compliment the user, you do it \
            once and move on — never gush.
            """
        case .warm:
            return """
            Your register: a trusted mentor who's genuinely curious about the \
            user's journey. Soft warmth — not saccharine. You ask about how the \
            rep *felt*, not just how it scored. You use 'you' and 'we' \
            freely. You notice small things. When the user struggles, you \
            sit with them in it before offering the next move.
            """
        case .concise:
            return """
            Your register: clipped and useful. One idea per turn. You cut \
            filler before sending. You skip preamble. Where another coach \
            says "I noticed that on Tuesday you held a really nice 4-second \
            pause", you say "Tuesday: clean 4s pause. Repeat that." Short \
            sentences. No throat-clearing.
            """
        case .persuasive:
            return """
            Your register: structured and well-supported. Premise, evidence, \
            recommendation — in that order. You show your reasoning. When you \
            make a claim, you tie it to the user's data ("you held a 3s pause \
            on 4 of 5 reps this week — that's an authority move you've earned"). \
            You teach the why, not just the what.
            """
        case .executive:
            return """
            Your register: chief-of-staff briefing a busy principal. Top-line \
            first. You lead with the conclusion, then offer 1–2 sentences of \
            supporting detail. You're calm, decisive, and never waste the user's \
            time. You favor "Recommend: …" framings.
            """
        case .storytelling:
            return """
            Your register: a narrative coach. You speak in arcs — set the \
            scene, name the move, land the meaning. You quote the user's actual \
            words when you can. You frame growth as a story they're inside of, \
            not a metric. "Three weeks ago you couldn't hold a pause. Today, \
            you held four."
            """
        }
    }

    /// Fallback personality when the user hasn't picked a voice yet
    /// (very early onboarding). Calm, direct, and brand-aligned but
    /// not yet tuned to any specific voice.
    static let defaultCoachPersonality = """
    Your register: a calm, direct speaking coach. Steady and curious. You \
    favor specifics over generalities. You ask one question at a time. You \
    never gush.
    """

    // MARK: - User context block

    /// Structured snapshot of the user's current state. Composed once
    /// per chat exchange and passed to the model alongside the conversation
    /// history. Each line is something the model can quote back at the
    /// user; the goal is to make the chat feel like the coach actually
    /// knows them.
    ///
    /// Sections:
    ///   • GOAL — voice + onboarding goal text (if set)
    ///   • RATING — overall + week peak + weekly delta
    ///   • BASELINE — most-stable numbers (fillers/min, pace, pause rate)
    ///   • STREAK — current streak + reps this week
    ///   • RECENT — last 3 sessions: mode, score, fillers, duration
    ///   • PATH — current node title + mission position
    ///   • TRENDS — strengths + persistent blockers
    static func userContext(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        rating: SpeakingRating,
        sessions: [PracticeSession],
        currentStreak: Int,
        pathStatus: PathNodeStatus?,
        pathGatingPhrase: String?
    ) -> String {
        var lines: [String] = []
        lines.append("=== USER CONTEXT (read carefully) ===")

        // GOAL — the voice they're training toward + their stated reason
        if let profile = profile {
            lines.append("")
            lines.append("GOAL")
            let voiceTitle = profile.speakingStyleGoal.title
            let voiceDesc = profile.speakingStyleGoal.coachingDescription
            lines.append("- Voice: \(voiceTitle) — wants to \(voiceDesc).")
            if let paraphrase = profile.paraphrasedGoal,
               !paraphrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines.append("- In their words: \(paraphrase)")
            }
            let whyNow = profile.whyNowReference
            if !whyNow.isEmpty {
                lines.append("- Why now: \(whyNow)")
            }
        } else {
            lines.append("")
            lines.append("GOAL")
            lines.append("- No voice set yet. Treat this as cold start — gentle, curious.")
        }

        // RATING — overall + week peak + weekly delta
        lines.append("")
        lines.append("RATING")
        if rating.totalRatedSessions == 0 {
            lines.append("- No rated sessions yet.")
        } else {
            let tier = LeagueTier.tier(for: rating.overall).title
            lines.append("- Overall: \(rating.overall) (\(tier) tier).")
            lines.append("- Peak this week: \(rating.weekPeakRating).")
            let delta = rating.weeklyDelta
            if delta > 0 {
                lines.append("- Week-over-week: +\(delta).")
            } else if delta < 0 {
                lines.append("- Week-over-week: \(delta). (Do not lecture about this — acknowledge factually only if asked.)")
            } else {
                lines.append("- Week-over-week: flat.")
            }
            lines.append("- Total rated sessions: \(rating.totalRatedSessions).")
        }

        // BASELINE — the numbers you can actually quote
        lines.append("")
        lines.append("BASELINE (rolling, last 30 days)")
        if baseline.overallConfidence == .insufficient {
            lines.append("- Not enough data for a stable baseline yet.")
        } else {
            // Only quote stats with enough confidence to mean something —
            // skip insufficient ones rather than dumping noisy zeros.
            if baseline.averageScore.confidence != .insufficient {
                lines.append("- Average score: \(String(format: "%.1f", baseline.averageScore.value))/10.")
            }
            if baseline.fillerRate.confidence != .insufficient {
                lines.append("- Fillers per minute: \(String(format: "%.1f", baseline.fillerRate.value)).")
            }
            if baseline.pace.confidence != .insufficient {
                lines.append("- Pace: \(Int(baseline.pace.value.rounded())) WPM.")
            }
            if baseline.pauseRate.confidence != .insufficient {
                lines.append("- Pauses per minute: \(String(format: "%.1f", baseline.pauseRate.value)).")
            }
            if baseline.hedgingRate.confidence != .insufficient {
                lines.append("- Hedging rate: \(String(format: "%.1f", baseline.hedgingRate.value))/min (kind of, sort of, just).")
            }
        }

        // STREAK — habit signal
        lines.append("")
        lines.append("STREAK")
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let weeklyReps = sessions.filter { $0.date >= cutoff }.count
        lines.append("- Current streak: \(currentStreak) day\(currentStreak == 1 ? "" : "s").")
        lines.append("- Reps this week: \(weeklyReps).")

        // RECENT — last 3 sessions, so the coach can quote actual numbers
        let recent = Array(sessions.sorted { $0.date > $1.date }.prefix(3))
        if !recent.isEmpty {
            lines.append("")
            lines.append("RECENT (most-recent first)")
            for s in recent {
                let mode = s.mode.displayLabel
                let score = s.score.map { "\($0)/10" } ?? "no score"
                let fillers = "\(s.fillerWordCount) filler\(s.fillerWordCount == 1 ? "" : "s")"
                let duration = "\(Int(s.duration.rounded()))s"
                let day = recentDayLabel(for: s.date)
                lines.append("- \(day) · \(mode): \(score), \(fillers), \(duration).")
            }
        }

        // PATH — where they are in their journey
        if let status = pathStatus {
            lines.append("")
            lines.append("PATH")
            lines.append("- Chapter: \(status.node.tier.title).")
            lines.append("- Current mission: \(status.node.title).")
            if let phrase = pathGatingPhrase {
                lines.append("- Gating: \(phrase)")
            }
        }

        // TRENDS — what's working + what's not
        if !baseline.topStrengths.isEmpty || !baseline.persistentBlockers.isEmpty {
            lines.append("")
            lines.append("TRENDS")
            if !baseline.topStrengths.isEmpty {
                let s = baseline.topStrengths.prefix(3).joined(separator: ", ")
                lines.append("- Strengths: \(s).")
            }
            if !baseline.persistentBlockers.isEmpty {
                let b = baseline.persistentBlockers.prefix(3).joined(separator: ", ")
                lines.append("- Persistent blockers: \(b).")
            }
        }

        lines.append("")
        lines.append("=== END CONTEXT ===")
        return lines.joined(separator: "\n")
    }

    // MARK: - Session-anchored opener
    //
    // Produces the seed message the Summary surface drops into the Ask Noum
    // thread when the user taps "Talk to your coach about this rep." The
    // opener is written *as the user* (it lands in their thread as a user
    // turn) so the model reads it the same way it would read a typed
    // question. The shape names the rep by its concrete metrics + ends
    // with a voice-shaped invitation so the coach has a clear hook.
    //
    // Restraint rules:
    //   • One sentence summarising the rep numerically, one sentence asking
    //     for the coach's read. No fluff.
    //   • No "great rep" / "bad rep" framing — the opener is just data.
    //     The model decides the verdict from the data + context block.
    //   • Voice-shaped ending — authoritative gets a verdict ask, warm
    //     gets a felt-experience ask, executive gets a "brief me" framing.
    //     Same voice mapping pattern as `coachPersonality(for:)` and
    //     `starterPrompts(for:)`.
    //   • Score is optional — Ah-Counter sessions have no score; the
    //     opener degrades to a mode + duration + filler shape without it.
    static func sessionOpener(
        mode: PracticeMode,
        score: Int?,
        fillerCount: Int,
        duration: TimeInterval,
        voice: SpeakingStyleGoal?
    ) -> String {
        let modeLabel = mode.displayLabel
        let seconds = max(0, Int(duration.rounded()))
        let fillerFragment = "\(fillerCount) filler\(fillerCount == 1 ? "" : "s")"
        let stats: String
        if let score = score {
            stats = "\(seconds)s, \(fillerFragment), \(score)/10"
        } else {
            stats = "\(seconds)s, \(fillerFragment)"
        }
        let lead = "Just finished a \(modeLabel) rep — \(stats)."
        let ask: String
        switch voice {
        case .authoritative:
            ask = "Give me your read."
        case .warm:
            ask = "How did that one feel from your seat?"
        case .concise:
            ask = "One move?"
        case .persuasive:
            ask = "Walk me through what the data says."
        case .executive:
            ask = "Brief me — top line first."
        case .storytelling:
            ask = "Where does this one sit in my arc?"
        case .none:
            ask = "What stood out?"
        }
        return "\(lead) \(ask)"
    }

    // MARK: - Starter prompts (per-voice)

    /// Suggested starter prompts shown above the input bar when the
    /// chat is empty. Voice-specific so a user training authority
    /// sees authority-shaped starters; a user training warmth sees
    /// warmth-shaped ones. Limits buy-in friction — the first
    /// message is the hardest.
    static func starterPrompts(for goal: SpeakingStyleGoal?) -> [String] {
        let common: [String] = [
            "Why did my score change this week?",
            "Plan my next 7 days of practice.",
        ]
        let voice: [String]
        switch goal {
        case .authoritative:
            voice = [
                "I have a board pitch on Tuesday. Help me prep.",
                "What's the next move that builds my authority?",
            ]
        case .warm:
            voice = [
                "I have a 1-on-1 with my manager this week — help me sound warm.",
                "What's the next move that makes me easier to trust?",
            ]
        case .concise:
            voice = [
                "I rambled in my last rep — what cut it?",
                "What's the next move that sharpens me up?",
            ]
        case .persuasive:
            voice = [
                "I'm pitching to a sceptic on Thursday — prep me.",
                "What's the next move that strengthens my argument?",
            ]
        case .executive:
            voice = [
                "I have a 5-minute exec read-out next week — help me prep.",
                "What's the next move toward executive presence?",
            ]
        case .storytelling:
            voice = [
                "I want to open my next talk with a story — coach me.",
                "What's the next move that makes my reps more vivid?",
            ]
        case .none:
            voice = [
                "Where should I start with Noum?",
                "What's the next move I should make?",
            ]
        }
        return voice + common
    }

    // MARK: - Helpers

    /// "Today" / "Yesterday" / "Mon" / "Apr 14" — compact day label
    /// so the recent-sessions context is readable inside the prompt.
    private static func recentDayLabel(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let now = Date()
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        if days < 7 {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}

#endif
