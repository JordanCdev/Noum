import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct SuddenDeathPracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechVM = SpeechRecognizerViewModel()
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @State private var question: String = PracticeTopics.random()
    @State private var elapsed: Int = 0
    @State private var showSummary = false
    @State private var timerTask: Task<Void, Never>? = nil
    @State private var pressureLevel: Int = 1
    @State private var evaluation: PracticeEvaluation?
    @State private var prepCountdown: Int? = nil
    @State private var launchCountdown: Int? = nil
    @State private var showGoCue = false
    @State private var transitionCue: LevelTransitionCue?
    @State private var pressurePulse = false
    @State private var silenceNudge: String? = nil
    @State private var stopReason: String? = nil
    @State private var isEndingSession = false
    @State private var activePressureEvent: PressureEvent?
    @State private var pressureEventsHandled = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    pressureBackground.leading,
                    Color.white,
                    pressureBackground.trailing
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    headerCard

                    if let error = speechVM.connectionError {
                        errorCard(error)
                    }

                    if speechVM.isRecording {
                        progressCard
                        transcriptCard
                        pressureDirectiveCard
                        if let activePressureEvent {
                            pressureEventCard(activePressureEvent)
                        }
                        if let silenceNudge {
                            silenceNudgeCard(silenceNudge)
                        }
                        timerCard
                            .accessibilityIdentifier("suddenDeathTimer")
                    } else if let prepCountdown {
                        prepStage(countdown: prepCountdown)
                    } else {
                        progressCard
                        promptCard
                    }
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
                    } else if prepCountdown == nil {
                        Button("Begin Run") { startSequence() }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(Color.orange, in: Capsule())
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.regularMaterial)
            }

            if let launchCountdown {
                countdownOverlay(value: "\(launchCountdown)", subtitle: "Get ready")
                    .transition(.opacity.combined(with: .scale))
            } else if showGoCue {
                countdownOverlay(value: "GO", subtitle: levelTitle)
                    .transition(.opacity.combined(with: .scale))
            } else if let transitionCue {
                countdownOverlay(value: transitionCue.title, subtitle: transitionCue.subtitle)
                    .transition(.opacity.combined(with: .scale))
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("suddenDeath.screen")
        .onChange(of: speechVM.fillerWordCount) { _, count in
            if count > 0 { stopSession() }
        }
        .navigationDestination(isPresented: $showSummary) {
            SummaryView(
                transcript: speechVM.highlightedText,
                fillerCount: speechVM.fillerWordCount,
                duration: TimeInterval(elapsed),
                score: evaluation?.score,
                progressSegments: max(0, pressureLevel - 1),
                xpEarned: evaluation?.xpEarned ?? 0,
                showDuration: true,
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
                    reset()
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
            Text("Survive until a filler word ends the run")
                .font(.largeTitle.weight(.bold))
            Text("Every 30 seconds the pressure level climbs. Stay clean, stay composed, and see how long you can hold the room.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if speechVM.isRecording {
                Text(pressureCue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(levelTint)
                    .padding(.top, 4)
            } else if let profile = coachingProfileStore.profile {
                Text(entryBrief(for: profile))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(levelTint.opacity(pressurePulse ? 0.85 : 0.25), lineWidth: pressurePulse ? 2.5 : 1)
                .animation(.easeInOut(duration: 0.35), value: pressurePulse)
        )
    }

    private var progressCard: some View {
        HStack(spacing: 12) {
            statCard(title: "Elapsed", value: "\(elapsed)s", tint: .orange)
            statCard(title: "Level", value: "\(pressureLevel)", tint: levelTint)
            statCard(title: "Fillers", value: "\(speechVM.fillerWordCount)", tint: .red)
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Prompt")
                .font(.headline)
            Text(question)
                .font(.title3.weight(.semibold))
            Text("Take a breath, understand the setup, then start the run when you are ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func prepStage(countdown: Int) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Prepare")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text(question)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)

            Text("You have a short setup window. Read the prompt, find your opening line, then the pressure run begins.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(countdown)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.orange)
                    Text("seconds to prepare")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button("Start Now") {
                prepCountdown = nil
                beginLaunchCountdown()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.orange, in: Capsule())
            .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
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
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var pressureDirectiveCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(currentDirective.eyebrow)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(levelTint)
                    .textCase(.uppercase)
                Spacer()
                Text("Level \(pressureLevel)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(currentDirective.title)
                .font(.headline)

            Text(currentDirective.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let constraint = currentDirective.constraint {
                Text(constraint)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(levelTint)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(levelTint.opacity(pressurePulse ? 0.85 : 0.18), lineWidth: pressurePulse ? 2 : 1)
                .animation(.easeInOut(duration: 0.35), value: pressurePulse)
        )
    }

    private var timerCard: some View {
        VStack(spacing: 8) {
            Text("\(elapsed)")
                .font(.system(size: 54, weight: .bold, design: .rounded))
                .foregroundStyle(levelTint)
            Text("Seconds survived")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(levelTitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(levelTint)
            Text(nextMilestoneText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .scaleEffect(pressurePulse ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.35), value: pressurePulse)
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

    private func startSequence() {
        if prepCountdown == nil {
            reset()
            prepCountdown = 15
            Task {
                for count in stride(from: 15, through: 1, by: -1) {
                    await MainActor.run { prepCountdown = count }
                    try? await Task.sleep(for: .seconds(1))
                    if Task.isCancelled { return }
                    let stillPreparing = await MainActor.run { prepCountdown != nil }
                    if !stillPreparing { return }
                }
                await MainActor.run {
                    prepCountdown = nil
                    beginLaunchCountdown()
                }
            }
            return
        }

        prepCountdown = nil
        beginLaunchCountdown()
    }

    private func beginLaunchCountdown() {
        launchCountdown = 3
        Task {
            for count in stride(from: 3, through: 1, by: -1) {
                await MainActor.run { launchCountdown = count }
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run {
                launchCountdown = nil
                showGoCue = true
            }
            try? await Task.sleep(for: .milliseconds(700))
            await MainActor.run {
                showGoCue = false
                startRecording()
            }
        }
    }

    private func startRecording() {
        reset()
        speechVM.prepareSession(mode: .suddenDeath)
        speechVM.startRecording()
        timerTask = Task {
            var seconds = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                seconds += 1
                await MainActor.run {
                    elapsed = seconds
                    let newLevel = max(1, (seconds / 30) + 1)
                    if newLevel != pressureLevel {
                        pressureLevel = newLevel
                        triggerPressurePulse()
                        showTransitionCue(for: newLevel)
                    }
                    if seconds >= 15 && seconds % 15 == 0 {
                        triggerPressureEvent(at: seconds)
                    }
                    if transcriptWordCount == 0 {
                        if seconds == 5 {
                            silenceNudge = "The room is waiting. Start with one clean sentence now."
                        } else if seconds == 10 {
                            silenceNudge = "Still no answer. Commit to the first simple thought and build from there."
                        }
                    } else {
                        silenceNudge = nil
                    }
                }
            }
        }
    }

    private func stopSession() {
        guard !isEndingSession else { return }
        isEndingSession = true
        timerTask?.cancel()
        speechVM.stopRecording()
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            await MainActor.run {
                let result = PracticeEvaluator.evaluateSuddenDeathPractice(
                    transcript: speechVM.transcribedText,
                    fillerCount: speechVM.fillerWordCount,
                    duration: TimeInterval(elapsed),
                    pressureEventsHandled: pressureEventsHandled,
                    recentSessions: speechVM.pastSessions,
                    profile: coachingProfileStore.profile
                )
                if let stopReason {
                    let overridden = PracticeEvaluation(
                        score: result.score,
                        xpEarned: result.xpEarned,
                        headline: "Round stopped",
                        feedback: stopReason,
                        segments: result.segments,
                        insights: result.insights
                    )
                    evaluation = overridden
                    speechVM.annotateLatestSession(
                        score: overridden.score,
                        xpEarned: overridden.xpEarned,
                        headline: overridden.headline,
                        insights: overridden.insights,
                        coachSummary: overridden.feedback
                    )
                } else {
                    evaluation = result
                    speechVM.annotateLatestSession(
                        score: result.score,
                        xpEarned: result.xpEarned,
                        headline: result.headline,
                        insights: result.insights,
                        coachSummary: result.feedback
                    )
                }
                showSummary = true
            }
        }
    }

    private func reset() {
        timerTask?.cancel()
        speechVM.resetCurrentSession()
        question = PracticeTopics.random()
        elapsed = 0
        pressureLevel = 1
        evaluation = nil
        prepCountdown = nil
        launchCountdown = nil
        showGoCue = false
        transitionCue = nil
        pressurePulse = false
        silenceNudge = nil
        stopReason = nil
        isEndingSession = false
        activePressureEvent = nil
        pressureEventsHandled = 0
    }

    private var levelTint: Color {
        switch pressureLevel {
        case 1:
            return .orange
        case 2:
            return .pink
        case 3:
            return .red
        default:
            return .purple
        }
    }

    private var levelTitle: String {
        switch pressureLevel {
        case 1:
            return "Level 1 • Settle in"
        case 2:
            return "Level 2 • Pressure rising"
        case 3:
            return "Level 3 • High pressure"
        default:
            return "Level \(pressureLevel) • Hold your nerve"
        }
    }

    private var nextMilestoneText: String {
        let nextLevelAt = pressureLevel * 30
        let remaining = max(0, nextLevelAt - elapsed)
        return remaining == 0
            ? "Pressure level just increased"
            : "\(remaining)s until level \(pressureLevel + 1)"
    }

    private var pressureCue: String {
        switch pressureLevel {
        case 1:
            return "Land the first sentence cleanly."
        case 2:
            return "Pressure is rising. Keep your pauses deliberate."
        case 3:
            return "The room feels tighter now. Hold your nerve."
        default:
            return "Stay composed. One filler ends the run."
        }
    }

    private var currentDirective: PressureDirective {
        pressureDirective(level: pressureLevel, profile: coachingProfileStore.profile)
    }

    private var pressureBackground: (leading: Color, trailing: Color) {
        switch pressureLevel {
        case 1:
            return (
                Color(red: 0.98, green: 0.93, blue: 0.88),
                Color(red: 0.99, green: 0.95, blue: 0.88)
            )
        case 2:
            return (
                Color(red: 0.99, green: 0.91, blue: 0.90),
                Color(red: 0.99, green: 0.90, blue: 0.94)
            )
        case 3:
            return (
                Color(red: 1.0, green: 0.90, blue: 0.90),
                Color(red: 0.98, green: 0.87, blue: 0.87)
            )
        default:
            return (
                Color(red: 0.95, green: 0.88, blue: 0.96),
                Color(red: 0.92, green: 0.87, blue: 0.98)
            )
        }
    }

    private var transcriptWordCount: Int {
        speechVM.transcribedText.split { !$0.isLetter && !$0.isNumber }.count
    }

    private func triggerPressurePulse() {
        pressurePulse = true
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            await MainActor.run { pressurePulse = false }
        }
    }

    private func triggerPressureEvent(at seconds: Int) {
        let event = pressureEvent(at: seconds, profile: coachingProfileStore.profile)
        activePressureEvent = event
        pressureEventsHandled += 1
        triggerPressurePulse()
        Task {
            try? await Task.sleep(for: .seconds(6))
            await MainActor.run {
                if activePressureEvent?.id == event.id {
                    activePressureEvent = nil
                }
            }
        }
    }

    private func showTransitionCue(for level: Int) {
        let cue = LevelTransitionCue(
            title: "Level \(level)",
            subtitle: transitionSubtitle(for: level)
        )
        transitionCue = cue
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                if transitionCue?.id == cue.id {
                    transitionCue = nil
                }
            }
        }
    }

    private func entryBrief(for profile: CoachingProfile) -> String {
        switch profile.confidenceLevel {
        case .beginner:
            return "This mode will push you, but the goal is still one clean thought at a time."
        case .rebuilding:
            return "Treat this as composure training: steady opening, steady breath, steady finish."
        case .inconsistent:
            return "You already have the ability. This drill tests whether you can hold it under pressure."
        case .confident:
            return "Use this to prove your delivery stays sharp when the pressure keeps climbing."
        }
    }

    private func pressureDirective(level: Int, profile: CoachingProfile?) -> PressureDirective {
        let challenge = profile?.biggestChallenge
        let confidence = profile?.confidenceLevel

        let body: String
        let constraint: String?

        switch level {
        case 1:
            body = baselineDirective(for: challenge, confidence: confidence)
            constraint = "Deliver one clear opening thought before you expand."
        case 2:
            body = secondLevelDirective(for: challenge)
            constraint = "Add one concrete example without rushing."
        case 3:
            body = thirdLevelDirective(for: challenge)
            constraint = "No filler. No restart. Clean transitions only."
        case 4:
            body = "Now make it sound room-ready. Keep your pace calm and your language deliberate, as if people are judging every sentence."
            constraint = "Turn the answer into a concise, persuasive mini-talk."
        default:
            body = "This is keynote territory now. Stay composed, hold your structure, and keep sounding intentional even as the pressure stacks up."
            constraint = "Keep authority in your tone while protecting clean pauses."
        }

        return PressureDirective(
            eyebrow: level >= 4 ? "High Pressure" : "Pressure Cue",
            title: pressureTitle(for: level),
            body: body,
            constraint: constraint
        )
    }

    private func pressureTitle(for level: Int) -> String {
        switch level {
        case 1: return "Establish control"
        case 2: return "Expand under pressure"
        case 3: return "Stay clean while the room tightens"
        case 4: return "Sound decisive"
        default: return "Hold the room"
        }
    }

    private func transitionSubtitle(for level: Int) -> String {
        switch level {
        case 2:
            return "Pressure rising. Keep the next idea clean."
        case 3:
            return "No loose transitions now. Stay composed."
        case 4:
            return "Sound decisive. The room is judging every line."
        default:
            return "Hold your nerve and keep control."
        }
    }

    private func baselineDirective(for challenge: SpeakingChallenge?, confidence: ConfidenceLevel?) -> String {
        switch challenge {
        case .fillerWords:
            return "Start with one calm sentence and let silence buy you time before the next point."
        case .rambling:
            return "Answer directly first, then add one supporting idea so the structure stays tight."
        case .freezing:
            return "Say the first simple sentence quickly, then build from it instead of waiting for a perfect answer."
        case .rushing:
            return "Slow the first sentence down on purpose so the rest of the answer follows your pace."
        case .none:
            switch confidence {
            case .beginner:
                return "Keep it simple. One clear point is enough to win the opening phase."
            case .rebuilding:
                return "Find your rhythm early and let the opening settle you."
            case .inconsistent:
                return "Show that your good reps are repeatable even when the pressure starts rising."
            case .confident:
                return "Set the tone quickly and make the room believe you’re in control."
            case .none:
                return "Open cleanly and establish control before you try to do more."
            }
        }
    }

    private func secondLevelDirective(for challenge: SpeakingChallenge?) -> String {
        switch challenge {
        case .fillerWords:
            return "The next risk is thinking out loud. Keep each pause quiet and intentional before you move to the example."
        case .rambling:
            return "Pressure rises here because answers start to wander. Keep everything tied back to your main point."
        case .freezing:
            return "Don’t overthink the next section. Add one example and keep momentum."
        case .rushing:
            return "Pressure can speed you up here. Keep the pace measured while you expand."
        case .none:
            return "Now show range: keep the answer alive without sounding scattered."
        }
    }

    private func thirdLevelDirective(for challenge: SpeakingChallenge?) -> String {
        switch challenge {
        case .fillerWords:
            return "This is where filler habits usually show. Protect every transition with a clean pause."
        case .rambling:
            return "The middle of the answer must stay disciplined now. If the structure drifts, the pressure wins."
        case .freezing:
            return "The pressure is high enough now that hesitation will feel obvious. Commit to the next sentence."
        case .rushing:
            return "Keep sounding composed while the internal tempo rises. Calm beats fast here."
        case .none:
            return "This is where solid speakers separate from shaky ones. Keep the answer structured and intentional."
        }
    }

    private func pressureEvent(at seconds: Int, profile: CoachingProfile?) -> PressureEvent {
        let level = max(1, (seconds / 30) + 1)
        let challenge = profile?.biggestChallenge
        let context = profile?.speakingContext

        switch (level, challenge, context) {
        case (1, .some(.freezing), _):
            return PressureEvent(
                title: "No overthinking",
                body: "Answer directly now. Do not wait for a perfect line.",
                constraint: "Give the next sentence immediately."
            )
        case (1, .some(.rambling), _):
            return PressureEvent(
                title: "Tighten it",
                body: "Restate your point in one clean sentence before you expand again.",
                constraint: "One sentence. No wandering."
            )
        case (2, _, .some(.work)):
            return PressureEvent(
                title: "Boardroom pressure",
                body: "Imagine someone senior just asked for a concrete example.",
                constraint: "Give one example right now."
            )
        case (2, _, .some(.interviews)):
            return PressureEvent(
                title: "Interview follow-up",
                body: "A recruiter interrupts and asks what the result was.",
                constraint: "Add a result or outcome in the next sentence."
            )
        case (2, _, .some(.presentations)):
            return PressureEvent(
                title: "Audience test",
                body: "The room needs a clearer takeaway.",
                constraint: "State your key message cleanly now."
            )
        case (3, .some(.rushing), _):
            return PressureEvent(
                title: "Slow without losing control",
                body: "The pressure is trying to speed you up. Stay deliberate.",
                constraint: "Make the next sentence your calmest one."
            )
        case (3, .some(.fillerWords), _):
            return PressureEvent(
                title: "Protect the transition",
                body: "This is where filler words usually break the run.",
                constraint: "Use one clean pause before the next idea."
            )
        case (4..., _, .some(.presentations)):
            return PressureEvent(
                title: "Keynote mode",
                body: "The answer now has to sound room-ready and authoritative.",
                constraint: "Deliver the next line like a closing statement."
            )
        case (4..., _, _):
            return PressureEvent(
                title: "High-stakes follow-up",
                body: "You are being judged on clarity and composure now.",
                constraint: "Sharpen the next sentence and land it confidently."
            )
        default:
            return PressureEvent(
                title: "Pressure shift",
                body: "The room just got harder. Keep control and adapt without filler.",
                constraint: "Answer the next moment more cleanly than the last."
            )
        }
    }

    private func countdownOverlay(value: String, subtitle: String) -> some View {
        ZStack {
            Color.black.opacity(0.10)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                Text(value)
                    .font(.system(size: 76, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.92))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(levelTint.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 34, style: .continuous))
            .padding(36)
            .shadow(color: .black.opacity(0.16), radius: 24, y: 18)
        }
    }

    private func silenceNudgeCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func pressureEventCard(_ event: PressureEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Live Pressure Event")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .textCase(.uppercase)
                Spacer()
                Text("Respond now")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Text(event.title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)

            Text(event.body)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))

            Text(event.constraint)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(levelTint.gradient, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: levelTint.opacity(0.20), radius: 18, y: 12)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func dismiss(times: Int) {
        guard times > 0 else { return }
        withAnimation(.none) { dismiss() }
        if times > 1 {
            DispatchQueue.main.async { dismiss(times: times - 1) }
        }
    }
}

private struct PressureDirective {
    let eyebrow: String
    let title: String
    let body: String
    let constraint: String?
}

private struct PressureEvent: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let body: String
    let constraint: String
}

private struct LevelTransitionCue: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
}
#endif
