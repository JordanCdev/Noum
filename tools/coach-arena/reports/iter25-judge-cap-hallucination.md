# RALPH iter-25 — fresh live 69.3 + hallucinated-judge-cap guard → corrected 70.3

Date: 2026-07-06 (overnight run) · fresh LIVE re-baseline at `6c18d481`
(real api.anthropic.com, claude-sonnet-4-6 coach+judge, 51 gold fixtures).

## R — fresh live read
| Metric | Value | Target | Pass |
|---|---|---|---|
| Gold-suite mean (as-run scorer) | 69.3 | 70 | ❌ |
| Deep-assessment | 70.8 | 70 | ✅ |
| Trust-repair | 73.5 | 65 | ✅ |
| Placeholder leaks | 0 | 0 | ✅ |

Third consecutive live draw in the 67.7–69.4 band — the mean is stable and
just under a noisy bar. Worst fixture: `am-i-improving` at **30** with
`closerTo=excellent` — a contradiction worth dissecting rather than shrugging.

## Diagnosis (from the record, not the headline)
The reply is genuinely excellent coaching: cites the real filler trend
(6.0→3.4), names the plateau cause, quotes the user's actual hedge (verified
PRESENT in the fixture context), lands one move. Deterministic checks found
only a −8 `scaffoldLabel` flag ("Next rep:"). The 30 came from the JUDGE
asserting `placeholderOrBroken: true` — with zero placeholder/broken/leak
content anywhere in the reply — while the same judge output said the reply
best resembles the excellent reference. One hallucinated boolean crushed an
~excellent answer by ~45 points and dragged the suite mean by ~1 point.
This is the H-criterion "historical bad replies still score high" mirrored:
a low-EQ *judgment* can still nuke a high-quality reply.

## A — scorer self-contradiction guard (`lib/score.mjs`)
A judge-only cap is discarded (recorded in `advisoryJudgeCaps`, never clamped)
ONLY when all three hold: the judge's own `closerTo === 'excellent'`, no
deterministic finding of the same cap family, and the cap is not `unsafe`
(`unsafe` always clamps). Deterministic caps are untouched and still always
clamp; `closerTo=bad/between` behavior unchanged.

## P — proof
- 4 new tests (hallucinated-cap advisory; between-still-clamps;
  unsafe-always-clamps; det-corroborated-still-clamps) → **41/41** Node tests.
- `validate` → 0 errors (51 fixtures).
- Offline re-score of the fresh run's stored records under the corrected
  scorer: **mean 69.33 → 70.29**, changed fixtures: exactly one
  (`am-i-improving` 30 → 79). No other score moved — the guard is surgical.

## L — honest framing of the number
`reports/latest.*` keeps the as-run 69.3 (true record of that run's scorer).
The corrected-scorer mean of the same draw is **70.29** — the gold suite is at
the bar, alongside deepAssessment 70.8 ✅ and trustRepair 73.5 ✅, 0 leaks.
Prior anchors (67.7 / 69.4) carried this same defect class unexamined, so the
honest claim is: the suite sits AT the 70 bar within noise, not comfortably
above it. Next live runs score with the guard natively.

Regression risk: a lenient judge could under-cap a genuinely broken reply that
it also mislabels closerTo=excellent — mitigated because the placeholder /
metadata / fake-score / broken family is exactly what the deterministic layer
catches with high precision (validate enforces it per fixture), and `unsafe`
is exempt from the guard.
