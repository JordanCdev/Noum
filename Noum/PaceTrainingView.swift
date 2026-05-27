import SwiftUI

/// Pace Training mini-game — trains real-time speaking pace awareness.
/// Two sub-modes: Freestyle (speak on a topic) and Read-Along (match
/// karaoke-style word highlighting at target WPM).
struct PaceTrainingView: View {
    @Binding var navigationPath: NavigationPath
    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var engine = PaceTrainingEngine()
    @EnvironmentObject private var profileManager: ProfileManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var didAwardXP = false

    private let tint = AppColor.modePace

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            content
        }
        .navigationBarBackButtonHidden(!(engine.phase == .setup))
        .onChange(of: speechVM.transcribedText) { _, newValue in
            engine.ingestTranscript(newValue)
        }
        .onChange(of: speechVM.fillerWordCount) { _, newValue in
            engine.updateFillerCount(newValue)
        }
        .onChange(of: engine.phase) { _, newPhase in
            handlePhase(newPhase)
        }
        .onAppear {
            engine.prompt = PaceTrainingEngine.randomPrompt()
            engine.passage = PaceTrainingEngine.passages.randomElement() ?? PaceTrainingEngine.passages[0]
        }
        .onDisappear {
            speechVM.stopRecording()
        }
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
        case .active:
            activeSurface
                .transition(.opacity)
        case .ended(let result):
            resultSurface(result)
                .transition(.opacity)
        }
    }

    // MARK: - Phase Handler

    private func handlePhase(_ phase: PaceTrainingPhase) {
        switch phase {
        case .active:
            speechVM.shouldRecordPracticeSession = false
            speechVM.sessionPrompt = engine.subMode == .freestyle ? engine.prompt : engine.passage.title
            speechVM.prepareSession(mode: .timed)
            speechVM.startRecording()
        case .ended(let result):
            speechVM.stopRecording()
            if !didAwardXP {
                profileManager.addXP(result.xpEarned)
                didAwardXP = true
            }
        default:
            break
        }
    }

    // MARK: - Setup Surface

    private var setupSurface: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // Title
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    HStack(spacing: Spacing.sm) {
                        Image(systemName: "metronome")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(tint)
                        Text("Pace Training")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                    }
                    Text("Match the target speaking pace for 75 seconds.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Sub-mode picker
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Mode")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Picker("Sub-mode", selection: $engine.subMode) {
                        ForEach(PaceSubMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Target info
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Target: \(Int(engine.targetWPM)) WPM")
                        .font(.headline)
                    Text("Zone: \(Int(engine.zoneMin))–\(Int(engine.zoneMax)) WPM")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                        .stroke(tint.opacity(0.20), lineWidth: 1)
                )

                // Preview card
                if engine.subMode == .freestyle {
                    promptPreviewCard
                } else {
                    passagePreviewCard
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.sm)
        }
        .safeAreaInset(edge: .bottom) {
            beginButton
        }
    }

    private var promptPreviewCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Your Topic", systemImage: "text.bubble")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            Text(engine.prompt)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private var passagePreviewCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label(engine.passage.title, systemImage: "text.alignleft")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            Text(engine.passage.text)
                .font(.body)
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
    }

    private var beginButton: some View {
        Button {
            CoachHaptic.selectionTap()
            engine.beginCountdown()
        } label: {
            Text("Begin")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(tint, in: Capsule())
        }
        .buttonStyle(.pressable)
        .padding(.horizontal, Spacing.screenH)
        .padding(.bottom, Spacing.sm)
    }

    // MARK: - Countdown

    private func countdownOverlay(_ n: Int, label: String? = nil) -> some View {
        VStack(spacing: Spacing.md) {
            Text(label ?? "\(n)")
                .font(.system(size: 80, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text("Get ready to speak")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .animation(.easeInOut(duration: 0.3), value: Int(engine.currentWPM))

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
        .background(AppColor.cardBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
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
            .background(AppColor.cardBackground.opacity(0.6), in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .padding(.horizontal, Spacing.screenH)
            .padding(.bottom, Spacing.md)
            .onChange(of: engine.highlightWordIndex) { _, newIdx in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newIdx, anchor: .center)
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
    }

    private func resultHero(_ result: PaceTrainingResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: result.verdictIcon)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(tint)
                Text(result.verdictLabel)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
            }

            Text(verdictDetail(result))
                .font(.subheadline)
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

            Button("Done") {
                dismiss()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 44)
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
            return "You averaged \(avgWPM) WPM against a target of \(targetWPM). \(zonePct)% time in zone — keep working on steadying your rhythm."
        } else {
            return "Your average was \(avgWPM) WPM with \(zonePct)% time in zone. Focus on matching the target pace of \(targetWPM) WPM."
        }
    }
}

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
