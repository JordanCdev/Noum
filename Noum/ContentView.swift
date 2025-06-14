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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !authManager.isSignedIn {
                    VStack(spacing: 10) {
                        Button("Sign in with Google") {
                            #if canImport(UIKit)
                            if let root = UIApplication.shared.windows.first?.rootViewController {
                                authManager.signInWithGoogle(presenting: root)
                            }
                            #endif
                        }
                        Button("Sign in with Apple") {
                            authManager.signInWithApple()
                        }
                    }
                } else {
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                }

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
                        speechVM.startRecording()
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
    }
}
#endif

#if canImport(SwiftUI)
#Preview {
    ContentView()
}
#endif
