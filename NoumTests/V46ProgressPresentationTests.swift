import Foundation
import Testing
@testable import Noum

/// Slice 3 contracts: the Progress evidence head and the Updated Today
/// earned state are driven only by comparable ledger evidence, speak in
/// bounded honest classes, and self-suppress without data.
@Suite("V4.6 Progress + Updated Today contracts")
struct V46ProgressPresentationTests {

    private var progressViewSource: String {
        get throws {
            let repositoryRoot = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            return try String(
                contentsOf: repositoryRoot
                    .appendingPathComponent("Noum")
                    .appendingPathComponent("SessionHistoryView.swift"),
                encoding: .utf8
            )
        }
    }

    private func outcome(
        result: TranscriptRetryResult,
        daysAgo: Double,
        lever: TranscriptPracticeLever = .opening,
        difficulty: TimedPracticeDifficulty = .easy,
        fingerprint: String = "v46-test",
        sourceSessionID: UUID = UUID(),
        sessionID: UUID = UUID(),
        comparisonSourceSessionID: UUID? = nil,
        comparisonRetrySessionID: UUID? = nil,
        now: Date = Date()
    ) -> RecommendationOutcome {
        RecommendationOutcome(
            id: UUID(),
            fingerprint: fingerprint,
            title: "Answer first",
            focus: "Answer first",
            target: "Answer first",
            mode: .timed,
            sessionID: sessionID,
            followed: true,
            executedDemand: .timed(difficulty: difficulty, speechProjectID: nil),
            completedAt: now.addingTimeInterval(-daysAgo * 24 * 3600),
            scoreDelta: 0,
            hasComparableScore: true,
            fillerDelta: 0,
            durationDelta: 0,
            sourceSessionID: sourceSessionID,
            transcriptRetryTarget: TranscriptRetryTarget(lever: lever),
            transcriptRetryComparison: TranscriptRetryComparison(
                schemaVersion: TranscriptRetryComparison.schemaVersion,
                lever: lever,
                sourceSessionID: comparisonSourceSessionID ?? sourceSessionID,
                retrySessionID: comparisonRetrySessionID ?? sessionID,
                sourceSignal: 40,
                retrySignal: result == .regressed ? 20 : 70,
                meaningOverlapPercent: 80,
                result: result
            )
        )
    }

    @Test("No comparable evidence renders nothing — never an activity chart")
    func suppressesWithoutComparableEvidence() {
        let presentation = V46ProgressPresentation.make(
            outcomes: [],
            intervention: nil
        )
        #expect(presentation == nil)
    }

