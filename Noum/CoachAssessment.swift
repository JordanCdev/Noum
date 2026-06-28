import Foundation

// MARK: - Typed coach assessment

struct CoachAssessment: Codable, Equatable {
    enum ResponseMode: String, Codable, Equatable {
        case immediateOnly
        case expandable
    }

    enum ToneMode: String, Codable, Equatable {
        case validate
        case challenge
        case explain
        case prescribe
        case repair
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
    var toneMode: ToneMode? = nil
    var repairFocus: String? = nil

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
            if let repairFocus,
               !repairFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Fair push: \(repairFocus). \(directVerdict) Proof test: \(nextProofTest)"
            }
            return "Fair push: I need to repair the answer before adding another drill. \(directVerdict) Proof test: \(nextProofTest)"
        }
    }
}
