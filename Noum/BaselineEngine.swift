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

    // Layer 1: Fundamentals
    var fillerRate: BaselineStat         // Fillers per minute
    var pace: BaselineStat               // Average WPM
    var paceVariance: BaselineStat       // Std dev of WPM across sessions
    var durationTendency: BaselineStat   // Typical speaking length (seconds)

    // Layer 2: Structure & Content
    var openingStrength: BaselineStat    // From category ratings (1-3 scale)
    var closingStrength: BaselineStat
    var structureQuality: BaselineStat
    var answerDepth: BaselineStat
    var clarity: BaselineStat

    // Layer 3: Style Signals
    var vocabularyRange: BaselineStat    // Unique word ratio

    // Layer 4: Overall
    var averageScore: BaselineStat

    // Computed summaries
    var topStrengths: [String]           // Skill area names consistently strong
    var persistentBlockers: [String]     // Areas stuck weak for 10+ sessions

    var overallConfidence: BaselineConfidence {
        BaselineConfidence.from(sessionCount: qualifyingSessionCount)
    }

    static let empty = CommunicationBaseline(
        lastUpdated: Date(),
        sessionCount: 0,
        qualifyingSessionCount: 0,
        fillerRate: .empty,
        pace: .empty,
        paceVariance: .empty,
        durationTendency: .empty,
        openingStrength: .empty,
        closingStrength: .empty,
        structureQuality: .empty,
        answerDepth: .empty,
        clarity: .empty,
        vocabularyRange: .empty,
        averageScore: .empty,
        topStrengths: [],
        persistentBlockers: []
    )
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

    /// Human-readable pressure insight, or nil if not enough data
    var pressureInsight: String? {
        guard let casual = casualFillerRate, casual.isReliable,
              let high = highFillerRate, high.isReliable else { return nil }
        let diff = high.value - casual.value
        if diff > 1.5 {
            return "Your filler rate jumps from \(String(format: "%.1f", casual.value))/min to \(String(format: "%.1f", high.value))/min under pressure."
        } else if diff < -0.5 {
            return "You actually use fewer fillers under pressure — you focus up."
        } else {
            return "Your filler control holds steady regardless of pressure."
        }
    }

    static let empty = PressureProfile()
}

// MARK: - Session Qualifier

/// Determines whether a session should contribute to the baseline.
enum SessionQualifier {
    static let minimumDuration: TimeInterval = 15
    static let minimumWordCount: Int = 20
    static let minimumConfidence: Double = 0.5

    static func qualifies(_ session: PracticeSession) -> Bool {
        guard session.duration >= minimumDuration else { return false }
        guard session.wordCount >= minimumWordCount else { return false }
        if let confidence = session.transcriptConfidence, confidence < minimumConfidence {
            return false
        }
        return true
    }
}

// MARK: - Baseline Engine

/// Computes and maintains the communication baseline from session history.
/// Uses exponential moving averages with a recency bias.
enum BaselineEngine {

    // MARK: - Full Recompute

