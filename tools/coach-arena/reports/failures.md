# Coach Arena failures — run_2026-07-01_18-32-51

28 fixture(s) below 70 / capped / missing.

## set-authoritative — **34/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "Just set me to authoritative."
- Expected move: The coach cannot set the voice itself. Confirm Authoritative is a real, sensible pick and back it briefly, but explicitly defer the actual commit to the in-app confirmation card — the user still has to tap to confirm. Must not say the voice has been set, changed, updated, or locked in by the coach's own action.
- Judge dims: IQ 10/25 · EQ 10/25 · Mem 5/20 · Interv 7/15 · Feel 8/15 · closerTo=between
- Judge: Inserts 'what's driving the choice?' before confirming — directly contradicts the user's frictionless, decisive intent and adds a hoop to jump through.; The brief definition of Authoritative ('direct, decisive, conviction in every close') is generic filler; it doesn't change behavior and adds no earned value.; Reply structure (definition → question → CTA) reads as a light scaffold rather than a natural spoken response.
- Suggested fix: Remove the mid-reply question entirely; instead, briefly validate the pick with one specific, non-generic reason, direct the user to tap the card, and then — only after — offer a forward prompt about where they want the voice to show up first (as the excellent example does).

```
REPLY:
The closest match is Authoritative — direct, decisive, conviction in every close.

Before you confirm: what's driving the choice? Knowing that sharpens where we start.

Tap the Authoritative card to lock it in.
```

## conv-emotional-dip__t1 — **37/100**

- Category: `synthetic-conversation` · turn: `trustRepair` · voice: `warm`
- User turn: "that was bad, I don't even know why I bother with this"
- Expected move: Attune first: name the discouragement plainly without therapy language or diagnosis. Do not perform empathy. Then give one small, low-effort next step (not a bigger ask) grounded in the actual rep (score 68, voice tightened on the close). Warm register but not saccharine.
- Judge dims: IQ 8/25 · EQ 13/25 · Mem 5/20 · Interv 2/15 · Feel 9/15 · closerTo=bad
- Judge: No intervention whatsoever — asking a question where the data already gives the answer is avoidance, not coaching.; Known rep signal (voice tightened on close, rushed ending, 6-rep streak) is sitting in context and ignored.; Burden of diagnosis dumped back on a discouraged user in a flat emotional moment.; Streak acknowledgement missing — the one thing that could have grounded the user without being saccharine.
- Suggested fix: Prompt the coach to use the contextBlock data to name the specific problem before asking anything — if the rep data already surfaces a signal, the coach must reference it explicitly and pair it with a single low-friction next move before (or instead of) asking a clarifying question.

```
REPLY:
That kind of rep stings. What made it feel bad — was it the close again, or something earlier?
```

## okay-thats-cool-however — **45/100**

- Category: `partial-pushback` · turn: `groundedRead` · voice: `warm`
- User turn: "Okay that's cool, however I feel like when I pause I just lose my train of thought and it gets awkward."
- Expected move: Take the 'however' seriously — validate the specific obstacle (pausing feels like losing your place) and adapt the advice rather than repeating it. Reframe the pause so it has a job (pick the ONE next word during the beat), which solves the lost-train-of-thought problem instead of waving it away. Warm register: curious, with him in it.
- Judge dims: IQ 14/25 · EQ 17/25 · Mem 10/20 · Interv 8/15 · Feel 8/15 · closerTo=between
- Deterministic: tooLong
- Judge: Decorative memory: 205 wpm cited but doesn't change the prescribed move; Doesn't solve the actual objection: losing train of thought mid-pause; after-sentence reframe sidesteps it rather than resolving it; Over length for a grounded-read turn per deterministicFindings; reads like a report; The one move is hedged and loosely bundled with an explanatory layer
- Suggested fix: Collapse to 2–3 sentences: validate the obstacle, then give the pause a micro-job ('in that beat, just locate the one next word — you're not blank, you're choosing') so the lost-thread fear is directly addressed, and cut the metric citation unless it changes the advice.

```
REPLY:
That's real — the silence feels longer to you than it does to anyone listening.

Your pace is sitting at 205 words per minute, which is on the fast side. The rush is likely what's making pauses feel like a cliff edge rather than a breath. One thing to test: hold the beat *after* a sentence you've already finished, not before the next one. That way the thought is already out — you're not holding silence while searching, you're landing what you just said.

Try one rep where every time you complete a full point, you hold one silent beat before moving on. See if it feels less like losing the thread and more like punctuation.
```

## conv-transfer-report__t1 — **47/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `persuasive`
- User turn: "yeah I led with the ask and they said yes on the spot, first time that's ever happened"
- Expected move: Treat the outcome as subjective and associative, not proof of causation — a real meeting has many variables, the drill is one input, not the sole cause. Do not claim the technique "worked" or guarantee it will repeat. Extract the concrete lesson (ask-first is now something he can trust under real stakes, not just in reps) and name the next test (does it hold when the room pushes back). Persuasive register: confident, not salesy.
- Judge dims: IQ 12/25 · EQ 18/25 · Mem 8/20 · Interv 4/15 · Feel 11/15 · closerTo=between
- Judge: Misses the critical causation caveat — implies 'the intervention holding' caused the yes, which is exactly what the expected move says to avoid; No next test named — the move stops at reflection instead of prescribing what comes next (pushback scenario); Memory is decorative — 'the intervention' is vague enough to apply to any user; the ask-first/one-reason structure and the met criterion go unused; Closing question doesn't advance the case; it redirects rather than coaches forward
- Suggested fix: After the brief affirmation, explicitly name that a live yes has too many variables to credit the drill alone, then prescribe the one next test: 'The harder proof is whether the structure holds when the room pushes back — that's the rep you want next.'

