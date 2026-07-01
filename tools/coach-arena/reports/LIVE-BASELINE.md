# First LIVE Arena baseline (2026-07-01)

Provider: `anthropic` · coach + judge: `claude-sonnet-4-6` (real api.anthropic.com,
not replay, not subagent-simulated) · prompt @ commit 16eb0c23 (rule-3 in, rule-1
original) · 60 fixtures, calibrated v1.1.0 judge.

**Gold-suite mean: 67.7 / 100** (target 70 — just under). deepAssessment 76.2 ✅,
trustRepair 70.3 ✅, 0 placeholder leaks. Range 34–89, median 71.

Dimension means: DiagIQ 18.8/25 (75%) · EQ 18.5/25 (74%) · Memory 13.5/20 (67%) ·
Intervention 10.2/15 (68%) · Dialogue 11.4/15 (76%).

**This is the trustworthy anchor.** It brackets the subagent runs (iter-3 59.4 was a
harsh draw; iter-4 72.7 was a lenient judge panel) — 67.7 is the honest current number.

**Top live-confirmed lever = interventionQuality's "prescribe, don't defer" axis.**
The worst live fixtures cluster on the coach ASKING a question / handing the decision
back instead of prescribing one concrete move — even after rule 3:
- conv-emotional-dip (37): "asking a question where the data already gives the answer is avoidance"
- exhausted (48): "no concrete rest prescription — puts the decision back on an exhausted user"
- conv-cold-start-first-rep (49): "closing question violates 'do not stack intake questions'"
- set-authoritative (34): "inserts a clarifying question before confirming — contradicts the decisive user"
- plan-request-week (48): "five separate daily moves instead of one through-line — violates single-intervention"
Second lever = personalMemory (decorative facts) — same as prior finding, now live-confirmed.
