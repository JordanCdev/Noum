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
                footer
            }
            .padding(28)
        }
        .frame(width: 360, height: 480)
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
            Text("Sharper speaking, one rep.")
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
        case .timed:          return "TIMED · \(modeDifficulty)"
        case .suddenDeath:    return "PRESSURE DRILL"
        case .ahCounter:      return "FREE-FLOW"
        case .imConversation: return "LIVE CONVERSATION"
        }
    }

    private var modeDifficulty: String {
        // Lossy — we don't store difficulty per session in the sharable
        // shape. Keep generic for the card.
        "1-MINUTE"
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

// MARK: - UIImage rendering

@available(iOS 17.0, *)
extension ShareableSessionCard {
    /// Render the card to a UIImage at 2× scale. Used by the share sheet.
    @MainActor
    static func render(session: PracticeSession, displayName: String, rating: Int) -> UIImage? {
        let renderer = ImageRenderer(content: ShareableSessionCard(
            session: session,
            displayName: displayName,
            rating: rating
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
        rating: 612
    )
    .padding()
}
#endif

#endif
