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
| Baseline and contracts | Implemented locally | Keep event names and cohort claims honest; population analytics still requires a privacy decision |
| Fast-lane activation | Implemented locally as a permissionless, structure-only written rehearsal owned by the existing profile store and root router | Validate elapsed time and the structured-to-spoken upgrade on signed devices; experiment assignment still requires a privacy/product decision |
| Goal-style scoring | Implemented as qualitative `GoalRubricStore` / `GoalOutcomeRead` projections; unsupported locales are suppressed before English inference | Human calibration; retain qualitative/low-confidence language until calibrated |
| Actionable coaching | Rewrite, semantic-preservation guard, practiceable phrase bank, and one finalizer-owned Summary prescription are implemented; historical Review is replay-only | Live-provider acceptance corpus and physical-device visual/interaction proof |
| Trust and reliability | Local speech, consent routing, privacy, export, and deletion implemented | Physical-device and release-policy verification |
| Retention and expansion | Local KPI, weekly check-in, reminder, and goal-movement substrate implemented | Real cohort validation, experiment assignment decision, and calibrated language expansion |

The supported local evidence refresh is:

```bash
./tools/coach-arena/run.sh evidence-refresh --no-fail
```

Production readiness still requires independently sourced professional-coach,
longitudinal real-user, physical TestFlight, and operational release evidence,
plus a fresh current-source zero-refusal live-provider sweep. The current provider
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
Choose a speaking goal → complete a baseline rep → receive a goal score
→ do the best next drill → review a rewrite → set a micro-goal
→ return for weekly progress
```

The existing five-tab shell, practice modes, session history, coach, and account infrastructure should be reused. The roadmap is about connecting those pieces around a single outcome, not adding more destinations.

## 2. Priorities and sequencing

| Phase | Outcome | Priority | Exit signal |
|---|---|---:|---|
| 0. Baseline and contracts | Confirm current implementation, define shared models, and instrument the funnel | P0 | Baseline dashboard and architecture decisions approved |
| 1. Fast-lane activation | Get a new user to useful structure feedback in under 60 seconds without requiring voice permissions | P0 | First-value completion/time improve without being conflated with a spoken rep |
| 2. Goal-style scoring | Quantify progress toward authoritative, concise, humorous, warm, or calm communication | P0 | Deterministic scorecard appears in session review and profile |
| 3. Actionable coaching | Turn scores into one next drill plus concrete rewrite practice | P0 | Review-to-next-rep conversion improves |
| 4. Trust and reliability | Make cloud/local processing explicit and preserve practice when offline | P1 | Fallback works; privacy controls match actual behavior |
| 5. Retention and expansion | Tie weekly habits, language support, and social milestones to the chosen goal | P2 | 28-day goal improvement and retention are measurable |

## 3. Phase 0 — Baseline, architecture, and instrumentation

### Deliverables

- Audit the current branch against the report. Mark each recommendation as `existing`, `partial`, or `missing`; the repository already contains related work such as `LocalSpeechProvider.swift` and prior goal-aware scoring artifacts.
- Define a single shared `SpeakingStyleGoal` model and persistence path. Do not create parallel onboarding/profile goal models.
- Define `GoalStyleScore`, `GoalRewriteSuggestion`, `GoalPrescription`, and confidence semantics.
- Add analytics events: `onboarding_started`, `first_rep_started`, `first_rep_completed`, `goal_selected`, `score_viewed`, `prescription_shown`, `prescription_accepted`, `review_opened`, `cloud_fallback`, and `privacy_setting_changed`.
- Establish a privacy threat model for audio, transcripts, credentials, exports, and deletion.

### Likely files

`CoachingOnboardingView.swift`, `FirstRunOnboardingManager.swift`, session models/store, `ContentView.swift`, `SessionHistoryView.swift`, `ProfileView.swift`, and the existing analytics abstraction.

### Acceptance criteria

- One canonical goal value is available from onboarding, session analysis, review, profile, and prescription code.
- Existing sessions and users without a goal remain readable and receive a low-confidence/default state.
- Events include permission state, provider, locale, and experiment variant without recording raw audio or transcript content.

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
  separate first-value, structured-value, and paired structured-to-live reads.

### Acceptance criteria

- Fresh install can receive useful first value without an authentication screen,
  microphone permission, cloud processing, or a spoken session.
- The deterministic UI test reaches the structure-only result in under 60 seconds;
  signed-device elapsed-time distribution remains release evidence.
- Denied permissions never create a dead end.
- A coherent first-value receipt prevents the fast lane repeating after relaunch;
  incomplete profile setup remains quietly resumable from Home.

### Experiment

Compare current onboarding with fast lane only after experiment assignment and
population analytics receive an explicit privacy/product decision. Keep
time-to-first-value and first-value completion separate from time-to-first-spoken-
rep and spoken-rep completion; also measure paired structured-to-live upgrade and
D1/D7 retention by permission state.

## 5. Phase 2 — Goal-style scoring engine

### Scope

Implement transcript-derived, deterministic scoring for the initial goals: `authoritative`, `concise`, `humorous`, `warm`, and `calm`. Scores should explain their contributing dimensions and confidence rather than present unsupported precision.

### Implementation

- Add `GoalStyle.swift` and `GoalStyleScoringEngine.swift`.
- Define transcript signals using existing metrics first: filler burden, hedging, sentence length, repetition, pacing, structure, and lexical cues.
- Return `GoalStyleScore(total, dimensions, confidence, nextAction)`.
- Add score cards to session detail and profile, reusing the existing “How you come across” evidence-gated language.

### Acceptance criteria

- Fixed transcript input produces the same score across runs.
- Missing/short transcript returns a low-confidence result instead of failing.
- A concise answer scores higher on concision than a rambling equivalent; tests cover false-positive safeguards for humor and authority.
- Scores are labelled as coaching estimates, not objective personality labels.

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
- High filler burden maps to filler-focused practice; pacing issues map to pace training; interpersonal-pressure goals can map to roleplay.
- Locked or unavailable modes fall back gracefully.
- Rewrite suggestions preserve semantic intent and phrase-bank data survives relaunch.

### Experiment

Compare generic review with goal score + prescription. Measure review-open rate, prescription acceptance, next-rep conversion, and 28-day goal-score slope.

## 7. Phase 4 — Trust, privacy, and reliability

### Offline/local processing

- Reconcile the existing `LocalSpeechProvider.swift` with the provider abstraction before adding another implementation.
- Add or complete a `TranscriptionProviderSelector` that prefers cloud only when permitted and available, otherwise falls back locally for practice.
- Persist the user’s cloud-transcription preference and show a non-blocking provider status message.
- Handle missing credentials, network loss, unsupported locale, and provider startup timeout without losing the session.

### Privacy centre

- Add `PrivacyCentreView.swift` and `PrivacyPreferencesStore.swift`.
- Surface cloud transcription on/off, data export, account deletion entry point, and a plain-language data summary.
- Reuse `AccountDataExportService` and existing Firestore/account rules.
- Remove any production dependency on long-lived client-embedded AWS credentials; use temporary credentials or a server-mediated flow.

### Acceptance criteria

- Practice works without AWS credentials and with cloud processing disabled.
- Toggling cloud mode changes runtime provider selection and persists across relaunch.
- Export and deletion entry points are reachable and accurately describe exclusions/retention.
- Privacy copy is reviewed against the actual provider and storage behavior.

## 8. Phase 5 — Retention and expansion

Only begin after activation and the core loop are validated.

- Weekly goal dashboard and one micro-goal per week.
- Streaks/notifications tied to the selected speaking goal, not generic activity.
- Expand language coverage and locale-specific filler heuristics beyond the verified en-US/es-ES/fr-FR path.
- Shareable goal milestones using existing social/league infrastructure.
- Deeper humor-specific training after the general scoring model is reliable.
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

- Median time-to-first-value and first-value completion rate, reported separately
  from time-to-first-spoken-rep and spoken-rep completion.
- Structured-to-live and typed-coach-to-live upgrade rates as separate funnels.
- Practice sessions per active user per week.
- Session-review open rate and content-free shown-to-tap prescription acceptance rate.
- Goal-score improvement after 7 and 28 days.
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
