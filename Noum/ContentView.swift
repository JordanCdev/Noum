//
//  ContentView.swift
//  Noum
//
//  Created by Jordan Coaten on 25/01/2025.
//

import SwiftUI

@available(iOS 17.0, macOS 12.0, *)
struct ContentView: View {
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @State private var showSummary = false
    @State private var showHistory = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ScrollView {
                    Text(speechVM.highlightedText)
                        .padding()
                }

                Text("Filler Words: \(speechVM.fillerWordCount)")

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
        .sheet(isPresented: $showSummary) {
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


#Preview {
    ContentView()
}
