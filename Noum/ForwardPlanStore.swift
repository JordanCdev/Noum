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
    /// Optional links from a plan week to a phrase the user explicitly saved
    /// in the existing account-scoped Phrase Bank. The plan stores only the
    /// entry identifier, never another copy of the phrase or its source
    /// transcript. Missing/deleted entries therefore fail closed to no phrase.
    let practicePhraseEntryIDsByWeek: [Int: UUID]?

    init(
        id: UUID = UUID(),
        weeks: [PlanWeek],
        generatedAt: Date = Date(),
        bigMomentID: UUID? = nil,
        voiceAtGeneration: SpeakingStyleGoal? = nil,
        isAIBacked: Bool,
        practicePhraseEntryIDsByWeek: [Int: UUID]? = nil
    ) {
        self.id = id
        self.weeks = weeks
        self.generatedAt = generatedAt
        self.bigMomentID = bigMomentID
        self.voiceAtGeneration = voiceAtGeneration
        self.isAIBacked = isAIBacked
        self.practicePhraseEntryIDsByWeek = practicePhraseEntryIDsByWeek
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

    /// Resolve the user-selected phrase link for one real plan week. Invalid
    /// week indices and stale identifiers are deliberately ignored by callers
    /// rather than inventing a replacement phrase.
    func practicePhraseEntryID(forWeek weekIndex: Int) -> UUID? {
        guard weeks.contains(where: { $0.weekIndex == weekIndex }) else {
            return nil
        }
        return practicePhraseEntryIDsByWeek?[weekIndex]
    }

    /// Immutable update used by `ForwardPlanStore`, preserving the generated
    /// plan's identity/provenance while changing only the user's explicit
    /// week-to-phrase execution choice.
    func assigningPracticePhrase(entryID: UUID, toWeek weekIndex: Int) -> ForwardPlan? {
        guard weeks.contains(where: { $0.weekIndex == weekIndex }) else {
            return nil
        }
        var assignments = practicePhraseEntryIDsByWeek ?? [:]
        assignments[weekIndex] = entryID
        return ForwardPlan(
            id: id,
            weeks: weeks,
            generatedAt: generatedAt,
            bigMomentID: bigMomentID,
            voiceAtGeneration: voiceAtGeneration,
            isAIBacked: isAIBacked,
            practicePhraseEntryIDsByWeek: assignments
        )
    }

    /// Clear every link to a removed Phrase Bank entry without touching the
    /// generated plan. Keeping this operation on the existing plan owner avoids
    /// a second handoff store and prevents dead references from accumulating.
    func removingPracticePhrase(entryID: UUID) -> ForwardPlan {
        let assignments = (practicePhraseEntryIDsByWeek ?? [:]).filter {
            $0.value != entryID
        }
        return ForwardPlan(
            id: id,
            weeks: weeks,
            generatedAt: generatedAt,
            bigMomentID: bigMomentID,
            voiceAtGeneration: voiceAtGeneration,
            isAIBacked: isAIBacked,
            practicePhraseEntryIDsByWeek: assignments.isEmpty ? nil : assignments
        )
    }

    /// Remove links whose text owner no longer contains the referenced entry.
    /// This covers explicit deletion, archive-cap eviction, and load-time
    /// filtering without making the plan a second phrase owner.
    func reconcilingPracticePhrases(validEntryIDs: Set<UUID>) -> ForwardPlan {
        let assignments = (practicePhraseEntryIDsByWeek ?? [:]).filter {
            validEntryIDs.contains($0.value)
        }
        return ForwardPlan(
            id: id,
            weeks: weeks,
            generatedAt: generatedAt,
            bigMomentID: bigMomentID,
            voiceAtGeneration: voiceAtGeneration,
            isAIBacked: isAIBacked,
            practicePhraseEntryIDsByWeek: assignments.isEmpty ? nil : assignments
        )
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
        let completed = PracticeProgressEligibility.eligibleSessions(in: sessions)
            .filter { range.start <= $0.date && $0.date < range.end }
            .count
        return (completed, week.sessionTarget)
    }
}

