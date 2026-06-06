# Noum Overhaul Roadmap

_Head-of-product synthesis of the surface audit, market research, three strategist debates, and the skeptic's challenges — reconciled against docs/VISION.md and verified against the codebase. Every load-bearing claim and every honesty correction below was checked in code, not assumed._

---

## 1. Diagnosis

Noum feels low-value and text-heavy **not because the coaching is shallow but because deep, honest coaching logic is buried under a presentation layer that makes the user do the interpretation a coach is supposed to do.** The intelligence is verifiably real — a ~700-line `RecommendationBiasEngine` behind the home Coach Card, a `VerdictEngine`, semantic-vs-filler detection, a bounded `CoachCaseFile`, Profile cards that self-suppress on thin data, and a `ProofMomentService` that verifies a quote exists in the transcript before showing it.

But every core surface answers many questions at once instead of one:

- The **post-rep summary** renders the SAME coach read three times (HeroScoreCard stats → CoachReadCard paragraph → WhatYouDidWell + WhatToImprove bullets) and hides the one fix and its evidence behind a chevron.
- The **populated home** stacks up to seven cards where three wear identical hero chrome and two are competing coach doors.
- **Onboarding** promises "coaching tailored to you," then drops the user on a cold home having never been asked a question or spoken a word — the actual questionnaire is orphaned in Settings behind a **12-second fake loading bar for three local writes**.
- The **coach's reply** — assembling ~20 grounded inputs — collapses into one prose `String` that reads like ChatGPT.
- **Profile** is a 22-surface dashboard that tells the rating story five times.

The owner's "too much text, useless info, no value" is, precisely, a **hierarchy-and-evidence problem** — and it is the exact failure mode every competitor (Orai, Speeko, Vocal Image: "graphs I can't read," "you have to coach yourself") gets 1–3 star reviews for. **The fix is overwhelmingly subtraction, re-ordering, and pointing existing-but-hidden machinery at the user — not new features.**

---

## 2. Root causes

- **Architectural — flattened coach output.** `CoachReplyPipeline` assembles ~20 grounded inputs, then collapses all of it into one unstructured prose `String` (`CoachMessage.text`, AskNoumStore.swift:44; `ChatOutcome=.reply(String)`, AICoachChatService.swift:62; system prompt "No headers. No bullet lists," CoachContextBuilder.swift:57). The depth is computed and then made invisible. **This is prose-by-deliberate-design — re-shaping it is an ENGINE change with a new fabrication surface, not a cheap re-render.**
- **Architectural — five progression ledgers, no spine.** `RatingEngine` (rating), `LessonStore` (0–5 crowns), `ProfileManager.addXP` (drill/challenge XP — verified credited at DailyChallengesManager.swift:164), `SpeechProject`, `PathProgressManager` (nodes), and `ProofMomentArchive` (library) each track "progress" on a different currency. The user can never answer "am I getting better at speaking?" in one place.
- **Design — no hierarchy / repeated register.** Same read 3× in the summary, ~5× in Profile; three home cards share the hero chrome. Cluster headers were added to Profile *instead of* cutting.
- **Design — evidence inverted.** The differentiated, un-fakeable content (cited quote, filler chips, the one located fix) is hidden behind tap-to-reveal while restated headlines sit above the fold. Proof is the product, and it's buried.
- **Product — value asserted before it is felt.** First-run is Splash(1s) → 3 marketing slides → cold Home with an anonymous session started silently (ContentView.swift:570). The user is told "real-time coaching" and gets nothing.
- **Product — dopamine decoupled from truth, AND anti-goal drift already shipping.** The motion budget goes to ambient decoration (forever-pulsing nav icons with no reduce-motion guard); meanwhile a real **loss-aversion streak-warning track is LIVE** ("X days in a row at risk," "Don't lose X days at the buzzer," NotificationCopy.swift:91-111) contradicting VISION's never-punish-shame rule and the file's own header comment. _The per-screen audit missed this._
- **Product — transfer (the north-star) is barely surfaced.** `BigMomentStore`/`PrepSessionPlanner` exist and a pending-outcome card shows on Home, but there is no felt prepare → event → reflect loop. CURRENT_STATE.md names this an honest gap.
- **Engineering debt — dead/orphaned duplicate logic.** `AchievementsPage.swift` (387 LoC, still at repo root, nothing navigates to it — **NOT deleted**); `SocialProfileView.swift` (1,495 LoC, `.socialProfile` → `ProfileView()` at ContentView.swift:365); simulated speak-off scoring `Int.random(in: 45...92)` at ChallengesManager.swift:456; three disagreeing pace thresholds.

