#if canImport(SwiftUI)
import SwiftUI

/// Summary-screen card that surfaces detected rhetorical devices.
///
/// This is **positive-only** feedback — the engine is conservative and the
/// card hides itself entirely when there are zero findings. The presence of
/// the card on a summary should always feel like a small win; absence should
/// never feel like a critique.
@available(iOS 17.0, macOS 12.0, *)
struct EloquenceFindingsCard: View {
    let findings: [EloquenceFinding]

    var body: some View {
        if findings.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(findings) { finding in
                        findingRow(finding)
                    }
                }
            }
            .padding(Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(Color.white.opacity(0.72), lineWidth: 1)
            )
            .accessibilityElement(children: .contain)
            .accessibilityLabel(accessibilitySummary)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.opening")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
            Text("Rhetorical moves")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            Spacer()
            xpBadge
        }
    }

    /// XP bonus chip. Always present when there's at least one finding —
    /// surfacing the reward keeps eloquence from feeling decorative.
    private var xpBadge: some View {
        let xp = EloquenceXP.totalXP(for: findings)
        return HStack(spacing: 4) {
            Image(systemName: "plus.circle.fill")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppColor.brandBlue)
            Text("\(xp) XP")
                .font(Typography.caption.monospacedDigit())
                .foregroundStyle(AppColor.brandBlue)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(AppColor.brandBlue.opacity(0.10), in: Capsule())
        .accessibilityLabel("Bonus \(xp) experience points")
    }

    // MARK: - Finding row

    private func findingRow(_ finding: EloquenceFinding) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .fill(AppColor.brandBlue.opacity(0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: symbolName(for: finding.device))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColor.brandBlue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(finding.device.title)
                    .font(Typography.headline)
                    .foregroundStyle(.primary)
                Text(finding.coachLine)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if !finding.snippet.isEmpty {
                    Text("\u{201C}\(truncatedSnippet(finding.snippet))\u{201D}")
                        .font(Typography.body)
                        .foregroundStyle(AppColor.brandBlue.opacity(0.92))
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }
        }
    }

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

    private func truncatedSnippet(_ raw: String) -> String {
        let limit = 90
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        return String(trimmed.prefix(limit - 1)) + "\u{2026}"
    }

    private var accessibilitySummary: String {
        let titles = findings.map { $0.device.title }.joined(separator: ", ")
        return "Rhetorical moves: \(findings.count) detected — \(titles)."
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Eloquence — populated") {
    EloquenceFindingsCard(findings: [
        EloquenceFinding(
            device: .tricolon,
            snippet: "Clarity, courage, and conviction",
            coachLine: "Lists of three feel complete. The third item is what makes it land."
        ),
        EloquenceFinding(
            device: .anaphora,
            snippet: "We will speak. We will lead. We will deliver.",
            coachLine: "Repeating the opening of a clause builds rhythm and presses the point."
        ),
        EloquenceFinding(
            device: .alliteration,
            snippet: "proper preparation prevents panic",
            coachLine: "Same-sound openings make a phrase memorable without sounding clever."
        )
    ])
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Eloquence — empty (hides)") {
    EloquenceFindingsCard(findings: [])
        .padding()
        .background(AppColor.screenBackground)
}
#endif

#endif
