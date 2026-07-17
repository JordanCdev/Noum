import Foundation

// MARK: - Typed assessment cache

struct CoachAssessmentCacheResult: Equatable {
    var assessment: CoachAssessment
    var cacheHit: Bool
    var generatedAt: Date
}

/// Small in-memory cache for the deterministic judgement object that sits
/// between trajectory evidence and provider verbalisation. Durable ownership
/// stays in the existing stores; this only makes repeated generation of the
/// same turn/evidence/rubric signature observable and cheap.
final class CoachAssessmentCache {
    static let shared = CoachAssessmentCache()

    private struct Entry {
        var key: String
        var assessment: CoachAssessment
        var generatedAt: Date
    }

    private let lock = NSLock()
    private var entry: Entry?

    /// Internal construction keeps deterministic tests isolated from the
    /// process-wide cache used by the live reply pipeline.
    init() {}

    @discardableResult
    func assessment(
        turnDepth: CoachTurnDepth,
        userQuestion: String,
        trajectory: UserTrajectorySnapshot,
        rubric: ActiveGoalRubric,
        surface: CoachReplySurface,
        recentProofTests: [String],
        previousCoachReply: String?,
        build: () -> CoachAssessment
    ) -> CoachAssessmentCacheResult {
        let key = Self.signature(
            turnDepth: turnDepth,
            userQuestion: userQuestion,
            trajectory: trajectory,
            rubric: rubric,
            surface: surface,
            recentProofTests: recentProofTests,
            previousCoachReply: previousCoachReply
        )
        lock.lock()
        defer { lock.unlock() }
        if let entry, entry.key == key {
            return CoachAssessmentCacheResult(
                assessment: entry.assessment,
                cacheHit: true,
                generatedAt: entry.generatedAt
            )
        }

        let assessment = build()
        let generatedAt = Date()
        entry = Entry(key: key, assessment: assessment, generatedAt: generatedAt)
        return CoachAssessmentCacheResult(
            assessment: assessment,
            cacheHit: false,
            generatedAt: generatedAt
        )
    }

    func invalidate() {
        lock.lock()
        entry = nil
        lock.unlock()
    }

    private static func signature(
        turnDepth: CoachTurnDepth,
        userQuestion: String,
        trajectory: UserTrajectorySnapshot,
        rubric: ActiveGoalRubric,
        surface: CoachReplySurface,
        recentProofTests: [String],
        previousCoachReply: String?
    ) -> String {
        [
            "depth=\(turnDepth.rawValue)",
            "surface=\(surface.rawValue)",
            "question=\(normalized(userQuestion))",
            "rubric=\(rubric.rubric.goalID)",
            "voice=\(rubric.voice?.rawValue ?? "none")",
            "trajectory=\(trajectorySignature(trajectory))",
            "recentProofs=\(recentProofTests.map(normalized).joined(separator: "||"))",
            "previousCoach=\(normalized(previousCoachReply ?? ""))"
        ].joined(separator: "|")
    }

    private static func trajectorySignature(_ trajectory: UserTrajectorySnapshot) -> String {
        let pack = trajectory.latestRepEvidencePack
        let latestMetrics = pack?.metricProjection
        let longitudinal = trajectory.qualifiedLongitudinalTrend
        let caseSummary = trajectory.coachCaseSummary
        let intervention = trajectory.activeInterventionState
        return [
            "sessions=\(trajectory.sessionCount)",
            "rated=\(trajectory.ratedSessionCount)",
            "coverage=\(Int((trajectory.evidenceCoverage * 100).rounded()))",
            "recent=\(trajectory.recentSessionLines.joined(separator: " / "))",
            "trends=\(trajectory.trendLines.joined(separator: " / "))",
            "latestMode=\(pack?.mode ?? "none")",
            "latestScore=\(pack?.score.map(String.init) ?? "none")",
            "latestFillers=\(pack?.fillerCount ?? -1)",
            "latestDuration=\(pack?.durationSeconds ?? -1)",
            "latestWords=\(pack?.transcriptWordCount ?? -1)",
            "latestExcerpt=\(normalized(pack?.transcriptExcerpt ?? ""))",
            "latestMetricSource=\(latestMetrics?.sourceSessionID.uuidString ?? "none")",
            "latestMetricSchema=\(latestMetrics?.comparisonMetricSchemaVersion ?? -1)",
            "longitudinal=\(normalized(longitudinal?.evidenceText ?? ""))",
            "longitudinalSources=\(longitudinal?.comparableSessionIDs.map(\.uuidString).joined(separator: ",") ?? "none")",
            "caseHypothesis=\(normalized(caseSummary?.hypothesis ?? ""))",
            "caseFocus=\(normalized(caseSummary?.focus ?? ""))",
            "caseEvidence=\(normalized(caseSummary?.evidenceSummary ?? ""))",
            "caseMove=\(normalized(caseSummary?.nextCoachMove ?? ""))",
            "intervention=\(normalized(intervention?.title ?? ""))",
            "interventionTarget=\(normalized(intervention?.target ?? ""))",
            "interventionReps=\(intervention?.followedRepCount ?? -1)",
            "interventionStatus=\(normalized(intervention?.reviewStatus ?? ""))"
        ].joined(separator: "#")
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .joined(separator: " ")
    }
}
