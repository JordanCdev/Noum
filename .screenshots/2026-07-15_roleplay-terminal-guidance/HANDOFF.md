# Run: 2026-07-15 · branch:ux-overhaul · HEAD 5987636f · truthful terminal Roleplay guidance

## Mode

light

## Changes shipped (this run)

- `Noum/RoleplayView.swift:123` — derives feedback/completion presentation from one cached engine transition, preserving exact pre-terminal promises while reframing terminal recommendations as future practice.
- `Noum/RoleplayView.swift:431` — resolves the next turn once at submission and consumes the same value during advancement.
- `Noum/RoleplayView.swift:519` — exposes stable completion accessibility identifiers and cites the final attempted result pressure.
- `Noum/NoumApp.swift:315` — mounts deterministic DEBUG-only Roleplay fixtures for rendered state verification.
- `NoumTests/NoumTests.swift:52183` and `NoumUITests/RoleplayTerminalGuidanceUITests.swift:3` — cover all retry-copy modes plus pre-terminal, unavailable, and fourth-attempt rendered paths.

## Screenshots

- `01_home_top.png` — Home tab, top of view
- `01_train_top.png` — Train tab, including the Roleplay library entry
- `01_review_top.png` — Review tab, top of view
- `01_profile_top.png` — Profile tab, top of view
- `01_settings_top.png` — Settings tab, top of view
- `roleplay_terminal_feedback_axxxl.png` — fourth-attempt feedback at Accessibility XXXL with “Practice focus” and “See results”
- `roleplay_terminal_completion_axxxl.png` — completion at Accessibility XXXL with four attempts, final Easy pressure, and future-practice guidance

## VISION gap

The touched flow now behaves like a trustworthy coaching system at the local
terminal boundary: it distinguishes a deliverable next turn from advice for a
future run and avoids false certainty when a transition is unavailable. The
original research still requires independently calibrated coaching outcomes,
longitudinal transfer, and production launch evidence. These simulator fixtures
bypass microphone capture and cannot prove those requirements.

## Next steps to reach desired state

1. Run the microphone-driven fourth-attempt flow on a signed physical TestFlight build and retain accessibility plus interruption evidence under `docs/TESTFLIGHT_QA.md`.
2. Decide the router/measurement contract before allowing interpersonal-pressure prescriptions to select Roleplay.
3. Define a persisted finalized turn-duration contract before restoring any duration-normalized Roleplay filler or pace coaching.

## Regressions checked

- Home, Train, Review, Profile, and Settings deep links — five light-sweep frames — no launch, route, or top-level layout regression.
- Pre-terminal adaptive Roleplay transition — deterministic UI test — exact “Next attempt” promise advances to the projected Realistic turn.
- Unavailable Roleplay transition — deterministic UI test — fails closed into results without promising a rung or objection.
- Fourth-attempt feedback and completion — retained Accessibility XXXL frames — readable, scrollable, and no nonexistent next-turn promise.

## Surfaces needing visual verification (cloud → local queue)

- Signed physical-device microphone completion, VoiceOver announcement order, Reduce Motion, interruption/retry, and real provider behavior remain unverified.

## For next run

- **If cloud**: re-rank remaining research rows that do not require product/schema authority; do not enable competitive or social production paths.
- **If local**: use an authorized signed TestFlight build for the physical Roleplay evidence above; simulator repetition does not move the production gate.
