# Research implementation audit

Source: `/Users/jordan/Downloads/deep-research-report (6).md`  
Audited: 2026-07-13 on branch `ux-overhaul`

The report is a useful product-direction document, but some of its repository
observations predate the current branch. This matrix treats runtime code and
tests as authoritative and prevents duplicate stores or replacement systems.

| Research requirement | Current implementation evidence | Status | Remaining production evidence |
|---|---|---|---|
| Goal-style outcome system | `GoalRubricStore`, `CoachReasoningPass`, and `GoalOutcomeRead` share one qualitative Summary/Review/Profile projection for authoritative, warm, concise, persuasive, executive, and storytelling goals. A separate deterministic `GoalStyleCalibrationEngine` produces versioned 0–100 candidates, confidence, missing-evidence, and rubric contributions only for a professional-review packet; it is disconnected from UI/persistence/analytics and Spanish/French fail closed. | Trust-preserving qualitative product alternative implemented; numeric candidate implemented for calibration only; humorous/calm product rubrics are not implemented | Bind a separate deidentified evidence package, complete blinded professional and longitudinal calibration, and make an explicit product/privacy decision before numeric identity scores or new style claims |
| Goal-aware feedback and rewrite | `AIRewriteService` and `RewriteSuggestionCard` support light/medium/strong movement, semantic/entity guards, and conservative fallback. A sanitized account-scoped Phrase Bank participates in export/deletion; a saved row can now seed the existing Timed one-shot prompt through a transient `PhrasePracticeIntent`. Spanish/French stop before English heuristics or provider resolution. | Implemented | Live-provider acceptance corpus and physical-device visual/interaction check |
| Adaptive drill prescription | `SessionFinalizer` / `NextActionEngine` own the active decision; `SummaryPrescriptionProjection` renders exactly one current-domain drill or full-rep action through existing routers. Goal movement is evidence only. Historical Review says “Repeat this rep,” preserves IM setup, and writes no new adaptive acceptance. | Implemented for the established Timed, Pressure, Ah Counter, IM, and mini-drill domain | A product decision is required before widening prescriptions to the separate Roleplay curriculum, Lessons, Speech Projects, or Path; longitudinal calibration remains external |
| Fast first session | `FastLaneOnboardingView`, `CoachingProfileDraft`, the existing `CoachingProfileStore`, `FirstRunOnboardingGate`, and a structure-only `RoleplayEngine` projection deliver offline written first value without speech permissions or fake delivery evidence. The raw response is transient; only a bounded content-free receipt persists. Full setup is prefilled/resumable and can continue into the existing consent/Timed path. The UI contract measures launch-to-result against the 60-second target. | Implemented locally; spoken and structured evidence remain distinct | Signed-device elapsed-time distribution, permission/consent, interruption/relaunch, and completed structured-to-spoken validation |
| Offline/on-device transcription | `LocalSpeechProvider`; release selection uses local-only when cloud consent is off and bounded Deepgram→local setup failover when allowed. A content-free, nonblocking notice appears only when a requested cloud startup resolves locally; mid-rep loss retains honest retry behavior instead of replaying audio to a second provider. | Implemented locally with the no-double-provider invariant preserved | Physical-device speech accuracy/locale matrix, airplane-mode rep, and visual/accessibility check of the fallback notice |
| Privacy and consent centre | Settings privacy card, `CloudProcessingConsentDisclosure`, `YourDataView`, processor manifest, export and account deletion | Implemented before M26 | Signed-device export/share/delete smoke and policy review at release |
| Multi-language expansion | UI/provider locale plumbing supports English, Spanish, and French. AI rewrite and goal-outcome paths explicitly suppress unsupported Spanish/French before English logic or transport. | Partial by design; the report's expansion beyond these locales is not implemented | Calibrated filler/semantic/rubric corpora per locale before expanding claims |
| Weekly goal-linked habit loop | Daily goal, proactive reminders, streak protection, weekly digest/check-in, goal-aware coach context | Implemented before M26 | Retention validation with real cohorts |
| Progress sharing | Session/proof share surfaces exist. Established goal outcomes now offer an opt-in milestone note that contains no transcript excerpt, raw score, or causal claim. | Implemented locally | Validate desirability and sharing behavior with real users after outcome calibration |
| Humour-specific training | No humour identity or calibrated rubric exists in the supported `SpeakingStyleGoal` set | Deferred intentionally, not implemented | Research and calibration; do not add an unvalidated identity score |
| Activation/transformation KPIs | Account-scoped `FlowEventLog`, `TransformationKPIReport`, session/provider history, recommendation outcomes, review/coach/notification lifecycle events, and the three-rep qualitative outcome question. Structured first value, tap intent, and the first later persisted spoken rep are separate reads; notification conversion is filtered to decisions at or after value. Prescription acceptance is shown-to-tap; cloud fallback includes only cloud-requested routes resolved locally. | Implemented as per-account diagnostics, not cohort rates or medians | Population aggregation requires an explicit privacy/telemetry decision; no transcript or dedicated analytics SDK is used |
| Onboarding A/B test | Exact versioned Remote Config tokens can select the existing full-onboarding control or permissionless fast lane for eligible new Release accounts. Assignment and actual exposure are separate account-local, content-free events; absent/unknown configuration stays unassigned on the fast lane, while developer, UI-test, returning, and already-started accounts are excluded. | Assignment/exposure contract implemented locally; default is unassigned | Product approval, configured allocation, population analysis, and signed-device validation are still required before claiming an experiment result |
| Generic review vs outcome-loop A/B test | Exact versioned Remote Config tokens can freeze a generic neutral-replay control or the shipping outcome-loop treatment for eligible fresh Release accounts. `FlowEventLog` owns content-free assignment, actual rendered exposure, bounded microphone/speech/locale context, and first-later-nonfixture-rep attribution. The empty/unknown default is unassigned on the shipping outcome loop; prior-session/Review, developer, and UI-test accounts are excluded. | Assignment/exposure/next-rep contract implemented locally; default is unassigned and no population result exists | Product/privacy approval, configured allocation, external aggregation, signed-device validation, and a calibrated 28-day outcome are required before claiming an experiment result |

