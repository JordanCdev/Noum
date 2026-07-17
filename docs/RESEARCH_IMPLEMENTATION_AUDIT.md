# Research implementation completion audit

Source: `/Users/jordan/Downloads/deep-research-report (6).md`

Audit date: 2026-07-17

Committed implementation inspected through `ea667cfd4`. This audit also covers
the current dirty account-deletion admission/recovery, Ask Noum failed-
acceptance repair, and bounded coaching-content journal source developed above
that baseline. Readiness has not been rerun for the dirty source.

The newest bounded slice makes deletion a durable input to scoped asynchronous
coaching work. One Keychain-backed schema-v2 record owns account/provider/
request identity and monotonic phase across relaunch; corrupt, unreadable, or
other-account state fails closed. Ask Noum replies and auxiliary provider work,
Forward Plan admission/registration/active transports, and recommendation
local/backend sync paths close and revalidate against that authority. Recovery
copy and actions are phase-derived, and an unknown remote result exposes only
opaque-reference support rather than a destructive retry.

The checked callable binds expected account identity to the verified Firebase
UID and gives the content-free completed server marker an expiry two hours
after completion. Firestore private writes are denied on marker existence until
TTL deletes it, so a cached ID token cannot recreate account data; TTL is
source-declared cleanup metadata.

The caller reports success only after exact completed-marker finalization, and
failure leaves the pending marker intact. Exact completed duplicates preserve
their original marker; mismatched or malformed state fails closed. Every 15
minutes the scheduled reconciler scans exact pending rows at least 30 minutes
old, paginates past malformed rows, and replays the same full deletion worklist
whether the Auth user exists or was already removed. Cleanup, Auth removal, and
exact marker identity are revalidated before completion; unchanged failures
stay pending and rotate through a refreshed `updatedAt`. Exact safe Apple,
recent-auth, and social-cutover preflights can clear only a current-attempt
remote-request fence. Generic failed-precondition, legacy REST, resumed, and
transport failures remain ambiguous.

The current Ask Noum audit records a failed user-acceptance boundary. The app
usually reported that coaching was unavailable; replies that did land were
rejected as repetitive, unnatural, and unlike a human expert communication
coach. Before the 2026-07-17 repair, the read-only production inventory exposed
only `coachChat`, `coachChatAvailability`, `deleteAccount`, and
`transcriptionToken`; the app's required `coachChatV2` callable was absent.
Production admission also accepted
Auth/App Check while the next five observed legacy `coachChat` generations
failed `data-loss`, so silently falling back to v1 would hide one broken
contract behind another. The earlier five-case Vertex run is a synthetic
model-boundary diagnostic, not current-source live generated quality proof.
A fresh read-only inventory on 2026-07-17 reconfirmed that same four-function
roster after the simulator displayed the backend-version banner. The attached
console excerpt contains only simulator keyboard-haptics library noise, not a
coach/Firebase error. User copy now states that the required service is not live
and that updating the app will not fix it.

That availability blocker is now repaired, but quality acceptance is not. An
explicitly authorized, source-bound scoped release from commit `86334ed45`
deployed only `coachChatV2` and `coachChatAvailability` to `noum-d0b6f` in
`europe-west2`. Both read back `ACTIVE` on Node 22 with source hash
`f5c8c1a1b509fb519a749a48b79337357cbf6634` and the dedicated
`noum-coach-runtime@noum-d0b6f.iam.gserviceaccount.com` identity. The build
required least-privilege restoration for the default build identity: source-
bucket `roles/storage.objectViewer`, regional `gcf-artifacts`
`roles/artifactregistry.writer`, and project `roles/logging.logWriter`; no
Editor/Owner role was restored. Unauthenticated probes fail closed with
401/403, and the installed simulator build clears the backend-version banner
and enables the composer. No generated message has yet been sent through that
composer, so this earns availability evidence only—not live wording quality,
reporter acceptance, professional review, rollback, or production readiness.

The first two real stream attempts subsequently failed at the Cloud Run edge,
not in coach generation: `coachchatv2` lacked `roles/run.invoker` for
`allUsers`, while `coachchatavailability` already had it. Cloud Run therefore
treated the Firebase ID token as an unverifiable Google IAM token and returned
HTTP 401 before the Functions framework could validate Firebase Auth or App
Check. The exact missing transport binding is now restored on `coachchatv2`;
in-function Auth/App Check enforcement is unchanged. A fresh unauthenticated
probe reaches the callable framework and returns the expected JSON
`UNAUTHENTICATED` response. The source-bound wrapper now idempotently restores
the binding on exactly the two reviewed Cloud Run services after Firebase
deployment. This closed the observed platform-admission defect.

An operator-confirmed retry at 21:16 UTC then completed from the installed
iPhone 17 simulator through the deployed route. Production recorded HTTP 200,
Firebase Auth `VALID`, App Check `VALID`, verified account binding, model
generation through `gemini-2.5-flash`, finish reason `STOP`, policy
`noum-coach-v2`, and a two-token visible response: `Hello.` The unavailable
banner cleared. This is one greeting-path transport proof, not a representative
conversation set or wording acceptance. The rendered row also overclaimed
`Based on your current focus and 12 recent reps` even though the conversational
lane excludes personal evidence. Current client source now persists the
existing response kind on turn metadata and shows that provenance only for
`personalEvidenceRead`; conversational, general, memory-only, and legacy rows
fail closed without it. The focused `CohesiveSummaryAskCopyTests` suite passes
4/4. Debug and Release simulator builds succeed, and a fresh iPhone 17 capture
of the persisted greeting shows neither the unavailable banner nor the false
evidence line. This UI proof does not broaden the one-turn quality claim.

The current working tree adds the normal `coachChatV2` route and one versioned
server policy. Typed personal-evidence, general-coaching, memory-handoff, and
conversational response kinds isolate prompt, history, assessment, fallback,
and reliability behavior. General and conversational replies cannot inherit
personal assessment/history. Personal prescriptions require qualified same-
dimension evidence and a latest-rep signal; a no-move brief makes zero provider
calls. A policy-rejected supported general turn may use only its short, intent-
specific deterministic repair; unsupported turns and empty or malformed output
remain typed failures rather than presenting generic copy as expert judgment.
Server repair exhaustion is now distinct from incomplete generation. The
separate schema-v1 `coachChat` implementation locally
freezes its historical policy, validation, context shape, one-generation live
deltas, errors, and exact seven-field completion. This proves only a local
semantic contract, not production v1 compatibility or rollback.

The current source replaces the legacy boolean availability echo with an exact
capability handshake for function
`coachChatV2`, request schema 2, and policy `noum-coach-v2`; the deployed
legacy `{available:true}` response now fails closed as a typed backend-version
limitation with specific copy. It also removes the text-chat double answer:
ordinary text waits for one vetted final reply, while live voice alone retains
the bounded provisional read. The personal provider projection no longer
duplicates the plan, case, assessment, prescription, and brief. The server uses
restrained visible limits (30 conversational, 45 general, 50 ordinary, 45 trust
repair, 90 explicit deep assessment, and 35 live). Its prompt and deterministic
fallback omit stored moves when the current turn does not request action. The
server gate now rejects high-confidence imperative, modal, recommendation, and
bounded indirect-action shapes on a personal explanation or judgement even when
the brief stores a continuity move. Hidden repair removes the drill; two invalid
drafts resolve to the evidence-only typed read, and the client landing gate
mirrors the bounded check. Explicit move requests, descriptive evidence,
general craft, and memory handoff remain available. This is conservative
lexical enforcement, not proof against every semantic paraphrase.
Deterministic fallback uses natural evidence-then-move sentences without forced
bridge wording. A fresh audit also found that the prior-action gate and typed
move grounding formed an impossible contract when the current brief deliberately
retained the active intervention. Server and iOS policy now canonicalize a
bounded synonym set, continue to reject exact or paraphrased drill restatement,
and accept only an evidence-led continuity reference when an action-seeking turn
has a typed move already present in recent coach history. Deterministic
exhaustion now names the current evidence and keeps the focus without reissuing
the drill; repair instructions no longer force `because` or `so`. This is local
lexical/deterministic evidence, not generated-wording acceptance. Trust repair
replays only the challenged coach answer and
the current complaint; a short elliptical general follow-up receives one
bounded prior-user referent. Cold-start evidence guards now also apply to the
general lane, preventing an invented personal metric from passing as a useful
first answer. Each attempted turn now has one service-owned remote capability
preflight; the view does not repeat it at dispatch and the Firebase stream only
revalidates local identity. Exact backend, identity, and service reasons survive
that boundary instead of collapsing to authentication or network failure.

The secure-session boundary now has one narrow source repair. A durable
`local-guest-*` fallback can automatically retry, or explicitly request, a new
anonymous Firebase UID. One copy-first, three-phase Keychain journal keeps the
source authoritative before identity commit and the target permanently
authoritative afterward. Exact account-scoped values move only after conflict
preflight; remote/derived bookkeeping, unattributed device state, and recordings
are excluded. Ask Noum refreshes on exact target hydration, and anonymous guests
cannot sign out and strand their only credential.

Firebase identity creation remains independent of content consent. The current
versioned account receipt, exact durable account/provider, hydration readiness,
transition fences, lifecycle generation, and matching Firebase UID are
revalidated before profile, XP, session/transcript/evidence, recommendation, and
REST writes. The lifecycle is captured at scheduling, REST bearer creation is
bound to the captured identity, and schema-v2 recommendation mutations require
an expected account that the callable compares with verified Auth. Consent is
encoded, persisted, and read back before publication; failed persistence closes
process-local authority so an older durable allow cannot be reused. A separate
target marker retries the initial snapshot without holding deletion or linking
behind network completion.

Ordinary profile, progression, and session work now synchronously enters one
account-scoped metadata-only journal before transport. Existing stores own the
payload; the actor resolves the exact account namespace, drains serially, and
acknowledges only the exact local revision/mutation UUID still pending. Relaunch/
hydration, foreground, and consent allow resume the journal; unreadable bytes
fail closed. Promotion snapshot work shares this lane, is restricted to the
proved-empty new target, and carries exact task ownership. Existing accounts do
not receive a blind snapshot. Bootstrap preserves dirty local profile,
progression, and session rows, replacement writes clear removed optionals, and
account deletion waits for in-flight content transport before advancing.

This proves bounded local ordering and retry, not remote convergence. Direct
documents have no server-enforced revision/CAS, mixed or older clients can
still last-write-win, and there is no startup digest repair for a crash between
payload persistence and journal enqueue. XP has no award-event provenance,
session deletion has no remote tombstone, and ordinary content still rewrites
mutable root provider metadata. Existing-account merge, complete cross-device
restoration, same-UID recovery after loss of an anonymous Firebase session, and
the Apple/Google link-success-before-Keychain crash window remain source gaps.
The audit also found that current schema-2 sessions were rejected by the source
schema-1-only Firestore rule. Source now admits schemas 1 and 2 and rejects
unknown schema 3; deployment and production readback remain unproved.

Current Ask backend evidence passes TypeScript lint/build, **161/161** Functions
tests, **7/7** deploy-lock tests, **19/19** cloud-operations validator tests,
and **9/9** Coach Arena simulator-environment checks. The tool guards reduce
accidental shared-simulator replacement but do not prove ownership or
disposability.

Current-source iOS evidence passes **124/124** typed-evidence routing,
provenance, policy, secure-wire, and pipeline tests in
`/private/tmp/NoumTypedEvidenceFinal8-20260717.xcresult` and **133/133** reply-
reliability tests in `/private/tmp/NoumReliabilityFinal3-20260717.xcresult`,
with zero failures or skips. The earlier **164/164** provider-chain and
**251/251** wider Ask selections remain broader adjacent evidence but predate
the final typed-projection and natural-stat-routing edits. These results prove
deterministic source behavior only; they do not provide an App Check-valid
deployed conversation, reporter acceptance, or an independent professional
judgment of visible wording. The earlier **30/30** Auth/Firestore/Functions
emulator suite, signed **224/224** Ask bundle, signed Debug, unsigned Release,
and visually inspected light sweep also remain historical. Only a post-edit
unsigned Debug simulator build has succeeded so far. Earlier promotion/privacy/
authority **41/41**, journal/promotion/registry **22/22**, and deletion-
admission **4/4** results remain bounded historical evidence for their
assertions.

Source inventories **18** reviewed callable exports plus one scheduled function,
**19 Functions exports total**, while the read-only production inventory
returned only the four active functions named above. Backend-first closure must
deploy and read back both `coachChatV2` and the updated
`coachChatAvailability` capability contract before a v2 app can pass admission.
That deployment, mixed v1/v2 smoke, adoption measurement, and rollback remain
unperformed. No current-source App Check-valid generated conversation, five-
case live quality acceptance, or independent professional review exists.
The latest authoritative source-bound readiness result remains the inherited
`ac664112` **NO-GO at 18/100 with 0/5 required external artifacts**, not a
fresh result for this dirty source.

The direct-evaluation routing and bounded typed-projection gaps are now closed
locally. One-rep and natural exact-stat requests select grounded personal
evidence; longitudinal requests select deep assessment; how-to and benchmark
questions remain general coaching. Latest metrics carry canonical persisted
word/WPM and qualified filler provenance. Longitudinal evidence requires two to
five unique current-schema reps with exact mode/pressure/rating/duration/demand
or setup comparability, and score is omitted unless every selected comparator
has a score. Exact and trend replies use the vetted direct brief without a model
call or drill, omit provenance IDs from prose, and are rejected on both sides if
metric kind, value, rounded direction, or visible direction wording diverges.
The rate parser no longer mistakes “fillers per minute” for a filler count.
Unsupported evidence remains restrained. The v2 callable and exact capability
handshake are now live, but an App Check-valid generated conversation and
human quality acceptance remain unproved.

For the preceding deletion slice, local evidence is green: **70/70** focused
iOS tests, **55/55** adjacent
regressions, a final frozen-source policy/recovery selection at **23/23**, and
**4,402 unique tests / 4,421 device-configuration executions** in the complete
unsigned `NoumTests` target. The final result bundle is
`/private/tmp/noum-account-deletion-full-final-20260716.xcresult`. Functions
passes **115/115** unit tests, **7/7** deploy-lock tests, **18/18** cloud-
operations validator tests, and **28/28** full Auth/Firestore/Functions
emulator tests including a stale-token 403 and direct scheduled-callback
recovery after deletion. The current-source unsigned Release simulator build
succeeds. A light five-tab simulator sweep is recorded in
`.screenshots/2026-07-16_account-deletion-fence/HANDOFF.md`; it does not
exercise deletion or recovery. No production deployment, live scheduler or
TTL evidence, durable post-Auth completion receipt, unauthenticated recovery,
or signed-device evidence exists; no required external artifact passes.
Production readiness remains **NO-GO at 18/100 with 0/5 required external
artifacts**.

The preceding bounded slice closes the Forward Plan provider-input evidence
gap. Recent filler context uses the shared historical quantity projection, so
only 20-word / 15-second, confidence-qualified, current-schema, non-fixture
samples can expose a normalized rate; every other sample is `not measured`.
Filler and pace baselines use the current-comparison accessors and fail closed
for stale or insufficient aggregates. Independent score evidence is unchanged.
The account/source/authorization lease still binds the fully hydrated loaded
account, lifecycle, latest intent, plan/session generations, exact source
input, locale, consent, and provider through transport and the final plan/Ask
compare-and-save.

Focused metric verification passes **7/7**, the combined metric and Forward
Plan regression selection passes **134/134**, and the complete unsigned target
passes **4,355 unique tests / 4,374 device-configuration executions** with zero
failures or skips. The result bundle is
`/private/tmp/noum-forward-plan-metric-full-20260716-0140.xcresult`. The
current-source unsigned Release simulator build succeeds. This is local
boundary evidence only.

Source inspection corrects the earlier reachability classification: first-plan
generation is source-reachable after three eligible reps through **Profile →
Library → Coaching evidence → Coaching direction**. It remains deeply buried,
Home suppresses `.prompt`, Ask Noum has no dedicated entry, and legitimate
fail-closed generation is not explained by the mounted stale-plan path. Account
deletion start is not yet a lease input, so pending provider work can start or
continue until local teardown, and an in-process plan/thread commit can still
occur before teardown. Successful teardown later removes account-scoped writes;
only completions after teardown fail closed. Device-global AI-call diagnostics
remain outside account reload, export, and deletion. Their reason metadata can
include interaction/coaching-gate details;
the optional `NOUM_LIVE_AI_EVAL_INCLUDE_DRAFTS=1` path can also append provider
draft fragments, although no checked-in build setting enables it. No
Forward-Plan-specific rendered, device, provider, professional, longitudinal,
operational, or external evidence was collected. Production readiness remains
**NO-GO at 18/100 with 0/5 required external artifacts**.

The preceding bounded slice closes the verified P0 cross-account and stale-source
race in asynchronous Proof Moment generation. A request can be captured only
for a signed-in, fully hydrated, nonempty account when the account-scoped
`PracticeSessionStore` epoch owns the exact saved row and every source field
matches. Its token and cache bind account lifecycle, session-store generation,
the full source snapshot/revision, and voice/goal/baseline generation identity.
Cache hits revalidate the token. Provider and deterministic results share one
archive compare-and-save path that rechecks account, lifecycle, store epoch,
source, transcript quote, and session date; a failed save is neither cached nor
returned. Weekly Insight, Path Celebration, First Rep, and Summary capture the
request before suspension and revalidate the result immediately before view
assignment. Weekly Insight also resets account-lifecycle-stale state, and
delayed lifecycle cache invalidation cannot erase a newer epoch.

