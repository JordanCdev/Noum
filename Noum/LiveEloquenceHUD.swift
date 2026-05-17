import Foundation
#if canImport(SwiftUI)
import SwiftUI
import Combine

// MARK: - Live Eloquence HUD
//
// During-session inline detector that watches the live transcript, runs the
// existing `EloquenceEngine` against partial output, and pulses a chip the
// moment a new rhetorical move lands. Positive-only, real-time feedback —
// no critique, no ranking, no XP math (the summary `EloquenceFindingsCard`
// already owns reward surfacing once the session ends).
//
// Architecture notes:
//
//  - The observer is the single source of truth for "what has been
//    announced this session". It throttles engine calls to once per second
//    so we don't hammer the CPU as Deepgram streams partials.
//  - Findings are queued and shown one at a time — back-to-back rhetoric
//    won't crash the chip into itself, and listeners get a clear visual
//    rhythm.
//  - `start()` / `stop()` mirror the speech VM lifecycle, so a fresh
//    session always starts with an empty announced set.
//
// This file is the only place this surface lives. The chip's visuals reuse
// the existing `Typography.*` and `AppColor.*` tokens; the symbol mapping
// is a faithful copy of `EloquenceFindingsCard.symbolName(for:)` so the
// during-session and post-session surfaces stay visually coherent.

@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class LiveEloquenceObserver: ObservableObject {

    /// The chip currently on screen (if any). Nil while idle.
    @Published private(set) var visibleFinding: EloquenceFinding?

    /// User's voice goal for this session. Captured once at `start()` —
    /// goal is a write-once setting from onboarding, so reading it
    /// reactively mid-rep would be wasted overhead. When set, devices
    /// that align with the goal render a "for your <voice>" trailing
    /// phrase on the chip instead of the neutral "noticed".
    private(set) var voiceGoal: SpeakingStyleGoal?

    /// Devices already announced this session. Each device fires at most
    /// once — repeating "tricolon" wouldn't be new information, and
    /// re-pulsing during a session would feel noisy.
    private var announced: Set<EloquenceDevice> = []

    /// Pending findings waiting their turn. Capped at a small queue so a
    /// dense burst of rhetoric doesn't queue 30s of chips.
    private var pending: [EloquenceFinding] = []
    private static let maxQueueDepth = 4

    /// Visible duration for each chip, before it slides out.
    private static let visibleSeconds: TimeInterval = 1.8
    /// Throttle window for engine analysis calls. ~1Hz keeps CPU off the
    /// fire path while still catching new devices the moment they land.
    private static let analyseInterval: TimeInterval = 1.0

    private var cancellable: AnyCancellable?
    private var dismissTask: Task<Void, Never>?
    private var lastAnalyseAt: Date = .distantPast

    /// Begin observing the speech VM. Idempotent — calling twice rewires
    /// the subscription cleanly. Captures the user's voice goal at the
    /// start of the session so chip copy can be goal-grounded.
    func start(transcriptPublisher: AnyPublisher<String, Never>, voiceGoal: SpeakingStyleGoal? = nil) {
        cancellable?.cancel()
        self.voiceGoal = voiceGoal
        cancellable = transcriptPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] transcript in
                self?.consume(transcript: transcript)
            }
    }

    /// Reset everything. Call between sessions so the next rep starts
    /// with a fresh announced set and an empty queue.
    func stop() {
        cancellable?.cancel()
        cancellable = nil
        dismissTask?.cancel()
        dismissTask = nil
        announced.removeAll()
        pending.removeAll()
        visibleFinding = nil
        voiceGoal = nil
        lastAnalyseAt = .distantPast
    }

    // MARK: - Private

    private func consume(transcript: String) {
        let now = Date()
        guard now.timeIntervalSince(lastAnalyseAt) >= Self.analyseInterval else { return }
        lastAnalyseAt = now

        // Engine is pure — running it on the main actor is fine for the
        // typical 30–150s transcripts we see during a Timed session.
        let findings = EloquenceEngine.analyse(transcript: transcript, maxFindings: 6)
        for finding in findings where !announced.contains(finding.device) {
            announced.insert(finding.device)
            enqueue(finding)
        }
    }

    private func enqueue(_ finding: EloquenceFinding) {
        if visibleFinding == nil {
            present(finding)
        } else if pending.count < Self.maxQueueDepth {
            pending.append(finding)
        }
    }

    private func present(_ finding: EloquenceFinding) {
        visibleFinding = finding
        CoachHaptic.trendBreakthrough()
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.visibleSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.advanceQueue()
        }
    }

    private func advanceQueue() {
        visibleFinding = nil
        // Small breath between chips so the slide-in is legible.
        guard !pending.isEmpty else { return }
        let next = pending.removeFirst()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            self?.present(next)
        }
    }
}

