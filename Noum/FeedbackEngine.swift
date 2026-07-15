import Foundation

// MARK: - Coach Note

/// The three-part feedback structure shown after every session.
struct CoachNote {
    let momentum: String      // What is getting stronger
    let leverage: String      // What is currently holding the user back
    let nextStep: String      // What to do about it
}

// MARK: - IM Context Fit

/// Context-fit data for IM (interview/meeting) sessions.
/// Captures how well the user's response fit the conversational scenario.
struct IMContextFit {
    let scenarioName: String      // e.g. "Executive briefing", "Team standup"
    let targetTone: String        // e.g. "Concise and direct", "Warm and collaborative"
    let relevanceScore: Double    // 0–1, how on-topic the response was
    let naturalness: Double       // 0–1, how natural/conversational it sounded
    let trustBuilding: Double     // 0–1, how well it built rapport/credibility
}

// MARK: - Style Trait Mapping

/// Maps a user's stated style goal to measurable communication traits.
enum StyleTraitMapping {
    struct StyleTrait {
        let name: String                 // e.g. "decisiveness"
        let evaluationHint: String       // What to look for in the session
    }

    /// Returns the traits associated with a style goal.
    static func traits(for goal: String) -> [StyleTrait] {
        let lowered = goal.lowercased()

        if lowered.contains("authoritative") || lowered.contains("authority") || lowered.contains("commanding") {
            return [
                StyleTrait(name: "Decisiveness", evaluationHint: "Low hedging, strong declarative statements, no trailing-off"),
                StyleTrait(name: "Strong openings", evaluationHint: "Confident first sentence, no preamble or apology"),
                StyleTrait(name: "Deliberate pacing", evaluationHint: "Controlled pace, strategic pauses before key points"),
                StyleTrait(name: "Clear phrasing", evaluationHint: "Direct language, minimal qualifiers"),
            ]
        }

        if lowered.contains("warm") || lowered.contains("approachable") || lowered.contains("friendly") {
            return [
                StyleTrait(name: "Conversational rhythm", evaluationHint: "Natural pace variation, occasional rhetorical questions"),
                StyleTrait(name: "Inclusive language", evaluationHint: "Uses 'we', acknowledges others' perspectives"),
                StyleTrait(name: "Story elements", evaluationHint: "Personal anecdotes or relatable examples"),
                StyleTrait(name: "Positive framing", evaluationHint: "Focuses on solutions and opportunities"),
            ]
        }

        if lowered.contains("concise") || lowered.contains("crisp") || lowered.contains("efficient") {
            return [
                StyleTrait(name: "Brevity", evaluationHint: "Short duration relative to content, no redundancy"),
                StyleTrait(name: "Lead with conclusion", evaluationHint: "Main point stated first, then supporting detail"),
                StyleTrait(name: "Minimal filler", evaluationHint: "Very low filler rate, no hedge phrases"),
                StyleTrait(name: "Clean transitions", evaluationHint: "No verbal clutter between ideas"),
            ]
        }

        if lowered.contains("persuasive") || lowered.contains("compelling") || lowered.contains("influential") {
            return [
                StyleTrait(name: "Structured argument", evaluationHint: "Clear claim → evidence → implication flow"),
                StyleTrait(name: "Vocal emphasis", evaluationHint: "Key words emphasized, variation in energy"),
                StyleTrait(name: "Confident delivery", evaluationHint: "No hedging, deliberate pacing on key claims"),
                StyleTrait(name: "Strong close", evaluationHint: "Call to action or memorable final statement"),
            ]
        }

        if lowered.contains("thoughtful") || lowered.contains("measured") || lowered.contains("analytical") {
            return [
                StyleTrait(name: "Considered pacing", evaluationHint: "Deliberate speed, pauses after complex points"),
                StyleTrait(name: "Depth over breadth", evaluationHint: "Fewer points developed thoroughly rather than many points skimmed"),
                StyleTrait(name: "Nuance", evaluationHint: "Acknowledges complexity, avoids oversimplification"),
                StyleTrait(name: "Evidence-based", evaluationHint: "References data, examples, or reasoning"),
            ]
        }

        // Default: general improvement traits
        return [
            StyleTrait(name: "Clarity", evaluationHint: "Clear, understandable delivery"),
            StyleTrait(name: "Confidence", evaluationHint: "Committed delivery without excessive hedging"),
        ]
    }
}

// MARK: - Confidence Phrasing

/// Wraps feedback text with appropriate certainty framing based on baseline confidence.
enum ConfidencePhrasing {

    /// Frame a statement based on how much data backs it up.
    static func frame(_ statement: String, confidence: BaselineConfidence) -> String {
        switch confidence {
        case .insufficient:
            return "Early signal: \(statement)"
        case .tentative:
            return "Initial read: \(statement)"
        case .moderate:
            return statement  // No framing needed — moderate confidence is the default
        case .established:
            return "Consistent pattern: \(statement)"
        case .stable:
            return "Well-established: \(statement)"
        }
    }

    /// Frame a comparison against baseline.
    static func comparison(_ dimension: String, sessionValue: String, baselineValue: String, direction: String, confidence: BaselineConfidence) -> String {
        switch confidence {
        case .insufficient, .tentative:
            return "\(dimension): \(sessionValue) (still building your baseline)"
        case .moderate:
            return "\(dimension): \(sessionValue) (\(direction) your emerging baseline of \(baselineValue))"
        case .established, .stable:
            return "\(dimension): \(sessionValue) (\(direction) your baseline of \(baselineValue))"
        }
    }
}

