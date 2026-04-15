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
    @Environment(\.dismiss) private var dismiss
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var daylightModel = PathDaylightModel()
    @State private var debugDayOverride: Double = -1

    private var isDebugActive: Bool { debugDayOverride >= 0 }

    private var snapshot: PracticeJourneySnapshot {
        let base = PracticeJourneySnapshot.make(from: sessionStore.sessions)
        if isDebugActive {
            return base.withSimulatedDays(Int(debugDayOverride))
        }
        return base
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColor.screenBackground
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Your journey")
                                .font(.system(size: 30, weight: .bold, design: .rounded))
                            Text(snapshot.summaryLine)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            PathJourneyArtwork(
                                snapshot: snapshot,
                                compact: false,
                                sceneResolver: { date in
                                    daylightModel.sceneState(for: date)
                                }
                            )
                            .frame(height: min(270, geometry.size.height * 0.37))

                            HStack(spacing: 10) {
                                journeyPill(title: "Revealed", value: snapshot.progressLabel, icon: "map.fill", accent: .green)
                                journeyPill(title: "Streak", value: snapshot.streakLabel, icon: "flame.fill", accent: .orange)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("What this means")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .textCase(.uppercase)
                                Text(snapshot.explanationLine)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(2)
                                Text(snapshot.consequenceLine)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text(snapshot.nextMilestoneLabel)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                        }
                        .padding(16)
                        .background(
                            Color.white,
                            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                                .stroke(Color.white.opacity(0.72), lineWidth: 1)
                        )

                        // MARK: - Debug day slider (developer only)
                        if AuthManager.shared.isDeveloper {
                            debugSliderCard
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Back")
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .accessibilityIdentifier("journey.screen")
        .task {
            daylightModel.activate()
        }
    }

    private var debugSliderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Debug: Simulate Days")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
                Spacer()
                if isDebugActive {
                    Button("Reset") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            debugDayOverride = -1
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                }
            }

            HStack(spacing: 12) {
                Text("Day \(isDebugActive ? Int(debugDayOverride) : snapshot.practicedDays)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: 80, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(snapshot.progressLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                    Text(String(format: "%.1f%% raw", snapshot.revealProgress * 100))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Slider(
                value: Binding(
                    get: { isDebugActive ? debugDayOverride : 0 },
                    set: { debugDayOverride = $0 }
                ),
                in: 0...21,
                step: 1
            )
            .tint(.orange)

            HStack {
                ForEach([0, 1, 3, 7, 14, 21], id: \.self) { day in
                    Button("\(day)") {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            debugDayOverride = Double(day)
                        }
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Int(debugDayOverride) == day ? .white : .orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Int(debugDayOverride) == day
                            ? AnyShapeStyle(Color.orange)
                            : AnyShapeStyle(Color.orange.opacity(0.12)),
                        in: Capsule()
                    )
                }
                Spacer()
            }
        }
        .padding(16)
        .background(
            Color.orange.opacity(0.06),
            in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }

    private func journeyPill(title: String, value: String, icon: String, accent: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(accent.opacity(0.82))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(accent.opacity(0.92))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.76), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

}

struct PracticeChallengeStatus {
    let title: String
    let summary: String
    let progress: Double
    let progressLabel: String
    let rewardLabel: String
}

struct PracticeAchievementStatus: Identifiable {
    let id: String
    let title: String
    let summary: String
    let progress: Double
    let progressLabel: String
    let isUnlocked: Bool
    let symbolName: String
}

struct RetentionLoopSnapshot {
    let activeChallenge: PracticeChallengeStatus
    let achievements: [PracticeAchievementStatus]
    let motivationLine: String
}

enum RetentionLoopEngine {
    static func snapshot(sessions: [PracticeSession], profile: CoachingProfile?) -> RetentionLoopSnapshot {
        let sortedSessions = sessions.sorted { $0.date > $1.date }
        let recentSessions = Array(sortedSessions.prefix(6))
        let currentStreak = currentStreak(from: sortedSessions)

        let activeChallenge = activeChallenge(
            sessions: recentSessions,
            allSessions: sortedSessions,
            profile: profile,
            currentStreak: currentStreak
        )

        let achievements = achievementStatuses(
            sessions: sortedSessions,
            currentStreak: currentStreak
        )

        let motivationLine: String
        if activeChallenge.progress >= 1 {
            motivationLine = "Challenge cleared. Keep the momentum alive."
        } else if currentStreak >= 3 {
            motivationLine = "You already have rhythm. One more rep strengthens it."
        } else {
            motivationLine = "Consistency is still the unlock."
        }

        return RetentionLoopSnapshot(
            activeChallenge: activeChallenge,
            achievements: achievements,
            motivationLine: motivationLine
        )
    }

