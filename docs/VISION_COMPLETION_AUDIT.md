# Vision completion audit

Audit date: 2026-07-20

Behavior source: `cdce32af90f64295fb2ce4bfd5ef905d4194f4c7`

Evidence checkout: `cdce32af90f64295fb2ce4bfd5ef905d4194f4c7`

Coach-source fingerprint: `sha256:e1c6b655edaee8759e791ed6669a567117a17a283ef283680c3278c01e49cbad`

## Verdict

Noum is not "truly done" against `docs/VISION.md`. The current branch has a
coherent, locally exercised coaching journey and closes the accepted
product-journey specification's main code paths. It does not yet earn the
vision's professional-coach-parity or production-readiness claims.

The distinction is material:

- **Implemented and locally proved:** the connected journey, voice-goal
  semantics, deterministic request terminal contract, content-free trace,
  transcript ladder, bounded memory controls, and targeted retry/adaptation
  plumbing.
- **Implemented but not validated in its intended environment:** real speech,
  live-provider behavior, physical-device lifecycle transitions,
  assistive-technology operation, purchase/signing, audio routes, and
  same-build physical-device behavior.
- **Not earnable from this repository alone:** blinded professional-coach
  calibration, longitudinal transfer outcomes, independent operational
  sign-off, and App Store/TestFlight authority.

The source-bound evaluator therefore remains **NO-GO at 20/100**. Its separate
local target-shape score is 90/100; that score is useful regression evidence,
not a launch or parity claim.

## Status vocabulary

| Status | Meaning |
| --- | --- |
| `PROVED LOCAL` | Implemented and exercised against the current behavior source in a simulator, unit test, rendered UI test, source-bound evaluator, or inspected artifact. |
| `PARTIAL` | Architecture exists, but an acceptance dimension is missing or the intended environment has not been exercised. |
| `EXTERNAL` | Requires physical hardware, production authority, independent reviewers, or longitudinal users. It must not be replaced with synthetic evidence. |
| `LATER MILESTONE` | The vision names this as post-M14 strategy or backlog; adding it now would conflict with M14's explicit no-new-features boundary. |
| `CONTRADICTED` | Current behavior conflicts with the requirement and needs a local change. |

## North star and coach-parity standard

| Vision requirement | Status | Current evidence | Remaining proof or gap |
| --- | --- | --- | --- |
| Measurably clearer communication under pressure over weeks | `EXTERNAL` | Persistent sessions, trends, case file, proof moments, and transfer reviews exist. | A preregistered longitudinal real-user programme with delayed outcomes, attrition accounting, and negative results retained. |
| Diagnosis without overclaiming thin evidence | `PROVED LOCAL` | Conservative evidence thresholds, semantic-filler protections, confidence language, source-bound fixture coverage, and zero app-path failures. | Representative real-audio and professional review remain external validation. |
| Revisable case formulation | `PARTIAL` | `CoachingProfileStore`, `CoachMemoryStore`, `ForwardPlanStore`, reflection, upcoming moments, and confirmable hypotheses form one bounded case spine. | Repeated real-user correction/confirmation over weeks; per-underlying-record provenance is not exposed because the model does not persist that granularity. |
| Reasoned intervention with observable target | `PROVED LOCAL` | Home/Train prescription, Summary diagnosis, one-step target, Phrase Bank/Timed handoff, and intervention-cycle tests. | Whether the prescription is professionally useful is covered by calibration, not local plumbing. |
| Compare attempts and adapt intervention | `PROVED LOCAL` | `TranscriptPracticeLoopTests` prove the same target reaches comparison, persists an accepted retry, and refreshes intervention on one trace; rendered Summary-to-Timed routing passes. | A same-target real-microphone retry on the source-bound TestFlight build. |
| Broad delivery perception | `PARTIAL` | Fillers, semantic use, pace, pauses, pitch range, vocal energy, composure, structure, and word choice feed conservative reads. | Calibration across devices, voices, rooms, microphones; breathing/emphasis/tension remain later work. Opt-in visual presence is explicitly a later milestone. |
| Real-world transfer | `PARTIAL` | Big Moment joins preparation, rehearsal, outcome/reflection, perceived counterpart response, and coach update. | Longitudinal outcomes across real interviews, presentations, leadership, conflict, pitches, networking, and personal conversations. |
| Professional-coach validation | `EXTERNAL` | A blinded packet and strict artifact validators exist. | Qualified independent coaches must rate representative sessions and the accepted artifact must meet its rubric floor. |

