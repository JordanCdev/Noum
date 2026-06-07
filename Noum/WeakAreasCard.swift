#if canImport(SwiftUI)
import SwiftUI

// MARK: - Weak Areas Card
//
// Targeted-practice surface that lifts the user's top blockers into one
// tappable card with a one-tap CTA into a drill that targets the signal.
//
// Inputs come from already-computed sources:
//  - `BaselineEngine.persistentBlockers` — the durable weaknesses
//  - `ClutchWordStore.topClutchWords` — recurring filler patterns
//  - `RatingStore.weeklyDelta` — pressure gap signal
//
// No new tracking. No new state owners.

enum TargetedPracticeCopy {
    static let header = "Targeted practice"
}

@available(iOS 17.0, macOS 12.0, *)
struct WeakAreasCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject var sessionStore: PracticeSessionStore
    @StateObject private var baselineStore = BaselineStore.shared
    @StateObject private var clutchWordStore = ClutchWordStore.shared
    @StateObject private var ratingStore = RatingStore.shared
    let onStartDrill: (DrillTarget) -> Void

    @State private var hasAppeared = false

    static func hasTargets(
        baseline: CommunicationBaseline,
        topClutchWords: [ClutchWordEntry],
        rating: SpeakingRating
    ) -> Bool {
        !baseline.persistentBlockers.isEmpty
        || topClutchWords.first != nil
        || rating.weeklyDelta < -10
    }

    enum DrillTarget {
        case fillerControl
        case opening
        case structure
        case pace
        case pressure

        var actionLabel: String {
            switch self {
            case .fillerControl: return "Run Land the Pause"
            case .opening:       return "Open Timed mode"
            case .structure:     return "Run Rule of Three lesson"
            case .pace:          return "Open Ah-Counter"
            case .pressure:      return "Open Pressure Drill"
            }
        }

        var symbolName: String {
            switch self {
            case .fillerControl: return "speaker.slash.fill"
            case .opening:       return "text.alignleft"
            case .structure:     return "list.number"
            case .pace:          return "speedometer"
            case .pressure:      return "bolt.fill"
            }
        }

        var tint: Color {
            switch self {
            case .fillerControl: return AppColor.caution
            case .opening:       return AppColor.modeTimed
            case .structure:     return AppColor.brandBlue
            case .pace:          return AppColor.modeAhCounter
            case .pressure:      return AppColor.modeSuddenDeath
            }
        }

        var destination: AppDestination {
            switch self {
            case .fillerControl: return .cutTheCrutchPractice
            case .opening:       return .timedPractice
            case .structure:     return .lessons
            case .pace:          return .ahCounterPractice
            case .pressure:      return .suddenDeathPractice
            }
        }
    }

    /// One-row practice-target model. The view stays simple — derive the rows
    /// from the existing engines, render, hand back a target on tap.
    private struct WeakRow: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let target: DrillTarget
    }

    private var rows: [WeakRow] {
        var out: [WeakRow] = []
        let baseline = baselineStore.baseline

        // 1. Persistent blockers — the most reliable weakness signal.
        for blocker in baseline.persistentBlockers.prefix(2) {
            let target: DrillTarget
            let lower = blocker.lowercased()
            if lower.contains("filler") || lower.contains("um") || lower.contains("hesit") {
                target = .fillerControl
            } else if lower.contains("opening") || lower.contains("open") {
                target = .opening
            } else if lower.contains("structure") || lower.contains("ramble") {
                target = .structure
            } else if lower.contains("pace") || lower.contains("rush") {
                target = .pace
            } else if lower.contains("pressure") || lower.contains("compose") {
                target = .pressure
            } else {
                target = .structure
            }
            out.append(WeakRow(
                title: blocker.capitalized,
                detail: "Shows up in recent reps. A direct drill gives the signal a cleaner next read.",
                target: target
            ))
        }

        // 2. Top clutch word — if the user has a recurring filler.
        if let top = clutchWordStore.topClutchWords.first {
            out.append(WeakRow(
                title: "\u{201C}\(top.word)\u{201D} keeps showing up",
                detail: "\(top.totalOccurrences) instance\(top.totalOccurrences == 1 ? "" : "s") across recent reps. A pause-control drill swaps it for silence.",
                target: .fillerControl
            ))
        }

        // 3. Weekly rating slipped — pressure tolerance gap.
        if ratingStore.rating.weeklyDelta < -10 {
            out.append(WeakRow(
                title: "Pressure caught you this week",
                detail: "Rating dipped \(ratingStore.rating.weeklyDelta) points. A calmer Pressure Drill rep is the better next target.",
                target: .pressure
            ))
        }

        return Array(out.prefix(3))
    }

    var body: some View {
        let weakRows = rows
        if weakRows.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                ForEach(weakRows) { row in
                    weakRowView(row)
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .scaleEffect(hasAppeared ? 1 : 0.97)
            .opacity(hasAppeared ? 1 : 0)
            .onAppear {
                guard !hasAppeared else { return }
                if reduceMotion {
                    hasAppeared = true
                } else {
                    withAnimation(.standardSpring.delay(0.05)) { hasAppeared = true }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
            Text(TargetedPracticeCopy.header)
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            Text("\(rows.count) drill\(rows.count == 1 ? "" : "s")")
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
    }

    private func weakRowView(_ row: WeakRow) -> some View {
        Button {
            CoachHaptic.selectionTap()
            onStartDrill(row.target)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(row.target.tint.opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: row.target.symbolName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(row.target.tint)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.title)
                        .font(Typography.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(row.detail)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption2.weight(.bold))
                        Text(row.target.actionLabel)
                            .font(Typography.caption.weight(.semibold))
                    }
                    .foregroundStyle(row.target.tint)
                    .padding(.top, 2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.tagBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#endif
