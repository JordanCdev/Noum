import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

/// Content-free presentation state for a transcription route decision.
///
/// This intentionally describes only where the current rep is transcribed.
/// It never carries transcript text, provider credentials, or transport errors.
struct TranscriptionRouteNotice: Equatable, Sendable {
    let title: String
    let message: String

    var accessibilityLabel: String {
        "\(title). \(message)"
    }

    static let cloudStartupFallback = TranscriptionRouteNotice(
        title: "Continuing on this device",
        message: "Cloud transcription wasn’t available at startup, so this rep is staying on this device. No rep audio was sent to a cloud speech provider."
    )
}

#if canImport(SwiftUI)
private struct TranscriptionRouteNoticeView: View {
    let notice: TranscriptionRouteNotice

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "lock.shield")
                .font(Typography.caption)
                .foregroundStyle(AppColor.brandBlue)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(notice.title)
                    .font(Typography.caption)
                    .foregroundStyle(AppColor.textPrimary)

                Text(notice.message)
                    .font(Typography.captionSmall)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous)
                .strokeBorder(AppColor.brandBlue.opacity(0.18), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(notice.accessibilityLabel))
        .accessibilityIdentifier("transcription.startupFallbackNotice")
    }
}

private struct TranscriptionRouteNoticeModifier: ViewModifier {
    let notice: TranscriptionRouteNotice?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: 0) {
                if let notice {
                    TranscriptionRouteNoticeView(notice: notice)
                        .padding(.horizontal, Spacing.screenH)
                        .padding(.vertical, Spacing.xs)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .move(edge: .top).combined(with: .opacity)
                        )
                }
            }
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 0.2),
                value: notice
            )
    }
}

extension View {
    /// Adds the shared, nonblocking startup-fallback notice used by practice modes.
    func transcriptionRouteNotice(_ notice: TranscriptionRouteNotice?) -> some View {
        modifier(TranscriptionRouteNoticeModifier(notice: notice))
    }
}
#endif
