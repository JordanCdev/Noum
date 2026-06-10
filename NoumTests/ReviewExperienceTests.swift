//
//  ReviewExperienceTests.swift
//  NoumTests
//
//  Contracts behind the insight-first Review overhaul: the under-target
//  scoring cap, the suggested-review highlights engine, the session-list
//  search/sort/collapse model, and the detail-view presentation helpers.
//

import Foundation
import Testing
import SwiftUI
@testable import Noum

// MARK: - Fixtures

private func makeSession(
    score: Int? = nil,
    daysAgo: Double = 0,
    duration: TimeInterval = 45,
    fillers: Int = 0,
    mode: PracticeMode = .timed,
    transcript: String = "a steady answer with a clear point and a clean close",
    headline: String? = nil,
    prompt: String? = nil,
    coachSummary: String? = nil,
    aiCoachFeedback: AICoachFeedback? = nil
) -> PracticeSession {
    PracticeSession(
        transcript: transcript,
        fillerWordCount: fillers,
        duration: duration,
        date: Date().addingTimeInterval(-daysAgo * 86_400),
        mode: mode,
        score: score,
        headline: headline,
        coachSummary: coachSummary,
        aiCoachFeedback: aiCoachFeedback,
        prompt: prompt
    )
}

private func makeChosenVoiceProfile(_ goal: SpeakingStyleGoal) -> CoachingProfile {
    var profile = CoachingProfile(
        speakingContext: .interviews,
        primaryGoal: .reduceFillers,
        confidenceLevel: .rebuilding,
        biggestChallenge: .fillerWords,
        desiredOutcome: .persuasive,
        speakingStyleGoal: goal,
        styleReference: "",
        coachingBrief: "",
        motivationWhyNow: "",
        successVision: ""
    )
    profile.chosenStyleGoal = goal
    return profile
}

// MARK: - Under-target scoring cap

// A rep the app itself describes as "only Ns — the target range is X–Ys"
// must not also read 9/10 "Table-topics ready" — that contradiction was
// called out on a real device. Solid (≤7) is the ceiling for a duration
// miss; the Timing segment and feedback line carry the why.
struct UnderTargetScoreCapTests {

    /// Strong content, clean delivery, but 34s against Easy's 45–90s
    /// window — the real-device case that scored 9/10.
    @Test func underTargetRepCapsAtSeven() {
        let words = Array(repeating: "word", count: 57).joined(separator: " ")
        let evaluation = PracticeEvaluator.evaluateTimedPractice(
            transcript: words,
            fillerCount: 0,
            duration: 34,
            difficulty: .easy,
            recentSessions: [],
            profile: nil
        )
        #expect(evaluation.durationAssessment == .tooShort)
        #expect(evaluation.score <= 7,
                "under-target rep scored \(evaluation.score); cap is 7")
        #expect(evaluation.headline != "Table-topics ready",
                "headline must not claim table-topics readiness on a duration miss")
    }

    /// The same delivery inside the window keeps its high score — the cap
    /// punishes nothing; it only stops the contradiction.
    @Test func onTargetRepStillScoresHigh() {
        let words = Array(repeating: "word", count: 130).joined(separator: " ")
        let evaluation = PracticeEvaluator.evaluateTimedPractice(
            transcript: words,
            fillerCount: 0,
            duration: 60,
            difficulty: .easy,
            recentSessions: [],
            profile: nil
        )
        #expect(evaluation.durationAssessment == .onTarget)
        #expect(evaluation.score >= 8,
                "on-target clean rep scored \(evaluation.score); the cap must not drag good reps down")
    }

    /// The sub-3s guard rail is untouched by the cap.
    @Test func nearEmptyRepStillScoresOne() {
        let evaluation = PracticeEvaluator.evaluateTimedPractice(
            transcript: "um",
            fillerCount: 1,
            duration: 2,
            difficulty: .easy,
            recentSessions: [],
            profile: nil
        )
        #expect(evaluation.score == 1)
    }
}

// MARK: - Review highlights engine

struct ReviewHighlightsEngineTests {

    @Test func noPicksBelowEvidenceFloor() {
        let sessions = (0..<4).map { makeSession(score: 8, daysAgo: Double($0)) }
        let picks = ReviewHighlightsEngine.highlights(sessions: sessions, profile: nil)
        #expect(picks.isEmpty, "4 scored reps is below the \(ReviewHighlightsEngine.minimumScoredSessions)-rep floor")
    }

    @Test func breakthroughFindsTheJumpRep() {
        var sessions = (1...4).map { makeSession(score: 4, daysAgo: Double($0)) }
        let jump = makeSession(score: 8, daysAgo: 0.5)
        sessions.append(jump)

        let pick = ReviewHighlightsEngine.breakthrough(
            in: sessions.sorted { $0.date > $1.date }
        )
        #expect(pick?.sessionID == jump.id)
        #expect(pick?.line.contains("8/10") == true)
        #expect(pick?.line.contains("4.0") == true, "line names the prior average as evidence")
    }

