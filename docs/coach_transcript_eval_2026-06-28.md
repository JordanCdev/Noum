# Ask Noum Transcript Evaluation - 2026-06-28

Status: evaluation artifact, not a production-readiness claim.

This file records 12 end-to-end Ask Noum fixture conversations from
`CoachChatEvaluationCorpus.latestManualEvalFixtureIDs`. These are target
transcripts and regression fixtures, not live provider outputs. The live path is
still `CoachLiveEvaluationTests.liveGeminiRepliesClearFixtureRubric`, which now
prints provider requested/chosen tier, chosen provider/model,
`providerAttemptCount`, `providerRetryCount`, `providerRefusalCount`,
`timeToFirstVisibleTokenMs`, `timeToFirstVisibleTokenSource`, completion
latency, `trajectoryCacheHit`, `assessmentCacheHit`, `assessmentCacheAgeMs`,
`assessmentProofTestHash`, `immediateCoachReadShown`, `replyWordCount`, trust
friction flags, `visionScore`, reliability issues, and `liveProductionFloor`.
`timeToFirstVisibleTokenMs` is exact when the stream-visible callback fires and
otherwise names the proxy source. It also writes a schema-versioned
`coach-live-eval-v1` JSON sidecar beside the markdown transcript so telemetry
and gate outcomes can be diffed across live runs. It fails unless quality gate,
semantic gate, senior-coach rubric, vision floor, and reliability cleanliness
all pass.

The same 12 conversations are now mirrored in
`CoachChatConversationCorpus.conversations` as three-turn, machine-scored
target transcripts. That corpus is still not live-provider evidence; it is a
repeatable target-shape gate that keeps the full conversation standard from
living only in prose.

2026-06-29 replay update: all 12 target conversations now pass
`CoachChatConversationCorpusTests`, including
`targetConversationsAreAcceptedByRuntimeGateAcrossHistory`, which routes all 30
target turns through `AICoachChatService.reply(...)`. The corpus also replays
`CoachReliabilityGate` over the same turn history and records per-turn
reliability issues in the report. This remains target-shape evidence, not a
production-readiness claim.

2026-06-29 report v9 update: the 12-conversation report now records per-turn
runtime quality/vision labels (`turnRuntimeIssues`, `runtimeIssues`,
`passesRuntimeGate`) and typed semantic-judgement labels (`turnSemanticIssues`,
`semanticIssues`, `passesSemanticGate`) using the same `auditLabel` vocabulary
as the live pipeline. `passesProductionFloor` now requires conversation score,
runtime gate cleanliness, semantic gate cleanliness, and reliability
cleanliness. Deliberately bad injected conversations prove both paths: an
"Understood." reply fails with professional + vision labels, and a hollow
trust-repair reply fails with `semantic:missingRepairInsight`. A polite
pushback variant now also fails when the reply merely says "but" before
prescribing again instead of naming the user's actual friction.
Rows also expose `turnDepths`, `trustRepairTurnIndices`,
`userPushbackWithinTwoTurns`, `coldnessComplaintFlag`, and
`coldnessComplaintTurnIndices`, plus `softPushbackFlag` and
`softPushbackTurnIndices`, so offline transcript review can see where trust
friction happened instead of treating a high-scoring repair as context-free.

2026-06-29 trust-repair hardening update: the semantic gate now rejects hollow
"I sounded cold because..." apologies when they do not include a concrete read
or evidence anchor, and it no longer accepts `but` as proof that Noum has
acknowledged polite pushback. The 12-conversation target corpus still passes,
but this is only a guardrail improvement. Harsh production score: **67/100** against
`docs/VISION.md`; the remaining gap is still live, expert-calibrated coach
presence and validated transfer outcomes, not another local transcript pass.

## Research Anchors

- IMBUE found that simulation plus just-in-time feedback improved skill mastery,
  while simulation alone did not transfer as well.
  https://arxiv.org/abs/2402.12556
- CARE found practice with structured feedback improved counselor behaviors more
  reliably than practice alone.
  https://arxiv.org/abs/2505.02428
- LLM motivational interviewing work reinforces that empathy, adherence, and
  actionability need separate measurement.
  https://arxiv.org/abs/2505.17362
