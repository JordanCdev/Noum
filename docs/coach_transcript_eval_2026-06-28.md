# Ask Noum Transcript Evaluation - 2026-06-28

Status: evaluation artifact, not a production-readiness claim.

This file started with 12 end-to-end Ask Noum fixture conversations from
`CoachChatEvaluationCorpus.latestManualEvalFixtureIDs`; the current short
conversation corpus now covers 13 three-turn target transcripts, including the
personal-pattern hypothesis boundary added on 2026-06-30. These are target
transcripts and regression fixtures, not live provider outputs. The live path is
still `CoachLiveEvaluationTests.liveGeminiRepliesClearFixtureRubric`, which now
prints provider requested/chosen tier, chosen provider/model,
`providerAttemptCount`, `providerRetryCount`, `providerRefusalCount`,
`timeToFirstVisibleTokenMs`, `timeToFirstVisibleTokenSource`, completion
latency, `trajectoryCacheHit`, `assessmentCacheHit`, `assessmentCacheAgeMs`,
`assessmentProofTestHash`, `immediateCoachReadShown`, `replyWordCount`, trust
friction flags, `visionScore`, reliability issues, and `liveProductionFloor`.
`timeToFirstVisibleTokenMs` is exact when the stream-visible callback fires and
otherwise names the proxy source. It also writes a schema-versioned
`coach-live-eval-v1` JSON sidecar beside the markdown transcript so telemetry
and gate outcomes can be diffed across live runs. It fails unless quality gate,
semantic gate, senior-coach rubric, vision floor, and reliability cleanliness
all pass.

The same short conversation corpus is mirrored in
`CoachChatConversationCorpus.conversations` as three-turn, machine-scored
target transcripts. That corpus is still not live-provider evidence; it is a
repeatable target-shape gate that keeps the full conversation standard from
living only in prose.

2026-06-29 replay update: all 12 target conversations now pass
`CoachChatConversationCorpusTests`, including
`targetConversationsAreAcceptedByRuntimeGateAcrossHistory`, which routes all 30
target turns through `AICoachChatService.reply(...)`. The corpus also replays
`CoachReliabilityGate` over the same turn history and records per-turn
reliability issues in the report. This remains target-shape evidence, not a
production-readiness claim.

2026-06-29 report v10 update: the 12-conversation report now records per-turn
runtime quality/vision labels (`turnRuntimeIssues`, `runtimeIssues`,
`passesRuntimeGate`) and typed semantic-judgement labels (`turnSemanticIssues`,
`semanticIssues`, `passesSemanticGate`) using the same `auditLabel` vocabulary
as the live pipeline. `passesProductionFloor` now requires conversation score,
runtime gate cleanliness, semantic gate cleanliness, and reliability
cleanliness. Deliberately bad injected conversations prove both paths: an
"Understood." reply fails with professional + vision labels, and a hollow
trust-repair reply fails with `semantic:missingRepairInsight`. A polite
pushback variant now also fails when the reply merely says "but" before
prescribing again instead of naming the user's actual friction.
Rows also expose `turnDepths`, `trustRepairTurnIndices`,
`userPushbackWithinTwoTurns`, `coldnessComplaintFlag`, and
`coldnessComplaintTurnIndices`, plus `softPushbackFlag` and
`softPushbackTurnIndices`, so offline transcript review can see where trust
friction happened instead of treating a high-scoring repair as context-free.
Schema v10 also serializes `visionProductionReadiness`, a report-level VISION
audit that records the 18/100 score, 20-point cap, readiness claim, and missing
validation blockers beside the transcript rows.

2026-06-29 trust-repair hardening update: the semantic gate now rejects hollow
"I sounded cold because..." apologies when they do not include a concrete read
or evidence anchor, and it no longer accepts `but` as proof that Noum has
acknowledged polite pushback. The 12-conversation target corpus still passes,
but this is only a guardrail improvement. The earlier 67/100 read was still a
local target-shape score, not production readiness. Harsh VISION production
readiness score: **18/100**. The remaining gap is live provider evidence,
expert-calibrated coach presence, real-device/TestFlight QA, launch operations,
and validated transfer outcomes, not another local transcript pass.

2026-06-29 production-readiness correction: `CoachVisionProductionReadinessAuditTests`
now pins the distinction in code. The local short conversations and app-path
proof-test wiring count as evaluation substrate, but the score is hard-capped at
20/100 until the app has a clean live-provider transcript sweep, professional
coach calibration, real-user longitudinal transfer outcomes, real-device
TestFlight verification, and the M14 launch checklist. This follows the
research anchors below: multi-turn reliability can degrade sharply, paired
flawed conversations expose isolated failures better than aggregate scores, and
structured feedback only matters once it is validated against real behavior.

2026-06-29 expert-calibration packet update:
`CoachChatConversationExpertCalibrationPacket` schema v1 started by exporting
the same 12 full three-turn conversations as a blinded professional-coach review
packet.
Rows carry the candidate transcript, source context, turn-depth/trust-friction
flags, and a response schema asking for diagnosis, case formulation,
intervention, adaptation, perception-honesty, transfer, trust-repair, and
overall-usefulness ratings. The packet is explicitly
`pendingExpertReview`; exporting it does not clear the VISION readiness blocker.
As of the 2026-06-30 personal-pattern boundary hardening, the current packet
exports 23 required conversation rows: 13 short three-turn conversations plus
the 10 five-turn long-form conversations. As of the independent-review
hardening, those 23 conversations require 46 completed professional review rows
before the calibration blocker can clear.

2026-06-29 app-path conversation report update:
`CoachChatConversationAppPathReport` schema v1 now replays the same 13
three-turn target conversations through an isolated `AskNoumStore` plus the
shared `CoachReplyPipeline` using scripted provider replies. This is stricter
than the earlier service-only target replay because it inspects the actual
stored coach rows and `CoachTurnMetadata`: turn depth, provider tier,
quality-gate outcome, redacted quality-gate event sequence, semantic-gate
outcome, reliability issues, vision score, immediate-read flags, proof-test
hashes, and latency fields. The current scripted app-path report is now green
on the local replay: all 39 turns pass the quality gate, target replies match,
semantic/reliability gates stay clean, and no typed-assessment fallback or
content-rejection path is accepted into the stored coach rows. The fix was not
to lower the floor. The shared pipeline now carries recent coach replies into
vision/personalization checks, accepts short conversation-local follow-ups when
the reply is grounded in observable coach anchors, routes explicit
"that did not answer what I meant" turns as trust repair, and treats replay
listening/rewrite prescriptions as real practice/transfer moves. Rows still
serialize `qualityGateEvents` labels such as `rejected:<gate>` and
`fallback:typedAssessment`, so a future regression gets a precise gate timeline
rather than only the final stored `qualityGateOutcome`. The summary also
aggregates
`qualityGateEventCounts`, `qualityGateFamilyCounts`, and
`nonCleanQualityGateEvents`, so the artifact can show the dominant gate family
without manual row inspection. It also separates accepted fallback from hard
failure through `acceptedFallbackTurnCount`, `typedAssessmentFallbackTurnCount`,
and `qualityGateBlockingFailureTurnCount`. This keeps deterministic safety
fallback visible as degraded if it reappears, instead of hiding it inside a
generic hard-fail bucket. The result clears the local scripted app-path floor;
it does not clear any VISION blocker.

2026-06-30 live app-path two-speed update:
The same app-path report machinery now also emits
`coach-chat-live-app-path-eval-v1.json`, using the same 13 three-turn
conversations, the same isolated `AskNoumStore`, and the same shared
`CoachReplyPipeline`, but with `surface: live`. This covers the gap left by
the provider-only live transcript harness: direct `AICoachChatService.reply`
captures can judge provider prose, but they cannot prove the app pipeline
actually shows the deterministic local coach read before the final model
answer. The live app-path artifact is local and scripted, but it now proves the
two-speed branch on the app path: all 39 live turns expected an immediate coach
read, all 39 showed it, every first-visible latency was under the local 500 ms
guard, all 39 quality-gate events were `passed`, and there were 0 target
mismatches, semantic failures, typed fallbacks, blocking quality-gate failures,
reliability issues, or vision-floor failures. This is stronger local
architecture evidence for the live UX path; it is still not a live-provider
sweep, real-device voice run, human-coach calibration, or real-user outcome.

2026-06-30 readiness evidence manifest update:
`CoachVisionProductionReadinessEvidenceManifest` schema v1 now writes
`coach-vision-production-readiness-evidence-manifest-v1.json` beside the other
conversation artifacts. The manifest is intentionally small and blunt: it marks
the local conversation corpus, long-form local conversation corpus, text
app-path replay, and live app-path immediate read as earned evidence, then
separately records the missing or pending launch evidence that still blocks
VISION readiness. Current manifest score remains **18/100** with claim
`localEvaluationSubstrateOnly`, local target-shape score 99/100, and blockers
for no live-provider transcript sweep, no professional coach calibration, no
real-user longitudinal transfer outcomes, no real-device TestFlight
verification, and incomplete operational launch checklist.

2026-06-30 long-form conversation eval update:
`CoachChatConversationCorpus.longFormConversations` now extends the local
conversation evidence from 12 short three-turn transcripts toward the requested
10 full end-to-end transcripts. The new
`coach-chat-long-form-conversation-eval-v1.json` artifact contains 10 five-turn
conversations derived from the existing calibrated fixture contexts. Each
conversation keeps source fixture provenance, covers transfer/proof checking on
the final turn, and the corpus spans quick moves, grounded reads, deep
assessment, and trust repair. The next pass hardened the long-form replies
against the research report's "flat judgement without bridge" failure mode by
requiring the coach to connect observed signal to prescribed action. The result
is still intentionally scored harshly but is now clean locally: 10/10 clear the
conversation floor, 10/10 clear the offline production-floor projection, and the
report summary shows 10/10 runtime, semantic, reliability, and production-floor
rows with empty runtime/semantic/reliability issue buckets. The long-form
artifact reports score 18/100 and claim `localEvaluationSubstrateOnly`; the
manifest records `longFormConversationCorpus` as earned local substrate without
removing any launch blocker. This is better evidence for multi-turn continuity,
not a launch claim.

2026-06-30 intent-fit semantic gate update:
The semantic gate now checks a narrow class of explicit user follow-up intents
before accepting a provider reply, deterministic fallback, final pipeline
metadata result, or transcript-evaluation row. This targets the multi-turn
failure where the coach gives a plausible neighboring answer instead of the
thing the user actually asked next. The gate is deliberately conservative: it
fires only on clear ask shapes such as "give me an example", "how do I know if
it worked", "what test separates those", "what should I capture", "do I change
the whole answer", "when would you call it authority", "what should you
remember next time", "what do I take into the interview", and "why". A new
paired report fixture proves an example request cannot clear the production
floor by returning only a generic verdict-first drill; it must supply a
session/example-shaped answer or equivalent intent-matched response. The 10
long-form conversations still pass the stricter local gate: 10/10 runtime,
semantic, reliability, and offline production-floor rows; 0 runtime, semantic,
or reliability issues. This hardens local evaluation quality, but does not
remove any live-provider, professional-calibration, real-user, real-device, or
launch-ops blocker.

2026-06-30 paired adversarial long-form update:
The evaluator now also emits `coach-chat-long-form-adversarial-eval-v1.json`,
a negative-control report built from 10 full five-turn conversations in the
clean long-form corpus. Each paired variant injects one realistic failure mode:
stale state, repeated proof-test prescription, missed follow-up intent, or a
trust-repair reply that prescribes without attunement. The report is expected
to fail every row, and the current artifact does: 0/10 rows pass the local
production-floor projection. The failure labels are specific enough to be
useful: `semantic:missingIntentFit` appears 7 times, `repeatedProofTest` 8
times, `noAttunementOnPushback` once, plus stale-state duplicate/runtime/vision
failures. The positive long-form report remains clean at 10/10. This is
evaluator-overfit protection, not readiness evidence, so the manifest score
remains **18/100** with the same launch blockers.

