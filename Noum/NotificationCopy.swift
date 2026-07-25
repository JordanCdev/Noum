import Foundation

// MARK: - Notification Copy
//
// All notification title + body strings live here so the voice rules apply
// uniformly. Each helper returns the copy variant most fitting for the
// user's current state — we never ship "Don't break the streak" to a user
// at streak 0, never ship a generic "open the app" body when we can name
// the actual numbers.
//
// Voice rules (lifted from `.claude/skills/noum-design`):
// - No "Let's", no chirpy filler
// - No emoji
// - Sentence case (titles can be Title Case)
// - Concrete numbers when available
// - Lock-screen-safe: never quote the user's typed goal text directly

struct NotificationLine {
    let title: String
    let body: String
}

/// Content-free attribution for Noum notifications outside the bounded
/// first-week contract. Only an enum and an app-owned route are persisted in
/// the notification request; display copy, account data, session identifiers,
/// goals, and coach content are deliberately not representable.
struct GrowthNotificationAttribution: Equatable {
    static let contractKey = "noum.notification.contract"
    static let growthKindKey = "noum.notification.growthKind"
    static let routeKey = "noum.notification.route"
    static let contractVersion = "growth.v1"

    let kind: GrowthNotificationKind
    let route: URL

    init?(kind: GrowthNotificationKind, route: URL) {
        guard kind != .unknown, route.scheme == "noum" else { return nil }
        self.kind = kind
        self.route = route
    }

    var userInfo: [AnyHashable: Any] {
        [
            Self.contractKey: Self.contractVersion,
            Self.growthKindKey: kind.rawValue,
            Self.routeKey: route.absoluteString,
        ]
    }

    static func decode(
        _ userInfo: [AnyHashable: Any]
    ) -> GrowthNotificationAttribution? {
        guard userInfo[contractKey] as? String == contractVersion,
              let rawKind = userInfo[growthKindKey] as? Int,
              let kind = GrowthNotificationKind(rawValue: rawKind),
              let rawRoute = userInfo[routeKey] as? String,
              let route = URL(string: rawRoute) else {
            return nil
        }
        return GrowthNotificationAttribution(kind: kind, route: route)
    }
}

/// Bounded attribution payload for first-week notifications. Values are only
/// enums, a version marker, and an app-owned route: no account ID, authored
/// text, transcript, coach prose, or session identifier leaves the app in the
/// notification request. `NoumAppDelegate` can decode this same contract to
/// route the tap and record `GrowthNotificationKind` without guessing from
/// display copy.
struct FirstWeekNotificationAttribution {
    static let contractKey = "noum.notification.contract"
    static let intentKey = "noum.notification.intent"
    static let routeKey = "noum.notification.route"
    static let growthKindKey = "noum.notification.growthKind"
    static let contractVersion = "firstWeek.v1"
    /// Content-free rendezvous route for Day 1–4. The app resolves the current
    /// contract and recommendation exposure when this route is opened; no
    /// coaching target or exercise setup is serialized into the notification.
    static let recommendationActionRoute = URL(
        string: "noum://home/first-week-action"
    )!
    /// Neutral Home rendezvous for Day 0. Only an explicit Home or
    /// notification tap prepares the process-local prompt handoff; the
    /// notification never carries a prompt token or opens a microphone route.
    static let spokenBaselineActionRoute = URL(
        string: "noum://home/first-week-spoken-proof"
    )!

    let intent: FirstWeekCoachingContract.NotificationIntent
    let route: URL
    let growthKind: GrowthNotificationKind

    init(snapshot: FirstWeekCoachingContract.Snapshot) {
        intent = snapshot.notificationIntent
        route = Self.route(for: intent)
        growthKind = Self.growthKind(for: intent)
    }

    var userInfo: [AnyHashable: Any] {
        [
            Self.contractKey: Self.contractVersion,
            Self.intentKey: intent.rawValue,
            Self.routeKey: route.absoluteString,
            Self.growthKindKey: growthKind.rawValue,
        ]
    }

    static func decode(
        _ userInfo: [AnyHashable: Any]
    ) -> FirstWeekNotificationAttribution? {
        guard userInfo[contractKey] as? String == contractVersion,
              let rawIntent = userInfo[intentKey] as? String,
              let intent = FirstWeekCoachingContract.NotificationIntent(rawValue: rawIntent),
              let rawRoute = userInfo[routeKey] as? String,
              let route = URL(string: rawRoute),
              let rawGrowthKind = userInfo[growthKindKey] as? Int,
              let growthKind = GrowthNotificationKind(rawValue: rawGrowthKind),
              route == Self.route(for: intent),
              growthKind == Self.growthKind(for: intent) else {
            return nil
        }
        return FirstWeekNotificationAttribution(
            intent: intent,
            route: route,
            growthKind: growthKind
        )
    }

