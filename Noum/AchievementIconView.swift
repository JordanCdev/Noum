import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Achievement Icon View System
//
// Premium, composited achievement icons using SF Symbols, custom shapes,
// gradients, and layered treatments. Track-aware with tier progression.
//
// External asset override: add images named "achievement_{id}" to Assets.xcassets.

// MARK: - Icon Size Presets

enum AchievementIconSize {
    case grid       // 52pt — ProfileView grid
    case detail     // 88pt — detail modal focus
    case celebrate  // 120pt — unlock celebration

    var diameter: CGFloat {
        switch self {
        case .grid: return 52
        case .detail: return 88
        case .celebrate: return 120
        }
    }

    var symbolSize: CGFloat {
        switch self {
        case .grid: return 18
        case .detail: return 32
        case .celebrate: return 44
        }
    }

    var ringWidth: CGFloat {
        switch self {
        case .grid: return 2
        case .detail: return 3
        case .celebrate: return 4.5
        }
    }
}

// MARK: - Container Shapes

enum AchievementContainerShape {
    case shield, hexagon, diamond, circle, octagon, medal, roundedSquare

    static func shape(for track: AchievementTrack) -> AchievementContainerShape {
        switch track {
        case .volume:      return .shield
        case .consistency: return .hexagon
        case .clarity:     return .diamond
        case .scores:      return .octagon
        case .endurance:   return .roundedSquare
        case .modes:       return .circle
        case .mastery:     return .medal
        }
    }
}

// MARK: - Main Icon View

@available(iOS 17.0, *)
struct AchievementIconView: View {
    let tier: AchievementTier
    let isUnlocked: Bool
    let progress: Double
    let size: AchievementIconSize

    private var hasCustomAsset: Bool {
        UIImage(named: "achievement_\(tier.id)") != nil
    }

    private var track: AchievementTrack { tier.track }

    /// Tier glow intensity — higher tiers glow more.
    private var tierGlowOpacity: Double {
        guard tier.totalTiersInTrack > 1 else { return 0.15 }
        let fraction = Double(tier.tierIndex) / Double(tier.totalTiersInTrack - 1)
        return 0.10 + fraction * 0.25
    }

    /// Whether this is the final tier in its track.
    private var isFinalTier: Bool {
        tier.tierIndex == tier.totalTiersInTrack - 1
    }

    var body: some View {
        if hasCustomAsset {
            customAssetIcon
        } else if isUnlocked {
            unlockedIcon
        } else {
            lockedIcon
        }
    }

    // MARK: - Custom Asset

    private var customAssetIcon: some View {
        ZStack {
            Image("achievement_\(tier.id)")
                .resizable()
                .scaledToFit()
                .frame(width: size.diameter, height: size.diameter)
                .clipShape(Circle())

            if !isUnlocked {
                // Desaturated overlay — light wash instead of dark blackout
                Circle()
                    .fill(.white.opacity(0.70))
                    .frame(width: size.diameter, height: size.diameter)

                Image(systemName: tier.symbolName)
                    .font(.system(size: size.symbolSize * 0.65, weight: .semibold))
                    .foregroundStyle(track.tint.opacity(0.30))
            }
        }
    }

    // MARK: - Unlocked Icon

    private var unlockedIcon: some View {
        let shape = AchievementContainerShape.shape(for: track)

        return ZStack {
            // Outer glow — only at detail/celebrate sizes and for higher tiers
            if tier.tierIndex >= 1 && size != .grid {
                containerPath(shape)
                    .fill(
                        RadialGradient(
                            colors: [track.accentGradient[0].opacity(tierGlowOpacity), .clear],
                            center: .center,
                            startRadius: size.diameter * 0.2,
                            endRadius: size.diameter * 0.65
                        )
                    )
                    .frame(width: size.diameter * 1.3, height: size.diameter * 1.3)
            }

            // Base filled shape
            containerPath(shape)
                .fill(
                    LinearGradient(
                        colors: track.gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.diameter, height: size.diameter)
                .shadow(
                    color: track.gradient[0].opacity(size == .grid ? 0.20 : 0.30),
                    radius: size == .celebrate ? 16 : (size == .grid ? 3 : 6),
                    y: size == .celebrate ? 5 : 2
                )

            // Inner border — subtle accent edge
            containerPath(shape)
                .stroke(
                    LinearGradient(
                        colors: track.accentGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: size == .grid ? 1.5 : size.ringWidth
                )
                .frame(width: size.diameter - size.ringWidth, height: size.diameter - size.ringWidth)

            // Specular highlight — only at detail/celebrate for cleaner grid icons
            if size != .grid {
                containerPath(shape)
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.18), .clear, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size.diameter - size.ringWidth * 2, height: size.diameter - size.ringWidth * 2)
            }

            // Center symbol — white for all tracks
            Image(systemName: tier.symbolName)
                .font(.system(size: size.symbolSize, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.25), radius: 1.5, y: 1)

            // Tier position now shown as text in the detail sheet — no pips on icon
        }
        .frame(width: size.diameter * 1.3, height: size.diameter * 1.3)
    }

    // MARK: - Locked Icon

    private var lockedIcon: some View {
        let shape = AchievementContainerShape.shape(for: track)

        return ZStack {
            // Light muted fill — sits naturally on the light page background
            containerPath(shape)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.92), Color(white: 0.88)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.diameter, height: size.diameter)