- Recent production multi-turn judge work found automated judges can miss
  cross-turn state/recovery defects even when turn-local scoring looks clean;
  this is why the conversation report has explicit state-retention and
  non-repetition gates instead of only averaging single-turn scores.
  https://arxiv.org/abs/2606.10315
- 2026 multi-turn reliability work reports sharp reliability degradation when
  global instructions, tool choices, or structured state have to survive longer
  conversations with distractions; this supports replaying target conversations
  across history rather than scoring isolated replies.
  https://arxiv.org/abs/2603.01423
- RankJudge's paired-conversation construction injects one flaw into one turn so
  the evaluator can isolate the failure category. The corpus now mirrors that
  pattern with paired reliability variants for near-duplicate, repeated
  proof-test, and no-attunement trust-repair smells.
  https://arxiv.org/abs/2605.21748

## Scoring Contract

Machine scoring path:

- `AICoachChatService.coachVisionEvaluation(...)`
- `AICoachChatService.visionQualityIssue(...)` is the runtime gate for
  critical misses and clearly weak scores.
- `CoachLiveEvaluationTests.liveGeminiRepliesClearFixtureRubric` now treats
  `CoachReliabilityGate` issues as live production-floor failures rather than
  diagnostic-only lines. A live transcript with a near-duplicate answer,
  no-attunement trust repair, repeated proof test, scaffold leak, or flat
  confidence-with-evidence smell is not green even if its rubric and vision
  score pass. The pure `liveProductionFloor(...)` helper is covered by
  skipped-provider tests, so this contract is verified without spending live AI
  calls.
- The live fixture sweep now carries recent assessment proof tests across
  fixtures before building the next `CoachAssessment`, mirroring the app
  pipeline's history-based `recentProofTests` handoff. This prevents the live
  transcript artifact from manufacturing the exact repeated-proof-test smell
  the production pipeline is designed to avoid. The same sweep also passes a
  normalized `proofTestRecentlyRepeated` flag into `CoachReliabilityGate`, so a
  repeated proof test fails the live production floor as `repeatedProofTest`.
- `CoachLiveEvaluationTests` now writes a `coach-live-eval-v1` JSON sidecar
  next to the markdown transcript. Rows include fixture ID, user turn,
  provider routing, latency source, assessment freshness/confidence/proof hash,
  trust-friction flags, diagnostics, accepted reply word count, rubric/vision
  scores, semantic gate issue, reliability issues, `liveProductionFloor`, and
  failure text for failed turns. Its run-level `summary` also records failure
  count/fixture IDs, proof-hash variety, repeated proof-hash count, confidence
  range and rounded diversity, reply-word-count range/average, expected-vs-shown
  immediate local coach reads, retry/refusal pressure, first-visible latency
  range, and trust-friction counts. It derives
  typed `readinessWarnings` for no-row runs, production-floor failures, repeated
  proof hashes, flat confidence, uniform reply length, missing expected
  immediate coach reads, retry/refusal pressure, and slow first-visible latency;
  `passesRunReadinessFloor` requires both clean row-level gates and no run-level
  warnings. This is a live-eval health floor, not a human-coach parity claim.
  Provider-only transcript captures may honestly fail this floor until they
  exercise `CoachReplyPipeline`'s provisional-read branch; that is the point of
  separating provider quality from actual app-path real-time behaviour. The
  sidecar is redacted: no prompts, API keys, request bodies, or failed draft
  text.
- `CoachReplyPipelineProvisionalReadTests` now exercises that app path with an
  isolated `AskNoumStore` and a no-provider `AICoachChatService`: the live
  pipeline must render the deterministic immediate coach read into the pending
  row before the final typed provider notice, and final metadata must preserve
  `immediateCoachReadShown=true`. This proves the local-read branch is wired,
  while still leaving live provider quality to the transcript harness.
- The same suite now also runs a successful two-turn text pipeline through an
  isolated `AskNoumStore` plus scripted OpenAI transport. A repeated pacing
  question must land as two real coach rows, carry typed assessment metadata on
  both rows, read the first row's prior proof test through `replayForModel`, and
  choose a different second proof test with `proofTestRecentlyRepeated=false`.
  This closes the gap between lower-level assessment-cache variation and the
  actual app thread path.
