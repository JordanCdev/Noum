import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct TimedPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @StateObject private var profile = ProfileManager.shared
    @State private var question: String = PracticeTopics.random()
    @State private var thinkingCountdown: Int = 15
    @State private var speakingCountdown: Int = 60
    @State private var progressSegments: Int = 0
    @State private var showSummary = false
    @State private var score: Int = 0
    @State private var xpEarned: Int = 0

    var body: some View {
        ZStack {
            content
        }
        .navigationTitle("Timed Practice")
        .onAppear(perform: startThinkingCountdown)
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                score: score,
                progressSegments: progressSegments,
                xpEarned: xpEarned,
                showDuration: false,
                onSelectPracticeMode: {
                    showSummary = false
                    dismissToRoot()
                },
                onHome: {
                    showSummary = false
                    dismissToRoot()
                },
                onPracticeAgain: {
                    reset()
                    startThinkingCountdown()
                }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 20) {
            HStack {
                ForEach(0..<3) { index in
                    Image(systemName: "circle.fill")
                        .foregroundColor(color(for: index))
                }
            }
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
        .padding()
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
                await MainActor.run {
                    speakingCountdown = i
                    updateProgress()
                }
                try? await Task.sleep(for: .seconds(1))
            }
            stopSession()
        }
    }

    private func stopSession() {
        speechVM.stopRecording()
        computeScore()
        xpEarned = score * 10
        showSummary = true
    }

    private func computeScore() {
        let base = 7
        let penalty = speechVM.fillerWordCount
        let bonus = progressSegments
        score = max(1, min(10, base + bonus - penalty))
    }

    private func reset() {
        speechVM.resetCurrentSession()
        question = PracticeTopics.random()
        thinkingCountdown = 15
        speakingCountdown = 60
        progressSegments = 0
        score = 0
    }

    private func updateProgress() {
        let elapsed = 60 - speakingCountdown
        progressSegments = min(3, elapsed / 15)
    }

    private func color(for index: Int) -> Color {
        if index < progressSegments {
            switch index {
            case 0: return .brown // bronze
            case 1: return .gray // silver
            default: return .yellow // gold
            }
        } else {
            return .gray.opacity(0.3)
        }
    }

    private func dismissToRoot() {
        DispatchQueue.main.async {
            dismiss()
            DispatchQueue.main.async {
                dismiss()
                DispatchQueue.main.async {
                    dismiss()
                }
            }
        }
    }
}
#endif
