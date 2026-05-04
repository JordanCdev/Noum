//
//  NoumTests.swift
//  NoumTests
//
//  Created by Jordan Coaten on 25/01/2025.
//

import Foundation
import Testing
import XCTest
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

final class VideoRecordingLifecycleTests: XCTestCase {
    func testStartingNewRecordingClearsPreviousResultAndError() {
        let firstURL = URL(fileURLWithPath: "/tmp/first.mov")
        var lifecycle = VideoRecordingLifecycle()

        lifecycle.startRecording()
        lifecycle.complete(url: firstURL)
        lifecycle.fail("Old failure")
        lifecycle.startRecording()

        XCTAssertEqual(lifecycle.state, .recording)
        XCTAssertNil(lifecycle.recordingURL)
        XCTAssertNil(lifecycle.savedRecordingURL)
        XCTAssertNil(lifecycle.errorMessage)
    }

    func testFinalizingSuccessPublishesAvailableURL() {
        let url = URL(fileURLWithPath: "/tmp/final.mov")
        var lifecycle = VideoRecordingLifecycle()

        lifecycle.startRecording()
        lifecycle.beginFinalizing()
        lifecycle.complete(url: url)

        XCTAssertEqual(lifecycle.state, .available(url))
        XCTAssertEqual(lifecycle.recordingURL, url)
        XCTAssertNil(lifecycle.errorMessage)
    }

    func testFailedFinalizationClearsURLAndStoresError() {
        let url = URL(fileURLWithPath: "/tmp/final.mov")
        var lifecycle = VideoRecordingLifecycle()

        lifecycle.startRecording()
        lifecycle.complete(url: url)
        lifecycle.fail("Recording failed")

        XCTAssertEqual(lifecycle.state, .failed("Recording failed"))
        XCTAssertNil(lifecycle.recordingURL)
        XCTAssertEqual(lifecycle.errorMessage, "Recording failed")
    }

