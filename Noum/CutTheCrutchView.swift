#if canImport(SwiftUI)
import SwiftUI

// MARK: - Cut the Crutch — Playable Screen

@available(iOS 17.0, macOS 12.0, *)
struct CutTheCrutchView: View {
    @Binding var navigationPath: NavigationPath

    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)
    @StateObject private var engine: CutTheCrutchEngine
    @StateObject private var hapticsSettings = HapticsSettings.shared
    @StateObject private var profileManager = ProfileManager.shared
    @StateObject private var clutchWordStore = ClutchWordStore.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var didAwardXP = false
    @State private var showAdjustments = false

    private let tint: Color = AppColor.modeCrutch
    private static let universalCrutches = ["actually", "basically", "honestly"]

    private var characterStage: NoumCharacter.Stage {
        ProgressionRatchet.resolvedStage(forXP: ProfileManager.shared.xp)
    }

    private var isResultPhase: Bool {
        if case .ended = engine.phase { return true }
        return false
    }

    init(navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath
        let firstClutch = ClutchWordStore.shared.topClutchWords.first?.word.lowercased()
        let initialWord = firstClutch ?? "actually"
        let initialPrompt = PracticeTopics.random()
        _engine = StateObject(wrappedValue: CutTheCrutchEngine(
            avoidedWord: initialWord,
            prompt: initialPrompt
        ))
    }

    // MARK: Body

    var body: some View {
        ZStack {
            if case .ended = engine.phase {
                AppColor.screenBackground.ignoresSafeArea()
            } else {
                FocusedPracticeBackground(style: .crutch)
            }

            switch engine.phase {
            case .setup:
                setupSurface
            case .countdown(let n):
                countdownOverlay(n)
            case .go:
                countdownOverlay(0, label: "GO")
            case .active:
                activeSurface
                    .environment(\.colorScheme, .dark)
            case .ended(let result):
                resultSurface(result)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(role: .cancel) {
                    speechVM.stopRecording()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(isResultPhase ? Color.secondary : Color.white)
                }
                .accessibilityLabel("Close")
            }
        }
        .onChange(of: speechVM.transcribedText) { _, newValue in
            engine.ingestTranscript(newValue)
        }
        .onChange(of: engine.phase) { _, newPhase in
            handlePhase(newPhase)
        }
        .onDisappear {
            speechVM.stopRecording()
        }
        .task {
            // Quick Start handshake — picker armed Cut the Crutch for a
            // one-tap launch. The engine's init already picked a top
            // user crutch (or "actually") + a random prompt, so the
            // countdown can fire immediately with sensible defaults.
            if case .setup = engine.phase, PracticeModeQuickStart.consumeCrutch() {
                engine.beginCountdown()
            }
        }
        .sheet(isPresented: $showAdjustments) {
            crutchAdjustSheet
        }
    }

    private func handlePhase(_ phase: CutTheCrutchPhase) {
        switch phase {
        case .active:
            speechVM.shouldRecordPracticeSession = false
            speechVM.sessionPrompt = engine.prompt
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

    // MARK: - Setup

    private var setupSurface: some View {
        FocusedPracticeScaffold(
            style: .crutch,
            status: "Ready for 60 seconds",
            title: "Cut the Crutch",
            subtitle: "Remove one reflex word. Keep the thought moving."
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
            .accessibilityIdentifier("cutTheCrutch.adjust")
            .accessibilityLabel("Adjust Cut the Crutch")
        } content: {
            crutchSetupCue
        }
        .accessibilityIdentifier("cutTheCrutch.screen")
        .safeAreaInset(edge: .bottom) {
            beginCTA
        }
    }

    private var crutchSetupCue: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Avoid this reflex word")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.focusedTextSecondary)

            Text("\u{201C}\(engine.avoidedWord)\u{201D}")
                .font(Typography.figtree(size: 36, weight: .bold, relativeTo: .title))
                .foregroundStyle(.white)

            Text(engine.prompt)
                .font(Typography.body)
                .foregroundStyle(AppColor.focusedTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusedGlassSurface()
        .accessibilityElement(children: .combine)
    }

    private var crutchAdjustSheet: some View {
        NavigationStack {
            Form {
                Section("Reflex word") {
                    Picker("Word to avoid", selection: $engine.avoidedWord) {
                        ForEach(wordOptions, id: \.self) { word in
                            Text(word.capitalized).tag(word.lowercased())
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Prompt") {
                    Text(engine.prompt)
                    Button("Choose another prompt") {
                        engine.prompt = PracticeTopics.random()
                        CoachHaptic.selectionTap()
                    }
                }

                Section {
                    Text("Three uses end the rep. Pausing or rephrasing keeps it alive.")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Adjust Cut the Crutch")
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

    private var beginCTA: some View {
        Button {
            engine.beginCountdown()
        } label: {
            Text("Start Cut the Crutch")
                .font(.headline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(.white, in: Capsule())
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.impact, trigger: engine.phase) { old, new in
            if hapticsSettings.isEnabled, case .countdown = new, case .setup = old { return true }
            return false
        }
        .accessibilityIdentifier("cutTheCrutch.start")
        .accessibilityLabel("Start Cut the Crutch")
        .background(
            LinearGradient(
                colors: [Color.clear, Color.black.opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var wordOptions: [String] {
        var words: [String] = []
        let topUserWords = clutchWordStore.topClutchWords.prefix(2).map { $0.word.lowercased() }
        for word in topUserWords where !words.contains(word) {
            words.append(word)
        }
        for word in Self.universalCrutches where !words.contains(word) {
            words.append(word)
        }
        return Array(words.prefix(5))
    }

    // MARK: - Countdown

    private func countdownOverlay(_ n: Int, label: String? = nil) -> some View {
        FocusedPracticeCountdownOverlay(
            style: .crutch,
            value: label ?? "\(n)",
            subtitle: label == nil ? "Get ready" : "Start speaking"
        )
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale))
    }

    // MARK: - Active

    private var activeSurface: some View {
        VStack(spacing: Spacing.md) {
            statusBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    promptStrip
                    transcriptCard
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }

            endRoundCTA
        }
    }

    private var statusBar: some View {
        VStack(spacing: Spacing.xs) {
            HStack(alignment: .center, spacing: Spacing.md) {
                NoumCharacter(
                    mood: speechVM.isRecording ? .listening : .calm,
                    tint: tint,
                    size: 36,
                    audioLevel: speechVM.audioLevel,
                    stage: characterStage
                )
                .accessibilityHidden(true)

                slipAllowanceRow
                Spacer()
                Text(timeRemainingLabel)
                    .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                    .accessibilityLabel("\(Int(secondsRemaining)) seconds remaining")
            }

            ComposureMeter(progress: engine.composure, tint: tint)
                .frame(height: 8)
        }
        .padding(.horizontal, Spacing.screenH)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(.regularMaterial)
    }

    private var slipAllowanceRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<engine.config.initialHearts, id: \.self) { index in
                Image(systemName: index < engine.heartsRemaining ? "shield.fill" : "xmark.circle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(index < engine.heartsRemaining ? tint : Color.secondary.opacity(0.35))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(engine.heartsRemaining) of \(engine.config.initialHearts) slips remaining")
    }

    private var promptStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 6) {
                Text("Avoiding")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("\u{201C}\(engine.avoidedWord)\u{201D}")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)
            }

            Text(engine.prompt)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.focusedGlassFill, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .focusedGlassSurface()
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("You said")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            if speechVM.transcribedText.isEmpty {
                Text("Listening…")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                // Live surface: calm the red filler marks to the dim
                // neutral register (A3 rule — mid-rep is never alarmed).
                // The summary's red ledger reads the raw value untouched.
                Text(LiveTranscriptStyle.calmed(highlightedTranscript))
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.focusedGlassFill, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .focusedGlassSurface()
    }

    /// Renders the transcript with the avoided word tinted in `modeCrutch`.
    private var highlightedTranscript: AttributedString {
        var result = AttributedString(speechVM.transcribedText)
        let lowerWord = engine.avoidedWord.lowercased()
        let raw = speechVM.transcribedText
        var searchStart = raw.startIndex
        while searchStart < raw.endIndex,
              let range = raw.range(of: lowerWord, options: [.caseInsensitive, .literal], range: searchStart..<raw.endIndex) {
            let nsRange = NSRange(range, in: raw)
            if isWholeWord(in: raw, nsRange: nsRange),
               let attrRange = Range(nsRange, in: result) {
                result[attrRange].foregroundColor = tint
                result[attrRange].font = .body.weight(.bold)
            }
            searchStart = range.upperBound
        }
        return result
    }

    private func isWholeWord(in text: String, nsRange: NSRange) -> Bool {
        let lowerBound = nsRange.location
        let upperBound = nsRange.location + nsRange.length
        let chars = Array(text)
        let leftOK: Bool = {
            if lowerBound == 0 { return true }
            let prev = chars[lowerBound - 1]
            return !prev.isLetter && !prev.isNumber
        }()
        let rightOK: Bool = {
            if upperBound >= chars.count { return true }
            let next = chars[upperBound]
            return !next.isLetter && !next.isNumber
        }()
        return leftOK && rightOK
    }

    private var endRoundCTA: some View {
        Button {
            engine.userEnded()
        } label: {
            Text("End round")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.sm)
                .padding(.horizontal, Spacing.screenH)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("End the round now")
        .accessibilityHint("Stops recording and shows your result.")
        .padding(.bottom, Spacing.sm)
    }

    private var secondsRemaining: TimeInterval {
        max(0, engine.config.survivalDuration - engine.elapsed)
    }

    private var timeRemainingLabel: String {
        let s = Int(secondsRemaining.rounded(.up))
        return ":\(String(format: "%02d", s))"
    }

    // MARK: - Result

    private func resultSurface(_ result: CutTheCrutchResult) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                resultHero(result)
                resultStats(result)
                if !result.violations.isEmpty {
                    violationsCard(result.violations)
                }
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

    private func resultHero(_ result: CutTheCrutchResult) -> some View {
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

    private func verdictDetail(_ result: CutTheCrutchResult) -> String {
        if result.cleanCut && result.violations.isEmpty {
            return "60 seconds, zero uses of \u{201C}\(result.avoidedWord)\u{201D}. That's the rep."
        }
        if result.cleanCut {
            return "You held the line — \(result.violations.count) slip\(result.violations.count == 1 ? "" : "s"), and the rep stayed alive."
        }
        let secs = Int(result.survivedDuration.rounded())
        return "\(result.violations.count) use\(result.violations.count == 1 ? "" : "s") of \u{201C}\(result.avoidedWord)\u{201D} in \(secs) seconds. Try again — the next rep is the one that lands."
    }

    private func resultStats(_ result: CutTheCrutchResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                StatCard(title: "Slips left", value: "\(result.heartsRemaining)/\(engine.config.initialHearts)", tint: tint)
                StatCard(title: "Survived", value: survivedLabel(result), tint: AppColor.brandBlue)
            }
            HStack(spacing: Spacing.sm) {
                StatCard(title: "Score", value: "\(result.score)/10", tint: AppColor.positive)
                StatCard(title: "XP earned", value: "+\(result.xpEarned)", tint: AppColor.pro)
            }
        }
    }

    private func survivedLabel(_ result: CutTheCrutchResult) -> String {
        let s = Int(result.survivedDuration.rounded())
        return "\(s)s"
    }

    private func violationsCard(_ violations: [CutTheCrutchViolation]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Where it landed")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)

            ForEach(violations) { v in
                violationRow(v)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private func violationRow(_ v: CutTheCrutchViolation) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(":\(String(format: "%02d", Int(v.timeFromStart.rounded())))")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .frame(width: 36, alignment: .leading)
            Text(v.fragment.isEmpty ? "—" : "…\(v.fragment)…")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private func resultCTA(_ result: CutTheCrutchResult) -> some View {
        VStack(spacing: Spacing.sm) {
            Button {
                CoachHaptic.selectionTap()
                let nextWord = engine.avoidedWord
                let nextPrompt = PracticeTopics.random()
                didAwardXP = false
                engine.reset(avoidedWord: nextWord, prompt: nextPrompt)
            } label: {
                Text("Try another rep")
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
}

// MARK: - Composure Meter

@available(iOS 17.0, macOS 12.0, *)
struct ComposureMeter: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(tint.opacity(0.12))
                RoundedRectangle(cornerRadius: 4)
                    .fill(tint)
                    .frame(width: geo.size.width * max(0, min(1, progress)))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Composure")
        .accessibilityValue("\(Int((progress * 100).rounded())) percent")
    }
}

// MARK: - FlowChips

/// Tiny wrap-on-overflow chip layout for the word selector.
@available(iOS 17.0, macOS 12.0, *)
struct FlowChips<Content: View>: View {
    let words: [String]
    @ViewBuilder let chip: (String) -> Content

    var body: some View {
        FlexibleHStack(data: words, spacing: 8, alignment: .leading) { word in
            chip(word)
        }
    }
}

@available(iOS 17.0, macOS 12.0, *)
private struct FlexibleHStack<Data: Hashable, Content: View>: View {
    let data: [Data]
    let spacing: CGFloat
    let alignment: HorizontalAlignment
    @ViewBuilder let content: (Data) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        VStack {
            GeometryReader { geo in
                self.generate(in: geo)
            }
        }
        .frame(height: totalHeight)
    }

    private func generate(in geo: GeometryProxy) -> some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return ZStack(alignment: Alignment(horizontal: alignment, vertical: .top)) {
            ForEach(data, id: \.self) { item in
                content(item)
                    .padding(.trailing, spacing)
                    .padding(.bottom, spacing)
                    .alignmentGuide(.leading) { d in
                        if abs(width - d.width) > geo.size.width {
                            width = 0
                            height -= d.height
                        }
                        let result = width
                        if item == data.last {
                            width = 0
                        } else {
                            width -= d.width
                        }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = height
                        if item == data.last { height = 0 }
                        return result
                    }
            }
        }
        .background(heightReader)
    }

    private var heightReader: some View {
        GeometryReader { geo -> Color in
            DispatchQueue.main.async { totalHeight = geo.size.height }
            return Color.clear
        }
    }
}

// MARK: - Previews

#if DEBUG
@available(iOS 17.0, *)
#Preview("Cut the Crutch — setup") {
    NavigationStack {
        CutTheCrutchView(navigationPath: .constant(NavigationPath()))
    }
}
#endif

#endif