    private init(
        intent: FirstWeekCoachingContract.NotificationIntent,
        route: URL,
        growthKind: GrowthNotificationKind
    ) {
        self.intent = intent
        self.route = route
        self.growthKind = growthKind
    }

    private static func route(
        for intent: FirstWeekCoachingContract.NotificationIntent
    ) -> URL {
        let value: String
        switch intent {
        case .recordSpokenBaseline:
            return spokenBaselineActionRoute
        case .repeatRep, .compareAndAdapt:
            return recommendationActionRoute
        case .realWorldCheckIn:
            value = "noum://profile/check-in"
        case .firstWeekRead:
            value = "noum://home/first-week-read"
        }
        // Every branch is an app-owned literal. Keeping the fallback makes the
        // initializer total if URL parsing behavior ever changes.
        return URL(string: value) ?? URL(string: "noum://home")!
    }

    private static func growthKind(
        for intent: FirstWeekCoachingContract.NotificationIntent
    ) -> GrowthNotificationKind {
        switch intent {
        case .recordSpokenBaseline, .repeatRep, .compareAndAdapt:
            return .practiceReminder
        case .realWorldCheckIn, .firstWeekRead:
            return .weeklyRead
        }
    }
}

enum NotificationCopy {

    // MARK: - First-week coaching contract

    /// Lock-screen-safe copy for the one unfinished step projected by
    /// `FirstWeekCoachingContract`. The intent is content-free by design, so
    /// authored goals, transcripts, check-in text, and generated prescription
    /// prose can never leak into a notification.
    static func firstWeek(
        intent: FirstWeekCoachingContract.NotificationIntent
    ) -> NotificationLine {
        switch intent {
        case .recordSpokenBaseline:
            return NotificationLine(
                title: "Your spoken baseline is ready",
                body: "Try the 30-second proof you chose. Noum will only report what the recording can support."
            )
        case .repeatRep:
            return NotificationLine(
                title: "Give your coach a second look",
                body: "Repeat one short rep so Noum can check whether the first pattern holds."
            )
        case .compareAndAdapt:
            return NotificationLine(
                title: "Your comparison rep is next",
                body: "Run the current prescription once more. Noum will compare the evidence before changing course."
            )
        case .realWorldCheckIn:
            return NotificationLine(
                title: "How did this show up outside Noum?",
                body: "A short check-in tells your coach what carried into a real conversation."
            )
        case .firstWeekRead:
            return NotificationLine(
                title: "Your first-week read is ready",
                body: "Review what repeated, what changed, and the one next step your evidence supports."
            )
        }
    }

    // MARK: - Daily reminder

    /// User picked a specific time. We have no information about whether
    /// they've already practiced today (the `todayDone` flag is filled by
    /// the caller from `SharedNoumState`).
    static func dailyReminder(streakDays: Int, todayDone: Bool) -> NotificationLine {
        if todayDone {
            // They've already practiced — soft "double-down" pull, not a guilt nudge.
            return NotificationLine(
                title: "Stack a second rep",
                body: "Today already counts. A second rep is where the muscle gets built."
            )
        }

        switch streakDays {
        case 0:
            return NotificationLine(
                title: "Today is rep one",
                body: "One short drill sets your baseline. Two minutes is enough."
            )
        case 1...2:
            return NotificationLine(
                title: "Day \(streakDays + 1) starts now",
                body: "Two days don't make a habit. Today's rep is the one that does."
            )
        case 3...6:
            return NotificationLine(
                title: "Keep your \(streakDays)-day streak going",
                body: "You're \(7 - streakDays) day\(7 - streakDays == 1 ? "" : "s") from a full week — one short rep adds today."
            )
        case 7...:
            return NotificationLine(
                title: "\(streakDays) days of steady practice",
                body: "A habit this established is worth one more rep today."
            )
        default:
            return NotificationLine(
                title: "Today's rep is waiting",
                body: "A short drill keeps the rhythm."
            )
        }
    }

    // MARK: - Evening practice nudge

