# Coach Parity Roadmap

Generated: 2026-06-01

## North star

Noum is "done" only when it does the repeatable, evidence-led work of an excellent human communication coach: diagnose the individual from evidence rather than a single sample, hold a durable and evolving picture of who they are and the real moments they are preparing for, prescribe deliberate practice with an observable target and an honest threshold for judging it, observe the response across multiple attempts and reinforce / vary / replace with a stated rationale, sense how they actually come across, prepare them for real-world moments and learn from how those went, and prove the whole thing is calibrated against a human-coach bar. Parity is proven by durable user outcomes over time. It is never claimed from a single LLM reply, one rep, or a feature checklist. This roadmap ranks the surviving, adversarially-verified gaps by leverage toward that standard and respects the vision's own post-M14 sequencing.

## Current maturity

Scores are 0-5 against the coach-parity bar for each stage, taken from the per-stage assessments and the verifier's findings. Every gap below survived adversarial verification (all real, all kept).

| Stage | Score | One-line note |
| --- | --- | --- |
| Diagnosis | 4 | Strong: session-gated confidence ladder, credibility filter, single high-leverage focus committed deterministically. Gap: the focus is selected from telemetry + stated voice only; it never reconciles with the user's stated challenge, and divergence is never surfaced. |
| Case formulation | 4 | Real durable CoachCaseFile rebuilt every finalize, injected every turn, user-confirmable, well-tested. Gaps: the forward-looking upcoming moment never reaches the durable case, and confidence only ratchets up (no revise-down / staleness path). |
| Intervention | 4 | End-to-end prescription spine: named strategy + rationale, observable target, success bar, followed-rep ledger, honest evidence-confidence. Gap: the target and bar are templated by goal + strategy, not grounded in the user's own baseline numbers. |
| Adaptation | 3 | One full loop wired end-to-end (IM tone-drill recovering / stalled / slipping). Gap: the general drill loop only narrates association; no reinforce / vary / replace verdict is computed from the outcome ledger or fed back into the next prescription. |
| Perception (delivery sensing) | 3 | All core delivery dimensions sensed and trended separately (pitch, energy, pause, composure, confidence markers, structure, word choice). Gap: no single durable fused delivery read distinguishing clarity from polish / evasion / timidity / detachment. |
| Transfer (real-world) | 3 | Big Moment intake, outcome capture, and read-back into context all exist. Gap: outcomes enter as a flat list of recent reports; nothing aggregates them across events of the same kind into a tentative cross-event transfer trend that drives the case. |
| Validation (human-coach calibration) | 1 | Only preconditions exist (evidence-gated language; an outcome-ledger structure that is currently orphaned). No evaluation set, expert baseline, calibration scoring, or longitudinal real-world outcome tracking. Quality is asserted, never measured. |

## Initiatives (ranked by leverage)

### 1. Close the general adaptation loop: compute a reinforce / vary / replace verdict and feed it into the next prescription

**Stages advanced:** Adaptation, Intervention

Adaptation is the engine that makes the entire prescribe -> observe -> adapt cycle real rather than a one-shot recommendation. Today only the IM tone-drill sub-domain closes this loop. `RecommendationLearningStore` accumulates per-mode outcomes and `RecommendationResponseAnalyzer` narrates "associated with improvement / adapt before repeating," but the core drill recommendation can never change course, so a user can be re-prescribed a drill the ledger already shows is not moving the metric. The vision names this exact standard as the next bar. Closing it turns the loop from one vertical slice into a real cycle and directly strengthens Intervention, because "did it move" now drives what gets prescribed.

