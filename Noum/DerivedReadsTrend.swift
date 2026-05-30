import Foundation

// MARK: - Derived Reads Trend Engine
//
// M30 — Longitudinal pass on M26-M29 derived reads. Today the four
// derived reads (vocal energy, composure, confidence markers,
// structural) compute on-the-fly per rep — the coach can comment on
// the most-recent rep but can't say "your composure has trended up
// across 5 sessions." This engine closes that gap.
//
// Pure function — no new persistence layer needed. All input data
// (PracticeSession + SkillSnapshot + CommunicationBaseline) already
// persists. Walks the recent window + computes reads + classifies
// direction per dimension.
//
// Per VISION § Coach-parity standard #4 (Adaptation):
//   "Compare response across multiple attempts and either reinforce,
//    vary, or replace the intervention with an explained rationale."
//
// Per VISION § Dev instructions:
//   - "Weak evidence must produce tentative language; repeated
//     evidence can strengthen intervention."
//   - "Every recommendation must have evidence, purpose, an
//     observable target, and an honest evidence threshold for
//     changing the plan."
//
// The trend engine returns nil per-dimension when the window is too
// thin for credible direction. Honest about uncertainty.

/// Direction a derived read has moved across the recent window.
enum DerivedReadDirection: String, Codable, Equatable {
    case improving
    case declining
    case stable
    case insufficient   // window too thin to call direction

    /// Coach-voice label used in the trend readout.
    var label: String {
        switch self {
        case .improving:    return "improving"
        case .declining:    return "declining"
        case .stable:       return "stable"
        case .insufficient: return "not enough signal"
        }
    }
}

/// Per-dimension trend snapshot. Holds the direction + the comparison
/// numbers so the coach can quote actuals ("composure 0.62 → 0.78
/// across 6 reps").
struct DerivedReadTrend: Codable, Equatable {
    /// Which dimension this trend describes.
    let dimension: String
    /// Recent (most-recent N reps) composite score.
    let recentMean: Double
    /// Older (prior N reps) composite score for comparison.
    let priorMean: Double
    /// Number of reps contributing to `recentMean`.
    let recentCount: Int
    /// Number of reps contributing to `priorMean`.
    let priorCount: Int
    let direction: DerivedReadDirection

    /// Short coach-voice readout line. Used in CoachContextBuilder's
    /// DERIVED READ TRENDS section.
    var readout: String {
        switch direction {
        case .insufficient:
            return "\(dimension): not enough signal yet (\(recentCount) recent + \(priorCount) prior reps)."
        case .stable:
            return "\(dimension): stable (\(String(format: "%.2f", recentMean)) across \(recentCount) recent reps)."
        case .improving:
            return "\(dimension): improving (\(String(format: "%.2f", priorMean)) → \(String(format: "%.2f", recentMean)) across \(recentCount + priorCount) reps)."
        case .declining:
            return "\(dimension): declining (\(String(format: "%.2f", priorMean)) → \(String(format: "%.2f", recentMean)) across \(recentCount + priorCount) reps)."
        }
    }
}

enum DerivedReadsTrendEngine {

    /// Minimum reps in the RECENT window to compute a direction.
    /// Below this, we report `.insufficient` instead of fabricating
    /// movement from one rep.
    static let minRecentReps: Int = 3

    /// Minimum reps in the PRIOR window to compare against. Below
    /// this, we report `.stable` only when recent has ≥ minRecentReps
    /// (no comparison data); otherwise insufficient.
    static let minPriorReps: Int = 2

    /// Window sizes — split the recent rep history into RECENT (latest
    /// 5) + PRIOR (5 before that). Comparing 5-vs-5 gives stable
    /// signal without being so wide that long-ago noise dominates.
    static let recentWindow: Int = 5
    static let priorWindow: Int = 5

    /// Significance threshold for direction classification. Deltas
    /// within ±0.05 are noise; bigger is movement. Empirically tuned
    /// to the 0-1 score range the derived reads operate in.
    static let movementThreshold: Double = 0.05

