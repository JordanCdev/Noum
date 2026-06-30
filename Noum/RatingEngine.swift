//
//  RatingEngine.swift
//  Noum
//
//  Speaking rating system. ELO-inspired rating that reflects current ability,
//  not time invested. Only rated sessions (Pressure Mode) move the rating.
//  Also tracks personal bests and weekly improvement.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Rating Snapshot

struct RatingSnapshot: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let rating: Int
    let delta: Int
    let sessionId: UUID
    let pressureLevel: PressureLevel

    init(date: Date = Date(), rating: Int, delta: Int, sessionId: UUID, pressureLevel: PressureLevel) {
        self.id = UUID()
        self.date = date
        self.rating = rating
        self.delta = delta
        self.sessionId = sessionId
        self.pressureLevel = pressureLevel
    }
}

// MARK: - Personal Best

enum PBCategory: String, Codable, CaseIterable {
    case highestScore           // Best overall session score
    case longestCleanRun        // Most consecutive words without a filler
    case lowestFillerRate       // Best fillers/minute (lower is better)
    case highestRating          // Peak speaking rating
    case longestPracticeStreak  // Most consecutive days
    case bestPressureScore      // Best score under high pressure
}

struct PersonalBestRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let category: PBCategory
    let value: Double
    let sessionId: UUID?
    let date: Date
    let mode: PracticeMode?

    init(category: PBCategory, value: Double, sessionId: UUID? = nil, date: Date = Date(), mode: PracticeMode? = nil) {
        self.id = UUID()
        self.category = category
        self.value = value
        self.sessionId = sessionId
        self.date = date
        self.mode = mode
    }
}

// MARK: - Speaking Rating

struct SpeakingRating: Codable, Equatable {
    var overall: Int                        // 100-1000
    var peakRating: Int                     // All-time highest
    var ratingHistory: [RatingSnapshot]     // Last 50 changes
    var personalBests: [PersonalBestRecord]
    var totalRatedSessions: Int
    /// Peak rating within the current ISO week. Resets to `overall` whenever
    /// `weekPeakISOWeek` differs from the current week — prevents stale
    /// "best of week" claims from carrying over into the next week.
    /// Optional for backwards-compat: legacy data without this field decodes cleanly.
    var weekPeakRating: Int
    /// ISO week (1-53) the `weekPeakRating` was set in. Combined with
    /// `weekPeakISOYear` to detect a week boundary.
    var weekPeakISOWeek: Int
    /// Year the `weekPeakRating` was set in. Needed because ISO weeks wrap.
    var weekPeakISOYear: Int

    var currentTrend: TrendDirection {
        guard ratingHistory.count >= 3 else { return .stable }
        let recent = ratingHistory.prefix(3)
        let totalDelta = recent.reduce(0) { $0 + $1.delta }
        if totalDelta > 10 { return .improving }
        if totalDelta < -10 { return .declining }
        return .stable
    }

