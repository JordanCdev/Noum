#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 12.0, *)
struct SplashScreenView: View {
    @State private var animateOrb = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            AppColor.screenBackground
            .ignoresSafeArea()

            Circle()
                .fill(AppColor.brandBlue.opacity(0.16))
                .frame(width: 220, height: 220)
                .blur(radius: 18)
                .offset(x: animateOrb ? 26 : -18, y: animateOrb ? -44 : -12)
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.8).repeatForever(autoreverses: true), value: animateOrb)

            Circle()
                .fill(Color.orange.opacity(0.14))
                .frame(width: 180, height: 180)
                .blur(radius: 16)
                .offset(x: animateOrb ? -34 : 20, y: animateOrb ? 68 : 30)
                .animation(reduceMotion ? nil : .easeInOut(duration: 2.1).repeatForever(autoreverses: true), value: animateOrb)

            VStack(spacing: 18) {
                Text("Noum")
                    .font(Typography.display)

                Text("Sharper speaking, one rep at a time.")
                    .font(Typography.subheadline)
                    .foregroundStyle(.secondary)

                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppColor.brandBlue)
                    .scaleEffect(1.1)
            }
            .padding(34)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            // Skip the orb animation entirely when Reduce Motion is on —
            // the static positions still read as a splash without
            // triggering vestibular response.
            guard !reduceMotion else { return }
            animateOrb = true
        }
    }
}
#endif
