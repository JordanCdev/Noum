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

            HStack {
                Button("Start") {
                    speechVM.startRecording()
                }
                Button("Stop") {
                    speechVM.stopRecording()
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
