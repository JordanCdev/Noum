import Foundation
import Testing
@testable import Noum

@Suite("Summary evidence-first composition")
struct SummaryEvidenceFirstCompositionTests {
    private var summarySource: String {
        get throws {
            let repositoryRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            return try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("Noum")
                    .appendingPathComponent("SummaryView.swift"),
                encoding: .utf8
            )
        }
    }

    @Test func timedSummaryLeadsWithEvidenceThenThePrescribedRetry() throws {
        let source = try summarySource
        let branch = try #require(
            slice(
                source,
                from: "// TIMED / AH-COUNTER / SUDDEN DEATH all spend the",
                through: "SummaryExitPanel(onDone: completeSummaryReview)"
            )
        )

        try expectOrdered(
            [
                "PostRepDebriefCard(",
                "transcriptRetryComparisonSection",
                "rewriteSection",
                "if !transcriptUpgradeOwnsNextAction",
                "reviewExperimentActionCard",
                "postRepProgressReceipt",
                "TalkToNoumCTACard(",
                "expandableDetailsSection",
                "SummaryExitPanel(onDone: completeSummaryReview)",
            ],
            in: branch
        )
        #expect(!branch.contains("HeroScoreCard("))
    }

    @Test func imSummaryUsesTheSameActionFirstHierarchyWithoutInventingProof() throws {
        let source = try summarySource
        let branch = try #require(
            slice(
                source,
                from: "// IM has no verified ProofMoment surface",
                through: "SummaryExitPanel(onDone: completeSummaryReview)"
            )
        )

        try expectOrdered(
            [
                "IMDebriefCard(",
                "reviewExperimentActionCard",
                "transcriptRetryComparisonSection",
                "rewriteSection",
                "postRepProgressReceipt",
                "expandableDetailsSection",
            ],
            in: branch
        )
        #expect(!branch.contains("IMVerdictCard("))
    }

    @Test func scoreAndModeReceiptsAreDemotedWithoutBeingDeleted() throws {
        let source = try summarySource
        let details = try #require(
            slice(
                source,
                from: "private var expandableDetailsSection: some View",
                through: "private var fullCoachReadDetail: some View"
            )
        )

        #expect(details.contains("if !isSuddenDeathSummary"))
        #expect(details.contains("resultOverviewCard"))
        #expect(source.contains("HeroScoreCard("))
        #expect(source.contains("IMVerdictCard("))
        #expect(source.contains("SuddenDeathReviewCard("))
    }

    @Test func visibleDoneUsesTheExistingExitBoundary() throws {
        let source = try summarySource

        #expect(source.contains("ToolbarItem(placement: .topBarTrailing)"))
        #expect(source.contains("Button(CohesiveSummaryCopy.done)"))
        #expect(source.contains(".accessibilityIdentifier(\"summary.toolbar.done\")"))
        #expect(source.contains(".accessibilityAction(named: Text(\"Done\"))"))
        #expect(source.components(separatedBy: "completeSummaryReview()").count - 1 >= 2)
    }

    @Test func rewriteReusesTheExactSessionsSavedSnapshot() throws {
        let source = try summarySource
        #expect(
            source.contains(
                "savedSnapshot: currentStoredSession?.transcriptRewriteSnapshot"
            )
        )
    }

    @Test func transcriptUpgradeOwnsOneImmediateLeverAndReusesTheSourcePrompt() throws {
        let source = try summarySource

        #expect(source.contains("suppressesNextMove: transcriptUpgradeOwnsNextAction"))
        #expect(source.contains("if !transcriptUpgradeOwnsNextAction"))
        #expect(source.contains("sourcePrompt: sessionPrompt ?? currentStoredSession?.prompt"))
        #expect(source.contains("transcriptUpgradeState != .unavailable"))
        #expect(source.contains("observationOverride: transcriptUpgradeObservation"))
        #expect(source.contains("The opening uses a tentative marker before the recommendation."))
    }

    @Test func verifiedEvidenceCarriesSourceProvenanceAndCanYieldToOneUpgrade() {
        let proof = ProofMoment(
            quote: "We should decide the owner today.",
            technique: "Direct opening",
            claim: "You led with the decision.",
            sessionDate: Date(),
            isAIBacked: false,
            generatedAt: Date()
        )
        let content = PostRepVerdictContent.make(
            note: nil,
            coachNote: CoachNote(momentum: "", leverage: "", nextStep: "Add one proof point."),
            winBullets: [],
            fixBullets: [],
            proof: proof,
            isMinimalEffort: false,
            sourceDuration: 18
        )

        #expect(content.provenanceLabel == "Source: original transcript · 0:18")
        #expect(
            PostRepDebriefVisibility.resolve(
                content: content,
                suppressesNextMove: true
            ).showsNextMove == false
        )
    }

    private func slice(
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

    private func expectOrdered(_ tokens: [String], in source: String) throws {
        var lowerBound = source.startIndex
        for token in tokens {
            let range = try #require(
                source.range(of: token, range: lowerBound..<source.endIndex),
                "Missing or out-of-order Summary section: \(token)"
            )
            lowerBound = range.upperBound
        }
    }
}
