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
    @State private var showHistory = false
    @State private var showSettings = false
    @State private var showPracticeOptions = false
    // Track whether the selected practice view should be shown
    @State private var showPractice = false
    @State private var selectedPracticeMode: PracticeMode = .timed
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome back \(authManager.currentAccountName ?? \"User\")")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text(profile.levelTitle)
                    .font(.headline)
                Spacer()
            }
            .padding()
            .navigationTitle("Noum")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(alignment: .bottom) {
                VStack(spacing: 0) {
                    Divider().background(Color.gray.opacity(0.3))
                    HStack(spacing: 50) {
                        Button { showPracticeOptions = true } label: {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 27))
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        Button { showHistory = true } label: {
                            Image(systemName: "book.fill")
                                .font(.system(size: 27))
                                .foregroundStyle(.brown)
                        }
                        .frame(maxWidth: .infinity)
                        Button { showSettings = true } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 27))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 12)
                }
                .padding(.bottom, 10)
                .background(Color(UIColor.systemBackground))
            }
        }
        .navigationDestination(isPresented: $showPracticeOptions) {
            PracticeModeSelectionView(selectedMode: $selectedPracticeMode) {
                showPractice = true
            }
       }
        // Present the selected practice mode within the navigation stack
        .navigationDestination(isPresented: $showPractice) {
            practiceDestination
        }
        .navigationDestination(isPresented: $showPractice) {
            practiceDestination
        }
        .sheet(isPresented: $showHistory) {
            SessionHistoryView(speechVM: SpeechRecognizerViewModel())
        }
        .sheet(isPresented: $showPractice) {
            PracticeModeView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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

    @ViewBuilder
    private var practiceDestination: some View {
        switch selectedPracticeMode {
        case .timed:
            TimedPracticeView()
        case .suddenDeath:
            SuddenDeathPracticeView()
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
