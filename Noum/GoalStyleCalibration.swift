import Foundation

// MARK: - Calibration-only goal-style candidate

/// A versioned, deterministic candidate for professional calibration.
///
/// This type is deliberately not referenced by any product view, session
/// model, store, analytics event, or account export. `GoalOutcomeRead` remains
/// the only product-facing goal projection until professional review earns a
/// separate product decision.
struct GoalStyleCalibrationCandidate: Codable, Equatable {
    let candidateSchemaVersion: String
    let formulaVersion: String
    let formulaFingerprint: String
    let sourceAssessmentID: String
    let goalID: String
    let localeCode: String
    let score0To100: Int?
    let confidence: Double
    let evidenceDepth: GoalStyleCalibrationEvidenceDepth
    let evidenceWeightCoverage: Double
    let observedDimensionCount: Int
    let totalDimensionCount: Int
    let dimensions: [GoalStyleCalibrationDimension]
    let missingDimensionIDs: [String]
    let insufficiencyReasons: [GoalStyleCalibrationInsufficiency]
    let qualitativeEvidenceLevel: GoalEvidenceLevel?
    let qualitativeMovement: GoalMovement?

    var isInsufficient: Bool { !insufficiencyReasons.isEmpty }
}

struct GoalStyleCalibrationDimension: Codable, Equatable, Identifiable {
    var id: String { dimensionID }

    let dimensionID: String
    let label: String
    let rubricWeight: Double
    let score0To100: Int?
    let normalizedObservedWeight: Double?
    let contributionToCandidate0To100: Double?
    let evidenceConfidence: Double?
    let evidenceReferenceIDs: [String]
    let missingEvidence: String?
}

struct GoalStyleCalibrationEvidenceReference: Codable, Equatable, Hashable {
    let referenceID: String
    let dimensionID: String
}

enum GoalStyleCalibrationEvidenceDepth: String, Codable, Equatable {
    case none
    case thin
    case forming
    case sufficient
}

enum GoalStyleCalibrationInsufficiency: String, Codable, Equatable {
    case noDefensibleDimensionEvidence
    case tooFewObservedDimensions
    case rubricCoverageBelowFloor
    case candidateConfidenceBelowFloor
}

enum GoalStyleCalibrationError: Error, Equatable {
    case unsupportedLocale(String)
    case invalidSourceAssessmentID
    case invalidRubric(String)
    case invalidEvidenceReference(String)
}

enum GoalStyleCalibrationEngine {
    static let candidateSchemaVersion = "goal-style-score-candidate-v1"
    static let formulaVersion = "goal-style-weighted-observed-evidence-v1"
    static let minimumCandidateConfidence = 0.55
    static let minimumObservedDimensionCount = 2

    /// Canonical-goal entry point. It binds the candidate to the same rubric
    /// and qualitative read already used by Summary, Review, and Profile.
    static func candidate(
        style: SpeakingStyleGoal,
        sourceAssessmentID: String,
        locale: PracticeLocale,
        assessment: CoachAssessment,
        evidenceReferences: [GoalStyleCalibrationEvidenceReference],
        outcomes: [RecommendationOutcome] = []
    ) throws -> GoalStyleCalibrationCandidate {
        let qualitativeRead = GoalOutcomeRead.make(
            style: style,
            assessment: assessment,
            outcomes: outcomes
        )
        return try candidate(
            rubric: GoalRubricStore.rubric(for: style),
            sourceAssessmentID: sourceAssessmentID,
            locale: locale,
            assessment: assessment,
            evidenceReferences: evidenceReferences,
            qualitativeEvidenceLevel: qualitativeRead.evidenceLevel,
            qualitativeMovement: qualitativeRead.movement
        )
    }

