import Foundation
import Testing
@testable import Noum

@Suite("Cohesive Review story")
struct CohesiveReviewStoryTests {
    private func session(daysAgo: Double = 0, score: Int = 7) -> PracticeSession {
        PracticeSession(
            transcript: "A clear answer with one concrete example.",
            fillerWordCount: 0,
            duration: 42,
            date: Date().addingTimeInterval(-daysAgo * 86_400),
            mode: .timed,
            score: score
        )
    }

    private func trend(
        _ area: SkillArea,
        direction: TrendDirection,
        confidence: TrendConfidence,
        windowSize: Int
    ) -> SkillTrend {
        SkillTrend(
            skillArea: area,
            direction: direction,
            confidence: confidence,
            windowSize: windowSize,
            currentLevel: .developing,
            recentDelta: nil
        )
    }

    @Test func storyCombinesMovementMeaningAndNextFocus() throws {
        let latest = session(daysAgo: 0)
        let story = try #require(ReviewStoryPresentation.make(
            trends: [
                trend(.structure, direction: .improving, confidence: .high, windowSize: 8),
                trend(.paceControl, direction: .declining, confidence: .medium, windowSize: 8)
            ],
            sessions: [session(daysAgo: 2), latest]
        ))

        #expect(story.latestSessionID == latest.id)
        #expect(story.movement.localizedCaseInsensitiveContains("structure"))
        #expect(story.meaning.localizedCaseInsensitiveContains("pace"))
        #expect(story.nextFocus == "Next focus: Pace.")
        #expect(story.evidenceCaption == "Seen across 8 recent reps.")
    }

    @Test func thinStoryDoesNotClaimAPattern() throws {
        let story = try #require(ReviewStoryPresentation.make(
            trends: [],
            sessions: [session(daysAgo: 1), session(daysAgo: 0)]
        ))

        #expect(story.meaning == "There is not enough evidence to call a pattern yet.")
        #expect(story.evidenceCaption == "Based on your latest two reps.")
        #expect(!story.movement.localizedCaseInsensitiveContains("trend"))
    }

    @Test func progressDisclosureStartsCollapsed() {
        #expect(!ReviewProgressDisclosure.defaultExpanded)
    }

    @Test func reviewHighlightsAreCappedAtTwoRows() {
        let highlights = [
            ReviewHighlightsEngine.Highlight(kind: .breakthrough, sessionID: UUID(), title: "One", line: "One"),
            ReviewHighlightsEngine.Highlight(kind: .goalExample, sessionID: UUID(), title: "Two", line: "Two"),
            ReviewHighlightsEngine.Highlight(kind: .recentBest, sessionID: UUID(), title: "Three", line: "Three")
        ]

        #expect(ReviewHighlightLimit.visible(highlights).count == 2)
    }
}

@Suite("Cohesive Profile composition")
struct CohesiveProfileCompositionTests {
    private func plan() -> CoachingPlan {
        CoachingPlan(
            strongestMode: .timed,
            currentFocus: "Focus on deliberate openings.",
            suggestedDrill: "Timed Practice: open with the answer, then add one concrete example.",
            encouragement: "Your recent reps are becoming more direct.",
            hiddenBaseline: HiddenBaseline(
                averageFillers: 1,
                averageDuration: 45,
                averageWordsPerMinute: 138,
                currentIdentity: "Controlled"
            )
        )
    }

    @Test func zeroThinAndEstablishedPlansStayBounded() {
        let zero = ProfileCompositionPlan.make(sessionCount: 0, hasProgressEvidence: false)
        let thin = ProfileCompositionPlan.make(sessionCount: 3, hasProgressEvidence: true)
        let established = ProfileCompositionPlan.make(sessionCount: 12, hasProgressEvidence: true)

        #expect(zero.stage == .zero)
        #expect(zero.surfaces == [.identity, .coachRead, .evidenceHub])
        #expect(thin.stage == .thin)
        #expect(thin.surfaces == [.identity, .progressHero, .coachRead, .evidenceHub])
        #expect(established.stage == .established)
        #expect(established.surfaces == [.identity, .progressHero, .coachRead, .evidenceHub])
    }

