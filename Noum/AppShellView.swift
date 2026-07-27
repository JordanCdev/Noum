import SwiftUI
import UIKit

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case train
    case review
    case profile
    case settings

    static let timedPromptTokenQueryName = "prompt-handoff"
    static let timedDifficultyQueryName = "difficulty"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Home"
        case .train: return "Train"
        case .review: return "Review"
        case .profile: return "Profile"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: return "house"
        case .train: return "waveform"
        case .review: return "book.closed"
        case .profile: return "person"
        case .settings: return "slider.horizontal.3"
        }
    }

    var accessibilityIdentifier: String {
        switch self {
        case .home: return "app.tab.home"
        case .train: return "nav.practice"
        case .review: return "nav.history"
        case .profile: return "nav.social"
        case .settings: return "nav.settings"
        }
    }

    static func topLevelRoute(for url: URL) -> AppTab? {
        guard url.scheme == "noum" else { return nil }
        switch url.host?.lowercased() {
        case "home", "ask", "asknoum", "asktype", "askchat", "bigmoment", "summary":
            return .home
        case "practice", "train", "lesson", "lessons", "path", "projects", "roleplay", "prep":
            return .train
        case "review", "history", "growth", "library":
            return .review
        case "profile", "social", "league", "friend", "friends":
            return .profile
        case "settings": return .settings
        default: return nil
        }
    }

    static func pushedDestination(for url: URL) -> AppDestination? {
        guard url.scheme == "noum" else { return nil }
        let component = url.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        guard !component.isEmpty else { return nil }

        switch (url.host?.lowercased(), component) {
        case ("practice", "timed"), ("train", "timed"):
            if let token = timedPromptToken(from: url) {
                return .timedPracticePrompt(
                    token: token,
                    difficulty: timedDifficulty(from: url)
                )
            }
            return .timedPractice(difficulty: timedDifficulty(from: url))
        case ("practice", "impromptu"), ("train", "impromptu"):
            return .timedPractice(difficulty: nil)
        case ("practice", "pressure"), ("practice", "sudden-death"),
             ("train", "pressure"), ("train", "sudden-death"):
            return .suddenDeathPractice
        case ("practice", "ah-counter"), ("practice", "fillers"),
             ("train", "ah-counter"), ("train", "fillers"):
            return .ahCounterPractice
        case ("practice", "im"), ("practice", "conversation"),
             ("train", "im"), ("train", "conversation"):
            return .imPractice(scenario: nil, tone: nil)
        case ("practice", "cut-the-crutch"), ("practice", "crutch"),
             ("train", "cut-the-crutch"), ("train", "crutch"):
            return .cutTheCrutchPractice
        case ("practice", "pace"), ("train", "pace"):
            return .paceTrainingPractice
        case ("projects", let projectID):
            guard SpeechProjects.project(id: projectID) != nil else { return nil }
            return .speechProject(id: projectID)
        case ("lesson", let lessonID):
            guard LessonsCatalog.lesson(id: lessonID) != nil else { return nil }
            return .lesson(id: lessonID)
        case ("ask", "type"), ("ask", "chat"),
             ("asknoum", "type"), ("asknoum", "chat"):
            return .askNoumTyped
        case ("profile", "check-in"):
            return .weeklyCheckIn
        case ("home", "first-week-read"):
            return .firstWeekRead
        default:
            return nil
        }
    }

    static func rootDestination(for url: URL) -> AppDestination? {
        guard url.scheme == "noum" else { return nil }
        if let pushed = pushedDestination(for: url) { return pushed }

        let host = url.host?.lowercased()
        switch host {
        case "lessons": return .lessons
        case "path": return .pathJourney
        case "projects": return .speechProjects
        case "roleplay": return .roleplaySetup
        case "prep": return .prepSession
        case "growth", "library": return .growthLibrary
        case "league": return .league
        case "friend", "friends": return .friendLeaderboard
        case "ask", "asknoum":
            let queryMode = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name.lowercased() == "mode" })?.value?.lowercased()
            return (queryMode == "type" || queryMode == "chat") ? .askNoumTyped : .askNoum
        case "asktype", "askchat": return .askNoumTyped
        default: return nil
        }
    }

    static func isFirstWeekRecommendationActionRoute(_ url: URL) -> Bool {
        url == FirstWeekNotificationAttribution.recommendationActionRoute
    }

    static func isFirstWeekSpokenProofRoute(_ url: URL) -> Bool {
        url == FirstWeekNotificationAttribution.spokenBaselineActionRoute
    }

    private static func timedPromptToken(from url: URL) -> UUID? {
        guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == timedPromptTokenQueryName })?
            .value else {
            return nil
        }
        return UUID(uuidString: value)
    }

    private static func timedDifficulty(from url: URL) -> TimedPracticeDifficulty? {
        guard let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == timedDifficultyQueryName })?
            .value?
            .lowercased() else {
            return nil
        }
        return TimedPracticeDifficulty(rawValue: value)
    }
}

