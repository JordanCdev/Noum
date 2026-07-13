# Noum Development Plan: Goal-Directed Speaking Transformation

**Source:** `deep-research-report (6).md`  
**Status:** Core loop and permissionless first-value path implemented locally;
production-evidence closure in progress
**Planning assumption:** The original 8–10 week estimate is historical. Runtime
code, `docs/CURRENT_STATE.md`, and `docs/RESEARCH_IMPLEMENTATION_AUDIT.md` now
define the implemented state.

## Current execution status — 2026-07-13

The research plan is no longer a greenfield specification. Noum already reuses
the established goal, session, coach, recommendation, privacy, transcription,
export/deletion, and navigation owners. Do not create the proposed parallel
`GoalStyle`, `GoalPrescription`, privacy, onboarding, or analytics systems.

| Research phase | Current status | Remaining closure |
|---|---|---|
| Baseline and contracts | Implemented as account-local, content-free diagnostics | Keep cohort claims honest; population analytics still requires a privacy decision |
| Fast-lane activation | Implemented locally as a permissionless, structure-only written rehearsal owned by the existing profile store and root router; launch-to-result is asserted under 60 seconds in UI automation | Validate the elapsed distribution and completed structured-to-spoken conversion on signed devices |
| Goal-style outcome | Implemented publicly as qualitative `GoalRubricStore` / `GoalOutcomeRead` projections; a separate deterministic 0–100 candidate exists only for professional calibration and unsupported locales fail closed | Bind a deidentified source-evidence package, complete professional/longitudinal calibration, and make a separate product/privacy decision before any numeric UI; humorous/calm remain unimplemented product goals |
| Actionable coaching | Rewrite, semantic-preservation guard, practiceable phrase bank, and one finalizer-owned Summary prescription are implemented; an exact-token generic-review versus outcome-loop assignment/exposure/next-rep contract exists but is inactive | Product/privacy approval, configured allocation, population analysis, live-provider acceptance, and physical-device visual/interaction proof |
| Trust and reliability | Local speech, consent routing, startup-fallback transparency, privacy, export/deletion, atomic live evidence, exact launch-prerequisite/history-scan validation, a status-only five-route containment probe, and a redacted Apple signing/TestFlight preflight are implemented | Revoke the leaked legacy Deepgram credential, protect/disable every legacy route, audit provider usage/billing, install paid-team distribution authority, and complete physical-device and release-policy verification |
| Retention and expansion | Local KPI, weekly check-in, reminder, and goal-movement substrate implemented; both research experiment contracts default to unassigned | Product approval and real cohort analysis, protected social cutover, and calibrated language expansion |

The supported local evidence refresh is:

```bash
./tools/coach-arena/run.sh evidence-refresh --no-fail
```

The workflow now fails when its local Swift package cache is absent, disables
automatic package resolution, unsets provider/judge keys for the XCTest bridge,
and disables code signing. It regenerates local evidence only; it cannot spend
provider quota or manufacture any external artifact.

A real live-provider sweep requires explicit quota authorization and publishes
only after the current-source capture passes atomically:

```bash
./tools/coach-arena/run.sh live-evidence --allow-live-network
```

Externally earned reviewer, longitudinal, TestFlight, and operational evidence
is collected through `tools/release-evidence/run.sh`; its templates fail by
default and cannot be promoted without source binding, real hashed attachments,
independent verification, and acceptance by the existing readiness validator.

Production readiness still requires independently sourced professional-coach,
longitudinal real-user, physical TestFlight, and operational release evidence,
plus a fresh current-source zero-refusal live-provider sweep. The legacy AWS
endpoint must also be disabled/protected and its leaked Deepgram credential
revoked before release. The current provider
environment has returned Gemini HTTP 429 and DeepSeek HTTP 402; those operational
failures must be resolved rather than hidden by a generated artifact.

The longitudinal gate uses `coach-real-user-transfer-outcomes-v3.json`. Its
cohort and analysis plan must be registered before results are collected; every
completed outcome stays in the ledger, including regressions and adverse reports.
Readiness evaluates the cohort distribution rather than demanding a cherry-picked
perfect sample: at least 60% positive transfer and 70% non-regression across the
full qualifying set, with coherent enrollment/withdrawal/exclusion accounting and
evidence-backed resolution for every adverse outcome.

## 1. Product outcome

Make Noum clearly answer one question: **“Is this helping me become the kind of speaker I want to be?”**

The primary loop should be:

```text
Choose a speaking goal → complete a baseline rep → receive an evidence-bounded goal read
→ do the best next drill → review a rewrite → set a micro-goal
→ return for weekly progress
```

