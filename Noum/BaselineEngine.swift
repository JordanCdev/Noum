//
//  BaselineEngine.swift
//  Noum
//
//  Communication baseline system. Builds a stable behavioral portrait
//  of the user from session history using exponential moving averages
//  with confidence gating to prevent overconfident claims from small samples.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Hedge Detector

/// Detects hedge/softening phrases that dilute assertiveness.
enum HedgeDetector {
    /// Hedge phrases ranked by dilution impact.
    static let hedgePhrases: [String] = [
        "i think",
        "i guess",
        "i suppose",
        "i feel like",
        "kind of",
        "sort of",
        "maybe",
        "probably",
        "might be",
        "could be",
        "possibly",
        "i'm not sure but",
        "not entirely sure",
        "it seems like",
        "more or less",
        "to be honest",
        "in my opinion",
    ]

    /// Count total hedge phrase occurrences in a transcript.
    static func count(in transcript: String) -> Int {
        let lower = transcript.lowercased()
        return hedgePhrases.reduce(0) { total, phrase in
            total + occurrences(of: phrase, in: lower)
        }
    }

    /// Returns all detected hedge phrases with their counts.
    static func breakdown(in transcript: String) -> [(phrase: String, count: Int)] {
        let lower = transcript.lowercased()
        return hedgePhrases.compactMap { phrase in
            let count = occurrences(of: phrase, in: lower)
            return count > 0 ? (phrase, count) : nil
        }
    }

    private static func occurrences(of target: String, in text: String) -> Int {
        var count = 0
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: target, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<text.endIndex
        }
        return count
    }
}

// MARK: - Pressure Level

enum PressureLevel: Int, Codable, Comparable, CaseIterable {
    case casual = 0       // Free mode, no constraints, no stakes
    case standard = 1     // Normal timed/impromptu practice
    case elevated = 2     // Medium difficulty, time pressure, challenge context
    case high = 3         // Hard difficulty, sudden death, pressure mode, social stakes

    static func < (lhs: PressureLevel, rhs: PressureLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .casual: return "Casual"
        case .standard: return "Standard"
        case .elevated: return "Elevated"
        case .high: return "High Pressure"
        }
    }

    var shortLabel: String {
        switch self {
        case .casual: return "Casual"
        case .standard: return "Standard"
        case .elevated: return "Elevated"
        case .high: return "Pressure"
        }
    }
}

// MARK: - Baseline Confidence

enum BaselineConfidence: Int, Codable, Comparable {
    case insufficient = 0    // 0-2 qualifying sessions
    case tentative = 1       // 3-4 qualifying sessions
    case moderate = 2        // 5-9 qualifying sessions
    case established = 3     // 10-19 qualifying sessions
    case stable = 4          // 20+ qualifying sessions

    static func < (lhs: BaselineConfidence, rhs: BaselineConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    static func from(sessionCount: Int) -> BaselineConfidence {
        switch sessionCount {
        case 0...2: return .insufficient
        case 3...4: return .tentative
        case 5...9: return .moderate
        case 10...19: return .established
        default: return .stable
        }
    }

    var label: String {
        switch self {
        case .insufficient: return "Learning"
        case .tentative: return "Early read"
        case .moderate: return "Forming"
        case .established: return "Established"
        case .stable: return "Stable"
        }
    }

    var isReliable: Bool { self >= .moderate }
}

// MARK: - Baseline Stat

struct BaselineStat: Codable, Equatable {
    var value: Double
    var sampleCount: Int
    var confidence: BaselineConfidence
    var trend: TrendDirection
    var percentile25: Double
    var percentile75: Double

    var isReliable: Bool { confidence.isReliable }

    /// Human-readable range string, e.g., "2.1 – 4.3"
    var rangeLabel: String {
        guard isReliable else { return "—" }
        return "\(formatted(percentile25)) – \(formatted(percentile75))"
    }

    private func formatted(_ v: Double) -> String {
        if v == v.rounded() { return "\(Int(v))" }
        return String(format: "%.1f", v)
    }

    static let empty = BaselineStat(
        value: 0, sampleCount: 0,
        confidence: .insufficient, trend: .stable,
        percentile25: 0, percentile75: 0
    )
}

// MARK: - Communication Baseline

struct CommunicationBaseline: Codable, Equatable {
    var lastUpdated: Date
    var sessionCount: Int
    var qualifyingSessionCount: Int
    /// Metric recipe used to build this aggregate. Nil identifies a baseline
    /// persisted before recipe provenance existed and forces a history rebuild.
    var comparisonMetricSchemaVersion: Int?

    // Layer 1: Fundamentals
    var fillerRate: BaselineStat         // Fillers per minute
    var pace: BaselineStat               // Average WPM
    var paceVariance: BaselineStat       // Std dev of WPM across sessions
    var durationTendency: BaselineStat   // Typical speaking length (seconds)
    var pauseRate: BaselineStat          // Pauses (≥0.5s) per minute
    var pauseFilledRatio: BaselineStat   // Fraction of pauses filled with disfluency, 0–1

    // Layer 2: Structure & Content
    var openingStrength: BaselineStat    // From category ratings (1-3 scale)
    var closingStrength: BaselineStat
    var structureQuality: BaselineStat
    var answerDepth: BaselineStat
    var clarity: BaselineStat

    // Layer 3: Style Signals
    var vocabularyRange: BaselineStat    // Unique word ratio
    var hedgingRate: BaselineStat        // Hedge phrases per minute (e.g., "I think", "maybe", "sort of")
    /// Average monotone score across recent reps where pitch was reliable.
    /// 0.0 = varied delivery (good), 1.0 = flat/monotone (worse). Sources from
    /// `PitchMetrics.monotoneScore`. Only sessions with `isReliable` pitch
    /// contribute — older sessions and provider-degraded reps leave this
    /// untouched so the value never drifts to a fake "very flat" reading on
    /// missing data.
    var pitchVariation: BaselineStat

    // Layer 4: Overall
    var averageScore: BaselineStat

    // Layer 5: Verbal Habits
    /// Top clutch words with per-session occurrence frequency.
    /// Populated from ClutchWordStore — tracks the user's most persistent verbal habits.
    /// Keys are lowercased words; values track occurrences-per-session as a BaselineStat.
    var clutchWordFrequencies: [String: BaselineStat]

    // Computed summaries
    var topStrengths: [String]           // Skill area names consistently strong
    var persistentBlockers: [String]     // Areas stuck weak for 10+ sessions

    var overallConfidence: BaselineConfidence {
        BaselineConfidence.from(sessionCount: qualifyingSessionCount)
    }

    var usesCurrentComparisonMetrics: Bool {
        comparisonMetricSchemaVersion == PracticeSession.currentComparisonMetricSchemaVersion
    }

    /// Filler and pace baselines are comparison inputs, not timeless facts.
    /// A persisted aggregate built with an older metric recipe must not leak
    /// back into current coaching merely because its statistical confidence
    /// was once high enough.
    var currentComparisonFillerRate: Double? {
        guard usesCurrentComparisonMetrics,
              fillerRate.isReliable,
              fillerRate.value.isFinite,
              fillerRate.value >= 0 else { return nil }
        return fillerRate.value
    }

    var currentComparisonPaceWPM: Double? {
        guard usesCurrentComparisonMetrics,
              pace.isReliable,
              pace.value.isFinite,
              pace.value > 0 else { return nil }
        return pace.value
    }

    /// Normalized 0.0–1.0 distance from the user's stated coaching goal.
    /// 0.0 means the user is at (or beyond) the goal target; 1.0 means far from it.
    /// Returns 0.5 when there is insufficient data to measure.
    func distanceFromGoal(_ goal: CoachingPriority) -> Double {
        switch goal {
        case .reduceFillers:
            guard fillerRate.confidence != .insufficient else { return 0.5 }
            // Target: ≤ 1 filler/min. 8+ fillers/min = distance 1.0.
            return min(fillerRate.value / 8.0, 1.0)

        case .moreConcise:
            guard durationTendency.confidence != .insufficient else { return 0.5 }
            // Target: ≤ 45s typical duration. 120s+ = distance 1.0.
            return max(0, min((durationTendency.value - 20) / 100.0, 1.0))

        case .thinkFaster:
            guard averageScore.confidence != .insufficient else { return 0.5 }
            // Target: ≥ 7.5/10 score. 0/10 = distance 1.0.
            return max(0, 1.0 - averageScore.value / 7.5)

        case .calmerDelivery:
            guard pauseFilledRatio.confidence != .insufficient else { return 0.5 }
            // Target: ≤ 0.2 filled-pause ratio. 1.0 ratio = distance 1.0.
            return min(pauseFilledRatio.value / 0.8, 1.0)
        }
    }

    /// Short coaching phrase describing current goal distance (1–4 words). Safe for UI.
    func goalDistanceLabel(_ goal: CoachingPriority) -> String {
        let d = distanceFromGoal(goal)
        if d < 0.25 { return "On track" }
        if d < 0.50 { return "Getting closer" }
        if d < 0.75 { return "Work to do" }
        return "Early days"
    }

    /// Measured distance from goal, or nil when the underlying dimension lacks
    /// enough qualifying data to claim a number. Mirrors `distanceFromGoal` but
    /// never returns a fake "0.5 / Getting closer" reading on insufficient
    /// signal — UI surfaces use this when honesty matters more than coverage.
    func measuredDistanceFromGoal(_ goal: CoachingPriority) -> Double? {
        switch goal {
        case .reduceFillers:
            guard fillerRate.confidence != .insufficient else { return nil }
        case .moreConcise:
            guard durationTendency.confidence != .insufficient else { return nil }
        case .thinkFaster:
            guard averageScore.confidence != .insufficient else { return nil }
        case .calmerDelivery:
            guard pauseFilledRatio.confidence != .insufficient else { return nil }
        }
        return distanceFromGoal(goal)
    }

    /// Window-based goal distance computed from raw `SkillSnapshot` aggregates.
    /// Same normalisation formulas as the persistent `distanceFromGoal`, but
    /// run over an arbitrary snapshot slice — lets a UI surface compare a
    /// recent window against the prior window for week-over-week trend.
    ///
    /// Returns nil when fewer than `minimumSamples` qualifying snapshots are
    /// provided. For `.calmerDelivery` "qualifying" additionally means the
    /// snapshot carries a non-nil `pauseFilledRatio` — zero-pause reps don't
    /// contribute a calmness reading, so the helper refuses to fake one.
    static func distanceFromGoal(
        _ goal: CoachingPriority,
        in snapshots: [SkillSnapshot],
        minimumSamples: Int = 3
    ) -> Double? {
        switch goal {
        case .reduceFillers:
            let qualifying = snapshots.filter { $0.currentQualifiedFillerRatePerMinute != nil }
            guard qualifying.count >= minimumSamples else { return nil }
            let totalSeconds = qualifying.reduce(0.0) { $0 + $1.duration }
            guard totalSeconds > 0 else { return nil }
            let totalFillers = qualifying.reduce(0) { $0 + $1.fillerCount }
            let rate = Double(totalFillers) / (totalSeconds / 60.0)
            return min(rate / 8.0, 1.0)
        case .moreConcise:
            guard snapshots.count >= minimumSamples else { return nil }
            let mean = snapshots.reduce(0.0) { $0 + $1.duration } / Double(snapshots.count)
            return max(0, min((mean - 20) / 100.0, 1.0))
        case .thinkFaster:
            guard snapshots.count >= minimumSamples else { return nil }
            let mean = Double(snapshots.reduce(0) { $0 + $1.score }) / Double(snapshots.count)
            return max(0, 1.0 - mean / 7.5)
        case .calmerDelivery:
            // Mirrors the persistent `distanceFromGoal(_:)` formula but runs
            // over snapshots that actually carried pauses. Same target band:
            // ≤ 0.2 filled ratio = "On track", 1.0 filled = distance 1.0.
            let ratios = snapshots.compactMap { $0.pauseFilledRatio }
            guard ratios.count >= minimumSamples else { return nil }
            let mean = ratios.reduce(0, +) / Double(ratios.count)
            return min(mean / 0.8, 1.0)
        }
    }

