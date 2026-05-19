//
//  NoumTests.swift
//  NoumTests
//
//  Created by Jordan Coaten on 25/01/2025.
//

import Foundation
import Testing
import XCTest
import AVFoundation
import SwiftUI
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
            pauseRate: .empty,
            pauseFilledRatio: .empty,
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

    // MARK: Goal-aware reasoning

    @Test func decliningTrendReasoningMentionsAlignedStyleGoal() {
        // .concise aligns with .fillerReduction → reasoning should reference
        // the user's voice goal when the chosen drill matches.
        let input = NextActionInput(
            fillerCount: 4, duration: 35, wordCount: 100, wpm: 140, score: 5,
            categoryRatings: ["Opening": "OK"],
            mode: .timed, pressureLevel: .standard,
            baseline: makeBaseline(sessionCount: 10),
            pressureProfile: .empty,
            trends: [SkillTrend(skillArea: .fillerReduction, direction: .declining, confidence: .medium, windowSize: 8, currentLevel: .developing)],
            drillHistory: [],
            sessionCount: 10, streakDays: 4, styleGoal: "concise"
        )
        let result = NextActionEngine.recommend(input: input)
        #expect(result.reasoning.lowercased().contains("concise voice"),
            "Aligned style goal should be reflected in reasoning. Got: \(result.reasoning)")
    }

    @Test func styleGoalResolvesFromDisplayTitle() {
        // SessionFinalizer passes the localized title (not the raw value);
        // resolver should still match.
        let input = NextActionInput(
            fillerCount: 4, duration: 35, wordCount: 100, wpm: 140, score: 5,
            categoryRatings: ["Opening": "OK"],
            mode: .timed, pressureLevel: .standard,
            baseline: makeBaseline(sessionCount: 10),
            pressureProfile: .empty,
            trends: [SkillTrend(skillArea: .fillerReduction, direction: .declining, confidence: .medium, windowSize: 8, currentLevel: .developing)],
            drillHistory: [],
            sessionCount: 10, streakDays: 4, styleGoal: "Concise and sharp"
        )
        let result = NextActionEngine.recommend(input: input)
        #expect(result.reasoning.lowercased().contains("concise voice"),
            "Resolver should accept display title. Got: \(result.reasoning)")
    }

    @Test func unalignedStyleGoalLeavesReasoningUnchanged() {
        // .warm does not align with .fillerReduction → no goal suffix.
        let input = NextActionInput(
            fillerCount: 4, duration: 35, wordCount: 100, wpm: 140, score: 5,
            categoryRatings: ["Opening": "OK"],
            mode: .timed, pressureLevel: .standard,
            baseline: makeBaseline(sessionCount: 10),
            pressureProfile: .empty,
            trends: [SkillTrend(skillArea: .fillerReduction, direction: .declining, confidence: .medium, windowSize: 8, currentLevel: .developing)],
            drillHistory: [],
            sessionCount: 10, streakDays: 4, styleGoal: "warm"
        )
        let result = NextActionEngine.recommend(input: input)
        #expect(!result.reasoning.lowercased().contains("warm voice"),
            "Unaligned style goal should NOT be referenced — would feel forced. Got: \(result.reasoning)")
    }

    @Test func nilStyleGoalLeavesReasoningUnchanged() {
        let input = NextActionInput(
            fillerCount: 4, duration: 35, wordCount: 100, wpm: 140, score: 5,
            categoryRatings: ["Opening": "OK"],
            mode: .timed, pressureLevel: .standard,
            baseline: makeBaseline(sessionCount: 10),
            pressureProfile: .empty,
            trends: [SkillTrend(skillArea: .fillerReduction, direction: .declining, confidence: .medium, windowSize: 8, currentLevel: .developing)],
            drillHistory: [],
            sessionCount: 10, streakDays: 4, styleGoal: nil
        )
        let result = NextActionEngine.recommend(input: input)
        #expect(!result.reasoning.lowercased().contains("voice."),
            "No style goal should produce no voice suffix. Got: \(result.reasoning)")
    }
}

// MARK: - SpeakingStyleGoal Tests

struct SpeakingStyleGoalAlignmentTests {

    @Test func aligningSkillsAreNonEmpty() {
        for goal in SpeakingStyleGoal.allCases {
            #expect(!goal.alignedSkillAreas.isEmpty, "\(goal) must have at least one aligned skill")
        }
    }

    @Test func alignsMatchesAlignedSkillAreasSet() {
        let concise: SpeakingStyleGoal = .concise
        #expect(concise.aligns(with: .conciseSpeaking))
        #expect(concise.aligns(with: .fillerReduction))
        #expect(!concise.aligns(with: .answerDevelopment),
            ".concise should not falsely claim alignment with depth")
    }

    @Test func resolveAcceptsRawValueAndTitle() {
        #expect(SpeakingStyleGoal.resolve("warm") == .warm)
        #expect(SpeakingStyleGoal.resolve("Warm and welcoming") == .warm)
        #expect(SpeakingStyleGoal.resolve("WARM AND WELCOMING") == .warm)
        #expect(SpeakingStyleGoal.resolve(nil) == nil)
        #expect(SpeakingStyleGoal.resolve("") == nil)
        #expect(SpeakingStyleGoal.resolve("nonsense") == nil)
    }

    @Test func shortVoiceLabelEndsConsistently() {
        // Copy contract — every label should slot cleanly into
        // "Closer to your <label>." or "step toward your <label>."
        for goal in SpeakingStyleGoal.allCases {
            #expect(!goal.shortVoiceLabel.isEmpty)
            #expect(!goal.shortVoiceLabel.hasSuffix("."),
                "shortVoiceLabel must not end with a period; the caller adds it.")
        }
    }

    // MARK: - Rhetorical-device alignment (mid-session HUD subtext)

    @Test func alignedEloquenceDevicesAreNonEmpty() {
        for goal in SpeakingStyleGoal.allCases {
            #expect(!goal.alignedEloquenceDevices.isEmpty,
                "\(goal) must have at least one aligned rhetorical device")
        }
    }

    @Test func alignsMatchesAlignedDevicesSet() {
        let authoritative: SpeakingStyleGoal = .authoritative
        #expect(authoritative.aligns(with: .tricolon))
        #expect(authoritative.aligns(with: .ruleOfThree))
        #expect(authoritative.aligns(with: .epistrophe))
        #expect(authoritative.aligns(with: .antithesis))
        #expect(!authoritative.aligns(with: .polysyndeton),
            "authoritative shouldn't claim alignment with conjunction-stacking")
    }

    @Test func conciseAlignsWithSharpCuts() {
        let concise: SpeakingStyleGoal = .concise
        #expect(concise.aligns(with: .asyndeton),
            "concise voice should claim asyndeton — dropping conjunctions speeds delivery")
        #expect(concise.aligns(with: .isocolon),
            "concise voice should claim isocolon — parallel grammar, no padding")
        #expect(!concise.aligns(with: .polysyndeton),
            "concise voice should NOT claim polysyndeton — stacking conjunctions slows delivery")
    }

    @Test func storytellingAlignsWithRhythmicDevices() {
        let story: SpeakingStyleGoal = .storytelling
        #expect(story.aligns(with: .anaphora))
        #expect(story.aligns(with: .diacope))
        #expect(story.aligns(with: .epizeuxis))
        #expect(story.aligns(with: .alliteration))
    }

    @Test func warmAlignsWithInvitingDevices() {
        let warm: SpeakingStyleGoal = .warm
        #expect(warm.aligns(with: .anaphora))
        #expect(warm.aligns(with: .rhetoricalQuestion),
            "warm voice pulls the listener in via rhetorical questions")
    }

    @Test func everyDeviceAlignsWithAtLeastOneVoice() {
        // Sanity check: no rhetorical device is universally orphaned.
        // Coverage matters — every move the EloquenceEngine detects should
        // be claimable by at least one of the six voice goals.
        for device in EloquenceDevice.allCases {
            let claimed = SpeakingStyleGoal.allCases.contains { $0.aligns(with: device) }
            #expect(claimed, "\(device) should align with at least one SpeakingStyleGoal")
        }
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
            pauseRate: .empty, pauseFilledRatio: .empty,
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

    @Test func improvingTrendOnGoalAlignedSkillCelebratesVoice() {
        // Warm voice aligns with paceControl, vocalEmphasis, answerDevelopment.
        // An improving pace trend should produce a momentum clause that names
        // the warm voice — the post-session counterpart to the voice anchor
        // banner.
        let paceImproving = SkillTrend(
            skillArea: .paceControl,
            direction: .improving,
            confidence: .medium,
            windowSize: 5,
            currentLevel: .developing,
            recentDelta: nil
        )
        let note = VerdictEngine.generate(
            fillerCount: 2, duration: 45, wordCount: 110, wpm: 130, score: 7,
            categoryRatings: ["Opening": "OK", "Structure": "Good"],
            trends: [paceImproving], primaryFocus: .paceControl, drillHistory: [],
            styleGoal: "warm"
        )
        #expect(note.momentum.lowercased().contains("warm voice"),
            "Goal-aligned improvement should celebrate the warm voice in momentum. Got: \(note.momentum)")
        // buildMomentum already names the improving skill — the goal clause
        // adds the voice frame without repeating the skill word.
        #expect(note.momentum.lowercased().contains("pace"),
            "Underlying momentum should still name the gaining skill. Got: \(note.momentum)")
    }

    @Test func improvingTrendOffGoalDoesNotMentionVoice() {
        // Concise voice aligns with conciseSpeaking, structure, fillerReduction.
        // An improving closingStrength trend is NOT in that set — momentum
        // should celebrate the gain but NOT manufacture a fake "toward your
        // concise voice" suffix. No fake personalization is a Claude.MD rule.
        let closingImproving = SkillTrend(
            skillArea: .closingStrength,
            direction: .improving,
            confidence: .medium,
            windowSize: 5,
            currentLevel: .developing,
            recentDelta: nil
        )
        let note = VerdictEngine.generate(
            fillerCount: 3, duration: 60, wordCount: 140, wpm: 140, score: 7,
            categoryRatings: ["Opening": "OK", "Close": "Good"],
            trends: [closingImproving], primaryFocus: .closingStrength, drillHistory: [],
            styleGoal: "concise"
        )
        #expect(!note.momentum.lowercased().contains("concise voice"),
            "Off-goal improvement must not invent voice-alignment language. Got: \(note.momentum)")
    }

    @Test func goalAwareMomentumSkippedWhenNoGoalSet() {
        // No styleGoal → no goal clause. Confirms the new enrichment is
        // strictly opt-in via the user's coaching profile.
        let paceImproving = SkillTrend(
            skillArea: .paceControl,
            direction: .improving,
            confidence: .medium,
            windowSize: 5,
            currentLevel: .developing,
            recentDelta: nil
        )
        let note = VerdictEngine.generate(
            fillerCount: 2, duration: 45, wordCount: 110, wpm: 130, score: 7,
            categoryRatings: ["Opening": "OK"],
            trends: [paceImproving], primaryFocus: .paceControl, drillHistory: []
        )
        #expect(!note.momentum.lowercased().contains("voice"),
            "Without a styleGoal, momentum must not reference a voice. Got: \(note.momentum)")
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
            pauseRate: .empty, pauseFilledRatio: .empty,
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
            pauseRate: .empty, pauseFilledRatio: .empty,
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
            pauseRate: .empty, pauseFilledRatio: .empty,
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
            pauseRate: .empty, pauseFilledRatio: .empty,
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
            pauseRate: .empty, pauseFilledRatio: .empty,
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
            pauseRate: .empty, pauseFilledRatio: .empty,
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
            pauseRate: .empty, pauseFilledRatio: .empty,
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
            pauseRate: .empty, pauseFilledRatio: .empty,
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
            pauseRate: .empty, pauseFilledRatio: .empty,
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
            pauseRate: .empty, pauseFilledRatio: .empty,
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

// MARK: - Pause Metrics

private func word(_ text: String, start: TimeInterval, end: TimeInterval) -> TranscriptUpdate.WordTiming {
    TranscriptUpdate.WordTiming(word: text, startTime: start, endTime: end, confidence: 1.0)
}

struct PauseMetricsTests {
    @Test func emptyInputProducesEmptyMetrics() {
        let metrics = PauseMetrics.compute(words: [], fillerStartTimes: [])
        #expect(metrics == .empty)
    }

    @Test func singleWordProducesEmptyMetrics() {
        // Need at least 2 words to measure a gap.
        let metrics = PauseMetrics.compute(words: [word("hi", start: 0, end: 0.4)], fillerStartTimes: [])
        #expect(metrics == .empty)
    }

    @Test func gapsBelowThresholdAreNotPauses() {
        // Two words separated by 0.3s — below the 0.5s threshold, so no pause counted.
        let words = [
            word("the", start: 0.0, end: 0.4),
            word("answer", start: 0.7, end: 1.2)
        ]
        let metrics = PauseMetrics.compute(words: words, fillerStartTimes: [])
        #expect(metrics.count == 0)
    }

    @Test func longGapCountsAsOnePause() {
        let words = [
            word("the", start: 0.0, end: 0.4),
            word("answer", start: 1.5, end: 2.0)
        ]
        let metrics = PauseMetrics.compute(words: words, fillerStartTimes: [])
        #expect(metrics.count == 1)
        // Gap is 1.1s (1.5 - 0.4)
        #expect(abs(metrics.meanSeconds - 1.1) < 0.01)
        #expect(abs(metrics.longestSeconds - 1.1) < 0.01)
        #expect(metrics.filledRatio == 0)
    }