// MARK: - Verdict Engine

/// Generates tone-aware, trend-informed feedback following the momentum/leverage/next-step pattern.
enum VerdictEngine {

    /// Generate a coach note from the current session and trend data.
    ///
    /// The baseline/pressure/style parameters are optional — when provided, feedback
    /// references the user's historical patterns (Layer 1), IM context-fit (Layer 2),
    /// prompt-grounded relevance for prompt-answering modes (Layer 2b), and style
    /// goal alignment (Layer 3).
    ///
    /// `promptRelevance` (Layer 2b) is the initiative-#8 `PromptRelevanceRead` —
    /// the SAME read the 7-dimension Relevance rating + both AI surfaces consume.
    /// Threaded here so the Timed three-part note shares one "answered vs buried"
    /// substance read with every other surface instead of carrying none. It only
    /// ever softens the leverage line on a clear miss; it never moves the score.
    static func generate(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        wpm: Double,
        score: Int,
        categoryRatings: [String: String],
        trends: [SkillTrend],
        primaryFocus: SkillArea,
        drillHistory: [DrillHistoryStore.Entry],
        baseline: CommunicationBaseline? = nil,
        pressureProfile: PressureProfile? = nil,
        pressureLevel: PressureLevel = .standard,
        styleGoal: String? = nil,
        imContext: IMContextFit? = nil,
        promptRelevance: PracticeEvaluator.PromptRelevanceRead? = nil
    ) -> CoachNote {
        let confidence = baseline?.overallConfidence ?? .insufficient

        var momentum = buildMomentum(
            fillerCount: fillerCount,
            wpm: wpm,
            score: score,
            categoryRatings: categoryRatings,
            trends: trends,
            drillHistory: drillHistory
        )

        var leverage = buildLeverage(
            primaryFocus: primaryFocus,
            fillerCount: fillerCount,
            wpm: wpm,
            duration: duration,
            wordCount: wordCount,
            categoryRatings: categoryRatings,
            trends: trends
        )

        var nextStep = buildNextStep(primaryFocus: primaryFocus, trends: trends)

        // --- Layer 1 Enhancement: Baseline-referenced feedback ---
        if let baseline, baseline.overallConfidence >= .moderate {
            momentum = enrichWithBaseline(momentum, fillerCount: fillerCount, wpm: wpm, duration: duration, baseline: baseline, confidence: confidence)
            leverage = enrichLeverageWithBaseline(leverage, fillerCount: fillerCount, wpm: wpm, duration: duration, baseline: baseline, confidence: confidence)
        }

        // --- Layer 2: IM context-fit ---
        if let imContext {
            let contextNote = buildIMContextNote(imContext: imContext)
            if !contextNote.isEmpty {
                leverage = leverage + " " + contextNote
            }
        }

        // --- Layer 2b: prompt-grounded relevance (Timed three-part note) ---
        // The IM context note above judges relevance for IM role-plays; this
        // is its analog for prompt-answering modes (Timed), reading the SAME
        // `PromptRelevanceRead` the 7-dimension Relevance rating and all the AI
        // surfaces consume (initiative #8, made positional in #10). Fires ONLY
        // on a genuine buried lede (`.buried` = point present across the rep but
        // missing from the lead) so a buried point gets one constructive nudge
        // while an answer that led with the point — or one that merely engaged
        // the question loosely — gets nothing. Never a confident "off-topic"
        // verdict, and never a down-talk on weak/absent evidence (the read
        // returns nil below its floor). Skipped when an IM context note has
        // already spoken to relevance, so the two never double up.
        if imContext == nil, let promptRelevance {
            let relevanceNote = buildPromptRelevanceNote(read: promptRelevance)
            if !relevanceNote.isEmpty {
                leverage = leverage + " " + relevanceNote
            }
        }

        // --- Layer 3: Style lens ---
        // Three-sided: celebrate gains that move the user toward their chosen
        // voice (momentum), connect the leverage and next-step to the voice
        // when the primary focus is goal-aligned, and surface the one
        // trait-mismatch worth fixing (style note → nextStep). All fire
        // independently — a session can win on an aligned skill, have a
        // separate aligned leverage area, and miss on a different trait.
        if let goal = styleGoal, !goal.isEmpty {
            momentum = enrichMomentumWithStyleAlignment(momentum, trends: trends, styleGoal: goal)
            leverage = enrichLeverageWithStyleAlignment(leverage, primaryFocus: primaryFocus, styleGoal: goal)
            nextStep = enrichNextStepWithStyleAlignment(nextStep, primaryFocus: primaryFocus, styleGoal: goal)
            let styleNote = buildStyleNote(goal: goal, fillerCount: fillerCount, wpm: wpm, duration: duration, categoryRatings: categoryRatings)
            if !styleNote.isEmpty {
                nextStep = nextStep + " " + styleNote
            }
        }

        // --- Pressure context ---
        if pressureLevel >= .elevated, let pressure = pressureProfile,
           let resilience = pressure.pressureResilience, resilience < 0.7 {
            momentum = momentum + " (This was a high-pressure session — any gains here carry extra weight.)"
        }

        return CoachNote(momentum: momentum, leverage: leverage, nextStep: nextStep)
    }

    // MARK: - Momentum (What's Getting Stronger)

