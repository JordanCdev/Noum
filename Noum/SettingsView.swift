#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 17.0, macOS 12.0, *)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var practiceSettings = PracticeSettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var aiSettings = AISettingsManager.shared
    @State private var showCoachingProfile = false

    var body: some View {
        NavigationStack {
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

                VStack(spacing: 18) {
                    practiceCard
                    coachingCard
                    aiCard
                    accountCard
                    securityCard
                    Spacer(minLength: 0)
                }
                .padding(18)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onChange(of: authManager.isSignedIn) { _, signedIn in
            if !signedIn { dismiss() }
        }
        .sheet(isPresented: $showCoachingProfile) {
            CoachingOnboardingView()
        }
    }

    private var practiceCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Practice")
                .font(.headline)

            Text("Timed practice difficulty changes the speaking timer and the XP weighting.")
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
                settingsRow(title: "Context", value: profile.speakingContext.title)
                settingsRow(title: "Primary goal", value: profile.primaryGoal.title)
                settingsRow(title: "Challenge", value: profile.biggestChallenge.title)
                settingsRow(title: "Desired result", value: profile.desiredOutcome.title)
                settingsRow(title: "Starting point", value: profile.confidenceLevel.title)
                if !profile.coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    settingsRow(title: "Coaching brief", value: profile.coachingBrief)
                }
            } else {
                Text("Complete your coaching profile so Noum can tailor drills and guidance to your goals.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AI Coach")
                .font(.headline)

            Text("Keep AI as an occasional deeper-feedback layer rather than something that runs after every session.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Provider", selection: $aiSettings.provider) {
                ForEach(AIProvider.allCases) { provider in
                    Text(provider.title).tag(provider)
                }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("Monthly AI feedback budget: \(aiSettings.monthlyAnalysisLimit)")
                    .font(.subheadline.weight(.semibold))
                Stepper(value: $aiSettings.monthlyAnalysisLimit, in: 5...100, step: 5) {
                    Text("\(aiSettings.remainingAnalyses) analyses remaining this month")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Set `OPENAI_API_KEY` or `DEEPSEEK_API_KEY` in your Xcode scheme environment, or create a local `AIConfig.plist` from `AIConfig.plist.example` and keep it out of git.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Account")
                .font(.headline)

            if authManager.isSignedIn {
                if let name = authManager.currentAccountName {
                    settingsRow(title: "Signed in as", value: name)
                } else if let id = authManager.currentAccountID {
                    settingsRow(title: "Account ID", value: id)
                } else {
                    settingsRow(title: "Status", value: "Signed in")
                }
            } else {
                settingsRow(title: "Status", value: "Signed out")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var securityCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session")
                .font(.headline)

            Text("Use sign out if you want to disconnect the current Google account on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if authManager.isSignedIn {
                Button("Sign Out") {
                    authManager.signOut()
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.red, in: Capsule())
                .foregroundStyle(.white)
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

    private func settingsRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}
#endif