- **State owners to extend:** `RecommendationLearningStore` (add a pure verdict reducer over its existing `outcomes`), `NextActionEngine` (consume the verdict to bias drill selection), `CoachContextBuilder` (carry the rationale through the existing INTERVENTION RESPONSE block).
- **First step:** In `RecommendationLearningStore` (Noum/RecommendationLearningStore.swift, alongside `recordOutcome` at ~line 21) add a pure `adaptationVerdict(focusKey:) -> (action: reinforce | vary | replace, confidence, followedReps, improvedRate)` computed only from the existing `outcomes` array, mirroring the tone-drill thresholds in IMHistorySummary.swift:535-577. Unit-test it first against fixture outcome arrays, then bias `NextActionEngine.recommend` away from a mode whose verdict is `.replace` at >= tentative confidence, and pass a one-line rationale into the existing INTERVENTION RESPONSE context lines (CoachContextBuilder.swift:504).
- **Evidence threshold:** Do not vary or replace an intervention until that focusKey has >= 3 followed reps with recorded metric movement (mirror the tone-drill min-sample / 4-rep floor). Below that, reinforcing or neutral language only. Phrase every verdict as association ("this mode has not moved alongside your metric over N reps"), never causation, and escalate to a confident "replace it" only at >= 6 followed reps.
- **Main risk:** Replacing an intervention too eagerly on thin or noisy data makes the coach feel fickle and can abandon a sound drill before it had a fair trial. The min-sample floor, association-only language, and a pure, unit-tested verdict reducer (so the decision is auditable rather than emergent) are the guardrails.

### 2. Fold the user's upcoming real-world moment into the durable CoachCaseFile

**Stages advanced:** Case formulation, Transfer

The case-formulation bar explicitly requires the case to retain the upcoming moments that matter, and the data already exists end-to-end: `BigMomentStore` owns scheduled moments and `CoachTransferReview` already folds the past outcome into the case. But the forward-looking moment stops at the per-turn context and never reaches the durable case spine, so the coach's persistent read is blind to what the user is preparing for. It cannot time interventions to a deadline, prioritise the lever the moment demands, or say "your board update is in three days." This is small, high-certainty, strictly extends an existing owner, and is the data bridge the Transfer stage builds on.

- **State owners to extend:** `CoachCaseFile` (add one bounded optional `upcomingMoment` field), `CoachCaseFile.build` (read the soonest future entry from `BigMomentStore`), `CoachContextBuilder` case-file lines (emit one tentative line).
- **First step:** Add `var upcomingMoment: CoachUpcomingMoment?` (title, category, daysUntil, derived focus) to `CoachCaseFile` (PrimaryFocusMemory.swift:821). In `CoachCaseFile.build(from:now:)` (PrimaryFocusMemory.swift:835) select the soonest future `BigMomentStore` entry and populate it, mirroring the existing `lastTransferReview` wiring at ~line 843. Append one tentative line to `coachCaseFileLines` (CoachContextBuilder, ~line 2160) and add a build test alongside the existing transfer-read test.
- **Evidence threshold:** No inference is needed to add a user-entered moment — it is the user's own scheduled event, not a hypothesis — so surface it as soon as one future moment exists. Keep it bounded to the single soonest moment, never let it strengthen a psychological hypothesis, and frame any moment -> focus link as "the kind of skill this moment tends to need," never a claim the user will struggle. Drop the line once the date passes (it then flows through the existing transfer-review path).
- **Main risk:** Low. The risk is copy that implies a prediction about how the moment will go, or a moment -> focus link that hardens into a claim. Strictly tentative framing and a hard bound to one soonest moment keep this a forward-awareness gain, not a new inference path.

### 3. Fuse the per-rep delivery reads into one durable delivery read

**Stages advanced:** Perception (delivery sensing), Case formulation

The hard part of perception is no longer sensing individual dimensions — pitch, energy, pause, composure, confidence markers, structure, and word-choice reads all already exist and trend separately. The parity gap is synthesis and memory: a coach integrates these into one evolving read ("your words are polished but your energy is flat and your structure is over-rehearsed — it reads as detached, not clear") and holds it across reps. Today they surface as parallel per-rep cards, which is precisely the "dashboard of meters" anti-goal, and nothing catches the speech that scores well on every axis yet still lands as evasive or emotionally flat. This is the explicitly named M17 frontier and the highest-leverage move in the stages the vision flags as most underweight.

