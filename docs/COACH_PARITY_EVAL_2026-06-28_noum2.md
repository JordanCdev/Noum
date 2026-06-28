# Coach-parity evaluation — 2026-06-28 (autonomous `noum2` run)

**Method shift, not another scorecard.** The prior run (`noum-1`, same date) already
re-scored the whole product at 7.7/10 on this HEAD and verified the new coach
judgement layer is real. Re-scoring again would add nothing. So this run aimed a
5-role workflow at the recurring **#1 ceiling-blocker every eval names** — the
judgement layer's *heuristic, uncalibrated scoring* — and turned it into a
version-controlled artifact that attacks the cap directly, plus fixed the one
real honesty gap that artifact surfaced.

## What shipped (build + test verified, real toolchain)

1. **`NoumTests/CoachReadCalibrationBaselineTests.swift`** — the coach-read
   **calibration substrate**: 15 expert-baseline fixtures exercising
   `CoachReasoningPass.assess` across coverage 0.22→0.82, the 0.35 abstention
   boundary, the 175-WPM pacing flip, pressure-proven vs. unproven goals, all four
   turn depths, both surfaces. Each fixture asserts the *expert-acceptable band* a
   competent coach would require (abstain / no-overclaim / disclose-pressure /
   confidence bounds). Authored by 5 role lenses, adversarially screened (2 of 25
   rejected for being tautological or numerically inconsistent with the real
   thresholds). Doc: `docs/COACH_READ_CALIBRATION_SUBSTRATE.md`. This is
   `docs/VISION.md`'s top "high-leverage next product move," now real.

2. **Fix in `Noum/CoachReasoningPass.swift` (`missingEvidence`)** — the substrate
   immediately caught a genuine honesty gap: `.append(pressure) + .prefix(3)`
   silently **dropped the "unproven under pressure" disclosure on weak reps**
   (≥3 failing dimensions evicted it), exactly where stakes-readiness matters
   most. The cardinal disclosures (coverage floor + pressure-unproven) are now
   ordered ahead of dimension-specific gaps so the cap can never evict them.
   3 previously-red fixtures now green; no regression in the existing
   reasoning-pass / semantic-gate suites.

## The honest 10/10 / "replaces a human coach" answer

Unchanged and correct: **literal "with no doubt replaces a human coach" stays
refused by design.** `CoachParityReadiness` structurally caps the Validation
stage below `.earned` because an app cannot self-certify parity
(`Noum/CoachParityReadiness.swift`). That cap is the trust moat — the most
coach-like thing the system does is decline to overclaim. Removing it to print a
10/10 would *destroy* the very property that makes Noum credible. Do not remove it.

What this run changes is **the credibility of the substrate beneath that answer.**
Before today the "heuristic scoring is uncalibrated" limitation was a hand-wave;
now it is a 15-fixture, version-controlled, expert-band measurement that is green
and extensible — the precondition for ever lifting the cap with evidence.

## Role panel — judgement layer in isolation (mean 6.2/10)

These are **component-level** reads of the deterministic reasoning pass, NOT a
re-score of the whole app (still ~7.7 from the prior run). They converge sharply
and code-grounded:

| Lens | Score | One-line |
|---|---|---|
| Veteran coach | 6.5 | Disciplined honesty engine a coach would trust to never overclaim — but it reads transcripts, not the room. |
| Skeptical end-user | 6.0 | Honesty floor is real and hard to fool — but it's one authoritative rubric for everyone. |
| Market/competitor | 6.5 | More honest than any metrics dashboard — but a calibration governor, not a coach that diagnoses *why*. |
| UX-honesty | 6.0 | Honest about *how much* it knows, not reliably *what* it knows (keyword-deep). |
| Swift/QA | 6.0 | Thresholds honest and well-guarded; a deterministic keyword scorer reads structure, not whether the user was actually authoritative. |

**Unanimous verdict:** the judgement layer is a trustworthy honesty/calibration
*governor* — deliberately built NOT to replace a coach — whose ceiling is
keyword/threshold **proxy** scoring (decision-word / hedge-token / WPM-band
lookups) standing in for perceived delivery. It earns trust by staying in its
lane; it cannot leave that lane to become a coach.

## Genuine limitations (ranked, with what only Jordan can unblock)

1. **Proxy scoring, not perception** (structural, named by all 5 lenses).
   Authority is inferred from substring/threshold proxies, not conviction,
   audibility, audience read, or content truth. Audio-only ceiling; closing it
   needs a delivery signal beyond transcript tokens. *Human-gated: product call
   on what signal (and the cloud-STT/on-device tradeoff).*
2. **One rubric for all voices** (most-cited *fixable* gap). Every
   `SpeakingStyleGoal` maps to the `authoritative` rubric, so a warm/storytelling
   user is judged on verdict-first decision words they may be intentionally not
   using. *Buildable next: add a second rubric + calibration fixtures for it.*
3. **Heuristic thresholds still un-externally-validated.** The substrate is
   green against *role-authored* bands; lifting `.forming` needs real coaches to
   review the 15 bands + longitudinal real-user outcomes. *Human-gated.*
4. **Dominant acquisition lever still dark.** `AutoGuidedFirstRep` /
   universal fast-start remain default-OFF pending on-device felt-QA. *Human-gated:
   flag-flip + device QA — highest leverage on the whole-app number.*

## Collision safety

A concurrent session holds an in-flight diff converting `CoachBrainFlags` to
config-driven (`CoachTurnDepth.swift` + `CoachPromptBundle.swift` +
`Localizable.xcstrings`). Verified it compiles (`** TEST BUILD SUCCEEDED **`).
This run touched only a NEW test file, a NEW doc, and `CoachReasoningPass.swift`
(clean, not in that diff). The commit uses explicit pathspecs; the in-flight diff
is preserved byte-for-byte. No push.
