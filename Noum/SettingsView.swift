#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(StoreKit)
import StoreKit
#endif
#if canImport(AVFAudio)
import AVFAudio
#endif

// MARK: - Settings Screen

/// Pure account-card policy. A `local-guest-*` identity owns data only on this
/// device, so presenting it as a signed-in cloud account or offering Sign out
/// would imply recovery guarantees the current lifecycle does not provide.
struct SettingsAccountPresentation: Equatable {
    let identityTitle: String
    let identityValue: String
    let providerTitle: String?
    let isOnDeviceGuest: Bool
    let showsSignOut: Bool
    let showsConnectCoaching: Bool
    let deletionAccessibilityHint: String

    static func resolve(
        accountID: String?,
        displayName: String,
        providerTitle: String?,
        providerRawValue: String?,
        hasPendingPromotion: Bool = false
    ) -> SettingsAccountPresentation {
        let isOnDeviceGuest = accountID.map {
            !AuthManager.shouldSyncBackend(accountID: $0)
        } ?? false
        if isOnDeviceGuest {
            return SettingsAccountPresentation(
                identityTitle: "Account",
                identityValue: "On-device guest",
                providerTitle: nil,
                isOnDeviceGuest: true,
                showsSignOut: false,
                showsConnectCoaching: true,
                deletionAccessibilityHint: "Deletes this on-device guest and its local practice data after confirmation."
            )
        }
        let isAnonymousGuest = providerRawValue == AuthProvider.guest.rawValue
        return SettingsAccountPresentation(
            identityTitle: "Signed in as",
            identityValue: displayName,
            providerTitle: providerTitle,
            isOnDeviceGuest: false,
            // An anonymous Firebase guest has no credential that can sign back
            // into the same UID. Clearing it would strand both local history
            // and backend-deletion authority; link or delete remains available.
            showsSignOut: !isAnonymousGuest && !hasPendingPromotion,
            showsConnectCoaching: false,
            deletionAccessibilityHint: "Requests permanent deletion after a typed confirmation. Local data stays until the remote account service succeeds."
        )
    }
}