// MARK: - ForwardPlanStore

/// Account-owned authorization captured on the same MainActor turn as the
/// Forward Plan input. Provider services must use this snapshot rather than
/// re-reading live settings after suspension, or one account's context could
/// inherit another account's cloud-processing permission.
struct ForwardPlanExecutionAuthorization: Equatable {
    let locale: PracticeLocale
    let cloudProcessingConsent: CloudProcessingConsent?
    let activeProviderRawValue: String?

    init(
        locale: PracticeLocale,
        cloudProcessingConsent: CloudProcessingConsent?,
        activeProvider: AIProvider?
    ) {
        self.locale = locale
        self.cloudProcessingConsent = cloudProcessingConsent
        activeProviderRawValue = activeProvider?.rawValue
    }

    var activeProvider: AIProvider? {
        activeProviderRawValue.flatMap(AIProvider.init(rawValue:))
    }

    var allowsRemoteRequest: Bool {
        locale.aiSupported && activeProvider != nil
    }

    @MainActor
    static func captureCurrent() -> ForwardPlanExecutionAuthorization {
        ForwardPlanExecutionAuthorization(
            locale: LocaleSettingsManager.shared.current,
            cloudProcessingConsent: AISettingsManager.shared.cloudProcessingConsent,
            activeProvider: AISettingsManager.shared.activeProvider
        )
    }

    static func == (
        lhs: ForwardPlanExecutionAuthorization,
        rhs: ForwardPlanExecutionAuthorization
    ) -> Bool {
        lhs.locale.rawValue == rhs.locale.rawValue
            && lhs.cloudProcessingConsent == rhs.cloudProcessingConsent
            && lhs.activeProviderRawValue == rhs.activeProviderRawValue
    }
}

/// Account-, lifecycle-, store-, source-, and authorization-scoped lease for
/// one asynchronous Forward Plan request. The request ID also makes the most
/// recent user intent authoritative when two provider calls finish out of order.
struct ForwardPlanSaveToken: Equatable {
    let requestID: UUID
    let accountScope: String
    let accountLifecycleGeneration: UInt64
    let planStoreGeneration: UInt64
    let sessionStoreEpoch: PracticeSessionStoreEpoch
    let inputIdentity: String
    let executionAuthorization: ForwardPlanExecutionAuthorization
}

struct ForwardPlanGenerationRequest {
    let input: ForwardPlanInput
    let saveToken: ForwardPlanSaveToken
}

/// Per-account persistent store for the active forward plan. Mirrors
/// the singleton + reload/end-session pattern every other per-account
/// store follows.
@MainActor
final class ForwardPlanStore: ObservableObject {
    static let shared = ForwardPlanStore()

    @Published private(set) var activePlan: ForwardPlan?

    /// The account whose plan is actually loaded in memory. Keychain identity
    /// can change before registry hydration completes; keeping this separate
    /// prevents a stale row from being relabelled as the new account's state.
    private(set) var loadedAccountScope: String?

    private let defaults: UserDefaults
    private let accountIDProvider: () -> String?
    private let accountLifecycleGenerationProvider: () -> UInt64
    private let accountIsReadyProvider: () -> Bool
    private let providerWorkAllowedProvider: (String) -> Bool
    private let sessionStoreEpochProvider: () -> PracticeSessionStoreEpoch?
    private let executionAuthorizationProvider: () -> ForwardPlanExecutionAuthorization
    private let planKeyPrefix = "forwardPlan."
    private var planStoreGeneration: UInt64 = 0
    private var latestGenerationRequestID: UUID?

