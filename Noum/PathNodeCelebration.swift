#if canImport(SwiftUI)
import SwiftUI

/// Full-screen celebration shown the moment a path node is newly unlocked.
/// Visual language matches `MilestoneCelebrationOverlay` so the app speaks
/// with one celebration voice — no chirpy copy, no shower of confetti, a
/// single positive moment that doesn't block the user from moving on.
@available(iOS 17.0, macOS 12.0, *)
struct PathNodeCelebration: View {
    let node: PathNode
    let onDismiss: () -> Void

    @State private var hasAppeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.32)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(AppColor.positive.opacity(0.18))
                        .frame(width: 96, height: 96)
                    Image(systemName: node.symbolName)
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(AppColor.positive)
                        .scaleEffect(hasAppeared ? 1 : 0.7)
                }

                VStack(spacing: 10) {
                    Text("Node unlocked")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColor.positive)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    Text(node.title)
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text(node.coachLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button(action: onDismiss) {
                    Text("Continue")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColor.brandBlue, in: Capsule())
                }
                .accessibilityIdentifier("path.celebration.continue")
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(
                AppColor.cardBackground,
                in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                    .stroke(Color.white.opacity(0.7), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 24, y: 8)
            .padding(.horizontal, 32)
            .scaleEffect(hasAppeared ? 1 : 0.92)
            .opacity(hasAppeared ? 1 : 0)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Path node unlocked: \(node.title). \(node.coachLine)")
        }
        .onAppear {
            CoachHaptic.trendBreakthrough()
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                hasAppeared = true
            }
        }
    }
}

#if DEBUG
@available(iOS 17.0, *)
#Preview("Path node unlocked") {
    PathNodeCelebration(
        node: PathNodeRegistry.all[4].0,
        onDismiss: {}
    )
}
#endif

#endif
