import Testing
import UIKit
@testable import Noum

@Suite("Accessibility contrast")
struct AccessibilityContrastTests {
    @Test @MainActor
    func adjustTextTokenClearsAAAgainstWhite() {
        let foreground = UIColor(AppColor.brandBlue)
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        let ratio = contrastRatio(foreground: foreground, background: .white)

        #expect(ratio >= 4.5)
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
