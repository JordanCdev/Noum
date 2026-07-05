# Coach Arena Failures

## Production Evidence Gate

- assessmentConfidence has only 1 distinct rounded value(s)

## Trace Quality Gate

- assessmentConfidence has only 1 distinct rounded value(s)

Repeated proof-test hashes:
- `15225bc3a8f5d742`: `repeating-yourself-005`, `filler-pressure-007`, `leadership-update-008`, `closing-ask-020`, `concise-answer-023`, `board-update-032`, `overexplaining-033`, `barge-in-045`, `real-world-outcome-047`
- `1da8bfcae44e5806`: `interview-prep-006`, `personal-pattern-consent-012`, `too-much-writing-017`, `no-baseline-interview-018`, `opening-verdict-021`, `upcoming-conflict-028`, `fear-disagreement-034`, `evasive-polished-037`, `quote-guard-043`
- `696c3d72287b1578`: `authoritative-distance-001`, `polite-however-pushback-003`, `not-easy-empathy-004`, `score-not-readiness-011`, `reject-hypothesis-013`, `leadership-transfer-capture-026`, `outcome-not-causation-027`, `authority-under-pressure-039`, `weekly-checkin-046`
- `93c07d25ebae00fe`: `confidence-ending-009`, `pace-rushing-019`, `pause-before-answer-022`, `confidence-clean-stop-025`, `presentation-nerves-030`, `live-latency-short-044`, `grammar-leak-048`, `placeholder-leak-049`
- `505fa914ffce9bf3`: `examples-from-sessions-010`, `structure-one-reason-024`, `networking-intro-029`, `sales-pitch-031`, `emotional-disconnection-036`, `no-transcript-fabrication-042`
- `fc0e67e26d92ee08`: `lack-conviction-035`, `timidity-038`, `semantic-filler-use-040`, `prompt-echo-041`
- `29dfb6faa4ac37c7`: `not-informative-trust-repair-002`, `markdown-tts-015`
- `9eb06db8540c3377`: `cold-generic-016`, `assistant-wrapper-050`

## examples-from-sessions-010 (groundedRead)

Score: `61/100`

User: Can you give me an example of me doing this in sessions?

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## outcome-not-causation-027 (groundedRead)

Score: `50/100`

User: The room seemed engaged. Did the drill cause that?

Failure reasons:
- reply does not match expected coach move

Suggested fix:

Answer the requested move: Reject causal proof, name association, ask what to repeat.

## upcoming-conflict-028 (quickMove)

Score: `61/100`

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

Score: `68/100`

User: My sales pitch loses people after the first minute.

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## lack-conviction-035 (deepAssessment)

Score: `59/100`

User: Do I lack conviction?

Failure reasons:
- deep assessment lacks verdict/evidence calibration

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## emotional-disconnection-036 (groundedRead)

Score: `50/100`

User: It sounds correct but not like me. What do I change?

Failure reasons:
- fixture disqualifier triggered: no reflection check
- fixture-specific disqualifier triggered
- reply does not match expected coach move

Suggested fix:

Answer the requested move: Validate self-report, preserve structure, change one phrase to user-owned language.

## evasive-polished-037 (deepAssessment)

Score: `63/100`

User: Could this sound polished but evasive?

Failure reasons:
- No explicit reason; score below threshold.

Suggested fix:

Tighten diagnosis, cite one real signal, and prescribe one testable move.

## semantic-filler-use-040 (groundedRead)

Score: `50/100`

User: You counted 'like' but I meant it as a comparison.

Failure reasons:
- fixture disqualifier triggered: no adjusted rule
- fixture-specific disqualifier triggered
- low-EQ reply: emotional signal is not acknowledged
- reply does not match expected coach move

Suggested fix:

Start by naming the user's friction in human language, then give one changed coaching move.

## live-latency-short-044 (quickMove)

Score: `50/100`

User: Quickly, what do I do next?

Failure reasons:
- missing evidence anchor
- reply does not match expected coach move

Suggested fix:

Answer the requested move: One short coach read and action, no essay.

## real-world-outcome-047 (groundedRead)

Score: `50/100`

User: My interview answer landed better than practice. What do we learn?

Failure reasons:
- fixture disqualifier triggered: no reusable move
- fixture-specific disqualifier triggered
- reply does not match expected coach move

Suggested fix:

Answer the requested move: Name self-reported transfer, identify likely reusable move, no causal proof.

## grammar-leak-048 (quickMove)

Score: `50/100`

User: What is the one move?

Failure reasons:
- missing evidence anchor
- reply does not match expected coach move

Suggested fix:

Answer the requested move: No labels or JSON; one sentence move.

## placeholder-leak-049 (quickMove)

Score: `50/100`

User: Can you coach this?

Failure reasons:
- missing evidence anchor
- reply does not match expected coach move

Suggested fix:

Answer the requested move: Either answer with grounded move or honest failure notice; never placeholder.