    private static func activeChallenge(
        sessions: [PracticeSession],
        allSessions: [PracticeSession],
        profile: CoachingProfile?,
        currentStreak: Int
    ) -> PracticeChallengeStatus {
        if currentStreak < 2 {
            let progress = min(Double(currentStreak), 2) / 2
            return PracticeChallengeStatus(
                title: "Hold the streak",
                summary: "Come back tomorrow and keep the path open with one focused rep.",
                progress: progress,
                progressLabel: "\(currentStreak)/2 days",
                rewardLabel: "+80 XP"
            )
        }

        switch profile?.biggestChallenge {
        case .fillerWords:
            let qualifying = sessions.filter { $0.fillerWordCount <= 2 && $0.wordCount >= 14 }.count
            return PracticeChallengeStatus(
                title: "Clean delivery",
                summary: "Complete two recent reps with two fillers or fewer.",
                progress: min(Double(qualifying), 2) / 2,
                progressLabel: "\(qualifying)/2 clean reps",
                rewardLabel: "+120 XP"
            )
        case .rambling:
            let qualifying = sessions.filter {
                ($0.score ?? 0) >= 7 && $0.duration >= 20 && $0.wordCount >= 18
            }.count
            return PracticeChallengeStatus(
                title: "Land the point",
                summary: "Finish two strong reps that stay structured instead of drifting.",
                progress: min(Double(qualifying), 2) / 2,
                progressLabel: "\(qualifying)/2 structured reps",
                rewardLabel: "+120 XP"
            )
        case .freezing:
            let qualifying = sessions.filter {
                ($0.score ?? 0) >= 6 && ($0.mode == .suddenDeath || $0.mode == .timed || $0.mode == .imConversation)
            }.count
            return PracticeChallengeStatus(
                title: "Fast response reps",
                summary: "Hit two quick-answer sessions without freezing or collapsing the reply.",
                progress: min(Double(qualifying), 2) / 2,
                progressLabel: "\(qualifying)/2 pressure reps",
                rewardLabel: "+120 XP"
            )
        case .rushing:
            let qualifying = sessions.filter {
                ($0.score ?? 0) >= 7 && (105...145).contains($0.wordsPerMinute)
            }.count
            return PracticeChallengeStatus(
                title: "Controlled pace",
                summary: "Finish two solid reps in the calmer pacing zone.",
                progress: min(Double(qualifying), 2) / 2,
                progressLabel: "\(qualifying)/2 controlled reps",
                rewardLabel: "+120 XP"
            )
        case .none:
            let qualifying = allSessions.filter { ($0.score ?? 0) >= 7 }.prefix(3).count
            return PracticeChallengeStatus(
                title: "Sharp sessions",
                summary: "Build three solid sessions to set your baseline.",
                progress: min(Double(qualifying), 3) / 3,
                progressLabel: "\(qualifying)/3 strong sessions",
                rewardLabel: "+140 XP"
            )
        }
    }

    private static func achievementStatuses(
        sessions: [PracticeSession],
        currentStreak: Int
    ) -> [PracticeAchievementStatus] {
        let imSessions = sessions.filter { $0.mode == .imConversation }.count
        let highScoreCount = sessions.filter { ($0.score ?? 0) >= 8 }.count
        let zeroFillerCount = sessions.filter { $0.fillerWordCount == 0 && $0.wordCount >= 12 }.count

        return [
            PracticeAchievementStatus(
                id: "first_rep",
                title: "First Rep",
                summary: "You started the path.",
                progress: min(Double(sessions.count), 1),
                progressLabel: sessions.isEmpty ? "0/1" : "Unlocked",
                isUnlocked: !sessions.isEmpty,
                symbolName: "flag.fill"
            ),
            PracticeAchievementStatus(
                id: "streak_three",
                title: "Rhythm Builder",
                summary: "Practice three days in a row.",
                progress: min(Double(currentStreak), 3) / 3,
                progressLabel: currentStreak >= 3 ? "Unlocked" : "\(currentStreak)/3 days",
                isUnlocked: currentStreak >= 3,
                symbolName: "flame.fill"
            ),
            PracticeAchievementStatus(
                id: "sharp_score",
                title: "Sharp Session",
                summary: "Land a session scored 8 or higher.",
                progress: min(Double(highScoreCount), 1),
                progressLabel: highScoreCount >= 1 ? "Unlocked" : "0/1",
                isUnlocked: highScoreCount >= 1,
                symbolName: "sparkles"
            ),
            PracticeAchievementStatus(
                id: "clean_run",
                title: "Clean Run",
                summary: "Finish a meaningful session without filler words.",
                progress: min(Double(zeroFillerCount), 1),
                progressLabel: zeroFillerCount >= 1 ? "Unlocked" : "0/1",
                isUnlocked: zeroFillerCount >= 1,
                symbolName: "checkmark.seal.fill"
            ),
            PracticeAchievementStatus(
                id: "im_connector",
                title: "Connection Builder",
                summary: "Complete three IM sessions.",
                progress: min(Double(imSessions), 3) / 3,
                progressLabel: imSessions >= 3 ? "Unlocked" : "\(imSessions)/3 chats",
                isUnlocked: imSessions >= 3,
                symbolName: "bubble.left.and.bubble.right.fill"
            )
        ]
        .sorted { lhs, rhs in
            if lhs.isUnlocked == rhs.isUnlocked {
                return lhs.progress > rhs.progress
            }
            return !lhs.isUnlocked && rhs.isUnlocked
        }
    }