@available(iOS 17.0, macOS 12.0, *)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isAppTabRoot) private var isAppTabRoot
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var authManager = AuthManager.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var practiceSettings = PracticeSettingsManager.shared
    @StateObject private var hapticsSettings = HapticsSettings.shared
    @StateObject private var interactionSounds = InteractionSoundSettings.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var imVoicePlaybackSettings = IMVoicePlaybackSettingsManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var premium = PremiumManager.shared
    @StateObject private var dailyGoal = DailyGoalManager.shared
    @StateObject private var localeSettings = LocaleSettingsManager.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    /// Observed so the AI-usage card's "coach notes today" row
    /// refreshes mid-view as the budget is consumed elsewhere — a
    /// rep finishing in the practice tab while Settings is open, or
    /// a deletion from the data-export sheet immediately above. The
    /// limiter publishes a `changeToken` on every successful
    /// `consumeIfAllowed` and on active-account `deleteAllData`.
    @StateObject private var rateLimiter = AIRateLimiter.shared
    @StateObject private var aiCallDiagnostics = AICallDiagnosticsStore.shared
    @StateObject private var flowEvents = FlowEventLog.shared

    // M15 Phase 4 — escape hatch for the signal-gated home. Mirrors the
    // AppStorage key read by ContentView; flipping this on shows every
    // home card from rep 1. Lives under Advanced — power-user surface only.
    @AppStorage("practice.showAllHomeCards") private var showAllHomeCards: Bool = false

    // Persisted so an advanced user who opens the section doesn't have to
    // re-open it every launch. Default collapsed so first-open is calm.
    @AppStorage("settings.advancedExpanded") private var advancedExpanded: Bool = false

    @State private var isBackendConfigured = false
    @StateObject private var bigMomentStore = BigMomentStore.shared
    @State private var showCoachingProfile = false
    @State private var showBigMomentIntake = false
    @State private var showPaywall = false
    @State private var showLocalePicker = false
    @State private var showYourData = false
    @State private var showPrivacyPolicy = false
    @State private var showCloudProcessingConsent = false
    @State private var showSoundscape = false
    @State private var showLogin = false
    @State private var showSignOutAlert = false
    @State private var showDeleteSheet = false
    @State private var debugMessage: String?
    @State private var supportToast: String?
    @State private var microphonePermission: MicrophonePermissionState = .unknown
    @State private var isRunningAIProviderHealthCheck = false
    @State private var aiProviderHealthSummary: String?
    @State private var aiProviderHealthGuidance: AIProviderHealthGuidance?
    #if DEBUG
    @State private var seedProfileStatus: String?
    #endif

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            List {
                if !isAppTabRoot {
                    Section {
                        profileHero
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    practiceDifficultyRow
                    dailyGoalCard
                    practiceVoiceCuesRow
                    fillerHighlightRow
                    pressureModeRow
                    practiceLanguageRow
                    soundscapeRow
                } header: {
                    SettingsSectionLabel(title: "Practice")
                }

                Section {
                    coachingProfileRow
                    upcomingMomentRow
                } header: {
                    SettingsSectionLabel(title: "Coaching")
                }

                Section {
                    dailyReminderRow
                    if notificationManager.dailyReminderEnabled {
                        dailyReminderTimePicker
                    }
                    eveningPracticeNudgeRow
                    weeklyDigestRow
                    notificationAccessRow
                    hapticsRow
                    interactionSoundsRow
                } header: {
                    SettingsSectionLabel(title: "Notifications")
                }

                Section {
                    subscriptionCard
                    privacyCard
                    accountCard
                } header: {
                    SettingsSectionLabel(title: "Account")
                }

                Section {
                    aboutCard
                } header: {
                    SettingsSectionLabel(title: "About")
                }

                Section {
                    advancedDisclosure
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(.compact)
            .scrollContentBackground(.hidden)
            .padding(.bottom, isAppTabRoot ? Spacing.tabRootNavigationClearance : 0)
        }
        .navigationTitle(isAppTabRoot ? "Settings" : "")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.screen")
        .toolbar {
            if !isAppTabRoot {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .accessibilityHint("Close settings")
                }
            }
        }
        .onChange(of: authManager.isSignedIn) { _, signedIn in
            if !signedIn && !isAppTabRoot { dismiss() }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshMicrophonePermission()
                Task { await notificationManager.refreshAuthorizationStatus() }
            }
        }
        .task {
            isBackendConfigured = await BackendSyncManager.shared.isConfigured
            refreshMicrophonePermission()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("UI_TESTING_PAYWALL") {
                showPaywall = true
            }
            #endif
        }
        .sheet(isPresented: $showCoachingProfile) {
            CoachingOnboardingView()
        }
        .sheet(isPresented: $showBigMomentIntake) {
            BigMomentIntakeView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showYourData) {
            NavigationStack {
                YourDataView(isBackendConfigured: isBackendConfigured)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showYourData = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView()
        }
        .sheet(isPresented: $showCloudProcessingConsent) {
            CloudProcessingConsentDisclosure(
                isCurrentlyAllowed: aiSettings.isCloudProcessingAllowed,
                onAllow: {
                    aiSettings.recordCloudProcessingDecision(.allowed)
                    showCloudProcessingConsent = false
                },
                onNotNow: {
                    aiSettings.recordCloudProcessingDecision(.declined)
                    showCloudProcessingConsent = false
                }
            )
        }
        .sheet(isPresented: $showSoundscape) {
            SoundscapePickerView()
        }
        .sheet(isPresented: $showLocalePicker) {
            PracticeLocalePickerSheet()
        }
        .fullScreenCover(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showDeleteSheet) {
            DeleteAccountConfirmationSheet(
                isOnDeviceGuest: accountPresentation.isOnDeviceGuest,
                initialError: AccountDeletionConfirmationPresentation.initialError(
                    from: authManager.accountDeletionState
                ),
                supportURLProvider: {
                    authManager.accountDeletionSupportURL
                },
                onConfirm: {
                    try await authManager.deleteCurrentAccount()
                    showDeleteSheet = false
                },
                onClose: {
                    showDeleteSheet = false
                },
                onReauthenticate: {
                    showDeleteSheet = false
                    showLogin = true
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("Sign out of Noum?", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Sign out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Your local drafts will be cleared. Your reps stay safe on your account.")
        }
        .alert("Heads up", isPresented: .constant(debugMessage != nil), actions: {
            Button("OK", role: .cancel) { debugMessage = nil }
        }, message: {
            Text(debugMessage ?? "")
        })
        .overlay(alignment: .bottom) {
            if let supportToast {
                Text(supportToast)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.black.opacity(0.85), in: Capsule())
                    .padding(.bottom, Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityLabel(supportToast)
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(2.0))
                            await MainActor.run {
                                withAnimation(reduceMotion ? nil : .standardSpring) {
                                    self.supportToast = nil
                                }
                            }
                        }
                    }
            }
        }
    }

    // MARK: - Advanced Disclosure

    /// Power-user knobs + (when `isDeveloper`) the dev tooling collapse
    /// behind one tap. Default collapsed so first-open is calm; expansion
    /// state persists via `advancedExpanded` so a power user who opened
    /// it doesn't have to re-open it every launch. Disclosure animation
    /// is gated on `reduceMotion` to match the rest of the app.
    @ViewBuilder
    private var advancedDisclosure: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Button {
                withAnimation(reduceMotion ? nil : .standardSpring) {
                    advancedExpanded.toggle()
                }
                CoachHaptic.selectionTap()
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text("Advanced")
                        .font(Typography.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: advancedExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                .padding(.horizontal, 4)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Advanced settings")
            .accessibilityHint(advancedExpanded ? "Tap to hide advanced settings" : "Tap to show advanced settings")
            .accessibilityValue(advancedExpanded ? "Expanded" : "Collapsed")
            .accessibilityIdentifier("settings.advancedToggle")

            if advancedExpanded {
                if aiUsageCardIsVisible {
                    section(label: "AI usage") { aiUsageCard }
                }

                if authManager.isDeveloper {
                    section(label: "Home reveal") { advancedHomeCard }
                    section(label: "Developer tools") { transcriptionProviderCard }
                    section(label: "AI calls") { aiCallDiagnosticsCard }
                    section(label: "Debug traces") { flowEventsCard }
                    section(label: "Diagnostics") { recommendationDiagnosticsCard }
                    section(label: "Seed data") { developerSeedCard }
                } else if exposesFlowLogForUITesting {
                    section(label: "Flow log") { flowEventsCard }
                }
            }
        }
    }

    private var exposesFlowLogForUITesting: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("UI_TESTING_RECOMMENDATION_FLOW_LOG")
            || ProcessInfo.processInfo.arguments.contains("UI_TESTING_COACH_TRACE_SUPPORT")
        #else
        false
        #endif
    }

    private var advancedHomeCard: some View {
        cardContainer(spacing: Spacing.sm) {
            SettingsToggleRow(
                title: "Show advanced home cards",
                subtitle: "Developer inspection override. Normal accounts follow the signal-gated Home reveal.",
                isOn: $showAllHomeCards,
                accessibilityHint: "Shows active optional home cards immediately for developer accounts while keeping retired dashboard cards hidden."
            )
        }
    }

    // MARK: - Section Wrapper

    @ViewBuilder
    private func section<Content: View>(label: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            SettingsSectionLabel(title: label)
            content()
        }
    }

    /// Cluster header used to group related Settings sections into named
    /// zones (Practice / Notifications / Account). Uses the same
    /// Dynamic-Type-aware headline role as the Advanced disclosure header;
    /// per-section labels below stay on the micro-uppercase + tracking-0.8
    /// treatment via `SettingsSectionLabel`.
    private func clusterHeader(_ title: LocalizedStringKey) -> some View {
        HStack {
            Text(title)
                .font(Typography.headline)
                .foregroundStyle(.primary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
        }
        .padding(.top, 8)
        .padding(.horizontal, 4)
    }

    // MARK: - Profile Hero

    private var displayName: String {
        AuthManager.userFacingDisplayName(from: authManager.currentAccountName)
    }

    private var accountPresentation: SettingsAccountPresentation {
        SettingsAccountPresentation.resolve(
            accountID: authManager.currentAccountID,
            displayName: displayName,
            providerTitle: authManager.currentAuthProviderTitle,
            providerRawValue: authManager.currentAuthProviderRawValue,
            hasPendingPromotion: authManager.hasPendingLocalGuestPromotion
        )
    }

    private var accountMutationIsBlocked: Bool {
        authManager.hasPendingLocalGuestPromotion
            || authManager.localGuestCloudConnectionState.blocksAccountMutation
    }

    /// Premium-tier presence tint for the hero avatar + ambient register.
    /// Pro users get the brand purple; everyone else gets brand blue.
    private var profileHeroTint: Color {
        premium.isPremium ? AppColor.pro : AppColor.brandBlue
    }

    private var profileHero: some View {
        Button {
            showCoachingProfile = true
        } label: {
            HStack(spacing: Spacing.md) {
                profileHeroMark

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(displayName)
                            .font(Typography.cardTitle)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)

                        if premium.isPremium {
                            Text("PRO")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(AppColor.pro, in: Capsule())
                                .accessibilityLabel("Pro subscriber")
                        }
                    }

                    // Identity first. If the user chose a voice target,
                    // Settings echoes that choice instead of making the hero
                    // feel like an XP receipt. The level still lives in
                    // accessibility and progression surfaces.
                    HStack(spacing: 6) {
                        Image(systemName: profileHeroSubtitleIcon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(profileHeroSubtitleTint)
                        Text(profileHeroSubtitle)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(profileHeroSubtitleTint)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 5)
                    .background(profileHeroSubtitleTint.opacity(0.12), in: Capsule())
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(profileHeroBackground)
            // Soft Pro-purple elevation — mirrors the HomeCoachCard hero
            // pattern but at a lower intensity since the Settings hero is
            // a compact row, not a full card. ~14pt radius + 6pt y-offset,
            // tinted in the same purple as the radial wash so the hero
            // reads as ambiently premium without a hard shadow rectangle.
            .shadow(color: AppColor.pro.opacity(0.10), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(profileHeroAccessibilityLabel)
        .accessibilityHint("Open coaching profile to edit")
        .accessibilityIdentifier("settings.profileHero")
    }

    private var profileHeroSubtitle: String {
        profileHeroPresentation.subtitle
    }

    private var profileHeroSubtitleIcon: String {
        profileHeroPresentation.subtitleIcon
    }

    private var profileHeroSubtitleTint: Color {
        coachingProfileStore.profile?.chosenStyleGoal?.voiceIconTint ?? AppColor.brandBlue
    }

    private var profileHeroPresentation: SettingsProfileHeroPresentation {
        SettingsProfileHeroPresentation.make(
            displayName: displayName,
            chosenVoice: coachingProfileStore.profile?.chosenStyleGoal,
            xp: profileManager.xp
        )
    }

    @ViewBuilder
    private var profileHeroMark: some View {
        if let chosenVoice = coachingProfileStore.profile?.chosenStyleGoal {
            VoiceGoalIcon(
                goal: chosenVoice,
                size: 22,
                containerSize: 56,
                cornerRadius: 18
            )
            .accessibilityHidden(true)
        } else {
            // Neutral pre-goal presence. Once the user chooses a voice target,
            // Settings should echo that identity rather than another generic
            // waveform mark.
            NoumCharacter(
                mood: .calm,
                tint: profileHeroTint,
                size: 56
            )
            .accessibilityHidden(true)
        }
    }

    private var profileHeroAccessibilityLabel: String {
        profileHeroPresentation.accessibilityLabel
    }

    /// Hero card chrome — applies the M14 Pro-purple ambient register so
    /// the Settings hero reads as a premium account surface instead of a
    /// list-view top row. Mirrors `HomeCoachCard.coachCardBackground` and
    /// `LeagueView.tierCardBackground`, with lower-intensity values
    /// because this card is compact (a single row) rather than a full
    /// hero. Two registers, same as the Coach Card: purple ambience for
    /// "this is your account" + the rank pill keeps the per-user accent.
    ///
    /// Layers, bottom to top:
    ///   1. White card surface (the canvas).
    ///   2. Top-anchored Pro-purple radial wash (0.16 → 0). Smaller
    ///      end-radius than the Coach Card since this card is shorter.
    ///   3. Faint Pro hairline border (1pt) at low opacity so the wash
    ///      reads as belonging to the card edge.
    private var profileHeroBackground: some View {
        let shape = RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        return ZStack {
            shape.fill(AppColor.cardBackground)

            shape.fill(
                RadialGradient(
                    colors: [AppColor.pro.opacity(0.44), AppColor.proLight.opacity(0.18), AppColor.pro.opacity(0.0)],
                    center: UnitPoint(x: 0.5, y: 0.0),
                    startRadius: 0,
                    endRadius: 220
                )
            )

            shape.strokeBorder(AppColor.pro.opacity(0.38), lineWidth: 1)
        }
    }

    // MARK: - Practice Card

    private var practiceDifficultyRow: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    practiceDifficultyLabel
                    practiceDifficultyPicker
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .center, spacing: Spacing.md) {
                    practiceDifficultyLabel
                    Spacer(minLength: Spacing.sm)
                    practiceDifficultyPicker
                }
            }
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("settings.practiceDifficulty")
    }

    private var practiceDifficultyLabel: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Practice difficulty")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text(practiceSettings.timedDifficulty.subtitle)
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var practiceDifficultyPicker: some View {
        Picker("Practice difficulty", selection: $practiceSettings.timedDifficulty) {
            ForEach(TimedPracticeDifficulty.allCases) { difficulty in
                Text(difficulty.title).tag(difficulty)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .accessibilityLabel("Practice difficulty")
        .tint(AppColor.brandBlue)
    }

    private var dailyGoalLabel: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Daily goal")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Text("Choose a pace that fits your week.")
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dailyGoalPicker: some View {
        Picker("Daily goal", selection: $dailyGoal.goalReps) {
            ForEach(dailyGoal.minGoalReps...dailyGoal.maxGoalReps, id: \.self) { value in
                Text("\(value) rep\(value == 1 ? "" : "s")").tag(value)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .accessibilityLabel("Daily goal")
        .tint(AppColor.brandBlue)
    }

    private var dailyGoalCard: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    dailyGoalLabel
                    dailyGoalPicker
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .center, spacing: Spacing.md) {
                    dailyGoalLabel
                    Spacer(minLength: Spacing.sm)
                    dailyGoalPicker
                }
            }
        }
        .frame(minHeight: 44)
        .accessibilityIdentifier("settings.dailyGoal")
    }

    private var practiceVoiceCuesRow: some View {
        SettingsToggleRow(
            title: "Voice cues",
            subtitle: "Read replies aloud during Conversation Practice.",
            isOn: $imVoicePlaybackSettings.isEnabled,
            accessibilityHint: "Enables spoken responses during Conversation Practice."
        )
    }

    private var fillerHighlightRow: some View {
        SettingsToggleRow(
            title: "Real-time filler highlight",
            subtitle: micDisabledForFillerHighlight
                ? "Microphone access is required for live filler detection."
                : "Plays a soft cue and pulse when a filler word is detected.",
            isOn: $practiceSettings.fillerAlertSoundEnabled,
            isDisabled: micDisabledForFillerHighlight,
            disabledReason: micDisabledForFillerHighlight ? "Mic access blocked" : nil,
            accessibilityHint: "Plays a soft cue when a filler word is detected during a session."
        )
    }

    private var pressureModeRow: some View {
        SettingsToggleRow(
            title: "Pressure mode",
            subtitle: "One-take reps, shorter prep, and a rated finish across exercises.",
            isOn: $practiceSettings.pressureModeEnabled,
            accessibilityHint: "Adds time pressure and rating to every exercise."
        )
    }

    private var practiceLanguageRow: some View {
        SettingsNavRow(
            title: "Practice language",
            value: localeSettings.current.displayName,
            icon: "globe",
            accessibilityHint: "Pick the language you want to practice in."
        ) {
            showLocalePicker = true
        }
    }

    private var soundscapeRow: some View {
        let mode = SoundscapeSettings.savedMode
        return SettingsNavRow(
            title: "Pre-rep ambience",
            value: mode == .off ? "Off" : mode.title,
            icon: mode.symbolName,
            accessibilityHint: "Pick an ambient texture for the pre-rep countdown."
        ) {
            showSoundscape = true
        }
    }

    private var coachingProfileRow: some View {
        SettingsNavRow(
            title: coachingProfileStore.profile == nil ? "Set coaching profile" : "Update coaching profile",
            value: coachingProfileStore.profile?.chosenStyleGoal?.title,
            icon: "person.crop.circle.badge.checkmark",
            accessibilityHint: "Open the coaching profile flow."
        ) {
            showCoachingProfile = true
        }
    }

    private var upcomingMomentRow: some View {
        SettingsNavRow(
            title: "Upcoming moment",
            value: bigMomentStore.activeMoment?.title,
            icon: "calendar.badge.clock",
            accessibilityHint: "Set or update the important moment you are preparing for."
        ) {
            showBigMomentIntake = true
        }
    }

    private var practiceCard: some View {
        cardContainer(spacing: Spacing.md) {
            HStack(alignment: .center, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Practice difficulty")
                        .font(.subheadline.weight(.semibold))
                    Text(practiceSettings.timedDifficulty.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.sm)
                Picker("Practice difficulty", selection: $practiceSettings.timedDifficulty) {
                    ForEach(TimedPracticeDifficulty.allCases) { difficulty in
                        Text(difficulty.title).tag(difficulty)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .accessibilityLabel("Practice difficulty")
                .tint(AppColor.brandBlue)
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("settings.practiceDifficulty")

            Divider()

            SettingsToggleRow(
                title: "Voice cues",
                subtitle: "Read replies aloud during Conversation Practice.",
                isOn: $imVoicePlaybackSettings.isEnabled,
                accessibilityHint: "Enables spoken responses during Conversation Practice."
            )

            Divider()

            SettingsToggleRow(
                title: "Real-time filler highlight",
                subtitle: micDisabledForFillerHighlight
                    ? "Microphone access is required for live filler detection."
                    : "Plays a soft cue and pulse when a filler word is detected.",
                isOn: $practiceSettings.fillerAlertSoundEnabled,
                isDisabled: micDisabledForFillerHighlight,
                disabledReason: micDisabledForFillerHighlight ? "Mic access blocked" : nil,
                accessibilityHint: "Plays a soft cue when a filler word is detected during a session."
            )

            Divider()

            SettingsToggleRow(
                title: "Pressure mode",
                subtitle: "One-take reps, shorter prep, and a rated finish across modes.",
                isOn: $practiceSettings.pressureModeEnabled,
                accessibilityHint: "Adds time pressure and rating to every drill."
            )
        }
    }

    private var micDisabledForFillerHighlight: Bool {
        microphonePermission == .denied
    }

    // MARK: - Soundscape Card

    private var soundscapeCard: some View {
        let mode = SoundscapeSettings.savedMode
        return cardContainer(spacing: Spacing.sm) {
            SettingsNavRow(
                title: "Pre-rep ambience",
                value: mode == .off ? "Off" : mode.title,
                icon: mode.symbolName,
                accessibilityHint: "Pick an ambient texture that plays during the pre-rep countdown."
            ) {
                showSoundscape = true
            }
        }
    }

    // MARK: - Practice Language Card (M12)

    private var localeCard: some View {
        cardContainer(spacing: Spacing.sm) {
            SettingsNavRow(
                title: "Practice language",
                value: localeSettings.current.displayName,
                icon: "globe",
                accessibilityHint: "Pick the language you want to practice in. Switches transcription, filler-word detection, and the prompt pool."
            ) {
                showLocalePicker = true
            }
        }
    }

    // MARK: - Coaching Profile Card

    private var coachingProfileCard: some View {
        cardContainer(spacing: Spacing.sm) {
            SettingsNavRow(
                title: coachingProfileStore.profile == nil ? "Set coaching profile" : "Update coaching profile",
                value: coachingProfileStore.profile.map {
                    "\($0.primaryGoal.title)\($0.chosenStyleGoal.map { " · \($0.title)" } ?? "")"
                },
                icon: "person.crop.circle.badge.checkmark",
                accessibilityHint: "Open the coaching profile flow."
            ) {
                showCoachingProfile = true
            }

            SettingsNavRow(
                title: "Upcoming moment",
                value: bigMomentStore.activeMoment?.title,
                icon: "calendar.badge.clock",
                accessibilityHint: "Set or update the high-stakes moment you are preparing for."
            ) {
                showBigMomentIntake = true
            }
        }
    }

    // MARK: - Feedback Card (Reminders + Haptics)

    private var dailyReminderRow: some View {
        SettingsToggleRow(
            title: "Daily reminder",
            subtitle: dailyReminderSubtitle,
            isOn: Binding(
                get: { notificationManager.dailyReminderEnabled },
                set: { newValue in
                    Task { await notificationManager.setDailyReminderEnabled(newValue) }
                }
            ),
            accessibilityHint: "A single reminder at your chosen time of day."
        )
    }

    private var eveningPracticeNudgeRow: some View {
        SettingsToggleRow(
            title: "Evening practice nudge",
            subtitle: "A quiet reminder when you have not practiced today.",
            isOn: Binding(
                get: { notificationManager.streakWarningEnabled },
                set: { newValue in
                    Task { await notificationManager.setStreakWarningEnabled(newValue) }
                }
            ),
            accessibilityHint: "Sends an optional evening reminder for a short practice rep."
        )
    }

    private var weeklyDigestRow: some View {
        SettingsToggleRow(
            title: "Weekly digest",
            subtitle: "A Sunday review of how the week landed and what is changing.",
            isOn: Binding(
                get: { notificationManager.weeklyDigestEnabled },
                set: { newValue in
                    Task { await notificationManager.setWeeklyDigestEnabled(newValue) }
                }
            ),
            accessibilityHint: "A short weekly summary every Sunday."
        )
    }

    private var notificationAccessRow: some View {
        SettingsStatusRow(
            title: "Notification access",
            value: notificationManager.authorizationLabel,
            valueTint: authorizationTint(notificationManager.authorizationLabel),
            icon: "bell.fill"
        )
    }

    private var hapticsRow: some View {
        SettingsToggleRow(
            title: "Haptics",
            subtitle: "Subtle taps for results and rep transitions.",
            isOn: $hapticsSettings.isEnabled,
            accessibilityHint: "Master haptic feedback switch."
        )
    }

    private var interactionSoundsRow: some View {
        SettingsToggleRow(
            title: "Interaction sounds",
            subtitle: "Quiet ticks when results land. The silent switch always wins.",
            isOn: $interactionSounds.isEnabled,
            accessibilityHint: "Master switch for interface sound cues."
        )
    }

    private var feedbackCard: some View {
        cardContainer(spacing: Spacing.md) {
            // Daily reminder
            SettingsToggleRow(
                title: "Daily reminder",
                subtitle: dailyReminderSubtitle,
                isOn: Binding(
                    get: { notificationManager.dailyReminderEnabled },
                    set: { newValue in
                        Task { await notificationManager.setDailyReminderEnabled(newValue) }
                    }
                ),
                accessibilityHint: "A single reminder at your chosen time of day."
            )

            if notificationManager.dailyReminderEnabled {
                dailyReminderTimePicker
            }

            Divider()

            // Evening rhythm nudge
            SettingsToggleRow(
                title: "Evening practice nudge",
                subtitle: "A quiet reminder when you have a streak and haven't practiced today.",
                isOn: Binding(
                    get: { notificationManager.streakWarningEnabled },
                    set: { newValue in
                        Task { await notificationManager.setStreakWarningEnabled(newValue) }
                    }
                ),
                accessibilityHint: "Sends an optional evening reminder for a short practice rep."
            )

            Divider()

            // Weekly digest
            SettingsToggleRow(
                title: "Weekly digest",
                subtitle: "Sunday evening: how the week landed and what's trending.",
                isOn: Binding(
                    get: { notificationManager.weeklyDigestEnabled },
                    set: { newValue in
                        Task { await notificationManager.setWeeklyDigestEnabled(newValue) }
                    }
                ),
                accessibilityHint: "A short weekly summary every Sunday."
            )

            SettingsStatusRow(
                title: "Notification access",
                value: notificationManager.authorizationLabel,
                valueTint: authorizationTint(notificationManager.authorizationLabel),
                icon: "bell.fill"
            )

            Divider()

            // Haptics
            SettingsToggleRow(
                title: "Haptics",
                subtitle: "Subtle taps for streaks, level-ups, and rep transitions.",
                isOn: $hapticsSettings.isEnabled,
                accessibilityHint: "Master haptic feedback switch."
            )

            Divider()

            // Interaction sounds (A2) — tiny synthesized cues (verdict
            // thump, settle tick, drill brush, streak tock). `.ambient`
            // session category: the device silent switch always wins;
            // this is the in-app master.
            SettingsToggleRow(
                title: "Interaction sounds",
                subtitle: "Quiet synthesized ticks when results land. The silent switch always wins.",
                isOn: $interactionSounds.isEnabled,
                accessibilityHint: "Master switch for interface sound cues."
            )
        }
    }

    private var dailyReminderSubtitle: String {
        if notificationManager.dailyReminderEnabled {
            return "Fires daily at \(formattedReminderTime). Tap to change."
        }
        return "One short reminder at a time you choose."
    }

    private var formattedReminderTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        var components = DateComponents()
        components.hour = notificationManager.dailyReminderHour
        components.minute = notificationManager.dailyReminderMinute
        let date = Calendar.current.date(from: components) ?? Date()
        return formatter.string(from: date)
    }

    private var dailyReminderTimePicker: some View {
        let binding = Binding<Date>(
            get: {
                var c = DateComponents()
                c.hour = notificationManager.dailyReminderHour
                c.minute = notificationManager.dailyReminderMinute
                return Calendar.current.date(from: c) ?? Date()
            },
            set: { newDate in
                let c = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                notificationManager.dailyReminderHour = c.hour ?? 9
                notificationManager.dailyReminderMinute = c.minute ?? 0
            }
        )

        return DatePicker(
            "Reminder time",
            selection: binding,
            displayedComponents: .hourAndMinute
        )
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .accessibilityLabel("Daily reminder time")
    }

    private func authorizationTint(_ label: String) -> Color {
        switch label {
        case "Allowed", "Quietly allowed", "Temporarily allowed": return AppColor.positive
        case "Blocked": return AppColor.warning
        default: return .secondary
        }
    }

    // MARK: - Subscription Card

    private var subscriptionCard: some View {
        cardContainer(spacing: Spacing.md) {
            if premium.isPremium {
                proHeader
                Divider()
                SettingsNavRow(
                    title: "Manage subscription",
                    icon: "creditcard.fill",
                    accessibilityHint: "Opens the App Store subscription manager."
                ) {
                    openManageSubscriptions()
                }
                SettingsNavRow(
                    title: "Restore purchase",
                    icon: "arrow.clockwise",
                    accessibilityHint: "Re-checks your App Store entitlements."
                ) {
                    Task { await premium.restorePurchases() }
                }
                if authManager.isDeveloper {
                    Button("Revoke Pro (debug)") {
                        premium.revokePremium()
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.warning)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                freeHeader
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "crown.fill")
                            .font(.subheadline.weight(.semibold))
                        Text("See plans")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [AppColor.pro, AppColor.proLight],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                }
                .buttonStyle(.pressable)
                .accessibilityHint("Opens the paywall to view subscription plans.")

                Button("Restore purchase") {
                    Task { await premium.restorePurchases() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 44)
                .accessibilityHint("Re-checks your App Store entitlements.")
            }
        }
    }

    private var proHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.title3)
                .foregroundStyle(
                    LinearGradient(
                        colors: [AppColor.pro, AppColor.proLight],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("Noum Pro")
                    .font(.headline.weight(.bold))
                Text("All premium features unlocked.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var freeHeader: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.title3)
                .foregroundStyle(AppColor.pro.opacity(0.6))
            VStack(alignment: .leading, spacing: 2) {
                Text("Noum is free to try")
                    .font(.headline.weight(.bold))
                Text("Pro unlocks Coach Mode, transcripts, analytics, and more.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private func openManageSubscriptions() {
        #if canImport(UIKit) && canImport(StoreKit)
        Task { @MainActor in
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) ?? UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first
            else {
                debugMessage = "Subscription management is unavailable right now."
                return
            }
            do {
                try await AppStore.showManageSubscriptions(in: scene)
            } catch {
                debugMessage = "Couldn't open the subscription manager. Try again from the App Store."
            }
        }
        #else
        debugMessage = "Subscription management is unavailable on this device."
        #endif
    }

    // MARK: - AI Usage Card
    //
    // Honest read-side surface for the two AI budgets that gate the coach
    // surfaces. Surfaces only when an AI provider is actually configured —
    // a user without API keys would just see "0 of 12 remaining" with no
    // explanation, which would read as a broken state. The card itself
    // explains the soft-degrade contract so a user on a heavy day knows
    // why their coach went rule-based today and isn't asking "is the AI
    // broken?"
    //
    // Two budgets shown:
    //   • Per-rep coach notes — daily cap from `AIRateLimiter`. Resets
    //     at midnight in the user's local calendar.
    //   • Per-rep session debrief — monthly cap from `AISettingsManager`.
    //     Resets on the first of the month.
    //
    // Vision-aligned (docs/VISION.md anti-goals): never blocks practice,
    // never lies about a fallback. The user always gets a coach note;
    // sometimes it's rule-based, and now they can see why.

    private var aiUsageCardIsVisible: Bool {
        aiSettings.activeProvider != nil
    }

    private var aiUsageCard: some View {
        let coachNotesRemaining = rateLimiter.remainingToday(kind: .postRepCoachNote)
        let coachNotesCap = rateLimiter.currentCap()
        let coachNotesUsed = max(0, coachNotesCap - coachNotesRemaining)
        let coachNotesHasReachedLimit = coachNotesRemaining == 0

        let debriefRemaining = aiSettings.remainingAnalyses
        let debriefCap = aiSettings.monthlyLimit
        let debriefUsed = max(0, debriefCap - debriefRemaining)

        return cardContainer(spacing: Spacing.md) {
            Text("A coach note is still available after every rep. When personalized wording reaches its daily limit, Noum keeps the same coaching structure with simpler wording.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            aiUsageRow(
                title: "Coach notes today",
                used: coachNotesUsed,
                cap: coachNotesCap,
                remaining: coachNotesRemaining,
                reachedLimit: coachNotesHasReachedLimit,
                resetCopy: "Resets at midnight",
                accessibilityHint: "Daily budget for personalized coach notes."
            )

            Divider()

            aiUsageRow(
                title: "Session debriefs",
                used: debriefUsed,
                cap: debriefCap,
                remaining: debriefRemaining,
                reachedLimit: aiSettings.hasReachedLimit,
                resetCopy: "Resets \(aiSettings.resetDateFormatted)",
                accessibilityHint: "Monthly budget for personalized session debriefs."
            )

            if !premium.isPremium {
                Divider()
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "crown.fill")
                            .font(.subheadline.weight(.semibold))
                        Text("Pro includes \(AIRateLimiter.premiumDailyCap) coach notes a day and \(AISettingsManager.premiumMonthlyDebriefLimit) debriefs a month")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(AppColor.pro)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 44)
                }
                .buttonStyle(.pressable)
                .accessibilityHint("Opens the paywall to view subscription plans.")
                .accessibilityIdentifier("settings.aiUsage.upgradeCTA")
            }
        }
        .accessibilityIdentifier("settings.aiUsage.card")
    }

    /// Single AI budget row — left column is the title + reset copy,
    /// right column is the headline "used / cap" tile in the tier
    /// register. Reaches a calm minimum-info baseline so a user who
    /// hasn't burned any budget yet sees "0 of 12 · resets at midnight"
    /// — honest without pushing the user to do anything.
    @ViewBuilder
    private func aiUsageRow(
        title: String,
        used: Int,
        cap: Int,
        remaining: Int,
        reachedLimit: Bool,
        resetCopy: String,
        accessibilityHint: String
    ) -> some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(resetCopy)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: Spacing.sm)
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(used) of \(cap)")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(reachedLimit ? AppColor.caution : .primary)
                    .monospacedDigit()
                Text(reachedLimit ? "Rule-based today" : "\(remaining) remaining")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(reachedLimit ? AppColor.caution : .secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(used) of \(cap) used. \(reachedLimit ? "Coach reads rule-based for the rest of the period." : "\(remaining) remaining.") \(resetCopy).")
        .accessibilityHint(accessibilityHint)
    }

    // MARK: - Privacy Card

    private var privacyCard: some View {
        cardContainer(spacing: Spacing.sm) {
            SettingsStatusRow(
                title: "Microphone access",
                value: microphonePermission.label,
                valueTint: microphonePermission.tint,
                icon: "mic.fill"
            )

            if microphonePermission == .denied {
                Button {
                    openSystemSettings()
                } label: {
                    Text("Open system settings")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
                .buttonStyle(.pressable)
                .accessibilityHint("Opens iOS Settings to grant microphone access.")
            }

            Divider()

            SettingsStatusRow(
                title: "Cloud processing",
                value: aiSettings.cloudProcessingStatusTitle,
                valueTint: aiSettings.isCloudProcessingAllowed ? AppColor.positive : .secondary,
                icon: "cloud.fill"
            )

            Button {
                showCloudProcessingConsent = true
            } label: {
                Text(aiSettings.isCloudProcessingAllowed ? "Review permission" : "Choose permission")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: 44)
            .buttonStyle(.pressable)
            .accessibilityHint("Review what Noum sends to speech and AI providers, then allow or decline cloud processing.")

            Divider()

            SettingsNavRow(
                title: "Your data",
                icon: "tray.full.fill",
                accessibilityHint: "Review what Noum stores on this device and where it processes data."
            ) {
                showYourData = true
            }

            Divider()

            SettingsNavRow(
                title: "Privacy policy",
                icon: "doc.text.fill",
                accessibilityHint: "Read the full privacy policy."
            ) {
                showPrivacyPolicy = true
            }
        }
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    // MARK: - Account Card

    private var accountCard: some View {
        cardContainer(spacing: Spacing.sm) {
            if authManager.isSignedIn {
                let presentation = accountPresentation
                SettingsStatusRow(
                    title: presentation.identityTitle,
                    value: presentation.identityValue,
                    valueTint: .primary
                )
                if let provider = presentation.providerTitle {
                    SettingsStatusRow(
                        title: "Provider",
                        value: provider,
                        valueTint: .secondary
                    )
                }

                Divider()

                if presentation.showsConnectCoaching {
                    Button {
                        Task { @MainActor in
                            await authManager.connectLocalGuestToCloud(
                                force: true
                            )
                        }
                    } label: {
                        accountActionLabel(
                            title: "Connect live coaching",
                            tint: AppColor.brandBlue,
                            icon: "bolt.horizontal.circle.fill"
                        )
                    }
                    .buttonStyle(.pressable)
                    .disabled(accountMutationIsBlocked)
                    .accessibilityHint("Creates a secure guest connection and keeps your existing practice history on this device.")
                    .accessibilityIdentifier("settings.account.connectCoaching")

                    Divider()
                }

                if accountMutationIsBlocked {
                    SettingsStatusRow(
                        title: "Account connection",
                        value: "Finishing securely",
                        valueTint: AppColor.caution,
                        icon: "arrow.triangle.2.circlepath"
                    )
                    Divider()
                }

                if presentation.showsSignOut {
                    Button {
                        showSignOutAlert = true
                    } label: {
                        accountActionLabel(title: "Sign out", tint: AppColor.warning, icon: "arrow.right.square")
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Sign out")
                    .accessibilityHint("Signs you out on this device. Your data stays on your account.")
                }

                Button {
                    showDeleteSheet = true
                } label: {
                    accountActionLabel(title: "Delete account", tint: AppColor.warning, icon: "trash.fill")
                }
                .buttonStyle(.pressable)
                .disabled(accountMutationIsBlocked)
                .accessibilityLabel("Delete account")
                .accessibilityHint(
                    accountMutationIsBlocked
                        ? "Available after the secure account connection finishes."
                        : presentation.deletionAccessibilityHint
                )
                .accessibilityIdentifier("settings.account.delete")
            } else {
                SettingsStatusRow(
                    title: "Status",
                    value: "Signed out",
                    valueTint: .secondary
                )

                Divider()

                Button {
                    showLogin = true
                } label: {
                    accountActionLabel(
                        title: "Sign in",
                        tint: AppColor.brandBlue,
                        icon: "person.crop.circle.badge.plus"
                    )
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Sign in")
                .accessibilityHint("Opens account options.")
                .accessibilityIdentifier("settings.account.openLogin")
            }
        }
    }

    private func accountActionLabel(title: String, tint: Color, icon: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 22)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint.opacity(0.6))
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
    }

    // MARK: - About Card

    private var aboutCard: some View {
        cardContainer(spacing: Spacing.sm) {
            SettingsStatusRow(
                title: "Version",
                value: appVersionString,
                valueTint: .secondary
            )

            Divider()

            SettingsNavRow(
                title: "Copy diagnostic report",
                icon: "doc.on.doc.fill",
                accessibilityHint: "Copies a short sign-in diagnostic to your clipboard for support."
            ) {
                copyDiagnosticReport()
            }
        }
    }

    private var appVersionString: String {
        "\(appVersion) (\(appBuildNumber))"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    private var appBuildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
    }

    private var appSourceGitCommit: String {
        Bundle.main.infoDictionary?["NoumSourceGitCommit"] as? String ?? "unbound"
    }

    private func copyDiagnosticReport() {
        let payload = authManager.supportReportPayload()
        #if canImport(UIKit)
        UIPasteboard.general.string = payload
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
        #endif
        withAnimation(reduceMotion ? nil : .standardSpring) {
            supportToast = "Diagnostic copied to clipboard"
        }
    }

    private func copyAICallDiagnostics() {
        let payload = aiCallDiagnostics.exportDiagnostics()
        #if canImport(UIKit)
        UIPasteboard.general.string = payload
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
        #endif
        withAnimation(reduceMotion ? nil : .standardSpring) {
            supportToast = "AI call log copied to clipboard"
        }
    }

    private func copyFlowEvents() {
        let payload = flowEvents.export()
        #if canImport(UIKit)
        UIPasteboard.general.string = payload
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
        #endif
        withAnimation(reduceMotion ? nil : .standardSpring) {
            supportToast = "Flow events copied to clipboard"
        }
    }

    private func copyTraceID(_ traceID: UUID) {
        #if canImport(UIKit)
        UIPasteboard.general.string = traceID.uuidString
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(traceID.uuidString, forType: .string)
        #endif
        withAnimation(reduceMotion ? nil : .standardSpring) {
            supportToast = "Trace ID copied to clipboard"
        }
    }

    private func copyCoachSupportBundle(_ traceID: UUID) {
        guard let payload = flowEvents.exportCoachSupportBundle(
            correlationId: traceID,
            diagnostics: aiCallDiagnostics.records,
            appVersion: appVersion,
            buildNumber: appBuildNumber,
            sourceGitCommit: appSourceGitCommit
        ) else {
            withAnimation(reduceMotion ? nil : .standardSpring) {
                supportToast = "Trace is no longer available"
            }
            return
        }
        #if canImport(UIKit)
        UIPasteboard.general.string = payload
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(payload, forType: .string)
        #endif
        withAnimation(reduceMotion ? nil : .standardSpring) {
            supportToast = "Redacted support bundle copied"
        }
    }

    @ViewBuilder
    private var flowEventsCard: some View {
        let kpis = TransformationKPIReport.derive(
            events: flowEvents.events,
            sessions: sessionStore.sessions,
            outcomes: recommendationLearningStore.outcomes
        )
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                compactStat(title: "Flow events", value: "\(flowEvents.events.count)")
                Spacer()
                compactStat(title: "Flows", value: "\(flowEvents.recentFlows().count)")
            }
            Text("Correlation-grouped events for reconstructing what happened in a rep or chat turn. Reasons + counts only — no transcript text.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Divider()
            Text("Transformation signals")
                .font(.caption.weight(.semibold))
            HStack {
                compactStat(
                    title: "First rep",
                    value: kpis.firstRepCompleted ? "Complete" : "Pending"
                )
                Spacer()
                compactStat(
                    title: "Time to rep",
                    value: kpis.timeToFirstRepSeconds.map { "\(Int($0))s" } ?? "—"
                )
            }
            HStack {
                compactStat(
                    title: "Typed → live",
                    value: kpis.typedToLiveUpgradeRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
                )
                Spacer()
                compactStat(
                    title: "Goal movement 28d",
                    value: kpis.goalImprovementRate28Days.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
                )
            }
            HStack {
                compactStat(
                    title: "Review open",
                    value: kpis.reviewOpenRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
                )
                Spacer()
                compactStat(
                    title: "Prescription",
                    value: kpis.prescriptionAcceptanceRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
                )
            }
            HStack {
                compactStat(
                    title: "Ladder → retry",
                    value: kpis.transcriptLadderAcceptanceRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
                )
                Spacer()
                compactStat(
                    title: "Retry → compared",
                    value: kpis.transcriptRetryComparisonCompletionRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
                )
            }
            HStack {
                compactStat(
                    title: "Target improved",
                    value: kpis.transcriptTargetImprovementRate.map { "\(Int(($0 * 100).rounded()))%" } ?? "—"
                )
                Spacer()
            }
            Text("Account-local diagnostic signals. No transcript, advertising identifier, or third-party analytics SDK is used.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Divider()
            Text("Coach request traces")
                .font(.caption.weight(.semibold))
            let coachTraces = flowEvents.recentCoachTraces(limit: 3)
            if coachTraces.isEmpty {
                Text("No Ask Noum request traces yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(coachTraces) { trace in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(String(trace.correlationId.uuidString.prefix(8)))
                                .font(.caption.monospaced().weight(.semibold))
                            Spacer()
                            Text(trace.terminalStatusLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(
                                    trace.hasTerminalContractViolation || trace.terminalState == .retryableError
                                        ? AppColor.warning
                                        : AppColor.textSecondary
                                )
                        }
                        HStack(spacing: Spacing.xs) {
                            Text("\(trace.events.count) stages")
                            if let latencyMs = trace.latencyMs {
                                Text("· \(latencyMs) ms")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        if trace.hasTerminalContractViolation {
                            Label(
                                "Terminal contract violation: \(trace.terminalEventCount) terminal events",
                                systemImage: "exclamationmark.triangle.fill"
                            )
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppColor.warning)
                        }
                        ForEach(trace.events) { event in
                            VStack(alignment: .leading, spacing: 1) {
                                HStack {
                                    Text(event.stage)
                                    Spacer()
                                    if let elapsedMs = trace.elapsedMs(for: event) {
                                        Text("+\(elapsedMs) ms")
                                    }
                                }
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                if !event.reason.isEmpty {
                                    Text(event.reason)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(2)
                                }
                            }
                        }
                        Button {
                            copyTraceID(trace.correlationId)
                        } label: {
                            Label("Copy trace ID", systemImage: "number")
                                .font(.caption.weight(.semibold))
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .foregroundStyle(AppColor.brandBlue)
                        .accessibilityIdentifier("settings.debugTraces.copyTraceID")
                        Button {
                            copyCoachSupportBundle(trace.correlationId)
                        } label: {
                            Label("Copy redacted support bundle", systemImage: "doc.badge.gearshape")
                                .font(.caption.weight(.semibold))
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                        .foregroundStyle(AppColor.brandBlue)
                        .accessibilityIdentifier("settings.debugTraces.copySupportBundle")
                        .accessibilityHint("Copies content-free request stages and matching provider diagnostics for local support replay.")
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel("Coach trace \(String(trace.correlationId.uuidString.prefix(8))), \(trace.terminalStatusLabel), \(trace.events.count) stages, \(trace.terminalEventCount) terminal events")
                    .accessibilityIdentifier("settings.debugTraces.coachTrace")
                }
            }
            Divider()
            Text("Training loop traces")
                .font(.caption.weight(.semibold))
            let trainingTraces = flowEvents.recentTranscriptPracticeTraces(limit: 3)
            if trainingTraces.isEmpty {
                Text("No transcript-ladder retry traces yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(trainingTraces) { trace in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(String(trace.correlationId.uuidString.prefix(8)))
                                .font(.caption.monospaced().weight(.semibold))
                            Spacer()
                            Text(trace.result?.rawValue ?? "in flight")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(trace.result == .regressed ? AppColor.warning : AppColor.textSecondary)
                        }
                        HStack(spacing: Spacing.xs) {
                            Text("\(trace.events.count) stages")
                            if let latencyMs = trace.latencyMs {
                                Text("· \(latencyMs) ms")
                            }
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        Text(trace.events.map(\.stage).joined(separator: " → "))
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                        Button {
                            copyTraceID(trace.correlationId)
                        } label: {
                            Label("Copy trace ID", systemImage: "number")
                                .font(.caption.weight(.semibold))
                                .frame(minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(AppColor.brandBlue)
                    }
                    .padding(Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Training trace \(String(trace.correlationId.uuidString.prefix(8))), \(trace.result?.rawValue ?? "in flight"), \(trace.events.count) stages")
                }
            }
            Divider()
            if flowEvents.events.isEmpty {
                Text("No flow events yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(flowEvents.events.prefix(4)) { event in
                    HStack(spacing: 8) {
                        Text(event.flow.title)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(event.stage)
                            .font(.caption.monospaced())
                        Spacer()
                        Text(event.outcome.title)
                            .font(.caption2)
                            .foregroundStyle(event.outcome == .success ? .green : .orange)
                    }
                }
            }
            HStack {
                Button { copyFlowEvents() } label: {
                    Label("Copy flow log", systemImage: "doc.on.doc")
                        .font(.caption.weight(.semibold))
                }
                Spacer()
                Button(role: .destructive) { flowEvents.reset() } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
            }
        }
        .accessibilityIdentifier("settings.debugTraces.card")
    }

    // MARK: - Microphone Permission

    private enum MicrophonePermissionState {
        case unknown, undetermined, denied, granted

        var label: String {
            switch self {
            case .granted: return "Allowed"
            case .denied: return "Blocked"
            case .undetermined: return "Not requested"
            case .unknown: return "Unavailable"
            }
        }

        var tint: Color {
            switch self {
            case .granted: return AppColor.positive
            case .denied: return AppColor.warning
            default: return .secondary
            }
        }
    }

    private func refreshMicrophonePermission() {
        #if canImport(AVFAudio)
        let status: MicrophonePermissionState
        switch AVAudioApplication.shared.recordPermission {
        case .granted: status = .granted
        case .denied: status = .denied
        case .undetermined: status = .undetermined
        @unknown default: status = .unknown
        }
        microphonePermission = status
        #else
        microphonePermission = .unknown
        #endif
    }

    // MARK: - Card Container

    @ViewBuilder
    private func cardContainer<Content: View>(
        spacing: CGFloat = Spacing.md,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: spacing, content: content)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Developer Cards (preserved from prior implementation)

    @AppStorage("transcriptionProvider") private var selectedProvider: String = "deepgram"

    private var transcriptionProviderCard: some View {
        cardContainer(spacing: Spacing.md) {
            Text("Switch between speech-to-text backends for testing and comparison.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Picker("Provider", selection: $selectedProvider) {
                ForEach(TranscriptionProviderID.allCases) { provider in
                    Text(provider.displayName).tag(provider.rawValue)
                }
            }
            .pickerStyle(.segmented)

            let qualityStore = TranscriptionQualityStore.shared
            if let avgLatency = qualityStore.averageLatency(for: selectedProvider) {
                HStack(spacing: Spacing.sm) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avg latency")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(avgLatency)ms")
                            .font(.subheadline.weight(.bold))
                    }
                    Spacer()
                    if let avgConf = qualityStore.averageConfidence(for: selectedProvider) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Avg confidence")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", avgConf * 100))
                                .font(.subheadline.weight(.bold))
                        }
                    }
                }
                .padding(Spacing.sm)
                .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }

            if imVoicePlaybackSettings.isEnabled {
                Divider()
                Text("Conversation voice quality")
                    .font(.subheadline.weight(.semibold))
                Text("Noum prioritizes Google Cloud first and quietly falls back to OpenAI if needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(IMVoiceEngine.allCases) { engine in
                    Button {
                        imVoicePlaybackSettings.engine = engine
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(engine.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text(engine.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: imVoicePlaybackSettings.engine == engine ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(imVoicePlaybackSettings.engine == engine ? AppColor.brandBlue : .secondary)
                        }
                        .padding(Spacing.sm)
                        .background(
                            AppColor.brandBlue.opacity(imVoicePlaybackSettings.engine == engine ? 0.10 : 0.04),
                            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        )
                    }
                    .buttonStyle(.pressable)
                }
            }

            // V3 — DEBUG-only developer cost-saver: force the on-device Apple
            // voice instead of paying for cloud TTS while testing. Compiled out
            // of release entirely (`#if DEBUG`) and nested inside the
            // `isDeveloper`-gated Developer tools section, so paying users can
            // never land here. Default OFF → production always uses cloud voice.
            #if DEBUG
            Divider()
            SettingsToggleRow(
                title: "Force on-device voice (dev)",
                subtitle: "Use the free Apple system voice instead of cloud TTS while testing. Lower quality — debug builds only.",
                isOn: $imVoicePlaybackSettings.forceOnDeviceTTS,
                accessibilityHint: "When on, coach replies speak with the on-device system voice to avoid cloud text-to-speech cost during development."
            )
            #endif
        }
    }

    private var aiCallDiagnosticsCard: some View {
        let latest = aiCallDiagnostics.latest
        return cardContainer(spacing: Spacing.md) {
            Text("Recent live-coaching health checks. Message content is never stored.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("AI service: \(AIProviderCredential.configurationSummary())")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.aiCallDiagnostics.providerSetup")

            Text("Live coaching: \(CoachChatProvider.configurationSummary())")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("settings.aiCallDiagnostics.chatProviderSetup")

            HStack(spacing: Spacing.xs) {
                compactStat(title: "Recent", value: "\(aiCallDiagnostics.records.count)")
                compactStat(title: "Latest", value: latest?.outcome.title ?? "-")
                compactStat(title: "Provider", value: latest?.provider ?? "-")
            }

            Button {
                runAIProviderHealthCheck()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: isRunningAIProviderHealthCheck ? "hourglass" : "waveform.path.ecg")
                        .accessibilityHidden(true)
                    Text(isRunningAIProviderHealthCheck ? "Checking providers..." : "Check providers")
                    Spacer(minLength: Spacing.xs)
                    Image(systemName: "arrow.right.circle.fill")
                        .accessibilityHidden(true)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, Spacing.sm)
            }
            .buttonStyle(.plain)
            .background(AppColor.brandBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            .foregroundStyle(AppColor.brandBlue)
            .disabled(isRunningAIProviderHealthCheck)
            .accessibilityHint("Sends one tiny health-check request to the active AI provider and records a non-secret diagnostic.")

            if let aiProviderHealthSummary {
                Text(aiProviderHealthSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let aiProviderHealthGuidance {
                aiProviderHealthGuidanceView(aiProviderHealthGuidance)
            }

            if aiCallDiagnostics.records.isEmpty {
                Text("No AI calls recorded yet. Ask Noum or finish a rep to populate this.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: Spacing.xs) {
                    ForEach(aiCallDiagnostics.records.prefix(3)) { record in
                        aiCallDiagnosticRow(record)
                    }
                }
            }

            HStack(spacing: Spacing.xs) {
                Button {
                    copyAICallDiagnostics()
                } label: {
                    Label("Copy log", systemImage: "doc.on.doc.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .background(AppColor.brandBlue.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .foregroundStyle(AppColor.brandBlue)
                .accessibilityHint("Copies the recent non-secret AI call log.")

                Button {
                    aiCallDiagnostics.reset()
                    debugMessage = "AI call diagnostics reset."
                } label: {
                    Text("Reset")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .background(AppColor.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .foregroundStyle(AppColor.warning)
                .accessibilityHint("Clears the recent AI call diagnostics on this device.")
            }
        }
        .accessibilityIdentifier("settings.aiCallDiagnostics.card")
    }

    private func runAIProviderHealthCheck() {
        guard !isRunningAIProviderHealthCheck else { return }
        isRunningAIProviderHealthCheck = true
        aiProviderHealthSummary = nil
        aiProviderHealthGuidance = nil

        Task {
            let sharedResults = await AIProviderHealthProbe.runConfiguredProviderProbes()
            let chatResults = await AICoachChatService.shared.runConfiguredProviderHealthProbes()
            let results = sharedResults + chatResults
            await MainActor.run {
                isRunningAIProviderHealthCheck = false
                aiProviderHealthSummary = formattedAIProviderHealthSummary(for: results)
                aiProviderHealthGuidance = AIProviderHealthGuidance.make(for: results)
                debugMessage = results.contains(where: \.isHealthy)
                    ? "At least one AI provider check passed."
                    : "AI provider check needs attention."
            }
        }
    }

    private func formattedAIProviderHealthSummary(for results: [AIProviderHealthProbeResult]) -> String {
        AIProviderHealthProbe.summary(for: results)
    }

    private func aiProviderHealthGuidanceView(_ guidance: AIProviderHealthGuidance) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: guidance.title == "Model path ready" ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(guidance.title == "Model path ready" ? AppColor.positive : AppColor.warning)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(guidance.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
                Text(guidance.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func aiCallDiagnosticRow(_ record: AICallDiagnosticRecord) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Circle()
                .fill(aiCallOutcomeTint(record.outcome))
                .frame(width: 10, height: 10)
                .padding(.top, 5)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: Spacing.xs) {
                    Text(record.surface)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: Spacing.xs)
                    Text(record.statusLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(aiCallOutcomeTint(record.outcome))
                }

                Text("\(record.provider)\(record.model.map { " - \($0)" } ?? "")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(record.reason)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.xs)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func aiCallOutcomeTint(_ outcome: AICallDiagnosticOutcome) -> Color {
        switch outcome {
        case .success: return AppColor.positive
        case .fallback: return AppColor.caution
        case .failure: return AppColor.warning
        case .skipped: return .secondary
        }
    }

    private var recommendationDiagnosticsCard: some View {
        cardContainer(spacing: Spacing.md) {
            Text("Inspect whether Noum's recommended mode is actually improving outcomes.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: Spacing.xs) {
                compactStat(title: "Shown", value: "\(recommendationLearningStore.outcomes.count)")
                compactStat(title: "Followed", value: "\(followedRecommendationCount)")
                compactStat(title: "Hit rate", value: followedRecommendationCount == 0 ? "—" : "\(Int(followRate * 100))%")
            }

            HStack(spacing: Spacing.xs) {
                compactStat(title: "Score Δ", value: averageScoreDelta.map { signedValue($0) } ?? "—")
                compactStat(title: "Filler rate Δ", value: averageFillerRateDelta.map { "\(signedValue($0))/min" } ?? "—")
                compactStat(title: "Duration Δ", value: averageDurationDelta.map { signedSeconds($0) } ?? "—")
            }

            HStack(spacing: Spacing.xs) {
                compactStat(
                    title: "Storage",
                    value: isBackendConfigured ? "Backend synced" : "Local only"
                )
                Button("Reset") {
                    recommendationLearningStore.resetDiagnostics()
                    debugMessage = "Recommendation diagnostics reset."
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppColor.warning.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .foregroundStyle(AppColor.warning)
            }
        }
    }

    private var developerSeedCard: some View {
        cardContainer(spacing: Spacing.md) {
            Text("Seed sessions and profiles without recording a live rep.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button("Create test session") {
                seedTestSession()
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(AppColor.brandBlue, in: Capsule())
            .buttonStyle(.pressable)

            Button("Create 3-session run") {
                seedSessionRun()
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(AppColor.modeSuddenDeath, in: Capsule())
            .buttonStyle(.pressable)

            #if DEBUG
            Divider()
            Text("Seed profiles")
                .font(.subheadline.weight(.semibold))
            Text("Inject realistic session history + baseline for inspecting the intelligence layer.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ForEach(SeedProfile.allCases, id: \.rawValue) { profile in
                Button(profile.displayName) {
                    Task { @MainActor in
                        DevSeedData.injectProfile(profile)
                        seedProfileStatus = "Injected: \(profile.displayName)"
                    }
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppColor.pro.opacity(0.15), in: Capsule())
                .foregroundStyle(AppColor.pro)
            }

            if let status = seedProfileStatus {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(AppColor.positive)
            }
            #endif
        }
    }

    private func compactStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.sm)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Recommendation Diagnostic Helpers

    private var followedRecommendationCount: Int {
        recommendationLearningStore.outcomes.filter(\.isVerifiedFollowed).count
    }

    private var followRate: Double {
        guard !recommendationLearningStore.outcomes.isEmpty else { return 0 }
        return Double(followedRecommendationCount) / Double(recommendationLearningStore.outcomes.count)
    }

    private var averageScoreDelta: Double? {
        let measured = followedOutcomes
            .filter {
                $0.hasComparableBaseline
                    && $0.hasComparableScore == true
            }
            .map(\.scoreDelta)
        guard !measured.isEmpty else { return nil }
        return measured.reduce(0, +) / Double(measured.count)
    }

    private var averageFillerRateDelta: Double? {
        let measured = followedOutcomes
            .filter(\.hasComparableBaseline)
            .compactMap(\.fillerRateDelta)
        guard !measured.isEmpty else { return nil }
        return measured.reduce(0, +) / Double(measured.count)
    }

    private var averageDurationDelta: Double? {
        averageMetric(for: \.durationDelta)
    }

    private func averageMetric(for keyPath: KeyPath<RecommendationOutcome, Double>) -> Double? {
        let values = followedOutcomes
            .filter(\.hasComparableBaseline)
            .map { $0[keyPath: keyPath] }
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private var followedOutcomes: [RecommendationOutcome] {
        recommendationLearningStore.outcomes.filter(\.isVerifiedFollowed)
    }

    private func signedValue(_ value: Double) -> String {
        String(format: "%+.1f", value)
    }

    private func signedSeconds(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded)s" : "\(rounded)s"
    }

    // MARK: - Dev Seeding

    private func seedTestSession() {
        let transcript = "I want to explain ideas with more structure and a calmer, more authoritative delivery when I feel pressure."
        seedSession(
            transcript: transcript,
            fillerCount: 1,
            duration: 34,
            mode: .timed,
            difficulty: practiceSettings.timedDifficulty
        )
        debugMessage = "Created one test session and synced XP/session data."
    }

    private func seedSessionRun() {
        seedSession(
            transcript: "I sometimes over-explain when I am nervous, so today I am focusing on clearer structure and steadier pacing.",
            fillerCount: 3,
            duration: 22,
            mode: .ahCounter,
            difficulty: .easy
        )
        seedSession(
            transcript: "My main point is that confident speakers slow the opening down, commit to the idea, and let silence replace filler words.",
            fillerCount: 1,
            duration: 29,
            mode: .suddenDeath,
            difficulty: .medium
        )
        seedSession(
            transcript: "I want people to hear me as calm and authoritative, so I need to stop over-explaining and land the point with less hesitation.",
            fillerCount: 0,
            duration: 41,
            mode: .timed,
            difficulty: .hard
        )
        debugMessage = "Created a 3-session test run with XP, summaries, and history entries."
    }

    private func seedSession(
        transcript: String,
        fillerCount: Int,
        duration: TimeInterval,
        mode: PracticeMode,
        difficulty: TimedPracticeDifficulty
    ) {
        let recentSessions = sessionStore.sessions
        let evaluation: PracticeEvaluation

        switch mode {
        case .timed:
            evaluation = PracticeEvaluator.evaluateTimedPractice(
                transcript: transcript,
                fillerCount: fillerCount,
                duration: duration,
                difficulty: difficulty,
                recentSessions: recentSessions,
                profile: coachingProfileStore.profile
            )
        case .suddenDeath:
            evaluation = PracticeEvaluator.evaluateSuddenDeathPractice(
                transcript: transcript,
                fillerCount: fillerCount,
                duration: duration,
                pressureEventsHandled: max(1, Int(duration / 15)),
                recentSessions: recentSessions,
                profile: coachingProfileStore.profile
            )
        case .ahCounter:
            evaluation = PracticeEvaluator.evaluateAhCounterPractice(
                transcript: transcript,
                fillerCount: fillerCount,
                duration: duration,
                recentSessions: recentSessions,
                profile: coachingProfileStore.profile
            )
        case .imConversation:
            evaluation = PracticeEvaluator.evaluateTimedPractice(
                transcript: transcript,
                fillerCount: fillerCount,
                duration: duration,
                difficulty: .easy,
                recentSessions: recentSessions,
                profile: coachingProfileStore.profile
            )
        }

        _ = PracticeSessionFinalizer.finalize(
            store: sessionStore,
            draft: PracticeSessionDraft(
                transcript: transcript,
                fillerWordCount: fillerCount,
                duration: duration,
                date: Date(),
                mode: mode
            ),
            annotation: PracticeSessionAnnotation(
                score: evaluation.score,
                xpEarned: evaluation.xpEarned,
                headline: evaluation.headline,
                insights: evaluation.insights,
                coachSummary: evaluation.feedback
            )
        )

        profileManager.addXP(evaluation.xpEarned)
    }
}

// MARK: - Cloud-processing consent

@available(iOS 17.0, macOS 12.0, *)
struct CloudProcessingConsentDisclosure: View {
    let isCurrentlyAllowed: Bool
    let onAllow: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Image(systemName: "hand.raised.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(width: 56, height: 56)
                        .background(AppColor.brandBlue.opacity(0.10), in: Circle())
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Cloud coaching, with your permission")
                            .font(Typography.bigStat)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("Firebase Authentication may establish a secure guest identifier before you decide. Noum does not upload your coaching content until you allow cloud processing, and deterministic coaching stays available where supported.")
                            .font(Typography.body)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            disclosureRow(
                                icon: "cloud.fill",
                                title: "Account-content storage",
                                detail: "After you allow, Firebase may sync your coaching profile, XP, practice sessions—including transcripts and session evidence—and recommendation state. Missing, declined, or stale permission keeps that content on this device."
                            )
                            disclosureRow(
                                icon: "waveform",
                                title: "Audio and transcripts",
                                detail: "Production live audio goes to Deepgram for transcription. If server observation is enabled, one bounded competitive rep first passes in memory through a protected Firebase Function; Noum does not store that audio or its full server transcript. Noum sets Deepgram's model-improvement opt-out flag, and transcripts may then be used for coaching you request."
                            )
                            disclosureRow(
                                icon: "person.text.rectangle.fill",
                                title: "Personal coaching context",
                                detail: "Your coaching profile, recent session evidence, and bounded conversation context may pass through a protected Firebase callable to Google Vertex AI (Gemini) for coaching you request."
                            )
                            disclosureRow(
                                icon: "video.fill",
                                title: "Visual feedback",
                                detail: "Selected video frames are sent only when you explicitly request a production visual-feedback feature that supports them. Release prompt speech uses Apple's on-device voice."
                            )
                        }
                    }

                    Text("Production processors: \(CloudProcessorManifest.consentProcessors.map(\.name).joined(separator: ", ")). Retention and safety practices follow their linked terms. Noum does not sell this data or use it for advertising.")
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Link(destination: NoumWebURLs.privacy) {
                        Label("Read privacy policy", systemImage: "arrow.up.right.square")
                            .font(Typography.body.weight(.semibold))
                            .foregroundStyle(AppColor.brandBlue)
                            .frame(minHeight: 44)
                    }
                    .accessibilityHint("Opens Noum's privacy policy in your browser.")

                    VStack(spacing: Spacing.sm) {
                        PrimaryCTA("Allow", icon: "checkmark.shield.fill", action: onAllow)
                            .accessibilityHint("Allows the cloud processing described above for this account.")
                            .accessibilityIdentifier("cloudProcessing.allow")

                        Button(isCurrentlyAllowed ? "Revoke permission" : "Not now") {
                            onNotNow()
                        }
                        .font(Typography.body.weight(.semibold))
                        .foregroundStyle(isCurrentlyAllowed ? AppColor.warning : AppColor.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .buttonStyle(.pressable)
                        .accessibilityHint("Keeps cloud processing off and uses local or deterministic behavior where available.")
                        .accessibilityIdentifier("cloudProcessing.notNow")
                    }
                }
                .padding(Spacing.lg)
            }
            .background(AppColor.screenBackground)
            .navigationTitle("Cloud processing")
            .navigationBarTitleDisplayMode(.inline)
            .accessibilityIdentifier("cloudProcessing.disclosure")
        }
    }

    private func disclosureRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(AppColor.brandBlue)
                .frame(width: 28)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(Typography.body.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(detail)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Delete Account Confirmation Sheet

enum AccountDeletionConfirmationPresentation: Equatable {
    case confirmation
    case localCleanup
    case supportOnly

    static func resolve(
        after error: AccountDeletionError?
    ) -> AccountDeletionConfirmationPresentation {
        guard let error else { return .confirmation }
        switch error {
        case .localCleanupFailed:
            return .localCleanup
        case .completionUncertain, .completionUncertainRequiresReauthentication:
            return .supportOnly
        default:
            return .confirmation
        }
    }

    static func initialError(
        from state: AccountDeletionState
    ) -> AccountDeletionError? {
        guard case .failed(let error) = state else { return nil }
        return error
    }

    var allowsDestructiveConfirmation: Bool {
        self != .supportOnly
    }

    var requiresTypedConfirmation: Bool {
        self == .confirmation
    }

    func actionIsEnabled(matchesRequiredPhrase: Bool) -> Bool {
        switch self {
        case .confirmation:
            return matchesRequiredPhrase
        case .localCleanup:
            return true
        case .supportOnly:
            return false
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .confirmation: return "Delete account"
        case .localCleanup: return "Finish device cleanup"
        case .supportOnly: return ""
        }
    }

    var workingActionTitle: String {
        switch self {
        case .confirmation: return "Deleting…"
        case .localCleanup: return "Finishing cleanup…"
        case .supportOnly: return ""
        }
    }

    var primaryActionAccessibilityHint: String {
        switch self {
        case .confirmation:
            return "Permanently deletes your account."
        case .localCleanup:
            return "Finishes clearing account data from this device without sending another remote deletion request."
        case .supportOnly:
            return ""
        }
    }

    var dismissButtonTitle: String {
        switch self {
        case .confirmation, .localCleanup: return "Cancel"
        case .supportOnly: return "Close"
        }
    }

    var dismissAccessibilityHint: String {
        switch self {
        case .confirmation:
            return "Closes this sheet without deleting your account."
        case .localCleanup:
            return "Closes this sheet without finishing device cleanup."
        case .supportOnly:
            return "Closes this unresolved deletion status. Contact deletion support before signing in or creating another account."
        }
    }
}

@available(iOS 17.0, macOS 12.0, *)
private struct DeleteAccountConfirmationSheet: View {
    let isOnDeviceGuest: Bool
    let supportURLProvider: () -> URL
    let onConfirm: () async throws -> Void
    let onClose: () -> Void
    let onReauthenticate: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typedConfirmation: String = ""
    @State private var isDeleting = false
    @State private var deletionError: AccountDeletionError?
    @FocusState private var fieldFocused: Bool

    private let requiredPhrase = "delete"

    private var matchesPhrase: Bool {
        typedConfirmation == requiredPhrase
    }

    private var presentation: AccountDeletionConfirmationPresentation {
        .resolve(after: deletionError)
    }

    private var actionIsEnabled: Bool {
        presentation.actionIsEnabled(matchesRequiredPhrase: matchesPhrase)
    }

    init(
        isOnDeviceGuest: Bool = false,
        initialError: AccountDeletionError? = nil,
        supportURLProvider: @escaping () -> URL = {
            NoumWebURLs.supportMail
        },
        onConfirm: @escaping () async throws -> Void,
        onClose: @escaping () -> Void,
        onReauthenticate: @escaping () -> Void
    ) {
        self.isOnDeviceGuest = isOnDeviceGuest
        self.supportURLProvider = supportURLProvider
        self.onConfirm = onConfirm
        self.onClose = onClose
        self.onReauthenticate = onReauthenticate
        _deletionError = State(initialValue: initialError)
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColor.warning)
                    Text("Delete account")
                        .font(Typography.bigStat)
                    Text(
                        isOnDeviceGuest
                            ? "This permanently removes this on-device guest and its account-scoped practice history and coaching data from this device. This guest does not have a Firebase-backed Noum account. You can't undo a completed deletion."
                            : "This permanently removes your account, account-scoped practice history, coaching data, and active cloud records. Noum keeps a content-free deletion-security record with account and request identifiers, status, and timestamps as a temporary write fence; automatic cleanup and server reconciliation manage that record. You can't undo a completed deletion."
                    )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label("Deleting Noum does not cancel an App Store subscription.", systemImage: "creditcard.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Link("Manage App Store subscriptions", destination: NoumWebURLs.manageSubscriptions)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(minHeight: 44)
                    Link("Contact deletion support", destination: supportURLProvider())
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(minHeight: 44)
                        .accessibilityHint("Opens an email to \(NoumWebURLs.supportEmail).")
                    if !isOnDeviceGuest {
                        Text("For Sign in with Apple, Noum will stop before deleting anything unless its Apple authorization can also be revoked safely.")
                            .font(.caption)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let deletionError {
                    ErrorCard(message: deletionError.localizedDescription)
                        .accessibilityIdentifier("accountDeletion.error")
                    if deletionError.requiresReauthentication {
                        Button("Sign in again") {
                            onReauthenticate()
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .buttonStyle(.pressable)
                    }
                }

                if presentation.requiresTypedConfirmation {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Type delete to confirm")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        TextField("delete", text: $typedConfirmation)
                            .font(.title3.weight(.semibold))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .focused($fieldFocused)
                            .padding(Spacing.md)
                            .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                                    .stroke(matchesPhrase ? AppColor.warning : Color.black.opacity(0.05), lineWidth: 1)
                            )
                            .accessibilityLabel("Confirmation text")
                            .accessibilityHint("Type the lowercase word delete to enable deletion.")

                        Text("This step exists so a single tap can't end your account.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(spacing: Spacing.sm) {
                    if presentation.allowsDestructiveConfirmation {
                        Button {
                            guard actionIsEnabled else { return }
                            isDeleting = true
                            Task {
                                do {
                                    try await onConfirm()
                                } catch {
                                    await MainActor.run {
                                        let resolvedError = (error as? AccountDeletionError) ?? .remoteRejected
                                        deletionError = resolvedError
                                        if AccountDeletionConfirmationPresentation.resolve(
                                            after: resolvedError
                                        ) == .supportOnly {
                                            typedConfirmation = ""
                                            fieldFocused = false
                                        }
                                        isDeleting = false
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                if isDeleting {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "trash.fill")
                                }
                                Text(
                                    isDeleting
                                        ? presentation.workingActionTitle
                                        : presentation.primaryActionTitle
                                )
                                    .font(.headline.weight(.semibold))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(
                                (actionIsEnabled ? AppColor.warning : AppColor.warning.opacity(0.4)),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.pressable)
                        .disabled(!actionIsEnabled || isDeleting)
                        .accessibilityLabel(presentation.primaryActionTitle)
                        .accessibilityHint(
                            actionIsEnabled
                                ? (isOnDeviceGuest && presentation == .confirmation
                                    ? "Permanently deletes this on-device guest and its local practice data."
                                    : presentation.primaryActionAccessibilityHint)
                                : "Type delete first to enable."
                        )
                    }

                    Button(presentation.dismissButtonTitle) {
                        onClose()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .disabled(isDeleting)
                    .accessibilityLabel(presentation.dismissButtonTitle)
                    .accessibilityHint(presentation.dismissAccessibilityHint)
                }
            }
            .padding(Spacing.lg)

            if isDeleting {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .allowsHitTesting(true)

                VStack(spacing: Spacing.md) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text(
                        presentation == .localCleanup
                            ? "Finishing device cleanup…"
                            : (isOnDeviceGuest
                                ? "Removing this on-device guest…"
                                : "Removing your account…")
                    )
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(Spacing.lg)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    presentation == .localCleanup
                        ? "Finishing device cleanup"
                        : (isOnDeviceGuest
                            ? "Removing this on-device guest"
                            : "Removing your account")
                )
            }
        }
        .interactiveDismissDisabled(isDeleting)
        .onAppear {
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { fieldFocused = true }
            } else {
                fieldFocused = true
            }
        }
    }
}

// MARK: - Your Data View (preserved)

@available(iOS 17.0, macOS 12.0, *)
struct YourDataView: View {
    var isBackendConfigured: Bool

    @StateObject private var authManager = AuthManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var friendsManager = FriendsManager.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var coachMemoryStore = CoachMemoryStore.shared
    @State private var showExportSheet = false
    @State private var exportURL: URL?
    @State private var exportError: String?
    @State private var isExporting = false
    @State private var goalMemoryDraft = ""
    @State private var showDeleteMemoryConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Your data")
                    .font(Typography.bigStat)

                Text("Here's what Noum stores and where. You can export the account-scoped local records Noum can identify or request account deletion at any time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                onDeviceSection
                coachingMemorySection
                cloudProcessingSection
                actionsSection
            }
            .padding(Spacing.lg)
        }
        .background(AppColor.screenBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExportSheet, onDismiss: cleanupExport) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
        }
        .alert("Export unavailable", isPresented: exportErrorBinding) {
            Button("OK", role: .cancel) { exportError = nil }
        } message: {
            Text(exportError ?? "Noum couldn't prepare your export.")
        }
        .confirmationDialog(
            "Delete coaching memory?",
            isPresented: $showDeleteMemoryConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete coaching memory", role: .destructive) {
                coachMemoryStore.clearAll()
                goalMemoryDraft = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes Noum's bounded cross-session case file. Your practice sessions and measured progress remain.")
        }
        .onAppear {
            goalMemoryDraft = coachMemoryStore.currentMemory?.statedGoalSummary ?? ""
        }
    }

    private var onDeviceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("On this device")
                .font(.headline)

            dataRow(
                label: "Practice sessions",
                detail: "\(sessionStore.sessions.count) sessions stored locally"
            )
            dataRow(
                label: "Coaching profile",
                detail: coachingProfileStore.profile != nil ? "Active — includes your goals, preferences, and speaking context" : "Not set up"
            )
            dataRow(
                label: "XP & progress",
                detail: "\(profileManager.xp) XP earned"
            )
            dataRow(
                label: "Friends",
                detail: "\(friendsManager.friendCount) saved locally (names and connected-account IDs only — no phone numbers). Secure connection records may also be stored in Firebase when that feature is enabled."
            )
            dataRow(
                label: "Recordings",
                detail: "App-managed fallback recordings are included. Recordings saved to Photos remain in your Photos library and are not included."
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var cloudProcessingSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Cloud processing")
                .font(.headline)

            Text("Permission: \(aiSettings.cloudProcessingStatusTitle). When allowed, account-content sync and cloud features may send the disclosed data to these services:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(CloudProcessorManifest.consentProcessors) { processor in
                processorRow(
                    name: processor.name,
                    purpose: processor.purpose,
                    data: processor.data
                )
            }

            if aiSettings.isCloudProcessingAllowed {
                Button("Revoke cloud-processing permission") {
                    aiSettings.revokeCloudProcessingConsent()
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.warning)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 44)
                .buttonStyle(.pressable)
                .accessibilityHint("Stops future cloud processing for this account. Local and deterministic coaching remains available where supported.")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var coachingMemorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Coaching memory")
                        .font(.headline)
                    Text("Bounded, inspectable context Noum carries between sessions")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(AppColor.brandBlue)
                    .accessibilityHidden(true)
            }

            if let memory = coachMemoryStore.currentMemory {
                Text("Case file updated \(memory.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                dataRow(
                    label: "Observed evidence",
                    detail: "\(memory.evidenceCount) eligible reps · \(memory.evidenceConfidence.label) confidence"
                )
                dataRow(
                    label: "Current training lever",
                    detail: memory.currentLever.map {
                        "\($0.displayName) · \(memory.currentLeverConfidence?.rawValue ?? "forming") confidence"
                    } ?? "Waiting for enough evidence"
                )
                if let basis = memory.currentLeverBasis,
                   !basis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    dataRow(label: "Lever provenance", detail: "Observed-session analysis · \(basis)")
                }

                Divider()

                VStack(alignment: .leading, spacing: 6) {
                    Text("Your stated goal")
                        .font(.subheadline.weight(.semibold))
                    Text("User-authored · direct provenance · updated \(memory.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppColor.positive)
                    TextField("What should your communication help you do?", text: $goalMemoryDraft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                        .accessibilityIdentifier("yourData.coachMemory.goal")
                    Button("Save goal memory") {
                        coachMemoryStore.updateStatedGoalSummary(goalMemoryDraft)
                        goalMemoryDraft = coachMemoryStore.currentMemory?.statedGoalSummary ?? ""
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(minHeight: 44, alignment: .leading)
                    .buttonStyle(.pressable)
                    .accessibilityHint("Changes only the goal statement carried into coaching, not measured evidence.")
                }

                if let hypothesis = memory.workingHypothesis,
                   !hypothesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let acknowledgement = memory.hypothesisAcknowledgement.flatMap {
                        $0.appliesTo(currentHypothesis: memory.workingHypothesis) ? $0 : nil
                    }
                    let hypothesisDate = acknowledgement?.acknowledgedAt ??
                        memory.hypothesisWatchStartedAt ?? memory.updatedAt
                    Divider()
                    removableMemoryRow(
                        title: "Coach hypothesis",
                        provenance: "Coach interpretation · \(acknowledgement?.confidence.rawValue ?? "unconfirmed") · \(hypothesisDate.formatted(date: .abbreviated, time: .omitted)) · confirmable",
                        value: hypothesis,
                        removeLabel: "Remove hypothesis"
                    ) {
                        coachMemoryStore.removeWorkingHypothesis()
                    }
                }

                if let reflection = memory.lastReflectionSummary,
                   !reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider()
                    removableMemoryRow(
                        title: "Latest reflection carried forward",
                        provenance: "User report · self-reported confidence · case updated \(memory.updatedAt.formatted(date: .abbreviated, time: .omitted)) · removable",
                        value: reflection,
                        removeLabel: "Stop carrying reflection"
                    ) {
                        coachMemoryStore.removeCarriedReflection()
                    }
                }

                Divider()
                Button(role: .destructive) {
                    showDeleteMemoryConfirmation = true
                } label: {
                    Label("Delete coaching memory", systemImage: "trash")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .buttonStyle(.pressable)
                .accessibilityHint("Deletes cross-session coach context while preserving practice sessions and measured progress.")
                .accessibilityIdentifier("yourData.coachMemory.delete")
            } else {
                Text("No cross-session coaching memory is stored. Noum builds one only from eligible practice evidence and information you choose to share.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .accessibilityIdentifier("yourData.coachMemory")
    }

    private func removableMemoryRow(
        title: String,
        provenance: String,
        value: String,
        removeLabel: String,
        remove: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(provenance)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(removeLabel, role: .destructive, action: remove)
                .font(.caption.weight(.semibold))
                .frame(minHeight: 44, alignment: .leading)
                .buttonStyle(.pressable)
        }
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Data actions")
                .font(.headline)

            Button {
                exportData()
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.up")
                    }
                    Text(isExporting ? "Preparing export…" : "Export account data")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(AppColor.brandBlue, in: Capsule())
            }
            .buttonStyle(.pressable)
            .disabled(isExporting)
            .accessibilityHint("Creates a ZIP archive without Keychain credentials or provider tokens.")

            Text("Creates Noum-export-YYYY-MM-DD.zip with versioned JSON for every registered account-data owner and any app-managed fallback recordings. Keychain credentials, Photos-library recordings, and provider-held data are not included. Legacy device-wide records are labelled as unattributed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private func dataRow(label: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.subheadline.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func processorRow(name: String, purpose: String, data: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(name)
                .font(.subheadline.weight(.semibold))
            Text(purpose)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("Data sent: \(data)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var exportErrorBinding: Binding<Bool> {
        Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )
    }

    private func exportData() {
        guard !isExporting else { return }
        isExporting = true
        exportError = nil
        Task { @MainActor in
            do {
                let url = try await authManager.exportCurrentAccountData()
                exportURL = url
                showExportSheet = true
            } catch {
                exportError = (error as? LocalizedError)?.errorDescription
                    ?? "Noum couldn't prepare your export. Nothing was shared. Try again."
            }
            isExporting = false
        }
    }

    private func cleanupExport() {
        authManager.cleanupAccountDataExport(at: exportURL)
        exportURL = nil
    }
}

struct SettingsProfileHeroPresentation: Equatable {
    let subtitle: String
    let subtitleIcon: String
    let accessibilityLabel: String

    static func make(
        displayName: String,
        chosenVoice: SpeakingStyleGoal?,
        xp: Int
    ) -> SettingsProfileHeroPresentation {
        let practiceLevel = PracticeVolumeNarration.title(forXP: xp)
        guard let chosenVoice else {
            return SettingsProfileHeroPresentation(
                subtitle: practiceLevel,
                subtitleIcon: "chart.bar.fill",
                accessibilityLabel: "\(displayName), \(practiceLevel)"
            )
        }

        return SettingsProfileHeroPresentation(
            subtitle: "Voice target: \(chosenVoice.title)",
            subtitleIcon: chosenVoice.voiceIconSystemName,
            accessibilityLabel: "\(displayName), voice target \(chosenVoice.title), \(practiceLevel)"
        )
    }
}

@available(iOS 17.0, *)
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, *)
#Preview("Settings — default") {
    NavigationStack {
        SettingsView()
    }
}

@available(iOS 17.0, *)
#Preview("Settings — Free tier") {
    NavigationStack {
        SettingsView()
    }
    .onAppear { PremiumManager.shared.revokePremium() }
}

@available(iOS 17.0, *)
#Preview("Settings — Pro tier") {
    NavigationStack {
        SettingsView()
    }
    .onAppear { PremiumManager.shared.upgradeToPremium() }
}

@available(iOS 17.0, *)
#Preview("Delete confirmation") {
    Color.clear.sheet(isPresented: .constant(true)) {
        DeleteAccountConfirmationSheet(
            onConfirm: {},
            onClose: {},
            onReauthenticate: {}
        )
        .presentationDetents([.large])
    }
}
#endif

#endif
