import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

// MARK: - Forward Plan
//
// The £130/hr coach hands you a written program at the end of session 1
// — what to practice each week and why. `ForwardPlan` is that artifact
// in Noum's voice: four weeks, each with a named focus, a recommended
// mode, a session target, and a one-sentence rationale tied back to
// the user's actual data + voice + Big Moment (when set).
//
// Persistence is per-account UserDefaults (same convention as every
// other store). One active plan at a time; regeneration replaces. The
// stored `bigMomentID` is the gate for invalidation: when the Big
// Moment changes, the plan is no longer aligned with the user's
// upcoming reality and the UI prompts to regenerate.
//
// Design rules:
//   • Pure-data model — no I/O on the struct itself. All computation
//     (current week index, session counts) happens via static helpers
//     so the model stays test-friendly.
//   • Bounded — exactly 4 weeks. A coach who hands you a 12-week
//     program is selling busyness; a 4-week program is what gets done.
//   • Honest about source — `isAIBacked: Bool` flows from the
//     generator so the UI can label deterministic fallbacks as
//     "rule-based" instead of presenting template copy as AI insight.

/// One week of a forward plan. Carries the focus skill area, the mode
/// best suited to drill it, a session target the user can actually
/// hit, and a short rationale the coach can read back aloud.
struct PlanWeek: Codable, Equatable, Identifiable {
    let weekIndex: Int            // 1...4
    let focus: CoachingPriority
    let focusSkillArea: SkillArea
    let suggestedMode: PracticeMode
    let sessionTarget: Int        // 2...5; honest about how many reps
    let rationale: String         // ≤ 200 chars, coach voice

    var id: Int { weekIndex }
}

/// A 4-week coaching program tied to the user's profile + baseline +
/// optional Big Moment. `currentWeekIndex(now:)` projects the plan
/// onto the calendar so progress tracking can compute completed-vs-
/// target without UI threading.
struct ForwardPlan: Codable, Equatable {
    let id: UUID
    let weeks: [PlanWeek]
    let generatedAt: Date
    /// The Big Moment ID at generation time. When the active moment
    /// changes (different ID or cleared), the plan is stale.
    let bigMomentID: UUID?
    /// The voice that shaped the rationale. Persisted so a voice
    /// change can invalidate without re-fetching the coaching profile.
    let voiceAtGeneration: SpeakingStyleGoal?
    /// True when the AI provider produced the plan; false when the
    /// deterministic rule-based fallback ran.
    let isAIBacked: Bool

    init(
        id: UUID = UUID(),
        weeks: [PlanWeek],
        generatedAt: Date = Date(),
        bigMomentID: UUID? = nil,
        voiceAtGeneration: SpeakingStyleGoal? = nil,
        isAIBacked: Bool
    ) {
        self.id = id
        self.weeks = weeks
        self.generatedAt = generatedAt
        self.bigMomentID = bigMomentID
        self.voiceAtGeneration = voiceAtGeneration
        self.isAIBacked = isAIBacked
    }

    // MARK: - Calendar projection

    /// Which week of the plan the user is in right now. 1-indexed; clamped
    /// to 4 once the program has run its course. A user opening the plan
    /// after 6 weeks still gets `currentWeekIndex == 4` (final week's
    /// guidance) rather than nil — the coach keeps coaching.
    func currentWeekIndex(now: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: generatedAt)
        let today = calendar.startOfDay(for: now)
        let days = max(0, calendar.dateComponents([.day], from: start, to: today).day ?? 0)
        let raw = (days / 7) + 1
        return min(max(raw, 1), 4)
    }

    /// The PlanWeek the user should be working through today. Always
    /// non-nil — `weeks` is constructed with exactly 4 entries and
    /// `currentWeekIndex` clamps into 1...4.
    func currentWeek(now: Date = Date(), calendar: Calendar = .current) -> PlanWeek? {
        let index = currentWeekIndex(now: now, calendar: calendar)
        return weeks.first { $0.weekIndex == index }
    }

    /// Date range for a specific plan week. `[start, end)` half-open so
    /// session-count helpers can filter without double-counting boundary
    /// reps. Week 1 starts at `generatedAt` (start-of-day); week 4 ends
    /// at `generatedAt + 28 days`.
    func dateRange(forWeek index: Int, calendar: Calendar = .current) -> (start: Date, end: Date) {
        let normalized = min(max(index, 1), 4)
        let base = calendar.startOfDay(for: generatedAt)
        let start = calendar.date(byAdding: .day, value: (normalized - 1) * 7, to: base) ?? base
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return (start, end)
    }

    /// True when the user's active BigMomentID no longer matches the one
    /// this plan was generated against (or when one side has cleared).
    /// The UI surfaces this as "Your big moment changed — regenerate."
    func isInvalidated(by activeBigMomentID: UUID?) -> Bool {
        bigMomentID != activeBigMomentID
    }

    /// Voice provenance is part of plan currentness too. A plan written for an
    /// effective compatibility fallback (or a previous explicit choice) must
    /// not remain an active prescription after the trust boundary changes.
    func isInvalidated(
        by activeBigMomentID: UUID?,
        chosenStyleGoal: SpeakingStyleGoal?
    ) -> Bool {
        isInvalidated(by: activeBigMomentID)
            || voiceAtGeneration != chosenStyleGoal
    }
}

