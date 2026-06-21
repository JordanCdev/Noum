import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Achievement Track

/// A "track" is one evolving progression line — e.g. Practice Volume.
/// Each track has ordered tiers that share a single visual identity.
enum AchievementTrack: String, Codable, CaseIterable {
    case volume         // Total sessions completed
    case consistency    // Streak milestones
    case clarity        // Clean/filler-free delivery
    case scores         // High score benchmarks
    case endurance      // Session duration milestones
    case modes          // Mode exploration & mastery
    case mastery        // Rare long-term accomplishments

    var label: String {
        switch self {
        case .volume:      return "Practice Volume"
        case .consistency: return "Consistency"
        case .clarity:     return "Clarity"
        case .scores:      return "Scores"
        case .endurance:   return "Endurance"
        case .modes:       return "Modes"
        case .mastery:     return "Mastery"
        }
    }

    var symbol: String {
        switch self {
        case .volume:      return "flame.fill"
        case .consistency: return "calendar.badge.clock"
        case .clarity:     return "checkmark.seal.fill"
        case .scores:      return "star.fill"
        case .endurance:   return "timer"
        case .modes:       return "square.grid.2x2.fill"
        case .mastery:     return "crown.fill"
        }
    }

    var tint: Color {
        switch self {
        case .volume:      return Color(red: 0.22, green: 0.55, blue: 0.38)
        case .consistency: return Color(red: 0.90, green: 0.52, blue: 0.12)
        case .clarity:     return Color(red: 0.20, green: 0.60, blue: 0.90)
        case .scores:      return Color(red: 0.85, green: 0.55, blue: 0.15)
        case .endurance:   return Color(red: 0.45, green: 0.35, blue: 0.80)
        case .modes:       return Color(red: 0.55, green: 0.30, blue: 0.85)
        case .mastery:     return Color(red: 0.85, green: 0.68, blue: 0.18)
        }
    }

    /// Gradient pair used by the icon system.
    var gradient: [Color] {
        switch self {
        case .volume:
            return [Color(red: 0.22, green: 0.58, blue: 0.40), Color(red: 0.14, green: 0.40, blue: 0.28)]
        case .consistency:
            return [Color(red: 0.92, green: 0.55, blue: 0.14), Color(red: 0.78, green: 0.38, blue: 0.08)]
        case .clarity:
            return [Color(red: 0.22, green: 0.58, blue: 0.92), Color(red: 0.14, green: 0.40, blue: 0.75)]
        case .scores:
            return [Color(red: 0.90, green: 0.60, blue: 0.18), Color(red: 0.75, green: 0.45, blue: 0.10)]
        case .endurance:
            return [Color(red: 0.50, green: 0.38, blue: 0.85), Color(red: 0.35, green: 0.22, blue: 0.70)]
        case .modes:
            return [Color(red: 0.58, green: 0.32, blue: 0.90), Color(red: 0.42, green: 0.20, blue: 0.72)]
        case .mastery:
            return [Color(red: 0.88, green: 0.72, blue: 0.22), Color(red: 0.72, green: 0.52, blue: 0.10)]
        }
    }

    /// Lighter accent gradient for borders and highlights.
    var accentGradient: [Color] {
        switch self {
        case .volume:
            return [Color(red: 0.30, green: 0.72, blue: 0.50), Color(red: 0.18, green: 0.55, blue: 0.35)]
        case .consistency:
            return [Color(red: 1.0, green: 0.68, blue: 0.22), Color(red: 0.92, green: 0.48, blue: 0.10)]
        case .clarity:
            return [Color(red: 0.35, green: 0.70, blue: 1.0), Color(red: 0.20, green: 0.50, blue: 0.92)]
        case .scores:
            return [Color(red: 1.0, green: 0.72, blue: 0.25), Color(red: 0.88, green: 0.55, blue: 0.12)]
        case .endurance:
            return [Color(red: 0.62, green: 0.48, blue: 1.0), Color(red: 0.45, green: 0.30, blue: 0.85)]
        case .modes:
            return [Color(red: 0.72, green: 0.45, blue: 1.0), Color(red: 0.52, green: 0.30, blue: 0.90)]
        case .mastery:
            return [Color(red: 1.0, green: 0.85, blue: 0.32), Color(red: 0.90, green: 0.65, blue: 0.15)]
        }
    }
}

// MARK: - Achievement Tier

/// Each tier within a track. Tier 0 = first milestone, higher = harder.
struct AchievementTier: Identifiable {
    let id: String
    let tierIndex: Int        // 0-based position within the track
    let title: String
    let description: String
    let symbolName: String
    let track: AchievementTrack
    let evaluate: ([PracticeSession], Int) -> (current: Int, target: Int)