2026-06-30 trust-repair reliability follow-up:
`CoachReliabilityGate` now treats `noAttunementOnPushback` as a blocking
last-mile defect instead of a recorded-only smell. If a user pushes back on the
coach and the final reply opens by prescribing again without acknowledging the
miss, `CoachReplyPipeline` substitutes the deterministic repair fallback before
the turn reaches `AskNoumStore.completeCoachTurn`. The remaining soft
reliability issues (`nearDuplicateReply`, `floorConfidenceWithEvidence`, and
`repeatedProofTest`) are still recorded for evals/metadata but do not blanket
replace otherwise-usable prose. The regenerated corpus run on iPhone 17
simulator passed 58/58 tests; the positive long-form corpus stayed 10/10 clean,
the adversarial corpus stayed 0/10 production-floor passing, and the manifest
remained **18/100** (`localEvaluationSubstrateOnly`).

2026-06-30 adversarial manifest integrity follow-up:
The top-level production-readiness manifest now carries the long-form
adversarial negative control as a first-class local evidence row:
`adversarialNegativeControlCorpus`. It is earned only when the existing 10
paired five-turn failure conversations all fail the production floor. This
does not lift the VISION score, because it is evaluator-integrity evidence, not
real launch evidence; it prevents the local ledger from looking trustworthy
when only the positive corpus is present. The regenerated manifest records
`localAdversarialConversationCount = 10`,
`localAdversarialRowsRejectedByProductionFloor = 10`, row status `earned`,
score **18/100**, claim `localEvaluationSubstrateOnly`, and the same five
external blockers.

2026-06-30 live-provider evidence ingestion hardening:
The manifest now has a typed `CoachLiveProviderSweepEvidence` decoder for
`coach-live-eval-v1` JSON, and the live-provider row only counts when that
artifact qualifies cleanly: schema matches, the latest-turn portion covers all
19 `CoachChatEvaluationCorpus.latestManualEvalFixtureIDs`, fixture IDs are
unique, all required turn depths are represented (`quickMove`, `groundedRead`,
`deepAssessment`, `trustRepair`), provider/model evidence is present, row counts
match, `passesProductionFloor` and `passesRunReadinessFloor` are both true,
there are no `readinessWarnings`, no production-floor failures, no missing
expected immediate coach reads, at least three rounded assessment-confidence
values are present, proof-test hashes are varied without repeats, and the
long-form portion covers the required 10 live conversations without failures.
Raw row counts can no longer clear the manifest blocker. The manifest artifact
writer now also attempts to load
`coach-live-eval-v1.json` from the same evaluation dump directory
(`NOUM_COACH_EVAL_DUMP_DIR`, `SIMCTL_CHILD_NOUM_COACH_EVAL_DUMP_DIR`,
`-NOUM_COACH_EVAL_DUMP_DIR`, or the default `/private/tmp/noum-coach-eval`).
If that sidecar is malformed, the eval fails loudly; if it is present but
rejected by the readiness floor, the blocker stays. A clean loaded sidecar
removes only `noLiveProviderTranscriptSweep` and raises the capped score to
20/100 while human calibration, real-user transfer outcomes, real-device QA,
and launch operations remain blocking. The current emitted manifest still has
no live sweep attached, so `liveProviderTranscriptSweep` remains missing with
observed count 0 and the overall score remains **18/100**.

2026-06-30 live-provider long-form coverage hardening:
The same sidecar now has to prove both latest-turn quality and multi-turn
conversation quality before it can clear `noLiveProviderTranscriptSweep`.
Readiness requires 30 live evidence units: the 20 latest-turn fixture rows
above plus the 10 full five-turn clean long-form conversation IDs. The
long-form rows must be unique, exactly match the required long-form corpus, and
have no live conversation failures. A sidecar that passes the 20 latest-turn
fixtures but omits the 10 long-form live conversations is rejected with
`missingLiveLongFormConversationCoverage`, so latest-turn-only provider smoke
evidence can no longer stand in for end-to-end coach behavior.

2026-06-30 live-provider long-form harness update:
The stricter contract is now collectible through the existing skipped-by-default
live harness. `NOUM_LIVE_AI_FIXTURES=readiness` selects the 20 latest-turn
fixture rows and all 10 required long-form conversations for the same run.
`NOUM_LIVE_AI_LONG_FORM=required` can opt into the long-form sweep alongside any
fixture selector, and a comma-separated `NOUM_LIVE_AI_LONG_FORM=<conversationID>`
list can run a targeted subset. The report schema keeps the manifest-facing
top-level fields
`longFormConversationIDsPassingProductionFloor` and
`longFormConversationFailureIDs`, and now also emits detailed
`longFormConversations` rows with per-turn provider reply, latency, semantic,
vision, reliability, and production-floor telemetry. This makes a real provider
readiness sidecar auditable without changing the manifest gate. The local
contract tests passed, but no external-provider long-form sweep was run in this
session.

2026-06-30 live-provider long-form detail gate update:
`CoachLiveProviderSweepEvidence` now decodes and validates the detailed
`longFormConversations` payload emitted by the live harness. A sidecar can no
longer clear `liveProviderTranscriptSweep` by claiming 10 top-level long-form
pass IDs alone: the decoder rejects missing detail rows, duplicate/unexpected
detail IDs, summary/detail pass-failure disagreement, wrong or incomplete
observed turn counts, failed detailed rows, missing provider/model evidence,
and missing per-turn reply/latency/rubric/vision/semantic/reliability/proof-test
telemetry. New corpus tests cover missing detail, mismatched summary fields,
short observed conversations, and missing provider/telemetry rows. Regenerated
local artifacts still show 10/10 clean long-form conversations, 0/10
adversarial long-form conversations passing, and a harsh VISION readiness score
of **18/100** with claim `localEvaluationSubstrateOnly`.

2026-06-30 live-provider run note:
A real-provider smoke sweep was considered after tightening the sidecar contract,
but running it from this session would send evaluation prompts and context to an
external AI service through local credentials. The approvals layer rejected that
execution path. No live-provider sidecar was emitted, and the blocker remains.

2026-06-30 professional-coach calibration results ingestion update:
The manifest now also has a typed `CoachProfessionalCalibrationEvidence` decoder
for `coach-chat-conversation-expert-calibration-results-v2.json`, separate from
the pending review packet. The professional-calibration row only counts when the
result schema v2, source packet schema v2, source packet fingerprint, and rubric
match; the completed reviews cover the full current 23-conversation calibration
corpus (13 short three-turn conversations plus 10 full five-turn long-form
conversations); every conversation has at least two independent professional
communication-coach review rows; there are no unexpected conversation IDs; every
counted row passes the calibration floor (`roughTie` or `noumBetter`, would use
with a client, every rating >= 4, at least one human-coach reference, no
overclaim notes, and no unresolved revision notes); there are no unsafe or
unready rows; there are no readiness warnings; the summary reviewer count
matches the nonblank reviewer IDs in the rows; and every conversation has two
distinct reviewers. A one-reviewer sweep, one-review-per-conversation sidecar,
duplicate reviewer/conversation pair, missing packet fingerprint, or stale
packet fingerprint no longer clears the blocker.
Malformed result sidecars fail loudly, and rejected result sidecars leave the
blocker in place. A clean loaded sidecar removes only
`noProfessionalCoachCalibration` and raises the capped score to 20/100 while
live-provider, real-user outcome, real-device QA, and launch-ops blockers
remain. The current emitted manifest has no completed professional result
sidecar, so `professionalCoachCalibration` remains pending with observed count
0 and the overall score remains **18/100**.

2026-06-30 professional-calibration coverage hardening:
The expert packet and readiness manifest now share
`CoachChatConversationCorpus.professionalCalibrationConversations`, so a
professional sidecar must cover both the 13 short regression conversations and
the 10 full five-turn conversations. The next regenerated
`coach-chat-conversation-expert-calibration-v2.json` reports 23 conversation
rows: 13 three-turn rows and 10 five-turn rows, plus
`requiredIndependentReviewsPerConversation: 2`, `requiredReviewCount: 46`, and
the stable `sourceCorpusFingerprint` that completed professional review sidecars
must echo as `sourcePacketFingerprint`.
The next regenerated readiness manifest should keep
`professionalCoachCalibration` pending with observed count 0, required count 46,
and notes `pendingExpertReview for 23 conversations`; the overall score remains
**18/100** with claim
`localEvaluationSubstrateOnly`.

2026-06-30 calibration packet fingerprint hardening:
The professional-calibration packet/results contract has been bumped to v2 and
bound to the exact transcript packet through a stable `sourceCorpusFingerprint`.
Completed professional review sidecars now need
`coach-chat-conversation-expert-calibration-results-v2.json` plus
`sourcePacketFingerprint` matching the current packet. Missing or stale
fingerprints reject the sidecar before any review rows can count. This prevents
a professional-review export for an older or stale packet from silently
clearing the calibration blocker after transcript text, turn order, or source
fixture content changes. The existing `/private/tmp/noum-coach-eval` packet may
still be the old v1 file until the corpus/audit XCTest regenerates artifacts; do
not treat that stale dump as current v2 evidence.
Local verification for this change is limited to `swiftc -parse` and
`git diff --check`. An escalated targeted `xcodebuild test` reached the test
runner but blocked on `waiting for workers to materialize`, and a warmed
`build-for-testing` attempt also had to be interrupted. No v2 packet or manifest
artifact was emitted.

2026-06-30 trajectory cache evidence-signature hardening:
The local typed judgement path now treats same-session evidence changes as cache
invalidating. `UserTrajectoryCache.signature` includes compact fingerprints for
the freshest sessions rather than only latest session ID/date/count and global
rating/baseline/memory state. The fingerprint covers the fields that shape the
local `CoachAssessment`: transcript hash, score, filler count, duration, word
count, transcript confidence, mode, pressure, rated flag, and intent focus, plus
aggregate mode/pressure/rated counts. A new regression verifies that the same
session ID/date with revised transcript, filler count, score, duration, and
confidence returns `cacheHit == false` and rebuilds the latest evidence pack.
This is architecture-quality work for case-specific judgement; it does not
clear live-provider, professional-calibration, real-user, device, or ops
blockers, so the harsh VISION readiness score remains **18/100**.

2026-06-30 real-user transfer outcome ingestion update:
The manifest now has a typed `CoachRealUserTransferOutcomeEvidence` decoder for
`coach-real-user-transfer-outcomes-v2.json`. The real-user transfer row only
counts when the sidecar matches `coach-transfer-outcome-ledger-v2`, includes at
least 10 completed off-app outcome follow-ups across at least eight users, keeps
no user above two counted outcomes, covers at least four real-world moment
categories, ties each counted outcome to a real-world moment and a linked Noum
intervention, carries row-level intervention/moment/follow-up/audience/self-
report evidence references, waits at least 24 hours before follow-up, shows no
confidence regression, reports positive transfer, contains no adverse outcomes,
and includes no causal claims that Noum caused the result. Malformed sidecars
fail loudly, and weak, over-concentrated, or overclaiming sidecars leave
`noRealUserLongitudinalTransferOutcomes` in place. A clean loaded sidecar removes
only that blocker and raises the capped score to 20/100 while live-provider,
professional-calibration, real-device QA, and launch-ops blockers remain. The
current emitted manifest has no completed real-user transfer sidecar, so
observed count is 0 and the overall score remains **18/100**. Any v1 transfer
sidecar is now stale and should be regenerated against the v2 ledger.

