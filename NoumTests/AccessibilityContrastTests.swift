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

    /// The floating navigation capsule is the one surface the user sees on
    /// every tab root, and the rendered audit only runs in light. These
    /// cases hold both registers to AA so a dark-mode regression cannot
    /// ship unseen: the selected pair resolved to #9061F9 on the quiet
    /// violet pill (3.68:1) until `…OnQuiet` lifted the dark register, and
    /// receding the unselected glyph to 0.75 alpha put it at 3.41:1.
    @Test @MainActor
    func navigationCapsuleTokensClearAAInBothAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let capsule = resolved(AppColor.cardBackground, in: style)
            let pill = resolved(AppColor.proQuietSurface, in: style)
            let cases: [(String, UIColor, UIColor)] = [
                ("unselected label", resolved(AppColor.neutralReceded, in: style), capsule),
                ("unselected glyph", resolved(AppColor.neutralReceded, in: style), capsule),
                ("selected label", resolved(AppColor.coachingInkOnQuiet, in: style), pill),
                ("selected glyph", resolved(AppColor.coachAccentOnQuiet, in: style), pill),
            ]

            for (name, foreground, background) in cases {
                #expect(
                    contrastRatio(foreground: foreground, background: background) >= 4.5,
                    "\(name) must clear AA on the navigation capsule in \(style == .dark ? "dark" : "light")"
                )
            }
        }
    }

    @MainActor
    private func resolved(_ color: Color) -> UIColor {
        resolved(color, in: .light)
    }

    @MainActor
    private func resolved(_ color: Color, in style: UIUserInterfaceStyle) -> UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
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