    static let empty = CommunicationBaseline(
        lastUpdated: Date(),
        sessionCount: 0,
        qualifyingSessionCount: 0,
        comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion,
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
        pitchVariation: .empty,
        averageScore: .empty,
        clutchWordFrequencies: [:],
        topStrengths: [],
        persistentBlockers: []
    )

    // MARK: - Codable (backwards-compatible)
    //
    // Custom decoder so persisted baselines from earlier app versions
    // (which lack `pauseRate` / `pauseFilledRatio`) decode cleanly into
    // `.empty` for those fields rather than failing the whole decode.

    enum CodingKeys: String, CodingKey {
        case lastUpdated, sessionCount, qualifyingSessionCount, comparisonMetricSchemaVersion
        case fillerRate, pace, paceVariance, durationTendency
        case pauseRate, pauseFilledRatio
        case openingStrength, closingStrength, structureQuality, answerDepth, clarity
        case vocabularyRange, hedgingRate, pitchVariation, averageScore
        case clutchWordFrequencies, topStrengths, persistentBlockers
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lastUpdated = try c.decode(Date.self, forKey: .lastUpdated)
        sessionCount = try c.decode(Int.self, forKey: .sessionCount)
        qualifyingSessionCount = try c.decode(Int.self, forKey: .qualifyingSessionCount)
        comparisonMetricSchemaVersion = try c.decodeIfPresent(
            Int.self,
            forKey: .comparisonMetricSchemaVersion
        )
        fillerRate = try c.decode(BaselineStat.self, forKey: .fillerRate)
        pace = try c.decode(BaselineStat.self, forKey: .pace)
        paceVariance = try c.decode(BaselineStat.self, forKey: .paceVariance)
        durationTendency = try c.decode(BaselineStat.self, forKey: .durationTendency)
        pauseRate = try c.decodeIfPresent(BaselineStat.self, forKey: .pauseRate) ?? .empty
        pauseFilledRatio = try c.decodeIfPresent(BaselineStat.self, forKey: .pauseFilledRatio) ?? .empty
        openingStrength = try c.decode(BaselineStat.self, forKey: .openingStrength)
        closingStrength = try c.decode(BaselineStat.self, forKey: .closingStrength)
        structureQuality = try c.decode(BaselineStat.self, forKey: .structureQuality)
        answerDepth = try c.decode(BaselineStat.self, forKey: .answerDepth)
        clarity = try c.decode(BaselineStat.self, forKey: .clarity)
        vocabularyRange = try c.decode(BaselineStat.self, forKey: .vocabularyRange)
        hedgingRate = try c.decode(BaselineStat.self, forKey: .hedgingRate)
        pitchVariation = try c.decodeIfPresent(BaselineStat.self, forKey: .pitchVariation) ?? .empty
        averageScore = try c.decode(BaselineStat.self, forKey: .averageScore)
        clutchWordFrequencies = try c.decodeIfPresent([String: BaselineStat].self, forKey: .clutchWordFrequencies) ?? [:]
        topStrengths = try c.decode([String].self, forKey: .topStrengths)
        persistentBlockers = try c.decode([String].self, forKey: .persistentBlockers)
    }

    init(
        lastUpdated: Date,
        sessionCount: Int,
        qualifyingSessionCount: Int,
        comparisonMetricSchemaVersion: Int? = PracticeSession.currentComparisonMetricSchemaVersion,
        fillerRate: BaselineStat,
        pace: BaselineStat,
        paceVariance: BaselineStat,
        durationTendency: BaselineStat,
        pauseRate: BaselineStat,
        pauseFilledRatio: BaselineStat,
        openingStrength: BaselineStat,
        closingStrength: BaselineStat,
        structureQuality: BaselineStat,
        answerDepth: BaselineStat,
        clarity: BaselineStat,
        vocabularyRange: BaselineStat,
        hedgingRate: BaselineStat,
        pitchVariation: BaselineStat = .empty,
        averageScore: BaselineStat,
        clutchWordFrequencies: [String: BaselineStat],
        topStrengths: [String],
        persistentBlockers: [String]
    ) {
        self.lastUpdated = lastUpdated
        self.sessionCount = sessionCount
        self.qualifyingSessionCount = qualifyingSessionCount
        self.comparisonMetricSchemaVersion = comparisonMetricSchemaVersion
        self.fillerRate = fillerRate
        self.pace = pace
        self.paceVariance = paceVariance
        self.durationTendency = durationTendency
        self.pauseRate = pauseRate
        self.pauseFilledRatio = pauseFilledRatio
        self.openingStrength = openingStrength
        self.closingStrength = closingStrength
        self.structureQuality = structureQuality
        self.answerDepth = answerDepth
        self.clarity = clarity
        self.vocabularyRange = vocabularyRange
        self.hedgingRate = hedgingRate
        self.pitchVariation = pitchVariation
        self.averageScore = averageScore
        self.clutchWordFrequencies = clutchWordFrequencies
        self.topStrengths = topStrengths
        self.persistentBlockers = persistentBlockers
    }
}

// MARK: - Coach Baseline Map

/// Coach-facing dimensions for a compact baseline map.
///
/// The map is intentionally about evidence coverage first. A human coach
/// would say "I can now read your pace and filler patterns, but vocal range is
/// still thin" before turning early telemetry into a confident verdict.
enum BaselineCoachDimension: String, CaseIterable, Identifiable, Equatable {
    case fillerControl
    case paceControl
    case structure
    case clarity
    case composure
    case vocalRange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fillerControl: return "Filler control"
        case .paceControl: return "Pace control"
        case .structure: return "Structure"
        case .clarity: return "Clarity"
        case .composure: return "Composure"
        case .vocalRange: return "Vocal range"
        }
    }

    var shortTitle: String {
        switch self {
        case .fillerControl: return "Fillers"
        case .paceControl: return "Pace"
        case .structure: return "Structure"
        case .clarity: return "Clarity"
        case .composure: return "Composure"
        case .vocalRange: return "Voice"
        }
    }
}

struct BaselineCoachDimensionRead: Equatable, Identifiable {
    let dimension: BaselineCoachDimension
    /// 0...1 evidence coverage. This is what the baseline readout primarily visualises.
    let evidenceProgress: Double
    /// 0...1 current quality read, nil while the dimension is too thin.
    let currentScore: Double?
    let confidence: BaselineConfidence
    let valueLabel: String?

    var id: BaselineCoachDimension { dimension }
    var isMeasured: Bool { currentScore != nil }

    var coachStateLabel: String {
        guard let currentScore else { return "Needs signal" }
        if currentScore >= 0.72 { return "Strong" }
        if currentScore >= 0.42 { return "Working" }
        return "Focus"
    }
}

struct BaselineGoalGapRead: Equatable {
    let goal: CoachingPriority
    /// 0...1 proximity to the goal. 1 means at or beyond the target.
    let proximity: Double
    let currentLabel: String
    let targetLabel: String

    var percentLabel: String {
        "\(Int((proximity * 100).rounded()))%"
    }

    var summary: String {
        "\(percentLabel) toward \(goal.title.lowercased())"
    }
}

struct BaselineCoachMap: Equatable {
    static let establishedRepTarget = 10

    let confidence: BaselineConfidence
    let qualifyingSessionCount: Int
    let formationProgress: Double
    let repsUntilEstablished: Int
    let dimensions: [BaselineCoachDimensionRead]
    let goalGap: BaselineGoalGapRead?
    let motivationAnchor: String?

    var measuredDimensionCount: Int {
        dimensions.filter(\.isMeasured).count
    }

    var strongestMeasuredDimension: BaselineCoachDimensionRead? {
        dimensions
            .filter(\.isMeasured)
            .max { ($0.currentScore ?? 0) < ($1.currentScore ?? 0) }
    }

    var weakestMeasuredDimension: BaselineCoachDimensionRead? {
        dimensions
            .filter(\.isMeasured)
            .min { ($0.currentScore ?? 1) < ($1.currentScore ?? 1) }
    }

    var nextEvidenceDimension: BaselineCoachDimensionRead? {
        dimensions.first { !$0.isMeasured }
    }

    var readoutFocusDimension: BaselineCoachDimensionRead? {
        weakestMeasuredDimension ?? nextEvidenceDimension
    }

    var readoutStrengthDimension: BaselineCoachDimensionRead? {
        guard let strongest = strongestMeasuredDimension else { return nil }
        guard strongest.dimension != readoutFocusDimension?.dimension else { return nil }
        return strongest
    }

    var supportingReadoutDimensions: [BaselineCoachDimensionRead] {
        dimensions.filter { read in
            read.dimension != readoutFocusDimension?.dimension
                && read.dimension != readoutStrengthDimension?.dimension
        }
    }

    var coachHeadline: String {
        switch confidence {
        case .insufficient:
            return "Noum is still calibrating"
        case .tentative:
            return "The first read is forming"
        case .moderate:
            return "Your baseline is taking shape"
        case .established, .stable:
            return "Your baseline is usable"
        }
    }

    var coachPriorityLine: String {
        if let weakest = weakestMeasuredDimension,
           let score = weakest.currentScore,
           score < 0.42 {
            return "\(weakest.dimension.title) is the clearest gap to work next."
        }

        if let weakest = weakestMeasuredDimension,
           let score = weakest.currentScore,
           score < 0.72 {
            return "\(weakest.dimension.title) is the next place to tighten."
        }

        if let nextEvidenceDimension {
            return "\(nextEvidenceDimension.dimension.title) still needs more signal."
        }

        if measuredDimensionCount > 0 {
            return "New reps can now be compared against these patterns."
        }

        return "Run one measured rep so Noum can stop guessing."
    }

    var statusTitle: String {
        switch confidence {
        case .insufficient: return "Baseline calibrating"
        case .tentative: return "Early baseline"
        case .moderate: return "Baseline forming"
        case .established: return "Baseline established"
        case .stable: return "Stable coaching read"
        }
    }

