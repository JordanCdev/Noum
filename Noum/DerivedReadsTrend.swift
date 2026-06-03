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

// MARK: - Fused Delivery Read (#3 — coach-parity standard #5, Perception)
//
// Per VISION § Coach-parity standard #5 (Perception):
//   "Coach for the difference between clarity and over-polish,
//    avoidance, timidity, or emotional distance."
//
// The four derived reads (vocal energy / composure / confidence markers /
// structural) each describe ONE channel of a single rep. A real coach
// fuses them into one felt read of HOW the speaker showed up — and only
// after enough reps agree, never off one. `CoachDeliveryRead` is that
// fused, DURABLE read. It is NOT a new analyzer: it COMBINES the existing
// per-rep reads over the recent-rep window (the same composure +
// confidence-marker machinery `compute` already runs), so calibration is
// inherited — every contributing read is relative to the user's own
// baseline (hedging rate + pace), never an absolute-loudness or
// absolute-pitch term. A soft or accented speaker is read against
// themselves.
//
// THIS IS THE MOST INTERPRETIVELY DANGEROUS READ IN THE SYSTEM. Three
// hard rules, mirroring `ConfidenceMarkerRead`'s anti-diagnosis contract:
//
//   1. HYPOTHESIS, NEVER A TRAIT. The read characterises the REP SET
//      ("these reps read as timid"), never the person ("you are timid").
//      Association, never causation.
//   2. HARD CONSISTENCY FLOOR. A dominant pattern is named only when
//      `minConsistentReads` (4) reps in the recent window cast the SAME
//      vote. Below that → `.forming` and the tentative line is SUPPRESSED.
//   3. ONLY DEFENSIBLE PATTERNS. The enum deliberately ships only the
//      patterns these reads can honestly distinguish:
//        • `.clear`  — composure held AND confidence markers read clean,
//                      consistently. The positive read.
//        • `.timid`  — confidence markers read heavily tentative,
//                      consistently (the ConfidenceMarkerRead's own
//                      domain). A hypothesis about the markers, not the
//                      person.
//      Three patterns the brief names are DELIBERATELY ABSENT, not an
//      oversight:
//        • `.evasive`  — DROPPED. It implies intent. The underlying reads
//                        cannot distinguish humble / concise from evasive,
//                        and a wrong "evasive" label is the single most
//                        damaging thing the coach could say. Never emitted.
//        • `.polished` — over-polish is not measurable from these reads
//                        (nothing senses over-rehearsal); it would be
//                        indistinguishable from `.clear`.
//        • `.detached` — would require an absolute pitch-flatness / low-
//                        energy term that is NOT relative to the user's own
//                        baseline, which would mislabel naturally even or
//                        soft speakers. Banned by the no-absolute-term rule.
//      If a future read can ground any of these RELATIVE to the user's
//      baseline, add the case then — not before.

/// A single fused, durable read of how the recent rep SET read on
/// delivery. A HYPOTHESIS about the reps, never a trait or diagnosis of
/// the person. Persisted on `CoachMemory` (carried forward across thin
/// windows) so one coherent delivery read survives across surfaces.
struct CoachDeliveryRead: Codable, Equatable {

    /// The dominant delivery pattern across the recent rep window.
    /// `.forming` is the honest default below the consistency floor — the
    /// coach has reps but not yet enough agreement to name a pattern.
    enum DeliveryPattern: String, Codable, Equatable {
        /// Not enough consistent reads to name a pattern. Line suppressed.
        case forming
        /// Composure held and confidence markers read clean, consistently.
        case clear
        /// Confidence markers read heavily tentative, consistently. A
        /// hypothesis about the markers in the reps, never about the person.
        case timid
    }

    let dominantPattern: DeliveryPattern

    /// How many reps in the recent window cast the dominant vote — the
    /// evidence depth behind the read. 0 when `.forming` from no agreement.
    /// Lets the surface hedge harder on a 4-rep read than a 5-rep one.
    let evidenceDepth: Int

    /// One short, hedged, hypothesis-framed line for the coach context —
    /// `nil` whenever `dominantPattern == .forming` (the line is SUPPRESSED
    /// below the consistency floor; the coach says nothing rather than
    /// guess). Always reads the REP SET, never the person.
    let tentativeLine: String?

    /// True when a real pattern was named (i.e. not `.forming`). The build
    /// step uses this to decide whether to persist the fresh read or carry
    /// the previous durable read forward across a thin window.
    var isCharacterized: Bool { dominantPattern != .forming }
}

