# Run: 2026-06-22 · branch:ux-overhaul · HEAD c9e5cd9 · Organic focus check-in

## Mode
light

## Changes shipped (this run)
- Noum/TimedPracticeView.swift:809 — removed the blocking pre-rep focus sheet wiring from Timed Practice; pending intent is only cleared when leaving.
- Noum/SuddenDeathPracticeView.swift:271 — removed the same blocking pre-rep focus sheet wiring from Sudden Death.
- Noum/SessionIntentEngine.swift:122 — kept the historical policy seam, but it now never auto-presents a setup sheet from practice entry.
- Noum/CoachReplyPipeline.swift:41 — detects whether a weekly check-in is due before building coach context.
- Noum/CoachContextBuilder.swift:141 — instructs Noum to use signup motivation and success vision sparingly, as an anchor rather than pressure.
- Noum/CoachContextBuilder.swift:605 — adds a due-only CHECK-IN OPPORTUNITY block for organic chat coaching.
- Noum/AskNoumView.swift:1428 — feeds profile motivation and weekly check-in due state into the starter prompt path.
- NoumTests/NoumTests.swift:20188 — updates the old auto-prompt expectation and adds coverage for organic check-ins and signup-motivation starters.

## Screenshots
- 01_home_top.png — Main launch surface; Ask Noum and case-following entry visible.
- 01_train_top.png — Train tab top; "Your next rep" appears with no "Today's focus?" sheet.
- 01_review_top.png — Review tab; coaching read and progress chart render.
- 01_profile_top.png — Profile tab; voice target and rating card render.
- 01_settings_top.png — Settings/practice profile surface renders.

## VISION gap
This run moves Noum away from interruptive setup friction and toward human-coach timing: ask check-in questions inside the coach relationship, not as a forced modal at the moment the user chose to speak.

Remaining gap: the old SessionIntentPromptView still exists as a retained component, though it is no longer routed from practice entry. Baseline progress/radar visualization and the broader Impromptu setup redesign are still not implemented in this slice.

## Next steps to reach desired state
1. Noum/SessionIntentPromptView.swift — either retire this view or repurpose it into a non-blocking inline/home coaching surface.
2. Noum/BaselineEngine.swift and related progress surfaces — add a real baseline-vs-goal model before any radar/progress visualization.
3. Noum/PracticeModeSelectionView.swift and Impromptu setup files — redesign Impromptu as default-first with settings hidden behind a calm control, not a wall of options.
4. Noum/CoachContextBuilder.swift — add evaluation fixtures for when Noum should ask a weekly check-in versus continue directly into practice.

## Regressions checked
- Train deep link — 01_train_top.png — no pre-rep focus popup appeared.
- Home/main deep link — 01_home_top.png — coach/case entry still renders.
- Review/Profile/Settings deep links — captured without blank frames or splash screens.

## Surfaces needing visual verification
- Actual Timed and Sudden Death in-rep launch after tapping Begin.
- Ask Noum starter chips under a forced weekly-check-in-due profile.
- Any future app-open check-in treatment, if added, should be non-modal and visually verified against the no-friction principle.

## For next run
- **If cloud**: continue model/context/tests work that does not need the simulator.
- **If local**: run the detailed screenshot tour after the Impromptu redesign or baseline visualization work.
