#if canImport(SwiftUI)
import SwiftUI

// MARK: - Word of the Day Tile (M9)
//
// Compact home-screen card surfacing today's curated word + definition
// + suggested 30s prompt. State indicator on the right shows "Used"
// (with check) when the user has already worked the word into a session,
// or a small "Try it" CTA otherwise.
//
// Tapping "Try it" sets the suggested prompt as the timed-practice seed
// and opens TimedPracticeView via the standard navigation pattern.

@available(iOS 17.0, macOS 12.0, *)
struct WordOfTheDayTile: View {
    @StateObject private var manager = WordOfTheDayManager.shared
    @Binding var navigationPath: NavigationPath
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        Button(action: tryIt) {
            HStack(alignment: .top, spacing: 14) {
                wordBadge
                    .frame(width: 48, height: 48)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("Word of the day")
                            .font(Typography.micro)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        Spacer()

                        statusPill
                    }

                    Text(manager.todaysEntry.word)
                        .font(Typography.cardTitle)
                        .foregroundStyle(.primary)

                    Text("\(manager.todaysEntry.partOfSpeech) — \(manager.todaysEntry.definition)")
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if !manager.hasUsedToday {
                        Text(manager.todaysEntry.promptSuggestion)
                            .font(Typography.caption.italic())
                            .foregroundStyle(AppColor.brandBlue)
                            .padding(.top, 2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(Spacing.lg)
            .background(
                tileBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(pulse ? 1.02 : 1.0)
        .onChange(of: manager.pendingUsageSignal) { _, signaled in
            guard signaled, !reduceMotion else {
                manager.consumePendingUsage()
                return
            }
            withAnimation(.standardSpring) { pulse = true }
            Task {
                try? await Task.sleep(for: .milliseconds(280))
                await MainActor.run {
                    withAnimation(.standardSpring) { pulse = false }
                    manager.consumePendingUsage()
                }
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Subviews

    private var wordBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(badgeAccent.opacity(manager.hasUsedToday ? 0.18 : 0.12))
            Image(systemName: manager.hasUsedToday ? "checkmark.seal.fill" : "text.book.closed.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(badgeAccent)
        }
    }

    @ViewBuilder
    private var statusPill: some View {
        if manager.hasUsedToday {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .heavy))
                Text("Used")
                    .font(Typography.micro.weight(.bold))
            }
            .foregroundStyle(AppColor.brandBlue)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColor.brandBlue.opacity(0.14), in: Capsule())
        } else {
            HStack(spacing: 4) {
                Text("Try it")
                    .font(Typography.micro.weight(.bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .heavy))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(AppColor.brandBlue, in: Capsule())
        }
    }

    private var badgeAccent: Color {
        manager.hasUsedToday ? AppColor.brandBlue : AppColor.brandBlue
    }

    private var tileBackground: some ShapeStyle {
        manager.hasUsedToday
            ? AnyShapeStyle(LinearGradient(
                colors: [AppColor.brandBlue.opacity(0.10), AppColor.brandBlue.opacity(0.04)],
                startPoint: .topLeading, endPoint: .bottomTrailing
              ))
            : AnyShapeStyle(AppColor.cardBackground)
    }

    private var accessibilityLabel: String {
        let usage = manager.hasUsedToday ? "Already used today." : "Tap to start a Timed rep using this word."
        return "Word of the day. \(manager.todaysEntry.word). \(manager.todaysEntry.definition) \(usage)"
    }

    // MARK: - Actions

    private func tryIt() {
        // Seed today's prompt into TimedPractice via the existing AppStorage
        // path used elsewhere by the recommendation flow. TimedPracticeView
        // reads "timedPractice.selectedTheme" — we don't override it here;
        // instead we set a one-shot prompt seed key that the view consumes
        // on next launch.
        let suggestion = manager.todaysEntry.promptSuggestion
        UserDefaults.standard.set(suggestion, forKey: "timedPractice.suggestedPrompt")
        UserDefaults.standard.set(manager.todaysEntry.word, forKey: "timedPractice.suggestedWord")
        navigationPath.append(AppDestination.timedPractice)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @State var path = NavigationPath()
    return WordOfTheDayTile(navigationPath: $path)
        .padding()
        .background(AppColor.screenBackground)
}

#endif