2026-06-30 real-device and launch-ops evidence ingestion update:
The manifest now typed-decodes `coach-real-device-testflight-qa-v2.json` and
`coach-operational-launch-checklist-v2.json` from the same evaluation dump
directory. The real-device/TestFlight sidecar only counts when all four VISION
high-risk surfaces pass on a physical TestFlight build: Live Activity, AI prompt
latency, soundscape audio session, and paywall purchase. Each required surface
must be marked real-device, TestFlight-installed, blocking-issue free, tied to
the same build, backed by the expected evidence artifact type, timestamped,
linked to a device identity hash, and, for AI prompt latency, within the 3,000 ms
budget, with no crash or readiness-warning escape hatch. The
launch checklist sidecar only counts when `m14-launch-gate-v2` is complete for
Firestore rules deployment, hosted privacy policy URL, Settings privacy URL,
App Store privacy-disclosure review, uploaded TestFlight build, and
release-blocking bug triage, with the expected artifact kind, environment,
release-candidate build, verifier identity, and command/review output reference
for every item. Malformed sidecars fail loudly, and rejected sidecars leave
their blockers in place. Clean loaded sidecars remove only their own blockers.
The current emitted manifest has neither sidecar, so
`realDeviceTestFlightVerification` and `operationalLaunchChecklist` remain
missing and the overall score remains **18/100**.

The focused corpus/audit XCTest now writes the current JSON artifact set to
`/private/tmp/noum-coach-eval` by default, while still accepting overrides from
`NOUM_COACH_EVAL_DUMP_DIR`, `SIMCTL_CHILD_NOUM_COACH_EVAL_DUMP_DIR`,
`-NOUM_COACH_EVAL_DUMP_DIR <path>`, or the matching `UserDefaults` launch key.
The generated files are:
`coach-chat-conversation-eval-v10.json`,
`coach-chat-conversation-expert-calibration-v2.json`,
`coach-chat-conversation-app-path-eval-v1.json`,
`coach-chat-long-form-conversation-eval-v1.json`, and
`coach-chat-long-form-adversarial-eval-v1.json`, and
`coach-chat-live-app-path-eval-v1.json`, plus
`coach-vision-production-readiness-evidence-manifest-v1.json`. The latest text
app-path artifact reports `passesAppPathFloor: true`, `surface: text`, score
**18/100** under the VISION audit cap, 0 app-path floor failures, 0
target-reply mismatches, 0 semantic-gate failures, 0 accepted fallback turns, 0
typed-assessment fallback turns, 0 blocking quality-gate failures, 0 reliability
issues, and 0 vision-floor failures. The quality-gate event/family counts are
`passed: 39`; readiness warnings are empty. The latest live app-path artifact
reports `passesAppPathFloor: true`, `surface: live`,
`immediateCoachReadExpectedCount: 39`, `immediateCoachReadMissingCount: 0`, and
the same clean quality/semantic/reliability/vision-floor summary. The manifest
keeps the score at **18/100** and lists five unresolved readiness blockers. The
latest long-form artifact reports 10 conversations, 10 passing the local
conversation floor, 10 passing the offline production-floor projection, 0
runtime issues, 0 semantic issues, 0 reliability issues, and summary gate counts
that make those blockers visible in the JSON. The adversarial long-form artifact
reports 10 paired full conversations, 0 passing the offline production-floor
projection, and specific semantic/reliability/runtime failure buckets. These
are local scripted replay results, not live-provider, professional-calibration,
real-user outcome, real-device, or launch-ops evidence. The expert-calibration
packet in the same dump currently reports 23 pending review rows, split across
13 short conversations and 10 five-turn long-form conversations.
Optional external sidecars can be placed in the same dump directory for the
manifest to ingest:
`coach-live-eval-v1.json`,
`coach-chat-conversation-expert-calibration-results-v2.json`,
`coach-real-user-transfer-outcomes-v2.json`,
`coach-real-device-testflight-qa-v2.json`, and
`coach-operational-launch-checklist-v2.json`.

## Research Anchors

- LLMs Get Lost In Multi-Turn Conversation reports that multi-turn performance
  drops sharply versus single-turn settings, with unreliability and failure to
  recover after early wrong turns as the dominant issue. This supports running
  app-path full conversations, not only isolated target replies.
  https://arxiv.org/abs/2505.06120
- IMBUE found that simulation plus just-in-time feedback improved skill mastery,
  while simulation alone did not transfer as well.
  https://arxiv.org/abs/2402.12556
- CARE found practice with structured feedback improved counselor behaviors more
  reliably than practice alone.
  https://arxiv.org/abs/2505.02428
- LLM motivational interviewing work reinforces that empathy, adherence, and
  actionability need separate measurement.
  https://arxiv.org/abs/2505.17362
- Recent production multi-turn judge work found automated judges can miss
  cross-turn state/recovery defects even when turn-local scoring looks clean;
  this is why the conversation report has explicit state-retention and
  non-repetition gates instead of only averaging single-turn scores.
  https://arxiv.org/abs/2606.10315
- 2026 multi-turn reliability work reports sharp reliability degradation when
  global instructions, tool choices, or structured state have to survive longer
  conversations with distractions; this supports replaying target conversations
  across history rather than scoring isolated replies.
  https://arxiv.org/abs/2603.01423
- RankJudge's paired-conversation construction injects one flaw into one turn so
  the evaluator can isolate the failure category. The corpus now mirrors that
  pattern with paired reliability variants for near-duplicate, repeated
  proof-test, and no-attunement trust-repair smells.
  https://arxiv.org/abs/2605.21748

## Scoring Contract

Machine scoring path:

- `AICoachChatService.coachVisionEvaluation(...)`
- `AICoachChatService.visionQualityIssue(...)` is the runtime gate for
  critical misses and clearly weak scores.
- `CoachLiveEvaluationTests.liveGeminiRepliesClearFixtureRubric` now treats
  `CoachReliabilityGate` issues as live production-floor failures rather than
  diagnostic-only lines. A live transcript with a near-duplicate answer,
  no-attunement trust repair, repeated proof test, scaffold leak, or flat
  confidence-with-evidence smell is not green even if its rubric and vision
  score pass. The pure `liveProductionFloor(...)` helper is covered by
  skipped-provider tests, so this contract is verified without spending live AI
  calls.
- The live fixture sweep now carries recent assessment proof tests across
  fixtures before building the next `CoachAssessment`, mirroring the app
  pipeline's history-based `recentProofTests` handoff. This prevents the live
  transcript artifact from manufacturing the exact repeated-proof-test smell
  the production pipeline is designed to avoid. The same sweep also passes a
  normalized `proofTestRecentlyRepeated` flag into `CoachReliabilityGate`, so a
  repeated proof test fails the live production floor as `repeatedProofTest`.
- `CoachLiveEvaluationTests` now writes a `coach-live-eval-v1` JSON sidecar
  next to the markdown transcript. Rows include fixture ID, user turn,
  provider routing, latency source, assessment freshness/confidence/proof hash,
  trust-friction flags, diagnostics, accepted reply word count, rubric/vision
  scores, semantic gate issue, reliability issues, `liveProductionFloor`, and
  failure text for failed turns. Its run-level `summary` also records failure
  count/fixture IDs, proof-hash variety, repeated proof-hash count, confidence
  range and rounded diversity, reply-word-count range/average, expected-vs-shown
  immediate local coach reads, retry/refusal pressure, first-visible latency
  range, and trust-friction counts. It derives
  typed `readinessWarnings` for no-row runs, production-floor failures, repeated
  proof hashes, flat confidence, uniform reply length, missing expected
  immediate coach reads, retry/refusal pressure, and slow first-visible latency;
  `passesRunReadinessFloor` requires both clean row-level gates and no run-level
  warnings. This is a live-eval health floor, not a human-coach parity claim.
  Provider-only transcript captures may honestly fail this floor until they
  exercise `CoachReplyPipeline`'s provisional-read branch; that is the point of
  separating provider quality from actual app-path real-time behaviour. The
  sidecar is redacted: no prompts, API keys, request bodies, or failed draft
  text.
- `CoachReplyPipelineProvisionalReadTests` now exercises that app path with an
  isolated `AskNoumStore` and a no-provider `AICoachChatService`: the live
  pipeline must render the deterministic immediate coach read into the pending
  row before the final typed provider notice, and final metadata must preserve
  `immediateCoachReadShown=true`. This proves the local-read branch is wired,
  while still leaving live provider quality to the transcript harness.
- The same suite now also runs a successful two-turn text pipeline through an
  isolated `AskNoumStore` plus scripted OpenAI transport. A repeated pacing
  question must land as two real coach rows, carry typed assessment metadata on
  both rows, read the first row's prior proof test through `replayForModel`, and
  choose a different second proof test with `proofTestRecentlyRepeated=false`.
  This closes the gap between lower-level assessment-cache variation and the
  actual app thread path.
- Skipped-provider live-harness tests now replay the latest transcript fixture
  set through the deterministic judgement pass and require non-flat
  `assessmentConfidence`, varied proof tests, and varied direct verdicts before
  any provider call is made. This directly guards the "0.20 confidence / same
  proof test / same verdict" failure mode from the research report.
- `CoachTurnMetadata.qualityGateOutcome` records whether the final user-visible
  reply passed cleanly, was repaired, used a fallback, or failed, plus compact
  failure/repair counts. It stores gate labels only, never failed draft text.
- `CoachChatEvaluationCIReport` schema v5 now includes turn depth, runtime-gate
  booleans, reference reliability issues, reference reliability pass/fail, and
  a strict `referencePassesProductionFloor` conjunction across rubric, quality
  gate, vision floor, runtime vision gate, and reliability cleanliness. CI
  artifacts now expose the production-floor decision in addition to raw vision
  scores; this is still evaluation substrate, not a launch-readiness claim.
- `CoachChatConversationEvaluationReport` schema v10 scores the current
  three-turn
  target transcripts against a zero-start conversation rubric: direct answer,
  evidence calibration, observable anchor, prescribed practice, rationale
  bridge, follow-up continuity, state retention, non-repetitive trajectory,
  proof-test progression, adaptive repair, repair carryover, transfer proof,
  senior register, and brevity. Known-bad variants must remain far below target
  transcripts; stale state variants must fail the state-retention gate even when
  they do not repeat the exact same reply; repeated-proof variants must fail the
  proof-test progression gate even when the rest of the reply still reads
  coherently. Generic advice, evidence overclaims, and pasted-same-reply
  conversations are hard-capped below the passing band so a plausible local
  answer cannot masquerade as a competent multi-turn coach. Report rows now
  include the full three-turn transcript, per-turn vision scores,
  `passesRuntimeGate`, `passesSemanticGate`, `passesReliabilityGate`,
  `passesProductionFloor`, `turnRuntimeIssues`, flattened `runtimeIssues`,
  `turnSemanticIssues`, flattened `semanticIssues`, `turnReliabilityIssues`, and
  flattened `reliabilityIssues`, plus `turnDepths`, `trustRepairTurnIndices`,
  `userPushbackWithinTwoTurns`, `coldnessComplaintFlag`, and
  `coldnessComplaintTurnIndices`, so reviews can inspect the actual
  conversation, runtime gate projection, typed semantic judgement projection,
  trust-friction signals, and last-mile reliability replay rather than only a
  pass/fail summary.
  `passesProductionFloor` is the offline conjunction of conversation floor,
  runtime gate cleanliness, semantic gate cleanliness, and reliability
  cleanliness; it is not a live-provider readiness claim.
  The report now also includes `visionProductionReadiness`, which explicitly
  marks the artifact as `localEvaluationSubstrateOnly` with score 18/100 and
  blockers for missing live-provider sweep, professional coach calibration,
  real-user longitudinal outcomes, real-device TestFlight QA, and launch
  checklist completion.