    private static func buildMomentum(
        fillerCount: Int,
        wpm: Double,
        score: Int,
        categoryRatings: [String: String],
        trends: [SkillTrend],
        drillHistory: [DrillHistoryStore.Entry]
    ) -> String {
        var strengths: [String] = []

        // Check for improving trends
        for trend in trends where trend.direction == .improving {
            switch trend.skillArea {
            case .fillerReduction:
                if let delta = trend.recentDelta {
                    strengths.append(delta)
                } else {
                    strengths.append("Your filler word control is getting stronger.")
                }
            case .paceControl:
                strengths.append("Your pace is becoming more controlled.")
            case .openingStrength:
                strengths.append("Your openings are getting more confident.")
            case .closingStrength:
                strengths.append("Your closings are landing more deliberately.")
            case .structure:
                strengths.append("Your answer structure is tightening up.")
            case .answerDevelopment:
                strengths.append("You're developing your ideas more fully.")
            default:
                strengths.append("Your \(trend.skillArea.displayName.lowercased()) is improving.")
            }
        }

        // Check for strong areas in this session
        if fillerCount == 0 && !strengths.contains(where: { $0.contains("filler") }) {
            strengths.append("Zero filler words — clean delivery.")
        }
        if ConversationalPaceBand.contains(wpm) && !strengths.contains(where: { $0.contains("pace") }) {
            strengths.append("Natural, well-controlled pace.")
        }

        // Check strong category ratings
        let strongDimensions = categoryRatings.filter { $0.value == "Good" }.map(\.key)
        if strongDimensions.count >= 3 && strengths.isEmpty {
            strengths.append("Solid performance across \(strongDimensions.prefix(2).joined(separator: " and ").lowercased()).")
        }

        // Check drill streaks
        if let lastSkill = drillHistory.first?.skillArea {
            let streak = drillHistory.prefix(while: { $0.skillArea == lastSkill && $0.succeeded }).count
            if streak >= 3 {
                strengths.insert("\(lastSkill.displayName) is becoming second nature — \(streak) successful drills in a row.", at: 0)
            }
        }

        // Fallback — always find something
        if strengths.isEmpty {
            if score >= 7 {
                strengths.append("Solid session overall — you showed control and intention.")
            } else if score >= 5 {
                strengths.append("You showed up and practiced — that's the foundation everything else builds on.")
            } else {
                strengths.append("Every session builds the habit. The fact that you're here matters.")
            }
        }

        return strengths.prefix(2).joined(separator: " ")
    }

    // MARK: - Leverage (What's Holding You Back)

    private static func buildLeverage(
        primaryFocus: SkillArea,
        fillerCount: Int,
        wpm: Double,
        duration: TimeInterval,
        wordCount: Int,
        categoryRatings: [String: String],
        trends: [SkillTrend]
    ) -> String {
        let sensitivity = primaryFocus.feedbackSensitivity
        let trend = trends.first(where: { $0.skillArea == primaryFocus })

        switch primaryFocus {
        case .fillerReduction:
            return fillerLeverage(count: fillerCount, sensitivity: sensitivity, trend: trend)
        case .paceControl:
            return paceLeverage(wpm: wpm, sensitivity: sensitivity)
        case .openingStrength:
            return "Your opening is the biggest opportunity right now — a strong first sentence sets the tone for everything after."
        case .closingStrength:
            return "Your answer trailed off instead of ending with intention. A deliberate close is what people remember."
        case .structure:
            return "Your ideas ran together without clear structure. A simple framework makes even impromptu answers feel prepared."
        case .answerDevelopment:
            if duration < 15 {
                return "Your answer was only \(Int(duration)) seconds — too short to develop any real depth."
            }
            return "Your answer stayed surface-level. One well-developed idea with a specific example beats three shallow points."
        case .conciseSpeaking:
            if duration > 120 {
                return "Your answer ran long at \(Int(duration)) seconds. Being concise means finding the core of what you want to say."
            }
            return "Your delivery could be tighter. Try leading with your conclusion and cutting anything that doesn't directly support it."
        case .pauseUsage:
            return "Your delivery could use more breathing room. Deliberate pauses make your points land harder."
        case .vocalEmphasis:
            return "Your delivery was steady but flat. Varying your emphasis on key words makes your message more compelling."
        case .confidence:
            return "Your delivery had hedge words or hesitation that softened your authority. Committing to each statement changes how you're perceived."
        }
    }

    private static func fillerLeverage(count: Int, sensitivity: FeedbackSensitivity, trend: SkillTrend?) -> String {
        // Gentle framing for filler words — this is anxiety-adjacent
        if let trend, trend.direction == .improving {
            return "Fillers are still above target at \(count), but they've been coming down — you're moving in the right direction. The next drill can push this further."
        }

        if count >= 8 {
            return "\(count) filler words this session. This is common when your brain is working faster than your mouth — the fix is learning to pause instead of fill."
        } else if count >= 5 {
            return "\(count) filler words — most appeared at transition points between ideas. These are trainable moments."
        } else {
            return "A few filler words crept in at transition points. They're minor but noticeable."
        }
    }

    private static func paceLeverage(wpm: Double, sensitivity: FeedbackSensitivity) -> String {
        if wpm > ConversationalPaceBand.maxWPM + 20 {
            return "Your pace hit \(Int(wpm)) WPM — noticeably fast. Speed can undermine clarity even when content is strong."
        } else if wpm > ConversationalPaceBand.maxWPM {
            return "Your pace was a bit quick at \(Int(wpm)) WPM. Slowing your start can bring the whole answer into a more natural range."
        } else if wpm < ConversationalPaceBand.minWPM - 20 {
            return "Your pace was \(Int(wpm)) WPM — quite measured. A slightly quicker conversational pace can help your delivery feel more natural."
        } else if wpm < ConversationalPaceBand.minWPM {
            return "Your pace was a touch slow at \(Int(wpm)) WPM. Committing to each sentence before starting it can help maintain flow."
        }
        return "Your pace could be more consistent. Aim for a natural conversational rhythm."
    }

