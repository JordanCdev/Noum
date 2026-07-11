#if canImport(SwiftUI)
import SwiftUI

// MARK: - Section Micro-Label

/// Quiet sentence-case label rendered above each grouped section.
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
            .font(Typography.caption.weight(.semibold))
            .foregroundStyle(.secondary)
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
            HStack(alignment: .top, spacing: Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                        .frame(width: 22)
                        .padding(.top, 2)
                }
                rowContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 4)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable)
        .accessibilityLabel(title)
        .accessibilityValue(value ?? "")
        .accessibilityHint(accessibilityHint ?? "")
    }

    @ViewBuilder
    private var rowContent: some View {
        if let value, !value.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    titleText
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: Spacing.xs)
                    valueText(value)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                VStack(alignment: .leading, spacing: 2) {
                    titleText
                    valueText(value)
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            titleText
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var titleText: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
    }

    private func valueText(_ value: String) -> some View {
        Text(value)
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
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
        HStack(alignment: .top, spacing: Spacing.sm) {
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
                    .padding(.top, 2)
            }
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
                    titleText
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: Spacing.xs)
                    valueText
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }

                VStack(alignment: .leading, spacing: 2) {
                    titleText
                    valueText
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }

    private var titleText: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
    }

    private var valueText: some View {
        Text(value)
            .font(.caption.weight(.semibold))
            .foregroundStyle(valueTint)
    }
}
#endif