Focused verification passes **39/39** and the related regression selection
passes **130/130**. This covers signed-out/hydrating state, identity before
store reload, an identical destination row, rapid same-account return,
same-account store reload, source drift before commit, archive grounding, cache
scope, and delayed invalidation. It is focused local evidence: the complete
unsigned target also passes **4,331 unique tests / 4,350 device-configuration
executions** with zero failures or skips; the result bundle is
`.build-roleplay-terminal/Full-NoumTests-ProofCAS-20260715-final-r2.xcresult`.
The current-source unsigned Release simulator build succeeds. A light
current-source simulator sweep renders the expected
five tab tops and is recorded in
`.screenshots/2026-07-15-proof-moment-account-cas/HANDOFF.md`; it does not
exercise the Proof Moment account-transition path.

The scoped P0 is closed, not the whole Proof Moment lifecycle. Same-account
voice, goal wording, and baseline changes during provider work are not yet
live-revalidated; persisted replay lacks goal/baseline provenance. Source
mutation or deletion after commit does not remove the archived proof, and
rendered consumers retain only the proof after assignment, so later
same-account drift can leave stale copy visible or replayable. Cancellation
during the MainActor archive hop can still persist a proof even when the
service returns nil, and the unused unchecked archive writer remains a latent
internal bypass. No Proof-Moment-specific rendered, physical-device,
live-provider, professional, longitudinal, operational, or external evidence
was collected. Production readiness remains **NO-GO at 18/100 with 0/5
required external artifacts**.

The preceding bounded slice keeps free-form premium Coach Read prose outside the
mechanic evidence system. Generation resolves the exact persisted row and
uses transcript, prompt, mode, score, duration, and score-only continuity;
filler, WPM, pace, tempo, cadence, and historical mechanic comparisons are
absent from provider context and deterministic fallback. Derivative baseline
strengths/blockers, clutch-word occurrence history, filler/pace pressure reads,
and mixed pressure resilience are withheld while independent score, duration,
and structure context remains. Returned prose is rejected for mechanic
assertions, common filler/speed aliases, or fabricated transcript quotes.
Required provider quote presence is separated from all-field quote integrity;
legacy replay applies integrity without deleting safe nonquoted coaching, and
contraction-safe deterministic quotes keep the offline path persistable. An
account-scoped full-source compare-and-swap token is checked atomically by the
session store after the asynchronous request, and only revalidated output can
persist. Summary and both Review replay paths suppress unsupported legacy
mechanic prose while retaining grounded nonmetric coaching. For that preceding
slice, the focused lane passes 56 unique tests / 58 device executions, and the
complete unsigned simulator target passes 4,320 unique tests / 4,339 device
executions with zero failures or skips; its unsigned Release simulator build
also succeeds. This proves a local fail-closed boundary, not provider
quality, rendered/device behavior, professional calibration, transfer, or
production readiness.

The preceding Summary-only slice binds Summary mechanics to the identified persisted
rep. Every active and diagnostic Summary entry carries a
`finalizedSessionID`; a nil or unmatched identifier cannot borrow recent
history for filler/WPM interpretation and cannot authorize new finalization
lifecycle effects. Deterministic verdict, filler-rate presentation, and
improvement bullets use the exact row's qualified projections, while pause,
pitch, baseline, and coach-note mechanics are resolved from that row after the
exact eligible-row gate. Independent presentation score, category, transcript,
and duration evidence remains available. Focused verification passes 58/58,
and the complete unsigned simulator target passes 4,302 unique tests / 4,321
device executions with zero failures or skips, and that Summary-only source's
unsigned Release simulator build succeeded. A light five-tab sweep was attempted, but
normal guest bootstrap rendered the account-save failure on every deep link;
the captures are retained only as blocker evidence and do not prove tab or
Summary rendering. This remains partial because the
qualitative delivery line, durable CoachMemory/derived delivery reads, IM baseline
comparison, Ask Noum session opener, share/request-feedback WPM, Proof Moment
metric qualification and remaining lifecycle/replay gaps, Forward Plan metric
qualification and first-plan reachability, and other durable narrative/reward
consumers remain open.

The current working tree closes the previously ranked raw Review inventory and
immediate post-rep/AI Insights metric leak through existing owners. Ah-Counter
and Timed summaries retain factual saved-run counts while exposing exact
measured denominators; filler/pace aggregates, clean-run claims, trends, chart
points, detail WPM, normalized replay targeting, and goal examples consume the
established 20-word / 15-second, supplied-confidence, current-schema, and
non-fixture projections. Unqualified chart values remain absent rather than
zero, raw filler count stays inspectable as a saved fact, and score-only reads
remain independent.

`PostRepCoachNoteService` now withholds current filler, derivable word count,
and WPM from the AI prompt unless the exact rep qualifies, then rejects output
that asserts withheld mechanics or treats filler as proof of rushed pace.
Recent summaries and baseline mechanics fail closed through existing owners.
`AIInsightsService` applies the same boundary to session prompts, baseline
context, deterministic fallback, and cache identity without synthesizing a
missing score. The focused selection passes 92/92 across 12 suites; the
complete unsigned simulator `NoumTests` target passes 4,289 unique tests /
4,308 device executions with zero failures or skips, and an unsigned
current-source Release simulator build succeeds. At that earlier boundary,
active Summary Coach Read remained open; the newest slice above now quarantines
its free-form mechanics and exact-session persistence. Proof Moment metric
qualification and remaining lifecycle/replay gaps, Forward Plan metric
qualification and first-plan reachability, durable CoachMemory/derived delivery
reads, and other narrative/reward consumers remain open; legacy trend archives
also remain
intentionally absent until qualified snapshots accrue. This is local
deterministic evidence, not professional calibration, physical-device behavior,
user benefit, or an external artifact.

The current working tree closes Summary's rendered capability-loss and exact
attribution gap through the existing recommendation owners. The exact
finalized `NextAction` and `SummaryPrescriptionProjection` used to render the
card now remain the exposure identity through tap; the complete live
`NextActionModeAvailability` snapshot may only downgrade that displayed mode
to Timed. `RecommendationTapAttribution` synchronously preserves the shown
denominator on fast fallback, acceptance still requires an exact
displayed/launched mode match, and a non-accepting route clears any interrupted
regular-mode `PracticeModeQuickStart`. A Release-inert fixture renders the real Summary
Pressure branch, removes Pressure only at tap, and pre-arms stale Timed state.
At Accessibility XXXL on iPhone 17 Pro / iOS 26.5, the 1/1 focused lane proves
the 44-point Pressure action reaches exact default manual Timed setup with no
Pressure/Conversation destination, automatic prompt, prescribed demand, or
stale quick-start; the content-free diagnostic retains shown at exact 0% with
no accepted event. Projection/fixture/attribution tests pass 23/23, the full
recommendation UI suite passes 5/5, the complete unsigned unit target passes
4,242 unique tests / 4,261 device executions, and the unsigned Release
simulator build succeeds. This is deterministic local simulator evidence for
one Summary Pressure branch, not physical capability loss, rendered Summary
Conversation/Home loss, population effectiveness, or an external artifact.

The current working tree closes the rendered mixed Review-history trust gap
through existing owners. Raw `PracticeSessionStore.sessions` still owns saved
count, search, exact detail, replay setup, deletion, and export, while the
shared progress-eligible projection now owns score aggregates, session-backed
mode cards, previous comparison, targeted replay, Review story/chart/highlight
reads, and Profile coaching depth. `TransformationKPIReport` counts unique
review-open correlations only when they match eligible session IDs, so thin,
foreign, and duplicate opens fail closed. A DEBUG-only five-row fixture renders
three newer high-score saved captures alongside two older measured reps. At
Accessibility XXXL from a simulator configured with Reduce Motion, the 2/2 UI
lane proves five raw rows remain inspectable while Review/Profile remain at two
measured reps and thin detail shows neutral saved-capture provenance. The
focused history/KPI lane passes 31/31, the complete unsigned unit target passes
4,241 unique tests / 4,260 device executions with zero failures or skips, and
an unsigned current-source Release simulator build succeeds. Non-finite and
evaluation-only rows remain unit-only; this does not prove every stricter
filler/WPM quantity floor, legacy Sudden Death run-ledger reconciliation,
physical hardware, calibration, transfer, operations, or an external artifact.

The current working tree closes the representative rendered
capability-loss-at-tap gap on Train without adding another recommendation,
routing, or analytics owner. A Release-inert, DEBUG-gated fixture supplies a
coherent Pressure source blueprint and a later unavailable capability snapshot;
`TrainRecommendationProjection`, `PracticeModeLaunchProjection`,
`RecommendationTapAttribution`, `RecommendationLearningStore`, `FlowEventLog`,
and the established router remain authoritative. Train renders the exact
Pressure Drill recommendation and a hittable 44-point Begin action, then fails
closed to ordinary Timed setup when capability disappears at tap. The fallback
has no Pressure/Conversation destination, automatically mounted prompt, or
stale prescribed demand; the content-free flow diagnostic retains shown at
exact 0% with no accepted event. The complete availability, attribution,
fixture, and recommendation-surface selection passes 24/24, and the complete
current-source unsigned unit target passes 4,228 unique tests / 4,247 device
executions with zero failures or skips; an unsigned current-source Release
simulator build also succeeds. This is deterministic simulator evidence
for one Train Pressure branch, not a physical capability transition, rendered
Home or Conversation loss, signed TestFlight behavior, or effectiveness
evidence. The leading current-source paragraph separately closes Summary
Pressure loss.

The current working tree closes the remaining representative rendered
mini-drill completion gap without creating a second scoring or persistence
path. A DEBUG-only fixture selects the existing Silent Transitions variation
from Summary and contributes only a finalized transcript receipt and recorder
duration. The production `MiniDrillCompletionDisposition` still classifies
that evidence, `MiniDrillView` still constructs the outcome, and Summary still
requires durable insertion of the exact account-owned receipt before XP,
reward, baseline, streak, or result presentation. At Accessibility XXXL from a
simulator configured with Reduce Motion, the two-word branch returns to a
hittable Start drill state with the established three-word/three-second
explanation and no result/XP; the 12-word/12-second branch renders the exact
zero-filler Clean Run, nonzero XP, and a usable Done transition back to Summary.
The fixture contract joins the related speech/history/account selection at
48/48; the rendered lane passes 2/2, the neighboring Lesson Apply completion
lane remains 2/2, and the complete current-source unsigned simulator
`NoumTests` target passes 4,224 unique tests / 4,243 device executions with zero
failures or skips. This is representative shared standard/framework rendering,
not proof of specialized live WPM/pause/PREP metrics, real microphone/provider
timing, physical hardware, calibration, transfer, or an external readiness
artifact.

The current working tree closes the rendered TR-4 gap through existing owners.
`SpeechRecognizerViewModel` preserves the exact
`LocalSpeechError.onDeviceRecognitionUnavailable` locale as a typed recording
issue; Timed Practice renders a specific offline-language headline and guidance,
withholds the futile generic retry and inactive End Session controls, and uses
its existing cleanup/reset lifecycle for Back to setup. The transition respects
Reduce Motion. A DEBUG-only provider fixture emits the same typed error and a
deterministic launch seam writes through `LocaleSettingsManager`, so persisted
test order cannot change the claimed locale and no parallel production store is
introduced. Focused speech/lifecycle verification passes 41/41. The real Timed
flow passes 1/1 at Accessibility XXXL with Reduce Motion, the generic provider
failure recovery remains green at 1/1, and the complete current-source unsigned
simulator `NoumTests` target passes 4,223 unique tests / 4,242 device executions
with zero failures. This proves local typed mapping and rendered recovery, not
real `SFSpeechRecognizer` availability, manual VoiceOver behavior, signed
TestFlight, deployed services, user benefit, or any required external artifact.

The current working tree closes a Lesson Apply false-progress path without
claiming that the research prescribed a literal numeric threshold. Four
keyword-only and two device-only lessons could previously pass on a fragment
that matched their narrow rubric. The evaluator now preserves every authored
quantity criterion and adds a visible 12-word complete-answer criterion only
where none existed. A usable terminal receipt and at least three finite
recorder-owned seconds produce transcript-free schema/word-count/duration
evidence; `LessonOutcome` requires that verified evidence plus the exact
concept/spot/apply result shape before lesson history or XP can mutate. Account reload
and teardown also clear transient lesson celebrations. Exact fragment, terminal
receipt/duration, malformed-outcome, XP, account-switch, source-order, and
rendered retry/completion contracts pass. The focused unit selection is 44/44,
the rendered UI selection is 2/2 with Reduce Motion and Accessibility XXXL
coverage, and the complete unsigned simulator `NoumTests` target passes 4,222
unique tests / 4,241 device executions; Swift Testing reports 4,200 tests across
428 suites (`/tmp/noum-lesson-apply-full.xcresult`). This is local
believable-progress evidence only. Historical aggregates remain grandfathered,
rubric thresholds lack professional calibration, microphone/provider timing is
not forced by the fixture, and no external readiness artifact was collected.

The current working tree also closes a mini-drill history ownership and receipt
provenance gap. The former `drillHistory` archive was device-global and
unversioned, yet it supplied streak, coaching, forward-plan, and recommendation
evidence. `DrillHistoryStore` now reloads a per-account archive and admits only
versioned mini-drill receipts that bind the exact outcome ID to its parent
practice session, terminal word count/duration, variation, and bounded XP.
Malformed, legacy, and duplicate rows fail closed before memory or disk changes;
the newest 30 verified receipts remain the deliberate retention window. Summary
must persist the receipt before any XP, reward, baseline, streak, or result
effect. The old global archive is not migrated into an account; it remains only
in the existing unattributed export/deletion inventory. The focused
DrillHistory/account-registry/Summary selection passes 47/47, and the complete
current-source unsigned simulator `NoumTests` target passes 4,213 unique tests /
4,232 device executions with zero failures; its Swift Testing phase reports
4,191 tests across 427 suites (`/tmp/noum-drill-history-full.xcresult`). This is
local deterministic evidence only: historical monotonic XP is not reconciled,
the bounded archive is not an unbounded idempotency ledger, and signed Release,
complete UI, device, backend, calibration, transfer, and external launch proof
remain missing.

The current working tree corrects the earlier TR-5 overclaim. The generic
standard/framework drill already awaited readiness and finalization, but the
three active specialized routes did not. Standard/framework, Beat the Brake,
Land the Pause, and PREP Stack now share awaited readiness, terminal completion,
recorder-owned duration, a three-word / three-finite-second outcome floor, and
retry behavior for thin speech. Summary independently validates that quantity,
binds the outcome to the parent practice session, and requires durable insertion
of the versioned receipt before XP/reward/baseline/result effects. Live WPM
samples and pause locks remain the specialized metric owners. PREP additionally
requires its declared 28 words for
success and bounds close strength below 100% until that evidence exists. The
foundational focused speech-integrity suite passes 28/28 unique tests across
receipt, quantity, lifecycle-source, PREP-boundary, and Summary-ordering
contracts; the later fixture contract brings the related current selection to
48/48. The current complete unsigned simulator `NoumTests` target passes 4,224
unique tests / 4,243 device executions with zero failures or skips. A seeded
light sweep plus the representative standard insufficient/eligible branches
were visually inspected, and the rendered lane passes 2/2 at Accessibility
XXXL from a simulator configured with Reduce Motion. Specialized live-metric
branches, microphone/provider timing, physical hardware, calibration,
effectiveness, longitudinal transfer, and launch operations remain unproved,
so this earns no external readiness point.

At `bb155866`, Cut the Crutch no longer converts a one- or two-word terminal
capture into visible score, XP, or Daily Goal/streak progress. The existing
live engine remains authoritative for avoided-word violations, survival,
composure, and the candidate result. A new pure disposition requires the shared
recording-completion receipt plus the existing three-word / three-finite-second
progress floor before that candidate may be committed and presented. Thin
usable speech returns to setup with a calm retry explanation; unusable capture
retains the recognizer error path; eligible capture preserves the exact
candidate and awards once. Focused Cut the Crutch, Pace, and shared speech
verification passes 36 parameterized executions across three suites. Two
deterministic UI flows pass with Reduce Motion enabled, including an
Accessibility XXXL thin-speech retry and the exact 10/10, +150 eligible result.
The complete target passes 4,200 unique tests / 4,219 device executions with
zero failures or skips. This is local deterministic and rendered simulator
evidence only. The fixtures bypass microphone/provider timing, and terminal
text cannot reconstruct or independently reconcile live avoided-word timing.
No durable Cut the Crutch attribution, physical-device result, effectiveness
evidence, or external artifact exists, so this closure earns no readiness
point.

At `5987636f`, terminal Roleplay guidance is bound to the continuation the app
can actually deliver. The view computes one `RoleplayEngine.nextTurn` result at
submission, caches it, and consumes that same transition for copy and
advancement. Existing pre-terminal retry modes retain their exact “Next
attempt” language. At the four-attempt cap, the retry evidence becomes a future
“Practice focus”; when no transition can be produced before the cap, guidance
fails closed without promising a rung or objection. Completion still reads the
last attempted `RoleplayTurnResult` pressure. Four pure tests pass inside the
focused 38/38 selection, three deterministic UI flows pass including the
fourth-attempt Accessibility XXXL feedback/completion states, and the complete
target passes 4,188 unique tests / 4,205 device executions with zero failures
or skips. This is local deterministic and rendered simulator evidence only; it
earns no external readiness point.

