#if canImport(SwiftUI)
import SwiftUI

// MARK: - Section Micro-Label

/// Uppercase tracked micro-label rendered above each card group.
/// Uses the canonical `Typography.micro` role so Settings labels inherit the
/// app-wide Dynamic Type contract.
///
/// M13: takes `LocalizedStringKey` so callers passing string literals
/// (`"Practice"`) get auto-translated through the app's
/// `Localizable.xcstrings` catalog when the active practice locale
/// has a matching entry. Callers passing dynamic non-localizable
/// strings (rare) need to wrap explicitly via `Text(verbatim:)`.
struct SettingsSectionLabel: View {
    let title: LocalizedStringKey

    init(title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .font(Typography.micro)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.8)
            .padding(.horizontal, 4)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Toggle Row

/// Standard toggle row with title, optional subtitle, brand-blue tint,
/// and sensory feedback gated on `HapticsSettings`.
@available(iOS 17.0, *)
struct SettingsToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    var isDisabled: Bool = false
    var disabledReason: String?
    var accessibilityHint: String?

    @ObservedObject private var haptics = HapticsSettings.shared

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Typography.subheadline.weight(.semibold))
                    .foregroundStyle(isDisabled ? Color.secondary : Color.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if isDisabled, let disabledReason {
                    Text(disabledReason)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColor.caution)
                }
            }
        }
        .toggleStyle(.switch)
        .tint(AppColor.brandBlue)
        .disabled(isDisabled)
        .frame(minHeight: 44)
        .sensoryFeedback(.selection, trigger: isOn) { _, _ in haptics.isEnabled }
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint ?? subtitle ?? "")
    }
}

// MARK: - Navigation Row

/// Tappable row with leading title, optional trailing value, and a chevron.
/// Used for "open" actions: Update profile, Your data, Manage subscription, etc.
@available(iOS 17.0, *)
struct SettingsNavRow: View {
    let title: String
    var value: String?
    var icon: String?
    var tint: Color = AppColor.brandBlue
    var accessibilityHint: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 22)
                }
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: Spacing.xs)
                if let value {
                    Text(value)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
        .accessibilityHint(accessibilityHint ?? "")
    }
}

// MARK: - Read-only Status Row

/// Inline label + value row for status that the user can't edit directly
/// (e.g. notification access, mic permission, provider, account ID).
@available(iOS 17.0, *)
struct SettingsStatusRow: View {
    let title: String
    let value: String
    var valueTint: Color = .primary
    var icon: String?

    var body: some View {
        HStack(spacing: Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
            }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Spacer(minLength: Spacing.xs)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(valueTint)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}
#endif