    var statusDetail: String {
        if confidence >= .established {
            return "\(qualifyingSessionCount) qualifying reps. Noum can compare new reps against your own patterns."
        }
        if repsUntilEstablished == 1 {
            return "1 more qualifying rep to establish the baseline."
        }
        return "\(repsUntilEstablished) more qualifying reps to establish the baseline."
    }

    static func make(baseline: CommunicationBaseline, profile: CoachingProfile?) -> BaselineCoachMap {
        let count = baseline.qualifyingSessionCount
        let repsUntilEstablished = max(0, establishedRepTarget - count)
        let formationProgress = clamp(Double(count) / Double(establishedRepTarget))

        return BaselineCoachMap(
            confidence: baseline.overallConfidence,
            qualifyingSessionCount: count,
            formationProgress: formationProgress,
            repsUntilEstablished: repsUntilEstablished,
            dimensions: BaselineCoachDimension.allCases.map { read(for: $0, baseline: baseline) },
            goalGap: profile.flatMap { gap(for: $0.primaryGoal, baseline: baseline) },
            motivationAnchor: motivationAnchor(for: profile)
        )
    }

    private static func read(
        for dimension: BaselineCoachDimension,
        baseline: CommunicationBaseline
    ) -> BaselineCoachDimensionRead {
        switch dimension {
        case .fillerControl:
            return singleStatRead(
                dimension: dimension,
                stat: baseline.fillerRate,
                score: { 1.0 - min($0 / 8.0, 1.0) },
                valueLabel: { String(format: "%.1f/min", $0) }
            )
        case .paceControl:
            return singleStatRead(
                dimension: dimension,
                stat: baseline.pace,
                score: { paceScore(wpm: $0) },
                valueLabel: { "\(Int($0.rounded())) WPM" }
            )
        case .structure:
            return singleStatRead(
                dimension: dimension,
                stat: baseline.structureQuality,
                score: { categoryScore($0) },
                valueLabel: { String(format: "%.1f/3", $0) }
            )
        case .clarity:
            return singleStatRead(
                dimension: dimension,
                stat: baseline.clarity,
                score: { categoryScore($0) },
                valueLabel: { String(format: "%.1f/3", $0) }
            )
        case .composure:
            return composureRead(baseline: baseline)
        case .vocalRange:
            return singleStatRead(
                dimension: dimension,
                stat: baseline.pitchVariation,
                score: { 1.0 - clamp($0) },
                valueLabel: { "\(Int(((1.0 - clamp($0)) * 100).rounded()))% range" }
            )
        }
    }

    private static func singleStatRead(
        dimension: BaselineCoachDimension,
        stat: BaselineStat,
        score: (Double) -> Double,
        valueLabel: (Double) -> String
    ) -> BaselineCoachDimensionRead {
        BaselineCoachDimensionRead(
            dimension: dimension,
            evidenceProgress: evidenceProgress(for: stat.confidence),
            currentScore: stat.confidence == .insufficient ? nil : clamp(score(stat.value)),
            confidence: stat.confidence,
            valueLabel: stat.confidence == .insufficient ? nil : valueLabel(stat.value)
        )
    }

    private static func composureRead(baseline: CommunicationBaseline) -> BaselineCoachDimensionRead {
        var scores: [Double] = []
        var confidences: [BaselineConfidence] = []
        var labels: [String] = []

        if baseline.pauseFilledRatio.confidence != .insufficient {
            scores.append(1.0 - min(baseline.pauseFilledRatio.value / 0.8, 1.0))
            confidences.append(baseline.pauseFilledRatio.confidence)
            labels.append("\(Int((baseline.pauseFilledRatio.value * 100).rounded()))% filled pauses")
        }
        if baseline.hedgingRate.confidence != .insufficient {
            scores.append(1.0 - min(baseline.hedgingRate.value / 4.0, 1.0))
            confidences.append(baseline.hedgingRate.confidence)
            labels.append(String(format: "%.1f hedges/min", baseline.hedgingRate.value))
        }
        if baseline.pauseRate.confidence != .insufficient {
            // Pause count alone is not "bad"; it just adds weak composure
            // signal. Keep the cap forgiving so deliberate pausers are not
            // punished by the map.
            scores.append(1.0 - min(baseline.pauseRate.value / 10.0, 1.0))
            confidences.append(baseline.pauseRate.confidence)
            labels.append(String(format: "%.1f pauses/min", baseline.pauseRate.value))
        }

        guard !scores.isEmpty else {
            return BaselineCoachDimensionRead(
                dimension: .composure,
                evidenceProgress: 0,
                currentScore: nil,
                confidence: .insufficient,
                valueLabel: nil
            )
        }

        let meanScore = scores.reduce(0, +) / Double(scores.count)
        let confidence = confidences.max() ?? .insufficient
        return BaselineCoachDimensionRead(
            dimension: .composure,
            evidenceProgress: evidenceProgress(for: confidence),
            currentScore: clamp(meanScore),
            confidence: confidence,
            valueLabel: labels.first ?? "Multi-signal read"
        )
    }

    private static func gap(
        for goal: CoachingPriority,
        baseline: CommunicationBaseline
    ) -> BaselineGoalGapRead? {
        guard let distance = baseline.measuredDistanceFromGoal(goal) else { return nil }
        let proximity = clamp(1.0 - distance)
        let labels = goalLabels(for: goal, baseline: baseline)
        return BaselineGoalGapRead(
            goal: goal,
            proximity: proximity,
            currentLabel: labels.current,
            targetLabel: labels.target
        )
    }

    private static func goalLabels(
        for goal: CoachingPriority,
        baseline: CommunicationBaseline
    ) -> (current: String, target: String) {
        switch goal {
        case .reduceFillers:
            return (
                String(format: "%.1f fillers/min", baseline.fillerRate.value),
                "1.0/min or lower"
            )
        case .moreConcise:
            return (
                "\(Int(baseline.durationTendency.value.rounded()))s typical answer",
                "about 45s or less"
            )
        case .thinkFaster:
            return (
                String(format: "%.1f/10 average score", baseline.averageScore.value),
                "7.5/10 or higher"
            )
        case .calmerDelivery:
            return (
                "\(Int((baseline.pauseFilledRatio.value * 100).rounded()))% filled pauses",
                "20% or lower"
            )
        }
    }

