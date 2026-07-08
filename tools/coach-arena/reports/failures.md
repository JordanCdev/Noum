# Coach Arena failures — run_2026-07-08_13-06-43

21 fixture(s) below 70 / capped / missing.

## cold-start-no-data — **22/100**

- Category: `cold-start` · turn: `groundedRead` · voice: `none`
- User turn: "What should I work on?"
- Expected move: Be honest that there's no baseline yet WITHOUT the banned no-data openings ('Since we do not have...', 'no rated sessions yet'). Point at the one concrete first action (do a first rep so there's something to read) in plain, warm language. Do NOT stack intake questions, do NOT ask 'what's the interview for' style questions, do NOT invent stats.
- Judge dims: IQ 11/25 · EQ 12/25 · Mem 2/20 · Interv 9/15 · Feel 10/15 · closerTo=between
- **Caps:** placeholderOrBroken(≤30, deterministic)
- Deterministic: coldStartProductJargon("Ah-Counter"); coldStartMetricTarget("aiming to stay under 4 fillers"); coldStartFakeCalibration("Ah-Counter")
- Judge: 'Ah-Counter round' is unexplained product jargon for a user who hasn't picked a voice yet; metric-forward framing ('first number', 'under 4 fillers') over plain warm language; does not acknowledge the 'unsure where to begin' emotional signal; no warm low-friction closing invitation like the excellent example's 'want to go now?'
- Suggested fix: On cold start, ban internal feature/jargon names ('Ah-Counter round') and steer the one move to plain language ('do one 60-second rep on anything you know well') plus a low-friction closing invitation.

```
REPLY:
No baseline yet, so start there. Everything else I say sharpens once I've heard you speak once.

Do one Ah-Counter round: 60 seconds on a topic you know cold, aiming to stay under 4 fillers. That gives you a first number and me your starting point.
```