---

## 3. Design principles (govern the whole overhaul)

1. **One surface, one question, one next move.** Everything else behind progressive disclosure.
2. **Subtract, don't add — but never subtract honesty.** Verbosity that IS an honesty contract (self-suppressing thin-data cards, "early read" disclaimers, the RULE-BASED provenance signal, the validation cap) is load-bearing. Cut the visual weight, keep the truth.
3. **Value felt, not claimed.** Demonstrate a judgment the user couldn't produce alone, in seconds. Proof above the fold; restatements cut.
4. **Believable progress is the only thing we celebrate.** Dopamine welds to a true, measured, rare crossing (`RewardEngine` `.major`). Never completion, never a thin sample, never implied parity. Copy stays evidence-bound.
5. **Restrained, asymmetric, accessible motion.** Improvement gets the full beat (visual + haptic + chime); regression gets a calm, neutral, no-sound treatment. Every celebration defines a reduced-motion fallback (keep haptic + sound, swap particles for a static fade).
6. **The coach has one presence and one memory.** Collapse competing coach doors; perform "it remembers me," don't tabulate it.
7. **Never gate practice; earn the paywall on depth.** A rep is always free. Premium = deeper analysis + the always-on coach chat, surfaced AFTER a felt win — never a hollow "unlock" wrapped into the celebration system, never a wall before first value.

---

## 4. Cross-cutting rules (apply to every iteration)

- **Paywall / premium (corrected per honesty review).** Verified: practice modes are NOT premium-gated; premium gates summary depth (`if !premium.isPremium`, SummaryView) and the coach chat (`lock.fill`, TalkToNoumCTACard). **Preserve this line.** Onboarding shows NO paywall; Home never blocks Begin; the post-rep premium prompt appears only after the free coach read, framed as "go deeper," never as an earned-moment unlock.
- **Honesty test contracts (must be tested, including the FAIL path).** (a) Any surfaced transcript quote routes through `ProofMomentService`'s verify-in-transcript guard and falls back to a stat/template when it fails — **test the fail path.** (b) Thin-data Profile/summary surfaces self-suppress (fewer cards), never render empty shells or fabricated numbers. (c) The RULE-BASED provenance and "early read" disclaimers survive as truth even as visual weight is cut.
- **No overclaim.** One rep is "your first read," never a baseline or a parity signal; no celebration on the first/onboarding rep; celebration copy stays evidence-bound ("filler rate dropped 30% over 3 sessions"), never "you're a great speaker."

---

## 5. Sequenced iterations (front-loaded by value-per-effort)

### Iteration 1 — One-screen verdict + honesty-safe celebration  ·  effort: HIGH
**Most directly kills "too much text / no value felt" at the highest-traffic moment.**

**Goal:** Deliver a coach's read in 5 seconds — one score, one spoken read, one proven win, one located fix — and make the ONLY celebration fire on a real crossing.

**Changes:**
- Collapse SummaryView's 7–9 cards to: animated score ring (count-up + one haptic on settle) + ONE coach-voice card = 2-sentence read + one WIN with its cited quote inline + one FIX with its concrete next move inline, **expanded by default (zero taps).**
- Delete the standalone CoachReadCard paragraph; reduce WhatYouDidWell/WhatToImprove to the single surviving win/fix (same `CoachNote` is rendered 3×).
- Everything else → one "Details" drawer (incl. per-dimension notes, analytics, the RULE-BASED tag as truth-not-weight, reflection capture).
- Wire existing celebration components (`PersonalBestHeroCard`/`CelebrationViews`/`ConfettiLayer`/`CoachHaptic`) STRICTLY off `RewardEngine` `.major` events (already gated via `if event.tier == .major`). Make the verified `ProofMoment` quote the hero. Define the reduced-motion fallback now.
- **Honesty test:** if the proof quote fails the transcript-match guard → deterministic template. Test the fail path.
- Relocate `SessionReflectionInlineCard` out of the comprehension flow.

**Surfaces:** SummaryView.swift, SummaryCards.swift, CoachReadCard.swift, WhatYouDidWellCard.swift, WhatToImproveCard.swift, SessionReflectionInlineCard.swift, RewardEngine.swift, ProofMomentService.swift, CelebrationViews/PersonalBestHeroCard/ConfettiLayer, CoachHaptic.swift.

