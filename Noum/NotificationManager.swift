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

    /// Streak warning fires daily at 8 PM if enabled. Re-armed each day; the
    /// schedule is conditional on streak being non-zero so brand-new users
    /// don't get a misleading warning.
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
    func refreshScheduledNotifications() {
#if canImport(UserNotifications)
        Task {
            let center = UNUserNotificationCenter.current()
            // Remove every daily-rhythm surface up front so we never double-stack.
            center.removePendingNotificationRequests(withIdentifiers: [
                dailyReminderIdentifier,
                streakWarningIdentifier,
                weeklyDigestIdentifier
            ])

            guard await requestAuthorizationIfNeeded() else { return }

            if dailyReminderEnabled {
                await scheduleDailyReminder()
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
        content.title = "Today's rep is waiting"
        content.body = "A short drill keeps the rhythm. One rep is enough to count today."
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
        let content = UNMutableNotificationContent()
        content.title = "Don't break the streak"
        content.body = "Your streak depends on a rep today. One short drill keeps it alive — or your weekly freeze covers a single miss."
        content.sound = .default

        // 8 PM local — close enough to midnight to be a meaningful nudge,
        // far enough to actually let the user act on it.
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
        content.title = "Your week, summed up"
        content.body = "Open Noum to see how this week shaped up — reps, score, and what's trending."
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
        let retentionSnapshot = RetentionLoopEngine.snapshot(sessions: sessions, profile: profile)
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
