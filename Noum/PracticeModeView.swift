import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct PracticeModeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @State private var question: String = PracticeTopics.random()
    @State private var thinkingCountdown: Int = 15
    @State private var speakingCountdown: Int = 60
    @State private var showSummary = false
    @State private var evaluation: PracticeEvaluation?
    @State private var countdownTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                    if let error = speechVM.connectionError {
                        errorCard(error)
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
            }
        
        .padding()
        .navigationTitle("Practice Mode")
        .onAppear { startThinkingCountdown() }
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                score: evaluation?.score,
                progressSegments: 0,
                xpEarned: evaluation?.xpEarned ?? 0,
                showDuration: false,
                practiceTitle: "Legacy Timed Practice",
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

    private func startThinkingCountdown() {
        reset()
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
        speechVM.prepareSession(mode: .timed)
        speechVM.startRecording()
        countdownTask?.cancel()
        countdownTask = Task {
            for i in stride(from: speakingCountdown, through: 1, by: -1) {
                await MainActor.run { speakingCountdown = i }
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            stopSession()
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
                    difficulty: .easy,
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

    private func errorCard(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func reset() {
        countdownTask?.cancel()
        speechVM.resetCurrentSession()
        question = PracticeTopics.random()
        thinkingCountdown = 15
        speakingCountdown = 60
        evaluation = nil
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
