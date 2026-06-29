# Coach-parity eval — 2026-06-29 (autonomous `noum-1` run)

**One-line:** 15th iteration. Instead of a 15th near-identical scorecard or
throwing autonomous code into a hot zone an active session was editing, a
read-only 4-role panel was aimed at one question — *is there any genuinely new,
non-human-gated, collision-safe lever the 14 prior runs missed?* — and it found
one. Shipped it: per-voice coaching rubrics, fixing a real CLAUDE.md invariant
violation. Full app build + tests GREEN in an isolated worktree. **No push.**

Commit: `52fc6aea`.

---

## Context this run had to respect

- **Heavy live concurrency.** An `ultracode` / `xhigh` session was actively
  editing the hot coach files (`AICoachChatService.swift`,
  `CoachReliabilityGate.swift`) plus three test files, with uncommitted work in
  the tree (the "near-duplicate soft signal" reliability-gate feature, recent
  commit `ed3c0545`). A Swift/QA role agent independently `git diff`'d that
  in-flight work and verified it is **real, coherent, non-placeholder** — so this
  run treated it as off-limits and preserved it byte-for-byte (explicit
  pathspecs on commit; the six concurrent files remain unstaged/untouched).
- **The 10/10 question is settled and unchanged.** The literal "with no doubt
  replaces a human coach 10/10" stays **REFUSED BY DESIGN** —
  `CoachParityReadiness.forming` is the trust moat, protected by CLAUDE.md ("do
  not introduce 'replaces a human coach' claims") and the coaching invariant
  "coaching must avoid overclaiming." This is a deliberate premium-product
  boundary, not a missing feature. Re-confirmed across all 14 prior runs.

## Method — find what 14 runs missed, don't re-score

Four read-only role agents (veteran coach · market/competitor vs.
Speeko/Orai/Yoodli/Duolingo · skeptical cold end-user · Swift/QA-honesty), each
forbidden from editing/building, each asked the *same* single question: name one
SPECIFIC, buildable-without-a-human-in-the-loop, collision-safe lever the priors
did NOT already ship or correctly defer — or honestly conclude none exists.

They surfaced three candidates; two were correctly already-deferred-as-gated or
too collision-prone for an unattended run, and **one was a genuine 14-iteration
blind spot** (named convergently by 2 of 4 agents, code-grounded):

## The blind spot that shipped — per-voice rubrics

`GoalRubricStore.rubric(for:)` collapsed **all six** `SpeakingStyleGoal` voices
onto the single `authoritativeRubric`. A user who explicitly chose **"Warm and
welcoming"** was scored against a verdict-first / hedge-control standard (the
*opposite* of warmth) and the coach copy literally told them they were
*"approaching the authoritative communication standard"*
(`CoachReasoningPass.swift` interpolating `rubric.displayName`). That is a direct
violation of the CLAUDE.md invariant **"never punish semantically valid speech
patterns incorrectly"**, leaking through on the one surface never voice-branched.

**Why the 14 priors deferred it wrongly:** they filed "second rubric" under
*threshold calibration* (genuinely human-gated — needs real-coach labels). The
veteran-coach agent caught the category error: *which dimensions a voice is
judged on, and their weights, is a product-definition axis, not a calibration
axis* — and the **same codebase already ships per-voice models headless**
(`PracticeEvaluator.voiceDeliveryBonus`, with tests, authored without any
real-coach labels). So a weights/displayName change reusing existing dimension
IDs carries no calibration claim.

**What shipped (`52fc6aea`):**

- `warmRubric` + `storytellingRubric` in `GoalRubricStore.swift`, reusing the
  **same six scored dimension IDs** (verified necessary: `CoachReasoningPass`
  scores those exact IDs in a `switch`; any new ID falls to an inert `0.45`
  default). The six `RubricDimension` definitions were extracted into a shared
  `coreDimensions` constant so the *only* per-voice difference is weights +
  displayName — making it unmistakably a weighting, never a new heuristic.
- Weights mirror the shipped `voiceDeliveryBonus` priorities: **warm**
  de-emphasizes `hedge_control` (0.18→0.06) and `verdict_first` (0.22→0.12),
  rewards `controlled_pacing` (0.16→0.26) and `salience` (0.08→0.22);
  **storytelling** makes `salience` its top dimension (0.30) and drops
  `verdict_first` to 0.08. All maps stay normalized to 1.0.
- `authoritative` / `executive` / `persuasive` / `concise` / `nil` stay on the
  authoritative rubric **deliberately** (shared verdict-first spine), now
  documented as intent rather than a silent TODO.
