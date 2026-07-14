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
    var transcriptExcerpt: String?
    var evidenceLines: [String]

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
        guard meetsQuantityFloor else { return nil }
        let burden = FillerBurden(
            fillerCount: fillerCount,
            duration: TimeInterval(durationSeconds)
        )
        guard burden.ratePerMinute != nil else { return nil }
        return burden
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