- Skipped-provider live-harness tests now replay the latest transcript fixture
  set through the deterministic judgement pass and require non-flat
  `assessmentConfidence`, varied proof tests, and varied direct verdicts before
  any provider call is made. This directly guards the "0.20 confidence / same
  proof test / same verdict" failure mode from the research report.
- `CoachTurnMetadata.qualityGateOutcome` records whether the final user-visible
  reply passed cleanly, was repaired, used a fallback, or failed, plus compact
  failure/repair counts. It stores gate labels only, never failed draft text.
- `CoachChatEvaluationCIReport` schema v5 now includes turn depth, runtime-gate
  booleans, reference reliability issues, reference reliability pass/fail, and
  a strict `referencePassesProductionFloor` conjunction across rubric, quality
  gate, vision floor, runtime vision gate, and reliability cleanliness. CI
  artifacts now expose the production-floor decision in addition to raw vision
  scores; this is still evaluation substrate, not a launch-readiness claim.
- `CoachChatConversationEvaluationReport` schema v9 scores the 12 three-turn
  target transcripts against a zero-start conversation rubric: direct answer,
  evidence calibration, observable anchor, prescribed practice, rationale
  bridge, follow-up continuity, state retention, non-repetitive trajectory,
  proof-test progression, adaptive repair, repair carryover, transfer proof,
  senior register, and brevity. Known-bad variants must remain far below target
  transcripts; stale state variants must fail the state-retention gate even when
  they do not repeat the exact same reply; repeated-proof variants must fail the
  proof-test progression gate even when the rest of the reply still reads
  coherently. Generic advice, evidence overclaims, and pasted-same-reply
  conversations are hard-capped below the passing band so a plausible local
  answer cannot masquerade as a competent multi-turn coach. Report rows now
  include the full three-turn transcript, per-turn vision scores,
  `passesRuntimeGate`, `passesSemanticGate`, `passesReliabilityGate`,
  `passesProductionFloor`, `turnRuntimeIssues`, flattened `runtimeIssues`,
  `turnSemanticIssues`, flattened `semanticIssues`, `turnReliabilityIssues`, and
  flattened `reliabilityIssues`, plus `turnDepths`, `trustRepairTurnIndices`,
  `userPushbackWithinTwoTurns`, `coldnessComplaintFlag`, and
  `coldnessComplaintTurnIndices`, so reviews can inspect the actual
  conversation, runtime gate projection, typed semantic judgement projection,
  trust-friction signals, and last-mile reliability replay rather than only a
  pass/fail summary.
  `passesProductionFloor` is the offline conjunction of conversation floor,
  runtime gate cleanliness, semantic gate cleanliness, and reliability
  cleanliness; it is not a live-provider readiness claim.
- Paired reliability variants now inject one near-duplicate second turn, one
  repeated proof-test trajectory, and one trust-repair-without-attunement case.
  Those variants must trip `nearDuplicateReply`, `repeatedProofTest`, and
  `noAttunementOnPushback` respectively, while the target transcripts must
  remain reliability-clean. The report must mark those reliability variants as
  failing `passesProductionFloor` even when their prose still reads plausibly.
- `CoachReliabilityGate` no longer treats any bare "let me..." opening as trust
  repair. "Let me give you the drill..." still trips `noAttunementOnPushback`;
  only repair-specific openings such as "let me repair/fix/correct..." count.
- `CoachReplyPipeline` quality-gate aggregation is pinned for rejected-then-pass,
  rejected-then-repair, rejected-then-fallback, and final failure paths.
- Trust-repair turns now carry `CoachAssessment.toneMode = repair` and an
  optional `repairFocus`; soft pushback such as "Okay, that's cool. However..."
  routes to trust repair after a coach reply. Provider verbalisation and the
  semantic gate must name that repair focus before prescribing another drill.
- Trust repair must now include a concrete coach read, not only a style repair.
  If a focused repair reply acknowledges "cold/robotic/generic" feedback and
  jumps straight to a proof test without a behavioral signal, evidence anchor,
  or actual read, the semantic gate fails it as `missingRepairInsight`. Broad
  glue words such as "because", "target", or "behavior" no longer count by
  themselves; the reply must touch non-repair evidence or state the actual
  coach read explicitly.
