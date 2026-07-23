import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Pure coaching-contract calendar used by the first-week scheduler. Each
/// day is a separate one-shot request, so its coaching meaning cannot remain
/// frozen inside a repeating notification after the contract advances.
struct FirstWeekNotificationSchedule {
    struct Delivery: Equatable {
        let day: Int
        let fireAt: Date
    }

    /// The written receipt remains the acquisition cohort anchor, while the
    /// notification program follows the spoken contract. Until a qualifying
    /// baseline exists, `now` keeps one Day-0 reminder available instead of
    /// silently expiring the journey seven calendar days after writing.
    static func contractAnchor(
        activationAt: Date,
        sessions: [PracticeSession],
        now: Date
    ) -> Date {
        PracticeProgressEligibility.eligibleSessions(in: sessions)
            .filter { activationAt <= $0.date && $0.date <= now }
            .min(by: { $0.date < $1.date })?
            .date ?? now
    }

    static func deliveries(
        activationAt: Date,
        now: Date,
        reminderHour: Int,
        reminderMinute: Int,
        calendar: Calendar = .current
    ) -> [Delivery] {
        let activationDay = calendar.startOfDay(for: activationAt)
        let hour = max(0, min(23, reminderHour))
        let minute = max(0, min(59, reminderMinute))

        return (0...FirstWeekCoachingContract.finalDay).compactMap { day in
            guard let dayStart = calendar.date(
                byAdding: .day,
                value: day,
                to: activationDay
            ) else { return nil }
            var components = calendar.dateComponents(
                [.year, .month, .day],
                from: dayStart
            )
            components.hour = hour
            components.minute = minute
            components.second = 0
            guard let fireAt = calendar.date(from: components),
                  fireAt > now else { return nil }
            return Delivery(day: day, fireAt: fireAt)
        }
    }

    /// The coaching contract owns daily-rhythm notification copy from the
    /// activation calendar day through the end of Day 7. The Day-7 read stays
    /// available later, but must not suppress the user's ordinary reminder
    /// settings indefinitely.
    static func isActivationWindowActive(
        activationAt: Date,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard activationAt <= now else { return false }
        let activationDay = calendar.startOfDay(for: activationAt)
        let currentDay = calendar.startOfDay(for: now)
        guard let elapsedDays = calendar.dateComponents(
            [.day],
            from: activationDay,
            to: currentDay
        ).day else {
            return false
        }
        return (0...FirstWeekCoachingContract.finalDay).contains(elapsedDays)
    }
}

/// Pure schedule projection for the three user-controlled rhythm toggles.
/// During Days 0-7, generic streak/digest copy is withheld and the existing
/// daily-reminder permission is projected onto the first-week contract. This
/// preserves notification frequency consent while guaranteeing that any
/// rhythm notification sent in the activation window names the unfinished
/// coaching step.
struct DailyRhythmNotificationPlan: Equatable {
    let firstWeekWindowActive: Bool
    let scheduleFirstWeekContract: Bool
    let scheduleDailyReminder: Bool
    let scheduleStreakWarning: Bool
    let scheduleWeeklyDigest: Bool

