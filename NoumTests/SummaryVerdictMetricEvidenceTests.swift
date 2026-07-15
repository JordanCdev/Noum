import Foundation
import Testing
@testable import Noum

@Suite("Summary verdict metric evidence")
struct SummaryVerdictMetricEvidenceTests {
    @Test("Summary metric resolution uses only the finalized session identifier")
    func summaryMetricResolutionUsesExactIdentity() {
        let intended = session(words: 60, duration: 30, fillers: 0)
        let newerButUnrelated = session(words: 60, duration: 30, fillers: 12)

        let resolved = SummaryMetricSessionResolver.resolve(
            finalizedSessionID: intended.id,
            storedSessions: [newerButUnrelated, intended]
        )
        let unidentified = SummaryMetricSessionResolver.resolve(
            finalizedSessionID: nil,
            storedSessions: [newerButUnrelated, intended]
        )
        let missing = SummaryMetricSessionResolver.resolve(
            finalizedSessionID: UUID(),
            storedSessions: [newerButUnrelated, intended]
        )
        let notPersisted = SummaryMetricSessionResolver.resolve(
            finalizedSessionID: intended.id,
            storedSessions: []
        )

        #expect(resolved?.id == intended.id)
        #expect(unidentified == nil)
        #expect(missing == nil)
        #expect(notPersisted == nil)
    }

    @Test("Unidentified Summary cannot borrow recency for stored evidence or filler judgment")
    func unidentifiedSummaryFailsClosed() {
        let unrelated = session(words: 60, duration: 30, fillers: 12)
        let resolved = SummaryMetricSessionResolver.resolve(
            finalizedSessionID: nil,
            storedSessions: [unrelated]
        )
        let fillerPresentation = SummaryFillerPresentation.make(
            metricSession: resolved,
            fallbackFillerCount: 12,
            fallbackDuration: 30,
            previousSessions: [unrelated, unrelated, unrelated]
        )

        #expect(resolved == nil)
        #expect(fillerPresentation.currentRatePerMinute == nil)
        #expect(fillerPresentation.comparison == nil)
        #expect(fillerPresentation.tone == .insufficient)
        #expect(fillerPresentation.accessibilityLabel.contains("Not enough speech for a fair filler-rate comparison"))
    }

    @MainActor
    @Test("Nil and unmatched Summary identifiers cannot start finalization side effects")
    func unresolvedSummaryCannotFinalize() {
        let profile = ProfileManager.shared
        let trendStore = SkillTrendStore.shared
        let previousXP = profile.xp
        let previousSnapshotCount = trendStore.snapshots.count
        let transcript = Array(repeating: "word", count: 60).joined(separator: " ")

        for unresolvedID in [UUID?.none, UUID()] {
            let result = SessionFinalizer.finalize(
                xpEarned: 100,
                scoreValue: 8,
                effectiveFillerCount: 8,
                effectiveDuration: 30,
                transcriptWordCount: 60,
                scoreBreakdown: [],
                currentMode: .timed,
                sessionPrompt: nil,
                latestSessionID: unresolvedID,
                recentSessions: PracticeSessionStore.shared.sessions,
                imConversationDetails: nil,
                practiceTitle: PracticeMode.timed.displayLabel,
                derivedInsightsFirst: nil,
                transcript: transcript
            )

            #expect(result.previousXP == result.newXP)
            #expect(result.nextAction == nil)
            #expect(result.coachNote == nil)
            #expect(result.achievementDeltas.isEmpty)
        }

        #expect(profile.xp == previousXP)
        #expect(trendStore.snapshots.count == previousSnapshotCount)
    }

    @MainActor
    @Test("Pause trend rate keeps the exact row's duration when payload duration differs")
    func pauseRateUsesExactSessionDuration() {
        let payloadDuration: TimeInterval = 30
        let exactSession = session(
            words: 60,
            duration: 60,
            fillers: 0,
            pauseMetrics: PauseMetrics(
                count: 6,
                meanSeconds: 0.8,
                longestSeconds: 1.2,
                filledRatio: 0
            )
        )

        #expect(payloadDuration != exactSession.duration)
        #expect(SessionFinalizer.pauseRateForTrend(session: exactSession) == 6)
    }

