import Foundation

/// A pure, account-scoped projection of Noum's first seven coaching days.
///
/// This is deliberately not a store and not another plan. It reads bounded
/// evidence already owned by onboarding, session history, coach memory, and
/// weekly check-ins, then exposes one next action plus a lock-screen-safe
/// notification intent. Callers remain responsible for navigation and
/// scheduling through the existing owners.
struct FirstWeekCoachingContract {
    /// Final day on which first-week evidence can enter the read. The read
    /// remains available afterwards, but later sessions do not rewrite what
    /// Noum said happened during the first week.
    static let finalDay = 7

    enum Stage: String, Equatable, CaseIterable {
        case day0Baseline
        case day1To2Repeat
        case day3To4CompareAndAdapt
        case day5To6RealWorldCheckIn
        case day7FirstWeekRead
    }

    enum ActivationSource: String, Equatable {
        case structuredFirstValue
        case spokenFirstValue
        case earliestEligibleSession
    }

    /// Content-free evidence that the account reached its first useful value.
    /// The written response, transcript, goal, and coach prose never enter this
    /// receipt or any notification projection.
    struct ActivationReceipt: Equatable {
        let accountID: String
        let completedAt: Date
        let source: ActivationSource
        let correlationID: UUID?
        let sessionID: UUID?

        init?(
            accountID: String,
            draft: CoachingProfileDraft
        ) {
            guard let normalizedAccountID = Self.normalized(accountID),
                  draft.hasCompletedFirstValue,
                  let receipt = draft.firstValueReceipt else {
                return nil
            }
            self.accountID = normalizedAccountID
            completedAt = receipt.completedAt
            source = receipt.modality == .structuredText
                ? .structuredFirstValue
                : .spokenFirstValue
            correlationID = draft.correlationID
            sessionID = receipt.sessionID
        }

        init?(
            accountID: String,
            earliestEligibleSession: PracticeSession
        ) {
            guard let normalizedAccountID = Self.normalized(accountID),
                  PracticeProgressEligibility.qualifies(earliestEligibleSession) else {
                return nil
            }
            self.accountID = normalizedAccountID
            completedAt = earliestEligibleSession.date
            source = .earliestEligibleSession
            correlationID = nil
            sessionID = earliestEligibleSession.id
        }

        private static func normalized(_ rawValue: String) -> String? {
            let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }

    struct SessionEvidence: Equatable {
        let accountID: String
        let sessions: [PracticeSession]

        init(accountID: String, sessions: [PracticeSession]) {
            self.accountID = accountID
            self.sessions = sessions
        }

        static func == (lhs: SessionEvidence, rhs: SessionEvidence) -> Bool {
            lhs.accountID == rhs.accountID
                && lhs.sessions.map(\.id) == rhs.sessions.map(\.id)
        }
    }

    /// Only content-free prescription fields needed to decide the next step.
    /// User-authored or generated title/target text stays with CoachMemory.
    struct PrescriptionEvidence: Equatable {
        let mode: PracticeMode
        let prescribedAt: Date?
        let followedRepCount: Int
        let minimumFollowedRepsForReview: Int
        let reviewStatus: CoachInterventionReviewStatus
        let reviewDueAt: Date?

        init(_ intervention: CoachIntervention) {
            mode = intervention.mode
            prescribedAt = intervention.prescribedAt
            followedRepCount = max(0, intervention.followedRepCount)
            minimumFollowedRepsForReview = max(1, intervention.minimumFollowedRepsForReview)
            reviewStatus = intervention.reviewStatus
            reviewDueAt = intervention.reviewDueAt
        }

        func needsReview(at now: Date) -> Bool {
            switch reviewStatus {
            case .diagnoseBeforeRepeating, .adaptBeforeRepeating:
                return true
            case .awaitingAttempt, .formingEvidence, .continueAndVerify:
                guard followedRepCount >= minimumFollowedRepsForReview,
                      let reviewDueAt else { return false }
                return now >= reviewDueAt
            }
        }
    }

    struct CheckInEvidence: Equatable {
        let recordedAt: Date
        let includesRealWorldContext: Bool

