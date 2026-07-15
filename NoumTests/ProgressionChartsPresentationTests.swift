//
//  ProgressionChartsPresentationTests.swift
//  NoumTests
//
//  Contracts for the Review progress graph presentation.
//

import Foundation
import Testing
@testable import Noum

#if canImport(SwiftUI)
import SwiftUI

@MainActor
@Suite("ProgressionCharts presentation")
struct ProgressionChartsPresentationTests {
    typealias Series = ProgressionChartsCard.ChartSeries
    typealias Model = ProgressionChartsCard.ChartPresentationModel
    private let now = Date(timeIntervalSince1970: 2_100_000_000)

    @Test func reviewOnlyRowsCannotUnlockChartGate() {
        let eligible = [
            makeEvidenceSession(words: 20, duration: 30, dayOffset: -2),
            makeEvidenceSession(words: 20, duration: 30, dayOffset: -1),
        ]
        let reviewOnly = [
            makeEvidenceSession(words: 2, duration: 30),
            makeEvidenceSession(words: 20, duration: 2.99),
            makeEvidenceSession(words: 20, duration: .infinity),
            makeEvidenceSession(words: 20, duration: 30, isEvaluationFixture: true),
        ]

        let projected = ReviewDevelopmentChartEvidence.recentScoredSessions(
            in: eligible + reviewOnly,
            now: now
        )

        #expect(projected.map(\.id) == eligible.map(\.id))
        #expect(!ReviewDevelopmentChartEvidence.hasEnoughData(in: eligible + reviewOnly, now: now))
    }

    @Test func threeEligibleRowsUnlockChartWithReviewOnlyHistoryPresent() {
        let eligible = (-3 ... -1).map {
            makeEvidenceSession(words: 20, duration: 30, dayOffset: $0)
        }
        let reviewOnly = makeEvidenceSession(words: 2, duration: 30)

        let projected = ReviewDevelopmentChartEvidence.recentScoredSessions(
            in: eligible + [reviewOnly],
            now: now
        )

        #expect(projected.map(\.id) == eligible.map(\.id))
        #expect(ReviewDevelopmentChartEvidence.hasEnoughData(in: eligible + [reviewOnly], now: now))
    }

    @Test func scoreDomainStaysBoundedAndReadableForFlatData() {
        let domain = Model.paddedDomain(for: [7.0, 7.0, 7.0], series: .score)

        #expect(domain.lowerBound >= 0)
        #expect(domain.upperBound <= 10)
        #expect(domain.upperBound - domain.lowerBound >= Series.score.minimumVisualSpan)
    }

    @Test func scoreDomainNearCeilingStillKeepsReadableSpan() {
        let domain = Model.paddedDomain(for: [9.7, 9.8, 9.9], series: .score)

        #expect(domain.lowerBound >= 0)
        #expect(domain.upperBound <= 10)
        #expect(domain.upperBound - domain.lowerBound >= Series.score.minimumVisualSpan)
    }

    @Test func scoreDomainUsesFullScaleToAvoidFakeVolatility() {
        let domain = Model.paddedDomain(for: [7.0, 7.0, 2.0, 2.0], series: .score)

        #expect(domain.lowerBound == 0)
        #expect(domain.upperBound == 10)
    }

    @Test func emptyDomainUsesTheSeriesFloorAndMinimumSpan() {
        let domain = Model.paddedDomain(for: [], series: .score)

        #expect(domain.lowerBound == 0)
        #expect(domain.upperBound == Series.score.minimumVisualSpan)
    }

    @Test func ordinalDomainPadsFirstAndLatestPointAwayFromEdges() {
        let domain = Model.ordinalDomain(forPointCount: 6)

        #expect(domain.lowerBound < 0)
        #expect(domain.upperBound > 5)
    }

    @Test func axisLabelsStayCompact() {
        #expect(Series.score.formatAxisValue(7.4) == "7")
        #expect(Series.fillerRate.formatAxisValue(1.24) == "1.2/m")
        #expect(Series.pace.formatAxisValue(124.8) == "125")
        #expect(Series.pitch.formatAxisValue(0.42) == "42%")
    }