    @Test("An accepted ordinary recommendation never impersonates verified retry progress")
    func ordinaryRecommendationTargetDoesNotEnterProgress() {
        let ordinary = RecommendationOutcome(
            id: UUID(),
            fingerprint: "ordinary-home-target",
            title: "Filler Control",
            focus: "Pause instead of filling.",
            target: "Finish the thought, then take one quiet beat.",
            mode: .ahCounter,
            sessionID: UUID(),
            followed: true,
            completedAt: Date(),
            scoreDelta: 0,
            hasComparableScore: false,
            fillerDelta: 0,
            durationDelta: 0,
            transcriptRetryTarget: nil,
            transcriptRetryComparison: nil
        )

        #expect(V46ProgressPresentation.make(
            outcomes: [ordinary],
            intervention: nil
        ) == nil)
    }

    @Test("Three holds in four reps reads as becoming reliable, with the honest tally")
    func reliableTallyClass() throws {
        let now = Date()
        let outcomes = [
            outcome(result: .improved, daysAgo: 3, now: now),
            outcome(result: .held, daysAgo: 2, now: now),
            outcome(result: .regressed, daysAgo: 1, difficulty: .hard, now: now),
            outcome(result: .improved, daysAgo: 0, difficulty: .medium, now: now)
        ]
        let presentation = try #require(V46ProgressPresentation.make(
            outcomes: outcomes,
            intervention: nil,
            now: now
        ))
        #expect(presentation.headline == "Becoming reliable.")
        #expect(presentation.readStage == .reliable)
        #expect(presentation.coachReadEyebrow == "COACH READ · LAST 4 REPS")
        #expect(presentation.authoredHeadline == "Your opening is becoming reliable.")
        #expect(presentation.nextFocus == TranscriptPracticeLever.opening.successMeasure)
        #expect(presentation.subtitle.contains("Held in 3 of 4 comparable reps"))
        #expect(presentation.subtitle.contains("under pressure"))
        #expect(presentation.rows.count <= 3)
        #expect(presentation.trajectory.count <= 4)
        #expect(presentation.trajectory.map(\.outcome) == [
            .improved, .held, .lapse, .improved
        ])
        #expect(presentation.trajectoryAccessibilitySummary.contains("held 3 of 4"))
    }

    @Test("A regressed day is an amber lapse row with a text cue, never colour alone")
    func lapseDayCarriesTextCue() throws {
        let now = Date()
        let outcomes = [
            outcome(result: .improved, daysAgo: 2, now: now),
            outcome(result: .regressed, daysAgo: 1, now: now),
            outcome(result: .improved, daysAgo: 0, now: now)
        ]
        let presentation = try #require(V46ProgressPresentation.make(
            outcomes: outcomes,
            intervention: nil,
            now: now
        ))
        let lapse = try #require(presentation.rows.first { $0.tone == .lapse })
        #expect(lapse.copy.contains("Didn't hold"))
        let lapseDay = try #require(presentation.trajectory.first { $0.isLapse })
        #expect(lapseDay.outcome == .lapse)
        #expect(presentation.trajectory.first?.outcome == .improved)
    }

    @Test("Chronology keeps the day's best while the receipt shows the actual newest attempt")
    func newestReceiptDoesNotHideALaterRegression() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_787_000_400) // fixed evening UTC
        let unpressuredImprovement = outcome(
            result: .improved,
            daysAgo: 1.10,
            difficulty: .easy,
            now: now
        )
        let pressuredRegression = outcome(
            result: .regressed,
            daysAgo: 1.05,
            difficulty: .hard,
            now: now
        )

        let presentation = try #require(V46ProgressPresentation.make(
            outcomes: [unpressuredImprovement, pressuredRegression],
            intervention: nil,
            now: now,
            calendar: calendar
        ))
        let row = try #require(presentation.rows.first)

        #expect(presentation.trajectory == [
            V46TrajectoryDay(label: "YESTERDAY", outcome: .improved)
        ])
        #expect(row.id == pressuredRegression.id)
        #expect(row.tone == .lapse)
        #expect(row.copy.contains("Didn't hold under time pressure"))
        #expect(!presentation.subtitle.contains("under pressure"))
    }

    @Test("Sparse multi-week chronology labels include a date")
    func chronologyLabelsStayUniqueAcrossRepeatedWeekdays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_787_000_400)
        let presentation = try #require(V46ProgressPresentation.make(
            outcomes: [
                outcome(result: .improved, daysAgo: 13, now: now),
                outcome(result: .held, daysAgo: 6, now: now),
                outcome(result: .improved, daysAgo: 0, now: now),
            ],
            intervention: nil,
            now: now,
            calendar: calendar
        ))
        let labels = presentation.trajectory.map(\.label)

        #expect(Set(labels).count == labels.count)
        #expect(labels.filter { $0 != "TODAY" && $0 != "YESTERDAY" }.allSatisfy { label in
            label.contains { character in character.isNumber }
        })
    }

    @Test("Below three comparable reps the head stays an early read")
    func earlyReadFloor() throws {
        let now = Date()
        let presentation = try #require(V46ProgressPresentation.make(
            outcomes: [outcome(result: .improved, daysAgo: 0, now: now)],
            intervention: nil,
            now: now
        ))
        #expect(presentation.headline == "Early read.")
        #expect(presentation.readStage == .early)
        #expect(presentation.coachReadEyebrow == "COACH READ · LAST 1 REP")
        #expect(presentation.authoredHeadline == "An early read on your opening.")
        #expect(presentation.subtitle.contains("more for a reliable read"))
    }

    @Test("Opening and closing retries never combine into one reliability claim")
    func cohortsByLatestLever() throws {
        let now = Date()
        let outcomes = [
            outcome(result: .improved, daysAgo: 5, lever: .closing, now: now),
            outcome(result: .held, daysAgo: 4, lever: .closing, now: now),
            outcome(result: .improved, daysAgo: 3, lever: .closing, now: now),
            outcome(result: .held, daysAgo: 2, lever: .closing, now: now),
            outcome(result: .improved, daysAgo: 1, lever: .opening, now: now),
            outcome(result: .held, daysAgo: 0, lever: .opening, now: now),
        ]
        let presentation = try #require(V46ProgressPresentation.make(
            outcomes: outcomes,
            intervention: nil,
            now: now
        ))

        #expect(presentation.practiceTarget.lever == .opening)
        #expect(presentation.eyebrow == TranscriptPracticeLever.opening.focusLabel.uppercased())
        #expect(presentation.headline == "Early read.")
        #expect(presentation.subtitle.contains("Held in 2 of 2 comparable reps"))
        #expect(!presentation.subtitle.contains("6 comparable"))
    }

    @Test("Broken source or retry provenance cannot enter the Progress cohort")
    func rejectsBrokenComparisonJoin() {
        let now = Date()
        let mismatchedSource = outcome(
            result: .improved,
            daysAgo: 0,
            sourceSessionID: UUID(),
            comparisonSourceSessionID: UUID(),
            now: now
        )
        let mismatchedRetry = outcome(
            result: .improved,
            daysAgo: 0,
            sessionID: UUID(),
            comparisonRetrySessionID: UUID(),
            now: now
        )

        #expect(V46ProgressPresentation.make(
            outcomes: [mismatchedSource],
            intervention: nil,
            now: now
        ) == nil)
        #expect(V46ProgressPresentation.make(
            outcomes: [mismatchedRetry],
            intervention: nil,
            now: now
        ) == nil)
    }

    @Test("Practice target requires the exact qualified prompt-backed cohort row")
    func targetPracticeFailsClosedWithoutExactPrompt() throws {
        let now = Date()
        let sourceSessionID = UUID()
        let retrySessionID = UUID()
        let outcome = outcome(
            result: .improved,
            daysAgo: 0,
            lever: .opening,
            sourceSessionID: sourceSessionID,
            sessionID: retrySessionID,
            now: now
        )
        let presentation = try #require(V46ProgressPresentation.make(
            outcomes: [outcome],
            intervention: nil,
            now: now
        ))
        let source = PracticeSession(
            id: sourceSessionID,
            transcript: "I recommend the launch today because the evidence is ready and the owner is clear.",
            fillerWordCount: 0,
            duration: 30,
            date: now,
            mode: .timed,
            score: 8,
            prompt: "Should we launch today?"
        )

        let projection = try #require(V46ProgressPracticeProjection.make(
            target: presentation.practiceTarget,
            sessions: [source]
        ))
        #expect(presentation.practiceTarget.sourceSessionID == sourceSessionID)
        #expect(presentation.practiceTarget.sourceSessionID != retrySessionID)
        #expect(projection.sourceSessionID == sourceSessionID)
        #expect(projection.suggestedPrompt == "Should we launch today?")
        #expect(projection.retryTarget.lever == .opening)
        #expect(
            V46ProgressPracticeProjection.make(
                target: presentation.practiceTarget,
                sessions: []
            ) == nil
        )

        let promptless = PracticeSession(
            id: sourceSessionID,
            transcript: source.transcript,
            fillerWordCount: 0,
            duration: 30,
            date: now,
            mode: .timed,
            score: 8,
            prompt: nil
        )
        #expect(
            V46ProgressPracticeProjection.make(
                target: presentation.practiceTarget,
                sessions: [promptless]
            ) == nil
        )
    }

    @Test("Progress mounts one route-owned practice target action")
    func practiceActionUsesExistingOwnersOnce() throws {
        let source = try progressViewSource
        #expect(source.components(separatedBy: "\"Practice this target\"").count - 1 == 1)
        #expect(source.contains("PrimaryCTA("))
        #expect(source.contains("V46ProgressPracticeProjection.make("))
        #expect(source.contains("offerTranscriptRetryToken(prescription)"))
        #expect(source.contains("recommendationLearningStore.recordShown("))
        #expect(source.contains("recommendationLearningStore.markTapped(mode: .timed)"))
        #expect(source.contains("AppDestination.timedPracticePrompt(token: token)"))
        #expect(source.contains(".accessibilityIdentifier(\"progress.v46.practiceTarget\")"))
        #expect(source.contains(".accessibilityIdentifier(\"progress.v46.evidenceDisclosure\")"))
    }

    @Test("Progress graphics describe evidence instead of repeating voice bars")
    func progressUsesAnHonestProofChronology() throws {
        let source = try progressViewSource

        #expect(!source.contains("NoumWaveformMark("))
        #expect(!source.contains("VoiceTraceDayCluster("))
        #expect(!source.contains("trajectoryHeights("))
        #expect(source.contains("Image(systemName: \"scope\")"))
        #expect(source.contains("v46ProofChronology(presentation)"))
        #expect(source.contains("Best result each day"))
        #expect(!source.contains("Text(presentation.evidenceValue)"))
        #expect(source.contains(".accessibilityIdentifier(\"progress.v46.chronology\")"))
        #expect(source.contains("dynamicTypeSize.isAccessibilitySize"))
        #expect(source.contains("reduceMotion || revealed"))
    }

    @Test("Earned Today fires once per un-acknowledged evidence event")
    func earnedTodayOncePerEvent() throws {
        let now = Date()
        let earned = outcome(result: .improved, daysAgo: 0.1, difficulty: .easy, now: now)
        let first = try #require(V46EarnedTodayPresentation.make(
            outcomes: [earned],
            suggestedNextDifficulty: .medium,
            acknowledgedOutcomeIDs: [],
            now: now
        ))
        #expect(first.outcomeID == earned.id)
        // The clock tightened (60s → 30s), so the hero re-speaks around it.
        #expect(first.headlineOverride == "Same target \u{2014} shorter clock.")
        #expect(first.ctaOverride == "Start the shorter clock")

        let second = V46EarnedTodayPresentation.make(
            outcomes: [earned],
            suggestedNextDifficulty: .medium,
            acknowledgedOutcomeIDs: [earned.id],
            now: now
        )
        #expect(second == nil)
    }

    @Test("Earned Today without a tightened clock keeps ordinary copy — chip only")
    func earnedTodayWithoutClockChange() throws {
        let now = Date()
        let earned = outcome(result: .held, daysAgo: 0.1, difficulty: .medium, now: now)
        let presentation = try #require(V46EarnedTodayPresentation.make(
            outcomes: [earned],
            suggestedNextDifficulty: .medium,
            acknowledgedOutcomeIDs: [],
            now: now
        ))
        #expect(presentation.headlineOverride == nil)
        #expect(presentation.ctaOverride == nil)
        #expect(presentation.chipText.contains("New evidence"))
    }

    @Test("A stale evidence event never re-announces")
    func earnedTodayWindowExpires() {
        let now = Date()
        let stale = outcome(result: .improved, daysAgo: 2, now: now)
        let presentation = V46EarnedTodayPresentation.make(
            outcomes: [stale],
            suggestedNextDifficulty: .medium,
            acknowledgedOutcomeIDs: [],
            now: now
        )
        #expect(presentation == nil)
    }
}
