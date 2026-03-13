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
    @State private var progressSegments: Int = 0
    @State private var score: Int = 0
    @State private var xpEarned: Int = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.98, green: 0.93, blue: 0.88),
                    Color.white,
                    Color(red: 0.99, green: 0.95, blue: 0.88)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                headerCard
                progressCard

                if speechVM.isRecording {
                    transcriptCard
                    timerCard
                        .accessibilityIdentifier("suddenDeathTimer")
                    Button("Stop") { stopSession() }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                } else {
                    promptCard
                    Button("Start") { startRecording() }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                }
            }
            .padding()
        }
        .navigationTitle("Sudden-Death")
        .accessibilityIdentifier("suddenDeath.screen")
        .onChange(of: speechVM.fillerWordCount) { _, count in
            if count > 0 { stopSession() }
        }
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: TimeInterval(elapsed),
                score: score,
                progressSegments: progressSegments,
                xpEarned: xpEarned,
                showDuration: true,
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pressure Drill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("One filler word ends the round")
                .font(.largeTitle.weight(.bold))
            Text("Start immediately and stay clean. The timer only helps if your delivery stays sharp.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var progressCard: some View {
        HStack(spacing: 12) {
            statCard(title: "Elapsed", value: "\(elapsed)s", tint: .orange)
            statCard(title: "Fillers", value: "\(speechVM.fillerWordCount)", tint: .red)
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompt")
                .font(.headline)
            Text(question)
                .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Live Transcript")
                .font(.headline)
            ScrollView {
                Text(speechVM.highlightedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(red: 0.97, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .frame(minHeight: 220)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var timerCard: some View {
        VStack(spacing: 8) {
            Text("\(elapsed)")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(.orange)
            Text("Seconds survived")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
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
        speechVM.prepareSession(mode: .suddenDeath)
        speechVM.startRecording()
        timerTask = Task {
            for i in 1...30 {
                try? await Task.sleep(for: .seconds(1))
                await MainActor.run {
                    elapsed = i
                    progressSegments = min(3, i / 10)
                }
                if Task.isCancelled { return }
            }
            stopSession()
        }
    }

    private func stopSession() {
        timerTask?.cancel()
        speechVM.stopRecording()
        computeScore()
        xpEarned = score * 10
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                speechVM.annotateLatestSession(
                    score: score,
                    xpEarned: xpEarned,
                    headline: score >= 8 ? "Composed under pressure" : "Pressure exposed a few cracks",
                    insights: [
                        fillerWordCountInsight,
                        elapsedInsight
                    ],
                    coachSummary: coachSummary
                )
                showSummary = true
            }
        }
    }

    private func reset() {
        speechVM.resetCurrentSession()
        question = PracticeTopics.random()
        elapsed = 0
        progressSegments = 0
        score = 0
        xpEarned = 0
        timerTask = nil
    }
    private func computeScore() {
        let base = 7
        let penalty = speechVM.fillerWordCount
        let bonus = progressSegments
        score = max(1, min(10, base + bonus - penalty))
    }

    private var fillerWordCountInsight: String {
        speechVM.fillerWordCount == 0
            ? "You held the line without filler words."
            : "A filler word ended the round, so focus on calmer openings and cleaner pauses."
    }

    private var elapsedInsight: String {
        elapsed >= 20
            ? "You kept control under pressure for \(elapsed) seconds, which is a strong sign of composure."
            : "Build toward a longer clean stretch before the first filler word appears."
    }

    private var coachSummary: String {
        speechVM.fillerWordCount == 0
            ? "A strong sudden-death round. You stayed composed and protected the clarity of the answer."
            : "This is useful pressure practice. Keep the first sentence deliberate and let pauses replace filler words."
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
