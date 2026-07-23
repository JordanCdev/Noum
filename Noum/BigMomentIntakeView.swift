#if canImport(SwiftUI)
import SwiftUI

// MARK: - Per-type chip colour

extension BigMomentCategory {
    /// Distinct chip colour per moment type (docs/UX_VISUAL_DIRECTION.md —
    /// white cards with per-concept coloured icon chips; semantic colour,
    /// consistently). All AppColor tokens, no hex literals in the view.
    var chipTint: Color {
        switch self {
        case .presentation:   return AppColor.brandBlue      // work/coach blue
        case .interview:      return AppColor.pro            // violet
        case .review:         return AppColor.caution        // amber
        case .conversation:   return AppColor.positive       // green
        case .publicSpeaking: return AppColor.modeCrutch     // warm rose
        case .other:          return AppColor.textSecondary  // quiet slate
        }
    }
}

// MARK: - Prefill

/// Pure prefill resolver for the intake sheet — preselects the TYPE only.
/// Never invents a title or a date: those stay user-authored (an empty
/// name field keeps Save disabled exactly as before).
enum BigMomentIntakePrefill {
    /// Priority:
    /// 1. The active moment's own category — re-entry from Settings or the
    ///    deep link is a revisit of the user's explicit prior choice.
    /// 2. The coaching profile's stated speaking context — a soft hint from
    ///    onboarding ("Interviews" → Interview). Work conversations and
    ///    everyday confidence both land nearest "Conversation".
    /// 3. The historical default (`.presentation`) when neither exists.
    static func category(
        activeMoment: BigMoment?,
        profile: CoachingProfile?
    ) -> BigMomentCategory {
        if let activeMoment { return activeMoment.category }
        switch profile?.speakingContext {
        case .interviews:    return .interview
        case .presentations: return .presentation
        case .work, .social: return .conversation
        case nil:            return .presentation
        }
    }
}

// MARK: - Intake sheet