    @Test func breakthroughNeedsThreePriors() {
        let sessions = [
            makeSession(score: 4, daysAgo: 2),
            makeSession(score: 4, daysAgo: 1.5),
            makeSession(score: 9, daysAgo: 1),
        ]
        let pick = ReviewHighlightsEngine.breakthrough(in: sessions.sorted { $0.date > $1.date })
        #expect(pick == nil, "two priors can't establish an average worth comparing against")
    }

    @Test func goalExampleRequiresAChosenVoice() {
        // Strong, voice-fitting reps (0 fillers, 30s+ → authoritative fit 0.5).
        let sessions = (0..<6).map {
            makeSession(score: 8, daysAgo: Double($0), duration: 40, fillers: 0)
        }

        let withoutChoice = ReviewHighlightsEngine.goalExample(
            in: sessions, profile: nil
        )
        #expect(withoutChoice == nil)

        let withChoice = ReviewHighlightsEngine.goalExample(
            in: sessions, profile: makeChosenVoiceProfile(.authoritative)
        )
        #expect(withChoice != nil)
        #expect(withChoice?.title.contains("authoritative") == true)
    }

    @Test func recentBestIgnoresOldReps() {
        let oldBest = [makeSession(score: 9, daysAgo: 30)]
        #expect(ReviewHighlightsEngine.recentBest(in: oldBest) == nil)

        let fresh = makeSession(score: 9, daysAgo: 3)
        let pick = ReviewHighlightsEngine.recentBest(in: [fresh])
        #expect(pick?.sessionID == fresh.id)
    }

    @Test func picksNeverRepeatASession() {
        // One standout rep that qualifies as breakthrough AND recent best.
        var sessions = (1...4).map { makeSession(score: 4, daysAgo: Double($0)) }
        sessions.append(makeSession(score: 9, daysAgo: 0.5))

        let picks = ReviewHighlightsEngine.highlights(sessions: sessions, profile: nil)
        let ids = picks.map(\.sessionID)
        #expect(Set(ids).count == ids.count, "the same rep must not appear twice")
        #expect(picks.first?.kind == .breakthrough)
    }
}

// MARK: - Session list model

struct SessionHistoryListModelTests {

    @Test func searchMatchesPromptTranscriptAndHeadline() {
        let session = makeSession(
            score: 8,
            transcript: "the hardest part of being in charge",
            headline: "Solid response",
            prompt: "What is the hardest part of leadership?"
        )
        #expect(SessionHistoryListModel.matches(session, query: "leadership"))
        #expect(SessionHistoryListModel.matches(session, query: "in charge"))
        #expect(SessionHistoryListModel.matches(session, query: "SOLID"))
        #expect(!SessionHistoryListModel.matches(session, query: "kangaroo"))
        #expect(SessionHistoryListModel.matches(session, query: "  "), "blank query matches everything")
    }

    @Test func highestScoreSortPutsUnscoredLast() {
        let high = makeSession(score: 9, daysAgo: 3)
        let low = makeSession(score: 2, daysAgo: 2)
        let unscored = makeSession(score: nil, daysAgo: 1)

        let sorted = SessionHistoryListModel.apply(
            [low, unscored, high], mode: nil, query: "", sort: .highestScore
        )
        #expect(sorted.first?.id == high.id)
        #expect(sorted.last?.id == unscored.id)
    }

    @Test func lowSignalPredicateMatchesTheFeedback() {
        // "Scores like two out of ten or no score = not completed properly."
        #expect(SessionHistoryListModel.isLowSignal(makeSession(score: 2)))
        #expect(SessionHistoryListModel.isLowSignal(makeSession(score: 1)))
        #expect(!SessionHistoryListModel.isLowSignal(makeSession(score: 3)))
        // Unscored but substantial: the user bailed on the summary, not
        // the speaking — keep it a full row.
        #expect(!SessionHistoryListModel.isLowSignal(makeSession(score: nil, duration: 47)))
        #expect(SessionHistoryListModel.isLowSignal(makeSession(score: nil, duration: 9)))
    }

    @Test func collapsingGroupsConsecutiveLowSignalRuns() {
        let good1 = makeSession(score: 8, daysAgo: 1)
        let junk1 = makeSession(score: 1, daysAgo: 2)
        let junk2 = makeSession(score: 1, daysAgo: 3)
        let junk3 = makeSession(score: 2, daysAgo: 4)
        let good2 = makeSession(score: 7, daysAgo: 5)

        let groups = SessionHistoryListModel.grouped(
            [good1, junk1, junk2, junk3, good2],
            collapsingLowSignal: true
        )
        #expect(groups.count == 3)
        if case .collapsed(let collapsed) = groups[1] {
            #expect(collapsed.count == 3)
        } else {
            Issue.record("middle group should be the collapsed junk run")
        }
    }

    @Test func singleLowSignalRepStaysAFullRow() {
        let good = makeSession(score: 8, daysAgo: 1)
        let junk = makeSession(score: 1, daysAgo: 2)
        let groups = SessionHistoryListModel.grouped([good, junk], collapsingLowSignal: true)
        #expect(groups.count == 2)
        for group in groups {
            if case .collapsed = group {
                Issue.record("a single low-signal rep must not collapse — that reads as editing history")
            }
        }
    }