// MARK: - Delivery Profile (F3 — user-facing Perception surface)
//
// The user can already FEEL their delivery read in the coach's replies; this
// is the durable, glanceable version for Profile — the four questions a coach
// answers about HOW you come across:
//   1. What pattern recurs?        (mirrored from the fused CoachDeliveryRead)
//   2. What has improved?          (strongest improving DerivedReadTrend)
//   3. What breaks under pressure? (Sudden Death reads vs calmer reps)
//   4. What is the next target?    (declining / weakest dimension, or markers)
//
// NOT a new analyzer — it composes the SAME engines that feed the coach
// context (DerivedReadsTrendEngine + the per-rep Composure/ConfidenceMarker
// reads). Every line is a HYPOTHESIS about the rep SET, never a label on the
// person, and each self-suppresses (nil = omit the row) below its evidence
// floor. No absolute-loudness/pitch term — all reads are baseline-relative.
struct DeliveryProfile: Codable, Equatable {
    let pattern: CoachDeliveryRead.DeliveryPattern
    let evidenceDepth: Int
    let improvedLine: String?
    let pressureLine: String?
    let nextTargetLine: String?

    /// A named pattern OR any substantive line — the card hides entirely below
    /// this, so Profile never shows an empty delivery shell.
    var hasContent: Bool {
        pattern != .forming || improvedLine != nil || pressureLine != nil || nextTargetLine != nil
    }

    /// User-facing line for the recurring pattern. Distinct from the fused
    /// read's COACH-facing `tentativeLine` (which addresses the model) — this
    /// addresses the user: second person, calm, hypothesis-framed, never a
    /// trait. `.forming` returns nil (nothing has earned the floor yet).
    var patternLine: String? {
        switch pattern {
        case .forming:
            return nil
        case .clear:
            return "Your recent reps have been reading as clear — composure holding, few tentative markers. A read of these reps, not a fixed trait."
        case .timid:
            return "Your recent reps have been reading as tentative — hedging and tentative phrasing landing relative to your own baseline. A read of these reps, not a label on you."
        }
    }

    // MARK: Build

    /// Each pressure group needs at least this many scored reps before the
    /// app will compare them — one or two reps can't characterise "under
    /// pressure" honestly.
    static let pressureMinRepsPerGroup: Int = 3

    /// The non-pressure mean must exceed the pressure mean by at least this
    /// (on the 0-1 composite) before the app names a pressure dip. Below it,
    /// the difference is noise and the line is suppressed.
    static let pressureGapThreshold: Double = 0.08

    /// Compose the profile from the same inputs the coach context uses. Returns
    /// nil when nothing has earned a line (so the card omits entirely).
    static func build(
        sessions: [PracticeSession],
        snapshots: [SkillSnapshot],
        hedgingPerMinute: Double?,
        paceBaseline: Double?,
        deliveryRead: CoachDeliveryRead?
    ) -> DeliveryProfile? {
        let trends = DerivedReadsTrendEngine.compute(
            sessions: sessions,
            snapshots: snapshots,
            hedgingPerMinutePerSession: { _ in hedgingPerMinute },
            paceBaselinePerSession: { _ in paceBaseline }
        )

        let pattern = deliveryRead?.dominantPattern ?? .forming
        let profile = DeliveryProfile(
            pattern: pattern,
            evidenceDepth: deliveryRead?.evidenceDepth ?? 0,
            improvedLine: strongestImprovement(in: trends),
            pressureLine: pressureRead(
                sessions: sessions,
                hedgingPerMinute: hedgingPerMinute,
                paceBaseline: paceBaseline
            ),
            nextTargetLine: nextTarget(in: trends, pattern: pattern)
        )
        return profile.hasContent ? profile : nil
    }

    private static func fmt(_ x: Double) -> String { String(format: "%.2f", x) }

    /// The improving dimension with the largest positive delta, or nil.
    /// `internal` so tests can lock the selection without session fixtures.
    static func strongestImprovement(in trends: [DerivedReadTrend]) -> String? {
        guard let best = trends
            .filter({ $0.direction == .improving })
            .max(by: { ($0.recentMean - $0.priorMean) < ($1.recentMean - $1.priorMean) })
        else { return nil }
        return "\(best.dimension) has improved — \(fmt(best.priorMean)) to \(fmt(best.recentMean)) across your recent reps."
    }

