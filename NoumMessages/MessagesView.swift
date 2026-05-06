#if canImport(SwiftUI)
import SwiftUI
import UIKit

// MARK: - Messages Challenge Card
//
// SwiftUI surface that renders inside the iMessage app extension. Mirrors
// the share-card design language from `ShareableSessionCard.swift` so the
// extension feels like part of the same product, not a bolt-on.
//
// The card shows the sender's current speaker rating, streak, and reps
// today, then exposes one primary action: "Challenge them". Tapping
// inserts an MSMessage carrying a `noum://practice` URL — the recipient
// taps the bubble, the system opens Noum, and the deep-link handler in
// the main app routes them into a fresh rep.

struct MessagesChallengeView: View {
    let snapshot: SharedNoumState
    let onChallenge: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ShareCard(snapshot: snapshot)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            challengeButton
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGroupedBackground))
    }

    private var challengeButton: some View {
        Button(action: onChallenge) {
            Text("Challenge them")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(MessagesBrand.brandBlue, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Challenge them on Noum")
    }
}

// MARK: - Share Card (mirror of ShareableSessionCard)

struct ShareCard: View {
    let snapshot: SharedNoumState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [MessagesBrand.brandBlue, MessagesBrand.brandBlueLight],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

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
                footer
            }
            .padding(28)
        }
        .frame(width: 320, height: 400)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    // MARK: Subviews

    private var wordmark: some View {
        HStack {
            Text("noum")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .tracking(1.2)
            Spacer()
            Text("Speaking rating")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.8)
            Text("\(snapshot.rating)")
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
    }

    private var headline: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Challenge me on Noum")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("One rep. One minute. See if you can hold pace.")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            statTile(value: streakText, label: "Streak")
            statTile(value: repsText, label: "Today")
            statTile(value: weeklyText, label: "Week")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .textCase(.uppercase)
                .tracking(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 12)
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
            Text("Tap to take the rep.")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Spacer()
        }
    }

    // MARK: Formatters

    private var streakText: String {
        "\(snapshot.currentStreak)d"
    }

    private var repsText: String {
        "\(snapshot.repsToday)/\(snapshot.goalReps)"
    }

    private var weeklyText: String {
        "\(snapshot.weeklyReps)"
    }
}

// MARK: - Brand colors (extension-local)

enum MessagesBrand {
    /// Mirror of `AppColor.brandBlue` from the main app's DesignSystem so
    /// the iMessage card matches the share-card design without depending
    /// on the main target.
    static let brandBlue = Color(red: 0.13, green: 0.45, blue: 0.96)
    static let brandBlueLight = Color(red: 0.27, green: 0.62, blue: 1.0)
}

// MARK: - UIImage rendering

extension ShareCard {
    /// Render the card to a UIImage at screen scale. Used as the
    /// `MSMessageTemplateLayout.image` so the bubble shows the card
    /// preview in the conversation.
    @MainActor
    static func render(snapshot: SharedNoumState) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCard(snapshot: snapshot))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

#endif