    // MARK: - Next Step

    private static func buildNextStep(primaryFocus: SkillArea, trends: [SkillTrend]) -> String {
        let trend = trends.first(where: { $0.skillArea == primaryFocus })

        // If improving, acknowledge and push forward with skill-specific guidance
        if trend?.direction == .improving {
            switch primaryFocus {
            case .fillerReduction:
                return "Your filler count is dropping. A pause-replacement drill will lock in the new habit."
            case .paceControl:
                return "Your pace is evening out. Try a timed response drill to anchor this rhythm."
            case .openingStrength:
                return "Your openings are getting sharper. Practice leading with a bold first sentence."
            case .closingStrength:
                return "Your closings are getting more deliberate. Drill the callback close to take it further."
            case .structure:
                return "Your structure is tightening. Try a two-point framework drill to push for even cleaner organization."
            case .answerDevelopment:
                return "You're developing ideas more fully. Practice the one-example depth drill to make your points land harder."
            case .conciseSpeaking:
                return "You're getting more concise. Try the 30-second constraint drill to sharpen further."
            case .pauseUsage:
                return "Your pauses are becoming more intentional. Practice placing one emphatic pause per answer."
            case .vocalEmphasis:
                return "Your emphasis is improving. Try varying tone on your opening and closing lines."
            case .confidence:
                return "Your delivery confidence is growing. Practice committing to declarative statements without softeners."
            }
        }

        // If new issue, be reassuring with skill-specific context
        if trend?.direction == .newIssue {
            switch primaryFocus {
            case .fillerReduction:
                return "Fillers just spiked — likely a one-off. A quick pause drill can reset the pattern."
            case .paceControl:
                return "Pace was off this session. A short pacing drill can bring it back to your range."
            case .openingStrength:
                return "Your opening was weaker than usual. Lead with your strongest point next time."
            case .structure:
                return "Structure slipped — try a framework drill to reset your defaults."
            case .answerDevelopment:
                return "Your depth dropped this session. One detailed-example drill can get it back on track."
            default:
                return "Your \(primaryFocus.displayName.lowercased()) dipped — a quick drill can reset it before it becomes a pattern."
            }
        }

        // Default: skill-specific call to action
        switch primaryFocus {
        case .fillerReduction:
            return "A filler-replacement drill is the best next move — swap each filler moment for a pause."
        case .paceControl:
            return "A pacing drill will help — practice finding your natural conversational speed."
        case .openingStrength:
            return "Practice your opening line before you start — a strong first sentence changes everything."
        case .closingStrength:
            return "Try ending your next answer with a single clear takeaway statement."
        case .structure:
            return "Try a framework drill — even a simple 'point, example, takeaway' structure makes a difference."
        case .answerDevelopment:
            return "Practice developing one idea fully before moving to the next."
        case .conciseSpeaking:
            return "Try the constraint drill — deliver your message in half the words you normally would."
        case .pauseUsage:
            return "In your next session, place one deliberate pause after your opening sentence."
        case .vocalEmphasis:
            return "Try emphasizing just two or three key words in your next answer."
        case .confidence:
            return "Replace one hedge phrase with a direct statement in your next session."
        }
    }

    // MARK: - Baseline-Enhanced Feedback (Layer 1)

    /// Enriches momentum text with baseline comparisons where available.
    private static func enrichWithBaseline(
        _ momentum: String,
        fillerCount: Int,
        wpm: Double,
        duration: TimeInterval,
        baseline: CommunicationBaseline,
        confidence: BaselineConfidence
    ) -> String {
        var additions: [String] = []

        // Filler rate vs baseline
        if baseline.fillerRate.isReliable && duration > 0 {
            let sessionRate = Double(fillerCount) / (duration / 60.0)
            let delta = sessionRate - baseline.fillerRate.value
            if delta < -0.5 {
                additions.append(ConfidencePhrasing.frame(
                    "Filler rate dropped to \(String(format: "%.1f", sessionRate))/min — below your baseline of \(String(format: "%.1f", baseline.fillerRate.value))/min.",
                    confidence: confidence
                ))
            }
        }

        // Pace vs baseline
        if baseline.pace.isReliable {
            if wpm >= baseline.pace.percentile25 && wpm <= baseline.pace.percentile75 {
                additions.append("Pace held steady at \(Int(wpm)) WPM — right in your zone.")
            }
        }

        if additions.isEmpty {
            return momentum
        }
        return momentum + " " + additions.joined(separator: " ")
    }

    /// Enriches leverage text with baseline comparisons.
    private static func enrichLeverageWithBaseline(
        _ leverage: String,
        fillerCount: Int,
        wpm: Double,
        duration: TimeInterval,
        baseline: CommunicationBaseline,
        confidence: BaselineConfidence
    ) -> String {
        // Compare session filler *rate* against baseline filler *rate* (both per minute)
        if baseline.fillerRate.isReliable, fillerCount > 0, duration > 0 {
            let sessionRate = Double(fillerCount) / (duration / 60.0)
            if sessionRate > baseline.fillerRate.value + 0.5 {
                return leverage + " " + ConfidencePhrasing.frame(
                    "Your filler rate this session was \(String(format: "%.1f", sessionRate))/min — above your usual \(String(format: "%.1f", baseline.fillerRate.value))/min.",
                    confidence: confidence
                )
            }
        }

        // If hedging is a known issue
        if baseline.hedgingRate.isReliable && baseline.hedgingRate.value > 3.0 {
            return leverage + " Watch for hedge phrases too — they've been a recurring pattern."
        }

        return leverage
    }

