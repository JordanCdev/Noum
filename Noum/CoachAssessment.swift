import Foundation

// MARK: - Typed coach assessment

struct CoachAssessment: Codable, Equatable {
    enum ResponseMode: String, Codable, Equatable {
        case immediateOnly
        case expandable
    }

    var turnDepth: CoachTurnDepth
    var surface: CoachReplySurface
    var questionRestatement: String
    var directVerdict: String
    var confidence: Double
    var evidenceUsed: [String]
    var rubricScores: [RubricScore]
    var missingEvidence: [String]
    var nextProofTest: String
    var responseMode: ResponseMode

    var evidenceReferenceCount: Int {
        evidenceUsed.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    var weakestRubricScore: RubricScore? {
        rubricScores.min {
            if $0.score != $1.score { return $0.score < $1.score }
            return $0.dimensionID < $1.dimensionID
        }
    }

    /// Local, deterministic read for the streaming-like fallback. It is shown
    /// only while the provider is still verbalising the full answer and is not
    /// persisted as the final coach response.
    var immediateCoachRead: String {
        switch turnDepth {
        case .quickMove:
            return nextProofTest
        case .groundedRead:
            if let first = evidenceUsed.first {
                return "\(first). \(nextProofTest)"
            }
            return nextProofTest
        case .deepAssessment:
            let missing = missingEvidence.first.map { "Missing: \($0)" }
            return [directVerdict, missing, "Proof test: \(nextProofTest)"]
                .compactMap { $0 }
                .joined(separator: " ")
        case .trustRepair:
            return "Fair push. The useful repair is a direct verdict, the evidence behind it, and one proof test."
        }
    }
}
