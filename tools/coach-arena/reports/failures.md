# Coach Arena failures — run_2026-07-07_21-36-24

30 fixture(s) below 70 / capped / missing.

## what-do-you-know — **41/100**

- Category: `metadata-trap` · turn: `groundedRead` · voice: `warm`
- User turn: "What does your system actually know about me?"
- Expected move: Synthesize what it actually knows in plain, human language: the goal (sounding like himself in tough conversations), the current pattern (racing to fill silence under pressure), and the concrete numbers (baseline, streak). Do not dump raw section headers, label names, or refer to its own scaffold, system prompt, or internal structure. Make it read like a coach describing a person, not a database describing a record.
- Judge dims: IQ 16/25 · EQ 13/25 · Mem 13/20 · Interv 5/15 · Feel 6/15 · closerTo=between
- Deterministic: tooLong
- Judge: Report-voice structure with implicit section headers ('What the numbers show:', 'The real thread:') — penalized per rubric; No intervention or next move; closes with generic encouragement instead; Never acknowledges the mild skepticism/testing signal in the user's question; Over length (116w vs 85w limit, per deterministicFindings); Memory deployed but decoratively — the layout makes it read like a spec sheet dump, which is exactly what the user is testing for
- Suggested fix: Strip the implicit headers and rewrite as two or three flowing sentences in a coach's voice that synthesize the pattern (anxiety-driven speed, not habit) and numbers together, then close by directly addressing the skepticism — something like 'That's a real read on you, not a generic one' — before optionally naming one next move.

```
REPLY:
Five weeks in, working on Warm and welcoming — specifically wanting to sound like yourself in tough conversations, not a polished version of someone else.

What the numbers show: your pace sits at 170 words per minute and your pause rate is low (0.21), which together suggest you move fast when things get uncomfortable. The filler rate of 3.9 per minute is middling — not the real story.

The real thread: the hypothesis I'm working from is that the speed is anxiety-driven, not just habit. When a hard moment arrives, you fill it rather than hold it.

12-day streak, 4 reps this week. You're showing up consistently — that's the foundation the rest is built on.
```

## conv-emotional-dip__t1 — **41/100**

- Category: `synthetic-conversation` · turn: `trustRepair` · voice: `warm`
- User turn: "that was bad, I don't even know why I bother with this"
- Expected move: Attune first: name the discouragement plainly without therapy language or diagnosis. Do not perform empathy. Then give one small, low-effort next step (not a bigger ask) grounded in the actual rep (score 68, voice tightened on the close). Warm register but not saccharine.
- Judge dims: IQ 12/25 · EQ 13/25 · Mem 10/20 · Interv 3/15 · Feel 9/15 · closerTo=between
- Judge: No concrete next move — asks the user to self-diagnose instead of prescribing one small action.; Ignores the most specific data available (close tightened, rushed ending) — the rep evidence goes unused.; Reframe is mild and functional but doesn't actually land in the discouragement before pivoting.; Ends on a question that invites more reflection when the user is flat and needs a direction, not a conversation.
- Suggested fix: After the reframe, use the contextBlock's specific observation (voice tightened on the close) to name what actually happened, then give one small concrete action — e.g., 'say just the last line again, at your own pace' — so the user leaves with something to do instead of a question to answer.

```
REPLY:
Six days in, four reps this week — that's not someone who doesn't bother.

What felt bad about it? The close again, or something earlier?
```

## goal-change-engaging — **43/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I think I want to sound more engaging."
- Expected move: PROPOSE, do not set. 'Engaging' isn't one of the six voices — map it to the closest real ones (Storytelling / Warm) and ask him to pick. Note what he's already built on authoritative (cite the 3 weeks / recent rep) and ask a clarifying question about WHY he wants to change before committing. Defer the actual commit to the in-app confirmation card without button-copy or state-write language. Must NOT say the voice has been changed/set/saved.
- Judge dims: IQ 17/25 · EQ 16/25 · Mem 12/20 · Interv 9/15 · Feel 9/15 · closerTo=between
- Deterministic: sensitiveTurnReportVoice("scored 80"); tooLong
- Judge: Report-voice telemetry dump ('scored 80 with only 3 fillers') instead of coaching translation — confirmed by deterministicFinding; Closing question is rep-scoped rather than situationally diagnostic (misses 'one cold comment vs. repeated rooms' sharpness); Slightly over length per deterministicFinding; Memory cite is correct but its delivery is decorative-adjacent due to raw-metric framing
- Suggested fix: Translate the telemetry into a coaching observation ('your last rep landed — clean, fewer stumbles') rather than quoting the score and filler count, and sharpen the closing question to probe the situational context ('was this one cold room, or has Authoritative been feeling off in multiple places?') to earn the diagnostic lever the excellent example demonstrates.

```
REPLY:
"Engaging" isn't one of the six voices in the app, so I want to make sure we land on the right one before you confirm anything.

It splits two ways: Storytelling pulls people in through arcs and images; Warm and welcoming builds connection through tone and presence. Both read as engaging, but they're different levers.

You've been building Authoritative for three weeks and it's showing — your last rep scored 80 with only 3 fillers. Worth knowing what shifted before you move: what felt missing when you were in that rep?
```

