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

    static func instructionLines(
        for depth: CoachTurnDepth,
        surface: CoachReplySurface
    ) -> [String] {
        let live = surface == .live
        switch depth {
        case .quickMove:
            return [
                "- Depth instruction: answer directly, give one reason and one next move. No menu.",
                "- Length budget: \(live ? "under 70 spoken words" : "under 90 words")."
            ]
        case .groundedRead:
            return [
                "- Depth instruction: give a short evidence-backed read. Include concrete signal, one gap, and one move.",
                "- Length budget: \(live ? "under 110 spoken words" : "under 160 words")."
            ]
        case .deepAssessment:
            return [
                "- Depth instruction: answer the distance-to-goal question first. Separate mechanics/score from true goal readiness. Use concrete evidence, name missing evidence, and end with the proof test. Never infer overall closeness from one score.",
                "- Length budget: \(live ? "compact spoken verdict, under 120 words" : "up to 260 words if needed").",
                "- Required terms of judgement: verdict first, mechanics versus goal distinction, evidence, missing evidence, one proof test."
            ]
        case .trustRepair:
            return [
                "- Depth instruction: acknowledge the specific miss briefly, name what the prior answer failed to establish, then repair with a better answer or the exact missing evidence.",
                "- Do not give another drill until the repair focus has been named.",
                "- Length budget: \(live ? "under 100 spoken words" : "under 160 words")."
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
        case (.quickMove, .text): return 180
        case (.groundedRead, .live): return 160
        case (.groundedRead, .text): return 180
        case (.deepAssessment, .live): return 220
        case (.deepAssessment, .text): return 420
        case (.trustRepair, .live): return 180
        case (.trustRepair, .text): return 260
        }
    }
}
