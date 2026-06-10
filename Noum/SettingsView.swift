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

@available(iOS 17.0, macOS 12.0, *)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
    @State private var showSoundscape = false
    @State private var showSignOutAlert = false
    @State private var showDeleteSheet = false
    @State private var debugMessage: String?
    @State private var supportToast: String?
    @State private var microphonePermission: MicrophonePermissionState = .unknown
    #if DEBUG
    @State private var seedProfileStatus: String?
    #endif

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    // M16 settings trim — first-open overwhelm was real
                    // (20+ control rows packed across 10 cards). Top level
                    // now surfaces 1 hero + 4 cluster zones + 1 advanced
                    // disclosure. Every existing setting still reaches the
                    // user; power-user toggles + dev tools live behind one
                    // tap. Mirrors the Profile clustering at
                    // `ProfileView.swift:113`.
                    //
                    //   Identity (no header — implicit hero)
                    //     • profileHero
                    //
                    //   Practice (the act of speaking)
                    //     • practiceCard (difficulty + 3 toggles),
                    //       dailyGoalCard, localeCard, soundscapeCard,
                    //       coachingProfileCard
                    //
                    //   Notifications (the coaching nudges)
                    //     • feedbackCard (4 notifs + haptics + interaction sounds)
                    //
                    //   Account (the user as customer)
                    //     • subscriptionCard, privacyCard, accountCard
                    //
                    //   About — trailing meta band, no header
                    //
                    //   Advanced (collapsed) — escape hatch + dev tools
                    //     for `isDeveloper` only
                    profileHero

                    clusterHeader("Practice")
                    section(label: "Defaults") { practiceCard }
                    section(label: "Daily goal") { dailyGoalCard }
                    section(label: "Coaching profile") { coachingProfileCard }
                    section(label: "Language") { localeCard }
                    section(label: "Pre-rep ambience") { soundscapeCard }

                    clusterHeader("Notifications")
                    section(label: "Reminders") { feedbackCard }

                    clusterHeader("Account")
                    section(label: "Subscription") { subscriptionCard }
                    section(label: "Privacy & data") { privacyCard }
                    section(label: "Sign-in") { accountCard }

                    section(label: "About") { aboutCard }

                    advancedDisclosure

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.screen")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
                    .accessibilityHint("Close settings")
            }
        }
        .onChange(of: authManager.isSignedIn) { _, signedIn in
            if !signedIn { dismiss() }
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
        .sheet(isPresented: $showSoundscape) {
            SoundscapePickerView()
        }
        .sheet(isPresented: $showLocalePicker) {
            PracticeLocalePickerSheet()
        }
        .sheet(isPresented: $showDeleteSheet) {
            DeleteAccountConfirmationSheet(
                onConfirm: {
                    authManager.deleteCurrentAccount()
                },
                onClose: {
                    showDeleteSheet = false
                }
            )
            .presentationDetents([.medium, .large])
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
            .accessibilityIdentifier("settings.advancedToggle")

            if advancedExpanded {
                if aiUsageCardIsVisible {
                    section(label: "AI usage") { aiUsageCard }
                }

                if authManager.isDeveloper {
                    section(label: "Home reveal") { advancedHomeCard }
                    section(label: "Developer tools") { transcriptionProviderCard }
                    section(label: "Diagnostics") { recommendationDiagnosticsCard }
                    section(label: "Seed data") { developerSeedCard }
                }
            }
        }
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
        let name = authManager.currentAccountName?.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? "Speaker" : name
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
                // M14 dream pass: replaces the letter avatar with the
                // shared NoumCharacter (same component Profile uses) so the
                // hero carries brand presence instead of a generic monogram.
                // Compact 56pt size since Settings' hero is a row, not a
                // full hero card. Pro users render against the purple tint
                // so the character + ambient background read as one register.
                NoumCharacter(
                    mood: .calm,
                    tint: profileHeroTint,
                    size: 56
                )
                .accessibilityHidden(true)

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

                    // Practice volume, not identity (progression spine):
                    // XP never wears a skill costume — "Practice level N"
                    // is the only permitted title shape for the XP ledger.
                    HStack(spacing: 6) {
                        Image(systemName: "chart.bar.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColor.brandBlue)
                        Text(PracticeVolumeNarration.title(forXP: profileManager.xp))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColor.brandBlue)
                    }
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, 5)
                    .background(AppColor.brandBlue.opacity(0.12), in: Capsule())
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
        .accessibilityLabel("\(displayName), \(PracticeVolumeNarration.title(forXP: profileManager.xp))")
        .accessibilityHint("Open coaching profile to edit")
        .accessibilityIdentifier("settings.profileHero")
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

    private var practiceCard: some View {
        cardContainer(spacing: Spacing.md) {
            VStack(spacing: Spacing.xs) {
                ForEach(TimedPracticeDifficulty.allCases) { difficulty in
                    difficultyOption(difficulty)
                }
            }

            Divider()

            SettingsToggleRow(
                title: "Voice cues",
                subtitle: "Read replies aloud during IM practice.",
                isOn: $imVoicePlaybackSettings.isEnabled,
                accessibilityHint: "Enables spoken responses in IM mode."
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

    private var dailyGoalCard: some View {
        cardContainer(spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                ForEach(dailyGoal.minGoalReps...dailyGoal.maxGoalReps, id: \.self) { value in
                    goalChip(value)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func goalChip(_ value: Int) -> some View {
        let isSelected = dailyGoal.goalReps == value
        return Button {
            dailyGoal.goalReps = value
            CoachHaptic.selectionTap()
        } label: {
            Text("\(value) rep\(value == 1 ? "" : "s")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .white : AppColor.brandBlue)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(
                    isSelected ? AppColor.brandBlue : AppColor.brandBlue.opacity(0.10),
                    in: Capsule()
                )
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.selection, trigger: isSelected) { _, _ in hapticsSettings.isEnabled }
        .accessibilityLabel("Daily goal \(value) rep\(value == 1 ? "" : "s")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var micDisabledForFillerHighlight: Bool {
        microphonePermission == .denied
    }

    private func difficultyOption(_ difficulty: TimedPracticeDifficulty) -> some View {
        let isSelected = practiceSettings.timedDifficulty == difficulty
        return Button {
            practiceSettings.timedDifficulty = difficulty
        } label: {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(difficulty.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(difficulty.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Spacing.xs)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AppColor.brandBlue : .secondary)
            }
            .frame(minHeight: 44)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            .background(
                AppColor.brandBlue.opacity(isSelected ? 0.10 : 0.04),
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.selection, trigger: isSelected) { _, _ in hapticsSettings.isEnabled }
        .accessibilityLabel("\(difficulty.title) difficulty")
        .accessibilityHint(difficulty.subtitle)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
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
        cardContainer(spacing: Spacing.md) {
            if let profile = coachingProfileStore.profile {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Spacing.xs) {
                    coachingTag(label: "Context", value: profile.speakingContext.title)
                    coachingTag(label: "Priority", value: profile.primaryGoal.title)
                    coachingTag(label: "Challenge", value: profile.biggestChallenge.title)
                    coachingTag(label: "Voice", value: profile.speakingStyleGoal.title)
                }
                if !profile.personalGoalReference.isEmpty {
                    Text(profile.personalGoalReference)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                }
            } else {
                Text("Set a coaching profile so Noum can tailor drills to your goals.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            SettingsNavRow(
                title: coachingProfileStore.profile == nil ? "Set coaching profile" : "Update coaching profile",
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

    private func coachingTag(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
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

    // MARK: - Feedback Card (Reminders + Haptics)

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
        .labelsHidden()
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, Spacing.xs)
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
            Text("Your coach note keeps coming after every rep. When the AI polish layer hits its budget for the day, the coach reads rule-based for the rest of the day — same content shape, just less personalised wording.")
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
                accessibilityHint: "Daily budget for AI-polished coach notes."
            )

            Divider()

            aiUsageRow(
                title: "Session debriefs",
                used: debriefUsed,
                cap: debriefCap,
                remaining: debriefRemaining,
                reachedLimit: aiSettings.hasReachedLimit,
                resetCopy: "Resets \(aiSettings.resetDateFormatted)",
                accessibilityHint: "Monthly budget for AI session debriefs."
            )

            if !premium.isPremium {
                Divider()
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "crown.fill")
                            .font(.subheadline.weight(.semibold))
                        Text("Pro gets \(AIRateLimiter.premiumDailyCap)/day · \(AISettingsManager.premiumMonthlyDebriefLimit)/month")
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
                SettingsStatusRow(
                    title: "Signed in as",
                    value: displayName,
                    valueTint: .primary
                )
                if let provider = authManager.currentAuthProviderTitle {
                    SettingsStatusRow(
                        title: "Provider",
                        value: provider,
                        valueTint: .secondary
                    )
                }

                Divider()

                Button {
                    showSignOutAlert = true
                } label: {
                    accountActionLabel(title: "Sign out", tint: AppColor.warning, icon: "arrow.right.square")
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Sign out")
                .accessibilityHint("Signs you out on this device. Your data stays on your account.")

                Button {
                    showDeleteSheet = true
                } label: {
                    accountActionLabel(title: "Delete account", tint: AppColor.warning, icon: "trash.fill")
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Delete account")
                .accessibilityHint("Permanently deletes your account and all data after a typed confirmation.")
            } else {
                SettingsStatusRow(
                    title: "Status",
                    value: "Signed out",
                    valueTint: .secondary
                )
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
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
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
            .padding(Spacing.lg)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
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
                Text("IM voice quality")
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
                compactStat(title: "Filler Δ", value: averageFillerDelta.map { signedValue($0) } ?? "—")
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
        recommendationLearningStore.outcomes.filter(\.followed).count
    }

    private var followRate: Double {
        guard !recommendationLearningStore.outcomes.isEmpty else { return 0 }
        return Double(followedRecommendationCount) / Double(recommendationLearningStore.outcomes.count)
    }

    private var averageScoreDelta: Double? {
        let measured = followedOutcomes
            .filter { $0.hasComparableScore == true }
            .map(\.scoreDelta)
        guard !measured.isEmpty else { return nil }
        return measured.reduce(0, +) / Double(measured.count)
    }

    private var averageFillerDelta: Double? {
        averageMetric(for: \.fillerDelta)
    }

    private var averageDurationDelta: Double? {
        averageMetric(for: \.durationDelta)
    }

    private func averageMetric(for keyPath: KeyPath<RecommendationOutcome, Double>) -> Double? {
        guard !followedOutcomes.isEmpty else { return nil }
        let values = followedOutcomes.map { $0[keyPath: keyPath] }
        return values.reduce(0, +) / Double(values.count)
    }

    private var followedOutcomes: [RecommendationOutcome] {
        recommendationLearningStore.outcomes.filter(\.followed)
    }

    private func signedValue(_ value: Double) -> String {
        let rounded = Int((value * 10).rounded() / 10)
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
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

// MARK: - Delete Account Confirmation Sheet

@available(iOS 17.0, macOS 12.0, *)
private struct DeleteAccountConfirmationSheet: View {
    let onConfirm: () -> Void
    let onClose: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var typedConfirmation: String = ""
    @State private var isDeleting = false
    @FocusState private var fieldFocused: Bool

    private let requiredPhrase = "delete"

    private var matchesPhrase: Bool {
        typedConfirmation == requiredPhrase
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
                    Text("This permanently removes your account and every session, coaching detail, and AI history tied to it. You can't undo this.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

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

                Spacer()

                VStack(spacing: Spacing.sm) {
                    Button {
                        guard matchesPhrase else { return }
                        isDeleting = true
                        // Hold the deletion overlay for 1.5s after firing so the
                        // user can't dismiss before the auth state flips.
                        Task {
                            onConfirm()
                            try? await Task.sleep(for: .seconds(1.5))
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            if isDeleting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                            }
                            Text(isDeleting ? "Deleting…" : "Delete account")
                                .font(.headline.weight(.semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.md)
                        .background(
                            (matchesPhrase ? AppColor.warning : AppColor.warning.opacity(0.4)),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(.pressable)
                    .disabled(!matchesPhrase || isDeleting)
                    .accessibilityLabel("Confirm delete account")
                    .accessibilityHint(matchesPhrase ? "Permanently deletes your account." : "Type delete first to enable.")

                    Button("Cancel") {
                        onClose()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .disabled(isDeleting)
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
                    Text("Removing your account…")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(Spacing.lg)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Removing your account")
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

    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var friendsManager = FriendsManager.shared
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Your data")
                    .font(Typography.bigStat)

                Text("Here's what Noum stores and where. Your data is yours — you can export or delete it at any time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                onDeviceSection
                cloudProcessingSection
                actionsSection
            }
            .padding(Spacing.lg)
        }
        .background(AppColor.screenBackground)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExportSheet) {
            if let exportURL {
                ShareSheet(activityItems: [exportURL])
            }
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
                detail: "\(friendsManager.friendCount) friends (names only — no phone numbers)"
            )
            dataRow(
                label: "Recordings",
                detail: "Saved to your Photos library (not stored by Noum)"
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

            Text("When you use certain features, data is sent to these services:")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            processorRow(
                name: "AWS Transcribe",
                purpose: "Real-time speech-to-text during practice sessions",
                data: "Audio stream (not stored after transcription)"
            )
            processorRow(
                name: "Google Gemini / OpenAI",
                purpose: "AI coaching analysis (Coach Read)",
                data: "Speech transcript sent for analysis (not used to train AI models)"
            )
            processorRow(
                name: "Google Cloud TTS",
                purpose: "Voice playback for prompts and coaching",
                data: "Text sent for speech synthesis"
            )
            if isBackendConfigured {
                processorRow(
                    name: "Noum Backend / Firebase",
                    purpose: "Syncing sessions and profile across devices",
                    data: "Practice sessions, coaching profile, progress"
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Data actions")
                .font(.headline)

            Button {
                exportData()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export all my data")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .background(AppColor.brandBlue, in: Capsule())
            }
            .buttonStyle(.pressable)

            Text("Exports a JSON file containing all your locally stored data — sessions, coaching profile, preferences, and progress.")
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

    private func exportData() {
        let accountID = AuthManager.shared.currentAccountID ?? "guest"
        let defaults = UserDefaults.standard

        var export: [String: Any] = [
            "exportDate": ISO8601DateFormatter().string(from: Date()),
            "accountID": accountID,
        ]

        if let data = defaults.data(forKey: "coachingProfile.\(accountID)"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["coachingProfile"] = json
        }
        if let data = defaults.data(forKey: "practiceSessions.\(accountID)"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["practiceSessions"] = json
        }
        if let data = defaults.data(forKey: "imRelationshipProfiles.\(accountID)"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["relationshipProfiles"] = json
        }
        if let data = defaults.data(forKey: "recommendation.pending.\(accountID)"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["recommendationPending"] = json
        }
        if let data = defaults.data(forKey: "recommendation.outcomes.\(accountID)"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["recommendationOutcomes"] = json
        }
        export["xp"] = defaults.integer(forKey: "profileXP.\(accountID)")
        if let data = defaults.data(forKey: "NoumFriendsList"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["friends"] = json
        }

        guard let jsonData = try? JSONSerialization.data(
            withJSONObject: export,
            options: [.prettyPrinted, .sortedKeys]
        ) else { return }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("noum-data-export.json")
        try? jsonData.write(to: fileURL)
        exportURL = fileURL
        showExportSheet = true
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
        DeleteAccountConfirmationSheet(onConfirm: {}, onClose: {})
            .presentationDetents([.medium, .large])
    }
}
#endif

#endif
