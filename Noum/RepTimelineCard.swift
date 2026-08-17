#if canImport(SwiftUI)
import SwiftUI

// MARK: - Rep Timeline Card
//
// The VISIBLE companion to `RepEventLocations` — the positional read of a
// single rep that, until now, only reached the coach prompt (via
// `CoachContextBuilder`) and never the user's eyes. This is the first stone of
// the annotated-analytics surface Speeko/Yoodli are known for, rendered in
// Noum's calm, restrained card language rather than their dense dashboards.
//
// HONEST BY CONSTRUCTION. It shows ONLY what `RepEventLocationsEngine` already
// decided was credible:
//   - the single longest qualifying pause (silence),
//   - the fastest rushed burst (pace),
//   - a filler CLUSTER (>= 2 in one zone).
// Each is optional; the engine returns nil unless at least one is present, so
// `SummaryView` never constructs this card for a non-finding. No new pace or
// pause thresholds, and NO finer precision than the model carries: the rep is
// drawn as three honest thirds (opening / middle / close), the exact resolution
// a coach actually talks in — never a fake per-word scrubber.
//
// Motion-free by design: a static card satisfies reduced-motion without a
// branch. A11y collapses the whole visual into one coherent positional
// sentence so VoiceOver reads "fastest stretch 168 wpm in the close, longest
// pause 1.4s in the opening" rather than spelling out decorative chips.

@available(iOS 17.0, macOS 12.0, *)
struct RepTimelineCard: View {
    let locations: RepEventLocations

    private let tint: Color = AppColor.brandBlue

    /// One renderable signal placed in its zone. Colors are semantic and reuse
    /// existing tokens — silence = calm brandBlue, pace = caution amber,
    /// fillers = muted secondary. No new color constants are introduced.
    private struct Marker: Identifiable {
        let zone: RepEventLocations.Zone
        let symbol: String
        let color: Color
        let value: String
        let kind: String
        var id: String { kind }
    }

