#if canImport(SwiftUI)
import SwiftUI

// MARK: - Growth Library (M16)
//
// Persistent on-demand surface that lists every transcript-anchored
// proof moment the coach has banked for this user. Today the proof
// archive feeds three ephemeral surfaces:
//
//   1. `AIWeeklyInsightCard` — one proof of the week, replaced weekly
//   2. `PathNodeCelebration` — one proof on path-node unlock
//   3. `PersonalBestCelebrationScreen` — one proof on PB
//
// Plus the Ask Noum chat reads up to three for its context block.
// None of those let the user *open* the archive — they're each a
// single visible record at a time, mid-flow. The Growth Library is
// the one place the user can re-read every proof the coach has
// noticed, with the actual quote in their own words.
//
// Closes VISION pillar #4 "Believable progress — visible improvement
// across sessions, no fake gamification." Restraint rules:
//
//   • Hidden until the archive has ≥1 record (the Profile entry
//     point already gates on `proofStore.records.count > 0`; the
//     screen tolerates a race where the user wipes the archive
//     after entering and renders an honest empty state).
//   • No counters. No "X insights unlocked" totals. The archive
//     is the artefact, not a number to chase.
//   • Reads straight off the existing `ProofMomentStore.shared` —
//     no new persistence, no migration, no AI calls.
//   • Voice neutral. The library shows the quotes; the coach voice
//     lives on Ask Noum and the celebration surfaces.

@available(iOS 17.0, *)
struct GrowthLibraryView: View {

    @StateObject private var proofStore = ProofMomentStore.shared

    var body: some View {
        ZStack {
            AppColor.screenBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    header
                    if records.isEmpty {
                        emptyState
                    } else {
                        ForEach(records) { record in
                            recordCard(record: record)
                        }
                    }
                    Spacer(minLength: Spacing.lg)
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.top, Spacing.sm)
                .padding(.bottom, Spacing.lg)
            }
        }
        .navigationTitle("Growth library")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("growthLibrary.screen")
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What the coach noticed")
                .font(Typography.bigStat)
                .foregroundStyle(.primary)
            Text("Every moment the coach caught in your own words. Most recent first.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.pro)
                Text("Library waiting")
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(AppColor.pro.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer(minLength: 0)
            }
            Text("Finish a rep with a clear moment and the coach will bank it here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
    }

    /// One persisted proof rendered as a card. Visual register mirrors
    /// `AIWeeklyInsightCard.proofSection(...)` — the same quote-icon
    /// eyebrow, brand-purple technique chip, italic quote, and
    /// secondary claim line. The relative date sits where the "Proof
    /// of the week" kicker lived on the AI card; on the library
    /// every row is a proof, so the date is the differentiator.
    private func recordCard(record: ProofMomentRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "quote.opening")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.pro)
                Text(Self.relativeDateLabel(record.proof.sessionDate))
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(AppColor.pro.opacity(0.85))
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer(minLength: 0)
                Text(record.proof.technique)
                    .font(Typography.micro.weight(.bold))
                    .foregroundStyle(AppColor.pro)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColor.pro.opacity(0.10), in: Capsule())
            }
            Text("\u{201C}\(record.proof.quote)\u{201D}")
                .font(Typography.body.italic())
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            if !record.proof.claim.isEmpty {
                Text(record.proof.claim)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                .stroke(Color.white.opacity(0.72), lineWidth: 1)
        )
        .shadow(color: AppColor.pro.opacity(0.06), radius: 12, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.accessibilityLabel(for: record))
    }

    // MARK: - Derived state

    /// Read most-recent-first via the store's own `recent(limit:)`
    /// helper. The cap matches the store's `maxStoredRecords` so we
    /// never silently truncate.
    private var records: [ProofMomentRecord] {
        proofStore.recent(limit: ProofMomentStore.maxStoredRecords)
    }

    // MARK: - Pure-function helpers (testable)

    /// Whole-day-granularity relative phrasing — matches the recency
    /// idiom used by `ProfileView.insightsBankedChip` so the two
    /// surfaces read in the same voice. Singular / plural agreement
    /// is enforced at every boundary so a single-month-old proof
    /// never reads "1 months ago."
    static func relativeDateLabel(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents(
            [.day],
            from: cal.startOfDay(for: date),
            to: cal.startOfDay(for: now)
        ).day ?? 0
        switch days {
        case ..<1: return "Today"
        case 1: return "1 day ago"
        case 2..<7: return "\(days) days ago"
        case 7..<14: return "1 week ago"
        case 14..<30:
            let weeks = days / 7
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        default:
            let months = days / 30
            return months == 1 ? "1 month ago" : "\(months) months ago"
        }
    }

    /// VoiceOver label flattens the three card slots into one sentence
    /// so an iteration through the library reads coherently.
    static func accessibilityLabel(for record: ProofMomentRecord) -> String {
        var parts: [String] = []
        parts.append(relativeDateLabel(record.proof.sessionDate))
        parts.append("Technique: \(record.proof.technique)")
        parts.append("You said: \(record.proof.quote)")
        if !record.proof.claim.isEmpty {
            parts.append(record.proof.claim)
        }
        return parts.joined(separator: ". ")
    }
}

// MARK: - Preview

#if DEBUG
@available(iOS 17.0, *)
#Preview("Growth library") {
    NavigationStack {
        GrowthLibraryView()
    }
}
#endif

#endif
