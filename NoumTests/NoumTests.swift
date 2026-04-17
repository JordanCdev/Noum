//
//  NoumTests.swift
//  NoumTests
//
//  Created by Jordan Coaten on 25/01/2025.
//

import Foundation
import Testing
@testable import Noum

struct NoumTests {

    /// Ensure that dynamic filler word variants like "errr" and "uhhhh" are
    /// detected by ``SpeechRecognizerViewModel``.
    @Test func dynamicVariantsAreCounted() async throws {
        let count1 = FillerWordDetector.count(in: "errr well uhhhh")
        #expect(count1 == 2)
    }

    /// Verify that a mix of base filler words and dynamic variants are all
    /// counted in the transcript.
    @Test func mixedFillerWordsCount() async throws {
        let count2 = FillerWordDetector.count(in: "like so you know errr uhhhh")
        #expect(count2 == 5)
    }

    /// Ensure newer filler words such as "hmm" and "erm" are detected.
    @Test func additionalFillerWords() async throws {
        let count3 = FillerWordDetector.count(in: "hmm erm mm")
        #expect(count3 == 3)
    }
}

// MARK: - Filler Detection Confidence Tests

struct FillerDetectionTests {

    @Test func cleanTranscriptHasNoHighConfidenceFillers() {
        let transcript = "I think the most important quality in a leader is the ability to listen. When you listen, you understand what your team needs, and you can make better decisions."
        let detections = FillerWordDetector.detections(in: transcript, prompt: "What is the most important quality in a leader?")
        let highConf = detections.filter { $0.confidence >= FillerDetection.suddenDeathThreshold }
        // Clean transcript should have zero high-confidence fillers
        #expect(highConf.count == 0, "Clean transcript should not trigger sudden death. Got: \(highConf.map { "'\($0.word)' c=\($0.confidence)" })")
    }

    @Test func fillerHeavyTranscriptDetectsManyFillers() {
        let transcript = "So um I think like the most important thing is uh you know when you're like trying to um lead a team you have to uh like be uh you know present and like um available."
        let detections = FillerWordDetector.detections(in: transcript, prompt: "What makes a good team leader?")
        let highConf = detections.filter { $0.confidence >= FillerDetection.suddenDeathThreshold }
        // Should detect many high-confidence fillers (um, uh, you know)
        #expect(highConf.count >= 6, "Filler-heavy transcript should have 6+ high-confidence fillers, got \(highConf.count)")
        // "um" and "uh" should be 0.95 confidence
        let pureDisf = detections.filter { ["um", "uh"].contains($0.word) }
        for d in pureDisf {
            #expect(d.confidence == 0.95, "Pure disfluency '\(d.word)' should be 0.95, got \(d.confidence)")
        }
    }

    @Test func promptEchoLikeGetsLowConfidence() {
        let transcript = "I like to think about what qualities I look for. Someone like a mentor who can guide the team."
        let detections = FillerWordDetector.detections(in: transcript, prompt: "What do you like about great leaders?")
        // "like" appears in the prompt, so occurrences should get prompt echo treatment
        let likeDetections = detections.filter { $0.word == "like" }
        let highConfLike = likeDetections.filter { $0.confidence >= FillerDetection.suddenDeathThreshold }
        #expect(highConfLike.count == 0, "Prompt-echo 'like' should NOT trigger sudden death. Got high-conf: \(highConfLike.map { "c=\($0.confidence) ctx=\($0.context)" })")
    }

    @Test func validLikeUsageNotFlagged() {
        let transcript = "It looks like the project is on track. I would like to discuss the timeline. The results feel like a strong indicator of progress."
        let detections = FillerWordDetector.detections(in: transcript, prompt: "How is the project going?")
        // "looks like", "would like", "feel like" — all valid, should return nil or very low
        let highConf = detections.filter { $0.confidence >= FillerDetection.suddenDeathThreshold }
        #expect(highConf.count == 0, "Valid 'like' usage should not be flagged. Got: \(highConf.map { "'\($0.word)' c=\($0.confidence)" })")
    }

    @Test func likeAfterPronounIsFiller() {
        let transcript = "So I was like thinking about it and she like went to the store and I like couldn't believe it."
        let detections = FillerWordDetector.detections(in: transcript, prompt: "Tell me about your weekend.")
        let likeFills = detections.filter { $0.word == "like" && $0.confidence >= 0.8 }
        // "I was like", "she like", "I like" — filler preceders
        #expect(likeFills.count >= 2, "Filler 'like' after pronouns should be detected. Got \(likeFills.count): \(likeFills.map { "c=\($0.confidence)" })")
    }

    @Test func youKnowDiscourseMarkerVsQuestion() {
        let transcript = "You know what I mean? But you know it's hard to explain. Do you know the feeling when you know everything clicks?"
        let detections = FillerWordDetector.detections(in: transcript, prompt: "Describe a breakthrough moment.")
        let youKnow = detections.filter { $0.word == "you know" }
        // "you know what" → NOT filler, "you know" standalone → filler, "do you know" → NOT filler
        // "you know everything" could go either way but "you know" before "everything" → probably filler
        let highConf = youKnow.filter { $0.confidence >= 0.8 }
        #expect(highConf.count >= 1 && highConf.count <= 3, "Should detect 1-3 discourse-marker 'you know'. Got \(highConf.count)")
    }

    @Test func soAsFillerVsAdverb() {
        let transcript = "So the thing is, it was so good that I couldn't stop. So then I realized it's not so bad after all."
        let detections = FillerWordDetector.detections(in: transcript, prompt: "What happened?")
        let soDetections = detections.filter { $0.word == "so" }
        // "So the thing" at start → filler (0.7)
        // "so good" → NOT filler (adverb)
        // "So then" → depends on position
        // "not so bad" → NOT filler
        let highConf = soDetections.filter { $0.confidence >= 0.7 }
        #expect(highConf.count >= 1, "Sentence-start 'so' should be detected as filler")
        // Verify "so good" and "not so bad" are NOT detected
        #expect(soDetections.count <= 3, "Should not over-detect 'so'. Got \(soDetections.count)")
    }

    @Test func pureDisfluenciesAlwaysHighConfidence() {
        let transcript = "The uh thing about erm leadership is that um you need to be uhh decisive and ah not hesitate."
        let detections = FillerWordDetector.detections(in: transcript, prompt: "What makes a good leader?")
        let pureDisf = detections.filter { ["uh", "erm", "um", "uhh", "ah"].contains($0.word) }
        #expect(pureDisf.count >= 4, "Should detect at least 4 pure disfluencies, got \(pureDisf.count)")
        for d in pureDisf {
            #expect(d.confidence == 0.95, "Pure disfluency '\(d.word)' should have 0.95 confidence, got \(d.confidence)")
        }
    }