- Turn metadata now persists `assessmentCacheHit`, `assessmentCacheAgeMs`,
  `immediateCoachReadShown`, `replyWordCount`, `providerTierChosen`, `providerAttemptCount`,
  `providerRefusalCount`, a real `providerRetryCount` derived from provider
  events rather than quality-gate failures, plus explicit
  `timeToFirstVisibleTokenMs` and `timeToCompleteReplyMs` aliases matching the
  research telemetry list for proving two-speed readiness, freshness, latency,
  routing, and reply-shape variation.
- The live transcript harness now prints and JSON-encodes that same turn-level telemetry:
  provider attempt/retry/refusal counts, first-visible latency with an explicit
  source (`streamedPartialVisible`, `providerFirstTokenDiagnostic`,
  `completedReplyProxy`, or `unavailable`), completion latency, proof-test
  hash, `immediateCoachReadShown`, `replyWordCount`, `userPushbackWithinTwoTurns`,
  `coldnessComplaintFlag`, `softPushbackFlag`, and `voiceBargeInOccurred`. The
  text harness records `immediateCoachReadShown: false` rather than implying a
  two-speed live read happened outside the app pipeline.
- Turn metadata now also persists `softPushbackFlag`, matching the v9
  transcript report's `softPushbackFlag` / `softPushbackTurnIndices` fields, so
  live saved threads can distinguish "okay, however..." hesitation from
  explicit coldness complaints.
- AI-call diagnostic reason text now keeps a wider bounded payload so the
  trust-loss fields survive in the debug record instead of being truncated
  before review.
- `semanticGateIssue` is persisted separately from the final semantic outcome,
  so a repaired answer can still show which judgement issue was caught before
  the user saw the final reply.
- `AICoachChatService.replyQualityIssue(...)` now accepts recent coach replies
  and trips `professional:repeatedProofTest` when a provider repeats the same
  action/proof-test sentence from the recent thread. The repair prompt receives
  compact recent-action fingerprints and must vary the target, condition, or
  evidence check before the reply can be accepted.
- `CoachAssessmentCache` now wraps the deterministic reasoning pass, keyed by
  turn depth, normalized user turn, trajectory signature, active rubric, recent
  proof tests, and previous coach reply. `assessmentCacheAgeMs` now measures
  the typed judgement object's age, not the trajectory snapshot age.
- `PracticeSessionFinalizer` now prewarms `UserTrajectoryCache` after the
  session, baseline, and rating writes land, so the first Ask Noum turn after a
  rep should report a warm trajectory snapshot. The later summary/coach-memory
  lifecycle still refreshes the cache with the richer durable case formulation.
- When a user sends trust-repair pushback after a coach reply, the prior coach
  row now records `userPushbackWithinTwoTurns`; cold/generic/robotic/low-EQ
  complaints additionally set `coldnessComplaintFlag`, while polite
  "okay/however" resistance sets `softPushbackFlag`, giving transcript audits a
  direct trust-loss signal instead of treating every pushback as identical.
- Live-call barge-ins now set `voiceBargeInOccurred` on the interrupted coach
  row and preserve it if the user interrupts the immediate local read before
  final provider metadata arrives.
- 100-point score starts at zero and earns criteria:
  direct answer, observable anchor, prescribed action, insight bridge,
  evidence honesty, adaptive repair, personalization, transfer proof, senior
  register, and brevity.
- Production floor: `score >= 85` and no critical misses.
- Runtime reject floor: critical misses always reject; non-live text replies
  below 70 reject; text deep-assessment replies below 74 reject; live replies
  use a lower reject floor so the spoken surface does not become brittle.
- Runtime gate scope: applies to coaching, judgement, critique, deep-assessment,
  and action-seeking turns. Simple acknowledgements such as "thanks" are not
  forced through the coaching-answer rubric.
- Hard caps: unsupported evidence or robotic register cannot exceed 44; missing
  anchor or action cannot exceed 48; missing bridge cannot pass production.

Manual score below is intentionally harsh. The machine corpus score now runs as
`CoachChatConversationCorpusTests`; live provider transcripts are still required
before this becomes production evidence.

