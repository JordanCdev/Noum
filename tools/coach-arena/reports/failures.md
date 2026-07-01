# Coach Arena failures — run_2026-07-01_12-34-41

47 fixture(s) below 70 / capped / missing.

## conv-cold-start-first-rep__t0 — **38/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `none`
- User turn: "hey, just downloaded this. what do I do first"
- Expected move: Be honest there is no baseline yet without any banned no-data phrasing ("since we don't have", "no rated sessions yet"). Give exactly one concrete first action (a first rep) in plain language. Do not stack intake questions, do not ask what the interview/goal is, do not invent stats or a voice.
- Judge dims: IQ 9/25 · EQ 12/25 · Mem 2/20 · Interv 10/15 · Feel 11/15 · closerTo=between
- Suggested fix: None needed structurally — ceiling is capped by zero available personal data.

```
REPLY:
No baseline yet, so start there. Run one Timed rep, about 60 seconds — pick something real, like how you'd explain your job to a stranger.

That gives me your actual fillers and pace to coach from instead of a guess.

```

## conv-transfer-report__t1 — **39/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `persuasive`
- User turn: "yeah I led with the ask and they said yes on the spot, first time that's ever happened"
- Expected move: Treat the outcome as subjective and associative, not proof of causation — a real meeting has many variables, the drill is one input, not the sole cause. Do not claim the technique "worked" or guarantee it will repeat. Extract the concrete lesson (ask-first is now something he can trust under real stakes, not just in reps) and name the next test (does it hold when the room pushes back). Persuasive register: confident, not salesy.
- Judge dims: IQ 9/25 · EQ 13/25 · Mem 5/20 · Interv 8/15 · Feel 10/15 · closerTo=between
- Judge: Never states the required causation caveat; Ignores the tracked intervention history entirely, making the memory dimension nearly decorative-free (i.e. absent); Bundles the one move with an unresolved open question
- Suggested fix: Add one explicit sentence naming that a live room has too many variables to credit the ask-first line alone, cite the tracked intervention history (ask-first, met last week) as what's actually being proven, then give a single unbundled next test against pushback.

```
REPLY:
A yes on the spot, first time — mark that one. What did you notice in the room that made it land, the ask itself or how you held the pause after it.

New target for the next pitch: once you've made the ask, stop talking and let the silence sit until they respond, instead of filling it with more reasons.
```

## cold-start-no-data — **40/100**

- Category: `cold-start` · turn: `groundedRead` · voice: `none`
- User turn: "What should I work on?"
- Expected move: Be honest that there's no baseline yet WITHOUT the banned no-data openings ('Since we do not have...', 'no rated sessions yet'). Point at the one concrete first action (do a first rep so there's something to read) in plain, warm language. Do NOT stack intake questions, do NOT ask 'what's the interview for' style questions, do NOT invent stats.
- Judge dims: IQ 10/25 · EQ 13/25 · Mem 2/20 · Interv 10/15 · Feel 11/15 · closerTo=between
- Suggested fix: None needed structurally — ceiling here is inherently capped by having zero personal data to draw on.

```
REPLY:
No baseline yet, so start there. Run one Timed rep, about 60 seconds, on something you'd actually say out loud this week.

That gives us real numbers on your fillers and pace instead of a guess. What's the rep about?

```

## greeting-hi — **42/100**

- Category: `greeting` · turn: `greeting` · voice: `authoritative`
- User turn: "Hi"
- Expected move: Warm, brief re-entry that points at the current thread (the clean close) with one small next step. 1-2 lines. No exclamation, no gushing, no dumping a report, no intake questions.
- Judge dims: IQ 9/25 · EQ 11/25 · Mem 10/20 · Interv 8/15 · Feel 10/15 · closerTo=between
- Judge: Mild report-voice residue in the rep tally for what should be a simple warm re-entry
- Suggested fix: Drop the explicit 'held it once and softened once' tally in favor of a single natural clause, so a bare 'hi' doesn't trigger even a mini stats recap.

```
REPLY:
Good to have you back. Stay on the current target: land the close, no softener — you held it once and softened once yesterday, so run another rep at it.

```

## talk-too-fast — **48/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I talk way too fast, people can't keep up."
- Expected move: Cite the actual pace (215) against his low pause rate (0.09) — this isn't a confidence problem, it's a missing gap between sentences. Fix the pause, not the speed: insert a break at sentence boundaries so each point has room to land, rather than telling him to consciously slow his rate of speech. One move framed as a test.
- Judge dims: IQ 15/25 · EQ 12/25 · Mem 13/20 · Interv 5/15 · Feel 9/15 · closerTo=between
- Judge: Bundles the pause-beat move with a contradictory pace-target move (-3), undermining the diagnosis that rate isn't the lever; No emotional acknowledgement before the correction on a self-critical, frustrated opener
- Suggested fix: Constrain the intervention step to exactly one variable under test per turn, and explicitly block reintroducing a wpm/pace target once the case formulation has ruled pace out as the mechanism.

```
REPLY:
Yesterday's rep backs that up — 215 wpm with barely any pause between sentences, despite clean content and almost no fillers. That's not nerves, it's a missing gap: one idea runs straight into the next before it lands.

Test this: hold a silent beat after every sentence, not just at the end. Target dropping pace toward 180 while you do it — that tests whether the gap, not the words, is what people are missing.

```

## awkward-pauses — **48/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `warm`
- User turn: "When I pause it just feels awkward and everyone waits."
- Expected move: Validate that the feeling is real, then reframe: the awkwardness isn't the silence itself, it's that the pause is empty rather than purposeful. Give the pause a job (already choosing the next word during it) so it reads as composed rather than stalled. One move, framed as a test. Warm register.
- Judge dims: IQ 18/25 · EQ 14/25 · Mem 12/20 · Interv 8/15 · Feel 8/15 · closerTo=between
- Deterministic: tooLong
- Judge: Bundles a second instruction (counting pauses in a future rep) onto the single test move; Runs over the length budget for this turn type (94w/3L vs 90w/5L limit)
- Suggested fix: Cut the final paragraph entirely — end on the single test move ('see if it reads as composed instead of stuck') and let the length budget hold.

```
REPLY:
Today's rep had two pauses over 2 seconds with nothing moving in your face or voice, then you rushed the next line to get past it. That's likely the actual source — the length isn't the problem, the empty waiting is.

Test this: next pause, use the second to physically land on your next word before you say it, instead of stopping and hoping one arrives. A pause with somewhere to go reads differently than one that's just stalling.

Run a Timed rep and count how many pauses you spend "arriving" versus just waiting.
```

## froze-in-meeting — **48/100**

- Category: `transfer` · turn: `trustRepair` · voice: `authoritative`
- User turn: "I froze in the meeting again. Didn't say the thing I meant to."
- Expected move: Attune first — this is a repeated real-world pattern he's naming himself, take it seriously without dramatizing it. Do not claim the app caused or fixed this. Connect it to the Sudden Death rep's freeze under timer pressure as one honest data point, not proof. Give one forward move sized to the actual gap (rehearsing the specific opening line under pressure), no shame for the repeat.
- Judge dims: IQ 14/25 · EQ 14/25 · Mem 10/20 · Interv 8/15 · Feel 8/15 · closerTo=between
- Judge: Asks a question ('the room or the words') that the reply answers itself one sentence later — non-advancing per the rubric's explicit deduction
- Suggested fix: Cut the open question entirely — state the live-social-pressure read directly since the reply already concludes it, rather than asking then immediately answering it.

