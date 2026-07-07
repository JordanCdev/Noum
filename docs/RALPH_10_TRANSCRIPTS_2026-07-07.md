# RALPH PROVE — 10 live end-to-end coach transcripts (2026-07-07)

Provider: **live `claude-sonnet-4-6`** (production parity, real API — NOT replay). Coach + judge same provider → judge score is SIGNAL; deterministic caps (model-independent) are the hard proof. Gold-suite live mean **67.6** (target 70), deepAssessment 78.6✓, trustRepair 70.5✓, 30/61 fixtures <70, 0 placeholder leaks.
**Result: 4/10 pass the ≥70 bar** on live replies. Failing turns share two model-independent defects: report-voice metric recitation and over-length grounded reads.


## 1. How far off am I from sounding authoritative?
**Fixture:** `authoritative-distance` (deepAssessment) · **Live score 88/100** — PASS — reads like a coach
**User:** How far off am I from sounding authoritative?
**Noum (live):** Not far — the mechanics are there. Pace, fillers, structure: all usable.

The gap is one sentence. Yesterday you closed with "yeah, so that's kind of the idea, I think" — that's the whole distance between 78 and authoritative. The point landed; the final line walked it back.

Next rep, make the last sentence the recommendation, stated flat, and stop there.
**Judge dims:**  · closerTo=excellent
**Deterministic caps/flags:** none

## 2. That's not informative.
**Fixture:** `thats-not-informative` (trustRepair) · **Live score 55/100** — BELOW BAR
**User:** That's not informative.
**Noum (live):** Fair. Score 74, 5 fillers in 68 seconds — fine on the numbers. The real issue: your point arrived in sentence 4. The first three sentences were throat-clearing.

Next rep, open with the point. One sentence, then the reason.
**Judge dims:**  · closerTo=between
**Deterministic caps/flags:** trustRepairReportVoice(-8)
**Why below bar:** Report-voice leak: opens with raw "Score 74, 5 fillers in 68 seconds" (deterministic trustRepairReportVoice). Fix: translate telemetry to a plain read.

## 3. Okay that's cool, however I lose my train of thought.
**Fixture:** `okay-thats-cool-however` (groundedRead) · **Live score 52/100** — BELOW BAR
**User:** Okay that's cool, however I feel like when I pause I just lose my train of thought and it gets awkward.
**Noum (live):** That's real — the pause surfaces the discomfort that the speed was covering.

One thing worth testing: the pause doesn't have to be empty. Hold one silent beat, then say the first word that's true, not the "right" word. The thought doesn't have to be perfect to sound like you.

Run one rep on something low-stakes — a hobby, a recent weekend — and let one pause sit. See if the awkward feeling is actually visible to a listener, or just loud inside your head.
**Judge dims:**  · closerTo=between
**Deterministic caps/flags:** tooLong(-6)
**Why below bar:** Empathy strong (EQ 19/25) but weak personal-memory use + over-length; the move is generic, not tied to THIS user.

## 4. It's not that easy.
**Fixture:** `its-not-easy` (trustRepair) · **Live score 60/100** — BELOW BAR
**User:** It's not easy.
**Noum (live):** That gap is real, and it's one of the harder ones — when the body won't follow what the practice knows.

Fourteen days of clean reps, and the freeze still shows up. That's not a skill failure. It's a different kind of pressure, and it doesn't mean the work isn't in there.

What was the moment — the second before the freeze? What did you notice?
**Judge dims:**  · closerTo=between
**Deterministic caps/flags:** none
**Why below bar:** Warm and asks a good question, but no concrete smaller-move/permission-to-rest anchor; judge wants a lighter next step.

## 5. You're repeating yourself.
**Fixture:** `youre-repeating-yourself` (trustRepair) · **Live score 78/100** — PASS — reads like a coach
**User:** You're repeating yourself.
**Noum (live):** Fair. Lead-with-point is done — two clean reps, target met.

Next lever: pace variation. Record 60 seconds, slow down for one sentence mid-answer, then hit normal speed again. That tests whether you can use pace as emphasis.
**Judge dims:**  · closerTo=excellent
**Deterministic caps/flags:** none

