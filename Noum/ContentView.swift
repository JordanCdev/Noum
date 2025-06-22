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
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @StateObject private var authManager = AuthManager.shared
    @State private var showSummary = false
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showPracticeOptions = false
    // Track whether the selected practice view should be shown
    @State private var showPractice = false
    @State private var selectedPracticeMode: PracticeMode = .timed
    @State private var showCredentialsAlert = false
    @State private var countdown: Int = 0
    
    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 20) {

                ScrollView {
                    Text(speechVM.highlightedText)
                        .padding()
                }

                Text("Filler Words: \(speechVM.fillerWordCount)")

                if let error = speechVM.connectionError {
                    Text(error)
                        .foregroundStyle(.red)
                }
                
                HStack {
                    Button("Start") {
                        if authManager.isSignedIn {
                            startCountdown()
                        } else {
                            showCredentialsAlert = true
                        }
                    }
                    .disabled(speechVM.isRecording || countdown > 0)
                    Button("Stop") {
                        speechVM.stopRecording()
                        showSummary = true
                    }
                    .disabled(!speechVM.isRecording)
                }
            }
            if countdown > 0 {
                Text("\(countdown)")
                    .font(.system(size: 72, weight: .bold))
                    .transition(.opacity)
                    .accessibilityIdentifier("countdown")
            }
        }
        .padding()
            .navigationTitle("Practice")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button { showPracticeOptions = true } label: {
                        Image(systemName: "figure.walk")
                    }
                    Button { showHistory = true } label: {
                        Image(systemName: "clock")
                    }
                    Button { showSettings = true } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
       }
        // Present the selected practice mode within the navigation stack
        .navigationDestination(isPresented: $showPractice) {
            practiceDestination
        }
        .sheet(
            isPresented: $showSummary,
            onDismiss: { speechVM.resetCurrentSession() }
        ) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                score: nil,
                onNewSession: { speechVM.resetCurrentSession() }
            )
        }
        .sheet(isPresented: $showHistory) {
            SessionHistoryView(speechVM: speechVM)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .navigationDestination(isPresented: $showPracticeOptions) {
            PracticeModeSelectionView(selectedMode: $selectedPracticeMode) {
                showPractice = true
            }
        }
        .alert("Credentials Missing", isPresented: $showCredentialsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sign in from Settings before starting a session.")
        }
        .fullScreenCover(
            isPresented: .init(
                get: { !authManager.isSignedIn },
                set: { _ in }
            )
        ) {
            LoginView()
        }
    }

    private func startCountdown() {
        countdown = 3
        Task {
            for i in stride(from: 3, through: 1, by: -1) {
                await MainActor.run { countdown = i }
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run {
                countdown = 0
                speechVM.startRecording()
            }
        }
    }

    @ViewBuilder
    private var practiceDestination: some View {
        switch selectedPracticeMode {
        case .timed:
            TimedPracticeView()
        case .suddenDeath:
            SuddenDeathPracticeView()
        }
    }
}
#endif

#if canImport(SwiftUI)
#Preview {
    ContentView()
}
#endif