    static func resolve(
        activationAt: Date?,
        now: Date,
        dailyReminderEnabled: Bool,
        streakWarningEnabled: Bool,
        weeklyDigestEnabled: Bool,
        calendar: Calendar = .current
    ) -> DailyRhythmNotificationPlan {
        let firstWeekWindowActive = activationAt.map {
            FirstWeekNotificationSchedule.isActivationWindowActive(
                activationAt: $0,
                now: now,
                calendar: calendar
            )
        } ?? false

        if firstWeekWindowActive {
            return DailyRhythmNotificationPlan(
                firstWeekWindowActive: true,
                scheduleFirstWeekContract: dailyReminderEnabled,
                scheduleDailyReminder: false,
                scheduleStreakWarning: false,
                scheduleWeeklyDigest: false
            )
        }

        return DailyRhythmNotificationPlan(
            firstWeekWindowActive: false,
            scheduleFirstWeekContract: false,
            scheduleDailyReminder: dailyReminderEnabled,
            scheduleStreakWarning: streakWarningEnabled,
            scheduleWeeklyDigest: weeklyDigestEnabled
        )
    }
}

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    // MARK: - Legacy follow-up toggle (kept for the existing post-session flow)

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: remindersEnabledKey)
        }
    }

    @Published private(set) var authorizationLabel: String = "Not requested"

    // MARK: - Daily-rhythm surfaces (per VISION milestone 1)

    /// Daily reminder fires at the user's chosen time of day. Persistent.
    @Published var dailyReminderEnabled: Bool {
        didSet { persistAndReschedule(key: dailyReminderEnabledKey, value: dailyReminderEnabled) }
    }

    /// Hour (0–23) component of the daily reminder. Default 9 AM.
    @Published var dailyReminderHour: Int {
        didSet { persistAndReschedule(key: dailyReminderHourKey, value: dailyReminderHour) }
    }

    /// Minute (0–59) component of the daily reminder. Default 0.
    @Published var dailyReminderMinute: Int {
        didSet { persistAndReschedule(key: dailyReminderMinuteKey, value: dailyReminderMinute) }
    }

    /// Evening practice nudge fires daily at 8 PM if enabled. Re-armed each
    /// day; the schedule is conditional on streak being non-zero so brand-new
    /// users don't get a misleading reminder.
    @Published var streakWarningEnabled: Bool {
        didSet { persistAndReschedule(key: streakWarningEnabledKey, value: streakWarningEnabled) }
    }

    /// Weekly digest fires Sunday 7 PM local. Idempotent re-schedule.
    @Published var weeklyDigestEnabled: Bool {
        didSet { persistAndReschedule(key: weeklyDigestEnabledKey, value: weeklyDigestEnabled) }
    }

    // MARK: - Storage keys

    private let remindersEnabledKey = "practiceRemindersEnabled"
    private let followUpRequestIdentifier = "noum.practice.followup"

    private let dailyReminderEnabledKey = "noum.notifications.dailyReminderEnabled"
    private let dailyReminderHourKey = "noum.notifications.dailyReminderHour"
    private let dailyReminderMinuteKey = "noum.notifications.dailyReminderMinute"
    private let streakWarningEnabledKey = "noum.notifications.streakWarningEnabled"
    private let weeklyDigestEnabledKey = "noum.notifications.weeklyDigestEnabled"

    // MARK: - Identifiers (so we can remove + re-add on schedule changes)

    private let dailyReminderIdentifier = "noum.daily.reminder"
    private let streakWarningIdentifier = "noum.streak.warning"
    private let weeklyDigestIdentifier = "noum.weekly.digest"
    private let bigMomentT7Identifier = "noum.bigmoment.t7"
    private let bigMomentT1Identifier = "noum.bigmoment.t1"
    private let bigMomentCheckInIdentifier = "noum.bigmoment.checkin"
    nonisolated static let firstWeekStageNotificationIdentifiers =
        (0...FirstWeekCoachingContract.finalDay).map {
            "noum.firstWeek.day.\($0)"
        }

    /// Exact retired identifier retained for one-way migration cleanup. Never
    /// add requests with this identifier again; removing pending and delivered
    /// requests on launch prevents an old repeating challenge nudge from
    /// advertising an unreachable surface after upgrade.
    nonisolated static let retiredDailyChallengeNotificationIdentifiers = [
        "noum.daily.challengeExpiry"
    ]

    // MARK: - Init

    private init() {
        if UserDefaults.standard.object(forKey: remindersEnabledKey) == nil {
            UserDefaults.standard.set(false, forKey: remindersEnabledKey)
        }
        isEnabled = UserDefaults.standard.bool(forKey: remindersEnabledKey)

        let defaults = UserDefaults.standard
        dailyReminderEnabled = defaults.bool(forKey: dailyReminderEnabledKey)
        dailyReminderHour = (defaults.object(forKey: dailyReminderHourKey) as? Int) ?? 9
        dailyReminderMinute = (defaults.object(forKey: dailyReminderMinuteKey) as? Int) ?? 0
        streakWarningEnabled = defaults.bool(forKey: streakWarningEnabledKey)
        weeklyDigestEnabled = defaults.bool(forKey: weeklyDigestEnabledKey)

        removeRetiredDailyChallengeNotifications()
        Task { await refreshAuthorizationStatus() }
    }

    // MARK: - Top-level toggle (legacy follow-up)

    func updateEnabled(_ enabled: Bool) async {
        if enabled {
            let granted = await requestAuthorizationIfNeeded()
            isEnabled = granted
        } else {
            isEnabled = false
        }
        await refreshAuthorizationStatus()
    }

    // MARK: - Daily-Rhythm Surfaces

    /// Toggles a daily-rhythm surface on/off. Wraps `requestAuthorizationIfNeeded`
    /// so the user is prompted exactly once across the three switches.
    func setDailyReminderEnabled(_ value: Bool) async {
        if value {
            let granted = await requestAuthorizationIfNeeded()
            dailyReminderEnabled = granted
        } else {
            dailyReminderEnabled = false
        }
        await refreshAuthorizationStatus()
    }

    func setStreakWarningEnabled(_ value: Bool) async {
        if value {
            let granted = await requestAuthorizationIfNeeded()
            streakWarningEnabled = granted
        } else {
            streakWarningEnabled = false
        }
        await refreshAuthorizationStatus()
    }

    func setWeeklyDigestEnabled(_ value: Bool) async {
        if value {
            let granted = await requestAuthorizationIfNeeded()
            weeklyDigestEnabled = granted
        } else {
            weeklyDigestEnabled = false
        }
        await refreshAuthorizationStatus()
    }

    /// Re-arms all enabled daily-rhythm surfaces. Idempotent and safe to call
    /// from `.task` on app launch or after any of the toggles flips.
    /// **Never** triggers iOS's hard system permission prompt — that's
    /// reserved for the explicit `set*Enabled(true)` toggles after the
    /// user has read the soft-sell `NotificationPrePromptSheet`. Passive
    /// foreground refreshes simply re-arm whatever is already granted +
    /// enabled, and silently no-op otherwise.
    func refreshScheduledNotifications() {
#if canImport(UserNotifications)
        // Migration cleanup must run even when notification authorization is
        // denied: an older build may already have delivered or pending copies.
        removeRetiredDailyChallengeNotifications()
        Task {
            let center = UNUserNotificationCenter.current()
            // Remove every daily-rhythm surface up front so we never double-stack.
            center.removePendingNotificationRequests(withIdentifiers: [
                dailyReminderIdentifier,
                streakWarningIdentifier,
                weeklyDigestIdentifier,
            ] + Self.firstWeekStageNotificationIdentifiers)

            // Read authorization state passively — do NOT request, do NOT
            // surface the system prompt. The pre-prompt sheet handles asks.
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                break
            default:
                return
            }

            let now = Date()
            let firstWeekSnapshot = FirstWeekCoachingSnapshotResolver.projection(
                at: now
            )
            let contractAnchor = firstWeekSnapshot.map {
                FirstWeekNotificationSchedule.contractAnchor(
                    activationAt: $0.activation.completedAt,
                    sessions: PracticeSessionStore.shared.sessions,
                    now: now
                )
            }
            let plan = DailyRhythmNotificationPlan.resolve(
                activationAt: contractAnchor,
                now: now,
                dailyReminderEnabled: dailyReminderEnabled,
                streakWarningEnabled: streakWarningEnabled,
                weeklyDigestEnabled: weeklyDigestEnabled
            )

            if plan.scheduleFirstWeekContract {
                await scheduleFirstWeekNotifications(now: now)
            }
            if plan.scheduleDailyReminder {
                await scheduleDailyReminder()
            }
            if plan.scheduleStreakWarning {
                await scheduleStreakWarning()
            }
            if plan.scheduleWeeklyDigest {
                await scheduleWeeklyDigest()
            }

            // Re-arm the active Big Moment's spine (T-7 / T-1 countdown +
            // day-after check-in). Closes the authorization race: a moment
            // set before the rep-1 pre-prompt accept grants authorization
            // would otherwise never arm. `scheduleBigMomentCountdown`
            // removes its own identifiers first, so this pass is
            // idempotent. When no moment is active we deliberately do NOT
            // remove the Big Moment identifiers — an already-armed
            // day-after check-in for a just-archived moment must survive
            // launch refreshes until it fires or the user checks in.
            if let activeMoment = BigMomentStore.shared.activeMoment {
                await scheduleBigMomentCountdown(for: activeMoment)
            }
        }
