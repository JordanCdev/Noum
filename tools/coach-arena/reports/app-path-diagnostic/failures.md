# Coach Arena Failures

## Production Evidence Gate

- 2 app-path fixture(s) below local quality floor 70: filler-pressure-007,not-easy-empathy-004
- source Swift app-path freshness: dirty coach source files after app-path dump: Noum/AICoachChatService.swift,Noum/AskNoumStore.swift,Noum/CoachAssessment.swift,Noum/CoachReasoningPass.swift,Noum/CoachReliabilityGate.swift,Noum/CoachReplyPipeline.swift,Noum/TurnDepthClassifier.swift,NoumTests/CoachChatConversationEvaluationTests.swift,+5 more
- source Swift app-path readiness warnings: appPathFloorFailures,targetReplyMismatch
- source Swift app-path report did not pass its app-path floor

Source app-path failure samples:

- Evidence status: `stale app-path source`; failure replies below may reflect an older Swift app-path dump until the dump is regenerated and rescored.
- `filler-pressure-prescription` / `filler-pressure-prescription-conversation` turn `0`: `appPathFloor, qualityGate, targetReplyMismatch`; semantic `passed`; quality `fallback:typedAssessment`
  User: How do I stop saying um under pressure?
  Final: Your last rep gives one usable signal so far, so run one answer and separate semantic words from filler words before cutting anything.
  Target: Your last pressure rep had 6 fillers, mostly before the close. Do not fight the urge; replace it with one silent beat before the final sentence, then finish the ask.
- `filler-pressure-prescription` / `not-easy-empathy-conversation` turn `0`: `appPathFloor, qualityGate, targetReplyMismatch`; semantic `passed`; quality `fallback:typedAssessment`
  User: It's not easy.
  Final: Fair push. I made the move sound easier than it feels under pressure. Your last rep gives one safe signal, I made the move sound easier than it feels under pressure, so say only the disagreement and one calm reason, then...
  Target: Fair push: no, it is not easy. The hard part is that sentence one carries the social risk, so test the smallest version: say only the disagreement and one calm reason, then stop before defending it.

## not-easy-empathy-004 (trustRepair)

Score: `60/100`

User: It's not easy.

Failure reasons:
- fixture disqualifier triggered: no adjusted intervention
- fixture-specific disqualifier triggered

Suggested fix:

Remove the fixture-specific disqualified behavior before optimizing score.

## filler-pressure-007 (quickMove)

Score: `30/100`

User: How do I stop saying um under pressure?

Failure reasons:
- fixture disqualifier triggered: semantic words treated as fillers
- fixture-specific disqualifier triggered
- quality/provider fallback output cannot score as normal coaching
- reply does not match expected coach move

Suggested fix:

Hold back broken/scaffold output and return an honest failure notice or clean deterministic read.