At `cb5f0327`, Review's progress-bearing projections no longer treat every
saved row as measured evidence. `ReviewStoryPresentation` filters evidence
depth and latest-rep navigation through the shared eligibility policy; all
highlight selectors enforce the same boundary defensively; and one pure
30-day scored-session projection now drives both the parent chart gate and the
chart card. Raw All Reps history, exact detail routing, export, and deletion
remain unchanged. The focused Review selection passes 48/48 and the complete
target passes 4,184 unique tests / 4,201 device executions with zero failures
or skips. Xcode recovered from one transient parallel-clone launch denial; the
authoritative result bundle is Passed. A fresh light sweep proves only the
ordinary valid-evidence shell, not the mixed invalid-history state. This is
local coaching-trust evidence and earns no external readiness point.

At `8ec313c9`, Profile no longer treats a Review-only capture as progress or
coaching evidence. Raw `PracticeSessionStore.sessions` continues to own the All
Reps count and exact saved-history inspection, while the existing
`progressEligibleSessions` projection now supplies Profile composition,
coaching-plan input, Coach Read evidence depth, Coach Parity diagnosis, the
three-rep transformation question, goal/forward-plan projections, retention
and session stats, and filler-pattern evidence. A matrix of too-few-word,
sub-three-second, non-finite, and evaluation-fixture rows remains covered in
raw-history projection tests but leaves all tested Profile evidence cold. The
focused selection
passes 44/44; the complete target passes 4,177 unique tests / 4,194 device
executions with zero failures or skips. This is deterministic local
coaching-trust evidence only. It earns no external readiness point and does not
prove physical rendering, calibrated effectiveness, longitudinal benefit, or
launch operations.

The current working-tree fixture supersedes the earlier rendered-evidence
limit for durable finite rows: too-few-word and sub-three-second captures are
now exercised through Review, All Reps, detail, and Profile. Non-finite and
evaluation-only cases remain unit-only because durable persistence rejects or
filters them; no UI claim is made for those shapes.

At `c4376973`, Roleplay completion remains bound to the pressure rung actually
attempted. The existing engine now resolves the prospective pressure level and
objection atomically. A terminal fourth response enters completion before the
recommended retry transition can mutate UI state, and an unavailable next
objection likewise cannot commit a prospective level. Level-up and level-down
recommendations can therefore describe a future attempt without changing the
pressure chip or “Final attempted pressure” summary. Pre-terminal exact retry,
fresh-selection, and `RoleplayStore` history behavior remain unchanged. Focused
verification passes 55 tests; the full target passes 4,175 unique tests / 4,192
device executions with zero failures or skips. This is deterministic local
truthfulness evidence only. Microphone-driven rendered completion, physical-
device behavior, professional calibration, user transfer, and launch evidence
remain unproved, so this closure earns no readiness point.

At `9bc93a23`, the retired Daily Challenge surface can no longer produce
invisible rewards, mutate readiness after a rep, or advertise unreachable work.
Production has no tile construction site, manager session subscription,
appearance/finalizer trigger, account-lifecycle activation, or expiry scheduler.
The compatibility manager initializes without side effects. Legacy
`noum.dailyChallenges.*` data remains covered by account export and deletion,
and historical XP/League awards are preserved. Launch and passive notification
refresh remove pending and delivered requests for only the exact retired
identifier. Focused retirement/Home/account coverage passes 30 tests; the full
target passes 4,169 unique tests / 4,186 device executions with zero failures or
skips. This is local lifecycle integrity, not physical upgrade proof or an
external artifact, and it earns no readiness point.

At `eaf2f31c`, raw Review persistence and earned progress have one explicit
boundary. Non-empty transport-valid captures remain inspectable, but sub-three-
word, sub-three-finite-second, and evaluation-only rows cannot mutate XP,
Path/achievement/mode/league state, streaks, goals, baselines, recommendation
outcomes, coaching memory, proof archives, rehearsal readiness, or retention
KPIs. The existing stores/finalizers remain authoritative; reactive and pure
projections filter the same eligible view. IM skips grading and relationship
mutation, Pressure Drill skips parallel game ledgers, and Summary withholds
credit and AI/durable coaching effects for Review-only rows. Focused selections
pass 25/25 and 30/30; the complete target passes 4,166 unique tests / 4,183
device executions with zero failures or skips. This is local deterministic
integrity only. Existing monotonic ledgers are not retroactively reconciled,
and no external artifact was collected.

At `9088fdc3`, `SpeechRecognizerViewModel` owns one monotonic microphone-capture
receipt frozen before audio teardown and terminal provider completion.
Persisted duration, `lastSessionDuration`, pitch eligibility, and quality
telemetry read that same receipt; Mini-drill and Pressure Drill totals no longer
remeasure after an `await`. Comparison epoch 2 identifies this exact-capture
provenance. Version 1 rows remain readable but are excluded from duration-
derived comparisons, baselines, and pressure profiles. Persisted baselines now
carry their comparison recipe and rebuild from current-epoch rows on mismatch;
pressure EMA replay is deterministic and chronological. Focused verification
passes 26 unique tests, the related selection passes 74, and the complete target
passes 4,155 unique tests / 4,172 device executions with zero failures or skips.
This is local deterministic evidence, not a live-provider latency run, physical-
device proof, professional calibration, longitudinal transfer, or launch
evidence.

At `b5747542`, Path unlock delivery is atomic with the common durable practice
finalizer. A synchronized pre-append unlock snapshot survives reactive store
recomputation; post-finalization resolution chooses the lowest registry-order
new node and carries the exact triggering session ID into celebration stat copy
and transcript proof. General criteria share the evaluator's three-word /
three-finite-second minimum and exclude evaluation fixtures, while the existing
stricter filler qualification and persisted-unlock grandfathering remain. This
prevents sub-floor progress, missed order-dependent celebrations, and the
newest-first `.last` bug that could cite an old rep. Focused integrity/filler
verification passes 23 unique tests, the related Path/finalization/presentation
selection passes 55/55, and the full target passes 4,145 unique tests / 4,162
device executions with zero failures or skips. The light simulator sweep proves
only the five-tab shell; it did not force an earned landmark. This is local
believable-progress correctness, not retention, accessibility, physical-device,
or launch evidence.

At `c3e018d4`, Roleplay fails closed on filler evidence that cannot satisfy the
shared quantity-qualified contract. Roleplay turns do not retain finalized
duration, so the duplicate raw word-ratio penalty was removed from quality and
retry-pressure selection rather than presenting unsupported certainty.
Semantic uses of “like”, “actually”, “kind”, and “sort” and isolated
unqualified disfluencies therefore remain neutral; existing directness,
evidence, listening, question, and explicit-hedge signals remain active. Pace
Training, Cut the Crutch, and Roleplay now reuse the shared content-free
startup-fallback notice, completing source wiring across all nine speech
surfaces. Focused fallback verification passes 26 unique tests, focused Roleplay
verification passes 24, and the full target passes 4,139 unique tests / 4,156
device executions with zero failures or skips. A light simulator sweep rendered
all five tab tops, but no real provider failure or physical/TestFlight fallback
presentation was produced. This is local fairness, wiring, and regression
evidence only.

At `ab5b6aaa`, the established qualitative goal breakdown now enters the
existing `SessionFinalizer` → `NextActionEngine` owner instead of a parallel
prescription system. `GoalOutcomeRead` selects the largest goal-weighted deficit
only among style-compatible actionable dimensions, so warm/storytelling speech
cannot be redirected toward verdict-first or hedge stripping and semantic
hedges are not relabelled as filler speech. A goal rep requires an explicit
matching style, an established read, a qualifying latest session, an
evidence-backed target below 0.70 or still missing proof, a recognized mapping,
non-mixed movement, and an
exact proof test. Severe current evidence, a persistent blocker, and a
continuing durable case remain ahead of it. Goal winners carry exact goal,
dimension, source-session, and proof provenance into Summary and the existing
followed-rep ledger; non-goal winners carry none, legacy goal-only outcomes fail
closed, and a capability fallback clears incompatible goal credit. The focused
goal suites pass 38/38, the related action selection passes 78/78, and the
complete `NoumTests` target passes 4,114 tests across 421 suites with zero
failures or skips. This is local routing/attribution evidence, not calibrated
effectiveness or production evidence.

At `a2502c04`, the Clean rep and Filler-free week Path milestones consume the
same shared quantity-qualified zero-filler evidence as the rest of the coaching
system. A qualifying rep requires 15 seconds, 20 words, adequate transcript
confidence, the current comparison schema, and a non-evaluation fixture; the
weekly node additionally requires 5/10+ and five qualifying reps inside seven
days. The stricter policy is prospective: already-persisted unlock IDs continue
to win through the existing JSON-array ledger, preventing a silent revocation
after upgrade. Gating and registry copy name the actual evidence floor and no
longer claim that generic clean practice proves pressure transfer. The focused
17-test suite, 49-test related selection, and complete 4,126-unique-test /
4,143-execution unit target pass with zero failures or skips. A seeded Path
capture verifies launch and top-level rendering, not the lower milestone copy.
This is local correctness and compatibility evidence only.

At `ac664112`, direct Ask Noum filler questions, trajectory context,
provisional Coach Read, AI Coach feedback, and deterministic repairs share the
same exact quantity-qualified filler projection. Qualified evidence carries
count, duration, and fillers per minute; undersized, low-confidence, stale, or
evaluation-only evidence fails closed. Arbitrary count scraping and unsupported
pressure-location certainty are removed. The complete serial unit target passes
4,109/4,109. A detached clean app-path refresh binds 53 conversations / 109
turns and 50 scored fixtures to fingerprint
`sha256:adfcd7bce86a2e248a923865aa4d014f93ab564670acc42e690585a14cbae2f4`;
average 79.78, zero fixture failures, and trace quality passes. This remains
local target-shape evidence only.

At `dbafb01b`, Summary, Practice insights, `CoachingPlanner`, and chronological
Review/Profile comparisons consume the shared quantity-qualified filler-rate
boundary. Current samples require 15 seconds, 20 words, and adequate transcript
confidence; historical comparisons require current schema, exclude evaluation
fixtures, use at least two prior samples, and suppress movement below 0.5
fillers per minute. Summary exposes rate movement and an explicit count,
duration, and rate accessibility description rather than implying raw-count
progress. The focused selection passes 19 unique tests and the complete
`NoumTests` target passes 4,102 unique tests / 4,117 executions with zero
failures or skips. A light five-tab simulator sweep is visually clean but does
not prove the seeded qualified-history Summary state. This is local consistency,
not calibration, longitudinal benefit, physical-device, or launch evidence.

At `5bbb850b`, `NextActionEngine` passes the finalized
`NextActionInput.trends` into the existing drill engine instead of allowing a
second read from mutable shared trend state. This preserves the established
action owner and removes order-dependent recommendation behavior found by the
complete suite. The affected three suites pass 57/57 tests. The complete
`NoumTests` target then passes 4,083 unique tests / 4,098 executions with zero
failures or skips on iPhone 17 / iOS 26.5. One simulator clone launch was
transiently denied, but Xcode recovered and the result bundle records the full
expected count with result `Passed`; no assertion or execution loss remains.

At `ac393554`, speech-quantity fairness reaches the qualitative goal and public
trajectory evidence boundary. `UserTrajectoryCache` withholds WPM below the
shared 15-second / 20-word floor and emits a recent filler-rate trend only when
all three reps qualify. `CoachReasoningPass` uses qualified filler rate for
hedge/pacing deductions, treats absent or undersized mechanics as missing
evidence, and suppresses count-driven prescriptions from tiny reps.
`TrajectorySummaryBuilder` requires two qualifying reps per week for its public
filler-rate trend, and `GoalOutcomeEngine` prevents mature history from
promoting a sub-floor latest rep. Focused goal, trajectory, calibration, and
availability regressions pass. This is local deterministic consistency, not
professional calibration, longitudinal benefit, or launch evidence.

At `4da56e3e`, speech-quantity fairness reaches the score-facing evaluator and
the remaining direct severe-pace shortcut. Timed Practice and Ah Counter now
use qualifying fillers per minute for score, XP, feedback, categories, weak
moments, insights, and recent-session comparisons; equivalent 1/60 and 10/600
rates receive equivalent reads, while 3/20 remains concentrated evidence.
Sub-15-second speech withholds filler judgment, explicit zero remains positive
evidence, and Sudden Death retains exact-zero tolerance. Immediate severe pace
now requires the shared 15-second / 20-word quantity floor plus finite WPM.
The focused selection passes 53 unique tests and the complete simulator unit
target passes 4,075 unique tests / 4,090 executions with zero failures or
skips. This is local deterministic evidence, not professional threshold
calibration or production effectiveness.

Immediate filler-driven prescription is now duration-normalized through one
pure projection owned beside the existing baseline evidence floor. At
`c3d1ff65`, `NextActionEngine`, `DrillEngineV2`, `TrendAnalyzer`, filler-aligned
style copy, and pressure-stretch eligibility use qualifying fillers per minute
rather than raw counts. The policy fails closed below 15 seconds, translates the
existing 2/3/5/8 thresholds into per-minute boundaries, and requires at least
three detected fillers before the severe tier. Ten fillers in ten minutes no
longer become a severe filler action; three fillers in twenty seconds do. The
same normalization now applies to cross-session filler trends, while explicit
target areas and filler-before-pace priority remain unchanged. A rebuilt full
simulator unit run passes 4,061 tests with zero failures or skips. At
`ec10990f`, severe qualifying filler burden now selects the existing Ah Counter
(`Filler Control`) full-rep route instead of a generic mini-drill. A directly
observed severe first qualifying rep may make that one corrective prescription;
non-severe thin evidence still yields no adaptive action. Home and Train now
build filler recommendation inputs from qualifying rates and rate trends, and
Summary reuses that same context builder rather than a raw-count duplicate. A
fresh focused run passes 93 tests and the full simulator unit target passes
4,065 tests, both with zero failures or skips. The 8/min boundary remains an
uncalibrated local routing heuristic; these tests do not establish professional
calibration, longitudinal benefit, or production effectiveness.

The checked-in Firebase deployment configuration now closes the backend path
that remained outside the non-executing npm command. At `77352b03`, the exact
four-requirement blocker is the first lifecycle hook for every Functions
codebase and Firestore database, so repository-configured scoped, combined, and
unscoped Firebase deploys refuse before lint, build, target preparation, or
network mutation. Hosting intentionally remains outside that lock for a
separately authorized privacy-policy correction. Seven deploy-lock tests,
86 readiness-gate tests, 109 Functions authority tests, 16 cloud-operations
contracts, and 22 operational static checks pass. This does not control direct
gcloud/Cloud Console mutation or alternate Firebase config files, provide
deployment authorization, create an immutable release artifact, or prove a
deployment occurred.

The dormant post-create challenge route now carries exact server-authored
prompt bytes and the existing content-free observation intent together through
the account-bound opaque Timed handoff. It rejects normalization, truncation,
wrong-account consumption, stale tokens, prompt replacement, and byte-different
armed sessions while leaving every capability false and every observation
ineligible. At `c7cd0b51`, that route is also a process-local lease rather than
persisted prompt-bearing state: it is created only after exact account/token
consumption and authoritative cached participant/expiry/unplayed validation,
then binds to the exact saved session before Summary. Exact prompt bytes,
session ID, token, account, and lease expiry fail closed; matching unbound
cancellation, retry/terminal cleanup, account teardown, and legacy-key purge
are covered by a 73/73 focused iOS run. The challenge sheets still have no
production call site, both capabilities remain false, and no eligible-evidence
writer exists, so this is route-integrity substrate rather than a complete
challenge UX or eligible evidence path.

The existing goal-style professional-calibration owner now also fails closed on
empty or partial case coverage, fewer than two distinct professional reviewers
per case, wrong roles, duplicate reviewer slots, malformed dimension maps,
invalid score/risk/note shapes, and evidence-access receipts attributed to
different reviewers. At `a5d5c365`, its focused simulator suite passes 14/14;
the artifact-dump XCTest emits all 12 cases with the strengthened response
schema and no raw transcript field. This is local review-intake integrity, not
a professional result or authorization to ship a numeric score.

The integrated implementation includes unified four-mode
availability, Train's atomic recommendation projection, Prep's stable-shape
availability fallback with category-bounded Timed prompts, the Phrase
Bank→active-week handoff, the account- and route-bound Timed prompt owner, and
selected-surface ownership for Home and Train prescription exposure, typed-ID
Speech Project execution through the existing Timed route, and
explicit quarantine of superseded privacy-audit documents. Followed-rep
learning now also requires explicit recommendation acceptance plus the matching
completed mode, clean-ancestor evidence reuse is documentation-only, and all
uncommitted behavior source now blocks evidence binding even when the manual
coach fingerprint matches. Recommendation outcomes now also require bounded,
unique history with exact persisted Timed difficulty, Pressure Drill
difficulty, and Speech Project identity; normalize fillers per minute;
judge the prescribed metric; and carry session/outcome schema provenance. Case
status now consumes the same accepted, comparable outcome contract through
exact current-epoch session IDs, target-metric evidence, and duration-normalized
filler criteria. Their
focused and full source/test results are recorded below with their exact source
boundaries. Recommendation state is now also serialized and burst-coalesced per
account, guarded during authoritative hydration, and routed on Firebase through
an authenticated, App Check-enforced transactional callable. The local source
adds revision-zero legacy migration, mutation/body-bound replay idempotency,
bounded conflict merge, account-scoped durable cursor/mutation provenance,
server-authority-only rules, and fail-closed unversioned REST writes. Detached
Node and focused Swift tests prove their named reducer, codec, persistence,
lane, and source-rule contracts. The callable and rules are not deployed, the
runtime identity and App Check are not externally verified, and no active-client
inventory, minimum-client decision, deployment, or two-device
mixed-build smoke exists. Older clients retain read compatibility through the
legacy state fields but their direct writes are intentionally rejected after
cutover. Distributed conflict safety therefore remains operationally unproved.
Home and Train now also apply one shared tap-attribution policy to the exact
captured rendered exposure: a recommended Begin tap records shown before the
live capability result is classified, while acceptance remains restricted to
an exact displayed/launched mode match. Capability-loss fallback therefore
contributes the KPI denominator without becoming accepted or followed. The
current Train Pressure lane now proves that shown-only contract through the
rendered recommendation, manual Timed fallback, and content-free flow
diagnostic; Home, Summary, and Conversation loss remain outside that rendered
proof. Current
Timed recommendations additionally carry their visible difficulty through the
existing route and adherence ledger. A followed outcome now requires current
adherence schema plus exact prescribed/executed demand; legacy mode-only rows
remain readable but fail closed for coaching and KPI use. Manual, Adjust,
Practice Again, free-form Ask, and fallback routes remain mode-only by design.