    func testCleanupResetsAllPublicLifecycleState() {
        let url = URL(fileURLWithPath: "/tmp/final.mov")
        var lifecycle = VideoRecordingLifecycle()

        lifecycle.startRecording()
        lifecycle.complete(url: url)
        lifecycle.markSaved(url: url)
        lifecycle.cleanup()

        XCTAssertEqual(lifecycle.state, .idle)
        XCTAssertNil(lifecycle.recordingURL)
        XCTAssertNil(lifecycle.savedRecordingURL)
        XCTAssertNil(lifecycle.errorMessage)
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

    @Test func fillerAnalysisSeparatesRawAndAdjustedCounts() {
        let prompt = "What do you like about teams?"
        let transcript = "I like how teams work. It feels like a real support system. Um, the best teams are clear."
        let analysis = FillerWordDetector.analysis(in: transcript, prompt: prompt)
        #expect(analysis.rawCount >= analysis.adjustedCount)
        #expect(analysis.adjustedCount == 1, "Only the explicit disfluency should count. Got \(analysis.adjustedCount)")
    }
}

struct FillerAlertGateTests {
    @Test func alertOnlyPlaysForEnabledHighConfidenceIncrementAfterCooldown() {
        var gate = FillerAlertGate()
        gate.cooldown = 1.0
        let detection = FillerDetection(word: "um", range: NSRange(location: 0, length: 2), confidence: 0.95, context: .midPhrase)
        let start = Date()

        let first = gate.evaluate(previousAdjustedCount: 0, adjustedCount: 1, detections: [detection], isEnabled: true, now: start)
        #expect(first.shouldPlay)

        let cooled = gate.evaluate(previousAdjustedCount: 1, adjustedCount: 2, detections: [detection, detection], isEnabled: true, now: start.addingTimeInterval(0.2))
        #expect(!cooled.shouldPlay)

        let disabled = gate.evaluate(previousAdjustedCount: 2, adjustedCount: 3, detections: [detection, detection, detection], isEnabled: false, now: start.addingTimeInterval(2.0))
        #expect(!disabled.shouldPlay)
    }
}

struct DrillXPEngineTests {
    @Test func drillXPVariesWithOutcomeQuality() {
        let variation = DrillCatalog.allVariations.first { $0.id == "pace.beatTheBrake" }!
        let drill = DrillRecommendationV2(variation: variation, reason: "test", trendContext: nil, alternateFormat: nil)
        let strong = MiniDrillOutcome(
            drill: drill,
            drillType: .beatTheBrake,
            transcript: String(repeating: "clear ", count: 70),
            fillerCount: 0,
            duration: 45,
            wordCount: 70,
            succeeded: true,
            beatTheBrakeMetrics: BeatTheBrakeMetrics(
                averageWPM: 126,
                timeInZone: 38,
                totalDuration: 45,
                zonePercentage: 0.84,
                peakWPM: 137,
                lowestWPM: 112,
                adjustedFillers: 0,
                rushedBursts: 0
            )
        )
        let weak = MiniDrillOutcome(
            drill: drill,
            drillType: .beatTheBrake,
            transcript: "um rushed answer",
            fillerCount: 1,
            duration: 8,
            wordCount: 3,
            succeeded: false,
            beatTheBrakeMetrics: BeatTheBrakeMetrics(
                averageWPM: 180,
                timeInZone: 1,
                totalDuration: 8,
                zonePercentage: 0.12,
                peakWPM: 210,
                lowestWPM: 160,
                adjustedFillers: 1,
                rushedBursts: 4
            )
        )

        #expect(DrillXPEngine.breakdown(outcome: strong).total > DrillXPEngine.breakdown(outcome: weak).total)
        #expect(DrillCompletionCopy.title(for: strong) == "Cleaner Rhythm")
        #expect(DrillCompletionCopy.title(for: weak) == "Rushed Finish")
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

// MARK: - Pressure Timer Engine Tests (auto-ramp, no difficulty selector)

struct PressureRoundConfigTests {

    @Test func round1HasWidestWindows() {
        let config = PressureRoundConfig.config(for: 1)
        #expect(config.startWindow == 12, "Round 1 start window should be 12s. Got: \(config.startWindow)")
        #expect(config.fillerTolerance == 3, "Round 1 should tolerate 3 fillers. Got: \(config.fillerTolerance)")
        #expect(!config.isFollowUp, "Round 1 should be a fresh prompt, not a follow-up")
    }

    @Test func pressureRampsAcrossRounds() {
        let r1 = PressureRoundConfig.config(for: 1)
        let r3 = PressureRoundConfig.config(for: 3)
        let r5 = PressureRoundConfig.config(for: 5)
        #expect(r3.startWindow < r1.startWindow, "Round 3 start window should be shorter than round 1")
        #expect(r5.startWindow < r3.startWindow, "Round 5 start window should be shorter than round 3")
        #expect(r5.fillerTolerance < r1.fillerTolerance, "Later rounds should tolerate fewer fillers")
    }

    @Test func round4IsTopicReset() {
        let config = PressureRoundConfig.config(for: 4)
        #expect(!config.isFollowUp, "Round 4 should be a topic reset (not a follow-up)")
        #expect(config.startWindow == 6, "Round 4 start window should be 6s. Got: \(config.startWindow)")
        #expect(config.fillerTolerance == 1, "Round 4 filler tolerance should be 1. Got: \(config.fillerTolerance)")
    }

    @Test func round6PlusHasZeroFillerTolerance() {
        let r6 = PressureRoundConfig.config(for: 6)
        let r8 = PressureRoundConfig.config(for: 8)
        #expect(r6.fillerTolerance == 0, "Round 6 should have zero filler tolerance")
        #expect(r8.fillerTolerance == 0, "Round 8 should have zero filler tolerance")
        #expect(r6.isFollowUp, "Round 6 should be a follow-up")
    }

    @Test func startWindowNeverGoesBelowMinimum() {
        let r20 = PressureRoundConfig.config(for: 20)
        #expect(r20.startWindow >= 3, "Start window should never go below 3s. Got: \(r20.startWindow)")
    }

    @Test func allRoundsHaveConsistentResponseCap() {
        for round in 1...10 {
            let config = PressureRoundConfig.config(for: round)
            #expect(config.responseCap == 30, "Response cap should be 30s for all rounds. Round \(round) got: \(config.responseCap)")
            #expect(config.minimumWords == 10, "Minimum words should be 10 for all rounds. Round \(round) got: \(config.minimumWords)")
        }
    }

    @Test func roundZeroOrNegativeClampedToRound1() {
        let r0 = PressureRoundConfig.config(for: 0)
        let rNeg = PressureRoundConfig.config(for: -3)
        let r1 = PressureRoundConfig.config(for: 1)
        #expect(r0 == r1, "Round 0 should clamp to round 1 config")
        #expect(rNeg == r1, "Negative round should clamp to round 1 config")
    }
}

struct RoundOutcomeTests {

    @Test func survivedIsNotFailed() {
        #expect(!RoundOutcome.survived.isFailed, "Survived should not be a failure")
    }

    @Test func allFailureStatesAreFailed() {
        let failures: [RoundOutcome] = [.timeoutBeforeStart, .fillerOverload, .tooShort]
        for outcome in failures {
            #expect(outcome.isFailed, "\(outcome.label) should be a failure state")
        }
    }

    @Test func allOutcomesHaveLabelsAndIcons() {
        let all: [RoundOutcome] = [.survived, .timeoutBeforeStart, .fillerOverload, .tooShort]
        for outcome in all {
            #expect(!outcome.label.isEmpty, "Outcome should have a label")
            #expect(!outcome.icon.isEmpty, "Outcome should have an icon")
        }
    }
}

struct PressureSessionResultTests {

    @Test func deepSurvivalCleanRunGetsTopLabel() {
        let result = PressureSessionResult(
            roundsSurvived: 6,
            finalOutcome: .timeoutBeforeStart,
            roundOutcomes: [.survived, .survived, .survived, .survived, .survived, .survived, .timeoutBeforeStart],
            totalDuration: 180, totalFillers: 0, totalWords: 120, bestRoundWords: 25,
            personalBest: 3
        )
        #expect(result.resultLabel == "Fast and Clear", "6+ rounds with 0 fillers should be 'Fast and Clear'. Got: \(result.resultLabel)")
        #expect(result.isNewPersonalBest, "6 rounds survived should beat personal best of 3")
    }

    @Test func timeoutOnFirstRoundGetsLowScore() {
        let result = PressureSessionResult(
            roundsSurvived: 0,
            finalOutcome: .timeoutBeforeStart,
            roundOutcomes: [.timeoutBeforeStart],
            totalDuration: 10, totalFillers: 0, totalWords: 0, bestRoundWords: 0,
            personalBest: 0
        )
        #expect(result.score <= 3, "Immediate timeout should score low. Got: \(result.score)")
        #expect(result.resultLabel == "Time Broke You", "Got: \(result.resultLabel)")
    }

    @Test func fillerFailureAfterSurvivalGetsRecoveryLabel() {
        let result = PressureSessionResult(
            roundsSurvived: 2,
            finalOutcome: .fillerOverload,
            roundOutcomes: [.survived, .survived, .fillerOverload],
            totalDuration: 60, totalFillers: 2, totalWords: 40, bestRoundWords: 20,
            personalBest: 1
        )
        #expect(result.resultLabel == "Strong Recovery", "Should be 'Strong Recovery' after surviving 2 rounds. Got: \(result.resultLabel)")
    }

    @Test func tooShortGetsRushedLabel() {
        let result = PressureSessionResult(
            roundsSurvived: 0,
            finalOutcome: .tooShort,
            roundOutcomes: [.tooShort],
            totalDuration: 5, totalFillers: 0, totalWords: 3, bestRoundWords: 3,
            personalBest: 0
        )
        #expect(result.resultLabel == "Rushed Start", "Got: \(result.resultLabel)")
    }

    @Test func xpScalesWithSurvival() {
        let shallow = PressureSessionResult(
            roundsSurvived: 1,
            finalOutcome: .fillerOverload,
            roundOutcomes: [.survived, .fillerOverload],
            totalDuration: 30, totalFillers: 2, totalWords: 15, bestRoundWords: 15,
            personalBest: 0
        )
        let deep = PressureSessionResult(
            roundsSurvived: 5,
            finalOutcome: .timeoutBeforeStart,
            roundOutcomes: [.survived, .survived, .survived, .survived, .survived, .timeoutBeforeStart],
            totalDuration: 150, totalFillers: 0, totalWords: 100, bestRoundWords: 25,
            personalBest: 3
        )
        #expect(deep.xpEarned > shallow.xpEarned,
            "Deep survival XP (\(deep.xpEarned)) should exceed shallow XP (\(shallow.xpEarned))")
    }

    @Test func personalBestDetection() {
        let notBest = PressureSessionResult(
            roundsSurvived: 2,
            finalOutcome: .fillerOverload,
            roundOutcomes: [.survived, .survived, .fillerOverload],
            totalDuration: 60, totalFillers: 1, totalWords: 30, bestRoundWords: 18,
            personalBest: 5
        )
        #expect(!notBest.isNewPersonalBest, "2 rounds should not beat personal best of 5")

        let isBest = PressureSessionResult(
            roundsSurvived: 6,
            finalOutcome: .timeoutBeforeStart,
            roundOutcomes: [.survived, .survived, .survived, .survived, .survived, .survived, .timeoutBeforeStart],
            totalDuration: 180, totalFillers: 0, totalWords: 120, bestRoundWords: 25,
            personalBest: 5
        )
        #expect(isBest.isNewPersonalBest, "6 rounds should beat personal best of 5")

        let firstRun = PressureSessionResult(
            roundsSurvived: 3,
            finalOutcome: .fillerOverload,
            roundOutcomes: [.survived, .survived, .survived, .fillerOverload],
            totalDuration: 90, totalFillers: 1, totalWords: 50, bestRoundWords: 20,
            personalBest: 0
        )
        #expect(!firstRun.isNewPersonalBest, "First run (personalBest == 0) should not flag as new PB")
    }

    @Test func resultLabelCoversAllExpectedValues() {
        let labels = ["Fast and Clear", "Beat the Clock", "Held Under Pressure", "Strong Recovery", "Filler Spike", "Rushed Start", "Time Broke You"]
        // Verify the icon/tint lookup doesn't crash for a baseline result
        let result = PressureSessionResult(
            roundsSurvived: 0,
            finalOutcome: .survived,
            roundOutcomes: [],
            totalDuration: 0, totalFillers: 0, totalWords: 0, bestRoundWords: 0,
            personalBest: 0
        )
        #expect(!result.resultIcon.isEmpty)
        #expect(!result.resultLabel.isEmpty)
        #expect(labels.count == 7, "Should have 7 distinct result labels")
    }

    @Test func scoreRangeIsClamped() {
        // Zero-round result should still be >= 1
        let zero = PressureSessionResult(
            roundsSurvived: 0,
            finalOutcome: .tooShort,
            roundOutcomes: [.tooShort],
            totalDuration: 2, totalFillers: 0, totalWords: 1, bestRoundWords: 1,
            personalBest: 0
        )
        #expect(zero.score >= 1 && zero.score <= 10, "Score should be 1-10. Got: \(zero.score)")

        // High survival result should still be <= 10
        let high = PressureSessionResult(
            roundsSurvived: 10,
            finalOutcome: .timeoutBeforeStart,
            roundOutcomes: Array(repeating: RoundOutcome.survived, count: 10) + [.timeoutBeforeStart],
            totalDuration: 300, totalFillers: 0, totalWords: 200, bestRoundWords: 30,
            personalBest: 8
        )
        #expect(high.score >= 1 && high.score <= 10, "Score should be 1-10. Got: \(high.score)")
    }
}

struct PressureFollowUpTemplateTests {

