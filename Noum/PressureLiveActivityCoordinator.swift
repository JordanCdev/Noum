import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif
import Combine

// MARK: - Pressure Live Activity Coordinator
//
// Observes the `PressureTimerEngine` and mirrors its phase into a Live
// Activity so the user can see round progress in the Dynamic Island /
// lock screen even when the app is backgrounded mid-rep.
//
// Lifecycle:
//   1. `start()` requests an Activity at session begin (or first phase
//      change away from `.setup`).
//   2. `update(...)` translates engine phase → activity state every time
//      the phase changes.
//   3. `end()` fires on `.sessionComplete` with `.immediate` dismissal so
//      the activity disappears as the user lands on the summary screen.
//
// Defensive about ActivityKit availability:
//   - iOS 16.1+ is required.
//   - User can disable Live Activities globally in Settings; we check
//     `ActivityAuthorizationInfo().areActivitiesEnabled` and skip silently
//     if they're off.
//   - Network outages don't matter: this is a local push activity.

@MainActor
@available(iOS 16.1, *)
final class PressureLiveActivityCoordinator {
    private let engine: PressureTimerEngine
    private let modeLabel: String
    private var phaseSubscription: AnyCancellable?
    #if canImport(ActivityKit)
    private var activity: Activity<PracticeLiveActivityAttributes>?
    #endif
    /// Wall-clock when the session started — used to render the
    /// activity progress and to feed the attributes' immutable
    /// `sessionStartedAt` field.
    private let sessionStart = Date()
    /// Pulled live from the speech VM so the activity shows current
    /// filler count without needing the engine to know about it.
    private let fillerCountProvider: () -> Int

    init(
        engine: PressureTimerEngine,
        modeLabel: String = "Pressure Drill",
        fillerCountProvider: @escaping () -> Int
    ) {
        self.engine = engine
        self.modeLabel = modeLabel
        self.fillerCountProvider = fillerCountProvider
    }

    // MARK: - Public lifecycle

    /// Start observing engine phase and request the Activity. Idempotent —
    /// calling start multiple times is safe.
    func start() {
        #if canImport(ActivityKit)
        guard activity == nil else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = PracticeLiveActivityAttributes(
            sessionStartedAt: sessionStart,
            modeLabel: modeLabel
        )
        let initialState = PracticeLiveActivityAttributes.State(
            roundNumber: 1,
            totalRounds: 6,
            secondsRemaining: 12,
            fillerCount: 0,
            phase: "Get ready"
        )

        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialState, staleDate: nil)
            )
        } catch {
            // If the request fails (most commonly: user disabled Live
            // Activities mid-flight), the coordinator becomes a no-op.
            // No reason to surface an error — the rep continues in-app.
            print("[LiveActivity] request failed: \(error.localizedDescription)")
        }

        // Observe phase changes from this point on.
        phaseSubscription = engine.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in
                Task { @MainActor [weak self] in
                    await self?.handle(phase: phase)
                }
            }
        #endif
    }

    /// End the Activity immediately. Safe to call repeatedly.
    func end() {
        #if canImport(ActivityKit)
        phaseSubscription?.cancel()
        phaseSubscription = nil
        guard let activity else { return }
        let finalState = PracticeLiveActivityAttributes.State(
            roundNumber: 0,
            totalRounds: 0,
            secondsRemaining: 0,
            fillerCount: fillerCountProvider(),
            phase: "Done"
        )
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        self.activity = nil
        #endif
    }

    // MARK: - Phase translation

    #if canImport(ActivityKit)
    private func handle(phase: PressureTurnPhase) async {
        guard let activity else { return }

        let state: PracticeLiveActivityAttributes.State?
        switch phase {
        case .setup:
            state = nil // before start; ignore.
        case .countdown(let n):
            state = PracticeLiveActivityAttributes.State(
                roundNumber: 1,
                totalRounds: 6,
                secondsRemaining: max(0, n),
                fillerCount: fillerCountProvider(),
                phase: "Get ready"
            )
        case .go:
            state = PracticeLiveActivityAttributes.State(
                roundNumber: 1,
                totalRounds: 6,
                secondsRemaining: 12,
                fillerCount: fillerCountProvider(),
                phase: "Go"
            )
        case .npcTurn(let round):
            state = PracticeLiveActivityAttributes.State(
                roundNumber: round,
                totalRounds: 6,
                secondsRemaining: 6,
                fillerCount: fillerCountProvider(),
                phase: "Listen"
            )
        case .userTurnWaiting(let round, let remaining):
            state = PracticeLiveActivityAttributes.State(
                roundNumber: round,
                totalRounds: 6,
                secondsRemaining: max(0, Int(remaining.rounded())),
                fillerCount: fillerCountProvider(),
                phase: "Speak"
            )
        case .userTurnActive(let round):
            state = PracticeLiveActivityAttributes.State(
                roundNumber: round,
                totalRounds: 6,
                secondsRemaining: 0,
                fillerCount: fillerCountProvider(),
                phase: "Speaking"
            )
        case .roundResult(let round, let outcome):
            state = PracticeLiveActivityAttributes.State(
                roundNumber: round,
                totalRounds: 6,
                secondsRemaining: 0,
                fillerCount: fillerCountProvider(),
                phase: outcome.isFailed ? outcome.label : "Survived"
            )
        case .sessionComplete:
            // Drive the final update + end on the next runloop tick so
            // the user sees the result for a beat before the activity
            // closes itself.
            await activity.update(
                ActivityContent(
                    state: PracticeLiveActivityAttributes.State(
                        roundNumber: 0,
                        totalRounds: 0,
                        secondsRemaining: 0,
                        fillerCount: fillerCountProvider(),
                        phase: "Done"
                    ),
                    staleDate: nil
                )
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.end()
            }
            return
        }

        if let state {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }
    #endif
}
