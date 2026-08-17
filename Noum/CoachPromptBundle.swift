import Foundation

// MARK: - Depth-aware coach prompt bundle

enum CoachPromptBundle {

    static func contextBlock(
        assessment: CoachAssessment,
        rubric: ActiveGoalRubric,
        surface: CoachReplySurface
    ) -> String {
        let plan = CoachReasoningPass.decisionPlan(for: assessment)
        var lines: [String] = []
        lines.append("")
        lines.append("COACH DECISION PLAN (PRIVATE; NEVER EXPOSE THESE LABELS)")
        lines.append("- Situation: \(plan.situation)")
        lines.append("- Stakes: \(plan.stakes)")
        lines.append("- Emotion: \(plan.emotion)")
        lines.append("- Observed behavior: \(plan.observedBehavior)")
        lines.append("- Exact evidence: \(plan.exactEvidence)")
        lines.append("- Skill stage: \(plan.skillStage.rawValue)")
        lines.append("- Chosen intervention: \(plan.chosenIntervention)")
        lines.append("- Success test: \(plan.successTest)")
        lines.append("- Evidence confidence is \(confidenceBand(assessment.confidence)); scale certainty to it.")
        lines.append("- Goal lens: \(rubric.rubric.displayName). This is a training emphasis, not a personality label.")
        if let toneMode = assessment.toneMode {
            lines.append("- Tone mode: \(toneMode.rawValue).")
        }
        if let repairFocus = assessment.repairFocus,
           !repairFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("- Repair focus: \(repairFocus). Acknowledge this before prescribing again.")
        }
        if !assessment.evidenceUsed.isEmpty {
            lines.append("- Evidence to use (translate into spoken behavior; private evidence is not surface copy):")
            for item in assessment.evidenceUsed.prefix(
                evidenceContextLimit(for: assessment.turnDepth)
            ) {
                lines.append("  - \(item)")
            }
        }
        if !assessment.missingEvidence.isEmpty {
            lines.append("- Missing evidence to name only when it answers the ask:")
            for item in assessment.missingEvidence.prefix(3) {
                lines.append("  - \(item)")
            }
        }
        lines.append("- Final action to express as a normal sentence, not a label: \(assessment.nextProofTest)")
        if let modelLine = plan.modelLine {
            lines.append("- Demonstration seed: “\(modelLine)” Adapt the content to the user's situation; preserve the communication move.")
        }
        if let invitation = plan.invitation {
            lines.append("- Invitation: \(invitation)")
        }
        lines.append(contentsOf: metricAuthorizationLines(for: assessment))
        lines.append(contentsOf: responseContractLines(for: plan, surface: surface))
        lines.append(contentsOf: universalCoachLines(surface: surface))
        lines.append(contentsOf: instructionLines(for: assessment.turnDepth, surface: surface))
        return lines.joined(separator: "\n")
    }

    static func generalContextBlock(
        userQuestion: String,
        turnDepth: CoachTurnDepth,
        surface: CoachReplySurface,
        recentMoves: [String] = []
    ) -> String {
        let plan = CoachReasoningPass.generalDecisionPlan(
            userQuestion: userQuestion,
            recentMoves: recentMoves
        )
        var lines = [
            "",
            "COACH DECISION PLAN (PRIVATE; NEVER EXPOSE THESE LABELS)",
            "- Situation: \(plan.situation)",
            "- Stakes: \(plan.stakes)",
            "- Emotion: \(plan.emotion)",
            "- Observed behavior: \(plan.observedBehavior)",
            "- Exact evidence: \(plan.exactEvidence)",
            "- Skill stage: \(plan.skillStage.rawValue)",
            "- Chosen intervention: \(plan.chosenIntervention)",
            "- Success test: \(plan.successTest)",
            "- General-coaching boundary: make the read about the communication problem in the question, never about the user's unobserved performance."
        ]
        if let benchmark = plan.benchmarkAuthorization {
            lines.append("- Generic benchmark authorization: \(benchmark.promptName) only; range \(benchmark.range).")
            lines.append("- Benchmark caveat required: \(benchmark.contextCaveat). Never present the range as an exact rule or imply it measures this user.")
            lines.append("- Personal metric authorization: NONE. Do not invent or recite the user's telemetry.")
        } else {
            lines.append("- Metric authorization: NONE. Do not invent or recite personal telemetry or unsolicited generic benchmarks.")
        }
        if let modelLine = plan.modelLine {
            lines.append("- Demonstration seed: “\(modelLine)” Adapt its content; preserve its communication shape.")
        }
        lines.append(contentsOf: responseContractLines(for: plan, surface: surface))
        lines.append(contentsOf: universalCoachLines(surface: surface))
        lines.append(contentsOf: instructionLines(for: turnDepth, surface: surface))
        return lines.joined(separator: "\n")
    }

    private static func evidenceContextLimit(for depth: CoachTurnDepth) -> Int {
        switch depth {
        case .quickMove: return 2
        case .groundedRead: return 4
        case .deepAssessment, .trustRepair: return 6
        }
    }

    private static func confidenceBand(_ confidence: Double) -> String {
        switch confidence {
        case ..<0.35: return "thin"
        case ..<0.70: return "forming"
        default: return "well supported"
        }
    }

    private static func metricAuthorizationLines(
        for assessment: CoachAssessment
    ) -> [String] {
        guard let requested = assessment.requestedMetrics,
              !requested.isEmpty else {
            return [
                "- Metric authorization: NONE. Do not mention scores, ratings, WPM, filler counts/rates, duration, percentages, or score trends.",
                "- The private evidence may contain telemetry. Use it only to choose the behavioural read; never copy its numbers into the answer."
            ]
        }
        let names = requested.map(\.rawValue).joined(separator: ", ")
        return [
            "- Metric authorization: \(names). Report only these requested metric kinds and no others.",
            "- Answer the requested facts directly, then add at most one plain-language implication. Do not add a drill unless the user asks for one."
        ]
    }

    private static func responseContractLines(
        for plan: CoachDecisionPlan,
        surface: CoachReplySurface
    ) -> [String] {
        switch plan.replyPosture {
        case .presenceOnly:
            return [
                "COACH RESPONSE CONTRACT",
                "- Presence is the complete response: acknowledge what this costs and remove pressure.",
                "- Stop after one or two natural sentences. No diagnosis, drill, metric, demonstration, or closing question."
            ]
        case .requestedMetrics:
            return [
                "COACH RESPONSE CONTRACT",
                "- Answer the exact metric question first in one sentence.",
                "- Give one behavioural meaning only if it helps. Do not pivot into an exercise or report unrequested telemetry."
            ]
        case .informationOnly:
            if plan.benchmarkAuthorization != nil {
                return [
                    "COACH RESPONSE CONTRACT",
                    "- Answer the generic benchmark question directly with the authorized bounded range and its context caveat.",
                    "- Use range language such as 'about' or 'starting range'. Never claim an exact, universal, or guaranteed target.",
                    "- Stop after the answer. No personal diagnosis, demonstration, drill, invitation, or closing question."
                ]
            }
            return [
                "COACH RESPONSE CONTRACT",
                "- Answer the legitimate craft-knowledge question directly and clearly.",
                "- Stop when the explanation is complete. Do not force a diagnosis, demonstration, drill, invitation, or closing question."
            ]
        case .coachedAttempt:
            return [
                "COACH RESPONSE CONTRACT",
                "- Write one natural coaching turn in this order: acknowledge briefly; give the specific read; model better wording or delivery; invite one attempt.",
                "- The demonstration is mandatory: include one short quoted line OR one precise delivery model the user can imitate now.",
                "- Invite exactly one attempt. Do not add a second exercise, option menu, score recap, or generic encouragement.",
                "- Keep it \(surface == .live ? "speakable in one breath" : "compact enough to read without scrolling")."
            ]
        }
    }

    static func universalCoachLines(surface: CoachReplySurface) -> [String] {
        let live = surface == .live
        return [
            "- Spoken-coach rule: do not use report labels, section labels, raw scaffold names, or dashboard-style rows such as 'What the numbers show', 'Filler rate:', 'Next rep:', 'Read:', 'Move:', or 'Target:'.",
            "- Do not use colon-led coaching labels such as 'Real read:', 'The specific thing:', 'Try this next:', or 'Proof test:'. Make those ideas normal sentences.",
            "- Metrics are opt-in. Unless the private decision plan explicitly authorizes named personal metrics or one requested generic benchmark, do not surface any score, rating, WPM, filler count/rate, duration, percentage, or numeric trend.",
            "- Cold start rule: when there is no baseline or no rated sessions, do not open with 'No baseline yet', do not name internal practice modes, and do not set filler or score targets. Ask for one plain 60-second sample on something the user knows well.",
            "- On voice or goal-change turns, do not use raw score, filler, or duration readouts as proof. Translate progress into coach speech, such as 'your authoritative work is already landing,' then ask what changed.",
            "- Treat a voice or goal as a training emphasis, never an identity or personality. A change reweights future practice; it does not make the user's prior delivery fake, inauthentic, or wasted, and it does not erase observed evidence.",
            "- If the user pushes back with 'however', 'but', 'not easy', 'awkward', 'cold', 'repeating', or 'not informative', solve that exact objection before prescribing again.",
            "- If a user asks what Noum knows about them, answer in plain person-shaped language: goal, pattern, one or two concrete examples, and a trust-earning close. Do not describe system memory, context, metadata, or internal structure.",
            "- If the user is tired, discouraged, or overwhelmed, give relief first: smaller move, permission to pause, or one grounded reminder. Do not make the next ask bigger.",
            "- If the user asks for a plan, a big moment, interview prep, or leadership prep, a short sequence is allowed; otherwise keep one move only.",
            "- If the user wants to change voice/goal, propose the closest real option in coach speech and let the confirmation card handle UI. Do not tell them to tap, confirm, or lock it in, and do not say it is set unless app state already says so.",
            "- If evidence is weak, say what is missing. If evidence is strong, make the read specific enough that it would not fit another user.",
            "- Length hard preference: \(live ? "one or two compact spoken beats, never over 35 words" : "usually no more than 50 words; explicit deep assessment may use 90")."
        ]
    }

    static func instructionLines(
        for depth: CoachTurnDepth,
        surface: CoachReplySurface
    ) -> [String] {
        let live = surface == .live
        switch depth {
        case .quickMove:
            return [
                "- Depth instruction: answer directly. Give one next move only when the user asked for action. No menu.",
                "- If the turn is off-topic or a test, name it lightly and steer back without mislabelling it as coaching evidence. Offer a coaching choice; no score, filler, or duration recap on that turn.",
                "- Length budget: \(live ? "35 spoken words" : "50 words and two sentences")."
            ]
        case .groundedRead:
            return [
                "- Depth instruction: give one short evidence-backed read in human language. Add one move only when it answers the ask.",
                "- Pushback rule: when the user's obstacle changes the advice, adapt the technique. Example: if pausing makes them lose the thread, give the pause a job rather than repeating 'pause more'.",
                "- Transfer rule: when the user reports a real-world outcome, connect it to one observed lever as association, not causation, then ask for the one thing they noticed.",
                "- Length budget: \(live ? "35 spoken words" : "50 words and two sentences")."
            ]
        case .deepAssessment:
            return [
                "- Depth instruction: answer the distance-to-goal question first. Separate what improved in the answer from what remains unproven under pressure. Use concrete evidence, name missing evidence, and end with one concrete validation rep. Never infer overall closeness from one score.",
                "- Prep rule: for interviews, leadership updates, speeches, or big moments, give a time-boxed sequence tied to the date and one observable target.",
                "- Length budget: \(live ? "compact spoken verdict, under 35 words" : "up to 90 words").",
                "- Required judgement shape: verdict first, observed answer control versus consistent authority, evidence, missing evidence, and one concrete validation rep."
            ]
        case .trustRepair:
            return [
                "- Depth instruction: acknowledge the specific miss briefly, name what the prior answer failed to establish, then repair with a better answer or the exact missing evidence.",
                "- Emotional repair rule: if the user says it is hard, exhausting, cold, repetitive, or unhelpful, meet that feeling first. Advice comes second and must be smaller than the original ask.",
                "- Do not give another drill until the repair focus has been named.",
                "- Length budget: \(live ? "under 35 spoken words" : "under 45 words")."
            ]
        }
    }

    static func preferredProviderTier(
        for depth: CoachTurnDepth,
        surface: CoachReplySurface,
        realtimeCoachModeEnabled: Bool = CoachBrainFlags.realtimeCoachModeEnabled
    ) -> CoachProviderTier {
        switch depth {
        case .quickMove, .groundedRead:
            return .geminiFast
        case .deepAssessment:
            return surface == .live && realtimeCoachModeEnabled
                ? .geminiFast
                : .claudeReasoning
        case .trustRepair:
            return .claudeReasoning
        }
    }

    static func maxOutputTokens(
        for depth: CoachTurnDepth,
        surface: CoachReplySurface
    ) -> Int {
        switch (depth, surface) {
        case (.quickMove, .live): return 80
        case (.quickMove, .text): return 100
        case (.groundedRead, .live): return 80
        case (.groundedRead, .text): return 110
        case (.deepAssessment, .live): return 80
        case (.deepAssessment, .text): return 180
        case (.trustRepair, .live): return 80
        case (.trustRepair, .text): return 100
        }
    }
}
