# Noum — Integrated UX / Value Findings

_Council review reconciled by the head of product. Three leads (UX, QA/Accessibility,
Market) each reviewed the REAL rendered app across four seeded density states
(A-cold 0 reps / B-beginner 5 / C-improving 12 / D-plateaued 20) plus onboarding
and standalone flows. Screens live in `.screenshots/2026-06-06_deep-audit/`
(PNG + `ax/*.txt` accessibility dumps). Source-level claims were independently
verified in the codebase before inclusion._

_Date: 2026-06-06 · Branch: `Redesign`_

---

## The brief (owner, verbatim)

> "UX is the biggest killer of this app, it sucks. I don't see enough value, too
> much text and useless info. The app must confidently replace a human
> communications coach AND keep users coming back — not from shallow gamification
> but from IMMENSE VALUE. Make it look amazing. I want dopamine-inducing
> animations like Duolingo."

The owner's instinct is right but mis-aimed. The problem is **not too little** —
it is that real value is **buried under text and contradicted by broken state
wiring**. The fix is overwhelmingly **subtraction + one source of truth per
metric + making real progress FELT**, not more features and not Duolingo's
coercion stack.

---

## Shared diagnosis — why the app feels low-value and text-heavy

All three leads converged on the same root cause, from three angles. **The
coaching LOGIC is genuinely deep** (verified in source: tone-drill trajectory
detection, SOLVED-ribbon crossing logic, `CoachCaseFile`, delivery profile,
weekly check-in, distanceFromGoal). **But the UI does three things that destroy
the value before the user can feel it:**

**1. It fabricates a power-user the user never became, then can't show real
progress to the user who did.** The state gradient is both *inverted* and
*frozen*.

- _Inverted (fabrication on day zero):_ a true-zero account (`A-cold-profile-1top.txt`)
  is shown `"Your highest rating yet."` with `"400 / Peak this week"` and
  `"+0 / vs all-time"`, plus a `"Silver league, +100 rating to Gold"` standing —
  a peak and a competitive tier before a single word is spoken. To its credit,
  the same screen *does* correctly read `"0 XP"`, `"1,000 to level up"`, `"0%"`,
  and `"Beginner Speaker I"` — so the baseline plumbing exists; the celebration
  and league surfaces simply ignore it.
- _Frozen (amnesia for the user who invested):_ the identity card is
  **byte-identical** across 5 / 12 / 20 sessions — `"Beginner Speaker II"`,
  `"91%"`, `"1,909 XP"`, `"91 to level up"`, and the per-mode mastery rows
  (`"Timed, level 3, Steady. 20 reps · 391 XP to Lv 4"`, etc.) are the same
  three numbers in `B-`, `C-`, and `D-profile-1top.txt`. The Path interior is
  identical in all four states (`"0% revealed"`, `"No streak yet"`,
  `"still cutting the first line through the grass"`). The home journey card
  reads `"First lesson cleared. Mission 5 of 20"` to a 20-session user. The Ask
  Noum coach brief is identical cold-vs-veteran: `"I need one clean rep to
  sharpen the read"` / `"Establish a baseline"` is shown to the `D-plateaued`
  account with 20 reps behind it. A coach's defining trait is **memory**; this
  reads as amnesia, and the moment a returning user notices their numbers never
  moved, trust is gone. The one metric that *does* respond is the Speaking
  Rating (`Peak: 624` at C vs `Peak: 740` at D) — proof the pattern is fixable.

**2. It tells value instead of showing it, and drowns the one real signal in
text.** The deep read exists but is rendered as paragraph-four grey decoration.
Profile stacks 15+ instrumentation modules in one ~2,600pt scroll; the
"How well Noum knows you" / clinical ladder renders mostly as `"No working read
yet"` empty circles — the screen that most loudly claims a relationship is the
one proving there isn't one. Session-history rows repeat one long AI coaching
sentence verbatim down the list. Settings is a flat ~3,600pt wall (including an
"AI USAGE" budget explainer with `"0 of 12"` meters). The owner's "too much
text and useless info" is **literally** on screen.

