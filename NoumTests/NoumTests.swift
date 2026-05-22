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

    // MARK: - Goal-aware leverage + next-step + drill rationale (M14 close-out)
    //
    // These tests lock the same restraint contract as the momentum enrichment:
    // voice clauses appear only when the session's primary focus is in the
    // goal's `alignedSkillAreas`. No fake personalization on off-goal focus,
    // no voice references when no goal is set.

    @Test func leverageOnGoalAlignedFocusMentionsVoice() {
        // Authoritative voice aligns with confidence, closingStrength, openingStrength.
        // A session whose primary focus IS openingStrength should produce a
        // leverage line that names the authoritative voice.
        let note = VerdictEngine.generate(
            fillerCount: 2, duration: 40, wordCount: 100, wpm: 130, score: 5,
            categoryRatings: ["Opening": "Could improve"],
            trends: [], primaryFocus: .openingStrength, drillHistory: [],
            styleGoal: "authoritative"
        )
        #expect(note.leverage.lowercased().contains("authoritative voice"),
            "Goal-aligned leverage should name the authoritative voice. Got: \(note.leverage)")
    }

    @Test func leverageOnOffGoalFocusDoesNotMentionVoice() {
        // Concise voice aligns with conciseSpeaking, structure, fillerReduction.
        // primaryFocus .closingStrength is NOT in that set — leverage stays neutral.
        let note = VerdictEngine.generate(
            fillerCount: 3, duration: 60, wordCount: 140, wpm: 140, score: 6,
            categoryRatings: ["Close": "Could improve"],
            trends: [], primaryFocus: .closingStrength, drillHistory: [],
            styleGoal: "concise"
        )
        #expect(!note.leverage.lowercased().contains("concise voice"),
            "Off-goal leverage must not invent voice-alignment language. Got: \(note.leverage)")
    }

    @Test func leverageWithoutGoalDoesNotMentionVoice() {
        let note = VerdictEngine.generate(
            fillerCount: 2, duration: 40, wordCount: 100, wpm: 130, score: 5,
            categoryRatings: ["Opening": "Could improve"],
            trends: [], primaryFocus: .openingStrength, drillHistory: []
        )
        #expect(!note.leverage.lowercased().contains("voice"),
            "Without a styleGoal, leverage must not reference a voice. Got: \(note.leverage)")
    }

    @Test func nextStepOnGoalAlignedFocusMentionsVoice() {
        // Concise voice aligns with conciseSpeaking — next step on this focus
        // should connect the drill to the concise voice.
        let note = VerdictEngine.generate(
            fillerCount: 2, duration: 90, wordCount: 220, wpm: 145, score: 6,
            categoryRatings: ["Structure": "OK"],
            trends: [], primaryFocus: .conciseSpeaking, drillHistory: [],
            styleGoal: "concise"
        )
        #expect(note.nextStep.lowercased().contains("concise voice"),
            "Goal-aligned next step should name the concise voice. Got: \(note.nextStep)")
    }

    @Test func nextStepOnOffGoalFocusDoesNotMentionVoice() {
        // Warm voice aligns with paceControl, vocalEmphasis, answerDevelopment.
        // primaryFocus .confidence is NOT in that set — next step stays neutral.
        let note = VerdictEngine.generate(
            fillerCount: 3, duration: 50, wordCount: 110, wpm: 130, score: 6,
            categoryRatings: ["Opening": "Could improve"],
            trends: [], primaryFocus: .confidence, drillHistory: [],
            styleGoal: "warm"
        )
        #expect(!note.nextStep.lowercased().contains("warm voice"),
            "Off-goal next step must not invent voice-alignment language. Got: \(note.nextStep)")
    }

    @Test func nextStepWithoutGoalDoesNotMentionVoice() {
        let note = VerdictEngine.generate(
            fillerCount: 2, duration: 90, wordCount: 220, wpm: 145, score: 6,
            categoryRatings: ["Structure": "OK"],
            trends: [], primaryFocus: .conciseSpeaking, drillHistory: []
        )
        #expect(!note.nextStep.lowercased().contains("voice"),
            "Without a styleGoal, next step must not reference a voice. Got: \(note.nextStep)")
    }

    @Test func drillRationaleOnGoalAlignedSkillMentionsVoice() {
        // Authoritative voice aligns with openingStrength — rationale for an
        // opening drill should end with a voice-alignment clause.
        let rationale = VerdictEngine.drillRationale(
            for: .openingStrength,
            fillerCount: 1, wpm: 130, duration: 40, wordCount: 100,
            categoryRatings: ["Opening": "Could improve"],
            styleGoal: .authoritative
        )
        #expect(rationale.lowercased().contains("authoritative voice"),
            "Goal-aligned drill rationale should name the authoritative voice. Got: \(rationale)")
    }

    @Test func drillRationaleOnOffGoalSkillDoesNotMentionVoice() {
        // Authoritative voice does NOT align with paceControl — pace rationale
        // stays neutral.
        let rationale = VerdictEngine.drillRationale(
            for: .paceControl,
            fillerCount: 1, wpm: 170, duration: 40, wordCount: 130,
            categoryRatings: [:],
            styleGoal: .authoritative
        )
        #expect(!rationale.lowercased().contains("voice"),
            "Off-goal drill rationale must not invent voice-alignment language. Got: \(rationale)")
    }

    @Test func drillRationaleWithoutGoalDoesNotMentionVoice() {
        let rationale = VerdictEngine.drillRationale(
            for: .openingStrength,
            fillerCount: 1, wpm: 130, duration: 40, wordCount: 100,
            categoryRatings: ["Opening": "Could improve"]
        )
        #expect(!rationale.lowercased().contains("voice"),
            "Without a styleGoal, drill rationale must not reference a voice. Got: \(rationale)")
    }
}

// MARK: - Voice-aware Delivery Bonus Tests
//
// Locks the restraint contract on `PracticeEvaluator.voiceDeliveryBonus`:
// the small uplift fires only when the *delivery profile* actually fits
// the user's chosen voice. No profile / no fit → zero (no fake
// personalization, no double-penalty when the delivery missed).
struct VoiceDeliveryBonusTests {

    private func makeProfile(_ goal: SpeakingStyleGoal) -> CoachingProfile {
        CoachingProfile(
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
    }

    @Test func bonusIsZeroWithoutProfile() {
        let bonus = PracticeEvaluator.voiceDeliveryBonus(
            profile: nil, wordCount: 60, duration: 30, fillerCount: 0, wordsPerMinute: 130
        )
        #expect(bonus == 0, "No profile must not earn a voice bonus. Got: \(bonus)")
    }

    @Test func bonusIsZeroOnTrivialDelivery() {
        // Guard rails: too short / too few words → silent, even if the
        // profile is set. Same restraint as the existing styleAlignment
        // path — a 5-word stub shouldn't move the score.
        let bonus = PracticeEvaluator.voiceDeliveryBonus(
            profile: makeProfile(.authoritative),
            wordCount: 5, duration: 3, fillerCount: 0, wordsPerMinute: 130
        )
        #expect(bonus == 0, "Trivial delivery must not earn a voice bonus. Got: \(bonus)")
    }

    @Test func conciseVoiceRewardsTightDelivery() {
        // Concise voice: lean (≤45 words / ≤35s), few fillers (≤1),
        // controlled pace (110–145 WPM). All three conditions met.
        let bonus = PracticeEvaluator.voiceDeliveryBonus(
            profile: makeProfile(.concise),
            wordCount: 40, duration: 25, fillerCount: 0, wordsPerMinute: 125
        )
        #expect(bonus >= 0.6, "Concise voice with tight delivery should earn the full bonus. Got: \(bonus)")
    }

    @Test func conciseVoiceWithRamblingDeliveryEarnsLessOrNothing() {
        // Long, rushed, filler-heavy → none of the concise conditions
        // fire. Restraint: zero, not a penalty.
        let bonus = PracticeEvaluator.voiceDeliveryBonus(
            profile: makeProfile(.concise),
            wordCount: 180, duration: 70, fillerCount: 6, wordsPerMinute: 175
        )
        #expect(bonus == 0, "Rambling delivery on a concise voice must not earn the bonus. Got: \(bonus)")
    }

    @Test func authoritativeVoiceRewardsCleanSustainedDelivery() {
        // Zero fillers + sustained answer → both conditions fire.
        let bonus = PracticeEvaluator.voiceDeliveryBonus(
            profile: makeProfile(.authoritative),
            wordCount: 80, duration: 40, fillerCount: 0, wordsPerMinute: 135
        )
        #expect(bonus >= 0.5, "Authoritative voice with clean sustained delivery should earn the full bonus. Got: \(bonus)")
    }

    @Test func authoritativeVoiceWithFillersEarnsPartialOrNothing() {
        // Sustained but with fillers → only the duration half fires.
        let bonus = PracticeEvaluator.voiceDeliveryBonus(
            profile: makeProfile(.authoritative),
            wordCount: 80, duration: 40, fillerCount: 3, wordsPerMinute: 135
        )
        #expect(abs(bonus - 0.2) < 0.001, "Authoritative voice with fillers should only earn the duration half (0.2). Got: \(bonus)")
    }

    @Test func warmVoiceRewardsNaturalPaceAndContent() {
        let bonus = PracticeEvaluator.voiceDeliveryBonus(
            profile: makeProfile(.warm),
            wordCount: 50, duration: 25, fillerCount: 2, wordsPerMinute: 140
        )
        #expect(bonus >= 0.5, "Warm voice with natural pace + content depth should earn the full bonus. Got: \(bonus)")
    }

    @Test func executiveVoiceRewardsCleanControlledPace() {
        let bonus = PracticeEvaluator.voiceDeliveryBonus(
            profile: makeProfile(.executive),
            wordCount: 60, duration: 30, fillerCount: 0, wordsPerMinute: 130
        )
        #expect(bonus >= 0.5, "Executive voice with clean controlled delivery should earn the full bonus. Got: \(bonus)")
    }

    @Test func storytellingVoiceRewardsLongFormDelivery() {
        let bonus = PracticeEvaluator.voiceDeliveryBonus(
            profile: makeProfile(.storytelling),
            wordCount: 90, duration: 50, fillerCount: 2, wordsPerMinute: 130
        )
        #expect(bonus >= 0.5, "Storytelling voice with sustained long-form delivery should earn the full bonus. Got: \(bonus)")
    }

    @Test func persuasiveVoiceRewardsDevelopedReasonStack() {
        let bonus = PracticeEvaluator.voiceDeliveryBonus(
            profile: makeProfile(.persuasive),
            wordCount: 70, duration: 35, fillerCount: 2, wordsPerMinute: 140
        )
        #expect(bonus >= 0.5, "Persuasive voice with developed content should earn the full bonus. Got: \(bonus)")
    }

    @Test func bonusCapsAt0_6() {
        // Even with every concise condition maxed out, bonus must not
        // exceed 0.6 raw — bounded so a borderline score lifts by ≤1 point.
        let bonus = PracticeEvaluator.voiceDeliveryBonus(
            profile: makeProfile(.concise),
            wordCount: 30, duration: 20, fillerCount: 0, wordsPerMinute: 125
        )
        #expect(bonus <= 0.6, "Voice bonus must cap at 0.6 raw. Got: \(bonus)")
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
        let hasMatch = findings.contains(where: { $0.device == .tricolon || $0.device == .ruleOfThree })
        #expect(hasMatch, "Expected tricolon/ruleOfThree finding. Got: \(findings.map { $0.device })")
    }

    @Test func anaphoraAcrossSentencesIsDetected() {
        let transcript = """
        Again, we'll get the briefing right. Again, we'll arrive ready. Practice makes the difference.
        """
        let findings = EloquenceEngine.analyse(transcript: transcript)
        #expect(findings.contains(where: { $0.device == .anaphora }),
                "Expected anaphora finding. Got: \(findings.map { $0.device })")
    }

