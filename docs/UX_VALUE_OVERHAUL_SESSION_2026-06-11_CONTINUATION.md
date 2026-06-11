# Noum overhaul — session continuation 2026-06-11

Branch: `ux-overhaul`
Mode: autonomous scheduled run (`noum-1`), no user present.
Toolchain: real (Xcode 26.x on this Mac) — every "verified" claim below is
compiled + tested on the booted iPhone 17 simulator
(`3D077053-2981-4C5D-819D-FF6F9BA8AD06`), not hand-traced.

## TL;DR

- Confirmed the tree is green at HEAD before and after changes: **full
  `NoumTests` = 2451 / 0** (baseline) and re-run after both commits.
- Ran a fresh 6-role evaluation workflow against the CURRENT tree (both 06-10
  evals predate the concurrent agent's REVIEW/HOME/CHAT commits). Honest score:
  **7/10**. The literal "10/10, no doubt replaces a human coach" answer is
  **no**, and the app is correct to never claim it — full delta + limitations in
  `docs/COACH_PARITY_EVAL_2026-06-11.md`.
- Shipped two owner-local, verified fixes that form one coherent slice — *make
  Noum quoting your own verified words land instantly and visibly* (the eval's
  #1 item + its provenance companion):
  - `a6e7524` — **verified-quote provenance** ("Your words, this rep") on the
    post-rep WIN card. 8/8 `PostRepVerdictContentTests`.
  - `2986303` — **first-frame proof-sync** via the pure static
    `ProofMomentService.deterministicProof`, no finalize-hot-path / URLSession
    risk. 17/17 proof + verdict tests.
- **Corrected a stale eval finding**: the post-session follow-up notification is
  NOT dead code — it is wired in `SessionFinalizer:184` and fires a +18h
  coach-voice nudge (opt-in/auth gated). The "3 of 4 surfaces" claim is out of
  date (a recent commit fixed the opt-in path; see the comment at
  `NotificationManager.swift:505-506`).
- The remaining high-leverage items are left as precise engineer specs below.
  Each was deferred for a real reason (architectural risk / coach-voice
  delicacy / on-device felt-quality QA an autonomous run can't do), not skipped.

## What shipped (verified)

### `a6e7524` — verified-quote provenance affordance

`PostRepVerdictContent.Win` gains `quoteIsVerified`, set true only for a
guard-cleared `ProofMoment` quote or an on-tape eloquence snippet (the user's
own detected words) — never for coach-authored text/impression wins.
`PostRepWinCard` renders a quiet `waveform` + "Your words, this rep" line under
the quote rail, with a VoiceOver label. No "verified vs competitors" / parity
framing (honors the red lines). `ProofMoment.sessionDate` had documented this
exact framing as intended-but-never-wired.

### `2986303` — first-frame proof-sync

`resolvedProof = personalBestProof ?? deterministicProof(proofInput)`. The
deterministic path is a pure static function (no actor hop, no network, no
main-actor block), so the verified quote + provenance paint on the first frame
instead of staggering in ~0.5s after the WIN card. The async
`loadPersonalBestProof` still upgrades the *claim wording* to the AI proof when
a provider is live; the verbatim quote is identical on both paths. Behaviour is
already locked by the existing `deterministicProof` tests.

## Verification

- `xcodebuild build -scheme Noum -destination 'platform=iOS Simulator,id=3D07…'
  -derivedDataPath ./DerivedData/Noum`: BUILD SUCCEEDED (HEAD baseline + after
  each change).
- `-only-testing:NoumTests/PostRepVerdictContentTests`: 8/8.
- `-only-testing:NoumTests/ProofMomentServiceTests -only-testing:NoumTests/PostRepVerdictContentTests`: 17/17.
- `-only-testing:NoumTests` (full): 2451/0 baseline; re-run after both commits
  (result bundle `/tmp/noum-fullsuite2.xcresult`).
- NOT pushed (concurrent-agent ref-race protocol). NOT visually captured: the
  two changes are post-rep-summary surfaces that need a seeded rep flow or the
  UI-test overlay harness to render; the logic is test-backed and the build is
  clean, but on-simulator screenshot QA of the first-frame proof + provenance
  line remains open.

## Engineer-grade specs for the remaining backlog

### #4 — Rep-1/2 named prescription (M, coach-voice core)

Owner: `PostRepCoachNoteService.metricSentence` (the deterministic priority
chain, `Noum/PostRepCoachNoteService.swift:710`). On reps 1–2 with no baseline,
the chain returns a win/observation sentence (e.g. branch 2 "Zero fillers —
clean run.") with no forward lever; the `<suffix>` is the generic persona
closing. Spec: add a thin-data branch that PAIRS the honest observation with ONE
deterministic, mode-appropriate next move drawn from the rep's own weakest
measured signal (pace outside range → "next rep, hold the open a beat"; short
rep → "give the next one 30 seconds"; etc.). Constraints: preserve
weak-evidence→softer-feedback; never claim causation; stay ≤200 chars; add
per-persona copy + tests. Pairs with #12. Deferred here because it is the
delicate coach-voice spine with extensive existing tests and needs on-device
felt-quality QA.

### #5 — Auto-seed the post-rep summary into the Ask Noum thread (S)

Owner: `AskNoumStore` (shared singleton) + `SessionFinalizer`. Today
`injectUserTurn` only fires on the explicit "Talk to Noum" tap
(`SummaryView.swift:2448`). Spec: at finalize, seed the thread WARM (carrying
the rep context) so it is already coach-aware when opened — WITHOUT
auto-navigating. Needs a "pending-but-not-shown" seed concept in `AskNoumStore`
so repeated reps don't accumulate/duplicate context, and chat QA. Same store,
same route, no second coach door.

### #12 — Thread the prescribed isolated variable into the post-rep note (M)

`PostRepCoachNoteInput` carries no `observableTarget` / `successCriterion`, so
the immediate note judges full-rep metrics and never names whether the ONE
prescribed lever moved. The data exists (`CoachSuccessCriterion.status`, shown
in CaseReview/Ask Noum). Spec: pass the intervention target into the note input
so instant feedback speaks to the prescribed lever in isolation ("a human coach
names one variable, watches it move, celebrates the move").

### #3 — RewardEngine activation: DO NOT auto-activate

`RewardEngine.evaluateSession` + `SessionCompletionCopy.headline` are confirmed
dead (zero invocations), BUT personal-best already celebrates via the
`SessionFinalizer` path. Wiring `evaluateSession` naively would double-fire
celebrations and stand up a parallel celebration coordinator — a CLAUDE.md
fragmentation violation. If the between-milestone warmth is wanted, it must be
threaded through the EXISTING `SessionFinalizer` gating, not the parallel
engine. This is an architecture decision for Jordan.

### #11 — Close the transfer loop (M, the transformative move)

Outcomes are collected (`BigMomentStore`) and fed to coach CONTEXT
(`CoachContextBuilder:~5348`), but `PrepSessionPlanner.plan()` takes only
moment+days+voice — outcomes never reshape the next prescription, and the
three-rep sequence is static per category. Add an `OutcomeTransferLink` so
"prep didn't carry" adapts the next prep, plus a proactive coached debrief
surface (currently passive: the user must open Ask Noum). Biggest
differentiation move vs every competitor.

## Connectors

- **Figma MCP** (`@figma`) and **Canva MCP** are both connected. Neither was
  exercised this session: the shipped work was a correctness/coherence slice +
  an evaluation, none of which needed a new visual artifact. The next session
  taking on the visual backlog (#7 Home plan arc, #10 onboarding→greeting
  bridge, #6 provenance everywhere) should use Figma to spec the chip/motion
  against the existing design tokens before implementing.
- No additional connectors are required for the remaining code-tickable backlog.
  The 10/10 limitations need a real provider key + a physical device + expert
  calibration + a real user cohort — all out of an agent's reach.
