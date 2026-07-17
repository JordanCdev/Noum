import Foundation

// MARK: - Cached coaching-state snapshot models

struct UserTrajectorySnapshot: Codable, Equatable {
    var generatedAt: Date
    var sessionCount: Int
    var ratedSessionCount: Int
    /// 0...1 evidence coverage for meta-judgement. This is not a quality score;
    /// it is the floor for how strongly the coach may speak.
    var evidenceCoverage: Double
    var recentSessionLines: [String]
    var trendLines: [String]
    var latestRepEvidencePack: LatestRepEvidencePack?
    var coachCaseSummary: CoachCaseSummary?
    var activeInterventionState: ActiveInterventionState?
    /// Present only when the session-history owner can compare the latest rep
    /// with its minimum exact-demand prior set under the current schema.
    var qualifiedLongitudinalTrend: CoachLongitudinalTrendProjection? = nil
}

enum CoachEvidenceReadKind: String, Codable, Sendable, Equatable {
    case latestRepMetrics
    case longitudinalTrend
}

enum CoachMetricKind: String, Codable, Sendable, Equatable, Hashable, CaseIterable {
    case score
    case fillerCount
    case fillerRatePerMinute
    case paceWordsPerMinute
    case durationSeconds
}

struct CoachLatestRepMetricProjection: Codable, Sendable, Equatable {
    let sourceSessionID: UUID
    let comparisonMetricSchemaVersion: Int
    let mode: String
    let score: Int?
    let fillerCount: Int?
    let fillerRatePerMinute: Double?
    let paceWordsPerMinute: Int?
    let durationSeconds: Int
    let transcriptWordCount: Int

    init?(evidencePack: LatestRepEvidencePack) {
        guard let sourceSessionID = evidencePack.sourceSessionID,
              evidencePack.comparisonMetricSchemaVersion == PracticeSession.currentComparisonMetricSchemaVersion,
              evidencePack.isEvaluationFixture == false,
              evidencePack.meetsQuantityFloor,
              evidencePack.durationSeconds >= Int(SessionQualifier.minimumDuration),
              evidencePack.transcriptWordCount >= SessionQualifier.minimumWordCount else {
            return nil
        }
        let fillerEvidence = evidencePack.qualifyingFillerEvidence
        self.sourceSessionID = sourceSessionID
        self.comparisonMetricSchemaVersion = PracticeSession.currentComparisonMetricSchemaVersion
        self.mode = evidencePack.mode
        self.score = evidencePack.score.flatMap { (0...10).contains($0) ? $0 : nil }
        self.fillerCount = fillerEvidence.status == .qualified
            ? fillerEvidence.fillerCount
            : nil
        self.fillerRatePerMinute = fillerEvidence.status == .qualified
            ? fillerEvidence.ratePerMinute
            : nil
        self.paceWordsPerMinute = evidencePack.wordsPerMinute.flatMap {
            $0 > 0 ? $0 : nil
        }
        self.durationSeconds = evidencePack.durationSeconds
        self.transcriptWordCount = evidencePack.transcriptWordCount
    }

    var evidenceText: String {
        var facts = [
            "latest qualified rep: \(mode)",
            "\(durationSeconds) seconds"
        ]
        if let score {
            facts.append("score \(score)/10")
        }
        if let fillerCount {
            let noun = fillerCount == 1 ? "filler" : "fillers"
            facts.append("\(fillerCount) \(noun)")
        }
        if let fillerRatePerMinute {
            facts.append("\(Self.oneDecimal(fillerRatePerMinute)) fillers per minute")
        }
        if let paceWordsPerMinute {
            facts.append("\(paceWordsPerMinute) WPM")
        }
        return facts.joined(separator: ", ")
    }

    func hasValue(for metric: CoachMetricKind) -> Bool {
        switch metric {
        case .score:
            return score != nil
        case .fillerCount:
            return fillerCount != nil
        case .fillerRatePerMinute:
            return fillerRatePerMinute != nil
        case .paceWordsPerMinute:
            return paceWordsPerMinute != nil
        case .durationSeconds:
            return true
        }
    }

