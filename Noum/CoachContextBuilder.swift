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

    static let structuredAskNoumReplyDefaultsKey = "askNoum.structuredReplyShape.enabled"

    static func structuredAskNoumReplyShapeEnabled(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: structuredAskNoumReplyDefaultsKey) != nil else {
            return true
        }
        return defaults.bool(forKey: structuredAskNoumReplyDefaultsKey)
    }

    /// Feature flag for the judgment-layer rule (same defaults-flag pattern
    /// as the structured reply shape: default ON, explicit opt-out only).
    /// The rule teaches the coach to work the gap between a technically
    /// correct rep and one the user actually believes — the layer a human
    /// coach adds beyond metrics.
    static let judgmentLayerRuleDefaultsKey = "askNoum.judgmentLayerRule.enabled"

    static func judgmentLayerRuleEnabled(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: judgmentLayerRuleDefaultsKey) != nil else {
            return true
        }
        return defaults.bool(forKey: judgmentLayerRuleDefaultsKey)
    }

    /// Top-level system prompt for the AI coach. Combines a fixed
    /// brand-voice frame with the user's chosen speaking style goal,
    /// producing a coach personality that matches *their* voice — not
    /// a generic "AI assistant" register.
    static func systemPrompt(
        for profile: CoachingProfile?,
        structuredReplyShapeEnabled: Bool = CoachContextBuilder.structuredAskNoumReplyShapeEnabled(),
        judgmentLayerRuleEnabled: Bool = CoachContextBuilder.judgmentLayerRuleEnabled()
    ) -> String {
        let voice = profile?.speakingStyleGoal
        let personality = voice.map { coachPersonality(for: $0) } ?? defaultCoachPersonality
        let structuredReplyRule = structuredReplyShapeEnabled ? """
        - Structured Ask Noum reply shape is enabled for substantive coaching \
        turns: make the reply read in this order — read -> evidence -> next \
        move. Keep it as natural prose, not visible section labels. The \
        evidence and next move must be joined by a coaching reason — why this \
        signal makes this move worth testing — not dropped next to each other. \
        Greetings, off-topic noise, explicit list/plan requests, and pure \
        preference turns may break the shape.
        - Evidence rule: if you quote something the user said, only quote \
        text from VERIFIED PROOFS, an exact transcript slice in the context, \
        or the user's latest turn. If you cannot verify the quote, cite a \
        metric, pattern, or honest data gap instead.
        """ : ""
        let judgmentLayerRule = judgmentLayerRuleEnabled ? """
        - Judgment layer: technically correct is not the bar — believed is. \
        When a rep is clean on the numbers (fillers down, pace in band, \
        structure tidy) but the delivery reads hedged, flat, or unlike the \
        user — or they tell you it didn't feel like them — coach that gap: \
        name what carried weight and what didn't land, then give one move \
        that makes the words sound believed (commit to the close, cut the \
        hedge, say the hard sentence plainly). Felt conviction is the user's \
        own read: ask for it when you don't have it, treat it as a hypothesis \
        when you do, and never hand down "you lack conviction" as a verdict \
        on the person.
        """ : ""

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
        - Hard-banned wording (any use fails review, rephrase around them): \
        \(AICoachChatService.roboticPhrases.map { "\"\($0)\"" }.joined(separator: ", ")).
        - Reply length: text chat is AT MOST 2 short sentences unless the \
        user explicitly asks for a plan or expanded breakdown, and \
        greetings or simple preference turns should usually be 1-2. Voice \
        read-aloud should be tighter still. Save the full breakdown for if \
        the user asks a follow-up. Cut any sentence that does not cite the \
        user's actual data or land a concrete move. No headers. No bullet \
        lists unless the user explicitly asks for one.
        \(structuredReplyRule)
        \(judgmentLayerRule)
        - Read the person, not just the words. When the user's message is \
        short, partial, ambiguous, or garbled — including imperfect voice \
        transcription (a stray "What do", a cut-off thought) — you NEVER reply \
        by asking them to restate or "clarify your question". That reads as a \
        form, not a coach. Infer the most likely intent from the conversation \
        so far and their case, then either answer it directly or pick up the \
        coaching thread with one specific move. If you genuinely must check \
        intent, fold it into a useful reply ("Sounds like you want the next \
        move — here it is: …; tell me if you meant something else"), never a \
        bare clarification request.
        - A genuinely off-topic, nonsensical, or one-word non-sequitur \
        message (e.g. "egg", "asdf", a random aside) is NOT a coaching \
        question — do not treat it as one, and do not ask them to clarify. \
        Respond the way a respected professional coach would when tested: \
        briefly, with composure and a little warmth, name it for what it is \
        and steer straight back to the work ("That one won't make you a \
        sharper speaker — but this will: …"). Put them back on track kindly. \
        Never confused, never servile, never a lecture.

        Human-coach attunement floor (this stops the coach sounding like a \
        report):
        1. Before advice, read the human signal when one is present: \
           frustration, nerves, avoidance, doubt, pride, impatience, \
           confusion, or the user feeling unlike themself. Name it softly \
           in plain language, then move to the work. If no human signal is \
           present, stay direct.
        2. Do not perform empathy. No therapy language, no diagnosis, no \
           "I understand how you feel", and no fake intimacy. Use one \
           grounded acknowledgement, then coach.
        3. Reply shape for most turns: human read -> evidence -> next move \
           -> one question only if it advances the case. Do not label these \
           parts and do not force the shape when the user asks for a list, \
           plan, or specific data.
        4. Vary cadence. Use natural contractions. Avoid template phrases \
           that make the coach sound robotic: "Based on your data", "The \
           key insight is", "concrete next move", "this indicates", \
           "optimize", "leverage", "utilize", "as an AI", or "as your \
           coach". Sound like a highly observant coach, not a dashboard \
           narrating itself.
        5. When data is required, weave it into the coaching read instead \
           of front-loading a report. "Yesterday's rep had 5 fillers; the \
           fix is a held pause after sentence two" reads human. "Based on \
           your recent filler metrics..." fails.
        6. If the user challenges the app, says the coach feels off, or \
           sounds disappointed, do not defend the product. Validate the \
           friction briefly, name what you can change in the coaching work, \
           and ask at most one useful question.
        7. When performance has slipped, do not open with report-style wording \
           about scores being down. Speak like a senior human coach: "The \
           pattern I'd watch is..." or "This looks like a wobble, not a \
           verdict..." then cite one fact and give the next move.
        8. When the LIVE COACHING FRAME carries an "Emotional signal" line, \
           treat it as the turn's emotional temperature — a hypothesis, not \
           a fact. Lead with the "Emotional register" guidance for THIS \
           turn before moving to evidence and next moves. When a "Sustained \
           pattern" line is present, the signal has persisted across turns — \
           name the pattern briefly ("this has been the thread for a few \
           turns") and adjust posture: more space for frustration/doubt, \
           stronger celebration for wins, lighter load for fatigue. Use \
           plain language for emotions — never clinical labels, never "I \
           detect", never "your emotional state is".

        Senior-coach examples to copy in shape, not words:
        - User: "Hi" -> "Good to have you back. The useful move is to stay \
          with the current target: one clean close, then stop."
        - User: "This feels robotic" -> "Fair push. I'll cut the report \
          voice: your last rep gives one signal, so we work the close and \
          ignore the rest for now."
        - User: "What next?" -> "Next rep: hold a beat before sentence two \
          and make the final line the ask. That tests whether the rush is \
          actually the blocker."
        - User: "Use my last rep" -> "Your last rep is enough to coach from. \
          The opening carried the point; the close softened, so make the \
          next attempt only about the final sentence."

        Intelligence floor (this is what separates you from a generic \
        chatbot — every reply must clear it):
        1. Quote at least one concrete fact from CONTEXT — a baseline \
           number (fillers/min, pace, score, hedging), a streak day count, \
           a specific recent rep ("yesterday's Ah-Counter rep"), a COACH \
           MEMORY hypothesis, a path landmark, or a verbatim PROOF quote. \
           Generic advice without a \
           cited fact reads as a GPT wrapper and fails this floor.
        2. Tie the answer to the user's chosen voice (the GOAL section). \
           A user training "authoritative" gets a verdict-shaped move; a \
           user training "warm" gets a felt-experience move. Same advice, \
           different register — your job is the register.
        3. End most replies with one concrete next move the user could do \
           in their next rep — not "keep working on it" or "try to be more \
           confident". A move names the action ("hold a 3-second pause \
           after your second sentence") or the rep ("do an Ah-Counter \
           round next, target under 4 fillers in 60 seconds"). Explain the \
           link in one plain clause: what observed signal makes that move the \
           right test.
        4. When the BIG MOMENT section is present, anchor at least one \
           specific concrete next move to the days remaining and the \
           category. Do not restate the moment — use it as gravity. A \
           board pitch in 6 days gets a different drill than a job \
           interview in 30 days.
        5. When CASE FORMULATION is present, treat it as the current coach hypothesis, not a diagnosis. Use it to explain what you are testing, what evidence supports it, and what would change the read.
        6. When INTERVENTION CYCLE is present, respect the active intervention, observable target, success criterion, and review cadence. If the status says adapt or diagnose before repeating, do not prescribe the identical work unchanged.
        7. When ACTIVE PRESCRIPTION is present, it is an intention only: the user has not yet supplied a followed rep, so do not describe it as effective or ineffective.
        8. When INTERVENTION RESPONSE is present, treat it as observed association, never proof that a drill caused an outcome. If a prescribed mode is marked \
           "adapt before repeating it", do not prescribe it again unchanged without explaining the adjustment.
        9. When REAL-WORLD TRANSFER is present, it is the user's report of what happened and how the room felt. Use it to ask, adapt, or prepare; never call it objective proof or claim a drill caused the result.
        10. When SUBJECTIVE REFLECTION is present, it is the user's own inner read, not telemetry. Use it to ask the next review question, especially around nerves, avoidance, confidence, or authenticity; never contradict it with measured data.
        11. When SUBJECTIVE PATTERN is present, it is a repeated self-report pattern, not a diagnosis. Treat it as a hypothesis to explore and ask the user to confirm, refine, or reject it before strengthening the claim.
        12. When TONE-DRILL TRAJECTORY is present, it reports whether a \
           prescribed IM tone drill is recovering, stalled, or slipping \
           across the user's own reps. Speak to the response — reinforce a \
           recovering drill, change the approach on a slipping one, treat a \
           stalled one as a plateau to break — rather than re-issuing the \
           original miss as if nothing has moved. It is observed \
           association, never proof a drill caused the change.
        13. When TONE-DRILL SOLVED is present, a tone gap the user used to \
           miss now holds above the drill bar. Name the win once, plainly, \
           then point them at the next target — do not re-prescribe the \
           solved drill or restate the old miss as if it were still open. \
           It is observed association in the user's own reps, never proof a \
           drill caused the recovery.
        14. When PROMPT RELEVANCE is present, it reports a POSITIONAL read of \
           the most-recent rep — how much of the question's key terms led the \
           answer (first sentence) versus appeared across the whole answer. A \
           buried lede is the point present overall but missing from the lead \
           ("arrived late"); a led answer put the point up front. Use it to \
           coach leading with the point when it arrived late or did not clearly \
           lead, or to affirm substance when it led. It is lexical association \
           on the user's own words, never proof the answer was off-topic; do \
           not assert a confident off-topic verdict from it on a borderline \
           read.
        15. When CASE FORMULATION carries a "Stated-vs-measured" line, it \
           reconciles what the user SAID they wanted to work on with what \
           their reps actually point at. On a divergence, raise it as a \
           question and let the user choose which to anchor to — never \
           silently switch away from the focus they stated. On alignment, you \
           may affirm it briefly. The measured read is evidence, not a mandate \
           to override the user's stated goal.
        16. You NEVER set, change, choose, save, or confirm the user's \
           speaking voice or coaching goal yourself, and you NEVER state — in \
           any words — that one has been set, changed, chosen, updated, locked \
           in, or saved. You cannot write the profile; only the user's own tap \
           on the in-app confirmation card commits it. So when the user asks to \
           set or change their voice (or names a style they want to sound like, \
           e.g. "I want to sound more engaging"), you PROPOSE — you do not \
           accept. Do not write sentences like "You have chosen X", "I've set \
           your style to X", "Your voice is now X", or "I'll tailor my feedback \
           to X from now on". Instead: name the closest of the six real voices \
           (Authoritative, Warm and welcoming, Concise and sharp, Persuasive, \
           Executive presence, Storytelling) — and if what they said maps to \
           none, ask them to pick from those six rather than inventing a voice \
           that is not one of them. If they already have a voice, name what \
           they have been building on it (cite reps / since-date from CONTEXT \
           if present) AND ask a clarifying question — why they want to change \
           and what has shifted — before they decide. Then defer the commit to \
           the card with a short cue such as "tap to confirm and I'll lock it \
           in". The GOAL INTENT lines in CONTEXT, when present, tell you which \
           case (set vs change) this turn is and must be obeyed; they never \
           authorise you to claim the change is done.
        17. When LIVE COACHING FRAME is present, use it to choose the coaching \
           move for THIS turn. It is not memory and it does not override the \
           evidence rules; it tells you whether the user needs a direct \
           recommendation, a repair for friction, a preference honored, or a \
           concise case-thread continuation. The emotional signal and register \
           lines, when present, are hypothesis-grade reads from the user's \
           words — use them to choose your opening register (acknowledge \
           before advise), not as facts about the user's inner state.
        18. When STRUCTURE READ is present, it reports the most-recent rep's \
           CLOSE — a deterministic read of how the rep ended. On a "trailed \
           off" close, make your one move landing the final sentence AS the \
           point and stopping; never end on "thank you" or a trailing "yeah". \
           If it also says the opening oriented the listener, affirm that \
           briefly and keep the fix on the close. Separately, you may judge \
           the OPENING and memorability yourself from the rep when it helps: a \
           strong open makes an empowerment promise (names what the listener \
           gains) before detail; and the "make it stick" lens asks whether a \
           clean-but-forgettable point has a SYMBOL (one image), a SLOGAN (a \
           short repeatable phrase), a SURPRISE, one SALIENT idea that stands \
           out, or a STORY. Name at most ONE missing element as the move — \
           never dump the list, and only when the numbers are already fine.

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
    ///   • COACH MEMORY — durable evidence depth, goal anchor, current
    ///     plan, declared intent, and stable preserve/watch signals.
    ///   • CASE FORMULATION — current hypothesis, goal fit, subjective
    ///     reflection, transfer update, and preserve/watch signals.
    ///   • INTERVENTION CYCLE — active intervention, observable target,
    ///     success criterion, review status, cadence, and course-change
    ///     reason.
    ///   • ACTIVE PRESCRIPTION — the currently shown intervention when
    ///     it has not yet been evaluated by a completed followed rep.
    ///   • INTERVENTION RESPONSE — whether previously prescribed modes
    ///     are associated with improved or worse subsequent reps.
    ///   • RECENT — last 3 sessions: mode, score, fillers, duration
    ///   • PATH — current node title + landmark position
    ///   • TRENDS — strengths + persistent blockers
    ///   • PROOFS — transcript-anchored evidence of growth (verbatim
    ///     quotes the user actually said in past reps). Omitted entirely
    ///     when no proofs exist so the model never invents one. Bounded
    ///     to the most-recent 3 — enough texture without crowding the
    ///     system prompt.
    ///   • REAL-WORLD TRANSFER — user-reported outcome and perceived
    ///     counterpart response from completed Big Moments. Bounded to
    ///     the most recent 2 and explicitly labelled subjective evidence.
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
        recentMomentOutcomes: [BigMomentOutcomeReport] = [],
        forwardPlan: ForwardPlan? = nil,
        latestRepNote: PostRepCoachNote? = nil,
        coachMemory: CoachMemory? = nil,
        pendingRecommendation: RecommendationExposure? = nil,
        recommendationOutcomes: [RecommendationOutcome] = [],
        trends: [SkillTrend] = [],
        // M29 — Optional most-recent SkillSnapshot. When provided, the
        // structural read engine composes the per-rep dimension
        // ratings (Opening / Structure / Depth / Close) into a STRUCTURAL
        // READ section. Defaults to nil so existing callers compile
        // unchanged.
        latestSnapshot: SkillSnapshot? = nil,
        // M30 — Optional snapshot history for the DERIVED READ TRENDS
        // section (longitudinal direction across the most-recent +
        // prior windows). Defaults to empty so existing callers
        // compile unchanged.
        snapshotsForTrends: [SkillSnapshot] = [],
        // S2 — Optional detected goal-set/change intent for the CURRENT chat
        // turn (from `detectGoalIntent`). When present, the GOAL block emits
        // propose-not-committed / change-trade-off / anti-thrash lines so the
        // coach PROPOSES rather than assumes a write — the user still confirms
        // in-app via the goal card. Defaults to nil so existing callers compile
        // unchanged and non-goal turns emit no extra lines.
        pendingGoalIntent: GoalIntent? = nil,
        // F1 — recent weekly check-ins (newest-first): the user's own
        // bidirectional answers (hardest / outside-app transfer / drill
        // verdict). Defaults to empty so existing callers compile unchanged.
        recentCheckIns: [CoachCheckIn] = [],
        // H1 — optional current-turn frame inputs. `CoachReplyPipeline`
        // derives these from the replay history so Ask Noum can tell the
        // model what coaching move THIS turn needs (repair, direct next move,
        // honoring a choice, greeting continuation) without adding new state.
        latestUserTurn: String? = nil,
        previousCoachReply: String? = nil,
        // EQ — recent user turns (newest-first) for sustained emotional
        // pattern detection. The arc detector scans these for repeated
        // signals across turns (e.g. frustration persisting over 3 turns).
        // Defaults to empty so existing callers compile unchanged.
        recentUserTurns: [String] = []
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
            // Blended voice — the user chose to keep their primary and add a
            // secondary from the in-chat goal-change card. The read weighs both
            // (see `CoachingProfile.blendedAlignedSkillAreas`); the coach should
            // hold the mix, not treat the secondary as a replacement.
            if let secondary = profile.secondaryStyleGoal,
               secondary != profile.speakingStyleGoal {
                lines.append("- Blended voice: primary \(profile.speakingStyleGoal.title), secondary \(secondary.title). Read both — the secondary widens the leverage, it does not replace the primary.")
            }
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
            // speakingContext — where they expect to use this voice.
            // Lets the coach anchor moves to the real-world surface ("you
            // train for interviews — that's where this rep lands").
            lines.append("- Where they want to use this: \(profile.speakingContext.title.lowercased())")
            // styleReference — "I want to sound like X." Free-text quote
            // when set. Coach can frame feedback against the reference
            // ("that opener was the opposite of what Obama would do").
            let reference = profile.styleReference.trimmingCharacters(in: .whitespacesAndNewlines)
            if !reference.isEmpty {
                lines.append("- Style reference (who they want to sound like): \(reference)")
            }
        } else {
            lines.append("")
            lines.append("GOAL")
            lines.append("- No voice set yet. Treat this as cold start — gentle, curious.")
        }

        // GOAL INTENT — when the current turn is a detected set/change request,
        // tell the coach to PROPOSE not assume (the user confirms in-app via the
        // goal card; the model never writes). On a change, name the trade-off and
        // surface the anti-thrash note when the user has been switching often.
        if let intent = pendingGoalIntent {
            lines.append(
                contentsOf: goalIntentContextLines(
                    intent: intent,
                    currentVoice: profile?.speakingStyleGoal,
                    adaptationLog: coachMemory?.adaptationLog
                )
            )
        }

        // BIG MOMENT — only present when active + within 60 days.
        // When present, the coach should ground at least one concrete next
        // move in the days-remaining and category (rule 4 of intelligence floor).
        if let moment = bigMoment,
           let days = BigMomentStore.daysUntil(moment),
           days >= 0 && days <= 60 {
            lines.append("")
            lines.append("BIG MOMENT")
            lines.append("- Preparing for: \(moment.title) (\(moment.category.displayName)). \(days) day\(days == 1 ? "" : "s") away.")
            // F2 — rehearsal readiness: how many prep shapes the user has run
            // since setting this moment, so the coach can nudge the remaining
            // rehearsal rather than re-explaining the moment.
            let prepReadiness = PrepSessionPlanner.readiness(
                plan: PrepSessionPlanner.plan(bigMoment: moment, daysRemaining: days),
                sessions: sessions,
                momentCreatedAt: moment.createdAt
            )
            lines.append("- Rehearsal: \(prepReadiness.contextLine)")
        }

        if !recentMomentOutcomes.isEmpty {
            lines.append("")
            lines.append("REAL-WORLD TRANSFER")
            for trend in BigMomentStore.transferTrends(from: recentMomentOutcomes, minimumReports: 3, limit: 2) {
                lines.append("- Transfer pattern: \(trend.contextLine)")
            }
            for report in recentMomentOutcomes.prefix(2) {
                lines.append("- \(report.coachContextLine)")
            }
            lines.append("- These are the user's reported outcome and read of the room, not objective evidence or proof that training caused the result. Pattern lines require at least 3 reports of the same moment kind.")
        }

        // WEEKLY CHECK-IN (F1) — the user's own answers from the most-recent
        // weekly check-in: what felt hardest, where it showed up outside the
        // app, and their read on whether the current drill is working.
        // User-reported, never inferred; the drill verdict guides review but
        // never proves the drill caused anything.
        if let latestCheckIn = recentCheckIns.first(where: { !$0.coachContextLines.isEmpty }) {
            lines.append("")
            lines.append("WEEKLY CHECK-IN (user-reported)")
            lines.append(contentsOf: latestCheckIn.coachContextLines)
            lines.append("- Use these to ask a sharper follow-up or adapt the plan; treat the drill verdict as the user's read, not proof of causation.")
        }

        let liveFrame = liveCoachingFrameLines(
            latestUserTurn: latestUserTurn,
            previousCoachReply: previousCoachReply,
            profile: profile,
            coachMemory: coachMemory,
            recentUserTurns: recentUserTurns
        )
        if !liveFrame.isEmpty {
            lines.append("")
            lines.append("LIVE COACHING FRAME (this turn only)")
            lines.append(contentsOf: liveFrame)
        }
        let turnContract = professionalTurnContractLines(
            latestUserTurn: latestUserTurn,
            previousCoachReply: previousCoachReply,
            profile: profile,
            coachMemory: coachMemory
        )
        if !turnContract.isEmpty {
            lines.append("")
            lines.append("PROFESSIONAL TURN CONTRACT (how this reply earns trust)")
            lines.append(contentsOf: turnContract)
        }

        // COACHING READINESS (F5) — claim-scaling. Always present so the coach
        // never asserts more certainty than the accumulated evidence supports,
        // and never claims validation/parity (capped by design). Counts here
        // are lower bounds (recent windows); under-counting only biases toward
        // humility, the safe direction.
        let parityReadiness = CoachParityReadiness.build(
            memory: coachMemory,
            sessionCount: sessions.count,
            recommendationOutcomeCount: recommendationOutcomes.count,
            transferReportCount: max(recentMomentOutcomes.count, (coachMemory?.lastTransferReview != nil) ? 1 : 0),
            checkInCount: recentCheckIns.count
        )
        lines.append("")
        lines.append("COACHING READINESS (scale your certainty to this)")
        lines.append(contentsOf: parityReadiness.coachContextLines)

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

        // MOMENTUM — cross-session trajectory signals. Omitted entirely
        // on cold start (< 5 sessions) to avoid overclaiming from thin
        // data. Bounded at 4 lines so the context stays lean.
        if sessions.count >= 5 {
            let baselineRate: Double? = baseline.fillerRate.confidence == .insufficient
                ? nil : baseline.fillerRate.value
            let sorted = sessions.sorted { $0.date > $1.date }
            var momentumLines: [String] = []

            let cleanCount = MomentumComputer.consecutiveCleanReps(
                sorted: sorted, baselineFillerRate: baselineRate
            )
            if cleanCount >= 2 {
                momentumLines.append("- Consecutive clean reps: \(cleanCount).")
            }
            if sessions.count >= 6 {
                if let fillerTrend = MomentumComputer.fillerTrend(sorted: sorted) {
                    switch fillerTrend {
                    case .improving:
                        momentumLines.append("- Filler trend: improving over last 6 sessions.")
                    case .declining:
                        momentumLines.append("- Filler trend: increasing over last 6 sessions.")
                    default: break
                    }
                }
                if let scoreTrend = MomentumComputer.scoreTrend(sorted: sorted) {
                    switch scoreTrend {
                    case .improving:
                        momentumLines.append("- Score trend: improving over last 6 sessions.")
                    case .declining:
                        momentumLines.append("- Score trend: declining over last 6 sessions.")
                    default: break
                    }
                }
            }
            if weeklyReps >= 3 {
                momentumLines.append("- Weekly rhythm: \(weeklyReps) reps this week.")
            }

            if !momentumLines.isEmpty {
                lines.append("")
                lines.append("MOMENTUM")
                lines.append(contentsOf: momentumLines.prefix(4))
            }
        }

        let memoryLines: [String]
        let caseFileLines: [String]
        let caseLines: [String]
        let cycleLines: [String]
        if let coachMemory {
            memoryLines = coachMemoryLines(
                memory: coachMemory
            )
            caseFileLines = coachCaseFileLines(
                memory: coachMemory
            )
            caseLines = coachCaseFormulationLines(
                memory: coachMemory
            )
            cycleLines = interventionCycleLines(
                memory: coachMemory,
                includeActiveIntervention: pendingRecommendation == nil
            )
        } else {
            memoryLines = coachMemoryLines(
                profile: profile,
                baseline: baseline,
                sessions: sessions,
                trends: trends
            )
            caseFileLines = []
            caseLines = []
            cycleLines = []
        }
        if !memoryLines.isEmpty {
            lines.append("")
            lines.append("COACH MEMORY")
            lines.append(contentsOf: memoryLines)
        }
        if !caseFileLines.isEmpty {
            lines.append("")
            lines.append("COACH CASE FILE (durable strategy)")
            lines.append(contentsOf: caseFileLines)
        }
        if !caseLines.isEmpty {
            lines.append("")
            lines.append("CASE FORMULATION (current hypothesis; revise with evidence)")
            lines.append(contentsOf: caseLines)
        }
        if !cycleLines.isEmpty {
            lines.append("")
            lines.append("INTERVENTION CYCLE (prescribe → observe → adapt)")
            lines.append(contentsOf: cycleLines)
        }

        if let pendingRecommendation {
            lines.append("")
            lines.append("ACTIVE PRESCRIPTION (shown; awaiting a followed rep)")
            lines.append("- \(pendingRecommendation.mode.displayLabel): \(pendingRecommendation.focus). Success marker: \(pendingRecommendation.target).")
            lines.append("- This has been prescribed but not tested; do not claim it helped or failed.")
        }

        let interventionLines = RecommendationResponseAnalyzer.promptLines(from: recommendationOutcomes)
        if !interventionLines.isEmpty {
            lines.append("")
            lines.append("INTERVENTION RESPONSE (association only; never claim causation)")
            lines.append(contentsOf: interventionLines)
            // The reinforce / vary / replace decision for the most-prescribed
            // key, surfaced under the same header so the chat coach speaks one
            // verdict — keep it, vary the approach, or swap the mode — rather
            // than only narrating the association above. Omitted below the
            // evidence floor (≥3 measurable reps) so the coach never decides on
            // thin data.
            if let topSummary = RecommendationResponseAnalyzer.summarize(outcomes: recommendationOutcomes).first,
               let verdictLine = RecommendationAdaptationAnalyzer.adaptationRationale(
                   mode: topSummary.mode, focus: topSummary.focus, in: recommendationOutcomes) {
                lines.append(verdictLine)
            }
        }

        // TONE-DRILL TRAJECTORY — the IM analog of INTERVENTION RESPONSE.
        // The recommendation engine already adapts its next-practice card
        // to whether the prescribed tone drill is recovering or slipping;
        // this carries the same Adaptation read into the chat coach so it
        // can speak to the response in conversation ("your calm tone is
        // recovering — 0% to 50%"), not only on the post-rep card. Pure read
        // over the user's own IM reps; surfaced only when the prescribed
        // scenario carries a trajectory (≥4 evaluated reps), so the coach
        // never claims a movement it can't see.
        //
        // Round 42 — freshness gate. `toneDrillSignal` itself has no recency
        // bound on the latest evaluated rep, so a scenario the user
        // practiced 60+ days ago and still hasn't returned to would surface
        // a TRAJECTORY line on every chat reply forever. Anchored against
        // the user's most-recent rep across all history
        // (`sessions.lazy.map(\.date).max()`), the section now drops past
        // `toneDrillSolvedRecencyDays` (14 days, shared with the round-41
        // SOLVED surface) from the prescribed scenario's latest evaluated
        // rep. The recommendation engine still prescribes the drill (the
        // gap is real) — only the chat-coach context surface gates.
        if let toneSignal = IMHistorySummary.toneDrillSignal(from: sessions),
           let trajectoryLines = toneDrillTrajectoryLines(for: toneSignal),
           let mostRecentRepDate = sessions.lazy.map(\.date).max(),
           toneDrillTrajectoryIsFresh(signal: toneSignal, in: sessions, now: mostRecentRepDate) {
            lines.append("")
            lines.append("TONE-DRILL TRAJECTORY (is the prescribed tone drill working?)")
            lines.append(contentsOf: trajectoryLines)
        }

        // TONE-DRILL SOLVED — the win after the drill is won. The signal
        // that feeds TONE-DRILL TRAJECTORY self-clears the moment a
        // scenario climbs past the drill bar, which is right for the
        // recommendation engine but leaves the coach silent at exactly the
        // moment it should name the win. This carries a recently-resolved
        // tone read so the coach can say "your calm tone in Difficult
        // Conversation is holding now — 0% to 100%" instead of dropping the
        // thread. Mutually exclusive with the trajectory section per
        // scenario (a scenario is either a still-sub-bar drill or a
        // resolved win, never both), but a drill in one scenario and a win
        // in another can — and should — both surface.
        //
        // Round 41 — freshness gate. `toneDrillResolved` returns the read
        // forever once a scenario holds the bar; without a gate, the chat
        // coach reads the same SOLVED section on every reply for months
        // after the crossing. Anchored against the user's most-recent rep
        // (`sessions.lazy.map(\.date).max()`), the section now drops past
        // `toneDrillSolvedRecencyDays` (14 days) — the same window
        // `repeatedPushbackRecencyDays` uses for the rejection-dampening
        // line on the case-state matrix. The chat coach moves on to the
        // current target, which is what the line's own guidance has been
        // asking the model to do since round 13.
        if let resolved = IMHistorySummary.toneDrillResolved(from: sessions),
           let mostRecentRepDate = sessions.lazy.map(\.date).max(),
           toneDrillSolvedIsFresh(resolved, now: mostRecentRepDate) {
            lines.append("")
            lines.append("TONE-DRILL SOLVED (a past tone gap the user has closed)")
            lines.append(contentsOf: toneDrillResolvedLines(for: resolved))
        }

        // RECENT — last 3 sessions, so the coach can quote actual numbers.
        // M21: when a session carried a declared intent (the user tapped a
        // chip on the SessionIntent prompt before the rep), append a quiet
        // "Intent: <label>" tail so the coach can quote it back ("you came
        // in wanting to tighten structure — here's what I saw"). Sessions
        // without intent get no tail; older persisted reps decode with nil.
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
                let intentTail: String = {
                    if let label = s.intentLabel?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !label.isEmpty {
                        return " · Intent: \(label)"
                    }
                    return ""
                }()
                // M26 — vocal energy tail. When the rep produced a
                // VocalEnergyMetrics aggregate (≥ minimumSampleFloor
                // samples in the accumulator), surface the qualitative
                // readout ("engaged energy, mostly steady") so the
                // coach has a HOW-THEY-SOUNDED signal alongside the
                // WHAT-THEY-SAID metrics. Older sessions decode with
                // nil → no tail; the model never sees a fabricated
                // read on thin-data reps.
                let vocalTail: String = {
                    if let ve = s.vocalEnergyMetrics {
                        return " · Vocal: \(ve.qualitativeReadout)"
                    }
                    return ""
                }()
                lines.append("- \(day) · \(mode): \(score), \(fillers), \(duration)\(intentTail)\(vocalTail).")
            }
        }

        // M27 — COMPOSURE READ. Derived signal that composes vocal
        // energy steadiness + pitch variation + pause filled-ratio +
        // hedging rate into one coach-facing read. Pure function over
        // signals the rep already produced — no new sensing. Engine
        // returns nil when fewer than 2 channels contributed (honest
        // about thin signal), so this block silently omits when the
        // read isn't credible. When present, the coach can comment on
        // composure across channels rather than only on isolated
        // metrics.
        if let latest = recent.first {
            let hedgingPerMinute: Double? = baseline.hedgingRate.value
            let composure = ComposureReadEngine.derive(
                session: latest,
                hedgingPerMinute: hedgingPerMinute
            )
            if let composure {
                lines.append("")
                lines.append("COMPOSURE READ (most-recent rep)")
                lines.append("- \(composure.readout). Composite \(String(format: "%.2f", composure.score))/1.0 from \(composure.contributingChannels) channels.")
            }

            // M28 — Confidence markers. Pure-function read composing
            // hedging density + filler density + pace consistency +
            // composure carryover. Reads MARKERS, not the person —
            // copy says "this rep read as tentative" never "you sound
            // unconfident". Omitted silently when fewer than 2
            // channels are available.
            let paceBaseline: Double? = baseline.pace.value
            if let confidence = ConfidenceMarkerEngine.derive(
                session: latest,
                hedgingPerMinute: hedgingPerMinute,
                paceWPM: paceBaseline,
                composure: composure
            ) {
                lines.append("")
                lines.append("CONFIDENCE MARKERS (most-recent rep)")
                lines.append("- \(confidence.readout). Composite \(String(format: "%.2f", confidence.score))/1.0 from \(confidence.contributingChannels) channels.")
            }

            // M29 — Structural read. Pure-function over the per-rep
            // categoryRatings (Opening / Structure / Depth / Close)
            // already captured by FeedbackEngine. When the most-recent
            // SkillSnapshot is available, composes the four dimensions
            // into one structural score so the coach can comment on
            // the "bones" of the rep — what held, what faltered — not
            // just isolated metrics. Engine returns nil when fewer
            // than 2 dimensions are present.
            if let structural = StructuralReadEngine.derive(snapshot: latestSnapshot) {
                lines.append("")
                lines.append("STRUCTURAL READ (most-recent rep)")
                lines.append("- \(structural.readout). Composite \(String(format: "%.2f", structural.score))/1.0 from \(structural.contributingDimensions) dimensions.")
            }

            // PROMPT RELEVANCE — the substance read (initiative #8 follow-on).
            // The same `PromptRelevanceRead` the 7-dimension Relevance rating,
            // the post-rep hero note, and the deep-analysis debrief consume,
            // surfaced HERE so the chat coach reads the "did you answer it /
            // lead vs buried" signal DIRECTLY rather than inheriting it as
            // free-text through the LAST REP NOTE. Timed only — the mode whose
            // stored `prompt` is a question to answer; IM relevance is carried
            // by the TONE-DRILL sections above. Gated on the read's evidence
            // floor (>= 3 prompt content words, >= 12 transcript words) so the
            // coach never judges relevance on thin data, and framed as lexical
            // association, never a confident "off-topic" (rule 14 is the
            // backstop, the guidance clause is the in-context nudge).
            if latest.mode == .timed {
                let relevanceRead = PracticeEvaluator.promptRelevance(
                    prompt: latest.prompt,
                    transcript: latest.transcript
                )
                if let relevanceLines = promptRelevanceLines(for: relevanceRead, prompt: latest.prompt) {
                    lines.append("")
                    lines.append("PROMPT RELEVANCE (most-recent rep — did the answer engage the question?)")
                    lines.append(contentsOf: relevanceLines)
                }

                // ARGUMENT LOGIC — the rep's reasoning shape (claim ->
                // evidence -> implication), the SAME deterministic read that
                // drives the Timed insight line so the chat coach can't disagree
                // with the post-rep note. Distinct from PROMPT RELEVANCE above
                // (topic vs reasoning structure). Nil below the floor or when no
                // claim was asserted — no down-talk on a fragment.
                if let argumentLines = argumentLogicLines(transcript: latest.transcript) {
                    lines.append("")
                    lines.append("ARGUMENT LOGIC (most-recent rep — is the answer built as an argument?)")
                    lines.append(contentsOf: argumentLines)
                }

                // STRUCTURE READ — Winston "make it stick" bookends (an
                // empowerment-promise opening + a landed close). Deterministic
                // (`MemorabilityAnalyzer`), emitted ONLY when there's an
                // actionable signal — a cold open or a trailed-off close — so a
                // rep that opened and landed cleanly adds nothing to the prompt.
                let structureRead = MemorabilityAnalyzer.analyze(transcript: latest.transcript)
                if structureRead.hasActionableSignal,
                   let structureLines = structureReadLines(for: structureRead) {
                    lines.append("")
                    lines.append("STRUCTURE READ (most-recent rep — Winston bookends)")
                    lines.append(contentsOf: structureLines)
                }
            }
        }

        // M30 — DERIVED READ TRENDS. Longitudinal direction (improving
        // / declining / stable / insufficient) on each of the four
        // derived reads (vocal energy steadiness, composure,
        // confidence markers, structural). Pure function over the
        // session history — no new persistence layer. Lets the coach
        // say "your composure has trended up across the last 5 reps"
        // instead of only commenting on the most-recent rep. Honest
        // about thin windows — dimensions below the minRecentReps
        // floor either omit or report .insufficient.
        let hedgingPerMin = baseline.hedgingRate.value
        let paceBaseline = baseline.pace.value
        let derivedTrends = DerivedReadsTrendEngine.compute(
            sessions: sessions,
            snapshots: snapshotsForTrends,
            hedgingPerMinutePerSession: { _ in hedgingPerMin },
            paceBaselinePerSession: { _ in paceBaseline }
        )
        // FUSED DELIVERY READ (#3) — the single durable read of how the
        // recent rep SET read on delivery, fused from the per-rep reads and
        // persisted on `CoachMemory`. `tentativeLine` is nil below the
        // consistency floor (the read is `.forming` — suppressed), so this
        // surfaces ONE line only when a pattern has earned the floor. It is a
        // HYPOTHESIS about the reps, never a trait/diagnosis — the copy itself
        // carries that hedge, and it leads the section because it is the
        // durable read the per-dimension trends below merely support.
        let caseFileDeliveryLine = coachMemory?.caseFile?.deliveryRead?.tentativeLine
        let fusedDeliveryLine = caseFileDeliveryLine == nil
            ? coachMemory?.coachDeliveryRead?.tentativeLine
            : nil
        if fusedDeliveryLine != nil || !derivedTrends.isEmpty {
            lines.append("")
            lines.append("DERIVED READ TRENDS (recent vs prior window)")
            if let fusedDeliveryLine {
                lines.append("- Fused delivery read: \(fusedDeliveryLine)")
            }
            for trend in derivedTrends {
                lines.append("- \(trend.readout)")
            }
        }

        // LAST REP NOTE — the coach's own short read of the most-recent
        // rep, persisted by `PostRepCoachNoteStore` after each session
        // finalizes. Lets the chat coach build on its own earlier read
        // instead of starting fresh every turn — when the user asks
        // "what did you think of my last rep?", the coach can paraphrase
        // or expand on this note rather than re-reading the metrics
        // from scratch. Honest about provenance: when the note is
        // rule-based (no AI provider was reachable), the model is told
        // so it doesn't claim "I noticed X" about a deterministic
        // template line.
        if let note = latestRepNote {
            lines.append("")
            lines.append("LAST REP NOTE")
            let provenance = note.isAIBacked ? "AI-generated" : "rule-based (template)"
            lines.append("- Your read after the user's most-recent rep (\(provenance)): \"\(note.noteText)\"")
        }

        // PATH — where they are in their journey
        if let status = pathStatus {
            lines.append("")
            lines.append("PATH")
            lines.append("- Chapter: \(status.node.tier.title).")
            lines.append("- Current landmark: \(status.node.title).")
            if let phrase = pathGatingPhrase {
                lines.append("- Gating: \(phrase)")
            }
        }

        // TRENDS — what's working + what's not. Combines baseline rollups
        // (strengths / blockers as short noun labels) with TrendAnalyzer
        // direction outputs (per-skill movement). Direction lines let the
        // coach cite "filler rate declining for 3 weeks" or "pause usage
        // resolved" without re-running the analyzer. Omitted entirely
        // when no signal is non-empty so the section never reads as a
        // hollow heading.
        let directionLines = trendDirectionLines(trends: trends)
        if !baseline.topStrengths.isEmpty || !baseline.persistentBlockers.isEmpty || !directionLines.isEmpty {
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
            for line in directionLines {
                lines.append("- \(line)")
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

    // MARK: - Live coaching frame (turn-level attunement)

    /// A lightweight, non-persistent read of the *current* chat turn.
    ///
    /// The durable coaching strategy still lives in `CoachMemory` /
    /// `CoachCaseFile`; this helper only tells the model what kind of move the
    /// next reply should make. It protects Ask Noum from the low-EQ failure mode
    /// in the screenshot: a short "Hi" after a choice should continue the case
    /// thread, while explicit critique should be treated as repair, not a
    /// generic menu.
    static func liveCoachingFrameLines(
        latestUserTurn: String?,
        previousCoachReply: String?,
        profile: CoachingProfile?,
        coachMemory: CoachMemory?,
        recentUserTurns: [String] = []
    ) -> [String] {
        guard let latestUserTurn else { return [] }
        let trimmed = latestUserTurn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lower = trimmed.lowercased()
        let normalized = normalizedTurn(trimmed)
        var lines: [String] = []

        // === INTENT DETECTION (unchanged) ===
        if containsAny(lower, [
            "robotic", "generic", "not ideal", "not a fan", "no where near",
            "nowhere near", "annoy", "frustrat", "sucks", "poop",
            "not human", "doesn't feel", "does not feel", "too much writing",
            "hardcoded"
        ]) {
            lines.append("- Turn read: user is giving friction or product-quality critique.")
            lines.append("- Coaching move: do not defend the app. Acknowledge the specific friction in one sentence, say what you will change in the coaching work, then give one concrete next move.")
        } else if isChoiceOrCommitmentTurn(normalized, previousCoachReply: previousCoachReply) {
            lines.append("- Turn read: user is choosing or negotiating a coaching direction.")
            lines.append("- Coaching move: honor the preference, do not ask the same choice again, and turn it into a prescribed next step with an observable target.")
        } else if containsAny(lower, [
            "what next", "next move", "what should i do", "where should",
            "what do i work", "focus on", "continue", "implement it",
            "make a bigger stride", "go for", "do the next"
        ]) {
            lines.append("- Turn read: user is asking for direction.")
            lines.append("- Coaching move: give one recommendation, not a menu. Name why it is high-leverage, then prescribe the next rep or review action.")
        } else if isLowSignalGreeting(normalized) {
            lines.append("- Turn read: low-signal opener.")
            lines.append("- Coaching move: do not respond with generic small talk or a broad menu. If there is an active case, continue the case thread; otherwise give one short discovery question tied to the user's stated goal.")
        } else {
            lines.append("- Turn read: normal coaching question or update.")
            lines.append("- Coaching move: answer the user's actual ask first, then connect it to the active case only if it genuinely helps.")
        }

        // === EMOTIONAL SIGNAL DETECTION (additive to intent, confidence-graded) ===
        let graded = gradedSignals(lower)
        let voice = profile?.speakingStyleGoal

        // === CONVERSATION ARC (sustained emotional pattern, confidence-weighted) ===
        // Computed before the per-turn block so a strong-this-turn read that is
        // ALSO sustained across the arc can trigger a visible acknowledgment.
        let arc = detectArcPattern(recentUserTurns: recentUserTurns)

        if let primary = graded.first {
            let move = emotionalCoachingMove(for: primary.signal, voice: voice)
            let qualifier = primary.confidence == .strong
                ? "clear in this turn"
                : "weak signal — treat as tentative, do not lead hard with it"
            lines.append("- Emotional signal (hypothesis, not diagnosis): \(primary.signal.contextLabel) (\(qualifier)).")
            lines.append("- Emotional register: \(move)")

            // Rank-1 visibility (2026-06-14 eval): being seen IS the coaching.
            // When the read is BOTH strong in this turn AND sustained across the
            // recent arc (the same signal), require the model to OPEN by naming
            // it in plain language. The words stay model-generated, so the reply
            // still passes the quality gate and there is no double-naming or
            // clinical meta-text. A weak/tentative or one-off read never forces a
            // visible open — that path stays soft so a misread is never spoken
            // (CLAUDE.md: weak evidence → softer feedback).
            if primary.confidence == .strong, arc?.signal == primary.signal {
                lines.append("- Open this reply by naming this read in plain language before anything else — one short clause (e.g. \"Sounds like the last few reps have been frustrating\"), no clinical labels and without quoting their words back — then continue with the coaching move.")
            }
        }

        if let arc {
            lines.append("- Sustained pattern: \(arc.signal.contextLabel) across \(arc.turnCount) of the last 4 turns. This is not a one-off — adjust the coaching posture accordingly.")
        }

        if coachMemory?.caseFile != nil {
            lines.append("- Case discipline: prefer the active case file before creating a new focus; if the user rejects it, ask one anchoring question before changing course.")
        }
        if profile == nil {
            lines.append("- Personalization floor: no chosen profile yet, so ask one useful discovery question before making a strong diagnosis.")
        }

        return lines
    }

    private static func normalizedTurn(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let scalars = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? String(scalar) : " "
        }
        return scalars.joined()
            .split(separator: " ")
            .joined(separator: " ")
    }

    private static func containsAny(_ value: String, _ needles: [String]) -> Bool {
        needles.contains { value.contains($0) }
    }

    // MARK: - Professional turn contract

    /// A tighter per-turn standard layered on top of the system prompt. The
    /// system prompt defines the coach's identity; this defines the job of the
    /// next reply. It is deliberately non-persistent: a senior coach adapts the
    /// turn shape without changing the durable case file.
    static func professionalTurnContractLines(
        latestUserTurn: String?,
        previousCoachReply: String?,
        profile: CoachingProfile?,
        coachMemory: CoachMemory?
    ) -> [String] {
        guard let latestUserTurn else { return [] }
        let trimmed = latestUserTurn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let lower = trimmed.lowercased()
        let normalized = normalizedTurn(trimmed)
        var lines: [String] = [
            "- Reply shape: at most 2 short sentences (more only when the user explicitly asks for a plan or expanded answer). No headers, bullets, or numbered lists unless the user explicitly asks for a list.",
            "- Coaching standard: one attuned human read, one observable fact or honest data gap, one prescribed action. No broad menu."
        ]

        if containsAny(lower, [
            "robotic", "generic", "not ideal", "not a fan", "no where near",
            "nowhere near", "annoy", "frustrat", "sucks", "poop",
            "not human", "doesn't feel", "does not feel", "too much writing",
            "hardcoded"
        ]) {
            lines.append("- Must do this turn: repair trust first. Name the specific friction, say how the coaching response will change, then give one useful action.")
        } else if isChoiceOrCommitmentTurn(normalized, previousCoachReply: previousCoachReply) {
            lines.append("- Must do this turn: treat the user's choice as a decision. Do not ask them to choose again.")
        } else if containsAny(lower, [
            "what next", "next move", "what should i do", "where should",
            "what do i work", "focus on", "continue", "implement it",
            "make a bigger stride", "go for", "do the next"
        ]) {
            lines.append("- Must do this turn: choose the highest-leverage next action for them. Explain the reason in one clause, then prescribe the rep or review.")
        } else if isLowSignalGreeting(normalized) {
            lines.append("- Must do this turn: resume the active coaching thread rather than greeting back with a menu.")
        } else {
            lines.append("- Must do this turn: answer the user's actual ask first. Bring in the case file only when it sharpens the answer.")
        }

        if coachMemory?.caseFile != nil {
            lines.append("- Active-case rule: stay with the current case unless the user clearly redirects.")
        } else if profile == nil {
            lines.append("- Cold-start rule: ask one discovery question tied to their speaking goal before making a strong read.")
        }

        return lines
    }

    // MARK: - Emotional signal detection (EQ workflow)
    //
    // A human coach reads emotional temperature before choosing a coaching
    // move. The system prompt's attunement floor tells the model to do this,
    // but without structured signals the model has to infer everything from
    // raw text — and often defaults to "coaching advice" even when the user
    // needs acknowledgment first. These pure-function helpers detect
    // emotional signals from keyword patterns and produce voice-specific
    // coaching-move guidance so the LIVE COACHING FRAME can pass a
    // structured emotional read alongside the intent read.
    //
    // Design rules:
    //   • Pure functions — no async, no singletons, no I/O.
    //   • Emotional reads are HYPOTHESES, never diagnoses. The copy
    //     carries the hedge ("signal suggests"), and the system prompt
    //     backstop tells the model to use plain language, not clinical
    //     labels.
    //   • Multiple signals can co-occur (frustration + self-doubt).
    //     Only the primary (first detected) gets a coaching-move line
    //     to keep the context bounded.
    //   • Voice-specific coaching moves follow the established
    //     `coachPersonality(for:)` switch pattern.

    /// Detected emotional signal from the user's turn. These are keyword-
    /// based hypotheses, never diagnoses. The model uses them to choose a
    /// coaching register, not to label the user.
    private enum EmotionalSignal: String, CaseIterable {
        case frustration
        case selfDoubt
        case vulnerability
        case fatigue
        case celebrationSeeking
        case breakthrough
        case resistance
        case comparison
        case overwhelm
        case curiosity

        /// Plain-language label for the context line — never clinical.
        var contextLabel: String {
            switch self {
            case .frustration:       return "frustration"
            case .selfDoubt:         return "self-doubt"
            case .vulnerability:     return "vulnerability"
            case .fatigue:           return "fatigue or burnout"
            case .celebrationSeeking: return "celebration or pride"
            case .breakthrough:      return "breakthrough or insight"
            case .resistance:        return "resistance or avoidance"
            case .comparison:        return "comparison with others"
            case .overwhelm:         return "overwhelm"
            case .curiosity:         return "curiosity"
            }
        }
    }

    /// Detect emotional signals from the user's turn text. Returns an array
    /// because multiple signals can co-occur (e.g. frustration + self-doubt).
    /// Empty array = no emotional signal detected = normal coaching turn.
    private static func detectEmotionalSignals(_ lower: String) -> [EmotionalSignal] {
        var signals: [EmotionalSignal] = []

        // "stuck" is the highest-collision frustration trigger — "stuck in
        // traffic" / "stuck in a meeting" is not coaching frustration. Match
        // the rest of the triggers directly, and only count a bare "stuck"
        // when it is NOT in an incidental physical context. Any non-stuck
        // trigger ("ugh", "this isn't working") in the same turn keeps the
        // frustration read regardless.
        let frustrationTriggersExStuck = [
            "i can't", "i cant", "this isn't working", "this isnt working",
            "not working", "ugh", "failing", "keep messing up",
            "same mistake", "what's the point", "whats the point",
            "going nowhere", "no progress", "getting worse",
            "i keep", "argh", "damn"
        ]
        if containsAny(lower, frustrationTriggersExStuck)
            || (lower.contains("stuck") && !isIncidentalStuck(lower)) {
            signals.append(.frustration)
        }

        if containsAny(lower, [
            "i suck", "i'm not good", "im not good", "not good enough",
            "not getting better", "never going to", "hopeless",
            "can't do this", "cant do this", "waste of time",
            "not cut out", "will i ever", "am i even",
            "i'm bad", "im bad", "terrible at"
        ]) {
            signals.append(.selfDoubt)
        }

        if containsAny(lower, [
            "scared", "nervous", "afraid", "terrified", "anxious",
            "panic", "dread", "i freeze", "my voice shakes",
            "embarrass", "ashamed", "vulnerable", "hard to admit",
            "freaking out", "butterflies"
        ]) {
            signals.append(.vulnerability)
        }

        if containsAny(lower, [
            "tired of", "burnt out", "burned out", "burnout",
            "exhausted", "over it", "need a break",
            "too much practice", "sick of", "done with this",
            "losing motivation", "not feeling it", "drained",
            "low energy"
        ]) {
            signals.append(.fatigue)
        }

        if containsAny(lower, [
            "nailed it", "crushed it", "best one yet", "finally did",
            "i'm proud", "im proud", "personal best",
            "killed it", "so much better", "huge improvement",
            "my best", "felt amazing", "felt great", "smashed it",
            "proud of"
        ]) {
            signals.append(.celebrationSeeking)
        }

        if containsAny(lower, [
            "just realized", "it clicked", "i see it now", "aha",
            "that makes sense", "i get it now", "light bulb",
            "finally understand", "it all connects",
            "something shifted", "penny dropped"
        ]) {
            signals.append(.breakthrough)
        }

        if containsAny(lower, [
            "do i have to", "don't want to", "dont want to",
            "can we do something else", "not in the mood",
            "maybe tomorrow", "rather not", "seems pointless",
            "does this even", "skip this", "can i skip",
            "not today", "pass on"
        ]) {
            signals.append(.resistance)
        }

        if containsAny(lower, [
            "my colleague", "everyone else", "natural speaker",
            "born with it", "they make it look", "compared to",
            "why can't i", "why cant i", "other people",
            "some people just", "natural talent",
            "comes easy to them", "wish i could be like"
        ]) {
            signals.append(.comparison)
        }

        if containsAny(lower, [
            "too much", "overwhelm", "where do i start",
            "where do i even start", "drowning", "so many things",
            "everything at once", "can't keep up", "cant keep up",
            "information overload", "don't know where to begin",
            "dont know where to begin", "all over the place"
        ]) {
            signals.append(.overwhelm)
        }

        if containsAny(lower, [
            "how does", "why do i", "i wonder", "tell me about",
            "curious about", "interested in", "what happens if",
            "teach me", "i want to understand", "how come",
            "what's the science", "whats the science"
        ]) {
            signals.append(.curiosity)
        }

        return signals
    }

    // MARK: - Confidence grading (false-positive suppression)
    //
    // Rank-4 of the 2026-06-14 eval: before the coach's read is ever made more
    // visible, it must be more PRECISE. Raw keyword matching over-fires — a
    // bare keyword in an incidental clause ("stuck in traffic") or a turn that
    // self-corrects ("I was frustrated but I'm managing now") should not be
    // read as a sustained emotional state. These helpers grade each turn's
    // signals so the LIVE COACHING FRAME can carry a confidence qualifier and
    // the arc detector can require genuine strength — never punishing a
    // semantically-valid turn with a confident misread (CLAUDE.md invariant:
    // weak evidence → softer feedback; avoid fake certainty from small samples).

    /// Confidence in a single-turn emotional read. `strong` = a first-person
    /// emotional frame with no self-correction; `tentative` = a soft / bare /
    /// self-corrected mention that the coach should hold lightly.
    private enum SignalConfidence {
        case strong, tentative
        var weight: Double { self == .strong ? 1.0 : 0.5 }
    }

    /// Per-turn signals paired with a confidence grade. Empty when the turn
    /// carries no emotional signal.
    private static func gradedSignals(
        _ lower: String
    ) -> [(signal: EmotionalSignal, confidence: SignalConfidence)] {
        let signals = detectEmotionalSignals(lower)
        guard !signals.isEmpty else { return [] }
        // A self-corrected turn, or one with no first-person framing, is held
        // as tentative — the read may be real but the coach must not lead hard
        // with it.
        let confidence: SignalConfidence =
            (selfCorrects(lower) || !firstPersonEmotionalFrame(lower)) ? .tentative : .strong
        return signals.map { ($0, confidence) }
    }

    /// True when the bare trigger "stuck" appears only in an incidental
    /// physical context, not a coaching-frustration one.
    private static func isIncidentalStuck(_ lower: String) -> Bool {
        containsAny(lower, [
            "stuck in traffic", "stuck in a meeting", "stuck in line",
            "stuck on the train", "stuck on a call", "stuck at work",
            "stuck in the", "stuck behind", "stuck on the bus"
        ])
    }

    /// True when the turn frames the feeling in the first person — the
    /// structural marker that separates "I'm stuck and frustrated" (a real
    /// emotional disclosure) from a detached or third-party mention.
    private static func firstPersonEmotionalFrame(_ lower: String) -> Bool {
        lower.hasPrefix("i ") || lower.hasPrefix("i'm") || lower.hasPrefix("im ")
            || containsAny(lower, [
                " i ", "i'm", "im ", "i'll", "i've", "i'd", "i can", "i cant",
                "i can't", "i keep", "my ", " me ", "i feel", "i am", "i was"
            ])
    }

    /// True when the same turn walks the feeling back ("…but I'm managing now",
    /// "actually I'm good"). The coach should treat such a turn as tentative,
    /// not lock onto the first half.
    private static func selfCorrects(_ lower: String) -> Bool {
        containsAny(lower, [
            "but i'm managing", "but im managing", "but i'm ok", "but im ok",
            "but i'm okay", "but im okay", "but i'm good", "but im good",
            "but i'm fine", "but im fine", "actually i'm fine", "actually im fine",
            "actually i'm good", "actually im good", "feeling good now",
            "feeling better now", "but it's fine", "but its fine", "all good now",
            "but i got it", "but i figured it out", "no worries though",
            "i'm okay now", "im okay now", "i'm fine now", "im fine now",
            "but i'm getting there", "but im getting there"
        ])
    }

    /// Voice-specific coaching move for a detected emotional signal. Each
    /// voice handles the same emotion differently — the warm coach sits with
    /// doubt, the executive coach reframes it, the concise coach names it
    /// and moves. Follows the established `coachPersonality(for:)` switch
    /// pattern.
    private static func emotionalCoachingMove(
        for signal: EmotionalSignal,
        voice: SpeakingStyleGoal?
    ) -> String {
        switch signal {
        case .frustration:
            switch voice {
            case .warm:
                return "Sit with the frustration briefly — name what is hard without fixing it immediately. Then offer one small, doable move."
            case .authoritative:
                return "Name the frustration once, plainly. Then give the verdict: what specifically to change on the next rep."
            case .concise:
                return "Acknowledge in one clause. Then prescribe one move."
            case .executive:
                return "Name the friction, give the top-line fix. No preamble."
            case .persuasive:
                return "Validate the frustration with evidence — show what the data says is actually moving, then redirect."
            case .storytelling:
                return "Name the hard part of the arc they are in. Show where this chapter goes."
            case nil:
                return "Acknowledge the frustration briefly, then offer one concrete next step."
            }

        case .selfDoubt:
            switch voice {
            case .warm:
                return "Do not rush past doubt. Reflect back what you heard. Then cite one concrete piece of evidence of growth — a specific rep, a number that moved."
            case .authoritative:
                return "Counter doubt with evidence. Quote one specific number or rep that contradicts the doubting claim. Be factual, not cheerful."
            case .concise:
                return "One fact that contradicts the doubt. No reassurance speech."
            case .executive:
                return "Top-line evidence against the doubt. One data point, then the next action."
            case .persuasive:
                return "Build the counter-case: premise (doubt is normal at this stage), evidence (here is what moved), recommendation (do this next)."
            case .storytelling:
                return "Quote their own words from a strong rep. Show the distance between then and now."
            case nil:
                return "Cite one specific piece of evidence that counters the doubt, then give a concrete next step."
            }

        case .vulnerability:
            switch voice {
            case .warm:
                return "Honor the vulnerability. Do not immediately coach. Acknowledge what they shared, then ask one gentle question about what they need."
            case .authoritative:
                return "Name what they shared with respect. Brief acknowledgement, no therapy language. Then give the grounded perspective and one move."
            case .concise:
                return "Brief, respectful acknowledgement. Then one focused move that meets them where they are."
            case .executive:
                return "Acknowledge the disclosure with composure. Reframe toward preparation — what they can control."
            case .persuasive:
                return "Validate the feeling with a normalizing frame, then build the case for the next step."
            case .storytelling:
                return "Honor the moment of honesty. Frame it as part of the arc — this is what growth looks like from inside."
            case nil:
                return "Acknowledge the vulnerability briefly and with respect, then offer one supportive next move."
            }

        case .fatigue:
            switch voice {
            case .warm:
                return "Do not push harder. Validate the fatigue. Suggest a lighter rep or a pause. Ask what would make practice feel sustainable."
            case .authoritative:
                return "Name the fatigue as real. Prescribe a lighter session shape or a strategic rest. Do not lecture about consistency."
            case .concise:
                return "Fatigue is data. Prescribe rest or a lighter shape. One sentence."
            case .executive:
                return "Recommend: lighter load or strategic pause. Not everything requires pushing through."
            case .persuasive:
                return "Make the case for pacing. Rest is part of the training cycle, not a failure."
            case .storytelling:
                return "Frame the rest as part of the story. The pause between chapters matters."
            case nil:
                return "Acknowledge the fatigue. Suggest a lighter approach or rest without judgment."
            }

        case .celebrationSeeking:
            switch voice {
            case .warm:
                return "Celebrate genuinely. Name the specific win — quote a number or a moment. Stay in the celebration before moving to what is next."
            case .authoritative:
                return "Affirm the result with one specific citation. Then name what to build on — the celebration IS the next-move setup."
            case .concise:
                return "Name the win. One fact. Then the carry-forward."
            case .executive:
                return "Top-line: earned result. Cite the evidence. Then recommend the build."
            case .persuasive:
                return "Build the case for why the win matters — connect it to the pattern, not just the moment."
            case .storytelling:
                return "Mark the milestone in the arc. Quote their actual improvement. Frame what comes next as the next chapter."
            case nil:
                return "Recognize the win with one specific citation before moving to the next step."
            }

        case .breakthrough:
            switch voice {
            case .warm:
                return "Sit with the insight. Reflect it back. Ask what shifted. Then connect it to the work ahead."
            case .authoritative:
                return "Confirm the insight with evidence. Name what it unlocks for the next phase."
            case .concise:
                return "Good read. Name what it unlocks. One next move."
            case .executive:
                return "Confirmed. Here is what that insight means for the plan."
            case .persuasive:
                return "Connect the insight to the broader case. Show how it changes the evidence picture."
            case .storytelling:
                return "This is the turn in the story. Name what they saw. Connect it to what comes next."
            case nil:
                return "Confirm the insight, connect it to evidence, and name one next step it enables."
            }

        case .resistance:
            switch voice {
            case .warm:
                return "Do not force. Name the resistance without judgment. Ask what would make the work feel worth doing right now."
            case .authoritative:
                return "Name the avoidance pattern directly but without shaming. Give one reason the prescribed work matters, then let them choose."
            case .concise:
                return "Name it. Offer one alternative. Their call."
            case .executive:
                return "Flag the pattern. Recommend one adjusted action. Decision is theirs."
            case .persuasive:
                return "Build the case for why this particular work matters now. If the case does not land, offer an alternative."
            case .storytelling:
                return "Name the chapter they are avoiding. Show what is on the other side."
            case nil:
                return "Acknowledge the resistance without judgment. Offer one adjusted alternative."
            }

        case .comparison:
            switch voice {
            case .warm:
                return "Normalize the comparison impulse. Redirect to their own trajectory — what has shifted since they started."
            case .authoritative:
                return "Natural speakers are not the benchmark — deliberate practice is. Cite their own trajectory."
            case .concise:
                return "Their trajectory, not the comparison. One data point from their reps."
            case .executive:
                return "Reframe: benchmark is their own prior self, not someone else. Cite the delta."
            case .persuasive:
                return "Build the counter-case: natural talent is less predictive than deliberate practice. Cite their own evidence."
            case .storytelling:
                return "Every strong speaker has a version of this chapter. Tell their version — where they started, where they are."
            case nil:
                return "Redirect from comparison to their own trajectory. Cite one specific improvement."
            }

        case .overwhelm:
            switch voice {
            case .warm:
                return "Slow down. Name that it feels like a lot. Pick ONE thing and make it small. Ask which one thing feels most important right now."
            case .authoritative:
                return "Cut the list to one. Name the single highest-leverage move and shelve the rest."
            case .concise:
                return "One thing. Not three. Name it."
            case .executive:
                return "Prioritize: one action item. Park the rest."
            case .persuasive:
                return "Narrow the case to one premise. The rest is noise right now."
            case .storytelling:
                return "Zoom in. One scene, not the whole act. Name the smallest version of the next move."
            case nil:
                return "Reduce to one action. Name it specifically and shelve the rest."
            }

        case .curiosity:
            switch voice {
            case .warm:
                return "Match their curiosity. Answer the question with genuine detail, then connect it to their practice."
            case .authoritative:
                return "Answer directly, with the relevant evidence. Then name how it applies to their case."
            case .concise:
                return "Answer. Connect to their data. One next move."
            case .executive:
                return "Brief, substantive answer. Then the application to their case."
            case .persuasive:
                return "Build the explanation with evidence. Then show how it applies to their specific situation."
            case .storytelling:
                return "Tell the answer as a story they can see themselves inside of."
            case nil:
                return "Answer the question with substance, then connect it to their practice."
            }
        }
    }

    /// Scan recent user turns for a sustained emotional pattern. Returns a
    /// summary only when the same signal appears in 2+ of the last 4 turns —
    /// a single-turn signal is already handled by the per-turn detector. This
    /// is a HYPOTHESIS from keyword frequency, never a diagnosis.
    private static func detectArcPattern(
        recentUserTurns: [String]
    ) -> (signal: EmotionalSignal, turnCount: Int)? {
        guard recentUserTurns.count >= 2 else { return nil }

        let window = recentUserTurns.suffix(4)
        var weighted: [EmotionalSignal: Double] = [:]
        var counts: [EmotionalSignal: Int] = [:]
        var strongCounts: [EmotionalSignal: Int] = [:]

        for turn in window {
            for (signal, confidence) in gradedSignals(turn.lowercased()) {
                weighted[signal, default: 0] += confidence.weight
                counts[signal, default: 0] += 1
                if confidence == .strong { strongCounts[signal, default: 0] += 1 }
            }
        }

        // Surface a pattern only when the confidence-WEIGHTED evidence reaches
        // 2.0 (two strong turns, or one strong + soft echoes) AND at least one
        // mention was unambiguous. This is why two high-confidence turns
        // outrank four tentative ones: four soft mentions weigh 2.0 but carry
        // zero strong turns, so they never sustain on their own — avoiding a
        // confident pattern claim built from incidental keywords.
        guard let (signal, weight) = weighted.max(by: { $0.value < $1.value }),
              weight >= 2.0,
              (strongCounts[signal] ?? 0) >= 1 else {
            return nil
        }

        return (signal, counts[signal] ?? 0)
    }

    private static func isLowSignalGreeting(_ normalized: String) -> Bool {
        let greetings: Set<String> = [
            "hi", "hello", "hey", "yo", "hiya", "morning",
            "good morning", "good afternoon", "good evening"
        ]
        return greetings.contains(normalized)
    }

    private static func isChoiceOrCommitmentTurn(
        _ normalized: String,
        previousCoachReply: String?
    ) -> Bool {
        let directChoicePhrases = [
            "work on", "fix filler", "fix fillers", "stay here", "switch focus",
            "compare both", "choose another", "go with", "do that",
            "lets do that", "let s do that", "that one", "the first",
            "the second"
        ]
        if directChoicePhrases.contains(where: { normalized.contains($0) }) {
            return true
        }

        guard previousCoachOfferedChoice(previousCoachReply) else { return false }
        let shortAcknowledgements: Set<String> = [
            "yes", "yeah", "yep", "ok", "okay", "sure", "sounds good",
            "that", "this", "first", "second", "both"
        ]
        return shortAcknowledgements.contains(normalized)
    }

    private static func previousCoachOfferedChoice(_ previousCoachReply: String?) -> Bool {
        guard let previousCoachReply else { return false }
        let lower = previousCoachReply.lowercased()
        return containsAny(lower, [
            "which direction", "would you prefer", "or we can", "which would",
            "what is your priority", "pick one", "choose"
        ])
    }

    // MARK: - Tone-drill trajectory (Adaptation read for the chat coach)
    //
    // Turns the Adaptation read carried on a tone-drill signal into the
    // terse, citeable register the system prompt's intelligence floor
    // expects ("0% to 50%"). Mirrors the branching of
    // `RecommendationBiasEngine`'s drill blueprint copy — reinforce a
    // recovering drill, change a slipping one, name a stalled plateau —
    // but for the conversational surface rather than the next-practice
    // card, so the two never disagree about whether the work is landing.
    //
    // Returns nil when the signal carries no trajectory (`progress == nil`,
    // i.e. fewer than the 4 evaluated reps needed to split two disjoint
    // windows). The coach must not invent a trajectory it cannot see — same
    // honest-evidence bar the helper that produced the signal enforces.
    //
    // First string is the data line; the second is a guidance clause so the
    // model uses the read correctly (the system prompt's rule 8 is the
    // backstop, this is the in-context nudge).
    static func toneDrillTrajectoryLines(for signal: IMToneDrillSignal) -> [String]? {
        guard let progress = signal.progress else { return nil }
        let scenario = signal.scenario.title
        let tone = signal.targetTone.title
        let earlierPct = Int((progress.earlierRate * 100).rounded())
        let recentPct = Int((progress.recentRate * 100).rounded())

        let directionPhrase: String
        let guidance: String
        switch progress.direction {
        case .recovering:
            directionPhrase = "recovering"
            guidance = "The prescribed tone drill is landing — reinforce it and name the climb; do not restate the original miss as if nothing has changed."
        case .slipping:
            directionPhrase = "slipping"
            guidance = "The tone drill is not landing — suggest changing how they open the scenario rather than repeating the identical ask."
        case .stalled:
            directionPhrase = "flat — no movement yet"
            guidance = "The tone has not moved yet — acknowledge the plateau honestly and offer a different angle if the user asks."
        }

        let dataLine = "- \(tone) tone in \(scenario): tone-match \(earlierPct)% to \(recentPct)% (earliest vs latest reps) — \(directionPhrase)."
        return [dataLine, "- \(guidance)"]
    }

    // MARK: - Tone-drill resolved read (the win, for the chat coach)
    //
    // The complement to `toneDrillTrajectoryLines`. That speaks to a drill
    // still in flight; this speaks to one the user has *won* — a scenario
    // whose committed tone used to miss but now holds above the drill bar.
    // Same terse, citeable register ("0% to 100%") so the two never read
    // as different voices. Two lines: a data line naming the scenario +
    // tone + the climb, and a guidance clause so the model names the win
    // once and moves the user to the next target rather than re-prescribing
    // a drill they have already beaten — the in-context backstop to the
    // system prompt's rule 9. Honest about provenance: the recovery is
    // observed in the user's own reps, never proof a drill caused it.
    static func toneDrillResolvedLines(for resolved: IMToneDrillResolved) -> [String] {
        let scenario = resolved.scenario.title
        let tone = resolved.targetTone.title
        let earlierPct = Int((resolved.earlierRate * 100).rounded())
        let recentPct = Int((resolved.recentRate * 100).rounded())
        let dataLine = "- \(tone) tone in \(scenario): tone-match \(earlierPct)% to \(recentPct)% (earliest vs latest reps) — holding above the drill bar now."
        let guidance = "- The user closed this tone gap; name the win once and point them at the next target rather than re-prescribing the solved drill. Observed in their own reps, not proof a drill caused it."
        return [dataLine, guidance]
    }

    // MARK: - Tone-drill solved freshness window (round 41)
    //
    // `IMHistorySummary.toneDrillResolved(from:)` returns the resolved read
    // forever once a scenario crosses the drill bar — the engine self-clears
    // only on a real relapse below the threshold, which is correct for the
    // recommendation engine (a once-solved drill should not be re-prescribed
    // out of nowhere). But surfaced verbatim into the chat-coach context, it
    // means the chat coach reads the same TONE-DRILL SOLVED section on every
    // reply for months after the crossing — beating a dead horse on a win the
    // user closed weeks ago, exactly the register a human coach moves past.
    //
    // The line's own guidance ("name the win once and point them at the next
    // target rather than re-prescribing the solved drill") was the in-context
    // intent from round 13; this freshness gate is the structural backstop —
    // after the recency window, the context simply doesn't carry the SOLVED
    // section, so the chat coach moves on whether the model remembered to or
    // not.
    //
    // The window mirrors `repeatedPushbackRecencyDays` (round 38) by deliberate
    // cross-surface symmetry — "win is fresh enough to name" and "pushback
    // verdict is fresh enough to dampen" share the same coach-parity ramp on
    // stage #3 (Intervention) and #4 (Adaptation), and a single number is
    // easier for a future round to tune than two parallel constants.
    //
    // Anchored against the user's most-recent practice rep (not wall-clock)
    // so the predicate is pure, intrinsically test-stable, and reads as
    // "fresh relative to the user's cadence" — a user who's actively
    // practicing other scenarios deserves to see the win named for longer
    // than a user who hasn't practiced at all in a month.
    static let toneDrillSolvedRecencyDays: Int = 14

    static func toneDrillSolvedIsFresh(_ resolved: IMToneDrillResolved, now: Date) -> Bool {
        let elapsed = now.timeIntervalSince(resolved.lastEvaluatedDate)
        guard elapsed >= 0 else { return false }
        let windowInterval = TimeInterval(toneDrillSolvedRecencyDays * 24 * 60 * 60)
        return elapsed <= windowInterval
    }

    // MARK: - Tone-drill trajectory freshness window (round 42)
    //
    // The mirror of round 41's SOLVED freshness gate on the still-in-flight
    // TRAJECTORY surface. `toneDrillSignal(from:)` returns a sub-bar scenario
    // whenever `evaluatedCount >= 3` AND the hit rate is below
    // `toneDrillMatchRateThreshold`. There is no recency gate on the
    // latest-evaluated rep, so a scenario the user practiced 60 days ago,
    // never returned to, and is still below the bar would surface a
    // TRAJECTORY line on every chat reply forever — the same "beating a dead
    // horse" register round 41 closed on the SOLVED side.
    //
    // The recommendation engine should still prescribe the drill on the next
    // IM launch (the gap is real — the user has not closed it). The freshness
    // gate is ONLY on the chat-coach context surface — past the window, the
    // chat coach doesn't re-issue the trajectory commentary on a long-stale
    // read, and the coach naturally moves on to a scenario the user is
    // actually practicing.
    //
    // Defensive scoping (intentional restraint, same shape as round 41):
    //
    //   • SAME constant as the SOLVED surface (`toneDrillSolvedRecencyDays`).
    //     The chat coach's freshness contract is one number — "fresh
    //     relative to the user's cadence" — and SOLVED + TRAJECTORY share
    //     the same coach-parity ramp on stage #3 (Intervention) and #4
    //     (Adaptation). A future tune of the constant touches both surfaces
    //     in lockstep, which is the right semantics.
    //
    //   • SAME anchor (`sessions.lazy.map(\.date).max()`, the user's
    //     most-recent practice rep across all history). A user actively
    //     practicing other scenarios deserves to see the trajectory named
    //     for longer; a user who's stopped practicing entirely sees it age
    //     out at 14 days flat.
    //
    //   • SAME inclusive 14-day boundary contract as rounds 38/39/40/41.
    //
    //   • Defensive negative-elapsed guard (a `now` pre-dating the latest
    //     evaluated rep returns false — bad anchor, refuse to fire).
    //
    //   • Per-scenario gate, not a global TRAJECTORY-off switch. The freshness
    //     anchor is the LATEST evaluated rep in the prescribed scenario.
    //     `toneDrillSignal(from:)` picks the worst-hit-rate scenario, so the
    //     prescribed scenario can differ from the user's most-recent rep's
    //     scenario; the gate compares the prescribed scenario's last
    //     evaluated rep against the user's overall most-recent rep — drops
    //     the section when the prescribed scenario itself has gone cold,
    //     regardless of what else the user is practicing.
    //
    // Engine state: NOTHING changes. The recommendation engine still
    // prescribes the drill (the gap is real). The TONE-DRILL TRAJECTORY block
    // is the only surface that gates on the freshness window.
    static func toneDrillTrajectoryIsFresh(
        signal: IMToneDrillSignal,
        in sessions: [PracticeSession],
        now: Date
    ) -> Bool {
        guard let lastEvaluatedDate = IMHistorySummary.latestEvaluatedRepDate(
            from: sessions,
            scenario: signal.scenario
        ) else { return false }
        let elapsed = now.timeIntervalSince(lastEvaluatedDate)
        guard elapsed >= 0 else { return false }
        let windowInterval = TimeInterval(toneDrillSolvedRecencyDays * 24 * 60 * 60)
        return elapsed <= windowInterval
    }

    // MARK: - Prompt-grounded relevance (the substance read for the chat coach)
    //
    // Initiative #8 gave the deterministic Relevance rating + both AI reads a
    // shared `PracticeEvaluator.PromptRelevanceRead` ("did you answer the
    // question / lead vs buried"). This carries the SAME read into the
    // conversational coach as a terse, citeable section — closing the
    // coherence gap where the chat coach only inherited it indirectly through
    // the free-text LAST REP NOTE.
    //
    // Same shape as `toneDrillTrajectoryLines`: a data line citing the
    // observed lexical overlap + the shared verdict, and a guidance clause so
    // the model uses it honestly (the system prompt's rule 14 is the
    // backstop). Returns nil below the evidence floor (`promptAnswerVerdict`
    // is nil) — the coach must not judge "did you answer it" on a too-thin
    // prompt or transcript, exactly as the rating defaults high there. The
    // verdict mapping is the SAME one the Timed three-part note reads, so the
    // chat coach and the post-rep note can never disagree about a rep.
    /// Format a `MemorabilityAnalyzer.Read` into chat-context lines, framed as
    /// observable structure (never a verdict on the person). Returns nil when
    /// there's no actionable signal so the caller emits nothing on a clean rep.
    static func structureReadLines(for read: MemorabilityAnalyzer.Read) -> [String]? {
        // Only the close is asserted as a fault — it's the reliably detectable
        // bookend. A positive opening read is affirmed (not nagged); a
        // non-oriented opening says nothing (absence isn't proof of a cold open).
        guard case .trailedOff(let tail) = read.closing else { return nil }
        var lines: [String] = [
            "- Close: trailed off on \"\(tail)\" — it did not land a committed final line."
        ]
        if case .oriented = read.opening {
            lines.append("- Opening: did orient the listener up front — affirm the open worked; keep the one move on the close.")
        }
        return lines
    }

    static func promptRelevanceLines(
        for read: PracticeEvaluator.PromptRelevanceRead,
        prompt: String?
    ) -> [String]? {
        guard let verdict = PracticeEvaluator.promptAnswerVerdict(for: read) else { return nil }
        let overlapPct = Int((read.overlap * 100).rounded())
        let leadPct = Int((read.firstSentenceOverlap * 100).rounded())

        // Positional verdict (initiative #10): the band is about WHERE the
        // point landed, not only how much of the question was echoed. The data
        // line now reports both the lead overlap and the whole-rep overlap so
        // the coach can cite the gap that defines a buried lede.
        let verdictPhrase: String
        let guidance: String
        switch verdict {
        case .answered:
            verdictPhrase = "the point led — the question's key terms were right up front"
            guidance = "The rep led with the answer — affirm the substance briefly if relevant, then coach delivery from there."
        case .partial:
            verdictPhrase = "the point did not clearly lead"
            guidance = "The answer's key terms did not clearly lead — if it fits, coach making the main point the first sentence. Lexical association, never proof the answer was off-topic."
        case .buried:
            verdictPhrase = "the point arrived late — present across the rep but missing from the lead"
            guidance = "The point was in there but buried — when relevant, coach leading with it so it lands in the first sentence. This is lexical association on the rep's own words, never proof the answer was off-topic."
        }

        var out: [String] = []
        let questionTail = promptRelevanceQuestionTail(prompt)
        if !questionTail.isEmpty {
            out.append("- Question asked: \(questionTail)")
        }
        out.append("- The first sentence echoed \(leadPct)% of the question's key terms; the whole answer echoed \(overlapPct)% (lexical overlap) — \(verdictPhrase).")
        out.append("- \(guidance)")
        return out
    }

    // MARK: - Argument logic (the reasoning-shape read for the chat coach)
    //
    // The deterministic claim->evidence->implication read
    // (`PracticeEvaluator.argumentStructure` / `argumentLogicVerdict`) surfaced
    // for the conversational coach as a terse, citeable section — the SAME read
    // that drives the Timed insight line, so the chat coach and the post-rep
    // insights can never disagree about a rep's reasoning shape (one source of
    // truth). DISTINCT from PROMPT RELEVANCE above: that reads whether the answer
    // engaged the QUESTION (topic); this reads whether the answer is built as an
    // ARGUMENT (claim, why, so-what) regardless of topic. Returns nil below the
    // content-word floor OR when no claim was even asserted (the verdict is nil),
    // so the coach never judges reasoning on a fragment. Framed as lexical
    // association on the rep's own discourse markers, never proof the reasoning is
    // sound (rule 14 is the backstop).
    static func argumentLogicLines(transcript: String) -> [String]? {
        let read = PracticeEvaluator.argumentStructure(transcript: transcript)
        guard let verdict = PracticeEvaluator.argumentLogicVerdict(for: read) else { return nil }
        let dataLine: String
        let guidance: String
        switch verdict {
        case .fullChain:
            dataLine = "- Reasoning shape: claim + reason + implication all present — the answer is built as an argument."
            guidance = "- The rep has a full reasoning spine; if relevant, affirm it briefly and coach delivery or tightening from there. Lexical association on the rep's own markers, never proof the reasoning is sound."
        case .claimWithSupport:
            if read.hasEvidence {
                dataLine = "- Reasoning shape: claim backed by a reason, but no implication — it never carries forward to what it means."
                guidance = "- When it fits, coach closing the loop: one line on what the point means or leads to. Lexical association, never a verdict on correctness."
            } else {
                dataLine = "- Reasoning shape: claim plus where it leads, but no stated reason — asserted and projected, never justified."
                guidance = "- When it fits, coach adding one reason (a \"because…\") so the argument holds. Lexical association, never a verdict on correctness."
            }
        case .assertionOnly:
            dataLine = "- Reasoning shape: a clear claim, but no reason and no implication — asserted, not argued."
            guidance = "- If it fits the moment, coach the claim -> reason -> implication spine so the next answer has a backbone. This is lexical association on the rep's own markers, never proof the answer was wrong."
        }
        return [dataLine, guidance]
    }

    /// Collapses + truncates the rep's stored prompt for the PROMPT RELEVANCE
    /// data line so the coach has the question to quote without dumping a long
    /// prompt into the bounded context block. Empty when the prompt is nil or
    /// blank (no placeholder line injected).
    private static func promptRelevanceQuestionTail(_ prompt: String?) -> String {
        guard let prompt else { return "" }
        let collapsed = prompt
            .split { $0.isWhitespace || $0.isNewline }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return "" }
        let limit = 120
        if collapsed.count <= limit { return "\"\(collapsed)\"" }
        let clipped = String(collapsed.prefix(limit)).trimmingCharacters(in: .whitespaces)
        return "\"\(clipped)…\""
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

    // MARK: - Intervention-review opener
    //
    // Seed message for the post-rep "Review with coach" prompt
    // (`InterventionReviewPromptCard`). Surfaced when the active
    // `CoachIntervention.isReviewDue(at:)` predicate returns true —
    // i.e. the user has logged at least `minimumFollowedRepsForReview`
    // followed reps AND the `reviewDueAt` cadence has elapsed.
    //
    // Shape mirrors `sessionOpener` exactly so the AskNoumView render
    // logic stays uniform: short fact-lead + voice-shaped ask. The
    // lead names the case (mode + focus + followed-rep depth) so the
    // coach reply has the verdict scaffolding already in scope; the
    // ask gives the voice-aligned question the user wants answered.
    //
    // Brand-voice rules: no exclamation, no "Let's", no urgency
    // framing. The coach is a professional revisiting a plan, not a
    // notification pinging the user.

    /// Seed opener for the post-rep intervention-review prompt. The
    /// `intervention.focus` (or `title` fallback) names the case; the
    /// followed-rep depth gives the model the evidence basis; the
    /// voice mapping shapes the question the user wants to ask.
    static func interventionReviewOpener(
        intervention: CoachIntervention,
        voice: SpeakingStyleGoal?,
        reflectionPattern: CoachReflectionPattern? = nil
    ) -> String {
        let modeLabel = intervention.mode.displayLabel
        let focus = (intervention.focus?.isEmpty == false ? intervention.focus : intervention.title)
            ?? intervention.title
        let focusLower = focus.lowercased()
        let repNoun = intervention.followedRepCount == 1 ? "rep" : "reps"
        let lead = "Time to review the active case: \(modeLabel) for \(focusLower), \(intervention.followedRepCount) followed \(repNoun) in."
        let subjectiveCheck = reflectionPattern.map {
            "Also review the subjective pattern as self-report, not diagnosis: \($0.interventionReviewQuestion)."
        }
        let ask: String
        switch voice {
        case .authoritative:
            ask = "Is this still the right intervention, or do we adapt?"
        case .warm:
            ask = "Is this still feeling like the right work?"
        case .concise:
            ask = "Keep, adapt, or replace?"
        case .persuasive:
            ask = "Make the case — keep going or change tack?"
        case .executive:
            ask = "Verdict: continue, adapt, or replace?"
        case .storytelling:
            ask = "Where does this arc go next?"
        case .none:
            ask = "Should we keep going, adapt, or change tack?"
        }
        return [lead, subjectiveCheck, ask]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    /// Compact display headline for the AskNoumView empty-state case-
    /// review chip. The chip is a short-form sibling of
    /// `InterventionReviewPromptCard` — same trigger predicate
    /// (`CoachIntervention.isReviewDue(at:)`), same coach voice, but
    /// a terser surface because it lives inside the chat empty state
    /// alongside other one-line starter prompts, not as a dedicated
    /// post-rep card.
    ///
    /// Mirrors `InterventionReviewPromptCard.headlineCopy(for:)`'s
    /// focus-or-title fallback so the user reads continuous voice
    /// across the two surfaces (the summary card and the AskNoum
    /// chip). The chip text is the DISPLAY label only — the actual
    /// opener dispatched when the user taps it is
    /// `interventionReviewOpener(intervention:voice:)`, which carries
    /// the case scaffolding (mode + focus + followed-rep depth) and
    /// the voice-shaped review ask. The reply the user gets is the
    /// same conversation no matter which surface they arrived from.
    ///
    /// Brand-voice rules: no exclamation, no "Let's", lower-cased
    /// focus (mid-sentence after the em-dash, not a proper noun).
    static func interventionReviewStarterHeadline(for intervention: CoachIntervention) -> String {
        let focus = (intervention.focus?.isEmpty == false ? intervention.focus : intervention.title)
            ?? intervention.title
        return "Review the active case — \(focus.lowercased())"
    }

    // MARK: - Revised-read opener (post-rep user-pushback Ask Noum seed)
    //
    // Round 29 — closes Future Move #11 from the round-28 HANDOFF. The
    // `RevisedReadCard` surfaces the user-pushback line as a visual
    // acknowledgement on the post-rep `SummaryView`. Without this lift, a
    // tap on the existing `TalkToNoumCTACard` on the same rep still
    // dispatches the generic `sessionOpener` ("Just finished a Timed rep
    // — 60s, 3 fillers, 8/10. Give me your read."), and the chat thread
    // starts from a clean rep summary as if the user had never tapped
    // `.rejected`. The case-file turn that `RevisedReadCard` named on the
    // summary screen drops on the floor the instant the user opens the
    // conversation.
    //
    // This opener replaces the generic seed on exactly the rep where
    // `RevisedReadCard` is showing (the `freshRevisedReadChange` gate in
    // `SummaryView`) so the chat thread starts where the card left off:
    // the user names the pushback, quotes the coach's revised read, and
    // invites the coach to pick up the case file in their voice.
    //
    // Shape mirrors `sessionOpener` and `interventionReviewOpener`:
    // pure function, voice-mapped ask, short fact-lead. The lead is
    // pinned as a static constant for the same reason
    // `interventionReviewOpenerLead` is — a future predicate (e.g. a
    // chat-thread classifier that wants to detect a revised-read opener
    // for analytics or for showing a follow-up chip row) can match the
    // prefix without re-running the full string composition.
    //
    // Brand-voice rules: no exclamation, no "Let's", no urgency framing.
    // The user is the one typing the message into the thread, so the
    // first-person framing ("I flagged") matches every other opener that
    // gets dispatched from a tap — `sessionOpener` ("Just finished..."),
    // `interventionReviewOpener` ("Time to review..."), and the
    // hypothesis ack chips ("Yes — that's the read", "Adapt the read").

    /// Lead prefix on every first-cycle `revisedReadOpener`. Lifted as a
    /// constant so a future predicate (e.g. a chat-thread classifier that
    /// detects a revised-read seed for a follow-up chip row, mirroring the
    /// round-26 `shouldShowHypothesisAcknowledgement` predicate) can match
    /// the prefix without depending on the voice-shaped ask suffix.
    static let revisedReadOpenerLead = "Picking up the case file — I flagged the prior read as off."

    /// Round-35 second-cycle lead. Surfaced when the carrying course change
    /// documents a second-cycle pushback (round 33's marker — the engine
    /// detected that the latest pushback rebuild itself followed a prior
    /// pushback rebuild). Mirrors `RevisedReadCard.secondCycleHeadlineCopy`
    /// ("You flagged the rebuilt read as off too.") in user voice so the
    /// chat seed names the repeated adapt the same way the post-rep card
    /// did on the same rep. The `shouldShowRevisedReadFollowUp` predicate
    /// matches against BOTH leads so the round-30 chip row still fires
    /// when the user dispatches a second-cycle seed.
    static let revisedReadOpenerSecondCycleLead = "Picking up the case file — I flagged the rebuilt read as off too."

    /// Seed opener for the post-rep "Talk to Noum" CTA when the just-
    /// finished rep produced a fresh `.rejected`-driven adaptation entry
    /// (the same gate the `RevisedReadCard` reads). Names the user's
    /// pushback, quotes where the coach's revised read sits, and ends
    /// with a voice-shaped invitation for the coach to pick up the case
    /// file. Pure function — no store reads.
    ///
    /// Why the gate lives in `SummaryView`, not here: this helper has no
    /// way to know whether the carrying memory's adaptation log is fresh.
    /// `SummaryView.talkToNoumOpener` walks the predicates and decides
    /// whether to call this function or fall back to the generic
    /// `sessionOpener`. One home for the eligibility logic.
    ///
    /// The trimmed-period treatment of `workingHypothesis` mirrors
    /// `RevisedReadCard.bodyCopy(workingHypothesis:)` so the same
    /// hypothesis text reads as a single sentence on both surfaces (the
    /// post-rep card and the chat seed). A nil or whitespace-only
    /// hypothesis falls back to a "still forming" line so the seed never
    /// reads "The revised read you're holding is: ." to the model.
    static func revisedReadOpener(
        workingHypothesis: String?,
        voice: SpeakingStyleGoal?
    ) -> String {
        let lead = revisedReadOpenerLead
        let body: String
        if let stripped = strippedHypothesisForOpener(workingHypothesis) {
            body = "The revised read you're holding is: \(stripped)."
        } else {
            body = "The revised read is still forming."
        }
        return "\(lead) \(body) \(revisedReadOpenerAsk(for: voice))"
    }

    /// Round-35 second-cycle opener. Mirrors `revisedReadOpener` shape but
    /// swaps the lead to `revisedReadOpenerSecondCycleLead` and the body
    /// verb to "next read" (matches `RevisedReadCard.secondCycleBodyCopy`
    /// so the post-rep card and the chat seed read with one voice on the
    /// cycle distinction). Voice-shaped ask is unchanged — the ask was
    /// always cycle-agnostic ("Where does the read land now?") and round
    /// 35 preserves that invariant so the seven voice branches keep
    /// matching between the two composers.
    static func secondCycleRevisedReadOpener(
        workingHypothesis: String?,
        voice: SpeakingStyleGoal?
    ) -> String {
        let lead = revisedReadOpenerSecondCycleLead
        let body: String
        if let stripped = strippedHypothesisForOpener(workingHypothesis) {
            body = "The next read you're holding is: \(stripped)."
        } else {
            body = "The next read is still forming."
        }
        return "\(lead) \(body) \(revisedReadOpenerAsk(for: voice))"
    }

    /// Round-35 opener router. Reads `documentsSecondCyclePushback` on the
    /// passed change and dispatches to the second-cycle composer when the
    /// round-33 marker is present, falling through to the first-cycle
    /// `revisedReadOpener` otherwise. Pure router — same shape as
    /// `RevisedReadCard.headlineCopy(for:)` / `bodyCopy(for:workingHypothesis:)`
    /// so the post-rep card and the chat seed gate on the same predicate.
    /// `SummaryView.talkToNoumOpener` is the single call site.
    static func revisedReadOpener(
        for change: CoachCourseChange,
        workingHypothesis: String?,
        voice: SpeakingStyleGoal?
    ) -> String {
        if change.documentsSecondCyclePushback {
            return secondCycleRevisedReadOpener(workingHypothesis: workingHypothesis, voice: voice)
        }
        return revisedReadOpener(workingHypothesis: workingHypothesis, voice: voice)
    }

    /// Shared hypothesis trim. The engine's hypothesis clause typically
    /// ends with `.`; both opener bodies wrap it in a "…: <hypothesis>."
    /// line which would otherwise produce `..`. Returns nil on nil /
    /// blank input so the caller can pick the "still forming" fallback
    /// without re-running the trim. Mirrors
    /// `RevisedReadCard.strippedHypothesis(_:)` — a future edit (e.g. a
    /// multi-period strip) lands in both places.
    private static func strippedHypothesisForOpener(_ raw: String?) -> String? {
        guard let raw = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        if raw.hasSuffix(".") {
            return String(raw.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
    }

    /// Shared voice-shaped ask. Lifted into one function so the first-
    /// cycle and second-cycle composers can never drift on the seven
    /// voice mappings — a future edit to one branch ripples to both.
    private static func revisedReadOpenerAsk(for voice: SpeakingStyleGoal?) -> String {
        switch voice {
        case .authoritative:
            return "Where does the read land now?"
        case .warm:
            return "What does this open up?"
        case .concise:
            return "Where does this go?"
        case .persuasive:
            return "Make the case for the new read."
        case .executive:
            return "Brief me on what shifted."
        case .storytelling:
            return "What chapter does this start?"
        case .none:
            return "Where does this go from here?"
        }
    }

    // MARK: - Goal-intent detection (chat-driven voice set / change)
    //
    // The deterministic seam behind the in-chat "set or change your voice"
    // affordance. The LLM is NEVER trusted to self-report a profile write
    // (the service is always free-text, AICoachChatService.swift:8-10); this
    // pure function reads the user's typed text + the current voice state and
    // decides whether the user is asking to SET (cold start) or CHANGE
    // (existing voice -> a new one) their speaking-style goal, and which voice
    // they named (if any).
    //
    // `AskNoumView.send(_:)` calls this on every entry point (typed / voice /
    // chip / inject) BEFORE dispatching the reply. A non-nil result drives the
    // ephemeral confirmation card (the user CONFIRMS the write with a tap —
    // human-in-the-loop) and injects a GOAL-section context line so the coach
    // PROPOSES rather than assumes (see `userContext` GOAL block).
    //
    // Mirror of the existing pure predicates (`shouldShowHypothesisAcknowledgement`,
    // `shouldShowRevisedReadFollowUp`): pure, testable without standing up any
    // store, deterministic so the same text always yields the same intent.

    /// A detected request to set or change the speaking-style goal from chat.
    /// `requestedVoice` is `nil` when the user asked to set/change a voice but
    /// named no concrete target ("help me pick one") — the card then offers the
    /// full voice palette as a guided pick. `kind` is `.initialSet` when the
    /// profile carries no voice yet (cold start) else `.change`.
    struct GoalIntent: Equatable {
        enum Kind: Equatable {
            case initialSet
            case change
        }
        var requestedVoice: SpeakingStyleGoal?
        var kind: Kind
    }

    /// Lowercased keyword aliases per voice. A user rarely types the exact
    /// `rawValue` or display title — they say "commanding", "boardroom",
    /// "vivid". `SpeakingStyleGoal.resolve` covers rawValue + title; this map
    /// covers the natural-language register. Intentionally narrow + unambiguous
    /// so two voices never both match the same word.
    private static let voiceAliases: [(voice: SpeakingStyleGoal, terms: [String])] = [
        (.authoritative, ["authoritative", "commanding", "command", "assertive", "in charge", "hard to ignore"]),
        (.warm,          ["warm", "welcoming", "friendly", "approachable", "personable"]),
        (.concise,       ["concise", "sharp", "crisp", "succinct", "to the point", "tight"]),
        (.persuasive,    ["persuasive", "convince", "convincing", "compelling"]),
        (.executive,     ["executive", "boardroom", "board room", "leadership presence", "executive presence"]),
        (.storytelling,  ["storytelling", "story telling", "vivid", "story", "narrative"]),
    ]

    /// SECONDARY, descriptor-level closest-match for when the user names a
    /// QUALITY they want to sound like that isn't one of the primary register
    /// words above — e.g. "I want to sound more engaging". Each term is drawn
    /// from (or sits adjacent to) the voice's user-facing `coachingDescription`
    /// adjectives, so "engaging"/"memorable" → Storytelling, "composed"/
    /// "high-level" → Executive presence, and so on. Terms are deliberately
    /// DISJOINT from `voiceAliases` (no overlap) and from each other, and this
    /// map is consulted ONLY after `voiceAliases` misses AND only when an
    /// explicit set/change phrase is present — so a casual "that felt engaging"
    /// (no intent cue) never resolves to a voice and never surfaces the card.
    /// The mapping only ever yields one of the six canonical
    /// `SpeakingStyleGoal` cases; it can never invent a voice. A miss falls
    /// through to `requestedVoice == nil`, which opens the guided-pick palette
    /// rather than guessing.
    private static let voiceDescriptorAliases: [(voice: SpeakingStyleGoal, terms: [String])] = [
        (.authoritative, ["steady", "assured", "authority", "gravitas"]),
        (.warm,          ["encouraging", "trustworthy", "genuine", "easy to trust", "down to earth"]),
        (.concise,       ["efficient", "clean", "no-nonsense", "no nonsense", "brief", "punchy"]),
        (.persuasive,    ["well-supported", "well supported", "intentional", "persuade"]),
        (.executive,     ["composed", "high-level", "high level", "polished", "senior", "boardroom-ready"]),
        (.storytelling,  ["engaging", "memorable", "captivating", "vividly"]),
    ]

    /// Phrasings that signal the user wants to SET or CHANGE their voice goal
    /// (as opposed to merely discussing a voice). Lowercased substring match.
    /// Kept deliberately broad on intent but the actual write is always gated
    /// behind the user's explicit card tap, so a false-positive only surfaces
    /// a dismissible card — never a silent write.
    private static let goalIntentPhrases: [String] = [
        "set my voice", "set my goal", "set my communication style", "set my style",
        "set my speaking", "change my voice", "change my goal", "change my style",
        "change my communication", "change my speaking", "switch my voice",
        "switch to", "switch my goal", "work on", "instead of", "i want to be",
        "i want to sound", "i'd rather", "make my voice", "update my voice",
        "update my goal", "change it to", "set it to", "pick a voice", "pick my voice",
        "choose a voice", "choose my voice", "help me pick", "help me choose",
        "can i set", "can you set", "can i change", "can we set", "can we change",
        "save my goal", "save my voice", "save it",
    ]

    /// Resolve the voice the user named in `lowered`, if any — exact
    /// resolve first (rawValue / title), then alias keywords. Returns the
    /// first voice whose alias appears; the alias lists are disjoint so order
    /// only matters for the (absent) overlap case.
    private static func resolveRequestedVoice(in lowered: String) -> SpeakingStyleGoal? {
        // Exact rawValue / display-title hit (e.g. "warm and welcoming").
        for voice in SpeakingStyleGoal.allCases {
            if lowered.contains(voice.rawValue) { return voice }
            if lowered.contains(voice.title.lowercased()) { return voice }
        }
        // Natural-language alias hit.
        for entry in voiceAliases {
            if entry.terms.contains(where: { lowered.contains($0) }) {
                return entry.voice
            }
        }
        return nil
    }

    /// SECONDARY closest-match: when the primary resolve misses, map a named
    /// QUALITY ("engaging", "composed") onto the nearest of the six canonical
    /// voices via `voiceDescriptorAliases`. Returns the FIRST voice whose
    /// descriptor term appears — the lists are disjoint so order is immaterial.
    /// Returns `nil` when nothing maps, so the caller routes to the guided pick
    /// rather than inventing a voice. Caller MUST gate this behind an explicit
    /// set/change intent cue so a casual mention never resolves a voice.
    private static func resolveDescriptorVoice(in lowered: String) -> SpeakingStyleGoal? {
        for entry in voiceDescriptorAliases {
            if entry.terms.contains(where: { lowered.contains($0) }) {
                return entry.voice
            }
        }
        return nil
    }

    /// Deterministically detect whether `text` is a request to set or change
    /// the speaking-style goal. Returns `nil` for any non-goal text (the
    /// overwhelming majority of chat turns) so the confirmation card never
    /// surfaces spuriously.
    ///
    /// Detection requires EITHER an explicit set/change phrase OR a named voice
    /// paired with a light intent cue, so "what does authoritative mean?"
    /// (a question about a voice, no intent) does NOT fire, while "I want to
    /// work on authoritative" and "set my voice to warm" do. When a phrase
    /// fires but no concrete voice resolves ("help me pick a voice"), the
    /// result carries `requestedVoice == nil` so the card offers a guided pick.
    ///
    /// When an explicit set/change phrase is present but no canonical voice
    /// resolves, a SECOND closest-match pass (`resolveDescriptorVoice`) maps a
    /// named quality ("engaging" → Storytelling) onto the nearest of the six;
    /// if that also misses, `requestedVoice` stays `nil` (guided pick). The
    /// second pass is gated on the phrase, so a bare quality mention never fires.
    ///
    /// - Parameters:
    ///   - text: the user's raw chat turn.
    ///   - currentVoice: the profile's current voice, or `nil` for cold start.
    ///     Drives `kind`: `.initialSet` when `nil`, else `.change`.
    static func detectGoalIntent(_ text: String, currentVoice: SpeakingStyleGoal?) -> GoalIntent? {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !lowered.isEmpty else { return nil }

        let resolved = resolveRequestedVoice(in: lowered)
        let hasIntentPhrase = goalIntentPhrases.contains { lowered.contains($0) }

        // Fire only when the user clearly wants to set/change a voice:
        //   • an explicit set/change phrase (with or without a named voice), OR
        //   • a named voice AND a "goal/voice/style" anchor word — so a bare
        //     mention of a voice in conversation doesn't trip the card.
        let mentionsGoalAnchor = lowered.contains("voice")
            || lowered.contains("goal")
            || lowered.contains("style")
        let namedVoiceWithAnchor = resolved != nil && mentionsGoalAnchor

        guard hasIntentPhrase || namedVoiceWithAnchor else { return nil }

        // Closest-match SECOND pass: if no canonical voice resolved but the user
        // DID express an explicit set/change phrase, try to map a named quality
        // ("engaging" → Storytelling) onto the nearest of the six voices. Gated
        // on `hasIntentPhrase` (never on a bare mention) so "that felt engaging"
        // can't reach this. A miss leaves `requestedVoice` nil → the card opens
        // the guided-pick palette; we NEVER invent a voice outside the six.
        let requested = resolved ?? (hasIntentPhrase ? resolveDescriptorVoice(in: lowered) : nil)

        return GoalIntent(
            requestedVoice: requested,
            kind: currentVoice == nil ? .initialSet : .change
        )
    }

    /// Count the user-confirmed voice-goal changes recorded in `adaptationLog`
    /// within `window` of `now` — the anti-thrash substrate. Only entries whose
    /// `reason` carries `CoachCourseChange.voiceChangeMarker` count (engine
    /// lever shifts and hypothesis rejections are excluded). The log is already
    /// bounded to the last 8 by the recorder, so this is cheap. When the count
    /// reaches the threshold the GOAL block surfaces a tentative
    /// "you've switched N times — give the current voice more reps" note; the
    /// note NEVER blocks a confirm (the choice is the user's).
    ///
    /// - Parameters:
    ///   - adaptationLog: the bounded course-change history (nil-safe).
    ///   - within: the recency window (default 7 days).
    ///   - now: reference time (default now).
    static func recentVoiceChangeCount(
        adaptationLog: [CoachCourseChange]?,
        within window: TimeInterval = 7 * 24 * 60 * 60,
        now: Date = Date()
    ) -> Int {
        guard let log = adaptationLog else { return 0 }
        let cutoff = now.addingTimeInterval(-window)
        return log.filter { $0.documentsVoiceChange && $0.changedAt >= cutoff }.count
    }

    /// Anti-thrash threshold: at or above this many confirmed voice changes
    /// inside the recency window, the GOAL block surfaces a tentative
    /// "give the current voice more reps" note. A NOTE, never a block — the
    /// user can always still confirm.
    static let voiceThrashThreshold = 2

    /// The GOAL-section lines for a detected set/change intent on the current
    /// turn. Pure so it can be tested without `userContext`'s full parameter
    /// list. Emits:
    ///   • cold start (`.initialSet`): a propose-not-committed line so the
    ///     coach helps the user set the voice in the moment but waits for the
    ///     in-app confirm.
    ///   • change (`.change`): a trade-off line (name what they've been building
    ///     in the current voice; raise it as a question, never silently switch —
    ///     reusing systemPrompt rule 15's posture on the distinct VOICE axis),
    ///     plus an anti-thrash note when `recentVoiceChangeCount` is at/above
    ///     the threshold.
    /// All framing keeps the honesty invariants: weak evidence -> tentative;
    /// the change is the user's call; never punish-shame a desire to change.
    static func goalIntentContextLines(
        intent: GoalIntent,
        currentVoice: SpeakingStyleGoal?,
        adaptationLog: [CoachCourseChange]?,
        now: Date = Date()
    ) -> [String] {
        var lines: [String] = []
        let targetClause: String = {
            if let v = intent.requestedVoice { return v.title }
            return "a voice they have not named yet"
        }()

        switch intent.kind {
        case .initialSet:
            lines.append("- GOAL INTENT (this turn): the user is asking to SET their voice to \(targetClause). Help them choose it now — but do NOT assume it is set. They confirm in-app with one tap; the change is not committed until they do.")
            if intent.requestedVoice == nil {
                lines.append("- They have not named a specific voice. Offer a short, plain guide to the options rather than picking for them.")
            }
        case .change:
            // The "from" voice grounds the trade-off. Fall back gracefully when
            // the current voice is somehow absent (defensive — a .change kind
            // means a voice existed at detection time).
            let fromClause = currentVoice?.title ?? "their current voice"
            lines.append("- GOAL INTENT (this turn): the user is asking to CHANGE their voice from \(fromClause) to \(targetClause). Do not assume it is committed and do NOT state it is set — they confirm in-app with one tap. Name the trade-off: they have been building \(fromClause) (cite reps / since-date from CONTEXT if present). Then ASK a clarifying question before they decide — why they want to change now and what has shifted (a real moment coming up, the current voice not landing, curiosity). Let them choose; the change is their call, you advise. Weak evidence -> tentative.")
            let switches = recentVoiceChangeCount(adaptationLog: adaptationLog, now: now)
            if switches >= voiceThrashThreshold {
                lines.append("- The user has changed voice \(switches) times in the last week. Note it plainly — suggest giving the current voice a few more reps before switching again. Do not punish-shame; the choice is theirs.")
            }
        }
        return lines
    }

    // MARK: - Goal proposal card (in-chat set / change confirmation)
    //
    // S3 — the human-in-the-loop affordance. After `detectGoalIntent` fires on
    // the user's turn (held on `AskNoumView.pendingGoalIntent`) and the coach
    // replies PROPOSING the set/change, surface a single confirmation card. The
    // card is the ONLY thing that commits a profile write — the model never
    // does (the service is always free text, never parsed for actions). A tap
    // on the card's chip:
    //   • cold start (`.initialSet`)  → `recordGoalSet`  → constructs + saves a
    //     fresh `CoachingProfile` in the chosen voice.
    //   • change (`.change`)          → `recordGoalChange` → notes a
    //     `CoachCourseChange` then saves a mutated profile copy (full switch or
    //     keep-primary-add-secondary blend).
    // Both write FIRST, then dispatch a voice-shaped continuation through
    // `send(_:)` so the chat stays continuous — same ordering as
    // `recordHypothesisAck`.
    //
    // The visibility gate mirrors `shouldShowHypothesisAcknowledgement`'s
    // chat-shape check (last message is a non-pending coach reply) but keys on
    // the presence of a detected intent rather than an opener-lead prefix —
    // the intent already encodes "the user asked to set/change a voice." The
    // view composes this with a `intentPresent` flag (its `@State` holds the
    // intent; clearing it on commit/decline collapses the card).

    /// Should the AskNoumView render the in-chat goal-proposal card? True when
    /// the thread's most-recent message is a non-pending coach reply AND a goal
    /// intent is currently pending (the user asked to set/change a voice this
    /// turn and hasn't yet confirmed or declined). Pure-function mirror of
    /// `shouldShowHypothesisAcknowledgement(messages:)` — same chat-shape check
    /// (so the card never flashes on the user's own turn or on the typing dots),
    /// gated on the detected-intent flag instead of an opener-lead prefix.
    ///
    /// `intentPresent` is the view's `pendingGoalIntent != nil`. Passing it as a
    /// bool keeps this predicate testable without standing up the view's state —
    /// the commit/decline handlers clear the intent, which flips this to false
    /// and collapses the card.
    static func shouldShowGoalProposal(messages: [CoachMessage], intentPresent: Bool) -> Bool {
        guard intentPresent else { return false }
        guard let last = messages.last,
              last.role == .coach,
              !last.isPending,
              !last.text.isEmpty else { return false }
        return true
    }

    // MARK: - Continuation surface arbiter (one per turn)
    //
    // The chat accumulated four post-reply surfaces across rounds 26-30 (goal
    // proposal, hypothesis ack, revised-read verdict, next-move panel), each
    // with its own eligibility predicate but no cross-surface arbiter — so a
    // goal-change turn could stack the commit card AND a "Next move" panel,
    // two competing calls-to-action under one reply. Iteration 6 contract:
    // every substantive coach turn ends in exactly ONE continuation surface.
    //
    // Priority: a pending DECISION is the turn's continuation — the user owes
    // the thread a verdict (or a profile commit) before the coach prescribes
    // the next rep, exactly as a human coach finishes "does that read land?"
    // before assigning homework. The goal proposal outranks the verdict rows
    // because it is the ONLY commit path for a voice change (the model never
    // writes the profile — prompt rule 16); hiding it would dead-end the
    // "tap to confirm" cue the coach just gave. The next-move panel comes
    // last and already collapses drill + follow-up chips into one primary
    // action (launchable drill wins; chips fold behind the overflow menu).

    /// The single continuation surface the chat may render under the latest
    /// coach reply. See the arbiter note above for the priority rationale.
    enum ChatContinuationSurface: Equatable {
        /// In-chat goal set/change confirmation card — the only commit path
        /// for a voice change, so it always wins while an intent is pending.
        case goalProposal
        /// Case-review verdict chips on the working hypothesis (round 26).
        case hypothesisAcknowledgement
        /// Rebuilt-read verdict chips after user pushback (round 30).
        case revisedReadFollowUp
        /// "Next move" panel: launchable drill first, else one follow-up
        /// chip as the primary with the rest behind the overflow menu.
        case nextMove
    }

    /// Resolve which ONE continuation surface this turn earns. Pure so the
    /// no-stacking contract is testable without standing up the view: the
    /// caller passes each surface's own eligibility composite and renders
    /// only the returned case. Nil → no continuation surface at all (e.g.
    /// a greeting turn whose reply earned no follow-up).
    static func continuationSurface(
        goalProposalEligible: Bool,
        hypothesisAckEligible: Bool,
        revisedReadFollowUpEligible: Bool,
        nextMoveAvailable: Bool
    ) -> ChatContinuationSurface? {
        if goalProposalEligible { return .goalProposal }
        if hypothesisAckEligible { return .hypothesisAcknowledgement }
        if revisedReadFollowUpEligible { return .revisedReadFollowUp }
        if nextMoveAvailable { return .nextMove }
        return nil
    }

    // MARK: - Live-call landing line (data-grounded)

    /// One data-grounded landing line for the live call when no case-file
    /// focus has been earned yet: the most recent timed rep's delivery facts
    /// (pace + filler count), stated plainly, with a forward invitation —
    /// "Last rep: 142 WPM, 3 fillers — want to tighten that?". Returns nil
    /// when there is no measured pace (no rep / empty transcript) so a true
    /// cold start never fabricates a read and the landing stays "Tap Talk
    /// to begin".
    ///
    /// Delivery FACTS only — never a substance or quality verdict. One rep is
    /// weak evidence, and weak evidence gets softer language: the line names
    /// what was measured and invites, it does not judge. The filler-count
    /// threshold (4) matches the deterministic chat fallback's
    /// (`AICoachChatService.bodySentence`) so every surface reads the same
    /// rep the same way.
    static func liveCallLandingLine(wordsPerMinute: Int, fillerCount: Int) -> String? {
        guard wordsPerMinute > 0 else { return nil }
        let fillers: String
        switch fillerCount {
        case 0: fillers = "no fillers"
        case 1: fillers = "1 filler"
        default: fillers = "\(fillerCount) fillers"
        }
        // Forward-only invite: name the most useful thread, never a verdict.
        let invite = fillerCount >= 4
            ? "want to tighten that?"
            : "want to pick it up from there?"
        return "Last rep: \(wordsPerMinute) WPM, \(fillers) — \(invite)"
    }

    /// The action a goal-proposal chip commits when tapped. Drives the view's
    /// tap handler (`recordGoalSet` / `recordGoalChange`) and the voice-shaped
    /// continuation dispatched after the durable write.
    enum GoalProposalAction: Equatable {
        /// Cold start — construct + save a fresh profile in this voice.
        case set(SpeakingStyleGoal)
        /// Full switch from the current voice to this one.
        case switchTo(SpeakingStyleGoal)
        /// Keep the current primary; add this voice as the secondary (blend).
        case blend(SpeakingStyleGoal)
        /// Decline — clear the pending intent, write nothing.
        case decline
    }

    /// One chip in the goal-proposal card. Carries the label the user sees, the
    /// durable action the tap commits, and the short voice-shaped user-turn text
    /// dispatched into the thread after the write so the chat reads continuously
    /// (a chip tap lands as a real reply, not a silent mutation). Same shape as
    /// `HypothesisAcknowledgementChip`.
    struct GoalProposalChip: Equatable, Identifiable {
        let id: String
        let label: String
        let action: GoalProposalAction
        let dispatchText: String
    }

    /// The chip catalog for the goal-proposal card, branched on the detected
    /// intent and the user's current voice. Pure so the UI row + the tap
    /// handlers read one source of truth and tests can assert the catalog shape
    /// without rendering.
    ///
    /// Four shapes:
    ///   • cold start WITH a resolved target → "Set <Title>" + "Not now".
    ///   • cold start WITHOUT a target ("help me pick") → one chip per voice
    ///     (the guided pick) + "Not now". Turns the dead-end into a palette.
    ///   • change WITH a resolved target → "Switch to <new>" + "Blend <old> +
    ///     <new>" + "Keep <old>". The blend is the coach's name-the-trade-off
    ///     alternative; keep is the decline.
    ///   • change WITHOUT a target ("change my voice" but none named) → the same
    ///     guided pick as cold start (each voice becomes a switch target),
    ///     excluding the current voice, + "Keep <old>".
    ///
    /// `currentVoice` is the profile's voice (nil on cold start). The dispatched
    /// continuation text is deliberately plain + short so it reads in any voice
    /// register without a per-voice catalog (the coach's NEXT reply re-voices).
    static func goalProposalChips(
        intent: GoalIntent,
        currentVoice: SpeakingStyleGoal?
    ) -> [GoalProposalChip] {
        switch intent.kind {
        case .initialSet:
            if let target = intent.requestedVoice {
                return [
                    GoalProposalChip(
                        id: "set.\(target.rawValue)",
                        label: "Set \(target.title)",
                        action: .set(target),
                        dispatchText: "Set my voice to \(target.title)."
                    ),
                    GoalProposalChip(
                        id: "decline",
                        label: "Not now",
                        action: .decline,
                        dispatchText: "Not now — I'll keep exploring first."
                    ),
                ]
            }
            // No named voice — offer the full palette as a guided pick.
            var chips = SpeakingStyleGoal.allCases.map { voice in
                GoalProposalChip(
                    id: "set.\(voice.rawValue)",
                    label: voice.title,
                    action: .set(voice),
                    dispatchText: "Set my voice to \(voice.title)."
                )
            }
            chips.append(
                GoalProposalChip(
                    id: "decline",
                    label: "Not now",
                    action: .decline,
                    dispatchText: "Not now — I'll keep exploring first."
                )
            )
            return chips

        case .change:
            let oldTitle = currentVoice?.title ?? "my current voice"
            if let target = intent.requestedVoice {
                var chips: [GoalProposalChip] = [
                    GoalProposalChip(
                        id: "switch.\(target.rawValue)",
                        label: "Switch to \(target.title)",
                        action: .switchTo(target),
                        dispatchText: "Switch my voice to \(target.title)."
                    )
                ]
                // Blend only makes sense when the target differs from current.
                if let current = currentVoice, current != target {
                    chips.append(
                        GoalProposalChip(
                            id: "blend.\(target.rawValue)",
                            label: "Blend \(current.title) + \(target.title)",
                            action: .blend(target),
                            dispatchText: "Blend my \(current.title) voice with \(target.title)."
                        )
                    )
                }
                chips.append(
                    GoalProposalChip(
                        id: "keep",
                        label: "Keep \(oldTitle)",
                        action: .decline,
                        dispatchText: "Keep \(oldTitle) for now."
                    )
                )
                return chips
            }
            // Change requested but no voice named — guided pick across the
            // voices that aren't already the current one, plus keep.
            var chips = SpeakingStyleGoal.allCases
                .filter { $0 != currentVoice }
                .map { voice in
                    GoalProposalChip(
                        id: "switch.\(voice.rawValue)",
                        label: voice.title,
                        action: .switchTo(voice),
                        dispatchText: "Switch my voice to \(voice.title)."
                    )
                }
            chips.append(
                GoalProposalChip(
                    id: "keep",
                    label: "Keep \(oldTitle)",
                    action: .decline,
                    dispatchText: "Keep \(oldTitle) for now."
                )
            )
            return chips
        }
    }

    // MARK: - Hypothesis acknowledgement chips (post-case-review reply)
    //
    // Round 26 — the case-parity adaptation move. After the coach replies
    // to an `interventionReviewOpener` (dispatched from either the
    // summary card or the AskNoumView empty-state chip), surface a single
    // row of one-tap acknowledgement chips so the user can record their
    // verdict on the working hypothesis without typing a sentence. The
    // ack lands in durable `CoachMemory.hypothesisAcknowledgement` and
    // feeds back into the next user-context block so the model knows
    // whether to reinforce, probe, or adapt.
    //
    // Why chips instead of a free-text follow-up:
    //   • Friction. Three taps cover the entire "confirmed / uncertain /
    //     rejected" space; free text would re-ask "what do you think?"
    //     after the coach already asked it.
    //   • Durable signal. A typed reply becomes one more conversational
    //     turn the model has to interpret. A discrete enum lands in
    //     case-file storage and survives across sessions / rebuilds.
    //   • Coach parity. A human coach asks "does that sound right?" and
    //     marks the answer; we owe the same structured record.
    //
    // Pure-helper contract: the predicate + chip catalog are testable
    // without standing up `AskNoumStore` or `CoachMemoryStore`. The UI
    // surface reads both at render time.

    /// Lead prefix on every `interventionReviewOpener` — used by the
    /// hypothesis ack-chip predicate to detect that the most-recent user
    /// turn was a case-review dispatch (from the summary card or the
    /// AskNoum chip) rather than an organic question. Pinned as a
    /// constant so the predicate and the opener stay in lockstep across
    /// future copy edits.
    static let interventionReviewOpenerLead = "Time to review the active case:"

    /// Display chip for the hypothesis acknowledgement row. Carries the
    /// label the user sees + the confidence the tap records + the short
    /// user-turn text dispatched into the thread so the chat surface
    /// stays continuous (a chip tap reads as a real reply, not a
    /// silent background mutation).
    struct HypothesisAcknowledgementChip: Equatable {
        let confidence: CoachHypothesisConfidence
        let label: String
        let dispatchText: String
    }

    /// Should the AskNoumView render the hypothesis ack-chip row? True
    /// when the thread's most-recent message is a non-pending coach
    /// reply AND the user turn that triggered it begins with the
    /// `interventionReviewOpener` lead. Pure function of message
    /// sequence so the UI eligibility check matches what the tests
    /// pin.
    ///
    /// Why both conditions: we only want the chip row after the coach
    /// has actually answered the case-review opener — not on the user
    /// turn (which is the opener itself) and not while the reply is
    /// pending (premature acknowledgement). A user turn after the
    /// coach reply means the conversation has moved on; the chip row
    /// stops rendering.
    static func shouldShowHypothesisAcknowledgement(messages: [CoachMessage]) -> Bool {
        guard let last = messages.last,
              last.role == .coach,
              !last.isPending,
              !last.text.isEmpty else { return false }
        // Find the user turn that triggered this coach reply (the last
        // user turn before `last`). Search backwards from the
        // second-to-last message.
        let prior = messages.dropLast()
        guard let userTurn = prior.last(where: { $0.role == .user }) else { return false }
        return userTurn.text.hasPrefix(interventionReviewOpenerLead)
    }

    /// Three voice-shaped acknowledgement chips — confirmed / uncertain
    /// / rejected. The chip set is fixed at three so the UI row reads as
    /// a complete verdict palette; the labels shift per voice so the
    /// authoritative coach's chip reads as a verdict ("Yes — that's the
    /// read") while the warm coach's reads as agreement ("That fits how
    /// I see it"). Same three branches under the hood — the durable
    /// `CoachHypothesisConfidence` value is voice-independent.
    static func hypothesisAcknowledgementChips(for voice: SpeakingStyleGoal?) -> [HypothesisAcknowledgementChip] {
        switch voice {
        case .authoritative:
            return [
                .init(confidence: .confirmed, label: "Yes — that's the read", dispatchText: "Yes — that's the read."),
                .init(confidence: .uncertain, label: "Not sure yet", dispatchText: "Not sure yet."),
                .init(confidence: .rejected, label: "Off — adapt the read", dispatchText: "That's off — adapt the read."),
            ]
        case .warm:
            return [
                .init(confidence: .confirmed, label: "That fits how I see it", dispatchText: "That fits how I see it."),
                .init(confidence: .uncertain, label: "I'm still figuring it out", dispatchText: "I'm still figuring it out."),
                .init(confidence: .rejected, label: "Doesn't quite match", dispatchText: "That doesn't quite match what I notice."),
            ]
        case .concise:
            return [
                .init(confidence: .confirmed, label: "Matches", dispatchText: "Matches."),
                .init(confidence: .uncertain, label: "Unsure", dispatchText: "Unsure."),
                .init(confidence: .rejected, label: "Adapt", dispatchText: "Adapt."),
            ]
        case .persuasive:
            return [
                .init(confidence: .confirmed, label: "Yes — make the case", dispatchText: "Yes — make the case."),
                .init(confidence: .uncertain, label: "I'd like more evidence", dispatchText: "I'd like more evidence before agreeing."),
                .init(confidence: .rejected, label: "I'd argue different", dispatchText: "I'd argue a different read."),
            ]
        case .executive:
            return [
                .init(confidence: .confirmed, label: "Confirmed", dispatchText: "Confirmed."),
                .init(confidence: .uncertain, label: "TBD", dispatchText: "TBD — need another data point."),
                .init(confidence: .rejected, label: "Reject — adapt", dispatchText: "Reject — adapt the read."),
            ]
        case .storytelling:
            return [
                .init(confidence: .confirmed, label: "That's the arc I see", dispatchText: "That's the arc I see."),
                .init(confidence: .uncertain, label: "I'm still in the middle", dispatchText: "I'm still in the middle of figuring it out."),
                .init(confidence: .rejected, label: "Different chapter", dispatchText: "I'd tell a different chapter here."),
            ]
        case .none:
            return [
                .init(confidence: .confirmed, label: "That matches what I see", dispatchText: "That matches what I see."),
                .init(confidence: .uncertain, label: "Not sure yet", dispatchText: "Not sure yet."),
                .init(confidence: .rejected, label: "Doesn't match", dispatchText: "That doesn't match what I notice."),
            ]
        }
    }

    // MARK: - Revised-read follow-up chips (post-rebuild reply)
    //
    // Round 30 — the chat-surface complement to round 29's `revisedReadOpener`.
    // After the user dispatches a revised-read seed (the post-rep summary's
    // `TalkToNoumCTACard` routes through `talkToNoumOpener` and lands the
    // round-29 `revisedReadOpenerLead` clause as the user turn) and the coach
    // replies with their take on the rebuilt read, surface a single row of
    // one-tap follow-up chips so the user can record where they land on the
    // rebuild without typing a sentence. Three branches —
    //
    //   • stick with the new read   (durable verdict: `.confirmed`)
    //   • add to the new read       (durable verdict: `.uncertain`)
    //   • push back again           (durable verdict: `.rejected`)
    //
    // — land on the same `CoachHypothesisAcknowledgement` storage the
    // hypothesis-ack chips write to. The rebuild rewrote the working
    // hypothesis, so the previous ack snapshot no longer applies (per
    // `appliesTo`); this row prompts the user to land a verdict on the NEW
    // hypothesis without re-routing through a case-review opener. The
    // adaptation lineage stays continuous: a `.rejected` reply on the
    // rebuild becomes the next `CoachCourseChange` entry's pushback marker;
    // a `.confirmed` reply locks the rebuild in without forcing another
    // `interventionReviewPromptCard` cadence to fire.
    //
    // Mirror of `shouldShowHypothesisAcknowledgement` /
    // `hypothesisAcknowledgementChips(for:)` (round 26):
    //   • Same predicate shape — last message is a non-pending coach reply,
    //     prior user turn begins with the opener lead. Only the lead
    //     constant differs (`revisedReadOpenerLead` instead of
    //     `interventionReviewOpenerLead`).
    //   • Same chip type — `HypothesisAcknowledgementChip` carries the
    //     verdict + label + dispatched user-turn text.
    //   • Same record path on the view side —
    //     `recordHypothesisAck(_:)` writes to
    //     `CoachMemoryStore.noteHypothesisAcknowledgement(_:)`. One storage
    //     home for both surfaces.
    //
    // The two predicates are mutually exclusive at the chat-shape level —
    // a single user turn can only begin with one opener lead — so the two
    // chip rows never render side-by-side. The UI layer doesn't need a
    // tiebreaker.

    /// Should the AskNoumView render the revised-read follow-up chip row?
    /// True when the thread's most-recent message is a non-pending coach
    /// reply AND the user turn that triggered it begins with EITHER the
    /// `revisedReadOpenerLead` (round 29 first-cycle seed) or the
    /// `revisedReadOpenerSecondCycleLead` (round 35 second-cycle seed)
    /// prefix. Pure-function mirror of
    /// `shouldShowHypothesisAcknowledgement(messages:)` — same shape,
    /// two valid lead constants instead of one.
    ///
    /// Why both leads match: round 35 split the chat seed into first-cycle
    /// and second-cycle composers (mirror of round 34's `RevisedReadCard`
    /// split). The follow-up chip row owns the rebuild-verdict surface on
    /// both cycles — a user who pushed back twice deserves the same
    /// one-tap stick / refine / push-back row as a user who pushed back
    /// once. The two leads are mutually exclusive at the chat-shape level
    /// (a single user turn can only start with one) so the predicate
    /// still names a single canonical surface.
    ///
    /// Why both message-shape conditions: we only want the chip row after
    /// the coach has actually answered the rebuild seed — not on the user
    /// turn (which is the seed itself) and not while the reply is pending
    /// (premature follow-up). A later user turn means the conversation
    /// has moved on; the chip row stops rendering.
    static func shouldShowRevisedReadFollowUp(messages: [CoachMessage]) -> Bool {
        guard let last = messages.last,
              last.role == .coach,
              !last.isPending,
              !last.text.isEmpty else { return false }
        let prior = messages.dropLast()
        guard let userTurn = prior.last(where: { $0.role == .user }) else { return false }
        return userTurn.text.hasPrefix(revisedReadOpenerLead)
            || userTurn.text.hasPrefix(revisedReadOpenerSecondCycleLead)
    }

    /// Three voice-shaped follow-up chips — confirmed / uncertain /
    /// rejected — for the rep where the user just received a coach reply
    /// to a revised-read opener. The user can stick with the rebuild,
    /// refine it, or push back again. The chip set is fixed at three so
    /// the row reads as a complete verdict palette; labels shift per
    /// voice so the authoritative coach's read as decisions ("Lock the
    /// new read in") while the warm coach's read as collaboration ("This
    /// feels right — let's stay here") — same three durable
    /// `CoachHypothesisConfidence` branches under the hood.
    static func revisedReadFollowUpChips(for voice: SpeakingStyleGoal?) -> [HypothesisAcknowledgementChip] {
        switch voice {
        case .authoritative:
            return [
                .init(confidence: .confirmed, label: "Lock the new read in", dispatchText: "Lock the new read in."),
                .init(confidence: .uncertain, label: "Here's what I'd add", dispatchText: "Here's what I'd add to the new read."),
                .init(confidence: .rejected, label: "Try a third angle", dispatchText: "Try a third angle."),
            ]
        case .warm:
            return [
                .init(confidence: .confirmed, label: "This one fits", dispatchText: "This one fits — I'd stay with it."),
                .init(confidence: .uncertain, label: "I'd add to it", dispatchText: "I'd add something to it."),
                .init(confidence: .rejected, label: "Still not quite there", dispatchText: "Still not quite there — try another angle."),
            ]
        case .concise:
            return [
                .init(confidence: .confirmed, label: "Stick", dispatchText: "Stick with it."),
                .init(confidence: .uncertain, label: "Add", dispatchText: "Add this."),
                .init(confidence: .rejected, label: "Reframe", dispatchText: "Reframe."),
            ]
        case .persuasive:
            return [
                .init(confidence: .confirmed, label: "I'll make this case", dispatchText: "I'll make this case."),
                .init(confidence: .uncertain, label: "I'd refine the claim", dispatchText: "I'd refine the claim."),
                .init(confidence: .rejected, label: "Argue a third angle", dispatchText: "Argue a third angle."),
            ]
        case .executive:
            return [
                .init(confidence: .confirmed, label: "Approve the rebuild", dispatchText: "Approve the rebuild."),
                .init(confidence: .uncertain, label: "Amend — one addition", dispatchText: "Amend — one addition."),
                .init(confidence: .rejected, label: "Reject — try again", dispatchText: "Reject — try a third read."),
            ]
        case .storytelling:
            return [
                .init(confidence: .confirmed, label: "That's the chapter", dispatchText: "That's the chapter."),
                .init(confidence: .uncertain, label: "Add a scene", dispatchText: "I'd add a scene."),
                .init(confidence: .rejected, label: "A different chapter", dispatchText: "A different chapter."),
            ]
        case .none:
            return [
                .init(confidence: .confirmed, label: "Stick with the new read", dispatchText: "Stick with the new read."),
                .init(confidence: .uncertain, label: "Here's what I'd add", dispatchText: "Here's what I'd add."),
                .init(confidence: .rejected, label: "Try a different read", dispatchText: "Try a different read."),
            ]
        }
    }

    // MARK: - Fresh revised-read context (carries the rebuild into every chat turn)
    //
    // Round 31 — the context-block complement to rounds 28/29/30. Round 28
    // surfaced `RevisedReadCard` on the post-rep summary when the user's
    // pushback was just folded into a rebuilt working hypothesis. Round 29
    // dispatched a case-anchored seed into Ask Noum so the chat thread
    // opened with the user's pushback named. Round 30 collected the user's
    // verdict on the rebuild via a one-tap chip row.
    //
    // The chat-coach user-context block — the payload the model reads on
    // every reply — has been carrying the generic
    // "Last course change: <reason> (<evidenceBasis>)" line from
    // `interventionCycleLines` all along. That line is honest but flat:
    // the model has to parse the `reason` text to know this was a
    // user-pushback rebuild AND that the rebuild is still fresh (i.e.,
    // no followed rep has rewritten memory since the pushback landed).
    // A clearer, predicate-gated line means the model can speak to the
    // rebuild state directly across the whole window between rebuild
    // and the next followed rep — not only on the round-29 seed turn.
    //
    // Both predicates already live on `CoachCourseChange` as pure-function
    // properties (`documentsUserPushback`, `isFresh(comparedTo:)`). The
    // `SummaryView.freshRevisedReadChange` private property gates
    // `RevisedReadCard` on the same pair. Round 31 lifts that pair into a
    // shared pure helper on `CoachContextBuilder` so the eligibility
    // contract is one call site away from the chat context block, the
    // summary card, the round-29 opener, and the round-30 follow-up row.

    /// Returns the latest `CoachCourseChange` iff it both documents a
    /// user-tapped rejection of the prior hypothesis (a pushback rebuild)
    /// AND was appended on the same rebuild that produced the current
    /// `CoachMemory`. Pure-function mirror of
    /// `SummaryView.freshRevisedReadChange` — same shape, lifted so the
    /// chat-coach context block can read the same gate without
    /// duplicating the predicate.
    static func freshRevisedReadChange(in memory: CoachMemory) -> CoachCourseChange? {
        guard let latest = memory.adaptationLog?.last,
              latest.documentsUserPushback,
              latest.isFresh(comparedTo: memory.updatedAt) else { return nil }
        return latest
    }

    /// Context-block lines for a fresh revised-read rebuild. Surfaced in
    /// `interventionCycleLines` in place of the generic "Last course
    /// change" line whenever `freshRevisedReadChange(in:)` returns
    /// non-nil AND `memory.workingHypothesis` is non-empty.
    ///
    /// Two lines:
    ///   1. The case-state line — names the pushback in the user's own
    ///      verdict (echoes `RevisedReadCard.headlineCopy` phrasing so
    ///      the cross-surface read is consistent) and carries the
    ///      evidence basis the engine documented on the change.
    ///   2. The coach-move line — tells the model to speak to the
    ///      rebuild as the operating read, not the original; leaves
    ///      room for the user to settle into it or push back again
    ///      before strengthening the new hypothesis.
    ///
    /// When the predicate does not fire, returns an empty array so the
    /// caller falls through to the generic "Last course change" line.
    /// When the predicate fires but `workingHypothesis` is empty, also
    /// returns an empty array — the lines would name a rebuild against
    /// a missing hypothesis and read incoherently to the model.
    static func freshRevisedReadContextLines(memory: CoachMemory) -> [String] {
        guard let change = freshRevisedReadChange(in: memory) else { return [] }
        guard let hypothesis = memory.workingHypothesis?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !hypothesis.isEmpty else { return [] }
        let basis = change.evidenceBasis.trimmingCharacters(in: .whitespacesAndNewlines)
        let basisTail = basis.isEmpty ? "" : " (\(basis))"
        // Round-33: when the rebuild is itself a second-cycle pushback (the
        // engine wrote the `secondCyclePushbackMarker` tag because the prior
        // adaptation entry was also a user pushback), surface the second
        // cycle in BOTH lines so the model recognises a repeated adapt
        // pattern instead of treating it as a first-time pushback. The
        // round-32 in-context "second pushback" tag only fires while the
        // chip-row ack is carried in memory; this branch preserves the
        // signal AFTER the engine drops that ack on the next rebuild.
        if change.documentsSecondCyclePushback {
            return [
                "- Case file shifted again: the user has now flagged the prior read as off across two consecutive rebuild cycles; the working hypothesis above is the new read\(basisTail).",
                "- Coach move on the second rebuild cycle: do not re-prescribe the same intervention unchanged. Acknowledge the repeated adapt explicitly, ask one focused question that would discriminate between this new read and the two it just replaced, and avoid strengthening either prior read.",
            ]
        }
        return [
            "- Case file just shifted: the user flagged the prior read as off; the working hypothesis above is the rebuilt one\(basisTail).",
            "- Coach move on the rebuild: speak to it as the live operating read, not the original. Leave room for the user to settle into the rebuild or push back again before strengthening it.",
        ]
    }

    // MARK: - Rebuild-verdict context (the round-30 chip-row ack, reflected into context)
    //
    // Round 32 — the context-block complement to round 30. Round 28 surfaced
    // the rebuild on the post-rep summary; round 29 named the user's pushback
    // in the chat seed; round 30 collected the user's verdict on the rebuild
    // via a one-tap chip row; round 31 carried the rebuild context into the
    // chat-coach user-context block on every reply through the next followed
    // rep — UNTIL the user taps a verdict chip.
    //
    // The round-31 lines gate on `change.isFresh(comparedTo: memory.updatedAt)`,
    // which has a one-second tolerance. The round-30 chip row writes the
    // verdict via `CoachMemoryStore.noteHypothesisAcknowledgement(_:)`, which
    // bumps `memory.updatedAt = now`. The `isFresh` window slams shut, the
    // round-31 lines stop firing, and the model loses the rebuild context the
    // moment the user lodges a verdict on it — exactly when the model most
    // needs to know the rebuild has been INHABITED, not just delivered.
    //
    // Round 32 detects this state with a sibling predicate that does NOT
    // depend on `isFresh`. Instead it pairs the latest pushback rebuild with
    // a user acknowledgement whose snapshot still applies AND whose
    // `acknowledgedAt` post-dates the rebuild's `changedAt`. The pair means:
    // "the user has lodged a verdict on the rebuilt read, specifically."
    //
    // The two paths are mutually exclusive at the memory level: the round-30
    // ack bump that fires round 32 also closes round 31's `isFresh` window.
    // The `interventionCycleLines` branch reads round 32 first, falls
    // through to round 31, falls through to the generic line — so the chat
    // context carries one canonical course-change line at any time.

    /// Pure-function pair: the latest course change + the user's
    /// acknowledgement on the rebuilt read, returned together iff:
    ///   1. The latest adaptation entry documents a user-pushback rebuild
    ///      (`documentsUserPushback`).
    ///   2. The current memory carries a `hypothesisAcknowledgement` whose
    ///      `acknowledgedAt` is at or after the change's `changedAt`
    ///      (ack was lodged after the rebuild was folded in).
    ///   3. The ack's `hypothesisSnapshot` still matches the current
    ///      `workingHypothesis` (`appliesTo` — same case-spine contract as
    ///      `coachCaseFormulationLines` round 26).
    ///
    /// Returns nil otherwise. Same shape as `freshRevisedReadChange(in:)`
    /// (pure read of memory fields, no UI dependency), so the chat context,
    /// the post-rep summary, and any future surface can read the same
    /// predicate without duplicating the gate.
    static func rebuildVerdictPair(
        in memory: CoachMemory
    ) -> (change: CoachCourseChange, ack: CoachHypothesisAcknowledgement)? {
        guard let change = memory.adaptationLog?.last,
              change.documentsUserPushback,
              let ack = memory.hypothesisAcknowledgement,
              ack.acknowledgedAt >= change.changedAt,
              ack.appliesTo(currentHypothesis: memory.workingHypothesis) else { return nil }
        return (change, ack)
    }

    /// Context-block lines for a rebuilt read that has been acknowledged by
    /// the user. Surfaced in `interventionCycleLines` AHEAD of
    /// `freshRevisedReadContextLines` whenever `rebuildVerdictPair(in:)`
    /// returns a pair AND `memory.workingHypothesis` is non-empty.
    ///
    /// Two lines:
    ///   1. Case-state line — names the rebuild AND the user's verdict on
    ///      it in one sentence, with the evidence basis carried in
    ///      parentheses. Echoes "the working hypothesis above" so the
    ///      anchor reads the same as round-31's case-state line — the
    ///      model sees one cross-line referent across the rebuild lifecycle.
    ///   2. Coach-move line — `confidence`-specific instruction from
    ///      `CoachHypothesisConfidence.rebuildVerdictInstruction`. The
    ///      `.confirmed` branch tells the model to treat the rebuild as
    ///      the accepted read; the `.uncertain` branch tells it to ask a
    ///      focused question; the `.rejected` branch tells it the user
    ///      pushed back twice and to propose a third angle without
    ///      retrying the same rebuild.
    ///
    /// Returns `[]` when the predicate does not fire, OR when the working
    /// hypothesis is empty/whitespace-only (the lines reference "the working
    /// hypothesis above" — pointing at nothing would read incoherently).
    static func rebuildVerdictContextLines(memory: CoachMemory) -> [String] {
        guard let pair = rebuildVerdictPair(in: memory) else { return [] }
        guard let hypothesis = memory.workingHypothesis?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !hypothesis.isEmpty else { return [] }
        let basis = pair.change.evidenceBasis.trimmingCharacters(in: .whitespacesAndNewlines)
        let basisTail = basis.isEmpty ? "" : " (\(basis))"
        return [
            "- Case file rebuild verdict: the user lodged a \(pair.ack.confidence.rebuildVerdictLabel) on the rebuilt working hypothesis above\(basisTail).",
            "- Coach move on the rebuild verdict: \(pair.ack.confidence.rebuildVerdictInstruction)",
        ]
    }

    // MARK: - Case-anchored amplification (round 37 — future moves #10)
    //
    // Round 37 — the active-intervention complement to rounds 30–36. When the
    // user has lodged a `.confirmed` verdict on a rebuilt working hypothesis
    // (the rebuild was itself user-driven via a prior pushback rebuild) the
    // chat coach should treat follow-on evidence on the carrying active
    // intervention as case-anchored, not exploratory: the user has now BOTH
    // pushed back on the original read AND confirmed the rebuilt read, so the
    // case file's hypothesis carries the user's own ratification, not just the
    // engine's inference.
    //
    // Pure additive surface — the active intervention's persisted fields are
    // untouched (no `reviewStatus` lift, no schema bump, no migration). The
    // amplification is signalled to the model via ONE additional context line
    // in `interventionCycleLines`, which the chat coach reads on every reply.
    // Restraint pin: the line is the LIGHTEST possible surface that signals
    // case anchoring — it does not duplicate the round-32 rebuild-verdict
    // block (which fires on every confirmed-rebuild ack regardless of cycle
    // history) and it does not duplicate the round-26 hypothesis-ack block
    // (which fires on any ack confidence). The line specifically reads as
    // "the active intervention is case-anchored" — the new signal round 37
    // adds to the model's awareness.
    //
    // Cross-surface contract: the amplification predicate is a STRICTER
    // subset of the round-32 `rebuildVerdictPair` predicate on the
    // `.confirmed` branch — round 37 implies round 32, but round 32 does not
    // imply round 37 (round 32 fires on uncertain/rejected acks too, and on
    // acks lodged outside the recency window). The two lines layer cleanly:
    // round 32 names the rebuild-verdict event; round 37 names the durable
    // case-anchoring state that the verdict establishes for the carrying
    // intervention. Both can fire on the same reply.

    /// Recency window for the case-anchored amplification predicate. The
    /// user's confirmation must have been lodged within this many days for
    /// the active intervention to be treated as case-anchored. Beyond this
    /// window the ack is durable in memory but the carrying intervention may
    /// have aged enough that fresh follow-on evidence belongs to a different
    /// case state — the chat coach should fall back to the round-32
    /// rebuild-verdict line (which carries no recency gate) rather than
    /// double-emit an amplification line on stale confirmation.
    ///
    /// Tuned to the same horizon as the post-rep follow-up window so the
    /// signal stays live across roughly two weeks of practice before
    /// expiring. Pure constant, locked by a brand-voice-style test for
    /// regression protection.
    static let caseAnchoredAmplificationRecencyDays: Int = 14

    /// Pure predicate: returns true iff the carrying active intervention's
    /// follow-on evidence should be treated as case-anchored, i.e. the user
    /// has both pushed back on the original read AND confirmed the rebuilt
    /// read within the recency window. Five gates, ALL required:
    ///
    ///   1. `memory.hypothesisAcknowledgement` carries a `.confirmed`
    ///      confidence (the user ratified the rebuilt read).
    ///   2. The ack `appliesTo(currentHypothesis: memory.workingHypothesis)`
    ///      — the rebuilt read the user ratified is still the operating
    ///      hypothesis (a later memory rebuild that rewrote the read drops
    ///      the predicate; the user's confirmation belongs to a hypothesis
    ///      that no longer exists).
    ///   3. The ack was lodged within `caseAnchoredAmplificationRecencyDays`
    ///      of `now` (defensive — stale confirmation does not anchor a
    ///      current case state).
    ///   4. The latest `adaptationLog` entry `documentsUserPushback` — the
    ///      rebuild that produced the carrying hypothesis was itself
    ///      user-driven, not an engine-only lever shift. (An engine-only
    ///      shift followed by a confirmation does not satisfy "the user
    ///      both pushed back and confirmed".)
    ///   5. The ack's `acknowledgedAt` is at or after the change's
    ///      `changedAt` (same ordering contract as `rebuildVerdictPair` —
    ///      a stale ack from before the rebuild does not ratify it).
    ///
    /// All five gates are pure reads on memory fields the engine already
    /// writes; no new persisted state, no schema bump, no migration. Memories
    /// persisted before round 37 read `false` automatically — the predicate
    /// is dark until both signals (pushback + confirmation) coexist.
    static func caseAnchoredAmplificationApplies(
        in memory: CoachMemory,
        now: Date
    ) -> Bool {
        guard let ack = memory.hypothesisAcknowledgement,
              ack.confidence == .confirmed,
              ack.appliesTo(currentHypothesis: memory.workingHypothesis) else { return false }
        let recencyInterval = TimeInterval(caseAnchoredAmplificationRecencyDays * 24 * 60 * 60)
        guard now.timeIntervalSince(ack.acknowledgedAt) <= recencyInterval else { return false }
        guard let lastChange = memory.adaptationLog?.last,
              lastChange.documentsUserPushback,
              ack.acknowledgedAt >= lastChange.changedAt else { return false }
        return true
    }

    /// Returns ONE additional context line when the case-anchored
    /// amplification predicate fires AND an active intervention is being
    /// surfaced. Returns `nil` otherwise so the caller can skip emitting.
    ///
    /// Read by `interventionCycleLines` after the active-intervention block.
    /// The line is intentionally short — one calm sentence that names the
    /// case-anchored state AND tells the model to treat follow-on evidence
    /// as case-anchored rather than exploratory. Brand-voice rules: no
    /// exclamation, no "Let's", no "we", no "sorry", no hype.
    ///
    /// The line does NOT duplicate the round-32 rebuild-verdict block's
    /// content (that block names the rebuild-verdict event); round 37 names
    /// the durable case-anchoring state the verdict establishes for the
    /// carrying intervention's follow-on evidence — a related but distinct
    /// signal the model can act on independently.
    static func caseAnchoredAmplificationContextLine(
        memory: CoachMemory,
        now: Date
    ) -> String? {
        guard caseAnchoredAmplificationApplies(in: memory, now: now) else { return nil }
        guard memory.activeIntervention != nil else { return nil }
        return "- Case-anchored amplification: the user has both pushed back on the original read AND confirmed the rebuilt working hypothesis above; treat follow-on evidence on the active intervention as case-anchored, not exploratory. Speak with conviction on the carrying read; do not re-open the original."
    }

    // MARK: - Intervention under repeated pushback (round 38 — round-37 mirror on the .rejected branch)
    //
    // Round 38 — the dampening complement to round 37's case-anchored
    // amplification. When the user has BOTH pushed back on the original read
    // AND lodged a `.rejected` verdict on the rebuilt read within the recency
    // window, the active intervention is under repeated pushback. The chat
    // coach should DAMPEN — slow down on follow-on reads, ask one focused
    // question that would discriminate the next read from the two the user
    // has rejected, and not re-prescribe the same intervention unchanged.
    //
    // Round 37 covered the `.confirmed` branch (user ratified the rebuild →
    // case-anchored amplification, speak with conviction). Round 38 closes
    // the symmetric gap on the `.rejected` branch (user rejected the rebuild
    // too → intervention is under repeated pushback, slow down). The
    // `.uncertain` branch deliberately has no dedicated dampening or
    // amplification line: the round-32 rebuild-verdict block already carries
    // the .uncertain instruction ("ask one focused question that would
    // discriminate this read from the alternatives") and the intervention is
    // neither anchored nor under pushback — it is awaiting evidence.
    //
    // Round 38 is the SAME shape as round 37: pure additive surface, the
    // active intervention's persisted fields are untouched (no `reviewStatus`
    // lift, no schema bump, no migration). The dampening is signalled to the
    // model via ONE additional context line in `interventionCycleLines`,
    // which the chat coach reads on every reply.
    //
    // Mutual exclusion with round 37: the two predicates gate on opposite
    // `confidence` values (`.confirmed` for round 37, `.rejected` for round
    // 38). Only one can fire per memory state. They cannot both surface a
    // line on the same chat reply.
    //
    // Cross-surface contract with the round-32 `rebuildVerdictContextLines`:
    // round 38 is a STRICTER subset of round 32 on the `.rejected` branch —
    // round 38 implies round 32, but round 32 does not imply round 38 (round
    // 32 fires on confirmed/uncertain acks and on acks lodged outside the
    // recency window). The two lines layer cleanly: round 32 names the
    // rebuild-verdict event (the user pushed back twice); round 38 names the
    // durable under-repeated-pushback state for the carrying intervention.
    // Both can fire on the same reply.
    //
    // Cross-surface contract with the round-33 `freshRevisedReadContextLines`
    // second-cycle branch: round 33 fires on the NEXT memory rebuild after
    // the user pushed back twice (the engine has folded the second-cycle
    // pushback into the adaptation log; the chip-row ack is dropped). Round
    // 38 fires BEFORE the engine has rebuilt — the ack is still carried and
    // the chat coach reads the dampening signal directly. The two are
    // sequential on the timeline: round 38 (chip-row ack carried) → engine
    // rebuild → round 33 (adaptation log marker, ack dropped). Both surfaces
    // tell the model the intervention is under repeated pushback; round 38
    // does it on the immediate chat reply, round 33 does it after the next
    // rebuild folds the signal in.

    /// Recency window for the round-38 under-repeated-pushback predicate.
    /// The user's rejection of the rebuilt read must have been lodged within
    /// this many days for the active intervention to be treated as under
    /// repeated pushback. Beyond this window the ack is durable in memory
    /// but the case may have aged enough that today's follow-on evidence is
    /// no longer dampened by an old rejection — the chat coach should fall
    /// back to the round-32 rebuild-verdict line (which carries no recency
    /// gate) rather than double-emit a dampening line on a stale rejection.
    ///
    /// Pinned to the same horizon as round 37's amplification recency
    /// (`caseAnchoredAmplificationRecencyDays`) so the case-anchoring and
    /// the under-pushback windows close on the same day after the verdict
    /// — coaching parity stays symmetric on the two branches. Pure
    /// constant, locked by a brand-voice-style test for regression
    /// protection and by an equality test against the round-37 constant.
    static let repeatedPushbackRecencyDays: Int = 14

    /// Pure predicate: returns true iff the carrying active intervention's
    /// follow-on evidence should be dampened, i.e. the user has both pushed
    /// back on the original read AND lodged a `.rejected` verdict on the
    /// rebuilt read within the recency window. Five gates, ALL required —
    /// the exact mirror of `caseAnchoredAmplificationApplies` on the
    /// `.rejected` branch:
    ///
    ///   1. `memory.hypothesisAcknowledgement` carries a `.rejected`
    ///      confidence (the user pushed back on the rebuilt read too).
    ///   2. The ack `appliesTo(currentHypothesis: memory.workingHypothesis)`
    ///      — the rebuilt read the user rejected is still the operating
    ///      hypothesis (a later memory rebuild that rewrote the read drops
    ///      the predicate; the user's rejection belongs to a hypothesis
    ///      that no longer exists).
    ///   3. The ack was lodged within `repeatedPushbackRecencyDays` of
    ///      `now` (defensive — stale rejection does not dampen a current
    ///      case state).
    ///   4. The latest `adaptationLog` entry `documentsUserPushback` — the
    ///      rebuild that produced the carrying hypothesis was itself
    ///      user-driven, not an engine-only lever shift. (An engine-only
    ///      shift followed by a rejection does not satisfy "the user
    ///      pushed back on both the original AND the rebuilt read".)
    ///   5. The ack's `acknowledgedAt` is at or after the change's
    ///      `changedAt` (same ordering contract as round 37 and
    ///      `rebuildVerdictPair` — a stale ack from before the rebuild
    ///      does not register as a rejection of it).
    ///
    /// All five gates are pure reads on memory fields the engine already
    /// writes; no new persisted state, no schema bump, no migration.
    /// Memories persisted before round 38 read `false` automatically — the
    /// predicate is dark until both signals (pushback rebuild + rejection)
    /// coexist.
    ///
    /// Mutual exclusion with `caseAnchoredAmplificationApplies`: the two
    /// predicates gate on `ack.confidence == .confirmed` and
    /// `ack.confidence == .rejected` respectively. The two cannot both
    /// return `true` for the same memory state — `confidence` is a single
    /// enum case at any point in time.
    static func interventionUnderRepeatedPushbackApplies(
        in memory: CoachMemory,
        now: Date
    ) -> Bool {
        guard let ack = memory.hypothesisAcknowledgement,
              ack.confidence == .rejected,
              ack.appliesTo(currentHypothesis: memory.workingHypothesis) else { return false }
        let recencyInterval = TimeInterval(repeatedPushbackRecencyDays * 24 * 60 * 60)
        guard now.timeIntervalSince(ack.acknowledgedAt) <= recencyInterval else { return false }
        guard let lastChange = memory.adaptationLog?.last,
              lastChange.documentsUserPushback,
              ack.acknowledgedAt >= lastChange.changedAt else { return false }
        return true
    }

    /// Returns ONE additional context line when the under-repeated-pushback
    /// predicate fires AND an active intervention is being surfaced.
    /// Returns `nil` otherwise so the caller can skip emitting.
    ///
    /// Read by `interventionCycleLines` after the active-intervention block,
    /// at the same call site as round 37's amplification line. The two
    /// surfaces are mutually exclusive at the predicate level (confirmed
    /// XOR rejected ack), so the worst-case line count stays the same as
    /// it was after round 37 landed.
    ///
    /// The line is intentionally short — one calm sentence that names the
    /// repeated-pushback state AND tells the model to slow down, ask a
    /// discriminating question, and avoid re-prescribing the same
    /// intervention. Brand-voice rules: no exclamation, no "Let's", no
    /// "we", no "sorry", no hype, no shame framing on the rejection (the
    /// user steering the coach is a healthy signal, not a failure state).
    ///
    /// The line does NOT duplicate the round-32 rebuild-verdict block's
    /// content (that block names the rebuild-verdict event); round 38
    /// names the durable under-repeated-pushback state the rejection
    /// establishes for the carrying intervention's follow-on evidence —
    /// a related but distinct signal the model can act on independently.
    static func interventionUnderRepeatedPushbackContextLine(
        memory: CoachMemory,
        now: Date
    ) -> String? {
        guard interventionUnderRepeatedPushbackApplies(in: memory, now: now) else { return nil }
        guard memory.activeIntervention != nil else { return nil }
        return "- Intervention under repeated pushback: the user has both pushed back on the original read AND lodged a no-fit verdict on the rebuilt working hypothesis above; treat the active intervention as under repeated pushback. Slow down on follow-on reads, ask one focused question that would discriminate the next read from the two the user has rejected, and do not re-prescribe the same intervention unchanged."
    }

    // MARK: - Case-anchored continuation through engine refinement (round 39 — durability for round 37)
    //
    // Round 39 — the durability complement to round 37's case-anchored
    // amplification. Round 37 fires only while the LATEST adaptation entry
    // documents a user pushback (the rebuild that produced the carrying
    // hypothesis was user-driven). The first subsequent engine-only
    // refinement — a quiet lever adjustment the engine writes without the
    // user pushing back — drops the latest-entry predicate AND the chat
    // coach loses the case-anchoring signal, even though the user's
    // confirmation snapshot still applies to the working hypothesis and
    // sits well within the recency window.
    //
    // That is a coach-parity gap on stage #2 (Case formulation) and stage
    // #4 (Adaptation): the user's ratification of the rebuilt read should
    // survive routine engine refinements that operate WITHIN that ratified
    // frame, not be silenced by the first one. A human coach who heard a
    // user ratify "pace is the focus" would not abandon that anchor the
    // moment they noticed a small drift in the same direction; they would
    // name the drift AS a refinement of the user-anchored read, not as a
    // departure from it.
    //
    // Round 39 closes the gap with the LIGHTEST possible surface: ONE
    // additional INTERVENTION CYCLE line, appended INSIDE the active-
    // intervention block at the same call site as round 37/38 (mutually
    // exclusive with BOTH at the predicate level — see below — so the
    // worst-case line count is unchanged from round 38).
    //
    // Defensive scoping (intentional restraint, same shape as rounds 37/38):
    //
    //   - **Pure context surface, not engine state change.** No engine-level
    //     amplification (e.g. extending the active intervention's
    //     `reviewDueAt`, lifting its `reviewStatus`). Round 39 keeps the
    //     impact bounded to the chat coach's context block — the same
    //     surface rounds 30–38 fan out across — so the new signal is
    //     testable in isolation and reversible if real-conversation
    //     evidence shows the line as off.
    //   - **Recency-gated, pinned to rounds 37/38.** The user's
    //     confirmation within the round-37 recency window dampens; beyond
    //     that, the carrying intervention may have aged enough that today's
    //     engine-only refinements are no longer a continuation of the
    //     ratified read — the chat coach should fall back to the generic
    //     "Last course change" line. Round 39 reads the SAME constant
    //     (`caseAnchoredAmplificationRecencyDays`) as rounds 37/38 by
    //     deliberate cross-surface symmetry — all three windows close on
    //     the same day after the verdict.
    //   - **Mutually exclusive with round 37 on the latest entry's nature.**
    //     Round 37 requires `lastChange.documentsUserPushback == true`;
    //     round 39 requires `lastChange.documentsUserPushback == false`.
    //     `documentsUserPushback` is a single boolean at any point in time,
    //     so the two surfaces cannot BOTH fire on the same reply — pinned
    //     end-to-end by `userContextNeverSurfacesBothRound37AndRound39OnSameReply`.
    //   - **Mutually exclusive with round 38 on the ack confidence AND on
    //     the latest entry's nature.** Round 38 requires `.rejected` ack
    //     AND `lastChange.documentsUserPushback == true`. Round 39 requires
    //     `.confirmed` ack AND `lastChange.documentsUserPushback == false`.
    //     Two orthogonal gates flip — round 39 is dark whenever round 38
    //     fires and vice versa. Pinned end-to-end by
    //     `userContextNeverSurfacesBothRound38AndRound39OnSameReply`.
    //   - **Cross-surface contract with round 32.** Round 32 requires the
    //     LATEST entry to document a user pushback; round 39 requires it
    //     NOT to. So round 32 is DARK whenever round 39 fires. That is the
    //     point: round 32 names the rebuild-verdict EVENT (which fired on
    //     the prior user pushback rebuild and surfaced in the chat coach's
    //     context at that time); round 39 names the DURABLE case-anchoring
    //     state that survives the subsequent engine refinement, when round
    //     32 has gone dark. The two are sequential on the timeline:
    //     pushback rebuild → round 32 + round 37 fire → engine refinement →
    //     round 32 + round 37 go dark, round 39 fires.
    //   - **Cross-surface contract with round 31.** Round 31
    //     (`freshRevisedReadContextLines`) also requires the LATEST entry
    //     to document a user pushback, so round 31 is dark whenever round
    //     39 fires. The generic "Last course change" else-arm in
    //     `interventionCycleLines` is what surfaces the engine refinement
    //     as a course change; round 39 layers ON TOP of that line as the
    //     durable case-anchoring signal. The two layer cleanly: the
    //     generic line names the engine refinement; round 39 frames the
    //     active intervention's read as the user's previously-ratified
    //     rebuild that the engine has refined.

    /// Pure predicate: returns true iff the carrying active intervention's
    /// follow-on evidence should still be treated as case-anchored — even
    /// after an engine-only refinement has post-dated the user's
    /// confirmation — because the ratified hypothesis snapshot still
    /// applies and the engine has refined WITHIN that anchor, not replaced
    /// it. Five gates, ALL required:
    ///
    ///   1. `memory.hypothesisAcknowledgement` carries a `.confirmed`
    ///      confidence (the user ratified the rebuilt read).
    ///   2. The ack `appliesTo(currentHypothesis: memory.workingHypothesis)`
    ///      — the rebuilt read the user ratified is still the operating
    ///      hypothesis. A later memory rebuild that materially rewrote the
    ///      working hypothesis drops the predicate; the user's
    ///      confirmation belongs to a hypothesis that no longer exists,
    ///      not to today's engine-refined frame.
    ///   3. The ack was lodged within `caseAnchoredAmplificationRecencyDays`
    ///      of `now` (defensive — stale confirmation does not anchor a
    ///      current case state across an indefinite series of refinements).
    ///   4. The LATEST `adaptationLog` entry is engine-only
    ///      (`documentsUserPushback == false`) AND its `changedAt` is at
    ///      or after the ack's `acknowledgedAt` (the engine refinement
    ///      post-dates the user's ratification — without this gate, an
    ///      engine refinement that pre-dates the ack would falsely fire
    ///      the predicate, which is round 37's territory, not round 39's).
    ///   5. There exists an entry in `adaptationLog` such that
    ///      `documentsUserPushback == true` AND its `changedAt <=
    ///      ack.acknowledgedAt` — the user's ratification was lodged on a
    ///      USER-DRIVEN rebuild that's still represented in the log. This
    ///      gate is the structural anchor that distinguishes round 39
    ///      ("engine refined the user-ratified rebuild") from an entirely
    ///      different state ("engine drifted the lever from a baseline
    ///      reading the user happened to confirm with no prior pushback
    ///      anywhere in the log"). Without this gate, a `.confirmed` ack
    ///      on an engine-only baseline with later engine refinements would
    ///      surface a case-anchored line that has no user-driven anchor
    ///      behind it.
    ///
    /// All five gates are pure reads on memory fields the engine already
    /// writes; no new persisted state, no schema bump, no migration.
    /// Memories persisted before round 39 read `false` on the predicate
    /// automatically — the predicate is dark until all five signals
    /// (`.confirmed` ack, current snapshot match, recency, engine-only
    /// latest entry post-dating the ack, prior user-pushback entry
    /// pre-dating the ack) coexist.
    ///
    /// Mutual exclusion with `caseAnchoredAmplificationApplies` (round 37):
    /// round 37 requires the latest entry to document a user pushback;
    /// round 39 requires it NOT to. `documentsUserPushback` is a single
    /// boolean per entry, so at most one of the two predicates returns
    /// true for any memory state.
    ///
    /// Mutual exclusion with `interventionUnderRepeatedPushbackApplies`
    /// (round 38): round 38 requires `.rejected` ack; round 39 requires
    /// `.confirmed`. `confidence` is a single enum case at any point in
    /// time, so the two predicates cannot both fire on the same memory.
    static func caseAnchoredContinuationApplies(
        in memory: CoachMemory,
        now: Date
    ) -> Bool {
        guard let ack = memory.hypothesisAcknowledgement,
              ack.confidence == .confirmed,
              ack.appliesTo(currentHypothesis: memory.workingHypothesis) else { return false }
        let recencyInterval = TimeInterval(caseAnchoredAmplificationRecencyDays * 24 * 60 * 60)
        guard now.timeIntervalSince(ack.acknowledgedAt) <= recencyInterval else { return false }
        guard let lastChange = memory.adaptationLog?.last,
              lastChange.documentsUserPushback == false,
              lastChange.changedAt >= ack.acknowledgedAt else { return false }
        guard memory.adaptationLog?.contains(where: { change in
            change.documentsUserPushback && change.changedAt <= ack.acknowledgedAt
        }) == true else { return false }
        return true
    }

    /// Returns ONE additional context line when the case-anchored
    /// continuation predicate fires AND an active intervention is being
    /// surfaced. Returns `nil` otherwise so the caller can skip emitting.
    ///
    /// Read by `interventionCycleLines` after rounds 37 and 38's call
    /// sites, at the same call site within the active-intervention block.
    /// Round 39 is mutually exclusive with both rounds 37 and 38 at the
    /// predicate level (see the doc comment on
    /// `caseAnchoredContinuationApplies`), so the worst-case line count
    /// stays the same as it was after round 38 landed — at most one of
    /// the three case-state lines (round 37 amplify / round 38 dampen /
    /// round 39 continue) fires per chat reply.
    ///
    /// The line is intentionally short — one calm sentence that names the
    /// case-anchored state AND tells the model how to resolve the natural
    /// tension between two surfaces on the same reply: the generic "Last
    /// course change" line above will name the engine refinement; round
    /// 39 frames the active intervention's carrying read as the user's
    /// previously-ratified rebuild that the engine has refined within,
    /// not replaced. The model is invited to name how the engine's
    /// refinement COMPLEMENTS the ratified read rather than departing
    /// from it. Brand-voice rules: no exclamation, no "Let's", no "we",
    /// no "sorry", no hype, no shame framing.
    ///
    /// The line does NOT duplicate the round-32 rebuild-verdict block's
    /// content (round 32 is DARK whenever round 39 fires, by construction);
    /// it complements the generic "Last course change" line that the
    /// `interventionCycleLines` else-arm emits on the engine refinement.
    static func caseAnchoredContinuationContextLine(
        memory: CoachMemory,
        now: Date
    ) -> String? {
        guard caseAnchoredContinuationApplies(in: memory, now: now) else { return nil }
        guard memory.activeIntervention != nil else { return nil }
        return "- Case-anchored continuation: the latest course change is an engine-only refinement applied on top of the user's previously-confirmed rebuild (still within the recency window); the active intervention's read remains the ratified rebuild, not a fresh exploration. Speak with quiet conviction on the carrying read. If you reference the latest course change, name how it complements the ratified read rather than replacing it; do not re-open the original."
    }

    // MARK: - Under-pushback continuation through engine refinement (round 40 — durability for round 38)
    //
    // Round 40 — the dampening-durability complement to round 38's
    // under-repeated-pushback line. Round 38 fires only while the LATEST
    // adaptation entry documents a user pushback (the rebuild that
    // produced the carrying hypothesis was user-driven, and the user has
    // since lodged a `.rejected` verdict on the rebuilt read too). The
    // FIRST subsequent engine-only refinement — a quiet lever adjustment
    // the engine writes WITHOUT the user pushing back — drops the
    // latest-entry predicate AND the chat coach loses the under-pushback
    // dampening signal, even though the user's rejection snapshot still
    // applies to the working hypothesis and sits well within the recency
    // window.
    //
    // That is the symmetric mirror, on the `.rejected` branch, of the
    // coach-parity gap round 39 closed on the `.confirmed` branch. A
    // human coach who heard a user reject the rebuilt read would NOT
    // silently treat the case as settled the moment they noticed a quiet
    // engine lever drift; they would treat the user's rejection as the
    // dominant signal, and name the drift AS a refinement OPERATING
    // WITHIN the standing no-fit verdict, not as a resolution of it.
    //
    // Round 40 closes the gap with the LIGHTEST possible surface: ONE
    // additional INTERVENTION CYCLE line, appended INSIDE the active-
    // intervention block at the same call site as rounds 37/38/39
    // (mutually exclusive with ALL THREE at the predicate level — see
    // below — so the worst-case line count is unchanged from round 39).
    //
    // The four predicates (37/38/39/40) now form one closed 2×2 matrix
    // on (ack confidence) × (latest entry's nature):
    //
    //                    | latest = pushback     | latest = engine-only         |
    //   ---------------- | --------------------- | ---------------------------- |
    //   .confirmed ack   | round 37 (amplify)    | round 39 (continuation)      |
    //   .rejected ack    | round 38 (dampen)     | round 40 (under-pushback     |
    //                    |                       |             continuation)    |
    //
    // The four cells are pairwise mutually exclusive at the predicate
    // level — at most ONE of the four case-state lines (37/38/39/40)
    // fires per chat reply.
    //
    // Defensive scoping (intentional restraint, same shape as rounds
    // 37/38/39):
    //
    //   - **Pure context surface, not engine state change.** No engine-
    //     level dampening (e.g. extending the active intervention's
    //     `reviewDueAt`, downgrading its `reviewStatus`). Round 40 keeps
    //     the impact bounded to the chat coach's context block — the
    //     same surface rounds 30–39 fan out across — so the new signal
    //     is testable in isolation and reversible if real-conversation
    //     evidence shows the line as off.
    //   - **Recency-gated, pinned to round 38.** The user's rejection
    //     within the round-38 recency window dampens; beyond that, the
    //     carrying intervention may have aged enough that today's
    //     engine-only refinements are no longer operating within a
    //     standing no-fit verdict — the chat coach should fall back to
    //     the generic "Last course change" line. Round 40 reads the
    //     SAME constant (`repeatedPushbackRecencyDays`) as round 38 by
    //     deliberate cross-surface symmetry — both `.rejected`-branch
    //     windows close on the same day after the verdict.
    //   - **Mutually exclusive with round 38 on the latest entry's
    //     nature.** Round 38 requires `lastChange.documentsUserPushback
    //     == true`; round 40 requires it `== false`.
    //     `documentsUserPushback` is a single boolean at any point in
    //     time, so the two surfaces cannot BOTH fire on the same reply —
    //     pinned end-to-end by
    //     `userContextNeverSurfacesBothRound38AndRound40OnSameReply`.
    //   - **Mutually exclusive with round 37 on the ack confidence AND
    //     on the latest entry's nature.** Round 37 requires `.confirmed`
    //     ack AND `lastChange.documentsUserPushback == true`. Round 40
    //     requires `.rejected` ack AND `lastChange.documentsUserPushback
    //     == false`. Two orthogonal gates flip — round 40 is dark
    //     whenever round 37 fires and vice versa.
    //   - **Mutually exclusive with round 39 on the ack confidence.**
    //     Round 39 requires `.confirmed`; round 40 requires `.rejected`.
    //     `confidence` is a single enum case at any point in time, so
    //     the two predicates cannot both fire on the same memory.
    //   - **Cross-surface contract with round 32.** Round 32 requires
    //     the LATEST entry to document a user pushback; round 40
    //     requires it NOT to. So round 32 is DARK whenever round 40
    //     fires. That is the point: round 32 names the rebuild-verdict
    //     EVENT (which fired on the prior user pushback rebuild AND
    //     surfaced in the chat coach's context at that time); round 40
    //     names the DURABLE under-pushback state that survives the
    //     subsequent engine refinement, when round 32 has gone dark.
    //     The two are sequential on the timeline: pushback rebuild →
    //     `.rejected` ack → round 32 + round 38 fire → engine refinement
    //     → round 32 + round 38 go dark, round 40 fires.
    //   - **Cross-surface contract with round 31.** Round 31
    //     (`freshRevisedReadContextLines`) also requires the LATEST
    //     entry to document a user pushback, so round 31 is dark
    //     whenever round 40 fires. The generic "Last course change"
    //     else-arm in `interventionCycleLines` is what surfaces the
    //     engine refinement as a course change; round 40 layers ON TOP
    //     of that line as the durable under-pushback signal. The two
    //     layer cleanly: the generic line names the engine refinement;
    //     round 40 frames the active intervention as still under the
    //     user's standing no-fit verdict, which the engine has refined
    //     WITHIN, not resolved.

    /// Pure predicate: returns true iff the carrying active intervention's
    /// follow-on evidence should still be treated as under repeated
    /// pushback — even after an engine-only refinement has post-dated the
    /// user's rejection — because the rejected hypothesis snapshot still
    /// applies and the engine has refined WITHIN that standing no-fit
    /// verdict, not closed it. Five gates, ALL required — the exact
    /// `.rejected`-branch mirror of `caseAnchoredContinuationApplies`:
    ///
    ///   1. `memory.hypothesisAcknowledgement` carries a `.rejected`
    ///      confidence (the user has lodged a no-fit verdict on the
    ///      rebuilt read too).
    ///   2. The ack `appliesTo(currentHypothesis: memory.workingHypothesis)`
    ///      — the rebuilt read the user rejected is still the operating
    ///      hypothesis. A later memory rebuild that materially rewrote
    ///      the working hypothesis drops the predicate; the user's
    ///      rejection belongs to a hypothesis that no longer exists,
    ///      not to today's engine-refined frame.
    ///   3. The ack was lodged within `repeatedPushbackRecencyDays` of
    ///      `now` (defensive — stale rejection does not dampen a
    ///      current case state across an indefinite series of
    ///      refinements).
    ///   4. The LATEST `adaptationLog` entry is engine-only
    ///      (`documentsUserPushback == false`) AND its `changedAt` is
    ///      at or after the ack's `acknowledgedAt` (the engine
    ///      refinement post-dates the user's rejection — without this
    ///      gate, an engine refinement that pre-dates the ack would
    ///      falsely fire the predicate, which is round 38's territory,
    ///      not round 40's).
    ///   5. There exists an entry in `adaptationLog` such that
    ///      `documentsUserPushback == true` AND its `changedAt <=
    ///      ack.acknowledgedAt` — the user's rejection was lodged on a
    ///      USER-DRIVEN rebuild that's still represented in the log.
    ///      This gate is the structural anchor that distinguishes round
    ///      40 ("engine refined the user-rejected rebuild") from an
    ///      entirely different state ("engine drifted the lever from a
    ///      baseline reading the user happened to reject with no prior
    ///      pushback anywhere in the log"). Without this gate, a
    ///      `.rejected` ack on an engine-only baseline with later
    ///      engine refinements would surface an under-pushback line
    ///      that has no user-driven rebuild behind it.
    ///
    /// All five gates are pure reads on memory fields the engine
    /// already writes; no new persisted state, no schema bump, no
    /// migration. Memories persisted before round 40 read `false` on
    /// the predicate automatically — the predicate is dark until all
    /// five signals (`.rejected` ack, current snapshot match, recency,
    /// engine-only latest entry post-dating the ack, prior user-pushback
    /// entry pre-dating the ack) coexist.
    ///
    /// Mutual exclusion with `interventionUnderRepeatedPushbackApplies`
    /// (round 38): round 38 requires the latest entry to document a
    /// user pushback; round 40 requires it NOT to.
    /// `documentsUserPushback` is a single boolean per entry, so at
    /// most one of the two predicates returns true for any memory
    /// state.
    ///
    /// Mutual exclusion with `caseAnchoredContinuationApplies` (round
    /// 39): round 39 requires `.confirmed`; round 40 requires
    /// `.rejected`. `confidence` is a single enum case at any point in
    /// time, so the two predicates cannot both fire on the same memory.
    ///
    /// Mutual exclusion with `caseAnchoredAmplificationApplies` (round
    /// 37): round 37 requires `.confirmed` AND latest=pushback; round
    /// 40 requires `.rejected` AND latest=engine-only. Two orthogonal
    /// gates flip.
    static func interventionUnderPushbackContinuationApplies(
        in memory: CoachMemory,
        now: Date
    ) -> Bool {
        guard let ack = memory.hypothesisAcknowledgement,
              ack.confidence == .rejected,
              ack.appliesTo(currentHypothesis: memory.workingHypothesis) else { return false }
        let recencyInterval = TimeInterval(repeatedPushbackRecencyDays * 24 * 60 * 60)
        guard now.timeIntervalSince(ack.acknowledgedAt) <= recencyInterval else { return false }
        guard let lastChange = memory.adaptationLog?.last,
              lastChange.documentsUserPushback == false,
              lastChange.changedAt >= ack.acknowledgedAt else { return false }
        guard memory.adaptationLog?.contains(where: { change in
            change.documentsUserPushback && change.changedAt <= ack.acknowledgedAt
        }) == true else { return false }
        return true
    }

    /// Returns ONE additional context line when the under-pushback
    /// continuation predicate fires AND an active intervention is being
    /// surfaced. Returns `nil` otherwise so the caller can skip emitting.
    ///
    /// Read by `interventionCycleLines` after rounds 37/38/39's call
    /// sites, at the same call site within the active-intervention
    /// block. Round 40 is mutually exclusive with rounds 37, 38, and 39
    /// at the predicate level (see the doc comment on
    /// `interventionUnderPushbackContinuationApplies`), so the worst-
    /// case line count stays the same as it was after round 39 landed —
    /// at most one of the four case-state lines (round 37 amplify /
    /// round 38 dampen / round 39 continue / round 40 under-pushback
    /// continue) fires per chat reply.
    ///
    /// The line is intentionally short — one calm sentence that names
    /// the under-pushback-continuation state AND tells the model how to
    /// resolve the natural tension between two surfaces on the same
    /// reply: the generic "Last course change" line above will name the
    /// engine refinement; round 40 frames the active intervention as
    /// still under the user's standing no-fit verdict, which the engine
    /// has refined WITHIN, not resolved. The model is invited to keep
    /// dampening — slow down on follow-on reads, keep asking the one
    /// focused discriminating question, do not re-prescribe the same
    /// intervention unchanged — and to name the engine refinement as
    /// operating within the standing no-fit verdict, not closing it.
    /// Brand-voice rules: no exclamation, no "Let's", no "we", no
    /// "sorry", no hype, no shame framing on the rejection (the user
    /// steering the coach is a healthy signal, not a failure state).
    ///
    /// The line does NOT duplicate the round-32 rebuild-verdict block's
    /// content (round 32 is DARK whenever round 40 fires, by
    /// construction); it complements the generic "Last course change"
    /// line that the `interventionCycleLines` else-arm emits on the
    /// engine refinement.
    static func interventionUnderPushbackContinuationContextLine(
        memory: CoachMemory,
        now: Date
    ) -> String? {
        guard interventionUnderPushbackContinuationApplies(in: memory, now: now) else { return nil }
        guard memory.activeIntervention != nil else { return nil }
        return "- Intervention still under pushback: the latest course change is an engine-only refinement applied on top of the user's previously-rejected rebuild (still within the recency window); the active intervention remains under the user's no-fit verdict — the engine has refined within that constraint, not resolved it. Continue to slow down on follow-on reads, keep the one focused discriminating question on the table, and do not re-prescribe the same intervention unchanged. If you reference the latest course change, name how it operates within the standing no-fit verdict rather than closing it."
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

    // MARK: - Data-grounded starter prompts
    //
    // Signal priority (first match wins, cap 3 chips at ≤60 chars each):
    //   1. BigMoment active → prep-for-event chips anchored to category
    //   2. Persistent blockers from baseline → targeted weakness chip
    //   3. Generic voice-default fallback
    //
    // This overload is what the view calls. The old `starterPrompts(for:)`
    // remains as the deterministic catalog for tests and the AI chip fallback.
    /// `rotation` varies which catalog prompts fill the non-contextual
    /// slots (owner feedback 2026-06-10: "the suggested prompts are just
    /// the same ones every time"). Callers pass a slow-changing seed
    /// (e.g. day-of-year) so consecutive opens differ while a single
    /// session stays stable. BigMoment chips are genuinely contextual and
    /// never rotate away.
    static func starterPrompts(
        bigMoment: BigMoment?,
        baseline: CommunicationBaseline,
        voice: SpeakingStyleGoal?,
        rotation: Int = 0
    ) -> [String] {
        var chips: [String] = []

        // Signal 1 — BigMoment. If a moment is active and within 60 days,
        // lead with two prompts anchored to the event.
        if let moment = bigMoment {
            let daysUntil = BigMomentStore.daysUntil(moment)
            if let days = daysUntil, days >= 0 && days <= 60 {
                let categoryLabel = moment.category.displayName
                chips.append("How should I open my \(categoryLabel)?")
                if days <= 14 {
                    chips.append("Give me a drill for the next \(days) day\(days == 1 ? "" : "s").")
                } else {
                    chips.append("Help me prep for my \(categoryLabel).")
                }
            }
        }

        // Signal 2 — weakest blocker from baseline. One chip max so it
        // doesn't crowd out the BigMoment prompts. Phrasing alternates by
        // rotation parity so the line reads fresh across days.
        if chips.count < 3,
           let blocker = baseline.persistentBlockers.first,
           !blocker.isEmpty {
            let variants = [
                "Why does my \(blocker.lowercased()) keep slipping?",
                "What's holding back my \(blocker.lowercased())?"
            ]
            let pick = variants[abs(rotation) % variants.count]
            chips.append(pick.count <= 60 ? pick : variants[1])
        }

        // Fill remaining slots (up to 3 total) from the deterministic
        // voice-catalog, starting at a rotation-derived offset and
        // wrapping — consecutive days surface different openers instead
        // of the same head-of-catalog trio forever.
        let catalog = starterPrompts(for: voice)
        if !catalog.isEmpty {
            let offset = abs(rotation) % catalog.count
            for index in 0..<catalog.count {
                if chips.count >= 3 { break }
                let prompt = catalog[(offset + index) % catalog.count]
                if !chips.contains(prompt) {
                    chips.append(prompt)
                }
            }
        }

        return Array(chips.prefix(3))
    }

    // MARK: - AI-tailored starter prompts (empty-state)
    //
    // Sibling to `generateAIFollowUpChips` — same provider plumbing, same
    // locale gate, same `parseAndFilterChips` grounding gate, same
    // never-throw contract — but for the EMPTY-STATE starter row shown
    // above the input bar before the first message. This is the only
    // truly-static chat surface left: `starterPrompts(bigMoment:baseline:
    // voice:)` is data-grounded but its strings are still drawn from a
    // fixed catalog. This overload lets the openers read as "the coach
    // already knows where you are" — anchored to the active BigMoment,
    // the weakest baseline dimension, and the chosen voice tone.
    //
    // Contract (identical to the follow-up chip path):
    //   • Returns nil on EVERY cold path — locale-blocked, no provider,
    //     network failure, model returned empty/unparseable output, or
    //     fewer than `count` chips survive the brand-voice filter. The
    //     caller (`AskNoumView`) keeps the deterministic data-grounded
    //     `starterPrompts(...)` visible and never shows an error.
    //   • Returns exactly `count` chips on success (default 3). Each chip
    //     is written AS THE USER's opening ask — second person, ≤ ~60
    //     chars, no exclamation, no emoji, no leading directive, no
    //     "Let's" — the same brand rules `parseAndFilterChips` enforces.
    //   • Bounded request — 8s timeout, 120 max-tokens, temperature 0.7,
    //     reused verbatim from the follow-up chip path.
    //
    // The deterministic fallback (`starterPrompts(bigMoment:baseline:
    // voice:)`) stays the source of truth for offline / non-English /
    // no-provider / no-signal — zero regression.
    static func generateAIStarterPrompts(
        voice: SpeakingStyleGoal?,
        bigMoment: BigMoment?,
        baseline: CommunicationBaseline,
        recentSessionDigest: String? = nil,
        count: Int = 3
    ) async -> [String]? {
        // Locale + provider gates first — match `generateAIFollowUpChips`,
        // `AICoachChatService`, and `AIPromptGeneratorService`. Reading
        // state on the main actor since both stores live there.
        guard await activeLocaleSupportsAI() else { return nil }
        guard let provider = await currentProvider(),
              let endpoint = provider.endpoint,
              let key = apiKey(for: provider) else { return nil }

        let system = aiStarterSystemPrompt
        let user = aiStarterUserPrompt(
            voice: voice,
            bigMoment: bigMoment,
            baseline: baseline,
            recentSessionDigest: recentSessionDigest,
            count: count
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Same tight timeout as the follow-up chips — starters are a
        // friction-remover, not a blocker; a stalled request shouldn't
        // hold the network while the deterministic catalog is already on
        // screen.
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
                    "max_tokens": 120,
                    "messages": [
                        ["role": "system", "content": system],
                        ["role": "user", "content": user]
                    ]
                ]
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            case .gemini:
                request.setGoogleAPIKey(key)
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
            // Same grounding gate as the follow-up chips: a partial /
            // ungrounded batch (fewer than `count` survive the filter)
            // loses to the deterministic catalog.
            return parseAndFilterChips(raw, count: count)
        } catch {
            return nil
        }
    }

    private static let aiStarterSystemPrompt = """
    You generate short opening prompts for a speaking-coach chat surface. \
    Each prompt is written AS THE USER opening a conversation with their \
    coach — second person, direct, the first thing they'd tap to start.

    Hard rules (every output must clear all of these):
    - Exactly the requested number of prompts. One per line. No numbering, no \
    bullets, no quotes, no JSON, no preface.
    - Each prompt ≤ 10 words.
    - Sentence case. No emoji. No exclamation marks. No "Let's".
    - No leading directive verbs like "Tell me", "Describe", "Explain", \
    "Discuss" — write as the user's own opening question or short ask.
    - Anchor to the user's situation: if a real upcoming moment is given, at \
    least one prompt preps for it; if a recent rep is given, at least one \
    references what just happened (the score, theme, intent, or weak area). \
    Otherwise lean on the weakest dimension and the voice tone.
    - Tailor to the voice tone. A user training authoritative gets \
    verdict-shaped openers; warm gets felt-experience asks; concise gets \
    clipped asks; persuasive gets reasoning asks; executive gets top-line \
    asks; storytelling gets arc-shaped asks.
    - Output only the prompts themselves, separated by newlines.
    """

    private static func aiStarterUserPrompt(
        voice: SpeakingStyleGoal?,
        bigMoment: BigMoment?,
        baseline: CommunicationBaseline,
        recentSessionDigest: String?,
        count: Int
    ) -> String {
        let voiceLine = voice.map { "Voice tone: \($0.title)." } ?? "Voice tone: not set — keep calm and direct."

        var lines: [String] = [voiceLine]

        // Upcoming moment (if any, within the window the deterministic
        // catalog also uses). Summary only — title + category + days.
        if let moment = bigMoment,
           let days = BigMomentStore.daysUntil(moment),
           days >= 0, days <= 60 {
            let label = moment.category.displayName
            lines.append("Upcoming moment: \(label) in \(days) day\(days == 1 ? "" : "s").")
        }

        // Weakest baseline dimension — single source of truth.
        if let weakest = PracticeTopics.weakestDimensionLabel(for: baseline) {
            lines.append("Weakest dimension right now: \(weakest).")
        }

        // Recent-rep digest (already privacy-bounded by the caller —
        // score/theme/intent/headline only, never raw transcript).
        if let digest = recentSessionDigest,
           !digest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(digest)
        }

        lines.append("")
        lines.append("Return exactly \(count) opening prompts, one per line.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Recent-session digest (chip context)
    //
    // Composes a tiny, privacy-bounded summary of the user's most recent
    // reps for the AI chip + starter prompts. PRIVACY: this NEVER pastes
    // raw transcript — only the score, theme label, declared-intent label,
    // and the (already coach-authored) headline. Bounded to `limit` reps
    // (default 2), one short line each, so the small chip token budget
    // (120 tokens) doesn't get crowded out and truncate the chips.
    //
    // Returns nil when there are no usable rows (empty history, or every
    // recent session is so bare it produces no signal) — the caller then
    // omits the RECENT REPS block entirely and the chip path falls through
    // to today's behavior. Decode-safe by construction: every field it
    // reads is already optional on `PracticeSession`.
    //
    // Pure + static so it's unit-testable without a store or a provider.
    static func recentSessionDigestForChips(
        sessions: [PracticeSession],
        baseline: CommunicationBaseline,
        limit: Int = 2
    ) -> String? {
        guard limit > 0 else { return nil }
        // Most-recent first. `sessions` is persisted newest-last in some
        // call paths and newest-first in others, so sort explicitly by
        // date to make the digest deterministic regardless of caller order.
        let recent = sessions
            .sorted { $0.date > $1.date }
            .prefix(limit)

        var rows: [String] = []
        for session in recent {
            var parts: [String] = []
            if let score = session.score {
                parts.append("score \(score)/10")
            }
            if let theme = session.theme, theme != .all {
                parts.append("theme \(theme.rawValue)")
            }
            if let intent = session.intentLabel,
               !intent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                parts.append("aimed for \(intent)")
            }
            if let headline = session.headline,
               !headline.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Headlines are coach-authored summaries, never the user's
                // raw words — safe to pass through. Strip any trailing
                // punctuation so the line stays clipped + clause-shaped.
                let clean = headline
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: ".!"))
                if !clean.isEmpty {
                    parts.append("read: \(clean)")
                }
            }
            guard !parts.isEmpty else { continue }
            rows.append("- " + parts.joined(separator: ", "))
        }

        guard !rows.isEmpty else { return nil }

        // One labelled block. The weakest-dimension line lives in the
        // starter prompt builder (single source of truth) — keep this
        // strictly the per-rep summary so the two don't duplicate.
        // "LAST SESSIONS", not "RECENT REPS": the model mirrors section
        // headers into its replies, and "recent reps show..." is on the
        // robotic-phrase ban list — a header that verbalizes straight into
        // a banned phrase guarantees gate trips on "where am I?" turns.
        return (["LAST SESSIONS (most recent first):"] + rows).joined(separator: "\n")
    }

    // MARK: - Follow-up suggestions (post-reply)
    //
    // Feeds the single "Next move" continuation panel in `AskNoumView`.
    // Different register from `starterPrompts`: starters are first-message
    // friction-removers; follow-ups have to earn their place after a real
    // reply lands. Generic replies intentionally return no chips.
    //
    // Topic detection rules:
    //   • Lightweight, deterministic, case-insensitive substring match
    //     on the coach's last reply. No NLP, no per-token analysis —
    //     the chips are nudges, not a parsed response.
    //   • Order of detection is intentional. We pick at most ONE topic
    //     to anchor the chips. Anchoring on the first detected topic keeps
    //     the continuation coherent.
    //   • Topics intentionally narrow to surfaces the coach actually
    //     talks about: drills, pauses, pace, fillers, weekly cadence,
    //     and turn-aware repair/direction/greeting fallbacks. Adding a topic
    //     means adding chips that read in every voice — we keep the catalog
    //     tight on purpose.
    //
    // Restraint contract:
    //   • If the reply is empty (e.g. mid-pending state, never
    //     happens in practice but defensively safe), return an empty
    //     array — `AskNoumView` collapses the chip row entirely.
    //   • Voice-shaped for anchored topics — six voices + nil fallback.
    //   • No exclamations, no "Let's", no emoji — same brand rules
    //     as everywhere else on the surface.
    static func followUpSuggestions(
        forCoachReply reply: String,
        previousCoachReply: String? = nil,
        lastUserTurn: String? = nil,
        voice: SpeakingStyleGoal?
    ) -> [String] {
        let trimmed = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if let answerChoices = choiceAnswerFollowUps(
            forCoachReply: trimmed,
            previousCoachReply: previousCoachReply,
            lastUserTurn: lastUserTurn,
            voice: voice
        ) {
            return answerChoices
        }
        let topic = detectFollowUpTopic(in: trimmed)
        if topic == .generic,
           let turnAware = turnAwareFallbackFollowUps(
               lastUserTurn: lastUserTurn,
               previousCoachReply: previousCoachReply,
               voice: voice
           ) {
            return turnAware
        }
        if topic == .generic {
            return []
        }
        return followUpChips(for: topic, voice: voice)
    }

    /// Last-turn aware fallback for the deterministic chip path. The AI chip
    /// path already receives the current turn; this keeps the no-provider /
    /// locale-blocked path from dropping back to broad evergreen prompts when
    /// the user's latest turn carries an obvious conversational job.
    private static func turnAwareFallbackFollowUps(
        lastUserTurn: String?,
        previousCoachReply: String?,
        voice: SpeakingStyleGoal?
    ) -> [String]? {
        guard let lastUserTurn else { return nil }
        let trimmed = lastUserTurn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        let normalized = normalizedTurn(trimmed)

        if containsAny(lower, [
            "robotic", "generic", "not ideal", "not a fan", "no where near",
            "nowhere near", "annoy", "frustrat", "sucks", "poop",
            "not human", "doesn't feel", "does not feel", "too much writing",
            "hardcoded"
        ]) {
            return repairFollowUps(voice: voice)
        }

        if containsAny(lower, [
            "what next", "next move", "what should i do", "where should",
            "what do i work", "focus on", "continue", "implement it",
            "make a bigger stride", "go for", "do the next"
        ]) {
            return directionFollowUps(voice: voice)
        }

        if isLowSignalGreeting(normalized) {
            return greetingFollowUps(previousCoachReply: previousCoachReply, voice: voice)
        }

        return nil
    }

    private static func repairFollowUps(voice: SpeakingStyleGoal?) -> [String] {
        switch voice {
        case .executive:
            return ["Rewrite the coaching move", "Use my last rep", "Set the priority"]
        case .concise:
            return ["Show the sharper version", "Use my last rep", "Pick one priority"]
        case .warm:
            return ["Make it feel more human", "Use my last rep", "Pick one helpful move"]
        case .authoritative:
            return ["Give me the sharper read", "Use my last rep", "Pick the real priority"]
        case .persuasive:
            return ["Show the better reasoning", "Use my last rep", "Pick the strongest move"]
        case .storytelling:
            return ["Make the read feel alive", "Use my last rep", "Find the turning point"]
        case .none:
            return ["Make it more human", "Use my last rep", "Pick one priority"]
        }
    }

    private static func directionFollowUps(voice: SpeakingStyleGoal?) -> [String] {
        switch voice {
        case .executive:
            return ["Give me the drill", "Define the success metric", "Use my last rep"]
        case .concise:
            return ["Give me the drill", "Success target?", "Use my last rep"]
        case .authoritative:
            return ["Prescribe the drill", "Name the standard", "Use my last rep"]
        case .warm:
            return ["Give me one drill", "What should feel different?", "Use my last rep"]
        case .persuasive:
            return ["Pick the strongest drill", "Show the reasoning", "Use my last rep"]
        case .storytelling:
            return ["Pick the next scene", "Name the turning point", "Use my last rep"]
        case .none:
            return ["Give me the drill", "What should improve first?", "Use my last rep"]
        }
    }

    private static func greetingFollowUps(
        previousCoachReply: String?,
        voice: SpeakingStyleGoal?
    ) -> [String] {
        let previous = previousCoachReply?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lower = previous.lowercased()

        var chips: [String] = []
        if let quoted = quotedFocusLabel(in: previous) {
            chips.append("Resume \(quoted)")
        } else if let voice {
            chips.append("Resume \(voice.title)")
        }

        if lower.contains("last rep") || lower.contains("recent rep") || lower.contains("score") {
            chips.append("Review my last rep")
        }
        if lower.contains("plan") || lower.contains("7 days") || lower.contains("seven days") || lower.contains("week") {
            chips.append("Resume the plan")
        }
        if lower.contains("filler") || lower.contains("\"um") || lower.contains("\"uh") {
            chips.append("Check filler pattern")
        }

        chips.append("Set today's target")
        chips.append("Pick the next rep")

        var seen = Set<String>()
        let unique = chips.filter { chip in
            let key = chip.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }

        return Array(unique.prefix(3))
    }

    /// Choice-question chips are different from normal follow-ups: if the
    /// coach just asked the user to choose a direction, the chips should read
    /// as possible answers, not generic meta-prompts. This keeps the instant
    /// fallback aligned with the AI path while remaining pure/testable.
    private static func choiceAnswerFollowUps(
        forCoachReply reply: String,
        previousCoachReply: String?,
        lastUserTurn: String?,
        voice: SpeakingStyleGoal?
    ) -> [String]? {
        guard replyLooksLikeChoiceQuestion(reply) else { return nil }

        let context = [reply, previousCoachReply, lastUserTurn]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        let lowerContext = context.lowercased()

        var chips: [String] = []
        if let quoted = quotedFocusLabel(in: context) {
            chips.append("Work on \(quoted)")
        } else if let voice {
            chips.append("Stay with \(voice.title)")
        }

        if lowerContext.contains("filler") || lowerContext.contains("\"um") || lowerContext.contains("\"uh") {
            chips.append("Fix filler words")
        }
        if lowerContext.contains("pace") || lowerContext.contains("rush") || lowerContext.contains("wpm") {
            chips.append("Fix pace")
        }
        if lowerContext.contains("pause") || lowerContext.contains("silence") || lowerContext.contains("breath") {
            chips.append("Improve pauses")
        }
        if lowerContext.contains("delivery") || lowerContext.contains("pitch")
            || lowerContext.contains("vocal variety") || lowerContext.contains("intonation")
            || lowerContext.contains("inflection") || lowerContext.contains("monotone") {
            chips.append("Tune delivery")
        }
        if lowerContext.contains("structure") || lowerContext.contains("opening")
            || lowerContext.contains("close") || lowerContext.contains("point") {
            chips.append("Tighten structure")
        }

        var seen = Set<String>()
        chips = chips.filter { chip in
            let key = chip.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }

        if chips.count >= 2 {
            return Array(chips.prefix(2)) + ["Compare both"]
        }
        if chips.count == 1 {
            return [chips[0], "Choose another focus", "Compare both"]
        }
        switch voice {
        case .executive:
            return ["Stay with this priority", "Switch the focus", "Compare both"]
        case .concise:
            return ["Stay here", "Switch focus", "Compare both"]
        default:
            return ["Stay with this focus", "Choose another focus", "Compare both"]
        }
    }

    private static func replyLooksLikeChoiceQuestion(_ reply: String) -> Bool {
        let lowerReply = reply.lowercased()
        return lowerReply.contains("which direction would you prefer")
            || lowerReply.contains("what is your priority")
            || lowerReply.contains("what's your priority")
            || lowerReply.contains("what would you like to focus")
            || lowerReply.contains("which should we focus")
            || lowerReply.contains("where should we focus")
            || (lowerReply.contains(" or ")
                && (lowerReply.contains("we can ")
                    || lowerReply.contains("we could ")
                    || lowerReply.contains("would you prefer")
                    || lowerReply.contains("priority today")
                    || lowerReply.contains("choose")))
    }

    private static func quotedFocusLabel(in text: String) -> String? {
        let parts = text.components(separatedBy: "\"")
        guard parts.count >= 3 else { return nil }
        let candidate = parts[1]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".:;,-"))
        guard candidate.count >= 3, candidate.count <= 28 else { return nil }
        return candidate
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
        /// Coach talked about vocal delivery — pitch, vocal variety, tone,
        /// energy, monotone, projection, emphasis, inflection.
        case deliveryMentioned
        /// Coach framed in terms of the week or a 7-day plan.
        case weeklyMentioned
        /// Generic — no specific anchor; voice-default evergreen chips.
        case generic
    }

    static func detectFollowUpTopic(in reply: String) -> FollowUpTopic {
        let lower = reply.lowercased()
        // Order matters — we anchor on the FIRST detected topic. Drills
        // are the most concrete coach recommendations. Explicit filler
        // quotes ("um"/"uh") come before pause/silence language so a
        // filler-reduction reply like "replace 'um' with silence" still
        // opens the filler follow-up path.
        if lower.contains("drill") || lower.contains("exercise") || lower.contains("try this") {
            return .drillMentioned
        }
        if lower.contains("filler") || lower.contains("\"um") || lower.contains("\"uh") || lower.contains(" um ") || lower.contains(" uh ") {
            return .fillerMentioned
        }
        if lower.contains("pause") || lower.contains("silence") || lower.contains("breath") {
            return .pauseMentioned
        }
        if lower.contains("pace") || lower.contains("wpm") || lower.contains("slow") || lower.contains("rush") {
            return .paceMentioned
        }
        if lower.contains("pitch") || lower.contains("vocal variety") || lower.contains("monotone")
            || lower.contains("intonation") || lower.contains("inflection") || lower.contains("vary your")
            || lower.contains("vocal energy") || lower.contains("projection") || lower.contains("emphasis") {
            return .deliveryMentioned
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
        case .deliveryMentioned:
            return deliveryFollowUps(voice: voice)
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

    /// A4 — situational chips when the coach reply is about vocal DELIVERY
    /// (pitch, variety, tone, energy). Previously these replies fell through to
    /// the generic evergreen set; now they get a delivery-anchored nudge.
    private static func deliveryFollowUps(voice: SpeakingStyleGoal?) -> [String] {
        switch voice {
        case .authoritative:
            return ["What's the pitch move?", "When does my voice flatten?", "Drill to add range?"]
        case .warm:
            return ["How do I sound more alive?", "When does my warmth fade?", "A drill for natural range?"]
        case .concise:
            return ["Best range drill?", "Where do I flatten?", "One move to fix it?"]
        case .persuasive:
            return ["How does pitch move the listener?", "Where does my delivery flatten?", "A drill that adds lift?"]
        case .executive:
            return ["Pitch range for an exec read-out?", "Where does my voice go flat?", "Tactic to add variety?"]
        case .storytelling:
            return ["How does pitch carry the scene?", "Where does my voice flatten?", "A drill for vocal range?"]
        case .none:
            return ["How do I add vocal variety?", "Where does my voice flatten?", "What's a good range drill?"]
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
        recentSessionDigest: String? = nil,
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
            recentSessionDigest: recentSessionDigest,
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
                request.setGoogleAPIKey(key)
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
            return parseAndFilterChips(
                raw,
                count: count,
                lastUserTurn: trimmedTurn,
                lastCoachReply: trimmedReply
            )
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
    - If the coach offered options, prompts must be answer options, not meta \
    questions. Good: "Work on Engaging", "Fix filler words", "Compare both". \
    Bad in that moment: "Next move?", "What am I missing?", "Where's the leverage?"
    - Output only the prompts themselves, separated by newlines.
    """

    private static func aiChipsUserPrompt(
        lastUserTurn: String,
        lastCoachReply: String,
        voice: SpeakingStyleGoal?,
        recentSessionDigest: String?,
        count: Int
    ) -> String {
        let voiceLine = voice.map { "Voice tone: \($0.title)." } ?? "Voice tone: not set — keep calm and direct."
        // Recent-rep digest is optional + already privacy-bounded by the
        // caller (score/theme/intent/headline only, never raw transcript).
        // When present it gives the chips a real anchor ("ask about my
        // last rep's score") instead of pure conversational follow-up.
        let digestBlock: String
        if let digest = recentSessionDigest,
           !digest.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            digestBlock = "\n\(digest)\n"
        } else {
            digestBlock = ""
        }
        return """
        \(voiceLine)
        \(digestBlock)
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

    /// Turn-aware sibling for AI follow-up chip generation. The generic parser
    /// enforces brand shape; this layer enforces usefulness in the actual
    /// moment so a valid-but-generic batch cannot override stronger
    /// deterministic chips after a choice, critique, greeting, or "what next"
    /// turn.
    static func parseAndFilterChips(
        _ raw: String,
        count: Int,
        lastUserTurn: String?,
        lastCoachReply: String?
    ) -> [String]? {
        guard let chips = parseAndFilterChips(raw, count: count) else { return nil }
        guard chipBatchMatchesTurn(
            chips,
            lastUserTurn: lastUserTurn,
            lastCoachReply: lastCoachReply
        ) else { return nil }
        return chips
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

    private static func chipBatchMatchesTurn(
        _ chips: [String],
        lastUserTurn: String?,
        lastCoachReply: String?
    ) -> Bool {
        let lowerChips = chips.map { chipNormalizedForContext($0) }
        let turn = lastUserTurn?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let lowerTurn = chipNormalizedForContext(turn)
        let reply = lastCoachReply?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if replyLooksLikeChoiceQuestion(reply) {
            return chipBatchAnswersChoice(lowerChips)
        }

        if containsAny(lowerTurn, [
            "robotic", "generic", "not ideal", "not a fan", "no where near",
            "nowhere near", "annoy", "frustrat", "sucks", "poop",
            "not human", "doesn't feel", "does not feel", "too much writing",
            "hardcoded"
        ]) {
            return chipBatchRepairsTrust(lowerChips)
        }

        if containsAny(lowerTurn, [
            "what next", "next move", "what should i do", "where should",
            "what do i work", "focus on", "continue", "implement it",
            "make a bigger stride", "go for", "do the next"
        ]) {
            return chipBatchGivesDirection(lowerChips)
        }

        if isLowSignalGreeting(normalizedTurn(turn)) {
            return !lowerChips.allSatisfy(chipIsGenericMeta)
        }

        return true
    }

    private static func chipNormalizedForContext(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func chipIsGenericMeta(_ lowerChip: String) -> Bool {
        containsAny(lowerChip, [
            "next move",
            "what am i missing",
            "where's the leverage",
            "what's next",
            "what now",
            "what should i do",
            "how do i improve",
            "keep going",
            "more detail"
        ])
    }

    private static func chipBatchAnswersChoice(_ lowerChips: [String]) -> Bool {
        guard !lowerChips.contains(where: chipIsGenericMeta) else { return false }
        return lowerChips.contains { chip in
            containsAny(chip, [
                "work on", "stay with", "fix ", "improve ", "tune ",
                "tighten ", "compare", "filler", "pace", "pause",
                "delivery", "structure", "engaging", "concise", "warm",
                "authoritative", "executive", "persuasive", "story"
            ])
        }
    }

    private static func chipBatchRepairsTrust(_ lowerChips: [String]) -> Bool {
        guard !lowerChips.contains(where: chipIsGenericMeta) else { return false }
        return lowerChips.contains { chip in
            containsAny(chip, [
                "human", "sharper", "better", "rewrite", "last rep",
                "priority", "friction", "specific", "grounded", "real"
            ])
        }
    }

    private static func chipBatchGivesDirection(_ lowerChips: [String]) -> Bool {
        guard !lowerChips.contains(where: chipIsGenericMeta) else { return false }
        return lowerChips.contains { chip in
            containsAny(chip, [
                "drill", "success", "target", "last rep", "next rep",
                "priority", "standard", "practice", "pick", "prescribe"
            ])
        }
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

    /// A compact "working formulation" for the coach. The rest of the
    /// context gives the model facts; this section tells it how a human
    /// coach would currently weight those facts: how much evidence exists,
    /// what lever seems most useful, and how tightly that lever maps to the
    /// user's stated voice goal. This stays bounded and evidence-labelled so
    /// it cannot turn weak reads into fake certainty.
    private static func coachMemoryLines(
        profile: CoachingProfile?,
        baseline: CommunicationBaseline,
        sessions: [PracticeSession],
        trends: [SkillTrend]
    ) -> [String] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? .distantPast
        let recentSessionCount = sessions.filter { $0.date >= cutoff }.count
        let maxTrendWindow = trends.map(\.windowSize).max() ?? 0
        let evidenceCount = [recentSessionCount, baseline.qualifyingSessionCount, maxTrendWindow].max() ?? 0
        guard evidenceCount > 0 else { return [] }

        let derivedConfidence = BaselineConfidence.from(sessionCount: evidenceCount)
        let confidence = max(baseline.overallConfidence, derivedConfidence)
        let signalNoun = evidenceCount == 1 ? "rep signal" : "rep signals"

        var lines: [String] = [
            "- Evidence depth: \(confidence.label) across \(evidenceCount) \(signalNoun); \(evidenceGuidance(for: confidence))."
        ]

        if let lever = currentCoachingLever(from: trends, profile: profile) {
            let area = lever.skillArea.displayName
            let evidence = memoryEvidencePhrase(for: lever)
            lines.append("- Current coaching hypothesis: \(area) is the next lever (\(lever.confidence.rawValue) evidence: \(evidence)).")

            if let voice = profile?.speakingStyleGoal {
                let voiceLabel = voice.title.lowercased()
                if voice.aligns(with: lever.skillArea) {
                    lines.append("- Goal fit: \(area) directly supports the user's \(voiceLabel) voice.")
                } else {
                    lines.append("- Goal fit: \(area) is not the primary route to the user's \(voiceLabel) voice; explain why it matters before prescribing.")
                }
            }
        } else if let blocker = baseline.persistentBlockers.first, !blocker.isEmpty {
            lines.append("- Current coaching hypothesis: \(blocker) is the persistent blocker to check first; tie advice to baseline evidence.")
        }

        if let strength = baseline.topStrengths.first, !strength.isEmpty {
            lines.append("- Preserve: \(strength).")
        }
        if let blocker = baseline.persistentBlockers.first, !blocker.isEmpty {
            lines.append("- Watch: \(blocker).")
        }

        return Array(lines.prefix(5))
    }

    private static func coachMemoryLines(
        memory: CoachMemory
    ) -> [String] {
        let signalNoun = memory.evidenceCount == 1 ? "rep signal" : "rep signals"
        var lines: [String] = [
            "- Evidence depth: \(memory.evidenceConfidence.label) across \(memory.evidenceCount) \(signalNoun); \(evidenceGuidance(for: memory.evidenceConfidence))."
        ]

        if let goal = memory.statedGoalSummary, !goal.isEmpty {
            lines.append("- Stated goal anchor: \(goal)")
        }

        if let planFocus = memory.planFocus,
           let weekIndex = memory.planWeekIndex {
            if let mode = memory.planMode {
                lines.append("- Current plan: week \(weekIndex) trains \(planFocus.displayName) via \(mode.displayLabel).")
            } else {
                lines.append("- Current plan: week \(weekIndex) trains \(planFocus.displayName).")
            }
        }

        if let intent = memory.lastIntentLabel, !intent.isEmpty {
            lines.append("- Last declared rep focus: \(intent).")
        }

        return Array(lines.prefix(7))
    }

    private static func coachCaseFileLines(
        memory: CoachMemory
    ) -> [String] {
        guard let caseFile = memory.caseFile else { return [] }

        var lines: [String] = []
        if let hypothesis = caseFile.hypothesis {
            lines.append("- Case hypothesis: \(hypothesis)")
        } else if let focus = caseFile.focus {
            lines.append("- Case focus: \(focus.displayName).")
        }
        lines.append("- Evidence: \(caseFile.evidenceSummary).")
        if let delivery = caseFile.deliveryRead?.tentativeLine {
            lines.append("- Delivery read: \(delivery)")
        }
        if let active = caseFile.activeIntervention {
            lines.append("- Intervention: \(active).")
        }
        if let target = caseFile.observableTarget {
            lines.append("- Observable target: \(target).")
        }
        if let measure = caseFile.successMeasure {
            lines.append("- Success measure: \(measure).")
        }
        if let due = caseFile.reviewDueAt {
            lines.append("- Review due: \(caseReviewLabel(for: due)).")
        }
        if let pattern = caseFile.subjectivePattern {
            lines.append("- Subjective pattern: \(pattern) Treat as self-report, not diagnosis.")
        }
        if let transfer = caseFile.transferRead {
            lines.append("- Transfer read: \(transfer) User-reported; not proof of causation.")
        }
        if let upcoming = caseFile.upcomingMomentLine {
            lines.append("- \(upcoming)")
        }
        lines.append("- Next coach move: \(caseFile.nextMove.contextLabel). \(caseFile.nextMove.contextInstruction) \(caseFile.nextQuestion)")

        return Array(lines.prefix(11))
    }

    private static func coachCaseFormulationLines(
        memory: CoachMemory
    ) -> [String] {
        var lines: [String] = []
        if let currentLever = memory.currentLever {
            let basis = memory.currentLeverBasis?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let evidence = basis.isEmpty ? "stored coach memory" : basis
            if let hypothesis = memory.workingHypothesis, !hypothesis.isEmpty {
                lines.append("- Working hypothesis (tentative): \(hypothesis)")
            } else if let confidence = memory.currentLeverConfidence {
                lines.append("- Current coaching hypothesis: \(currentLever.displayName) is the next lever (\(confidence.rawValue) evidence: \(evidence)).")
            } else {
                lines.append("- Current coaching hypothesis: \(currentLever.displayName) is the next lever (\(evidence)).")
            }

            // User's most-recent ack on the working hypothesis. Only
            // surfaced when the ack is still about the currently-carried
            // hypothesis (the snapshot guard) — a stale ack from a prior
            // case read is dropped so the coach never reinforces a
            // hypothesis the user already agreed-to-then-replaced.
            if let ack = memory.hypothesisAcknowledgement,
               ack.appliesTo(currentHypothesis: memory.workingHypothesis) {
                lines.append("- Hypothesis acknowledgement: \(ack.confidence.contextLabel). \(ack.confidence.nextMoveInstruction)")
            }

            if let prior = memory.previousLever, prior != currentLever {
                lines.append("- Focus shift: last read was \(prior.displayName); current read is \(currentLever.displayName).")
            }

            if let voice = memory.voice {
                switch memory.goalFit {
                case .aligned:
                    lines.append("- Goal fit: \(currentLever.displayName) directly supports the user's \(voice.title.lowercased()) voice.")
                case .offGoal:
                    lines.append("- Goal fit: \(currentLever.displayName) is not the primary route to the user's \(voice.title.lowercased()) voice; explain why it matters before prescribing.")
                case .noVoice, .noLever:
                    break
                }
            }

            // Stated-vs-measured concordance (slice-4). The diagnosis engine
            // reconciles the measured lever with the challenge the user
            // STATED at onboarding (`CoachingProfile.biggestChallenge`) and
            // never silently switches focus on a divergence — a guardrail a
            // real coach does not violate. We surface that read here, beside
            // the goal-fit read, so chat coach / blueprint / debrief all
            // reference the same one source of truth.
            //
            //   • .divergent → ONE divergence question naming both the stated
            //     challenge area and the measured lever, so the coach asks
            //     which to anchor to rather than overriding the user's stated
            //     focus.
            //   • .agree → a brief affirmation that the reps line up with what
            //     the user came in for (no question).
            //   • .deferred / .unknown → silent: below the evidence floor the
            //     measured read isn't trustworthy enough to challenge the
            //     stated challenge, and `.unknown` means nothing to say.
            switch memory.statedChallengeConcordance {
            case .divergent:
                if let statedArea = memory.statedChallengeArea, statedArea != currentLever {
                    lines.append("- Stated-vs-measured: the user came in wanting to work on \(statedArea.displayName), but the reps point more at \(currentLever.displayName). Ask which to anchor to — do not silently switch the focus they stated.")
                } else if memory.statedChallengeArea == nil {
                    lines.append("- Stated-vs-measured: the measured reps may diverge from the user's stated challenge, but the stored stated area is missing. Ask a clarifying question before changing focus.")
                }
            case .agree:
                lines.append("- Stated-vs-measured: the reps line up with the \(currentLever.displayName) challenge the user came in for; you can affirm that alignment.")
            case .deferred, .unknown:
                break
            }
        }

        if let transfer = memory.lastTransferReview {
            lines.append("- Transfer case update: \(transfer.reportedOutcomeLine) Next review move: \(transfer.nextAction.contextInstruction) This is user-reported evidence only; do not treat it as proof that the intervention caused the outcome.")
        }

        if let reflection = memory.lastReflectionReview {
            lines.append("- Subjective reflection: \(reflection.reportedLine). Next review move: \(reflection.nextAction.contextInstruction)")
            lines.append("- Reflection evidence rule: this is their own read, not a measured signal — it captures inner experience; reference it, never contradict it.")
        } else if let reflection = memory.lastReflectionSummary, !reflection.isEmpty {
            lines.append("- Last reflection: the user said \(reflection). This is their own read, not a measured signal — reference it, never contradict it.")
        }
        if let pattern = memory.reflectionPattern {
            lines.append("- Subjective pattern (\(pattern.confidence.contextLabel)): \(pattern.reportedLine) Next review move: \(pattern.contextInstruction)")
            lines.append("- Pattern evidence rule: this is repeated self-report, not a diagnosis — ask the user to confirm, refine, or reject it before strengthening the claim.")
        }
        if let strength = memory.strengths.first, !strength.isEmpty {
            lines.append("- Preserve: \(strength).")
        }
        if let blocker = memory.blockers.first, !blocker.isEmpty {
            lines.append("- Watch: \(blocker).")
        }

        return Array(lines.prefix(12))
    }

    private static func interventionCycleLines(
        memory: CoachMemory,
        includeActiveIntervention: Bool
    ) -> [String] {
        var lines: [String] = []

        if includeActiveIntervention, let intervention = memory.activeIntervention {
            let purpose = intervention.focus ?? intervention.title
            let marker = intervention.target.map { " Success marker: \($0)." } ?? ""
            lines.append("- Active intervention: \(intervention.mode.displayLabel) for \(purpose).\(marker)")
            let repNoun = intervention.followedRepCount == 1 ? "followed rep" : "followed reps"
            lines.append("- Evidence depth for this intervention: \(intervention.followedRepCount) \(repNoun); review threshold \(intervention.minimumFollowedRepsForReview).")
            lines.append("- Intervention review: \(intervention.reviewStatus.contextLabel) \(intervention.reviewBasis)")
            if let criterion = intervention.successCriterion {
                let statusTail = intervention.criterionStatus.map { " — \($0.contextLabel)" } ?? ""
                lines.append("- Success criterion: \(criterion.summary)\(statusTail).")
            }
            if let due = intervention.reviewDueAt {
                lines.append("- Review cadence: revisit by \(caseReviewLabel(for: due)).")
            }
            // Round-37: case-anchored amplification. Anchored against
            // `memory.updatedAt` as the time origin (same anchor round 31
            // uses for `isFresh`) so the predicate is pure and locked by
            // tests without standing up a real wall clock. The recency
            // window guards a stale confirmation from amplifying follow-on
            // evidence across multiple weeks of practice.
            if let amplificationLine = caseAnchoredAmplificationContextLine(
                memory: memory,
                now: memory.updatedAt
            ) {
                lines.append(amplificationLine)
            }
            // Round-38: under-repeated-pushback dampening — mirror of round
            // 37 on the `.rejected` branch. Mutually exclusive with the
            // round-37 amplification at the predicate level (confirmed XOR
            // rejected ack), so at most ONE of the two lines fires per
            // chat reply. The 9-line cap on this block is preserved:
            // worst case (5 base intervention lines + 1 round-37-or-38
            // line + 2 round-32 verdict lines) = 8, under cap.
            if let repeatedPushbackLine = interventionUnderRepeatedPushbackContextLine(
                memory: memory,
                now: memory.updatedAt
            ) {
                lines.append(repeatedPushbackLine)
            }
            // Round-39: case-anchored continuation through engine refinement
            // — durability complement to round 37. Fires AFTER round 37
            // would have fired and a subsequent engine-only refinement
            // post-dated the user's confirmation. Mutually exclusive with
            // BOTH round 37 (opposite latest-entry-nature gate) and round
            // 38 (opposite ack-confidence gate) at the predicate level, so
            // at most ONE of the three case-state lines (37/38/39) fires
            // per chat reply. The 9-line cap on this block is preserved:
            // worst case (5 base intervention lines + 1 round-37/38/39
            // line + 2 round-32 verdict lines) = 8, under cap; AND in the
            // round-39 firing state, round 32 is dark BY CONSTRUCTION
            // (round 32 requires `last.documentsUserPushback`, round 39
            // requires `!last.documentsUserPushback`), so the worst case
            // in the round-39 branch is 6, well under cap.
            if let continuationLine = caseAnchoredContinuationContextLine(
                memory: memory,
                now: memory.updatedAt
            ) {
                lines.append(continuationLine)
            }
            // Round-40: under-pushback continuation through engine
            // refinement — dampening-durability complement to round 38,
            // the `.rejected`-branch symmetric mirror of round 39. Fires
            // AFTER round 38 would have fired and a subsequent engine-
            // only refinement post-dated the user's rejection. The four
            // case-state predicates (37/38/39/40) now form one closed
            // 2×2 matrix on (ack confidence) × (latest entry's nature)
            // and are pairwise mutually exclusive at the predicate
            // level, so at most ONE of the four case-state lines fires
            // per chat reply. The 9-line cap on this block is preserved:
            // worst case (5 base intervention lines + 1 round-37/38/
            // 39/40 line + 2 round-32 verdict lines) = 8, under cap; AND
            // in the round-40 firing state, round 32 is dark BY
            // CONSTRUCTION (round 32 requires
            // `last.documentsUserPushback`, round 40 requires
            // `!last.documentsUserPushback`), so the worst case in the
            // round-40 branch is 6, well under cap.
            if let underPushbackContinuationLine = interventionUnderPushbackContinuationContextLine(
                memory: memory,
                now: memory.updatedAt
            ) {
                lines.append(underPushbackContinuationLine)
            }
        }

        // Three-tier course-change surface, most-specific first:
        //
        //   1. Round 32 — `rebuildVerdictContextLines`. Fires when the
        //      latest pushback rebuild has been ACKNOWLEDGED by the user
        //      via the round-30 follow-up chip row (the ack post-dates the
        //      rebuild AND still applies to the current hypothesis). Names
        //      the rebuild AND the user's verdict on it in one block.
        //   2. Round 31 — `freshRevisedReadContextLines`. Fires when the
        //      latest pushback rebuild is fresh against memory.updatedAt
        //      but no verdict has been lodged yet — the window between the
        //      rebuild folding in and the user tapping a chip. Same case-
        //      state phrasing, different coach-move (leave room to settle).
        //   3. Generic — `"Last course change: ..."`. Fires when neither
        //      dedicated path applies: engine-only lever shifts (round-19
        //      adaptation lineage), stale pushback rebuilds that aged
        //      past this rep AND were never acknowledged, or rebuilds
        //      whose ack has already been dropped by a later memory
        //      rebuild that rewrote the working hypothesis.
        //
        // The three are mutually exclusive at the memory level: the round-30
        // ack bump that satisfies round 32 also closes round 31's `isFresh`
        // window, so the two dedicated blocks never both fire. The chat
        // context carries one canonical course-change block at any time.
        let verdictLines = rebuildVerdictContextLines(memory: memory)
        if !verdictLines.isEmpty {
            lines.append(contentsOf: verdictLines)
        } else {
            let revisedReadLines = freshRevisedReadContextLines(memory: memory)
            if !revisedReadLines.isEmpty {
                lines.append(contentsOf: revisedReadLines)
            } else if let change = memory.adaptationLog?.last {
                lines.append("- Last course change: \(change.reason) (\(change.evidenceBasis)).")
                // Round-33: when the latest course change documents a
                // second-cycle pushback BUT round 31's `isFresh` window has
                // already closed AND round 32's ack is no longer carried,
                // append a one-sentence cycle note so the second-cycle
                // signal survives the rep boundary. The model otherwise
                // sees the entry as "another course change" and loses the
                // repeated-adapt context the engine has already recorded.
                if change.documentsSecondCyclePushback {
                    lines.append("- Repeated-adapt note: the latest course change is a second-cycle pushback — the prior course change was also a user pushback rebuild, so the model should treat the new read as the SECOND adapt, not the first. Avoid re-prescribing identical work and avoid strengthening either prior read until the user weighs in on the new one.")
                }
            }
        }

        return Array(lines.prefix(9))
    }

    /// Short, future-facing phrase for an intervention's review date so the
    /// coach can say "revisit by tomorrow" rather than read out a timestamp.
    static func caseReviewLabel(for date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        if days < 0 { return "now (review overdue)" }
        if days == 0 { return "today" }
        if days == 1 { return "tomorrow" }
        return "in \(days) days"
    }

    private static func evidenceGuidance(for confidence: BaselineConfidence) -> String {
        switch confidence {
        case .insufficient:
            return "treat this as a hypothesis, not a verdict"
        case .tentative:
            return "soften claims and ask one clarifying question when useful"
        case .moderate:
            return "name patterns carefully and tie prescriptions to evidence"
        case .established, .stable:
            return "name repeated patterns directly, but keep the next move specific"
        }
    }

    private static func currentCoachingLever(
        from trends: [SkillTrend],
        profile: CoachingProfile?
    ) -> SkillTrend? {
        let scored = trends.compactMap { trend -> (trend: SkillTrend, score: Int)? in
            let score = coachMemoryScore(for: trend, profile: profile)
            guard score > 0 else { return nil }
            return (trend, score)
        }

        return scored.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.trend.windowSize != rhs.trend.windowSize {
                return lhs.trend.windowSize > rhs.trend.windowSize
            }
            return lhs.trend.skillArea.displayName < rhs.trend.skillArea.displayName
        }.first?.trend
    }

    private static func coachMemoryScore(for trend: SkillTrend, profile: CoachingProfile?) -> Int {
        guard trend.confidence != .low,
              trend.direction != .resolved,
              trend.currentLevel != .strong else { return 0 }

        var score: Int
        switch trend.direction {
        case .newIssue:
            score = 100
        case .declining:
            score = 95
        case .stable:
            score = trend.currentLevel <= .developing ? 70 : 30
        case .improving:
            score = trend.currentLevel <= .developing ? 60 : 25
        case .resolved:
            score = 0
        }

        switch trend.currentLevel {
        case .weak: score += 25
        case .developing: score += 15
        case .solid: score += 5
        case .strong: break
        }

        switch trend.confidence {
        case .high: score += 10
        case .medium: score += 4
        case .low: break
        }

        if profile?.speakingStyleGoal.aligns(with: trend.skillArea) == true {
            score += 8
        }

        return score >= 50 ? score : 0
    }

    private static func memoryEvidencePhrase(for trend: SkillTrend) -> String {
        let core: String
        switch trend.direction {
        case .declining:
            core = "declining from the prior window"
        case .newIssue:
            core = "new issue in the recent window"
        case .stable:
            core = "stable at \(trend.currentLevel.rawValue)"
        case .improving:
            core = "improving but still \(trend.currentLevel.rawValue)"
        case .resolved:
            core = "recently resolved"
        }

        if let delta = trend.recentDelta?.trimmingCharacters(in: .whitespacesAndNewlines),
           !delta.isEmpty {
            return "\(core); \(delta)"
        }
        return core
    }

    /// Per-skill direction lines built from `TrendAnalyzer` output. Only
    /// high-signal trends survive — low-confidence reads are dropped so
    /// the coach never quotes a "declining" signal that's actually noise.
    /// Hard cap at 4 lines so the section stays scannable. Lines are
    /// pre-formatted noun phrases the caller dashes into TRENDS.
    static func trendDirectionLines(trends: [SkillTrend]) -> [String] {
        let interesting: [TrendDirection] = [.improving, .declining, .newIssue, .resolved]
        let filtered = trends.filter { trend in
            interesting.contains(trend.direction) && trend.confidence != .low
        }
        // Priority order: declining / newIssue first (urgent), then resolved
        // / improving (motivating). Within a band, higher confidence first.
        let urgencyOrder: [TrendDirection] = [.declining, .newIssue, .resolved, .improving]
        let sorted = filtered.sorted { a, b in
            let ai = urgencyOrder.firstIndex(of: a.direction) ?? urgencyOrder.count
            let bi = urgencyOrder.firstIndex(of: b.direction) ?? urgencyOrder.count
            if ai != bi { return ai < bi }
            return a.confidence == .high && b.confidence != .high
        }
        return sorted.prefix(4).map { trend in
            let area = trend.skillArea.displayName.lowercased()
            let phrase: String
            switch trend.direction {
            case .declining: phrase = "\(area) declining"
            case .improving: phrase = "\(area) improving"
            case .newIssue:  phrase = "\(area) just became an issue"
            case .resolved:  phrase = "\(area) resolved"
            case .stable:    phrase = "\(area) stable"
            }
            if let delta = trend.recentDelta, !delta.isEmpty {
                return "\(phrase) (\(delta))"
            }
            return phrase
        }
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
