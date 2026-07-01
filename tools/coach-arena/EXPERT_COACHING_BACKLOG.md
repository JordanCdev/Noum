# Expert-coaching backlog (VISION-driven)

> **RESUME HERE (fresh session):** The `/loop` self-improvement pass runs locally
> and does NOT survive a context reset — re-run `/loop 50 keep assessing the app
> and finding ways to improve against the VISION.md goals (expert level coaching)`
> to continue. iter 4 DONE: interventionQuality one-clean-move (rule 3), controlled
> A/B +4.93. iters 5 AND 6 REVERTED: personalMemory is NOT movable via rule-1
> prompt wording — two same-era dual-arm A/Bs both net-negative, and old-arm scores
> swing ±5/fixture between draws (generation variance dwarfs the effect). Approach
> CLOSED. iter 7 (assessment): evidence-scaled confidence is ALREADY implemented
> (Investigated) — the prompt/context layer is MATURE, so prompt-rule tweaking is
> now low-leverage. iter 8 (audit): the chat quality GATE is well-calibrated — it
> correctly rejects long/"Next rep:"-labelled replies the ARENA is lenient about
> (`reports/iter8-gate-audit.md`); no gate bug. iter 9 DONE: aligned the Arena length
> limits with the gate's real `replyLengthLimits` (`lib/checks.mjs`) so tooLong now
> predicts the gate; 24/24 tests. iter 10 (mined the existing app-path report): the
> real-pipeline "degradation" is a HARNESS ARTIFACT (gpt-4o-mini + typed-fallback
> candidates; the LLM `rawReply` layer is actually good) — a trustworthy run needs a
> production provider + a key (`reports/iter10-realpipeline-finding.md`). Next task =
> **#1 real-pipeline eval is BLOCKED headless (needs key/dump) → next tick does #3
> (delivery intelligence, the one new-capability gap) or #2 (turn-aware fallback)**.
> Context: memory files `coach_arena` +
> `session_lifecycle_evidence_floor`; commits
> `f035a3c4`..`3f0edd01` on `ux-overhaul`.
> **On measurement (read before trusting any number):** the full-suite re-judge is
> a fresh LLM panel each run, and panels DRIFT in leniency run-to-run (iter 4's
> panel graded ~3 pts/dim above iter 3's, uniformly, incl. dims a given change
> can't touch). So a raw `latest.json` mean vs the prior run CONFOUNDS the change
> with judge drift. To claim a real effect, isolate it with a single-panel blind
> A/B of old-vs-new replies (see `reports/iter4-ab-blind.json` for the pattern),
> not the headline delta. Do NOT re-inflate the judge or over-fit the prompt to
> hit 70 — the gap is real.

A living, prioritized list of gaps between Chat-with-Noum today and VISION's
"expert human coach" bar. The `/loop` self-improvement pass works this top-down,
newest-done first. Each item: the VISION hook, why it matters, and status.

## Done
- **Close the interventionQuality gap — exactly one clean move** (iter 4). The
  calibrated run's weakest dim was interventionQuality (9.8/15): the coach
  reliably included a move but BUNDLED extras onto it — a second move, a
  two-variant menu, an extra/contradicting target (worst: "hold a silent beat"
  *and* "drop pace to 180", which undoes its own diagnosis), or a self-answering
  question. Rewrote intelligence-floor rule 3 (`Noum/CoachContextBuilder.swift`)
  to enforce EXACTLY ONE move and ban all four shapes, keeping the reason clause,
  the rest/smaller-step carve-out, and the plan-request exemption; stripped the
  verbatim-eval example phrases to avoid over-fit. Design pressure-tested by a
  3-lens adversarial panel. **Verified with a controlled single-panel blind A/B
  (independent judge, old vs new reply per fixture, masked + order-shuffled):
  interventionQuality 7.57 → 12.5 on the 14 bundling/soft-move fixtures (+4.93),
  new reply preferred 12/14; the old set was bimodal (0-move punts *or* 2-move
  bundles), the new set is almost all exactly-1** (`reports/iter4-ab-blind.json`).
  The full 60-fixture re-judge read 72.7 overall, but that panel drifted ~3
  pts/dim leniently across the board (incl. Diagnostic IQ / EQ, which a
  move-rule can't move), so 72.7 is NOT banked as "gap closed" — the defensible
  result is the controlled IQ lift. Node 22/22, Swift compiles. Residual next
  levers surfaced: scaffold-label slips (`thats-not-informative`, `i-ramble`),
  cold-start jargon + ceiling, greeting report-voice residue.

- **Sharpen the measurement — give `closerTo` mechanical weight** (iter 1). The
  Arena judge rated 56/60 replies "excellent"; its holistic bad/between/excellent
  comparison had zero effect on the score, so grounded-but-generic answers scored
  as well as expert ones. Now: `bad` → capped at 45, `between` → −6. This is the
  foundation — you can't drive toward expert coaching with a lenient ruler.
  (VISION: "believable progress", coach-parity #7 Validation.) `lib/score.mjs`.

- **Judge calibration / anti-leniency** (iter 2). The judge rated 56/60
  "excellent" (40/60 scored 80+). Added a "hold the line" section to
  `judges/rubric-judge.md`: explicit score BANDS (top ≥85% is rare; competent
  55–70% is where most land) + 6 concrete deductions (generic-but-true diagnosis,
  decorative memory, bundled move, register mismatch, report-voice, self-answered
  question). **Verified:** re-graded 8 borderline "excellent" fixtures → mean
  dim-sum 79.9→70.9 (−9), 4/8 re-classified to "between". Judge bumped to v1.1.0.
  (VISION: coach-parity #7 Validation; believable progress.)

- **Recalibrate the full baseline** (iter 3). Re-judged all 60 with v1.1.0.
  **Honest baseline: gold mean 79.8 → 59.4** (median 60, range 38–79, buckets
  30s:2 40s:9 50s:18 60s:18 70s:13 80s:0), closerTo "excellent" 56/60 → 15/60.
  All thresholds now FAIL (59.4<70, deep 67.7<70, trust 60.7<65) — and that's
  correct: against an expert bar the coach is competent-not-expert, which VISION
  says it is. The number finally means something. **This does NOT mean re-inflate
  the judge or over-fit the prompt to close the gap** — the gap is real coaching
  work. Weakest dims point the way: interventionQuality 9.8/15 (bundled/hedged
  moves, not one clean test) and personalMemory 12.1/20 (decorative facts, not
  un-swappable reads).

## Investigated — negative / reverted
- **personalMemory "un-swappable fact" rewrite** (iter 5) — REVERTED, do not
  re-attempt as-is. Rewrote intelligence-floor rule 1 to demand the cited fact be
  load-bearing (delete-test), scan for the single most load-bearing fact, add
  synthesize-not-restate, and a cold-start fabrication guard. Verified with a
  **same-era dual-arm blind A/B** (regenerated BOTH old-prompt and new-prompt
  replies for 17 fixtures, then one blind judge scored each on personalMemory —
  isolates the rule from BOTH judge drift AND generation-era variance;
  `reports/iter5-ab-personalmemory-NEGATIVE.json`): **memoryFailure old 14.17 ->
  new 13.33 (−0.83, new preferred only 5/12); controls −2 (interview-prep −5:
  the new rule made the model DROP useful facts); and the cold-start fixture NEW
  FABRICATED a "trailing off" weakness with zero data** — the exact failure the
  guard was meant to prevent. Two lessons: (1) the iter-3 baseline's low
  personalMemory scores (its-not-easy 4, conv-transfer 5) were largely a specific
  unlucky GENERATION DRAW — a fresh old-prompt draw of the same fixtures scores
  ~14-16, so the "gap" was overstated by that one baseline; personalMemory is
  dominated by generation variance more than prompt wording. (2) "cite the single
  most load-bearing fact / one fact beats a stat dump" backfired by making the
  model drop useful secondary facts on already-strong replies. The ONE promising
  sub-idea that won in isolation (too-long +5, goal-change +6): "synthesize a read
  ACROSS the data / don't restate verbatim / don't re-cite a fact an earlier turn
  surfaced" — try THAT clause alone, appended to the original rule 1, and re-verify
  before shipping. Do NOT re-add the load-bearing-scan or the cold-start guard.
  [Tried in iter 6 — also failed; see below.]

- **personalMemory synthesize-clause-only** (iter 6) — REVERTED. Took ONLY the
  iter-5 winner (append a "when two or more data points genuinely connect, read
  them together, never force it, don't re-cite stale facts" sentence to the
  original rule 1). Same-era dual-arm A/B (`reports/iter6-ab-personalmemory-NEGATIVE.json`):
  memoryFailure old 13.08 -> new 12.5 (−0.58, preferred 4/12), controls −0.33,
  and it STILL induced a fabrication (`too-long`: claimed "pace held", a metric the
  rep does not measure, while dropping the real fillers delta). DECISIVE cross-iter
  finding: the OLD-arm score swings ±5 per fixture between the iter-5 and iter-6
  draws (conv-transfer old 16->11, too-long old 10->15) — generation variance
  dwarfs any rule-1 wording effect. CONCLUSION: personalMemory is NOT movable via
  rule-1 prompt wording; stop trying. Any real lever is structural (the CONTEXT
  block) — see Next #1.

- **Evidence-scaled confidence** (iter 7, assessment) — ALREADY IMPLEMENTED, not an
  open gap. Read the code: `CoachContextBuilder.coachMemoryLines` emits a COACH
  MEMORY "Evidence depth: <label> across <N> rep signal(s); <guidance>" line;
  `evidenceGuidance(for:)` scales tone per tier (insufficient → "treat this as a
  hypothesis, not a verdict"; tentative → "soften claims and ask one clarifying
  question"; moderate → "name patterns carefully"; established/stable → "name
  repeated patterns directly"); `derivedConfidenceLabel` + `BaselineConfidence.from(
  sessionCount:)` compute confidence from n; and the RATING section confidence-GATES
  stats (only quotes a metric when its `.confidence != .insufficient`). This is
  VISION's weak-evidence→tentative invariant, end to end, and the arena surfaces it
  (`lib/context.mjs` "Evidence depth"). No change made. Adding more prompt text here
  would be redundant (and iters 5-6 showed redundant prompt text doesn't move a
  dimension). If future thin-evidence over-claims appear, fix the specific
  computation that under-labels confidence, not the prompt wording.

- **Chat quality-gate over-rejection** (iter 8, audit) — NOT a gate bug; the gate is
  well-calibrated. Swept 15 Arena-high replies (75-89) through the live gate rules
  (`replyQualityIssue`/`semanticQualityIssue`/`visionQualityIssue`) via a temporary
  `@testable` test. 12 trips on 9/15 replies, but on inspection almost all are the
  gate CORRECTLY enforcing the app contract the Arena is lenient about:
  `scaffoldLabel` (3) = replies using "Next rep:" / "Straight verdict:", labels the
  prompt EXPLICITLY bans; `tooLong` (6) = `monotone` genuinely 106 words, the rest
  exceed the DELIBERATE, test-locked 4-sentence/420-char groundedRead caps
  (`rejectsOverlongTextModeReply`, `shortnessTurnDoesNotAccidentallyExpand` lock
  them). Full write-up: `reports/iter8-gate-audit.md`. Removed the sweep test (wrong
  premise: "Arena-high ⇒ should pass the gate" is false). **Real finding: the ARENA
  under-penalizes length/labels vs the shipping gate** — so "Arena-high" over-predicts
  ship quality. Improvement is on the MEASUREMENT side (done iter 9). One product
  question flagged for Jordan: the gate's 4-SENTENCE cap is stricter than the prompt's
  4-LINE/75-word contract, so a 47-word/5-sentence reply gets repaired — deliberate?

- **Align the Arena length limits with the shipping gate** (iter 9) — DONE. Correction
  to the iter-8 note: the Arena does NOT "shrug" at labels — its scaffoldLabel check
  already fires on "Next rep:" (−8; confirmed on the 3 label replies). The real gap was
  purely the LENGTH limits: `lib/checks.mjs` `LENGTH_LIMITS` was a loose approximation
  (groundedRead 7 sentences / 640 chars) while the shipping gate is 4 / 420, so 4 of the
  6 gate-`tooLong` replies passed the Arena with flagPenalty 0. Set `LENGTH_LIMITS` to
  the gate's actual `replyLengthLimits` (text, non-expanded): groundedRead
  {85w,4s,420c,5L}, trustRepair {170w,7s,900c,8L}, deepAssessment {260w,10s,1400c,10L}.
  Fixes BOTH directions — groundedRead tightened (now flags the gate's 6 tooLong replies,
  was 0) AND trustRepair loosened on words (was 110, gate allows 170). Verified: Arena
  `tooLong` now matches the gate on all 6 known replies; panic-blank (trustRepair 111w)
  correctly passes; 24/24 harness tests incl. 2 new alignment guards. Label penalty (−8)
  left as-is: a banned label triggers the gate's REPAIR (not reject), so −8 is a
  reasonable "repair cost" signal.

- **Real-pipeline degradation hypothesis** (iter 10) — NOT confirmed; the existing
  data is a harness artifact. Mined `reports/app-path/latest.json` (sibling's Python
  engine over real app candidates): avg 68.5, fails, groundedRead weakest, dominant
  failure "does not match expected coach move". BUT the traces show 18/50 candidates
  are the generic TYPED FALLBACK (17 identical openings) and the provider is gpt-4o-mini
  (31×), not production gemini. Crucially the typed-fallback fixtures' `rawReply` (the
  actual LLM draft) is GOOD and on-target (gives the example, builds the intro), while
  `finalReply` is the generic template with `issues: []`. Production Swift applies the
  typed fallback ONLY on `sawContentRejection`, so a good-rawReply + empty-issues +
  fallback can't be the production path — it's the eval capturing the typed read. So
  this report UNDER-states real quality and shows NO production bug; the LLM layer is
  fine. A trustworthy real-pipeline number needs production provider + final-reply
  capture + a key (Next #1). Write-up: `reports/iter10-realpipeline-finding.md`. Real
  edge-case surfaced: the typed fallback is turn-blind (Next #2).

## Next (priority order)
> **iter 7 re-prioritization (read this):** the prompt/context LAYER IS MATURE.
> iters 4-7 established that the remaining prompt/context "gaps" are largely already
> built or not prompt-movable — interventionQuality (fixed, iter 4), personalMemory
> (not prompt-movable, iters 5-6), evidence-scaled confidence (already implemented,
> see Investigated). Further prompt-rule tweaking is low-leverage. The real leverage
> is now (a) the PIPELINE the Arena can't see, and (b) genuinely new capability.
> Levers below re-ordered accordingly.

1. **Real-pipeline eval — needs a PRODUCTION-FAITHFUL re-run** (iter 10 mined the
   existing app-path report; see Investigated). The existing `reports/app-path/latest.json`
   is NOT trustworthy: it used gpt-4o-mini (not production gemini) and ~36% of graded
   candidates are the generic TYPED FALLBACK, not the LLM reply — whose `rawReply` was
   actually good/on-target. So it under-states quality and does NOT show a production
   bug. A trustworthy run needs: (a) production provider (`gemini-3.5-flash`), (b) grade
   the FINAL LLM reply not the typed fallback, (c) a dump dir or live key. It is the
   SIBLING's Python engine — coordinate, don't unilaterally rewrite it. Blocks a
   headless tick until a key/dump exists.
2. **Turn-aware fallback** (from iter 10) — LOW priority, product call for Jordan. When
   the pipeline falls back to `deterministicAssessmentFallbackReply` (production: only
   when ALL providers content-reject), the reply is TURN-BLIND — same "your last rep
   gives one usable signal: 7/10, 1 filler, 50s" regardless of the question. Rare, but
   a generic non-answer when it fires. Make the fallback at least address the turn type.
3. **Delivery intelligence depth** — VISION roadmap #5 (Perception). The coach
   senses fillers/pace/pauses but not prosody contour, breathing, emphasis, vocal
   energy, authority/tension. The one genuinely-new CAPABILITY gap (not a prompt
   tweak). Needs new session evidence, conservative thresholds, user-visible "what
   can/can't be inferred" copy. Large; stage it.
4. **personalMemory via STRUCTURAL context** — DEPRIORITIZED (may not be a real
   gap). iters 5-6 proved prompt-wording can't move it; avg is already ~13-14/20 on
   fresh draws (the low baseline was an unlucky draw). Only pursue if a fresh
   dual-arm baseline re-confirms the gap; then the lever is pre-synthesizing durable
   facts in the CONTEXT block (renderContext), not rule 1.
5. **Adaptation across attempts** — coach-parity #4. Extend the tone-drill
   reinforce/vary/replace pattern to the other skill areas (pace, close,
   structure) with an explained rationale each time.
6. **Transfer outcome loop** — coach-parity #6. Post-event outcome + audience-read
   capture that becomes durable coach context, not just a one-off report.

## Guardrails for the loop
- Don't over-fit the prompt to the Arena (Arena is a lenient same-model grader).
- Verify every change (Node tests for harness, `xcodebuild test` for app).
- The repo is shared with a concurrent scheduled task — a clean full app-test run
  isn't reliable while it runs; verify touched files in isolation.
