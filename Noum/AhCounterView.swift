import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct AhCounterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @State private var showSummary = false
    @State private var evaluation: PracticeEvaluation?

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
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
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                    HStack(spacing: 12) {
                        statCard(title: "Filler Words", value: "\(speechVM.fillerWordCount)", tint: .red)
                        statCard(title: "Status", value: speechVM.isRecording ? "Live" : "Ready", tint: speechVM.isRecording ? .green : .blue)
                    }

                    if let error = speechVM.connectionError {
                        errorCard(error)
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
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 90)
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if speechVM.isRecording {
                        Button("Stop") { stopSession() }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.red, in: Capsule())
                            .foregroundStyle(.white)
                    } else {
                        Button("Start") { startRecording() }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color(red: 0.14, green: 0.60, blue: 0.44), in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ahCounter.screen")
        .task { speechVM.prepareForInteractiveUse() }
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: speechVM.lastSessionDuration,
                score: evaluation?.score,
                progressSegments: 0,
                xpEarned: evaluation?.xpEarned ?? 0,
                showDuration: false,
                feedbackOverride: evaluation?.feedback,
                headlineOverride: evaluation?.headline,
                scoreBreakdown: evaluation?.segments ?? [],
                insights: evaluation?.insights ?? [],
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
                    speechVM.resetCurrentSession()
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
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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

    private func startRecording() {
        speechVM.prepareSession(mode: .ahCounter)
        speechVM.startRecording()
    }

    private func stopSession() {
        speechVM.stopRecording()
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                let result = PracticeEvaluator.evaluateAhCounterPractice(
                    transcript: speechVM.transcribedText,
                    fillerCount: speechVM.fillerWordCount,
                    duration: speechVM.lastSessionDuration,
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

    private func dismiss(times: Int) {
        guard times > 0 else { return }
        withAnimation(.none) { dismiss() }
        if times > 1 {
            DispatchQueue.main.async { dismiss(times: times - 1) }
        }
    }
}
#endif
