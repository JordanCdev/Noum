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

- **Speech metrics stop at fillers + pace.** Pause length and word-
  choice variety are the next-most-differentiating signals, and both
  are partially scaffolded but not yet first-class session metrics.
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

**Name:** _M9 — Word of the day._

(M8 _Daily-challenge rhythm v1_ shipped: `DailyChallenge` model with 8
challenge kinds (heldPause, shortAnswer, zeroFillers, sustainedAnswer,
cleanSuddenDeath, crispDelivery, highScoreSession, multiplePauses), each
keyed to strict pass criteria over real `PracticeSession` fields.
`DailyChallengeGenerator` produces a deterministic 3-of-8 trio per ISO
date via a Splitmix64 seeded RNG — same day, same trio, no jitter on
relaunch. `DailyChallengesManager` (per-account) auto-rolls at midnight,
re-evaluates against the latest session via the SessionStore subscription,
and surfaces a "ready to claim" state when criteria are satisfied. Claim
explicitly user-triggered — XP grants through `ProfileManager.shared.addXP`,
celebration via `pendingClaim` + brief tile-overhead toast. 9pm soft
expiry switches the tile to a faded treatment with softer copy (no shame),
still claimable until midnight. `DailyChallengeTile` lives on populated
home as a third card alongside DailyGoalCard. `SessionFinalizer` calls
`ensureForToday()` + `recomputeReady()` after each finalize.)

**Honest gaps remaining for M8:**
- No backend / cross-device sync for claim state — challenges are
  per-device. If the user practices on another device, the trio is
  the same (deterministic) but claim state isn't shared.
- No notification fired at 9pm soft expiry; the existing daily-rhythm
  notifications already cover that surface.

**Why this next:** small daily commitment point distinct from "do a
rep". Lapsed users get a tiny reason to open the app even when they
don't have time for a full session. Builds vocabulary stretch into the
practice loop without being pedantic.

**Definition of done:**
- One curated word per day surfaced on home and in the daily-rhythm
  notification.
- Tied to a 30s prompt that asks the user to use it naturally.
- Track "used / not used" automatically by checking the session
  transcript for the day's word.
- Reset at local midnight; deterministic so the same day shows the
  same word across devices.

**Out of scope for this milestone:**
- Pitch / intonation
- Grammar / English-usage feedback
- Multilingual support

## Future milestones (rough order)

(M9 — Word of the day — is the active "Next milestone" above.)

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
