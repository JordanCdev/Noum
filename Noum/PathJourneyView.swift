import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct PathJourneyView: View {
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var daylightModel = PathDaylightModel()

    private var snapshot: PracticeJourneySnapshot {
        PracticeJourneySnapshot.make(from: sessionStore.sessions)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.93, blue: 0.88),
                    Color.white,
                    Color(red: 0.89, green: 0.96, blue: 0.91)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Path")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                        Text(snapshot.summaryLine)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        PathJourneyArtwork(
                            snapshot: snapshot,
                            compact: false,
                            scene: daylightModel.sceneState(for: Date())
                        )
                            .frame(height: 320)

                        HStack(spacing: 10) {
                            journeyPill(title: "Revealed", value: snapshot.progressLabel, accent: .green)
                            journeyPill(title: "Current streak", value: snapshot.streakLabel, accent: .blue)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("What this means")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Text(snapshot.explanationLine)
                                .font(.subheadline.weight(.semibold))
                            Text(snapshot.consequenceLine)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(snapshot.nextMilestoneLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(22)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.96),
                                Color(red: 0.93, green: 0.97, blue: 0.94).opacity(0.88)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .stroke(Color.white.opacity(0.72), lineWidth: 1)
                    )
                }
                .padding(18)
                .padding(.top, 10)
                .padding(.bottom, 36)
            }
        }
        .navigationTitle("Path")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            daylightModel.activate()
        }
    }

    private func journeyPill(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(accent.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct PracticeJourneySnapshot {
    let practicedDays: Int
    let streak: Int
    let revealProgress: Double
    let quality: Double
    let progressLabel: String
    let previewLine: String
    let summaryLine: String
    let explanationLine: String
    let nextMilestoneLabel: String
    let consequenceLine: String
    let homeGoalLine: String
    let homeGoalShortLabel: String

    static func make(from sessions: [PracticeSession]) -> PracticeJourneySnapshot {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let windowDays = 21
        let windowStart = calendar.date(byAdding: .day, value: -(windowDays - 1), to: today) ?? today

        let uniqueWindowDays = Set(
            sessions
                .map { calendar.startOfDay(for: $0.date) }
                .filter { $0 >= windowStart && $0 <= today }
        )
        let practicedDays = uniqueWindowDays.count

        let recentSessions = Array(sessions.prefix(10))
        let averageFillers = recentSessions.isEmpty
            ? 0
            : Double(recentSessions.map(\.fillerWordCount).reduce(0, +)) / Double(recentSessions.count)
        let averageDuration = recentSessions.isEmpty
            ? 0
            : recentSessions.map(\.duration).reduce(0, +) / Double(recentSessions.count)
        let averageScore = recentSessions.compactMap(\.score).isEmpty
            ? 0
            : Double(recentSessions.compactMap(\.score).reduce(0, +)) / Double(recentSessions.compactMap(\.score).count)

        let streak = currentStreak(from: sessions, calendar: calendar)
        let consistency = min(1, Double(practicedDays) / Double(windowDays))
        let scoreQuality = min(1, averageScore / 100)
        let fillerQuality = max(0, 1 - (averageFillers / 8))
        let durationQuality = min(1, averageDuration / 45)
        let streakQuality = min(1, Double(streak) / 7)
        let quality = min(1, (scoreQuality * 0.30) + (fillerQuality * 0.30) + (durationQuality * 0.20) + (streakQuality * 0.20))
        let streakMomentum = max(0, Double(streak - 1) / Double(windowDays))
        let revealProgress = min(
            1,
            max(
                practicedDays > 0 ? 0.05 : 0,
                (consistency * 0.82) + (quality * 0.08) + (streakMomentum * 0.10)
            )
        )

        let progressPercent = Int((revealProgress * 100).rounded())
        let milestoneIndex = min(3, Int(revealProgress * 4))
        let milestoneDays = [5, 10, 15, 21]
        let nextMilestoneDay = milestoneDays.first(where: { practicedDays < $0 }) ?? 21
        let daysRemaining = max(0, nextMilestoneDay - practicedDays)

        let previewLine: String
        if practicedDays == 0 {
            previewLine = "The trail is still hidden. Today's rep starts clearing it."
        } else if streak >= 3 {
            previewLine = "The trail is opening up. Each steady rep makes your speaking path easier to follow."
        } else {
            previewLine = "You have started the trail. Keep returning before the grass closes back in."
        }

        let explanationLine: String
        switch milestoneIndex {
        case 0:
            explanationLine = "You are still cutting the first line through the grass. Early reps matter because they prove the path can exist."
        case 1:
            explanationLine = "The trail is starting to hold. What felt hidden is becoming a repeatable speaking habit."
        case 2:
            explanationLine = "The route is clear enough to trust. Repetition is starting to change how you answer under pressure."
        default:
            explanationLine = "The path is established. You are reinforcing a speaking identity, not just logging reps."
        }

        let nextMilestoneLabel: String
        if practicedDays == 0 {
            nextMilestoneLabel = "Complete today's rep to reveal the first section."
        } else if daysRemaining == 0 {
            nextMilestoneLabel = "You have reached the current milestone. Keep going to widen and strengthen the path."
        } else {
            nextMilestoneLabel = "\(daysRemaining) more day\(daysRemaining == 1 ? "" : "s") to reveal the next section."
        }

        let consequenceLine: String
        if practicedDays == 0 {
            consequenceLine = "Leave it untouched and the grass keeps covering the route you want to build."
        } else if streak <= 1 {
            consequenceLine = "Miss too many days and the trail softens again. Consistency keeps it visible."
        } else {
            consequenceLine = "Staying with it keeps the route open and makes confident speaking feel more natural."
        }

        let homeGoalLine: String
        if practicedDays == 0 {
            homeGoalLine = "Start the path with one rep today."
        } else {
            homeGoalLine = "\(practicedDays) of 21 days trained. \(nextMilestoneLabel)"
        }

        let homeGoalShortLabel: String
        if practicedDays == 0 {
            homeGoalShortLabel = "Begin"
        } else if daysRemaining == 0 {
            homeGoalShortLabel = "Opened"
        } else {
            homeGoalShortLabel = "\(daysRemaining) day\(daysRemaining == 1 ? "" : "s")"
        }

        return PracticeJourneySnapshot(
            practicedDays: practicedDays,
            streak: streak,
            revealProgress: revealProgress,
            quality: quality,
            progressLabel: "\(progressPercent)% revealed",
            previewLine: previewLine,
            summaryLine: "Built from the last \(windowDays) days of practice, consistency, and session quality.",
            explanationLine: explanationLine,
            nextMilestoneLabel: nextMilestoneLabel,
            consequenceLine: consequenceLine,
            homeGoalLine: homeGoalLine,
            homeGoalShortLabel: homeGoalShortLabel
        )
    }

    var streakLabel: String {
        streak > 0 ? "\(streak) day\(streak == 1 ? "" : "s")" : "No streak yet"
    }

    private static func currentStreak(from sessions: [PracticeSession], calendar: Calendar) -> Int {
        let uniqueDays = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        guard !uniqueDays.isEmpty else { return 0 }

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())
        while uniqueDays.contains(cursor) {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previousDay
        }
        return streak
    }
}

struct PathJourneyArtwork: View {
    let snapshot: PracticeJourneySnapshot
    let compact: Bool
    let scene: PathSkyScene

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 15.0)) { timeline in
            let phase = breezePhase(for: timeline.date)

            GeometryReader { geometry in
                let size = geometry.size

                ZStack {
                    RoundedRectangle(cornerRadius: compact ? 24 : 30, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    scene.skyTop,
                                    scene.skyMiddle,
                                    scene.skyBottom
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    skyGlow(size: size, scene: scene)
                    celestialBody(size: size, scene: scene)
                    cloudHaze(size: size, scene: scene)
                    if scene.isNight {
                        starField(size: size)
                    }

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.70, green: 0.74, blue: 0.46),
                                    Color(red: 0.52, green: 0.60, blue: 0.28),
                                    Color(red: 0.32, green: 0.42, blue: 0.14)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: size.height * 0.46)
                        .frame(maxHeight: .infinity, alignment: .bottom)

                    fieldTexture(size: size)

                    ZStack {
                        PerspectivePathShape()
                            .fill(Color(red: 0.43, green: 0.37, blue: 0.27).opacity(0.03 + (snapshot.revealProgress * 0.04)))

                        PerspectivePathShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.47, green: 0.39, blue: 0.29).opacity(0.10 + (snapshot.revealProgress * 0.14)),
                                        Color(red: 0.60, green: 0.52, blue: 0.37).opacity(0.08 + (snapshot.revealProgress * 0.18)),
                                        Color(red: 0.74, green: 0.68, blue: 0.49).opacity(0.03 + (snapshot.revealProgress * 0.14))
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .mask(alignment: .bottom) {
                                Rectangle()
                                    .frame(height: revealedDepth(for: size))
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }

                        PerspectivePathTextureShape()
                            .stroke(Color(red: 0.39, green: 0.31, blue: 0.22).opacity(0.03 + (snapshot.revealProgress * 0.08)), lineWidth: compact ? 0.7 : 0.9)
                            .mask(alignment: .bottom) {
                                Rectangle()
                                    .frame(height: revealedDepth(for: size))
                                    .frame(maxHeight: .infinity, alignment: .bottom)
                            }

                        flowerDots(size: size, phase: phase)

                        ForEach(grassBlades(for: size)) { blade in
                            RoundedRectangle(cornerRadius: blade.width / 2, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            grassBaseColor(for: blade).opacity(blade.opacity),
                                            grassHighlightColor(for: blade).opacity(blade.opacity * 0.92)
                                        ],
                                        startPoint: .bottom,
                                        endPoint: .top
                                    )
                                )
                                .frame(width: blade.width, height: blade.height)
                                .rotationEffect(.degrees(blade.rotation + (blade.animates ? phase * blade.sway : 0)))
                                .offset(x: CGFloat(blade.animates ? phase : 0) * blade.offset)
                                .position(blade.position)
                        }
                    }
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: size.height * 0.46)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                    }

                    distantTrees(size: size)
                }
                .clipShape(RoundedRectangle(cornerRadius: compact ? 24 : 30, style: .continuous))
            }
        }
    }

    private func revealedDepth(for size: CGSize) -> CGFloat {
        let minimum = compact ? size.height * 0.06 : size.height * 0.08
        let maximum = compact ? size.height * 0.58 : size.height * 0.78
        return minimum + (maximum - minimum) * snapshot.revealProgress
    }

    private func grassBlades(for size: CGSize) -> [JourneyGrassBlade] {
        let overgrowth = 1 - snapshot.revealProgress
        let rowCount = compact ? 10 : 17
        let bladesPerRow = compact ? 28 : 46

        return (0..<rowCount).flatMap { row in
            (0..<bladesPerRow).compactMap { column in
                let depth = Double(row) / Double(max(1, rowCount - 1))
                let y = 0.44 + depth * 0.50
                let x = (Double(column) + 0.5) / Double(bladesPerRow)
                let pathHalfWidth = pathHalfWidth(at: y, compact: compact)
                let distanceFromCenter = abs(x - 0.5)
                let insidePath = distanceFromCenter < pathHalfWidth * (0.70 + (overgrowth * 0.36))
                let revealedLine = 1 - (revealedDepth(for: size) / size.height)
                let pathVisibilityBuffer = 0.05 + (snapshot.revealProgress * 0.10)
                let clumpWave = (sin((x * 18) + (depth * 6.5)) + cos((x * 29) - (depth * 8.0))) * 0.5
                let clumpStrength = 0.72 + (max(0, clumpWave) * 0.55)
                let shouldSkipForPatchiness = clumpWave < -0.38 && !insidePath

                if insidePath && y > (revealedLine + pathVisibilityBuffer) {
                    return nil
                }

                if shouldSkipForPatchiness {
                    return nil
                }

                let noise = sin((Double(column) * 1.17) + (Double(row) * 0.73))
                let perspectiveScale = 0.28 + pow(depth, 1.9) * 1.75
                let worldHeight = (compact ? 18.0 : 26.0) * clumpStrength
                let overgrowthHeight = compact ? 8.0 : 12.0
                let width = (compact ? 1.8 : 2.2) + (perspectiveScale * (compact ? 1.8 : 2.4))
                let height = (worldHeight + (overgrowth * overgrowthHeight)) * perspectiveScale
                let animates = depth > 0.74
                let dryness = 0.35 + max(0, (0.5 - clumpWave)) * 0.7
                return JourneyGrassBlade(
                    position: CGPoint(
                        x: size.width * x,
                        y: size.height * y
                    ),
                    width: width,
                    height: height + abs(noise * (compact ? 3.0 : 4.5)),
                    rotation: (-22 + (noise * 24)),
                    opacity: 0.18 + (depth * 0.34) + (overgrowth * 0.18),
                    sway: (compact ? 2.2 : 3.0) + (depth * 3.2),
                    offset: (compact ? 0.6 : 1.0) + (depth * 2.2),
                    animates: animates,
                    tintMix: dryness
                )
            }
        }
    }

    private func breezePhase(for date: Date) -> Double {
        let time = date.timeIntervalSinceReferenceDate
        return sin(time * 1.1) * 0.8 + sin(time * 0.33) * 0.35
    }

    @ViewBuilder
    private func skyGlow(size: CGSize, scene: PathSkyScene) -> some View {
        RadialGradient(
            colors: [
                scene.glowColor.opacity(scene.isNight ? 0.18 : 0.40),
                scene.glowColor.opacity(scene.isNight ? 0.08 : 0.16),
                Color.clear
            ],
            center: .topTrailing,
            startRadius: 6,
            endRadius: compact ? 120 : 180
        )
        .frame(width: size.width, height: size.height * 0.46)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func celestialBody(size: CGSize, scene: PathSkyScene) -> some View {
        ZStack {
            Circle()
                .fill(scene.celestialGlow.opacity(scene.isNight ? 0.22 : 0.30))
                .frame(width: compact ? 54 : 82, height: compact ? 54 : 82)
            Circle()
                .fill(scene.celestialBody)
                .frame(width: compact ? 22 : 30, height: compact ? 22 : 30)
        }
        .position(x: size.width * scene.celestialX, y: size.height * scene.celestialY)
    }

    @ViewBuilder
    private func cloudHaze(size: CGSize, scene: PathSkyScene) -> some View {
        ForEach(0..<3, id: \.self) { index in
            Capsule()
                .fill(scene.cloudColor.opacity(scene.isNight ? 0.12 : 0.18))
                .frame(width: compact ? 72 : 110, height: compact ? 16 : 22)
                .blur(radius: compact ? 6 : 9)
                .position(
                    x: size.width * [0.24, 0.50, 0.70][index],
                    y: size.height * [0.12, 0.18, 0.10][index]
                )
        }
    }

    @ViewBuilder
    private func starField(size: CGSize) -> some View {
        ForEach(0..<12, id: \.self) { index in
            Circle()
                .fill(Color.white.opacity(0.65))
                .frame(width: index.isMultiple(of: 3) ? 2.4 : 1.6, height: index.isMultiple(of: 3) ? 2.4 : 1.6)
                .position(
                    x: size.width * [0.12, 0.22, 0.33, 0.45, 0.58, 0.66, 0.74, 0.82, 0.18, 0.38, 0.54, 0.88][index],
                    y: size.height * [0.08, 0.16, 0.10, 0.06, 0.14, 0.09, 0.19, 0.12, 0.21, 0.17, 0.05, 0.15][index]
                )
        }
    }

    @ViewBuilder
    private func flowerDots(size: CGSize, phase: Double) -> some View {
        ForEach(flowerNodes(for: size)) { flower in
            ZStack {
                ForEach(0..<4, id: \.self) { petal in
                    Circle()
                        .fill(flower.color.opacity(0.90))
                        .frame(width: flower.size * 0.55, height: flower.size * 0.55)
                        .offset(
                            x: cos(Double(petal) * .pi / 2) * flower.size * 0.28,
                            y: sin(Double(petal) * .pi / 2) * flower.size * 0.28
                        )
                }
                Circle()
                    .fill(Color(red: 0.99, green: 0.88, blue: 0.42))
                    .frame(width: flower.size * 0.24, height: flower.size * 0.24)
            }
            .rotationEffect(.degrees(phase * flower.sway))
            .position(flower.position)
            .opacity(flower.opacity)
        }
    }

    private func flowerNodes(for size: CGSize) -> [JourneyFlowerNode] {
        let values: [(Double, Double, Color, Double)] = [
            (0.16, 0.82, Color.white, 0.58),
            (0.22, 0.88, Color.white, 0.52),
            (0.29, 0.84, Color(red: 0.98, green: 0.96, blue: 0.88), 0.48),
            (0.70, 0.82, Color(red: 0.98, green: 0.96, blue: 0.88), 0.46),
            (0.76, 0.79, Color.white, 0.54),
            (0.84, 0.86, Color.white, 0.50),
            (0.88, 0.81, Color(red: 0.98, green: 0.96, blue: 0.88), 0.44)
        ]
        return values.map { x, y, color, opacity in
            JourneyFlowerNode(
                position: CGPoint(x: size.width * x, y: size.height * y),
                size: compact ? 6 : 8,
                color: color,
                opacity: opacity,
                sway: compact ? 4 : 6
            )
        }
    }

    private func pathHalfWidth(at normalizedY: Double, compact: Bool) -> Double {
        let t = max(0, min(1, normalizedY))
        let base = compact ? 0.18 : 0.21
        let horizon = compact ? 0.012 : 0.018
        return horizon + ((base - horizon) * pow(t, 1.35))
    }

    @ViewBuilder
    private func fieldTexture(size: CGSize) -> some View {
        ZStack {
            ForEach(fieldPatches(for: size)) { patch in
                Ellipse()
                    .fill(patch.color.opacity(patch.opacity))
                    .frame(width: patch.width, height: patch.height)
                    .rotationEffect(.degrees(patch.rotation))
                    .position(patch.position)
            }
        }
        .mask(alignment: .bottom) {
            Rectangle()
                .frame(height: size.height * 0.46)
                .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }

    private func fieldPatches(for size: CGSize) -> [FieldPatch] {
        let rows = compact ? 6 : 9
        let columns = compact ? 8 : 12
        var patches: [FieldPatch] = []

        for row in 0..<rows {
            for column in 0..<columns {
                let depth = Double(row) / Double(max(1, rows - 1))
                let x = (Double(column) + 0.45) / Double(columns)
                let y = 0.34 + depth * 0.56
                let noise = sin((Double(column) * 1.9) + (Double(row) * 1.3))
                let width = (compact ? 22.0 : 34.0) + (depth * (compact ? 18.0 : 36.0))
                let height = (compact ? 10.0 : 14.0) + (depth * (compact ? 10.0 : 20.0))
                let color: Color = noise > 0
                    ? Color(red: 0.76, green: 0.73, blue: 0.49)
                    : Color(red: 0.46, green: 0.58, blue: 0.24)

                patches.append(
                    FieldPatch(
                        position: CGPoint(x: size.width * x, y: size.height * y),
                        width: width,
                        height: height,
                        rotation: noise * 12,
                        color: color,
                        opacity: 0.06 + (depth * 0.08)
                    )
                )
            }
        }

        return patches
    }

    @ViewBuilder
    private func distantTrees(size: CGSize) -> some View {
        ZStack {
            ForEach(treeSilhouettes(for: size)) { tree in
                ZStack(alignment: .bottom) {
                    HStack(spacing: tree.crownWidth * 0.02) {
                        ForEach(0..<tree.clusterCount, id: \.self) { index in
                            ZStack {
                                UnevenRoundedEllipseShape(
                                    topInset: 0.12 + (Double(index % 2) * 0.05),
                                    sideInset: 0.08 + (Double((index + 1) % 2) * 0.06)
                                )
                                    .fill(tree.color.opacity(tree.opacity * (0.98 - (Double(index) * 0.03))))
                                    .frame(
                                        width: tree.crownWidth * (0.62 + (Double(index % 3) * 0.10)),
                                        height: tree.crownHeight * (0.76 + (Double((index + 1) % 3) * 0.07))
                                    )

                                // Break up the canopy so the treeline reads less like flat circles.
                                ForEach(0..<4, id: \.self) { textureIndex in
                                    UnevenRoundedEllipseShape(
                                        topInset: 0.20 + (Double(textureIndex) * 0.03),
                                        sideInset: 0.16 + (Double(textureIndex) * 0.02)
                                    )
                                        .fill(tree.highlight.opacity(tree.opacity * 0.34))
                                        .frame(
                                            width: tree.crownWidth * (0.14 + (Double(textureIndex) * 0.035)),
                                            height: tree.crownHeight * (0.12 + (Double(textureIndex) * 0.025))
                                        )
                                        .offset(
                                            x: tree.crownWidth * [-0.18, -0.02, 0.14, 0.24][textureIndex],
                                            y: tree.crownHeight * [-0.08, -0.18, -0.04, -0.14][textureIndex]
                                        )
                                }
                            }
                            .offset(
                                x: CGFloat(index) * tree.crownWidth * 0.02,
                                y: CGFloat(index.isMultiple(of: 2) ? -tree.crownHeight * 0.05 : tree.crownHeight * 0.01)
                            )
                        }
                    }

                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(Color(red: 0.26, green: 0.22, blue: 0.15).opacity(tree.opacity * 0.78))
                        .frame(width: tree.trunkWidth, height: tree.trunkHeight)
                }
                .position(tree.position)
            }
        }
        .mask {
            ZStack {
                Rectangle()
                    .frame(width: size.width * 0.35)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Rectangle()
                    .frame(width: size.width * 0.35)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func treeSilhouettes(for size: CGSize) -> [FieldTreeNode] {
        let values: [(Double, Double, Double)] = [
            (0.04, 0.455, 1.65),
            (0.11, 0.425, 2.35),
            (0.17, 0.448, 1.58),
            (0.27, 0.438, 1.82),
            (0.73, 0.444, 1.72),
            (0.81, 0.430, 1.98),
            (0.88, 0.418, 2.42),
            (0.94, 0.438, 1.92),
            (0.985, 0.452, 1.62)
        ]

        return values.map { x, y, scale in
            FieldTreeNode(
                position: CGPoint(x: size.width * x, y: size.height * y),
                crownWidth: (compact ? 22 : 38) * scale,
                crownHeight: (compact ? 26 : 52) * scale,
                trunkWidth: (compact ? 2.8 : 5.4) * scale,
                trunkHeight: (compact ? 10 : 20) * scale,
                color: Color(red: 0.26, green: 0.38, blue: 0.14),
                highlight: Color(red: 0.36, green: 0.50, blue: 0.20),
                opacity: 1.0,
                clusterCount: scale > 2.3 ? 4 : 2
            )
        }
    }

    private func grassBaseColor(for blade: JourneyGrassBlade) -> Color {
        let dry = Color(red: 0.50, green: 0.50, blue: 0.21)
        let green = Color(red: 0.38, green: 0.48, blue: 0.17)
        return blade.tintMix > 0.65 ? dry : green
    }

    private func grassHighlightColor(for blade: JourneyGrassBlade) -> Color {
        let dry = Color(red: 0.76, green: 0.73, blue: 0.42)
        let green = Color(red: 0.66, green: 0.72, blue: 0.33)
        return blade.tintMix > 0.65 ? dry : green
    }
}

private struct JourneyGrassBlade: Identifiable {
    let id = UUID()
    let position: CGPoint
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
    let opacity: Double
    let sway: Double
    let offset: Double
    let animates: Bool
    let tintMix: Double
}

private struct FieldPatch: Identifiable {
    let id = UUID()
    let position: CGPoint
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
    let color: Color
    let opacity: Double
}

private struct FieldTreeNode: Identifiable {
    let id = UUID()
    let position: CGPoint
    let crownWidth: CGFloat
    let crownHeight: CGFloat
    let trunkWidth: CGFloat
    let trunkHeight: CGFloat
    let color: Color
    let highlight: Color
    let opacity: Double
    let clusterCount: Int
}

private struct UnevenRoundedEllipseShape: Shape {
    let topInset: Double
    let sideInset: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let left = rect.minX + rect.width * sideInset
        let right = rect.maxX - rect.width * sideInset
        let top = rect.minY + rect.height * topInset
        let bottom = rect.maxY

        path.move(to: CGPoint(x: left, y: bottom))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: top),
            control1: CGPoint(x: left - rect.width * 0.08, y: rect.minY + rect.height * 0.52),
            control2: CGPoint(x: rect.minX + rect.width * 0.26, y: rect.minY)
        )
        path.addCurve(
            to: CGPoint(x: right, y: bottom),
            control1: CGPoint(x: rect.maxX - rect.width * 0.26, y: rect.minY),
            control2: CGPoint(x: right + rect.width * 0.08, y: rect.minY + rect.height * 0.58)
        )
        path.closeSubpath()
        return path
    }
}

struct PathSkyScene {
    let skyTop: Color
    let skyMiddle: Color
    let skyBottom: Color
    let glowColor: Color
    let celestialBody: Color
    let celestialGlow: Color
    let cloudColor: Color
    let celestialX: Double
    let celestialY: Double
    let isNight: Bool
}

final class PathDaylightModel: NSObject, ObservableObject {
    @Published private var coordinate: PathCoordinate?

#if canImport(CoreLocation)
    private let manager = CLLocationManager()
#endif

    override init() {
        super.init()
#if canImport(CoreLocation)
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyThreeKilometers
#endif
    }

    func activate() {
#if canImport(CoreLocation)
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
#endif
    }

    @MainActor
    func sceneState(for date: Date) -> PathSkyScene {
        let solar = SolarCalculator.events(for: coordinate, on: date)
        return SolarCalculator.scene(for: date, events: solar)
    }
}

#if canImport(CoreLocation)
extension PathDaylightModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.coordinate = PathCoordinate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                timeZone: .current
            )
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {}
}
#endif

