# Run: 2026-07-20 · branch: ux-overhaul · HEAD: c34b0505a

Plan-first training, calmer coaching evidence, and unified post-rep progression.

## Mode

Light tab sweep plus focused UI-test captures for the changed surfaces.

## What changed

- `Noum/PathJourneyView.swift`: replaced the footsteps metaphor with a waypoint, opened the center corridor, made foliage opaque, reduced tree crowding, and shortened supporting copy while preserving the reason and landmark sections.
- `Noum/PracticeModeSelectionView.swift`: made the coach-built rep the default decision and moved the complete catalog behind an optional “Choose for myself” disclosure.
- `ProfileView.swift`: reduced coaching evidence to an at-a-glance focus and next move, with rationale and progress evidence behind separate disclosures.
- `Noum/WeeklyCheckInCard.swift`: replaced sheet-like floating controls with a native pushed screen, one primary save action, and progressive disclosure for optional questions.
- `Noum/AchievementsTreeView.swift`: replaced mixed badge treatments with one calm milestone system and collapsed each track to its next meaningful marker.
- `Noum/SummaryView.swift`: removed production full-screen reward interstitials and placed milestone, skill, practice-level, and unlock progress into one inline post-rep receipt.

## Captures

- `01_home_top.png`
- `01_train_top.png`
- `01_review_top.png`
- `01_profile_top.png`
- `01_settings_top.png`
- `tour_path-marker-top.png`
- `tour_path-marker-bottom.png`
- `tour_ux-train-coach-plan.png`
- `tour_ux-train-free-selection.png`
- `tour_ux-coaching-evidence-overview.png`
- `tour_ux-coaching-evidence-expanded.png`
- `tour_profile-weekly-check-in-sheet.png`
- `tour_ux-practice-milestones.png`
- `tour_S-summary-1top.png`
- `tour_S-summary-2mid.png`
- `tour_S-summary-3bottom.png`

## Verification

- Release simulator build passed.
- Full `NoumTests` suite passed: 4,551 tests, 0 failures.
- Focused UI screenshot tour passed: Path, plan-first Train, evidence overview/details, milestones, weekly check-in, and Summary.
- `git diff --check` passed.
- Final captures were visually inspected after the last hierarchy polish.

## Product notes

- The iPhone home indicator remains system-owned; the redesigned surfaces respect its safe area instead of trying to hide it globally.
- PDF export was intentionally deferred. The evidence hierarchy is now concise in-app; export should be added only when a concrete sharing or archival workflow justifies it.

## Remaining validation

- Run a real-device pass with larger Dynamic Type sizes and Reduce Motion enabled before release sign-off.
- Validate the new plan-first wording with users who regularly switch exercise types.
