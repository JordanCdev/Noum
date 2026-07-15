import Foundation

// MARK: - Goal rubric models

struct GoalRubric: Codable, Equatable {
    var goalID: String
    var displayName: String
    var dimensions: [RubricDimension]
    var defaultWeights: [String: Double]
    /// Minimum bounded-read confidence before the rubric may describe a
    /// pattern as established. Optional for backward compatibility with
    /// cached payloads.
    var establishedEvidenceFloor: Double? = nil
}

struct RubricDimension: Codable, Equatable, Identifiable {
    var id: String
    var label: String
    var description: String
    var proofSignals: [String]
    var proofTest: String
    var missingIfAbsent: String
}

struct ActiveGoalRubric: Codable, Equatable {
    var rubric: GoalRubric
    var voice: SpeakingStyleGoal?
}

struct RubricScore: Codable, Equatable, Identifiable {
    var id: String { dimensionID }
    var dimensionID: String
    var label: String
    /// 0...1, intentionally coarse. The model gets the typed read; it should
    /// not invent precision beyond this deterministic pass.
    var score: Double
    var confidence: Double
    var evidence: [String]
    var missingEvidence: String?
}

enum GoalEvidenceLevel: String, Codable, Equatable {
    case insufficient
    case forming
    case established
}

enum GoalMovement: String, Codable, Equatable {
    case emerging
    case holding
    case improving
    case mixed
}

/// A restrained user-facing projection of the existing deterministic coach
/// assessment. It is never persisted as a second score and never presents a
/// speaking identity as a precise percentage.
struct GoalOutcomeRead: Equatable {
    let style: SpeakingStyleGoal
    let evidenceLevel: GoalEvidenceLevel
    let movement: GoalMovement
    let strongestDimension: RubricScore?
    let nextDimension: RubricScore?
    let evidenceCitation: String?
    let confidence: Double
    let prescribedNextAction: String
    let latestFollowUpResult: GoalFollowUpResult?

    static func make(
        style: SpeakingStyleGoal,
        assessment: CoachAssessment,
        outcomes: [RecommendationOutcome] = []
    ) -> GoalOutcomeRead {
        let rubric = GoalRubricStore.rubric(for: style)
        let usefulScores = assessment.rubricScores.filter { !$0.evidence.isEmpty }
        let strongest = usefulScores.max {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.dimensionID > $1.dimensionID
        }
        // Select the largest goal-weighted deficit among dimensions that can
        // be acted on without distorting the chosen voice. Lowest raw score is
        // not enough: warm/storytelling intentionally down-weight verdict and
        // hedge mechanics, and those dimensions must not become prescriptions.
        let next = usefulScores
            .filter {
                GoalRubricStore.actionTarget(
                    for: style,
                    dimensionID: $0.dimensionID
                ) != nil
            }
            .max {
                let lhs = (rubric.defaultWeights[$0.dimensionID] ?? 0)
                    * max(0, 1 - $0.score)
                let rhs = (rubric.defaultWeights[$1.dimensionID] ?? 0)
                    * max(0, 1 - $1.score)
                if lhs != rhs { return lhs < rhs }
                return $0.dimensionID > $1.dimensionID
            }
        let confidence = min(1, max(0, assessment.confidence))
        // Rubrics deliberately set different evidence floors. For example, an
        // executive-presence read needs more corroboration than a concise
        // delivery read before we call the pattern established. Keep the
        // presentation tied to that same rubric rather than silently applying
        // a one-size-fits-all threshold.
        let establishedEvidenceFloor = rubric.establishedEvidenceFloor ?? 0.70
        let evidenceLevel: GoalEvidenceLevel
        if confidence < 0.35 || assessment.evidenceReferenceCount == 0 {
            evidenceLevel = .insufficient
        } else if confidence < establishedEvidenceFloor || assessment.evidenceReferenceCount < 2 {
            evidenceLevel = .forming
        } else {
            evidenceLevel = .established
        }

        let currentTargetID = next?.dimensionID
        let goalOutcomes = outcomes
            .filter { outcome in
                outcome.goal == style
                    && outcome.isVerifiedFollowed
                    && outcome.hasComparableBaseline
                    && outcome.targetDimensionID == currentTargetID
                    && rubric.dimensions.contains(where: { dimension in
                        dimension.id == outcome.targetDimensionID
                    })
            }
            .sorted { $0.completedAt > $1.completedAt }
        let comparableTargetOutcomes = goalOutcomes
        let movement: GoalMovement
        let followUps = comparableTargetOutcomes.prefix(3).compactMap(\.goalFollowUpResult)
        if followUps.contains(.mixed) {
            movement = .mixed
        } else if followUps.filter({ $0 == .earlyImprovement }).count >= 2 {
            movement = .improving
        } else if followUps.contains(.held) {
            movement = .holding
        } else if followUps.contains(.earlyImprovement) || followUps.contains(.needsMoreEvidence) {
            movement = .emerging
        } else {
            movement = evidenceLevel == .established ? .holding : .emerging
        }

        let citation = assessment.evidenceUsed
            .first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            ?? strongest?.evidence.first

        let prescribedNextAction = next.flatMap { score in
            rubric.dimensions.first { $0.id == score.dimensionID }?.proofTest
        } ?? assessment.nextProofTest

        return GoalOutcomeRead(
            style: style,
            evidenceLevel: evidenceLevel,
            movement: movement,
            strongestDimension: strongest,
            nextDimension: next,
            evidenceCitation: citation,
            confidence: confidence,
            prescribedNextAction: prescribedNextAction,
            latestFollowUpResult: comparableTargetOutcomes.first?.goalFollowUpResult
        )
    }
}
