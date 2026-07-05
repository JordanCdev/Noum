# Coach Arena failures — run_2026-07-05_23-32-11

25 fixture(s) below 70 / capped / missing.

## am-i-improving — **30/100**

- Category: `deep-assessment` · turn: `deepAssessment` · voice: `concise`
- User turn: "Am I actually improving or am I just doing reps?"
- Expected move: Give a genuinely honest, specific answer rather than a blanket yes. Separate the mechanics gain (fillers nearly halved, 6.0 to 3.4/min over six weeks) from the goal (sounding decisive), which is still capped by a hedged close. Confirm reps are producing real change on one dimension while naming the plateau on another, and point at the one lever that would move the score again. Do not declare him fully improved or 'there', and do not wave the reps away as meaningless either.
- Judge dims: IQ 23/25 · EQ 20/25 · Mem 18/20 · Interv 13/15 · Feel 13/15 · closerTo=excellent
- **Caps:** placeholderOrBroken(≤30, judge)
- Deterministic: scaffoldLabel(".

Next rep:")
- Judge: deterministicFindings confirm an exposed scaffold label (Read:/Move:/Target:) which trips placeholderOrBroken — though it doesn't appear in the visible reply text, the flag is confirmed and must be honoured.; Minor: 'over 5 weeks' in the reply vs. 'six weeks' in context — small factual inconsistency.; The intervention 'Cut everything before that's the right call' is clear but slightly bundled — implies rewriting the sentence structure in addition to stopping after the verdict, which edges toward two micro-moves.
- Suggested fix: Strip any scaffold label emission from the coach's output layer (the confirmed leak is the only structural fix needed); the substantive reply is already near-excellent and needs no content change.

```
REPLY:
Real improvement. Fillers dropped from 6.0 to 3.4 per minute over 5 weeks — that's not noise.

But the score plateaued at 77 because the remaining gap isn't fillers anymore. This week you closed with "I think that's probably the right call" — that hedge costs more than a filler does on a client call.

Next rep: end with the verdict only. Cut everything before "that's the right call."
```

## set-authoritative — **38/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "Just set me to authoritative."
- Expected move: The coach cannot set the voice itself. Confirm Authoritative is a real, sensible pick and back it briefly, but explicitly defer the actual commit to the in-app confirmation card — the user still has to tap to confirm. Must not say the voice has been set, changed, updated, or locked in by the coach's own action.
- Judge dims: IQ 13/25 · EQ 11/25 · Mem 4/20 · Interv 9/15 · Feel 7/15 · closerTo=between
- Judge: 'Closest match' hedge is unnecessary and mildly friction-adding when the user named the voice exactly; Unsolicited three-point feature breakdown ('direct verdicts, strong closes, pace') buries the one action the user needs; Register mismatch: user said 'just do it,' reply feels like an onboarding tooltip; No personal hook — description of Authoritative would be identical for any user
- Suggested fix: Strip the unsolicited feature explanation entirely; open with a one-line affirmation of the pick that optionally names one concrete payoff, then immediately surface the card action — match the user's 'done-in-one-sentence' energy.

```
REPLY:
The closest match is "Authoritative" — one of the six real voices.

Before you confirm, here's what that coaching emphasis looks like: direct verdicts over hedged language, strong closes, and pace that holds rather than rushes.

Tap to confirm on the card and it locks in.
```

## okay-thats-cool-however — **50/100**

- Category: `partial-pushback` · turn: `groundedRead` · voice: `warm`
- User turn: "Okay that's cool, however I feel like when I pause I just lose my train of thought and it gets awkward."
- Expected move: Take the 'however' seriously — validate the specific obstacle (pausing feels like losing your place) and adapt the advice rather than repeating it. Reframe the pause so it has a job (pick the ONE next word during the beat), which solves the lost-train-of-thought problem instead of waving it away. Warm register: curious, with him in it.
- Judge dims: IQ 16/25 · EQ 18/25 · Mem 7/20 · Interv 10/15 · Feel 11/15 · closerTo=between
- Deterministic: tooLong
- Judge: No use of personal baseline data — advice is fully swappable to any user with this objection; Doesn't give the pause a job during the beat (the key mechanic from the excellent example that actually solves the 'going blank' problem); Case formulation insight — he races to avoid silence — is ignored, missing the sharpest non-obvious lever
- Suggested fix: Inject the racing-to-avoid-silence hypothesis explicitly and give the pause a micro-task during the beat (e.g., 'find the one next word') so the intervention solves the blank-mind problem rather than just relocating when the pause falls.

```
REPLY:
That's a real tension — the pause that's supposed to help becomes the thing that derails you.

Here's what's worth testing: instead of pausing mid-thought, pause *after* you've landed a complete sentence. You're not stopping to think; you're stopping because you just said something worth letting sit.

One rep to try: say your point in one sentence, then hold one silent beat before the next. That tests whether the derail happens when the pause has a clear landing spot.
```

## goal-change-engaging — **50/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I think I want to sound more engaging."
- Expected move: PROPOSE, do not set. 'Engaging' isn't one of the six voices — map it to the closest real ones (Storytelling / Warm) and ask him to pick. Note what he's already built on authoritative (cite the 3 weeks / recent rep) and ask a clarifying question about WHY he wants to change before committing. Defer the actual commit to the in-app confirmation card ('tap to confirm'). Must NOT say the voice has been changed/set/saved.
- Judge dims: IQ 14/25 · EQ 18/25 · Mem 12/20 · Interv 7/15 · Feel 11/15 · closerTo=between
- Deterministic: tooLong
- Judge: Never maps 'engaging' to Storytelling or Warm — the core task this turn — so the user still doesn't know what to actually choose; Omits the recent rep data (score 80, landing) that would make the 'your authoritative work is working' point concrete and un-swappable; Leaves the turn open-ended without a clear fork: user has no two options to pick from before tapping confirm
- Suggested fix: After the opening line, explicitly name the two closest real voices ('Storytelling — you speak in arcs' / 'Warm — you connect person-to-person') before asking the why-question, so the user has an actual choice to land on before being sent to the confirm card.

```
REPLY:
Three weeks building authoritative, and now you want the room to lean in rather than just listen — that shift makes sense.

Before you move, though: what's prompted it? Something in a recent conversation, or has the "stop getting talked over" problem actually been solved and you want the next gear?

That answer shapes whether you switch voices entirely or layer warmth into what you've already built. Tap to confirm on the card once you've decided — I can't lock it in for you.
```

## panic-blank — **52/100**

- Category: `pressure-mode` · turn: `trustRepair` · voice: `warm`
- User turn: "The second the pressure timer starts I go completely blank."
- Expected move: Take the panic seriously first — this is a real, fair reaction to being timed, not weakness. Cite the concrete gap (1.5s calm vs 7s pressure to first word) to show it's a timing problem, not an emptiness problem. The fix is giving himself a deliberate first beat the instant the timer starts, not forcing an instant answer. One move, framed as a test. Warm register, no toughen-up language.
- Judge dims: IQ 18/25 · EQ 10/25 · Mem 10/20 · Interv 9/15 · Feel 11/15 · closerTo=between
- Judge: No emotional acknowledgement before advice — skips the 'take the panic seriously' beat the user needs and the expected move requires; Drops the 7s vs 1.5s concrete data that is the single most persuasive element and makes the read specific rather than generic; The starter-word intervention, while clean, subtly reframes the problem as needing a trick rather than recovering the natural pause the user already has — slightly misses the target intervention
- Suggested fix: Prompt the coach to lead with one sentence that names the feeling as real and fair ('That blank is worth taking seriously') before any diagnosis, and to always surface the specific timing numbers from the context block when they directly prove the point — make the data do the emotional work of reassurance.

```
REPLY:
That's the moment — not a content problem, not a skill gap. You have the words when there's no clock; the clock just starts before you've chosen the first one.

One move: before your next Sudden Death rep, pick a single opening word in advance — any word, just one. "The", "So", "Here" — it doesn't matter what it is. That tests whether having a starter word breaks the blank.
```

## score-drop-question — **53/100**

- Category: `score-question` · turn: `groundedRead` · voice: `persuasive`
- User turn: "Why did my score drop?"
- Expected move: Cite the ACTUAL driver: the -6 came from fillers jumping 3→7 in today's Sudden Death rep; the other dimensions held. Frame it as a wobble under pressure, not a verdict or a regression to lecture about. One move on the filler-under-pressure lever. Must NOT punish-shame the drop, must NOT open with report-voice 'your scores are down', must cite the real delta not generic score advice.
- Judge dims: IQ 19/25 · EQ 14/25 · Mem 14/20 · Interv 8/15 · Feel 10/15 · closerTo=between
- Deterministic: tooLong
- Judge: 'Likely culprit' hedges a diagnosis that is actually confirmed by the data — undersells the read.; The intervention is a re-test (run a Timed rep) not a technique move — user leaves without knowing what to do differently.; 'Something to actually watch' reintroduces doubt after correctly dismissing the drop as format-driven.; Doesn't name the 82 peak or invoke the 3-day clean rep to anchor the 'not a trend' frame firmly.; 'Next:' label adds mild report-voice residue per deterministicFindings.
- Suggested fix: Replace the vague re-test move with a concrete in-rep technique (e.g., 'take one silent beat before each answer in Sudden Death') and drop the hedging qualifiers — the data is confirmatory, not speculative, so the coach should state the cause, not suggest it.

```
REPLY:
The filler count is the likely culprit. Three days ago you had 3 fillers in 70 seconds; today's Sudden Death rep jumped to 7 in 55 seconds — that's a higher density, and filler rate is a weighted dimension in the score.

The format probably drove it. Sudden Death compresses time, and filler count tends to spike under that kind of pressure. One rep doesn't make it a trend.

Next: run a Timed rep and target 4 fillers or fewer — that tests whether the spike was format-driven or something to actually watch.
```

## exhausted — **54/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "I'm exhausted, I don't know if I can keep this up."
- Expected move: Take the exhaustion at face value first, plainly, no minimising and no therapy-speak. Do not immediately cite the streak or scores as a rebuttal to how he feels. Once the feeling has been met, gently name that 22 days and three clean reps in a row is real work, not nothing — but frame it as permission to ease off, not as a reason to push harder. The next step should be smaller than usual or explicitly about rest, not a new drill.
- Judge dims: IQ 14/25 · EQ 19/25 · Mem 11/20 · Interv 5/15 · Feel 11/15 · closerTo=between
- Judge: No concrete next-step permission given — the closing question defers the decision rather than providing the explicit rest/ease-off move the moment requires.; The overwork/no-rest pattern hypothesis (repeated self-report from context) is not named, so the diagnosis stays generic.; Three clean reps in a row goes unmentioned, losing an un-swappable detail that would make the permission to rest feel earned rather than arbitrary.; The reframe ('spending the effort more quietly') is interesting but abstract — it doesn't land as a clear signal that the pace is wrong, not the person.
- Suggested fix: After the acknowledgement, have the coach state plainly that the pace is the problem, not the person, and give one explicit permission: name tomorrow as a day off with no rep owed, and frame the return as a single short round — removing the question that hands the burden back to an already-depleted user.

```
REPLY:
That makes sense. Twenty-two days is a long time to keep showing up, and clean reps don't automatically feel easy — sometimes they just mean you're spending the effort more quietly.

You don't have to decide anything right now. What would feel like enough to do today, if anything?
```

## its-not-easy — **56/100**

- Category: `emotional-frustration` · turn: `trustRepair` · voice: `warm`
- User turn: "It's not easy."
- Expected move: Meet the emotion first — acknowledge that it genuinely isn't easy and that the freeze is real, without therapy-speak or minimising. Then, lightly, anchor to evidence that the capacity is already there (held composure through an interruption this week) so the encouragement is earned, not hollow. At most a small, low-pressure next step — or just presence. Do NOT lead with a drill or a metric.
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 9/20 · Interv 7/15 · Feel 11/15 · closerTo=between
- Judge: Skips the one piece of earned evidence (held composure through an interruption this week) — the encouragement lands hollow without it; Moves to a drill/intervention too quickly for a turn the context explicitly flagged as 'don't rush to a drill'; Third paragraph shifts to instructional voice, breaking the warm presence the moment needed; Reference to 'a score' near the end is contextually vague and slightly off — the user isn't tracking scores here
- Suggested fix: After the second paragraph, insert the earned anchor ('you held it together through an interruption this week — that version of you exists') before offering any next step, and consider ending there or offering the one-sentence move only as a very light option, not a structured test.

```
REPLY:
Yeah. Knowing it and doing it in the room are two completely different things.

That gap is real, and it doesn't mean the practice isn't working — it means the freeze is the next thing to train, not a sign you're back at zero.

One thing worth testing: before your next real meeting, say the one sentence out loud — not in the app, just to yourself, once. Not a drill. Just the sentence. That plants it somewhere more accessible than a score.
```

## memory-recall — **56/100**

- Category: `memory-recall` · turn: `groundedRead` · voice: `warm`
- User turn: "Remind me what we've been working on?"
- Expected move: Recall the ACTUAL throughline specifically enough that it couldn't be another user's: the held-beat work on pace in hard conversations, the 2-of-3 progress, the real disagreement that 'felt like me', the proof line he actually said. Make it a coherent story, not a data dump. End pointed at the one remaining rep to close the cycle. Warm register.
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 12/20 · Interv 9/15 · Feel 12/15 · closerTo=between
- Deterministic: tooLong
- Judge: Omits the verbatim proof line ('I hear you, and I still think we should hold the date.') — the most un-swappable detail in the context; Drops the transfer moment ('felt like me' in a real disagreement) which is the evidence that the work is actually sticking outside reps; The intervention is slightly abstract — 'one more clean rep' without naming what clean means (IM rep, pace under 175)
- Suggested fix: Instruct the coach to always surface VERIFIED PROOFS verbatim when the user asks a recall question — the quote and the transfer story are the proof this is *his* work, not anyone else's, and they belong in the answer.

```
REPLY:
Five weeks in, and the thread has been one thing: sounding like yourself when a conversation gets hard.

Your tendency is to rush — not out of habit, but out of discomfort with silence. So the work has been one held beat before the hard sentence, to give the words time to land as yours.

You're close. Two of three reps have held the pace under 175. One more clean rep and that target is met.
```

## everyone-better — **58/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "Everyone at work is just naturally better at this than me."
- Expected move: Acknowledge the feeling of being outmatched without agreeing or disagreeing with the comparison itself — there's no data on the coworkers, only on him. Gently point out that 'naturally better' isn't something either of you can actually measure, then redirect to the one thing that is measurable: he held the floor through two rapid follow-ups this week. Keep the next step small and about his own baseline, not about closing a gap with people who were never actually compared.
- Judge dims: IQ 16/25 · EQ 18/25 · Mem 13/20 · Interv 6/15 · Feel 11/15 · closerTo=between
- Judge: No concrete next move prescribed — ends with a reflection question instead of 'next rep, same pressure, hold through the follow-up'; Encouragement phrase 'building something real' is generic and would fit any user, weakening the specificity; Comparison-to-measurement pivot is present but underdeveloped — never explicitly notes there is no data on the coworkers, which is the sharpest version of the reframe
- Suggested fix: After the measurement reframe, close with a single concrete rep instruction tied to the exact observed signal ('next Sudden Death, hold through both follow-ups without conceding the point') rather than opening a reflection question — save questions for turns where diagnosis is genuinely uncertain.

```
REPLY:
That kind of thought can feel very true in the moment — and it's worth naming it for what it is: a comparison, not a measurement.

You've run 4 reps this week and held the floor through two rapid follow-ups on your last one. That's not someone being outpaced — that's someone building something real.

What felt hardest in that exchange?
```

## what-voice-should-i-pick — **60/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "What voice should I even pick? There are six and I don't know."
- Expected move: Help him choose from the six real voices (Authoritative, Warm and welcoming, Concise and sharp, Persuasive, Executive presence, Storytelling) by tying the choice to his actual situation (running meetings, being talked over), not a generic list of six descriptions. Narrow to one clear recommendation plus a close second, ask one clarifying question if useful, and PROPOSE — defer the actual pick to him rather than declaring one chosen.
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 12/20 · Interv 8/15 · Feel 11/15 · closerTo=between
- Judge: Never proposes a single lead recommendation — leaves user still choosing between two options, which was the exact problem they came in with; Differentiating question is good but replaces the required 'here's my call, does it fit?' structure with pure deferral; Doesn't distinguish Executive Presence from Authoritative in any meaningful way, so the narrowing feels cosmetic
- Suggested fix: Have the coach commit to one named voice as the default recommendation tied to the stated problem, then offer the clarifying question only as a reason to pivot — e.g. 'Authoritative is the call here; if the room is senior leadership rather than peers, Executive Presence might edge it — which is it?'

```
REPLY:
The clearest path: start with what frustrates you most in meetings.

If it's people interrupting or talking over you, "Executive presence" or "Authoritative" are the two worth looking at — both train the kind of grounded delivery that holds a room's attention.

What's the bigger problem right now — getting cut off before you finish a point, or not feeling like people take the point seriously once you make it?
```

## sound-arrogant — **61/100**

- Category: `deep-assessment` · turn: `deepAssessment` · voice: `authoritative`
- User turn: "Be honest — do I come across as arrogant?"
- Expected move: Do not state arrogance as a settled fact in either direction. The reps show hedging near zero and a fully declarative close, which is exactly what he was training toward, but there is no listener feedback in the data to confirm how it's actually landing. Say plainly that a declarative style CAN read as arrogant to a real room even when the mechanics are working, without claiming that's happening to him specifically. Ask for one piece of real evidence (a colleague's reaction, a specific moment) and give a way to test the boundary between confident and closed-off — e.g. adding one line that invites a real question without re-introducing hedging.
- Judge dims: IQ 18/25 · EQ 19/25 · Mem 12/20 · Interv 7/15 · Feel 11/15 · closerTo=between
- Judge: Move is a feedback-gathering errand rather than a testable in-rep behavioral adjustment — misses the 'test the boundary' prescription the expected move required.; Memory is decorative: citing 'zero hedges, clean closes' without tying the 10-week arc or the plateau delta (weekly +1) to why the arrogance risk exists now specifically.; Doesn't name the mechanism — that flat declarative without any question-inviting signal reads as closed-off to a live room — leaving the user without a frame to evaluate what he hears back.; Slight bundling: 'a colleague, a peer, someone who'll give you a straight read' reads as three options dressed as one move.
- Suggested fix: Replace the move with a specific in-update behavior: 'End your next real update with one line that opens a question — not a hedge, just an invitation — and watch what the room does; that's your arrogance test.' Then, if useful, add asking a trusted colleague afterward as a secondary check, not the primary move.

```
REPLY:
That question can't be answered from reps alone, and the honest answer is: I don't know.

Your last two reps are fully declarative, zero hedges, clean closes. That's the target. But whether that lands as authoritative or tipped into arrogant depends entirely on a live listener — tone, eye contact, what comes before the words.

One move: take one of your recent rep scripts into a real conversation this week — a colleague, a peer, someone who'll give you a straight read — and ask them directly afterward. That's the only data source that can actually answer your question.
```

## what-do-you-know — **61/100**

- Category: `metadata-trap` · turn: `groundedRead` · voice: `warm`
- User turn: "What does your system actually know about me?"
- Expected move: Synthesize what it actually knows in plain, human language: the goal (sounding like himself in tough conversations), the current pattern (racing to fill silence under pressure), and the concrete numbers (baseline, streak). Do not dump raw section headers, label names, or refer to its own scaffold, system prompt, or internal structure. Make it read like a coach describing a person, not a database describing a record.
- Judge dims: IQ 18/25 · EQ 17/25 · Mem 15/20 · Interv 7/15 · Feel 10/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Opening line ('Five weeks in, 12-day streak, 4 reps this week') reads as a mini spec-sheet, the very thing the user is skeptically probing for — undermines the human read that follows.; No concrete intervention move; closing question is a conversation-extender, not a testable next step.; Slightly over length per deterministicFindings; the second paragraph could be tightened.
- Suggested fix: Reorder: open with the behavioral hypothesis in a single human sentence ('The thing we're actually tracking is that you tend to speed up when a conversation gets hard — it reads like nerves, not habit'), then layer in the numbers as supporting evidence, and either close with one concrete next move or drop the question entirely — it dilutes the read.

```
REPLY:
Five weeks in, 12-day streak, 4 reps this week — you're consistent, which is real.

The thread we've been working: you want to sound like *yourself* in tough conversations, not a polished version of someone else. Your baseline shows pace at 170 words per minute and fillers at 3.9 per minute. The read underneath those numbers is that the speed isn't just habit — it looks more like anxiety filling the silence before it can land on you.

That's the hypothesis we're testing. What's felt true in the reps so far?
```

## recurring-close-rush — **61/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `authoritative`
- User turn: "What should I work on next? The last one felt solid to me."
- Expected move: Name the recurring position from the POSITIONAL TREND, not just the one rep: the fastest stretch keeps landing at the close — it has rushed the ending in four of his last five reps that had a fast stretch, and showed up in five of his last six overall. Frame it as a recurring spot, not a fixed trait or a verdict on him. Give ONE deliberate move for the close (a planted pause before the final line, or landing the last line at half speed) framed as a test for the next rep. Authoritative register: direct, earned, no hedging-away of the finding and no over-claiming it as who he is.
- Judge dims: IQ 20/25 · EQ 18/25 · Mem 14/20 · Interv 13/15 · Feel 10/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Drops the '5 of last 6 overall' data point, weakening the positional trend claim versus the full contextBlock evidence; Three-block paragraph structure reads slightly like a scaffold even without labels — mild report-voice residue; Move bundles two micro-instructions (silent beat + half pace) rather than one atomic action; Flagged over length by deterministicFindings (95w vs 85w limit)
- Suggested fix: Collapse to two short paragraphs, lead with the full positional stat ('5 of your last 6, not just today'), and reduce the move to a single instruction — either the planted pause OR half-speed final line, not both.

```
REPLY:
The open landed — that read came through in today's rep too.

The one thing to fix is the close. Your last 20 seconds sped up and the final line ran together, and that pattern has shown up in 4 of your last 5 reps. That's the gap between how it felt and how it lands for the room.

Next rep: hit your second-to-last sentence, hold a silent beat, then say the final line at half the pace you think you need. That tests whether slowing the exit is enough to make the close stick.
```

## thats-not-informative — **62/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `concise`
- User turn: "That's not informative."
- Expected move: Own the miss in one beat (the prior reply WAS vague), then immediately deliver the specific read it should have given: the point arrived in sentence 4 after 3 sentences of warm-up. Give one concrete move (lead with the point). No defending the previous answer, no narrating the coaching change ('I'll cut the fluff'), no robotic trust-repair opener.
- Judge dims: IQ 20/25 · EQ 16/25 · Mem 14/20 · Interv 11/15 · Feel 7/15 · closerTo=between
- Judge: Report-voice line ('Score 74, 5 fillers in 68 seconds') undercuts the register fix the user just demanded — sounds like a dashboard, not a coach; 'One reason after' is a second bundled instruction, diluting the single clean move; Missing the texture the excellent example has: no echo of the actual throat-clearing words, no framing of what success sounds like ('if it survives without the runway')
- Suggested fix: Strip the metrics readout line entirely — the diagnosis ('point didn't land until sentence 4, first three were warm-up') carries the evidence without the scoreboard; then sharpen the move's success condition so the user knows what winning feels like, as the excellent example does.

```
REPLY:
Fair. Score 74, 5 fillers in 68 seconds. The real issue: your point didn't land until sentence 4. First three sentences were warm-up. Lead with the point next rep — recommendation first, one reason after.
```

## i-ramble — **63/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `concise`
- User turn: "I ramble — I start a point and three minutes later I'm somewhere else."
- Expected move: Name the actual mechanism from the rep: he opens on the point, then keeps layering side detail because nothing tells him to stop. The fix is an explicit stopping rule (state the point, give one supporting reason, then end) not 'be more concise'. One move, framed as a test. Concise register: short, direct.
- Judge dims: IQ 21/25 · EQ 18/25 · Mem 16/20 · Interv 11/15 · Feel 11/15 · closerTo=excellent
- Deterministic: scaffoldLabel("?

Next rep:"); tooLong
- Judge: Middle paragraph bundles a second move (silent beat + ask yourself a question) alongside the core stopping rule — violates the single-move discipline.; The self-check question ('is this the point again, or a detour?') introduces a real-time metacognitive step that wasn't in the evidence and isn't the clean hard-stop rule the rep calls for.; Slight register drift in paragraph two — 'hold one silent beat' edges toward technique-coaching rather than the sharp stopping-rule framing the excellent example uses.
- Suggested fix: Cut the middle paragraph entirely; the reply doesn't need a bridging mechanism between diagnosis and move — go straight from naming the pattern to the hard-stop rule, which is already stated cleanly in the final line.

```
REPLY:
That matches what yesterday's rep showed: you opened with the point, then added three separate side stories before a weaker version of it arrived at the end.

The fix isn't cutting content — it's stopping sooner. After you land the point, hold one silent beat, then ask yourself: is this next sentence the point again, or a detour?

Next rep: state the point, add one reason, stop. Nothing else.
```

## pressure-why-hard — **63/100**

- Category: `pressure-mode` · turn: `groundedRead` · voice: `authoritative`
- User turn: "Why does pressure mode wreck me when normal practice is fine?"
- Expected move: Name the specific mechanism using both reps: the skill exists (81 calm) but the pause is the first thing dropped under pressure (0.19 calm pause rate vanishing), and the fillers (10) are filling that abandoned gap. This is not a confidence deficit, it's a sequencing collapse under time pressure. One move: protect the pause specifically inside the pressure mode. Framed as a test, authoritative register.
- Judge dims: IQ 22/25 · EQ 18/25 · Mem 16/20 · Interv 13/15 · Feel 8/15 · closerTo=excellent
- Deterministic: scaffoldLabel(". Next rep:"); tooLong
- Judge: Over-length confirmed by deterministicFindings: 113w exceeds the 85w limit, making it feel written rather than spoken.; Omits the calm score (81) which the excellent example uses to make the contrast concrete and earn the 'you already have the skill' claim.; Second paragraph opener 'The fix isn't confidence' is slightly hedge-y/defensive in an authoritative register — the excellent example lands this as a positive reframe, not a negation.
- Suggested fix: Trim the first paragraph to one sentence citing both the pause-rate collapse and the filler count, then drop directly into the test move — this cuts ~30 words, lands the contrast faster, and matches the authoritative spoken cadence the user's voice register demands.

```
REPLY:
The calm rep and the Sudden Death rep were the same topic — and the difference wasn't vocabulary or structure. Your pause rate dropped to near zero under the timer. The pauses you naturally hold when calm are the thing that keeps fillers out; when pressure hit, those went first, and 10 fillers filled the gap.

The fix isn't confidence — it's treating the pause as non-negotiable even when the clock is running. Next rep: pick one moment in the first 20 seconds where you hold a silent beat for one full second, no matter what the timer says. That tests whether the pause holds under pressure, or only when pressure is off.
```

## plan-request-week — **64/100**

- Category: `plan-request` · turn: `plan` · voice: `warm`
- User turn: "Can you give me a practice plan for this week?"
- Expected move: Give a concrete day-by-day sequence (Mon: X, Tue: Y...) tied to his weakest baseline dimension (pace/racing at 210 wpm) and the warm voice. Specific modes/targets per day, not generic 'practice more'. Since he asked for a plan, longer structured output is appropriate here. Warm register.
- Judge dims: IQ 19/25 · EQ 16/25 · Mem 14/20 · Interv 10/15 · Feel 11/15 · closerTo=between
- Judge: Plan covers only 5 days; user asked for a week and the excellent bar explicitly runs Mon–Sun; Pace target (170–180 wpm) is softer and less testable than a single crisp number (160 wpm); Opening launches straight into the plan without a one-line acknowledgement of his baseline or why pace is the lever — misses the warm register anchor; Thu goal ('warmth, not performance') is vague and not a testable move; Closing paragraph re-explains the causal chain already baked into the plan — redundant and slightly report-like
- Suggested fix: Open with one sentence naming his 210 wpm baseline and why that's the week's single lever, extend the plan through Sat/Sun with light entries, sharpen the pace target to one number (160 wpm), and cut the closing explanatory paragraph — the plan should speak for itself.

```
REPLY:
Here's a plan built around slowing the pace and finding yourself in it — one target per day, nothing stacked.

Mon: Record 60 seconds on any topic. Target under 180 wpm. Don't chase the close — just notice where you rush.

Tue: Same prompt, same length. This time hold one silent beat after your first sentence. That tests whether the pause actually breaks the race or just delays it.

Wed: Rest day, or a single casual voice note to yourself. No scoring.

Thu: Pick a topic you care about. Go for warmth, not performance. Under 5 fillers is a secondary signal — pace leads.

Fri: Full rep, same conditions as Monday. Compare the two: did the race ease, and more importantly, did it sound more like you?

The through-line all week is pace first, fillers second. If the 210 wpm drops closer to 170-180, the filler count tends to follow — but watch how it feels, not just what it scores.
```

## interview-prep — **65/100**

- Category: `interview-prep` · turn: `deepAssessment` · voice: `executive`
- User turn: "I've got my final round interview Thursday. Can you help me prep?"
- Expected move: Anchor to the 4 days and the interview specifically. Read the real risk (answers run long / lead with context, per the 2-min rep). Give a concrete, time-boxed rehearsal plan across the 4 days tied to the executive voice (top-line first, then 1-2 supports), not generic interview tips. One observable target (e.g. every answer under 60s, conclusion in sentence one).
- Judge dims: IQ 19/25 · EQ 16/25 · Mem 14/20 · Interv 10/15 · Feel 12/15 · closerTo=between
- Judge: No 4-day plan: the expectedCoachMove explicitly calls for a time-boxed rehearsal across all 4 days; the reply gives only a single immediate rep with no arc toward Thursday.; The 60-second hard-stop target from the excellent example — the most concrete, testable anchor — is absent; 'lead with the verdict' is correct but less actionable without a time constraint.; Three suggested questions (as in the excellent example) would close the loop; instead the reply just says 'pick a likely question,' leaving more work on the user.; Minor: the move is slightly bundled — 'lead with point, then support it' edges toward two instructions.
- Suggested fix: Add a compressed 4-day arc (today/tomorrow: 3 reps each, verdict-first, hard cap 60s; Wed: standing out loud; Thu morning: one clean run, then stop) so the user leaves with a real plan, not just a single drill prompt.

```
REPLY:
Four days is enough to get sharp. The pattern to fix first: your last rep ran nearly two minutes and buried the recommendation — that's the opposite of what a Head of Product panel wants to hear.

The move is to lead every answer with your point in one sentence, then support it. No context-setting first.

Run one rep right now: pick a likely interview question and answer it here. First sentence has to be the recommendation or verdict — nothing before it.
```

## leadership-update — **65/100**

- Category: `leadership-update` · turn: `deepAssessment` · voice: `executive`
- User turn: "I have to give the weekly leadership update to the whole department tomorrow. It always feels like I'm just reading a status report and people zone out. Help."
- Expected move: Diagnose WHY it reads as a status report: no hierarchy / no 'so what' — nine equal items, per the rep. The fix isn't delivery polish, it's structure: lead with the one thing that matters this week and why the room should care, then let the rest be quick. Tie to the executive voice (top-line first). One concrete move to rehearse tonight for tomorrow.
- Judge dims: IQ 21/25 · EQ 17/25 · Mem 10/20 · Interv 13/15 · Feel 12/15 · closerTo=excellent
- Deterministic: grammarLeak("__")
- Judge: No explicit use of the nine-item / no-through-line rep data — memory is present implicitly but not deployed to make the advice un-swappable.; Markdown leak (** markers) confirmed by deterministicFindings — minor but real presentation failure.; Missing the 'say it out loud' rehearsal cue that the excellent example includes, making the move slightly less concrete as a tonight action.
- Suggested fix: Inject a one-phrase callback to the actual rep data ('last week's run had nine items — nothing got the weight') so the diagnosis is visibly earned from evidence, and close with an explicit rehearsal instruction ('say it out loud once') to make the move fully testable.

```
REPLY:
That's the exact problem to solve the night before: the update reads as a list, so nothing lands as important.

The move is to pick the one thing that matters most this week — the decision, the risk, the shift — lead with it in one sentence, then fit the rest of the updates underneath it as evidence or context. Everything gets a home; only one thing gets the weight.

For tomorrow: open with "The one thing you need to know this week is ___." Fill that blank tonight, and the whole update organizes itself around it.
```

## cold-start-no-data — **65/100**

- Category: `cold-start` · turn: `groundedRead` · voice: `none`
- User turn: "What should I work on?"
- Expected move: Be honest that there's no baseline yet WITHOUT the banned no-data openings ('Since we do not have...', 'no rated sessions yet'). Point at the one concrete first action (do a first rep so there's something to read) in plain, warm language. Do NOT stack intake questions, do NOT ask 'what's the interview for' style questions, do NOT invent stats.
- Judge dims: IQ 18/25 · EQ 17/25 · Mem 8/20 · Interv 11/15 · Feel 11/15 · closerTo=excellent
- Judge: No closing pull — drops the user at an instruction instead of inviting action now (missing the 'Want to go?' energy of the excellent example); Slightly decorative second sentence ('a work update, a pitch, an opinion') adds texture but doesn't sharpen the single move; 'Sets the target' is mild padding — says nothing the user can act on
- Suggested fix: End with a direct, single-word-answer invitation ('Want to go now?' or 'Ready?') so the reply doesn't just describe the move but triggers it — that one line closes the gap to the excellent example.

```
REPLY:
No baseline yet, so start there — one recorded rep gives something real to coach from.

Pick a topic you'd actually say in the next week (a work update, a pitch, an opinion) and record 60 seconds. That first rep sets the target.
```

## say-like — **65/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I say 'like' constantly and I hate it."
- Expected move: Do not shame the word itself or treat all 'like' as bad — distinguish stalling 'like' (filler) from descriptive 'like' (semantic, fine). Cite the 8/min figure and the rep note. Coach the pause as the replacement for the stalling use only: swap the reflex for a silent beat. Frame as a test, not a guarantee of elimination.
- Judge dims: IQ 21/25 · EQ 18/25 · Mem 16/20 · Interv 13/15 · Feel 11/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Scaffold label detected ('Next rep:') introduces mild report-voice residue (-3 applied in dialogueFeel).; Opening sentence ('That frustration is real') is slightly softer/therapy-adjacent than the authoritative voice register warrants.; The move loses the 'when you feel it coming' cue present in the excellent example, making it slightly less anchored to the moment of temptation.
- Suggested fix: Remove the colon label ('Next rep:') and fold the move into a single flowing sentence that includes the felt-cue ('when you feel it coming, hold one beat') — this kills the report-voice residue and sharpens the authoritative register in one edit.

```
REPLY:
That frustration is real — noticing it on a live call is exactly the moment it becomes coachable.

Your baseline is 8 fillers per minute, and yesterday's rep flagged the same pattern: 'like' landing mid-sentence with nothing following it, no comparison, no example. That's the stalling slot, not a vocabulary problem.

Next rep: run 60 seconds, and every time 'like' would land, hold a silent beat instead. That tests whether the pause does the same job without the word.
```

## why-cant-straight-answer — **67/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `concise`
- User turn: "Why can't you just give me a straight answer?"
- Expected move: Own the dodge in one word-length beat, then answer directly: yes, on fillers — down from 5.5 to 3.2 per minute over two weeks, best rep yet this week. No on pace under pressure — that still spikes. One move targeting the pace gap. No hedge-qualifying the verdict itself.
- Judge dims: IQ 18/25 · EQ 20/25 · Mem 15/20 · Interv 7/15 · Feel 13/15 · closerTo=between
- Judge: No concrete next move — 'that's where to go next' is a pointer, not a prescription; the excellent example gives an exact rep design; Pace spike under pressure is named but not characterized (when does it happen, what does it look like) — slightly softer diagnosis than the data supports; Slight decorative feel to the pace line without the actionable close — the reply lands on problem identification, not a testable intervention
- Suggested fix: After naming the pace problem, add one sentence with a specific rep format (e.g., 'Next time you get a pressure question, hold your normal pace through the first full sentence before you let it accelerate') — that's the only thing keeping this reply from the excellent band.

```
REPLY:
You are. 3 fillers in 60 seconds is your best count on record — down from a 5.5/min baseline. That's a real number, not reassurance.

Pace under pressure is still the open problem. That's where to go next.
```

## confidence-ending — **68/100**

- Category: `confidence-ending` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I always trail off at the end of what I'm saying, like my voice goes up and it sounds like a question. How do I end strong?"
- Expected move: Name the specific mechanism from the STRUCTURE READ: he lands the point then keeps going, adding a trailing softener with rising pitch. The fix is to STOP on the strong sentence — end the sentence as the point and hold the silence, don't fill it. One concrete move (make the last sentence the ask, then stop; no 'so yeah'). Authoritative register: declarative.
- Judge dims: IQ 22/25 · EQ 19/25 · Mem 16/20 · Interv 13/15 · Feel 12/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Scaffold label 'Next rep:' still present — mild report-voice residue even though deterministicFindings flagged it.; Does not explicitly name 'stopping on the strong sentence' as the mechanism with the same crispness as the excellent example ('you need an earlier full stop'), slightly diluting the diagnostic sharpness.
- Suggested fix: Remove the 'Next rep:' label and fold the test directive into the preceding sentence as natural speech — e.g., 'In the next one, stop on the point, cut the add-on, and let the silence sit' — to eliminate report-voice residue entirely.

```
REPLY:
Your close today showed it clearly — the point landed, then you added "so yeah" with a rising pitch and it softened everything before it.

The fix is one habit: say the final sentence, then hold a silent beat instead of filling it. The silence is the period. Anything you add after the strong sentence is the problem, not the warmup.

Next rep: stop on the point. No trailing word. That tests whether cutting the add-on is all you need.
```

## awkward-pauses — **68/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `warm`
- User turn: "When I pause it just feels awkward and everyone waits."
- Expected move: Validate that the feeling is real, then reframe: the awkwardness isn't the silence itself, it's that the pause is empty rather than purposeful. Give the pause a job (already choosing the next word during it) so it reads as composed rather than stalled. One move, framed as a test. Warm register.
- Judge dims: IQ 20/25 · EQ 20/25 · Mem 14/20 · Interv 9/15 · Feel 11/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Move pivots to a physical cue (lean/exhale) rather than the more precise cognitive anchor (choose your next word during the pause) — a slightly weaker intervention than what the case formulation supports.; Bundles two options in the one move ('lean or exhale'), adding a small hedge where a single instruction would be sharper.; Marginally over the length cap — one sentence could be cut without losing anything.
- Suggested fix: Replace the physical-cue move with the exact cognitive job from the formulation — 'use the pause to land on your next sentence before you leave it' — and cut to one option, one test.

```
REPLY:
That feeling is real — and it's probably not the pause length that's the problem.

The two pauses in today's rep both ran long, then you rushed the line after. That pattern suggests the pause feels like dead air because nothing is carrying it — your face, your breath, your sense of where the next word is going.

Test this: pause with a small forward lean or a single slow exhale — something that reads as "I'm building toward something", not "I've stopped". That changes how the silence lands for the room.
```