        init(_ checkIn: CoachCheckIn) {
            recordedAt = checkIn.recordedAt
            includesRealWorldContext = checkIn.outsideApp != nil
        }
    }

    struct CoachingEvidence: Equatable {
        let accountID: String
        let observedAt: Date?
        let currentLever: SkillArea?
        let prescription: PrescriptionEvidence?
        let latestCheckIn: CheckInEvidence?
        /// Existing evidence-owner projection. The contract validates that all
        /// referenced sessions belong to its bounded first-week sample before
        /// exposing it to a UI.
        let longitudinalTrend: CoachLongitudinalTrendProjection?

        init(
            accountID: String,
            memory: CoachMemory?,
            latestCheckIn: CoachCheckIn?,
            longitudinalTrend: CoachLongitudinalTrendProjection? = nil
        ) {
            self.accountID = accountID
            observedAt = memory?.updatedAt
            currentLever = memory?.currentLever
            prescription = memory?.activeIntervention.map(PrescriptionEvidence.init)
            self.latestCheckIn = latestCheckIn.map(CheckInEvidence.init)
            self.longitudinalTrend = longitudinalTrend
        }
    }

    /// Compact Day-7 projection for `AIWeeklyInsightCard` (or a dedicated
    /// detail surface). It carries evidence references and calibrated states,
    /// not a second narrative, transcript, plan, or durable owner.
    struct FirstWeekReadProjection: Codable, Equatable {
        enum Change: Codable, Equatable {
            /// A comparison already qualified by `UserTrajectoryCache`, then
            /// revalidated against this account's first-week session window.
            case verifiedComparison(CoachLongitudinalTrendProjection)
            /// Honest fallback when Noum cannot yet say that anything changed.
            case notYetProven(eligibleRepCount: Int)
        }

        enum UnprovenArea: String, Codable, Equatable, CaseIterable {
            case practiceChange
            case realWorldOutcome
            case durability
        }

        /// Enough information for a UI to look up the existing session and ask
        /// `ProofMomentStore` / `ProofMomentService` for a grounded example.
        /// The source transcript never enters this contract or a notification.
        struct VerifiedExampleReference: Codable, Equatable {
            let sessionID: UUID
            let recordedAt: Date
            let mode: PracticeMode
            let score: Int?
            let comparisonMetricSchemaVersion: Int
        }

        struct NextWeekPlan: Codable, Equatable {
            let lever: SkillArea?
            let mode: PracticeMode?
            let remainingComparableRepsBeforeReview: Int
            let recommendedAction: NextAction
        }

        let whatChanged: Change
        let remainsUnproven: [UnprovenArea]
        let verifiedExample: VerifiedExampleReference?
        let nextWeekPlan: NextWeekPlan
    }

    /// Immutable receipt persisted by the existing account-scoped
    /// `CoachMemoryStore` the first time a qualified Day-7 read is exposed.
    /// The live resolver can redact missing evidence references for display,
    /// but it never rewrites this saved projection from later trajectory or
    /// memory state.
    struct FirstWeekReadSnapshot: Codable, Equatable {
        let capturedAt: Date
        let projection: FirstWeekReadProjection
    }

    enum NextAction: Codable, Equatable {
        case recordSpokenBaseline
        case repeatRep(mode: PracticeMode?)
        case compareAndAdapt(lever: SkillArea?, mode: PracticeMode?)
        case realWorldCheckIn
        case reviewFirstWeekRead

        var accessibilityIdentifier: String {
            switch self {
            case .recordSpokenBaseline: return "firstWeek.nextAction.spokenBaseline"
            case .repeatRep: return "firstWeek.nextAction.repeat"
            case .compareAndAdapt: return "firstWeek.nextAction.compare"
            case .realWorldCheckIn: return "firstWeek.nextAction.checkIn"
            case .reviewFirstWeekRead: return "firstWeek.nextAction.read"
            }
        }
    }

    enum NotificationIntent: String, Equatable, CaseIterable {
        case recordSpokenBaseline
        case repeatRep
        case compareAndAdapt
        case realWorldCheckIn
        case firstWeekRead
    }

