#if canImport(SwiftUI)
import SwiftUI

// MARK: - Peak Rating Wall (M6)
//
// Surfaces three "best" framings without faking ranks:
//   • Best ever — `SpeakingRating.peakRating`
//   • Best this week — `SpeakingRating.weekPeakRating` (resets every ISO week)
//   • Best in friends — max `lastKnownPeakRating` across friends with linked
//     accounts; `nil` (Awaiting sync) when no friend has been synced yet.
//
// Honest empty states: when no peer data exists (no friends linked to
// accounts, or Firestore rules not yet deployed), the friends row says
// "Awaiting sync" rather than showing zero. We never invent a comparison.
//
// Ratings are read live from RatingStore + FriendsManager so the card
// stays in sync as new sessions land.
@available(iOS 17.0, *)
struct PeakRatingWallCard: View {
    @StateObject private var ratingStore = RatingStore.shared
    @StateObject private var friendsManager = FriendsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppColor.brandBlue)
                Text("Peak rating")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
            }

            VStack(spacing: 10) {
                row(
                    label: "Best ever",
                    value: "\(ratingStore.rating.peakRating)",
                    accent: AppColor.brandBlue,
                    badge: bestEverBadge
                )

                row(
                    label: "Best this week",
                    value: weekPeakDisplay,
                    accent: weekPeakAccent,
                    badge: weekPeakBadge
                )

                row(
                    label: "Best in friends",
                    value: friendsPeakDisplay,
                    accent: friendsAccent,
                    badge: friendsBadge
                )
            }
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
    }

    // MARK: - Row builder

    private func row(label: String, value: String, accent: Color, badge: String?) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let badge {
                Text(badge)
                    .font(Typography.micro)
                    .foregroundStyle(accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(accent.opacity(0.14), in: Capsule())
            }

            Text(value)
                .font(Typography.bigStat)
                .foregroundStyle(accent)
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(rawNumeric(value))))
        }
    }

    // MARK: - Best this week

    private var weekPeakDisplay: String {
        guard ratingStore.rating.isWeekPeakCurrent else { return "—" }
        return "\(ratingStore.rating.weekPeakRating)"
    }

    private var weekPeakAccent: Color {
        guard ratingStore.rating.isWeekPeakCurrent else { return .secondary }
        let current = ratingStore.rating.overall
        return ratingStore.rating.weekPeakRating > current ? AppColor.brandBlue : .primary
    }

    private var weekPeakBadge: String? {
        guard ratingStore.rating.isWeekPeakCurrent else { return "Resets at week start" }
        return nil
    }

    // MARK: - Best ever badge

    private var bestEverBadge: String? {
        let current = ratingStore.rating.overall
        let peak = ratingStore.rating.peakRating
        // If user is currently at their all-time peak, surface that — it's the
        // moment worth celebrating. Otherwise no badge keeps the card calm.
        return current >= peak && peak > 400 ? "Now" : nil
    }

    // MARK: - Best in friends

    private var friendsPeakDisplay: String {
        guard let max = friendPeakMax else { return "Awaiting sync" }
        return "\(max.peak)"
    }

    private var friendsAccent: Color {
        guard let max = friendPeakMax else { return .secondary }
        return max.peak >= ratingStore.rating.peakRating ? .orange : .primary
    }

    private var friendsBadge: String? {
        guard let max = friendPeakMax else {
            return friendsManager.friends.isEmpty ? nil : "No linked friends"
        }
        if max.peak > ratingStore.rating.peakRating {
            return max.name
        }
        if max.peak < ratingStore.rating.peakRating {
            return "You lead"
        }
        return "Tied with \(max.name)"
    }

    private var friendPeakMax: (peak: Int, name: String)? {
        let withPeaks: [(peak: Int, name: String)] = friendsManager.friends.compactMap { friend in
            guard let peak = friend.lastKnownPeakRating else { return nil }
            return (peak, friend.displayName)
        }
        return withPeaks.max(by: { $0.peak < $1.peak })
    }

    // MARK: - Helpers

    private func rawNumeric(_ s: String) -> Int {
        Int(s.filter(\.isNumber)) ?? 0
    }
}

// MARK: - Preview

#Preview {
    PeakRatingWallCard()
        .padding()
        .background(AppColor.screenBackground)
}

#endif