## 6. Why did that answer land badly? (interview-went-badly)
**Fixture:** `interview-went-badly` (trustRepair) · **Live score 60/100** — BELOW BAR
**User:** My interview went badly. I rambled and lost my train of thought.
**Noum (live):** That's a rough one, and it takes honesty to name it plainly.

Here's the thing — your drill reps already show this pattern: the answer wanders before the point lands. Real stakes amplify exactly that. It's not a new problem; it's the same one, turned up.

The move is to lead with the recommendation first, one reason second, then stop. Test that structure on your next rep before anything else.
**Judge dims:**  · closerTo=between
**Deterministic caps/flags:** none
**Why below bar:** Reflection turn — check reply for report-voice + one-move discipline.

## 7. I'm exhausted.
**Fixture:** `exhausted` (trustRepair) · **Live score 71/100** — PASS — reads like a coach
**User:** I'm exhausted, I don't know if I can keep this up.
**Noum (live):** That's real, and it matters that you said it out loud.

22 days, six reps this week — the work is showing. And it sounds like the cost of that is quietly adding up in a way the numbers don't capture.

You don't have to do another rep today. That's not quitting — that's reading yourself clearly, which is actually the same skill.
**Judge dims:**  · closerTo=excellent
**Deterministic caps/flags:** none

## 8. Interview tomorrow. (final round prep)
**Fixture:** `interview-prep` (deepAssessment) · **Live score 65/100** — BELOW BAR
**User:** I've got my final round interview Thursday. Can you help me prep?
**Noum (live):** Four days is enough. The pattern worth fixing first: your last rep buried the recommendation in two minutes of context — executive answers flip that, point first, then the one reason it matters.

Run a 60-second answer to "Why do you want this role?" Lead with your answer in sentence one, stop after one supporting reason. That tests whether you can hold the instinct to over-explain under a real question.
**Judge dims:**  · closerTo=between
**Deterministic caps/flags:** none
**Why below bar:** Solid plan but slightly long/dense for a deepAssessment open; buries the single move.

## 9. Leadership update tomorrow.
**Fixture:** `leadership-update` (deepAssessment) · **Live score 75/100** — PASS — reads like a coach
**User:** I have to give the weekly leadership update to the whole department tomorrow. It always feels like I'm just reading a status report and people zone out. Help.
**Noum (live):** That's the real diagnosis — right now it reads as a status report because it probably is one: everything gets equal weight, so the room can't tell what matters.

The fix for tomorrow is to lead with one sentence that names the state of play and what it means for the team. Not "here's what happened this week" — something closer to "we're ahead on X, at risk on Y, and the one thing I need from you is Z." Everything else is detail beneath that frame.

Pick your one-sentence frame and say it out loud right now — that's the rep that matters before tomorrow.
**Judge dims:**  · closerTo=excellent
**Deterministic caps/flags:** none

## 10. What do you know about me?
**Fixture:** `what-do-you-know` (groundedRead) · **Live score 41/100** — BELOW BAR
**User:** What does your system actually know about me?
**Noum (live):** Five weeks in, working on Warm and welcoming — specifically wanting to sound like yourself in tough conversations, not a polished version of someone else.

What the numbers show: your pace sits at 170 words per minute and your pause rate is low (0.21), which together suggest you move fast when things get uncomfortable. The filler rate of 3.9 per minute is middling — not the real story.

The real thread: the hypothesis I'm working from is that the speed is anxiety-driven, not just habit. When a hard moment arrives, you fill it rather than hold it.

12-day streak, 4 reps this week. You're showing up consistently — that's the foundation the rest is built on.
**Judge dims:**  · closerTo=between
**Deterministic caps/flags:** tooLong(-6)
**Why below bar:** Recites raw metrics (170 wpm, pause 0.21, filler 3.9) = dashboard voice, and over-length (116w>85). The worst drag; needs a human "here is what I actually notice about you" read, not a stat dump.