## Accepted product-journey specification

### Product journey

| Acceptance criterion | Status | Evidence and observation | Remaining gap |
| --- | --- | --- | --- |
| Home has one obvious next coaching action | `PROVED LOCAL` | Fresh Home capture shows one dominant stakeholder-review/continue-prep action; secondary Ask entry is contextual. | Physical-device/VoiceOver verification. |
| Practice normally begins from a reasoned prescription | `PROVED LOCAL` | Fresh Train capture places one recommended Timed rep above the library; existing route/state owners are reused. | Real recommendation usefulness is an outcome question. |
| Review shows one diagnosis and one target | `PROVED LOCAL` | Existing Summary diagnosis remains primary and the ladder exposes one actionable lever. | Broader physical-device matrix. |
| One-step rewrite is directly available and aspiration is secondary | `PROVED LOCAL` | `RewriteSuggestionCard` implements exact original → one step → labelled aspiration, with changed words and an accessible targeted-practice action. Unit and rendered UI tests pass. | Interactive VoiceOver and largest-text inspection for the complete ladder. |
| Targeted retry is one tap away | `PROVED LOCAL` | `GoalOutcomeLoopUITests.testTranscriptLadderPractisesOneStepRewriteFromSummary` reaches the existing Timed destination. | Same-target microphone run on device. |
| Ask Noum is contextual | `PROVED LOCAL` | Existing contextual entry retains relevant rep, voice goal, case/intervention, and upcoming-moment modules. Source-bound traces audit context/retrieval/memory/prompt. | Live-provider device run and conversational human review. |
| Progress is a coaching story | `PROVED LOCAL` | Fresh Review/Profile captures show a recent movement story, current focus, voice target, and one next action rather than a metric wall. | Longitudinal user comprehension and usefulness. |
| Redundant surfaces are removed or demoted | `PROVED LOCAL` | No new tab, route, store, or dashboard was added; existing Summary, Ask, Home, Train, Progress, Phrase Bank, and plan owners were connected. | Continue resisting post-M14 feature expansion. |

### Voice-goal quality

All listed acceptance criteria are `PROVED LOCAL`. A goal change is a change in
training emphasis, not identity; session/evidence/memory history is preserved;
memory and plan provenance advances; only the goal-dependent forward projection
is invalidated. The reliability gate blocks authenticity-shaming, "pretending",
and fake-persona language. `ProductJourneyContractTests` and the wider coach
fixture suite cover the regression.

The remaining question is external usefulness: whether goal-aware drill choice
and coaching language improve outcomes for real users. The product must not
infer that from the local tests.

### Detailed-prompt and long-chat reliability

| Acceptance criterion | Status | Evidence | Remaining gap |
| --- | --- | --- | --- |
| Deterministic terminal outcome; no indefinite loading or silent loss | `PROVED LOCAL` | Client-owned text/live deadlines and the exhaustive accepted/repaired, safe-fallback, retryable-error, cancelled, or timed-out contract. A 3,000-character turn survives account-scoped reload exactly. Cancellation/deadline tests include providers that ignore cancellation. |
| Every request has one trace ID across the full path | `PROVED LOCAL` | One opaque UUID spans request classification, memory/evidence availability, prompt, provider attempts, gates, fallback, persistence, UI commit, and terminal. Duplicate/malformed terminal events are labelled trace errors. |
| Errors are actionable and privacy-safe | `PROVED LOCAL` | Retryable notices persist; the Debug viewer shows content-free status/timings; the support bundle excludes communication content, account IDs, credentials, prompt and response text, and redacts secret markers. |
| Background/foreground and live-provider behavior | `PARTIAL` | The rendered simulator suite accepts a delayed request, backgrounds and foregrounds the app, then proves one stable terminal row, one user row, and no lingering thinking state. The complete Ask Noum UI class passes 10/10. | Source-bound live-provider and lifecycle runs on a physical TestFlight build are not yet attached. |

The support bundle intentionally replays only terminal-path structure. Exact
semantic replay would require prompt/transcript/response content and would
violate the privacy boundary. The checked-in replayer fails closed and tells an
operator to use a consented synthetic Coach Arena fixture when answer-quality
reproduction is required.

### Transcript ladder

All code-side criteria are `PROVED LOCAL`: bounded exact-original verification,
one-lever meaning/voice-preserving rewrite, distinct aspirational exemplar,
word-level explanation, one-step targeted practice, same-target comparison,
and intervention refresh. The source-bound synthetic retry corpus passes 20/20.

