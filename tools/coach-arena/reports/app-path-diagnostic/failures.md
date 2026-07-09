# Coach Arena Failures

## Production Evidence Gate

- 2 app-path fixture(s) below local quality floor 70: filler-pressure-007,not-easy-empathy-004
- 50 real-pipeline trace(s) missing first-token source
- source Swift app-path freshness: dirty coach source files after app-path dump: Noum/AICoachChatService.swift,Noum/AskNoumStore.swift,Noum/CoachContextBuilder.swift,Noum/CoachReliabilityGate.swift,Noum/CoachReplyPipeline.swift,NoumTests/CoachChatConversationEvaluationTests.swift,NoumTests/CoachChatEvaluationFixtures.swift,NoumTests/CoachJudgementLayerTests.swift,+3 more
- source Swift app-path freshness: source app-path git commit(s) do not match current HEAD: a556f772
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

## Trace Quality Gate

- 50 real-pipeline trace(s) missing first-token source

Repeated proof-test hashes:
- `1da8bfcae44e5806`: `evasive-polished-037`, `quote-guard-043`, `live-latency-short-044`, `grammar-leak-048`, `placeholder-leak-049`
- `60fd8fcf9223a028`: `confidence-ending-009`, `pace-rushing-019`, `confidence-clean-stop-025`
- `7f6851a30be7eb60`: `polite-however-pushback-003`, `reject-hypothesis-013`, `leadership-transfer-capture-026`
- `def04e50d54df7ca`: `personal-pattern-consent-012`, `upcoming-conflict-028`, `fear-disagreement-034`
- `e40b13097d07fb20`: `structure-one-reason-024`, `lack-conviction-035`, `timidity-038`
- `16cf05d07197879f`: `interview-prep-006`, `no-baseline-interview-018`
- `29dfb6faa4ac37c7`: `not-informative-trust-repair-002`, `markdown-tts-015`
- `4be6cb9d66613054`: `closing-ask-020`, `concise-answer-023`
- `61c7f48e58c086b9`: `outcome-not-causation-027`, `real-world-outcome-047`
- `696c3d72287b1578`: `authority-under-pressure-039`, `weekly-checkin-046`

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
