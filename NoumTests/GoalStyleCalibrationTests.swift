import Foundation
import Testing
@testable import Noum

@Suite("GoalStyleCalibrationTests")
struct GoalStyleCalibrationTests {
    @Test func fixedAssessmentScoringIsDeterministicForEveryCanonicalGoal() throws {
        for style in SpeakingStyleGoal.allCases {
            let first = try GoalStyleCalibrationFixtures.packetCase(
                style: style,
                evidenceShape: .established
            )
            let second = try GoalStyleCalibrationFixtures.packetCase(
                style: style,
                evidenceShape: .established
            )

            #expect(first == second, "\(style.rawValue) changed for fixed evidence")
            #expect(first.candidate.score0To100 != nil)
            #expect(first.candidate.evidenceDepth == .sufficient)
            #expect(first.candidate.missingDimensionIDs.isEmpty)
            #expect(first.candidate.qualitativeEvidenceLevel == .established)
            #expect(first.candidate.formulaVersion == GoalStyleCalibrationEngine.formulaVersion)
        }
    }

    @Test func observedDimensionContributionsSumToCandidateBeforeIntegerRounding() throws {
        let row = try GoalStyleCalibrationFixtures.packetCase(
            style: .authoritative,
            evidenceShape: .established
        )
        let contributionSum = row.candidate.dimensions
            .compactMap(\.contributionToCandidate0To100)
            .reduce(0, +)
        let score = try #require(row.candidate.score0To100)

        #expect(abs(contributionSum - Double(score)) <= 0.51)
        #expect(row.candidate.dimensions.allSatisfy { $0.evidenceReferenceIDs.count == 1 })
    }

    @Test func missingDimensionIsNotImputedAndOnlyReducesCoverageAndConfidence() throws {
        let style = SpeakingStyleGoal.concise
        let rubric = GoalRubricStore.rubric(for: style)
        let observedID = rubric.dimensions[0].id
        let references = [
            GoalStyleCalibrationEvidenceReference(
                referenceID: "evidence.concise.thin.verdict-first.001",
                dimensionID: observedID
            )
        ]
        var lowMissingScore = GoalStyleCalibrationFixtures.assessment(
            style: style,
            rubric: rubric,
            observedDimensionIDs: [observedID],
            evidenceShape: .thin
        )
        var highMissingScore = lowMissingScore
        lowMissingScore.rubricScores = lowMissingScore.rubricScores.map { score in
            guard score.dimensionID != observedID else { return score }
            var copy = score
            copy.score = 0.01
            return copy
        }
        highMissingScore.rubricScores = highMissingScore.rubricScores.map { score in
            guard score.dimensionID != observedID else { return score }
            var copy = score
            copy.score = 0.99
            return copy
        }

        let low = try GoalStyleCalibrationEngine.candidate(
            style: style,
            sourceAssessmentID: "goal-style.concise.missing-low.001",
            locale: .enUS,
            assessment: lowMissingScore,
            evidenceReferences: references
        )
        let high = try GoalStyleCalibrationEngine.candidate(
            style: style,
            sourceAssessmentID: "goal-style.concise.missing-high.001",
            locale: .enUS,
            assessment: highMissingScore,
            evidenceReferences: references
        )

        #expect(low.score0To100 == high.score0To100)
        #expect(low.confidence == high.confidence)
        #expect(low.observedDimensionCount == 1)
        #expect(low.missingDimensionIDs.count == rubric.dimensions.count - 1)
        #expect(low.isInsufficient)
        #expect(low.insufficiencyReasons.contains(.tooFewObservedDimensions))
        #expect(low.insufficiencyReasons.contains(.rubricCoverageBelowFloor))
        #expect(low.insufficiencyReasons.contains(.candidateConfidenceBelowFloor))
    }

    @Test func noDefensibleEvidenceReturnsExplicitInsufficiencyWithoutSyntheticScore() throws {
        let style = SpeakingStyleGoal.warm
        let assessment = GoalStyleCalibrationFixtures.assessment(
            style: style,
            observedDimensionIDs: [],
            evidenceShape: .thin
        )
        let candidate = try GoalStyleCalibrationEngine.candidate(
            style: style,
            sourceAssessmentID: "goal-style.warm.no-evidence.001",
            locale: .enUS,
            assessment: assessment,
            evidenceReferences: []
        )

        #expect(candidate.score0To100 == nil)
        #expect(candidate.confidence == 0)
        #expect(candidate.evidenceDepth == .none)
        #expect(candidate.insufficiencyReasons.contains(.noDefensibleDimensionEvidence))
        #expect(candidate.dimensions.allSatisfy { $0.score0To100 == nil })
    }