- `CoachChatConversationExpertCalibrationPacket` schema v2 turns the current
  professional-calibration corpus into a human-review work packet: 13 short
  three-turn conversations plus 10 five-turn long-form conversations. It is the first concrete
  professional-calibration artifact for multi-turn Ask Noum conversations, but
  it remains substrate only until an actual coach fills the packet and the
  results are compared against longitudinal user outcomes.
- `CoachChatConversationAppPathReport` schema v1 turns the same short corpus
  into a scripted app-path replay through `AskNoumStore` +
  `CoachReplyPipeline`. The report exists because service-only target replies
  can pass while the shared pipeline still substitutes typed-assessment
  fallback copy on follow-up turns. Its per-turn `qualityGateEvents` expose the
  redacted gate timeline (`passed`, `repaired:<gate>`, `rejected:<gate>`,
  `fallback:<gate>`, `failed:<gate>`) before final metadata is collapsed. Its
  summary adds `qualityGateEventCounts`, `qualityGateFamilyCounts`, and
  `nonCleanQualityGateEvents` so a report reader can see the dominant failure
  class before opening per-turn rows. It also distinguishes accepted fallback
  from blocking failure with `acceptedFallbackTurnCount`,
  `typedAssessmentFallbackTurnCount`, and
  `qualityGateBlockingFailureTurnCount`, plus `visionFloorFailureTurnCount`,
  so a future drift can separate a target mismatch, semantic failure,
  reliability issue, fallback, hard block, or vision-floor miss. Its
  readiness warnings are intentionally first-class (`appPathFloorFailures`,
  `targetReplyMismatch`,
  `semanticGateFailures`, `visionFloorFailures`, `missingTurnMetadata`,
  `missingImmediateCoachRead`, etc.), and the report serializes
  `visionProductionReadiness` so even a green local app-path replay cannot be
  mistaken for live provider proof.
- `CoachChatConversationAppPathReport` also has a live-surface sibling,
  `coach-chat-live-app-path-eval-v1`, which uses `surface: live` on the same
  shared pipeline and fixture set. Its purpose is not to score provider prose;
  it proves the two-speed local-read branch that provider-only captures cannot
  observe. The live artifact must show every expected `immediateCoachReadShown`
  row, local first-visible latency under the guard, clean quality/semantic/
  reliability gates, and the same `visionProductionReadiness` cap.
- `CoachChatConversationEvaluationReport` can also be generated as
  `coach-chat-long-form-conversation-eval-v1` for the 10 five-turn local
  conversations. That report reuses the same row schema and production-floor
  conjunction as v10, but its manifest contribution is local substrate only:
  10/10 passing the conversation floor earns the long-form coverage row. The
  current artifact also reports 10/10 passing the local offline production-floor
  projection with empty runtime/semantic/reliability issue buckets, but this
  still does not remove any VISION launch blocker.
- `coach-chat-long-form-adversarial-eval-v1` uses the same report schema for
  paired negative controls. It must not be counted as earned readiness evidence:
  every row is expected to fail because the fixtures intentionally inject
  stale-state, repeated-proof, missed-intent, or no-attunement coach behavior
  into otherwise full end-to-end conversations.
- `CoachVisionProductionReadinessEvidenceManifest` schema v1 is the top-level
  launch-evidence ledger. It lists earned local artifacts separately from
  pending/missing production evidence, so a green target corpus, green text
  app-path replay, and green live immediate-read replay cannot erase the missing
  live-provider sweep, human coach calibration, real-user outcomes, real-device
  QA, or launch operations. Its live-provider evidence row now accepts only a
  decoded, clean `coach-live-eval-v1` sweep covering the 20 latest-turn fixture
  rows plus the 10 full live long-form conversations, all four turn-depth
  classes, provider/model evidence, varied assessment confidence, varied
  proof-test hashes, and no run-level readiness warnings; a raw count,
  partial/easy-turn sweep, or latest-turn-only sweep does not clear the blocker.
  The live harness can now generate the required sidecar in one manual provider
  run with `NOUM_LIVE_AI_FIXTURES=readiness`, and the corpus/audit artifact
  writer auto-loads that sidecar from the evaluation dump directory when it
  exists, so a real live run can feed the ledger without hand-editing the
  manifest. Its professional-coach evidence
  row likewise accepts only a completed
  `coach-chat-conversation-expert-calibration-results-v2.json` sidecar with a
  matching source packet schema, source packet fingerprint, and rubric, two
  independent professional coach review rows for every conversation in the
  current 23-conversation calibration corpus, no unexpected conversation IDs,
  coherent nonblank reviewer IDs/counts, no duplicate reviewer/conversation
  pairs, no readiness warnings, no unsafe rows, no
  unresolved revision notes, and every counted row meeting the calibrated
  coach-parity floor; the pending review packet itself remains non-launch
  evidence. Its real-user
  transfer row now accepts only a completed
  `coach-real-user-transfer-outcomes-v2.json` sidecar with at least 10 qualifying
  off-app follow-ups across at least eight users, no more than two counted
  outcomes from any one user, at least four real-world moment categories,
  linked interventions, row-level evidence references, at least 24 hours between
  moment and follow-up, audience-response evidence, no confidence regression, no
  adverse outcomes, and no causal overclaim; local scripted conversations still
  cannot satisfy the transfer blocker. Its real-device/TestFlight row now
  accepts only `coach-real-device-testflight-qa-v2.json` with all required
  high-risk surfaces passing on the same physical TestFlight build, the expected
  evidence artifact kind per surface, usable capture timestamps, device identity,
  and AI prompt latency at or below 3,000 ms, with no blocking issues, crashes,
  or readiness warnings. Its launch-ops row now
  accepts only `coach-operational-launch-checklist-v2.json` with the
  `m14-launch-gate-v2` checklist complete for deployment, privacy, TestFlight,
  and release-triage items, again with expected artifact kinds, environment,
  release-candidate build, verifier identity, command/review outputs, and no
  readiness warnings.
- The manifest also carries `adversarialNegativeControlCorpus` as local
  evaluator-integrity evidence. It must observe 10/10 paired adversarial
  long-form conversations rejected by the production floor; it has no blocker
  and no production-score lift.
- Paired reliability variants now inject one near-duplicate second turn, one
  repeated proof-test trajectory, and one trust-repair-without-attunement case.
  Those variants must trip `nearDuplicateReply`, `repeatedProofTest`, and
  `noAttunementOnPushback` respectively, while the target transcripts must
  remain reliability-clean. The report must mark those reliability variants as
  failing `passesProductionFloor` even when their prose still reads plausibly.
- `CoachReliabilityGate` no longer treats any bare "let me..." opening as trust
  repair. "Let me give you the drill..." still trips `noAttunementOnPushback`;
  only repair-specific openings such as "let me repair/fix/correct..." count,
  and the issue now blocks with a deterministic trust-repair fallback.
- `CoachReplyPipeline` quality-gate aggregation is pinned for rejected-then-pass,
  rejected-then-repair, rejected-then-fallback, and final failure paths.
- Trust-repair turns now carry `CoachAssessment.toneMode = repair` and an
  optional `repairFocus`; soft pushback such as "Okay, that's cool. However..."
  routes to trust repair after a coach reply. Provider verbalisation and the
  semantic gate must name that repair focus before prescribing another drill.
- Trust repair must now include a concrete coach read, not only a style repair.
  If a focused repair reply acknowledges "cold/robotic/generic" feedback and
  jumps straight to a proof test without a behavioral signal, evidence anchor,
  or actual read, the semantic gate fails it as `missingRepairInsight`. Broad
  glue words such as "because", "target", or "behavior" no longer count by
  themselves; the reply must touch non-repair evidence or state the actual
  coach read explicitly.
- Turn metadata now persists `assessmentCacheHit`, `assessmentCacheAgeMs`,
  `immediateCoachReadShown`, `replyWordCount`, `providerTierChosen`, `providerAttemptCount`,
  `providerRefusalCount`, a real `providerRetryCount` derived from provider
  events rather than quality-gate failures, plus explicit
  `timeToFirstVisibleTokenMs` and `timeToCompleteReplyMs` aliases matching the
  research telemetry list for proving two-speed readiness, freshness, latency,
  routing, and reply-shape variation.
- The live transcript harness now prints and JSON-encodes that same turn-level telemetry:
  provider attempt/retry/refusal counts, first-visible latency with an explicit
  source (`streamedPartialVisible`, `providerFirstTokenDiagnostic`,
  `completedReplyProxy`, or `unavailable`), completion latency, proof-test
  hash, `immediateCoachReadShown`, `replyWordCount`, `userPushbackWithinTwoTurns`,
  `coldnessComplaintFlag`, `softPushbackFlag`, and `voiceBargeInOccurred`. The
  text harness records `immediateCoachReadShown: false` rather than implying a
  two-speed live read happened outside the app pipeline.
- Turn metadata now also persists `softPushbackFlag`, matching the v10
  transcript report's `softPushbackFlag` / `softPushbackTurnIndices` fields, so
  live saved threads can distinguish "okay, however..." hesitation from
  explicit coldness complaints.
- AI-call diagnostic reason text now keeps a wider bounded payload so the
  trust-loss fields survive in the debug record instead of being truncated
  before review.
- `semanticGateIssue` is persisted separately from the final semantic outcome,
  so a repaired answer can still show which judgement issue was caught before
  the user saw the final reply.
- `AICoachChatService.replyQualityIssue(...)` now accepts recent coach replies
  and trips `professional:repeatedProofTest` when a provider repeats the same
  action/proof-test sentence from the recent thread. The repair prompt receives
  compact recent-action fingerprints and must vary the target, condition, or
  evidence check before the reply can be accepted.
- `CoachAssessmentCache` now wraps the deterministic reasoning pass, keyed by
  turn depth, normalized user turn, trajectory signature, active rubric, recent
  proof tests, and previous coach reply. `assessmentCacheAgeMs` now measures
  the typed judgement object's age, not the trajectory snapshot age.
- `PracticeSessionFinalizer` now prewarms `UserTrajectoryCache` after the
  session, baseline, and rating writes land, so the first Ask Noum turn after a
  rep should report a warm trajectory snapshot. The later summary/coach-memory
  lifecycle still refreshes the cache with the richer durable case formulation.
- When a user sends trust-repair pushback after a coach reply, the prior coach
  row now records `userPushbackWithinTwoTurns`; cold/generic/robotic/low-EQ
  complaints additionally set `coldnessComplaintFlag`, while polite
  "okay/however" resistance sets `softPushbackFlag`, giving transcript audits a
  direct trust-loss signal instead of treating every pushback as identical.
- Live-call barge-ins now set `voiceBargeInOccurred` on the interrupted coach
  row and preserve it if the user interrupts the immediate local read before
  final provider metadata arrives.
- 100-point score starts at zero and earns criteria:
  direct answer, observable anchor, prescribed action, insight bridge,
  evidence honesty, adaptive repair, personalization, transfer proof, senior
  register, and brevity.
- Production floor: `score >= 85` and no critical misses.
- Runtime reject floor: critical misses always reject; non-live text replies
  below 70 reject; text deep-assessment replies below 74 reject; live replies
  use a lower reject floor so the spoken surface does not become brittle.
- Runtime gate scope: applies to coaching, judgement, critique, deep-assessment,
  and action-seeking turns. Simple acknowledgements such as "thanks" are not
  forced through the coaching-answer rubric.
- Hard caps: unsupported evidence or robotic register cannot exceed 44; missing
  anchor or action cannot exceed 48; missing bridge cannot pass production.

Manual score below is intentionally harsh. The machine corpus score now runs as
`CoachChatConversationCorpusTests`; live provider transcripts are still required
before this becomes production evidence.

## Conversation 1 - Cold Start Interview Baseline