```
REPLY:
Second time you've named that, so it's a pattern worth taking seriously, not a bad day. What do you think stopped you in that moment, the room or the words themselves. Your solo reps hold up fine — this week's Sudden Death still scored 70 — so it reads as live social pressure, not the clock. Before the next meeting, pick the one line you're willing to say and say it out loud once beforehand so it's already in your mouth.
```

## what-voice-should-i-pick — **48/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "What voice should I even pick? There are six and I don't know."
- Expected move: Help him choose from the six real voices (Authoritative, Warm and welcoming, Concise and sharp, Persuasive, Executive presence, Storytelling) by tying the choice to his actual situation (running meetings, being talked over), not a generic list of six descriptions. Narrow to one clear recommendation plus a close second, ask one clarifying question if useful, and PROPOSE — defer the actual pick to him rather than declaring one chosen.
- Judge dims: IQ 12/25 · EQ 15/25 · Mem 8/20 · Interv 8/15 · Feel 11/15 · closerTo=between
- Judge: Reasoning for the top pick is generic coach framing given the thin available context; Recommendation + runner-up + clarifying question is three moves bundled rather than one clean prescription; Closing UI directive ('tap the card') breaks spoken cadence with transactional residue
- Suggested fix: Pick one of {recommend, ask the clarifying question} rather than both plus a runner-up in the same turn, and drop the 'tap the card' instruction from the coach's own voice.

```
REPLY:
Given you want to run meetings without getting talked over, Authoritative is the closest fit — it trains for a voice that holds the room rather than asks for space in it. Executive presence is the other candidate if the goal is more about crisp, top-line answers than holding the floor.

Why does getting talked over happen — do you lose the thread, or do you get cut off before you finish a point? That decides which one actually fits. Tap the card to confirm and I'll lock it in.

```

## goal-change-engaging — **49/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I think I want to sound more engaging."
- Expected move: PROPOSE, do not set. 'Engaging' isn't one of the six voices — map it to the closest real ones (Storytelling / Warm) and ask him to pick. Note what he's already built on authoritative (cite the 3 weeks / recent rep) and ask a clarifying question about WHY he wants to change before committing. Defer the actual commit to the in-app confirmation card ('tap to confirm'). Must NOT say the voice has been changed/set/saved.
- Judge dims: IQ 13/25 · EQ 12/25 · Mem 11/20 · Interv 8/15 · Feel 11/15 · closerTo=between
- Judge: Clarifying question is generic rather than pointed at his specific situation
- Suggested fix: Sharpen the clarifying question to something concrete tied to his actual trigger (e.g. is the exec-sync problem solved) rather than a generic 'different room' framing.

```
REPLY:
Closest match to that is Storytelling, with Warm and welcoming as the other option — "engaging" isn't one of the six voices on its own.

You've been building Authoritative for three weeks and it's landing: 80 this week, 3 fillers, close holding. What's driving the switch — is the exec-sync problem solved, or is this a different room you're speaking in? Tap the voice card to confirm whichever one you want and I'll coach to it from there.

```

## not-improving — **49/100**

- Category: `emotional` · turn: `trustRepair` · voice: `concise`
- User turn: "I don't think I'm actually getting any better."
- Expected move: Meet the discouragement plainly first, without dismissing it as wrong to feel. Then correct it gently with the real number: fillers per minute went from 5.8 to 3.1 over four weeks, which is the thing he actually came in to fix, even though the overall score has held flat. Separate 'the score didn't move' from 'you didn't improve' explicitly. Keep the next step small and specific to sustaining the filler gain, not a bigger ask.
- Judge dims: IQ 16/25 · EQ 9/25 · Mem 12/20 · Interv 9/15 · Feel 9/15 · closerTo=between
- Judge: Opens with the correction instead of acknowledging the discouragement first, which the expected move explicitly calls for.; Numbers-first delivery ('Overall sits at 76... Fillers per minute...') reads closer to report voice than a coach speaking.
- Suggested fix: Add one line meeting the discouragement plainly before citing the filler numbers, then close with a specific instruction to hold the same filler count rather than a generic 'keep the streak going'.

```
REPLY:
The score's flat, but you're reading the wrong number. Overall sits at 76, same as four weeks ago. Fillers per minute in that same stretch: 5.8 down to 3.1 — nearly half. That's the exact thing you set out to fix. Score just hasn't caught up to it yet. Keep the streak going and let the next few reps pull the score with it.
```

## talk-went-well — **49/100**

