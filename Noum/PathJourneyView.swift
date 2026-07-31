import Foundation
#if canImport(CoreLocation)
import CoreLocation
#endif

/// Visual state for the Path screen's compact landmark component. This is a
/// projection of `PathNodeStatus`, not a second progress owner.
enum ProgressLandmarkState: String, Equatable {
    case complete
    case current
    case upcoming

    var label: String {
        switch self {
        case .complete: return "Complete"
        case .current: return "Current"
        case .upcoming: return "Upcoming"
        }
    }
}

/// View-only handoff model for Figma's `Progress/Landmark` component.
/// Identity and copy remain sourced from the existing Path node registry.
struct ProgressLandmarkPresentation: Identifiable, Equatable {
    let id: String
    let state: ProgressLandmarkState
    let title: String
    let detail: String

    var accessibilityLabel: String {
        "\(state.label) path step, \(title). \(detail)"
    }
}

/// One calm slice of the full path: the last proof, the active prescription,
/// and the next landmark. The resolver intentionally owns no persistence and
/// cannot unlock or relock anything.
struct PathJourneyProgressProjection: Equatable {
    let statusLine: String
    let completed: ProgressLandmarkPresentation?
    let current: ProgressLandmarkPresentation
    let upcoming: ProgressLandmarkPresentation?

    static func make(
        statuses: [PathNodeStatus],
        evidenceDays: Int,
        currentGatingPhrase: String?
    ) -> PathJourneyProgressProjection {
        let evidenceDayCount = max(0, evidenceDays)
        let evidenceLabel = evidenceDayCount == 1 ? "evidence day" : "evidence days"

        guard !statuses.isEmpty else {
            return PathJourneyProgressProjection(
                statusLine: "Path ready · \(evidenceDayCount) \(evidenceLabel)",
                completed: nil,
                current: ProgressLandmarkPresentation(
                    id: "path.first-step",
                    state: .current,
                    title: "Start your path",
                    detail: "Complete one focused rep."
                ),
                upcoming: nil
            )
        }

        let currentIndex = statuses.firstIndex(where: \PathNodeStatus.isCurrent)
            ?? statuses.firstIndex(where: { !$0.isComplete })
        let stageOrdinal = currentIndex.map { $0 + 1 } ?? statuses.count
        let statusLine = "Stage \(stageOrdinal) of \(statuses.count) · \(evidenceDayCount) \(evidenceLabel)"

        guard let currentIndex else {
            return PathJourneyProgressProjection(
                statusLine: statusLine,
                completed: nil,
                current: ProgressLandmarkPresentation(
                    id: "path.complete",
                    state: .complete,
                    title: "Path complete",
                    detail: "Keep applying the skill in real conversations."
                ),
                upcoming: nil
            )
        }

        let currentStatus = statuses[currentIndex]
        let completedStatus = statuses[..<currentIndex].last(where: \PathNodeStatus.isComplete)
        let upcomingStatus = statuses.dropFirst(currentIndex + 1).first(where: { !$0.isComplete })

        return PathJourneyProgressProjection(
            statusLine: statusLine,
            completed: completedStatus.map {
                ProgressLandmarkPresentation(
                    id: $0.id,
                    state: .complete,
                    title: $0.node.title,
                    detail: $0.node.detail
                )
            },
            current: ProgressLandmarkPresentation(
                id: currentStatus.id,
                state: .current,
                title: currentStatus.node.title,
                detail: evidenceSafeDetail(currentGatingPhrase ?? currentStatus.node.detail)
            ),
            upcoming: upcomingStatus.map {
                ProgressLandmarkPresentation(
                    id: $0.id,
                    state: .upcoming,
                    title: $0.node.title,
                    detail: evidenceSafeDetail($0.node.detail)
                )
            }
        )
    }

    /// Legacy node copy used game-like "unlock" language. Path presents an
    /// evidence sequence, so the view projection removes only that suffix
    /// without mutating the authoritative node registry or gating rules.
    private static func evidenceSafeDetail(_ detail: String) -> String {
        detail
            .replacingOccurrences(of: " to unlock.", with: ".", options: .caseInsensitive)
            .replacingOccurrences(of: " to unlock", with: "", options: .caseInsensitive)
    }
}

#if canImport(SwiftUI)
import SwiftUI

enum PathLandscapeSizing {
    static func treePerspectiveScale(depthInField: Double) -> Double {
        1.0 + max(0, min(1, depthInField)) * 0.58
    }
}