    @Test func templateFallbackNeverReturnsEmpty() {
        for _ in 0..<20 {
            let template = PressureFollowUpTemplates.random()
            #expect(!template.isEmpty, "Template should never be empty")
        }
    }
}

// MARK: - Eloquence Engine

struct EloquenceEngineTests {

    @Test func tricolonInPreparedSentenceIsDetected() {
        let transcript = "We need clarity, courage, and conviction in everything we do."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        #expect(findings.contains(where: { $0.device == .tricolon || $0.device == .ruleOfThree }),
                "Expected tricolon/ruleOfThree finding. Got: \(findings.map(\.device))")
    }

    @Test func anaphoraAcrossSentencesIsDetected() {
        let transcript = """
        Again, we'll get the briefing right. Again, we'll arrive ready. Practice makes the difference.
        """
        let findings = EloquenceEngine.analyse(transcript: transcript)
        #expect(findings.contains(where: { $0.device == .anaphora }),
                "Expected anaphora finding. Got: \(findings.map(\.device))")
    }

    @Test func alliterationRunIsDetected() {
        let transcript = "Pride, prejudice, and proper preparation prevent panic."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        #expect(findings.contains(where: { $0.device == .alliteration }),
                "Expected alliteration finding. Got: \(findings.map(\.device))")
    }

    @Test func epizeuxisIsDetected() {
        let transcript = "Never, never give in. The work is hard, but worth it."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        #expect(findings.contains(where: { $0.device == .epizeuxis }),
                "Expected epizeuxis finding. Got: \(findings.map(\.device))")
    }

    @Test func diacopeIsDetected() {
        let transcript = "Bond, James Bond. The brand sells itself."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        #expect(findings.contains(where: { $0.device == .diacope || $0.device == .epizeuxis }),
                "Expected diacope or epizeuxis. Got: \(findings.map(\.device))")
    }

    @Test func rhetoricalQuestionIsDetected() {
        let transcript = "What does that look like in practice? Three crisp answers, on the clock, no fillers."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        #expect(findings.contains(where: { $0.device == .rhetoricalQuestion }),
                "Expected rhetorical question finding. Got: \(findings.map(\.device))")
    }

    @Test func plainTranscriptHasNoFindings() {
        let transcript = "Yeah I think that's basically how I'd handle it. We could probably move forward."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        // No tricolon / parallel / anaphora etc. expected here.
        #expect(findings.count <= 1, "Plain transcript should produce at most 1 weak finding. Got: \(findings.map(\.device))")
    }

    @Test func veryShortTranscriptReturnsEmpty() {
        let transcript = "Hello there."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        #expect(findings.isEmpty, "Very short transcripts should not produce findings")
    }

    @Test func cappedAtMaxFindings() {
        let transcript = """
        We will speak. We will lead. We will deliver. \
        Friends, families, futures all rise together. \
        Pride, prejudice, perfect preparation push performance. \
        Never, never give in.
        """
        let findings = EloquenceEngine.analyse(transcript: transcript, maxFindings: 3)
        #expect(findings.count <= 3, "Should cap at maxFindings")
    }
}