    // MARK: - IM Context-Fit (Layer 2)

    /// Generates context-fit feedback for IM sessions.
    private static func buildIMContextNote(imContext: IMContextFit) -> String {
        var notes: [String] = []

        if imContext.relevanceScore < 0.5 {
            notes.append("Your response drifted from the \(imContext.scenarioName.lowercased()) context — staying on-topic builds credibility.")
        }

        if imContext.naturalness < 0.5 {
            notes.append("The delivery felt rehearsed — aim for a more conversational tone, especially in a \(imContext.scenarioName.lowercased()) setting.")
        }

        if imContext.trustBuilding < 0.5 && imContext.targetTone.lowercased().contains("collaborative") {
            notes.append("The tone didn't build rapport — try acknowledging the other perspective before stating your position.")
        }

        return notes.prefix(1).joined()
    }

    // MARK: - Prompt-Grounded Relevance (Layer 2b)

    /// Prompt-grounded relevance note for the Timed three-part coach note.
    /// Mirrors `buildIMContextNote`'s single-note, miss-only shape: it fires
    /// ONLY when the shared POSITIONAL read lands on `.buried` — the point was
    /// present across the rep but missing from the lead (a buried lede) — and
    /// it frames the move (lead with the point) rather than asserting the answer
    /// was off-topic. Returns "" (no note) on `.answered`, `.partial`, or below
    /// the evidence floor, so the leverage line is never cluttered, never
    /// down-talks weak evidence, and never fires on an answer that merely
    /// engaged the question loosely. Reads the SAME
    /// `PracticeEvaluator.promptAnswerVerdict` mapping the chat coach reads, so
    /// the post-rep note and the live coach can't disagree. The copy is honest
    /// by construction: `.buried` already proved the point is in there.
    private static func buildPromptRelevanceNote(read: PracticeEvaluator.PromptRelevanceRead) -> String {
        guard PracticeEvaluator.promptAnswerVerdict(for: read) == .buried else { return "" }
        return "Your main point was in there but arrived late — leading with it in the first sentence keeps the answer anchored to the question."
    }

    // MARK: - Style Lens (Layer 3)

    /// Generates style-aligned next step guidance.
    private static func buildStyleNote(
        goal: String,
        fillerCount: Int,
        wpm: Double,
        duration: TimeInterval,
        categoryRatings: [String: String]
    ) -> String {
        let traits = StyleTraitMapping.traits(for: goal)
        guard !traits.isEmpty else { return "" }

        // Check if the session aligns or misaligns with the style goal
        var mismatches: [String] = []

        for trait in traits {
            let hint = trait.evaluationHint.lowercased()
            if hint.contains("low hedging") || hint.contains("minimal filler") {
                if FillerBurden(fillerCount: fillerCount, duration: duration).meets(.urgent) {
                    mismatches.append("Your \(goal.lowercased()) goal needs fewer fillers — they undercut \(trait.name.lowercased()).")
                    break
                }
            }
            if hint.contains("brevity") || hint.contains("short duration") {
                if duration > 120 {
                    mismatches.append("For a \(goal.lowercased()) style, aim for shorter, tighter responses.")
                    break
                }
            }
            if hint.contains("strong opening") || hint.contains("confident first") {
                if categoryRatings["Opening"] == "Could improve" {
                    mismatches.append("Your \(goal.lowercased()) goal starts with a stronger opening — lead with conviction.")
                    break
                }
            }
            if hint.contains("strong close") || hint.contains("call to action") {
                if categoryRatings["Close"] == "Could improve" {
                    mismatches.append("End with impact — a \(goal.lowercased()) communicator closes deliberately.")
                    break
                }
            }
        }

        return mismatches.first ?? ""
    }

    /// Appends a goal-celebrating clause to the momentum line when at least one
    /// improving trend lands in the user's `SpeakingStyleGoal.alignedSkillAreas`.
    ///
    /// This is the post-session counterpart to `VoiceAnchorBanner` (pre-session)
    /// and the goal-aware `LiveEloquenceHUD` chip (mid-session) — together they
    /// make every M14 surface speak the user's chosen voice. The Coach Note's
    /// momentum line is the highest-leverage post-session feedback surface, so
    /// goal-alignment praise lives here rather than in a separate card.
    ///
    /// Restraint: only fires when there's a real improving trend AND it maps
    /// onto an aligned skill area for the goal. No fake personalization; no
    /// generic "moving toward your voice" suffix when nothing actually moved.
    private static func enrichMomentumWithStyleAlignment(
        _ momentum: String,
        trends: [SkillTrend],
        styleGoal: String
    ) -> String {
        guard let resolved = SpeakingStyleGoal.resolve(styleGoal) else { return momentum }
        let aligned = resolved.alignedSkillAreas
        guard !aligned.isEmpty else { return momentum }

        // Find the first improving trend whose skill is on the goal's lever
        // list. `buildMomentum` already names the specific skill ("Your pace
        // is becoming more controlled."); this clause adds the voice-goal
        // frame on top, without repeating the skill name.
        let alignedImprovement = trends.first { trend in
            trend.direction == .improving && aligned.contains(trend.skillArea)
        }
        guard alignedImprovement != nil else { return momentum }

        let voiceLabel = resolved.shortVoiceLabel
        let clause = "That's the work your \(voiceLabel) depends on."
        return momentum + " " + clause
    }