    @Test func lowConfidenceAssessmentWithoutTranscriptStaysLowConfidence() throws {
        let row = try GoalStyleCalibrationFixtures.packetCase(
            style: .executive,
            evidenceShape: .thin
        )

        #expect(row.candidate.score0To100 != nil)
        #expect(row.candidate.confidence < GoalStyleCalibrationEngine.minimumCandidateConfidence)
        #expect(row.candidate.evidenceDepth == .thin)
        #expect(row.candidate.isInsufficient)
        #expect(row.candidate.dimensions.flatMap(\.evidenceReferenceIDs).allSatisfy {
            !$0.contains(" ")
        })
    }

    @Test func unsupportedLocalesFailClosedBeforeCandidateCreation() throws {
        let assessment = GoalStyleCalibrationFixtures.assessment(style: .persuasive)
        let references = GoalRubricStore.rubric(for: .persuasive).dimensions.map {
            GoalStyleCalibrationEvidenceReference(
                referenceID: "evidence.persuasive.\($0.id).001",
                dimensionID: $0.id
            )
        }

        for locale in [PracticeLocale.esES, .frFR] {
            do {
                _ = try GoalStyleCalibrationEngine.candidate(
                    style: .persuasive,
                    sourceAssessmentID: "goal-style.persuasive.locale.001",
                    locale: locale,
                    assessment: assessment,
                    evidenceReferences: references
                )
                Issue.record("\(locale.code) unexpectedly produced a candidate")
            } catch let error as GoalStyleCalibrationError {
                #expect(error == .unsupportedLocale(locale.code))
            }
        }
    }

    @Test func formulaFingerprintChangesWithFormulaOrRubric() throws {
        let rubric = GoalRubricStore.rubric(for: .authoritative)
        let current = try GoalStyleCalibrationEngine.formulaFingerprint(for: rubric)
        let changedFormula = try GoalStyleCalibrationEngine.formulaFingerprint(
            for: rubric,
            formulaVersion: "goal-style-weighted-observed-evidence-v2"
        )
        var changedRubric = rubric
        changedRubric.defaultWeights["verdict_first"] = 0.23
        changedRubric.defaultWeights["hedge_control"] = 0.17
        let changedWeights = try GoalStyleCalibrationEngine.formulaFingerprint(for: changedRubric)

        #expect(current != changedFormula)
        #expect(current != changedWeights)
        #expect(changedFormula != changedWeights)
    }

    @Test func proposedGoalRequiresAndCarriesAnExplicitRubric() throws {
        let dimensions = Array(GoalRubricStore.coreDimensions.prefix(2))
        let proposedRubric = GoalRubric(
            goalID: "calm_candidate_v1",
            displayName: "Proposed calm-delivery candidate",
            dimensions: dimensions,
            defaultWeights: [
                dimensions[0].id: 0.45,
                dimensions[1].id: 0.55
            ],
            establishedEvidenceFloor: 0.75
        )
        let observed = Set(dimensions.map(\.id))
        let assessment = GoalStyleCalibrationFixtures.assessment(
            style: .warm,
            rubric: proposedRubric,
            observedDimensionIDs: observed
        )
        let references = dimensions.map {
            GoalStyleCalibrationEvidenceReference(
                referenceID: "evidence.proposed-calm.\($0.id).001",
                dimensionID: $0.id
            )
        }
        let candidate = try GoalStyleCalibrationEngine.candidate(
            rubric: proposedRubric,
            sourceAssessmentID: "goal-style.proposed-calm.001",
            locale: .enUS,
            assessment: assessment,
            evidenceReferences: references
        )
        let packet = try GoalStyleCalibrationPacket.make(from: [
            GoalStyleCalibrationPacketCase(
                calibrationCaseID: "proposed.calm.001",
                rubricOrigin: .proposedExplicitRubric,
                rubric: proposedRubric,
                candidate: candidate
            )
        ])

        #expect(candidate.goalID == "calm_candidate_v1")
        #expect(candidate.qualitativeEvidenceLevel == nil)
        #expect(packet.rows[0].rubricOrigin == .proposedExplicitRubric)
        #expect(packet.rows[0].rubric == proposedRubric)
        #expect(SpeakingStyleGoal.allCases.count == 6)
        #expect(!SpeakingStyleGoal.allCases.map(\.rawValue).contains("calm"))
        #expect(!SpeakingStyleGoal.allCases.map(\.rawValue).contains("humorous"))
    }

    @Test func packetIsDeterministicCoversCanonicalGoalsAndContainsNoRawTranscript() throws {
        let sentinel = "RAW_TRANSCRIPT_SENTINEL private client words"
        let style = SpeakingStyleGoal.storytelling
        let rubric = GoalRubricStore.rubric(for: style)
        let assessment = GoalStyleCalibrationFixtures.assessment(
            style: style,
            rubric: rubric,
            rawEvidenceSentinel: sentinel
        )
        let references = rubric.dimensions.map {
            GoalStyleCalibrationEvidenceReference(
                referenceID: "evidence.storytelling.private.\($0.id).001",
                dimensionID: $0.id
            )
        }
        let candidate = try GoalStyleCalibrationEngine.candidate(
            style: style,
            sourceAssessmentID: "goal-style.storytelling.private.001",
            locale: .enUS,
            assessment: assessment,
            evidenceReferences: references
        )
        let privacyPacket = try GoalStyleCalibrationPacket.make(from: [
            GoalStyleCalibrationPacketCase(
                calibrationCaseID: "canonical.storytelling.privacy",
                rubricOrigin: .canonical,
                rubric: rubric,
                candidate: candidate
            )
        ])
        let privacyJSON = try privacyPacket.encodedSortedJSON()
        let first = try GoalStyleCalibrationFixtures.packet()
        let second = try GoalStyleCalibrationFixtures.packet()

        #expect(first == second)
        #expect(first.caseCount == SpeakingStyleGoal.allCases.count * 2)
        #expect(Set(first.rows.map { $0.rubric.goalID }) == Set(SpeakingStyleGoal.allCases.map(\.rawValue)))
        #expect(first.rows.allSatisfy { !$0.sourceAssessmentID.isEmpty })
        #expect(first.rows.allSatisfy { row in
            row.candidate.dimensions
                .filter { $0.score0To100 != nil }
                .allSatisfy { !$0.evidenceReferenceIDs.isEmpty }
        })
        #expect(!privacyJSON.contains(sentinel))
        #expect(!privacyJSON.lowercased().contains("raw_transcript_sentinel"))
    }

    @Test func reviewSubmissionCannotApplyToChangedFormulaFingerprint() throws {
        let packet = try GoalStyleCalibrationFixtures.boundPacket()
        let source = try #require(packet.rows.first)
        let staleReview = GoalStyleCalibrationReviewRow(
            calibrationCaseID: source.calibrationCaseID,
            formulaFingerprint: "fnv1a64:0000000000000000",
            reviewerID: "reviewer.001",
            reviewerRole: "professional-communication-coach",
            evidencePackageAccessReceiptID: "evidence-access-receipt.001",
            reviewerAttestsEvidenceWasReviewed: true,
            independentScore0To100: 68,
            dimensionScores: [:],
            evidenceCoverageAppropriate: true,
            confidenceAppropriate: true,
            missingEvidenceHandledSafely: true,
            scoreWithinAcceptableTolerance: true,
            overclaimRisk: "low",
            notes: ""
        )
        let submission = GoalStyleCalibrationReviewSubmission(
            schemaVersion: GoalStyleCalibrationPacket.reviewResultsSchemaVersion,
            sourcePacketFingerprint: packet.packetFingerprint,
            sourceEvidencePackageFingerprint: packet.evidencePackageRequirement.packageFingerprint,
            rows: [staleReview]
        )

        #expect(packet.rejectionReasons(for: submission) == [
            "formulaFingerprint:\(source.calibrationCaseID)"
        ])
    }

    @Test func packetAloneBlocksReviewUntilSeparateEvidencePackageIsBoundAndReviewed() throws {
        let unboundPacket = try GoalStyleCalibrationFixtures.packet()
        let source = try #require(unboundPacket.rows.first)
        let requiredReferenceIDs = Set(
            unboundPacket.rows.flatMap { row in
                row.candidate.dimensions.flatMap(\.evidenceReferenceIDs)
            }
        )
        let unverifiedReview = GoalStyleCalibrationReviewRow(
            calibrationCaseID: source.calibrationCaseID,
            formulaFingerprint: source.candidate.formulaFingerprint,
            reviewerID: "reviewer.001",
            reviewerRole: "professional-communication-coach",
            evidencePackageAccessReceiptID: nil,
            reviewerAttestsEvidenceWasReviewed: false,
            independentScore0To100: 68,
            dimensionScores: [:],
            evidenceCoverageAppropriate: true,
            confidenceAppropriate: true,
            missingEvidenceHandledSafely: true,
            scoreWithinAcceptableTolerance: true,
            overclaimRisk: "low",
            notes: ""
        )
        let unboundSubmission = GoalStyleCalibrationReviewSubmission(
            schemaVersion: GoalStyleCalibrationPacket.reviewResultsSchemaVersion,
            sourcePacketFingerprint: unboundPacket.packetFingerprint,
            sourceEvidencePackageFingerprint: nil,
            rows: [unverifiedReview]
        )

        #expect(unboundPacket.humanGateStatus == "blockedPendingAccessControlledEvidencePackage")
        #expect(unboundPacket.evidencePackageRequirement.packageFingerprint == nil)
        #expect(unboundPacket.evidencePackageRequirement.sourceEvidenceIncludedInPacket == false)
        #expect(unboundPacket.evidencePackageRequirement.reviewWithoutEvidencePackageIsInvalid)
        #expect(Set(unboundPacket.evidencePackageRequirement.requiredEvidenceReferenceIDs) == requiredReferenceIDs)
        #expect(unboundPacket.rejectionReasons(for: unboundSubmission).contains("evidencePackageNotBound"))

        let boundPacket = try GoalStyleCalibrationFixtures.boundPacket()
        let boundSource = try #require(boundPacket.rows.first)
        let boundUnverifiedReview = GoalStyleCalibrationReviewRow(
            calibrationCaseID: boundSource.calibrationCaseID,
            formulaFingerprint: boundSource.candidate.formulaFingerprint,
            reviewerID: "reviewer.001",
            reviewerRole: "professional-communication-coach",
            evidencePackageAccessReceiptID: nil,
            reviewerAttestsEvidenceWasReviewed: false,
            independentScore0To100: 68,
            dimensionScores: [:],
            evidenceCoverageAppropriate: true,
            confidenceAppropriate: true,
            missingEvidenceHandledSafely: true,
            scoreWithinAcceptableTolerance: true,
            overclaimRisk: "low",
            notes: ""
        )
        let boundUnverifiedSubmission = GoalStyleCalibrationReviewSubmission(
            schemaVersion: GoalStyleCalibrationPacket.reviewResultsSchemaVersion,
            sourcePacketFingerprint: boundPacket.packetFingerprint,
            sourceEvidencePackageFingerprint: boundPacket.evidencePackageRequirement.packageFingerprint,
            rows: [boundUnverifiedReview]
        )
        let verifiedReview = GoalStyleCalibrationReviewRow(
            calibrationCaseID: boundSource.calibrationCaseID,
            formulaFingerprint: boundSource.candidate.formulaFingerprint,
            reviewerID: "reviewer.001",
            reviewerRole: "professional-communication-coach",
            evidencePackageAccessReceiptID: "evidence-access-receipt.001",
            reviewerAttestsEvidenceWasReviewed: true,
            independentScore0To100: 68,
            dimensionScores: [:],
            evidenceCoverageAppropriate: true,
            confidenceAppropriate: true,
            missingEvidenceHandledSafely: true,
            scoreWithinAcceptableTolerance: true,
            overclaimRisk: "low",
            notes: ""
        )
        let verifiedSubmission = GoalStyleCalibrationReviewSubmission(
            schemaVersion: GoalStyleCalibrationPacket.reviewResultsSchemaVersion,
            sourcePacketFingerprint: boundPacket.packetFingerprint,
            sourceEvidencePackageFingerprint: boundPacket.evidencePackageRequirement.packageFingerprint,
            rows: [verifiedReview]
        )

        #expect(boundPacket.humanGateStatus == "pendingProfessionalReview")
        #expect(boundPacket.rejectionReasons(for: boundUnverifiedSubmission).contains(
            "evidenceNotReviewed:\(boundSource.calibrationCaseID)"
        ))
        #expect(boundPacket.rejectionReasons(for: boundUnverifiedSubmission).contains(
            "evidenceAccessReceipt:\(boundSource.calibrationCaseID)"
        ))
        #expect(boundPacket.rejectionReasons(for: verifiedSubmission).isEmpty)
    }
}
