# Noum wordmarks & brand assets

Noum ships no logo file in the iOS repo — the wordmark is always set in SF Pro Rounded.

- `logo-wordmark.svg` — lowercase `noum` at 42/bold/rounded, text color `--fg-primary`
- `logo-eyebrow.svg` — uppercase `NOUM` at 18/bold/rounded with `tracking: 4px`, muted white for dark-bg use
- `logo-wordmark-blue.svg` — blue variant for card use, fill `--brand-blue`
- `app-icon.svg` — rounded-square app icon placeholder (request real `.icns` / `AppIcon.appiconset` for production)
- `icon-map.md` — SF Symbol → Lucide substitution map for web/prototype work

## Iconography source of truth

iOS: **SF Symbols only**, always a single tint, `.bold` or `.semibold` weight, prefer filled variants.

Web / prototypes: **Lucide** at 1.75px stroke — see `icon-map.md`. This is a flagged substitution; for pixel-perfect iOS mocks, screenshot from Xcode or request PNG exports.
