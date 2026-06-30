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
            return Self.compactRead(
                verdict: directVerdict,
                evidence: evidenceUsed.first,
                missing: nil,
                proofTest: nextProofTest
            )
        case .groundedRead:
            return Self.compactRead(
                verdict: directVerdict,
                evidence: evidenceUsed.first,
                missing: nil,
                proofTest: nextProofTest
            )
        case .deepAssessment:
            return Self.compactRead(
                verdict: directVerdict,
                evidence: evidenceUsed.first,
                missing: missingEvidence.first,
                proofTest: nextProofTest
            )
        case .trustRepair:
            if let repairFocus,
               !repairFocus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Fair push: \(repairFocus). \(directVerdict) Proof test: \(nextProofTest)"
            }
            return "Fair push: I need to repair the answer before adding another drill. \(directVerdict) Proof test: \(nextProofTest)"
        }
    }

    private static func compactRead(
        verdict: String,
        evidence: String?,
        missing: String?,
        proofTest: String
    ) -> String {
        var parts: [String] = []
        parts.append(completeSentence(verdict))
        if let signal = compactEvidence(evidence) {
            parts.append("The signal I can use is \(completeSentence(signal))")
        }
        if let missing,
           !missing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("I still need \(missingRequirementPhrase(missing))")
        }
        parts.append("Try this next: \(completeSentence(proofTest))")
        return parts.joined(separator: " ")
    }

    private static func compactEvidence(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let prefixes = [
            "latest rep:",
            "pace estimate:",
            "case summary:",
            "case focus:",
            "case evidence:",
            "active intervention:",
            "conversation hypothesis:",
            "prior coach read:",
            "trust repair signal:"
        ]
        let lowered = trimmed.lowercased()
        for prefix in prefixes where lowered.hasPrefix(prefix) {
            let value = trimmed.dropFirst(prefix.count)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? trimmed : String(value)
        }
        return trimmed
    }

    private static func missingRequirementPhrase(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let lower = trimmed.lowercased()
        let phrase: String
        if lower.hasPrefix("need ") {
            phrase = String(trimmed.dropFirst("Need ".count))
        } else {
            phrase = trimmed
        }
        return completeSentence(lowercaseFirst(phrase))
    }

    private static func lowercaseFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).lowercased() + String(text.dropFirst())
    }

    private static func completeSentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return trimmed }
        if ".!?".contains(last) { return trimmed }
        return "\(trimmed)."
    }
}