    var weeklyDelta: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return ratingHistory
            .filter { $0.date >= weekAgo }
            .reduce(0) { $0 + $1.delta }
    }

    /// True once the user has at least one real rated result. The default
    /// 400 rating is a starting line, not an earned peak/tier.
    var hasRatedEvidence: Bool {
        totalRatedSessions > 0 || !ratingHistory.isEmpty
    }

    /// True when `weekPeakRating` was set in the current ISO week.
    /// Caller can use this to decide whether to surface the value as a
    /// "this week" stat or to treat it as stale.
    var isWeekPeakCurrent: Bool {
        let comps = Calendar.current.dateComponents([.weekOfYear, .yearForWeekOfYear], from: Date())
        return comps.weekOfYear == weekPeakISOWeek && comps.yearForWeekOfYear == weekPeakISOYear
    }

    enum CodingKeys: String, CodingKey {
        case overall, peakRating, ratingHistory, personalBests, totalRatedSessions
        case weekPeakRating, weekPeakISOWeek, weekPeakISOYear
    }

    init(
        overall: Int,
        peakRating: Int,
        ratingHistory: [RatingSnapshot],
        personalBests: [PersonalBestRecord],
        totalRatedSessions: Int,
        weekPeakRating: Int? = nil,
        weekPeakISOWeek: Int? = nil,
        weekPeakISOYear: Int? = nil
    ) {
        self.overall = overall
        self.peakRating = peakRating
        self.ratingHistory = ratingHistory
        self.personalBests = personalBests
        self.totalRatedSessions = totalRatedSessions
        self.weekPeakRating = weekPeakRating ?? overall
        let comps = Calendar.current.dateComponents([.weekOfYear, .yearForWeekOfYear], from: Date())
        self.weekPeakISOWeek = weekPeakISOWeek ?? (comps.weekOfYear ?? 1)
        self.weekPeakISOYear = weekPeakISOYear ?? (comps.yearForWeekOfYear ?? 2026)
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.overall = try c.decode(Int.self, forKey: .overall)
        self.peakRating = try c.decode(Int.self, forKey: .peakRating)
        self.ratingHistory = try c.decode([RatingSnapshot].self, forKey: .ratingHistory)
        self.personalBests = try c.decode([PersonalBestRecord].self, forKey: .personalBests)
        self.totalRatedSessions = try c.decode(Int.self, forKey: .totalRatedSessions)
        let comps = Calendar.current.dateComponents([.weekOfYear, .yearForWeekOfYear], from: Date())
        self.weekPeakRating = try c.decodeIfPresent(Int.self, forKey: .weekPeakRating) ?? overall
        self.weekPeakISOWeek = try c.decodeIfPresent(Int.self, forKey: .weekPeakISOWeek) ?? (comps.weekOfYear ?? 1)
        self.weekPeakISOYear = try c.decodeIfPresent(Int.self, forKey: .weekPeakISOYear) ?? (comps.yearForWeekOfYear ?? 2026)
    }

    static let initial = SpeakingRating(
        overall: 400,
        peakRating: 400,
        ratingHistory: [],
        personalBests: [],
        totalRatedSessions: 0,
        weekPeakRating: 400
    )
}

// MARK: - Rating Engine

enum RatingEngine {

    /// Calculate rating delta for a rated session using ELO-inspired formula.
    /// K-factor decreases as rating increases (harder to climb at higher ratings).
    static func calculateDelta(currentRating: Int, sessionScore: Int) -> Int {
        let k: Double
        if currentRating < 600 {
            k = 32
        } else if currentRating < 800 {
            k = 24
        } else {
            k = 16
        }

        let expected = Double(currentRating) / 1000.0
        let actual = Double(sessionScore) / 10.0
        let delta = k * (actual - expected)

        return Int(delta.rounded())
    }

    /// Process a rated session and return the updated rating.
    static func processRatedSession(
        rating: SpeakingRating,
        sessionScore: Int,
        sessionId: UUID,
        pressureLevel: PressureLevel
    ) -> SpeakingRating {
        let delta = calculateDelta(currentRating: rating.overall, sessionScore: sessionScore)
        let newRating = max(100, min(1000, rating.overall + delta))

        let snapshot = RatingSnapshot(
            rating: newRating,
            delta: delta,
            sessionId: sessionId,
            pressureLevel: pressureLevel
        )

        var updated = rating
        updated.overall = newRating
        updated.totalRatedSessions += 1
        updated.ratingHistory.insert(snapshot, at: 0)
        if updated.ratingHistory.count > 50 {
            updated.ratingHistory = Array(updated.ratingHistory.prefix(50))
        }
        if newRating > updated.peakRating {
            updated.peakRating = newRating
        }

        // Maintain week peak. If the current ISO week differs from the stored
        // one, this is a brand-new week — reset peak to the new rating instead
        // of carrying the old number forward (which would be a lie).
        let comps = Calendar.current.dateComponents([.weekOfYear, .yearForWeekOfYear], from: Date())
        let currentWeek = comps.weekOfYear ?? updated.weekPeakISOWeek
        let currentYear = comps.yearForWeekOfYear ?? updated.weekPeakISOYear
        if currentWeek != updated.weekPeakISOWeek || currentYear != updated.weekPeakISOYear {
            updated.weekPeakRating = newRating
            updated.weekPeakISOWeek = currentWeek
            updated.weekPeakISOYear = currentYear
        } else if newRating > updated.weekPeakRating {
            updated.weekPeakRating = newRating
        }

        return updated
    }