    /// Fired late evening only when the user has an established rhythm and
    /// has not practiced today. Copy stays neutral: no countdown and no
    /// last-chance pressure.
    static func streakWarning(streakDays: Int, freezesAvailable: Int) -> NotificationLine {
        let freezeLine = freezesAvailable > 0
            ? "Your weekly freeze can cover one quiet day."
            : "Two minutes is enough when you want to keep the rhythm active."

        switch streakDays {
        case 0:
            // Should never reach here per the scheduling guard, but be safe.
            return NotificationLine(
                title: "Today's rep is waiting",
                body: "A short drill keeps the rhythm."
            )
        case 1...2:
            return NotificationLine(
                title: "Evening practice nudge",
                body: "You've started a speaking rhythm. One short rep adds today. \(freezeLine)"
            )
        case 3...6:
            return NotificationLine(
                title: "\(streakDays) days of steady practice",
                body: "One focused rep adds today to the rhythm. \(freezeLine)"
            )
        case 7...13:
            return NotificationLine(
                title: "\(streakDays) days of steady practice",
                body: "Your habit is established. A short rep keeps it active. \(freezeLine)"
            )
        case 14...29:
            return NotificationLine(
                title: "\(streakDays) days in — nice rhythm",
                body: "A focused rep today keeps the practice line connected. \(freezeLine)"
            )
        case 30...:
            return NotificationLine(
                title: "\(streakDays) days of steady practice",
                body: "One short rep continues the habit. \(freezeLine)"
            )
        default:
            return NotificationLine(
                title: "Evening practice nudge",
                body: "A short rep keeps your rhythm active. \(freezeLine)"
            )
        }
    }

    // MARK: - Big Moment day-after check-in (neutral invite, never guilt)
    //
    // Fired the morning after a dated Big Moment passes. Closes the
    // prepare → event → reflect loop: the user prepped for a real
    // moment; the day after, the coach asks how it went so the Home
    // outcome card can collect their read of the room.
    //
    // Contracts:
    //   • Privacy — takes only the category, by construction. The
    //     user-authored moment title must NEVER reach the lock screen
    //     (same rule as the T-7 / T-1 countdown copy).
    //   • Never guilt — a pure invite. No "don't forget", no urgency,
    //     no implication that skipping the check-in costs anything.
    //     "No rush" is the register: the check-in waits for them.
    static func bigMomentCheckIn(category: BigMomentCategory) -> NotificationLine {
        NotificationLine(
            title: "How did your \(category.displayName) go?",
            body: "When you're ready, a short check-in tells your coach how the room felt. No rush."
        )
    }

    // MARK: - Weekly digest

    /// Weekly practice read with optional context from the voice goal the user
    /// explicitly chose. `nil` stays fully generic: callers must never pass the
    /// profile's always-populated effective/default style as if it were a
    /// deliberate choice.
    static func weeklyDigest(
        weeklyReps: Int,
        chosenStyleGoal: SpeakingStyleGoal? = nil
    ) -> NotificationLine {
        let line: NotificationLine

        switch weeklyReps {
        case 0:
            line = NotificationLine(
                title: "Your week, summed up",
                body: "No reps recorded this week. The path is still here when you are."
            )
        case 1...2:
            line = NotificationLine(
                title: "Light week — \(weeklyReps) rep\(weeklyReps == 1 ? "" : "s")",
                body: "\(weeklyReps) rep\(weeklyReps == 1 ? "" : "s") banked this week. Open Noum to review the week when it suits you."
            )
        case 3...4:
            line = NotificationLine(
                title: "Steady week — \(weeklyReps) reps in",
                body: "Open Noum to review this week's reps, pace, and score when it suits you."
            )
        case 5...6:
            line = NotificationLine(
                title: "Strong week — \(weeklyReps) reps in",
                body: "Open Noum to review this week's evidence across reps, pace, and score."
            )
        case 7...:
            line = NotificationLine(
                title: "Top week — \(weeklyReps) reps cleared",
                body: "A full week of regular practice, banked. Open Noum to see how it added up."
            )
        default:
            line = NotificationLine(
                title: "Your week, summed up",
                body: "Open Noum to review your latest practice record when it suits you."
            )
        }

        guard let chosenStyleGoal else { return line }

        return NotificationLine(
            title: line.title,
            body: "\(line.body) \(weeklyGoalFocus(for: chosenStyleGoal))"
        )
    }

    /// Names the selected direction without claiming that a thin week proved
    /// improvement. Canonical goal labels are lock-screen safe; authored goal
    /// text never enters this path.
    private static func weeklyGoalFocus(for goal: SpeakingStyleGoal) -> String {
        switch goal {
        case .authoritative:
            return "Your authoritative goal stays focused on steadiness and decisive endings."
        case .warm:
            return "Your warm-voice goal stays focused on natural pace and connection."
        case .concise:
            return "Your concise goal stays focused on clean structure and fewer extra words."
        case .persuasive:
            return "Your persuasive goal stays focused on clear structure and support."
        case .executive:
            return "Your executive-presence goal stays focused on composure and concise decisions."
        case .storytelling:
            return "Your storytelling goal stays focused on a clear narrative turn and vocal emphasis."
        }
    }
}
