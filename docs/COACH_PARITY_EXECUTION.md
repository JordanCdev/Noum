# Coach Parity Execution Plan

Generated: 2026-06-01

This plan sequences the adversarially-verified roadmap (`docs/COACH_PARITY_ROADMAP.md`) from the shipped initiative #1 to the coach-parity bar, and states plainly where machine work ends and human gates begin. It DOES achieve: a static, file:line-grounded verification that initiative #1's code is sound, hand-traced test coverage, and implementation-ready specs for #2-#7 that extend only named owners and honor every coaching invariant. It does NOT achieve — and on this host cannot — a compiled build, a passing test run, device QA, a TestFlight release, real-user outcomes, or human-coach calibration. Coach parity is proven by durable user outcomes over time and a scored comparison against an excellent human coach. It is never claimed from a single LLM reply, one rep, a feature checklist, or a green test suite. Treat this document as the map between here and those human-only gates, not as evidence of parity.

## Initiative #1 — status: BUILT, pending compile

Verified clean across three independent lenses (compile-failure cold-read; per-test hand-trace of all 22 new tests; coaching-invariant + coach-lens audit). No compile failures, no broken pre-existing test, no invariant breach, no new parallel system. The reducer is a pure free enum (`RecommendationAdaptationAnalyzer` in `Noum/PracticeSupport.swift`), the engine bias is a total tie-breaker (`shouldDeferReinforcement` inside Priority 6 of `Noum/NextActionEngine.swift`), and the verdict surfaces coherently on all three coaching surfaces.

Punch list before compile:

- **CLEAN** — all three lenses non-blocking, zero blocker/high findings.
- **MUST-DO (the one real gate):** run `xcodebuild test` on a Mac. Every test was hand-traced only, never executed (`docs/initiatives/01_adaptation_loop_spec.md:301`).
- **Count check (non-blocking):** brief said 20 analyzer tests; lens 1 counted 19 `@Test` functions + 2 deferral tests. Reconcile when the suite runs. No build impact.
- **Doc nit (low, optional):** comment the deliberate cross-surface keying difference at `Noum/PrimaryFocusMemory.swift` ~1491-1498 — case file keys on the most-recent outcome, chat/plan key on the most-followed group. Same reducer per key (no contradiction); document the seam. Fold into #2.
- **Doc nit (low, optional):** reconcile `docs/initiatives/01_adaptation_loop_spec.md` "Wiring edits #2" — only Priority 6 reinforcement-deferral shipped, not the spec's P3/P7/P8/standardDrill bias. The shipped version is strictly more conservative and violates no criterion; the doc over-states scope.

## Phased path (each phase gated on the previous being real and stable)

| Milestone | Work | Gate before next phase starts | Who passes |
| --- | --- | --- | --- |
| **M16 — case file + intervention cycle** | #1 (adaptation loop — built, anchors the phase), then #5 (baseline-grounded success bar), #6 (focus-vs-stated-challenge reconciliation), #2 (upcoming moment in the durable case file). All extend named owners only. | #1 compiles + full suite green on a real toolchain; then each of #5/#6/#2 compiles, passes its own test matrix + the full regression suite, and passes device QA confirming coherent reads with no fake certainty below floor. Sign-offs needed: #6 selectLever precedence; #2 moment-alone-seeds-case-file guard; #5 floor value (3 vs 5 reps). | user-mac-compile |
| **M17 — delivery intelligence** | #3 (fuse per-rep delivery reads into ONE durable `CoachDeliveryRead` on the case spine — the most interpretively dangerous initiative; dual gate of >=4 scored reps AND >=0.60 direction consistency before any characterization). | M16 layer trustworthy + stable (the fused read persists onto that spine); then #3 compiles, passes its fusion matrix (forming below floor, the 4-rep boundary, association-only/no-trait copy locks, soft-speaker non-mislabel, decode-safety, single-source coherence), regression, device QA. Load-bearing sign-off: is persist-as-rejectable-hypothesis enough, or must an established read gain a confirm/reject chip? Pin the pattern-disambiguation ladder. | device-qa |
| **M18 — real-moment transfer** | #4 (aggregate Big Moment outcomes into a tentative cross-event transfer read; durable write only on explicit user confirmation, invalidated on direction flip). | Must follow #2 (moment on the durable spine) and #1 (confirmed trend flows into the adaptation machinery); then #4 compiles, passes its reducer matrix (exhaustive direction map, recurrence floor, per-kind isolation, window cap, order-independence, decode-safety, confirm-gated durable write, flip-invalidation), regression keeping the locked flat-block tests green, device QA. Load-bearing sign-off: the confirm gesture is net-new — confirm the design vs shipping only the tentative per-turn aggregate first. | device-qa |
| **M19 — presence with consent** | INTENTIONALLY DEFERRED. No initiative. Visual/nonverbal reads are deferred by the VISION until audio + text coaching are trustworthy, and must be an explicit consent-gated extension — never a hidden camera path. | N/A — deferred by design. Entering it at all is a product + ethics decision gated on M16-M18 being durably trustworthy in real use, behind an explicit consent surface. | real-users |
| **M20 — human-coach calibration** | #7 (version-controlled evaluation substrate wired to the live logic — SUBSTRATE ONLY; fixtures must never leak into the live store/baseline/rating/league/backend). | FINAL gate — cannot be passed by code. Substrate (fixtures + leak-guarded snapshot test compiling) is passable by compile; the validation maturity needle moves ONLY when an expert coach captures a per-fixture baseline AND a scored Noum-vs-baseline comparison agrees at a pre-registered rate on a majority of fixtures AND longitudinal real-user outcomes confirm durable improvement. No "validated" claim from a green snapshot alone. | human-coaches |

