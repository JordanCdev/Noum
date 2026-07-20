# Noum — Vision & Roadmap

## North star

Noum helps people become measurably better communicators under pressure.
Success means a user can look back after weeks of use and feel — and see —
that they speak more clearly, with fewer fillers, and hold composure better
in hard conversations.

The destination is not an AI-assisted practice app. Noum exists to make the
quality of an excellent personal communication and public-speaking coach
accessible without requiring private-coaching prices or availability. The
product target is parity with the repeatable, evidence-led work a human coach
does: diagnose the individual, remember what matters, prescribe deliberate
practice, observe response, revise the plan, and prepare the user for real
moments where their communication matters.

Noum must earn that claim. It may pursue human-coach replacement as the
product ambition, but it must never imply parity from an LLM response, a
single rep, or a feature checklist. Parity means durable user outcomes and
coaching judgment that can be demonstrated over time.

## Product pillars

1. **Filler-word reduction** — detect, distinguish semantic vs filler use,
   coach without nagging.
2. **Pressure modes** — reveal breakdowns fairly. Pressure should feel
   challenging, not chaotic.
3. **Conversational intelligence** — feedback on pacing, clarity, structure.
4. **Believable progress** — visible improvement across sessions, no fake
   gamification.
5. **Personalized coaching** — adapts to the user's actual patterns over time.
6. **Real-world transfer** — prepares for and learns from interviews,
   presentations, conflict, leadership moments, and daily conversations.

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

Where the product is now **underweight** for coach parity:

- **The coaching case is newly explicit, but still early.** Durable memory,
  proof moments, trend reads, forward plans, observed response to followed
  recommendations, subjective reflection patterns, transfer reviews, and a
  first-class `CoachCaseFile` now provide one bounded case spine: hypothesis,
  intervention, target, success measure, review due date, transfer read, and
  next coach move. That is the right architecture, but it still needs richer
  user confirmation, more repeated evidence, and real-world validation before
  Noum can claim professional-coach parity.
- **Delivery sensing exists, but is not yet validated deeply enough.** Fillers,
  pace, pause quality, word choice, rhetorical devices, scenario state, pitch
  range, vocal energy, composure, and structure now feed a conservative fused
  delivery read. The remaining gap is reliability across real devices, voices,
  rooms, and microphones, plus breathing, emphasis, tension, and eventually
  opt-in presence signals. A derived delivery read must never be presented as a
  direct read of motive or personality.
- **The user's inner experience is now captured at bounded checkpoints, but the
  evidence is still early.** Post-rep reflection and the weekly check-in ask
  what felt hardest, what changed outside the app, confidence, avoidance, and
  drill fit. Confirmable patterns can enter the coaching case as hypotheses;
  observed speech evidence remains separate and higher priority. The remaining
  need is longitudinal participation, user correction, and evidence that these
  check-ins improve the intervention rather than merely collect more data.
- **Deeper patterns remain hypotheses, not a coaching record.** The product
  must be able to explore overexplaining, fear of disagreement, lack of
  conviction, defensiveness, weak executive presence, timidity, evasion, or
  emotional disconnection, while never labelling the user from telemetry or
  a single AI reading.
- **The transfer loop exists, but real-world evidence is sparse.** Big Moment
  supports an upcoming case, a rehearsal plan, relevant scenario practice, a
  post-event outcome/reflection, the user's read of audience or counterpart
  reaction, and an updated transfer trend. That is the correct product loop;
  it is not proof that interviews, board updates, pitches, difficult
  conversations, networking, leadership moments, or speeches improve. Only a
  longitudinal real-user programme can establish that.
- **Goal capture used to be a write-once event** — now an explicitly chosen
  style shapes the M14 coaching loop, including drill *selection*
  (a small `+10` priority bonus on goal-aligned trends inside
  `TrendAnalyzer.primaryFocus`, plus a day-one fallback to the
  voice's canonical lever when there's no trend data) and verdict
  *copy* (momentum, leverage, next step, and drill rationale all
  carry a voice-alignment clause when the focus skill is in the
  goal's `alignedSkillAreas`; off-goal sessions stay neutral so
  there's no fake personalization). Evaluation *scoring* now reads
  the voice too: `PracticeEvaluator.voiceDeliveryBonus` adds a small
  (≤0.6 raw / ≤1 of 10) lift when the delivery profile fits the
  chosen voice — `.concise` rewards lean tight delivery, `.warm`
  rewards natural pace + content, `.authoritative` rewards zero
  fillers + sustained duration, etc. Restraint matches the copy
  enrichments: 0 when no goal, 0 when delivery doesn't fit (no
  double-penalty layered on top of the existing dimension weights).
  Score, copy, and drill are goal-aware end-to-end only when
  `chosenStyleGoal` proves that choice. Legacy `speakingStyleGoal` values remain
  readable compatibility data but never authorize tailored coaching; an
  unchosen profile stays neutral. Weekly digest copy follows the same boundary,
  and current plans/proofs/notes are filtered or invalidated when their voice
  provenance no longer matches. The next standard is intervention-aware: did
  that prescribed work help this specific user's stated goal, and what should
  the coach change next?
