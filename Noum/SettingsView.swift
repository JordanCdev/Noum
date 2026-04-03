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
    @State private var isBackendConfigured = false
    @State private var showCoachingProfile = false
    @State private var debugMessage: String?
    @State private var showDeleteConfirmation = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.92, blue: 0.87),
                    Color.white,
                    Color(red: 0.90, green: 0.95, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    overviewCard
                    practiceCard
                    coachingCard
                    remindersCard
                    accountPrivacyCard
                    if authManager.isDeveloper {
                        debugCard
                        recommendationDiagnosticsCard
                    }
                    Spacer(minLength: 0)
                }
                .padding(18)
            }
        }
        .navigationTitle("Settings")
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
        .alert("Debug Tools", isPresented: .constant(debugMessage != nil), actions: {
            Button("OK", role: .cancel) { debugMessage = nil }
        }, message: {
            Text(debugMessage ?? "")
        })
        .alert("Delete Account?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                authManager.deleteCurrentAccount()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the current account and its synced practice data from this app session.")
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
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
                    .background(Color.blue.opacity(practiceSettings.timedDifficulty == difficulty ? 0.10 : 0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                            .background(Color.blue.opacity(imVoicePlaybackSettings.engine == engine ? 0.10 : 0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                    .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
                        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
            .padding(.vertical, 15)
            .background(Color.blue, in: Capsule())
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var remindersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Practice Reminders")
                .font(.headline)

            Text("Tie the return loop to what the user actually cares about, not a generic streak banner.")
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
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
            } else {
                Text("No active session")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
            .padding(.vertical, 15)
            .background(Color.blue, in: Capsule())
            .foregroundStyle(.white)

            Button("Create 3 Session Run") {
                seedSessionRun()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.orange, in: Capsule())
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
                .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
                .background(Color.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
        .background(Color.black.opacity(0.04), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
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
        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
        .background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
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
#endif