    /// Appends a positive voice-alignment frame to the leverage line when
    /// the session's `primaryFocus` skill is one of the user's voice-aligned
    /// levers. Pairs with `enrichMomentumWithStyleAlignment` and
    /// `enrichNextStepWithStyleAlignment` to close the goal-aware loop on
    /// every Coach Note line (M14).
    ///
    /// Restraint: only fires when the focus is in `alignedSkillAreas`.
    /// Off-goal weaknesses don't get a voice clause — the brand rule is
    /// "no fake personalization." Reframing an off-goal leverage as
    /// voice-relevant would invent meaning the data doesn't support and
    /// risks reading as shaming ("your authoritative voice is being
    /// undercut by paceControl"). When the focus aligns, the clause names
    /// the voice as the *upside* of working that lever — not the cost of
    /// missing it.
    private static func enrichLeverageWithStyleAlignment(
        _ leverage: String,
        primaryFocus: SkillArea,
        styleGoal: String
    ) -> String {
        guard let resolved = SpeakingStyleGoal.resolve(styleGoal) else { return leverage }
        guard resolved.aligns(with: primaryFocus) else { return leverage }
        let voiceLabel = resolved.shortVoiceLabel
        let clause = "These are the moves that build your \(voiceLabel)."
        return leverage + " " + clause
    }

    /// Appends a positive voice-alignment frame to the next-step line when
    /// the recommended drill targets a voice-aligned skill. Frames the
    /// suggested action as direct work toward the user's chosen voice, so
    /// the post-rep "what to do next" line reinforces the same voice the
    /// home recommendation chip, the looking-ahead card, and the drill
    /// picker all reference.
    ///
    /// Same restraint contract as the leverage and momentum helpers — no
    /// voice clause on off-goal next steps. Drills on non-aligned skills
    /// are still valid coaching, they just don't get personalized framing.
    private static func enrichNextStepWithStyleAlignment(
        _ nextStep: String,
        primaryFocus: SkillArea,
        styleGoal: String
    ) -> String {
        guard let resolved = SpeakingStyleGoal.resolve(styleGoal) else { return nextStep }
        guard resolved.aligns(with: primaryFocus) else { return nextStep }
        let voiceLabel = resolved.shortVoiceLabel
        let clause = "This is direct work on your \(voiceLabel)."
        return nextStep + " " + clause
    }

    // MARK: - Dynamic Drill Rationale

    /// Generate a session-specific rationale for why this drill was selected.
    /// This is NOT a static template — it uses the session's actual data.
    ///
    /// `styleGoal` (optional) lets the rationale close on a voice-alignment
    /// clause when the drill's skill is one of the goal's aligned levers —
    /// keeping the drill's "why this" line in sync with the voice the rest
    /// of the M14 surfaces speak. Restraint: only fires on alignment, never
    /// invents a voice tie-in for off-goal drills.
    static func drillRationale(
        for skillArea: SkillArea,
        fillerCount: Int,
        wpm: Double,
        duration: TimeInterval,
        wordCount: Int,
        categoryRatings: [String: String],
        styleGoal: SpeakingStyleGoal? = nil,
        fillerEvidenceQualified: Bool = true,
        paceEvidenceQualified: Bool = true
    ) -> String {
        let base = baseDrillRationale(
            for: skillArea,
            fillerCount: fillerCount,
            wpm: wpm,
            duration: duration,
            wordCount: wordCount,
            categoryRatings: categoryRatings,
            fillerEvidenceQualified: fillerEvidenceQualified,
            paceEvidenceQualified: paceEvidenceQualified
        )

        guard let styleGoal, styleGoal.aligns(with: skillArea) else { return base }
        return base + " This drill targets the foundation of your \(styleGoal.shortVoiceLabel)."
    }

