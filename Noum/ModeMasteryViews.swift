import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)

// MARK: - Mode Mastery Card (Profile)
//
// One card on the profile that shows where the speaker has put real reps.
// Each row is a mode + its mastery level + a thin progress rail toward the
// next tier. Tap a row → jumps into that mode's picker entry.

@available(iOS 17.0, macOS 12.0, *)
struct ModeMasteryCard: View {
    @StateObject private var masteryStore = ModeMasteryStore.shared

    /// Optional callback when a row is tapped (e.g. open the mode picker).
    var onSelect: ((PracticeMode) -> Void)? = nil

    private var snapshots: [ModeMasterySnapshot] {
        // Stable order — picker order — so the rail doesn't reshuffle as
        // levels move.
        [PracticeMode.timed, .suddenDeath, .ahCounter, .imConversation]
            .map { masteryStore.snapshot(for: $0) }
    }

    var body: some View {
        if masteryStore.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                VStack(spacing: Spacing.sm) {
                    ForEach(snapshots) { snapshot in
                        Group {
                            if let onSelect {
                                Button {
                                    onSelect(snapshot.mode)
                                } label: {
                                    ModeMasteryRow(snapshot: snapshot)
                                }
                                .buttonStyle(.pressable)
                            } else {
                                ModeMasteryRow(snapshot: snapshot)
                            }
                        }
                    }
                }
            }
            .padding(Spacing.lg)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Mode mastery")
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("MODE MASTERY")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
                Text("Where your reps live")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption2.weight(.bold))
                Text("\(totalReps)")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppColor.tagBackground, in: Capsule())
            .accessibilityLabel("\(totalReps) total reps logged")
        }
    }

    private var totalReps: Int {
        snapshots.reduce(0) { $0 + $1.sessionsLogged }
    }
}

// MARK: - Single Row

@available(iOS 17.0, macOS 12.0, *)
struct ModeMasteryRow: View {
    let snapshot: ModeMasterySnapshot

    private var tint: Color { AppColor.tint(for: snapshot.mode) }

    var body: some View {
        HStack(spacing: Spacing.md) {
            // Icon + level chip
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .fill(tint.opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: snapshot.mode.iconName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)

                levelChip
                    .offset(x: 6, y: 6)
            }
            .frame(width: 50, height: 50, alignment: .center)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(snapshot.mode.displayLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("·")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(snapshot.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tint)
                }
                progressRail
                Text(detailLine)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var levelChip: some View {
        Text("\(snapshot.level)")
            .font(.caption2.weight(.heavy))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(tint, in: Circle())
            .overlay(
                Circle().stroke(Color.white, lineWidth: 1.5)
            )
    }

    private var progressRail: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.12))
                Capsule()
                    .fill(tint.gradient)
                    .frame(width: snapshot.isMaxed
                           ? proxy.size.width
                           : proxy.size.width * snapshot.progressToNext)
            }
        }
        .frame(height: 6)
    }

    private var detailLine: String {
        if snapshot.isMaxed {
            return "Maxed · \(snapshot.totalXP) XP"
        }
        if snapshot.sessionsLogged == 0 {
            return "Untouched. One rep starts the climb."
        }
        let remaining = max(0, snapshot.xpForNextLevel - snapshot.xpIntoLevel)
        return "\(snapshot.sessionsLogged) reps · \(remaining) XP to Lv \(snapshot.level + 1)"
    }

    private var accessibilityLabel: String {
        "\(snapshot.mode.displayLabel), level \(snapshot.level), \(snapshot.title). \(detailLine)"
    }
}

// MARK: - Compact Badge (for picker rows)

/// Small inline badge that shows the mode's current mastery level.
/// Designed to sit next to the mode title in `PracticeModeSelectionView`.
@available(iOS 17.0, macOS 12.0, *)
struct ModeMasteryBadge: View {
    let snapshot: ModeMasterySnapshot

    private var tint: Color { AppColor.tint(for: snapshot.mode) }

    var body: some View {
        HStack(spacing: 4) {
            Text("Lv \(snapshot.level)")
                .font(.system(size: 10, weight: .heavy, design: .rounded))
                .tracking(0.4)
            if !snapshot.title.isEmpty {
                Text(snapshot.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.10), in: Capsule())
        .accessibilityLabel("Level \(snapshot.level), \(snapshot.title)")
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Mastery card") {
    ScrollView {
        VStack(spacing: 16) {
            ModeMasteryCard()
                .padding(.horizontal, 20)
        }
    }
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Mastery row — Timed Lv 4") {
    let snapshot = ModeMasteryRank.snapshot(mode: .timed, totalXP: 1_350, sessionsLogged: 18)
    return ModeMasteryRow(snapshot: snapshot)
        .padding(.horizontal, 20)
        .background(AppColor.screenBackground)
}
#endif

#endif