    /// Recomputes the entire baseline from session history.
    /// Called on app launch and after account switch.
    static func compute(from sessions: [PracticeSession]) -> CommunicationBaseline {
        let qualifying = sessions.filter { SessionQualifier.qualifies($0) }
        guard !qualifying.isEmpty else { return .empty }

        // Sort most recent first
        let sorted = qualifying.sorted { $0.date > $1.date }
        let recent = Array(sorted.prefix(20))

        var baseline = CommunicationBaseline.empty
        baseline.sessionCount = sessions.count
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

        // Category ratings (Opening, Closing, Structure, Depth, Clarity)
        // Map "Good" = 3, "OK" = 2, "Could improve" = 1
        baseline.openingStrength = buildCategoryStat(from: recent, dimension: "Opening", allSamples: qualifying.count)
        baseline.closingStrength = buildCategoryStat(from: recent, dimension: "Close", allSamples: qualifying.count)
        baseline.structureQuality = buildCategoryStat(from: recent, dimension: "Structure", allSamples: qualifying.count)
        baseline.answerDepth = buildCategoryStat(from: recent, dimension: "Depth", allSamples: qualifying.count)
        baseline.clarity = buildCategoryStat(from: recent, dimension: "Clarity", allSamples: qualifying.count)

        // Vocabulary range (unique word ratio)
        let vocabRatios = recent.compactMap { s -> Double? in
            let words = s.transcript.lowercased().split { !$0.isLetter }
            guard words.count >= 20 else { return nil }
            return Double(Set(words).count) / Double(words.count)
        }
        if !vocabRatios.isEmpty {
            baseline.vocabularyRange = buildStat(from: vocabRatios, allSamples: qualifying.count)
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

    // MARK: - Incremental Update

    /// Updates an existing baseline with a new session.
    /// Uses EMA with recency bias: α = 0.5 for early sessions (< 5), 0.15 for established.
    static func update(_ baseline: CommunicationBaseline, with session: PracticeSession) -> CommunicationBaseline {
        guard SessionQualifier.qualifies(session) else {
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

        // Update strengths and blockers
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
        guard SessionQualifier.qualifies(session) else { return profile }

        let fillerRate = session.duration > 0 ? Double(session.fillerWordCount) / (session.duration / 60.0) : 0
        let wpm = Double(session.wordsPerMinute)
        let score = Double(session.score ?? 0)

        var updated = profile

        // We only track casual and high in detail for the MVP pressure gap analysis
        switch pressure {
        case .casual:
            let existing = updated.casualFillerRate ?? .empty
            updated.casualFillerRate = updateStat(existing, newValue: fillerRate, alpha: 0.2, totalSamples: existing.sampleCount + 1)
            let existingPace = updated.casualPace ?? .empty
            updated.casualPace = updateStat(existingPace, newValue: wpm, alpha: 0.2, totalSamples: existingPace.sampleCount + 1)
            let existingScore = updated.casualScore ?? .empty
            updated.casualScore = updateStat(existingScore, newValue: score, alpha: 0.2, totalSamples: existingScore.sampleCount + 1)
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
        }

        return updated
    }

    // MARK: - Prompt Context

    /// Generates a baseline summary string for inclusion in AI evaluation prompts.
    static func promptContext(baseline: CommunicationBaseline, pressure: PressureProfile) -> String {
        guard baseline.overallConfidence >= .tentative else {
            return "Baseline: Not yet established (fewer than 3 qualifying sessions)."
        }

        var lines: [String] = []
        lines.append("--- SPEAKER BASELINE (confidence: \(baseline.overallConfidence.label)) ---")

        if baseline.fillerRate.isReliable {
            lines.append("Filler rate: \(String(format: "%.1f", baseline.fillerRate.value))/min (range: \(baseline.fillerRate.rangeLabel))")
        }
        if baseline.pace.isReliable {
            lines.append("Pace: \(Int(baseline.pace.value)) WPM (range: \(baseline.pace.rangeLabel))")
        }
        if baseline.durationTendency.isReliable {
            lines.append("Typical duration: \(Int(baseline.durationTendency.value))s")
        }
        if baseline.averageScore.isReliable {
            lines.append("Average score: \(String(format: "%.1f", baseline.averageScore.value))/10")
        }
        if !baseline.topStrengths.isEmpty {
            lines.append("Consistent strengths: \(baseline.topStrengths.joined(separator: ", "))")
        }
        if !baseline.persistentBlockers.isEmpty {
            lines.append("Persistent blockers: \(baseline.persistentBlockers.joined(separator: ", "))")
        }

        if let insight = pressure.pressureInsight {
            lines.append("Pressure pattern: \(insight)")
        }

        lines.append("Compare this session against the baseline. Note deviations — positive or negative.")
        return lines.joined(separator: "\n")
    }

    // MARK: - Session Comparison

    /// Generates comparison strings for a session vs baseline.
    /// Returns a dictionary of dimension → comparison string.
    static func sessionComparison(session: PracticeSession, baseline: CommunicationBaseline) -> [String: String] {
        var comparisons: [String: String] = [:]

        if baseline.fillerRate.isReliable {
            let sessionRate = session.duration > 0 ? Double(session.fillerWordCount) / (session.duration / 60.0) : 0
            let delta = sessionRate - baseline.fillerRate.value
            if abs(delta) > 0.3 {
                let direction = delta > 0 ? "above" : "below"
                comparisons["Fillers"] = "\(String(format: "%.1f", sessionRate))/min (\(direction) your baseline of \(String(format: "%.1f", baseline.fillerRate.value)))"
            } else {
                comparisons["Fillers"] = "\(String(format: "%.1f", sessionRate))/min (in your normal range)"
            }
        }

        if baseline.pace.isReliable {
            let wpm = Double(session.wordsPerMinute)
            if wpm < baseline.pace.percentile25 {
                comparisons["Pace"] = "\(session.wordsPerMinute) WPM (slower than your usual \(Int(baseline.pace.percentile25))–\(Int(baseline.pace.percentile75)))"
            } else if wpm > baseline.pace.percentile75 {
                comparisons["Pace"] = "\(session.wordsPerMinute) WPM (faster than your usual \(Int(baseline.pace.percentile25))–\(Int(baseline.pace.percentile75)))"
            } else {
                comparisons["Pace"] = "\(session.wordsPerMinute) WPM (in your zone)"
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

    private static func buildCategoryStat(from sessions: [PracticeSession], dimension: String, allSamples: Int) -> BaselineStat {
        // Category ratings live in SkillTrendStore snapshots, not directly on PracticeSession.
        // For baseline, we'll use the SkillTrendStore data when available.
        // For now, return empty — this gets populated via the trend store integration.
        return .empty
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
        if baseline.pace.isReliable && baseline.pace.value >= 110 && baseline.pace.value <= 150 {
            strengths.append("Pace control")
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
        if baseline.openingStrength.isReliable && baseline.openingStrength.value < 1.5 {
            blockers.append("Opening strength")
        }
        if baseline.structureQuality.isReliable && baseline.structureQuality.value < 1.5 {
            blockers.append("Structure")
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
        baseline = BaselineEngine.compute(from: sessions)
        // Rebuild pressure profile from scratch
        var profile = PressureProfile.empty
        for session in sessions {
            let pressure = session.pressureLevel
            profile = BaselineEngine.updatePressureProfile(profile, session: session, pressure: pressure)
        }
        pressureProfile = profile
        save()
    }

    /// Incrementally update with a new session.
    func recordSession(_ session: PracticeSession, pressure: PressureLevel) {
        baseline = BaselineEngine.update(baseline, with: session)
        pressureProfile = BaselineEngine.updatePressureProfile(pressureProfile, session: session, pressure: pressure)
        save()
    }

    func reloadForCurrentAccount() {
        load()
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

    private func load() {
        let accountID = accountStorageKey()
        if let data = UserDefaults.standard.data(forKey: "\(baselineKey).\(accountID)"),
           let decoded = try? JSONDecoder().decode(CommunicationBaseline.self, from: data) {
            baseline = decoded
        } else {
            baseline = .empty
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