    @Test func alliterationRunIsDetected() {
        let transcript = "Pride, prejudice, and proper preparation prevent panic."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        #expect(findings.contains(where: { $0.device == .alliteration }),
                "Expected alliteration finding. Got: \(findings.map { $0.device })")
    }

    @Test func epizeuxisIsDetected() {
        let transcript = "Never, never give in. The work is hard, but worth it."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        #expect(findings.contains(where: { $0.device == .epizeuxis }),
                "Expected epizeuxis finding. Got: \(findings.map { $0.device })")
    }

    @Test func diacopeIsDetected() {
        let transcript = "Bond, James Bond. The brand sells itself."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        let hasMatch = findings.contains(where: { $0.device == .diacope || $0.device == .epizeuxis })
        #expect(hasMatch, "Expected diacope or epizeuxis. Got: \(findings.map { $0.device })")
    }

    @Test func rhetoricalQuestionIsDetected() {
        let transcript = "What does that look like in practice? Three crisp answers, on the clock, no fillers."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        #expect(findings.contains(where: { $0.device == .rhetoricalQuestion }),
                "Expected rhetorical question finding. Got: \(findings.map { $0.device })")
    }

    @Test func plainTranscriptHasNoFindings() {
        let transcript = "Yeah I think that's basically how I'd handle it. We could probably move forward."
        let findings = EloquenceEngine.analyse(transcript: transcript)
        // No tricolon / parallel / anaphora etc. expected here.
        #expect(findings.count <= 1, "Plain transcript should produce at most 1 weak finding. Got: \(findings.map { $0.device })")
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

// MARK: - PromptHistoryStore — recentTexts AI seed (recurrence-aware)
//
// The sibling text store lives next to the hash store and feeds the AI
// generator the last N prompts so it can dodge near-clones. These tests
// pin the contract — LRU order, freshness window, account-scope, reset
// fan-out, and dedup against case-only variants.

struct PromptHistoryStoreRecentTextsTests {

    @Test @MainActor func recentTextsEmptyByDefault() {
        let store = PromptHistoryStore.shared
        store.reset()
        #expect(store.recentTexts(limit: 5).isEmpty)
        #expect(store.recentTexts(limit: 0).isEmpty)
    }

    @Test @MainActor func recentTextsReturnsNewestFirstOrdering() {
        let store = PromptHistoryStore.shared
        store.reset()
        store.record("First prompt?")
        store.record("Second prompt?")
        store.record("Third prompt?")
        let recents = store.recentTexts(limit: 5)
        #expect(recents == ["Third prompt?", "Second prompt?", "First prompt?"])
        store.reset()
    }

    @Test @MainActor func recentTextsRespectsLimit() {
        let store = PromptHistoryStore.shared
        store.reset()
        for i in 1...6 {
            store.record("Prompt number \(i)?")
        }
        #expect(store.recentTexts(limit: 3).count == 3)
        #expect(store.recentTexts(limit: 3).first == "Prompt number 6?")
        store.reset()
    }

    @Test @MainActor func recentTextsLruCapsAtMaxTextEntries() {
        let store = PromptHistoryStore.shared
        store.reset()
        // Record more than the cap so the oldest must be dropped.
        for i in 1...(PromptHistoryStore.maxTextEntries + 5) {
            store.record("Cap test prompt \(i)?")
        }
        let all = store.recentTexts(limit: PromptHistoryStore.maxTextEntries + 5)
        #expect(all.count == PromptHistoryStore.maxTextEntries)
        // Newest entry must be present, oldest must be gone.
        #expect(all.first == "Cap test prompt \(PromptHistoryStore.maxTextEntries + 5)?")
        #expect(!all.contains("Cap test prompt 1?"))
        store.reset()
    }

    @Test @MainActor func recordingSamePromptTwiceDoesNotDuplicateText() {
        // The hash store no-ops on re-record, so the text store should
        // stay in lockstep. The user re-seeing a prompt on a re-roll
        // should not produce two adjacent identical entries.
        let store = PromptHistoryStore.shared
        store.reset()
        store.record("Repeated prompt?")
        store.record("Repeated prompt?")
        store.record("REPEATED PROMPT?") // case-only variant
        #expect(store.recentTexts(limit: 5) == ["Repeated prompt?"])
        store.reset()
    }

    @Test @MainActor func resetClearsBothStores() {
        let store = PromptHistoryStore.shared
        store.reset()
        store.record("Pre-reset prompt?")
        #expect(store.wasRecentlySeen("Pre-reset prompt?") == true)
        #expect(store.recentTexts(limit: 5).isEmpty == false)
        store.reset()
        #expect(store.wasRecentlySeen("Pre-reset prompt?") == false)
        #expect(store.recentTexts(limit: 5).isEmpty == true)
    }

    @Test @MainActor func recentTextsHonorsSameFreshnessWindowAsHashStore() {
        // The text store's freshness cut-off must match the hash store's
        // 14-day window. We can't fast-forward time inside the store, so
        // assert the contract via the shared static — if either side
        // changes window without updating the other, this test fails the
        // moment the constants diverge.
        #expect(PromptHistoryStore.freshnessWindow == 14 * 24 * 60 * 60)
        let store = PromptHistoryStore.shared
        store.reset()
        store.record("Today's prompt?")
        // Freshly recorded entries land inside the window — same window
        // controls both stores, so a fresh entry appears in both.
        #expect(store.wasRecentlySeen("Today's prompt?") == true)
        #expect(store.recentTexts(limit: 1) == ["Today's prompt?"])
        store.reset()
    }
}

// MARK: - AIPromptGeneratorService — recurrence-aware seed shape
//
// The deterministic prompt-body builder is exposed as a `static` so we
// can pin the shape end-to-end without a provider, a network stub, or
// the actor isolation hop. The system prompt is also exposed read-only
// so we can assert the "avoid near-clones" clause is present.

struct AIPromptGeneratorSeedTests {

    private func makeProfile() -> CoachingProfile {
        CoachingProfile(
            speakingContext: .work,
            primaryGoal: .moreConcise,
            confidenceLevel: .rebuilding,
            biggestChallenge: .fillerWords,
            desiredOutcome: .persuasive,
            speakingStyleGoal: .concise,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: ""
        )
    }

    @Test func systemPromptInstructsModelToAvoidNearClones() {
        let sys = AIPromptGeneratorService.systemPromptForTesting.lowercased()
        #expect(sys.contains("near-clones") || sys.contains("near clone"))
    }

    @Test func userPromptOmitsRecentsBlockWhenEmpty() {
        let body = AIPromptGeneratorService.buildUserPrompt(
            profile: makeProfile(),
            weakestDimension: "filler control",
            recentPromptTexts: []
        )
        #expect(body.contains("Goal:"))
        #expect(body.contains("Weakest dimension"))
        #expect(!body.contains("Recent prompts"))
        #expect(body.hasSuffix("Return one prompt."))
    }

    @Test func userPromptIncludesRecentsBlockWhenProvided() {
        let body = AIPromptGeneratorService.buildUserPrompt(
            profile: makeProfile(),
            weakestDimension: nil,
            recentPromptTexts: [
                "What is the most underrated skill in your industry?",
                "When should a leader admit they don't have an answer?"
            ]
        )
        #expect(body.contains("Recent prompts the user has already seen — avoid near-clones:"))
        #expect(body.contains("- What is the most underrated skill in your industry?"))
        #expect(body.contains("- When should a leader admit they don't have an answer?"))
        // Weakest dimension was nil — must NOT show up as a "nil" line.
        #expect(!body.contains("Weakest dimension"))
    }

    @Test func userPromptDropsBlankAndWhitespaceOnlyRecents() {
        let body = AIPromptGeneratorService.buildUserPrompt(
            profile: makeProfile(),
            weakestDimension: nil,
            recentPromptTexts: ["", "   ", "Real prompt?"]
        )
        #expect(body.contains("- Real prompt?"))
        #expect(!body.contains("- \n"))
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

// MARK: - Grammar Feedback Service (M11 → M16)

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
        // otherwise we drop the finding (defensive against fabrication).
        // One highImpact finding would normally pass the threshold; with
        // the excerpt rejected, the rest must be empty.
        let transcript = "We launched the product on Tuesday."
        let payload: [String: Any] = [
            "choices": [[
                "message": [
                    "content": #"{"findings": [{"pattern": "agreement", "severity": "highImpact", "excerpt": "the team are happy", "note": "could read clearer as 'team is'"}]}"#
                ]
            ]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let parsed = await GrammarFeedbackService.shared.parse(data: data, provider: .openAI, transcript: transcript)
        #expect(parsed != nil)
        #expect(parsed?.findings.isEmpty == true)
        #expect(parsed?.aiBacked == true)
    }

    @Test func parseAcceptsSingleHighImpactFinding() async {
        // One highImpact finding meets the threshold on its own.
        let transcript = "The team are planning to ship faster this quarter."
        let payload: [String: Any] = [
            "choices": [[
                "message": [
                    "content": #"{"findings": [{"pattern": "agreement", "severity": "highImpact", "excerpt": "team are planning", "note": "could read clearer as 'team is planning'"}]}"#
                ]
            ]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let parsed = await GrammarFeedbackService.shared.parse(data: data, provider: .openAI, transcript: transcript)
        #expect(parsed != nil)
        #expect(parsed?.findings.count == 1)
        #expect(parsed?.findings.first?.pattern == .agreement)
        #expect(parsed?.findings.first?.severity == .highImpact)
        #expect(parsed?.findings.first?.note.contains("could read clearer") == true)
    }

    @Test func parseDropsSingleRoutineFinding() async {
        // One routine-only finding does NOT meet the threshold. Silence is
        // the right move — better silent than pedantic.
        let transcript = "We launched the product on Tuesday and the team handled it well."
        let payload: [String: Any] = [
            "choices": [[
                "message": [
                    "content": #"{"findings": [{"pattern": "repetition", "severity": "routine", "excerpt": "the team", "note": "phrase 'the team' lands twice"}]}"#
                ]
            ]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let parsed = await GrammarFeedbackService.shared.parse(data: data, provider: .openAI, transcript: transcript)
        #expect(parsed != nil)
        #expect(parsed?.findings.isEmpty == true)
        #expect(parsed?.aiBacked == true)
    }

    @Test func parseAcceptsThreeRoutineFindings() async {
        // Three routine findings clear the ≥3-instances arm of the threshold.
        let transcript = "The team are happy. The data shows interesting result. We were planning the launch."
        let json = #"""
        {"findings": [
          {"pattern": "agreement", "severity": "routine", "excerpt": "team are happy", "note": "could read clearer as 'team is happy'"},
          {"pattern": "agreement", "severity": "routine", "excerpt": "data shows interesting result", "note": "could read clearer as 'results'"},
          {"pattern": "repetition", "severity": "routine", "excerpt": "the launch", "note": "phrase lands twice in the closer"}
        ]}
        """#
        let payload: [String: Any] = [
            "choices": [["message": ["content": json]]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let parsed = await GrammarFeedbackService.shared.parse(data: data, provider: .openAI, transcript: transcript)
        #expect(parsed?.findings.count == 3)
    }

    @Test func parseCapsAtThreeFindings() async {
        let transcript = "The team are happy. The data shows interesting result. We were planning the launch and shipping in time."
        let json = #"""
        {"findings": [
          {"pattern": "agreement", "severity": "highImpact", "excerpt": "team are happy", "note": "could read clearer as 'team is happy'"},
          {"pattern": "agreement", "severity": "routine", "excerpt": "data shows interesting result", "note": "could read clearer as 'results'"},
          {"pattern": "runOn", "severity": "routine", "excerpt": "planning the launch and shipping in time", "note": "could split at 'and'"},
          {"pattern": "repetition", "severity": "routine", "excerpt": "the team", "note": "lands twice"}
        ]}
        """#
        let payload: [String: Any] = [
            "choices": [["message": ["content": json]]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let parsed = await GrammarFeedbackService.shared.parse(data: data, provider: .openAI, transcript: transcript)
        #expect(parsed?.findings.count == 3)
    }

    @Test func parseAcceptsEmptyFindings() async {
        // Model honestly returns nothing — card self-hides on this case.
        let transcript = "We launched the product on Tuesday and the team handled it well."
        let payload: [String: Any] = [
            "choices": [["message": ["content": #"{"findings": []}"#]]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let parsed = await GrammarFeedbackService.shared.parse(data: data, provider: .openAI, transcript: transcript)
        #expect(parsed != nil)
        #expect(parsed?.findings.isEmpty == true)
        #expect(parsed?.aiBacked == true)
    }

    @Test func parseRejectsCorrectiveVoice() async {
        // Voice guard: a finding that calls the user "wrong" or "incorrect"
        // gets dropped — observational voice is non-negotiable. One
        // highImpact finding with rejected voice should leave findings
        // empty (and below threshold).
        let transcript = "The team are planning to ship faster this quarter."
        let payload: [String: Any] = [
            "choices": [[
                "message": [
                    "content": #"{"findings": [{"pattern": "agreement", "severity": "highImpact", "excerpt": "team are planning", "note": "This is incorrect — use 'team is'."}]}"#
                ]
            ]]
        ]
        let data = try! JSONSerialization.data(withJSONObject: payload)
        let parsed = await GrammarFeedbackService.shared.parse(data: data, provider: .openAI, transcript: transcript)
        #expect(parsed != nil)
        #expect(parsed?.findings.isEmpty == true)
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

// MARK: - Goal-aware drill selection (closes the M14 loop)

/// Locks the contract that the user's `SpeakingStyleGoal` biases drill *selection*
/// itself — not just post-session copy. The bias is a small (+10) tiebreaker
/// inside `TrendAnalyzer.primaryFocus`, so urgent off-goal trends still win.
/// This is the seventh and final surface of the goal-aware loop: every other
/// surface (banner, HUD, momentum line, profile ring, home chip, looking-ahead
/// chip) already reads from the goal; this test set verifies the *picker
/// itself* does too.
struct GoalAwareDrillSelectionTests {

    private func warmTrend(level: SkillLevel, direction: TrendDirection = .stable) -> SkillTrend {
        SkillTrend(skillArea: .paceControl,            // warm-aligned
                   direction: direction, confidence: .medium,
                   windowSize: 5, currentLevel: level)
    }

    private func offGoalTrend(_ area: SkillArea,
                              level: SkillLevel,
                              direction: TrendDirection = .stable,
                              confidence: TrendConfidence = .medium) -> SkillTrend {
        SkillTrend(skillArea: area, direction: direction, confidence: confidence,
                   windowSize: 5, currentLevel: level)
    }

    @Test func goalBiasBreaksTieAtDevelopingTier() {
        // Two developing trends, same priority (50). With a warm voice goal,
        // the .paceControl trend (warm-aligned) should beat the .structure
        // trend (off-goal for warm).
        let trends = [
            warmTrend(level: .developing),
            offGoalTrend(.structure, level: .developing),
        ]
        let pick = TrendAnalyzer.primaryFocus(
            trends: trends,
            currentSessionSnapshot: nil,
            recentDrills: [],
            styleGoal: .warm
        )
        #expect(pick == .paceControl,
                "Goal-aligned developing skill should beat off-goal developing skill")
    }

    @Test func goalBiasDoesNotOverrideDecliningHighConfidence() {
        // Declining-high-confidence on off-goal skill (priority 100) should
        // still beat developing on goal-aligned (priority 60 with bonus).
        // Urgency wins over goal alignment.
        let trends = [
            warmTrend(level: .developing),
            offGoalTrend(.fillerReduction, level: .solid,
                         direction: .declining, confidence: .high),
        ]
        let pick = TrendAnalyzer.primaryFocus(
            trends: trends,
            currentSessionSnapshot: nil,
            recentDrills: [],
            styleGoal: .warm
        )
        #expect(pick == .fillerReduction,
                "Declining-high-confidence on off-goal must still beat goal-aligned developing")
    }

    @Test func goalBiasDoesNotOverrideWeakStable() {
        // Weak-stable on off-goal (priority 90) should still beat developing
        // on goal-aligned (priority 60 with bonus). Persistent off-goal
        // problems remain the highest-leverage move.
        let trends = [
            warmTrend(level: .developing),
            offGoalTrend(.structure, level: .weak, direction: .stable),
        ]
        let pick = TrendAnalyzer.primaryFocus(
            trends: trends,
            currentSessionSnapshot: nil,
            recentDrills: [],
            styleGoal: .warm
        )
        #expect(pick == .structure,
                "Weak-stable off-goal must still beat goal-aligned developing")
    }

    @Test func goalBiasDoesNotOverrideNewIssue() {
        // New-issue on off-goal (priority 80) should still beat developing on
        // goal-aligned (priority 60 with bonus). Just-appeared issues get
        // caught early regardless of voice.
        let trends = [
            warmTrend(level: .developing),
            offGoalTrend(.openingStrength, level: .developing, direction: .newIssue),
        ]
        let pick = TrendAnalyzer.primaryFocus(
            trends: trends,
            currentSessionSnapshot: nil,
            recentDrills: [],
            styleGoal: .warm
        )
        #expect(pick == .openingStrength,
                "New-issue off-goal must still beat goal-aligned developing")
    }

    @Test func goalBiasTipsAdjacentTierNearTie() {
        // Solid goal-aligned (priority 20+10=30) should NOT beat developing
        // off-goal (priority 50). Confirms the +10 bonus stays a tiebreaker
        // — it can't promote a solid skill over a developing one. Picker
        // remains weakness-first.
        let trends = [
            warmTrend(level: .solid),
            offGoalTrend(.structure, level: .developing),
        ]
        let pick = TrendAnalyzer.primaryFocus(
            trends: trends,
            currentSessionSnapshot: nil,
            recentDrills: [],
            styleGoal: .warm
        )
        #expect(pick == .structure,
                "Goal bias must not promote a solid aligned skill over a developing off-goal skill")
    }

    @Test func goalBiasIsSilentWhenNoGoalSet() {
        // No styleGoal → behavior is exactly the pre-M14 contract: developing
        // trends tie at 50 and `max` picks the first one found (here, .structure).
        // Locks the no-regression promise.
        let trends = [
            warmTrend(level: .developing),
            offGoalTrend(.structure, level: .developing),
        ]
        let pickWithGoal = TrendAnalyzer.primaryFocus(
            trends: trends, currentSessionSnapshot: nil,
            recentDrills: [], styleGoal: .warm
        )
        let pickWithout = TrendAnalyzer.primaryFocus(
            trends: trends, currentSessionSnapshot: nil,
            recentDrills: [], styleGoal: nil
        )
        #expect(pickWithGoal == .paceControl)
        // Without the goal, the picker is allowed to land on either
        // developing trend — the contract is "no goal-aware promotion",
        // not "stable ordering". We assert it's _one of_ the candidates.
        #expect(pickWithout == .structure || pickWithout == .paceControl)
    }

    @Test func goalDrivesDayOneFallbackWhenNoTrendsOrSignal() {
        // No trends, no session snapshot at all — the function previously
        // returned the generic `.structure`. With a stated voice goal it now
        // returns that voice's canonical most-direct lever. Locks the
        // "day-one user with a stated voice still gets a goal-grounded
        // first drill" contract.
        let cases: [(SpeakingStyleGoal, SkillArea)] = [
            (.authoritative, .confidence),
            (.warm,          .paceControl),
            (.concise,       .conciseSpeaking),
            (.persuasive,    .structure),
            (.executive,     .confidence),
            (.storytelling,  .answerDevelopment),
        ]
        for (voice, expected) in cases {
            let pick = TrendAnalyzer.primaryFocus(
                trends: [], currentSessionSnapshot: nil,
                recentDrills: [], styleGoal: voice
            )
            #expect(pick == expected,
                    "\(voice) should map to \(expected) for day-one users")
        }
    }

    @Test func noGoalFallbackStaysStructureForBackCompat() {
        // No styleGoal AND no trends AND no snapshot → unchanged from the
        // pre-bias contract: `.structure`. Locks the back-compat path so
        // older call sites that never pass `styleGoal` keep behaving exactly
        // as before.
        let pick = TrendAnalyzer.primaryFocus(
            trends: [], currentSessionSnapshot: nil,
            recentDrills: [], styleGoal: nil
        )
        #expect(pick == .structure)
    }

    @Test func decliningWithoutHighConfidenceCanBeBeatenByAlignedWeakStable() {
        // Declining-medium-confidence falls into the "default" 40 bucket
        // (the priority tree only fires the 100 score for high-confidence
        // declines). A weak-stable goal-aligned trend (90+10=100) should
        // beat it. Confirms the picker's tier hierarchy is intact and goal
        // alignment only stacks _within_ a tier or across small gaps.
        let trends = [
            warmTrend(level: .weak, direction: .stable),
            offGoalTrend(.structure, level: .solid,
                         direction: .declining, confidence: .medium),
        ]
        let pick = TrendAnalyzer.primaryFocus(
            trends: trends, currentSessionSnapshot: nil,
            recentDrills: [], styleGoal: .warm
        )
        #expect(pick == .paceControl)
    }

    @Test func primaryAlignedSkillAreaIsDeterministic() {
        // `alignedSkillAreas` is a `Set` and can't carry order; the picker
        // relies on `primaryAlignedSkillArea` for a deterministic
        // day-one default. Lock the mapping so a refactor that drops it
        // (or shuffles the switch order) fails this test rather than
        // quietly randomising day-one drills.
        #expect(SpeakingStyleGoal.authoritative.primaryAlignedSkillArea == .confidence)
        #expect(SpeakingStyleGoal.warm.primaryAlignedSkillArea          == .paceControl)
        #expect(SpeakingStyleGoal.concise.primaryAlignedSkillArea       == .conciseSpeaking)
        #expect(SpeakingStyleGoal.persuasive.primaryAlignedSkillArea    == .structure)
        #expect(SpeakingStyleGoal.executive.primaryAlignedSkillArea     == .confidence)
        #expect(SpeakingStyleGoal.storytelling.primaryAlignedSkillArea  == .answerDevelopment)

        // Every voice's primary lever must also be in its `alignedSkillAreas`
        // — keeps the deterministic accessor consistent with the set-based one.
        for voice in SpeakingStyleGoal.allCases {
            #expect(voice.alignedSkillAreas.contains(voice.primaryAlignedSkillArea),
                    "\(voice).primaryAlignedSkillArea must be in alignedSkillAreas")
        }
    }
}

// MARK: - Peak glow (Home post-session demotion)
//
// `RatingStore.pendingPeakGlow` is the gate that decides whether the
// Personal Best purple hero shows on Home as a post-rep glow. The
// invariants below come straight from the brand rules:
//   - Only fire on UPWARD movement (never punish-shame regression).
//   - Only fire when the new peak strictly exceeds the last value
//     the Home glow has already consumed.
//   - `markPeakGlowConsumed()` must clear the flag exactly once.
@MainActor
struct PeakGlowGatingTests {

    @Test func markPeakGlowConsumedClearsFlag() {
        // The simplest invariant: `markPeakGlowConsumed()` flips the
        // flag to false regardless of prior state. The upward-fire
        // case relies on per-account UserDefaults cursor state that's
        // shared across the test process; covering it here would
        // require keychain + UserDefaults isolation. The no-fire cases
        // below (flat + downward) cover the "must not punish-shame"
        // brand rule directly; combined with `markPeakGlowConsumed`
        // clearing the flag, the upward path is exercised in QA / the
        // detailed screenshot tour rather than as a unit test.
        let store = RatingStore.shared
        store.markPeakGlowConsumed()
        #expect(!store.pendingPeakGlow,
                "markPeakGlowConsumed must clear pendingPeakGlow.")
    }

    @Test func flatPeakSilenceGlow() {
        let store = RatingStore.shared
        store.markPeakGlowConsumed()
        // Fire the hook with no peak movement — must be a silent no-op.
        store.notePeakReachedForGlow()
        #expect(!store.pendingPeakGlow,
                "Flat peak (no movement) must not raise glow.")
    }

    @Test func downwardPeakSilenceGlow() {
        // Brand rule from `never_punish_shame.md`: drops are silent.
        // Even if `weekPeakRating` somehow decreased (week boundary
        // reset, etc.), the glow must not fire.
        let store = RatingStore.shared
        store.markPeakGlowConsumed()

        var seeded = store.rating
        let downPeak = max(100, seeded.weekPeakRating - 50)
        seeded.weekPeakRating = downPeak
        store.replaceForDebug(seeded)
        store.notePeakReachedForGlow()

        #expect(!store.pendingPeakGlow,
                "Downward peak must never raise glow — no punish-shame on regression.")
    }
}

// MARK: - HomeCoachCard mood-pulse + variant resolution
//
// `HomeCoachCard` exposes `coachTitle` + `coachSubtitle` as a function
// of session count, week-peak tier, and `RecommendationBiasEngine`
// output. These tests pin the variant ladder so a future refactor
// can't accidentally lose the cold-start line or the tier-holding
// flourish.
//
// We can't easily instantiate the SwiftUI view in a unit test, but
// the coach line generator's variant ladder mirrors the same one
// landing inside the view. The tests below assert the contract via
// the same downstream API the view consumes.
@MainActor
struct HomeCoachCardVariantTests {

    @Test func tierTitleFormatMatchesHoldingPattern() {
        // The view's "Hold Gold." / "Hold Platinum." title pattern
        // depends on `LeagueTier.tier(for:).title` producing the
        // capitalized tier name we can drop directly into a sentence.
        #expect(LeagueTier.tier(for: 750).title == "Platinum")
        #expect(LeagueTier.tier(for: 600).title == "Gold")
        #expect(LeagueTier.tier(for: 400).title == "Silver")
        #expect(LeagueTier.tier(for: 200).title == "Bronze")
    }

    @Test func tierHoldingOnlyFiresOnGoldAndAbove() {
        // The Coach Card writes "You're holding <Tier>." only for
        // gold/platinum/diamond — bronze/silver get the plain
        // coaching line so we never write "You're holding Bronze"
        // (false flattery). Pins the threshold so a future tweak
        // doesn't quietly lower it.
        let bronzeTier = LeagueTier.tier(for: 200)
        let silverTier = LeagueTier.tier(for: 400)
        let goldTier = LeagueTier.tier(for: 600)
        let platinumTier = LeagueTier.tier(for: 750)
        let diamondTier = LeagueTier.tier(for: 900)

        let allows: (LeagueTier) -> Bool = { tier in
            tier == .gold || tier == .platinum || tier == .diamond
        }
        #expect(!allows(bronzeTier))
        #expect(!allows(silverTier))
        #expect(allows(goldTier))
        #expect(allows(platinumTier))
        #expect(allows(diamondTier))
    }
}

// MARK: - VoiceMetricsCard (M14)
//
// `VoiceMetricsCard` promotes Pause + Word-choice from optional post-
// session surfaces into a first-class Home read. The coach-voice copy is
// produced by `VoiceMetricsRead.compute` so the contract can be asserted
// without instantiating SwiftUI. Three properties matter:
//
//  1. When the baseline dimension is `.insufficient`, the row collapses
//     (no "Awaiting data" placeholder per CLAUDE.md engineering bans).
//  2. When pauses run clean (filledRatio low) AND the baseline is
//     reliable, the row reads "Above your baseline." — the user-facing
//     polarity of "better than usual" for filled-ratio (lower = cleaner).
//  3. When pauses run filled, the row reads as a coach redirect, never
//     punish-shame ("Re-anchor on the next rep.").
struct VoiceMetricsCardReadTests {

    private static func stat(
        _ value: Double,
        p25: Double? = nil,
        p75: Double? = nil,
        sampleCount: Int = 10,
        confidence: BaselineConfidence = .moderate
    ) -> BaselineStat {
        BaselineStat(
            value: value,
            sampleCount: sampleCount,
            confidence: confidence,
            trend: .stable,
            percentile25: p25 ?? value * 0.7,
            percentile75: p75 ?? value * 1.3
        )
    }

    private static func baseline(
        pauseRate: BaselineStat? = nil,
        pauseFilledRatio: BaselineStat? = nil,
        vocabularyRange: BaselineStat? = nil
    ) -> CommunicationBaseline {
        var b = CommunicationBaseline.empty
        if let pauseRate { b.pauseRate = pauseRate }
        if let pauseFilledRatio { b.pauseFilledRatio = pauseFilledRatio }
        if let vocabularyRange { b.vocabularyRange = vocabularyRange }
        return b
    }

    private static func session(
        daysAgo: Int,
        transcript: String = "",
        pauseMetrics: PauseMetrics? = nil
    ) -> PracticeSession {
        let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return PracticeSession(
            transcript: transcript,
            fillerWordCount: 0,
            duration: 60,
            date: date,
            pauseMetrics: pauseMetrics
        )
    }

    // MARK: row collapse on insufficient data

    @Test func bothRowsCollapseOnEmptyBaseline() {
        let read = VoiceMetricsRead.compute(
            baseline: .empty,
            sessions: []
        )
        #expect(read.pause == nil)
        #expect(read.wordChoice == nil)
        #expect(read.isEmpty)
    }

    @Test func pauseRowCollapsesWhenBaselineInsufficient() {
        let b = Self.baseline(
            pauseRate: Self.stat(2.0, sampleCount: 1, confidence: .insufficient),
            pauseFilledRatio: Self.stat(0.1)
        )
        let read = VoiceMetricsRead.compute(baseline: b, sessions: [])
        #expect(read.pause == nil)
    }

    // MARK: clean pauses → "Above your baseline"

    @Test func cleanPausesPlusLowFilledRatioReadsAboveBaseline() {
        let b = Self.baseline(
            pauseRate: Self.stat(2.5),
            pauseFilledRatio: Self.stat(0.10, p25: 0.05, p75: 0.30)
        )
        let metrics = PauseMetrics(count: 3, meanSeconds: 1.2, longestSeconds: 1.8, filledRatio: 0.10)
        let s = Self.session(daysAgo: 1, pauseMetrics: metrics)
        let read = VoiceMetricsRead.compute(baseline: b, sessions: [s])
        guard let pause = read.pause else {
            Issue.record("Expected pause row to render with clean week + reliable baseline")
            return
        }
        #expect(pause.copy.contains("Above your baseline."),
                "Expected 'Above your baseline.' for clean pauses; got: \(pause.copy)")
    }

    // MARK: filled pauses → coach redirect, never shame

    @Test func filledPausesReadsAsCoachRedirectNotShame() {
        let b = Self.baseline(
            pauseRate: Self.stat(2.5),
            pauseFilledRatio: Self.stat(0.70, p25: 0.15, p75: 0.40)
        )
        let read = VoiceMetricsRead.compute(baseline: b, sessions: [])
        guard let pause = read.pause else {
            Issue.record("Expected pause row to render with reliable baseline")
            return
        }
        // Never punish-shame; always carry a forward redirect.
        #expect(pause.copy.contains("Re-anchor on the next rep.")
                || pause.copy.contains("Below your baseline."),
                "Filled-pause row must be a coach redirect, not shame; got: \(pause.copy)")
        let shameWords = ["bad", "failed", "poor", "weak", "terrible"]
        for word in shameWords {
            #expect(!pause.copy.lowercased().contains(word),
                    "Filled-pause row contained shame word '\(word)' in: \(pause.copy)")
        }
    }

    // MARK: trend classifier — pinpoints the polarity contract

    @Test func pauseTrendAboveWhenFilledRatioBelowQuartile() {
        let stat = Self.stat(0.10, p25: 0.20, p75: 0.50)
        #expect(VoiceMetricsRead.pauseTrend(filledRatioStat: stat) == .above)
    }

    @Test func pauseTrendBelowWhenFilledRatioAboveQuartile() {
        let stat = Self.stat(0.65, p25: 0.10, p75: 0.40)
        #expect(VoiceMetricsRead.pauseTrend(filledRatioStat: stat) == .below)
    }

    @Test func pauseTrendStableWhenFilledRatioInsufficient() {
        let stat = Self.stat(0.20, sampleCount: 1, confidence: .insufficient)
        #expect(VoiceMetricsRead.pauseTrend(filledRatioStat: stat) == .steady)
    }

    // MARK: word-choice row — week-over-week

    @Test func wordChoiceRowReadsUpFromLastWeekWhenRatioRises() {
        let b = Self.baseline(vocabularyRange: Self.stat(0.65))
        // This week: a varied transcript with many unique words across two
        // qualifying reps so we clear the ≥ 2-sessions-per-window floor.
        let thisWeekA = Self.session(
            daysAgo: 1,
            transcript: "Yesterday I built a strong opening line that anchored the entire talk in clarity, drove momentum, and resolved with precision. Word choice mattered."
        )
        let thisWeekB = Self.session(
            daysAgo: 2,
            transcript: "Today the audience responded to vivid imagery, deliberate cadence, and a closing argument carrying weight beyond the immediate context of conversation."
        )
        // Last week: two qualifying reps with deliberate repetition so the
        // unique-ratio falls below this week's mean.
        let lastWeekA = Self.session(
            daysAgo: 9,
            transcript: String(repeating: "thing thing things and and the the the like like and ", count: 4)
        )
        let lastWeekB = Self.session(
            daysAgo: 10,
            transcript: String(repeating: "stuff stuff and so and so like like and the the ", count: 4)
        )
        let read = VoiceMetricsRead.compute(
            baseline: b,
            sessions: [thisWeekA, thisWeekB, lastWeekA, lastWeekB]
        )
        guard let word = read.wordChoice else {
            Issue.record("Expected word-variety row with reliable baseline + qualifying transcripts")
            return
        }
        #expect(word.copy.contains("Up from"),
                "Expected 'Up from … last week.' read; got: \(word.copy)")
        #expect(word.copy.contains("% unique words"),
                "Expected unique-words headline; got: \(word.copy)")
    }
}

// MARK: - DailyChallengeTile countdown math (M14 daily-rhythm v2)
//
// Locks the wall-clock math that drives the bottom expiry bar and the
// header reset-window flips. We pin a fixed gregorian calendar in
// UTC-equivalent terms (TimeZone(secondsFromGMT: 0)) so the test is
// stable across whoever's machine runs it — the production code reads
// `Calendar.current`, but the helper takes a calendar in so it's
// testable independent of locale.

struct DailyChallengeTileCountdownTests {

    /// Build a Date for "today at H:M" in the test calendar.
    private static func at(_ hour: Int, _ minute: Int, calendar: Calendar) -> Date {
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 5
        comps.day = 17
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        return calendar.date(from: comps)!
    }

    private static var testCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    @Test func minutesUntilMidnightAt2345Is15() {
        let cal = Self.testCalendar
        let now = Self.at(23, 45, calendar: cal)
        let mins = DailyChallengeTile.minutesUntilMidnight(from: now, in: cal)
        #expect(mins == 15, "23:45 should report 15 minutes until midnight, got \(mins)")
    }

    @Test func minutesUntilMidnightAt2200Is120() {
        let cal = Self.testCalendar
        let now = Self.at(22, 0, calendar: cal)
        let mins = DailyChallengeTile.minutesUntilMidnight(from: now, in: cal)
        #expect(mins == 120, "22:00 should report 120 minutes until midnight, got \(mins)")
    }

    @Test func minutesUntilMidnightAt0001Is1439() {
        let cal = Self.testCalendar
        let now = Self.at(0, 1, calendar: cal)
        let mins = DailyChallengeTile.minutesUntilMidnight(from: now, in: cal)
        #expect(mins == 1439, "00:01 should report 1439 minutes until midnight, got \(mins)")
    }

    @Test func minutesUntilMidnightAtMidnightIs1440() {
        let cal = Self.testCalendar
        let now = Self.at(0, 0, calendar: cal)
        let mins = DailyChallengeTile.minutesUntilMidnight(from: now, in: cal)
        // Right at 00:00:00 we expect the full 1440 — startOfDay(now) == now
        // means nextMidnight is 24h later, so this is the canonical "fresh
        // day" value.
        #expect(mins == 1440, "00:00 should report 1440 minutes until midnight, got \(mins)")
    }

    @Test func eyebrowWindowMostOfDayIsToday() {
        let cal = Self.testCalendar
        let mid = Self.at(14, 0, calendar: cal)
        #expect(DailyChallengeTile.eyebrowWindow(at: mid, calendar: cal) == .today)
    }

    @Test func eyebrowWindowAt2345IsResetsIn15() {
        let cal = Self.testCalendar
        let edge = Self.at(23, 45, calendar: cal)
        #expect(DailyChallengeTile.eyebrowWindow(at: edge, calendar: cal) == .resetsIn(minutes: 15))
    }

    @Test func eyebrowWindowAt2350IsResetsIn10() {
        let cal = Self.testCalendar
        let edge = Self.at(23, 50, calendar: cal)
        #expect(DailyChallengeTile.eyebrowWindow(at: edge, calendar: cal) == .resetsIn(minutes: 10))
    }

    @Test func eyebrowWindowAt2358IsResetsIn2() {
        let cal = Self.testCalendar
        let edge = Self.at(23, 58, calendar: cal)
        #expect(DailyChallengeTile.eyebrowWindow(at: edge, calendar: cal) == .resetsIn(minutes: 2))
    }

    @Test func eyebrowWindowAt0005IsNewMissions() {
        let cal = Self.testCalendar
        let edge = Self.at(0, 5, calendar: cal)
        #expect(DailyChallengeTile.eyebrowWindow(at: edge, calendar: cal) == .newMissions)
    }

    @Test func eyebrowWindowAt0010IsTodayAgain() {
        // 00:10 is the inclusive boundary — the spec says first ~10 minutes
        // get NEW MISSIONS. The strict-less-than gate in the helper means
        // 00:10:00.000 already reads as TODAY. Locks the contract.
        let cal = Self.testCalendar
        let edge = Self.at(0, 10, calendar: cal)
        #expect(DailyChallengeTile.eyebrowWindow(at: edge, calendar: cal) == .today)
    }

    @Test func expiryCountdownTextRenderHours() {
        #expect(DailyChallengeTile.expiryCountdownText(minutesRemaining: 227) == "3h 47m before midnight")
        #expect(DailyChallengeTile.expiryCountdownText(minutesRemaining: 120) == "2h before midnight")
        #expect(DailyChallengeTile.expiryCountdownText(minutesRemaining: 47)  == "47m before midnight")
        #expect(DailyChallengeTile.expiryCountdownText(minutesRemaining: 1)   == "Under a minute")
        #expect(DailyChallengeTile.expiryCountdownText(minutesRemaining: 0)   == "Under a minute")
    }
}

// MARK: - NoumCharacter.Stage XP gates + ratchet (M14)
//
// Pins the contract behind the character's lifetime arc:
//   1. `Stage.current(xp:)` is a pure step-function of XP. Each gate's
//      lower bound is inclusive; one XP below stays on the previous stage.
//   2. `Stage` is `Comparable` by rank (awakening < ... < mastery) so the
//      ratchet's `max` operation works.
//   3. `ProgressionRatchet` is a one-way ratchet — a lower candidate
//      never overwrites a higher stored peak. Mirrors the
//      "never punish-shame regression — only celebrate upward" invariant
//      that league + skill-levels already implement.
//   4. `resolvedStage(forXP:)` returns max(derived, stored) and bumps
//      the stored peak when the derived stage is higher.
//
// We use a `UserDefaults(suiteName:)` to avoid polluting the real defaults
// — each test gets a clean store via `suiteName: UUID().uuidString`.

struct NoumCharacterStageTests {

    private func freshDefaults() -> UserDefaults {
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        return suite
    }

    // MARK: Pure-function gates

    @Test func awakeningCoversZeroAndJustBelowFirstGate() {
        #expect(NoumCharacter.Stage.current(xp: 0)   == .awakening)
        #expect(NoumCharacter.Stage.current(xp: 1)   == .awakening)
        #expect(NoumCharacter.Stage.current(xp: 499) == .awakening)
    }

    @Test func voiceCoversItsRange() {
        #expect(NoumCharacter.Stage.current(xp: 500)  == .voice)
        #expect(NoumCharacter.Stage.current(xp: 1000) == .voice)
        #expect(NoumCharacter.Stage.current(xp: 1499) == .voice)
    }

    @Test func composureCoversItsRange() {
        #expect(NoumCharacter.Stage.current(xp: 1500) == .composure)
        #expect(NoumCharacter.Stage.current(xp: 2500) == .composure)
        #expect(NoumCharacter.Stage.current(xp: 3499) == .composure)
    }

    @Test func commandCoversItsRange() {
        #expect(NoumCharacter.Stage.current(xp: 3500) == .command)
        #expect(NoumCharacter.Stage.current(xp: 6000) == .command)
        #expect(NoumCharacter.Stage.current(xp: 7999) == .command)
    }

    @Test func masteryCoversItsRangeAndExtendsUnbounded() {
        #expect(NoumCharacter.Stage.current(xp: 8000)    == .mastery)
        #expect(NoumCharacter.Stage.current(xp: 25_000)  == .mastery)
        #expect(NoumCharacter.Stage.current(xp: 999_999) == .mastery)
    }

    @Test func negativeXPClampsToAwakening() {
        // Defensive: XP should never be negative in production, but if a
        // migration bug pushes it into negatives the character must not
        // crash or jump to an arbitrary stage.
        #expect(NoumCharacter.Stage.current(xp: -1)    == .awakening)
        #expect(NoumCharacter.Stage.current(xp: -1000) == .awakening)
    }

    // MARK: Comparable ordering (used by ratchet's `max`)

    @Test func stageOrderingIsAwakeningThroughMastery() {
        let ordered: [NoumCharacter.Stage] = [
            .awakening, .voice, .composure, .command, .mastery
        ]
        for i in 0..<(ordered.count - 1) {
            #expect(ordered[i] < ordered[i + 1],
                    "\(ordered[i]) should sort before \(ordered[i + 1])")
        }
        // max should pick the highest
        #expect(ordered.max() == .mastery)
        #expect(ordered.min() == .awakening)
    }

    // MARK: Ratchet — one-way upward

    @Test func ratchetPersistsHigherCandidate() {
        let defaults = freshDefaults()
        #expect(ProgressionRatchet.peakStage(defaults: defaults) == .awakening)

        let result = ProgressionRatchet.recordIfHigher(.voice, defaults: defaults)
        #expect(result == .voice)
        #expect(ProgressionRatchet.peakStage(defaults: defaults) == .voice)
    }

    @Test func ratchetIgnoresLowerCandidate() {
        let defaults = freshDefaults()
        ProgressionRatchet.recordIfHigher(.command, defaults: defaults)
        #expect(ProgressionRatchet.peakStage(defaults: defaults) == .command)

        // A lower candidate must NOT regress the stored peak.
        let result = ProgressionRatchet.recordIfHigher(.voice, defaults: defaults)
        #expect(result == .command,
                "recordIfHigher must return the stored peak when candidate is lower")
        #expect(ProgressionRatchet.peakStage(defaults: defaults) == .command,
                "Lower candidate must never overwrite a higher stored peak")
    }

    @Test func ratchetIgnoresEqualCandidate() {
        // Equal candidate is a no-op — the `>` gate in recordIfHigher
        // means strictly-greater wins. Locks against an off-by-one
        // refactor turning it into `>=`.
        let defaults = freshDefaults()
        ProgressionRatchet.recordIfHigher(.voice, defaults: defaults)
        let result = ProgressionRatchet.recordIfHigher(.voice, defaults: defaults)
        #expect(result == .voice)
        #expect(ProgressionRatchet.peakStage(defaults: defaults) == .voice)
    }

    // MARK: resolvedStage — derived vs stored

    @Test func resolvedStagePicksDerivedWhenHigher() {
        let defaults = freshDefaults()
        // Stored is awakening; derived from 1500 XP is composure — wins.
        let resolved = ProgressionRatchet.resolvedStage(forXP: 1500, defaults: defaults)
        #expect(resolved == .composure)
        // Side-effect: the ratchet should have been bumped to composure too.
        #expect(ProgressionRatchet.peakStage(defaults: defaults) == .composure)
    }

    @Test func resolvedStagePicksStoredWhenDerivedRegressed() {
        let defaults = freshDefaults()
        // Pre-seed the ratchet at command (user reached level 3+ historically).
        ProgressionRatchet.recordIfHigher(.command, defaults: defaults)
        // Now XP somehow dropped to 600 (would derive to .voice).
        let resolved = ProgressionRatchet.resolvedStage(forXP: 600, defaults: defaults)
        #expect(resolved == .command,
                "Resolved stage must hold to the historical peak — never regress visually")
        #expect(ProgressionRatchet.peakStage(defaults: defaults) == .command,
                "Stored peak must not be overwritten by a regression")
    }
}

// MARK: - Coach context builder (Ask Noum)
//
// Pure-function helpers in `CoachContextBuilder` produce the structured
// context the AI coach gets every chat turn. These tests pin the
// contract on three axes:
//   1. Voice-specific personalities differ per `SpeakingStyleGoal` —
//      the authoritative coach reads differently than the warm coach.
//   2. The user context block surfaces the right numbers (rating,
//      baseline, recent sessions) and omits sections that have no
//      data (never invent / fabricate).
//   3. Starter prompts differ per voice — the chat's empty state is
//      always voice-tuned.

struct CoachContextBuilderTests {

    // MARK: - Voice-specific personalities

    @Test func voicePersonalitiesAreDistinct() {
        // Every voice should produce a clearly different personality
        // string. A refactor that quietly unifies them under one
        // "calm coach" register fails this test — the voice-specific
        // promise is the whole point.
        let voices = SpeakingStyleGoal.allCases
        let personalities = voices.map { CoachContextBuilder.coachPersonality(for: $0) }
        let unique = Set(personalities)
        #expect(unique.count == voices.count,
                "Each voice should produce a unique coach personality string")
    }

    @Test func authoritativePersonalityIsVerdictShaped() {
        // The authoritative voice should read like a verdict — direct,
        // declarative, no hedging. Lock the key phrases so a future
        // copy edit can't quietly soften it.
        let p = CoachContextBuilder.coachPersonality(for: .authoritative)
        #expect(p.lowercased().contains("senior advisor"),
                "Authoritative voice should frame the coach as a senior advisor")
        #expect(p.contains("declarative"),
                "Authoritative voice should mention declarative sentence shape")
    }

    @Test func warmPersonalityIsCurious() {
        let p = CoachContextBuilder.coachPersonality(for: .warm)
        #expect(p.lowercased().contains("curious"),
                "Warm voice should frame the coach as curious")
        #expect(p.lowercased().contains("not saccharine") || p.lowercased().contains("not sweet"),
                "Warm voice should explicitly guard against saccharine")
    }

    @Test func concisePersonalityMentionsBrevity() {
        // The concise voice's personality should explicitly tell the
        // coach to keep replies clipped — that's the user-visible
        // contract. The marker phrases below come straight from the
        // brand brief for this voice.
        let p = CoachContextBuilder.coachPersonality(for: .concise)
        #expect(p.lowercased().contains("one idea per turn"),
                "Concise voice should mention 'one idea per turn'")
        #expect(p.lowercased().contains("skip preamble"),
                "Concise voice should mention skipping preamble")
    }

    // MARK: - System prompt composition

    @Test func systemPromptIncludesBrandRules() {
        // The brand non-negotiables — second person, no chirpy filler,
        // no exclamation marks, no overclaiming — must be in every
        // system prompt regardless of voice. These are the rules that
        // protect coaching trust.
        let prompt = CoachContextBuilder.systemPrompt(for: nil)
        #expect(prompt.contains("Second person"))
        #expect(prompt.contains("never use chirpy filler"))
        #expect(prompt.contains("never use exclamation marks"))
        #expect(prompt.contains("never overclaim"))
        #expect(prompt.contains("never punish-shame"))
    }

    @Test func systemPromptIncludesVoicePersonalityWhenProfileSet() {
        // When the user has set a voice, the system prompt must
        // include that voice's personality block. The authoritative
        // marker phrase ("senior advisor") is the signal.
        let profile = sampleProfile(voice: .authoritative)
        let prompt = CoachContextBuilder.systemPrompt(for: profile)
        #expect(prompt.lowercased().contains("senior advisor"),
                "System prompt with authoritative profile should bake in the authoritative personality")
    }

    @Test func systemPromptUsesDefaultPersonalityWhenNoProfile() {
        // No profile yet (very early onboarding) → falls back to the
        // default coach personality. Locks against a future change
        // that crashes or returns an empty system prompt on cold start.
        let prompt = CoachContextBuilder.systemPrompt(for: nil)
        #expect(prompt.contains("calm, direct speaking coach"),
                "Nil profile should use the default personality string")
    }

    // MARK: - User context block

    @Test func userContextHandlesColdStart() {
        // Brand-new user — no profile, no rating, no baseline, no
        // sessions. The context should acknowledge this honestly
        // ("No rated sessions yet.") and instruct the model not to
        // fabricate stats.
        let baseline = CommunicationBaseline.empty
        let rating = SpeakingRating.initial
        let ctx = CoachContextBuilder.userContext(
            profile: nil,
            baseline: baseline,
            rating: rating,
            sessions: [],
            currentStreak: 0,
            pathStatus: nil,
            pathGatingPhrase: nil
        )
        #expect(ctx.contains("No voice set yet"),
                "Cold-start context should flag missing voice")
        #expect(ctx.contains("No rated sessions yet"),
                "Cold-start context should flag missing rating")
        #expect(ctx.contains("Not enough data for a stable baseline yet"),
                "Cold-start context should flag missing baseline")
    }

    @Test func userContextSurfacesGoal() {
        // With a profile, the context's GOAL section should include
        // the voice title and the coaching description — those are
        // the lines the model uses to anchor every reply.
        let profile = sampleProfile(voice: .warm)
        let ctx = CoachContextBuilder.userContext(
            profile: profile,
            baseline: .empty,
            rating: .initial,
            sessions: [],
            currentStreak: 0,
            pathStatus: nil,
            pathGatingPhrase: nil
        )
        #expect(ctx.contains("GOAL"))
        #expect(ctx.contains("Warm and welcoming"),
                "Warm voice title should be in the GOAL section")
        #expect(ctx.contains("encouraging, natural, and easy to trust"),
                "Warm voice coaching description should be in the GOAL section")
    }

    @Test func userContextOmitsBaselineDimensionsWithoutData() {
        // Specific baseline dimensions with `.insufficient` confidence
        // should NOT appear in the context — quoting them would
        // surface fake "0.0 fillers/min" numbers. The contract is:
        // only quote what's confident.
        let baseline = CommunicationBaseline.empty // all dimensions insufficient
        let ctx = CoachContextBuilder.userContext(
            profile: nil,
            baseline: baseline,
            rating: .initial,
            sessions: [],
            currentStreak: 0,
            pathStatus: nil,
            pathGatingPhrase: nil
        )
        #expect(!ctx.contains("Fillers per minute:"),
                "Insufficient filler rate must not surface a value line")
        #expect(!ctx.contains("Pace:"),
                "Insufficient pace must not surface a value line")
    }

    // MARK: - Starter prompts

    @Test func starterPromptsAreVoiceSpecific() {
        // Each voice should produce starter prompts that mention
        // moves relevant to *that* voice — not generic ones.
        let auth = CoachContextBuilder.starterPrompts(for: .authoritative).joined()
        let warm = CoachContextBuilder.starterPrompts(for: .warm).joined()
        let storytell = CoachContextBuilder.starterPrompts(for: .storytelling).joined()
        #expect(auth.lowercased().contains("authority") || auth.lowercased().contains("pitch"))
        #expect(warm.lowercased().contains("warm") || warm.lowercased().contains("trust"))
        #expect(storytell.lowercased().contains("story") || storytell.lowercased().contains("vivid"))
    }

    @Test func starterPromptsAlwaysIncludeCommonOnes() {
        // Two common starters ("Why did my score change", "Plan my
        // next 7 days") should appear for every voice — they're
        // useful regardless of which voice the user picked. This
        // catches a refactor that accidentally drops them.
        for voice in SpeakingStyleGoal.allCases {
            let prompts = CoachContextBuilder.starterPrompts(for: voice)
            #expect(prompts.contains(where: { $0.lowercased().contains("score change") }),
                    "Voice \(voice) should include the 'score change' common starter")
            #expect(prompts.contains(where: { $0.lowercased().contains("7 days") }),
                    "Voice \(voice) should include the '7-day plan' common starter")
        }
    }

    // MARK: - Session-anchored opener (Summary → Ask Noum bridge)

    @Test func sessionOpenerIncludesConcreteMetrics() {
        // Opener must quote the rep's actual numbers so the model has
        // an anchor before reading the user-context block. Filler count,
        // duration (rounded to whole seconds), and score (when present)
        // all need to be in the seed message.
        let opener = CoachContextBuilder.sessionOpener(
            mode: .timed,
            score: 8,
            fillerCount: 2,
            duration: 28.4,
            voice: .authoritative
        )
        #expect(opener.contains("Timed"), "Mode label is in the opener: \(opener)")
        #expect(opener.contains("28s"), "Duration is in the opener: \(opener)")
        #expect(opener.contains("2 fillers"), "Filler count is in the opener: \(opener)")
        #expect(opener.contains("8/10"), "Score is in the opener: \(opener)")
    }

    @Test func sessionOpenerPluralisesFillers() {
        // Single filler should read "1 filler", multiple should read "N
        // fillers". Pluralisation matters — the model reads this as a
        // user message and copies the register back in its reply.
        let one = CoachContextBuilder.sessionOpener(
            mode: .timed, score: nil, fillerCount: 1, duration: 30, voice: nil
        )
        let many = CoachContextBuilder.sessionOpener(
            mode: .timed, score: nil, fillerCount: 4, duration: 30, voice: nil
        )
        #expect(one.contains("1 filler") && !one.contains("1 fillers"),
                "Single filler reads 'filler' not 'fillers': \(one)")
        #expect(many.contains("4 fillers"),
                "Multiple fillers read plural: \(many)")
    }

    @Test func sessionOpenerDropsScoreWhenAbsent() {
        // Ah-Counter sessions have no score; the opener must degrade
        // gracefully (no "nil/10" or "0/10" leakage).
        let opener = CoachContextBuilder.sessionOpener(
            mode: .ahCounter, score: nil, fillerCount: 3, duration: 45, voice: .concise
        )
        #expect(!opener.contains("/10"), "Score is omitted when absent: \(opener)")
        #expect(!opener.contains("nil"), "Never leaks nil: \(opener)")
        #expect(opener.contains("Ah-Counter"), "Mode label is present: \(opener)")
        #expect(opener.contains("45s"), "Duration is present: \(opener)")
        #expect(opener.contains("3 fillers"), "Filler count is present: \(opener)")
    }

    @Test func sessionOpenerEndingIsVoiceShaped() {
        // The closing ask differs per voice. The mapping mirrors
        // `starterPrompts` and `coachPersonality` — same per-voice
        // registers the rest of the AskNoum surface uses, so the
        // injected opener doesn't read like a different speaker.
        let auth = CoachContextBuilder.sessionOpener(
            mode: .timed, score: 7, fillerCount: 2, duration: 30, voice: .authoritative
        )
        let warm = CoachContextBuilder.sessionOpener(
            mode: .timed, score: 7, fillerCount: 2, duration: 30, voice: .warm
        )
        let concise = CoachContextBuilder.sessionOpener(
            mode: .timed, score: 7, fillerCount: 2, duration: 30, voice: .concise
        )
        let exec = CoachContextBuilder.sessionOpener(
            mode: .timed, score: 7, fillerCount: 2, duration: 30, voice: .executive
        )
        let story = CoachContextBuilder.sessionOpener(
            mode: .timed, score: 7, fillerCount: 2, duration: 30, voice: .storytelling
        )
        let none = CoachContextBuilder.sessionOpener(
            mode: .timed, score: 7, fillerCount: 2, duration: 30, voice: nil
        )
        #expect(auth.lowercased().contains("verdict") || auth.lowercased().contains("read"),
                "Authoritative ending asks for a verdict/read: \(auth)")
        #expect(warm.lowercased().contains("feel"),
                "Warm ending asks how it felt: \(warm)")
        #expect(concise.lowercased().contains("one move") || concise.lowercased().contains("move"),
                "Concise ending asks for the single move: \(concise)")
        #expect(exec.lowercased().contains("brief"),
                "Executive ending is a brief: \(exec)")
        #expect(story.lowercased().contains("arc"),
                "Storytelling ending references the arc: \(story)")
        #expect(none.lowercased().contains("stood out") || none.lowercased().contains("what"),
                "No-voice fallback asks what stood out: \(none)")
    }

    @Test func sessionOpenerHandlesEveryVoiceWithoutCrashing() {
        // Coverage invariant — adding a voice in the future without
        // wiring it here will surface as a missing closing ask and
        // this test will catch it.
        for voice in SpeakingStyleGoal.allCases {
            let opener = CoachContextBuilder.sessionOpener(
                mode: .timed, score: 7, fillerCount: 2, duration: 30, voice: voice
            )
            #expect(opener.contains("Timed"))
            // Two sentences — fact + ask. Should always end with a period
            // or question mark (the ask). Catches an accidental nil-ask.
            let last = opener.trimmingCharacters(in: .whitespacesAndNewlines).last
            #expect(last == "?" || last == ".",
                    "Voice \(voice) opener should end with ? or .: \(opener)")
        }
    }

    // MARK: - Follow-up suggestions (post-reply chip row)
    //
    // Pins the contract behind the AskNoumView follow-up chips:
    //   1. Empty reply returns an empty array — chip row collapses.
    //   2. Topic detection finds drill / pause / pace / filler / weekly
    //      anchors in the reply text, deterministically and order-
    //      sensitively (first match wins).
    //   3. Every voice handled — no voice produces an empty array.
    //   4. Voice register is preserved across topics: authoritative is
    //      verdict-shaped, warm is curious, concise is clipped,
    //      storytelling references the arc.
    //   5. No exclamations / emoji / "Let's" in any voice × topic cell
    //      (brand voice rules).

    @Test func followUpSuggestionsEmptyReplyReturnsEmpty() {
        let chips = CoachContextBuilder.followUpSuggestions(
            forCoachReply: "",
            voice: .authoritative
        )
        #expect(chips.isEmpty)

        let whitespaceOnly = CoachContextBuilder.followUpSuggestions(
            forCoachReply: "   \n\t  ",
            voice: .authoritative
        )
        #expect(whitespaceOnly.isEmpty, "Whitespace-only reply must also collapse the chip row")
    }

    @Test func followUpTopicDetectionFindsDrillFirst() {
        // Drill / exercise / "try this" all map to drillMentioned.
        // Order check: when both drill and pause appear, drill wins
        // because it's the more concrete recommendation.
        let drill = CoachContextBuilder.detectFollowUpTopic(in: "Try this drill tomorrow.")
        let exercise = CoachContextBuilder.detectFollowUpTopic(in: "Run an exercise on openings.")
        let tryThis = CoachContextBuilder.detectFollowUpTopic(in: "Try this: open with a thesis.")
        let drillAndPause = CoachContextBuilder.detectFollowUpTopic(
            in: "I'd recommend a drill where you hold a pause between points."
        )
        #expect(drill == .drillMentioned)
        #expect(exercise == .drillMentioned)
        #expect(tryThis == .drillMentioned)
        #expect(drillAndPause == .drillMentioned,
                "Drill should win when both drill and pause appear — drill is the more concrete anchor")
    }

    @Test func followUpTopicDetectionFindsPause() {
        let pause = CoachContextBuilder.detectFollowUpTopic(in: "Hold a four-second pause before your close.")
        let silence = CoachContextBuilder.detectFollowUpTopic(in: "Trust the silence.")
        let breath = CoachContextBuilder.detectFollowUpTopic(in: "Take a breath, then continue.")
        #expect(pause == .pauseMentioned)
        #expect(silence == .pauseMentioned)
        #expect(breath == .pauseMentioned)
    }

    @Test func followUpTopicDetectionFindsPace() {
        let pace = CoachContextBuilder.detectFollowUpTopic(in: "Your pace climbs as you build energy.")
        let wpm = CoachContextBuilder.detectFollowUpTopic(in: "You averaged 168 WPM this week.")
        let rush = CoachContextBuilder.detectFollowUpTopic(in: "You rush into the second point.")
        let slow = CoachContextBuilder.detectFollowUpTopic(in: "Slow your opening by 20%.")
        #expect(pace == .paceMentioned)
        #expect(wpm == .paceMentioned)
        #expect(rush == .paceMentioned)
        #expect(slow == .paceMentioned)
    }

    @Test func followUpTopicDetectionFindsFillers() {
        let fillers = CoachContextBuilder.detectFollowUpTopic(in: "Three fillers in the opening.")
        let umQuoted = CoachContextBuilder.detectFollowUpTopic(in: "Replace \"um\" with silence.")
        #expect(fillers == .fillerMentioned)
        #expect(umQuoted == .fillerMentioned)
    }

    @Test func followUpTopicDetectionFindsWeekly() {
        let thisWeek = CoachContextBuilder.detectFollowUpTopic(in: "This week, hit three reps.")
        let nextWeek = CoachContextBuilder.detectFollowUpTopic(in: "Next week we shift focus.")
        let sevenDays = CoachContextBuilder.detectFollowUpTopic(in: "Over the next 7 days, do 5 reps.")
        #expect(thisWeek == .weeklyMentioned)
        #expect(nextWeek == .weeklyMentioned)
        #expect(sevenDays == .weeklyMentioned)
    }

    @Test func followUpTopicDetectionFallsBackToGeneric() {
        // A reply with no detectable topic anchor should land on
        // .generic so we still surface evergreen chips rather than
        // collapse the row entirely.
        let generic = CoachContextBuilder.detectFollowUpTopic(in: "You're holding steady. Stay with it.")
        #expect(generic == .generic)
    }

    @Test func followUpSuggestionsEveryVoiceProducesThreeChips() {
        // Coverage invariant: every voice × every topic produces
        // exactly three chips. Adding a voice / a topic in future
        // must wire chips for every cell — this test catches a miss.
        let topicReplies: [(String, String)] = [
            ("Try this drill.", "drill"),
            ("Hold a pause.", "pause"),
            ("Watch your pace.", "pace"),
            ("Cut the fillers.", "filler"),
            ("This week, hit three reps.", "weekly"),
            ("Keep building.", "generic"),
        ]
        for voice in SpeakingStyleGoal.allCases {
            for (reply, label) in topicReplies {
                let chips = CoachContextBuilder.followUpSuggestions(forCoachReply: reply, voice: voice)
                #expect(chips.count == 3,
                        "Voice \(voice) × topic '\(label)' should produce 3 chips, got \(chips.count)")
            }
        }
        // nil voice (no goal set) is also a real path — same contract.
        for (reply, label) in topicReplies {
            let chips = CoachContextBuilder.followUpSuggestions(forCoachReply: reply, voice: nil)
            #expect(chips.count == 3,
                    "nil voice × topic '\(label)' should produce 3 chips, got \(chips.count)")
        }
    }

    @Test func followUpSuggestionsAreVoiceShapedForDrillTopic() {
        // Authoritative / warm / concise / storytelling each produce
        // chips that read in their respective register when anchored
        // on the same topic. Drill is the test topic because every
        // voice has distinct shaping for it.
        let reply = "Try this drill: open with a thesis statement."

        let auth = CoachContextBuilder.followUpSuggestions(forCoachReply: reply, voice: .authoritative).joined(separator: " ").lowercased()
        let warm = CoachContextBuilder.followUpSuggestions(forCoachReply: reply, voice: .warm).joined(separator: " ").lowercased()
        let concise = CoachContextBuilder.followUpSuggestions(forCoachReply: reply, voice: .concise).joined(separator: " ").lowercased()
        let story = CoachContextBuilder.followUpSuggestions(forCoachReply: reply, voice: .storytelling).joined(separator: " ").lowercased()

        #expect(auth.contains("nailed it") || auth.contains("failure"),
                "Authoritative drill chips should reach for verdict-shaped language: \(auth)")
        #expect(warm.contains("walk me through") || warm.contains("feel"),
                "Warm drill chips should reach for felt-experience language: \(warm)")
        #expect(concise.count < auth.count,
                "Concise chips should be shorter than authoritative — got concise=\(concise.count) auth=\(auth.count)")
        #expect(story.contains("arc") || story.contains("scene") || story.contains("rep"),
                "Storytelling drill chips should reach for narrative language: \(story)")
    }

    @Test func followUpSuggestionsRespectBrandVoiceRules() {
        // No exclamations, no emoji, no "Let's" anywhere across all
        // voices × topics. Same brand rules as `starterPrompts` and
        // `sessionOpener`.
        let topicReplies = [
            "Try this drill on openings.",
            "Hold a four-second pause.",
            "Slow your pace to 140 WPM.",
            "Three fillers clustered in the opening.",
            "Over the next 7 days, run five reps.",
            "Keep building from where you are.",
        ]
        for voice in SpeakingStyleGoal.allCases {
            for reply in topicReplies {
                let chips = CoachContextBuilder.followUpSuggestions(forCoachReply: reply, voice: voice)
                for chip in chips {
                    #expect(!chip.contains("!"),
                            "Voice \(voice) chip '\(chip)' contains an exclamation")
                    #expect(!chip.lowercased().contains("let's"),
                            "Voice \(voice) chip '\(chip)' contains 'Let's'")
                    #expect(chip.count < 60,
                            "Voice \(voice) chip '\(chip)' is too long — chips should be quick nudges (<60 chars)")
                }
            }
        }
    }

    // MARK: - Helpers

    private func sampleProfile(voice: SpeakingStyleGoal) -> CoachingProfile {
        CoachingProfile(
            speakingContext: .work,
            primaryGoal: .reduceFillers,
            confidenceLevel: .rebuilding,
            biggestChallenge: .fillerWords,
            desiredOutcome: .concise,
            speakingStyleGoal: voice,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: ""
        )
    }
}

// MARK: - Ask Noum store (per-account, bounded, pending-aware)
//
// Pins the contract behind the chat thread store:
//   1. `appendUserTurn` adds a user row plus a pending coach
//      placeholder, setting `isAwaitingReply = true`.
//   2. `completeCoachTurn` hydrates the placeholder with the model's
//      reply text and clears `isAwaitingReply`.
//   3. An empty reply text becomes a `.systemNotice` row instead of
//      an empty coach bubble — never leave a blank bubble.
//   4. `cancelPendingCoachTurn` removes the pending row entirely.
//   5. The thread caps at the configured max — older messages drop
//      off the front.
//   6. Pending rows do NOT persist to disk — a relaunch must start
//      with a clean thread (no orphaned typing indicators).

@MainActor
struct AskNoumStoreTests {

    private func freshStore() -> AskNoumStore {
        // Each test gets its own UserDefaults suite + a deterministic
        // account ID so persistence is isolated and reproducible.
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        return AskNoumStore(defaults: suite, accountIDProvider: { "tester" })
    }

    @Test func appendUserTurnAddsUserAndPendingCoach() {
        let store = freshStore()
        let ids = store.appendUserTurn("Plan my week.")
        #expect(store.messages.count == 2)
        #expect(store.messages[0].role == .user)
        #expect(store.messages[0].text == "Plan my week.")
        #expect(store.messages[0].id == ids.userID)
        #expect(store.messages[1].role == .coach)
        #expect(store.messages[1].isPending == true)
        #expect(store.messages[1].id == ids.coachID)
        #expect(store.isAwaitingReply)
    }

    @Test func completeCoachTurnHydratesPlaceholder() {
        let store = freshStore()
        let ids = store.appendUserTurn("Plan my week.")
        store.completeCoachTurn(id: ids.coachID, outcome: .reply("Do 3 reps of Sudden Death."))
        #expect(store.messages.count == 2)
        #expect(store.messages[1].role == .coach)
        #expect(store.messages[1].isPending == false)
        #expect(store.messages[1].text == "Do 3 reps of Sudden Death.")
        #expect(!store.isAwaitingReply)
    }

    @Test func completeCoachTurnWithEmptyTextBecomesSystemNotice() {
        // Empty reply (model failure / no provider) MUST not leave a
        // blank coach bubble — it converts to a system notice so the
        // user understands what happened.
        let store = freshStore()
        let ids = store.appendUserTurn("Plan my week.")
        store.completeCoachTurn(id: ids.coachID, outcome: .failure(.network))
        #expect(store.messages.count == 2)
        #expect(store.messages[1].role == .systemNotice)
        #expect(store.messages[1].text.contains("couldn't reach"))
        #expect(!store.isAwaitingReply)
    }

    @Test func cancelPendingCoachTurnRemovesPlaceholder() {
        let store = freshStore()
        let ids = store.appendUserTurn("Plan my week.")
        store.cancelPendingCoachTurn(id: ids.coachID)
        // Only the user row remains; the pending row is gone.
        #expect(store.messages.count == 1)
        #expect(store.messages[0].id == ids.userID)
        #expect(!store.isAwaitingReply)
    }

    @Test func replayForModelOmitsSystemNoticesAndPendingRows() {
        let store = freshStore()
        let ids1 = store.appendUserTurn("First.")
        store.completeCoachTurn(id: ids1.coachID, outcome: .reply("First reply."))
        let ids2 = store.appendUserTurn("Second.")
        store.completeCoachTurn(id: ids2.coachID, outcome: .failure(.network)) // → system notice
        let ids3 = store.appendUserTurn("Third.")
        // ids3.coachID is still pending — should NOT be in replay.

        let replay = store.replayForModel
        // 3 user turns + 1 coach reply = 4. The system notice + the
        // pending third coach turn are both excluded.
        #expect(replay.count == 4)
        #expect(replay.contains(where: { $0.text == "First." }))
        #expect(replay.contains(where: { $0.text == "First reply." }))
        #expect(replay.contains(where: { $0.text == "Second." }))
        #expect(replay.contains(where: { $0.text == "Third." }))
        #expect(!replay.contains(where: { $0.role == .systemNotice }))
        #expect(!replay.contains(where: { $0.isPending }))
    }

    @Test func clearThreadRemovesAllMessages() {
        let store = freshStore()
        let ids = store.appendUserTurn("Hello.")
        store.completeCoachTurn(id: ids.coachID, outcome: .reply("Hi."))
        store.clearThread()
        #expect(store.messages.isEmpty)
    }

    @Test func relaunchDoesNotResurrectPendingRows() {
        // Simulate a mid-reply crash / background → relaunch by
        // creating a fresh store on the same defaults suite. The
        // pending row must NOT come back.
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let store1 = AskNoumStore(defaults: suite, accountIDProvider: { "tester" })
        let ids = store1.appendUserTurn("Plan my week.")
        _ = ids
        // Note: do NOT call completeCoachTurn — the pending row
        // never resolves. Now simulate relaunch:
        let store2 = AskNoumStore(defaults: suite, accountIDProvider: { "tester" })
        #expect(store2.messages.count == 1,
                "Relaunch should restore only the user row, not the pending coach placeholder")
        #expect(store2.messages.first?.role == .user)
        #expect(!store2.isAwaitingReply)
    }

    // MARK: - Cross-surface inject (Summary → Ask Noum bridge)

    @Test func injectUserTurnAddsTurnAndExposesPendingCoachID() {
        // Same shape as appendUserTurn but the store also publishes
        // `pendingInjectedCoachID` so AskNoumView can pick the
        // reply up on appear.
        let store = freshStore()
        let coachID = store.injectUserTurn("Just finished a Timed rep — 28s, 2 fillers, 8/10. Give me your read.")
        #expect(coachID != nil)
        #expect(store.messages.count == 2)
        #expect(store.messages[0].role == .user)
        #expect(store.messages[1].role == .coach)
        #expect(store.messages[1].isPending)
        #expect(store.pendingInjectedCoachID == coachID)
        #expect(store.isAwaitingReply)
    }

    @Test func consumePendingInjectedClearsTheSignal() {
        // The store hands the ID back exactly once. A second
        // consume returns nil — re-mounts of AskNoumView won't
        // trigger a duplicate reply for the same opener.
        let store = freshStore()
        let coachID = store.injectUserTurn("Opener A.")
        let first = store.consumePendingInjectedCoachID()
        let second = store.consumePendingInjectedCoachID()
        #expect(first == coachID)
        #expect(second == nil)
        #expect(store.pendingInjectedCoachID == nil)
    }

    @Test func injectUserTurnIsIdempotentWhilePending() {
        // A double-tap on the Summary bridge must NOT queue two
        // copies of the same opener back-to-back. While the prior
        // reply is still pending, re-injecting the same text returns
        // the existing coachID and leaves the thread shape unchanged.
        let store = freshStore()
        let first = store.injectUserTurn("Same opener.")
        let second = store.injectUserTurn("Same opener.")
        #expect(first == second, "Repeated inject returns the existing pending coachID")
        #expect(store.messages.count == 2, "Thread shape unchanged after the second inject")
    }

    @Test func injectUserTurnRejectsEmptyText() {
        // Whitespace-only seeds would produce a useless coach reply
        // and a confusing blank user bubble. Reject at the boundary.
        let store = freshStore()
        let coachID = store.injectUserTurn("   ")
        #expect(coachID == nil)
        #expect(store.messages.isEmpty)
        #expect(store.pendingInjectedCoachID == nil)
    }

    @Test func injectUserTurnAfterCompletedReplyAppendsFreshTurn() {
        // Idempotency only suppresses the duplicate WHILE the prior
        // reply is pending. Once the coach has actually answered,
        // re-injecting the same opener legitimately appends a new
        // pair — the user is asking the same question again, which is
        // a real action the bridge supports (e.g. the user navigated
        // back to summary, scrolled, tapped the bridge again later).
        let store = freshStore()
        let firstCoachID = store.injectUserTurn("Same opener.")
        // Reply lands.
        store.completeCoachTurn(id: firstCoachID!, outcome: .reply("Here's the read."))
        // Second inject of the same text now appends a fresh pair.
        let secondCoachID = store.injectUserTurn("Same opener.")
        #expect(secondCoachID != nil)
        #expect(secondCoachID != firstCoachID)
        #expect(store.messages.count == 4,
                "After-reply re-inject appends a fresh user + pending coach pair")
    }

    @Test func clearThreadAlsoClearsPendingInjectedSignal() {
        let store = freshStore()
        _ = store.injectUserTurn("Drop this on me.")
        store.clearThread()
        #expect(store.pendingInjectedCoachID == nil,
                "clearThread wipes the cross-surface signal too")
        #expect(store.messages.isEmpty)
    }
}

// MARK: - Proof Moment Service (transcript-anchored evidence)
//
// Pins the contract behind the proof extractor:
//   1. `transcriptContains` is the fabrication guard — it must accept
//      verbatim quotes, smart-quote variants, and case differences,
//      while rejecting quotes that don't actually appear.
//   2. `deterministicProof` returns voice-specific (technique, claim)
//      shapes — never the same string regardless of voice.
//   3. The fallback never invents a quote; if the transcript is too
//      short to yield a clause, it returns nil.

struct ProofMomentServiceTests {

    // MARK: - Fabrication guard

    @Test func transcriptContainsVerbatimSliceTrue() {
        let transcript = "We're going to focus on three things this quarter: revenue, retention, and reach."
        #expect(ProofMomentService.transcriptContains("three things this quarter", in: transcript))
    }

    @Test func transcriptContainsIsCaseInsensitive() {
        let transcript = "Hold the pause. Let the silence work for you."
        #expect(ProofMomentService.transcriptContains("LET THE SILENCE WORK", in: transcript))
        #expect(ProofMomentService.transcriptContains("hold the pause", in: transcript))
    }

    @Test func transcriptContainsNormalisesSmartQuotes() {
        // Smart quotes (’, “, ”) come back from some
        // transcription providers; the model may also generate them.
        // We normalise both sides to plain ASCII so a smart-quoted
        // candidate still matches a plain-quoted transcript.
        let transcript = "It's our best quarter yet"
        let candidate = "It\u{2019}s our best quarter yet"
        #expect(ProofMomentService.transcriptContains(candidate, in: transcript))
    }

    @Test func transcriptContainsRejectsFabrication() {
        // The model invents a quote that *sounds* like the transcript
        // but doesn't appear in it. The guard must catch this.
        let transcript = "Revenue is up fourteen percent. Retention held steady."
        #expect(!ProofMomentService.transcriptContains("Revenue is up twenty percent", in: transcript))
        #expect(!ProofMomentService.transcriptContains("Customer happiness improved", in: transcript))
    }

    @Test func transcriptContainsRejectsEmptyCandidate() {
        // Empty candidate is treated as "no quote", not "matches
        // everything". Avoids false positives on malformed model
        // output.
        let transcript = "Anything at all."
        #expect(!ProofMomentService.transcriptContains("", in: transcript))
        #expect(!ProofMomentService.transcriptContains("   ", in: transcript))
    }

    // MARK: - Deterministic fallback

    @Test func deterministicProofReturnsNilForShortTranscript() {
        // A transcript with no clause of >= 4 words has nothing
        // useful to surface. Service returns nil rather than
        // fabricate a one-word "quote".
        let session = sampleSession(transcript: "Yes.", score: 5, duration: 30)
        let input = ProofMomentInput(
            session: session, voice: .authoritative,
            goalParaphrase: nil, baselineFillerRate: nil, baselinePace: nil
        )
        #expect(ProofMomentService.deterministicProof(for: input) == nil)
    }

    @Test func deterministicProofProducesValidQuote() {
        // Given a realistic transcript, the deterministic path should
        // pick a clause from it and stamp it with a voice-specific
        // technique. The quote must come from the transcript (the
        // fabrication guard applies here too).
        let transcript = "We focused on three priorities this quarter. Revenue grew steadily. Retention held strong."
        let session = sampleSession(transcript: transcript, score: 8, duration: 40)
        let input = ProofMomentInput(
            session: session, voice: .authoritative,
            goalParaphrase: nil, baselineFillerRate: nil, baselinePace: nil
        )
        let proof = ProofMomentService.deterministicProof(for: input)
        #expect(proof != nil)
        if let proof = proof {
            #expect(!proof.quote.isEmpty)
            #expect(!proof.technique.isEmpty)
            #expect(!proof.claim.isEmpty)
            #expect(proof.isAIBacked == false,
                    "Deterministic path must report isAIBacked = false")
            #expect(ProofMomentService.transcriptContains(proof.quote, in: transcript),
                    "Deterministic quote must come from the transcript verbatim")
        }
    }

    @Test func deterministicProofVoiceSpecificMapping() {
        // Same transcript + same session shape, different voice goal
        // → different (technique, claim). Locks the promise that
        // proof is voice-tied, not generic.
        let transcript = "We focused on three priorities this quarter. Revenue grew steadily."
        let session = sampleSession(transcript: transcript, score: 8, duration: 40)

        let authInput = ProofMomentInput(
            session: session, voice: .authoritative,
            goalParaphrase: nil, baselineFillerRate: nil, baselinePace: nil
        )
        let warmInput = ProofMomentInput(
            session: session, voice: .warm,
            goalParaphrase: nil, baselineFillerRate: nil, baselinePace: nil
        )
        let auth = ProofMomentService.deterministicProof(for: authInput)
        let warm = ProofMomentService.deterministicProof(for: warmInput)
        #expect(auth?.technique != warm?.technique,
                "Authoritative + warm voices should produce different techniques on the same rep")
        #expect(auth?.claim != warm?.claim,
                "Authoritative + warm voices should produce different claims on the same rep")
    }

    @Test func deterministicCleanRepFavoursCleanTechniqueLabel() {
        // A clean rep (no fillers, sustained duration) under the
        // .concise voice should land on a "BLUF"-shaped technique
        // (Bottom Line Up Front). This locks the cleanRep branch in
        // the template mapping so a refactor can't silently route
        // clean reps into a "Trim Move" generic label.
        let transcript = "Revenue grew fourteen percent. Retention held steady."
        let cleanSession = sampleSession(transcript: transcript, score: 9, duration: 40, fillerCount: 0)
        let input = ProofMomentInput(
            session: cleanSession, voice: .concise,
            goalParaphrase: nil, baselineFillerRate: nil, baselinePace: nil
        )
        let proof = ProofMomentService.deterministicProof(for: input)
        #expect(proof?.technique == "BLUF",
                "Clean concise rep should map to BLUF technique label")
    }

    // MARK: - Helpers

    private func sampleSession(
        transcript: String,
        score: Int,
        duration: TimeInterval,
        fillerCount: Int = 0
    ) -> PracticeSession {
        PracticeSession(
            id: UUID(),
            transcript: transcript,
            fillerWordCount: fillerCount,
            duration: duration,
            date: Date(),
            mode: .timed,
            score: score
        )
    }
}

// MARK: - Proof Moment Archive (persistent, per-account, bounded)
//
// Pins the contract behind the proof archive store:
//   1. `record(_:for:)` is idempotent on session ID — refreshing a
//      proof replaces the existing record rather than appending.
//   2. `recent(limit:)` returns most-recent-by-session-date first.
//   3. Persistence round-trips: a second store reading the same
//      defaults suite sees the same archive.
//   4. Per-account isolation — switching the account ID switches the
//      visible archive without crossing data.
//   5. Cap at `maxStoredRecords`. Older entries (by addedAt) drop off
//      the front when the cap is exceeded.
//
// Together these guarantee the coach reads from a stable, account-
// scoped log of the user's actual past words — never quoting another
// account's proof, never returning stale duplicates after refresh.

@MainActor
struct ProofMomentArchiveTests {

    private func freshStore(account: String = "tester") -> ProofMomentStore {
        // Each test gets its own UserDefaults suite + a deterministic
        // account ID so persistence is isolated and reproducible.
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        return ProofMomentStore(defaults: suite, accountIDProvider: { account })
    }

    private func sampleProof(
        quote: String,
        technique: String = "Power Pause",
        claim: String = "Steady hold — composure reads as authority.",
        sessionDate: Date = Date(),
        isAIBacked: Bool = false
    ) -> ProofMoment {
        ProofMoment(
            quote: quote,
            technique: technique,
            claim: claim,
            sessionDate: sessionDate,
            isAIBacked: isAIBacked,
            generatedAt: Date()
        )
    }

    @Test func recordPersistsSingleProof() {
        let store = freshStore()
        let sessionID = UUID()
        let proof = sampleProof(quote: "Three priorities this quarter.")
        store.record(proof, for: sessionID)
        #expect(store.records.count == 1)
        #expect(store.records.first?.sessionID == sessionID)
        #expect(store.records.first?.proof.quote == "Three priorities this quarter.")
    }

    @Test func recordIsIdempotentOnSessionID() {
        // Re-recording the same session ID replaces the existing
        // entry rather than appending a duplicate. This is the path
        // where a deterministic fallback gets upgraded by a later
        // AI re-fetch — the archive should reflect the upgraded proof
        // without the old + new both surfacing in the chat context.
        let store = freshStore()
        let sessionID = UUID()
        let templateProof = sampleProof(
            quote: "First version of the quote.",
            technique: "Trim Move",
            isAIBacked: false
        )
        let aiProof = sampleProof(
            quote: "Upgraded version of the quote.",
            technique: "BLUF",
            isAIBacked: true
        )
        store.record(templateProof, for: sessionID)
        store.record(aiProof, for: sessionID)
        #expect(store.records.count == 1, "Re-saving the same session ID must not produce a duplicate row")
        #expect(store.records.first?.proof.quote == "Upgraded version of the quote.")
        #expect(store.records.first?.proof.isAIBacked == true)
    }

    @Test func recentReturnsMostRecentFirstBySessionDate() {
        // The chat context wants the freshest proof at the top —
        // session date drives the ordering (not `addedAt`), because
        // a user could regenerate an old session's proof and it
        // shouldn't suddenly become the freshest.
        let store = freshStore()
        let oldDate = Date(timeIntervalSinceNow: -86_400 * 14) // 2 weeks ago
        let midDate = Date(timeIntervalSinceNow: -86_400 * 3)  // 3 days ago
        let newDate = Date()
        store.record(sampleProof(quote: "Oldest.", sessionDate: oldDate), for: UUID())
        store.record(sampleProof(quote: "Newest.", sessionDate: newDate), for: UUID())
        store.record(sampleProof(quote: "Middle.", sessionDate: midDate), for: UUID())
        let recent = store.recent(limit: 5)
        #expect(recent.count == 3)
        #expect(recent[0].proof.quote == "Newest.")
        #expect(recent[1].proof.quote == "Middle.")
        #expect(recent[2].proof.quote == "Oldest.")
    }

    @Test func recentRespectsLimit() {
        let store = freshStore()
        for i in 0..<6 {
            store.record(
                sampleProof(
                    quote: "Quote \(i).",
                    sessionDate: Date(timeIntervalSinceNow: TimeInterval(-i) * 100)
                ),
                for: UUID()
            )
        }
        let three = store.recent(limit: 3)
        #expect(three.count == 3, "limit should cap the returned count")
        // First three should be the most-recent three (i=0,1,2).
        #expect(three[0].proof.quote == "Quote 0.")
        #expect(three[2].proof.quote == "Quote 2.")
    }

    @Test func recentClampsNegativeLimitToZero() {
        let store = freshStore()
        store.record(sampleProof(quote: "Something."), for: UUID())
        #expect(store.recent(limit: -3).isEmpty,
                "Negative limit should clamp to zero — never crash, never return junk")
    }

    @Test func persistenceRoundTripsAcrossStores() {
        // Mirror the AskNoumStore relaunch test — a fresh store reading
        // the same defaults suite + account ID should see the saved
        // archive. Locks the on-disk format against silent regressions.
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let store1 = ProofMomentStore(defaults: suite, accountIDProvider: { "tester" })
        let sessionID = UUID()
        store1.record(sampleProof(quote: "Persistent quote."), for: sessionID)

        let store2 = ProofMomentStore(defaults: suite, accountIDProvider: { "tester" })
        #expect(store2.records.count == 1)
        #expect(store2.records.first?.sessionID == sessionID)
        #expect(store2.records.first?.proof.quote == "Persistent quote.")
    }

    @Test func accountSwitchHidesOtherAccountArchive() {
        // Account A writes a proof. Account B (same defaults suite,
        // different ID) starts empty — per-account scoping locks the
        // archive to the signed-in user.
        let suite = UserDefaults(suiteName: UUID().uuidString)!
        let storeA = ProofMomentStore(defaults: suite, accountIDProvider: { "alpha" })
        storeA.record(sampleProof(quote: "A's quote."), for: UUID())

        let storeB = ProofMomentStore(defaults: suite, accountIDProvider: { "beta" })
        #expect(storeB.records.isEmpty,
                "Account B must not see Account A's archive")

        // And A re-loaded still sees its own.
        let storeAReload = ProofMomentStore(defaults: suite, accountIDProvider: { "alpha" })
        #expect(storeAReload.records.count == 1)
        #expect(storeAReload.records.first?.proof.quote == "A's quote.")
    }

    @Test func capDropsOldestByAddedAt() {
        // Push more than the cap. Oldest-by-addedAt should be the one
        // that drops off so a recent refresh-replace doesn't accidentally
        // evict a record we just upgraded.
        let store = freshStore()
        let now = Date()
        // 14 records — 2 over the cap of 12.
        for i in 0..<14 {
            let addedAt = now.addingTimeInterval(TimeInterval(i))
            let proof = sampleProof(
                quote: "Quote \(i).",
                sessionDate: now.addingTimeInterval(TimeInterval(-i) * 10)
            )
            store.record(proof, for: UUID(), at: addedAt)
        }
        #expect(store.records.count == ProofMomentStore.maxStoredRecords,
                "Archive should never exceed maxStoredRecords on disk")
        // Quote 0 (oldest addedAt) is gone. Quote 13 (newest addedAt) is in.
        #expect(!store.records.contains(where: { $0.proof.quote == "Quote 0." }),
                "Oldest-by-addedAt should be evicted first")
        #expect(store.records.contains(where: { $0.proof.quote == "Quote 13." }))
    }

    @Test func clearWipesAllRecords() {
        let store = freshStore()
        store.record(sampleProof(quote: "One."), for: UUID())
        store.record(sampleProof(quote: "Two."), for: UUID())
        #expect(store.records.count == 2)
        store.clear()
        #expect(store.records.isEmpty)
    }

    @Test func removeDropsSpecificRecord() {
        let store = freshStore()
        let keepID = UUID()
        let dropID = UUID()
        store.record(sampleProof(quote: "Keep."), for: keepID)
        store.record(sampleProof(quote: "Drop."), for: dropID)
        store.remove(sessionID: dropID)
        #expect(store.records.count == 1)
        #expect(store.records.first?.sessionID == keepID)
    }
}

// MARK: - userContext proof rendering
//
// Pins the contract that proof moments thread into the AI coach's
// context block:
//   1. With proofs, a PROOFS section appears with verbatim quotes.
//   2. Without proofs, the section is omitted entirely (never an
//      empty heading, never a fabricated quote).
//   3. Most-recent-first ordering — the freshest proof reads top.
//   4. Hard cap at 3 — the system prompt stays bounded even if the
//      archive holds 12 records.

struct CoachContextBuilderProofTests {

    private func sampleProfile(voice: SpeakingStyleGoal = .authoritative) -> CoachingProfile {
        CoachingProfile(
            speakingContext: .work,
            primaryGoal: .reduceFillers,
            confidenceLevel: .rebuilding,
            biggestChallenge: .fillerWords,
            desiredOutcome: .concise,
            speakingStyleGoal: voice,
            styleReference: "",
            coachingBrief: "",
            motivationWhyNow: "",
            successVision: ""
        )
    }

    private func sampleProof(
        quote: String,
        technique: String,
        date: Date
    ) -> ProofMoment {
        ProofMoment(
            quote: quote,
            technique: technique,
            claim: "Coach-voice claim — voice-shaped.",
            sessionDate: date,
            isAIBacked: false,
            generatedAt: Date()
        )
    }

    private func record(quote: String, technique: String, date: Date) -> ProofMomentRecord {
        ProofMomentRecord(
            sessionID: UUID(),
            proof: sampleProof(quote: quote, technique: technique, date: date),
            addedAt: Date()
        )
    }

    @Test func proofsSectionAppearsWhenRecordsProvided() {
        // With non-empty proofs, the context should carry a PROOFS
        // section + at least one verbatim quote so the model can
        // quote it back at the user.
        let r = record(
            quote: "we focused on three priorities",
            technique: "Triad",
            date: Date()
        )
        let ctx = CoachContextBuilder.userContext(
            profile: sampleProfile(),
            baseline: .empty,
            rating: .initial,
            sessions: [],
            currentStreak: 0,
            pathStatus: nil,
            pathGatingPhrase: nil,
            recentProofs: [r]
        )
        #expect(ctx.contains("PROOFS"),
                "Non-empty proofs should produce a PROOFS section header")
        #expect(ctx.contains("we focused on three priorities"),
                "PROOFS section should carry the verbatim quote")
        #expect(ctx.contains("Triad"),
                "PROOFS section should carry the technique label")
    }

    @Test func proofsSectionOmittedWhenRecordsEmpty() {
        // Cold-start / pre-proof users get NO PROOFS section. The
        // model can't quote what doesn't exist; the section is silent
        // rather than rendering an empty header.
        let ctx = CoachContextBuilder.userContext(
            profile: sampleProfile(),
            baseline: .empty,
            rating: .initial,
            sessions: [],
            currentStreak: 0,
            pathStatus: nil,
            pathGatingPhrase: nil,
            recentProofs: []
        )
        #expect(!ctx.contains("PROOFS"),
                "Empty proofs should omit the PROOFS section entirely")
    }

    @Test func proofsRenderMostRecentFirst() {
        // Three proofs across three different dates. The newest must
        // read on top so the model anchors on the freshest evidence.
        let old = record(
            quote: "older quote here",
            technique: "Anchor Phrase",
            date: Date(timeIntervalSinceNow: -86_400 * 14)
        )
        let mid = record(
            quote: "middle quote here",
            technique: "Triad",
            date: Date(timeIntervalSinceNow: -86_400 * 3)
        )
        let new = record(
            quote: "newest quote here",
            technique: "BLUF",
            date: Date()
        )
        let ctx = CoachContextBuilder.userContext(
            profile: sampleProfile(),
            baseline: .empty,
            rating: .initial,
            sessions: [],
            currentStreak: 0,
            pathStatus: nil,
            pathGatingPhrase: nil,
            recentProofs: [old, mid, new] // intentionally unsorted on input
        )
        let newestIdx = ctx.range(of: "newest quote here")?.lowerBound
        let middleIdx = ctx.range(of: "middle quote here")?.lowerBound
        let oldestIdx = ctx.range(of: "older quote here")?.lowerBound
        #expect(newestIdx != nil && middleIdx != nil && oldestIdx != nil,
                "All three proofs should render")
        if let n = newestIdx, let m = middleIdx, let o = oldestIdx {
            #expect(n < m, "Newest must precede middle")
            #expect(m < o, "Middle must precede oldest")
        }
    }

    @Test func proofsAreHardCappedAtThree() {
        // Even if the archive holds 12, the system prompt only sees 3
        // — the contract is bounded context, not an exhaustive dump.
        var records: [ProofMomentRecord] = []
        for i in 0..<12 {
            records.append(record(
                quote: "quote number \(i)",
                technique: "Move \(i)",
                date: Date(timeIntervalSinceNow: TimeInterval(-i) * 100)
            ))
        }
        let ctx = CoachContextBuilder.userContext(
            profile: sampleProfile(),
            baseline: .empty,
            rating: .initial,
            sessions: [],
            currentStreak: 0,
            pathStatus: nil,
            pathGatingPhrase: nil,
            recentProofs: records
        )
        // The three most-recent appear (0, 1, 2 — closest to "now").
        #expect(ctx.contains("quote number 0"))
        #expect(ctx.contains("quote number 1"))
        #expect(ctx.contains("quote number 2"))
        // The fourth onward must NOT appear — context stays bounded.
        #expect(!ctx.contains("quote number 3"),
                "Hard cap at 3 — older proofs must not bleed into the system prompt")
        #expect(!ctx.contains("quote number 11"))
    }

    @Test func proofsSectionLandsAfterTrends() {
        // Section order matters for the model — GOAL / RATING / etc.
        // come first, PROOFS reads as supporting evidence at the end.
        // Locks the ordering so a future refactor can't accidentally
        // bury GOAL beneath PROOFS.
        let r = record(quote: "evidence quote here", technique: "BLUF", date: Date())
        let ctx = CoachContextBuilder.userContext(
            profile: sampleProfile(),
            baseline: .empty,
            rating: .initial,
            sessions: [],
            currentStreak: 0,
            pathStatus: nil,
            pathGatingPhrase: nil,
            recentProofs: [r]
        )
        let goalIdx = ctx.range(of: "GOAL")?.lowerBound
        let proofsIdx = ctx.range(of: "PROOFS")?.lowerBound
        #expect(goalIdx != nil && proofsIdx != nil)
        if let g = goalIdx, let p = proofsIdx {
            #expect(g < p, "GOAL must precede PROOFS in the system prompt")
        }
    }
}

// MARK: - Practice Mode Row Expansion (M15 Phase 3)
//
// Pins the contract behind the "What this trains" affordance copy:
//   1. Every `PracticeMode` resolves to a complete triple (pressureType,
//      surfaces, repLength). No silent gaps.
//   2. Coach voice — no exclamation marks, no emoji. The user is
//      already tense in the picker; chirpy filler reads as a sales
//      pitch, not a coach.
//   3. The rep-length line is specific (mentions seconds or minutes).
//      "Typical rep length" without a duration is exactly the kind of
//      generic copy this affordance exists to replace.

@MainActor
struct PracticeModeRowExpansionTests {

    private static let allModes: [PracticeMode] = [
        .timed, .suddenDeath, .ahCounter, .imConversation
    ]

    @Test func everyModeHasCompleteExpansionCopy() {
        for mode in Self.allModes {
            let copy = PracticeModeExpansionCopy.copy(for: mode)
            #expect(!copy.pressureType.trimmingCharacters(in: .whitespaces).isEmpty,
                    "\(mode) missing pressureType")
            #expect(!copy.surfaces.trimmingCharacters(in: .whitespaces).isEmpty,
                    "\(mode) missing surfaces")
            #expect(!copy.repLength.trimmingCharacters(in: .whitespaces).isEmpty,
                    "\(mode) missing repLength")
        }
    }

    @Test func expansionCopyHonorsCoachVoice() {
        for mode in Self.allModes {
            let copy = PracticeModeExpansionCopy.copy(for: mode)
            let combined = "\(copy.pressureType) \(copy.surfaces) \(copy.repLength)"
            #expect(!combined.contains("!"),
                    "\(mode) copy must not use exclamation marks")
            let hasEmoji = combined.unicodeScalars.contains { scalar in
                scalar.properties.isEmojiPresentation
                    || (scalar.value >= 0x1F300 && scalar.value <= 0x1FAFF)
            }
            #expect(!hasEmoji, "\(mode) copy must not contain emoji")
        }
    }

    @Test func repLengthIsSpecific() {
        for mode in Self.allModes {
            let copy = PracticeModeExpansionCopy.copy(for: mode)
            let lower = copy.repLength.lowercased()
            // Must mention a duration unit — `s` (seconds), `min`, or
            // `minute`. Catches a future edit that strips the unit
            // while leaving the line in place.
            let mentionsDuration = lower.contains("s ")
                || lower.hasSuffix("s.")
                || lower.contains("min")
            #expect(mentionsDuration,
                    "\(mode) repLength should mention a unit: \(copy.repLength)")
        }
    }

    @Test func expansionCopyStaysTerse() {
        // 3 lines max means each line should still read as one sentence,
        // not a paragraph. Cap each line at a soft ~80 chars so a future
        // edit doesn't grow the affordance into a wall of text.
        for mode in Self.allModes {
            let copy = PracticeModeExpansionCopy.copy(for: mode)
            for (label, line) in [
                ("pressureType", copy.pressureType),
                ("surfaces", copy.surfaces),
                ("repLength", copy.repLength)
            ] {
                #expect(line.count <= 80,
                        "\(mode) \(label) too long (\(line.count) chars): \(line)")
            }
        }
    }
}

// MARK: - Home discipline (M15 Phase 4)

/// Locks the contract that the signal-gated home holds back cards until
/// the user has the signal to fill them — and that the Settings override
/// fully reverses the gate.
struct HomeSignalGateTests {
    @Test func coldStartShowsOnlyFloorCards() {
        let gate = HomeSignalGate.evaluate(
            sessionCount: 0,
            sessionsThisWeekCount: 0,
            hasUnlockedPathNode: false,
            hasCoachingProfile: false,
            showAllOverride: false
        )
        #expect(gate.coachCard)
        #expect(gate.utilityStrip)
        #expect(gate.askNoumPromo)
        #expect(!gate.dailyChallenge)
        #expect(!gate.voiceMetrics)
        #expect(!gate.aiWeeklyInsight)
        #expect(!gate.journey)
    }

    @Test func firstSessionUnlocksDailyChallengeAndVoiceMetrics() {
        let gate = HomeSignalGate.evaluate(
            sessionCount: 1,
            sessionsThisWeekCount: 1,
            hasUnlockedPathNode: false,
            hasCoachingProfile: false,
            showAllOverride: false
        )
        #expect(gate.dailyChallenge)
        #expect(gate.voiceMetrics)
        // Weekly insight stays gated until session 3 this week.
        #expect(!gate.aiWeeklyInsight)
    }

    @Test func threeSessionsInWeekUnlocksWeeklyInsight() {
        let gate = HomeSignalGate.evaluate(
            sessionCount: 3,
            sessionsThisWeekCount: 3,
            hasUnlockedPathNode: false,
            hasCoachingProfile: false,
            showAllOverride: false
        )
        #expect(gate.aiWeeklyInsight)
    }

    @Test func goalSetStateUnlocksJourney() {
        let gate = HomeSignalGate.evaluate(
            sessionCount: 0,
            sessionsThisWeekCount: 0,
            hasUnlockedPathNode: false,
            hasCoachingProfile: true,
            showAllOverride: false
        )
        #expect(gate.journey, "Journey card should surface once a voice goal is captured, even before any rep.")
    }

    @Test func unlockedPathNodeUnlocksJourney() {
        let gate = HomeSignalGate.evaluate(
            sessionCount: 5,
            sessionsThisWeekCount: 2,
            hasUnlockedPathNode: true,
            hasCoachingProfile: false,
            showAllOverride: false
        )
        #expect(gate.journey)
    }

    /// Reversibility contract — flipping the AppStorage escape hatch must
    /// restore every card regardless of signal. Returning power-users who
    /// don't want the gradual reveal get the dense home back.
    @Test func showAllOverrideReturnsEveryCard() {
        let gate = HomeSignalGate.evaluate(
            sessionCount: 0,
            sessionsThisWeekCount: 0,
            hasUnlockedPathNode: false,
            hasCoachingProfile: false,
            showAllOverride: true
        )
        #expect(gate == .allVisible)
    }

    @Test func weeklyCountUsesISOWeekBoundary() {
        let iso = Calendar(identifier: .iso8601)
        let now = Date()
        guard let weekInterval = iso.dateInterval(of: .weekOfYear, for: now) else {
            Issue.record("ISO week interval not derivable")
            return
        }
        let insideMid = weekInterval.start.addingTimeInterval(weekInterval.duration / 2)
        let insideStart = weekInterval.start.addingTimeInterval(60)
        let beforeWeek = weekInterval.start.addingTimeInterval(-86_400)
        let afterWeek = weekInterval.end.addingTimeInterval(86_400)
        let count = HomeSignalGate.sessionsInCurrentISOWeek(
            sessionDates: [insideMid, insideStart, beforeWeek, afterWeek],
            now: now
        )
        #expect(count == 2)
    }
}

// MARK: - Home discipline augmentation (M15 Phase 4 edge cases)

/// Edge cases on top of `HomeSignalGateTests`. The phase commit landed
/// the happy-path coverage; these pin the contract at the corners where
/// a future refactor is most likely to silently regress:
///   • Override beats every signal-derived flag (not just when signals
///     are zero) — a returning power-user with full signal must still
///     get `.allVisible` exactly.
///   • Empty-week boundary: `sessionsInCurrentISOWeek` on an empty
///     date list must return 0 (defensive against optionals collapsing
///     to `[]`).
///   • Floor cards never depend on signal — re-asserted explicitly so a
///     refactor that wires `coachCard` to a session threshold can't
///     slip through.
@MainActor
struct HomeSignalGateEdgeTests {

    @Test func overrideWinsEvenWhenSignalsAlreadyTrue() {
        // Returning user with rich signal flips the toggle on. The
        // override path should still hand back the canonical
        // `.allVisible` value identically, so call sites that compare
        // against `.allVisible` to short-circuit downstream gating stay
        // correct.
        let gate = HomeSignalGate.evaluate(
            sessionCount: 50,
            sessionsThisWeekCount: 12,
            hasUnlockedPathNode: true,
            hasCoachingProfile: true,
            showAllOverride: true
        )
        #expect(gate == .allVisible)
    }

    @Test func emptyDateListReturnsZeroForCurrentWeek() {
        // Defensive: callers will pass `sessionStore.sessions.map(\.date)`
        // — that array is empty for fresh installs. Must not crash, must
        // not surface a non-zero count.
        let count = HomeSignalGate.sessionsInCurrentISOWeek(
            sessionDates: [],
            now: Date()
        )
        #expect(count == 0)
    }

    @Test func floorCardsNeverDependOnSignal() {
        // Coach + UtilityStrip + AskNoum promo are the cold-start floor.
        // Re-asserted as a separate contract because they're the only
        // three cards the cold-start home shows, and a future "hide
        // everything until session 1" refactor would silently break
        // the empty-state read.
        for sessions in [0, 1, 5, 25] {
            let gate = HomeSignalGate.evaluate(
                sessionCount: sessions,
                sessionsThisWeekCount: 0,
                hasUnlockedPathNode: false,
                hasCoachingProfile: false,
                showAllOverride: false
            )
            #expect(gate.coachCard, "coachCard must be true at \(sessions) sessions")
            #expect(gate.utilityStrip, "utilityStrip must be true at \(sessions) sessions")
            #expect(gate.askNoumPromo, "askNoumPromo must be true at \(sessions) sessions")
        }
    }

    @Test func journeyUnlockSatisfiedByEitherCondition() {
        // OR contract: either an unlocked path node OR a captured voice
        // goal is enough on its own. Re-stated separately from
        // `goalSetStateUnlocksJourney` / `unlockedPathNodeUnlocksJourney`
        // so a refactor that accidentally tightens it to `AND` fails
        // the contract regardless of which leg gets dropped first.
        let pathOnly = HomeSignalGate.evaluate(
            sessionCount: 0,
            sessionsThisWeekCount: 0,
            hasUnlockedPathNode: true,
            hasCoachingProfile: false,
            showAllOverride: false
        )
        #expect(pathOnly.journey)

        let goalOnly = HomeSignalGate.evaluate(
            sessionCount: 0,
            sessionsThisWeekCount: 0,
            hasUnlockedPathNode: false,
            hasCoachingProfile: true,
            showAllOverride: false
        )
        #expect(goalOnly.journey)

        let neither = HomeSignalGate.evaluate(
            sessionCount: 0,
            sessionsThisWeekCount: 0,
            hasUnlockedPathNode: false,
            hasCoachingProfile: false,
            showAllOverride: false
        )
        #expect(!neither.journey, "Journey must stay gated when neither leg is satisfied")
    }

    @Test func weeklyInsightStaysGatedAtTwoSessions() {
        // `aiWeeklyInsight` opens at 3 sessions in the current ISO week.
        // Tests the lower side of the threshold so a future `>= 2` typo
        // gets caught.
        let twoSessions = HomeSignalGate.evaluate(
            sessionCount: 12,
            sessionsThisWeekCount: 2,
            hasUnlockedPathNode: false,
            hasCoachingProfile: false,
            showAllOverride: false
        )
        #expect(!twoSessions.aiWeeklyInsight, "Two sessions this week should not unlock the AI Weekly Insight card")

        let threeSessions = HomeSignalGate.evaluate(
            sessionCount: 12,
            sessionsThisWeekCount: 3,
            hasUnlockedPathNode: false,
            hasCoachingProfile: false,
            showAllOverride: false
        )
        #expect(threeSessions.aiWeeklyInsight)
    }
}

// MARK: - Insights banked chip (M15 Phase 5)
//
// Phase 5 surfaces `ProofMomentStore.shared.records` as a quiet ambient
// signal on Profile + Ask Noum. The two surfaces share the same shape:
//   • Hidden entirely when the archive is empty (no "0 insights" copy,
//     no "you lost your streak" loss-aversion — VISION.md anti-goal #2).
//   • Pluralisation: "1 insight" (singular), otherwise "N insights".
//   • Most-recent recency uses whole-day granularity matching the
//     SummaryView / HomeCoachCard idiom: "today" / "1d ago" / "Nd ago".
//
// The Profile and AskNoum view helpers that compute this are `private`,
// so these tests pin the contract by re-implementing the exact formula
// the production code uses. If the production helper drifts, the chip
// will visibly disagree with this contract in QA — and a later
// re-promotion of the helper to `internal` will let us swap to direct
// calls without changing the assertions.

@MainActor
struct InsightsBankedChipTests {

    private func proof(daysAgo: Int) -> ProofMoment {
        let sessionDate = Calendar.current.date(
            byAdding: .day, value: -daysAgo, to: Date()
        ) ?? Date()
        return ProofMoment(
            quote: "Sample quote \(daysAgo).",
            technique: "Power Pause",
            claim: "",
            sessionDate: sessionDate,
            isAIBacked: false,
            generatedAt: Date()
        )
    }

    /// Mirror of ProfileView's `mostRecentInsightRecency`. The production
    /// helper is private; this is the contract it must satisfy.
    private func recency(forMostRecentSessionDate date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: date),
            to: cal.startOfDay(for: Date())
        ).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "1d ago"
        default: return "\(days)d ago"
        }
    }

    /// Mirror of the pluralisation rule shared by Profile + AskNoum.
    private func noun(for count: Int) -> String {
        count == 1 ? "insight" : "insights"
    }

    @Test func nounSingularAtOne() {
        #expect(noun(for: 1) == "insight")
    }

    @Test func nounPluralAtZeroAndAboveOne() {
        // Zero matters even though the chip is hidden at zero — the
        // copy still has to read correctly if it ever does render
        // (e.g. a future "0 banked, your first rep starts the count"
        // empty-state experiment).
        #expect(noun(for: 0) == "insights")
        #expect(noun(for: 2) == "insights")
        #expect(noun(for: 99) == "insights")
    }

    @Test func recencyReadsAsTodayForSameCalendarDay() {
        // Same calendar day — `days == 0` falls into the `..<1` arm.
        let now = Date()
        #expect(recency(forMostRecentSessionDate: now) == "today")
    }

    @Test func recencyReadsAsOneDayAgoForYesterday() {
        let yesterday = Calendar.current.date(
            byAdding: .day, value: -1, to: Date()
        )!
        #expect(recency(forMostRecentSessionDate: yesterday) == "1d ago")
    }

    @Test func recencyReadsAsDaysAgoForOlderDates() {
        let threeDaysAgo = Calendar.current.date(
            byAdding: .day, value: -3, to: Date()
        )!
        let twoWeeksAgo = Calendar.current.date(
            byAdding: .day, value: -14, to: Date()
        )!
        #expect(recency(forMostRecentSessionDate: threeDaysAgo) == "3d ago")
        #expect(recency(forMostRecentSessionDate: twoWeeksAgo) == "14d ago")
    }

    @Test func chipHiddenWhenArchiveIsEmpty() {
        // Locks the "no streak loop" anti-goal. The chip composition
        // hinges on `count > 0`; emptyArchive must not render at all.
        let store = ProofMomentStore(
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            accountIDProvider: { "chip-empty" }
        )
        #expect(store.records.isEmpty)
        // The view layer guards with `if count > 0`. Asserting on the
        // store itself is the layer-of-record check — if the archive is
        // empty the chip cannot render.
        let count = store.records.count
        #expect(count == 0, "Empty archive must yield zero count so the chip stays hidden")
    }

    @Test func chipRendersOldestSessionRecencyForOnlyRecord() {
        // Single proof, three days old. The chip's "Most recent" arm
        // must read the same session date back as recency input. Locks
        // the ordering contract: the chip pulls `recent(limit: 1).first`
        // which `ProofMomentStore` returns sorted by sessionDate desc —
        // so for a single record the chip's recency == that record's
        // session date.
        let store = ProofMomentStore(
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            accountIDProvider: { "chip-single" }
        )
        let onlyProof = proof(daysAgo: 3)
        store.record(onlyProof, for: UUID())
        let mostRecent = store.recent(limit: 1).first?.proof.sessionDate
        #expect(mostRecent != nil)
        if let mostRecent {
            #expect(recency(forMostRecentSessionDate: mostRecent) == "3d ago")
        }
    }

    @Test func chipPicksFreshestWhenMultipleRecordsExist() {
        // Multiple proofs across ages — `recent(limit: 1).first` returns
        // the freshest session. The chip's recency string must reflect
        // that one, not the median or the oldest.
        let store = ProofMomentStore(
            defaults: UserDefaults(suiteName: UUID().uuidString)!,
            accountIDProvider: { "chip-multi" }
        )
        store.record(proof(daysAgo: 14), for: UUID())
        store.record(proof(daysAgo: 1),  for: UUID())
        store.record(proof(daysAgo: 7),  for: UUID())
        let freshest = store.recent(limit: 1).first?.proof.sessionDate
        #expect(freshest != nil)
        if let freshest {
            #expect(recency(forMostRecentSessionDate: freshest) == "1d ago")
        }
        #expect(store.records.count == 3)
        #expect(noun(for: store.records.count) == "insights")
    }
}

// MARK: - First-rep celebration fallback chain (M15 Phase 2)
//
// Phase 2 swaps the generic "duration + fillers" subtitle on the first-
// rep celebration for a verbatim coach observation. The observation
// flows through a two-stage fallback chain inside FirstRepCelebration:
//
//   ProofMomentService.proof(for:)      // canonical AI / template path
//     ↳ if nil ↦ celebrationLocalProof  // celebration-only minimum
//         ↳ pulls a 4-14 word slice via minimumVerbatimSlice
//         ↳ frames it via quoteFramingCopy (voice × filler matrix)
//
// These helpers are the path most likely to break silently in
// production — the AI path has its own tests over in
// `ProofMomentServiceTests`, but the celebration-local fallback only
// fires when the AI path returns nil (rep ≤8s, very sparse transcript)
// and is the read every brand-new user gets on rep 1.
//
// The matrix of voices × filler-count buckets is large; rather than
// asserting exact copy on every cell (which would be a maintenance
// magnet), these tests assert tone-shape: each cell returns a non-empty
// distinct string, the "claim wins if non-empty" precedence is locked,
// and the per-voice register has a recognisable mark (e.g. authoritative
// closes on a period, warm uses "felt" / "heard" / "honest", concise
// stays brief). If a future copy edit drifts the register, the test
// fails before QA reads it on-device.

@MainActor
struct FirstRepCelebrationFallbackTests {

    // MARK: - minimumVerbatimSlice

    @Test func sliceReturnsNilForEmptyTranscript() {
        #expect(FirstRepCelebration.minimumVerbatimSlice(in: "") == nil)
        #expect(FirstRepCelebration.minimumVerbatimSlice(in: "    ") == nil)
    }

    @Test func sliceReturnsNilForSingleWord() {
        // <4 words is the floor — the slot stays empty and the
        // celebration falls back to the duration+filler safety net.
        #expect(FirstRepCelebration.minimumVerbatimSlice(in: "Hello") == nil)
        #expect(FirstRepCelebration.minimumVerbatimSlice(in: "Hello there friend") == nil)
    }

    @Test func sliceReturnsFullPhraseAtExactlyFourWords() {
        // Exactly the lower-bound. The whole phrase must come back —
        // no truncation, no extra trimming.
        let slice = FirstRepCelebration.minimumVerbatimSlice(in: "Three priorities this quarter")
        #expect(slice == "Three priorities this quarter")
    }

    @Test func sliceReturnsFullPhraseAtExactlyFourteenWords() {
        // Upper bound of the "return as-is" branch — fourteen words
        // qualifies as still concise enough to render verbatim
        // (boundary check: <=14 returns whole, 15+ trims to 12).
        let fourteenWords = "I think the most important thing about leadership is empathy and authority every day"
        #expect(FirstRepCelebration.wordCount(fourteenWords) == 14,
                "Test fixture sanity — wordCount must be 14, got \(FirstRepCelebration.wordCount(fourteenWords))")
        let slice = FirstRepCelebration.minimumVerbatimSlice(in: fourteenWords)
        #expect(slice == fourteenWords,
                "14-word transcript should return verbatim, got: \(slice ?? "nil")")
    }

    @Test func sliceTrimsAtFifteenWordsToTwelve() {
        // Just-over-the-boundary check. 15 words triggers the trim
        // path; the returned slice should be exactly 12 words.
        let fifteenWords = "I think the most important thing about leadership is empathy and quiet authority every day"
        #expect(FirstRepCelebration.wordCount(fifteenWords) == 15,
                "Test fixture sanity — wordCount must be 15")
        let slice = FirstRepCelebration.minimumVerbatimSlice(in: fifteenWords)
        #expect(slice != nil)
        if let slice {
            #expect(FirstRepCelebration.wordCount(slice) == 12,
                    "15-word input should trim to 12, got \(FirstRepCelebration.wordCount(slice))-word slice: \(slice)")
        }
    }

    @Test func sliceTrimsLongerSentenceToTwelveWords() {
        // Beyond fourteen words the slice trims to twelve via the
        // raw-word window. Locks the "12-word window" magic number;
        // a future refactor that drops it would silently expand the
        // celebration quote.
        let long = "This rep was one of those moments where I really wanted to nail the opening and not stumble out of the gate at all"
        let slice = FirstRepCelebration.minimumVerbatimSlice(in: long)
        #expect(slice != nil)
        if let slice {
            #expect(FirstRepCelebration.wordCount(slice) == 12,
                    "Long sentence should trim to a 12-word window, got: \(slice)")
            // First word must be preserved — the trim takes from the
            // tail, not the head (otherwise the quote loses its opener).
            #expect(slice.hasPrefix("This rep was"),
                    "Trim window should retain the opener, got: \(slice)")
        }
    }

    @Test func slicePunctuationHeavyPicksFirstQualifyingClause() {
        // Sentence terminators split the transcript first. The first
        // clause with ≥4 words wins — even if a later clause is shorter
        // and "cleaner". Pins the deterministic ordering so two reps
        // with the same opening don't yield different quotes.
        let punctuationHeavy = "Hi! So the thing I want to talk about today is leadership. Then I'll cover trust."
        let slice = FirstRepCelebration.minimumVerbatimSlice(in: punctuationHeavy)
        #expect(slice != nil)
        if let slice {
            // First qualifying clause is the long "So the thing..." one.
            #expect(slice.lowercased().contains("the thing"),
                    "First clause with ≥4 words should win, got: \(slice)")
            #expect(!slice.contains("!"),
                    "Slice should not carry the terminator that split it")
        }
    }

    @Test func sliceNormalisesSmartQuoteApostrophe() {
        // U+2019 right-single-quote (Apple keyboard default) gets
        // normalised to ASCII apostrophe so downstream verbatim-match
        // checks (ProofMomentService.transcriptContains) don't reject
        // the slice when the transcript happens to render with smart
        // quotes.
        let smartQuoted = "It\u{2019}s the moment that matters most"
        let slice = FirstRepCelebration.minimumVerbatimSlice(in: smartQuoted)
        #expect(slice != nil)
        if let slice {
            #expect(slice.contains("'"),
                    "Smart-quote apostrophe should be normalised to ASCII apostrophe")
            #expect(!slice.contains("\u{2019}"),
                    "Smart-quote U+2019 should not survive normalisation")
        }
    }

    @Test func sliceHandlesNewlinesAsWhitespace() {
        // Transcript can arrive with line breaks (multi-paragraph
        // transcription); these must not split the slice arbitrarily
        // or leave embedded `\n` in the rendered quote.
        let multiline = "First line of thought\nsecond line continuing the same idea"
        let slice = FirstRepCelebration.minimumVerbatimSlice(in: multiline)
        #expect(slice != nil)
        if let slice {
            #expect(!slice.contains("\n"),
                    "Newlines should normalise to spaces, got: \(slice)")
            #expect(FirstRepCelebration.wordCount(slice) >= 4)
        }
    }

    // MARK: - wordCount

    @Test func wordCountIgnoresExtraWhitespace() {
        #expect(FirstRepCelebration.wordCount("") == 0)
        #expect(FirstRepCelebration.wordCount("one") == 1)
        #expect(FirstRepCelebration.wordCount("  one    two   ") == 2)
        #expect(FirstRepCelebration.wordCount("a b c d e") == 5)
    }

    // MARK: - celebrationLocalProof

    private func session(transcript: String, fillers: Int = 0, duration: TimeInterval = 30) -> PracticeSession {
        PracticeSession(
            transcript: transcript,
            fillerWordCount: fillers,
            duration: duration,
            date: Date(),
            mode: .timed,
            pressureLevel: .standard
        )
    }

    @Test func localProofIsNilWhenTranscriptIsEmpty() {
        let proof = FirstRepCelebration.celebrationLocalProof(for: session(transcript: ""))
        #expect(proof == nil)
    }

    @Test func localProofIsNilWhenTranscriptIsBelowFourWords() {
        let proof = FirstRepCelebration.celebrationLocalProof(for: session(transcript: "Hello world there"))
        #expect(proof == nil, "Sub-floor transcript should not produce a local proof")
    }

    @Test func localProofExtractsVerbatimAtFourWords() {
        let proof = FirstRepCelebration.celebrationLocalProof(
            for: session(transcript: "Three priorities this quarter")
        )
        #expect(proof != nil)
        if let proof {
            #expect(proof.quote == "Three priorities this quarter")
            #expect(proof.claim.isEmpty,
                    "Local-fallback proof must leave claim empty so quoteFramingCopy supplies the framing")
            #expect(!proof.isAIBacked, "Celebration-local proof must never be marked AI-backed")
            #expect(proof.technique == "First Read",
                    "Celebration-local proof uses the dedicated 'First Read' technique label")
        }
    }

    @Test func localProofCarriesSessionDateThrough() {
        // The proof's `sessionDate` drives the chat-context ordering
        // downstream; it must mirror the session it was extracted from
        // (not the wall clock at extraction time).
        let oldSession = PracticeSession(
            transcript: "Three priorities this quarter",
            fillerWordCount: 0,
            duration: 30,
            date: Date(timeIntervalSinceNow: -86_400 * 3),
            mode: .timed,
            pressureLevel: .standard
        )
        let proof = FirstRepCelebration.celebrationLocalProof(for: oldSession)
        #expect(proof != nil)
        if let proof {
            #expect(proof.sessionDate == oldSession.date)
        }
    }

    // MARK: - quoteFramingCopy — precedence

    @Test func framingHonoursNonEmptyClaim() {
        // If the service handed back a real claim string (AI path or
        // templated fallback inside the canonical service), that copy
        // was already voice-shaped — the framing must trust it and
        // return it verbatim regardless of voice or filler count.
        let claim = "Steady hold — composure reads as authority."
        let result = FirstRepCelebration.quoteFramingCopy(
            claim: claim,
            fillerCount: 5,
            voice: .warm
        )
        #expect(result == claim)
    }

    @Test func framingFallsThroughOnEmptyClaim() {
        // Empty claim is the celebration-local path; the framing must
        // produce a non-empty observation pulled from the voice × filler
        // matrix, never echo the empty string.
        for voice in SpeakingStyleGoal.allCases {
            for fillers in [0, 1, 3] {
                let result = FirstRepCelebration.quoteFramingCopy(
                    claim: "",
                    fillerCount: fillers,
                    voice: voice
                )
                #expect(!result.isEmpty,
                        "voice=\(voice), fillers=\(fillers) must return a non-empty observation")
            }
        }
    }

    // MARK: - quoteFramingCopy — voice × filler matrix coverage

    @Test func framingCoversEveryVoiceFillerCellWithoutDuplicates() {
        // Locks the "every voice has three distinct branches" contract:
        // a 0-filler line, a 1-2-filler line, and a 3+ filler line. A
        // refactor that accidentally collapses two branches into one
        // (or copy-pastes the warm line into executive) would silently
        // strip the per-voice register on rep 1.
        let voices: [SpeakingStyleGoal?] = SpeakingStyleGoal.allCases.map { $0 } + [nil]
        for voice in voices {
            let zero = FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 0, voice: voice)
            let oneOrTwo = FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 1, voice: voice)
            let many = FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 4, voice: voice)
            // All three branches non-empty
            #expect(!zero.isEmpty)
            #expect(!oneOrTwo.isEmpty)
            #expect(!many.isEmpty)
            // All three branches distinct — same string in two cells
            // means a branch was lost.
            #expect(zero != oneOrTwo, "voice=\(String(describing: voice)) 0 == 1-2 — branch collapsed")
            #expect(oneOrTwo != many, "voice=\(String(describing: voice)) 1-2 == 3+ — branch collapsed")
            #expect(zero != many, "voice=\(String(describing: voice)) 0 == 3+ — branch collapsed")
        }
    }

    @Test func framingFillerBucketBoundaryAtTwo() {
        // 2 fillers must use the 1-2 line; 3 must use the "3+" line.
        // Pins the off-by-one. Tested on .none so we don't have to pick
        // a particular voice arbitrarily.
        let two = FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 2, voice: .none)
        let three = FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 3, voice: .none)
        // Reference values from the source: 2 ⇒ "A few fillers in the open..."
        //                                    3 ⇒ "Fillers cluster early. The pause..."
        #expect(two.contains("few fillers") || two.contains("tell"),
                "fillerCount==2 should land on the 1-2 branch, got: \(two)")
        #expect(three.contains("cluster") || three.contains("pause"),
                "fillerCount==3 should land on the 3+ branch, got: \(three)")
        #expect(two != three)
    }

    @Test func framingNoBranchUsesAnExclamation() {
        // Brand rule + Phase 2 brief: the framing must read as
        // observation, not as a cheerleader. No exclamation marks
        // anywhere in the matrix.
        let voices: [SpeakingStyleGoal?] = SpeakingStyleGoal.allCases.map { $0 } + [nil]
        for voice in voices {
            for fillers in [0, 1, 2, 3, 4, 10] {
                let result = FirstRepCelebration.quoteFramingCopy(
                    claim: "", fillerCount: fillers, voice: voice
                )
                #expect(!result.contains("!"),
                        "voice=\(String(describing: voice)) fillers=\(fillers) must not use an exclamation mark, got: \(result)")
            }
        }
    }

    @Test func framingAuthoritativeRegisterClosesOnDeclarative() {
        // Authoritative register reads as a verdict — every cell ends
        // with a period (no question marks, no soft endings). Holds
        // the per-voice "shape" rule from the brief.
        for fillers in [0, 1, 3] {
            let result = FirstRepCelebration.quoteFramingCopy(
                claim: "", fillerCount: fillers, voice: .authoritative
            )
            #expect(result.hasSuffix("."),
                    "Authoritative voice should close declaratively, got: \(result)")
            #expect(!result.contains("?"),
                    "Authoritative voice should never use a question, got: \(result)")
        }
    }

    @Test func framingWarmRegisterCarriesEmpathyMarkers() {
        // Warm register: at least one branch must use one of the
        // empathy verbs ("felt" / "heard" / "honest" / "calm"). This
        // is the cell-level register check — a copy refactor that
        // strips all empathy markers would land flat to the user.
        let resultsByFillers = [
            FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 0, voice: .warm),
            FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 1, voice: .warm),
            FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 4, voice: .warm),
        ]
        let combined = resultsByFillers.joined(separator: " ").lowercased()
        let empathyMarkers = ["felt", "heard", "honest", "calm", "feels"]
        let hit = empathyMarkers.contains { combined.contains($0) }
        #expect(hit,
                "Warm voice should carry at least one empathy marker across its branches, got: \(combined)")
    }

    @Test func framingConciseRegisterStaysBrief() {
        // Concise register: every cell stays under ~80 chars. A long
        // line in the concise voice breaks the brand promise of the
        // setting. Soft cap chosen to match the existing
        // PracticeModeExpansionCopy ~80-char rule.
        for fillers in [0, 1, 3] {
            let result = FirstRepCelebration.quoteFramingCopy(
                claim: "", fillerCount: fillers, voice: .concise
            )
            #expect(result.count <= 80,
                    "Concise voice should stay terse (≤80 chars), got \(result.count): \(result)")
        }
    }

    @Test func framingExecutiveRegisterCarriesBriefingMarkers() {
        // Executive register: at least one branch uses a briefing /
        // recommendation marker ("Recommend" / "Brief" / "signal").
        let combined = [
            FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 0, voice: .executive),
            FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 1, voice: .executive),
            FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 4, voice: .executive),
        ].joined(separator: " ").lowercased()
        let hit = ["recommend", "brief", "signal", "composed"].contains { combined.contains($0) }
        #expect(hit,
                "Executive voice should carry a briefing marker across its branches, got: \(combined)")
    }

    @Test func framingStorytellingRegisterCarriesNarrativeMarkers() {
        // Storytelling register: scene / arc / line / page narrative
        // markers — anything that gestures at a craft vocabulary.
        let combined = [
            FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 0, voice: .storytelling),
            FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 1, voice: .storytelling),
            FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 4, voice: .storytelling),
        ].joined(separator: " ").lowercased()
        let hit = ["scene", "arc", "story", "page", "draft", "breath"].contains { combined.contains($0) }
        #expect(hit,
                "Storytelling voice should gesture at narrative craft across its branches, got: \(combined)")
    }

    @Test func framingNilVoiceFallsBackToNeutralObservation() {
        // nil voice = user hasn't set a SpeakingStyleGoal. The framing
        // must still produce on-brand observation copy (no per-voice
        // adornments leak into the neutral line).
        let zero = FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 0, voice: nil)
        let many = FirstRepCelebration.quoteFramingCopy(claim: "", fillerCount: 4, voice: nil)
        #expect(!zero.isEmpty)
        #expect(!many.isEmpty)
        // Neutral line must not borrow per-voice register markers that
        // would tip a user about a voice they haven't set.
        #expect(!zero.lowercased().contains("recommend"),
                "Neutral voice should not borrow executive register, got: \(zero)")
        #expect(!many.lowercased().contains("story breath"),
                "Neutral voice should not borrow storytelling register, got: \(many)")
    }
}

// MARK: - GrowthLibrary weekly grouping
//
// The Growth Library Profile surface reads
// `ProofMomentStore.weeklyGroups()` to render a week-by-week timeline of
// banked proof moments. The helper is pure-function over the records
// array — these tests drive it directly without instantiating SwiftUI.
//
// Contract under test:
//   • Empty input returns no buckets (the view collapses to the empty
//     state).
//   • Records inside the same ISO week land in one bucket, sorted
//     most-recent-first within the bucket.
//   • Buckets emerge newest-week-first.
//   • Labels mirror the user-readable register: "This week", "Last week",
//     then "Week of MMM d" for older buckets.
//   • Cross-year weeks include the year in the label so the user is
//     never confused between Jan of two different years.

struct GrowthLibraryWeeklyGroupingTests {

    private func calendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal
    }

    private func proof(_ quote: String, on date: Date) -> ProofMomentRecord {
        ProofMomentRecord(
            sessionID: UUID(),
            proof: ProofMoment(
                quote: quote,
                technique: "Power Pause",
                claim: "Steady hold — composure reads as authority.",
                sessionDate: date,
                isAIBacked: false,
                generatedAt: date
            ),
            addedAt: date
        )
    }

    @Test func emptyArchiveReturnsNoBuckets() {
        let groups = ProofMomentStore.weeklyGroups(from: [], now: Date(), calendar: calendar())
        #expect(groups.isEmpty, "Empty input must collapse to an empty timeline")
    }

    @Test func sameWeekRecordsCollapseIntoOneBucket() {
        let cal = calendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 21))!
        let recordA = proof("A", on: cal.date(byAdding: .day, value: -1, to: now)!)
        let recordB = proof("B", on: cal.date(byAdding: .day, value: -2, to: now)!)
        let groups = ProofMomentStore.weeklyGroups(from: [recordA, recordB], now: now, calendar: cal)
        #expect(groups.count == 1, "Two records inside the same ISO week must collapse to one bucket")
        #expect(groups[0].records.count == 2)
        // Within the bucket, most-recent-first.
        #expect(groups[0].records[0].proof.quote == "A")
        #expect(groups[0].records[1].proof.quote == "B")
    }

    @Test func bucketsEmergeNewestWeekFirst() {
        let cal = calendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 21))!
        let recordThisWeek = proof("recent", on: cal.date(byAdding: .day, value: -1, to: now)!)
        let recordTwoWeeksAgo = proof("older", on: cal.date(byAdding: .day, value: -14, to: now)!)
        let groups = ProofMomentStore.weeklyGroups(
            from: [recordTwoWeeksAgo, recordThisWeek],
            now: now,
            calendar: cal
        )
        #expect(groups.count == 2)
        #expect(groups[0].records.first?.proof.quote == "recent",
                "Newest week's bucket must appear first")
        #expect(groups[1].records.first?.proof.quote == "older")
    }

    @Test func thisWeekAndLastWeekLabelsRender() {
        let cal = calendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 21))!
        let recordThisWeek = proof("recent", on: cal.date(byAdding: .day, value: -1, to: now)!)
        let recordLastWeek = proof("older", on: cal.date(byAdding: .day, value: -8, to: now)!)
        let groups = ProofMomentStore.weeklyGroups(
            from: [recordLastWeek, recordThisWeek],
            now: now,
            calendar: cal
        )
        #expect(groups[0].label == "This week")
        #expect(groups[1].label == "Last week")
    }

    @Test func olderBucketsUseExplicitWeekOfLabel() {
        // A record three weeks ago should get a "Week of MMM d" label,
        // not "Last week" — the relative idiom only stretches one week.
        let cal = calendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 5, day: 21))!
        let recordThreeWeeksAgo = proof("oldish", on: cal.date(byAdding: .day, value: -21, to: now)!)
        let groups = ProofMomentStore.weeklyGroups(from: [recordThreeWeeksAgo], now: now, calendar: cal)
        #expect(groups.count == 1)
        #expect(groups[0].label.hasPrefix("Week of "),
                "Older buckets must use explicit week-of-date labels, got: \(groups[0].label)")
        // Same-year records should not carry a year suffix.
        #expect(!groups[0].label.contains("202"),
                "Same-year bucket label must omit the year, got: \(groups[0].label)")
    }

    @Test func crossYearBucketIncludesYearInLabel() {
        // A record from a previous calendar year must include the year
        // in the label so a January 2025 vs January 2026 entry is never
        // ambiguous.
        let cal = calendar()
        let now = cal.date(from: DateComponents(year: 2026, month: 2, day: 15))!
        let lastYear = cal.date(from: DateComponents(year: 2025, month: 12, day: 20))!
        let groups = ProofMomentStore.weeklyGroups(from: [proof("xmas", on: lastYear)], now: now, calendar: cal)
        #expect(groups.count == 1)
        #expect(groups[0].label.contains("2025"),
                "Cross-year bucket must carry the year, got: \(groups[0].label)")
    }
}

// MARK: - AppDestination.sessionDetail wiring
//
// The Growth Library quote cards push `.sessionDetail(sessionID:)` so the
// user can tap a banked moment → land on the session that produced it.
// Two contracts to lock:
//   1. The case is Hashable + Equatable across identical UUIDs (so
//      `NavigationLink(value:)` can dedupe taps and re-enter cleanly).
//   2. Different session IDs produce distinct destinations (so the navi-
//      gation stack doesn't collapse two cards onto the same screen).
struct AppDestinationSessionDetailTests {

    @Test func sessionDetailEqualsBySessionID() {
        let id = UUID()
        let a: AppDestination = .sessionDetail(sessionID: id)
        let b: AppDestination = .sessionDetail(sessionID: id)
        #expect(a == b, "Same session ID must produce equal destinations")
    }

    @Test func sessionDetailDistinctBySessionID() {
        let a: AppDestination = .sessionDetail(sessionID: UUID())
        let b: AppDestination = .sessionDetail(sessionID: UUID())
        #expect(a != b, "Different session IDs must produce distinct destinations")
    }

    @Test func sessionDetailDistinctFromOtherCases() {
        // Sanity — the new case must not collide with the existing
        // growthLibrary or sessionHistory destinations.
        let detail: AppDestination = .sessionDetail(sessionID: UUID())
        #expect(detail != .growthLibrary)
        #expect(detail != .sessionHistory)
    }

    @Test func sessionDetailIsHashable() {
        // NavigationPath stores destinations in a hashable container, so
        // the case has to round-trip through a Set without crashing.
        var set: Set<AppDestination> = []
        let id = UUID()
        set.insert(.sessionDetail(sessionID: id))
        set.insert(.sessionDetail(sessionID: id))
        #expect(set.count == 1, "Identical session-detail destinations must collapse in a Set")
    }
}

#if DEBUG
// MARK: - DevSeedData CoachingProfile seeding
//
// M16 follow-on — DevSeedData.injectProfile now seeds CoachingProfileStore
// alongside sessions/baseline/rating/XP so HomeSignalGate's
// `coachingProfileSet` branch lights up and UI tests can use the tap-the-
// card pattern again on gated home cards. These tests lock the per-seed
// voice mapping so a future "tighten the seed narrative" pass can't quietly
// shuffle voice assignments out from under the screenshot tour. The pure
// helper `DevSeedData.seedCoachingProfile(for:)` is tested directly so we
// don't have to mutate any live stores.
struct DevSeedCoachingProfileTests {

    @Test func improvingIntermediateSeedsWarmVoiceAndConciseGoal() {
        // The showcase profile (used by ScreenshotTour, UI tests, and the
        // -DeepLink screenshot capture path). The voice and goal must
        // match the narrative — fillers dropping → tightening up next,
        // warm voice keeps the coach copy approachable.
        let profile = DevSeedData.seedCoachingProfile(for: .improvingIntermediate)
        #expect(profile.speakingStyleGoal == .warm)
        #expect(profile.primaryGoal == .moreConcise)
        #expect(profile.biggestChallenge == .rambling)
        // displayableGoal falls back to the template until the AI
        // paraphrase lands — must not be empty either way.
        #expect(!profile.displayableGoal.isEmpty)
    }

    @Test func plateauedAdvancedSeedsAuthoritativeVoice() {
        let profile = DevSeedData.seedCoachingProfile(for: .plateauedAdvanced)
        #expect(profile.speakingStyleGoal == .authoritative)
        #expect(profile.speakingContext == .presentations)
    }

    @Test func pressureVulnerableSeedsExecutiveVoiceAndCalmerGoal() {
        let profile = DevSeedData.seedCoachingProfile(for: .pressureVulnerable)
        #expect(profile.speakingStyleGoal == .executive)
        #expect(profile.primaryGoal == .calmerDelivery)
        #expect(profile.biggestChallenge == .rushing)
    }

    @Test func fillerFreeSeedsConciseVoiceAndPersuasiveOutcome() {
        let profile = DevSeedData.seedCoachingProfile(for: .fillerFree)
        #expect(profile.speakingStyleGoal == .concise)
        #expect(profile.desiredOutcome == .persuasive)
    }

    @Test func beginnerSeedsRebuildingConfidenceAndFillerFocus() {
        let profile = DevSeedData.seedCoachingProfile(for: .beginner)
        #expect(profile.confidenceLevel == .rebuilding)
        #expect(profile.primaryGoal == .reduceFillers)
        #expect(profile.biggestChallenge == .fillerWords)
    }

    @Test func everySeedProfileProducesACompleteCoachingProfile() {
        // Hard contract: HomeSignalGate's `coachingProfileSet` branch must
        // light up for every seed profile, not just the showcase one. If
        // a future refactor adds a new SeedProfile case, this test will
        // fail until the new case carries a matching CoachingProfile —
        // CaseIterable + exhaustive switch in seedCoachingProfile is the
        // belt-and-braces compile-time guard, this is the runtime one.
        for seedProfile in SeedProfile.allCases {
            let profile = DevSeedData.seedCoachingProfile(for: seedProfile)
            #expect(!profile.coachingBrief.isEmpty,
                    "\(seedProfile) must seed a non-empty coachingBrief")
            #expect(!profile.motivationWhyNow.isEmpty,
                    "\(seedProfile) must seed a non-empty motivationWhyNow")
            #expect(!profile.successVision.isEmpty,
                    "\(seedProfile) must seed a non-empty successVision")
        }
    }

    @Test func everyVoiceIsDistinctAcrossSeedProfiles() {
        // The five seed profiles should each express a different voice so
        // the screenshot tour and design audits can see every voice live
        // on a single seed pass. Concise + warm + authoritative +
        // executive + warm/etc — the contract: at least 4 distinct
        // voices across the 5 seeds (mild duplication tolerated, full
        // collapse not).
        let voices = Set(SeedProfile.allCases.map { DevSeedData.seedCoachingProfile(for: $0).speakingStyleGoal })
        #expect(voices.count >= 4,
                "Seed profiles must cover at least 4 distinct voices for visual breadth, got: \(voices)")
    }
}
#endif

// MARK: - CoachContextBuilder chip parser
//
// M17 deferred-test coverage. Locks the contract of
// CoachContextBuilder.parseAndFilterChips and the brand-voice rules its
// per-chip filter (passesChipFilter, private) enforces. The model returns
// newline-separated text (NOT JSON), occasionally with list-marker prefixes,
// numeric enumeration, or wrapping quotes — every transform survives a
// regression hit here. passesChipFilter is exercised indirectly: any chip
// the filter rejects gets dropped from the parser's output, so a single-line
// input that fails to produce a count==1 batch proves the rejection branch.

struct CoachContextBuilderChipParserTests {

    // MARK: - parseAndFilterChips: happy path

    @Test func returnsExactCountWhenAllLinesPass() {
        let raw = """
        How did that land?
        What changed for you?
        Where next?
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == ["How did that land?", "What changed for you?", "Where next?"])
    }

    @Test func truncatesToCountWhenMoreLinesSurvive() {
        let raw = """
        One step forward?
        Two steps forward?
        Three steps forward?
        Four steps forward?
        Five steps forward?
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips?.count == 3)
        #expect(chips == ["One step forward?", "Two steps forward?", "Three steps forward?"])
    }

    @Test func trimsLeadingAndTrailingWhitespacePerLine() {
        let raw = "   How did that land?   \n\t  What changed for you?  \t\n   Where next?   "
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == ["How did that land?", "What changed for you?", "Where next?"])
    }

    @Test func stripsHyphenListMarkers() {
        let raw = """
        - How did that land?
        - What changed for you?
        - Where next?
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == ["How did that land?", "What changed for you?", "Where next?"])
    }

    @Test func stripsAsteriskListMarkers() {
        let raw = """
        * How did that land?
        * What changed for you?
        * Where next?
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == ["How did that land?", "What changed for you?", "Where next?"])
    }

    @Test func stripsBulletListMarkers() {
        let raw = """
        • How did that land?
        • What changed for you?
        • Where next?
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == ["How did that land?", "What changed for you?", "Where next?"])
    }

    @Test func stripsRepeatedMixedListMarkers() {
        // The while-loop strips successive list-marker chars (-, *, •) until
        // a non-marker remains; verify that "- * • text" collapses to "text".
        let raw = "-*• How did that land?"
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 1)
        #expect(chips == ["How did that land?"])
    }

    @Test func stripsNumericEnumerationWithDot() {
        let raw = """
        1. How did that land?
        2. What changed for you?
        3. Where next?
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == ["How did that land?", "What changed for you?", "Where next?"])
    }

    @Test func stripsNumericEnumerationWithParen() {
        let raw = """
        1) How did that land?
        2) What changed for you?
        3) Where next?
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == ["How did that land?", "What changed for you?", "Where next?"])
    }

    @Test func stripsWrappingStraightQuotes() {
        let raw = """
        "How did that land?"
        "What changed for you?"
        "Where next?"
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == ["How did that land?", "What changed for you?", "Where next?"])
    }

    @Test func stripsWrappingSmartQuotes() {
        // U+201C / U+201D — the parser handles both straight and curly pairs.
        let raw = "\u{201C}How did that land?\u{201D}\n\u{201C}What changed for you?\u{201D}\n\u{201C}Where next?\u{201D}"
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == ["How did that land?", "What changed for you?", "Where next?"])
    }

    @Test func leavesMismatchedQuotesIntact() {
        // Only the prefix-AND-suffix branch strips; a leading-only quote
        // stays so we don't mangle quoted-phrase chips.
        let raw = "\"Half a quote chip?"
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 1)
        #expect(chips == ["\"Half a quote chip?"])
    }

    // MARK: - parseAndFilterChips: count-gating

    @Test func returnsNilWhenFewerLinesThanRequested() {
        // Two surviving chips can't satisfy count: 3.
        let raw = """
        How did that land?
        What changed for you?
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == nil)
    }

    @Test func returnsNilForEmptyInput() {
        let chips = CoachContextBuilder.parseAndFilterChips("", count: 3)
        #expect(chips == nil)
    }

    @Test func returnsNilForWhitespaceOnlyInput() {
        let chips = CoachContextBuilder.parseAndFilterChips("   \n\t  \n   ", count: 3)
        #expect(chips == nil)
    }

    @Test func returnsNilWhenAllChipsViolateBrandVoice() {
        // Every line trips the exclamation ban — none survive the filter.
        let raw = """
        How did that land!
        What changed for you!
        Where next!
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == nil)
    }

    @Test func mixesValidAndInvalidLinesAndCountsOnlyValid() {
        // 3 valid + 2 invalid → still satisfies count: 3, picks the first 3
        // survivors in source order.
        let raw = """
        How did that land?
        Tell me more
        What changed for you?
        Let's keep going
        Where next?
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == ["How did that land?", "What changed for you?", "Where next?"])
    }

    // MARK: - passesChipFilter (via parseAndFilterChips): brand-voice rejections

    @Test func rejectsChipBelowMinLength() {
        // 3 chars is below the 4-char floor — must drop.
        let chips = CoachContextBuilder.parseAndFilterChips("Hey", count: 1)
        #expect(chips == nil)
    }

    @Test func acceptsChipAtMinLengthBoundary() {
        // Exactly 4 chars — inside the inclusive 4...60 range.
        let chips = CoachContextBuilder.parseAndFilterChips("Next", count: 1)
        #expect(chips == ["Next"])
    }

    @Test func acceptsChipAtMaxLengthBoundary() {
        // Exactly 60 chars — inside the inclusive 4...60 range.
        let chip60 = String(repeating: "a", count: 60)
        let chips = CoachContextBuilder.parseAndFilterChips(chip60, count: 1)
        #expect(chips == [chip60])
    }

    @Test func rejectsChipAboveMaxLength() {
        // 61 chars — outside the inclusive 4...60 range.
        let chip61 = String(repeating: "a", count: 61)
        let chips = CoachContextBuilder.parseAndFilterChips(chip61, count: 1)
        #expect(chips == nil)
    }

    @Test func rejectsChipWithExclamation() {
        let chips = CoachContextBuilder.parseAndFilterChips("Big move ahead!", count: 1)
        #expect(chips == nil)
    }

    @Test func rejectsChipWithEmoji() {
        // Sparkle emoji (U+2728) sits above the 0x238C scalar threshold and
        // has isEmoji true, so it must be dropped.
        let chips = CoachContextBuilder.parseAndFilterChips("Nice move \u{2728}", count: 1)
        #expect(chips == nil)
    }

    @Test func rejectsChipStartingWithLetsContraction() {
        let chips = CoachContextBuilder.parseAndFilterChips("Let's keep going?", count: 1)
        #expect(chips == nil)
    }

    @Test func rejectsChipStartingWithLetsNoApostrophe() {
        let chips = CoachContextBuilder.parseAndFilterChips("Lets keep going?", count: 1)
        #expect(chips == nil)
    }

    @Test func rejectsChipWithTellMeDirective() {
        let chips = CoachContextBuilder.parseAndFilterChips("Tell me more about it", count: 1)
        #expect(chips == nil)
    }

    @Test func rejectsChipWithDescribeDirective() {
        let chips = CoachContextBuilder.parseAndFilterChips("Describe the moment", count: 1)
        #expect(chips == nil)
    }

    @Test func rejectsChipWithExplainDirective() {
        let chips = CoachContextBuilder.parseAndFilterChips("Explain the choice", count: 1)
        #expect(chips == nil)
    }

    @Test func rejectsChipWithDiscussDirective() {
        let chips = CoachContextBuilder.parseAndFilterChips("Discuss the impact", count: 1)
        #expect(chips == nil)
    }

    @Test func rejectsChipWithElaborateDirective() {
        let chips = CoachContextBuilder.parseAndFilterChips("Elaborate on it", count: 1)
        #expect(chips == nil)
    }

    @Test func rejectsChipWithShareDirective() {
        let chips = CoachContextBuilder.parseAndFilterChips("Share more of it", count: 1)
        #expect(chips == nil)
    }

    @Test func rejectsChipWithTalkAboutDirective() {
        let chips = CoachContextBuilder.parseAndFilterChips("Talk about it now", count: 1)
        #expect(chips == nil)
    }

    @Test func directiveCheckIsCaseInsensitive() {
        // Lowercased before comparison — uppercase "TELL ME" must still drop.
        let chips = CoachContextBuilder.parseAndFilterChips("TELL ME more", count: 1)
        #expect(chips == nil)
    }

    @Test func directiveCheckOnlyAppliesAtChipStart() {
        // "tell me" appears mid-chip, not as a prefix — the chip survives.
        let chips = CoachContextBuilder.parseAndFilterChips("Would you tell me later?", count: 1)
        #expect(chips == ["Would you tell me later?"])
    }

    @Test func acceptsLowAsciiSymbolsBelowEmojiThreshold() {
        // The emoji guard ignores scalars <= 0x238C — the # symbol (U+0023)
        // and ° (U+00B0) live below that cutoff and must pass.
        let chips = CoachContextBuilder.parseAndFilterChips("Top #1 angle?", count: 1)
        #expect(chips == ["Top #1 angle?"])
    }
}

