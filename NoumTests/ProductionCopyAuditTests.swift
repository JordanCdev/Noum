import Foundation
import Testing
@testable import Noum

@Suite("Production copy audit regressions")
struct ProductionCopyAuditRegressionTests {

    @MainActor
    @Test func unavailableServicesDoNotExposeConfigurationWork() {
        let lines = [
            IMModeServiceError.unavailable.errorDescription,
            IMModeServiceError.replyGenerationFailed("provider timeout").errorDescription,
            IMModeServiceError.evaluationFailed("invalid JSON").errorDescription,
            VideoAnalysisError.releaseUnavailable.errorDescription,
            VideoAnalysisError.premiumRequired.errorDescription,
            VideoAnalysisError.providerNotVisionCapable.errorDescription,
            VideoAnalysisError.invalidProviderRead.errorDescription,
            AICoachError.providerDisabled.errorDescription,
            AICoachError.missingAPIKey.errorDescription,
            AICoachError.invalidResponse.errorDescription,
            AICoachError.apiFailure("raw provider failure").errorDescription,
            AuthManager.missingCredentialsMessage,
        ].compactMap { $0 }

        let banned = [
            "provider", "backend", "api key", "configure", "settings",
            "xcode", "firebase", "credential", "invalid json", "raw provider"
        ]

        for line in lines {
            let lowered = line.lowercased()
            #expect(!banned.contains(where: lowered.contains), "User-facing error leaked setup detail: \(line)")
            #expect(!line.contains("!"))
        }
    }

    @Test func thinTrendEvidenceUsesTentativeLanguage() throws {
        let newIssue = SkillTrend(
            skillArea: .structure,
            direction: .newIssue,
            confidence: .low,
            windowSize: 1,
            currentLevel: .weak
        )
        let declining = SkillTrend(
            skillArea: .paceControl,
            direction: .declining,
            confidence: .low,
            windowSize: 2,
            currentLevel: .developing
        )

        let newIssueLine = try #require(TrendAnalyzer.trendContext(
            for: .structure,
            trends: [newIssue]
        ))
        let decliningLine = try #require(TrendAnalyzer.trendContext(
            for: .paceControl,
            trends: [declining]
        ))

        #expect(newIssueLine.contains("Another rep will show whether it repeats"))
        #expect(decliningLine.contains("too early to call a pattern"))

        let joined = "\(newIssueLine) \(decliningLine)".lowercased()
        let banned = ["slipped", "hasn't been a problem", "stops being an issue", "immediately"]
        #expect(!banned.contains(where: joined.contains))
    }

    @Test func reviewNewIssueCopyRequestsConfirmationInsteadOfDeclaringDecline() {
        let line = ReviewCoachRead.focusLine(for: SkillTrend(
            skillArea: .openingStrength,
            direction: .newIssue,
            confidence: .medium,
            windowSize: 4,
            currentLevel: .developing
        ))

        #expect(line.contains("confirming rep"))
        #expect(!line.lowercased().contains("slipping"))
        #expect(!line.lowercased().contains("catch it"))
    }

    @Test func practiceActionsReadAsActionsWithoutSeparatorFragments() {
        let primary = PracticeModePrescriptionCopy.beginLabel(for: "Timed Practice")
        let target = PracticeModePrescriptionCopy.prescriptionLine(
            focus: "Longer answer",
            target: "30s+"
        )

        #expect(primary == "Start Timed Practice")
        #expect(!primary.contains("·"))
        #expect(target == "30s+")
        #expect(target?.contains("·") == false)
    }

    @Test func conversationModeDoesNotExposeInternalInitials() {
        #expect(PracticeMode.imConversation.displayLabel == "Conversation Practice")
        #expect(SessionHistoryListModel.modeLabel(for: .imConversation) == "Conversation Practice")
        #expect(!PracticeMode.imConversation.displayLabel.contains("IM"))
    }

    @Test func conversationExportDoesNotDependOnInternalModeInitials() {
        let export = IMHistoryExport.formatPlainText(sessions: [])

        #expect(export.contains("Conversation Practice history"))
        #expect(!export.contains("IM history"))
        #expect(!export.contains("·"))
    }

    @Test func severeEvidenceNamesAConstraintWithoutUrgency() {
        let input = NextActionInput(
            fillerCount: 12,
            duration: 45,
            wordCount: 120,
            wpm: 160,
            score: 4,
            categoryRatings: ["Opening": "OK", "Structure": "Could improve"],
            mode: .timed,
            pressureLevel: .standard,
            baseline: .empty,
            pressureProfile: .empty,
            trends: [],
            drillHistory: [],
            sessionCount: 1,
            streakDays: 0,
            styleGoal: nil
        )

        let line = NextActionEngine.recommend(input: input).reasoning
        #expect(line.contains("clear constraint"))
        #expect(!line.lowercased().contains("immediately"))
        #expect(!line.contains("!"))
    }

    @Test func deepAssessmentCopyUsesNaturalValidationLanguage() {
        let assessment = CoachAssessment(
            turnDepth: .deepAssessment,
            surface: .text,
            questionRestatement: "How close am I to sounding authoritative?",
            directVerdict: "One answer is not enough to call the voice consistently authoritative.",
            confidence: 0.56,
            evidenceUsed: ["latest rep: the recommendation arrived in sentence one"],
            rubricScores: [],
            missingEvidence: ["repeated answers under pressure"],
            nextProofTest: "Record one answer with the recommendation first and a clean stop.",
            responseMode: .expandable
        )

        let productionLines = [assessment.immediateCoachRead]
            + CoachPromptBundle.instructionLines(for: .deepAssessment, surface: .text)
            + [
                CoachSemanticQualityIssue.missingMechanicsGoalDistinction.repairInstruction,
                CoachSemanticQualityIssue.missingRepairInsight.repairInstruction,
                CoachSemanticQualityIssue.missingProofTest.repairInstruction,
            ]
        let banned = [
            "goal readiness",
            "cleaner mechanics",
            "highest-leverage mechanics",
            "proof test",
        ]

        for line in productionLines {
            let lowered = line.lowercased()
            #expect(!banned.contains(where: lowered.contains), "Internal coaching jargon leaked into production language: \(line)")
        }
        #expect(assessment.immediateCoachRead.contains("For the next check"))
    }
}