- **State owners to extend:** `CoachCaseFile` (add one bounded fused delivery-read field), `DerivedReadsTrend` (combine the existing `ComposureRead` / `ConfidenceMarkerRead` / `PitchMetrics` / `VocalEnergyMetrics` / `StructuralRead` outputs over the recent-rep window). No new analyzer.
- **First step:** Re-read the output shapes of `PitchMetrics`, `VocalEnergyMetrics`, `ComposureRead`, `ConfidenceMarkerRead`, `StructuralRead`, and DerivedReadsTrend.swift to confirm no fusion already exists. Then define a single bounded `DeliveryRead` value (a dominant-pattern enum including a clear-vs-polished / evasive / timid / detached characterization, plus `evidenceDepth` and a tentative one-line read), computed by combining those existing reads over the recent-rep window inside `DerivedReadsTrend`, and persist it on `CoachCaseFile` so Ask Noum, post-rep feedback, and the next recommendation all read one delivery read instead of many cards.
- **Evidence threshold:** Do not assert a clarity-vs-polish / evasive / detached characterization until the same direction holds across at least ~4-5 reps in the window; single-rep reads stay tentative and unpersisted. Frame every interpretive read as a hypothesis the user can confirm or reject, never a trait or diagnosis, and describe combined acoustic + structural signals as association, never causation. Calibrate pitch/energy bands to the user's own baseline (`BaselineEngine`) so soft-spoken or accented speakers are never scored as monotone or detached.
- **Main risk:** This is the most interpretively dangerous initiative. Labelling someone "evasive" or "emotionally detached" on weak acoustic evidence is exactly the overclaim the vision forbids, and miscalibrated bands would systematically mislabel quiet or accented speakers. Mitigation: per-user baseline calibration, a multi-rep direction threshold before anything persists, hypothesis framing the user can reject, and editorial fusion (one read leads, details collapse) rather than another card.

### 4. Aggregate Big Moment outcomes into a tentative cross-event transfer read

**Stages advanced:** Transfer (real-world), Case formulation

The transfer loop is wired — `BigMomentOutcomeInlineCard` captures outcome and perceived audience response, and `CoachContextBuilder` reads `recentOutcomeReports` back into context — so the gap is not "outcomes are ignored," it is depth. Outcomes enter as a flat list with no aggregation across events of the same kind and no derived trend, so the coach cannot honestly say "across your last three interviews your perceived reception is improving." Transfer parity is proven by real-world outcomes over time; a flat recent-report list either says nothing longitudinal or risks overclaiming from a single event. An aggregated, tentative cross-event read is what lets the coach state, honestly, whether practice is transferring.

- **State owners to extend:** `BigMomentStore` (add a bounded computed transfer-read summary over its existing outcome reports), `CoachContextBuilder` (replace/augment the flat `recentOutcomeReports` emission at ~line 1509), `CoachCaseFile` (let a confirmed recurring read populate the durable transfer read).
- **First step:** In `BigMomentStore` (Noum/BigMomentStore.swift, alongside `recentOutcomeReports` at line 276) add a pure computed summary that groups existing outcome reports by moment kind and counts perceived-response direction over a bounded recent window. Then replace/augment the flat emission at CoachContextBuilder.swift:1509 with one tentative aggregated line per kind (e.g. "across your last 3 interviews, perceived reception was 2 better-than-expected, 1 as-expected — the user's own read, not a measured outcome"). Add a test over fixture outcome arrays.
- **Evidence threshold:** A single outcome stays an anecdote phrased tentatively as the user's self-report. Only when the same perceived-response direction recurs across >= 3 outcomes of the same moment kind may the coach state a tentative transfer trend, always labelled association not causation, and confirmed with the user before it is written into the case file as a durable transfer read.
- **Main risk:** Perceived audience response is self-reported and subjective; aggregating it can read as an objective real-world outcome if the copy is not scrupulously framed as the user's own read, and small per-kind samples make any "trend" fragile. Mitigation: the >= 3-same-kind threshold, explicit self-report and association framing in every line, and user confirmation before anything persists.

### 5. Ground the observable target and success bar in the user's actual baseline numbers

**Stages advanced:** Intervention

`targetLine` / `successLine` are a fixed switch on goal + strategy, so every user on the same goal hears the same generic bar. The user's real numbers already live in session history — `buildSuccessCriterion` even computes `priorAverage` — but `criterionSummary` never receives or mentions it, so the bar reads as boilerplate rather than a coach who knows your numbers. A coach prescribes against the individual's current number ("your last five reps averaged 4.2% — let's hold under 4% for three reps"), which makes the target feel earned and the success bar falsifiable. It also sharpens Adaptation downstream, since "did it move" is then measured against a concrete starting value. It sits below the adaptation loop itself because the bigger win is the loop that consumes the result.

