#if canImport(SwiftUI)
import SwiftUI

// MARK: - Lessons Home

/// A curriculum browser with one recommended move above the full catalogue.
/// The store remains the authority for attempts, reviews, and practice passes;
/// this view never turns an opened lesson into visual completion.
@available(iOS 17.0, macOS 12.0, *)
struct LessonsHomeView: View {
    @StateObject private var lessonStore = LessonStore.shared
    @Binding var navigationPath: NavigationPath

    init(navigationPath: Binding<NavigationPath>) {
        self._navigationPath = navigationPath
    }

    init() {
        self._navigationPath = .constant(NavigationPath())
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: Spacing.xl) {
                    header
                    lessonProgressReceipt
                    nextMove
                    curriculumProgress
                    lessonsByCategory
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.xl)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("lessons.screen")
    }

    // MARK: - Focus

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: Spacing.md) {
                NoumSemanticGraphic(role: .learning, tint: AppColor.coachingInk)
                    .accessibilityHidden(true)
                headerCopy
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                NoumSemanticGraphic(role: .learning, tint: AppColor.coachingInk)
                    .accessibilityHidden(true)
                headerCopy
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text("LESSONS")
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(AppColor.coachingInk)
                .tracking(0.8)
            Text("Learn one move. Prove it in speech.")
                .font(Typography.screenTitle)
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Short lessons end with a spoken rep, so progress reflects use rather than reading.")
                .font(Typography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var nextMove: some View {
        if let lesson = lessonStore.nextRecommendedLesson {
            NoumMissionCard(
                eyebrow: recommendedEyebrow(for: lesson),
                title: lesson.title,
                instruction: lesson.tagline,
                metadata: LessonReviewPresentation(progress: lessonStore.progress(for: lesson.id)).rowLabel,
                graphicRole: .learning,
                actionTitle: "Start lesson",
                action: { navigationPath.append(AppDestination.lesson(id: lesson.id)) }
            )
            .accessibilityIdentifier("emptyState.lessons")
        } else {
            NoumSurface(.quiet) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Label("Nothing due right now", systemImage: "checkmark.seal.fill")
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.positive)
                    Text("Use one learned move in a real conversation. Noum will surface a review when it can test retention.")
                        .font(Typography.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityIdentifier("lessons.transferWindow")
        }
    }

    private func recommendedEyebrow(for lesson: Lesson) -> String {
        switch lessonStore.reviewState(for: lesson.id) {
        case .new: return "YOUR NEXT MOVE"
        case .ready: return "REVIEW READY"
        case .waiting: return "KEEP IT FRESH"
        }
    }

    // MARK: - Truth-backed progress

    @ViewBuilder
    private var lessonProgressReceipt: some View {
        if let celebration = lessonStore.pendingCelebration,
           let lesson = LessonsCatalog.lesson(id: celebration.lessonID) {
            NoumSurface(.evidence) {
                HStack(alignment: .top, spacing: Spacing.sm) {
                    NoumSemanticGraphic(role: .verifiedEvidence, tint: AppColor.positive, size: 44)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(celebration.kind.headline)
                            .font(Typography.headline)
                            .foregroundStyle(AppColor.textPrimary)
                        Text("\(lesson.title) · \(LessonProgressPresentation(completedPasses: celebration.practicePassCount).celebrationLine(for: celebration.kind))")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: Spacing.xs)

                    Button("Done") {
                        lessonStore.consumeCelebration()
                    }
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(AppColor.coachingInk)
                    .noumMinimumTouchTarget()
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("lesson.progressReceipt")
        }
    }

    private var curriculumProgress: some View {
        let cleared = LessonsCatalog.all.filter { lessonStore.isCleared($0.id) }.count
        let total = LessonsCatalog.all.count
        let reviewCount = lessonStore.reviewsReadyCount

        return NoumSurface(.quiet) {
            VStack(alignment: .leading, spacing: Spacing.md) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your curriculum")
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Spacer(minLength: Spacing.sm)
                    Text(reviewCount == 0 ? "No reviews due" : "\(reviewCount) due")
                        .font(Typography.caption)
                        .foregroundStyle(reviewCount == 0 ? AppColor.textSecondary : AppColor.coachingInk)
                }

                NoumProgressTrack(
                    value: total == 0 ? 0 : Double(cleared) / Double(total),
                    label: "Skills with a passing spoken rep",
                    valueLabel: "\(cleared) of \(total)",
                    tint: AppColor.coachingInk
                )
            }
        }
    }

    // MARK: - Catalogue

    private var lessonsByCategory: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Text("Explore lessons")
                .font(Typography.cardTitle)
                .foregroundStyle(AppColor.textPrimary)

            ForEach(Lesson.Category.allCases, id: \.self) { category in
                let lessons = LessonsCatalog.all.filter { $0.category == category }
                if !lessons.isEmpty {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(category.label.uppercased())
                            .font(Typography.captionSmall.weight(.bold))
                            .foregroundStyle(AppColor.textSecondary)
                            .tracking(0.7)

                        NoumSurface(.standard) {
                            VStack(spacing: 0) {
                                ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                                    lessonRow(lesson)
                                    if index < lessons.count - 1 {
                                        Divider()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        Button {
            navigationPath.append(AppDestination.lesson(id: lesson.id))
        } label: {
            HStack(alignment: .center, spacing: Spacing.md) {
                Image(systemName: lesson.symbolName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColor.coachingInk)
                    .frame(width: 36, height: 36)
                    .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(lesson.title)
                        .font(Typography.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(lesson.tagline)
                        .font(Typography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(LessonReviewPresentation(progress: lessonStore.progress(for: lesson.id)).rowLabel)
                        .font(Typography.captionSmall.weight(.semibold))
                        .foregroundStyle(lessonStatusColor(for: lesson.id))
                }

                Spacer(minLength: Spacing.xs)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.textTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, Spacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .noumMinimumTouchTarget()
        .accessibilityIdentifier("lessons.row.\(lesson.id)")
    }

    private func lessonStatusColor(for lessonID: String) -> Color {
        switch lessonStore.reviewState(for: lessonID) {
        case .ready: return AppColor.coachingInk
        case .new, .waiting: return AppColor.textSecondary
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Lessons — V3 curriculum") {
    NavigationStack {
        LessonsHomeView()
    }
}
#endif

#endif
