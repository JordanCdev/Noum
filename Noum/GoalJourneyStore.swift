import Foundation
import Combine
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Goal Journey Store
//
// Owns the user's goal-journey completion state. 1:1 structural twin of
// `PathProgressManager` (PathProgressManager.swift:31) — the ONLY new persisted
// state is `completedStepIDs` (goal-namespaced). All evidence/progress is read
// from existing owners (`BaselineStore`, `PracticeSessionStore`,
// `CoachingProfileStore`, `CoachMemoryStore`); no second metric store.
//
// Source-of-truth split (same as PathProgressManager):
// - Live progress for the current step is derived every render — no stored values.
// - Once a step hits 100% it's persisted to `completedStepIDs`; a later loss of
//   signal never relocks it (no-relock invariant).
// - Celebrations fire ONLY from `evaluateAfterSession()` (the post-rep hook),
//   never from a silent `recompute()`, so launch ticks don't chain overlays.

@MainActor
@available(iOS 17.0, macOS 12.0, *)
final class GoalJourneyStore: ObservableObject {
    static let shared = GoalJourneyStore()

    @Published private(set) var statuses: [GoalStepStatus] = []
    @Published private(set) var pendingCelebrationStepID: String?

    private let completedKeyPrefix = "noum.goalJourney.completed."
    private let hasInitializedKeyPrefix = "noum.goalJourney.initialized."
    /// Goal-namespaced ids — the ONLY new persisted state.
    private var completedStepIDs: Set<String> = []
    private var hasCompletedInitialBackfill = false

    private var sessionsSubscription: AnyCancellable?
    private var baselineSubscription: AnyCancellable?
    private var profileSubscription: AnyCancellable?
    private var memorySubscription: AnyCancellable?

    private init() {
        loadCompleted()
        recompute()
        observeStateChanges()
    }

    // MARK: - Public read-model (mirrors PathProgressManager)

    /// First incomplete step — the home card + chat-context + landscape read.
    var currentStep: GoalStepStatus? {
        statuses.first(where: { !$0.isComplete })
    }

    var completedSteps: [GoalStepStatus] {
        statuses.filter(\.isComplete)
    }

    /// "Step N of M" — N = completed + 1 clamped to total, M = total.
    var stepCountLabel: (current: Int, total: Int) {
        let total = statuses.count
        let done = completedSteps.count
        return (min(done + 1, max(total, 1)), total)
    }

    /// Tiny value handed to `CoachContextBuilder` / surfaces (no new state).
    var currentJourneyContext: GoalStepStatus? { currentStep }

    // MARK: - Recompute (silent — never fires a celebration)

    func recompute() {
        let steps = buildSteps()
        guard !steps.isEmpty else {
            statuses = []
            markInitialized()
            return
        }
        let input = makeInput()
        let newStatuses = GoalJourneyEngine.evaluate(
            steps: steps, input: input, persistedComplete: completedStepIDs
        )
        let newlyComplete = newStatuses
            .filter { $0.isComplete && !completedStepIDs.contains($0.step.id) }
            .map(\.step.id)
        statuses = newStatuses
        if !newlyComplete.isEmpty {
            completedStepIDs.formUnion(newlyComplete)
            persistCompleted()
        }
        markInitialized()
    }

    // MARK: - Post-rep hook (the ONLY path that fires a celebration)

    /// Called by `SessionFinalizer` after a session lands. Celebrates ONLY
    /// upward crossings (a newly-completed step). A miss changes nothing — no
    /// relock, no negative branch (never-punish invariant).
    func evaluateAfterSession() {
        let before = completedStepIDs
        recompute()
        let newly = completedStepIDs.subtracting(before)
        guard !newly.isEmpty else { return }
        // Lowest-order newly-completed step (the next card walks the rest).
        pendingCelebrationStepID = statuses.first { newly.contains($0.step.id) }?.step.id
    }

    func consumeCelebration() {
        pendingCelebrationStepID = nil
    }

    func reloadForCurrentAccount() {
        loadCompleted()
        recompute()
    }

    // MARK: - Inputs (read existing owners; create NO new evidence state)

    private func buildSteps() -> [GoalStep] {
        guard let goal = CoachingProfileStore.shared.profile?.primaryGoal else { return [] }
        return GoalJourneyEngine.build(
            goal: goal,
            baseline: BaselineStore.shared.baseline,
            intervention: CoachMemoryStore.shared.currentMemory?.activeIntervention,
            recentSessions: PracticeSessionStore.shared.sessions
        )
    }

    private func makeInput() -> GoalStepInput {
        GoalStepInput(
            sessions: PracticeSessionStore.shared.sessions,
            baseline: BaselineStore.shared.baseline,
            goal: CoachingProfileStore.shared.profile?.primaryGoal ?? .reduceFillers,
            now: Date()
        )
    }

    private func observeStateChanges() {
        sessionsSubscription = PracticeSessionStore.shared.$sessions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
        baselineSubscription = BaselineStore.shared.$baseline
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
        profileSubscription = CoachingProfileStore.shared.$profile
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
        memorySubscription = CoachMemoryStore.shared.$currentMemory
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.recompute() }
    }

    // MARK: - Persistence (account-scoped, mirrors PathProgressManager)

    private static func currentAccountID() -> String {
        AuthManager.shared.currentAccountID ?? "guest"
    }

    private var completedKey: String { completedKeyPrefix + Self.currentAccountID() }
    private var hasInitializedKey: String { hasInitializedKeyPrefix + Self.currentAccountID() }

    private func markInitialized() {
        if !hasCompletedInitialBackfill {
            hasCompletedInitialBackfill = true
            UserDefaults.standard.set(true, forKey: hasInitializedKey)
        }
    }

    private func loadCompleted() {
        if let data = UserDefaults.standard.data(forKey: completedKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            completedStepIDs = Set(decoded)
        } else {
            completedStepIDs = []
        }
        hasCompletedInitialBackfill = UserDefaults.standard.bool(forKey: hasInitializedKey)
    }

    private func persistCompleted() {
        guard let data = try? JSONEncoder().encode(Array(completedStepIDs)) else { return }
        UserDefaults.standard.set(data, forKey: completedKey)
    }
}

#endif