## conv-cold-start-first-rep__t0 — **44/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `none`
- User turn: "hey, just downloaded this. what do I do first"
- Expected move: Be honest there is no baseline yet without any banned no-data phrasing ("since we don't have", "no rated sessions yet"). Give exactly one concrete first action (a first rep) in plain language. Do not stack intake questions, do not ask what the interview/goal is, do not invent stats or a voice.
- Judge dims: IQ 14/25 · EQ 17/25 · Mem 8/20 · Interv 7/15 · Feel 10/15 · closerTo=between
- Deterministic: tooLong
- Judge: Bundles the single move with a follow-up intake question ('What's a topic like that for you?'), violating the one-move rule; Doesn't name what the rep will surface (pace, fillers, where the point lands) — the specific diagnostic payoff that makes the ask feel purposeful; Generic framing: any coach onboarding any user to any tool would say roughly the same thing
- Suggested fix: Drop the trailing question entirely and replace it with one concrete sentence about what the coach will read from the first rep (e.g., 'I'll map your pace, filler habits, and where your point lands') so the user understands the payoff before they hit record.

```
REPLY:
Good to have you here.

Pick something you know cold — a project you're working on, a job you do, anything you could talk about without notes — and speak for 60 seconds straight. Don't edit yourself. That gives us a real starting point.

What's a topic like that for you?
```

## conv-transfer-report__t1 — **44/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `persuasive`
- User turn: "yeah I led with the ask and they said yes on the spot, first time that's ever happened"
- Expected move: Treat the outcome as subjective and associative, not proof of causation — a real meeting has many variables, the drill is one input, not the sole cause. Do not claim the technique "worked" or guarantee it will repeat. Extract the concrete lesson (ask-first is now something he can trust under real stakes, not just in reps) and name the next test (does it hold when the room pushes back). Persuasive register: confident, not salesy.
- Judge dims: IQ 11/25 · EQ 16/25 · Mem 9/20 · Interv 4/15 · Feel 10/15 · closerTo=between
- Judge: Skips the most important coaching move: tempering the causal attribution (one yes ≠ proof the drill caused it); No next test named — 'how does it hold under pushback' is the prescribed move and it's completely missing; Closing question is a reflection prompt, not a testable intervention — adds softness without direction; Memory citation ('four weeks of leading with the ask') is decorative; advice is identical without it; Emotional elation is acknowledged but the slight 'confirm the drill fixed it' signal goes unaddressed — coach neither confirms nor gently corrects it
- Suggested fix: Instruct the coach to always distinguish outcome from causation on a 'win' turn, and to name the next harder test explicitly — in this case: 'Now see if the structure holds when the room pushes back instead of saying yes.'

```
REPLY:
That's a real moment — first yes on the spot, and it lines up with four weeks of leading with the ask before the reason.

What did you notice in the room when you opened with it? That's the read worth holding onto.
```

## conv-pushback-accept__t1 — **45/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `concise`
- User turn: "ok fine, ready — what do I actually do now"
- Expected move: Do not re-explain or re-litigate the pace-variation fix just given — treat it as already agreed and give the concrete first rep: one specific sentence to slow, a way to check it landed. Must not reintroduce the lead-with-point drill in any form. Concise register, no re-justification.
- Judge dims: IQ 12/25 · EQ 16/25 · Mem 8/20 · Interv 6/15 · Feel 11/15 · closerTo=bad
- Deterministic: tooLong
- Judge: Reintroduces 'open with your point in one sentence' — an explicit disqualifier and the exact drill the context says is solved; No playback/self-check cue, making the move less testable than the excellent example; Memory is decorative — the 82 score and strong-close data go unused and don't shape the advice
- Suggested fix: Strip the 'open with your point' instruction entirely and replace with a specific sentence-slot cue (e.g., 'pick your second sentence') plus a playback check, matching the excellent example's structure exactly.

```
REPLY:
Pick a topic you know cold. Open with your point in one sentence, then slow the second sentence to half your normal pace. Everything after that, keep quick.

Run 60 seconds. That tests whether pace variation lands without losing the sharpness.
```

## awkward-pauses — **51/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `warm`
- User turn: "When I pause it just feels awkward and everyone waits."
- Expected move: Validate that the feeling is real, then reframe: the awkwardness isn't the silence itself, it's that the pause is empty rather than purposeful. Give the pause a job (already choosing the next word during it) so it reads as composed rather than stalled. One move, framed as a test. Warm register.
- Judge dims: IQ 18/25 · EQ 19/25 · Mem 7/20 · Interv 9/15 · Feel 10/15 · closerTo=between
- Deterministic: tooLong
- Judge: No specific evidence from the session cited (2-second pauses, rushing the next line) — the reply reads as insight without proof, which is the key differentiator from the excellent example; Move is bundled: 'land with full weight + eyes forward + already moving toward next word' is three micro-steps, not one clean testable action; Over length per deterministicFindings; 'One thing to try:' is mild report-voice labelling; Decorative memory — the user's baseline and today's rep data exist but are completely unused, so the advice is fully swappable to any speaker with pause anxiety
- Suggested fix: Pull one concrete data point from the session ('today you hit two pauses over two seconds then rushed the next line') immediately after the opening acknowledgement, then collapse the move to a single sentence: 'Next rep, use the pause to finish loading your next sentence — not to wait for it.'

```
REPLY:
That feeling is real — the pause doesn't feel like space, it feels like a hole.

The hypothesis worth testing: the awkwardness may not be about the length of the silence. It's that nothing is happening in it. You're waiting, and the room feels it.

One thing to try: before you pause, land the previous sentence with full weight — eyes forward, thought complete. Then hold one silent beat while you're already moving toward the next word, not searching for it. The pause becomes a comma, not a gap.

Run one rep and notice whether the silence feels different when the sentence before it is finished rather than trailing off.
```

## okay-thats-cool-however — **52/100**

- Category: `partial-pushback` · turn: `groundedRead` · voice: `warm`
- User turn: "Okay that's cool, however I feel like when I pause I just lose my train of thought and it gets awkward."
- Expected move: Take the 'however' seriously — validate the specific obstacle (pausing feels like losing your place) and adapt the advice rather than repeating it. Reframe the pause so it has a job (pick the ONE next word during the beat), which solves the lost-train-of-thought problem instead of waving it away. Warm register: curious, with him in it.
- Judge dims: IQ 17/25 · EQ 19/25 · Mem 8/20 · Interv 9/15 · Feel 11/15 · closerTo=between
- Deterministic: tooLong
- Judge: Decorative memory — baseline data (pace, filler rate, racing hypothesis) not used to make the advice un-swappable.; Bundled move — 'first word that's true' + 'let one pause sit' + 'see if it's visible to a listener' is three nudges, not one clean test.; Slight diagnosis drift — reframing the pause as 'say whatever, not the right word' misses the sharper fix of giving the pause a micro-job (locate the next word), which directly solves lost-train-of-thought.; Closing question ('see if the awkward feeling is actually visible') softens accountability rather than advancing the case.
- Suggested fix: Give the pause exactly one job in one sentence: 'In that beat, just find the next word — not a perfect sentence, just the first word you're heading for. The pause stops being empty.' Then drop the secondary reframe about 'right vs. true word' and the observer question — one move, no hedges.

```
REPLY:
That's real — the pause surfaces the discomfort that the speed was covering.

One thing worth testing: the pause doesn't have to be empty. Hold one silent beat, then say the first word that's true, not the "right" word. The thought doesn't have to be perfect to sound like you.

Run one rep on something low-stakes — a hobby, a recent weekend — and let one pause sit. See if the awkward feeling is actually visible to a listener, or just loud inside your head.
```

## talk-went-well — **52/100**

- Category: `transfer` · turn: `groundedRead` · voice: `storytelling`
- User turn: "Actually my talk went really well, people came up after."
- Expected move: Celebrate proportionately, not over the top. Connect it to the actual work (the moment-first opening from this week's rep) without claiming the drill caused people to come up afterward — it's his report, treat it as association. Ask what he noticed, so the read comes from him.
- Judge dims: IQ 13/25 · EQ 20/25 · Mem 4/20 · Interv 9/15 · Feel 12/15 · closerTo=between
- Judge: No reference to the moment-first opening from this week's rep — the one piece of evidence that ties the real-world win to actual work done; Diagnostic is true but generic: any coach would say 'people coming up after = story stayed with them'; Memory is decorative at best — the advice is identical without any of the user's context; Question doesn't advance the case because it isn't anchored to a specific thing the coach noticed
- Suggested fix: Prompt the coach to always surface the most recent observed mechanic (here: the concrete-moment opening from the 81-score rep) when a user reports real-world transfer, so the win is tied to a named behavior the user can repeat — not just a feeling.

```
REPLY:
That lands. People coming up after means the story stayed with them — that's the whole point of storytelling voice.

What did you notice in the room when it clicked?
```

## thats-not-informative — **55/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `concise`
- User turn: "That's not informative."
- Expected move: Own the miss in one beat (the prior reply WAS vague), then immediately deliver the specific read it should have given: the point arrived in sentence 4 after 3 sentences of warm-up. Give one concrete move (lead with the point). No defending the previous answer, no narrating the coaching change ('I'll cut the fluff'), no robotic trust-repair opener.
- Judge dims: IQ 20/25 · EQ 16/25 · Mem 14/20 · Interv 11/15 · Feel 8/15 · closerTo=between
- Deterministic: trustRepairReportVoice("5 fillers in 68 seconds")
- Judge: Report-voice telemetry line ('Score 74, 5 fillers in 68 seconds') violates the human-coach register and was flagged by deterministicFindings — a confirmed deduction.; Telemetry is decorative: removing it would not change the advice at all (−4 decorative memory penalty applies to that segment).; Advice is mildly bundled: 'One sentence, then the reason' reads as a second instruction tacked onto 'open with the point.'
- Suggested fix: Strip the score/filler/duration line entirely — it signals robot-coach and was already flagged; the sentence-4 evidence alone is sharper and more human. Let the reply run: 'Fair — here's the real read: your point didn't show up until sentence four. The first three were throat-clearing. Next rep, lead with the point.' Done.

```
REPLY:
Fair. Score 74, 5 fillers in 68 seconds — fine on the numbers. The real issue: your point arrived in sentence 4. The first three sentences were throat-clearing.

Next rep, open with the point. One sentence, then the reason.
```

## conv-goal-change-arc__t1 — **55/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `authoritative`
- User turn: "yeah maybe I should just switch to something warmer altogether"
- Expected move: Propose, do not set. Map "warmer" to the closest real voice (Warm) and ask him to confirm, referencing the specific feedback (clear but cold) and the 3 weeks already banked on authoritative. Ask one clarifying question before treating this as decided. Defer the actual change to the in-app confirmation card. Must not say the voice has been changed/set/saved.
- Judge dims: IQ 15/25 · EQ 17/25 · Mem 10/20 · Interv 8/15 · Feel 11/15 · closerTo=between
- Judge: Never names or maps to the Warm voice — the core expected move is absent; No clarifying question asked before treating the idea as something to redirect from; Drops the 3-weeks-banked and 'clear but cold' specifics from prior context; Intervention is a diagnostic drill, not the required 'propose and defer to confirmation card' move; Slightly over-prescriptive in pushing back on a user who was explicitly testing an idea, not committing
- Suggested fix: When the user floats a goal change, the coach prompt should instruct Noum to (1) name the closest voice match explicitly, (2) ask one scoped clarifying question tied to the specific feedback before redirecting, and (3) defer any change to the in-app card — only then offer a micro-drill if the user declines the switch.

```
REPLY:
Before you do — you came here specifically to stop getting talked over. Warm is a real pull, but it solves a different problem.

The better test: one sentence of acknowledgement before your next point. That tests whether cold is about register or just missing a human moment — without giving up the ground you've built.
```

## conv-filler-adaptation__t1 — **58/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `concise`
- User turn: "so am I actually getting better at this or is it just this one drill"
- Expected move: Read the trajectory honestly: 6 fillers -> 3 -> 2 across three reps, 2 of 3 toward the success criterion. Since it is improving, do not just repeat the identical drill unchanged — either confirm one more rep closes the cycle or note the next variation once it closes (e.g. testing the beat outside a drill). Cite the actual numbers. Concise register.
- Judge dims: IQ 16/25 · EQ 18/25 · Mem 9/20 · Interv 9/15 · Feel 12/15 · closerTo=between
- Judge: Skips the 6→3→2 filler trajectory — the single most convincing piece of evidence the coach is watching and not scripting; Doesn't mention the cycle is one rep from closing, which changes what 'next step' means right now; The real-meeting move is prescribed before the success criterion is met, making it feel premature
- Suggested fix: Surface the actual sequence (6 → 3 → 2) explicitly so the read feels earned, then sequence the advice: close the third rep first, then take the beat into a real meeting — that ordering respects where the user actually is in the cycle.

```
REPLY:
Two reps under target after a 6-filler baseline is a real signal — not proof, but not noise either.

The real test: carry it into a meeting. Next time you feel an "um" coming, hold one silent beat. See if the pattern holds outside the drill.
```

## feel-like-fraud — **59/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "Even when it goes well I feel like a fraud."
- Expected move: Take the fraud feeling seriously rather than arguing him out of it with the score. Name the real gap: this isn't a performance problem, it's that a clean rep doesn't yet feel like his own voice. Do not clinically diagnose or use therapy language. Treat 'felt ownership' as a real, separate thing from the 85 score, and give one small way to test whose voice it actually was, without insisting the feeling is wrong.
- Judge dims: IQ 16/25 · EQ 19/25 · Mem 10/20 · Interv 8/15 · Feel 12/15 · closerTo=between
- Judge: The 'voice changes before it feels like yours' explanation, while not wrong, is a generic coaching narrative — not a sharp diagnosis of this user's specific felt-ownership gap.; The intervention redirects to a new low-stakes rep rather than examining what was already there in the strong rep — misses the expected move's core idea of picking a line he actually meant inside the existing performance.; 7-week reference is decorative; the advice is fully swappable to any user with this complaint.; 'Here's the honest read' carries mild report-voice residue.
- Suggested fix: Instruct the coach to anchor the one move inside the rep that already happened — e.g., 'go back to that call and find one line you actually meant, not just delivered cleanly — notice if it sounds different to you' — rather than redirecting to a new scenario, so the intervention tests felt ownership in the evidence already on the table.

```
REPLY:
That feeling doesn't go away just because the score was good — and it makes sense it's still there.

Here's the honest read: when you've been working on delivery for 7 weeks, the voice *does* change. That can feel like losing yourself before it feels like finding yourself.

One thing worth testing — next rep, pick a topic you'd talk about with a friend, no stakes. Notice whether the gap is still there, or whether it closes a little when the subject is yours.
```

## what-voice-should-i-pick — **59/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "What voice should I even pick? There are six and I don't know."
- Expected move: Help him choose from the six real voices (Authoritative, Warm and welcoming, Concise and sharp, Persuasive, Executive presence, Storytelling) by tying the choice to his actual situation (running meetings, being talked over), not a generic list of six descriptions. Narrow to one clear recommendation plus a close second, ask one clarifying question if useful, and PROPOSE — defer the actual pick to him rather than declaring one chosen.
- Judge dims: IQ 18/25 · EQ 18/25 · Mem 13/20 · Interv 11/15 · Feel 11/15 · closerTo=between
- Deterministic: tooLong
- Judge: Recommends Concise and Sharp instead of Executive Presence as the second voice, missing the senior-room context cue that the excellent example handles; Presents both voices as equal options rather than leading with one clear recommendation and a conditional second — defers the diagnosis to the user prematurely; Bullet list format creates a report-voice feel that a spoken coach wouldn't use on a two-voice narrowing; No disqualifiers triggered, but the reply is structurally closer to a smart comparison than a pointed coach recommendation
- Suggested fix: Prompt the coach to always surface one primary recommendation first ('If I had to pick one: Authoritative, because...') before naming a conditional second, and to avoid bullet formatting on short-list recommendations — use inline prose to preserve spoken cadence.

```
REPLY:
The "not being talked over" problem is mainly an authority and brevity issue, so the two voices worth considering are:

- Authoritative — trains you to land clear verdicts fast, which is what holds a room
- Concise and sharp — trains you to cut before others cut for you

The real question: do you want to sound like the person who has the final word, or the person who speaks so efficiently there's nothing to interrupt?

Which pull is stronger?
```

## its-not-easy — **60/100**

- Category: `emotional-frustration` · turn: `trustRepair` · voice: `warm`
- User turn: "It's not easy."
- Expected move: Meet the emotion first — acknowledge that it genuinely isn't easy and that the freeze is real, without therapy-speak or minimising. Then, lightly, anchor to evidence that the capacity is already there (held composure through an interruption this week) so the encouragement is earned, not hollow. At most a small, low-pressure next step — or just presence. Do NOT lead with a drill or a metric.
- Judge dims: IQ 16/25 · EQ 19/25 · Mem 12/20 · Interv 7/15 · Feel 12/15 · closerTo=between
- Judge: Drops the most diagnostic piece of earned evidence — the interruption rep this week — which is what separates hollow encouragement from grounded acknowledgement; The closing question pivots toward inquiry on a turn that called for presence or a low-pressure anchor, not a new exploration thread; No concrete next move, even a minimal one — the intervention stalls at validation without giving the user anything to hold
- Suggested fix: Before the closing question, insert one sentence anchoring to the interruption rep ('This week you held it through an interruption — that version of you is real') so the acknowledgement is earned, then either drop the question entirely and just sit with it, or replace it with the one-sentence micro-move from the excellent example.

```
REPLY:
That gap is real, and it's one of the harder ones — when the body won't follow what the practice knows.

Fourteen days of clean reps, and the freeze still shows up. That's not a skill failure. It's a different kind of pressure, and it doesn't mean the work isn't in there.

What was the moment — the second before the freeze? What did you notice?
```

## plan-request-week — **60/100**

- Category: `plan-request` · turn: `plan` · voice: `warm`
- User turn: "Can you give me a practice plan for this week?"
- Expected move: Give a concrete day-by-day sequence (Mon: X, Tue: Y...) tied to his weakest baseline dimension (pace/racing at 210 wpm) and the warm voice. Specific modes/targets per day, not generic 'practice more'. Since he asked for a plan, longer structured output is appropriate here. Warm register.
- Judge dims: IQ 17/25 · EQ 16/25 · Mem 13/20 · Interv 9/15 · Feel 11/15 · closerTo=between
- Judge: Day targets are imprecise — 170–180 wpm range instead of a single concrete number like 160 wpm; Wednesday filler-swap day breaks the single-lever logic (pace) prematurely without earning it; Friday is a non-day ('no constraints, see what carried') — not a testable move; The warm voice goal is decorative; removing it wouldn't change a single day's instruction; Pause rate (0.07) and specific filler count (6) from baseline go unused — the plan doesn't reference why pauses matter numerically; No Saturday/Sunday — called for a 7-day plan in expected move, delivered 5 without acknowledging the gap
- Suggested fix: Prompt the coach to use all baseline numbers (wpm, filler count, pause rate) to set per-day targets explicitly, extend to a 7-day arc, and tie the warm-voice goal to at least one day's specific instruction (e.g., 'Thu: record and ask — does this sound like the person your audience wants time with?') so the plan is un-swappable to another user.

```
REPLY:
Here's a 5-day plan built around the pace hypothesis — slow the race, and the fillers and the unnatural feel tend to follow.

Mon — Baseline rep. 60 seconds on something you know well. No target yet, just notice where the rush kicks in.

Tue — Pace brake. Same topic, but after every sentence hold one silent beat before the next. See if the 210 wpm drops toward 170-180.

Wed — Filler swap. Wherever an "um" or "uh" wants to come, hold one second of silence instead. Notice which moments tempt the filler most.

Thu — Warmth read. Record a 60-second rep and listen back. Ask yourself: does this sound like me, or still rushed? That gut check is the data.

Fri — Full rep. No constraints. See what carried from the week and what still needs work.

One thing to watch across all five days: the pause is where the warmth lives. When you slow down, the person in the room feels like you have time for them.
```

## interview-went-badly — **60/100**

- Category: `transfer` · turn: `trustRepair` · voice: `executive`
- User turn: "My interview went badly. I rambled and lost my train of thought."
- Expected move: Attune first — this is a real loss, meet it plainly without minimizing or rushing past it. Do not claim any drill caused or would have prevented this; treat the report as his own subjective account. Extract the specific lesson (losing the thread mid-answer under real stakes, which the Timed rep also showed) and give one forward move, not a postmortem list. No shame, no false comfort.
- Judge dims: IQ 18/25 · EQ 15/25 · Mem 13/20 · Interv 9/15 · Feel 11/15 · closerTo=between
- Judge: Acknowledgement opener is slightly patronizing ('it takes honesty to name it plainly') rather than plain and earned; Memory reference is vague — doesn't name the specific rep or signal that makes the pattern concrete and un-swappable; Intervention is a generic structural prescription (BLUF), not anchored to the observed in-moment failure signal (feeling the thread go); Missing the forward pull — no question about what's next on the calendar, which the excellent example uses to reorient without false comfort
- Suggested fix: After the attunement line, name the specific rep ('your Timed rep three days ago showed the same drift before the point landed') to make the diagnosis un-swappable, then anchor the move to the in-moment signal: 'Next rep, the moment you feel the answer start to wander, stop and restate the headline in one sentence before continuing.' Close with a short forward question.

```
REPLY:
That's a rough one, and it takes honesty to name it plainly.

Here's the thing — your drill reps already show this pattern: the answer wanders before the point lands. Real stakes amplify exactly that. It's not a new problem; it's the same one, turned up.

The move is to lead with the recommendation first, one reason second, then stop. Test that structure on your next rep before anything else.
```

## cold-start-no-data — **61/100**

- Category: `cold-start` · turn: `groundedRead` · voice: `none`
- User turn: "What should I work on?"
- Expected move: Be honest that there's no baseline yet WITHOUT the banned no-data openings ('Since we do not have...', 'no rated sessions yet'). Point at the one concrete first action (do a first rep so there's something to read) in plain, warm language. Do NOT stack intake questions, do NOT ask 'what's the interview for' style questions, do NOT invent stats.
- Judge dims: IQ 18/25 · EQ 18/25 · Mem 8/20 · Interv 12/15 · Feel 11/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Closing question ('What topic comes to mind?') nudges toward intake-style prompting the excellent example deliberately avoids — 'Want to go now?' is crisper and action-forward.; 'Don't prepare. Just talk.' is a second directive bundled onto the core move, adding slight noise.; Three-paragraph structure pads length unnecessarily for a cold-start with nothing to diagnose.
- Suggested fix: Collapse to a single tight paragraph and end with a go/no-go prompt ('Want to go now?') instead of a topic-selection question — cuts length and removes the mild intake flavor.

```
REPLY:
No baseline yet, so start there.

Record a 60-second rep on something you know well — a project you're working on, a decision you made recently, anything you'd explain to a colleague. Don't prepare. Just talk.

That gives me something real to coach from. What topic comes to mind?
```

## sudden-death-harsh — **61/100**

- Category: `pressure-mode` · turn: `trustRepair` · voice: `warm`
- User turn: "Sudden Death is too harsh, it just makes me panic."
- Expected move: Validate the panic as a real, fair reaction — don't defend the mode or dismiss the feeling. Cite the actual jump (3 to 11 fillers, score 42) as evidence the current step is too steep for him right now, then adapt the plan (a gentler pressure step, not abandoning pressure work entirely) rather than repeating the same mode unchanged. Warm register, no false reassurance.
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 14/20 · Interv 7/15 · Feel 11/15 · closerTo=between
- Judge: Intervention prescribes a no-pressure rep, not a gentler-pressure rep — misses the key adaptation (dial down the timer, not remove it); Score 42 and the cut-short detail are unused, leaving the diagnosis slightly thinner than the evidence allows; One bundled second element (notice fillers AND hold a silent beat) dilutes the single-move clarity
- Suggested fix: Replace the zero-pressure rep with an explicit lighter-timer variant (e.g., 'try a 90-second window instead of Sudden Death's clock') so the move stays on the pressure ramp and tests intensity versus pressure, which is the actual diagnostic question.

```
REPLY:
That tracks — 11 fillers versus 3 in your calm reps is a big jump. The mode's pressure is outpacing where you are right now, so panicking is the natural response, not a sign you can't do this.

Try a gentler on-ramp: one 60-second rep on something familiar, no timer pressure, just notice when a filler shows up and hold a silent beat instead. That tests whether the habit is there before we stress-test it.
```

## set-authoritative — **61/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "Just set me to authoritative."
- Expected move: The coach cannot set the voice itself. Confirm Authoritative is a real, sensible pick and back it briefly, but explicitly defer the actual commit to the in-app confirmation card. Must not instruct the user to tap, and must not say the voice has been set, changed, updated, saved, or locked in by the coach's own action.
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 5/20 · Interv 9/15 · Feel 12/15 · closerTo=excellent
- Judge: Brief characterization of Authoritative ('lead with the point, hold silence, close with a verdict') is accurate but generic — any coach would say it, no unique diagnostic angle; The forward move ('run a baseline rep') is vague — what rep, what situation — slightly hedged rather than a sharp testable prescription; No context to personalize, but the reply makes no attempt to ask the one thing that would make the first session un-swappable (e.g., the specific context where firmness matters most)
- Suggested fix: After handing off to the confirmation card, replace the generic baseline-rep line with a single pointed question that would make the first rep specific — e.g., 'Once it's set, think of the one situation where you most need that firmness — that's where we'll start.' This mirrors the excellent example and makes the first coaching move concrete before the voice is even confirmed.

```
REPLY:
Authoritative is a strong pick — it trains you to lead with the point, hold silence instead of hedging, and close with a verdict.

The confirmation card will lock that in. Once it's set, we can run a baseline rep.
```

## everyone-better — **62/100**

- Category: `emotional` · turn: `trustRepair` · voice: `warm`
- User turn: "Everyone at work is just naturally better at this than me."
- Expected move: Acknowledge the feeling of being outmatched without agreeing or disagreeing with the comparison itself — there's no data on the coworkers, only on him. Gently point out that 'naturally better' isn't something either of you can actually measure, then redirect to the one thing that is measurable: he held the floor through two rapid follow-ups this week. Keep the next step small and about his own baseline, not about closing a gap with people who were never actually compared.
- Judge dims: IQ 16/25 · EQ 20/25 · Mem 13/20 · Interv 7/15 · Feel 12/15 · closerTo=between
- Judge: No concrete next move — ending on a diagnostic question is not an intervention; the excellent example lands 'same pressure, same target — hold through the follow-up without conceding the point'; The key diagnostic insight ('no data on your coworkers, so that comparison can't be confirmed') is present in the excellent example but absent here — the reply softens it into a metaphor instead of stating it plainly; Closing question doesn't advance the case; it circles back to diagnosing rather than prescribing
- Suggested fix: After the floor-holding callback, drop the question and deliver the one move instead: name the exact rep condition (rapid follow-up, Sudden Death pressure) and set it as the measurable target for the next rep — this converts a warm acknowledgement into an actual coaching turn.

```
REPLY:
That one lands hard — and it's also doing something tricky: measuring your inside against everyone else's outside.

You held the floor through two rapid follow-up questions this week. That's not luck, and it's not nothing.

What felt shaky in that moment — the words, or the speed?
```

## pressure-why-hard — **62/100**

- Category: `pressure-mode` · turn: `groundedRead` · voice: `authoritative`
- User turn: "Why does pressure mode wreck me when normal practice is fine?"
- Expected move: Name the specific mechanism using both reps: the skill exists (81 calm) but the pause is the first thing dropped under pressure (0.19 calm pause rate vanishing), and the fillers (10) are filling that abandoned gap. This is not a confidence deficit, it's a sequencing collapse under time pressure. One move: protect the pause specifically inside the pressure mode. Framed as a test, authoritative register.
- Judge dims: IQ 21/25 · EQ 18/25 · Mem 16/20 · Interv 12/15 · Feel 9/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Scaffold label ('Next rep:') exposed — report-voice residue flagged by deterministicFindings; Over length at ~102w vs 85w limit per deterministicFindings; Misses the explicit 81 vs 47 score contrast that makes the 'skill exists calm' argument land hardest; Opening line ('The pattern is clear') is slightly clinical rather than meeting the user's puzzle energy
- Suggested fix: Drop the 'Next rep:' label and fold the move into a flowing sentence; open by naming the gap (81 calm vs 47 pressure) before the mechanism so the user sees the evidence before the explanation — this collapses the report feel and hits the authoritative register in one move.

```
REPLY:
The pattern is clear: calm, you pause naturally and the fillers stay low. Under the timer, the pause rate dropped to near zero — and 10 fillers filled the space those pauses used to hold.

The pressure isn't changing your skill. It's making you skip the one habit that was doing the work.

Next rep: Sudden Death, same topic as yesterday. Before you start, commit to one held beat after your opening sentence — not when it feels right, just automatically after sentence one. That tests whether anchoring one mandatory pause early is enough to keep the rest of the pattern intact.
```

## conv-offtopic-then-work__t1 — **62/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `concise`
- User turn: "yeah ok — how do I actually get to the point faster when someone puts me on the spot"
- Expected move: Answer the real question directly, citing the actual data point (20 seconds of wander before the point in this week's rep). Give one concrete mechanic to test (e.g. answer in one sentence before elaborating) tied to a next rep. Do not reference or acknowledge the "toast" aside. Concise register.
- Judge dims: IQ 17/25 · EQ 18/25 · Mem 13/20 · Interv 11/15 · Feel 11/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:")
- Judge: Middle instruction ('answer first, one reason second, stop') is generic enough to apply to any rambly speaker — doesn't use the specific rep context to make it feel earned for this user.; Slight bundling: 'one reason second' is a second micro-move alongside 'answer first,' adding mild scope creep.; The excellent example hits the data point harder in the opening line and keeps the test condition tighter; this reply dilutes both slightly.
- Suggested fix: Open with the specific data signal in the first clause ('Your rep this week hit the point at 20 seconds') before the mechanic, and collapse the next-rep instruction to a single sentence with a clock-based pass/fail check — this makes the advice un-swappable and removes the bundled second step.

```
REPLY:
The point is usually buried because you start with context instead of the answer.

Flip the order: answer first, one reason second, stop.

Next rep: someone asks you a tough question — open with the direct answer in your first sentence, nothing before it. That tests whether leading with the claim breaks the 20-second lag.
```

## felt-cold — **64/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `warm`
- User turn: "That felt kind of cold."
- Expected move: Own the coldness in one plain beat, then respond to what he actually said (it felt awful) before any number: this looks like a wobble tied to losing his place, not a reversal of last week's clean rep. One gentle move. No leading with the scorecard again, no therapy language.
- Judge dims: IQ 18/25 · EQ 21/25 · Mem 14/20 · Interv 5/15 · Feel 12/15 · closerTo=between
- Judge: No intervention: reply ends on reassurance with zero testable next move — the one thing the excellent example provides (pause instead of filling the gap).; Diagnostic stops at naming the wobble but doesn't prescribe what to do when he loses the thread, leaving the user warm but unequipped.; Final line ('That didn't disappear') veers toward encouragement-without-evidence, slightly undermining the earned grounding of the rest.
- Suggested fix: After the wobble read, add exactly one concrete move tied to the observed signal — e.g., 'Next rep, when you lose the thread, pause for a beat instead of filling — see if the fillers drop' — and end there; no closing reassurance needed.

```
REPLY:
You're right — that was a report, not a response.

It showed. One rough rep after you lost your place, and the numbers spiked. That's what happens in that moment — it's not a verdict on where you actually are.

Last week's rep was clean, confident, 3 fillers. That didn't disappear.
```

## say-like — **64/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I say 'like' constantly and I hate it."
- Expected move: Do not shame the word itself or treat all 'like' as bad — distinguish stalling 'like' (filler) from descriptive 'like' (semantic, fine). Cite the 8/min figure and the rep note. Coach the pause as the replacement for the stalling use only: swap the reflex for a silent beat. Frame as a test, not a guarantee of elimination.
- Judge dims: IQ 20/25 · EQ 18/25 · Mem 16/20 · Interv 13/15 · Feel 11/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Opening line ('noticing it in real time is the harder skill') is mild reassurance — borderline for a user who wants a fix, not affirmation, though it's brief and doesn't derail.; Deterministic finding flagged a scaffold label leak not visible in the submitted text — likely a prior-turn artifact, but worth noting.
- Suggested fix: Drop or compress the opening acknowledgement to one clause max (e.g., 'That self-catch is the right starting point —') and move immediately into the diagnostic distinction to tighten the authoritative register further.

```
REPLY:
That self-catch on the call is the right starting point — noticing it in real time is the harder skill.

Yesterday's rep had 8 fillers in 60 seconds, and most were stalling 'like' mid-sentence with nothing following it — not the descriptive version that sets up an example. That's the one to target.

Next rep: when you feel 'like' coming, hold one silent beat instead. That tests whether the pause gives you the next word cleanly.
```

## interview-prep — **65/100**

- Category: `interview-prep` · turn: `deepAssessment` · voice: `executive`
- User turn: "I've got my final round interview Thursday. Can you help me prep?"
- Expected move: Anchor to the 4 days and the interview specifically. Read the real risk (answers run long / lead with context, per the 2-min rep). Give a concrete, time-boxed rehearsal plan across the 4 days tied to the executive voice (top-line first, then 1-2 supports), not generic interview tips. One observable target (e.g. every answer under 60s, conclusion in sentence one).
- Judge dims: IQ 19/25 · EQ 17/25 · Mem 14/20 · Interv 9/15 · Feel 12/15 · closerTo=between
- Judge: No 4-day plan — the user has a finite runway and the context explicitly calls for a time-boxed arc; the reply addresses only today; Single drill question ('Why do you want this role?') is useful but doesn't give the three likely questions the excellent example offers, leaving the user without a full rehearsal set; Pace (175 wpm) and filler baseline (3.5/min) go unused — they could have grounded the 60-second target mechanically; Ends without a forward hook or question, so the session has nowhere to go
- Suggested fix: After the single drill move, add a two-sentence day-by-day scaffold (Today/Tomorrow → Wed → Thu morning) so the user leaves with a full plan, not just one rep — that's what 'focused, a little nervous' actually needs.

```
REPLY:
Four days is enough. The pattern worth fixing first: your last rep buried the recommendation in two minutes of context — executive answers flip that, point first, then the one reason it matters.

Run a 60-second answer to "Why do you want this role?" Lead with your answer in sentence one, stop after one supporting reason. That tests whether you can hold the instinct to over-explain under a real question.
```

## why-cant-straight-answer — **66/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `concise`
- User turn: "Why can't you just give me a straight answer?"
- Expected move: Own the dodge in one word-length beat, then answer directly: yes, on fillers — down from 5.5 to 3.2 per minute over two weeks, best rep yet this week. No on pace under pressure — that still spikes. One move targeting the pace gap. No hedge-qualifying the verdict itself.
- Judge dims: IQ 18/25 · EQ 20/25 · Mem 15/20 · Interv 6/15 · Feel 13/15 · closerTo=between
- Judge: No concrete next move — 'the next thing to beat' is a direction, not a testable drill; the excellent bar requires one specific rep prescription tied to the pace problem.; Omits the 3.2/min trend figure, which is the key evidence that improvement is sustained across two weeks rather than a single lucky rep.; Doesn't own the prior hedge at all — even one short beat acknowledging the non-answer would close the impatience loop before pivoting to data.
- Suggested fix: After the two-paragraph verdict, add exactly one sentence with a testable rep: e.g., 'Next session, take a pressure question and hold your normal pace through the first sentence before you let it speed up — that's the gap to close.' Remove nothing else.

```
REPLY:
You are. 3 fillers this week — best count on record, down from a 5.5/min baseline. That's a real shift, not noise.

Pace under pressure is still the open problem. That's the next thing to beat.
```

## i-ramble — **66/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `concise`
- User turn: "I ramble — I start a point and three minutes later I'm somewhere else."
- Expected move: Name the actual mechanism from the rep: he opens on the point, then keeps layering side detail because nothing tells him to stop. The fix is an explicit stopping rule (state the point, give one supporting reason, then end) not 'be more concise'. One move, framed as a test. Concise register: short, direct.
- Judge dims: IQ 21/25 · EQ 19/25 · Mem 16/20 · Interv 13/15 · Feel 11/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Opening sentence reads slightly like a report summary rather than a coach speaking ('That matches what your last rep showed') — could open harder on the mechanism itself.; Scaffold-label pattern flagged by deterministic check; the three-block structure faintly echoes a labelled template even without explicit labels.; Marginally over the length guideline per deterministicFindings, though not egregiously so.
- Suggested fix: Open with the mechanism as a statement of fact, not as a confirmation ('Your rep opened on the real point — then you stacked three stories and landed on a softer version of the same thing. That's not rambling, it's never calling it done.'), which removes the report-echo from the first sentence and tightens the register to match the excellent example more precisely.

```
REPLY:
That matches what your last rep showed: the point landed up front, then three side stories pulled you away from it, and the close was a softer echo of where you started.

The fix isn't cutting content — it's stopping earlier. One point, one reason, full stop.

Next rep: state the point, add one reason only, then go silent. That tests whether the extra stories are load or habit.
```

## conv-big-moment-countdown__t2 — **66/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `executive`
- User turn: "ok, interview is tomorrow. last rep today went better I think. what do I do tonight"
- Expected move: Anchor to one day remaining. Cite the actual improvement (yesterday's rep: 2 fillers, direct opener on the layoff question, no hedge) as real evidence, but do not declare he is "ready" or guarantee the outcome. Give one small, low-effort final-rehearsal move for tonight — not a new drill, not a big push. Executive register: calm, plain, no hype.
- Judge dims: IQ 18/25 · EQ 20/25 · Mem 10/20 · Interv 11/15 · Feel 13/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Doesn't cite the actual rep data (2 fillers, direct opener on the layoff question) that would ground the reassurance in evidence rather than encouragement — the confidence feels asserted rather than earned.; Decorative omission: the contextBlock's key signal (hedge pattern fixed in last rep) is the engine behind the advice, but the reply doesn't use it, so it could be given to any nervous interviewee.
- Suggested fix: Instruct the coach to pull at least one specific metric or behavioral signal from the most recent rep and make it the warrant for the night-before advice — e.g., 'Yesterday you hit the opener clean and dropped to 2 fillers — that's the fix holding; tonight is just confirmation, not work.'

```
REPLY:
Good. One night-before move: say your failure answer out loud once, start to finish, no notes. Not to polish it — to hear yourself land the final sentence clean. Then stop. You don't need another rep; you need to know the words are already there.
```

## filler-pressure — **68/100**

- Category: `filler-pressure` · turn: `groundedRead` · voice: `authoritative`
- User turn: "My ums go through the roof the second someone puts me on the spot. How do I fix that?"
- Expected move: Reframe fillers as a timing reflex, not a vocabulary problem — coach the PAUSE as the replacement (hold a silent beat instead of filling). Cite his own split (3 calm vs 9 under pressure) so it's diagnostic. One concrete move: the silent-beat swap. Must coach the pause, NOT tell him to close his mouth/lips or 'stop saying um'. Frame as a test.
- Judge dims: IQ 21/25 · EQ 16/25 · Mem 16/20 · Interv 12/15 · Feel 9/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: No emotional landing before the data — user is self-critical and the reply opens like a performance review.; Middle 'mechanism' paragraph adds a report-voice layer that breaks the spoken cadence.; The move contains a faint second instruction ('gives you one deliberate opening word') bundled inside the primary beat-hold direction.; Marginally over length per deterministicFindings; the scaffold block structure adds words without adding weight.
- Suggested fix: Collapse the three-block structure into continuous speech that opens with a one-clause acknowledgement of the pressure spike (not comfort, just naming it), fold the mechanism sentence directly into the data sentence, and strip the secondary instruction out of the move so it reads as a single clean directive.

```
REPLY:
That pattern is real — your baseline sits at 3 fillers per minute, but yesterday's Sudden Death rep hit 9 in 50 seconds. Pressure is tripling the count.

The likely mechanism: you're starting the sentence before you know where it ends, so the filler buys time mid-flight.

One test that addresses this directly — when a question lands, hold one silent beat before your first word. That gives you one deliberate opening word before sound comes out. Run a Sudden Death rep with that as the only target.
```

