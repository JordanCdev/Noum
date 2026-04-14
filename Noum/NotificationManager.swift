import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

@MainActor
final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: remindersEnabledKey)
        }
    }

    @Published private(set) var authorizationLabel: String = "Not requested"

    private let remindersEnabledKey = "practiceRemindersEnabled"
    private let followUpRequestIdentifier = "noum.practice.followup"

    private init() {
        if UserDefaults.standard.object(forKey: remindersEnabledKey) == nil {
            UserDefaults.standard.set(false, forKey: remindersEnabledKey)
        }
        isEnabled = UserDefaults.standard.bool(forKey: remindersEnabledKey)
        Task { await refreshAuthorizationStatus() }
    }

    func updateEnabled(_ enabled: Bool) async {
        if enabled {
            let granted = await requestAuthorizationIfNeeded()
            isEnabled = granted
        } else {
            isEnabled = false
        }
        await refreshAuthorizationStatus()
    }

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
        // Titles are always visible on the lock screen — keep them motivational
        // but never include user-authored text (goals, whyNow, successVision).
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
        // Body text is also visible on the lock screen by default.
        // Reference the user's coaching context without quoting their exact words.
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
