# Ask Noum Transcript Evaluation - 2026-06-28

Status: evaluation artifact, not a production-readiness claim.

This file records 10 end-to-end Ask Noum fixture conversations from
`CoachChatEvaluationCorpus.latestManualEvalFixtureIDs`. These are target
transcripts and regression fixtures, not live provider outputs. The live path is
still `CoachLiveEvaluationTests.liveGeminiRepliesClearFixtureRubric`, which now
prints provider requested/chosen tier, chosen provider/model, completion
latency, `trajectoryCacheHit`, `assessmentCacheHit`, `assessmentCacheAgeMs`,
`visionScore`, and fails below `passesProductionFloor`.

The same 10 conversations are now mirrored in
`CoachChatConversationCorpus.conversations` as three-turn, machine-scored
target transcripts. That corpus is still not live-provider evidence; it is a
repeatable target-shape gate that keeps the full conversation standard from
living only in prose.

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

## Scoring Contract

Machine scoring path:

- `AICoachChatService.coachVisionEvaluation(...)`
- `AICoachChatService.visionQualityIssue(...)` is the runtime gate for
  critical misses and clearly weak scores.
- `CoachTurnMetadata.qualityGateOutcome` records whether the final user-visible
  reply passed cleanly, was repaired, used a fallback, or failed, plus compact
  failure/repair counts. It stores gate labels only, never failed draft text.
- `CoachChatEvaluationCIReport` schema v4 now includes runtime-gate booleans
  for reference and known-bad replies, so CI artifacts expose the production
  gate decision in addition to raw vision scores.
- `CoachChatConversationEvaluationReport` schema v3 scores the 10 three-turn
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
  include the full three-turn transcript plus per-turn vision scores, so reviews
  can inspect the actual conversation rather than only a pass/fail summary.
- `CoachReplyPipeline` quality-gate aggregation is pinned for rejected-then-pass,
  rejected-then-repair, rejected-then-fallback, and final failure paths.
- Trust-repair turns now carry `CoachAssessment.toneMode = repair` and an
  optional `repairFocus`; soft pushback such as "Okay, that's cool. However..."
  routes to trust repair after a coach reply. Provider verbalisation and the
  semantic gate must name that repair focus before prescribing another drill.
- Turn metadata now persists `assessmentCacheHit`, `assessmentCacheAgeMs`,
  `immediateCoachReadShown`, `replyWordCount`, `providerTierChosen`, `providerAttemptCount`,
  `providerRefusalCount`, a real `providerRetryCount` derived from provider
  events rather than quality-gate failures, plus explicit
  `timeToFirstVisibleTokenMs` and `timeToCompleteReplyMs` aliases matching the
  research telemetry list for proving two-speed readiness, freshness, latency,
  routing, and reply-shape variation.
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
  complaints additionally set `coldnessComplaintFlag`, giving transcript audits
  a direct trust-loss signal instead of treating every pushback as identical.
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

Noum target: Use a 45-second recommendation prompt. Sentence one is the decision,
sentence two is one reason, then stop cleanly.

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

Noum target: Fair push: that read was too generic. The last rep gives enough
signal; next rep, use one clean opener and stop after the point lands.

User: What was generic about it?

Noum target: It was generic because it named a plan without naming the behavior.
The target is the opener: run a 45-second rep where sentence one lands before
the explanation starts.

User: Give me the short version.

Noum target: Short version: open with the point, add one reason, then stop. Run
that once and check whether sentence one lands before any setup.

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

Noum target: Fair push: the asterisks should never reach you or the voice. Your
last rep had 4 fillers, so state the recommendation first and stop after one
proof. No symbols, no report shape.

User: And stop saying "practice more."

Noum target: Agreed. The move is not more volume. It is a cleaner first
sentence: recommendation, one proof, stop.

User: What should I record?

Noum target: Record one 45-second answer to a recommendation prompt. If sentence
one is not the recommendation, restart.

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

Noum target: No. It moves warmth to the right place. Lead with the decision so
people know what you mean, then use warmth to make the decision easier to hear.

User: Give me the pattern.

Noum target: Recommendation. One reason. One reassurance. Then stop.

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
overall. Your last rep was 7/10 with 1 filler, so the mechanics are partly
landing, but goal readiness still needs repeated pressure evidence. Missing:
more than one clean rep under stakes. Proof test: record a 75-second answer with
the verdict in sentence one, one reason, and a clean stop.

User: Is 7/10 bad?

Noum target: No. It means the mechanics are not the bottleneck yet. The open
question is whether the same steadiness survives a more consequential prompt.

User: What would make you change the diagnosis?

Noum target: Two clean pressure reps with verdict-first openings. If those hold,
we move from mechanics to presence: less explaining, more settled commitment.

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

Noum target: The opening is serviceable enough. The close is where the authority
leaks because the answer ends as a summary instead of an ask.

User: What is the exact rep?

Noum target: 60 seconds. Same topic. Last sentence must be the ask. If it turns
into a recap, run it once more.

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

Noum target: I would not claim that from this sample. The observable issue is
order: the listener waits too long for the conclusion.

User: What test separates those?

Noum target: Run the same answer verdict-first. If it lands better with the same
voice and filler count, the issue was structure, not authority.

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

Noum target: Then use a placeholder ask: "I need alignment on the next step."
The training target is the shape of the close, not the final business content.

User: What should I check after?

Noum target: Check only the final ten seconds, because that is where the update
transfers into the room. If the last sentence asks for alignment or a decision,
keep it; if it recaps, rewrite the close.

Manual vision grade: 89/100.

Why it passes: bridges recent practice into tomorrow's real situation and gives
an action even when the exact business ask is unknown.

Remaining gap: could name the actual ask if known from BigMoment or ForwardPlan
context.

## Aggregate Read

Manual average across these target conversations: 87.1/100.

This is not a production score. It is a target-shape score. Production readiness
requires the live provider path to generate replies at this level, the machine
vision score to pass, and the transcript set to be reviewed against expert or
human-coach baselines.
