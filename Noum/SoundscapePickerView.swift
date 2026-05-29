#if canImport(SwiftUI)
import SwiftUI

// MARK: - Soundscape Picker
//
// Settings surface that lets the user pick a pre-rep ambient texture
// and previews each option live (1.5s preview, then auto-stops). Pro-
// gated — Free users see the row but tapping nudges them to the paywall.
//
// Voice rules: sentence-case, no exclamations, coach-tone subtitles
// describing what each layer adds.

@available(iOS 17.0, macOS 12.0, *)
struct SoundscapePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = SoundscapeEngine.shared
    @StateObject private var premium = PremiumManager.shared
    @State private var selectedMode: SoundscapeMode = SoundscapeSettings.savedMode
    @State private var previewTask: Task<Void, Never>?
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    headerCopy
                    modesList
                    if selectedMode != .off {
                        volumeRow
                    }
                    coachNote
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.lg)
            }
            .background(AppColor.screenBackground.ignoresSafeArea())
            .navigationTitle("Pre-rep prep")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { commitAndDismiss() }
                        .foregroundStyle(AppColor.brandBlue)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
            .onDisappear {
                previewTask?.cancel()
                engine.stop()
            }
            .accessibilityIdentifier("soundscape.picker")
        }
    }

    // MARK: - Sections

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pre-rep prep")
                .font(Typography.screenTitle)
                .foregroundStyle(.primary)
            Text("A short ambient texture during the seconds before recording. Fades out the moment your rep starts.")
                .font(Typography.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var modesList: some View {
        VStack(spacing: Spacing.cardGap) {
            ForEach(SoundscapeMode.allCases) { mode in
                modeRow(mode)
            }
        }
    }

    private func modeRow(_ mode: SoundscapeMode) -> some View {
        let isSelected = mode == selectedMode
        let isPlaying = engine.activeMode == mode
        return Button { tap(mode) } label: {
            HStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(tint(for: mode).opacity(isSelected ? 0.18 : 0.10))
                        .frame(width: 44, height: 44)
                    Image(systemName: mode.symbolName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(tint(for: mode))
                        .symbolEffect(.pulse, options: .repeating, isActive: isPlaying)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(mode.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)
                        if mode != .off, !premium.isPremium {
                            proPill
                        }
                    }
                    Text(mode.coachLine)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? tint(for: mode) : Color.secondary.opacity(0.4))
            }
            .padding(Spacing.md)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(
                        isSelected ? tint(for: mode).opacity(0.32) : Color.white.opacity(0.72),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.pressable)
        .accessibilityIdentifier("soundscape.row.\(mode.rawValue)")
    }

    private var proPill: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(
                    colors: [AppColor.pro, AppColor.proLight],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: Capsule(style: .continuous)
            )
    }

    private var volumeRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Volume")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
                Text("\(Int(engine.volume * 100))%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .monospacedDigit()
            }
            Slider(value: Binding(
                get: { Double(engine.volume) },
                set: { engine.volume = Float($0) }
            ), in: 0.0...1.0)
            .tint(AppColor.brandBlue)
        }
        .padding(Spacing.md)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    private var coachNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(AppColor.brandBlue)
            Text("This plays only during the pre-rep countdown. It fades the moment the rep begins.")
                .font(Typography.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .background(AppColor.brandBlue.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
    }

    // MARK: - Behavior

    private func tap(_ mode: SoundscapeMode) {
        // Pro-gate everything except .off
        if mode != .off, !premium.isPremium {
            previewTask?.cancel()
            engine.stop()
            showPaywall = true
            return
        }
        selectedMode = mode
        previewTask?.cancel()
        if mode == .off {
            engine.stop()
            return
        }
        // Live preview: start the engine and auto-stop after 2.0s so
        // the user can taste each option without manually stopping.
        engine.start(mode)
        previewTask = Task { [mode] in
            try? await Task.sleep(for: .seconds(2.0))
            await MainActor.run {
                if engine.activeMode == mode {
                    engine.stop()
                }
            }
        }
    }

    private func commitAndDismiss() {
        SoundscapeSettings.persistMode(selectedMode)
        previewTask?.cancel()
        engine.stop()
        dismiss()
    }

    private func tint(for mode: SoundscapeMode) -> Color {
        switch mode {
        case .off:    return AppColor.textSecondary
        case .focus:  return AppColor.brandBlue
        case .calm:   return AppColor.modeAhCounter
        case .steady: return AppColor.pro
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Soundscape picker") {
    SoundscapePickerView()
}
#endif

#endif
