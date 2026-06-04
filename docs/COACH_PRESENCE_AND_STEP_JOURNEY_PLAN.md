# Noum — Living Coach Presence + "One Step at a Time" Journey

**Status:** Design proposal for review (Claude). Cross-check with Codex + Gemini before implementation.
**Branch:** `Redesign`
**Author:** Claude (Opus 4.8) — grounded in a full read of `VISION.md`, `CURRENT_STATE.md`, and a code map of the relevant subsystems (file/line references throughout).
**Date:** 2026-06-04

---

## Status — decisions locked (2026-06-04)

User picks are in; this is now a build plan, not just a proposal.

- **Coach face (Pillar A): Living Orb** — a persistent, *reacting* `NoumCharacter` in-thread + progressive reply reveal. No face/avatar (brand rule held). Implemented in `Noum/AskNoumView.swift`; concept board at `docs/concepts/coach_presence_concepts.png`.
- **Reply animation:** client-side progressive reveal (decision #1) — provider-agnostic, reduce-motion → instant.
- **Miss handling:** never reset; re-anchor on the next small step + a gentle landscape recede (decision #4). Hard reset rejected (violates never-punish-shame).
- **Path consolidation:** keep both renderers, one shared goal anchor (decision #3).
- **Pillar B build spec:** `docs/PILLAR_B_GOAL_JOURNEY_BUILD_SPEC.md` — adversarially verified against the real code; caught 2 real bugs (progress-% inversion, per-metric evidence floor). **Its §9 has 6 open questions still needing your/Codex/Gemini sign-off** (esp. the counterfactual-baseline gap + double-overlay precedence).

Remaining open product decisions live in §10 below + §9 of the Pillar B spec.

---

## 0. How to use this doc (for reviewers)

This proposes two coordinated pieces of work:

- **Pillar A — Living Coach Presence:** make "Talk with Noum" feel like a coach in the room, not an SMS thread.
- **Pillar B — One Step at a Time:** turn the user's monolithic goal into a visible, achievable sequence of small steps, surfaced across the whole app, with honest (never-punishing) miss handling.

Sections 4–5 are the design. Section 8 is the phased plan with verification gates. **Section 10 ("Open decisions") is the most important thing to red-team** — those are the forks where the design could reasonably go another way.

Each claim about current behavior carries a `file:line` reference so reviewers can verify rather than trust.

---

## 1. Grounding (per CLAUDE.md required reading)

- **Milestone served:** This sits *after* M14 (the launch gate). It advances the post-M14 strategic roadmap item #1 ("Coaching case file + intervention cycle... surface it coherently") and the retention loop. It is **net-new product surface**, so it must not regress M14 launch-readiness.
- **Product pillars served:** #4 *Believable progress* (visible improvement, no fake gamification), #5 *Personalized coaching* (adapts to the user's actual patterns), and #1 *Filler reduction* / others as the content of the steps.
- **Coach-parity stages served:** #2 *Case formulation* (the goal decomposition IS a revisable plan), #3 *Intervention* (each step names an observable target), #4 *Adaptation* (steps advance as evidence accrues).
- **Hard invariants that constrain this work:**
  - **Never punish-shame a miss** — only celebrate upward crossings (memory `never_punish_shame`; VISION anti-goals).
  - **No hearts-and-lives gating** — practice must never be blocked by a meta-token (VISION anti-goal).
  - **No fake progress / no overclaiming from thin evidence** (CLAUDE.md coaching invariants).
  - **Brand rule:** no illustration, no literal characters. Visual richness = SF Symbols + motion + color + shape. `NoumCharacter` is the brand presence (memory `brand_rules`).
  - **Weak evidence → softer feedback; repeated patterns → stronger intervention.**

---

## 2. Current-state map (verified)

### 2a. The coach chat ("Talk with Noum" / Ask Noum)

- Whole surface: `Noum/AskNoumView.swift` (2173 lines). State owner: `Noum/AskNoumStore.swift` (`@MainActor ObservableObject`, `.shared`).
- Messages render as **bare alternating text bubbles**: right-aligned `brandBlue` user bubble (`AskNoumView.swift:1449`), left-aligned grey full-width coach card (`:1466`). **No per-bubble avatar** — it was deliberately removed as "visual noise" (`:1467`).
- The `NoumCharacter` orb lives only in a **collapsing header** (60pt → 28pt on scroll, `:372`) and as the **typing indicator** (24pt `.thinking`, `:1531`).
- Replies are **one-shot, not streamed**: `runReply` (`:2067`) → `AICoachChatService.shared.reply(...)` (`:2129`) → `store.completeCoachTurn` swaps the pending bubble's text **wholesale** (`AskNoumStore.swift:186`). No token-by-token motion.
- No timestamps, no read receipts, no in-thread coach presence once you scroll.
- Interactivity (starter chips, follow-up chips, mode-launch CTA, the 3 verdict-chip rows for hypothesis-ack / revised-read / goal-proposal) all sit **outside** the bubbles, appended below the thread.
- Entry: pushed `AppDestination.askNoum` (no dedicated tab) from the Home promo card and the post-rep `TalkToNoumCTACard`.

### 2b. NoumCharacter (the "face")

- `Noum/NoumCharacter.swift` (866 lines) + `NoumCharacterStage.swift` (220 lines).
- **6 moods:** `.calm / .listening / .excited / .coaching / .thinking / .noticing` — each a distinct `waveform.*` SF Symbol + animation.
- **5 lifetime stages** (XP-driven, one-way ratchet): `awakening → voice → composure → command → mastery`.
- Reacts to **live audio** (`audioLevel`), supports **transient `.moodPulse(_:duration:)`**, fully reduce-motion gated internally.
- **The presence we need already exists.** The work is making it *persist and react inside the conversation*, not building a new avatar.

### 2c. Goal, path, streak, reinforcement

- **Long-term goal is monolithic.** `CoachingPriority` (4 cases: `.reduceFillers / .moreConcise / .thinkFaster / .calmerDelivery`, `PracticeSupport.swift:358`) on `CoachingProfile.primaryGoal` (`:492`), owned by `CoachingProfileStore` (`:3399`). Progress = one continuous `CommunicationBaseline.distanceFromGoal(_:)` reading (`BaselineEngine.swift:218`), shown as one ring in `GoalProgressView.swift`. **It is not broken into sub-steps anywhere.**
- **TWO unrelated "path" systems** (architectural smell — see §9):
  - **System A — cosmetic landscape** (`PathJourneyView.swift`): a trail that reveals over a **21-day rolling window of distinct practice days** (`PracticeJourneySnapshot.make`, `:744`). Already recedes gradually as old days age out. Driven only by session dates — *not* the goal.
  - **System B — 20-node milestone ladder** (`PathNode.swift` / `PathProgressManager.swift`): app-authored nodes (`first_rep`→`composed_pauses`), identical for every user, gated on concrete signals via pure `(progress, isComplete)` criteria, **never relock** once earned, celebrate via `pendingCelebrationNodeID`.
  - **Finding:** the Home "Your journey" card reads **System B** (`PathProgressManager.currentNode`) but tapping it opens **System A** (`PathJourneyView`). They don't share a data source.
- **THREE streak calculations** that can disagree on the same day: `StreakFreezeManager.currentStreak` (the displayed source of truth — 1 auto-freeze/week, **never punishes a miss**, `StreakFreezeManager.swift:34`); `PracticeSession.calculateStreak` (1-day grace, `PracticeSupport.swift:6769`); and the journey artwork's strict no-grace streak (`PathJourneyView.swift:861`).
- **Durable coaching state** lives in `CoachMemory` / `CoachMemoryStore` (`PrimaryFocusMemory.swift`): working hypothesis, **intervention cycle** (active mode, observable target, success criterion, review status, adaptation log), reflection patterns, transfer reviews. Rebuilt by `CoachMemoryEngine` on session finalize.
- **`CoachContextBuilder.userContext(...)`** (`CoachContextBuilder.swift`, ~4400 lines) composes 40+ inputs into the ≤500-token context block every coach surface reads. **This is the contract for getting new state in front of the coach.**
- **~12 celebration surfaces** already exist, all firing only on **upward crossings** via a `pending…` flag + consume pattern.

---

## 3. Root causes (not symptoms)

- **"Feels like IM"** is not a missing face — it's three things: (1) the existing face *collapses away* the moment you engage; (2) replies *arrive* fully-formed instead of being *written*; (3) the message stream has no coaching chrome (no sense the coach is reacting to *you* in the moment).
- **"No sense of a journey / one step at a time"** is because the user's actual goal is a single number (`distanceFromGoal`), never decomposed. The two things that *look* like steps (the 20 path nodes, the weekly challenge) are **generic and not derived from the user's goal**, so they don't read as "my path to my goal."
- **"Reset on miss" instinct** comes from wanting absence to *matter*. But a hard reset is loss-aversion punishment, which the product explicitly forbids.

---

## 4. Pillar A — Living Coach Presence

**Goal:** the coach is *present and reacting* throughout the conversation, and replies *land like someone speaking to you*, without violating the brand rule or turning into noise.

**Design (reuse `NoumCharacter`, do not invent an avatar):**

1. **Persistent presence rail.** Keep a single small `NoumCharacter` (≈36pt) docked at the top-left of the thread that **stays visible** while scrolling (pinned, not collapsing-to-gone). It changes mood with conversational state: `.thinking` while composing, `.noticing` for a beat when it quotes the user's own data back, `.coaching` at rest, `.excited` on a celebrated step. This is the "face" — already brand-legal.
   - *Why not per-bubble avatars:* that was tried and removed as noise (`AskNoumView.swift:1467`). A single persistent reacting presence is the right middle ground.
2. **Stream the reply (typewriter / progressive reveal).** Replace the wholesale text swap in `completeCoachTurn` with progressive text. Two options (decide in §10): (a) true token streaming if `AICoachChatService` providers support it, or (b) a **client-side reveal** of the already-returned text at a natural reading cadence (cheaper, provider-agnostic, fully reduce-motion gated → instant). The orb holds `.thinking` during reveal, settles to `.coaching` when done.
3. **Light conversational chrome (restrained).** A coach "is typing… / is reading your last rep…" status line tied to what the context actually contains; optional relative timestamp on tap (not always-on). No read receipts, no reactions — those are IM tropes, not coaching.
4. **In-thread interactivity that belongs to coaching, not chat.** Promote the existing verdict chips and add a compact **"current step" card** (from Pillar B) inline so the conversation can advance the plan, not just talk about it.
5. **Voice-first stays.** The existing 72pt talk button and TTS path are good; presence + streaming make spoken replies feel embodied.

**Patterns reused:** `NoumCharacter` moods/`moodPulse`/`audioLevel`; the existing chip/`FlowLayout` system; `AskNoumStore`'s `isPending`/`completeCoachTurn` mutation point; reduce-motion gating already in `NoumCharacter`.

**Files touched:** `AskNoumView.swift` (presence rail, chrome, reveal wiring), `AskNoumStore.swift` (progressive-reveal API on the pending message), possibly `AICoachChatService.swift` (if true streaming). No new state owner.

---

## 5. Pillar B — One Step at a Time (Goal Journey)

**Goal:** decompose the user's real goal into an ordered sequence of small, concrete, achievable steps, ground each step in a signal the app already computes, and surface "your next one step" everywhere — so the whole app says *change is hard; here's the next small move.*

**The unifying model (reuse the PathNode machinery; do NOT build a parallel system):**

- `GoalStep` — mirrors `PathNode`: `id`, title, coach-voice rationale, an **observable target** + **success criterion** (the Intervention contract), a pure `criterion(_ input:) -> (progress: Double, isComplete: Bool)`, and a CTA destination.
- `GoalJourneyEngine` — a **pure function** (sibling of `CoachMemoryEngine` / `BaselineEngine`) that produces an ordered `[GoalStep]` from `(CoachingProfile.primaryGoal, CommunicationBaseline, CoachMemory.interventionCycle, recent sessions)`. The steps are *derived from the user's goal*, e.g. for `.reduceFillers`: "Finish a rep" → "Hold under 3 fillers/min in a rep" → "Three reps in a row under 2/min" → "A filler-free Timed rep under pressure" → tone-drill-style real-conversation transfer. Difficulty and thresholds read off `distanceFromGoal` so they're calibrated to *this* user, not hardcoded.
- `GoalJourneyStore` — thin account-scoped persistence of completed step IDs, **mirroring `PathProgressManager`'s `unlockedNodeIDs` + no-relock invariant + `pendingCelebration` pattern exactly**. Celebrations fire only on completion (upward only).
- **Grounding, not a second brain:** the steps render the case the coach *already* maintains (`CoachMemory.interventionCycle` is effectively the current step's rationale). New state is minimal (just which steps are done); the intelligence is reused.

**Surfacing "one step at a time" app-wide (single source → many surfaces):**

- **Home:** the "Your journey" card shows *"Step 3 of 8 — <next step>"* with progress + one-tap CTA. This also **resolves the System A/B split** (see §6).
- **Coach chat:** a new `GOAL JOURNEY` section in `CoachContextBuilder.userContext` (next step + why + evidence threshold) so the coach speaks to the plan; inline "current step" card.
- **Post-rep:** `LookingAheadCard` / debrief names *"that moved you toward Step N"* or *"Step N complete — next: …"*. Reuses the existing crossing-detection pattern (cf. the tone-drill SOLVED ribbon).
- **The landscape (System A):** re-anchor its goal flag to the **current GoalStep**, so the cosmetic trail and the real goal become one progression instead of two.

**Miss handling — the honest version (see push-back §3 below):** steps **never relock** (no-relock invariant). The streak already degrades gracefully via `StreakFreezeManager` (never punishing). The landscape already *softly recedes* over its rolling window — keep that as a gentle "the trail's grown over a little while you were away," framed as **invitation, not penalty**. On return, the coach re-anchors on the next *single* step ("welcome back — just one rep today"). This is the "one step at a time because change is hard" intelligence the request is really asking for.

**Patterns reused:** `PathNode` / `PathNodeCriterion` / `PathProgressManager` (criteria + persistence + celebration), `CoachingPriority` + `distanceFromGoal`, `CoachMemory.interventionCycle`, `CoachContextBuilder.userContext`, the pending-flag celebration pattern, `PathProgressManager.evaluateAfterSession` finalize hook.

**Files touched (new):** `GoalStep.swift`, `GoalJourneyEngine.swift`, `GoalJourneyStore.swift`. **(edit):** `CoachContextBuilder.swift` (+`GOAL JOURNEY` section), `ContentView.swift` (journey card), `PathJourneyView.swift` (goal flag re-anchor), `SummaryCards.swift`/`SummaryView.swift` (post-rep step copy), finalize wiring. **Tests:** new `GoalJourney*Tests` suites (pure engine + criteria + store no-relock), matching the repo's heavy unit-test culture.

---

## 6. The coherence layer (why A and B reinforce each other)

- The chat's **inline "current step" card** is the same `GoalStep` the Home card shows and the coach context names — one source, three surfaces.
- Re-anchoring the **landscape goal flag** to the current `GoalStep` collapses the System A/B confusion into one story: *the trail is my journey to my goal; the next node is my next step.*
- The coach's **intervention cycle** (already durable) becomes *visible* as the step rationale — closing the VISION roadmap #1 ask ("surface it coherently in Ask Noum, post-rep feedback, and the next-practice recommendation").

---

## 7. Push-backs (CLAUDE.md: pushback is expected)

1. **"Reset the path if they miss a day."** ❌ Recommend against. It's loss-aversion punishment that violates `never_punish_shame`, the StreakFreezeManager design, the path no-relock invariant, and the VISION anti-goal against hearts-and-lives gating. **Stronger alternative (above):** never burn progress; let the landscape *gently* recede as a non-punishing signal of absence; re-anchor on the next single step on return. A real coach never makes you start over for missing a day — they get you back on the next rep.
2. **"Need a face… /canvas-design or Figma."** ❌ Don't illustrate a face (brand rule). ✅ The face is `NoumCharacter` — make it a *persistent, reacting presence* in the thread (Pillar A). canvas-design produces static PNG art (wrong tool for an animated in-app SwiftUI presence); illustration would break the brand. **Optional:** I can mock the redesigned chat layout in **Figma** for you to react to *before* I build it, if a visual target helps the cross-check.

---

## 8. Phased roadmap (each phase = its own verification gate)

> Verification is real, not hand-traced: this machine has Xcode 26.3 (memory `toolchain_and_verification`). Every phase ends with `xcodebuild test` green + a simulator glance.

- **Phase 0 — Coherence prerequisite (small, de-risks everything).** Consolidate the 3 streak calcs onto `StreakFreezeManager.currentStreak`; decide + document the System A/B relationship. No new feature surface. *Gate: full suite green, streak identical across Home + journey screen.*
- **Phase 1 — Goal Journey engine (pure logic, no UI).** `GoalStep` + `GoalJourneyEngine` + `GoalJourneyStore` + criteria, fully unit-tested. *Gate: new suites green; no UI risk.*
- **Phase 2 — Surface the journey.** Home card → next step; `CoachContextBuilder` `GOAL JOURNEY` section; post-rep step copy; landscape goal-flag re-anchor; step-complete celebration. *Gate: suite green + simulator walkthrough of a fresh + mid-journey user.*
- **Phase 3 — Living Coach Presence.** Persistent presence rail + reply reveal + restrained chrome + inline step card. *Gate: suite green + simulator + reduce-motion verification.*
- **Phase 4 — Polish & QA.** Accessibility labels, reduced-motion, empty/error states, regression sweep of M14 surfaces, device QA notes. *Gate: CLAUDE.md Definition-of-Done checklist.*

---

## 9. Risks & regressions

- **Architectural smell to fix, not extend:** two path systems + three streak calcs. Phase 0 must consolidate or we layer a hack (violates CLAUDE.md). **Risk if skipped:** contradictory progress numbers across surfaces.
- **Overclaiming:** a goal-step plan must self-suppress below evidence floors (reuse `distanceFromGoal`'s "insufficient → nil" honesty, and `CoachParityReadiness` ceilings). No fabricated steps on a cold-start user.
- **Streaming cost/latency:** true token streaming touches the provider layer and rate-limiter (`AIRateLimiter`). Client-side reveal avoids this — likely the right v1.
- **M14 launch-readiness:** this is post-M14 net-new surface; must not destabilize the four high-risk M14 surfaces. Keep additive, default-off where possible.
- **Motion/accessibility:** presence rail + reveal must be fully reduce-motion gated (the `NoumCharacter` pattern already is).

---

## 10. Open decisions for cross-check (red-team these)

1. **Reply animation:** true token streaming (provider work + cost) vs. client-side progressive reveal (provider-agnostic). *Recommendation: client-side reveal v1.*
2. **Step authoring:** fully engine-derived per goal vs. a curated per-goal template the engine selects/calibrates from. *Recommendation: curated templates the engine calibrates via `distanceFromGoal` — avoids fabricated/incoherent steps.*
3. **Path consolidation:** unify System A + B into one model, or keep both but make the landscape goal-flag read the GoalJourney. *Recommendation: keep both surfaces, single shared data source.*
4. **Miss signal strength:** silent recede vs. a gentle coach line on return vs. nothing. *Recommendation: gentle recede + a warm "pick up here" coach line; never a counter reset.*
5. **Presence rail vs. restoring per-turn avatars:** confirm the single-persistent-presence direction (vs. the previously-removed per-bubble glyph).
6. **Scope of "everywhere":** which surfaces get the "next step" in v1 (Home + chat + post-rep proposed) vs. also practice-mode picker, notifications, lessons.

---

## 11. Definition of done (per CLAUDE.md)

End-to-end works; state persists (account-scoped, no-relock); edge/empty/cold-start states handled; navigation verified; accessibility labels + reduced-motion verified; M14 surfaces regression-checked; no duplicated state ownership; visual consistency held; **real behavior verified on simulator, not assumed**; critical logic unit-tested.
