#if canImport(SwiftUI)
import SwiftUI

// MARK: - Big Moment Outcome Inline Card
//
// A real-world follow-up after an elapsed Big Moment. This sits inline on
// Home rather than interrupting the user with a sheet, and records only
// user-owned evidence: how it went and how the room seemed to respond.

@available(iOS 17.0, macOS 12.0, *)
struct BigMomentOutcomeInlineCard: View {
    let moment: BigMoment

    @StateObject private var store = BigMomentStore.shared
    @State private var selectedOutcome: ReportedMomentOutcome?
    @State private var selectedResponse: ReportedAudienceResponse?
    @State private var note = ""
    @State private var deferredForNow = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [
        GridItem(.flexible(), spacing: Spacing.xs),
        GridItem(.flexible(), spacing: Spacing.xs),
        GridItem(.flexible(), spacing: Spacing.xs)
    ]

    var body: some View {
        if !deferredForNow {
            VStack(alignment: .leading, spacing: Spacing.md) {
                header
                choices(
                    title: "How it went",
                    values: ReportedMomentOutcome.allCases,
                    selected: selectedOutcome,
                    label: \.chipLabel
                ) { selectedOutcome = $0 }
                choices(
                    title: "Their response",
                    values: ReportedAudienceResponse.allCases,
                    selected: selectedResponse,
                    label: \.chipLabel
                ) { selectedResponse = $0 }

                TextField("A detail your coach should remember (optional)", text: $note, axis: .vertical)
                    .font(Typography.caption)
                    .lineLimit(2...3)
                    .padding(Spacing.sm)
                    .background(
                        AppColor.innerSurface,
                        in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                    )
                    .accessibilityIdentifier("bigMoment.outcome.note")
                    .onChange(of: note) { _, updated in
                        if updated.count > BigMomentOutcomeReport.noteCharacterLimit {
                            note = String(updated.prefix(BigMomentOutcomeReport.noteCharacterLimit))
                        }
                    }

                HStack(spacing: Spacing.sm) {
                    Button("Later") {
                        withAnimation(reduceMotion ? nil : .standardSpring) {
                            deferredForNow = true
                        }
                    }
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.sm)
                    .accessibilityIdentifier("bigMoment.outcome.later")

                    Button {
                        save()
                    } label: {
                        Label("Save check-in", systemImage: "checkmark.circle.fill")
                            .font(Typography.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Spacing.sm)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .background(
                        canSave ? AppColor.brandBlue : Color.secondary.opacity(0.35),
                        in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    )
                    .disabled(!canSave)
                    .accessibilityIdentifier("bigMoment.outcome.save")
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
                    .stroke(AppColor.brandBlue.opacity(0.15), lineWidth: 1)
            )
            .accessibilityIdentifier("home.bigMomentOutcomeCheckIn")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.up.forward.circle.fill")
                    .foregroundStyle(AppColor.brandBlue)
                Text("Real-world follow-up")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            Text("How did \(moment.title) land?")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Your coach uses your read of the room, not just practice scores.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func choices<Value: Identifiable & Equatable>(
        title: String,
        values: [Value],
        selected: Value?,
        label: KeyPath<Value, String>,
        onSelect: @escaping (Value) -> Void
    ) -> some View where Value.ID == String {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title)
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            LazyVGrid(columns: columns, spacing: Spacing.xs) {
                ForEach(values) { value in
                    let isSelected = selected == value
                    Button {
                        CoachHaptic.selectionTap()
                        onSelect(value)
                    } label: {
                        Text(value[keyPath: label])
                            .font(Typography.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? AppColor.brandBlue : .primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 38)
                            .padding(.horizontal, 4)
                            .background(
                                isSelected ? AppColor.brandBlue.opacity(0.09) : AppColor.innerSurface,
                                in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                                    .stroke(isSelected ? AppColor.brandBlue.opacity(0.3) : Color.clear, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bigMoment.outcome.choice.\(value.id)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private var canSave: Bool {
        selectedOutcome != nil && selectedResponse != nil
    }

    private func save() {
        guard let selectedOutcome, let selectedResponse else { return }
        if let report = store.recordOutcome(
            for: moment,
            outcome: selectedOutcome,
            audienceResponse: selectedResponse,
            note: note
        ) {
            CoachMemoryStore.shared.noteTransferOutcome(report)
        }
        CoachHaptic.selectionTap()
    }
}

#if DEBUG
@available(iOS 17.0, macOS 12.0, *)
#Preview {
    BigMomentOutcomeInlineCard(
        moment: BigMoment(title: "Board presentation", category: .presentation)
    )
    .padding()
}
#endif
#endif