// MARK: - View

/// Inline HUD overlay. Drop this anywhere with `.overlay(alignment: .top) {…}`
/// and pass the speech VM. The HUD wires itself up on appear and resets on
/// disappear — no parent-side bookkeeping required.
@available(iOS 17.0, macOS 12.0, *)
struct LiveEloquenceHUD: View {
    @ObservedObject var speechVM: SpeechRecognizerViewModel
    @StateObject private var observer = LiveEloquenceObserver()
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Voice goal at the moment a session starts. Read once via
    /// `CoachingProfileStore.shared` — the goal is a write-once onboarding
    /// setting, so observing the store reactively here would be overkill.
    private var currentVoiceGoal: SpeakingStyleGoal? {
        coachingProfileStore.profile?.speakingStyleGoal
    }

    var body: some View {
        ZStack {
            if let finding = observer.visibleFinding {
                chip(for: finding)
                    .transition(transition)
                    .id(finding.id)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.xs)
        .animation(reduceMotion ? .easeOut(duration: 0.18) : .spring(response: 0.42, dampingFraction: 0.78), value: observer.visibleFinding?.id)
        .allowsHitTesting(false)
        .onAppear {
            observer.start(transcriptPublisher: speechVM.$transcribedText.eraseToAnyPublisher(), voiceGoal: currentVoiceGoal)
        }
        .onDisappear { observer.stop() }
        .onChange(of: speechVM.isRecording) { _, isRecording in
            // When a new session starts (recording flips on), reset the
            // announced-device set so each rep can re-celebrate the same
            // devices the listener earned last time. Re-read the goal so a
            // mid-life-of-the-view goal change (Settings → onboarding redo)
            // surfaces on the next rep.
            if isRecording {
                observer.stop()
                observer.start(transcriptPublisher: speechVM.$transcribedText.eraseToAnyPublisher(), voiceGoal: currentVoiceGoal)
            }
        }
    }

    // MARK: - Chip

    private func chip(for finding: EloquenceFinding) -> some View {
        let trailing = LiveEloquenceChipCopy.trailingPhrase(device: finding.device, goal: observer.voiceGoal)
        return HStack(spacing: 8) {
            Image(systemName: symbolName(for: finding.device))
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(AppColor.brandBlue)
            Text(finding.device.title)
                .font(Typography.caption)
                .foregroundStyle(.primary)
            Text(trailing)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(AppColor.cardBackground)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(AppColor.brandBlue.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: AppColor.brandBlue.opacity(0.18), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: finding, trailing: trailing))
    }

    /// VoiceOver narration. When the chip is goal-grounded, the announcement
    /// tells the listener which voice it ties to so the alignment isn't only
    /// visual.
    private func accessibilityLabel(for finding: EloquenceFinding, trailing: String) -> String {
        if trailing == "noticed" {
            return "Rhetorical move noticed: \(finding.device.title)"
        }
        return "\(finding.device.title) — a direct step toward your \(observer.voiceGoal?.shortVoiceLabel ?? "voice")."
    }

    /// Slide in from the leading edge with a soft fade. Reduce-motion
    /// users get a plain crossfade — same surfacing, no movement.
    private var transition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .leading).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Mirrors `EloquenceFindingsCard.symbolName(for:)` so the during-session
    /// chip and the post-session card share an icon vocabulary.
    private func symbolName(for device: EloquenceDevice) -> String {
        switch device {
        case .tricolon, .ruleOfThree: return "3.circle.fill"
        case .anaphora: return "arrow.forward.circle.fill"
        case .epistrophe: return "arrow.backward.circle.fill"
        case .alliteration: return "a.circle.fill"
        case .isocolon: return "equal.circle.fill"
        case .antithesis: return "arrow.left.arrow.right.circle.fill"
        case .polysyndeton: return "plus.circle.fill"
        case .asyndeton: return "minus.circle.fill"
        case .diacope: return "scope"
        case .epizeuxis: return "exclamationmark.bubble.fill"
        case .rhetoricalQuestion: return "questionmark.circle.fill"
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Live HUD — chip") {
    struct PreviewWrap: View {
        @StateObject var vm = SpeechRecognizerViewModel(preloadOnInit: false)
        var body: some View {
            ZStack(alignment: .top) {
                AppColor.screenBackground.ignoresSafeArea()
                LiveEloquenceHUD(speechVM: vm)
                    .padding(.top, 40)
                Button("Inject tricolon transcript") {
                    vm.transcribedText = "We need clarity, courage, and conviction. We must lead. We must deliver."
                }
                .padding(.top, 120)
            }
        }
    }
    return PreviewWrap()
}
#endif

#endif
