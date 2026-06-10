import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

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
    private let dailyChallengeExpiryIdentifier = "noum.daily.challengeExpiry"
    private let bigMomentT7Identifier = "noum.bigmoment.t7"
    private let bigMomentT1Identifier = "noum.bigmoment.t1"

    /// Fixed 8:30 PM local fire time for the daily-challenge expiry warning.
    /// Set 30 minutes after the evening practice nudge's 8 PM so the two
    /// surfaces never stack — a user with both enabled gets the rhythm ping first,
    /// then this one only if challenges are still open. Kept as a constant
    /// because the brief calls for a single nightly nudge, not a
    /// user-configurable time.
    private let dailyChallengeExpiryHour: Int = 20
    private let dailyChallengeExpiryMinute: Int = 30

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
        Task {
            let center = UNUserNotificationCenter.current()
            // Remove every daily-rhythm surface up front so we never double-stack.
            center.removePendingNotificationRequests(withIdentifiers: [
                dailyReminderIdentifier,
                streakWarningIdentifier,
                weeklyDigestIdentifier,
                dailyChallengeExpiryIdentifier
            ])

            // Read authorization state passively — do NOT request, do NOT
            // surface the system prompt. The pre-prompt sheet handles asks.
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                break
            default:
                return
            }

            if dailyReminderEnabled {
                await scheduleDailyReminder()
                // The expiry warning piggy-backs on the same "you opted
                // into daily nudges" mental model as the daily reminder.
                // No new Settings toggle — one switch controls the
                // user's appetite for evening nudges, two cohesive
                // surfaces fire under it. Always-safe: the schedule
                // method itself bails when there's nothing to nudge
                // about (no challenges open / all claimed / etc.).
                await scheduleDailyChallengeExpiryWarning()
            }
            if streakWarningEnabled {
                await scheduleStreakWarning()
            }
            if weeklyDigestEnabled {
                await scheduleWeeklyDigest()
            }
        }
#endif
    }

    // MARK: - Schedulers

    private func scheduleDailyReminder() async {
#if canImport(UserNotifications)
        let content = UNMutableNotificationContent()
        let copy = NotificationCopy.dailyReminder(
            streakDays: SharedNoumState.read().currentStreak,
            todayDone: SharedNoumState.read().repsToday > 0
        )
        content.title = copy.title
        content.body = copy.body
        content.sound = .default

        var components = DateComponents()
        components.hour = max(0, min(23, dailyReminderHour))
        components.minute = max(0, min(59, dailyReminderMinute))

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: dailyReminderIdentifier, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
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
        let copy = NotificationCopy.weeklyDigest(weeklyReps: SharedNoumState.read().weeklyReps)
        content.title = copy.title
        content.body = copy.body
        content.sound = .default

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

    /// Public, additive entry point — the caller (today: only the
    /// internal `refreshScheduledNotifications` path) re-arms the
    /// expiry warning. Reads the daily-challenge state at schedule
    /// time and bails when there's nothing to nudge about, so the
    /// notification never lies about claimable work.
    ///
    /// Anti-goal alignment: this surface MUST never punish-shame
    /// (no "you'll lose", no "Hurry") — copy lives in
    /// `NotificationCopy.dailyChallengeExpiry(unclaimedCount:)`.
    func scheduleDailyChallengeExpiryWarning() async {
#if canImport(UserNotifications)
        // Honesty guard: read the live unclaimed count from the
        // DailyChallengesManager at schedule time. If everything's
        // already claimed today (or hasn't been initialised yet),
        // there's nothing to nudge — don't arm the trigger.
        let unclaimed: Int
        let pastSoftExpiry: Bool
        if #available(iOS 17.0, macOS 12.0, *) {
            unclaimed = DailyChallengesManager.shared.unclaimedCount
            pastSoftExpiry = DailyChallengesManager.shared.isPastSoftExpiry
        } else {
            return
        }
        guard unclaimed > 0 else { return }

        // Extra restraint: if the user is already past the tile's
        // soft-expiry (9 PM in the existing M8 contract), the in-app
        // tile is already showing the muted treatment — they've seen
        // the signal. We skip the push so we don't double-nudge.
        guard !pastSoftExpiry else { return }

        let content = UNMutableNotificationContent()
        let copy = NotificationCopy.dailyChallengeExpiry(unclaimedCount: unclaimed)
        content.title = copy.title
        content.body = copy.body
        content.sound = .default

        var components = DateComponents()
        components.hour = max(0, min(23, dailyChallengeExpiryHour))
        components.minute = max(0, min(59, dailyChallengeExpiryMinute))

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: dailyChallengeExpiryIdentifier,
            content: content,
            trigger: trigger
        )
        try? await UNUserNotificationCenter.current().add(request)
#endif
    }

    // MARK: - Big Moment countdown notifications

    /// Schedules T-7 and T-1 notifications for the given `BigMoment`.
    /// Call when the user sets or updates their Big Moment; cancel first
    /// via `cancelBigMomentNotifications()` to avoid duplicates.
    ///
    /// Privacy contract: NEVER expose `moment.title` (user-authored text)
    /// on the lock screen. Use `category.displayName` only — the title
    /// could contain sensitive information the user doesn't want visible
    /// on a shared or unattended device.
    func scheduleBigMomentCountdown(for moment: BigMoment) async {
#if canImport(UserNotifications)
        guard let eventDate = moment.date else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [
            bigMomentT7Identifier,
            bigMomentT1Identifier
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
            let t1Trigger = UNCalendarNotificationTrigger(dateMatching: t1Components, repeats: false)
            let t1Request = UNNotificationRequest(
                identifier: bigMomentT1Identifier,
                content: t1Content,
                trigger: t1Trigger
            )
            try? await center.add(t1Request)
        }
#endif
    }

    /// Cancels any pending Big Moment countdown notifications.
    /// Call when the user clears or changes their Big Moment.
    func cancelBigMomentNotifications() {
#if canImport(UserNotifications)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [
            bigMomentT7Identifier,
            bigMomentT1Identifier
        ])
#endif
    }

    // MARK: - Persist + reschedule helper

    private func persistAndReschedule(key: String, value: Any) {
        UserDefaults.standard.set(value, forKey: key)
        refreshScheduledNotifications()
    }

    // MARK: - Existing post-session follow-up (kept as-is)

    func scheduleFollowUpReminder(
        profile: CoachingProfile?,
        relationship: IMRelationshipProfile?,
        sessions: [PracticeSession],
        practiceTitle: String,
        nextMove: String?
    ) async {
#if canImport(UserNotifications)
        guard isEnabled else { return }
        guard await requestAuthorizationIfNeeded() else {
            isEnabled = false
            return
        }

        let content = UNMutableNotificationContent()
        content.sound = .default
        let retentionSnapshot = RetentionLoopEngine.snapshot(
            sessions: sessions,
            profile: profile,
            displayedStreak: StreakFreezeManager.shared.currentStreak
        )
        content.title = reminderTitle(
            profile: profile,
            relationship: relationship,
            practiceTitle: practiceTitle,
            challenge: retentionSnapshot.activeChallenge
        )
        content.body = reminderBody(
            profile: profile,
            relationship: relationship,
            nextMove: nextMove,
            challenge: retentionSnapshot.activeChallenge
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
            return "Your conversation practice is waiting"
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
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
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
