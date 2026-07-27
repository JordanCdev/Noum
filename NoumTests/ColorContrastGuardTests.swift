import Foundation
import SwiftUI
import Testing
#if canImport(UIKit)
import UIKit
#endif
@testable import Noum

/// Guards the defect class that every other accessibility check in this repo is
/// blind to: text that is present and correctly labelled in the accessibility
/// tree, but visually unreadable because a hardcoded colour sits on an adaptive
/// surface.
///
/// The bug that motivated this: `CoachingOnboardingView`'s option labels were a
/// hardcoded near-black ink on `AppColor.innerSurface`, which resolves dark.
/// 1.01:1 in Dark appearance, 13.67:1 in Light. The first interactive screen in
/// the product was unreadable for anyone with Dark appearance on. Xcode's native
/// audit suite passed it at Accessibility XXXL across five tabs, and VoiceOver
/// was unaffected, because the text was always in the tree — the failure is
/// visible only to a sighted user in Dark mode, a population no existing check
/// represented.
///
/// This resolves the REAL tokens through a trait collection rather than
/// duplicating their tuples, so the assertions cannot drift away from
/// `DesignSystem.swift`.
@Suite("Colour contrast guard")
struct ColorContrastGuardTests {

    // MARK: - WCAG arithmetic

    /// Relative luminance per WCAG 2.1.
    static func luminance(_ rgb: (Double, Double, Double)) -> Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(rgb.0) + 0.7152 * channel(rgb.1) + 0.0722 * channel(rgb.2)
    }

    static func contrastRatio(
        _ a: (Double, Double, Double),
        _ b: (Double, Double, Double)
    ) -> Double {
        let la = luminance(a)
        let lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    @Test("WCAG arithmetic matches known reference pairs")
    func arithmeticIsCorrect() {
        let white = (1.0, 1.0, 1.0)
        let black = (0.0, 0.0, 0.0)
        // Black on white is the canonical 21:1.
        #expect(abs(Self.contrastRatio(black, white) - 21.0) < 0.01)
        // Same colour is always 1:1.
        #expect(abs(Self.contrastRatio(white, white) - 1.0) < 0.001)
        // Ratio is symmetric — order of arguments must not matter.
        let a = (0.2, 0.4, 0.6)
        #expect(abs(Self.contrastRatio(a, white) - Self.contrastRatio(white, a)) < 0.0001)
        // #767676 on white is the textbook 4.54:1 boundary case.
        let grey = (0x76 / 255.0, 0x76 / 255.0, 0x76 / 255.0)
        #expect(abs(Self.contrastRatio(grey, white) - 4.54) < 0.05)
    }

    // MARK: - Token resolution

#if canImport(UIKit)
    enum Appearance: String, CaseIterable {
        case light, dark
        var traits: UITraitCollection {
            UITraitCollection(userInterfaceStyle: self == .dark ? .dark : .light)
        }
    }

    /// Resolves a token's actual RGB for one appearance. Composites any alpha
    /// over `over`, because a translucent foreground is only as readable as what
    /// sits behind it.
    static func rgb(
        _ color: Color,
        _ appearance: Appearance,
        over backdrop: (Double, Double, Double)? = nil
    ) -> (Double, Double, Double) {
        let resolved = UIColor(color).resolvedColor(with: appearance.traits)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        guard let backdrop, a < 1 else { return (Double(r), Double(g), Double(b)) }
        return (
            Double(r) * Double(a) + backdrop.0 * (1 - Double(a)),
            Double(g) * Double(a) + backdrop.1 * (1 - Double(a)),
            Double(b) * Double(a) + backdrop.2 * (1 - Double(a))
        )
    }

    /// Self-check on the harness. If `UIColor(Color)` lost the dynamic provider,
    /// every token would resolve to its light value and the whole suite would
    /// pass while proving nothing — the exact false-green this file exists to
    /// prevent. Any real token must differ between appearances.
    @Test("Trait resolution actually distinguishes light from dark")
    func harnessResolvesBothAppearances() {
        let light = Self.rgb(AppColor.screenBackground, .light)
        let dark = Self.rgb(AppColor.screenBackground, .dark)
        #expect(
            Self.luminance(light) > Self.luminance(dark) + 0.1,
            "screenBackground must be lighter in Light than in Dark — if these match, UIColor(Color) dropped the trait provider and every other assertion here is meaningless."
        )
    }

    // MARK: - The contract

    /// AA thresholds. 4.5:1 for normal text; 3:1 for text at >= 18.66pt bold
    /// (or >= 24pt regular) and for non-text UI components.
    enum Requirement: Double {
        case normalText = 4.5
        case largeTextOrComponent = 3.0
    }

    struct Pairing {
        let label: String
        let foreground: Color
        let background: Color
        let requirement: Requirement
    }

    /// Every foreground/background combination the design system actually uses.
    /// This table IS the readability contract — adding a token pairing to the
    /// app means adding it here.
    static var pairings: [Pairing] {
        var all: [Pairing] = []
        let surfaces: [(String, Color)] = [
            ("screenBackground", AppColor.screenBackground),
            ("cardBackground", AppColor.cardBackground),
            ("innerSurface", AppColor.innerSurface),
            ("warmCanvas", AppColor.warmCanvas),
        ]
        let inks: [(String, Color, Requirement)] = [
            ("textPrimary", AppColor.textPrimary, .normalText),
            ("textSecondary", AppColor.textSecondary, .normalText),
            ("textTertiary", AppColor.textTertiary, .normalText),
            // Semantic feedback carries meaning as text (deltas, lapse rows), so
            // it is held to the normal-text bar, not the component bar.
            ("positive", AppColor.positive, .normalText),
            ("caution", AppColor.caution, .normalText),
            ("warning", AppColor.warning, .normalText),
        ]
        for (surfaceName, surface) in surfaces {
            for (inkName, ink, requirement) in inks {
                all.append(
                    Pairing(
                        label: "\(inkName) on \(surfaceName)",
                        foreground: ink,
                        background: surface,
                        requirement: requirement
                    )
                )
            }
        }
        // Coach voice on its own quiet surface, per the token contract's
        // dedicated -OnQuiet roles.
        all.append(Pairing(label: "coachingInkOnQuiet on proQuietSurface", foreground: AppColor.coachingInkOnQuiet, background: AppColor.proQuietSurface, requirement: .normalText))
        all.append(Pairing(label: "coachAccentOnQuiet on proQuietSurface", foreground: AppColor.coachAccentOnQuiet, background: AppColor.proQuietSurface, requirement: .normalText))
        // `coachingInk` is a FILL role per the token contract ("editorial CTA
        // fill, improved-phrase tint, selected tab label"), so it is asserted as
        // a background carrying a label, not as text on a card. Text on the
        // quiet surface must use the dedicated `-OnQuiet` register, asserted
        // above — the general ink measures 3.68:1 there in Dark.
        all.append(Pairing(label: "white on coachingInk fill", foreground: .white, background: AppColor.coachingInk, requirement: .largeTextOrComponent))
        all.append(Pairing(label: "proText on cardBackground", foreground: AppColor.proText, background: AppColor.cardBackground, requirement: .normalText))
        // The startable action is always a filled pill whose label is
        // `Typography.headline` = 18pt bold. That clears WCAG's large-text
        // threshold (14pt bold), so the 3:1 bar applies rather than 4.5:1.
        // Asserted at the component bar deliberately, not to make the suite
        // pass: dark `brandBlue` measures 3.54:1 against white, which is
        // conformant for this size and non-conformant for small text — hence
        // the separate `brandBlueOnWash` register that already exists for small
        // brand-blue copy.
        all.append(Pairing(label: "white on brandBlue pill (18pt bold)", foreground: .white, background: AppColor.brandBlue, requirement: .largeTextOrComponent))
        all.append(Pairing(label: "white on actionPressed pill (18pt bold)", foreground: .white, background: AppColor.actionPressed, requirement: .largeTextOrComponent))
        // Small brand-blue copy has its own register precisely because the
        // standard one does not clear the small-text bar on washed cards.
        all.append(Pairing(label: "brandBlueOnWash on cardBackground", foreground: AppColor.brandBlueOnWash, background: AppColor.cardBackground, requirement: .normalText))
        return all
    }

    @Test("Every design-system text pairing clears AA in both appearances")
    func allPairingsClearAA() {
        var failures: [String] = []
        for pairing in Self.pairings {
            for appearance in Appearance.allCases {
                let background = Self.rgb(pairing.background, appearance)
                let foreground = Self.rgb(pairing.foreground, appearance, over: background)
                let ratio = Self.contrastRatio(foreground, background)
                if ratio < pairing.requirement.rawValue {
                    failures.append(
                        String(
                            format: "%@ [%@] = %.2f:1, needs %.1f:1",
                            pairing.label, appearance.rawValue, ratio, pairing.requirement.rawValue
                        )
                    )
                }
            }
        }
        #expect(
            failures.isEmpty,
            Comment(rawValue: "Contrast failures:\n" + failures.joined(separator: "\n"))
        )
    }

    /// Locks in the two regressions found by the 2026-07-27 audit so they cannot
    /// silently return. `positive` was #199966 (3.44:1 on the warm canvas) and
    /// `caution` was #D48519 (2.79:1) — both used on caption-size delta text.
    @Test("The semantic feedback set stays at its corrected values")
    func semanticFeedbackDoesNotRegress() {
        let canvas = Self.rgb(AppColor.screenBackground, .light)
        let positive = Self.contrastRatio(Self.rgb(AppColor.positive, .light), canvas)
        let caution = Self.contrastRatio(Self.rgb(AppColor.caution, .light), canvas)
        #expect(positive >= 4.5, Comment(rawValue: "positive regressed to \(positive):1 on the light canvas"))
        #expect(caution >= 4.5, Comment(rawValue: "caution regressed to \(caution):1 on the light canvas"))
    }

    /// The specific failure that started this: a hardcoded near-black ink on an
    /// adaptive inner surface. Kept as an explicit regression witness — if
    /// someone reintroduces that literal, this documents why it is wrong.
    @Test("The onboarding regression stays fixed")
    func hardcodedInkOnAdaptiveSurfaceIsUnreadableInDark() {
        let hardcodedInk = (0.14, 0.16, 0.21)
        let innerDark = Self.rgb(AppColor.innerSurface, .dark)
        let bad = Self.contrastRatio(hardcodedInk, innerDark)
        #expect(bad < 1.5, Comment(rawValue: "Sanity: the original hardcoded ink measured 1.01:1 in Dark; got \(bad):1"))

        // The token that replaced it must clear AA in the same place.
        let token = Self.rgb(AppColor.textPrimary, .dark)
        #expect(Self.contrastRatio(token, innerDark) >= 4.5)
    }
#endif
}
