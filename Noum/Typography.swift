import Foundation
#if canImport(SwiftUI)
import SwiftUI
import UIKit
#endif

#if canImport(SwiftUI)

// MARK: - Typography
//
// Single source of truth for the Noum type system after the M3 redesign.
// Display / rounded → **Figtree** (variable, 300–900). Body / UI → **Manrope**
// (variable, 200–800). The variable fonts ship in the bundle as TTF and are
// registered via Info.plist `UIAppFonts`.
//
// Apple's `Font.custom(_:size:relativeTo:)` resolves variable fonts by family
// name and binds the size to a `Font.TextStyle` so the result tracks Dynamic
// Type. A weight is then applied with `.weight(_)`. SF Pro Rounded / SF Pro
// Text remain the fallbacks if Figtree/Manrope fail to load (e.g. preview
// targets).

enum Typography {
    enum Family {
        static let display = "Figtree"
        static let text = "Manrope"
    }

    // MARK: - Roles
    //
    // Roles map directly to the design-system spec in
    // `.claude/skills/noum-design/colors_and_type.css`. Sizes / weights /
    // line-heights all match the production token set.
    //
    // Every role binds to a `TextStyle` via `relativeTo:` so Dynamic Type
    // scales the whole catalog. The numeric size is the rendered point size
    // at the system's default text size (.large / "Regular") — pick the
    // closest `TextStyle` family so the scaling curve matches user intent
    // (bigger headlines scale faster than caption text under Larger Text).

    /// 42 / bold / rounded — splash "Noum"
    static let display = Typography.figtree(size: 42, weight: .bold, relativeTo: .largeTitle)
    /// 40 / bold / rounded — login hero
    static let hero = Typography.figtree(size: 40, weight: .bold, relativeTo: .largeTitle)
    /// 30 / bold / rounded — screen titles ("Choose your next rep")
    static let screenTitle = Typography.figtree(size: 30, weight: .bold, relativeTo: .title)
    /// 26 / semibold / rounded — section heroes ("Hello, Jordan")
    static let sectionHero = Typography.figtree(size: 26, weight: .semibold, relativeTo: .title2)
    /// 28 / bold / rounded — big stat values ("Speaker 1", rating numbers)
    static let bigStat = Typography.figtree(size: 28, weight: .bold, relativeTo: .title)
    /// 52 / bold / rounded — XL stat values (score reveal hero)
    static let statHero = Typography.figtree(size: 52, weight: .bold, relativeTo: .largeTitle)
    /// 20 / bold / rounded — card titles
    static let cardTitle = Typography.figtree(size: 20, weight: .bold, relativeTo: .title3)
    /// 18 / bold / rounded — recommendation/headline copy
    static let headline = Typography.figtree(size: 18, weight: .bold, relativeTo: .headline)
    /// 16 / bold / rounded — sub-card headers
    static let cardLabel = Typography.figtree(size: 16, weight: .bold, relativeTo: .headline)
    /// 16 / medium / text — login subcopy
    static let subheadline = Typography.manrope(size: 16, weight: .medium, relativeTo: .subheadline)
    /// 15 / regular / text — body / mode descriptions
    static let body = Typography.manrope(size: 15, weight: .regular, relativeTo: .body)
    /// 13 / semibold / text — labels, targets, badges
    static let caption = Typography.manrope(size: 13, weight: .semibold, relativeTo: .footnote)
    /// 11 / semibold / text — minor labels, secondary chips
    static let captionSmall = Typography.manrope(size: 11, weight: .semibold, relativeTo: .caption)
    /// 10 / bold / rounded — uppercase micro-labels (tracking 0.8)
    static let micro = Typography.figtree(size: 10, weight: .bold, relativeTo: .caption2)
    /// 10 / semibold / rounded — nav labels (TRAIN, REVIEW)
    static let nav = Typography.figtree(size: 10, weight: .semibold, relativeTo: .caption2)

    // MARK: - Builders

    /// Figtree at the requested size + weight + Dynamic-Type anchor.
    /// `relativeTo:` is required so every custom font in the app scales
    /// with the user's text-size preference rather than ignoring it.
    static func figtree(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) -> Font {
        Font.custom(Family.display, size: size, relativeTo: style).weight(weight)
    }

    /// Manrope at the requested size + weight + Dynamic-Type anchor.
    static func manrope(size: CGFloat, weight: Font.Weight, relativeTo style: Font.TextStyle) -> Font {
        Font.custom(Family.text, size: size, relativeTo: style).weight(weight)
    }

    /// Figtree variant for ad-hoc numeric / stat displays that don't fit a
    /// named role. Pick the closest `TextStyle` family so Dynamic Type
    /// scaling tracks the visual weight.
    static func figtreeNumeric(size: CGFloat, weight: Font.Weight = .bold, relativeTo style: Font.TextStyle = .title) -> Font {
        figtree(size: size, weight: weight, relativeTo: style).monospacedDigit()
    }

    /// Monospaced-digit variant for any role. Use on stat values + counters
    /// so they don't wobble when the digits change.
    static func monoDigit(_ font: Font) -> Font {
        font.monospacedDigit()
    }
}

// MARK: - View extensions

extension View {
    /// Apply the canonical Noum micro-label treatment in one line:
    /// uppercase, 0.8 tracking, secondary tint.
    func microLabel(_ tint: Color = .secondary) -> some View {
        self
            .font(Typography.micro)
            .foregroundStyle(tint)
            .textCase(.uppercase)
            .tracking(0.8)
    }

    /// Apply the canonical Noum nav-label treatment:
    /// uppercase, 0.4 tracking.
    func navLabel(_ tint: Color = .primary) -> some View {
        self
            .font(Typography.nav)
            .foregroundStyle(tint)
            .textCase(.uppercase)
            .tracking(0.4)
    }
}

// MARK: - Font registration verification

/// One-time best-effort log of registered font families. Useful when
/// debugging "is Figtree actually loaded?" without breaking release builds.
enum TypographyDebug {
    static func logRegisteredFamiliesOnce() {
        #if DEBUG
        guard !hasLogged else { return }
        hasLogged = true
        let figtreeAvailable = UIFont.fontNames(forFamilyName: Typography.Family.display).count > 0
        let manropeAvailable = UIFont.fontNames(forFamilyName: Typography.Family.text).count > 0
        print("[Typography] Figtree loaded: \(figtreeAvailable). Manrope loaded: \(manropeAvailable).")
        if !figtreeAvailable {
            print("[Typography] Available rounded-ish families:")
            UIFont.familyNames
                .filter { $0.lowercased().contains("rounded") || $0.lowercased().contains("fig") }
                .forEach { print("  - \($0)") }
        }
        #endif
    }
    private static var hasLogged = false
}

#endif