The local KPI report covers first-value completion and elapsed time separately
from durable first-spoken-rep completion and elapsed time; it also separates the
structured-to-spoken tap from a later persisted spoken rep and reports the time
between them. It includes sessions per active week, review-open rate,
shown-to-tap prescription acceptance, typed-coach-to-live entry, 7/28-day
qualitative follow-up movement, post-value notification decision, D1/D7/D28
active-day return, and requested-cloud-to-resolved-local fallback. Deliberate
local-only sessions do not inflate the fallback rate. These are account-scoped
diagnostic signals included in deletion/export ownership; they are not
population rates, medians, causal slopes, or experiment results and must not be
presented as such.

## Current local evaluation evidence

The source-matched canonical Swift app-path artifact refreshed on 2026-07-13
covers 53 conversations and 109 turns. It has zero app-path floor failures,
target mismatches, missing metadata rows, semantic-gate failures, blocking
reliability issues, vision-floor failures, or readiness warnings. The arena
scores 50 required fixtures at a 79.76 average with local score/coverage,
real-pipeline evidence, and trace-quality gates passing. Source sidecars and all
embedded traces matched the clean checkout used for the refresh; the generated
report remains the authority for the exact commit and fingerprint values.

The canonical artifact-dump bridge also exports a calibration-only goal-style
packet. Its repository form is intentionally
`blockedPendingAccessControlledEvidencePackage`; opaque evidence-reference IDs
must be resolved through a separately delivered, access-controlled,
deidentified, SHA-256-bound package before any professional review is valid.
The packet is not product authorization.

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

The live-evidence producer now stages either a deliberately authorized production
provider sweep or a SHA-256-attested capture and publishes only after the complete
current-source corpus and readiness contract pass. The external release-evidence
workflow separately binds real reviewer, longitudinal, TestFlight, and operational
attachments and cannot promote placeholder or self-attested rows. Neither workflow
overrides the still-active unauthenticated legacy AWS credential leak. A read-only
production social inventory also found six legacy public profiles, fifteen league
memberships, six manifests, and no cutover marker; mutation remains approval-gated.

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
- A structured first-value receipt never counts as a spoken rep or unlocks
  speech-derived coaching evidence, progress, or rewards.
- The auto-guided first-rep release default stays off until the signed-device
  permission/consent/interruption matrix passes; simulator-only evidence is not
  sufficient to change it.
