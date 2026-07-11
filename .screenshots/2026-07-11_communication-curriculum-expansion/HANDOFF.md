# Run: 2026-07-11 · branch:codex/communication-curriculum-expansion · HEAD 2c244b15 · broaden communication practice and make learning repeatable

## Mode
light

## Changes shipped (this run)
- `Noum/Lesson.swift:156` — added transparent, criterion-level evaluation for applied lesson attempts.
- `Noum/LessonStore.swift:81` — added migration-safe spaced-review scheduling and due-review recommendations.
- `Noum/LessonsCatalog.swift:15` — expanded the lesson curriculum from five speaking mechanics to twelve interleaved communication skills.
- `Noum/LessonsHomeView.swift:71` — replaced badge-grid framing with learn, practice, transfer, and revisit language.
- `Noum/RoleplayEngine.swift:168` — added listening, ownership, constructiveness, and inquiry signals to the existing deterministic scorer.
- `Noum/RoleplayScenario.swift:214` — added feedback, boundaries, trust repair, and discovery conversations.
- `Noum/RoleplaySetupView.swift:84` — converted the scenario chooser to a compact divided list.

## Screenshots
- `01_home_top.png` — Home tab, top of view.
- `01_train_top.png` — Train tab, top of view.
- `01_review_top.png` — Review tab, top of view.
- `01_profile_top.png` — Profile tab, top of view.
- `01_settings_top.png` — Settings tab, top of view.
- `02_lessons_top.png` — revised Lessons catalogue at the default content size.
- `03_roleplay_top.png` — Roleplay focused setup at the default content size.
- `04_lessons_accessibility_large.png` — revised Lessons catalogue at Accessibility Large.
- `05_roleplay_accessibility_large.png` — Roleplay focused setup at Accessibility Large.

## VISION gap
The app now trains more of the communication loop—listening, questioning, explanation, feedback, boundaries, and repair—and revisits successful work on an expanding schedule. It still cannot validate nonverbal delivery, multi-person facilitation, intercultural adaptation, or real-world transfer without additional sensing and outcome evidence.

## Next steps to reach desired state
1. Extend `Noum/RoleplaySessionView.swift` from one-turn objection practice to a bounded multi-turn exchange while keeping Fast/Ultra routing and server policy unchanged.
2. Add externally validated listening and feedback rubrics before presenting deterministic lexical signals as anything stronger than practice guidance.
3. Add explicit real-world transfer check-ins to `Noum/LessonStore.swift` rather than treating an in-app pass as proof of workplace behavior.

## Regressions checked
- Five tab roots — `01_*_top.png` — no visual regression in the existing shell.
- Lessons default and Accessibility Large — `02_lessons_top.png`, `04_lessons_accessibility_large.png` — content remains readable and scrollable above the native tab shell.
- Roleplay default and Accessibility Large — `03_roleplay_top.png`, `05_roleplay_accessibility_large.png` — directive, scenario, adjust control, and primary CTA remain visible without clipping.
- Focused route behavior — `FocusedPracticeSetupUITests` — deep links, accessibility identifiers, selected traits, and hidden tab bar passed.

## Surfaces needing visual verification (cloud → local queue)
- The apply-step criterion feedback and retry state require a mocked speech transcript for deterministic screenshot coverage.
- The eight-item Roleplay Adjust sheet should be added to the detailed tour as a named capture.

## For next run
- **If cloud**: add pure rubric fixtures for ambiguous acknowledgements, indirect questions, and culturally varied phrasing.
- **If local**: add transcript injection for lesson apply states, then capture pass, miss, retry, and transfer-summary screens.
