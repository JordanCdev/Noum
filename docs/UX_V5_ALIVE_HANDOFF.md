# Noum V5 — "Alive Loop" · UX rescue audit + Figma redesign + SwiftUI handoff

**Date:** 2026-08-19 · **Branch:** `ux-experiment` · **Author:** Claude (principal UX pass, founder brief of 2026-08-19)
**Figma:** https://www.figma.com/design/srCgE5IP3rWoNMWtHo3AnI/ · **Page:** `521:497` **"22 V5 — Alive Loop"**
**Exports:** `artifacts/figma/v5-alive/` (12 PNGs, all `file`-validated)
**Status:** design candidate for founder review → then Codex implementation per this doc.

---

## 1. Blunt audit — why the branch feels empty

Grounded in the 2026-08-19 screenshot sweep (`.screenshots/2026-08-19_autostop-2fe6918d7-0918/`),
the V3 experiment mockups (Figma page 20), the founder checkpoint (page 21), and the branch diff.

1. **The implementation kept V4.6's subtraction and dropped V3's dopamine — the exact inverse
   of what each pass was for.** V4.6 celebrated "−48% visible text" as its goal; the founder brief
   now asks for Duolingo-level momentum. The shipped screens hit the old target, not the new one.
2. **The momentum layer was designed and then lost.** The V3 mockups (page 20, D1) had streak +
   XP pills and a rep ladder with DONE / NOW / LOCKED states. The shipped Home has none of them:
   "Welcome." + one card + one row. `CelebrationViews.swift` (−453) and `PathNodeCelebration.swift`
   (−581) were deleted outright on this branch; the reward layer has no owner.
3. **There is no visible world.** Path, lessons/crowns, league, achievements, XP — all exist in
   code, none are ambient on any tab. Duolingo feels alive because the journey IS the home screen;
   Noum hides its journey behind navigation.
4. **First-run is a void.** Progress tab on day one is a single empty-state card. The V3 promise
   ("populated and alive even for a new user") is unmet: nothing locked-but-visible, no starting
   line, no waiting badges.
5. **The strongest asset was diluted.** The Rep Report reference (score hero + narrative + delta
   chips + pattern card + trend) was subtracted down to quote + phrase + one button. The results
   screen is the product's emotional anchor and currently its flattest surface.
6. **No motion identity.** Static waveform icon, no count-ups, no one-shot celebration, no
   unlock beats. The founder checkpoint's 340ms arming beat exists as a note, not a system.

**What is NOT broken:** the evidence honesty (verified quotes, one lever, honest ledger), the
founder checkpoint law (one mission, one tap, no setup tax), the token system, and the coaching
copy voice. V5 keeps all of it.

## 2. Direction — three inherited laws + one addition

- **Founder checkpoint law (kept):** Home = one mission, one tap. No setup choices on Home;
  Practice owns choice, Home owns momentum.
- **Truth contract (kept, expanded below):** no fake reward, no invented readiness, no
  punish-shame. Every reward traces to verified evidence.
- **V4.6 evidence bones (kept):** WHAT NOUM HEARD → verified improvement → one next move.
- **NEW — the world layer:** streak/XP/path/records become ambient, visible state on every tab,
  fed exclusively by existing owners. Density comes from real state, not decoration.

## 3. Screen-by-screen spec (Figma node ↔ SwiftUI target)