**Success:** Score + one read + one proven win (with quote) + one located fix (with move) all above the fold, zero taps. Coach read rendered once. Celebration fires only on a `.major` crossing and always shows a verified quote (or tested template fallback). Reduced-motion verified via xcresult. Existing routers unregressed.

**Risk:** 3,194 LoC on the critical path; could regress the Looking-Ahead/Practice-Again routers and the IM SOLVED ribbon; inline quote risks a hallucination if the guard is bypassed. **Mitigation:** route every quote through the guard + unit-test the fail path; leave the tested routers untouched; feature-flag and verify via real build + xcresult before Iteration 2.

---

### Iteration 2 — Quick honesty + accessibility + dead-code sweep  ·  effort: LOW
**Cheap, high-correctness; de-risks the test net before the big rewires.**

**Goal:** Remove shipped anti-goal drift, fix an outright a11y violation, delete dead/duplicate code.

**Changes:**
- Gate the four nav icons' `.symbolEffect(.pulse, options: .repeating.speed(0.6))` on `accessibilityReduceMotion` and remove the forever-pulse (ContentView.swift ~1589 — verified ungated).
- Cut the loss-aversion streak-warning track (NotificationCopy.swift:91-111). Keep at most a no-countdown value nudge.
- Delete `AchievementsPage.swift` (387 LoC, repo root, never navigated) and `SocialProfileView.swift` (1,495 LoC, `.socialProfile` → `ProfileView()`).
- Cut the decorative `+80/+120/+140 XP` `rewardLabel` (PathJourneyView.swift:570-624). **CORRECTION: leave DailyChallenge XP alone — verified credited at DailyChallengesManager.swift:164.**
- Remove simulated speak-off scoring `Int.random(in: 45...92)` (ChallengesManager.swift:456). **NOTE: the "simulated" disclaimer lives in dead `SocialProfileView.swift`, so it is NOT a shipping leak — but the random scoring IS reachable; cut it.**

**Surfaces:** ContentView.swift, NotificationCopy.swift, NotificationManager.swift, AchievementsPage.swift (delete), SocialProfileView.swift (delete), PathJourneyView.swift, ChallengesManager.swift.

**Success:** Nav icons static / state-driven and respect Reduce Motion. No loss-aversion/countdown copy. Both dead files gone; compiles green. No "+XP" on the path card; DailyChallenge XP still credits. No rep scored against a random number.

**Risk:** Low. Keep the notification schedule slot (swap copy) or remove cleanly and run the notification tests.

---

### Iteration 3 — First 60 seconds: ASK then PROVE  ·  effort: MEDIUM
**Goal:** Three one-tap questions then one short rep with one honest read — from screens that already exist.

**Changes:**
- Route the EXISTING `CoachingOnboardingView` option lists (context / challenge / voice) into the production launch path as the spine of first run, replacing the 3-slide hero.
- Immediately guide one ~20–30s rep, then show ONE honest read (fillers, wpm) framed as **"your first read."**
- **Honesty test:** the first rep fires NO celebration, shows NO parity-implying verdict, carries "early read" framing.
- Delete the 12s+2s fake-loading sequence (`processingDuration=12.0`). Cut the forced 1s Splash spinner (NoumApp.swift ~89). Replace the streak-flame closing slide with an outcome-led one. Migrate ~30 hardcoded `Color(red:)` literals to tokens.
- **Paywall:** none in onboarding or before the first rep.

**Surfaces:** NoumApp.swift, ContentView.swift (first-run orchestration), CoachingOnboardingView.swift, OnboardingHeroView.swift, first-rep practice path.

**Success:** New user is asked 3 questions and completes one short rep with an honest "first read" within ~60s, before Home. No fake loading, no forced spinner, no celebration/verdict on rep 1, no paywall. Time-to-first-spoken-word drops from "never" to under a minute.

**Risk:** Rewiring the launch path is fragile (double-start, test-only flag). **Mitigation:** reuse the existing session-start path; keep the test flag working; verify cold-start AND returning-user branches on device; do NOT ship with the Profile rewire.

---

### Iteration 4 — Home: one coach, one hero, one next move  ·  effort: MEDIUM
**Goal:** Home reads as a coach who looked at your last rep and named the one thing to do next.