    /// Compose trends for all four derived reads. Each entry returned
    /// at most one per dimension. Dimensions with no signal across
    /// the window are omitted entirely.
    static func compute(
        sessions: [PracticeSession],
        snapshots: [SkillSnapshot],
        hedgingPerMinutePerSession: (PracticeSession) -> Double?,
        paceBaselinePerSession: (PracticeSession) -> Double?
    ) -> [DerivedReadTrend] {
        // Sort sessions newest-first so the recent window is the head.
        let ordered = sessions.sorted { $0.date > $1.date }
        guard ordered.count >= minRecentReps else { return [] }
        let recent = Array(ordered.prefix(recentWindow))
        let prior = Array(ordered.dropFirst(recentWindow).prefix(priorWindow))

        var trends: [DerivedReadTrend] = []

        // 1. Vocal energy steadiness — directly from
        //    PracticeSession.vocalEnergyMetrics.steadiness.
        if let trend = computeTrend(
            dimension: "Vocal energy steadiness",
            recent: recent,
            prior: prior,
            score: { $0.vocalEnergyMetrics?.steadiness }
        ) {
            trends.append(trend)
        }

        // 2. Composure score — derive per-session via M27 engine.
        if let trend = computeTrend(
            dimension: "Composure",
            recent: recent,
            prior: prior,
            score: { session in
                ComposureReadEngine.derive(
                    session: session,
                    hedgingPerMinute: hedgingPerMinutePerSession(session)
                )?.score
            }
        ) {
            trends.append(trend)
        }

        // 3. Confidence markers — derive per-session via M28 engine.
        //    Pass composure as a feeder (matches the live computation).
        if let trend = computeTrend(
            dimension: "Confidence markers",
            recent: recent,
            prior: prior,
            score: { session in
                let composure = ComposureReadEngine.derive(
                    session: session,
                    hedgingPerMinute: hedgingPerMinutePerSession(session)
                )
                return ConfidenceMarkerEngine.derive(
                    session: session,
                    hedgingPerMinute: hedgingPerMinutePerSession(session),
                    paceWPM: paceBaselinePerSession(session),
                    composure: composure
                )?.score
            }
        ) {
            trends.append(trend)
        }

        // 4. Structural read — derive per-session via M29 engine,
        //    matching SkillSnapshot to session by sessionId.
        if let trend = computeTrend(
            dimension: "Structural",
            recent: recent,
            prior: prior,
            score: { session in
                let snap = snapshots.first(where: { $0.sessionId == session.id })
                return StructuralReadEngine.derive(snapshot: snap)?.score
            }
        ) {
            trends.append(trend)
        }

        return trends
    }

    /// Pure helper that runs a score function across two windows and
    /// classifies direction. Returns nil when the recent window
    /// produced no scored reps.
    static func computeTrend(
        dimension: String,
        recent: [PracticeSession],
        prior: [PracticeSession],
        score: (PracticeSession) -> Double?
    ) -> DerivedReadTrend? {
        let recentScores = recent.compactMap(score)
        let priorScores = prior.compactMap(score)

        // No recent scores → no signal at all; omit entirely.
        guard !recentScores.isEmpty else { return nil }

        let recentMean = recentScores.reduce(0, +) / Double(recentScores.count)
        let priorMean = priorScores.isEmpty ? 0 : priorScores.reduce(0, +) / Double(priorScores.count)

        let direction: DerivedReadDirection
        if recentScores.count < minRecentReps {
            direction = .insufficient
        } else if priorScores.count < minPriorReps {
            direction = .stable
        } else {
            let delta = recentMean - priorMean
            if abs(delta) <= movementThreshold {
                direction = .stable
            } else if delta > 0 {
                direction = .improving
            } else {
                direction = .declining
            }
        }

        return DerivedReadTrend(
            dimension: dimension,
            recentMean: recentMean,
            priorMean: priorMean,
            recentCount: recentScores.count,
            priorCount: priorScores.count,
            direction: direction
        )
    }
}
