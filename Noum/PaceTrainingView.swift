import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Pace Training mini-game — trains real-time speaking pace awareness.
/// Two sub-modes: Freestyle (speak on a topic) and Read-Along (match
/// karaoke-style word highlighting at target WPM).
struct PaceTrainingView: View {
    @Binding var navigationPath: NavigationPath
    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var engine = PaceTrainingEngine()
    @EnvironmentObject private var profileManager: ProfileManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var didAwardXP = false
    @State private var hasValidatedResult = false
    @State private var completionIssue: String?
    @State private var showAdjustments = false
    #if DEBUG
    @State private var isPresentingCompletionFixture = false
    #endif

    private let tint = AppColor.modePace

    private var isResultPhase: Bool {
        if case .ended = engine.phase, hasValidatedResult { return true }
        return false
    }

    private var isSetupPhase: Bool { engine.phase == .setup }

    var body: some View {
        ZStack {
            if case .ended = engine.phase, hasValidatedResult {
                AppColor.screenBackground
                    .ignoresSafeArea()
            } else {
                FocusedPracticeBackground(style: .pace)
            }

            content
        }
        .navigationBarBackButtonHidden(!(engine.phase == .setup))
        .tint(isResultPhase ? tint : .white)
        .toolbar {
            if !isSetupPhase && !isResultPhase {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        speechVM.cancelRecording()
                        engine.cancel()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .accessibilityLabel("End pace training")
                }
            }
        }
        .onChange(of: speechVM.transcribedText) { _, newValue in
            engine.ingestTranscript(newValue)
        }
        .onChange(of: speechVM.fillerWordCount) { _, newValue in
            engine.updateFillerCount(newValue)
        }
        .onChange(of: engine.phase) { _, newPhase in
            handlePhase(newPhase)
        }
        .onChange(of: speechVM.recordingLifecycle) { _, lifecycle in
            guard case .failed = lifecycle,
                  engine.phase != .setup else { return }
            completionIssue = nil
            engine.reset()
        }
        .onAppear {
            #if DEBUG
            if presentRequestedCompletionFixtureIfNeeded() { return }
            #endif
            engine.prompt = PaceTrainingEngine.randomPrompt()
            engine.passage = PaceTrainingEngine.passages.randomElement() ?? PaceTrainingEngine.passages[0]
        }
        .onDisappear {
            speechVM.cancelRecording()
            engine.cancel()
        }
        .sheet(isPresented: $showAdjustments) {
            paceAdjustSheet
        }
        .transcriptionRouteNotice(speechVM.transcriptionRouteNotice)
    }

    // MARK: - Content Router

    @ViewBuilder
    private var content: some View {
        switch engine.phase {
        case .setup:
            setupSurface
                .transition(.opacity)
        case .countdown(let n):
            countdownOverlay(n)
                .transition(.opacity)
        case .go:
            countdownOverlay(0, label: "GO")
                .transition(.opacity)
        case .connecting:
            connectingSurface
                .transition(.opacity)
        case .active:
            activeSurface
                .environment(\.colorScheme, .dark)
                .transition(.opacity)
        case .ended(let result):
            if hasValidatedResult {
                resultSurface(result)
                    .transition(.opacity)
            } else {
                finalizingSurface
                    .transition(.opacity)
            }
        }
    }

    // MARK: - Phase Handler

    private func handlePhase(_ phase: PaceTrainingPhase) {
        switch phase {
        case .connecting:
            connectRecorderAndStartRound()
        case .active:
            guard speechVM.isRecording else {
                engine.reset()
                return
            }
        case .ended(let result):
            #if DEBUG
            guard !isPresentingCompletionFixture else { return }
            #endif
            Task { @MainActor in
                let completion = await speechVM.stopRecordingAwaitingFinalization()
                let disposition = PaceTrainingCompletionDisposition.resolve(
                    candidate: result,
                    completion: completion,
                    captureDuration: speechVM.lastSessionDuration
                )
                switch disposition {
                case .eligible:
                    completionIssue = nil
                    if !didAwardXP {
                        profileManager.addXP(disposition.awardedXP)
                        didAwardXP = true
                    }
                    hasValidatedResult = true
                case .insufficientSpeech:
                    engine.reset()
                    hasValidatedResult = false
                    completionIssue = Self.insufficientSpeechMessage
                case .unusableRecording:
                    engine.reset()
                    hasValidatedResult = false
                    completionIssue = nil
                }
            }
        default:
            break
        }
    }

    private func beginCountdown() {
        guard engine.phase == .setup else { return }
        guard recordingIssuePresentation?.recovery != .openSettings else { return }
        hasValidatedResult = false
        didAwardXP = false
        completionIssue = nil
        speechVM.connectionError = nil
        engine.beginCountdown()
    }

    private func connectRecorderAndStartRound() {
        Task { @MainActor in
            speechVM.shouldRecordPracticeSession = false
            speechVM.sessionPrompt = engine.subMode == .freestyle ? engine.prompt : engine.passage.title
            speechVM.prepareSession(mode: .timed)
            guard await speechVM.startRecordingAwaitingReadiness(),
                  engine.phase == .connecting else { return }
            engine.confirmCaptureReady(captureReady: true)
        }
    }

    #if DEBUG
    private func presentRequestedCompletionFixtureIfNeeded() -> Bool {
        guard !isPresentingCompletionFixture,
              let fixture = PaceTrainingCompletionFixture.requested() else { return false }
        isPresentingCompletionFixture = true
        let disposition = PaceTrainingCompletionDisposition.resolve(
            candidate: fixture.candidate,
            completion: fixture.completion,
            captureDuration: fixture.captureDuration
        )
        switch disposition {
        case .eligible(let result):
            didAwardXP = true
            hasValidatedResult = true
            completionIssue = nil
            engine.presentResultForUITesting(result)
        case .insufficientSpeech:
            didAwardXP = false
            hasValidatedResult = false
            completionIssue = Self.insufficientSpeechMessage
            engine.reset()
        case .unusableRecording:
            assertionFailure("Pace completion UI fixture must provide a usable terminal receipt")
        }
        return true
    }
    #endif

    private var connectingSurface: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(.white)
            Text("Connecting live transcription…")
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connecting live transcription")
    }

    private var finalizingSurface: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .tint(.white)
            Text("Finishing your recording…")
                .font(Typography.body.weight(.semibold))
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Finishing your recording")
    }

    // MARK: - Setup Surface

    private var setupSurface: some View {
        FocusedPracticeScaffold(
            style: .pace,
            status: "Ready for 75 seconds",
            title: "Pace Training",
            subtitle: "Find a clear rhythm and keep it inside the target zone."
        ) {
            Button {
                CoachHaptic.selectionTap()
                showAdjustments = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.white.opacity(0.14), in: Circle())
                    .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("paceTraining.adjust")
            .accessibilityLabel("Adjust pace training")
        } content: {
            VStack(spacing: Spacing.md) {
                paceSetupCue
                if let completionIssue {
                    FocusedPracticeErrorStatus(message: completionIssue)
                        .accessibilityIdentifier("paceTraining.insufficientSpeech")
                } else if let error = speechVM.connectionError {
                    let presentation = SpeechRecordingIssuePresentation.make(
                        issue: speechVM.recordingIssue,
                        message: error
                    )
                    if presentation.recovery == .openSettings {
                        FocusedPracticePermissionIssueStatus(
                            presentation: presentation,
                            settingsButtonIdentifier: "paceTraining.recordingIssue.openSettings",
                            openSettings: openAppSettingsAfterRecordingIssue
                        )
                        .accessibilityIdentifier("paceTraining.recordingIssue")
                    } else {
                        FocusedPracticeErrorStatus(message: error)
                    }
                }
            }
        }
        .accessibilityIdentifier("paceTraining.screen")
        .safeAreaInset(edge: .bottom) {
            if recordingIssuePresentation?.recovery != .openSettings {
                beginButton
            }
        }
    }

    private var recordingIssuePresentation: SpeechRecordingIssuePresentation? {
        guard let error = speechVM.connectionError else { return nil }
        return SpeechRecordingIssuePresentation.make(
            issue: speechVM.recordingIssue,
            message: error
        )
    }

    private func openAppSettingsAfterRecordingIssue() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        speechVM.connectionError = nil
        openURL(url)
        #endif
    }

    private var paceSetupCue: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Label(engine.subMode.label, systemImage: "metronome.fill")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.focusedTextSecondary)

            Text(engine.subMode == .freestyle ? engine.prompt : engine.passage.title)
                .font(Typography.figtree(size: 24, weight: .semibold, relativeTo: .title3))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text("Aim for \(Int(engine.zoneMin))–\(Int(engine.zoneMax)) words per minute.")
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.focusedTextSecondary)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusedGlassSurface()
        .accessibilityElement(children: .combine)
    }

    private var paceAdjustSheet: some View {
        NavigationStack {
            Form {
                Section("Format") {
                    Picker("Practice format", selection: $engine.subMode) {
                        ForEach(PaceSubMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Target") {
                    LabeledContent("Target", value: "\(Int(engine.targetWPM)) WPM")
                    LabeledContent("Clear zone", value: "\(Int(engine.zoneMin))–\(Int(engine.zoneMax)) WPM")
                }

                Section(engine.subMode == .freestyle ? "Topic" : "Passage") {
                    if engine.subMode == .freestyle {
                        Text(engine.prompt)
                        Button("Choose another topic") {
                            engine.prompt = PaceTrainingEngine.randomPrompt()
                            CoachHaptic.selectionTap()
                        }
                    } else {
                        Text(engine.passage.title)
                            .font(Typography.cardLabel)
                        Text(engine.passage.text)
                            .font(Typography.body)
                    }
                }
            }
            .navigationTitle("Adjust pace training")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showAdjustments = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var beginButton: some View {
        Button {
            CoachHaptic.selectionTap()
            beginCountdown()
        } label: {
            Text("Start pace training")
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(.white, in: Capsule())
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, Spacing.screenH)
        .padding(.bottom, Spacing.sm)
        .accessibilityIdentifier("paceTraining.start")
    }

    // MARK: - Countdown

    private func countdownOverlay(_ n: Int, label: String? = nil) -> some View {
        FocusedPracticeCountdownOverlay(
            style: .pace,
            value: label ?? "\(n)",
            subtitle: label == nil ? "Get ready" : "Start speaking"
        )
    }

    // MARK: - Active Surface

    private var activeSurface: some View {
        VStack(spacing: 0) {
            // Top bar: timer + zone label
            HStack {
                Label(timerLabel, systemImage: "timer")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(engine.zoneLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(zoneColor)
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.sm)

            Spacer()

            // Central WPM display
            VStack(spacing: Spacing.sm) {
                Text("\(Int(engine.currentWPM))")
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(zoneColor)
                    .contentTransition(.numericText())
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: Int(engine.currentWPM))

                Text("WPM")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            // Pace band
            paceBand
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.lg)

            Spacer()

            // Mode-specific content below the band
            if engine.subMode == .freestyle {
                freestyleActiveContent
            } else {
                readAlongActiveContent
            }

            // Bottom stats
            HStack(spacing: Spacing.lg) {
                miniStat(title: "Words", value: "\(engine.totalWords)")
                miniStat(title: "In Zone", value: "\(engine.timeInZone)s")
                miniStat(title: "Target", value: "\(Int(engine.targetWPM))")
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, Spacing.lg)
        }
    }

    private var freestyleActiveContent: some View {
        // Collapsed prompt at bottom
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Label("Topic", systemImage: "text.bubble")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint.opacity(0.7))
            Text(engine.prompt)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .focusedGlassSurface()
        .padding(.horizontal, Spacing.screenH)
        .padding(.bottom, Spacing.md)
    }

    private var readAlongActiveContent: some View {
        // Passage text with highlighted word
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                WrappingHStack(engine.passage.words, id: \.self, spacing: 4, lineSpacing: 6) { word in
                    let idx = engine.passage.words.firstIndex(of: word) ?? 0
                    let isHighlighted = idx == engine.highlightWordIndex
                    let isPast = idx < engine.highlightWordIndex

                    Text(word)
                        .font(.body.weight(isHighlighted ? .bold : .regular))
                        .foregroundStyle(isHighlighted ? tint : (isPast ? .secondary : .primary))
                        .background(
                            isHighlighted
                                ? RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(tint.opacity(0.15))
                                    .padding(.horizontal, -3)
                                    .padding(.vertical, -2)
                                : nil
                        )
                        .id(idx)
                }
                .padding(Spacing.md)
            }
            .frame(maxHeight: 160)
            .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .focusedGlassSurface()
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, Spacing.md)
            .onChange(of: engine.highlightWordIndex) { _, newIdx in
                if reduceMotion {
                    proxy.scrollTo(newIdx, anchor: .center)
                } else {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(newIdx, anchor: .center)
                    }
                }
            }
        }
    }

    /// Horizontal pace band with three zones.
    private var paceBand: some View {
        VStack(spacing: Spacing.xs) {
            GeometryReader { geo in
                let w = geo.size.width
                let h: CGFloat = 8
                let zoneStart = (engine.zoneMin - 60) / 140  // 60 min, 200 max
                let zoneEnd = (engine.zoneMax - 60) / 140

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: h)

                    // Zone overlay (green zone)
                    Capsule()
                        .fill(AppColor.positive.opacity(0.25))
                        .frame(width: w * (zoneEnd - zoneStart), height: h)
                        .offset(x: w * zoneStart)

                    // Current position dot
                    Circle()
                        .fill(zoneColor)
                        .frame(width: 18, height: 18)
                        .shadow(color: zoneColor.opacity(0.4), radius: 6, y: 2)
                        .offset(x: w * engine.bandPosition - 9)
                        .animation(reduceMotion ? .none : .easeInOut(duration: 0.3), value: engine.bandPosition)
                }
                .frame(height: 18)
            }
            .frame(height: 18)

            // Zone labels
            HStack {
                Text("\(Int(engine.zoneMin))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(engine.targetWPM))")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer()
                Text("\(Int(engine.zoneMax))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Result Surface

    private func resultSurface(_ result: PaceTrainingResult) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                resultHero(result)
                resultStats(result)
                Spacer(minLength: Spacing.lg)
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            resultCTA(result)
        }
        .accessibilityIdentifier("paceTraining.result")
    }

    private func resultHero(_ result: PaceTrainingResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: result.verdictIcon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint)
                Text(result.verdictLabel)
                    .font(Typography.bigStat)
            }

            Text(verdictDetail(result))
                .font(Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(tint.opacity(0.20), lineWidth: 1)
        )
    }

    private func resultStats(_ result: PaceTrainingResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                StatCard(title: "In Zone", value: "\(Int(result.zonePercentage * 100))%", tint: AppColor.positive)
                StatCard(title: "Avg WPM", value: "\(Int(result.averageWPM))", tint: tint)
            }
            HStack(spacing: Spacing.sm) {
                StatCard(title: "Peak", value: "\(Int(result.peakWPM))", tint: AppColor.caution)
                StatCard(title: "XP Earned", value: "+\(result.xpEarned)", tint: AppColor.pro)
            }
        }
    }

    private func resultCTA(_ result: PaceTrainingResult) -> some View {
        VStack(spacing: Spacing.sm) {
            Button {
                CoachHaptic.selectionTap()
                didAwardXP = false
                completionIssue = nil
                engine.reset()
            } label: {
                Text("Go Again")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.md)
                    .background(tint, in: Capsule())
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("paceTraining.result.goAgain")

            Button("Done") {
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
            .accessibilityIdentifier("paceTraining.result.done")
        }
        .padding(.horizontal, Spacing.screenH)
        .padding(.bottom, Spacing.sm)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.02), Color.white.opacity(0.72)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    // MARK: - Helpers

    private var timerLabel: String {
        let remaining = max(0, Int(PaceTrainingEngine.drillDuration - engine.elapsed))
        return "\(remaining)s"
    }

    private static let insufficientSpeechMessage =
        "We didn’t catch enough speech to score that pace run. Speak a little longer and try again."

    private var zoneColor: Color {
        if engine.isInZone { return AppColor.positive }
        if engine.currentWPM > engine.zoneMax { return AppColor.warning }
        return AppColor.caution
    }

    private func miniStat(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func verdictDetail(_ result: PaceTrainingResult) -> String {
        let zonePct = Int(result.zonePercentage * 100)
        let avgWPM = Int(result.averageWPM)
        let targetWPM = Int(result.targetWPM)

        if result.zonePercentage >= 0.70 {
            return "You spent \(zonePct)% of the session in the target zone at \(avgWPM) WPM. Strong pace control."
        } else if result.zonePercentage >= 0.40 {
            return "You averaged \(avgWPM) WPM against a \(targetWPM) target and spent \(zonePct)% of the rep in the clear zone."
        } else {
            return "Your average was \(avgWPM) WPM with \(zonePct)% time in zone. Focus on matching the target pace of \(targetWPM) WPM."
        }
    }
}

#if DEBUG
/// Deterministic terminal receipts for rendered completion-integrity tests.
/// They enter the same pure disposition used by the live stop path and never
/// construct a transcription provider or mutate persisted progress.
private enum PaceTrainingCompletionFixture: String {
    case insufficient
    case eligible

    static func requested(arguments: [String] = ProcessInfo.processInfo.arguments) -> Self? {
        guard let index = arguments.firstIndex(of: "UI_TESTING_PACE_COMPLETION_FIXTURE"),
              arguments.indices.contains(index + 1) else { return nil }
        return Self(rawValue: arguments[index + 1])
    }

    var candidate: PaceTrainingResult {
        PaceTrainingResult(
            subMode: .freestyle,
            targetWPM: 130,
            averageWPM: 132,
            zonePercentage: 0.65,
            peakWPM: 155,
            lowestWPM: 105,
            totalWords: self == .eligible ? 103 : 2,
            fillerCount: 0,
            totalDuration: 75,
            wpmSamples: [118, 126, 134, 142, 131]
        )
    }

    var completion: FinalizedTranscript {
        FinalizedTranscript(
            text: self == .eligible
                ? "This terminal pace response contains enough evidence"
                : "Too short",
            receivedFinalResult: true,
            audioByteCount: 4_096
        )
    }

    var captureDuration: TimeInterval { 75 }
}
#endif

// MARK: - Wrapping HStack for Read-Along text

/// A flow layout that wraps content to the next line when it runs out
/// of horizontal space — used for the read-along passage display.
struct WrappingHStack<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let content: (Data.Element) -> Content

    init(
        _ data: Data,
        id: KeyPath<Data.Element, Data.Element>,
        spacing: CGFloat = 4,
        lineSpacing: CGFloat = 4,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.content = content
    }

    @State private var totalHeight = CGFloat.zero

    var body: some View {
        GeometryReader { geo in
            self.generateContent(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func generateContent(in geo: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero

        return ZStack(alignment: .topLeading) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                content(item)
                    .padding(.trailing, spacing)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0
                            height -= d.height + lineSpacing
                        }
                        let result = width
                        if index == data.count - 1 {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if index == data.count - 1 {
                            height = 0
                        }
                        return result
                    }
            }
        }
        .background(viewHeightReader($totalHeight))
    }

    private func viewHeightReader(_ binding: Binding<CGFloat>) -> some View {
        GeometryReader { geo -> Color in
            DispatchQueue.main.async {
                binding.wrappedValue = geo.size.height
            }
            return Color.clear
        }
    }
}
