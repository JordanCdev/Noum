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

## Next (priority order)
1. **Judge calibration / anti-leniency.** The judge still marks most replies
   "excellent". Add per-band anchoring examples to `judges/rubric-judge.md` and a
   self-consistency check (grade a held-out reply twice; flag drift). Without
   calibration the score is a soft same-model self-grade. (Audit finding.)
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
