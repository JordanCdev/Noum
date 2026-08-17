import Foundation
import Testing
@testable import Noum

@Suite("V3 practice and result loop")
struct V3PracticeResultLoopTests {
    @Test("Live focus keeps exactly one intervention")
    func liveFocusPrecedenceIsStable() {
        #expect(
            TimedLiveRepFocus.target(
                retryFocus: "Lead with the recommendation.",
                drillConstraint: "Remove every filler.",
                styleGoal: .warm,
                pressureEnabled: true
            ) == "Lead with the recommendation."
        )
        #expect(
            TimedLiveRepFocus.target(
                retryFocus: nil,
                drillConstraint: "Use one signpost.",
                styleGoal: .concise,
                pressureEnabled: true
            ) == "Use one signpost."
        )
    }

    @Test("Every voice fallback is observable and bounded")
    func voiceTargetsRemainBiteSized() {
        for goal in SpeakingStyleGoal.allCases {
            let target = TimedLiveRepFocus.target(
                retryFocus: nil,
                drillConstraint: nil,
                styleGoal: goal,
                pressureEnabled: false
            )
            #expect(!target.isEmpty)
            #expect(target.count <= 90)
            #expect(target.components(separatedBy: ".").count <= 4)
        }
    }

    @Test("Gold reward requires the exact qualified session")
    func rewardQualificationFailsClosed() {
        let finalized = UUID()
        let other = UUID()

        #expect(SummaryRewardQualification.earnedXP(
            finalizedSessionID: finalized,
            resolvedSessionID: finalized,
            isProgressEligible: true,
            xpEarned: 25
        ) == 25)
        #expect(SummaryRewardQualification.earnedXP(
            finalizedSessionID: finalized,
            resolvedSessionID: other,
            isProgressEligible: true,
            xpEarned: 25
        ) == 0)
        #expect(SummaryRewardQualification.earnedXP(
            finalizedSessionID: nil,
            resolvedSessionID: finalized,
            isProgressEligible: true,
            xpEarned: 25
        ) == 0)
        #expect(SummaryRewardQualification.earnedXP(
            finalizedSessionID: finalized,
            resolvedSessionID: finalized,
            isProgressEligible: false,
            xpEarned: 25
        ) == 0)
        #expect(SummaryRewardQualification.earnedXP(
            finalizedSessionID: finalized,
            resolvedSessionID: finalized,
            isProgressEligible: true,
            xpEarned: 0
        ) == 0)
    }

    @Test("Summary chooses one focused stage with pressure taking precedence")
    func summaryFocusedStageIsDeterministic() {
        #expect(SummaryFocusedActionStage.resolve(
            isPressureRun: true,
            transcriptUpgradeOwnsNextAction: true
        ) == .pressureReceipt)
        #expect(SummaryFocusedActionStage.resolve(
            isPressureRun: false,
            transcriptUpgradeOwnsNextAction: true
        ) == .transcriptUpgrade)
        #expect(SummaryFocusedActionStage.resolve(
            isPressureRun: false,
            transcriptUpgradeOwnsNextAction: false
        ) == .prescription)
    }

    @Test("Timed capture never celebrates a score by itself")
    func timedCaptureContainsNoScoreConfetti() throws {
        let source = try repositorySource("TimedPracticeView.swift")
        #expect(!source.contains("showCelebration"))
        #expect(!source.contains("ConfettiLayer("))
        #expect(!source.contains("if result.score >= 70"))
        #expect(!source.contains("NoumCharacter("))
        #expect(source.contains("RecordingCompletionGate.allowsScoringAndProgress"))
        #expect(source.contains("level: CGFloat(min(max(audioLevel, 0), 1))"))
        #expect(source.contains("Live microphone waveform"))
    }

    @Test("Earned retry uses shared adaptive primitives")
    func earnedRetryUsesFoundationAndSupportsDarkMode() throws {
        let source = try repositorySource("TranscriptPracticeLoop.swift")
        let milestone = try #require(sourceSlice(
            source,
            from: "struct TranscriptRetryMilestoneView: View",
            through: "private enum RetryRewardWaveformPhase"
        ))

        #expect(milestone.contains("NoumWaveformMark(state: .earned"))
        #expect(milestone.contains("NoumRewardPill("))
        #expect(milestone.contains("NoumEvidenceCard("))
        #expect(!milestone.contains(".preferredColorScheme(.light)"))
        #expect(!milestone.contains("repeatForever"))
    }

    private func repositorySource(_ filename: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: root.appendingPathComponent("Noum").appendingPathComponent(filename),
            encoding: .utf8
        )
    }

    private func sourceSlice(
        _ source: String,
        from startMarker: String,
        through endMarker: String
    ) -> String? {
        guard let start = source.range(of: startMarker),
              let end = source.range(
                of: endMarker,
                range: start.lowerBound..<source.endIndex
              ) else {
            return nil
        }
        return String(source[start.lowerBound..<end.upperBound])
    }
}