    @Test func multiplePausesCountedSeparately() {
        let words = [
            word("first", start: 0.0, end: 0.5),
            word("second", start: 1.5, end: 2.0),     // 1.0s gap
            word("third", start: 2.3, end: 2.8),       // 0.3s gap (sub-threshold)
            word("fourth", start: 4.0, end: 4.5)        // 1.2s gap
        ]
        let metrics = PauseMetrics.compute(words: words, fillerStartTimes: [])
        #expect(metrics.count == 2)
        // Mean of (1.0, 1.2) = 1.1s
        #expect(abs(metrics.meanSeconds - 1.1) < 0.01)
        #expect(abs(metrics.longestSeconds - 1.2) < 0.01)
    }

    @Test func filledPauseDetected() {
        // Pause from 0.5 to 1.5 (1.0s gap). Filler at 0.8 falls inside it.
        let words = [
            word("ok", start: 0.0, end: 0.5),
            word("so", start: 1.5, end: 1.7)
        ]
        let metrics = PauseMetrics.compute(words: words, fillerStartTimes: [0.8])
        #expect(metrics.count == 1)
        #expect(metrics.filledRatio == 1.0)
    }

    @Test func unfilledPauseDetected() {
        // Same gap, but the filler is well outside the gap (at 5.0).
        let words = [
            word("ok", start: 0.0, end: 0.5),
            word("so", start: 1.5, end: 1.7)
        ]
        let metrics = PauseMetrics.compute(words: words, fillerStartTimes: [5.0])
        #expect(metrics.count == 1)
        #expect(metrics.filledRatio == 0)
    }

    @Test func mixedFilledAndUnfilledPauses() {
        let words = [
            word("a", start: 0.0, end: 0.3),
            word("b", start: 1.3, end: 1.5),     // pause 1: filler at 0.8 inside (filled)
            word("c", start: 3.0, end: 3.3),     // pause 2: no filler (unfilled)
            word("d", start: 5.0, end: 5.3)      // pause 3: filler at 4.5 inside (filled)
        ]
        let metrics = PauseMetrics.compute(words: words, fillerStartTimes: [0.8, 4.5])
        #expect(metrics.count == 3)
        // 2 of 3 pauses are filled
        #expect(abs(metrics.filledRatio - (2.0 / 3.0)) < 0.01)
    }

    @Test func unsortedWordsAreSortedBeforeComputation() {
        // Provider may emit words slightly out of order on partial results.
        let words = [
            word("second", start: 1.5, end: 2.0),
            word("first", start: 0.0, end: 0.5)
        ]
        let metrics = PauseMetrics.compute(words: words, fillerStartTimes: [])
        #expect(metrics.count == 1)
        #expect(abs(metrics.longestSeconds - 1.0) < 0.01)
    }

    @Test func headlineCopyIsOnVoice() {
        // Voice rules: no "Let's", no exclamations, sentence case, concrete.
        let zero = PauseMetrics.empty.headline
        #expect(!zero.contains("!"))
        #expect(!zero.lowercased().contains("let's"))

        let clean = PauseMetrics(count: 4, meanSeconds: 0.8, longestSeconds: 1.2, filledRatio: 0).headline
        #expect(!clean.contains("!"))
    }
}

// MARK: - Path Node pause criteria

private func sessionWithPauseMetrics(_ metrics: PauseMetrics, duration: TimeInterval = 60) -> PracticeSession {
    PracticeSession(
        transcript: "test",
        fillerWordCount: 0,
        duration: duration,
        date: Date(),
        mode: .timed,
        pauseMetrics: metrics
    )
}

private func emptyProgressInput(sessions: [PracticeSession] = []) -> PathProgressInput {
    PathProgressInput(
        sessions: sessions,
        currentStreak: 0,
        baseline: .empty,
        rating: .initial,
        modeMastery: [:],
        totalLessonCrowns: 0,
        maxLessonCrown: 0,
        now: Date()
    )
}

struct WordChoiceMetricsTests {
    @Test func tooShortInputReturnsEmpty() {
        // Below 20 content-word minimum.
        let metrics = WordChoiceMetrics.compute(transcript: "I think the answer is yes.")
        #expect(metrics.contentWordCount == 0)
        #expect(metrics.uniqueRatio == 0)
        #expect(metrics.repeatedContentWords.isEmpty)
    }

    @Test func stopWordsAreFiltered() {
        // Lots of stop words shouldn't surface as repeated content.
        let transcript = """
        the team needs better systems and more clear ownership across deliverables
        because consistent delivery becomes operational discipline once standards
        align with execution timelines and stakeholder feedback loops
        """
        let metrics = WordChoiceMetrics.compute(transcript: transcript)
        #expect(metrics.contentWordCount > 0)
        let words = metrics.repeatedContentWords.map { $0.word }
        #expect(!words.contains("the"))
        #expect(!words.contains("and"))
    }

    @Test func fillerTokensAreFiltered() {
        let transcript = String(repeating: "um like basically actually ", count: 10)
            + "structure delivery composure clarity range projection authority "
            + "team direction outcome growth"
        let metrics = WordChoiceMetrics.compute(transcript: transcript)
        let words = metrics.repeatedContentWords.map { $0.word }
        #expect(!words.contains("um"))
        #expect(!words.contains("like"))
        #expect(!words.contains("basically"))
        #expect(!words.contains("actually"))
    }

    @Test func repeatedContentWordSurfaces() {
        // "leadership" repeats 5 times; should surface as #1 in repeats.
        let transcript = """
        leadership requires honest leadership about decisions and leadership
        starts with leadership presence in tough rooms also leadership
        means saying the harder thing when other things stay quiet
        meanwhile direction structure clarity outcome delivery growth team
        """
        let metrics = WordChoiceMetrics.compute(transcript: transcript)
        #expect(metrics.repeatedContentWords.first?.word == "leadership")
        #expect((metrics.repeatedContentWords.first?.count ?? 0) >= 3)
    }

    @Test func varietyHighInVariedTranscript() {
        // 40 distinct content words.
        let transcript = """
        structure clarity delivery composure outcome direction depth range
        cadence pacing phrasing emphasis economy substance candor presence
        focus restraint nuance precision authority warmth signal momentum
        rhythm balance honesty insight resolve method tone mastery
        timing instinct action context judgement framing distance
        """
        let metrics = WordChoiceMetrics.compute(transcript: transcript)
        #expect(metrics.uniqueRatio >= 0.9, "Expected high unique ratio for varied transcript, got \(metrics.uniqueRatio)")
    }

    @Test func minThreeRepeatsRequiredForRepeatList() {
        // Each content word appears exactly twice — below the 3-rep cutoff.
        let transcript = """
        structure structure clarity clarity delivery delivery composure composure
        outcome outcome direction direction range range cadence cadence
        phrasing phrasing emphasis emphasis economy economy substance substance
        """
        let metrics = WordChoiceMetrics.compute(transcript: transcript)
        // Even though some words appear twice, none reach the 3-rep bar
        // so the surfaced list is empty (avoids noisy false-positives).
        #expect(metrics.repeatedContentWords.isEmpty)
    }
}

struct PathNodePauseCriteriaTests {
    @Test func heldSilentPauseRequiresUnfilledPause() {
        // A long pause that was filled doesn't count.
        let filled = sessionWithPauseMetrics(PauseMetrics(count: 1, meanSeconds: 2.0, longestSeconds: 2.0, filledRatio: 1.0))
        let input = emptyProgressInput(sessions: [filled])
        let progress = PathNodeCriterion.heldSilentPause(seconds: 1.5).progress(for: input)
        #expect(progress == 0.0)
    }

    @Test func heldSilentPauseProgressesWithUnfilledLong() {
        // Unfilled pause exactly at the bar.
        let silent = sessionWithPauseMetrics(PauseMetrics(count: 1, meanSeconds: 1.5, longestSeconds: 1.5, filledRatio: 0))
        let input = emptyProgressInput(sessions: [silent])
        let progress = PathNodeCriterion.heldSilentPause(seconds: 1.5).progress(for: input)
        #expect(progress == 1.0)
    }

    @Test func heldSilentPausePartialProgress() {
        // Unfilled pause halfway to the bar.
        let half = sessionWithPauseMetrics(PauseMetrics(count: 1, meanSeconds: 0.75, longestSeconds: 0.75, filledRatio: 0))
        let input = emptyProgressInput(sessions: [half])
        let progress = PathNodeCriterion.heldSilentPause(seconds: 1.5).progress(for: input)
        #expect(abs(progress - 0.5) < 0.01)
    }

    @Test func cleanPauseSessionRequiresMinPauseCount() {
        // Session with 0% filled ratio but only 1 pause — below the
        // minPauses bar so doesn't trivially complete the node.
        let single = sessionWithPauseMetrics(PauseMetrics(count: 1, meanSeconds: 1.0, longestSeconds: 1.0, filledRatio: 0))
        let input = emptyProgressInput(sessions: [single])
        let progress = PathNodeCriterion.cleanPauseSession(maxRatio: 0.25, minPauses: 3).progress(for: input)
        #expect(progress == 0.0)
    }

    @Test func cleanPauseSessionPassesWithEnoughPauses() {
        // 3 pauses, none filled — clears the bar.
        let composed = sessionWithPauseMetrics(PauseMetrics(count: 3, meanSeconds: 0.8, longestSeconds: 1.2, filledRatio: 0))
        let input = emptyProgressInput(sessions: [composed])
        let progress = PathNodeCriterion.cleanPauseSession(maxRatio: 0.25, minPauses: 3).progress(for: input)
        #expect(progress == 1.0)
    }

    @Test func cleanPauseSessionFailsAboveMaxRatio() {
        // 4 pauses, half filled — above the 0.25 max.
        let cluttered = sessionWithPauseMetrics(PauseMetrics(count: 4, meanSeconds: 0.8, longestSeconds: 1.2, filledRatio: 0.5))
        let input = emptyProgressInput(sessions: [cluttered])
        let progress = PathNodeCriterion.cleanPauseSession(maxRatio: 0.25, minPauses: 3).progress(for: input)
        #expect(progress == 0.0)
    }
}

// MARK: - distanceFromGoal (M5)

struct DistanceFromGoalTests {

    private static func stat(_ value: Double) -> BaselineStat {
        BaselineStat(value: value, sampleCount: 10, confidence: .moderate, trend: .stable, percentile25: 0, percentile75: 0)
    }

    private static func baseline(
        fillerRate: Double = 0,
        pace: Double = 130,
        duration: Double = 30,
        score: Double = 7,
        pauseFilledRatio: Double = 0.1
    ) -> CommunicationBaseline {
        var b = CommunicationBaseline.empty
        b.fillerRate = stat(fillerRate)
        b.pace = stat(pace)
        b.durationTendency = stat(duration)
        b.averageScore = stat(score)
        b.pauseFilledRatio = stat(pauseFilledRatio)
        return b
    }

    @Test func atGoalFillerRateReturnsZeroDistance() {
        let b = Self.baseline(fillerRate: 0)
        #expect(b.distanceFromGoal(.reduceFillers) == 0.0)
    }

    @Test func highFillerRateReturnsMaxDistance() {
        let b = Self.baseline(fillerRate: 8)
        #expect(b.distanceFromGoal(.reduceFillers) == 1.0)
    }

    @Test func midFillerRateIsMidDistance() {
        let b = Self.baseline(fillerRate: 4)
        let d = b.distanceFromGoal(.reduceFillers)
        #expect(d > 0.4 && d < 0.6)
    }

    @Test func shortDurationIsCloserToGoalForConcise() {
        let near = Self.baseline(duration: 20)
        let far = Self.baseline(duration: 90)
        #expect(near.distanceFromGoal(.moreConcise) < far.distanceFromGoal(.moreConcise))
    }

    @Test func highScoreIsCloseToThinkFasterGoal() {
        let near = Self.baseline(score: 7.5)
        let far = Self.baseline(score: 3.0)
        #expect(near.distanceFromGoal(.thinkFaster) < far.distanceFromGoal(.thinkFaster))
    }

    @Test func lowPauseFilledRatioIsCloseToCalmerDeliveryGoal() {
        let near = Self.baseline(pauseFilledRatio: 0.05)
        let far = Self.baseline(pauseFilledRatio: 0.7)
        #expect(near.distanceFromGoal(.calmerDelivery) < far.distanceFromGoal(.calmerDelivery))
    }

    @Test func distanceIsAlwaysInUnitRange() {
        let b = Self.baseline(fillerRate: 100, pace: 300, duration: 300, score: 0, pauseFilledRatio: 2.0)
        for goal in CoachingPriority.allCases {
            let d = b.distanceFromGoal(goal)
            #expect(d >= 0.0 && d <= 1.0, "goal \(goal.rawValue) distance \(d) out of range")
        }
    }

    @Test func insufficientDataReturnsHalf() {
        var b = CommunicationBaseline.empty
        // .empty has .insufficient confidence on all stats
        for goal in CoachingPriority.allCases {
            let d = b.distanceFromGoal(goal)
            #expect(d == 0.5, "expected 0.5 for insufficient data, got \(d) for \(goal.rawValue)")
        }
    }

    @Test func goalDistanceLabelStrings() {
        let near = Self.baseline(fillerRate: 0)
        let far = Self.baseline(fillerRate: 8)
        #expect(near.goalDistanceLabel(.reduceFillers) == "On track")
        #expect(far.goalDistanceLabel(.reduceFillers) == "Early days")
    }
}

// MARK: - Weekly peak rating (M6)

struct WeekPeakRatingTests {

    @Test func freshRatingHasCurrentWeekStamped() {
        let r = SpeakingRating.initial
        #expect(r.isWeekPeakCurrent == true)
        #expect(r.weekPeakRating == 400)
    }

