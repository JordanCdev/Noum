import Foundation
#if canImport(SwiftUI)
import SwiftUI
import Combine
#endif

// MARK: - Voice Goal Whisper
//
// Mid-session live UI that quietly reinforces the user's chosen voice goal
// during a rep. Closes the "live HUD adapts copy for the user's voice goal
// during the rep" gap called out in docs/CURRENT_STATE.md.
//
// Architecture:
//
//  - `VoiceGoalCueLibrary` is a deterministic catalog: 5 hand-written cues per
//    SpeakingStyleGoal, each cue mapped to one of the goal's aligned skill
//    areas (so the icon/tint match the coaching surface used elsewhere).
//  - `VoiceGoalWhisperObserver` watches the speech VM's `isRecording` flag.
//    When recording flips on, it fires one cue (rotated by session count for
//    freshness), holds it visible briefly, then dismisses.
//  - `VoiceGoalWhisperHUD` is the SwiftUI surface — mount it as
//    `.overlay(alignment: .bottom)` on any practice view. Self-contained:
//    lifecycle is bound to the speech VM, so callers don't manage state.
//
// Voice rules followed throughout:
//   - No "Let's", no emoji, no exclamation in cue bodies.
//   - Sentence case for body, Title Case + tracked uppercase for micro-label.
//   - Cues are imperatives — coaching, not narrating.
//   - Silent when no goal is set (CoachingProfileStore.profile == nil).

// MARK: - Cue Model

/// A single live cue: a one-line imperative tied to a skill area.
/// The skill area drives the icon and tint so the whisper visually rhymes
/// with the post-session drill surface.
struct VoiceGoalCue: Equatable {
    let body: String
    let skillArea: SkillArea
}

// MARK: - Cue Library

/// Hand-written catalog of mid-session whispers, one set per voice goal.
/// All cues are grounded in `SpeakingStyleGoal.alignedSkillAreas` so the
/// during-session prompt matches the post-session drill recommendation.
enum VoiceGoalCueLibrary {

    static func cues(for goal: SpeakingStyleGoal) -> [VoiceGoalCue] {
        switch goal {
        case .authoritative:  return authoritative
        case .warm:           return warm
        case .concise:        return concise
        case .persuasive:     return persuasive
        case .executive:      return executive
        case .storytelling:   return storytelling
        }
    }

    /// Pick a cue deterministically. `rotationIndex` is typically the user's
    /// session count — same index produces same cue across launches, and
    /// successive sessions cycle through every cue before repeating.
    static func cue(for goal: SpeakingStyleGoal, rotationIndex: Int) -> VoiceGoalCue {
        let bank = cues(for: goal)
        let safeIndex = ((rotationIndex % bank.count) + bank.count) % bank.count
        return bank[safeIndex]
    }

    // Every cue's skillArea is one of the goal's alignedSkillAreas. That keeps
    // the during-session whisper visually consistent with the post-session
    // drill card the engine recommends. The "groundedPace" cues map to
    // .confidence (not .paceControl) because that's where DrillCatalog puts
    // the underlying drill (`confidence.groundedPace`).

    static let authoritative: [VoiceGoalCue] = [
        VoiceGoalCue(body: "Land your opening with one clean line.", skillArea: .openingStrength),
        VoiceGoalCue(body: "Commit to each statement. No hedge words.", skillArea: .confidence),
        VoiceGoalCue(body: "End with conviction. Don't trail off.", skillArea: .closingStrength),
        VoiceGoalCue(body: "Speak at 80% of your natural speed. Control reads as authority.", skillArea: .confidence),
        VoiceGoalCue(body: "Own the silence between points.", skillArea: .confidence),
    ]