    private var markers: [Marker] {
        var result: [Marker] = []
        if let zone = locations.rushedBurstZone, let wpm = locations.rushedBurstWPM {
            result.append(Marker(
                zone: zone,
                symbol: "hare.fill",
                color: AppColor.caution,
                value: "\(Int(wpm.rounded())) wpm",
                kind: "pace"
            ))
        }
        if let zone = locations.longestPauseZone, let seconds = locations.longestPauseSeconds {
            result.append(Marker(
                zone: zone,
                symbol: "pause.circle.fill",
                color: tint,
                value: formatSeconds(seconds),
                kind: "silence"
            ))
        }
        if let zone = locations.fillerClusterZone, let count = locations.fillerClusterCount {
            result.append(Marker(
                zone: zone,
                symbol: NoumSemanticGraphicRole.fillerWords.systemName,
                color: AppColor.textSecondary,
                value: "×\(count)",
                kind: "fillers"
            ))
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top, spacing: Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(tint.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "timeline.selection")
                        .font(Typography.headline)
                        .foregroundStyle(tint)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Where it landed")
                        .font(Typography.micro)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Text(summaryLine)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 6) {
                ForEach(RepEventLocations.Zone.allCases, id: \.self) { zone in
                    zoneColumn(zone)
                }
            }

            if !legend.isEmpty {
                HStack(spacing: Spacing.md) {
                    ForEach(legend) { item in
                        HStack(spacing: 5) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(item.color)
                            Text(item.label)
                                .font(Typography.captionSmall)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityReadout)
        .accessibilityIdentifier("summary.repTimelineCard")
    }

    // MARK: - Zone column

    private func zoneColumn(_ zone: RepEventLocations.Zone) -> some View {
        let zoneMarkers = markers.filter { $0.zone == zone }
        return VStack(spacing: 6) {
            VStack(spacing: 4) {
                if zoneMarkers.isEmpty {
                    Text("—")
                        .font(Typography.caption)
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(zoneMarkers) { marker in
                        markerChip(marker)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.vertical, Spacing.sm)
            .background(
                AppColor.innerSurface,
                in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
            )

            Text(zone.label.capitalized)
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .accessibilityHidden(true)
    }

    private func markerChip(_ marker: Marker) -> some View {
        HStack(spacing: 4) {
            Image(systemName: marker.symbol)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(marker.color)
            Text(marker.value)
                .font(Typography.captionSmall)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(marker.color.opacity(0.12), in: Capsule())
    }

    // MARK: - Legend

    private struct LegendItem: Identifiable {
        let id: String
        let symbol: String
        let label: String
        let color: Color
    }

    private var legend: [LegendItem] {
        markers.map { marker in
            let label: String
            switch marker.kind {
            case "pace": label = "Fastest"
            case "silence": label = "Longest pause"
            case "fillers": label = "Fillers"
            default: label = marker.kind
            }
            return LegendItem(id: marker.kind, symbol: marker.symbol, label: label, color: marker.color)
        }
    }

    // MARK: - Copy

    private var summaryLine: String { RepTimelineCopy.summaryLine(for: locations) }
    private var accessibilityReadout: String { RepTimelineCopy.accessibilityReadout(for: locations) }

    private func formatSeconds(_ value: Double) -> String {
        RepTimelineCopy.formatSeconds(value)
    }
}

// MARK: - Rep Timeline Copy
//
// Pure, view-free derivation of the card's user-facing strings, extracted so
// the data → text contract is unit-testable without a SwiftUI host. The card
// is the only renderer; this is the only place the copy is shaped.

enum RepTimelineCopy {
    /// Reuses the engine's own positional readout verbatim (minus its internal
    /// prefix) so the card never invents a claim the model didn't already make.
    static func summaryLine(for locations: RepEventLocations) -> String {
        let prefix = "Positional read (most-recent rep): "
        var line = locations.readout
        if line.hasPrefix(prefix) {
            line.removeFirst(prefix.count)
        }
        guard let first = line.first else { return line }
        return first.uppercased() + line.dropFirst()
    }

    /// One coherent VoiceOver sentence covering exactly the present signals,
    /// in the same fastest → pause → fillers order the card draws them.
    static func accessibilityReadout(for locations: RepEventLocations) -> String {
        var parts: [String] = []
        if let zone = locations.rushedBurstZone, let wpm = locations.rushedBurstWPM {
            parts.append("fastest stretch \(Int(wpm.rounded())) wpm in the \(zone.label)")
        }
        if let zone = locations.longestPauseZone, let seconds = locations.longestPauseSeconds {
            parts.append("longest pause \(formatSeconds(seconds)) in the \(zone.label)")
        }
        if let zone = locations.fillerClusterZone, let count = locations.fillerClusterCount {
            parts.append("fillers ×\(count) in the \(zone.label)")
        }
        return "Where it landed. " + parts.joined(separator: ", ") + "."
    }

    static func formatSeconds(_ value: Double) -> String {
        if value >= 10 { return String(format: "%.0fs", value) }
        return String(format: "%.1fs", value)
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Timeline — all three signals") {
    RepTimelineCard(locations: RepEventLocations(
        longestPauseZone: .opening,
        longestPauseSeconds: 1.4,
        rushedBurstZone: .close,
        rushedBurstWPM: 168,
        fillerClusterZone: .middle,
        fillerClusterCount: 3,
        readout: "Positional read (most-recent rep): the fastest stretch (~168 wpm) ran in the close; the longest silence (1.4s) fell in the opening; fillers clustered in the middle (3)."
    ))
    .padding()
    .background(AppColor.screenBackground)
}

@available(iOS 17.0, *)
#Preview("Timeline — single signal") {
    RepTimelineCard(locations: RepEventLocations(
        longestPauseZone: nil,
        longestPauseSeconds: nil,
        rushedBurstZone: .close,
        rushedBurstWPM: 172,
        fillerClusterZone: nil,
        fillerClusterCount: nil,
        readout: "Positional read (most-recent rep): the fastest stretch (~172 wpm) ran in the close."
    ))
    .padding()
    .background(AppColor.screenBackground)
}
#endif

#endif