#endif
    }

    private func removeRetiredDailyChallengeNotifications() {
#if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let identifiers = Self.retiredDailyChallengeNotificationIdentifiers
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
#endif
    }

    // MARK: - Schedulers

    private func scheduleDailyReminder() async {
#if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        let snapshot = SharedNoumState.read()
        let copy = NotificationCopy.dailyReminder(
            streakDays: snapshot.currentStreak,
            todayDone: snapshot.repsToday > 0
        )
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        content.userInfo = attribution(
            kind: .practiceReminder,
            route: "noum://train"
        )

        var components = DateComponents()
        components.hour = max(0, min(23, dailyReminderHour))
        components.minute = max(0, min(59, dailyReminderMinute))

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderIdentifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
#endif
    }

    /// Installs the remaining activation-relative first-week days as separate
    /// one-shot requests. Re-running this after a rep or check-in removes and
    /// rebuilds them from the current evidence owners, so future routes always
    /// point at the step that is still unfinished.
    private func scheduleFirstWeekNotifications(now: Date) async {
#if canImport(UserNotifications)
        guard let current = FirstWeekCoachingSnapshotResolver.projection(at: now),
              current.day <= FirstWeekCoachingContract.finalDay else {
            return
        }
        let contractAnchor = FirstWeekNotificationSchedule.contractAnchor(
            activationAt: current.activation.completedAt,
            sessions: PracticeSessionStore.shared.sessions,
            now: now
        )
        let deliveries = FirstWeekNotificationSchedule.deliveries(
            activationAt: contractAnchor,
            now: now,
            reminderHour: dailyReminderHour,
            reminderMinute: dailyReminderMinute
        )
        guard !deliveries.isEmpty else { return }

        let center = UNUserNotificationCenter.current()
        for delivery in deliveries {
            guard let projected = FirstWeekCoachingSnapshotResolver.projection(
                at: delivery.fireAt
            ) else { continue }
            let copy = NotificationCopy.firstWeek(intent: projected.notificationIntent)
            let content = UNMutableNotificationContent()
            content.title = copy.title
            content.body = copy.body
            content.sound = .default
            content.userInfo = FirstWeekNotificationAttribution(
                snapshot: projected
            ).userInfo

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: delivery.fireAt
            )
            let request = UNNotificationRequest(
                identifier: Self.firstWeekStageNotificationIdentifiers[delivery.day],
                content: content,
                trigger: UNCalendarNotificationTrigger(
                    dateMatching: components,
                    repeats: false
                )
            )
            try? await center.add(request)
        }