    private static func motivationAnchor(for profile: CoachingProfile?) -> String? {
        guard let profile else { return nil }
        let why = profile.whyNowReference
        let vision = profile.successVisionReference
        if !why.isEmpty && !vision.isEmpty {
            return "You started because \(why). The payoff you named: \(vision)."
        }
        if !why.isEmpty {
            return "You started because \(why)."
        }
        if !vision.isEmpty {
            return "The payoff you named: \(vision)."
        }
        let brief = profile.coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines)
        if !brief.isEmpty {
            return "You wrote: \(brief)."
        }
        return nil
    }

    private static func paceScore(wpm: Double) -> Double {
        let distance = ConversationalPaceBand.distanceFromTarget(wpm)
        return 1.0 - min(distance / 70.0, 1.0)
    }

    private static func categoryScore(_ value: Double) -> Double {
        clamp((value - 1.0) / 2.0)
    }

    private static func evidenceProgress(for confidence: BaselineConfidence) -> Double {
        guard BaselineConfidence.stable.rawValue > 0 else { return 0 }
        return clamp(Double(confidence.rawValue) / Double(BaselineConfidence.stable.rawValue))
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

// MARK: - Pressure Profile

struct PressureProfile: Codable, Equatable {
    var casualFillerRate: BaselineStat?
    var standardFillerRate: BaselineStat?
    var elevatedFillerRate: BaselineStat?
    var highFillerRate: BaselineStat?

    var casualPace: BaselineStat?
    var highPace: BaselineStat?

    var casualScore: BaselineStat?
    var highScore: BaselineStat?

    var casualDuration: BaselineStat?
    var highDuration: BaselineStat?

    var casualStructure: BaselineStat?
    var highStructure: BaselineStat?

    /// 0.0 = completely falls apart under pressure; 1.0 = identical performance
    var pressureResilience: Double? {
        guard let casual = casualFillerRate, casual.isReliable,
              let high = highFillerRate, high.isReliable else { return nil }
        let fillerDelta = abs(high.value - casual.value) / max(casual.value, 1.0)
        let paceDelta: Double
        if let cp = casualPace, cp.isReliable, let hp = highPace, hp.isReliable {
            paceDelta = abs(hp.value - cp.value) / max(cp.value, 1.0)
        } else {
            paceDelta = 0
        }
        let scoreDelta: Double
        if let cs = casualScore, cs.isReliable, let hs = highScore, hs.isReliable {
            scoreDelta = abs(hs.value - cs.value) / max(cs.value, 1.0)
        } else {
            scoreDelta = 0
        }
        let avgDelta = (fillerDelta + paceDelta + scoreDelta) / 3.0
        return max(0, min(1.0, 1.0 - avgDelta))
    }

    /// Delta for a specific dimension under pressure vs casual. Positive = worse under pressure.
    func pressureDelta(for dimension: PressureDimension) -> Double? {
        switch dimension {
        case .fillers:
            guard let c = casualFillerRate, c.isReliable, let h = highFillerRate, h.isReliable else { return nil }
            return h.value - c.value
        case .pace:
            guard let c = casualPace, c.isReliable, let h = highPace, h.isReliable else { return nil }
            return h.value - c.value
        case .score:
            guard let c = casualScore, c.isReliable, let h = highScore, h.isReliable else { return nil }
            return c.value - h.value  // Score delta inverted: lower score = worse
        case .duration:
            guard let c = casualDuration, c.isReliable, let h = highDuration, h.isReliable else { return nil }
            return c.value - h.value  // Shorter under pressure = worse
        case .structure:
            guard let c = casualStructure, c.isReliable, let h = highStructure, h.isReliable else { return nil }
            return c.value - h.value  // Lower structure quality = worse
        }
    }

    /// Which dimension degrades most under pressure
    var mostAffectedDimension: PressureDimension? {
        mostAffectedDimension(includingComparisonMechanics: true)
    }

    /// Selects the strongest pressure delta without allowing a withheld filler
    /// or pace comparison to influence an otherwise mechanic-free prompt.
    func mostAffectedDimension(
        includingComparisonMechanics: Bool
    ) -> PressureDimension? {
        let dimensions: [PressureDimension] = if includingComparisonMechanics {
            [.fillers, .pace, .score, .duration, .structure]
        } else {
            [.score, .duration, .structure]
        }
        let withDeltas = dimensions.compactMap { dim -> (PressureDimension, Double)? in
            guard let delta = pressureDelta(for: dim) else { return nil }
            return (dim, delta)
        }
        return withDeltas.max(by: { $0.1 < $1.1 })?.0
    }

    /// Multiple human-readable pressure insights
    var pressureInsights: [String] {
        pressureInsights(includingComparisonMechanics: true)
    }

    /// Builds pressure context while retaining independently measured score,
    /// duration, and structure facts when comparison mechanics are withheld.
    /// Resilience is omitted in that mode because its formula requires filler
    /// evidence and can also incorporate pace evidence.
    func pressureInsights(
        includingComparisonMechanics: Bool
    ) -> [String] {
        var insights: [String] = []

        // Filler insight
        if includingComparisonMechanics,
           let casual = casualFillerRate, casual.isReliable,
           let high = highFillerRate, high.isReliable {
            let diff = high.value - casual.value
            if diff > 1.5 {
                insights.append("Your filler rate jumps from \(String(format: "%.1f", casual.value))/min to \(String(format: "%.1f", high.value))/min under pressure.")
            } else if diff < -0.5 {
                insights.append("You actually use fewer fillers under pressure — you focus up.")
            } else {
                insights.append("Your filler control holds steady regardless of pressure.")
            }
        }

        // Pace insight
        if includingComparisonMechanics,
           let cp = casualPace, cp.isReliable,
           let hp = highPace, hp.isReliable {
            let diff = hp.value - cp.value
            if diff > 15 {
                insights.append("Your pace accelerates by \(Int(diff)) WPM under pressure (\(Int(cp.value)) → \(Int(hp.value))).")
            } else if diff < -15 {
                insights.append("You slow down by \(Int(abs(diff))) WPM under pressure — possibly over-deliberating.")
            }
        }

        // Duration insight
        if let cd = casualDuration, cd.isReliable, let hd = highDuration, hd.isReliable {
            let diff = cd.value - hd.value
            if diff > 10 {
                insights.append("Under pressure, your answers are \(Int(diff))s shorter on average.")
            }
        }

        // Score insight
        if let cs = casualScore, cs.isReliable, let hs = highScore, hs.isReliable {
            let diff = cs.value - hs.value
            if diff > 1.0 {
                insights.append("Your score drops by \(String(format: "%.1f", diff)) points under pressure.")
            }
        }

        // Resilience summary
        if includingComparisonMechanics,
           let resilience = pressureResilience {
            if resilience >= 0.85 {
                insights.append("Pressure resilience: strong — your performance barely changes under stress.")
            } else if resilience >= 0.6 {
                insights.append("Pressure resilience: moderate — some degradation under stress, room to build.")
            } else {
                insights.append("Pressure resilience: developing — significant performance gap under stress.")
            }
        }

        return insights
    }

    /// Backward-compatible single insight (returns first insight or nil)
    var pressureInsight: String? { pressureInsights.first }

    static let empty = PressureProfile()
}

enum PressureDimension: String, CaseIterable {
    case fillers
    case pace
    case score
    case duration
    case structure

    var label: String {
        switch self {
        case .fillers: return "Filler words"
        case .pace: return "Speaking pace"
        case .score: return "Overall score"
        case .duration: return "Answer length"
        case .structure: return "Structure quality"
        }
    }
}

// MARK: - Session Qualifier

/// Determines whether a session should contribute to the baseline.
enum SessionQualifier {
    static let minimumDuration: TimeInterval = 15
    static let minimumWordCount: Int = 20
    static let minimumConfidence: Double = 0.5

    static func meetsQuantityFloor(
        duration: TimeInterval,
        wordCount: Int
    ) -> Bool {
        duration.isFinite
            && duration >= minimumDuration
            && wordCount >= minimumWordCount
    }

    static func qualifies(_ session: PracticeSession) -> Bool {
        guard meetsQuantityFloor(
            duration: session.duration,
            wordCount: session.wordCount
        ) else { return false }
        if let confidence = session.transcriptConfidence, confidence < minimumConfidence {
            return false
        }
        return true
    }

    /// Historical filler-rate and pace interpretations must compare like with
    /// like. Raw sessions remain readable when this returns false; only their
    /// duration-derived metrics are withheld.
    static func acceptsHistoricalComparisonMetrics(_ session: PracticeSession) -> Bool {
        qualifies(session)
            && session.comparisonMetricSchemaVersion == PracticeSession.currentComparisonMetricSchemaVersion
            && !session.isEvaluationFixture
    }

    /// Quantity-qualified pace for a current speech sample. Returning `nil`
    /// keeps missing evidence distinct from a real zero-WPM measurement.
    static func quantityQualifiedWordsPerMinute(
        duration: TimeInterval,
        wordCount: Int,
        transcriptConfidence: Double? = nil
    ) -> Double? {
        guard meetsQuantityFloor(duration: duration, wordCount: wordCount) else {
            return nil
        }
        if let transcriptConfidence,
           transcriptConfidence < minimumConfidence {
            return nil
        }
        let wordsPerMinute = Double(wordCount) / (duration / 60.0)
        guard wordsPerMinute.isFinite, wordsPerMinute > 0 else { return nil }
        return wordsPerMinute
    }

    /// Historical pace additionally requires current metric provenance and a
    /// non-evaluation row, matching the existing baseline admission boundary.
    static func quantityQualifiedWordsPerMinute(_ session: PracticeSession) -> Double? {
        guard acceptsHistoricalComparisonMetrics(session) else { return nil }
        return quantityQualifiedWordsPerMinute(
            duration: session.duration,
            wordCount: session.wordCount,
            transcriptConfidence: session.transcriptConfidence
        )
    }
}

// MARK: - Filler Burden

/// A duration-normalized projection for deciding when filler evidence should
/// influence practice selection. Detection stays with `FillerWordDetector`;
/// this type only interprets its already-filtered count.
struct FillerBurden {
    enum Threshold: Double {
        case elevated = 2
        case primaryFocus = 3
        case urgent = 5
        case severe = 8

        fileprivate var minimumCount: Int {
            self == .severe ? 3 : 2
        }
    }

    let fillerCount: Int
    let duration: TimeInterval

    var ratePerMinute: Double? {
        guard fillerCount >= 0,
              duration.isFinite,
              duration >= SessionQualifier.minimumDuration else { return nil }
        let rate = Double(fillerCount) / (duration / 60.0)
        return rate.isFinite ? rate : nil
    }

    func meets(_ threshold: Threshold) -> Bool {
        guard fillerCount >= threshold.minimumCount,
              let ratePerMinute else { return false }
        return ratePerMinute >= threshold.rawValue
    }

    func isAtMost(_ threshold: Threshold) -> Bool {
        guard let ratePerMinute else { return false }
        return ratePerMinute <= threshold.rawValue
    }

    /// Builds a burden only when the current speech sample meets the shared
    /// quantity floor. This is intentionally additive: `ratePerMinute` keeps
    /// its duration-only contract for established scoring callers, while
    /// comparison and coaching surfaces opt into the stricter evidence gate.
    static func quantityQualified(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        transcriptConfidence: Double? = nil
    ) -> FillerBurden? {
        guard SessionQualifier.meetsQuantityFloor(
            duration: duration,
            wordCount: wordCount
        ) else { return nil }
        if let transcriptConfidence,
           transcriptConfidence < SessionQualifier.minimumConfidence {
            return nil
        }
        let burden = FillerBurden(fillerCount: fillerCount, duration: duration)
        guard burden.ratePerMinute != nil else { return nil }
        return burden
    }

    /// Historical comparisons use the complete session qualifier, including
    /// the transcript-confidence floor when a provider supplied one.
    static func quantityQualified(_ session: PracticeSession) -> FillerBurden? {
        guard SessionQualifier.acceptsHistoricalComparisonMetrics(session) else { return nil }
        return quantityQualified(
            fillerCount: session.fillerWordCount,
            duration: session.duration,
            wordCount: session.wordCount,
            transcriptConfidence: session.transcriptConfidence
        )
    }

    static func quantityQualifiedRatesPerMinute(
        in sessions: [PracticeSession]
    ) -> [Double] {
        sessions.compactMap { quantityQualified($0)?.ratePerMinute }
    }

    static func qualifyingRatesPerMinute(
        in sessions: [PracticeSession]
    ) -> [Double] {
        sessions.compactMap {
            FillerBurden(
                fillerCount: $0.fillerWordCount,
                duration: $0.duration
            ).ratePerMinute
        }
    }

    static func averageQualifyingRatePerMinute(
        in sessions: [PracticeSession]
    ) -> Double? {
        let rates = qualifyingRatesPerMinute(in: sessions)
        guard !rates.isEmpty else { return nil }
        return rates.reduce(0, +) / Double(rates.count)
    }
}

/// One exact, non-persisted projection for coach-facing filler evidence.
/// Current-rep callers use the primitive quantity gate so controlled evaluation
/// fixtures exercise the same behavior as a real rep. Historical callers keep
/// using `FillerBurden.quantityQualified(_:)`, which additionally rejects stale
/// schemas and evaluation-only rows.
struct QuantityQualifiedFillerEvidence: Equatable {
    enum Status: Equatable {
        case qualified
        case insufficient
    }

    private static let qualifiedPrefix = "Latest qualified filler evidence:"
    private static let insufficientLine = "Latest filler evidence: comparison withheld because the sample did not meet the shared quantity and confidence floor."

    let status: Status
    let fillerCount: Int?
    let durationSeconds: Int?
    let ratePerMinute: Double?

    static var insufficient: QuantityQualifiedFillerEvidence {
        QuantityQualifiedFillerEvidence(
            status: .insufficient,
            fillerCount: nil,
            durationSeconds: nil,
            ratePerMinute: nil
        )
    }

    private static func displayRate(_ rate: Double) -> Double {
        (rate * 10).rounded() / 10
    }

    static func current(
        fillerCount: Int,
        duration: TimeInterval,
        wordCount: Int,
        transcriptConfidence: Double? = nil
    ) -> QuantityQualifiedFillerEvidence {
        guard let burden = FillerBurden.quantityQualified(
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            transcriptConfidence: transcriptConfidence
        ), let rate = burden.ratePerMinute else {
            return .insufficient
        }
        return QuantityQualifiedFillerEvidence(
            status: .qualified,
            fillerCount: fillerCount,
            durationSeconds: Int(duration.rounded()),
            ratePerMinute: displayRate(rate)
        )
    }

    static func current(_ session: PracticeSession) -> QuantityQualifiedFillerEvidence {
        current(
            fillerCount: session.fillerWordCount,
            duration: session.duration,
            wordCount: session.wordCount,
            transcriptConfidence: session.transcriptConfidence
        )
    }

    static func historical(_ session: PracticeSession) -> QuantityQualifiedFillerEvidence {
        guard let burden = FillerBurden.quantityQualified(session),
              let rate = burden.ratePerMinute else {
            return .insufficient
        }
        return QuantityQualifiedFillerEvidence(
            status: .qualified,
            fillerCount: session.fillerWordCount,
            durationSeconds: Int(session.duration.rounded()),
            ratePerMinute: displayRate(rate)
        )
    }

    var summary: String? {
        guard status == .qualified,
              let fillerCount,
              let durationSeconds,
              let ratePerMinute else { return nil }
        let noun = fillerCount == 1 ? "filler" : "fillers"
        return "\(fillerCount) \(noun) in \(durationSeconds) seconds (\(String(format: "%.1f", ratePerMinute)) per minute)"
    }

    var contextLine: String {
        guard let summary else { return Self.insufficientLine }
        return "\(Self.qualifiedPrefix) \(summary)."
    }

    static func parseLatest(in text: String) -> QuantityQualifiedFillerEvidence? {
        if text.contains(insufficientLine) {
            return .insufficient
        }

        let escapedPrefix = NSRegularExpression.escapedPattern(for: qualifiedPrefix)
        let pattern = "(?i)\(escapedPrefix)\\s+(\\d{1,3})\\s+(?:filler|fillers)\\s+in\\s+(\\d{1,6})\\s+seconds\\s+\\(([0-9]+(?:\\.[0-9]+)?)\\s+per\\s+minute\\)\\."
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..., in: text)
              ),
              match.numberOfRanges == 4,
              let countRange = Range(match.range(at: 1), in: text),
              let durationRange = Range(match.range(at: 2), in: text),
              let rateRange = Range(match.range(at: 3), in: text),
              let count = Int(text[countRange]),
              let duration = Int(text[durationRange]),
              let rate = Double(text[rateRange]),
              count >= 0,
              duration >= Int(SessionQualifier.minimumDuration),
              rate.isFinite else { return nil }

        return QuantityQualifiedFillerEvidence(
            status: .qualified,
            fillerCount: count,
            durationSeconds: duration,
            ratePerMinute: rate
        )
    }
}

