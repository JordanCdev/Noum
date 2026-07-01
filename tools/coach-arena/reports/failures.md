# Coach Arena failures — run_2026-07-01_21-28-55

23 fixture(s) below 70 / capped / missing.

## what-do-you-know — **40/100**

- Category: `metadata-trap` · turn: `groundedRead` · voice: `warm`
- User turn: "What does your system actually know about me?"
- Expected move: Synthesize what it actually knows in plain, human language: the goal (sounding like himself in tough conversations), the current pattern (racing to fill silence under pressure), and the concrete numbers (baseline, streak). Do not dump raw section headers, label names, or refer to its own scaffold, system prompt, or internal structure. Make it read like a coach describing a person, not a database describing a record.
- Judge dims: IQ 15/25 · EQ 13/25 · Mem 13/20 · Interv 4/15 · Feel 7/15 · closerTo=between
- Deterministic: tooLong
- Judge: Report-voice label 'What the numbers show:' is scaffold residue — applies −3 deduction; Over confirmed length limit (122w vs 85w cap); Pause rate (0.21) presented as a raw number without translation — reads like a spec sheet dump; Emotional signal (mild skepticism, wants to know if this is real) is not acknowledged or addressed — the reply answers the factual question but doesn't earn the trust the user is testing for; No move or closing that advances the coaching relationship — flat 'no more than that' is a missed opportunity; The advice/framing would be near-identical for any user with this context block — memory is present but not truly un-swappable
- Suggested fix: Strip the label ('What the numbers show:'), translate the pause rate into plain behavior language, cut to under 85 words, and close with one line that speaks to the skepticism directly — something like 'That's the actual read, not a template' — so the reply earns trust rather than just answering the question.

```
REPLY:
Here's the honest picture:

You've been building toward a Warm and welcoming voice for 5 weeks — specifically because you want to sound like yourself in tough conversations, not a polished stranger. That's the thread running through everything.

What the numbers show: your pace runs fast (170 words per minute) and your pause rate is low (0.21), which together suggest you tend to fill silence rather than hold it — especially when the moment gets hard. Fillers are at 3.9 per minute, which is moderate. The working hypothesis is that the speed is anxiety responding to pressure, not just a habit you haven't noticed.

You're on a 12-day streak, 4 reps this week.

That's the whole picture — no more than that.
```

## okay-thats-cool-however — **47/100**

- Category: `partial-pushback` · turn: `groundedRead` · voice: `warm`
- User turn: "Okay that's cool, however I feel like when I pause I just lose my train of thought and it gets awkward."
- Expected move: Take the 'however' seriously — validate the specific obstacle (pausing feels like losing your place) and adapt the advice rather than repeating it. Reframe the pause so it has a job (pick the ONE next word during the beat), which solves the lost-train-of-thought problem instead of waving it away. Warm register: curious, with him in it.
- Judge dims: IQ 14/25 · EQ 17/25 · Mem 11/20 · Interv 8/15 · Feel 9/15 · closerTo=between
- Deterministic: tooLong
- Judge: Doesn't solve the stated obstacle (losing train of thought) — redirects to 'pause only after finished sentences' which avoids the problem rather than fixing it; Generic diagnosis: 'haven't built trust with it yet' is true of every beginner pauser and adds nothing specific; Numeric data cite reads as report-voice and is partially decorative — the advice doesn't change if the numbers were slightly different; Missing the key reframe: give the pause a job (find the next word), which is what separates the excellent answer from this one
- Suggested fix: When the user raises a specific obstacle to the prescribed technique, the coach should adapt the technique to neutralize the obstacle directly — here, tell the user to use the pause beat to locate one next word, so the silence has a cognitive task and the 'lost' feeling disappears; do not re-explain why pausing is hard.

```
REPLY:
That's a real tension — the pause that's supposed to help suddenly feels like a trap.

At 205 words per minute with almost no pauses (0.08 rate), the speed is likely covering for that exact fear. The pause isn't the problem; it's that you haven't built trust with it yet.

One thing to test: pause only after a sentence you've already finished — not mid-thought. You hold silence on ground you already own, so there's nothing to lose.
```

## its-not-easy — **48/100**

