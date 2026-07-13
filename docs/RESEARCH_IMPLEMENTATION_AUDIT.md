# Research implementation completion audit

Source: `/Users/jordan/Downloads/deep-research-report (6).md`

Audit date: 2026-07-14

Committed implementation inspected through:
`936b32aaed84b737fd628cc47491896288c803f6`

The integrated implementation includes unified four-mode
availability, Train's atomic recommendation projection, Prep's stable-shape
availability fallback with category-bounded Timed prompts, the Phrase
Bank→active-week handoff, the account- and route-bound Timed prompt owner, and
explicit quarantine of superseded privacy-audit documents. Their focused and
full source/test results are recorded below and now have a clean commit-bound
source fingerprint.

Last complete source-bound evidence checkout:
`80fbf6d25cfda2b46932a0b0a1a963d156fe7b52`

The explicit-style, rendered-Home, availability, Prep/Train, weekly-phrase,
Timed-prompt, and privacy-document changes after that evidence checkout now have
a complete current-working-tree regression: all 3,924 `NoumTests` tests across
406 suites passed with zero failures, and an unsigned Release simulator build
succeeded. The canonical coach-evidence refresh from that clean source boundary
also passes app-path, real-pipeline, and trace-quality gates. The current four-mode
availability contract is **Proved** at its pure/source boundary; that does not
prove rendered SwiftUI behavior or the report's wider destination catalog.

Integrated branch: `ux-overhaul`

## Scope

This audit checks every explicit roadmap recommendation, expected output, named
acceptance test, KPI, and experiment in the report against the current source,
tests, and evidence gates. It does not treat a similarly named screen or a green
simulator test as production proof.

## Product goal

The work serves M14's operational launch gate and the VISION move from a library
of modes toward one believable communication-improvement loop. It principally
supports personalized coaching, visible progress, real-world transfer, and
trust. The report's direction is aligned with that goal; its literal suggested
implementations are not all the product contract Noum now ships.

## Existing patterns being reused

- `CoachingProfileStore` and `CoachingProfileDraft` own goal and onboarding
  state.
- `PracticeSessionStore`, `SessionFinalizer`, and `FirstValueReceipt` distinguish
  spoken reps from structured first value.
- `GoalRubricStore`, `GoalOutcomeRead`, and `CoachReasoningPass` own the public
  goal-outcome loop.
- `NextActionEngine`, `RecommendationLearningStore`, and existing routers own
  prescription and response learning.
- `AISettingsManager`, `AccountDataRegistry`, export/deletion services, and
  `AuthManager` own privacy and account state.
- `FlowEventLog`, `TransformationKPIReport`, and the versioned experiment
  contracts own bounded, account-local observability.
- Coach-arena and release-evidence tooling own the separation between local
  implementation evidence and externally earned launch evidence.

## Root causes

The report mixes five different things: product direction, literal feature
prompts, acceptance tests, measurement contracts, and production-effectiveness
claims. The repository has also moved since the report's scan. Several report
premises are stale, and several requested contracts were deliberately narrowed
to preserve trust: qualitative rather than public 0–100 identity scoring,
structured first value rather than relabelling typing as a rep, one provider per
audio stream, and extension of existing owners rather than parallel stores.

## Risks

- Calling product substrate “complete” would overstate calibration, retention,
  causal impact, accessibility, device, and production evidence.
- Treating every literal mismatch as a defect would undo trust-preserving
  choices and duplicate state owners.
- The committed canonical app-path baseline is local fixture/target-shape
  evidence only and can become stale if later integration changes coach source.
- Apple signing, TestFlight, security-incident closure, protected social
  migration, and external studies cannot be completed by local code changes.

## Plan

This document records literal report coverage, the safer shipped alternatives,
acceptance-test evidence, KPI/experiment boundaries, and the current release
prerequisites. The integration pass also hardened the existing evidence and
preflight workflows; it did not add a parallel product model, screen, store, or
route, and it made no production mutation.

## Classification key

Only these classifications are used:

- **Proved** — the literal local behavior is present and backed by direct source
  plus an executable test or successful current-checkout command.
- **Contradicted** — the current contract intentionally or observably differs
  from the literal report requirement.
- **Incomplete** — useful substrate exists, but one or more required outputs,
  destinations, states, or checks are absent.
- **Weak evidence** — source or simulator evidence exists, but the report's
  device, population, live-provider, or production claim is not earned.
- **Missing** — neither the literal behavior nor valid evidence was found.

“Proved” in this audit means proved locally at the stated boundary. It never
means production-ready, effective for real users, or equivalent to a human
coach.

## Executive verdict

| Audit surface | Classification | Verdict |
|---|---|---|
| Goal-attainment product direction | **Proved** | When the user explicitly selects a style, current goal rubrics, goal-aware review, adaptive next action, progress surfaces, and weekly/real-world context form real connective tissue across existing modes. Without that provenance the style layer stays neutral. |
| Literal six-feature prompt bundle | **Incomplete** | Large parts exist, but public numeric style scoring, humorous/calm goals, a true under-60-second spoken rep, the requested full prescription destination set, mid-stream provider failover, and a single unified privacy centre do not. |
| Report acceptance-test contract | **Incomplete** | Many equivalent safety and persistence tests pass; several literal examples are absent or contradicted by the safer current contract. |
| KPI instrumentation | **Incomplete** | Account-local event derivation is strong. Population rates, medians, cohorts, experiment inference, and a numeric goal-score slope are not implemented. |
| Experiment infrastructure | **Incomplete** | Assignment, eligibility, exposure, and bounded attribution contracts exist. There is no approved allocation or population result, and Test B's shipping treatment is qualitative rather than numeric. |
| Production effectiveness and coach parity | **Missing** | No valid professional calibration, longitudinal real-user outcome artifact, or experiment result exists. |
| Launch evidence | **Missing** | The gate is NO-GO at 18/100. None of five required external artifacts currently passes. |