Fixture: `cold-start-interview-baseline`

Context: no profile voice, no rated sessions, no stable baseline.

Transcript:

User: How do I get better before my interview?

Noum target: No baseline yet, so the honest move is one interview rep. Record 60
seconds on a likely question, then review whether the first sentence gives the
point before polishing anything.

User: What should I listen for in the replay?

Noum target: For your first baseline rep, listen for sentence one only. If it
names the answer before the setup, keep it. If it starts with background,
rewrite that first sentence and run the rep again.

User: So not my whole speaking style yet?

Noum target: Right, because one rep is too thin for a style diagnosis. Use this
first pass to create the baseline, then Noum can judge whether the same pattern
repeats.

Manual vision grade: 86/100.

Why it passes: honest cold start, one practice move, no fake diagnosis, and a
clear answer when the user asks about scope.

Remaining gap: thin personalization until the interview type or a real rep is
available.

## Conversation 2 - Filler Under Pressure

Fixture: `filler-pressure-prescription`

Context: concise voice, recent timed rep had 6 fillers, trend says fillers are
worse under pressure.

Transcript:

User: How do I stop saying um under pressure?

Noum target: Last rep had 6 fillers; the pressure cue is showing up before the
close. Next rep, hold one beat before the final sentence and check whether
fillers drop after that point.

User: Do I pause before every sentence?

Noum target: No, because the pause belongs where the pressure leaks: before the
close. If you pause everywhere, the answer will sound managed instead of steady.

User: What proves it worked?

Noum target: Use the same 60-second prompt and timer because you only want to
test the pause point. Success is fewer fillers after that point and a final
sentence that still lands cleanly.

Manual vision grade: 84/100.

Why it passes: grounded metric, specific replacement behavior, pressure-aware
boundary, and proof criteria.

Remaining gap: "cut every filler" is slightly absolute; better wording would
test whether the count drops after that point.

## Conversation 3 - Metric Without Coaching Read

Fixture: `metric-action-without-read`

Context: authoritative voice, recent rep had 5 fillers inside the decision line.

Transcript:

User: What should I do with that filler count?

Noum target: Last rep had 5 fillers; the signal is inside the recommendation,
not before it. Next rep, hold one beat after the decision line and restart if a
filler appears.

User: Why after the decision line?

Noum target: Because the filler is interrupting the moment where authority
should sound settled. The pause after the decision gives your reason somewhere
to go without weakening the recommendation.

User: What do I run next?

Noum target: Use a 45-second recommendation prompt because it tests the decision
line without inviting a full essay. Sentence one is the decision, sentence two
is one reason, then stop cleanly.

Manual vision grade: 88/100.

Why it passes: treats the metric as evidence, not the whole read, and converts
the read into a sequence-level prescription.

Remaining gap: "restart if a filler appears" may feel rigid in live mode.

## Conversation 4 - Robotic Writing Trust Repair

Fixture: `critique-trust-repair`

Prior Noum reply: Recent reps show a decline in scores, so you should optimize
your communication plan.

Transcript:

User: This is robotic and too much writing.

Noum target: Fair push: that read was robotic and too much writing. The last rep
gives enough signal; next rep, use one clean opener and stop after the point
lands.

User: What was generic about it?

Noum target: That was generic because it named a plan without naming the behavior.
The target is the opener: run a 45-second rep where sentence one lands before
the explanation starts.

User: Give me the short version.

Noum target: Short version: the opener is the target because the prior reply
buried the behavior. Open with the point, add one reason, then stop. Run that
once and check whether sentence one lands before any setup.

Manual vision grade: 82/100.

Why it mostly passes: acknowledges the friction, explains the miss, and returns
to one action.

Remaining gap: first repair is still a little written; the final short version
is closer to the desired register.

## Conversation 5 - Markdown/TTS Trust Repair

Fixture: `markdown-tts-trust-repair`

Prior Noum reply: **Read:** Your last rep has fillers. **Move:** practice more.

Transcript:

User: The ** don't format and TTS reads them out. The responses feel robotic and
cold, nowhere near an expert coach.

Noum target: Fair push: the asterisks should never reach you or the voice, and
that made the coaching feel robotic and cold. Your last rep had 4 fillers, so
for the next rep, state the recommendation first, give one proof, then stop. No
symbols, no report shape.

User: And stop saying "practice more."

Noum target: Agreed: that was too generic. The move is not more volume; the
target is a cleaner first sentence because it turns vague advice into a testable
line: recommendation, one proof, stop.

User: What should I record?

Noum target: Record one 45-second answer to a recommendation prompt because it
tests whether the first sentence carries the recommendation. If sentence one is
not the recommendation, restart.

Manual vision grade: 87/100.

Why it passes: repairs the exact UI/TTS failure, rejects generic advice, cites
real evidence, and prescribes one changed move.

Remaining gap: still target-shaped; the live provider must consistently avoid
symbolic formatting.

## Conversation 6 - Assistant Explainer Register

Fixture: `assistant-explainer-register`

Prior Noum reply: Here are some tips to communicate more clearly: be clear and
concise and practice often.

Transcript:

User: This still sounds cold and overexplained, like generic AI tips.

Noum target: Fair push: that was advice, not coaching. Your last rep has the
useful signal: warmth came before the recommendation, so next rep say the
recommendation first, then soften it with one reassurance.

User: Does that make me sound less warm?

Noum target: No. The target is placement, not less warmth: lead with the
decision so people know what you mean, then use warmth to make the decision
easier to hear.

User: Give me the pattern.

Noum target: Next rep, say: recommendation, one reason, one reassurance, then
stop, because it keeps warmth after clarity.

Manual vision grade: 91/100.

Why it passes: names the felt failure, uses the actual transcript pattern, and
preserves warmth without letting it bury the recommendation.

Remaining gap: live tone still needs provider verification.

## Conversation 7 - Authoritative Distance Assessment

Fixture: `authoritative-distance-deep-assessment`

Context: authoritative voice, one 7/10 timed rep, 1 filler, no repeated pressure
evidence.

Transcript:

User: How far off am I from sounding authoritative?

Noum target: You are closer mechanically than you are to sounding authoritative
overall. The transcript opens with a recommendation, and the latest timed rep
was 7/10 with 1 filler, so the mechanics are partly landing, but goal readiness
still needs repeated pressure evidence. Missing: more than one clean rep under
stakes. Proof test: record a 75-second answer with the verdict in sentence one,
one reason, and a clean stop.

User: Is 7/10 bad?

Noum target: No. 7/10 means the mechanics are not the bottleneck yet. The open
question is whether the same steadiness survives a more consequential prompt.

User: What would make you change the diagnosis?

Noum target: Record 2 clean pressure reps with verdict-first openings because
that is the evidence that would move the diagnosis from mechanics to presence:
less explaining, more settled commitment.

Manual vision grade: 93/100.

Why it passes: separates score from goal readiness, names missing evidence, and
uses repeated pressure evidence as the threshold for stronger judgment.

Remaining gap: should be checked with `assessment.confidence` in the live report
to avoid over-reading one rep.

## Conversation 8 - What Next

Fixture: `what-next-single-move`

Prior Noum reply: Which direction would you prefer?

Context: executive voice, recent clean rep, trend says close lost force.

Transcript:

User: What next?

Noum target: The pattern I'd pick is the rushed close. Review the last
transcript, rewrite only the final sentence, then run one rep with that close as
the target.

User: Why the close instead of the opening?

Noum target: In the last transcript, the opening is serviceable enough. The close
is where the authority leaks because the answer ends as a summary instead of an
ask.

User: What is the exact rep?

Noum target: 60 seconds, same topic, because it isolates the close. Last sentence
must be the ask. If it turns into a recap, run it once more.

Manual vision grade: 86/100.

Why it passes: chooses one move instead of a menu and explains why that move
wins over another possible focus.

Remaining gap: could cite the trend more concretely: "close lost force in recent
reps."

## Conversation 9 - Overclaim Boundary

Fixture: `overclaim-hypothesis-boundary`

Context: authoritative voice, recent transcript says the recommendation arrived
late.

Transcript:

User: Why did that answer land badly?

Noum target: From the transcript, I would treat it as a hypothesis: the
recommendation arrived late. Next rep, say the conclusion first, then add one
reason.

User: So I am not bad at authority?

Noum target: I would not claim that from this transcript. The observable issue
is order: the listener waits too long for the conclusion.

User: What test separates those?

Noum target: Run the same answer verdict-first because it separates structure
from authority. If it lands better with the same voice and filler count, the
issue was structure, not authority.

Manual vision grade: 85/100.

Why it passes: frames the read as a hypothesis, avoids trait labels, and gives a
disconfirming test.

Remaining gap: could add one more real-world transfer prompt for stronger proof.

## Conversation 10 - Leadership Transfer Setup

Fixture: `leadership-transfer-setup`

Context: executive voice, upcoming leadership update, recent timed rep solid on
fillers but light on close.

Transcript:

User: I have a leadership update tomorrow, what should I practice?

Noum target: Your recent timed rep was solid on fillers but light on the close.
Record a 75-second leadership update and make the final sentence the ask, not a
summary.

User: I do not know the ask yet.

Noum target: For the 75-second update, use a placeholder ask: "I need alignment
on the next step," because it lets you train the shape of the close before the
business content is final.

User: What should I check after?

Noum target: Check only the final 10 seconds of the 75-second update, because
that is where the update transfers into the room. If the last sentence asks for
alignment or a decision, keep it; if it recaps, rewrite the close.

Manual vision grade: 89/100.

Why it passes: bridges recent practice into tomorrow's real situation and gives
an action even when the exact business ask is unknown.

Remaining gap: could name the actual ask if known from BigMoment or ForwardPlan
context.

## Conversation 11 - Answer Depth One Example

Fixture: `answer-depth-one-example`

Context: executive voice, recent vendor recommendation, 0 fillers, trend says
answers need one concrete example before they expand.

Transcript:

User: How do I add depth without rambling?

Noum target: Your last rep has strong reasons; the signal is no concrete example
for the listener to picture. Next rep, keep the same claim, add one example,
then stop before adding a second thread.

User: Can you give me an example of me doing this in sessions?

Noum target: In the vendor rep, you said implementation risk was lower and the
team already knew the workflow. Those are reasons, not a picture, so add one
concrete example after the first reason, then stop.

User: What should I record?

Noum target: Record the same executive recommendation in 60 seconds because it
isolates answer depth. Sentence one is the claim, sentence two is one reason,
sentence three is one example, then stop.

Manual vision grade: 88/100.

Why it passes: answers the user's example request with a specific prior-session
signal, distinguishes reasons from a concrete example, and keeps the next drill
bounded.

Remaining gap: still target-shaped; live replies must cite examples without
fabricating quotes or turning into a transcript report.

## Conversation 12 - Polite Pushback Attunement

Fixture: `assistant-explainer-register`

Context: warm voice, client concern rep where reassurance came before the
recommendation, and the previous coach answer sounded like generic tips.

Transcript:

User: Okay, that's cool. However, I don't feel like that answered what I meant.

Noum target: Fair push: that was generic advice instead of evidence, and there
is friction underneath the polite pushback. The actual read is warmth came before
the recommendation, so the listener waits for the point. Next rep, say the
recommendation first, then one reassurance.

User: What did you miss?

Noum target: I missed the hesitation in your pushback. Your last rep gives the
actual read: the comfort came first and the point arrived late. You were asking
for that behavior, not a harder drill.

User: How do I test that without sounding harsh?

Noum target: Run one 45-second client concern answer. Sentence one is the
recommendation; sentence two is one reassurance. That tests order without
removing warmth, because the tone stays kind while the point arrives first.

Manual vision grade: 87/100.