struct PathCoordinate {
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone
}

enum SolarCalculator {
    static func events(for coordinate: PathCoordinate?, on date: Date) -> SolarEvents {
        guard let coordinate else {
            return fallbackEvents(on: date, timeZone: .current)
        }
        return calculateEvents(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            date: date,
            timeZone: coordinate.timeZone
        ) ?? fallbackEvents(on: date, timeZone: coordinate.timeZone)
    }

    static func scene(for date: Date, events: SolarEvents) -> PathSkyScene {
        let sunrise = events.sunrise
        let sunset = events.sunset
        let dawn = sunrise.addingTimeInterval(-45 * 60)
        let dusk = sunset.addingTimeInterval(45 * 60)

        let progress: Double
        if date < dawn || date > dusk {
            return PathSkyScene(
                skyTop: Color(red: 0.05, green: 0.10, blue: 0.21),
                skyMiddle: Color(red: 0.11, green: 0.17, blue: 0.30),
                skyBottom: Color(red: 0.20, green: 0.28, blue: 0.38),
                glowColor: Color(red: 0.83, green: 0.88, blue: 0.97),
                celestialBody: Color(red: 0.95, green: 0.96, blue: 1.0),
                celestialGlow: Color(red: 0.75, green: 0.82, blue: 0.98),
                cloudColor: Color(red: 0.66, green: 0.72, blue: 0.82),
                celestialX: 0.76,
                celestialY: 0.16,
                isNight: true
            )
        } else if date < sunrise {
            progress = max(0, min(1, date.timeIntervalSince(dawn) / sunrise.timeIntervalSince(dawn)))
            return twilightScene(progress: progress, sunrise: true)
        } else if date > sunset {
            progress = max(0, min(1, date.timeIntervalSince(sunset) / dusk.timeIntervalSince(sunset)))
            return twilightScene(progress: progress, sunrise: false)
        } else {
            let dayProgress = max(0, min(1, date.timeIntervalSince(sunrise) / sunset.timeIntervalSince(sunrise)))
            let arc = sin(dayProgress * .pi)
            return PathSkyScene(
                skyTop: Color(red: 0.41, green: 0.70, blue: 0.96),
                skyMiddle: Color(red: 0.68, green: 0.86, blue: 0.98),
                skyBottom: Color(red: 0.84, green: 0.93, blue: 0.98),
                glowColor: Color.white,
                celestialBody: Color(red: 1.0, green: 0.95, blue: 0.76),
                celestialGlow: Color(red: 1.0, green: 0.90, blue: 0.55),
                cloudColor: Color.white,
                celestialX: 0.14 + (dayProgress * 0.72),
                celestialY: 0.28 - (arc * 0.16),
                isNight: false
            )
        }
    }

