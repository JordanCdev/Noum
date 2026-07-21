#if canImport(SwiftUI)
import SwiftUI

// MARK: - Weekly Check-In (F1 — Formulation, coach-parity stage 2)
//
// The Profile coaching-cluster entry to the weekly check-in: a human coach
// asks questions, and these ANSWERS become durable context. The card shows
// only when the cadence is DUE (no-nag — once a week, never twice; hidden
// otherwise). Tapping opens a calm sheet with short, OPTIONAL questions;
// saving records a CoachCheckIn that feeds the coach context. An all-empty
// submission is a no-op (the store refuses a hollow "checked in").

struct WeeklyCheckInPrompt: Equatable, Identifiable {
    let id: String
    let title: String
    let helper: String
    let placeholder: String
}

enum WeeklyCheckInCopy {
    static let cardTitle = "Your weekly read"
    static let cardBody = "A quick check-in for what metrics miss."
    static let sheetTitle = "What should Noum know?"
    static let sheetBody = "Choose one answer. Add detail only if it helps."
    static let noteTitle = "Your words, not a score"
    static let noteBody = "One honest answer is enough to help Noum shape the next question."

    static let hardest = WeeklyCheckInPrompt(
        id: "hardest",
        title: "What felt hard?",
        helper: "A moment or feeling you kept noticing.",
        placeholder: "I tightened up when..."
    )

    static let outsideApp = WeeklyCheckInPrompt(
        id: "outsideApp",
        title: "Where did it show up?",
        helper: "A real conversation, meeting, call, pitch, or conflict.",
        placeholder: "In my..."
    )

    static let avoidedSaying = WeeklyCheckInPrompt(
        id: "avoidedSaying",
        title: "What did you avoid saying?",
        helper: "Only if something stayed unsaid.",
        placeholder: "I avoided saying..."
    )

    static let confidenceQuestion = "How steady did you feel?"
    static let confidenceHelper = "Use your own read of the moment."
    static let drillQuestion = "Did the drill still fit?"
    static let drillHelper = "Noum can keep this exercise or choose another."
}

struct WeeklyCheckInCard: View {
    @ObservedObject var store: CoachCheckInStore

    var body: some View {
        // Self-guard on cadence so the card is inert when not due, even if a
        // caller forgets to gate. ProfileView also gates, so this is belt-and-
        // braces, not the only check.
        if store.isCheckInDue() {
            NavigationLink {
                WeeklyCheckInSheet(store: store)
            } label: {
                cardBody
            }
            .buttonStyle(.pressable)
            .accessibilityIdentifier("profile.weeklyCheckIn.start")
            .accessibilityLabel("Start your weekly coach check-in")
        }
    }

    private var cardBody: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.title3)
                .foregroundStyle(AppColor.pro)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(WeeklyCheckInCopy.cardTitle)
                    .font(Typography.cardLabel)
                    .foregroundStyle(.primary)
                Text(WeeklyCheckInCopy.cardBody)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(Typography.caption)
                .foregroundStyle(.tertiary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
    }
}

// MARK: - Sheet

struct WeeklyCheckInSheet: View {
    @ObservedObject var store: CoachCheckInStore
    @Environment(\.dismiss) private var dismiss

    @State private var hardest: String = ""
    @State private var outsideApp: String = ""
    @State private var drillVerdict: CoachDrillVerdict? = nil
    @State private var confidenceShift: CoachConfidenceShift? = nil
    @State private var avoidedSaying: String = ""
    @State private var showsMoreContext = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    coachNote
                    confidenceSection
                    question(
                        WeeklyCheckInCopy.hardest,
                        text: $hardest,
                    )

                    moreContextButton

                    if showsMoreContext {
                        VStack(alignment: .leading, spacing: Spacing.lg) {
                            question(
                                WeeklyCheckInCopy.outsideApp,
                                text: $outsideApp,
                            )
                            question(
                                WeeklyCheckInCopy.avoidedSaying,
                                text: $avoidedSaying,
                            )
                            drillVerdictSection
                        }
                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                    }

