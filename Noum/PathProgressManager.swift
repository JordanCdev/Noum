import Foundation
import Combine
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Node status

/// Render-friendly state for a single node at a point in time.
struct PathNodeStatus: Identifiable, Equatable {
    let node: PathNode
    let progress: Double
    let isComplete: Bool
    let isCurrent: Bool

    var id: String { node.id }
}

struct PathUnlockSnapshot: Equatable {
    let unlockedNodeIDs: Set<String>
}

struct PathUnlockCelebration: Equatable {
    let nodeID: String
    let triggeringSessionID: UUID
}

enum PathUnlockCelebrationResolver {
    static func resolve(
        snapshot: PathUnlockSnapshot,
        currentUnlockedNodeIDs: Set<String>,
        triggeringSessionID: UUID,
        orderedNodeIDs: [String]
    ) -> PathUnlockCelebration? {
        let newlyUnlocked = currentUnlockedNodeIDs.subtracting(snapshot.unlockedNodeIDs)
        guard let nodeID = orderedNodeIDs.first(where: newlyUnlocked.contains) else {
            return nil
        }
        return PathUnlockCelebration(
            nodeID: nodeID,
            triggeringSessionID: triggeringSessionID
        )
    }
}

/// Persisted unlocks are durable compatibility state. A corrected live
/// criterion may tighten future evidence without silently revoking a node the
/// user already earned under an earlier app version.
enum PathUnlockPolicy {
    static func isComplete(
        nodeID: String,
        liveProgress: Double,
        unlockedNodeIDs: Set<String>
    ) -> Bool {
        unlockedNodeIDs.contains(nodeID) || liveProgress >= 1.0
    }
}

enum PathUnlockCodec {
    static func decode(_ data: Data?) -> Set<String> {
        guard let data,
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(decoded)
    }

    static func encode(_ nodeIDs: Set<String>) -> Data? {
        try? JSONEncoder().encode(nodeIDs.sorted())
    }
}

// MARK: - Path Progress Manager

#if canImport(SwiftUI)

