//
//  RewardEngine.swift
//  Noum
//
//  Central reward event system. All reward moments flow through here.
//  Handles event emission, haptic triggers, and celebration coordination.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Reward Tier

enum RewardTier: Int, Comparable {
    case micro = 1
    case medium = 2
    case major = 3

    static func < (lhs: RewardTier, rhs: RewardTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Reward Event

#if canImport(SwiftUI)

enum RewardEvent: Identifiable, Equatable {
    // Tier 1: Micro-wins — subtle, ambient acknowledgment
    case statImproved(stat: String, delta: String)
    case drillCompleted(skillArea: SkillArea, succeeded: Bool)
    case sessionCompleted(score: Int, xpEarned: Int)
    case returnedAfterAbsence(days: Int)

    // Tier 2: Medium wins — visible, satisfying feedback
    case scoreIncreased(from: Int, to: Int)
    case skillLevelUp(skill: SkillArea, newLevel: SkillLevel)
    case drillStreak(skill: SkillArea, count: Int)
    case zeroFillerSession(duration: TimeInterval)
    case sessionStreak(days: Int)

    // Tier 3: Major wins — full celebration
    case levelUp(from: String, to: String)
    case personalBest(mode: String, score: Int, previousBest: Int)
    case skillResolved(skill: SkillArea)
    case majorSessionStreak(days: Int)
    case sessionCountMilestone(count: Int)

    var id: String {
        switch self {
        case .statImproved(let stat, let delta): return "stat-\(stat)-\(delta)"
        case .drillCompleted(let area, let ok): return "drill-\(area.rawValue)-\(ok)"
        case .sessionCompleted(let s, let x): return "session-\(s)-\(x)"
        case .returnedAfterAbsence(let d): return "returned-\(d)"
        case .scoreIncreased(let f, let t): return "score-\(f)-\(t)"
        case .skillLevelUp(let skill, let lv): return "skilllv-\(skill.rawValue)-\(lv.rawValue)"
        case .drillStreak(let skill, let c): return "drillstrk-\(skill.rawValue)-\(c)"
        case .zeroFillerSession(let d): return "zerofiller-\(d)"
        case .sessionStreak(let d): return "streak-\(d)"
        case .levelUp(let f, let t): return "levelup-\(f)-\(t)"
        case .personalBest(let m, let s, _): return "pb-\(m)-\(s)"
        case .skillResolved(let skill): return "resolved-\(skill.rawValue)"
        case .majorSessionStreak(let d): return "majorstreak-\(d)"
        case .sessionCountMilestone(let c): return "count-\(c)"
        }
    }

    var tier: RewardTier {
        switch self {
        case .statImproved, .drillCompleted, .sessionCompleted, .returnedAfterAbsence:
            return .micro
        case .scoreIncreased, .skillLevelUp, .drillStreak, .zeroFillerSession, .sessionStreak:
            return .medium
        case .levelUp, .personalBest, .skillResolved, .majorSessionStreak, .sessionCountMilestone:
            return .major
        }
    }
}

// MARK: - Reward Engine

@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class RewardEngine: ObservableObject {
    static let shared = RewardEngine()

    @Published private(set) var pendingEvents: [RewardEvent] = []
    @Published private(set) var activeCelebration: RewardEvent?

    private init() {}

    /// Emit a reward event. Triggers haptic and queues for UI consumption.
    func emit(_ event: RewardEvent) {
        pendingEvents.append(event)
        triggerHaptic(for: event)

        if event.tier == .major && activeCelebration == nil {
            activeCelebration = event
        }
    }

    /// Emit multiple events at once (e.g., post-session evaluation).
    func emit(_ events: [RewardEvent]) {
        for event in events {
            emit(event)
        }
    }

    /// Mark an event as consumed (UI has displayed it).
    func consume(_ event: RewardEvent) {
        pendingEvents.removeAll { $0.id == event.id }
    }

    /// Dismiss the active celebration overlay.
    func dismissCelebration() {
        if let current = activeCelebration {
            consume(current)
        }
        activeCelebration = nil

        // Check if there's another major event queued
        if let next = pendingEvents.first(where: { $0.tier == .major }) {
            activeCelebration = next
        }
    }

    /// Clear all pending events.
    func reset() {
        pendingEvents.removeAll()
        activeCelebration = nil
    }

    // MARK: - Haptic Dispatch

    private func triggerHaptic(for event: RewardEvent) {
        switch event {
        case .statImproved:
            CoachHaptic.trendBreakthrough()
        case .drillCompleted(_, let succeeded):
            if succeeded { CoachHaptic.drillSuccess() } else { CoachHaptic.drillIncomplete() }
        case .sessionCompleted:
            CoachHaptic.selectionTap()
        case .returnedAfterAbsence:
            break // no haptic for ambient welcome-back
        case .scoreIncreased:
            CoachHaptic.scoreReveal()
        case .skillLevelUp:
            CoachHaptic.skillLevelUp()
        case .drillStreak:
            CoachHaptic.streakAchievement()
        case .zeroFillerSession:
            CoachHaptic.trendBreakthrough()
        case .sessionStreak:
            CoachHaptic.streakAchievement()
        case .levelUp:
            CoachHaptic.levelUp()
        case .personalBest:
            CoachHaptic.personalBest()
        case .skillResolved:
            CoachHaptic.trendBreakthrough()
        case .majorSessionStreak:
            CoachHaptic.levelUp()
        case .sessionCountMilestone:
            CoachHaptic.streakAchievement()
        }
    }

    // MARK: - Post-Session Event Detection

    /// Analyze session results and emit appropriate reward events.
    /// Call this from SummaryView's onAppear after session data is locked.
    func evaluateSession(
        score: Int,
        previousBestScore: Int?,
        xpEarned: Int,
        fillerCount: Int,
        duration: TimeInterval,
        sessionStreak: Int,
        sessionCount: Int,
        levelBefore: String,
        levelAfter: String,
        mode: String,
        recentScores: [Int],
        trends: [SkillArea: SkillTrend]
    ) {
        var events: [RewardEvent] = []

        // Session completed (always)
        events.append(.sessionCompleted(score: score, xpEarned: xpEarned))

        // Level-up
        if levelBefore != levelAfter {
            events.append(.levelUp(from: levelBefore, to: levelAfter))
        }

        // Personal best
        if let prevBest = previousBestScore, score > prevBest, score >= 6, prevBest > 0 {
            events.append(.personalBest(mode: mode, score: score, previousBest: prevBest))
        }

        // Score increase vs recent baseline
        let recentAvg = recentScores.isEmpty ? 0 : recentScores.reduce(0, +) / recentScores.count
        if score > recentAvg && recentAvg > 0 {
            events.append(.scoreIncreased(from: recentAvg, to: score))
        }

        // Zero-filler session
        if fillerCount == 0 && duration >= 30 {
            events.append(.zeroFillerSession(duration: duration))
        }

        // Session streak milestones
        if [3, 7].contains(sessionStreak) {
            events.append(.sessionStreak(days: sessionStreak))
        } else if [14, 30].contains(sessionStreak) {
            events.append(.majorSessionStreak(days: sessionStreak))
        }

        // Session count milestones
        if [10, 25, 50, 100].contains(sessionCount) {
            events.append(.sessionCountMilestone(count: sessionCount))
        }

        // Skill trends — detect resolved and level-ups
        for (area, trend) in trends {
            if trend.direction == .resolved {
                events.append(.skillResolved(skill: area))
            }
        }

        // Filler improvement (compare to recent baseline if available)
        // This is a micro-win tracked via stat deltas in the UI rather than here

        // Emit all detected events, highest tier first
        let sorted = events.sorted { $0.tier > $1.tier }
        emit(sorted)
    }

    /// Analyze drill completion and emit appropriate events.
    func evaluateDrill(
        skillArea: SkillArea,
        succeeded: Bool,
        streak: Int
    ) {
        var events: [RewardEvent] = []

        events.append(.drillCompleted(skillArea: skillArea, succeeded: succeeded))

        if succeeded && streak >= 3 {
            events.append(.drillStreak(skill: skillArea, count: streak))
        }

        emit(events)
    }
}

#endif