    /// Check and update personal bests from a session.
    /// Returns tuple: (updated rating with new PBs, list of new PB categories achieved)
    static func checkPersonalBests(
        rating: SpeakingRating,
        session: PracticeSession,
        currentStreak: Int
    ) -> (SpeakingRating, [PBCategory]) {
        var updated = rating
        var newPBs: [PBCategory] = []

        // Highest score
        if let score = session.score {
            let current = updated.personalBests.first { $0.category == .highestScore }
            if current == nil || Double(score) > current!.value {
                updated.personalBests.removeAll { $0.category == .highestScore }
                updated.personalBests.append(PersonalBestRecord(
                    category: .highestScore,
                    value: Double(score),
                    sessionId: session.id,
                    date: session.date,
                    mode: session.mode
                ))
                if current != nil { newPBs.append(.highestScore) }
            }
        }

        // Lowest filler rate (only for qualifying sessions)
        if session.duration >= 15, session.wordCount >= 20 {
            let rate = Double(session.fillerWordCount) / (session.duration / 60.0)
            let current = updated.personalBests.first { $0.category == .lowestFillerRate }
            if current == nil || rate < current!.value {
                updated.personalBests.removeAll { $0.category == .lowestFillerRate }
                updated.personalBests.append(PersonalBestRecord(
                    category: .lowestFillerRate,
                    value: rate,
                    sessionId: session.id,
                    date: session.date,
                    mode: session.mode
                ))
                if current != nil { newPBs.append(.lowestFillerRate) }
            }
        }

        // Longest clean run (words without a filler — approximate from transcript)
        if session.fillerWordCount == 0 && session.wordCount >= 30 {
            let current = updated.personalBests.first { $0.category == .longestCleanRun }
            let cleanWords = Double(session.wordCount)
            if current == nil || cleanWords > current!.value {
                updated.personalBests.removeAll { $0.category == .longestCleanRun }
                updated.personalBests.append(PersonalBestRecord(
                    category: .longestCleanRun,
                    value: cleanWords,
                    sessionId: session.id,
                    date: session.date,
                    mode: session.mode
                ))
                if current != nil { newPBs.append(.longestCleanRun) }
            }
        }

        // Best pressure score
        if session.pressureLevel >= .elevated, let score = session.score {
            let current = updated.personalBests.first { $0.category == .bestPressureScore }
            if current == nil || Double(score) > current!.value {
                updated.personalBests.removeAll { $0.category == .bestPressureScore }
                updated.personalBests.append(PersonalBestRecord(
                    category: .bestPressureScore,
                    value: Double(score),
                    sessionId: session.id,
                    date: session.date,
                    mode: session.mode
                ))
                if current != nil { newPBs.append(.bestPressureScore) }
            }
        }

        // Highest rating (updated separately when rating changes)

        // Longest practice streak
        if currentStreak > 0 {
            let current = updated.personalBests.first { $0.category == .longestPracticeStreak }
            if current == nil || Double(currentStreak) > current!.value {
                updated.personalBests.removeAll { $0.category == .longestPracticeStreak }
                updated.personalBests.append(PersonalBestRecord(
                    category: .longestPracticeStreak,
                    value: Double(currentStreak),
                    date: Date()
                ))
                if current != nil { newPBs.append(.longestPracticeStreak) }
            }
        }

        return (updated, newPBs)
    }

    /// Get a formatted display string for a personal best.
    static func formatPB(_ record: PersonalBestRecord) -> String {
        switch record.category {
        case .highestScore:
            return "\(Int(record.value))/10"
        case .longestCleanRun:
            return "\(Int(record.value)) words"
        case .lowestFillerRate:
            if record.value == 0 { return "0/min" }
            return "\(String(format: "%.1f", record.value))/min"
        case .highestRating:
            return "\(Int(record.value))"
        case .longestPracticeStreak:
            return "\(Int(record.value)) days"
        case .bestPressureScore:
            return "\(Int(record.value))/10"
        }
    }

    /// Human-readable title for a PB category.
    static func pbTitle(_ category: PBCategory) -> String {
        switch category {
        case .highestScore: return "Best Score"
        case .longestCleanRun: return "Longest Clean Run"
        case .lowestFillerRate: return "Best Filler Rate"
        case .highestRating: return "Peak Rating"
        case .longestPracticeStreak: return "Longest Streak"
        case .bestPressureScore: return "Best Under Pressure"
        }
    }