    /// Explicit-rubric entry point for proposed goal definitions. A proposed
    /// goal cannot silently inherit a canonical rubric: callers must supply the
    /// complete definition that reviewers will see in the packet.
    static func candidate(
        rubric: GoalRubric,
        sourceAssessmentID: String,
        locale: PracticeLocale,
        assessment: CoachAssessment,
        evidenceReferences: [GoalStyleCalibrationEvidenceReference]
    ) throws -> GoalStyleCalibrationCandidate {
        try candidate(
            rubric: rubric,
            sourceAssessmentID: sourceAssessmentID,
            locale: locale,
            assessment: assessment,
            evidenceReferences: evidenceReferences,
            qualitativeEvidenceLevel: nil,
            qualitativeMovement: nil
        )
    }

    static func formulaFingerprint(
        for rubric: GoalRubric,
        formulaVersion: String = Self.formulaVersion
    ) throws -> String {
        try validate(rubric: rubric)
        let formulaContract = [
            "formulaVersion=\(formulaVersion)",
            "score=round(sum(observedScore*normalizedObservedWeight)*100)",
            "missing=excluded_without_imputation",
            "confidence=min(assessment,weightedDimensionConfidence)*observedWeightCoverage",
            "minimumCandidateConfidence=\(canonical(minimumCandidateConfidence))",
            "minimumObservedDimensionCount=\(minimumObservedDimensionCount)",
            "depth=none|thin(<0.50_or_<2)|forming(<floor)|sufficient"
        ].joined(separator: "|")
        let dimensions = rubric.dimensions
            .sorted { $0.id < $1.id }
            .map { dimension in
                [
                    canonicalField("id", dimension.id),
                    canonicalField("label", dimension.label),
                    canonicalField("description", dimension.description),
                    canonicalField("proofSignals", dimension.proofSignals.joined(separator: "\u{1f}")),
                    canonicalField("proofTest", dimension.proofTest),
                    canonicalField("missingIfAbsent", dimension.missingIfAbsent),
                    canonicalField("weight", canonical(rubric.defaultWeights[dimension.id] ?? 0))
                ].joined(separator: "|")
            }
            .joined(separator: "\n")
        let rubricContract = [
            canonicalField("goalID", rubric.goalID),
            canonicalField("displayName", rubric.displayName),
            canonicalField("establishedEvidenceFloor", canonical(rubric.establishedEvidenceFloor ?? 0.70)),
            dimensions
        ].joined(separator: "\n")
        return stableFingerprint(formulaContract + "\n" + rubricContract)
    }

