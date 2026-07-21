import Foundation
import Testing
@testable import Noum

@Suite("Cohesive summary interstitial policy")
struct CohesiveSummaryInterstitialPolicyTests {
    @Test func statusAreaCoverUsesTheMeasuredTopInset() {
        #expect(SummaryTopSafeAreaCoverLayout.height(for: 59) == 59)
        #expect(SummaryTopSafeAreaCoverLayout.height(for: 24) == 24)
        #expect(SummaryTopSafeAreaCoverLayout.height(for: 0) == 0)
        #expect(SummaryTopSafeAreaCoverLayout.height(for: -1) == 0)
    }

    @Test func firstRepSuppressesEveryInterstitialCandidate() {
        for count in [0, 1] {
            let selected = SummaryInterstitialPolicy.select(
                completedRepCount: count,
                hasPersonalBest: true,
                hasSkillProgress: true,
                hasAchievementProgress: true,
                hasPracticeVolumeLevel: true
            )
            #expect(selected == nil)
        }
    }

    @Test func everyEarnedEventStaysInsideTheResultsReceipt() {
        #expect(SummaryInterstitialPolicy.priority.isEmpty)

        #expect(SummaryInterstitialPolicy.select(
            completedRepCount: 8,
            hasPersonalBest: true,
            hasSkillProgress: true,
            hasAchievementProgress: true,
            hasPracticeVolumeLevel: true
        ) == nil)

        #expect(SummaryInterstitialPolicy.select(
            completedRepCount: 8,
            hasPersonalBest: false,
            hasSkillProgress: true,
            hasAchievementProgress: true,
            hasPracticeVolumeLevel: true
        ) == nil)

        #expect(SummaryInterstitialPolicy.select(
            completedRepCount: 8,
            hasPersonalBest: false,
            hasSkillProgress: false,
            hasAchievementProgress: true,
            hasPracticeVolumeLevel: true
        ) == nil)
    }

    @Test func noEarnedCandidateGoesStraightToSummary() {
        #expect(SummaryInterstitialPolicy.select(
            completedRepCount: 12,
            hasPersonalBest: false,
            hasSkillProgress: false,
            hasAchievementProgress: false,
            hasPracticeVolumeLevel: false
        ) == nil)
    }
}

@Suite("Cohesive post-rep debrief")
struct CohesivePostRepDebriefTests {
    @Test func combinedDebriefShowsHeldAndMoveWhenBothExist() {
        let content = makeContent(
            win: .init(
                headline: "The opening landed clearly.",
                quote: "The answer is simple",
                support: "Direct opening",
                quoteIsVerified: true
            ),
            fix: .init(
                headline: "Hold the final sentence.",
                evidence: .text("The close accelerated."),
                nextMove: "Pause once before the conclusion."
            )
        )

        #expect(PostRepDebriefVisibility.resolve(content: content) == .init(
            showsWhatHeld: true,
            showsNextMove: true
        ))
    }

    @Test func combinedDebriefKeepsReviewMoveWithoutGenericFix() {
        let content = makeContent(win: nil, fix: nil)
        #expect(PostRepDebriefVisibility.resolve(
            content: content,
            hasReviewIntervention: true
        ) == .init(showsWhatHeld: false, showsNextMove: true))
    }

    @Test func thinRepDoesNotInventHeldOrMoveSections() {
        let content = makeContent(win: nil, fix: nil)
        #expect(PostRepDebriefVisibility.resolve(content: content) == .init(
            showsWhatHeld: false,
            showsNextMove: false
        ))
    }

    private func makeContent(
        win: PostRepVerdictContent.Win?,
        fix: PostRepVerdictContent.Fix?
    ) -> PostRepVerdictContent {
        PostRepVerdictContent(
            readText: "A bounded read.",
            provenanceLabel: nil,
            thinEvidenceCopy: nil,
            deliveryReadLine: nil,
            win: win,
            fix: fix
        )
    }
}