private struct AppTabRootKey: EnvironmentKey {
    static let defaultValue = false
}

private struct SelectedAppTabKey: EnvironmentKey {
    // Standalone/previews are visible by definition. AppShell overrides this
    // for retained tab roots so off-tab content cannot claim an exposure.
    static let defaultValue = true
}

extension EnvironmentValues {
    var isAppTabRoot: Bool {
        get { self[AppTabRootKey.self] }
        set { self[AppTabRootKey.self] = newValue }
    }

    var isSelectedAppTab: Bool {
        get { self[SelectedAppTabKey.self] }
        set { self[SelectedAppTabKey.self] = newValue }
    }
}

/// Persistent five-tab shell. Each section owns its own navigation history,
/// while the existing `AppDestination` values continue to resolve every
/// pushed screen. Home keeps ownership only of its app-level overlays and
/// coaching state; the shell owns all five navigation paths.
struct AppShellView: View {
    @StateObject private var deepLinkRouter = DeepLinkRouter.shared
    @State private var selectedTab: AppTab = .home
    /// Shared geometry space for the capsule's selection pill so it glides
    /// between tabs instead of blinking (V4.6.1 micro-interaction).
    @Namespace private var tabPillNamespace
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedPracticeMode: PracticeMode = .timed
    @State private var homeRoute: URL?
    @State private var homePath = NavigationPath()
    @State private var trainPath = NavigationPath()
    @State private var reviewPath = NavigationPath()
    @State private var profilePath = NavigationPath()
    @State private var settingsPath = NavigationPath()