// MARK: - Plan progress (pure)

/// Pure helper that counts how many sessions in `sessions` landed in
/// the date range of `plan`'s current week. Used by both the Profile
/// card and the PLAN section in `CoachContextBuilder.userContext` so
/// the count is identical in every surface.
enum ForwardPlanProgress {

    /// `(completed, target)` for the current plan week. Sessions count
    /// regardless of mode — the target is a rep target, not a "must do
    /// the suggested mode" lock. The suggestion is guidance; the count
    /// is honest about what the user actually did.
    static func currentWeekProgress(
        plan: ForwardPlan,
        sessions: [PracticeSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> (completed: Int, target: Int)? {
        guard let week = plan.currentWeek(now: now, calendar: calendar) else { return nil }
        let range = plan.dateRange(forWeek: week.weekIndex, calendar: calendar)
        let completed = sessions.filter { range.start <= $0.date && $0.date < range.end }.count
        return (completed, week.sessionTarget)
    }
}

// MARK: - ForwardPlanStore

/// Per-account persistent store for the active forward plan. Mirrors
/// the singleton + reload/end-session pattern every other per-account
/// store follows.
@MainActor
final class ForwardPlanStore: ObservableObject {
    static let shared = ForwardPlanStore()

    @Published private(set) var activePlan: ForwardPlan?

    private let accountKey = "NoumAccountID"
    private let planKeyPrefix = "forwardPlan."

    private init() {}

    // MARK: - Lifecycle

    func reloadForCurrentAccount() {
        guard let accountID = currentAccountID else {
            activePlan = nil
            return
        }
        activePlan = Self.loadPlan(forKey: planKey(for: accountID))
    }

    func endSession() {
        activePlan = nil
    }

    // MARK: - API

    /// Replace the active plan and persist. Triggered by `ForwardPlanService`
    /// after a successful generation (AI or deterministic fallback).
    func replace(_ plan: ForwardPlan) {
        guard let accountID = currentAccountID else { return }
        activePlan = plan
        persist(plan, accountID: accountID)
    }

    /// Drop the active plan entirely. Used by Settings → "Reset plan" and
    /// the implicit invalidation path when the user clears their Big Moment.
    func clearPlan() {
        guard let accountID = currentAccountID else {
            activePlan = nil
            return
        }
        activePlan = nil
        UserDefaults.standard.removeObject(forKey: planKey(for: accountID))
    }

    /// True when there's an active plan AND its `bigMomentID` still matches
    /// the currently-active BigMoment. UI gating reads this instead of
    /// `activePlan != nil` so a stale plan doesn't claim to be live.
    func isPlanCurrent(
        activeBigMomentID: UUID?,
        chosenStyleGoal: SpeakingStyleGoal?
    ) -> Bool {
        guard let plan = activePlan else { return false }
        return !plan.isInvalidated(
            by: activeBigMomentID,
            chosenStyleGoal: chosenStyleGoal
        )
    }

    /// The only plan safe to feed active coaching/prescription consumers.
    /// UI may still inspect `activePlan` to offer regeneration, but model and
    /// memory paths use this reconciled projection.
    func currentPlan(
        activeBigMomentID: UUID?,
        chosenStyleGoal: SpeakingStyleGoal?
    ) -> ForwardPlan? {
        guard isPlanCurrent(
            activeBigMomentID: activeBigMomentID,
            chosenStyleGoal: chosenStyleGoal
        ) else { return nil }
        return activePlan
    }

    // MARK: - Auth wipe

    func deleteAllData(for accountID: String) {
        UserDefaults.standard.removeObject(forKey: planKey(for: accountID))
        if currentAccountID == accountID {
            activePlan = nil
        }
    }

    // MARK: - Private

    private func persist(_ plan: ForwardPlan, accountID: String) {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        UserDefaults.standard.set(data, forKey: planKey(for: accountID))
    }

    private func planKey(for accountID: String) -> String {
        "\(planKeyPrefix)\(accountID)"
    }

    private var currentAccountID: String? {
        KeychainHelper.load(key: accountKey)
    }

    private static func loadPlan(forKey key: String) -> ForwardPlan? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let plan = try? JSONDecoder().decode(ForwardPlan.self, from: data) else { return nil }
        return plan
    }
}