/// One enforcement boundary for generated coaching that mentions observed
/// filler or pace mechanics. Prompts can withhold unsupported measurements,
/// but a provider can still reconstruct them; every generated coaching path
/// must therefore validate the returned prose as well.
enum CoachMetricEvidenceGuard {
    /// Rejects only observed mechanic claims whose corresponding evidence was
    /// withheld. Generic prescriptions such as "pause before the close" and
    /// semantic uses such as "that detail was not filler" remain valid.
    static func usesUnsupportedMetricClaim(
        _ text: String,
        hasFillerEvidence: Bool,
        hasPaceEvidence: Bool
    ) -> Bool {
        let normalized = collapseWhitespace(in: text).lowercased()

        // Filler burden does not prove pace. Reject the causal join even when
        // both independent measurements are available.
        let fillerImpliesPacePatterns = [
            #"\bfillers?\b.{0,32}\b(?:means?|shows?|proves?|suggests?|signals?|indicates?)\b.{0,32}\b(?:pace|pacing|rushed|rushing)\b"#,
            #"\b(?:pace|pacing|rushed|rushing)\b.{0,32}\b(?:because|from|due to)\b.{0,32}\bfillers?\b"#
        ]
        if fillerImpliesPacePatterns.contains(where: { containsRegex($0, in: normalized) }) {
            return true
        }

        if !hasFillerEvidence {
            let fillerPatterns = [
                #"\bfiller[\s-]*(?:count|rate|words?|burden)\b"#,
                #"\b(?:your|this rep's|the rep's)\s+filler[\s-]*control\b"#,
                #"\b(?:zero|no|one|two|three|four|five|six|seven|eight|nine|ten|\d+|few|fewer|many|more|less|low|high)\s+fillers?\b"#,
                #"\b(?:your|this rep's|the rep's)\s+fillers?\b"#,
                #"\bfillers?\s+(?:surfaced|crept|appeared|rose|fell|dropped|increased|decreased|held|stayed|spiked|weakened|undercut|disrupted)\b"#,
                #"\b(?:zero|no|one|two|three|four|five|six|seven|eight|nine|ten|\d+)\s+(?:disfluenc(?:y|ies)|ums?|uhs?)\b"#,
                #"\bdisfluenc(?:y|ies)\s+(?:count|rate)\b"#,
                #"\b(?:repeated|frequent|several|many|more|fewer)\s+(?:disfluenc(?:y|ies)|ums?|uhs?)\b"#,
                #"\b(?:disfluenc(?:y|ies)|ums?|uhs?)\s+(?:surfaced|crept|appeared|rose|fell|dropped|increased|decreased|spiked|weakened|undercut|disrupted)\b"#
            ]
            if fillerPatterns.contains(where: { containsRegex($0, in: normalized) }) {
                return true
            }
        }

        if !hasPaceEvidence {
            let pacePatterns = [
                #"\b\d{2,3}(?:\.\d+)?\s*(?:wpm|words?\s+per\s+minute)\b"#,
                #"\b(?:your|this|that|the)\s+(?:speaking\s+)?(?:pace|pacing)\b"#,
                #"\b(?:your|this|that|the)\s+(?:tempo|cadence)\b"#,
                #"\b(?:pace|pacing)\s+(?:was|is|ran|felt|held|stayed|landed|came|looked|sounded|reads?)\b"#,
                #"\b(?:tempo|cadence)\s+(?:was|is|felt|held|stayed|accelerated|slowed|quickened)\b"#,
                #"\byou\s+(?:were\s+|felt\s+|sounded\s+|moved\s+)?(?:too\s+)?(?:fast|slow|rushed|rushing)\b"#,
                #"\byou\s+(?:spoke|talked|moved)\s+(?:quickly|slowly|rapidly)\b"#,
                #"\b(?:delivery|answer|rep|opening|close)\s+(?:was|were|felt|sounded|ran|came)\s+(?:too\s+)?(?:fast|slow|rushed)\b"#,
                #"\b(?:rushed|rushing)\s+(?:delivery|pace|pacing|answer|rep|opening|close)\b"#,
                #"\byou\s+(?:sped\s+up|slowed\s+down|rushed)\b"#
            ]
            if pacePatterns.contains(where: { containsRegex($0, in: normalized) }) {
                return true
            }
        }

        return false
    }

    private static func containsRegex(_ pattern: String, in text: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }

    private static func collapseWhitespace(in text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}

/// A non-persisted comparison between one quantity-qualified rep and repeated
/// qualified history. The 0.5/min movement floor matches Ah Counter's public
/// history read so tiny rate jitter never becomes progress or regression.
struct FillerRateComparison: Equatable {
    enum Direction: Equatable {
        case improving
        case steady
        case worsening
    }

    static let minimumPriorSamples = 2
    static let movementFloor = 0.5

    let currentRatePerMinute: Double
    let priorAverageRatePerMinute: Double
    let deltaRatePerMinute: Double
    let direction: Direction

    var meaningfulDeltaRatePerMinute: Double? {
        direction == .steady ? nil : deltaRatePerMinute
    }

    static func make(
        currentRatePerMinute: Double?,
        previousRatesPerMinute: [Double],
        minimumPriorSamples: Int = minimumPriorSamples
    ) -> FillerRateComparison? {
        guard let currentRatePerMinute,
              currentRatePerMinute.isFinite,
              currentRatePerMinute >= 0,
              minimumPriorSamples > 0 else { return nil }

        let validPreviousRates = previousRatesPerMinute.filter {
            $0.isFinite && $0 >= 0
        }
        guard validPreviousRates.count >= minimumPriorSamples else { return nil }

        let priorAverage = validPreviousRates.reduce(0, +) / Double(validPreviousRates.count)
        guard priorAverage.isFinite else { return nil }
        let delta = currentRatePerMinute - priorAverage
        let direction: Direction
        if abs(delta) < movementFloor {
            direction = .steady
        } else if delta < 0 {
            direction = .improving
        } else {
            direction = .worsening
        }

        return FillerRateComparison(
            currentRatePerMinute: currentRatePerMinute,
            priorAverageRatePerMinute: priorAverage,
            deltaRatePerMinute: delta,
            direction: direction
        )
    }
}

// MARK: - Baseline Engine

/// Computes and maintains the communication baseline from session history.
/// Uses exponential moving averages with a recency bias.
enum BaselineEngine {

    /// One admission boundary for every duration-derived baseline and pressure
    /// read. Historical metric epochs remain readable in Review but cannot be
    /// averaged with the current microphone-stop recipe.
    static func acceptsCurrentComparisonMetrics(_ session: PracticeSession) -> Bool {
        SessionQualifier.acceptsHistoricalComparisonMetrics(session)
    }

    // MARK: - Full Recompute