## Conversation 1 - Cold Start Interview Baseline

Fixture: `cold-start-interview-baseline`

Context: no profile voice, no rated sessions, no stable baseline.

Transcript:

User: How do I get better before my interview?

Noum target: No baseline yet, so the honest move is one interview rep. Record 60
seconds on a likely question, then review whether the first sentence gives the
point before polishing anything.

User: What should I listen for in the replay?

Noum target: For your first baseline rep, listen for sentence one only. If it
names the answer before the setup, keep it. If it starts with background,
rewrite that first sentence and run the rep again.

User: So not my whole speaking style yet?

Noum target: Right, because one rep is too thin for a style diagnosis. Use this
first pass to create the baseline, then Noum can judge whether the same pattern
repeats.

Manual vision grade: 86/100.

Why it passes: honest cold start, one practice move, no fake diagnosis, and a
clear answer when the user asks about scope.

Remaining gap: thin personalization until the interview type or a real rep is
available.

## Conversation 2 - Filler Under Pressure

Fixture: `filler-pressure-prescription`

Context: concise voice, recent timed rep had 6 fillers, trend says fillers are
worse under pressure.

Transcript:

User: How do I stop saying um under pressure?

Noum target: Last rep had 6 fillers; the pressure cue is showing up before the
close. Next rep, hold one beat before the final sentence and check whether
fillers drop after that point.

User: Do I pause before every sentence?

Noum target: No, because the pause belongs where the pressure leaks: before the
close. If you pause everywhere, the answer will sound managed instead of steady.

User: What proves it worked?

Noum target: Use the same 60-second prompt and timer because you only want to
test the pause point. Success is fewer fillers after that point and a final
sentence that still lands cleanly.

Manual vision grade: 84/100.

Why it passes: grounded metric, specific replacement behavior, pressure-aware
boundary, and proof criteria.

Remaining gap: "cut every filler" is slightly absolute; better wording would
test whether the count drops after that point.

## Conversation 3 - Metric Without Coaching Read

Fixture: `metric-action-without-read`

Context: authoritative voice, recent rep had 5 fillers inside the decision line.

Transcript:

User: What should I do with that filler count?

Noum target: Last rep had 5 fillers; the signal is inside the recommendation,
not before it. Next rep, hold one beat after the decision line and restart if a
filler appears.

User: Why after the decision line?

Noum target: Because the filler is interrupting the moment where authority
should sound settled. The pause after the decision gives your reason somewhere
to go without weakening the recommendation.

User: What do I run next?

Noum target: Use a 45-second recommendation prompt because it tests the decision
line without inviting a full essay. Sentence one is the decision, sentence two
is one reason, then stop cleanly.

Manual vision grade: 88/100.

Why it passes: treats the metric as evidence, not the whole read, and converts
the read into a sequence-level prescription.

Remaining gap: "restart if a filler appears" may feel rigid in live mode.

## Conversation 4 - Robotic Writing Trust Repair

Fixture: `critique-trust-repair`

Prior Noum reply: Recent reps show a decline in scores, so you should optimize
your communication plan.

Transcript:

User: This is robotic and too much writing.

Noum target: Fair push: that read was robotic and too much writing. The last rep
gives enough signal; next rep, use one clean opener and stop after the point
lands.

User: What was generic about it?

Noum target: That was generic because it named a plan without naming the behavior.
The target is the opener: run a 45-second rep where sentence one lands before
the explanation starts.

User: Give me the short version.

Noum target: Short version: the opener is the target because the prior reply
buried the behavior. Open with the point, add one reason, then stop. Run that
once and check whether sentence one lands before any setup.

Manual vision grade: 82/100.

Why it mostly passes: acknowledges the friction, explains the miss, and returns
to one action.

Remaining gap: first repair is still a little written; the final short version
is closer to the desired register.

## Conversation 5 - Markdown/TTS Trust Repair

Fixture: `markdown-tts-trust-repair`

Prior Noum reply: **Read:** Your last rep has fillers. **Move:** practice more.

Transcript:

User: The ** don't format and TTS reads them out. The responses feel robotic and
cold, nowhere near an expert coach.