    var body: some View {
        TabView(selection: $selectedTab) {
            ContentView(navigationPath: $homePath, externalRoute: $homeRoute)
                .environment(\.isSelectedAppTab, selectedTab == .home)
                .toolbar(.hidden, for: .tabBar)
                .tabItem { tabLabel(.home) }
                .tag(AppTab.home)

            destinationStack(path: $trainPath) {
                PracticeModeSelectionView(
                    selectedMode: $selectedPracticeMode,
                    navigationPath: $trainPath
                )
                .environment(\.isAppTabRoot, true)
                .environment(\.isSelectedAppTab, selectedTab == .train)
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { tabLabel(.train) }
            .tag(AppTab.train)

            destinationStack(path: $reviewPath) {
                SessionHistoryView(navigationPath: $reviewPath)
                    .environment(\.isAppTabRoot, true)
                    .environment(\.isSelectedAppTab, selectedTab == .review)
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { tabLabel(.review) }
            .tag(AppTab.review)

            destinationStack(path: $profilePath) {
                ProfileView()
                    .environment(\.isAppTabRoot, true)
                    .environment(\.isSelectedAppTab, selectedTab == .profile)
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { tabLabel(.profile) }
            .tag(AppTab.profile)

            destinationStack(path: $settingsPath) {
                SettingsView()
                    .environment(\.isAppTabRoot, true)
                    .environment(\.isSelectedAppTab, selectedTab == .settings)
            }
            .toolbar(.hidden, for: .tabBar)
            .tabItem { tabLabel(.settings) }
            .tag(AppTab.settings)
        }
        .tint(AppColor.brandBlue)
        .overlay(alignment: .bottom) {
            // The capsule lives on the four tab ROOTS only — pushed
            // destinations (summary, recording, settings detail, …) own
            // their full height, matching the frozen screens.
            if !v46TabBarHidden {
                v46TabBar
                    .transition(.opacity)
            }
        }
        .background {
            AppTabAccessibilityBridge(
                identifiers: AppTab.allCases.map(\.accessibilityIdentifier)
            )
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
        .onAppear {
            if let pending = deepLinkRouter.pending {
                consume(pending)
            }
        }
        .onChange(of: deepLinkRouter.pending) { _, pending in
            guard let pending else { return }
            consume(pending)
        }
    }

    private func tabLabel(_ tab: AppTab) -> some View {
        Label(tab.title, systemImage: tab.systemImage)
            .accessibilityIdentifier(tab.accessibilityIdentifier)
    }

    // MARK: - V4.6 floating capsule navigation (258:947)
    //
    // Four areas — Today · Practice · Progress · You. Settings folds under
    // You (its tab remains routable for deep links; the bar highlights You
    // while it is frontmost). Selection is never colour-alone: the pill,
    // the glyph tint, and the label weight move together.

    private var v46TabBarHidden: Bool {
        switch selectedTab {
        case .home: return !homePath.isEmpty
        case .train: return !trainPath.isEmpty
        case .review: return !reviewPath.isEmpty
        case .profile: return !profilePath.isEmpty
        case .settings: return !settingsPath.isEmpty
        }
    }

    private var v46TabBar: some View {
        HStack(spacing: 0) {
            v46TabButton(.home, title: "Today", glyph: "sun.max")
            v46TabButton(.train, title: "Practice", glyph: "waveform")
            v46TabButton(.review, title: "Progress", glyph: "chart.line.uptrend.xyaxis")
            v46TabButton(.profile, title: "You", glyph: "person.crop.circle")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, Spacing.xs)
        .background {
            // Opaque, not translucent: the capsule floats over live list
            // content, and at accessibility sizes a section header can sit
            // directly beneath it. Any alpha here bleeds that copy through
            // as ~1.05:1 ghost text (Settings' "Appearance" header read as
            // "Appe|arance"), which the native contrast audit fails.
            //
            // No hairline stroke: at 0.05 black / 0.10 white it computed
            // ~1.05:1 against its own fill, so it delineated nothing and
            // the audit read the curve as failing content inside the tab
            // items. The shadow carries the floating edge. A visible
            // boundary here would need to clear 3:1 (WCAG 1.4.11).
            Capsule(style: .continuous)
                .fill(AppColor.cardBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 24, y: 8)
        }
        .padding(.bottom, Spacing.xs)
        // Pill glide is scoped to the BAR's subtree only — the TabView
        // content switch stays instant. Reduce Motion: pill just appears.
        .animation(reduceMotion ? nil : .listChange, value: selectedTab)
        // Navigation chrome caps its own scaling (native tab bars do the
        // same); screen content carries the accessibility sizes.
        .dynamicTypeSize(...DynamicTypeSize.large)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("app.v46TabBar")
    }

    private func v46TabButton(_ tab: AppTab, title: String, glyph: String) -> some View {
        let isSelected = selectedTab == tab
            || (tab == .profile && selectedTab == .settings)
        return Button {
            guard selectedTab != tab else { return }
            // Discrete selection haptic on genuine tab changes only —
            // re-tapping the current tab stays silent (register map:
            // input acknowledgment, never a haptic on every tap).
            CoachHaptic.selectionTap()
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: glyph)
                    .font(.system(size: 17, weight: .semibold))
                    // Full-strength token in both states. Receding the
                    // unselected glyph to 0.75 computed 3.41:1 on the
                    // capsule — under AA for a navigation glyph, and the
                    // native audit flags it. Selection stays legible
                    // without it: pill + accent tint + label weight.
                    .foregroundStyle(
                        isSelected ? AppColor.coachAccentOnQuiet : AppColor.neutralReceded
                    )
                    .accessibilityHidden(true)
                Text(title)
                    .font(Typography.figtree(size: 10.5, weight: isSelected ? .heavy : .semibold, relativeTo: .caption2))
                    .foregroundStyle(isSelected ? AppColor.coachingInkOnQuiet : AppColor.neutralReceded)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(AppColor.proQuietSurface)
                        // The pill glides to the newly selected tab; under
                        // Reduce Motion the withMotion branch above mutates
                        // without a transaction, so the pill just appears.
                        .matchedGeometryEffect(id: "v46TabPill", in: tabPillNamespace)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // The bar clamps Dynamic Type to `.large` to protect the capsule
        // geometry, and the comment there claims native tab bars do the same.
        // They do — but they pair the clamp with the large-content viewer, the
        // long-press HUD that shows the label at full size. Without it a
        // Larger-Text user at AX1–AX5 simply gets 10.5pt labels everywhere with
        // no way to enlarge them, and the native audits do not flag it because
        // 10.5pt is neither clipped nor low-contrast. This restores the other
        // half of the parity the clamp assumes.
        .accessibilityShowsLargeContentViewer {
            Label(title, systemImage: glyph)
        }
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier(tab.accessibilityIdentifier)
    }

    private func destinationStack<Root: View>(
        path: Binding<NavigationPath>,
        @ViewBuilder root: () -> Root
    ) -> some View {
        NavigationStack(path: path) {
            root()
                .navigationDestination(for: AppDestination.self) { destination in
                    AppDestinationView(destination: destination, navigationPath: path)
                }
        }
    }

    private func consume(_ url: URL) {
        guard url.scheme == "noum" else {
            deepLinkRouter.pending = nil
            return
        }

        if let tab = AppTab.topLevelRoute(for: url) {
            selectedTab = tab
            switch tab {
            case .home:
                homePath = NavigationPath()
                if let destination = AppTab.rootDestination(for: url) {
                    homePath.append(destination)
                } else if url.host?.lowercased() == "bigmoment"
                    || url.host?.lowercased() == "summary"
                    || AppTab.isFirstWeekRecommendationActionRoute(url)
                    || AppTab.isFirstWeekSpokenProofRoute(url) {
                    // These routes create Home-owned presentation state before
                    // navigation, so ContentView remains their owner. The
                    // first-week route is intentionally content-free and must
                    // resolve the current prescription only after the tap.
                    homeRoute = url
                }
            case .train:
                trainPath = NavigationPath()
                if let destination = AppTab.rootDestination(for: url) {
                    trainPath.append(destination)
                }
            case .review:
                reviewPath = NavigationPath()
                if let destination = AppTab.rootDestination(for: url) {
                    reviewPath.append(destination)
                }
            case .profile:
                profilePath = NavigationPath()
                if let destination = AppTab.rootDestination(for: url) {
                    profilePath.append(destination)
                }
            case .settings: settingsPath = NavigationPath()
            }
            deepLinkRouter.pending = nil
            return
        }

        // Non-tab routes keep using ContentView's established URL parser so
        // lesson IDs, Ask Noum modes, seeded summaries, and friend routes do
        // not acquire a second routing implementation.
        selectedTab = .home
        homeRoute = url
        deepLinkRouter.pending = nil
    }
}

/// SwiftUI preserves each tab's human-readable label but does not forward an
/// identifier placed inside `tabItem` to the native `UITabBarItem`. Keep the
/// native tab bar and assign identifiers at its UIKit accessibility boundary.
private struct AppTabAccessibilityBridge: UIViewRepresentable {
    let identifiers: [String]

    func makeUIView(context: Context) -> AppTabAccessibilityBridgeView {
        AppTabAccessibilityBridgeView(identifiers: identifiers)
    }

    func updateUIView(_ uiView: AppTabAccessibilityBridgeView, context: Context) {
        uiView.identifiers = identifiers
        uiView.beginIdentifierAssignment()
    }
}

private final class AppTabAccessibilityBridgeView: UIView {
    var identifiers: [String]

    private var scheduledRetry: DispatchWorkItem?
    private var retryCount = 0

    /// A cold SwiftUI `TabView` can attach this representable before UIKit has
    /// finished creating every `UITabBarItem`/tab control. Layout is not
    /// guaranteed to run again for this zero-sized bridge, so cover the short
    /// materialisation window explicitly instead of waiting for unrelated
    /// navigation to trigger another update.
    private static let maximumRetryCount = 90
    private static let retryInterval: TimeInterval = 1.0 / 60.0

    init(identifiers: [String]) {
        self.identifiers = identifiers
        super.init(frame: .zero)
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cancelScheduledRetry()
        } else {
            beginIdentifierAssignment()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        beginIdentifierAssignment()
    }

    deinit {
        scheduledRetry?.cancel()
    }

    func beginIdentifierAssignment() {
        guard window != nil else { return }
        retryCount = 0
        cancelScheduledRetry()

        if !applyIdentifiers() {
            scheduleRetry()
        }
    }

    @discardableResult
    private func applyIdentifiers() -> Bool {
        guard let tabBar = findTabBar(),
              let items = tabBar.items,
              items.count == identifiers.count else {
            return false
        }

        for (item, identifier) in zip(items, identifiers) {
            if item.accessibilityIdentifier != identifier {
                item.accessibilityIdentifier = identifier
            }
        }

        // Setting the item before its native control exists is sufficient on
        // most OS versions. If UIKit already created the controls, stamp those
        // too: some releases snapshot accessibility metadata when building the
        // tab button and do not immediately mirror later item changes.
        let controls = Self.descendantControls(in: tabBar)
        var matchedControlCount = 0
        for (item, identifier) in zip(items, identifiers) {
            guard let expectedLabel = item.accessibilityLabel ?? item.title,
                  let control = controls.first(where: {
                      $0.accessibilityLabel == expectedLabel
                  }) else {
                continue
            }
            control.accessibilityIdentifier = identifier
            matchedControlCount += 1
        }

        let allItemsAssigned = zip(items, identifiers).allSatisfy {
            $0.0.accessibilityIdentifier == $0.1
        }
        return allItemsAssigned && matchedControlCount == identifiers.count
    }

    private func scheduleRetry() {
        guard window != nil,
              retryCount < Self.maximumRetryCount,
              scheduledRetry == nil else {
            return
        }

        retryCount += 1
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.scheduledRetry = nil
            if !self.applyIdentifiers() {
                self.scheduleRetry()
            }
        }
        scheduledRetry = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.retryInterval,
            execute: workItem
        )
    }

    private func cancelScheduledRetry() {
        scheduledRetry?.cancel()
        scheduledRetry = nil
    }

    private func findTabBar() -> UITabBar? {
        guard let window else { return nil }
        if let rootViewController = window.rootViewController,
           let tabBarController = Self.findTabBarController(in: rootViewController) {
            return tabBarController.tabBar
        }
        return Self.findTabBar(in: window)
    }

    private static func findTabBarController(in viewController: UIViewController) -> UITabBarController? {
        if let tabBarController = viewController as? UITabBarController {
            return tabBarController
        }

        for child in viewController.children {
            if let tabBarController = findTabBarController(in: child) {
                return tabBarController
            }
        }

        if let presented = viewController.presentedViewController {
            return findTabBarController(in: presented)
        }

        return nil
    }

    private static func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar {
            return tabBar
        }
        for subview in view.subviews {
            if let tabBar = findTabBar(in: subview) {
                return tabBar
            }
        }
        return nil
    }

    private static func descendantControls(in view: UIView) -> [UIControl] {
        view.subviews.flatMap { subview -> [UIControl] in
            let current = (subview as? UIControl).map { [$0] } ?? []
            return current + descendantControls(in: subview)
        }
    }
}

/// One resolver shared by every tab's NavigationStack. This keeps existing
/// destination/state ownership intact while allowing each tab to maintain a
/// separate history.
struct AppDestinationView: View {
    let destination: AppDestination
    @Binding var navigationPath: NavigationPath

    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var coachCheckInStore = CoachCheckInStore.shared
    @State private var selectedPracticeMode: PracticeMode = .timed