/// Keeps the visible habit summary internally coherent when persisted streak
/// state is temporarily ahead of the eligible-session ledger (for example
/// after a fixture restore or an account transition). A rhythm cannot be
/// presented without at least one visible practice day.
enum PathConsistencyPresentation {
    static func displayedStreak(practicedDays: Int, rawStreak: Int) -> Int {
        practicedDays > 0 ? max(0, rawStreak) : 0
    }
}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct PathJourneyView: View {
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @StateObject private var pathProgress = PathProgressManager.shared
    @StateObject private var streakManager = StreakFreezeManager.shared
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var goalRefresh = GoalRefreshManager.shared
    @StateObject private var daylightModel = PathDaylightModel()
    @State private var selectedAchievementID: String?
    @State private var alongTheWayExpanded = false
    @State private var showWhyCapture = false
    /// Day-bloom settle beat. While non-nil the artwork renders rewound
    /// to this practiced-day count; clearing it inside `withAnimation`
    /// advances the reveal band to the live fraction. Set only when
    /// `JourneyDayBloomRatchet` reports a genuine upward change.
    @State private var bloomBaselineDays: Int?
    @State private var bloomTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
#if DEBUG
    @State private var debugDayOverride: Double = -1

    private var isDebugActive: Bool { debugDayOverride >= 0 }
#endif

    /// Days-driven landscape truth (System A). The artwork and compact
    /// evidence-day status read THIS: the path is worn in by practiced days
    /// — the habit — never by landmark counts. The coach's node sequence is
    /// projected separately so the two progressions never masquerade as one.
    private var snapshot: PracticeJourneySnapshot {
        let base = PracticeJourneySnapshot.make(from: sessionStore.progressEligibleSessions)
            .withDisplayedStreak(streakManager.currentStreak)
#if DEBUG
        if isDebugActive {
            return base.withSimulatedReveal(Int(debugDayOverride))
        }
#endif
        return base
    }

    private var retentionSnapshot: RetentionLoopSnapshot {
        RetentionLoopEngine.snapshot(
            sessions: sessionStore.progressEligibleSessions,
            profile: coachingProfileStore.profile,
            displayedStreak: streakManager.currentStreak
        )
    }

    /// What the hero artwork renders. Identical to `snapshot` except for
    /// the one beat where the day-bloom holds the reveal at the last-seen
    /// count; the status line always reads the live snapshot so copy never
    /// lags the truth. The DEBUG slider wins —
    /// it already owns `snapshot` wholesale.
    private var artworkSnapshot: PracticeJourneySnapshot {
#if DEBUG
        if isDebugActive { return snapshot }
#endif
        if let bloomBaselineDays {
            return snapshot.withRevealRewound(toDays: bloomBaselineDays)
        }
        return snapshot
    }

    private var practicedToday: Bool {
        let calendar = Calendar.current
        return sessionStore.progressEligibleSessions.contains { calendar.isDateInToday($0.date) }
    }

    private var progressProjection: PathJourneyProgressProjection {
        PathJourneyProgressProjection.make(
            statuses: pathProgress.statuses,
            evidenceDays: snapshot.practicedDays,
            currentGatingPhrase: pathProgress.currentNodeGatingPhrase
        )
    }

    private var whyContent: JourneyWhyContent? {
        JourneyWhyComposer.whyContent(
            successVision: coachingProfileStore.profile?.successVision ?? "",
            motivationWhyNow: coachingProfileStore.profile?.motivationWhyNow ?? "",
            paraphrasedGoal: coachingProfileStore.profile?.trustedStyleGoalParaphrase,
            coachingBrief: coachingProfileStore.profile?.coachingBrief ?? ""
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                AppColor.screenBackground
                .ignoresSafeArea()

                ScrollViewReader { scrollProxy in
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Path")
                                    .font(Typography.screenTitle)
                                Text(headerStateLine)
                                    .font(Typography.subheadline)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                ZStack {
                                    PathJourneyArtwork(
                                        snapshot: artworkSnapshot,
                                        compact: false,
                                        sceneResolver: { date in
                                            daylightModel.sceneState(for: date)
                                        },
                                        onDestinationTap: {
                                            if reduceMotion {
                                                scrollProxy.scrollTo("journey.why", anchor: .center)
                                            } else {
                                                withAnimation(.easeInOut(duration: 0.45)) {
                                                    scrollProxy.scrollTo("journey.why", anchor: .center)
                                                }
                                            }
                                        }
                                    )
                                    // Reduce-motion swaps the settle for a plain
                                    // crossfade: keying identity on the bloom state
                                    // fades the rewound artwork into the live one
                                    // with zero movement. Identity stays fixed when
                                    // motion is allowed so the band animates in place.
                                    .id(reduceMotion
                                        ? "journey.artwork.bloomed.\(bloomBaselineDays == nil)"
                                        : "journey.artwork")
                                }
                                .frame(
                                    height: dynamicTypeSize.isAccessibilitySize
                                        ? min(176, geometry.size.height * 0.23)
                                        : min(216, geometry.size.height * 0.28)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                                        .stroke(Color.white.opacity(0.38), lineWidth: 1)
                                )
                                .shadow(color: AppColor.brandBlue.opacity(0.06), radius: 8, y: 4)

                                journeyStatusLine
                                ProgressLandmark(presentation: progressProjection.current)
                                todayRow
                                landmarkContextRows
                            }

                            whyCard
                                .id("journey.why")

                            alongTheWayCard

                            // MARK: - Debug day slider (developer only)
#if DEBUG
                            if AuthManager.shared.isDeveloper {
                                debugSliderCard
                            }
#endif
                        }
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.top, Spacing.xs)
                        .padding(.bottom, Spacing.md)
                    }
                }
            }
        }
        .sheet(isPresented: $showWhyCapture) {
            DeferredProfileCaptureSheet(prompt: .whyNow)
        }
        .accessibilityIdentifier("journey.screen")
        .toolbarBackground(AppColor.screenBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            daylightModel.activate()
        }
        .onAppear {
            evaluateDayBloom()
        }
        .onDisappear {
            // An interrupted bloom must not strand the artwork on the
            // rewound fraction — the ratchet already committed, so the
            // next appear would read .unchanged and never clear it.
            bloomTask?.cancel()
            bloomTask = nil
            bloomBaselineDays = nil
        }
    }

    /// Compare the live practiced-day count against the per-account
    /// ratchet and, on a genuine increase, play the one-shot settle beat:
    /// hold the artwork at the last-seen fraction for a breath, then
    /// advance the reveal band and shift the current-position marker
    /// forward. Seeding, equal counts,
    /// and window-slide decreases all return without animating — the
    /// ratchet commits inside `evaluate` either way.
    private func evaluateDayBloom() {
        // `debugDayOverride` is always inactive at appear, so this reads
        // the real window count, never a simulated one.
        let outcome = JourneyDayBloomRatchet.evaluate(currentDays: snapshot.practicedDays)
        guard case .advanced(let previousDays) = outcome else { return }

        bloomBaselineDays = previousDays
        bloomTask?.cancel()
        bloomTask = Task { @MainActor in
            // Let the page land before the beat so the change reads as
            // "this just happened," not as load-in jitter.
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.45)) {
                    bloomBaselineDays = nil
                }
            } else {
                withAnimation(.easeOut(duration: 0.8)) {
                    bloomBaselineDays = nil
                }
            }
        }
    }

