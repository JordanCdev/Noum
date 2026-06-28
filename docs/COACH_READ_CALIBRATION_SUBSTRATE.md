# Coach-read calibration substrate

Created: 2026-06-28 (autonomous `noum2` run)
Owner test: `NoumTests/CoachReadCalibrationBaselineTests.swift`
Status: validation **substrate** — explicitly NOT validation.

## Why this exists

Every coach-parity evaluation in `docs/COACH_PARITY_EVAL_*.md` converges on the
same #1 ceiling-blocker: the deterministic judgement layer
(`CoachReasoningPass.assess`) scores rubric dimensions, confidence, and the
overall verdict with **heuristics that had never been pinned against an
expert-coach baseline across a spread of situations.** A single fixture (the
"7/10 one rep" case in `CoachJudgementLayerTests`) was reused everywhere, so the
suite proved a handful of narrow behaviours but never characterised the engine
across its input space.

That gap is exactly why `CoachParityReadiness` is structurally capped at
`.forming` for the Validation stage — the app cannot self-certify a scoring
engine it has never calibrated — and why `docs/VISION.md`'s top
"high-leverage next product move" is:

> Build a version-controlled evaluation set and compare Noum reads to expert
> coach baselines. Label this "validation substrate", not validation.

This suite is that substrate.

## What it is

15 calibration fixtures. Each is a concrete `UserTrajectorySnapshot` INPUT plus
the **expert-acceptable BAND** a competent human communications coach would
require of the resulting `CoachAssessment`:

- `mustAbstain` — coverage too thin for any overall verdict
- `verdictForbidden` — overclaim phrases the verdict must never contain
- `requiredMissing` — evidence gaps the coach must disclose (e.g. `pressure`)
- `confidenceMax` / `confidenceMin` — coach-acceptable certainty bounds
- `immediateReadContains` / `responseMode` — live-surface honesty bounds

## How the fixtures were authored

Five role lenses each authored 3–5 scenarios from a distinct angle (veteran
communications coach · skeptical paying end-user · market/competitor analyst
benchmarking Speeko/Orai/Yoodli/Duolingo · UX + product-honesty auditor ·
Swift/QA threshold-hunter). An adversarial verifier then screened all 25: a band
is kept only if it is (a) **fair** — a real coach would genuinely require it, not
stricter; (b) **expressible** against the real `CoachAssessment` contract; and
(c) **non-tautological** — it can actually fail. Two were rejected (one
tautological quick-move band whose confidence range could never be violated; one
whose authored inputs yielded weighted mechanics 0.677 < the real 0.68 branch
threshold, so its expected verdict branch was wrong). The surviving 15 span:

- coverage **0.22 → 0.82**, including the **0.35 abstention boundary** (strict `<`)
- the **175-WPM** controlled-pacing flip
- **pressure-proven vs. unproven** goals at matched coverage
- all four turn depths (quickMove / groundedRead* / deepAssessment / trustRepair)
- both surfaces (text / live)

(*groundedRead is exercised indirectly; deepAssessment dominates because that is
where the overclaim risk lives.)

## The honesty laws it locks

1. **Thin evidence (coverage < 0.35) → explicit abstention**, never "you're
   close", however clean the single rep. (`first-rep-new-client-thin-evidence`,
   `single-great-rep-wants-nailed-it`, `live-surface-bounded-immediate-read`)
2. **One strong rep is never overall goal closeness** — `goalReadiness` is
   structurally capped at evidence coverage. (`single-good-rep-not-overall-closeness`)
3. **Pressure proof is always named missing until it exists**, even at coverage
   0.82 — a clean normal rep does not prove authority under stakes.
   (`high-coverage-zero-pressure-proof`)
4. **Genuine, repeated, pressure-proven evidence IS rewarded** ("approaching the
   standard") — the engine is honest, not uselessly pessimistic. This is the
   guard against over-correcting into a permabear.
   (`earned-approaching-repeated-pressure-proven`, `approaching-standard-still-needs-pressure`)
5. **The mechanics-vs-goal distinction holds** — "your technique is landing but
   you haven't proven the goal where it counts." (`mechanics-clean-but-goal-unproven`,
   `polished-evasive-no-point-mechanically-ahead`)
6. **Confidence stays inside coach-acceptable bounds** — no fake certainty, no
   uselessly flat reads.

## How to read a result

- **Green** — the heuristic still lands inside the expert band for every fixture.
  That is the meaningful, publishable finding: across 15 diverse situations the
  deterministic read matches what a competent coach would accept.
- **Red** — a real **calibration gap**. Triage it: either the heuristic has
  drifted and should be fixed, or (rarer) the band was wrong and should be
  corrected with a comment. Never silence a red by loosening a band without a
  recorded reason.

## What it does and does NOT prove

It proves the judgement layer's reads are **expert-band-consistent on a
curated, version-controlled set** — a precondition for ever lifting the
Validation cap. It does **not** prove parity: the bands are authored by role
agents, not a panel of credentialed coaches scoring real users, and the engine
still scores keyword/threshold **proxies** (decision words, hedge tokens, a WPM
band), not perceived delivery. Lifting `CoachParityReadiness` past `.forming`
requires (a) the bands re-reviewed by real expert coaches and (b) longitudinal
real-user outcomes — neither of which an app can self-certify. This is the
floor under that work, not the work itself.

## Next moves this unlocks

- Expand to a non-authoritative rubric once one exists (today every voice shares
  the `authoritative` rubric — the most-cited concrete limitation from the role
  panel).
- Add a "perceived-quality vs. proxy-score" divergence fixture set once any
  delivery signal beyond transcript tokens lands.
- Have a real coach review/annotate the 15 bands; record agreement as the first
  external-calibration data point.