## Report observations that changed underneath the recommendations

| Report observation | Classification | Current evidence |
|---|---|---|
| Noum has a broad five-tab product with drills, roleplay/IM, lessons, path, projects, social, review, and coaching surfaces | **Proved** | `AppShellView`, `AppDestination`, the mode catalog, Review/Profile/Path/Projects/Lessons, and social routes remain present. The report was right that inventory breadth can obscure the next action. |
| The verified Release route is AWS/cloud-only and uses direct app credential injection | **Contradicted** | Release now requests short-lived Deepgram access through the authenticated, App Check-enforced Firebase callable and can stay local. The historical unauthenticated AWS/credential incident remains open, so the stale implementation premise does not remove the security blocker. |
| There is no local/offline transcription fallback | **Contradicted** | `LocalSpeechProvider` requires Apple on-device recognition; Release consent-off selects it without constructing cloud, and the automatic route can fall back locally before streaming starts. |
| There is style intake but no closed goal loop | **Contradicted** | An explicit `chosenStyleGoal` can feed qualitative rubrics, Summary/Review/Profile outcome reads, rewrite eligibility, coach context, next-action reasoning, weekly copy, and milestone sharing. A missing legacy key fails closed to no chosen style; `speakingStyleGoal` is compatibility storage, not consent. What remains absent is the report's public per-session 0–100 identity score. |
| Review does not translate into an exact next action | **Contradicted** | `SessionFinalizer` and `NextActionEngine` finalize one primary recommendation for the active Summary, and `SummaryPrescriptionProjection` renders/routes that decision. The report's wider destination inventory is still incomplete; Noum does not maintain a second device-global prescription snapshot. |
| Privacy controls need to be created from scratch | **Contradicted** | Settings already exposes cloud consent, processor disclosure, Your Data, export, signed-in deletion, notifications, and policy links through existing owners. The information architecture is distributed rather than a new parallel centre/store. |
| Accessibility identifiers and reduced-motion handling exist | **Proved** | Source and tests contain both contracts. Their behavior across the large custom-card surface on physical devices remains weak evidence until TestFlight QA. |

## Recommended target-state flow

| Report transition | Classification | Current boundary |
|---|---|---|
| Choose communication goal → baseline rep | **Proved** | Explicit canonical style selection persists as `chosenStyleGoal` through the established profile owner and is available to spoken session finalization. Legacy profiles without that key remain readable but neutral. |
| Baseline rep → goal scorecard | **Contradicted** | Noum shows an evidence-bounded qualitative goal read, not the proposed numeric identity scorecard. |
| Goal read → auto-prescribed drill | **Incomplete** | The chosen goal and goal movement inform coach reasoning, while `NextActionEngine` owns the action. It does not consume the report's nonexistent numeric dimension breakdown or reach every proposed destination. |
| Prescribed drill → rep review → rewritten example | **Proved** | Existing routing, Review, evidence-gated rewrite, comparison, and Phrase Bank create this local loop for supported goals and evidence. |
| Rewrite → next micro-goal → weekly progress | **Proved** | A saved phrase can seed Timed immediately or be explicitly attached by ID to the active week of the existing four-week `ForwardPlan`, which remains the focus/mode/target/rationale/progress owner. The write is plan-ID bound, deleted/unsafe links fail closed, and Home resolves the current-week phrase into the existing transient Timed handoff. The focused iPhone 17 Pro simulator test now renders the assigned Home action, launches Timed, and asserts the exact saved line. Account binding and exact-once consumption remain separately proved by pure handoff contracts; physical-device persistence remains QA. No second weekly or phrase-text owner was added. |

## Recommendation and deliverable matrix

### 1. Goal-style scoring

