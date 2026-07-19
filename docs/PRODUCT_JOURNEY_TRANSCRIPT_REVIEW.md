# Product journey transcript review

Review date: 2026-07-19
Source commit: `fe0498e29`
Coach-source fingerprint: `sha256:0dd341ca95e6c86a06fac375080dbbf90db7af372194231b08f64eccd452e089`
Canonical artifact: `tools/coach-arena/reports/app-path/latest.json`

## Evidence boundary

These are exact user turns and final persisted coach replies emitted by the real Swift `CoachReplyPipeline`/`AskNoumStore` app-path harness. They are synthetic evaluation conversations, not real-user outcomes or live-provider proof. “Accepted + UI commit” means the request returned a coach reply, the quality gate passed, no accepted fallback was used, and the final coach row was present after store commit.

The complete fresh run contains 53 conversations and 109 text turns. The 20 transcripts below are a deliberately mixed review slice covering cold start, metrics, vulnerable pushback, preference repair, evidence boundaries, memory consent, transfer setup, and readiness calibration.

## Reviewed transcripts

| # | Scenario | User | Final coach reply | Lane | Terminal | First visible / complete | Review |
| ---: | --- | --- | --- | --- | --- | ---: | --- |
| 1 | Cold-start interview | “How do I get better before my interview?” | “No baseline yet, so start with evidence. Record 60 seconds on 'Why should we hire you?', answer in sentence one, give one proof, then stop and replay only the opener.” | coaching / general | Accepted + UI commit | 49 / 49 ms | Starts with an honest evidence gap, then gives one bounded baseline rep. |
| 2 | Filler under pressure | “How do I stop saying um under pressure?” | “When um wants to enter under pressure, hold a one-second silence instead because the gap stays quiet. Repeat the prompt and compare fillers per minute; treat one rep as a test, not a pattern.” | coaching / general | Accepted + UI commit | 49 / 49 ms | Preserves the semantic-filler invariant and avoids claiming one rep is a pattern. |
| 3 | Metric to action | “What should I do with that filler count?” | “Use the filler count as one baseline, not a pattern. Hold one silent beat after the decision line because that tests the timing move; then compare the rate on an equivalent rep.” | coaching / personal evidence | Accepted + UI commit | 74 / 74 ms | Converts a metric into a focused test rather than presenting the number as progress. |
| 4 | Robotic/long feedback | “This is robotic and too much writing.” | “You're right—that sounded robotic and was too long. I'll use one specific point in plain language: the recommendation came after the setup.” | preference / conversational | Accepted + UI commit | 48 / 48 ms | Repairs Noum’s behavior instead of assigning the user another drill. |
| 5 | TTS/format feedback | “The ** don't format and TTS reads them out. The responses feel robotic and cold, nowhere near an expert coach.” | “You're right—TTS read the formatting aloud, and the wording sounded robotic. I'll use plain text and one direct point: the recommendation came after the setup.” | preference / conversational | Accepted + UI commit | 50 / 50 ms | Owns both rendering and register failures in plain text. |
| 6 | Generic-AI feedback | “This still sounds cold and overexplained, like generic AI tips.” | “You're right—that sounded robotic and was too long. I'll use one specific point in plain language: reassurance came before the recommendation.” | preference / conversational | Accepted + UI commit | 57 / 57 ms | Makes a specific coach-side correction with a grounded read. |
| 7 | Authority distance | “How far off am I from sounding authoritative?” | “Not proven yet: the transcript shows mechanics—a recommendation and one controlled rep—but not authority under pressure. Missing repeated higher-stakes evidence; repeat the stakeholder answer with verdict first and a clean stop.” | coaching / personal evidence | Accepted + UI commit | 65 / 65 ms | Separates observed mechanics from an unsupported identity/readiness claim. |
| 8 | Dominant next step | “What next?” | “The close is the target because the latest transcript ends in explanation. Rewrite only the final sentence, then retry the same prompt with that ask.” | coaching / personal evidence | Accepted + UI commit | 73 / 73 ms | Produces one lever, one rewrite boundary, and an immediate retry. |
| 9 | Diagnosis boundary | “Why did that answer land badly?” | “From the transcript, I would treat it as a hypothesis: the recommendation arrived late. Next rep, say the conclusion first, then add one reason.” | coaching / personal evidence | Accepted + UI commit | 69 / 69 ms | Grounds the diagnosis and labels uncertainty before prescribing one change. |
| 10 | Sensitive pattern | “Do I sound defensive when I disagree?” | “Treat defensiveness as a hypothesis, not a label: the transcript softened the disagreement before the point. Check whether that fits, then say the disagreement first, give one reason, and stop.” | coaching / personal evidence | Accepted + UI commit | 75 / 75 ms | Keeps a sensitive pattern confirmable and rejects trait certainty. |
| 11 | Leadership transfer | “I have a leadership update tomorrow, what should I practice?” | “Your recent timed rep was solid on fillers but light on the close. Record a 75-second leadership update and make the final sentence the ask, not a summary.” | coaching / general | Accepted + UI commit | 53 / 53 ms | Connects prior evidence to a real upcoming moment and a single close target. |
| 12 | Depth without rambling | “How do I add depth without rambling?” | “Add one layer only: state the point, give one concrete example, then stop. That creates depth without opening a second thread.” | coaching / general | Accepted + UI commit | 53 / 53 ms | Uses a bounded answer shape and explains why it controls scope. |
| 13 | Polite pushback | “Okay, that's cool. However, I don't feel like that answered what I meant.” | “Fair push—I answered with advice when you wanted the read. Reassurance came before the recommendation; next time I'll name that ordering issue directly.” | preference / conversational | Accepted + UI commit | 46 / 46 ms | Detects soft dissatisfaction instead of treating politeness as success. |
| 14 | Not informative | “That's not informative at all.” | “You're right—that answer was vague. I should have said this plainly: reassurance came before the recommendation, so the listener had to wait for the point.” | preference / conversational | Accepted + UI commit | 50 / 50 ms | Replaces apology/canned language with a specific missing read. |
| 15 | Vulnerable pushback | “It's not easy.” | “You're right—this isn't easy. The setup carries social risk under pressure, so make it smaller: say the disagreement and one calm reason, then stop.” | vulnerable / conversational | Accepted + UI commit | 47 / 47 ms | Validates difficulty and lowers the existing prescription without unsolicited homework on standalone disclosure. |
| 16 | Repetition feedback | “You're repeating yourself.” | “You're right—I repeated the same instruction. I should have changed the evidence instead of sending you through the same drill again.” | preference / conversational | Accepted + UI commit | 47 / 47 ms | Correctly changes the coach’s proof strategy rather than blaming user effort. |
| 17 | Arena polite pushback | “Okay that's cool, however I still don't feel like that answers what I meant.” | “Fair push—I answered with advice when you wanted the read. Reassurance came before the recommendation; next time I'll name that ordering issue directly.” | preference / conversational | Accepted + UI commit | 46 / 46 ms | The punctuation variant reaches the same repair contract. |
| 18 | Brevity request | “Too much writing. Get to the point.” | “You're right—that was too long. I'll give the direct point in plain language: the answer kept explaining after the ask.” | preference / conversational | Accepted + UI commit | 45 / 45 ms | Terminal response is short and changes Noum’s output behavior. |
| 19 | Confidence close | “Why does my ending sound less confident?” | “The confidence leak is the extra softener after the recommendation. Your closing-strength focus is the ask: it starts sounding optional, so keep the recommendation, cut the final qualifier, and end on the ask.” | coaching / general | Accepted + UI commit | 48 / 48 ms | Names an observable lever and preserves the user’s meaning. |
| 20 | Score/readiness boundary | “I got 8/10. Am I ready for the board update?” | “Not proven yet: the timed rep and clear recommendation show useful mechanics, but not board readiness under pressure. Missing: repeated pressure evidence; run a board proof with verdict first, one reason, and a clean stop.” | coaching / personal evidence | Accepted + UI commit | 67 / 67 ms | Prevents a local score from masquerading as transfer or launch readiness. |

## Slice result

- Accepted final replies: 20/20.
- Quality-gate outcome `passed`: 20/20.
- Accepted fallbacks: 0/20.
- Silent loss, endless thinking, canned terminal output, or placeholder leakage observed: 0/20.
- First-visible-token range: 45–75 ms in this deterministic local harness. These timings are not live-provider or physical-device latency evidence.

## Remaining proof

This review supports local response shape and terminal-state coverage only. It does not close the live-provider sweep, professional-coach calibration, real-user longitudinal transfer, physical TestFlight, or operational launch gates.
