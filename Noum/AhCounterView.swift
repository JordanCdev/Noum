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
            AppColor.screenBackground
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("Live Monitor")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Text("Track filler words as you speak")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        Text("Use this mode for open-ended reps without a fixed countdown.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg)
                    .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))

                    HStack(spacing: Spacing.sm) {
                        StatCard(title: "Filler Words", value: "\(speechVM.fillerWordCount)", tint: .red)
                        StatCard(title: "Status", value: speechVM.isRecording ? "Live" : "Ready", tint: speechVM.isRecording ? .green : AppColor.brandBlue)
                    }

                    if let error = speechVM.connectionError {
                        ErrorCard(message: error)
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Transcript")
                            .font(.headline)
                        ScrollView {
                            Text(speechVM.highlightedText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(Spacing.md)
                                .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                        }
                        .frame(minHeight: 260)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg)
                    .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.md)
                .padding(.bottom, 90)
            }
            .safeAreaInset(edge: .bottom) {
                Group {
                    if speechVM.isRecording {
                        Button("Stop") { stopSession() }
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(Color.red.gradient, in: Capsule(style: .continuous))
                            .foregroundStyle(.white)
                            .buttonStyle(.pressable)
                    } else {
                        Button("Start") { startRecording() }
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.md)
                            .background(AppColor.modeAhCounter.gradient, in: Capsule(style: .continuous))
                            .foregroundStyle(.white)
                            .buttonStyle(.pressable)
                    }
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.sm)
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

    // statCard and errorCard replaced by shared StatCard and ErrorCard from DesignSystem.swift

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
        dismissRecursively(from: dismiss, times: times)
    }
}
#endif
