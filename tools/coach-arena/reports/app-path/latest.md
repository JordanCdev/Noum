# Coach Arena Latest Report

- Generated: `2026-07-08T19:52:48+00:00`
- Candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Fixtures: `50`
- Average: `78.56/100`
- Passes score/coverage thresholds: `True`
- Real-pipeline evidence passes: `False`
- Evidence claim: `localEvaluationOnly`
- Trace quality passes: `True`
- Placeholder/fallback leaks: `0`
- Local fixture failures: `0`

## Report Lens and Canonical Paths

- Current report: `app-path`
- Current report path: `tools/coach-arena/reports/app-path/latest.md`
- Comparable prompt-layer report: `tools/coach-arena/reports/latest.md`
- Canonical app-path source of truth: `tools/coach-arena/reports/app-path/latest.md`
- Nested duplicate app-path path: stale duplicate present at tools/coach-arena/tools/coach-arena/reports/app-path/latest.json (generated 2026-07-05T23:09:49+00:00); ignore this path

## Type Averages

- `deepAssessment`: `80.67/100`
- `groundedRead`: `79.83/100`
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

- `source Swift app-path freshness: dirty coach source files after app-path dump: NoumTests/CoachChatConversationEvaluationTests.swift`

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
- Previous generated: `2026-07-08T19:41:36+00:00`
- Previous candidate: `/private/tmp/noum-coach-eval/coach-chat-conversation-app-path-eval-v1.json`
- Candidate changed: `False`
- Fixture count changed: `False`
- Average delta: `1.06`
- Failure count delta: `-1`
- Placeholder leak delta: `-1`
- Pass state changed: `True`
- Type average deltas: `deepAssessment` `0.0`, `groundedRead` `2.94`, `quickMove` `0.0`, `trustRepair` `0.0`
- Cleared failures: `examples-from-sessions-010`
- New failures: `none`

## Coverage

- Source: `appPathReport`
- Source schema: `coach-chat-conversation-app-path-eval-v1`
- Source surface: `text`
- Source app-path floor: `True`
- Source app-path floor failures: `0`
- App-path local fixture floor: `True`
- Source target-reply mismatches: `0`
- Source app-path failure samples: `0` of `0`
- Source trace git commits: `667735c8`
- Source traces missing git commit: `0`
- Current git commit: `667735c8`
- Dirty coach source files: `1`
- Source freshness passes: `False`
- Coverage passes: `True`
- Requested fixtures: `50`
- Matched fixtures: `50`
- Unmatched fixtures: `0`
- Ambiguous fixtures: `0`
- Source freshness failures: `dirty coach source files after app-path dump: NoumTests/CoachChatConversationEvaluationTests.swift`

## Worst Fixtures

- `cold-generic-016` `trustRepair`: `70/100` - no local failure reason
- `pace-rushing-019` `groundedRead`: `70/100` - no local failure reason
- `confidence-clean-stop-025` `quickMove`: `70/100` - no local failure reason
- `not-easy-empathy-004` `trustRepair`: `71/100` - no local failure reason
- `filler-pressure-007` `quickMove`: `71/100` - no local failure reason
- `quote-guard-043` `groundedRead`: `71/100` - no local failure reason
- `interview-prep-006` `quickMove`: `72/100` - no local failure reason
- `leadership-transfer-capture-026` `quickMove`: `72/100` - no local failure reason
- `semantic-filler-use-040` `groundedRead`: `72/100` - no local failure reason
- `prompt-echo-041` `groundedRead`: `72/100` - no local failure reason
