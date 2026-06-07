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

// MARK: - Achievement Unlock Celebration

@available(iOS 17.0, *)
struct AchievementUnlockCelebration: View {
    let tier: AchievementTier
    let onContinue: () -> Void

    @State private var phase1 = false
    @State private var phase2 = false
    @State private var phase3 = false

    var body: some View {
        ZStack {
            // Dark background tinted by track
            LinearGradient(
                colors: [
                    Color.black,
                    tier.track.gradient[0].opacity(0.12),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Particles
            if phase3 {
                achievementParticles
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                Spacer()

                // Radiating rings + icon
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(
                                tier.track.accentGradient[0].opacity(phase1 ? 0.08 - Double(i) * 0.02 : 0),
                                lineWidth: 1.5
                            )
                            .frame(width: CGFloat(180 + i * 40), height: CGFloat(180 + i * 40))
                            .scaleEffect(phase1 ? 1.0 : 0.3)
                    }

                    AchievementIconView(
                        tier: tier,
                        isUnlocked: true,
                        progress: 1.0,
                        size: .celebrate
                    )
                    .scaleEffect(phase1 ? 1.0 : 0.1)
                }

                Spacer().frame(height: 40)

                // Text content
                VStack(spacing: 14) {
                    Text("ACHIEVEMENT UNLOCKED")
                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(tier.track.accentGradient[0])
                        .opacity(phase2 ? 1 : 0)
                        .offset(y: phase2 ? 0 : 20)

                    Text(tier.title)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(phase2 ? 1 : 0)
                        .scaleEffect(phase2 ? 1.0 : 0.85)

                    Text(tier.description)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(phase2 ? 1 : 0)
                        .offset(y: phase2 ? 0 : 10)

                    // Track badge
                    HStack(spacing: 5) {
                        Image(systemName: tier.track.symbol)
                            .font(.caption2)
                        Text(tier.track.label.uppercased())
                            .font(.system(size: 10, weight: .heavy))
                            .tracking(1.5)
                    }
                    .foregroundStyle(tier.track.tint)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(tier.track.tint.opacity(0.15), in: Capsule())
                    .opacity(phase2 ? 1 : 0)
                }

                Spacer()

                // Continue
                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(tier.track.accentGradient[0], in: Capsule())
                }
                .buttonStyle(.pressable)
                .opacity(phase2 ? 1 : 0)
                .offset(y: phase2 ? 0 : 30)
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
#if canImport(UIKit)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred()
#endif
        withAnimation(.spring(response: 0.6, dampingFraction: 0.65)) {
            phase1 = true
        }
#if canImport(UIKit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
#endif
        withAnimation(.easeOut(duration: 0.5).delay(0.35)) {
            phase2 = true
        }
        withAnimation(.easeIn(duration: 0.3).delay(0.5)) {
            phase3 = true
        }
    }

    private var achievementParticles: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 20.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<14, id: \.self) { i in
                        let seed = Double(i) * 1.618
                        let x = geo.size.width * (0.08 + (seed.truncatingRemainder(dividingBy: 0.85)))
                        let speed = 0.5 + seed.truncatingRemainder(dividingBy: 0.8)
                        let travel = (t * speed).truncatingRemainder(dividingBy: 4.5) / 4.5
                        let y = geo.size.height * (1.0 - travel)

                        Circle()
                            .fill(tier.track.accentGradient[0].opacity(0.2 * (1.0 - travel)))
                            .frame(width: CGFloat(2 + (i % 3) * 2), height: CGFloat(2 + (i % 3) * 2))
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Post-Session Progression View

@available(iOS 17.0, *)
struct PostSessionProgressionView: View {
    let xpEarned: Int
    let previousXP: Int
    let newXP: Int
    let previousLevel: String
    let newLevel: String
    let achievementProgress: [AchievementProgressDelta]
    let newUnlocks: [AchievementTier]
    let onContinue: () -> Void

    @State private var showXP = false
    @State private var xpBarProgress: Double = 0
    @State private var showAchievements = false
    @State private var showButton = false
    @State private var currentUnlockIndex: Int = -1

    private var didLevelUp: Bool { previousLevel != newLevel }

    /// Show at most 3 achievement progress rows — prioritize newly unlocked, then biggest jumps.
    private var topDeltas: [AchievementProgressDelta] {
        let sorted = achievementProgress.sorted {
            // Newly unlocked first, then by progress delta size
            let aUnlocked = $0.newProgress >= 1.0 && $0.previousProgress < 1.0
            let bUnlocked = $1.newProgress >= 1.0 && $1.previousProgress < 1.0
            if aUnlocked != bUnlocked { return aUnlocked }
            return ($0.newProgress - $0.previousProgress) > ($1.newProgress - $1.previousProgress)
        }
        return Array(sorted.prefix(3))
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.10),
                    Color(red: 0.08, green: 0.08, blue: 0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Unlock celebrations shown one at a time
            if currentUnlockIndex >= 0 && currentUnlockIndex < newUnlocks.count {
                AchievementUnlockCelebration(
                    tier: newUnlocks[currentUnlockIndex],
                    onContinue: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            if currentUnlockIndex + 1 < newUnlocks.count {
                                currentUnlockIndex += 1
                            } else {
                                currentUnlockIndex = -1
                            }
                        }
                    }
                )
                .transition(.opacity)
                .zIndex(10)
            } else {
                // Game-style reward screen — concise, no scrolling if possible
                VStack(spacing: 0) {
                    Spacer()

                    // XP earned — big hero number
                    VStack(spacing: 6) {
                        Text("SESSION COMPLETE")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(3)
                            .foregroundStyle(.white.opacity(0.4))

                        Text("+\(xpEarned) XP")
                            .font(.system(size: 52, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.orange, Color.yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        if didLevelUp {
                            Text("LEVEL UP → \(newLevel)")
                                .font(.system(size: 12, weight: .heavy, design: .rounded))
                                .tracking(1.5)
                                .foregroundStyle(.purple)
                                .padding(.top, 2)
                        }
                    }
                    .opacity(showXP ? 1 : 0)
                    .scaleEffect(showXP ? 1 : 0.8)

                    // XP bar — compact
                    VStack(spacing: 8) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(.white.opacity(0.08))
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(geo.size.width * xpBarProgress, 8))
                                    .shadow(color: .blue.opacity(0.4), radius: 6)
                            }
                        }
                        .frame(height: 10)

                        HStack {
                            Text(newLevel)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white.opacity(0.6))
                            Spacer()
                            Text("\(ProfileManager.xpNeededToNextLevel(forXP: newXP)) XP to next level")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.white.opacity(0.30))
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 18)
                    .opacity(showXP ? 1 : 0)