    init(
        defaults: UserDefaults = .standard,
        accountIDProvider: (() -> String?)? = nil,
        accountLifecycleGenerationProvider: (() -> UInt64)? = nil,
        accountIsReadyProvider: (() -> Bool)? = nil,
        providerWorkAllowedProvider: ((String) -> Bool)? = nil,
        sessionStoreEpochProvider: (() -> PracticeSessionStoreEpoch?)? = nil,
        executionAuthorizationProvider: (() -> ForwardPlanExecutionAuthorization)? = nil
    ) {
        self.defaults = defaults
        self.accountIDProvider = accountIDProvider ?? {
            KeychainHelper.load(key: "NoumAccountID")
        }
        self.accountLifecycleGenerationProvider = accountLifecycleGenerationProvider ?? {
            AuthManager.shared.accountLifecycleGeneration
        }
        self.accountIsReadyProvider = accountIsReadyProvider ?? {
            AuthManager.shared.isSignedIn
                && AuthManager.shared.initialAccountHydrationState == .ready
        }
        self.providerWorkAllowedProvider = providerWorkAllowedProvider ?? {
            AuthManager.shared.isProviderWorkAllowed(for: $0)
        }
        self.sessionStoreEpochProvider = sessionStoreEpochProvider ?? {
            PracticeSessionStore.shared.loadedAccountEpoch
        }
        self.executionAuthorizationProvider = executionAuthorizationProvider ?? {
            ForwardPlanExecutionAuthorization.captureCurrent()
        }
        activePlan = nil
        loadedAccountScope = nil
    }

    // MARK: - Lifecycle

    func reloadForCurrentAccount() {
        invalidateGenerationRequests()
        loadedAccountScope = nil
        activePlan = nil
        guard let accountID = currentAccountID else { return }
        loadedAccountScope = accountID
        activePlan = Self.loadPlan(
            forKey: planKey(for: accountID),
            defaults: defaults
        )
    }

    func endSession() {
        invalidateGenerationRequests()
        loadedAccountScope = nil
        activePlan = nil
    }

    // MARK: - API

    /// Capture an inseparable request + lease before provider work can suspend.
    /// Auth readiness and the session-store epoch prove that every live store
    /// has completed account hydration rather than merely observing a newly
    /// written Keychain identity.
    func generationRequest(
        for input: ForwardPlanInput
    ) -> ForwardPlanGenerationRequest? {
        guard accountIsReadyProvider(),
              let accountID = currentAccountID,
              providerWorkAllowedProvider(accountID),
              loadedAccountScope == accountID,
              let sessionStoreEpoch = sessionStoreEpochProvider(),
              sessionStoreEpoch.accountScope == accountID,
              let inputIdentity = input.generationIdentity else {
            return nil
        }
        let executionAuthorization = executionAuthorizationProvider()
        let requestID = UUID()
        latestGenerationRequestID = requestID
        return ForwardPlanGenerationRequest(
            input: input,
            saveToken: ForwardPlanSaveToken(
                requestID: requestID,
                accountScope: accountID,
                accountLifecycleGeneration: accountLifecycleGenerationProvider(),
                planStoreGeneration: planStoreGeneration,
                sessionStoreEpoch: sessionStoreEpoch,
                inputIdentity: inputIdentity,
                executionAuthorization: executionAuthorization
            )
        )
    }

    /// Revalidate the complete lease immediately before committing. Callers
    /// rebuild `currentInput` from the same existing state owners; any profile,
    /// baseline, session, trend, drill, recommendation, transfer, streak,
    /// rating, or Big Moment drift rejects the stale result.
    func tokenIsCurrent(
        _ token: ForwardPlanSaveToken,
        currentInput: ForwardPlanInput
    ) -> Bool {
        guard accountIsReadyProvider(),
              currentAccountID == token.accountScope,
              providerWorkAllowedProvider(token.accountScope),
              loadedAccountScope == token.accountScope,
              accountLifecycleGenerationProvider()
                == token.accountLifecycleGeneration,
              planStoreGeneration == token.planStoreGeneration,
              latestGenerationRequestID == token.requestID,
              sessionStoreEpochProvider() == token.sessionStoreEpoch,
              executionAuthorizationProvider()
                == token.executionAuthorization,
              currentInput.generationIdentity == token.inputIdentity else {
            return false
        }
        return true
    }

