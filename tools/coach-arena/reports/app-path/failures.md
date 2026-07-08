# Coach Arena Failures

## Production Evidence Gate

- 1 app-path fixture(s) below local quality floor 70: live-latency-short-044
- source Swift app-path freshness: dirty coach source files after app-path dump: NoumTests/CoachJudgementLayerTests.swift
- source Swift app-path readiness warnings: appPathFloorFailures,targetReplyMismatch
- source Swift app-path report did not pass its app-path floor

Source app-path failure samples:

- `answer-depth-one-example` / `answer-depth-one-example-conversation` turn `2`: `appPathFloor, qualityGate, targetReplyMismatch`; semantic `passed`; quality `fallback:deterministicAssessmentAfterContentRejected`
  User: What should I record?
  Final: Pressure is the next lever: repeat the same answer under a timer and protect sentence one. Try this next: Run the latest Timed topic under a 60-second pressure timer and keep sentence one intact.
  Target: Record the same executive recommendation in 60 seconds because it isolates answer depth. Sentence one is the claim, sentence two is one reason, sentence three is one example, then stop.
- `assistant-explainer-register` / `not-informative-trust-repair-conversation` turn `2`: `appPathFloor, qualityGate, targetReplyMismatch`; semantic `passed`; quality `fallback:typedAssessment`
  User: What should I do with that?
  Final: Your last rep gives one usable signal so far, so run the same answer under a 60-90 second timer or pressure mode and keep the verdict first.
  Target: Run one 45-second client concern answer because it isolates order. Sentence one is the recommendation; sentence two is one reassurance; then stop.
- `live-latency-short-044` / `arena-live-latency-short-044-app-path-conversation` turn `0`: `appPathFloor, qualityGate, targetReplyMismatch`; semantic `passed`; quality `fallback:deterministicAssessmentAfterContentRejected`
  User: Quickly, what do I do next?
  Final: Pacing is the next lever: add one deliberate beat before the reason, then judge the same answer. The signal I can use is hypothesis: Confidence may be the highest-leverage focus because stated voice goal while evidence i...
  Target: The close is the lever, so make the final sentence the ask, then stop.

## live-latency-short-044 (quickMove)

Score: `30/100`

User: Quickly, what do I do next?

Failure reasons:
- quality/provider fallback output cannot score as normal coaching
- reply does not match expected coach move

Suggested fix:

Hold back broken/scaffold output and return an honest failure notice or clean deterministic read.