    private static func currentStreak(from sessions: [PracticeSession]) -> Int {
        PracticeSession.calculateStreak(from: sessions)
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

    /// Returns a copy with `revealProgress` and labels overridden to simulate a specific day count.
    func withSimulatedDays(_ days: Int) -> PracticeJourneySnapshot {
        let windowDays = 21
        let clamped = max(0, min(windowDays, days))
        let progress = Double(clamped) / Double(windowDays)
        let pct = Int(progress * 100)
        return PracticeJourneySnapshot(
            practicedDays: clamped,
            streak: clamped,
            revealProgress: progress,
            quality: quality,
            progressLabel: "\(pct)% revealed",
            previewLine: previewLine,
            summaryLine: summaryLine,
            explanationLine: explanationLine,
            nextMilestoneLabel: nextMilestoneLabel,
            consequenceLine: consequenceLine,
            homeGoalLine: homeGoalLine,
            homeGoalShortLabel: homeGoalShortLabel
        )
    }

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

        // Reveal progress: purely linear — each practiced day reveals 1/21 of the path.
        let revealProgress = min(1.0, Double(practicedDays) / Double(windowDays))

        let progressPercent = Int(revealProgress * 100)
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
        PracticeSession.calculateStreak(from: sessions)
    }
}

struct PathJourneyArtwork: View {
    let snapshot: PracticeJourneySnapshot
    let compact: Bool
    let sceneResolver: (Date) -> PathSkyScene

    @State private var scene: PathSkyScene?

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let currentScene = scene ?? sceneResolver(Date())

