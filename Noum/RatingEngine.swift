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

    static let initial = SpeakingRating(
        overall: 400,
        peakRating: 400,
        ratingHistory: [],
        personalBests: [],
        totalRatedSessions: 0
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

    private let storageKey = "speakingRating"

    private init() {
        load()
    }

    /// Record a rated session. Returns the rating delta.
    @discardableResult
    func recordRatedSession(score: Int, sessionId: UUID, pressureLevel: PressureLevel) -> Int {
        let previousRating = rating.overall
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
        return rating.overall - previousRating
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
        return newPBs
    }

    func reloadForCurrentAccount() {
        load()
    }

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
    }

    private func accountStorageKey() -> String {
        if let id = KeychainHelper.load(key: "NoumAccountID"), !id.isEmpty {
            return id
        }
        return "guest"
    }
}

#endif