                    // Achievement deltas — max 3 rows, compact
                    if !topDeltas.isEmpty {
                        VStack(spacing: 10) {
                            ForEach(Array(topDeltas.enumerated()), id: \.element.id) { index, delta in
                                compactProgressRow(delta, index: index)
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 28)
                        .opacity(showAchievements ? 1 : 0)
                        .offset(y: showAchievements ? 0 : 15)
                    }

                    Spacer()

                    // Continue button
                    Button {
                        onContinue()
                    } label: {
                        Text("View Summary")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                ),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.pressable)
                    .accessibilityIdentifier("postSessionProgression.viewSummary")
                    .opacity(showButton ? 1 : 0)
                    .offset(y: showButton ? 0 : 30)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 50)
                }
            }
        }
        .onAppear { runProgressionAnimation() }
    }

    /// Compact achievement row — icon + title + inline progress bar, single line feel.
    private func compactProgressRow(_ delta: AchievementProgressDelta, index: Int) -> some View {
        HStack(spacing: 12) {
            if let t = AchievementStore.tier(for: delta.id) {
                AchievementIconView(
                    tier: t,
                    isUnlocked: delta.newProgress >= 1.0,
                    progress: delta.newProgress,
                    size: .grid
                )
                .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(delta.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    if delta.newProgress >= 1.0 {
                        Text("UNLOCKED")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(.green)
                    } else {
                        Text(delta.progressLabel)
                            .font(.caption2.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.45))
                    }
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(.white.opacity(0.06))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(delta.newProgress >= 1.0
                                ? AnyShapeStyle(Color.green)
                                : AnyShapeStyle(Color.blue.opacity(0.6)))
                            .frame(width: max(geo.size.width * delta.newProgress, 4))
                    }
                }
                .frame(height: 5)
            }
        }
        .animation(.easeOut(duration: 0.35).delay(Double(index) * 0.10), value: showAchievements)
    }

    private func runProgressionAnimation() {
        if !newUnlocks.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentUnlockIndex = 0
                }
            }
        }

        let xpDelay: Double = 0.2
        DispatchQueue.main.asyncAfter(deadline: .now() + xpDelay) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showXP = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + xpDelay + 0.3) {
            withAnimation(.easeOut(duration: 0.8)) {
                xpBarProgress = ProfileManager.progressTowardsNextLevel(forXP: newXP)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + xpDelay + 0.8) {
            withAnimation(.easeOut(duration: 0.5)) {
                showAchievements = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + xpDelay + 1.4) {
            withAnimation(.easeOut(duration: 0.4)) {
                showButton = true
            }
        }
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
