//
//  CoachChatEvaluationFixtures.swift
//  NoumTests
//
//  Version-controlled Ask Noum evaluation fixtures.
//  SUBSTRATE ONLY: these fixtures are regression guards, not expert
//  calibration and not proof of human-coach parity.
//

import Foundation
import Testing
@testable import Noum

enum CoachChatEvaluationPillar: String, CaseIterable, Codable {
    case diagnosis
    case prescription
    case adaptation
    case transfer
    case honesty
    case validation
}

enum CoachChatExpertBaselineStatus: String, Codable, Equatable {
    case pendingExpertReview
}

struct CoachChatExpertBaselineSlot: Codable, Equatable {
    let status: CoachChatExpertBaselineStatus
    let baselineID: String?
    let coachSummary: String?
    let scoringRubricVersion: String

    static let pending = CoachChatExpertBaselineSlot(
        status: .pendingExpertReview,
        baselineID: nil,
        coachSummary: nil,
        scoringRubricVersion: "coach-chat-eval-v1"
    )
}

struct CoachChatEvaluationFixture {
    let id: String
    let pillar: CoachChatEvaluationPillar
    let expertBaseline: CoachChatExpertBaselineSlot
    let profile: CoachingProfile?
    let sessions: [PracticeSession]
    let trends: [SkillTrend]
    let latestUserTurn: String
    let previousCoachReply: String?
    let expectedContextNeedles: [String]
    let referenceReply: String
    let knownBadReply: String
    let expectedBadIssue: CoachChatReplyQualityIssue
}

struct CoachChatEvaluationCIReport: Codable, Equatable {
    let schemaVersion: String
    let fixtureCount: Int
    let rows: [CoachChatEvaluationCIReportRow]