**3. It leaks internals and imports anti-goals, breaking the premium illusion.**
Coaching rationale is written in **third person about the user** —
`"The user has drifted off rhythm, so the next drill should reconnect them…"`
and `"Their goal depends on sounding right with another person…"` (verified in
`Noum/PracticeSupport.swift:8824` / `:8835`) — reading as a leaked LLM prompt,
not a coach speaking to you. The mode picker ships hearts/lives vocabulary:
`"Avoid one specific word for 60 seconds. 3 hearts, no second chances."`
(verified `Noum/PracticeModeSelectionView.swift:94`) plus a `"Sudden Death"`
mode — a **named VISION anti-goal**. The post-rep screen can lead with
`"Time Broke You"` / `"2/10"` (verified `Noum/PressureTimerEngine.swift:292`),
a punish-shame verdict that **violates the never-punish-shame invariant** and is
reachable as a new user's first felt outcome.

**The throughline:** the value is real but **unfelt, untrue at the edges, and
buried**. Every lead's prescription is the same shape — cut the fabrication and
the clutter, wire the real signal to the surface, and make ONE honest, evidenced
read the hero of each screen. The cold empty states for Home, Coach, and Review
already prove the team can do this (`"Welcome. One short rep sets your starting
line. Begin · First rep"`); the job is to make every other surface obey that
pattern.

**On the "Duolingo dopamine" ask — unanimous:** do NOT answer it with
badges/hearts/streaks. The real dopamine is the post-rep moment where Noum names
a pattern with **evidence from the user's own voice**, and the unfakeable
A/B replay ("week-1 you" vs "today you" with a real filler-rate delta) — a moat
Duolingo structurally cannot copy. Motion belongs ON honestly-earned moments
(a real path segment revealing, a real peak crossed, the SOLVED ribbon firing on
the actual crossing rep), never on fabricated ones.

---

## Consensus priorities (all three leads, in order)

1. **Stop lying about progress.** Gate every celebration/standing/peak/tier
   behind real evidence (≥1 rated session). On zero data, show only what the
   user earned. This is the single biggest violation of the believable-progress
   north star and the precondition for everything else.
2. **Make real progress visible — wire the frozen surfaces to live data.** Path
   reveal, streak, identity level, per-mode mastery, home mission counter, and
   the coach brief must advance rep-over-rep, or be cut until they can. A frozen
   number presented as progress is worse than no number.
3. **Subtract ruthlessly; make each surface state ONE thing.** Rebuild Profile,
   Home, and Settings around a single hero read + one action; demote everything
   else behind a disclosure. This directly answers "too much text and useless
   info."
4. **Make the post-rep moment the hero — one evidenced verdict, instantly,
   from rep #1.** Lead with the weakness named from the user's own voice + one
   proof number + one action. This is where the "immense value" and the honest
   "dopamine" both live.
5. **Purge anti-goal violations and leaked internals.** Hearts/lives language,
   punish-shame titles, fake-peer leagues, third-person coaching strings,
   cosmetic location prompt, dev tooling on a user-reachable surface.
6. **Convert the relationship surfaces from claims to evidence.** Honesty should
   read as confidence ("your league forms after your first week"), not as
   foregrounded absence (seven empty "not enough data" circles).

---

## Cross-role tensions (and the head-of-product call on each)

### Tension 1 — Severity of the "Debug: Simulate Days" panel

- **QA view:** Critical. Claimed it "ships in the user-facing Path screen with
  NO build guard … End users on TestFlight/release see and can drive dev
  tooling."
- **UX view:** Critical. "Compile-flag the debug simulator out of every
  non-debug build immediately."
- **Verified reality:** The panel at `Noum/PathJourneyView.swift:84` is gated
  behind `if AuthManager.shared.isDeveloper`, and `isDeveloper`
  (`Noum/AuthManager.swift:67`) is `true` only when the signed-in account ID is
  in `AIConfig.plist → DEVELOPER_ACCOUNT_IDS`. It is **not** visible to ordinary
  TestFlight/release users; it appears in the audit capture because the
  screenshots were taken on a developer account.
