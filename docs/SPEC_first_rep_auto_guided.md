# Spec — auto-guided first rep (close the first 60 seconds)

Status: **SPEC ONLY — felt-QA gated, do not blind-build autonomously.**
Owner of build: a session with on-device QA (real build via xcresult + a human
feel pass on the cold-start moment). Source: highest-value gap in
`docs/COACH_PARITY_EVAL_2026-06-22.md` (acquisition 5.5) and roadmap move #1 in
`docs/COACH_PARITY_EVAL_2026-06-20.md`.

## Scope
First-run **only**: replace the "land on the practice picker" moment with one
auto-guided ~20–30s micro-rep that gets the user *speaking* before any decision,
then shows one honest "your first read" (fillers + wpm). Returning users are
untouched — they keep the deliberate picker.

## Product goal
The verified blocker on the acquisition axis: time-to-first-spoken-word > 60s
because first-run routes through a picker + Begin tap + countdown
(`CoachingOnboardingView.swift:563-575` → `noum://train` →
`ContentView.swift:1382` `.practiceSelection`). Speeko/Yoodli get the user
performing in seconds; Noum's depth is real but invisible until after this
friction. Closing it is the single biggest lever from 7.2 toward ~8.5.

## Verified current flow (do not break the returning-user branch)
1. `CoachingOnboardingView` "Start Practicing" sets
   `DeepLinkRouter.shared.pending = noum://train` (first-run only;
   `isEditingExistingProfile` saves silently).
2. `ContentView` consumes the deep link → `replaceNavigationPath(.practiceSelection)`.
3. `PracticeModeSelectionView` computes `recommendedMode` / `recommendedOption`
   and shows a "Begin · {title}" CTA — but never auto-starts; a rep needs a tap.

## Proposed change
- Gate on `FirstRunOnboardingManager.shared.hasSeen` having *just* flipped (a
  one-shot "first rep not yet done" flag, e.g. `firstRepCompleted == false`),
  **and** a feature flag (`AutoGuidedFirstRep.enabled`, default off until felt-QA
  signs off). When both true, the `noum://train` consumption routes to a new
  lightweight **GuidedFirstRepView** instead of `.practiceSelection`.
- GuidedFirstRepView:
  - One sentence of coach framing ("Let's hear you for 20 seconds — just answer
    out loud. No score, no streak."). No paywall, no celebration.
  - Auto-arms the mic **exactly once** with a visible prompt + countdown, using
    the existing session-start path / `TimedPracticeView` engine. Reuse, do not
    fork, the rep pipeline.
  - On stop → one honest "your first read": fillers + wpm only, framed as a first
    read (no rating, peak, league, or trend claim — `hasRatedEvidence` is false on
    a single rep; respect it). One CTA into Home.
  - A persistent one-tap escape ("Pick a different drill") that drops to
    `.practiceSelection`, so the picker is never *removed*, only deferred.
  - Set `firstRepCompleted = true` on completion or escape so it never re-fires.

## Constraints to respect (hard invariants)
- **Push-to-talk / echo loop:** a ONE-SHOT auto-arm is allowed; an auto-*re*-arm
  loop is NOT — it makes the mic transcribe TTS (see `LiveCoachCallView` push-to-
  talk notes, `39d5d03`). The guided rep arms once and stops; it never re-opens
  the mic on its own.
- **Soundscape lifecycle:** if pre-rep ambience plays, `SoundscapeEngine.stop()`
  must fire the instant recording starts (`soundscape_lifecycle` invariant).
- **No fake progress / no overclaim:** single-rep read is fillers + wpm only,
  honestly framed; no celebration, no earned-state claims.
- **Reduced motion + a11y:** countdown + reveal respect reduced-motion; the rep
  prompt and "your first read" carry accessibility labels.

## Files
- New: `Noum/GuidedFirstRepView.swift`, `Noum/AutoGuidedFirstRep.swift` (flag +
  one-shot state), tests in `NoumTests/NoumTests.swift`.
- Edit: `Noum/ContentView.swift` (`noum://train` branch — first-run fork),
  `Noum/NoumApp.swift` (wire the one-shot flag alongside `firstRunOnboarding`),
  reuse `TimedPracticeView` / `SummaryView` for the rep + read.
- Leave `PracticeModeSelectionView` and the returning-user route unchanged.

## Test plan
- Unit: routing fork fires only when `hasSeen && !firstRepCompleted && flag`;
  one-shot never re-fires; single-rep read exposes no `hasRatedEvidence`-gated
  claim; escape hatch sets the flag and routes to `.practiceSelection`.
- **Felt-QA (the gate, on a real build via xcresult — NOT UI-test injection):**
  cold-start path AND returning-user path both verified; time-to-first-spoken-
  word measured < 60s; the read reads honest, not hype; mic arms once and does
  not echo.

## Why this is spec-only
This is the make-or-break first impression and it overlaps the live onboarding
work in flight on `ux-overhaul`. A hands-off autonomous build would risk both a
felt regression at the most important UX moment and a merge collision. Build it
in a session that can run the device + own the feel pass.