/// Owns the user's path-progression state.
///
/// Source-of-truth split:
/// - Live progress for the *next* node is derived every render from sessions,
///   baseline, rating, streak — no stored values.
/// - Once a node hits 100% it gets persisted to `unlockedNodeIDs`. Persistence
///   means subsequent loss of underlying signal (e.g. rolling streak) doesn't
///   relock the node — the user reached it once and that's permanent.
@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class PathProgressManager: ObservableObject {
    static let shared = PathProgressManager()

    @Published private(set) var statuses: [PathNodeStatus] = []
    @Published private(set) var pendingCelebration: PathUnlockCelebration?

    var pendingCelebrationNodeID: String? { pendingCelebration?.nodeID }
    var pendingCelebrationSessionID: UUID? { pendingCelebration?.triggeringSessionID }

    private let unlockedKeyPrefix = "noum.pathProgress.unlocked."
    private let hasInitializedKeyPrefix = "noum.pathProgress.initialized."
    private var unlockedNodeIDs: Set<String> = []
    /// True after the first recompute completes. Until then, any nodes that
    /// are already at 100% are silently absorbed into `unlockedNodeIDs` —
    /// we never fire a celebration for nodes the user technically cleared
    /// before the M3 release shipped.
    private var hasCompletedInitialBackfill = false
    private var sessionsSubscription: AnyCancellable?
    private var ratingSubscription: AnyCancellable?
    private var streakSubscription: AnyCancellable?
    private var masterySubscription: AnyCancellable?
    private var lessonsSubscription: AnyCancellable?

    private init() {
        loadUnlocked()
        recompute()
        observeStateChanges()
    }

    // MARK: - Public API

    /// First incomplete node, if any. Used by the home "Your next node" card.
    var currentNode: PathNodeStatus? {
        statuses.first(where: { !$0.isComplete })
    }

    /// Coach-voice gating line for the current node — e.g.
    /// "Two clean pauses from unlocked." Returns nil when the path is
    /// cleared, when the current node has no readable distance, or when
    /// the input signal isn't measurable yet. Drops in under the node
    /// title on the home journey preview card.
    var currentNodeGatingPhrase: String? {
        guard let status = currentNode else { return nil }
        guard let entry = PathNodeRegistry.all.first(where: { $0.0.id == status.node.id }) else {
            return nil
        }
        return GatingPhrase.copy(for: entry.1, input: makeInput())
    }

    /// All completed nodes — for the "past" section of the path map.
    var completedNodes: [PathNodeStatus] {
        statuses.filter(\.isComplete)
    }

    /// The next 3 nodes after the current one — visible-but-locked.
    var upcomingNodes: [PathNodeStatus] {
        guard let currentIndex = statuses.firstIndex(where: { !$0.isComplete }) else {
            return []
        }
        let after = currentIndex + 1
        guard after < statuses.count else { return [] }
        return Array(statuses[after..<min(statuses.count, after + 3)])
    }

    /// True when there's at least one node beyond the visible window.
    var hasMaskedNodes: Bool {
        guard let currentIndex = statuses.firstIndex(where: { !$0.isComplete }) else {
            return false
        }
        return statuses.count > currentIndex + 4
    }

    /// Force a recompute. Called automatically when sessions, rating, streak,
    /// or mode mastery change. Updates `statuses` and silently absorbs any
    /// newly-completed nodes into `unlockedNodeIDs` so the persisted set stays
    /// in sync — but it never creates `pendingCelebration`. Celebration
    /// is reserved for the explicit post-session evaluation so async store ticks don't
    /// trigger a chain of overlays at launch.
    func recompute() {
        let input = makeInput()
        let registry = PathNodeRegistry.all

        var newStatuses: [PathNodeStatus] = []
        var newlyDiscovered: [String] = []

        var firstCurrentSet = false
        for (node, criterion) in registry {
            let isPersistedUnlock = unlockedNodeIDs.contains(node.id)
            let liveProgress = criterion.progress(for: input)
            let isComplete = PathUnlockPolicy.isComplete(
                nodeID: node.id,
                liveProgress: liveProgress,
                unlockedNodeIDs: unlockedNodeIDs
            )

            if isComplete && !isPersistedUnlock {
                newlyDiscovered.append(node.id)
            }

            let isCurrent = !isComplete && !firstCurrentSet
            if isCurrent { firstCurrentSet = true }

            newStatuses.append(
                PathNodeStatus(
                    node: node,
                    progress: isComplete ? 1.0 : liveProgress,
                    isComplete: isComplete,
                    isCurrent: isCurrent
                )
            )
        }

        statuses = newStatuses

        if !newlyDiscovered.isEmpty {
            unlockedNodeIDs.formUnion(newlyDiscovered)
            persistUnlocked()
        }

        if !hasCompletedInitialBackfill {
            hasCompletedInitialBackfill = true
            UserDefaults.standard.set(true, forKey: hasInitializedKey)
        }
    }

    /// Synchronizes pre-existing live progress before a new session mutates
    /// any store. The returned value remains stable even if a Combine sink
    /// silently recomputes before explicit finalization reaches the manager.
    func captureUnlockSnapshot() -> PathUnlockSnapshot {
        recompute()
        return PathUnlockSnapshot(unlockedNodeIDs: unlockedNodeIDs)
    }

    /// Called by the common practice finalizer after the exact session and its
    /// dependent rating/baseline state land. Comparing against the pre-append
    /// snapshot makes celebration delivery independent of run-loop ordering.
    func evaluateAfterSession(
        triggeringSessionID: UUID,
        from snapshot: PathUnlockSnapshot
    ) {
        recompute()
        guard pendingCelebration == nil else { return }
        pendingCelebration = PathUnlockCelebrationResolver.resolve(
            snapshot: snapshot,
            currentUnlockedNodeIDs: unlockedNodeIDs,
            triggeringSessionID: triggeringSessionID,
            orderedNodeIDs: PathNodeRegistry.all.map(\.0.id)
        )
    }

    /// Mark the celebration as seen so the overlay dismisses. The unlock
    /// itself remains persisted.
    func consumeCelebration() {
        pendingCelebration = nil
    }

    func reloadForCurrentAccount() {
        pendingCelebration = nil
        loadUnlocked()
        recompute()
    }

    // MARK: - Internals

    private func observeStateChanges() {
        sessionsSubscription = PracticeSessionStore.shared.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
        ratingSubscription = RatingStore.shared.$rating
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
        streakSubscription = StreakFreezeManager.shared.$currentStreak
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
        masterySubscription = ModeMasteryStore.shared.$snapshots
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
        lessonsSubscription = LessonStore.shared.$progress
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
    }

    private func makeInput() -> PathProgressInput {
        let lessonStore = LessonStore.shared
        let totalPasses = lessonStore.totalPracticePasses
        let maxPassCount = lessonStore.progress.values.map(\.practicePassCount).max() ?? 0
        return PathProgressInput(
            sessions: PracticeSessionStore.shared.sessions,
            currentStreak: StreakFreezeManager.shared.currentStreak,
            baseline: BaselineStore.shared.baseline,
            rating: RatingStore.shared.rating,
            modeMastery: ModeMasteryStore.shared.snapshots,
            totalLessonPasses: totalPasses,
            maxLessonPassCount: maxPassCount,
            now: Date()
        )
    }

    // MARK: - Persistence

    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private var unlockedKey: String {
        unlockedKeyPrefix + Self.currentAccountID()
    }

    private var hasInitializedKey: String {
        hasInitializedKeyPrefix + Self.currentAccountID()
    }

    private func loadUnlocked() {
        unlockedNodeIDs = PathUnlockCodec.decode(
            UserDefaults.standard.data(forKey: unlockedKey)
        )
        hasCompletedInitialBackfill = UserDefaults.standard.bool(forKey: hasInitializedKey)
    }

    private func persistUnlocked() {
        guard let data = PathUnlockCodec.encode(unlockedNodeIDs) else { return }
        UserDefaults.standard.set(data, forKey: unlockedKey)
    }
}