The existing five-tab shell, practice modes, session history, coach, and account infrastructure should be reused. The roadmap is about connecting those pieces around a single outcome, not adding more destinations.

## 2. Priorities and sequencing

| Phase | Outcome | Priority | Exit signal |
|---|---|---:|---|
| 0. Baseline and contracts | Confirm current implementation, define shared models, and instrument the funnel | P0 | Baseline dashboard and architecture decisions approved |
| 1. Fast-lane activation | Get a new user to useful structure feedback in under 60 seconds without requiring voice permissions | P0 | First-value completion/time improve without being conflated with a spoken rep |
| 2. Goal-style outcome | Show credible movement toward the canonical selected style without unsupported identity precision | P0 | Deterministic qualitative read appears in Summary, Review, and Profile |
| 3. Actionable coaching | Turn evidence into one next drill plus concrete rewrite practice | P0 | Review-to-next-rep conversion improves |
| 4. Trust and reliability | Make cloud/local processing explicit and preserve practice when offline | P1 | Fallback works; privacy controls match actual behavior |
| 5. Retention and expansion | Tie weekly habits, language support, and social milestones to the chosen goal | P2 | 28-day goal improvement and retention are measurable |

## 3. Phase 0 — Baseline, architecture, and instrumentation

### Deliverables

- Audit the current branch against the report. Mark each recommendation as `existing`, `partial`, or `missing`; the repository already contains related work such as `LocalSpeechProvider.swift` and prior goal-aware scoring artifacts.
- Keep `CoachingProfile.chosenStyleGoal` as the single shared speaking-goal persistence path. Do not create parallel onboarding/profile goal models.
- Reuse `GoalOutcomeRead`, `RewriteSuggestion`, the finalized `NextAction`, and their evidence/confidence semantics. Do not create the report's proposed parallel score or prescription owners.
- Keep content-free activation, value, review, prescription, provider-route, retention, notification, and qualitative-outcome events in the account-scoped `FlowEventLog`.
- Establish a privacy threat model for audio, transcripts, credentials, exports, and deletion.

### Likely files

`CoachingOnboardingView.swift`, `FirstRunOnboardingManager.swift`, session models/store, `ContentView.swift`, `SessionHistoryView.swift`, `ProfileView.swift`, and the existing analytics abstraction.

### Acceptance criteria

- One canonical goal value is available from onboarding, session analysis, review, profile, and prescription code.
- Existing sessions and users without a goal remain readable and receive a low-confidence/default state.
- Assigned first-run exposures include bounded permission state, locale, version, and variant without recording raw audio, transcript content, or typed responses. Provider route remains a separate practice event.

## 4. Phase 1 — Fast-lane first session

### Scope

The shipping local path now asks for one context and one speaking challenge,
then runs an authored, offline written rehearsal. The result names one supported
structural strength and one next move while explicitly withholding filler, pace,
pause, tone, composure, and other speech-only claims. It persists only a bounded,
content-free receipt; it does not create a `PracticeSession`, score, XP, streak,
baseline, or synthetic speech evidence. A user can continue through the remaining
profile choice into spoken coaching or explore first and resume setup from Home.

`AutoGuidedFirstRep` remains the existing default-off spoken path. It is not used
as the permissionless value mechanism and still requires its signed-device
permission/consent matrix before release enablement.

### Implementation

- `FastLaneOnboardingView.swift` uses the existing `SpeakingContext` and
  `SpeakingChallenge` values plus a structure-only `RoleplayEngine` projection.
- `FirstRunOnboardingGate`, `CoachingProfileStore`, `CoachingOnboardingView`,
  `NoumApp`, and `ContentView` share routing, account scope, prefill, and resume
  behavior; no parallel profile or onboarding-completion flag was added.
- The typed response remains transient. The account-scoped draft and receipt
  participate in the existing export/deletion registry.
- `TransformationKPIReport` keeps spoken `firstRepCompleted` semantics and adds
  separate first-value, structured-value, tap-intent, and later persisted
  structured-to-spoken completion reads.

### Acceptance criteria

- Fresh install can receive useful first value without an authentication screen,
  microphone permission, cloud processing, or a spoken session.
- The deterministic UI test reaches the structure-only result in under 60 seconds;
  signed-device elapsed-time distribution remains release evidence.
- Denied permissions never create a dead end.
- A coherent first-value receipt prevents the fast lane repeating after relaunch;
  incomplete profile setup remains quietly resumable from Home.

