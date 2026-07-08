# Coach Arena Latest Report

- Generated: `2026-07-08T19:03:47+00:00`
- Candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Fixtures: `50`
- Average: `77.5/100`
- Passes score/coverage thresholds: `False`
- Real-pipeline evidence passes: `False`
- Evidence claim: `localEvaluationOnly`
- Trace quality passes: `True`
- Placeholder/fallback leaks: `1`
- Local fixture failures: `1`

## Report Lens and Canonical Paths

- Current report: `app-path`
- Current report path: `tools/coach-arena/reports/app-path/latest.md`
- Comparable prompt-layer report: `tools/coach-arena/reports/latest.md`
- Canonical app-path source of truth: `tools/coach-arena/reports/app-path/latest.md`
- Nested duplicate app-path path: stale duplicate present at tools/coach-arena/tools/coach-arena/reports/app-path/latest.json (generated 2026-07-05T23:09:49+00:00); ignore this path

## Type Averages

- `deepAssessment`: `80.67/100`
- `groundedRead`: `76.89/100`
- `quickMove`: `77.18/100`
- `trustRepair`: `77.22/100`

## VISION Readiness Boundary

- Production ready: `False`
- Score: `18/100`
- Maximum allowed score: `20/100`
- Claim: `localEvaluationSubstrateOnly`
- Blockers: `noLiveProviderTranscriptSweep`, `noProfessionalCoachCalibration`, `noRealUserLongitudinalTransferOutcomes`, `noRealDeviceTestFlightVerification`, `operationalLaunchChecklistIncomplete`

VISION production readiness 18/100; local target-shape 85/100; claim localEvaluationSubstrateOnly; blockers: noLiveProviderTranscriptSweep, noProfessionalCoachCalibration, noRealUserLongitudinalTransferOutcomes, noRealDeviceTestFlightVerification, operationalLaunchChecklistIncomplete.

## Real-Pipeline Evidence

- `1 app-path fixture(s) below local quality floor 70: examples-from-sessions-010`
- `source Swift app-path freshness: dirty coach source files after app-path dump: Noum/AICoachChatService.swift,Noum/AskNoumStore.swift,Noum/CoachContextBuilder.swift,Noum/CoachPromptBundle.swift,Noum/CoachReliabilityGate.swift,NoumTests/CoachChatConversationEvaluationTests.swift,NoumTests/CoachJudgementLayerTests.swift,NoumTests/CoachReliabilityGateTests.swift,+1 more`
- `source Swift app-path readiness warnings: appPathFloorFailures,targetReplyMismatch,semanticGateFailures`
- `source Swift app-path report did not pass its app-path floor`

## Trace Audit

- Real-pipeline trace fixtures: `50`
- Complete traces: `50`
- Missing-trace fixture count: `0`
- Candidate sources: `appPathReport` `50`

## Trace Quality

- Eligible real-pipeline traces: `50`
- Passes: `True`
- Unique proof-test hashes: `9`
- Max proof-test hash reuse: `9`
- Max proof-test hash reuse allowed: `10`
- Distinct rounded confidence values: `10`
- Empty retrieval-card traces: `0`
- Allowed empty retrieval-card traces: `3`
- Slow first-token traces: `0`

## Previous Run

- Status: `compared`
- Previous generated: `2026-07-08T18:33:48+00:00`
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
- Source trace git commits: `778f544d`
- Source traces missing git commit: `0`
- Current git commit: `778f544d`
- Dirty coach source files: `9`
- Source freshness passes: `False`
- Coverage passes: `True`
- Requested fixtures: `50`
- Matched fixtures: `50`
- Unmatched fixtures: `0`
- Ambiguous fixtures: `0`
- Source freshness failures: `dirty coach source files after app-path dump: Noum/AICoachChatService.swift,Noum/AskNoumStore.swift,Noum/CoachContextBuilder.swift,Noum/CoachPromptBundle.swift,Noum/CoachReliabilityGate.swift,NoumTests/CoachChatConversationEvaluationTests.swift,NoumTests/CoachJudgementLayerTests.swift,NoumTests/CoachReliabilityGateTests.swift,+1 more`

### Source App-Path Failure Samples

- `answer-depth-one-example` / `answer-depth-one-example-conversation` turn `1`: `appPathFloor, qualityGate, semanticGate, targetReplyMismatch`; semantic `failed:missingIntentFit`; quality `fallback:deterministicAssessmentAfterContentRejected`
- `examples-from-sessions-010` / `arena-examples-from-sessions-010-app-path-conversation` turn `0`: `appPathFloor, qualityGate, targetReplyMismatch`; semantic `passed`; quality `fallback:deterministicAssessmentAfterContentRejected`

## Worst Fixtures

- `examples-from-sessions-010` `groundedRead`: `30/100` - fixture disqualifier triggered: no example; fixture-specific disqualifier triggered; missing verified quote anchor; quality/provider fallback output cannot score as normal coaching; reply does not match expected coach move
- `cold-generic-016` `trustRepair`: `70/100` - no local failure reason
- `pace-rushing-019` `groundedRead`: `70/100` - no local failure reason
- `confidence-clean-stop-025` `quickMove`: `70/100` - no local failure reason
- `not-easy-empathy-004` `trustRepair`: `71/100` - no local failure reason
- `filler-pressure-007` `quickMove`: `71/100` - no local failure reason
- `quote-guard-043` `groundedRead`: `71/100` - no local failure reason
- `interview-prep-006` `quickMove`: `72/100` - no local failure reason
- `leadership-transfer-capture-026` `quickMove`: `72/100` - no local failure reason
- `semantic-filler-use-040` `groundedRead`: `72/100` - no local failure reason