    static func make(from fixtures: [CoachChatEvaluationFixture]) -> CoachChatEvaluationCIReport {
        CoachChatEvaluationCIReport(
            schemaVersion: CoachChatEvaluationCorpus.reportSchemaVersion,
            fixtureCount: fixtures.count,
            rows: fixtures.map { fixture in
                let context = CoachChatEvaluationCorpus.renderedContext(for: fixture)
                let missingContextNeedles = fixture.expectedContextNeedles.filter {
                    !CoachChatEvaluationCorpus.contains(context, $0)
                }
                let recentTurns = fixture.previousCoachReply.map {
                    [CoachMessage(role: .coach, text: $0)]
                } ?? []
                let turnDepth = TurnDepthClassifier.classify(
                    userText: fixture.latestUserTurn,
                    recentTurns: recentTurns
                )
                let referenceResult = AICoachChatService.professionalCoachRubric(
                    reply: fixture.referenceReply,
                    latestUserTurn: fixture.latestUserTurn
                )
                let referenceVision = AICoachChatService.coachVisionEvaluation(
                    reply: fixture.referenceReply,
                    latestUserTurn: fixture.latestUserTurn,
                    quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                    systemContext: context
                )
                let referenceIssue = AICoachChatService.replyQualityIssue(
                    in: fixture.referenceReply,
                    latestUserTurn: fixture.latestUserTurn,
                    quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                    systemContext: context
                )
                let referenceVisionRuntimeIssue = AICoachChatService.visionQualityIssue(
                    in: fixture.referenceReply,
                    latestUserTurn: fixture.latestUserTurn,
                    quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                    systemContext: context
                )
                let referenceReliability = CoachReliabilityGate.evaluate(
                    replyText: fixture.referenceReply,
                    previousCoachReply: fixture.previousCoachReply,
                    turnDepth: turnDepth,
                    assessment: nil,
                    evidenceCoverage: nil,
                    surface: .text
                )
                let issue = AICoachChatService.replyQualityIssue(
                    in: fixture.knownBadReply,
                    latestUserTurn: fixture.latestUserTurn,
                    quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                    systemContext: context
                )
                let knownBadVision = AICoachChatService.coachVisionEvaluation(
                    reply: fixture.knownBadReply,
                    latestUserTurn: fixture.latestUserTurn,
                    quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                    systemContext: context
                )
                let knownBadVisionRuntimeIssue = AICoachChatService.visionQualityIssue(
                    in: fixture.knownBadReply,
                    latestUserTurn: fixture.latestUserTurn,
                    quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                    systemContext: context
                )
                let knownBadReliability = CoachReliabilityGate.evaluate(
                    replyText: fixture.knownBadReply,
                    previousCoachReply: fixture.previousCoachReply,
                    turnDepth: turnDepth,
                    assessment: nil,
                    evidenceCoverage: nil,
                    surface: .text
                )
                let referencePassesReliabilityGate = referenceReliability.issues.isEmpty
                return CoachChatEvaluationCIReportRow(
                    fixtureID: fixture.id,
                    pillar: fixture.pillar.rawValue,
                    expertBaselineStatus: fixture.expertBaseline.status.rawValue,
                    turnDepth: turnDepth.rawValue,
                    referenceReplyPassesRubric: referenceResult.passesSeniorCoachFloor,
                    referenceReplyPassesQualityGate: referenceIssue == nil,
                    referenceVisionScore: referenceVision.score,
                    referencePassesVisionFloor: referenceVision.passesProductionFloor,
                    referencePassesVisionRuntimeGate: referenceVisionRuntimeIssue == nil,
                    referenceReliabilityIssues: referenceReliability.issues.map(\.rawValue),
                    referencePassesReliabilityGate: referencePassesReliabilityGate,
                    referencePassesProductionFloor: referenceResult.passesSeniorCoachFloor &&
                        referenceIssue == nil &&
                        referenceVision.passesProductionFloor &&
                        referenceVisionRuntimeIssue == nil &&
                        referencePassesReliabilityGate &&
                        missingContextNeedles.isEmpty,
                    knownBadIssueMatched: issue == fixture.expectedBadIssue,
                    knownBadVisionScore: knownBadVision.score,
                    knownBadTripsVisionRuntimeGate: knownBadVisionRuntimeIssue != nil,
                    knownBadReliabilityIssues: knownBadReliability.issues.map(\.rawValue),
                    knownBadTripsReliabilityGate: !knownBadReliability.issues.isEmpty,
                    expectedBadIssue: String(describing: fixture.expectedBadIssue),
                    contextNeedleCount: fixture.expectedContextNeedles.count,
                    contextNeedlesPassed: missingContextNeedles.isEmpty,
                    missingContextNeedles: missingContextNeedles
                )
            }
        )
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct CoachChatEvaluationCIReportRow: Codable, Equatable {
    let fixtureID: String
    let pillar: String
    let expertBaselineStatus: String
    let turnDepth: String
    let referenceReplyPassesRubric: Bool
    let referenceReplyPassesQualityGate: Bool
    let referenceVisionScore: Int
    let referencePassesVisionFloor: Bool
    let referencePassesVisionRuntimeGate: Bool
    let referenceReliabilityIssues: [String]
    let referencePassesReliabilityGate: Bool
    let referencePassesProductionFloor: Bool
    let knownBadIssueMatched: Bool
    let knownBadVisionScore: Int
    let knownBadTripsVisionRuntimeGate: Bool
    let knownBadReliabilityIssues: [String]
    let knownBadTripsReliabilityGate: Bool
    let expectedBadIssue: String
    let contextNeedleCount: Int
    let contextNeedlesPassed: Bool
    let missingContextNeedles: [String]
}

enum CoachChatConversationCriterion: String, Codable, Equatable, CaseIterable {
    case directAnswer
    case evidenceCalibration
    case observableAnchor
    case prescribedPractice
    case rationaleBridge
    case followupContinuity
    case stateRetention
    case nonRepetitiveTrajectory
    case proofTestProgression
    case adaptiveRepair
    case repairCarryover
    case transferProof
    case seniorRegister
    case brevity
}

struct CoachChatConversationTurn: Codable, Equatable {
    let userTurn: String
    let coachReply: String
}

struct CoachChatConversationFixture: Codable, Equatable {
    let id: String
    let sourceFixtureID: String
    let turns: [CoachChatConversationTurn]
}

struct CoachChatConversationScore: Codable, Equatable {
    let score: Int
    let earned: [CoachChatConversationCriterion]
    let missed: [CoachChatConversationCriterion]
    let turnVisionScores: [Int]
    let lowestTurnVisionScore: Int

    var passesConversationFloor: Bool {
        score >= 82 &&
        lowestTurnVisionScore >= 45 &&
        !missed.contains(.directAnswer) &&
        !missed.contains(.evidenceCalibration) &&
        !missed.contains(.prescribedPractice) &&
        !missed.contains(.stateRetention) &&
        !missed.contains(.nonRepetitiveTrajectory) &&
        !missed.contains(.proofTestProgression) &&
        !missed.contains(.seniorRegister)
    }
}

struct CoachChatConversationEvaluationReport: Codable, Equatable {
    let schemaVersion: String
    let conversationCount: Int
    let visionProductionReadiness: CoachVisionProductionReadinessAudit
    let summary: CoachChatConversationEvaluationSummary
    let rows: [CoachChatConversationEvaluationReportRow]

    static func make(
        from conversations: [CoachChatConversationFixture],
        schemaVersion: String = CoachChatConversationCorpus.reportSchemaVersion
    ) -> CoachChatConversationEvaluationReport {
        let rows = conversations.map { conversation in
            let score = CoachChatConversationCorpus.evaluate(conversation)
            let reliabilityIssuesByTurn = CoachChatConversationCorpus
                .reliabilityIssuesByTurn(in: conversation)
            let runtimeIssuesByTurn = CoachChatConversationCorpus
                .runtimeIssueLabelsByTurn(in: conversation)
            let semanticIssuesByTurn = CoachChatConversationCorpus
                .semanticIssueLabelsByTurn(in: conversation)
            let turnDepths = CoachChatConversationCorpus.turnDepthsByTurn(in: conversation)
            let trustRepairTurnIndices = CoachChatConversationCorpus
                .trustRepairTurnIndices(in: conversation)
            let coldnessComplaintTurnIndices = CoachChatConversationCorpus
                .coldnessComplaintTurnIndices(in: conversation)
            let softPushbackTurnIndices = CoachChatConversationCorpus
                .softPushbackTurnIndices(in: conversation)
            let passesRuntimeGate = runtimeIssuesByTurn.allSatisfy(\.isEmpty)
            let passesSemanticGate = semanticIssuesByTurn.allSatisfy(\.isEmpty)
            let passesReliabilityGate = reliabilityIssuesByTurn.allSatisfy(\.isEmpty)
            return CoachChatConversationEvaluationReportRow(
                conversationID: conversation.id,
                sourceFixtureID: conversation.sourceFixtureID,
                turns: conversation.turns,
                score: score.score,
                passesConversationFloor: score.passesConversationFloor,
                passesRuntimeGate: passesRuntimeGate,
                passesSemanticGate: passesSemanticGate,
                passesReliabilityGate: passesReliabilityGate,
                passesProductionFloor: score.passesConversationFloor &&
                    passesRuntimeGate &&
                    passesSemanticGate &&
                    passesReliabilityGate,
                turnVisionScores: score.turnVisionScores,
                turnRuntimeIssues: runtimeIssuesByTurn,
                runtimeIssues: runtimeIssuesByTurn.flatMap { $0 },
                turnSemanticIssues: semanticIssuesByTurn,
                semanticIssues: semanticIssuesByTurn.flatMap { $0 },
                turnReliabilityIssues: reliabilityIssuesByTurn.map { issues in
                    issues.map(\.rawValue)
                },
                reliabilityIssues: reliabilityIssuesByTurn
                    .flatMap { $0 }
                    .map(\.rawValue),
                turnDepths: turnDepths.map(\.rawValue),
                trustRepairTurnIndices: trustRepairTurnIndices,
                userPushbackWithinTwoTurns: CoachChatConversationCorpus
                    .userPushbackWithinTwoTurns(in: conversation),
                coldnessComplaintFlag: !coldnessComplaintTurnIndices.isEmpty,
                coldnessComplaintTurnIndices: coldnessComplaintTurnIndices,
                softPushbackFlag: !softPushbackTurnIndices.isEmpty,
                softPushbackTurnIndices: softPushbackTurnIndices,
                lowestTurnVisionScore: score.lowestTurnVisionScore,
                earned: score.earned.map(\.rawValue),
                missed: score.missed.map(\.rawValue)
            )
        }
        let localTargetShapeScore = CoachVisionProductionReadinessAudit
            .localTargetShapeScore(rows: rows)
        let readiness = CoachVisionProductionReadinessAudit.make(
            localTargetShapeScore: localTargetShapeScore,
            evidence: .currentLocalSubstrate(
                conversationCount: conversations.count,
                rowsPassingProductionFloor: rows.filter(\.passesProductionFloor).count
            )
        )
        let summary = CoachChatConversationEvaluationSummary.make(rows: rows)
        return CoachChatConversationEvaluationReport(
            schemaVersion: schemaVersion,
            conversationCount: conversations.count,
            visionProductionReadiness: readiness,
            summary: summary,
            rows: rows
        )
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct CoachChatConversationEvaluationSummary: Codable, Equatable {
    let rowsPassingConversationFloor: Int
    let rowsPassingRuntimeGate: Int
    let rowsPassingSemanticGate: Int
    let rowsPassingReliabilityGate: Int
    let rowsPassingProductionFloor: Int
    let productionFloorFailureConversationIDs: [String]
    let runtimeIssueCounts: [String: Int]
    let semanticIssueCounts: [String: Int]
    let reliabilityIssueCounts: [String: Int]
    let turnDepthCounts: [String: Int]

    static func make(
        rows: [CoachChatConversationEvaluationReportRow]
    ) -> CoachChatConversationEvaluationSummary {
        CoachChatConversationEvaluationSummary(
            rowsPassingConversationFloor: rows.filter(\.passesConversationFloor).count,
            rowsPassingRuntimeGate: rows.filter(\.passesRuntimeGate).count,
            rowsPassingSemanticGate: rows.filter(\.passesSemanticGate).count,
            rowsPassingReliabilityGate: rows.filter(\.passesReliabilityGate).count,
            rowsPassingProductionFloor: rows.filter(\.passesProductionFloor).count,
            productionFloorFailureConversationIDs: rows
                .filter { !$0.passesProductionFloor }
                .map(\.conversationID),
            runtimeIssueCounts: counts(rows.flatMap(\.runtimeIssues)),
            semanticIssueCounts: counts(rows.flatMap(\.semanticIssues)),
            reliabilityIssueCounts: counts(rows.flatMap(\.reliabilityIssues)),
            turnDepthCounts: counts(rows.flatMap(\.turnDepths))
        )
    }

    private static func counts(_ values: [String]) -> [String: Int] {
        values.reduce(into: [:]) { partial, value in
            partial[value, default: 0] += 1
        }
    }
}

struct CoachChatConversationEvaluationReportRow: Codable, Equatable {
    let conversationID: String
    let sourceFixtureID: String
    let turns: [CoachChatConversationTurn]
    let score: Int
    let passesConversationFloor: Bool
    let passesRuntimeGate: Bool
    let passesSemanticGate: Bool
    let passesReliabilityGate: Bool
    let passesProductionFloor: Bool
    let turnVisionScores: [Int]
    let turnRuntimeIssues: [[String]]
    let runtimeIssues: [String]
    let turnSemanticIssues: [[String]]
    let semanticIssues: [String]
    let turnReliabilityIssues: [[String]]
    let reliabilityIssues: [String]
    let turnDepths: [String]
    let trustRepairTurnIndices: [Int]
    let userPushbackWithinTwoTurns: Bool
    let coldnessComplaintFlag: Bool
    let coldnessComplaintTurnIndices: [Int]
    let softPushbackFlag: Bool
    let softPushbackTurnIndices: [Int]
    let lowestTurnVisionScore: Int
    let earned: [String]
    let missed: [String]
}

struct CoachChatConversationExpertCalibrationPacket: Codable, Equatable {
    let schemaVersion: String
    let rubricVersion: String
    let sourceCorpusFingerprint: String
    let humanGateStatus: CoachChatExpertBaselineStatus
    let instructions: String
    let responseSchema: String
    let conversationCount: Int
    let requiredIndependentReviewsPerConversation: Int
    let requiredReviewCount: Int
    let rows: [CoachChatConversationExpertCalibrationPacketRow]

    static func make(
        from conversations: [CoachChatConversationFixture]
    ) -> CoachChatConversationExpertCalibrationPacket {
        CoachChatConversationExpertCalibrationPacket(
            schemaVersion: CoachChatConversationCorpus.expertCalibrationPacketSchemaVersion,
            rubricVersion: CoachProfessionalCalibrationEvidence.expectedRubricVersion,
            sourceCorpusFingerprint: sourceCorpusFingerprint(for: conversations),
            humanGateStatus: .pendingExpertReview,
            instructions: [
                "Blinded professional-coach review packet: compare Noum's full multi-turn coaching conversation against what an excellent human communication coach would do.",
                "Use the supplied user turns, candidate coach replies, and Noum context only; do not assume the app is validated or production-ready.",
                "Evaluate diagnosis, case formulation, intervention, adaptation, perception limits, transfer setup, trust repair, and evidence calibration across the whole conversation.",
                "Each conversation needs at least two independent professional communication-coach reviews before it can count as calibration evidence.",
                "Prefer useful, attuned, evidence-led coaching over polished generic advice; mark thin evidence and overclaims explicitly.",
                "This packet gathers human calibration evidence only. Do not treat a completed packet as production readiness without longitudinal user outcomes and real-device QA."
            ].joined(separator: " "),
            responseSchema: [
                "Return one JSON object per reviewer per conversation:",
                "{\"conversationID\": string,",
                "\"reviewerID\": string,",
                "\"ratings\": {\"diagnosis\": 1-5, \"caseFormulation\": 1-5, \"intervention\": 1-5, \"adaptation\": 1-5, \"perceptionHonesty\": 1-5, \"transferSetup\": 1-5, \"trustRepair\": 1-5, \"overallUsefulness\": 1-5},",
                "\"calibrationDecision\": \"expertBetter|noumBetter|roughTie|unsafeOrUnready\",",
                "\"humanCoachReference\": [{\"turnIndex\": number, \"idealCoachMove\": string, \"evidenceUsed\": [string], \"uncertainty\": string}],",
                "\"overclaimNotes\": [string], \"revisionNotes\": [string], \"wouldUseWithClient\": boolean}."
            ].joined(separator: " "),
            conversationCount: conversations.count,
            requiredIndependentReviewsPerConversation:
                CoachProfessionalCalibrationEvidence.requiredReviewsPerConversation,
            requiredReviewCount: conversations.count *
                CoachProfessionalCalibrationEvidence.requiredReviewsPerConversation,
            rows: conversations.map { conversation in
                let source = CoachChatEvaluationCorpus.fixtures.first {
                    $0.id == conversation.sourceFixtureID
                }
                return CoachChatConversationExpertCalibrationPacketRow(
                    conversationID: conversation.id,
                    sourceFixtureID: conversation.sourceFixtureID,
                    sourcePillar: source?.pillar.rawValue,
                    expertBaselineStatus: source?.expertBaseline.status.rawValue ??
                        CoachChatExpertBaselineStatus.pendingExpertReview.rawValue,
                    coachContext: source.map(CoachChatEvaluationCorpus.renderedContext(for:)),
                    turns: conversation.turns,
                    turnDepths: CoachChatConversationCorpus
                        .turnDepthsByTurn(in: conversation)
                        .map(\.rawValue),
                    trustRepairTurnIndices: CoachChatConversationCorpus
                        .trustRepairTurnIndices(in: conversation),
                    coldnessComplaintTurnIndices: CoachChatConversationCorpus
                        .coldnessComplaintTurnIndices(in: conversation),
                    softPushbackTurnIndices: CoachChatConversationCorpus
                        .softPushbackTurnIndices(in: conversation)
                )
            }
        )
    }

    static func sourceCorpusFingerprint(
        for conversations: [CoachChatConversationFixture]
    ) -> String {
        let canonical = conversations
            .sorted { $0.id < $1.id }
            .map { conversation -> String in
                let turnText = conversation.turns.enumerated().flatMap { index, turn in
                    [
                        canonicalField("turnIndex=\(index)"),
                        canonicalField("user=\(turn.userTurn)"),
                        canonicalField("coach=\(turn.coachReply)")
                    ]
                }.joined(separator: "|")
                return [
                    canonicalField("conversationID=\(conversation.id)"),
                    canonicalField("sourceFixtureID=\(conversation.sourceFixtureID)"),
                    canonicalField("turnCount=\(conversation.turns.count)"),
                    turnText
                ].joined(separator: "|")
            }
            .joined(separator: "\n")
        let hex = String(fnv1a64(canonical), radix: 16)
        return "fnv1a64:\(String(repeating: "0", count: max(0, 16 - hex.count)))\(hex)"
    }

    private static func canonicalField(_ value: String) -> String {
        "\(value.utf8.count):\(value)"
    }

    private static func fnv1a64(_ value: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        let prime: UInt64 = 0x0000_0100_0000_01b3
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }
        return hash
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct CoachChatConversationExpertCalibrationPacketRow: Codable, Equatable {
    let conversationID: String
    let sourceFixtureID: String
    let sourcePillar: String?
    let expertBaselineStatus: String
    let coachContext: String?
    let turns: [CoachChatConversationTurn]
    let turnDepths: [String]
    let trustRepairTurnIndices: [Int]
    let coldnessComplaintTurnIndices: [Int]
    let softPushbackTurnIndices: [Int]
}

struct CoachProfessionalCalibrationEvidence: Codable, Equatable {
    static let expectedSchemaVersion = "coach-chat-conversation-expert-calibration-results-v2"
    static let expectedRubricVersion = "coach-parity-conversation-calibration-v2"
    static let requiredReviewsPerConversation = 2
    static let requiredConversationIDs = CoachChatConversationCorpus
        .professionalCalibrationConversations
        .map(\.id)
    static var expectedSourcePacketFingerprint: String {
        CoachChatConversationExpertCalibrationPacket.sourceCorpusFingerprint(
            for: CoachChatConversationCorpus.professionalCalibrationConversations
        )
    }
    static var requiredCalibrationReviewCount: Int {
        requiredConversationIDs.count * requiredReviewsPerConversation
    }

    let schemaVersion: String
    let sourcePacketSchemaVersion: String
    let sourcePacketFingerprint: String?
    let rubricVersion: String
    let reviewerRole: String
    let reviewCount: Int
    let summary: Summary
    let rows: [Row]

    var rowsPassingCalibrationFloor: Int {
        qualifiesForReadiness ? rows.filter(\.passesCalibrationFloor).count : 0
    }

    var qualifiesForReadiness: Bool {
        rejectionReasons.isEmpty
    }

    var rejectionReasons: [String] {
        var reasons: [String] = []
        let passingRows = rows.filter(\.passesCalibrationFloor)
        let uniqueConversationIDs = Set(rows.map(\.conversationID))
        let uniqueReviewerIDs = Set(rows.map(\.reviewerID).filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        })
        let rowsByConversationID = Dictionary(grouping: rows, by: \.conversationID)
        let passingRowsByConversationID = Dictionary(grouping: passingRows, by: \.conversationID)
        let reviewSlots = rows.map {
            "\($0.conversationID)|\($0.reviewerID.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        let uniqueReviewSlots = Set(reviewSlots)
        if schemaVersion != Self.expectedSchemaVersion {
            reasons.append("schemaVersion=\(schemaVersion)")
        }
        if sourcePacketSchemaVersion != CoachChatConversationCorpus.expertCalibrationPacketSchemaVersion {
            reasons.append("sourcePacketSchemaVersion=\(sourcePacketSchemaVersion)")
        }
        let trimmedSourcePacketFingerprint = sourcePacketFingerprint?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedSourcePacketFingerprint.isEmpty {
            reasons.append("sourcePacketFingerprintMissing")
        } else if trimmedSourcePacketFingerprint != Self.expectedSourcePacketFingerprint {
            reasons.append("sourcePacketFingerprintMismatch")
        }
        if rubricVersion != Self.expectedRubricVersion {
            reasons.append("rubricVersion=\(rubricVersion)")
        }
        if reviewCount < Self.requiredCalibrationReviewCount ||
            rows.count < Self.requiredCalibrationReviewCount {
            reasons.append("fewerThanRequiredReviews")
        }
        if reviewCount < Self.requiredCalibrationReviewCount ||
            rows.count < Self.requiredCalibrationReviewCount {
            reasons.append("missingFullConversationCoverage")
        }
        if reviewCount != rows.count || summary.rowCount != rows.count {
            reasons.append("rowCountMismatch")
        }
        if uniqueReviewSlots.count != rows.count {
            reasons.append("duplicateConversationReviewerPairs")
        }
        let missingConversationIDs = Self.requiredConversationIDs.filter {
            !uniqueConversationIDs.contains($0)
        }
        if !missingConversationIDs.isEmpty {
            reasons.append("missingRequiredConversations=\(missingConversationIDs.joined(separator: ","))")
        }
        let unexpectedConversationIDs = uniqueConversationIDs
            .filter { !Self.requiredConversationIDs.contains($0) }
            .sorted()
        if !unexpectedConversationIDs.isEmpty {
            reasons.append("unexpectedConversationIDs=\(unexpectedConversationIDs.joined(separator: ","))")
        }
        let insufficientReviewConversationIDs = Self.requiredConversationIDs.filter {
            (rowsByConversationID[$0]?.count ?? 0) < Self.requiredReviewsPerConversation
        }
        if !insufficientReviewConversationIDs.isEmpty {
            reasons.append(
                "insufficientReviewsPerConversation=\(insufficientReviewConversationIDs.joined(separator: ","))"
            )
        }
        let insufficientPassingConversationIDs = Self.requiredConversationIDs.filter {
            (passingRowsByConversationID[$0]?.count ?? 0) < Self.requiredReviewsPerConversation
        }
        if !insufficientPassingConversationIDs.isEmpty {
            reasons.append(
                "insufficientPassingReviewsPerConversation=\(insufficientPassingConversationIDs.joined(separator: ","))"
            )
        }
        let insufficientReviewerDiversityIDs = Self.requiredConversationIDs.filter { conversationID in
            let reviewerIDs = Set((rowsByConversationID[conversationID] ?? []).map {
                $0.reviewerID.trimmingCharacters(in: .whitespacesAndNewlines)
            }.filter { !$0.isEmpty })
            return reviewerIDs.count < Self.requiredReviewsPerConversation
        }
        if !insufficientReviewerDiversityIDs.isEmpty {
            reasons.append(
                "insufficientReviewerDiversity=\(insufficientReviewerDiversityIDs.joined(separator: ","))"
            )
        }
        if summary.reviewerCount != uniqueReviewerIDs.count ||
            summary.reviewerCount < Self.requiredReviewsPerConversation ||
            reviewerRole.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            rows.contains(where: { $0.reviewerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            reasons.append("missingProfessionalReviewer")
        }
        if summary.completedReviewCount != rows.count {
            reasons.append("incompleteReviews")
        }
        if summary.passingCalibrationCount != passingRows.count ||
            summary.passingCalibrationCount < Self.requiredCalibrationReviewCount {
            reasons.append("insufficientPassingCalibrationRows")
        }
        if summary.wouldUseWithClientCount < Self.requiredCalibrationReviewCount {
            reasons.append("insufficientWouldUseWithClientRows")
        }
        if summary.unsafeOrUnreadyCount > 0 ||
            rows.contains(where: { $0.calibrationDecision == "unsafeOrUnready" }) {
            reasons.append("unsafeOrUnreadyRows")
        }
        if rows.contains(where: { !$0.passesCalibrationFloor }) {
            reasons.append("rowCalibrationFloorFailures")
        }
        if passingRows.contains(where: { !$0.revisionNotes.isEmpty }) {
            reasons.append("unresolvedRevisionNotes")
        }
        if summary.minimumOverallUsefulness < 4 ||
            summary.averageOverallUsefulness < 4.0 {
            reasons.append("overallUsefulnessBelowFloor")
        }
        if !summary.readinessWarnings.isEmpty {
            reasons.append("readinessWarnings=\(summary.readinessWarnings.joined(separator: ","))")
        }
        return reasons
    }

    static func decode(from json: String) throws -> CoachProfessionalCalibrationEvidence {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(CoachProfessionalCalibrationEvidence.self, from: data)
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    struct Summary: Codable, Equatable {
        let rowCount: Int
        let reviewerCount: Int
        let completedReviewCount: Int
        let passingCalibrationCount: Int
        let wouldUseWithClientCount: Int
        let unsafeOrUnreadyCount: Int
        let averageOverallUsefulness: Double
        let minimumOverallUsefulness: Int
        let readinessWarnings: [String]
    }

    struct Row: Codable, Equatable {
        let conversationID: String
        let reviewerID: String
        let calibrationDecision: String
        let wouldUseWithClient: Bool
        let ratings: Ratings
        let humanCoachReferenceCount: Int
        let overclaimNotes: [String]
        let revisionNotes: [String]

        var passesCalibrationFloor: Bool {
            (calibrationDecision == "roughTie" || calibrationDecision == "noumBetter") &&
                wouldUseWithClient &&
                ratings.minimum >= 4 &&
                humanCoachReferenceCount > 0 &&
                overclaimNotes.isEmpty
        }
    }

    struct Ratings: Codable, Equatable {
        let diagnosis: Int
        let caseFormulation: Int
        let intervention: Int
        let adaptation: Int
        let perceptionHonesty: Int
        let transferSetup: Int
        let trustRepair: Int
        let overallUsefulness: Int

        var minimum: Int {
            [
                diagnosis,
                caseFormulation,
                intervention,
                adaptation,
                perceptionHonesty,
                transferSetup,
                trustRepair,
                overallUsefulness
            ].min() ?? 0
        }
    }
}

struct CoachRealUserTransferOutcomeEvidence: Codable, Equatable {
    static let expectedSchemaVersion = "coach-real-user-transfer-outcomes-v2"
    static let expectedProtocolVersion = "coach-transfer-outcome-ledger-v2"
    static let requiredOutcomeCount = 10
    static let requiredUniqueUserCount = 8
    static let requiredMomentCategoryCount = 4
    static let maximumOutcomesPerUser = 2
    static let minimumFollowUpDelayHours = 24

    let schemaVersion: String
    let studyProtocolVersion: String
    let cohortDescription: String
    let outcomeCount: Int
    let summary: Summary
    let rows: [Row]

    var rowsPassingOutcomeFloor: Int {
        qualifiesForReadiness ? rows.filter(\.passesOutcomeFloor).count : 0
    }

    var qualifiesForReadiness: Bool {
        rejectionReasons.isEmpty
    }

    var rejectionReasons: [String] {
        var reasons: [String] = []
        let passingRows = rows.filter(\.passesOutcomeFloor)
        let uniqueOutcomeIDs = Set(rows.map { Self.normalizedKey($0.outcomeID) })
        let uniqueUserIDs = Set(rows.map { Self.normalizedKey($0.userIDHash) })
        let uniqueMomentCategories = Set(rows.map { Self.normalizedKey($0.momentCategory) })
        let rowsByUser = Dictionary(grouping: rows, by: { Self.normalizedKey($0.userIDHash) })
        let maximumObservedOutcomesPerUser = rowsByUser.values.map(\.count).max() ?? 0
        let verifiedEvidenceReferenceRows = rows.filter(\.hasRequiredEvidenceReferences).count
        let minimumObservedFollowUpDelay = rows.map(\.followUpDelayHours).min() ?? 0
        let completedFollowUps = rows.filter(\.followUpCompleted).count
        let realWorldMoments = rows.filter(\.realWorldMomentOccurred).count
        let linkedInterventions = rows.filter { $0.linkedCoachInterventionCount > 0 }.count
        let positiveTransfer = rows.filter(\.positiveTransferReported).count
        let audienceEvidence = rows.filter(\.audienceResponseEvidenceCollected).count
        let noRegression = rows.filter { $0.postMomentConfidence >= $0.preMomentConfidence }.count
        let adverseOutcomes = rows.filter(\.adverseOutcomeReported).count
        let rowsMissingIdentity = rows.enumerated().compactMap { index, row -> String? in
            row.hasRequiredIdentity ? nil : row.outcomeIDForDiagnostics(index: index)
        }
        if schemaVersion != Self.expectedSchemaVersion {
            reasons.append("schemaVersion=\(schemaVersion)")
        }
        if studyProtocolVersion != Self.expectedProtocolVersion {
            reasons.append("studyProtocolVersion=\(studyProtocolVersion)")
        }
        if outcomeCount < Self.requiredOutcomeCount || rows.count < Self.requiredOutcomeCount {
            reasons.append("fewerThanTenOutcomes")
        }
        if outcomeCount != rows.count || summary.rowCount != rows.count {
            reasons.append("rowCountMismatch")
        }
        if uniqueOutcomeIDs.count != rows.count {
            reasons.append("duplicateOutcomeIDs")
        }
        if !rowsMissingIdentity.isEmpty {
            reasons.append("missingRowIdentity=\(rowsMissingIdentity.joined(separator: ","))")
        }
        if summary.uniqueUserCount != uniqueUserIDs.count ||
            summary.uniqueUserCount < Self.requiredUniqueUserCount {
            reasons.append("insufficientUniqueUsers")
        }
        if summary.uniqueMomentCategoryCount != uniqueMomentCategories.count ||
            summary.uniqueMomentCategoryCount < Self.requiredMomentCategoryCount {
            reasons.append("insufficientMomentCategoryDiversity")
        }
        if summary.maximumOutcomesPerUser != maximumObservedOutcomesPerUser ||
            maximumObservedOutcomesPerUser > Self.maximumOutcomesPerUser {
            reasons.append("excessiveOutcomesPerUser")
        }
        if summary.verifiedEvidenceReferenceCount != verifiedEvidenceReferenceRows ||
            verifiedEvidenceReferenceRows < Self.requiredOutcomeCount {
            reasons.append("insufficientEvidenceReferences")
        }
        if summary.minimumFollowUpDelayHours != minimumObservedFollowUpDelay ||
            minimumObservedFollowUpDelay < Self.minimumFollowUpDelayHours {
            reasons.append("insufficientFollowUpDelay")
        }
        if summary.completedFollowUpCount != completedFollowUps || completedFollowUps < 10 {
            reasons.append("insufficientCompletedFollowUps")
        }
        if summary.realWorldMomentCount != realWorldMoments || realWorldMoments < 10 {
            reasons.append("insufficientRealWorldMoments")
        }
        if summary.linkedInterventionOutcomeCount != linkedInterventions || linkedInterventions < 10 {
            reasons.append("insufficientLinkedInterventions")
        }
        if summary.positiveTransferCount != positiveTransfer || positiveTransfer < 10 {
            reasons.append("insufficientPositiveTransferOutcomes")
        }
        if summary.audienceResponseEvidenceCount != audienceEvidence || audienceEvidence < 10 {
            reasons.append("insufficientAudienceResponseEvidence")
        }
        if summary.noRegressionOutcomeCount != noRegression || noRegression < 10 {
            reasons.append("insufficientNoRegressionOutcomes")
        }
        if summary.adverseOutcomeCount != adverseOutcomes || adverseOutcomes > 0 {
            reasons.append("adverseOutcomesReported")
        }
        if summary.minimumDaysSinceFirstSession < 7 || summary.studyDurationDays < 14 {
            reasons.append("insufficientLongitudinalWindow")
        }
        if rows.contains(where: { !$0.causalityClaims.isEmpty }) {
            reasons.append("causalityClaimsPresent")
        }
        if rows.contains(where: { !$0.passesOutcomeFloor }) ||
            summary.passingOutcomeCount != passingRows.count ||
            summary.passingOutcomeCount < 10 {
            reasons.append("outcomeFloorFailures")
        }
        if !summary.readinessWarnings.isEmpty {
            reasons.append("readinessWarnings=\(summary.readinessWarnings.joined(separator: ","))")
        }
        return reasons
    }

    private static func normalizedKey(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    fileprivate static func usableEvidenceReference(_ value: String) -> Bool {
        let normalized = normalizedKey(value)
        guard !normalized.isEmpty else { return false }
        return ![
            "n/a",
            "na",
            "none",
            "todo",
            "tbd",
            "placeholder",
            "unknown"
        ].contains(normalized)
    }

    static func decode(from json: String) throws -> CoachRealUserTransferOutcomeEvidence {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(CoachRealUserTransferOutcomeEvidence.self, from: data)
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    struct Summary: Codable, Equatable {
        let rowCount: Int
        let uniqueUserCount: Int
        let completedFollowUpCount: Int
        let realWorldMomentCount: Int
        let linkedInterventionOutcomeCount: Int
        let positiveTransferCount: Int
        let audienceResponseEvidenceCount: Int
        let noRegressionOutcomeCount: Int
        let adverseOutcomeCount: Int
        let passingOutcomeCount: Int
        let minimumDaysSinceFirstSession: Int
        let studyDurationDays: Int
        let uniqueMomentCategoryCount: Int
        let verifiedEvidenceReferenceCount: Int
        let minimumFollowUpDelayHours: Int
        let maximumOutcomesPerUser: Int
        let readinessWarnings: [String]
    }

    struct Row: Codable, Equatable {
        let outcomeID: String
        let userIDHash: String
        let momentCategory: String
        let interventionID: String
        let realWorldMomentOccurred: Bool
        let followUpCompleted: Bool
        let linkedCoachInterventionCount: Int
        let daysSinceFirstNoumSession: Int
        let followUpDelayHours: Int
        let preMomentConfidence: Int
        let postMomentConfidence: Int
        let positiveTransferReported: Bool
        let audienceResponseEvidenceCollected: Bool
        let adverseOutcomeReported: Bool
        let interventionEvidenceReference: String
        let momentEvidenceReference: String
        let followUpEvidenceReference: String
        let audienceResponseEvidenceReference: String
        let selfReportEvidenceReference: String
        let causalityClaims: [String]
        let notes: [String]

        var hasRequiredIdentity: Bool {
            !outcomeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !userIDHash.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !momentCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !interventionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var hasRequiredEvidenceReferences: Bool {
            [
                interventionEvidenceReference,
                momentEvidenceReference,
                followUpEvidenceReference,
                audienceResponseEvidenceReference,
                selfReportEvidenceReference
            ].allSatisfy(CoachRealUserTransferOutcomeEvidence.usableEvidenceReference)
        }

        var passesOutcomeFloor: Bool {
            realWorldMomentOccurred &&
                followUpCompleted &&
                hasRequiredIdentity &&
                hasRequiredEvidenceReferences &&
                linkedCoachInterventionCount > 0 &&
                daysSinceFirstNoumSession >= 7 &&
                followUpDelayHours >= CoachRealUserTransferOutcomeEvidence.minimumFollowUpDelayHours &&
                postMomentConfidence >= preMomentConfidence &&
                positiveTransferReported &&
                audienceResponseEvidenceCollected &&
                !adverseOutcomeReported &&
                causalityClaims.isEmpty
        }

        func outcomeIDForDiagnostics(index: Int) -> String {
            let trimmed = outcomeID.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "row-\(index)" : trimmed
        }
    }
}

struct CoachRealDeviceTestFlightEvidence: Codable, Equatable {
    static let expectedSchemaVersion = "coach-real-device-testflight-qa-v2"
    static let maximumAIPromptLatencyMs = 3_000
    static let requiredSurfaceKeys = [
        "liveActivity",
        "aiPromptLatency",
        "soundscapeAudioSession",
        "paywallPurchase"
    ]
    static let expectedEvidenceKindBySurface = [
        "liveActivity": "screenRecording",
        "aiPromptLatency": "latencyTrace",
        "soundscapeAudioSession": "audioSessionLog",
        "paywallPurchase": "storeKitReceipt"
    ]

    let schemaVersion: String
    let testRunID: String
    let appVersion: String
    let buildNumber: String
    let deviceModel: String
    let osVersion: String
    let testerRole: String
    let summary: Summary
    let rows: [Row]

    var qualifiesForReadiness: Bool {
        rejectionReasons.isEmpty
    }

    var rejectionReasons: [String] {
        var reasons: [String] = []
        let trimmedRunID = testRunID.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBuild = buildNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDevice = deviceModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTesterRole = testerRole.trimmingCharacters(in: .whitespacesAndNewlines)
        let uniqueSurfaceKeys = Set(rows.map(\.surfaceKey))
        let requiredSurfaceKeys = Set(Self.requiredSurfaceKeys)
        let passedRequiredRows = rows.filter {
            requiredSurfaceKeys.contains($0.surfaceKey) && $0.passesSurfaceFloor
        }
        let realDeviceRequiredRows = rows.filter {
            requiredSurfaceKeys.contains($0.surfaceKey) && $0.realDevice
        }
        let testFlightRequiredRows = rows.filter {
            requiredSurfaceKeys.contains($0.surfaceKey) && $0.testFlightBuildInstalled
        }
        let artifactBackedRows = rows.filter {
            requiredSurfaceKeys.contains($0.surfaceKey) && $0.hasRequiredArtifactTrail
        }
        let expectedEvidenceKindRows = rows.filter {
            requiredSurfaceKeys.contains($0.surfaceKey) && $0.evidenceKindMatchesSurface
        }
        let sameBuildRows = rows.filter {
            requiredSurfaceKeys.contains($0.surfaceKey) &&
                $0.testFlightBuildNumber.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedBuild
        }
        let deviceIdentityRows = rows.filter {
            requiredSurfaceKeys.contains($0.surfaceKey) &&
                Self.usableEvidenceReference($0.deviceIdentifierHash)
        }
        let latencyRows = rows.filter {
            requiredSurfaceKeys.contains($0.surfaceKey) && $0.surfaceKey == "aiPromptLatency"
        }
        let latencyWithinBudgetRows = latencyRows.filter(\.latencyWithinBudget)
        let blockingIssueCount = rows.reduce(0) { $0 + $1.blockingIssueCount }
        if schemaVersion != Self.expectedSchemaVersion {
            reasons.append("schemaVersion=\(schemaVersion)")
        }
        if trimmedRunID.isEmpty || trimmedBuild.isEmpty || trimmedDevice.isEmpty || trimmedTesterRole.isEmpty {
            reasons.append("missingRunMetadata")
        }
        if summary.rowCount != rows.count {
            reasons.append("rowCountMismatch")
        }
        if uniqueSurfaceKeys.count != rows.count {
            reasons.append("duplicateSurfaceKeys")
        }
        let missingRequired = requiredSurfaceKeys.subtracting(uniqueSurfaceKeys)
        if !missingRequired.isEmpty {
            reasons.append("missingRequiredSurfaces=\(missingRequired.sorted().joined(separator: ","))")
        }
        if summary.requiredSurfaceCount != Self.requiredSurfaceKeys.count {
            reasons.append("requiredSurfaceCountMismatch")
        }
        if summary.passedRequiredSurfaceCount != passedRequiredRows.count ||
            passedRequiredRows.count < Self.requiredSurfaceKeys.count {
            reasons.append("surfaceFloorFailures")
        }
        if summary.realDeviceSurfaceCount != realDeviceRequiredRows.count ||
            realDeviceRequiredRows.count < Self.requiredSurfaceKeys.count {
            reasons.append("notAllSurfacesOnRealDevice")
        }
        if summary.testFlightBuildSurfaceCount != testFlightRequiredRows.count ||
            testFlightRequiredRows.count < Self.requiredSurfaceKeys.count {
            reasons.append("notAllSurfacesOnTestFlightBuild")
        }
        let missingArtifactKeys = requiredSurfaceKeys.subtracting(Set(artifactBackedRows.map(\.surfaceKey)))
        if summary.artifactBackedSurfaceCount != artifactBackedRows.count ||
            !missingArtifactKeys.isEmpty {
            reasons.append("missingDeviceEvidence=\(missingArtifactKeys.sorted().joined(separator: ","))")
        }
        let evidenceKindMismatchKeys = requiredSurfaceKeys.subtracting(Set(expectedEvidenceKindRows.map(\.surfaceKey)))
        if summary.expectedEvidenceKindSurfaceCount != expectedEvidenceKindRows.count ||
            !evidenceKindMismatchKeys.isEmpty {
            reasons.append("evidenceKindMismatch=\(evidenceKindMismatchKeys.sorted().joined(separator: ","))")
        }
        let buildMismatchKeys = requiredSurfaceKeys.subtracting(Set(sameBuildRows.map(\.surfaceKey)))
        if summary.sameBuildSurfaceCount != sameBuildRows.count ||
            !buildMismatchKeys.isEmpty {
            reasons.append("buildNumberMismatch=\(buildMismatchKeys.sorted().joined(separator: ","))")
        }
        let missingDeviceIdentityKeys = requiredSurfaceKeys.subtracting(Set(deviceIdentityRows.map(\.surfaceKey)))
        if summary.deviceIdentitySurfaceCount != deviceIdentityRows.count ||
            !missingDeviceIdentityKeys.isEmpty {
            reasons.append("missingDeviceIdentity=\(missingDeviceIdentityKeys.sorted().joined(separator: ","))")
        }
        if latencyRows.count != 1 ||
            summary.latencyWithinBudgetSurfaceCount != latencyWithinBudgetRows.count ||
            latencyWithinBudgetRows.count != 1 {
            reasons.append("aiPromptLatencyOverBudget")
        }
        if summary.blockingIssueCount != blockingIssueCount || blockingIssueCount > 0 {
            reasons.append("blockingIssuesPresent")
        }
        if !summary.crashFree {
            reasons.append("crashesObserved")
        }
        if rows.contains(where: { !$0.passesSurfaceFloor }) {
            reasons.append("rowSurfaceFloorFailures")
        }
        if !summary.readinessWarnings.isEmpty {
            reasons.append("readinessWarnings=\(summary.readinessWarnings.joined(separator: ","))")
        }
        return reasons
    }

    static func usableEvidenceReference(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let lowercased = normalized.lowercased()
        return !["n/a", "na", "none", "todo", "tbd", "placeholder", "unknown"].contains(lowercased)
    }

    static func decode(from json: String) throws -> CoachRealDeviceTestFlightEvidence {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(CoachRealDeviceTestFlightEvidence.self, from: data)
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    struct Summary: Codable, Equatable {
        let rowCount: Int
        let requiredSurfaceCount: Int
        let passedRequiredSurfaceCount: Int
        let realDeviceSurfaceCount: Int
        let testFlightBuildSurfaceCount: Int
        let artifactBackedSurfaceCount: Int
        let expectedEvidenceKindSurfaceCount: Int
        let sameBuildSurfaceCount: Int
        let deviceIdentitySurfaceCount: Int
        let latencyWithinBudgetSurfaceCount: Int
        let blockingIssueCount: Int
        let crashFree: Bool
        let readinessWarnings: [String]
    }

    struct Row: Codable, Equatable {
        let surfaceKey: String
        let passed: Bool
        let realDevice: Bool
        let testFlightBuildInstalled: Bool
        let evidenceReference: String
        let evidenceKind: String
        let evidenceCapturedAtISO8601: String
        let testFlightBuildNumber: String
        let deviceIdentifierHash: String
        let latencyMs: Int?
        let blockingIssueCount: Int
        let notes: [String]

        var hasRequiredArtifactTrail: Bool {
            CoachRealDeviceTestFlightEvidence.usableEvidenceReference(evidenceReference) &&
                CoachRealDeviceTestFlightEvidence.usableEvidenceReference(evidenceKind) &&
                CoachRealDeviceTestFlightEvidence.usableEvidenceReference(evidenceCapturedAtISO8601) &&
                CoachRealDeviceTestFlightEvidence.usableEvidenceReference(testFlightBuildNumber) &&
                CoachRealDeviceTestFlightEvidence.usableEvidenceReference(deviceIdentifierHash)
        }

        var evidenceKindMatchesSurface: Bool {
            guard let expectedKind = CoachRealDeviceTestFlightEvidence.expectedEvidenceKindBySurface[surfaceKey] else {
                return false
            }
            return evidenceKind.trimmingCharacters(in: .whitespacesAndNewlines) == expectedKind
        }

        var latencyWithinBudget: Bool {
            guard surfaceKey == "aiPromptLatency" else { return true }
            guard let latencyMs else { return false }
            return latencyMs <= CoachRealDeviceTestFlightEvidence.maximumAIPromptLatencyMs
        }

        var passesSurfaceFloor: Bool {
            passed &&
                realDevice &&
                testFlightBuildInstalled &&
                blockingIssueCount == 0 &&
                hasRequiredArtifactTrail &&
                evidenceKindMatchesSurface &&
                latencyWithinBudget
        }
    }
}

struct CoachOperationalLaunchChecklistEvidence: Codable, Equatable {
    static let expectedSchemaVersion = "coach-operational-launch-checklist-v2"
    static let expectedChecklistVersion = "m14-launch-gate-v2"
    static let requiredItemKeys = [
        "firestoreRulesDeployed",
        "privacyPolicyURLHosted",
        "settingsPrivacyURLVerified",
        "appStorePrivacyDisclosuresReviewed",
        "testFlightBuildUploaded",
        "releaseBlockingBugsTriaged"
    ]
    static let expectedEvidenceKindByItem = [
        "firestoreRulesDeployed": "firebaseDeployLog",
        "privacyPolicyURLHosted": "publicURLProbe",
        "settingsPrivacyURLVerified": "settingsScreenshot",
        "appStorePrivacyDisclosuresReviewed": "appStorePrivacyExport",
        "testFlightBuildUploaded": "appStoreConnectBuildRecord",
        "releaseBlockingBugsTriaged": "releaseTriageReport"
    ]
    static let expectedEnvironmentByItem = [
        "firestoreRulesDeployed": "production",
        "privacyPolicyURLHosted": "production",
        "settingsPrivacyURLVerified": "releaseCandidate",
        "appStorePrivacyDisclosuresReviewed": "appStoreConnect",
        "testFlightBuildUploaded": "appStoreConnect",
        "releaseBlockingBugsTriaged": "releaseBoard"
    ]

    let schemaVersion: String
    let checklistVersion: String
    let releaseCandidateBuild: String
    let completedByRole: String
    let summary: Summary
    let items: [Item]

    var qualifiesForReadiness: Bool {
        rejectionReasons.isEmpty
    }

    var rejectionReasons: [String] {
        var reasons: [String] = []
        let trimmedBuild = releaseCandidateBuild.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRole = completedByRole.trimmingCharacters(in: .whitespacesAndNewlines)
        let uniqueKeys = Set(items.map(\.key))
        let requiredKeys = Set(Self.requiredItemKeys)
        let completedRequiredItems = items.filter {
            requiredKeys.contains($0.key) && $0.completed
        }
        let failedRequiredItems = items.filter {
            requiredKeys.contains($0.key) && !$0.completed
        }
        let artifactBackedItems = items.filter {
            requiredKeys.contains($0.key) && $0.hasRequiredArtifactTrail
        }
        let expectedEvidenceKindItems = items.filter {
            requiredKeys.contains($0.key) && $0.evidenceKindMatchesItem
        }
        let expectedEnvironmentItems = items.filter {
            requiredKeys.contains($0.key) && $0.environmentMatchesItem
        }
        let sameBuildItems = items.filter {
            requiredKeys.contains($0.key) &&
                $0.releaseCandidateBuild.trimmingCharacters(in: .whitespacesAndNewlines) == trimmedBuild
        }
        let verifiedRequiredItems = items.filter {
            requiredKeys.contains($0.key) && $0.hasVerificationIdentity
        }
        if schemaVersion != Self.expectedSchemaVersion {
            reasons.append("schemaVersion=\(schemaVersion)")
        }
        if checklistVersion != Self.expectedChecklistVersion {
            reasons.append("checklistVersion=\(checklistVersion)")
        }
        if trimmedBuild.isEmpty || trimmedRole.isEmpty {
            reasons.append("missingReleaseMetadata")
        }
        if summary.itemCount != items.count {
            reasons.append("itemCountMismatch")
        }
        if uniqueKeys.count != items.count {
            reasons.append("duplicateChecklistItems")
        }
        let missingRequired = requiredKeys.subtracting(uniqueKeys)
        if !missingRequired.isEmpty {
            reasons.append("missingRequiredItems=\(missingRequired.sorted().joined(separator: ","))")
        }
        if summary.completedRequiredItemCount != completedRequiredItems.count ||
            completedRequiredItems.count < Self.requiredItemKeys.count {
            reasons.append("incompleteRequiredItems")
        }
        if summary.failedRequiredItemCount != failedRequiredItems.count ||
            !failedRequiredItems.isEmpty {
            reasons.append("failedRequiredItems")
        }
        let missingArtifactKeys = requiredKeys.subtracting(Set(artifactBackedItems.map(\.key)))
        if summary.artifactBackedItemCount != artifactBackedItems.count ||
            !missingArtifactKeys.isEmpty {
            reasons.append("missingOperationalEvidence=\(missingArtifactKeys.sorted().joined(separator: ","))")
        }
        let evidenceKindMismatchKeys = requiredKeys.subtracting(Set(expectedEvidenceKindItems.map(\.key)))
        if summary.expectedEvidenceKindItemCount != expectedEvidenceKindItems.count ||
            !evidenceKindMismatchKeys.isEmpty {
            reasons.append("evidenceKindMismatch=\(evidenceKindMismatchKeys.sorted().joined(separator: ","))")
        }
        let environmentMismatchKeys = requiredKeys.subtracting(Set(expectedEnvironmentItems.map(\.key)))
        if summary.expectedEnvironmentItemCount != expectedEnvironmentItems.count ||
            !environmentMismatchKeys.isEmpty {
            reasons.append("environmentMismatch=\(environmentMismatchKeys.sorted().joined(separator: ","))")
        }
        let buildMismatchKeys = requiredKeys.subtracting(Set(sameBuildItems.map(\.key)))
        if summary.sameBuildItemCount != sameBuildItems.count ||
            !buildMismatchKeys.isEmpty {
            reasons.append("releaseCandidateBuildMismatch=\(buildMismatchKeys.sorted().joined(separator: ","))")
        }
        let missingVerificationKeys = requiredKeys.subtracting(Set(verifiedRequiredItems.map(\.key)))
        if summary.verifiedRequiredItemCount != verifiedRequiredItems.count ||
            !missingVerificationKeys.isEmpty {
            reasons.append("missingOperationalVerification=\(missingVerificationKeys.sorted().joined(separator: ","))")
        }
        if items.contains(where: { requiredKeys.contains($0.key) && !$0.passesItemFloor }) {
            reasons.append("itemFloorFailures")
        }
        if !summary.readinessWarnings.isEmpty {
            reasons.append("readinessWarnings=\(summary.readinessWarnings.joined(separator: ","))")
        }
        return reasons
    }

    static func usableEvidenceReference(_ value: String) -> Bool {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return false }
        let lowercased = normalized.lowercased()
        return !["n/a", "na", "none", "todo", "tbd", "placeholder", "unknown"].contains(lowercased)
    }

    static func usableEvidenceReference(_ value: String?) -> Bool {
        guard let value else { return false }
        return usableEvidenceReference(value)
    }

    static func decode(from json: String) throws -> CoachOperationalLaunchChecklistEvidence {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(CoachOperationalLaunchChecklistEvidence.self, from: data)
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    struct Summary: Codable, Equatable {
        let itemCount: Int
        let completedRequiredItemCount: Int
        let failedRequiredItemCount: Int
        let artifactBackedItemCount: Int
        let expectedEvidenceKindItemCount: Int
        let expectedEnvironmentItemCount: Int
        let sameBuildItemCount: Int
        let verifiedRequiredItemCount: Int
        let readinessWarnings: [String]
    }

    struct Item: Codable, Equatable {
        let key: String
        let completed: Bool
        let evidenceReference: String
        let evidenceKind: String
        let verificationReference: String
        let commandOrReviewOutputReference: String
        let releaseCandidateBuild: String
        let environment: String
        let completedAtISO8601: String?
        let verifiedAtISO8601: String?
        let verifiedByRole: String
        let notes: [String]

        var hasRequiredArtifactTrail: Bool {
            CoachOperationalLaunchChecklistEvidence.usableEvidenceReference(evidenceReference) &&
                CoachOperationalLaunchChecklistEvidence.usableEvidenceReference(verificationReference) &&
                CoachOperationalLaunchChecklistEvidence.usableEvidenceReference(commandOrReviewOutputReference) &&
                CoachOperationalLaunchChecklistEvidence.usableEvidenceReference(completedAtISO8601)
        }

        var evidenceKindMatchesItem: Bool {
            guard let expectedKind = CoachOperationalLaunchChecklistEvidence.expectedEvidenceKindByItem[key] else {
                return false
            }
            return evidenceKind.trimmingCharacters(in: .whitespacesAndNewlines) == expectedKind
        }

        var environmentMatchesItem: Bool {
            guard let expectedEnvironment = CoachOperationalLaunchChecklistEvidence.expectedEnvironmentByItem[key] else {
                return false
            }
            return environment.trimmingCharacters(in: .whitespacesAndNewlines) == expectedEnvironment
        }

        var hasVerificationIdentity: Bool {
            CoachOperationalLaunchChecklistEvidence.usableEvidenceReference(verifiedAtISO8601) &&
                CoachOperationalLaunchChecklistEvidence.usableEvidenceReference(verifiedByRole)
        }

        var passesItemFloor: Bool {
            completed &&
                hasRequiredArtifactTrail &&
                evidenceKindMatchesItem &&
                environmentMatchesItem &&
                hasVerificationIdentity
        }
    }
}

struct CoachChatConversationAppPathReport: Codable, Equatable {
    let schemaVersion: String
    let surface: String
    let conversationCount: Int
    let turnCount: Int
    let passesAppPathFloor: Bool
    let visionProductionReadiness: CoachVisionProductionReadinessAudit
    let summary: CoachChatConversationAppPathSummary
    let rows: [CoachChatConversationAppPathReportRow]

    static func make(
        rows: [CoachChatConversationAppPathReportRow],
        localTargetShapeScore: Int,
        schemaVersion: String = CoachChatConversationCorpus.appPathReportSchemaVersion,
        surface: CoachReplySurface = .text
    ) -> CoachChatConversationAppPathReport {
        let summary = CoachChatConversationAppPathSummary.make(from: rows)
        let passesAppPathFloor = !rows.isEmpty &&
            summary.readinessWarnings.isEmpty &&
            rows.allSatisfy(\.passesAppPathFloor)
        let readiness = CoachVisionProductionReadinessAudit.make(
            localTargetShapeScore: localTargetShapeScore,
            evidence: .currentLocalSubstrate(
                conversationCount: rows.count,
                rowsPassingProductionFloor: rows.filter(\.passesAppPathFloor).count
            )
        )
        return CoachChatConversationAppPathReport(
            schemaVersion: schemaVersion,
            surface: surface.rawValue,
            conversationCount: rows.count,
            turnCount: rows.reduce(0) { $0 + $1.turnCount },
            passesAppPathFloor: passesAppPathFloor,
            visionProductionReadiness: readiness,
            summary: summary,
            rows: rows
        )
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct CoachChatConversationAppPathSummary: Codable, Equatable {
    let conversationCount: Int
    let turnCount: Int
    let appPathFloorFailureCount: Int
    let failureConversationIDs: [String]
    let targetReplyMismatchCount: Int
    let missingMetadataTurnCount: Int
    let semanticGateFailureTurnCount: Int
    let qualityGateEventCounts: [String: Int]
    let qualityGateFamilyCounts: [String: Int]
    let nonCleanQualityGateEvents: [String]
    let acceptedFallbackTurnCount: Int
    let typedAssessmentFallbackTurnCount: Int
    let qualityGateBlockingFailureTurnCount: Int
    let visionFloorFailureTurnCount: Int
    let reliabilityIssueTurnCount: Int
    let immediateCoachReadExpectedCount: Int
    let immediateCoachReadMissingCount: Int
    let readinessWarnings: [String]

    static func make(
        from rows: [CoachChatConversationAppPathReportRow]
    ) -> CoachChatConversationAppPathSummary {
        let turns = rows.flatMap(\.turns)
        let floorFailures = rows.filter { !$0.passesAppPathFloor }
        let targetReplyMismatchCount = turns.filter { !$0.targetReplyMatched }.count
        let missingMetadataTurnCount = turns.filter { !$0.metadataPresent }.count
        let semanticGateFailureTurnCount = turns.filter { !$0.semanticGatePassed }.count
        let qualityGateEventCounts = eventCounts(
            turns.flatMap(\.qualityGateEvents)
        )
        let qualityGateFamilyCounts = eventCounts(
            turns.flatMap(\.qualityGateEvents).map(qualityGateFamily)
        )
        let nonCleanQualityGateEvents = nonCleanEvents(
            from: qualityGateEventCounts
        )
        let acceptedFallbackTurnCount = turns.filter(\.qualityGateAcceptedFallback).count
        let typedAssessmentFallbackTurnCount = turns.filter(\.typedAssessmentFallbackApplied).count
        let qualityGateBlockingFailureTurnCount = turns.filter(\.qualityGateBlockingFailure).count
        let visionFloorFailureTurnCount = turns.filter { $0.visionPassesProductionFloor == false }.count
        let reliabilityIssueTurnCount = turns.filter { !$0.reliabilityIssues.isEmpty }.count
        let immediateExpected = turns.filter(\.immediateCoachReadExpected)
        let immediateMissing = immediateExpected.filter { !$0.immediateCoachReadShown }
        let warnings = readinessWarnings(
            conversationCount: rows.count,
            floorFailureCount: floorFailures.count,
            targetReplyMismatchCount: targetReplyMismatchCount,
            missingMetadataTurnCount: missingMetadataTurnCount,
            semanticGateFailureTurnCount: semanticGateFailureTurnCount,
            visionFloorFailureTurnCount: visionFloorFailureTurnCount,
            reliabilityIssueTurnCount: reliabilityIssueTurnCount,
            immediateCoachReadMissingCount: immediateMissing.count
        )

        return CoachChatConversationAppPathSummary(
            conversationCount: rows.count,
            turnCount: turns.count,
            appPathFloorFailureCount: floorFailures.count,
            failureConversationIDs: floorFailures.map(\.conversationID),
            targetReplyMismatchCount: targetReplyMismatchCount,
            missingMetadataTurnCount: missingMetadataTurnCount,
            semanticGateFailureTurnCount: semanticGateFailureTurnCount,
            qualityGateEventCounts: qualityGateEventCounts,
            qualityGateFamilyCounts: qualityGateFamilyCounts,
            nonCleanQualityGateEvents: nonCleanQualityGateEvents,
            acceptedFallbackTurnCount: acceptedFallbackTurnCount,
            typedAssessmentFallbackTurnCount: typedAssessmentFallbackTurnCount,
            qualityGateBlockingFailureTurnCount: qualityGateBlockingFailureTurnCount,
            visionFloorFailureTurnCount: visionFloorFailureTurnCount,
            reliabilityIssueTurnCount: reliabilityIssueTurnCount,
            immediateCoachReadExpectedCount: immediateExpected.count,
            immediateCoachReadMissingCount: immediateMissing.count,
            readinessWarnings: warnings
        )
    }

    private static func eventCounts(_ events: [String]) -> [String: Int] {
        events.reduce(into: [:]) { counts, event in
            counts[event, default: 0] += 1
        }
    }

    private static func qualityGateFamily(_ event: String) -> String {
        guard event != "passed" else { return event }
        let parts = event.split(separator: ":", maxSplits: 2).map(String.init)
        guard parts.count >= 2 else { return event }
        let state = parts[0]
        let gate = parts[1]
        if gate == "typedAssessment" || gate == "contentRejected" || gate == "providerRefused" {
            return "\(state):\(gate)"
        }
        if gate == "safeReference", parts.count == 3 {
            let nested = parts[2].split(separator: ":", maxSplits: 1).first.map(String.init)
            return [state, gate, nested].compactMap { $0 }.joined(separator: ":")
        }
        return "\(state):\(gate)"
    }

    private static func nonCleanEvents(
        from counts: [String: Int]
    ) -> [String] {
        counts.keys
            .filter { event in
                event.hasPrefix("rejected:") ||
                    event.hasPrefix("failed:") ||
                    event.hasPrefix("fallback:")
            }
            .sorted()
    }

    private static func readinessWarnings(
        conversationCount: Int,
        floorFailureCount: Int,
        targetReplyMismatchCount: Int,
        missingMetadataTurnCount: Int,
        semanticGateFailureTurnCount: Int,
        visionFloorFailureTurnCount: Int,
        reliabilityIssueTurnCount: Int,
        immediateCoachReadMissingCount: Int
    ) -> [String] {
        var warnings: [CoachChatConversationAppPathWarning] = []
        if conversationCount < 10 {
            warnings.append(.fewerThanTenConversations)
        }
        if floorFailureCount > 0 {
            warnings.append(.appPathFloorFailures)
        }
        if targetReplyMismatchCount > 0 {
            warnings.append(.targetReplyMismatch)
        }
        if missingMetadataTurnCount > 0 {
            warnings.append(.missingTurnMetadata)
        }
        if semanticGateFailureTurnCount > 0 {
            warnings.append(.semanticGateFailures)
        }
        if visionFloorFailureTurnCount > 0 {
            warnings.append(.visionFloorFailures)
        }
        if reliabilityIssueTurnCount > 0 {
            warnings.append(.reliabilityIssues)
        }
        if immediateCoachReadMissingCount > 0 {
            warnings.append(.missingImmediateCoachRead)
        }
        return warnings.map(\.rawValue)
    }
}

enum CoachChatConversationAppPathWarning: String, Codable, Equatable {
    case fewerThanTenConversations
    case appPathFloorFailures
    case targetReplyMismatch
    case missingTurnMetadata
    case semanticGateFailures
    case visionFloorFailures
    case reliabilityIssues
    case missingImmediateCoachRead
}

struct CoachChatConversationAppPathReportRow: Codable, Equatable {
    let conversationID: String
    let sourceFixtureID: String
    let turnCount: Int
    let coachTurnCount: Int
    let targetRepliesMatched: Bool
    let turnDepths: [String]
    let proofTestHashes: [String]
    let passesAppPathFloor: Bool
    let turns: [CoachChatConversationAppPathTurnRow]

    static func make(
        conversationID: String,
        sourceFixtureID: String,
        turns: [CoachChatConversationAppPathTurnRow]
    ) -> CoachChatConversationAppPathReportRow {
        CoachChatConversationAppPathReportRow(
            conversationID: conversationID,
            sourceFixtureID: sourceFixtureID,
            turnCount: turns.count,
            coachTurnCount: turns.filter(\.outcomeSucceeded).count,
            targetRepliesMatched: turns.allSatisfy(\.targetReplyMatched),
            turnDepths: turns.compactMap(\.turnDepth),
            proofTestHashes: turns.compactMap(\.proofTestHash),
            passesAppPathFloor: !turns.isEmpty && turns.allSatisfy(\.passesAppPathFloor),
            turns: turns
        )
    }
}

struct CoachChatConversationAppPathTurnRow: Codable, Equatable {
    let turnIndex: Int
    let userTurn: String
    let targetCoachReply: String
    let finalCoachReply: String?
    let outcomeSucceeded: Bool
    let targetReplyMatched: Bool
    let metadataPresent: Bool
    let turnDepth: String?
    let providerTierRequested: String?
    let providerTierChosen: String?
    let providerName: String?
    let providerModel: String?
    let semanticGateOutcome: String?
    let semanticGateIssue: String?
    let semanticGatePassed: Bool
    let qualityGateOutcome: String?
    let qualityGateEvents: [String]
    let qualityGateClean: Bool
    let qualityGateAcceptedFallback: Bool
    let typedAssessmentFallbackApplied: Bool
    let qualityGateBlockingFailure: Bool
    let reliabilityIssues: [String]
    let visionScore: Int?
    let visionPassesProductionFloor: Bool?
    let immediateCoachReadExpected: Bool
    let immediateCoachReadShown: Bool
    let proofTestHash: String?
    let proofTestRecentlyRepeated: Bool?
    let timeToFirstVisibleTokenMs: Int?
    let timeToCompleteReplyMs: Int?
    let passesAppPathFloor: Bool
}

struct CoachLiveProviderSweepEvidence: Codable, Equatable {
    static let expectedSchemaVersion = "coach-live-eval-v1"
    static let requiredFixtureIDs = CoachChatEvaluationCorpus.latestManualEvalFixtureIDs
    static let requiredLongFormConversationIDs = CoachChatConversationCorpus
        .longFormConversations
        .map(\.id)
    static var requiredReadinessEvidenceCount: Int {
        requiredFixtureIDs.count + requiredLongFormConversationIDs.count
    }
    static let requiredTurnDepths = [
        CoachTurnDepth.quickMove.rawValue,
        CoachTurnDepth.groundedRead.rawValue,
        CoachTurnDepth.deepAssessment.rawValue,
        CoachTurnDepth.trustRepair.rawValue
    ]

    let schemaVersion: String
    let fixtureCount: Int
    let longFormConversationCount: Int
    let longFormConversationIDsPassingProductionFloor: [String]
    let longFormConversationFailureIDs: [String]
    let longFormConversations: [LongFormConversation]?
    let providerChain: [String]
    let passesProductionFloor: Bool
    let passesRunReadinessFloor: Bool
    let summary: Summary
    let rows: [Row]

    var rowsPassingReadinessFloor: Int {
        qualifiesForReadiness
            ? rows.filter(\.liveProductionFloor).count + longFormConversationIDsPassingProductionFloor.count
            : 0
    }

    var qualifiesForReadiness: Bool {
        rejectionReasons.isEmpty
    }

    var rejectionReasons: [String] {
        var reasons: [String] = []
        if schemaVersion != Self.expectedSchemaVersion {
            reasons.append("schemaVersion=\(schemaVersion)")
        }
        if fixtureCount < 10 || rows.count < 10 {
            reasons.append("fewerThanTenRows")
        }
        if fixtureCount < Self.requiredFixtureIDs.count ||
            rows.count < Self.requiredFixtureIDs.count {
            reasons.append("missingLatestTranscriptCoverage")
        }
        if longFormConversationCount < Self.requiredLongFormConversationIDs.count ||
            longFormConversationIDsPassingProductionFloor.count < Self.requiredLongFormConversationIDs.count {
            reasons.append("missingLiveLongFormConversationCoverage")
        }
        if fixtureCount != rows.count || summary.rowCount != rows.count {
            reasons.append("rowCountMismatch")
        }
        if longFormConversationCount != longFormConversationIDsPassingProductionFloor.count +
            longFormConversationFailureIDs.count {
            reasons.append("longFormConversationCountMismatch")
        }
        let fixtureIDs = rows.map(\.fixtureID)
        let uniqueFixtureIDs = Set(fixtureIDs)
        if uniqueFixtureIDs.count != fixtureIDs.count {
            reasons.append("duplicateFixtureIDs")
        }
        let uniqueLongFormConversationIDs = Set(longFormConversationIDsPassingProductionFloor)
        if uniqueLongFormConversationIDs.count != longFormConversationIDsPassingProductionFloor.count {
            reasons.append("duplicateLongFormConversationIDs")
        }
        let detailedLongFormRows = longFormConversations ?? []
        if detailedLongFormRows.isEmpty {
            reasons.append("missingDetailedLongFormConversations")
        }
        let detailedLongFormIDs = detailedLongFormRows.map(\.conversationID)
        let uniqueDetailedLongFormIDs = Set(detailedLongFormIDs)
        if uniqueDetailedLongFormIDs.count != detailedLongFormIDs.count {
            reasons.append("duplicateDetailedLongFormConversationIDs")
        }
        if !detailedLongFormRows.isEmpty &&
            detailedLongFormRows.count != longFormConversationCount {
            reasons.append("detailedLongFormConversationCountMismatch")
        }
        let missingFixtureIDs = Self.requiredFixtureIDs.filter {
            !uniqueFixtureIDs.contains($0)
        }
        if !missingFixtureIDs.isEmpty {
            reasons.append("missingRequiredFixtures=\(missingFixtureIDs.joined(separator: ","))")
        }
        let missingLongFormConversationIDs = Self.requiredLongFormConversationIDs.filter {
            !uniqueLongFormConversationIDs.contains($0)
        }
        if !missingLongFormConversationIDs.isEmpty {
            reasons.append(
                "missingRequiredLongFormConversations=\(missingLongFormConversationIDs.joined(separator: ","))"
            )
        }
        let missingDetailedLongFormConversationIDs = Self.requiredLongFormConversationIDs.filter {
            !uniqueDetailedLongFormIDs.contains($0)
        }
        if !missingDetailedLongFormConversationIDs.isEmpty {
            reasons.append(
                "missingDetailedLongFormConversations=\(missingDetailedLongFormConversationIDs.joined(separator: ","))"
            )
        }
        let unexpectedLongFormConversationIDs = uniqueLongFormConversationIDs
            .filter { !Self.requiredLongFormConversationIDs.contains($0) }
            .sorted()
        if !unexpectedLongFormConversationIDs.isEmpty {
            reasons.append(
                "unexpectedLongFormConversationIDs=\(unexpectedLongFormConversationIDs.joined(separator: ","))"
            )
        }
        let unexpectedDetailedLongFormConversationIDs = uniqueDetailedLongFormIDs
            .filter { !Self.requiredLongFormConversationIDs.contains($0) }
            .sorted()
        if !unexpectedDetailedLongFormConversationIDs.isEmpty {
            reasons.append(
                "unexpectedDetailedLongFormConversations=\(unexpectedDetailedLongFormConversationIDs.joined(separator: ","))"
            )
        }
        let detailedPassingIDs = Set(
            detailedLongFormRows
                .filter(\.liveProductionFloor)
                .map(\.conversationID)
        )
        let detailedFailureIDs = Set(
            detailedLongFormRows
                .filter { !$0.liveProductionFloor }
                .map(\.conversationID)
        )
        if !detailedLongFormRows.isEmpty &&
            uniqueLongFormConversationIDs != detailedPassingIDs {
            reasons.append("longFormConversationPassingSummaryMismatch")
        }
        if !detailedLongFormRows.isEmpty &&
            Set(longFormConversationFailureIDs) != detailedFailureIDs {
            reasons.append("longFormConversationFailureSummaryMismatch")
        }
        let malformedDetailedLongFormIDs = detailedLongFormRows.compactMap { conversation -> String? in
            let expectedTurnCount = Self.requiredLongFormConversationTurnCountsByID[conversation.conversationID]
            let hasExpectedTurnCount = expectedTurnCount.map { $0 == conversation.expectedTurnCount } ?? false
            let observedMatchesRows = conversation.observedTurnCount == conversation.rows.count
            let observedMatchesExpected = conversation.observedTurnCount == conversation.expectedTurnCount
            let hasRows = !conversation.rows.isEmpty
            return hasExpectedTurnCount && observedMatchesRows && observedMatchesExpected && hasRows
                ? nil
                : conversation.conversationID
        }
        if !malformedDetailedLongFormIDs.isEmpty {
            reasons.append(
                "malformedDetailedLongFormConversations=\(malformedDetailedLongFormIDs.joined(separator: ","))"
            )
        }
        let failedDetailedLongFormIDs = detailedLongFormRows.compactMap { conversation -> String? in
            conversation.liveProductionFloor && conversation.failure == nil &&
                conversation.rows.allSatisfy(\.liveProductionFloor)
                ? nil
                : conversation.conversationID
        }
        if !failedDetailedLongFormIDs.isEmpty {
            reasons.append(
                "detailedLongFormProductionFloorFailures=\(failedDetailedLongFormIDs.joined(separator: ","))"
            )
        }
        let missingDetailedProviderEvidenceIDs = detailedLongFormRows.compactMap { conversation -> String? in
            conversation.rows.contains(where: { !$0.hasProviderEvidence })
                ? conversation.conversationID
                : nil
        }
        if !missingDetailedProviderEvidenceIDs.isEmpty {
            reasons.append(
                "missingDetailedLongFormProviderEvidence=\(missingDetailedProviderEvidenceIDs.joined(separator: ","))"
            )
        }
        let missingDetailedTelemetryIDs = detailedLongFormRows.compactMap { conversation -> String? in
            conversation.rows.contains(where: { !$0.hasReadinessTelemetry })
                ? conversation.conversationID
                : nil
        }
        if !missingDetailedTelemetryIDs.isEmpty {
            reasons.append(
                "missingDetailedLongFormTelemetry=\(missingDetailedTelemetryIDs.joined(separator: ","))"
            )
        }
        let latestGateTelemetryFailureIDs = rows.compactMap { row -> String? in
            row.hasCleanProductionTelemetry ? nil : row.fixtureID
        }
        if !latestGateTelemetryFailureIDs.isEmpty {
            reasons.append(
                "latestTurnGateTelemetryFailures=\(latestGateTelemetryFailureIDs.joined(separator: ","))"
            )
        }
        let detailedGateTelemetryFailureIDs = detailedLongFormRows.compactMap { conversation -> String? in
            conversation.rows.contains { !$0.hasCleanProductionTelemetry }
                ? conversation.conversationID
                : nil
        }
        if !detailedGateTelemetryFailureIDs.isEmpty {
            reasons.append(
                "detailedLongFormGateTelemetryFailures=\(detailedGateTelemetryFailureIDs.joined(separator: ","))"
            )
        }
        let duplicatedLatestReplyIDs = Self.duplicateReplyIDs(in: rows)
        if !duplicatedLatestReplyIDs.isEmpty {
            reasons.append(
                "duplicatedLatestTurnReplies=\(duplicatedLatestReplyIDs.joined(separator: ","))"
            )
        }
        let genericLatestReplyIDs = rows.compactMap { row -> String? in
            row.hasGenericPlaceholderReply ? row.fixtureID : nil
        }
        if !genericLatestReplyIDs.isEmpty {
            reasons.append(
                "genericLatestTurnReplies=\(genericLatestReplyIDs.joined(separator: ","))"
            )
        }
        let duplicatedDetailedReplyIDs = detailedLongFormRows.compactMap { conversation -> String? in
            Self.duplicateReplyIDs(in: conversation.rows).isEmpty ? nil : conversation.conversationID
        }
        if !duplicatedDetailedReplyIDs.isEmpty {
            reasons.append(
                "duplicatedDetailedLongFormReplies=\(duplicatedDetailedReplyIDs.joined(separator: ","))"
            )
        }
        let genericDetailedReplyIDs = detailedLongFormRows.compactMap { conversation -> String? in
            conversation.rows.contains(where: \.hasGenericPlaceholderReply)
                ? conversation.conversationID
                : nil
        }
        if !genericDetailedReplyIDs.isEmpty {
            reasons.append(
                "genericDetailedLongFormReplies=\(genericDetailedReplyIDs.joined(separator: ","))"
            )
        }
        let observedDepths = Set(rows.compactMap(\.turnDepth))
        let missingDepths = Self.requiredTurnDepths.filter {
            !observedDepths.contains($0)
        }
        if !missingDepths.isEmpty {
            reasons.append("missingTurnDepthCoverage=\(missingDepths.joined(separator: ","))")
        }
        if providerChain.isEmpty ||
            rows.contains(where: {
                ($0.providerChosen ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                    ($0.providerModel ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }) {
            reasons.append("missingProviderEvidence")
        }
        if !passesProductionFloor {
            reasons.append("passesProductionFloor=false")
        }
        if !passesRunReadinessFloor {
            reasons.append("passesRunReadinessFloor=false")
        }
        if summary.productionFloorFailureCount > 0 || rows.contains(where: { !$0.liveProductionFloor }) {
            reasons.append("productionFloorFailures")
        }
        if !longFormConversationFailureIDs.isEmpty {
            reasons.append("longFormConversationFailures=\(longFormConversationFailureIDs.joined(separator: ","))")
        }
        if !summary.readinessWarnings.isEmpty {
            reasons.append("readinessWarnings=\(summary.readinessWarnings.joined(separator: ","))")
        }
        if summary.immediateCoachReadMissingCount > 0 {
            reasons.append("missingImmediateCoachRead")
        }
        if summary.assessmentConfidenceDistinctRoundedCount < 3 {
            reasons.append("flatAssessmentConfidence")
        }
        if summary.uniqueProofTestHashCount < 3 ||
            summary.repeatedProofTestHashCount > 0 {
            reasons.append("weakProofTestVariety")
        }
        return reasons
    }

    static func decode(from json: String) throws -> CoachLiveProviderSweepEvidence {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(CoachLiveProviderSweepEvidence.self, from: data)
    }

    private static func duplicateReplyIDs(in rows: [Row]) -> [String] {
        var firstIDByReply: [String: String] = [:]
        var duplicateIDs = Set<String>()
        for row in rows {
            let key = row.normalizedReplyKey
            guard !key.isEmpty else { continue }
            if let firstID = firstIDByReply[key] {
                duplicateIDs.insert(firstID)
                duplicateIDs.insert(row.fixtureID)
            } else {
                firstIDByReply[key] = row.fixtureID
            }
        }
        return duplicateIDs.sorted()
    }

    private static func normalizedReplyKey(_ value: String?) -> String {
        (value ?? "")
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanIssueValue(_ value: String?) -> Bool {
        let normalized = normalizedReplyKey(value)
        return ["none", "passed", "clean", "no issue", "no issues"].contains(normalized)
    }

    private static func genericPlaceholderReply(_ value: String?) -> Bool {
        let normalized = normalizedReplyKey(value)
        guard !normalized.isEmpty else { return false }
        return [
            "focused coach reply with concrete evidence",
            "grounded coach reply with a proof test",
            "generic coach reply",
            "placeholder",
            "practice more and communicate clearly",
            "based on your data",
            "keep practicing and track your progress"
        ].contains { normalized.contains($0) }
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    struct Summary: Codable, Equatable {
        let rowCount: Int
        let productionFloorFailureCount: Int
        let readinessWarnings: [String]
        let immediateCoachReadExpectedCount: Int
        let immediateCoachReadMissingCount: Int
        let assessmentConfidenceDistinctRoundedCount: Int
        let uniqueProofTestHashCount: Int
        let repeatedProofTestHashCount: Int
        let maxProviderRetryCount: Int
        let totalProviderRefusalCount: Int
        let firstVisibleTokenMaxMs: Int?
    }

    struct Row: Codable, Equatable {
        let fixtureID: String
        let turnDepth: String?
        let providerChosen: String?
        let providerModel: String?
        let timeToFirstVisibleTokenMs: Int?
        let assessmentConfidence: Double?
        let assessmentProofTestHash: String?
        let immediateCoachReadExpected: Bool?
        let immediateCoachReadShown: Bool?
        let liveProductionFloor: Bool
        let reply: String?
        let passesRubric: Bool?
        let visionPassesProductionFloor: Bool?
        let qualityIssue: String?
        let semanticGateIssue: String?
        let reliabilityIssues: [String]?

        var hasProviderEvidence: Bool {
            !(providerChosen ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                !(providerModel ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        var hasReadinessTelemetry: Bool {
            let proofHash = (assessmentProofTestHash ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let replyText = (reply ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let quality = (qualityIssue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let semantic = (semanticGateIssue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return !(turnDepth ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                timeToFirstVisibleTokenMs != nil &&
                assessmentConfidence != nil &&
                !proofHash.isEmpty &&
                !replyText.isEmpty &&
                passesRubric != nil &&
                visionPassesProductionFloor != nil &&
                !quality.isEmpty &&
                !semantic.isEmpty &&
                reliabilityIssues != nil &&
                ((immediateCoachReadExpected ?? false) ? immediateCoachReadShown == true : true)
        }

        var hasCleanProductionTelemetry: Bool {
            liveProductionFloor &&
                passesRubric == true &&
                visionPassesProductionFloor == true &&
                CoachLiveProviderSweepEvidence.cleanIssueValue(qualityIssue) &&
                CoachLiveProviderSweepEvidence.cleanIssueValue(semanticGateIssue) &&
                (reliabilityIssues ?? []).isEmpty
        }

        var normalizedReplyKey: String {
            CoachLiveProviderSweepEvidence.normalizedReplyKey(reply)
        }

        var hasGenericPlaceholderReply: Bool {
            CoachLiveProviderSweepEvidence.genericPlaceholderReply(reply)
        }
    }

    struct LongFormConversation: Codable, Equatable {
        let conversationID: String
        let sourceFixtureID: String
        let expectedTurnCount: Int
        let observedTurnCount: Int
        let liveProductionFloor: Bool
        let failure: String?
        let rows: [Row]
    }

    private static let requiredLongFormConversationTurnCountsByID: [String: Int] =
        Dictionary(
            uniqueKeysWithValues: CoachChatConversationCorpus.longFormConversations.map {
                ($0.id, $0.turns.count)
            }
        )
}

struct CoachVisionProductionReadinessAudit: Codable, Equatable {
    let score: Int
    let maximumAllowedScore: Int
    let localTargetShapeScore: Int
    let claim: CoachVisionProductionReadinessClaim
    let blockers: [CoachVisionProductionReadinessBlocker]
    let summary: String

    var productionReady: Bool {
        score >= 85 && blockers.isEmpty && claim == .productionReadyEvidenceAvailable
    }

    static func make(
        localTargetShapeScore: Int,
        evidence: CoachVisionProductionReadinessEvidence
    ) -> CoachVisionProductionReadinessAudit {
        let blockers = blockers(for: evidence)
        let rawScore = rawEvidenceScore(evidence)
        let maximumAllowedScore = cap(for: blockers)
        let score = min(rawScore, maximumAllowedScore)
        let claim: CoachVisionProductionReadinessClaim = blockers.isEmpty
            ? .productionReadyEvidenceAvailable
            : .localEvaluationSubstrateOnly
        return CoachVisionProductionReadinessAudit(
            score: score,
            maximumAllowedScore: maximumAllowedScore,
            localTargetShapeScore: localTargetShapeScore,
            claim: claim,
            blockers: blockers,
            summary: summary(
                score: score,
                localTargetShapeScore: localTargetShapeScore,
                claim: claim,
                blockers: blockers
            )
        )
    }

    static func localTargetShapeScore(
        from report: CoachChatConversationEvaluationReport
    ) -> Int {
        localTargetShapeScore(rows: report.rows)
    }

    static func localTargetShapeScore(
        rows: [CoachChatConversationEvaluationReportRow]
    ) -> Int {
        guard !rows.isEmpty else { return 0 }
        let total = rows.reduce(0) { $0 + $1.score }
        return Int((Double(total) / Double(rows.count)).rounded())
    }

    private static func rawEvidenceScore(
        _ evidence: CoachVisionProductionReadinessEvidence
    ) -> Int {
        var score = 0
        if evidence.localConversationCount >= 10 {
            score += 8
        }
        if evidence.localRowsPassingProductionFloor >= 10 {
            score += 2
        }
        if evidence.appPathImmediateReadVerified {
            score += 4
        }
        if evidence.appPathProofTestProgressionVerified {
            score += 4
        }
        if evidence.liveProviderRowsPassingFloor >= CoachLiveProviderSweepEvidence.requiredReadinessEvidenceCount {
            score += 16
        }
        if evidence.professionalCoachCalibrationRows >= CoachProfessionalCalibrationEvidence.requiredCalibrationReviewCount {
            score += 20
        }
        if evidence.realUserLongitudinalOutcomeCount >= 10 {
            score += 26
        }
        if evidence.realDeviceTestFlightVerified {
            score += 12
        }
        if evidence.operationalLaunchChecklistComplete {
            score += 8
        }
        return score
    }

    private static func blockers(
        for evidence: CoachVisionProductionReadinessEvidence
    ) -> [CoachVisionProductionReadinessBlocker] {
        var blockers: [CoachVisionProductionReadinessBlocker] = []
        if evidence.liveProviderRowsPassingFloor < CoachLiveProviderSweepEvidence.requiredReadinessEvidenceCount {
            blockers.append(.noLiveProviderTranscriptSweep)
        }
        if evidence.professionalCoachCalibrationRows < CoachProfessionalCalibrationEvidence.requiredCalibrationReviewCount {
            blockers.append(.noProfessionalCoachCalibration)
        }
        if evidence.realUserLongitudinalOutcomeCount < 10 {
            blockers.append(.noRealUserLongitudinalTransferOutcomes)
        }
        if !evidence.realDeviceTestFlightVerified {
            blockers.append(.noRealDeviceTestFlightVerification)
        }
        if !evidence.operationalLaunchChecklistComplete {
            blockers.append(.operationalLaunchChecklistIncomplete)
        }
        return blockers
    }

    private static func cap(
        for blockers: [CoachVisionProductionReadinessBlocker]
    ) -> Int {
        if blockers.contains(.noLiveProviderTranscriptSweep) ||
            blockers.contains(.noProfessionalCoachCalibration) ||
            blockers.contains(.noRealUserLongitudinalTransferOutcomes) {
            return 20
        }
        if blockers.contains(.noRealDeviceTestFlightVerification) {
            return 45
        }
        if blockers.contains(.operationalLaunchChecklistIncomplete) {
            return 60
        }
        return 100
    }

    private static func summary(
        score: Int,
        localTargetShapeScore: Int,
        claim: CoachVisionProductionReadinessClaim,
        blockers: [CoachVisionProductionReadinessBlocker]
    ) -> String {
        let blockerText = blockers.isEmpty
            ? "no blocking evidence gaps"
            : blockers.map(\.rawValue).joined(separator: ", ")
        return "VISION production readiness \(score)/100; local target-shape \(localTargetShapeScore)/100; claim \(claim.rawValue); blockers: \(blockerText)."
    }
}

struct CoachVisionProductionReadinessEvidence: Codable, Equatable {
    let localConversationCount: Int
    let localRowsPassingProductionFloor: Int
    let localLongFormConversationCount: Int
    let localLongFormRowsPassingConversationFloor: Int
    let localAdversarialConversationCount: Int
    let localAdversarialRowsRejectedByProductionFloor: Int
    let appPathImmediateReadVerified: Bool
    let appPathProofTestProgressionVerified: Bool
    let liveProviderRowsPassingFloor: Int
    let professionalCoachCalibrationRows: Int
    let realUserLongitudinalOutcomeCount: Int
    let realDeviceTestFlightVerified: Bool
    let operationalLaunchChecklistComplete: Bool

    static func currentLocalSubstrate(
        conversationCount: Int,
        rowsPassingProductionFloor: Int,
        longFormConversationCount: Int = 0,
        longFormRowsPassingConversationFloor: Int = 0,
        adversarialConversationCount: Int = 0,
        adversarialRowsRejectedByProductionFloor: Int = 0
    ) -> CoachVisionProductionReadinessEvidence {
        CoachVisionProductionReadinessEvidence(
            localConversationCount: conversationCount,
            localRowsPassingProductionFloor: rowsPassingProductionFloor,
            localLongFormConversationCount: longFormConversationCount,
            localLongFormRowsPassingConversationFloor: longFormRowsPassingConversationFloor,
            localAdversarialConversationCount: adversarialConversationCount,
            localAdversarialRowsRejectedByProductionFloor: adversarialRowsRejectedByProductionFloor,
            appPathImmediateReadVerified: true,
            appPathProofTestProgressionVerified: true,
            liveProviderRowsPassingFloor: 0,
            professionalCoachCalibrationRows: 0,
            realUserLongitudinalOutcomeCount: 0,
            realDeviceTestFlightVerified: false,
            operationalLaunchChecklistComplete: false
        )
    }
}

struct CoachVisionProductionReadinessEvidenceManifest: Codable, Equatable {
    static let schemaVersion = "coach-vision-production-readiness-evidence-manifest-v1"

    let schemaVersion: String
    let localTargetShapeScore: Int
    let evidence: CoachVisionProductionReadinessEvidence
    let audit: CoachVisionProductionReadinessAudit
    let rows: [CoachVisionProductionReadinessEvidenceRow]

    static func make(
        conversationReport: CoachChatConversationEvaluationReport,
        longFormConversationReport: CoachChatConversationEvaluationReport? = nil,
        adversarialConversationReport: CoachChatConversationEvaluationReport? = nil,
        expertPacket: CoachChatConversationExpertCalibrationPacket,
        textAppPathReport: CoachChatConversationAppPathReport,
        liveAppPathReport: CoachChatConversationAppPathReport,
        liveProviderSweep: CoachLiveProviderSweepEvidence? = nil,
        professionalCalibration: CoachProfessionalCalibrationEvidence? = nil,
        realUserTransferOutcomes: CoachRealUserTransferOutcomeEvidence? = nil,
        realDeviceTestFlight: CoachRealDeviceTestFlightEvidence? = nil,
        operationalLaunchChecklist: CoachOperationalLaunchChecklistEvidence? = nil
    ) -> CoachVisionProductionReadinessEvidenceManifest {
        let localRowsPassing = conversationReport.rows
            .filter(\.passesProductionFloor)
            .count
        let localLongFormRowsPassing = longFormConversationReport?.rows
            .filter(\.passesConversationFloor)
            .count ?? 0
        let localAdversarialRowsRejected = adversarialConversationReport?.summary
            .productionFloorFailureConversationIDs
            .count ?? 0
        let localTargetShapeScore = CoachVisionProductionReadinessAudit
            .localTargetShapeScore(from: conversationReport)
        let textAppPathVerified = textAppPathReport.surface == CoachReplySurface.text.rawValue &&
            textAppPathReport.passesAppPathFloor &&
            textAppPathReport.summary.readinessWarnings.isEmpty
        let liveAppPathVerified = liveAppPathReport.surface == CoachReplySurface.live.rawValue &&
            liveAppPathReport.passesAppPathFloor &&
            liveAppPathReport.summary.immediateCoachReadExpectedCount >= 10 &&
            liveAppPathReport.summary.immediateCoachReadMissingCount == 0 &&
            liveAppPathReport.summary.readinessWarnings.isEmpty
        let proofProgressionVerified = conversationReport.rows.allSatisfy { row in
            !row.missed.contains(CoachChatConversationCriterion.proofTestProgression.rawValue)
        }
        let appPathImmediateReadVerified = textAppPathVerified && liveAppPathVerified
        let appPathProofTestProgressionVerified = proofProgressionVerified &&
            textAppPathVerified &&
            liveAppPathVerified
        let verifiedLiveProviderRowsPassingFloor = liveProviderSweep?
            .rowsPassingReadinessFloor ?? 0
        let verifiedProfessionalCoachCalibrationRows = professionalCalibration?
            .rowsPassingCalibrationFloor ?? 0
        let verifiedRealUserTransferOutcomeRows = realUserTransferOutcomes?
            .rowsPassingOutcomeFloor ?? 0
        let verifiedRealDeviceTestFlight = realDeviceTestFlight?
            .qualifiesForReadiness == true
        let verifiedOperationalLaunchChecklist = operationalLaunchChecklist?
            .qualifiesForReadiness == true
        let evidence = CoachVisionProductionReadinessEvidence(
            localConversationCount: conversationReport.conversationCount,
            localRowsPassingProductionFloor: localRowsPassing,
            localLongFormConversationCount: longFormConversationReport?.conversationCount ?? 0,
            localLongFormRowsPassingConversationFloor: localLongFormRowsPassing,
            localAdversarialConversationCount: adversarialConversationReport?.conversationCount ?? 0,
            localAdversarialRowsRejectedByProductionFloor: localAdversarialRowsRejected,
            appPathImmediateReadVerified: appPathImmediateReadVerified,
            appPathProofTestProgressionVerified: appPathProofTestProgressionVerified,
            liveProviderRowsPassingFloor: verifiedLiveProviderRowsPassingFloor,
            professionalCoachCalibrationRows: verifiedProfessionalCoachCalibrationRows,
            realUserLongitudinalOutcomeCount: verifiedRealUserTransferOutcomeRows,
            realDeviceTestFlightVerified: verifiedRealDeviceTestFlight,
            operationalLaunchChecklistComplete: verifiedOperationalLaunchChecklist
        )
        let audit = CoachVisionProductionReadinessAudit.make(
            localTargetShapeScore: localTargetShapeScore,
            evidence: evidence
        )
        let rows = evidenceRows(
            conversationReport: conversationReport,
            longFormConversationReport: longFormConversationReport,
            adversarialConversationReport: adversarialConversationReport,
            expertPacket: expertPacket,
            textAppPathReport: textAppPathReport,
            liveAppPathReport: liveAppPathReport,
            liveProviderSweep: liveProviderSweep,
            professionalCalibration: professionalCalibration,
            realUserTransferOutcomes: realUserTransferOutcomes,
            realDeviceTestFlight: realDeviceTestFlight,
            operationalLaunchChecklist: operationalLaunchChecklist,
            evidence: evidence
        )
        return CoachVisionProductionReadinessEvidenceManifest(
            schemaVersion: schemaVersion,
            localTargetShapeScore: localTargetShapeScore,
            evidence: evidence,
            audit: audit,
            rows: rows
        )
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func evidenceRows(
        conversationReport: CoachChatConversationEvaluationReport,
        longFormConversationReport: CoachChatConversationEvaluationReport?,
        adversarialConversationReport: CoachChatConversationEvaluationReport?,
        expertPacket: CoachChatConversationExpertCalibrationPacket,
        textAppPathReport: CoachChatConversationAppPathReport,
        liveAppPathReport: CoachChatConversationAppPathReport,
        liveProviderSweep: CoachLiveProviderSweepEvidence?,
        professionalCalibration: CoachProfessionalCalibrationEvidence?,
        realUserTransferOutcomes: CoachRealUserTransferOutcomeEvidence?,
        realDeviceTestFlight: CoachRealDeviceTestFlightEvidence?,
        operationalLaunchChecklist: CoachOperationalLaunchChecklistEvidence?,
        evidence: CoachVisionProductionReadinessEvidence
    ) -> [CoachVisionProductionReadinessEvidenceRow] {
        let textAppPathEarned = textAppPathReport.surface == CoachReplySurface.text.rawValue &&
            textAppPathReport.passesAppPathFloor &&
            textAppPathReport.summary.readinessWarnings.isEmpty
        let textAppPathTurnsPassing = textAppPathReport.rows
            .flatMap(\.turns)
            .filter(\.passesAppPathFloor)
            .count
        let liveImmediateReadEarned = liveAppPathReport.surface == CoachReplySurface.live.rawValue &&
            liveAppPathReport.passesAppPathFloor &&
            liveAppPathReport.summary.immediateCoachReadMissingCount == 0 &&
            liveAppPathReport.summary.readinessWarnings.isEmpty
        let adversarialNegativeControlEarned = evidence.localAdversarialConversationCount >= 10 &&
            evidence.localAdversarialRowsRejectedByProductionFloor >= 10
        let liveProviderEarned = evidence.liveProviderRowsPassingFloor >=
            CoachLiveProviderSweepEvidence.requiredReadinessEvidenceCount &&
            liveProviderSweep?.qualifiesForReadiness == true
        let liveProviderSource = liveProviderSweep?.schemaVersion ??
            CoachLiveProviderSweepEvidence.expectedSchemaVersion
        let liveProviderNotes: String = {
            guard let liveProviderSweep else {
                return "Requires real provider replies through the live transcript harness; scripted app-path rows do not count."
            }
            if liveProviderSweep.qualifiesForReadiness {
                return "\(liveProviderSweep.rows.count) latest-turn rows and \(liveProviderSweep.longFormConversationIDsPassingProductionFloor.count) long-form conversations passed the run readiness floor; providerChain=\(liveProviderSweep.providerChain.joined(separator: " -> "))"
            }
            return "Live-provider report rejected: \(liveProviderSweep.rejectionReasons.joined(separator: ","))"
        }()
        let professionalCalibrationEarned = evidence.professionalCoachCalibrationRows >=
            CoachProfessionalCalibrationEvidence.requiredCalibrationReviewCount &&
            professionalCalibration?.qualifiesForReadiness == true
        let professionalCalibrationSource = professionalCalibration?.schemaVersion ??
            CoachProfessionalCalibrationEvidence.expectedSchemaVersion
        let professionalCalibrationNotes: String = {
            guard let professionalCalibration else {
                return "Packet status \(expertPacket.humanGateStatus.rawValue) for \(expertPacket.conversationCount) conversations; pending expert review does not count as calibration."
            }
            if professionalCalibration.qualifiesForReadiness {
                return "\(professionalCalibration.rows.count) professional-coach calibration rows passed; reviewerRole=\(professionalCalibration.reviewerRole); sourcePacketFingerprint=\(professionalCalibration.sourcePacketFingerprint ?? "missing")"
            }
            return "Professional calibration results rejected: \(professionalCalibration.rejectionReasons.joined(separator: ","))"
        }()
        let realUserTransferEarned = evidence.realUserLongitudinalOutcomeCount >= 10 &&
            realUserTransferOutcomes?.qualifiesForReadiness == true
        let realUserTransferSource = realUserTransferOutcomes?.schemaVersion ??
            CoachRealUserTransferOutcomeEvidence.expectedSchemaVersion
        let realUserTransferNotes: String = {
            guard let realUserTransferOutcomes else {
                return "Requires longitudinal off-app outcome follow-ups tied to real user transfer moments."
            }
            if realUserTransferOutcomes.qualifiesForReadiness {
                return "\(realUserTransferOutcomes.rows.count) real-user transfer outcomes passed; cohort=\(realUserTransferOutcomes.cohortDescription)"
            }
            return "Real-user transfer outcomes rejected: \(realUserTransferOutcomes.rejectionReasons.joined(separator: ","))"
        }()
        let realDeviceSource = realDeviceTestFlight?.schemaVersion ??
            CoachRealDeviceTestFlightEvidence.expectedSchemaVersion
        let realDeviceNotes: String = {
            guard let realDeviceTestFlight else {
                return "Simulator and local XCTest evidence do not cover real-device voice/live behavior."
            }
            if realDeviceTestFlight.qualifiesForReadiness {
                return "Real-device TestFlight QA passed on \(realDeviceTestFlight.deviceModel) / \(realDeviceTestFlight.osVersion); build=\(realDeviceTestFlight.buildNumber)"
            }
            return "Real-device TestFlight QA rejected: \(realDeviceTestFlight.rejectionReasons.joined(separator: ","))"
        }()
        let operationalSource = operationalLaunchChecklist?.schemaVersion ??
            CoachOperationalLaunchChecklistEvidence.expectedSchemaVersion
        let operationalNotes: String = {
            guard let operationalLaunchChecklist else {
                return "Requires deployment/ops evidence, not code-only readiness."
            }
            if operationalLaunchChecklist.qualifiesForReadiness {
                return "M14 launch checklist passed for build \(operationalLaunchChecklist.releaseCandidateBuild)."
            }
            return "M14 launch checklist rejected: \(operationalLaunchChecklist.rejectionReasons.joined(separator: ","))"
        }()
        return [
            CoachVisionProductionReadinessEvidenceRow(
                key: "localConversationCorpus",
                status: evidence.localConversationCount >= 10 &&
                    evidence.localRowsPassingProductionFloor >= 10 ? .earned : .missing,
                observedCount: evidence.localRowsPassingProductionFloor,
                requiredCount: 10,
                source: conversationReport.schemaVersion,
                blocker: nil,
                notes: "\(conversationReport.conversationCount) conversations; \(evidence.localRowsPassingProductionFloor) rows pass the local production floor."
            ),
            CoachVisionProductionReadinessEvidenceRow(
                key: "longFormConversationCorpus",
                status: evidence.localLongFormConversationCount >= 10 &&
                    evidence.localLongFormRowsPassingConversationFloor >= 10 ? .earned : .missing,
                observedCount: evidence.localLongFormRowsPassingConversationFloor,
                requiredCount: 10,
                source: longFormConversationReport?.schemaVersion ??
                    CoachChatConversationCorpus.longFormReportSchemaVersion,
                blocker: nil,
                notes: "\(evidence.localLongFormConversationCount) five-turn conversations; local substrate only, no production score lift."
            ),
            CoachVisionProductionReadinessEvidenceRow(
                key: "adversarialNegativeControlCorpus",
                status: adversarialNegativeControlEarned ? .earned : .missing,
                observedCount: evidence.localAdversarialRowsRejectedByProductionFloor,
                requiredCount: 10,
                source: adversarialConversationReport?.schemaVersion ??
                    CoachChatConversationCorpus.longFormAdversarialReportSchemaVersion,
                blocker: nil,
                notes: "\(evidence.localAdversarialConversationCount) paired failure conversations; all must fail the production floor so local evaluator blind spots stay visible."
            ),
            CoachVisionProductionReadinessEvidenceRow(
                key: "textAppPathReplay",
                status: textAppPathEarned ? .earned : .missing,
                observedCount: textAppPathTurnsPassing,
                requiredCount: textAppPathReport.summary.turnCount,
                source: textAppPathReport.schemaVersion,
                blocker: nil,
                notes: "surface=\(textAppPathReport.surface); warnings=\(textAppPathReport.summary.readinessWarnings.joined(separator: ","))"
            ),
            CoachVisionProductionReadinessEvidenceRow(
                key: "liveAppPathImmediateRead",
                status: liveImmediateReadEarned ? .earned : .missing,
                observedCount: liveAppPathReport.summary.immediateCoachReadExpectedCount -
                    liveAppPathReport.summary.immediateCoachReadMissingCount,
                requiredCount: liveAppPathReport.summary.immediateCoachReadExpectedCount,
                source: liveAppPathReport.schemaVersion,
                blocker: nil,
                notes: "surface=\(liveAppPathReport.surface); expected immediate reads=\(liveAppPathReport.summary.immediateCoachReadExpectedCount)."
            ),
            CoachVisionProductionReadinessEvidenceRow(
                key: "liveProviderTranscriptSweep",
                status: liveProviderEarned ? .earned : .missing,
                observedCount: evidence.liveProviderRowsPassingFloor,
                requiredCount: CoachLiveProviderSweepEvidence.requiredReadinessEvidenceCount,
                source: liveProviderSource,
                blocker: liveProviderEarned ? nil : .noLiveProviderTranscriptSweep,
                notes: liveProviderNotes
            ),
            CoachVisionProductionReadinessEvidenceRow(
                key: "professionalCoachCalibration",
                status: professionalCalibrationEarned ? .earned : .pending,
                observedCount: evidence.professionalCoachCalibrationRows,
                requiredCount: CoachProfessionalCalibrationEvidence.requiredCalibrationReviewCount,
                source: professionalCalibrationSource,
                blocker: professionalCalibrationEarned ? nil : .noProfessionalCoachCalibration,
                notes: professionalCalibrationNotes
            ),
            CoachVisionProductionReadinessEvidenceRow(
                key: "realUserLongitudinalTransferOutcomes",
                status: realUserTransferEarned ? .earned : .missing,
                observedCount: evidence.realUserLongitudinalOutcomeCount,
                requiredCount: 10,
                source: realUserTransferSource,
                blocker: realUserTransferEarned ? nil : .noRealUserLongitudinalTransferOutcomes,
                notes: realUserTransferNotes
            ),
            CoachVisionProductionReadinessEvidenceRow(
                key: "realDeviceTestFlightVerification",
                status: evidence.realDeviceTestFlightVerified ? .earned : .missing,
                observedCount: evidence.realDeviceTestFlightVerified ? 1 : 0,
                requiredCount: 1,
                source: realDeviceSource,
                blocker: evidence.realDeviceTestFlightVerified ? nil : .noRealDeviceTestFlightVerification,
                notes: realDeviceNotes
            ),
            CoachVisionProductionReadinessEvidenceRow(
                key: "operationalLaunchChecklist",
                status: evidence.operationalLaunchChecklistComplete ? .earned : .missing,
                observedCount: evidence.operationalLaunchChecklistComplete ? 1 : 0,
                requiredCount: 1,
                source: operationalSource,
                blocker: evidence.operationalLaunchChecklistComplete ? nil : .operationalLaunchChecklistIncomplete,
                notes: operationalNotes
            )
        ]
    }
}

struct CoachVisionProductionReadinessEvidenceRow: Codable, Equatable {
    let key: String
    let status: CoachVisionProductionReadinessEvidenceStatus
    let observedCount: Int
    let requiredCount: Int
    let source: String
    let blocker: CoachVisionProductionReadinessBlocker?
    let notes: String
}

enum CoachVisionProductionReadinessEvidenceStatus: String, Codable, Equatable {
    case earned
    case pending
    case missing
}

enum CoachVisionProductionReadinessClaim: String, Codable, Equatable {
    case localEvaluationSubstrateOnly
    case productionReadyEvidenceAvailable
}

enum CoachVisionProductionReadinessBlocker: String, Codable, Equatable {
    case noLiveProviderTranscriptSweep
    case noProfessionalCoachCalibration
    case noRealUserLongitudinalTransferOutcomes
    case noRealDeviceTestFlightVerification
    case operationalLaunchChecklistIncomplete
}

struct CoachChatExpertReviewPacket: Codable, Equatable {
    let schemaVersion: String
    let rubricVersion: String
    let instructions: String
    let responseSchema: String
    let fixtureCount: Int
    let rows: [CoachChatExpertReviewPacketRow]

    static func make(from fixtures: [CoachChatEvaluationFixture]) -> CoachChatExpertReviewPacket {
        CoachChatExpertReviewPacket(
            schemaVersion: CoachChatEvaluationCorpus.expertReviewPacketSchemaVersion,
            rubricVersion: "coach-chat-eval-v1",
            instructions: [
                "Write the answer an excellent human communication coach would give for each case.",
                "Use only the supplied user turn, prior coach reply, and Noum context.",
                "Name one highest-leverage next move; avoid broad menus, trait labels, diagnoses, or claims that the app is validated.",
                "Mark thin evidence as a hypothesis and include what evidence would change your view.",
                "Do not score Noum in this packet; this captures an independent expert baseline for later blinded comparison."
            ].joined(separator: " "),
            responseSchema: "Return one JSON object per fixture: {\"fixtureID\": string, \"coachSummary\": string, \"recommendedReply\": string, \"evidenceUsed\": [string], \"uncertainty\": string, \"qualityNotes\": [string]}.",
            fixtureCount: fixtures.count,
            rows: fixtures.map { fixture in
                CoachChatExpertReviewPacketRow(
                    fixtureID: fixture.id,
                    pillar: fixture.pillar.rawValue,
                    expertBaselineStatus: fixture.expertBaseline.status.rawValue,
                    latestUserTurn: fixture.latestUserTurn,
                    previousCoachReply: fixture.previousCoachReply,
                    coachContext: CoachChatEvaluationCorpus.renderedContext(for: fixture)
                )
            }
        )
    }

    func encodedSortedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct CoachChatExpertReviewPacketRow: Codable, Equatable {
    let fixtureID: String
    let pillar: String
    let expertBaselineStatus: String
    let latestUserTurn: String
    let previousCoachReply: String?
    let coachContext: String
}

enum CoachChatEvaluationCorpus {
    static let reportSchemaVersion = "coach-chat-eval-report-v6"
    static let expertReviewPacketSchemaVersion = "coach-chat-expert-review-packet-v1"
    static let latestManualEvalFixtureIDs = [
        "cold-start-interview-baseline",
        "filler-pressure-prescription",
        "metric-action-without-read",
        "critique-trust-repair",
        "markdown-tts-trust-repair",
        "assistant-explainer-register",
        "authoritative-distance-deep-assessment",
        "what-next-single-move",
        "overclaim-hypothesis-boundary",
        "personal-pattern-hypothesis-confirmation",
        "leadership-transfer-setup",
        "pace-control-next-rep",
        "closing-ask-proof-test",
        "opening-verdict-next-rep",
        "pause-before-answer-drill",
        "concise-answer-next-rep",
        "structure-one-reason-proof",
        "confidence-clean-stop",
        "answer-depth-one-example",
        "closing-stop-no-summary"
    ]

    static let fixtures: [CoachChatEvaluationFixture] = [
        CoachChatEvaluationFixture(
            id: "cold-start-interview-baseline",
            pillar: .diagnosis,
            expertBaseline: .pending,
            profile: nil,
            sessions: [],
            trends: [],
            latestUserTurn: "How do I get better before my interview?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "No voice set yet",
                "No rated sessions yet",
                "Not enough data for a stable baseline yet",
                "COACH FORMULATION",
                "first useful coaching move is one usable rep",
                "do not ask a discovery question"
            ],
            referenceReply: "No baseline yet, so the honest move is one interview rep. Record 60 seconds on a likely question, then review whether the first sentence gives the point before polishing anything.",
            knownBadReply: "Keep practicing and try to sound more confident.",
            expectedBadIssue: .roboticPhrase("keep practicing")
        ),
        CoachChatEvaluationFixture(
            id: "filler-pressure-prescription",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .concise, challenge: .fillerWords),
            sessions: [
                session(
                    id: "11111111-1111-1111-1111-111111111111",
                    transcript: "I think the plan is strong, um, but I need the team to move faster before Friday.",
                    fillerCount: 6,
                    duration: 64,
                    daysAgo: 1,
                    mode: .timed,
                    score: 6,
                    prompt: "Give a concise team update."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .fillerReduction,
                    direction: .declining,
                    confidence: .high,
                    windowSize: 5,
                    currentLevel: .weak,
                    recentDelta: "2 more fillers vs prior window"
                )
            ],
            latestUserTurn: "How do I stop saying um under pressure?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "6 fillers",
                "TRENDS",
                "COACH FORMULATION",
                "silence as the replacement behavior"
            ],
            referenceReply: "Last rep had 6 fillers; the pressure cue is showing up before the close. Next rep, hold one beat before the final sentence and cut every filler after that point.",
            knownBadReply: "Based on your data, the key insight is reducing fillers.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "metric-action-without-read",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .fillerWords),
            sessions: [
                session(
                    id: "66666666-6666-6666-6666-666666666666",
                    transcript: "The recommendation is to hold the launch date, um, because the customer migration is not ready.",
                    fillerCount: 5,
                    duration: 61,
                    daysAgo: 1,
                    mode: .timed,
                    score: 6,
                    prompt: "Give a direct recommendation."
                )
            ],
            trends: [],
            latestUserTurn: "What should I do with that filler count?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "5 fillers",
                "Safe filler fact",
                "COACH FORMULATION",
                "leverage is the beat after the decision"
            ],
            referenceReply: "Last rep had 5 fillers; the signal is inside the recommendation, not before it. Next rep, hold one beat after the decision line and restart if a filler appears.",
            knownBadReply: "Your last rep had 5 fillers. Next rep, hold one beat before sentence two.",
            expectedBadIssue: .missingInsightBridge
        ),
        CoachChatEvaluationFixture(
            id: "critique-trust-repair",
            pillar: .adaptation,
            expertBaseline: .pending,
            profile: profile(voice: .warm, challenge: .rambling),
            sessions: [
                session(
                    id: "22222222-2222-2222-2222-222222222222",
                    transcript: "The point is that I can help the client, but I went too wide before saying it.",
                    fillerCount: 1,
                    duration: 58,
                    daysAgo: 0,
                    mode: .timed,
                    score: 7,
                    prompt: "Answer a client objection warmly."
                )
            ],
            trends: [],
            latestUserTurn: "This is robotic and too much writing.",
            previousCoachReply: "Recent reps show a decline in scores, so you should optimize your communication plan.",
            expectedContextNeedles: [
                "repair trust first",
                "specific friction",
                "RECENT (most-recent first)"
            ],
            referenceReply: "Fair push: that read was too generic. The last rep gives enough signal; next rep, use one clean opener and stop after the point lands.",
            knownBadReply: "Next rep, use one clean opener and stop after the point lands.",
            expectedBadIssue: .missedTrustRepair
        ),
        CoachChatEvaluationFixture(
            id: "markdown-tts-trust-repair",
            pillar: .adaptation,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .fillerWords),
            sessions: [
                session(
                    id: "77777777-7777-7777-7777-777777777777",
                    transcript: "My recommendation is to hold the date, um, because the launch risk is still unresolved.",
                    fillerCount: 4,
                    duration: 52,
                    daysAgo: 0,
                    mode: .timed,
                    score: 6,
                    prompt: "Give a direct stakeholder recommendation."
                )
            ],
            trends: [],
            latestUserTurn: "The ** don't format and TTS reads them out. The responses feel robotic and cold, nowhere near an expert coach.",
            previousCoachReply: "**Read:** Your last rep has fillers. **Move:** practice more.",
            expectedContextNeedles: [
                "repair trust first",
                "specific friction",
                "Never output literal Markdown markers",
                "same text may be spoken aloud"
            ],
            referenceReply: "Fair push: the stars should never reach you or the voice, and that made the coaching feel robotic and cold. Your last rep had 4 fillers, so for the next rep, state the recommendation first, give one proof, then stop. No symbols, no report shape.",
            knownBadReply: "The app is designed to provide AI coaching, and formatting like **Read:** may appear while the system improves.",
            expectedBadIssue: .defensiveProductLanguage
        ),
        CoachChatEvaluationFixture(
            id: "assistant-explainer-register",
            pillar: .adaptation,
            expertBaseline: .pending,
            profile: profile(voice: .warm, challenge: .rambling),
            sessions: [
                session(
                    id: "88888888-8888-8888-8888-888888888888",
                    transcript: "I wanted to reassure the client first, but I took too long to say the actual recommendation.",
                    fillerCount: 1,
                    duration: 66,
                    daysAgo: 0,
                    mode: .timed,
                    score: 6,
                    prompt: "Answer a client concern with warmth."
                )
            ],
            trends: [],
            latestUserTurn: "This still sounds cold and overexplained, like generic AI tips.",
            previousCoachReply: "Here are some tips to communicate more clearly: be clear and concise and practice often.",
            expectedContextNeedles: [
                "repair trust first",
                "specific friction",
                "RECENT (most-recent first)",
                "1 filler",
                "Safe warmth fact",
                "COACH FORMULATION",
                "ordering signal"
            ],
            referenceReply: "Fair push: that was advice, not coaching. Your last rep has the useful signal: warmth came before the recommendation, so next rep say the recommendation first, then soften it with one reassurance.",
            knownBadReply: "I understand your frustration. Here are some tips to communicate more clearly: be clear and concise, structure your thoughts, and practice confidence.",
            expectedBadIssue: .roboticPhrase("i understand your frustration")
        ),
        CoachChatEvaluationFixture(
            id: "authoritative-distance-deep-assessment",
            pillar: .honesty,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .fillerWords),
            sessions: [
                session(
                    id: "99999999-9999-9999-9999-999999999999",
                    transcript: "My recommendation is to keep the launch date because the customer migration risk is contained, and the team needs a clear decision today.",
                    fillerCount: 1,
                    duration: 60,
                    daysAgo: 0,
                    mode: .timed,
                    score: 7,
                    prompt: "Give a direct stakeholder recommendation."
                )
            ],
            trends: [],
            latestUserTurn: "How far off am I from sounding authoritative?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "7/10",
                "1 filler",
                "ARGUMENT LOGIC",
                "authoritative"
            ],
            referenceReply: "You are closer mechanically than you are to sounding authoritative overall. The transcript opens with a recommendation, and the latest timed rep was 7/10 with 1 filler, so the mechanics are partly landing, but goal readiness still needs repeated pressure evidence. Missing: more than one clean rep under stakes. Proof test: record a 75-second answer with the verdict in sentence one, one reason, and a clean stop.",
            knownBadReply: "This proves you are close to sounding authoritative. You scored 7/10, so use fewer fillers next time.",
            expectedBadIssue: .overclaimsEvidence
        ),
        CoachChatEvaluationFixture(
            id: "what-next-single-move",
            pillar: .validation,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .rushing),
            sessions: [
                session(
                    id: "33333333-3333-3333-3333-333333333333",
                    transcript: "We can keep the launch tight if we align scope now and make the decision before noon.",
                    fillerCount: 0,
                    duration: 42,
                    daysAgo: 2,
                    mode: .timed,
                    score: 8,
                    prompt: "Give an executive update."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .closingStrength,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "close lost force in recent reps"
                )
            ],
            latestUserTurn: "What next?",
            previousCoachReply: "Which direction would you prefer?",
            expectedContextNeedles: [
                "choose the highest-leverage next action",
                "No broad menu",
                "RECENT (most-recent first)"
            ],
            referenceReply: "The pattern I'd pick is the rushed close. Review the last transcript, rewrite only the final sentence, then run one rep with that close as the target.",
            knownBadReply: "We can work on fillers or structure. What is your priority today?",
            expectedBadIssue: .menuInsteadOfDecision
        ),
        CoachChatEvaluationFixture(
            id: "overclaim-hypothesis-boundary",
            pillar: .honesty,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .freezing),
            sessions: [
                session(
                    id: "44444444-4444-4444-4444-444444444444",
                    transcript: "I waited too long to state the recommendation, then gave the context after it.",
                    fillerCount: 2,
                    duration: 55,
                    daysAgo: 1,
                    mode: .timed,
                    score: 6,
                    prompt: "Make a recommendation under pressure."
                )
            ],
            trends: [],
            latestUserTurn: "Why did that answer land badly?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "PROMPT RELEVANCE",
                "ARGUMENT LOGIC",
                "RECENT (most-recent first)",
                "REPLY-SAFE FACTS",
                "recommendation arrived late",
                "do not say the point led",
                "2 fillers",
                "COACH FORMULATION",
                "do not say the recommendation was up front"
            ],
            referenceReply: "From the transcript, I would treat it as a hypothesis: the recommendation arrived late. Next rep, say the conclusion first, then add one reason.",
            knownBadReply: "You are clearly evasive, and this proves you lack conviction.",
            expectedBadIssue: .overclaimsEvidence
        ),
        CoachChatEvaluationFixture(
            id: "personal-pattern-hypothesis-confirmation",
            pillar: .honesty,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .rambling),
            sessions: [
                session(
                    id: "12121212-1212-1212-1212-121212121212",
                    transcript: "I disagree with the direction, but I understand the concern, and maybe we can keep exploring options before I say no.",
                    fillerCount: 1,
                    duration: 63,
                    daysAgo: 1,
                    mode: .timed,
                    score: 6,
                    prompt: "Disagree with a stakeholder calmly."
                )
            ],
            trends: [],
            latestUserTurn: "Do I sound defensive when I disagree?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "1 filler",
                "COACH FORMULATION",
                "hypothesis",
                "do not label the user"
            ],
            referenceReply: "From the transcript, I would treat defensiveness as a hypothesis, not a label: you softened the disagreement and added context before the point. Check whether that fits; next rep, say the disagreement in sentence one, give one reason, then stop.",
            knownBadReply: "You are defensive because you fear disagreement and lack conviction.",
            expectedBadIssue: .overclaimsEvidence
        ),
        CoachChatEvaluationFixture(
            id: "leadership-transfer-setup",
            pillar: .transfer,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .rambling),
            sessions: [
                session(
                    id: "55555555-5555-5555-5555-555555555555",
                    transcript: "The update is simple: customer onboarding is ahead, support volume is down, and I need approval on the rollout date.",
                    fillerCount: 0,
                    duration: 72,
                    daysAgo: 3,
                    mode: .timed,
                    score: 8,
                    prompt: "Give a leadership update."
                )
            ],
            trends: [],
            latestUserTurn: "I have a leadership update tomorrow, what should I practice?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "Where they want to use this",
                "RECENT (most-recent first)",
                "0 fillers",
                "COACH FORMULATION",
                "75-second update"
            ],
            referenceReply: "Your recent timed rep was solid on fillers but light on the close. Record a 75-second leadership update and make the final sentence the ask, not a summary.",
            knownBadReply: "You should think about your audience and try to communicate clearly.",
            expectedBadIssue: .roboticPhrase("think about your audience")
        ),
        CoachChatEvaluationFixture(
            id: "pace-control-next-rep",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .rushing),
            sessions: [
                session(
                    id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                    transcript: "The decision is to keep support staffed through Friday because the migration will create two peak windows, and I need approval today.",
                    fillerCount: 0,
                    duration: 38,
                    daysAgo: 1,
                    mode: .timed,
                    score: 7,
                    prompt: "Give a calm operations update."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .paceControl,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "recent reps are landing compressed"
                )
            ],
            latestUserTurn: "How do I slow down without sounding unsure?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "Current coaching hypothesis: Pace is the next lever",
                "recent reps are landing compressed"
            ],
            referenceReply: "Your last rep is clean but compressed. Next rep, keep the same first sentence, then pause once after the decision so the reason has room to land.",
            knownBadReply: "Based on your data, slow down and sound more confident.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "closing-ask-proof-test",
            pillar: .validation,
            expertBaseline: .pending,
            profile: profile(voice: .persuasive, challenge: .rambling),
            sessions: [
                session(
                    id: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                    transcript: "The pilot is working, adoption is up, and I need your approval to expand it next week.",
                    fillerCount: 1,
                    duration: 54,
                    daysAgo: 1,
                    mode: .timed,
                    score: 7,
                    prompt: "Make a persuasive request."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .closingStrength,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "final ask has softened in recent reps"
                )
            ],
            latestUserTurn: "How do I make the ending stronger?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "1 filler",
                "TRENDS",
                "Current coaching hypothesis: Closings is the next lever",
                "final ask has softened in recent reps"
            ],
            referenceReply: "Your last rep already named the approval ask, but the close still softened after the evidence. Next rep, make the final sentence the ask itself: approve the expansion next week, then stop.",
            knownBadReply: "Based on your data, think about your audience and communicate more clearly.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "opening-verdict-next-rep",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .rambling),
            sessions: [
                session(
                    id: "cccccccc-cccc-cccc-cccc-cccccccccccc",
                    transcript: "The answer is yes, the pilot is ready to expand because usage is up and support volume is stable.",
                    fillerCount: 0,
                    duration: 46,
                    daysAgo: 1,
                    mode: .timed,
                    score: 8,
                    prompt: "Give a concise recommendation."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .openingStrength,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "openers are warming up before the point"
                )
            ],
            latestUserTurn: "How do I make the opening stronger?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "openers are warming up before the point",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep is clean, but the useful gap is the opener: it warms into the point, so the verdict arrives late. Next rep, make sentence one the verdict, then add one reason.",
            knownBadReply: "Based on your data, make the opening clearer.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "pause-before-answer-drill",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .freezing),
            sessions: [
                session(
                    id: "dddddddd-dddd-dddd-dddd-dddddddddddd",
                    transcript: "I think we should pause the rollout because the support queue is overloaded and the customer risk is still open.",
                    fillerCount: 2,
                    duration: 50,
                    daysAgo: 1,
                    mode: .timed,
                    score: 6,
                    prompt: "Respond to a difficult stakeholder question."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .pauseUsage,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "pauses are disappearing under pressure"
                )
            ],
            latestUserTurn: "What should I practice when I freeze before answering?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "2 fillers",
                "TRENDS",
                "pauses are disappearing under pressure",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep had 2 fillers, and the signal is the pause disappearing before the answer. Next rep, hold one silent beat before sentence one, then answer.",
            knownBadReply: "Based on your data, practice confidence and communicate clearly.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "concise-answer-next-rep",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .concise, challenge: .rambling),
            sessions: [
                session(
                    id: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
                    transcript: "The proposal is ready, the cost is controlled, and the team can begin on Monday if we approve today.",
                    fillerCount: 0,
                    duration: 49,
                    daysAgo: 1,
                    mode: .timed,
                    score: 8,
                    prompt: "Give a concise project update."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .conciseSpeaking,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "recent answers are carrying extra context"
                )
            ],
            latestUserTurn: "How do I tighten this answer?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "recent answers are carrying extra context",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep is already clean; the signal is the extra condition adding drag. Next rep, say the recommendation in one sentence, give one reason, then stop.",
            knownBadReply: "Based on your data, make it shorter and communicate clearly.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "structure-one-reason-proof",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .persuasive, challenge: .rambling),
            sessions: [
                session(
                    id: "ffffffff-ffff-ffff-ffff-ffffffffffff",
                    transcript: "The pilot should continue because adoption rose and support load stayed manageable.",
                    fillerCount: 0,
                    duration: 57,
                    daysAgo: 1,
                    mode: .timed,
                    score: 7,
                    prompt: "Make a persuasive case."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .structure,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "reasons are not consistently tied to the ask"
                )
            ],
            latestUserTurn: "How do I make the middle clearer?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "reasons are not consistently tied to the ask",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep has the claim and a reason; the signal is that the reason is not yet tied to the ask. Next rep, use claim, one reason, and one sentence that says what that reason makes possible.",
            knownBadReply: "Based on your data, structure the middle more clearly.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "confidence-clean-stop",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .authoritative, challenge: .freezing),
            sessions: [
                session(
                    id: "12121212-1212-1212-1212-121212121212",
                    transcript: "My recommendation is to keep the launch date because the risk is contained.",
                    fillerCount: 0,
                    duration: 36,
                    daysAgo: 1,
                    mode: .timed,
                    score: 7,
                    prompt: "Give a direct recommendation."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .confidence,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "final lines are ending cautiously"
                )
            ],
            latestUserTurn: "How do I sound more certain at the end?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "final lines are ending cautiously",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep is clear; the signal is the close keeps softening. Next rep, say the recommendation once, give one reason, and stop without adding a softener.",
            knownBadReply: "Based on your data, sound more confident and believe in yourself.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "answer-depth-one-example",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .rambling),
            sessions: [
                session(
                    id: "34343434-3434-3434-3434-343434343434",
                    transcript: "We should retain the vendor because implementation risk is lower, the team already knows the workflow, and switching now would slow the launch.",
                    fillerCount: 0,
                    duration: 63,
                    daysAgo: 1,
                    mode: .timed,
                    score: 8,
                    prompt: "Give an executive recommendation."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .answerDevelopment,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "answers need one concrete example before they expand"
                )
            ],
            latestUserTurn: "How do I add depth without rambling?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "answers need one concrete example before they expand",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep has strong reasons; the signal is no concrete example for the listener to picture. Next rep, keep the same claim, add one example, then stop before adding a second thread.",
            knownBadReply: "Based on your data, add more depth but avoid rambling.",
            expectedBadIssue: .roboticPhrase("based on your data")
        ),
        CoachChatEvaluationFixture(
            id: "closing-stop-no-summary",
            pillar: .prescription,
            expertBaseline: .pending,
            profile: profile(voice: .executive, challenge: .rambling),
            sessions: [
                session(
                    id: "56565656-5656-5656-5656-565656565656",
                    transcript: "The safest choice is to renew the contract, keep support stable, and review pricing after the pilot.",
                    fillerCount: 0,
                    duration: 48,
                    daysAgo: 1,
                    mode: .timed,
                    score: 8,
                    prompt: "Give a concise recommendation."
                )
            ],
            trends: [
                SkillTrend(
                    skillArea: .closingStrength,
                    direction: .declining,
                    confidence: .medium,
                    windowSize: 4,
                    currentLevel: .developing,
                    recentDelta: "final sentences are turning into summaries"
                )
            ],
            latestUserTurn: "How do I stop trailing off at the end?",
            previousCoachReply: nil,
            expectedContextNeedles: [
                "RECENT (most-recent first)",
                "0 fillers",
                "TRENDS",
                "final sentences are turning into summaries",
                "COACHING EXPERTISE"
            ],
            referenceReply: "Your last rep has the decision; the signal is the ending turns into a summary. Next rep, make the final sentence the decision itself and stop there.",
            knownBadReply: "Based on your data, make the ending stronger and clearer.",
            expectedBadIssue: .roboticPhrase("based on your data")
        )
    ]

    static func deterministicCoachingExpertise(for fixture: CoachChatEvaluationFixture) -> [CoachKnowledgeCard] {
        KnowledgeRetriever.retrieve(
            query: fixture.latestUserTurn,
            lever: fixture.trends.first?.skillArea,
            voice: fixture.profile?.speakingStyleGoal,
            hasDiagnosis: !fixture.sessions.isEmpty
        )
    }

    static func quoteGuard(for fixture: CoachChatEvaluationFixture) -> CoachChatQuoteGuardContext {
        let recentTimed = fixture.sessions
            .filter { $0.mode == .timed }
            .max(by: { $0.date < $1.date })
        return CoachChatQuoteGuardContext(
            transcripts: [recentTimed?.transcript],
            latestUserTurn: fixture.latestUserTurn,
            recentUserTurns: [fixture.latestUserTurn]
        )
    }

    static func renderedContext(for fixture: CoachChatEvaluationFixture) -> String {
        CoachContextBuilder.userContext(
            profile: fixture.profile,
            baseline: .empty,
            rating: .initial,
            sessions: fixture.sessions,
            currentStreak: fixture.sessions.isEmpty ? 0 : 2,
            pathStatus: nil,
            pathGatingPhrase: nil,
            trends: fixture.trends,
            latestUserTurn: fixture.latestUserTurn,
            previousCoachReply: fixture.previousCoachReply,
            coachingExpertise: deterministicCoachingExpertise(for: fixture)
        )
    }

    static func contains(_ haystack: String, _ needle: String) -> Bool {
        haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    private static func profile(
        voice: SpeakingStyleGoal,
        challenge: SpeakingChallenge
    ) -> CoachingProfile {
        CoachingProfile(
            speakingContext: .work,
            primaryGoal: challenge.recommendedPriority,
            confidenceLevel: .inconsistent,
            biggestChallenge: challenge,
            desiredOutcome: voice.recommendedOutcome,
            speakingStyleGoal: voice,
            styleReference: "",
            coachingBrief: "I want senior coaching that makes my work communication sharper.",
            motivationWhyNow: "There are higher-stakes conversations coming up.",
            successVision: "I can land the point cleanly under pressure.",
            chosenStyleGoal: voice
        )
    }

    private static func session(
        id: String,
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        daysAgo: Int,
        mode: PracticeMode,
        score: Int,
        prompt: String
    ) -> PracticeSession {
        let date = Calendar(identifier: .gregorian).date(
            byAdding: .day,
            value: -daysAgo,
            to: Date(timeIntervalSince1970: 1_775_000_000)
        ) ?? Date(timeIntervalSince1970: 1_775_000_000)

        return PracticeSession(
            id: UUID(uuidString: id) ?? UUID(),
            transcript: transcript,
            fillerWordCount: fillerCount,
            duration: duration,
            date: date,
            mode: mode,
            score: score,
            prompt: prompt,
            pressureLevel: .standard,
            isRated: true
        )
    }
}

/// Regression guard for the latest manual/live transcript the product was
/// tuned against. These are not generic "bad wording" examples; they are the
/// concrete drafts that made Ask Noum feel less than expert-coach level.
@Suite("CoachChatLatestLiveEvalRegressionTests")
struct CoachChatLatestLiveEvalRegressionTests {

    @Test func fixtureContextsContainExpectedEvidenceNeedles() throws {
        for fixture in CoachChatEvaluationCorpus.fixtures {
            let context = CoachChatEvaluationCorpus.renderedContext(for: fixture)
            let missing = fixture.expectedContextNeedles.filter {
                !CoachChatEvaluationCorpus.contains(context, $0)
            }

            #expect(missing.isEmpty, "\(fixture.id) missing context needles: \(missing)")
        }
    }

    @Test func ciReportRejectsFixtureWhenExpectedContextEvidenceIsMissing() throws {
        let fixture = try Self.fixture("cold-start-interview-baseline")
        let missingNeedle = "MISSING CONTEXT NEEDLE: impossible evidence anchor"
        let brokenFixture = CoachChatEvaluationFixture(
            id: "\(fixture.id)-missing-context-needle",
            pillar: fixture.pillar,
            expertBaseline: fixture.expertBaseline,
            profile: fixture.profile,
            sessions: fixture.sessions,
            trends: fixture.trends,
            latestUserTurn: fixture.latestUserTurn,
            previousCoachReply: fixture.previousCoachReply,
            expectedContextNeedles: fixture.expectedContextNeedles + [missingNeedle],
            referenceReply: fixture.referenceReply,
            knownBadReply: fixture.knownBadReply,
            expectedBadIssue: fixture.expectedBadIssue
        )

        let report = CoachChatEvaluationCIReport.make(from: [brokenFixture])
        let row = try #require(report.rows.first)

        #expect(row.referenceReplyPassesRubric)
        #expect(row.referenceReplyPassesQualityGate)
        #expect(row.referencePassesVisionFloor)
        #expect(row.referencePassesReliabilityGate)
        #expect(row.contextNeedleCount == fixture.expectedContextNeedles.count + 1)
        #expect(row.contextNeedlesPassed == false)
        #expect(row.missingContextNeedles == [missingNeedle])
        #expect(row.referencePassesProductionFloor == false)
    }

    @Test func latestManualEvalWeakDraftsTripTheProfessionalGate() throws {
        let samples: [(fixtureID: String, reply: String, issue: CoachChatReplyQualityIssue)] = [
            (
                "cold-start-interview-baseline",
                """
                No rated sessions yet, so the honest starting point is: I don't know which part of your delivery needs the most work.
                Run one timed rep — pick a likely interview question, answer it out loud for 60–90 seconds, then note where you hesitated or rushed. That gives us something real to coach from.
                What's the interview for?
                """,
                .roboticPhrase("no rated sessions yet")
            ),
            (
                "filler-pressure-prescription",
                """
                Your last rep had 6 fillers under a timed limit, so the pattern is there when the clock runs.
                To break this, test the silent pause: the moment you feel an um coming, hold one second of silence instead, then say the next word.
                Run one rep now with that silent beat to see if it stops the filler.
                """,
                .roboticPhrase("to break this")
            ),
            (
                "metric-action-without-read",
                "Your last rep had five fillers, so test a slow open on your next run to give yourself room to find the second sentence. Say your first line slower than feels natural, which can replace the early um with a silent beat.",
                .roboticPhrase("give yourself room to find")
            ),
            (
                "metric-action-without-read",
                "Your last rep carried five fillers, which is a solid baseline to test against. Run one rep now where you focus on a slow open: say your first sentence slower than feels natural, then hold a silent beat before sentence two.",
                .missingInsightBridge
            ),
            (
                "critique-trust-repair",
                "You are right to call that out, and I am cutting the robotic report voice. Your last rep had one filler, so record a new rep where you say the main point in your very first sentence and then stop.",
                .roboticPhrase("i am cutting the")
            ),
            (
                "markdown-tts-trust-repair",
                "Fair push. I'll cut the markers and the report voice — your last rep gives me enough to work from, so next time out, lead with your recommendation in the first sentence and stop there.",
                .roboticPhrase("i'll cut the markers")
            ),
            (
                "assistant-explainer-register",
                "You are right to call that out, as that generic tip-giving was cold and did not help. Your last rep had one filler but the main point did not clearly lead, so open your next attempt by saying your core client recommendation in the very first sentence because that tests whether a strong start helps you feel in control.",
                .roboticPhrase("generic tip-giving")
            ),
            (
                "what-next-single-move",
                "Your last rep was clean on fillers but the point arrived late, so state your main takeaway in your very first sentence on the next run. Leading with the conclusion tests whether that immediately gives you more control over the pace.",
                .missingInsightBridge
            ),
            (
                "overclaim-hypothesis-boundary",
                "Your last rep put the recommendation right up front, but you asserted the claim without giving a reason or an implication to back it up. That risks sounding like an opinion rather than an authoritative verdict, so run a rep where you state the point, give one clear reason, and name the impact if we do not act.",
                .overclaimsEvidence
            ),
            (
                "leadership-transfer-setup",
                "Your last rep led with the point cleanly, so test the thirty-second update for tomorrow's meeting. State your main headline and what it means in the first sentence, because a senior room wants the implication immediately.",
                .roboticPhrase("a senior room wants")
            )
        ]

        for sample in samples {
            let fixture = try Self.fixture(sample.fixtureID)
            let context = CoachChatEvaluationCorpus.renderedContext(for: fixture)
            let issue = AICoachChatService.replyQualityIssue(
                in: sample.reply,
                latestUserTurn: fixture.latestUserTurn,
                quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                systemContext: context
            )

            #expect(issue == sample.issue,
                    "\(sample.fixtureID) expected \(sample.issue), got \(String(describing: issue))")
        }
    }

    @Test func latestManualEvalPreferredShapesStayShortAndActionable() throws {
        let samples: [(fixtureID: String, reply: String)] = [
            (
                "cold-start-interview-baseline",
                "No baseline yet, so start there. Record 60 seconds on one likely interview question, then review whether the first sentence answers it before polishing anything."
            ),
            (
                "filler-pressure-prescription",
                "Your last rep had 6 fillers, so hold one silent beat before the final sentence and check whether the next rep lowers the count."
            ),
            (
                "metric-action-without-read",
                "Your last rep had 5 fillers, so hold one silent beat after the decision line and restart if a filler appears."
            ),
            (
                "assistant-explainer-register",
                "Fair push: that was advice, not coaching. Your last rep has the useful signal: warmth came before the recommendation, so next rep say the recommendation first, then soften it with one reassurance."
            ),
            (
                "what-next-single-move",
                "The pattern I'd pick is the rushed close. Review the last transcript, rewrite only the final sentence, then run one rep with that close as the target."
            ),
            (
                "overclaim-hypothesis-boundary",
                "From the transcript, the recommendation arrived late, so say the decision first, add one reason, then name the implication."
            ),
            (
                "leadership-transfer-setup",
                "Your recent timed rep was solid on fillers but light on the close. Record a 75-second leadership update and make the final sentence the ask, not a summary."
            )
        ]

        for sample in samples {
            let fixture = try Self.fixture(sample.fixtureID)
            let context = CoachChatEvaluationCorpus.renderedContext(for: fixture)
            let issue = AICoachChatService.replyQualityIssue(
                in: sample.reply,
                latestUserTurn: fixture.latestUserTurn,
                quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                systemContext: context
            )
            let rubric = AICoachChatService.professionalCoachRubric(
                reply: sample.reply,
                latestUserTurn: fixture.latestUserTurn
            )

            #expect(issue == nil,
                    "\(sample.fixtureID) preferred shape tripped quality gate: \(String(describing: issue))")
            #expect(rubric.passesSeniorCoachFloor,
                    "\(sample.fixtureID) preferred shape should pass. Misses: \(rubric.misses)")
        }
    }

    @Test func fillerRepairShapeUsesDecisionLineWhenTranscriptShowsIt() throws {
        let fixture = try Self.fixture("metric-action-without-read")
        let shape = try #require(AICoachChatService.repairReferenceShape(
            issue: .missingInsightBridge,
            latestUserTurn: fixture.latestUserTurn,
            system: CoachChatEvaluationCorpus.renderedContext(for: fixture)
        ))

        #expect(shape.contains("after the decision line"))
        #expect(shape.contains("restart if a filler appears"))
        #expect(!shape.contains("before sentence two"))
    }

    @Test func trustRepairShapePrefersWarmthSignalOverFillerCount() throws {
        let fixture = try Self.fixture("assistant-explainer-register")
        let shape = try #require(AICoachChatService.repairReferenceShape(
            issue: .missedTrustRepair,
            latestUserTurn: fixture.latestUserTurn,
            system: CoachChatEvaluationCorpus.renderedContext(for: fixture)
        ))

        #expect(shape.contains("warmth came before the recommendation"))
        #expect(shape.contains("say the recommendation first"))
        #expect(!shape.contains("1 filler"))
    }

    @Test func genericAdviceScoresNearTheReviewCritique() throws {
        let fixture = try Self.fixture("cold-start-interview-baseline")
        let reply = "Keep practicing and try to sound more confident."

        let vision = AICoachChatService.coachVisionEvaluation(
            reply: reply,
            latestUserTurn: fixture.latestUserTurn,
            quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
            systemContext: CoachChatEvaluationCorpus.renderedContext(for: fixture)
        )
        let issue = AICoachChatService.replyQualityIssue(
            in: reply,
            latestUserTurn: fixture.latestUserTurn,
            quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
            systemContext: CoachChatEvaluationCorpus.renderedContext(for: fixture)
        )

        #expect(vision.score <= 30)
        #expect(vision.criticalMisses.contains(.directAnswer))
        #expect(vision.criticalMisses.contains(.observableAnchor))
        #expect(vision.criticalMisses.contains(.prescribedAction))
        #expect(issue != nil)
    }

    @Test func coachTurnMetadataPersistsVisionDiagnostics() throws {
        let metadata = CoachTurnMetadata(
            providerTier: .claudeReasoning,
            providerTierChosen: .claudeReasoning,
            semanticGateIssue: "trustRepairMissed",
            visionScore: 32,
            visionCriticalMisses: [.directAnswer, .observableAnchor],
            visionPassesProductionFloor: false,
            qualityGateOutcome: .repaired("vision:32:directAnswer,observableAnchor"),
            qualityGateFailureCount: 1,
            qualityGateRepairCount: 1,
            assessmentCacheHit: true,
            assessmentCacheAgeMs: 240,
            immediateCoachReadShown: true,
            replyWordCount: 38,
            providerRetryCount: 1,
            providerAttemptCount: 2,
            providerRefusalCount: 1,
            ttftMs: 180,
            fullLatencyMs: 940,
            timeToFirstVisibleTokenMs: 180,
            timeToCompleteReplyMs: 940,
            userPushbackWithinTwoTurns: true,
            coldnessComplaintFlag: true,
            softPushbackFlag: true,
            voiceBargeInOccurred: true
        )

        let encoded = try JSONEncoder().encode(metadata)
        let decoded = try JSONDecoder().decode(CoachTurnMetadata.self, from: encoded)

        #expect(decoded.providerTier == .claudeReasoning)
        #expect(decoded.providerTierChosen == .claudeReasoning)
        #expect(decoded.visionScore == 32)
        #expect(decoded.visionCriticalMisses == [.directAnswer, .observableAnchor])
        #expect(decoded.visionPassesProductionFloor == false)
        #expect(decoded.semanticGateIssue == "trustRepairMissed")
        #expect(decoded.qualityGateOutcome == .repaired("vision:32:directAnswer,observableAnchor"))
        #expect(decoded.qualityGateFailureCount == 1)
        #expect(decoded.qualityGateRepairCount == 1)
        #expect(decoded.assessmentCacheHit == true)
        #expect(decoded.assessmentCacheAgeMs == 240)
        #expect(decoded.immediateCoachReadShown == true)
        #expect(decoded.replyWordCount == 38)
        #expect(decoded.providerRetryCount == 1)
        #expect(decoded.providerAttemptCount == 2)
        #expect(decoded.providerRefusalCount == 1)
        #expect(decoded.timeToFirstVisibleTokenMs == 180)
        #expect(decoded.timeToCompleteReplyMs == 940)
        #expect(decoded.userPushbackWithinTwoTurns == true)
        #expect(decoded.coldnessComplaintFlag == true)
        #expect(decoded.softPushbackFlag == true)
        #expect(decoded.voiceBargeInOccurred == true)
    }

    @Test func qualityGateAggregationKeepsPassedOutcomeAfterRejectedDraft() {
        let events: [CoachTurnQualityGateEvent] = [
            .rejected("vision:28:observableAnchor"),
            .passed
        ]

        #expect(CoachReplyPipeline.qualityGateOutcome(
            for: events,
            outcome: .reply("No baseline yet, so run one 60-second answer and make the first sentence the verdict.")
        ) == .passed)
        #expect(CoachReplyPipeline.qualityGateFailureCount(events) == 1)
        #expect(CoachReplyPipeline.qualityGateRepairCount(events) == 0)
    }

    @Test func qualityGateAggregationReportsRepairShownToUser() {
        let events: [CoachTurnQualityGateEvent] = [
            .rejected("vision:34:prescribedAction"),
            .repaired("vision:72:transferProof")
        ]

        #expect(CoachReplyPipeline.qualityGateOutcome(
            for: events,
            outcome: .reply("Your close is the lever. Do a 75-second update and make the final sentence the ask.")
        ) == .repaired("vision:72:transferProof"))
        #expect(CoachReplyPipeline.qualityGateFailureCount(events) == 1)
        #expect(CoachReplyPipeline.qualityGateRepairCount(events) == 1)
    }

