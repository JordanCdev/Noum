# Noum — Vision & Roadmap

## North star

Noum helps people become measurably better communicators under pressure.
Success means a user can look back after weeks of use and feel — and see —
that they speak more clearly, with fewer fillers, and hold composure better
in hard conversations.

## Product pillars

1. **Filler-word reduction** — detect, distinguish semantic vs filler use,
   coach without nagging.
2. **Pressure modes** — reveal breakdowns fairly. Pressure should feel
   challenging, not chaotic.
3. **Conversational intelligence** — feedback on pacing, clarity, structure.
4. **Believable progress** — visible improvement across sessions, no fake
   gamification.
5. **Personalized coaching** — adapts to the user's actual patterns over time.

## Honest assessment — where we are vs where we need to be

The technical foundation is strong. Speech recognition is multi-provider
and resilient. Filler detection is genuinely smart (semantic vs disfluency,
prompt-echo aware). Pace, scoring, and rating are real and persistent.
Premium is wired through StoreKit 2. Auth, account deletion, and the
privacy posture are above the bar for an indie app.

What's underweight is the **pull**.

The Duolingo question — "does the user feel like the app keeps me coming
back?" — has a clear answer in the code today: **the app rewards effort
that's already happening, but it doesn't pull a wavering user back to it.**

Concretely:

- **Streaks calculate but don't protect.** A miss breaks them with no
  freeze, no warning, no second chance.
- **Notifications are reactive, not proactive.** One follow-up after a
  session, no daily reminder at a chosen time, no "your streak ends in
  4 hours" nudge, no goal anniversary.
- **The Path Journey is decorative.** It shows where you've been, not
  what specific node you're on or what unlocks next.
- **The "active challenge" is one rolling tile**, not a real
  daily/weekly rhythm. No expiry pressure, no claim moment, no resetting
  league.
- **Trends compute but don't render.** The user sees "Trending up" as a
  pill, not a line graph that proves it.
- **No peer surface that resets.** Friends exist; weekly leaderboards
  don't. The "I'm climbing this week" pull is missing.
- **Goal capture is one-shot.** Users define a goal at onboarding then
  never revisit it; the goal doesn't shape their drill prompts or
  weekly digest.

This is the gap between "this app works" and "this app pulls me back".
The next two milestones are explicitly about closing it.

## Current phase

**Build phase: closing the retention loop.** Core session loop, multi-mode
practice, scoring, rating, achievements, premium gating, settings, and
account lifecycle all ship. Daily-rhythm v1 (M1) is shipped end-to-end:
daily goal ring, streak freeze, three notification surfaces, 30-day rating
chart, weekly digest, AI-paraphrased goal text. Peer Pull v1 (M2) is
landed in app code: friend leaderboard with real backend stats, async
challenge round-trip via shared Firestore docs, weekly league bucketed by
tier+ISO-week. The Firestore security rules (`FIRESTORE_RULES.md` at the
project root) need to deploy before launch — the iOS code is the minimum
contract; the rules are what enforce write isolation.

## Next milestone

**Name:** _Path-Journey gameplay v1 — node-by-node unlock._

(M1 _Daily-rhythm_ and M2 _Peer Pull_ have shipped in app code; M2 is
gated on Firestore rules deployment.)

