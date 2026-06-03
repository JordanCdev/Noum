#if canImport(SwiftUI)
import SwiftUI

// MARK: - Weekly Check-In (F1 — Formulation, coach-parity stage 2)
//
// The Profile coaching-cluster entry to the weekly check-in: a human coach
// asks questions, and these ANSWERS become durable context. The card shows
// only when the cadence is DUE (no-nag — once a week, never twice; hidden
// otherwise). Tapping opens a calm sheet with three short, OPTIONAL questions;
// saving records a CoachCheckIn that feeds the coach context. An all-empty
// submission is a no-op (the store refuses a hollow "checked in").

struct WeeklyCheckInCard: View {
    @ObservedObject var store: CoachCheckInStore
    @State private var showingSheet = false

    var body: some View {
        // Self-guard on cadence so the card is inert when not due, even if a
        // caller forgets to gate. ProfileView also gates, so this is belt-and-
        // braces, not the only check.
        if store.isCheckInDue() {
            Button {
                showingSheet = true
            } label: {
                cardBody
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.weeklyCheckIn.start")
            .accessibilityLabel("Start your weekly coach check-in")
            .sheet(isPresented: $showingSheet) {
                WeeklyCheckInSheet(store: store)
            }
        }
    }

    private var cardBody: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "bubble.left.and.text.bubble.right")
                .font(.title3)
                .foregroundStyle(AppColor.pro)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("Weekly check-in")
                    .font(Typography.cardLabel)
                    .foregroundStyle(.primary)
                Text("A few quick questions for your coach — what was hardest, where it showed up, and whether the drill is working.")
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

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.screenBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Spacing.lg) {
                        header
                        question(
                            "What felt hardest this week?",
                            placeholder: "A moment, a pattern, a feeling…",
                            text: $hardest,
                            id: "hardest"
                        )
                        question(
                            "Where did this show up outside the app?",
                            placeholder: "A meeting, a call, a conversation…",
                            text: $outsideApp,
                            id: "outsideApp"
                        )
                        drillVerdictSection
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
                    Button("Not now") { dismiss() }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("weeklyCheckIn.skip")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        store.record(
                            hardest: hardest.nilIfBlank,
                            outsideApp: outsideApp.nilIfBlank,
                            drillVerdict: drillVerdict
                        )
                        dismiss()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(canSave ? AppColor.brandBlue : Color.secondary)
                    .disabled(!canSave)
                    .accessibilityIdentifier("weeklyCheckIn.save")
                }
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Weekly check-in")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            Text("Answer what's useful — every field is optional. Your coach uses these to ask sharper questions and adapt the plan.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, Spacing.sm)
    }

    private func question(_ prompt: String, placeholder: String, text: Binding<String>, id: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel(prompt)
            TextField(placeholder, text: text, axis: .vertical)
                .font(.subheadline)
                .padding(Spacing.md)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
                .lineLimit(2...4)
                .accessibilityIdentifier("weeklyCheckIn.field.\(id)")
        }
    }

    private var drillVerdictSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            sectionLabel("Is the current drill working?")
            HStack(spacing: Spacing.sm) {
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
                .foregroundStyle(isSelected ? AppColor.brandBlue : .secondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity)
                .background(
                    isSelected ? AppColor.brandBlue.opacity(0.08) : AppColor.cardBackground,
                    in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous)
                        .strokeBorder(isSelected ? AppColor.brandBlue.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("weeklyCheckIn.verdict.\(verdict.rawValue)")
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var canSave: Bool {
        hardest.nilIfBlank != nil || outsideApp.nilIfBlank != nil || drillVerdict != nil
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