    private static func candidate(
        rubric: GoalRubric,
        sourceAssessmentID: String,
        locale: PracticeLocale,
        assessment: CoachAssessment,
        evidenceReferences: [GoalStyleCalibrationEvidenceReference],
        qualitativeEvidenceLevel: GoalEvidenceLevel?,
        qualitativeMovement: GoalMovement?
    ) throws -> GoalStyleCalibrationCandidate {
        guard locale == .enUS, locale.aiSupported else {
            throw GoalStyleCalibrationError.unsupportedLocale(locale.code)
        }
        guard isOpaqueIdentifier(sourceAssessmentID) else {
            throw GoalStyleCalibrationError.invalidSourceAssessmentID
        }
        try validate(rubric: rubric)

        let dimensionIDs = Set(rubric.dimensions.map(\.id))
        var referenceIDs = Set<String>()
        for reference in evidenceReferences {
            guard isOpaqueIdentifier(reference.referenceID),
                  dimensionIDs.contains(reference.dimensionID),
                  referenceIDs.insert(reference.referenceID).inserted else {
                throw GoalStyleCalibrationError.invalidEvidenceReference(reference.referenceID)
            }
        }

        let referencesByDimension = Dictionary(
            grouping: evidenceReferences,
            by: \.dimensionID
        )
        let scoresByDimension = Dictionary(
            grouping: assessment.rubricScores,
            by: \.dimensionID
        )
        if let duplicate = scoresByDimension.first(where: { $0.value.count != 1 })?.key {
            throw GoalStyleCalibrationError.invalidRubric("duplicate assessment score: \(duplicate)")
        }

        let totalWeight = rubric.dimensions.reduce(0.0) {
            $0 + (rubric.defaultWeights[$1.id] ?? 0)
        }
        let observedDimensions = rubric.dimensions.compactMap { dimension -> (RubricDimension, RubricScore, [GoalStyleCalibrationEvidenceReference])? in
            guard let score = scoresByDimension[dimension.id]?.first,
                  score.score.isFinite,
                  (0...1).contains(score.score),
                  score.confidence.isFinite,
                  (0...1).contains(score.confidence),
                  score.evidence.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }),
                  let references = referencesByDimension[dimension.id],
                  !references.isEmpty else {
                return nil
            }
            return (dimension, score, references)
        }
        let observedWeight = observedDimensions.reduce(0.0) {
            $0 + (rubric.defaultWeights[$1.0.id] ?? 0)
        }
        let coverage = totalWeight > 0 ? observedWeight / totalWeight : 0

        var renderedDimensions: [GoalStyleCalibrationDimension] = []
        for dimension in rubric.dimensions {
            let weight = rubric.defaultWeights[dimension.id] ?? 0
            if let observed = observedDimensions.first(where: { $0.0.id == dimension.id }) {
                let normalizedWeight = observedWeight > 0 ? weight / observedWeight : 0
                renderedDimensions.append(
                    GoalStyleCalibrationDimension(
                        dimensionID: dimension.id,
                        label: dimension.label,
                        rubricWeight: rounded(weight),
                        score0To100: integerScore(observed.1.score),
                        normalizedObservedWeight: rounded(normalizedWeight),
                        contributionToCandidate0To100: rounded(observed.1.score * normalizedWeight * 100),
                        evidenceConfidence: rounded(observed.1.confidence),
                        evidenceReferenceIDs: observed.2.map(\.referenceID).sorted(),
                        missingEvidence: nil
                    )
                )
            } else {
                renderedDimensions.append(
                    GoalStyleCalibrationDimension(
                        dimensionID: dimension.id,
                        label: dimension.label,
                        rubricWeight: rounded(weight),
                        score0To100: nil,
                        normalizedObservedWeight: nil,
                        contributionToCandidate0To100: nil,
                        evidenceConfidence: nil,
                        evidenceReferenceIDs: [],
                        missingEvidence: dimension.missingIfAbsent
                    )
                )
            }
        }

        let weightedObservedScore: Double? = observedWeight > 0
            ? observedDimensions.reduce(0.0) { partial, observed in
                let weight = rubric.defaultWeights[observed.0.id] ?? 0
                return partial + observed.1.score * (weight / observedWeight)
            }
            : nil
        let weightedDimensionConfidence = observedWeight > 0
            ? observedDimensions.reduce(0.0) { partial, observed in
                let weight = rubric.defaultWeights[observed.0.id] ?? 0
                return partial + observed.1.confidence * (weight / observedWeight)
            }
            : 0
        let candidateConfidence = min(
            bounded(assessment.confidence),
            bounded(weightedDimensionConfidence)
        ) * bounded(coverage)
        let evidenceFloor = bounded(rubric.establishedEvidenceFloor ?? 0.70)

        var insufficiency: [GoalStyleCalibrationInsufficiency] = []
        if observedDimensions.isEmpty {
            insufficiency.append(.noDefensibleDimensionEvidence)
        }
        if observedDimensions.count < minimumObservedDimensionCount {
            insufficiency.append(.tooFewObservedDimensions)
        }
        if coverage < evidenceFloor {
            insufficiency.append(.rubricCoverageBelowFloor)
        }
        if candidateConfidence < minimumCandidateConfidence {
            insufficiency.append(.candidateConfidenceBelowFloor)
        }

        let depth: GoalStyleCalibrationEvidenceDepth
        if observedDimensions.isEmpty {
            depth = .none
        } else if observedDimensions.count < minimumObservedDimensionCount || coverage < 0.50 {
            depth = .thin
        } else if coverage < evidenceFloor {
            depth = .forming
        } else {
            depth = .sufficient
        }

        return GoalStyleCalibrationCandidate(
            candidateSchemaVersion: candidateSchemaVersion,
            formulaVersion: formulaVersion,
            formulaFingerprint: try formulaFingerprint(for: rubric),
            sourceAssessmentID: sourceAssessmentID,
            goalID: rubric.goalID,
            localeCode: locale.code,
            score0To100: weightedObservedScore.map(integerScore),
            confidence: rounded(candidateConfidence),
            evidenceDepth: depth,
            evidenceWeightCoverage: rounded(coverage),
            observedDimensionCount: observedDimensions.count,
            totalDimensionCount: rubric.dimensions.count,
            dimensions: renderedDimensions,
            missingDimensionIDs: renderedDimensions
                .filter { $0.score0To100 == nil }
                .map(\.dimensionID),
            insufficiencyReasons: insufficiency,
            qualitativeEvidenceLevel: qualitativeEvidenceLevel,
            qualitativeMovement: qualitativeMovement
        )
    }

    private static func validate(rubric: GoalRubric) throws {
        guard isOpaqueIdentifier(rubric.goalID), !rubric.dimensions.isEmpty else {
            throw GoalStyleCalibrationError.invalidRubric("missing goal or dimensions")
        }
        let ids = rubric.dimensions.map(\.id)
        guard Set(ids).count == ids.count,
              ids.allSatisfy(isOpaqueIdentifier) else {
            throw GoalStyleCalibrationError.invalidRubric("invalid or duplicate dimension IDs")
        }
        guard Set(rubric.defaultWeights.keys) == Set(ids) else {
            throw GoalStyleCalibrationError.invalidRubric("weights must match dimensions exactly")
        }
        let weights = ids.compactMap { rubric.defaultWeights[$0] }
        guard weights.allSatisfy({ $0.isFinite && $0 > 0 }),
              weights.reduce(0, +) > 0 else {
            throw GoalStyleCalibrationError.invalidRubric("weights must be finite and positive")
        }
        if let floor = rubric.establishedEvidenceFloor,
           (!floor.isFinite || !(0...1).contains(floor)) {
            throw GoalStyleCalibrationError.invalidRubric("invalid evidence floor")
        }
    }

    private static func integerScore(_ value: Double) -> Int {
        Int((bounded(value) * 100).rounded(.toNearestOrAwayFromZero))
    }

    private static func bounded(_ value: Double) -> Double {
        min(1, max(0, value.isFinite ? value : 0))
    }

    fileprivate static func rounded(_ value: Double) -> Double {
        (value * 10_000).rounded(.toNearestOrAwayFromZero) / 10_000
    }

    fileprivate static func isOpaqueIdentifier(_ value: String) -> Bool {
        guard !value.isEmpty, value.utf8.count <= 120 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._:"))
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }

    fileprivate static func stableFingerprint(_ value: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01b3
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        let hex = String(hash, radix: 16)
        return "fnv1a64:\(String(repeating: "0", count: max(0, 16 - hex.count)))\(hex)"
    }

    private static func canonical(_ value: Double) -> String {
        String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), value)
    }

    private static func canonicalField(_ name: String, _ value: String) -> String {
        "\(name)=\(value.utf8.count):\(value)"
    }
}