    private static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }
}

struct CoachLongitudinalMetricTrend: Codable, Sendable, Equatable {
    enum Direction: String, Codable, Sendable, Equatable {
        case improving
        case declining
        case stable
    }

    let metric: CoachMetricKind
    let direction: Direction
    let currentValue: Double
    let priorAverage: Double

    var evidenceText: String {
        switch metric {
        case .score:
            return "score \(Self.oneDecimal(currentValue))/10 versus \(Self.oneDecimal(priorAverage))/10"
        case .fillerRatePerMinute:
            return "filler rate \(Self.oneDecimal(currentValue)) fillers per minute versus \(Self.oneDecimal(priorAverage)) fillers per minute"
        case .paceWordsPerMinute:
            return "pace \(Self.wholeNumber(currentValue)) WPM versus \(Self.wholeNumber(priorAverage)) WPM"
        case .fillerCount, .durationSeconds:
            return ""
        }
    }

    private static func oneDecimal(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    private static func wholeNumber(_ value: Double) -> String {
        String(Int(value.rounded()))
    }
}

struct CoachLongitudinalTrendProjection: Codable, Sendable, Equatable {
    let sourceSessionID: UUID
    let comparisonMetricSchemaVersion: Int
    let mode: String
    let comparableSessionIDs: [UUID]
    let metrics: [CoachLongitudinalMetricTrend]

    var evidenceText: String {
        let metricFacts = metrics
            .map(\.evidenceText)
            .filter { !$0.isEmpty }
            .joined(separator: "; ")
        let noun = comparableSessionIDs.count == 1 ? "rep" : "reps"
        return "latest \(mode) rep versus \(comparableSessionIDs.count) prior comparable \(noun): \(metricFacts)"
    }
}

struct CoachCaseSummary: Codable, Equatable {
    var hypothesis: String?
    var focus: String?
    var evidenceSummary: String?
    var nextCoachMove: String?
}

struct LatestRepEvidencePack: Codable, Equatable {
    var mode: String
    var score: Int?
    var fillerCount: Int
    var durationSeconds: Int
    var wordsPerMinute: Int?
    var transcriptWordCount: Int
    var transcriptConfidence: Double? = nil
    var transcriptExcerpt: String?
    var evidenceLines: [String]
    var sourceSessionID: UUID? = nil
    var comparisonMetricSchemaVersion: Int? = nil
    var isEvaluationFixture: Bool? = nil

    /// Rubric mechanics may only interpret delivery metrics when the latest
    /// rep contains enough speech to make duration-normalized comparisons.
    /// Keep this computed so cached payloads and existing fixtures remain
    /// backward compatible.
    var meetsQuantityFloor: Bool {
        SessionQualifier.meetsQuantityFloor(
            duration: TimeInterval(durationSeconds),
            wordCount: transcriptWordCount
        )
    }

    var qualifyingFillerBurden: FillerBurden? {
        FillerBurden.quantityQualified(
            fillerCount: fillerCount,
            duration: TimeInterval(durationSeconds),
            wordCount: transcriptWordCount,
            transcriptConfidence: transcriptConfidence
        )
    }

    var qualifyingFillerEvidence: QuantityQualifiedFillerEvidence {
        QuantityQualifiedFillerEvidence.current(
            fillerCount: fillerCount,
            duration: TimeInterval(durationSeconds),
            wordCount: transcriptWordCount,
            transcriptConfidence: transcriptConfidence
        )
    }

    var metricProjection: CoachLatestRepMetricProjection? {
        CoachLatestRepMetricProjection(evidencePack: self)
    }
}

struct ActiveInterventionState: Codable, Equatable {
    var title: String
    var target: String?
    var followedRepCount: Int
    var reviewStatus: String
}

struct UserTrajectoryCacheResult: Equatable {
    var snapshot: UserTrajectorySnapshot
    var cacheHit: Bool
}