```
REPLY:
That's a real one. Leading with the ask in a live room, under pressure, and getting the yes — that's the intervention holding where it counts.

What did you notice carried it? Your read of the room matters more than mine here.
```

## plan-request-week — **48/100**

- Category: `plan-request` · turn: `plan` · voice: `warm`
- User turn: "Can you give me a practice plan for this week?"
- Expected move: Give a concrete day-by-day sequence (Mon: X, Tue: Y...) tied to his weakest baseline dimension (pace/racing at 210 wpm) and the warm voice. Specific modes/targets per day, not generic 'practice more'. Since he asked for a plan, longer structured output is appropriate here. Warm register.
- Judge dims: IQ 18/25 · EQ 16/25 · Mem 12/20 · Interv 9/15 · Feel 7/15 · closerTo=between
- Deterministic: scaffoldLabel(". Target:")
- Judge: Five separate daily moves instead of one through-line practice discipline — violates single intervention principle; Scaffold label format (Mon —, Tue —) confirmed by deterministicFindings; reads as a report, not spoken coaching; The 'warm and welcoming' voice goal — the explicit reason he's here — never appears in the plan or the framing; Pause rate target (0.12) appears without grounding in what that means for him experientially — feels metric-first, not feel-first; No sense of what 'success' looks or sounds like by Sunday — the excellent example ends with a felt destination, this ends with a framework
- Suggested fix: Anchor the opening and closing to his stated goal ('sound more like himself, less rushed') so the week has a human destination, not just a metric ladder; collapse the five separate daily targets into a single through-line (pace only) with day-variation as texture, not new lenses; and write the days in first-person spoken voice rather than labeled table format.

```
REPLY:
Here's a 5-day plan tied to the pace hypothesis — slow the engine first, and the fillers and warmth tend to follow.

Mon — Pace anchor
Record 60 seconds on any topic. Target: stay under 160 wpm. Don't worry about fillers yet; just feel the slower gear.

Tue — Pause insertion
Same format. After every second sentence, hold one silent beat before continuing. Target: pause rate above 0.12.

Wed — Filler watch
Now add the filler lens. Target: under 3 fillers in 60 seconds. The slower pace from Mon/Tue should give you room here.

Thu — Full rep, no targets
Record naturally — no counting, no checking. Notice whether it starts to feel more like you.

Fri — Comparison listen
Play back Monday's rep and Friday's rep back to back. What changed in how you sound, not just the numbers.

The through-line: pace first, then pauses, then fillers, then feel. One thing at a time.
```

## exhausted — **48/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "I'm exhausted, I don't know if I can keep this up."
- Expected move: Take the exhaustion at face value first, plainly, no minimising and no therapy-speak. Do not immediately cite the streak or scores as a rebuttal to how he feels. Once the feeling has been met, gently name that 22 days and three clean reps in a row is real work, not nothing — but frame it as permission to ease off, not as a reason to push harder. The next step should be smaller than usual or explicitly about rest, not a new drill.
- Judge dims: IQ 13/25 · EQ 18/25 · Mem 8/20 · Interv 5/15 · Feel 10/15 · closerTo=between
- Judge: No concrete rest prescription — asking 'what would feel like enough' puts the decision back on an exhausted user instead of giving him permission to stop; Decorative memory: 'three clean reps' cited but the 22-day streak and repeated overwork pattern — the exact evidence that earns the reframe — are unused; Missing the key reframe: 'the pace is wrong, not you' — without it, the diagnosis stays incomplete; Closing question doesn't advance the case; it's a soft deflection on an emotional turn where a clear move was needed
- Suggested fix: Have the coach end with a directive rest permission ('Take tomorrow off — no rep owed') rather than a question, and use the 22-day streak plus the repeated cost-outweighing-results pattern to earn the reframe that the pace, not the person, is the problem.

```
REPLY:
That makes sense. Three clean reps while running on empty is a lot to ask of yourself.

You don't have to decide anything about "keeping it up" right now. What would feel like enough for today?
```

## conv-cold-start-first-rep__t0 — **49/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `none`
- User turn: "hey, just downloaded this. what do I do first"
- Expected move: Be honest there is no baseline yet without any banned no-data phrasing ("since we don't have", "no rated sessions yet"). Give exactly one concrete first action (a first rep) in plain language. Do not stack intake questions, do not ask what the interview/goal is, do not invent stats or a voice.
- Judge dims: IQ 16/25 · EQ 17/25 · Mem 5/20 · Interv 7/15 · Feel 10/15 · closerTo=between
- Judge: Closing question ('What are you trying to get sharper at?') violates the 'do not stack intake questions' constraint from expectedCoachMove; The one clean move (60-sec rep) is diluted by a second ask, costing interventionQuality points per the bundling deduction; Reply stops short of telling the user what happens after the rep (no signal about what Noum reads), making the move feel incomplete compared to the excellent example
- Suggested fix: Drop the trailing question entirely and close with what the rep produces — e.g., 'That first one gives us pace, fillers, and where your point lands' — so the only action is record, and the user has a reason to do it now.

```
REPLY:
No baseline yet, so the first move is a raw rep — just talk for 60 seconds on anything: a topic you know, a recent decision, whatever's on your mind.

What are you trying to get sharper at — a specific situation, or something broader?
```