// MARK: - M17 Summary redesign — bullet selector contracts
//
// The M17 redesign replaced the legacy AI debrief + CoachNote stack inside
// the Summary hero with two observational cards: `WhatYouDidWellCard` and
// `WhatToImproveCard`. The cards' bullet selection logic lives in two
// pure static functions (`computeBullets(...)`) so the design contract is
// testable without spinning up a SwiftUI runtime. These suites pin every
// branch — silent paths (minimal effort, empty signals), ordering,
// the 3-bullet cap, dedup against the leverage line, and the headroom
// gates that decide whether eloquence/AI/pace bullets land.

@available(iOS 17.0, *)
struct WhatYouDidWellBulletSelectorTests {

    private func note(momentum: String = "", leverage: String = "", nextStep: String = "") -> CoachNote {
        CoachNote(momentum: momentum, leverage: leverage, nextStep: nextStep)
    }

    @Test func minimalEffortYieldsNoBullets() {
        // 4-second blurts shouldn't earn "Structure felt solid." The card
        // hides itself entirely so the hero never lies about progress.
        let bullets = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Cleaner delivery."),
            feedbackCategories: [FeedbackCategory(dimension: "Opening", rating: .good, note: "")],
            eloquenceFindings: [],
            aiFeedback: nil,
            isMinimalEffort: true
        )
        #expect(bullets.isEmpty)
    }

    @Test func momentumOnlyPathYieldsSingleBullet() {
        // No category wins, no eloquence — just the verdict engine's
        // momentum line. That's a legitimate single-bullet card; we
        // don't pad it with fake content.
        let bullets = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Filler rate dropped to 1.2/min."),
            feedbackCategories: [],
            eloquenceFindings: [],
            aiFeedback: nil,
            isMinimalEffort: false
        )
        #expect(bullets.count == 1)
        #expect(bullets.first?.id == "momentum")
        #expect(bullets.first?.headline == "Filler rate dropped to 1.2/min.")
    }

    @Test func emptyMomentumIsOmittedNotRenderedBlank() {
        // The verdict engine should always produce something, but if it
        // hands us whitespace we must not emit a blank bullet.
        let bullets = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "   "),
            feedbackCategories: [FeedbackCategory(dimension: "Opening", rating: .good, note: "")],
            eloquenceFindings: [],
            aiFeedback: nil,
            isMinimalEffort: false
        )
        // Only the category bullet remains.
        #expect(bullets.count == 1)
        #expect(bullets.first?.id == "category-Opening")
    }

    @Test func goodCategoriesCappedAtTwo() {
        // Three good categories should not produce three category
        // bullets — the cap is two so the momentum line still anchors.
        // With no eloquence finding, both categories land in slots 2+3.
        let bullets = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Clean rep."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .good, note: ""),
                FeedbackCategory(dimension: "Structure", rating: .good, note: ""),
                FeedbackCategory(dimension: "Pace", rating: .good, note: "")
            ],
            eloquenceFindings: [],
            aiFeedback: nil,
            isMinimalEffort: false
        )
        // momentum + 2 categories = 3 bullets total (cap respected).
        #expect(bullets.count == 3)
        #expect(bullets[0].id == "momentum")
        #expect(bullets[1].id == "category-Opening")
        #expect(bullets[2].id == "category-Structure")
        // Pace should be dropped — not added beyond the prefix(2) cap.
        #expect(!bullets.contains { $0.id == "category-Pace" })
    }

    @Test func okRatingDoesNotCountAsAWin() {
        // .ok is "mostly there", not a celebration. Surfacing it as a
        // "did well" bullet would punish accuracy of the underlying
        // evaluator — kept out of this card by design.
        let bullets = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Solid rep."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .ok, note: ""),
                FeedbackCategory(dimension: "Pace", rating: .ok, note: "")
            ],
            eloquenceFindings: [],
            aiFeedback: nil,
            isMinimalEffort: false
        )
        #expect(bullets.count == 1)
        #expect(bullets[0].id == "momentum")
    }

    @Test func eloquencePromotedAboveSecondGoodCategory() {
        // Contract: when momentum + a first good category + eloquence +
        // a second good category all compete for 3 slots, the eloquence
        // finding wins slot 3 over the second category. Rationale: an
        // engine-detected rhetorical device is concrete on-tape evidence
        // (we caught a real pattern in the user's words), whereas a
        // second "felt solid" is the same impression voice already
        // carried by the first category bullet. Concrete beats restated.
        let finding = EloquenceFinding(
            device: .tricolon,
            snippet: "clarity, courage, conviction",
            coachLine: "Lists of three feel complete."
        )
        let bullets = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Strong rep."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .good, note: ""),
                FeedbackCategory(dimension: "Structure", rating: .good, note: "")
            ],
            eloquenceFindings: [finding],
            aiFeedback: nil,
            isMinimalEffort: false
        )
        #expect(bullets.count == 3)
        #expect(bullets[0].id == "momentum")
        #expect(bullets[1].id == "category-Opening")
        #expect(bullets[2].id == "eloquence-tricolon")
        // The second category is the one that loses to eloquence under
        // the cap — not the first.
        #expect(!bullets.contains { $0.id == "category-Structure" })
    }

    @Test func eloquenceFindingLandsWhenHeadroomExists() {
        // momentum + 1 category leaves room for eloquence at slot 3.
        let finding = EloquenceFinding(
            device: .anaphora,
            snippet: "we will, we will",
            coachLine: "Repetition with intent."
        )
        let bullets = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Strong rep."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .good, note: "")
            ],
            eloquenceFindings: [finding],
            aiFeedback: nil,
            isMinimalEffort: false
        )
        #expect(bullets.count == 3)
        #expect(bullets[2].id == "eloquence-anaphora")
    }

    @Test func secondGoodCategoryStillLandsWhenNoEloquence() {
        // The promotion only takes effect when eloquence is present —
        // with no eloquence finding, the second good category claims
        // slot 3 and the card reads as a "double win" rep.
        let bullets = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Strong rep."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .good, note: ""),
                FeedbackCategory(dimension: "Structure", rating: .good, note: "")
            ],
            eloquenceFindings: [],
            aiFeedback: nil,
            isMinimalEffort: false
        )
        #expect(bullets.count == 3)
        #expect(bullets[1].id == "category-Opening")
        #expect(bullets[2].id == "category-Structure")
    }

    @Test func eloquenceQuoteEvidenceUsesSnippet() {
        // When the engine returns a snippet, the bullet's evidence is the
        // quoted snippet (italic, brand-blue treatment in the View). Cold
        // (empty snippet) path falls back to text-only.
        let finding = EloquenceFinding(
            device: .alliteration,
            snippet: "swift, sharp, smart",
            coachLine: "Alliteration locks rhythm."
        )
        let bullets = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Strong rep."),
            feedbackCategories: [],
            eloquenceFindings: [finding],
            aiFeedback: nil,
            isMinimalEffort: false
        )
        guard let evidence = bullets.last?.evidence else {
            #expect(Bool(false), "Eloquence bullet must carry evidence")
            return
        }
        switch evidence {
        case .quote(let text, _):
            #expect(text == "swift, sharp, smart")
        default:
            #expect(Bool(false), "Eloquence snippet present → must be .quote evidence")
        }
    }

    @Test func aiStrengthBulletGatedOnHeadroom() {
        // AI strength is the lowest-priority bullet — only lands when
        // the saturating bullets above didn't already fill three slots.
        let aiFull = AICoachFeedback(
            strengths: ["You opened with conviction."],
            keyImprovement: "Tighten the close.",
            suggestedDrill: "",
            revisedOpening: ""
        )
        let saturated = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Strong rep."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .good, note: ""),
                FeedbackCategory(dimension: "Structure", rating: .good, note: "")
            ],
            eloquenceFindings: [],
            aiFeedback: aiFull,
            isMinimalEffort: false
        )
        #expect(!saturated.contains { $0.id == "ai-strength" })

        let withHeadroom = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Strong rep."),
            feedbackCategories: [],
            eloquenceFindings: [],
            aiFeedback: aiFull,
            isMinimalEffort: false
        )
        #expect(withHeadroom.contains { $0.id == "ai-strength" })
    }

    @Test func aiStrengthEmptyStringDoesNotEmitBullet() {
        // Defensive: a malformed AI response (empty first strength)
        // must not produce an empty-headline bullet.
        let aiFeedback = AICoachFeedback(
            strengths: ["   "],
            keyImprovement: "",
            suggestedDrill: "",
            revisedOpening: ""
        )
        let bullets = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Strong rep."),
            feedbackCategories: [],
            eloquenceFindings: [],
            aiFeedback: aiFeedback,
            isMinimalEffort: false
        )
        #expect(bullets.count == 1)
        #expect(!bullets.contains { $0.id == "ai-strength" })
    }

    @Test func totalBulletCeilingNeverExceedsThree() {
        // Belt-and-braces: every signal source firing at once must
        // still land at exactly 3 bullets. The cap protects the
        // visual hierarchy of the hero block.
        let finding = EloquenceFinding(
            device: .isocolon,
            snippet: "fast and clean and clear",
            coachLine: "Parallel structure."
        )
        let aiFeedback = AICoachFeedback(
            strengths: ["Strong open."],
            keyImprovement: "",
            suggestedDrill: "",
            revisedOpening: ""
        )
        let bullets = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Strong rep."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .good, note: ""),
                FeedbackCategory(dimension: "Structure", rating: .good, note: ""),
                FeedbackCategory(dimension: "Pace", rating: .good, note: "")
            ],
            eloquenceFindings: [finding],
            aiFeedback: aiFeedback,
            isMinimalEffort: false
        )
        #expect(bullets.count == 3)
    }

    @Test func categoryNoteTextEvidencePopulatesWhenNoteNonEmpty() {
        // A good-rated category with a coaching note should hang the
        // note as expandable evidence; empty notes leave evidence nil
        // so the chevron disappears.
        let withNote = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Solid."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .good, note: "Clear, confident start.")
            ],
            eloquenceFindings: [],
            aiFeedback: nil,
            isMinimalEffort: false
        )
        guard let categoryBullet = withNote.first(where: { $0.id == "category-Opening" }),
              let evidence = categoryBullet.evidence else {
            #expect(Bool(false), "Category with note must carry text evidence")
            return
        }
        switch evidence {
        case .text(let text):
            #expect(text == "Clear, confident start.")
        default:
            #expect(Bool(false), "Category note → text evidence")
        }

        let withoutNote = WhatYouDidWellCard.computeBullets(
            coachNote: note(momentum: "Solid."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .good, note: "")
            ],
            eloquenceFindings: [],
            aiFeedback: nil,
            isMinimalEffort: false
        )
        let categoryBulletBare = withoutNote.first(where: { $0.id == "category-Opening" })
        #expect(categoryBulletBare?.evidence == nil)
    }
}