| Report requirement or output | Classification | Current implementation and exact gap |
|---|---|---|
| Reuse onboarding/profile goal ownership | **Proved** | Optional `chosenStyleGoal` stays in `CoachingProfileStore`/draft and is the only style value projected into behavioral coaching. `speakingStyleGoal` remains compatibility storage; no parallel goal store was added. |
| Preserve explicit choice provenance | **Proved** | Profiles that predate the `chosenStyleGoal` key decode with no chosen style instead of inferring consent from a historical default. Goal rubrics, scoring/copy enrichments, AI/cache inputs, plans, proofs, and post-rep notes fail closed or filter incompatible provenance. |
| Support `authoritative`, `concise`, `humorous`, `warm`, and `calm` | **Incomplete** | Canonical goals are authoritative, warm, concise, persuasive, executive, and storytelling. Humorous and calm are deliberately absent; tests pin that absence. |
| Compute a public 0–100 style score for every session | **Contradicted** | The product deliberately exposes `GoalOutcomeRead` as qualitative evidence/movement. `GoalStyleCalibrationCandidate` can produce a versioned 0–100 candidate only for access-controlled professional calibration and is explicitly disconnected from product views, stores, analytics, sessions, and export. |
| Work from transcript text alone | **Missing** | No public score contract accepts a raw transcript as its complete input. The calibration engine accepts a `CoachAssessment` plus evidence references, and unsupported locales fail closed. |
| Include total, dimensions, confidence, and next action in a `GoalStyleScore` model | **Incomplete** | The calibration candidate contains total, dimensions, confidence, missing evidence, and formula fingerprint. The public qualitative read and existing `NextAction` stay separate by design; there is no product `GoalStyleScore`. |
| Persist the score with session insight state | **Missing** | Calibration candidates are intentionally not session state. Public goal outcome evidence is derived through established owners. |
| Show numeric score cards in session detail and Profile | **Missing** | Summary, Review, and Profile show qualitative goal movement/evidence; no numeric goal-style card is product-authorized. |

### 2. Goal-aware review and rewrite

| Report requirement or output | Classification | Current implementation and exact gap |
|---|---|---|
| “Make me more X” review tied to the chosen goal | **Proved** | `AIRewriteService` consumes the canonical chosen voice and weakness context; `RewriteSuggestionCard` is gated by evidence, locale, length, ambiguity, and identifier safety. |
| “More/less” slider control | **Contradicted** | The shipped control is a discrete light/medium/strong segmented choice. There is no continuous more/less slider, avoiding false precision. |
| Generate light, medium, and strong variants | **Contradicted** | All three intensities exist and can be generated deterministically, but the restrained card generates and displays the selected intensity sequentially rather than producing three simultaneous suggestions. That is a deliberate readability choice, not literal delivery of the report's three-at-once output. Humorous rewriting remains withheld because that goal is unsupported. |
| Preserve meaning and sensitive entities | **Proved** | `AIRewriteSemanticGuardTests` cover anchors, negation, numbers, currency, percentages, names, entities, contractions, and scope; unsafe edits are withheld. |
| Compare original and suggestion | **Proved** | The card exposes original/suggestion comparison without mutating the source session. |
| Save and restore a reusable phrase-bank entry | **Proved** | `PhraseBankStore` is account-scoped, bounded, deduplicated, identifier-resistant, export/deletion-owned, and can seed Timed through transient `PhrasePracticeIntent`. Prompt text then stays in the process-local `TimedPracticePromptHandoff`; only an opaque route token enters navigation. |
| Reusable suggestion model and review card | **Proved** | The shipped types have different names from the prompt but provide the requested model/card responsibilities through existing AI rewrite abstractions. |
| Offline heuristic fallback | **Proved** | Provider failure uses the conservative deterministic on-device rewrite; unsupported locales stop before English heuristics. |
| Hide suggestions for a too-short transcript | **Proved** | Eligibility returns `.tooShort` below the bounded input floor and the UI withholds the card. |

### 3. Adaptive drill prescription

| Report requirement or output | Classification | Current implementation and exact gap |
|---|---|---|
| Goal plus latest breakdown drives one best next rep | **Proved** | `SessionFinalizer` calls the established `NextActionEngine` using current evidence, baseline/trends, history, pressure profile, and style-goal alignment. Summary renders exactly the finalized primary action. |
| Up to two alternatives | **Incomplete** | `NextAction` can hold one optional secondary, but `SummaryPrescriptionProjection` deliberately renders only the primary. There is no two-alternative product card. |
| Route across Timed, Sudden Death, Ah Counter, Cut the Crutch, pace, roleplay, Lessons, Projects, and Path | **Incomplete** | The engine can return existing mini-drills and the four `PracticeMode` values (Timed, Sudden Death, Ah Counter, IM conversation). Separate Roleplay curriculum, Lessons, Speech Projects, and Path are not prescription destinations. |
| Short coach-voice rationale | **Proved** | Action reason, wider evidence, and confidence are kept distinct and duplicate copy is suppressed. |
| Home/Train card and deep link | **Incomplete** | Summary renders and deep-links the finalizer-owned action. Source inspection shows Home and Train consume the shared availability projection; focused unit tests prove projection values, exposure fingerprints, setup/destination, and launch acceptance/fallback semantics. They do not mount either SwiftUI view or execute the real `recordShown`/`markTapped` calls. Home owns its visible exposure; the phantom `ContentView` path and unread global snapshot were removed. This row remains incomplete because the report's wider destination catalog and a rendered end-to-end card/deep-link contract are absent. |
| Availability/locked-mode fallback | **Proved** | Summary, Home, Train, Prep, both Ask Noum recommendation paths, and the defensive router consume the shared rating/IM availability contract. Pure tests cover coherent projection values, suppressed stale setup/evidence/confidence, retained established IM focus/target, safe tap-time loss, and no false acceptance. Prep-specific tests preserve the planned rehearsal identity, render honest Timed fallback copy/setup, withhold false readiness credit, prevent a fallback from upgrading at tap, and route unavailable pressure/audience shapes with a category-bounded prompt containing neither the moment title nor transcript. This is source/pure-projection proof, not rendered UI or the report's wider destination catalog. |

### 4. Fast-lane first session