#if DEBUG
    private var debugSliderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Debug: Simulate Path Reveal")
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
                Text("\(isDebugActive ? Int(debugDayOverride) : Int(snapshot.revealProgress * 21))")
                    .font(Typography.figtreeNumeric(size: 28, relativeTo: .title))
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
#endif

    /// Figma's target framing: Path is a proof-to-transfer sequence, not a
    /// second score or a streak dashboard.
    private var headerStateLine: String {
        "One journey from proof to real-world transfer."
    }

    private var journeyStatusLine: some View {
        Text(progressProjection.statusLine)
            .font(Typography.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Spacing.xxs)
            .accessibilityLabel(progressProjection.statusLine.replacingOccurrences(of: "·", with: ","))
        .accessibilityIdentifier("journey.consistency")
    }

    @ViewBuilder
    private var landmarkContextRows: some View {
        if progressProjection.completed != nil || progressProjection.upcoming != nil {
            VStack(spacing: Spacing.xs) {
                if let completed = progressProjection.completed {
                    ProgressLandmark(presentation: completed)
                }
                if let upcoming = progressProjection.upcoming {
                    ProgressLandmark(presentation: upcoming)
                }
            }
            .accessibilityIdentifier("journey.landmark.context")
        }
    }

    /// The page's one call to action. Pre-rep it points at practice;
    /// post-rep it acknowledges, quietly.
    @ViewBuilder
    private var todayRow: some View {
        if practicedToday {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(AppColor.brandBlue)
                Text("Today's rep is done.")
                    .font(Typography.cardLabel)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .frame(minHeight: 52)
            .padding(.horizontal, Spacing.md)
            .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("journey.today")
        } else {
            let current = pathProgress.statuses.first(where: { $0.isCurrent })
                ?? pathProgress.statuses.first(where: { !$0.isComplete })
            let destination = current?.node.actionDestination ?? AppDestination.practiceSelection
            let title = current == nil ? "Choose a practice" : "Start prescribed rep"

            NavigationLink(value: destination) {
                Text(title)
                    .font(Typography.cardLabel)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .padding(.horizontal, Spacing.md)
                .contentShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            }
            .buttonStyle(.pressable)
            .background(AppColor.brandBlue, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .accessibilityLabel(title)
            .accessibilityHint(current.map { "Opens the practice for \($0.node.title)." } ?? "Opens the practice library.")
            .accessibilityIdentifier("journey.today")
        }
    }

    /// The user's own reason, kept visible — what the flag on the
    /// horizon stands for. Provenance rule: quotation marks and italics
    /// ONLY around the user's literal words; the AI paraphrase renders
    /// plain so the page never puts words in their mouth.
    private var whyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your reason")
                .font(Typography.headline)
                .foregroundStyle(AppColor.brandBlue.opacity(0.85))

            if let why = whyContent {
                Group {
                    if why.provenance == .userVerbatim {
                        Text("\u{201C}\(why.text)\u{201D}")
                            .font(.body.weight(.medium).italic())
                    } else {
                        Text(why.text)
                            .font(.body.weight(.medium))
                    }
                }
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)

                HStack {
                    Spacer()
                    Button {
                        goalRefresh.requestReview()
                    } label: {
                        Label("Edit", systemImage: "pencil")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.brandBlue.opacity(0.9))
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("journey.why.refresh")
                }
            } else {
                Text("What matters outside the app?")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Button {
                    showWhyCapture = true
                } label: {
                    Label("Add your reason", systemImage: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("journey.why.capture")
            }

            if goalRefresh.shouldPresent {
                GoalRefreshInlineCard()
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, Spacing.sm)
        .accessibilityIdentifier("journey.why")
    }

    /// The weekly challenge and skill milestones, demoted into one quiet
    /// disclosure — real content, off the main read. They near-duplicate
    /// the landmark ladder; until they merge, they stay reachable here
    /// without competing for the page's story.
    private var alongTheWayCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.84)) {
                    alongTheWayExpanded.toggle()
                }
            } label: {
                HStack {
                    Text("More progress")
                        .font(Typography.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(alongTheWayExpanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("journey.alongTheWay")
            .accessibilityLabel("More progress")
            .accessibilityValue(alongTheWayExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(alongTheWayExpanded ? "Hides weekly and milestone progress." : "Shows weekly and milestone progress.")

            if alongTheWayExpanded {
                VStack(alignment: .leading, spacing: 10) {
                    activeChallengeRow
                    ForEach(Array(retentionSnapshot.achievements.prefix(3))) { achievement in
                        Button {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.84)) {
                                selectedAchievementID = selectedAchievementID == achievement.id ? nil : achievement.id
                            }
                        } label: {
                            milestoneRow(
                                achievement: achievement,
                                isExpanded: selectedAchievementID == achievement.id
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.vertical, Spacing.sm)
    }

    /// This week's focus (the active challenge), compacted to one row
    /// inside the "Along the way" disclosure.
    private var activeChallengeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly focus")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                Spacer()
                Text(retentionSnapshot.activeChallenge.progressLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            Text(retentionSnapshot.activeChallenge.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(retentionSnapshot.activeChallenge.summary)
                .font(.caption)
                .foregroundStyle(.secondary)

            ShimmerProgressBar(progress: retentionSnapshot.activeChallenge.progress, tint: .blue, animated: false)
        }
        .padding(12)
        .background(Color.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    @ViewBuilder
    private func milestoneRow(achievement: PracticeAchievementStatus, isExpanded: Bool) -> some View {
        let isUnlocked = achievement.isUnlocked
        let accent: Color = isUnlocked ? AppColor.brandBlue : Color.secondary
        let rowBackground: Color = isUnlocked
            ? AppColor.brandBlue.opacity(0.05)
            : Color.black.opacity(0.025)
        let borderColor: Color = isUnlocked
            ? AppColor.brandBlue.opacity(0.16)
            : Color.black.opacity(0.05)

        HStack(alignment: .top, spacing: 12) {
            // Thin colored leading bar — blue for unlocked, grayscale for locked.
            // This is the primary at-a-glance signal between locked/unlocked.
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(isUnlocked ? AppColor.brandBlue : Color.black.opacity(0.10))
                .frame(width: 3)
                .frame(maxHeight: .infinity)

            // Icon disc — tinted when unlocked, grayscale when locked.
            // A small check chip is pinned bottom-trailing on unlocked rows
            // as a concrete second-tier signal beyond the colored leading bar.
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    Circle()
                        .fill(isUnlocked ? AppColor.brandBlue.opacity(0.12) : Color.black.opacity(0.06))
                        .frame(width: 40, height: 40)

                    Image(systemName: achievement.symbolName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(isUnlocked ? AppColor.brandBlue : Color.secondary)
                }
                .frame(width: 40, height: 40)

                if isUnlocked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, AppColor.brandBlue)
                        .offset(x: 2, y: 2)
                }
            }
            .frame(width: 44, height: 44, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(achievement.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isUnlocked ? .primary : Color.secondary)
                        Text(achievement.summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 8)

                    VStack(alignment: .trailing, spacing: 6) {
                        Text(achievement.progressLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(accent)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        ShimmerProgressBar(
                            progress: achievement.progress,
                            tint: isUnlocked ? AppColor.brandBlue : .blue,
                            animated: false
                        )
                        Text(
                            isUnlocked
                                ? "Reached through repeated practice."
                                : "Keep practicing — this step unlocks once the habit is holding."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .fill(rowBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1)
        )
    }
}

/// SwiftUI counterpart of Figma `Progress/Landmark` (`31:189`). The component
/// communicates state with icon, label, surface, and border so colour is never
/// the only cue. It is deliberately view-only; `PathProgressManager` remains
/// the sole owner of unlock truth.
@available(iOS 17.0, macOS 12.0, *)
struct ProgressLandmark: View {
    let presentation: ProgressLandmarkPresentation
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(presentation.state == .current ? Spacing.md : Spacing.sm)
        .background(
            landmarkSurface,
            in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(
                    landmarkBorder,
                    lineWidth: presentation.state == .current ? 2 : 1
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityIdentifier("journey.landmark.\(presentation.state.rawValue)")
    }

    private var standardLayout: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            stateIcon
            landmarkCopy
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                stateIcon
                Text(presentation.state.label)
                    .font(Typography.caption)
                    .foregroundStyle(landmarkAccent)
            }
            Text(presentation.title)
                .font(Typography.cardLabel)
                .foregroundStyle(.primary)
            Text(presentation.detail)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var landmarkCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(presentation.state.label)
                .font(Typography.captionSmall)
                .foregroundStyle(landmarkAccent)
            Text(presentation.title)
                .font(Typography.cardLabel)
                .foregroundStyle(.primary)
            Text(presentation.detail)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stateIcon: some View {
        ZStack {
            Circle()
                .fill(iconSurface)
                .frame(width: 40, height: 40)
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(iconForeground)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }

    private var iconName: String {
        switch presentation.state {
        case .complete: return "checkmark"
        case .current: return "arrow.right"
        case .upcoming: return "circle.dashed"
        }
    }

    private var landmarkAccent: Color {
        presentation.state == .upcoming ? Color.secondary : AppColor.brandBlue
    }

    private var iconSurface: Color {
        switch presentation.state {
        case .current: return AppColor.brandBlue
        case .complete: return AppColor.brandBlue.opacity(0.12)
        case .upcoming: return AppColor.innerSurface
        }
    }

    private var iconForeground: Color {
        presentation.state == .current ? .white : landmarkAccent
    }

    private var landmarkSurface: Color {
        switch presentation.state {
        case .current: return AppColor.lightGradientStart
        case .complete, .upcoming: return AppColor.cardBackground
        }
    }

    private var landmarkBorder: Color {
        switch presentation.state {
        case .current: return AppColor.brandBlue
        case .complete: return AppColor.brandBlue.opacity(0.14)
        case .upcoming: return AppColor.subtleBorder
        }
    }
}

struct PracticeChallengeStatus {
    let title: String
    let summary: String
    let progress: Double
    let progressLabel: String
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
    /// `displayedStreak` lets MainActor call sites hand in the freeze-aware
    /// streak from `StreakFreezeManager` (the single displayed-streak owner)
    /// so the "X/2 days" challenge label and streak achievements can never
    /// disagree with the number Home shows. The raw fallback keeps the
    /// engine pure for tests and non-live inputs.
    static func snapshot(
        sessions: [PracticeSession],
        profile: CoachingProfile?,
        displayedStreak: Int? = nil
    ) -> RetentionLoopSnapshot {
        let sortedSessions = PracticeProgressEligibility.eligibleSessions(in: sessions)
            .sorted { $0.date > $1.date }
        let recentSessions = Array(sortedSessions.prefix(6))
        let currentStreak = displayedStreak ?? currentStreak(from: sortedSessions)

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
                title: "Build a rhythm",
                summary: "One focused rep a day — today counts.",
                progress: progress,
                progressLabel: "\(currentStreak)/2 days"
            )
        }

        switch profile?.biggestChallenge {
        case .fillerWords:
            let qualifying = sessions.filter { $0.fillerWordCount <= 2 && $0.wordCount >= 14 }.count
            return PracticeChallengeStatus(
                title: "Clean delivery",
                summary: "Complete two recent reps with two fillers or fewer.",
                progress: min(Double(qualifying), 2) / 2,
                progressLabel: "\(qualifying)/2 clean reps"
            )
        case .rambling:
            let qualifying = sessions.filter {
                ($0.score ?? 0) >= 7 && $0.duration >= 20 && $0.wordCount >= 18
            }.count
            return PracticeChallengeStatus(
                title: "Land the point",
                summary: "Finish two strong reps that stay structured instead of drifting.",
                progress: min(Double(qualifying), 2) / 2,
                progressLabel: "\(qualifying)/2 structured reps"
            )
        case .freezing:
            let qualifying = sessions.filter {
                ($0.score ?? 0) >= 6 && ($0.mode == .suddenDeath || $0.mode == .timed || $0.mode == .imConversation)
            }.count
            return PracticeChallengeStatus(
                title: "Fast response reps",
                summary: "Hit two quick-answer sessions without freezing or collapsing the reply.",
                progress: min(Double(qualifying), 2) / 2,
                progressLabel: "\(qualifying)/2 pressure reps"
            )
        case .rushing:
            let qualifying = sessions.filter {
                ($0.score ?? 0) >= 7 && ConversationalPaceBand.contains($0.wordsPerMinute)
            }.count
            return PracticeChallengeStatus(
                title: "Controlled pace",
                summary: "Finish two solid reps in the conversational pacing zone.",
                progress: min(Double(qualifying), 2) / 2,
                progressLabel: "\(qualifying)/2 controlled reps"
            )
        case .none:
            let qualifying = allSessions.filter { ($0.score ?? 0) >= 7 }.prefix(3).count
            return PracticeChallengeStatus(
                title: "Sharp sessions",
                summary: "Build three solid sessions to set your baseline.",
                progress: min(Double(qualifying), 3) / 3,
                progressLabel: "\(qualifying)/3 strong sessions"
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
                summary: "Complete three Conversation Practice sessions.",
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
        let calendar = Calendar.current
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

    /// Returns a copy with visual reveal progress overridden for DEBUG-only
    /// inspection. Narrative copy stays live so the simulator tool cannot
    /// become a second product truth source.
    func withSimulatedReveal(_ days: Int) -> PracticeJourneySnapshot {
        let windowDays = 21
        let clamped = max(0, min(windowDays, days))
        let progress = Double(clamped) / Double(windowDays)
        let pct = Int(progress * 100)
        return PracticeJourneySnapshot(
            practicedDays: clamped,
            streak: clamped,
            revealProgress: progress,
            quality: quality,
            progressLabel: "\(pct)% preview",
            previewLine: previewLine,
            summaryLine: summaryLine,
            explanationLine: explanationLine,
            nextMilestoneLabel: nextMilestoneLabel,
            consequenceLine: consequenceLine,
            homeGoalLine: homeGoalLine,
            homeGoalShortLabel: homeGoalShortLabel
        )
    }

    /// Returns a copy with the reveal rewound to an earlier practiced-day
    /// count. Drives the day-bloom settle beat: the artwork opens at the
    /// last-seen fraction and animates forward to the live one. Only the
    /// two reveal-driving fields change — streak, quality, and every
    /// narrative line stay live (the rewind is a visual baseline for one
    /// beat, not a second truth source).
    func withRevealRewound(toDays days: Int) -> PracticeJourneySnapshot {
        let windowDays = 21
        let clamped = max(0, min(windowDays, days))
        return PracticeJourneySnapshot(
            practicedDays: clamped,
            streak: streak,
            revealProgress: Double(clamped) / Double(windowDays),
            quality: quality,
            progressLabel: progressLabel,
            previewLine: previewLine,
            summaryLine: summaryLine,
            explanationLine: explanationLine,
            nextMilestoneLabel: nextMilestoneLabel,
            consequenceLine: consequenceLine,
            homeGoalLine: homeGoalLine,
            homeGoalShortLabel: homeGoalShortLabel
        )
    }

    /// Returns a copy with the displayed streak swapped in.
    /// `StreakFreezeManager.currentStreak` is the single displayed-streak
    /// owner (freeze-aware, never punishes one missed day); the snapshot's
    /// internal strict streak only seeds the quality read. The reveal
    /// stays days-driven — landmark progress never touches the landscape.
    func withDisplayedStreak(_ displayed: Int) -> PracticeJourneySnapshot {
        PracticeJourneySnapshot(
            practicedDays: practicedDays,
            streak: max(0, displayed),
            revealProgress: revealProgress,
            quality: quality,
            progressLabel: progressLabel,
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
        let sessions = PracticeProgressEligibility.eligibleSessions(in: sessions)
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
        let scoreQuality = min(1, averageScore / 100)
        let fillerQuality = max(0, 1 - (averageFillers / 8))
        let durationQuality = min(1, averageDuration / 45)
        let streakQuality = min(1, Double(streak) / 7)
        let quality = min(1, (scoreQuality * 0.30) + (fillerQuality * 0.30) + (durationQuality * 0.20) + (streakQuality * 0.20))

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

        // Forward-framed only — absence is described as invitation, never
        // as a threatened loss (never-punish-shame invariant).
        let consequenceLine: String
        if practicedDays == 0 {
            consequenceLine = "The route is here when you are ready to start."
        } else if streak <= 1 {
            consequenceLine = "Each return keeps the route easy to find."
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
            homeGoalShortLabel = "Start"
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
        streak > 0 ? "\(streak) day\(streak == 1 ? "" : "s")" : "Start today"
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

struct PathJourneyPresentation: Equatable {
    let revealProgress: Double
    let currentStreak: Int
    let progressLabel: String
    let previewLine: String
    let summaryLine: String
    let explanationLine: String
    let nextMilestoneLabel: String
    let consequenceLine: String
    let homeGoalLine: String
    let homeGoalShortLabel: String

    static func make(
        statuses: [PathNodeStatus],
        currentStreak: Int,
        sessionCount: Int,
        currentGatingPhrase: String?
    ) -> PathJourneyPresentation {
        let totalCount = statuses.count
        let completedCount = statuses.filter(\.isComplete).count
        let current = statuses.first(where: { !$0.isComplete })
        return make(
            completedCount: completedCount,
            currentProgress: current?.progress,
            totalCount: totalCount,
            currentTitle: current?.node.title,
            currentDetail: current?.node.detail,
            currentGatingPhrase: currentGatingPhrase,
            currentStreak: currentStreak,
            sessionCount: sessionCount
        )
    }

    static func make(
        completedCount rawCompletedCount: Int,
        currentProgress rawCurrentProgress: Double?,
        totalCount rawTotalCount: Int,
        currentTitle: String?,
        currentDetail: String?,
        currentGatingPhrase: String?,
        currentStreak: Int,
        sessionCount: Int
    ) -> PathJourneyPresentation {
        let totalCount = max(0, rawTotalCount)
        let completedCount = min(max(0, rawCompletedCount), totalCount)
        let hasPath = totalCount > 0
        let isComplete = hasPath && completedCount >= totalCount
        let currentProgress = isComplete
            ? 0
            : min(1, max(0, rawCurrentProgress ?? 0))
        let revealProgress = progress(
            completedCount: completedCount,
            currentProgress: currentProgress,
            totalCount: totalCount
        )
        let pct = Int((revealProgress * 100).rounded(.down))

        if !hasPath {
            return PathJourneyPresentation(
                revealProgress: 0,
                currentStreak: max(0, currentStreak),
                progressLabel: "Path pending",
                previewLine: "One short rep gives Noum a real signal to build from.",
                summaryLine: "Path steps come from completed practice, not days on a calendar.",
                explanationLine: "Start with one rep.",
                nextMilestoneLabel: "Complete one rep to reveal the first step.",
                consequenceLine: "The path begins with your first completed rep.",
                homeGoalLine: "Start the path with one rep today.",
                homeGoalShortLabel: "Start"
            )
        }

        if isComplete {
            return PathJourneyPresentation(
                revealProgress: 1,
                currentStreak: max(0, currentStreak),
                progressLabel: "100% complete",
                previewLine: "The current path is clear. Keep training to make the gains durable.",
                summaryLine: "All \(totalCount) path steps reached from real practice signals.",
                explanationLine: "Current path complete.",
                nextMilestoneLabel: "Keep training to strengthen the habits behind the unlocks.",
                consequenceLine: "The coach will keep looking for the next clear pattern.",
                homeGoalLine: "All \(totalCount) path steps reached. Keep the route strong.",
                homeGoalShortLabel: "Cleared"
            )
        }

        let landmarkNumber = min(totalCount, completedCount + 1)
        let title = currentTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = currentDetail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let gating = currentGatingPhrase?.trimmingCharacters(in: .whitespacesAndNewlines)
        let readableTitle = title?.isEmpty == false ? title! : "Next step"
        let readableDetail = detail?.isEmpty == false
            ? detail!
            : "Complete a rep to give this node a stronger signal."
        let readableGate = gating?.isEmpty == false
            ? gating!
            : "Keep training to move toward this step."

        let previewLine: String
        if sessionCount <= 0 {
            previewLine = "The path starts after one real rep. No step is claimed before you speak."
        } else if completedCount == 0 {
            previewLine = "Your first path step is ahead. Noum is reading real reps now."
        } else {
            previewLine = "\(completedCount) path step\(completedCount == 1 ? "" : "s") reached. The next one is based on your latest signals."
        }

        return PathJourneyPresentation(
            revealProgress: revealProgress,
            currentStreak: max(0, currentStreak),
            progressLabel: "\(pct)% complete",
            previewLine: previewLine,
            summaryLine: "\(completedCount) of \(totalCount) path steps reached from real practice signals.",
            explanationLine: "Step \(landmarkNumber): \(readableTitle)",
            nextMilestoneLabel: readableGate,
            consequenceLine: readableDetail,
            homeGoalLine: "Step \(landmarkNumber) of \(totalCount): \(readableTitle). \(readableGate)",
            homeGoalShortLabel: "\(pct)%"
        )
    }

    static func progress(completedCount rawCompletedCount: Int, currentProgress rawCurrentProgress: Double, totalCount rawTotalCount: Int) -> Double {
        let totalCount = max(0, rawTotalCount)
        guard totalCount > 0 else { return 0 }
        let completedCount = min(max(0, rawCompletedCount), totalCount)
        guard completedCount < totalCount else { return 1 }
        let currentProgress = min(1, max(0, rawCurrentProgress))
        return min(1, max(0, (Double(completedCount) + currentProgress) / Double(totalCount)))
    }
}

// MARK: - Why composer (pure, view-free)

/// What the journey page shows as the user's reason for walking.
struct JourneyWhyContent: Equatable {
    enum Provenance: Equatable {
        /// The user's literal words — the ONLY provenance that renders
        /// with quotation marks. Quoting the AI paraphrase would put
        /// words in the user's mouth (overclaiming at the typographic
        /// level).
        case userVerbatim
        /// `CoachingProfile.paraphrasedGoal` — AI-sanitised; renders plain.
        case paraphrase
    }

    let text: String
    let provenance: Provenance
}

/// Pure resolvers for the journey page's "Why you're walking" card.
/// No state of its own — reads the fields the app already captures
/// (onboarding + DeferredProfileCapture) and the session-derived
/// recency facts the page already computes.
enum JourneyWhyComposer {

    /// Longest verbatim answer we'll surface before preferring the AI
    /// paraphrase — a why should land in one breath, and onboarding
    /// answers can run long. If there's no paraphrase, the long verbatim
    /// still wins: real words beat no words.
    static let verbatimLengthLimit = 220

    /// Fallback chain: success vision → why-now → AI paraphrase →
    /// coaching brief → nil (the card invites capture instead of
    /// fabricating a reason).
    static func whyContent(
        successVision: String,
        motivationWhyNow: String,
        paraphrasedGoal: String?,
        coachingBrief: String
    ) -> JourneyWhyContent? {
        let paraphrase = paraphrasedGoal?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let verbatimCandidates = [successVision, motivationWhyNow]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if let verbatim = verbatimCandidates.first {
            if verbatim.count <= verbatimLengthLimit || paraphrase.isEmpty {
                return JourneyWhyContent(text: verbatim, provenance: .userVerbatim)
            }
            return JourneyWhyContent(text: paraphrase, provenance: .paraphrase)
        }

        if !paraphrase.isEmpty {
            return JourneyWhyContent(text: paraphrase, provenance: .paraphrase)
        }

        let brief = coachingBrief.trimmingCharacters(in: .whitespacesAndNewlines)
        if !brief.isEmpty {
            return JourneyWhyContent(text: brief, provenance: .userVerbatim)
        }

        return nil
    }

    /// One state-aware coach line under the why. Forward-framing only:
    /// a return after absence is re-anchored ("nothing you built is
    /// gone"), never counted against the user. No missed-day numbers,
    /// no loss copy — the never-punish-shame invariant applies to every
    /// branch here.
    static func coachLine(
        practicedToday: Bool,
        daysSinceLastSession: Int?,
        streak: Int,
        practicedDays: Int,
        windowDays: Int = 21,
        hasWhy: Bool
    ) -> String {
        guard hasWhy else {
            return "Tell Noum why this matters. A coach who knows what you're walking toward can hold you to it."
        }

        guard daysSinceLastSession != nil else {
            return "This field is where that lives. One rep cuts the first line toward it."
        }

        if practicedDays >= windowDays {
            return "You've walked all \(windowDays) of the last \(windowDays) days. What you're walking toward hasn't moved — you have."
        }

        if practicedToday {
            return "Today counted. You're a day's walking closer."
        }

        if let gap = daysSinceLastSession, gap >= 4 {
            return "Nothing you built is gone — the trail just softened. One rep reopens it."
        }

        if streak >= 3 {
            return "\(streak) days of showing up for this. The path is holding under your feet."
        }

        return "Each return makes the route easier to find."
    }
}

struct PathJourneyArtwork: View {
    let snapshot: PracticeJourneySnapshot
    let compact: Bool
    let sceneResolver: (Date) -> PathSkyScene
    /// Fired when the user taps the destination flag. The page scrolls
    /// to the why card — the flag IS the why.
    var onDestinationTap: (() -> Void)? = nil

    @State private var scene: PathSkyScene?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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

                // Destination glow — a soft beacon at the vanishing point
                // where the trail leads. It exists before the first rep
                // (the destination is real before you start walking) and
                // warms with reveal; green-shifts when the window is full,
                // matching the flag.
                destinationGlow(size: size, scene: currentScene)

                // Goal marker rendered outside the field mask so the flag
                // pole and banner are never clipped by the ground region.
                if snapshot.revealProgress > 0 {
                    goalMarker(size: size)
                }

                // Current position on the trail. A grounded marker keeps
                // the "you are here" affordance without dropping the coach
                // mascot into the landscape metaphor.
                currentPositionMarker(size: size)

                // Tap target over the flag → the why card. Rendered last
                // so nothing occludes the hit area.
                if onDestinationTap != nil {
                    destinationTapTarget(size: size)
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
        let signWidth: CGFloat = compact ? 28 : 42
        let signHeight: CGFloat = compact ? 13 : 19
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
                .position(x: centerX + signWidth * 0.16, y: poleTopY + signHeight * 0.55)

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

            // Quiet trail sign — a grounded landmark rather than a bright
            // arcade pennant. The destination remains tappable through the
            // same accessibility contract below.
            ZStack {
                RoundedRectangle(cornerRadius: compact ? 2 : 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isComplete
                                ? [Color(red: 0.18, green: 0.55, blue: 0.30), Color(red: 0.12, green: 0.38, blue: 0.22)]
                                : [Color(red: 0.48, green: 0.32, blue: 0.17), Color(red: 0.30, green: 0.20, blue: 0.11)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: compact ? 2 : 3, style: .continuous)
                            .stroke(Color.white.opacity(0.28), lineWidth: compact ? 0.6 : 0.9)
                    )

                Image(systemName: isComplete ? "checkmark" : "arrow.right")
                    .font(.system(size: compact ? 7 : 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .frame(width: signWidth, height: signHeight)
            .shadow(color: .black.opacity(0.18), radius: 2, y: 1)
            .position(
                x: centerX + signWidth * 0.42,
                y: poleTopY + signHeight * 0.50 + (compact ? 1 : 2)
            )

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

    // MARK: - Destination glow + current position

    @ViewBuilder
    private func destinationGlow(size: CGSize, scene: PathSkyScene) -> some View {
        let field = fieldMetrics(for: size)
        let isComplete = snapshot.revealProgress >= 1.0
        let intensity = 0.16 + snapshot.revealProgress * 0.22
        let color = isComplete
            ? Color(red: 0.36, green: 0.86, blue: 0.52)
            : scene.glowColor
        let radius: CGFloat = compact ? 58 : 92

        RadialGradient(
            colors: [color.opacity(intensity), Color.clear],
            center: .center,
            startRadius: 2,
            endRadius: radius
        )
        .frame(width: radius * 2, height: radius * 2)
        .position(x: size.width * 0.515, y: field.top - (compact ? 26 : 38))
        .allowsHitTesting(false)
    }

    /// Where the current-position marker sits: the frontier of the revealed
    /// trail, following the path's perspective. A quiet waypoint dot avoids
    /// turning the landscape into literal clip-art while still reading as
    /// "you are here."
    private func currentPositionMetrics(for size: CGSize) -> (x: CGFloat, y: CGFloat, size: CGFloat) {
        let field = fieldMetrics(for: size)
        let frontierY = field.top + hiddenDepth(for: size)

        // Same depth mapping the grass rows use: 0 at the horizon end of
        // the field, 1 at the bottom edge.
        let yNorm = Double(frontierY / max(size.height, 1))
        let markerDepth = max(0, min(1, (yNorm - 0.55) / 0.39))
        let curveShift = (1.0 - markerDepth) * 0.015 - markerDepth * 0.01
        let x = size.width * CGFloat(0.5 + curveShift)

        let markerSize = (compact ? 18.0 : 25.0) + (compact ? 18.0 : 26.0) * markerDepth
        let rawY = frontierY - CGFloat(markerSize) * 0.30
        let y = min(rawY, size.height - CGFloat(markerSize) * 0.72)
        return (x, y, CGFloat(markerSize))
    }

    @ViewBuilder
    private func currentPositionMarker(size: CGSize) -> some View {
        let metrics = currentPositionMetrics(for: size)

        ZStack {
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: metrics.size * 0.62, height: metrics.size * 0.62)
                .shadow(color: .black.opacity(0.16), radius: 3, y: 2)

            Circle()
                .fill(AppColor.brandBlue)
                .frame(width: metrics.size * 0.26, height: metrics.size * 0.26)
        }
        .position(x: metrics.x, y: metrics.y)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func destinationTapTarget(size: CGSize) -> some View {
        let field = fieldMetrics(for: size)
        Color.clear
            .frame(width: 56, height: compact ? 64 : 88)
            .contentShape(Rectangle())
            .position(x: size.width * 0.515, y: field.top - (compact ? 22 : 32))
            .onTapGesture { onDestinationTap?() }
            .accessibilityElement()
            .accessibilityLabel("Your destination. Opens why you're walking.")
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("journey.flag")
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
                    id: row * 1000 + column,
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
            // Day-bloom: newly earned flowers scale-bloom in with a small
            // per-flower stagger so a multi-day catch-up reads as growth,
            // not a redraw. Flowers have stable ids, so this fires only
            // for genuine insertions; reduce-motion bloom paths replace
            // the whole artwork (crossfade), so no movement leaks there.
            .transition(
                reduceMotion
                    ? .opacity
                    : AnyTransition.scale(scale: 0.25)
                        .combined(with: .opacity)
                        .animation(
                            .spring(response: 0.45, dampingFraction: 0.7)
                                .delay(0.30 + Double(flower.id % 3) * 0.16)
                        )
            )
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

        // Index-stable ids: a flower keeps its identity as the visible
        // prefix grows, so the day-bloom inserts only the new ones.
        return allFlowers.prefix(clamped).enumerated().map { index, flower in
            JourneyFlowerNode(
                id: index,
                position: CGPoint(x: size.width * flower.0, y: size.height * flower.1),
                size: compact ? 5 : 7,
                color: flower.2,
                opacity: flower.3,
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
                .shadow(color: .black.opacity(0.12), radius: 2, y: 2)
                .opacity(tree.opacity)
            }
        }
    }

    private func canopyGradient(for tree: FieldTreeNode) -> LinearGradient {
        LinearGradient(
            colors: [tree.highlight, tree.color, tree.color],
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

        // A restrained tree line keeps the landscape open. Trees deliberately
        // share nearly the same scale and sit away from the path corridor so
        // the scene reads as depth, not two overlapping green walls.
        let values: [(Double, Double, Double, TreeVariety)] = [
            (0.03, 1.00, 0.00, .pointed),
            (0.17, 1.02, 0.00, .round),
            (0.31, 1.00, 0.08, .round),
            (0.69, 1.00, 0.08, .layered),
            (0.83, 1.02, 0.00, .pointed),
            (0.97, 1.00, 0.00, .layered),
        ]

        return values.map { x, scale, depthInField, variety in
            // Trees lower in the field are physically nearer to the viewer.
            let perspectiveFactor = PathLandscapeSizing.treePerspectiveScale(depthInField: depthInField)
            let effectiveScale = scale * perspectiveFactor

            let crownW = (compact ? 34.0 : 56.0) * effectiveScale
            let crownH = (compact ? 42.0 : 68.0) * effectiveScale
            let trunkW = (compact ? 4.5 : 7.0) * effectiveScale
            let trunkH = (compact ? 16.0 : 25.0) * effectiveScale
            let totalH = crownH + trunkH

            let canopyHalfWidth = crownW * 0.55
            // Deeper trees have a narrower exclusion zone so they sit closer
            // to the path, giving a natural corridor perspective.
            let exclusionHalf = 0.17 - (depthInField * 0.03)
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
            let haze = depthInField * 0.06
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
    /// Row/column-derived — stable across renders so blades cleared by
    /// an advancing reveal fade out individually instead of the whole
    /// field crossfading.
    let id: Int
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
        // Never prompt for location just to tint a cosmetic sky gradient — the
        // fallback coordinate already drives a sensible day/night scene. Only
        // refine the scene if the user has ALREADY granted location for another
        // feature; a brand-new user landing on the Path sees no system prompt.
        switch manager.authorizationStatus {
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
    /// Index into the fixed flower table — stable across renders so
    /// SwiftUI animates insertions instead of replacing the whole field.
    let id: Int
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
