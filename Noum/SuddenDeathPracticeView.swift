import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct SuddenDeathPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @State private var question: String = PracticeTopics.random()
    @State private var elapsed: Int = 0
    @State private var showSummary = false
    @State private var timerTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(spacing: 20) {
            if speechVM.isRecording {
                ScrollView { Text(speechVM.highlightedText).padding() }
                Text("\(elapsed)")
                    .font(.system(size: 48, weight: .bold))
                        .accessibilityIdentifier("suddenDeathTimer")
                    Button("Stop") { stopSession() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Text(question)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Start") { startRecording() }
                        .buttonStyle(.borderedProminent)
                }
        }
        .padding()
        .navigationTitle("Sudden-Death")
        .onChange(of: speechVM.fillerWordCount) { _, count in
            if count > 0 { stopSession() }
        }
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: TimeInterval(elapsed),
                score: nil,
                showDuration: true,
                onNewSession: { reset() }
            )
        }
    }

    private func startRecording() {
        speechVM.startRecording()
        timerTask = Task {
            for i in 1...30 {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run { elapsed = i }
                if Task.isCancelled { return }
            }
            stopSession()
        }
    }

    private func stopSession() {
        timerTask?.cancel()
        speechVM.stopRecording()
        showSummary = true
    }

    private func reset() {
        speechVM.resetCurrentSession()
        question = PracticeTopics.random()
        elapsed = 0
        timerTask = nil
    }
}
#endif