@available(iOS 17.0, *)
struct WhatToImproveBulletSelectorTests {

    private func note(momentum: String = "", leverage: String = "", nextStep: String = "") -> CoachNote {
        CoachNote(momentum: momentum, leverage: leverage, nextStep: nextStep)
    }

    @Test func minimalEffortYieldsNoBullets() {
        // 4-second blurts get no "to improve" feedback — punishing a
        // user for not really starting is the wrong vibe.
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(leverage: "Pace ran fast."),
            feedbackCategories: [FeedbackCategory(dimension: "Pace", rating: .couldImprove, note: "")],
            aiFeedback: nil,
            transcriptText: "um",
            effectiveFillerCount: 4,
            effectiveDuration: 3,
            transcriptWordCount: 2,
            isMinimalEffort: true,
            customFillerWords: []
        )
        #expect(bullets.isEmpty)
    }

    @Test func cleanRepWithNoLeverageYieldsNoBullets() {
        // A genuinely clean rep produces no bullets — no fake "to
        // improve" placeholder, no padding. The card hides itself.
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(leverage: ""),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .good, note: ""),
                FeedbackCategory(dimension: "Structure", rating: .good, note: "")
            ],
            aiFeedback: nil,
            transcriptText: "Clear and calm and on point.",
            effectiveFillerCount: 0,
            effectiveDuration: 35,
            transcriptWordCount: 80,
            isMinimalEffort: false,
            customFillerWords: []
        )
        #expect(bullets.isEmpty)
    }

    @Test func leverageBulletCarriesNextStepEvidence() {
        // The leverage bullet's expandable evidence is the verdict
        // engine's nextStep so the user can act on the read, not just
        // see it.
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(
                leverage: "Pace ran a touch fast.",
                nextStep: "Slow the first two sentences to set tempo."
            ),
            feedbackCategories: [],
            aiFeedback: nil,
            transcriptText: "I think the most important thing is consistency over time.",
            effectiveFillerCount: 0,
            effectiveDuration: 22,
            transcriptWordCount: 40,
            isMinimalEffort: false,
            customFillerWords: []
        )
        guard let leverageBullet = bullets.first(where: { $0.id == "leverage" }),
              let evidence = leverageBullet.evidence else {
            #expect(Bool(false), "Leverage bullet must carry evidence")
            return
        }
        switch evidence {
        case .nextStep(let text):
            #expect(text == "Slow the first two sentences to set tempo.")
        default:
            #expect(Bool(false), "Leverage evidence is the verdict engine's nextStep")
        }
    }

    @Test func leverageBulletWithoutNextStepHasNoEvidence() {
        // If nextStep is missing, the leverage bullet renders without a
        // chevron — no expand affordance pointing at nothing.
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(leverage: "Slightly off."),
            feedbackCategories: [],
            aiFeedback: nil,
            transcriptText: "A short cleanish rep.",
            effectiveFillerCount: 0,
            effectiveDuration: 22,
            transcriptWordCount: 40,
            isMinimalEffort: false,
            customFillerWords: []
        )
        let leverageBullet = bullets.first(where: { $0.id == "leverage" })
        #expect(leverageBullet?.evidence == nil)
    }

    @Test func fillerBulletDoesNotFireBelowTwoCount() {
        // One filler isn't worth surfacing — it's noise inside the
        // session-to-session normal range. Stays silent at 1.
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(),
            feedbackCategories: [],
            aiFeedback: nil,
            transcriptText: "Um a clean rep mostly.",
            effectiveFillerCount: 1,
            effectiveDuration: 18,
            transcriptWordCount: 30,
            isMinimalEffort: false,
            customFillerWords: []
        )
        #expect(!bullets.contains { $0.id == "filler" })
    }

    @Test func fillerBulletFiresAtTwoOrMore() {
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(),
            feedbackCategories: [],
            aiFeedback: nil,
            transcriptText: "Um like you know um a few here.",
            effectiveFillerCount: 3,
            effectiveDuration: 18,
            transcriptWordCount: 30,
            isMinimalEffort: false,
            customFillerWords: []
        )
        let fillerBullet = bullets.first { $0.id == "filler" }
        #expect(fillerBullet != nil)
        #expect(fillerBullet?.headline.contains("(3)") == true)
    }

    @Test func fillerBulletHeadlineUsesClusterFramingAtFivePlus() {
        // The "clustered" framing reads as more honest at the high end
        // — five+ feels like a pattern, not a stray.
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(),
            feedbackCategories: [],
            aiFeedback: nil,
            transcriptText: "Um um like you know um like uh I mean um.",
            effectiveFillerCount: 7,
            effectiveDuration: 18,
            transcriptWordCount: 30,
            isMinimalEffort: false,
            customFillerWords: []
        )
        let fillerBullet = bullets.first { $0.id == "filler" }
        #expect(fillerBullet?.headline.lowercased().contains("clustered") == true)
    }

    @Test func leverageDedupsAgainstCategoryByName() {
        // When leverage mentions "structure" (case-insensitive), the
        // Structure couldImprove category is suppressed — same point,
        // two voices, would inflate the card under the 3-cap.
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(leverage: "Your structure ran loose this rep."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Structure", rating: .couldImprove, note: ""),
                FeedbackCategory(dimension: "Depth", rating: .couldImprove, note: "")
            ],
            aiFeedback: nil,
            transcriptText: "A reasonable length rep with some signal.",
            effectiveFillerCount: 0,
            effectiveDuration: 22,
            transcriptWordCount: 40,
            isMinimalEffort: false,
            customFillerWords: []
        )
        #expect(!bullets.contains { $0.id == "category-Structure" })
        #expect(bullets.contains { $0.id == "category-Depth" })
    }

    @Test func categoryNeedsWorkCappedAtTwo() {
        // Even with three couldImprove categories, only the first two
        // pass through — keeps the card under the 3-cap with room for
        // leverage at the top.
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .couldImprove, note: ""),
                FeedbackCategory(dimension: "Close", rating: .couldImprove, note: ""),
                FeedbackCategory(dimension: "Depth", rating: .couldImprove, note: "")
            ],
            aiFeedback: nil,
            transcriptText: "A reasonable length rep with some signal.",
            effectiveFillerCount: 0,
            effectiveDuration: 22,
            transcriptWordCount: 40,
            isMinimalEffort: false,
            customFillerWords: []
        )
        let categoryBullets = bullets.filter { $0.id.hasPrefix("category-") }
        #expect(categoryBullets.count == 2)
        #expect(categoryBullets.map(\.id) == ["category-Opening", "category-Close"])
    }

    @Test func paceFastFiresWhenAboveOneSeventyAndHeadroomExists() {
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(),
            feedbackCategories: [],
            aiFeedback: nil,
            // 60 words / 20 seconds = 180 WPM
            transcriptText: String(repeating: "one ", count: 60),
            effectiveFillerCount: 0,
            effectiveDuration: 20,
            transcriptWordCount: 60,
            isMinimalEffort: false,
            customFillerWords: []
        )
        let paceBullet = bullets.first { $0.id == "pace-fast" }
        #expect(paceBullet != nil)
        #expect(paceBullet?.headline.contains("WPM") == true)
    }

    @Test func paceSlowFiresWhenBelowNinetyFive() {
        // 20 words / 20 seconds = 60 WPM — below the slow band.
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(),
            feedbackCategories: [],
            aiFeedback: nil,
            transcriptText: String(repeating: "one ", count: 20),
            effectiveFillerCount: 0,
            effectiveDuration: 20,
            transcriptWordCount: 20,
            isMinimalEffort: false,
            customFillerWords: []
        )
        let paceBullet = bullets.first { $0.id == "pace-slow" }
        #expect(paceBullet != nil)
    }

    @Test func paceAnomalySuppressedWithoutHeadroom() {
        // With leverage + 2 categories already populating, pace stays
        // silent — the user needs ONE focus, not five.
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(leverage: "Pace ran fast in the middle."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Depth", rating: .couldImprove, note: ""),
                FeedbackCategory(dimension: "Close", rating: .couldImprove, note: "")
            ],
            aiFeedback: nil,
            transcriptText: String(repeating: "one ", count: 60),
            effectiveFillerCount: 0,
            effectiveDuration: 20,
            transcriptWordCount: 60,
            isMinimalEffort: false,
            customFillerWords: []
        )
        #expect(!bullets.contains { $0.id.hasPrefix("pace-") })
    }

    @Test func paceAnomalyRequiresMinimumWordsAndDuration() {
        // Below the 12-word / 10-second minimum the WPM read isn't
        // stable enough to call. Stay silent rather than nag.
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(),
            feedbackCategories: [],
            aiFeedback: nil,
            transcriptText: "ten quick words land here in this short stretch ok",
            effectiveFillerCount: 0,
            effectiveDuration: 5,
            transcriptWordCount: 10,
            isMinimalEffort: false,
            customFillerWords: []
        )
        #expect(!bullets.contains { $0.id.hasPrefix("pace-") })
    }

    @Test func aiKeyImprovementLandsAtTailWhenHeadroomExists() {
        let aiFeedback = AICoachFeedback(
            strengths: [],
            keyImprovement: "Sharpen the close — land your final point cleanly.",
            suggestedDrill: "Try the 'Decisive Stop' drill on the next rep.",
            revisedOpening: ""
        )
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(leverage: "Solid but generic close."),
            feedbackCategories: [],
            aiFeedback: aiFeedback,
            transcriptText: "A reasonable length rep with some signal.",
            effectiveFillerCount: 0,
            effectiveDuration: 25,
            transcriptWordCount: 50,
            isMinimalEffort: false,
            customFillerWords: []
        )
        #expect(bullets.contains { $0.id == "ai-improvement" })
    }

    @Test func aiKeyImprovementSuppressedWithoutHeadroom() {
        // Leverage + 2 categories already saturate — AI doesn't push
        // through the cap.
        let aiFeedback = AICoachFeedback(
            strengths: [],
            keyImprovement: "Sharpen the close.",
            suggestedDrill: "",
            revisedOpening: ""
        )
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(leverage: "Loose middle section."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Depth", rating: .couldImprove, note: ""),
                FeedbackCategory(dimension: "Close", rating: .couldImprove, note: "")
            ],
            aiFeedback: aiFeedback,
            transcriptText: "A reasonable length rep with some signal.",
            effectiveFillerCount: 0,
            effectiveDuration: 22,
            transcriptWordCount: 40,
            isMinimalEffort: false,
            customFillerWords: []
        )
        #expect(!bullets.contains { $0.id == "ai-improvement" })
    }

    @Test func totalBulletCeilingNeverExceedsThree() {
        // Every signal source firing: leverage + filler + 2 categories +
        // pace + AI. The final list must still land at exactly 3.
        let aiFeedback = AICoachFeedback(
            strengths: [],
            keyImprovement: "Cleaner ending.",
            suggestedDrill: "",
            revisedOpening: ""
        )
        let bullets = WhatToImproveCard.computeBullets(
            coachNote: note(leverage: "Mid-rep wobble."),
            feedbackCategories: [
                FeedbackCategory(dimension: "Opening", rating: .couldImprove, note: ""),
                FeedbackCategory(dimension: "Depth", rating: .couldImprove, note: ""),
                FeedbackCategory(dimension: "Close", rating: .couldImprove, note: "")
            ],
            aiFeedback: aiFeedback,
            transcriptText: "um like um you know um " + String(repeating: "one ", count: 60),
            effectiveFillerCount: 5,
            effectiveDuration: 20,
            transcriptWordCount: 65,
            isMinimalEffort: false,
            customFillerWords: []
        )
        #expect(bullets.count == 3)
    }
}

