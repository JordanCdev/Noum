//
//  ContentView.swift
//  Noum
//
//  Created by Jordan Coaten on 25/01/2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var speechVM = SpeechRecognizerViewModel()

    var body: some View {
        VStack(spacing: 20) {
            Text("Transcribed Text: \(speechVM.transcribedText)")
                .padding()

            Text("Filler Words: \(speechVM.fillerWordCount)")

            HStack {
                Button("Start") {
                    speechVM.startRecording()
                }
                Button("Stop") {
                    speechVM.stopRecording()
                }
            }
        }
        .padding()
    }
}


#Preview {
    ContentView()
}