Last complete source-bound evidence checkout:
`7ae1fe43153f76c682f8a2d909842632cdcb4410`

The last complete clean-source regression passed 4,061 tests with zero failures
or skips at `7ae1fe43`; the same detached source passed the optimized Release
simulator build and bundle scan. The latest canonical coach artifact passes
app-path, real-pipeline, production-evidence, and trace-quality gates at the
later evidence-tooling boundary `70b0b380`. Subsequent release-verifier commits
do not change coach output, but they make that artifact a named historical
source boundary rather than current-HEAD evidence. A future current-source
refresh must use the hardened verifiers. The
current four-mode availability contract is **Proved** at its pure/source
boundary. Prep's
locked-shape fallback and the current Home/Train Filler Control prescription are
additionally proved through their rendered routes. Speech Projects now have a
separate rendered catalog-to-Timed execution proof, but remain outside the
adaptive prescription engine. That does not prove rendered behavior for every
recommendation destination in the report's wider catalog.

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
  evidence only. Its authored replies prove post-generation wiring, not what
  the production model generates, and it can become stale if coach source moves.
- Clean-ancestor and uncommitted-source checks now fail closed. The whole
  non-ignored worktree is classified with exact documentation/generated-output
  exclusions; ignored local configuration still belongs to separate build and
  release-isolation checks rather than Git provenance diagnostics.
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
| Local goal-attainment product wiring | **Proved** | When the user explicitly selects a style, current goal rubrics, goal-aware review, adaptive next action, progress surfaces, and weekly/real-world context form real connective tissue across existing modes. Without that provenance the style layer stays neutral. |
| User-facing Ask Noum coaching loop | **Contradicted** | Current production behavior does not meet the intended loop: five consecutive observed generations failed after nominally successful admission, a durable local guest can see a composer it cannot authorize, and the reporter rejected the wording as repetitive, unnatural, and non-expert. Local repairs do not reverse this classification until the deployed secure path and real output pass acceptance. |
| Literal six-feature prompt bundle | **Incomplete** | Large parts exist, but public numeric style scoring, humorous/calm goals, a true under-60-second spoken rep, the requested full prescription destination set, mid-stream provider failover, and a single unified privacy centre do not. |
| Report acceptance-test contract | **Incomplete** | Many equivalent safety and persistence tests pass; several literal examples are absent or contradicted by the safer current contract. |
| KPI instrumentation | **Incomplete** | Account-local event derivation is strong. Population rates, medians, cohorts, experiment inference, and a numeric goal-score slope are not implemented. |
| Experiment infrastructure | **Incomplete** | Assignment, eligibility, exposure, and bounded attribution contracts exist. There is no approved allocation or population result, and Test B's shipping treatment is qualitative rather than numeric. |
| Production effectiveness and coach parity | **Missing** | No valid professional calibration, longitudinal real-user outcome artifact, or experiment result exists. |
| Launch evidence | **Missing** | The latest authoritative source-bound gate is the inherited `ac664112` NO-GO at 18/100, not a fresh run for this dirty source. None of five required external artifacts currently passes, and current source has no passing live hosted-policy exact-body verification; the last live probe targeted an older source body and failed its comparison. |

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
| Goal read → auto-prescribed drill | **Proved locally** | At `ab5b6aaa`, the safer supported-domain contract is a full comparable proof rep rather than a mini-drill that cannot enter the existing outcome ledger. `GoalOutcomeRead` selects one style-compatible goal-weighted deficit and its exact rubric proof test. `SessionFinalizer` supplies that read to `NextActionEngine`, where severe evidence, persistent blocker, and a continuing durable case retain priority. Eligible targets route to Timed or Pressure Drill; locked pressure safely falls back without goal credit. Summary attributes only a goal-winning action with exact goal, dimension, proof, and source session. This does not implement the report's public numeric score or wider destination inventory. |
| Prescribed drill → rep review → rewritten example | **Proved** | Existing routing, Review, evidence-gated rewrite, comparison, and Phrase Bank create this local loop for supported goals and evidence. |
| Rewrite → next micro-goal → weekly progress | **Proved** | A saved phrase can seed Timed immediately or be explicitly attached by ID to the active week of the existing four-week `ForwardPlan`, which remains the focus/mode/target/rationale/progress owner. The write is plan-ID bound, deleted/unsafe links fail closed, and Home resolves the current-week phrase into the existing transient Timed handoff. The focused iPhone 17 Pro simulator test now renders the assigned Home action, launches Timed, and asserts the exact saved line. Account binding and exact-once consumption remain separately proved by pure handoff contracts; physical-device persistence remains QA. No second weekly or phrase-text owner was added. |

## Recommendation and deliverable matrix

### 1. Goal-style scoring

| Report requirement or output | Classification | Current implementation and exact gap |
|---|---|---|
| Reuse onboarding/profile goal ownership | **Proved** | Optional `chosenStyleGoal` stays in `CoachingProfileStore`/draft and is the only style value projected into behavioral coaching. `speakingStyleGoal` remains compatibility storage; no parallel goal store was added. |
| Preserve explicit choice provenance | **Proved** | Profiles that predate the `chosenStyleGoal` key decode with no chosen style instead of inferring consent from a historical default. Goal rubrics, scoring/copy enrichments, AI/cache inputs, plans, proofs, and post-rep notes fail closed or filter incompatible provenance. |
| Support `authoritative`, `concise`, `humorous`, `warm`, and `calm` | **Incomplete** | Canonical goals are authoritative, warm, concise, persuasive, executive, and storytelling. Humorous and calm are deliberately absent; tests pin that absence. |
| Compute a public 0–100 style score for every session | **Contradicted** | The product deliberately exposes `GoalOutcomeRead` as qualitative evidence/movement. `GoalStyleCalibrationCandidate` can produce a versioned 0–100 candidate only for access-controlled professional calibration and is explicitly disconnected from product views, stores, analytics, sessions, and export. Its result gate requires complete two-reviewer professional coverage, exact rubric shape, and reviewer-bound evidence-access receipts; that integrity contract is not a calibration result. |
| Professional goal-style review intake integrity | **Proved locally** | At `a5d5c365`, 14/14 focused simulator tests prove that empty, partial, non-independent, wrong-role, malformed, and cross-reviewer receipt-reuse submissions cannot pass; complete independent negative judgments remain structurally valid evidence. The artifact-dump XCTest emits a 12-case packet with the strengthened schema and no raw transcript field. No evidence package or reviewer result exists. |
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
| Goal plus latest breakdown drives one best next rep | **Proved locally** | At `ab5b6aaa`, the latest quantity-qualified `GoalOutcomeRead` enters the existing finalizer-owned action cascade. One deterministic, style-compatible, goal-weighted deficit and its exact rubric proof select a full comparable Timed or Pressure rep only when the explicit style matches, the overall and dimension evidence are established, the latest session qualifies, the target is recognized and still below its proof bar, and movement is not mixed. Severe evidence, persistent blockers, and continuing durable cases win first; diagnose/adapt case states do not repeat. The finalized action alone carries goal/dimension/source/proof provenance into Summary. Non-goal actions write no goal attribution, historical goal-only rows cannot create movement, and unavailable pressure proof falls back without false credit. Focused 38/38, related 78/78, and full 4,114-test regression pass. This proves local selection and attribution for the existing supported domain, not outcome benefit, wider destinations, deployed persistence, or production effectiveness. |
| Up to two alternatives | **Contradicted** | Noum deliberately renders exactly one best next rep. `NextAction` retains one optional internal secondary for older decision paths, but `SummaryPrescriptionProjection` does not expose an alternatives menu. Because “up to two” permits zero, this does not block the one-action research outcome; it records an intentional product-contract choice against simultaneous alternatives rather than an implementation gap. |
| Route across Timed, Sudden Death, Ah Counter, Cut the Crutch, pace, roleplay, Lessons, Projects, and Path | **Incomplete** | The engine can return existing mini-drills and the four `PracticeMode` values (Timed, Sudden Death, Ah Counter, IM conversation). Separate Roleplay curriculum, Lessons, Speech Projects, and Path are not prescription destinations. Speech Projects are now independently executable: a stable catalog ID resolves into Timed with its curated prompts and project duration contract, but that does not make Projects an adaptive recommendation destination. |
| Short coach-voice rationale | **Proved** | Action reason, wider evidence, and confidence are kept distinct and duplicate copy is suppressed. |
| Home/Train card and deep link | **Incomplete** | Summary renders and deep-links the finalizer-owned action. At detached source commit `eb597589`, focused UI tests mounted the real Home and Train surfaces from the `plateauedAdvanced` profile, verified their exact Filler Control prescription and 44-point actions, followed both into `ahCounter.screen`, and read the existing account-local flow log back as one correlated `prescription.shown` / `prescription.accepted` pair at 100%. Exposure still waits for a settled selected-tab projection, so retained off-tab Home and Train's transient initial blueprint cannot create false denominators. A recommended Begin tap now records the exact captured visible exposure synchronously before the live capability result is classified. An exact displayed/launched mode match then records acceptance; Pressure or IM capability loss records shown only, does not arm Quick Start, and remains unfollowed. Same-fingerprint shown writes are idempotent, and Train's Adjust/alternate actions remain excluded. The current rendered Train lane additionally presents Pressure Drill at Accessibility XXXL, removes Pressure only at tap, reaches manual Timed setup without a stale demand or automatically mounted prompt, and retains shown at exact 0% with no accepted event. At `77b1361a`, a serial seeded Train UI contract additionally renders the exact `Medium · 30 sec` Timed demand and reaches the real Timed prompt; pure route/adherence tests prove that this Begin path carries the same difficulty into the outcome ledger. Home and Train continue to reuse `RecommendationLearningStore`, `FlowEventLog`, `NextActionModeAvailability`, and the established router. This row remains incomplete because Roleplay, Lessons, Projects, Path, pace, and the rest of the report's wider destination catalog lack one rendered prescription contract. |
| Availability/locked-mode fallback | **Proved** | Summary, Home, Train, Prep, both Ask Noum recommendation paths, and the defensive router consume the shared rating/IM availability contract. Pure tests cover coherent projection values, suppressed stale setup/evidence/confidence, retained established IM focus/target, safe tap-time loss, no false acceptance, and the no-upgrade invariant for a mode that already rendered as Timed. Prep-specific rendered coverage preserves planned rehearsal identity and exact category-only fallback prompts. The current Train and Summary lanes prove the stronger after-render Pressure branch: each visible recommendation can lose Pressure at tap, reach default manual Timed setup with no stale demand or automatic prompt, retain shown-only attribution, and avoid acceptance. Summary additionally clears a pre-armed interrupted regular-mode Quick Start and carries the exact rendered projection through attribution. Rendered Home loss, rendered Conversation loss, physical capability transition, and the report's wider destination catalog remain outside this proof. |

### 4. Fast-lane first session

| Report requirement or output | Classification | Current implementation and exact gap |
|---|---|---|
| Ask only one goal and one context | **Proved** | Fast lane collects a bounded communication context and challenge, then opens a permissionless structured rehearsal. |
| Initial rep in under 60 seconds | **Contradicted** | The timed UI contract proves a structured first-value result under the target, not a spoken `PracticeSession`. Code and tests explicitly prevent that receipt from counting as a rep, speech evidence, progress, or reward. |
| Do not require live voice permissions | **Proved** | The structured path requests no microphone or speech permission and explains the spoken upgrade. |
| No auth dependency | **Contradicted** | No login credential or network round-trip is required for first value, but `FirstRunOnboardingGate` waits for a durable guest/account identity before routing. The product does not create anonymous unowned persistence. A `local-guest-*` identity remains the immediate local owner and is ineligible for remote reads/writes until a later, non-blocking anonymous-Firebase promotion succeeds. The new promotion route improves later Ask availability; it does not turn initial routing into an auth-free ownership model. |
| Deferred, resumable full-profile capture | **Proved** | `CoachingProfileDraft` and `FirstRunOnboardingGate` preserve the structured receipt and resume the established onboarding/consent/spoken path. |
| First-rep completion marker | **Contradicted** | `FirstValueReceipt` distinguishes `.structuredText` from `.spokenTimed`; only a persisted session counts as the first spoken rep. The fast lane writes a first-value marker. |
| Returning users skip fast lane | **Proved** | A completed profile remains the sole completion truth, and account-scoped gate/receipt tests cover reload and reset behavior. |

### 5. Offline transcription fallback

| Report requirement or output | Classification | Current implementation and exact gap |
|---|---|---|
| Local `TranscriptionProvider` | **Proved** | `LocalSpeechProvider` uses `SFSpeechRecognizer`, forces `requiresOnDeviceRecognition`, and fails rather than silently using Apple's server recognizer. |
| Cloud/privacy selection policy | **Proved** | Release consent-off constructs only local. Consent-on constructs bounded Deepgram-to-local automatic startup routing. DEBUG provider selection remains separate from the Release policy. |
| Persisted cloud-disabled choice | **Proved** | The existing `AISettingsManager` consent owner persists the choice and production construction tests prove no cloud route when it is off. |
| Automatically fall back for missing credentials/network/cloud | **Incomplete** | Setup failure can fall back before audio begins. At `c44bd91c`, Mini-drills and Lesson Apply now wait for that readiness and require terminal receipts, so failure cannot consume their clock or create XP/history/lesson progress. Once either provider starts, a mid-rep failure still stops honestly and offers retry; audio is never replayed to a second provider. The report's broad runtime failover promise is intentionally narrower. |
| Graceful failover banner | **Proved locally** | At `c3e018d4`, requested-cloud/resolved-local startup produces one shared content-free, accessibility-labelled notice across all nine speech surfaces: Timed, Pressure, Ah Counter, IM, Cut the Crutch, Pace Training, Roleplay, Mini-drills, and Lesson Apply. Deliberate local use and successful cloud stay quiet, and a new route clears stale notice state. The nine-surface source contract plus provider-semantic tests pass. No real provider failure was forced during the light simulator sweep, so rendered physical-device/TestFlight presentation, VoiceOver announcement, and reduced-motion behavior remain external proof. |
| Helpful unsupported-locale state | **Proved locally** | The current working tree preserves the exact configured locale from `LocalSpeechError.onDeviceRecognitionUnavailable` as a typed recognizer-owned issue while arbitrary provider detail remains collapsed. A DEBUG-only equivalent provider fixture drives the real Timed lifecycle at a deterministic `en-US` locale. The Accessibility XXXL + Reduce Motion UI lane proves a specific offline-language headline, exact locale/device explanation, Settings/device guidance, no futile retry or inactive End Session control, and a hittable Back to setup action that clears the issue. Focused speech/lifecycle verification passes 41/41 and the rendered lane passes 1/1. Real `SFSpeechRecognizer` model availability, manual VoiceOver announcement, physical-device behavior, and TestFlight remain unverified. |

### 6. Privacy and consent centre