### Experiment

The code can accept exact, versioned Remote Config assignments for the existing
full-onboarding control or fast lane, and it records assignment separately from
actual exposure. The empty default performs no assignment; unknown tokens fail
closed; developer, UI-test, returning, and already-started accounts are excluded.
Activate an allocation and population analysis only after an explicit
privacy/product decision. Keep
time-to-first-value and first-value completion separate from time-to-first-spoken-
rep and spoken-rep completion; also keep the structured-to-spoken tap separate
from the later persisted spoken rep and segment D1/D7 retention by the bounded
permission state recorded at exposure.

## 5. Phase 2 — Goal-style outcome engine

### Scope

The report proposed transcript-derived 0–100 scoring for `authoritative`,
`concise`, `humorous`, `warm`, and `calm`. Noum deliberately does not ship that
identity-precision model without longitudinal human calibration. The implemented
system provides qualitative, evidence-bounded outcomes for the canonical
authoritative, warm, concise, persuasive, executive, and storytelling goals.

### Implementation

- Reuse `GoalRubricStore`, `CoachReasoningPass`, and `GoalOutcomeRead` across
  Summary, Review, and Profile.
- Use established transcript/session signals only when their evidence floor is
  met; weak or contradictory evidence stays insufficient, forming, or mixed.
- Keep next action owned by `SessionFinalizer` / `NextActionEngine`, not the
  outcome projection.
- Add a public numeric score, humour rubric, or calm identity only after a
  calibrated protocol supports the claim.
- Use `GoalStyleCalibrationEngine` and its source-evidence-package-bound reviewer
  packet only for professional calibration. It must remain disconnected from UI,
  persistence, analytics, experiment allocation, and product claims.

### Acceptance criteria

- Fixed evidence produces the same qualitative read across runs.
- Missing/short/unsupported evidence withholds the read or returns an
  insufficient state instead of inventing precision.
- Goal-specific rubric weights and evidence floors are deterministic and tested.
- Outcomes are labelled as evidence-bounded coaching reads, not objective
  personality labels or causal claims.

## 6. Phase 3 — Actionable review and adaptive prescription

### 3A. Goal-aware rewrite review

- Extend the existing `AIRewriteService`, `RewriteSuggestionCard`, and
  `PhraseBankStore`; do not create parallel goal-rewrite owners.
- For each selected transcript snippet, provide light, medium, and strong rewrites.
- Preserve meaning; show original versus suggestion; allow saving a phrase to a reusable, account-scoped phrase bank that is covered by export and deletion, then practice that phrase through the existing Timed one-shot prompt handoff.
- Provide deterministic heuristic templates when an AI service is unavailable.

### 3B. Adaptive next-rep prescription

- Keep `SessionFinalizer` / `NextActionEngine` as strategic owners and project
  their result through one Summary action card. Do not add a parallel
  `GoalPrescriptionEngine`.
- Output exactly one best next rep with a short rationale. Historical Review
  may replay a recorded setup but does not record adaptive acceptance.
- Reuse existing destinations: timed, sudden death, ah counter, Cut the Crutch, pace training, roleplay, lessons, speech projects, and path.
- Respect availability/permission gates and fall back to a viable mode.

### Acceptance criteria

- Review always ends with one clear next action.
- High filler burden maps to filler-focused practice and pacing issues map to
  pace work inside the established action domain. Widening strategic
  prescriptions to the separate Roleplay curriculum, Lessons, Speech Projects,
  or Path requires a product decision and router expansion.
- Locked or unavailable modes fall back gracefully.
- Rewrite suggestions preserve semantic intent and phrase-bank data survives relaunch.

### Experiment

The production assignment/exposure contract now exists but is inactive by
default. Exact Remote Config tokens select either a neutral generic-review replay
or the shipping goal-outcome/adaptive-prescription loop for eligible fresh Release
accounts. Assignment, actual rendered exposure, bounded permission/locale context,
and the first later persisted nonfixture rep are separate account-local reads.
Unknown or absent configuration remains unassigned on the shipping outcome loop;
developer, UI-test, prior-session, and prior-Review accounts cannot be newly
enrolled. Do not activate allocation or claim an experiment result until a
product/privacy decision approves the non-degrading control, population analysis,
and calibrated 28-day outcome. The current `earlyImprovement` follow-up proportion
is not a numeric goal-score slope.

## 7. Phase 4 — Trust, privacy, and reliability

### Offline/local processing

- Keep `LocalSpeechProvider` behind the existing provider abstraction.
- Consent-off selects local without constructing cloud. Consent-on uses one
  bounded Deepgram-to-local startup fallback before microphone audio is sent.
