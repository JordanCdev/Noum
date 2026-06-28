import Foundation

// MARK: - Goal rubric models

struct GoalRubric: Codable, Equatable {
    var goalID: String
    var displayName: String
    var dimensions: [RubricDimension]
    var defaultWeights: [String: Double]
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