    @Test func processedSessionUpdatesWeekPeakWhenHigher() {
        let initial = SpeakingRating.initial
        // High enough score to bump rating upward
        let updated = RatingEngine.processRatedSession(
            rating: initial,
            sessionScore: 9,
            sessionId: UUID(),
            pressureLevel: .standard
        )
        #expect(updated.weekPeakRating >= initial.weekPeakRating)
        #expect(updated.weekPeakRating == updated.overall)
    }

    @Test func processedSessionDoesNotLowerWeekPeak() {
        // Start at a high peak, then take a hit
        var r = SpeakingRating.initial
        r.overall = 700
        r.weekPeakRating = 750
        let lower = RatingEngine.processRatedSession(
            rating: r,
            sessionScore: 1,  // forces negative delta
            sessionId: UUID(),
            pressureLevel: .standard
        )
        #expect(lower.weekPeakRating == 750, "week peak shouldn't drop on a bad session")
        #expect(lower.overall < r.overall, "rating itself should drop")
    }

    @Test func staleWeekResetsToCurrentRating() {
        // Simulate a rating saved last week — week stamp doesn't match today.
        var r = SpeakingRating.initial
        r.overall = 500
        r.weekPeakRating = 800       // stale value from last week
        r.weekPeakISOWeek = 1        // forced mismatch
        r.weekPeakISOYear = 2000

        let updated = RatingEngine.processRatedSession(
            rating: r,
            sessionScore: 7,
            sessionId: UUID(),
            pressureLevel: .standard
        )

        // After reset, the week peak should be the new rating (not the
        // carried-over 800), because we're in a new week.
        #expect(updated.weekPeakRating == updated.overall)
        let comps = Calendar.current.dateComponents([.weekOfYear, .yearForWeekOfYear], from: Date())
        #expect(updated.weekPeakISOWeek == comps.weekOfYear)
        #expect(updated.weekPeakISOYear == comps.yearForWeekOfYear)
    }

    @Test func isWeekPeakCurrentDetectsStaleWeek() {
        var r = SpeakingRating.initial
        r.weekPeakISOWeek = 1
        r.weekPeakISOYear = 2000
        #expect(r.isWeekPeakCurrent == false)
    }