    @ViewBuilder
    var body: some View {
        switch destination {
        case .practiceSelection:
            PracticeModeSelectionView(selectedMode: $selectedPracticeMode, navigationPath: $navigationPath)
        case .timedPractice(let difficulty):
            TimedPracticeView(
                navigationPath: $navigationPath,
                prescribedTimedDifficulty: difficulty
            )
                .toolbar(.hidden, for: .tabBar)
        case .timedPracticePrompt(let token, let difficulty):
            TimedPracticeView(
                navigationPath: $navigationPath,
                prescribedTimedDifficulty: difficulty,
                promptHandoffToken: token
            )
            .toolbar(.hidden, for: .tabBar)
        case .suddenDeathPractice:
            SuddenDeathPracticeView(navigationPath: $navigationPath)
                .toolbar(.hidden, for: .tabBar)
        case .ahCounterPractice:
            AhCounterView(navigationPath: $navigationPath)
                .toolbar(.hidden, for: .tabBar)
        case .imPractice(let scenario, let tone):
            if IMModeAvailability.isAvailable {
                IMPracticeView(
                    navigationPath: $navigationPath,
                    preferredScenario: scenario,
                    preferredTone: tone
                )
                .toolbar(.hidden, for: .tabBar)
            } else {
                TimedPracticeView(navigationPath: $navigationPath)
                    .toolbar(.hidden, for: .tabBar)
            }
        case .cutTheCrutchPractice:
            CutTheCrutchView(navigationPath: $navigationPath)
                .toolbar(.hidden, for: .tabBar)
        case .paceTrainingPractice:
            PaceTrainingView(navigationPath: $navigationPath)
                .toolbar(.hidden, for: .tabBar)
        case .speechProject(let id):
            if let project = SpeechProjects.project(id: id) {
                TimedPracticeView(
                    navigationPath: $navigationPath,
                    speechProject: project
                )
                .toolbar(.hidden, for: .tabBar)
            } else {
                SpeechProjectsView(navigationPath: $navigationPath)
            }
        case .friendLeaderboard:
            FriendLeaderboardView()
                .toolbar(.hidden, for: .tabBar)
        case .league:
            LeagueView()
                .toolbar(.hidden, for: .tabBar)
        case .speechProjects:
            SpeechProjectsView(navigationPath: $navigationPath)
                .toolbar(.hidden, for: .tabBar)
        case .lessons:
            LessonsHomeView(navigationPath: $navigationPath)
                .toolbar(.hidden, for: .tabBar)
        case .lesson(let id):
            if let lesson = LessonsCatalog.lesson(id: id) {
                LessonView(lesson: lesson, navigationPath: $navigationPath)
                    .toolbar(.hidden, for: .tabBar)
            } else {
                LessonsHomeView(navigationPath: $navigationPath)
            }
        case .summary(let payload):
            SummaryView(payload: payload, navigationPath: $navigationPath)
                .toolbar(.hidden, for: .tabBar)
        case .sessionHistory:
            SessionHistoryView(navigationPath: $navigationPath)
        case .socialProfile, .speakingRank:
            ProfileView()
                .toolbar(.hidden, for: .tabBar)
        case .settings:
            SettingsView()
        case .pathJourney:
            PathJourneyView()
                .toolbar(.hidden, for: .tabBar)
        case .askNoum:
            CoachSessionView(
                sessionStore: sessionStore,
                ratingStore: ratingStore,
                coachingProfileStore: coachingProfileStore,
                navigationPath: $navigationPath,
                initialMode: .live
            )
            .toolbar(.hidden, for: .tabBar)
        case .askNoumTyped:
            CoachSessionView(
                sessionStore: sessionStore,
                ratingStore: ratingStore,
                coachingProfileStore: coachingProfileStore,
                navigationPath: $navigationPath,
                initialMode: .type
            )
            .toolbar(.hidden, for: .tabBar)
        case .weeklyCheckIn:
            WeeklyCheckInSheet(store: coachCheckInStore)
                .toolbar(.hidden, for: .tabBar)
        case .firstWeekRead:
            FirstWeekReadDetailView()
                .toolbar(.hidden, for: .tabBar)
        case .coachingMemory:
            CoachingMemoryView()
        case .growthLibrary:
            GrowthLibraryView()
                .toolbar(.hidden, for: .tabBar)
        case .sessionDetail(let sessionID):
            if let session = sessionStore.sessions.first(where: { $0.id == sessionID }) {
                SessionHistoryDetailView(
                    session: session,
                    insights: CoachingPlanner.sessionInsights(
                        for: session,
                        comparedTo: sessionStore.sessions,
                        profile: coachingProfileStore.profile
                    ),
                    navigationPath: $navigationPath
                )
                .toolbar(.hidden, for: .tabBar)
            } else {
                SessionHistoryView(navigationPath: $navigationPath)
            }
        case .bigMomentIntake:
            BigMomentIntakeView()
                .toolbar(.hidden, for: .tabBar)
        case .prepSession:
            PrepSessionView(navigationPath: $navigationPath)
                .toolbar(.hidden, for: .tabBar)
        case .preparationPractice(let route):
            PreparationPracticeContextView(
                route: route,
                navigationPath: $navigationPath
            )
            .toolbar(.hidden, for: .tabBar)
        case .suddenDeathDifficultyDetail(let difficulty):
            SuddenDeathDifficultyRunsView(difficulty: difficulty)
                .toolbar(.hidden, for: .tabBar)
        case .imScenarioDetail(let scenario):
            IMScenarioDetailView(scenario: scenario, navigationPath: $navigationPath)
                .toolbar(.hidden, for: .tabBar)
        case .roleplaySetup:
            RoleplaySetupView(navigationPath: $navigationPath)
                .toolbar(.hidden, for: .tabBar)
        case .roleplayRun(let scenario, let startingLevel):
            RoleplayView(
                scenario: scenario,
                startingLevel: startingLevel,
                navigationPath: $navigationPath
            )
            .toolbar(.hidden, for: .tabBar)
        }
    }
}

/// Hosts the existing practice views without duplicating their lifecycle or
/// result logic. The active origin is captured by `SummaryDataStore.store`
/// immediately before those views push Summary, then cleared as this route
/// leaves the hierarchy (including when the user switches tabs or backs out).
private struct PreparationPracticeContextView: View {
    let route: PreparationPracticeRoute
    @Binding var navigationPath: NavigationPath