Noum target: Fair push: the asterisks should never reach you or the voice, and
that made the coaching feel robotic and cold. Your last rep had 4 fillers, so
for the next rep, state the recommendation first, give one proof, then stop. No
symbols, no report shape.

User: And stop saying "practice more."

Noum target: Agreed: that was too generic. The move is not more volume; the
target is a cleaner first sentence because it turns vague advice into a testable
line: recommendation, one proof, stop.

User: What should I record?

Noum target: Record one 45-second answer to a recommendation prompt because it
tests whether the first sentence carries the recommendation. If sentence one is
not the recommendation, restart.

Manual vision grade: 87/100.

Why it passes: repairs the exact UI/TTS failure, rejects generic advice, cites
real evidence, and prescribes one changed move.

Remaining gap: still target-shaped; the live provider must consistently avoid
symbolic formatting.

## Conversation 6 - Assistant Explainer Register

Fixture: `assistant-explainer-register`

Prior Noum reply: Here are some tips to communicate more clearly: be clear and
concise and practice often.

Transcript:

User: This still sounds cold and overexplained, like generic AI tips.

Noum target: Fair push: that was advice, not coaching. Your last rep has the
useful signal: warmth came before the recommendation, so next rep say the
recommendation first, then soften it with one reassurance.

User: Does that make me sound less warm?

Noum target: No. The target is placement, not less warmth: lead with the
decision so people know what you mean, then use warmth to make the decision
easier to hear.

User: Give me the pattern.

Noum target: Next rep, say: recommendation, one reason, one reassurance, then
stop, because it keeps warmth after clarity.

Manual vision grade: 91/100.

Why it passes: names the felt failure, uses the actual transcript pattern, and
preserves warmth without letting it bury the recommendation.

Remaining gap: live tone still needs provider verification.

## Conversation 7 - Authoritative Distance Assessment

Fixture: `authoritative-distance-deep-assessment`

Context: authoritative voice, one 7/10 timed rep, 1 filler, no repeated pressure
evidence.

Transcript:

User: How far off am I from sounding authoritative?

Noum target: You are closer mechanically than you are to sounding authoritative
overall. The transcript opens with a recommendation, and the latest timed rep
was 7/10 with 1 filler, so the mechanics are partly landing, but goal readiness
still needs repeated pressure evidence. Missing: more than one clean rep under
stakes. Proof test: record a 75-second answer with the verdict in sentence one,
one reason, and a clean stop.

User: Is 7/10 bad?

Noum target: No. 7/10 means the mechanics are not the bottleneck yet. The open
question is whether the same steadiness survives a more consequential prompt.

User: What would make you change the diagnosis?

Noum target: Record 2 clean pressure reps with verdict-first openings because
that is the evidence that would move the diagnosis from mechanics to presence:
less explaining, more settled commitment.

Manual vision grade: 93/100.

Why it passes: separates score from goal readiness, names missing evidence, and
uses repeated pressure evidence as the threshold for stronger judgment.

Remaining gap: should be checked with `assessment.confidence` in the live report
to avoid over-reading one rep.

## Conversation 8 - What Next

Fixture: `what-next-single-move`

Prior Noum reply: Which direction would you prefer?

Context: executive voice, recent clean rep, trend says close lost force.

Transcript:

User: What next?

Noum target: The pattern I'd pick is the rushed close. Review the last
transcript, rewrite only the final sentence, then run one rep with that close as
the target.

User: Why the close instead of the opening?

Noum target: In the last transcript, the opening is serviceable enough. The close
is where the authority leaks because the answer ends as a summary instead of an
ask.

User: What is the exact rep?

Noum target: 60 seconds, same topic, because it isolates the close. Last sentence
must be the ask. If it turns into a recap, run it once more.

Manual vision grade: 86/100.

Why it passes: chooses one move instead of a menu and explains why that move
wins over another possible focus.

Remaining gap: could cite the trend more concretely: "close lost force in recent
reps."

## Conversation 9 - Overclaim Boundary

Fixture: `overclaim-hypothesis-boundary`

Context: authoritative voice, recent transcript says the recommendation arrived
late.

Transcript:

User: Why did that answer land badly?