    @Test func everySeriesHasUserFacingLabelAndIcon() {
        #expect(Series.allCases.count == 5)

        for series in Series.allCases {
            #expect(!series.shortLabel.isEmpty)
            #expect(!series.symbolName.isEmpty)
        }
    }

    @Test func seriesLabelsStayShortEnoughForCompactGrid() {
        for series in Series.allCases {
            #expect(series.shortLabel.count <= 7)
        }
    }

    @Test func lowEvidenceTrendUsesSofterCoachingCopy() {
        let points = makeScorePoints([7.0, 7.0, 2.0, 2.0, 2.0, 2.0])
        let model = Model(series: .score, points: points)

        #expect(model.readTitle == "Baseline forming")
        #expect(model.readBody.contains("not a verdict"))
        #expect(!model.shouldShowTrendLine)
        #expect(model.baselineProgress == .init(current: 6, total: 8, remaining: 2))
        #expect(model.baselineProgress.remainingCopy == "2 more measured reps before Noum calls this a trend.")
        #expect(model.latestFormatted == "2.0")
    }

    @Test func baselineProgressCapsAtDirectionalEvidenceFloor() {
        #expect(Model.baselineProgress(forPointCount: -2) == .init(current: 0, total: 8, remaining: 8))
        #expect(Model.baselineProgress(forPointCount: 1) == .init(current: 1, total: 8, remaining: 7))
        #expect(Model.baselineProgress(forPointCount: 8) == .init(current: 8, total: 8, remaining: 0))
        #expect(Model.baselineProgress(forPointCount: 14) == .init(current: 8, total: 8, remaining: 0))
    }

    @Test func baselineProgressCopyHandlesSingularAndCompleteStates() {
        #expect(Model.baselineProgress(forPointCount: 7).remainingCopy == "1 more measured rep before Noum calls this a trend.")
        #expect(Model.baselineProgress(forPointCount: 8).remainingCopy == "Trend ready. Noum can start reading direction.")
    }

    @Test func baselineProgressPresentationHelpersStayReadable() {
        let forming = Model.baselineProgress(forPointCount: 6)
        let ready = Model.baselineProgress(forPointCount: 8)

        #expect(forming.sampleLabel == "6 of 8")
        #expect(forming.trendStateLabel == "2 left")
        #expect(forming.fraction == 0.75)
        #expect(ready.sampleLabel == "8 of 8")
        #expect(ready.trendStateLabel == "Ready")
        #expect(ready.fraction == 1)
    }

    @Test func enoughEvidenceCanCallDirectionalMovement() {
        let points = makeScorePoints([7.0, 7.0, 6.0, 6.0, 5.0, 5.0, 4.0, 4.0])
        let model = Model(series: .score, points: points)

        #expect(model.readTitle == "Worth a closer look")
        #expect(model.readBody == "Recent score average is down 1.7 over the previous block.")
    }

    @Test func recentLiftCanOutweighFirstToLatestDrop() {
        let points = makeScorePoints([9.0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0, 7.0, 7.0, 7.0, 7.0, 7.0, 7.0, 7.0])
        let model = Model(series: .score, points: points)

        #expect(model.readTitle == "Moving the right way")
        #expect(model.readBody == "Recent score average is up 4.0 over the previous block.")
    }

    @Test func trendSamplesUseRawValuesUntilEvidenceFloor() {
        let points = makeScorePoints([7.0, 2.0, 7.0])
        let model = Model(series: .score, points: points)

        #expect(model.rawSamples == model.trendSamples)
        #expect(!model.shouldShowTrendLine)
    }

    @Test func trendSamplesSmoothNoisyHistoryWithoutDroppingRawDots() {
        let points = makeScorePoints([9.0, 1.0, 9.0, 1.0, 9.0, 1.0, 9.0, 1.0])
        let model = Model(series: .score, points: points)

        #expect(model.shouldShowTrendLine)
        #expect(model.rawSamples.count == 8)
        #expect(model.trendSamples.count == 8)
        #expect(model.rawSamples[3].value == 1.0)
        #expect(model.trendSamples[3].value > model.rawSamples[3].value)
        #expect(model.trendSamples[3].value < model.rawSamples[2].value)
    }