The honest residual is `EXTERNAL`: a synthetic typed retry cannot prove speech
capture, audio finalization, or coaching usefulness. The exact route must be
performed with real speech on the candidate build and then reviewed by a human.

### Bounded cross-session memory

| Acceptance criterion | Status | Evidence | Remaining gap |
| --- | --- | --- | --- |
| Context changes the response | `PROVED LOCAL` | Coach context and app-path traces show bounded goal, case, plan, evidence, intervention, reflection, and upcoming-moment modules affecting the response. |
| Bounded and inspectable | `PROVED LOCAL` | Existing `CoachMemoryStore` remains the owner; Your Data exposes the bounded projection and provenance categories. |
| User evidence outranks coach prose | `PROVED LOCAL` | Observed evidence is separated and cannot be rewritten through memory editing. |
| Sensitive patterns are confirmable hypotheses | `PROVED LOCAL` | Hypotheses are labelled coach interpretations and may be confirmed/rejected/removed rather than asserted as facts. |
| Goal changes preserve/invalidate correctly | `PROVED LOCAL` | Goal-change contract tests prove evidence retention and projection-only invalidation. |
| Correct and delete memory | `PROVED LOCAL` | User-stated fields are editable; projections and bounded memory can be deleted without rewriting observed evidence. |
| Per-record timestamp/source visibility | `PARTIAL` | Overall update date/confidence and category provenance are visible. | The persistence model lacks independent provenance for every underlying evidence row. Do not fabricate it in UI; evaluate a model extension after TestFlight reveals a real trust need. |

### UI, accessibility, and quality

| Requirement | Status | Evidence | Remaining gap |
| --- | --- | --- | --- |
| Clear hierarchy; no wall of cards | `PROVED LOCAL` | Fresh 1206×2622 Home, Train, Review, Profile, Settings, and contextual Ask captures were visually inspected after the contrast and tab-clearance pass; the Debug viewer has its own earlier inspected capture. | Longitudinal comprehension and usefulness remain user/outcome questions. |
| Snapshot evidence for key states | `PROVED LOCAL` | `.screenshots/2026-07-20_accessibility-journey-final/HANDOFF.md` records the source-bound five-root plus contextual-Ask sweep; `.screenshots/2026-07-20_trace-support-bundle/HANDOFF.md` records the expanded Debug state. The PNGs remain local evidence by design. | Light mode does not emit dedicated PNGs for the scrolled ladder or Debug state on every run; the rendered UI gate owns those states. |
| Largest Dynamic Type | `PROVED LOCAL` | Fifteen high-risk journey interactions pass at Accessibility XXXL. Eight native rendered audits cover Home, Train, Review, Progress, the scrolled Progress story, Settings, contextual Ask, and the transcript ladder; one focused test verifies Debug trace actions; three companion unit tests resolve the exact production color tokens/surfaces. All 12 checks pass in one result bundle. | The complete 14-surface physical matrix and interactive assistive-technology operation remain external device QA. |
| VoiceOver | `PARTIAL` | Important actions expose labels/traits/identifiers and rendered accessibility-tree assertions exist. | Interactive focus order, announcements, rotor behavior, and task completion require a device/operator. |
| Reduce Motion | `PARTIAL` | Core practice/live/social/celebration surfaces read `accessibilityReduceMotion` and disable/reduce repeated animation. | Same-build interactive inspection across the required surface matrix. |
| Dark appearance | `PARTIAL` | The app root deliberately forces light appearance; a dark-system launch was inspected and remained legible in the supported light presentation. | Decide whether light-only is the shipped product boundary or implement and verify full dark mode after M14. Do not claim dark-mode support today. |
| No placeholders, scaffolds, fabricated quotes, or raw metadata | `PROVED LOCAL` | Current 50-fixture report passes with zero placeholder leaks/failures; exact-quote and generated-read gates are covered. |
| Human-readable material improvement | `PARTIAL` | The 20-scenario corpus and report were inspected, not merely scored. | Professional calibration and longitudinal users determine material coaching improvement. |

## M14 definition of done