    @Test func searchDisablesCollapsing() {
        let junk1 = makeSession(score: 1, daysAgo: 1)
        let junk2 = makeSession(score: 1, daysAgo: 2)
        let groups = SessionHistoryListModel.grouped([junk1, junk2], collapsingLowSignal: false)
        #expect(groups.count == 2)
    }
}

// MARK: - Detail presentation helpers

struct SessionHistoryDetailPresentationTests {

    @Test func leadSentenceCutsAtFirstRealTerminator() {
        let paragraph = "Lead with your main point and let it breathe. Your current opening uses conversational phrasing which can dilute the impact."
        let lead = SessionHistoryDetailPresentation.leadSentence(of: paragraph)
        #expect(lead == "Lead with your main point and let it breathe.")
    }

    @Test func leadSentenceSurvivesEarlyAbbreviation() {
        let paragraph = "E.g. focus on leading with your main point before expanding."
        let lead = SessionHistoryDetailPresentation.leadSentence(of: paragraph)
        #expect(lead.count > 10, "an abbreviation period must not end the sentence at 'E.g.'")
    }

    @Test func leadSentenceWithoutTerminatorReturnsWholeText() {
        let text = "keep the opening deliberate and slow"
        #expect(SessionHistoryDetailPresentation.leadSentence(of: text) == text)
    }

    @Test func previousRepLineFindsSameModePriorScoredRep() {
        let previous = makeSession(score: 5, daysAgo: 3, mode: .timed)
        let otherMode = makeSession(score: 9, daysAgo: 2, mode: .ahCounter)
        let current = makeSession(score: 8, daysAgo: 1, mode: .timed)

        let line = SessionHistoryDetailPresentation.previousRepLine(
            for: current, in: [previous, otherMode, current]
        )
        #expect(line?.contains("5/10") == true)
        #expect(line?.contains("Timed") == true)
    }

    @Test func previousRepLineIsNilForFirstScoredRep() {
        let current = makeSession(score: 8, daysAgo: 1, mode: .timed)
        let line = SessionHistoryDetailPresentation.previousRepLine(for: current, in: [current])
        #expect(line == nil)
    }

    @Test func previousRepLineIsNilForUnscoredRep() {
        let previous = makeSession(score: 5, daysAgo: 3, mode: .timed)
        let current = makeSession(score: nil, daysAgo: 1, mode: .timed)
        let line = SessionHistoryDetailPresentation.previousRepLine(for: current, in: [previous, current])
        #expect(line == nil)
    }

    @Test func durationRendersRoundedEverywhere() {
        // 34.6s rendered as 34s in one card and 35s in another on the same
        // screen — the real-device inconsistency. Rounded is the contract.
        let session = makeSession(score: 8, duration: 34.6)
        #expect(SessionHistoryDetailPresentation.durationLabel(for: session) == "35s")
        #expect(SessionHistoryDetailPresentation.transcriptEndLine(for: session).contains("35s"))
    }

    @Test func promptSurfacesOnlyWhenReal() {
        #expect(SessionHistoryDetailPresentation.prompt(for: makeSession(prompt: "Tell me about a hard call.")) == "Tell me about a hard call.")
        #expect(SessionHistoryDetailPresentation.prompt(for: makeSession(prompt: "   ")) == nil)
        #expect(SessionHistoryDetailPresentation.prompt(for: makeSession(prompt: nil)) == nil)
    }
}

// MARK: - Coach read selection

struct ReviewCoachReadTests {

    private func trend(
        _ area: SkillArea,
        direction: TrendDirection,
        confidence: TrendConfidence
    ) -> SkillTrend {
        SkillTrend(
            skillArea: area,
            direction: direction,
            confidence: confidence,
            windowSize: 8,
            currentLevel: .developing,
            recentDelta: nil
        )
    }

    @Test func lowConfidenceTrendsNeverSurface() {
        let trends = [
            trend(.fillerReduction, direction: .improving, confidence: .low),
            trend(.paceControl, direction: .declining, confidence: .low),
        ]
        #expect(ReviewCoachRead.improvingTrend(in: trends) == nil)
        #expect(ReviewCoachRead.focusTrend(in: trends) == nil)
    }

    @Test func picksHighestConfidenceRows() {
        let trends = [
            trend(.fillerReduction, direction: .improving, confidence: .medium),
            trend(.structure, direction: .improving, confidence: .high),
            trend(.paceControl, direction: .declining, confidence: .medium),
        ]
        #expect(ReviewCoachRead.improvingTrend(in: trends)?.skillArea == .structure)
        #expect(ReviewCoachRead.focusTrend(in: trends)?.skillArea == .paceControl)
    }

    @Test func focusCopyStaysCalm() {
        let line = ReviewCoachRead.focusLine(
            for: trend(.paceControl, direction: .declining, confidence: .high)
        )
        #expect(!line.contains("!"))
        let lowered = line.lowercased()
        #expect(!lowered.contains("fail"))
        #expect(!lowered.contains("bad"))
        #expect(!lowered.contains("worse"))
    }
}