    static let warm: [VoiceGoalCue] = [
        VoiceGoalCue(body: "Speak as if explaining to a friend over coffee.", skillArea: .paceControl),
        VoiceGoalCue(body: "Let one detail land vividly.", skillArea: .answerDevelopment),
        VoiceGoalCue(body: "Vary your pace — it sounds human.", skillArea: .vocalEmphasis),
        VoiceGoalCue(body: "Take a breath before the next thought.", skillArea: .paceControl),
        VoiceGoalCue(body: "Lift one word per sentence with your voice.", skillArea: .vocalEmphasis),
    ]

    static let concise: [VoiceGoalCue] = [
        VoiceGoalCue(body: "Lead with the headline. Support after.", skillArea: .conciseSpeaking),
        VoiceGoalCue(body: "Three sentences. No more.", skillArea: .structure),
        VoiceGoalCue(body: "Cut the next 'um' before it lands.", skillArea: .fillerReduction),
        VoiceGoalCue(body: "Make the point. Stop. Move on.", skillArea: .conciseSpeaking),
        VoiceGoalCue(body: "If you said it once, don't say it twice.", skillArea: .conciseSpeaking),
    ]

    static let persuasive: [VoiceGoalCue] = [
        VoiceGoalCue(body: "One concrete example. That's the lever.", skillArea: .answerDevelopment),
        VoiceGoalCue(body: "Frame it: claim, reason, evidence.", skillArea: .structure),
        VoiceGoalCue(body: "End with what this means going forward.", skillArea: .closingStrength),
        VoiceGoalCue(body: "Earn the close by setting up the contrast.", skillArea: .structure),
        VoiceGoalCue(body: "Build the argument step by step.", skillArea: .structure),
    ]

    static let executive: [VoiceGoalCue] = [
        VoiceGoalCue(body: "Bottom line up front.", skillArea: .conciseSpeaking),
        VoiceGoalCue(body: "Cut every hedge: 'I think', 'maybe', 'sort of'.", skillArea: .confidence),
        VoiceGoalCue(body: "Open with the thesis in one line.", skillArea: .openingStrength),
        VoiceGoalCue(body: "Speak at 80% of your natural speed.", skillArea: .confidence),
        VoiceGoalCue(body: "End with the answer. No wind-up.", skillArea: .conciseSpeaking),
    ]

    static let storytelling: [VoiceGoalCue] = [
        VoiceGoalCue(body: "Open with the moment, not the lesson.", skillArea: .answerDevelopment),
        VoiceGoalCue(body: "Pause before the turn in the story.", skillArea: .pauseUsage),
        VoiceGoalCue(body: "Let one sensory detail anchor the scene.", skillArea: .answerDevelopment),
        VoiceGoalCue(body: "Slow down for the line that matters.", skillArea: .vocalEmphasis),
        VoiceGoalCue(body: "Hold the silence after your last line.", skillArea: .pauseUsage),
    ]
}

// MARK: - Observer

#if canImport(SwiftUI)

/// Watches the speech VM's recording flag and surfaces one cue per session.
/// `start()` / `stop()` mirror the view lifecycle. Idempotent.
@available(iOS 17.0, macOS 12.0, *)
@MainActor
final class VoiceGoalWhisperObserver: ObservableObject {

    /// The cue currently on screen, if any. Nil while idle.
    @Published private(set) var visibleCue: VoiceGoalCue?

    /// Whether the whisper has already been shown this session.
    /// Resets when `isRecording` flips false → true.
    private var hasFiredForCurrentRecording = false

    /// How long the whisper stays visible before fading out.
    private static let visibleSeconds: TimeInterval = 4.0
    /// Small delay after recording starts before the whisper appears —
    /// gives the user a beat to begin speaking without competing for focus.
    private static let revealDelay: TimeInterval = 0.6

    private var recordingCancellable: AnyCancellable?
    private var revealTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?

