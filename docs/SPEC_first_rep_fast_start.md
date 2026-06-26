# Spec — auto-guided first rep: instant start (close the 15s gap)

Status: **SPEC ONLY — blocked by concurrency + felt-QA gated.**
Owner of build: the session that lands the in-progress mic-readiness-guard slice
(it occupies `TimedPracticeView.swift`), with the on-device felt-QA pass that flips
`AutoGuidedFirstRep.enabled`. Source: role-synthesis in
`docs/COACH_PARITY_EVAL_2026-06-26_noum2.md` (highest-leverage first-rep move).

## Problem
With `AutoGuidedFirstRep.enabled` ON, a brand-new user is routed straight into the
Timed rep — but the rep still runs the **15s "prep countdown"** before they may
speak, and the seeded prompt can be hidden. So "speak in seconds" becomes "wait 15s,
then speak," which defeats the entire acquisition lever. The benchmark to beat is
<30s app-open-to-first-word *with the words supplied*; the countdown alone blows it.

## Verified current mechanics (do not break the returning-user path)
- `TimedPracticeView` reads two persistent prefs:
  - `@AppStorage("timedPractice.enableThinkingTime")` default **true** (`:692`) → the
    15s prep countdown (`useThinkingTime` at `:2653`, `:3001`).
  - `@AppStorage("timedPractice.keepPromptVisible")` default **false** (`:690`).
- The QuickStart auto-begin handshake is consumed in `.task` at `:838`
  (`PracticeModeQuickStart.consume(for: .timed)`), right where the seeded prompt is
  consumed (`consumeSeededPrompt()` at `:839/:949`, reading the exact key
  `AutoGuidedFirstRep.seedFramingPrompt()` writes).

## Why we must NOT just flip the AppStorage keys
`AutoGuidedFirstRep` is clean and *could* set `enableThinkingTime=false` +
`keepPromptVisible=true` next to `seedFramingPrompt()`. **Don't** — those are the
user's *persistent* practice preferences. Overwriting them silently changes every
future rep's behaviour without the user choosing it (a silent-pref-mutation the
product rightly avoids). The fix must be a **per-rep one-shot override** that leaves
persistent prefs untouched.

## Proposed change (per-rep one-shot, mirrors the seeded-prompt contract)
1. **`Noum/AutoGuidedFirstRep.swift` (clean — safe to edit now):** add a one-shot
   flag written at the fork alongside the prompt seed, e.g.
   `UserDefaults.standard.set(true, forKey: "timedPractice.fastStartOnce")`.
2. **`Noum/TimedPracticeView.swift` (BLOCKED — land with the mic-guard slice):** in the
   `.task` at `:838`, when `PracticeModeQuickStart.consume(for: .timed)` succeeds,
   also consume `fastStartOnce` (read-then-remove, exactly like `consumeSeededPrompt()`):
   if set, drive **this rep only** with thinking-time off + prompt visible — using
   local `@State` overrides, NOT by writing the `@AppStorage` prefs — so the user's
   saved prep-countdown / prompt preferences are never mutated.
3. Returning users and any rep that isn't the auto-guided first rep are untouched
   (the flag is only ever written by the first-run fork in `ContentView.swift:1412`).

## Constraints (hard invariants)
- One-shot, consumed once, removed on read (an app-kill mid-rep can't re-apply it).
- Push-to-talk one-shot arm only — no auto-re-arm (echo loop).
- `SoundscapeEngine.stop()` at record start (soundscape lifecycle).
- Honesty unchanged: non-pressure ⇒ `isRated` false ⇒ no rating/peak/league on n=1.
- Reduced-motion + a11y unchanged.

## Test plan
- Unit (in `NoumTests`): `fastStartOnce` is written by the fork, consumed-and-removed
  on the first Timed `.task`, never present on a returning-user rep; persistent
  `enableThinkingTime` / `keepPromptVisible` AppStorage values are unchanged after an
  auto-guided rep.
- **Felt-QA (the gate, real device):** with the flag ON, cold-start a fresh account →
  speaking on a visible prompt in ~2–3s (no 15s countdown); the user's Settings still
  show their chosen prep-countdown default afterward; returning user still gets their
  saved behaviour.

## Sequence
After the unstaged mic-readiness-guard slice lands (so the Timed edit applies to the
final arming path), and together with the `AutoGuidedFirstRep.enabled` flag-flip
felt-QA — these are one device-owning work session, not separate tickets.