    @Test("Verdict withholds current filler and pace claims for every invalid evidence class")
    func verdictWithholdsInvalidMechanics() {
        let invalid = [
            session(words: 10, duration: 30, fillers: 8),
            session(words: 25, duration: 10, fillers: 8),
            session(words: 25, duration: 30, fillers: 8, confidence: 0.49),
            session(
                words: 25,
                duration: 30,
                fillers: 8,
                schemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
            ),
            session(words: 25, duration: 30, fillers: 8, isEvaluationFixture: true),
        ]

        for sample in invalid {
            let fillerNote = verdict(focus: .fillerReduction, session: sample)
            let paceNote = verdict(focus: .paceControl, session: sample)
            let combined = [
                fillerNote.momentum, fillerNote.leverage, fillerNote.nextStep,
                paceNote.momentum, paceNote.leverage, paceNote.nextStep,
            ].joined(separator: " ").lowercased()

            #expect(fillerNote.leverage.contains("not measured"))
            #expect(paceNote.leverage.contains("not measured"))
            #expect(!combined.contains("8 filler"))
            #expect(!combined.contains("zero filler"))
            #expect(!combined.contains("/min"))
            #expect(!combined.contains("wpm"))
            #expect(!combined.contains("natural, well-controlled pace"))
        }
    }

    @Test("Verdict retains independently qualified filler and pace evidence")
    func verdictRetainsQualifiedMechanics() {
        let clean = session(words: 60, duration: 30, fillers: 0, confidence: 0.5)
        let note = verdict(focus: .structure, session: clean)

        #expect(note.momentum.lowercased().contains("zero filler"))
        #expect(note.momentum.lowercased().contains("pace"))
    }

    @Test("Verdict mechanics come from the saved row rather than raw presentation scalars")
    func verdictUsesSavedRowMechanics() {
        let saved = session(words: 60, duration: 30, fillers: 2)
        let note = VerdictEngine.generate(
            fillerCount: 99,
            duration: 1,
            wordCount: 1,
            wpm: 999,
            score: 7,
            categoryRatings: [:],
            trends: [],
            primaryFocus: .paceControl,
            drillHistory: [],
            metricSession: saved
        )
        let combined = [note.momentum, note.leverage, note.nextStep]
            .joined(separator: " ")
            .lowercased()

        #expect(!combined.contains("99 filler"))
        #expect(!combined.contains("999 wpm"))
        #expect(note.momentum.contains("Natural, well-controlled pace"))
    }

    @Test("Verdict fails closed when no exact saved row or score exists")
    func verdictRequiresExactSavedEvidence() {
        let note = VerdictEngine.generate(
            fillerCount: 99,
            duration: 30,
            wordCount: 60,
            wpm: 999,
            score: nil,
            categoryRatings: [:],
            trends: [],
            primaryFocus: .paceControl,
            drillHistory: []
        )
        let combined = [note.momentum, note.leverage, note.nextStep]
            .joined(separator: " ")
            .lowercased()

        #expect(note.leverage.contains("not measured"))
        #expect(!combined.contains("99 filler"))
        #expect(!combined.contains("999 wpm"))
        #expect(!note.momentum.contains("Solid session overall"))
    }

    @Test("Qualified zero-filler leverage does not invent stray fillers")
    func zeroFillerLeverageIsAccurate() {
        let clean = session(words: 40, duration: 30, fillers: 0)
        let note = verdict(focus: .fillerReduction, session: clean)

        #expect(note.leverage.contains("No filler words were detected"))
        #expect(!note.leverage.lowercased().contains("a few filler"))
    }

    @Test("Long low-rate reps do not turn absolute filler counts into a problem claim")
    func lowRateFillerCountStaysNonCorrective() {
        let longLowRate = session(words: 600, duration: 600, fillers: 2)
        let note = verdict(focus: .fillerReduction, session: longLowRate)
        let bullets = fixBullets(session: longLowRate)

        #expect(note.leverage.contains("stayed low"))
        #expect(!note.leverage.contains("above target"))
        #expect(!note.leverage.lowercased().contains("crept in"))
        #expect(!bullets.contains { $0.id == "filler" })
    }