| Report requirement or output | Classification | Current implementation and exact gap |
|---|---|---|
| Explain what leaves the device, stays local, and is excluded from export | **Proved locally** | Settings privacy disclosure and `YourDataView` describe cloud/on-device routing, processors, export ownership, Keychain/Photos/provider exclusions, and cleanup. Processor manifest v7 includes account-scoped coaching-content sync and states that identity creation alone does not authorize upload. Exact published/persisted consent equality and the content-sync lease enforce that source policy locally. The new journal stores only document identity, local revision, and mutation UUID; profile/session content remains in existing account stores. Journal metadata participates in account export/deletion and is discarded as derived bookkeeping during guest promotion. Hosted byte equivalence and user comprehension remain unproved. |
| Cloud transcription on/off | **Proved** | The existing consent control changes Release provider construction and revocation behavior. |
| Export ZIP entry point | **Proved** | `AccountDataExportServiceTests` validate manifest/data entries, exclusions, CRC-readable ZIP output, safe paths, and cleanup. |
| Account deletion entry point | **Proved** | The account card shows deletion only when signed in, requires typed confirmation, and routes through the existing callable contract. |
| Account deletion admission, stale-token fence, and recovery | **Partially proved locally** | The current source makes one Keychain-backed schema-v2 account/provider/request/phase record authoritative across relaunch and sign-out. Ask Noum replies/auxiliary calls, Forward Plan admission/registration/transport, and recommendation local/backend sync close and revalidate against it. Settings exposes phase-safe retry, local-cleanup-only, or support-only recovery. The checked callable binds expected account identity to verified Firebase auth, and a minimal completed server marker with an expiry two hours after completion keeps Firestore private writes denied until TTL deletion, beyond the declared one-hour stale-token window. Success requires exact marker finalization; exact duplicates preserve the marker, while mismatch, malformed state, and finalization failure fail closed. The 28/28 emulator gate proves a cached token receives 403 and directly exercises the every-15-minute stale-pending reconciler replaying the full deletion worklist with Auth present or absent. Focused iOS is 70/70, adjacent regression is 55/55, final frozen-source policy/recovery is 23/23, full unsigned unit is 4,402 unique tests / 4,421 executions, Functions unit/deploy-lock are 115/115 + 7/7, and the cloud-operations validator is 18/18. Functions, scheduler identity, rules, index, and TTL are undeployed; live scheduler/TTL behavior, a durable completion receipt/unauthenticated post-Auth recovery route, other backend-work audit, signed device behavior, and external evidence remain missing. |
| Notifications/privacy summary | **Proved** | Both are present in Settings, using existing notification and consent owners. |
| Transient Timed prompt isolation | **Proved** | `TimedPracticePromptHandoff` keeps one bounded prompt in process, binds it to the active account and exact opaque route token, consumes it once, and clears it during account teardown. A mismatched token cannot steal a newer prompt; navigation carries no user text/account ID, and the former unscoped prompt/word defaults keys are purged rather than migrated. App termination naturally drops the in-memory value. |
| A single `PrivacyCentreView` | **Contradicted** | The user-facing trust story deliberately stays within the established Settings privacy card, Your Data, Account, and Notifications owners. A new named centre would duplicate navigation and state ownership without adding a missing control. |
| A new `PrivacyPreferencesStore` | **Contradicted** | Creating it would duplicate `AISettingsManager`, notification state, auth/account state, and export/deletion ownership. The architecture correctly extends the existing owners. |
| Copy verified against live production behavior | **Weak evidence** | Code and processor-manifest contracts align locally. Superseded audit/remediation/execution documents are explicitly marked historical and source-guarded so they cannot masquerade as current operations. The narrow hosted probe still proves only reachability—not an exact manifest-v3 body match, production processor behavior, App Store privacy disclosures, or a signed build. |

### 7. Remaining roadmap opportunities

| Opportunity | Classification | Current implementation and exact gap |
|---|---|---|
| Multi-language expansion beyond en-US/es-ES/fr-FR | **Missing** | UI/provider locale plumbing covers those locales, while AI rewrite and goal calibration fail closed outside their supported English contract. No calibrated new locale corpus exists. |
| Weekly habit/streak coaching organised around one speaking goal | **Proved** | The persisted `ForwardPlan` provides four weekly focuses, modes, targets, rationales, and derived progress alongside streak protection and check-ins. Weekly digest copy is goal-specific only when `chosenStyleGoal` is present and otherwise stays generic. A saved rewrite can be explicitly attached by ID to the active week and launched from Home through the account- and route-bound Timed handoff without duplicating phrase text or weekly state. Async plan generation is locally leased to the exact loaded account, source input, provider authorization, and latest intent. Provider-visible recent filler and baseline comparison mechanics now pass the current quantity/confidence/schema/fixture boundary; focused metric checks pass 7/7 and the combined related selection passes 134/134. First-plan generation is source-reachable after three eligible reps through Profile → Library → Coaching evidence → Coaching direction, but that route is deeply buried; Home suppresses `.prompt`, Ask Noum has no dedicated entry, and rendered discoverability remains unproved. Real cohort effect remains unproved. |
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
| PR-1 | High filler burden chooses Ah Counter or Sudden Death | **Proved** | At `c3d1ff65`, qualifying high filler burden became duration-normalized: 10/600 does not enter the severe path, 3/20 does, count/duration floors fail closed, and filler retains priority over simultaneous severe pace. At `ec10990f`, that severe path selects Ah Counter (`Filler Control`) and no longer emits a generic filler mini-drill or Sudden Death. The finalizer permits this directly observed severe prescription on the first qualifying rep while continuing to suppress non-severe adaptive claims on thin evidence. Focused destination/boundary/context tests pass 93/93; the full unit target passes 4,065 tests with zero failures or skips. This proves the literal local route, not professional threshold calibration or outcome benefit. |
| PR-2 | Pacing issues choose pace training | **Incomplete** | Severe, persistent, declining, and new pace evidence can select an existing `.paceControl` focused mini-drill; supported Home/Train pace trends project to Timed with a pace instruction. At `4da56e3e`, the immediate severe branch requires the shared 15-second / 20-word quantity floor and finite WPM, so a short or non-finite first rep cannot create that prescription and established evidence still falls through. At `8e7af9d9`, standalone Pace itself now awaits the terminal provider receipt and recorder-owned duration, requires the shared three-word / three-finite-second progress floor, withholds result/XP for thin speech, and preserves the exact live sampled result for eligible speech. No adaptive route selects that standalone destination, and it still writes neither `PracticeSession`, drill history, recommendation outcome, nor comparable response evidence. Routing there without first adding durable attribution would weaken the observe/adapt loop. |
| PR-3 | Interpersonal-pressure goals bias toward Roleplay | **Missing** | The established engine can route IM conversation, not the separate Roleplay curriculum requested by the report. |
| PR-4 | Locked modes fall back gracefully | **Proved** | The shared four-mode matrix covers locked-at-render and capability-lost-at-tap paths without stale setup/copy/confidence or false acceptance. Prep adds stable planned-shape identity, honest fallback copy/setup, no false readiness credit, no capability-return upgrade, and a route-bound, category-only prompt for unavailable pressure/audience shapes. The 2026-07-14 simulator UI test proves the locked Prep route. Current Train and Summary UI lanes separately prove Pressure can render as available and then fail closed at tap to manual Timed setup with no stale demand, automatic prompt, or accepted event; Summary additionally clears interrupted regular-mode Quick Start and keeps the exact rendered exposure identity. This is not physical-device/TestFlight evidence, and a matrix for the report's broader destination catalog still does not exist. |
| FL-1 | Fresh install reaches a first rep without auth | **Contradicted** | It reaches structured first value without login credentials, after durable guest identity. A local fallback identity can persist and relaunch without remote traffic, but it is still an identity and typing is still not claimed as a spoken rep. |
| FL-2 | Denied microphone does not dead-end | **Proved** | The written rehearsal path is permissionless, and upgrade routing is separately tested. |
| FL-3 | Completed first rep resumes full onboarding later | **Incomplete** | Structured first value resumes prefilled full onboarding and later spoken practice, including across a signed simulator relaunch with a durable local guest. The literal initial spoken-rep case is not the fast-lane contract. |
| FL-4 | Returning users do not see fast lane again | **Proved** | Completed profile precedence and account-scoped gate behavior are tested. |
| TR-1 | Missing AWS credentials still allows local practice | **Proved** | Local construction has no AWS dependency. The premise is stale because AWS is not the Release primary. |
| TR-2 | Cloud-disabled preference persists | **Proved** | Existing consent persistence and no-cloud construction tests pass. |
| TR-3 | Switching providers does not break filler detection | **Proved** | A focused provider-neutral contract passes equivalent local, Deepgram, Google, and AWS transcript updates—with deliberately different provider filler hints—through the production `handleTranscriptUpdate`/semantic-highlighting path and asserts identical transcript, count, and highlighted output. This proves between-route behavior locally; the product intentionally does not switch providers mid-audio-stream. |
| TR-4 | Unsupported locale shows a helpful message | **Proved locally** | The exact device/locale-specific error reaches a typed recognizer-owned issue while arbitrary provider detail stays hidden. A deterministic equivalent local-provider failure passes through Timed Practice at Accessibility XXXL with Reduce Motion and renders an offline-language explanation, exact locale, Settings/device guidance, no dead retry/stop actions, and a real Back to setup transition. Focused speech/lifecycle verification is 41/41 and rendered verification is 1/1. Hardware model availability, manual VoiceOver, physical-device, and TestFlight evidence remain missing. |
| TR-5 | Failed supplemental capture cannot create progress | **Proved locally** | Standard/framework mini-drills, Beat the Brake, Land the Pause, PREP Stack, and Lesson Apply all await capture readiness/finalization and use recorder-owned duration before progress. Mini-drills require the shared three-word / three-finite-second floor and a durable account-scoped versioned receipt before history, XP, reward, baseline, streak, or result presentation; PREP also enforces its declared 28-word success floor. Lesson Apply preserves authored 10/14/18/20-word criteria, adds a visible 12-word floor to six quantity-free lessons, requires at least three finite seconds, and binds transcript-free completion evidence to the exact concept/spot/apply outcome before lesson progress or XP. Malformed/duplicate receipts and malformed lesson outcomes fail closed. The current related mini-drill speech/history/account selection passes 48/48, and representative standard insufficient/eligible rendering passes 2/2 at Accessibility XXXL from a simulator configured with Reduce Motion. Lesson Apply passes 44/44 with its two rendered branches also green at 2/2. Specialized mini-drill live metrics, microphone interruption/provider timing, and physical-device behavior remain unproved. |
| PC-1 | Cloud toggle changes provider selection | **Proved** | Production consent-on/off construction is directly tested. |
| PC-2 | Export creates and cleans up ZIP | **Proved** | `AccountDataExportServiceTests` verify the real temporary ZIP and its deletion. |
| PC-3 | Deletion entry point visibility follows account state | **Proved** | Focused UI tests render both branches of the existing `authManager.isSignedIn` owner: the durable local guest/account path exposes `settings.account.delete`, while explicitly signed-out Settings exposes login and no deletion control. Local-guest deletion intentionally performs local teardown without making a remote deletion call; this row does not prove Firebase deletion. |
| PC-4 | Privacy summary copy matches actual behavior | **Weak evidence** | Processor manifest v4 and generated disclosures now cover the disabled bounded competitive PCM path, Firebase-to-Deepgram routing, transcript-free storage, account deletion, and the fact that expiry is not automatic deletion without externally configured Firestore TTL. Local routing/manifest contracts match that copy, and superseded privacy documents are visibly quarantined by a source test. Production TTL, processor behavior, hosted-policy body, App Store disclosure, and signed-device behavior were not independently verified. |

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
| Session-review open rate | **Proved** | **Missing** | Account-local eligible-session/review-open counts exist. In the current working tree, the numerator is a set of unique `review.sessionOpened` correlations intersected with progress-eligible session IDs, so duplicate, thin, and foreign legacy events cannot inflate the rate. No population aggregation exists. |
| Prescriptions accepted rate | **Proved** | **Missing** | Exposure ownership sits on the rendered Summary/Home/Train surfaces. The shared tap-attribution policy records the exact captured visible prescription as shown before classifying the live route, then records acceptance only when the displayed mode is the mode actually launched. Pressure/IM capability-loss tests prove fallback contributes shown only; existing outcome tests keep that rep unfollowed. Source-bound Home/Train accepted-path UI coverage produces content-free correlated shown/accepted evidence. The current Train and Summary Pressure loss-at-tap captures each read back exact 0% acceptance with `prescription.shown` and no `prescription.accepted`; Summary also proves a fast fallback cannot lose the denominator and clears an interrupted regular-mode Quick Start. No population result or physical-device run exists; rendered Home and Conversation loss remain unproved. |
| Notification opt-in after first value | **Proved** | **Missing** | Decisions before value are excluded and the local conversion signal exists. |
| D1/D7/D28 retention | **Proved** | **Missing** | Account-local active-day return anchors exist; there is no retention cohort. |
| Cloud-to-local fallback rate | **Proved** | **Missing** | Only cloud-requested routes resolved locally enter the denominator; deliberate local sessions are excluded. |
| “Did Noum help you move toward the speaker you want to be?” after at least three reps | **Proved** | **Missing** | Exact localized copy and one-shot behavior are present and tested. At `8ec313c9`, Profile uses only progress-eligible reps. The current Accessibility XXXL fixture renders five raw saved rows but only two eligible reps, keeps the question withheld, and uses neutral starting-point copy. No collected real-user result is staged. |

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

Source binding matters here. The `40d5e903`, `47cbab5f`, and `80fbf6d2` rows
remain valid historical evidence for their named baselines. The current
canonical artifact is bound to clean evidence-tooling commit `70b0b380` and
coach fingerprint `sha256:7f99e3f…e689e380`; the complete signed regression and
optimized Release scan remain valid at the unchanged-app boundary `7ae1fe43`.
Historical results are not treated as proof for later behavior.

