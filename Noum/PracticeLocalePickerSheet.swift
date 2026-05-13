#if canImport(SwiftUI)
import SwiftUI

// MARK: - Practice Locale Picker (M12)
//
// Bottom sheet for switching the active practice language. Updates take
// effect on the next session start (existing in-flight session keeps its
// current locale until the user finishes it).
//
// English is the canonical 200+ pool with full coaching support.
// Spanish and French ship with smaller curated pools and use the same
// coaching surfaces — copy is intentionally still in English (see
// VISION.md M12 honesty section).

@available(iOS 17.0, macOS 12.0, *)
struct PracticeLocalePickerSheet: View {
    @StateObject private var manager = LocaleSettingsManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 6) {
                Text("Practice language")
                    .font(Typography.cardTitle)
                Text("locale.picker.subtitle")
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 8) {
                ForEach(PracticeLocale.allCases) { locale in
                    row(for: locale)
                }
            }

            Spacer()
        }
        .padding(Spacing.lg)
        .presentationDetents([.medium])
    }

    @ViewBuilder
    private func row(for locale: PracticeLocale) -> some View {
        let isActive = manager.current == locale
        Button {
            manager.current = locale
            CoachHaptic.selectionTap()
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(locale.shortLabel)
                    .font(Typography.caption.weight(.bold))
                    .foregroundStyle(isActive ? .white : AppColor.brandBlue)
                    .frame(width: 36, height: 36)
                    .background(
                        isActive ? AppColor.brandBlue : AppColor.brandBlue.opacity(0.14),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(locale.displayName)
                        .font(Typography.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle(for: locale))
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColor.brandBlue)
                }
            }
            .padding(Spacing.md)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                    .stroke(isActive ? AppColor.brandBlue.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func subtitle(for locale: PracticeLocale) -> LocalizedStringKey {
        switch locale {
        case .enUS: return "locale.pool.full"
        case .esES, .frFR: return "locale.pool.curated"
        }
    }
}

#endif
