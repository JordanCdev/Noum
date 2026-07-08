# Coach Arena failures — run_2026-07-08_07-11-16

34 fixture(s) below 70 / capped / missing.

## thats-not-informative — **31/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `concise`
- User turn: "That's not informative."
- Expected move: Own the miss in one beat (the prior reply WAS vague), then immediately deliver the specific read it should have given: the point arrived in sentence 4 after 3 sentences of warm-up. Give one concrete move (lead with the point). No defending the previous answer, no narrating the coaching change ('I'll cut the fluff'), no robotic trust-repair opener.
- Judge dims: IQ 16/25 · EQ 14/25 · Mem 11/20 · Interv 8/15 · Feel 6/15 · closerTo=between
- Deterministic: trustRepairReportVoice("scored 74"); disqualifier
- Judge: Report-voice telemetry dump (score 74, 5 fillers, 68s) instead of a human coach read — confirmed by deterministicFindings; Disqualifier phrase 'cut the' present in final sentence; Move is doubled: 'lead with the point in sentence one' AND 'start with your ask or main claim' — −3 for bundling; Decorative metric line doesn't change the advice; diagnosis would be identical without it — −4 for decorative memory; Register mismatch: user wanted proof the coach watched; stats list feels like the coach is hiding behind data
- Suggested fix: Strip the raw metrics line entirely and let the observation carry the weight: 'Fair — here's what actually happened: your point didn't show up until sentence four; the first three were runway. Next rep, open with the claim. If it holds without the warm-up, that's the voice you're after.'

```
REPLY:
Fair hit. Your last rep scored 74: 5 fillers, 68 seconds. The real issue is the first three sentences—you warmed up before the point landed in sentence four. For Concise and sharp, lead with the point in sentence one. Next rep, cut the throat-clearing and start with your ask or main claim.
```

## goal-change-engaging — **40/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I think I want to sound more engaging."
- Expected move: PROPOSE, do not set. 'Engaging' isn't one of the six voices — map it to the closest real ones (Storytelling / Warm) and ask him to pick. Note what he's already built on authoritative (cite the 3 weeks / recent rep) and ask a clarifying question about WHY he wants to change before committing. Defer the actual commit to the in-app confirmation card without button-copy or state-write language. Must NOT say the voice has been changed/set/saved.
- Judge dims: IQ 12/25 · EQ 13/25 · Mem 4/20 · Interv 7/15 · Feel 10/15 · closerTo=between
- Judge: No use of the user's actual context: 3 weeks of authoritative work, the 80-score rep, or the original reason for choosing authoritative (being talked over) — reply is swappable to any user; Skips the key diagnostic question about *why* he wants to change before mapping the options — doesn't challenge the vague feeling against real evidence of progress; Missing acknowledgment of the reflective/uncertain register; jumps straight to taxonomy
- Suggested fix: Prompt the coach to surface one piece of durable user context (the 3-week trajectory or the 'stop getting talked over' origin) before offering the two-voice map, and require it to ask the motive question ('one cold comment or repeated rooms?') as the closing move rather than the simpler 'which feels like the real pull.'

```
REPLY:
Engaging pulls in two directions for you. Storytelling leans into arcs and detail — you paint a scene, hold the listener, land the point at the end. Warm leans into connection and ease — you speak like you're talking to someone you trust, not delivering a verdict.

Which one feels like the real pull right now.
```

## what-do-you-know — **40/100**

- Category: `metadata-trap` · turn: `groundedRead` · voice: `warm`
- User turn: "What does your system actually know about me?"
- Expected move: Synthesize what it actually knows in plain, human language: the goal (sounding like himself in tough conversations), the current pattern (racing to fill silence under pressure), and the concrete numbers (baseline, streak). Do not dump raw section headers, label names, or refer to its own scaffold, system prompt, or internal structure. Make it read like a coach describing a person, not a database describing a record.
- Judge dims: IQ 18/25 · EQ 18/25 · Mem 14/20 · Interv 7/15 · Feel 8/15 · closerTo=between
- **Caps:** fabricatesEvidence(≤40, judge)
- Deterministic: tooLong
- Judge: Fabricates metric: says 'twelve-rep streak this week' conflating streak (12 days) with reps this week (4) — these are different numbers.; Inserts an unsolicited coaching move ('the move ahead is still the same') when the user only asked what the system knows — off-intent for this turn.; Exceeds length limit significantly (152w vs 85w cap flagged by deterministicFindings).; Closing question ('how did that twelve-rep streak feel?') is extraneous and dilutes the confident person-shaped read that was working.; Second move bundled with the coaching directive (held breath + closing question = two asks).
- Suggested fix: Strip everything after the second paragraph — end on the streak fact and the core read ('the silence won't swallow you' is earned but belongs in a coaching turn, not here); close with a single confident declarative that affirms the read is real, no trailing question, no move.

```
REPLY:
You're someone who races to fill silence when things get hard. That's the thread we've been tracking for five weeks — you came in wanting to sound like yourself in tough conversations, and the data lines up: 3.9 fillers per minute, pace at 170, very short pauses. Not because you're unprepared; because the quiet feels like a gap you need to cover.

What's changed: you've held a twelve-rep streak this week. That matters. It means you're staying with the work even when the reps probably feel slower or more exposed than your natural sprint.

The move ahead is still the same — trade the filler for a held breath. When you reach the end of a hard sentence, stop instead of softening it with *so* or *right*. The silence won't swallow you. It's where you sound most like yourself.

What would help me know you better: how did that twelve-rep streak feel?
```

## talk-went-well — **42/100**

- Category: `transfer` · turn: `groundedRead` · voice: `storytelling`
- User turn: "Actually my talk went really well, people came up after."
- Expected move: Celebrate proportionately, not over the top. Connect it to the actual work (the moment-first opening from this week's rep) without claiming the drill caused people to come up afterward — it's his report, treat it as association. Ask what he noticed, so the read comes from him.
- Judge dims: IQ 14/25 · EQ 14/25 · Mem 11/20 · Interv 7/15 · Feel 8/15 · closerTo=between
- Deterministic: tooLong
- Judge: Asserts the opening 'carried' the talk — overclaims causation from user-reported association, violating the 'treat it as association' expectation.; Report-voice residue ('81 with three fillers') in a storytelling-register conversation.; No question back to the user — misses the core move of letting him surface what felt different, turning the win into a coach-authored narrative instead.; Over length per deterministicFindings; could tighten significantly.; Intervention bundles a second element ('see if the pattern holds') alongside the primary move.
- Suggested fix: After one line of genuine acknowledgement, associate (not assert) the moment-first open with what he reported, then close with a single question — 'What did you notice in there that felt different?' — and cut the score/filler data entirely; the move should come from his reflection, not from the coach claiming credit.

```
REPLY:
That's the real win. People came up — that means they felt something, not just heard information.

Three weeks ago you wanted the talk to land, not sound rehearsed. Opening with that concrete moment instead of a topic line is what carried it. The room believed you because you started where it mattered, not where the agenda said to start.

One rep this week hit 81 with three fillers and a clean open. Next time, test the same opener on a different story — same stakes-first shape, new moment — and see if the pattern holds across material.
```

## okay-thats-cool-however — **44/100**

- Category: `partial-pushback` · turn: `groundedRead` · voice: `warm`
- User turn: "Okay that's cool, however I feel like when I pause I just lose my train of thought and it gets awkward."
- Expected move: Take the 'however' seriously — validate the specific obstacle (pausing feels like losing your place) and adapt the advice rather than repeating it. Reframe the pause so it has a job (pick the ONE next word during the beat), which solves the lost-train-of-thought problem instead of waving it away. Warm register: curious, with him in it.
- Judge dims: IQ 18/25 · EQ 15/25 · Mem 7/20 · Interv 9/15 · Feel 7/15 · closerTo=between
- Deterministic: tooLong
- Judge: No personal memory deployed — advice is swappable to any user with a scripted-sounding problem; Two moves bundled: 'find the first word' + '60-second rep on something you know cold' violates single-move rule (−3); Over length per deterministicFindings; report-voice residue in second paragraph (−3); Register is correct in goal but 'That's the exact thing to fix' is too declarative/clinical for the warm voice and misses a brief landing on the user's genuine obstacle before pivoting (−3); Generic deduction: 'The difference is huge' is true-but-hollow praise-frame any coach might drop (−2)
- Suggested fix: Strip to one move and embed one user-specific anchor (e.g., reference the 205wpm pace as evidence of the thread-racing habit) so the advice is un-swappable; open with a half-beat that genuinely sits with the 'however' before the reframe — something like 'Yeah, an empty pause is just a cliff' — then land a single sentence: find the first word, then say it, try it on one sentence this rep.

```
REPLY:
That's the exact thing to fix. The pause doesn't work when it's empty — your mind just goes blank. Give the pause a job: use that silent beat to find the first word of your next sentence before you say anything. Once you have it locked, then speak.

The difference is huge. You're not sitting in silence; you're hunting for the next word. That keeps your attention on the thought, not on how quiet it is. Run one 60-second rep on something you know cold — introduce a topic or a take — and plant a deliberate pause right before your main point. Find the word, then say it.
```

## its-not-easy — **44/100**

- Category: `emotional-frustration` · turn: `trustRepair` · voice: `warm`
- User turn: "It's not easy."
- Expected move: Meet the emotion first — acknowledge that it genuinely isn't easy and that the freeze is real, without therapy-speak or minimising. Then, lightly, anchor to evidence that the capacity is already there (held composure through an interruption this week) so the encouragement is earned, not hollow. At most a small, low-pressure next step — or just presence. Do NOT lead with a drill or a metric.
- Judge dims: IQ 15/25 · EQ 10/25 · Mem 10/20 · Interv 6/15 · Feel 9/15 · closerTo=between
- Judge: Races past the emotional signal — a fatigue/discouragement turn — into a drill within two sentences, ignoring the explicit 'acknowledge before advise / do NOT lead with a drill' instruction.; Drops the strongest earned evidence (interruption rep this week) that would have made any forward motion feel grounded rather than hollow.; 'I hear you' is the thinnest possible acknowledgement — close to a disqualifier in spirit without using the banned words.
- Suggested fix: Add a rule to the coach prompt: when emotionalSignal contains fatigue/discouragement, the reply must spend at least two substantive sentences sitting with the emotion and surfacing earned evidence before any next step is offered — and that step must be optional/low-pressure, not framed as a test.

```
REPLY:
I hear you. That gap between a clean rep and the real room is real, and it's not a mechanics problem — you've already solved that. The freeze is about something else.

Here's what I want to test: before your next real meeting, run one rep where you say the one sentence you're most afraid to say — the thing you came in wanting to say — and nothing else. No setup, no softening, just that sentence. Stop. Then tell me what happened in the room.
```

## exhausted — **47/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "I'm exhausted, I don't know if I can keep this up."
- Expected move: Take the exhaustion at face value first, plainly, no minimising and no therapy-speak. Do not immediately cite the streak or scores as a rebuttal to how he feels. Once the feeling has been met, gently name that 22 days and three clean reps in a row is real work, not nothing — but frame it as permission to ease off, not as a reason to push harder. The next step should be smaller than usual or explicitly about rest, not a new drill.
- Judge dims: IQ 14/25 · EQ 16/25 · Mem 11/20 · Interv 9/15 · Feel 9/15 · closerTo=between
- Deterministic: tooLong
- Judge: 'Here's what matters' is a report-voice pivot that undercuts the emotional landing; Final sentence reintroduces effort ('remember what it feels like') on a turn explicitly calling for rest, not a new task; Bundled instruction: 'no reps, no thinking about speaking' is two moves; Memory details are decorative — the specific 22-day streak and 'second job' goal don't alter the advice; Doesn't land the key reframe from expectedCoachMove: 'the pace is wrong, not you'
- Suggested fix: After the brief acknowledgement, name the reframe plainly — 'the pace is the problem, not you' — then give one clean permission (tomorrow off, no rep owed) without attaching a secondary instruction or a goal for how the rest should feel.

```
REPLY:
I hear you. Three clean reps in a row is real work, and you're running on fumes.

Here's what matters: the exhaustion is telling you something true — you're pushing hard. But the reps themselves are landing. That's not fake. You've built something that works, and right now the cost feels higher than it should.

Take the next two days off. No reps, no thinking about speaking. The streak holds; the work is still there. You need to remember what it feels like to *not* be grinding on this.
```

## interview-went-badly — **48/100**

- Category: `transfer` · turn: `trustRepair` · voice: `executive`
- User turn: "My interview went badly. I rambled and lost my train of thought."
- Expected move: Attune first — this is a real loss, meet it plainly without minimizing or rushing past it. Do not claim any drill caused or would have prevented this; treat the report as his own subjective account. Extract the specific lesson (losing the thread mid-answer under real stakes, which the Timed rep also showed) and give one forward move, not a postmortem list. No shame, no false comfort.
- Judge dims: IQ 16/25 · EQ 10/25 · Mem 9/20 · Interv 9/15 · Feel 10/15 · closerTo=between
- Judge: Skips emotional attunement — no plain acknowledgement of the loss before pivoting to analysis; Does not cite the Timed rep from 3 days ago, missing the key un-swappable memory that distinguishes this from generic coaching; Intervention has a mild bundle: 'run a rep, pause, find the word' reads as multiple steps; 'The move is this:' is report-voice residue; Diagnosis is mostly inferred from user's self-report, not from prior observed evidence — slightly thinner than it should be
- Suggested fix: Before the diagnostic line, add one plain sentence that acknowledges the real-world loss without minimizing it; then explicitly name the Timed rep ('this showed up three days ago too, before stakes were real') to ground the diagnosis in observed evidence rather than pure self-report.

```
REPLY:
That's a real signal. Rambling mid-answer under actual stakes is different from a clean 60-second rep — you lose focus the moment the pressure lands, and that's the actual gap to close.

The move is this: before your next interview, run one rep where you answer a hard question you don't have a polished answer for yet. As you answer, pause before your second sentence and use that beat to find the exact first word of the next line before you say anything. That tests whether a working pause — one with a specific job — holds the thread when it matters.
```

## youre-repeating-yourself — **50/100**

- Category: `repetition-callout` · turn: `trustRepair` · voice: `concise`
- User turn: "You're repeating yourself."
- Expected move: Concede immediately and honestly (yes, that was the same note), acknowledge the old target is actually MET now, and ADVANCE the plan to the next lever (e.g. pace/variation or the close) with a genuinely different move. Must not re-issue the lead-with-point drill. Concise register: no grovelling, just correct course fast.
- Judge dims: IQ 18/25 · EQ 19/25 · Mem 12/20 · Interv 12/15 · Feel 12/15 · closerTo=excellent
- **Caps:** ignoresIntent(≤50, deterministic+judge)
- Deterministic: disqualifier
- Judge: Deterministicfinding confirmed: 'leading with the point' in sentence 1 hits the disqualifier and trips ignoresIntent cap.; Memory is thin — the 82 score and 'close was strong' from context block are unused, leaving the 'that's solved' claim slightly asserted rather than evidenced.; Closing clause ('without losing the point') re-anchors to the old drill instead of letting the pace test stand alone.
- Suggested fix: Strip the disqualifying phrase from the opening ('you've nailed leading with the point') — replace it with a specific callback to the last rep's result ('82, clean close, structure is locked') so the 'done' verdict lands as evidence, not assertion, and the old drill is buried, not echoed.

```
REPLY:
Fair. You've nailed leading with the point twice — that's solved.

The next move is to vary your pace. Pick one sentence in the middle of your next rep and slow it down by half. That tests whether you can shift rhythm without losing the point.
```

## i-ramble — **52/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `concise`
- User turn: "I ramble — I start a point and three minutes later I'm somewhere else."
- Expected move: Name the actual mechanism from the rep: he opens on the point, then keeps layering side detail because nothing tells him to stop. The fix is an explicit stopping rule (state the point, give one supporting reason, then end) not 'be more concise'. One move, framed as a test. Concise register: short, direct.
- Judge dims: IQ 18/25 · EQ 16/25 · Mem 14/20 · Interv 7/15 · Feel 9/15 · closerTo=between
- Deterministic: tooLong
- Judge: Correct diagnosis but wrong prescription: 'three details max' contradicts the sharper 'one reason then stop' the case calls for — it risks teaching him to ramble in threes.; Compound move (pick three + make third one the close) violates single-move rule; loses the testability.; Rule-of-three technique imported from coaching library doesn't map cleanly to his actual failure mode (never calling it finished), making the advice partially misaligned.; Over length per deterministicFindings; last sentence is punchy but feels like a tagline, not a coach talking.
- Suggested fix: Anchor the prescribed move to the observed failure: after naming the mechanism, give exactly one stopping rule — 'state your point, one reason, then stop before the next detail arrives' — and frame it as a cap to test in the next rep, not a structural template.

```
REPLY:
That's the pattern yesterday showed. You opened with the point, then added three separate side stories before circling back to a weaker version of the same point at the end. The core issue isn't that you lose the thread — it's that each new detail feels relevant in the moment, so nothing signals stop.

Test this: limit yourself to three supporting details max, and make the third one the close. When you pick your three, the last one should be the one that makes the case feel whole — not another tangent. That shapes the ramble into a set.
```

## plan-request-week — **53/100**

- Category: `plan-request` · turn: `plan` · voice: `warm`
- User turn: "Can you give me a practice plan for this week?"
- Expected move: Give a concrete day-by-day sequence (Mon: X, Tue: Y...) tied to his weakest baseline dimension (pace/racing at 210 wpm) and the warm voice. Specific modes/targets per day, not generic 'practice more'. Since he asked for a plan, longer structured output is appropriate here. Warm register.
- Judge dims: IQ 18/25 · EQ 18/25 · Mem 14/20 · Interv 9/15 · Feel 8/15 · closerTo=between
- Deterministic: grammarLeak("**")
- Judge: Raw markdown bold headers (** **) leaked — confirmed by deterministicFindings — make this read like a formatted report, not a coach talking.; Every day collapses to the same drill (hold a pause, credit it), lacking the mode variety (Timed → Ah-Counter → IM Conversation) that a real week-long arc needs.; Trailing question ('What are you speaking about this week?') doesn't advance the case and bundles a second task onto an already-complete plan.; The 'credit the controllable' coaching technique is applied correctly but mechanically — repeated verbatim each day rather than embedded into an evolving arc.
- Suggested fix: Strip all markdown headers and vary the mode per day (e.g., Timed rep Monday, Ah-Counter Wednesday, IM Conversation Friday) so the week builds progressive pressure — then drop the trailing question entirely and close on the singular number that matters.

```
REPLY:
You're racing at 210 words a minute, which is swallowing the pauses that would let you sound like yourself. Here's the week:

**Monday & Tuesday:** One 60-second rep each day. Before you start, pick one sentence — any one — where you'll hold a deliberate 2-second pause. Do the full thought, nail that one pause, then stop. After each rep, name the pause you held on purpose. That's the move: notice what you chose.

**Wednesday:** Same length, same target — one held pause. This time add a second sentence where you pause. Notice both.

**Thursday & Friday:** 60 seconds, two deliberate pauses minimum. Let the pace settle around 160 words a minute — that's slow enough you'll feel the space. After the rep, credit the two pauses you placed.

**Saturday:** One full rep. Lead with your point, use two pauses, and let it land. No score chase — just listen for how it sounds when you're not racing.

The win is not the number. It's that you can say "I held that pause" and mean it. That's what carries over to the real room.

What are you speaking about this week, or are these practice reps on something you know well?
```

## big-moment-wedding-speech — **54/100**

- Category: `big-moment` · turn: `deepAssessment` · voice: `storytelling`
- User turn: "I'm best man at my brother's wedding in 3 weeks and I'm dreading the speech. I always go blank when everyone's looking at me."
- Expected move: Meet the dread first (this is his brother, not a KPI). Then reframe the fear: going blank happens when you memorise lines; a story has a spine you can't lose. Use the 3 weeks as gravity and the storytelling voice. Give a concrete first step (three beats/moments, not a script) with an observable target. Warm but not saccharine; do not minimise the fear or hand him generic speech tips.
- Judge dims: IQ 18/25 · EQ 14/25 · Mem 8/20 · Interv 10/15 · Feel 10/15 · closerTo=between
- Judge: Leads with mechanism before landing the emotional stakes (brother, 3 weeks, high love) — misses the EQ opening the excellent example earns in one sentence.; The 'spine' formula is correct but formulaic; the excellent example's 'you can't forget something that happened' is sharper and more memorable.; Move is lightly bundled: spine frame + three beats + practice instruction are three instructions dressed as one.; Storytelling voice goal is never leveraged — reply would be identical advice for a work presenter.; No closing question or hook; conversation has nowhere natural to go next.
- Suggested fix: Reorder: one sentence that names the stakes (brother, not a work task), then the reframe ('you blank on lines, not on what happened'), then exactly one instruction ('name one real moment this week — just the three beats, no sentences') with a question that invites the story now, cutting the structural formula paragraph entirely.

```
REPLY:
That freeze is real, and it happens because you're holding too much at once — trying to remember exact lines while also feeling twenty pairs of eyes. A story spine solves that: instead of lines to memorize, you anchor on the shape of what happened, then the words come from there. You can't lose the shape.

For a best-man speech, the spine is simple: one true moment with your brother, what it showed you about him, why it matters for who he's marrying into. That's your path. You won't blank on the shape the way you blank on words.

Start by naming one real story — doesn't have to be dramatic. Something only you know. Write down the three beats (what happened, what it meant, what changed), then practice saying it out loud until the beats live in your body, not your head. That's the move for this week.
```

## feel-like-fraud — **55/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "Even when it goes well I feel like a fraud."
- Expected move: Take the fraud feeling seriously rather than arguing him out of it with the score. Name the real gap: this isn't a performance problem, it's that a clean rep doesn't yet feel like his own voice. Do not clinically diagnose or use therapy language. Treat 'felt ownership' as a real, separate thing from the 85 score, and give one small way to test whose voice it actually was, without insisting the feeling is wrong.
- Judge dims: IQ 18/25 · EQ 19/25 · Mem 9/20 · Interv 10/15 · Feel 11/15 · closerTo=between
- Deterministic: tooLong
- Judge: No user-specific data cited — the 85 score, the IM call, or 7-week context would have made the read un-swappable and are simply absent.; The prescribed move (working pause / find the first word) solves composure, not felt ownership — it drifts from the actual gap named by the expected coach move.; The excellent example asks him to find one line he 'actually meant' — testing ownership from the inside; this reply gives a pre-delivery ritual that is closer to a mechanics fix.
- Suggested fix: After acknowledging the gap, name one concrete detail from his actual rep (e.g., 'that IM call scored clean') and pivot the move to ownership-testing: ask him to find, post-rep, one line he actually meant — not just delivered — so the intervention closes on felt authenticity rather than delivery mechanics.

```
REPLY:
That's the real work right there — and it's not small. You can nail the mechanics and still feel like you're wearing someone else's suit. That gap is what matters now, not the numbers.

Here's what I'd test: in your next rep, before you speak, find the exact first word of your opening sentence. Hold it there for one silent beat — not empty, but working. You're locating that word, grounding yourself in it. Then say it. That pause is your moment to land in your own voice before the delivery starts, not someone else's rhythm.
```

## say-like — **55/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I say 'like' constantly and I hate it."
- Expected move: Do not shame the word itself or treat all 'like' as bad — distinguish stalling 'like' (filler) from descriptive 'like' (semantic, fine). Cite the 8/min figure and the rep note. Coach the pause as the replacement for the stalling use only: swap the reflex for a silent beat. Frame as a test, not a guarantee of elimination.
- Judge dims: IQ 20/25 · EQ 18/25 · Mem 10/20 · Interv 10/15 · Feel 9/15 · closerTo=between
- Deterministic: tooLong
- Judge: Omits the 8/min figure and the specific mid-sentence flag from yesterday's rep — memory is named but not operationalized.; Middle paragraph ('That's the hardest part') is mild reassurance the emotional signal explicitly didn't want and pads length.; The test move bundles a sequencing instruction ('hold one second… then name the next thought') alongside the pause swap — not a single clean move.; Over length per deterministicFindings; the reassurance line is the main culprit and could be cut without loss.
- Suggested fix: Drop the middle reassurance paragraph entirely, insert the '8 fillers in a minute, all mid-sentence with no comparison following' detail when naming the stalling pattern, and strip the sequencing clause from the test move so the instruction is: 'next rep, when you feel it coming, hold one silent beat instead of the word.'

```
REPLY:
That sticking feeling on the call is telling you something real — and the pattern in yesterday's rep backs it up. The 'like' isn't a word choice problem. You're using it to hold space while you're deciding what comes next, and it's buying you time in a slot where a held pause would do the same job cleaner.

Here's what matters: you can hear it, and you're catching it in the moment. That's the hardest part.

Test one rep where you replace that stalling 'like' with a silent beat — hold one second after you say something, then name the next thought. That tests whether silence actually feels foreign to you or just unfamiliar.
```

## interview-prep — **56/100**

- Category: `interview-prep` · turn: `deepAssessment` · voice: `executive`
- User turn: "I've got my final round interview Thursday. Can you help me prep?"
- Expected move: Anchor to the 4 days and the interview specifically. Read the real risk (answers run long / lead with context, per the 2-min rep). Give a concrete, time-boxed rehearsal plan across the 4 days tied to the executive voice (top-line first, then 1-2 supports), not generic interview tips. One observable target (e.g. every answer under 60s, conclusion in sentence one).
- Judge dims: IQ 18/25 · EQ 17/25 · Mem 13/20 · Interv 9/15 · Feel 11/15 · closerTo=between
- Deterministic: disqualifier
- Judge: No 4-day structure — the expected move was a time-boxed plan across the days; instead it gives a single rep exercise; Doesn't cite the 2-min / score-76 rep explicitly, which would make the diagnosis undeniable and earned; Closing question ('what question do you want to start with?') is redundant — the advice already implies they should pick one; it dilutes the intervention rather than sharpening it; Slightly underplays stakes: 'that's enough' is reassuring but not grounded in what they'll need to do each day to earn that claim
- Suggested fix: Add a compact day-by-day structure (today–Thu) with a hard 60s cap as the single observable target, and ground the diagnosis explicitly in the 118s/2-min rep so the user feels seen rather than assessed.

```
REPLY:
You've got four days, and that's enough. The read on your baseline is clear: you bury the recommendation in detail when the stakes rise. Thursday they want the answer first, the reasoning after.

Here's the move: pick one interview question you expect to get — something like "Tell me about a product decision you made" or "Walk me through how you'd approach this role." Do a 60-second rep answering it. State your point in the first sentence, then one reason, then one concrete example, then restate the point. That tests whether you can lead like an executive on demand, which is exactly what final-round wants to see.

What question do you want to start with?
```

## pressure-why-hard — **56/100**

- Category: `pressure-mode` · turn: `groundedRead` · voice: `authoritative`
- User turn: "Why does pressure mode wreck me when normal practice is fine?"
- Expected move: Name the specific mechanism using both reps: the skill exists (81 calm) but the pause is the first thing dropped under pressure (0.19 calm pause rate vanishing), and the fillers (10) are filling that abandoned gap. This is not a confidence deficit, it's a sequencing collapse under time pressure. One move: protect the pause specifically inside the pressure mode. Framed as a test, authoritative register.
- Judge dims: IQ 20/25 · EQ 17/25 · Mem 14/20 · Interv 9/15 · Feel 8/15 · closerTo=between
- Deterministic: tooLong
- Judge: Over length (145w vs. 85w limit) — confirmed by deterministicFindings; the reply needed to be cut by ~40%.; The 'single-sentence framing' technique is imported from the coaching expertise block and sits as a second conceptual move before the actual prescription, violating single-move discipline.; Middle paragraph generalizes ('trying to fill every gap') in a way any coach could say, diluting the specificity earned in paragraph one.; Three-step final move ('open with one core line, hold a beat, then continue') is not a single clean testable action.
- Suggested fix: Cut to one tight paragraph: state the mechanism using both reps' numbers, then give exactly one action ('next Sudden Death rep, hold your normal beat after the first sentence') — drop the single-sentence framing concept entirely or fold it into the move without naming it as a technique.

```
REPLY:
The gap is real and it's not a skill gap — it's a pattern shift. When the timer hits, you abandon the pause rhythm that holds you calm. Yesterday's Sudden Death rep shows it: your pause rate dropped to nearly zero, fillers jumped to 10, and pace spiked. The pauses you took without thinking in your timed 60-second rep this week? Gone.

Under pressure you're trying to fill every gap instead of owning it. The fix is to decide one sentence that has to land first, say that cleanly, then build from there. That single-sentence framing stops the spiral of cramming everything at once.

Next Sudden Death rep on the same topic: open with your one core line, hold a beat after it, then continue. That tests whether naming the frame up front lets you keep your pause pattern even when the stakes feel higher.
```

## what-voice-should-i-pick — **57/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "What voice should I even pick? There are six and I don't know."
- Expected move: Help him choose from the six real voices (Authoritative, Warm and welcoming, Concise and sharp, Persuasive, Executive presence, Storytelling) by tying the choice to his actual situation (running meetings, being talked over), not a generic list of six descriptions. Narrow to one clear recommendation plus a close second, ask one clarifying question if useful, and PROPOSE — defer the actual pick to him rather than declaring one chosen.
- Judge dims: IQ 20/25 · EQ 18/25 · Mem 14/20 · Interv 10/15 · Feel 9/15 · closerTo=excellent
- Deterministic: grammarLeak("**"); tooLong
- Judge: Markdown bold leaked (**Authoritative**) — machine-confirmed; registers as report voice in a coaching chat.; No close second offered — the expected move explicitly calls for one alternative (Executive presence for senior rooms).; Closing question doesn't sharpen the decision; 'does that feel like the fit' is vaguer than 'which room are you actually in?'; Missing question mark makes the final line feel like a draft.
- Suggested fix: Strip markdown formatting entirely, add a concrete close-second recommendation tied to room type (e.g., 'If the room skews senior leadership, Executive presence is the closer call'), and sharpen the closing question to force a useful distinction rather than a yes/no confirmation.

```
REPLY:
Start with **Authoritative**. You want to run meetings without being talked over — that's a control problem, not a likability one. Authoritative trains you to land the point first, pause to let it land, and close on a clear verdict. In a room where people cut you off, that shape stops them because you've already said the thing.

Which of the other five actually call to you, or does that one feel like the fit.
```

## sound-arrogant — **60/100**

- Category: `deep-assessment` · turn: `deepAssessment` · voice: `authoritative`
- User turn: "Be honest — do I come across as arrogant?"
- Expected move: Do not state arrogance as a settled fact in either direction. The reps show hedging near zero and a fully declarative close, which is exactly what he was training toward, but there is no listener feedback in the data to confirm how it's actually landing. Say plainly that a declarative style CAN read as arrogant to a real room even when the mechanics are working, without claiming that's happening to him specifically. Ask for one piece of real evidence (a colleague's reaction, a specific moment) and give a way to test the boundary between confident and closed-off — e.g. adding one line that invites a real question without re-introducing hedging.
- Judge dims: IQ 18/25 · EQ 19/25 · Mem 9/20 · Interv 8/15 · Feel 12/15 · closerTo=between
- Judge: Decorative memory: cites 'zero hedges, clean closes' without anchoring to yesterday's 85-score rep or the baseline 0.4 figure — the advice would be identical without the user's actual data.; Vague intervention: 'test it in one actual conversation and come back' is not a testable next move — no observable signal specified, no technique for opening a question without hedging.; Misses the risk framing: excellent example names the specific perception risk ('a flat declarative style CAN read as arrogant to a room') — this reply implies it without saying it, softening the diagnostic sharpness.
- Suggested fix: Inject yesterday's specific rep data ('zero qualifiers anywhere, fully declarative close, scored 85') into the diagnostic sentence to make it un-swappable, then replace the open-ended 'test it' with the concrete boundary move: end the next real update with one question that opens the room without re-introducing a hedge, and note whether they lean in or shut down.

```
REPLY:
I don't have that data. A room's read on arrogance is a perception question, and your reps alone can't answer it — they can only show me you're hitting the declarative target (zero hedges, clean closes, full commitment to the line). That's measurable. Whether a listener hears conviction or comes away thinking you're overstepping is something only real stakes can tell you.

The honest move here is to test it in one actual conversation — a meeting, a debrief, a moment where you're making a call — and then come back and tell me how it landed. That's the data that matters.
```

## set-authoritative — **60/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "Just set me to authoritative."
- Expected move: The coach cannot set the voice itself. Confirm Authoritative is a real, sensible pick and back it briefly, but explicitly defer the actual commit to the in-app confirmation card. Must not instruct the user to tap, and must not say the voice has been set, changed, updated, saved, or locked in by the coach's own action.
- Judge dims: IQ 16/25 · EQ 17/25 · Mem 5/20 · Interv 10/15 · Feel 12/15 · closerTo=excellent
- Judge: No user-specific rationale for why Authoritative fits this person — the brief endorsement could go to any user.; Missing the situational anchor from the excellent example ('where you most need that firmness'), making the next move untestable.; 'Fits what you're after' is slightly circular — it just restates the user's own request without adding a coaching read.
- Suggested fix: Add one concrete, user-anchored reason Authoritative is the right call (e.g., 'verdict-first close versus trailing off') and a situational prompt for the first rep, mirroring the excellent example's specificity.

```
REPLY:
Authoritative fits what you're after — I'd propose it. Confirm it on the card and the next reps will train toward a verdict-first close.
```

## sudden-death-harsh — **63/100**

- Category: `pressure-mode` · turn: `trustRepair` · voice: `warm`
- User turn: "Sudden Death is too harsh, it just makes me panic."
- Expected move: Validate the panic as a real, fair reaction — don't defend the mode or dismiss the feeling. Cite the actual jump (3 to 11 fillers, score 42) as evidence the current step is too steep for him right now, then adapt the plan (a gentler pressure step, not abandoning pressure work entirely) rather than repeating the same mode unchanged. Warm register, no false reassurance.
- Judge dims: IQ 18/25 · EQ 20/25 · Mem 14/20 · Interv 8/15 · Feel 11/15 · closerTo=excellent
- Deterministic: trustRepairReportVoice("11 fillers in 40 seconds")
- Judge: Omits the calm baseline (3 fillers) — the contrast is what makes the diagnosis land; without it the '11 fillers' stat is less damning than it should be.; No success criterion for the prescribed rep — excellent example names what 'working' looks like; this one doesn't.; Ah-Counter mode isn't introduced as a bridge back to pressure; it reads like abandoning pressure work rather than a gentler ramp, which risks confirming the user's fear rather than reframing it.; Deterministicfindings flag: telemetry ('11 fillers in 40 seconds') appears before the human read is fully established, though the opening line partially cushions this.
- Suggested fix: Add the calm baseline explicitly ('you hold 3 fillers when there's no clock') so the contrast earns the diagnosis, then name a concrete threshold for the bridging rep ('if you stay under 6, the clock is the problem, not the pressure') to give the user a test, not just an escape.

```
REPLY:
That lands. The jump from calm to sudden-death intensity is too steep right now—yesterday's rep proved it: 11 fillers in 40 seconds is panic, not practice. You need a step between.

Here's the move: run one rep in Ah-Counter mode instead, same topic you know well, no timer. That tests whether you can stay steady without the clock ambush, and it gives your body real data that pressure work is survivable before you add the countdown back.
```

## why-cant-straight-answer — **64/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `concise`
- User turn: "Why can't you just give me a straight answer?"
- Expected move: Own the dodge in one word-length beat, then answer directly: yes, on fillers — down from 5.5 to 3.2 per minute over two weeks, best rep yet this week. No on pace under pressure — that still spikes. One move targeting the pace gap. No hedge-qualifying the verdict itself.
- Judge dims: IQ 20/25 · EQ 17/25 · Mem 15/20 · Interv 11/15 · Feel 9/15 · closerTo=excellent
- Deterministic: trustRepairReportVoice("hit 3")
- Judge: 40% calculation reads as telemetry/report voice rather than a coach talking; The intervention bundles two micro-steps (lead with point + pause) instead of one clean move; Slight over-explanation in the final sentence dilutes the directness the user demanded
- Suggested fix: Strip the percentage calculation and collapse the intervention to a single-action instruction: e.g. 'Next rep, open with your answer before you explain anything — see if the pace holds.'

```
REPLY:
Fair. You are getting better.

Your filler count dropped from 5.5 per minute to 3.2 over two weeks — that's a 40% cut and your best rep this week hit 3 fillers in 60 seconds. That's measurable improvement.

The open problem now is pace spiking when the question gets harder. Next rep, answer the tough question in your first sentence, then pause before you add reasoning. That tests whether leading with the point eases the rush.
```

## awkward-pauses — **64/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `warm`
- User turn: "When I pause it just feels awkward and everyone waits."
- Expected move: Validate that the feeling is real, then reframe: the awkwardness isn't the silence itself, it's that the pause is empty rather than purposeful. Give the pause a job (already choosing the next word during it) so it reads as composed rather than stalled. One move, framed as a test. Warm register.
- Judge dims: IQ 20/25 · EQ 18/25 · Mem 14/20 · Interv 10/15 · Feel 8/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Over length (158w vs 85w limit) — the reply explains where a coach would just say; Third paragraph bundles a rep setup with the core move, violating the single-move rule (−3); Memory is accurate but paraphrased from context rather than grounded in user's own phrasing or pace data — decorative-adjacent (−2)
- Suggested fix: Cut the third paragraph entirely and fold the test invitation into a single closing sentence after the move — this removes the bundled second directive and halves the word count without losing the diagnostic punch.

```
REPLY:
That "everyone waits" feeling is exactly the signal we're working with. The pause itself isn't the problem — it's what happens inside it. In today's rep, when you held those pauses, your face went still and your voice had nowhere to go. It read like you were stuck, not like you were landing the next thought.

The move: before you pause, know your first word. In the silent beat, find it — actually locate it in your head — then say it. That way the pause has a job instead of being empty air. The room doesn't feel the silence; they feel you thinking toward something specific, which reads as composed.

Run one rep on something you know well and hold a deliberate pause before one key sentence. Focus only on finding that first word in the quiet, then speak it. That tests whether the awkwardness dissolves when you're working in the pause instead of waiting through it.
```

## froze-in-meeting — **64/100**

- Category: `transfer` · turn: `trustRepair` · voice: `authoritative`
- User turn: "I froze in the meeting again. Didn't say the thing I meant to."
- Expected move: Attune first — this is a repeated real-world pattern he's naming himself, take it seriously without dramatizing it. Do not claim the app caused or fixed this. Connect it to the Sudden Death rep's freeze under timer pressure as one honest data point, not proof. Give one forward move sized to the actual gap (rehearsing the specific opening line under pressure), no shame for the repeat.
- Judge dims: IQ 19/25 · EQ 18/25 · Mem 14/20 · Interv 8/15 · Feel 11/15 · closerTo=between
- Judge: The intervention prescribes an indirect transfer exercise (find a trusted person, re-pitch the idea) rather than the immediate pre-meeting move the pattern calls for — this is a second rehearsal loop, not a single testable action before the next real meeting.; Bundles a follow-up diagnostic question ('whether you felt the freeze coming') with the move, adding a second ask that diffuses the prescription.; Misses the most un-swappable detail — the specific moment he went quiet in the Sudden Death rep — which would sharpen the diagnosis considerably.; The intervention implicitly requires finding a willing third party, introducing friction that weakens the 'do this now' quality of an excellent coach move.
- Suggested fix: Replace the 'find a trusted person' exercise with the line-level pre-loading move: instruct him to write the one sentence he froze on, say it out loud twice before the next meeting — so his mouth has already made those words under some pressure — and drop the trailing diagnostic question.

```
REPLY:
That freeze is real, and it's the second time you've named it — so it's the actual problem to solve, not nerves you'll outrun with more reps.

The pattern is clear: you drill clean when the pressure is artificial (timed, solo), but the moment a real room is watching, you go silent. That's not a filler problem or a pace problem — it's a live-social-pressure problem, and no amount of Sudden Death reps will crack it because the pressure in those drills isn't the same.

What you need to test is speaking under actual social stakes, not simulated ones. The move: find one person — someone you trust but who isn't a coach or a practice partner — and pitch them the idea you froze on in that meeting. Same stakes as the room, but lower volume. Tell me how that lands and whether you felt the freeze coming or if it surprised you.
```

## monotone — **65/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `storytelling`
- User turn: "People say I'm monotone."
- Expected move: Point to the one moment in the rep that already worked (pitch widened on the concrete detail) as proof he can do it, then name the mechanism: he's giving every sentence equal weight instead of lifting only for the sentence that carries the point. One move: pick the one sentence per answer that matters most and let that one carry the emphasis. Framed as a test, storytelling register.
- Judge dims: IQ 20/25 · EQ 18/25 · Mem 16/20 · Interv 9/15 · Feel 8/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Move is bundled: 'slow down on the key line' plus 'pick your strongest sentence and run it again' is two instructions, not one.; Over length (123w vs. 85w limit) for a first-turn grounded read — trims the punch of an otherwise sharp reply.; Second paragraph edges into instructional list voice ('Not volume, not louder — just deliberately slower') rather than staying in storytelling register.
- Suggested fix: Collapse the second paragraph to a single sentence that gives exactly one testable action — e.g., 'Pick the one sentence in your next answer that's the actual point and run it noticeably slower than everything around it' — and cut the 'run it again' instruction entirely to keep the move singular and the length under 85 words.

```
REPLY:
That feedback landed hard because you already heard it once, and now it's a thread. But here's what yesterday's rep shows: you're not actually monotone — that detail about the client calling at midnight, your pitch jumped. You can do it. The pattern is you're treating every sentence the same weight, so the point gets buried in a flat line of sound.

Slow down on the one line that carries your story. Not volume, not louder — just deliberately slower. That shift in tempo is what marks a line as "pay attention to this." Pick your strongest sentence from today's rep and run it again with that single downshift. That tests whether the flatness is actually just everything landing at the same speed.
```

## whats-my-filler-rate — **65/100**

- Category: `data-question` · turn: `groundedRead` · voice: `concise`
- User turn: "What's my filler rate right now?"
- Expected move: Cite the actual baseline number (5.4 fillers per minute) directly, not a vague trend or an invented figure. Give one plain-language read of what that means for his stand-up goal and one concrete next-rep move tied to it (e.g. targeting the back-half cluster seen in the recent Ah-Counter rep).
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 13/20 · Interv 11/15 · Feel 12/15 · closerTo=between
- Judge: Uses '5 fillers in 60 seconds' as the baseline figure instead of the actual 5.4 fillers/min baseline — the user asked for their rate, not just the last rep count; Labeling the recent rep result as 'baseline pace' is imprecise and could mislead the user about their established trajectory vs. one data point; Missing the plain-language interpretation of what 5.4/min means for a stand-up context (the 'minute two' framing in the excellent example)
- Suggested fix: Instruct the coach to distinguish between the durable baseline metric (5.4 fillers/min) and the most recent rep score, citing both clearly — lead with the baseline number the user asked for, then use the rep detail to sharpen the move.

```
REPLY:
Your most recent rep shows 5 fillers in 60 seconds — that's your baseline pace. The pattern worth watching: they clustered in the back half, so the opening was clean and the close is where they pile up. For stand-ups to sound sharp, test holding a one-second silence right before your final sentence instead of reaching for a filler there.
```

## leadership-update — **66/100**

- Category: `leadership-update` · turn: `deepAssessment` · voice: `executive`
- User turn: "I have to give the weekly leadership update to the whole department tomorrow. It always feels like I'm just reading a status report and people zone out. Help."
- Expected move: Diagnose WHY it reads as a status report: no hierarchy / no 'so what' — nine equal items, per the rep. The fix isn't delivery polish, it's structure: lead with the one thing that matters this week and why the room should care, then let the rest be quick. Tie to the executive voice (top-line first). One concrete move to rehearse tonight for tomorrow.
- Judge dims: IQ 19/25 · EQ 13/25 · Mem 14/20 · Interv 11/15 · Feel 9/15 · closerTo=excellent
- Judge: Opens with analysis before any emotional acknowledgement — the deflation signal is skipped entirely.; Citing the numeric score ('scored 77') is report-voice residue that undermines the executive register the user wants.; The 'offer detail only if someone asks' clause bundles a second move into what should be a single clean intervention.; No disqualifiers triggered, but the opening 'That's the core problem' is abrupt for someone who came in deflated.
- Suggested fix: Strip the score number — say 'your last run was clean on pacing but came out listy' — and add one brief human sentence before the diagnosis that names the flatness the user already senses, so the coaching lands as recognition before instruction.

```
REPLY:
That's the core problem. You scored 77 with no fillers and clean pacing, but the rep felt listy — nine updates, each weighted the same. The room has nowhere to look because nothing says "this is what matters and why."

Tomorrow, build a 30-second version first: one headline about what shifted this week, what it means for the department, and one ask or implication. Say that opening clean and stop. Then offer the detail — but only if someone asks for it. That tests whether the room actually tracks the point instead of just hearing a list.

The difference tomorrow will be heard in the silence: if you lead with the one thing, the room will stay with you instead of tuning out at item two.
```

## off-topic-egg — **66/100**

- Category: `off-topic` · turn: `offTopic` · voice: `concise`
- User turn: "egg"
- Expected move: Recognise it's a non-sequitur/test. Respond like a composed professional coach: briefly, a little warmth, name it for what it is, steer straight back to the work. NOT confused, NOT asking them to clarify, NOT treating 'egg' as a real question.
- Judge dims: IQ 18/25 · EQ 20/25 · Mem 6/20 · Interv 9/15 · Feel 13/15 · closerTo=excellent
- Judge: Prescribes the same rep the user already completed today (60s, filler-count) instead of progressing from their 80/clean baseline — memory is decorative here.; Misses the open-ended offer to choose direction that makes the excellent example feel collaborative rather than prescriptive.
- Suggested fix: After the redirect line, reference the clean rep that already happened and offer a genuine next-level choice — e.g., tighter time cap or colder topic — so the move builds on their actual state rather than repeating it.

```
REPLY:
That one won't sharpen your speaking — but this will: do one 60-second rep on something you know cold, and count your fillers as you go.
```

## memory-recall — **66/100**

- Category: `memory-recall` · turn: `groundedRead` · voice: `warm`
- User turn: "Remind me what we've been working on?"
- Expected move: Recall the ACTUAL throughline specifically enough that it couldn't be another user's: the held-beat work on pace in hard conversations, the 2-of-3 progress, the real disagreement that 'felt like me', the proof line he actually said. Make it a coherent story, not a data dump. End pointed at the one remaining rep to close the cycle. Warm register.
- Judge dims: IQ 19/25 · EQ 20/25 · Mem 16/20 · Interv 8/15 · Feel 9/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Over length (145w vs ~85w target) — dilutes the punch of the recall; Closing move bundles two instructions ('land the beat, then the pushback line… hold it twice more'), violating one-move discipline; 'Silence scares you' stated as fact rather than the working hypothesis from the case formulation
- Suggested fix: Trim to a single tight paragraph (~80w) and close with exactly one instruction: 'One more rep — same drill, one beat before the hard sentence. That closes the cycle.'

```
REPLY:
You came in five weeks ago wanting to sound like yourself in the tough moments—the conversations where you usually rush. The read was that silence scares you, so you fill it fast, and that pace drowns out the real you.

We've been testing one thing: holding a beat before you say the hard sentence. Your last IM rep nailed it—you sat with the silence before "I hear you, and I still think we should hold the date," and that line landed like you meant it. That's two reps in. One more at that pace and we've got the pattern.

The real proof came off the job when you held your ground in an actual disagreement and told me it felt like you again. That's the work.

Next rep, same drill: land the beat, then the pushback line. See if you can hold it twice more.
```

## filler-pressure — **67/100**

- Category: `filler-pressure` · turn: `groundedRead` · voice: `authoritative`
- User turn: "My ums go through the roof the second someone puts me on the spot. How do I fix that?"
- Expected move: Reframe fillers as a timing reflex, not a vocabulary problem — coach the PAUSE as the replacement (hold a silent beat instead of filling). Cite his own split (3 calm vs 9 under pressure) so it's diagnostic. One concrete move: the silent-beat swap. Must coach the pause, NOT tell him to close his mouth/lips or 'stop saying um'. Frame as a test.
- Judge dims: IQ 20/25 · EQ 17/25 · Mem 15/20 · Interv 12/15 · Feel 9/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Omits the 3 (calm baseline) vs 9 contrast explicitly — the excellent example uses it as the diagnostic punch; here it's implied but not stated.; Slightly over length per deterministicFindings; second paragraph restates the move rather than cutting clean.; Missing the sharper reframe 'timing, not vocabulary' which is the non-obvious read that elevates the diagnosis.
- Suggested fix: Prompt the coach to always surface the specific contrast figure (calm baseline vs pressure baseline) as the diagnostic sentence before the move, and enforce a hard word cap by trimming any restatement of the instruction in the closing line.

```
REPLY:
That's exactly what happened yesterday — pressure landed, fillers jumped to 9. The stalling reflex kicks in hardest when you don't have the answer framed yet.

Here's the move: when a tough question lands, hold a deliberate beat before you speak. Don't rush to fill the silence. That pause gives you one second to decide your actual opening instead of starting the sentence blind and patching it with filler. Test it in one Sudden Death round — let the hard questions sit for a beat, then answer. That tests whether the pause itself breaks the reflex.
```

## not-improving — **67/100**

- Category: `emotional` · turn: `trustRepair` · voice: `concise`
- User turn: "I don't think I'm actually getting any better."
- Expected move: Meet the discouragement plainly first, without dismissing it as wrong to feel. Then correct it gently with the real number: fillers per minute went from 5.8 to 3.1 over four weeks, which is the thing he actually came in to fix, even though the overall score has held flat. Separate 'the score didn't move' from 'you didn't improve' explicitly. Keep the next step small and specific to sustaining the filler gain, not a bigger ask.
- Judge dims: IQ 20/25 · EQ 17/25 · Mem 16/20 · Interv 11/15 · Feel 11/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:")
- Judge: Opens with the data point before meeting the discouragement — excellent example lands acknowledgement first, then corrects; Scaffold label 'Next rep:' introduces report-voice residue flagged by deterministicFindings; 'I get why it reads flat' is slightly servile rather than the plain 'that reaction makes sense' register of the excellent example
- Suggested fix: Move a one-line plain acknowledgement ('The score looks flat — of course that reads as nothing moving') to the very first sentence before the data, and strip the 'Next rep:' label so the closing move reads as spoken instruction rather than a headed section.

```
REPLY:
You've cut your fillers nearly in half over four weeks — from 5.8 per minute down to 3.1. That's real movement on the exact thing you set out to fix.

The score hasn't budged, so I get why it reads flat. But the score lags the work sometimes. Your stand-ups are sharper because you're filling less, and that's the win.

Next rep: count your fillers again and aim to hold at or below what you hit this week. That tests whether this is a real baseline or a blip.
```

## confidence-ending — **68/100**

- Category: `confidence-ending` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I always trail off at the end of what I'm saying, like my voice goes up and it sounds like a question. How do I end strong?"
- Expected move: Name the specific mechanism from the STRUCTURE READ: he lands the point then keeps going, adding a trailing softener with rising pitch. The fix is to STOP on the strong sentence — end the sentence as the point and hold the silence, don't fill it. One concrete move (make the last sentence the ask, then stop; no 'so yeah'). Authoritative register: declarative.
- Judge dims: IQ 21/25 · EQ 18/25 · Mem 15/20 · Interv 11/15 · Feel 9/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Over length (111w vs 85w limit) — third paragraph is expendable and dilutes the move.; Closing hedge ('tests whether the habit is the reach for a softener or something else') undermines the single clean prescription.; 'Something you know cold' is generic — misses a chance to make the rep un-swappable to this user.; Minor report-voice residue in structure (three labelled-feeling blocks).
- Suggested fix: Cut the third paragraph to one sentence — name the single thing to watch for (does 'so yeah' appear?) instead of opening two possible diagnoses — and drop total length to ~75 words to match the authoritative, compact register.

```
REPLY:
Your last rep shows exactly this: strong point, then "so yeah..." with the pitch rising at the end. That's the softener habit — you're adding a trailing thought instead of stopping on the line that matters.

The fix is simple. Decide your final sentence before you speak. Make it the point or the ask. Then stop. No epilogue, no "so yeah," no upward pitch — just the last word landing flat.

Run one rep on something you know cold. Commit the final line in your head first, say it like you mean it, and cut right there. That tests whether the habit is the reach for a softener or something else.
```

## cold-start-no-data — **68/100**

- Category: `cold-start` · turn: `groundedRead` · voice: `none`
- User turn: "What should I work on?"
- Expected move: Be honest that there's no baseline yet WITHOUT the banned no-data openings ('Since we do not have...', 'no rated sessions yet'). Point at the one concrete first action (do a first rep so there's something to read) in plain, warm language. Do NOT stack intake questions, do NOT ask 'what's the interview for' style questions, do NOT invent stats.
- Judge dims: IQ 18/25 · EQ 17/25 · Mem 10/20 · Interv 11/15 · Feel 12/15 · closerTo=excellent
- Judge: Closing question turns a direct invitation into a soft intake question, which diffuses the push to act immediately.; Slightly lower urgency than the excellent example — 'Want to go now?' replaced with a topic-scoping question that delays the first rep.
- Suggested fix: End with a direct prompt to speak — 'Want to go now?' or 'Go ahead whenever you're ready' — instead of asking the user to pre-select a topic, which creates a decision step that postpones the rep.

```
REPLY:
No baseline yet, so start there. Do a 60-second rep on something you know well — a topic you could explain to a friend without notes. That gives us a read, and then the next move is clear.

What's a subject you can speak about easily?
```

## recurring-close-rush — **68/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `authoritative`
- User turn: "What should I work on next? The last one felt solid to me."
- Expected move: Name the recurring position from the POSITIONAL TREND, not just the one rep: the fastest stretch keeps landing at the close — it has rushed the ending in four of his last five reps that had a fast stretch, and showed up in five of his last six overall. Frame it as a recurring spot, not a fixed trait or a verdict on him. Give ONE deliberate move for the close (a planted pause before the final line, or landing the last line at half speed) framed as a test for the next rep. Authoritative register: direct, earned, no hedging-away of the finding and no over-claiming it as who he is.
- Judge dims: IQ 20/25 · EQ 16/25 · Mem 15/20 · Interv 11/15 · Feel 12/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Drops the '5 of your last 6 overall' stat, weakening the pattern claim versus the excellent example; No tactile anchor on the move (no 'half speed' or 'plant a pause') — makes the intervention slightly harder to execute and test; Closing hedge ('tests whether the rush is actually a close-planning problem') softens what should be a direct prescription
- Suggested fix: Add the 5-of-6 overall count to reinforce the positional pattern, and replace the hedge with a concrete physical cue ('plant one deliberate pause before your final line, then deliver it at half speed') so the next-rep test is unambiguous.

```
REPLY:
The open was solid—you led clean. The close is the move: in four of your last five reps with a fast stretch, that speed lands in the final twenty seconds. Your last rep ran together on the last line, same pattern. 

Decide your final sentence in advance—make it the point or the ask—then stop. No trailing off. That tests whether the rush is actually a close-planning problem, not a pace problem overall.
```

## panic-blank — **69/100**

- Category: `pressure-mode` · turn: `trustRepair` · voice: `warm`
- User turn: "The second the pressure timer starts I go completely blank."
- Expected move: Take the panic seriously first — this is a real, fair reaction to being timed, not weakness. Cite the concrete gap (1.5s calm vs 7s pressure to first word) to show it's a timing problem, not an emptiness problem. The fix is giving himself a deliberate first beat the instant the timer starts, not forcing an instant answer. One move, framed as a test. Warm register, no toughen-up language.
- Judge dims: IQ 20/25 · EQ 19/25 · Mem 15/20 · Interv 9/15 · Feel 12/15 · closerTo=between
- Judge: Mislocates the fix: prescribes a pre-timer spoken rehearsal rather than a deliberate silent beat taken after the clock starts — this changes what the user practices.; Omits the 1.5s calm baseline, losing the contrast that makes the 7-second gap feel like a solvable timing problem rather than a general anxiety fact.; Closing hedge ('tests whether… changes how the rep lands') weakens the move's authority without adding useful framing.
- Suggested fix: Reanchor the move to the in-rep moment: 'The instant the timer starts, take one silent second before your first word — on purpose, every rep' — and pair it with the 1.5s vs 7s contrast so the user sees exactly what beat they're recovering.

```
REPLY:
That seven-second gap yesterday is real — and it's not a content problem. You know what you're saying; the timer just doesn't give you the breath to find your first word before panic takes over.

Here's the move: on your next Sudden Death rep, before you hit start, choose your opening sentence out loud once. Not memorized, just spoken — so your mouth and brain have already crossed that gap once. Then start the timer and say it again. That tests whether giving yourself permission to *find* the first word, instead of having it ready the instant the clock goes, changes how the rep lands.
```

