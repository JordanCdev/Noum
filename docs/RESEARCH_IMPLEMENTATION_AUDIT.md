# Research implementation audit

Source: `/Users/jordan/Downloads/deep-research-report (6).md`  
Audited: 2026-07-13 on branch `ux-overhaul`

The report is a useful product-direction document, but some of its repository
observations predate the current branch. This matrix treats runtime code and
tests as authoritative and prevents duplicate stores or replacement systems.

| Research requirement | Current implementation evidence | Status | Remaining production evidence |
|---|---|---|---|
| Goal-style outcome system | `GoalRubricStore`, `CoachReasoningPass`, and `GoalOutcomeRead` share one qualitative Summary/Review/Profile projection. Spanish/French stop before English goal inference. | Implemented in M26; locale trust boundary hardened | Longitudinal human calibration before stronger identity claims |
| Goal-aware feedback and rewrite | `AIRewriteService` and `RewriteSuggestionCard` support light/medium/strong movement, semantic/entity guards, and conservative fallback. A sanitized account-scoped Phrase Bank participates in export/deletion; a saved row can now seed the existing Timed one-shot prompt through a transient `PhrasePracticeIntent`. Spanish/French stop before English heuristics or provider resolution. | Implemented | Live-provider acceptance corpus and physical-device visual/interaction check |
| Adaptive drill prescription | `SessionFinalizer` / `NextActionEngine` own the active decision; `SummaryPrescriptionProjection` renders exactly one drill or full-rep action through existing routers. Goal movement is evidence only. Historical Review says “Repeat this rep,” preserves IM setup, and writes no new adaptive acceptance. | Implemented and simulator/UI-proven | Longitudinal real-user calibration |
| Fast first session | Transactional guest bootstrap, three-choice onboarding, `AutoGuidedFirstRep`, seeded prompt and fast-start handshake; erased-simulator decline, failure-recovery, interruption/relaunch, and deferred-capture matrix passes. The current auto-guided path still requires usable microphone permission and therefore is not the report's typed/structured permissionless first rep. | Partial behind default-off release flag | Decide/build the permissionless activation contract, then run signed-device elapsed-time, microphone-permission, consent, interruption, and relaunch validation before enablement |
| Offline/on-device transcription | `LocalSpeechProvider`; release selection uses local-only when cloud consent is off and bounded Deepgram→local setup failover when allowed | Implemented in M26 | Physical-device speech accuracy/locale matrix and airplane-mode rep |
| Privacy and consent centre | Settings privacy card, `CloudProcessingConsentDisclosure`, `YourDataView`, processor manifest, export and account deletion | Implemented before M26 | Signed-device export/share/delete smoke and policy review at release |
| Multi-language expansion | UI/provider locale plumbing supports English, Spanish, and French. AI rewrite and goal-outcome paths explicitly suppress unsupported Spanish/French before English logic or transport. | Partial, with honest boundary enforced | Calibrated filler/semantic/rubric corpora per locale before expanding claims |
| Weekly goal-linked habit loop | Daily goal, proactive reminders, streak protection, weekly digest/check-in, goal-aware coach context | Implemented before M26 | Retention validation with real cohorts |
| Progress sharing | Session/proof share surfaces exist. Established goal outcomes now offer an opt-in milestone note that contains no transcript excerpt, raw score, or causal claim. | Implemented locally | Validate desirability and sharing behavior with real users after outcome calibration |
| Humour-specific training | No humour identity exists in the supported `SpeakingStyleGoal` set | Deferred intentionally | Research and calibration; do not add an unvalidated identity score |
| Activation/transformation KPIs | Account-scoped `FlowEventLog`, `TransformationKPIReport`, session/provider history, recommendation outcomes, review/coach/notification lifecycle events, and the three-rep qualitative outcome question. Prescription acceptance is a content-free shown-to-tap pair; cloud-to-local fallback includes only cloud-requested routes that resolved locally. | Implemented locally in M26 | Cohort aggregation requires an explicit privacy/telemetry decision; no transcript or third-party analytics SDK is used |
| Onboarding A/B test | Overrideable first-rep flag exists | Partial | Experiment assignment and cohort analysis require a privacy/product decision |
| Generic review vs outcome-loop A/B test | Both underlying presentations can be gated, but no cohort assignment exists | Partial | Same experiment decision; do not silently enroll users |

The local KPI report now covers first-rep completion and elapsed time,
sessions per active week, review-open rate, shown-to-tap prescription acceptance,
typed-to-live upgrade, 7/28-day qualitative goal movement, notification
decision, D1/D7/D28 active-day return, and requested-cloud-to-resolved-local
fallback. Deliberate local-only sessions do not inflate the fallback rate. These
are account-scoped diagnostic signals included in deletion/export ownership;
they are not population analytics and should not be presented as such.

## Current local evaluation evidence

The source-matched canonical Swift app-path artifact refreshed on 2026-07-13
covers 53 conversations and 109 turns. It has zero app-path floor failures,
target mismatches, missing metadata rows, semantic-gate failures, blocking
reliability issues, vision-floor failures, or readiness warnings. The arena
scores 50 required fixtures at a 79.76 average with local score/coverage,
real-pipeline evidence, and trace-quality gates passing. Source sidecars and all
embedded traces matched the clean checkout used for the refresh; the generated
report remains the authority for the exact commit and fingerprint values.

This is local implementation evidence only. Production readiness remains
18/100, capped at 20/100, until the five independently sourced launch artifacts
exist: live-provider transcripts, professional-coach calibration, longitudinal
real-user outcomes, physical TestFlight QA, and the completed operational
launch checklist. No placeholder artifact can satisfy those gates.

The available live-provider artifact predates the final-visible reliability and
research-loop closure work and is therefore correctly rejected by the freshness
gate. It also contains real Gemini HTTP 429
`RESOURCE_EXHAUSTED` and DeepSeek HTTP 402 refusals. A fresh current-source run
must meet the zero-refusal readiness floor after those provider capacity/account
conditions are resolved; local fallback quality does not erase an operational
refusal from release evidence.

The real-user transfer contract is now v3 and no longer requires an implausible
10/10 positive, non-regressing, adverse-free sample. It requires a registered
protocol, analysis plan, benchmark reference, coherent cohort completion and
exclusion log, the full set of positive and negative rows, a 60% positive-transfer
floor, a 70% non-regression floor, and documented resolution of every adverse
outcome. This closes the former incentive to omit users whose result was mixed or
negative while keeping the evidence bar independently auditable.

## Release invariants

- No 0–100 speaking-identity score until calibrated against longitudinal human
  judgments; qualitative evidence and movement states remain the public model.
- Cloud consent off must never instantiate a cloud transcription provider.
- Cloud fallback must happen before audio streaming begins; audio is never sent
  to two providers for one rep.
- Weak or contradictory evidence remains `insufficient`, `forming`, or `mixed`.
- Recommendation response is association only; copy never claims a drill caused
  an improvement.
- Existing account, profile, session, recommendation, privacy, and navigation
  owners remain the single sources of truth.
- The auto-guided first-rep release default stays off until the signed-device
  permission/consent/interruption matrix passes; simulator-only evidence is not
  sufficient to change it.
