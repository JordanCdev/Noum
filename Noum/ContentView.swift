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
    @State private var showCredentialsAlert = false
    
    var body: some View {
        NavigationStack {
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
                            speechVM.startRecording()
                        } else {
                            showCredentialsAlert = true
                        }
                    }
                    .disabled(speechVM.isRecording)
                    Button("Stop") {
                        speechVM.stopRecording()
                        showSummary = true
                    }
                    .disabled(!speechVM.isRecording)
                }
            }
            .padding()
            .navigationTitle("Practice")
            .toolbar {
                Button("History") { showHistory = true }
                Button("Settings") { showSettings = true }
            }
        }
        .sheet(
            isPresented: $showSummary,
            onDismiss: { speechVM.resetCurrentSession() }
        ) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                onNewSession: { speechVM.resetCurrentSession() }
            )
        }
        .sheet(isPresented: $showHistory) {
            SessionHistoryView(speechVM: speechVM)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert("Credentials Missing", isPresented: $showCredentialsAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Sign in from Settings before starting a session.")
        }
    }
}
#endif

#if canImport(SwiftUI)
#Preview {
    ContentView()
}
#endif
