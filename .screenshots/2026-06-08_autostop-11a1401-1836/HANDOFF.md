# Run: 2026-06-08 1836 · branch:ux-overhaul · HEAD 11a1401 · auto-stop capture

Auto-captured manually through the noum-screenshots light workflow after the
ordinary badge typography pass. This folder is local visual evidence only; PNGs
are gitignored.

## Mode
`light` (read from `.agents/skills/noum-screenshots/.mode`)

## Screenshots
- `01_home_top.png` — Home tab
- `01_train_top.png` — Train (Practice mode picker)
- `01_review_top.png` — Review (Session history)
- `01_profile_top.png` — Profile
- `01_settings_top.png` — Settings

All five PNGs are nonblank 1206x2622 captures, but visual spot-checking showed
all five landed on the same Home/Train-like surface with the bottom rail visible
instead of distinct tab roots. Treat this sweep as launch/render evidence only,
not per-tab visual verification.

## What this run did
- Installed the freshly built app from
  `DerivedData/Noum/Build/Products/Release-iphonesimulator/Noum.app` on the
  booted iPhone 17 simulator.
- Ran `.agents/skills/noum-screenshots/capture.sh` in `light` mode after commit
  `11a1401`.
- Found a capture/deep-link limitation: `noum://train`, `noum://review`,
  `noum://profile`, and `noum://settings` did not produce distinct root-tab
  screenshots in this run.

## For next run
- If cloud: read this HANDOFF + any newer ones for richer context.
- If local: prefer the detailed `ScreenshotTour` or fix the light deep-link
  capture route before using light screenshots as tab-level QA.
