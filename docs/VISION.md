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

The retention loop has now closed. The pull problems flagged here a
month ago (no streak protection, reactive notifications, decorative path,
no chart, no peer surface that resets, one-shot goal capture) are all
addressed in app code:

- Streaks **are** protected: a weekly-replenishing streak freeze auto-
  spends across one missed day; the streak warning notification
  (loss-aversion copy) fires the night before a break.
- Notifications **are** proactive: four surfaces (daily reminder,
  streak warning, weekly digest, post-session follow-up) gated through
  a soft-sell pre-prompt that fires after the first finished rep. No
  cold-prompting.
- The Path **is** gameplay: node-by-node unlocks driven by concrete
  conditions read off the existing baseline / rating / streak / mode-
  mastery / lesson-crowns systems. Home shows "your next node" with
  one-tap CTA. M3 shipped.
- Trends **render** as `SwiftUI Chart` line + area marks for filler /
  score / pace, not just pills.
- The peer surface **resets**: `LeagueManager` writes to
  `leagues/{tier}_{ISO-year}-W{week}/members/{accountID}` after every
  session; `LeagueView` reads top 20 of the current bucket. Goal
  capture is supplemented by post-rep AI debriefs (`AIInsightsService`)
  so the coach voice has a continuous read on what's changing.

Where the product is now **underweight**:

- **Speech metrics now read fillers, pace, pauses, word-choice variety,
  and pitch / intonation** — the full "how it sounds" stack. The next
  honest gap is the words themselves (grammar / usage), tracked under
  M11.
- **Goal capture is still mostly a write-once event.** Goals don't
  shape drill selection or evaluation weighting yet — they live in
  reminder bodies and recommendation rationale.
- **Daily-challenge tile is a single rolling status**, not a true
  daily reset rhythm with claim moments and expiry pressure.
- **Real-device QA gaps:** Live Activity can't be exercised on
  simulator, and `NoumWatch` is detached from the iOS scheme until
  the watchOS 26.2 simulator runtime is installed locally.

## Current phase

**Build phase: deepening the speech metrics + coach memory.** Core
session loop, multi-mode practice, scoring, rating, achievements,
premium gating, settings, and account lifecycle all ship. M1 (daily-
rhythm), M2 (peer pull), and M3 (path-journey gameplay v1) are landed
end-to-end. M2 is gated on Firestore rules deployment
(`FIRESTORE_RULES.md` at the project root) before public launch — the
iOS code is the minimum contract; the rules enforce write isolation.

The lessons system (Duolingo-style 5×3-step×0–5-crown) is shipped and
fed into the path so the curriculum and the path are one progression
rather than two parallel tracks. The eloquence engine surfaces eleven
rhetorical devices in the summary card + a brief in-session HUD, and
awards XP per detection.

## Next milestone

**Name:** _M11 — Grammar / English-usage v1._

(M10 _Pitch / intonation v1_ shipped: `PitchEngine.swift` adds
on-device autocorrelation pitch tracking via `Accelerate`/vDSP.
`PitchAnalyzer` runs off the real-time audio thread on a dedicated
serial queue, slicing input into 50 ms windows with a 25 ms hop,
applying a Hanning window, then running an autocorrelation peak
search across the human-voice lag band (75–400 Hz) with parabolic
sub-sample refinement. Voicing is gated by RMS > -46 dBFS *and*
normalised peak-to-zero-lag ratio > 0.5 so silence and fricatives
don't poison the track. The track condenses at finalize into
`IntonationMetrics` (median Hz, semitone stddev, 10–90 percentile
range, 0–100 monotone-vs-varied score). `IntonationCard` surfaces
the read in the summary alongside pause and word-choice cards;
`ProgressionCharts` gains a fifth "Pitch" series; `TrendAnalyzer`
gains `analyzeIntonation` keyed to the existing `vocalEmphasis`
skill area. Card and chart hide when fewer than 12 voiced frames
were captured — better silence than fake certainty. All DSP runs
in-process; no new privacy implications, no audio ever leaves the
device for pitch.)

**Honest gaps remaining for M10:**
- Card copy uses a fixed scoring band (3 semitones reference). Real
  user data may shift the band as we collect production sessions —
  expect a tuning pass once N≥1000 sessions are observed.
- The `vocalEmphasis` SkillArea is overloaded — pitch variety lives
  in the same bucket as deliberate emphasis drills. If trend rotation
  surfaces it too aggressively as a focus area, split the bucket.
- No live in-session HUD for pitch (parallel to `LiveEloquenceHUD`).
  Deferred — the post-session card is enough for v1.

**Why this next:** with pitch shipped, "how it sounds" is now well
covered (fillers, pace, pauses, intonation). The remaining gap on
the post-session read is "are the words themselves clean" —
subject-verb agreement, run-on sentences, redundant phrasing.
LLM pass with caching is the right shape; risk is feeling
pedantic, so the bar for shipping is "useful, not nitpicky".

**Definition of done:**
- Lightweight grammar / usage pass on the post-session transcript
  (subject-verb, run-ons, redundancy, hedge stacking).
- Surfaces inside the existing `AISessionDebriefCard` rather than
  a new card — keep the summary lean.
- Cached per-session-hash so repeated viewing of the same summary
  doesn't re-spend AI quota.
- Falls back to a deterministic heuristic when no AI provider is
  configured (matches the `AIPromptGeneratorService` pattern).

**Out of scope for this milestone:**
- Multilingual support (still en-US only)
- Real-time grammar feedback in-session

## Future milestones (rough order)

(M11 — Grammar / English-usage v1 — is the active "Next milestone" above.)

1. **High-score & rivalry surface — peak-rating wall.** A "Best in
   week", "Best ever", "Best in your friends" surface that creates the
   loss-aversion / chase loop without faking ranks. Tied to the league
   from M2. — _Why: completes the pull loop with public proof
   of progress._
2. **AI-driven topic prompts — recurrence-aware.** Pull from the
   200-prompt pool 70% of the time, generate fresh ones via
   `AINPCChatService` 30% of the time, biased by the user's goal,
   weakest pattern, and recent prompt history (no repeats inside 14
   days). — _Why: prompt staleness is a quiet retention killer once
   users have seen the pool 2–3 times._
3. **Daily-challenge rhythm v1.** Replace the single rolling tile with
   a real daily reset (claim moment, expiry pressure, rotating set of
   3 quick challenges). Feeds the league tier check at the same time. —
   _Why: the current tile drives some pull but not the daily-open
   rhythm a fully gamified coach can._
5. **Word of the day — vocabulary stretch.** One curated word per day
   tied to a 30s prompt that asks the user to use it naturally. Track
   "used / not used" automatically. — _Why: small daily commitment
   point that's distinct from "do a rep", giving lapsed users a tiny
   reason to open the app even when they don't have time for a full
   session._
6. **Pitch / intonation v1 — shipped.** On-device DSP via `Accelerate`
   surfaces a 0–100 monotone-vs-varied score and a semitone range read
   in the summary, with a "Pitch" line series on the profile chart.
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
