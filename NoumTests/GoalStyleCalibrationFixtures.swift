import Foundation
@testable import Noum

enum GoalStyleCalibrationFixtures {
    static func canonicalPacketCases() throws -> [GoalStyleCalibrationPacketCase] {
        try SpeakingStyleGoal.allCases.flatMap { style in
            try [
                packetCase(style: style, evidenceShape: .established),
                packetCase(style: style, evidenceShape: .thin)
            ]
        }
    }

    static func packet() throws -> GoalStyleCalibrationPacket {
        try GoalStyleCalibrationPacket.make(from: canonicalPacketCases())
    }

    static func boundPacket() throws -> GoalStyleCalibrationPacket {
        let cases = try canonicalPacketCases()
        let evidenceReferenceIDs = Array(Set(
            cases.flatMap { item in
                item.candidate.dimensions.flatMap(\.evidenceReferenceIDs)
            }
        )).sorted()
        let descriptor = GoalStyleCalibrationEvidencePackageDescriptor(
            schemaVersion: GoalStyleCalibrationPacket.evidencePackageSchemaVersion,
            packageID: "goal-style-calibration-test-evidence.001",
            packageFingerprint: "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
            evidenceReferenceIDs: evidenceReferenceIDs,
            containsDeidentifiedSourceEvidence: true
        )
        return try GoalStyleCalibrationPacket.make(
            from: cases,
            evidencePackage: descriptor
        )
    }

    static func packetCase(
        style: SpeakingStyleGoal,
        evidenceShape: EvidenceShape
    ) throws -> GoalStyleCalibrationPacketCase {
        let rubric = GoalRubricStore.rubric(for: style)
        let sourceAssessmentID = "goal-style.\(style.rawValue).\(evidenceShape.rawValue).001"
        let observedIDs: Set<String>
        switch evidenceShape {
        case .established:
            observedIDs = Set(rubric.dimensions.map(\.id))
        case .thin:
            observedIDs = [rubric.dimensions[0].id]
        }
        let references = rubric.dimensions.compactMap { dimension in
            observedIDs.contains(dimension.id)
                ? GoalStyleCalibrationEvidenceReference(
                    referenceID: "evidence.\(style.rawValue).\(evidenceShape.rawValue).\(dimension.id).001",
                    dimensionID: dimension.id
                )
                : nil
        }
        let assessment = assessment(
            style: style,
            rubric: rubric,
            observedDimensionIDs: observedIDs,
            evidenceShape: evidenceShape
        )
        let candidate = try GoalStyleCalibrationEngine.candidate(
            style: style,
            sourceAssessmentID: sourceAssessmentID,
            locale: .enUS,
            assessment: assessment,
            evidenceReferences: references
        )
        return GoalStyleCalibrationPacketCase(
            calibrationCaseID: "canonical.\(style.rawValue).\(evidenceShape.rawValue)",
            rubricOrigin: .canonical,
            rubric: rubric,
            candidate: candidate
        )
    }

    static func assessment(
        style: SpeakingStyleGoal,
        rubric: GoalRubric? = nil,
        observedDimensionIDs: Set<String>? = nil,
        evidenceShape: EvidenceShape = .established,
        rawEvidenceSentinel: String? = nil
    ) -> CoachAssessment {
        let activeRubric = rubric ?? GoalRubricStore.rubric(for: style)
        let observed = observedDimensionIDs ?? Set(activeRubric.dimensions.map(\.id))
        let styleOffset = Double(
            SpeakingStyleGoal.allCases.firstIndex(of: style) ?? 0
        ) * 0.015
        let baseScores: [String: Double] = [
            "verdict_first": 0.76,
            "hedge_control": 0.70,
            "clean_close": 0.73,
            "pressure_stability": 0.62,
            "controlled_pacing": 0.68,
            "salience": 0.66
        ]
        let confidence: Double = evidenceShape == .established ? 0.79 : 0.38
        let scores = activeRubric.dimensions.map { dimension in
            let isObserved = observed.contains(dimension.id)
            return RubricScore(
                dimensionID: dimension.id,
                label: dimension.label,
                score: min(0.94, (baseScores[dimension.id] ?? 0.64) + styleOffset),
                confidence: confidence,
                evidence: isObserved
                    ? [rawEvidenceSentinel ?? "assessment-evidence:\(dimension.id)"]
                    : [],
                missingEvidence: isObserved ? nil : dimension.missingIfAbsent
            )
        }
        let assessmentReferences = observed.sorted().map { "assessment-ref:\($0)" }
        return CoachAssessment(
            turnDepth: .deepAssessment,
            surface: .text,
            questionRestatement: "",
            directVerdict: "",
            confidence: confidence,
            evidenceUsed: rawEvidenceSentinel.map { assessmentReferences + [$0] } ?? assessmentReferences,
            rubricScores: scores,
            missingEvidence: scores.compactMap(\.missingEvidence),
            nextProofTest: "",
            responseMode: .expandable,
            toneMode: .challenge,
            repairFocus: nil
        )
    }

    enum EvidenceShape: String {
        case established
        case thin
    }
}
