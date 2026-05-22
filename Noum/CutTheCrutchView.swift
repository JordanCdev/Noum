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

    private let tint: Color = AppColor.modeCrutch
    private static let universalCrutches = ["actually", "basically", "honestly"]

    private var characterStage: NoumCharacter.Stage {
        ProgressionRatchet.resolvedStage(forXP: ProfileManager.shared.xp)
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
            AppColor.screenBackground.ignoresSafeArea()

            switch engine.phase {
            case .setup:
                setupSurface
            case .countdown(let n):
                countdownOverlay(n)
            case .go:
                countdownOverlay(0, label: "GO")
            case .active:
                activeSurface
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
                        .foregroundStyle(.secondary)
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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                introCard
                wordCard
                promptCard
                Spacer(minLength: Spacing.lg)
            }
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            beginCTA
        }
    }

    private var introCard: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            NoumCharacter(
                mood: speechVM.isRecording ? .listening : .calm,
                tint: tint,
                size: 44,
                audioLevel: speechVM.audioLevel,
                stage: characterStage
            )
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Cut the Crutch")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text("Speak for 60 seconds without using one specific word. 3 hearts. Each use chips one. Survive without dropping all three for a clean cut.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var wordCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Avoiding")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack {
                Text("\u{201C}\(engine.avoidedWord)\u{201D}")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
                Spacer()
            }

            Text("Tap to change.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            FlowChips(words: wordOptions) { word in
                let isSelected = word.lowercased() == engine.avoidedWord.lowercased()
                Button {
                    engine.avoidedWord = word.lowercased()
                    CoachHaptic.selectionTap()
                } label: {
                    Text(word)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white : tint)
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? tint : tint.opacity(0.10),
                            in: Capsule()
                        )
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Avoid the word \(word)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text("Prompt")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Button {
                    engine.prompt = PracticeTopics.random()
                    CoachHaptic.selectionTap()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.bold))
                        Text("New prompt")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(tint)
                }
                .buttonStyle(.pressable)
                .accessibilityLabel("Get a different prompt")
            }

            Text(engine.prompt)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var beginCTA: some View {
        Button {
            engine.beginCountdown()
        } label: {
            Text("Begin")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.md)
                .background(tint, in: Capsule())
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.sm)
        }
        .buttonStyle(.pressable)
        .sensoryFeedback(.impact, trigger: engine.phase) { old, new in
            if hapticsSettings.isEnabled, case .countdown = new, case .setup = old { return true }
            return false
        }
        .accessibilityLabel("Begin Cut the Crutch")
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.02), Color.white.opacity(0.72)],
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
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            Text(label ?? "\(n)")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .accessibilityLabel(label ?? "\(n)")
        }
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

                heartsRow
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

    private var heartsRow: some View {
        HStack(spacing: 6) {
            ForEach(0..<engine.config.initialHearts, id: \.self) { index in
                Image(systemName: index < engine.heartsRemaining ? "heart.fill" : "heart.slash")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(index < engine.heartsRemaining ? tint : Color.secondary.opacity(0.35))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(engine.heartsRemaining) of \(engine.config.initialHearts) hearts remaining")
    }

    private var promptStrip: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: 6) {
                Text("Avoiding")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
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
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    private var transcriptCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("You said")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            if speechVM.transcribedText.isEmpty {
                Text("Listening…")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
            } else {
                Text(highlightedTranscript)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
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

    private func verdictDetail(_ result: CutTheCrutchResult) -> String {
        if result.cleanCut && result.violations.isEmpty {
            return "60 seconds, zero uses of \u{201C}\(result.avoidedWord)\u{201D}. That's the rep."
        }
        if result.cleanCut {
            return "You held the line — \(result.violations.count) slip\(result.violations.count == 1 ? "" : "s") but you finished with hearts to spare."
        }
        let secs = Int(result.survivedDuration.rounded())
        return "\(result.violations.count) use\(result.violations.count == 1 ? "" : "s") of \u{201C}\(result.avoidedWord)\u{201D} in \(secs) seconds. Try again — the next rep is the one that lands."
    }

    private func resultStats(_ result: CutTheCrutchResult) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                StatCard(title: "Hearts left", value: "\(result.heartsRemaining)/\(engine.config.initialHearts)", tint: tint)
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
                .textCase(.uppercase)
                .tracking(0.8)

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