    /// Pure switch over the session metrics — the goal-agnostic copy. Split
    /// out from `drillRationale` so the voice-alignment suffix is the only
    /// goal-aware branch and the cases stay easy to read.
    private static func baseDrillRationale(
        for skillArea: SkillArea,
        fillerCount: Int,
        wpm: Double,
        duration: TimeInterval,
        wordCount: Int,
        categoryRatings: [String: String],
        fillerEvidenceQualified: Bool,
        paceEvidenceQualified: Bool
    ) -> String {
        switch skillArea {
        case .fillerReduction:
            guard fillerEvidenceQualified else {
                return "This drill builds cleaner transitions by replacing verbal placeholders with deliberate pauses."
            }
            let fillerBurden = FillerBurden(fillerCount: fillerCount, duration: duration)
            if fillerBurden.meets(.severe) {
                return "You used \(fillerCount) filler words — they clustered at transition points before the next idea was ready."
            } else if fillerBurden.meets(.urgent) {
                return "You used \(fillerCount) filler words this session. Most speakers can cut these significantly with focused practice."
            } else {
                return "You had \(fillerCount) filler words — they appeared between ideas and made transitions less clean."
            }

        case .openingStrength:
            // M14: real-device feedback asked us to back up the claim with
            // reasoning, not just assert it. The opening signal lives in
            // the first ~12s of the rep — filler density there + how
            // declarative the first sentence reads. We can cite the
            // observable data point (filler count) without pretending we
            // analysed prosody on the opening specifically.
            if fillerEvidenceQualified && fillerCount >= 3 && duration >= 15 {
                return "Your opening didn't land — \(fillerCount) fillers in the first stretch made the start sound uncertain. The first sentence is where listeners decide whether to lean in."
            }
            return "Your opening didn't land — the first sentence read tentative rather than declarative. Listeners decide whether to lean in inside the first eight seconds."

        case .closingStrength:
            // M14: same reasoning treatment as openingStrength.
            if duration < 18 {
                return "Your close trailed off — at \(Int(duration))s the rep ended before the answer could resolve. A strong close is what stays with the listener."
            }
            return "Your close trailed off rather than ending with conviction. The last sentence is what listeners walk away repeating — make it land."

        case .paceControl:
            guard paceEvidenceQualified else {
                return "This drill builds a steadier conversational rhythm so key ideas have room to land."
            }
            if wpm > ConversationalPaceBand.maxWPM {
                return "Your pace hit \(Int(wpm)) WPM — faster than conversational. Slowing down makes you sound more in control."
            } else if wpm < ConversationalPaceBand.minWPM && duration >= 15 {
                return "Your pace was \(Int(wpm)) WPM — hesitant delivery can undermine strong content."
            }
            return "Your pace wasn't in the natural conversational range. Steady rhythm signals confidence."

        case .structure:
            return "Your answer didn't have clear sections. Without structure, even good ideas blur together."

        case .answerDevelopment:
            if duration < 15 {
                return "Your answer was only \(Int(duration)) seconds — too short to develop any real point."
            }
            return "Your content stayed surface-level. Adding one specific example makes the difference."

        case .conciseSpeaking:
            if wordCount > 300 {
                return "You used \(wordCount) words — more than needed. Finding the core of your message is the skill."
            }
            return "Your delivery could be tighter. Lead with the conclusion, then support it."

        case .pauseUsage:
            return "Your delivery had no deliberate pauses. Pauses create emphasis and give the listener time to absorb."

        case .vocalEmphasis:
            return "Your delivery was consistent but lacked emphasis. Varying your tone on key words makes ideas stick."

        case .confidence:
            return "Some hedge words or hesitation softened your authority. Committing to each statement changes perception."
        }
    }
}

// MARK: - Drill Recommendation Engine (v2)

/// The upgraded drill engine that uses both session metrics and trend data.
enum DrillEngineV2 {

    /// Generate a drill recommendation using session data + cross-session trends.
    /// When `targetArea` is provided, the engine skips its own focus determination
    /// and drills into the requested skill area directly.
    ///
    /// `styleGoal` (optional) lets the focus picker prefer skills aligned with
    /// the user's stated voice goal when candidates are otherwise tied — see
    /// `TrendAnalyzer.primaryFocus` for the bias contract. Ignored when
    /// `targetArea` is set (the caller already picked the skill).
    static func recommend(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        score: Int,
        feedbackCategories: [(dimension: String, rating: String)],
        targetArea: SkillArea? = nil,
        styleGoal: SpeakingStyleGoal? = nil,
        trendOverride: [SkillTrend]? = nil,
        trendStore: SkillTrendStore = .shared,
        drillHistory: DrillHistoryStore = .shared,
        transcriptConfidence: Double? = nil,
        comparisonMetricSchemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        isEvaluationFixture: Bool = false
    ) -> DrillRecommendationV2 {
        let wpm = duration > 0 ? Double(wordCount) / duration * 60 : 0
        let isMinimal = wordCount < 5 || duration < 5
        let acceptsComparisonMetrics = comparisonMetricSchemaVersion
            == PracticeSession.currentComparisonMetricSchemaVersion
            && !isEvaluationFixture
        let qualifiedFillerBurden = acceptsComparisonMetrics
            ? FillerBurden.quantityQualified(
                fillerCount: fillerCount,
                duration: duration,
                wordCount: wordCount,
                transcriptConfidence: transcriptConfidence
            )
            : nil
        let qualifiedPaceWPM = acceptsComparisonMetrics
            ? SessionQualifier.quantityQualifiedWordsPerMinute(
                duration: duration,
                wordCount: wordCount,
                transcriptConfidence: transcriptConfidence
            )
            : nil

        // Build category ratings dict
        let categoryRatings = Dictionary(uniqueKeysWithValues: feedbackCategories.map { ($0.dimension, $0.rating) })

        // Get trends
        let trends = trendOverride ?? TrendAnalyzer.analyze(snapshots: trendStore.snapshots)

        // Build a current session snapshot for trend context
        let qualifiedFillerRate = qualifiedFillerBurden?.ratePerMinute
        let sessionSnapshot = SkillSnapshot(
            sessionId: UUID(),
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            wpm: wpm,
            qualifiedFillerRatePerMinute: qualifiedFillerRate,
            qualifiedPaceWPM: qualifiedPaceWPM,
            comparisonMetricSchemaVersion: qualifiedFillerRate != nil && qualifiedPaceWPM != nil
                ? PracticeSession.currentComparisonMetricSchemaVersion
                : nil,
            score: score,
            categoryRatings: categoryRatings
        )

        // Use the caller's target area when provided; otherwise derive from session data
        let focusArea: SkillArea

        if let targetArea {
            focusArea = targetArea
        } else if isMinimal {
            focusArea = .answerDevelopment
        } else {
            focusArea = determineFocus(
                fillerBurden: qualifiedFillerBurden,
                paceWPM: qualifiedPaceWPM,
                duration: duration,
                score: score,
                categoryRatings: categoryRatings,
                trends: trends,
                sessionSnapshot: sessionSnapshot,
                drillHistory: drillHistory,
                styleGoal: styleGoal
            )
        }

        // Select a fresh variation for this skill area
        guard let variation = DrillSelector.select(for: focusArea, history: drillHistory) else {
            // Extreme fallback
            let fallback = DrillCatalog.structureDrills.first!
            return DrillRecommendationV2(
                variation: fallback,
                reason: "Practice with intention — structure your answer clearly.",
                trendContext: nil,
                alternateFormat: nil
            )
        }

        // Generate dynamic rationale — goal-aware when the focus aligns
        // with the user's voice goal (silent otherwise).
        let reason = VerdictEngine.drillRationale(
            for: focusArea,
            fillerCount: fillerCount,
            wpm: wpm,
            duration: duration,
            wordCount: wordCount,
            categoryRatings: categoryRatings,
            styleGoal: styleGoal,
            fillerEvidenceQualified: qualifiedFillerBurden != nil,
            paceEvidenceQualified: qualifiedPaceWPM != nil
        )

        // Get trend context
        let context = TrendAnalyzer.trendContext(for: focusArea, trends: trends)

        // Determine if alternate format should be offered
        let alternate: DrillFormat?
        if score >= 7 && variation.format == .miniDrill {
            alternate = .fullRetry
        } else if variation.format == .fullRetry {
            alternate = .miniDrill
        } else {
            alternate = nil
        }

        return DrillRecommendationV2(
            variation: variation,
            reason: reason,
            trendContext: context,
            alternateFormat: alternate
        )
    }

