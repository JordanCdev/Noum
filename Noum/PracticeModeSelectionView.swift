import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum PracticeMode: String, Codable {
    case timed
    case suddenDeath
    case ahCounter
    case imConversation
}

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct PracticeModeSelectionView: View {
    @Binding var selectedMode: PracticeMode

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.92, blue: 0.87),
                    Color.white,
                    Color(red: 0.90, green: 0.95, blue: 0.99)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Choose Your Drill")
                        .font(.largeTitle.weight(.bold))
                    Text("Pick the type of pressure you want to train against before you start speaking.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                practiceModeCard(
                    title: "Timed Practice",
                    subtitle: "Choose a difficulty, take your prep time, and practise a complete response with coaching.",
                    systemImage: "clock.fill",
                    tint: Color(red: 0.20, green: 0.47, blue: 0.96),
                    mode: .timed
                )

                practiceModeCard(
                    title: "Sudden Death",
                    subtitle: "Start immediately and survive without a single filler word.",
                    systemImage: "bolt.fill",
                    tint: Color(red: 0.95, green: 0.55, blue: 0.15),
                    mode: .suddenDeath
                )

                practiceModeCard(
                    title: "Ah-Counter",
                    subtitle: "Free-form speaking with live filler-word tracking.",
                    systemImage: "waveform.and.mic",
                    tint: Color(red: 0.14, green: 0.60, blue: 0.44),
                    mode: .ahCounter
                )

                practiceModeCard(
                    title: "IM Mode",
                    subtitle: "Voice your side of a realistic chat and train tone, pacing, and conversational control.",
                    systemImage: "message.badge.waveform.fill",
                    tint: Color(red: 0.56, green: 0.36, blue: 0.92),
                    mode: .imConversation
                )

                Spacer()
            }
            .padding(20)
        }
        .navigationTitle("Practice Modes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink("Start") {
                    switch selectedMode {
                    case .timed:
                        TimedPracticeView()
                    case .suddenDeath:
                        SuddenDeathPracticeView()
                    case .ahCounter:
                        AhCounterView()
                    case .imConversation:
                        IMPracticeView()
                    }
                }
                .accessibilityIdentifier("practiceModes.start")
            }
        }
    }

    private func practiceModeCard(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        mode: PracticeMode
    ) -> some View {
        Button {
            selectedMode = mode
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(tint.opacity(0.14))
                        .frame(width: 54, height: 54)
                    Image(systemName: systemImage)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: selectedMode == mode ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selectedMode == mode ? tint : .secondary)
            }
            .padding(18)
            .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("practiceMode.\(mode.rawValue)")
    }
}
#endif