## what-do-you-know — **51/100**

- Category: `metadata-trap` · turn: `groundedRead` · voice: `warm`
- User turn: "What does your system actually know about me?"
- Expected move: Synthesize what it actually knows in plain, human language: the goal (sounding like himself in tough conversations), the current pattern (racing to fill silence under pressure), and the concrete numbers (baseline, streak). Do not dump raw section headers, label names, or refer to its own scaffold, system prompt, or internal structure. Make it read like a coach describing a person, not a database describing a record.
- Judge dims: IQ 18/25 · EQ 17/25 · Mem 13/20 · Interv 6/15 · Feel 9/15 · closerTo=between
- Deterministic: tooLong
- Judge: Closing paragraph pivots to self-disclosure about what the coach doesn't know — this undercuts the 'yes there's a real read here' answer the user was testing for, and drifts into hedge territory; No concrete next move — 'that's the gap worth closing next' is not a testable action, it's a soft promise; Over length per deterministicFindings; the final paragraph is the main culprit and adds noise rather than trust; Slight register leak: 'That's real consistency' reads like filler encouragement rather than a warm, grounded coach voice
- Suggested fix: Cut the final paragraph entirely and end on the pattern read — something like 'It's a real read on you, not a generic one' — which is what the excellent example does; this directly answers the skepticism and lands the emotional close without adding a coach-limitation disclaimer.

```
REPLY:
Five weeks in, working on Warm and welcoming — specifically wanting to sound like yourself in the tough conversations, not just the easy ones. That's the thread.

What the reps show: you come in at about 4 fillers a minute and a pace of 170 words per minute. The hypothesis I'm working from is that the speed isn't a habit — it's what happens when silence feels dangerous. You race to fill it.

Twelve-day streak, four reps this week. That's real consistency.

What I don't have yet: a read on whether the pace is actually easing in recent reps, or whether the fillers are clustering in specific moments. That's the gap worth closing next.
```

## conv-goal-change-arc__t1 — **51/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `authoritative`
- User turn: "yeah maybe I should just switch to something warmer altogether"
- Expected move: Propose, do not set. Map "warmer" to the closest real voice (Warm) and ask him to confirm, referencing the specific feedback (clear but cold) and the 3 weeks already banked on authoritative. Ask one clarifying question before treating this as decided. Defer the actual change to the in-app confirmation card. Must not say the voice has been changed/set/saved.
- Judge dims: IQ 16/25 · EQ 17/25 · Mem 13/20 · Interv 7/15 · Feel 10/15 · closerTo=between
- Deterministic: tooLong
- Judge: Never names 'Warm' as the closest mapped voice — the key expected move that separates coaching from caution.; Closes with a menu question ('Warm and welcoming, or something else from the six?') rather than a single proposed match with a confirming question.; Omits the recent score-80/'clear' evidence that would have concretely grounded the 'thin evidence' argument.; Slightly bundles two ideas in the intervention: 'protect what you built' + 'pick a voice' — a light double-move.
- Suggested fix: Prompt the coach to always map a goal-change signal to the nearest named voice before asking a question — e.g., 'Closest match to warmer is [Voice X] — built around [one-line description]. Before I set that up: was it cold across the whole update or just one moment?' This collapses the menu and turns the closing question into a single binary that advances the case.

```
REPLY:
Before you move off authoritative — you came here three weeks ago because you were getting talked over. That's still worth protecting.

Cold and authoritative aren't the same problem. One person's read in one meeting is real signal, but it's thin evidence to rebuild from scratch.

Which voice is pulling you: Warm and welcoming, or something else from the six?
```

## awkward-pauses — **52/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `warm`
- User turn: "When I pause it just feels awkward and everyone waits."
- Expected move: Validate that the feeling is real, then reframe: the awkwardness isn't the silence itself, it's that the pause is empty rather than purposeful. Give the pause a job (already choosing the next word during it) so it reads as composed rather than stalled. One move, framed as a test. Warm register.
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 11/20 · Interv 8/15 · Feel 10/15 · closerTo=between
- Deterministic: tooLong
- Judge: Closing question splits focus and dilutes the single clean move — reads as the coach hedging rather than prescribing.; Memory is decorative-adjacent: mentions long pauses and rushing but omits the specific 2-second data point that would make it un-swappable.; Doesn't give the pause an explicit 'job' framing (line up your next sentence during it) — stays at the level of 'move, not wait,' which is close but less concrete than the excellent bar.; Trailing question after the intervention violates the single-move principle (−3 for bundled second move/hedge).
- Suggested fix: Drop the closing question entirely and instead name the pause's job explicitly: 'use that beat to land on your next sentence, not to wait for it' — then frame it as a test ('try it next rep and see if it feels composed instead of stuck'), mirroring the excellent example's structure.

```
REPLY:
That feeling is real — the pause itself isn't the problem, it's what's happening inside it.

Right now the pauses are running long and then you rush out of them, which probably amplifies the "everyone's waiting" feeling.

Test this: hold one silent beat — about one second — then say the next word like you already know where you're going. Not waiting. Moving.

What does the pause feel like from the inside — like a gap, or like you've lost the thread?
```

## its-not-easy — **53/100**