Why it passes: treats "okay, however" as a trust signal, names the hesitation
before prescribing, keeps warmth as a goal rather than flattening the user into
a harder-drill frame, and gives a bounded proof test.

Remaining gap: still target-shaped; live replies must show the same attunement
without sounding self-referential or scripted.

## Conversation 13 - Baseline Shift Cache Freshness

Fixture: `baseline-shift-cache-freshness`

Context: authoritative voice, same latest session as the prior turn, but the
rolling baseline has shifted from a low-filler read to a higher filler/hedging
read after more qualifying reps were imported.

Transcript:

User: Should I keep doing the same drill if my filler baseline got worse?

Noum target: Do not reuse the old read. Your current baseline says fillers and
hedging are the pressure leak now, so keep the drill narrower: one 45-second
answer, verdict first, then stop after one reason.

User: So the previous advice was wrong?

Noum target: Not necessarily. It matched the older evidence. The coaching move
changes because the baseline moved: when fillers and hedging rise together, the
first proof test should be a shorter answer, not a broader plan.

User: What would count as improvement?

Noum target: Improvement is one rep below your current filler baseline while
the first sentence still gives the point. If the filler count drops but the
verdict disappears, that is not the win.

Manual vision grade: 86/100.

Why it passes: treats changed baseline evidence as a reason to revise the
coaching move, avoids claiming the earlier advice was objectively wrong, and
defines a proof test that preserves communication quality instead of optimizing
only filler count.

Remaining gap: target-shaped only; the live path still needs provider evidence
that same-session/same-confidence baseline changes surface this freshly without
stale cache reuse.

## Conversation 14 - Account Baseline Isolation

Fixture: `account-baseline-isolation`

Context: a signed-out/signed-in transition where the prior account had a strong
authoritative baseline, while the current account has only a cold first rep and
no stable baseline yet.

Transcript:

User: Am I already close to sounding authoritative?

Noum target: I would not borrow the previous baseline here. For this account,
there is not enough evidence yet, so the honest read is one first-rep signal:
you need a verdict-first opener before Noum can judge authority over time.

User: But the app said the baseline was strong earlier.

Noum target: That was a different evidence set. For this thread, treat the
baseline as unproven. Record one 60-second answer and check only sentence one:
does it name the recommendation before the background?

User: What should the coach remember after that?

Noum target: Remember the observable result, not a trait label. If sentence one
names the recommendation, the next test is pressure; if it starts with context,
the next intervention stays on structure.

Manual vision grade: 88/100.

Why it passes: refuses cross-account evidence borrowing, calibrates confidence
to the current user's evidence, and gives a follow-up memory rule that preserves
hypothesis language.

Remaining gap: target-shaped only; real production proof still needs account
switch QA and a live Ask Noum transcript after sign-out/sign-in.

## Conversation 15 - Rating Evidence Isolation

Fixture: `rating-evidence-isolation`

Context: the previous account had a Gold-tier rating and visible week peak, but
the current account has no rated pressure sessions. Ask Noum must not use the
old rating to sound more certain.

Transcript:

User: Since my rating was high, should I skip the basics?

Noum target: Not from this account's evidence. I do not have rated pressure
sessions here yet, so do one baseline pressure rep before skipping anything.
The test is verdict first, one reason, clean stop.

User: What if I really am already Gold level?

Noum target: Then the first pressure rep should make that obvious without me
borrowing the old tier. If the verdict stays first under pressure, Noum can
raise the plan; if it softens, the basics are still the right intervention.

User: What should the reply say after the rep?

Noum target: It should compare the rep to this account's rating evidence, not
the prior account's peak. If there is still no rated history, it should say
"first pressure signal" rather than "your rating shows."

Manual vision grade: 87/100.

Why it passes: separates rating evidence by account, avoids false confidence
from stale tier data, and gives a pressure proof test that can either confirm or
disconfirm readiness.

Remaining gap: target-shaped only; production proof needs live account-switch
QA plus stored metadata showing `rating.totalRatedSessions == 0` for the current
thread.

## Conversation 16 - Proof Quote Account Isolation

Fixture: `proof-quote-account-isolation`

Context: the prior account has archived transcript proof moments with quotable
lines, but the current account has no proof archive after account switch or
sign-out. Ask Noum must not quote or paraphrase the previous account's transcript
as evidence.

Transcript:

User: What exact line proved I sounded more executive last time?

Noum target: I do not have an exact proof line for this account yet, so I
should not quote one. The honest next step is a fresh 60-second answer; then I
can point to a specific sentence from that transcript.

User: I remember the app had a quote about "owning the tradeoff." Was that me?

Noum target: I cannot attach that quote to this account's evidence. Treat it as
unverified here. Record one answer and look for the observable version of that
skill: naming the tradeoff before the explanation.

User: What should the coach say if there is still no quote?

Noum target: It should say "no saved proof line yet" and coach from the current
rep's measurable behavior, not invent or reuse a quote. Once a proof moment is
saved here, it can cite that line directly.

Manual vision grade: 88/100.

Why it passes: refuses cross-account transcript quotes, preserves exact-evidence
honesty, gives a fresh proof-capture path, and avoids making the product sound
more certain than its stored evidence allows.

Remaining gap: target-shaped only; production proof still needs live
sign-out/sign-in QA plus a real Ask Noum transcript showing the proof archive is
empty for the current account.

## Conversation 17 - Live Sidecar Smoothed Reply Rejection

Fixture: `live-sidecar-smoothed-reply-rejection`

Context: an eval sidecar claims every live-provider row passed, but the rows
contain repeated generic reply text or gate telemetry that contradicts the pass.
The production-readiness manifest must reject the sidecar instead of treating it
as live evidence.

Transcript:

User: The live run says every row passed. Can we count it now?

Noum target: Not if the rows are smoothed. A live sweep only counts when the
reply text, rubric pass, vision pass, semantic gate, quality gate, reliability
gate, latency, and proof-test fields agree at row level.

User: What if the JSON says `liveProductionFloor: true` anyway?

Noum target: Then the decoder should still reject it when the row carries a
semantic issue, failed rubric flag, failed vision flag, reliability issue, or
generic duplicate reply. The boolean is not enough evidence by itself.

User: What should change in the score?

Noum target: Nothing yet. This makes the live-provider blocker harder to fake;
it does not satisfy the blocker. The score can move only after a real provider
sweep passes the stricter artifact contract.

Manual vision grade: 88/100.

Why it passes: keeps evaluation evidence falsifiable, refuses self-certified
readiness from contradictory telemetry, and protects against generic repeated
provider text being counted as human-coach-quality live output.

Remaining gap: target-shaped only; production proof still needs an actual
provider-generated `coach-live-eval-v1.json` with varied, clean, row-level
telemetry and detailed long-form conversations.

## Conversation 18 - Transfer Ledger Evidence Discipline

Fixture: `transfer-ledger-evidence-discipline`

Context: a closed-beta outcome export claims Noum helped users transfer a
practice intervention into real meetings, but the rows are over-concentrated in
a few users, collapse into one moment type, or rely on summary booleans without
evidence references. The production-readiness manifest must reject that ledger.

Transcript:

User: We have ten people saying the app helped before their real meetings. Does
that satisfy transfer?

Noum target: Not by itself. Transfer evidence has to show real moments, delayed
follow-ups, linked Noum interventions, audience-response evidence, and enough
independent users and moment types that the result is not just a smoothed beta
summary.

User: What if every row says `positiveTransferReported: true` and
`audienceResponseEvidenceCollected: true`?

Noum target: The row still needs proof references: the intervention, the real
moment, the follow-up, the audience-response evidence, and the user's own
reflection. A boolean without a reference is not enough to claim outside-app
transfer.

User: So should the readiness score move after this change?

Noum target: No. The stricter v2 ledger only defines what would count later.
Until real longitudinal outcomes arrive in that format, the transfer blocker
stays open and Noum must not claim coach-parity validation.

Manual vision grade: 89/100.

Why it passes: preserves the VISION distinction between local coaching quality
and demonstrated real-world transfer, rejects self-report-only evidence, and
keeps the product from implying causation or professional validation.

Remaining gap: target-shaped only; production proof still needs a completed
`coach-real-user-transfer-outcomes-v2.json` sidecar from real users with
auditable row-level evidence.

## Conversation 19 - Real Device QA Evidence Discipline

Fixture: `real-device-qa-evidence-discipline`

Context: a TestFlight QA summary says the high-risk launch surfaces passed, but
the evidence mixes build numbers, uses manual notes instead of surface-specific
artifacts, omits device identity, or records a live prompt latency outside the
target budget. The production-readiness manifest must reject that sidecar.

Transcript:

User: The TestFlight tester says Live Activity, latency, audio, and purchase all
passed. Can that clear device QA?

Noum target: Only if the rows prove it. Each high-risk surface needs a physical
device, the same TestFlight build, the right artifact type, a usable evidence
reference, a capture timestamp, and device identity. A summary pass is not
launch evidence.

User: What if the AI prompt row passed but latency was 4.2 seconds?

Noum target: Then it still fails. For the live coach path, the sidecar has to
show prompt latency inside the 3,000 ms text budget. A slow real-device pass
does not prove the coach feels live under pressure.

User: Does this raise the production score?

Noum target: No. It only defines the v2 proof standard. Until a real
`coach-real-device-testflight-qa-v2.json` is captured from TestFlight and passes
that contract, the real-device blocker stays open.

Manual vision grade: 88/100.

Why it passes: protects the M14 launch gate from QA summaries that hide mixed
builds, missing artifacts, simulator-adjacent evidence, or live-prompt latency
that would break the premium coach experience.

Remaining gap: target-shaped only; production proof still needs a completed
real-device TestFlight sidecar from an actual physical-device run.

## Conversation 20 - Launch Ops Evidence Discipline

Fixture: `launch-ops-evidence-discipline`

Context: the M14 checklist says Firestore rules, privacy URLs, App Store privacy
review, TestFlight upload, and bug triage are complete, but the rows only have
checked boxes and generic evidence links. The manifest must reject launch-ops
readiness unless each row has the expected artifact, environment, verifier, and
output proof.

Transcript:

User: The launch checklist is all checked off. Can we count M14 ops as done?

Noum target: Only if the checklist proves each item. Firestore rules need a
production deploy log, privacy needs a public URL probe, Settings needs release
candidate evidence, App Store privacy needs a review export, TestFlight needs
the build record, and triage needs a release-blocker report.

User: What if the release manager says they reviewed everything?

Noum target: The reviewer matters, but a reviewer note is not enough. Each row
also needs the command or review output, the expected environment, the matching
release-candidate build, and verification time. Otherwise it is a launch memo,
not launch evidence.

User: Does this make Noum production-ready?

Noum target: No. It only makes the ops blocker harder to fake. Until the real
v2 checklist is captured and the live-provider, coach-calibration, transfer,
and device blockers are also cleared, Noum should keep the production score at
18/100.

Manual vision grade: 88/100.

Why it passes: preserves the distinction between code readiness and operational
readiness, uses artifact-backed launch evidence, and refuses to let a completed
checklist imply coach-parity validation.

Remaining gap: target-shaped only; production proof still needs a completed
`coach-operational-launch-checklist-v2.json` sidecar from the actual release
process.

## Conversation 21 - Personal Pattern Consent Boundary

Fixture: `personal-pattern-hypothesis-confirmation`

Context: the user asks whether they sound defensive when disagreeing. The
transcript evidence is thin: one recent rep where the disagreement appears
after softening language and setup. Noum must not turn that into a hidden-motive
or identity claim such as "you are defensive because you fear disagreement."

Transcript:

User: Do I sound defensive when I disagree?

Noum target: From the transcript, I would treat defensiveness as a hypothesis,
not a label: you softened the disagreement and added context before the point.
Check whether that fits; next rep, say the disagreement in sentence one, give
one reason, then stop.