#endif
    }

    private func scheduleStreakWarning() async {
#if canImport(UserNotifications)
        // Evening rhythm nudges are useful only after the user has actually
        // practiced before. New users at streak 0 get the ordinary daily
        // reminder, never a fake "you have a streak" message.
        let snapshot = SharedNoumState.read()
        guard snapshot.currentStreak > 0 else {
            // Quietly skip — when the user builds a streak, the next
            // refresh re-arms this with real numbers.
            return
        }
        // Skip if they've already practiced today.
        guard snapshot.repsToday == 0 else { return }

        let content = UNMutableNotificationContent()
        let copy = NotificationCopy.streakWarning(
            streakDays: snapshot.currentStreak,
            freezesAvailable: snapshot.freezesAvailable
        )
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        content.userInfo = attribution(
            kind: .practiceReminder,
            route: "noum://train"
        )

        // 8 PM local — late enough to be useful, calm enough to avoid
        // countdown or loss-framed pressure.
        var components = DateComponents()
        components.hour = 20
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: streakWarningIdentifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
#endif
    }

    private func scheduleWeeklyDigest() async {
#if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        let copy = NotificationCopy.weeklyDigest(
            weeklyReps: SharedNoumState.read().weeklyReps,
            chosenStyleGoal: CoachingProfileStore.shared.profile?.chosenStyleGoal
        )
        content.title = copy.title
        content.body = copy.body
        content.sound = .default
        content.userInfo = attribution(
            kind: .weeklyRead,
            route: "noum://home"
        )

        // Sunday 7 PM local. ISO weekday 1 = Sunday.
        var components = DateComponents()
        components.weekday = 1
        components.hour = 19
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: weeklyDigestIdentifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
#endif
    }

    // MARK: - Big Moment countdown notifications

    /// Schedules T-7 and T-1 notifications plus the day-after check-in
    /// for the given `BigMoment`. Call when the user sets or updates
    /// their Big Moment; removes its own identifiers first so repeated
    /// calls (including the launch re-arm pass) never double-stack.
    ///
    /// Privacy contract: NEVER expose `moment.title` (user-authored text)
    /// on the lock screen. Use `category.displayName` only — the title
    /// could contain sensitive information the user doesn't want visible
    /// on a shared or unattended device.
    ///
    /// Authorization is checked passively — this never triggers the hard
    /// system prompt (the soft pre-prompt sheet owns asks). A moment set
    /// before the user authorizes is re-armed by
    /// `refreshScheduledNotifications()` on the next launch/toggle pass.
    func scheduleBigMomentCountdown(for moment: BigMoment) async {
#if canImport(UserNotifications)
        guard let eventDate = moment.date else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            bigMomentT7Identifier,
            bigMomentT1Identifier,
            bigMomentCheckInIdentifier
        ])

        let settings = await center.notificationSettings()
        guard [.authorized, .provisional, .ephemeral].contains(settings.authorizationStatus) else {
            return
        }

        let categoryName = moment.category.displayName
        let calendar = Calendar.current

        // T-7: 7 days before the event at 9 AM local.
        if let t7Date = calendar.date(byAdding: .day, value: -7, to: eventDate) {
            var t7Components = calendar.dateComponents([.year, .month, .day], from: t7Date)
            t7Components.hour = 9
            t7Components.minute = 0
            let t7Content = UNMutableNotificationContent()
            t7Content.title = "7 days to your \(categoryName)."
            t7Content.body = "Time for a focused rep."
            t7Content.sound = .default
            t7Content.userInfo = attribution(
                kind: .bigMoment,
                route: "noum://train"
            )
            let t7Trigger = UNCalendarNotificationTrigger(dateMatching: t7Components, repeats: false)
            let t7Request = UNNotificationRequest(
                identifier: bigMomentT7Identifier,
                content: t7Content,
                trigger: t7Trigger
            )
            try? await center.add(t7Request)
        }

        // T-1: 1 day before the event at 9 AM local.
        if let t1Date = calendar.date(byAdding: .day, value: -1, to: eventDate) {
            var t1Components = calendar.dateComponents([.year, .month, .day], from: t1Date)
            t1Components.hour = 9
            t1Components.minute = 0
            let t1Content = UNMutableNotificationContent()
            t1Content.title = "Tomorrow is your \(categoryName)."
            t1Content.body = "One last rep — make it the one that builds confidence."
            t1Content.sound = .default
            t1Content.userInfo = attribution(
                kind: .bigMoment,
                route: "noum://train"
            )
            let t1Trigger = UNCalendarNotificationTrigger(dateMatching: t1Components, repeats: false)
            let t1Request = UNNotificationRequest(
                identifier: bigMomentT1Identifier,
                content: t1Content,
                trigger: t1Trigger
            )
            try? await center.add(t1Request)
        }

        // Day-after check-in: ONE neutral invite the morning after the
        // event passed, closing the prepare → event → reflect loop. The
        // Home outcome card collects the user's read once they open the
        // app; this is the comeback trigger for users who don't. 10 AM
        // local — offset from the 9 AM countdown/daily-reminder slot so
        // two surfaces never fire on the same minute. Copy lives in
        // `NotificationCopy.bigMomentCheckIn` (neutral invite, never
        // guilt) and takes only the category, so the privacy contract
        // above holds by construction.
        if let dayAfter = calendar.date(byAdding: .day, value: 1, to: eventDate) {
            var checkInComponents = calendar.dateComponents([.year, .month, .day], from: dayAfter)
            checkInComponents.hour = 10
            checkInComponents.minute = 0
            let copy = NotificationCopy.bigMomentCheckIn(category: moment.category)
            let checkInContent = UNMutableNotificationContent()
            checkInContent.title = copy.title
            checkInContent.body = copy.body
            checkInContent.sound = .default
            checkInContent.userInfo = attribution(
                kind: .bigMoment,
                route: "noum://home"
            )
            let checkInTrigger = UNCalendarNotificationTrigger(dateMatching: checkInComponents, repeats: false)
            let checkInRequest = UNNotificationRequest(
                identifier: bigMomentCheckInIdentifier,
                content: checkInContent,
                trigger: checkInTrigger
            )
            try? await center.add(checkInRequest)
        }