            // Soft track-color tint overlay
            containerPath(shape)
                .fill(
                    LinearGradient(
                        colors: track.gradient.map { $0.opacity(0.08) },
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size.diameter, height: size.diameter)

            // Visible border in track color
            containerPath(shape)
                .stroke(
                    track.tint.opacity(0.20),
                    lineWidth: size == .grid ? 1.5 : 2
                )
                .frame(width: size.diameter - size.ringWidth, height: size.diameter - size.ringWidth)

            // Symbol silhouette — clearly visible, muted but not invisible
            Image(systemName: tier.symbolName)
                .font(.system(size: size.symbolSize * 0.80, weight: .semibold))
                .foregroundStyle(track.tint.opacity(0.30))
        }
        .frame(width: size.diameter * 1.3, height: size.diameter * 1.3)
    }

    // MARK: - Shape Path Helper

    private func containerPath(_ shape: AchievementContainerShape) -> AnyShape {
        switch shape {
        case .shield:       AnyShape(ShieldShape())
        case .hexagon:      AnyShape(HexagonShape())
        case .diamond:      AnyShape(DiamondShape())
        case .circle:       AnyShape(Circle())
        case .octagon:      AnyShape(OctagonShape())
        case .medal:        AnyShape(MedalShape())
        case .roundedSquare: AnyShape(RoundedSquareShape())
        }
    }
}

// MARK: - Custom Shapes

struct ShieldShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: w * 0.12, y: h * 0.06))
        p.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.06), control: CGPoint(x: w * 0.5, y: 0))
        p.addLine(to: CGPoint(x: w * 0.92, y: h * 0.08))
        p.addQuadCurve(to: CGPoint(x: w * 0.85, y: h * 0.65), control: CGPoint(x: w * 0.94, y: h * 0.35))
        p.addQuadCurve(to: CGPoint(x: w * 0.5, y: h * 0.96), control: CGPoint(x: w * 0.72, y: h * 0.88))
        p.addQuadCurve(to: CGPoint(x: w * 0.15, y: h * 0.65), control: CGPoint(x: w * 0.28, y: h * 0.88))
        p.addQuadCurve(to: CGPoint(x: w * 0.08, y: h * 0.08), control: CGPoint(x: w * 0.06, y: h * 0.35))
        p.closeSubpath()
        return p
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.width / 2, cy = rect.height / 2
        let r = min(rect.width, rect.height) / 2 * 0.92
        var p = Path()
        for i in 0..<6 {
            let angle = Angle(degrees: Double(i) * 60 - 90).radians
            let pt = CGPoint(x: cx + r * Foundation.cos(angle), y: cy + r * Foundation.sin(angle))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.width / 2, cy = rect.height / 2
        let rx = rect.width * 0.46, ry = rect.height * 0.46
        var p = Path()
        p.move(to: CGPoint(x: cx, y: cy - ry))
        p.addQuadCurve(to: CGPoint(x: cx + rx, y: cy), control: CGPoint(x: cx + rx * 0.55, y: cy - ry * 0.55))
        p.addQuadCurve(to: CGPoint(x: cx, y: cy + ry), control: CGPoint(x: cx + rx * 0.55, y: cy + ry * 0.55))
        p.addQuadCurve(to: CGPoint(x: cx - rx, y: cy), control: CGPoint(x: cx - rx * 0.55, y: cy + ry * 0.55))
        p.addQuadCurve(to: CGPoint(x: cx, y: cy - ry), control: CGPoint(x: cx - rx * 0.55, y: cy - ry * 0.55))
        p.closeSubpath()
        return p
    }
}

struct OctagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        let cx = rect.width / 2, cy = rect.height / 2
        let r = min(rect.width, rect.height) / 2 * 0.92
        var p = Path()
        for i in 0..<8 {
            let angle = Angle(degrees: Double(i) * 45 - 90).radians
            let pt = CGPoint(x: cx + r * Foundation.cos(angle), y: cy + r * Foundation.sin(angle))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

struct RoundedSquareShape: Shape {
    func path(in rect: CGRect) -> Path {
        let inset = min(rect.width, rect.height) * 0.08
        return Path(roundedRect: rect.insetBy(dx: inset, dy: inset), cornerRadius: min(rect.width, rect.height) * 0.22)
    }
}

struct MedalShape: Shape {
    func path(in rect: CGRect) -> Path {
        // 8-point starburst badge — clean, reads at any size, feels premium
        let cx = rect.width / 2, cy = rect.height / 2
        let outerR = min(rect.width, rect.height) / 2 * 0.92
        let innerR = outerR * 0.82
        let points = 8
        var p = Path()
        for i in 0..<(points * 2) {
            let angle = Angle(degrees: Double(i) * (360.0 / Double(points * 2)) - 90).radians
            let r = i.isMultiple(of: 2) ? outerR : innerR
            let pt = CGPoint(x: cx + r * Foundation.cos(angle), y: cy + r * Foundation.sin(angle))
            i == 0 ? p.move(to: pt) : p.addLine(to: pt)
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Achievement Progress Delta

struct AchievementProgressDelta: Identifiable {
    let id: String
    let title: String
    let previousProgress: Double
    let newProgress: Double
    let progressLabel: String
}

#endif