    @Test func movementCopyRemovesRawSignsFromUserFacingText() {
        #expect(Series.score.movementCopy(delta: -1.2) == "Score is down 1.2 from first to latest.")
        #expect(Series.fillerRate.movementCopy(delta: -0.8) == "Fillers are down 0.8/min from first to latest.")
        #expect(!Series.score.movementCopy(delta: -1.2).contains("-"))
        #expect(!Series.fillerRate.movementCopy(delta: 0.8).contains("+"))
    }

    @Test func paceSmallMovementReadsAsFlat() {
        #expect(Series.pace.isFlat(delta: 4.9))
        #expect(!Series.pace.isFlat(delta: 5.1))
    }

    @Test func smallScoreMovementReadsAsHoldingSteady() {
        #expect(Series.score.isFlat(delta: -0.1))
        #expect(Series.score.formatDelta(-0.1) == "Even")
    }

    @Test func paceMovingTowardBandExplainsTheRemainingGap() {
        let points = makePacePoints(Array(repeating: 32, count: 7) + Array(repeating: 56, count: 7))
        let model = Model(series: .pace, points: points)

        #expect(model.readTitle == "Closer, still slow")
        #expect(model.readBody == "Recent pace is up 24 WPM, but still below the 110–150 WPM target band.")
    }

    @Test func paceInsideTargetBandNamesTheWinInsteadOfRawMovement() {
        let points = makePacePoints(Array(repeating: 92, count: 7) + Array(repeating: 126, count: 7))
        let model = Model(series: .pace, points: points)

        #expect(model.readTitle == "In the target band")
        #expect(model.readBody == "Recent pace is inside the 110–150 WPM target band.")
    }

    @Test func paceImprovementUsesTargetBandContext() {
        #expect(Series.pace.isImprovement(delta: 24, recentAverage: 56))
        #expect(!Series.pace.isImprovement(delta: 24, recentAverage: 176))
        #expect(Series.pace.isImprovement(delta: -24, recentAverage: 176))
        #expect(!Series.pace.isImprovement(delta: -24, recentAverage: 56))
        #expect(!Series.pace.isImprovement(delta: 24))
    }

    private func makeScorePoints(_ values: [Double]) -> [ProgressionChartsCard.ChartPoint] {
        values.enumerated().compactMap { offset, value in
            let session = PracticeSession(
                transcript: "eligible score rep",
                fillerWordCount: 0,
                duration: 60,
                date: Date(timeIntervalSince1970: Double(offset)),
                mode: .timed,
                score: Int(value.rounded())
            )
            return ProgressionChartsCard.ChartPoint(session: session)
        }
    }

    private func makeEvidenceSession(
        words: Int,
        duration: TimeInterval,
        dayOffset: Int = 0,
        isEvaluationFixture: Bool = false
    ) -> PracticeSession {
        PracticeSession(
            transcript: Array(repeating: "word", count: words).joined(separator: " "),
            fillerWordCount: 0,
            duration: duration,
            date: Calendar.current.date(byAdding: .day, value: dayOffset, to: now) ?? now,
            mode: .timed,
            score: 8,
            isEvaluationFixture: isEvaluationFixture
        )
    }

    private func makePacePoints(_ values: [Int]) -> [ProgressionChartsCard.ChartPoint] {
        values.enumerated().compactMap { offset, value in
            let transcript = Array(repeating: "word", count: value).joined(separator: " ")
            let session = PracticeSession(
                transcript: transcript,
                fillerWordCount: 0,
                duration: 60,
                date: Date(timeIntervalSince1970: Double(offset)),
                mode: .timed,
                score: 5
            )
            return ProgressionChartsCard.ChartPoint(session: session)
        }
    }
}
#endif