@available(iOS 17.0, macOS 12.0, *)
struct BigMomentIntakeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var store = BigMomentStore.shared

    @State private var selectedCategory: BigMomentCategory
    @State private var title: String = ""
    @State private var includeDate: Bool = false
    @State private var selectedDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()
    @State private var didComplete = false
    @FocusState private var titleFieldFocused: Bool

    var onSave: (() -> Void)?
    var onSkip: (() -> Void)?

    @MainActor
    init(onSave: (() -> Void)? = nil, onSkip: (() -> Void)? = nil) {
        self.onSave = onSave
        self.onSkip = onSkip
        _selectedCategory = State(initialValue: BigMomentIntakePrefill.category(
            activeMoment: BigMomentStore.shared.activeMoment,
            profile: CoachingProfileStore.shared.profile
        ))
    }

    var body: some View {
        ZStack {
            AppColor.screenBackground
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    headerSection
                    categorySection
                    titleSection
                    dateSection
                    Spacer(minLength: Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.lg)
            }
        }
        .safeAreaInset(edge: .bottom) {
            PrimaryCTA("Save moment", tint: AppColor.brandBlue) {
                saveAndDismiss()
            }
            .disabled(!canSave)
            .accessibilityIdentifier("bigMoment.intake.save")
            .padding(.horizontal, Spacing.screenH)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.sm)
            .background {
                LinearGradient(
                    colors: [
                        AppColor.screenBackground.opacity(0),
                        AppColor.screenBackground,
                        AppColor.screenBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .navigationTitle("Prepare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColor.screenBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .interactiveDismissDisabled(false)
        .onDisappear {
            if !didComplete {
                onSkip?()
            }
        }
        .accessibilityIdentifier("bigMoment.intake")
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Prepare for a real moment")
                .font(Typography.figtree(size: 24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(.primary)
            Text("Tell Noum what’s coming up so your next reps can prepare you.")
                .font(Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.sm)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Type")
            VStack(spacing: Spacing.xs) {
                ForEach(BigMomentCategory.allCases, id: \.rawValue) { category in
                    categoryCard(category)
                }
            }
        }
    }

    private func categoryCard(_ category: BigMomentCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            guard selectedCategory != category else { return }
            if reduceMotion {
                selectedCategory = category
            } else {
                withAnimation(.snappySpring) { selectedCategory = category }
            }
            CoachHaptic.selectionTap()
        } label: {
            HStack(spacing: Spacing.sm) {
                // Gradient-tinted rounded-square icon chip — the same
                // 36pt chip register as the Profile rows / verdict cards.
                Image(systemName: category.sfSymbol)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(
                        category.chipTint.gradient,
                        in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    )
                    .accessibilityHidden(true)

                Text(category.title)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)

                Spacer(minLength: Spacing.xs)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isSelected ? AppColor.brandBlue : AppColor.textSecondary.opacity(0.30))
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs + 2)
            .background(
                // Selected = subtle brand tint OVER the white card — never
                // a full blue fill (calm premium, per the approved pass).
                ZStack {
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(AppColor.cardBackground)
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .fill(AppColor.brandBlue.opacity(isSelected ? 0.05 : 0))
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppColor.brandBlue.opacity(0.65) : AppColor.subtleBorder,
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.pressable)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("bigMoment.intake.category.\(category.rawValue)")
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("Name it")
                Spacer(minLength: Spacing.sm)
                Text("Required")
                    .font(Typography.captionSmall.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
            }
            TextField("What's coming up?", text: $title, axis: .vertical)
                .font(Typography.subheadline)
                .focused($titleFieldFocused)
                .padding(Spacing.md)
                .background(
                    AppColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .strokeBorder(
                            titleFieldFocused ? AppColor.brandBlue.opacity(0.65) : AppColor.subtleBorder,
                            lineWidth: titleFieldFocused ? 1.5 : 1
                        )
                )
                .lineLimit(2...4)
                .accessibilityIdentifier("bigMoment.intake.title")

            if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Give this moment a short name to save it.")
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityIdentifier("bigMoment.intake.titleGuidance")
            }
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("When is it?")

            Button {
                if reduceMotion {
                    includeDate.toggle()
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        includeDate.toggle()
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    // Quiet slate chip — the date is supporting detail, not
                    // a concept of its own (grey-chip register from the
                    // direction doc's quiet rows).
                    Image(systemName: "calendar")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            AppColor.textSecondary.gradient,
                            in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(includeDate ? "Date added" : "Add a date")
                            .font(Typography.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                        if includeDate {
                            Text(selectedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(Typography.caption)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }

                    Spacer(minLength: Spacing.xs)

                    Image(systemName: includeDate ? "minus.circle" : "plus.circle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                        .accessibilityHidden(true)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs + 2)
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .strokeBorder(AppColor.subtleBorder, lineWidth: 1)
            )

            if includeDate {
                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .tint(AppColor.brandBlue)
                .padding(Spacing.sm)
                .background(
                    AppColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                        .strokeBorder(AppColor.subtleBorder, lineWidth: 1)
                )
                .accessibilityIdentifier("bigMoment.intake.date")
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .microLabel()
    }

    // MARK: - Logic

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func saveMoment() {
        let moment = BigMoment(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            date: includeDate ? selectedDate : nil,
            category: selectedCategory
        )
        store.setMoment(moment)
        // Arm the moment's notification spine (T-7 / T-1 countdown + the
        // day-after check-in). Authorization is checked passively inside —
        // this never triggers the hard system prompt (the soft pre-prompt
        // sheet owns asks). If the user authorizes later, the launch
        // refresh pass re-arms the active moment.
        Task {
            await NotificationManager.shared.scheduleBigMomentCountdown(for: moment)
        }
    }

    private func saveAndDismiss() {
        guard canSave else { return }
        saveMoment()
        didComplete = true
        onSave?()
        dismiss()
    }
}

#if DEBUG
@available(iOS 17.0, macOS 12.0, *)
#Preview {
    BigMomentIntakeView()
}
#endif
#endif
