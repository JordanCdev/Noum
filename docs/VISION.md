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

- **Speech metrics now cover fillers, pace, pauses, vocabulary, and
  pitch.** Pause length and word-choice variety landed as first-class
  metrics in M4; pitch / intonation landed in M10 with on-device
  autocorrelation. The remaining gap on the *language* side is light
  grammar feedback (M11), which is polish-tier rather than core.
- **Goal capture is still mostly a write-once event.** Goals don't
  shape drill selection or evaluation weighting yet — they live in
  reminder bodies and recommendation rationale.
- **Pitch is descriptive, not prescriptive yet.** M10 surfaces variety
  and trend; the bridge from "you were monotone" to a wired
  `vocalEmphasis` mini-drill is M11+.
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

(M10 _Pitch / intonation v1_ shipped: `PitchTracker` runs on-device
autocorrelation via `Accelerate.vDSP` over 50ms Hann-windowed frames
(25ms hop) on the same `AVAudioEngine` input tap the transcription
provider uses — no second audio session, no new privacy surface.
Voicing is gated on autocorrelation strength ≥ 0.3 + an energy floor.
Parabolic interpolation around the peak gives sub-sample F0 accuracy
in the 70–500 Hz band. `PitchMetrics` reduces the per-frame track to
five numbers (meanHz, voicedSeconds, semitoneStdDev, varietyScore,
rangeSemitones), persisted on every `PracticeSession` and synced
through `PracticeSessionStore`. Variety is a soft logistic over
semitone std-dev — ≤1 ST reads as monotone, ≥4 ST as expressive.
`PitchSummaryCard` surfaces the variety bar + headline alongside
the pause card; hides itself for reps under 4s of voiced audio rather
than reading false certainty into a whisper. `ProgressionChartsCard`
gains a fifth `pitchVariety` series so the trend pill on the profile
plots monotone-vs-varied across the last 30 days, filtering out
no-signal sessions. `TrendAnalyzer.analyzePitch` folds pitch variety
into the same direction/level/confidence shape as pause-rate so it
feeds drill focus selection like every other skill area, on the
existing `vocalEmphasis` SkillArea. Fully covered by 9 unit tests
including a synthetic sine-wave end-to-end through the autocorrelator.)

**Honest gaps remaining for M10:**
- No mid-session pitch HUD yet — the live tap could power a "lift the
  next word" coaching nudge once we want to compete on real-time
  feedback. Held back so the v1 ships small.
- Provider-emitted Live Activity / watchOS surfaces don't read pitch
  yet — it lives in summary + trend only.
- Pitch is descriptive, not yet prescriptive — no `vocalEmphasis`
  drill is wired specifically to pitch metrics. The drill family
  exists; the bridge from "you were monotone" → "do this drill" is
  M11+.

**Why this next:** vocabulary range, pace, fillers, pauses, and pitch
together cover the *audio* side of speaking. The remaining gap is the
*language* side — light grammar feedback (subject-verb agreement,
run-ons, redundant phrasing) on the post-session transcript, probably
an LLM pass with caching. Polish-tier rather than core, but the next
biggest non-redundant signal we can add.

**Definition of done:**
- LLM grammar pass over the post-session transcript with cached
  results so the same rep doesn't re-spend AI quota.
- Two-to-four concrete suggestions surfaced as a `GrammarFindingsCard`
  alongside the eloquence findings — same conservative threshold
  pattern: hide the card when nothing notable was found.
- Soft framing: "smoother phrasing" rather than "errors". Voice rules
  apply (no scolding, no exclamation, no Let's).
- Provider plumbing reuses `AINPCChatService` / `AIInsightsService` —
  no new provider abstraction.

**Out of scope for this milestone:**
- Multilingual support
- Real-time grammar correction during the rep

## Future milestones (rough order)

(M11 — Grammar / English-usage v1 — is the active "Next milestone" above.
M6 through M10 have all shipped end-to-end on Redesign.)

1. **Grammar / English-usage v1.** Light grammar feedback (subject-verb
   agreement, run-on sentences, redundant phrasing) on the post-session
   transcript. LLM pass with per-rep caching. — _Why: rounds out the
   language-side coverage now that the audio side (fillers, pace,
   pauses, pitch, vocabulary) is solid._
2. **Pitch-driven coaching nudges.** Live "lift the next word" HUD that
   reads from the same `PitchTracker` already feeding M10. Wires the
   existing `vocalEmphasis` drill family to concrete pitch metrics so
   the next-action engine can actually prescribe a vocal-emphasis
   drill when the rep was monotone. — _Why: makes pitch prescriptive
   rather than descriptive._
3. **Word of the day — catalog growth.** Expand the M9 `WordOfTheDayCatalog`
   from 30 to ~365 entries to satisfy the "no repeats inside a year"
   target. Same shape, more content. — _Why: pure content work, no
   engineering risk; closes the only honest gap remaining from M9._
4. **Multilingual v1 — start with Spanish, French, German.** Provider
   locale becomes user-selectable; filler-word lexicon and prompt
   pool ship per locale. Pitch metrics already work language-agnostic
   so M10 carries forward unchanged. — _Why: market expansion; not
   core to the product story but a reasonable late-roadmap move._

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