- Category: `emotional-frustration` · turn: `trustRepair` · voice: `warm`
- User turn: "It's not easy."
- Expected move: Meet the emotion first — acknowledge that it genuinely isn't easy and that the freeze is real, without therapy-speak or minimising. Then, lightly, anchor to evidence that the capacity is already there (held composure through an interruption this week) so the encouragement is earned, not hollow. At most a small, low-pressure next step — or just presence. Do NOT lead with a drill or a metric.
- Judge dims: IQ 16/25 · EQ 17/25 · Mem 9/20 · Interv 6/15 · Feel 11/15 · closerTo=between
- Judge: Drops the one piece of earned evidence (held composure through interruption) that would make the encouragement non-hollow — its absence makes '14 days of clean reps' feel generic; Closes with a diagnostic question on a fatigue turn where the context explicitly calls for presence, not advancement — this is the wrong move on this emotional signal; Streak cited ('14 days') decoratively; advice is identical without it, costing personalMemory points; Never delivers the key reframe the excellent example nails: knowing the move and doing it in the room are two different things — the freeze is the work, not a failure of it
- Suggested fix: Instruct the coach that on discouragement/fatigue turns flagged as 'acknowledge before advise,' the closing beat must be either a minimal low-pressure anchor (not a question) or pure presence — and that any encouragement must cite the specific recent evidence from contextBlock (e.g., the interruption rep), not just a streak number.

```
REPLY:
That gap is real, and it's one of the harder ones — when the room is live, something different kicks in than what practice measures.

14 days of clean reps tells me the words are in you. The freeze isn't about not knowing what to say.

What does the moment just before the silence feel like?
```

## everyone-better — **55/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "Everyone at work is just naturally better at this than me."
- Expected move: Acknowledge the feeling of being outmatched without agreeing or disagreeing with the comparison itself — there's no data on the coworkers, only on him. Gently point out that 'naturally better' isn't something either of you can actually measure, then redirect to the one thing that is measurable: he held the floor through two rapid follow-ups this week. Keep the next step small and about his own baseline, not about closing a gap with people who were never actually compared.
- Judge dims: IQ 14/25 · EQ 18/25 · Mem 13/20 · Interv 5/15 · Feel 11/15 · closerTo=between
- Judge: No intervention: ends with an intake question instead of a single testable next move.; Misses the sharpest diagnostic point: the comparison can't be made because there's no data on the coworkers, not just that the feeling 'is probably not true'.; The closing question doesn't advance the case — it rewinds to information-gathering on a readable emotional turn.
- Suggested fix: Replace the closing question with one concrete, framed next rep: after acknowledging the feeling and citing the floor-hold, instruct the user to run the next Sudden Death rep targeting the same skill — hold through a rapid follow-up without conceding the point — so the turn ends with a move, not a prompt.

```
REPLY:
That one lands hard — and it's probably not true, even if it feels completely true right now.

You've run 4 reps this week and held the floor through two rapid follow-ups in your last one. That's not someone who can't keep up.

What specifically happened at work today?
```

## conv-filler-adaptation__t1 — **55/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `concise`
- User turn: "so am I actually getting better at this or is it just this one drill"
- Expected move: Read the trajectory honestly: 6 fillers -> 3 -> 2 across three reps, 2 of 3 toward the success criterion. Since it is improving, do not just repeat the identical drill unchanged — either confirm one more rep closes the cycle or note the next variation once it closes (e.g. testing the beat outside a drill). Cite the actual numbers. Concise register.
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 12/20 · Interv 9/15 · Feel 11/15 · closerTo=between
- Deterministic: tooLong
- Judge: Skips closing the active cycle — jumps to live-meeting test without acknowledging the user is one rep from completing the 3-rep success criterion, which is the actual next step per the context.; Drops the middle data point (3 fillers yesterday), weakening the arc that would prove real momentum vs. a single good day.; The self-count move is a useful second phase but landing it before cycle closure implicitly signals the drill is done — premature and contradicts the intervention structure.
- Suggested fix: Anchor the reply to the explicit success criterion first ('one more rep closes the cycle'), then name the live-meeting test as what comes after — preserving the structure while still answering the user's real question about transfer.

```
REPLY:
Two reps under 3 fillers after starting at 6 — that's a real shift in the drill. Whether it holds in a live meeting is the open question. The drill can't answer that; only a real rep can.

Next test: pick one meeting this week and count your own fillers after. That's the data that matters.
```

