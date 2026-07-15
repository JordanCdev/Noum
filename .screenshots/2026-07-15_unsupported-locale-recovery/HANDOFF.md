# Run: 2026-07-15 · branch:ux-overhaul · HEAD 3969c8171 · prove actionable unsupported-locale recovery without overstating readiness

## Mode
light

## Changes shipped (this run)
- `Noum/SpeechRecognizerViewModel.swift:88` — keeps the established recognizer as the single owner and exposes the exact unsupported on-device locale as a typed recording issue.
- `Noum/SpeechRecognizerViewModel.swift:381` and `Noum/SpeechRecognizerViewModel.swift:1438` — add a DEBUG-only provider seam that emits the same typed local-provider failure for deterministic rendered proof.
- `Noum/NoumApp.swift:126` — makes the rendered fixture's Practice locale deterministic through the existing `LocaleSettingsManager` owner.
- `Noum/TimedPracticeView.swift:1397` — renders specific offline-language guidance, removes the futile retry, and provides a real Back to setup action.
- `Noum/TimedPracticeView.swift:2794` — hides the inactive End Session control while a start/interruption issue owns recovery.
- `Noum/TimedPracticeView.swift:2898` — returns through the established Timed cleanup/reset lifecycle.
- `NoumTests/LocalSpeechProviderTests.swift:104` — verifies that the fixture retains the configured locale and local route.
- `NoumUITests/HomePracticePathPolishUITests.swift:53` — proves the real Timed path at Accessibility XXXL with Reduce Motion, including exact copy, absent dead controls, and successful return to setup.
- `docs/CURRENT_STATE.md:3`, `docs/DEVELOPMENT_PLAN.md:9`, and `docs/RESEARCH_IMPLEMENTATION_AUDIT.md:9` — record local TR-4 proof while retaining NO-GO 18/100 and 0/5 external artifacts.

The source checkout is intentionally dirty and contains pre-existing Lesson, mini-drill, localization, and staged handoff work; this run did not discard or rewrite those changes.

## Screenshots
- `01_home_top.png` — Home tab, seeded active preparation state.
- `02_train_top.png` — Train tab, recommended Timed rep and practice library.
- `03_review_top.png` — Review tab, recent movement and saved-rep entry points.
- `04_profile_top.png` — Profile tab, rating, coaching focus, and transformation question.
- `05_settings_top.png` — Settings tab, including the visible Practice language entry.
- `06_timed_unsupported_locale_axxxl.png` — Timed Practice's actionable unsupported-locale issue at Accessibility XXXL with no generic retry or End Session control.

All six captures were visually inspected after the current build was installed on the booted iPhone 17 simulator. The five tab tops render the expected destination; the focused issue card remains readable and its single recovery action is visible.

## VISION gap
The touched path now matches the trust and restraint goals in `docs/VISION.md`: weak device capability does not become false progress or a generic retry loop, and the user receives a calm, specific recovery. This remains simulator evidence driven by a DEBUG-equivalent typed failure. Real `SFSpeechRecognizer` model availability, manual VoiceOver announcement order, signed physical-device/TestFlight behavior, and longitudinal coaching benefit are still outside the evidence set.

## Next steps to reach desired state
1. Run the attachment-backed signed physical TestFlight checklist for the real unsupported-locale/model boundary, VoiceOver, reduced motion, microphone, offline/reconnect, and recovery behavior; bind it to the exact promoted source rather than treating this fixture as device proof.
2. Freshly rank the remaining bounded local UI evidence gaps; deterministic mini-drill insufficient/eligible branches and broader capability-fallback rendering are candidates.
3. Keep standalone Pace attribution and wider Roleplay prescription routing blocked on explicit product/schema and mixed-client decisions rather than introducing parallel state.

## Regressions checked
- Home / Train / Review / Profile / Settings launch routing — `01_home_top.png` through `05_settings_top.png` — expected destination and coherent seeded shell, no visible regression.
- Unsupported locale at Accessibility XXXL + Reduce Motion — `06_timed_unsupported_locale_axxxl.png` and `/tmp/noum-unsupported-locale-ui-actionable-rm.xcresult` — 1/1 passed; specific guidance, no dead controls, and Back to setup verified.
- Existing generic Filler Control provider-failure recovery — `/tmp/noum-unsupported-locale-ui-generic-regression.xcresult` — 1/1 passed.
- Speech provider and lifecycle boundary — `/tmp/noum-unsupported-locale-focused-actionable.xcresult` — 41/41 passed.
- Complete current-source unsigned unit target — `/tmp/noum-unsupported-locale-full-actionable.xcresult` — 4,223 unique tests / 4,242 device executions passed with zero failures.
- Localization preservation — `Noum/Resources/Localizable.xcstrings` — pre-existing SHA-256 `ee0a735ed8a3c17d5f589d5926a6f2c14e2080a5e35002ed2db3aafb80a6f16a` retained.

## Surfaces needing visual verification (cloud → local queue)
- Real unsupported locale/model availability on a signed physical TestFlight build.
- Manual VoiceOver focus and announcement order for the issue and Back to setup action.
- Signed Release/full-scheme coverage and the complete 14-surface/77-check physical-device evidence contract.
- First-run generic provider-failure recovery on a clean signed simulator/device account; the unsigned isolated lane reaches the existing Keychain bootstrap error before transcription.

## For next run
- **If cloud**: re-rank remaining research rows from current source and prepare product/schema decision notes; do not manufacture external readiness evidence.
- **If local**: run the next deterministic rendered branch only after the ranked gap is confirmed, or collect the signed physical/TestFlight evidence when credentials, promotion, hardware, and operator authority are available.