#endif
    }

    /// Cancels any pending Big Moment notifications (countdown + the
    /// day-after check-in). Call when the user clears or changes their
    /// Big Moment.
    func cancelBigMomentNotifications() {
#if canImport(UserNotifications)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            bigMomentT7Identifier,
            bigMomentT1Identifier,
            bigMomentCheckInIdentifier
        ])
#endif
    }

    /// Cancels ONLY the pending day-after check-in. Called the moment an
    /// outcome report is saved in-app — a push inviting a check-in the
    /// user has already done would be a lie.
    func cancelBigMomentCheckIn() {
#if canImport(UserNotifications)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            bigMomentCheckInIdentifier
        ])
#endif
    }

    // MARK: - Persist + reschedule helper

    private func persistAndReschedule(key: String, value: Any) {
        UserDefaults.standard.set(value, forKey: key)
        refreshScheduledNotifications()
    }

    // MARK: - Post-session follow-up (+18h coach-continuity nudge)

    /// Lightweight cache of the most recent session's follow-up payload. Held
    /// on this existing singleton (not a new store) so that if the user enables
    /// the post-session follow-up *after* a rep finalizes — e.g. by accepting
    /// the notification pre-prompt that fires on rep 1 — we can still arm the
    /// +18h nudge for that rep instead of silently missing it. This was the
    /// bug: the accept flow flipped the three daily-rhythm surfaces but never
    /// set `isEnabled`, so the follow-up surface was dead for opt-in users.
    private struct PendingFollowUp {
        var profile: CoachingProfile?
        var relationship: IMRelationshipProfile?
        var sessions: [PracticeSession]
        var practiceTitle: String
        var nextMove: String?
    }
    private var pendingFollowUp: PendingFollowUp?

    func scheduleFollowUpReminder(
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        sessions: [PracticeSession],
        practiceTitle: String,
        nextMove: String?
    ) async {
        // Always remember the latest payload so a later opt-in (the rep-1
        // pre-prompt accept, which lands after this rep finalizes) can still
        // arm this rep's follow-up rather than waiting for the next session.
        pendingFollowUp = PendingFollowUp(
            profile: profile,
            relationship: relationship,
            sessions: sessions,
            practiceTitle: practiceTitle,
            nextMove: nextMove
        )
        // A completed rep can change the first-week unfinished step. Re-arm
        // the existing daily/weekly requests immediately so stale copy does
        // not keep asking for work the user has already done.
        refreshScheduledNotifications()
        await performFollowUpSchedule()
    }

    /// Master toggle for the post-session follow-up. The notification
    /// pre-prompt's "Turn on reminders" path now calls this so the +18h nudge
    /// joins the three daily-rhythm surfaces. Previously `isEnabled` was never
    /// set from the accept flow, so the follow-up never fired for opt-in users.
    func setFollowUpEnabled(_ value: Bool) async {
        if value {
            let granted = await requestAuthorizationIfNeeded()
            isEnabled = granted
            if granted { await performFollowUpSchedule() }
        } else {
            isEnabled = false
        }
        await refreshAuthorizationStatus()
    }

    private func performFollowUpSchedule() async {
#if canImport(UserNotifications)
        guard isEnabled else { return }
        guard let pending = pendingFollowUp else { return }
        guard await requestAuthorizationIfNeeded() else {
            isEnabled = false
            return
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        let retentionSnapshot = RetentionLoopEngine.snapshot(
            sessions: pending.sessions,
            profile: pending.profile,
            displayedStreak: StreakFreezeManager.shared.currentStreak
        )
        content.title = reminderTitle(
            profile: pending.profile,
            relationship: pending.relationship,
            practiceTitle: pending.practiceTitle,
            challenge: retentionSnapshot.activeChallenge
        )
        content.body = reminderBody(
            profile: pending.profile,
            relationship: pending.relationship,
            nextMove: pending.nextMove,
            challenge: retentionSnapshot.activeChallenge
        )
        content.userInfo = attribution(
            kind: .reengagement,
            route: "noum://train"
        )

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60 * 60 * 18, repeats: false)
        let request = UNNotificationRequest(
            identifier: followUpRequestIdentifier,
            content: content,
            trigger: trigger
        )

        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [followUpRequestIdentifier])
        try? await center.add(request)
        await refreshAuthorizationStatus()