| Report requirement or output | Classification | Current implementation and exact gap |
|---|---|---|
| Ask only one goal and one context | **Proved** | Fast lane collects a bounded communication context and challenge, then opens a permissionless structured rehearsal. |
| Initial rep in under 60 seconds | **Contradicted** | The timed UI contract proves a structured first-value result under the target, not a spoken `PracticeSession`. Code and tests explicitly prevent that receipt from counting as a rep, speech evidence, progress, or reward. |
| Do not require live voice permissions | **Proved** | The structured path requests no microphone or speech permission and explains the spoken upgrade. |
| No auth dependency | **Contradicted** | No login credential or network round-trip is required, but `FirstRunOnboardingGate` waits for a durable guest/account identity before routing. The product does not create anonymous unowned persistence. |
| Deferred, resumable full-profile capture | **Proved** | `CoachingProfileDraft` and `FirstRunOnboardingGate` preserve the structured receipt and resume the established onboarding/consent/spoken path. |
| First-rep completion marker | **Contradicted** | `FirstValueReceipt` distinguishes `.structuredText` from `.spokenTimed`; only a persisted session counts as the first spoken rep. The fast lane writes a first-value marker. |
| Returning users skip fast lane | **Proved** | A completed profile remains the sole completion truth, and account-scoped gate/receipt tests cover reload and reset behavior. |

### 5. Offline transcription fallback

| Report requirement or output | Classification | Current implementation and exact gap |
|---|---|---|
| Local `TranscriptionProvider` | **Proved** | `LocalSpeechProvider` uses `SFSpeechRecognizer`, forces `requiresOnDeviceRecognition`, and fails rather than silently using Apple's server recognizer. |
| Cloud/privacy selection policy | **Proved** | Release consent-off constructs only local. Consent-on constructs bounded Deepgram-to-local automatic startup routing. DEBUG provider selection remains separate from the Release policy. |
| Persisted cloud-disabled choice | **Proved** | The existing `AISettingsManager` consent owner persists the choice and production construction tests prove no cloud route when it is off. |
| Automatically fall back for missing credentials/network/cloud | **Incomplete** | Setup failure can fall back before audio begins. Once either provider starts, a mid-rep failure stops honestly and offers retry; audio is never replayed to a second provider. The report's broad runtime failover promise is intentionally narrower. |
| Graceful failover banner | **Proved** | Requested-cloud/resolved-local startup produces one content-free, accessibility-labelled notice. Deliberate local use and successful cloud stay quiet. |
| Helpful unsupported-locale state | **Weak evidence** | `LocalSpeechProviderTests` proves the device/locale-specific `LocalSpeechError` passes through the production recording-error mapper for both startup and interruption while arbitrary provider detail stays collapsed. Real `SFSpeechRecognizer` locale availability and rendered presentation still require physical-device/TestFlight evidence. |

### 6. Privacy and consent centre

| Report requirement or output | Classification | Current implementation and exact gap |
|---|---|---|
| Explain what leaves the device, stays local, and is excluded from export | **Proved** | Settings privacy disclosure and `YourDataView` describe cloud/on-device routing, processors, export ownership, Keychain/Photos/provider exclusions, and cleanup. |
| Cloud transcription on/off | **Proved** | The existing consent control changes Release provider construction and revocation behavior. |
| Export ZIP entry point | **Proved** | `AccountDataExportServiceTests` validate manifest/data entries, exclusions, CRC-readable ZIP output, safe paths, and cleanup. |
| Account deletion entry point | **Proved** | The account card shows deletion only when signed in, requires typed confirmation, and routes through the existing callable contract. |
| Notifications/privacy summary | **Proved** | Both are present in Settings, using existing notification and consent owners. |
| Transient Timed prompt isolation | **Proved** | `TimedPracticePromptHandoff` keeps one bounded prompt in process, binds it to the active account and exact opaque route token, consumes it once, and clears it during account teardown. A mismatched token cannot steal a newer prompt; navigation carries no user text/account ID, and the former unscoped prompt/word defaults keys are purged rather than migrated. App termination naturally drops the in-memory value. |
| A single `PrivacyCentreView` | **Contradicted** | The user-facing trust story deliberately stays within the established Settings privacy card, Your Data, Account, and Notifications owners. A new named centre would duplicate navigation and state ownership without adding a missing control. |
| A new `PrivacyPreferencesStore` | **Contradicted** | Creating it would duplicate `AISettingsManager`, notification state, auth/account state, and export/deletion ownership. The architecture correctly extends the existing owners. |
| Copy verified against live production behavior | **Weak evidence** | Code and processor-manifest contracts align locally. Superseded audit/remediation/execution documents are explicitly marked historical and source-guarded so they cannot masquerade as current operations. The narrow hosted probe still proves only reachability—not an exact manifest-v3 body match, production processor behavior, App Store privacy disclosures, or a signed build. |

### 7. Remaining roadmap opportunities