    /// Total tiers in this tier's track — set during registration.
    var totalTiersInTrack: Int = 1
}

// MARK: - Unlock Record

struct AchievementUnlock: Codable, Identifiable {
    let id: String
    let unlockedAt: Date
}

// MARK: - Achievement Store

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class AchievementStore: ObservableObject {
    static let shared = AchievementStore()

    @Published private(set) var unlocks: [String: Date] = [:]
    @Published private(set) var newlyUnlocked: [String] = []

    private let storageKey = "noum_achievement_unlocks"

    private init() {
        load()
    }

    // MARK: - All Tiers (flat list)

    static let allTiers: [AchievementTier] = {
        var tiers: [AchievementTier] = []

        // ─── PRACTICE VOLUME ───────────────────────────
        let volumeSymbols = ["figure.walk", "figure.run", "figure.run.circle.fill", "flame.fill", "crown.fill"]
        let volumeTitles = ["First Rep", "Getting Reps In", "Double Digits", "Committed", "Centurion"]
        let volumeDescs = [
            "Complete your first practice session.",
            "Complete 5 practice sessions.",
            "Complete 10 practice sessions.",
            "Complete 25 practice sessions.",
            "Complete 100 practice sessions."
        ]
        let volumeTargets = [1, 5, 10, 25, 100]
        for i in 0..<5 {
            let target = volumeTargets[i]
            tiers.append(AchievementTier(
                id: "volume_\(target)",
                tierIndex: i,
                title: volumeTitles[i],
                description: volumeDescs[i],
                symbolName: volumeSymbols[i],
                track: .volume,
                evaluate: { sessions, _ in (min(sessions.count, target), target) }
            ))
        }

        // ─── CONSISTENCY ───────────────────────────────
        let streakTargets = [3, 7, 14, 30]
        let streakTitles = ["Rhythm Builder", "Week Warrior", "Fortnight Force", "Iron Habit"]
        let streakDescs = [
            "Practice 3 days in a row.",
            "Practice 7 days in a row.",
            "Practice 14 days in a row.",
            "Practice 30 days in a row."
        ]
        let streakSymbols = ["flame", "flame.fill", "flame.circle", "flame.circle.fill"]
        for i in 0..<4 {
            let target = streakTargets[i]
            tiers.append(AchievementTier(
                id: "streak_\(target)",
                tierIndex: i,
                title: streakTitles[i],
                description: streakDescs[i],
                symbolName: streakSymbols[i],
                track: .consistency,
                evaluate: { _, streak in (min(streak, target), target) }
            ))
        }

        // ─── CLARITY ───────────────────────────────────
        let clarityTargets = [1, 3, 10]
        let clarityTitles = ["Clean Run", "Squeaky Clean", "Silver Tongue"]
        let clarityDescs = [
            "Complete a session with zero filler words.",
            "Complete 3 zero-filler sessions.",
            "Complete 10 zero-filler sessions."
        ]
        let claritySymbols = ["checkmark.seal", "checkmark.seal.fill", "sparkle"]
        for i in 0..<3 {
            let target = clarityTargets[i]
            tiers.append(AchievementTier(
                id: "clarity_\(target)",
                tierIndex: i,
                title: clarityTitles[i],
                description: clarityDescs[i],
                symbolName: claritySymbols[i],
                track: .clarity,
                evaluate: { sessions, _ in
                    let count = sessions.filter { $0.fillerWordCount == 0 && $0.wordCount >= 12 }.count
                    return (min(count, target), target)
                }
            ))
        }

        // ─── SCORES ────────────────────────────────────
        let scoreTitles = ["Sharp Session", "Consistent Excellence", "Perfect 10"]
        let scoreDescs = [
            "Score 8 or higher in a session.",
            "Score 8+ in five different sessions.",
            "Score a perfect 10 in any session."
        ]
        let scoreSymbols = ["star", "star.fill", "10.circle.fill"]
        // Tier 0: 1 session >= 8
        tiers.append(AchievementTier(
            id: "score_8",
            tierIndex: 0,
            title: scoreTitles[0],
            description: scoreDescs[0],
            symbolName: scoreSymbols[0],
            track: .scores,
            evaluate: { sessions, _ in
                let count = sessions.filter { ($0.score ?? 0) >= 8 }.count
                return (min(count, 1), 1)
            }
        ))
        // Tier 1: 5 sessions >= 8
        tiers.append(AchievementTier(
            id: "score_8x5",
            tierIndex: 1,
            title: scoreTitles[1],
            description: scoreDescs[1],
            symbolName: scoreSymbols[1],
            track: .scores,
            evaluate: { sessions, _ in
                let count = sessions.filter { ($0.score ?? 0) >= 8 }.count
                return (min(count, 5), 5)
            }
        ))
        // Tier 2: perfect 10
        tiers.append(AchievementTier(
            id: "score_10",
            tierIndex: 2,
            title: scoreTitles[2],
            description: scoreDescs[2],
            symbolName: scoreSymbols[2],
            track: .scores,
            evaluate: { sessions, _ in
                let count = sessions.filter { ($0.score ?? 0) >= 10 }.count
                return (min(count, 1), 1)
            }
        ))

        // ─── ENDURANCE ─────────────────────────────────
        let enduranceTitles = ["Deep Dive", "Marathon Speaker"]
        let enduranceDescs = [
            "Complete a session lasting 2+ minutes.",
            "Complete a session lasting 5+ minutes."
        ]
        let enduranceSymbols = ["timer", "figure.run"]
        let enduranceTargets: [TimeInterval] = [120, 300]
        for i in 0..<2 {
            let target = enduranceTargets[i]
            tiers.append(AchievementTier(
                id: "endurance_\(Int(target))",
                tierIndex: i,
                title: enduranceTitles[i],
                description: enduranceDescs[i],
                symbolName: enduranceSymbols[i],
                track: .endurance,
                evaluate: { sessions, _ in
                    let count = sessions.filter { $0.duration >= target }.count
                    return (min(count, 1), 1)
                }
            ))
        }

        // ─── MODES ─────────────────────────────────────
        // Tier 0: Try every mode
        tiers.append(AchievementTier(
            id: "modes_explorer",
            tierIndex: 0,
            title: "Mode Explorer",
            description: "Try every practice mode at least once.",
            symbolName: "square.grid.2x2",
            track: .modes,
            evaluate: { sessions, _ in
                let allModes: Set<PracticeMode> = [.timed, .suddenDeath, .ahCounter, .imConversation]
                let tried = allModes.filter { mode in sessions.contains { $0.mode == mode } }
                return (tried.count, allModes.count)
            }
        ))
        // Tier 1: Pressure Drill survival (60s)
        tiers.append(AchievementTier(
            id: "modes_pressure_60",
            tierIndex: 1,
            title: "Minute Man",
            description: "Survive 60+ seconds in a Pressure Drill.",
            symbolName: "bolt.fill",
            track: .modes,
            evaluate: { sessions, _ in
                let count = sessions.filter { $0.mode == .suddenDeath && $0.duration >= 60 }.count
                return (min(count, 1), 1)
            }
        ))
        // Tier 2: Pressure Drill mastery (180s)
        tiers.append(AchievementTier(
            id: "modes_pressure_180",
            tierIndex: 2,
            title: "Pressure Proof",
            description: "Survive 3+ minutes in a Pressure Drill.",
            symbolName: "bolt.shield.fill",
            track: .modes,
            evaluate: { sessions, _ in
                let count = sessions.filter { $0.mode == .suddenDeath && $0.duration >= 180 }.count
                return (min(count, 1), 1)
            }
        ))
        // Tier 3: IM conversation depth
        tiers.append(AchievementTier(
            id: "modes_im_5",
            tierIndex: 3,
            title: "Connection Builder",
            description: "Complete 5 IM conversation sessions.",
            symbolName: "bubble.left.and.bubble.right.fill",
            track: .modes,
            evaluate: { sessions, _ in
                let count = sessions.filter { $0.mode == .imConversation }.count
                return (min(count, 5), 5)
            }
        ))

        // ─── MASTERY ───────────────────────────────────
        // Tier 0: Score improvement
        tiers.append(AchievementTier(
            id: "mastery_rising",
            tierIndex: 0,
            title: "Rising Tide",
            description: "Your last 5 sessions average higher than your first 5.",
            symbolName: "arrow.up.right",
            track: .mastery,
            evaluate: { sessions, _ in
                guard sessions.count >= 10 else { return (0, 1) }
                let sorted = sessions.sorted { $0.date < $1.date }
                let first5 = Double(sorted.prefix(5).compactMap(\.score).reduce(0, +)) /
                    max(1, Double(sorted.prefix(5).compactMap(\.score).count))
                let last5 = Double(sorted.suffix(5).compactMap(\.score).reduce(0, +)) /
                    max(1, Double(sorted.suffix(5).compactMap(\.score).count))
                return (last5 > first5 ? 1 : 0, 1)
            }
        ))
        // Tier 1: 1,000 total words
        tiers.append(AchievementTier(
            id: "mastery_1k_words",
            tierIndex: 1,
            title: "Thousand Words",
            description: "Speak a total of 1,000 words across all sessions.",
            symbolName: "text.justify.leading",
            track: .mastery,
            evaluate: { sessions, _ in
                let total = sessions.map(\.wordCount).reduce(0, +)
                return (min(total, 1000), 1000)
            }
        ))
        // Tier 2: 10,000 total words
        tiers.append(AchievementTier(
            id: "mastery_10k_words",
            tierIndex: 2,
            title: "Ten Thousand Words",
            description: "Speak a total of 10,000 words across all sessions.",
            symbolName: "book.fill",
            track: .mastery,
            evaluate: { sessions, _ in
                let total = sessions.map(\.wordCount).reduce(0, +)
                return (min(total, 10000), 10000)
            }
        ))

        // Set totalTiersInTrack on each tier
        let trackCounts = Dictionary(grouping: tiers, by: \.track).mapValues(\.count)
        for i in tiers.indices {
            tiers[i].totalTiersInTrack = trackCounts[tiers[i].track] ?? 1
        }

        return tiers
    }()

    /// Tiers grouped by track, in track order.
    static let tiersByTrack: [(track: AchievementTrack, tiers: [AchievementTier])] = {
        var result: [(AchievementTrack, [AchievementTier])] = []
        for track in AchievementTrack.allCases {
            let trackTiers = allTiers.filter { $0.track == track }.sorted { $0.tierIndex < $1.tierIndex }
            if !trackTiers.isEmpty {
                result.append((track, trackTiers))
            }
        }
        return result
    }()

    // MARK: - Evaluation

    @discardableResult
    func evaluate(sessions: [PracticeSession], streak: Int) -> [String] {
        var justUnlocked: [String] = []

        for tier in Self.allTiers {
            let (current, target) = tier.evaluate(sessions, streak)
            let isComplete = current >= target

            if isComplete && unlocks[tier.id] == nil {
                unlocks[tier.id] = Date()
                justUnlocked.append(tier.id)
            }
        }

        if !justUnlocked.isEmpty {
            newlyUnlocked = justUnlocked
            save()
        }

        return justUnlocked
    }

    func clearNewlyUnlocked() {
        newlyUnlocked = []
    }

#if DEBUG
    func resetForDebug() {
        unlocks = [:]
        newlyUnlocked = []
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
#endif

    /// Returns display statuses for all tiers.
    func allStatuses(sessions: [PracticeSession], streak: Int) -> [PracticeAchievementStatus] {
        Self.allTiers.map { tier in
            let (current, target) = tier.evaluate(sessions, streak)
            let isUnlocked = unlocks[tier.id] != nil
            let progress = target > 0 ? min(1.0, Double(current) / Double(target)) : 0

            return PracticeAchievementStatus(
                id: tier.id,
                title: tier.title,
                summary: tier.description,
                progress: progress,
                progressLabel: isUnlocked ? "Unlocked" : "\(current)/\(target)",
                isUnlocked: isUnlocked,
                symbolName: tier.symbolName
            )
        }
    }

    /// Lookup a tier by ID.
    static func tier(for id: String) -> AchievementTier? {
        allTiers.first { $0.id == id }
    }

    /// Backward-compatible lookup used by existing call sites.
    static func definition(for id: String) -> AchievementTier? {
        tier(for: id)
    }

    /// The highest unlocked tier index in a given track, or -1 if none.
    func highestUnlockedTier(in track: AchievementTrack) -> Int {
        let trackTiers = Self.allTiers.filter { $0.track == track }
        var highest = -1
        for t in trackTiers {
            if unlocks[t.id] != nil && t.tierIndex > highest {
                highest = t.tierIndex
            }
        }
        return highest
    }

    /// The next locked tier in a track (the one being progressed toward), if any.
    func nextTier(in track: AchievementTrack) -> AchievementTier? {
        let trackTiers = Self.allTiers.filter { $0.track == track }.sorted { $0.tierIndex < $1.tierIndex }
        return trackTiers.first { unlocks[$0.id] == nil }
    }

    // MARK: - Persistence

    private func save() {
        let records = unlocks.map { AchievementUnlock(id: $0.key, unlockedAt: $0.value) }
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([AchievementUnlock].self, from: data) else { return }
        unlocks = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0.unlockedAt) })
    }
}
#endif