All frames on page `521:497`. Light mode; dark = semantic recolour via existing `Noum/Theme`
tokens (`AppColor` already trait-resolves). Fonts: SF Pro Rounded on device (Figma shows Nunito
per the file's substitution rule); body = system (Inter in mocks).

### V1 · Today — returning (`521:500`) → Home owner (`ContentView` Today section)
- Top strip: `TODAY · DAY 12` eyebrow + **StreakPill** ("12 DAY STREAK") + **XPPill** ("340 XP"),
  reward-gold surface. Data: `StreakFreezeManager` + XP owner. Never rendered without real values.
- Mission headline + meta from the daily goal owner (ordinal + completion state supplied, never
  hard-coded — checkpoint contract).
- **PathHeroCard** (violet gradient): today's rep ladder as a trail — done node (✓), NOW node
  (waveform glyph, ring), locked node ("AFTER REP 2"), then a gold **milestone row** ("First
  Hold — 2 days away") read from the path/milestone owner. Coach line + answer-clock chip stay
  (prescription + exact clock, no invented why).
- CTA `Start rep 2 of 3` (blue `action/primary`, arming beat per motion contract).
- **QuestChip** row: Daily Challenge + Pressure round — real systems only, tinted washes.
- **WeekStrip**: 7 day dots, done=filled, today=ringed, honest count ("5 of 7 days").
- States: mid-mission (shown) / pre-first-rep (V9) / mission complete ("Practice another rep" —
  extra practice optional, completion stays earned, per checkpoint contract).

### V9 · Today — first run (`521:505`) → same owner, day-one content
- Same skeleton, zero fake data: `WEEK 1 · STARTING LINE` pill, path shows Rep 1 NOW +
  labelled locked days (Tomorrow · Day 3) + first milestone; "NO SCORE PRESSURE" chip;
  coach line "I'll find the one thing holding you back."
- "Opens next" previews (Pressure Drill · Records) rendered at 75% opacity — locked but
  labelled, real unlock criteria.
- **Rule: the world is visible on day one; nothing is empty, nothing is invented.**

### V2 · Practice — arcade (`521:501`) → `PracticeModeSelectionView`
- **RecommendedHero** (violet quiet wash + Recommendation elevation): evidence-led why
  ("you rushed 3 of 6 openings this week" — from `TrendAnalyzer`/session history), duration +
  `+XP` + one-clear-target chips, mastery `LV n` chip, inline CTA.
- **ModeCard** 2×2 grid: Pressure Drill / Roleplay / Cut the Crutch / Pace. Each: tinted
  waveform glyph (pattern varies per mode: countdown/dialogue/cut/steady), one-line hook,
  personal stat line (BEST · 5 ROUNDS, "basically" · 7 this wk, 142 WPM avg), difficulty dots.
  Stats come from mode mastery/session owners; a mode with no data shows its hook only.
- Lessons row with crown progress (real `LessonsCatalog` crowns).

### V3 · Recording — live (`521:502`) → `TimedPracticeView` (+ mode variants)
- Focused canvas keeps the existing mode gradient system (`focusedTimedGradient` etc.).
- Glass prompt card; **TimerRing** (donut arc, real remaining time); **LiveWaveform** bound to
  `SpeechRecognizerViewModel` amplitude; pace chip ("IN YOUR BAND") only when pace data is live;
  coach presence line; stop button.
- States: ready → countdown (3·2·1 scale beats) → live (shown) → final seconds (ring amber) →
  processing. Silence state keeps V4.6 behaviour.

### V4 · Rep Report (`521:503`, full-scroll frame, fold marked at 852) → `SummaryView`
**The hero screen — the quality bar for the app.** Order:
1. **RepReportHero** (violet gradient): eyebrow + VERIFIED chip (with duration), score
   **count-up** (`duration/score-reveal` 800ms, haptic .success at landing) + ▲ delta chip,
   one narrative line (from insight owner, template fallback), two evidence chips (fillers ↓,
   wpm in band), gold `+XP · VERIFIED` chip + streak tick. XP appears only if the reliability
   gate passed the rep.
2. **VerifiedImprovementCard**: struck original ("What I'd say is that…") → violet improved
   phrase — word-level transformation, from the rewrite/insight owner; hidden entirely when
   no verified improvement exists (V4.6 coached-absence state applies).
3. **PatternCard** ("WHERE IT KEEPS HAPPENING · LAST 6 REPS"): opening/middle/close segment
   dots + one honest line. Needs ≥4 comparable reps; hidden below evidence floor.
4. **TrendMini**: last-8-reps bars + "+6 this week". Hidden below 3 reps.
5. **NextRepCard** (violet quiet): prescription + clock.
6. CTA `Start rep 3` + quiet `Transcript, scores and Ask Noum ›` (full transcript, scores,
   Ask Noum stay one tap away — never dumped on the hero).

### V5 · Reward — verified milestone (`521:504`) → new one-shot view
- Fires **only** on verified milestone events (readiness gate), max one per rep, never chained
  with the Rep Report (it replaces the hero entrance, then continues to evidence).
- Violet blobs + **waveform-bar confetti** (single 600ms fall — brand-safe, no illustration),
  VERIFIED MILESTONE chip, "THAT LANDED.", gold milestone card (+XP · criteria line), COACH WIN
  card ("VERIFIED FROM BOTH REPS"), path-unlock row → record. RM: static, no confetti.
- `CelebrationViews.swift` was deleted on this branch — rebuild from scratch to this spec;
  do not resurrect the old file (it celebrated unverified events).

### V6 · Progress (`521:506`) + V6b day-one (`521:507`) → `TrajectoryView` / `SessionHistoryView`
- Populated: trajectory line+area chart (Swift Charts) + "▲ +6 THIS WEEK" chip; **SkillBars**
  (Clarity/Fillers/Pace/Composure with LV chips — skill-level owners); **EvidenceLedger** rows
  (wins ✓ green wash; lapse = neutral amber dot, respectful copy: "Rushed the close — worth one
  retry"); weekly review row.
- Day one (V6b): **StartingLineCard** — baseline score + filler/wpm chips + ghost dashed line +
  "Day 2 draws your line — same time tomorrow." Never an empty state.

### V7 · You — records (`521:508`) → `ProfileView` + `AchievementsTreeView` data
- Header: waveform avatar, name, "Day 12 · Peak 78 · Silver league".
- **StreakCard**: big count + freeze chip ("1 FREEZE READY" — visible, auto-spend never silent)
  + best-run mini bars.
- **BadgeGrid**: unlocked = tinted ring + glyph + earned date; locked = grey + progress arc +
  `X / Y · %`. Badges are records of real firsts with visible criteria. Detail view: criteria,
  progress, earn date, linked evidence.
- **LeagueRow**: "#4 of 20 — top 5 promote · resets Sunday · rating only, never words."
- **BigMomentRow** when an event exists. Coaching record link row stays (trust surface).

### V8 · Pressure Drill (`521:509`) → `SuddenDeathPracticeView`
- Pressure gradient canvas; round ladder R1✓ R2✓ **R3** R4 R5 + gold BEST chip; ANSWER NOW
  prompt flash; shrinking-window ring (0:07); **FillerAllowance** ("1 OF 2 USED" — resets each
  round, never gates starting practice; explicitly not hearts/lives); live waveform; coach line;
  stop. Escalation: window shrinks per round (30s → 8s). Out state: "Round over — you held 3.
  Again?" one-tap retry.

## 4. Component inventory (new reusable SwiftUI views)

`StreakPill` · `XPPill` · `WeekStrip` · `PathHeroCard`/`PathTrail` · `QuestChip` ·
`RecommendedHero` · `ModeCard` · `TimerRing` · `LiveWaveform` · `WaveformGlyph` (parametric bar
pattern — the only brand mark) · `RepReportHero` · `VerifiedImprovementCard` · `PatternCard` ·
`TrendMini` · `NextRepCard` · `MilestoneCelebration` · `StartingLineCard` · `SkillBars` ·
`EvidenceLedgerRow` · `BadgeView`/`BadgeGrid` · `LeagueRow` · `BigMomentRow` ·
`PressureRoundTrack` · `FillerAllowanceMeter` · `FloatingTabBar` (4 items: Today · Practice ·
Progress · You).

All views take real model inputs; previews use `DevSeedData`-style realistic fixtures (respect
the 110–135 WPM transcript realism rule) so no preview ever looks empty.

## 5. Token additions to `DesignSystem.swift`

Figma `Noum/Theme` already carries them; mirror into `AppColor` with AA-checked registers
(add pairings to the contrast-guard test table — do not lift existing tokens):

- `rewardGold` `#F5B800` (dark `#F8C84A`) — fills/chips only
- `rewardSurface` `#FFF4C7` (dark `#352807`)
- `rewardOnGold` `#5B3A00` (dark `#241700`) — the ONLY text ink on gold surfaces
- Existing violet family/action-deep/positive tokens cover everything else. Raw-hex exceptions
  in the mocks (`#FFE9A8` milestone text on violet, `#7BE6A8` positive-on-violet) need named
  on-accent registers with the same treatment.

## 6. Truth contract (binding for implementation)

1. XP is earned only from verified evidence — the reliability/readiness gate decides; UI never invents.
2. Streak = real days; freeze auto-spend is visible; a missed day is never shamed in copy.
3. Badges = records of real firsts, visible criteria, X/Y progress. No login-streak spam.
4. Celebrations: one-shot per verified event, never chained, never looping. RM pair mandatory.
5. A lapse renders as a respectful static row. No red, no shake, no punish animation.
6. First-run density comes from the visible world (locked-but-labelled), never fake data.
7. Pressure filler allowance resets per round and never gates practice (no hearts/lives).
8. League shows rating/reps/peak — never transcripts.
9. Evidence floors: pattern card ≥4 comparable reps; trend ≥3 reps; improvement card only when verified.

## 7. Motion contract

Summary on board `538:497`; tokens in Figma `Noum/Motion` (Standard · Reduce Motion modes) map to
existing SwiftUI motion constants. Micro: CTA arm-beat 260ms + .light haptic; chip pop; tab
crossfade. Meso: score count-up 800ms ease-out + .success at landing; XP chip stagger 80ms; path
node advance (bouncy 400); trend bars stagger; recording ring sweep + amplitude bars. Macro:
milestone one-shot (blobs 340 + confetti 600, never loops); badge unlock (0.85→1 spring + one
glint); streak tick; round advance (.medium haptic). **Every beat's RM pair: final values render
immediately, no loops, haptics kept.**

## 8. Build order + acceptance

Order: tokens → momentum components → Today (V1/V9) → Rep Report + Reward (V4/V5) → Practice
(V2) → Progress (V6/V6b) → Records (V7) → Pressure (V8) → polish (haptics, RM, AX labels,
Dynamic Type, dark).

Accept when: no tab is ever empty (day-one included); Home answers "what do I do" in one glance
and one tap; Rep Report feels celebratory and specific with the transcript one tap away;
progression is ambient on every tab; every reward traces to a verified event; build green;
previews for every new component; existing UI-test accessibility ids preserved (container ids
must not stomp child ids — known trap); full suite scope-named honestly (NoumTests green ≠ suite
green).

## 9. Traps and notes for Codex

- `CelebrationViews.swift` / `PathNodeCelebration.swift` are deleted on this branch — build the
  new one-shot celebration fresh; don't revert the deletions.
- Founder checkpoint (Figma page 21) governs Home: goal owner supplies ordinal/completion; Home
  never hard-codes "1 of 1"; no "Change this rep" on Home (Practice owns adjustment).
- Tab rail is 4 tabs (Today · Practice · Progress · You); Settings lives behind You. `AppShellView`
  currently models 5 — reconcile with its accessibility-id contract intact.
- Reduced Motion: read the existing app-wide setting; the pre-rep soundscape stop rules and
  aborted-rep evidence floor are invariants — celebration/XP must respect the same gates.
- Dark mode ships via existing trait-resolving tokens; don't fork per-screen palettes.
- Dynamic Type: pills wrap to a second row at AX sizes; path trail rows stack; tab labels use
  the large-content viewer (already wired on this branch — keep it).

## 10. Deliverable map

| Artifact | Where |
|---|---|
| Figma page (10 frames + 2 boards) | `srCgE5IP3rWoNMWtHo3AnI` page `521:497` |
| Node IDs | V1 `521:500` · V2 `521:501` · V3 `521:502` · V4 `521:503` · V5 `521:504` · V9 `521:505` · V6 `521:506` · V6b `521:507` · V7 `521:508` · V8 `521:509` · Motion `538:497` · Handoff `539:497` |
| Validated exports | `artifacts/figma/v5-alive/` (12 PNGs) |
| This spec | `docs/UX_V5_ALIVE_HANDOFF.md` |