    /// Icon for a PB category.
    static func pbIcon(_ category: PBCategory) -> String {
        switch category {
        case .highestScore: return "star.fill"
        case .longestCleanRun: return "text.badge.checkmark"
        case .lowestFillerRate: return "waveform.path.ecg"
        case .highestRating: return "chart.line.uptrend.xyaxis"
        case .longestPracticeStreak: return "flame.fill"
        case .bestPressureScore: return "bolt.fill"
        }
    }
}

// MARK: - Rating Store

#if canImport(SwiftUI)

@MainActor
final class RatingStore: ObservableObject {
    static let shared = RatingStore()

    @Published private(set) var rating: SpeakingRating = .initial

    /// True when there's a fresh week-peak to celebrate on Home that hasn't
    /// been shown yet. Flipped on by `recordRatedSession` when the new
    /// week-peak strictly exceeds the last value Home consumed; flipped off
    /// by `markPeakGlowConsumed()` once the post-session glow card fades.
    ///
    /// Drives the M14 demotion of the "Personal best" purple hero from a
    /// permanent home anchor to a post-session glow. Never set on regression
    /// (per `never_punish_shame.md`): downward changes update the snapshot
    /// silently and never raise the glow.
    @Published private(set) var pendingPeakGlow: Bool = false

    private let storageKey = "speakingRating"
    /// Per-account persisted record of the last week-peak Home has already
    /// shown the glow for. We only raise `pendingPeakGlow` when the newly
    /// recorded peak strictly exceeds this value — so a brand-new install,
    /// a flat week, or a downward rating swing never re-triggers the glow.
    private let lastShownPeakKey = "speakingRating.lastShownWeekPeak"

    private init() {
        load()
    }

    /// Record a rated session. Returns the rating delta.
    @discardableResult
    func recordRatedSession(score: Int, sessionId: UUID, pressureLevel: PressureLevel) -> Int {
        let previousRating = rating.overall
        let previousWeekPeak = rating.weekPeakRating
        let previousWeekISO = (rating.weekPeakISOWeek, rating.weekPeakISOYear)
        rating = RatingEngine.processRatedSession(
            rating: rating,
            sessionScore: score,
            sessionId: sessionId,
            pressureLevel: pressureLevel
        )

        // Update peak rating PB
        if rating.overall >= rating.peakRating {
            rating.personalBests.removeAll { $0.category == .highestRating }
            rating.personalBests.append(PersonalBestRecord(
                category: .highestRating,
                value: Double(rating.peakRating),
                date: Date()
            ))
        }

        save()

        // M14: post-session peak glow — only fire upward, and only when the
        // new value strictly exceeds the last value Home has shown. A week
        // boundary that resets `weekPeakRating` down to `overall` should not
        // raise the glow even if the numeric value happens to equal a prior
        // peak. We require both (a) a real week-peak rise inside the SAME
        // ISO week, OR (b) a new ISO week whose peak exceeds the last shown
        // value. Both reduce to the same check against `lastShownWeekPeak`.
        let sameWeek = previousWeekISO.0 == rating.weekPeakISOWeek
            && previousWeekISO.1 == rating.weekPeakISOYear
        if rating.weekPeakRating > previousWeekPeak || !sameWeek {
            notePeakReachedForGlow()
        }

        UserTrajectoryCache.shared.invalidate()
        return rating.overall - previousRating
    }

    /// Called when the rating store mutates `weekPeakRating` upward as part
    /// of finalizing a session. Sets `pendingPeakGlow = true` iff the new
    /// week peak strictly exceeds the last value Home consumed, then
    /// persists the candidate so we don't re-fire on the next launch.
    ///
    /// Safe to call unconditionally — the strictly-greater guard means a
    /// flat or downward swing is a silent no-op.
    func notePeakReachedForGlow() {
        guard rating.hasRatedEvidence else { return }
        let lastShown = loadLastShownPeak()
        guard rating.weekPeakRating > lastShown else { return }
        pendingPeakGlow = true
        saveLastShownPeak(rating.weekPeakRating)
    }

