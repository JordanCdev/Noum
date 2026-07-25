import Testing
import SwiftUI
import UIKit
@testable import Noum

@Suite("Accessibility contrast")
struct AccessibilityContrastTests {
    @Test @MainActor
    func adjustTextTokenClearsAAAgainstWhite() {
        let foreground = resolved(AppColor.brandBlue)
        let ratio = contrastRatio(foreground: foreground, background: .white)

        #expect(ratio >= 4.5)
    }

    @Test @MainActor
    func semanticLightSurfaceTokensClearAA() {
        let cases: [(String, UIColor, UIColor)] = [
            ("primary", resolved(AppColor.textPrimary), .white),
            ("primary on pro surface", resolved(AppColor.textPrimary), resolved(AppColor.proQuietSurface)),
            ("secondary", resolved(AppColor.textSecondary), .white),
            ("tertiary", resolved(AppColor.textTertiary), .white),
            ("pro text", resolved(AppColor.proText), resolved(AppColor.proQuietSurface)),
            // V4.6 slice-1 tokens. voiceLive is exempt: decorative trace bars
            // on natively dark surfaces, never text on light.
            ("receded transcript words", resolved(AppColor.neutralReceded), .white),
            ("receded words on quiet tag surface", resolved(AppColor.neutralReceded), resolved(AppColor.cardBackground)),
            ("white label on pressed CTA", .white, resolved(AppColor.actionPressed)),
        ]

        for (name, foreground, background) in cases {
            #expect(
                contrastRatio(foreground: foreground, background: background) >= 4.5,
                "\(name) must clear AA on its production surface"
            )
        }
    }

    @Test @MainActor
    func progressHeroInkClearsAAAtEveryGradientStop() {
        let foreground = resolved(AppColor.progressHeroInk)
        for stop in [
            AppColor.progressHeroStart,
            AppColor.progressHeroMid,
            AppColor.progressHeroEnd,
        ] {
            #expect(contrastRatio(foreground: foreground, background: resolved(stop)) >= 4.5)
        }
    }

    @MainActor
    private func resolved(_ color: Color) -> UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
    }

    private func contrastRatio(foreground: UIColor, background: UIColor) -> Double {
        let foregroundLuminance = relativeLuminance(foreground)
        let backgroundLuminance = relativeLuminance(background)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func relativeLuminance(_ color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return 0
        }

        func linearize(_ component: CGFloat) -> Double {
            let value = Double(component)
            return value <= 0.04045
                ? value / 12.92
                : pow((value + 0.055) / 1.055, 2.4)
        }

        return 0.2126 * linearize(red)
            + 0.7152 * linearize(green)
            + 0.0722 * linearize(blue)
    }
}