- **State owners to extend:** `PrimaryFocusMemory.activeIntervention` prescription path (`updateActiveInterventionFromRecommendation` / `targetLine` / `successLine` / `criterionSummary`), reading from the existing session store the same way `TrendAnalyzer` does — not a new store.
- **First step:** Thread the already-computed `priorAverage` (PrimaryFocusMemory.swift:1412) into `criterionSummary` (~line 1435) so the summary interpolates the real figure when the sample is sufficient, and extend `updateActiveInterventionFromRecommendation` to carry a small baseline snapshot. Add a test asserting a populated baseline yields a numeric, personalized target while a thin baseline yields the existing generic string.
- **Evidence threshold:** Only emit a numeric, personalized target/bar when there are at least ~3-5 recent reps in the relevant metric (mirror the existing baseline / evidence-confidence gating). Below that, keep the tentative generic copy. The bar's specificity may strengthen as reps accumulate, but never state a precise threshold ("under 4%") off one or two reps, and never imply the drill caused a change — only that the number is or is not tracking toward the stated target.
- **Main risk:** A precise-sounding numeric target off a thin or noisy sample reads as fake certainty and is easy to miss when natural variance swings the metric, denting trust. Mitigation: the 3-5 rep gate with graceful fallback to the current generic copy, and tracking-toward language rather than causal claims.

### 6. Reconcile the measured focus with the user's stated challenge, and surface agreement vs. divergence

**Stages advanced:** Diagnosis

The diagnosis the whole loop anchors on is selected from telemetry + stated voice only: `selectLever` branches trend -> persistent blocker -> `speakingStyleGoal` -> structure and never consults the user's stated challenge (`CoachingProfile.biggestChallenge`), nor tells the user whether the measured read agrees with their own. A human coach's central diagnostic act is exactly this reconciliation ("you said conflict makes you freeze; your reps back that up" or "you flagged rambling, but the data points more at fillers — does that fit?"). Both halves exist but never meet at the decision layer, so the engine can confidently name a focus the user does not recognise. It ranks sixth only because Diagnosis is already the most mature stage and the captured challenge already reaches the LLM prompt — the marginal parity gain is real but smaller than the loop-deepening initiatives above.

- **State owners to extend:** `PrimaryFocusMemory.selectLever` / `resolve` (consume `biggestChallenge`, already reachable on the passed-in `CoachingProfile`; emit a concordance flag on the lever), and the existing `CoachReadCard` / `CoachContextBuilder` surfaces (render agreement vs. divergence).
- **First step:** Extend `PrimaryFocusMemory.selectLever` (PrimaryFocusMemory.swift:1157) with a pure mapping from `CoachingProfile.biggestChallenge` (PracticeSupport.swift:494) -> `SkillArea`, reusing the existing `SpeakingChallenge.recommendedPriority` mapping. Return it as an explicitly tentative lever ("you told me X") when `baseline.overallConfidence < .tentative`; once telemetry is reliable, set an `isConcordant` flag comparing the stated-challenge lever to the trend/blocker lever for the existing surfaces to render. Add a test for the tentative day-zero path and the concordance flag.
- **Evidence threshold:** The stated challenge alone yields only a tentative lever ("you told me X") and never a confirmed diagnosis. Strengthen or confirm the focus only when telemetry reaches the existing `isReliable` bar (>= moderate) and agrees with the stated challenge. On divergence, do not silently override and do not auto-flip the stored lever — surface a one-line coach question for the user to confirm or reject before the named focus changes.
- **Main risk:** Letting the stated challenge override measured telemetry would re-introduce self-report bias into a diagnosis the engine has rightly kept evidence-led, while silently flipping the focus on divergence would erode the hypotheses-not-facts contract. Mitigation: stated challenge is tentative-only and never confirms a focus alone; divergence surfaces a question rather than a switch.

### 7. Stand up a version-controlled evaluation set wired to the live coaching logic

**Stages advanced:** Validation (human-coach calibration)

Validation is the lowest-maturity stage and the literal definition of done, yet it is correctly sequenced last by the vision (M20) precisely because it must measure a system that has stabilized — standing up calibration before the loop deepens would score Noum against a moving target and bake in a baseline the rank 1-6 work is about to change. The stage is defined by comparing Noum's output to a human-coach baseline on representative sessions, but no fixed, inspectable caseload exists to run the logic against (the existing `DevSeedData` is an in-memory `#if DEBUG` tool, not a version-controlled fixture). This initiative builds only the measurement substrate — the first brick every later validation capability (expert baseline, calibration scoring, blinded comparison) needs.

