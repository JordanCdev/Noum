# Coach Arena Failures

## Production Evidence Gate

- source Swift app-path readiness warnings: appPathFloorFailures,targetReplyMismatch,semanticGateFailures,visionFloorFailures
- source Swift app-path report did not pass its app-path floor

Source app-path failure samples:

- `filler-pressure-prescription` / `not-easy-empathy-conversation` turn `1`: `appPathFloor, qualityGate, targetReplyMismatch`; semantic `passed`; quality `fallback:typedAssessment`
  User: Is it the pause or the close?
  Final: Your last rep gives one usable signal: latest rep Timed, so use one silent beat after the verdict, then finish the answer without speeding up.
  Target: Your last rep gives one usable signal: under pressure, the close needs one silent beat after the verdict. Use that beat, then finish the answer without speeding up.
- `lack-conviction-035` / `arena-lack-conviction-035-app-path-conversation` turn `0`: `appPathFloor, qualityGate, semanticGate, targetReplyMismatch, visionFloor`; semantic `failed:unsupportedClosenessClaim`; quality `fallback:deterministicAssessmentAfterContentRejected`
  User: Do I lack conviction?
  Final: I do not have enough evidence for an overall authoritative communication verdict yet. The signal I can use is hypothesis: Filler Words appears to be the highest-leverage focus because it keeps showing up in the rolling b...
  Target: There is not enough evidence to call this lack of conviction overall. The latest rep and pace estimate only support a mechanics signal: hedge control before the recommendation, not an identity verdict. Missing: repeated...

## examples-from-sessions-010 (groundedRead)

Score: `61/100`

User: Can you give me an example of me doing this in sessions?

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## outcome-not-causation-027 (groundedRead)

Score: `69/100`

User: The room seemed engaged. Did the drill cause that?

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## upcoming-conflict-028 (quickMove)

Score: `57/100`

User: I have a difficult conversation tonight. What should I practice?

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## networking-intro-029 (quickMove)

Score: `63/100`

User: I ramble when introducing myself at networking events.

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## sales-pitch-031 (quickMove)

Score: `67/100`

User: My sales pitch loses people after the first minute.

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## emotional-disconnection-036 (groundedRead)

Score: `69/100`

User: It sounds correct but not like me. What do I change?

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## evasive-polished-037 (deepAssessment)

Score: `60/100`

User: Could this sound polished but evasive?

Failure reasons:
- fixture disqualifier triggered: personality judgment
- fixture-specific disqualifier triggered

Suggested fix:

Remove the fixture-specific disqualified behavior before optimizing score.

## live-latency-short-044 (quickMove)

Score: `63/100`

User: Quickly, what do I do next?

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## real-world-outcome-047 (groundedRead)

Score: `67/100`

User: My interview answer landed better than practice. What do we learn?

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## grammar-leak-048 (quickMove)

Score: `60/100`

User: What is the one move?

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## placeholder-leak-049 (quickMove)

Score: `50/100`

User: Can you coach this?

Failure reasons:
- reply does not match expected coach move

Suggested fix:

Answer the requested move: Either answer with grounded move or honest failure notice; never placeholder.