## Per-initiative spec pointers

- **#1** — `docs/initiatives/01_adaptation_loop_spec.md` (shipped; implementation note records the confident-replace gate correction to recent-window level `<= -0.5` and the all-three-surface coherence resolution).
- **#2** — Fold upcoming moment into `CoachCaseFile`. Correction: `CoachCaseFile.build` is a PURE `CoachMemory -> CoachCaseFile` transform; thread the raw `BigMoment` onto `CoachMemory` from `Noum/SessionFinalizer.swift` (mirroring `lastTransferReport`), do NOT read `BigMomentStore` inside build.
- **#3** — Fuse delivery reads in `DerivedReadsTrendEngine.fuseDeliveryRead`; persist one `CoachDeliveryRead?` on the case spine; surface through the single `coachCaseFileLines` emitter (no per-surface recompute).
- **#4** — `BigMomentTransferTrend.build` reducer in `Noum/BigMomentStore.swift`. Correction: roadmap's "better/as-expected" axis does not exist — use the real `ReportedMomentOutcome` x `ReportedAudienceResponse` map.
- **#5** — Thread the already-computed `priorAverage` + sample depth into `criterionSummary` (`Noum/PrimaryFocusMemory.swift`) behind a >=3-prior-rep gate; one bounded decode-safe `BaselineSnapshot`. Correction: roadmap's `updateActiveInterventionFromRecommendation`/`targetLine`/`successLine` symbols do not exist; the real path is `activeIntervention -> enrichWithCase -> buildSuccessCriterion -> criterionSummary`.
- **#6** — `selectLever` stated-challenge fallback + a `CoachLeverConcordance` flag in `CoachMemoryEngine.build`; divergence emits a QUESTION, never an auto-flip. Correction: `SpeakingChallenge.recommendedPriority` returns `CoachingPriority`, not `SkillArea` — compose it through `ForwardPlanService.skillAreaForAIWeek`.
- **#7** — `docs/initiatives/07_evaluation_substrate_spec.md` (to author). Correction: roadmap's `SessionStore`/`StoredSession`/`Noum/SessionStore.swift` do not exist — extend the real `PracticeSession` + `PracticeSessionStore` in `Noum/PracticeSupport.swift`.

## What only you / your users / real coaches can do

This is the honest boundary. Everything above is code an agent can author and statically verify. None of the following can be done by any workflow, and none is optional.

- **You (Jordan), on your Mac:** compile, run the full test suite, do device QA on the simulator/device, archive and ship to TestFlight. Until `xcodebuild test` runs green, initiative #1 is built, not shipped. You also own the load-bearing sign-offs each phase gates on (precedence in #6, the confirm-affordance questions in #3 and #4, the floor values).
- **Your users, over time:** generate the durable longitudinal evidence that the loop actually improves communication. A green test proves the code does what it says; it does not prove the coaching works. Real-world transfer and adaptation are proven by people practicing across weeks, read through honest telemetry — including the evidence-density questions #1 and #4 leave open.
- **Real coaches:** decide whether Noum's read matches what an excellent human communication coach would say. The evaluation substrate (#7) is the measuring stick, not the verdict. The Validation maturity needle moves only with an expert per-fixture baseline and a scored, pre-registered comparison.

Parity is the destination, not a milestone you can merge. This plan gets the code to the door; the people above walk it through.