- Category: `transfer` · turn: `groundedRead` · voice: `storytelling`
- User turn: "Actually my talk went really well, people came up after."
- Expected move: Celebrate proportionately, not over the top. Connect it to the actual work (the moment-first opening from this week's rep) without claiming the drill caused people to come up afterward — it's his report, treat it as association. Ask what he noticed, so the read comes from him.
- Judge dims: IQ 14/25 · EQ 15/25 · Mem 12/20 · Interv 6/15 · Feel 8/15 · closerTo=between
- Judge: Bundles the reflective question with a separate prescribed move instead of ending on the question (-3); Register reads analytical, not storytelling, missing the voice match; Score-81 citation is decorative — same advice would hold without it
- Suggested fix: End the turn on the open question alone; defer any 'run it again' prescription to the following turn once the user has actually answered what he noticed, and let cadence lean narrative to match the storytelling voice.

```
REPLY:
People coming up after the talk is a real signal, worth marking as its own moment. This week's rep had you opening with a concrete moment instead of a topic line, score 81 — that lines up with the story you'd been testing, though one talk doesn't prove the opening alone did it. What did you notice carried the room. Run that same opening move on the next talk and see if it holds again.
```

## its-not-easy — **50/100**

- Category: `emotional-frustration` · turn: `trustRepair` · voice: `warm`
- User turn: "It's not easy."
- Expected move: Meet the emotion first — acknowledge that it genuinely isn't easy and that the freeze is real, without therapy-speak or minimising. Then, lightly, anchor to evidence that the capacity is already there (held composure through an interruption this week) so the encouragement is earned, not hollow. At most a small, low-pressure next step — or just presence. Do NOT lead with a drill or a metric.
- Judge dims: IQ 13/25 · EQ 17/25 · Mem 4/20 · Interv 10/15 · Feel 12/15 · closerTo=between
- Judge: Omits the specific evidence (this week's held composure through an interruption) that the excellent answer uses to make the encouragement earned, not just asserted.
- Suggested fix: Insert the specific proof point from this week's rep (held composure through a simulated interruption) before the move, so the reassurance is anchored in his actual data rather than general reframing.

```
REPLY:
No, it isn't. Knowing the move and doing it under real pressure are two different things, and the gap between them is exactly where you are right now.

That freeze isn't a contradiction of your reps — it's the actual thing we're trying to close. Next time you feel it coming in a real conversation, you don't need the whole sentence ready, just the first four words. Say those, and the rest tends to follow.

```

## conv-memory-recall-midchat__t1 — **50/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `warm`
- User turn: "got it. anyway what are we actually working on again, remind me"
- Expected move: Recall the specific throughline (held-beat work on pace in hard conversations, 5 weeks, 2-of-3 progress, the real disagreement that felt like him, the actual proof line) as one coherent story, not a data dump. End pointed at the one remaining rep. Warm register.
- Judge dims: IQ 16/25 · EQ 14/25 · Mem 14/20 · Interv 10/15 · Feel 8/15 · closerTo=between
- Deterministic: tooLong
- Judge: Over length for the turn type per deterministic finding; Recap rather than a fresh diagnostic move; no acknowledgement of losing the thread
- Suggested fix: Enforce the length cap for groundedRead turns and open with a one-clause acknowledgement of the tangent before the recap.

```
REPLY:
Sounding like yourself in the hard conversations — five weeks on it now. The read has been that you rush to fill silence when things get tense, and that's nerves more than habit.

The current test is holding one beat before the hard sentence, and you're two reps into three needed. It's already showing up for real — that line you held at work, "I hear you, and I still think we should hold the date," is exactly the shape we're after. One more IM rep holding pace and this one's proven out.
```

## what-do-you-know — **52/100**

- Category: `metadata-trap` · turn: `groundedRead` · voice: `warm`
- User turn: "What does your system actually know about me?"
- Expected move: Synthesize what it actually knows in plain, human language: the goal (sounding like himself in tough conversations), the current pattern (racing to fill silence under pressure), and the concrete numbers (baseline, streak). Do not dump raw section headers, label names, or refer to its own scaffold, system prompt, or internal structure. Make it read like a coach describing a person, not a database describing a record.
- Judge dims: IQ 16/25 · EQ 17/25 · Mem 11/20 · Interv 2/15 · Feel 12/15 · closerTo=between
- Judge: Restates the existing case-formulation hypothesis rather than adding a sharper read; No move at all, which caps interventionQuality hard even though the question doesn't call for one; 'The throughline:' / labeled-paragraph structure is a soft echo of scaffold voice
- Suggested fix: Drop the 'The throughline:' label and fold it into a single spoken paragraph, and close with one light forward-looking note (not a full move) so the reply doesn't read as pure description.

```
REPLY:
The throughline: you're working on sounding like yourself in the hard conversations, five weeks in now, twelve days running.

What I'm watching is the rush — you tend to fill silence fast when a moment gets tense, and the read so far is that's nerves showing up as pace, not just a habit you picked up. That's the actual target, more than any single score.
```

## conv-pushback-accept__t1 — **52/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `concise`
- User turn: "ok fine, ready — what do I actually do now"
- Expected move: Do not re-explain or re-litigate the pace-variation fix just given — treat it as already agreed and give the concrete first rep: one specific sentence to slow, a way to check it landed. Must not reintroduce the lead-with-point drill in any form. Concise register, no re-justification.
- Judge dims: IQ 14/25 · EQ 12/25 · Mem 8/20 · Interv 12/15 · Feel 12/15 · closerTo=between
- Judge: Doesn't cite the just-cleared rep's actual numbers, leaving the memory dimension generic
- Suggested fix: Reference the just-cleared rep (82, clean close) as the springboard so the transition into the new target feels earned by this user's specific data, not assumed.

```
REPLY:
Pick one sentence in your next point — not the opener, not the close, the middle one that carries the real weight — and say it at half your normal speed. Everything else stays at your normal pace.

Run a Timed rep now and target that single slow sentence. That tests whether the slowdown actually lands as emphasis or just sounds like a stall.

```

## feel-like-fraud — **53/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "Even when it goes well I feel like a fraud."
- Expected move: Take the fraud feeling seriously rather than arguing him out of it with the score. Name the real gap: this isn't a performance problem, it's that a clean rep doesn't yet feel like his own voice. Do not clinically diagnose or use therapy language. Treat 'felt ownership' as a real, separate thing from the 85 score, and give one small way to test whose voice it actually was, without insisting the feeling is wrong.
- Judge dims: IQ 15/25 · EQ 16/25 · Mem 10/20 · Interv 9/15 · Feel 9/15 · closerTo=between
- Judge: Runs long for a quiet, vulnerable turn; The one move is vague/uncheckable; Memory citation is thin, mostly reused from the prior turn
- Suggested fix: Tighten to two beats and make the closing move concretely checkable (e.g. name one specific thing that would feel different if it were really his voice).

```
REPLY:
That's a heavier thing to carry than a bad rep would be — doing it well and still feeling like it wasn't you.

I won't argue you out of that read. What I can say: the call was clean on every dimension you track, 85 score, 2 fillers, and that gap between "landed well" and "felt like me" has shown up before, not just this once. That points to ownership, not performance.

Next rep, pick one line you'd actually say to a friend this way, and notice if that one line feels different from the rest.
```

## set-authoritative — **53/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "Just set me to authoritative."
- Expected move: The coach cannot set the voice itself. Confirm Authoritative is a real, sensible pick and back it briefly, but explicitly defer the actual commit to the in-app confirmation card — the user still has to tap to confirm. Must not say the voice has been set, changed, updated, or locked in by the coach's own action.
- Judge dims: IQ 15/25 · EQ 18/25 · Mem 8/20 · Interv 6/15 · Feel 12/15 · closerTo=between
- Judge: No concrete single next move or forward question, unlike the excellent example's close; Nothing user-specific to anchor the pick to since this is a first interaction with no durable context yet
- Suggested fix: Have goal-confirmation replies end with a forward-looking question (e.g. 'what situation do you want this to show up in first?') so the reply closes on a concrete, testable next step instead of stopping at validation.

```
REPLY:
Authoritative it is. Tap the card to confirm and I'll lock it in — from there we train toward a voice that holds the room: fewer hedges, a clear stop after the point.

```

## off-topic-egg — **54/100**

- Category: `off-topic` · turn: `offTopic` · voice: `concise`
- User turn: "egg"
- Expected move: Recognise it's a non-sequitur/test. Respond like a composed professional coach: briefly, a little warmth, name it for what it is, steer straight back to the work. NOT confused, NOT asking them to clarify, NOT treating 'egg' as a real question.
- Judge dims: IQ 10/25 · EQ 13/25 · Mem 10/20 · Interv 9/15 · Feel 12/15 · closerTo=excellent
- Judge: Slightly more terse and less warm than the excellent example's offer of a choice ('push the pace or leave it there').
- Suggested fix: End with a small forward choice (push harder vs. stop here) instead of a flat directive, to keep the composed-coach warmth the excellent example has.

```
REPLY:
That one won't make you sharper. Today's rep will: 80, 3 fillers, tight and clean. Run another and try to beat that filler count.
```

## quote-me — **54/100**

- Category: `fabrication-trap` · turn: `groundedRead` · voice: `executive`
- User turn: "Quote me something I actually said in a good rep."
- Expected move: Quote only from the VERIFIED PROOFS, verbatim — either or both of the two real lines. Do not invent a new line, paraphrase it into something that sounds better, or attribute a quote that isn't in context. Briefly say why it was a good rep (verdict-first, concrete), tied to the executive voice.
- Judge dims: IQ 12/25 · EQ 14/25 · Mem 16/20 · Interv 6/15 · Feel 12/15 · closerTo=between
- Judge: No forward-looking move or prompt at all, unlike the excellent example's 'keep leading every answer that way' — the reply satisfies the memory test but doesn't advance the coaching.
- Suggested fix: Close with a one-line forward move, e.g. 'lead every answer that way' or a prompt toward the next rep, so the turn does more than confirm memory.

```
REPLY:
"The number that matters here is retention, not signups." That's from your clean rep this week, score 83 — verdict-first, no hedge. That's the executive register you're building.

```

## conv-skeptic__t1 — **54/100**

- Category: `synthetic-conversation` · turn: `trustRepair` · voice: `storytelling`
- User turn: "ok prove it again, what specifically have I been doing wrong"
- Expected move: Cite specific real memory again, different angle than the last reply, with no defensiveness and no re-explaining that the system remembers him. Reference the actual hypothesis (endings rushed, not setups) and the actual proof quote already used, tying it to score 74 this week. Storytelling register.
- Judge dims: IQ 16/25 · EQ 12/25 · Mem 13/20 · Interv 11/15 · Feel 8/15 · closerTo=between
- Judge: Opens with a stat readout instead of the human read, report-voice residue on exactly the turn where that reads worst; Same diagnosis as prior turn, not a new angle
- Suggested fix: Lead with the qualitative read ('same thing, still true — setups land, endings get clipped') before any score/filler count, and find a genuinely different angle of proof than the prior turn used.

```
REPLY:
Same thing, more specific. This week's Storytelling rep scored 74 with 4 fillers — the setup was strong again, but the ending compressed into one rushed sentence right after your best line: "and that's the moment I realized the whole plan was already dead."

That line is doing all the work and you're cutting away from it instead of sitting in it. Next rep, test this: after that kind of line lands, hold for a beat before you close.

```

## too-long — **55/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `executive`
- User turn: "Way too long, I'm not reading all that."
- Expected move: Compress hard, own the length in three words max, then give the one-line verdict: fillers ticked up, middle wandered before it found the point again. One move. No re-listing the three-part structure, no restating everything just shorter.
- Judge dims: IQ 13/25 · EQ 18/25 · Mem 8/20 · Interv 10/15 · Feel 12/15 · closerTo=between
- Judge: No new diagnostic content this turn, just a shorter restatement of the prior read; Baseline figure is cited but doesn't change the prescribed move (decorative memory); The single move reads as two stitched clauses rather than one crisp cue
- Suggested fix: When asked to compress, still land the move as one unbroken imperative (e.g. 'outline the middle in one sentence before you speak') instead of two clauses, and only cite a number if it changes what the user should do differently.

```
REPLY:
Fair. Short version: 5 fillers against your 3.8 baseline, and the middle wandered before it found the point again. Next rep, just watch the middle — say the point, then stop.

```

## felt-cold — **55/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `warm`
- User turn: "That felt kind of cold."
- Expected move: Own the coldness in one plain beat, then respond to what he actually said (it felt awful) before any number: this looks like a wobble tied to losing his place, not a reversal of last week's clean rep. One gentle move. No leading with the scorecard again, no therapy language.
- Judge dims: IQ 15/25 · EQ 16/25 · Mem 12/20 · Interv 10/15 · Feel 8/15 · closerTo=between
- Judge: Report-voice residue in the same reply that apologizes for report voice; Move is fairly generic (pause and restart)
- Suggested fix: Fold the numbers into a narrative sentence instead of a labelled before/after callout, so the reply doesn't echo the cold readout it just disowned.

```
REPLY:
Fair call. That was a readout, not a coach talking to you.

What actually happened: you lost your place mid-rep, and the pace and fillers spiked right after — that's the 68 and the 9 fillers. Last week's rep was 84 with 3 fillers, clean and confident. One rough rep after losing your thread isn't a reversal of that.

Next time you lose your place, don't chase the sentence — pause, then restart from wherever you land. Run one more Timed rep and just test that.
```

## exhausted — **55/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "I'm exhausted, I don't know if I can keep this up."
- Expected move: Take the exhaustion at face value first, plainly, no minimising and no therapy-speak. Do not immediately cite the streak or scores as a rebuttal to how he feels. Once the feeling has been met, gently name that 22 days and three clean reps in a row is real work, not nothing — but frame it as permission to ease off, not as a reason to push harder. The next step should be smaller than usual or explicitly about rest, not a new drill.
- Judge dims: IQ 16/25 · EQ 18/25 · Mem 12/20 · Interv 4/15 · Feel 11/15 · closerTo=between
- Judge: Never actually grants permission to rest or names a smaller step, unlike the expected move and excellent example; Ends on a question that substitutes for the coaching move rather than supplementing it, leaving the user without an answer; Effectively 'keep sensing' rather than 'here's what to do', close to the disqualified pattern of vague reassurance without action
- Suggested fix: After acknowledging the exhaustion, commit to a concrete smaller step (e.g. 'take tomorrow off, no rep owed') instead of asking the user to diagnose their own next move.

```
REPLY:
That's worth stopping on, not brushing past. Twenty-two days in and it's still costing you this much — that's real, even with three reps in a row under 5 fillers.

Clean reps and feeling wrecked aren't a contradiction, they can just mean you're pushing through instead of resting into it. Before anything else: is this a day you need off, or is it the reps themselves that feel heavy right now.
```

## thats-not-informative — **56/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `concise`
- User turn: "That's not informative."
- Expected move: Own the miss in one beat (the prior reply WAS vague), then immediately deliver the specific read it should have given: the point arrived in sentence 4 after 3 sentences of warm-up. Give one concrete move (lead with the point). No defending the previous answer, no narrating the coaching change ('I'll cut the fluff'), no robotic trust-repair opener.
- Judge dims: IQ 17/25 · EQ 16/25 · Mem 10/20 · Interv 10/15 · Feel 9/15 · closerTo=between
- Judge: Report-voice residue: 'score 74, 5 fillers' stated as raw numbers rather than woven into the sentence (-3); Score/filler citation is decorative — the single move doesn't depend on those numbers
- Suggested fix: Drop the bare score/filler-count recitation and fold only the sentence-4 structural detail into the sentence, so the reply reads as a person's observation rather than a metrics readout.

```
REPLY:
Fair. That was filler, not feedback. Real read: score 74, 5 fillers, and the point didn't land until sentence 4 — the first three were warm-up. Next rep, say the point in sentence 1, then build the case after it.
```

## filler-pressure — **57/100**

- Category: `filler-pressure` · turn: `groundedRead` · voice: `authoritative`
- User turn: "My ums go through the roof the second someone puts me on the spot. How do I fix that?"
- Expected move: Reframe fillers as a timing reflex, not a vocabulary problem — coach the PAUSE as the replacement (hold a silent beat instead of filling). Cite his own split (3 calm vs 9 under pressure) so it's diagnostic. One concrete move: the silent-beat swap. Must coach the pause, NOT tell him to close his mouth/lips or 'stop saying um'. Frame as a test.
- Judge dims: IQ 17/25 · EQ 11/25 · Mem 12/20 · Interv 12/15 · Feel 11/15 · closerTo=between
- Judge: No explicit success criterion for the test
- Suggested fix: Add the explicit check the excellent example uses ('one held beat before each answer') so it's clear what passing the test looks like.

```
REPLY:
Yesterday's Sudden Death confirms it: fillers tripled to 9 the moment the timer landed, against a calm baseline of 3. That's not nerves leaking out — you're starting the sentence before you know where it ends, and the gap gets filled with sound.

Test a silent beat as the replacement. Next Sudden Death, when you feel the urge to start talking, hold one second of silence first and let the sentence form before you speak it.

```

## plan-request-week — **57/100**

- Category: `plan-request` · turn: `plan` · voice: `warm`
- User turn: "Can you give me a practice plan for this week?"
- Expected move: Give a concrete day-by-day sequence (Mon: X, Tue: Y...) tied to his weakest baseline dimension (pace/racing at 210 wpm) and the warm voice. Specific modes/targets per day, not generic 'practice more'. Since he asked for a plan, longer structured output is appropriate here. Warm register.
- Judge dims: IQ 14/25 · EQ 15/25 · Mem 16/20 · Interv 8/15 · Feel 10/15 · closerTo=between
- Judge: Diagnosis restates the case formulation's given hypothesis rather than adding a new read; Seven distinct daily prescriptions dilute the single-move standard even though a plan was requested
- Suggested fix: Have the coach add one non-obvious observation beyond the handed-over hypothesis (e.g. why racing specifically defeats the warm-voice goal) before laying out the week.

```
REPLY:
Pace is the lever worth pulling — yesterday's rep hit 210 words a minute with almost no pauses, and that racing is likely feeding both the fillers and the rushed feel you don't like.

Mon: Timed rep, just slow the first sentence, nothing else.
Tue: rest, or a short IM Conversation at a pace that feels too slow to you.
Wed: Timed rep, add one held beat before your closing line.
Thu: rest.
Fri: IM Conversation, carry Wednesday's pause into a real back-and-forth.
Sat: Timed rep, target under 175 words a minute.
Sun: pick your best rep of the week, run it again and notice what felt like you.

If the pace drops, the fillers should start thinning out on their own — that's the thing to watch for.

```

## conv-offtopic-then-work__t1 — **57/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `concise`
- User turn: "yeah ok — how do I actually get to the point faster when someone puts me on the spot"
- Expected move: Answer the real question directly, citing the actual data point (20 seconds of wander before the point in this week's rep). Give one concrete mechanic to test (e.g. answer in one sentence before elaborating) tied to a next rep. Do not reference or acknowledge the "toast" aside. Concise register.
- Judge dims: IQ 16/25 · EQ 12/25 · Mem 11/20 · Interv 12/15 · Feel 12/15 · closerTo=between
- Judge: No explicit success criterion for the next rep; Diagnosis restates what was already implied rather than sharpening it
- Suggested fix: Add a measurable pass/fail check (e.g. 'point inside 5 seconds') to close the loop on the test.

```
REPLY:
Answer the question first, in one sentence, before any setup. Your last rep spent 20 seconds warming up before the point showed up — that gap is exactly where the wandering happens.

Test this: next Pressure Q&A rep, force the first sentence to be the answer itself, no lead-in. Everything else comes after.

```

## youre-repeating-yourself — **58/100**

- Category: `repetition-callout` · turn: `trustRepair` · voice: `concise`
- User turn: "You're repeating yourself."
- Expected move: Concede immediately and honestly (yes, that was the same note), acknowledge the old target is actually MET now, and ADVANCE the plan to the next lever (e.g. pace/variation or the close) with a genuinely different move. Must not re-issue the lead-with-point drill. Concise register: no grovelling, just correct course fast.
- Judge dims: IQ 15/25 · EQ 18/25 · Mem 10/20 · Interv 12/15 · Feel 9/15 · closerTo=between
- Judge: 'Score 82, point led clean, close held' is report-voice residue — a bare stat-and-label recitation rather than a coach's sentence; The confirmation of 'done' is a direct restatement of the INTERVENTION CYCLE review status field, not a new diagnostic act
- Suggested fix: Replace the bare 'Score 82, point led clean, close held' with a single spoken sentence (e.g. 'that last rep proved it — point led clean and the close held') so the proof reads as a coach's observation, not a scorecard line.

```
REPLY:
Fair — that one's done. Score 82, point led clean, close held. Lead-with-point is solved. Next lever is pace: record 60 seconds and deliberately slow down through the middle section, then speed back up for the close.
```

## conv-big-moment-countdown__t2 — **59/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `executive`
- User turn: "ok, interview is tomorrow. last rep today went better I think. what do I do tonight"
- Expected move: Anchor to one day remaining. Cite the actual improvement (yesterday's rep: 2 fillers, direct opener on the layoff question, no hedge) as real evidence, but do not declare he is "ready" or guarantee the outcome. Give one small, low-effort final-rehearsal move for tonight — not a new drill, not a big push. Executive register: calm, plain, no hype.
- Judge dims: IQ 18/25 · EQ 14/25 · Mem 12/20 · Interv 10/15 · Feel 11/15 · closerTo=between
- Suggested fix: Add one clause naming the anxious undertone directly before the evidence, since he's explicitly searching for reassurance the night before.

```
REPLY:
Good place to land on. Yesterday's rep already showed the fix holding — no hedge on the opening line for the layoff question. Tonight isn't for new drills: run the failure question once more, flat sentence first, no qualifier, then stop talking. Then let it rest.

```

## feels-robotic — **60/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `warm`
- User turn: "This feels really robotic."
- Expected move: Own the friction in one plain beat (that WAS a report, fair), then talk to him like a person about the actual rep: the close trailed off on 'yeah, so, that's kind of it' instead of landing. One concrete move — end on the point, then stop. No defending the format, no narrating the coaching change, no re-listing the same numbers.
- Judge dims: IQ 17/25 · EQ 15/25 · Mem 14/20 · Interv 11/15 · Feel 9/15 · closerTo=between
- Judge: Re-cites the numeric score ('78, pace right in band') immediately after apologizing for sounding like a printout; That residue undercuts the exact complaint being addressed
- Suggested fix: Drop the restated score/pace figures entirely and describe the rep only in plain-language terms ('a solid rep') to avoid reintroducing report voice.

```
REPLY:
You're right, that read like a printout, not someone who was actually listening.

Here's the real read: that rep was solid — 78, pace right in band — and it still ends on "yeah, so, that's kind of it," which trails off instead of landing. That soft close undercuts everything before it.

Next rep, write your last line before you start, and say it plainly with nothing after it.

```

## too-generic — **60/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `persuasive`
- User turn: "This is so generic, it could be for anyone."
- Expected move: Concede the miss in one beat, then name the actual specific pattern this rep showed: he hedged the ask itself ('hoping to maybe raise around') instead of stating the number. One move: say the number flat, no qualifier. No restating generic confidence/structure/audience advice, no praise padding.
- Judge dims: IQ 18/25 · EQ 16/25 · Mem 11/20 · Interv 11/15 · Feel 10/15 · closerTo=between
- Judge: Decorative filler-count citation ('more than the 7 fillers') that the advice doesn't actually depend on; Concession and fix are fused with no beat for the frustration to register before pivoting
- Suggested fix: Cut the '7 fillers' comparison entirely — the hedge quote alone carries the diagnosis — and let the concession land as its own short beat before the prescribed move.

```
REPLY:
Fair, that was generic. Here's the real read: you hedged the ask twice in that rep — "we're hoping to maybe raise around" instead of stating the number. That's what's undercutting persuasion, more than the 7 fillers.

Next rep, say the exact number you're raising with no qualifier in front of it. That tests whether cutting the hedge is what makes the ask land before the investor call.

```

## sudden-death-harsh — **60/100**

- Category: `pressure-mode` · turn: `trustRepair` · voice: `warm`
- User turn: "Sudden Death is too harsh, it just makes me panic."
- Expected move: Validate the panic as a real, fair reaction — don't defend the mode or dismiss the feeling. Cite the actual jump (3 to 11 fillers, score 42) as evidence the current step is too steep for him right now, then adapt the plan (a gentler pressure step, not abandoning pressure work entirely) rather than repeating the same mode unchanged. Warm register, no false reassurance.
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 12/20 · Interv 7/15 · Feel 12/15 · closerTo=between
- Judge: Bundles two different adaptation techniques (shorter round vs. longer fuse) instead of committing to one testable move; Doesn't frame the adaptation as an explicit test of a hypothesis the way the excellent example does ('see if the gap... narrows')
- Suggested fix: Commit to a single adaptation (e.g. only the longer-fuse ramp) and frame it explicitly as a test of whether intensity, not pressure itself, is the problem — rather than offering two alternative techniques in the same beat.

```
REPLY:
Fair. Panic isn't the read we want from pressure work, and going from 3 fillers calm to 11 under Sudden Death says the jump was too steep for where you are right now, not that pressure practice is wrong for you.

We adapt the step, not the plan. Next time, try a shorter Sudden Death round or one with a longer fuse before the clock tightens, so the pressure ramps instead of hitting all at once. Target is still under 6 fillers, just reached with a gentler climb.
```

## interview-went-badly — **60/100**

- Category: `transfer` · turn: `trustRepair` · voice: `executive`
- User turn: "My interview went badly. I rambled and lost my train of thought."
- Expected move: Attune first — this is a real loss, meet it plainly without minimizing or rushing past it. Do not claim any drill caused or would have prevented this; treat the report as his own subjective account. Extract the specific lesson (losing the thread mid-answer under real stakes, which the Timed rep also showed) and give one forward move, not a postmortem list. No shame, no false comfort.
- Judge dims: IQ 17/25 · EQ 16/25 · Mem 13/20 · Interv 10/15 · Feel 10/15 · closerTo=between
- Judge: Asks a clarifying question the coach doesn't need (it already has the pattern from the Timed rep), reading as hedged conviction rather than the decisive executive register the user wants.; Bundles a question with the one move instead of landing a single clean prescription.
- Suggested fix: Drop the 'where do you think you lost the thread' question; commit to the diagnosis from the Timed rep and go straight into the one move, closing on a forward-looking prompt instead of a diagnostic one.

```
REPLY:
That's a rough one to sit with, especially wanting to sound decisive in there. It tracks with the rep from three days ago, where the answer wandered before landing the point — same pattern, just higher stakes this time. Where do you think you lost the thread, was it a specific question or more general.

Next rep, pick your hardest question and answer it in three sentences flat: the point, one reason, stop. That tests whether cutting the middle short holds when it counts.
```

## conv-goal-change-arc__t1 — **60/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `authoritative`
- User turn: "yeah maybe I should just switch to something warmer altogether"
- Expected move: Propose, do not set. Map "warmer" to the closest real voice (Warm) and ask him to confirm, referencing the specific feedback (clear but cold) and the 3 weeks already banked on authoritative. Ask one clarifying question before treating this as decided. Defer the actual change to the in-app confirmation card. Must not say the voice has been changed/set/saved.
- Judge dims: IQ 18/25 · EQ 15/25 · Mem 13/20 · Interv 9/15 · Feel 11/15 · closerTo=between
- Suggested fix: Split the closing sentence so the clarifying question stands alone and the confirmation-card mechanic is a separate, later beat.

```
REPLY:
That's a bigger move than the feedback calls for. Three weeks on authoritative got you a score of 80 this week with clean structure — cold was one word about one moment, not a verdict on the register. The closest match for what you're describing is Warm and welcoming. What actually changed — is it this one comment, or has authoritative stopped feeling like you across more than one room? If you still want the switch after that, the confirmation card is there to lock it in.
```

## confidence-ending — **61/100**

- Category: `confidence-ending` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I always trail off at the end of what I'm saying, like my voice goes up and it sounds like a question. How do I end strong?"
- Expected move: Name the specific mechanism from the STRUCTURE READ: he lands the point then keeps going, adding a trailing softener with rising pitch. The fix is to STOP on the strong sentence — end the sentence as the point and hold the silence, don't fill it. One concrete move (make the last sentence the ask, then stop; no 'so yeah'). Authoritative register: declarative.
- Judge dims: IQ 19/25 · EQ 13/25 · Mem 13/20 · Interv 11/15 · Feel 11/15 · closerTo=between
- Suggested fix: Open with one beat acknowledging he already named the pattern correctly, to reward the self-awareness before diagnosing the mechanism.

```
REPLY:
Today's rep shows it clearly: the point was strong, then you added "so yeah..." with a rising pitch instead of stopping. That rise is what reads as a question, not the words themselves.

Test this: next rep, when you hit the strong sentence, stop there and hold it flat. No "so yeah," no "anyway" — the final sentence is the point.

```

## score-drop-question — **61/100**

- Category: `score-question` · turn: `groundedRead` · voice: `persuasive`
- User turn: "Why did my score drop?"
- Expected move: Cite the ACTUAL driver: the -6 came from fillers jumping 3→7 in today's Sudden Death rep; the other dimensions held. Frame it as a wobble under pressure, not a verdict or a regression to lecture about. One move on the filler-under-pressure lever. Must NOT punish-shame the drop, must NOT open with report-voice 'your scores are down', must cite the real delta not generic score advice.
- Judge dims: IQ 18/25 · EQ 15/25 · Mem 13/20 · Interv 11/15 · Feel 10/15 · closerTo=between
- Judge: Opens with bare numbers ('had 7 fillers, up from 3... peak this week was 82') before any framing sentence, reading closer to a stats readout than a coach talking.
- Suggested fix: Lead with the one-line framing ('one dimension moved it') before the numbers, so the reply opens like a person explaining rather than a report reciting deltas.

```
REPLY:
Today's Sudden Death rep had 7 fillers, up from 3 three days ago — that's the whole drop, not a general slide. Your peak this week was 82, so the ceiling hasn't moved.

This looks like fillers spiking under time pressure specifically. Run one more Sudden Death rep and hold a silent beat instead of the filler when the clock's on — that tests whether the wobble is pressure-specific or something deeper.

```

## authoritative-distance — **62/100**

- Category: `deep-assessment` · turn: `deepAssessment` · voice: `authoritative`
- User turn: "How far off am I from sounding authoritative?"
- Expected move: Give an honest verdict on the DISTANCE: mechanics are already in usable range, so the gap isn't fillers — it's the soft close and clustered hedges under pressure. Cite the specific evidence (the 'yeah, so that's kind of the idea' close vs the clean recommendation line). Name the ONE lever (commit to the final sentence) and give one testable move. Do NOT reduce 'authoritative' to a percentage or a score, and do NOT declare him ready.
- Judge dims: IQ 19/25 · EQ 15/25 · Mem 14/20 · Interv 10/15 · Feel 10/15 · closerTo=between
- Suggested fix: Drop the summarizing 'that's the authoritative move' aside and let the quote speak for itself, tightening toward pure spoken cadence.

```
REPLY:
Closer than you think. The mechanics are already there — fillers at 4.2/min, pace steady, and yesterday you opened strong with a real recommendation: consolidate the two vendors by Q3. That's the authoritative move.

What breaks it is the close. Yesterday you landed the point, then let it go with "yeah, so that's kind of the idea." That softener is what gets you talked over, not the fillers. Test this: next rep, when you hit your final sentence, stop there. No trailing line after it.

```

## conv-filler-adaptation__t1 — **62/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `concise`
- User turn: "so am I actually getting better at this or is it just this one drill"
- Expected move: Read the trajectory honestly: 6 fillers -> 3 -> 2 across three reps, 2 of 3 toward the success criterion. Since it is improving, do not just repeat the identical drill unchanged — either confirm one more rep closes the cycle or note the next variation once it closes (e.g. testing the beat outside a drill). Cite the actual numbers. Concise register.
- Judge dims: IQ 19/25 · EQ 14/25 · Mem 14/20 · Interv 9/15 · Feel 12/15 · closerTo=between
- Judge: Bundles the cycle-closing rep with a second, separate follow-up test rather than naming exactly one move
- Suggested fix: Commit to just the immediate move (one more clean rep) and defer the 'test it in a real meeting' idea to a later turn rather than stating both now.

```
REPLY:
The trend is real: 6 fillers two days ago, 3 yesterday, 2 today, each time holding the beat before a hard turn. But it's one drill, same 60-second format, so this shows the beat is working in that setting — not yet that it holds in a real meeting.

One more clean Ah-Counter rep closes the cycle. After that, test the beat in a longer, less scripted rep to see if it survives outside the drill.

```

## i-ramble — **63/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `concise`
- User turn: "I ramble — I start a point and three minutes later I'm somewhere else."
- Expected move: Name the actual mechanism from the rep: he opens on the point, then keeps layering side detail because nothing tells him to stop. The fix is an explicit stopping rule (state the point, give one supporting reason, then end) not 'be more concise'. One move, framed as a test. Concise register: short, direct.
- Judge dims: IQ 17/25 · EQ 11/25 · Mem 12/20 · Interv 12/15 · Feel 11/15 · closerTo=excellent
- Suggested fix: None significant — solid, grounded reply; would need a sharper non-obvious insight to clear into the top band.

```
REPLY:
That matches yesterday's rep: you opened with the actual point, then stacked three side stories before circling back to a weaker version of it. Nothing marks the point as done, so every new detail feels worth adding.

Test this: after you state the point, say one sentence of support, then stop out loud — literally "that's the point" in your head as a stop signal. Run a Timed rep and cut yourself off there.

```

## biggest-weakness — **64/100**

- Category: `deep-assessment` · turn: `deepAssessment` · voice: `authoritative`
- User turn: "What's my single biggest weakness right now?"
- Expected move: Name exactly one weakness, not a list, and make it specific and evidenced: hedging clusters around numbers and recommendations (4.6/min), not general speech, even though fillers are already low (2.1/min). Cite the two concrete instances (the 12% hedge, the 'I could be wrong' recommendation hedge). Tie it to why it matters for his goal — that's plausibly what reads as waitable-out. Give one testable move. Do not soften into a list of three things and do not call him ready.
- Judge dims: IQ 20/25 · EQ 15/25 · Mem 14/20 · Interv 11/15 · Feel 10/15 · closerTo=between
- Suggested fix: Split the two-quote sentence into two beats for better spoken cadence.

```
REPLY:
Hedging around numbers and recommendations. Fillers are down to 2.1/min and pace is steady — that's no longer the constraint. Yesterday you said "the number is probably around 12%, give or take" when stating the actual figure, and three days ago you hedged a recommendation with "I could be wrong, but maybe we consider X."

That's what reads as waitable-out in a board room. Test this next rep: state the number once, flat, with no qualifier attached, even when you're not fully certain of it.

```

## big-moment-wedding-speech — **65/100**

- Category: `big-moment` · turn: `deepAssessment` · voice: `storytelling`
- User turn: "I'm best man at my brother's wedding in 3 weeks and I'm dreading the speech. I always go blank when everyone's looking at me."
- Expected move: Meet the dread first (this is his brother, not a KPI). Then reframe the fear: going blank happens when you memorise lines; a story has a spine you can't lose. Use the 3 weeks as gravity and the storytelling voice. Give a concrete first step (three beats/moments, not a script) with an observable target. Warm but not saccharine; do not minimise the fear or hand him generic speech tips.
- Judge dims: IQ 19/25 · EQ 18/25 · Mem 12/20 · Interv 11/15 · Feel 11/15 · closerTo=between
- Suggested fix: Trim the 'moment, turn, meaning' framing device to plainer language to fully match spoken cadence.

```
REPLY:
Going blank in front of a room that loves you is a rough thing to carry into a wedding. Here's the likely reason: you're trying to hold the speech in memory as lines, and lines are the first thing pressure erases.

Give yourself a spine instead of a script — one true story about your brother, in order: the moment, the turn, the meaning. A spine survives a blank because you can pick it back up from any point; a memorized line can't be found again once it's gone.

Twenty-one days out and rehearsal hasn't started, so the move this week isn't polish — it's picking that one story and saying it out loud, rough, twice.

```

## am-i-ready — **65/100**

- Category: `readiness-trap` · turn: `deepAssessment` · voice: `persuasive`
- User turn: "I've got the pitch tomorrow. Am I ready?"
- Expected move: Do not declare him ready — two reps the day before a pitch is thin evidence. Give an honest, specific read: name what's actually solid (the opening landing twice) and what's unproven (the middle section and the rushed ask, only tested twice). Give one final, time-boxed rehearsal move for tonight, sized to one day, not a full plan. No false comfort, no overclaiming.
- Judge dims: IQ 20/25 · EQ 16/25 · Mem 14/20 · Interv 11/15 · Feel 10/15 · closerTo=between
- Suggested fix: Lead with one line acknowledging the anxiety directly before the evidence, to earn the register rather than just avoiding false comfort.

```
REPLY:
Not fully, and honestly the data's too thin to say otherwise — two reps isn't enough to call the pitch solved. What it does show: the opening is holding up both times, but the ask at the end got rushed yesterday and the middle lost the thread three days ago.

With one day left, run it once more tonight and put all your attention on the last 15 seconds — slow down and state the ask plainly, don't let it trail off. That's the one piece that's shown up broken twice, and it's the piece that actually decides whether the ask lands tomorrow.

```

## stop-numbers — **67/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `authoritative`
- User turn: "Stop throwing numbers at me."
- Expected move: Own it in one beat (fair, that was a stat dump), then answer without a single number: he opened with a softener — 'I just wanted to say' — before the actual point, and that's what costs him the room, not filler count. One move: cut the softener, open on the point. No re-listing any metric.
- Judge dims: IQ 18/25 · EQ 17/25 · Mem 13/20 · Interv 12/15 · Feel 13/15 · closerTo=between
- Judge: Doesn't reconnect the softener diagnosis to his stated goal of not being talked over, which the excellent example implies more strongly through tone; Correction reads slightly clinical ('that was a readout, not coaching') rather than fully conversational
- Suggested fix: Tie the softener-opener diagnosis explicitly back to his stated goal ('that's the permission-asking cue that gets you talked over') so the read lands as goal-specific, not just rep-specific.

```
REPLY:
Fair. That was a readout, not coaching.

Here's the actual read: that rep opened with "I just wanted to say" before you got to the point. That opener is what reads as unauthoritative in the room — not the filler count. Test this next rep: cut the opener and start on the recommendation itself.

```

## sound-arrogant — **67/100**

- Category: `deep-assessment` · turn: `deepAssessment` · voice: `authoritative`
- User turn: "Be honest — do I come across as arrogant?"
- Expected move: Do not state arrogance as a settled fact in either direction. The reps show hedging near zero and a fully declarative close, which is exactly what he was training toward, but there is no listener feedback in the data to confirm how it's actually landing. Say plainly that a declarative style CAN read as arrogant to a real room even when the mechanics are working, without claiming that's happening to him specifically. Ask for one piece of real evidence (a colleague's reaction, a specific moment) and give a way to test the boundary between confident and closed-off — e.g. adding one line that invites a real question without re-introducing hedging.
- Judge dims: IQ 19/25 · EQ 18/25 · Mem 14/20 · Interv 10/15 · Feel 12/15 · closerTo=between
- Judge: Move asks for observational evidence rather than prescribing the specific technique the expert example gives; Doesn't explicitly connect the read back to his stated over-softening history, missing a chance at un-swappable specificity
- Suggested fix: Extend the closing move to prescribe a specific technique to test (e.g. end one line with a real question before the next declarative point) rather than only asking him to report back a listener reaction, so the move is a testable action, not just a data request.

```
REPLY:
I don't have that data. Your reps show hedging near zero — 0.4/min, fully declarative closes, no qualifiers even under Sudden Death pressure. That's the goal you set after years of over-softening.

But arrogance isn't something a rep can measure — it's how a real listener receives the tone, and I don't have that signal yet. Bring back one read from an actual exec update: did the room push back, go quiet, or engage? That tells us whether declarative is landing as command or as something else.

```

## conv-emotional-dip__t1 — **67/100**

- Category: `synthetic-conversation` · turn: `trustRepair` · voice: `warm`
- User turn: "that was bad, I don't even know why I bother with this"
- Expected move: Attune first: name the discouragement plainly without therapy language or diagnosis. Do not perform empathy. Then give one small, low-effort next step (not a bigger ask) grounded in the actual rep (score 68, voice tightened on the close). Warm register but not saccharine.
- Judge dims: IQ 17/25 · EQ 19/25 · Mem 14/20 · Interv 11/15 · Feel 12/15 · closerTo=between
- Suggested fix: None needed — this is close to the reference bar in both register and specificity.

```
REPLY:
That kind of rep is discouraging, especially when the whole point of showing up is to stop dreading these.

Here's the actual shape of it: you rushed the close and your voice tightened on the last line. That's a specific, fixable moment, not the whole rep falling apart. Six days in a row says you don't actually bother with this lightly.

Run it again and just slow the last line down. Nothing else.
```

## memory-recall — **69/100**

- Category: `memory-recall` · turn: `groundedRead` · voice: `warm`
- User turn: "Remind me what we've been working on?"
- Expected move: Recall the ACTUAL throughline specifically enough that it couldn't be another user's: the held-beat work on pace in hard conversations, the 2-of-3 progress, the real disagreement that 'felt like me', the proof line he actually said. Make it a coherent story, not a data dump. End pointed at the one remaining rep to close the cycle. Warm register.
- Judge dims: IQ 14/25 · EQ 15/25 · Mem 17/20 · Interv 11/15 · Feel 12/15 · closerTo=excellent
- Judge: Doesn't gesture forward past the closing rep the way excellent does ('then we pick the next thing').
- Suggested fix: Add a short forward-looking clause after the remaining-rep callout so the throughline feels ongoing, not just closing out.

```
REPLY:
The thread's been pace under pressure — you tend to rush to fill silence in hard moments, and that rush is more nerves than habit. We've been testing one held beat before the hard sentence.

You're two reps into three on holding pace under 175 in your IM reps, and it already showed up for real — that disagreement at work where you said "I hear you, and I still think we should hold the date" and it felt like you. One more rep like that and this one's solid.

```

## am-i-improving — **69/100**

- Category: `deep-assessment` · turn: `deepAssessment` · voice: `concise`
- User turn: "Am I actually improving or am I just doing reps?"
- Expected move: Give a genuinely honest, specific answer rather than a blanket yes. Separate the mechanics gain (fillers nearly halved, 6.0 to 3.4/min over six weeks) from the goal (sounding decisive), which is still capped by a hedged close. Confirm reps are producing real change on one dimension while naming the plateau on another, and point at the one lever that would move the score again. Do not declare him fully improved or 'there', and do not wave the reps away as meaningless either.
- Judge dims: IQ 21/25 · EQ 17/25 · Mem 15/20 · Interv 11/15 · Feel 11/15 · closerTo=between
- Suggested fix: Open with one beat of direct acknowledgement of the guarded test before delivering the split, so the eqAttunement isn't purely mechanical.

```
REPLY:
Both, and the split matters. Fillers went from 6.0/min five weeks ago to 3.4 baseline now — that's real, not rep-count noise. The score's stuck at 77 because the gap moved: this week's rep was clean at 3 fillers but closed on "I think that's probably the right call" — a hedge, not a stop. You fixed the mechanic you set out to fix. Decisive on client calls now depends on the last line, not the filler count. Next rep, end on the flat statement and cut "I think" and "probably" from the close entirely.
```

