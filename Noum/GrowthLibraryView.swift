#if canImport(SwiftUI)
import SwiftUI

// MARK: - Growth Library
//
// Surfaces the per-account ProofMomentArchive as a browseable timeline.
// Today the archive is invisible to the user — the coach reads it via
// `CoachContextBuilder.userContext`, and the Profile chip surfaces the
// count. This view turns the underlying evidence into something the
// user can scroll through and own: "these are the things you actually
// said that worked."
//
// Restraint contract (VISION anti-goals):
//   • Empty archive renders an honest empty state, never fabricated
//     placeholder quotes.
//   • Quotes are verbatim transcript slices (already enforced by
//     `ProofMomentService.transcriptContains`).
//   • No streak shaming, no "you lost your library" framing on missed
//     days — the library is cumulative evidence, not a daily counter.
//   • No exclamations, no chirpy copy. Sentence case in the body.

@available(iOS 17.0, *)
struct GrowthLibraryView: View {

    @StateObject private var proofStore = ProofMomentStore.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if proofStore.records.isEmpty {
                    emptyState
                } else {
                    header(count: proofStore.records.count)
                    ForEach(weeklyGroups, id: \.weekStart) { group in
                        weekSection(label: group.label, records: group.records)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [AppColor.lightGradientStart, AppColor.lightGradientEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
        .navigationTitle("Growth library")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("growthLibrary.screen")
    }

    private var weeklyGroups: [(weekStart: Date, label: String, records: [ProofMomentRecord])] {
        proofStore.weeklyGroups()
    }

    // MARK: - Header

    @ViewBuilder
    private func header(count: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YOUR EVIDENCE")
                .font(Typography.micro)
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Text(headerHeadline(count: count))
                .font(Typography.sectionHero)
                .foregroundStyle(.primary)
            Text("Verbatim moments your coach has banked from past reps. Quote anchors only — never a paraphrase.")
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func headerHeadline(count: Int) -> String {
        let noun = count == 1 ? "moment" : "moments"
        return "\(count) banked \(noun)"
    }

    // MARK: - Sections

    @ViewBuilder
    private func weekSection(label: String, records: [ProofMomentRecord]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(label.uppercased())
                .font(Typography.micro)
                .tracking(0.8)
                .foregroundStyle(.secondary)
            VStack(spacing: Spacing.cardGap) {
                ForEach(records) { record in
                    proofCard(record: record)
                }
            }
        }
    }

    // MARK: - Quote card

    @ViewBuilder
    private func proofCard(record: ProofMomentRecord) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                techniqueChip(record.proof.technique)
                Spacer(minLength: Spacing.xs)
                Text(relativeDate(record.proof.sessionDate))
                    .font(Typography.captionSmall)
                    .foregroundStyle(.tertiary)
            }

            HStack(alignment: .top, spacing: Spacing.xs) {
                Image(systemName: "quote.opening")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.pro.opacity(0.55))
                Text(record.proof.quote)
                    .font(Typography.body.italic())
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !record.proof.claim.isEmpty {
                Text(record.proof.claim)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 6) {
                Image(systemName: record.proof.isAIBacked ? "sparkles" : "checkmark.seal")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(record.proof.isAIBacked ? AppColor.pro : AppColor.brandBlue)
                Text(record.proof.isAIBacked ? "Coach reading" : "Pattern match")
                    .font(Typography.captionSmall)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(AppColor.pro.opacity(0.16), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(record: record))
    }

    @ViewBuilder
    private func techniqueChip(_ technique: String) -> some View {
        Text(technique.isEmpty ? "Moment" : technique)
            .font(Typography.captionSmall)
            .foregroundStyle(AppColor.pro)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppColor.pro.opacity(0.12), in: Capsule())
    }

    // MARK: - Empty state

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("YOUR EVIDENCE")
                .font(Typography.micro)
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Text("Nothing banked yet")
                .font(Typography.sectionHero)
                .foregroundStyle(.primary)
            Text("After a few reps, your coach starts banking the moments where you did something specific — a clean pause, a triad, a closer. Those land here.")
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: date),
            to: cal.startOfDay(for: Date())
        ).day ?? 0
        switch days {
        case ..<1: return "Today"
        case 1: return "Yesterday"
        case 2...6: return "\(days)d ago"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = cal.component(.year, from: date) == cal.component(.year, from: Date()) ? "MMM d" : "MMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    private func accessibilityLabel(record: ProofMomentRecord) -> String {
        let when = relativeDate(record.proof.sessionDate)
        let tech = record.proof.technique.isEmpty ? "Moment" : record.proof.technique
        let claim = record.proof.claim.isEmpty ? "" : ". \(record.proof.claim)"
        return "\(when), \(tech). You said: \(record.proof.quote)\(claim)"
    }
}

#endif
