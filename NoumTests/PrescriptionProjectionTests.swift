import Foundation
import Testing
@testable import Noum

@Suite("Summary prescription projection")
struct PrescriptionProjectionTests {
    @Test func drillActionUsesTheFinalizedDrillAndKeepsMiniSemantics() {
        let finalized = drill(id: "final.mini", title: "Land the pause", format: .miniDrill)
        let fallback = drill(id: "fallback.full", title: "Fallback retry", format: .fullRetry)
        let action = nextAction(
            .drill(finalized),
            reasoning: "Your pauses tightened across the recent window.",
            confidence: .moderate
        )

        let projection = SummaryPrescriptionProjection.resolve(
            nextAction: action,
            fallbackDrill: fallback
        )

        #expect(projection.source == .finalizedNextAction)
        #expect(projection.title == "Land the pause")
        #expect(projection.reason == finalized.reason)
        #expect(projection.evidence == "Your pauses tightened across the recent window.")
        #expect(projection.confidenceLabel == BaselineConfidence.moderate.label)
        #expect(projection.destination(imAvailable: true) == nil)
        guard case .drill(let projected) = projection.kind else {
            Issue.record("Expected a drill projection")
            return
        }
        #expect(projected.variation.id == finalized.variation.id)
        #expect(projected.format == .miniDrill)
    }

    @Test func confidenceRebuildingUsesTheSameExistingDrillRendererContract() {
        let finalized = drill(id: "confidence.full", title: "Rebuild the opening", format: .fullRetry)
        let projection = SummaryPrescriptionProjection.resolve(
            nextAction: nextAction(
                .confidenceRebuilding(finalized),
                reasoning: "This pattern has repeated across enough reps to warrant a reset.",
                confidence: .established
            ),
            fallbackDrill: drill(id: "fallback", title: "Fallback", format: .miniDrill)
        )

        guard case .drill(let projected) = projection.kind else {
            Issue.record("Expected confidence rebuilding to remain a drill")
            return
        }
        #expect(projected.variation.id == finalized.variation.id)
        #expect(projected.format == .fullRetry)
        #expect(projection.confidenceLabel == BaselineConfidence.established.label)
    }

    @Test func practiceModeProjectsToOneFullRep() {
        assertFullRep(
            action: .practiceMode(.ahCounter, reason: "Use a live filler read on the next rep."),
            expectedMode: .ahCounter,
            expectedTitle: PracticeMode.ahCounter.displayLabel
        )
    }

    @Test func pressureExposureProjectsToOneFullRep() {
        assertFullRep(
            action: .pressureExposure(.suddenDeath, reason: "Test the same control under pressure."),
            expectedMode: .suddenDeath,
            expectedTitle: "\(PracticeMode.suddenDeath.displayLabel) · Pressure"
        )
    }

    @Test func lockedPressureExposureProjectsCoherentlyToTimedPractice() {
        let projection = SummaryPrescriptionProjection.resolve(
            nextAction: nextAction(
                .pressureExposure(
                    .suddenDeath,
                    reason: "Test the same control under pressure."
                ),
                reasoning: "Your casual reps read stronger than your pressure reps.",
                confidence: .moderate
            ),
            fallbackDrill: drill(id: "fallback", title: "Fallback", format: .miniDrill),
            modeAvailability: NextActionModeAvailability(rating: .initial)
        )

        #expect(projection.source == .finalizedNextAction)
        #expect(projection.fullRepMode == .timed)
        #expect(projection.title == PracticeMode.timed.displayLabel)
        #expect(projection.reason == NextActionModeAvailability.suddenDeathFallbackReason)
        #expect(projection.evidence == nil)
        #expect(projection.confidenceLabel == nil)
        #expect(projection.destination(imAvailable: true) == .timedPractice(difficulty: nil))
    }

    @Test func stabilizingRepProjectsToOneFullRep() {
        assertFullRep(
            action: .stabilizingRep(.timed, reason: "Run one comparable rep to see whether the gain holds."),
            expectedMode: .timed,
            expectedTitle: "\(PracticeMode.timed.displayLabel) · Steady the gain"
        )
    }

    @Test func nilNextActionUsesOnlyTheProvidedDrillFallback() {
        let fallback = drill(
            id: "fallback.mini",
            title: "Commit to one full answer",
            format: .miniDrill,
            trendContext: "One more rep will establish a usable comparison."
        )

        let projection = SummaryPrescriptionProjection.resolve(
            nextAction: nil,
            fallbackDrill: fallback
        )

        #expect(projection.source == .drillFallback)
        #expect(projection.title == fallback.title)
        #expect(projection.reason == fallback.reason)
        #expect(projection.evidence == fallback.trendContext)
        #expect(projection.confidenceLabel == nil)
        guard case .drill(let projected) = projection.kind else {
            Issue.record("Expected the nil path to use the caller's fallback drill")
            return
        }
        #expect(projected.variation.id == fallback.variation.id)
    }