@Suite("Cohesive summary and Ask Noum copy")
struct CohesiveSummaryAskCopyTests {
    @Test func deterministicWarmProofDoesNotInferPaceOrToneFromFillers() {
        let session = PracticeSession(
            id: UUID(),
            transcript: "We will focus on the customer problem before proposing the next move.",
            fillerWordCount: 0,
            duration: 68,
            date: Date(),
            mode: .timed,
            score: 9
        )
        let input = ProofMomentInput(
            session: session,
            voice: .warm,
            goalParaphrase: nil,
            baselineFillerRate: nil,
            baselinePace: nil
        )

        let proof = ProofMomentService.deterministicProof(for: input)
        let claim = proof?.claim.lowercased() ?? ""

        #expect(proof?.technique == "Clean Delivery")
        #expect(claim.contains("no fillers across this rep"))
        #expect(!claim.contains("calm"))
        #expect(!claim.contains("unhurried"))
        #expect(!claim.contains("reads as warmth"))
    }

    @Test func summaryUsesOneStandardActionVocabulary() {
        let labels = [
            SummaryDrillActionCard.primaryCTALabel(drillTitle: "Land the pause"),
            SummaryRepeatActionCard.primaryCTALabel(exerciseName: "Conversation Practice"),
            CohesiveSummaryCopy.askNoum,
            CohesiveSummaryCopy.seeDetails,
            CohesiveSummaryCopy.done,
        ]

        #expect(labels[0] == "Start Land the pause")
        #expect(labels[1] == "Start Conversation Practice")
        #expect(Array(labels.dropFirst(2)) == ["Ask Noum", "See details", "Done"])

        for label in labels {
            let lower = label.lowercased()
            for banned in ["begin", "run ", "open ", "talk to noum"] {
                #expect(!lower.contains(banned))
            }
        }
    }

    @Test func askLabelsContainNoImplementationOrCaseFileLanguage() {
        let labels = AskNoumVisibleCopy.primaryLabels
        let banned = [
            "current case",
            "review due",
            "using:",
            "rule-based",
            "ai-backed",
            "evidence behind this read",
            "talk to noum",
        ]

        for label in labels {
            let lower = label.lowercased()
            for fragment in banned {
                #expect(!lower.contains(fragment))
            }
        }
    }

    @Test func evidenceMetadataIsBoundedAndHonest() {
        #expect(AskNoumEvidenceMetadata.line(
            responseKind: .personalEvidenceRead,
            hasCurrentFocus: true,
            recentRepCount: 3
        ) == "Based on your current focus and 3 recent reps")
        #expect(AskNoumEvidenceMetadata.line(
            responseKind: .personalEvidenceRead,
            hasCurrentFocus: true,
            recentRepCount: 1
        ) == "Based on your current focus and 1 recent rep")
        #expect(AskNoumEvidenceMetadata.line(
            responseKind: .personalEvidenceRead,
            hasCurrentFocus: true,
            recentRepCount: 30
        ) == "Based on your current focus and 12 recent reps")
        #expect(AskNoumEvidenceMetadata.line(
            responseKind: .personalEvidenceRead,
            hasCurrentFocus: false,
            recentRepCount: 3
        ) == nil)
        #expect(AskNoumEvidenceMetadata.line(
            responseKind: .personalEvidenceRead,
            hasCurrentFocus: true,
            recentRepCount: 0
        ) == nil)
        #expect(AskNoumEvidenceMetadata.line(
            responseKind: .conversational,
            hasCurrentFocus: true,
            recentRepCount: 12
        ) == nil)
        #expect(AskNoumEvidenceMetadata.line(
            responseKind: .generalCoaching,
            hasCurrentFocus: true,
            recentRepCount: 12
        ) == nil)
        #expect(AskNoumEvidenceMetadata.line(
            responseKind: nil,
            hasCurrentFocus: true,
            recentRepCount: 12
        ) == nil)
    }
}