    // MARK: - Focus Determination

    private static func determineFocus(
        fillerBurden: FillerBurden?,
        paceWPM: Double?,
        duration: TimeInterval,
        score: Int,
        categoryRatings: [String: String],
        trends: [SkillTrend],
        sessionSnapshot: SkillSnapshot,
        drillHistory: DrillHistoryStore,
        styleGoal: SpeakingStyleGoal? = nil
    ) -> SkillArea {
        // First: check if current session has a clear, urgent weakness
        let urgentFocus = urgentSessionFocus(
            fillerBurden: fillerBurden,
            paceWPM: paceWPM,
            duration: duration,
            categoryRatings: categoryRatings
        )

        // If we have trend data, let TrendAnalyzer weigh in
        if !trends.isEmpty {
            let trendFocus = TrendAnalyzer.primaryFocus(
                trends: trends,
                currentSessionSnapshot: sessionSnapshot,
                recentDrills: drillHistory.entries,
                styleGoal: styleGoal
            )

            // If session has an urgent weakness AND trend analysis agrees, use it
            if let urgent = urgentFocus, urgent == trendFocus {
                return urgent
            }

            // If session has an urgent weakness but trend says something else,
            // use session weakness if it's severe, otherwise trust trends
            if let urgent = urgentFocus {
                if fillerBurden?.meets(.severe) == true
                    || duration < 10
                    || paceWPM.map({ $0 > 180 }) == true {
                    return urgent  // Severe session issue overrides trend
                }
                return trendFocus  // Moderate issue — trust the trend analysis
            }

            return trendFocus
        }

        // No trend data — fall back to session-only analysis
        return urgentFocus ?? sessionOnlyFocus(
            fillerBurden: fillerBurden,
            paceWPM: paceWPM,
            duration: duration,
            score: score,
            categoryRatings: categoryRatings,
            styleGoal: styleGoal
        )
    }

    /// Check for urgent single-session weaknesses.
    private static func urgentSessionFocus(
        fillerBurden: FillerBurden?,
        paceWPM: Double?,
        duration: TimeInterval,
        categoryRatings: [String: String]
    ) -> SkillArea? {
        if fillerBurden?.meets(.urgent) == true { return .fillerReduction }
        if duration < 15 { return .answerDevelopment }
        if paceWPM.map({ $0 > ConversationalPaceBand.maxWPM }) == true { return .paceControl }
        if paceWPM.map({ $0 < ConversationalPaceBand.minWPM }) == true && duration >= 15 { return .paceControl }
        if categoryRatings["Opening"] == "Could improve" { return .openingStrength }
        if categoryRatings["Structure"] == "Could improve" { return .structure }
        if categoryRatings["Close"] == "Could improve" { return .closingStrength }
        if categoryRatings["Depth"] == "Could improve" { return .answerDevelopment }
        if fillerBurden?.meets(.elevated) == true { return .fillerReduction }
        return nil
    }

    /// Session-only focus when no trend data exists (new users).
    private static func sessionOnlyFocus(
        fillerBurden: FillerBurden?,
        paceWPM: Double?,
        duration: TimeInterval,
        score: Int,
        categoryRatings: [String: String],
        styleGoal: SpeakingStyleGoal? = nil
    ) -> SkillArea {
        if fillerBurden?.meets(.urgent) == true { return .fillerReduction }
        if duration < 15 { return .answerDevelopment }
        if paceWPM.map({ $0 > ConversationalPaceBand.maxWPM }) == true { return .paceControl }
        if fillerBurden?.meets(.elevated) == true { return .fillerReduction }
        if categoryRatings["Opening"] == "Could improve" { return .openingStrength }
        if categoryRatings["Structure"] == "Could improve" { return .structure }
        if categoryRatings["Close"] == "Could improve" { return .closingStrength }
        if paceWPM.map({ $0 < ConversationalPaceBand.minWPM }) == true && duration >= 15 { return .paceControl }
        if categoryRatings["Depth"] == "Could improve" { return .answerDevelopment }
        // No clear session signal. Prefer the user's stated voice goal over the
        // generic .confidence / .structure defaults — keeps day-one users with
        // a voice on a goal-grounded path from their first drill.
        if let styleGoal { return styleGoal.primaryAlignedSkillArea }
        if score >= 7 { return .confidence }
        return .structure
    }
}