| Evidence item | Classification | Result |
|---|---|---|
| Recorded full integrated Swift regression | **Proved** | At clean commit `47cbab5f`, the result bundle passed 3,946 tests across 411 suites with zero failures or skips. The run used the local Swift package cache, disabled automatic package resolution and code signing, and removed provider credential variables. One transient parallel-clone launch rejection was retried by Xcode; the final result is Passed with the complete count. The unsigned optimized Release simulator build also succeeded from the same detached source boundary. |
| Current full integrated Swift regression | **Proved** | At clean implementation commit `7ae1fe43153f76c682f8a2d909842632cdcb4410`, `/private/tmp/NoumProductionClosureSerial-7ae1fe43-20260714T105310Z.xcresult` completed the signed serial scheme with 4,061 tests, zero failures, and zero skips. Xcode's phase output records 3,989 unit tests across 411 suites and all 56 UI tests passing, with no clone loss. The run used a unique DerivedData directory, the populated offline Swift package cache, disabled automatic package resolution, and removed provider credential variables. Its deterministic result-bundle file rollup is `f6aa4bf32c25ce661ab10c6f8837a8eb5328655f90bd7212be09e92bab0d3c21`. The same detached commit passed the optimized Release simulator build and `release-scan-app-bundle.sh`. This is clean local simulator/build evidence, not physical-device, deployed-backend, or external-provider proof. |
| 2026-07-15 working-tree unit regression | **Proved locally at that boundary** | In the exact-session Summary and premium Coach Read working tree captured on 2026-07-15, the complete unsigned simulator `NoumTests` target passed 4,320 unique tests / 4,339 device executions with zero failures or skips (`.build-roleplay-terminal/Full-NoumTests-Commit-final2-20260715.xcresult`). The generated Coach Read/shared regression lane passed 56 unique tests / 58 device executions (`.build-roleplay-terminal/Focused-GeneratedCoachRead-Commit-final2-20260715.xcresult`). The preceding Summary selection was 58/58, Review/history/post-rep/AI metric selection was 92/92, and earlier rendered recommendation, mixed-history, mini-drill, Lesson Apply, and unsupported-locale evidence remains recorded in their rows. The unsigned Release simulator build succeeded at that boundary. This historical row is not evidence for the current dirty Ask source and does not supersede the clean signed full-scheme, optimized Release scan, complete UI, manual VoiceOver, physical-device, deployed-backend, or external evidence gates. |
| Rendered mixed Review-only history | **Proved locally** | `.build-roleplay-terminal/Logs/Test/Test-Noum-2026.07.15_review-history-ui-final2.xcresult` passes 2/2 on an iPhone 17 Pro / iOS 26.5 simulator at Accessibility XXXL from a base simulator configured with Reduce Motion. Five durable finite rows remain visible and searchable, but only two drive Review/Profile evidence and the 6.5 All Reps average. The thin row and detail show neutral `Saved capture` / `Not measured` provenance, no stored 10/10 or praise headline, and no coaching cards; exact prompt, replay, transcript, deletion, and export ownership remain raw. Five passing attachments were visually inspected and retained in `.screenshots/2026-07-15_review-only-history-rendered/verified/`. Non-finite/evaluation cases are unit-only, Sudden Death's independent legacy run ledger is not reconciled, and the shared progress floor is not every mode's stricter metric floor. |
| Rendered unsupported-locale recovery | **Proved locally** | `/tmp/noum-unsupported-locale-ui-actionable-rm.xcresult` passes 1/1 on an iPhone 17 Pro simulator. The real Timed setup/start path receives the typed local-provider fixture at deterministic `en-US`, renders the specific actionable issue at Accessibility XXXL with Reduce Motion enabled, exposes neither generic retry nor inactive End Session, and returns to pristine setup through the identified recovery action. The retained attachment was visually inspected. `/tmp/noum-unsupported-locale-ui-generic-regression.xcresult` separately keeps the established generic provider-failure path green at 1/1. These fixtures bypass hardware speech-model availability and are not manual VoiceOver, physical-device, signed Release, or TestFlight proof. |
| Rendered standard mini-drill completion | **Proved locally** | `.build-roleplay-terminal/Logs/Test/Test-Noum-2026.07.15_11-48-52-+0100.xcresult` passes 2/2 on an iPhone 17 Pro simulator at Accessibility XXXL from a base simulator configured with Reduce Motion. The insufficient fixture supplies a usable two-word terminal receipt and proves the production disposition returns to Ready with exact quantity guidance, a hittable Start drill action, and no result/XP. The eligible fixture supplies 12 terminal words over 12 recorder-owned seconds and can render the exact zero-filler Clean Run, nonzero XP, and Done-to-Summary transition only after Summary inserts the account-owned verified receipt. Both captures and a seeded light five-tab sweep were visually inspected; the handoff is `.screenshots/2026-07-15_mini-drill-rendered-completion/HANDOFF.md`. This is representative standard/framework evidence only: it bypasses microphone/provider timing and does not render specialized live WPM, pause-lock, or PREP-step metrics, manual VoiceOver, physical-device, signed Release, or TestFlight behavior. |
| Selected pre-baseline Swift product/test contracts | **Proved** | At `40d5e903`, focused simulator tests passed for goal calibration/outcomes, rewrite, Phrase Bank, prescription, fast lane, local speech, privacy, KPI, and experiment contracts. They remain valid for that named source boundary, not as a substitute for the final full run. |
| Post-baseline explicit-style, weekly-copy, mode-availability, and coach-provenance contracts | **Proved** | The explicit-style trust-boundary run passed 238 tests with zero failures, the weekly digest goal-copy suite passed 4 unique tests with zero failures, and the final integrated availability run passed 69 tests across `NextActionAvailabilityTests`, `PrescriptionProjectionTests`, `SummaryLookingAheadRouterTests`, `AskNoumModeSuggestionTests`, `NextActionEngineTests`, and `HomeCoachCardVariantTests`, with zero failures or skips. The availability matrix exhausts all four modes × four capability snapshots × live IM states. The regression-repair run passed 219 tests across seven suites and the style-aware evidence boundary passed 112 tests across three suites. App-path rows carry an explicit styled, neutral, or unknown semantic expectation. Styled turns require a passed gate and typed assessment; known neutral turns require `notEvaluated` without typed assessment; unknown IDs fail closed. The 25 supplemental arena scenarios are explicitly neutral at construction, so missing fixtures cannot silently inherit neutrality. Fabricated/default voice telemetry remains rejected. The refreshed commit-bound report preserves this contract with 23 styled, 27 neutral, and zero invalid selected traces. |
| Rendered account-visibility contract | **Proved** | The focused `testSignedOutSettingsPresentsAccountOptions` and `testPermissionlessFirstValueStaysStructuredAndDefersSetupToHome` UI runs passed on the iPhone 17 Pro simulator with its normal local test-signing path. The newer signed local-guest onboarding/relaunch run passed 2/2 and preserved the same durable account across relaunch without permission/App Check traffic. They prove the deletion entry point's rendered account-state branches and local fallback persistence, not remote deletion success. |
| Durable local-guest persistence boundary | **Proved locally; promotion incomplete** | `AuthManager.shouldSyncBackend` keeps `local-guest-*` as the exact local owner with no remote access. The current source adds a copy-first, three-phase Keychain promotion journal to a newly created anonymous Firebase UID, exact account-data conflict checks, target-authoritative post-commit recovery, self-challenge rebind, and explicit exclusions for remote/derived/unattributed/recording data. The backend seed snapshot is restricted to that pending newly minted empty target, enters the ordinary durable journal lane, and uses exact request ownership; this does not imply a general existing-target merge. Anonymous guests cannot sign out and strand the credential. Same-UID secure-session loss, Apple/Google link success before provider persistence, existing-target merge, physical kill/relaunch, and deployed anonymous-provider configuration remain unproved. |
| Rendered active-week phrase execution | **Proved** | On 2026-07-14, `testActiveWeekPhraseLaunchesExactPromptFromHome` passed on the iPhone 17 Pro simulator and retained an attachment of the exact saved line in Timed's thinking phase. The same 19-test focused run passed `ForwardPlanPhraseHandoffTests`, `PhrasePracticeIntentTests`, and `TimedPracticePromptHandoffTests`, including account binding and exact-once consumption. This is simulator/source evidence, not physical-device, TestFlight, or longitudinal outcome evidence. |
| Rendered Prep availability fallback | **Proved** | On 2026-07-14, a combined 23-test focused run passed the real locked-shape Prep UI flow plus `PrepSessionAvailabilityTests`, `TimedPracticePromptHandoffTests`, and `ReleaseIdentityPrivacyTests`, with zero failures or skips. Retained attachments `prep-locked-shapes-timed-fallbacks` and `prep-pressure-fallback-exact-timed-prompt` were visually checked after the readiness-copy correction. They prove honest planned-shape status, Timed fallback actions, a 44-point target, and the exact category prompt at the destination on the iPhone 17 Pro simulator—not physical-device or TestFlight behavior. |
| Rendered recommendation ownership and capability loss | **Proved** | At detached implementation commit `eb597589`, Home and Train each rendered Filler Control, exposed a 44-point action, reached `ahCounter.screen`, and retained a 100% correlated shown/accepted diagnostic. The later Train Pressure lane proved available-at-render/unavailable-at-tap fallback to default manual Timed setup at Accessibility XXXL. The current working-tree Summary lane carries the exact finalized action and rendered projection into attribution, rechecks the complete live capability snapshot, clears an interrupted regular-mode Quick Start on fallback, and preserves shown without acceptance. Its focused branch passes 1/1; all five current recommendation UI tests pass together, including normal Home/Train acceptance, Train/Summary Pressure fallback, and exact Timed demand. Focused logic passes 23/23, and eight current captures in `.screenshots/2026-07-15_summary-capability-loss/` were visually inspected. This proves rendered Train and Summary Pressure loss-at-tap plus normal Home/Train ownership. It does not render Home capability loss, Conversation Practice loss, the wider destination catalog, physical-device behavior, population effectiveness, or TestFlight behavior. |
| Rendered Speech Project execution | **Proved** | At implementation commit `47cbab5f`, the focused routing and project-duration contracts passed together with `FocusedPracticeSetupUITests.testFocusedSetupIdentifiersSelectionTraitsAndTabBarHiding` on the iPhone 17 Pro simulator. The rendered `noum://projects/ice_breaker` route retained the catalog ID in Timed, exposed its project cue and begin control, hid the tab bar, and showed the aligned four-to-six-minute contract. The light five-tab sweep and project frame in `.screenshots/2026-07-14_speech-project-execution/` were visually checked. This proves local catalog-to-practice execution, not adaptive prescription, per-project longitudinal progress, physical-device behavior, or TestFlight behavior. |
| Recommendation outcome attribution | **Proved** | `0da19af1` established explicit acceptance plus matching-mode attribution. At the detached clean `f1d6ec72` boundary, 75 focused simulator tests passed across `GoalOutcomeLoopTests`, `RecommendationResponseAnalyzerTests`, `RecommendationAdaptationAnalyzerTests`, and `TransformationKPIReportTests` with zero failures or skips. They additionally prove bounded persisted-demand comparison, unique-session floors, evaluator/outcome schema rejection, normalized filler polarity, focus-matched pace/filler judging, legacy fail-closed behavior, and KPI gating. At the detached clean `488f8040` boundary, all 54 `CoachMemoryEngineTests` passed with zero failures or skips. They prove that case status admits only exact accepted comparable session IDs, rejects duplicate/missing/future/pre-prescription/wrong-focus/legacy/target-metric-missing evidence, uses fillers per minute, rebuilds legacy criteria, and keeps target-aware success bars stable. The seeded light five-tab sweep in `.screenshots/2026-07-14_comparable-recommendation-evidence/` was visually checked for the earlier response contract; it does not prove this case-state logic, the lower DEBUG diagnostic, or population effectiveness. |
| Exact executed practice demand | **Proved** | At detached clean `ea7a3845`, Functions lint and all 67 Node tests passed. A fresh iPhone 17 Pro simulator build passed 43/43 focused tests across `PracticeSessionDemandTests`, `GoalOutcomeLoopTests`, and `AccountDataRegistryTests`; result bundle `/private/tmp/NoumExactDemand-ea7a3845.xcresult`. They prove current/legacy codecs, exact Timed/Pressure/Project comparison, comparison-schema v2 fail-closed behavior, intent-copy retention, and account-isolated export/deletion. The canonical local `demo-noum` Auth/Firestore/Functions emulator gate later passed all 22 integration tests at clean `bbd040b5`, including the private-session mode/demand allow/reject matrix. The current dirty audit then found that current schema-2 payloads were nevertheless rejected because source rules admitted only schema 1. Source now admits known schemas 1 and 2 and rejects unknown schema 3; updated emulator coverage proves that matrix locally. The light screenshot sweep was blocked by the simulator account-bootstrap recovery surface and does not visually prove the share-card label. This remains local source/emulator evidence, not deployed enforcement. |
| Exact prescribed Timed demand | **Proved** | At implementation commit `d1d25ca6`, `/tmp/NoumExactDemandTests.xcresult` passed 89/89 selected simulator tests with zero failures or skips across exact demand persistence, route projection, tap attribution, reconciliation, availability, and legacy fail-closed behavior. At detached clean source boundary `77b1361a`, Functions lint and all 69 Node tests passed and the unsigned optimized Release simulator build succeeded. `/tmp/NoumExactDemandRouteUI.xcresult` also passed the serial seeded Train contract: it rendered `Recommended difficulty, Medium`, entered the existing Timed prompt, and retained a destination attachment. Commit `7ae1fe43` makes DEBUG trend fixtures replace rather than append to the active account's capped history; its clean complete regression passed the exact Home plateaued→Train plateaued→Train beginner sequence and launched the real Timed prompt with the Medium accessibility value. The light sweep's five ordinary tabs were blocked by account bootstrap; `.screenshots/2026-07-14_prescribed-timed-demand/02_train_seeded_beginner.png` separately verifies the restrained demand capsule. These local contracts do not prove a deployed cross-device ledger, normal-account five-tab routing, physical-device behavior, or population effectiveness. |
| Recommendation sync ordering, hydration, and local CAS source | **Proved** | At detached clean source commit `9378b6ef`, `/private/tmp/NoumRecommendationSyncCommit9378b6ef.xcresult` passed 81 selected simulator tests with zero failures or skips across first-run hydration, recommendation sync, goal outcomes, release identity/privacy, and account-data registry coverage. At detached clean `00dd5975`, Functions lint and 66/66 Node tests passed; `/private/tmp/NoumRecommendationCAS-00dd5975.xcresult` passed 28 focused iPhone 17 Pro simulator tests with zero failures or skips. The newer contracts cover strict legacy/versioned envelopes, expected-revision mutation, exact-body idempotent replay, Unix wire dates, crash-safe persistence ordering, bounded one-shot conflict rebase, direct-write denial, account-scoped cursor/mutation ownership, and fail-closed REST writes. At clean `bbd040b5`, the canonical local `demo-noum` emulator gate passed 22/22 with Node 22.23.1, Java 21.0.11, and Firebase CLI 15.19.1, including concurrent same-revision CAS, migration/replay/conflict, deletion, and direct-write denial. This proves named local source/emulator contracts, not deployed Firebase behavior, runtime IAM/App Check, mixed-client compatibility, or two-device conflict recovery. |
| Current coaching-content upload authority | **Partially proved locally** | Existing consent, account/provider, hydration, lifecycle, deletion/promotion, and Firebase-UID admission remains intact. Ordinary profile, progression, and session writes now synchronously enqueue a metadata-only account journal, drain through one serial account lane, resolve current store payloads, and exact-ack only the pending mutation that completed. Relaunch/hydration, foreground, and consent allow resume pending work. Promotion snapshot work shares this lane, is limited to the proved-empty new anonymous target, and uses exact task ownership; existing accounts no longer receive a blind snapshot. Bootstrap preserves dirty profile/progression/session state, replacement writes clear removed optional fields, and deletion drains active content transport before remote destruction. This remains partial because revisions are not enforced by the server, mixed clients can still last-write-win, startup has no digest repair for the local-persist/enqueue crash window, XP lacks award-event provenance, session deletion lacks tombstones, mutable root provider metadata remains content-writable, and no deployed/two-device evidence exists. |
| Coach-arena contracts at the evidence baseline | **Proved** | 119 Node contracts and 143 Python runner contracts pass. The suite proves default-deny committed and uncommitted source classification, NUL-safe rename/copy/untracked handling, exact generated-output exclusions, no-overwrite sidecar refusal, score/trace/readiness behavior, simulator destination pinning, custom-directory propagation, previous-value restoration, and cleanup after success/failure. The canonical artifact is refreshed and bound to `70b0b380`. These are local tooling and evaluation contracts, not live-provider or human-outcome proof. |
| Custom dump-directory evidence refresh | **Proved** | At clean commit `70b0b380`, the documented evidence-refresh wrapper ran with unique `NOUM_COACH_EVAL_DUMP_DIR` `/private/tmp/noum-coach-eval-70b0b380-20260714T1330Z-b` and emitted both source sidecars plus all five XCTest artifacts into that exact directory. The default dump's deterministic byte rollup remained `4e5344a9f93ad50af55703c37d7a9bfbc18997b85bf69916fffbf38ffeef7033`; source commit/fingerprint matched every trace; app-path preflight, scoring, and readiness consumed the same directory; and the simulator variables and lock were absent afterward. Focused contracts also cover command/boot failure cleanup. This proves local evidence isolation only; it does not create external launch evidence. |
| Release-evidence workflow contracts | **Proved** | 29 tests passed. They prove fail-closed dirty-source binding, full-commit history-scan binding, the exact 14-surface/77-check TestFlight contract, and validator agreement—not that external evidence exists. The final readiness gate revalidates the selected attachment-backed run and requires exact promotion-receipt, source-binding, and four-artifact hash continuity with the active dump. |
| Final external-evidence provenance linkage | **Proved** | Focused readiness/live-evidence tests prove complete external-looking JSON without a release run is rejected, a validated promotion-bound run can pass the linkage, and changed managed-artifact bytes fail closed. The release-workflow integration also proves that changing a registered attachment after promotion invalidates the final linkage. Missing/altered live capture provenance and non-live provider identities are rejected. The embedded live block is an operator provenance assertion, not independently signed cryptographic proof. This proves enforcement behavior only; no external evidence was collected. |
| Legacy endpoint, cloud-probe, and TestFlight preflight contracts | **Proved** | 7 status-only endpoint-probe tests, 4 no-network cloud-probe scenarios, and 31 signing/TestFlight preflight tests passed. The preflight forwards and independently requires the explicit attachment-backed run accepted by readiness. These results prove local tooling behavior only. |
| Current app-path dump preflight | **Proved** | The documented source-bound evidence-refresh wrapper produced 53 conversations/109 turns from detached clean commit `ac664112`. Fail-closed preflight passed with zero blockers or warnings, zero missing trace commits/fingerprints, and exact coach fingerprint `sha256:adfcd7bce86a2e248a923865aa4d014f93ab564670acc42e690585a14cbae2f4`. The harness explicitly supplies no prior case memory rather than reading an arbitrary signed-in simulator account. |
| Committed canonical app-path baseline | **Proved** | The refreshed local canonical report embeds `ac664112` / `sha256:adfcd7bc…cbae2f4`, scores all 50 required fixtures at 79.78, and passes its local score/coverage and trace-shape gates with zero fixture failures or placeholder leaks. It is scripted-gold post-generation wiring evidence: each authored target reply is injected through the pipeline. It does not exercise production generation, Auth/App Check, callable availability, human-coach quality, physical-device behavior, or launch readiness. |
| Ask Noum v2 production capability readback (2026-07-17) | **Partially proved live** | Source-bound commit `86334ed45` added a checked-in two-function release path and deployed only `coachChatV2` plus updated `coachChatAvailability` to `noum-d0b6f` in `europe-west2`. Both read back `ACTIVE`, Node 22, identical source hash `f5c8c1a1b509fb519a749a48b79337357cbf6634`, and the dedicated `noum-coach-runtime` identity. The default build identity has only source-bucket object viewer, regional `gcf-artifacts` writer, and project log writer for this build path; no Editor/Owner grant was restored. The initially missing `coachchatv2` Cloud Run invoker binding was restored without weakening in-handler Auth/App Check. An operator-confirmed installed-simulator retry then recorded HTTP 200, Auth/App Check `VALID`, verified account binding, model generation through `gemini-2.5-flash`, finish reason `STOP`, and visible reply `Hello.` This proves one trivial greeting route, not acceptable coaching quality, mixed-client behavior, rollback, independent review, or production readiness. |
| Ask Noum supported-identity availability | **Incomplete** | The deployed v2 route now completes one installed-simulator greeting with valid Firebase Auth and App Check after the missing Cloud Run invoker binding was restored. The current source uses one service-owned exact remote capability preflight per attempted turn, preserves typed limitation reasons, and requires exact Firebase UID/durable account, hydration, backend eligibility, and deletion-fence authority. A `local-guest-*` owner has one bounded automatic/explicit path to a new anonymous Firebase UID through a journaled exact-data copy. This is not complete identity recovery: lost same-UID Firebase sessions, Apple/Google link-success-before-Keychain, deployed anonymous-provider configuration, and physical/TestFlight relaunch remain gaps. One greeting does not prove those identities, a representative conversation, or acceptable output. |
| Production coaching-policy parity | **Incomplete** | The prior secure path dropped the detailed client prompt. The current source instead sends validated voice, turn depth, turn intent, a typed coaching brief, and short verified proof quotes; it keeps the full transcript local, derives the concise anti-invention/anti-redundancy/trust-repair contract on the server, and returns policy plus generation-mode provenance. Known greetings, off-topic probes, reply preferences, and vulnerable disclosures cannot receive deterministic coaching briefs or short prescriptions; iOS also suppresses its provisional assessment for those turns. A bounded server/client gate removes stored drills from personal explanation and judgement turns that did not request action. When an action-seeking turn deliberately retains the recent intervention, exact or synonym-swapped restatement remains rejected and only a current-evidence-led continuity reference is accepted. Typed proof is bound to the selected rubric dimension and quantity floor, and unclassified hedge semantics stay neutral. Direct evaluations and natural exact-stat requests use personal evidence; action targets and attributed self-reports remain distinct. Bounded latest-rep metrics and exact-comparable longitudinal trends now survive the secure wire, keep IDs out of prose, validate kind/value/rounded direction on both sides, and return vetted evidence-only copy without a model call or invented drill. Coach-quality repair, explicit state changes, and vulnerable disclosures outrank a simultaneous metric ask, while a bare ambiguous broad-data fragment does not authorize telemetry. Current Functions lint/build plus 161/161 policy and 7/7 deploy-lock tests pass; current iOS typed-evidence and reply-reliability selections pass 124/124 and 133/133. Deployment revision, real transmitted request capture, App Check-valid context survival, live semantic paraphrases, reporter acceptance, professional review, and production-output parity remain unproved. |
| Live generated reply quality | **Missing** | The reporter's real acceptance failed: replies were described as weird, redundant, and unlike a human expert communication coach. Earlier synthetic production-policy probes repeated advice and invented numbers, settings, mechanisms, promises, and future exercises. The latest five-case Vertex probe predates the current response-kind isolation and is only a synthetic model-boundary diagnostic; it is not current-source generated-quality evidence. No current-source deployed conversation set passes the full directness, specificity, concision, fairness, adaptation, and human-tone boundary, and no independent professional review or reporter re-acceptance exists. |
| Real app transport coverage in live-provider evidence | **Incomplete** | An operator-confirmed installed iPhone 17 simulator retry now proves composer retry, Auth/App Check verification, callable completion, and visible `Hello.` as one live greeting route. Production binds the deployed function hash, policy, generation mode, model, finish reason, and status, but the capture does not bind an exact app commit/signing artifact or preserve a managed release attachment. It is not a multi-turn or coaching-quality sample. Required evidence must still bind app SHA, signing/entitlement state, Firebase identity type, deployed revision, and actual visible responses across the representative corpus. |
| Operational static repository wiring | **Proved** | At `77352b03`, readiness reports 22/22 static checks, including fail-closed processor-manifest generation freshness, exact first-hook deployment locks for every checked-in Firebase Functions/Firestore target, and Hosting isolation from that backend lock. It explicitly does not prove deployment, hosted content, direct gcloud/alternate-config containment, App Store review, TestFlight upload, or bug triage. |
| Full callable runtime-security inventory | **Incomplete** | Current source requires exactly 18 reviewed callable exports plus one reviewed scheduled function, 19 Functions exports total; the static cloud-operations validator passes 19/19. Production now includes active `coachChatV2` and updated `coachChatAvailability` in addition to the historical four-function roster, and one v2 request passed deployed Auth/App Check and account binding. The complete 19-export production roster, indexes, mixed v1/v2 behavior, adoption measurement, and rollback remain unproved; the one repaired callable cannot stand in for a full runtime-security inventory. |
| Source-exact hosted privacy enforcement | **Proved locally** | Shell and Python readiness paths share bounded decompression and require the approved origin, 2xx HTML, and exact `public/privacy.html` bytes without logging body content. The focused privacy contracts and generator freshness check pass. Processor manifest v7 changes the current body to 32,420 bytes / `c4422d8260a3a4c92b6504d918fb2c46ceeb9c93a52254b25fa743932ebe2da2`; the last live probe targeted an older source body, so hosted equivalence remains Missing until an authorized deployment and fresh current-source probe pass. |
| Recoverable social cutover source and emulator contract | **Proved locally** | At `236d9719`, cutover schema v3 supersedes the unsafe v2 disposition: it recursively inventories challenge descendants (including missing-parent trees), quarantines/deletes all legacy challenges, descendants, and friend links, leaves legacy challenge/friend manifest arrays empty, removes challenge roots before descendants, and restores descendants before roots. Exact server challenge/friend schemas and a v3-only complete marker fail closed on legacy or injected rows. 36/36 migration/credential/backup tests, 72/72 Functions units, 6/6 deploy-blocker tests, 24/24 callable/rules emulator tests, and 6/6 actual CLI/Firestore-adapter tests pass. The current emulator host selected Node 26 despite the harness's Node-22 preflight; Java 21.0.11 and Firebase CLI 15.19.1 were pinned. No production adapter invocation or deployment occurred. |
| Ineligible competitive observation substrate | **Proved locally** | Commits through `81c17f4c` add exact Auth/App-Check/cutover-gated begin/complete contracts, bounded canonical PCM, at-most-once provider work, transcript-free permanently ineligible receipts, direct-rule denial, account deletion, and a false-gated iOS Ah Counter route. At `5aa8e728`, the source replaces the per-UID raw-audio claim with one server-only seven-day domain-separated exact-PCM claim shared across accounts. At `23fbfeee`, the post-create challenge sheet carries exact server prompt bytes plus the existing challenge intent through the account/token-bound Timed handoff; prompt replacement, Unicode/case/whitespace drift, stale tokens, wrong accounts, and byte-different armed sessions fail closed. At `c7cd0b51`, the prompt-bearing arm becomes a process-local route lease created only after exact account/token consumption and authoritative cached participant/expiry/unplayed validation, bound to the exact saved session before Summary, and removed from reload/export/migration; matching unbound cancellation, retry/terminal cleanup, account teardown, and legacy-key purge are fail-closed. A focused iOS selection passes 73/73. Both capabilities remain false, receipts remain ineligible, no verified-evidence writer exists, and the sheets have no production call site. The clean detached canonical gate (26/26 callable/rules/lifecycle plus 6/6 real adapter tests), the current 22/22 static readiness checks, and a clean unsigned arm64 Release simulator build remain the broader local boundary. This proves bounded local exact-byte capture/replay and route-lifecycle mechanics only. Hydrated/opponent navigation, replay after transformation or after the retention window, deployed TTL, live provider behavior, non-challenge provenance, evaluator calibration, and eligible evidence remain unproved. |
| Supported backend deploy path | **Proved locally closed for checked-in configuration** | At `d96afc90`, `npm --prefix functions run deploy` became a non-executing blocker with no process, network, or file-read primitive. At `77352b03`, the exact blocker becomes the first hook for every checked-in Firebase Functions/Firestore target, closing scoped, combined, and unscoped deploys before preparation or mutation; 7/7 deploy tests, 86/86 readiness tests, and 22/22 static checks pass. Hosting deliberately remains independent. This does not control direct gcloud/Cloud Console mutation or alternate Firebase config files, authorize deployment, or prove production state. |
| Speech-quantity fairness across evaluation, goal evidence, and immediate prescription | **Proved locally** | At `c3d1ff65`, one pure `FillerBurden` projection drives severity, drill focus, cross-session trends, filler-aligned copy, and controlled pressure-stretch eligibility. At `ec10990f`, severe qualifying burden routes to Ah Counter (`Filler Control`), including after a first severe qualifying rep; non-severe thin evidence stays suppressed. At `4da56e3e`, Timed/Ah evaluation uses the same qualifying rate for score, XP, feedback, clarity, weak moments, insights, and recent-session comparison; 1/60 equals 10/600, 3/20 stays concentrated, and sub-floor speech withholds judgment. At `ac393554`, the latest trajectory pack, qualitative goal rubric, goal-card confidence, and public weekly filler trend require quantity-qualified, duration-normalized evidence. At `dbafb01b`, Summary, Practice insights, `CoachingPlanner`, and chronological Review/Profile comparison join the same boundary. At `ac664112`, direct Ask Noum context, provisional Coach Read, AI Coach feedback/fallbacks, and comparable proof tests also join it; thin evidence cannot leak an older count or become a pressure pattern. At `a2502c04`, Clean rep and Filler-free week Path milestones require the same quantity, confidence, current-schema, and non-fixture evidence, while persisted unlock IDs remain grandfathered through the existing ledger. At `c3e018d4`, Roleplay withholds filler scoring entirely because its turn model lacks finalized duration; semantic terms and isolated unqualified disfluencies cannot alter quality or pressure while non-filler content signals remain. At `9088fdc3`, every duration-bearing practice surface uses the same recorder-stop receipt, and legacy-clock rows fail closed for duration-derived coaching. Focused capture verification passes 26 unique tests, the related selection passes 74, and the complete target passes 4,155 unique tests / 4,172 device executions. This proves local consistency and fail-closed behavior, not professional calibration or user benefit. |
| Metric-specific historical filler/WPM evidence | **Partially proved locally** | Duration-derived mechanics remain optional evidence rather than inferred truth. The identified row must clear the 20-word / 15-second quantity floor, any supplied confidence floor, current comparison schema, and non-fixture boundary before supporting deterministic filler-rate or pace claims. Summary verdict, filler-rate presentation, and improvement bullets remain bound to `finalizedSessionID`, and `SessionFinalizer` withholds lifecycle effects unless that exact eligible persisted row resolves. Premium generated Coach Read now takes the stricter free-form route: provider context, fallback, continuity, persistence, and replay admit no observed filler/WPM/pace mechanics or comparisons; derivative baseline strengths, blockers, clutch words, and filler/pace pressure reads are also excluded. Exact transcript quote presence, all-field quote integrity, and an account-scoped source revision are revalidated at the store boundary; legacy replay requires quote integrity without inventing a new required-quote rule. For that preceding Coach Read source, the generated/shared lane passes 56 unique tests / 58 executions, the complete target passes 4,320 unique tests / 4,339 executions, and the unsigned Release simulator build succeeds. Forward Plan's provider prompt now exposes recent filler only as a qualified normalized rate or `not measured`, and current-schema reliable filler/pace baselines replace the former confidence-only check; the focused metric lane passes 7/7 and the combined related selection passes 134/134. This remains partial because the qualitative Summary delivery line, durable CoachMemory/derived delivery reads, IM baseline comparison, Ask Noum session opener, share/request-feedback WPM, Proof Moment metric qualification and remaining lifecycle/replay gaps, other durable narrative/reward consumers, and legacy trend continuity remain open. No professional, device, transfer, or external evidence exists. |
| Proof Moment asynchronous account/source isolation | **Proved locally for the scoped P0; lifecycle partial** | In the current source developed above `8fbdbab6e`, request creation requires a signed-in, ready account and the exact row plus loaded `PracticeSessionStore` epoch. Account lifecycle, store generation, source revision, and generation identity scope cache and persistence; cache hits, the archive compare-and-save boundary, and all four render assignments revalidate the lease. Nil/hydrating identity, pre-reload state, identical destination rows, rapid same-account return, store reload, source mutation/deletion before commit, stale cache, and delayed invalidation fail closed. Focused verification passes 39/39, the related selection passes 130/130, and the complete unsigned target passes 4,331 unique tests / 4,350 device-configuration executions with zero failures or skips. The current-source unsigned Release simulator build succeeds, and a light five-tab sweep renders the expected tab tops without exercising the account-transition path. Same-account personalization drift, post-commit source deletion/mutation, retained render state, cancellation during save, and the latent unchecked writer remain P1/P2 gaps. This is local race-boundary evidence only, not provider, Proof-Moment-specific rendered, device, professional, longitudinal, operational, or external proof. |
| Capture-duration and baseline metric provenance | **Proved locally** | At `9088fdc3`, the microphone-capture interval freezes before audio teardown/provider drain and supplies persisted duration, telemetry, pitch eligibility, Mini-drill, and exact Pressure Drill round totals. Comparison schema 2 separates exact receipts from readable schema-1 history. Baseline recipes rebuild from current-epoch rows on mismatch, and pressure EMA replay is chronological. Focused, related, and full passes cover 26, 74, and 4,155 unique tests respectively. No deliberately delayed live-provider or physical-device run exists, so this remains local provenance evidence. |
| Path unlock delivery and evidence provenance | **Proved locally** | At `b5747542`, `PracticeSessionFinalizer` captures synchronized unlock state before append and `PathProgressManager` compares it after dependent state lands, so a reactive recompute cannot consume the celebration event. The event carries the exact finalized session ID; stat copy and proof resolve that ID rather than `.last`. General criteria reject sub-floor and evaluation-only rows, stricter filler milestones remain unchanged, and persisted unlock IDs remain grandfathered. Focused 23-test, related 55-test, and complete 4,145-unique-test / 4,162-execution simulator gates pass. The light sweep does not force the overlay, and no signed-device, accessibility, retention, or transfer result exists. |
| Progress-bearing session provenance | **Proved locally** | At `eaf2f31c`, one three-word/three-finite-second/non-fixture policy separates raw Review history from earned, coaching, recommendation, rehearsal, and KPI projections. At `8ec313c9` and `cb5f0327`, Profile coaching depth plus Review story/latest/highlight/chart reads consume that projection. The current working tree completes the rendered boundary: All Reps keeps raw saved count, search, exact detail, replay setup, deletion, and export, while its score aggregate and session-backed mode cards, previous-rep comparison, targeted mistake replay, Profile starting-point copy/transformation gate, and unique eligible review-open KPI use measured rows only. Thin rows replace stored score/praise with neutral saved-capture provenance and withhold coaching detail while retaining prompt, replay, and transcript access. The focused history/KPI lane passes 31/31, the rendered lane passes 2/2 with five visually inspected attachments, and the current complete target passes 4,242 unique tests / 4,261 executions. Non-finite/evaluation rows remain unit-only. The shared floor does not replace stricter filler/WPM quantity gates; Sudden Death's independent legacy run ledger and existing monotonic ledgers are not reconciled. No device, live-provider, professional, longitudinal, or launch result exists. |
| Account-owned mini-drill receipt provenance | **Proved locally** | In the current working tree, `DrillHistoryStore` no longer imports the device-global `drillHistory` archive into progress. Each account owns a separate bounded archive; accepted receipts require current schema/source, exact outcome identity, parent practice-session identity, terminal word count and finite duration, variation, and bounded XP. Summary durably records that receipt before XP/reward/baseline/streak/result effects. Eight store tests cover account isolation, legacy filtering, invalid evidence, duplicate rejection, persistence/order/streak, teardown, and capacity; the current related selection including the rendered fixture contract passes 48/48. The eligible representative UI path reaches its result only after that insertion and the insufficient path shows neither result nor XP; the UI lane passes 2/2. The complete current-source target passes 4,224 unique tests / 4,243 device executions. The legacy global archive remains unattributed for export/deletion, historical XP is not reconciled, and deduplication is bounded by the retained 30 receipts. |
| Lesson Apply earned-progress integrity | **Proved locally** | The evaluator preserves authored word floors and supplies a visible 12-word fallback for the six lessons that previously had only keyword/device evidence. A usable terminal receipt, at least three finite recorder-owned seconds, and transcript-free schema/word-count/duration evidence must accompany the exact concept/spot/apply result shape before a known lesson can pass or earn XP. Exact thin keyword fragments, device-only thin findings, non-finite/short duration, malformed outcomes, account-switch celebration teardown, and persistence are covered in the focused 44/44 selection. The rendered keyword-only retry and eligible summary flows pass 2/2 with Reduce Motion, including Accessibility XXXL; their retained captures were visually inspected. Historical aggregate lesson progress remains grandfathered, Profile XP and LessonStore mutation are not one cross-store transaction, fixtures bypass microphone/provider timing, and thresholds lack professional calibration. |
| Roleplay completion pressure provenance | **Proved locally** | At `c4376973`, the fourth attempt and an unavailable-next-objection path complete without applying a prospective pressure rung. The chip and “Final attempted pressure” summary therefore remain bound to `RoleplayTurnResult.pressureLevel`; pre-terminal level and objection transitions remain atomic. Focused 55-test and complete 4,175-unique-test / 4,192-execution simulator gates pass. No deterministic rendered microphone-completion fixture, physical-device result, or effectiveness evidence exists. |
| Roleplay terminal continuation guidance | **Proved locally** | At `5987636f`, feedback and completion share one cached engine transition. A real next turn retains its exact adaptive promise; the fourth attempt becomes future-practice guidance; and a missing transition fails closed without claiming a rung or objection. Four pure tests pass inside a focused 38/38 selection, 3/3 deterministic UI flows pass including Accessibility XXXL terminal feedback/completion, and the complete target passes 4,188 unique tests / 4,205 device executions. The UI fixture bypasses microphone capture and is not physical-device, effectiveness, or launch evidence. |
| Standalone Pace earned-result integrity | **Proved locally** | At `8e7af9d9`, the provider's terminal receipt owns final speech eligibility, the recorder owns duration, and existing live samples own the Pace result. The shared recording gate plus three-word / three-finite-second floor prevents thin or unusable capture from presenting a score or awarding XP; eligible capture preserves the exact result and awards once. The focused engine/result/integrity selection passes 34/34, and the insufficient and eligible rendered fixtures pass individually, including Accessibility XXXL and accessible retry/exit actions. The complete unit target was not rerun at this commit; the latest complete target remains 4,188 unique tests / 4,205 device executions at `5987636f`. Fixtures bypass microphone/provider timing, and no durable Pace attribution or effectiveness evidence exists. |
| Standalone Cut the Crutch earned-result integrity | **Proved locally** | At `bb155866`, live engine evidence owns avoided-word violations and the candidate result, while the terminal provider receipt and recorder duration own minimum speech eligibility. The shared completion gate plus three-word / three-finite-second floor prevents thin or unusable capture from presenting a score, awarding XP, or committing Daily Goal/streak progress; eligible capture preserves the exact live candidate and commits once. Focused verification passes 36 parameterized executions across three suites, and both UI branches pass with Reduce Motion enabled, including Accessibility XXXL, accessible retry/exit actions, and exact +150 eligible copy. The complete unit target passes 4,200 unique tests / 4,219 device executions. Fixtures bypass microphone/provider timing; terminal text cannot reconstruct or independently reconcile live avoided-word timing; and no durable Cut the Crutch attribution or effectiveness evidence exists. |
| Production readiness | **Missing** | Ask Noum has direct failed-acceptance evidence: the app-required `coachChatV2` route is absent from the four-function production roster, five later legacy generations failed `data-loss`, the secure prompt path diverged from scripted quality evidence, and the reporter rejected the wording as repetitive, unnatural, and non-expert. Current source adds one exact v2 capability preflight per turn, a one-final-text-reply path, turn-scoped provider context, restrained server response ceilings, typed server quality rejection with bounded intent-specific recovery, a bounded no-unsolicited-drill gate, an evidence-led retained-intervention continuation, specific coach-owned style repair, and a bounded local-guest-to-new-anonymous repair. It also routes natural exact-stat and longitudinal asks through bounded typed projections, returns vetted metric/trend copy without a model call, rejects kind/value/direction drift, fixes a filler-rate self-rejection that could surface as unavailable, and preserves coach-repair/state-change intent in mixed metric turns. None of that is deployed or physical proof. Current backend evidence passes TypeScript lint/build, 161/161 Functions tests, 7/7 deploy-lock tests, 19/19 cloud-operations validator tests, and 9/9 simulator-environment checks. Current iOS evidence passes 124/124 typed routing/provenance/wire/pipeline tests and 133/133 reply-reliability tests; earlier 164/164 provider-chain and 251/251 wider Ask results predate the final typed edits and remain historical. The earlier 30/30 emulator, signed 224/224 Ask, 41/41 promotion/privacy/authority, 22/22 journal/promotion/registry, and 4/4 deletion-admission results also remain historical. These local results and the earlier synthetic five-case Vertex diagnostic earn no readiness points. Enabled content sync now has bounded local ordering, retry, exact acknowledgement, dirty-bootstrap preservation, snapshot ownership, and deletion draining. It still lacks server CAS/mixed-client cutover, startup digest repair, XP award-event provenance, session tombstones, deployed schema-2 rules, immutable provider metadata, and production convergence evidence. Same-UID anonymous recovery, Apple/Google link crash recovery, and existing-target merge remain source gaps. The latest authoritative source-bound result remains the inherited clean `ac664112` NO-GO, 18/100, local target shape 85/100, maximum allowed 20/100, claim `localEvaluationSubstrateOnly`; it was not freshly rerun for this dirty source. Reconciliation and backend-first deployment from the observed four-function roster to the reviewed source roster of 18 callables plus one scheduled function must deploy and read back both `coachChatV2` and updated `coachChatAvailability`; mixed-client/adoption/rollback evidence, current-source App Check-valid live generated conversations, reporter acceptance, independent professional review, signed full-scheme/UI/VoiceOver/physical-device proof, and every external gate remain missing. One historical live artifact is invalid; zero of five required external artifacts passes. |