| Opportunity | Classification | Current implementation and exact gap |
|---|---|---|
| Multi-language expansion beyond en-US/es-ES/fr-FR | **Missing** | UI/provider locale plumbing covers those locales, while AI rewrite and goal calibration fail closed outside their supported English contract. No calibrated new locale corpus exists. |
| Weekly habit/streak coaching organised around one speaking goal | **Proved** | The persisted `ForwardPlan` provides four weekly focuses, modes, targets, rationales, and derived progress alongside streak protection and check-ins. Weekly digest copy is goal-specific only when `chosenStyleGoal` is present and otherwise stays generic. A saved rewrite can be explicitly attached by ID to the active week and launched from Home through the account- and route-bound Timed handoff without duplicating phrase text or weekly state. Real cohort effect remains unproved. |
| Progress sharing for goal milestones | **Proved** | Established qualitative outcomes can offer opt-in, transcript-free, evidence-bounded milestone notes. Real-user desirability and sharing behavior remain unproved. |
| Deeper humour-specific training | **Missing** | There is no humorous identity, rubric, rewrite, scoring, or calibrated training track. |

## Literal acceptance-test audit

Passing a nearby test is not counted as the report's test when its semantics are
different.

| ID | Report test | Classification | Evidence or gap |
|---|---|---|---|
| GS-1 | Clearly concise answer scores higher than a rambling answer | **Missing** | No raw-transcript, product 0–100 comparison test exists. Current tests score assessment evidence for calibration, not two answer strings. |
| GS-2 | Onboarding-selected goal persists | **Proved** | Profile/account persistence and goal resolution tests cover explicit canonical choices and account boundaries; legacy payloads without the provenance key decode to no chosen style rather than an inferred default. |
| GS-3 | Unsupported or missing transcript returns low confidence without crashing | **Contradicted** | Missing dimensions produce bounded insufficiency/no synthetic score; unsupported locales throw/fail closed before candidate creation rather than return a low-confidence product score. |
| GS-4 | Fixed transcript input is deterministic | **Incomplete** | Calibration output and fingerprint are deterministic for fixed assessment evidence, but there is no transcript-only scoring entry point. |
| RW-1 | Suggestions preserve semantic intent | **Proved** | Semantic-guard suites cover anchors, entities, negation, quantities, and unsafe change rejection across all intensities. |
| RW-2 | Phrase Bank saves and restores | **Proved** | Account-scoped round-trip, dedupe, cap, identifier rejection, and practice-intent tests pass. Active-week projection contracts additionally cover immutable plan updates, legacy decoding, exact entry resolution, deletion cleanup, missing/unsafe fail-closed behavior, and a content-free route token for the transient prompt. A rendered simulator run proves the active-week Home action reaches Timed with the exact saved line; physical-device account persistence remains QA. |
| RW-3 | Feature works offline with heuristic templates | **Proved** | Deterministic on-device fallback and vocabulary-bounded rewrite tests pass. |
| RW-4 | Too-short transcript shows no suggestion | **Proved** | Eligibility and withheld-card behavior are directly tested. |
| PR-1 | High filler burden chooses Ah Counter or Sudden Death | **Incomplete** | Severe filler evidence does trigger one corrective action, commonly a focused filler drill, but there is no literal destination assertion restricting it to those two modes. |
| PR-2 | Pacing issues choose pace training | **Incomplete** | Pace-focused drill inventory and next-action inputs exist, but the selected report-specific routing assertion is absent. |
| PR-3 | Interpersonal-pressure goals bias toward Roleplay | **Missing** | The established engine can route IM conversation, not the separate Roleplay curriculum requested by the report. |
| PR-4 | Locked modes fall back gracefully | **Proved** | The shared four-mode matrix covers locked-at-render and capability-lost-at-tap paths without stale setup/copy/confidence or false acceptance. Prep adds stable planned-shape identity, honest fallback copy/setup, no false readiness credit, no capability-return upgrade, and a route-bound, category-only prompt for unavailable pressure/audience shapes. A matrix for the report's broader destination catalog still does not exist and remains captured by the separate incomplete routing row. |
| FL-1 | Fresh install reaches a first rep without auth | **Contradicted** | It reaches structured first value without login credentials, after durable guest identity. It does not claim that typing is a rep. |
| FL-2 | Denied microphone does not dead-end | **Proved** | The written rehearsal path is permissionless, and upgrade routing is separately tested. |
| FL-3 | Completed first rep resumes full onboarding later | **Incomplete** | Structured first value resumes prefilled full onboarding and later spoken practice; the literal initial spoken-rep case is not the fast-lane contract. |
| FL-4 | Returning users do not see fast lane again | **Proved** | Completed profile precedence and account-scoped gate behavior are tested. |
| TR-1 | Missing AWS credentials still allows local practice | **Proved** | Local construction has no AWS dependency. The premise is stale because AWS is not the Release primary. |
| TR-2 | Cloud-disabled preference persists | **Proved** | Existing consent persistence and no-cloud construction tests pass. |
| TR-3 | Switching providers does not break filler detection | **Proved** | A focused provider-neutral contract passes equivalent local, Deepgram, Google, and AWS transcript updates—with deliberately different provider filler hints—through the production `handleTranscriptUpdate`/semantic-highlighting path and asserts identical transcript, count, and highlighted output. This proves between-route behavior locally; the product intentionally does not switch providers mid-audio-stream. |
| TR-4 | Unsupported locale shows a helpful message | **Weak evidence** | A focused test proves the exact device/locale-specific error reaches the production recording-UI mapper before and after recording begins, while arbitrary provider detail remains hidden. Hardware locale availability and rendered UI presentation remain unverified. |
| PC-1 | Cloud toggle changes provider selection | **Proved** | Production consent-on/off construction is directly tested. |
| PC-2 | Export creates and cleans up ZIP | **Proved** | `AccountDataExportServiceTests` verify the real temporary ZIP and its deletion. |
| PC-3 | Deletion entry point visibility follows account state | **Proved** | Focused UI tests render both branches of the existing `authManager.isSignedIn` owner: the durable local guest/account path exposes `settings.account.delete`, while explicitly signed-out Settings exposes login and no deletion control. |
| PC-4 | Privacy summary copy matches actual behavior | **Weak evidence** | Local routing/manifest contracts match the copy, and superseded privacy documents are visibly quarantined by a source test. Production processor, hosted-policy body, App Store disclosure, and signed-device behavior were not independently verified. |