**Definition of done:**
- The Path is no longer decorative. Each node has a concrete entry
  condition (e.g. "3 clean reps", "peak rating ≥ X", "zero fillers in
  a Sudden Death round") read off the existing baseline / rating /
  session systems — no parallel tracking.
- Home always shows "Your next node" with a one-tap CTA that opens
  the rep that progresses it.
- Completing a node fires a single celebration overlay
  (`MilestoneCelebrationOverlay`) and unlocks the visual reveal of the
  next node — consolidated with the existing milestone copy so we
  don't double-celebrate.
- Path map shows past, current, and next-3 nodes with state
  indicators. Beyond the next 3 stays masked so the path doesn't read
  as a finite track.
- Re-uses `RetentionLoopEngine` and `BaselineEngine` data; no new
  state owners.
- The decorative `practicedDays`-based reveal in `PathJourneyView` is
  retired or repurposed (it implied progress without driving it).

**Out of scope for this milestone:**
- Pitch / grammar / pause analytics
- Word of the day
- AI-generated topic prompts
- Multilingual support
- Server-side league matching algorithms beyond the
  client-deterministic `{tier}_{ISO-week}` bucketing already in M2.

## Future milestones (rough order)

1. **Speech-quality v2 — pauses + word-choice variety.** Pauses become
   a session metric (count, mean length, longest, "filled vs unfilled").
   Word-choice gets a "variety score" from a Zipf-style repetition
   metric. Both feed `BaselineEngine` and `TrendAnalyzer`, both render
   in the new chart card. — _Why: filler control is solved enough that
   the ceiling on improvement now lives in pacing and word choice._
2. **Coach memory v1 — goal-aware drill selection.** Goal capture
   becomes recurring (re-asked every 2 weeks). Drill prompts are
   filtered by goal tags. Session debrief framing leads with the goal
   ("you said you wanted to be more concise — your last 5 reps averaged
   23s, target was 30s"). — _Why: the coaching profile is captured
   once and ignored after; making it living turns the app from a tool
   into a coach._
3. **High-score & rivalry surface — peak-rating wall.** A "Best in
   week", "Best ever", "Best in your friends" surface that creates the
   loss-aversion / chase loop without faking ranks. Tied to the league
   from M2. — _Why: completes the pull loop with public proof
   of progress._
4. **AI-driven topic prompts — recurrence-aware.** Pull from the
   200-prompt pool 70% of the time, generate fresh ones via
   `AINPCChatService` 30% of the time, biased by the user's goal,
   weakest pattern, and recent prompt history (no repeats inside 14
   days). — _Why: prompt staleness is a quiet retention killer once
   users have seen the pool 2–3 times._
5. **Word of the day — vocabulary stretch.** One curated word per day
   tied to a 30s prompt that asks the user to use it naturally. Track
   "used / not used" automatically. — _Why: small daily commitment
   point that's distinct from "do a rep", giving lapsed users a tiny
   reason to open the app even when they don't have time for a full
   session._
6. **Pitch / intonation v1.** Add a pitch track to the audio pipeline
   (likely on-device DSP, `Accelerate` framework). Score monotone vs
   varied delivery. Render alongside pace. — _Why: the missing third
   leg of "how it sounds when you speak", and the most differentiating
   metric vs. competitors who only count fillers._
7. **Grammar / English-usage v1.** Light grammar feedback (subject-verb
   agreement, run-on sentences, redundant phrasing) on the post-session
   transcript. Probably an LLM pass with caching. — _Why: requested
   feature; lower priority because it touches polish rather than core
   skill, and risks feeling pedantic._
8. **Multilingual v1 — start with Spanish, French, German.** Provider
    locale becomes user-selectable; filler-word lexicon and prompt
    pool ship per locale. — _Why: market expansion; not core to the
    product story but a reasonable late-roadmap move._

## Anti-goals

Things Noum will not become:
- A dashboard of vanity metrics
- A streak-and-badge addiction loop _(streaks exist; we don't celebrate
  hollow ones, we don't fake unlocks, and we never punish-shame a
  miss in copy)_
- A generic AI chat wrapper
- A noisy productivity app
- **An ad-supported product.** Sponsor / advertisement surfaces
  appeared on the Trello board; they conflict with the paid tier and
  the credibility of the coaching voice. **Don't build them.**
- **A hearts-and-lives gating game.** Loss-aversion mechanics that
  block practice (run out of hearts, can't continue) actively work
  against the product's purpose. Speaking practice should never be
  gated by a meta-game token.
- **A leaderboard that publishes raw transcripts.** League surfaces
  show rating, reps, fillers, peak — never the words a user said.
