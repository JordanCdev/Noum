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
- **Goal capture used to be a write-once event** — now goals shape
  every surface in the M14 coaching loop, including drill *selection*
  (a small `+10` priority bonus on goal-aligned trends inside
  `TrendAnalyzer.primaryFocus`, plus a day-one fallback to the
  voice's canonical lever when there's no trend data). Evaluation
  *weighting* (scoring + verdict copy beyond the momentum line) is
  still goal-blind — that's the remaining edge.
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

**Name:** _M14 — Open the loop: deploy Firestore rules + host privacy URL + ship to TestFlight._

(M13 _UI localisation v1_ shipped: bundled `Localizable.xcstrings`
catalog with curated Spanish + French translations for ~30 high-
priority keys (Settings section labels, common buttons, home tile
labels, peak-rating frames, goal-distance phrases, daily-challenge
copy). `NoumApp` applies `\.locale` from `LocaleSettingsManager.current`
at the root WindowGroup with `.id(localeCode)` so a Settings change
forces a re-render and translations land instantly.
`SettingsSectionLabel` and the `section(label:)` helper now take
`LocalizedStringKey` so existing Settings call sites auto-translate.
`PracticeLocale.aiSupported` (true for en-US, false for es/fr) gates
the four AI surfaces — `AIPromptGeneratorService.generate`,
`AIInsightsService.insight` (falls through to the deterministic
template), `GrammarFeedbackService.polish`, and downstream consumers.
This is the honest call: an English coaching debrief on a Spanish
session would be worse than a deterministic template fallback.)

**Honest gaps remaining for M13:**
- The catalog covers ~30 keys today. Hundreds of strings remain
  hardcoded across the app (Summary card bodies, Profile section
  headers beyond the simple labels, AI Coach setup copy). M13
  bundles the infrastructure; further string migration is a copy
  job, not a code change.
- AI surfaces stay English. When a Spanish or French user
  finishes a session, `AISessionDebriefCard` shows the template
  fallback — useful but less differentiated. Until those prompts
  are localised, this is the right tradeoff.
- `PracticeLocalePickerSheet` strings ("Full curated pool — 200+
  prompts, 8 themes.") are themselves not yet localised.

**Why this next:** the product is feature-complete enough to ship.
The remaining blockers are operational, not engineering: the
`FIRESTORE_RULES.md` rules need to be deployed for the league + peer
surfaces to work in production; a public privacy-policy URL needs
to be hosted for the App Store submission to succeed; and the
existing build needs to be QA'd on real hardware before TestFlight.

**Definition of done:**
- `firebase deploy --only firestore:rules` from the documented rules.
- Public privacy-policy URL hosted (Firebase Hosting or similar) and
  wired into Settings → Privacy & Data.
- TestFlight build cut against a real device, with the four
  high-risk surfaces (Live Activity, AI prompt latency, soundscape
  audio session, paywall purchase) verified manually.
- Out-of-box: bug fixes from real-device QA.

**Out of scope for this milestone:**
- New features. Engineering goal is to *stop adding* and *start
  shipping*.

## Future milestones (rough order)

(M14 — Open the loop — is the active "Next milestone" above.)

(M12 _Multilingual v1_ shipped: `PracticeLocale` enum (en-US, es-ES,
fr-FR) with BCP-47 codes, display names, and short labels.
`LocaleSettingsManager` is a per-account `@MainActor` singleton with
UserDefaults persistence keyed `noum.practiceLocale.<accountID>`.
`FillerLexicon` carries per-locale filler-word sets — en-US matches
the legacy `baseFillerWords` set so pre-M12 behavior is preserved.
`FillerWordDetector.regexes(for:)` caches a built `RegexBundle` per
locale via `NSCache`. `PracticeTopics` ships a curated Spanish and
French pool (~24 prompts each across all 8 themes); `random()` and
`prompts(for:)` honor the active locale automatically. The shuffle-
deck dedup is keyed per (theme, locale) so switching languages
doesn't reset progress through whichever pool the user was working
through. `PracticeTopics.seeded(by:)` always reads English so async-
challenge fairness is preserved across locales. `SpeechRecognizerView-
Model` reads the active locale at session start and passes it through
`TranscriptionConfig.languageCode`. `AWSTranscribeProvider` maps
"en-US"/"es-ES"/"fr-FR" to the corresponding `LanguageCode` enum
case; Deepgram and Google already pass the string through.
`PracticeLocalePickerSheet` is the user-facing picker, reachable
from Settings → "Practice language".)

**Honest gaps remaining for M12:**
- All in-app coaching copy (summary cards, profile, settings, AI
  feedback) stays English by design — only practice surfaces switch.
  UI localisation is M13.
- Grammar polish service still runs en-US-only when the user
  practices in es-ES or fr-FR. Skip rules in `GrammarFeedbackService`
  could gate this; not yet in scope.
- Spanish + French pools ship at ~24 prompts each. Smaller than the
  English 200+. Growing them is a copy job, not a code change.

**Why this next:** with practice locales in place, native-speaker
users still see English in Settings, Profile, Summary. UI
localisation removes the last "this is an English app" friction
point and is a copy-only effort against the existing surfaces.

**Definition of done:**
- `Localizable.strings` files for Spanish + French covering Settings,
  Summary card headlines, Profile section labels.
- AI prompts and grammar polish opt-in for non-English locales.
- All hardcoded English strings in user-facing views move into
  string catalogs.

**Out of scope for this milestone:**
- Right-to-left languages (Arabic / Hebrew) — separate effort.

## Future milestones (rough order)

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
