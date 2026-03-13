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
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.93, green: 0.96, blue: 0.90),
                    Color.white,
                    Color(red: 0.90, green: 0.95, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Live Monitor")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text("Track filler words as you speak")
                        .font(.largeTitle.weight(.bold))
                    Text("Use this mode for open-ended reps without a fixed countdown.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                HStack(spacing: 12) {
                    statCard(title: "Filler Words", value: "\(speechVM.fillerWordCount)", tint: .red)
                    statCard(title: "Status", value: speechVM.isRecording ? "Live" : "Ready", tint: speechVM.isRecording ? .green : .blue)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Transcript")
                        .font(.headline)
                    ScrollView {
                        Text(speechVM.highlightedText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(red: 0.97, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .frame(minHeight: 260)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                if speechVM.isRecording {
                    Button("Stop") { stopSession() }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                } else {
                    Button("Start") { startRecording() }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                }
            }
            .padding()
        }
        .navigationTitle("Ah-Counter")
        .accessibilityIdentifier("ahCounter.screen")
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
                    showSummary = false
                    dismiss(times: 2)
                }
            )
        }
    }

    private func statCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func startRecording() {
        speechVM.prepareSession(mode: .ahCounter)
        speechVM.startRecording()
    }

    private func stopSession() {
        speechVM.stopRecording()
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                speechVM.annotateLatestSession(
                    headline: speechVM.fillerWordCount <= 2 ? "Good awareness" : "Useful awareness rep",
                    insights: [
                        speechVM.fillerWordCount <= 2
                            ? "You kept filler words relatively low in a free-form speaking rep."
                            : "This rep surfaced your filler habits clearly, which is useful coaching data."
                    ],
                    coachSummary: speechVM.fillerWordCount <= 2
                        ? "A solid awareness rep. Keep noticing where silence can replace filler words."
                        : "This was a productive awareness drill. Notice which moments triggered the filler words and rehearse cleaner pauses."
                )
                showSummary = true
            }
        }
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