// MARK: - Gating phrase (coach voice)
//
// Converts a `PathNodeCriterion` + current `PathProgressInput` into a one-
// line coach-voice gating sentence ("Two clean pauses from unlocked.").
// Lives next to PathProgressManager because both the criterion and the
// signal it reads are sourced here — no view code needs to know how to
// compute "distance from the bar."
//
// Voice spec: imperative-leaning, concrete numbers, no "Let's", no shame
// on regression (we only render forward distance, never "you slipped from
// 6 to 5"). When the user's current best already meets the bar, the
// helper returns "Ready to mark complete" rather than a negative number.
enum GatingPhrase {
    static func copy(for criterion: PathNodeCriterion, input: PathProgressInput) -> String? {
        switch criterion {
        case .sessionCountAtLeast(let n):
            let remaining = max(0, n - input.sessionCount)
            return remaining == 0 ? readyLine : "\(repsRemaining(remaining)) from unlocked."
        case .modeSessionAtLeast(let mode, let n):
            let count = input.progressEligibleSessions.filter { $0.mode == mode }.count
            let remaining = max(0, n - count)
            return remaining == 0 ? readyLine : "\(repsRemaining(remaining)) in \(modeName(mode)) from unlocked."
        case .scoreAtLeast(let target):
            let scored = input.progressEligibleSessions.compactMap(\.score)
            let best = scored.max() ?? 0
            if best >= target { return readyLine }
            if scored.isEmpty {
                return "Land one \(target)/10 session to unlock."
            }
            return "Best so far is \(best)/10. \(target)/10 unlocks it."
        case .zeroFillerSession:
            return "One zero-filler rep (\(quantityFloorLabel)) from unlocked."
        case .streakAtLeast(let n):
            let remaining = max(0, n - input.currentStreak)
            return remaining == 0 ? readyLine : "\(daysRemaining(remaining)) of streak from unlocked."
        case .ratingAtLeast(let target):
            let peak = input.rating.peakRating
            if peak >= target { return readyLine }
            return "+\(target - peak) rating from unlocked."
        case .pressureSurvived(let rounds):
            return "Survive into round \(rounds) of a Pressure Drill rep to unlock."
        case .modeMasteryLevel(let mode, let level):
            let current = input.modeMastery[mode]?.level ?? 1
            if current >= level { return readyLine }
            return "\(modeName(mode)) mastery \(level) unlocks it. You're at \(current)."
        case .modeMasteryAnyLevel(let level):
            let best = input.modeMastery.values.map(\.level).max() ?? 1
            if best >= level { return readyLine }
            return "Reach mastery \(level) in any mode. Your best is \(best)."
        case .distinctPracticeDays(let n):
            let remaining = max(0, n - input.distinctPracticeDayCount)
            return remaining == 0 ? readyLine : "\(daysRemaining(remaining)) of practice from unlocked."
        case .cleanRunsInWindow(let count, let minScore):
            let qualifying = input.quantityQualifiedZeroFillerCountLast7Days(
                minimumScore: minScore
            )
            let remaining = max(0, count - qualifying)
            if remaining == 0 { return readyLine }
            let unit = remaining == 1 ? "clean rep" : "clean reps"
            return "\(remaining) more full \(unit) (\(quantityFloorLabel), \(minScore)/10+) in seven days from unlocked."
        case .totalLessonPasses(let target):
            let remaining = max(0, target - input.totalLessonPasses)
            if remaining == 0 { return readyLine }
            let unit = remaining == 1 ? "practice pass" : "practice passes"
            return "\(remaining) more lesson \(unit) from unlocked."
        case .anyLessonMastered:
            let passCount = input.maxLessonPassCount
            if passCount >= LessonProgressPresentation.masteryPassCap { return readyLine }
            let remaining = LessonProgressPresentation.masteryPassCap - passCount
            let unit = remaining == 1 ? "practice pass" : "practice passes"
            return "Your highest lesson is at \(passCount)/\(LessonProgressPresentation.masteryPassCap) passes. \(remaining) more \(unit) on it unlocks mastery."
        case .heldSilentPause(let target):
            let bestSilent = input.progressEligibleSessions
                .compactMap { s -> Double? in
                    guard let m = s.pauseMetrics, m.count > 0, m.filledRatio == 0 else { return nil }
                    return m.longestSeconds
                }
                .max() ?? 0
            if bestSilent >= target { return readyLine }
            let targetSeconds = secondsLabel(target)
            // If the user has held some silent pause but not the target,
            // name the gap — concrete, non-shaming, points at the next rep.
            if bestSilent > 0 {
                let bestSeconds = secondsLabel(bestSilent)
                return "Best silent pause so far is \(bestSeconds). \(targetSeconds) in a rep unlocks it."
            }
            return "Hold one \(targetSeconds) silent pause in a rep to unlock."
        case .cleanPauseSession(let maxRatio, let minPauses):
            let pct = Int(maxRatio * 100)
            return "Land a rep with \(minPauses)+ pauses, fewer than \(pct)% filled, to unlock."
        }
    }

    // MARK: - Helpers

    private static let readyLine = "Ready to mark complete."

    private static var quantityFloorLabel: String {
        "\(SessionQualifier.minimumWordCount)+ words, \(secondsLabel(SessionQualifier.minimumDuration))+"
    }

    private static func repsRemaining(_ n: Int) -> String {
        n == 1 ? "One rep" : "\(n) reps"
    }

    private static func daysRemaining(_ n: Int) -> String {
        n == 1 ? "One day" : "\(n) days"
    }

    private static func modeName(_ mode: PracticeMode) -> String {
        mode.displayLabel
    }

    /// "1.5s" / "3s" — short numeric label for inline reading.
    private static func secondsLabel(_ s: Double) -> String {
        if s == floor(s) {
            return "\(Int(s))s"
        }
        return String(format: "%.1fs", s)
    }
}

#endif
