// Low-emphasis status row beneath the Coach Card: streak on the left, word of the day on the right.

#if canImport(SwiftUI)
import SwiftUI

// MARK: - Home Utility Strip
//
// Thin row that lives BELOW the Coach Card and ABOVE the section headers on
// the populated home. Combines two facts the user already knows about — their
// current streak and today's word — into a single inline strip so neither
// surface needs a full card.
//
// Visual weight rules:
//   • No card background, no border, no badge styling.
//   • ~36–40pt tall. Two compact tap targets, Spacer() between.
//   • Iconography: SF Symbols only (flame / chevron). No emoji in copy.
//   • Coach voice: facts, no celebration verbs ("12 day streak", not
//     "12 day streak!"). Streak drops are silent; this strip only reads
//     what already exists in the singleton stores.
//
// Taps:
//   • Streak  → AppDestination.socialProfile (Profile holds the full streak
//                detail surface).
//   • Word    → seeds WordOfTheDayManager's suggested prompt into the
//                shared UserDefaults key used by TimedPracticeView, then
//                routes to AppDestination.timedPractice. This mirrors the
//                tap behaviour in WordOfTheDayTile so the two entry points
//                stay consistent.

@available(iOS 17.0, macOS 12.0, *)
struct HomeUtilityStrip: View {
    @Binding var navigationPath: NavigationPath
    @StateObject private var streak = StreakFreezeManager.shared
    @StateObject private var word = WordOfTheDayManager.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            streakButton
            Spacer(minLength: Spacing.xs)
            wordButton
        }
        .frame(minHeight: 36)
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Streak

    private var streakButton: some View {
        Button {
            navigationPath.append(AppDestination.socialProfile)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(streakTint)
                    .accessibilityHidden(true)

                Text(streakLabel)
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.standardSpring, value: streak.currentStreak)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(streakAccessibilityLabel)
        .accessibilityHint("Opens your profile.")
    }

    private var streakTint: Color {
        streak.currentStreak > 0 ? .orange : Color.secondary.opacity(0.55)
    }

    /// Coach-voice fact. "12 day streak". No exclamation, no celebration
    /// word. When the streak is 0 we render "No streak yet" rather than
    /// "0 day streak" — the latter reads like punishment.
    private var streakLabel: String {
        let n = streak.currentStreak
        return n > 0 ? "\(n) day streak" : "No streak yet"
    }

    private var streakAccessibilityLabel: String {
        let n = streak.currentStreak
        return n > 0 ? "\(n) day streak." : "No streak yet."
    }

    // MARK: - Word of the day

    private var wordButton: some View {
        Button(action: openWordOfTheDay) {
            HStack(spacing: 6) {
                Text("Word: \(word.todaysEntry.word)")
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.9)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Word of the day: \(word.todaysEntry.word).")
        .accessibilityHint(word.hasUsedToday
            ? "Already used today. Opens a timed rep using this word."
            : "Opens a timed rep seeded with today's word.")
    }

    /// Mirrors WordOfTheDayTile.tryIt() — seeds the shared UserDefaults
    /// prompt keys that TimedPracticeView reads on launch, then pushes the
    /// timed destination. Keeping this in lockstep with the tile means
    /// both entry points feel identical to the user.
    private func openWordOfTheDay() {
        let entry = word.todaysEntry
        UserDefaults.standard.set(entry.promptSuggestion, forKey: "timedPractice.suggestedPrompt")
        UserDefaults.standard.set(entry.word, forKey: "timedPractice.suggestedWord")
        navigationPath.append(AppDestination.timedPractice)
    }
}

// MARK: - Preview

#Preview("Active streak") {
    @Previewable @State var path = NavigationPath()
    return HomeUtilityStrip(navigationPath: $path)
        .padding(.horizontal, Spacing.screenH)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.screenBackground)
}

#Preview("Empty streak") {
    @Previewable @State var path = NavigationPath()
    return HomeUtilityStrip(navigationPath: $path)
        .padding(.horizontal, Spacing.screenH)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.screenBackground)
}

#endif
