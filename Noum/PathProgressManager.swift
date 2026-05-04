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
    @Published private(set) var pendingCelebrationNodeID: String?

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
    /// in sync — but it never fires `pendingCelebrationNodeID`. Celebration
    /// is reserved for `evaluateAfterSession()` so async store ticks don't
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
            let isComplete = isPersistedUnlock || criterion.isComplete(for: input)

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

    /// Called by `SessionFinalizer` immediately after a session lands. This
    /// is the *only* path that fires a celebration overlay — async store
    /// updates use `recompute()` which is silent.
    func evaluateAfterSession() {
        let beforeSet = unlockedNodeIDs
        recompute()
        let afterSet = unlockedNodeIDs
        let newlyUnlocked = afterSet.subtracting(beforeSet)
        guard !newlyUnlocked.isEmpty else { return }

        // Surface the lowest-order newly-unlocked node — if a session crossed
        // multiple thresholds, the next-node home card walks the user through
        // the rest after this one dismisses.
        let firstByOrder = PathNodeRegistry.all
            .map(\.0)
            .first { newlyUnlocked.contains($0.id) }
        pendingCelebrationNodeID = firstByOrder?.id
    }

    /// Mark the celebration as seen so the overlay dismisses. The unlock
    /// itself remains persisted.
    func consumeCelebration() {
        pendingCelebrationNodeID = nil
    }

    func reloadForCurrentAccount() {
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
        let totalCrowns = lessonStore.totalCrowns
        let maxCrown = lessonStore.progress.values.map(\.crownLevel).max() ?? 0
        return PathProgressInput(
            sessions: PracticeSessionStore.shared.sessions,
            currentStreak: StreakFreezeManager.shared.currentStreak,
            baseline: BaselineStore.shared.baseline,
            rating: RatingStore.shared.rating,
            modeMastery: ModeMasteryStore.shared.snapshots,
            totalLessonCrowns: totalCrowns,
            maxLessonCrown: maxCrown,
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
        if let data = UserDefaults.standard.data(forKey: unlockedKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            unlockedNodeIDs = Set(decoded)
        } else {
            unlockedNodeIDs = []
        }
        hasCompletedInitialBackfill = UserDefaults.standard.bool(forKey: hasInitializedKey)
    }

    private func persistUnlocked() {
        let array = Array(unlockedNodeIDs)
        guard let data = try? JSONEncoder().encode(array) else { return }
        UserDefaults.standard.set(data, forKey: unlockedKey)
    }
}

#endif