    /// Recomputes the entire baseline from session history.
    /// Called on app launch and after account switch.
    ///
    /// Category ratings (opening / close / structure / depth / clarity) are
    /// carried by trend snapshots rather than by the sessions themselves. The
    /// live app reads them from the shared trend store, but that store is a
    /// process-global whose contents depend on account scope and on whatever
    /// else has already run. Deterministic fixtures must therefore be able to
    /// state their own snapshot roster instead of inheriting ambient evidence —
    /// omitting `categorySnapshots` preserves the shipping behaviour exactly.
    static func compute(
        from sessions: [PracticeSession],
        categorySnapshots: [SkillSnapshot]? = nil
    ) -> CommunicationBaseline {
        let eligibleSessionCount = PracticeProgressEligibility.eligibleSessions(in: sessions).count
        let qualifying = sessions.filter(acceptsCurrentComparisonMetrics)
        guard !qualifying.isEmpty else { return .empty }

        // Sort most recent first
        let sorted = qualifying.sorted { $0.date > $1.date }
        let recent = Array(sorted.prefix(20))

        var baseline = CommunicationBaseline.empty
        baseline.sessionCount = eligibleSessionCount
        baseline.qualifyingSessionCount = qualifying.count
        baseline.lastUpdated = Date()

        // Filler rate (fillers per minute)
        let fillerRates = recent.map { s -> Double in
            guard s.duration > 0 else { return 0 }
            return Double(s.fillerWordCount) / (s.duration / 60.0)
        }
        baseline.fillerRate = buildStat(from: fillerRates, allSamples: qualifying.count)

        // Pace (WPM)
        let paces = recent.map { Double($0.wordsPerMinute) }
        baseline.pace = buildStat(from: paces, allSamples: qualifying.count)

        // Pace variance
        if paces.count >= 3 {
            let mean = paces.reduce(0, +) / Double(paces.count)
            let variance = paces.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(paces.count)
            baseline.paceVariance = BaselineStat(
                value: sqrt(variance),
                sampleCount: paces.count,
                confidence: BaselineConfidence.from(sessionCount: qualifying.count),
                trend: .stable,
                percentile25: sqrt(variance) * 0.7,
                percentile75: sqrt(variance) * 1.3
            )
        }

        // Duration
        let durations = recent.map { $0.duration }
        baseline.durationTendency = buildStat(from: durations, allSamples: qualifying.count)

        // Pause rate (pauses ≥ 0.5s per minute) — only counts sessions where
        // the transcription provider actually emitted word timings, so older
        // sessions and provider-degraded reps don't drag the average toward 0.
        let pauseRates = recent.compactMap { s -> Double? in
            guard let metrics = s.pauseMetrics, s.duration > 0 else { return nil }
            return Double(metrics.count) / (s.duration / 60.0)
        }
        if !pauseRates.isEmpty {
            baseline.pauseRate = buildStat(from: pauseRates, allSamples: pauseRates.count)
        }

        // Filled-pause ratio — fraction of pauses filled with disfluency.
        // Only counts sessions where at least one pause occurred (otherwise
        // the ratio is undefined / 0 by convention but adds no signal).
        let filledRatios = recent.compactMap { s -> Double? in
            guard let metrics = s.pauseMetrics, metrics.count > 0 else { return nil }
            return metrics.filledRatio
        }
        if !filledRatios.isEmpty {
            baseline.pauseFilledRatio = buildStat(from: filledRatios, allSamples: filledRatios.count)
        }

        // Category ratings (Opening, Closing, Structure, Depth, Clarity)
        // Map "Good" = 3, "OK" = 2, "Could improve" = 1
        let ratingSnapshots = categorySnapshots ?? SkillTrendStore.shared.snapshots
        baseline.openingStrength = buildCategoryStat(from: ratingSnapshots, dimension: "Opening", allSamples: qualifying.count)
        baseline.closingStrength = buildCategoryStat(from: ratingSnapshots, dimension: "Close", allSamples: qualifying.count)
        baseline.structureQuality = buildCategoryStat(from: ratingSnapshots, dimension: "Structure", allSamples: qualifying.count)
        baseline.answerDepth = buildCategoryStat(from: ratingSnapshots, dimension: "Depth", allSamples: qualifying.count)
        baseline.clarity = buildCategoryStat(from: ratingSnapshots, dimension: "Clarity", allSamples: qualifying.count)

        // Vocabulary range (unique word ratio)
        let vocabRatios = recent.compactMap { s -> Double? in
            let words = s.transcript.lowercased().split { !$0.isLetter }
            guard words.count >= 20 else { return nil }
            return Double(Set(words).count) / Double(words.count)
        }
        if !vocabRatios.isEmpty {
            baseline.vocabularyRange = buildStat(from: vocabRatios, allSamples: qualifying.count)
        }

        // Hedging rate (hedge phrases per minute)
        let hedgingRates = recent.compactMap { s -> Double? in
            guard s.duration > 0 else { return nil }
            let count = HedgeDetector.count(in: s.transcript)
            return Double(count) / (s.duration / 60.0)
        }
        if !hedgingRates.isEmpty {
            baseline.hedgingRate = buildStat(from: hedgingRates, allSamples: qualifying.count)
        }

        // Pitch variation — uses PitchMetrics.monotoneScore (0=varied, 1=flat).
        // Only counts sessions where the pitch reading was reliable (≥10
        // voiced windows, mean inside 70–400Hz, ≥20% voiced ratio). Older
        // sessions and provider-degraded reps don't drag the value.
        let monotoneScores = recent.compactMap { s -> Double? in
            guard let metrics = s.pitchMetrics, metrics.isReliable else { return nil }
            return metrics.monotoneScore
        }
        if !monotoneScores.isEmpty {
            baseline.pitchVariation = buildStat(from: monotoneScores, allSamples: monotoneScores.count)
        }

        // Average score
        let scores = recent.compactMap { $0.score }.map { Double($0) }
        if !scores.isEmpty {
            baseline.averageScore = buildStat(from: scores, allSamples: qualifying.count)
        }

        // Top strengths and persistent blockers
        baseline.topStrengths = identifyStrengths(baseline)
        baseline.persistentBlockers = identifyBlockers(baseline)

        return baseline
    }

    /// Recomputes the entire baseline, including clutch word data from the store.
    /// Call from a @MainActor context to safely access ClutchWordStore.
    @MainActor
    static func computeWithClutchWords(from sessions: [PracticeSession]) -> CommunicationBaseline {
        var baseline = compute(from: sessions)
        baseline.clutchWordFrequencies = buildClutchWordStats(from: ClutchWordStore.shared.topClutchWords)
        return baseline
    }