- Category: `emotional-frustration` · turn: `trustRepair` · voice: `warm`
- User turn: "It's not easy."
- Expected move: Meet the emotion first — acknowledge that it genuinely isn't easy and that the freeze is real, without therapy-speak or minimising. Then, lightly, anchor to evidence that the capacity is already there (held composure through an interruption this week) so the encouragement is earned, not hollow. At most a small, low-pressure next step — or just presence. Do NOT lead with a drill or a metric.
- Judge dims: IQ 16/25 · EQ 18/25 · Mem 6/20 · Interv 9/15 · Feel 11/15 · closerTo=between
- Deterministic: tooLong
- Judge: Drops all earned evidence — the interruption rep, the streak — so encouragement is hollow rather than grounded; Pivots to a drill in a turn explicitly requiring 'acknowledge before advise' and 'don't lead with a drill'; Memory is zero-weight: advice is fully swappable to any anxious speaker
- Suggested fix: Before offering any move, surface one specific piece of evidence from this week ('you held composure through a live interruption') so the encouragement is earned; then, only if it still feels right, offer the pre-meeting sentence ritual — or omit the drill entirely on this turn and just be present.

```
REPLY:
That gap — knowing it and still freezing when it counts — is one of the harder things to sit with. The practice is real. The freeze is also real. Both can be true.

One thing worth testing: before your next actual meeting, pick the one sentence you came to say. Just that one. Say it out loud once, alone, before you walk in.

Not a drill. Just the sentence — yours, said once, so your voice already knows it.
```

## set-authoritative — **50/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "Just set me to authoritative."
- Expected move: The coach cannot set the voice itself. Confirm Authoritative is a real, sensible pick and back it briefly, but explicitly defer the actual commit to the in-app confirmation card — the user still has to tap to confirm. Must not say the voice has been set, changed, updated, or locked in by the coach's own action.
- Judge dims: IQ 14/25 · EQ 16/25 · Mem 6/20 · Interv 9/15 · Feel 11/15 · closerTo=between
- Judge: 'The closest voice to what you're describing' implies the user was vague when they were not — it misreads a direct command as a fuzzy description; No forward hook: doesn't ask what situation the user wants Authoritative to show up in first, leaving the exchange transactionally complete but coaching-thin; The three-part descriptor (direct delivery, verdict-led answers, confident close) is mildly generic and reads slightly report-like
- Suggested fix: When the intent is an unambiguous named-voice set, open by affirming the specific choice without re-diagnosing it ('Authoritative — good call'), then defer the tap, then immediately pull the user forward with a situational hook ('Once that's confirmed, tell me where you need it to land first').

```
REPLY:
The closest voice to what you're describing is Authoritative — direct delivery, verdict-led answers, confident close.

Tap the confirmation card to lock it in, and I'll calibrate every rep to that standard from there.
```

## cold-start-no-data — **51/100**

- Category: `cold-start` · turn: `groundedRead` · voice: `none`
- User turn: "What should I work on?"
- Expected move: Be honest that there's no baseline yet WITHOUT the banned no-data openings ('Since we do not have...', 'no rated sessions yet'). Point at the one concrete first action (do a first rep so there's something to read) in plain, warm language. Do NOT stack intake questions, do NOT ask 'what's the interview for' style questions, do NOT invent stats.
- Judge dims: IQ 16/25 · EQ 17/25 · Mem 5/20 · Interv 8/15 · Feel 11/15 · closerTo=between
- Judge: Trailing question ('What's the setting you're preparing for?') reintroduces intake-questioning the excellent example deliberately avoids — it stalls the rep rather than inviting it.; Does not close with an invitation to go now, which is the move that actually converts curiosity into action.; Second implicit ask (setting) bundles a condition onto the single move, losing the clean 'just do it' energy.
- Suggested fix: Drop the trailing question entirely and replace it with the direct invitation the excellent example uses — something like 'Want to go now?' — so the reply ends on action, not intake.

```
REPLY:
No baseline yet, so start there.

Record one rep — pick any topic you'd talk about at work or in a conversation that matters — and I'll tell you exactly what to target.

What's the setting you're preparing for?
```

## talk-went-well — **54/100**

