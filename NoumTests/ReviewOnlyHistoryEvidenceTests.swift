import Foundation
import Testing
@testable import Noum

@Suite("Review-only history evidence")
struct ReviewOnlyHistoryEvidenceTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Rendered fixture is durable raw history with only two progress reps")
    func fixtureBoundary() {
        let sessions = ReviewProgressEligibilityUITestFixture.sessions(now: now)
        let eligible = PracticeProgressEligibility.eligibleSessions(in: sessions)

        #expect(sessions.count == 5)
        #expect(eligible.map(\.id) == [
            ReviewProgressEligibilityUITestFixture.eligibleLatestID,
            ReviewProgressEligibilityUITestFixture.eligibleEarlierID,
        ])
        #expect(sessions.first?.id == ReviewProgressEligibilityUITestFixture.tooFewWordsID)
        #expect((sessions.first?.date ?? .distantPast) > (eligible.first?.date ?? .distantFuture))
        #expect(sessions.allSatisfy { $0.duration.isFinite && !$0.isEvaluationFixture })
        #expect(eligible.allSatisfy(SessionQualifier.qualifies))
    }

    @Test("All Reps keeps raw count but aggregate score and mode cards use measured reps")
    func allRepsSeparatesRawRowsFromAggregates() {
        let sessions = ReviewProgressEligibilityUITestFixture.sessions(now: now)
        let progressSessions = SessionHistoryListEvidence.progressSessions(in: sessions)

        #expect(SessionHistoryListEvidence.leadSummary(for: sessions) ==
            "5 sessions saved. 2 measured reps. Average score 6.5.")
        #expect(progressSessions.count == 2)

        let row = CrossModeHistorySummary.rows(
            from: progressSessions,
            now: now
        ).first
        #expect(row?.mode == .timed)
        #expect(row?.repCount == 2)
        #expect(row?.averageScore == 6.5)

        let rawSearch = SessionHistoryListModel.apply(
            sessions,
            mode: nil,
            query: "Two-word capture",
            sort: .newest
        )
        #expect(rawSearch.map(\.id) == [ReviewProgressEligibilityUITestFixture.tooFewWordsID])
    }

    @Test("Thin rows and details explain the capture without validating its stored score")
    func thinCapturePresentationSuppressesUnsupportedRead() {
        let thin = ReviewProgressEligibilityUITestFixture.sessions(now: now)[0]

        #expect(SessionHistoryRowPreview.text(for: thin) ==
            "Saved capture · Not enough speech to measure")
        #expect(SessionHistoryDetailPresentation.scoreLabel(for: thin) == "Not measured")
        #expect(SessionHistoryDetailPresentation.insufficientEvidenceMessage.contains("does not affect your progress"))
        #expect(!SessionHistoryRowPreview.text(for: thin)!.contains("10/10"))
    }

    @Test("Thin captures replace a persisted positive headline with neutral provenance")
    func thinCaptureHeadlineSuppressesUnsupportedPraise() {
        let thin = PracticeSession(
            transcript: "Brief answer",
            fillerWordCount: 0,
            duration: 30,
            date: now,
            mode: .timed,
            score: 10,
            headline: "Exceptional clarity under pressure"
        )

        let headline = SessionHistoryDetailPresentation.headline(
            for: thin,
            fallback: "Timed Practice"
        )
        #expect(headline == "Saved capture")
        #expect(!headline.contains("Exceptional"))
    }

    @Test("Measured captures preserve their persisted headline")
    func eligibleCaptureHeadlinePreservesStoredRead() {
        let measured = PracticeSession(
            transcript: "I stated the decision clearly, supported it with one reason, and named the next step.",
            fillerWordCount: 0,
            duration: 30,
            date: now,
            mode: .timed,
            score: 8,
            headline: "Clear decision and next step"
        )

        #expect(SessionHistoryDetailPresentation.headline(
            for: measured,
            fallback: "Timed Practice"
        ) == "Clear decision and next step")
    }

    @Test("Non-finite legacy duration has a safe presentation fallback")
    func nonFiniteDurationPresentationIsSafe() {
        let session = PracticeSession(
            transcript: "This legacy capture contains enough words for the duration fallback check.",
            fillerWordCount: 0,
            duration: .infinity,
            date: now,
            mode: .timed,
            score: 8
        )

        #expect(SessionHistoryDetailPresentation.durationLabel(for: session) == "Unavailable")
        #expect(SessionHistoryDetailPresentation.scoreLabel(for: session) == "Not measured")
    }

    @Test("Review root stays on two measured reps despite three newer scored captures")
    func reviewRootUsesOnlyMeasuredEvidence() {
        let sessions = ReviewProgressEligibilityUITestFixture.sessions(now: now)
        let story = ReviewStoryPresentation.make(trends: [], sessions: sessions)

        #expect(story?.evidenceCaption == "Based on your latest two reps.")
        #expect(story?.latestSessionID == ReviewProgressEligibilityUITestFixture.eligibleLatestID)
        #expect(!ReviewDevelopmentChartEvidence.hasEnoughData(in: sessions, now: now))
        #expect(ReviewHighlightsEngine.highlights(sessions: sessions, profile: nil, now: now).isEmpty)
    }

    @Test("Previous-rep comparison skips thin captures and withholds comparison for a thin current row")
    func previousRepComparisonUsesOnlyMeasuredEvidence() {
        let current = session(
            id: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!,
            transcript: "This current answer contains enough words to count as measured evidence.",
            score: 7,
            date: now
        )
        let thinPrior = session(
            id: UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!,
            transcript: "Thin capture",
            score: 10,
            date: now.addingTimeInterval(-60)
        )
        let eligiblePrior = session(
            id: UUID(uuidString: "CCCCCCCC-CCCC-4CCC-8CCC-CCCCCCCCCCCC")!,
            transcript: "This earlier answer also contains enough words for measured evidence.",
            score: 6,
            date: now.addingTimeInterval(-120)
        )

        let line = SessionHistoryDetailPresentation.previousRepLine(
            for: current,
            in: [current, thinPrior, eligiblePrior]
        )
        #expect(line?.contains("6/10") == true)
        #expect(line?.contains("10/10") == false)
        #expect(SessionHistoryDetailPresentation.previousRepLine(
            for: thinPrior,
            in: [thinPrior, eligiblePrior]
        ) == nil)
    }

    @Test("Thin low-score or filler-heavy captures cannot become targeted replay rows")
    func targetedReplayUsesOnlyMeasuredEvidence() {
        let thin = PracticeSession(
            transcript: "Thin capture",
            fillerWordCount: 9,
            duration: 30,
            date: now,
            mode: .timed,
            score: 1
        )
        let measured = PracticeSession(
            transcript: "This measured answer contains enough words to support a review row.",
            fillerWordCount: 0,
            duration: 30,
            date: now,
            mode: .timed,
            score: 5
        )

        #expect(MistakeReplayCard.eligibleReviewSessions(in: [thin]).isEmpty)
        #expect(!MistakeReplayCard.hasReviewRows(in: [thin], now: now))
        #expect(MistakeReplayCard.hasReviewRows(in: [measured], now: now))
    }

    @Test("Profile evidence floor remains two while raw history contains five rows")
    func profileEvidenceDepthUsesMeasuredSessions() {
        let sessions = ReviewProgressEligibilityUITestFixture.sessions(now: now)
        let eligible = PracticeProgressEligibility.eligibleSessions(in: sessions)
        let presentation = ProfileCoachBriefPresentation.make(
            sessionCount: eligible.count,
            plan: nil,
            memory: nil
        )

        #expect(presentation.evidenceCaption == "Based on your latest two reps.")
        #expect(presentation.observation == "Your latest two reps are setting a starting point.")
        #expect(!TransformationQuestionEligibility.shouldShow(
            sessionCount: eligible.count,
            events: []
        ))
        #expect(TransformationQuestionEligibility.shouldShow(
            sessionCount: sessions.count,
            events: []
        ))
    }

    @Test("Fixture is opt-in and requires the UI testing guard")
    func fixtureLaunchGuard() {
        let argument = ReviewProgressEligibilityUITestFixture.launchArgument
        #expect(!ReviewProgressEligibilityUITestFixture.requested(arguments: []))
        #expect(!ReviewProgressEligibilityUITestFixture.requested(arguments: [argument]))
        #expect(ReviewProgressEligibilityUITestFixture.requested(arguments: ["UI_TESTING", argument]))
    }

    private func session(
        id: UUID,
        transcript: String,
        score: Int,
        date: Date
    ) -> PracticeSession {
        PracticeSession(
            id: id,
            transcript: transcript,
            fillerWordCount: 0,
            duration: 30,
            date: date,
            mode: .timed,
            score: score
        )
    }
}