    private static func twilightScene(progress: Double, sunrise: Bool) -> PathSkyScene {
        let x = sunrise ? 0.14 + (progress * 0.18) : 0.68 + (progress * 0.18)
        let y = 0.22 - (sin(progress * .pi) * 0.08)
        return PathSkyScene(
            skyTop: Color(red: 0.21, green: 0.30, blue: 0.46),
            skyMiddle: Color(red: 0.60, green: 0.54, blue: 0.62),
            skyBottom: Color(red: 0.96, green: 0.71, blue: 0.48),
            glowColor: Color(red: 1.0, green: 0.84, blue: 0.62),
            celestialBody: Color(red: 1.0, green: 0.86, blue: 0.58),
            celestialGlow: Color(red: 1.0, green: 0.72, blue: 0.36),
            cloudColor: Color.white.opacity(0.9),
            celestialX: x,
            celestialY: y,
            isNight: false
        )
    }

    private static func fallbackEvents(on date: Date, timeZone: TimeZone) -> SolarEvents {
        let calendar = Calendar(identifier: .gregorian)
        let localDate = date.addingTimeInterval(TimeInterval(timeZone.secondsFromGMT(for: date)))
        let start = calendar.startOfDay(for: localDate)
        let sunrise = start.addingTimeInterval(6.5 * 3600).addingTimeInterval(-TimeInterval(timeZone.secondsFromGMT(for: date)))
        let sunset = start.addingTimeInterval(19.5 * 3600).addingTimeInterval(-TimeInterval(timeZone.secondsFromGMT(for: date)))
        return SolarEvents(sunrise: sunrise, sunset: sunset)
    }

