# Run: 2026-06-26 · branch:ux-overhaul · HEAD 97b5097 · live caption scaffold-label fix

## Mode
focused

## Changes shipped (this run)
- `Noum/LiveCoachCallView.swift` — live call captions now render as plain spoken-caption text with a final sanitizer pass, so stored or seeded coach rows cannot visually leak `Read:` / `Move:` scaffold labels.
- `NoumTests/NoumTests.swift` — added a sanitizer regression test proving live captions stay clean after stored-reply normalization.

## Screenshots
- `live-caption-plain-scaffold-fixed.png` — forced live-call caption with the old plain `Read:` / `Move:` fixture; visible card now reads naturally without scaffold labels.

## VISION gap
The change supports conversational intelligence and personalized coaching trust. A live coach surface must not reveal internal prompt scaffolding; it should feel like a human coach speaking in the moment.

## Next steps to reach desired state
1. Keep rich formatting in typed chat, but keep the live call plain and spoken-first.
2. Add OCR/pixel-level visual assertions if this caption surface regresses again; current UI tests verify accessibility text and this run adds manual visual evidence.

## Regressions checked
- Live caption sanitizer unit suite — passed.
- Live call forced plain scaffold UI test — passed.
- Fresh simulator screenshot — no visible `Read:` or `Move:` labels.

## Surfaces needing visual verification
- None for this patch.

## For next run
- If local: reuse `UI_TESTING_LIVE_FORCE_PLAIN_SCAFFOLD_CAPTION` for quick visual verification after live-call caption changes.