    @Test func qualityGateAggregationPrefersSafeFallbackOverPriorRepair() {
        let events: [CoachTurnQualityGateEvent] = [
            .rejected("vision:31:directAnswer"),
            .repaired("vision:76:bridge"),
            .fallback("safeReference:vision:29:observableAnchor")
        ]

        #expect(CoachReplyPipeline.qualityGateOutcome(
            for: events,
            outcome: .reply("I’m holding off on a broad read. Start with one 60-second rep and we’ll judge the first sentence.")
        ) == .fallback("safeReference:vision:29:observableAnchor"))
        #expect(CoachReplyPipeline.qualityGateFailureCount(events) == 1)
        #expect(CoachReplyPipeline.qualityGateRepairCount(events) == 2)
    }

    @Test func semanticGateIssueSurvivesSuccessfulRepair() {
        let events: [CoachTurnQualityGateEvent] = [
            .rejected("semantic:trustRepairMissed"),
            .repaired("semantic:trustRepairMissed"),
            .passed
        ]

        #expect(CoachReplyPipeline.semanticGateIssue(
            for: .passed,
            qualityGateEvents: events
        ) == "trustRepairMissed")
    }

    @Test func semanticGateIssuePrefersFinalFailedOutcome() {
        #expect(CoachReplyPipeline.semanticGateIssue(
            for: .failed("unsupportedClosenessClaim"),
            qualityGateEvents: [.repaired("semantic:trustRepairMissed")]
        ) == "unsupportedClosenessClaim")
    }

    @Test func providerAttemptAggregationSeparatesRetriesFromQualityFailures() {
        let first = CoachTurnProviderChoice(providerName: "Gemini", model: "gemini-2.5-flash")
        let second = CoachTurnProviderChoice(providerName: "Claude", model: "claude-sonnet-4-6")
        let events: [CoachProviderAttemptEvent] = [
            .started(first),
            .retry(first),
            .refused(first),
            .started(second)
        ]

        #expect(CoachReplyPipeline.providerAttemptCount(events) == 2)
        #expect(CoachReplyPipeline.providerRefusalCount(events) == 1)
        #expect(CoachReplyPipeline.providerRetryCount(events) == 2)
    }

    @Test func providerTierChosenClassifiesKnownRoutingFamilies() {
        #expect(CoachReplyPipeline.providerTierChosen(
            for: CoachTurnProviderChoice(providerName: "Claude", model: "claude-sonnet-4-6"),
            requestedTier: .geminiFast
        ) == .claudeReasoning)
        #expect(CoachReplyPipeline.providerTierChosen(
            for: CoachTurnProviderChoice(providerName: "Google Cloud", model: "gemini-3.5-flash"),
            requestedTier: .claudeReasoning
        ) == .geminiFast)
        #expect(CoachReplyPipeline.providerTierChosen(
            for: CoachTurnProviderChoice(providerName: "Typed judgement fallback", model: "CoachAssessment"),
            requestedTier: .claudeReasoning
        ) == .claudeReasoning)
        #expect(CoachReplyPipeline.providerTierChosen(
            for: CoachTurnProviderChoice(providerName: "OpenAI", model: "gpt-test"),
            requestedTier: .claudeReasoning
        ) == nil)
    }

    @Test func qualityGateAggregationPreservesFinalFailureReason() {
        let events: [CoachTurnQualityGateEvent] = [
            .rejected("vision:24:evidenceHonesty"),
            .failed("providerRefused")
        ]

        #expect(CoachReplyPipeline.qualityGateOutcome(
            for: events,
            outcome: .failure(.contentRejected)
        ) == .failed("providerRefused"))
        #expect(CoachReplyPipeline.qualityGateFailureCount(events) == 2)
        #expect(CoachReplyPipeline.qualityGateRepairCount(events) == 0)
    }

    @Test func broadStructureAdviceTripsQualityAndVisionGatesDespiteLexicalShape() throws {
        let fixture = try Self.fixture("cold-start-interview-baseline")
        let reply = "No baseline yet, so focus on structure and clarity before the interview."

        #expect(AICoachChatService.replyQualityIssue(
            in: reply,
            latestUserTurn: fixture.latestUserTurn,
            quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
            systemContext: CoachChatEvaluationCorpus.renderedContext(for: fixture)
        ) == .ignoredCoachingExpertise)

        let issue = try #require(AICoachChatService.visionQualityIssue(
            in: reply,
            latestUserTurn: fixture.latestUserTurn,
            quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
            systemContext: CoachChatEvaluationCorpus.renderedContext(for: fixture)
        ))

        if case .visionGate(let score, let misses) = issue {
            #expect(score < 85)
            #expect(misses.contains(.prescribedAction))
        } else {
            Issue.record("Expected vision gate issue, got \(issue)")
        }
    }

    @Test func specificColdStartMoveClearsVisionRuntimeGate() throws {
        let fixture = try Self.fixture("cold-start-interview-baseline")
        let reply = fixture.referenceReply

        #expect(AICoachChatService.visionQualityIssue(
            in: reply,
            latestUserTurn: fixture.latestUserTurn,
            quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
            systemContext: CoachChatEvaluationCorpus.renderedContext(for: fixture)
        ) == nil)
    }

    @Test func socialAcknowledgementDoesNotTripVisionRuntimeGate() {
        #expect(AICoachChatService.visionQualityIssue(
            in: "Anytime.",
            latestUserTurn: "Thanks, that helps."
        ) == nil)
    }

    @Test func latestManualEvalReferenceShapesEarnVisionScore() throws {
        for id in CoachChatEvaluationCorpus.latestManualEvalFixtureIDs.prefix(10) {
            let fixture = try Self.fixture(id)
            let context = CoachChatEvaluationCorpus.renderedContext(for: fixture)
            let vision = AICoachChatService.coachVisionEvaluation(
                reply: fixture.referenceReply,
                latestUserTurn: fixture.latestUserTurn,
                quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                systemContext: context
            )

            #expect(vision.score >= 70,
                    "\(id) reference reply scored too low: \(vision.score), missed \(vision.missed)")
            #expect(!vision.criticalMisses.contains(.observableAnchor),
                    "\(id) reference reply lost its grounding anchor")
            #expect(!vision.criticalMisses.contains(.prescribedAction),
                    "\(id) reference reply lost its next move")
        }
    }

    @Test func latestManualEvalKnownBadShapesScoreHarshly() throws {
        for id in CoachChatEvaluationCorpus.latestManualEvalFixtureIDs.prefix(10) {
            let fixture = try Self.fixture(id)
            let context = CoachChatEvaluationCorpus.renderedContext(for: fixture)
            let vision = AICoachChatService.coachVisionEvaluation(
                reply: fixture.knownBadReply,
                latestUserTurn: fixture.latestUserTurn,
                quoteGuard: CoachChatEvaluationCorpus.quoteGuard(for: fixture),
                systemContext: context
            )

            #expect(vision.score <= 78,
                    "\(id) known-bad reply scored too high: \(vision.score), earned \(vision.earned)")
            #expect(!vision.passesProductionFloor)
        }
    }

    private static func fixture(_ id: String) throws -> CoachChatEvaluationFixture {
        try #require(CoachChatEvaluationCorpus.fixtures.first { $0.id == id })
    }
}