## External proof gates

| Required artifact/gate | Classification | Current authoritative result |
|---|---|---|
| Current-source live-provider transcript sweep | **Missing** | No current-source live-provider artifact is staged in the clean `70b0b380` evidence directory. A historical artifact outside that directory is rejected for stale source/provenance and cannot count. |
| Blinded professional-coach calibration | **Missing** | `coach-chat-conversation-expert-calibration-results-v2.json` is absent. The conversation calibration-input packet is not a result. The separate goal-style packet now rejects incomplete or malformed review coverage, but it likewise has no bound evidence package or professional result and cannot close this gate. |
| Longitudinal real-user transfer outcomes | **Missing** | `coach-real-user-transfer-outcomes-v3.json` is absent. Local fixtures cannot earn this row. |
| Physical-device TestFlight QA | **Missing** | `coach-real-device-testflight-qa-v3.json` is absent. Its fail-closed contract requires exactly 14 named surfaces and 77 named checks from the same independently verified physical TestFlight build; simulator and direct development-device builds cannot count. |
| Operational launch checklist | **Missing** | `coach-operational-launch-checklist-v2.json` is absent. |
| Required sidecar set as a whole | **Missing** | The current SHA-bound evidence directory contains 0/5 required external sidecars; 0/5 passes the staging contract. |

