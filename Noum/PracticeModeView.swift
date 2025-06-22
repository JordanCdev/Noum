import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct PracticeModeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @State private var question: String = PracticeTopics.random()
    @State private var thinkingCountdown: Int = 15
    @State private var speakingCountdown: Int = 60
    @State private var showSummary = false
    @State private var score: Int = 0

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 20) {
                    if thinkingCountdown > 0 {
                        Text(question)
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .padding()
                        Text("Prepare your answer")
                        Text("\(thinkingCountdown)")
                            .font(.system(size: 48, weight: .bold))
                    } else {
                        ScrollView { Text(speechVM.highlightedText).padding() }
                        Text("Filler Words: \(speechVM.fillerWordCount)")
                        if speechVM.isRecording {
                            Text("\(speakingCountdown)")
                                .font(.system(size: 48, weight: .bold))
                                .accessibilityIdentifier("practiceCountdown")
                        }
                    }
                    if speechVM.isRecording {
                        Button("Stop") { stopSession() }
                            .buttonStyle(.borderedProminent)
                    } else if thinkingCountdown <= 0 {
                        Button("Close") { dismiss() }
                    }
                }
            }
            .padding()
            .navigationTitle("Practice Mode")
        }
        .onAppear { startThinkingCountdown() }
        .sheet(isPresented: $showSummary, onDismiss: reset) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                score: score,
                onNewSession: { reset() }
            )
        }
    }

    private func startThinkingCountdown() {
        Task {
            for i in stride(from: thinkingCountdown, through: 1, by: -1) {
                await MainActor.run { thinkingCountdown = i }
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run { thinkingCountdown = 0 }
            startRecording()
        }
    }

    private func startRecording() {
        speechVM.startRecording()
        Task {
            for i in stride(from: speakingCountdown, through: 1, by: -1) {
                await MainActor.run { speakingCountdown = i }
                try? await Task.sleep(for: .seconds(1))
            }
            stopSession()
        }
    }

    private func stopSession() {
        speechVM.stopRecording()
        computeScore()
        showSummary = true
    }

    private func computeScore() {
        let base = 100
        let penalty = speechVM.fillerWordCount * 5
        score = max(1, base - penalty)
    }

    private func reset() {
        speechVM.resetCurrentSession()
        question = PracticeTopics.random()
        thinkingCountdown = 15
        speakingCountdown = 60
        score = 0
    }
}
#endif
