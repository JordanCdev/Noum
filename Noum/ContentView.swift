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
    @State private var selectedPracticeMode: PracticeMode = .timed
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                let displayName = authManager.currentAccountName ?? "User"
                Text("Welcome back \(displayName)")
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
                    Divider()
                        .frame(maxWidth: .infinity)
                        .frame(height: 3)
                        .background(Color.gray.opacity(0.3))
                        .padding(.bottom, 20)
                    HStack(spacing: 50) {
                        NavigationLink(destination: PracticeModeSelectionView(selectedMode: $selectedPracticeMode)) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 27))
                                .foregroundStyle(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        Button { showHistory = true } label: {
                            Image(systemName: "book.fill")
                                .font(.system(size: 27))
                                .foregroundStyle(Color(white: 0.95))
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
        .sheet(isPresented: $showHistory) {
            SessionHistoryView(speechVM: SpeechRecognizerViewModel())
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

}
#endif

#if canImport(SwiftUI)
#Preview {
    ContentView()
}
#endif
