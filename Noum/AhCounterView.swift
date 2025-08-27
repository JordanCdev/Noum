import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct AhCounterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @State private var showSummary = false

    var body: some View {
        VStack(spacing: 20) {
            ScrollView { Text(speechVM.highlightedText).padding() }
            Text("Filler Words: \(speechVM.fillerWordCount)")
            if speechVM.isRecording {
                Button("Stop") { stopSession() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Start") { startRecording() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .navigationTitle("Ah-Counter")
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                score: nil,
                progressSegments: 0,
                xpEarned: 0,
                showDuration: false,
                onSelectPracticeMode: {
                    showSummary = false
                    dismiss(times: 2)
                },
                onHome: {
                    showSummary = false
                    dismiss(times: 3)
                },
                onPracticeAgain: {
                    speechVM.resetCurrentSession()
                    startRecording()
                }
            )
        }
    }

    private func startRecording() {
        speechVM.startRecording()
    }

    private func stopSession() {
        speechVM.stopRecording()
        showSummary = true
    }

    private func dismiss(times: Int) {
        guard times > 0 else { return }
        withAnimation(.none) { dismiss() }
        if times > 1 {
            DispatchQueue.main.async { dismiss(times: times - 1) }
        }
    }
}
#endif
