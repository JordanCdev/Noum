# Expert-coaching backlog (VISION-driven)

A living, prioritized list of gaps between Chat-with-Noum today and VISION's
"expert human coach" bar. The `/loop` self-improvement pass works this top-down,
newest-done first. Each item: the VISION hook, why it matters, and status.

## Done
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

## Next (priority order)
1. **Close the interventionQuality gap** — the #1 expert lever the calibrated
   run exposes. The coach bundles two moves / hedges instead of prescribing ONE
   clean testable move. Tighten the system-prompt intelligence-floor rule 3 (one
   move, no second move, no hedge) and re-measure on a live run. Verify the mean
   moves on interventionQuality specifically, not just overall.
2. **Close the personalMemory gap** — replies cite facts that don't change the
   advice (decorative). Strengthen the "un-swappable" contract: the cited fact
   must be load-bearing for the move. Prompt + fixture-anchored.
2. **Delivery intelligence depth** — VISION roadmap #2. The coach senses fillers/
   pace/pauses but not prosody contour, breathing, emphasis, vocal energy,
   authority/tension. This is the biggest gap to "expert perception". Needs new
   session evidence, conservative thresholds, user-visible "what can/can't be
   inferred" copy. Large; stage it.
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
