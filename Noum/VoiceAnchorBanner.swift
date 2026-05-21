import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Voice Anchor Banner
//
// A restrained, brief intent-setter shown at the top of the speaking layout
// when a rep starts. Closes half of the "Mid-session live UI doesn't read
// the goal" gap from docs/CURRENT_STATE.md — paired with the goal-aware
// `LiveEloquenceHUD` subtext, the user gets at least one personalized
// touchpoint every session (the HUD only pulses when rhetoric is detected,
// which doesn't happen on every rep).
//
// Constraints (per Claude.MD design rules):
//
//  - Restrained motion: a single fade in / fade out, no slide, no pulse.
//    `reduceMotion` collapses to an instant appear/disappear.
//  - Calm coach tone: "Toward your warm voice." No "Let's", no emoji,
//    no exclamation.
//  - Hidden when an active drill is providing the in-the-moment intent
//    (drill banner already owns that surface).
//  - Hidden when no `SpeakingStyleGoal` is set (pre-onboarding users see
//    nothing — no fake personalization).
//  - Self-contained lifecycle: subscribes to `speechVM.$isRecording`,
//    shows for 4s on the first false→true transition per mount, then
//    fades out and stays hidden until the next rep boots fresh.

@available(iOS 17.0, macOS 12.0, *)
struct VoiceAnchorBanner: View {

    /// The user's chosen voice goal. Required — caller gates the banner
    /// on `coachingProfile?.speakingStyleGoal` so we never render an
    /// empty/optional surface.
    let styleGoal: SpeakingStyleGoal

    /// Live recording flag from the speech VM. The banner shows on the
    /// false→true transition and hides itself after `visibleSeconds`.
    let isRecording: Bool

    /// When true (default), the banner re-arms each time recording stops so
    /// the next false→true transition can fire it again. This is the right
    /// behavior for single-rep surfaces like `TimedPracticeView`, where one
    /// view mount maps to one finished rep.
    ///
    /// When false, the banner fires once per mount and never re-arms.
    /// Required for multi-rep surfaces like `SuddenDeathPracticeView`
    /// (rounds) and `IMPracticeView` (dictated replies) where the user
    /// goes through several isRecording cycles inside one session — they
    /// don't need the same anchor flashed at them each turn.
    var resetsBetweenReps: Bool = true

    @State private var visible = false
    @State private var hasShownThisSession = false
    @State private var dismissTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let visibleSeconds: TimeInterval = 4.0
    private static let fadeDuration: TimeInterval = 0.35

    var body: some View {
        Group {
            if visible {
                HStack(spacing: 8) {
                    Image(systemName: "scope")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColor.brandBlue)
                    Text("Toward your \(styleGoal.shortVoiceLabel)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(AppColor.brandBlue.opacity(0.18), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .transition(reduceMotion ? .identity : .opacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Working toward your \(styleGoal.shortVoiceLabel).")
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: Self.fadeDuration), value: visible)
        .onChange(of: isRecording) { _, recording in
            if recording {
                showOnceIfNeeded()
            } else if resetsBetweenReps {
                // Recording stopped (rep ended or user cancelled) — reset so
                // the next rep on the same mount fires the banner again.
                // Skipped on multi-rep surfaces (SuddenDeath, IM) where we
                // want one anchor per session, not one per round.
                resetForNextRep()
            }
        }
        .onDisappear {
            dismissTask?.cancel()
        }
    }

    private func showOnceIfNeeded() {
        guard !hasShownThisSession else { return }
        hasShownThisSession = true
        visible = true
        dismissTask?.cancel()
        dismissTask = Task { [visibleSeconds = Self.visibleSeconds] in
            try? await Task.sleep(nanoseconds: UInt64(visibleSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { visible = false }
        }
    }

    private func resetForNextRep() {
        dismissTask?.cancel()
        dismissTask = nil
        visible = false
        hasShownThisSession = false
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Voice Anchor — warm") {
    struct PreviewWrap: View {
        @State private var recording = false
        var body: some View {
            VStack(spacing: 12) {
                VoiceAnchorBanner(styleGoal: .warm, isRecording: recording)
                Spacer()
                Button(recording ? "Stop" : "Start") { recording.toggle() }
            }
            .padding(.top, 40)
        }
    }
    return PreviewWrap()
}

@available(iOS 17.0, *)
#Preview("Voice Anchor — executive") {
    struct PreviewWrap: View {
        @State private var recording = false
        var body: some View {
            VStack(spacing: 12) {
                VoiceAnchorBanner(styleGoal: .executive, isRecording: recording)
                Spacer()
                Button(recording ? "Stop" : "Start") { recording.toggle() }
            }
            .padding(.top, 40)
        }
    }
    return PreviewWrap()
}
#endif

#endif