    private static func calculateEvents(latitude: Double, longitude: Double, date: Date, timeZone: TimeZone) -> SolarEvents? {
        let calendar = Calendar(identifier: .gregorian)
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let lngHour = longitude / 15

        func eventTime(isSunrise: Bool) -> Date? {
            let base = Double(dayOfYear) + ((isSunrise ? 6 : 18) - lngHour) / 24
            let anomaly = (0.9856 * base) - 3.289
            var trueLongitude = anomaly + (1.916 * sin(anomaly.degreesToRadians)) + (0.020 * sin((2 * anomaly).degreesToRadians)) + 282.634
            trueLongitude = trueLongitude.truncatingRemainder(dividingBy: 360)
            if trueLongitude < 0 { trueLongitude += 360 }

            var rightAscension = atan(0.91764 * tan(trueLongitude.degreesToRadians)).radiansToDegrees
            rightAscension = rightAscension.truncatingRemainder(dividingBy: 360)
            if rightAscension < 0 { rightAscension += 360 }

            let lQuadrant = floor(trueLongitude / 90) * 90
            let raQuadrant = floor(rightAscension / 90) * 90
            rightAscension += (lQuadrant - raQuadrant)
            rightAscension /= 15

            let sinDec = 0.39782 * sin(trueLongitude.degreesToRadians)
            let cosDec = cos(asin(sinDec))
            let cosH = (cos(90.833.degreesToRadians) - (sinDec * sin(latitude.degreesToRadians))) / (cosDec * cos(latitude.degreesToRadians))
            guard cosH >= -1, cosH <= 1 else { return nil }

            let hourAngle = isSunrise
                ? 360 - acos(cosH).radiansToDegrees
                : acos(cosH).radiansToDegrees
            let localHour = (hourAngle / 15) + rightAscension - (0.06571 * base) - 6.622
            var utcHour = localHour - lngHour
            utcHour.formTruncatingRemainder(dividingBy: 24)
            if utcHour < 0 { utcHour += 24 }

            let startOfDay = calendar.startOfDay(for: date)
            return startOfDay.addingTimeInterval((utcHour * 3600) - Double(timeZone.secondsFromGMT(for: date)))
        }

        guard let sunrise = eventTime(isSunrise: true),
              let sunset = eventTime(isSunrise: false) else {
            return nil
        }
        return SolarEvents(sunrise: sunrise, sunset: sunset)
    }
}