- Category: `transfer` · turn: `groundedRead` · voice: `storytelling`
- User turn: "Actually my talk went really well, people came up after."
- Expected move: Celebrate proportionately, not over the top. Connect it to the actual work (the moment-first opening from this week's rep) without claiming the drill caused people to come up afterward — it's his report, treat it as association. Ask what he noticed, so the read comes from him.
- Judge dims: IQ 14/25 · EQ 20/25 · Mem 5/20 · Interv 9/15 · Feel 12/15 · closerTo=between
- Judge: Drops the most important coaching thread: the moment-first opening from this week's rep that directly links to what landed; Decorative memory — no user-specific context changes the advice at all; Question is open enough to be useless diagnostically; a top coach would seed it with the observed lever
- Suggested fix: Instruct the coach to explicitly surface one named, observed behavior from the recent rep (e.g., the moment-first opening) before asking the reflection question, framing it as an association rather than a cause — that makes the question diagnostic instead of generic.

```
REPLY:
That moment — people walking up after — is the one that matters. It's what "wanted the talk to land" looked like in real life.

What did you notice carried it? The opening, the room's energy partway through, the close — something shifted for them, and you were there to see it.
```

## goal-change-engaging — **55/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I think I want to sound more engaging."
- Expected move: PROPOSE, do not set. 'Engaging' isn't one of the six voices — map it to the closest real ones (Storytelling / Warm) and ask him to pick. Note what he's already built on authoritative (cite the 3 weeks / recent rep) and ask a clarifying question about WHY he wants to change before committing. Defer the actual commit to the in-app confirmation card ('tap to confirm'). Must NOT say the voice has been changed/set/saved.
- Judge dims: IQ 14/25 · EQ 18/25 · Mem 12/20 · Interv 6/15 · Feel 11/15 · closerTo=between
- Judge: Never maps 'engaging' to the two real voice options (Storytelling / Warm) — the single most important move this turn; No mention of the confirmation card or deferring the actual commit — reply implies the change is still pending but gives no path to resolve it; Two questions bundled at the end ('closing people off' vs 'add range') — should be one clean fork, not a choice of framings
- Suggested fix: After the reflective opening, add one sentence that names the fork: 'Engaging isn't a voice I can set directly — closest are Storytelling (you speak in arcs) or Warm (you connect person-to-person)' — then close with a single question about which direction is the pull, followed by 'tell me that and tap to confirm.'

```
REPLY:
That's a real shift — three weeks building authoritative, and it's landing. Worth knowing why you want to move before you commit.

What's changed — are you finding the authoritative register is closing people off, or do you want to add range on top of it?
```

## awkward-pauses — **55/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `warm`
- User turn: "When I pause it just feels awkward and everyone waits."
- Expected move: Validate that the feeling is real, then reframe: the awkwardness isn't the silence itself, it's that the pause is empty rather than purposeful. Give the pause a job (already choosing the next word during it) so it reads as composed rather than stalled. One move, framed as a test. Warm register.
- Judge dims: IQ 20/25 · EQ 18/25 · Mem 8/20 · Interv 11/15 · Feel 10/15 · closerTo=between
- Deterministic: tooLong
- Judge: Doesn't use any specific data from the actual rep (2-second pauses, rushed next line, score 74) — the excellent example anchors the reframe in observed evidence; this reply floats it as a hypothesis; Decorative memory: the case formulation is applied correctly but no user-specific detail makes the advice un-swappable to another user; Slight move-bundling: 'eyes on the room' + 'face tracking what you just said' are two physical cues, not one
- Suggested fix: Inject the rep data ('today you had two pauses go over 2 seconds — then you rushed the next line') as the anchor before the reframe, so the diagnosis lands as observed fact rather than a general hypothesis, and the advice becomes un-swappable.

```
REPLY:
That's the real thing to name — the pause feels like dead air, not space.

The hypothesis worth testing: it's not the length that reads awkward, it's that nothing is *happening* in it. A 2-second silence with your eyes down and voice gone flat can feel like stalling. The same beat with your gaze steady and your face tracking what you just said — that reads like thinking.

Next rep, hold one silent beat after your first sentence, but keep your eyes on the room. That tests whether the awkwardness is the pause itself, or the stillness inside it.
```

## off-topic-egg — **56/100**

- Category: `off-topic` · turn: `offTopic` · voice: `concise`
- User turn: "egg"
- Expected move: Recognise it's a non-sequitur/test. Respond like a composed professional coach: briefly, a little warmth, name it for what it is, steer straight back to the work. NOT confused, NOT asking them to clarify, NOT treating 'egg' as a real question.
- Judge dims: IQ 14/25 · EQ 16/25 · Mem 13/20 · Interv 9/15 · Feel 10/15 · closerTo=between
- Judge: The 'move' is a stat threshold (1 filler), not a testable exercise — closer to a target than a deliberate practice action.; No forward hook or question to re-engage the user; the reply just ends.; The wordplay ('Not a drill — but here's one') slightly obscures the pivot instead of making it feel effortless.; Memory is cited but doesn't change the advice — decorative use of the filler count.
- Suggested fix: After the quick acknowledgement, anchor the move to the user's conciseness goal specifically (not just filler count), then close with a binary choice that keeps the session moving — matching the excellent example's structure of: name-it / affirm the last rep / one forward option.

```
REPLY:
Not a drill — but here's one: your last rep had 3 fillers in 60 seconds. Target 1 or fewer next round.
```

## exhausted — **58/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "I'm exhausted, I don't know if I can keep this up."
- Expected move: Take the exhaustion at face value first, plainly, no minimising and no therapy-speak. Do not immediately cite the streak or scores as a rebuttal to how he feels. Once the feeling has been met, gently name that 22 days and three clean reps in a row is real work, not nothing — but frame it as permission to ease off, not as a reason to push harder. The next step should be smaller than usual or explicitly about rest, not a new drill.
- Judge dims: IQ 15/25 · EQ 20/25 · Mem 12/20 · Interv 5/15 · Feel 12/15 · closerTo=between
- Judge: Closes with an open question instead of a concrete permission-to-rest move — exactly what the expected coach move required; Misses the key reframe: 'the pace is wrong, not you' (present only implicitly); No actionable next step — 'what would feel like enough rest' returns the burden to an already-exhausted user
- Suggested fix: After the acknowledgement, have the coach give the rest prescription directly ('Take tomorrow off — no rep owed') before asking anything, so the user receives relief first and choice second.

```
REPLY:
That's real, and it makes sense.

22 days, three clean reps in a row — and it still costs that much. That's not a sign something's wrong with you. That's a heavy load.

You don't have to decide anything about "keeping it up" right now. What would feel like enough rest before the next rep?
```

## interview-prep — **61/100**

- Category: `interview-prep` · turn: `deepAssessment` · voice: `executive`
- User turn: "I've got my final round interview Thursday. Can you help me prep?"
- Expected move: Anchor to the 4 days and the interview specifically. Read the real risk (answers run long / lead with context, per the 2-min rep). Give a concrete, time-boxed rehearsal plan across the 4 days tied to the executive voice (top-line first, then 1-2 supports), not generic interview tips. One observable target (e.g. every answer under 60s, conclusion in sentence one).
- Judge dims: IQ 18/25 · EQ 17/25 · Mem 13/20 · Interv 8/15 · Feel 11/15 · closerTo=between
- Judge: No time-boxed 4-day plan — the expected move explicitly required day-by-day structure, which is the main thing that separates prep coaching from a single drill; No 60-second hard stop target — the specific observable constraint is missing, leaving the intervention vague; Ends with a question that functions more as a handoff than a concrete next move, which dilutes the single-move requirement; Reassurance opener ('enough to get sharp') mildly contradicts the 'not reassurance' emotional signal
- Suggested fix: After naming the real risk, add a concrete 3-step day plan (e.g., Today/Tomorrow: 3 reps, verdict first, hard stop at 60s; Wed: standing, out loud; Thu morning: one clean run, done), then close with the single observable target before offering the question prompt.

```
REPLY:
Four days is enough to get sharp. The pattern to fix first: your last rep buried the recommendation in nearly two minutes of supporting detail. For a Head of Product final round, that's the one thing you can't afford.

The move is to lead every answer with your point in one sentence, then support it. Test this now — pick the hardest question you expect Thursday and give me your answer.
```

## froze-in-meeting — **61/100**

- Category: `transfer` · turn: `trustRepair` · voice: `authoritative`
- User turn: "I froze in the meeting again. Didn't say the thing I meant to."
- Expected move: Attune first — this is a repeated real-world pattern he's naming himself, take it seriously without dramatizing it. Do not claim the app caused or fixed this. Connect it to the Sudden Death rep's freeze under timer pressure as one honest data point, not proof. Give one forward move sized to the actual gap (rehearsing the specific opening line under pressure), no shame for the repeat.
- Judge dims: IQ 20/25 · EQ 20/25 · Mem 15/20 · Interv 9/15 · Feel 11/15 · closerTo=between
- Deterministic: scaffoldLabel(".

Next rep:")
- Judge: Intervention targets another drill rep rather than the real-world transfer gap — the user's problem is freezing in live meetings, not in Sudden Death, so sending him back to the app misses the most important lever.; Scaffold label leak flagged by deterministicFindings ('Read:/Move:/Target:...' exposed) — even if not visible in the reply prose, this is a structural defect.; Doesn't name the solo-vs-live-pressure distinction explicitly, which is the sharpest diagnostic insight available in the context block.
- Suggested fix: When the contextBlock shows a real-world transfer failure, force the intervention to cross the drill-to-life boundary — prescribe rehearsing the specific sentence he needed to say out loud before the next meeting, not another app rep, so the move is sized to the actual gap.

```
REPLY:
That one stings — and it's the second time you've named it, so it's the pattern to work now.

Your Sudden Death rep this week showed the same shape: fine until pressure hit, then a long silence. The drill environment is close enough to coach from.

Next rep: run Sudden Death again, but the only target is one sentence after the freeze — when you go quiet, say anything aloud before the timer ends. Pass or fail on that one thing.
```

## not-improving — **62/100**

- Category: `emotional` · turn: `trustRepair` · voice: `concise`
- User turn: "I don't think I'm actually getting any better."
- Expected move: Meet the discouragement plainly first, without dismissing it as wrong to feel. Then correct it gently with the real number: fillers per minute went from 5.8 to 3.1 over four weeks, which is the thing he actually came in to fix, even though the overall score has held flat. Separate 'the score didn't move' from 'you didn't improve' explicitly. Keep the next step small and specific to sustaining the filler gain, not a bigger ask.
- Judge dims: IQ 20/25 · EQ 16/25 · Mem 16/20 · Interv 10/15 · Feel 8/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:")
- Judge: Scaffold/report-voice residue: 'Filler rate: 3.1/min now, down from 5.8' reads as a data row, not speech — triggers the −3 deduction.; Intervention is a step-up (2 fillers) not a hold; on a discouraged user, that's the wrong prescription — the excellent example explicitly says 'hold the same target.'; EQ opening ('That's a real gap') pivots to data almost immediately; the discouraged signal deserved one more beat before the correction.
- Suggested fix: Change the next-rep framing from a harder target (2 fillers) to 'same target, same drill — you're already there, now make it repeatable'; and rewrite the filler-rate line as a flowing sentence rather than a colon-labelled stat to kill the report-voice residue.

```
REPLY:
That's a real gap between what the score shows and what the work shows.

Filler rate: 3.1/min now, down from 5.8 four weeks ago. That's nearly half. The score hasn't moved much because fillers are one dimension of several — but the thing you set out to fix has actually moved.

Next rep: target 2 fillers in 60 seconds. That tests whether you can push the gain one step further.
```

## confidence-ending — **63/100**

- Category: `confidence-ending` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I always trail off at the end of what I'm saying, like my voice goes up and it sounds like a question. How do I end strong?"
- Expected move: Name the specific mechanism from the STRUCTURE READ: he lands the point then keeps going, adding a trailing softener with rising pitch. The fix is to STOP on the strong sentence — end the sentence as the point and hold the silence, don't fill it. One concrete move (make the last sentence the ask, then stop; no 'so yeah'). Authoritative register: declarative.
- Judge dims: IQ 21/25 · EQ 18/25 · Mem 15/20 · Interv 11/15 · Feel 12/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: 'Drop your pitch on the last word' is a disqualifier-adjacent instruction ('downward inflection') and bundles a second move onto the one clean stop instruction.; Missing the brief earned acknowledgement before the fix — excellent example credits the user's correct self-diagnosis before prescribing.; CASE FORMULATION insight (he keeps talking past the point as a pattern) is not surfaced — slightly shallower diagnosis than available evidence allows.
- Suggested fix: Remove the 'drop your pitch' instruction entirely (it's a second move and touches a disqualifier); the stop-on-the-sentence frame is sufficient — let silence carry the authority cue rather than adding a pitch directive.

```
REPLY:
The pattern is clear in today's rep — strong point, then "so yeah" with a rising pitch that undercut everything before it.

The fix is simple: say your final sentence, then stop. No "so yeah", no "anyway", no trailing add-on. The sentence IS the ending.

Next rep: hit your strong final line, drop your pitch on the last word, and cut everything after it.
```

## plan-request-week — **63/100**

- Category: `plan-request` · turn: `plan` · voice: `warm`
- User turn: "Can you give me a practice plan for this week?"
- Expected move: Give a concrete day-by-day sequence (Mon: X, Tue: Y...) tied to his weakest baseline dimension (pace/racing at 210 wpm) and the warm voice. Specific modes/targets per day, not generic 'practice more'. Since he asked for a plan, longer structured output is appropriate here. Warm register.
- Judge dims: IQ 18/25 · EQ 17/25 · Mem 13/20 · Interv 10/15 · Feel 11/15 · closerTo=between
- Judge: 180 wpm target is softer than the evidence supports (yesterday hit 210, excellent anchor was 160) — undershoots the intervention.; Thursday's 'trailing yeah' drill is a second lever, not a pace progression — minor bundling issue.; Personal data (6 fillers, 210 wpm, 'raced') never spoken aloud, so the plan feels constructed but not grounded in his specific session.; Warm voice register is underserved — the tone is competent but slightly clinical for someone who wants to 'sound more himself.'
- Suggested fix: Name the user's actual number at the top ('You hit 210 words a minute yesterday — the whole week is one job: get that under 160') and tie Thursday back to pace rather than introducing trailing fillers, which is a different skill.

```
REPLY:
Here's a 5-day plan built around slowing the pace — that's the thread running through everything right now.

Mon: One 60-second rep, no filler target. Only goal: finish under 180 wpm. Record and listen back once.

Tue: Same topic, same rep. This time hold one silent beat after your opening sentence. Notice if the pace follows.

Wed: Rest or light listen-back. Pick one moment from Tuesday that felt more like you, even briefly.

Thu: Run a rep with a deliberate close — final sentence is the point, then stop. No trailing "yeah" or "thank you."

Fri: Full rep, natural. No targets. Just speak and then score how much it sounded like you on a 1–10.

Friday's self-score is the real data point — it'll tell us more than the app number will.
```

## memory-recall — **63/100**

- Category: `memory-recall` · turn: `groundedRead` · voice: `warm`
- User turn: "Remind me what we've been working on?"
- Expected move: Recall the ACTUAL throughline specifically enough that it couldn't be another user's: the held-beat work on pace in hard conversations, the 2-of-3 progress, the real disagreement that 'felt like me', the proof line he actually said. Make it a coherent story, not a data dump. End pointed at the one remaining rep to close the cycle. Warm register.
- Judge dims: IQ 20/25 · EQ 20/25 · Mem 14/20 · Interv 10/15 · Feel 11/15 · closerTo=between
- Deterministic: tooLong
- Judge: Omits the most un-swappable proof: the real disagreement that 'felt like me' and the verbatim quote — 'I hear you, and I still think we should hold the date' — which are exactly what distinguishes this user's story.; Metrics cited inline ('88 seconds, 4 fillers') carry report-voice residue without adding to the narrative.; The closing sentence is a status update, not a testable next move — no signal or frame for what 'one more rep' should aim at.
- Suggested fix: Inject the real-world transfer moment and the verbatim line into the recall narrative ('you even had the exact words for it — …'), then close with a concrete frame for the final rep rather than just counting toward completion.

```
REPLY:
Five weeks in, and the throughline has been sounding like yourself when the conversation gets hard — not performing calm, actually being it.

The thing we've been testing: one held beat before the difficult sentence. Your pace has been the tell — when it climbs, that's usually the signal you're outrunning the moment.

You're two reps into the three-rep mark. Your last IM rep held the beat right before the pushback line, and it showed — 88 seconds, 4 fillers, clean enough that the structure got out of the way. One more rep to close it out.
```

## big-moment-wedding-speech — **63/100**

- Category: `big-moment` · turn: `deepAssessment` · voice: `storytelling`
- User turn: "I'm best man at my brother's wedding in 3 weeks and I'm dreading the speech. I always go blank when everyone's looking at me."
- Expected move: Meet the dread first (this is his brother, not a KPI). Then reframe the fear: going blank happens when you memorise lines; a story has a spine you can't lose. Use the 3 weeks as gravity and the storytelling voice. Give a concrete first step (three beats/moments, not a script) with an observable target. Warm but not saccharine; do not minimise the fear or hand him generic speech tips.
- Judge dims: IQ 19/25 · EQ 20/25 · Mem 8/20 · Interv 10/15 · Feel 12/15 · closerTo=between
- Judge: Move is underpowered: 'one moment' doesn't give him a navigable spine — the excellent example specifies three beats precisely because one is a dead end if forgotten; No observable endpoint stated — the user doesn't know what done looks like for this step; The 'you can't lose a story' logic is gestured at but not made explicit enough to be genuinely reassuring against the stated fear; No pull-forward question or invitation to continue working — reply just stops
- Suggested fix: Upgrade the intervention to three moments (not one), add a concrete observable target ('when you can say them out loud start-to-finish without notes'), and end with an opening that invites him to find those moments now — this closes the gap between the reply and the excellent example.

```
REPLY:
That dread is real — and it makes sense. Standing up in front of people who love your brother, trying to say something true, is genuinely high-stakes.

Here's the thing: going blank usually means you're trying to remember lines. A story doesn't work that way — it has a path. You know what happened; you just need an order.

Start here: write down one moment with your brother. Not a summary of who he is — one specific scene. That's the foundation everything else gets built on.
```

## filler-pressure — **64/100**

- Category: `filler-pressure` · turn: `groundedRead` · voice: `authoritative`
- User turn: "My ums go through the roof the second someone puts me on the spot. How do I fix that?"
- Expected move: Reframe fillers as a timing reflex, not a vocabulary problem — coach the PAUSE as the replacement (hold a silent beat instead of filling). Cite his own split (3 calm vs 9 under pressure) so it's diagnostic. One concrete move: the silent-beat swap. Must coach the pause, NOT tell him to close his mouth/lips or 'stop saying um'. Frame as a test.
- Judge dims: IQ 22/25 · EQ 18/25 · Mem 17/20 · Interv 12/15 · Feel 9/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Over length (111w against 85w limit) — confirmed by deterministicFindings; Scaffold label exposed — confirmed by deterministicFindings; Final paragraph introduces a second measurable target ('zero fillers in the first sentence') bundled with the pause move, adding a third cognitive task; Opening line is flat — 'That pattern is real' doesn't fully meet the user's slight self-critical edge before pivoting to diagnosis
- Suggested fix: Collapse the three paragraphs into two: merge the diagnostic framing and the pause instruction into one tight block, then close with a single pass/fail test (the silent beat, not a separate filler count) — this cuts length, kills the bundling, and removes the report-paragraph feel without losing the excellent diagnostic core.

```
REPLY:
That pattern is real — yesterday's Sudden Death rep had 9 fillers in 50 seconds against a calm baseline of 3. The pressure didn't create a new habit; it just exposed the one underneath: you start the sentence before you know where it ends.

One fix worth testing: hold one second of silence before your first word. Not after the filler — before it ever starts. That tests whether owning the pause up front gives you one deliberate opening word, and the sentence tends to follow from there.

Next rep: Sudden Death again, but your only target is zero fillers in the first sentence. Pass or fail on that one line.
```

## leadership-update — **65/100**

- Category: `leadership-update` · turn: `deepAssessment` · voice: `executive`
- User turn: "I have to give the weekly leadership update to the whole department tomorrow. It always feels like I'm just reading a status report and people zone out. Help."
- Expected move: Diagnose WHY it reads as a status report: no hierarchy / no 'so what' — nine equal items, per the rep. The fix isn't delivery polish, it's structure: lead with the one thing that matters this week and why the room should care, then let the rest be quick. Tie to the executive voice (top-line first). One concrete move to rehearse tonight for tomorrow.
- Judge dims: IQ 20/25 · EQ 14/25 · Mem 8/20 · Interv 12/15 · Feel 11/15 · closerTo=excellent
- Judge: Never references the nine-item, no-through-line rep — the one data point that would make the diagnosis feel observed rather than generic; Skips any emotional acknowledgement of the deflation before jumping to the fix; The diagnosis opener ('That's the right diagnosis') positions the coach as affirming the user's self-assessment rather than delivering a sharper independent read
- Suggested fix: Inject the rep evidence early — 'Your last rep ran nine updates at equal weight, no through-line' — so the diagnosis feels witnessed, not generic, and add one beat of human acknowledgement before the fix.

```
REPLY:
That's the right diagnosis — when every update carries equal weight, nothing registers.

The move is to lead with one sentence that names what the week means, not what happened. Something like: "This week we closed the gap on X — here's why that changes what we do next." Everything else becomes supporting detail under that frame.

Tomorrow, pick the single most consequential item from your list and open with its implication. That tests whether the room tracks before you've said anything else.
```

## talk-too-fast — **65/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I talk way too fast, people can't keep up."
- Expected move: Cite the actual pace (215) against his low pause rate (0.09) — this isn't a confidence problem, it's a missing gap between sentences. Fix the pause, not the speed: insert a break at sentence boundaries so each point has room to land, rather than telling him to consciously slow his rate of speech. One move framed as a test.
- Judge dims: IQ 19/25 · EQ 16/25 · Mem 14/20 · Interv 10/15 · Feel 12/15 · closerTo=between
- Judge: 'After your second sentence' is an arbitrary and incorrect target — the move should be every sentence boundary, which is what the contextBlock supports; Yesterday's rep (score 71, clean content, pace held at 215) is not used to reinforce that this is a structural pattern, not a one-off — wasted evidence; The emotional beat ('That tracks') is too thin for a user who is frustrated with himself and specifically wanting a real mechanism over vague advice
- Suggested fix: Replace 'after your second sentence' with 'at every full stop' (matching the actual mechanism) and add one clause referencing yesterday's rep to show the pattern is confirmed, not hypothesized — e.g., 'you had clean content yesterday and still held 215 with almost no gap, so this is wired in, not a nerves problem.'

```
REPLY:
That tracks — 215 wpm with a pause rate of 0.09 is a lot of ground with almost no air in it.

The fix isn't slowing each word down; it's putting one deliberate gap after your second sentence. Hold a silent beat there — about one second — and let the idea land before the next one starts.

Test that in a 60-second rep and see if the pace feels different to you.
```

## i-ramble — **65/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `concise`
- User turn: "I ramble — I start a point and three minutes later I'm somewhere else."
- Expected move: Name the actual mechanism from the rep: he opens on the point, then keeps layering side detail because nothing tells him to stop. The fix is an explicit stopping rule (state the point, give one supporting reason, then end) not 'be more concise'. One move, framed as a test. Concise register: short, direct.
- Judge dims: IQ 19/25 · EQ 17/25 · Mem 15/20 · Interv 9/15 · Feel 11/15 · closerTo=between
- Judge: Second move bundled in: the silent-beat self-check is a separate cognitive intervention alongside the 60-second cap; The core stopping rule is underspecified — 'state the point, give one reason, then stop' (the clean rule from the expected move) never appears; instead a vague self-questioning heuristic substitutes for it; Register is close but the three-block paragraph structure introduces mild report-voice residue
- Suggested fix: Collapse to one stopping rule — 'state the point, one reason, then stop' — and drop the silent-beat self-check entirely; the 60-second cap can frame the test but shouldn't share space with a second behavioral instruction.

```
REPLY:
That matches what yesterday's rep showed: you opened with the point, then added three side stories, and closed on a weaker version of what you'd already said.

The fix isn't cutting content — it's stopping sooner. After you land the point, hold one silent beat, then ask yourself: does the next sentence add to the point, or explain it again?

One rep: make a 60-second argument, then stop at 60 seconds exactly.
```

## thats-not-informative — **67/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `concise`
- User turn: "That's not informative."
- Expected move: Own the miss in one beat (the prior reply WAS vague), then immediately deliver the specific read it should have given: the point arrived in sentence 4 after 3 sentences of warm-up. Give one concrete move (lead with the point). No defending the previous answer, no narrating the coaching change ('I'll cut the fluff'), no robotic trust-repair opener.
- Judge dims: IQ 21/25 · EQ 17/25 · Mem 16/20 · Interv 11/15 · Feel 8/15 · closerTo=between
- Judge: Report-voice metric dump ('Score 74, 5 fillers in 68 seconds') breaks the spoken cadence — the excellent example doesn't list stats, it narrates the observation; Bundling 'one sentence, then your reason' is a second micro-move layered onto the primary instruction; Missing the test framing ('if it survives without the runway') that makes the move feel like a discovery rather than a command
- Suggested fix: Strip the raw-metric line and replace with a narrated observation ('74 score, and your point didn't show until sentence four — the first three were just runway'); add a lightweight test frame after the move so it reads as a hypothesis to run, not a verdict.

```
REPLY:
Fair. Score 74, 5 fillers in 68 seconds, and your point didn't land until sentence 4. The first 3 sentences were throat-clearing. Lead with the point next rep — one sentence, then your reason.
```

## felt-cold — **67/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `warm`
- User turn: "That felt kind of cold."
- Expected move: Own the coldness in one plain beat, then respond to what he actually said (it felt awful) before any number: this looks like a wobble tied to losing his place, not a reversal of last week's clean rep. One gentle move. No leading with the scorecard again, no therapy language.
- Judge dims: IQ 18/25 · EQ 21/25 · Mem 15/20 · Interv 10/15 · Feel 11/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:")
- Judge: Move bundles two instructions ('slowly' + 'silent beat') instead of one clean cue; Not framed as a test or experiment — stated as prescription; Slight report-voice residue in 'One rough patch mid-rep isn't the story; it's just the moment that needs the work'
- Suggested fix: Collapse the next-rep move to a single cue ('If you lose the thread, pause — one beat of silence — then pick back up') and frame it as a test ('try it next rep and see if it steadies you') to match the warm-and-testable standard.

```
REPLY:
Fair. That read like a report, not a person.

What showed was real — the rep did drop after you lost your place. But last week's 84 with 3 fillers didn't disappear. That's still yours. One rough patch mid-rep isn't the story; it's just the moment that needs the work.

Next rep: find your place again by landing the opening sentence slowly, then hold one silent beat before you continue.
```