- **My call:** **Downgrade the user-facing-fabrication framing — QA's claim is
  overstated.** BUT two real issues remain and one is critical: (a) **code
  hygiene (medium):** a runtime account-allowlist is weaker than a `#if DEBUG`
  compile guard; wrap it so it physically cannot compile into a release binary —
  cheap insurance. (b) **the actually-critical issue (which both leads correctly
  sensed underneath this):** the Path's `snapshot` is wired through
  `withSimulatedDays(debugDayOverride)`, and with the override at its default it
  sits at Day 0 — which is **why the Path is byte-identical across all four
  states.** The fix is not the guard; it is binding Path reveal/streak/milestones
  to the live session+streak stores (Ranked Fix #2). Be precise: ship the guard,
  but call the frozen wiring the critical item.

### Tension 2 — "Add a dopamine reward moment" vs "subtract, don't add"

- **Market view:** Build ONE earned post-rep celebration (coach sentence on a
  real delta + restrained waveform-settle animation + a path segment revealing).
  "The highest-frequency dopamine beat in any practice app is absent."
- **UX view:** The dominant lever is **subtraction**; "do NOT answer the
  Duolingo brief with more badges."
- **My call:** **Not a real conflict — both are right, and the sequence
  resolves it.** Subtraction first (it's free and it's most of the win), then
  add exactly ONE thing: the evidenced post-rep payoff, anchored to a real delta,
  fired only on genuine wins. It is *addition by subtraction* — it replaces six
  competing chip rows with one hero verdict. It trips zero anti-goals because
  something real happened. The animation is on-brand (composed from the existing
  `NoumCharacter` waveform SF Symbols, per the brand-rule constraint). Build it,
  but only after the fabrication is gone — celebrating on fake data is the
  hollow-celebration anti-goal.

### Tension 3 — Profile overload: "simple mode toggle" vs "cut and reorder"

- **Market view (explicit):** Do **not** add a parallel "simple mode" toggle —
  "that's layering, not the subtraction the owner asked for." Lead with the
  one-line read + one action, collapse the rest behind "See the evidence."
- **UX view:** Move XP/league/achievements/matrix/social funnel "off the main
  scroll behind a single 'Stats' disclosure."
- **My call:** **Agreement, not tension — and Market's framing is the guardrail.**
  One Profile, reordered: hero rating + direction + small real sparkline at the
  top, ONE next action, everything else one tap down. No mode toggle, no second
  Profile. A disclosure is subtraction from the default view; a toggle is a
  parallel system (and CLAUDE.md bans parallel systems).

### Tension 4 — The League surface: fix it vs demote/replace it

- **QA view:** Populate League from `LeagueManager` (real user row + real peers);
  fill the user's own STREAK/THIS WEEK from local data; honest pre-launch state
  until peers are live.
- **Market view:** **Demote the league out of the retention center entirely** and
  ship NOTHING fake — replace fabricated standings with a private,
  transcript-free belonging signal, because the league is "the lowest-value,
  most addiction-loop-shaped surface in the corpus."
- **My call:** **Sequence them; Market sets the destination, QA sets the floor.**
  Immediately (both agree): kill the fabricated `"Silver / +100 to Gold"` tier on
  zero reps and the `"Sample peer"` rows; show an honest unranked/placement state
  that assigns no tier and no sample leaderboard (the existing
  `"SAMPLE STANDINGS · LIVE DATA APPEARS AS THE BUCKET FILLS"` disclaimer shows
  the right instinct but still presents a fake tier above it). Then, on strategy:
  **do not make League a primary retention surface** — the north-star retention
  surface is the user's own rating trajectory + the A/B voice replay, not peers.
  Wire real peer data only when it exists, and even then keep it secondary.
  Reconcile QA's "fill the user's own streak even before peers" with this: yes —
  the user's own STREAK/THIS WEEK showing `"—"` even at 20 sessions
  (`D-plateaued-league-1top.txt`) is a plain bug regardless of the strategic call.

### Tension 5 — Day-zero copy: "I read your last 30 days" / "starting line"

- **Market view:** This copy "claims history the user doesn't have" and "flirts
  with implying parity from no evidence" — swap to the honest diagnostic frame.
- **UX view:** Listed the cold Home/Coach copy as the **north-star pattern to
  keep and propagate.**
- **Verified:** `A-cold-home-1top.txt` carries both `"One short rep sets your
  starting line."` (clean, honest, forward-looking) AND `"I read your last 30
  days before every reply."` (false on day zero).
- **My call:** **Both are right about different sentences — split the baby.**
  KEEP the structure and tone of the cold Home/Coach (one honest line + one CTA,
  zero fabricated numbers) — it is the proven standard. FIX the specific
  retrospective overclaim: `"I read your last 30 days"` must not appear before 30
  days exist; replace with the diagnostic promise already proven on the same
  screens (`"Give me one rep and I'll name your lever"`). "Starting line" as a
  forward promise is fine; "last 30 days" as a claimed past is not. This honors
  VISION's hard rule: never imply parity/history from no evidence.

### Tension 6 — Weak-evidence framing on the beginner home headline

- **QA view (caution):** `B-beginner-home` leads with `"45 clean."` and
  `"your confident tone landed only 0% of the time"` on a 5-rep sample — a
  punish-leaning `0%` headline on thin evidence, in tension with the
  "weak evidence → softer feedback" invariant.
- **UX view:** This evidenced personal read is the **real product** — promote it
  to hero type.
- **My call:** **Both hold if you respect the evidence threshold.** Promote the
  evidenced read to hero — it IS the differentiator. But the magnitude of the
  claim must scale with evidence depth: no stark `"0%"` headline on a 5-rep
  sample; soften to the next actionable rep and qualify the deficit ("early
  signal — your confident tone hasn't landed yet; let's get a cleaner read").
  The coaching-logic invariant ("weak evidence → softer feedback; never
  punish-shame") is non-negotiable and the source already has the
  evidence-floor machinery (`CoachParityReadiness`, self-suppressing cards) to
  do this correctly.

---

## Ranked fix list

Ordered by impact-to-effort. "Effort" is relative engineering cost given the
existing architecture (most fixes are subtraction or wiring to stores that
already exist).

| # | Fix | Impact | Effort | Screens (evidence) | Why |
|---|-----|--------|--------|--------------------|-----|
| 1 | **Gate every celebration / standing / peak / tier behind ≥1 rated session.** No "highest rating yet", no "Peak 400", no "Silver league / +100 to Gold", on a zero-rep account. Reuse the true-zero baseline the same screen already computes. | High | Low | `A-cold-profile-1top` (`"Your highest rating yet."` + `"400 / Peak this week"`), `A-cold-league-1top` (`"Silver / +100 rating to Gold"`), `O-01..O-05` (seeded home behind onboarding) | Single biggest believable-progress violation; trips fake-progress + hollow-celebration + vanity-dashboard anti-goals at once. Cheap because the baseline plumbing exists. |
| 2 | **Wire the frozen surfaces to live session/streak data: Path reveal %, streak, milestones; identity level + XP; per-mode mastery; home mission counter; Ask Noum coach brief.** Stop reading the Path through the debug day-override. | High | High | Path `"0% revealed"`/`"No streak yet"` identical across `A/B/C/D-path-1top`; identity `"1,909 XP"`/`"91%"` identical across `B/C/D-profile-1top`; brief `"establish a baseline"` identical across `A/B/C/D-ask`; `"Mission 5 of 20"` identical across `B/C/D-home` | A coach's defining trait is memory; frozen numbers read as amnesia and silently destroy trust. The Speaking Rating already moves (624→740), proving the pattern is fixable. |
| 3 | **Make the post-rep verdict the hero: ONE evidenced "Fix this first" — weakness name + one proof number from the user's own voice + one action — present from rep #1 (softened on thin evidence).** Demote score/duration/fillers/WPM to one quiet strip; delete the apologetic "See full review" subtitle. | High | Medium | `09-session-detail` (six numbers across three chip rows + apologetic subtitle), `B-beginner-review-1top` (no verdict block at 5 sessions), `C-improving-review-1top` (identical template on both drill cards) | The app's single highest-value beat, currently buried and gated backwards. This is where "immense value" is felt in <2s. |
| 4 | **Build ONE earned post-rep payoff moment anchored to a REAL delta** — one coach sentence naming what changed vs last time + a restrained `NoumCharacter` waveform-settle + a path segment revealing right there. Fires only on genuine wins. | High | Medium | `09-session-detail` (static pill grid, no reward beat), `C-improving-bigmoment` (the "moment" screen is just the prep form), `C-improving-path` (best motion in the app, stranded a tab away) | The honest answer to "Duolingo dopamine." Scarcity keeps it premium; it trips zero anti-goals because something real happened. Depends on #1+#2 (never celebrate fake data). |
| 5 | **Rebuild Profile around ONE hero metric** (Speaking Rating + direction arrow + small real sparkline, peak shown once) + ONE action; collapse XP/league/achievements/per-mode/clinical-matrix/social funnel behind a single disclosure. Reconcile contradictory trend/peak/"new high" copy to one computed narrative. No "simple mode" toggle. | High | Medium | `C-improving-profile-1top/2mid` (25+ competing numbers), contradiction: `B-beginner` shows `"highest rating yet"` + `"Peak 740"` while `D` (the 740 account) omits it; `"Holding steady"` + `"new high"` + `"-12 to all-time"` coexisting | Turns the vanity dashboard the owner hates into the believable-progress mirror. Answers "am I getting better, and by how much" in 5s. |
| 6 | **Rewrite all third-person coaching rationale to second person; audit for any "the user"/"their"/"them".** | High | Low | `C-improving-train`/`D-plateaued-train` (`"The user has drifted off rhythm…"`, `"Their goal depends on sounding right…"`) — source `Noum/PracticeSupport.swift:8824`/`:8835` | Leaked LLM planning register; a coherence-killing tell that a coach is not actually speaking to you. Trivial string fix, high trust payoff. |
| 7 | **Strip hearts/lives + punish-shame from the coaching surface.** Reword `"3 hearts, no second chances"` to a neutral constraint ("three slips ends the rep"); reframe `"Sudden Death"` as a precision/focus challenge; replace `"Time Broke You"` / `"Missed the Mark"` verdict titles with neutral factual titles (mode + topic). Gate pressure modes until a fair baseline exists. | High | Low | `A-cold-train` (`"3 hearts, no second chances"`, `"Sudden Death"`) — source `PracticeModeSelectionView.swift:94`; `09-session-detail`/`C-improving-review-2mid` (`"Time Broke You"`, `"Missed the Mark: Off-Topic and Unprofessional"`) — source `PressureTimerEngine.swift:292` | Two named anti-goals (hearts-and-lives gating; punish-shame a miss) shipping in pixels. Worst possible first felt outcome for an anxiety-prone audience. |
| 8 | **Converge the active Home onto the calm cold Home:** one coach hero (evidenced read in plain words) + one Begin + at most one quiet secondary strip. Cut the disabled daily-challenge XP checklist, the wandering voice-metrics %, and the under-hero utility row (flame/Word-of-the-day/soundscape mute). | High | Medium | `C-improving-home-1top/2mid/3bottom` (five equal-weight cards; 3 Disabled challenge rows with `+25/+35 XP`; voice % wandering 83→95→91); `A-cold-home` proves the calm target | The dashboard the owner explicitly hates; converging on the proven cold pattern is mostly deletion. |
| 9 | **Remove the cosmetic location-permission prompt; derive day/night from the device clock/timezone** (the `.approximateCurrent` fallback already exists and is already the failure path). | Medium | Low | `A-cold-path-1top` (OS location prompt on cold Path open) — source `PathJourneyView.swift:1688`/`1692`, fallback at `:1709`/`:1759` | Privacy red flag on a coaching app + App-Review-rejection risk (cosmetic purpose string) + setup-friction ban. The non-cosmetic path already exists. |
| 10 | **Fix day-zero overclaim copy:** replace `"I read your last 30 days before every reply"` (shown on a zero-day account) with the honest diagnostic frame ("give me one rep and I'll name your lever"). Keep the cold-Home/Coach structure as the cold-start standard. | Medium | Low | `A-cold-home-1top`/`A-cold-ask` (`"I read your last 30 days"`), `O-05-summary` | VISION hard rule: never imply history/parity from no evidence. Keep the proven calm pattern; fix the one false sentence. |
| 11 | **Radically subtract Settings** into a short root (~1.5 screens, 4–5 grouped destinations) with rare items one level down. Delete the "AI USAGE" budget explainer + `"0 of 12"` meters; handle degradation silently. Cut per-row captions on obvious toggles. For a zero-data guest, reduce Account to a single "Sign in to sync." | Medium | Medium | `A-cold-settings-1top/2mid/3bottom` (~3,600pt, 14 sections, AI-budget prose, full storefront + Restore/Delete/Diagnostic for a guest) | "Too much text and useless info" at its most literal; exposes cost-control internals as features. |
| 12 | **Reconcile the peak-rating hero to a single source of truth** (hero reads the same value as the rating card; one delta label; one headline rule keyed off the real comparison). Remove the hardcoded 400/+0 fallback. | Medium | Low | `B-beginner-profile-2mid` (`"Peak 740"` card vs `"400 Peak this week"` hero), `C-improving` (`"+0"` delta vs body "12 above where you sit"), `D-plateaued` ("to all-time" vs "vs all-time") | One component, multiple sources of truth, reading as a bug on the surface meant to prove progress. (Largely folded into #5.) |
| 13 | **Convert relationship surfaces from claims to evidence:** hide clinical-ladder stages with no data (or reframe as "3 more reps and I can name your pattern"); replace the fake-peer league with an honest placement state; fill the user's own STREAK/THIS WEEK from local data. | Medium | Medium | `C-improving-profile-2mid` (7-stage "knows you" ladder, mostly empty circles); `A-cold-league`/`D-plateaued-league` (`"Sample peer"`, user's own `"—"` even at 20 sessions) | The screen that claims a relationship currently proves there isn't one. Keep the honesty *instinct*; stop expressing it as half-empty rubrics. |
| 14 | **Compress the pre-speak funnel** to one decision + a permission ask: route cold "Begin · First rep" straight into the recommended Timed rep with the computed weakest-area theme; defer the 8-mode catalogue + Classic/Coach paywall fork behind "see other modes" until after rep 1; move the mic ask to the first rep with a one-line reason and a denied-state path. | Medium | Medium | `A-cold-train` (8-mode jargon menu), `14-timed-setup` (mic prompt after full setup, no denied path) | Time-to-first-value matters most for a cold user; four gates before speaking is the opposite of a coach hand-off. |
| 15 | **Make Lessons + Speech Projects personalized and progress-aware:** one "do this next, because of YOUR last reps" anchor on each (reuse the Train "Recommended" pattern); real per-item mastery state; make ≥1 lesson step actually DO something (spot-it/say-it). Cut the "Inspired by Toastmasters Pathways" line. | Medium | Medium | `19-lessons-home` (`"CROWNS 0/25"`, "earn your FIRST crown" regardless of state), `20-lesson-detail` (three read-and-tap text screens), `21-speech-projects` (8 identical rows, competitor anchor) | Where coaching depth should be most evident, currently static and state-blind. |
| 16 | **Close the real-world-transfer loop:** after a Big Moment passes, have the coach ask how it went and capture the user's read of audience reaction; pay off Save with a concrete promise + countdown. | Medium | Medium | `C-improving-profile-2mid` (`"Real-world transfer: no real-world outcomes reported yet"`), `A-cold-bigmoment` (captures the event, never follows up) | The one thing the category admits AI can't assess, left as dead text; the most coach-like longitudinal data the product could own. |
| 17 | **Build the A/B voice replay** ("week-1 you" vs "today you", two waveform clips + one honest filler-rate delta) and make it — not the league — a primary retention surface. | High | High | (new surface; motivated by `C-improving-path` being the best-executed, most-stranded motion + the buried evidenced reads) | The honest version of "Duolingo dopamine": unfakeable, the north-star "visible believable progress" made literal, trips zero anti-goals, structurally uncopyable by Duolingo. Sequenced last because it depends on real session history (#1+#2). |
| 18 | **Fix systemic a11y plumbing:** give each screen's root its own identifier (stop applying `home.screen` to Profile/Review/League/Train roots); apply `accessibilityHidden`/`accessibilityViewIsModal` to the presenting view behind every sheet/cover; collapse duplicated level-badge / coach-brief double-reads; hide decorative SF Symbols that leak labels ("Flame"/"Favorite"/"Walk"). | Medium | Medium | root `'home.screen'` on `A-cold-profile-1top`/`A-cold-review-1top`/`C-improving-league-1top`/`A-cold-train`; modal exposure on `A-cold-bigmoment`/`O-01..O-05`; decorative leaks on `A-cold-profile-1top` | Breaks VoiceOver landmarking + makes screens indistinguishable to UI-test/deep-link targeting; the make-or-break first-run surfaces are the worst affected. Contained pass — fixing duplication + identity + modal hiding, not relabeling from scratch. |
| 19 | **Code hygiene:** wrap the "Debug: Simulate Days" panel in `#if DEBUG` so it cannot compile into a release binary (currently only runtime-gated by `AuthManager.isDeveloper`). | Low | Low | `D-plateaued-path-3bottom` (panel visible on the developer-account capture) — source `PathJourneyView.swift:83` | Not user-facing today (account-allowlist gated), so NOT the critical issue QA framed it as — but a compile guard is cheap insurance and the right pattern. The *critical* part of this (Path wired through the override) is Fix #2. |

---

## Cut list (delete or hide — subtraction is the dominant lever)

**Fabricated data (must not appear without real evidence):**
- The `"Your highest rating yet."` + `"400 / Peak this week"` + `"+0 / vs all-time"`
  celebration on a zero-rep Profile (`A-cold-profile-1top`).
- The `"Silver league, +100 rating to Gold"` standing on a zero-rep account
  (`A-cold-league-1top`, `A-cold-profile-1top`).
- The seeded power-user Home rendered behind every onboarding stage
  (`O-01..O-05`); onboarding must present over a neutral/empty backdrop.
- The `"Sample peer"` league rows at every tier (`A-cold-league`,
  `D-plateaued-league`), and the user's own STREAK / THIS WEEK `"—"` even at 20
  sessions — replace with the user's own real rating trajectory + an honest
  placement state.

**Anti-goal violations (named in VISION):**
- Hearts/lives vocabulary: `"3 hearts, no second chances"` and the
  `"Sudden Death"` framing (`A-cold-train`; source `PracticeModeSelectionView.swift:94`).
- Punish-shame session titles: `"Time Broke You"`, `"Missed the Mark: Off-Topic
  and Unprofessional"` (`09-session-detail`, `C-improving-review-2mid`; source
  `PressureTimerEngine.swift:292`).
- The `+20 XP` chip on the rep-detail surface (shown even on a failed 2/10 rep)
  and `"+80 XP"` attendance challenges that reward calendar presence over
  speaking improvement (`09-session-detail`, `A-cold-profile-1top`).

**Leaked internals / dev tooling:**
- Third-person coaching rationale: `"The user has drifted off rhythm…"`,
  `"Their goal depends on sounding right…"` (`C-improving-train`; source
  `PracticeSupport.swift:8824`/`:8835`).
- The cosmetic OS location-permission prompt on cold Path open
  (`A-cold-path-1top`; source `PathJourneyView.swift:1692`).
- The "Debug: Simulate Days" panel from release binaries via `#if DEBUG`
  (`D-plateaued-path-3bottom`; source `PathJourneyView.swift:83`) — runtime-gated
  today, but compile-guard it.

**Text bloat / useless info:**
- The "AI USAGE" Settings section: budget-explainer paragraphs + `"0 of 12"` /
  `"0 of 20"` meters (`A-cold-settings-3bottom`) — handle degradation silently.
- The entire "How well Noum knows you" clinical matrix when empty
  (`C-improving-profile-2mid`) — reframe or hide stages with no data.
- The per-mode "Mode Mastery" XP block on Profile + per-mode level pills on the
  Train picker (`"Lv 3 Steady"`, `"Lv 2 Reactive"`) — a second/third unexplained
  progression vocabulary (`B/C/D-profile-1top`, `B-beginner-train`).
- The home daily-challenges card (3 Disabled rows as a tappable checklist with
  near-invisible XP labels) and the context-free wandering voice-metrics %
  (`C-improving-home-1top/3bottom`).
- The under-hero Home utility row: flame `"No streak yet"` (even at 20 sessions),
  `"Word of the day"` widget, soundscape mute (`A-cold-home-1top`,
  `D-plateaued-home-3bottom`).
- The per-row coaching sentence repeated verbatim down the session-history list,
  and the identical template on both "MISTAKES TO FIX" drill cards
  (`C-improving-review-2mid`, `C-improving-review-1top`).
- The apologetic `"See full review — open only when you want more detail"`
  subtitle (`09-session-detail`).
- The `"Inspired by Toastmasters Pathways"` line (`21-speech-projects`) — anchors
  Noum to a competitor; own the value.
- Day-zero overclaim `"I read your last 30 days before every reply"` on a
  zero-day account (`A-cold-home-1top`, `A-cold-ask`).
- The orphaned `"To speak like a king."` string with no caption in the populated
  Settings/Profile coaching section (`B-beginner-profile-1top`) — reads as an
  unfilled placeholder.
- Duplicate Coach-header identity labels (`"COACH"` + `"with Noum"` + `"Noum"`)
  and the destructive `"Leave"` button sized equal to primary `"Talk"`.
- Raw profanity in scannable Review previews — show the coach verdict line as the
  preview, keep the full transcript in detail.

---

## What to keep and amplify (the design north star already lives in the app)

- **The cold empty states for Home, Coach, and Review** — `"Welcome. One short
  rep sets your starting line. Begin · First rep"`, `"I need one clean rep to
  sharpen the read"`, `"Your first session is the hardest"` — one honest line +
  one CTA, zero fabricated numbers. Make this the cold-start STANDARD every other
  surface obeys, and converge the active states onto it.
- **The restrained soft-sell surfaces** — notification pre-prompt
  (`27-notification-pre-prompt`: "No marketing, no spam" / "Maybe later") and the
  inline goal direction check (`26-goal-refresh-inline`). Use their
  tone/structure as the template for EVERY permission or upsell moment, with
  inline coaching preferred over modal interruption when the user can keep going.
- **The genuine evidenced coaching signal that already exists but is buried** —
  e.g. "Across your last 5 Social Catch-Up reps your confident tone landed only
  0% of the time." This personal, evidenced read is the real product and the real
  dopamine; promote it to hero type (and scale claim strength to evidence depth).
- **Big Moment / real-event rehearsal** — correctly state-invariant, the app's
  real differentiator vs a streak app. Amplify with an outcome loop after the
  event and a felt prep promise.
- **The longitudinal "Your arc" narrative** (Day 1 Awakening → Today → Next) and
  the named Coaching Profile with the user's own goal ("to speak like a king") —
  relationship-over-time substance no competitor offers. Pull it UP; surface the
  one-line read at the top.
- **The honesty instinct** behind the clinical matrix and the
  `"SAMPLE STANDINGS · LIVE DATA APPEARS AS THE BUCKET FILLS"` label — never
  overclaim, never self-certify parity (the source even structurally caps
  validation at `.forming`). Keep the principle; stop expressing it as half-empty
  rubrics and fake leaderboards. Honesty should read as confidence, not
  foregrounded absence.
- **The premium visual restraint** (mode-tinted capsules, calm card language) and
  the grass-reveal Path motion — the right answer to "make it look amazing."
  Amplify motion ON honestly-earned moments, never on fabricated ones.

---

## What this does NOT recommend (anti-goal compliance)

Per VISION, none of the above recommends toward: a vanity-metric dashboard (we
delete it), a streak-and-badge addiction loop (we cut XP-trickle, attendance
challenges, and the fake league), hollow celebrations / fake unlocks (every
celebration is gated behind real evidence), punish-shaming a miss (we replace
"Time Broke You"), a generic AI chat wrapper, a noisy productivity app, ads,
hearts-and-lives gating (we strip "3 hearts"), or a leaderboard publishing
transcripts. The "dopamine" ask is answered with the user's own improving voice,
not coercion mechanics.

And no recommendation claims coach parity. The honest framing throughout is the
diagnostic coach voice ("give me one rep and I'll name your lever") and visible,
evidence-scaled progress — the product ambition is human-coach replacement, but
nothing here implies parity from one reply, one rep, or one feature.