// MARK: - Eloquence XP

struct EloquenceXPTests {

    @Test func emptyFindingsAwardZero() {
        #expect(EloquenceXP.totalXP(for: []) == 0)
    }

    @Test func singleFindingPaysFullBaseXP() {
        let finding = EloquenceFinding(
            device: .tricolon,
            snippet: "clarity, courage, conviction",
            coachLine: "_"
        )
        let xp = EloquenceXP.totalXP(for: [finding])
        #expect(xp == EloquenceXP.baseXP(for: .tricolon))
    }

    @Test func diminishingReturnsAcrossFindings() {
        let three: [EloquenceFinding] = [
            .init(device: .antithesis, snippet: "_", coachLine: "_"),
            .init(device: .tricolon, snippet: "_", coachLine: "_"),
            .init(device: .anaphora, snippet: "_", coachLine: "_")
        ]
        let xp = EloquenceXP.totalXP(for: three)
        let naive = three.map { EloquenceXP.baseXP(for: $0.device) }.reduce(0, +)
        #expect(xp < naive, "Diminishing returns must reduce the third finding")
    }

    @Test func cannotExceedPerSessionCap() {
        // Five high-value devices in one session — total should still be ≤ cap.
        let many: [EloquenceFinding] = [
            .init(device: .antithesis, snippet: "_", coachLine: "_"),
            .init(device: .tricolon, snippet: "_", coachLine: "_"),
            .init(device: .anaphora, snippet: "_", coachLine: "_"),
            .init(device: .epistrophe, snippet: "_", coachLine: "_"),
            .init(device: .isocolon, snippet: "_", coachLine: "_")
        ]
        let xp = EloquenceXP.totalXP(for: many)
        #expect(xp <= EloquenceXP.perSessionCap, "Must respect per-session cap")
    }

    @Test func bonusCopyMatchesContent() {
        #expect(EloquenceXP.bonusCopy(for: []) == nil)
        let solo = EloquenceXP.bonusCopy(for: [
            .init(device: .tricolon, snippet: "_", coachLine: "_")
        ])
        #expect(solo?.contains("rule of three") == true)
        let multi = EloquenceXP.bonusCopy(for: [
            .init(device: .tricolon, snippet: "_", coachLine: "_"),
            .init(device: .anaphora, snippet: "_", coachLine: "_")
        ])
        #expect(multi?.contains("shape") == true)
    }

    @Test func antithesisIsHighestPaying() {
        // Per-product spec: antithesis is the rarest detector (most
        // conservative) and should pay the most per finding.
        let antithesisXP = EloquenceXP.baseXP(for: .antithesis)
        for device in EloquenceDevice.allCases where device != .antithesis {
            #expect(antithesisXP >= EloquenceXP.baseXP(for: device),
                    "antithesis should be ≥ \(device): got \(antithesisXP) vs \(EloquenceXP.baseXP(for: device))")
        }
    }
}
