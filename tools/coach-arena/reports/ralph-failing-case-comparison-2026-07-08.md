# RALPH failing-case comparison — 2026-07-08

Deterministic before/after comparison for this loop (no live model; all figures from
the real Swift app-path dump + the python `local_judge`).

## A. The fixed regression — app-path confidence (before → after option a)

| Signal (109 turns) | BEFORE (HEAD, evidence-free harness) | AFTER (session injection) |
|---|---|---|
| `assessmentConfidenceDistinctRoundedCount` | **1** (all 0.20) | **10** (0.20–0.38) |
| confidence spread | `{0.20: 109}` | `{0.20:43, 0.24:8, 0.27:2, 0.28:2, 0.32:19, 0.33:6, 0.34:6, 0.35:12, 0.36:10, 0.38:1}` |
| app-path conversation floor failures | 26 / 53 | **21 / 53** |
| `targetReplyMismatch` turns | 18 | 17 |
| `semanticGate` failure turns | 0 | 0 (no cascade) |
| `flatAssessmentConfidence` warning | present | **cleared** |
| python `evidenceClaim` | `localEvaluationOnly` | **`realPipelineEvidence`** |
| python `productionEvidence` / `traceQuality` | False / False | **True / True** |

Why it moved: the harness now injects each conversation's real source-fixture practice
sessions, so `UserTrajectory.evidenceCoverage` varies per conversation and
`CoachReasoningPass` raises confidence above the 0.20 thin-evidence floor **legitimately**
(cold-start conversations with no sessions correctly stay at 0.20). No gold reply text
changed; no judge threshold changed.

## B. Residual app-path sub-70 fixtures (quickMove type-avg 68.76) — NOT honestly movable

| Fixture | Score | local_judge reason | Diagnosis |
|---|---|---|---|
| `upcoming-conflict-028` | 50 | too-broad + **missing evidence anchor** + move-mismatch | Scripted reply is a cold-start "No baseline yet…" that does not fit the fixture's expected evidence-grounded move. Corpus mismatch. |
| `sales-pitch-031` | 50 | **missing evidence anchor** + move-mismatch | Same cold-start scripted reply vs an evidence-expecting fixture. Corpus mismatch. |
| `placeholder-leak-049` | 50 | move-mismatch | Adversarial fixture; the reply cites the rep but the expected move differs. |
| `networking-intro-029` | 63 | **(none)** | Good reply, scored below 70 by the rubric baseline with no specific disqualifier. |
| `live-latency-short-044` | 63 | **(none)** | Good reply ("On the latest rep the close is the signal…"), conservative rubric score. |
| `grammar-leak-048` | 60 | **(none)** | Good reply, conservative rubric score. |

Two honest reasons, neither a legitimate deterministic lever:
1. **Corpus mismatch** (cold-start scripted reply vs evidence-expecting fixture): the reply
   text is FORCED, so improving the score means editing gold replies — corpus-gaming.
2. **Conservative rubric baseline** on good replies (reason-less sub-70): raising these means
   loosening the `local_judge` — judge inflation, explicitly banned.

The aggregate app-path score (73.8) already passes ≥70. The honest route to lift quickMove is
authoring stronger gold quickMove replies (a corpus-quality task for Jordan), not a
harness/judge change.

## C. Prompt-layer worst-10 (from `reports/failures.md`, committed live run 67.6)

The dominant deterministic finding across the worst fixtures is `tooLong` (a known
Arena-vs-app artifact — the shipping `replyLengthLimits` gate repairs over-length before
the user sees it) plus report-voice/scaffold-label residue and "decorative memory". These
are **prompt-layer** issues: their score comes from the LIVE LLM judge on GENERATED replies,
so any change (wording OR the untried CONTEXT-block evidence-surfacing lever) is
**unmeasurable without an `ANTHROPIC_API_KEY`**. 17 prior iterations confirm wording can't
cross the noisy 70; the credential-gated protocol to move them is in
`RALPH_HANDOFF_2026-07-09.md`.

## Bottom line
Everything below 70 that is deterministically measurable is either a corpus-quality matter
(editing gold = gaming) or a judge-threshold matter (loosening = inflation) — both forbidden.
The prompt-layer items need a live model key. No honest deterministic lever remains this loop.
