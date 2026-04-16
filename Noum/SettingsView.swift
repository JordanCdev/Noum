#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

@available(iOS 17.0, macOS 12.0, *)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var practiceSettings = PracticeSettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var recommendationLearningStore = RecommendationLearningStore.shared
    @StateObject private var imVoicePlaybackSettings = IMVoicePlaybackSettingsManager.shared
    @StateObject private var notificationManager = NotificationManager.shared
    @StateObject private var premium = PremiumManager.shared
    @State private var isBackendConfigured = false
    @State private var showCoachingProfile = false
    @State private var showPaywall = false
    @State private var debugMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var showYourData = false

    var body: some View {
        ZStack {
            AppColor.screenBackground
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    overviewCard
                    subscriptionCard
                    practiceCard
                    coachingCard
                    remindersCard
                    accountPrivacyCard
                    if authManager.isDeveloper {
                        transcriptionProviderCard
                        debugCard
                        recommendationDiagnosticsCard
                    }
                    Spacer(minLength: 0)
                }
                .padding(Spacing.lg)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.screen")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .onChange(of: authManager.isSignedIn) { _, signedIn in
            if !signedIn { dismiss() }
        }
        .task {
            isBackendConfigured = await BackendSyncManager.shared.isConfigured
        }
        .sheet(isPresented: $showCoachingProfile) {
            CoachingOnboardingView()
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
        .alert("Debug Tools", isPresented: .constant(debugMessage != nil), actions: {
            Button("OK", role: .cancel) { debugMessage = nil }
        }, message: {
            Text(debugMessage ?? "")
        })
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Delete Everything", role: .destructive) {
                authManager.deleteCurrentAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account and all associated data, including practice sessions, coaching profile, AI analysis history, and any synced data on our servers. This cannot be undone.")
        }
    }

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Settings")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            Text("Manage practice defaults, coaching preferences, and your account in one place.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private let proColor = AppColor.pro

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            if premium.isPremium {
                // Active subscriber card
                HStack(spacing: 14) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [proColor, AppColor.proLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Noum Pro")
                                .font(.headline.weight(.bold))
                            Text("ACTIVE")
                                .font(.caption2.weight(.heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(proColor, in: Capsule())
                        }
                        Text("All premium features are unlocked.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Divider()
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 10) {
                    subscriptionFeatureRow(icon: "text.magnifyingglass", title: "Coach Mode")
                    subscriptionFeatureRow(icon: "text.quote", title: "Live Transcript")
                    subscriptionFeatureRow(icon: "video.fill", title: "Video Recording")
                    subscriptionFeatureRow(icon: "waveform.badge.magnifyingglass", title: "Filler Tracking")
                    subscriptionFeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Trends & Analytics")
                    subscriptionFeatureRow(icon: "person.2.wave.2.fill", title: "Unlimited Async Challenges")
                    subscriptionFeatureRow(icon: "tray.full.fill", title: "Saved Transcripts")
                }

                if authManager.isDeveloper {
                    Divider()
                        .padding(.vertical, 2)

                    Button("Revoke Premium (Debug)") {
                        premium.revokePremium()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.red)
                }
            } else {
                // Free user — upgrade CTA
                HStack(spacing: 14) {
                    Image(systemName: "crown.fill")
                        .font(.title2)
                        .foregroundStyle(proColor.opacity(0.6))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Upgrade to Pro")
                            .font(.headline.weight(.bold))
                        Text("Unlock Coach Mode, transcripts, analytics, and more.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }

                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.subheadline)
                        Text("See Plans")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(
                        LinearGradient(
                            colors: [proColor, proColor.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                    .shadow(color: proColor.opacity(0.3), radius: 12, y: 4)
                }
                .buttonStyle(.pressable)

                Button("Restore Purchase") {
                    Task { await premium.restorePurchases() }
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .overlay(
            premium.isPremium
                ? RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(proColor.opacity(0.15), lineWidth: 1)
                : nil
        )
    }

    private func subscriptionFeatureRow(icon: String, title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(proColor)
                .frame(width: 24, height: 24)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
        }
    }

    private var practiceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Practice")
                .font(.headline)

            Text("Choose the default timed drill difficulty.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(TimedPracticeDifficulty.allCases) { difficulty in
                Button {
                    practiceSettings.timedDifficulty = difficulty
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(difficulty.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(difficulty.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: practiceSettings.timedDifficulty == difficulty ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(practiceSettings.timedDifficulty == difficulty ? .blue : .secondary)
                    }
                    .padding(14)
                    .background(Color.blue.opacity(practiceSettings.timedDifficulty == difficulty ? 0.10 : 0.04), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            Divider()
                .padding(.vertical, 2)

            Toggle(isOn: $imVoicePlaybackSettings.isEnabled) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Read IM messages aloud")
                        .font(.subheadline.weight(.semibold))
                    Text("Noum reads NPC replies out loud during IM Mode. Enabled by default.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            if imVoicePlaybackSettings.isEnabled && authManager.isDeveloper {
                Divider()
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 10) {
                    Text("IM voice quality")
                        .font(.subheadline.weight(.semibold))

                    Text("Keep voice dependable. Noum now prioritizes Google Cloud first and quietly falls back to OpenAI if needed.")
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
                                    .foregroundStyle(imVoicePlaybackSettings.engine == engine ? .blue : .secondary)
                            }
                            .padding(14)
                            .background(Color.blue.opacity(imVoicePlaybackSettings.engine == engine ? 0.10 : 0.04), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Voice Debug")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("Selected: \(imVoicePlaybackSettings.engine.title)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Resolved: \(imVoicePlaybackSettings.lastResolvedEngineTitle)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Status: \(imVoicePlaybackSettings.lastPlaybackStatus)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let lastPlaybackError = imVoicePlaybackSettings.lastPlaybackError {
                            Text("Last error: \(lastPlaybackError)")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var coachingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Coaching Profile")
                .font(.headline)

            if let profile = coachingProfileStore.profile {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    compactTag(title: "Context", value: profile.speakingContext.title)
                    compactTag(title: "Priority", value: profile.primaryGoal.title)
                    compactTag(title: "Challenge", value: profile.biggestChallenge.title)
                    compactTag(title: "Voice", value: profile.speakingStyleGoal.title)
                }
                if !profile.personalGoalReference.isEmpty {
                    Text(profile.personalGoalReference)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(14)
                        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                }
                if !profile.whyNowReference.isEmpty || !profile.successVisionReference.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        if !profile.whyNowReference.isEmpty {
                            compactTag(title: "Why now", value: profile.whyNowReference)
                        }
                        if !profile.successVisionReference.isEmpty {
                            compactTag(title: "What success changes", value: profile.successVisionReference)
                        }
                    }
                }
            } else {
                Text("Complete your coaching profile so Noum can tailor drills and guidance to your goals.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            compactTag(title: "AI coach", value: aiSettings.activeProvider == nil ? "Not configured" : "Ready")

            Button(coachingProfileStore.profile == nil ? "Set Coaching Profile" : "Update Coaching Profile") {
                showCoachingProfile = true
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Color.blue, in: Capsule())
            .foregroundStyle(.white)
            .buttonStyle(.pressable)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Practice Reminders")
                .font(.headline)

            Text("Set reminders that keep your practice habit consistent and goal-aligned.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Toggle(
                isOn: Binding(
                    get: { notificationManager.isEnabled },
                    set: { newValue in
                        Task { await notificationManager.updateEnabled(newValue) }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Goal-based follow-ups")
                        .font(.subheadline.weight(.semibold))
                    Text("Send a single follow-up based on the north star, why now, and the next best move.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            compactTag(title: "Notification access", value: notificationManager.authorizationLabel)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var accountPrivacyCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account & Privacy")
                .font(.headline)

            if authManager.isSignedIn {
                compactTag(title: "Signed in as", value: authManager.currentAccountName ?? "Guest Speaker")
                if let provider = authManager.currentAuthProviderTitle {
                    compactTag(title: "Provider", value: provider)
                }
                if let accountID = authManager.currentAccountID {
                    Button {
                        #if canImport(UIKit)
                        UIPasteboard.general.string = accountID
                        #elseif canImport(AppKit)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(accountID, forType: .string)
                        #endif
                        debugMessage = "Account ID copied to clipboard."
                    } label: {
                        compactTag(title: "Account ID (tap to copy)", value: accountID)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                compactTag(title: "Status", value: "Signed out")
            }

            Text("Use log out to disconnect this device, or delete the current account if you want to remove it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if authManager.isSignedIn {
                Button {
                    authManager.signOut()
                } label: {
                    actionRow(title: "Log Out", tint: .red)
                }
                .buttonStyle(.plain)

                Button {
                    showDeleteConfirmation = true
                } label: {
                    actionRow(title: "Delete Account", tint: .black)
                }
                .buttonStyle(.plain)

                Button {
                    showYourData = true
                } label: {
                    actionRow(title: "Your Data", tint: .blue)
                }
                .buttonStyle(.plain)
            } else {
                Text("No active session")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    @AppStorage("transcriptionProvider") private var selectedProvider: String = "deepgram"

    private var transcriptionProviderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Transcription Provider")
                .font(.headline)

            Text("Switch between speech-to-text backends for testing and comparison.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Provider", selection: $selectedProvider) {
                ForEach(TranscriptionProviderID.allCases) { provider in
                    Text(provider.displayName).tag(provider.rawValue)
                }
            }
            .pickerStyle(.segmented)

            let qualityStore = TranscriptionQualityStore.shared
            if let avgLatency = qualityStore.averageLatency(for: selectedProvider) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Avg Latency")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text("\(avgLatency)ms")
                            .font(.subheadline.weight(.bold))
                    }
                    Spacer()
                    if let avgConf = qualityStore.averageConfidence(for: selectedProvider) {
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Avg Confidence")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f%%", avgConf * 100))
                                .font(.subheadline.weight(.bold))
                        }
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var debugCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Developer Tools")
                .font(.headline)

            Text("Seed local and Firebase-backed data without recording a live session.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Create Test Session") {
                seedTestSession()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Color.blue, in: Capsule())
            .foregroundStyle(.white)
            .buttonStyle(.pressable)

            Button("Create 3 Session Run") {
                seedSessionRun()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(Color.orange, in: Capsule())
            .foregroundStyle(.white)
            .buttonStyle(.pressable)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var recommendationDiagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recommendation Diagnostics")
                .font(.headline)

            Text("Inspect whether Noum's recommended mode is actually improving outcomes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let pending = recommendationLearningStore.pendingExposure {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Pending Recommendation")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(pending.title)
                        .font(.subheadline.weight(.semibold))
                    Text("Mode: \(label(for: pending.mode)) • \(pending.isAIBacked ? "AI-backed" : "Rules-backed")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }

            HStack(spacing: 10) {
                compactTag(title: "Shown", value: "\(recommendationLearningStore.outcomes.count)")
                compactTag(title: "Followed", value: "\(followedRecommendationCount)")
                compactTag(title: "Hit rate", value: followedRecommendationCount == 0 ? "--" : "\(Int(followRate * 100))%")
            }

            HStack(spacing: 10) {
                compactTag(title: "Score delta", value: signedValue(averageScoreDelta))
                compactTag(title: "Filler delta", value: signedValue(averageFillerDelta))
                compactTag(title: "Duration delta", value: signedSeconds(averageDurationDelta))
            }

            HStack(spacing: 10) {
                compactTag(
                    title: "Storage",
                    value: isBackendConfigured ? "Firebase / backend synced" : "Local only"
                )

                Button("Reset") {
                    recommendationLearningStore.resetDiagnostics()
                    debugMessage = "Recommendation diagnostics reset."
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .foregroundStyle(.red)
            }

            if recommendationLearningStore.outcomes.isEmpty {
                Text("No completed recommendation outcomes yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Recent Outcomes")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    ForEach(recommendationLearningStore.outcomes.prefix(4)) { outcome in
                        recommendationOutcomeRow(outcome)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private func compactTag(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.9)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }

    private func actionRow(title: String, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(tint)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(tint.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(tint.opacity(0.14), lineWidth: 1)
        )
    }

    private func recommendationOutcomeRow(_ outcome: RecommendationOutcome) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(outcome.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(outcome.followed ? "Followed" : "Skipped")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(outcome.followed ? .green : .secondary)
            }
            Text("Mode: \(label(for: outcome.mode)) • Score \(signedValue(outcome.scoreDelta)) • Fillers \(signedValue(outcome.fillerDelta)) • Duration \(signedSeconds(outcome.durationDelta))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }

    private var followedRecommendationCount: Int {
        recommendationLearningStore.outcomes.filter(\.followed).count
    }

    private var followRate: Double {
        guard !recommendationLearningStore.outcomes.isEmpty else { return 0 }
        return Double(followedRecommendationCount) / Double(recommendationLearningStore.outcomes.count)
    }

    private var averageScoreDelta: Double {
        averageMetric(for: \.scoreDelta)
    }

    private var averageFillerDelta: Double {
        averageMetric(for: \.fillerDelta)
    }

    private var averageDurationDelta: Double {
        averageMetric(for: \.durationDelta)
    }

    private func averageMetric(for keyPath: KeyPath<RecommendationOutcome, Double>) -> Double {
        guard !recommendationLearningStore.outcomes.isEmpty else { return 0 }
        let values = recommendationLearningStore.outcomes.map { $0[keyPath: keyPath] }
        return values.reduce(0, +) / Double(values.count)
    }

    private func signedValue(_ value: Double) -> String {
        let rounded = Int((value * 10).rounded() / 10)
        return rounded > 0 ? "+\(rounded)" : "\(rounded)"
    }

    private func signedSeconds(_ value: Double) -> String {
        let rounded = Int(value.rounded())
        return rounded > 0 ? "+\(rounded)s" : "\(rounded)s"
    }

    private func label(for mode: PracticeMode) -> String {
        switch mode {
        case .timed:
            return "Timed"
        case .suddenDeath:
            return "Sudden Death"
        case .ahCounter:
            return "Ah-Counter"
        case .imConversation:
            return "IM Mode"
        }
    }

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

// MARK: - Your Data View

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
            VStack(alignment: .leading, spacing: 18) {
                Text("Your Data")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Here's what Noum stores and where. Your data is yours — you can export or delete it at any time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

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
        VStack(alignment: .leading, spacing: 12) {
            Text("On This Device")
                .font(.headline)

            dataRow(
                label: "Practice Sessions",
                detail: "\(sessionStore.sessions.count) sessions stored locally"
            )
            dataRow(
                label: "Coaching Profile",
                detail: coachingProfileStore.profile != nil ? "Active — includes your goals, preferences, and speaking context" : "Not set up"
            )
            dataRow(
                label: "XP & Progress",
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Cloud Processing")
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Data Actions")
                .font(.headline)

            Button {
                exportData()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export All My Data")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.blue, in: Capsule())
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Text("Exports a JSON file containing all your locally stored data — sessions, coaching profile, preferences, and progress.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

        // Coaching profile
        if let data = defaults.data(forKey: "coachingProfile.\(accountID)"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["coachingProfile"] = json
        }

        // Practice sessions
        if let data = defaults.data(forKey: "practiceSessions.\(accountID)"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["practiceSessions"] = json
        }

        // IM relationship profiles
        if let data = defaults.data(forKey: "imRelationshipProfiles.\(accountID)"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["relationshipProfiles"] = json
        }

        // Recommendations
        if let data = defaults.data(forKey: "recommendation.pending.\(accountID)"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["recommendationPending"] = json
        }
        if let data = defaults.data(forKey: "recommendation.outcomes.\(accountID)"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["recommendationOutcomes"] = json
        }

        // XP
        export["xp"] = defaults.integer(forKey: "profileXP.\(accountID)")

        // Friends
        if let data = defaults.data(forKey: "NoumFriendsList"),
           let json = try? JSONSerialization.jsonObject(with: data) {
            export["friends"] = json
        }

        // Write to temp file
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

/// Minimal UIActivityViewController wrapper for sharing the export file.
@available(iOS 17.0, *)
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#endif