    @Test("Unqualified mechanics do not suppress score and category coaching")
    func verdictPreservesIndependentEvidence() {
        let weakMechanics = session(words: 25, duration: 30, fillers: 8, score: 8, confidence: 0.49)
        let scoreNote = VerdictEngine.generate(
            fillerCount: weakMechanics.fillerWordCount,
            duration: weakMechanics.duration,
            wordCount: weakMechanics.wordCount,
            wpm: Double(weakMechanics.wordsPerMinute),
            score: 8,
            categoryRatings: [:],
            trends: [],
            primaryFocus: .structure,
            drillHistory: [],
            metricSession: weakMechanics
        )
        let categoryNote = VerdictEngine.generate(
            fillerCount: weakMechanics.fillerWordCount,
            duration: weakMechanics.duration,
            wordCount: weakMechanics.wordCount,
            wpm: Double(weakMechanics.wordsPerMinute),
            score: nil,
            categoryRatings: ["Opening": "Good", "Structure": "Good", "Depth": "Good"],
            trends: [],
            primaryFocus: .structure,
            drillHistory: [],
            metricSession: weakMechanics
        )

        #expect(scoreNote.momentum.contains("Solid session overall"))
        #expect(categoryNote.momentum.contains("Solid performance"))
        #expect(categoryNote.leverage.lowercased().contains("structure"))
        #expect(!scoreNote.momentum.lowercased().contains("filler"))
        #expect(!scoreNote.momentum.lowercased().contains("pace"))
        #expect(!categoryNote.momentum.lowercased().contains("filler"))
        #expect(!categoryNote.momentum.lowercased().contains("pace"))
    }

    @Test("Fix bullets withhold invalid filler and pace mechanics")
    func fixBulletsWithholdInvalidMechanics() {
        let invalid = [
            session(words: 10, duration: 30, fillers: 8),
            session(words: 25, duration: 10, fillers: 8),
            session(words: 25, duration: 30, fillers: 8, confidence: 0.49),
            session(
                words: 25,
                duration: 30,
                fillers: 8,
                schemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
            ),
            session(words: 25, duration: 30, fillers: 8, isEvaluationFixture: true),
        ]

        for sample in invalid {
            let bullets = fixBullets(session: sample)
            #expect(!bullets.contains { $0.id == "filler" })
            #expect(!bullets.contains { $0.id.hasPrefix("pace-") })
        }
    }

    @Test("Fix bullets retain qualified filler and pace mechanics from the saved row")
    func fixBulletsRetainQualifiedMechanics() {
        let qualified = session(words: 60, duration: 20, fillers: 5)
        let bullets = fixBullets(session: qualified)

        #expect(bullets.contains { $0.id == "filler" })
        #expect(bullets.contains { $0.id == "pace-fast" })
        #expect(bullets.first(where: { $0.id == "filler" })?.headline.contains("5") == true)
        #expect(bullets.first(where: { $0.id == "pace-fast" })?.headline.contains("180 WPM") == true)
    }

    private func verdict(
        focus: SkillArea,
        session: PracticeSession
    ) -> CoachNote {
        VerdictEngine.generate(
            fillerCount: session.fillerWordCount,
            duration: session.duration,
            wordCount: session.wordCount,
            wpm: Double(session.wordsPerMinute),
            score: session.score ?? 7,
            categoryRatings: [:],
            trends: [],
            primaryFocus: focus,
            drillHistory: [],
            metricSession: session
        )
    }

    private func fixBullets(session: PracticeSession) -> [WhatToImproveCard.Bullet] {
        WhatToImproveCard.computeBullets(
            coachNote: CoachNote(momentum: "", leverage: "", nextStep: ""),
            feedbackCategories: [],
            aiFeedback: nil,
            transcriptText: session.transcript,
            effectiveFillerCount: session.fillerWordCount,
            effectiveDuration: session.duration,
            transcriptWordCount: session.wordCount,
            isMinimalEffort: false,
            customFillerWords: [],
            metricSession: session
        )
    }

    private func session(
        words: Int,
        duration: TimeInterval,
        fillers: Int,
        score: Int? = 7,
        confidence: Double? = 0.8,
        schemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        isEvaluationFixture: Bool = false,
        pauseMetrics: PauseMetrics? = nil
    ) -> PracticeSession {
        PracticeSession(
            transcript: Array(repeating: "word", count: words).joined(separator: " "),
            fillerWordCount: fillers,
            duration: duration,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            mode: .timed,
            score: score,
            transcriptConfidence: confidence,
            comparisonMetricSchemaVersion: schemaVersion,
            pauseMetrics: pauseMetrics,
            isEvaluationFixture: isEvaluationFixture
        )
    }
}