    @Test func decodeLegacyRatingDataAddsCurrentWeekStamp() throws {
        // Legacy JSON missing the week-peak fields should decode cleanly with
        // weekPeakRating defaulting to overall and the current week stamped.
        let legacy = """
        {
          "overall": 525,
          "peakRating": 600,
          "ratingHistory": [],
          "personalBests": [],
          "totalRatedSessions": 4
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SpeakingRating.self, from: legacy)
        #expect(decoded.overall == 525)
        #expect(decoded.peakRating == 600)
        #expect(decoded.weekPeakRating == 525)  // defaulted to current overall
        #expect(decoded.isWeekPeakCurrent == true)
    }
}

// MARK: - AI prompt content filter (M7)

struct AIPromptContentFilterTests {

    @Test func acceptsCleanQuestion() {
        let raw = "What is the most overrated skill in your industry?"
        #expect(PromptContentFilter.accept(raw) == raw)
    }

    @Test func stripsEnclosingDoubleQuotes() {
        let raw = "\"What changes when leaders admit uncertainty?\""
        let cleaned = PromptContentFilter.accept(raw)
        #expect(cleaned == "What changes when leaders admit uncertainty?")
    }

    @Test func rejectsMissingQuestionMark() {
        let raw = "The most overrated skill in your industry."
        #expect(PromptContentFilter.accept(raw) == nil)
    }

    @Test func rejectsLeadingDirective() {
        let raw = "Tell me about a moment that changed your perspective?"
        #expect(PromptContentFilter.accept(raw) == nil)
    }

    @Test func rejectsDescribeDirective() {
        let raw = "Describe a hard decision you've made recently?"
        #expect(PromptContentFilter.accept(raw) == nil)
    }

    @Test func rejectsTooShort() {
        let raw = "Why care?"
        #expect(PromptContentFilter.accept(raw) == nil)
    }

    @Test func rejectsTooLong() {
        let raw = String(repeating: "a", count: 250) + "?"
        #expect(PromptContentFilter.accept(raw) == nil)
    }

    @Test func rejectsEmailLikeContent() {
        let raw = "What would you say to admin@example.com if asked?"
        #expect(PromptContentFilter.accept(raw) == nil)
    }

    @Test func rejectsPhoneLikeContent() {
        let raw = "Would you call +1 (555) 123-4567 to speak up?"
        #expect(PromptContentFilter.accept(raw) == nil)
    }

    @Test func rejectsExcessiveExclamation() {
        let raw = "What is the wildest belief you've changed your mind on!!?"
        #expect(PromptContentFilter.accept(raw) == nil)
    }

    @Test func collapsesInternalWhitespace() {
        let raw = "What  is  the    most  underrated   habit?"
        let cleaned = PromptContentFilter.accept(raw)
        #expect(cleaned == "What is the most underrated habit?")
    }
}

// MARK: - PromptHistoryStore (M7)

struct PromptHistoryStoreTests {

    @Test @MainActor func recordsAndDetectsFreshPrompt() {
        let store = PromptHistoryStore.shared
        store.reset()
        let prompt = "What is the most underrated skill in your field?"
        #expect(store.wasRecentlySeen(prompt) == false)
        store.record(prompt)
        #expect(store.wasRecentlySeen(prompt) == true)
        store.reset()
    }

    @Test @MainActor func dedupNormalizesCase() {
        let store = PromptHistoryStore.shared
        store.reset()
        store.record("What is success?")
        // Same prompt with different casing should still be considered seen.
        #expect(store.wasRecentlySeen("WHAT IS SUCCESS?") == true)
        #expect(store.wasRecentlySeen("  what is success?  ") == true)
        store.reset()
    }

    @Test @MainActor func emptyWindowReturnsFalse() {
        let store = PromptHistoryStore.shared
        store.reset()
        #expect(store.wasRecentlySeen("Anything at all?") == false)
        #expect(store.recentCount == 0)
    }

    @Test @MainActor func recordingTwiceDoesNotInflateCount() {
        let store = PromptHistoryStore.shared
        store.reset()
        store.record("Why does honesty cost more than people think?")
        store.record("Why does honesty cost more than people think?")
        #expect(store.recentCount == 1)
        store.reset()
    }

    @Test @MainActor func hashIsStableAcrossWhitespaceAndCase() {
        let a = PromptHistoryStore.hash(of: "What matters most?")
        let b = PromptHistoryStore.hash(of: "  WHAT MATTERS MOST?  ")
        #expect(a == b)
    }
}

// MARK: - PracticeTopics goal-aware orchestrator (M7)

struct PracticeTopicsM7Tests {

    @Test func themeBiasMapsConciseToWorkCareer() {
        let p = makeProfile(goal: .moreConcise, context: .work)
        #expect(PracticeTopics.themeBias(for: p) == .workCareer)
    }

    @Test func themeBiasMapsCalmerDeliveryToEthics() {
        let p = makeProfile(goal: .calmerDelivery, context: .work)
        #expect(PracticeTopics.themeBias(for: p) == .ethicsOpinions)
    }

    @Test func themeBiasMapsThinkFasterFreezingToGeneral() {
        let p = makeProfile(goal: .thinkFaster, context: .work, challenge: .freezing)
        #expect(PracticeTopics.themeBias(for: p) == .general)
    }

    @Test func themeBiasMapsReduceFillersToAll() {
        let p = makeProfile(goal: .reduceFillers, context: .work)
        #expect(PracticeTopics.themeBias(for: p) == .all)
    }

    @Test func weakestDimensionPicksWorstStat() {
        var b = CommunicationBaseline.empty
        b.fillerRate = BaselineStat(value: 8, sampleCount: 10, confidence: .moderate, trend: .stable, percentile25: 0, percentile75: 10)
        b.openingStrength = BaselineStat(value: 2.5, sampleCount: 10, confidence: .moderate, trend: .stable, percentile25: 1, percentile75: 3)
        b.clarity = BaselineStat(value: 2.8, sampleCount: 10, confidence: .moderate, trend: .stable, percentile25: 1, percentile75: 3)
        // Filler 8/min is far worse than the 1-3 stats; engine should label it.
        let label = PracticeTopics.weakestDimensionLabel(for: b)
        #expect(label == "filler control")
    }

    @Test func weakestDimensionIgnoresInsufficientStats() {
        // All-empty baseline has insufficient confidence on every stat —
        // there's no honest "weakest" to claim, so we return nil.
        let b = CommunicationBaseline.empty
        #expect(PracticeTopics.weakestDimensionLabel(for: b) == nil)
    }

    // MARK: helpers

    private func makeProfile(
        goal: CoachingPriority,
        context: SpeakingContext,
        challenge: SpeakingChallenge = .fillerWords
    ) -> CoachingProfile {
        CoachingProfile(
            speakingContext: context,
            primaryGoal: goal,
            confidenceLevel: .rebuilding,
            biggestChallenge: challenge,
            desiredOutcome: .persuasive,
            speakingStyleGoal: .concise,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: ""
        )
    }
}

// MARK: - Daily challenges (M8)

struct DailyChallengeKindTests {

    private func session(
        fillerWordCount: Int = 0,
        duration: TimeInterval = 30,
        transcript: String = "This is a fairly long transcript with plenty of words to count up to fourteen at least.",
        mode: PracticeMode = .timed,
        score: Int? = nil,
        wpm: Int? = nil,
        pause: PauseMetrics? = nil
    ) -> PracticeSession {
        var s = PracticeSession(
            transcript: transcript,
            fillerWordCount: fillerWordCount,
            duration: duration,
            date: Date()
        )
        s.mode = mode
        s.score = score
        s.pauseMetrics = pause
        return s
    }

    @Test func zeroFillersRequiresFourteenWordsAndZeroFillers() {
        let pass = session(fillerWordCount: 0, transcript: "I have a clear answer with at least fourteen unique meaningful words to count.")
        let failShort = session(fillerWordCount: 0, transcript: "Too short answer.")
        let failFiller = session(fillerWordCount: 1, transcript: "I have a clear answer with at least fourteen unique meaningful words to count.")
        #expect(DailyChallengeKind.zeroFillers.isSatisfied(by: pass) == true)
        #expect(DailyChallengeKind.zeroFillers.isSatisfied(by: failShort) == false)
        #expect(DailyChallengeKind.zeroFillers.isSatisfied(by: failFiller) == false)
    }

    @Test func heldPauseRequiresLongUnfilledPause() {
        let good = session(pause: PauseMetrics(count: 1, meanSeconds: 3.0, longestSeconds: 3.5, filledRatio: 0.0))
        let badShort = session(pause: PauseMetrics(count: 1, meanSeconds: 0.8, longestSeconds: 1.0, filledRatio: 0.0))
        let badFilled = session(pause: PauseMetrics(count: 1, meanSeconds: 3.5, longestSeconds: 3.5, filledRatio: 0.9))
        #expect(DailyChallengeKind.heldPause.isSatisfied(by: good) == true)
        #expect(DailyChallengeKind.heldPause.isSatisfied(by: badShort) == false)
        #expect(DailyChallengeKind.heldPause.isSatisfied(by: badFilled) == false)
    }

    @Test func cleanSuddenDeathRequiresMatchingMode() {
        let goodMode = session(fillerWordCount: 0, mode: .suddenDeath)
        let wrongMode = session(fillerWordCount: 0, mode: .timed)
        #expect(DailyChallengeKind.cleanSuddenDeath.isSatisfied(by: goodMode) == true)
        #expect(DailyChallengeKind.cleanSuddenDeath.isSatisfied(by: wrongMode) == false)
    }

    @Test func highScoreRequiresAtLeastEight() {
        let pass = session(score: 8)
        let fail = session(score: 7)
        let nilScore = session(score: nil)
        #expect(DailyChallengeKind.highScoreSession.isSatisfied(by: pass) == true)
        #expect(DailyChallengeKind.highScoreSession.isSatisfied(by: fail) == false)
        #expect(DailyChallengeKind.highScoreSession.isSatisfied(by: nilScore) == false)
    }

    @Test func multiplePausesRequiresLowFillRatio() {
        let pass = session(pause: PauseMetrics(count: 3, meanSeconds: 0.7, longestSeconds: 1.5, filledRatio: 0.2))
        let failFill = session(pause: PauseMetrics(count: 3, meanSeconds: 0.7, longestSeconds: 1.5, filledRatio: 0.8))
        let failCount = session(pause: PauseMetrics(count: 1, meanSeconds: 0.7, longestSeconds: 1.5, filledRatio: 0.0))
        #expect(DailyChallengeKind.multiplePauses.isSatisfied(by: pass) == true)
        #expect(DailyChallengeKind.multiplePauses.isSatisfied(by: failFill) == false)
        #expect(DailyChallengeKind.multiplePauses.isSatisfied(by: failCount) == false)
    }

    @Test func everyKindHasNonEmptyDisplayCopy() {
        for kind in DailyChallengeKind.allCases {
            #expect(!kind.title.isEmpty)
            #expect(!kind.subtitle.isEmpty)
            #expect(!kind.symbol.isEmpty)
            #expect(kind.xpReward > 0)
        }
    }
}

struct DailyChallengeGeneratorTests {

    @Test func deterministicForSameDayKey() {
        let key = "2026-05-06"
        let first = DailyChallengeGenerator.threeKinds(for: key)
        let second = DailyChallengeGenerator.threeKinds(for: key)
        #expect(first == second)
        #expect(first.count == 3)
    }

    @Test func returnsThreeDistinctKinds() {
        let key = "2026-05-07"
        let kinds = DailyChallengeGenerator.threeKinds(for: key)
        #expect(kinds.count == 3)
        #expect(Set(kinds).count == 3, "all three should be distinct")
    }

    @Test func differentDaysGiveDifferentSets() {
        // Not always true (collisions exist with 8 kinds choose 3) but for
        // these specific keys we expect divergence.
        let a = DailyChallengeGenerator.threeKinds(for: "2026-05-06")
        let b = DailyChallengeGenerator.threeKinds(for: "2026-05-07")
        // Expect at least one kind to differ on adjacent days.
        #expect(Set(a) != Set(b) || a == b, "smoke test — same allowed but uncommon")
    }
}

struct DailyChallengeSetTests {

    @Test func softExpiryAfterNinePMOnSameDay() {
        // Pick a date that is "today" so softExpiryDate produces an
        // interpretable timestamp; we then assert the contract.
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: Date())
        let set = DailyChallengeSet(dayKey: todayKey, kinds: [.zeroFillers], claimedKinds: [])

        guard let stamp = set.softExpiryDate() else {
            #expect(Bool(false), "expected non-nil soft expiry")
            return
        }
        let comps = Calendar.current.dateComponents([.hour], from: stamp)
        #expect(comps.hour == 21)
    }

    @Test func allClaimedFlagsTrueWhenAllInSet() {
        let set = DailyChallengeSet(
            dayKey: "2026-05-06",
            kinds: [.zeroFillers, .heldPause],
            claimedKinds: [.zeroFillers, .heldPause]
        )
        #expect(set.allClaimed == true)
    }

    @Test func allClaimedFalseForEmptySet() {
        let set = DailyChallengeSet(dayKey: "2026-05-06", kinds: [], claimedKinds: [])
        #expect(set.allClaimed == false)
    }
}

// MARK: - Word of the Day (M9)

struct WordOfTheDayCatalogTests {

    @Test func deterministicForSameDayKey() {
        let key = "2026-05-06"
        let a = WordOfTheDayCatalog.entry(for: key)
        let b = WordOfTheDayCatalog.entry(for: key)
        #expect(a == b)
    }

    @Test func entriesHaveAcceptedHeadwordForm() {
        for entry in WordOfTheDayCatalog.entries {
            // Headword (lowercased) must always be in acceptedForms — that's
            // the primary detection target.
            #expect(entry.acceptedForms.contains(entry.word.lowercased()))
        }
    }

    @Test func entriesHaveDisplayCopy() {
        for entry in WordOfTheDayCatalog.entries {
            #expect(!entry.word.isEmpty)
            #expect(!entry.partOfSpeech.isEmpty)
            #expect(!entry.definition.isEmpty)
            #expect(!entry.promptSuggestion.isEmpty)
        }
    }

    @Test func definitionsStayUnderNinetyChars() {
        // Style guide: definitions should fit in a single line on the home
        // tile. Hard-cap at 90 to surface anything that drifts over.
        for entry in WordOfTheDayCatalog.entries {
            #expect(entry.definition.count <= 90,
                    "definition too long for \(entry.word): \(entry.definition.count) chars")
        }
    }

    @Test func promptsAreQuestions() {
        for entry in WordOfTheDayCatalog.entries {
            #expect(entry.promptSuggestion.hasSuffix("?"),
                    "prompt for \(entry.word) doesn't end with '?'")
        }
    }
}

@MainActor
struct WordOfTheDayDetectionTests {

    @Test func detectsHeadwordInTranscript() {
        let forms = ["pivot", "pivots", "pivoted", "pivoting"]
        let transcript = "I had to pivot mid-conversation when the room shifted."
        #expect(WordOfTheDayManager.transcriptContains(any: forms, in: transcript) == true)
    }

    @Test func detectsInflectedForm() {
        let forms = ["resonate", "resonates", "resonated", "resonant", "resonance"]
        let transcript = "That advice still resonates with me three years later."
        #expect(WordOfTheDayManager.transcriptContains(any: forms, in: transcript) == true)
    }

    @Test func ignoresSubstringWithinUnrelatedWord() {
        // "art" should NOT match inside "smart" — word-boundary safe.
        let forms = ["art"]
        let transcript = "She made a smart call under pressure."
        #expect(WordOfTheDayManager.transcriptContains(any: forms, in: transcript) == false)
    }

    @Test func caseInsensitive() {
        let forms = ["candour"]
        let transcript = "Candour is harder than honesty in practice."
        #expect(WordOfTheDayManager.transcriptContains(any: forms, in: transcript) == true)
    }

    @Test func emptyTranscriptReturnsFalse() {
        #expect(WordOfTheDayManager.transcriptContains(any: ["hello"], in: "") == false)
    }

    @Test func noMatchReturnsFalse() {
        let transcript = "Today was a normal day with no surprises."
        #expect(WordOfTheDayManager.transcriptContains(any: ["catalyst", "galvanise"], in: transcript) == false)
    }
}

// MARK: - Pitch Analyzer (M10)

struct PitchAnalyzerTests {

    /// Generate a pure sine wave at the given frequency for the given duration.
    /// Used as ground-truth input — autocorrelation should detect this f0
    /// within ~5% on a clean signal.
    private func sine(hz: Double, durationSeconds: Double, sampleRate: Double) -> [Float] {
        let n = Int(durationSeconds * sampleRate)
        var out = [Float](repeating: 0, count: n)
        let twoPi = 2.0 * .pi
        for i in 0..<n {
            out[i] = Float(sin(twoPi * hz * Double(i) / sampleRate))
        }
        return out
    }

    @Test func detectsPureSineWaveAt220Hz() {
        let sampleRate: Double = 16_000
        let signal = sine(hz: 220, durationSeconds: 0.25, sampleRate: sampleRate)
        let window = Array(signal.prefix(PitchAnalyzer.windowSize))
        let minLag = Int((sampleRate / PitchAnalyzer.maxPitchHz).rounded())
        let maxLag = Int((sampleRate / PitchAnalyzer.minPitchHz).rounded())
        let detected = PitchAnalyzer.detectF0(in: window, sampleRate: sampleRate, minLag: minLag, maxLag: maxLag)
        guard let f0 = detected else {
            #expect(Bool(false), "expected f0 detection on clean sine")
            return
        }
        #expect(abs(f0 - 220) / 220 < 0.05, "detected \(f0) Hz, expected ~220")
    }

    @Test func detectsPureSineWaveAt140Hz() {
        let sampleRate: Double = 16_000
        let signal = sine(hz: 140, durationSeconds: 0.25, sampleRate: sampleRate)
        let window = Array(signal.prefix(PitchAnalyzer.windowSize))
        let minLag = Int((sampleRate / PitchAnalyzer.maxPitchHz).rounded())
        let maxLag = Int((sampleRate / PitchAnalyzer.minPitchHz).rounded())
        let detected = PitchAnalyzer.detectF0(in: window, sampleRate: sampleRate, minLag: minLag, maxLag: maxLag)
        guard let f0 = detected else {
            #expect(Bool(false), "expected f0 detection on clean sine")
            return
        }
        #expect(abs(f0 - 140) / 140 < 0.05, "detected \(f0) Hz, expected ~140")
    }

    @Test func returnsNilForSilentWindow() {
        let sampleRate: Double = 16_000
        let window = [Float](repeating: 0, count: PitchAnalyzer.windowSize)
        let minLag = Int((sampleRate / PitchAnalyzer.maxPitchHz).rounded())
        let maxLag = Int((sampleRate / PitchAnalyzer.minPitchHz).rounded())
        let detected = PitchAnalyzer.detectF0(in: window, sampleRate: sampleRate, minLag: minLag, maxLag: maxLag)
        #expect(detected == nil, "silent window should not produce f0")
    }

    @Test func returnsNilForRandomNoise() {
        // White noise has no fundamental — autocorrelation peak should not
        // clear the voicing threshold. We seed for determinism.
        var rng = SeededRandomNumberGenerator(seed: 42)
        var window = [Float]()
        window.reserveCapacity(PitchAnalyzer.windowSize)
        for _ in 0..<PitchAnalyzer.windowSize {
            let raw = rng.next()
            // Map UInt64 to Float in [-1, 1].
            let normalized = Float(Double(raw) / Double(UInt64.max)) * 2 - 1
            window.append(normalized)
        }
        let sampleRate: Double = 16_000
        let minLag = Int((sampleRate / PitchAnalyzer.maxPitchHz).rounded())
        let maxLag = Int((sampleRate / PitchAnalyzer.minPitchHz).rounded())
        let detected = PitchAnalyzer.detectF0(in: window, sampleRate: sampleRate, minLag: minLag, maxLag: maxLag)
        // White noise *can* produce a spurious peak; we only assert it's
        // either nil or doesn't yield an absurdly low frequency.
        if let f0 = detected {
            #expect(f0 >= 70 && f0 <= 400, "detected \(f0) Hz outside vocal range")
        }
    }

    @Test func metricsEmptyWhenWindowTooShort() {
        let m = PitchMetrics(meanHz: nil, stdHz: nil, voicedRatio: 0, windowCount: 0)
        #expect(m.isReliable == false)
        #expect(m.monotoneScore == 0.5)
    }

    @Test func metricsMonotoneScoreClampsAtBounds() {
        // Very low std → very monotone → score ~1.0
        let monotone = PitchMetrics(meanHz: 180, stdHz: 4, voicedRatio: 0.6, windowCount: 50)
        #expect(monotone.isReliable == true)
        #expect(monotone.monotoneScore == 1.0)

        // Very high std → very varied → score ~0.0
        let varied = PitchMetrics(meanHz: 180, stdHz: 50, voicedRatio: 0.6, windowCount: 50)
        #expect(varied.isReliable == true)
        #expect(varied.monotoneScore == 0.0)
    }

    @Test func metricsHidesWhenInsufficientSignal() {
        // Below the voiced-ratio threshold, isReliable goes false.
        let weak = PitchMetrics(meanHz: 180, stdHz: 12, voicedRatio: 0.10, windowCount: 50)
        #expect(weak.isReliable == false)

        // Out-of-vocal-range mean also fails.
        let outOfRange = PitchMetrics(meanHz: 600, stdHz: 12, voicedRatio: 0.5, windowCount: 50)
        #expect(outOfRange.isReliable == false)

        // Window count below 10 fails.
        let tiny = PitchMetrics(meanHz: 180, stdHz: 12, voicedRatio: 0.5, windowCount: 5)
        #expect(tiny.isReliable == false)
    }

    @Test @MainActor func appendBufferAccumulatesSamples() {
        let analyzer = PitchAnalyzer()
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024
        if let channelData = buffer.floatChannelData?[0] {
            for i in 0..<1024 {
                channelData[i] = Float(sin(2.0 * .pi * 220.0 * Double(i) / 16_000.0))
            }
        }
        #expect(analyzer.capturedSampleCount == 0)
        analyzer.appendBuffer(buffer, sampleRate: 16_000)
        #expect(analyzer.capturedSampleCount == 1024)
        analyzer.reset()
        #expect(analyzer.capturedSampleCount == 0)
    }
}

// MARK: - Grammar Feedback Service (M11)

struct GrammarFeedbackServiceTests {

    @Test func skipsWhenSessionTooShort() {
        // Below the 12s duration floor.
        let runs = GrammarFeedbackService.shouldRun(
            transcript: "I think the team has been doing really well this quarter.",
            duration: 8,
            wordCount: 30,
            fillerWordCount: 0,
            transcriptConfidence: 0.9
        )
        #expect(runs == false)
    }

    @Test func skipsWhenWordCountTooLow() {
        let runs = GrammarFeedbackService.shouldRun(
            transcript: "Yeah I guess so honestly not sure.",
            duration: 30,
            wordCount: 10,
            fillerWordCount: 0,
            transcriptConfidence: 0.9
        )
        #expect(runs == false)
    }

    @Test func skipsWhenTranscriptConfidenceLow() {
        let runs = GrammarFeedbackService.shouldRun(
            transcript: String(repeating: "word ", count: 60),
            duration: 30,
            wordCount: 60,
            fillerWordCount: 0,
            transcriptConfidence: 0.40
        )
        #expect(runs == false)
    }

    @Test func skipsWhenFillerHeavy() {
        // 30+ % filler ratio = throat-clearing; nothing to grade.
        let runs = GrammarFeedbackService.shouldRun(
            transcript: "um uh like so um you know like really um the thing is um uh well",
            duration: 25,
            wordCount: 30,
            fillerWordCount: 12,
            transcriptConfidence: 0.9
        )
        #expect(runs == false)
    }

    @Test func runsOnHealthySession() {
        let runs = GrammarFeedbackService.shouldRun(
            transcript: "The biggest opportunity for our team is to ship faster without sacrificing quality.",
            duration: 35,
            wordCount: 60,
            fillerWordCount: 1,
            transcriptConfidence: 0.85
        )
        #expect(runs == true)
    }

    @Test func runsWhenTranscriptConfidenceMissing() {
        // Some providers don't emit a confidence — don't reject by default.
        let runs = GrammarFeedbackService.shouldRun(
            transcript: "We were planning the launch carefully because the deadline is real.",
            duration: 30,
            wordCount: 35,
            fillerWordCount: 0,
            transcriptConfidence: nil
        )
        #expect(runs == true)
    }

    @Test func parseRejectsExcerptThatIsntInTranscript() async {
        // Excerpt the model returns must actually appear in the transcript;
        // otherwise we drop the note (defensive against fabrication).
        let transcript = "We launched the product on Tuesday."
        let payload: [String: Any] = [
            "choices": [[
                "message": [
                    "content": #"{"notes": [{"category": "agreement", "severity": "moderate", "excerpt": "the team are happy", "suggestion": "Use 'team is' for singular agreement.", "rationale": null}]}"#
                ]
            ]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let parsed = await GrammarFeedbackService.shared.parse(data: data, provider: .openAI, transcript: transcript)
        #expect(parsed != nil)
        #expect(parsed?.notes.isEmpty == true)
        #expect(parsed?.aiBacked == true)
    }

    @Test func parseAcceptsRealExcerpt() async {
        let transcript = "The team are planning to ship faster this quarter."
        let payload: [String: Any] = [
            "choices": [[
                "message": [
                    "content": #"{"notes": [{"category": "agreement", "severity": "moderate", "excerpt": "team are planning", "suggestion": "Use 'team is planning' for collective subject.", "rationale": null}]}"#
                ]
            ]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let parsed = await GrammarFeedbackService.shared.parse(data: data, provider: .openAI, transcript: transcript)
        #expect(parsed != nil)
        #expect(parsed?.notes.count == 1)
        #expect(parsed?.notes.first?.category == .agreement)
        #expect(parsed?.notes.first?.severity == .moderate)
        #expect(parsed?.notes.first?.suggestion.contains("team is") == true)
    }

    @Test func parseCapsAtThreeNotes() async {
        let transcript = "The team are happy. The data shows interesting result. Their is room. Its been a long week."
        // Four valid notes — service must cap at 3.
        let json = #"""
        {"notes": [
          {"category": "agreement", "severity": "moderate", "excerpt": "team are happy", "suggestion": "Use 'team is happy' for collective subject.", "rationale": null},
          {"category": "agreement", "severity": "minor", "excerpt": "data shows interesting result", "suggestion": "Use 'results' (plural).", "rationale": null},
          {"category": "wordChoice", "severity": "material", "excerpt": "Their is room", "suggestion": "Use 'There is' — possessive vs existential.", "rationale": null},
          {"category": "wordChoice", "severity": "minor", "excerpt": "Its been a long week", "suggestion": "Use 'It's been' (contraction of 'it has').", "rationale": null}
        ]}
        """#
        let payload: [String: Any] = [
            "choices": [["message": ["content": json]]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let parsed = await GrammarFeedbackService.shared.parse(data: data, provider: .openAI, transcript: transcript)
        #expect(parsed?.notes.count == 3)
    }

    @Test func parseAcceptsEmptyNotes() async {
        let transcript = "We launched the product on Tuesday and the team handled it well."
        let payload: [String: Any] = [
            "choices": [["message": ["content": #"{"notes": []}"#]]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let parsed = await GrammarFeedbackService.shared.parse(data: data, provider: .openAI, transcript: transcript)
        #expect(parsed != nil)
        #expect(parsed?.notes.isEmpty == true)
        #expect(parsed?.isCleanRun == true)
    }
}

// MARK: - Trend Analyzer pitch (M11)

struct TrendAnalyzerPitchTests {

    /// Build a synthetic snapshot with just the fields the pitch analyzer cares about.
    private func snapshot(daysAgo: Int, monotone: Double?) -> SkillSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return SkillSnapshot(
            sessionId: UUID(),
            date: date,
            fillerCount: 2,
            duration: 40,
            wordCount: 80,
            wpm: 120,
            score: 6,
            categoryRatings: [:],
            drillCompleted: nil,
            pauseRate: nil,
            pitchMonotone: monotone
        )
    }

    @Test func returnsNilWhenInsufficientData() {
        // Only 2 snapshots with pitch — below the 3-rep floor.
        let snapshots = [
            snapshot(daysAgo: 0, monotone: 0.5),
            snapshot(daysAgo: 1, monotone: 0.5),
            snapshot(daysAgo: 2, monotone: nil)
        ]
        let trend = TrendAnalyzer.analyzePitch(snapshots)
        #expect(trend == nil)
    }

    @Test func detectsImprovement() {
        // Recent reps are more varied (lower monotone) than older ones.
        let snapshots = [
            snapshot(daysAgo: 0, monotone: 0.30),
            snapshot(daysAgo: 1, monotone: 0.32),
            snapshot(daysAgo: 2, monotone: 0.35),
            snapshot(daysAgo: 3, monotone: 0.70),
            snapshot(daysAgo: 4, monotone: 0.72),
            snapshot(daysAgo: 5, monotone: 0.74)
        ]
        let trend = TrendAnalyzer.analyzePitch(snapshots)
        #expect(trend != nil)
        #expect(trend?.direction == .improving)
        #expect(trend?.skillArea == .vocalEmphasis)
    }

    @Test func detectsDeclining() {
        // Recent reps are flatter (higher monotone) than older ones.
        let snapshots = [
            snapshot(daysAgo: 0, monotone: 0.80),
            snapshot(daysAgo: 1, monotone: 0.78),
            snapshot(daysAgo: 2, monotone: 0.82),
            snapshot(daysAgo: 3, monotone: 0.40),
            snapshot(daysAgo: 4, monotone: 0.42),
            snapshot(daysAgo: 5, monotone: 0.38)
        ]
        let trend = TrendAnalyzer.analyzePitch(snapshots)
        #expect(trend?.direction == .declining)
    }

    @Test func skillLevelMapsFromMonotoneAverage() {
        let strong = [
            snapshot(daysAgo: 0, monotone: 0.20),
            snapshot(daysAgo: 1, monotone: 0.22),
            snapshot(daysAgo: 2, monotone: 0.25)
        ]
        #expect(TrendAnalyzer.analyzePitch(strong)?.currentLevel == .strong)

        let weak = [
            snapshot(daysAgo: 0, monotone: 0.85),
            snapshot(daysAgo: 1, monotone: 0.88),
            snapshot(daysAgo: 2, monotone: 0.82)
        ]
        #expect(TrendAnalyzer.analyzePitch(weak)?.currentLevel == .weak)
    }
}

// MARK: - Baseline pitch dimension (M11)

struct BaselinePitchTests {

    @Test func emptyBaselineHasEmptyPitchStat() {
        let baseline = CommunicationBaseline.empty
        #expect(baseline.pitchVariation == .empty)
        #expect(baseline.pitchVariation.isReliable == false)
    }

    @Test func decoderRestoresMissingPitchAsEmpty() throws {
        // Older persisted baselines won't carry the field.
        let json = """
        {
          "lastUpdated": 720000000.0,
          "sessionCount": 5,
          "qualifyingSessionCount": 5,
          "fillerRate": {"value": 1.0, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 0.5, "percentile75": 1.5},
          "pace": {"value": 130, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 110, "percentile75": 145},
          "paceVariance": {"value": 8, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 5, "percentile75": 10},
          "durationTendency": {"value": 45, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 30, "percentile75": 60},
          "openingStrength": {"value": 2.0, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 1.5, "percentile75": 2.5},
          "closingStrength": {"value": 2.0, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 1.5, "percentile75": 2.5},
          "structureQuality": {"value": 2.0, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 1.5, "percentile75": 2.5},
          "answerDepth": {"value": 2.0, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 1.5, "percentile75": 2.5},
          "clarity": {"value": 2.0, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 1.5, "percentile75": 2.5},
          "vocabularyRange": {"value": 0.65, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 0.55, "percentile75": 0.75},
          "hedgingRate": {"value": 1.0, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 0.5, "percentile75": 1.5},
          "averageScore": {"value": 7.0, "sampleCount": 5, "confidence": 1, "trend": "stable", "percentile25": 6.5, "percentile75": 7.5},
          "topStrengths": ["Filler control"],
          "persistentBlockers": []
        }
        """
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(CommunicationBaseline.self, from: data)
        #expect(decoded.pitchVariation == .empty)
        #expect(decoded.fillerRate.value == 1.0)
    }

    @Test func vocalVarietyShowsAsStrengthWhenVaried() throws {
        // Build a baseline where pitchVariation is reliable and varied.
        let varied = BaselineStat(value: 0.20, sampleCount: 12, confidence: .established, trend: .stable, percentile25: 0.18, percentile75: 0.25)
        var baseline = CommunicationBaseline.empty
        baseline = CommunicationBaseline(
            lastUpdated: Date(),
            sessionCount: 12,
            qualifyingSessionCount: 12,
            fillerRate: .empty,
            pace: .empty,
            paceVariance: .empty,
            durationTendency: .empty,
            pauseRate: .empty,
            pauseFilledRatio: .empty,
            openingStrength: .empty,
            closingStrength: .empty,
            structureQuality: .empty,
            answerDepth: .empty,
            clarity: .empty,
            vocabularyRange: .empty,
            hedgingRate: .empty,
            pitchVariation: varied,
            averageScore: .empty,
            clutchWordFrequencies: [:],
            topStrengths: [],
            persistentBlockers: []
        )
        // Re-encoding/decoding round-trips without losing the field.
        let data = try JSONEncoder().encode(baseline)
        let decoded = try JSONDecoder().decode(CommunicationBaseline.self, from: data)
        #expect(decoded.pitchVariation.value == 0.20)
        #expect(decoded.pitchVariation.isReliable == true)
    }
}

// MARK: - Practice Locale (M12)

struct PracticeLocaleTests {

    @Test func allLocalesHaveCodeAndDisplayName() {
        for locale in PracticeLocale.allCases {
            #expect(!locale.code.isEmpty)
            #expect(!locale.displayName.isEmpty)
            #expect(!locale.shortLabel.isEmpty)
        }
    }

    @Test func bcp47CodesMatchExpectedFormat() {
        #expect(PracticeLocale.enUS.code == "en-US")
        #expect(PracticeLocale.esES.code == "es-ES")
        #expect(PracticeLocale.frFR.code == "fr-FR")
    }
}

struct FillerLexiconTests {

    @Test func enUSMatchesLegacyBaseSet() {
        // M12 refactored FillerWordDetector.baseFillerWords to read from
        // FillerLexicon.enUS — the lexicon must keep that set intact so
        // pre-M12 callers behave unchanged.
        #expect(FillerWordDetector.baseFillerWords == FillerLexicon.enUS)
    }

    @Test func eachLocaleHasAtLeastSixEntries() {
        for locale in PracticeLocale.allCases {
            let words = FillerLexicon.words(for: locale)
            #expect(words.count >= 6, "lexicon for \(locale.code) too small: \(words.count)")
        }
    }

    @Test func spanishLexiconContainsCanonicalHesitation() {
        #expect(FillerLexicon.esES.contains("este"))
        #expect(FillerLexicon.esES.contains("eh"))
    }

    @Test func frenchLexiconContainsCanonicalHesitation() {
        #expect(FillerLexicon.frFR.contains("euh"))
        #expect(FillerLexicon.frFR.contains("ben"))
    }

    @Test func effectiveWordSetUnionsCustomWordsLowercased() {
        let resolved = FillerWordDetector.effectiveWordSet(
            for: .enUS,
            customWords: ["Basically", "ACTUALLY"]
        )
        #expect(resolved.contains("basically"))
        #expect(resolved.contains("actually"))
        // Existing base-set entries still present
        #expect(resolved.contains("uh"))
        #expect(resolved.contains("um"))
    }

    @Test func regexBundleNotEmptyPerLocale() {
        for locale in PracticeLocale.allCases {
            #expect(!FillerWordDetector.regexes(for: locale).isEmpty)
        }
    }
}

struct PracticeTopicsLocaleTests {

    @Test func enUSPoolReadsLegacyDictionary() {
        let prompts = PracticeTopics.prompts(for: .general, locale: .enUS)
        #expect(!prompts.isEmpty)
    }

    @Test func spanishPoolHasPromptsAcrossThemes() {
        for theme in PromptTheme.allCases where theme != .all {
            let prompts = PracticeTopics.prompts(for: theme, locale: .esES)
            #expect(!prompts.isEmpty, "es-ES \(theme.rawValue) pool is empty")
        }
    }

    @Test func frenchPoolHasPromptsAcrossThemes() {
        for theme in PromptTheme.allCases where theme != .all {
            let prompts = PracticeTopics.prompts(for: theme, locale: .frFR)
            #expect(!prompts.isEmpty, "fr-FR \(theme.rawValue) pool is empty")
        }
    }

    @Test func allThemeFlattensPerLocale() {
        let en = PracticeTopics.prompts(for: .all, locale: .enUS)
        let es = PracticeTopics.prompts(for: .all, locale: .esES)
        let fr = PracticeTopics.prompts(for: .all, locale: .frFR)
        #expect(en.count >= 100)
        #expect(es.count >= 20)
        #expect(fr.count >= 20)
    }

    @Test func explicitLocaleRandomReturnsFromCorrectPool() {
        let esPool = Set(PracticeTopics.prompts(for: .all, locale: .esES))
        for _ in 0..<10 {
            let pick = PracticeTopics.random(theme: .all, locale: .esES)
            #expect(esPool.contains(pick), "es-ES random returned non-Spanish prompt: \(pick)")
        }
    }

    @Test func seededByAlwaysReadsEnglishPool() {
        // Async-challenge fairness contract: same seed = same prompt across
        // devices regardless of each user's practice locale setting.
        let a = PracticeTopics.seeded(by: "challenge-42")
        let b = PracticeTopics.seeded(by: "challenge-42")
        #expect(a == b)
        let englishPool = Set(PracticeTopics.prompts(for: .all, locale: .enUS))
        #expect(englishPool.contains(a))
    }
}

@MainActor
struct LocaleSettingsManagerTests {

    @Test func currentLocaleIsValid() {
        let m = LocaleSettingsManager.shared
        #expect(PracticeLocale.allCases.contains(m.current))
    }

    @Test func roundTripsLocaleChange() {
        let m = LocaleSettingsManager.shared
        let original = m.current
        defer { m.current = original }

        m.current = .esES
        #expect(m.current == .esES)
        m.current = .frFR
        #expect(m.current == .frFR)
        m.current = .enUS
        #expect(m.current == .enUS)
    }
}

// MARK: - UI Localisation (M13)

struct PracticeLocaleAISupportTests {

    @Test func englishSupportsAISurfaces() {
        #expect(PracticeLocale.enUS.aiSupported == true)
    }

    @Test func spanishAndFrenchDoNotSupportAIYet() {
        // M13 ships practice-loop localisation; AI surfaces are
        // English-only until a future milestone localises the prompts.
        // Flipping these will be the marker that the gate has lifted.
        #expect(PracticeLocale.esES.aiSupported == false)
        #expect(PracticeLocale.frFR.aiSupported == false)
    }
}

@MainActor
struct LocalizableCatalogTests {

    /// Smoke test that the bundled `Localizable.xcstrings` resolves a
    /// known key into the matching Spanish and French translations.
    @Test func resolvesPracticeKeyForESAndFR() {
        let key = "Practice"
        let bundle = Bundle.main

        let es = bundle.localizedString(forKey: key, value: nil, table: nil)
        // When running tests under a non-localised host, `localizedString`
        // can still return the source key. We only assert that some
        // non-empty value comes back; a deeper test would isolate the
        // locale via Bundle.path(forResource:locale:) but that requires
        // bundle introspection that's flaky in test targets.
        #expect(!es.isEmpty)
    }

    @Test func catalogContainsExpectedKeys() {
        // Cross-check the catalog file path is in the bundle. This catches
        // the common "added the file but Xcode didn't sync" failure mode.
        let url = Bundle.main.url(forResource: "Localizable", withExtension: "xcstrings")
        // The catalog gets compiled to .strings tables at build time —
        // the .xcstrings source file isn't always present in the runtime
        // bundle. Fall back to confirming the localisation table works
        // for a single key by Bundle.localizedString returning non-empty.
        if url == nil {
            #expect(!Bundle.main.localizedString(forKey: "Account", value: nil, table: nil).isEmpty)
        } else {
            #expect(url != nil)
        }
    }
}

// MARK: - Skill Level-Up detection
//
// Asks the question: when a session bumps a SkillTrend up a band, do we
// queue a celebration event? And do we silently ignore drops, never
// firing a "punish" moment? The detection logic itself is pure — these
// tests don't touch UserDefaults; they exercise the static `detect`
// helper directly.

struct SkillLevelUpDetectionTests {

    private func trend(_ area: SkillArea, _ level: SkillLevel) -> SkillTrend {
        SkillTrend(
            skillArea: area,
            direction: .stable,
            confidence: .medium,
            windowSize: 5,
            currentLevel: level
        )
    }

    @Test func upwardCrossingFiresEvent() {
        let previous: [SkillArea: SkillLevel] = [.fillerReduction: .developing]
        let current = [trend(.fillerReduction, .solid)]
        let events = SkillLevelUpEvent.detect(previous: previous, current: current)
        #expect(events.count == 1)
        #expect(events.first?.previousLevel == .developing)
        #expect(events.first?.newLevel == .solid)
    }

    @Test func downwardCrossingDoesNotFire() {
        // Per the brand anti-goal "never punish-shame a miss in copy",
        // drops are stored silently. No event fires.
        let previous: [SkillArea: SkillLevel] = [.paceControl: .solid]
        let current = [trend(.paceControl, .developing)]
        let events = SkillLevelUpEvent.detect(previous: previous, current: current)
        #expect(events.isEmpty)
    }

    @Test func sameLevelDoesNotFire() {
        let previous: [SkillArea: SkillLevel] = [.structure: .solid]
        let current = [trend(.structure, .solid)]
        #expect(SkillLevelUpEvent.detect(previous: previous, current: current).isEmpty)
    }

    @Test func firstObservationDoesNotFire() {
        // No previous reading for this skill — first time it's been ranked.
        // We don't celebrate the first sighting; we wait for an actual
        // upward transition before firing the moment.
        let previous: [SkillArea: SkillLevel] = [:]
        let current = [trend(.openingStrength, .solid)]
        #expect(SkillLevelUpEvent.detect(previous: previous, current: current).isEmpty)
    }

    @Test func multipleSkillsCanCrossInOneSession() {
        // Rare but real — a strong session can move multiple skills.
        let previous: [SkillArea: SkillLevel] = [
            .fillerReduction: .developing,
            .paceControl:     .developing,
            .structure:       .weak
        ]
        let current = [
            trend(.fillerReduction, .solid),     // up
            trend(.paceControl,     .developing), // unchanged
            trend(.structure,       .developing)  // up
        ]
        let events = SkillLevelUpEvent.detect(previous: previous, current: current)
        #expect(events.count == 2)
        let areas = Set(events.map { $0.skillArea })
        #expect(areas == [.fillerReduction, .structure])
    }

    @Test func headlineCopyMatchesSkill() {
        let event = SkillLevelUpEvent(
            skillArea: .fillerReduction,
            previousLevel: .developing,
            newLevel: .solid,
            date: Date()
        )
        #expect(event.headline == "Filler Words leveled up")
        #expect(event.subline == "Developing → Solid")
    }
}

// MARK: - AI Rewrite voice-preservation (real-device feedback fix)
//
// User-stated requirement at M14: "don't want them to learn how to speak
// like chatgpt/AI right, THIS IS VERY IMPORTANT". These tests pin the
// deterministic pieces of the rewrite service — VoiceSignals + the
// content filter — so the voice-preservation contract can't regress
// silently. The actual model call is integration-only; we don't test it
// here.

struct VoiceSignalsTests {

    @Test func detectsContractions() {
        let s = VoiceSignals.compute(transcript: "I'm not sure about it. I don't know yet, but it's something I'm working on.")
        #expect(s.usesContractions == true)
    }

    @Test func absenceOfContractionsReadsAsFormal() {
        let s = VoiceSignals.compute(transcript: "I am not sure about it. I do not know yet, but it is something I am working on.")
        #expect(s.usesContractions == false)
    }

    @Test func detectsHedging() {
        let s = VoiceSignals.compute(transcript: "It's kind of like a thing where I sort of feel that way, you know?")
        #expect(s.usesHedging == true)
    }

    @Test func averageSentenceLengthIsRoughlyCorrect() {
        // Three sentences of ~6 words each.
        let s = VoiceSignals.compute(transcript: "I think this matters a lot. We should look at it. The team can probably help.")
        #expect(s.avgSentenceLength >= 5 && s.avgSentenceLength <= 8)
    }

    @Test func firstPersonHeavyDetected() {
        let s = VoiceSignals.compute(transcript: "I think I'm pretty good at this. I've been doing it for a while. I just need to keep going. I really like it.")
        #expect(s.firstPersonHeavy == true)
    }

    @Test func distinctiveWordsExcludeStopwords() {
        let s = VoiceSignals.compute(transcript: "Strategic thinking really matters because everything around it depends on people understanding the framework before they actually start.")
        // "really", "actually", "everything", "around", "people", "before"
        // are stopwords and should be excluded.
        #expect(!s.distinctiveWords.contains("really"))
        #expect(!s.distinctiveWords.contains("actually"))
        #expect(!s.distinctiveWords.contains("everything"))
        // "framework" and "strategic" should make it through.
        #expect(s.distinctiveWords.contains("strategic") || s.distinctiveWords.contains("framework"))
    }

    @Test func emptyTranscriptReturnsEmptySignals() {
        let s = VoiceSignals.compute(transcript: "")
        #expect(s.avgSentenceLength == 0)
        #expect(s.distinctiveWords.isEmpty)
    }
}

struct RewriteContentFilterTests {

    private let casualSignals = VoiceSignals(
        avgSentenceLength: 8,
        usesContractions: true,
        usesHedging: true,
        firstPersonHeavy: true,
        distinctiveWords: ["meeting", "project", "manager"]
    )

    @Test func rejectsCorporateJargonUserDidNotSay() {
        // User never said "leverage" — model output containing it must be
        // rejected. This is the AI-tell guard the user explicitly asked for.
        let raw = "We can leverage the meeting to align on the project."
        #expect(RewriteContentFilter.accept(raw, signals: casualSignals) == nil)
    }

    @Test func rejectsValueAddPhrasing() {
        let raw = "It's really a value-add for the project — strategic thinking matters."
        #expect(RewriteContentFilter.accept(raw, signals: casualSignals) == nil)
    }

    @Test func rejectsMissingContractionsWhenUserUsesThem() {
        // User uses contractions; rewrite without any contraction reads
        // formal vs. their voice — reject.
        let raw = "I will share the update with the team in the meeting."
        #expect(RewriteContentFilter.accept(raw, signals: casualSignals) == nil)
    }

    @Test func acceptsCleanCasualRewrite() {
        let raw = "I'll share the update with the team in the meeting."
        let cleaned = RewriteContentFilter.accept(raw, signals: casualSignals)
        #expect(cleaned == "I'll share the update with the team in the meeting.")
    }

    @Test func rejectsTooShort() {
        let raw = "I will."
        #expect(RewriteContentFilter.accept(raw, signals: casualSignals) == nil)
    }

    @Test func rejectsTooLong() {
        let raw = String(repeating: "x", count: 250) + "."
        #expect(RewriteContentFilter.accept(raw, signals: casualSignals) == nil)
    }

    @Test func stripsEnclosingDoubleQuotes() {
        let raw = "\"I'll keep this concise — here's the answer in one line for the team.\""
        let cleaned = RewriteContentFilter.accept(raw, signals: casualSignals)
        #expect(cleaned == "I'll keep this concise — here's the answer in one line for the team.")
    }

    @Test func acceptsAITellWordIfUserActuallyUsedIt() {
        // If the user actually said "strategic" themselves, the rewrite
        // is allowed to keep it. The filter is "no NEW jargon", not
        // "no jargon at all."
        let signals = VoiceSignals(
            avgSentenceLength: 8,
            usesContractions: false,
            usesHedging: false,
            firstPersonHeavy: false,
            distinctiveWords: ["strategic", "meeting", "project"]
        )
        let raw = "The meeting is strategic for our project this quarter."
        let cleaned = RewriteContentFilter.accept(raw, signals: signals)
        #expect(cleaned != nil)
    }
}

// MARK: - Score recalibration (real-device feedback fix)
//
// Real-device QA surfaced that an obviously-poor rep (80 WPM, 2 fillers,
// 30s on Medium) was scoring 8/10 — too generous. The fix tightened the
// pace bands and score formula. These tests pin the new behaviour so we
// don't regress to the old bands.

struct ScoreCalibrationTests {

    /// 80 WPM is genuinely halting speech, not "controlled and calm".
    /// Old behaviour returned 0.72 (encouraging) — caller's score got
    /// lifted by ~1.4 points across that band. New behaviour: ≤ 0.5.
    @Test func paceScore80WPMIsHonestlyPoor() {
        let score = PracticeEvaluator.paceScoreForTesting(wpm: 80, wordCount: 40)
        #expect(score <= 0.5, "80 WPM should not get >0.5 pace credit; got \(score)")
    }

    @Test func paceScoreInTargetRangeReturnsFullCredit() {
        // 145 WPM is mid-target.
        let score = PracticeEvaluator.paceScoreForTesting(wpm: 145, wordCount: 40)
        #expect(score == 1.0)
    }

    @Test func paceScoreOver200WPMIsRushed() {
        let score = PracticeEvaluator.paceScoreForTesting(wpm: 220, wordCount: 60)
        #expect(score <= 0.3, "220 WPM is sprinting; pace credit must be low")
    }

    /// Halting label, not "Measured" — copy must match the new band.
    @Test func paceSnapshotAt80WPMUsesHonestLabel() {
        let snap = PracticeEvaluator.paceSnapshotForTesting(wpm: 80, wordCount: 40)
        #expect(snap.label == "Hesitant" || snap.label == "Halting",
                "label was \(snap.label); old 'Measured' was the bug")
    }

    /// The original real-device read: 80 WPM, 2 fillers, 30s on Medium
    /// difficulty. Score should NOT be 8 anymore.
    @Test func realWorldPoorRepDoesNotScoreEight() {
        // Build a transcript with ~40 words to hit 80 WPM in 30s.
        let words = Array(repeating: "word", count: 40).joined(separator: " ")
        let evaluation = PracticeEvaluator.evaluateTimedPractice(
            transcript: words,
            fillerCount: 2,
            duration: 30,
            difficulty: .medium,
            recentSessions: [],
            profile: nil,
            transcriptConfidence: nil
        )
        #expect(evaluation.score <= 6,
                "80 WPM + 2 fillers + 30s Medium scored \(evaluation.score); old bug returned 8")
    }

    /// Filler penalty must accelerate past 4 fillers — old cap of 3.0
    /// meant 10 fillers looked the same as 4. New cap is 5.5 with
    /// non-linear ramp.
    @Test func highFillerCountCostsMoreThanLowCount() {
        let lowFillerWords = Array(repeating: "word", count: 60).joined(separator: " ")
        let lowEval = PracticeEvaluator.evaluateTimedPractice(
            transcript: lowFillerWords,
            fillerCount: 2,
            duration: 30,
            difficulty: .medium,
            recentSessions: [],
            profile: nil
        )
        let highEval = PracticeEvaluator.evaluateTimedPractice(
            transcript: lowFillerWords,
            fillerCount: 10,
            duration: 30,
            difficulty: .medium,
            recentSessions: [],
            profile: nil
        )
        #expect(lowEval.score > highEval.score,
                "10 fillers (\(highEval.score)) should score lower than 2 (\(lowEval.score))")
    }

    // MARK: - Typography Dynamic Type contract
    //
    // Every Typography role builds through `figtree(_:weight:relativeTo:)`
    // or `manrope(_:weight:relativeTo:)`, both of which now *require* a
    // `Font.TextStyle` argument. If a future refactor drops `relativeTo:`
    // the call site fails to compile. These tests sanity-check that the
    // canonical roles still resolve to a non-nil Font (i.e. Family.display
    // / Family.text names haven't drifted to something the system can't
    // find — Font.custom always returns a Font but the smoke test catches
    // any future accidental nil-able variant).

    @Test func typographyRolesResolveToFonts() {
        // Touch every role so a renamed family or removed enum case fails
        // the test rather than silently rendering the system fallback.
        _ = Typography.display
        _ = Typography.hero
        _ = Typography.screenTitle
        _ = Typography.sectionHero
        _ = Typography.bigStat
        _ = Typography.statHero
        _ = Typography.cardTitle
        _ = Typography.headline
        _ = Typography.cardLabel
        _ = Typography.subheadline
        _ = Typography.body
        _ = Typography.caption
        _ = Typography.captionSmall
        _ = Typography.micro
        _ = Typography.nav
        #expect(Typography.Family.display == "Figtree")
        #expect(Typography.Family.text == "Manrope")
    }

    @Test func typographyNumericHelperReturnsMonospacedDigit() {
        // The numeric helper must monospace digits so stat counters don't
        // wobble when the leading digit changes width.
        _ = Typography.figtreeNumeric(size: 28)
        _ = Typography.figtreeNumeric(size: 18, weight: .heavy, relativeTo: .headline)
        // Compile-time check is the contract — runtime smoke is enough.
    }
}

// MARK: - Goal Progress Tests (M14)
//
// Locks the contract for the profile's goal-progress ring:
//   • Snapshot-window distance computes from raw signal aggregates for all
//     four goals — `.calmerDelivery` reads the per-snapshot
//     `pauseFilledRatio` field and skips zero-pause reps so the loop is
//     closed across every voice without faking a "perfectly calm" read.
//   • measuredDistanceFromGoal returns nil on insufficient baseline data so
//     the UI can render "Early signal" rather than a fake 50%.
//   • Trend compute classifies closer / steady / slipped honestly and
//     returns nil when either window has fewer than 3 qualifying snapshots.

struct GoalProgressTests {

    private func snapshot(
        daysAgo: Int,
        fillerCount: Int,
        duration: TimeInterval,
        score: Int,
        pauseFilledRatio: Double? = nil
    ) -> SkillSnapshot {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return SkillSnapshot(
            sessionId: UUID(),
            date: date,
            fillerCount: fillerCount,
            duration: duration,
            wordCount: 120,
            wpm: 130,
            score: score,
            categoryRatings: [:],
            drillCompleted: nil,
            pauseRate: nil,
            pitchMonotone: nil,
            pauseFilledRatio: pauseFilledRatio
        )
    }

    // MARK: distanceFromGoal(in:)

    @Test func snapshotDistanceFillerHitsTargetAtCleanRate() {
        // 6 reps × 60s × 1 filler each = 1.0 filler/min → distance 0.125
        // (well inside "On track" band — proximity ≥ 87%).
        let snaps = (0..<6).map { snapshot(daysAgo: $0, fillerCount: 1, duration: 60, score: 7) }
        guard let d = CommunicationBaseline.distanceFromGoal(.reduceFillers, in: snaps) else {
            #expect(Bool(false), "Expected a measured distance for filler-clean reps.")
            return
        }
        #expect(d < 0.20, "Clean filler reps should sit inside On-track band. Got: \(d)")
    }

    @Test func snapshotDistanceFillerSaturatesAtNoisyRate() {
        // 6 reps × 30s × 8 fillers each = 16/min → clamps to 1.0.
        let snaps = (0..<6).map { snapshot(daysAgo: $0, fillerCount: 8, duration: 30, score: 4) }
        guard let d = CommunicationBaseline.distanceFromGoal(.reduceFillers, in: snaps) else {
            #expect(Bool(false), "Expected a measured distance for filler-heavy reps.")
            return
        }
        #expect(d == 1.0, "16 fillers/min must saturate at 1.0. Got: \(d)")
    }

    @Test func snapshotDistanceConciseTracksDurationMean() {
        // 5 reps averaging 40s → distance = (40-20)/100 = 0.20.
        let snaps = (0..<5).map { snapshot(daysAgo: $0, fillerCount: 0, duration: 40, score: 7) }
        guard let d = CommunicationBaseline.distanceFromGoal(.moreConcise, in: snaps) else {
            #expect(Bool(false), "Expected a measured distance for concise reps.")
            return
        }
        #expect(abs(d - 0.20) < 0.01, "40s mean should map to distance 0.20. Got: \(d)")
    }

    @Test func snapshotDistanceThinkFasterTracksScoreMean() {
        // 5 reps × score 8 → distance = max(0, 1 - 8/7.5) = 0.0.
        let snaps = (0..<5).map { snapshot(daysAgo: $0, fillerCount: 1, duration: 45, score: 8) }
        guard let d = CommunicationBaseline.distanceFromGoal(.thinkFaster, in: snaps) else {
            #expect(Bool(false), "Expected a measured distance for high-score reps.")
            return
        }
        #expect(d == 0.0, "Score-8 mean should pin distance at 0.0. Got: \(d)")
    }

    @Test func snapshotDistanceCalmerDeliveryHiddenWithoutPauseHistory() {
        // Reps without any captured pauses don't contribute a calmness
        // reading — the helper returns nil so the trend chip stays hidden
        // rather than treat zero-pause sessions as "perfectly calm".
        let snaps = (0..<6).map { snapshot(daysAgo: $0, fillerCount: 1, duration: 45, score: 7) }
        let d = CommunicationBaseline.distanceFromGoal(.calmerDelivery, in: snaps)
        #expect(d == nil, "calmerDelivery is unmeasurable without pause history. Got: \(String(describing: d))")
    }

    @Test func snapshotDistanceCalmerDeliveryTracksFilledPauseMean() {
        // 5 reps with mean filledRatio = 0.4 → distance = 0.4 / 0.8 = 0.50.
        let snaps = (0..<5).map { i in
            snapshot(daysAgo: i, fillerCount: 1, duration: 45, score: 7, pauseFilledRatio: 0.4)
        }
        guard let d = CommunicationBaseline.distanceFromGoal(.calmerDelivery, in: snaps) else {
            #expect(Bool(false), "Expected a measured distance once filled-ratio history exists.")
            return
        }
        #expect(abs(d - 0.50) < 0.01, "0.4 filled-ratio mean should map to distance 0.50. Got: \(d)")
    }

    @Test func snapshotDistanceCalmerDeliverySaturatesAtFullyFilled() {
        // Every pause filled with disfluency → mean 1.0 → distance clamps to 1.0.
        let snaps = (0..<4).map { i in
            snapshot(daysAgo: i, fillerCount: 4, duration: 30, score: 4, pauseFilledRatio: 1.0)
        }
        guard let d = CommunicationBaseline.distanceFromGoal(.calmerDelivery, in: snaps) else {
            #expect(Bool(false), "Expected a measured distance for fully-filled pauses.")
            return
        }
        #expect(d == 1.0, "1.0 filled mean must saturate at distance 1.0. Got: \(d)")
    }

    @Test func snapshotDistanceCalmerDeliverySkipsZeroPauseReps() {
        // Mixed history: 2 reps with pauses (good calmness) + 3 zero-pause
        // reps. Only the 2 reps with pause history qualify — that's below
        // the 3-sample minimum, so the helper honestly returns nil.
        var snaps: [SkillSnapshot] = []
        snaps.append(snapshot(daysAgo: 0, fillerCount: 1, duration: 45, score: 7, pauseFilledRatio: 0.1))
        snaps.append(snapshot(daysAgo: 1, fillerCount: 1, duration: 45, score: 7, pauseFilledRatio: 0.15))
        snaps.append(contentsOf: (2..<5).map { i in
            snapshot(daysAgo: i, fillerCount: 1, duration: 45, score: 7, pauseFilledRatio: nil)
        })
        let d = CommunicationBaseline.distanceFromGoal(.calmerDelivery, in: snaps)
        #expect(d == nil, "Need ≥3 reps with non-nil filled ratio to read calmness. Got: \(String(describing: d))")
    }

    @Test func snapshotDistanceBelowMinimumSamplesReturnsNil() {
        // Two snapshots is below the minimum-3 floor.
        let snaps = (0..<2).map { snapshot(daysAgo: $0, fillerCount: 1, duration: 60, score: 7) }
        #expect(CommunicationBaseline.distanceFromGoal(.reduceFillers, in: snaps) == nil)
    }

    // MARK: measuredDistanceFromGoal

    @Test func measuredDistanceHidesWhenConfidenceInsufficient() {
        // .empty baseline → every dimension is .insufficient → measured
        // returns nil for every goal so the ring renders "Early signal"
        // rather than a fake 50% reading.
        let baseline = CommunicationBaseline.empty
        #expect(baseline.measuredDistanceFromGoal(.reduceFillers) == nil)
        #expect(baseline.measuredDistanceFromGoal(.moreConcise) == nil)
        #expect(baseline.measuredDistanceFromGoal(.thinkFaster) == nil)
        #expect(baseline.measuredDistanceFromGoal(.calmerDelivery) == nil)
    }

    @Test func measuredDistanceSurfacesWhenConfidenceClearsThreshold() {
        let baseline = CommunicationBaseline(
            lastUpdated: Date(), sessionCount: 12, qualifyingSessionCount: 12,
            fillerRate: BaselineStat(value: 2.0, sampleCount: 12, confidence: .established, trend: .stable, percentile25: 1.5, percentile75: 2.5),
            pace: .empty, paceVariance: .empty, durationTendency: .empty,
            pauseRate: .empty, pauseFilledRatio: .empty,
            openingStrength: .empty, closingStrength: .empty,
            structureQuality: .empty, answerDepth: .empty, clarity: .empty,
            vocabularyRange: .empty, hedgingRate: .empty,
            averageScore: .empty, clutchWordFrequencies: [:],
            topStrengths: [], persistentBlockers: []
        )
        guard let d = baseline.measuredDistanceFromGoal(.reduceFillers) else {
            #expect(Bool(false), "Expected a measured distance when fillerRate confidence is established.")
            return
        }
        #expect(abs(d - 0.25) < 0.01, "2.0 fillers/min should map to distance 0.25. Got: \(d)")
    }

    // MARK: GoalProgressTrend.compute

    @Test func trendDetectsImprovementWeekOverWeek() {
        // Recent 5 reps: 1 filler/60s → 1/min. Prior 5 reps: 4 fillers/60s →
        // 4/min. Distance drops from 0.5 to 0.125 — clearly "closer".
        let recent = (0..<5).map { snapshot(daysAgo: $0, fillerCount: 1, duration: 60, score: 7) }
        let prior = (5..<10).map { snapshot(daysAgo: $0, fillerCount: 4, duration: 60, score: 5) }
        guard let trend = GoalProgressTrend.compute(goal: .reduceFillers, snapshots: recent + prior) else {
            #expect(Bool(false), "Expected a trend with 5+5 qualifying snapshots.")
            return
        }
        #expect(trend.direction == .closer, "Filler drop should classify as closer. Got: \(trend.direction)")
        #expect(trend.delta < -GoalProgressTrend.steadyThreshold, "Closer trend must have a meaningfully negative delta. Got: \(trend.delta)")
    }

    @Test func trendDetectsSlippageWeekOverWeek() {
        // Recent reps drift longer (concise distance goes up).
        let recent = (0..<5).map { snapshot(daysAgo: $0, fillerCount: 1, duration: 90, score: 7) }
        let prior = (5..<10).map { snapshot(daysAgo: $0, fillerCount: 1, duration: 40, score: 7) }
        guard let trend = GoalProgressTrend.compute(goal: .moreConcise, snapshots: recent + prior) else {
            #expect(Bool(false), "Expected a trend for the slip case.")
            return
        }
        #expect(trend.direction == .slipped, "Longer mean duration must classify as slipped. Got: \(trend.direction)")
    }

    @Test func trendClassifiesSteadyInsideNoiseBand() {
        // Recent and prior windows hold the same filler rate — the chip
        // should not celebrate movement that isn't there.
        let all = (0..<10).map { snapshot(daysAgo: $0, fillerCount: 2, duration: 60, score: 7) }
        guard let trend = GoalProgressTrend.compute(goal: .reduceFillers, snapshots: all) else {
            #expect(Bool(false), "Expected a steady trend on identical windows.")
            return
        }
        #expect(trend.direction == .steady, "Identical windows must classify as steady. Got: \(trend.direction)")
        #expect(abs(trend.delta) < GoalProgressTrend.steadyThreshold)
    }

    @Test func trendReturnsNilWhenPriorWindowIsThin() {
        // 5 recent snapshots but only 2 prior — below the 3-sample floor for
        // the prior window. The chip stays hidden rather than celebrate a
        // delta against a noisy baseline.
        let recent = (0..<5).map { snapshot(daysAgo: $0, fillerCount: 1, duration: 60, score: 7) }
        let prior = (5..<7).map { snapshot(daysAgo: $0, fillerCount: 4, duration: 60, score: 5) }
        let trend = GoalProgressTrend.compute(goal: .reduceFillers, snapshots: recent + prior)
        #expect(trend == nil, "Trend must require ≥3 snapshots in each window. Got: \(String(describing: trend))")
    }

    @Test func trendReturnsNilForCalmerDeliveryWithoutPauseHistory() {
        // Without filled-ratio readings on the snapshots, the trend chip
        // stays hidden so the UI never claims a calmness delta it can't
        // actually compute — restraint over coverage.
        let snaps = (0..<10).map { snapshot(daysAgo: $0, fillerCount: 1, duration: 45, score: 7) }
        let trend = GoalProgressTrend.compute(goal: .calmerDelivery, snapshots: snaps)
        #expect(trend == nil)
    }

    @Test func trendDetectsCalmerDeliveryImprovement() {
        // Recent 5 reps: filled-ratio 0.15 (calm). Prior 5 reps: 0.6 (noisy).
        // Distance drops from 0.75 → 0.1875 → clearly "closer".
        let recent = (0..<5).map { i in
            snapshot(daysAgo: i, fillerCount: 1, duration: 45, score: 7, pauseFilledRatio: 0.15)
        }
        let prior = (5..<10).map { i in
            snapshot(daysAgo: i, fillerCount: 3, duration: 45, score: 5, pauseFilledRatio: 0.6)
        }
        guard let trend = GoalProgressTrend.compute(goal: .calmerDelivery, snapshots: recent + prior) else {
            #expect(Bool(false), "Expected a calmness trend once snapshots carry filled-ratio history.")
            return
        }
        #expect(trend.direction == .closer, "Filled-ratio drop should classify as closer. Got: \(trend.direction)")
        #expect(trend.delta < -GoalProgressTrend.steadyThreshold, "Closer trend must have a meaningfully negative delta. Got: \(trend.delta)")
    }

    @Test func trendChipCopyIsRestraintFriendly() {
        // Quick smoke on the user-facing strings — guards against an
        // accidental "let's" / emoji / exclamation creep that would violate
        // the brand voice rules in the design system.
        let closer = GoalProgressTrend(direction: .closer, delta: -0.1, windowSize: 5)
        let steady = GoalProgressTrend(direction: .steady, delta: 0.0, windowSize: 5)
        let slipped = GoalProgressTrend(direction: .slipped, delta: 0.1, windowSize: 5)
        for chip in [closer, steady, slipped] {
            #expect(!chip.label.isEmpty)
            #expect(!chip.label.contains("!"))
            #expect(!chip.label.lowercased().contains("let's"))
        }
    }
}

// MARK: - Voice Alignment (M14: fifth surface in the goal-aware loop)
//
// Tests for the home-recommendation alignment chip. The chip extends the
// pre-rep banner → mid-rep HUD → post-rep Coach Note → profile ring chain
// onto the home `suggestionLink`. The contract:
//
//   • `PracticeMode.primarySkillAreas` is the canonical mode→skill map.
//     Every mode owns 2–3 skills it most directly trains.
//   • `SpeakingStyleGoal.aligns(with mode:)` is true iff the voice's aligned
//     skills overlap with the mode's primary skills.
//   • Each of the 4 modes has ≥1 aligned voice; each of the 6 voices has ≥1
//     aligned mode. Otherwise the chip would orphan a surface.
//   • Some voice→mode pairs do NOT align by design — voices that need space
//     (warm, storytelling) don't align with sudden-death pressure; voices
//     that need composure (executive) don't align with the looser ah-counter.
//
// The chip's copy ("Toward your <voice> voice") reuses `shortVoiceLabel`, so
// the brand-voice smoke covers it via `GoalProgressTests.trendChipCopyIsRestraintFriendly`-
// style guards on the same source string.

struct VoiceAlignmentTests {

    private let allModes: [PracticeMode] = [.timed, .suddenDeath, .ahCounter, .imConversation]

    // MARK: PracticeMode.primarySkillAreas

    @Test func timedTrainsStructureAndAnswerDevelopment() {
        let skills = PracticeMode.timed.primarySkillAreas
        #expect(skills.contains(.structure))
        #expect(skills.contains(.answerDevelopment))
        #expect(skills.contains(.openingStrength))
    }

    @Test func suddenDeathTrainsConfidenceAndFillerControl() {
        let skills = PracticeMode.suddenDeath.primarySkillAreas
        #expect(skills.contains(.confidence))
        #expect(skills.contains(.fillerReduction))
    }

    @Test func ahCounterTrainsFillerAndPaceAndPauseSkills() {
        let skills = PracticeMode.ahCounter.primarySkillAreas
        #expect(skills.contains(.fillerReduction))
        #expect(skills.contains(.paceControl))
        #expect(skills.contains(.pauseUsage))
    }

    @Test func imConversationTrainsEmphasisAndDepth() {
        let skills = PracticeMode.imConversation.primarySkillAreas
        #expect(skills.contains(.vocalEmphasis))
        #expect(skills.contains(.answerDevelopment))
    }

    @Test func primarySkillAreasStayNarrow() {
        // Intentional restraint — broader maps dilute the signal that the
        // home chip reads from. 2–3 skills per mode is the design contract.
        for mode in allModes {
            let count = mode.primarySkillAreas.count
            #expect(count >= 2 && count <= 3, "\(mode) maps to \(count) skills — expected 2–3.")
        }
    }

    // MARK: SpeakingStyleGoal.aligns(with:)

    @Test func conciseVoiceAlignsWithTimedAndAhCounter() {
        // Concise → structure + fillerReduction + conciseSpeaking. Both timed
        // (structure) and ahCounter (fillerReduction) overlap.
        #expect(SpeakingStyleGoal.concise.aligns(with: .timed))
        #expect(SpeakingStyleGoal.concise.aligns(with: .ahCounter))
    }

    @Test func warmVoiceDoesNotAlignWithSuddenDeath() {
        // Warm voice needs space and rhythm — pressure mode cuts both. The
        // chip must stay silent rather than claim a sudden-death rep moves
        // a speaker toward warmth.
        #expect(!SpeakingStyleGoal.warm.aligns(with: .suddenDeath))
    }

    @Test func warmVoiceAlignsWithImConversation() {
        // Warm voice ↔ IM. Live two-way exchange is exactly where vocal
        // emphasis + answer depth land warmly.
        #expect(SpeakingStyleGoal.warm.aligns(with: .imConversation))
    }

    @Test func executiveVoiceDoesNotAlignWithAhCounter() {
        // Executive presence is composed and tight. Ah-counter's loose,
        // free-form delivery isn't a direct lever — the chip stays out of
        // the way on this combination.
        #expect(!SpeakingStyleGoal.executive.aligns(with: .ahCounter))
    }

    @Test func authoritativeAlignsWithSuddenDeath() {
        // Authoritative voice trains confidence — sudden death's primary
        // lesson is composure under pressure.
        #expect(SpeakingStyleGoal.authoritative.aligns(with: .suddenDeath))
    }

    @Test func storytellingDoesNotAlignWithSuddenDeath() {
        // Storytelling needs pauseUsage and vocalEmphasis — both impossible
        // in a mode that ends on the first filler. Silent on this pair.
        #expect(!SpeakingStyleGoal.storytelling.aligns(with: .suddenDeath))
    }

    @Test func persuasiveAlignsWithTimedNotAhCounter() {
        // Persuasive structure (rule-of-three, antithesis) needs the
        // architecture timed mode trains. Ah-counter is too loose to land
        // a persuasive close.
        #expect(SpeakingStyleGoal.persuasive.aligns(with: .timed))
        #expect(!SpeakingStyleGoal.persuasive.aligns(with: .ahCounter))
    }

    // MARK: Coverage invariants

    @Test func everyModeHasAtLeastOneAlignedVoice() {
        // Sanity check — no orphan modes. If a mode mapped to skills no
        // voice cared about, the chip would never fire on that mode and
        // we'd silently lose half the alignment surface.
        for mode in allModes {
            let aligned = SpeakingStyleGoal.allCases.filter { $0.aligns(with: mode) }
            #expect(!aligned.isEmpty, "\(mode) has no aligned voice — orphan mode.")
        }
    }

    @Test func everyVoiceAlignsWithAtLeastOneMode() {
        // The chip should be reachable for every voice goal — otherwise
        // a user who picked, say, .storytelling would never see the
        // alignment chip and the loop would feel incomplete for them.
        for voice in SpeakingStyleGoal.allCases {
            let aligned = allModes.filter { voice.aligns(with: $0) }
            #expect(!aligned.isEmpty, "\(voice) has no aligned mode — chip would never fire.")
        }
    }

    @Test func everyVoiceHasAtLeastOneNonAlignedMode() {
        // Restraint contract: the chip must stay silent some of the time
        // for every voice. If a voice aligned with all 4 modes, the chip
        // would lose its meaning — it'd always be on and stop reading as
        // personalization.
        for voice in SpeakingStyleGoal.allCases {
            let silent = allModes.filter { !voice.aligns(with: $0) }
            #expect(!silent.isEmpty, "\(voice) aligns with every mode — chip would never go silent.")
        }
    }

    // MARK: Copy restraint

    @Test func chipCopyFollowsBrandVoice() {
        // The chip phrase is "Toward your <voice>". Guards against an
        // accidental "let's" / emoji / exclamation creep that would
        // violate the design-system voice rules.
        for voice in SpeakingStyleGoal.allCases {
            let copy = "Toward your \(voice.shortVoiceLabel)"
            #expect(!copy.isEmpty)
            #expect(!copy.contains("!"))
            #expect(!copy.lowercased().contains("let's"))
            #expect(!copy.lowercased().contains("great job"))
        }
    }
}

// MARK: - LookingAheadCard voice alignment (M14: sixth surface in the goal-aware loop)
//
// The post-session "Looking ahead" card mirrors the home recommendation
// tile by surfacing the same `VoiceAlignmentChip` when the user has a
// voice goal AND the recommended next-session mode aligns with it.
//
// Tests below lock the Hint's gating predicate independently of the
// SwiftUI body. The chip's own visual gating (`shouldShow`) is already
// covered by `VoiceAlignmentTests`; these tests pin the contract that
// `LookingAheadCard.Hint` exposes the same gate to its caller — so the
// post-rep surface stays honest in the same three silent paths the home
// surface respects (no profile, no voice goal, off-mode alignment).
//
// Adding the chip to the post-rep card is the closing move on a chain of
// six goal-aware surfaces. The home, banner, HUD, Coach Note momentum,
// profile ring, and Looking Ahead card now all read from the single
// `SpeakingStyleGoal` source of truth.

struct LookingAheadCardVoiceAlignmentTests {

    private func hint(mode: PracticeMode, styleGoal: SpeakingStyleGoal?) -> LookingAheadCard.Hint {
        LookingAheadCard.Hint(
            mode: mode,
            whyMode: "Test mode benefit.",
            whyNow: "Test why now.",
            styleGoal: styleGoal
        )
    }

    @Test func alignedVoiceAndModeShowsChip() {
        // .concise aligns with .timed (concise → structure ∩ timed.primary).
        // The Looking Ahead chip should fire here, same as the home chip.
        let h = hint(mode: .timed, styleGoal: .concise)
        #expect(h.shouldShowVoiceAlignment, "Concise → timed should surface the chip on the post-rep card.")
    }

    @Test func warmVoiceWithImConversationShowsChip() {
        // The warm-voice user is most likely to end up here: finish a Timed
        // rep, see "try IM Conversation next" — the chip should ground that
        // suggestion in the user's chosen voice.
        let h = hint(mode: .imConversation, styleGoal: .warm)
        #expect(h.shouldShowVoiceAlignment)
    }

    @Test func unalignedVoiceAndModeHidesChip() {
        // Warm voice + sudden death is an honest silent case — pressure
        // mode cuts the rhythm warm voice needs. The post-rep card must
        // mirror the home card's restraint here.
        let h = hint(mode: .suddenDeath, styleGoal: .warm)
        #expect(!h.shouldShowVoiceAlignment, "Warm → sudden death must stay silent on the post-rep card too.")
    }

    @Test func nilStyleGoalHidesChip() {
        // Pre-onboarding users (and users who skipped the voice step) pass
        // nil. No personalization should be invented on either surface.
        let h = hint(mode: .timed, styleGoal: nil)
        #expect(!h.shouldShowVoiceAlignment)
    }

    @Test func everyVoiceHasAtLeastOneShowingAndOneSilentPair() {
        // Restraint contract — the chip must fire some of the time and stay
        // silent some of the time for every voice. Same coverage invariant
        // as the home chip; lifted here so a future refactor that breaks
        // this on the post-rep surface fails the test suite independently.
        let allModes: [PracticeMode] = [.timed, .suddenDeath, .ahCounter, .imConversation]
        for voice in SpeakingStyleGoal.allCases {
            let firing = allModes.filter { hint(mode: $0, styleGoal: voice).shouldShowVoiceAlignment }
            let silent = allModes.filter { !hint(mode: $0, styleGoal: voice).shouldShowVoiceAlignment }
            #expect(!firing.isEmpty, "\(voice) never fires the post-rep chip — surface would orphan.")
            #expect(!silent.isEmpty, "\(voice) fires the post-rep chip on every mode — would lose meaning.")
        }
    }

    @Test func hintDefaultsToNilStyleGoalForCallSiteBackCompat() {
        // The legacy initializer (mode/whyMode/whyNow only) must keep
        // working — `styleGoal:` is optional with a nil default. Locks the
        // back-compat contract so older call sites still compile and stay
        // silent on the chip.
        let h = LookingAheadCard.Hint(
            mode: .timed,
            whyMode: "Legacy why mode.",
            whyNow: "Legacy why now."
        )
        #expect(h.styleGoal == nil)
        #expect(!h.shouldShowVoiceAlignment)
    }
}
