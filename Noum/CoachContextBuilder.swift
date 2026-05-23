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
        - Stay under four short paragraphs. No headers. No bullet lists \
        unless the user explicitly asks for one. Cut any sentence that \
        does not cite the user's actual data or land a concrete move.

        Intelligence floor (this is what separates you from a generic \
        chatbot — every reply must clear it):
        1. Quote at least one concrete fact from CONTEXT — a baseline \
           number (fillers/min, pace, score, hedging), a streak day count, \
           a specific recent rep ("yesterday's Ah-Counter rep"), a path \
           mission, or a verbatim PROOF quote. Generic advice without a \
           cited fact reads as a GPT wrapper and fails this floor.
        2. Tie the answer to the user's chosen voice (the GOAL section). \
           A user training "authoritative" gets a verdict-shaped move; a \
           user training "warm" gets a felt-experience move. Same advice, \
           different register — your job is the register.
        3. End most replies with one concrete next move the user could do \
           in their next rep — not "keep working on it" or "try to be more \
           confident". A move names the action ("hold a 3-second pause \
           after your second sentence") or the rep ("do an Ah-Counter \
           round next, target under 4 fillers in 60 seconds").
        4. When the BIG MOMENT section is present, anchor at least one \
           specific concrete next move to the days remaining and the \
           category. Do not restate the moment — use it as gravity. A \
           board pitch in 6 days gets a different drill than a job \
           interview in 30 days.

        When the user asks "why did my score change" or any data-question, \
        you cite the actual delta + the dimension that moved it (not \
        generic advice about scores). When you cannot cite a fact because \
        the CONTEXT doesn't have it, you say "I don't have that data" — \
        you do not invent stats.

        If the user asks for a practice plan, give a concrete day-by-day \
        sequence (Mon: X, Tue: Y) tied to their goal and their weakest \
        baseline dimension — not generic week-of-practice advice.

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
    ///   • BIG MOMENT — upcoming high-stakes event (if active + ≤60 days)
    ///   • PLAN — current week of the active 4-week forward plan, with
    ///     progress + stale-warning when the plan no longer aligns with
    ///     the BigMoment that shaped it. Omitted when no plan exists.
    ///   • RATING — overall + week peak + weekly delta
    ///   • BASELINE — most-stable numbers (fillers/min, pace, pause rate)
    ///   • STREAK — current streak + reps this week
    ///   • RECENT — last 3 sessions: mode, score, fillers, duration
    ///   • PATH — current node title + mission position
    ///   • TRENDS — strengths + persistent blockers
    ///   • PROOFS — transcript-anchored evidence of growth (verbatim
    ///     quotes the user actually said in past reps). Omitted entirely
    ///     when no proofs exist so the model never invents one. Bounded
    ///     to the most-recent 3 — enough texture without crowding the
    ///     system prompt.
    static func userContext(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        rating: SpeakingRating,
        sessions: [PracticeSession],
        currentStreak: Int,
        pathStatus: PathNodeStatus?,
        pathGatingPhrase: String?,
        recentProofs: [ProofMomentRecord] = [],
        bigMoment: BigMoment? = nil,
        forwardPlan: ForwardPlan? = nil
    ) -> String {
        var lines: [String] = []
        lines.append("=== USER CONTEXT (read carefully) ===")

        // GOAL — the voice they're training toward + their stated reason
        // + dormant intake fields surfaced to give the coach real context.
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
            // successVision — user's own motivational anchor. Raw wording
            // preserved so the coach can quote it back.
            let vision = profile.successVisionReference
            if !vision.isEmpty {
                lines.append("- Their vision of success: \(vision)")
            }
            // biggestChallenge — what the user named as their primary problem.
            // Coach can open with "you said <X> is your enemy — here's what I saw."
            let challengeLabel = challengeDisplayLabel(profile.biggestChallenge)
            lines.append("- Their stated biggest challenge: \(challengeLabel)")
            // desiredOutcome — register-matching signal.
            lines.append("- Desired outcome: \(profile.desiredOutcome.title.lowercased())")
        } else {
            lines.append("")
            lines.append("GOAL")
            lines.append("- No voice set yet. Treat this as cold start — gentle, curious.")
        }

        // BIG MOMENT — only present when active + within 60 days.
        // When present, the coach should ground at least one concrete next
        // move in the days-remaining and category (rule 4 of intelligence floor).
        if let moment = bigMoment,
           let days = BigMomentStore.shared.daysUntil(moment),
           days >= 0 && days <= 60 {
            lines.append("")
            lines.append("BIG MOMENT")
            lines.append("- Preparing for: \(moment.title) (\(moment.category.displayName)). \(days) day\(days == 1 ? "" : "s") away.")
        }

        // PLAN — current week of the active forward plan + completed-vs-target
        // for the current week. Lets the coach say "your plan says X this week
        // and you're at 2 of 3 reps" without the user having to ask. Stale
        // plans (BigMomentID mismatch) are surfaced as a warning so the model
        // can suggest regeneration instead of quoting a plan no longer aligned
        // with the user's reality.
        if let plan = forwardPlan, let week = plan.currentWeek() {
            lines.append("")
            lines.append("PLAN")
            let isStale = plan.isInvalidated(by: bigMoment?.id)
            if isStale {
                lines.append("- Active plan is stale — the user's big moment changed since generation. Recommend regenerating before quoting this plan as current.")
            }
            lines.append("- Week \(week.weekIndex) of 4 focus: \(week.focusSkillArea.displayName) via \(week.suggestedMode.displayLabel).")
            lines.append("- Why this week: \(week.rationale)")
            let progress = ForwardPlanProgress.currentWeekProgress(plan: plan, sessions: sessions)
            if let progress {
                lines.append("- Progress: \(progress.completed) of \(progress.target) rep\(progress.target == 1 ? "" : "s") this week.")
            }
        }

        // RATING — overall + week peak + weekly delta + derived confidence
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
            // Derived confidence — computed from recent session history.
            // Overrides the stale onboarding self-report: a user who was
            // "beginner" at sign-up but is averaging 8/10 over 10 sessions
            // should be coached as confident, not as a beginner.
            let derived = derivedConfidenceLabel(baseline: baseline, sessions: sessions)
            lines.append("- Derived confidence: \(derived)")
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

        // PROOFS — verbatim moments from the user's actual reps. Lets the
        // model quote the user's own words back ("Three weeks ago you
        // said 'we focused on three priorities' — that's the move you've
        // been refining") rather than relying on numbers alone. Hard cap
        // at 3 so the system prompt stays bounded.
        let proofs = recentProofs
            .sorted { $0.proof.sessionDate > $1.proof.sessionDate }
            .prefix(3)
        if !proofs.isEmpty {
            lines.append("")
            lines.append("PROOFS (verbatim moments from past reps — quote these directly when relevant)")
            for record in proofs {
                let day = recentDayLabel(for: record.proof.sessionDate)
                let technique = record.proof.technique
                let quote = record.proof.quote
                lines.append("- \(day) · \(technique): \"\(quote)\"")
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

    // MARK: - Follow-up suggestions (post-reply)
    //
    // Shown as quiet chips beneath the most-recent coach reply inside
    // `AskNoumView`. Different register from `starterPrompts`: starters
    // are first-message friction-removers shown above an empty input
    // bar; follow-ups are "keep the thread alive" nudges shown after
    // a real reply lands. Three short voice-shaped options is the
    // sweet spot — fewer than that reads as random; more crowds the
    // thread and starts to feel like a quiz.
    //
    // Topic detection rules:
    //   • Lightweight, deterministic, case-insensitive substring match
    //     on the coach's last reply. No NLP, no per-token analysis —
    //     the chips are nudges, not a parsed response.
    //   • Order of detection is intentional. We pick at most ONE topic
    //     to anchor the chips; the rest fall back to voice-default
    //     evergreen prompts. Anchoring on the first detected topic
    //     keeps the chips coherent (three chips about three different
    //     things would read as scattershot).
    //   • Topics intentionally narrow to surfaces the coach actually
    //     talks about: drills, pauses, pace, fillers, weekly cadence,
    //     and a generic "next move" fallback. Adding a topic means
    //     adding chips that read in every voice — we keep the catalog
    //     tight on purpose.
    //
    // Restraint contract:
    //   • If the reply is empty (e.g. mid-pending state, never
    //     happens in practice but defensively safe), return an empty
    //     array — `AskNoumView` collapses the chip row entirely.
    //   • Voice-shaped — six voices + nil fallback. Every voice
    //     handled; the test suite asserts this.
    //   • No exclamations, no "Let's", no emoji — same brand rules
    //     as everywhere else on the surface.
    static func followUpSuggestions(
        forCoachReply reply: String,
        voice: SpeakingStyleGoal?
    ) -> [String] {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let topic = detectFollowUpTopic(in: trimmed)
        return followUpChips(for: topic, voice: voice)
    }

    /// Detected anchor for follow-up shaping. Internal — only
    /// `followUpSuggestions` and its tests need this.
    enum FollowUpTopic: Equatable {
        /// Coach recommended a specific drill / move / exercise.
        case drillMentioned
        /// Coach quoted a pause or "pause" mechanic.
        case pauseMentioned
        /// Coach talked about pace / WPM / speed / rushing / slowing.
        case paceMentioned
        /// Coach quoted fillers / "um" / "uh" / hedging.
        case fillerMentioned
        /// Coach framed in terms of the week or a 7-day plan.
        case weeklyMentioned
        /// Generic — no specific anchor; voice-default evergreen chips.
        case generic
    }

    static func detectFollowUpTopic(in reply: String) -> FollowUpTopic {
        let lower = reply.lowercased()
        // Order matters — we anchor on the FIRST detected topic. Drills
        // and pauses are the most concrete coach recommendations, so
        // they take priority over more general framings.
        if lower.contains("drill") || lower.contains("exercise") || lower.contains("try this") {
            return .drillMentioned
        }
        if lower.contains("pause") || lower.contains("silence") || lower.contains("breath") {
            return .pauseMentioned
        }
        if lower.contains("pace") || lower.contains("wpm") || lower.contains("slow") || lower.contains("rush") {
            return .paceMentioned
        }
        if lower.contains("filler") || lower.contains("\"um") || lower.contains("\"uh") || lower.contains(" um ") || lower.contains(" uh ") {
            return .fillerMentioned
        }
        if lower.contains("this week") || lower.contains("next week") || lower.contains("7 days") || lower.contains("seven days") {
            return .weeklyMentioned
        }
        return .generic
    }

    private static func followUpChips(for topic: FollowUpTopic, voice: SpeakingStyleGoal?) -> [String] {
        // Each voice gets a register that matches its `coachPersonality`
        // and `starterPrompts` shape. Three chips per (topic, voice)
        // cell — kept short (<= ~10 words) so they read as quick
        // nudges, not paragraphs the user has to parse.
        switch topic {
        case .drillMentioned:
            return drillFollowUps(voice: voice)
        case .pauseMentioned:
            return pauseFollowUps(voice: voice)
        case .paceMentioned:
            return paceFollowUps(voice: voice)
        case .fillerMentioned:
            return fillerFollowUps(voice: voice)
        case .weeklyMentioned:
            return weeklyFollowUps(voice: voice)
        case .generic:
            return genericFollowUps(voice: voice)
        }
    }

    private static func drillFollowUps(voice: SpeakingStyleGoal?) -> [String] {
        switch voice {
        case .authoritative:
            return ["Show me an example.", "How will I know I nailed it?", "What's the failure mode?"]
        case .warm:
            return ["Can you walk me through it?", "What does it feel like when it lands?", "Why this drill for me?"]
        case .concise:
            return ["Show me one example.", "Success looks like what?", "Any common pitfall?"]
        case .persuasive:
            return ["Walk me through the reasoning.", "What does success look like?", "What's the risk if I skip it?"]
        case .executive:
            return ["Top line: what does success look like?", "Brief me on the failure mode.", "Time to noticeable result?"]
        case .storytelling:
            return ["Tell me a rep that nailed this.", "What does the moment feel like?", "Where does this fit in my arc?"]
        case .none:
            return ["Show me an example.", "How will I know it worked?", "Why this one?"]
        }
    }

    private static func pauseFollowUps(voice: SpeakingStyleGoal?) -> [String] {
        switch voice {
        case .authoritative:
            return ["What's the right length?", "When should I deploy it?", "What kills a pause?"]
        case .warm:
            return ["How long should it feel?", "When do pauses help me trust myself?", "What makes a pause land?"]
        case .concise:
            return ["How long?", "Where to drop one?", "What makes it work?"]
        case .persuasive:
            return ["What makes a pause persuasive?", "When does it lose power?", "How long is right?"]
        case .executive:
            return ["Recommend: how long, where, why?", "When does a pause backfire?", "One pause technique to drill?"]
        case .storytelling:
            return ["When does a pause carry the scene?", "How long should it feel?", "A rep where my pause worked?"]
        case .none:
            return ["How long should a pause be?", "When should I use one?", "What kills a pause?"]
        }
    }

    private static func paceFollowUps(voice: SpeakingStyleGoal?) -> [String] {
        switch voice {
        case .authoritative:
            return ["What's my target pace?", "How do I lock it in?", "When am I rushing?"]
        case .warm:
            return ["What pace sounds warmest?", "How do I notice when I drift?", "What slows me down naturally?"]
        case .concise:
            return ["Target WPM?", "How to lock it?", "What drift to watch?"]
        case .persuasive:
            return ["What pace persuades?", "How does pace shift the listener?", "What's my drift pattern?"]
        case .executive:
            return ["Target pace for an exec read-out?", "What drift signals do I have?", "Tactic to lock it?"]
        case .storytelling:
            return ["What pace carries a story?", "When does my pace flatten the scene?", "How do I gear-shift mid-rep?"]
        case .none:
            return ["What pace should I target?", "How do I notice when I'm rushing?", "What's the fix?"]
        }
    }

    private static func fillerFollowUps(voice: SpeakingStyleGoal?) -> [String] {
        switch voice {
        case .authoritative:
            return ["What replaces a filler?", "When do mine cluster?", "Drill that cuts them fastest?"]
        case .warm:
            return ["Why do I reach for fillers?", "How do I forgive myself when one slips?", "A drill that makes pauses feel natural?"]
        case .concise:
            return ["Best filler-cut drill?", "When do mine cluster?", "Replacement move?"]
        case .persuasive:
            return ["How do fillers weaken the case?", "Replacement moves that strengthen it?", "When do mine cluster?"]
        case .executive:
            return ["Recommend: top filler-cut move.", "When do mine cluster?", "Acceptable filler rate for exec?"]
        case .storytelling:
            return ["Do fillers break the scene?", "A rep where my fillers vanished?", "Move that replaces them?"]
        case .none:
            return ["What replaces a filler?", "When do mine cluster?", "Best drill to cut them?"]
        }
    }

    private static func weeklyFollowUps(voice: SpeakingStyleGoal?) -> [String] {
        switch voice {
        case .authoritative:
            return ["Lock in the plan.", "What's the must-hit rep?", "How do I measure success?"]
        case .warm:
            return ["Which rep matters most this week?", "How do I make this stick?", "What if I miss a day?"]
        case .concise:
            return ["Must-hit rep?", "How to measure?", "If I miss a day?"]
        case .persuasive:
            return ["Why this sequence?", "Which rep moves the needle most?", "How do I measure week-over-week?"]
        case .executive:
            return ["Top priority rep?", "Success metric for the week?", "Risk if a day slips?"]
        case .storytelling:
            return ["What chapter is this week?", "Which rep is the turning point?", "What does the end of the week look like?"]
        case .none:
            return ["Which rep matters most?", "How do I measure progress?", "What if I miss a day?"]
        }
    }

    private static func genericFollowUps(voice: SpeakingStyleGoal?) -> [String] {
        switch voice {
        case .authoritative:
            return ["Give me the next move.", "What am I missing?", "What's the leverage point?"]
        case .warm:
            return ["Tell me more.", "What should I notice next?", "Where am I growing right now?"]
        case .concise:
            return ["Next move?", "What am I missing?", "Where's the leverage?"]
        case .persuasive:
            return ["Walk me through the reasoning.", "What's the strongest signal in my data?", "Where am I underweighting?"]
        case .executive:
            return ["Top line: next move?", "Brief me on the leverage point.", "What am I underweighting?"]
        case .storytelling:
            return ["Where am I in the arc?", "What's the next chapter?", "Which rep was the turning point?"]
        case .none:
            return ["What's the next move?", "Tell me more.", "Where should I focus?"]
        }
    }

    // MARK: - AI-tailored follow-up chips (post-reply)
    //
    // Sibling to `followUpSuggestions` — same surface, same shape (three
    // short tappable nudges below the coach reply), but the strings are
    // model-generated against the actual last-user-turn + last-coach-reply
    // + voice tone. Lets the chips read as "the coach knows what you just
    // said" rather than a catalog draw.
    //
    // Contract:
    //   • Returns nil on any cold path — no provider, network failure,
    //     locale-blocked, model returned empty/unparseable output, or any
    //     chip fails the brand-voice filter. AskNoumView keeps the
    //     deterministic chips visible during the request and reuses them
    //     unchanged on nil — chips never disappear mid-conversation.
    //   • Returns exactly `count` chips on success (default 3). Each chip
    //     trimmed, ≤ ~60 chars, no exclamation marks, no emoji, no leading
    //     "Let's" / "Tell me" directives — same voice rules as everywhere
    //     else on the surface.
    //   • Bounded request — temperature 0.7 (mild variety, not random),
    //     short max-tokens because the output is ~30 tokens of text.
    //   • Same provider plumbing as `AICoachChatService` (OpenAI / DeepSeek
    //     / Gemini via `AISettingsManager`). Locale-gated identically.
    //
    // Why not extend AICoachChatService instead of a sibling function: the
    // chat service is request-shaped around conversation replay (history
    // + system prompt + user context block). Chip generation is a one-shot
    // text gen with no replay, a different system prompt, a much smaller
    // token budget, and a content filter unique to chip shape. Routing it
    // through the chat service would force a fake "history" parameter and
    // overload the failure types (a chip-gen failure is not a "coach reply
    // failure" the store needs to surface). A small standalone function in
    // CoachContextBuilder keeps the chips co-located with their
    // deterministic catalog — every reader sees both paths in one file.
    static func generateAIFollowUpChips(
        lastUserTurn: String,
        lastCoachReply: String,
        voice: SpeakingStyleGoal?,
        count: Int = 3
    ) async -> [String]? {
        let trimmedReply = lastCoachReply.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTurn = lastUserTurn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReply.isEmpty, !trimmedTurn.isEmpty else { return nil }

        // Locale + provider gates first — match what AICoachChatService
        // and AIPromptGeneratorService do. Reading state on the main
        // actor since both stores live there.
        guard await activeLocaleSupportsAI() else { return nil }
        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider) else { return nil }

        let system = aiChipsSystemPrompt
        let user = aiChipsUserPrompt(
            lastUserTurn: trimmedTurn,
            lastCoachReply: trimmedReply,
            voice: voice,
            count: count
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Tight timeout — chips are a fast-path nice-to-have; a stalled
        // request shouldn't keep the network in flight while the user is
        // already reading the deterministic fallback.
        request.timeoutInterval = 8

        do {
            switch provider {
            case .none:
                return nil
            case .openAI, .deepSeek:
                request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
                let body: [String: Any] = [
                    "model": provider.model,
                    "temperature": 0.7,
                    // Small budget — 3 short chips on separate lines
                    // is well under 80 tokens. Caps an over-eager
                    // model that wants to write a paragraph.
                    "max_tokens": 120,
                    "messages": [
                        ["role": "system", "content": system],
                        ["role": "user", "content": user]
                    ]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            case .gemini:
                request.setValue(key, forHTTPHeaderField: "x-goog-api-key")
                let body: [String: Any] = [
                    "systemInstruction": ["parts": [["text": system]]],
                    "contents": [["role": "user", "parts": [["text": user]]]],
                    "generationConfig": [
                        "temperature": 0.7,
                        "maxOutputTokens": 120
                    ]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            guard let raw = extractAIChipsText(from: data, provider: provider) else { return nil }
            return parseAndFilterChips(raw, count: count)
        } catch {
            return nil
        }
    }

    private static let aiChipsSystemPrompt = """
    You generate short tap-to-continue follow-up prompts for a speaking-coach \
    chat surface. Each prompt is written AS THE USER asking their coach the \
    next question — second person, direct.

    Hard rules (every output must clear all of these):
    - Exactly the requested number of prompts. One per line. No numbering, no \
    bullets, no quotes, no JSON, no preface.
    - Each prompt ≤ 8 words.
    - Sentence case. No emoji. No exclamation marks. No "Let's".
    - No leading directive verbs like "Tell me", "Describe", "Explain", \
    "Discuss" — write as the user's own question or short ask.
    - Tailor to the last coach reply + last user turn + the voice tone. A \
    user training authoritative gets verdict-shaped follow-ups; warm gets \
    felt-experience asks; concise gets clipped asks; persuasive gets \
    reasoning asks; executive gets top-line asks; storytelling gets \
    arc-shaped asks.
    - If the coach asked the user a question, at least one of your prompts \
    should help the user answer or push back on it.
    - Output only the prompts themselves, separated by newlines.
    """

    private static func aiChipsUserPrompt(
        lastUserTurn: String,
        lastCoachReply: String,
        voice: SpeakingStyleGoal?,
        count: Int
    ) -> String {
        let voiceLine = voice.map { "Voice tone: \($0.title)." } ?? "Voice tone: not set — keep calm and direct."
        return """
        \(voiceLine)

        Last user turn:
        \"\"\"
        \(lastUserTurn)
        \"\"\"

        Last coach reply:
        \"\"\"
        \(lastCoachReply)
        \"\"\"

        Return exactly \(count) follow-up prompts, one per line.
        """
    }

    private static func extractAIChipsText(from data: Data, provider: AIProvider) -> String? {
        switch provider {
        case .none: return nil
        case .openAI, .deepSeek:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let choices = object["choices"] as? [[String: Any]],
                let first = choices.first,
                let message = first["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return nil }
            return content
        case .gemini:
            guard
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let candidates = object["candidates"] as? [[String: Any]],
                let first = candidates.first,
                let content = first["content"] as? [String: Any],
                let parts = content["parts"] as? [[String: Any]]
            else { return nil }
            return parts.compactMap { $0["text"] as? String }.joined(separator: "\n")
        }
    }

    /// Parse the model's newline-separated chip output, apply brand-voice
    /// rules per chip, and return exactly `count` chips. Returns nil if
    /// fewer than `count` chips survive filtering — the caller's
    /// deterministic fallback is better than a partial set.
    ///
    /// Exposed `internal` (default) so the test suite can exercise the
    /// filter shape without needing a provider stub.
    static func parseAndFilterChips(_ raw: String, count: Int) -> [String]? {
        let lines = raw
            .components(separatedBy: CharacterSet.newlines)
            .map { line -> String in
                var t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                // Strip common list-marker prefixes a model might add.
                while let first = t.first, "-*•".contains(first) {
                    t = String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
                }
                // Strip numeric "1. " / "2) " enumeration if present.
                if let match = t.range(of: #"^\d+[.)]\s+"#, options: .regularExpression) {
                    t.removeSubrange(match)
                }
                // Strip wrapping quotes / smart quotes if present.
                if (t.hasPrefix("\"") && t.hasSuffix("\""))
                    || (t.hasPrefix("\u{201C}") && t.hasSuffix("\u{201D}")) {
                    if t.count >= 2 {
                        t = String(t.dropFirst().dropLast())
                    }
                }
                return t.trimmingCharacters(in: .whitespaces)
            }
            .filter { passesChipFilter($0) }

        guard lines.count >= count else { return nil }
        return Array(lines.prefix(count))
    }

    /// Per-chip brand-voice filter. Mirrors the everywhere-else rules:
    /// no exclamations, no emoji, no "Let's", no leading directives, no
    /// runaway-length copy. Anything that fails is dropped — the caller
    /// gates on chip count to decide whether to honour the AI batch.
    private static func passesChipFilter(_ chip: String) -> Bool {
        guard !chip.isEmpty else { return false }
        // 4–60 chars covers "Next move?" up to ~8 words; longer than
        // that no longer reads as a quick tap.
        guard (4...60).contains(chip.count) else { return false }
        // No exclamation marks — brand voice ban.
        if chip.contains("!") { return false }
        // No emoji — brand voice ban. Quick category check covers most
        // graphic Unicode (Symbol + Pictograph + Misc Symbols + Emoji
        // Presentation default-encoded chars).
        for scalar in chip.unicodeScalars {
            if scalar.properties.isEmoji && scalar.value > 0x238C {
                return false
            }
        }
        let lower = chip.lowercased()
        if lower.hasPrefix("let's ") || lower.hasPrefix("lets ") { return false }
        let leadingDirectives = [
            "tell me ", "describe ", "explain ", "discuss ", "elaborate ",
            "share ", "talk about "
        ]
        if leadingDirectives.contains(where: { lower.hasPrefix($0) }) { return false }
        return true
    }

    // MARK: - Provider plumbing (shared with AICoachChatService /
    // AIPromptGeneratorService). Tiny shims rather than a shared helper
    // because the call sites are simple and the abstraction would obscure
    // the actor boundaries.

    @MainActor
    private static func currentProvider() -> AIProvider? {
        AISettingsManager.shared.activeProvider
    }

    @MainActor
    private static func activeLocaleSupportsAI() -> Bool {
        LocaleSettingsManager.shared.current.aiSupported
    }

    private static func apiKey(for provider: AIProvider) -> String? {
        guard let keyName = provider.environmentKey else { return nil }
        if let value = ProcessInfo.processInfo.environment[keyName], !value.isEmpty {
            return value
        }
        return LocalConfigLoader.value(forKey: keyName, plistNamed: "AIConfig")
    }

    // MARK: - Derived confidence

    /// Computes a confidence label from session history rather than the
    /// stale onboarding self-report. Uses `baseline.averageScore` when
    /// reliable (≥ initial confidence threshold), otherwise falls back
    /// to the last 10 rated sessions, then to the static profile field.
    static func derivedConfidenceLabel(
        baseline: CommunicationBaseline,
        sessions: [PracticeSession]
    ) -> String {
        // Prefer the rolling baseline average when it has enough confidence.
        if baseline.averageScore.confidence != .insufficient {
            let avg = baseline.averageScore.value
            if avg >= 7.5 { return "confident" }
            if avg <= 5.0 { return "rebuilding" }
            return "developing"
        }
        // Fall back to raw session scores when baseline isn't stable yet.
        let scores = sessions
            .compactMap(\.score)
            .prefix(10)
            .map(Double.init)
        guard !scores.isEmpty else { return "unknown" }
        let avg = scores.reduce(0, +) / Double(scores.count)
        if avg >= 7.5 { return "confident" }
        if avg <= 5.0 { return "rebuilding" }
        return "developing"
    }

    /// Short coach-readable label for a `SpeakingChallenge`.
    /// Uses a brief noun phrase so the coach context stays scannable:
    /// "freezing" reads faster than "I blank when I'm put on the spot."
    static func challengeDisplayLabel(_ challenge: SpeakingChallenge) -> String {
        switch challenge {
        case .fillerWords: return "filler words"
        case .rambling:    return "rambling"
        case .freezing:    return "freezing"
        case .rushing:     return "rushing"
        }
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
