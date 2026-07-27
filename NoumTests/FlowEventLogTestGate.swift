import Foundation

/// Cross-suite mutual exclusion for tests that reset process-global observability
/// state (`FlowEventLog.shared`, `CoachAssessmentCache.shared`,
/// `UserTrajectoryCache.shared`).
///
/// Why this exists: Swift Testing's `.serialized` trait orders tests *within* one
/// suite, but different suites still run concurrently. Two suites both reset the
/// shared flow log, so one suite's `reset()` could land in the middle of another
/// suite's pipeline run and wipe events it was about to assert on. That produced
/// order-dependent failures — `streamFirstBuffered` counted 0 instead of 1 — which
/// passed in isolation and only failed in a full-suite run, the worst shape of
/// flake because it makes a green suite unreliable rather than obviously broken.
///
/// A global actor would not fix it: these tests suspend at `await` while driving
/// the reply pipeline, and another suite's test resumes in exactly that window.
/// Mutual exclusion therefore has to be held across the whole test body, including
/// its suspension points, which is what this gate provides.
///
/// Usage — wrap the entire body of any test that resets shared observability state:
/// ```
/// @Test func example() async throws {
///     try await FlowEventLogTestGate.shared.withExclusiveAccess {
///         // reset + drive + assert
///     }
/// }
/// ```
actor FlowEventLogTestGate {
    static let shared = FlowEventLogTestGate()

    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    private func acquire() async {
        guard isHeld else {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func release() {
        guard !waiters.isEmpty else {
            isHeld = false
            return
        }
        // Ownership passes straight to the next waiter, so `isHeld` deliberately
        // stays true — clearing it first would let a newly arriving caller barge
        // ahead of a test that has already been queued.
        waiters.removeFirst().resume()
    }

    /// Runs `body` with exclusive access to the shared observability globals.
    /// The gate is released even when `body` throws, so one failing test cannot
    /// deadlock every other suite that needs the same state.
    func withExclusiveAccess<T>(_ body: () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await body()
    }
}
