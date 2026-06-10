import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI) && canImport(AVFoundation)

/// Beat the Brake — a live WPM gauge drill.
/// User speaks for 45s. A large arc gauge shows real-time WPM.
/// The zone (the shared `ConversationalPaceBand`) is highlighted green.
/// Outside = red/amber. Success: 60%+ time in the zone.
struct BeatTheBrakeView: View {
    let drill: DrillRecommendationV2
    let prompt: String?
    let onComplete: (MiniDrillOutcome) -> Void
    let onCancel: () -> Void

    @StateObject private var speechVM = SpeechRecognizerViewModel(preloadOnInit: false)

    @State private var phase: DrillPhase = .ready
    @State private var elapsedSeconds: Int = 0
    @State private var countdownValue: Int = 3
    @State private var timerTask: Task<Void, Never>?

    // WPM tracking
    @State private var currentWPM: Double = 0
    @State private var previousWordCount: Int = 0
    @State private var wordTimestamps: [(count: Int, time: Date)] = []
    @State private var timeInZone: Int = 0
    @State private var peakWPM: Double = 0
    @State private var lowestWPM: Double = 999
    @State private var wasInZone: Bool = false
    @State private var wpmSamples: [Double] = []
    @State private var recordingStartDate: Date?

    private let drillDuration: Int = 45
    // The ONE conversational pace zone — shared with PaceTrainingEngine,
    // DailyChallenge copy, and live path state. Never hardcode a second
    // threshold here: three drills disagreeing on "in zone" reads as a bug.
    private let zoneMin: Double = ConversationalPaceBand.minWPM
    private let zoneMax: Double = ConversationalPaceBand.maxWPM
    private let gaugeMin: Double = 60
    private let gaugeMax: Double = 200

    enum DrillPhase {
        case ready, countdown, speaking, finishing
    }

    private var isInZone: Bool {
        currentWPM >= zoneMin && currentWPM <= zoneMax
    }

    private var zoneLabel: String {
        if currentWPM < 10 { return "SPEAK" }
        if currentWPM < zoneMin { return "TOO SLOW" }
        if currentWPM > zoneMax { return "TOO FAST" }
        return "IN ZONE"
    }