## KPI audit

`TransformationKPIReport` is an account-local diagnostic read. It contains no
transcript and participates in account deletion/export. That is useful product
substrate, but it is not a cohort analytics service.

| Report KPI | Local substrate | Population/effectiveness evidence | Boundary |
|---|---|---|---|
| First-rep completion rate | **Proved** | **Missing** | Durable spoken-rep completion is distinct from structured first value; no population denominator exists. |
| Median time to first rep | **Proved** | **Missing** | Per-account elapsed time exists; no cross-user median exists. |
| Typed-to-live upgrade rate | **Proved** | **Missing** | Tap intent, first later persisted spoken rep, and elapsed upgrade time are distinct; no cohort rate exists. |
| Practice sessions per active user per week | **Proved** | **Missing** | Active days and sessions per active week are derived locally; no population aggregation exists. |
| Goal-score improvement over 7/28 days | **Contradicted** | **Missing** | The public metric is qualitative goal follow-up/movement, not numeric goal-score improvement or a causal slope. |
| Session-review open rate | **Proved** | **Missing** | Account-local eligible-session/review-open counts exist. |
| Prescriptions accepted rate | **Proved** | **Missing** | Exposure ownership sits on the rendered Summary/Home/Train surfaces, and the shared launch projection records acceptance only when the displayed mode is the mode actually launched. A tap-time operational fallback routes safely but is excluded from acceptance. No population result exists. |
| Notification opt-in after first value | **Proved** | **Missing** | Decisions before value are excluded and the local conversion signal exists. |
| D1/D7/D28 retention | **Proved** | **Missing** | Account-local active-day return anchors exist; there is no retention cohort. |
| Cloud-to-local fallback rate | **Proved** | **Missing** | Only cloud-requested routes resolved locally enter the denominator; deliberate local sessions are excluded. |
| “Did Noum help you move toward the speaker you want to be?” after at least three reps | **Proved** | **Missing** | Exact localized copy and one-shot three-rep event behavior are present and tested; no collected real-user result is staged. |

## Experiment audit

| Experiment requirement | Classification | Current evidence and boundary |
|---|---|---|
| Test A variants: current/full onboarding vs fast lane | **Proved** | `ActivationExperimentContract` uses exact versioned Remote Config tokens and freezes account-local assignment separately from actual exposure. |
| Test A excludes internal/developer, UI-test, returning, unhydrated, already-started, and draft accounts | **Proved** | Eligibility and default-unassigned behavior are directly tested. Permission/speech context is bounded and content-free. |
| Test A outcomes: time to first rep, first-session completion, D7 | **Incomplete** | Local outcome anchors exist, including the structured/spoken distinction, but no allocated population, median, rate, or D7 comparison exists. |
| Test A result | **Missing** | No approved allocation, sample, analysis, or result artifact exists. |
| Test B variants: generic review vs goal-style scoring plus adaptive prescription | **Contradicted** | The exact control/treatment contract exists, but the shipping treatment is the qualitative goal-outcome loop plus existing next action—not a public numeric goal-style score. |
| Test B exposure and next-rep conversion attribution | **Proved** | It freezes assignment, records only actually rendered exposure, excludes prior/fixture reps, and attributes the first later persisted nonfixture rep. |
| Test B permission segmentation and developer exclusion | **Proved** | Eligibility and bounded microphone/speech/locale context are directly tested. |
| Test B outcomes: next-day return, review-to-next-rep conversion, 28-day goal-improvement slope | **Incomplete** | First-later-rep attribution and local retention/qualitative movement signals exist; no numeric slope or population causal analysis exists. |
| Test B result | **Missing** | No approved allocation, externally aggregated cohort, calibrated outcome, or result artifact exists. |

## Local implementation evidence

Source binding matters here. The `40d5e903` rows remain valid historical evidence
for that named baseline. The current canonical artifact is bound to clean source
commit `80fbf6d2` and coach fingerprint `sha256:8087e26d…ca71`; focused checks
prove their narrowed contracts and the completed full regression proves the
integrated test target.