    private var origin: SummaryJourneyOrigin {
        .bigMomentPreparation(route)
    }

    var body: some View {
        practiceView
            .onAppear {
                SummaryDataStore.shared.activateJourneyOrigin(origin)
            }
            .onDisappear {
                SummaryDataStore.shared.deactivateJourneyOrigin(origin)
            }
    }

    @ViewBuilder
    private var practiceView: some View {
        switch route.exercise {
        case .timed(let difficulty):
            TimedPracticeView(
                navigationPath: $navigationPath,
                prescribedTimedDifficulty: difficulty
            )
        case .timedPrompt(let token, let difficulty):
            TimedPracticeView(
                navigationPath: $navigationPath,
                prescribedTimedDifficulty: difficulty,
                promptHandoffToken: token
            )
        case .suddenDeath:
            SuddenDeathPracticeView(navigationPath: $navigationPath)
        case .conversation(let scenario, let tone):
            if IMModeAvailability.isAvailable {
                IMPracticeView(
                    navigationPath: $navigationPath,
                    preferredScenario: scenario,
                    preferredTone: tone
                )
            } else {
                // Capability can disappear after the plan rendered. Preserve
                // the preparation return contract while failing closed to the
                // same Timed surface as ordinary app routing.
                TimedPracticeView(navigationPath: $navigationPath)
            }
        }
    }
}
