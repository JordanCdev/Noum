# Expert-coaching backlog (VISION-driven)

> **RESUME HERE (fresh session):** The `/loop` self-improvement pass runs locally
> and does NOT survive a context reset — re-run `/loop 50 keep assessing the app
> and finding ways to improve against the VISION.md goals (expert level coaching)`
> to continue. iter 4 DONE: interventionQuality one-clean-move (rule 3), controlled
> A/B +4.93. iter 5 REVERTED: the personalMemory rule-1 rewrite did NOT help in a
> same-era dual-arm A/B (−0.83, controls −2, cold-start fabrication) — see
> "Investigated" below. Next task = **Next item #1 (narrow synthesize-across-data
> clause only, re-verified) or item #2 (delivery intelligence)**. Context: memory
> files `coach_arena` + `session_lifecycle_evidence_floor`; commits
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

## Next (priority order)
1. **personalMemory — synthesize-across-data clause ONLY** (narrow retry of the
   iter-5 revert). Append just the winning sub-idea to the ORIGINAL rule 1: "when
   two or more data points exist, build a read across them (pattern/contrast/
   trajectory/a connection the user hasn't drawn) rather than restating a stat
   verbatim, and don't re-cite a fact an earlier turn already surfaced." Nothing
   else — no load-bearing-scan, no cold-start guard. Verify with the same-era
   dual-arm blind A/B before shipping; abandon if not clearly positive incl.
   controls + no new fabrications.
2. **Delivery intelligence depth** — VISION roadmap #5 (Perception). The coach
   senses fillers/pace/pauses but not prosody contour, breathing, emphasis, vocal
   energy, authority/tension. This is the biggest gap to "expert perception".
   Needs new session evidence, conservative thresholds, user-visible "what
   can/can't be inferred" copy. Large; stage it.
3. **Evidence-scaled confidence, end to end.** VISION: weak evidence → tentative
   language; repeated evidence → stronger intervention; never fake certainty from
   small n. Audit + this session found several thin-evidence over-claims (the
   aborted-rep read, the transfer-causation slip). Add a single evidence-depth
   read the coach context carries and the prompt scales tone to.
4. **Real-pipeline eval.** The Arena grades the prompt on Claude, self-graded.
   Wire the Python app-path engine (or a live `--live` run on the production
   `gemini-3.5-flash` path) so we measure the coach users actually get, incl. the
   gate/fallback/retrieval the prompt-faithful engine can't see. (Audit HIGH.)
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