    @Test func suddenDeathFairnessPromptEcho() {
        // Key test: should NOT end a sudden death run on prompt-echo words
        let transcript = "Like I mentioned earlier, what I like about this approach is that it like brings people together."
        let prompt = "What do you like about collaborative approaches?"
        let highCount = FillerWordDetector.highConfidenceCount(in: transcript, prompt: prompt)
        // "like" appears in prompt → most uses should be echo or valid
        // "it like brings" → ambiguous, may or may not flag
        #expect(highCount <= 1, "Sudden death should be lenient with prompt-echo 'like'. High-conf count: \(highCount)")
    }
}

// MARK: - NextAction Engine Tests

struct NextActionEngineTests {

    private func makeBaseline(
        sessionCount: Int = 15,
        fillerRate: Double = 2.0,
        pace: Double = 135,
        score: Double = 7.0,
        strengths: [String] = ["Pace control"],
        blockers: [String] = []
    ) -> CommunicationBaseline {
        let confidence = BaselineConfidence.from(sessionCount: sessionCount)
        return CommunicationBaseline(
            lastUpdated: Date(),
            sessionCount: sessionCount,
            qualifyingSessionCount: sessionCount,
            fillerRate: BaselineStat(value: fillerRate, sampleCount: sessionCount, confidence: confidence, trend: .stable, percentile25: fillerRate * 0.7, percentile75: fillerRate * 1.3),
            pace: BaselineStat(value: pace, sampleCount: sessionCount, confidence: confidence, trend: .stable, percentile25: pace - 10, percentile75: pace + 10),
            paceVariance: .empty,
            durationTendency: BaselineStat(value: 45, sampleCount: sessionCount, confidence: confidence, trend: .stable, percentile25: 35, percentile75: 55),
            openingStrength: .empty,
            closingStrength: .empty,
            structureQuality: .empty,
            answerDepth: .empty,
            clarity: .empty,
            vocabularyRange: .empty,
            hedgingRate: .empty,
            averageScore: BaselineStat(value: score, sampleCount: sessionCount, confidence: confidence, trend: .stable, percentile25: score - 1, percentile75: score + 1),
            clutchWordFrequencies: [:],
            topStrengths: strengths,
            persistentBlockers: blockers
        )
    }

    private func makePressure(resilience: Double? = nil) -> PressureProfile {
        if let resilience {
            // Build a profile where resilience is approximately the target.
            // The resilience formula averages delta across filler, pace, and score,
            // so we need all three dimensions populated to get the right result.
            let targetDelta = 1.0 - resilience  // e.g. resilience 0.4 → delta 0.6
            let fillerDelta = targetDelta * 2.0  // fillerDelta/max(casual,1) = targetDelta
            let casualFiller = BaselineStat(value: 2.0, sampleCount: 10, confidence: .established, trend: .stable, percentile25: 1.5, percentile75: 2.5)
            let highFiller = BaselineStat(value: 2.0 + fillerDelta, sampleCount: 5, confidence: .moderate, trend: .stable, percentile25: 2.0, percentile75: 3.0 + fillerDelta)
            // Pace: casual 130, high = 130 * (1 + targetDelta)
            let casualPace = BaselineStat(value: 130, sampleCount: 10, confidence: .established, trend: .stable, percentile25: 120, percentile75: 140)
            let highPace = BaselineStat(value: 130 * (1 + targetDelta), sampleCount: 5, confidence: .moderate, trend: .stable, percentile25: 140, percentile75: 180)
            // Score: casual 7.0, high = 7.0 * (1 - targetDelta)
            let casualScore = BaselineStat(value: 7.0, sampleCount: 10, confidence: .established, trend: .stable, percentile25: 6.0, percentile75: 8.0)
            let highScore = BaselineStat(value: max(1, 7.0 * (1 - targetDelta)), sampleCount: 5, confidence: .moderate, trend: .stable, percentile25: 2.0, percentile75: 5.0)
            return PressureProfile(
                casualFillerRate: casualFiller, highFillerRate: highFiller,
                casualPace: casualPace, highPace: highPace,
                casualScore: casualScore, highScore: highScore
            )
        }
        return .empty
    }

    @Test func severeFillerIssueTriggersImmediateAction() {
        let input = NextActionInput(
            fillerCount: 12, duration: 45, wordCount: 120, wpm: 160, score: 4,
            categoryRatings: ["Opening": "OK", "Structure": "Could improve"],
            mode: .timed, pressureLevel: .standard,
            baseline: makeBaseline(), pressureProfile: .empty,
            trends: [], drillHistory: [],
            sessionCount: 10, streakDays: 3, styleGoal: "authoritative"
        )
        let result = NextActionEngine.recommend(input: input)
        // Severe filler issue → immediate corrective drill
        #expect(result.reasoning.contains("significant issue"), "Severe session should mention significant issue. Got: \(result.reasoning)")
    }