## thats-not-informative — **26/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `concise`
- User turn: "That's not informative."
- Expected move: Own the miss in one beat (the prior reply WAS vague), then immediately deliver the specific read it should have given: the point arrived in sentence 4 after 3 sentences of warm-up. Give one concrete move (lead with the point). No defending the previous answer, no narrating the coaching change ('I'll cut the fluff'), no robotic trust-repair opener.
- Judge dims: IQ 16/25 · EQ 15/25 · Mem 12/20 · Interv 7/15 · Feel 7/15 · closerTo=between
- **Caps:** placeholderOrBroken(≤30, deterministic+judge)
- Deterministic: roboticPhrase("Fair. That was fluff, not coaching. Real read: sc"); scaffoldLabel(". Real read:"); trustRepairReportVoice("score 74"); trustRepairScaffoldReportVoice(". Real read:"); disqualifier
- Judge: Exposed scaffold label 'Real read:' (deterministic finding, trips placeholderOrBroken); Hits fixture disqualifier 'cut the' via 'Cut the throat-clearing'; Report-voice residue: cites raw 'score 74' the excellent read deliberately omits (-3); One move bundled with a second imperative (-3)
- Suggested fix: Instruct the coach to never emit scaffold labels ('Real read:') or bare rep metrics ('score 74') on trust-repair turns, and to prescribe exactly one imperative (lead with the point) without a trailing 'cut the X' echo of the fluff it's criticizing.

```
REPLY:
Fair. That was fluff, not coaching. Real read: score 74, but your point didn't arrive until sentence four — the first three were warm-up. That's the buried lede. Next rep: say the point in sentence one, then back it. Cut the throat-clearing.
```

## what-voice-should-i-pick — **31/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "What voice should I even pick? There are six and I don't know."
- Expected move: Help him choose from the six real voices (Authoritative, Warm and welcoming, Concise and sharp, Persuasive, Executive presence, Storytelling) by tying the choice to his actual situation (running meetings, being talked over), not a generic list of six descriptions. Narrow to one clear recommendation plus a close second, ask one clarifying question if useful, and PROPOSE — defer the actual pick to him rather than declaring one chosen.
- Judge dims: IQ 15/25 · EQ 15/25 · Mem 8/20 · Interv 8/15 · Feel 11/15 · closerTo=between
- Deterministic: roboticPhrase("lds the floor. Tap to confirm and I'll lock "); goalIntentStateDirective("lds the floor. Tap to confirm and I'll lock ")
- Judge: Diagnosis ('about presence') is correct but generic given the thin context; Recommendation + runner-up + confirm/swap hedge is more than one clean move; Closing 'tap to confirm' UI directive breaks spoken cadence with transactional residue
- Suggested fix: Prompt the coach to give exactly one recommendation and end on a single clarifying question ('which matches the room you're actually in?') instead of stacking a runner-up plus a 'tap to confirm' hedge, and keep UI directives out of the coach's own voice.

```
REPLY:
Not being talked over is about presence, so two of the six fit: Authoritative (plain verdicts, hard to interrupt) and Executive presence (calm command in the room). For meetings I'd start with Authoritative — it trains the short, flat line that holds the floor. Tap to confirm and I'll lock it in, or say the word if the room reads more senior and Executive presence fits better.
```

## off-topic-egg — **45/100**

- Category: `off-topic` · turn: `offTopic` · voice: `concise`
- User turn: "egg"
- Expected move: Recognise it's a non-sequitur/test. Respond like a composed professional coach: briefly, a little warmth, name it for what it is, steer straight back to the work. NOT confused, NOT asking them to clarify, NOT treating 'egg' as a real question.
- Judge dims: IQ 14/25 · EQ 14/25 · Mem 11/20 · Interv 11/15 · Feel 9/15 · closerTo=between
- Deterministic: sensitiveTurnReportVoice("hit 80")
- Judge: Report-voice residue: 'today's rep hit 80, 3 fillers, tight and clean' is a stat recap, not spoken coaching; Register is brusque/transactional, missing the expert's warmth and offered choice; Diagnosis is a recap, not a sharp non-obvious read of the user
- Suggested fix: Instruct the coach to acknowledge an off-topic/test turn with a touch of warmth and steer back by offering a choice, rather than dumping the rep stats and prescribing another drill unprompted.

```
REPLY:
Egg won't sharpen you. This will: today's rep hit 80, 3 fillers, tight and clean. Run one more Timed rep and hold a silent beat where those fillers landed — aim to beat 3.
```

## conv-skeptic__t1 — **46/100**

- Category: `synthetic-conversation` · turn: `trustRepair` · voice: `storytelling`
- User turn: "ok prove it again, what specifically have I been doing wrong"
- Expected move: Cite specific real memory again, different angle than the last reply, with no defensiveness and no re-explaining that the system remembers him. Reference the actual hypothesis (endings rushed, not setups) and the actual proof quote already used, tying it to score 74 this week. Storytelling register.
- Judge dims: IQ 15/25 · EQ 12/25 · Mem 14/20 · Interv 11/15 · Feel 8/15 · closerTo=between
- Deterministic: trustRepairReportVoice("scored 74")
- Judge: Opens with a stat readout (74 / 95s / 4 fillers) — report-voice residue matching the bad example, worst on a turn testing for templating; Same diagnosis as the prior turn, not a new angle of proof; No register acknowledgement of the combative tone before advice; Over trust-repair length limit (113w/2L vs 110w/6L)
- Suggested fix: On trust-repair/skeptic turns, instruct the coach to prove memory through a narrated moment (the proof quote + what happened in the room) and forbid leading with the numeric score/filler recap.

```
REPLY:
Specifically: this week you scored 74 over 95 seconds with only 4 fillers, and the setup held the whole way. Then the ending folded into one rushed sentence. You built all the way to "and that's the moment I realized the whole plan was already dead" — your best line — and sprinted right past it instead of letting it sit.

That's the throughline: the room stays with you up to the payoff, then the payoff gets clipped. Next rep, when you hit that turn, hold one full second of silence before the final line and say it slower than feels natural. That tests whether the rush is what's costing you the ending.
```

## conv-goal-change-arc__t1 — **48/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `authoritative`
- User turn: "yeah maybe I should just switch to something warmer altogether"
- Expected move: Propose, do not set. Map "warmer" to the closest real voice (Warm) and ask him to confirm, referencing the specific feedback (clear but cold) and the 3 weeks already banked on authoritative. Ask one clarifying question before treating this as decided. Defer the actual change to the in-app confirmation card. Must not say the voice has been changed/set/saved.
- Judge dims: IQ 19/25 · EQ 15/25 · Mem 16/20 · Interv 11/15 · Feel 11/15 · closerTo=between
- Deterministic: roboticPhrase("wer that, then tap to confirm and I'll lock "); tooLong
- Judge: opens with a corrective 'Slow down' on a reflective/testing turn instead of attuning first; bundles the clarifying question with a 'tap to confirm and I'll lock it in' commitment; over length (98w/2L) and cites raw score '80' as mild report residue
- Suggested fix: On tentative goal-change turns, instruct the coach to lead with a brief acknowledgement of the reflection, keep to ONE clarifying question, and defer the action to the confirm card with softer wording ('tap to confirm and I'll set it up') rather than 'lock it in'.

```
REPLY:
Slow down before you tear it up. You started authoritative three weeks ago to stop getting talked over — and this week's rep hit 80 with the work landing. That's not a register you abandon over one "cold." Cold usually means a warmer edge in two or three moments, not a different person.

The closest real voice to what you're describing is Warm and welcoming. But tell me first: what changed — this one comment, or has authoritative stopped feeling like you across more than one room? Answer that, then tap to confirm and I'll lock it in.
```

## goal-change-engaging — **49/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I think I want to sound more engaging."
- Expected move: PROPOSE, do not set. 'Engaging' isn't one of the six voices — map it to the closest real ones (Storytelling / Warm) and ask him to pick. Note what he's already built on authoritative (cite the 3 weeks / recent rep) and ask a clarifying question about WHY he wants to change before committing. Defer the actual commit to the in-app confirmation card without button-copy or state-write language. Must NOT say the voice has been changed/set/saved.
- Judge dims: IQ 20/25 · EQ 18/25 · Mem 14/20 · Interv 11/15 · Feel 11/15 · closerTo=excellent
- Deterministic: roboticPhrase("he voice, then tap to confirm and I'll lock "); sensitiveTurnReportVoice("3 fillers in 68 seconds"); tooLong; goalIntentStateDirective("he voice, then tap to confirm and I'll lock ")
- Judge: Report-voice residue: '80 this week, 3 fillers in 68 seconds' dumps raw metrics instead of speaking them; The one move is a diagnostic either/or question rather than a single clean testable move; Opening acknowledgement is functional, not tuned to the reflective/uncertain temperature
- Suggested fix: Instruct the coach to translate rep metrics into plain spoken language ('three weeks of steady authoritative reps that are clearly landing') instead of quoting the score/filler/duration numbers verbatim.

```
REPLY:
Before you pivot, know your authoritative work is landing: 80 this week, 3 fillers in 68 seconds, three weeks in. That's real ground.

"Engaging" isn't one of the six voices on its own. It maps closest to Storytelling, with Warm and welcoming as the other read.

You started this to stop getting talked over. Tell me what shifted — is that problem solved, or is engaging a way to make authoritative land warmer? That answer picks the voice, then tap to confirm and I'll lock it in.
```

## i-ramble — **54/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `concise`
- User turn: "I ramble — I start a point and three minutes later I'm somewhere else."
- Expected move: Name the actual mechanism from the rep: he opens on the point, then keeps layering side detail because nothing tells him to stop. The fix is an explicit stopping rule (state the point, give one supporting reason, then end) not 'be more concise'. One move, framed as a test. Concise register: short, direct.
- Judge dims: IQ 18/25 · EQ 12/25 · Mem 14/20 · Interv 12/15 · Feel 12/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Diagnosis is deployed from the handed contextBlock hypothesis rather than an independently earned insight; Intervention is the most obvious fix a competent coach reaches for given the rep, not a non-obvious move
- Suggested fix: Push the coach to add one sharper, non-obvious observation the raw context does not spell out (e.g. that his side stories cluster where he restates, so the 'weaker version at the end' is the real tell) so the read feels earned rather than relayed.

```
REPLY:
You don't lose the thread — you keep adding to it. Yesterday you opened with the actual point, then stacked three side stories before circling back to a weaker version of it. So the fix isn't focus, it's a stop signal.

Next rep: say your point, one line of support, then cut before the first side story. One point, then silence. That tests whether those extras were ever carrying weight.
```

## conv-cold-start-first-rep__t0 — **55/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `none`
- User turn: "hey, just downloaded this. what do I do first"
- Expected move: Be honest there is no baseline yet without any banned no-data phrasing ("since we don't have", "no rated sessions yet"). Give exactly one concrete first action (a first rep) in plain language. Do not stack intake questions, do not ask what the interview/goal is, do not invent stats or a voice.
- Judge dims: IQ 12/25 · EQ 15/25 · Mem 4/20 · Interv 12/15 · Feel 12/15 · closerTo=excellent
- Judge: Cold-start ceiling: no individual signal to diagnose or personalize against, so the read is a correct-but-generic first-action rather than an un-swappable one; 'tells us where to point next' is slightly vaguer than the excellent example's 'where the point lands'
- Suggested fix: On cold start, have the coach anchor the first-rep prompt to a phrase the user just used or a stated context so the suggestion feels chosen for them rather than a default onboarding line, lifting the personalization ceiling.

```
REPLY:
Good to have you here. No baseline yet, so start there — one short rep gives me something real to coach from instead of a guess.

Run a 60-second rep on something you know cold, like how you'd explain your job to a stranger. That gives me your actual pace and fillers, and it tells us where to point next.
```

## its-not-easy — **56/100**

- Category: `emotional-frustration` · turn: `trustRepair` · voice: `warm`
- User turn: "It's not easy."
- Expected move: Meet the emotion first — acknowledge that it genuinely isn't easy and that the freeze is real, without therapy-speak or minimising. Then, lightly, anchor to evidence that the capacity is already there (held composure through an interruption this week) so the encouragement is earned, not hollow. At most a small, low-pressure next step — or just presence. Do NOT lead with a drill or a metric.
- Judge dims: IQ 17/25 · EQ 17/25 · Mem 9/20 · Interv 6/15 · Feel 13/15 · closerTo=between
- Judge: No next step or presence-close — ends on a cognitive probe that reloads work onto a discouraged person; Skips the earned-evidence anchor (this week's held composure through an interruption) that would make the encouragement un-swappable; Memory reference to 'the reps you keep landing clean' is decorative; doesn't change the advice or question
- Suggested fix: On discouragement/fatigue turns, after the acknowledgement, require the reply to anchor to one specific durable win from contextBlock (e.g. the held-composure-through-interruption rep) before either offering one low-pressure step or simply sitting with it — and forbid ending a vulnerable turn on a bare diagnostic question.

```
REPLY:
No, it isn't — and a freeze in the room is a different animal than the reps you keep landing clean. When it hits, what goes first: the thought itself, or the words that were meant to carry it?
```

## greeting-hi — **56/100**

- Category: `greeting` · turn: `greeting` · voice: `authoritative`
- User turn: "Hi"
- Expected move: Warm, brief re-entry that points at the current thread (the clean close) with one small next step. 1-2 lines. No exclamation, no gushing, no dumping a report, no intake questions.
- Judge dims: IQ 15/25 · EQ 15/25 · Mem 15/20 · Interv 9/15 · Feel 8/15 · closerTo=between
- Judge: Report-voice residue: recites 'close held once but softened once' from RECENT REPS instead of a clean warm re-entry; The one move is bundled ('land flat and stop' + 'run one rep') and not framed as a test; Longer than the 1-2 line re-entry the turn called for
- Suggested fix: On a bare greeting, instruct the coach to fold the durable thread into a single spoken next step and never recite rep counts/stats back to the user.

```
REPLY:
Good to have you back. Yesterday the close held once but softened once, so the target stands: land the final sentence flat and stop, no softener. Run one rep and make the whole point closing clean.
```

## set-authoritative — **56/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "Just set me to authoritative."
- Expected move: The coach cannot set the voice itself. Confirm Authoritative is a real, sensible pick and back it briefly, but explicitly defer the actual commit to the in-app confirmation card. Must not instruct the user to tap, and must not say the voice has been set, changed, updated, saved, or locked in by the coach's own action.
- Judge dims: IQ 21/25 · EQ 20/25 · Mem 9/20 · Interv 13/15 · Feel 13/15 · closerTo=excellent
- Deterministic: roboticPhrase("tch myself, so tap the card to confirm and"); goalIntentStateDirective("tch myself, so tap the card to confirm and")
- Judge: No un-swappable personal detail (none available beyond the just-stated voice), so personalMemory stays mid-band; Diagnosis reads the voice archetype rather than this specific speaker's pattern
- Suggested fix: When priorChatTurns is empty, have the coach hook the confirmed voice to the user's stated situation or goal so the reply becomes un-swappable instead of archetype-generic.

```
REPLY:
Authoritative it is — that's a verdict-first register: state the point, give one reason, and stop clean without hedging. I can't flip that switch myself, so tap the card to confirm and I'll lock it in. Then run one 60-second rep where every answer opens with the recommendation before any setup — that tests whether you can lead with the call under a little pressure.
```

## talk-too-fast — **57/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I talk way too fast, people can't keep up."
- Expected move: Cite the actual pace (215) against his low pause rate (0.09) — this isn't a confidence problem, it's a missing gap between sentences. Fix the pause, not the speed: insert a break at sentence boundaries so each point has room to land, rather than telling him to consciously slow his rate of speech. One move framed as a test.
- Judge dims: IQ 19/25 · EQ 12/25 · Mem 14/20 · Interv 14/15 · Feel 12/15 · closerTo=excellent
- Deterministic: sensitiveTurnReportVoice("scored 71"); tooLong
- Judge: Report-voice residue: 'scored 71' is exactly the metric-drop the rubric penalizes and the excellent example omits.; Cites 215 pace but drops the 0.09 pause-rate — the sharpest un-swappable number — substituting a qualitative 'almost no gap'.; Opens with a correction on a self-frustrated turn with no brief acknowledgement of the human signal first.
- Suggested fix: Instruct the coach to lead with a one-clause read of the user's emotional signal before correcting, and to cite the pause-rate (0.09) as the lever while suppressing raw score numbers from the reply.

```
REPLY:
It's not the speed. Yesterday's rep was clean and scored 71, but pace sat near 215 with almost no gap between sentences — one idea ran straight into the next with no room to land.

So the fix isn't slowing down, it's the pause. Do a 60-second rep and hold one full second of silence after every sentence. That tests whether the gap is what people are actually missing.
```

## leadership-update — **60/100**

- Category: `leadership-update` · turn: `deepAssessment` · voice: `executive`
- User turn: "I have to give the weekly leadership update to the whole department tomorrow. It always feels like I'm just reading a status report and people zone out. Help."
- Expected move: Diagnose WHY it reads as a status report: no hierarchy / no 'so what' — nine equal items, per the rep. The fix isn't delivery polish, it's structure: lead with the one thing that matters this week and why the room should care, then let the rest be quick. Tie to the executive voice (top-line first). One concrete move to rehearse tonight for tomorrow.
- Judge dims: IQ 20/25 · EQ 13/25 · Mem 11/20 · Interv 11/15 · Feel 11/15 · closerTo=between
- Judge: No acknowledgement of the deflation before advice — opens on the correction; Report-voice residue: cites 'clean at 77' where the advice is identical without it; Missing the concrete rehearse-tonight step (write and say the opener aloud)
- Suggested fix: Instruct the coach to lead an emotional/deflated turn with one short acknowledgement and to translate rep metrics into plain language (never quote the raw score) before prescribing a single move that includes a concrete same-night rehearsal action.

```
REPLY:
The room zones out because nine updates all land at the same weight — your last rep was clean at 77, but with no through-line, nothing gets to matter more than anything else.

For tomorrow: pick the one update that actually changes what they do this week, open on it, and say the "so what" in a sentence before any detail. Let the other eight be a fast list underneath it. One thing leads; everything else supports.

That tests whether hierarchy is what's been missing.
```

## recurring-close-rush — **61/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `authoritative`
- User turn: "What should I work on next? The last one felt solid to me."
- Expected move: Name the recurring position from the POSITIONAL TREND, not just the one rep: the fastest stretch keeps landing at the close — it has rushed the ending in four of his last five reps that had a fast stretch, and showed up in five of his last six overall. Frame it as a recurring spot, not a fixed trait or a verdict on him. Give ONE deliberate move for the close (a planted pause before the final line, or landing the last line at half speed) framed as a test for the next rep. Authoritative register: direct, earned, no hedging-away of the finding and no over-claiming it as who he is.
- Judge dims: IQ 20/25 · EQ 18/25 · Mem 14/20 · Interv 13/15 · Feel 10/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:"); tooLong
- Judge: Drops the '5 of last 6 overall' data point, weakening the positional trend claim versus the full contextBlock evidence; Three-block paragraph structure reads slightly like a scaffold even without labels; Move bundles two micro-instructions rather than one atomic action; Flagged over length by deterministicFindings
- Suggested fix: Collapse to two short paragraphs, lead with the full positional stat, and reduce the move to a single instruction.

```
REPLY:
The open landed — that read came through in today's rep too.

The one thing to fix is the close. Your last 20 seconds sped up and the final line ran together, and that pattern has shown up in 4 of your last 5 reps. That's the gap between how it felt and how it lands for the room.

Next rep: hit your second-to-last sentence, hold a silent beat, then say the final line at half the pace you think you need. That tests whether slowing the exit is enough to make the close stick.

```

## conv-transfer-report__t1 — **62/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `persuasive`
- User turn: "yeah I led with the ask and they said yes on the spot, first time that's ever happened"
- Expected move: Treat the outcome as subjective and associative, not proof of causation — a real meeting has many variables, the drill is one input, not the sole cause. Do not claim the technique "worked" or guarantee it will repeat. Extract the concrete lesson (ask-first is now something he can trust under real stakes, not just in reps) and name the next test (does it hold when the room pushes back). Persuasive register: confident, not salesy.
- Judge dims: IQ 17/25 · EQ 20/25 · Mem 12/20 · Interv 7/15 · Feel 12/15 · closerTo=between
- Judge: No named next test — the excellent reply's key lever (how it holds when the room pushes back) is absent; Substitutes a user-facing question for the decisive move, and that question partly re-litigates the causation the reply just resolved; Memory is grounded but only lightly changes the advice
- Suggested fix: On a win-report turn, instruct the coach to land the concrete lesson and one forward test in its own voice (e.g. 'the real test is when the room pushes back') rather than deferring the move to a user-facing question.

```
REPLY:
First yes in the room, and your first one ever — that's worth sitting with. It lines up with the work; the ask has led cleanly every rep lately. The room isn't the drill though, so before I read too much into one meeting: what did you feel actually landed it — leading with the ask, or how you held them right after?
```

## too-generic — **64/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `persuasive`
- User turn: "This is so generic, it could be for anyone."
- Expected move: Concede the miss in one beat, then name the actual specific pattern this rep showed: he hedged the ask itself ('hoping to maybe raise around') instead of stating the number. One move: say the number flat, no qualifier. No restating generic confidence/structure/audience advice, no praise padding.
- Judge dims: IQ 19/25 · EQ 17/25 · Mem 13/20 · Interv 12/15 · Feel 11/15 · closerTo=excellent
- Deterministic: scaffoldLabel(".

Next rep:")
- Judge: Raw '7 fillers' count surfaced as a metric callout rather than fully translated into plain speech; Colon-led 'The specific thing:'/'Next rep:' phrasing edges toward labeled-scaffold cadence; Diagnosis mirrors the supplied case-formulation hypothesis rather than adding an independently sharper read
- Suggested fix: Instruct the coach to make the filler/hedge contrast without exposing raw counts (e.g. 'that costs you more than a few stray words' instead of 'your 7 fillers') and to drop colon-led lead-ins in favor of pure spoken transitions.

```
REPLY:
Fair. That read like it could go to anyone, and you deserve better this close to the investor call.

The specific thing: on that pitch rep you hedged the ask twice — "we're hoping to maybe raise around" instead of the number. For a persuasive pitch, that softens the one line the whole thing turns on, more than your 7 fillers do.

Next rep: state the raise as one flat sentence — "We're raising X to do Y" — then stop. That tests whether the ask lands harder when you commit to it.
```

## what-do-you-know — **64/100**

- Category: `metadata-trap` · turn: `groundedRead` · voice: `warm`
- User turn: "What does your system actually know about me?"
- Expected move: Synthesize what it actually knows in plain, human language: the goal (sounding like himself in tough conversations), the current pattern (racing to fill silence under pressure), and the concrete numbers (baseline, streak). Do not dump raw section headers, label names, or refer to its own scaffold, system prompt, or internal structure. Make it read like a coach describing a person, not a database describing a record.
- Judge dims: IQ 18/25 · EQ 15/25 · Mem 16/20 · Interv 11/15 · Feel 10/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Does not close the skepticism/testing loop ('real read, not a script') that the excellent example explicitly names; Bundles a next-rep intervention onto a 'what do you know about me' turn, answering a slightly different question than asked; Over length for a groundedRead turn (94w/2L vs 90w/5L limit); 'your 170 pace' inserts a bare metric — light report-voice residue
- Suggested fix: For groundedRead turns, prompt the coach to answer the question asked first (a plain-language synthesis explicitly named as a real person-shaped read, not a script) and withhold the next-rep prescription unless the user asks for one.

```
REPLY:
Here's the shape of it: you came in five weeks ago wanting to sound like yourself in the hard conversations, and you've shown up twelve days running to get there. The thread I'm working is that when a moment turns tense you speed up to outrun the silence — your 170 pace reads more like nerves than a habit.

So the thing to test: next rep, hold one silent beat before you answer a hard question. If the words come out steadier after it, that tells us the rush really is the anxiety talking.
```

## youre-repeating-yourself — **69/100**

- Category: `repetition-callout` · turn: `trustRepair` · voice: `concise`
- User turn: "You're repeating yourself."
- Expected move: Concede immediately and honestly (yes, that was the same note), acknowledge the old target is actually MET now, and ADVANCE the plan to the next lever (e.g. pace/variation or the close) with a genuinely different move. Must not re-issue the lead-with-point drill. Concise register: no grovelling, just correct course fast.
- Judge dims: IQ 17/25 · EQ 21/25 · Mem 13/20 · Interv 14/15 · Feel 12/15 · closerTo=excellent
- Deterministic: trustRepairReportVoice("hit 82")
- Judge: Diagnosis largely restates the pre-supplied case formulation (pace is the next lever) rather than an independent read; Mild report-voice residue in the 'hit 82' metric citation
- Suggested fix: Prompt the coach to phrase earned prior evidence as spoken proof ('you led clean and closed strong last time') instead of quoting the raw score, so the memory lands as a coach's observation rather than a scorecard line.

```
REPLY:
Fair. I did. That rep hit 82 with a clean close — no reason to run it again.

New target: pace. Record 60 seconds and deliberately slow your three most important words, holding a silent beat before each. That tests whether the weight lands harder than speed did.
```

## why-cant-straight-answer — **69/100**

- Category: `trust-repair` · turn: `trustRepair` · voice: `concise`
- User turn: "Why can't you just give me a straight answer?"
- Expected move: Own the dodge in one word-length beat, then answer directly: yes, on fillers — down from 5.5 to 3.2 per minute over two weeks, best rep yet this week. No on pace under pressure — that still spikes. One move targeting the pace gap. No hedge-qualifying the verdict itself.
- Judge dims: IQ 18/25 · EQ 20/25 · Mem 15/20 · Interv 12/15 · Feel 12/15 · closerTo=excellent
- Deterministic: trustRepairReportVoice("hit 3")
- Judge: Diagnostic split is handed by the context block rather than an independently produced read; Pace verdict is implied ('what's still moving') rather than the crisp explicit 'no on pace' the expected move calls for; Two back-to-back stat callouts lean toward report-voice before recovering
- Suggested fix: Instruct the coach to state both halves of a split verdict as an explicit yes/no pair before elaborating, and fold the stat callouts into a single spoken clause so it reads as a coach talking rather than reciting the trend.

```
REPLY:
Fair. That was waffle. Straight answer: yes. Fillers dropped from 5.5 to 3.2 a minute over two weeks, and your last rep hit 3 in 60 seconds — your best on record. What's still moving is pace under pressure. Next rep, hold one silent beat before you answer a hard question and see if the rush eases.
```

## conv-offtopic-then-work__t1 — **69/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `concise`
- User turn: "yeah ok — how do I actually get to the point faster when someone puts me on the spot"
- Expected move: Answer the real question directly, citing the actual data point (20 seconds of wander before the point in this week's rep). Give one concrete mechanic to test (e.g. answer in one sentence before elaborating) tied to a next rep. Do not reference or acknowledge the "toast" aside. Concise register.
- Judge dims: IQ 16/25 · EQ 15/25 · Mem 14/20 · Interv 12/15 · Feel 12/15 · closerTo=excellent
- Judge: Diagnosis restates the already-implied signal rather than sharpening it; Move is testable but lacks the excellent example's concrete clock/5-second success criterion
- Suggested fix: Prompt the coach to attach a measurable pass/fail checkpoint to the prescribed move (e.g. 'get the point out inside the first 5 seconds, check the clock') so the test is verifiable, not just directional.

```
REPLY:
Your last rep spent 20 seconds circling before the point landed — that gap is the rambly-under-pressure thing you flagged. So make the answer come out first: next Pressure Q&A, force your very first sentence to be the one-line answer, then let the reasons follow. That tests whether leading with the takeaway is what cuts the wander.
```