    @Test func unavailableImProjectionFallsBackBeforeRenderAndDropsStaleSetupAndEvidence() {
        let projection = SummaryPrescriptionProjection.resolve(
            nextAction: nextAction(
                .practiceMode(.imConversation, reason: "Test this tone in a live exchange."),
                reasoning: "The next useful demand is relational rather than scripted.",
                confidence: .moderate
            ),
            fallbackDrill: drill(id: "fallback", title: "Fallback", format: .miniDrill),
            existingScenario: .difficultConversation,
            existingTone: .calm,
            modeAvailability: NextActionModeAvailability(
                suddenDeathAvailable: true,
                imConversationAvailable: false
            )
        )

        #expect(projection.fullRepMode == .timed)
        #expect(projection.title == PracticeMode.timed.displayLabel)
        #expect(projection.reason == NextActionModeAvailability.imConversationFallbackReason)
        #expect(projection.evidence == nil)
        #expect(projection.confidenceLabel == nil)
        guard case .fullRep(let mode, let scenario, let tone) = projection.kind else {
            Issue.record("Expected a full-rep projection")
            return
        }
        #expect(mode == .timed)
        #expect(scenario == nil)
        #expect(tone == nil)
        // Decision-time unavailability remains authoritative even if the
        // tap-time provider probe later reads available.
        #expect(projection.destination(imAvailable: true) == .timedPractice(difficulty: nil))
    }

    @Test func availableImProjectionPreservesSetupButRechecksAvailabilityAtTap() {
        let projection = SummaryPrescriptionProjection.resolve(
            nextAction: nextAction(
                .practiceMode(.imConversation, reason: "Test this tone in a live exchange."),
                reasoning: "The next useful demand is relational rather than scripted.",
                confidence: .moderate
            ),
            fallbackDrill: drill(id: "fallback", title: "Fallback", format: .miniDrill),
            existingScenario: .difficultConversation,
            existingTone: .calm,
            modeAvailability: .allAvailable
        )

        #expect(projection.destination(imAvailable: true) == .imPractice(
            scenario: .difficultConversation,
            tone: .calm
        ))
        #expect(projection.destination(imAvailable: false) == .timedPractice(difficulty: nil))
        let fallbackLaunch = projection.launch(imAvailable: false)
        #expect(fallbackLaunch?.displayedMode == .imConversation)
        #expect(fallbackLaunch?.launchedMode == .timed)
        #expect(fallbackLaunch?.acceptsDisplayedPrescription == false)
        let acceptedLaunch = projection.launch(imAvailable: true)
        #expect(acceptedLaunch?.launchedMode == .imConversation)
        #expect(acceptedLaunch?.acceptsDisplayedPrescription == true)
    }

    @Test func finalizerResolvedAvailabilityFallbackDoesNotRegainConfidence() {
        let fallbackReason = NextActionModeAvailability.imConversationFallbackReason
        let projection = SummaryPrescriptionProjection.resolve(
            nextAction: nextAction(
                .practiceMode(.timed, reason: fallbackReason),
                reasoning: fallbackReason,
                confidence: .established,
                availabilityFallbackFrom: .imConversation
            ),
            fallbackDrill: drill(id: "fallback", title: "Fallback", format: .miniDrill),
            modeAvailability: .allAvailable
        )

        #expect(projection.fullRepMode == .timed)
        #expect(projection.reason == fallbackReason)
        #expect(projection.evidence == nil)
        #expect(projection.confidenceLabel == nil)
    }

    @Test func imFullRepWithoutExistingSetupRoutesToTheUnprefilledPicker() {
        let projection = SummaryPrescriptionProjection.resolve(
            nextAction: nextAction(
                .stabilizingRep(.imConversation, reason: "Repeat the conversation demand once."),
                reasoning: "The first signal needs one comparable rep.",
                confidence: .tentative
            ),
            fallbackDrill: drill(id: "fallback", title: "Fallback", format: .miniDrill),
            modeAvailability: .allAvailable
        )

        #expect(projection.destination(imAvailable: true) == .imPractice(scenario: nil, tone: nil))
    }

    @Test func nonIMFullRepDropsIrrelevantScenarioAndTone() {
        let projection = SummaryPrescriptionProjection.resolve(
            nextAction: nextAction(
                .practiceMode(.timed, reason: "Build one structured answer."),
                reasoning: "A timed rep isolates answer shape.",
                confidence: .moderate
            ),
            fallbackDrill: drill(id: "fallback", title: "Fallback", format: .miniDrill),
            existingScenario: .networking,
            existingTone: .warm
        )

        guard case .fullRep(let mode, let scenario, let tone) = projection.kind else {
            Issue.record("Expected a full-rep projection")
            return
        }
        #expect(mode == .timed)
        #expect(scenario == nil)
        #expect(tone == nil)
        #expect(projection.destination(imAvailable: false) == .timedPractice(difficulty: nil))
    }

    @Test func duplicateReasoningIsNotRenderedAsDuplicateEvidence() {
        let reason = "Run one comparable rep to see whether the gain holds."
        let projection = SummaryPrescriptionProjection.resolve(
            nextAction: nextAction(
                .stabilizingRep(.timed, reason: reason),
                reasoning: "  \(reason.uppercased())  ",
                confidence: .moderate
            ),
            fallbackDrill: drill(id: "fallback", title: "Fallback", format: .miniDrill)
        )

        #expect(projection.evidence == nil)
    }

    private func assertFullRep(
        action: ActionRecommendation,
        expectedMode: PracticeMode,
        expectedTitle: String
    ) {
        let projection = SummaryPrescriptionProjection.resolve(
            nextAction: nextAction(
                action,
                reasoning: "The available evidence points to one comparable full rep.",
                confidence: .moderate
            ),
            fallbackDrill: drill(id: "fallback", title: "Fallback", format: .miniDrill),
            modeAvailability: .allAvailable
        )

        #expect(projection.source == .finalizedNextAction)
        #expect(projection.title == expectedTitle)
        #expect(projection.fullRepMode == expectedMode)
        guard case .fullRep(let mode, let scenario, let tone) = projection.kind else {
            Issue.record("Expected a full-rep projection")
            return
        }
        #expect(mode == expectedMode)
        #expect(scenario == nil)
        #expect(tone == nil)
    }

    private func nextAction(
        _ primary: ActionRecommendation,
        reasoning: String,
        confidence: BaselineConfidence,
        availabilityFallbackFrom: PracticeMode? = nil
    ) -> NextAction {
        NextAction(
            primary: primary,
            secondary: nil,
            reasoning: reasoning,
            confidenceLevel: confidence,
            availabilityFallbackFrom: availabilityFallbackFrom
        )
    }

    private func drill(
        id: String,
        title: String,
        format: DrillFormat,
        trendContext: String? = nil
    ) -> DrillRecommendationV2 {
        DrillRecommendationV2(
            variation: DrillVariation(
                id: id,
                skillArea: .pauseUsage,
                title: title,
                constraint: "Hold one silent beat before the next point.",
                coachingPrinciple: "A deliberate pause separates ideas.",
                format: format,
                successDescription: "Land three clean transitions."
            ),
            reason: "Your latest rep needs a clearer transition beat.",
            trendContext: trendContext,
            alternateFormat: nil
        )
    }
}