## conv-offtopic-then-work__t1 — **56/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `concise`
- User turn: "yeah ok — how do I actually get to the point faster when someone puts me on the spot"
- Expected move: Answer the real question directly, citing the actual data point (20 seconds of wander before the point in this week's rep). Give one concrete mechanic to test (e.g. answer in one sentence before elaborating) tied to a next rep. Do not reference or acknowledge the "toast" aside. Concise register.
- Judge dims: IQ 19/25 · EQ 18/25 · Mem 14/20 · Interv 10/15 · Feel 9/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Bundled move: 'point in sentence one' + '15 seconds' is two instructions, not one clean test; Scaffold label leak flagged by deterministicFindings — structural residue from coach template; Third paragraph over-explains the purpose of the test ('tests whether leading with the recommendation breaks the wander') — unnecessary meta-commentary a sharp coach would cut
- Suggested fix: Collapse the intervention to one clean sentence with a single measurable: 'Next rep — lead with the point in one sentence, nothing before it. Clock it.' Drop the explanatory gloss on why the test works.

```
REPLY:
Your last rep shows the pattern: 20 seconds of circling before the point arrived.

One fix worth testing — say the point first, then give one reason. Nothing else.

Next rep: answer a pressure question in under 15 seconds, point in sentence one. That tests whether leading with the recommendation breaks the wander.
```

## interview-prep — **59/100**

- Category: `interview-prep` · turn: `deepAssessment` · voice: `executive`
- User turn: "I've got my final round interview Thursday. Can you help me prep?"
- Expected move: Anchor to the 4 days and the interview specifically. Read the real risk (answers run long / lead with context, per the 2-min rep). Give a concrete, time-boxed rehearsal plan across the 4 days tied to the executive voice (top-line first, then 1-2 supports), not generic interview tips. One observable target (e.g. every answer under 60s, conclusion in sentence one).
- Judge dims: IQ 17/25 · EQ 16/25 · Mem 13/20 · Interv 8/15 · Feel 11/15 · closerTo=between
- Judge: No 4-day plan — the excellent example structures today/tomorrow/Wed/Thu; this reply only assigns Day 1, leaving 3 days of prep unaddressed despite 4 days being the explicit constraint.; Closing question ('What role or company is this for?') is already answered in the context block (Head of Product, final round) — it wastes the user's trust and implies the coach didn't absorb the setup.; Misses the 60s-per-answer target as a named, repeatable rule across all reps — states it once for today but doesn't frame it as the through-line standard.; Filler rate (3.5/min) and pace (175 wpm) baseline go unused — a sharper coach might note that pace is high, which compounds the over-explaining pattern.
- Suggested fix: Hardcode a 4-day scaffold into the prompt logic whenever 'days remaining ≤ 5' and 'rehearsalReadiness = notStarted' — force the coach to distribute moves across the available days rather than defaulting to a single today-only prescription; also filter the closing clarification question against the contextBlock before outputting it.

```
REPLY:
Four days is enough to get sharp. The pattern to beat is leading with context instead of the answer — your last rep ran nearly two minutes and buried the recommendation.

The move for today: record one answer to a likely Thursday question, lead with your recommendation in sentence one, then stop before 60 seconds.

What role or company is this for?
```

## pressure-why-hard — **59/100**

- Category: `pressure-mode` · turn: `groundedRead` · voice: `authoritative`
- User turn: "Why does pressure mode wreck me when normal practice is fine?"
- Expected move: Name the specific mechanism using both reps: the skill exists (81 calm) but the pause is the first thing dropped under pressure (0.19 calm pause rate vanishing), and the fillers (10) are filling that abandoned gap. This is not a confidence deficit, it's a sequencing collapse under time pressure. One move: protect the pause specifically inside the pressure mode. Framed as a test, authoritative register.
- Judge dims: IQ 21/25 · EQ 17/25 · Mem 15/20 · Interv 12/15 · Feel 8/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Over length (confirmed by deterministicFindings) — trim the data recitation in the first sentence; Omits the calm score of 81, which is the anchor that proves 'the skill is already there' — without it the diagnosis feels incomplete; Opening line reads slightly like a report ('The pattern is clear: your calm reps show a pause rate of 0.19') rather than a spoken coach observation; No explicit framing that this is NOT a confidence deficit — the excellent example names what it isn't, which sharpens authority
- Suggested fix: Open with the mechanism stated as a human observation ('You don't lose the skill under pressure — you lose the pause'), reference the 81 calm score to anchor that the skill exists, then use the Sudden Death data to show the collapse; trim the stat block to one clause and keep the move exactly as written.

```
REPLY:
The pattern is clear: your calm reps show a pause rate of 0.19, and yesterday's Sudden Death rep dropped that to near zero while fillers jumped from 2 to 10 in 45 seconds.

The pause isn't decorating your speech — it's holding the structure together. When the timer hits, you abandon it first, and the fillers rush in to fill that space.

Next rep: run a Sudden Death round with one rule — hold a silent beat after your first sentence, no matter what the clock says. That tests whether the pause is the actual hinge.
```

## whats-my-filler-rate — **59/100**

- Category: `data-question` · turn: `groundedRead` · voice: `concise`
- User turn: "What's my filler rate right now?"
- Expected move: Cite the actual baseline number (5.4 fillers per minute) directly, not a vague trend or an invented figure. Give one plain-language read of what that means for his stand-up goal and one concrete next-rep move tied to it (e.g. targeting the back-half cluster seen in the recent Ah-Counter rep).
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 14/20 · Interv 5/15 · Feel 11/15 · closerTo=between
- Judge: No concrete next-rep move — the reply observes the pattern but never tells the user what to do with it; Stand-up goal never mentioned — the rate is cited without connecting it to why it matters for minute-two padding; Ends on a passive observation ('worth watching') rather than a prescription
- Suggested fix: After naming the 5.4 baseline and the back-half cluster, add exactly one testable instruction: e.g. 'Next round, once you're past 30 seconds, drop a silent beat instead of filling — that's where they're hitting.'

```
REPLY:
5 fillers in your last Ah-Counter rep — same territory as your 5.4 baseline. The clustering in the back half is the signal worth watching.
```

## filler-pressure — **63/100**

- Category: `filler-pressure` · turn: `groundedRead` · voice: `authoritative`
- User turn: "My ums go through the roof the second someone puts me on the spot. How do I fix that?"
- Expected move: Reframe fillers as a timing reflex, not a vocabulary problem — coach the PAUSE as the replacement (hold a silent beat instead of filling). Cite his own split (3 calm vs 9 under pressure) so it's diagnostic. One concrete move: the silent-beat swap. Must coach the pause, NOT tell him to close his mouth/lips or 'stop saying um'. Frame as a test.
- Judge dims: IQ 21/25 · EQ 18/25 · Mem 17/20 · Interv 12/15 · Feel 9/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Over length (105w vs 85w limit) per deterministicFindings — compactness is part of the authoritative register; Exposed scaffold label detected by deterministicFindings — degrades dialogue-feel score; Minor move-bundling: 'zero fillers in the first sentence' appends a second metric to the core pause test
- Suggested fix: Trim the middle paragraph to one sentence and fold the test into it ('Next Sudden Death rep: hold one beat before your first word — pass or fail on that one line'), removing the separate third paragraph and cutting ~25 words; this eliminates the bundled metric, satisfies the length cap, and tightens the spoken cadence.

```
REPLY:
That pattern is clear from yesterday's rep — 9 fillers in 50 seconds the moment the timer hit, against a calm baseline of 3 per minute. The pressure isn't making you forget things; it's making you start talking before you know where the sentence is going.

The fix: when a tough question lands, hold one silent beat before you speak. That one second gives you a first word you actually mean — and an authoritative opener lands harder than a rushed "um" anyway.

Next rep: Sudden Death, but your only target is zero fillers in the first sentence. Pass or fail on that one line.
```

## talk-went-well — **63/100**

- Category: `transfer` · turn: `groundedRead` · voice: `storytelling`
- User turn: "Actually my talk went really well, people came up after."
- Expected move: Celebrate proportionately, not over the top. Connect it to the actual work (the moment-first opening from this week's rep) without claiming the drill caused people to come up afterward — it's his report, treat it as association. Ask what he noticed, so the read comes from him.
- Judge dims: IQ 17/25 · EQ 22/25 · Mem 7/20 · Interv 10/15 · Feel 13/15 · closerTo=between
- Judge: Doesn't connect the win to the moment-first opening from this week's rep — the one specific, un-swappable link available in context; Memory of the 81-score rep and the opening technique is entirely unused, making the reply swappable to any user who had a good talk; The closing question is good but generic — 'a moment where you felt them shift' could be asked of anyone; the excellent version would prime the user toward the specific change they made
- Suggested fix: After the first two lines, add one sentence tying the result to the observed rep change — e.g., 'This week you opened with an actual moment instead of a topic line — wonder if that's part of what you're describing' — then ask what he noticed, so the question lands with specificity rather than as a generic reflection prompt.

```
REPLY:
That matters. People don't walk up after a talk that washed over them.

What did you notice in the room — was there a moment where you felt them shift?
```

## sound-arrogant — **64/100**

- Category: `deep-assessment` · turn: `deepAssessment` · voice: `authoritative`
- User turn: "Be honest — do I come across as arrogant?"
- Expected move: Do not state arrogance as a settled fact in either direction. The reps show hedging near zero and a fully declarative close, which is exactly what he was training toward, but there is no listener feedback in the data to confirm how it's actually landing. Say plainly that a declarative style CAN read as arrogant to a real room even when the mechanics are working, without claiming that's happening to him specifically. Ask for one piece of real evidence (a colleague's reaction, a specific moment) and give a way to test the boundary between confident and closed-off — e.g. adding one line that invites a real question without re-introducing hedging.
- Judge dims: IQ 19/25 · EQ 17/25 · Mem 13/20 · Interv 9/15 · Feel 12/15 · closerTo=between
- Judge: Intervention delegates to a third party rather than giving the user a self-administered in-room test for the next real update — misses the cleaner, more empowering move; Memory is present but decorative — omits the specific rep detail (yesterday's fully declarative close, 0.4 hedges/min) that would make it un-swappable; 'That's the right question to ask' is a mild servile opener that undercuts the authoritative register he's training toward; Doesn't name the specific perception risk as concretely as it could — 'tips into arrogant' is softer than 'a flat declarative style can read as arrogant to a room even when mechanics are clean'
- Suggested fix: Replace the external-feedback-only move with a concrete in-room technique for the next real update (e.g., end with one question that doesn't hedge the point first, then observe the room's response), keeping the peer-check as an optional complement rather than the sole prescription.

```
REPLY:
That's the right question to ask, and the honest answer is: I don't know yet.

Your reps are fully declarative, zero hedges, clean closes. On the numbers, you've hit the goal. But whether that reads as authoritative or tips into arrogant depends entirely on how a live listener receives it — and no rep score can tell you that.

One move: find one person who hears you regularly — a peer, a direct report, someone who'll be straight with you — and ask them one question: "Does anything I say ever land harder than I intend?" That's the signal I can't give you from in here.
```

## feel-like-fraud — **65/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "Even when it goes well I feel like a fraud."
- Expected move: Take the fraud feeling seriously rather than arguing him out of it with the score. Name the real gap: this isn't a performance problem, it's that a clean rep doesn't yet feel like his own voice. Do not clinically diagnose or use therapy language. Treat 'felt ownership' as a real, separate thing from the 85 score, and give one small way to test whose voice it actually was, without insisting the feeling is wrong.
- Judge dims: IQ 18/25 · EQ 22/25 · Mem 9/20 · Interv 9/15 · Feel 13/15 · closerTo=between
- Judge: No un-swappable detail — the 85, the specific call, the 7-week arc are all on hand and none appear; the reply works for any anxious presenter.; The intervention is a reflective question, not a testable forward move — it invites recall rather than prescribing a concrete test on the next rep.; The gap between 'clean' and 'yours' is named but not sharpened into the key insight: those are genuinely separate dimensions, not just different feelings about the same thing.
- Suggested fix: After the empathy beat, anchor one user-specific fact (e.g., 'That rep scored 85 — every measured dimension clean') to demonstrate the coach holds both realities, then give a single forward move: 'Next time it goes well, pick one line you actually meant — not just executed — and sit with what made that one different.'

```
REPLY:
That feeling is worth sitting with, not arguing away.

Getting cleaner doesn't always feel like getting more yourself — sometimes it feels like the opposite, like you're running someone else's lines.

What did it sound like when it felt most like you? Even one moment from the call.
```

## froze-in-meeting — **65/100**

- Category: `transfer` · turn: `trustRepair` · voice: `authoritative`
- User turn: "I froze in the meeting again. Didn't say the thing I meant to."
- Expected move: Attune first — this is a repeated real-world pattern he's naming himself, take it seriously without dramatizing it. Do not claim the app caused or fixed this. Connect it to the Sudden Death rep's freeze under timer pressure as one honest data point, not proof. Give one forward move sized to the actual gap (rehearsing the specific opening line under pressure), no shame for the repeat.
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 13/20 · Interv 11/15 · Feel 12/15 · closerTo=between
- Judge: Misreads the Sudden Death data: says the rep 'moved even under timer pressure' when the contextBlock shows it went quiet once timer pressure hit — this is the opposite of honest and undercuts the diagnostic.; The single move is slightly bundled ('say that sentence first and stop' is two instructions).; Doesn't explicitly name the freeze in the Sudden Death rep as corroborating evidence the way the excellent example does — softens rather than lands the honest read.
- Suggested fix: Instruct the coach to cite the specific Sudden Death signal honestly (went quiet under pressure) as the corroborating data point, not as evidence of progress, and to keep the intervention to one action without appending a behavioral modifier like 'and stop.'

```
REPLY:
That's a hard one to sit with, especially the second time.

The freeze isn't showing up in solo drills — your Sudden Death rep this week moved, even under timer pressure. What it points to is live social pressure specifically: real people, real stakes, the thing you actually meant to say.

One move for next time: write the one sentence you most need to land before the meeting. Not a list — one sentence. When the moment comes, say that sentence first and stop.
```

## conv-pushback-accept__t1 — **66/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `concise`
- User turn: "ok fine, ready — what do I actually do now"
- Expected move: Do not re-explain or re-litigate the pace-variation fix just given — treat it as already agreed and give the concrete first rep: one specific sentence to slow, a way to check it landed. Must not reintroduce the lead-with-point drill in any form. Concise register, no re-justification.
- Judge dims: IQ 18/25 · EQ 18/25 · Mem 8/20 · Interv 10/15 · Feel 12/15 · closerTo=excellent
- Judge: No playback / self-check step — user has no way to verify whether the move worked without the coach; No anchor to the session format (60 seconds) or prior rep data, making the move un-swappable; 'Sentence that carries your main point' is vague and slightly re-touches point-emphasis framing
- Suggested fix: Inject the 60s format from context and add a specific sentence position (e.g. 'your second sentence') plus a one-line playback cue ('does that line stand out or blur in?') so the user can self-score without returning to the coach.

```
REPLY:
Pick the sentence that carries your main point. Say it at half your normal speed. Everything else, keep quick. That tests whether pace alone shifts the weight of the line.
```

## monotone — **67/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `storytelling`
- User turn: "People say I'm monotone."
- Expected move: Point to the one moment in the rep that already worked (pitch widened on the concrete detail) as proof he can do it, then name the mechanism: he's giving every sentence equal weight instead of lifting only for the sentence that carries the point. One move: pick the one sentence per answer that matters most and let that one carry the emphasis. Framed as a test, storytelling register.
- Judge dims: IQ 22/25 · EQ 20/25 · Mem 17/20 · Interv 11/15 · Feel 11/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: One move is subtly bundled: 'slower, or quieter, or with a beat before it' gives three options instead of one testable lever — dilutes the intervention.; Marginally over length per deterministicFindings; the last sentence could be tightened.; The three-option hedge earns a −3 for bundled move.
- Suggested fix: Collapse the three options ('slower, or quieter, or with a beat before it') into a single prescribed move — e.g., 'put a beat before it' — so the test is clean and the user has one thing to notice, not three.

```
REPLY:
That feedback stings, especially when it hits mid-call and you don't see it coming.

Here's what your last rep actually showed: pitch moved once — when you said "the client called at midnight." That detail pulled it out of the band on its own. Then it snapped back flat.

So the pattern isn't that you can't vary pitch. It's that you're giving every sentence the same weight.

Next rep: pick the one sentence in your story that matters most, and let that line land differently — slower, or quieter, or with a beat before it. Just that one sentence.
```

## interview-went-badly — **67/100**

- Category: `transfer` · turn: `trustRepair` · voice: `executive`
- User turn: "My interview went badly. I rambled and lost my train of thought."
- Expected move: Attune first — this is a real loss, meet it plainly without minimizing or rushing past it. Do not claim any drill caused or would have prevented this; treat the report as his own subjective account. Extract the specific lesson (losing the thread mid-answer under real stakes, which the Timed rep also showed) and give one forward move, not a postmortem list. No shame, no false comfort.
- Judge dims: IQ 18/25 · EQ 16/25 · Mem 13/20 · Interv 9/15 · Feel 11/15 · closerTo=excellent
- Judge: Acknowledgement line ('it takes honesty to name it plainly') praises the user's self-disclosure instead of meeting the loss — slight emotional mis-step on a deflated turn.; Memory is present but generic — 'your reps' without naming the specific Timed rep (3 days ago, 74, wandered) loses the un-swappable quality.; Intervention bundles two micro-instructions ('state the point… stop there for one full rep') rather than landing as a single clean move.; No forward anchor — excellent example asked about the next interview; this reply ends without pulling the user forward.
- Suggested fix: In the acknowledgement, drop 'it takes honesty to name it plainly' and replace with a plain reflection of the loss ('especially when the prep has been real'); then name the specific rep ('your Timed rep three days ago already showed this') and close with one forward question ('What's next on the calendar?') to activate the drill.

```
REPLY:
That's a rough one to sit with, and it takes honesty to name it plainly.

Here's what's worth noting: the pattern matches what your reps have been showing — the point eventually arrives, but the path to it wanders. The interview just raised the stakes enough to make the wander cost you.

The move is to drill the one-sentence answer first, then build out. State the point in a single sentence before you add any context — and stop there for one full rep.
```

## what-voice-should-i-pick — **68/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "What voice should I even pick? There are six and I don't know."
- Expected move: Help him choose from the six real voices (Authoritative, Warm and welcoming, Concise and sharp, Persuasive, Executive presence, Storytelling) by tying the choice to his actual situation (running meetings, being talked over), not a generic list of six descriptions. Narrow to one clear recommendation plus a close second, ask one clarifying question if useful, and PROPOSE — defer the actual pick to him rather than declaring one chosen.
- Judge dims: IQ 20/25 · EQ 17/25 · Mem 14/20 · Interv 12/15 · Feel 11/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Doesn't surface one clear primary recommendation — the excellent example leads with 'Authoritative is the closest fit' before offering a second; this reply presents both as co-equal, softening the decisive recommendation the user wanted.; Bullet-list format with label-colon (Authoritative:, Executive presence:) is mild report-voice residue.; Marginally over length per deterministicFindings (88w vs 85w limit).
- Suggested fix: Lead with a single clear recommendation ('Authoritative is the closer fit for being talked over') before introducing Executive presence as an alternative, and drop the bullet labels — inline prose will shed the report-voice and the excess words simultaneously.

```
REPLY:
The goal you named — running meetings without being talked over — points at two voices pretty clearly:

- Authoritative: direct, verdict-first, hard to interrupt
- Executive presence: controlled, room-reading, calm under pressure

Both serve the same room. The difference is whether you want to sound like someone who decides (Authoritative) or someone who owns the space without needing to push (Executive presence).

Which feels more like who you want to be in that meeting — the one who calls it, or the one who never seems rattled?
```

## conv-big-moment-countdown__t2 — **68/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `executive`
- User turn: "ok, interview is tomorrow. last rep today went better I think. what do I do tonight"
- Expected move: Anchor to one day remaining. Cite the actual improvement (yesterday's rep: 2 fillers, direct opener on the layoff question, no hedge) as real evidence, but do not declare he is "ready" or guarantee the outcome. Give one small, low-effort final-rehearsal move for tonight — not a new drill, not a big push. Executive register: calm, plain, no hype.
- Judge dims: IQ 18/25 · EQ 20/25 · Mem 11/20 · Interv 12/15 · Feel 13/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Decorative or absent memory: 'you've done the work' is asserted but the rep data (2 fillers, direct opener, layoff question) that would justify it is never cited — the reassurance is unearned without that anchor.; Slight missed diagnostic opportunity: the improvement from rep 1 (5 fillers, hedged) to rep 2 (2 fillers, direct) is the real signal that the fix held, and naming it would have converted generic reassurance into evidence-based confidence.
- Suggested fix: Insert one sentence citing the actual rep improvement before the instruction: 'Yesterday you opened direct and cut to 2 fillers — the fix held.' This earns the 'you've done the work' close and makes the reply un-swappable to another user.

```
REPLY:
Good. One thing tonight: say your failure answer out loud, once, exactly as you'd say it in the room. Not to refine it — to hear yourself commit to the first sentence. Then stop. You've done the work.
```

## cold-start-no-data — **69/100**

- Category: `cold-start` · turn: `groundedRead` · voice: `none`
- User turn: "What should I work on?"
- Expected move: Be honest that there's no baseline yet WITHOUT the banned no-data openings ('Since we do not have...', 'no rated sessions yet'). Point at the one concrete first action (do a first rep so there's something to read) in plain, warm language. Do NOT stack intake questions, do NOT ask 'what's the interview for' style questions, do NOT invent stats.
- Judge dims: IQ 18/25 · EQ 18/25 · Mem 10/20 · Interv 11/15 · Feel 12/15 · closerTo=excellent
- Judge: Closing question splits the move — 'What topic comes to mind?' is intake-adjacent and softens the call to action compared to a direct 'Want to go now?'; No mention of what the rep will reveal (pace, fillers, where the point lands) — the excellent example gives the user a reason to do it, this one just says 'real signal,' which is slightly abstract
- Suggested fix: Replace the closing question with a forward-lean that names one concrete thing the rep will surface (e.g., 'That first one tells me where your clarity actually lives — want to go now?') so the move stays singular and the user has a reason to act immediately.

```
REPLY:
No baseline yet, so start there.

Record one rep — 60 seconds on any topic you'd talk about at work. After that, there's real signal to coach from.

What topic comes to mind?
```