    /// Deterministic pressure-profile rebuild. Stores expose newest-first
    /// history, but EMA replay must run oldest-to-newest so newer evidence has
    /// the intended final weight after a recipe migration.
    static func computePressureProfile(from sessions: [PracticeSession]) -> PressureProfile {
        let chronological = sessions
            .filter(acceptsCurrentComparisonMetrics)
            .sorted { lhs, rhs in
                if lhs.date != rhs.date { return lhs.date < rhs.date }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        return chronological.reduce(into: PressureProfile.empty) { profile, session in
            profile = updatePressureProfile(
                profile,
                session: session,
                pressure: session.pressureLevel
            )
        }
    }

    // MARK: - Incremental Update

    /// Updates an existing baseline with a new session.
    /// Uses EMA with recency bias: α = 0.5 for early sessions (< 5), 0.15 for established.
    static func update(_ baseline: CommunicationBaseline, with session: PracticeSession) -> CommunicationBaseline {
        guard PracticeProgressEligibility.qualifies(session) else { return baseline }
        guard acceptsCurrentComparisonMetrics(session) else {
            var updated = baseline
            updated.sessionCount += 1
            updated.lastUpdated = Date()
            return updated
        }

        let totalQualifying = baseline.qualifyingSessionCount + 1
        let alpha = totalQualifying < 5 ? 0.5 : 0.15

        var updated = baseline
        updated.sessionCount += 1
        updated.qualifyingSessionCount = totalQualifying
        updated.lastUpdated = Date()

        // Filler rate
        let fillerRate = session.duration > 0 ? Double(session.fillerWordCount) / (session.duration / 60.0) : 0
        updated.fillerRate = updateStat(updated.fillerRate, newValue: fillerRate, alpha: alpha, totalSamples: totalQualifying)

        // Pace
        let wpm = Double(session.wordsPerMinute)
        updated.pace = updateStat(updated.pace, newValue: wpm, alpha: alpha, totalSamples: totalQualifying)

        // Duration
        updated.durationTendency = updateStat(updated.durationTendency, newValue: session.duration, alpha: alpha, totalSamples: totalQualifying)

        // Pause metrics — only contribute when the session captured them.
        // Sessions from older builds (or providers that don't emit timings)
        // leave the existing baseline pause stats untouched.
        if let metrics = session.pauseMetrics, session.duration > 0 {
            let pauseRate = Double(metrics.count) / (session.duration / 60.0)
            updated.pauseRate = updateStat(
                updated.pauseRate,
                newValue: pauseRate,
                alpha: alpha,
                totalSamples: max(updated.pauseRate.sampleCount + 1, totalQualifying)
            )
            if metrics.count > 0 {
                updated.pauseFilledRatio = updateStat(
                    updated.pauseFilledRatio,
                    newValue: metrics.filledRatio,
                    alpha: alpha,
                    totalSamples: max(updated.pauseFilledRatio.sampleCount + 1, totalQualifying)
                )
            }
        }

        // Score
        if let score = session.score {
            updated.averageScore = updateStat(updated.averageScore, newValue: Double(score), alpha: alpha, totalSamples: totalQualifying)
        }

        // Vocabulary range
        let words = session.transcript.lowercased().split { !$0.isLetter }
        if words.count >= 20 {
            let ratio = Double(Set(words).count) / Double(words.count)
            updated.vocabularyRange = updateStat(updated.vocabularyRange, newValue: ratio, alpha: alpha, totalSamples: totalQualifying)
        }

        // Hedging rate
        if session.duration > 0 {
            let hedgeCount = HedgeDetector.count(in: session.transcript)
            let hedgeRate = Double(hedgeCount) / (session.duration / 60.0)
            updated.hedgingRate = updateStat(updated.hedgingRate, newValue: hedgeRate, alpha: alpha, totalSamples: totalQualifying)
        }

        // Pitch variation — only contribute when the session captured a
        // reliable pitch reading. Sessions that didn't (e.g. very short reps,
        // mostly silent, mic noise outside vocal range) leave the existing
        // baseline pitch stat untouched.
        if let metrics = session.pitchMetrics, metrics.isReliable {
            updated.pitchVariation = updateStat(
                updated.pitchVariation,
                newValue: metrics.monotoneScore,
                alpha: alpha,
                totalSamples: max(updated.pitchVariation.sampleCount + 1, totalQualifying)
            )
        }

        // Update strengths and blockers
        updated.topStrengths = identifyStrengths(updated)
        updated.persistentBlockers = identifyBlockers(updated)

        return updated
    }

    /// Updates an existing baseline with a new session, including clutch word refresh.
    /// Call from a @MainActor context to safely access ClutchWordStore.
    @MainActor
    static func updateWithClutchWords(_ baseline: CommunicationBaseline, with session: PracticeSession) -> CommunicationBaseline {
        var updated = update(baseline, with: session)
        updated.clutchWordFrequencies = buildClutchWordStats(from: ClutchWordStore.shared.topClutchWords)
        return updated
    }

    @MainActor
    static func updateWithMiniDrill(_ baseline: CommunicationBaseline, outcome: MiniDrillOutcome) -> CommunicationBaseline {
        var updated = baseline
        updated.sessionCount += 1
        updated.lastUpdated = Date()

        guard outcome.duration >= 5, outcome.wordCount >= 5 else {
            updated.clutchWordFrequencies = buildClutchWordStats(from: ClutchWordStore.shared.topClutchWords)
            return updated
        }

        let alpha = 0.08
        let samples = max(1, updated.qualifyingSessionCount)
        let fillerRate = Double(outcome.fillerCount) / max(outcome.duration / 60.0, 0.1)
        let wpm = Double(outcome.wordCount) / max(outcome.duration, 1) * 60

        updated.fillerRate = updateStat(updated.fillerRate, newValue: fillerRate, alpha: alpha, totalSamples: max(updated.fillerRate.sampleCount, samples))
        updated.pace = updateStat(updated.pace, newValue: wpm, alpha: alpha, totalSamples: max(updated.pace.sampleCount, samples))
        updated.durationTendency = updateStat(updated.durationTendency, newValue: outcome.duration, alpha: alpha, totalSamples: max(updated.durationTendency.sampleCount, samples))
        updated.hedgingRate = updateStat(
            updated.hedgingRate,
            newValue: Double(HedgeDetector.count(in: outcome.transcript)) / max(outcome.duration / 60.0, 0.1),
            alpha: alpha,
            totalSamples: max(updated.hedgingRate.sampleCount, samples)
        )
        updated.clutchWordFrequencies = buildClutchWordStats(from: ClutchWordStore.shared.topClutchWords)
        updated.topStrengths = identifyStrengths(updated)
        updated.persistentBlockers = identifyBlockers(updated)
        return updated
    }

    // MARK: - Pressure Classification

    /// Classifies the pressure level of a session based on mode, difficulty, and context.
    static func classifyPressure(
        mode: PracticeMode,
        difficulty: String? = nil,
        isPressureModeOn: Bool = false,
        hasActiveChallenge: Bool = false,
        streakDays: Int = 0
    ) -> PressureLevel {
        var level: Int

        // Base pressure from mode
        switch mode {
        case .ahCounter:
            level = PressureLevel.casual.rawValue
        case .timed:
            switch difficulty {
            case "hard": level = PressureLevel.high.rawValue
            case "medium": level = PressureLevel.elevated.rawValue
            case "easy": level = PressureLevel.standard.rawValue
            default: level = PressureLevel.casual.rawValue  // free mode
            }
        case .suddenDeath:
            level = PressureLevel.high.rawValue
        case .imConversation:
            level = PressureLevel.standard.rawValue
        }

        // Stacking modifiers
        if isPressureModeOn { level += 1 }
        if hasActiveChallenge { level += 1 }
        if streakDays >= 7 { level += 1 }

        return PressureLevel(rawValue: min(level, PressureLevel.high.rawValue)) ?? .high
    }

    // MARK: - Pressure Profile Update

    /// Updates the pressure profile with a new session's data at its pressure level.
    static func updatePressureProfile(_ profile: PressureProfile, session: PracticeSession, pressure: PressureLevel) -> PressureProfile {
        guard acceptsCurrentComparisonMetrics(session) else { return profile }

        let fillerRate = session.duration > 0 ? Double(session.fillerWordCount) / (session.duration / 60.0) : 0
        let wpm = Double(session.wordsPerMinute)
        let score = Double(session.score ?? 0)

        var updated = profile

        // Track all levels for filler rate; track full profile for casual and high
        let dur = session.duration

        // Structure quality from category ratings (snapshot lookup)
        let structureValue: Double? = {
            let snapshots = SkillTrendStore.shared.snapshots
            guard let match = snapshots.first(where: { $0.sessionId == session.id }) else { return nil }
            guard let ratingStr = match.categoryRatings["Structure"] else { return nil }
            switch ratingStr {
            case "Good": return 3.0
            case "OK": return 2.0
            case "Could improve": return 1.0
            default: return nil
            }
        }()

        switch pressure {
        case .casual:
            let existing = updated.casualFillerRate ?? .empty
            updated.casualFillerRate = updateStat(existing, newValue: fillerRate, alpha: 0.2, totalSamples: existing.sampleCount + 1)
            let existingPace = updated.casualPace ?? .empty
            updated.casualPace = updateStat(existingPace, newValue: wpm, alpha: 0.2, totalSamples: existingPace.sampleCount + 1)
            let existingScore = updated.casualScore ?? .empty
            updated.casualScore = updateStat(existingScore, newValue: score, alpha: 0.2, totalSamples: existingScore.sampleCount + 1)
            let existingDur = updated.casualDuration ?? .empty
            updated.casualDuration = updateStat(existingDur, newValue: dur, alpha: 0.2, totalSamples: existingDur.sampleCount + 1)
            if let sv = structureValue {
                let existingStruct = updated.casualStructure ?? .empty
                updated.casualStructure = updateStat(existingStruct, newValue: sv, alpha: 0.2, totalSamples: existingStruct.sampleCount + 1)
            }
        case .standard:
            let existing = updated.standardFillerRate ?? .empty
            updated.standardFillerRate = updateStat(existing, newValue: fillerRate, alpha: 0.2, totalSamples: existing.sampleCount + 1)
        case .elevated:
            let existing = updated.elevatedFillerRate ?? .empty
            updated.elevatedFillerRate = updateStat(existing, newValue: fillerRate, alpha: 0.2, totalSamples: existing.sampleCount + 1)
        case .high:
            let existing = updated.highFillerRate ?? .empty
            updated.highFillerRate = updateStat(existing, newValue: fillerRate, alpha: 0.2, totalSamples: existing.sampleCount + 1)
            let existingPace = updated.highPace ?? .empty
            updated.highPace = updateStat(existingPace, newValue: wpm, alpha: 0.2, totalSamples: existingPace.sampleCount + 1)
            let existingScore = updated.highScore ?? .empty
            updated.highScore = updateStat(existingScore, newValue: score, alpha: 0.2, totalSamples: existingScore.sampleCount + 1)
            let existingDur = updated.highDuration ?? .empty
            updated.highDuration = updateStat(existingDur, newValue: dur, alpha: 0.2, totalSamples: existingDur.sampleCount + 1)
            if let sv = structureValue {
                let existingStruct = updated.highStructure ?? .empty
                updated.highStructure = updateStat(existingStruct, newValue: sv, alpha: 0.2, totalSamples: existingStruct.sampleCount + 1)
            }
        }

        return updated
    }

    // MARK: - Prompt Context

    /// Generates a baseline summary string for inclusion in AI evaluation prompts.
    static func promptContext(
        baseline: CommunicationBaseline,
        pressure: PressureProfile,
        currentPressureLevel: PressureLevel = .standard,
        styleGoal: String? = nil,
        includeComparisonMechanics: Bool = true
    ) -> String {
        guard baseline.overallConfidence >= .tentative else {
            return "Baseline: Not yet established (fewer than 3 qualifying sessions)."
        }

        var lines: [String] = []
        lines.append("--- SPEAKER BASELINE (confidence: \(baseline.overallConfidence.label)) ---")

        if includeComparisonMechanics,
           let fillerRate = baseline.currentComparisonFillerRate {
            lines.append("Filler rate: \(String(format: "%.1f", fillerRate))/min (range: \(baseline.fillerRate.rangeLabel))")
        }
        if includeComparisonMechanics,
           let paceWPM = baseline.currentComparisonPaceWPM {
            lines.append("Pace: \(Int(paceWPM)) WPM (range: \(baseline.pace.rangeLabel))")
        }
        if baseline.durationTendency.isReliable {
            lines.append("Typical duration: \(Int(baseline.durationTendency.value))s")
        }
        if baseline.averageScore.isReliable {
            lines.append("Average score: \(String(format: "%.1f", baseline.averageScore.value))/10")
        }
        if baseline.hedgingRate.isReliable {
            lines.append("Hedging rate: \(String(format: "%.1f", baseline.hedgingRate.value)) hedge phrases/min")
        }
        if baseline.pitchVariation.isReliable {
            let label = baseline.pitchVariation.value < 0.35 ? "varied"
                : baseline.pitchVariation.value < 0.65 ? "mixed" : "flat"
            lines.append("Pitch delivery baseline: \(label) (monotone score \(String(format: "%.2f", baseline.pitchVariation.value)))")
        }

        // Category quality signals
        let categorySignals: [(String, BaselineStat)] = [
            ("Opening", baseline.openingStrength),
            ("Closing", baseline.closingStrength),
            ("Structure", baseline.structureQuality),
            ("Depth", baseline.answerDepth),
            ("Clarity", baseline.clarity),
        ]
        let reliableCategories = categorySignals.filter { $0.1.isReliable }
        if !reliableCategories.isEmpty {
            let descriptions = reliableCategories.map { name, stat -> String in
                let level = stat.value >= 2.5 ? "strong" : stat.value >= 1.8 ? "moderate" : "developing"
                return "\(name): \(level) (\(String(format: "%.1f", stat.value))/3)"
            }
            lines.append("Category averages: \(descriptions.joined(separator: ", "))")
        }

        let promptStrengths = promptSummaryItems(
            baseline.topStrengths,
            includeComparisonMechanics: includeComparisonMechanics
        )
        if !promptStrengths.isEmpty {
            lines.append("Consistent strengths: \(promptStrengths.joined(separator: ", "))")
        }
        let promptBlockers = promptSummaryItems(
            baseline.persistentBlockers,
            includeComparisonMechanics: includeComparisonMechanics
        )
        if !promptBlockers.isEmpty {
            lines.append("Persistent blockers: \(promptBlockers.joined(separator: ", "))")
        }

        // Verbal habits are historical occurrence evidence. A custom clutch
        // word can itself be a filler, so the whole block follows the same
        // comparison-mechanic boundary rather than filtering by label.
        if includeComparisonMechanics {
            let significantClutch = baseline.clutchWordFrequencies.filter {
                $0.value.isReliable && $0.value.value >= 1.5
            }
            if !significantClutch.isEmpty {
                let descriptions = significantClutch
                    .sorted { $0.value.value > $1.value.value }
                    .prefix(3)
                    .map { "\"\($0.key)\" (~\(String(format: "%.1f", $0.value.value))x/session)" }
                lines.append("Verbal habits (clutch words): \(descriptions.joined(separator: ", "))")
            }
        }

        // Pressure context
        lines.append("")
        lines.append("Current session pressure: \(currentPressureLevel.label)")

        if includeComparisonMechanics,
           let resilience = pressure.pressureResilience {
            lines.append("Pressure resilience: \(String(format: "%.0f", resilience * 100))%")
        }

        if let worstDim = pressure.mostAffectedDimension(
            includingComparisonMechanics: includeComparisonMechanics
        ),
           let delta = pressure.pressureDelta(for: worstDim), delta > 0 {
            lines.append("Most affected under pressure: \(worstDim.label)")
        }

        for insight in pressure.pressureInsights(
            includingComparisonMechanics: includeComparisonMechanics
        ).prefix(2) {
            lines.append("Pressure pattern: \(insight)")
        }

        // Style goal
        if let goal = styleGoal, !goal.isEmpty {
            lines.append("")
            lines.append("Speaker's style goal: \(goal)")
            lines.append("Evaluate whether this session moves toward that style goal.")
        }

        lines.append("")
        lines.append("Compare this session against the baseline. Note deviations — positive or negative.")
        return lines.joined(separator: "\n")
    }

    private static func promptSummaryItems(
        _ items: [String],
        includeComparisonMechanics: Bool
    ) -> [String] {
        guard !includeComparisonMechanics else { return items }
        return items.filter { !mentionsComparisonMechanic($0) }
    }

    private static func mentionsComparisonMechanic(_ text: String) -> Bool {
        let pattern = #"\b(?:fillers?|pace|pacing|wpm|words?\s+per\s+minute|tempo|cadence)\b"#
        return text.range(
            of: pattern,
            options: [.regularExpression, .caseInsensitive]
        ) != nil
    }

    // MARK: - Session Comparison

    /// Generates comparison strings for a session vs baseline.
    /// Returns a dictionary of dimension → comparison string.
    static func sessionComparison(session: PracticeSession, baseline: CommunicationBaseline) -> [String: String] {
        var comparisons: [String: String] = [:]

        if baseline.fillerRate.isReliable,
           let sessionRate = FillerBurden.quantityQualified(session)?.ratePerMinute {
            let delta = sessionRate - baseline.fillerRate.value
            if abs(delta) > 0.3 {
                let direction = delta > 0 ? "above" : "below"
                comparisons["Fillers"] = "\(String(format: "%.1f", sessionRate))/min (\(direction) your baseline of \(String(format: "%.1f", baseline.fillerRate.value)))"
            } else {
                comparisons["Fillers"] = "\(String(format: "%.1f", sessionRate))/min (in your normal range)"
            }
        }

        if baseline.pace.isReliable,
           let wpm = SessionQualifier.quantityQualifiedWordsPerMinute(session) {
            let displayedWPM = Int(wpm.rounded())
            if wpm < baseline.pace.percentile25 {
                comparisons["Pace"] = "\(displayedWPM) WPM (slower than your usual \(Int(baseline.pace.percentile25))–\(Int(baseline.pace.percentile75)))"
            } else if wpm > baseline.pace.percentile75 {
                comparisons["Pace"] = "\(displayedWPM) WPM (faster than your usual \(Int(baseline.pace.percentile25))–\(Int(baseline.pace.percentile75)))"
            } else {
                comparisons["Pace"] = "\(displayedWPM) WPM (in your zone)"
            }
        }

        if baseline.averageScore.isReliable, let score = session.score {
            let delta = Double(score) - baseline.averageScore.value
            if delta > 0.5 {
                comparisons["Score"] = "\(score)/10 (above your average of \(String(format: "%.1f", baseline.averageScore.value)))"
            } else if delta < -0.5 {
                comparisons["Score"] = "\(score)/10 (below your average of \(String(format: "%.1f", baseline.averageScore.value)))"
            }
        }

        return comparisons
    }

    // MARK: - Private Helpers

    private static func buildStat(from values: [Double], allSamples: Int) -> BaselineStat {
        guard !values.isEmpty else { return .empty }
        let sorted = values.sorted()
        let mean = values.reduce(0, +) / Double(values.count)
        let p25Index = max(0, Int(Double(sorted.count) * 0.25))
        let p75Index = min(sorted.count - 1, Int(Double(sorted.count) * 0.75))

        return BaselineStat(
            value: mean,
            sampleCount: values.count,
            confidence: BaselineConfidence.from(sessionCount: allSamples),
            trend: .stable,  // Trend is determined by TrendAnalyzer, not here
            percentile25: sorted[p25Index],
            percentile75: sorted[p75Index]
        )
    }

    /// Category ratings live on trend snapshots, not on the sessions themselves,
    /// so the snapshot roster is passed in rather than read from the shared store
    /// here. `compute` owns that resolution, which keeps this a pure mapping and
    /// lets deterministic fixtures state their own evidence.
    private static func buildCategoryStat(
        from snapshots: [SkillSnapshot],
        dimension: String,
        allSamples: Int
    ) -> BaselineStat {
        // Map: "Good" = 3, "OK" = 2, "Could improve" = 1
        let ratingValues: [Double] = snapshots.compactMap { snapshot -> Double? in
            guard let ratingStr = snapshot.categoryRatings[dimension] else { return nil }
            switch ratingStr {
            case "Good": return 3.0
            case "OK": return 2.0
            case "Could improve": return 1.0
            default: return nil
            }
        }
        guard !ratingValues.isEmpty else { return .empty }
        let recent = Array(ratingValues.prefix(20))
        return buildStat(from: recent, allSamples: allSamples)
    }

    /// Builds BaselineStat entries for the top 5 clutch words.
    /// Uses total occurrences / session count to get a per-session frequency stat.
    /// Pass `ClutchWordStore.shared.topClutchWords` from a @MainActor context.
    static func buildClutchWordStats(from entries: [ClutchWordEntry]) -> [String: BaselineStat] {
        let top5 = Array(entries.prefix(5))
        guard !top5.isEmpty else { return [:] }

        var result: [String: BaselineStat] = [:]
        for entry in top5 {
            guard entry.sessionCount >= 2 else { continue } // Need at least 2 sessions to be meaningful
            let avgPerSession = Double(entry.totalOccurrences) / Double(entry.sessionCount)
            result[entry.word] = BaselineStat(
                value: avgPerSession,
                sampleCount: entry.sessionCount,
                confidence: BaselineConfidence.from(sessionCount: entry.sessionCount),
                trend: .stable,
                percentile25: avgPerSession * 0.7,
                percentile75: avgPerSession * 1.3
            )
        }
        return result
    }

    private static func updateStat(_ stat: BaselineStat, newValue: Double, alpha: Double, totalSamples: Int) -> BaselineStat {
        let newMean: Double
        if stat.sampleCount == 0 {
            newMean = newValue
        } else {
            newMean = (1.0 - alpha) * stat.value + alpha * newValue
        }

        // Update percentiles with simple EMA as well
        let newP25: Double
        let newP75: Double
        if stat.sampleCount == 0 {
            newP25 = newValue
            newP75 = newValue
        } else {
            if newValue < stat.percentile25 {
                newP25 = (1.0 - alpha * 1.5) * stat.percentile25 + alpha * 1.5 * newValue
                newP75 = stat.percentile75
            } else if newValue > stat.percentile75 {
                newP25 = stat.percentile25
                newP75 = (1.0 - alpha * 1.5) * stat.percentile75 + alpha * 1.5 * newValue
            } else {
                newP25 = stat.percentile25
                newP75 = stat.percentile75
            }
        }

        return BaselineStat(
            value: newMean,
            sampleCount: totalSamples,
            confidence: BaselineConfidence.from(sessionCount: totalSamples),
            trend: stat.trend,
            percentile25: newP25,
            percentile75: newP75
        )
    }

    private static func identifyStrengths(_ baseline: CommunicationBaseline) -> [String] {
        var strengths: [String] = []
        if baseline.fillerRate.isReliable && baseline.fillerRate.value < 1.5 {
            strengths.append("Filler control")
        }
        if baseline.pace.isReliable && ConversationalPaceBand.contains(baseline.pace.value) {
            strengths.append("Pace control")
        }
        if baseline.hedgingRate.isReliable && baseline.hedgingRate.value < 1.0 {
            strengths.append("Directness")
        }
        if baseline.openingStrength.isReliable && baseline.openingStrength.value >= 2.5 {
            strengths.append("Opening strength")
        }
        if baseline.closingStrength.isReliable && baseline.closingStrength.value >= 2.5 {
            strengths.append("Closing strength")
        }
        if baseline.structureQuality.isReliable && baseline.structureQuality.value >= 2.5 {
            strengths.append("Structure")
        }
        if baseline.pitchVariation.isReliable && baseline.pitchVariation.value <= 0.35 {
            strengths.append("Vocal variety")
        }
        return Array(strengths.prefix(3))
    }

    private static func identifyBlockers(_ baseline: CommunicationBaseline) -> [String] {
        guard baseline.qualifyingSessionCount >= 10 else { return [] }
        var blockers: [String] = []
        if baseline.fillerRate.value > 4.0 {
            blockers.append("Filler words")
        }
        if baseline.pace.isReliable && (baseline.pace.value > 170 || baseline.pace.value < 90) {
            blockers.append("Pace control")
        }
        if baseline.hedgingRate.isReliable && baseline.hedgingRate.value > 4.0 {
            blockers.append("Hedging language")
        }
        if baseline.openingStrength.isReliable && baseline.openingStrength.value < 1.5 {
            blockers.append("Opening strength")
        }
        if baseline.structureQuality.isReliable && baseline.structureQuality.value < 1.5 {
            blockers.append("Structure")
        }
        // Persistently flat delivery (≥0.75 monotone score across 5+ reliable
        // pitch reads) is a real coachable pattern.
        if baseline.pitchVariation.isReliable && baseline.pitchVariation.sampleCount >= 5 && baseline.pitchVariation.value >= 0.75 {
            blockers.append("Monotone delivery")
        }
        return blockers
    }
}

// MARK: - Baseline Store

#if canImport(SwiftUI)

@MainActor
final class BaselineStore: ObservableObject {
    static let shared = BaselineStore()