#endif
    }

    private func reminderTitle(
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        practiceTitle: String,
        challenge: PracticeChallengeStatus
    ) -> String {
        if relationship != nil {
            return "Your Conversation Practice rep is ready"
        }
        if challenge.progress < 1 {
            return challenge.title
        }
        return "Time for a quick practice rep"
    }

    private func reminderBody(
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        nextMove: String?,
        challenge: PracticeChallengeStatus
    ) -> String {
        if let relationship {
            return "\(relationship.scenario.personaName) is ready for another round. A quick rep keeps the momentum going."
        }

        if challenge.progress < 1 {
            return "\(challenge.summary) You're at \(challenge.progressLabel.lowercased()) right now."
        }

        if let profile, !profile.personalGoalReference.isEmpty {
            return "You set a goal that matters to you. One more rep moves you closer."
        }

        if profile != nil {
            return "You've got a reason to practice today. A short session keeps you moving forward."
        }

        return "A short follow-up rep now will make the next conversation feel easier."
    }

    private func attribution(
        kind: GrowthNotificationKind,
        route: String
    ) -> [AnyHashable: Any] {
        guard let url = URL(string: route),
              let value = GrowthNotificationAttribution(kind: kind, route: url) else {
            return [:]
        }
        return value.userInfo
    }

    // MARK: - Authorization

    private func requestAuthorizationIfNeeded() async -> Bool {
#if canImport(UserNotifications)
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            let correlationID = UUID()
            FlowEventGrowthEventSink.shared.record(
                GrowthEvent(
                    correlationID: correlationID,
                    name: .notificationOptInPrompted
                )
            )
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            FlowEventGrowthEventSink.shared.record(
                GrowthEvent(
                    correlationID: correlationID,
                    name: granted ? .notificationOptInAccepted : .notificationOptInDeclined,
                    outcome: granted ? .succeeded : .cancelled
                )
            )
            FlowLog.log(
                correlationId: correlationID,
                flow: .other,
                stage: granted ? "notification.authorizationGranted" : "notification.authorizationDeclined",
                outcome: granted ? .success : .skipped,
                reason: "notification decision after contextual prompt"
            )
            return granted
        @unknown default:
            return false
        }
#else
        return false
#endif
    }

    func refreshAuthorizationStatus() async {
#if canImport(UserNotifications)
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationLabel = switch settings.authorizationStatus {
        case .authorized: "Allowed"
        case .provisional: "Quietly allowed"
        case .ephemeral: "Temporarily allowed"
        case .denied: "Blocked"
        case .notDetermined: "Not requested"
        @unknown default: "Unavailable"
        }
#else
        authorizationLabel = "Unavailable"
#endif
    }
}
