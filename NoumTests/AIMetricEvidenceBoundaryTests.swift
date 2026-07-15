import Foundation
import Testing
@testable import Noum

@Suite("AI metric evidence boundary")
struct AIMetricEvidenceBoundaryTests {
    @Test("Post-rep prompt withholds unqualified current mechanics")
    func postRepPromptWithholdsUnqualifiedCurrentMechanics() {
        let inputs = [
            postRepInput(confidence: 0.49),
            postRepInput(schemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1),
            postRepInput(isEvaluationFixture: true),
            postRepInput(duration: 14, words: 30)
        ]

        for input in inputs {
            let prompt = PostRepCoachNoteService.userPrompt(from: input)
            #expect(prompt.contains("Score: 7/10"))
            #expect(prompt.contains("Duration:"))
            #expect(prompt.contains("THE QUESTION ASKED:"))
            #expect(prompt.contains("THIS REP — TRANSCRIPT"))
            #expect(prompt.contains("Baseline filler rate: 2.0 per minute"))
            #expect(prompt.contains("Baseline pace: 130 WPM"))
            #expect(!prompt.contains("Filler count:"))
            #expect(!prompt.contains("Filler rate:"))
            #expect(!prompt.contains("Word count:"))
            #expect(!prompt.contains("Current pace:"))
        }
    }

    @Test("Post-rep prompt retains independently qualified mechanics")
    func postRepPromptRetainsQualifiedMechanics() {
        let prompt = PostRepCoachNoteService.userPrompt(
            from: postRepInput(fillers: 3, duration: 30, words: 60, confidence: 0.5)
        )

        #expect(prompt.contains("Filler count: 3"))
        #expect(prompt.contains("Filler rate: 6.0 per minute"))
        #expect(prompt.contains("Word count: 60"))
        #expect(prompt.contains("Current pace: 120 WPM"))
    }