| Evidence item | Classification | Result on 2026-07-13 |
|---|---|---|
| Full integrated Swift regression for the newer source | **Proved** | The final integrated current working tree passed 3,924/3,924 `NoumTests` tests across 406 suites with zero failures. The run used the local Swift package cache, disabled automatic package resolution and code signing, and removed provider credential variables. Its unsigned Release simulator build also succeeded. |
| Selected pre-baseline Swift product/test contracts | **Proved** | At `40d5e903`, focused simulator tests passed for goal calibration/outcomes, rewrite, Phrase Bank, prescription, fast lane, local speech, privacy, KPI, and experiment contracts. They remain valid for that named source boundary, not as a substitute for the final full run. |
| Post-baseline explicit-style, weekly-copy, mode-availability, and coach-provenance contracts | **Proved** | The explicit-style trust-boundary run passed 238 tests with zero failures, the weekly digest goal-copy suite passed 4 unique tests with zero failures, and the final integrated availability run passed 69 tests across `NextActionAvailabilityTests`, `PrescriptionProjectionTests`, `SummaryLookingAheadRouterTests`, `AskNoumModeSuggestionTests`, `NextActionEngineTests`, and `HomeCoachCardVariantTests`, with zero failures or skips. The availability matrix exhausts all four modes × four capability snapshots × live IM states. The regression-repair run passed 219 tests across seven suites and the style-aware evidence boundary passed 112 tests across three suites. App-path rows carry an explicit styled, neutral, or unknown semantic expectation. Styled turns require a passed gate and typed assessment; known neutral turns require `notEvaluated` without typed assessment; unknown IDs fail closed. The 25 supplemental arena scenarios are explicitly neutral at construction, so missing fixtures cannot silently inherit neutrality. Fabricated/default voice telemetry remains rejected. The refreshed commit-bound report preserves this contract with 23 styled, 27 neutral, and zero invalid selected traces. |
| Rendered account-visibility contract | **Proved** | The focused `testSignedOutSettingsPresentsAccountOptions` and `testPermissionlessFirstValueStaysStructuredAndDefersSetupToHome` UI runs passed on the iPhone 17 Pro simulator with its normal local test-signing path. They prove the deletion entry point's rendered account-state branches, not remote deletion success. |
| Rendered active-week phrase execution | **Proved** | On 2026-07-14, `testActiveWeekPhraseLaunchesExactPromptFromHome` passed on the iPhone 17 Pro simulator and retained an attachment of the exact saved line in Timed's thinking phase. The same 19-test focused run passed `ForwardPlanPhraseHandoffTests`, `PhrasePracticeIntentTests`, and `TimedPracticePromptHandoffTests`, including account binding and exact-once consumption. This is simulator/source evidence, not physical-device, TestFlight, or longitudinal outcome evidence. |
| Coach-arena contracts at the evidence baseline | **Proved** | 119 Node contracts and the current 126-test Python runner suite pass. The canonical artifact is refreshed from `80fbf6d2` and its current coach-source fingerprint. These are local tooling and evaluation contracts, not live-provider or human-outcome proof. |
| Release-evidence workflow contracts | **Proved** | 28 tests passed. They prove fail-closed tooling, full-commit history-scan binding, the exact 14-surface/77-check TestFlight contract, and validator agreement—not that external evidence exists. The final readiness gate now revalidates the selected attachment-backed run and requires exact promotion-receipt, source-binding, and four-artifact hash continuity with the active dump. |
| Final external-evidence provenance linkage | **Proved** | Focused readiness/live-evidence tests prove complete external-looking JSON without a release run is rejected, a validated promotion-bound run can pass the linkage, and changed managed-artifact bytes fail closed. The release-workflow integration also proves that changing a registered attachment after promotion invalidates the final linkage. Missing/altered live capture provenance and non-live provider identities are rejected. The embedded live block is an operator provenance assertion, not independently signed cryptographic proof. This proves enforcement behavior only; no external evidence was collected. |
| Legacy endpoint, cloud-probe, and TestFlight preflight contracts | **Proved** | 7 status-only endpoint-probe tests, 4 no-network cloud-probe scenarios, and 31 signing/TestFlight preflight tests passed. The preflight forwards and independently requires the explicit attachment-backed run accepted by readiness. These results prove local tooling behavior only. |
| App-path dump preflight at the evidence baseline | **Proved** | The staged dump matches `80fbf6d2` and coach fingerprint `sha256:8087e26d0fdb43b51aad5aa59a79270f254c0b69162fe748b723b6bc8ff2ca71`; 53 conversations/109 turns pass the app-path floor with no source warnings. |
| Committed canonical app-path baseline | **Proved** | The refreshed canonical report generated `2026-07-13T10:20:06+00:00` embeds `80fbf6d2` / `sha256:8087e26d…ca71`, scores all 50 required fixtures at 79.76, and passes local score/coverage, real-pipeline, production-evidence, and trace-quality gates with zero local fixture failures. It is still local real-pipeline/target-shape evidence, not external provider, reviewer, longitudinal, or device proof. |
| Operational static repository wiring | **Proved** | Readiness reports 19/19 static checks, including fail-closed processor-manifest generation freshness. It explicitly does not prove deployment, hosted content, App Store review, TestFlight upload, or bug triage. |
| Production readiness | **Missing** | Gate result is NO-GO, 18/100, local target shape 85/100, maximum allowed 20/100, claim `localEvaluationSubstrateOnly`. No validated attachment-backed release run is available to the gate, and none of the external rows is earned. |

## External proof gates