- **Real-device QA gaps:** Live Activity can't be exercised on
  simulator, and `NoumWatch` is detached from the iOS scheme until
  the watchOS 26.2 simulator runtime is installed locally.

## Current phase

**Release phase: M14 — open the loop and earn TestFlight evidence.** Core
session loop, multi-mode practice, scoring, rating, achievements,
premium gating, settings, and account lifecycle all ship. M1 (daily-
rhythm), M2 (peer pull), and M3 (path-journey gameplay v1) are landed
locally. M2 must remain unavailable in production until the guarded social
cutover is complete: back up and quarantine legacy client-authored rows,
inventory/migrate incompatible private-profile enum values, deploy a trusted
server-side evidence producer, and then deploy the reviewed rules/functions as
one authorized operation. Source rules alone do not make the social surface
safe.

The lessons system (Duolingo-style 5×3-step×0–5-crown) is shipped and
fed into the path so the curriculum and the path are one progression
rather than two parallel tracks. The eloquence engine surfaces eleven
rhetorical devices in the summary card + a brief in-session HUD, and
awards XP per detection.

The coach-memory track now includes durable working memory, bounded
response-to-recommendation evidence, bounded subjective reflection-pattern
memory, real-world transfer reviews, and a first-class `CoachCaseFile` for Ask
Noum and AI-generated forward plans. Intervention-review handoffs now carry
those repeated self-report patterns into the review question, and the case file
names the current hypothesis, intervention, observable target, success measure,
review date, transfer read, and next coach move. That is the beginning of an
adaptive coaching relationship, not the finish: Noum can observe that a
prescribed mode is associated with progress or regression, and can carry a
repeated self-report pattern as a coach hypothesis, but it still has to prove
transfer into the user's real-world moments.

## Coach-parity standard

Noum is on-par with a strong human coach only when it can repeatedly deliver
all of the following for an individual user:

1. **Diagnosis** — establish a credible baseline and identify the user's
   high-leverage communication pattern without overclaiming thin evidence.
2. **Case formulation** — retain a concise, revisable understanding of the
   user's goal, blockers, strengths, pressure triggers, subjective experience,
   confidence and avoidance patterns, and upcoming moments. Deeper personal
   patterns must be treated as hypotheses the user can confirm or reject.
3. **Intervention** — prescribe a drill for a reason, name the observable
   target, and define what improvement would look like before the user starts.
4. **Adaptation** — compare response across multiple attempts and either
   reinforce, vary, or replace the intervention with an explained rationale.
5. **Perception** — assess not only words and fillers but vocal variety,
   intonation, breathing, energy, pitch range, authority, tension, structure,
   composure, and, when explicitly enabled, posture, eye contact, and visual
   presence. It must help distinguish clear communication from speech that is
   merely polished, evasive, timid, over-rehearsed, or emotionally detached.
6. **Transfer** — connect training to real conversations, presentations,
   interviews, pitches, conflict, leadership, dating, and networking, then
   collect honest outcome/reflection and perceived audience-response evidence
   after the event.
7. **Validation** — demonstrate that recommendations and feedback are as
   useful and trustworthy as professional-coach judgment on representative
   sessions and longitudinal user outcomes.

### Development instructions

- Every coaching feature must strengthen at least one stage of the loop:
  diagnose → formulate → prescribe → observe → adapt → transfer.
- Prefer extending existing state owners (`CoachingProfileStore`,
  `CoachMemoryStore`, `RecommendationLearningStore`, session history, and
  forward-plan stores) over adding disconnected AI surfaces.
- A generated reply is not personalization by itself. Coaching context that
  matters over time must persist, be bounded, be inspectable, and be tested.
- Every recommendation must have evidence, purpose, an observable target,
  and an honest evidence threshold for changing the plan.
- An intervention cycle must invite short reflection at the right moments:
  what felt difficult, how confident the user felt, what they avoided, what
  real situation is approaching, and what changed outside the app.