    /// Close the synchronous Forward Plan mutation boundary as soon as account
    /// deletion is admitted. An already-installed plan stays in memory and on
    /// disk until remote deletion succeeds so a recoverable pre-remote failure
    /// does not erase user data. Only pending provider authority is revoked.
    func suspendProviderWorkForAccountTransition(accountID: String) {
        let normalized = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty,
              loadedAccountScope == normalized || currentAccountID == normalized else {
            return
        }
        invalidateGenerationRequests()
    }

    func suspendProviderWorkForDeletion(accountID: String) {
        suspendProviderWorkForAccountTransition(accountID: accountID)
    }

    /// Compare-and-save boundary for async generation. `announce` executes
    /// synchronously on the same MainActor turn after every guard and after the
    /// plan has encoded successfully. If the checked Ask Noum write rejects,
    /// no plan state changes; if it succeeds, the non-throwing UserDefaults
    /// write and published plan land before another account event can run.
    @discardableResult
    func commit(
        _ plan: ForwardPlan,
        currentInput: ForwardPlanInput,
        expected token: ForwardPlanSaveToken,
        announce: () -> Bool
    ) -> Bool {
        guard tokenIsCurrent(token, currentInput: currentInput),
              plan.bigMomentID == currentInput.bigMoment?.id,
              plan.voiceAtGeneration == currentInput.profile?.chosenStyleGoal,
              let data = try? JSONEncoder().encode(plan),
              announce() else {
            return false
        }
        latestGenerationRequestID = nil
        activePlan = plan
        defaults.set(data, forKey: planKey(for: token.accountScope))
        return true
    }

    /// Drop the active plan entirely. Used by Settings → "Reset plan" and
    /// the implicit invalidation path when the user clears their Big Moment.
    func clearPlan() {
        invalidateGenerationRequests()
        guard let accountID = currentAccountID,
              loadedAccountScope == accountID else {
            activePlan = nil
            return
        }
        activePlan = nil
        defaults.removeObject(forKey: planKey(for: accountID))
    }

    #if DEBUG
    /// Explicit fixture-only bypass. Production generation must use the leased
    /// compare-and-save path above; screenshot fixtures still need a direct,
    /// deterministic way to install an authored plan after account hydration.
    func replaceForDebug(_ plan: ForwardPlan) {
        invalidateGenerationRequests()
        guard let accountID = currentAccountID,
              loadedAccountScope == accountID else { return }
        activePlan = plan
        persist(plan, accountID: accountID)
    }
    #endif

    /// Attach one explicitly saved Phrase Bank entry to a specific week of the
    /// currently rendered plan. `expectedPlanID` prevents a delayed sheet tap
    /// from mutating a newly regenerated plan that the user never saw.
    @discardableResult
    fileprivate func assignPracticePhrase(
        entryID: UUID,
        toWeek weekIndex: Int,
        expectedPlanID: UUID
    ) -> Bool {
        guard let accountID = currentAccountID,
              loadedAccountScope == accountID,
              let plan = activePlan,
              plan.id == expectedPlanID,
              let updated = plan.assigningPracticePhrase(
                entryID: entryID,
                toWeek: weekIndex
              ) else {
            return false
        }
        invalidateGenerationRequests()
        activePlan = updated
        persist(updated, accountID: accountID)
        return true
    }

