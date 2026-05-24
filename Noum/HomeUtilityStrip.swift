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
//   • Word    → seeds a neutral topic plus today's word into the shared
//                UserDefaults keys used by TimedPracticeView, then routes
//                to AppDestination.timedPractice. Timed shows the word as a
//                separate cue so the prompt never does the usage for them.

@available(iOS 17.0, macOS 12.0, *)
struct HomeUtilityStrip: View {
    @Binding var navigationPath: NavigationPath
    @StateObject private var streak = StreakFreezeManager.shared
    @StateObject private var word = WordOfTheDayManager.shared
    @State private var showSoundscape = false
    @State private var soundscapeMode: SoundscapeMode = SoundscapeSettings.savedMode
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.sm) {
            streakButton
            Spacer(minLength: Spacing.xs)
            wordButton
            Spacer(minLength: Spacing.xs)
            soundscapeButton
        }
        .frame(minHeight: 36)
        .padding(.vertical, 2)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showSoundscape) {
            SoundscapePickerView()
        }
        .onChange(of: showSoundscape) { _, isOpen in
            // Re-read the user's preference each time the picker closes so
            // the strip's icon + dot reflect the current mode.
            if !isOpen {
                soundscapeMode = SoundscapeSettings.savedMode
            }
        }
    }

    // MARK: - Soundscape

    /// Compact soundscape entry on the home utility strip. Surfaces the
    /// user's chosen ambient (Off / Focus / Calm / Steady) so the dream's
    /// "creative theme you can pick" is reachable in one tap from Home,
    /// not buried two screens deep in Settings. Mode-symbol drives the
    /// glyph; a small active dot indicates a non-Off mode is set.
    private var soundscapeButton: some View {
        Button {
            showSoundscape = true
        } label: {
            HStack(spacing: 4) {
                // Soundscape entry stays icon-led so the three-item
                // strip (streak + word + soundscape) fits comfortably
                // on a single line at every device width. Label only
                // appears when a non-Off mode is active; the active dot
                // signals the rest of the time.
                Image(systemName: soundscapeMode.symbolName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(soundscapeMode == .off ? .secondary : AppColor.pro)
                    .accessibilityHidden(true)

                if soundscapeMode != .off {
                    Text(soundscapeMode.title)
                        .font(Typography.caption.weight(.semibold))
                        .foregroundStyle(AppColor.pro)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("Soundscape \(soundscapeMode.title).")
        .accessibilityHint("Opens the soundscape picker.")
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
                // Tiny "used today" affirmation. Coach-voice rule from the
                // M16 brief: surface state factually, no praise inflation
                // and no streak counter. The checkmark replaces the chevron
                // when the user has already used the word in a rep today.
                if word.hasUsedToday {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppColor.brandBlue)
                        .accessibilityHidden(true)
                }

                Text("Word of the day: \(word.todaysEntry.word)")
                    .font(Typography.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .minimumScaleFactor(0.9)

                Image(systemName: word.hasUsedToday ? "arrow.right" : "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(word.hasUsedToday
            ? "Word of the day: \(word.todaysEntry.word). Used today."
            : "Word of the day: \(word.todaysEntry.word).")
        .accessibilityHint(word.hasUsedToday
            ? "Already used today. Opens a timed rep with this word as a separate cue."
            : "Opens a timed rep with today's word as a separate cue.")
    }

    /// Seeds the shared UserDefaults prompt keys that TimedPracticeView
    /// reads on launch, then pushes the timed destination. The prompt is
    /// neutral; the word travels separately as an intentional constraint.
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
