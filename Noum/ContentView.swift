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

            Toggle("Use Whisper", isOn: $speechVM.useWhisper)
                .padding(.horizontal)
                .disabled(!speechVM.isWhisperReady)

            HStack {
                Button("Start") {
                    if speechVM.useWhisper {
                        speechVM.startWhisperRecording()
                    } else {
                        speechVM.startRecording()
                    }
                }
                Button("Stop") {
                    if speechVM.useWhisper {
                        speechVM.stopWhisperRecording()
                    } else {
                        speechVM.stopRecording()
                    }
                    print("Summary Transcript: \(speechVM.transcribedText)")
                    print("Total filler words: \(speechVM.fillerWordCount)")
                    showSummary = true
                }
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