**Changes:**
- Make `HomeCoachCard` the ONLY hero; strip the radial-wash + capsule-CTA chrome off journeyPreviewCard, askNoumPromoCard, VoiceMetricsCard (ContentView.swift:240-296).
- Fold Ask-Noum access INTO the Coach Card (one coach door, not "Begin" ~1864 vs "Open the thread" ~1223).
- Gate the utility strip + Ask-Noum promo behind ≥1 completed rep; removes the cold-start overclaim "I read your last 30 days" (ContentView.swift:1272) and "No streak yet."
- Reduce the populated home to one hero + one quiet status line + at most one quiet secondary read, each gated on real signal.
- **Resolve the fake tab bar:** real `TabView` with a `selectedTab` + active indicator, OR stop styling the four push-buttons as a tab bar.
- **Paywall:** Home never blocks Begin; an Ask lock may appear only after a rep exists.

**Surfaces:** ContentView.swift, HomeCoachCard.swift, HomeUtilityStrip.swift, AIWeeklyInsightCard/VoiceMetricsCard, HomeSignalGate.swift.

**Success:** Zero-rep user sees exactly Coach Card + Begin (no empty/contradictory status, no "30 days"). Returning user sees one hero + one status line. One coach door. Clear nav selection state. Verified on device for both states.

**Risk:** 2,293 LoC; nav decision is app-wide. **Mitigation:** card-hierarchy + gating first (contained); tab-bar decision as a separate change; extend HomeSignalGate, don't replace it.

---

### Iteration 5 — One coach, one prescription + the curriculum spine  ·  effort: HIGH
**Goal:** Stop making the user be their own coach; consolidate five ledgers onto one spine.