- **State owners to extend:** `SessionStore` (extend `StoredSession` with an evaluation-fixture flag + stable `fixtureID` and a bundled seed set), run through the existing `CoachContextBuilder` pipeline — no parallel eval store.
- **First step:** Add `isEvaluationFixture` / `fixtureID` to `StoredSession` (Noum/SessionStore.swift:18), commit a JSON seed of ~12-20 hand-curated sessions spanning the five pillars (filler-heavy, pace, structure-collapse-under-pressure, strong-baseline, cold-start), and add a test that loads each fixture, runs it through `CoachContextBuilder`, and snapshots the generated recommendation set so any logic change is diffable against known sessions.
- **Evidence threshold:** Do not claim any Validation progress beyond "substrate exists" from the eval set alone. The maturity needle moves only once an expert-coach baseline is captured for each fixture and a scored Noum-vs-baseline comparison agrees at a pre-registered rate on a majority of fixtures. A single fixture or a single good generation proves nothing, and confidence labels remain unscored until a reliability check exists.
- **Main risk:** The substrate could be mistaken for validation itself — a fixture set and snapshot test do not mean the coaching is calibrated, and claiming so would be the exact overclaim the stage exists to prevent. Doing it too early also risks calibrating against logic the higher-ranked initiatives will soon change. Mitigation: explicit "substrate only" framing, last in sequence, and no maturity claim until an expert baseline and a scored comparison exist.

## Sequencing

Follow the vision's own canonical post-M14 order; each step is gated on the previous being real and stable. M15 (stable ship) is the precondition for everything and is assumed in place.

- **M16 — case file + intervention cycle:** rank 1 (close the adaptation loop) and rank 2 (upcoming moment in the case file) land first. Rank 5 (baseline-grounded targets) is a natural companion to rank 1, because the adaptation verdict reads cleaner against a concrete target. Rank 6 (diagnosis reconciliation) rounds out the case-file layer.
- **M17 — delivery intelligence:** rank 3 (delivery fusion) should not begin until the case-file/intervention layer is trustworthy, because the fused read persists onto that same spine.
- **M18 — real-moment transfer:** rank 4 (cross-event transfer read) must follow rank 2 — the read is far more valuable once the moment lives on the durable case spine — and should follow rank 1 so a confirmed transfer trend can flow into the same adaptation machinery.
- **M19 — presence with consent:** intentionally omitted from this roadmap. Visual/nonverbal reads are deferred by the vision until audio and text coaching are trustworthy, and must be an explicit, consent-gated extension, never a hidden camera path.
- **M20 — human-coach calibration:** rank 7 (validation substrate) is deliberately last. It must measure a system that has stabilized, so standing it up before ranks 1-6 deepen the loop would calibrate against a moving target.

## Anti-goals guardrail

While pursuing these initiatives, do not build any of the following.

- **No new parallel systems.** No new store, screen, or routing layer — every initiative extends a named owner (`CoachingProfileStore`, `CoachMemoryStore`, `RecommendationLearningStore`, `CoachCaseFile`, `SessionStore`, `BigMomentStore`, `CoachContextBuilder`).
- **No metric-card dashboard.** Delivery work is editorial fusion (one read leads, details collapse), not another post-rep meter. A dashboard of vanity metrics is an explicit anti-goal.
- **No causation language.** Never "this drill improved your fillers"; only "tracking toward / not tracking toward."
- **No asserted inner-life claims.** Inferred psychological or interpersonal patterns (evasive, detached, timid, freezes-under-conflict) are always hypotheses the user can confirm or reject, never persisted or strengthened without asking.
- **No claims below their evidence floor.** No precise numeric targets, confident verdicts, transfer trends, or delivery characterizations below their stated thresholds (~3-5 reps for targets/verdicts, >= 3 same-kind events for transfer, ~4-5 consistent reps for a delivery read).
- **No silent focus switches.** On stated-vs-measured divergence, surface a question; do not auto-flip the stored focus.
- **No premature validation claims.** The eval substrate alone proves nothing; Validation maturity moves only with an expert baseline and a scored comparison.
- **None of the standing product anti-goals.** No presence/visual reads here, no fake gamification or unlocks, no punish-shame on regression, no hearts/lives practice-gating, and no leaderboard that publishes raw transcripts.
