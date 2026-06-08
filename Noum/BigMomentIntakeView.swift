#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 12.0, *)
struct BigMomentIntakeView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = BigMomentStore.shared

    @State private var selectedCategory: BigMomentCategory = .presentation
    @State private var title: String = ""
    @State private var includeDate: Bool = false
    @State private var selectedDate: Date = Calendar.current.date(byAdding: .day, value: 30, to: Date()) ?? Date()

    var onSave: (() -> Void)?
    var onSkip: (() -> Void)?

    var body: some View {
        NavigationStack {
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip for now") {
                        onSkip?()
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("bigMoment.intake.skip")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveMoment()
                        onSave?()
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(canSave ? AppColor.brandBlue : Color.secondary)
                    .disabled(!canSave)
                    .accessibilityIdentifier("bigMoment.intake.save")
                }
            }
            .interactiveDismissDisabled(false)
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("What's coming up?")
                .font(Typography.figtree(size: 24, weight: .bold, relativeTo: .title2))
                .foregroundStyle(.primary)
            Text("Name the moment so your coach can help you prepare for it.")
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
                    categoryRow(category)
                }
            }
        }
    }

    private func categoryRow(_ category: BigMomentCategory) -> some View {
        let isSelected = selectedCategory == category
        return Button {
            selectedCategory = category
            CoachHaptic.selectionTap()
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: category.sfSymbol)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? AppColor.brandBlue : .secondary)
                    .frame(width: 24)

                Text(category.title)
                    .font(Typography.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? .primary : .secondary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.brandBlue)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                isSelected
                    ? AppColor.brandBlue.opacity(0.08)
                    : AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    .strokeBorder(
                        isSelected ? AppColor.brandBlue.opacity(0.3) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bigMoment.intake.category.\(category.rawValue)")
    }

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Name it")
            TextField("What's coming up?", text: $title, axis: .vertical)
                .font(.subheadline)
                .padding(Spacing.md)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .lineLimit(2...4)
                .accessibilityIdentifier("bigMoment.intake.title")
        }
    }

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("When is it?")

            Toggle(isOn: $includeDate.animation(.easeInOut(duration: 0.2))) {
                Text("Add a date")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
            }
            .tint(AppColor.brandBlue)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

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
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                .accessibilityIdentifier("bigMoment.intake.date")
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.6)
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
    }
}

#if DEBUG
@available(iOS 17.0, macOS 12.0, *)
#Preview {
    BigMomentIntakeView()
}
#endif
#endif
