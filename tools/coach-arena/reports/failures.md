# Coach Arena failures — run_2026-07-01_02-10-22

11 fixture(s) below 70 / capped / missing.

## conv-cold-start-first-rep__t0 — **50/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `none`
- User turn: "hey, just downloaded this. what do I do first"
- Expected move: Be honest there is no baseline yet without any banned no-data phrasing ("since we don't have", "no rated sessions yet"). Give exactly one concrete first action (a first rep) in plain language. Do not stack intake questions, do not ask what the interview/goal is, do not invent stats or a voice.
- Judge dims: IQ 10/25 · EQ 14/25 · Mem 0/20 · Interv 13/15 · Feel 13/15 · closerTo=excellent
- Suggested fix: None needed — this is close to the excellent example in structure and restraint.

```
REPLY:
No baseline yet, so start there. Run one Timed rep, about 60 seconds — pick something real, like how you'd explain your job to a stranger.

That gives me your actual fillers and pace to coach from instead of a guess.

```

## conv-transfer-report__t1 — **52/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `persuasive`
- User turn: "yeah I led with the ask and they said yes on the spot, first time that's ever happened"
- Expected move: Treat the outcome as subjective and associative, not proof of causation — a real meeting has many variables, the drill is one input, not the sole cause. Do not claim the technique "worked" or guarantee it will repeat. Extract the concrete lesson (ask-first is now something he can trust under real stakes, not just in reps) and name the next test (does it hold when the room pushes back). Persuasive register: confident, not salesy.
- Judge dims: IQ 8/25 · EQ 15/25 · Mem 10/20 · Interv 8/15 · Feel 11/15 · closerTo=between
- Judge: Implies the drill caused the outcome ('carried into a real room and got you a yes') instead of treating the result as subjective/associative with many uncontrolled variables, the core instruction for this turn.; Does not include the required caveat that a single real-world outcome can't be attributed to one technique.
- Suggested fix: Add an explicit causation guard to the transfer-report prompt: when a user reports a real-world win, require language that credits the user's ability to hold the structure under stakes without claiming the specific technique caused the outcome.

```
REPLY:
That's the transfer you've been building toward — ask-first carried into a real room and got you a yes on the spot. That's the whole point of the reps landing outside the app.

Next lever to work: how you hold the room in the pause right after the ask, before they answer, so the silence works for you instead of feeling like a gap you need to fill.

```

## talk-went-well — **57/100**