    /// Begin observing the speech VM's `isRecording` flag. Idempotent —
    /// calling twice rewires the subscription cleanly.
    func start(isRecordingPublisher: AnyPublisher<Bool, Never>) {
        recordingCancellable?.cancel()
        recordingCancellable = isRecordingPublisher
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isRecording in
                if isRecording {
                    self?.handleRecordingStarted()
                } else {
                    self?.handleRecordingStopped()
                }
            }
    }

    /// Tear down all state. Call from `.onDisappear`.
    func stop() {
        recordingCancellable?.cancel()
        recordingCancellable = nil
        revealTask?.cancel()
        revealTask = nil
        dismissTask?.cancel()
        dismissTask = nil
        visibleCue = nil
        hasFiredForCurrentRecording = false
    }

    // MARK: - Private

    private func handleRecordingStarted() {
        guard !hasFiredForCurrentRecording else { return }
        guard let goal = CoachingProfileStore.shared.profile?.speakingStyleGoal else { return }
        hasFiredForCurrentRecording = true

        let rotationIndex = PracticeSessionStore.shared.sessions.count
        let cue = VoiceGoalCueLibrary.cue(for: goal, rotationIndex: rotationIndex)

        revealTask?.cancel()
        revealTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.revealDelay * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.present(cue)
        }
    }

    private func handleRecordingStopped() {
        revealTask?.cancel()
        dismissTask?.cancel()
        visibleCue = nil
        hasFiredForCurrentRecording = false
    }

    private func present(_ cue: VoiceGoalCue) {
        visibleCue = cue
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.visibleSeconds * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.visibleCue = nil
        }
    }
}

// MARK: - View

/// Bottom-of-screen whisper HUD. Drop into any practice view with
/// `.overlay(alignment: .bottom) { VoiceGoalWhisperHUD(speechVM: vm) }`.
/// Self-wiring: reads the user's voice goal from `CoachingProfileStore`,
/// fires once per session, fades out automatically. Does nothing when no
/// goal is set or no profile exists.
@available(iOS 17.0, macOS 12.0, *)
struct VoiceGoalWhisperHUD: View {
    @ObservedObject var speechVM: SpeechRecognizerViewModel
    @StateObject private var observer = VoiceGoalWhisperObserver()
    @StateObject private var profileStore = CoachingProfileStore.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            if let cue = observer.visibleCue, let goal = profileStore.profile?.speakingStyleGoal {
                whisperCard(cue: cue, goal: goal)
                    .transition(transition)
                    .id(cue.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, Spacing.md)
        .padding(.bottom, Spacing.lg)
        .animation(reduceMotion ? .easeOut(duration: 0.20) : .spring(response: 0.42, dampingFraction: 0.82), value: observer.visibleCue?.body)
        .allowsHitTesting(false)
        .onAppear { wireObserver() }
        .onDisappear { observer.stop() }
    }

    private func wireObserver() {
        observer.start(isRecordingPublisher: speechVM.$isRecording.eraseToAnyPublisher())
    }

    // MARK: - Whisper Card

    private func whisperCard(cue: VoiceGoalCue, goal: SpeakingStyleGoal) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: cue.skillArea.icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(cue.skillArea.tint)
                Text("Toward your \(goal.shortVoiceLabel)".uppercased())
                    .font(Typography.micro)
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
            Text(cue.body)
                .font(Typography.caption)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(cue.skillArea.tint.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: cue.skillArea.tint.opacity(0.12), radius: 12, x: 0, y: 6)
        .frame(maxWidth: 340, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Voice goal cue: \(cue.body). Toward your \(goal.shortVoiceLabel).")
    }

    /// Slide up softly with a fade. Reduce-motion users get a plain crossfade.
    private var transition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity
        )
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Voice Goal Whisper") {
    struct PreviewWrap: View {
        @StateObject var vm = SpeechRecognizerViewModel(preloadOnInit: false)
        var body: some View {
            ZStack {
                AppColor.screenBackground.ignoresSafeArea()
                VStack {
                    Spacer()
                    Button("Toggle recording") {
                        vm.isRecording.toggle()
                    }
                    .padding(.bottom, 200)
                }
                VoiceGoalWhisperHUD(speechVM: vm)
            }
        }
    }
    return PreviewWrap()
}
#endif

#endif
