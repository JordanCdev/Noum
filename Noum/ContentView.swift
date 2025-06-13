//
//  ContentView.swift
//  Noum
//
//  Created by Jordan Coaten on 25/01/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @State private var showSummary = false

    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(speechVM.highlightedText)
                    .padding()
            }

            Text("Filler Words: \(speechVM.fillerWordCount)")

            if !speechVM.isWhisperReady {
                ProgressView()
                    .padding(.vertical)
            }
            if let error = speechVM.whisperInitError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }

            HStack {
                Button("Start") {
                    speechVM.startRecording()
                }
                .disabled(!speechVM.isWhisperReady)
                Button("Stop") {
                    speechVM.stopRecording()
                    print("Summary Transcript: \(speechVM.transcribedText)")
                    print("Total filler words: \(speechVM.fillerWordCount)")
                    showSummary = true
                }
                .disabled(!speechVM.isWhisperReady)
            }
        }
        .padding()
        .sheet(isPresented: $showSummary) {
            SummaryView(transcript: speechVM.highlightedText, fillerCount: speechVM.fillerWordCount)
        }
    }
}


#Preview {
    ContentView()
}