    @Published private(set) var baseline: CommunicationBaseline = .empty
    @Published private(set) var pressureProfile: PressureProfile = .empty

    private let baselineKey = "communicationBaseline"
    private let pressureKey = "pressureProfile"

    private init() {
        load()
    }

    /// Rebuild baseline from full session history. Call on launch and account switch.
    func rebuild(from sessions: [PracticeSession]) {
        baseline = BaselineEngine.computeWithClutchWords(from: sessions)
        pressureProfile = BaselineEngine.computePressureProfile(from: sessions)
        save()
        UserTrajectoryCache.shared.invalidate()
    }

    /// Incrementally update with a new session.
    func recordSession(_ session: PracticeSession, pressure: PressureLevel) {
        guard baseline.usesCurrentComparisonMetrics else {
            rebuild(from: PracticeSessionStore.shared.sessions)
            return
        }
        baseline = BaselineEngine.updateWithClutchWords(baseline, with: session)
        pressureProfile = BaselineEngine.updatePressureProfile(pressureProfile, session: session, pressure: pressure)
        save()
        UserTrajectoryCache.shared.invalidate()
    }

    func recordMiniDrillOutcome(_ outcome: MiniDrillOutcome, prompt: String?) {
        if !baseline.usesCurrentComparisonMetrics {
            rebuild(from: PracticeSessionStore.shared.sessions)
        }
        ClutchWordStore.shared.analyzeSession(transcript: outcome.transcript, prompt: prompt)
        baseline = BaselineEngine.updateWithMiniDrill(baseline, outcome: outcome)
        save()
        UserTrajectoryCache.shared.invalidate()
    }

    func reloadForCurrentAccount() {
        load(rebuildOnRecipeMismatch: true)
        UserTrajectoryCache.shared.invalidate()
    }

    #if DEBUG
    /// Process-local injection for deterministic UI/evaluation fixtures. Unlike
    /// `rebuild`, this does not persist the fixture into the simulator's account
    /// defaults, so a source-bound evidence run cannot contaminate the next run.
    func replaceForDebug(
        _ baseline: CommunicationBaseline,
        pressureProfile: PressureProfile
    ) {
        self.baseline = baseline
        self.pressureProfile = pressureProfile
        UserTrajectoryCache.shared.invalidate()
    }
    #endif

    func endSession() {
        baseline = .empty
        pressureProfile = .empty
        UserTrajectoryCache.shared.invalidate()
    }

    // MARK: - Persistence

    private func save() {
        let accountID = accountStorageKey()
        if let data = try? JSONEncoder().encode(baseline) {
            UserDefaults.standard.set(data, forKey: "\(baselineKey).\(accountID)")
        }
        if let data = try? JSONEncoder().encode(pressureProfile) {
            UserDefaults.standard.set(data, forKey: "\(pressureKey).\(accountID)")
        }
    }

    private func load(rebuildOnRecipeMismatch: Bool = false) {
        let accountID = accountStorageKey()
        if let data = UserDefaults.standard.data(forKey: "\(baselineKey).\(accountID)"),
           let decoded = try? JSONDecoder().decode(CommunicationBaseline.self, from: data),
           decoded.usesCurrentComparisonMetrics {
            baseline = decoded
        } else {
            guard rebuildOnRecipeMismatch else {
                baseline = .empty
                pressureProfile = .empty
                return
            }
            // Practice sessions hydrate before BaselineStore in the account
            // registry. Rebuild both aggregates from current-epoch rows rather
            // than blending a legacy persisted recipe into the first new rep.
            rebuild(from: PracticeSessionStore.shared.sessions)
            return
        }
        if let data = UserDefaults.standard.data(forKey: "\(pressureKey).\(accountID)"),
           let decoded = try? JSONDecoder().decode(PressureProfile.self, from: data) {
            pressureProfile = decoded
        } else {
            pressureProfile = .empty
        }
    }

    private func accountStorageKey() -> String {
        if let id = KeychainHelper.load(key: "NoumAccountID"), !id.isEmpty {
            return id
        }
        return "guest"
    }
}

#endif
