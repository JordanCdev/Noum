# iter 8 — Chat quality-gate over-rejection audit

**Method:** swept 15 diverse Arena-high coach replies (75–89/100, across trust-repair /
deep-assessment / grounded-read) through the live context-free gate rules
(`replyQualityIssue`, `semanticQualityIssue`, `visionQualityIssue`) via a temporary
`@testable` XCTest. Corpus + raw results: `runs/gate-audit-corpus.json`.

**Raw result:** 12 trips across 9 of 15 replies. On inspection, almost all are the
gate CORRECTLY enforcing the app's contract, not over-rejection:

| Trip | Count | Verdict |
|---|---|---|
| `professional=scaffoldLabel` | 3 | **Gate correct.** All 3 use "Next rep:" / "Straight verdict:" — labels the system prompt EXPLICITLY bans (CoachContextBuilder rule at ~line 166). The Arena judge is lenient about these; the gate is not. |
| `vision=visionGate(seniorRegister)` | 3 | Same 3 label-using replies; entangled with the label issue; gate applies to deepAssessment/trustRepair by design. |
| `professional=tooLong` | 6 | **Mostly gate-correct.** `monotone` is 106 words (genuinely long). Others exceed the 4-sentence / 420-char groundedRead caps, which are DELIBERATE and test-locked (`rejectsOverlongTextModeReply`, `shortnessTurnDoesNotAccidentallyExpand`). |

**Honest conclusion:** the gate is well-calibrated; the "over-rejection" of Arena-high
replies is the gate enforcing the brevity + no-label contract that the ARENA JUDGE
UNDER-PENALIZES. So the improvement is on the MEASUREMENT side, not the product:
tighten the Arena's dialogueFeel length/label penalty so "Arena-high" better predicts
"ships through the gate."

**One product question for Jordan (not changed unilaterally):** the gate's 4-SENTENCE
groundedRead cap is stricter than the prompt's stated 4-LINE / 75-word contract, so a
concise reply like `conv-pushback-accept` (47 words, 5 short sentences, 288 chars) gets
repaired despite meeting the documented word/line bounds. Options: (a) align the gate's
sentence cap with the 4-line/75-word contract (relaxes brevity slightly; would need to
update `shortnessTurn`/`rejectsOverlong` tests + a shortness-turn tighter path); or
(b) leave as-is (deliberate premium brevity) and instead tighten the Arena. Recommend
(b) + Arena tightening unless the repair-cycle latency proves material in a live run.