struct SolarEvents {
    let sunrise: Date
    let sunset: Date
}

private extension Double {
    var degreesToRadians: Double { self * .pi / 180 }
    var radiansToDegrees: Double { self * 180 / .pi }
}

private struct JourneyFlowerNode: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let color: Color
    let opacity: Double
    let sway: Double
}

private struct PerspectivePathShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.width * 0.40, y: rect.height))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.49, y: rect.height * 0.24),
            control1: CGPoint(x: rect.width * 0.42, y: rect.height * 0.72),
            control2: CGPoint(x: rect.width * 0.46, y: rect.height * 0.42)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.53, y: rect.height * 0.24))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.60, y: rect.height),
            control1: CGPoint(x: rect.width * 0.54, y: rect.height * 0.42),
            control2: CGPoint(x: rect.width * 0.58, y: rect.height * 0.72)
        )
        path.closeSubpath()
        return path
    }
}

private struct PerspectivePathTextureShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for index in 0..<5 {
            let offset = CGFloat(index) * rect.width * 0.014
            path.move(to: CGPoint(x: rect.width * 0.465 + offset, y: rect.height * 0.26))
            path.addCurve(
                to: CGPoint(x: rect.width * 0.43 + offset * 0.6, y: rect.height),
                control1: CGPoint(x: rect.width * 0.47 + offset, y: rect.height * 0.46),
                control2: CGPoint(x: rect.width * 0.45 + offset * 0.7, y: rect.height * 0.76)
            )
        }
        return path
    }
}

#Preview {
    NavigationStack {
        PathJourneyView()
    }
}
#endif