            ZStack {
                RoundedRectangle(cornerRadius: compact ? 24 : 30, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                currentScene.skyTop,
                                currentScene.skyMiddle,
                                currentScene.skyBottom
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                skyGlow(size: size, scene: currentScene)
                celestialBody(size: size, scene: currentScene)
                cloudHaze(size: size, scene: currentScene)
                if currentScene.isNight {
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
                flowerDots(size: size)

                ForEach(grassBlades(for: size)) { blade in
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    grassBaseColor(for: blade).opacity(blade.opacity * 0.82),
                                    grassHighlightColor(for: blade).opacity(blade.opacity * 0.62)
                                ],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(width: blade.width, height: blade.height)
                        .rotationEffect(.degrees(blade.rotation))
                        .position(blade.position)
                }

                ZStack {
                    // Only render path elements when there is actual progress.
                    if snapshot.revealProgress > 0 {
                        // Solid dirt base — the core of the walked trail.
                        PerspectivePathShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.56, green: 0.46, blue: 0.32),
                                        Color(red: 0.62, green: 0.52, blue: 0.36),
                                        Color(red: 0.68, green: 0.60, blue: 0.44)
                                    ],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .mask(alignment: .bottom) {
                                revealMask(for: size)
                            }

                        // Lighter highlight on one side to give the dirt some dimension.
                        PerspectivePathShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.76, green: 0.68, blue: 0.52).opacity(0.28),
                                        Color.clear
                                    ],
                                    startPoint: .trailing,
                                    endPoint: .leading
                                )
                            )
                            .mask(alignment: .bottom) {
                                revealMask(for: size)
                            }

                        // Soft edge along the trail borders.
                        PerspectivePathShape()
                            .stroke(
                                Color(red: 0.48, green: 0.54, blue: 0.26).opacity(0.35),
                                lineWidth: compact ? 3 : 5
                            )
                            .mask(alignment: .bottom) {
                                revealMask(for: size)
                            }

                        // Dense overgrowth keeps the unrevealed section fully hidden.
                        PerspectivePathShape()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.60, green: 0.65, blue: 0.30),
                                        Color(red: 0.42, green: 0.52, blue: 0.18),
                                        Color(red: 0.28, green: 0.38, blue: 0.12)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .mask(alignment: .bottom) {
                                VStack(spacing: 0) {
                                    Spacer(minLength: 0)
                                    Rectangle()
                                        .frame(height: hiddenDepth(for: size))
                                    Rectangle()
                                        .frame(height: revealedDepth(for: size))
                                        .hidden()
                                }
                            }

                    }

                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.78, green: 0.79, blue: 0.47).opacity(0.05),
                                    Color(red: 0.58, green: 0.65, blue: 0.28).opacity(0.14),
                                    Color(red: 0.40, green: 0.49, blue: 0.16).opacity(0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .blendMode(.softLight)
                }
                .mask(alignment: .bottom) {
                    Rectangle()
                        .frame(height: size.height * 0.46)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }

                distantTrees(size: size)

                // Goal marker rendered outside the field mask so the flag
                // pole and banner are never clipped by the ground region.
                if snapshot.revealProgress > 0 {
                    goalMarker(size: size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: compact ? 24 : 30, style: .continuous))
        }
        .task {
            scene = sceneResolver(Date())
        }
    }

    @ViewBuilder
    private func revealMask(for size: CGSize) -> some View {
        let depth = revealedDepth(for: size)
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            // Rounded top edge gives the reveal a natural feel instead of a hard line.
            Ellipse()
                .frame(width: size.width * 0.6, height: compact ? 18 : 28)
                .frame(maxWidth: .infinity)
            Rectangle()
                .frame(height: max(0, depth - (compact ? 9 : 14)))
        }
    }

    @ViewBuilder
    private func goalMarker(size: CGSize) -> some View {
        let field = fieldMetrics(for: size)
        let pathTopY = field.top
        let centerX = size.width * 0.515
        let poleHeight: CGFloat = compact ? 44 : 64
        let poleWidth: CGFloat = compact ? 3.0 : 4.0
        let flagWidth: CGFloat = compact ? 20 : 28
        let flagHeight: CGFloat = compact ? 14 : 20
        let isComplete = snapshot.revealProgress >= 1.0
        let flagY = pathTopY + (compact ? 2 : 3)
        let poleTopY = flagY - poleHeight

        ZStack {
            // Soft glow behind the flag
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            (isComplete
                                ? Color(red: 0.40, green: 0.85, blue: 0.50)
                                : Color(red: 1.0, green: 0.88, blue: 0.44)
                            ).opacity(0.45),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: compact ? 22 : 32
                    )
                )
                .frame(width: compact ? 46 : 64, height: compact ? 46 : 64)
                .position(x: centerX + flagWidth * 0.35, y: poleTopY + flagHeight * 0.55)

            // Pole
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.30, green: 0.24, blue: 0.16),
                            Color(red: 0.20, green: 0.16, blue: 0.10)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: poleWidth, height: poleHeight)
                .position(x: centerX, y: flagY - poleHeight * 0.5)

            // Pennant flag — a triangular banner hanging from the pole top
            FlagPennantShape()
                .fill(
                    LinearGradient(
                        colors: isComplete
                            ? [
                                Color(red: 0.18, green: 0.72, blue: 0.40),
                                Color(red: 0.36, green: 0.86, blue: 0.52)
                            ]
                            : [
                                Color(red: 0.92, green: 0.30, blue: 0.16),
                                Color(red: 0.98, green: 0.46, blue: 0.22)
                            ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    FlagPennantShape()
                        .stroke(Color.white.opacity(0.60), lineWidth: compact ? 0.8 : 1.2)
                }
                .frame(width: flagWidth, height: flagHeight)
                .shadow(color: .black.opacity(0.14), radius: 1.5, y: 1)
                .position(x: centerX + (flagWidth * 0.5) + (poleWidth * 0.5),
                          y: poleTopY + flagHeight * 0.5 + (compact ? 1 : 2))

            // Pole cap — small ball on top
            Circle()
                .fill(Color(red: 0.36, green: 0.30, blue: 0.20))
                .frame(width: compact ? 5 : 7, height: compact ? 5 : 7)
                .position(x: centerX, y: poleTopY)

            // Ground base
            Ellipse()
                .fill(Color(red: 0.52, green: 0.42, blue: 0.28).opacity(0.70))
                .frame(width: compact ? 10 : 14, height: compact ? 4 : 6)
                .position(x: centerX, y: flagY + (compact ? 1 : 2))
        }
        .opacity(snapshot.revealProgress > 0.05 ? 1 : 0.35)
    }

    private func revealedDepth(for size: CGSize) -> CGFloat {
        guard snapshot.revealProgress > 0 else { return 0 }
        // The field occupies the bottom 46% of the artwork. At 100% the full field is revealed.
        let fieldHeight = fieldMetrics(for: size).height
        return fieldHeight * snapshot.revealProgress
    }

    private func hiddenDepth(for size: CGSize) -> CGFloat {
        let metrics = fieldMetrics(for: size)
        return max(0, metrics.height - revealedDepth(for: size))
    }

    private func fieldMetrics(for size: CGSize) -> (top: CGFloat, height: CGFloat) {
        let height = size.height * 0.46
        return (top: size.height - height, height: height)
    }

    private func grassBlades(for size: CGSize) -> [JourneyGrassBlade] {
        let progress = snapshot.revealProgress
        let rowCount = compact ? 6 : 8
        let bladesPerRow = compact ? 14 : 20
        let field = fieldMetrics(for: size)
        let revealLine = progress > 0 ? Double((field.top + hiddenDepth(for: size)) / size.height) : 2.0

        return (0..<rowCount).flatMap { row in
            (0..<bladesPerRow).compactMap { column in
                let depth = Double(row) / Double(max(1, rowCount - 1))
                let y = 0.55 + depth * 0.39
                let x = (Double(column) + 0.5) / Double(bladesPerRow)
                let hw = pathHalfWidth(at: y, compact: compact)
                // The S-curve shifts the path center, so offset the clearing center
                // to match. The curve shifts left in the lower half and right upper.
                let curveShift = (1.0 - depth) * 0.015 - depth * 0.01
                let distanceFromCenter = abs(x - (0.5 + curveShift))

                // Very generous clearing corridor to prevent any visual overlap.
                let insidePath = distanceFromCenter < hw * 1.6
                let inRevealedZone = y > revealLine

                // Remove grass inside the path where it has been revealed.
                if insidePath && progress > 0 && inRevealedZone {
                    return nil
                }

                let clumpWave = (sin((x * 18) + (depth * 6.5)) + cos((x * 29) - (depth * 8.0))) * 0.5
                let clumpStrength = 0.72 + (max(0, clumpWave) * 0.55)
                let shouldSkipForPatchiness = clumpWave < -0.38 && !insidePath

                if shouldSkipForPatchiness {
                    return nil
                }

                let noise = sin((Double(column) * 1.17) + (Double(row) * 0.73))
                let perspectiveScale = 0.28 + pow(depth, 1.9) * 1.75

                // Field grass stays full height at all times. Grass covering the
                // unrevealed part of the path grows extra tall to hide the dirt beneath.
                let baseHeight = (compact ? 18.0 : 26.0) * clumpStrength
                let pathOvergrowth: Double
                if insidePath && !inRevealedZone {
                    pathOvergrowth = compact ? 20.0 : 30.0
                } else {
                    pathOvergrowth = 0
                }

                // Edge overgrowth — grass near the left/right edges grows
                // taller, especially early in the journey when progress is low.
                let edgeness = max(0, (abs(x - 0.5) - 0.25) / 0.25) // 0 at center, 1 at edge
                let wildness = 1.0 - min(1.0, progress * 1.5) // 1 at 0%, fades by ~67%
                let edgeOvergrowth = edgeness * wildness * (compact ? 16.0 : 24.0)

                let width = (compact ? 1.6 : 2.0) + (perspectiveScale * (compact ? 1.0 : 1.4))
                    + (edgeness * wildness * (compact ? 0.6 : 1.0))
                let height = (baseHeight + pathOvergrowth + edgeOvergrowth) * perspectiveScale * 0.88
                let animates = false
                let dryness = 0.35 + max(0, (0.5 - clumpWave)) * 0.7

                return JourneyGrassBlade(
                    position: CGPoint(
                        x: size.width * x,
                        y: size.height * y
                    ),
                    width: width,
                    height: height + abs(noise * (compact ? 3.0 : 4.5)),
                    rotation: (-16 + (noise * 18)),
                    opacity: 0.18 + (depth * 0.28),
                    sway: (compact ? 2.2 : 3.0) + (depth * 3.2),
                    offset: (compact ? 0.6 : 1.0) + (depth * 2.2),
                    animates: animates,
                    tintMix: dryness
                )
            }
        }
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
        EmptyView()
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
    private func flowerDots(size: CGSize) -> some View {
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
            .position(flower.position)
            .opacity(flower.opacity)
        }
    }

    private func flowerNodes(for size: CGSize) -> [JourneyFlowerNode] {
        let progress = snapshot.revealProgress
        let streakBoost = min(8, max(0, snapshot.streak))
        let yellow = Color(red: 0.98, green: 0.88, blue: 0.32)
        let softYellow = Color(red: 0.96, green: 0.92, blue: 0.50)

        // Flowers stay light at low progress, then thicken as reveal progress and streak both rise.
        let allFlowers: [(Double, Double, Color, Double)] = [
            (0.14, 0.68, Color.white, 0.50),
            (0.86, 0.74, yellow, 0.48),
            (0.78, 0.64, Color.white, 0.46),
            (0.22, 0.80, softYellow, 0.44),
            (0.90, 0.86, Color.white, 0.44),
            (0.10, 0.88, yellow, 0.42),
            (0.68, 0.70, softYellow, 0.40),
            (0.30, 0.66, Color.white, 0.42),
            (0.82, 0.82, yellow, 0.40),
            (0.18, 0.76, softYellow, 0.40),
            (0.72, 0.90, Color.white, 0.38),
            (0.08, 0.72, yellow, 0.38),
            (0.24, 0.71, Color.white, 0.42),
            (0.76, 0.78, softYellow, 0.40),
            (0.58, 0.86, Color.white, 0.38),
            (0.40, 0.83, yellow, 0.40),
            (0.12, 0.81, softYellow, 0.38),
            (0.88, 0.69, Color.white, 0.38),
            (0.63, 0.75, yellow, 0.36),
            (0.36, 0.91, Color.white, 0.36),
        ]

        let minCount = 2
        let maxCount = allFlowers.count
        let progressCount = minCount + Int(progress * Double(maxCount - minCount - streakBoost))
        let visibleCount = progressCount + streakBoost
        let clamped = min(maxCount, visibleCount)

        return allFlowers.prefix(clamped).map { x, y, color, opacity in
            JourneyFlowerNode(
                position: CGPoint(x: size.width * x, y: size.height * y),
                size: compact ? 5 : 7,
                color: color,
                opacity: opacity,
                sway: compact ? 4 : 6
            )
        }
    }

    private func pathHalfWidth(at normalizedY: Double, compact: Bool) -> Double {
        let t = max(0, min(1, normalizedY))
        let base = compact ? 0.22 : 0.25
        let horizon = compact ? 0.018 : 0.026
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
        let rows = compact ? 3 : 4
        let columns = compact ? 4 : 5
        var patches: [FieldPatch] = []

        for row in 0..<rows {
            for column in 0..<columns {
                let depth = Double(row) / Double(max(1, rows - 1))
                let x = (Double(column) + 0.45) / Double(columns)
                let y = 0.58 + depth * 0.32
                let noise = sin((Double(column) * 1.9) + (Double(row) * 1.3))
                let width = (compact ? 20.0 : 28.0) + (depth * (compact ? 14.0 : 24.0))
                let height = (compact ? 8.0 : 12.0) + (depth * (compact ? 8.0 : 14.0))
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
                        opacity: 0.05 + (depth * 0.05)
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
                let frameH = tree.crownHeight + tree.trunkHeight
                ZStack(alignment: .bottom) {
                    // Brown trunk
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    tree.trunkColor,
                                    tree.trunkColor.opacity(0.80)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: tree.trunkWidth, height: tree.trunkHeight)

                    canopyView(for: tree)
                    .frame(width: tree.crownWidth, height: tree.crownHeight)
                    .offset(y: -tree.trunkHeight + tree.crownHeight * 0.12)
                }
                .frame(width: tree.crownWidth, height: frameH)
                .position(tree.position)
            }
        }
    }

    private func canopyGradient(for tree: FieldTreeNode) -> LinearGradient {
        LinearGradient(
            colors: [tree.highlight, tree.color, tree.color.opacity(0.90)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func canopyHighlight(for tree: FieldTreeNode) -> LinearGradient {
        LinearGradient(
            colors: [tree.highlight.opacity(0.28), Color.clear],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func canopyView(for tree: FieldTreeNode) -> some View {
        switch tree.variety {
        case .round:
            TreeCanopyShape()
                .fill(canopyGradient(for: tree))
                .overlay {
                    TreeCanopyShape()
                        .fill(canopyHighlight(for: tree))
                }
        case .pointed:
            PointedCanopyShape()
                .fill(canopyGradient(for: tree))
                .overlay {
                    PointedCanopyShape()
                        .fill(canopyHighlight(for: tree))
                }
        case .layered:
            LayeredCanopyShape()
                .fill(canopyGradient(for: tree))
                .overlay {
                    LayeredCanopyShape()
                        .fill(canopyHighlight(for: tree))
                }
        }
    }

    private func treeSilhouettes(for size: CGSize) -> [FieldTreeNode] {
        let field = fieldMetrics(for: size)

        // (x, scale, depthInField, variety) — depthInField 0 = horizon, >0 = further into field.
        // Scale range is tight so the line stays cohesive while still feeling organic.
        // Deeper trees sit closer to the path, creating a corridor/depth effect.
        let values: [(Double, Double, Double, TreeVariety)] = [
            // Horizon row — the main tree-line
            (0.04,  1.00, 0, .pointed),
            (0.10,  1.10, 0, .round),
            (0.17,  0.95, 0, .layered),
            (0.23,  1.05, 0, .round),
            (0.77,  1.00, 0, .layered),
            (0.82,  1.08, 0, .pointed),
            (0.89,  1.10, 0, .round),
            (0.95,  1.02, 0, .layered),
            (0.985, 0.92, 0, .pointed),
            // Mid-field trees — closer to the path for depth
            (0.28, 0.95, 0.18, .layered),
            (0.72, 0.98, 0.18, .round),
            (0.15, 0.92, 0.28, .pointed),
            (0.85, 0.95, 0.28, .layered),
            // Deep field trees — even closer to path
            (0.34, 0.90, 0.42, .round),
            (0.66, 0.92, 0.42, .layered),
        ]

        return values.map { x, scale, depthInField, variety in
            // Gentle perspective shrink — max 20% reduction at deepest
            let perspectiveFactor = 1.0 - (depthInField * 0.20)
            let effectiveScale = scale * perspectiveFactor

            let crownW = (compact ? 24.0 : 40.0) * effectiveScale
            let crownH = (compact ? 26.0 : 48.0) * effectiveScale * 1.25
            let trunkW = (compact ? 3.0 : 5.0) * effectiveScale
            let trunkH = (compact ? 10.0 : 18.0) * effectiveScale * 1.25
            let totalH = crownH + trunkH

            let canopyHalfWidth = crownW * 0.55
            // Deeper trees have a narrower exclusion zone so they sit closer
            // to the path, giving a natural corridor perspective.
            let exclusionHalf = 0.13 - (depthInField * 0.07)
            let exclusionLeft = size.width * (0.5 - exclusionHalf)
            let exclusionRight = size.width * (0.5 + exclusionHalf)
            var positionX = size.width * x

            if positionX < size.width * 0.5 {
                positionX = min(positionX, exclusionLeft - canopyHalfWidth)
            } else {
                positionX = max(positionX, exclusionRight + canopyHalfWidth)
            }

            // Vertical position: horizon trees sit at field.top, deeper trees
            // move downward into the field.
            let baseY = field.top + (depthInField * field.height * 0.45)
            let centerY = baseY - (totalH * 0.5) + trunkH + (compact ? 4 : 6)

            // Slightly lighter/hazier green for trees further into the field
            let haze = depthInField * 0.10
            let treeColor = Color(
                red: 0.20 + haze, green: 0.34 + haze * 0.4, blue: 0.12 + haze * 0.3
            )
            let treeHighlight = Color(
                red: 0.30 + haze, green: 0.46 + haze * 0.3, blue: 0.18 + haze * 0.2
            )

            return FieldTreeNode(
                position: CGPoint(x: positionX, y: centerY),
                crownWidth: crownW,
                crownHeight: crownH,
                trunkWidth: trunkW,
                trunkHeight: trunkH,
                color: treeColor,
                highlight: treeHighlight,
                trunkColor: Color(red: 0.40, green: 0.28, blue: 0.16),
                opacity: 1.0,
                variety: variety
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

private enum TreeVariety {
    case round
    case pointed
    case layered
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
    let trunkColor: Color
    let opacity: Double
    let variety: TreeVariety
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
    @Published private var coordinate: PathCoordinate? = .approximateCurrent
    @Published private var source: PathCoordinateSource = .fallback

#if canImport(CoreLocation)
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
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

    @MainActor
    fileprivate func debugSnapshot(for date: Date) -> PathSkyDebugSnapshot {
        let activeCoordinate = coordinate ?? .approximateCurrent
        let solar = SolarCalculator.events(for: coordinate, on: date)
        let scene = SolarCalculator.scene(for: date, events: solar)
        let formatter = DateFormatter()
        formatter.timeZone = activeCoordinate.timeZone
        formatter.dateFormat = "HH:mm"

        return PathSkyDebugSnapshot(
            source: source.label,
            timeZoneID: activeCoordinate.timeZone.identifier,
            coordinateLabel: String(format: "%.4f, %.4f", activeCoordinate.latitude, activeCoordinate.longitude),
            nowLabel: formatter.string(from: date),
            sunriseLabel: formatter.string(from: solar.sunrise),
            sunsetLabel: formatter.string(from: solar.sunset),
            modeLabel: scene.isNight ? "NIGHT" : "DAY"
        )
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
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            let resolvedTimeZone = placemarks?.first?.timeZone
            let resolvedCoordinate: PathCoordinate
            let resolvedSource: PathCoordinateSource
            let currentTimeZone = TimeZone.autoupdatingCurrent

            if let resolvedTimeZone,
               resolvedTimeZone.identifier == currentTimeZone.identifier {
                resolvedCoordinate = PathCoordinate(
                    latitude: location.coordinate.latitude,
                    longitude: location.coordinate.longitude,
                    timeZone: resolvedTimeZone
                )
                resolvedSource = .resolvedLocation
            } else {
                // Keep the sky aligned with the user-visible local time if the
                // simulator/device location is stale or points at a different region.
                resolvedCoordinate = PathCoordinate.approximate(for: currentTimeZone)
                resolvedSource = .fallback
            }

            Task { @MainActor in
                self.coordinate = resolvedCoordinate
                self.source = resolvedSource
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in
            self.coordinate = .approximateCurrent
            self.source = .fallback
        }
    }
}
#endif

fileprivate enum PathCoordinateSource {
    case fallback
    case resolvedLocation

    var label: String {
        switch self {
        case .fallback:
            return "Fallback"
        case .resolvedLocation:
            return "Location"
        }
    }
}

fileprivate struct PathSkyDebugSnapshot {
    let source: String
    let timeZoneID: String
    let coordinateLabel: String
    let nowLabel: String
    let sunriseLabel: String
    let sunsetLabel: String
    let modeLabel: String
}

struct PathCoordinate {
    let latitude: Double
    let longitude: Double
    let timeZone: TimeZone

    static var approximateCurrent: PathCoordinate {
        approximate(for: .autoupdatingCurrent)
    }

    static func approximate(for timeZone: TimeZone) -> PathCoordinate {
        switch timeZone.identifier {
        case "Europe/London":
            return PathCoordinate(latitude: 51.5074, longitude: -0.1278, timeZone: timeZone)
        case "Europe/Dublin":
            return PathCoordinate(latitude: 53.3498, longitude: -6.2603, timeZone: timeZone)
        case "Europe/Paris":
            return PathCoordinate(latitude: 48.8566, longitude: 2.3522, timeZone: timeZone)
        case "Europe/Berlin":
            return PathCoordinate(latitude: 52.5200, longitude: 13.4050, timeZone: timeZone)
        case "Europe/Madrid":
            return PathCoordinate(latitude: 40.4168, longitude: -3.7038, timeZone: timeZone)
        case "Europe/Rome":
            return PathCoordinate(latitude: 41.9028, longitude: 12.4964, timeZone: timeZone)
        case "America/New_York":
            return PathCoordinate(latitude: 40.7128, longitude: -74.0060, timeZone: timeZone)
        case "America/Chicago":
            return PathCoordinate(latitude: 41.8781, longitude: -87.6298, timeZone: timeZone)
        case "America/Denver":
            return PathCoordinate(latitude: 39.7392, longitude: -104.9903, timeZone: timeZone)
        case "America/Los_Angeles":
            return PathCoordinate(latitude: 34.0522, longitude: -118.2437, timeZone: timeZone)
        case "America/Phoenix":
            return PathCoordinate(latitude: 33.4484, longitude: -112.0740, timeZone: timeZone)
        case "America/Toronto":
            return PathCoordinate(latitude: 43.6532, longitude: -79.3832, timeZone: timeZone)
        case "Australia/Sydney":
            return PathCoordinate(latitude: -33.8688, longitude: 151.2093, timeZone: timeZone)
        default:
            return PathCoordinate(latitude: 51.5074, longitude: -0.1278, timeZone: timeZone)
        }
    }
}

enum SolarCalculator {
    static func events(for coordinate: PathCoordinate?, on date: Date) -> SolarEvents {
        let coordinate = coordinate ?? .approximateCurrent
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
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let sunrise = start.addingTimeInterval(6.5 * 3600)
        let sunset = start.addingTimeInterval(19.5 * 3600)
        return SolarEvents(sunrise: sunrise, sunset: sunset)
    }

    private static func calculateEvents(latitude: Double, longitude: Double, date: Date, timeZone: TimeZone) -> SolarEvents? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
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

            var utcCalendar = Calendar(identifier: .gregorian)
            utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
            let localComponents = calendar.dateComponents([.year, .month, .day], from: date)
            let utcMidnight = utcCalendar.date(from: localComponents)
            return utcMidnight?.addingTimeInterval(utcHour * 3600)
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
        // Gentle S-curve gives the trail a natural, wandering feel.
        path.move(to: CGPoint(x: rect.width * 0.36, y: rect.height))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.48, y: rect.height * 0.24),
            control1: CGPoint(x: rect.width * 0.38, y: rect.height * 0.74),
            control2: CGPoint(x: rect.width * 0.52, y: rect.height * 0.44)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.54, y: rect.height * 0.24))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.64, y: rect.height),
            control1: CGPoint(x: rect.width * 0.50, y: rect.height * 0.44),
            control2: CGPoint(x: rect.width * 0.62, y: rect.height * 0.74)
        )
        path.closeSubpath()
        return path
    }
}

/// A rounded tree canopy shape (no trunk).
private struct TreeCanopyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let top = rect.minY
        let bottom = rect.maxY
        let midY = top + (bottom - top) * 0.45

        path.move(to: CGPoint(x: midX, y: bottom))
        // Right side up
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: midY),
            control1: CGPoint(x: midX + rect.width * 0.35, y: bottom),
            control2: CGPoint(x: rect.maxX + rect.width * 0.05, y: midY + (bottom - top) * 0.32)
        )
        // Right side to top
        path.addCurve(
            to: CGPoint(x: midX, y: top),
            control1: CGPoint(x: rect.maxX - rect.width * 0.02, y: midY - (bottom - top) * 0.22),
            control2: CGPoint(x: midX + rect.width * 0.18, y: top - (bottom - top) * 0.02)
        )
        // Top to left side
        path.addCurve(
            to: CGPoint(x: rect.minX, y: midY),
            control1: CGPoint(x: midX - rect.width * 0.18, y: top - (bottom - top) * 0.02),
            control2: CGPoint(x: rect.minX + rect.width * 0.02, y: midY - (bottom - top) * 0.22)
        )
        // Left side down
        path.addCurve(
            to: CGPoint(x: midX, y: bottom),
            control1: CGPoint(x: rect.minX - rect.width * 0.05, y: midY + (bottom - top) * 0.32),
            control2: CGPoint(x: midX - rect.width * 0.35, y: bottom)
        )
        path.closeSubpath()
        return path
    }
}

