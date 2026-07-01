# RALPH iter-17 — fresh live read + trailing-setup-question detector

Date: 2026-07-01 · branch `ux-overhaul` · commit base `0bb4e692`

## R — READ (fresh LIVE run, user-supplied key)
`ANTHROPIC_API_KEY … ./run.sh run` at commit `0bb4e692` (coach + judge
`claude-sonnet-4-6`, real api.anthropic.com):

| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean | **69.4** | 70 | ❌ (within noise) |
| Deep-assessment | 74.9 | 70 | ✅ |
| Trust-repair | 74 | 65 | ✅ |
| Placeholder leaks | 0 | 0 | ✅ |

Range 40–90, median 72. Up from the 67.7 anchor, but the README's own noise band
(same prompt/commit has produced 75.7 and 76.5; per-fixture ±9) means 69.4 vs 70
is **noise, not a miss**. deepAssessment + trustRepair clear their bars.

### Worst-10 diagnosis (from the actual replies, not the headline)
The residual is NOT low-EQ or canned (worst fixtures are `closerTo=between`, EQ
13–20/25). Two real, deterministic patterns:
1. **`tooLong` on groundedRead** — what-do-you-know (40, 122w, intervention 4/15),
   okay-thats-cool-however (47), its-not-easy (48), awkward-pauses (55). The app's
   own `replyLengthLimits` gate repairs these at runtime, so the shipped reply is
   shorter than the raw one the Arena scored — Arena is pessimistic here by design.
2. **Trailing setup question after a real move** — cold-start-no-data (51) gives the
   rep, then asks *"What's the setting you're preparing for?"* — which prompt rule
   40 explicitly bans and rule 57 forbids as an add-on. The prompt is already
   maxed on this; the model still does it ~1 turn in 5.
`exhausted` (58, EQ 20/25) closes with a *gentle* question ("What would feel like
enough rest?") — legitimate per rule 57; the judge over-penalised it (intervention
5/15). Not a defect to chase.

## A — ACT (deterministic eval fidelity, not prompt churn)
New `checks.mjs` detector **`trailingSetupQuestion`** (flag 6): fires only when the
reply ALREADY gives a concrete move AND its last sentence asks the user to supply
situational context the coach should infer (setting / audience / purpose / topic).
Narrowly scoped so a warm offer to continue ("Want the three questions?" — the gold
interview-prep close) and a gentle emotional reflection are NOT flagged. Grounded
in an explicit prompt rule; makes the eval **harsher** (honest), never inflates.

Prompt-wording was NOT touched — it is already maximal on "prescribe, don't defer /
no add-on question" (rules 38, 40, 57), and iters 4–15 prove wording deltas here are
within judge noise. The lever for a prompt-forbidden-but-still-happening pattern is
deterministic detection, not more instruction.

## L / P — verification
- `./run.sh validate` → 0 errors (1 pre-existing warn on 09-confidence-ending).
- `./run.sh test` → **33/33** (4 new tests: fires on cold-start hand-back; does NOT
  fire on the warm offer, the gentle emotional close, or a move-ending reply).
- Applied to this live run's 50 replies, `trailingSetupQuestion` flags exactly **1**
  (cold-start-no-data) — zero false positives on the live corpus.

## H — HARDEN (honest state)
- Live gold mean **69.4 ≈ target within the harness's own noise band.** deepAssessment
  and trustRepair pass. 0 leaks. This is a mature system sitting on the target line.
- The residual is length-discipline on groundedRead (the app repairs at runtime) +
  the occasional banned trailing setup question (now detected) + judge variance.
  None is a low-EQ / canned / fallback failure.
- Not claiming production-ready: the mean is a hair under a noisy 70, and the real
  chat's quality past the length-repair gate still wants live-user validation
  (VISION reserves parity for longitudinal outcomes).

## Next real levers (require your key for attribution)
1. **groundedRead compactness A/B** — a *structural* CONTEXT-block change (surface one
   crisp latest-rep signal so the read is short by construction), attributed via a
   dual-arm blind run. Wording changes are noise; this is the only honest score lever.
2. **Verify the app's runtime length-repair** produces a good short groundedRead reply
   (Swift, credential-free) — closes the Arena-vs-real-app divergence for trust.
