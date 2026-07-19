# Handoff — 2026-07-19 · coach accessibility, rewrite reachability, dead code, funnel

Branch: `ux-overhaul`. Base commit at session start: `b1fc40d24`.

## What changed

1. **VoiceOver on the live call.** New `Noum/AccessibilityAnnouncer.swift` — the
   first announcement helper in the codebase. `LiveCoachCallView` posted no
   announcements at all, so a VoiceOver user got silence when the coach's caption
   or state line changed. Announcements are suppressed when Aloud is on and a
   voice is available (the reply is already spoken — announcing would
   double-speak), and user partial transcripts are never announced.
2. **13 `.isHeader` traits + 7 hints** across `SummaryView`, `AskNoumView`,
   `LiveCoachCallView`. `.isSelected` was deliberately NOT added — all four
   candidate chip rows were checked and none carries selection state.
3. **Rewrite card promoted** out of the collapsed `expandableDetailsSection` to
   directly beneath the debrief, in both Summary branches. Free users get
   `LockedRewritePreviewCard` (real sentence quoted, rewrite gated, no service
   call, nothing fabricated). Pro gating unchanged.
4. **Bug fixed** — `AIRewriteService.originalSnippet` returned the entire
   transcript as "your opening" when the text had no sentence punctuation.
5. **360 lines of dead code deleted** — `PostRepFixCard`, `PostRepWinCard`,
   `PostRepReadCard`, `ConceptIconChip`.
6. **Funnel denominators** — `rep.started`, `summary.viewed` on the existing
   `FlowObservability`. No SDK, no privacy-manifest change.

## Screenshots in this folder

| File | What it proves |
|---|---|
| `10_rewrite_card_pro.png` | The Pro rewrite card rendering **above** the "NEXT REP" drill card and Ask Noum — its new position. Captured from the `testOnDeviceRewriteCanBeSavedAndOpenedFromSummary` attachment. |
| `11_rewrite_card_locked_free.png` | The new `LockedRewritePreviewCard` for a free user: real transcript sentence under "Your version", lock line, "Unlock with Pro". Also shows the truncation fix working (snippet ends `before…`). Captured from the new `testLockedRewritePreviewRendersForFreeUsersWithoutOpeningDetails` attachment. |
| `01_home_top.png` | Home renders clean — no launch/render regression. |

## Sweep coverage — read this before trusting it

The skill mode is `detailed`, but the **full 5-tab sweep and UI tour were NOT
run**. Two honest reasons:

- The simulator entered a wedged state (`SBMainWorkspace` `RequestDenied` on every
  `simctl launch`) that survived shutdown, boot, and `erase`. A second automated
  agent was driving simulators and building into `./DerivedData/Noum`
  concurrently. `01_home_top.png` is from earlier in the same session, before the
  wedge.
- The two captures that matter here came from UI-test attachments of the actual
  changed surfaces, which is stronger evidence than a generic tab-top tour would
  have given for this particular change.

**Not visually verified:** Train / Review / Profile / Settings tab tops on this
build; the accessibility traits and hints (they are not visible in screenshots —
they need Accessibility Inspector or a VoiceOver pass on device); reduced-motion
behaviour; Dynamic Type at large sizes.

**The VoiceOver announcements have NOT been heard.** Their logic is verified by
inspection and compiles, but no VoiceOver session was run. That is the single
highest-value manual check for the next session: turn VoiceOver on, start a coach
call with Aloud OFF (confirm the caption is announced) and then with Aloud ON
(confirm it is NOT announced twice).

## Test state

- Full unit suite: **4464 passed / 49 failed** — byte-identical to a stashed
  baseline, so this work adds zero new failures.
- 10 new unit tests in `NoumTests/RewriteSnippetAndFunnelTests.swift` pass.
- UI: 5 of 6 pass in `GoalOutcomeLoopUITests` + `FastLaneFirstSessionUITests`.

### Two pre-existing failures — confirmed against baseline, do not re-diagnose

- `GoalOutcomeLoopTests/showcaseSeedUsesComparableEvidenceBeforeOfferingAMilestone`
  — fails only under parallel execution, passes in isolation. Running it alone to
  "check" it gives the wrong answer and makes unrelated changes look guilty.
- `GoalOutcomeLoopUITests/testActiveWeekPhraseLaunchesExactPromptFromHome` — fails
  on a clean baseline with all changes stashed.

## Production readiness

Unchanged: **NO-GO**, 0/5 external artifacts. Nothing in this pass moves that
gate — the five artifacts are live-provider sweep, blinded professional review,
longitudinal real-user transfer, physical TestFlight QA, and operational launch
sign-off. All require hardware, real users, or the operator.