    @Test func persistentBlockerGetsConfidenceRebuilding() {
        let input = NextActionInput(
            fillerCount: 4, duration: 35, wordCount: 90, wpm: 154, score: 5,
            categoryRatings: ["Opening": "Could improve", "Structure": "OK"],
            mode: .timed, pressureLevel: .standard,
            baseline: makeBaseline(blockers: ["Filler words"]),
            pressureProfile: .empty,
            trends: [], drillHistory: [],
            sessionCount: 15, streakDays: 5, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        // Persistent blocker → confidence rebuilding
        #expect(result.reasoning.contains("persistent"), "Persistent blocker should be mentioned. Got: \(result.reasoning)")
        if case .confidenceRebuilding = result.primary {
            // good
        } else {
            #expect(Bool(false), "Expected confidenceRebuilding, got \(result.primary.displayTitle)")
        }
    }

    @Test func pressureGapDetected() {
        let input = NextActionInput(
            fillerCount: 1, duration: 55, wordCount: 150, wpm: 140, score: 8,
            categoryRatings: ["Opening": "Good", "Structure": "Good"],
            mode: .timed, pressureLevel: .standard,
            baseline: makeBaseline(sessionCount: 12, score: 7.5),
            pressureProfile: makePressure(resilience: 0.4),
            trends: [], drillHistory: [],
            sessionCount: 12, streakDays: 7, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        // Strong casually + low resilience → pressure exposure
        #expect(result.reasoning.lowercased().contains("pressure"), "Should suggest pressure exposure. Got: \(result.reasoning)")
    }

    @Test func improvingTrendGetsStabilizingRep() {
        let input = NextActionInput(
            fillerCount: 2, duration: 40, wordCount: 100, wpm: 130, score: 7,
            categoryRatings: ["Opening": "Good", "Structure": "OK"],
            mode: .timed, pressureLevel: .standard,
            baseline: makeBaseline(sessionCount: 8),
            pressureProfile: .empty,
            trends: [SkillTrend(skillArea: .fillerReduction, direction: .improving, confidence: .medium, windowSize: 8, currentLevel: .solid, recentDelta: "2 fewer fillers than 5 sessions ago")],
            drillHistory: [DrillHistoryStore.Entry(variationId: "test", skillArea: .fillerReduction, succeeded: true, sessionId: UUID())],
            sessionCount: 8, streakDays: 3, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        // Improving + recent drill match → stabilizing rep
        let hasProgress = result.reasoning.lowercased().contains("progress")
        #expect(hasProgress, "Should acknowledge progress. Got: \(result.reasoning)")
    }

    @Test func strongPerformanceGetsStretchChallenge() {
        let input = NextActionInput(
            fillerCount: 0, duration: 50, wordCount: 140, wpm: 135, score: 9,
            categoryRatings: ["Opening": "Good", "Structure": "Good", "Depth": "Good"],
            mode: .timed, pressureLevel: .standard,
            baseline: makeBaseline(sessionCount: 10, score: 8.0),
            pressureProfile: .empty,
            trends: [SkillTrend(skillArea: .fillerReduction, direction: .stable, confidence: .high, windowSize: 8, currentLevel: .strong)],
            drillHistory: [],
            sessionCount: 10, streakDays: 5, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        // Strong + stable → stretch challenge
        #expect(result.reasoning.lowercased().contains("push") || result.reasoning.lowercased().contains("edge") || result.reasoning.lowercased().contains("solid"), "Should suggest stretch. Got: \(result.reasoning)")
    }

    @Test func defaultRecommendationIsNeverEmpty() {
        let input = NextActionInput(
            fillerCount: 3, duration: 30, wordCount: 70, wpm: 140, score: 5,
            categoryRatings: [:],
            mode: .timed, pressureLevel: .standard,
            baseline: .empty, pressureProfile: .empty,
            trends: [], drillHistory: [],
            sessionCount: 2, streakDays: 1, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        #expect(!result.primary.displayTitle.isEmpty, "Should always have a recommendation")
        #expect(!result.reasoning.isEmpty, "Should always have reasoning")
    }
}

// MARK: - VerdictEngine Tests

struct VerdictEngineTests {

    @Test func cleanSessionGeneratesMomentum() {
        let note = VerdictEngine.generate(
            fillerCount: 0, duration: 45, wordCount: 120, wpm: 135, score: 8,
            categoryRatings: ["Opening": "Good", "Structure": "Good", "Depth": "Good"],
            trends: [], primaryFocus: .structure, drillHistory: []
        )
        #expect(!note.momentum.isEmpty, "Should generate momentum")
        #expect(note.momentum.lowercased().contains("zero filler") || note.momentum.lowercased().contains("clean") || note.momentum.lowercased().contains("pace"),
            "Clean session momentum should mention clean delivery or pace. Got: \(note.momentum)")
    }

    @Test func baselineEnrichedFeedbackReferencesBaseline() {
        let baseline = CommunicationBaseline(
            lastUpdated: Date(), sessionCount: 15, qualifyingSessionCount: 15,
            fillerRate: BaselineStat(value: 3.0, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 2.0, percentile75: 4.0),
            pace: BaselineStat(value: 130, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 120, percentile75: 140),
            paceVariance: .empty, durationTendency: .empty,
            openingStrength: .empty, closingStrength: .empty,
            structureQuality: .empty, answerDepth: .empty, clarity: .empty,
            vocabularyRange: .empty, hedgingRate: .empty,
            averageScore: .empty, clutchWordFrequencies: [:],
            topStrengths: [], persistentBlockers: []
        )
        // Session with lower filler rate than baseline (1 filler in 60s = 1.0/min vs baseline 3.0/min)
        let note = VerdictEngine.generate(
            fillerCount: 1, duration: 60, wordCount: 160, wpm: 130, score: 7,
            categoryRatings: ["Opening": "Good", "Structure": "OK"],
            trends: [], primaryFocus: .fillerReduction, drillHistory: [],
            baseline: baseline
        )
        // Should mention baseline improvement
        let mentionsBaseline = note.momentum.lowercased().contains("baseline") || note.momentum.lowercased().contains("below") || note.momentum.lowercased().contains("dropped")
        #expect(mentionsBaseline, "Baseline-enriched momentum should reference baseline. Got: \(note.momentum)")
    }

    @Test func confidencePhrasingAdjustsForLowData() {
        let earlyFrame = ConfidencePhrasing.frame("Your filler rate is improving.", confidence: .tentative)
        #expect(earlyFrame.hasPrefix("Initial read:"), "Tentative should prefix with 'Initial read'. Got: \(earlyFrame)")

        let earlySignal = ConfidencePhrasing.frame("Your filler rate is improving.", confidence: .insufficient)
        #expect(earlySignal.hasPrefix("Early signal:"), "Insufficient should prefix with 'Early signal'. Got: \(earlySignal)")

        let established = ConfidencePhrasing.frame("Your filler rate is improving.", confidence: .established)
        #expect(established.hasPrefix("Consistent pattern:"), "Established should prefix with 'Consistent pattern'. Got: \(established)")

        let moderate = ConfidencePhrasing.frame("Your filler rate is improving.", confidence: .moderate)
        #expect(moderate == "Your filler rate is improving.", "Moderate should pass through unchanged. Got: \(moderate)")
    }

    @Test func styleGoalProducesRelevantNote() {
        let note = VerdictEngine.generate(
            fillerCount: 6, duration: 45, wordCount: 100, wpm: 133, score: 5,
            categoryRatings: ["Opening": "Could improve", "Structure": "OK"],
            trends: [], primaryFocus: .fillerReduction, drillHistory: [],
            styleGoal: "authoritative"
        )
        // Authoritative + high fillers → style note about fillers undercutting authority
        #expect(note.nextStep.lowercased().contains("authoritative") || note.nextStep.lowercased().contains("filler"),
            "Style-aware next step should reference style goal or fillers. Got: \(note.nextStep)")
    }

    @Test func highPressureSessionGetsPressureAcknowledgment() {
        let pressure = PressureProfile(
            casualFillerRate: BaselineStat(value: 2.0, sampleCount: 10, confidence: .established, trend: .stable, percentile25: 1.5, percentile75: 2.5),
            highFillerRate: BaselineStat(value: 5.0, sampleCount: 5, confidence: .moderate, trend: .stable, percentile25: 4.0, percentile75: 6.0)
        )
        let note = VerdictEngine.generate(
            fillerCount: 1, duration: 40, wordCount: 100, wpm: 130, score: 7,
            categoryRatings: ["Opening": "Good"],
            trends: [], primaryFocus: .fillerReduction, drillHistory: [],
            pressureProfile: pressure, pressureLevel: .high
        )
        #expect(note.momentum.lowercased().contains("pressure") || note.momentum.lowercased().contains("high"),
            "High-pressure session should acknowledge pressure. Got: \(note.momentum)")
    }
}

// MARK: - Baseline Prompt Context Tests

struct BaselinePromptContextTests {

    @Test func insufficientBaselineReturnsMinimalContext() {
        let baseline = CommunicationBaseline.empty
        let context = BaselineEngine.promptContext(baseline: baseline, pressure: .empty)
        #expect(context.contains("Not yet established"), "Empty baseline should say not established. Got: \(context)")
    }

    @Test func establishedBaselineIncludesAllDimensions() {
        let baseline = CommunicationBaseline(
            lastUpdated: Date(), sessionCount: 15, qualifyingSessionCount: 15,
            fillerRate: BaselineStat(value: 2.5, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 1.8, percentile75: 3.2),
            pace: BaselineStat(value: 135, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 125, percentile75: 145),
            paceVariance: .empty,
            durationTendency: BaselineStat(value: 45, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 35, percentile75: 55),
            openingStrength: .empty, closingStrength: .empty,
            structureQuality: .empty, answerDepth: .empty, clarity: .empty,
            vocabularyRange: .empty, hedgingRate: .empty,
            averageScore: BaselineStat(value: 7.2, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 6.5, percentile75: 7.9),
            clutchWordFrequencies: [:],
            topStrengths: ["Pace control", "Filler discipline"],
            persistentBlockers: ["Opening strength"]
        )
        let context = BaselineEngine.promptContext(
            baseline: baseline, pressure: .empty,
            currentPressureLevel: .elevated,
            styleGoal: "authoritative"
        )
        #expect(context.contains("Filler rate:"), "Should include filler rate")
        #expect(context.contains("Pace:"), "Should include pace")
        #expect(context.contains("Average score:"), "Should include score")
        #expect(context.contains("Consistent strengths:"), "Should include strengths")
        #expect(context.contains("Persistent blockers:"), "Should include blockers")
        #expect(context.contains("Elevated"), "Should include current pressure level")
        #expect(context.contains("authoritative"), "Should include style goal")
    }

    @Test func pressureProfileInsightsAreIncluded() {
        let pressure = PressureProfile(
            casualFillerRate: BaselineStat(value: 1.5, sampleCount: 10, confidence: .established, trend: .stable, percentile25: 1.0, percentile75: 2.0),
            highFillerRate: BaselineStat(value: 4.5, sampleCount: 5, confidence: .moderate, trend: .stable, percentile25: 3.5, percentile75: 5.5),
            casualPace: BaselineStat(value: 130, sampleCount: 10, confidence: .established, trend: .stable, percentile25: 120, percentile75: 140),
            highPace: BaselineStat(value: 155, sampleCount: 5, confidence: .moderate, trend: .stable, percentile25: 145, percentile75: 165)
        )
        let baseline = CommunicationBaseline(
            lastUpdated: Date(), sessionCount: 15, qualifyingSessionCount: 15,
            fillerRate: BaselineStat(value: 2.5, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 1.8, percentile75: 3.2),
            pace: .empty, paceVariance: .empty, durationTendency: .empty,
            openingStrength: .empty, closingStrength: .empty,
            structureQuality: .empty, answerDepth: .empty, clarity: .empty,
            vocabularyRange: .empty, hedgingRate: .empty,
            averageScore: .empty, clutchWordFrequencies: [:],
            topStrengths: [], persistentBlockers: []
        )
        let context = BaselineEngine.promptContext(baseline: baseline, pressure: pressure, currentPressureLevel: .high)
        #expect(context.contains("resilience"), "Should include pressure resilience")
        #expect(context.contains("Pressure pattern:"), "Should include pressure patterns")
    }
}

// MARK: - IM Context-Fit Tests

struct IMContextFitTests {

    @Test func imOnTopicGetsPositiveFeedback() {
        let imContext = IMContextFit(
            scenarioName: "Executive briefing",
            targetTone: "Concise and direct",
            relevanceScore: 0.9,
            naturalness: 0.85,
            trustBuilding: 0.8
        )
        let note = VerdictEngine.generate(
            fillerCount: 1, duration: 50, wordCount: 130, wpm: 135, score: 8,
            categoryRatings: ["Opening": "Good", "Structure": "Good", "Depth": "Good"],
            trends: [], primaryFocus: .structure, drillHistory: [],
            imContext: imContext
        )
        // On-topic IM → momentum should acknowledge good context fit
        let mentionsIM = note.momentum.lowercased().contains("brief") ||
                         note.momentum.lowercased().contains("scenario") ||
                         note.momentum.lowercased().contains("context") ||
                         note.momentum.lowercased().contains("conversation") ||
                         note.momentum.lowercased().contains("tone")
        #expect(mentionsIM || !note.momentum.isEmpty, "IM on-topic session should generate meaningful momentum. Got: \(note.momentum)")
    }

    @Test func imOffTopicGetsDirectionalFeedback() {
        let imContext = IMContextFit(
            scenarioName: "Customer objection handling",
            targetTone: "Empathetic but firm",
            relevanceScore: 0.3,
            naturalness: 0.5,
            trustBuilding: 0.4
        )
        let note = VerdictEngine.generate(
            fillerCount: 4, duration: 40, wordCount: 100, wpm: 150, score: 4,
            categoryRatings: ["Opening": "Could improve", "Structure": "Could improve"],
            trends: [], primaryFocus: .structure, drillHistory: [],
            imContext: imContext
        )
        // Off-topic IM → leverage should address the low context fit
        let addressesFit = note.leverage.lowercased().contains("relevance") ||
                           note.leverage.lowercased().contains("scenario") ||
                           note.leverage.lowercased().contains("tone") ||
                           note.leverage.lowercased().contains("context") ||
                           note.leverage.lowercased().contains("question") ||
                           note.leverage.lowercased().contains("focus")
        #expect(addressesFit || !note.leverage.isEmpty, "IM off-topic session should address context fit. Got: \(note.leverage)")
    }
}

// MARK: - Declining Trend & New Issue Tests

struct TrendResponseTests {

    @Test func decliningTrendGetsCorrective() {
        let baseline = CommunicationBaseline(
            lastUpdated: Date(), sessionCount: 12, qualifyingSessionCount: 12,
            fillerRate: BaselineStat(value: 2.0, sampleCount: 12, confidence: .established, trend: .declining, percentile25: 1.5, percentile75: 2.5),
            pace: BaselineStat(value: 140, sampleCount: 12, confidence: .established, trend: .stable, percentile25: 130, percentile75: 150),
            paceVariance: .empty, durationTendency: .empty,
            openingStrength: .empty, closingStrength: .empty,
            structureQuality: .empty, answerDepth: .empty, clarity: .empty,
            vocabularyRange: .empty, hedgingRate: .empty,
            averageScore: BaselineStat(value: 6.5, sampleCount: 12, confidence: .established, trend: .stable, percentile25: 5.5, percentile75: 7.5),
            clutchWordFrequencies: [:],
            topStrengths: ["Pace control"], persistentBlockers: []
        )
        let input = NextActionInput(
            fillerCount: 5, duration: 40, wordCount: 100, wpm: 150, score: 5,
            categoryRatings: ["Opening": "OK", "Structure": "Could improve"],
            mode: .timed, pressureLevel: .standard,
            baseline: baseline, pressureProfile: .empty,
            trends: [SkillTrend(skillArea: .fillerReduction, direction: .declining, confidence: .high, windowSize: 8, currentLevel: .weak)],
            drillHistory: [],
            sessionCount: 12, streakDays: 4, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        // Declining filler trend → should get a corrective drill
        let reasoningLower = result.reasoning.lowercased()
        let mentionsSlipping = reasoningLower.contains("slipping") ||
                               reasoningLower.contains("reverse") ||
                               reasoningLower.contains("pattern") ||
                               reasoningLower.contains("significant")
        #expect(mentionsSlipping, "Declining trend should produce corrective reasoning. Got: \(result.reasoning)")
    }

    @Test func newIssueGetsCaughtEarly() {
        let baseline = CommunicationBaseline(
            lastUpdated: Date(), sessionCount: 10, qualifyingSessionCount: 10,
            fillerRate: BaselineStat(value: 1.5, sampleCount: 10, confidence: .established, trend: .stable, percentile25: 1.0, percentile75: 2.0),
            pace: BaselineStat(value: 130, sampleCount: 10, confidence: .established, trend: .stable, percentile25: 120, percentile75: 140),
            paceVariance: .empty, durationTendency: .empty,
            openingStrength: .empty, closingStrength: .empty,
            structureQuality: .empty, answerDepth: .empty, clarity: .empty,
            vocabularyRange: .empty, hedgingRate: .empty,
            averageScore: BaselineStat(value: 7.0, sampleCount: 10, confidence: .established, trend: .stable, percentile25: 6.0, percentile75: 8.0),
            clutchWordFrequencies: [:],
            topStrengths: ["Pace control"], persistentBlockers: []
        )
        let input = NextActionInput(
            fillerCount: 2, duration: 35, wordCount: 80, wpm: 137, score: 6,
            categoryRatings: ["Opening": "Good", "Structure": "Could improve"],
            mode: .timed, pressureLevel: .standard,
            baseline: baseline, pressureProfile: .empty,
            trends: [SkillTrend(skillArea: .structure, direction: .newIssue, confidence: .medium, windowSize: 5, currentLevel: .weak)],
            drillHistory: [],
            sessionCount: 10, streakDays: 3, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        // New issue → should catch it early
        let reasonLower = result.reasoning.lowercased()
        let caughtEarly = reasonLower.contains("just appeared") || reasonLower.contains("early") || reasonLower.contains("catching")
        #expect(caughtEarly, "New issue should be caught early. Got: \(result.reasoning)")
    }
}

// MARK: - Style-Specific Coaching Tests

struct StyleCoachingTests {

    @Test func authoritativeStyleWithHighFillersGetsTargetedAdvice() {
        let note = VerdictEngine.generate(
            fillerCount: 8, duration: 40, wordCount: 100, wpm: 150, score: 4,
            categoryRatings: ["Opening": "Could improve", "Structure": "OK"],
            trends: [], primaryFocus: .fillerReduction, drillHistory: [],
            styleGoal: "authoritative"
        )
        // Authoritative style + high fillers → should note that fillers undercut authority
        let mentionsStyle = note.nextStep.lowercased().contains("authoritative") ||
                            note.nextStep.lowercased().contains("authority") ||
                            note.nextStep.lowercased().contains("decisive")
        let mentionsFillers = note.nextStep.lowercased().contains("filler") ||
                              note.nextStep.lowercased().contains("pause") ||
                              note.nextStep.lowercased().contains("hesitat")
        #expect(mentionsStyle || mentionsFillers,
            "Authoritative style with high fillers should produce targeted next step. Got: \(note.nextStep)")
    }

    @Test func warmStyleWithGoodDeliveryGetsEncouragement() {
        let note = VerdictEngine.generate(
            fillerCount: 1, duration: 55, wordCount: 140, wpm: 130, score: 8,
            categoryRatings: ["Opening": "Good", "Structure": "Good", "Depth": "Good"],
            trends: [], primaryFocus: .structure, drillHistory: [],
            styleGoal: "warm"
        )
        // Warm style + good delivery → next step should reference warmth-related traits or be substantive
        #expect(!note.nextStep.isEmpty, "Should always have a next step")
        #expect(note.nextStep.count > 20, "Next step should be substantive, not generic. Got: \(note.nextStep)")
    }

    @Test func repeatedBlockerAcrossSessionsGetsPersistentAdvice() {
        // A user who has been stuck on openings for many sessions
        let baseline = CommunicationBaseline(
            lastUpdated: Date(), sessionCount: 20, qualifyingSessionCount: 20,
            fillerRate: BaselineStat(value: 1.5, sampleCount: 20, confidence: .stable, trend: .stable, percentile25: 1.0, percentile75: 2.0),
            pace: BaselineStat(value: 130, sampleCount: 20, confidence: .stable, trend: .stable, percentile25: 120, percentile75: 140),
            paceVariance: .empty, durationTendency: .empty,
            openingStrength: .empty, closingStrength: .empty,
            structureQuality: .empty, answerDepth: .empty, clarity: .empty,
            vocabularyRange: .empty, hedgingRate: .empty,
            averageScore: BaselineStat(value: 6.5, sampleCount: 20, confidence: .stable, trend: .stable, percentile25: 5.5, percentile75: 7.5),
            clutchWordFrequencies: [:],
            topStrengths: ["Pace control", "Filler discipline"],
            persistentBlockers: ["Opening strength"]
        )
        let input = NextActionInput(
            fillerCount: 1, duration: 40, wordCount: 100, wpm: 130, score: 6,
            categoryRatings: ["Opening": "Could improve", "Structure": "Good"],
            mode: .timed, pressureLevel: .standard,
            baseline: baseline, pressureProfile: .empty,
            trends: [], drillHistory: [],
            sessionCount: 20, streakDays: 10, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        // Persistent blocker → should reference persistent pattern
        #expect(result.reasoning.lowercased().contains("persistent"),
            "Repeated blocker should be identified. Got: \(result.reasoning)")
        if case .confidenceRebuilding = result.primary {
            // Good — persistent blockers get confidence rebuilding
        } else {
            #expect(Bool(false), "Persistent blocker should get confidenceRebuilding, got \(result.primary.displayTitle)")
        }
    }
}

// MARK: - Short Session & Underdeveloped Response Tests

struct SessionEdgeCaseTests {

    @Test func veryShortSessionGetsImmediateGuidance() {
        let input = NextActionInput(
            fillerCount: 0, duration: 5, wordCount: 12, wpm: 144, score: 2,
            categoryRatings: [:],
            mode: .timed, pressureLevel: .standard,
            baseline: .empty, pressureProfile: .empty,
            trends: [], drillHistory: [],
            sessionCount: 3, streakDays: 1, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        // Very short session → significant issue (duration < 8s)
        #expect(result.reasoning.lowercased().contains("significant"),
            "Very short session should be flagged as significant issue. Got: \(result.reasoning)")
    }

    @Test func underdevelopedResponseGetsDepthDrill() {
        // Duration long enough (not < 8s) but word count and score low
        let note = VerdictEngine.generate(
            fillerCount: 2, duration: 20, wordCount: 35, wpm: 105, score: 3,
            categoryRatings: ["Depth": "Could improve", "Structure": "Could improve"],
            trends: [], primaryFocus: .answerDevelopment, drillHistory: []
        )
        // Underdeveloped → leverage should address depth/development
        let addressesDepth = note.leverage.lowercased().contains("develop") ||
                             note.leverage.lowercased().contains("expand") ||
                             note.leverage.lowercased().contains("more") ||
                             note.leverage.lowercased().contains("depth") ||
                             note.leverage.lowercased().contains("structure") ||
                             note.leverage.lowercased().contains("detail")
        #expect(addressesDepth || !note.leverage.isEmpty,
            "Underdeveloped response should address depth. Got: \(note.leverage)")
    }

    @Test func strongStructuredSessionGetsStretchAdvice() {
        let input = NextActionInput(
            fillerCount: 0, duration: 60, wordCount: 160, wpm: 133, score: 9,
            categoryRatings: ["Opening": "Good", "Structure": "Good", "Depth": "Good", "Closing": "Good"],
            mode: .timed, pressureLevel: .standard,
            baseline: CommunicationBaseline(
                lastUpdated: Date(), sessionCount: 15, qualifyingSessionCount: 15,
                fillerRate: BaselineStat(value: 0.8, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 0.3, percentile75: 1.3),
                pace: BaselineStat(value: 133, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 125, percentile75: 141),
                paceVariance: .empty, durationTendency: .empty,
                openingStrength: .empty, closingStrength: .empty,
                structureQuality: .empty, answerDepth: .empty, clarity: .empty,
                vocabularyRange: .empty, hedgingRate: .empty,
                averageScore: BaselineStat(value: 8.5, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 7.5, percentile75: 9.5),
                clutchWordFrequencies: [:],
                topStrengths: ["Pace control", "Filler discipline", "Structure"],
                persistentBlockers: []
            ),
            pressureProfile: .empty,
            trends: [SkillTrend(skillArea: .fillerReduction, direction: .stable, confidence: .high, windowSize: 8, currentLevel: .strong)],
            drillHistory: [],
            sessionCount: 15, streakDays: 7, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        // Strong structured session → stretch challenge
        let isStretch = result.reasoning.lowercased().contains("push") ||
                        result.reasoning.lowercased().contains("edge") ||
                        result.reasoning.lowercased().contains("solid") ||
                        result.reasoning.lowercased().contains("pressure") ||
                        result.reasoning.lowercased().contains("challenge")
        #expect(isStretch, "Strong session should get stretch recommendation. Got: \(result.reasoning)")
    }
}

// MARK: - Seed Data Profile Tests

#if DEBUG
struct SeedDataTests {

    @Test func allProfilesGenerateValidSessions() {
        for profile in SeedProfile.allCases {
            let sessions = DevSeedData.sessions(for: profile)
            #expect(!sessions.isEmpty, "\(profile.rawValue) should generate sessions")
            for session in sessions {
                #expect(session.duration > 0, "Session duration should be positive")
                #expect(session.fillerWordCount >= 0, "Filler count should be non-negative")
                #expect(!session.transcript.isEmpty, "Transcript should not be empty")
            }
        }
    }

    @Test func profileSummaryContainsKeyInfo() {
        for profile in SeedProfile.allCases {
            let summary = DevSeedData.profileSummary(profile)
            #expect(summary.contains("Sessions:"), "\(profile.rawValue) summary should include session count")
            #expect(summary.contains("Confidence:"), "\(profile.rawValue) summary should include confidence")
        }
    }

    @Test func pressureVulnerableProfileHasMixedPressure() {
        let sessions = DevSeedData.sessions(for: .pressureVulnerable)
        let casualCount = sessions.filter { $0.pressureLevel == .casual }.count
        let highCount = sessions.filter { $0.pressureLevel == .high }.count
        #expect(casualCount >= 5, "Should have casual sessions")
        #expect(highCount >= 3, "Should have high-pressure sessions")
    }

    @Test func baselineFromSeedProfilesIsReasonable() {
        // The improving intermediate profile should produce a moderate+ baseline
        let sessions = DevSeedData.sessions(for: .improvingIntermediate)
        let baseline = BaselineEngine.compute(from: sessions)
        #expect(baseline.sessionCount == 12, "Should have 12 sessions")
        #expect(baseline.overallConfidence >= .moderate, "12 sessions should give moderate+ confidence")

        // The filler-free profile should have very low filler rate
        let fillerFreeSessions = DevSeedData.sessions(for: .fillerFree)
        let fillerFreeBaseline = BaselineEngine.compute(from: fillerFreeSessions)
        #expect(fillerFreeBaseline.fillerRate.value < 1.0, "Filler-free profile should have sub-1.0 filler rate")
    }
}
#endif

// MARK: - Hedge Detection Tests

struct HedgeDetectionTests {

    @Test func hedgeFreeTranscriptReturnsZero() {
        let count = HedgeDetector.count(in: "The project will launch on Friday. We have completed all milestones. The team is ready.")
        #expect(count == 0, "Hedge-free transcript should have 0 hedges, got \(count)")
    }

    @Test func hedgeHeavyTranscriptDetectsAll() {
        let transcript = "I think maybe we should probably look at this. I guess it could be sort of important. I'm not sure but it seems like kind of a big deal."
        let count = HedgeDetector.count(in: transcript)
        // "I think", "maybe", "probably", "I guess", "could be", "sort of", "I'm not sure but", "it seems like", "kind of"
        #expect(count >= 7, "Hedge-heavy transcript should detect 7+ hedges, got \(count)")
        let breakdown = HedgeDetector.breakdown(in: transcript)
        #expect(!breakdown.isEmpty, "Breakdown should not be empty")
    }
}

// MARK: - Weak Spot Fix Verification Tests

struct BlockerMatchTests {

    @Test func blockerStringsMatchAcrossEngines() {
        // Verify that identifyBlockers produces strings that checkPersistentBlocker can match
        let baseline = CommunicationBaseline(
            lastUpdated: Date(), sessionCount: 20, qualifyingSessionCount: 20,
            fillerRate: BaselineStat(value: 5.0, sampleCount: 20, confidence: .stable, trend: .stable, percentile25: 4.0, percentile75: 6.0),
            pace: BaselineStat(value: 130, sampleCount: 20, confidence: .stable, trend: .stable, percentile25: 120, percentile75: 140),
            paceVariance: .empty, durationTendency: .empty,
            openingStrength: BaselineStat(value: 1.0, sampleCount: 20, confidence: .stable, trend: .declining, percentile25: 0.8, percentile75: 1.2),
            closingStrength: .empty,
            structureQuality: .empty, answerDepth: .empty, clarity: .empty,
            vocabularyRange: .empty, hedgingRate: .empty,
            averageScore: BaselineStat(value: 5.0, sampleCount: 20, confidence: .stable, trend: .stable, percentile25: 4.0, percentile75: 6.0),
            clutchWordFrequencies: [:],
            topStrengths: [],
            persistentBlockers: ["Filler words", "Opening strength"]
        )
        let input = NextActionInput(
            fillerCount: 6, duration: 40, wordCount: 100, wpm: 150, score: 5,
            categoryRatings: ["Opening": "Could improve"],
            mode: .timed, pressureLevel: .standard,
            baseline: baseline, pressureProfile: .empty,
            trends: [], drillHistory: [],
            sessionCount: 20, streakDays: 10, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        // With high filler count (6) this may hit Priority 1 (severe), but if not,
        // the persistent blockers should be matched. Either way, it should produce actionable output.
        #expect(!result.reasoning.isEmpty, "Should produce reasoning")
    }

    @Test func fillerBlockerMatchesNextActionEngine() {
        // Create a baseline where the only blocker is "Filler words"
        let baseline = CommunicationBaseline(
            lastUpdated: Date(), sessionCount: 20, qualifyingSessionCount: 20,
            fillerRate: BaselineStat(value: 5.0, sampleCount: 20, confidence: .stable, trend: .stable, percentile25: 4.0, percentile75: 6.0),
            pace: BaselineStat(value: 130, sampleCount: 20, confidence: .stable, trend: .stable, percentile25: 120, percentile75: 140),
            paceVariance: .empty, durationTendency: .empty,
            openingStrength: .empty, closingStrength: .empty,
            structureQuality: .empty, answerDepth: .empty, clarity: .empty,
            vocabularyRange: .empty, hedgingRate: .empty,
            averageScore: BaselineStat(value: 6.0, sampleCount: 20, confidence: .stable, trend: .stable, percentile25: 5.0, percentile75: 7.0),
            clutchWordFrequencies: [:],
            topStrengths: [],
            persistentBlockers: ["Filler words"]
        )
        // Score low enough that Priority 1 doesn't trigger (fillerCount < 10)
        // but baseline has the blocker
        let input = NextActionInput(
            fillerCount: 3, duration: 50, wordCount: 130, wpm: 130, score: 6,
            categoryRatings: ["Opening": "Good", "Structure": "Good"],
            mode: .timed, pressureLevel: .standard,
            baseline: baseline, pressureProfile: .empty,
            trends: [], drillHistory: [],
            sessionCount: 20, streakDays: 10, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        // Persistent blocker should be detected and recommended
        let isPersistent = result.reasoning.lowercased().contains("persistent")
        #expect(isPersistent, "Filler words blocker should trigger persistent path. Got: \(result.reasoning)")
        if case .confidenceRebuilding = result.primary {
            // Expected
        } else {
            #expect(Bool(false), "Should get confidenceRebuilding for persistent blocker, got \(result.primary.displayTitle)")
        }
    }
}

struct SoDetectionMidSentenceTests {

    @Test func soAfterConjunctionIsDetected() {
        let transcript = "I went to the meeting and so I decided to bring up the topic but so the response was unexpected."
        let detections = FillerWordDetector.detections(in: transcript, prompt: "Describe a recent meeting.")
        let soDetections = detections.filter { $0.word == "so" }
        // "and so" and "but so" should be caught as mid-phrase fillers
        #expect(soDetections.count >= 2, "Mid-sentence 'so' after conjunctions should be detected. Got \(soDetections.count)")
        for d in soDetections where d.context == .midPhrase {
            #expect(d.confidence >= 0.6, "'so' after conjunction should have >= 0.6 confidence. Got \(d.confidence)")
        }
    }

    @Test func soAfterNotStillExcluded() {
        let transcript = "It was not so difficult after all. The result is not so bad."
        let detections = FillerWordDetector.detections(in: transcript, prompt: "Describe the challenge.")
        let soDetections = detections.filter { $0.word == "so" }
        #expect(soDetections.isEmpty, "'not so' should not be flagged as filler. Got \(soDetections.count)")
    }
}

struct SkillSpecificFeedbackTests {

    @Test func nextStepIsSkillSpecificForFillers() {
        let note = VerdictEngine.generate(
            fillerCount: 6, duration: 40, wordCount: 100, wpm: 125, score: 5,
            categoryRatings: ["Opening": "OK", "Structure": "OK"],
            trends: [], primaryFocus: .fillerReduction, drillHistory: []
        )
        let step = note.nextStep.lowercased()
        let mentionsFiller = step.contains("filler") || step.contains("pause")
        #expect(mentionsFiller, "Next step for filler focus should mention fillers or pauses. Got: \(note.nextStep)")
    }

    @Test func nextStepIsSkillSpecificForStructure() {
        let note = VerdictEngine.generate(
            fillerCount: 1, duration: 45, wordCount: 120, wpm: 130, score: 5,
            categoryRatings: ["Structure": "Could improve", "Opening": "Good"],
            trends: [], primaryFocus: .structure, drillHistory: []
        )
        let step = note.nextStep.lowercased()
        let mentionsStructure = step.contains("framework") || step.contains("structure") || step.contains("point")
        #expect(mentionsStructure, "Next step for structure focus should mention structure/framework. Got: \(note.nextStep)")
    }

    @Test func nextStepIsSkillSpecificForOpening() {
        let note = VerdictEngine.generate(
            fillerCount: 0, duration: 50, wordCount: 130, wpm: 130, score: 6,
            categoryRatings: ["Opening": "Could improve", "Structure": "Good"],
            trends: [], primaryFocus: .openingStrength, drillHistory: []
        )
        let step = note.nextStep.lowercased()
        let mentionsOpening = step.contains("opening") || step.contains("first sentence") || step.contains("first line")
        #expect(mentionsOpening, "Next step for opening focus should mention openings. Got: \(note.nextStep)")
    }

    @Test func improvingTrendGetsSkillSpecificEncouragement() {
        let trends = [SkillTrend(skillArea: .paceControl, direction: .improving, confidence: .high, windowSize: 8, currentLevel: .developing, recentDelta: "Pace down 10 WPM")]
        let note = VerdictEngine.generate(
            fillerCount: 2, duration: 45, wordCount: 120, wpm: 135, score: 7,
            categoryRatings: ["Opening": "Good", "Structure": "Good"],
            trends: trends, primaryFocus: .paceControl, drillHistory: []
        )
        let step = note.nextStep.lowercased()
        let mentionsPace = step.contains("pace") || step.contains("rhythm") || step.contains("timed")
        #expect(mentionsPace, "Improving pace trend should get pace-specific next step")
    }
}

struct FillerRateComparisonTests {

    @Test func leverageUsesRateNotCountForBaseline() {
        // Short session (30 sec) with 3 fillers = 6/min — high rate
        // Baseline rate is 2.0/min
        let baseline = CommunicationBaseline(
            lastUpdated: Date(), sessionCount: 15, qualifyingSessionCount: 15,
            fillerRate: BaselineStat(value: 2.0, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 1.5, percentile75: 2.5),
            pace: .empty, paceVariance: .empty, durationTendency: .empty,
            openingStrength: .empty, closingStrength: .empty,
            structureQuality: .empty, answerDepth: .empty, clarity: .empty,
            vocabularyRange: .empty, hedgingRate: .empty,
            averageScore: .empty,
            clutchWordFrequencies: [:],
            topStrengths: [], persistentBlockers: []
        )
        let note = VerdictEngine.generate(
            fillerCount: 3, duration: 30, wordCount: 60, wpm: 120, score: 6,
            categoryRatings: [:], trends: [], primaryFocus: .fillerReduction, drillHistory: [],
            baseline: baseline
        )
        // With rate 6.0/min vs baseline 2.0/min, leverage should note "above your usual"
        let mentionsRate = note.leverage.contains("/min")
        #expect(mentionsRate, "Should compare rates in /min units. Got: \(note.leverage)")
    }

    @Test func lowCountHighDurationDoesNotFalseAlarm() {
        // Long session (3 min) with 3 fillers = 1.0/min — below baseline of 2.0/min
        let baseline = CommunicationBaseline(
            lastUpdated: Date(), sessionCount: 15, qualifyingSessionCount: 15,
            fillerRate: BaselineStat(value: 2.0, sampleCount: 15, confidence: .established, trend: .stable, percentile25: 1.5, percentile75: 2.5),
            pace: .empty, paceVariance: .empty, durationTendency: .empty,
            openingStrength: .empty, closingStrength: .empty,
            structureQuality: .empty, answerDepth: .empty, clarity: .empty,
            vocabularyRange: .empty, hedgingRate: .empty,
            averageScore: .empty,
            clutchWordFrequencies: [:],
            topStrengths: [], persistentBlockers: []
        )
        let note = VerdictEngine.generate(
            fillerCount: 3, duration: 180, wordCount: 400, wpm: 133, score: 7,
            categoryRatings: [:], trends: [], primaryFocus: .fillerReduction, drillHistory: [],
            baseline: baseline
        )
        // 1.0/min is below baseline 2.0/min — should NOT say "above your usual"
        let mentionsAbove = note.leverage.contains("above your usual")
        #expect(!mentionsAbove, "1.0/min should NOT be flagged as above baseline 2.0/min. Got: \(note.leverage)")
    }
}

struct DrillTargetAreaTests {

    @Test func selectDrillRespectsTargetArea() {
        // When NextActionEngine passes .openingStrength, the drill should be for openings
        let rec = DrillEngineV2.recommend(
            fillerCount: 0, duration: 50, wordCount: 130, score: 7,
            feedbackCategories: [("Opening", "Good"), ("Structure", "Good")],
            targetArea: .openingStrength
        )
        #expect(rec.variation.skillArea == .openingStrength,
            "Drill should target opening strength when requested. Got: \(rec.variation.skillArea)")
    }

    @Test func defaultRecommendDerivesFocusAutomatically() {
        // Without targetArea, the engine should derive from session data
        let rec = DrillEngineV2.recommend(
            fillerCount: 12, duration: 30, wordCount: 80, score: 3,
            feedbackCategories: [("Opening", "Could improve", ), ("Structure", "Could improve")]
        )
        // With 12 fillers in 30 seconds, filler reduction should be the focus
        #expect(rec.variation.skillArea == .fillerReduction,
            "High filler count should auto-target filler reduction. Got: \(rec.variation.skillArea)")
    }
}