| M14 gate | Status | Exact boundary |
| --- | --- | --- |
| Guarded social cutover | `EXTERNAL` | Source locks and runbooks exist; production backup/quarantine, migration, trusted producer, coordinated deploy, readback, and two-device smoke require an authorized operator. The social surface correctly remains unavailable. |
| Hosted policy and custom domain | `PARTIAL` | The Firebase-hosted privacy page exists and disclosure generation is source controlled. `noum.app` DNS/TLS/body-match proof is absent. |
| Historical credential/session closure | `PARTIAL` | The known Deepgram/Google incident is documented as contained. Firebase CLI session revocation and residual AWS account inventory need owner-produced, independently reviewed evidence. |
| Source-bound physical TestFlight 14-surface/77-check | `EXTERNAL` | Simulator builds/tests are not a signed archive or processed TestFlight build. Paid-team signing, upload, physical install, and exact checklist are absent. |
| Current-source live-provider sweep | `EXTERNAL` | Local deterministic provider traces are complete; a `--probe-live` artifact for this candidate is absent. |
| Blinded professional review | `EXTERNAL` | Packet/validator exists; qualified independent ratings are absent. |
| Longitudinal real-user transfer | `EXTERNAL` | Schema/validator and product loop exist; consented delayed outcomes are absent. |
| Operational launch sign-off | `EXTERNAL` | The 12-row checklist validator exists; independently verified operational evidence is absent. |

## Ranked remaining work

### Now: local release hardening

1. Keep the complete serialized unit target and Release simulator build green
   after every behavior change; bind reports to the exact behavior source.
2. Complete locally automatable accessibility-size and supported-appearance
   sweeps for the high-risk journey states, while reserving interactive
   VoiceOver/Reduce Motion claims for physical QA.
3. Keep QA documentation source-bound so superseded failures cannot be
   mistaken for the candidate state.

### Next: authorized release operations

Follow `docs/MANUAL_LAUNCH_ACTIONS.md` in order. The first action is revoking the
two historical Firebase CLI sessions, reauthenticating the intended account,
and obtaining independent verification. Do not perform a broad Firebase deploy
or social cutover from an untrusted session.

### After a stable TestFlight build

Run the longitudinal and professional validation programme, then use its real
failures to deepen case formulation, delivery sensing, transfer, and progress.
Presence coaching, broader inference, and optional feature expansion remain
`LATER MILESTONE`; implementing them now would violate the active milestone's
explicit instruction to stop adding features and start shipping.

## Evidence inventory

- Canonical app-path report: `tools/coach-arena/reports/app-path/latest.json`
  generated 2026-07-20T15:15:04Z; 53 conversations / 109 turns, 50 fixtures,
  81.16 average, zero failures, 50 complete traces, source freshness passed.
- Canonical dump: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`.
- Product journey suite: 13/13 within the complete serialized unit result.
- Complete serialized unit target: 4,549/4,549 passed with zero failures or
  skips in `/private/tmp/noum-vision-full-unit-final-pass2.xcresult`.
- Complete serialized UI target: 79/79 passed with zero failures or skips in
  `/private/tmp/noum-vision-full-ui-final-pass2.xcresult`. This includes the
  full screenshot tours and the four paths that failed the first broad soak:
  active-week phrase execution, both in-chat goal-confirmation variants, and
  the transcript-ladder native accessibility audit under sustained load.
- Accessibility XXXL and request regression matrix: 25/25 passed in
  `/private/tmp/noum-vision-journey-chat-regression-final.xcresult`; this is 15
  high-risk journey/failure interactions plus all 10 Ask Noum reliability flows,
  including one delayed accepted request across background/foreground.
- Expanded accessibility gate: 12/12 passed in
  `/private/tmp/noum-vision-core-a11y-final-pass4.xcresult`; this comprises eight
  native rendered state audits, the focused Debug action state, and three
  production color-token/surface tests.
- Rendered trace support flow: 1/1 in
  `/private/tmp/noum-trace-support-focus.xcresult`.
- Coach Arena: 167/167 Python and 118/118 Node tests passed, with one intentional
  Node skip.
- Transcript retry corpus: 20/20.
- Current screenshot handoffs:
  `.screenshots/2026-07-20_accessibility-journey-final/HANDOFF.md`,
  `.screenshots/2026-07-20_accessibility-journey-hardening/HANDOFF.md` and
  `.screenshots/2026-07-20_trace-support-bundle/HANDOFF.md`.
- Current-source Release simulator app passed strict signature verification at
  `/private/tmp/noum-vision-home-a11y-fix-derived/Build/Products/Release-iphonesimulator/Noum.app`.

These artifacts prove the stated local contracts only. They do not replace any
of the five independent production artifacts.