    private var zoneLabelColor: Color {
        if currentWPM < 10 { return .white.opacity(0.4) }
        if isInZone { return AppColor.positive }
        return .red
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                constraintBanner
                    .padding(.top, 8)

                Spacer()

                // Center: gauge + readout
                ZStack {
                    switch phase {
                    case .ready:
                        readyContent
                    case .countdown:
                        Text("\(countdownValue)")
                            .font(.system(size: 56, weight: .bold, design: .rounded))
                            .foregroundStyle(drill.tint)
                            .transition(.scale.combined(with: .opacity))
                    case .speaking:
                        wpmGauge
                    case .finishing:
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(drill.tint)
                    }
                }

                Spacer()

                // Bottom controls
                VStack(spacing: 20) {
                    if phase == .speaking {
                        // Zone time tracker
                        Text("\(timeInZone)s in zone / \(drillDuration)s")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.5))

                        // Filler count
                        if speechVM.fillerWordCount > 0 {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 6, height: 6)
                                Text("\(speechVM.fillerWordCount) filler\(speechVM.fillerWordCount == 1 ? "" : "s")")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.red.opacity(0.8))
                            }
                            .transition(.opacity)
                        }
                    }

                    // Prompt
                    if let prompt, phase == .speaking || phase == .ready {
                        Text("\"\(prompt)\"")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(3)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Action button
                    switch phase {
                    case .ready:
                        Button {
                            startCountdown()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.subheadline.weight(.bold))
                                Text("Begin Drill")
                                    .font(.subheadline.weight(.bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .background(drill.tint, in: Capsule())
                        }
                        .buttonStyle(.pressable)
                    case .countdown:
                        EmptyView()
                    case .speaking:
                        Button {
                            finishDrill()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "stop.fill")
                                    .font(.caption.weight(.bold))
                                Text("Stop")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.15), in: Capsule())
                        }
                        .buttonStyle(.pressable)
                    case .finishing:
                        EmptyView()
                    }
                }
                .padding(.bottom, 40)
            }
            .padding(.horizontal, Spacing.screenH)

            // Close button (top-left)
            VStack {
                HStack {
                    Button {
                        cancelDrill()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.pressable)
                    .accessibilityLabel("Close drill")
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()
            }
        }
        .interactiveDismissDisabled(phase == .speaking)
    }

    // MARK: - Ready Content

    private var readyContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "gauge.open.with.lines.needle.33percent")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(drill.tint)
            Text("Ready")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)
        }
    }

    // MARK: - WPM Gauge

    private var wpmGauge: some View {
        VStack(spacing: 16) {
            ZStack {
                // Background arc
                ArcShape(startAngle: .degrees(135), endAngle: .degrees(405), lineWidth: 14)
                    .stroke(.white.opacity(0.08), lineWidth: 14)
                    .frame(width: 200, height: 200)

                // Zone segment (green arc for the shared conversational band)
                ArcShape(
                    startAngle: .degrees(angleForWPM(zoneMin)),
                    endAngle: .degrees(angleForWPM(zoneMax)),
                    lineWidth: 14
                )
                .stroke(AppColor.positive.opacity(isInZone ? 0.4 : 0.15), lineWidth: 14)
                .frame(width: 200, height: 200)

                // Current position indicator
                ArcShape(
                    startAngle: .degrees(135),
                    endAngle: .degrees(angleForWPM(min(currentWPM, gaugeMax))),
                    lineWidth: 14
                )
                .stroke(
                    isInZone ? AppColor.positive : (currentWPM > zoneMax ? .red : .orange),
                    style: StrokeStyle(lineWidth: 14, lineCap: .round)
                )
                .frame(width: 200, height: 200)
                .animation(.easeOut(duration: 0.5), value: currentWPM)

                // Needle
                NeedleShape()
                    .fill(isInZone ? AppColor.positive : .red)
                    .frame(width: 4, height: 70)
                    .offset(y: -35)
                    .rotationEffect(.degrees(angleForWPM(min(currentWPM, gaugeMax)) - 270))
                    .animation(.easeOut(duration: 0.5), value: currentWPM)

                // Center hub
                Circle()
                    .fill(.white.opacity(0.15))
                    .frame(width: 12, height: 12)

                // Center readout
                VStack(spacing: 2) {
                    Text("\(Int(currentWPM))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.3), value: Int(currentWPM))
                    Text("WPM")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .offset(y: 20)
            }

            // Zone label
            Text(zoneLabel)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(zoneLabelColor)

            // Elapsed time
            Text("\(elapsedSeconds)s / \(drillDuration)s")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.35))
        }
    }

    // MARK: - Constraint Banner

    private var constraintBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "gauge.open.with.lines.needle.33percent")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(drill.tint)
                Text(drill.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            Text(drill.constraint)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(drill.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - Gauge Math

    /// Maps a WPM value to a degree on the arc (135° to 405°, i.e. 270° sweep).
    private func angleForWPM(_ wpm: Double) -> Double {
        let fraction = (wpm - gaugeMin) / (gaugeMax - gaugeMin)
        let clamped = max(0, min(1, fraction))
        return 135 + clamped * 270
    }

    // MARK: - Actions

    private func startCountdown() {
        withAnimation(.snappySpring) { phase = .countdown }
        CoachHaptic.drillStart()

        Task {
            for i in stride(from: 3, through: 1, by: -1) {
                await MainActor.run {
                    withAnimation(.snappySpring) { countdownValue = i }
                }
                CoachHaptic.countdownBeat()
                try? await Task.sleep(for: .seconds(1))
            }
            await MainActor.run { startSpeaking() }
        }
    }

    private func startSpeaking() {
        withAnimation(.standardSpring) { phase = .speaking }

        speechVM.sessionPrompt = prompt
        speechVM.shouldRecordPracticeSession = false
        speechVM.prepareSession(mode: .timed)
        recordingStartDate = Date()
        speechVM.startRecording()

        timerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    elapsedSeconds += 1
                    updateWPM()

                    if elapsedSeconds >= drillDuration {
                        finishDrill()
                    }
                }
            }
        }
    }

    private func updateWPM() {
        let totalWords = speechVM.transcribedText.split(separator: " ").count
        let now = Date()

        // Record this sample
        wordTimestamps.append((count: totalWords, time: now))

        // Use a rolling 5-second window
        let windowStart = now.addingTimeInterval(-5)
        wordTimestamps.removeAll { $0.time < windowStart.addingTimeInterval(-1) }

        if let oldest = wordTimestamps.first(where: { $0.time >= windowStart }) {
            let wordDelta = totalWords - oldest.count
            let timeDelta = now.timeIntervalSince(oldest.time)
            if timeDelta > 0.5 {
                let newWPM = Double(wordDelta) / timeDelta * 60
                currentWPM = newWPM
                wpmSamples.append(newWPM)
                if newWPM > peakWPM { peakWPM = newWPM }
                if newWPM < lowestWPM && newWPM > 0 { lowestWPM = newWPM }
            }
        }

        // Track zone time
        let nowInZone = isInZone
        if nowInZone {
            timeInZone += 1
        }

        // Haptic feedback on zone transitions
        if wasInZone && !nowInZone {
            CoachHaptic.paceWarning()
        } else if !wasInZone && nowInZone && elapsedSeconds > 3 {
            CoachHaptic.selectionTap()
        }
        wasInZone = nowInZone
    }

    private func finishDrill() {
        guard phase == .speaking else { return }
        timerTask?.cancel()
        speechVM.stopRecording()

        withAnimation(.standardSpring) { phase = .finishing }

        let fillerCount = speechVM.fillerWordCount
        let measuredDuration = recordingStartDate.map { Date().timeIntervalSince($0) } ?? TimeInterval(elapsedSeconds)
        let duration = max(speechVM.lastSessionDuration, measuredDuration, TimeInterval(elapsedSeconds))
        let transcript = speechVM.transcribedText
        let wordCount = transcript.split(separator: " ").count

        let avgWPM = wpmSamples.isEmpty ? 0 : wpmSamples.reduce(0, +) / Double(wpmSamples.count)
        let zonePct = elapsedSeconds > 0 ? Double(timeInZone) / Double(elapsedSeconds) : 0
        let rushedBursts = wpmSamples.filter { $0 > zoneMax }.count
        let fillerAnalysis = FillerWordDetector.analysis(in: transcript, prompt: prompt ?? "")
        let succeeded = zonePct >= 0.60 && elapsedSeconds >= 10

        let metrics = BeatTheBrakeMetrics(
            averageWPM: avgWPM,
            timeInZone: TimeInterval(timeInZone),
            totalDuration: duration,
            zonePercentage: zonePct,
            peakWPM: peakWPM,
            lowestWPM: lowestWPM == 999 ? 0 : lowestWPM,
            adjustedFillers: fillerAnalysis.adjustedCount,
            rushedBursts: rushedBursts
        )

        if succeeded {
            CoachHaptic.drillSuccess()
        } else {
            CoachHaptic.drillIncomplete()
        }

        let outcome = MiniDrillOutcome(
            drill: drill,
            drillType: .beatTheBrake,
            transcript: transcript,
            fillerCount: fillerCount,
            duration: duration,
            wordCount: wordCount,
            succeeded: succeeded,
            beatTheBrakeMetrics: metrics
        )

        Task {
            try? await Task.sleep(for: .milliseconds(800))
            await MainActor.run { onComplete(outcome) }
        }
    }

    private func cancelDrill() {
        timerTask?.cancel()
        if speechVM.isRecording { speechVM.stopRecording() }
        onCancel()
    }
}

// MARK: - Arc Shape

private struct ArcShape: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let lineWidth: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: (min(rect.width, rect.height) - lineWidth) / 2,
            startAngle: startAngle,
            endAngle: endAngle,
            clockwise: false
        )
        return p
    }
}

// MARK: - Needle Shape

private struct NeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let w = rect.width
        let h = rect.height
        p.move(to: CGPoint(x: w / 2, y: 0))
        p.addLine(to: CGPoint(x: w, y: h * 0.85))
        p.addQuadCurve(to: CGPoint(x: 0, y: h * 0.85), control: CGPoint(x: w / 2, y: h))
        p.closeSubpath()
        return p
    }
}

#endif
