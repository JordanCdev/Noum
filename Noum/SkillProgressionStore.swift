#if canImport(SwiftUI)
import Foundation
import SwiftUI

// MARK: - Skill Progression Store
//
// Per-account snapshot of each `SkillArea`'s last-seen `SkillLevel`.
// After every session finalize, compare current trends against the stored
// snapshot — any skill that crossed UPWARD (e.g., developing → solid)
// queues a `SkillLevelUpEvent` for the summary to celebrate.
//
// We never queue events for downward crossings. Per the brand rule + the
// product anti-goal "never punish-shame a miss in copy", drops happen
// silently.
//
// We also never celebrate first-time observations. If we have no prior
// snapshot for a skill (the user is new, or the skill wasn't ranked yet),
// the current level is recorded silently with no event. The first event
// requires an actual upward transition.

@MainActor
@available(iOS 17.0, *)
final class SkillProgressionStore: ObservableObject {
    static let shared = SkillProgressionStore()

    /// Events from the most recent `record(_:)` call that haven't been
    /// shown yet. Summary view consumes these once and clears.
    @Published private(set) var pendingLevelUps: [SkillLevelUpEvent] = []

    private let storageKeyPrefix = "noum.skillProgression."

    private init() {}

    /// Compare trends against the stored snapshot, queue events for any
    /// upward crossings, then update the snapshot. Called from
    /// SessionFinalizer after `SkillTrendStore` has recorded the new
    /// session.
    func record(trends: [SkillTrend]) {
        var snapshot = loadSnapshot()
        var newEvents: [SkillLevelUpEvent] = []

        // Defense in depth for the celebration invariant. The snapshot is
        // mutated inside this loop, so a second trend for an area already seen
        // in THIS batch would compare against its sibling rather than against
        // history and manufacture an upward crossing out of two unrelated
        // measurements. `TrendAnalyzer.analyze` no longer emits duplicates;
        // this makes the guarantee hold for any caller.
        var areasRecordedThisBatch: Set<SkillArea> = []

        for trend in trends {
            guard areasRecordedThisBatch.insert(trend.skillArea).inserted else { continue }
            let previous = snapshot[trend.skillArea]
            // Always update the snapshot to the new level so we don't
            // re-fire on the same level next session.
            snapshot[trend.skillArea] = trend.currentLevel

            guard let previous else { continue }
            // Only celebrate upward crossings. Comparable on SkillLevel
            // is ordinal: weak < developing < solid < strong.
            if trend.currentLevel > previous {
                newEvents.append(
                    SkillLevelUpEvent(
                        skillArea: trend.skillArea,
                        previousLevel: previous,
                        newLevel: trend.currentLevel,
                        date: Date()
                    )
                )
            }
        }

        save(snapshot)

        if !newEvents.isEmpty {
            pendingLevelUps.append(contentsOf: newEvents)
        }
    }

    /// Drop a single event after the UI has shown it.
    func consume(_ event: SkillLevelUpEvent) {
        pendingLevelUps.removeAll { $0.id == event.id }
    }

    /// Drop all pending events. Used when the user backs out of summary
    /// without dismissing each event individually — we don't want a
    /// stale stack of events showing up on the next session.
    func consumeAll() {
        pendingLevelUps.removeAll()
    }

    /// Account switch — wipe pending events; the new account starts
    /// fresh. Persisted snapshot is per-account already so it switches
    /// automatically via the account-keyed storage key.
    func reloadForCurrentAccount() {
        pendingLevelUps.removeAll()
    }

    /// Test hook — wipe the persisted snapshot for the current account.
    /// Used by tests and the developer "reset progression" surface.
    func reset() {
        UserDefaults.standard.removeObject(forKey: storageKey)
        pendingLevelUps.removeAll()
    }

    // MARK: - Storage

    private var storageKey: String {
        let id = AuthManager.shared.currentAccountID ?? "guest"
        return storageKeyPrefix + id
    }

    private func loadSnapshot() -> [SkillArea: SkillLevel] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: SkillLevel].self, from: data) else {
            return [:]
        }
        var out: [SkillArea: SkillLevel] = [:]
        for (rawArea, level) in decoded {
            if let area = SkillArea(rawValue: rawArea) {
                out[area] = level
            }
        }
        return out
    }

    private func save(_ snapshot: [SkillArea: SkillLevel]) {
        var dict: [String: SkillLevel] = [:]
        for (area, level) in snapshot {
            dict[area.rawValue] = level
        }
        guard let data = try? JSONEncoder().encode(dict) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

// MARK: - Event

struct SkillLevelUpEvent: Identifiable, Equatable {
    let id = UUID()
    let skillArea: SkillArea
    let previousLevel: SkillLevel
    let newLevel: SkillLevel
    let date: Date

    /// User-facing copy. Voice rule: direct, second-person, ≤ 12 words.
    var headline: String {
        "\(skillArea.displayName) leveled up"
    }

    var subline: String {
        "\(previousLevel.rawValue.capitalized) → \(newLevel.rawValue.capitalized)"
    }

    /// Detection rule for tests + diagnostics.
    static func detect(
        previous: [SkillArea: SkillLevel],
        current trends: [SkillTrend]
    ) -> [SkillLevelUpEvent] {
        trends.compactMap { trend -> SkillLevelUpEvent? in
            guard let prev = previous[trend.skillArea], trend.currentLevel > prev else { return nil }
            return SkillLevelUpEvent(
                skillArea: trend.skillArea,
                previousLevel: prev,
                newLevel: trend.currentLevel,
                date: Date()
            )
        }
    }
}

#endif
