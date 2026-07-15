import Foundation
import Testing
@testable import Noum

@Suite("Generated Coach Read evidence boundary")
struct GeneratedCoachReadMetricEvidenceTests {
    @Test("Exact saved source builds a mechanic-free Coach Read prompt")
    func promptUsesExactSourceWithoutFreeFormMechanics() {
        let saved = session(words: 60, duration: 30, fillers: 4, score: 8)
        let prompt = AICoachService.userPrompt(
            input: coachInput(session: saved),
            profile: nil,
            plan: nil,
            baselineContext: "Typical duration: 45s"
        )

        #expect(prompt.contains("Score: 8/10"))
        #expect(prompt.contains("Duration: 30s"))
        #expect(prompt.contains(saved.transcript))
        #expect(prompt.contains("Typical duration: 45s"))
        #expect(!prompt.lowercased().contains("filler"))
        #expect(!prompt.lowercased().contains("pace"))
        #expect(!prompt.lowercased().contains("wpm"))
    }

    @Test("Fallback never turns any evidence class into free-form mechanics")
    func fallbackWithholdsMechanicsForEveryEvidenceClass() {
        let samples = [
            session(words: 19, duration: 30, fillers: 8),
            session(words: 30, duration: 14, fillers: 8),
            session(words: 30, duration: 30, fillers: 8, confidence: 0.49),
            session(
                words: 30,
                duration: 30,
                fillers: 8,
                schemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
            ),
            session(words: 30, duration: 30, fillers: 8, isEvaluationFixture: true),
            session(words: 60, duration: 30, fillers: 4),
        ]

        for sample in samples {
            let feedback = AICoachService.deterministicFeedback(
                input: coachInput(session: sample)
            )
            #expect(!AICoachService.usesUnsupportedMetricClaim(
                feedback,
                transcript: sample.transcript
            ))
            let text = allText(in: feedback).lowercased()
            #expect(!text.contains("filler"))
            #expect(!text.contains(" wpm"))
            #expect(!text.contains("pace"))
        }
    }

    @Test("Observed mechanic claims fail even when the source row qualifies")
    func outputGateRejectsObservedMechanicsAndComparisons() {
        let transcript = Array(repeating: "revenue", count: 60).joined(separator: " ")
        let claims = [
            feedback(improvement: "No fillers appeared in this rep."),
            feedback(improvement: "Four fillers appeared in 30 seconds at 8.0 per minute."),
            feedback(improvement: "The rep averaged 120 WPM."),
            feedback(improvement: "Your pacing was rushed around the revenue point."),
            feedback(improvement: "Repeated ums weakened the close."),
            feedback(improvement: "You spoke quickly through the recommendation."),
            feedback(improvement: "The tempo accelerated after the revenue point."),
            feedback(improvement: "Your cadence slowed at the close."),
            feedback(improvement: "Your filler rate was below your usual."),
            feedback(improvement: "The fillers show the pacing was rushed."),
        ]

        for claim in claims {
            #expect(AICoachService.usesUnsupportedMetricClaim(
                claim,
                transcript: transcript
            ))
        }
    }

    @Test("Semantic language and generic prescriptions remain available")
    func outputGatePreservesNonObservationalCoaching() {
        let transcript = Array(repeating: "revenue", count: 30).joined(separator: " ")
        let safe = [
            feedback(improvement: "That revenue detail was not filler; it made the recommendation concrete."),
            feedback(drill: "Run the filler-control drill once before the next rep."),
            feedback(drill: "Try a slower pace next time, then listen back for clarity."),
            feedback(drill: "Pause once before the final sentence."),
        ]

        for candidate in safe {
            #expect(!AICoachService.usesUnsupportedMetricClaim(
                candidate,
                transcript: transcript
            ))
        }
    }

    @Test("Legacy replay hides mechanic prose but keeps grounded nonmetric coaching")
    func legacyReplayFailsClosedSelectively() {
        let weakUnsafe = session(
            words: 30,
            duration: 30,
            fillers: 8,
            confidence: 0.49,
            aiFeedback: feedback(improvement: "Your pacing was rushed around the revenue point.")
        )
        let qualifiedUnsafe = session(
            words: 60,
            duration: 30,
            fillers: 4,
            aiFeedback: feedback(improvement: "The rep averaged 120 WPM.")
        )
        let grounded = session(
            words: 30,
            duration: 30,
            fillers: 8,
            confidence: 0.49,
            aiFeedback: feedback(improvement: "The revenue point needs a cleaner close.")
        )

        #expect(weakUnsafe.evidenceSafeAICoachFeedback == nil)
        #expect(qualifiedUnsafe.evidenceSafeAICoachFeedback == nil)
        #expect(grounded.evidenceSafeAICoachFeedback != nil)
    }

    @Test("Coach Read baseline context excludes mechanics but retains independent facts")
    func baselinePromptCanExcludeComparisonMechanics() {
        var baseline = CommunicationBaseline.empty
        baseline.sessionCount = 5
        baseline.qualifyingSessionCount = 5
        baseline.comparisonMetricSchemaVersion = PracticeSession.currentComparisonMetricSchemaVersion
        baseline.fillerRate.value = 4.2
        baseline.fillerRate.confidence = .moderate
        baseline.pace.value = 132
        baseline.pace.confidence = .moderate
        baseline.durationTendency.value = 48
        baseline.durationTendency.confidence = .moderate

        let coachReadContext = BaselineEngine.promptContext(
            baseline: baseline,
            pressure: .empty,
            includeComparisonMechanics: false
        )
        #expect(coachReadContext.contains("Typical duration: 48s"))
        #expect(!coachReadContext.contains("Filler rate:"))
        #expect(!coachReadContext.contains("Pace:"))

        let generalContext = BaselineEngine.promptContext(
            baseline: baseline,
            pressure: .empty
        )
        #expect(generalContext.contains("Filler rate: 4.2/min"))
        #expect(generalContext.contains("Pace: 132 WPM"))
    }

    @Test("Mechanic-free baseline context removes derivative history and pressure reads")
    func baselinePromptExcludesDerivativeMechanics() {
        var baseline = CommunicationBaseline.empty
        baseline.sessionCount = 12
        baseline.qualifyingSessionCount = 12
        baseline.comparisonMetricSchemaVersion = PracticeSession.currentComparisonMetricSchemaVersion
        baseline.fillerRate = stat(4.2)
        baseline.pace = stat(132)
        baseline.durationTendency = stat(48)
        baseline.averageScore = stat(7.2)
        baseline.structureQuality = stat(2.6)
        baseline.clutchWordFrequencies = ["um": stat(2.4)]
        baseline.topStrengths = ["Filler control", "Pace control", "Cadence stability", "Structure"]
        baseline.persistentBlockers = ["Filler words", "Tempo control", "Opening strength"]

        let pressure = PressureProfile(
            casualFillerRate: stat(1),
            highFillerRate: stat(5),
            casualPace: stat(120),
            highPace: stat(170),
            casualScore: stat(9),
            highScore: stat(6),
            casualDuration: stat(60),
            highDuration: stat(40),
            casualStructure: stat(2.8),
            highStructure: stat(1.5)
        )

        let coachReadContext = BaselineEngine.promptContext(
            baseline: baseline,
            pressure: pressure,
            currentPressureLevel: .high,
            includeComparisonMechanics: false
        )
        let mechanicFree = coachReadContext.lowercased()

        #expect(coachReadContext.contains("Typical duration: 48s"))
        #expect(coachReadContext.contains("Average score: 7.2/10"))
        #expect(coachReadContext.contains("Structure: strong (2.6/3)"))
        #expect(coachReadContext.contains("Consistent strengths: Structure"))
        #expect(coachReadContext.contains("Persistent blockers: Opening strength"))
        #expect(coachReadContext.contains("Most affected under pressure: Answer length"))
        #expect(coachReadContext.contains("answers are 20s shorter"))
        #expect(coachReadContext.contains("score drops by 3.0 points"))
        #expect(!coachReadContext.contains("Pressure resilience:"))
        #expect(!coachReadContext.contains("Verbal habits"))
        #expect(!coachReadContext.contains("\"um\""))
        #expect(!coachReadContext.contains("~2.4x/session"))
        for forbidden in ["filler", "pace", "pacing", "wpm", "tempo", "cadence"] {
            #expect(!mechanicFree.contains(forbidden))
        }

        let generalContext = BaselineEngine.promptContext(
            baseline: baseline,
            pressure: pressure,
            currentPressureLevel: .high
        )
        #expect(generalContext.contains("Filler rate: 4.2/min"))
        #expect(generalContext.contains("Pace: 132 WPM"))
        #expect(generalContext.contains("Consistent strengths: Filler control, Pace control, Cadence stability, Structure"))
        #expect(generalContext.contains("Persistent blockers: Filler words, Tempo control, Opening strength"))
        #expect(generalContext.contains("Verbal habits (clutch words): \"um\" (~2.4x/session)"))
        #expect(generalContext.contains("Pressure resilience:"))
        #expect(generalContext.contains("Most affected under pressure: Speaking pace"))
        #expect(generalContext.contains("Your filler rate jumps"))
        #expect(generalContext.contains("Your pace accelerates by 50 WPM"))
    }

    @Test("Recent Coach Read continuity carries no historical mechanics")
    func recentContinuityIsScoreOnly() {
        let current = session(words: 60, duration: 30, fillers: 9, score: 9)
        let prior = session(words: 60, duration: 30, fillers: 4, score: 7)
        let summaries = AICoachService.recentCoachReadSummaries(
            sessions: [current, prior],
            currentRepID: current.id
        )

        #expect(summaries == ["Timed Practice | score 7/10"])
        #expect(!summaries.joined().lowercased().contains("filler"))
        #expect(!summaries.joined().lowercased().contains("pace"))
    }

    @Test("Save token rejects account or source mutation after suspension")
    func saveTokenIsCompareAndSwapRevision() {
        let id = UUID()
        let base = session(
            id: id,
            transcript: "revenue should lead because the recommendation needs one clear decision today",
            duration: 30,
            fillers: 4,
            score: 7,
            prompt: "What should lead the recommendation?"
        )
        let token = CoachReadSaveToken(
            accountScope: "account-a",
            source: base.coachReadSourceSnapshot
        )

        #expect(token.matches(accountScope: "account-a", session: base))
        #expect(!token.matches(accountScope: "account-b", session: base))

        let changed = [
            session(id: UUID(), transcript: base.transcript, duration: 30, fillers: 4, score: 7, prompt: base.prompt),
            session(id: id, transcript: base.transcript + " now", duration: 30, fillers: 4, score: 7, prompt: base.prompt),
            session(id: id, transcript: base.transcript, duration: 30, fillers: 4, mode: .suddenDeath, score: 7, prompt: base.prompt),
            session(id: id, transcript: base.transcript, duration: 30, fillers: 4, score: 8, prompt: base.prompt),
            session(id: id, transcript: base.transcript, duration: 30, fillers: 4, score: 7, prompt: "A different prompt"),
            session(id: id, transcript: base.transcript, duration: 30, fillers: 5, score: 7, prompt: base.prompt),
            session(id: id, transcript: base.transcript, duration: 31, fillers: 4, score: 7, prompt: base.prompt),
            session(id: id, transcript: base.transcript, duration: 30, fillers: 4, score: 7, prompt: base.prompt, confidence: 0.7),
            session(id: id, transcript: base.transcript, duration: 30, fillers: 4, score: 7, prompt: base.prompt, schemaVersion: 1),
            session(id: id, transcript: base.transcript, duration: 30, fillers: 4, score: 7, prompt: base.prompt, isEvaluationFixture: true),
        ]
        for mutation in changed {
            #expect(!token.matches(accountScope: "account-a", session: mutation))
        }
    }

    @Test("Provider quote gate accepts exact source quotes and rejects fabrication")
    func quoteVerificationUsesExactTranscript() {
        let transcript = "Revenue should lead the recommendation because the board needs one clear decision today."
        let verified = feedback(
            strength: "You opened with 'Revenue should lead the recommendation' — that set the frame.",
            improvement: "The revenue close needs one clearer decision.",
            opening: "Open with 'The recommendation is to hold.'"
        )
        let fabricated = feedback(
            strength: "You opened with 'Profit should lead the recommendation' — that set the frame.",
            improvement: "The revenue close needs one clearer decision."
        )

        #expect(AICoachService.hasVerifiedTranscriptQuote(verified, transcript: transcript))
        #expect(!AICoachService.hasVerifiedTranscriptQuote(fabricated, transcript: transcript))
    }

    private func coachInput(session: PracticeSession) -> AICoachSessionInput {
        AICoachSessionInput(
            transcript: session.transcript,
            mode: session.mode,
            score: session.score,
            duration: session.duration,
            speakingIdentity: "Developing speaker",
            prompt: session.prompt ?? ""
        )
    }

    private func session(
        id: UUID = UUID(),
        words: Int = 0,
        transcript: String? = nil,
        duration: TimeInterval,
        fillers: Int,
        mode: PracticeMode = .timed,
        score: Int? = 7,
        prompt: String? = nil,
        confidence: Double? = 0.8,
        schemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        isEvaluationFixture: Bool = false,
        aiFeedback: AICoachFeedback? = nil
    ) -> PracticeSession {
        let resolvedTranscript = transcript
            ?? Array(repeating: "revenue", count: words).joined(separator: " ")
        return PracticeSession(
            id: id,
            transcript: resolvedTranscript,
            fillerWordCount: fillers,
            duration: duration,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            mode: mode,
            score: score,
            aiCoachFeedback: aiFeedback,
            prompt: prompt,
            transcriptConfidence: confidence,
            comparisonMetricSchemaVersion: schemaVersion,
            isEvaluationFixture: isEvaluationFixture
        )
    }

    private func feedback(
        strength: String = "The revenue point was specific.",
        improvement: String = "Tighten the revenue close.",
        drill: String = "Repeat the revenue point in one sentence.",
        opening: String = "Revenue should lead the recommendation."
    ) -> AICoachFeedback {
        AICoachFeedback(
            strengths: [strength, "The example supported the point."],
            keyImprovement: improvement,
            suggestedDrill: drill,
            revisedOpening: opening
        )
    }

    private func stat(_ value: Double) -> BaselineStat {
        BaselineStat(
            value: value,
            sampleCount: 12,
            confidence: .established,
            trend: .stable,
            percentile25: value,
            percentile75: value
        )
    }

    private func allText(in feedback: AICoachFeedback) -> String {
        (feedback.strengths + [
            feedback.keyImprovement,
            feedback.suggestedDrill,
            feedback.revisedOpening,
        ]).joined(separator: " ")
    }
}