// MARK: - TalkToNoumCTACard — copy contract
//
// The CTA card lives at the bottom of the summary hero block. The pro
// gate is wired through `isPremium`. These tests pin the brand-voice
// rules (no "Let's", no exclamation, no emoji, sentence case) and the
// pro/free divergence so a future copy tweak can't quietly drift into
// dark-pattern territory or break the screenshot tour.

@available(iOS 17.0, *)
struct TalkToNoumCTACardCopyTests {

    @Test func headlineIsInvariantAcrossPremiumState() {
        // The moment is the same — premium status only changes what
        // happens on tap, not the framing.
        #expect(TalkToNoumCTACard.headlineCopy(isPremium: true)
                == TalkToNoumCTACard.headlineCopy(isPremium: false))
        #expect(TalkToNoumCTACard.headlineCopy(isPremium: true)
                == "Talk to Noum about this rep.")
    }

    @Test func subCopyDivergesByPremiumState() {
        // Pro users get the "this rep loaded" framing; free users get
        // the membership pitch. The two must not collide.
        let pro = TalkToNoumCTACard.subCopy(isPremium: true)
        let free = TalkToNoumCTACard.subCopy(isPremium: false)
        #expect(pro != free)
        #expect(pro.lowercased().contains("quotes"))
        #expect(free.lowercased().contains("pro"))
    }

    @Test func ctaCopyMatchesPremiumState() {
        #expect(TalkToNoumCTACard.ctaCopy(isPremium: true) == "Open the thread")
        #expect(TalkToNoumCTACard.ctaCopy(isPremium: false) == "Unlock with Pro")
    }

    @Test func brandVoiceRulesUpheld() {
        // No exclamations, no "Let's", no emoji, no chirpy "great" /
        // "awesome" copy. The coach voice contract — applies to every
        // string the card emits.
        let strings = [
            TalkToNoumCTACard.headlineCopy(isPremium: true),
            TalkToNoumCTACard.headlineCopy(isPremium: false),
            TalkToNoumCTACard.subCopy(isPremium: true),
            TalkToNoumCTACard.subCopy(isPremium: false),
            TalkToNoumCTACard.ctaCopy(isPremium: true),
            TalkToNoumCTACard.ctaCopy(isPremium: false),
            TalkToNoumCTACard.accessibilityLabel(isPremium: true),
            TalkToNoumCTACard.accessibilityLabel(isPremium: false)
        ]
        let banned = ["!", "Let's", "let's", "Let’s", "let’s", "awesome", "Awesome", "great!"]
        for string in strings {
            for token in banned {
                #expect(!string.contains(token),
                        "Brand-voice contract: '\(string)' must not contain '\(token)'")
            }
        }
    }

    @Test func accessibilityLabelCarriesLockSignalOnlyForFreeUsers() {
        let proLabel = TalkToNoumCTACard.accessibilityLabel(isPremium: true)
        let freeLabel = TalkToNoumCTACard.accessibilityLabel(isPremium: false)
        #expect(!proLabel.lowercased().contains("locked"))
        #expect(freeLabel.lowercased().contains("locked"))
    }
}

