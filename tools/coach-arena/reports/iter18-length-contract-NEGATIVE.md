# RALPH iter-18 — groundedRead length contract — NEGATIVE, REVERTED

Date: 2026-07-01 · branch `ux-overhaul` · live A/B on Jordan's key

## Hypothesis
The live worst-10 (iter-17) is dominated by `tooLong` on **groundedRead**. The
prompt says "under 75 words / 1-4 lines" for ALL text turns but has **no
per-turn-depth hard cap**, so the model applies the deepAssessment/trustRepair
length allowance to quick grounded reads. A structural per-depth length contract
("a grounded read is a local read, not a report: 2-3 sentences, one signal + one
move; only deepAssessment / trustRepair / plan earns a longer answer") should cut
groundedRead length and lift the mean.

## Method — full live A/B (real claude-sonnet-4-6, api.anthropic.com)
- OLD arm = committed `0bb4e692` prompt (the 69.4 run, preserved).
- NEW arm = same suite with the length contract added to `CoachContextBuilder`.
- Compared on the **drift-immune deterministic signal** (word count + `tooLong`
  rate — not subject to judge-panel drift) plus the mean.

## Result — the change failed its own goal
| Metric (19 groundedRead fixtures) | OLD | NEW | verdict |
|---|---|---|---|
| avg words | 71 | **74** | ↑ (worse) |
| `tooLong` count | 10 | **12** | ↑ (worse) |
| groundedRead mean score | 63.0 | 64.7 | +1.7 (noise) |
| **gold-suite mean** | **69.4** | **68.5** | −0.9 (noise) |

deepAssessment 74.9→71.6 and trustRepair 74→71.2 are fresh-panel drift (both
still pass). The decisive, drift-immune fact: **groundedRead did not get
shorter** — the length contract did not bind. The over-length is driven by
sentence/line count, not words, and the model ignores the explicit per-depth cap
just as 15 prior iters found for every other wording lever.

Reverted `CoachContextBuilder.swift`; restored the committed 69.4 report.

## Conclusion (16th confirmation)
Prompt WORDING — including a hard structural length contract — does not reliably
move this mature prompt. The residual groundedRead `tooLong` is an **Arena-vs-app
artifact**: the shipping app's runtime `replyLengthLimits` gate *repairs*
over-length replies before the user sees them, so the real-app groundedRead is
shorter/compliant while the Arena penalises the raw draft. The Arena 69.4
therefore UNDER-states real groundedRead quality.

The number will not cross a noisy 70 via prompt/eval edits. The only real levers
left are out of this layer: a stronger coach model, or the perception /
longitudinal-outcome validation VISION explicitly reserves for real users.
Do not re-try a groundedRead length wording lever.