                    if !canSave {
                        Label("Choose one option or write one line to save.", systemImage: "info.circle")
                            .font(Typography.caption)
                            .foregroundStyle(AppColor.textSecondary)
                            .accessibilityIdentifier("weeklyCheckIn.saveGuidance")
                    }
                    Spacer(minLength: Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.md)
                .padding(.bottom, Spacing.lg)
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider()
                PrimaryCTA("Save reflection", tint: AppColor.brandBlue) {
                    save()
                }
                .disabled(!canSave)
                .opacity(canSave ? 1 : 0.45)
                .accessibilityIdentifier("weeklyCheckIn.save")
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.sm)
            }
            .background(.regularMaterial)
        }
        .navigationTitle("Weekly check-in")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColor.screenBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .accessibilityIdentifier("weeklyCheckIn.sheet")
    }

    private func save() {
        guard canSave else { return }
        store.record(
            hardest: hardest.nilIfBlank,
            outsideApp: outsideApp.nilIfBlank,
            drillVerdict: drillVerdict,
            confidenceShift: confidenceShift,
            avoidedSaying: avoidedSaying.nilIfBlank
        )
        dismiss()
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(WeeklyCheckInCopy.sheetTitle)
                .font(Typography.sectionHero)
                .foregroundStyle(.primary)
            Text(WeeklyCheckInCopy.sheetBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.sm)
    }

    private var coachNote: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "quote.bubble.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.pro)
                .frame(width: 24, height: 24)
                .background(AppColor.pro.opacity(0.10), in: Circle())

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(WeeklyCheckInCopy.noteTitle)
                    .font(Typography.caption)
                    .foregroundStyle(.primary)
                Text(WeeklyCheckInCopy.noteBody)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.pro.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func question(_ prompt: WeeklyCheckInPrompt, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(prompt.title)
                    .font(Typography.cardLabel)
                    .foregroundStyle(.primary)
                Text(prompt.helper)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            TextField(prompt.placeholder, text: text, axis: .vertical)
                .font(.subheadline)
                .padding(Spacing.md)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .lineLimit(2...4)
                .accessibilityIdentifier("weeklyCheckIn.field.\(prompt.id)")
        }
    }

    private var confidenceSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel(WeeklyCheckInCopy.confidenceQuestion, helper: WeeklyCheckInCopy.confidenceHelper)
            FlowLayout(spacing: Spacing.sm, runSpacing: Spacing.sm) {
                ForEach(CoachConfidenceShift.allCases) { shift in
                    confidenceChip(shift)
                }
            }
        }
    }

    private var moreContextButton: some View {
        Button {
            if reduceMotion {
                showsMoreContext.toggle()
            } else {
                withAnimation(.easeInOut(duration: 0.22)) {
                    showsMoreContext.toggle()
                }
            }
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "text.badge.plus")
                    .foregroundStyle(AppColor.brandBlue)
                Text(showsMoreContext ? "Show fewer questions" : "Add more context")
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.brandBlue)
                Spacer(minLength: 0)
                Image(systemName: showsMoreContext ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("weeklyCheckIn.moreContext")
    }

    private func confidenceChip(_ shift: CoachConfidenceShift) -> some View {
        let isSelected = confidenceShift == shift
        return Button {
            confidenceShift = isSelected ? nil : shift
            CoachHaptic.selectionTap()
        } label: {
            Text(shift.chipLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? AppColor.pro : AppColor.textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    isSelected ? AppColor.pro.opacity(0.08) : AppColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .strokeBorder(isSelected ? AppColor.pro.opacity(0.3) : AppColor.subtleBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("weeklyCheckIn.confidence.\(shift.rawValue)")
    }

    private var drillVerdictSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel(WeeklyCheckInCopy.drillQuestion, helper: WeeklyCheckInCopy.drillHelper)
            FlowLayout(spacing: Spacing.sm, runSpacing: Spacing.sm) {
                ForEach(CoachDrillVerdict.allCases) { verdict in
                    verdictChip(verdict)
                }
            }
        }
    }

    private func verdictChip(_ verdict: CoachDrillVerdict) -> some View {
        let isSelected = drillVerdict == verdict
        return Button {
            // Tapping the selected chip clears it (keeps the field optional).
            drillVerdict = isSelected ? nil : verdict
            CoachHaptic.selectionTap()
        } label: {
            Text(verdict.chipLabel)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isSelected ? AppColor.brandBlue : AppColor.textPrimary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .fixedSize(horizontal: true, vertical: false)
                .background(
                    isSelected ? AppColor.brandBlue.opacity(0.08) : AppColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .strokeBorder(isSelected ? AppColor.brandBlue.opacity(0.3) : AppColor.subtleBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("weeklyCheckIn.verdict.\(verdict.rawValue)")
    }

    private func sectionLabel(_ text: String, helper: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(text)
                .font(Typography.cardLabel)
                .foregroundStyle(.primary)
            Text(helper)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var canSave: Bool {
        hardest.nilIfBlank != nil
            || outsideApp.nilIfBlank != nil
            || drillVerdict != nil
            || confidenceShift != nil
            || avoidedSaying.nilIfBlank != nil
    }
}

private extension String {
    /// nil when the string is empty or whitespace-only, else self. Keeps the
    /// store's optional fields honestly optional (no empty-string records).
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
#endif
