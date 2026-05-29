import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Voice Alignment Chip (M14)
//
// Fifth surface in the goal-aware coaching loop. The pre-rep
// `VoiceAnchorBanner`, mid-rep `LiveEloquenceHUD`, post-rep Coach Note
// momentum line, and profile `GoalProgressView` ring already speak the
// user's chosen voice. This chip carries the same thread onto the very
// first surface the user sees — the home recommendation tile.
//
// Honesty rules:
//   • Silent when no `SpeakingStyleGoal` is set — pre-onboarding users
//     and "skipped voice" users see nothing, never a fake personalization.
//   • Silent when the recommended mode's primary skills don't overlap
//     with the voice's aligned skills (`SpeakingStyleGoal.aligns(with:)`).
//     Some voices align with some modes — the chip stays out of the way
//     when the alignment isn't real.
//   • One line, sentence-fragment phrasing, no exclamation. Mirrors the
//     `VoiceAnchorBanner` tone exactly.
//
// Visual: tiny capsule at the bottom of the recommendation tile's text
// stack, tinted with the mode color at 10% so it harmonises with the tile
// background rather than competing with the CTA.

@available(iOS 17.0, macOS 12.0, *)
struct VoiceAlignmentChip: View {
    /// The user's chosen voice goal — `nil` is the no-onboarding-yet case
    /// and the chip stays hidden.
    let styleGoal: SpeakingStyleGoal?

    /// The recommended practice mode. The chip fires when this mode's
    /// `primarySkillAreas` overlap with the voice's `alignedSkillAreas`.
    let mode: PracticeMode

    /// Mode tint passed by the caller so the chip harmonises with the
    /// surrounding tile (timed = blue, suddenDeath = orange, etc.).
    let tint: Color

    private var shouldShow: Bool {
        guard let goal = styleGoal else { return false }
        return goal.aligns(with: mode)
    }

    var body: some View {
        Group {
            if shouldShow, let goal = styleGoal {
                HStack(spacing: 4) {
                    Image(systemName: "scope")
                        .font(.system(size: 9, weight: .bold))
                    Text("Toward your \(goal.shortVoiceLabel)")
                        .font(.caption2.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tint.opacity(0.10), in: Capsule())
                .accessibilityLabel("Aligned with your \(goal.shortVoiceLabel).")
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Voice Alignment — concise + timed") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Concise voice → timed mode (aligned)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        VoiceAlignmentChip(styleGoal: .concise, mode: .timed, tint: AppColor.brandBlue)

        Text("Warm voice → sudden death (not aligned — silent)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        VoiceAlignmentChip(styleGoal: .warm, mode: .suddenDeath, tint: AppColor.modeSuddenDeath)

        Text("No goal → silent")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        VoiceAlignmentChip(styleGoal: nil, mode: .timed, tint: AppColor.brandBlue)
    }
    .padding()
    .background(AppColor.cardBackground)
}

@available(iOS 17.0, *)
#Preview("All voices × all modes") {
    let voices: [SpeakingStyleGoal] = SpeakingStyleGoal.allCases
    let modes: [PracticeMode] = [.timed, .suddenDeath, .ahCounter, .imConversation]
    return ScrollView {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(voices, id: \.self) { voice in
                Text(voice.title).font(.caption.weight(.bold))
                ForEach(modes, id: \.self) { mode in
                    HStack {
                        Text(mode.rawValue).font(.caption2).frame(width: 110, alignment: .leading)
                        VoiceAlignmentChip(styleGoal: voice, mode: mode, tint: AppColor.tint(for: mode))
                        Spacer()
                    }
                }
                Divider()
            }
        }
        .padding()
    }
}
#endif

#endif
