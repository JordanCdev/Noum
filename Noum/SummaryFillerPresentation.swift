import Foundation

/// One quantity-qualified filler read for every Summary presentation surface.
/// It accepts the detector-owned count and never reclassifies transcript text.
struct SummaryFillerPresentation: Equatable {
    enum Tone: Equatable {
        case insufficient
        case positive
        case caution
        case warning
    }

    let fillerCount: Int
    let duration: TimeInterval
    let currentRatePerMinute: Double?
    let comparison: FillerRateComparison?
    let tone: Tone

    var meaningfulDeltaRatePerMinute: Double? {
        comparison?.meaningfulDeltaRatePerMinute
    }

    var derivedInsight: String? {
        guard let comparison else { return nil }
        switch comparison.direction {
        case .improving:
            return "Your filler rate improved against your recent qualified average."
        case .steady:
            return nil
        case .worsening:
            return "Your filler rate rose above your recent qualified average. Try a slower opening."
        }
    }

    var accessibilityLabel: String {
        let seconds = max(0, Int(duration.rounded(.down)))
        let countLabel = "\(fillerCount) filler\(fillerCount == 1 ? "" : "s") across \(seconds) seconds."
        guard let currentRatePerMinute else {
            return "\(countLabel) Not enough speech for a fair filler-rate comparison."
        }

        let rateLabel = "Filler rate \(Self.formatRate(currentRatePerMinute)) per minute."
        guard let comparison else {
            return "\(countLabel) \(rateLabel) No recent qualified average yet."
        }

        switch comparison.direction {
        case .improving:
            return "\(countLabel) \(rateLabel) \(Self.formatRate(abs(comparison.deltaRatePerMinute))) per minute lower than the recent qualified average."
        case .steady:
            return "\(countLabel) \(rateLabel) In line with the recent qualified average."
        case .worsening:
            return "\(countLabel) \(rateLabel) \(Self.formatRate(abs(comparison.deltaRatePerMinute))) per minute higher than the recent qualified average."
        }
    }

    static func make(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        transcriptConfidence: Double? = nil,
        previousSessions: [PracticeSession]
    ) -> SummaryFillerPresentation {
        let burden = FillerBurden.quantityQualified(
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            transcriptConfidence: transcriptConfidence
        )
        return assemble(
            fillerCount: fillerCount,
            duration: duration,
            currentRate: burden?.ratePerMinute,
            previousSessions: previousSessions
        )
    }

    /// Summary's live projection requires the exact persisted row so current
    /// schema and non-fixture provenance are checked along with quantity and
    /// confidence. Raw presentation facts remain visible when resolution
    /// fails, but they cannot become a rate, trend, or tone judgment.
    static func make(
        metricSession: PracticeSession?,
        fallbackFillerCount: Int,
        fallbackDuration: TimeInterval,
        previousSessions: [PracticeSession]
    ) -> SummaryFillerPresentation {
        guard let metricSession else {
            return assemble(
                fillerCount: fallbackFillerCount,
                duration: fallbackDuration,
                currentRate: nil,
                previousSessions: previousSessions
            )
        }

        return assemble(
            fillerCount: metricSession.fillerWordCount,
            duration: metricSession.duration,
            currentRate: FillerBurden.quantityQualified(metricSession)?.ratePerMinute,
            previousSessions: previousSessions
        )
    }

    private static func assemble(
        fillerCount: Int,
        duration: TimeInterval,
        currentRate: Double?,
        previousSessions: [PracticeSession]
    ) -> SummaryFillerPresentation {
        let previousRates = FillerBurden.quantityQualifiedRatesPerMinute(
            in: previousSessions
        )
        let comparison = FillerRateComparison.make(
            currentRatePerMinute: currentRate,
            previousRatesPerMinute: previousRates
        )

        let tone: Tone
        if currentRate == nil {
            tone = .insufficient
        } else if fillerCount == 0 {
            tone = .positive
        } else if let comparison {
            switch comparison.direction {
            case .improving, .steady:
                tone = .positive
            case .worsening:
                tone = comparison.deltaRatePerMinute < FillerBurden.Threshold.elevated.rawValue
                    ? .caution
                    : .warning
            }
        } else {
            tone = .caution
        }

        return SummaryFillerPresentation(
            fillerCount: fillerCount,
            duration: duration,
            currentRatePerMinute: currentRate,
            comparison: comparison,
            tone: tone
        )
    }

    static func formatRate(_ rate: Double) -> String {
        String(format: "%.1f", rate)
    }
}