- Persist the cloud-processing preference and show a restrained, nonblocking
  notice only when requested cloud startup actually resolves locally.
- Missing credentials, startup network failure, unsupported locale, and provider
  timeout fail clearly. Mid-stream loss stops the rep with actionable retry; it
  must not replay or duplicate that rep's audio to a second provider.

### Privacy centre

- Reuse the existing Settings privacy card, `AISettingsManager`, consent
  disclosure, and `YourDataView`; do not create a parallel privacy store.
- Surface cloud transcription on/off, data export, account deletion entry point,
  processor/configuration behavior, and a plain-language data summary.
- Reuse `AccountDataExportService` and existing Firestore/account rules.
- Remove any production dependency on long-lived client-embedded AWS credentials; use temporary credentials or a server-mediated flow.
- Treat the still-live legacy unauthenticated AWS credential endpoint as a hard
  release blocker even though the replacement Firebase callable is healthy.

### Acceptance criteria

- Practice works without AWS credentials and with cloud processing disabled.
- Toggling cloud mode changes runtime provider selection and persists across relaunch.
- Export and deletion entry points are reachable and accurately describe exclusions/retention.
- Privacy copy is reviewed against the actual provider and storage behavior.

## 8. Phase 5 — Retention and expansion

The local substrate exists, but expansion claims remain gated on activation and
core-loop validation.

- Weekly goal dashboard and one micro-goal per week.
- Streaks/notifications tied to the selected speaking goal, not generic activity.
- Expand language coverage and locale-specific filler heuristics beyond the verified en-US/es-ES/fr-FR path.
- Shareable goal milestones using existing social/league infrastructure.
- Deeper humour-specific training only after the qualitative outcome system is
  professionally calibrated for that claim.
- Accessibility regression sweep for VoiceOver, Dynamic Type, Reduce Motion, keyboard navigation, and custom cards after each new surface.

## 9. Cross-cutting quality gates

Every phase must include:

- Unit tests for scoring, routing, persistence, fallback, and migration behavior.
- UI tests for fresh install, denied microphone, offline mode, missing transcript, and returning-user flows.
- Accessibility identifiers and VoiceOver labels for new controls and cards.
- Performance checks for first-rep launch and provider startup latency.
- Analytics validation in a non-production environment.
- Screenshot or simulator review for Home, Train, Review, Profile, and Settings changes.

## 10. Success metrics

Track these as the release scorecard:

- Median time-to-first-value and first-value completion rate, aggregated outside
  the app from approved account-local evidence and reported separately from
  time-to-first-spoken-rep and spoken-rep completion.
- Structured-to-spoken tap intent, later persisted spoken completion, and
  typed-coach-to-live entry as separate funnels.
- Practice sessions per active user per week.
- Session-review open rate and content-free shown-to-tap prescription acceptance rate.
- Calibrated goal improvement after 7 and 28 days; until then, label the local
  follow-up read as an early-improvement proportion rather than a score slope.
- D1, D7, and D28 retention.
- Cloud-to-local fallback rate and provider failure rate.
- Notification opt-in after the first value moment.
- Qualitative prompt after three reps: **“Did Noum help you move toward the speaker you want to be?”**

## 11. Risks and decisions to resolve early

| Risk | Mitigation / decision |
|---|---|
| Feature sprawl returns | Make “best next rep” the default home/train action; keep the library secondary. |
| Scores feel arbitrary | Show dimensions, examples, confidence, and trend; avoid personality claims. |
| AI availability blocks coaching | Ship deterministic rewrite/prescription fallbacks. |
| Cloud privacy undermines trust | Default to explicit consent, transparent provider state, and safe credential architecture. |
| Existing partial implementations conflict | Complete the Phase 0 audit before creating duplicate models or providers. |
| Accessibility debt grows | Treat accessibility tests and reusable components as release gates. |

## 12. Definition of done for the first validated release

The release is ready when a new user can choose a goal, complete a rep, see an
explainable qualitative outcome, receive one actionable next drill, and complete
that drill with or without cloud transcription. The path must be measurable
end-to-end, privacy behavior must match the UI, and the experiment must show
improved activation or next-rep conversion before expanding into additional modes
or social features. Production-ready status additionally requires a fresh
zero-refusal current-source live-provider sweep, blinded professional-coach
calibration, longitudinal real-user transfer evidence, physical TestFlight QA,
and a completed operational launch checklist; simulator fixtures cannot replace
any of those gates.