@Suite("Historical Review replay semantics")
struct HistoricalReviewReplaySemanticsTests {
    @Test func everyModeUsesReplayCopyAndNeverClaimsAdaptiveAcceptance() {
        for mode in [
            PracticeMode.timed,
            .suddenDeath,
            .ahCounter,
            .imConversation,
        ] {
            let presentation = SessionHistoryDetailReplayPresentation.make(
                for: session(mode: mode)
            )

            #expect(presentation.displayTitle == "Repeat this rep")
            #expect(presentation.displaySupportingCopy.lowercased().contains("replay"))
            #expect(presentation.accessibilityLabel.contains("Repeat this rep"))
            #expect(presentation.semantics == .replay)
            #expect(!presentation.semantics.recordsAdaptivePrescriptionAcceptance)
            #expect(!presentation.accessibilityLabel.contains("!"))
            #expect(!presentation.accessibilityLabel.lowercased().contains("let's"))
        }
    }

    @Test func reviewReplayPreservesRecordedIMSetupWithoutChangingItsSemantics() {
        let setup = IMConversationSetup(
            scenario: .socialCatchUp,
            targetTone: .warm
        )
        let details = IMConversationDetails(
            setup: setup,
            turns: [],
            actualTone: nil,
            finalState: nil,
            outcome: nil
        )
        let presentation = SessionHistoryDetailReplayPresentation.make(
            for: session(mode: .imConversation, details: details)
        )

        #expect(presentation.destination == .imPractice(
            scenario: .socialCatchUp,
            tone: .warm
        ))
        #expect(presentation.semantics == .replay)
        #expect(!presentation.semantics.recordsAdaptivePrescriptionAcceptance)
    }

    private func session(
        mode: PracticeMode,
        details: IMConversationDetails? = nil
    ) -> PracticeSession {
        PracticeSession(
            transcript: "A complete answer with a clear point and one supporting reason.",
            fillerWordCount: 0,
            duration: 40,
            date: Date(),
            mode: mode,
            imConversationDetails: details,
            score: 7
        )
    }
}