    /// The next delivery target: a declining dimension wins (movement matters
    /// most), else the timid-pattern markers, else the lowest weak-but-steady
    /// dimension. nil when nothing stands out. `internal` for testability.
    static func nextTarget(in trends: [DerivedReadTrend], pattern: CoachDeliveryRead.DeliveryPattern) -> String? {
        if let declining = trends
            .filter({ $0.direction == .declining })
            .min(by: { ($0.recentMean - $0.priorMean) < ($1.recentMean - $1.priorMean) }) {
            return "\(declining.dimension) has slipped lately (\(fmt(declining.priorMean)) to \(fmt(declining.recentMean))) — a good next focus."
        }
        if pattern == .timid {
            return "Confidence markers are the next target — easing the tentative phrasing so more reps read as clear."
        }
        if let lowestStable = trends
            .filter({ $0.direction == .stable })
            .min(by: { $0.recentMean < $1.recentMean }),
           lowestStable.recentMean < 0.5 {
            return "\(lowestStable.dimension) is the lowest of your steady reads — the next area to lift."
        }
        return nil
    }

    /// Sudden-Death composite vs non-Sudden-Death composite. Names a dip only
    /// when each group clears the rep floor AND the gap clears the threshold —
    /// otherwise nil (no fabricated pressure story, and never a dip claim when
    /// pressure reads at or above calm).
    private static func pressureRead(
        sessions: [PracticeSession],
        hedgingPerMinute: Double?,
        paceBaseline: Double?
    ) -> String? {
        func composite(_ s: PracticeSession) -> Double? {
            let comp = ComposureReadEngine.derive(session: s, hedgingPerMinute: hedgingPerMinute)
            let conf = ConfidenceMarkerEngine.derive(
                session: s,
                hedgingPerMinute: hedgingPerMinute,
                paceWPM: paceBaseline,
                composure: comp
            )
            let scores = [comp?.score, conf?.score].compactMap { $0 }
            guard !scores.isEmpty else { return nil }
            return scores.reduce(0, +) / Double(scores.count)
        }
        let pressure = sessions.filter { $0.mode == .suddenDeath }.compactMap(composite)
        let calm = sessions.filter { $0.mode != .suddenDeath }.compactMap(composite)
        guard pressure.count >= pressureMinRepsPerGroup,
              calm.count >= pressureMinRepsPerGroup else { return nil }
        let pMean = pressure.reduce(0, +) / Double(pressure.count)
        let cMean = calm.reduce(0, +) / Double(calm.count)
        guard cMean - pMean >= pressureGapThreshold else { return nil }
        return "Under pressure (Sudden Death) your delivery reads lower than in calmer reps — composure and confidence markers dip when the clock is on."
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

    // MARK: - Fused delivery read

    /// Minimum reps in the recent window that must cast the SAME vote
    /// before a delivery pattern is named. Below this, the read is
    /// `.forming` and the line is suppressed. Set at 4 (of a 5-rep recent
    /// window) — the hard floor the brief requires; one or two reps can
    /// never characterise how someone "shows up".
    static let minConsistentDeliveryReads: Int = 4

    /// A rep votes `.clear` only when BOTH composure and confidence markers
    /// read at or above this floor (steady AND clean of tentative markers).
    /// Both reads are 0-1 and baseline-relative.
    static let deliveryClearFloor: Double = 0.65

    /// A rep votes `.timid` only when its confidence-marker score is at or
    /// below this ceiling (tentative markers landing heavily). Read off the
    /// ConfidenceMarkerRead — the read whose explicit domain is tentative
    /// markers — so the label stays "the markers read tentative", never a
    /// claim about the person.
    static let deliveryTimidCeiling: Double = 0.40

    /// When a rep DOES produce a structural read, it must not be weaker
    /// than this for a `.clear` vote to stand — bones falling apart
    /// contradicts a "clear" read. Absent structural never blocks the vote
    /// (most reps won't carry a snapshot), so this only ever weakens, never
    /// fabricates, a clear read.
    static let deliveryClearStructuralGuard: Double = 0.45

    /// Fuse the existing per-rep reads (composure + confidence markers +
    /// structural) across the recent rep window into one durable, hedged
    /// delivery read. NOT a new analyzer — it reuses the SAME per-session
    /// derive machinery `compute` runs (the `hedgingPerMinutePerSession` +
    /// `paceBaselinePerSession` closures), so calibration is inherited:
    /// every contributing read is relative to the user's own baseline, with
    /// no absolute-loudness or absolute-pitch term anywhere.
    ///
    /// Returns `nil` only when NO rep in the recent window produced any
    /// read at all (truly no signal). Otherwise returns a `CoachDeliveryRead`
    /// — `.forming` with a suppressed line below the consistency floor, or a
    /// named pattern (`.clear` / `.timid`) at/above it. The build step
    /// decides whether to persist `.forming` or carry the previous durable
    /// read forward.
    ///
    /// - Note: Every named pattern is a HYPOTHESIS about the REP SET, never
    ///   a trait or diagnosis of the person, and never a causal claim.
    static func fusedDeliveryRead(
        sessions: [PracticeSession],
        snapshots: [SkillSnapshot],
        hedgingPerMinutePerSession: (PracticeSession) -> Double?,
        paceBaselinePerSession: (PracticeSession) -> Double?
    ) -> CoachDeliveryRead? {
        // Same ordering + windowing as `compute`: newest-first, recent head.
        let ordered = sessions.sorted { $0.date > $1.date }
        let recent = Array(ordered.prefix(recentWindow))

        var clearVotes = 0
        var timidVotes = 0
        var anyRead = false

        for session in recent {
            // Reuse the EXACT per-session derive path `compute` uses, so the
            // fused read can never diverge from the per-rep reads. Composure
            // folds in vocal-energy steadiness + pitch variation + pause
            // quality + hedging (all scale-invariant / baseline-relative);
            // confidence markers fold in hedging + filler density + pace
            // (relative to baseline) + composure carryover.
            let composure = ComposureReadEngine.derive(
                session: session,
                hedgingPerMinute: hedgingPerMinutePerSession(session)
            )
            let confidence = ConfidenceMarkerEngine.derive(
                session: session,
                hedgingPerMinute: hedgingPerMinutePerSession(session),
                paceWPM: paceBaselinePerSession(session),
                composure: composure
            )

            // A rep can only vote when BOTH always-available baseline-relative
            // reads formed (each needs ≥ 2 channels). One channel alone is
            // never enough to read how someone showed up.
            guard let composure, let confidence else { continue }
            anyRead = true

            // Structural is a non-contradiction guard for `.clear` only —
            // absent structural never blocks a vote.
            let structural = StructuralReadEngine.derive(
                snapshot: snapshots.first(where: { $0.sessionId == session.id })
            )

            if composure.score >= deliveryClearFloor,
               confidence.score >= deliveryClearFloor,
               (structural?.score ?? 1.0) >= deliveryClearStructuralGuard {
                clearVotes += 1
            } else if confidence.score <= deliveryTimidCeiling {
                // Timid is a tentative-marker phenomenon — read off the
                // confidence markers alone. Structural says nothing about
                // timidity, so it is not consulted here.
                timidVotes += 1
            }
            // Anything else is a "mixed" rep — no vote. Honest abstention.
        }

        // No rep produced any read → no signal at all; let the caller carry
        // a previous durable read forward rather than inventing `.forming`.
        guard anyRead else { return nil }

        // Characterise ONLY when one vote clears the consistency floor. Ties
        // and below-floor pluralities both fall through to `.forming` — the
        // coach abstains rather than guess.
        if clearVotes >= minConsistentDeliveryReads, clearVotes > timidVotes {
            return CoachDeliveryRead(
                dominantPattern: .clear,
                evidenceDepth: clearVotes,
                tentativeLine: "Across the last \(clearVotes) reps the delivery has read as clear — composure holding and few tentative markers. A read of these reps, not a fixed trait."
            )
        }
        if timidVotes >= minConsistentDeliveryReads, timidVotes > clearVotes {
            return CoachDeliveryRead(
                dominantPattern: .timid,
                evidenceDepth: timidVotes,
                tentativeLine: "Across the last \(timidVotes) reps the delivery has read as tentative — hedging and tentative markers landing relative to this user's own baseline. A hypothesis about these reps, not a label on the person."
            )
        }

        // Reps exist but no pattern has earned the floor yet → forming, line
        // suppressed. Evidence depth 0: no agreement to stand on.
        return CoachDeliveryRead(
            dominantPattern: .forming,
            evidenceDepth: 0,
            tentativeLine: nil
        )
    }
}
