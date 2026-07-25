#if canImport(SwiftUI)
import SwiftUI
import UIKit

// MARK: - Shareable Session Card
//
// A render-only card sized for iMessage / Twitter / Stories. The user taps
// "Share rep" on the summary, this card snapshots itself, and the system
// share sheet opens with the resulting image.
//
// Design: bold gradient, big score, three stats, no transcript (privacy).
// The user controls what they share — the card never includes the spoken
// content, only the shape of the rep.

@available(iOS 17.0, macOS 12.0, *)
struct ShareableSessionCard: View {
    let session: PracticeSession
    let displayName: String
    let rating: Int
    /// Recent session scores in chronological order (oldest → newest),
    /// up to 5. The final entry is the rep being shared. Defaults to
    /// reading from `PracticeSessionStore.shared` so callers don't
    /// have to plumb it through, but injectable so the render path
    /// and tests can pass deterministic data.
    let recentScores: [Int]
    /// Friends with a known peak rating, top 3 by peak. Empty array
    /// hides the friends section entirely (no "no friends yet" empty
    /// state — calm-restrained per CLAUDE.md).
    let friendsPeak: [FriendPeak]

    struct FriendPeak: Identifiable, Equatable {
        let id: UUID
        let displayName: String
        let initials: String
        let peakRating: Int
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColor.brandBlue, AppColor.brandBlueLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Soft white orbs for depth — reuses the splash motif.
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 22)
                .offset(x: 90, y: -120)
            Circle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 180, height: 180)
                .blur(radius: 22)
                .offset(x: -110, y: 140)

            VStack(alignment: .leading, spacing: 18) {
                wordmark
                Spacer(minLength: 0)
                headline
                statsRow
                if !recentScores.isEmpty {
                    historySection
                }
                if !friendsPeak.isEmpty {
                    friendsSection
                }
                footer
            }
            .padding(28)
        }
        .frame(width: 360, height: 600)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: - Subviews

    private var wordmark: some View {
        HStack {
            Text("noum")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .tracking(1.2)
            Spacer()
            Text("Speaking rating")
                .font(Typography.micro)
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.8)
            Text("\(rating)")
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headlineTitle)
                .font(.system(size: 38, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(modeLabel)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(value: scoreText, label: "Score")
            statTile(value: fillerText, label: "Fillers")
            statTile(value: durationText, label: "Time")
        }
    }

    /// Last N reps as a row of score chips with the current session
    /// emphasised. Reads cleaner than a sparkline at this card width
    /// because each score stays legible and the rep-count is explicit.
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Last \(recentScores.count) reps")
                .font(Typography.micro)
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.8)
            HStack(spacing: 8) {
                ForEach(Array(recentScores.enumerated()), id: \.offset) { index, score in
                    historyChip(score: score, isCurrent: index == recentScores.count - 1)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func historyChip(score: Int, isCurrent: Bool) -> some View {
        Text("\(score)")
            .font(.system(size: isCurrent ? 18 : 16, weight: isCurrent ? .bold : .semibold, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(isCurrent ? 1.0 : 0.78))
            .frame(width: 38, height: 38)
            .background(
                Circle()
                    .fill(Color.white.opacity(isCurrent ? 0.22 : 0.10))
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(isCurrent ? 0.55 : 0.18), lineWidth: isCurrent ? 1.5 : 1)
            )
    }

    /// Top friends by peak rating. Privacy posture: name + initials +
    /// peak rating only. No streak, no recent rep, no transcript.
    private var friendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Friends' best")
                .font(Typography.micro)
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.8)
            VStack(spacing: 6) {
                ForEach(friendsPeak) { friend in
                    friendRow(friend: friend)
                }
            }
        }
    }

    private func friendRow(friend: FriendPeak) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: 28, height: 28)
                Text(friend.initials)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            Text(friend.displayName)
                .font(Typography.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(friend.peakRating)")
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(Typography.micro)
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Image(systemName: "waveform.and.mic")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            Text(displayName.isEmpty ? "Speaker" : displayName)
                .font(Typography.caption.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            Text("Sharper speaking, one rep at a time.")
                .font(Typography.caption)
                .foregroundStyle(.white.opacity(0.78))
        }
    }

    // MARK: - Formatters

    private var headlineTitle: String {
        guard let score = session.score else { return "Clean rep" }
        switch score {
        case 9...: return "Standout rep"
        case 7...8: return "Strong rep"
        case 5...6: return "Solid rep"
        case 3...4: return "Building"
        default:    return "First rep"
        }
    }

    private var modeLabel: String {
        switch session.mode {
        case .timed:
            if let difficulty = session.practiceDemand?.timedDifficulty,
               session.practiceDemand?.isValid(for: .timed) == true {
                return "TIMED PRACTICE · \(difficulty.title.uppercased())"
            }
            return "TIMED PRACTICE"
        case .suddenDeath:    return "PRESSURE DRILL"
        case .ahCounter:      return "FILLER CONTROL"
        case .imConversation: return "CONVERSATION PRACTICE"
        }
    }

    private var scoreText: String {
        guard let score = session.score else { return "—" }
        return "\(score)"
    }

    private var fillerText: String {
        "\(session.fillerWordCount)"
    }

    private var durationText: String {
        let seconds = Int(session.duration)
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        let remainder = seconds % 60
        return remainder == 0 ? "\(minutes)m" : "\(minutes)m \(remainder)s"
    }
}

