# Noum App Icon — Xcode Drop-In

## Which folder do I use?

**`AppIcon.appiconset/` ← use this for any iOS 17+ project (recommended)**

Single-size assets with three appearances (Any / Dark / Tinted). Xcode 15+ auto-generates every device size from the 1024×1024 source. This is Apple's current recommended approach.

**`AppIcon-legacy/`** — fallback for older Xcode versions or if you prefer hand-rolled sizes. iPhone, iPad, and marketing slots covered. No dark/tinted variants.

---

## Install (iOS 17+ / Xcode 15+)

1. In Xcode, open `Assets.xcassets`.
2. Delete the existing `AppIcon` set (right-click → Remove).
3. Drag the entire `AppIcon.appiconset` folder from this project into `Assets.xcassets`.
4. Select the new `AppIcon` set — you should see three slots: **Any Appearance**, **Dark**, **Tinted**, all populated.
5. Build and run. The system handles every device size automatically.

## Install (legacy)

1. Open `Assets.xcassets`, delete the existing `AppIcon`.
2. Drag `AppIcon-legacy` in, then rename it to `AppIcon.appiconset` (right-click → Show in Finder, rename folder, drop back in).
3. All slots should populate from the included `Contents.json`.

---

## Files

```
AppIcon.appiconset/
├── Contents.json
├── AppIcon-1024.png         Any Appearance (light)
├── AppIcon-1024-Dark.png    Dark
└── AppIcon-1024-Tinted.png  Tinted (grayscale; system applies user accent)

AppIcon-legacy/
├── Contents.json
├── Icon-20-2x.png  …  Icon-1024.png   (12 sizes, light only)
```

Source vectors (for future edits):
- `assets/app-icon.svg` — primary
- `assets/app-icon-dark.svg` — dark variant source
- `assets/app-icon-tinted.svg` — tinted (grayscale) source

---

## Notes on the variants

- **Any** — full glossy 3D render: warm orange body, deep-orange smiling bubble, yellow speaking bubble.
- **Dark** — body shifted to a deep warm near-black; bubbles retain their saturation so the brand mark stays recognisable on a Dark Mode home screen.
- **Tinted** — authored in grayscale per Apple's spec. iOS applies the user's chosen accent at runtime; do NOT pre-tint or it will double-tint.

If you change the design, edit `assets/app-icon.svg` and re-run the export — every PNG re-renders from the same vector source so the three variants stay in sync.
