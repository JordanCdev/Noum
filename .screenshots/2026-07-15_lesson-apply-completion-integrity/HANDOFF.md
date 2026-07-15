# Run: 2026-07-15 · branch:ux-overhaul · HEAD 3969c8171 · Lesson Apply completion integrity

## Mode

light, plus three focused attachments from the deterministic Lesson Apply UI lane

## Changes shipped (this run)

- `Noum/Lesson.swift:157` — preserves authored quantity criteria, adds a visible 12-word fallback, and requires terminal word-count/duration evidence before a lesson can pass or earn XP.
- `Noum/LessonView.swift:755` — routes live and deterministic terminal completion through the same eligibility policy and shows calm retry/result states.
- `Noum/LessonStore.swift:378` — clears transient progress and celebrations on account teardown.

## Screenshots

- `01_home_top.png` — Home tab, rendered correctly.
- `01_train_top.png` — Train tab, rendered correctly.
- `01_review_top.png` — Review tab, rendered correctly.
- `01_profile_top.png` — Profile tab, rendered correctly.
- `01_settings_top.png` — Settings tab, rendered correctly.
- `lesson-keyword-only-retry-axxxl.png` — keyword matches remain visible, but the 12-word complete-answer floor withholds completion at Accessibility XXXL.
- `lesson-eligible-evaluation.png` — eligible terminal evidence passes every displayed criterion and enables Continue.
- `lesson-eligible-summary.png` — the verified outcome reaches the existing spaced-practice summary.

## VISION gap

The lesson flow now better supports believable progress and coaching trust: a
semantic fragment cannot masquerade as demonstrated skill. The fallback floor
is still a locally derived heuristic, not professionally calibrated evidence,
and simulator fixtures do not prove provider timing or physical-device speech
capture.

## Next steps to reach desired state

1. Obtain blinded professional calibration for the lesson rubrics and quantity floors before treating them as validated coaching thresholds.
2. Run the terminal receipt/duration paths with live providers on physical TestFlight hardware.
3. Decide whether lesson progress and Profile XP require one durable cross-store reward transaction.

## Regressions checked

- Five-tab shell — `01_*_top.png` — all expected screens rendered; no blank, crash, or wrong-route frame.
- Keyword-only Apply — `lesson-keyword-only-retry-axxxl.png` — no false completion; retry remains accessible with reduced motion.
- Eligible Apply — `lesson-eligible-evaluation.png` and `lesson-eligible-summary.png` — real policy reaches the existing summary.

## Surfaces needing visual verification (cloud → local queue)

- Live unsupported-locale recording error.
- Live microphone interruption and provider-finalization timing.
- VoiceOver reading order on physical hardware.

## For next run

- **If cloud**: audit durable standalone Pace attribution and the account-safe lesson reward transaction boundary.
- **If local**: force the unsupported-locale branch and capture physical-device/TestFlight provider timing when authorized.