private struct PointedCanopyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.width * 0.22, y: rect.height))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.10, y: rect.height * 0.56),
            control1: CGPoint(x: rect.width * 0.08, y: rect.height * 0.92),
            control2: CGPoint(x: rect.width * 0.02, y: rect.height * 0.76)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.50, y: rect.height * 0.02),
            control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.28),
            control2: CGPoint(x: rect.width * 0.34, y: rect.height * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.90, y: rect.height * 0.56),
            control1: CGPoint(x: rect.width * 0.66, y: rect.height * 0.06),
            control2: CGPoint(x: rect.width * 0.82, y: rect.height * 0.28)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.78, y: rect.height),
            control1: CGPoint(x: rect.width * 0.98, y: rect.height * 0.76),
            control2: CGPoint(x: rect.width * 0.92, y: rect.height * 0.92)
        )
        path.closeSubpath()
        return path
    }
}

/// A fuller canopy with a shallow central dip to break up the skyline.
private struct LayeredCanopyShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bottom = rect.maxY

        path.move(to: CGPoint(x: rect.width * 0.18, y: bottom))
        path.addCurve(
            to: CGPoint(x: rect.width * 0.08, y: rect.height * 0.48),
            control1: CGPoint(x: rect.width * 0.05, y: rect.height * 0.90),
            control2: CGPoint(x: rect.width * 0.00, y: rect.height * 0.68)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.30, y: rect.height * 0.14),
            control1: CGPoint(x: rect.width * 0.10, y: rect.height * 0.22),
            control2: CGPoint(x: rect.width * 0.18, y: rect.height * 0.06)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.50, y: rect.height * 0.22),
            control1: CGPoint(x: rect.width * 0.38, y: rect.height * 0.04),
            control2: CGPoint(x: rect.width * 0.44, y: rect.height * 0.20)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.08),
            control1: CGPoint(x: rect.width * 0.56, y: rect.height * 0.08),
            control2: CGPoint(x: rect.width * 0.63, y: rect.height * 0.00)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.92, y: rect.height * 0.50),
            control1: CGPoint(x: rect.width * 0.84, y: rect.height * 0.12),
            control2: CGPoint(x: rect.width, y: rect.height * 0.28)
        )
        path.addCurve(
            to: CGPoint(x: rect.width * 0.82, y: bottom),
            control1: CGPoint(x: rect.width, y: rect.height * 0.70),
            control2: CGPoint(x: rect.width * 0.95, y: rect.height * 0.92)
        )
        path.addLine(to: CGPoint(x: rect.width * 0.18, y: bottom))
        path.closeSubpath()
        return path
    }
}

/// A triangular pennant flag that attaches on its left edge.
private struct FlagPennantShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // Top-left anchor (attached to pole)
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Top edge to right tip with a slight wave
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rect.midY),
            control1: CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.04),
            control2: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY - rect.height * 0.10)
        )
        // Bottom edge back with a slight wave
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY),
            control1: CGPoint(x: rect.maxX - rect.width * 0.12, y: rect.midY + rect.height * 0.10),
            control2: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.04)
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