Noum target: From the transcript, I would treat it as a hypothesis: the
recommendation arrived late. Next rep, say the conclusion first, then add one
reason.

User: So I am not bad at authority?

Noum target: I would not claim that from this transcript. The observable issue
is order: the listener waits too long for the conclusion.

User: What test separates those?

Noum target: Run the same answer verdict-first because it separates structure
from authority. If it lands better with the same voice and filler count, the
issue was structure, not authority.

Manual vision grade: 85/100.

Why it passes: frames the read as a hypothesis, avoids trait labels, and gives a
disconfirming test.

Remaining gap: could add one more real-world transfer prompt for stronger proof.

## Conversation 10 - Leadership Transfer Setup

Fixture: `leadership-transfer-setup`

Context: executive voice, upcoming leadership update, recent timed rep solid on
fillers but light on close.

Transcript:

User: I have a leadership update tomorrow, what should I practice?

Noum target: Your recent timed rep was solid on fillers but light on the close.
Record a 75-second leadership update and make the final sentence the ask, not a
summary.

User: I do not know the ask yet.

Noum target: For the 75-second update, use a placeholder ask: "I need alignment
on the next step," because it lets you train the shape of the close before the
business content is final.

User: What should I check after?

Noum target: Check only the final 10 seconds of the 75-second update, because
that is where the update transfers into the room. If the last sentence asks for
alignment or a decision, keep it; if it recaps, rewrite the close.

Manual vision grade: 89/100.

Why it passes: bridges recent practice into tomorrow's real situation and gives
an action even when the exact business ask is unknown.

Remaining gap: could name the actual ask if known from BigMoment or ForwardPlan
context.

## Conversation 11 - Answer Depth One Example

Fixture: `answer-depth-one-example`

Context: executive voice, recent vendor recommendation, 0 fillers, trend says
answers need one concrete example before they expand.

Transcript:

User: How do I add depth without rambling?

Noum target: Your last rep has strong reasons; the signal is no concrete example
for the listener to picture. Next rep, keep the same claim, add one example,
then stop before adding a second thread.

User: Can you give me an example of me doing this in sessions?

Noum target: In the vendor rep, you said implementation risk was lower and the
team already knew the workflow. Those are reasons, not a picture, so add one
concrete example after the first reason, then stop.

User: What should I record?

Noum target: Record the same executive recommendation in 60 seconds because it
isolates answer depth. Sentence one is the claim, sentence two is one reason,
sentence three is one example, then stop.

Manual vision grade: 88/100.

Why it passes: answers the user's example request with a specific prior-session
signal, distinguishes reasons from a concrete example, and keeps the next drill
bounded.

Remaining gap: still target-shaped; live replies must cite examples without
fabricating quotes or turning into a transcript report.

## Conversation 12 - Polite Pushback Attunement

Fixture: `assistant-explainer-register`

Context: warm voice, client concern rep where reassurance came before the
recommendation, and the previous coach answer sounded like generic tips.

Transcript:

User: Okay, that's cool. However, I don't feel like that answered what I meant.

Noum target: Fair push: that was generic advice instead of evidence, and there
is friction underneath the polite pushback. The actual read is warmth came before
the recommendation, so the listener waits for the point. Next rep, say the
recommendation first, then one reassurance.

User: What did you miss?

Noum target: I missed the hesitation in your pushback. Your last rep gives the
actual read: the comfort came first and the point arrived late. You were asking
for that behavior, not a harder drill.

User: How do I test that without sounding harsh?

Noum target: Run one 45-second client concern answer. Sentence one is the
recommendation; sentence two is one reassurance. That tests order without
removing warmth, because the tone stays kind while the point arrives first.

Manual vision grade: 87/100.

Why it passes: treats "okay, however" as a trust signal, names the hesitation
before prescribing, keeps warmth as a goal rather than flattening the user into
a harder-drill frame, and gives a bounded proof test.

Remaining gap: still target-shaped; live replies must show the same attunement
without sounding self-referential or scripted.

## Aggregate Read

Manual average across these target conversations: 87.2/100.

This is not a production score. It is a target-shape score. Production readiness
requires the live provider path to generate replies at this level, the machine
vision score to pass, and the transcript set to be reviewed against expert or
human-coach baselines.