User: What if that doesn't fit?

Noum target: Then reject that hypothesis and keep the observable read: the
disagreement arrived after too much setup. Run the same answer
disagreement-first and compare whether the listener gets the point sooner.

User: What should Noum remember?

Noum target: Use this memory as a testable hypothesis only: disagreement may be
getting softened by setup. Keep it if two pressure reps show the point arrives
late; drop it if verdict-first solves it.

Manual vision grade: 89/100.

Why it passes: keeps the coach honest about evidence strength, answers the
personal-pattern question without labeling the user, preserves disconfirmation,
and still gives a concrete next rep.

Remaining gap: target-shaped only; production proof still needs live-provider
transcripts, professional coach review, and real-user transfer validation.

Research note: this hardening follows the same evidence-discipline stance as
NIST AI 600-1's warning about confident false content and SAMHSA TIP 35's
motivational-counseling emphasis on reflective listening, normalizing
ambivalence, and checking agreement before treating a formulation as true.

## Aggregate Read

Manual average across these target conversations: 87.5/100.

This is not a production score. It is a target-shape score. Production readiness
requires the live provider path to generate replies at this level, the machine
vision score to pass, the transcript set to be reviewed against expert or
human-coach baselines, real-device QA to pass, and transfer outcomes to be
validated over time. Current harsh VISION production readiness is **18/100**,
not 67/100 or 87/100.

## 2026-06-30 trajectory baseline-signature hardening

This pass closed the companion stale-read loophole in `UserTrajectoryCache`.
The previous cache key had already been hardened for changed recent-session
evidence, but baseline freshness still reduced to `overallConfidence`. That was
too coarse for Ask Noum: `UserTrajectorySnapshot.trendLines` reads concrete
baseline values such as filler rate, pace, and hedging, so two same-depth
baselines could produce different coach evidence while sharing the same cache
signature.

`UserTrajectoryCache.signature` now includes stable baseline fingerprints for
the metric values, sample counts, confidence, and trend state used by the
trajectory layer, plus normalized strengths and blockers. It deliberately does
not include volatile `lastUpdated`, so harmless store rebuilds do not turn every
chat turn into a miss. A new `UserTrajectoryCacheTests` regression covers the
production-shaped failure: same session, same baseline confidence, changed
baseline filler/pace/hedging metrics. The second snapshot must miss the cache
and expose the revised baseline trend lines.

Verification completed:

- `xcrun swiftc -parse -parse-as-library Noum/UserTrajectoryCache.swift NoumTests/CoachJudgementLayerTests.swift NoumTests/CoachChatEvaluationFixtures.swift NoumTests/CoachChatConversationEvaluationTests.swift NoumTests/CoachLiveEvaluationTests.swift`
- `git diff --check`

No live provider sweep or Xcode XCTest artifact was produced in this pass. The
production score remains **18/100**: this improves the reliability of local
trajectory evidence for Ask Noum, but it does not supply professional coach
calibration, real-device TestFlight QA, live provider transcripts, or real-user
transfer outcomes.

## 2026-06-30 baseline store account-reload hardening

External research used in this pass:

- OpenAI eval docs: production evals should define desired behavior against
  explicit test data and testing criteria, not rely on one aggregate score.
- NIST AI 600-1: generative-AI risk management should cover lifecycle stages
  and use-case context; confident-but-wrong outputs are a named risk.
- HELM-style evaluation: robust model assessment needs multiple metrics and
  transparent scenario coverage rather than a single accuracy number.

The code gap found locally was account/baseline freshness rather than another
prompt tweak. `BaselineStore` already persisted `communicationBaseline.<account>`
and `pressureProfile.<account>`, but it did not participate in
`AuthManager.deferStoreReloadForCurrentAccount()` or
`deferStoreSessionReset()`, and its own baseline mutation methods did not
invalidate `UserTrajectoryCache`. That meant Ask Noum could keep a trajectory
snapshot built from an older baseline until a separate session/profile/memory
event happened to invalidate the cache. Account deletion also omitted the
baseline and pressure-profile keys, leaving durable coaching evidence outside
the wipe list.

This pass wires `BaselineStore.reloadForCurrentAccount()` into account reload,
adds `BaselineStore.endSession()` to reset in-memory baseline/pressure state on
sign-out, clears baseline and pressure-profile keys during account deletion,
and invalidates `UserTrajectoryCache` after baseline rebuilds, session updates,
mini-drill updates, account reloads, and baseline session resets. A focused
`UserTrajectoryCacheTests` regression now proves a baseline-store rebuild breaks
a same-input trajectory cache hit.

Verification completed:

- `xcrun swiftc -parse -parse-as-library Noum/AuthManager.swift Noum/BaselineEngine.swift Noum/UserTrajectoryCache.swift NoumTests/CoachJudgementLayerTests.swift NoumTests/CoachChatEvaluationFixtures.swift NoumTests/CoachChatConversationEvaluationTests.swift NoumTests/CoachLiveEvaluationTests.swift`
- `git diff --check`

The transcript target set now includes 14 full three-turn conversations,
including the new `account-baseline-isolation` case. Production readiness still
stays at **18/100** because this is local architecture/eval hygiene, not
professional calibration, live-provider evidence, real-device QA, or
longitudinal real-user transfer validation.

## 2026-06-30 rating store account-reload hardening

The same account-isolation audit found the adjacent rating gap. `RatingStore`
already persisted `speakingRating.<account>`, and Ask Noum reads
`RatingStore.shared.rating` both for the trajectory cache and for the coach
context's rating/tier/weekly-delta lines. But `RatingStore` was not part of the
auth reload/reset fan-out, account deletion only cleared the week-peak cursor
and not the rating payload, and rating mutations did not invalidate the
trajectory cache.

This pass wires `RatingStore.reloadForCurrentAccount()` into account reload,
adds `RatingStore.endSession()` to clear in-memory rating state on sign-out,
clears `speakingRating.<accountID>` during account deletion, and invalidates
`UserTrajectoryCache` after rated-session updates, personal-best updates,
account reloads, session resets, and debug seed replacements. A focused
regression now proves a rating-store mutation breaks a same-input trajectory
cache hit. The transcript target set also gained `rating-evidence-isolation`,
which pins the expected coach behavior when a prior account had a high tier but
the current account has no rated pressure sessions.

Verification completed:

- `xcrun swiftc -parse -parse-as-library Noum/AuthManager.swift Noum/BaselineEngine.swift Noum/RatingEngine.swift Noum/UserTrajectoryCache.swift NoumTests/CoachJudgementLayerTests.swift NoumTests/CoachChatEvaluationFixtures.swift NoumTests/CoachChatConversationEvaluationTests.swift NoumTests/CoachLiveEvaluationTests.swift`
- `git diff --check`

Production readiness remains **18/100**. This removes another stale local
evidence path, but it still does not replace professional coach calibration,
live-provider transcript sweeps, real-device TestFlight QA, or longitudinal
transfer validation.

## 2026-06-30 proof moment account-reload hardening

The same account-isolation audit then found the quote-specific version of the
bug. Ask Noum can read `ProofMomentStore.shared.recent(limit: 3)` and cite saved
transcript proof lines. The archive was persisted per account, but a live store
that had loaded account A could retain its in-memory records when account B had
no archive or corrupt archive data. `ProofMomentStore` also was not part of the
auth reload/reset fan-out, and account deletion did not list
`proofMoment.archive.<accountID>`.

This pass adds explicit `ProofMomentStore.reloadForCurrentAccount()`,
`endSession()`, and `deleteAllData(for:)` lifecycle hooks, clears in-memory
records when disk load finds no valid archive, wires proof moments into
`AuthManager` account reload and sign-out reset, and includes the proof archive
key in account deletion. Two focused `ProofMomentArchiveTests` regressions pin
the failure: switching one live store from account A to an account with no
archive must clear A's quote, and sign-out must clear memory without writing a
guest proof archive.

Verification completed:

- `xcrun swiftc -parse -parse-as-library Noum/ProofMomentArchive.swift Noum/ProofMomentService.swift`
- `xcrun swiftc -parse -parse-as-library Noum/AuthManager.swift`
- `xcrun swiftc -parse -parse-as-library NoumTests/NoumTests.swift`
- `git diff --check`

The transcript target set now includes 16 full three-turn conversations,
including `proof-quote-account-isolation`. Production readiness remains
**18/100**. This closes another local stale-evidence path, but the main blockers
are unchanged: no live-provider transcript sweep, no professional coach
calibration sign-off, no real-device TestFlight QA evidence, and no longitudinal
real-user transfer outcomes.

## 2026-06-30 live-provider sidecar anti-smoothing hardening

This pass tightened the manifest-facing live-provider evidence contract again.
The prior decoder already required latest-turn coverage, long-form coverage,
turn-depth variety, confidence/proof-test variety, detailed long-form rows, and
basic per-turn telemetry. The remaining loophole was a smoothed sidecar:
`liveProductionFloor: true` could be present while the row still carried a
failed rubric flag, failed vision flag, semantic issue, quality issue,
reliability issue, generic placeholder reply, or exact duplicated reply text.

`CoachLiveProviderSweepEvidence.rejectionReasons` now independently rejects
latest-turn and detailed long-form rows whose clean-pass boolean contradicts
their row-level gate telemetry. It also rejects exact duplicate reply text in
the latest-turn rows or inside any detailed long-form conversation, and rejects
obvious placeholder/generic live replies such as "focused coach reply with
concrete evidence." Two negative-control tests pin the behavior:
contradictory gate telemetry cannot pass, and duplicated/generic provider reply
text cannot pass. The synthetic clean sidecar helper now emits varied
fixture-specific reply text so the positive loader test remains meaningful.

This follows the evaluation stance already recorded from OpenAI eval guidance
(explicit test data and criteria), NIST AI 600-1 (context-sensitive
confabulation/false-confidence risk), and HELM-style multi-metric evaluation:
do not let a single self-reported pass flag stand in for inspectable evidence.

Verification completed:

- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatEvaluationFixtures.swift`
- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatConversationEvaluationTests.swift`
- `xcrun swiftc -parse -parse-as-library NoumTests/CoachJudgementLayerTests.swift`
- `xcrun swiftc -parse -parse-as-library Noum/UserTrajectoryCache.swift NoumTests/CoachJudgementLayerTests.swift NoumTests/CoachChatEvaluationFixtures.swift NoumTests/CoachChatConversationEvaluationTests.swift`
- `git diff --check`
- `xcodebuild test -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/noum-derived-data-live-sidecar -only-testing:NoumTests/CoachChatConversationCorpusTests/liveProviderSweepEvidenceRejectsContradictoryGateTelemetry -only-testing:NoumTests/CoachChatConversationCorpusTests/liveProviderSweepEvidenceRejectsDuplicatedOrGenericReplyText`

The escalated Xcode run succeeded after fixing two compile issues that the
broader test target exposed: the trajectory cache `scaled(_:)` helper now
returns its rounded value explicitly, and the rating-store cache invalidation
test is marked `@MainActor`.

The transcript target set now includes 17 full three-turn conversations,
including `live-sidecar-smoothed-reply-rejection`. Production readiness remains
**18/100**. This makes the live-provider evidence gate harder to fake, but no
real-provider sweep, professional calibration, real-device TestFlight QA, or
longitudinal transfer evidence has been produced.

## 2026-06-30 real-user transfer ledger v2 hardening

This pass tightened the real-user transfer blocker from a boolean outcome ledger
into a row-evidence ledger. The prior v1 sidecar already required 10 completed
off-app follow-ups, linked interventions, audience-response evidence, no
confidence regression, no adverse outcomes, and no causal overclaim. The
remaining loophole was still too large for VISION validation: a sidecar could
pass with only five users, a narrow set of moment types, immediate follow-up,
and clean summary booleans without row-level evidence references.

