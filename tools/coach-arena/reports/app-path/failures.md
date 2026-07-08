# Coach Arena Failures

## Production Evidence Gate

- 1 app-path fixture(s) below local quality floor 70: examples-from-sessions-010
- source Swift app-path freshness: dirty coach source files after app-path dump: Noum/AICoachChatService.swift,Noum/AskNoumStore.swift,Noum/CoachContextBuilder.swift,Noum/CoachPromptBundle.swift,Noum/CoachReliabilityGate.swift,NoumTests/CoachChatConversationEvaluationTests.swift,NoumTests/CoachJudgementLayerTests.swift,NoumTests/CoachReliabilityGateTests.swift,+1 more
- source Swift app-path readiness warnings: appPathFloorFailures,targetReplyMismatch,semanticGateFailures
- source Swift app-path report did not pass its app-path floor

Source app-path failure samples:

- `answer-depth-one-example` / `answer-depth-one-example-conversation` turn `1`: `appPathFloor, qualityGate, semanticGate, targetReplyMismatch`; semantic `failed:missingIntentFit`; quality `fallback:deterministicAssessmentAfterContentRejected`
  User: Can you give me an example of me doing this in sessions?
  Final: Salience is the next lever: add one concrete detail, then return to the ask. Try this next: Use one specific detail that makes the point memorable, then return to the ask.
  Target: In the vendor rep, you said implementation risk was lower and the team already knew the workflow. Those are reasons, not a picture, so add one concrete example after the first reason, then stop.
- `examples-from-sessions-010` / `arena-examples-from-sessions-010-app-path-conversation` turn `0`: `appPathFloor, qualityGate, targetReplyMismatch`; semantic `passed`; quality `fallback:deterministicAssessmentAfterContentRejected`
  User: Can you give me an example of me doing this in sessions?
  Final: Salience is the next lever: add one concrete detail, then return to the ask. The signal I can use is hypothesis: Filler Words appears to be the highest-leverage focus because it keeps showing up in the rolling baseline;...
  Target: One specific example is the latest rep: the reasons were clear before there was a concrete scene. That shows the pattern because the listener gets logic before a picture. Next rep, add one example after the first reason,...

## examples-from-sessions-010 (groundedRead)

Score: `30/100`

User: Can you give me an example of me doing this in sessions?

Failure reasons:
- fixture disqualifier triggered: no example
- fixture-specific disqualifier triggered
- missing verified quote anchor
- quality/provider fallback output cannot score as normal coaching
- reply does not match expected coach move

Suggested fix:

Hold back broken/scaffold output and return an honest failure notice or clean deterministic read.
