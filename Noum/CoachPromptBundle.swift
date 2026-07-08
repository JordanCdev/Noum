import Foundation

// MARK: - Depth-aware coach prompt bundle

enum CoachPromptBundle {

    static func contextBlock(
        assessment: CoachAssessment,
        rubric: ActiveGoalRubric,
        surface: CoachReplySurface
    ) -> String {
        var lines: [String] = []
        lines.append("")
        lines.append("COACH JUDGEMENT PASS (typed source of truth)")
        lines.append("- Turn depth: \(assessment.turnDepth.rawValue).")
        lines.append("- Surface: \(surface.rawValue).")
        lines.append("- User ask: \(assessment.questionRestatement)")
        lines.append("- Direct verdict to verbalise first: \(assessment.directVerdict)")
        lines.append("- Confidence: \(String(format: "%.2f", assessment.confidence)) (scale claims to this; weak evidence means softer language).")
        if let toneMode = assessment.toneMode {
            lines.append("- Tone mode: \(toneMode.rawValue).")
        }
        if let repairFocus = assessment.repairFocus,
           !repairFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("- Repair focus: \(repairFocus). Acknowledge this before prescribing again.")
        }
        if !assessment.evidenceUsed.isEmpty {
            lines.append("- Evidence to use:")
            for item in assessment.evidenceUsed.prefix(evidenceContextLimit(for: assessment.turnDepth)) {
                lines.append("  - \(item)")
            }
        }
        if !assessment.rubricScores.isEmpty {
            lines.append("- Rubric: \(rubric.rubric.displayName).")
            for score in assessment.rubricScores.prefix(6) {
                lines.append("  - \(score.label): \(String(format: "%.2f", score.score)) confidence \(String(format: "%.2f", score.confidence)).")
            }
        }
        if !assessment.missingEvidence.isEmpty {
            lines.append("- Missing evidence to name when relevant:")
            for item in assessment.missingEvidence.prefix(3) {
                lines.append("  - \(item)")
            }
        }
        lines.append("- Next proof test to end with: \(assessment.nextProofTest)")
        lines.append(contentsOf: universalCoachLines(surface: surface))
        lines.append(contentsOf: instructionLines(for: assessment.turnDepth, surface: surface))
        return lines.joined(separator: "\n")
    }

    private static func evidenceContextLimit(for depth: CoachTurnDepth) -> Int {
        switch depth {
        case .quickMove:
            return 2
        case .groundedRead:
            return 4
        case .deepAssessment, .trustRepair:
            return 6
        }
    }

    static func universalCoachLines(surface: CoachReplySurface) -> [String] {
        let live = surface == .live
        return [
            "- Spoken-coach rule: do not use report labels, section labels, raw scaffold names, or dashboard-style rows such as 'What the numbers show', 'Filler rate:', 'Next rep:', 'Read:', 'Move:', or 'Target:'.",
            "- Translate metrics into behaviour. Use a number only when it changes the read; never dump pace, pause rate, score, and fillers as a list.",
            "- If the user pushes back with 'however', 'but', 'not easy', 'awkward', 'cold', 'repeating', or 'not informative', solve that exact objection before prescribing again.",
            "- If a user asks what Noum knows about them, answer in plain person-shaped language: goal, pattern, one or two proof points, and a trust-earning close. Do not describe system memory, context, metadata, or internal structure.",
            "- If the user is tired, discouraged, or overwhelmed, give relief first: smaller move, permission to pause, or one grounded reminder. Do not make the next ask bigger.",
            "- If the user asks for a plan, a big moment, interview prep, or leadership prep, a short sequence is allowed; otherwise keep one move only.",
            "- If the user wants to change voice/goal, propose the closest real option in coach speech and let the confirmation card handle UI. Do not tell them to tap, confirm, or lock it in, and do not say it is set unless app state already says so.",
            "- If evidence is weak, say what is missing. If evidence is strong, make the read specific enough that it would not fit another user.",
            "- Length hard preference: \(live ? "one or two compact spoken beats" : "usually under 90 words unless the user explicitly asked for a plan or deep assessment")."
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
                "- Depth instruction: answer directly, give one reason and one next move. No menu.",
                "- If the turn is off-topic or a test, name it lightly and steer back without pretending it was a real coaching question. No score, filler, or duration recap on that turn.",
                "- Length budget: \(live ? "under 60 spoken words" : "under 75 words")."
            ]
        case .groundedRead:
            return [
                "- Depth instruction: give a short evidence-backed read in human language: one observed signal, the real gap, and one move.",
                "- Pushback rule: when the user's obstacle changes the advice, adapt the technique. Example: if pausing makes them lose the thread, give the pause a job rather than repeating 'pause more'.",
                "- Transfer rule: when the user reports a real-world outcome, connect it to one observed lever as association, not causation, then ask for the one thing they noticed.",
                "- Length budget: \(live ? "under 90 spoken words" : "under 95 words unless a plan was requested")."
            ]
        case .deepAssessment:
            return [
                "- Depth instruction: answer the distance-to-goal question first. Separate mechanics/score from true goal readiness. Use concrete evidence, name missing evidence, and end with one proof test. Never infer overall closeness from one score.",
                "- Prep rule: for interviews, leadership updates, speeches, or big moments, give a time-boxed sequence tied to the date and one observable target.",
                "- Length budget: \(live ? "compact spoken verdict, under 110 words" : "up to 220 words if needed").",
                "- Required terms of judgement: verdict first, mechanics versus goal distinction, evidence, missing evidence, one proof test."
            ]
        case .trustRepair:
            return [
                "- Depth instruction: acknowledge the specific miss briefly, name what the prior answer failed to establish, then repair with a better answer or the exact missing evidence.",
                "- Emotional repair rule: if the user says it is hard, exhausting, cold, repetitive, or unhelpful, meet that feeling first. Advice comes second and must be smaller than the original ask.",
                "- Do not give another drill until the repair focus has been named.",
                "- Length budget: \(live ? "under 85 spoken words" : "under 95 words unless the user asked for a plan")."
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
        case (.quickMove, .live): return 120
        case (.quickMove, .text): return 160
        case (.groundedRead, .live): return 140
        case (.groundedRead, .text): return 180
        case (.deepAssessment, .live): return 220
        case (.deepAssessment, .text): return 380
        case (.trustRepair, .live): return 160
        case (.trustRepair, .text): return 220
        }
    }
}
