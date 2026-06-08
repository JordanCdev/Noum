# Run: 2026-06-08 · branch:ux-overhaul · HEAD 0a9a0df · M14 typography accessibility pass

## Mode
off

Mode source note: `.Codex/skills/noum-screenshots/.mode` was missing in this
workspace, so this run followed the skill's minimal-handoff path instead of
capturing PNGs.

## Changes shipped (this run)
- `Noum/LoginView.swift` — first-run app name, hero headline, hero subcopy, Google fallback button, and guest button migrated from fixed `.system(size:)` text fonts to `Typography`.
- `Noum/HomeCoachCard.swift` — Home coach card title migrated to a Dynamic-Type-aware Figtree builder.
- `Noum/SettingsView.swift` / `Noum/SettingsRow.swift` — Settings cluster headers, advanced disclosure title, micro labels, and toggle row labels moved onto `Typography`.
- `Noum/BigMomentIntakeView.swift` — real-world moment intake header, subcopy, and category text moved onto `Typography`.
- `Noum/PracticeModeSelectionView.swift` / `Noum/SessionIntentPromptView.swift` — practice picker and session-focus prompt headers/subcopy moved onto `Typography`.
- `Noum/IMPracticeView.swift` — IM setup and ending-state copy moved onto `Typography`.
- `Noum/PathJourneyView.swift` / `Noum/ModeMasteryViews.swift` — journey/mode-mastery headings, pill values, and small mastery badges moved onto `Typography`.
- `docs/CURRENT_STATE.md` — Dynamic Type status corrected so remaining `.system(size:)` call sites are not incorrectly marked complete/intentional.

## Screenshots
- No PNGs captured in this run.

## VISION gap
VISION expects premium readability and low-friction UX. The edited surfaces now
reuse the app-wide type system, but remaining legacy `.system(size:)` text call
sites still need surface-by-surface review before Dynamic Type coverage can be
called complete.

## Next steps to reach desired state
1. Recreate `.Codex/skills/noum-screenshots/.mode` with `light` or `detailed`, then capture login/Home/Settings/Big Moment intake after this typography pass.
2. Continue auditing legacy `.system(size:)` text in practice, summary, lessons, and celebration surfaces, preserving intentional fixed icon/counter/share-card uses.

## Regressions checked
- Simulator compile + focused tests passed via `xcodebuild test -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:NoumTests/ScoreCalibrationTests`.
- `git diff --check` passed.

## Surfaces needing visual verification
- Login first-run hero/buttons.
- Home coach card title.
- Settings top/mid/advanced disclosure.
- Big Moment intake sheet.
- Practice picker and session-focus sheet.
- IM conversation setup and ending states.
- Path Journey and Mode Mastery cards.

## For next run
- **If cloud**: continue code-only typography audit in non-modal surfaces.
- **If local**: run the light screenshot sweep and inspect the four edited surfaces at large Dynamic Type sizes.