`CoachRealUserTransferOutcomeEvidence` now expects
`coach-real-user-transfer-outcomes-v2.json` with
`coach-transfer-outcome-ledger-v2`. The v2 ledger requires at least eight unique
users, no more than two counted outcomes from any one user, at least four
real-world moment categories, at least 24 hours before the follow-up, and
non-placeholder row references for the Noum intervention, the real moment, the
follow-up, the audience-response evidence, and the user's self-report. Missing
references, same-hour follow-up, over-concentrated users, or one-category
outcomes now reject the entire sidecar before any transfer rows count.

This follows the current multi-turn evaluation literature: user-aware agent
evaluation should account for the user role and diagnose error patterns, and
multi-turn assistants should be scored over trajectories rather than isolated
last replies. For Noum, the matching production-readiness lesson is simple:
outside-app transfer needs auditable longitudinal rows, not a clean local
summary.

Verification completed:

- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatEvaluationFixtures.swift`
- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatConversationEvaluationTests.swift`
- `git diff --check`
- `xcodebuild test -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/noum-derived-data-transfer-ledger -only-testing:NoumTests/CoachChatConversationCorpusTests/realUserTransferOutcomeEvidenceRequiresLongitudinalUsableRows -only-testing:NoumTests/CoachChatConversationCorpusTests/realUserTransferOutcomeEvidenceRejectsThinOrSmoothedSidecars -only-testing:NoumTests/CoachChatConversationCorpusTests/productionReadinessManifestIngestsCleanRealUserTransferOutcomesFromArtifactDirectory`

The transcript target set now includes 18 full three-turn conversations,
including `transfer-ledger-evidence-discipline`. Production readiness remains
**18/100**. This makes the real-user transfer blocker harder to fake, but no
real longitudinal outcome sidecar has been produced.

## 2026-06-30 real-device TestFlight v2 hardening

This pass tightened the real-device/TestFlight blocker from a row of QA booleans
into an artifact-backed device ledger. The prior v1 sidecar required the four
high-risk surfaces to pass on a physical TestFlight build with evidence
references and no warnings, but it still allowed vague evidence references,
mixed build rows, missing device identity, manual-note substitutions for real
artifacts, and AI prompt latency outside the live-coach budget.

`CoachRealDeviceTestFlightEvidence` now expects
`coach-real-device-testflight-qa-v2.json`. Each required surface must include
the expected evidence kind (`screenRecording`, `latencyTrace`,
`audioSessionLog`, or `storeKitReceipt`), a usable evidence reference, a capture
timestamp, matching TestFlight build number, device identity hash, and no
blocking issue. The AI prompt latency row must carry a measured latency at or
below 3,000 ms. Negative-control tests reject wrong artifact kind, over-budget
latency, mixed build numbers, and placeholder/missing evidence.

Verification completed:

- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatEvaluationFixtures.swift`
- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatConversationEvaluationTests.swift`
- `git diff --check`
- `xcodebuild test -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/noum-derived-data-real-device -only-testing:NoumTests/CoachChatConversationCorpusTests/realDeviceTestFlightEvidenceRequiresAllHighRiskSurfaces -only-testing:NoumTests/CoachChatConversationCorpusTests/realDeviceTestFlightEvidenceRejectsSmoothedOrIncompleteEvidence -only-testing:NoumTests/CoachChatConversationCorpusTests/productionReadinessManifestIngestsCleanRealDeviceTestFlightFromArtifactDirectory`

The transcript target set now includes 19 full three-turn conversations,
including `real-device-qa-evidence-discipline`. Production readiness remains
**18/100**. This makes the real-device blocker harder to fake, but no real
physical-device TestFlight sidecar has been produced.

## 2026-06-30 operational launch checklist v2 hardening

This pass tightened the M14 launch-ops blocker from a completed checklist into
an artifact-backed release ledger. The prior v1 sidecar required all six launch
items to be marked complete with timestamps and evidence references, but it
still allowed generic references, manual-note substitutions, staging evidence
for public privacy URLs, mixed release-candidate build rows, and reviewer notes
without command or review output.

`CoachOperationalLaunchChecklistEvidence` now expects
`coach-operational-launch-checklist-v2.json` with `m14-launch-gate-v2`. Each
required item must include the expected evidence kind (`firebaseDeployLog`,
`publicURLProbe`, `settingsScreenshot`, `appStorePrivacyExport`,
`appStoreConnectBuildRecord`, or `releaseTriageReport`), the expected
environment, matching release-candidate build, usable evidence reference,
verification reference, command/review output reference, completion time,
verification time, verifier role, and no readiness warnings. Negative-control
tests reject manual-note artifact substitutions, staging privacy URL proof,
mixed TestFlight build records, missing App Store privacy-review output, and
missing verifier identity.

This mirrors the launch guidance checked in official sources during this pass:
Firebase says to test rules before deploying and deploy Firestore rules with
`firebase deploy --only firestore:rules`; Apple requires accurate, up-to-date
App Store privacy responses plus a public privacy policy URL; TestFlight build
evidence should come from App Store Connect build/tester records, not local
claims.

Verification completed:

- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatEvaluationFixtures.swift`
- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatConversationEvaluationTests.swift`
- `git diff --check`
- `xcodebuild test -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/noum-derived-data-operational-launch -only-testing:NoumTests/CoachChatConversationCorpusTests/operationalLaunchChecklistEvidenceRequiresCompletedM14Items -only-testing:NoumTests/CoachChatConversationCorpusTests/operationalLaunchChecklistEvidenceRejectsThinOrSmoothedItems -only-testing:NoumTests/CoachChatConversationCorpusTests/productionReadinessManifestIngestsCleanOperationalLaunchChecklistFromArtifactDirectory`

The transcript target set now includes 20 full three-turn conversations,
including `launch-ops-evidence-discipline`. Production readiness remains
**18/100**. This makes the M14 ops blocker harder to fake, but no real
operational launch checklist sidecar has been produced.

## 2026-06-30 personal-pattern hypothesis gate

This pass tightened the Ask Noum runtime quality gate for thin-evidence
personal-pattern claims. The prior overclaim detector already blocked obvious
"this proves..." and "you lack conviction" language, but it could still let a
reply assert hidden motive or identity from one transcript: "you are defensive
because you fear disagreement." That is exactly the kind of confident
over-reading that erodes coaching trust.

`AICoachChatService.replyOverclaimsEvidence(_:)` now rejects unconfirmed
personal-pattern labels and hidden-motive claims such as defensive/evasive/
insecure, fear of disagreement, or fear of conflict unless the reply frames the
read as a hypothesis and gives the user a way to confirm, reject, or test it.
The gate still allows observable structure reads: "the disagreement arrived
after too much setup" is fine; "you are defensive because you fear disagreement"
is not.

The transcript target set now includes 21 full three-turn conversations,
including `personal-pattern-consent-boundary-conversation`. The short local
conversation corpus now has 13 three-turn rows, so the full professional review
packet covers 23 conversations and requires 46 independent professional review
rows. Text/live app-path scripted replay now covers 39 short-corpus turns. The
production readiness score remains **18/100** because this is local gate and
fixture hardening, not live-provider, professional-coach, real-device, launch,
or real-user transfer evidence.

Verification completed:

- `xcrun swiftc -parse -parse-as-library Noum/AICoachChatService.swift`
- `xcrun swiftc -parse -parse-as-library NoumTests/CoachJudgementLayerTests.swift`
- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatEvaluationFixtures.swift`
- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatConversationEvaluationTests.swift`
- `xcodebuild test -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/noum-derived-data-personal-pattern -only-testing:NoumTests/CoachSemanticQualityGateTests/unconfirmedPersonalPatternLabelFailsProfessionalGate -only-testing:NoumTests/CoachSemanticQualityGateTests/confirmablePersonalPatternHypothesisClearsProfessionalGate -only-testing:NoumTests/CoachSemanticQualityGateTests/observableStructureReadDoesNotTripPersonalPatternGate -only-testing:NoumTests/CoachChatConversationCorpusTests/conversationCorpusCoversFullThreeTurnTranscripts -only-testing:NoumTests/CoachChatConversationCorpusTests/conversationReportRoundTripsAsSortedJSON -only-testing:NoumTests/CoachChatConversationCorpusTests/conversationExpertCalibrationPacketCoversFullCorpusWithoutClaimingReadiness`
- `xcodebuild test -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/noum-derived-data-personal-pattern-latest -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalWeakDraftsTripTheProfessionalGate -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalPreferredShapesStayShortAndActionable -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalReferenceShapesEarnVisionScore -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalKnownBadShapesScoreHarshly`
- `git diff --check`

## 2026-06-30 context-needle integrity gate

This pass tightened the latest-turn manual evaluator so evidence anchors are no
longer only a fixture convention. `CoachChatEvaluationCIReport` schema v6 now
renders the same coach context each fixture uses, checks every
`expectedContextNeedles` anchor against it, serializes `contextNeedlesPassed`
and `missingContextNeedles`, and refuses to mark a reference row as passing the
local production-floor projection when context evidence is missing.

The paired regression
`CoachChatLatestLiveEvalRegressionTests.fixtureContextsContainExpectedEvidenceNeedles`
now sweeps the full current fixture set and fails with the specific missing
needles for any drift. This protects the research-report complaint that a coach
can sound polished while losing the evidence that made the read legitimate:
target replies cannot pass just because the answer text is well shaped if the
prompt context no longer carries the transcript/session/formulation anchors it
claims to use.

The follow-up negative control,
`ciReportRejectsFixtureWhenExpectedContextEvidenceIsMissing`, creates a valid
fixture with one impossible context anchor. The reference reply still passes the
rubric, quality gate, vision floor, and reliability gate, but the row now reports
`contextNeedlesPassed=false`, serializes the missing anchor, and fails
`referencePassesProductionFloor`. That keeps this from becoming a decorative
JSON field.

Verification completed:

- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatEvaluationFixtures.swift`
- `xcodebuild test -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/noum-derived-data-context-needles -only-testing:NoumTests/CoachChatLatestLiveEvalRegressionTests/fixtureContextsContainExpectedEvidenceNeedles`
- `xcodebuild test -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/noum-derived-data-context-needles -only-testing:NoumTests/CoachChatLatestLiveEvalRegressionTests/fixtureContextsContainExpectedEvidenceNeedles -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalWeakDraftsTripTheProfessionalGate -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalPreferredShapesStayShortAndActionable -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalReferenceShapesEarnVisionScore -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalKnownBadShapesScoreHarshly`
- `xcrun swiftc -parse -parse-as-library NoumTests/CoachChatEvaluationFixtures.swift NoumTests/NoumTests.swift`
- `xcodebuild test -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath /private/tmp/noum-derived-data-context-needles-v6 -only-testing:NoumTests/CoachChatLatestLiveEvalRegressionTests/fixtureContextsContainExpectedEvidenceNeedles -only-testing:NoumTests/CoachChatLatestLiveEvalRegressionTests/ciReportRejectsFixtureWhenExpectedContextEvidenceIsMissing -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalWeakDraftsTripTheProfessionalGate -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalPreferredShapesStayShortAndActionable -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalReferenceShapesEarnVisionScore -only-testing:NoumTests/CoachChatEvaluationReportTests/latestManualEvalKnownBadShapesScoreHarshly -only-testing:NoumTests/CoachChatEvaluationFixtureTests/ciReportProjectionIsDeterministicAndMachineReadable`
- `git diff --check`

Production readiness remains **18/100**. This is evaluator-integrity evidence,
not a live-provider sweep, professional-coach calibration, real-user transfer
study, physical-device QA pass, or completed launch-ops artifact.