    /// Called after the Home glow card finishes its display window. Clears
    /// the pending flag so the card doesn't re-appear on the next Home
    /// visit. The persisted `lastShownWeekPeak` (set when the glow was
    /// raised) gates future fires until the user earns a strictly higher
    /// peak.
    func markPeakGlowConsumed() {
        guard pendingPeakGlow else { return }
        pendingPeakGlow = false
    }

    /// Highest rating reached inside the current ISO week, derived purely
    /// from `ratingHistory`. Nil when there are no rated sessions yet this
    /// week — surfaces drive the "Best in week" framing only when there's
    /// real evidence to show (no fake "—" placeholders).
    ///
    /// Note: `SpeakingRating.weekPeakRating` is the persisted snapshot
    /// maintained by `recordRatedSession`; this computed property is the
    /// pure read alongside it so the peak wall can render from a single
    /// source of truth (history) without coupling to the persistence step.
    var peakRatingThisWeek: Int? {
        var calendar = Calendar(identifier: .iso8601)
        calendar.firstWeekday = 2
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return nil
        }
        let thisWeek = rating.ratingHistory.filter { snapshot in
            weekInterval.contains(snapshot.date)
        }
        return thisWeek.map(\.rating).max()
    }

    /// Check personal bests for a session (called for all sessions, not just rated).
    /// Returns list of new PB categories.
    @discardableResult
    func checkPersonalBests(session: PracticeSession, currentStreak: Int) -> [PBCategory] {
        let (updated, newPBs) = RatingEngine.checkPersonalBests(
            rating: rating,
            session: session,
            currentStreak: currentStreak
        )
        rating = updated
        save()
        UserTrajectoryCache.shared.invalidate()
        return newPBs
    }

    func reloadForCurrentAccount() {
        load()
        UserTrajectoryCache.shared.invalidate()
    }

    func endSession() {
        rating = .initial
        pendingPeakGlow = false
        UserTrajectoryCache.shared.invalidate()
    }

    #if DEBUG
    /// Debug-only injector for `DevSeedData`. Lets seed profiles ship a
    /// plausible peak rating so the home / Profile premium hero surfaces.
    /// Never called in release builds.
    func replaceForDebug(_ rating: SpeakingRating) {
        self.rating = rating
        save()
        UserTrajectoryCache.shared.invalidate()
    }
    #endif

    /// Get the PB record for a category, if it exists.
    func personalBest(for category: PBCategory) -> PersonalBestRecord? {
        rating.personalBests.first { $0.category == category }
    }

    // MARK: - Persistence

    private func save() {
        let accountID = accountStorageKey()
        if let data = try? JSONEncoder().encode(rating) {
            UserDefaults.standard.set(data, forKey: "\(storageKey).\(accountID)")
        }
    }

    private func load() {
        let accountID = accountStorageKey()
        if let data = UserDefaults.standard.data(forKey: "\(storageKey).\(accountID)"),
           let decoded = try? JSONDecoder().decode(SpeakingRating.self, from: data) {
            rating = decoded
        } else {
            rating = .initial
        }
        // Glow is a UI-state flag, not part of `SpeakingRating`. Never
        // restore it from a previous launch — the glow is only meaningful
        // for the few seconds after a freshly-finished session.
        pendingPeakGlow = false
    }

    private func loadLastShownPeak() -> Int {
        let accountID = accountStorageKey()
        let key = "\(lastShownPeakKey).\(accountID)"
        // `object(forKey:)` lets us distinguish "never shown" from "shown 0".
        // First-ever fire seeds the cursor at the current week peak so a
        // brand-new install with no rated reps yet doesn't celebrate.
        if UserDefaults.standard.object(forKey: key) == nil {
            UserDefaults.standard.set(rating.weekPeakRating, forKey: key)
            return rating.weekPeakRating
        }
        return UserDefaults.standard.integer(forKey: key)
    }

    private func saveLastShownPeak(_ value: Int) {
        let accountID = accountStorageKey()
        UserDefaults.standard.set(value, forKey: "\(lastShownPeakKey).\(accountID)")
    }

    private func accountStorageKey() -> String {
        if let id = KeychainHelper.load(key: "NoumAccountID"), !id.isEmpty {
            return id
        }
        return "guest"
    }
}

#endif