| Required artifact/gate | Classification | Current authoritative result |
|---|---|---|
| Current-source live-provider transcript sweep | **Weak evidence** | One artifact is present but rejected for source commit/fingerprint mismatch, missing published atomic-capture provenance, a non-live fallback identity in one failed row, missing/malformed required long-form coverage, production-floor failure, and provider retry/refusal pressure. It is 0/1 passing. |
| Blinded professional-coach calibration | **Missing** | `coach-chat-conversation-expert-calibration-results-v2.json` is absent. The calibration-input packet is not a result. |
| Longitudinal real-user transfer outcomes | **Missing** | `coach-real-user-transfer-outcomes-v3.json` is absent. Local fixtures cannot earn this row. |
| Physical-device TestFlight QA | **Missing** | `coach-real-device-testflight-qa-v3.json` is absent. Its fail-closed contract requires exactly 14 named surfaces and 77 named checks from the same independently verified physical TestFlight build; simulator and direct development-device builds cannot count. |
| Operational launch checklist | **Missing** | `coach-operational-launch-checklist-v2.json` is absent. |
| Required sidecar set as a whole | **Missing** | 1/5 files is present and 0/5 passes the staging contract. |

## Current prerequisite and signing gaps

These are the repository's authoritative M14 preconditions as of this audit.
The audit did not attempt deployment, certificate repair, App Store mutation,
credential revocation, or production traffic.

| Prerequisite | Classification | Evidence and remaining action |
|---|---|---|
| Replacement transcription boundary in source | **Proved** | Release construction uses the authenticated Firebase/Deepgram route with local fallback. This is product substrate, not a signed-device or live-service proof. |
| Historical Deepgram/AWS incident closed | **Missing** | The runbook still requires legacy credential revocation, disabling/authenticating every legacy endpoint, and provider usage/billing audit. |
| Protected social cutover | **Missing** | Production backup/quarantine, explicit disposition, trusted server-authored evidence, migration dry run, and coordinated rules/functions deployment remain approval-gated. |
| Hosted Firebase privacy page | **Proved** | The readiness live probe passes 3/3 checks for `https://noum-d0b6f.web.app/privacy`. This proves that a Noum policy endpoint is publicly reachable; it does not prove the manifest-v3 generated body was redeployed after the latest processor change, App Store disclosure review, or the custom domain. |
| `noum.app` custom privacy domain | **Missing** | The runbook records it as parked at GoDaddy pending DNS, TLS, and policy verification. |
| Sign in with Apple entitlement in the app | **Proved** | `Noum.entitlements` contains the capability. |
| Sign in with Apple Firebase/provider configuration | **Missing** | External Apple/Firebase configuration remains unchecked in `docs/TESTFLIGHT_QA.md`. |
| Paid-team archive signing on this host | **Missing** | The fail-closed local preflight finds zero valid Apple Distribution identities and zero matching App Store profiles for the app, Widget, and Messages extension. It does not claim what exists in the Apple Developer account. |
| App Store Connect StoreKit products and metadata | **Missing** | No verified App Store Connect evidence or signed purchase/restore run exists. |
| Build/version notes and TestFlight upload | **Missing** | The pre-flight checklist remains unchecked and the operational artifact is absent. |
| Signed physical-TestFlight run | **Missing** | Required App Check, real microphone, consent/offline/reconnect, auth, deletion, notification, widget/Live Activity, accessibility, and purchase/restore evidence is absent. |

## Highest-leverage next evidence

### Safe local

The safe local source/evidence refresh and final-gate provenance hardening are
complete. Keep `40d5e903` as a named
historical baseline and `80fbf6d2` as the current canonical source boundary.
Future coach-source changes must rerun the same atomic refresh and preserve the
provenance contract: explicitly styled rows pass only with typed assessment,
declared-neutral rows remain truthfully `notEvaluated`, and unknown fixture IDs
fail closed. The gate also requires the original validated release run and
promotion receipt to remain available. Local reruns cannot raise production
readiness past the external cap by themselves.

### External or approval-gated

First contain the historical credential incident: revoke exposed credentials,
disable or authenticate legacy endpoints, and audit usage/billing. In parallel,
establish paid-team Apple/provider/StoreKit signing so an actual TestFlight
release candidate can exist. Against that exact build, collect the five
independent artifacts: current live-provider sweep, blinded professional-coach
calibration, preregistered longitudinal real-user outcomes, physical TestFlight
QA, and independently verified operational checklist. Do not create placeholder
sidecars; missing proof should remain missing.

## Release invariants

- No public 0–100 speaking-identity score until professional and longitudinal
  calibration earns a separate product/privacy decision.
- Weak or contradictory evidence remains insufficient, forming, or mixed;
  repeated evidence may strengthen intervention without becoming certainty.
- A structured first-value receipt never counts as a spoken rep or unlocks
  speech-derived evidence, progress, or rewards.
- Cloud consent off never instantiates a cloud transcription provider.
- A material processor-manifest change invalidates earlier cloud consent, and
  generated Swift, bundled-policy, and hosted-policy disclosures must remain exact.
- Provider fallback occurs before streaming; one rep's audio is never sent to
  two transcription providers.
- Recommendation response is association, not proof that a drill caused change.
- Existing profile, session, recommendation, privacy, account, and navigation
  owners remain the single sources of truth.
- A green simulator suite, local arena score, configured entitlement, or static
  preflight is not signed-device, population, production, or coach-parity proof.