// MARK: - Blinded professional calibration packet

enum GoalStyleCalibrationRubricOrigin: String, Codable, Equatable {
    case canonical
    case proposedExplicitRubric
}

struct GoalStyleCalibrationPacketCase: Equatable {
    let calibrationCaseID: String
    let rubricOrigin: GoalStyleCalibrationRubricOrigin
    let rubric: GoalRubric
    let candidate: GoalStyleCalibrationCandidate
}

struct GoalStyleCalibrationPacket: Codable, Equatable {
    static let schemaVersion = "goal-style-score-professional-calibration-v1"
    static let reviewResultsSchemaVersion = "goal-style-score-professional-calibration-results-v1"
    static let evidencePackageSchemaVersion = "goal-style-score-source-evidence-package-v1"
    static let artifactFileName = "goal-style-score-professional-calibration-v1.json"

    let schemaVersion: String
    let packetFingerprint: String
    let formulaVersion: String
    let humanGateStatus: String
    let evidencePackageRequirement: GoalStyleCalibrationEvidencePackageRequirement
    let privacyContract: String
    let instructions: String
    let responseSchema: String
    let caseCount: Int
    let rows: [GoalStyleCalibrationPacketRow]

    static func make(
        from cases: [GoalStyleCalibrationPacketCase],
        evidencePackage: GoalStyleCalibrationEvidencePackageDescriptor? = nil
    ) throws -> GoalStyleCalibrationPacket {
        let rows = try cases
            .sorted { $0.calibrationCaseID < $1.calibrationCaseID }
            .map { item -> GoalStyleCalibrationPacketRow in
                guard GoalStyleCalibrationEngine.isOpaqueIdentifier(item.calibrationCaseID),
                      item.rubric.goalID == item.candidate.goalID,
                      try GoalStyleCalibrationEngine.formulaFingerprint(for: item.rubric) == item.candidate.formulaFingerprint else {
                    throw GoalStyleCalibrationError.invalidRubric("packet case does not match candidate")
                }
                return GoalStyleCalibrationPacketRow(
                    calibrationCaseID: item.calibrationCaseID,
                    sourceAssessmentID: item.candidate.sourceAssessmentID,
                    rubricOrigin: item.rubricOrigin,
                    rubric: item.rubric,
                    candidate: item.candidate
                )
            }
        let requiredEvidenceReferenceIDs = Array(Set(
            rows.flatMap { row in
                row.candidate.dimensions.flatMap(\.evidenceReferenceIDs)
            }
        )).sorted()
        let evidencePackageRequirement = try evidencePackageRequirement(
            requiredEvidenceReferenceIDs: requiredEvidenceReferenceIDs,
            descriptor: evidencePackage
        )
        let packetFingerprint = fingerprint(
            rows: rows,
            evidencePackageRequirement: evidencePackageRequirement
        )
        return GoalStyleCalibrationPacket(
            schemaVersion: schemaVersion,
            packetFingerprint: packetFingerprint,
            formulaVersion: GoalStyleCalibrationEngine.formulaVersion,
            humanGateStatus: evidencePackageRequirement.packageFingerprint == nil
                ? "blockedPendingAccessControlledEvidencePackage"
                : "pendingProfessionalReview",
            evidencePackageRequirement: evidencePackageRequirement,
            privacyContract: "Opaque assessment and evidence-reference IDs only. No account identifier, raw transcript, audio, user-authored goal text, coach reply, or session content is included. Source evidence must be deidentified and delivered separately under access control; it must not be committed with this packet.",
            instructions: [
                "Blinded professional communication-coach calibration of deterministic 0-100 goal-style candidates.",
                "This packet alone is insufficient for review: every evidence reference ID must resolve in the separately delivered, access-controlled, deidentified source-evidence package bound by fingerprint.",
                "Do not submit or accept a review unless the reviewer accessed that package, examined the referenced evidence, and received a coordinator-issued access receipt.",
                "Rate the supplied rubric and evidence coverage independently; a candidate score is not a product claim.",
                "Check whether missing dimensions were withheld rather than imputed and whether confidence matches evidence depth.",
                "For proposed goals, reject any row whose explicit rubric is not behaviorally observable or professionally defensible.",
                "Do not approve product UI from this packet alone; reviewer agreement and longitudinal transfer evidence remain separate gates."
            ].joined(separator: " "),
            responseSchema: [
                "Return one JSON row per reviewer per calibration case using schema \(reviewResultsSchemaVersion).",
                "Echo packetFingerprint, evidencePackageFingerprint, calibrationCaseID, and formulaFingerprint exactly.",
                "Include reviewerID, reviewerRole, evidencePackageAccessReceiptID, reviewerAttestsEvidenceWasReviewed=true, independentScore0To100 (0-100), dimensionScores keyed by dimension ID (0-100 or null when unjudgeable), evidenceCoverageAppropriate (boolean), confidenceAppropriate (boolean), missingEvidenceHandledSafely (boolean), scoreWithinAcceptableTolerance (boolean), overclaimRisk (low|medium|high), and notes."
            ].joined(separator: " "),
            caseCount: rows.count,
            rows: rows
        )
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    func rejectionReasons(for submission: GoalStyleCalibrationReviewSubmission) -> [String] {
        var reasons: [String] = []
        if submission.schemaVersion != Self.reviewResultsSchemaVersion {
            reasons.append("schemaVersion")
        }
        if submission.sourcePacketFingerprint != packetFingerprint {
            reasons.append("sourcePacketFingerprint")
        }
        guard let expectedEvidencePackageFingerprint = evidencePackageRequirement.packageFingerprint else {
            reasons.append("evidencePackageNotBound")
            return Array(Set(reasons)).sorted()
        }
        if submission.sourceEvidencePackageFingerprint != expectedEvidencePackageFingerprint {
            reasons.append("sourceEvidencePackageFingerprint")
        }
        let rowsByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.calibrationCaseID, $0) })
        var reviewSlots = Set<String>()
        for review in submission.rows {
            guard let source = rowsByID[review.calibrationCaseID] else {
                reasons.append("unknownCase:\(review.calibrationCaseID)")
                continue
            }
            if review.formulaFingerprint != source.candidate.formulaFingerprint {
                reasons.append("formulaFingerprint:\(review.calibrationCaseID)")
            }
            if !GoalStyleCalibrationEngine.isOpaqueIdentifier(review.reviewerID) {
                reasons.append("reviewerID:\(review.calibrationCaseID)")
            }
            if !review.reviewerAttestsEvidenceWasReviewed {
                reasons.append("evidenceNotReviewed:\(review.calibrationCaseID)")
            }
            if !GoalStyleCalibrationEngine.isOpaqueIdentifier(
                review.evidencePackageAccessReceiptID ?? ""
            ) {
                reasons.append("evidenceAccessReceipt:\(review.calibrationCaseID)")
            }
            let slot = "\(review.calibrationCaseID)|\(review.reviewerID)"
            if !reviewSlots.insert(slot).inserted {
                reasons.append("duplicateReview:\(slot)")
            }
            if !(0...100).contains(review.independentScore0To100) {
                reasons.append("independentScore:\(review.calibrationCaseID)")
            }
        }
        return Array(Set(reasons)).sorted()
    }

    private static func evidencePackageRequirement(
        requiredEvidenceReferenceIDs: [String],
        descriptor: GoalStyleCalibrationEvidencePackageDescriptor?
    ) throws -> GoalStyleCalibrationEvidencePackageRequirement {
        if let descriptor {
            guard descriptor.schemaVersion == evidencePackageSchemaVersion,
                  GoalStyleCalibrationEngine.isOpaqueIdentifier(descriptor.packageID),
                  isSHA256Fingerprint(descriptor.packageFingerprint),
                  descriptor.containsDeidentifiedSourceEvidence,
                  Set(descriptor.evidenceReferenceIDs) == Set(requiredEvidenceReferenceIDs) else {
                throw GoalStyleCalibrationError.invalidEvidenceReference("evidence-package-binding")
            }
            return GoalStyleCalibrationEvidencePackageRequirement(
                schemaVersion: evidencePackageSchemaVersion,
                packageID: descriptor.packageID,
                packageFingerprint: descriptor.packageFingerprint,
                requiredEvidenceReferenceIDs: requiredEvidenceReferenceIDs,
                deliveryMode: "separateAccessControlledCoordinatorDelivery",
                sourceEvidenceIncludedInPacket: false,
                reviewWithoutEvidencePackageIsInvalid: true,
                bindingStatus: "bound"
            )
        }
        return GoalStyleCalibrationEvidencePackageRequirement(
            schemaVersion: evidencePackageSchemaVersion,
            packageID: nil,
            packageFingerprint: nil,
            requiredEvidenceReferenceIDs: requiredEvidenceReferenceIDs,
            deliveryMode: "separateAccessControlledCoordinatorDelivery",
            sourceEvidenceIncludedInPacket: false,
            reviewWithoutEvidencePackageIsInvalid: true,
            bindingStatus: "blockedUntilCoordinatorBindsPackage"
        )
    }

    private static func isSHA256Fingerprint(_ value: String) -> Bool {
        guard value.hasPrefix("sha256:") else { return false }
        let hex = value.dropFirst("sha256:".count)
        return hex.count == 64 && hex.allSatisfy { $0.isHexDigit }
    }

    private static func fingerprint(
        rows: [GoalStyleCalibrationPacketRow],
        evidencePackageRequirement: GoalStyleCalibrationEvidencePackageRequirement
    ) -> String {
        let rowContract = rows.map { row in
            let dimensions = row.candidate.dimensions.map { dimension in
                [
                    dimension.dimensionID,
                    dimension.score0To100.map(String.init) ?? "missing",
                    dimension.evidenceReferenceIDs.joined(separator: ",")
                ].joined(separator: "|")
            }.joined(separator: ";")
            return [
                row.calibrationCaseID,
                row.sourceAssessmentID,
                row.rubricOrigin.rawValue,
                row.candidate.formulaFingerprint,
                row.candidate.score0To100.map(String.init) ?? "missing",
                dimensions
            ].joined(separator: "|")
        }.joined(separator: "\n")
        let evidenceContract = [
            evidencePackageRequirement.schemaVersion,
            evidencePackageRequirement.packageID ?? "unbound",
            evidencePackageRequirement.packageFingerprint ?? "unbound",
            evidencePackageRequirement.requiredEvidenceReferenceIDs.joined(separator: ","),
            evidencePackageRequirement.bindingStatus
        ].joined(separator: "|")
        return GoalStyleCalibrationEngine.stableFingerprint(rowContract + "\n" + evidenceContract)
    }
}