**Changes:**
- Lead `PracticeModeSelectionView` with the ONE recommended rep as hero + single Begin, configured by the existing engine (`computeRecommendation`). Demote other tiles + the 6-toggle panel behind "Other ways to practice" / "Advanced." Move Lessons + Speech Projects out of the rep picker.
- **Keep a visible one-tap "Not this — pick another" escape** next to the hero (mitigates recommendation single-point-of-failure).
- Kill the blocking "Today's focus?" modal for new users; suppress until ≥1–2 reps, then optional inline chip.
- **Consolidate the progression spine.** Name the **speaking rating** (`RatingEngine`) the ONE believable number. Dispositions: **crowns** and **drill/challenge XP** become INPUTS that ladder into the rating/skill story (keep the credit, change where it's surfaced); **SpeechProjects** stays a distinct long-form track, not a competing currency; the **Growth Library (`ProofMomentArchive`)** is promoted into the believable-progress payoff. Reconcile the 3 pace thresholds (110-140 / 110-150 / 100-160) into ONE constant.
- Collapse the 51 `DrillVariations` to the handful with distinct playable experiences + a small per-skill rotation pool; cut the ~45 that render only as the generic 45s card. Drills stay coach-prescribed but FELT (name the skill + why, one line).

**Surfaces:** PracticeModeSelectionView.swift, TimedPracticeView/SuddenDeathPracticeView, SessionIntentPromptView.swift, DrillSystem.swift, RatingEngine/ProfileManager, LessonStore/SpeechProject/ProofMomentArchive, PaceTrainingView/BeatTheBrakeView.

**Success:** Practice surface shows one recommended rep + Begin + a "pick another" escape; no intent modal for new users. ONE progression number on Home/Profile; crowns/XP feed it. One pace constant. Recommendation acceptance rate measured before the menu is fully hidden.

**Risk:** Bets the practice loop on recommendation quality; consolidating ledgers risks deleting a wired signal (DailyChallenge XP is real). **Mitigation:** keep the escape; validate acceptance rate first; feed crowns/XP into the spine (don't delete credit); regression-test path/lesson unlock conditions.

---

### Iteration 6 — Coach reply gets a shape (the ChatGPT-vs-coach fix)  ·  effort: HIGH
**Scoped honestly as an ENGINE change, per the verified premise check.**

**Goal:** Every substantive coach turn reads as READ → EVIDENCE → MOVE in 2 seconds — without a new fabrication surface.

**Changes:**
- Introduce a light 3-part structured reply fed by the ~20 inputs already assembled. **Scope correction: the reply is prose-by-design (`ChatOutcome=.reply(String)`, "always-text no JSON," "No headers. No bullet lists") — this is an engine change, HIGH-effort and trust-risky, NOT a re-render.**
- **Honesty test:** the structured "evidence" field can hallucinate a quote. Route every quote through the verify-in-transcript guard; fall back to a stat/template on failure; **test the fail path.** If the guard can't be guaranteed on the chat path, KEEP the reply prose and structure only the (already card-structured, lower-risk) post-rep summary.
- **Do not force structure on every turn:** greetings/preference turns stay 1–2 sentences — a rigid template on short turns reads robotic.
- On the live call landing (`LiveCoachCallView`), cut the 4-field "COACHING READ" meta-brief (esp. the cold-start "I have nothing" version); lead with one focus line or "Tap Talk." Enforce ONE continuation surface per turn (drill > one pending decision > one chip).
- Lead the empty/landing state with one data-grounded line ("Last rep: 142 wpm, 3 fillers in the open — want to tighten that?").
- **Paywall:** the coach chat/call is the primary premium surface, but shows a value-first remembered-read preview before the lock; a free user always gets the post-rep coach read.

**Surfaces:** AskNoumStore.swift, AskNoumView.swift, LiveCoachCallView.swift, CoachReplyPipeline/CoachContextBuilder/AICoachChatService, ProofMomentService.swift.

**Success:** Substantive replies read as read→evidence→move; short turns stay conversational. Any quoted evidence is verified or falls back (fail path tested). Live call leads with one line or "Tap Talk"; ≤1 continuation per turn. Free users still receive a real post-rep coach read.

**Risk:** Highest-trust-risk iteration — one fabricated "you said X" collapses all trust. **Mitigation:** gate every quote through the guard with a tested fail path; if not guaranteeable, structure only the summary; never force structure on greetings; flag + adversarial review of the fail path.

---

### Iteration 7 — Believable-progress Profile + the transfer (north-star) loop  ·  effort: HIGH
**Goal:** Profile answers "am I getting better + next move" in one glance; real-world transfer becomes a felt loop.

**Changes:**
- Reduce Profile to ~4 surfaces: identity; ONE believable-progress hero (rating + one honest trend line + one plain one-liner); ONE "your coach: current read + next move + one proof point" (3 lines max); a quiet History/Library entry. Collapse the 5 rating retellings into one. Move Community to its own tab.
- Cut the "How well Noum knows you" `CoachParityReadinessCard` (7 rows of internal instrumentation).
- **Honesty test:** the 22→4 collapse MUST carry forward each card's self-suppress-on-thin-data discipline — a thin-data user sees fewer cards, NOT empty shells or fabricated numbers. **Test the thin-data path** (the honesty review's top risk).
- Redirect motion to EARNED moments: rating ticks up on a new weekly best; a weakness flips to "Resolved" with a fill+settle (reuse Iteration 1's asymmetric system).
- **Build the transfer outcome loop (north-star, currently barely surfaced):** promote `BigMomentStore`/`PrepSessionPlanner` into a coherent prepare → real event → reflect/outcome loop (remembered upcoming moment, `PrepSessionReadiness` read, post-event outcome capture feeding the coach case). Strict no-causation copy ("they felt their prep carried," never "the drill caused"). **This is the one place the plan adds visible surface area — because the north-star metric demands it — but it reuses existing stores.**
- Demote History's top mini-dashboard: lead with the session list; one-line summary; collapse the two review cards into one "Worth a replay."

**Surfaces:** ProfileView.swift, SessionHistoryView.swift, CaseReviewCard/DeliveryProfileCard, CoachParityReadinessCard (cut), PeakRatingWallCard/YourArcCard/ProgressionCharts, BigMomentStore/BigMomentIntakeView/BigMomentOutcomeInlineCard/PrepSessionPlanner/PrepSessionView.

**Success:** Profile answers the question in ≤4 surfaces; rating story appears once; thin-data user sees fewer cards (tested). Transfer loop reachable and felt with no causal overclaim. Motion fires on earned crossings only.

**Risk:** Largest blast radius (1,795 LoC of honesty-disciplined cards); transfer loop is the only net-new surface. **Mitigation:** treat honesty contracts as load-bearing — port self-suppression forward and test the thin-data path; do the Profile collapse and the transfer loop as separate reviewable changes; do NOT ship with Iteration 3 or 6.

---

## 6. Orphaned-surface dispositions (explicit keep / demote / cut / defer)

| Surface | LoC | Disposition | Reason |
|---|---|---|---|
| `AchievementsPage.swift` | 387 | **CUT (delete)** | Still at repo root, nothing navigates to it — was NOT actually deleted. Third copy of achievement logic. (Iteration 2) |
| `SocialProfileView.swift` | 1,495 | **CUT (delete)** | `.socialProfile` resolves to `ProfileView()` (ContentView.swift:365); never instantiated. Holds the dead "simulated" disclaimer. (Iteration 2) |
| Simulated speak-off scoring | — | **CUT** | `Int.random(in: 45...92)` (ChallengesManager.swift:456) is reachable; a rep scored against a dice roll is a hollow unlock. (Iteration 2) |
| `WordOfTheDay` (`WordOfTheDay.swift` 978 + `WordOfTheDayManager.swift` 151) | 1,129 | **DEMOTE / DEFER** | Reachable (HomeUtilityStrip, ContentView, TimedPracticeView) but VISION classifies it as "secondary backlog… optional user-led tool." Remove from the cold-start home (Iteration 4); keep as an opt-in tool, defer any expansion. |
| Lessons / crowns curriculum (`LessonsCatalog` 239, `LessonsHomeView` 367, `LessonView` 817, `LessonStore` 165, `Lesson` ) | ~1,600+ | **KEEP, fold into the spine** | Content is genuinely good. Crowns become an INPUT to the rating/skill spine, not a separate scoreboard; move Lessons out of the rep picker into "Train a skill." (Iteration 5) |
| `NoumCharacter` (`NoumCharacter.swift` 865 + `NoumCharacterStage.swift` 219) | 1,084 | **KEEP** | Used across 23 files; the brand-rule-compliant waveform identity (no illustration). It is the right vehicle for a living believable-progress artifact. |
| `CutTheCrutch` (`CutTheCrutchView.swift` 708 + `CutTheCrutchEngine.swift` 297) | 1,005 | **KEEP, demote in picker** | Reachable from the picker; a real drill. Demote behind "Other ways to practice"; its pace logic feeds the single reconciled pace constant. (Iteration 5) |
| Watch (`NoumWatch`) | — | **DEFER** | CURRENT_STATE: detached from the iOS scheme until the watchOS 26.2 sim runtime is installed; real-device/runtime gap, not a UX call. |
| Live Activity (`NoumWidget/PracticeLiveActivity*`) | — | **KEEP, defer QA** | Real feature; can't be exercised on simulator. Defer until device QA (it's a named M14 high-risk verify item). |

---

## 7. Quick wins (low effort, high correctness)

- Gate the nav-icon repeating pulse on `accessibilityReduceMotion` and remove the forever-pulse (ContentView.swift ~1589). _(Iter 2)_
- Delete the loss-aversion streak-warning copy (NotificationCopy.swift:91-111) — a SHIPPING punish-shame violation. _(Iter 2)_
- Delete `AchievementsPage.swift` and `SocialProfileView.swift`. _(Iter 2)_
- Delete the 12s+2s fake-loading bar in `CoachingOnboardingView`. _(Iter 3)_
- Cut the decorative `+80/+120/+140 XP` rewardLabel (PathJourneyView.swift:570-624). **Leave DailyChallenge XP — it is really credited.** _(Iter 2)_
- Remove `Int.random(in: 45...92)` speak-off scoring (ChallengesManager.swift:456). _(Iter 2)_
- Cut the forced 1s Splash spinner (NoumApp.swift ~89). _(Iter 3)_
- Delete the standalone CoachReadCard paragraph. _(Iter 1)_

---

## 8. Biggest bets

1. **One-screen post-rep verdict + crossing-gated celebration** — highest value-per-effort; kills "too much text / no value" and delivers honest dopamine at once. _(Iter 1)_
2. **ASK → PROVE first 60 seconds** — converts "talks about coaching" into "just coached me." _(Iter 3)_
3. **Coach reply gets a shape** — fixes the ChatGPT-vs-coach read, scoped honestly as an engine change with a verified-quote fail path. _(Iter 6)_
4. **One progression spine (rating) + lead with the one prescription** — answers "am I getting better?" _(Iter 5 + 7)_
5. **Real-world transfer outcome loop** — the north-star metric, currently barely surfaced. _(Iter 7)_

---

## 9. Cut list (remove or hide)

- Standalone CoachReadCard paragraph (same CoachNote 3× in the summary).
- Tap-to-reveal on the surviving win/fix — show quote + filler chips inline; hide restated headlines instead.
- `SessionReflectionInlineCard` from the mid-results flow → bottom/drawer.
- The 12s+2s fake-loading sequence (`processingDuration=12.0`).
- Forced 1s Splash spinner + streak-flame closing hero slide + duplicate LoginView pitch.
- HomeUtilityStrip Word-of-the-day + Soundscape at session 0; whole strip + Ask-Noum promo for a zero-rep user (incl. the "30 days" overclaim, ContentView.swift:1272).
- The second coach door on Home (fold Ask into the Coach Card).
- Loss-aversion streak-warning track (NotificationCopy.swift:91-111).
- Live numeric Trust/Tension chips in IM Mode's active conversation (IMPracticeView ~431).
- `CoachParityReadinessCard` "How well Noum knows you" (ProfileView ~1011).
- Duplicate Profile progression surfaces: `YourArcCard` + standalone `PeakRatingWallCard`.
- Decorative `+80/+120/+140 XP` rewardLabel (PathJourneyView.swift:570-624) — **keep DailyChallenge XP.**
- Simulated speak-off scoring `Int.random(in: 45...92)` (ChallengesManager.swift:456). _(The "simulated" disclaimer is in dead `SocialProfileView.swift` — not a shipping leak, but the random scoring is reachable.)_
- DEAD CODE: `AchievementsPage.swift` (387 LoC), `SocialProfileView.swift` (1,495 LoC).
- PathJourneyView 270pt grass-meadow hero + ~8 lines of metaphor prose → demote to ambient header or retarget to the real trend curve.
- Settings AI-usage meter + 280-char explainer (SettingsView.swift:950-1009) → in-context lite-mode only; raw counters behind Advanced.
- Two top-of-scroll Settings captions (difficulty :442, daily-goal :488) + legacy "Post-session follow-up" toggle (:712).
- Picker "What this trains" triples + per-mode "Start now" buttons.
- ~45 phantom `DrillVariations` that render only as the generic 45s card.
- One of three pace trainers; reconcile thresholds into ONE constant.
- Live call 4-field "COACHING READ" meta-brief (esp. cold-start) → one focus line or "Tap Talk."
- Stacked AskNoum continuation rows → ONE continuation per turn.

---

## 10. Open debates (owner's call)

1. **Does a streak anchor anything at all, or become a quiet off-rampable status line?** Keep with bounded forgiveness + user cadence (retentive) vs. cut as an anchor entirely (brand purity; VISION names the addiction loop). **Recommendation:** after removing the loss-aversion copy (Iter 2), demote to a quiet no-countdown status line — but whether it anchors retention AT ALL is the owner's call. Decide before softening copy.
2. **Where does the PRIMARY comeback trigger live?** Value-delivering notification vs. in-app coach-memory callback vs. nothing. **Recommendation:** default notifications to neutral-invite framing; assert a delta only when it clears the same conservative threshold the in-app debrief uses. Whether to push asserted-progress at all is the owner's risk call (one wrong "you improved" is worse than ten neutral invites).
3. **Per-rep dopamine when crossings are rare.** Calm in-rep micro-feedback vs. keep the rep near-silent (the product already removed an in-rep HUD for breaking concentration). **Recommendation:** keep the rep silent; put the beat in the score-ring resolve + the honest read; reserve the full celebration for true crossings. Owner decides appetite for any in-rep motion.
4. **How aggressively to collapse the picker.** One prescribed rep vs. a curated short menu. **Recommendation:** ship the one-rep hero WITH a one-tap "pick another" escape; measure recommendation acceptance before hiding the menu further. Final altitude is the owner's call once acceptance data exists.

---

## 11. Metrics to watch (believable, not vanity)

- Time-to-first-spoken-word in onboarding (target <~60s; today: effectively never).
- Time-to-first-honest-read (proxy for "value felt" replacing "value claimed").
- Post-rep comprehension: tap-to-fix count (target 0 — can the user state their ONE fix without a disclosure?).
- Recommendation acceptance rate (Begin-on-recommended vs "pick another") — gates picker collapse.
- Celebration honesty rate: % of celebrations on a verified `.major` crossing AND showing a transcript-verified quote (must be ~100%).
- ProofMoment fallback-path rate: how often the transcript-match guard rejects a model quote and falls to template (watch that the fail path fires; never leaks a raw quote).
- Returning-user retention to a 2nd and 3rd rep (not raw DAU; not a streak count).
- Real-world transfer loop completion: BigMoments with a prepare → outcome/reflection logged (the north-star signal, currently ~0 surfaced).
- Believable-progress crossings per active user over weeks (personal bests, weaknesses flipped to Resolved).
- Reduced-motion correctness: zero ungated repeating animations on core surfaces (audited, not assumed).
- Anti-goal copy audit: zero notification/UI strings with loss-aversion/countdown/"don't lose" framing (hard gate, recurring).

---

_Sequencing rule: ship Iteration 1 (the value moment) and Iteration 2 (cheap honesty/a11y/dead-code) first; they de-risk the rest. Do NOT land the onboarding rewire (3), the coach-reply engine change (6), and the Profile 22→4 collapse (7) in one pass — each is a high-effort change on the most-trafficked ~8,500 LoC with a historically flaky test net. Feature-flag, build, and verify via xcresult between each._

---

## 12. Owner decisions (delegated to Claude, 2026-06-06)

Jordan delegated every open decision and the full build. Calls made (adopting the §10 recommendations):

1. **Streak** — KEEP as a quiet, no-countdown status line; remove every loss-aversion / countdown / "don't lose" string. Not a pressure anchor — a gentle marker only.
2. **Comeback trigger** — neutral-invite notifications by default; assert a delta only when it clears the same conservative threshold the in-app debrief uses; the primary value lever is the in-session coach-memory callback ("last time you worked on X").
3. **Per-rep dopamine** — the rep stays near-silent; the satisfying beat lives in the post-rep score-ring resolve (spring count-up + one haptic on settle); the full multi-sensory celebration is reserved for true `.major` crossings only.
4. **Picker collapse** — ship the one prescribed rep as the hero WITH a visible one-tap "pick another" escape; do not hide the full menu.

**Execution order (de-risking):** Iter 2 → 1 → 3 → 4 → 5 → 6 → 7. Real build + simulator verification (via xcresult + screenshots) between each; feature-flag the high-risk rewires (3, 6, 7).

---

## 13. Visual review findings (rendered corpus) — new items, verified real vs artifact

The 3-fleet review of the real screenshots (full report: docs/UX_RENDERED_REVIEW.md) raised 72 critical/high items. Each was triaged against the actual code/screens before acting (verify-before-acting):

**VERIFIED REAL — fixed in Iteration 2:**
- Cosmetic **location permission prompt** on Path open (`PathDaylightModel.activate()` requested `whenInUse` on `.notDetermined` just to tint a sky gradient). Removed the prompt; uses the fallback coordinate, only refines if already granted.

**VERIFIED REAL — routed to later iterations:**
- **Cold-start fabricates a power-user.** A 0-rep user sees Profile "Your highest rating yet · 400 Peak this week" and League "Silver · 400 RATING · +100 to Gold" with sample standings. Root: new accounts get a seeded ~400 rating and the celebration/league surfaces don't gate on ≥1 real rated session. → **Iteration 4** (Home/cold gating) + **Iteration 7** (Profile believable-progress, thin-data self-suppress). Connects to the existing `league_promotion_guard` need.
- **Third-person coaching voice leaks** ("Their goal…", "The user has drifted off rhythm…") in the picker rationale. → **Iteration 5/6** (coach voice is second person).
- **Coach brief is byte-identical across 5/12/20-session states** + a 7-row brief on cold open. → **Iteration 6**.
- **8-item jargon mode menu for a first-timer** ("Pick your next rep", incl. "Cut the Crutch · 3 hearts, no second chances"). → **Iteration 3** (route Begin → recommended rep) + **Iteration 5** (picker collapse; rename "hearts" in the Cut-the-Crutch engine).
- **Profile metric overload** (25+ competing numbers) + **hardcoded identity/level card** (verify it reads XP). → **Iteration 7**.
- **Settings** flat ~3,600pt scroll + AI-usage prose cards. → roadmap §9 cuts (fold into a late pass).
- **Beginner Review never shows "Mistakes to fix"** (the user who needs it most). → **Iteration 1/7**.

**ARTIFACT / NOT A SHIPPING BUG (no action):**
- "Platinum power-user home behind the onboarding overlay" (O-01…O-05) — my **pre-erase capture** caught stale sim data behind the onboarding; the true cold home is the clean "Welcome / Begin · First rep".
- "Debug: Simulate Days panel ships" — gated by `AuthManager.isDeveloper` (AIConfig.plist allowlist; `false` for real users). Visible only because the seeded session matched a developer ID.
- Several "frozen across states" reads (Path interior, journey card) — partly because the dev **seed does not populate Path/journey progression**, so they default to Day 0 for every seed; verify per-surface in Iter 4/7 before treating as a render bug.