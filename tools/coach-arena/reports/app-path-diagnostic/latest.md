# Coach Arena Latest Report

- Generated: `2026-07-09T21:31:51+00:00`
- Candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Fixtures: `50`
- Average: `77.92/100`
- Passes score/coverage thresholds: `False`
- Real-pipeline evidence passes: `False`
- Evidence claim: `localEvaluationOnly`
- Trace quality passes: `False`
- Placeholder/fallback leaks: `1`
- Local fixture failures: `2`

## Report Lens and Canonical Paths

- Current report: `app-path`
- Current report path: `tools/coach-arena/reports/app-path-diagnostic/latest.md`
- Comparable prompt-layer report: `tools/coach-arena/reports/latest.md`
- Canonical app-path source of truth: `tools/coach-arena/reports/app-path/latest.md`
- Nested duplicate app-path path: stale duplicate present at tools/coach-arena/tools/coach-arena/reports/app-path/latest.json (generated 2026-07-05T23:09:49+00:00); ignore this path

## Type Averages

- `deepAssessment`: `80.67/100`
- `groundedRead`: `80.5/100`
- `quickMove`: `74.76/100`
- `trustRepair`: `76.89/100`

## VISION Readiness Boundary

- Production ready: `False`
- Score: `18/100`
- Maximum allowed score: `20/100`
- Claim: `localEvaluationSubstrateOnly`
- Blockers: `noLiveProviderTranscriptSweep`, `noProfessionalCoachCalibration`, `noRealUserLongitudinalTransferOutcomes`, `noRealDeviceTestFlightVerification`, `operationalLaunchChecklistIncomplete`

VISION production readiness 18/100; local target-shape 85/100; claim localEvaluationSubstrateOnly; blockers: noLiveProviderTranscriptSweep, noProfessionalCoachCalibration, noRealUserLongitudinalTransferOutcomes, noRealDeviceTestFlightVerification, operationalLaunchChecklistIncomplete.

## Real-Pipeline Evidence

- `2 app-path fixture(s) below local quality floor 70: filler-pressure-007,not-easy-empathy-004`
- `50 real-pipeline trace(s) missing first-token source`
- `source Swift app-path freshness: dirty coach source files after app-path dump: Noum/AICoachChatService.swift,Noum/AskNoumStore.swift,Noum/CoachContextBuilder.swift,Noum/CoachReliabilityGate.swift,Noum/CoachReplyPipeline.swift,NoumTests/CoachChatConversationEvaluationTests.swift,NoumTests/CoachChatEvaluationFixtures.swift,NoumTests/CoachJudgementLayerTests.swift,+3 more`
- `source Swift app-path freshness: source app-path git commit(s) do not match current HEAD: a556f772`
- `source Swift app-path readiness warnings: appPathFloorFailures,targetReplyMismatch`
- `source Swift app-path report did not pass its app-path floor`

## Trace Audit

- Real-pipeline trace fixtures: `50`
- Complete traces: `50`
- Missing-trace fixture count: `0`
- Candidate sources: `appPathReport` `50`

## Trace Quality

- Eligible real-pipeline traces: `50`
- Passes: `False`
- Unique proof-test hashes: `28`
- Max proof-test hash reuse: `5`
- Max proof-test hash reuse allowed: `10`
- Distinct rounded confidence values: `10`
- Empty retrieval-card traces: `0`
- Allowed empty retrieval-card traces: `3`
- Slow first-token traces: `0`
- Trace quality failures: `50 real-pipeline trace(s) missing first-token source`

## Previous Run

- Status: `compared`
- Previous generated: `2026-07-09T06:36:25+00:00`
- Previous candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Candidate changed: `False`
- Fixture count changed: `False`
- Average delta: `0.0`
- Failure count delta: `0`
- Placeholder leak delta: `0`
- Pass state changed: `False`
- Type average deltas: `deepAssessment` `0.0`, `groundedRead` `0.0`, `quickMove` `0.0`, `trustRepair` `0.0`
- Cleared failures: `none`
- New failures: `none`

## Coverage

- Source: `appPathReport`
- Source schema: `coach-chat-conversation-app-path-eval-v1`
- Source surface: `text`
- Source app-path floor: `False`
- Source app-path floor failures: `2`
- App-path local fixture floor: `False`
- Source target-reply mismatches: `2`
- Source app-path failure samples: `2` of `2`
- Source trace git commits: `a556f772`
- Source traces missing git commit: `0`
- Current git commit: `5bef2d08`
- Source trace coach fingerprints: `sha256:d8662f3feef2bed08afc861b6d41edbfecc7c3b1471bacef2863a6a42aee5e0a`
- Source traces missing coach fingerprint: `0`
- Current coach source fingerprint: `sha256:10bbf2c3aa86cece99f2cce118756078e594165d31e3b0d74b8e45d7ef809894`
- Source fingerprint matches current: `False`
- Dirty coach source files: `11`
- Source freshness passes: `False`
- Coverage passes: `True`
- Requested fixtures: `50`
- Matched fixtures: `50`
- Unmatched fixtures: `0`
- Ambiguous fixtures: `0`
- Source freshness failures: `dirty coach source files after app-path dump: Noum/AICoachChatService.swift,Noum/AskNoumStore.swift,Noum/CoachContextBuilder.swift,Noum/CoachReliabilityGate.swift,Noum/CoachReplyPipeline.swift,NoumTests/CoachChatConversationEvaluationTests.swift,NoumTests/CoachChatEvaluationFixtures.swift,NoumTests/CoachJudgementLayerTests.swift,+3 more`; `source app-path git commit(s) do not match current HEAD: a556f772`

### Source App-Path Failure Samples

- Evidence status: `stale app-path source`; failure replies below may reflect an older Swift app-path dump until the dump is regenerated and rescored.
- `filler-pressure-prescription` / `filler-pressure-prescription-conversation` turn `0`: `appPathFloor, qualityGate, targetReplyMismatch`; semantic `passed`; quality `fallback:typedAssessment`
- `filler-pressure-prescription` / `not-easy-empathy-conversation` turn `0`: `appPathFloor, qualityGate, targetReplyMismatch`; semantic `passed`; quality `fallback:typedAssessment`

## Worst Fixtures

- `filler-pressure-007` `quickMove`: `30/100` - fixture disqualifier triggered: semantic words treated as fillers; fixture-specific disqualifier triggered; quality/provider fallback output cannot score as normal coaching; reply does not match expected coach move
- `not-easy-empathy-004` `trustRepair`: `60/100` - fixture disqualifier triggered: no adjusted intervention; fixture-specific disqualifier triggered
- `confidence-clean-stop-025` `quickMove`: `70/100` - no local failure reason
- `not-informative-trust-repair-002` `trustRepair`: `71/100` - no local failure reason
- `quote-guard-043` `groundedRead`: `71/100` - no local failure reason
- `interview-prep-006` `quickMove`: `72/100` - no local failure reason
- `leadership-transfer-capture-026` `quickMove`: `72/100` - no local failure reason
- `semantic-filler-use-040` `groundedRead`: `72/100` - no local failure reason
- `prompt-echo-041` `groundedRead`: `72/100` - no local failure reason
- `confidence-ending-009` `groundedRead`: `73/100` - no local failure reason