struct GoalStyleCalibrationPacketRow: Codable, Equatable {
    let calibrationCaseID: String
    let sourceAssessmentID: String
    let rubricOrigin: GoalStyleCalibrationRubricOrigin
    let rubric: GoalRubric
    let candidate: GoalStyleCalibrationCandidate
}

struct GoalStyleCalibrationReviewSubmission: Codable, Equatable {
    let schemaVersion: String
    let sourcePacketFingerprint: String
    let sourceEvidencePackageFingerprint: String?
    let rows: [GoalStyleCalibrationReviewRow]
}

struct GoalStyleCalibrationReviewRow: Codable, Equatable {
    let calibrationCaseID: String
    let formulaFingerprint: String
    let reviewerID: String
    let reviewerRole: String
    let evidencePackageAccessReceiptID: String?
    let reviewerAttestsEvidenceWasReviewed: Bool
    let independentScore0To100: Int
    let dimensionScores: [String: Int?]
    let evidenceCoverageAppropriate: Bool
    let confidenceAppropriate: Bool
    let missingEvidenceHandledSafely: Bool
    let scoreWithinAcceptableTolerance: Bool
    let overclaimRisk: String
    let notes: String
}

struct GoalStyleCalibrationEvidencePackageDescriptor: Equatable {
    let schemaVersion: String
    let packageID: String
    let packageFingerprint: String
    let evidenceReferenceIDs: [String]
    let containsDeidentifiedSourceEvidence: Bool
}

struct GoalStyleCalibrationEvidencePackageRequirement: Codable, Equatable {
    let schemaVersion: String
    let packageID: String?
    let packageFingerprint: String?
    let requiredEvidenceReferenceIDs: [String]
    let deliveryMode: String
    let sourceEvidenceIncludedInPacket: Bool
    let reviewWithoutEvidencePackageIsInvalid: Bool
    let bindingStatus: String
}
