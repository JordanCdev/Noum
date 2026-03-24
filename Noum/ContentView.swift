//
//  ContentView.swift
//  Noum
//
//  Created by Jordan Coaten on 25/01/2025.
//

#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 17.0, macOS 12.0, *)
struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var profile = ProfileManager.shared
    @StateObject private var practiceSettings = PracticeSettingsManager.shared
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @State private var selectedPracticeMode: PracticeMode = .timed
    private let isUITesting = ProcessInfo.processInfo.arguments.contains("UI_TESTING")

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.93, blue: 0.88),
                        Color.white,
                        Color(red: 0.90, green: 0.95, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 18) {
                        heroCard
                        progressCard
                        quickStartCard
                        focusCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle("Noum")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                bottomNavigation
            }
        }
        .fullScreenCover(
            isPresented: .init(
                get: { !authManager.isSignedIn && !isUITesting },
                set: { _ in }
            )
        ) {
            LoginView()
        }
        .fullScreenCover(
            isPresented: .init(
                get: { authManager.isSignedIn && coachingProfileStore.shouldPresentInitialOnboarding && !isUITesting },
                set: { _ in }
            )
        ) {
            CoachingOnboardingView()
        }
    }

    private var displayName: String {
        authManager.currentAccountName ?? "Speaker"
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speak with control")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("Welcome back, \(displayName)")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text("Train clarity, reduce filler words, and stack consistent speaking reps.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            NavigationLink(destination: PracticeModeSelectionView(selectedMode: $selectedPracticeMode)) {
                Label("Start Practicing", systemImage: "waveform.and.mic")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.blue, in: Capsule())
                    .foregroundStyle(.white)
            }
            .accessibilityIdentifier("home.startPracticing")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Level")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(profile.levelTitle)
                        .font(.title3.weight(.bold))
                }
                Spacer()
                Text("\(profile.xp) XP")
                    .font(.headline)
                    .foregroundStyle(.blue)
            }

            ProgressView(value: profile.progressTowardsNextLevel)
                .tint(.blue)

            HStack {
                Text("\(ProfileManager.xpNeededToNextLevel(forXP: profile.xp)) XP to level up")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Momentum")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var quickStartCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Quick Start")
                .font(.headline)

            HStack(spacing: 12) {
                quickLink(
                    title: "Timed",
                    subtitle: "Structured practice",
                    systemImage: "clock.fill",
                    tint: .blue,
                    mode: .timed
                )

                quickLink(
                    title: "Sudden Death",
                    subtitle: "Pressure test",
                    systemImage: "bolt.fill",
                    tint: .orange,
                    mode: .suddenDeath
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var focusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Focus Today")
                .font(.headline)

            VStack(alignment: .leading, spacing: 10) {
                if let plan = CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile) {
                    focusRow(title: "Current focus", value: plan.currentFocus)
                    focusRow(title: "Suggested drill", value: plan.suggestedDrill)
                    if let profile = coachingProfileStore.profile {
                        let reference = profile.personalGoalReference
                        focusRow(
                            title: "Voice target",
                            value: reference.isEmpty ? profile.speakingStyleGoal.title : "\(profile.speakingStyleGoal.title) • \(reference)"
                        )
                    }
                    focusRow(title: "Coach note", value: plan.encouragement)
                } else {
                    focusRow(
                        title: "Starting point",
                        value: coachingProfileStore.profile == nil
                            ? "Complete your coaching profile first, then finish a few practice sessions so Noum can tailor your next steps."
                            : "Complete a few sessions and Noum will start tailoring your coaching from your practice patterns."
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var bottomNavigation: some View {
        VStack(spacing: 0) {
            Divider()
                .overlay(Color.black.opacity(0.04))

            HStack(spacing: 10) {
                NavigationLink(destination: PracticeModeSelectionView(selectedMode: $selectedPracticeMode)) {
                    navItem(title: "Practice", systemImage: "dumbbell.fill", accent: .blue)
                }
                .accessibilityIdentifier("nav.practice")
                .frame(maxWidth: .infinity)

                NavigationLink(destination: SessionHistoryView()) {
                    navItem(title: "History", systemImage: "book.fill", accent: .orange)
                }
                .accessibilityIdentifier("nav.history")
                .frame(maxWidth: .infinity)

                NavigationLink(destination: SettingsView()) {
                    navItem(title: "Settings", systemImage: "slider.horizontal.3", accent: .green)
                }
                .accessibilityIdentifier("nav.settings")
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 20)
            .background(.ultraThinMaterial)
        }
    }

    private func quickLink(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        mode: PracticeMode
    ) -> some View {
        NavigationLink(destination: PracticeModeSelectionView(selectedMode: $selectedPracticeMode)) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .padding(16)
            .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .simultaneousGesture(TapGesture().onEnded {
            selectedPracticeMode = mode
        })
    }

    private func focusRow(title: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 92, alignment: .leading)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func navItem(title: String, systemImage: String, accent: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(accent)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
#endif

#if canImport(SwiftUI)
#Preview {
    ContentView()
}
#endif