- `NoumTests/GoalRubricVoiceRoutingTests.swift` — **+10 tests** locking routing,
  the "no warm/storytelling overclaim of the authoritative standard" guarantee,
  dimension-ID reuse, weight normalization, and per-voice weight intent. NOT a
  calibration assertion (no thresholds asserted; that stays in
  `CoachReadCalibrationBaselineTests` and stays human-gated).

**Scope discipline:** only warm + storytelling were split out — the two voices
the current mapping *actively punishes*. executive/concise/persuasive genuinely
share the authoritative spine, so inventing hand-tuned weights for them would be
fake precision; they're mapped on purpose. No `CoachReasoningPass` edit, no new
state owner, no new thresholds.

## Verification

- Isolated `git worktree` at HEAD `ed3c0545` (excludes the concurrent session's
  uncommitted edits) + the four gitignored plists + isolated `DerivedData`.
- `xcodebuild test` on iPhone 17 Pro sim → **`** TEST SUCCEEDED **`**. All 10
  `GoalRubricVoiceRoutingTests` pass; pre-existing `GoalRubricStoreTests` still
  passes (no regression to the authoritative path).
- Commit staged with explicit pathspecs; the concurrent six-file diff verified
  still dirty/unstaged afterward. No push.

## The other two candidates (logged, not shipped this run)

1. **first-rep-ever keep-prompt-visible** (`TimedPracticeView.swift`): on a new
   user's first rep with the auto-guide flag OFF, the prompt flashes ~3s
   (`briefReveal`) then disappears before they speak — the "wait, what was I
   supposed to say?" rep-1 trap. A `sessionStore.sessions.isEmpty` gate would fix
   it independently of the human-gated `AutoGuidedFirstRep` flag. *Deferred:*
   keeping a prompt on-screen during the speaking phase changes cold-start *feel*
   for every new user and arguably does merit a device felt-QA pass; `TimedPracticeView`
   has also been a contention file. Lower-confidence on the "no-felt-QA" axis —
   left for a felt-QA-attended run, not an unattended 4am build.
2. **Annotated transcript timeline** (Yoodli/Speeko signature): persist the
   Deepgram per-word timings (currently computed then discarded at
   `SpeechRecognizerViewModel.swift`) and render where fillers/pauses/bursts
   occurred in the user's own words. Genuinely absent from all 14 priors and pure
   presentation of existing data. *Deferred:* larger surface (persistence
   migration on `PracticeSession`, which has a noted parallel-teammate append
   point — real collision risk on that struct) — not safe to land blind while
   multiple sessions are live. **This is the strongest next buildable slice** once
   the tree is quiet; spec it against `PracticeSession` + `SummaryView`.

## Genuine limitations (unchanged, ranked) — what only Jordan can unblock

1. **Proxy scoring, not perception.** Authority/warmth/etc. are inferred from
   substring + threshold proxies, not conviction, audibility, or audience read.
   Audio-only ceiling; closing it needs a delivery signal beyond transcript
   tokens. *Human-gated: product call on the signal + cloud-STT/on-device trade.*
2. **Thresholds still un-externally-validated.** The calibration substrate is
   green against role-authored bands; lifting `.forming` needs real coaches to
   review the bands + longitudinal real-user outcomes. *Human-gated.* (This run
   deliberately added **zero** new thresholds, so it does not enlarge this debt.)
3. **Dominant acquisition lever still dark.** `AutoGuidedFirstRep` / universal
   fast-start remain default-OFF pending on-device felt-QA — the single highest
   leverage on the whole-app number. *Human-gated: flag-flip + device QA.*

## Connectors (the task asked)

- **Figma** and **Canva** MCPs are both connected and available. They are
  genuinely useful for the *next* design-led work (the annotated-transcript
  surface, the first-run acquisition moment) — but creating artifacts in Jordan's
  external accounts is an outward-facing write, so it was **not** auto-triggered
  in an unattended run. Flag to do together when present.
- No additional connector is blocking. The remaining levers are gated on
  on-device felt-QA and real-coach validation — human judgement, not tooling.

## 10/10 answer (restated, unchanged)

Literal "with no doubt replaces a human coach" stays **refused by design**. What
this run changed is one more honest brick beneath that answer: the judgement
layer no longer mis-judges 2 of 6 voices against a standard they never chose.
Realistic achievable ceiling is unchanged (~9 after the human-gated flag-flip +
felt-QA), and the path to it is gated on Jordan, not on more autonomous code.