    struct Input: Equatable {
        let activeAccountID: String
        let activation: ActivationReceipt
        let sessionEvidence: SessionEvidence
        let coachingEvidence: CoachingEvidence?
    }

    struct Snapshot: Equatable {
        let accountID: String
        let activation: ActivationReceipt
        let day: Int
        let stage: Stage
        let eligibleSessionCount: Int
        let currentLever: SkillArea?
        let prescription: PrescriptionEvidence?
        let hasRealWorldCheckIn: Bool
        /// Non-nil from Day 7 onward. A caller can render the four requested
        /// sections directly: change, unknowns, example, and next-week plan.
        let firstWeekRead: FirstWeekReadProjection?
        let nextAction: NextAction
        let notificationIntent: NotificationIntent

        func replacingFirstWeekRead(
            _ read: FirstWeekReadProjection?
        ) -> Snapshot {
            Snapshot(
                accountID: accountID,
                activation: activation,
                day: day,
                stage: stage,
                eligibleSessionCount: eligibleSessionCount,
                currentLever: currentLever,
                prescription: prescription,
                hasRealWorldCheckIn: hasRealWorldCheckIn,
                firstWeekRead: read,
                nextAction: nextAction,
                notificationIntent: notificationIntent
            )
        }
    }

    /// Resolves the seven-day stage from local calendar days and fails closed
    /// on missing, future, or cross-account evidence. The written value keeps
    /// its role as the growth activation receipt, while the coaching contract
    /// starts only when its first qualifying spoken baseline is persisted.
    /// Day 7 is durable: it is the terminal stage rather than a one-day window
    /// that disappears.
    static func resolve(
        input: Input,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Snapshot? {
        guard let activeAccountID = normalized(input.activeAccountID),
              normalized(input.activation.accountID) == activeAccountID,
              normalized(input.sessionEvidence.accountID) == activeAccountID,
              input.coachingEvidence.map({ normalized($0.accountID) == activeAccountID }) ?? true,
              input.activation.completedAt <= now else {
            return nil
        }

        let sessionsThroughNow = PracticeProgressEligibility
            .eligibleSessions(in: input.sessionEvidence.sessions)
            .filter {
                input.activation.completedAt <= $0.date
                    && $0.date <= now
            }
        guard let programStartedAt = sessionsThroughNow
            .min(by: { $0.date < $1.date })?
            .date else {
            // Permissionless written value is still activation, but calendar
            // time alone must never advance or expire a coaching program that
            // has no spoken baseline. A late first rep will begin Day 0 then.
            return Snapshot(
                accountID: activeAccountID,
                activation: input.activation,
                day: 0,
                stage: .day0Baseline,
                eligibleSessionCount: 0,
                currentLever: nil,
                prescription: nil,
                hasRealWorldCheckIn: false,
                firstWeekRead: nil,
                nextAction: .recordSpokenBaseline,
                notificationIntent: .recordSpokenBaseline
            )
        }

        let programStartDay = calendar.startOfDay(for: programStartedAt)
        let currentDay = calendar.startOfDay(for: now)
        guard let elapsedDays = calendar.dateComponents(
            [.day],
            from: programStartDay,
            to: currentDay
        ).day,
              elapsedDays >= 0 else {
            return nil
        }

        let firstWeekEnd = calendar.date(
            byAdding: .day,
            value: finalDay + 1,
            to: programStartDay
        ) ?? now.addingTimeInterval(1)
        let evidenceUpperBound = min(now, firstWeekEnd.addingTimeInterval(-0.001))

        let eligibleSessions = sessionsThroughNow
            .filter {
                programStartedAt <= $0.date
                    && $0.date <= evidenceUpperBound
            }
        let coaching = input.coachingEvidence
        let currentLever: SkillArea? = {
            guard let observedAt = coaching?.observedAt,
                  programStartedAt <= observedAt,
                  observedAt <= evidenceUpperBound else { return nil }
            return coaching?.currentLever
        }()
        let prescription: PrescriptionEvidence? = {
            guard let value = coaching?.prescription,
                  let prescribedAt = value.prescribedAt,
                  programStartedAt <= prescribedAt,
                  prescribedAt <= evidenceUpperBound else { return nil }
            return value
        }()
        let hasRealWorldCheckIn: Bool = {
            guard let checkIn = coaching?.latestCheckIn,
                  programStartedAt <= checkIn.recordedAt,
                  checkIn.recordedAt <= evidenceUpperBound else { return false }
            return checkIn.includesRealWorldContext
        }()
        let longitudinalTrend = validatedLongitudinalTrend(
            coaching?.longitudinalTrend,
            eligibleSessions: eligibleSessions
        )

        let stage = stage(forDay: elapsedDays)
        let nextAction = nextAction(
            stage: stage,
            eligibleSessionCount: eligibleSessions.count,
            currentLever: currentLever,
            prescription: prescription,
            hasRealWorldCheckIn: hasRealWorldCheckIn,
            now: now
        )

        return Snapshot(
            accountID: activeAccountID,
            activation: input.activation,
            day: elapsedDays,
            stage: stage,
            eligibleSessionCount: eligibleSessions.count,
            currentLever: currentLever,
            prescription: prescription,
            hasRealWorldCheckIn: hasRealWorldCheckIn,
            firstWeekRead: stage == .day7FirstWeekRead
                ? firstWeekRead(
                    eligibleSessions: eligibleSessions,
                    longitudinalTrend: longitudinalTrend,
                    currentLever: currentLever,
                    prescription: prescription,
                    now: now
                )
                : nil,
            nextAction: nextAction,
            notificationIntent: notificationIntent(for: nextAction)
        )
    }

    /// Revalidates only the evidence references in a saved read. Later reps,
    /// memory changes, and a newly-computed trajectory cannot upgrade or
    /// otherwise rewrite the saved receipt. If a referenced source session is
    /// deleted or no longer matches its recorded schema, the returned display
    /// projection withholds that claim while the immutable saved receipt stays
    /// untouched in `CoachMemoryStore`.
    static func displayProjection(
        from saved: FirstWeekReadSnapshot,
        activation: ActivationReceipt,
        sessions: [PracticeSession],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FirstWeekReadProjection {
        let sessionsThroughNow = PracticeProgressEligibility
            .eligibleSessions(in: sessions)
            .filter {
                activation.completedAt <= $0.date
                    && $0.date <= now
            }
        let eligibleSessions: [PracticeSession] = {
            guard let programStartedAt = sessionsThroughNow
                .min(by: { $0.date < $1.date })?
                .date else { return [] }
            let programStartDay = calendar.startOfDay(for: programStartedAt)
            let firstWeekEnd = calendar.date(
                byAdding: .day,
                value: finalDay + 1,
                to: programStartDay
            ) ?? programStartedAt
            let evidenceUpperBound = min(
                now,
                firstWeekEnd.addingTimeInterval(-0.001)
            )
            return sessionsThroughNow.filter {
                programStartedAt <= $0.date && $0.date <= evidenceUpperBound
            }
        }()

        let savedTrend: CoachLongitudinalTrendProjection? = {
            guard case .verifiedComparison(let trend) = saved.projection.whatChanged else {
                return nil
            }
            return validatedLongitudinalTrend(
                trend,
                eligibleSessions: eligibleSessions
            )
        }()
        let change: FirstWeekReadProjection.Change
        var remainsUnproven = saved.projection.remainsUnproven
        switch saved.projection.whatChanged {
        case .notYetProven:
            change = saved.projection.whatChanged
        case .verifiedComparison:
            if let savedTrend {
                change = .verifiedComparison(savedTrend)
            } else {
                change = .notYetProven(eligibleRepCount: eligibleSessions.count)
                if !remainsUnproven.contains(.practiceChange) {
                    remainsUnproven.insert(.practiceChange, at: 0)
                }
            }
        }

        let verifiedExample: FirstWeekReadProjection.VerifiedExampleReference? =
            saved.projection.verifiedExample.flatMap { reference in
            guard reference.comparisonMetricSchemaVersion
                    == PracticeSession.currentComparisonMetricSchemaVersion,
                  let source = eligibleSessions.first(where: { $0.id == reference.sessionID }),
                  source.date == reference.recordedAt,
                  source.mode == reference.mode,
                  source.score == reference.score,
                  source.comparisonMetricSchemaVersion
                    == reference.comparisonMetricSchemaVersion,
                  ProofMomentService.canProduceRestrainedProof(from: source) else {
                return nil
            }
            return reference
        }

        return FirstWeekReadProjection(
            whatChanged: change,
            remainsUnproven: remainsUnproven,
            verifiedExample: verifiedExample,
            nextWeekPlan: saved.projection.nextWeekPlan
        )
    }

    private static func validatedLongitudinalTrend(
        _ trend: CoachLongitudinalTrendProjection?,
        eligibleSessions: [PracticeSession]
    ) -> CoachLongitudinalTrendProjection? {
        guard let trend,
              trend.comparisonMetricSchemaVersion == PracticeSession.currentComparisonMetricSchemaVersion,
              trend.comparableSessionIDs.count >= RecommendationComparisonEngine.minimumComparisonSamples,
              !trend.metrics.isEmpty else {
            return nil
        }

        let eligibleIDs = Set(eligibleSessions.map(\.id))
        guard eligibleIDs.contains(trend.sourceSessionID),
              trend.comparableSessionIDs.allSatisfy(eligibleIDs.contains),
              !trend.comparableSessionIDs.contains(trend.sourceSessionID),
              trend.metrics.allSatisfy({ metric in
                  metric.currentValue.isFinite && metric.priorAverage.isFinite
              }) else {
            return nil
        }
        return trend
    }

    private static func firstWeekRead(
        eligibleSessions: [PracticeSession],
        longitudinalTrend: CoachLongitudinalTrendProjection?,
        currentLever: SkillArea?,
        prescription: PrescriptionEvidence?,
        now: Date
    ) -> FirstWeekReadProjection {
        let change: FirstWeekReadProjection.Change = if let longitudinalTrend {
            .verifiedComparison(longitudinalTrend)
        } else {
            .notYetProven(eligibleRepCount: eligibleSessions.count)
        }

        var remainsUnproven: [FirstWeekReadProjection.UnprovenArea] = [
            .realWorldOutcome,
            .durability,
        ]
        if longitudinalTrend == nil {
            remainsUnproven.insert(.practiceChange, at: 0)
        }

        let proofCapableSessions = eligibleSessions.filter {
            ProofMomentService.canProduceRestrainedProof(from: $0)
        }
        let preferredExampleID = longitudinalTrend?.sourceSessionID
        let exampleSession = preferredExampleID.flatMap { sourceID in
            proofCapableSessions.first { $0.id == sourceID }
        } ?? proofCapableSessions.max { lhs, rhs in
            let lhsScore = lhs.score ?? Int.min
            let rhsScore = rhs.score ?? Int.min
            if lhsScore != rhsScore { return lhsScore < rhsScore }
            return lhs.date < rhs.date
        }
        let verifiedExample: FirstWeekReadProjection.VerifiedExampleReference? = exampleSession.flatMap { session in
            guard session.comparisonMetricSchemaVersion == PracticeSession.currentComparisonMetricSchemaVersion else {
                return nil
            }
            return FirstWeekReadProjection.VerifiedExampleReference(
                sessionID: session.id,
                recordedAt: session.date,
                mode: session.mode,
                score: session.score,
                comparisonMetricSchemaVersion: PracticeSession.currentComparisonMetricSchemaVersion
            )
        }

        let reviewNeeded = prescription?.needsReview(at: now) == true
        let remainingReps = reviewNeeded
            ? 0
            : max(
                1,
                (prescription?.minimumFollowedRepsForReview ?? 1)
                    - (prescription?.followedRepCount ?? 0)
            )
        let nextWeekAction: NextAction = reviewNeeded
            ? .compareAndAdapt(lever: currentLever, mode: prescription?.mode)
            : .repeatRep(mode: prescription?.mode)

        return FirstWeekReadProjection(
            whatChanged: change,
            remainsUnproven: remainsUnproven,
            verifiedExample: verifiedExample,
            nextWeekPlan: FirstWeekReadProjection.NextWeekPlan(
                lever: currentLever,
                mode: prescription?.mode,
                remainingComparableRepsBeforeReview: remainingReps,
                recommendedAction: nextWeekAction
            )
        )
    }

    private static func stage(forDay day: Int) -> Stage {
        switch day {
        case 0: return .day0Baseline
        case 1...2: return .day1To2Repeat
        case 3...4: return .day3To4CompareAndAdapt
        case 5...6: return .day5To6RealWorldCheckIn
        default: return .day7FirstWeekRead
        }
    }

    private static func nextAction(
        stage: Stage,
        eligibleSessionCount: Int,
        currentLever: SkillArea?,
        prescription: PrescriptionEvidence?,
        hasRealWorldCheckIn: Bool,
        now _: Date
    ) -> NextAction {
        // A written Day-0 value does not become spoken evidence merely because
        // the calendar advanced. Keep asking for the bounded baseline until an
        // eligible rep exists, then continue the staged plan.
        guard eligibleSessionCount > 0 else { return .recordSpokenBaseline }

        switch stage {
        case .day0Baseline:
            return .repeatRep(mode: prescription?.mode)
        case .day1To2Repeat:
            return .repeatRep(mode: prescription?.mode)
        case .day3To4CompareAndAdapt:
            return .compareAndAdapt(
                lever: currentLever,
                mode: prescription?.mode
            )
        case .day5To6RealWorldCheckIn:
            guard !hasRealWorldCheckIn else {
                return .repeatRep(mode: prescription?.mode)
            }
            return .realWorldCheckIn
        case .day7FirstWeekRead:
            return .reviewFirstWeekRead
        }
    }

    private static func notificationIntent(for action: NextAction) -> NotificationIntent {
        switch action {
        case .recordSpokenBaseline: return .recordSpokenBaseline
        case .repeatRep: return .repeatRep
        case .compareAndAdapt: return .compareAndAdapt
        case .realWorldCheckIn: return .realWorldCheckIn
        case .reviewFirstWeekRead: return .firstWeekRead
        }
    }

    private static func normalized(_ rawValue: String) -> String? {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

/// The single live-store bridge for first-week surfaces. Home and detail
/// surfaces use `current`, while non-presentational consumers such as future
/// notification scheduling use `projection`. Both reuse the same account,
/// hydration, activation, and trajectory gates; only current presentation may
/// capture the durable Day-7 read. The underlying contract remains pure and
/// directly testable.
@MainActor
enum FirstWeekCoachingSnapshotResolver {
    /// Whether resolving a qualified Day-7 snapshot is allowed to create the
    /// durable, write-once read receipt. Future notification projections must
    /// remain side-effect free; only a surface presenting the read now may
    /// capture it.
    enum ReadExposure {
        case projectionOnly
        case captureForPresentation
    }

    typealias FirstWeekReadCapture = (
        _ projection: FirstWeekCoachingContract.FirstWeekReadProjection,
        _ expectedAccountID: String,
        _ capturedAt: Date
    ) -> FirstWeekCoachingContract.FirstWeekReadSnapshot?

    /// Resolves the snapshot for a Home/detail surface presenting current
    /// state. This is the sole live-store path that may capture the qualified
    /// Day-7 read.
    static func current(
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> FirstWeekCoachingContract.Snapshot? {
        resolveLiveSnapshot(
            now: now,
            calendar: calendar,
            readExposure: .captureForPresentation
        )
    }

    /// Projects state for a future or non-presentational consumer such as the
    /// notification scheduler. It deliberately returns the live projection
    /// without creating or mutating the durable Day-7 read receipt.
    static func projection(
        at projectedDate: Date,
        calendar: Calendar = .current
    ) -> FirstWeekCoachingContract.Snapshot? {
        resolveLiveSnapshot(
            now: projectedDate,
            calendar: calendar,
            readExposure: .projectionOnly
        )
    }

    private static func resolveLiveSnapshot(
        now: Date,
        calendar: Calendar,
        readExposure: ReadExposure
    ) -> FirstWeekCoachingContract.Snapshot? {
        let auth = AuthManager.shared
        guard auth.initialAccountHydrationState == .ready,
              let rawAccountID = auth.currentAccountID else {
            return nil
        }
        let accountID = rawAccountID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accountID.isEmpty,
              let sessionEpoch = PracticeSessionStore.shared.loadedAccountEpoch,
              sessionEpoch.accountScope == accountID else {
            return nil
        }

        let eligibleSessions = PracticeSessionStore.shared.progressEligibleSessions
        let activation: FirstWeekCoachingContract.ActivationReceipt?
        if let draft = CoachingProfileStore.shared.onboardingDraft {
            activation = FirstWeekCoachingContract.ActivationReceipt(
                accountID: accountID,
                draft: draft
            )
        } else if let earliest = eligibleSessions.min(by: { $0.date < $1.date }) {
            activation = FirstWeekCoachingContract.ActivationReceipt(
                accountID: accountID,
                earliestEligibleSession: earliest
            )
        } else {
            activation = nil
        }
        guard let activation else { return nil }

        let memory = CoachMemoryStore.shared.currentMemory
        let trajectory = UserTrajectoryCache.shared.snapshot(
            profile: CoachingProfileStore.shared.profile,
            baseline: BaselineStore.shared.baseline,
            rating: RatingStore.shared.rating,
            sessions: eligibleSessions,
            coachMemory: memory
        ).snapshot

        guard let liveSnapshot = FirstWeekCoachingContract.resolve(
            input: FirstWeekCoachingContract.Input(
                activeAccountID: accountID,
                activation: activation,
                sessionEvidence: FirstWeekCoachingContract.SessionEvidence(
                    accountID: sessionEpoch.accountScope,
                    sessions: eligibleSessions
                ),
                coachingEvidence: FirstWeekCoachingContract.CoachingEvidence(
                    accountID: accountID,
                    memory: memory,
                    latestCheckIn: CoachCheckInStore.shared.latest,
                    longitudinalTrend: trajectory.qualifiedLongitudinalTrend
                )
            ),
            now: now,
            calendar: calendar
        ) else {
            return nil
        }

        return applyingReadExposure(
            readExposure,
            to: liveSnapshot,
            activation: activation,
            eligibleSessions: eligibleSessions,
            now: now,
            calendar: calendar,
            capture: { projection, expectedAccountID, capturedAt in
                CoachMemoryStore.shared.captureFirstWeekReadIfNeeded(
                    projection,
                    expectedAccountID: expectedAccountID,
                    capturedAt: capturedAt
                )
            }
        )
    }

    /// Dependency-injected seam that keeps the side-effect boundary explicit
    /// and behaviorally testable without touching live account stores.
    static func applyingReadExposure(
        _ readExposure: ReadExposure,
        to liveSnapshot: FirstWeekCoachingContract.Snapshot,
        activation: FirstWeekCoachingContract.ActivationReceipt,
        eligibleSessions: [PracticeSession],
        now: Date,
        calendar: Calendar,
        capture: FirstWeekReadCapture
    ) -> FirstWeekCoachingContract.Snapshot? {
        // A written-only account remains on the spoken-baseline action even
        // after Day 7; do not freeze an empty read before the product has any
        // spoken evidence. A future projection may expose the intended action
        // and lock-screen-safe copy, but it must never write the receipt.
        guard liveSnapshot.nextAction == .reviewFirstWeekRead,
              let candidate = liveSnapshot.firstWeekRead else {
            return liveSnapshot
        }
        guard readExposure == .captureForPresentation else {
            return liveSnapshot
        }
        guard let saved = capture(candidate, liveSnapshot.accountID, now) else {
            // No volatile Day-7 read: if durable account memory cannot accept
            // the receipt, the surface fails closed and tries again later.
            return nil
        }
        let displayedRead = FirstWeekCoachingContract.displayProjection(
            from: saved,
            activation: activation,
            sessions: eligibleSessions,
            now: now,
            calendar: calendar
        )
        return liveSnapshot.replacingFirstWeekRead(displayedRead)
    }
}