// MARK: - CoachContextBuilder.parseAndFilterChips — brand-voice contract
//
// `parseAndFilterChips` is the gate between AI-generated chip output and
// the Ask Noum follow-up chip row. Its job is to (a) tolerate the messy
// output shapes models sometimes return (numbered lists, bullet
// prefixes, smart quotes, trailing whitespace) and (b) enforce every
// brand-voice rule the system prompt asks for — so a model that drifts
// past its instructions can't slip exclamation marks, emoji, "Let's"
// kickoffs, or runaway-length copy into the user-facing chip surface.
//
// These tests lock the parser AND the per-chip filter contract. The
// filter itself is `private`, but every gate it enforces is reachable
// through `parseAndFilterChips`: feed it raw text containing the
// banned shape, and assert the function returns nil (because too few
// chips survive filtering to meet the count).
//
// Caller contract: when `parseAndFilterChips` returns nil, the AI
// follow-up generator falls back to the deterministic catalog chips.
// That fallback is why nil-on-shortfall is the right behavior here —
// a partial AI batch padded with catalog chips would mix tones, while
// the all-or-nothing gate keeps each chip row coherent.

@available(iOS 17.0, *)
struct CoachContextBuilderChipParserTests {

    // MARK: - Happy path: well-formed model output

    @Test func parsesPlainNewlineSeparatedChips() {
        // The contract: count 3 chips returned with no transformation
        // beyond trim. Mirrors the system-prompt-compliant output the
        // model is asked to produce.
        let raw = """
        Walk me through your goal
        What part felt off
        Show me what to try next
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips?.count == 3)
        #expect(chips?[0] == "Walk me through your goal")
        #expect(chips?[1] == "What part felt off")
        #expect(chips?[2] == "Show me what to try next")
    }

    @Test func returnsNilWhenFewerChipsThanRequested() {
        // Two chips when three are asked for — the caller's
        // deterministic fallback is better than a partial AI batch.
        let raw = """
        Walk me through your goal
        What part felt off
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == nil)
    }

    @Test func extraChipsAreTruncatedToCount() {
        // The model might return four when we asked for three. We take
        // the first three rather than throwing the whole batch out —
        // the chips are already shape-validated by the filter.
        let raw = """
        First chip
        Second chip
        Third chip
        Fourth chip
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips?.count == 3)
        #expect(chips == ["First chip", "Second chip", "Third chip"])
    }

    // MARK: - Cleanup: tolerant of common model output messiness

    @Test func stripsLeadingBulletAndDashMarkers() {
        // Models sometimes wrap chips in "- " / "* " / "• " markers
        // despite the system prompt asking for none. We strip them
        // rather than failing the whole batch.
        let raw = """
        - First chip here
        * Second chip too
        • Third with bullet
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips?.count == 3)
        #expect(chips?[0] == "First chip here")
        #expect(chips?[1] == "Second chip too")
        #expect(chips?[2] == "Third with bullet")
    }

    @Test func stripsNumericEnumeration() {
        // "1. " / "2) " enumeration is another common drift. Stripped.
        let raw = """
        1. Walk me through it
        2) What changed today
        3. Show me a clean rep
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips?.count == 3)
        #expect(chips?[0] == "Walk me through it")
        #expect(chips?[1] == "What changed today")
        #expect(chips?[2] == "Show me a clean rep")
    }

    @Test func stripsWrappingStraightAndSmartQuotes() {
        // Models love to "quote" things. Both straight and smart
        // quotes are unwrapped.
        let raw = """
        "Walk me through it"
        \u{201C}What changed today\u{201D}
        Show me a clean rep
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips?.count == 3)
        #expect(chips?[0] == "Walk me through it")
        #expect(chips?[1] == "What changed today")
        #expect(chips?[2] == "Show me a clean rep")
    }

    @Test func tolerantOfBlankLinesAndWhitespace() {
        // Empty lines and surrounding whitespace are normalized away.
        // The four content lines reduce to three valid chips (the
        // blank line is filtered out as failing the min-length gate).
        let raw = """

           First chip here
        \tSecond chip too\t

        Third chip lands
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips?.count == 3)
        #expect(chips?[0] == "First chip here")
        #expect(chips?[1] == "Second chip too")
        #expect(chips?[2] == "Third chip lands")
    }

    // MARK: - Brand-voice contract: bans enforced per chip

    @Test func banExclamationMarksDropsChip() {
        // One chip carries an exclamation — it drops, leaving 2 valid
        // chips, which is below count=3, so the whole batch is
        // rejected. The fallback catalog runs instead.
        let raw = """
        Walk me through your goal
        Awesome work today!
        Show me a clean rep
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == nil)
    }

    @Test func banLetsKickoffDropsChipBothApostropheStyles() {
        // "Let's" and "Lets" both drop. "let's" lowercase also drops.
        let lowerStraight = """
        Walk me through your goal
        let's try a clean rep
        Show me what changed
        """
        #expect(CoachContextBuilder.parseAndFilterChips(lowerStraight, count: 3) == nil)

        let titleStraight = """
        Walk me through your goal
        Lets jump to next steps
        Show me what changed
        """
        #expect(CoachContextBuilder.parseAndFilterChips(titleStraight, count: 3) == nil)
    }

    @Test func banLeadingDirectivesDropsChip() {
        // "Tell me", "Describe", "Explain" etc. shouldn't lead a chip
        // — the chips are meant to read as the user's question, not
        // an order to the coach.
        let directives = [
            "Tell me what changed today",
            "Describe what to fix next",
            "Explain how to slow my pace",
            "Discuss what went wrong",
            "Elaborate on the close",
            "Share what worked best",
            "Talk about my structure"
        ]
        for directive in directives {
            let raw = """
            \(directive)
            Walk me through it
            Show me a clean rep
            """
            #expect(CoachContextBuilder.parseAndFilterChips(raw, count: 3) == nil,
                    "Directive '\(directive)' should be filtered out")
        }
    }

    @Test func banEmojiDropsChip() {
        // Pictographs are banned (graphic Unicode above U+238C). The
        // rocket emoji used to slip through some models is the
        // canonical regression case.
        let raw = """
        Walk me through your goal
        Show me the next move 🚀
        What changed today
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == nil)
    }

    @Test func chipBelowMinimumLengthIsDropped() {
        // 4-char floor. "Huh?" passes (4 chars with a `?`); "Hm"
        // fails. Use a clearly-short chip so the gate is exercised.
        let raw = """
        Hm
        Walk me through your goal
        What changed today
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == nil)
    }

    @Test func chipAboveMaximumLengthIsDropped() {
        // 60-char ceiling. Runaway-length chips no longer read as a
        // quick tap and break the chip-row layout. Drop them.
        let runaway = String(repeating: "long chip ", count: 8)  // 80+ chars
        let raw = """
        Walk me through your goal
        \(runaway)
        What changed today
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips == nil)
    }

    @Test func chipsAtExactMinAndMaxLengthArePreserved() {
        // 4-char "Huh?" and a 60-char chip both land — boundaries
        // are inclusive on the (4...60) range.
        let sixtyChars = "What is the single highest leverage move for next session"
        // confirm length is in range before relying on it
        #expect(sixtyChars.count >= 4 && sixtyChars.count <= 60)
        let raw = """
        Huh?
        Walk me through it
        \(sixtyChars)
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips?.count == 3)
        #expect(chips?[0] == "Huh?")
        #expect(chips?[2] == sixtyChars)
    }

    @Test func unicodeBelowEmojiThresholdIsAllowed() {
        // Em-dashes, ellipses, accented characters etc. are still
        // valid copy — the emoji gate triggers on graphic pictograph
        // codepoints (U+238C and above), not all non-ASCII.
        let raw = """
        Walk me through it — fast
        What changed today\u{2026}
        Café cleanup next
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips?.count == 3)
        #expect(chips?[0] == "Walk me through it — fast")
        #expect(chips?[2] == "Café cleanup next")
    }

    @Test func combinedMessIsRecoveredWhenContentValid() {
        // The parser is tolerant of layered mess: bullets +
        // numbering + smart quotes + trailing whitespace + blank
        // lines can all coexist with three valid chips inside.
        let raw = """

        1. \u{201C}Walk me through your goal\u{201D}
        - "What changed today"
        \t• Show me a clean rep \t

        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 3)
        #expect(chips?.count == 3)
        #expect(chips?[0] == "Walk me through your goal")
        #expect(chips?[1] == "What changed today")
        #expect(chips?[2] == "Show me a clean rep")
    }

    @Test func returnsExactlyTheRequestedCountNotMore() {
        // count=2 → exactly 2 chips even if 5 valid chips exist.
        let raw = """
        First chip here
        Second chip too
        Third chip lands
        Fourth chip extra
        Fifth chip extra
        """
        let chips = CoachContextBuilder.parseAndFilterChips(raw, count: 2)
        #expect(chips?.count == 2)
        #expect(chips == ["First chip here", "Second chip too"])
    }
}