// MARK: - Data assembly

@available(iOS 17.0, macOS 12.0, *)
extension ShareableSessionCard {
    /// Pull the trailing N scores from the given store, oldest → newest,
    /// with the just-shared session pinned to the end. Sessions without a
    /// score (rare — short reps that never got rated) are skipped so the
    /// chip row never renders a dash.
    @MainActor
    static func recentScores(forSession session: PracticeSession,
                             store: PracticeSessionStore,
                             limit: Int = 5) -> [Int] {
        // Store is newest-first. Reverse to chronological, ensure the
        // shared session is the final entry even if it hasn't persisted
        // yet (the share button can fire mid-save).
        var ordered: [PracticeSession] = store.sessions.reversed()
        if !ordered.contains(where: { $0.id == session.id }) {
            ordered.append(session)
        }
        let tail = Array(ordered.suffix(limit))
        return tail.compactMap(\.score)
    }

    /// Convenience overload that reads from the shared store.
    @MainActor
    static func recentScores(forSession session: PracticeSession, limit: Int = 5) -> [Int] {
        recentScores(forSession: session, store: .shared, limit: limit)
    }

    /// Top friends by peak rating, capped at `limit`. Friends without a
    /// known peak are excluded — sharing a "—" alongside real numbers
    /// reads as noise. Returns empty when the friend list itself is
    /// empty or has no synced peaks yet, which collapses the section
    /// in the card.
    nonisolated static func topFriendsPeak(
        friends: [NoumFriend],
        limit: Int = 3
    ) -> [FriendPeak] {
        friends
            .compactMap { friend -> FriendPeak? in
                guard let peak = friend.lastKnownPeakRating else { return nil }
                return FriendPeak(
                    id: friend.id,
                    displayName: friend.displayName,
                    initials: friend.initials,
                    peakRating: peak
                )
            }
            .sorted { $0.peakRating > $1.peakRating }
            .prefix(limit)
            .map { $0 }
    }

    @MainActor
    static func topFriendsPeak(manager: FriendsManager, limit: Int = 3) -> [FriendPeak] {
        topFriendsPeak(friends: manager.friends, limit: limit)
    }

    /// Convenience overload that reads from the shared manager.
    @MainActor
    static func topFriendsPeak(limit: Int = 3) -> [FriendPeak] {
        topFriendsPeak(manager: .shared, limit: limit)
    }
}

// MARK: - UIImage rendering

@available(iOS 17.0, *)
extension ShareableSessionCard {
    /// Render the card to a UIImage at 2× scale. Used by the share sheet.
    /// Pulls recent scores + friends' best peaks from the live stores.
    @MainActor
    static func render(session: PracticeSession, displayName: String, rating: Int) -> UIImage? {
        let recent = recentScores(forSession: session)
        let friends = topFriendsPeak()
        let renderer = ImageRenderer(content: ShareableSessionCard(
            session: session,
            displayName: displayName,
            rating: rating,
            recentScores: recent,
            friendsPeak: friends
        ))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Share card — strong rep") {
    ShareableSessionCard(
        session: PracticeSession(
            transcript: "Communication starts with listening. The best conversations happen when both parties feel heard.",
            fillerWordCount: 1,
            duration: 48,
            date: Date(),
            mode: .timed,
            pressureLevel: .standard
        ),
        displayName: "Jordan",
        rating: 612,
        recentScores: [],
        friendsPeak: []
    )
    .padding()
}

@available(iOS 17.0, *)
#Preview("With history + friends") {
    ShareableSessionCard(
        session: PracticeSession(
            transcript: "Communication starts with listening.",
            fillerWordCount: 1,
            duration: 48,
            date: Date(),
            mode: .timed,
            pressureLevel: .standard
        ),
        displayName: "Jordan",
        rating: 612,
        recentScores: [5, 7, 6, 8, 9],
        friendsPeak: [
            ShareableSessionCard.FriendPeak(id: UUID(), displayName: "Sam Linden", initials: "SL", peakRating: 740),
            ShareableSessionCard.FriendPeak(id: UUID(), displayName: "Ava Quinn",  initials: "AQ", peakRating: 685)
        ]
    )
    .padding()
}
#endif

#endif
