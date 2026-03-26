import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct TimedPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @StateObject private var practiceSettings = PracticeSettingsManager.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @State private var question: String = PracticeTopics.random()
    @State private var thinkingCountdown: Int = 15
    @State private var speakingCountdown: Int = 60
    @State private var progressSegments: Int = 0
    @State private var showSummary = false
    @State private var evaluation: PracticeEvaluation?
    @State private var hasStartedSpeaking = false
    @State private var countdownTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.92, blue: 0.87),
                    Color.white,
                    Color(red: 0.90, green: 0.95, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .navigationTitle("Timed Practice")
        .accessibilityIdentifier("timedPractice.screen")
        .onAppear(perform: startThinkingCountdown)
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                score: evaluation?.score,
                progressSegments: progressSegments,
                xpEarned: evaluation?.xpEarned ?? 0,
                showDuration: false,
                practiceTitle: "Timed Practice • \(practiceSettings.timedDifficulty.title)",
                feedbackOverride: evaluation?.feedback,
                headlineOverride: evaluation?.headline,
                scoreBreakdown: evaluation?.segments ?? [],
                insights: evaluation?.insights ?? [],
                recentSessions: speechVM.pastSessions,
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
                    startThinkingCountdown()
                }
            )
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 20) {
            headerCard(
                eyebrow: "Timed Drill",
                title: hasStartedSpeaking ? "Deliver with control" : "Prepare your answer",
                subtitle: thinkingCountdown > 0
                    ? "Use the setup window to structure your response before the timer starts."
                    : activeSubtitle
            )

            HStack {
                ForEach(0..<4) { index in
                    Image(systemName: "circle.fill")
                        .foregroundColor(color(for: index))
                }
            }
            .padding(.vertical, 8)

            if let error = speechVM.connectionError {
                errorCard(error)
            }

            if !hasStartedSpeaking {
                promptCard
                if thinkingCountdown > 0 {
                    countdownCard(value: thinkingCountdown, label: "Seconds to think", tint: .blue)
                } else if practiceSettings.timedDifficulty == .free {
                    countdownCard(value: 0, label: "Free mode. Start when ready", tint: .green)
                } else {
                    countdownCard(value: speakingCountdown, label: "Ready to begin", tint: .orange)
                }
            } else {
                transcriptCard
                statChip(title: "Filler Words", value: "\(speechVM.fillerWordCount)", tint: .red)
                if speechVM.isRecording {
                    if practiceSettings.timedDifficulty == .free {
                        countdownCard(value: Int(speechVM.lastSessionDuration), label: "Seconds spoken", tint: .green)
                            .accessibilityIdentifier("practiceCountdown")
                    } else {
                        countdownCard(value: speakingCountdown, label: "Seconds remaining", tint: .orange)
                            .accessibilityIdentifier("practiceCountdown")
                    }
                }
            }
            if speechVM.isRecording {
                Button("Stop") { stopSession() }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            } else if !hasStartedSpeaking {
                Button(thinkingCountdown > 0 ? "Start Now" : "Start Speaking") {
                    beginSpeaking()
                }
                .buttonStyle(.borderedProminent)
                .tint(practiceSettings.timedDifficulty == .free ? .green : .blue)
            } else {
                Button("Close") { dismiss() }
                    .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompt")
                .font(.headline)
            Text(question)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var activeSubtitle: String {
        switch practiceSettings.timedDifficulty {
        case .free:
            return "No timer is running. Build the answer until you decide to stop."
        case .easy:
            return "Aim for a complete answer with a clean beginning, middle, and close."
        case .medium:
            return "Keep it punchy. One clear point and a confident finish."
        case .hard:
            return "Short, sharp, and direct. Get to your best point quickly."
        }
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

    private func headerCard(eyebrow: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(eyebrow)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(title)
                .font(.largeTitle.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func countdownCard(value: Int, label: String, tint: Color) -> some View {
        VStack(spacing: 8) {
            Text("\(value)")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func statChip(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(tint.opacity(0.18))
                .frame(width: 12, height: 12)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.92), in: Capsule())
    }

    private func errorCard(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transcription error")
                .font(.headline)
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func startThinkingCountdown() {
        reset()
        Task {
            for i in stride(from: thinkingCountdown, through: 1, by: -1) {
                await MainActor.run { thinkingCountdown = i }
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run { thinkingCountdown = 0 }
            if practiceSettings.timedDifficulty != .free {
                beginSpeaking()
            }
        }
    }

    private func beginSpeaking() {
        guard !speechVM.isRecording else { return }
        hasStartedSpeaking = true
        speechVM.prepareSession(mode: .timed)
        speechVM.startRecording()
        if let duration = practiceSettings.timedDifficulty.duration {
            countdownTask?.cancel()
            countdownTask = Task {
                for i in stride(from: duration, through: 1, by: -1) {
                    await MainActor.run {
                        speakingCountdown = i
                        updateProgress()
                    }
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled { return }
                }
                stopSession()
            }
        } else {
            countdownTask?.cancel()
            countdownTask = Task {
                var elapsed = 0
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    elapsed += 1
                    await MainActor.run {
                        speakingCountdown = elapsed
                        progressSegments = min(4, elapsed / 15)
                    }
                }
            }
        }
    }

    private func stopSession() {
        countdownTask?.cancel()
        speechVM.stopRecording()
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                let result = PracticeEvaluator.evaluateTimedPractice(
                    transcript: speechVM.transcribedText,
                    fillerCount: speechVM.fillerWordCount,
                    duration: speechVM.lastSessionDuration,
                    difficulty: practiceSettings.timedDifficulty,
                    recentSessions: speechVM.pastSessions,
                    profile: coachingProfileStore.profile
                )
                evaluation = result
                speechVM.annotateLatestSession(
                    score: result.score,
                    xpEarned: result.xpEarned,
                    headline: result.headline,
                    insights: result.insights,
                    coachSummary: result.feedback
                )
                showSummary = true
            }
        }
    }

    private func reset() {
        countdownTask?.cancel()
        speechVM.resetCurrentSession()
        question = PracticeTopics.random()
        thinkingCountdown = 15
        speakingCountdown = practiceSettings.timedDifficulty.duration ?? 0
        progressSegments = 0
        evaluation = nil
        hasStartedSpeaking = false
    }

    private func updateProgress() {
        guard let duration = practiceSettings.timedDifficulty.duration else { return }
        let elapsed = duration - speakingCountdown
        let segmentSize = max(1, duration / 4)
        progressSegments = min(4, elapsed / segmentSize)
    }

    private func color(for index: Int) -> Color {
        if index < progressSegments {
            switch index {
            case 0: return .brown
            case 1: return .gray
            case 2: return .yellow
            default: return .green
            }
        } else {
            return .gray.opacity(0.3)
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