    @Test("Post-rep AI acceptance rejects only unsupported mechanic claims")
    func postRepGeneratedNoteMetricGate() {
        let withheld = postRepInput(confidence: 0.49)
        #expect(PostRepCoachNoteService.usesUnsupportedMetricClaim(
            "The revenue point landed. Four fillers weakened the close.",
            input: withheld
        ))
        #expect(PostRepCoachNoteService.usesUnsupportedMetricClaim(
            "The revenue point landed. Your pacing was rushed.",
            input: withheld
        ))
        #expect(PostRepCoachNoteService.usesUnsupportedMetricClaim(
            "The revenue point landed at 180 WPM. Pause after the opening.",
            input: withheld
        ))
        #expect(!PostRepCoachNoteService.usesUnsupportedMetricClaim(
            "The revenue point landed. Pause once before the close.",
            input: withheld
        ))
        #expect(!PostRepCoachNoteService.usesUnsupportedMetricClaim(
            "That detail was not filler; it made the recommendation concrete.",
            input: withheld
        ))

        let qualified = postRepInput(fillers: 4, duration: 30, words: 80, confidence: 0.5)
        #expect(!PostRepCoachNoteService.usesUnsupportedMetricClaim(
            "Four fillers surfaced. Pace was 160 WPM.",
            input: qualified
        ))
        #expect(PostRepCoachNoteService.usesUnsupportedMetricClaim(
            "Four fillers means pacing was rushed.",
            input: qualified
        ))
    }

    @Test("Recent post-rep summaries expose filler counts only for qualified history")
    func recentSummariesQualifyFillerCounts() {
        let qualified = session(score: 7, fillers: 3, confidence: 0.5)
        let lowConfidence = session(score: 6, fillers: 8, confidence: 0.49)
        let stale = session(
            score: 5,
            fillers: 9,
            schemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )
        let fixture = session(score: 4, fillers: 10, isEvaluationFixture: true)

        let summaries = AICoachService.recentSessionSummaries(
            sessions: [qualified, lowConfidence, stale, fixture],
            currentRepID: nil
        )
        let joined = summaries.joined(separator: "\n")

        #expect(joined.contains("3 fillers"))
        #expect(!joined.contains("8 fillers"))
        #expect(!joined.contains("9 fillers"))
        #expect(!joined.contains("10 fillers"))
        #expect(joined.contains("filler comparison withheld"))
    }

    @Test("AI Insights prompt marks weak, stale, and fixture mechanics unmeasured")
    func insightsPromptQualifiesEachRecentSession() {
        let qualified = session(score: 7, fillers: 3, confidence: 0.5)
        let lowConfidence = session(score: 6, fillers: 8, confidence: 0.49)
        let stale = session(
            score: 5,
            fillers: 9,
            schemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )
        let fixture = session(score: 4, fillers: 10, isEvaluationFixture: true)
        let prompt = AIInsightsService.userPrompt(
            from: insightInput(sessions: [qualified, lowConfidence, stale, fixture])
        )

        #expect(prompt.contains("score 7/10 | duration 30s | fillers 3 (6.0 per minute) | pace 50 WPM"))
        #expect(prompt.contains("score 6/10 | duration 30s | fillers not measured | pace not measured"))
        #expect(prompt.contains("score 5/10 | duration 30s | fillers not measured | pace not measured"))
        #expect(prompt.contains("score 4/10 | duration 30s | fillers not measured | pace not measured"))
        #expect(!prompt.contains("fillers 8"))
        #expect(!prompt.contains("fillers 9"))
        #expect(!prompt.contains("fillers 10"))
    }

    @Test("AI Insights prompt omits stale and insufficient baseline mechanics")
    func insightsPromptQualifiesBaselineMechanics() {
        var baseline = CommunicationBaseline.empty
        baseline.fillerRate.value = 4.2
        baseline.fillerRate.confidence = .moderate
        baseline.pace.value = 132
        baseline.pace.confidence = .moderate

        baseline.comparisonMetricSchemaVersion = PracticeSession.currentComparisonMetricSchemaVersion - 1
        let stalePrompt = AIInsightsService.userPrompt(
            from: insightInput(sessions: [], baseline: baseline)
        )
        #expect(stalePrompt.contains("Average score baseline:"))
        #expect(!stalePrompt.contains("Filler rate baseline:"))
        #expect(!stalePrompt.contains("Pace baseline:"))

        baseline.comparisonMetricSchemaVersion = PracticeSession.currentComparisonMetricSchemaVersion
        baseline.pace.confidence = .insufficient
        let mixedPrompt = AIInsightsService.userPrompt(
            from: insightInput(sessions: [], baseline: baseline)
        )
        #expect(mixedPrompt.contains("Filler rate baseline: 4.2 per minute"))
        #expect(!mixedPrompt.contains("Pace baseline:"))
    }

    @Test("Post-rep regeneration omits stale baseline mechanics")
    func postRepRegenerationQualifiesBaselineMechanics() {
        var baseline = CommunicationBaseline.empty
        baseline.fillerRate.value = 4.2
        baseline.fillerRate.confidence = .moderate
        baseline.pace.value = 132
        baseline.pace.confidence = .moderate
        baseline.comparisonMetricSchemaVersion = PracticeSession.currentComparisonMetricSchemaVersion - 1
        let rep = session(score: 7, fillers: 2)

        let staleInput = PracticeSessionFinalizer.regenerationInput(
            from: rep,
            newVoice: .concise,
            baseline: baseline,
            bigMoment: nil,
            bigMomentDaysUntil: nil
        )
        #expect(staleInput.baselineFillerRate == nil)
        #expect(staleInput.baselinePaceWPM == nil)

        baseline.comparisonMetricSchemaVersion = PracticeSession.currentComparisonMetricSchemaVersion
        let currentInput = PracticeSessionFinalizer.regenerationInput(
            from: rep,
            newVoice: .concise,
            baseline: baseline,
            bigMoment: nil,
            bigMomentDaysUntil: nil
        )
        #expect(currentInput.baselineFillerRate == 4.2)
        #expect(currentInput.baselinePaceWPM == 132)
    }

    @Test("AI Insights fallback never turns filler evidence into rushed pace")
    func insightsFallbackKeepsMechanicsIndependent() {
        let highFiller = session(score: 9, fillers: 6, confidence: 0.5)
        let insight = AIInsightsService.templatedFallback(
            for: insightInput(sessions: [highFiller])
        )

        #expect(insight.headline == "Fillers crept in")
        #expect(insight.body.contains("6 fillers"))
        #expect(!insight.body.lowercased().contains("rushed"))
        #expect(!insight.body.lowercased().contains("pacing was"))
    }

    @Test("AI Insights fallback does not synthesize score zero or weak mechanics")
    func insightsFallbackFailsClosedWithoutScore() {
        let weak = session(score: nil, fillers: 12, confidence: 0.49)
        let insight = AIInsightsService.templatedFallback(
            for: insightInput(sessions: [weak])
        )
        let joinedEvidence = insight.evidence.joined(separator: " ")

        #expect(insight.headline == "Rep captured")
        #expect(!joinedEvidence.contains("Score 0/10"))
        #expect(!joinedEvidence.contains("12 filler"))
        #expect(!joinedEvidence.contains("WPM"))
        #expect(!insight.body.lowercased().contains("rushed"))
    }

    @Test("AI Insights cache identity includes session metric provenance")
    func insightsCacheIdentityIncludesMetricProvenance() {
        let id = UUID()
        let current = session(id: id, score: 7, fillers: 3, confidence: 0.8)
        let stale = session(
            id: id,
            score: 7,
            fillers: 3,
            confidence: 0.8,
            schemaVersion: PracticeSession.currentComparisonMetricSchemaVersion - 1
        )
        let lowConfidence = session(id: id, score: 7, fillers: 3, confidence: 0.4)
        let fixture = session(
            id: id,
            score: 7,
            fillers: 3,
            confidence: 0.8,
            isEvaluationFixture: true
        )

        let currentKey = AIInsightsService.cacheIdentity(
            for: insightInput(sessions: [current])
        )
        #expect(currentKey != AIInsightsService.cacheIdentity(for: insightInput(sessions: [stale])))
        #expect(currentKey != AIInsightsService.cacheIdentity(for: insightInput(sessions: [lowConfidence])))
        #expect(currentKey != AIInsightsService.cacheIdentity(for: insightInput(sessions: [fixture])))
    }

    private func postRepInput(
        fillers: Int = 8,
        duration: TimeInterval = 30,
        words: Int = 60,
        confidence: Double? = 0.8,
        schemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        isEvaluationFixture: Bool = false
    ) -> PostRepCoachNoteInput {
        PostRepCoachNoteInput(
            sessionID: UUID(),
            mode: .timed,
            score: 7,
            fillerCount: fillers,
            duration: duration,
            wordCount: words,
            voice: .concise,
            intentLabel: "Lead with the answer",
            baselineFillerRate: 2,
            baselinePaceWPM: 130,
            bigMoment: nil,
            bigMomentDaysUntil: nil,
            transcript: Array(repeating: "revenue", count: max(words, 1)).joined(separator: " "),
            prompt: "What should the team do next?",
            transcriptConfidence: confidence,
            comparisonMetricSchemaVersion: schemaVersion,
            isEvaluationFixture: isEvaluationFixture
        )
    }

    private func session(
        id: UUID = UUID(),
        score: Int?,
        fillers: Int,
        confidence: Double? = 0.8,
        schemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        isEvaluationFixture: Bool = false
    ) -> PracticeSession {
        PracticeSession(
            id: id,
            transcript: Array(repeating: "word", count: 25).joined(separator: " "),
            fillerWordCount: fillers,
            duration: 30,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            mode: .timed,
            score: score,
            transcriptConfidence: confidence,
            comparisonMetricSchemaVersion: schemaVersion,
            isEvaluationFixture: isEvaluationFixture
        )
    }

    private func insightInput(
        sessions: [PracticeSession],
        baseline: CommunicationBaseline = .empty
    ) -> AIInsightInput {
        AIInsightInput(
            kind: .sessionDebrief,
            sessions: sessions,
            baseline: baseline,
            rating: SpeakingRating(
                overall: 1_200,
                peakRating: 1_200,
                ratingHistory: [],
                personalBests: [],
                totalRatedSessions: 0
            ),
            weeklyDelta: 0,
            weeklyReps: sessions.count,
            topFillerWord: nil,
            goalParaphrase: nil,
            currentStreak: 0,
            goalDistance: nil
        )
    }
}