    /// Called when a Phrase Bank entry is deleted. The phrase store remains the
    /// text owner; the plan owner only removes its identifier reference.
    fileprivate func removePracticePhraseReference(entryID: UUID) {
        guard let accountID = currentAccountID,
              loadedAccountScope == accountID,
              let plan = activePlan,
              plan.practicePhraseEntryIDsByWeek?.values.contains(entryID) == true else {
            return
        }
        let updated = plan.removingPracticePhrase(entryID: entryID)
        invalidateGenerationRequests()
        activePlan = updated
        persist(updated, accountID: accountID)
    }

    /// Reconcile the plan's ID-only links whenever the shared Phrase Bank
    /// changes. Account switching remains safe because both owners reload from
    /// the same account registry before this callback runs.
    func reconcilePracticePhraseReferences(validEntryIDs: Set<UUID>) {
        guard let accountID = currentAccountID,
              loadedAccountScope == accountID,
              let plan = activePlan else {
            return
        }
        let updated = plan.reconcilingPracticePhrases(
            validEntryIDs: validEntryIDs
        )
        guard updated != plan else { return }
        invalidateGenerationRequests()
        activePlan = updated
        persist(updated, accountID: accountID)
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
        defaults.removeObject(forKey: planKey(for: accountID))
        if currentAccountID == accountID || loadedAccountScope == accountID {
            invalidateGenerationRequests()
            loadedAccountScope = nil
            activePlan = nil
        }
    }

    // MARK: - Private

    private func persist(_ plan: ForwardPlan, accountID: String) {
        guard let data = try? JSONEncoder().encode(plan) else { return }
        defaults.set(data, forKey: planKey(for: accountID))
    }

    private func planKey(for accountID: String) -> String {
        "\(planKeyPrefix)\(accountID)"
    }

    private var currentAccountID: String? {
        let trimmed = accountIDProvider()?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func loadPlan(
        forKey key: String,
        defaults: UserDefaults
    ) -> ForwardPlan? {
        guard let data = defaults.data(forKey: key),
              let plan = try? JSONDecoder().decode(ForwardPlan.self, from: data) else { return nil }
        return plan
    }

    private func invalidateGenerationRequests() {
        planStoreGeneration &+= 1
        latestGenerationRequestID = nil
    }
}

/// The only mutation boundary joining Phrase Bank membership to the current
/// Forward Plan. The sheet passes the exact target it rendered; this coordinator
/// rechecks live plan currentness, week, existing assignment, entry membership,
/// and phrase safety immediately before writing.
@available(iOS 17.0, macOS 12.0, *)
@MainActor
enum ForwardPlanPhraseCoordinator {
    nonisolated static func validatesAssignment(
        entryID: UUID,
        renderedTarget: ForwardPlanPhraseTarget,
        currentPlan: ForwardPlan?,
        entries: [PhraseBankEntry]
    ) -> Bool {
        guard let liveTarget = ForwardPlanPhraseProjection.target(plan: currentPlan),
              liveTarget == renderedTarget,
              let entry = entries.first(where: { $0.id == entryID }),
              PhrasePracticeIntent(entry: entry) != nil else {
            return false
        }
        return true
    }

    @discardableResult
    static func assign(
        entryID: UUID,
        renderedTarget: ForwardPlanPhraseTarget,
        currentPlan: ForwardPlan?,
        phraseBank: PhraseBankStore,
        planStore: ForwardPlanStore
    ) -> Bool {
        guard let liveTarget = ForwardPlanPhraseProjection.target(plan: currentPlan),
              validatesAssignment(
                entryID: entryID,
                renderedTarget: renderedTarget,
                currentPlan: currentPlan,
                entries: phraseBank.entries
              ) else {
            return false
        }
        return planStore.assignPracticePhrase(
            entryID: entryID,
            toWeek: liveTarget.weekIndex,
            expectedPlanID: liveTarget.planID
        )
    }

    static func remove(
        entryID: UUID,
        phraseBank: PhraseBankStore,
        planStore: ForwardPlanStore
    ) {
        phraseBank.remove(id: entryID)
        planStore.removePracticePhraseReference(entryID: entryID)
    }
}
