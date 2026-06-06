# Routine 6 — Mid-session goal-aware HUD (M5 stub closing) (Night 3, 05:00 daily)

## Slot
Night 3, 05:00 local time.

## Purpose
Pre-dawn focused code work to chip away at a STUBBED feature flagged in `docs/CURRENT_STATE.md` under "Stubbed / placeholder":

> Goal-driven coaching feedback in mid-session UI — the goal is captured and now reaches post-session coaching surfaces ... Mid-session live UI still doesn't read the goal — that's a separate surface and probably the right next push (e.g. live HUD adapts copy for the user's voice goal during the rep).

Each night: one small step toward closing this stub. Cloud writes blind (no simulator); flags every UI change for visual verification.

## Prompt

```
You're closing one of Noum's last stubbed features: making the mid-session live UI goal-aware. Per `docs/CURRENT_STATE.md`, the user's goal is captured and reaches POST-session surfaces, but the LIVE HUD during a rep doesn't read it. Your job: chip away at this one step per run.

Running on Linux. Write Swift code blind. No simulator verification. Flag visual verification needs.

## Required reading (every run)

1. `CLAUDE.md`
2. `docs/VISION.md` — pillar 5 "Personalized coaching: adapts to the user's actual patterns over time"
3. `docs/CURRENT_STATE.md` — read the entire "Goal-driven coaching feedback in mid-session UI" stub paragraph + the surrounding context (M5 Coach memory work)
4. `Noum/Noum/CoachingProfileStore.swift` — where `CoachingProfile.goal` and `displayableGoal` live
5. `Noum/Noum/SpeakingStyleGoal.swift` (or `Noum/Noum/DrillSystem.swift` which contains `alignedSkillAreas`) — the goal → skill-area alignment map
6. `Noum/Noum/LiveEloquenceHUD.swift` — one of the in-rep HUD surfaces; understand its current API
7. `Noum/Noum/TimedPracticeView.swift`, `Noum/Noum/SuddenDeathPracticeView.swift`, `Noum/Noum/AhCounterView.swift`, `Noum/Noum/IMPracticeView.swift` — the four practice views with live HUDs
8. The last 7 `.screenshots/<date>_goal-hud/HANDOFF.md` from cloud — what's been done already

## Pick today's step

Pick the smallest concrete extension of the live HUD that surfaces the user's goal. Sequence (do them in order across runs — never two steps in one run):

1. **Pass `CoachingProfile.goal` into the HUD as a parameter.** Add a non-breaking optional `userGoal: SpeakingStyleGoal?` to `LiveEloquenceHUD` (or equivalent). Default nil. Wire one practice view (start with TimedPracticeView) to pass it in.
2. **Show a goal-aligned ribbon when a relevant detection happens.** When a rhetorical device fires in a category that aligns with the user's goal (per `alignedSkillAreas`), add a subtle "Closer to your <voice> voice" sub-line to the existing HUD card. ~6pt smaller than the main detection text.
3. **Repeat step 1+2 for SuddenDeathPracticeView.**
4. **Repeat for AhCounterView.**
5. **Repeat for IMPracticeView.**
6. **Pass the goal into the live filler-feedback path too** — when a filler fires under pressure on a "concise" voice goal, the HUD shows the alignment ("Closer to your concise voice" never; "One filler — pressure showing" + a faint tint shift would respect the alignment subtly).

If steps 1–5 are done, propose a step 7 from the existing code's natural extensions. Don't reinvent.

## Brand + engineering rules

- The HUD changes must be SUBTLE. The brand rule: motion + color + shape, never noisy. A new ribbon should be ~12pt body weight in the tint, fade in over 0.4s, fade out after the detection clears.
- Never shame. If the user's goal is "concise" and they're going long, the HUD does NOT say "Your concise voice is slipping." It silently NOT-fires the alignment ribbon. Pure positive surfacing.
- The Goal is captured per-account in `CoachingProfile.goal`. Always read from `CoachingProfileStore.shared.profile.goal` — don't pass strings around.
- All tokens from DesignSystem; no literal hex.
- Reduced-motion: the ribbon fades respect `@Environment(\.accessibilityReduceMotion)` — when reduced-motion is on, the ribbon snaps in/out without animation.

## Write HANDOFF.md at `.screenshots/<YYYY-MM-DD>_goal-hud/HANDOFF.md`

Sections:
- Step number done (1–6) + which file(s) touched
- API additions (e.g. "LiveEloquenceHUD gained `userGoal: SpeakingStyleGoal?` parameter")
- **Surfaces needing visual verification** — list every practice view + describe what the next local run should look for ("TimedPracticeView: after a tricolon detection, look for a subtle 'Closer to your concise voice' sub-line under the eloquence card")
- VISION gap closing: how much of the M5 stub is now closed (percentage estimate)
- Branch name + commit SHA

## Commit policy
- Commit on `cloud/goal-hud-step<N>-<YYYY-MM-DD>`. Push.
- Message: `M5: live HUD step <N> — <what>`.

## Don't
- Don't try to close the entire stub in one run. One step.
- Don't change the post-session goal surfaces — those already work.
- Don't redesign the HUD layout. Add to it.
- Don't add new managers / new stores.
- Don't open PRs.
- Don't add unit tests in this routine (test coverage is Routine 5's job).
```
