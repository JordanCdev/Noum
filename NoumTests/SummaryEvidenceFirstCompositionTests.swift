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

    private var summaryCardsSource: String {
        get throws {
            let repositoryRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            return try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("Noum")
                    .appendingPathComponent("SummaryCards.swift"),
                encoding: .utf8
            )
        }
    }

    @Test func collapsedSummaryUsesFourPerceptualStages() throws {
        let source = try summarySource
        let collapsed = try #require(
            slice(
                source,
                from: "ScrollView(showsIndicators: false) {",
                through: "// END V3 ATTENTION BUDGET"
            )
        )

        try expectOrdered(
            [
                "SummaryCompletionHeader(",
                "if isIMSummary",
                "IMDebriefCard(",
                "PostRepDebriefCard(",
                "focusedSummaryActionStage",
                "expandableDetailsSection",
                "SummaryExitPanel(onDone: completeSummaryReview)",
            ],
            in: collapsed
        )

        for secondary in [
            "transcriptRetryComparisonSection",
            "rewriteSection",
            "reviewExperimentActionCard",
            "postRepProgressReceipt",
            "resultOverviewCard",
        ] {
            #expect(!collapsed.contains(secondary))
        }
        #expect(collapsed.contains(".cardEntrance(1)"))
        #expect(collapsed.contains(".cardEntrance(2)"))
        #expect(collapsed.components(separatedBy: ".cardEntrance(3)").count - 1 == 1)
    }

    @Test func secondaryAnalysisIsContainedBehindTheExistingDisclosure() throws {
        let source = try summarySource
        let details = try #require(
            slice(
                source,
                from: "private var expandableDetailsSection: some View",
                through: "private var fullCoachReadDetail: some View"
            )
        )

        try expectOrdered(
            [
                "if showSecondaryDetails",
                "resultOverviewCard",
                "transcriptRetryComparisonSection",
                "deferredInterventionReviewCard",
                "if focusedActionStage != .transcriptUpgrade",
                "rewriteSection",
                "if focusedActionStage != .prescription",
                "reviewExperimentActionCard",
                "postRepProgressReceipt",
            ],
            in: details
        )
        #expect(details.contains("if !isSuddenDeathSummary"))
        #expect(source.contains("HeroScoreCard("))
        #expect(source.contains("IMVerdictCard("))
        #expect(source.contains("SuddenDeathReviewCard("))
    }

    @Test func focusedSlotRendersExactlyOneApplicableSurface() throws {
        let source = try summarySource
        let focused = try #require(
            slice(
                source,
                from: "private var focusedSummaryActionStage: some View",
                through: "private func recordSummaryViewedIfNeeded()"
            )
        )

        try expectOrdered(
            [
                "case .pressureReceipt:",
                "resultOverviewCard",
                "case .transcriptUpgrade:",
                "rewriteSection",
                "case .prescription:",
                "reviewExperimentActionCard",
            ],
            in: focused
        )
        #expect(focused.components(separatedBy: "resultOverviewCard").count - 1 == 1)
        #expect(focused.components(separatedBy: "rewriteSection").count - 1 == 1)
        #expect(focused.components(separatedBy: "reviewExperimentActionCard").count - 1 == 1)
    }

    @Test func askNoumIsDepthNotACompetingPrimaryAction() throws {
        let source = try summarySource
        let collapsed = try #require(
            slice(
                source,
                from: "ScrollView(showsIndicators: false) {",
                through: "// END V3 ATTENTION BUDGET"
            )
        )
        let details = try #require(
            slice(
                source,
                from: "private var expandableDetailsSection: some View",
                through: "private var fullCoachReadDetail: some View"
            )
        )

        #expect(!collapsed.contains("TalkToNoumCTACard("))
        #expect(details.contains("TalkToNoumCTACard("))
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
        let cards = try summaryCardsSource
        let collapsed = try #require(
            slice(
                source,
                from: "if isIMSummary",
                through: "focusedSummaryActionStage"
            )
        )

        #expect(
            collapsed.components(
                separatedBy: "suppressesNextMove: focusedActionStage == .transcriptUpgrade"
            ).count - 1 == 2
        )
        #expect(cards.contains("var suppressesNextMove: Bool = false"))
        #expect(cards.contains("if !suppressesNextMove"))
        #expect(source.contains("case .transcriptUpgrade:"))
        #expect(source.contains("if focusedActionStage != .transcriptUpgrade"))
        #expect(source.contains("sourcePrompt: sessionPrompt ?? currentStoredSession?.prompt"))
        #expect(source.contains("transcriptUpgradeState != .unavailable"))
        #expect(source.contains("? transcriptUpgradeObservation"))
        #expect(source.contains("The opening uses a tentative marker before the recommendation."))
    }

    @Test func dueInterventionReviewDefersToDetailsDuringTranscriptRecovery() throws {
        let source = try summarySource
        let collapsed = try #require(
            slice(
                source,
                from: "ScrollView(showsIndicators: false) {",
                through: "// END V3 ATTENTION BUDGET"
            )
        )
        let details = try #require(
            slice(
                source,
                from: "private var expandableDetailsSection: some View",
                through: "private var fullCoachReadDetail: some View"
            )
        )
        let deferredReview = try #require(
            slice(
                source,
                from: "private var deferredInterventionReviewCard: some View",
                through: "// MARK: - Revised-read card"
            )
        )

        #expect(!collapsed.contains("InterventionReviewPromptCard(intervention:"))
        #expect(details.contains("deferredInterventionReviewCard"))
        #expect(deferredReview.contains("focusedActionStage == .transcriptUpgrade"))
        #expect(deferredReview.contains("let intervention = activeReviewDueIntervention"))
        #expect(deferredReview.contains("let onAskNoumAboutRep"))
        #expect(deferredReview.contains("InterventionReviewPromptCard(intervention: intervention)"))
        #expect(deferredReview.contains("interventionReviewOpener(for: intervention)"))
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
