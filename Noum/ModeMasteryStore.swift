import Foundation
import Combine
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Per-Mode Mastery
//
// Each practice mode trains a different skill (composure under a clock,
// pressure tolerance, filler awareness, conversational realism). The aggregate
// XP/rank ladder in `ProfileManager` rewards general activity — but it doesn't
// answer "where am I weakest, where am I strongest" at the mode level.
//
// `ModeMasteryStore` derives per-mode mastery from the session history. It is
// a pure projection of `PracticeSessionStore.sessions` — no separate
// persistence, no double accounting. Rebuilds when sessions change.

/// Snapshot of a single mode's mastery state.
struct ModeMasterySnapshot: Equatable, Identifiable {
    let mode: PracticeMode
    let totalXP: Int
    let sessionsLogged: Int
    let level: Int
    let xpIntoLevel: Int
    let xpForNextLevel: Int
    let title: String

    var id: PracticeMode { mode }

    /// 0…1 progress toward next level. 1.0 when at max level.
    var progressToNext: Double {
        guard xpForNextLevel > 0 else { return 1.0 }
        return min(1.0, Double(xpIntoLevel) / Double(xpForNextLevel))
    }

    /// True when the player has reached the highest mastery tier.
    var isMaxed: Bool {
        level >= ModeMasteryRank.maxLevel
    }
}

/// Cumulative XP thresholds and tier names for the mastery ladder.
/// Same shape across all modes so the UI is a single component.
enum ModeMasteryRank {
    static let maxLevel = 10

    /// XP required to reach a given level (cumulative, level 1 = 0).
    private static let thresholds: [Int] = [
        0,      // 1
        200,    // 2
        500,    // 3
        1_000,  // 4
        1_700,  // 5
        2_700,  // 6
        4_000,  // 7
        5_700,  // 8
        7_800,  // 9
        10_500  // 10
    ]

    /// Returns the level (1...maxLevel) for a given total XP.
    static func level(for xp: Int) -> Int {
        var level = 1
        for (i, threshold) in thresholds.enumerated() {
            if xp >= threshold { level = i + 1 }
        }
        return level
    }

    /// XP into the current level (0…<xpForNextLevel(level)).
    static func xpInto(level: Int, totalXP: Int) -> Int {
        let idx = max(1, min(level, thresholds.count)) - 1
        return max(0, totalXP - thresholds[idx])
    }

    /// XP needed to advance from `level` to `level + 1`. 0 when at max.
    static func xpForNext(after level: Int) -> Int {
        let idx = max(1, min(level, thresholds.count)) - 1
        guard idx + 1 < thresholds.count else { return 0 }
        return thresholds[idx + 1] - thresholds[idx]
    }

    /// Mode-flavoured title shown next to the level number. Stays on-voice —
    /// no chirpy badge names, no exclamation marks.
    static func title(level: Int, mode: PracticeMode) -> String {
        let l = max(1, min(level, maxLevel))
        switch mode {
        case .timed:
            return ["Drafting", "Drafting", "Steady", "Structured", "Composed",
                    "Composed", "Polished", "Polished", "Authoritative", "Master"][l - 1]
        case .suddenDeath:
            return ["Reactive", "Reactive", "Quickfire", "Quickfire", "Sharp",
                    "Sharp", "Unflinching", "Unflinching", "Unfazed", "Master"][l - 1]
        case .ahCounter:
            return ["Tuning", "Tuning", "Aware", "Aware", "Clean",
                    "Clean", "Refined", "Refined", "Crystal", "Master"][l - 1]
        case .imConversation:
            return ["Acquaintance", "Acquaintance", "Conversant", "Conversant", "Attuned",
                    "Attuned", "Trusted", "Trusted", "Anchored", "Master"][l - 1]
        }
    }

    /// Snapshot factory. `xp` is total XP earned in this mode across all sessions.
    static func snapshot(mode: PracticeMode, totalXP: Int, sessionsLogged: Int) -> ModeMasterySnapshot {
        let lvl = level(for: totalXP)
        return ModeMasterySnapshot(
            mode: mode,
            totalXP: totalXP,
            sessionsLogged: sessionsLogged,
            level: lvl,
            xpIntoLevel: xpInto(level: lvl, totalXP: totalXP),
            xpForNextLevel: xpForNext(after: lvl),
            title: title(level: lvl, mode: mode)
        )
    }
}

#if canImport(SwiftUI)

/// Observable projection of session history → per-mode mastery snapshots.
@MainActor
final class ModeMasteryStore: ObservableObject {
    static let shared = ModeMasteryStore()

    @Published private(set) var snapshots: [PracticeMode: ModeMasterySnapshot] = [:]

    private let sessionStore: PracticeSessionStore
    private var cancellables: Set<AnyCancellable> = []

    private init(sessionStore: PracticeSessionStore? = nil) {
        // Resolved in the init body rather than via default parameter so
        // accessing `PracticeSessionStore.shared` (main-actor-isolated)
        // happens inside the init's @MainActor context, not at the
        // default-parameter evaluation site. Explicit branch instead of
        // `??` because `??`'s RHS is a nonisolated autoclosure.
        let resolvedStore: PracticeSessionStore
        if let provided = sessionStore {
            resolvedStore = provided
        } else {
            resolvedStore = PracticeSessionStore.shared
        }
        self.sessionStore = resolvedStore
        rebuild(from: resolvedStore.sessions)
        resolvedStore.$sessions
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sessions in
                self?.rebuild(from: sessions)
            }
            .store(in: &cancellables)
    }

    /// O(n) rebuild — small enough at typical session volumes that we don't
    /// need incremental updates.
    private func rebuild(from sessions: [PracticeSession]) {
        var totals: [PracticeMode: Int] = [:]
        var counts: [PracticeMode: Int] = [:]
        for session in sessions {
            counts[session.mode, default: 0] += 1
            if let xp = session.xpEarned, xp > 0 {
                totals[session.mode, default: 0] += xp
            }
        }
        var next: [PracticeMode: ModeMasterySnapshot] = [:]
        for mode in [PracticeMode.timed, .suddenDeath, .ahCounter, .imConversation] {
            next[mode] = ModeMasteryRank.snapshot(
                mode: mode,
                totalXP: totals[mode] ?? 0,
                sessionsLogged: counts[mode] ?? 0
            )
        }
        snapshots = next
    }

    /// Convenience accessor — always returns a snapshot (level 1 / 0 XP if untouched).
    func snapshot(for mode: PracticeMode) -> ModeMasterySnapshot {
        snapshots[mode] ?? ModeMasteryRank.snapshot(mode: mode, totalXP: 0, sessionsLogged: 0)
    }

    /// Sorted by level desc → totalXP desc. Used for "best mode" surfaces.
    var orderedSnapshots: [ModeMasterySnapshot] {
        let modes: [PracticeMode] = [.timed, .suddenDeath, .ahCounter, .imConversation]
        return modes
            .map { snapshot(for: $0) }
            .sorted { lhs, rhs in
                if lhs.level != rhs.level { return lhs.level > rhs.level }
                return lhs.totalXP > rhs.totalXP
            }
    }

    /// True when no mode has any logged sessions. Used to hide the surface
    /// entirely on first launch instead of showing four empty rails.
    var isEmpty: Bool {
        snapshots.values.allSatisfy { $0.sessionsLogged == 0 }
    }
}
#endif
