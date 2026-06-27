# Spec — universal first-rep fast-start (the path users actually hit)

Status: **SPEC ONLY — code-shippable but device-felt-QA gated.** Do NOT ship
headless: it changes the live cold-start for every new user with no mic device to
certify the feel. Source: audit panel finding #5,
`docs/COACH_PARITY_EVAL_2026-06-27.md`.

## Problem
This run shipped instant-start for the **auto-guided** first rep — but that path
is behind `AutoGuidedFirstRep.enabled` (default-OFF). The first rep users
actually hit today is **picker → "Begin · Timed"** (or **Home → Begin**), which
arms `PracticeModeQuickStart` but NOT fast-start. So a brand-new user still lands
on the full-screen 15s "Breathe and think" countdown before the mic opens
(`enableThinkingTime` defaults true). That blows the <30s-to-first-word
table-stakes for the path that matters most.

## Verified current mechanics
- `armFastStartOnce()` is only called at the auto-guided fork
  (`ContentView.swift`, `noum://train`, default-OFF).
- The picker hero "Begin" arms QuickStart at `PracticeModeSelectionView.swift`
  (~`:376`) but never arms fast-start.
- `HomeCoachCard.beginRecommendedRep()` (~`:659`) appends the destination but —
  per the audit — does not arm QuickStart at all (verify: it may flash the setup
  page; fix both there).
- The consume + per-rep override machinery already exists and is tested
  (`AutoGuidedFirstRep.consumeFastStartOnce()` + `fastStartActive` in
  `TimedPracticeView`, reset in `resetState`).

## Proposed change (per-rep one-shot, first-ever rep only)
1. Arm `AutoGuidedFirstRep.armFastStartOnce()` for the **first-ever** rep
   regardless of entry point, gated on zero completed reps
   (`PracticeSessionStore.shared.sessions.isEmpty`). Add it next to the existing
   `PracticeModeQuickStart.arm` at the picker hero Begin and in
   `HomeCoachCard.beginRecommendedRep()` (and fix Home to arm QuickStart there
   too so no setup page flashes).
2. Rep 2+ keeps the user's saved 15s countdown (the one-shot is consumed once;
   `resetState` already clears `fastStartActive`).
3. Honest by construction: the rep stays non-pressure ⇒ unrated ⇒ no
   rating/peak/league on n=1.

## Constraints (hard invariants)
- One-shot, consumed once, removed on read.
- Push-to-talk one-shot arm only — no auto-re-arm (echo loop).
- `SoundscapeEngine.stop()` at record start.
- Reduced-motion + a11y unchanged.
- Must reconcile with this run's already-shipped fast-start layout — guard
  against double-arming (check `sessions.isEmpty` AND that the auto-guided fork
  didn't already arm).

## Test plan
- Unit: first-ever rep arms fast-start from picker + Home; rep 2 does not; the
  one-shot is consumed once; persistent prefs unchanged.
- **Felt-QA (the gate, real device):** fresh install → Home Begin and picker
  Begin both go straight to speaking with the prompt visible, no 15s countdown,
  no second setup page; rep 2 shows the countdown; the instant mic-open feels
  calm, not abrupt, for a genuine first-timer.

## Sequence
One device-owning work session, together with the
`AutoGuidedFirstRep.enabled` flag-flip felt-QA — not a separate ticket.