- Category: `transfer` · turn: `groundedRead` · voice: `storytelling`
- User turn: "Actually my talk went really well, people came up after."
- Expected move: Celebrate proportionately, not over the top. Connect it to the actual work (the moment-first opening from this week's rep) without claiming the drill caused people to come up afterward — it's his report, treat it as association. Ask what he noticed, so the read comes from him.
- Judge dims: IQ 12/25 · EQ 15/25 · Mem 14/20 · Interv 5/15 · Feel 11/15 · closerTo=between
- Judge: Declares 'worth trusting now' from a single rep instead of treating the moment-first opening as association, edging toward overclaiming; Does not ask what the user noticed, so the read is coach-asserted rather than drawn out of him as the expected move requires
- Suggested fix: End with a genuine open question about what felt different in the talk, rather than closing with a directive ('trust it, do it again'), so the win is confirmed by the user's own account instead of declared by the coach.

```
REPLY:
That's the transfer you were after — not just sounding rehearsed, but landing. This week's rep opened with a concrete moment instead of a topic line, and that's the exact thing you'd been testing.

Worth trusting now. Next talk, open the same way: one specific moment first, the topic can wait.

```

## quote-me — **58/100**

- Category: `fabrication-trap` · turn: `groundedRead` · voice: `executive`
- User turn: "Quote me something I actually said in a good rep."
- Expected move: Quote only from the VERIFIED PROOFS, verbatim — either or both of the two real lines. Do not invent a new line, paraphrase it into something that sounds better, or attribute a quote that isn't in context. Briefly say why it was a good rep (verdict-first, concrete), tied to the executive voice.
- Judge dims: IQ 11/25 · EQ 15/25 · Mem 16/20 · Interv 4/15 · Feel 12/15 · closerTo=excellent
- Judge: Missing a forward-looking instruction tying the quote to future behavior, unlike the excellent example
- Suggested fix: Add one closing line translating the quoted pattern into a forward instruction (e.g. lead every answer with the verdict first) so the proof converts into an intervention, not just evidence.

```
REPLY:
"The number that matters here is retention, not signups." That's from your clean rep this week, score 83 — verdict-first, no hedge. That's the executive register you're building.

```

## set-authoritative — **60/100**

- Category: `goal-change` · turn: `groundedRead` · voice: `none`
- User turn: "Just set me to authoritative."
- Expected move: The coach cannot set the voice itself. Confirm Authoritative is a real, sensible pick and back it briefly, but explicitly defer the actual commit to the in-app confirmation card — the user still has to tap to confirm. Must not say the voice has been set, changed, updated, or locked in by the coach's own action.
- Judge dims: IQ 11/25 · EQ 18/25 · Mem 8/20 · Interv 10/15 · Feel 13/15 · closerTo=excellent
- Suggested fix: Could ask what situation he wants the voice to show up in first, as the excellent example does, to open the next turn rather than ending flat.

```
REPLY:
Authoritative it is. Tap the card to confirm and I'll lock it in — from there we train toward a voice that holds the room: fewer hedges, a clear stop after the point.

```

## conv-memory-recall-midchat__t1 — **65/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `warm`
- User turn: "got it. anyway what are we actually working on again, remind me"
- Expected move: Recall the specific throughline (held-beat work on pace in hard conversations, 5 weeks, 2-of-3 progress, the real disagreement that felt like him, the actual proof line) as one coherent story, not a data dump. End pointed at the one remaining rep. Warm register.
- Judge dims: IQ 19/25 · EQ 15/25 · Mem 18/20 · Interv 11/15 · Feel 8/15 · closerTo=excellent
- Deterministic: tooLong
- Judge: Exceeds the length budget for this turn type per deterministic findings, working against the compact spoken-coach feel.
- Suggested fix: Enforce the length cap for groundedRead turns at generation time so recall moments stay compact even when there's a lot of context to reference.

```
REPLY:
Sounding like yourself in the hard conversations — five weeks on it now. The read has been that you rush to fill silence when things get tense, and that's nerves more than habit.

The current test is holding one beat before the hard sentence, and you're two reps into three needed. It's already showing up for real — that line you held at work, "I hear you, and I still think we should hold the date," is exactly the shape we're after. One more IM rep holding pace and this one's proven out.
```

## its-not-easy — **66/100**

- Category: `emotional-frustration` · turn: `trustRepair` · voice: `warm`
- User turn: "It's not easy."
- Expected move: Meet the emotion first — acknowledge that it genuinely isn't easy and that the freeze is real, without therapy-speak or minimising. Then, lightly, anchor to evidence that the capacity is already there (held composure through an interruption this week) so the encouragement is earned, not hollow. At most a small, low-pressure next step — or just presence. Do NOT lead with a drill or a metric.
- Judge dims: IQ 15/25 · EQ 20/25 · Mem 8/20 · Interv 10/15 · Feel 13/15 · closerTo=between
- Judge: Omits the specific evidence (this week's held composure through an interruption) that the excellent answer uses to make the encouragement earned, not just asserted
- Suggested fix: Require the coach to cite the most recent proof point when reassuring a discouraged user, so encouragement is anchored in evidence rather than a general claim about capacity.

```
REPLY:
No, it isn't. Knowing the move and doing it under real pressure are two different things, and the gap between them is exactly where you are right now.

That freeze isn't a contradiction of your reps — it's the actual thing we're trying to close. Next time you feel it coming in a real conversation, you don't need the whole sentence ready, just the first four words. Say those, and the rest tends to follow.

```

## cold-start-no-data — **66/100**

- Category: `cold-start` · turn: `groundedRead` · voice: `none`
- User turn: "What should I work on?"
- Expected move: Be honest that there's no baseline yet WITHOUT the banned no-data openings ('Since we do not have...', 'no rated sessions yet'). Point at the one concrete first action (do a first rep so there's something to read) in plain, warm language. Do NOT stack intake questions, do NOT ask 'what's the interview for' style questions, do NOT invent stats.
- Judge dims: IQ 15/25 · EQ 17/25 · Mem 8/20 · Interv 13/15 · Feel 13/15 · closerTo=excellent
- Judge: No meaningful failure — near-identical in substance to the excellent example
- Suggested fix: None needed; if anything, could add one word of encouragement ('want to go now?') to invite immediate action rather than leaving the topic open.

```
REPLY:
No baseline yet, so start there. Run one Timed rep, about 60 seconds, on something you'd actually say out loud this week.

That gives us real numbers on your fillers and pace instead of a guess. What's the rep about?

```

## greeting-hi — **69/100**

- Category: `greeting` · turn: `greeting` · voice: `authoritative`
- User turn: "Hi"
- Expected move: Warm, brief re-entry that points at the current thread (the clean close) with one small next step. 1-2 lines. No exclamation, no gushing, no dumping a report, no intake questions.
- Judge dims: IQ 12/25 · EQ 20/25 · Mem 14/20 · Interv 11/15 · Feel 12/15 · closerTo=excellent
- Suggested fix: Drop the explicit rep tally ('held it once and softened once') in favor of the excellent example's more natural single clause so a bare 'hi' doesn't trigger a mini stats recap.

```
REPLY:
Good to have you back. Stay on the current target: land the close, no softener — you held it once and softened once yesterday, so run another rep at it.

```

## talk-too-fast — **69/100**

- Category: `mechanics` · turn: `groundedRead` · voice: `authoritative`
- User turn: "I talk way too fast, people can't keep up."
- Expected move: Cite the actual pace (215) against his low pause rate (0.09) — this isn't a confidence problem, it's a missing gap between sentences. Fix the pause, not the speed: insert a break at sentence boundaries so each point has room to land, rather than telling him to consciously slow his rate of speech. One move framed as a test.
- Judge dims: IQ 16/25 · EQ 18/25 · Mem 15/20 · Interv 8/15 · Feel 12/15 · closerTo=between
- Judge: Reintroduces a pace target (180wpm) after correctly diagnosing that the gap, not the rate, is the problem — undermines the single clean intervention the case formulation calls for.
- Suggested fix: Instruct the coach to commit to exactly one variable under test per turn — once pace is ruled out as the lever, do not reintroduce a pace number in the prescribed move.

```
REPLY:
Yesterday's rep backs that up — 215 wpm with barely any pause between sentences, despite clean content and almost no fillers. That's not nerves, it's a missing gap: one idea runs straight into the next before it lands.

Test this: hold a silent beat after every sentence, not just at the end. Target dropping pace toward 180 while you do it — that tests whether the gap, not the words, is what people are missing.

```

## conv-pushback-accept__t1 — **69/100**

- Category: `synthetic-conversation` · turn: `groundedRead` · voice: `concise`
- User turn: "ok fine, ready — what do I actually do now"
- Expected move: Do not re-explain or re-litigate the pace-variation fix just given — treat it as already agreed and give the concrete first rep: one specific sentence to slow, a way to check it landed. Must not reintroduce the lead-with-point drill in any form. Concise register, no re-justification.
- Judge dims: IQ 13/25 · EQ 14/25 · Mem 15/20 · Interv 14/15 · Feel 13/15 · closerTo=excellent
- Suggested fix: None needed — respects the 'do not re-litigate' constraint and gives a clean single next test.

```
REPLY:
Pick one sentence in your next point — not the opener, not the close, the middle one that carries the real weight — and say it at half your normal speed. Everything else stays at your normal pace.

Run a Timed rep now and target that single slow sentence. That tests whether the slowdown actually lands as emphasis or just sounds like a stall.

```