    @Test func oneOrTwoRepsUseLatestRepLanguageOnly() {
        for count in 1...2 {
            let brief = ProfileCoachBriefPresentation.make(
                sessionCount: count,
                plan: plan(),
                memory: nil
            )
            #expect(brief.observation == "Your latest rep points to deliberate openings.")
            #expect(!brief.observation.localizedCaseInsensitiveContains("pattern"))
            #expect(!brief.observation.localizedCaseInsensitiveContains("recent reps"))
        }
    }

    @Test func evidenceCaptionScalesWithDepth() {
        #expect(ProfileCoachBriefPresentation.evidenceCaption(for: 0) == nil)
        #expect(ProfileCoachBriefPresentation.evidenceCaption(for: 1) == "Based on your latest rep.")
        #expect(ProfileCoachBriefPresentation.evidenceCaption(for: 3) == "Early read from 3 recent reps.")
        #expect(ProfileCoachBriefPresentation.evidenceCaption(for: 7) == "Seen across 7 recent reps.")
        #expect(ProfileCoachBriefPresentation.evidenceCaption(for: 12) == "Repeated across 12 recent reps.")
    }

    @Test func establishedBriefRemovesInternalCoachingJargon() {
        let memory = CoachMemory(
            updatedAt: Date(),
            evidenceCount: 12,
            evidenceConfidence: .established,
            currentLever: .fillerReduction,
            goalFit: .aligned,
            strengths: [],
            blockers: [],
            workingHypothesis: "Filler Words appears to be the highest-leverage focus because persistent blocker in the rolling baseline; keep checking against future reps."
        )

        let brief = ProfileCoachBriefPresentation.make(
            sessionCount: 12,
            plan: plan(),
            memory: memory
        )
        let visibleCopy = [brief.observation, brief.nextMove, brief.evidenceCaption ?? ""]
            .joined(separator: " ")
            .lowercased()

        #expect(brief.evidenceCaption == "Repeated across 12 recent reps.")
        #expect(!visibleCopy.contains("lever"))
        #expect(!visibleCopy.contains("rolling baseline"))
        #expect(!visibleCopy.contains("rehearsal shapes"))
        #expect(!visibleCopy.contains("established read"))
        #expect(!visibleCopy.contains("evidence behind this read"))
    }
}

@Suite("Peer comparison visibility")
struct PeerComparisonVisibilityTests {
    private func member(_ accountID: String, name: String) -> PublicProfileSnapshot {
        .empty(accountID: accountID, displayName: name)
    }

    @Test func emptyAndSelfOnlyBucketsStayForming() {
        #expect(PeerComparisonVisibility.make(members: [], currentAccountID: "me") == .forming)
        #expect(PeerComparisonVisibility.make(
            members: [member("me", name: "Me")],
            currentAccountID: "me"
        ) == .forming)
    }

    @Test func missingCurrentAccountNeverTreatsRowsAsPeers() {
        #expect(PeerComparisonVisibility.make(
            members: [member("someone", name: "Someone")],
            currentAccountID: nil
        ) == .forming)
    }

    @Test func genuinePeersUnlockTheProfileRouteAndDeduplicate() {
        let visibility = PeerComparisonVisibility.make(
            members: [
                member("me", name: "Me"),
                member("peer", name: "Peer"),
                member("peer", name: "Peer duplicate")
            ],
            currentAccountID: "me"
        )

        #expect(visibility == .available(peerCount: 1))
        #expect(visibility.showsProfileEntry)
        #expect(ProfileLibraryPresentation.make(
            showsPeerComparison: visibility.showsProfileEntry,
            isPremium: true
        ).rows.contains(.peerComparison))
    }

    @Test func formingStateKeepsPeerRouteOutOfProfile() {
        let presentation = ProfileLibraryPresentation.make(
            showsPeerComparison: PeerComparisonVisibility.forming.showsProfileEntry,
            isPremium: false
        )
        #expect(!presentation.rows.contains(.peerComparison))
        #expect(presentation.rows.last == .upgrade)
    }
}