## Current prerequisite and signing gaps

These are the repository's authoritative M14 preconditions as of this audit.
The audit did not attempt deployment, certificate repair, App Store mutation,
credential revocation, or production traffic.

| Prerequisite | Classification | Evidence and remaining action |
|---|---|---|
| Replacement transcription boundary in source | **Proved** | Release construction uses the authenticated Firebase/Deepgram route with local fallback. This is product substrate, not a signed-device or live-service proof. |
| Historical Deepgram/AWS incident closed | **Missing** | The runbook still requires legacy credential revocation, disabling/authenticating every legacy endpoint, and provider usage/billing audit. |
| Protected social cutover | **Missing** | Schema-v3 recoverable mechanics are proved locally and no longer promote client-authorable challenges or friend links. The disabled competitive observation callables also share the exact cutover gate but cannot authorize social state. Production active-client inventory/minimum-client disposition, writer suspension, backup/quarantine, explicit legacy-data approval, trusted eligible evidence producer, authorized source-bound dry run/apply, coordinated rules/functions deployment, mixed-build smoke, and rollback drill remain unperformed. |
| Trusted competitive session-evidence producer/evaluator | **Missing for eligibility; bounded observation substrate proved locally** | `_verifiedSessionEvidence` has a strict server consumer contract, and the disabled path can server-observe bounded PCM through Deepgram and persist only a transcript-free, permanently ineligible receipt. It deliberately never writes eligible evidence. A shared account-unlinked claim rejects byte-identical PCM across accounts for seven days, source declares the three TTL policies, and the dormant post-create challenge route preserves the server prompt's exact bytes into Timed capture. Its process-local lease now requires cached authoritative participant/expiry/unplayed state, exact account/token consumption, and exact saved-session binding before submission; legacy persisted prompt/token state is purged and omitted from export. Hydrated/opponent challenges still have no production launch route. Transformed/post-window replay, deployed retention, non-challenge provenance, deterministic evaluation, calibration, evidence-floor policy, and production authorization remain missing. Client sessions, local scores, observation receipts, and emulator fixtures cannot close this row. |
| Reciprocal friendship lifecycle | **Proved locally; production authority missing** | At `40e728f5`, four release-disabled Auth/App-Check callables create, accept, completely list, and pair-bound remove digest-addressed invitations through exact reciprocal schema-v2 links and capped atomic schema-v2 manifests. Canonical 32-byte bearer tokens remain memory/share-only; accepted replay cannot resurrect a removed pair; duplicate invites become terminal; removal and account deletion clean both directions even when manifest membership is missing or corrupt. The account-fenced iOS owner preserves manual contacts and replaces only the connected subset after a successful exact 50-link snapshot. Functions lint/build, 108/108 unit tests, 6/6 deploy-blocker tests, 18/18 migration tests, and the clean detached `demo-noum` gate (26/26 callable/rules/lifecycle plus 6/6 real adapter tests) pass. No production cutover, deployed IAM/App Check/rules/index inspection, TTL/retention proof, two-device TestFlight run, or hosted privacy verification exists; shipping capabilities remain false. The focused iOS test worker produced 0 tests, so only the unsigned build is counted. |
| Executable deployment authorization and immutable artifact | **Missing** | The supported deploy command intentionally refuses to execute. No independently trusted authorization evidence or immutable source-bound deployment artifact exists, and self-attested files are not acceptable substitutes. |
| Recoverable social migration/quarantine mechanics | **Proved locally** | At `40e728f5`, a clean-source, project- and implementation-bound mode-0600 backup inventories exact private profiles plus every legacy social source, recursively including challenge descendants. Apply journals before mutation, transactionally pairs each quarantine copy with source deletion, removes challenge roots before descendants, empties legacy challenge/friend references, binds resume to the same run/backup digest, restores descendants before roots during exact rollback, and completes only after identical expected/observed inventory digests. All ten social callables require the exact provenance-bearing v4 marker with exact schema-v2 manifests; v3 and older markers are rejected. Migration tests pass 18/18, and the combined clean `demo-noum` emulator gate passes 26/26 callable/rules/lifecycle tests plus 6/6 actual CLI/adapter tests. This proves local mechanics and the real emulator adapter path; production inventory, backup, quarantine, migration, index/rules/functions deployment, and rollback drill were not executed. |
| Hosted Firebase privacy endpoint reachability | **Proved** | The public Firebase Hosting endpoint responded on 2026-07-14. Reachability alone is not policy equivalence or deployment proof. |
| Hosted Firebase privacy body matches source | **Missing** | Current source is 29,606 bytes / `b0425f51…12bf68f`. The last live probe targeted an older source body, and no current-source exact-body probe exists. An authorized deploy and a fresh passing probe are required. |
| `noum.app` custom privacy domain | **Missing** | The runbook records it as parked at GoDaddy pending DNS, TLS, and policy verification. |
| Sign in with Apple entitlement in the app | **Proved** | `Noum.entitlements` contains the capability. |
| Sign in with Apple Firebase/provider configuration | **Missing** | External Apple/Firebase configuration remains unchecked in `docs/TESTFLIGHT_QA.md`. |
| Paid-team archive signing on this host | **Missing** | The fail-closed local preflight finds zero valid Apple Distribution identities and zero matching App Store profiles for the app, Widget, and Messages extension. It does not claim what exists in the Apple Developer account. |
| App Store Connect StoreKit products and metadata | **Missing** | No verified App Store Connect evidence or signed purchase/restore run exists. |
| Build/version notes and TestFlight upload | **Missing** | The pre-flight checklist remains unchecked and the operational artifact is absent. |
| Signed physical-TestFlight run | **Missing** | Required App Check, real microphone, consent/offline/reconnect, auth, deletion, notification, widget/Live Activity, accessibility, and purchase/restore evidence is absent. |

## Highest-leverage next evidence

### Safe local

Committed-ancestor, dirty-worktree, exact privacy-body, and full callable-roster
verifier hardening are complete. Keep
`40d5e903`, `47cbab5f`, and `80fbf6d2` as named historical baselines; the
current complete signed regression and optimized Release scan are bound to
`7ae1fe43`, while the repaired evidence workflow and canonical app-path report
are bound to `70b0b380`. The app-path report
preserves the provenance contract: explicitly styled rows pass only with typed
assessment, declared-neutral rows remain truthfully `notEvaluated`, unknown
fixture IDs fail closed, and all 109 traces carry the current commit and coach
fingerprint. Local reruns cannot raise production readiness past the external
cap by themselves.

In the current working tree, the highest-impact unambiguous rendered TR-4 gap
is closed. The existing recognizer owns an exact typed unsupported-locale issue;
Timed Practice presents specific offline-language guidance, removes recovery
controls that cannot help, and returns through its established setup lifecycle.
Focused speech/lifecycle verification passes 41/41, the Accessibility XXXL +
Reduce Motion lane passes 1/1, the generic provider-failure regression remains
green at 1/1, and the complete target passes 4,223 unique tests / 4,242 device
executions. Hardware model availability, manual VoiceOver, signed TestFlight,
and user benefit remain external. The later representative standard mini-drill
closure now passes 48/48 focused, 2/2 rendered, and 4,224 unique tests / 4,243
device executions in the complete unit target. It intentionally does not
fabricate specialized live WPM, pause-lock, or PREP-step evidence. The current
Train Pressure capability-loss closure remains proved, and the new Summary
closure carries the exact rendered projection through tap-time availability
and attribution. Projection/fixture/attribution verification passes 23/23, the
focused Summary branch passes 1/1, and all five current recommendation UI tests
pass together. The latest complete unit target now passes 4,267 unique tests /
4,286 device executions. This proves deterministic Train and Summary Pressure
branches, not rendered Home or Conversation loss, physical capability loss, or
benefit.
The rendered mixed Review-only history gap is now closed for durable finite
rows: raw saved captures remain inspectable while thin rows cannot own scores,
mode aggregates, comparisons, replay targeting, Review/Profile depth, or the
review-open KPI. Non-finite/evaluation cases remain unit-only, and stricter
mode-metric floors plus legacy Sudden Death run ledgers remain explicit
boundaries. The core metric-specific quantity gate is now closed for trend,
baseline/comparison, recommendation aggregation, momentum, severe next action,
drill focus/rationale, and deterministic post-rep copy. Its focused selection
passes 31/31, the complete target passes 4,267 unique tests / 4,286 device
executions, and the unsigned Release simulator build succeeds. Raw Review
history cards/charts/detail, replay/highlight interpretation, and one AI insight
fallback remain P1; legacy trend archives intentionally fail closed for filler
and pace until qualified snapshots accrue. Rendered Home/Conversation
expansion, standalone Pace attribution, and wider Roleplay prescription routing
remain product/schema decisions rather than safe mechanical follow-ups.

At `bb155866`, the highest-impact verified standalone Cut the Crutch integrity
gap is closed: the live engine may compute a candidate, but terminal provider
speech quantity and recorder duration must satisfy the shared progress floor
before result presentation, XP, or Daily Goal/streak commitment. Focused
verification passes 36 parameterized executions across three suites; both
rendered branches pass with Reduce Motion enabled, including Accessibility XXXL;
and the complete target passes 4,200 unique tests / 4,219 device executions.
This does not make terminal text an independent audit of live avoided-word
timing, create durable Cut the Crutch attribution, or earn an external readiness
point. The next safe local gap must be freshly re-ranked against current source.

At `8e7af9d9`, the highest-impact verified standalone Pace integrity gap is
closed: terminal provider text and recorder duration now gate the existing live
sampled result before any result or XP is exposed. Thin speech returns to setup
with a restrained retry explanation, unusable capture keeps the established
recognizer failure path, and eligible XP remains exact and single-award. The
focused Pace selection passes 34/34, both rendered branches pass individually,
and the insufficient branch remains readable at Accessibility XXXL. This does
not close PR-2: adaptive routing to standalone Pace still requires a durable
session/recommendation/comparable-response attribution contract, and local
fixtures cannot establish microphone timing, coaching effect, or launch proof.
The next safe local gap must be freshly re-ranked; no external readiness point
was earned.

At `cb5f0327`, the highest-impact verified Review leak is closed: Review-only
rows remain exact saved history but no longer strengthen story depth, hijack
latest-rep navigation, enter highlights, unlock the development chart, or make
the parent choose a chart that renders empty. Focused verification passes 48/48
and the complete target passes 4,184 unique tests / 4,201 device executions.
The light sweep shows the ordinary valid-evidence Review shell, not a forced
mixed invalid-history branch. At `5987636f`, the adjacent bounded Roleplay
candidate is also closed: visible guidance and advancement consume one cached
transition, terminal feedback becomes a future practice focus, and an
unavailable transition fails closed. Focused verification passes 38/38, the
rendered fixture lane passes 3/3 including Accessibility XXXL, and the complete
target passes 4,188 unique tests / 4,205 device executions. This still earns no
external readiness point. The next safe local gap must be freshly re-ranked;
wider Roleplay prescription routing needs product/router/measurement decisions,
and duration-based Roleplay mechanics need a persisted turn-duration contract.

At `af923c00`, Roleplay's floor-level retry preserves the exact objection
already attempted when the engine returns `.sameObjectionSlower`, deliberately
bypassing account-wide novelty filtering only for that branch. Fresh-objection,
level-up, and level-down branches continue to use the established selection
policy at the resolved pressure rung, and every attempt remains a distinct
`RoleplayStore` record. Focused verification passes 52 tests and the complete
target passes 4,172 unique tests / 4,189 device executions with zero failures or
skips. This proves local deterministic adaptation continuity only. “Slower” is
still an instructional cue, not measured pace evidence, and this closure earns
no external readiness point. At `c4376973`, the adjacent terminal truthfulness
gap is also closed: pressure and objection advance atomically only when another
attempt exists, so fourth-turn completion keeps the attempted rung and labels it
“Final attempted pressure.” Focused verification passes 55 tests and the full
target passes 4,175 unique tests / 4,192 device executions. This remains local
deterministic evidence; the next safe local gap must be freshly re-ranked rather
than inferred from this completed path.

At `ab5b6aaa`, the highest-impact locally executable goal-action gap is closed:
an established, qualified, style-compatible goal target can select and
attribute one existing full proof rep without displacing severe, blocker, or
durable-case evidence. Standalone Pace Training attribution now requires an
explicit backend-schema and mixed-client compatibility decision; wider
Roleplay/Lessons/Projects/Path routing requires a product/router/measurement
decision. Neither is a safe mechanical follow-up to this closure.

At `c3e018d4`, the highest-impact unambiguous local trust gap is also closed:
Roleplay no longer penalizes semantic speech or an isolated disfluency through
an unqualified raw word ratio, and every speech surface presents the shared
startup-fallback notice. Reintroducing Roleplay filler coaching requires a
durable finalized turn-duration contract. Standalone Pace attribution still
requires the backend-schema and mixed-client decision, and rendered fallback
behavior still requires a real provider failure on physical TestFlight hardware.

The custom dump-directory wrapper, recoverable social migration state machine,
actual Firestore adapter on the demo emulator, an explicitly closed supported
deploy path, and fail-closed professional goal-calibration review intake are now
proved locally. The goal-style packet still needs an access-controlled evidence
package and real independent reviews; local validators cannot manufacture that
evidence. The highest-impact remaining product work is to turn the now-present,
disabled observation substrate into an independently calibrated deterministic
evaluator and trusted eligible evidence producer while obtaining deployed
retention proof and extending the bounded exact-PCM replay contract where the
evaluator's freshness policy requires it. Only after that authority exists
should the dormant post-create handoff become one coherent hydrated/opponent
challenge launch flow; adding a disconnected enabled UI now would weaken the
release boundary. The reciprocal friendship
lifecycle is now present locally, but its TTL/index/rules/functions deployment,
authorized cutover, and two-device verification remain production evidence gaps.
Neither authority boundary can be replaced honestly by copying client sessions, scores,
transcripts, or emulator fixtures into trusted collections. After those exist,
the remaining work is operational and approval-gated: independent deployment
authorization bound to an immutable artifact, production identity inspection,
a reviewed active-client inventory and minimum-client disposition, safe writer
suspension, an authorized source-bound dry run and backup review, privacy
deployment, and the coordinated migration/rules/functions cutover. A two-device
mixed-build conflict/replay/deletion smoke, plus backup and rollback evidence,
must accompany that deployment. The current screenshot handoff records local
blocker evidence only and does not close any external gate.

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