- Inferred psychological or interpersonal patterns must be framed as coach
  hypotheses, never facts or diagnoses; ask the user before persisting or
  strengthening them.
- Weak evidence must produce tentative language; repeated evidence can
  strengthen intervention; association must never be described as causation.
- Engagement, vocabulary, social, or cosmetic features must not displace
  work that closes a coach-parity gap unless they are needed to ship or retain
  enough usage to measure real improvement.

## Next milestone

**Name:** _M14 — Open the loop: close release gates + ship to TestFlight._

M14 is a launch gate, not a change in ambition. Shipping a stable build is
necessary so the coach-parity work can be tested with real people, real
practice history, and real upcoming moments; it does not mean the product is
already equivalent to a professional coach.

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

**Why this next:** the product is feature-complete enough to enter release
closure. The remaining release gates are externally earned evidence and
operator-owned actions, not authorization to add more local feature surface. The
hosted policy already exists at `https://noum-d0b6f.web.app/privacy`; custom-domain
DNS remains a separate operator-owned launch prerequisite, not a reason to claim
that no public policy exists. The reviewed Firestore rules/functions still need
the guarded social
cutover and authorized coordinated production deploy, and the source-bound build
still needs real-hardware/TestFlight QA.

**Definition of done:**
- Guarded social backup/quarantine, private-profile inventory/migration,
  trusted evidence production, and coordinated rules/functions deployment.
- Hosted policy and the Settings link verified against the generated processor
  disclosure; custom-domain DNS/TLS/content cutover is completed as the
  operational checklist requires.
- Historical credential/endpoint and exposed Firebase-session incidents closed,
  with independent verification and provider usage/billing audit.
- A source-bound TestFlight build installed on physical hardware and the exact
  14-surface/77-check schema completed for that same build.
- All five independent launch artifacts accepted: current-source live-provider
  sweep, blinded professional review, longitudinal real-user transfer,
  physical TestFlight QA, and operational launch sign-off.
- Out-of-box: bug fixes from real-device QA.

**Out of scope for this milestone:**
- New features. Engineering goal is to *stop adding* and *start
  shipping*.

## Strategic roadmap after M14

M14 is the active operational milestone. After a stable TestFlight build,
coach-parity work takes priority over optional retention and expansion
features.

1. **Validate and deepen the coaching case.** The existing case spine already
   joins profile, bounded memory, forward plan, proof moments,
   recommendation-response evidence, weekly check-ins, and transfer outcomes.
   Use stable TestFlight history to test whether its active hypothesis,
   intervention, target, success measure, review date, response, and next move
   remain coherent over weeks. Improve confirmation and correction before
   expanding what is inferred.
2. **Validate and deepen delivery intelligence.** Pause quality, pitch range,
   vocal energy, composure, structure, confidence markers, and word-choice
   precision already contribute to delivery reads. Calibrate them on real
   audio before adding breathing, emphasis, authority/tension, or other
   channels. Coach for the difference between clarity and over-polish only
   with conservative thresholds and user-visible inference limits.
3. **Validate and deepen real-moment transfer.** Big Moment already links an
   upcoming event, rehearsal plan, scenario practice, post-event reflection,
   perceived audience/counterpart reaction, and a coach update. Use a
   longitudinal pilot to learn whether that loop changes outcomes across
   presentations, interviews, leadership, pitches, conflict, networking, and
   personal conversations before adding more transfer surfaces.
4. **Consolidate the progress story.** After a stable TestFlight build, make
   Progress, Path, and streak continuity read as one coaching narrative:
   current lever, evidence-backed change, next milestone, and the reason for
   the next practice. Reuse the existing session, path, memory, plan, and
   streak owners; do not add another progress store or another dashboard.
5. **Presence coaching with consent.** Add opt-in visual and nonverbal reads
   only once audio/text coaching is trustworthy: eye contact, posture,
   gesture, facial energy, and camera rehearsal, with clear privacy controls,
   no hidden analysis, and no claim that visual cues reveal inner motives.
6. **Human-coach calibration.** Build a blinded evaluation set and
   longitudinal pilot in which professional coaches rate diagnosis,
   usefulness, fairness, drill choice, and adaptation. Do not market
   replacement/parity until Noum can meet an explicit benchmark.

**Secondary backlog after parity-critical work:** recurrence-aware prompt
variety, vocabulary stretch/Word of the Day as an optional user-led tool,
additional rivalry surfaces, expanded localisation, and broader languages.
These may support access or retention, but they are not substitutes for a
coach who knows what the user needs and adjusts accordingly.

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
