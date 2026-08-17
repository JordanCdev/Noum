# M15 Release Audit

_Read-only audit of every M15-touched file against VISION.md anti-goals + accessibility checklist. Generated 2026-05-21 on `agent-m15-audit` worktree at base `b5f8d56`._

_Re-validated 2026-05-21 by a re-spawned agent (the original SendMessage approach did not resume the prior session). Independent re-audit confirmed every finding below; two additional NICE-TO-HAVE entries were added (proof-line fade-in not reduceMotion-gated; verdict + summary table updated accordingly)._

---

## Methodology

The audit walks two checklists against the **union of files touched by all 5 M15 commits** plus Phase 1's in-tree (uncommitted) edits to `NoumCharacter` / `SpeechRecognizerViewModel`:

**Commits in scope** (all on `Redesign`):
- `121d270` — Phase 1b orb in 5 practice views
- `b5f8d56` — Phase 2 rep-1 quote
- `2ec3c7b` — Phase 5 insights chip
- `1bc99fd` — Phase 4 home discipline
- `1c1a8ae` — Phase 3 mode literacy

**14 files audited:**

| # | File |
|---|---|
| 1 | `Noum/AhCounterView.swift` |
| 2 | `Noum/AskNoumView.swift` |
| 3 | `Noum/ContentView.swift` |
| 4 | `Noum/CutTheCrutchView.swift` |
| 5 | `Noum/FirstRepCelebration.swift` |
| 6 | `Noum/HomeSignalGate.swift` |
| 7 | `Noum/IMPracticeView.swift` |
| 8 | `Noum/NoumCharacter.swift` |
| 9 | `Noum/PracticeModeSelectionView.swift` |
| 10 | `Noum/SettingsView.swift` |
| 11 | `Noum/SpeechRecognizerViewModel.swift` |
| 12 | `Noum/SuddenDeathPracticeView.swift` |
| 13 | `Noum/TimedPracticeView.swift` |
| 14 | `ProfileView.swift` |

### Anti-goals check

For each file, scanned for:
- **Streak shame** — copy like "you lost", "your streak broke", "X days missed", loss-aversion framing
- **Shallow gamification** — popups, hearts-and-lives gating, slot-machine feedback
- **Punishing language** — tone that makes users feel bad for missing or regressing
- **Exclamation marks** in user-facing string literals (VISION + noum-design ban these)
- **Emoji** in user-facing strings (brand rule: "no illustration, no characters")
- **Chirpy filler** — "Awesome!", "Great job!", "Let's go!", "Amazing!", "Fantastic!", "Well done!"
- **Fake progress** — "loading…", placeholder copy, dead toggles, fake states

### Accessibility check

For each file:
- Buttons + interactive elements have a derivable VoiceOver label (explicit `accessibilityLabel` or string-literal `Button("…")` form)
- `Text` uses **Dynamic Type-scaled** fonts (e.g. `Typography.headline`, not `.font(.system(size: 14))` everywhere)
- VoiceOver: orb instances either hidden (`.accessibilityHidden(true)`) or carry their own label so they don't compete with surrounding screen reading
- Reduce-motion: animations gated by `@Environment(\.accessibilityReduceMotion)` — especially `repeatForever` and entrance-springs

### Severity

- **BLOCKER** — ship-stopper for release; either contradicts VISION explicitly or fails a baseline accessibility expectation that VoiceOver users will hit immediately.
- **SHOULD-FIX** — real violation, but either pre-existing (M15 didn't introduce it) or low-frequency (only one corner case). Worth fixing before TestFlight expansion.
- **NICE-TO-HAVE** — borderline pattern, mostly visual polish or strict-reading-of-the-rule. Won't break anything.

---

## Findings — Anti-goals

### Streak shame

**No streak-shame copy found across the 14 M15-touched files.**

Reverse-finding worth noting: `ProfileView.swift:539` includes a deliberate negative-pattern comment — _"Hidden entirely when the archive is empty so we never render '0 insights' or a 'you lost your streak' prompt — VISION.md bans the streak-and-badge loop."_ Phase 5 was explicitly designed around this anti-goal, and the chip correctly hides at zero rather than rendering a hollow state.

### Shallow gamification / hearts-and-lives

| Finding | Severity | Notes |
|---|---|---|
| `Noum/TimedPracticeView.swift:1717` — `celebrationOverlay` renders a burst of `["🎉", "✨", "🔥", "⭐️", "💪", "🏆"]` emoji particles around milestone moments. | **SHOULD-FIX** | Pre-existing (Apr 2026, predates M15). Conflicts with brand rule "no illustration, no characters" and VISION anti-goal "shallow gamification". M15 touched this view (Phase 1b orb) but did not introduce this code. Suggested fix: replace the emoji array with the existing `ConfettiLayer` (SF-Symbol-based, used by `FirstRepCelebration` and `PathNodeCelebration`) for visual-vocabulary consistency, or remove the celebration overlay entirely if the milestone scale animation alone is sufficient. |
| `Noum/CutTheCrutchEngine.swift:96` + `Noum/CutTheCrutchView.swift:331-338` — Hearts mechanic. Three hearts visible during the 60s round, each violation `chips` one (`heart.fill` → `heart.slash`); hearts == 0 calls `finalize(cleanCut: false)` and ends the current round early. Docstring explicitly labels this _"loss-framed hearts"_. | **NICE-TO-HAVE** | Pre-existing pattern, NOT introduced by M15. Hearts are an intra-drill pressure mechanic (a single 60-second round), NOT a meta-game token that gates practice across the app — losing all hearts ends one drill round, not the user's session for the day. Reads as VISION pillar 2 ("pressure modes — reveal breakdowns fairly") rather than the banned "hearts-and-lives gating game". Worth a team-level review of whether the heart visual register is the right pressure signal vs. e.g. composure-bar decay alone; not a release blocker. |
| `Noum/CutTheCrutchView.swift:133` — _"Speak for 60 seconds without using one specific word. 3 hearts. Each use chips one. Survive without dropping all three for a clean cut."_ + `Noum/PracticeModeSelectionView.swift:81` subtitle _"Avoid one specific word for 60 seconds. 3 hearts, no second chances."_ | **NICE-TO-HAVE** | Pre-existing copy. The "3 hearts, no second chances" phrasing reads close to loss-aversion gating; pairs with the heart visuals above. Same team-review note applies. |

### Punishing language

**No punishing copy found across the 14 M15-touched files.** Grep for "you failed", "you're behind", "you have to", "don't miss", "you should have", "too bad" — zero matches.

Phase 2's `FirstRepCelebration.quoteFraming` (FirstRepCelebration.swift:499-549) is the most-recent piece of coach copy added in M15; every branch (six voices × three filler-count buckets) reads as observation, not lecture. The 3+ filler branches use phrases like _"Fillers cluster early when the moment matters. We work the pause next."_ (authoritative), _"First reps surprise everyone. The hesitation is honest, and it's workable."_ (warm) — no shaming, no blame.

### Exclamation marks in user-facing copy

**No exclamation marks found in user-facing string literals across the 14 M15-touched files.** (Grep on `Text("…!"`, `Text(.*!.*)` patterns — clean.) The only `!` characters are Swift force-unwraps (`as!`, `try!`, etc.) and `!=` comparisons.

### Emoji in user-facing copy

| Finding | Severity | Notes |
|---|---|---|
| `Noum/TimedPracticeView.swift:1717` — see above. | **SHOULD-FIX** | (Duplicate of the gamification finding; same line, same fix.) |

No other emoji in user-facing strings across the remaining 13 files.

### Chirpy filler

**No chirpy filler found across the 14 M15-touched files.** Grep for "Awesome", "Great job", "Nice work", "Well done", "Keep it up", "You rock", "Amazing", "Fantastic", "Super", "Let's go", "Woohoo", "Huzzah" — zero matches.

### Fake progress / placeholders

**No fake-loading or placeholder copy found across the 14 M15-touched files.** Grep for "loading...", "placeholder", "coming soon", "TBD", "TODO" in string literals — zero matches.

One legitimate `"Listening…"` (CutTheCrutchView.swift:373, AhCounterView elsewhere) is real transcript state, not a fake-loading placeholder.

---

## Findings — Accessibility

### Accessibility labels on interactive elements

| Finding | Severity | Notes |
|---|---|---|
| `Noum/FirstRepCelebration.swift:182` — hero `NoumCharacter(mood: .excited, tint: .white, size: 160)` is **not** wrapped in `.accessibilityHidden(true)` on the celebration screen. | **SHOULD-FIX** | The five practice views (Timed, SuddenDeath, AhCounter, IM, CutTheCrutch) all correctly hide their orbs from VoiceOver since the surrounding header owns the screen-reading. On `FirstRepCelebration` the orb sits between the headline ("First rep, in the bag.") and the observation slot ("firstRep.celebration.observation"); VoiceOver users will hear the `NoumCharacter`'s internal mood-label ("Noum coach, just noticed something") sandwiched between them, which competes with the screen's two-element narrative. Suggested fix: add `.accessibilityHidden(true)` to the `base` view in `FirstRepCelebration.swift:182` (the rest of the screen — headline + observation + buttons — already carries the meaning). |
| All other interactive elements across the 14 files carry either an explicit `accessibilityLabel`, an `accessibilityIdentifier`, or use the `Button("StringLiteral") { … }` form which auto-derives the VoiceOver label. | clean | Spot-checked TimedPracticeView buttons ("End", "Begin Session", "Start Now"), IMPracticeView buttons ("Back", "Start conversation", "End Chat"), AhCounterView buttons ("Stop", "Start", "Keep Practicing", "Discard") — all derivable. |

### Dynamic Type / scaled fonts

| Finding | Severity | Notes |
|---|---|---|
| Fixed-size `.font(.system(size: N))` usage across M15-touched files: 16 in TimedPracticeView, 12 in ContentView, 5 in CutTheCrutch, 4 in SuddenDeath, 3 in IM, 3 in NoumCharacter, 2 in Profile, 2 in AskNoum, 2 in AhCounter, 1 in Settings. | **SHOULD-FIX** (pre-existing) | Most are intentional hero numerals (`size: 110, weight: .black` for the Sudden Death countdown digit at SuddenDeathPracticeView.swift:388-394; `size: 76` for AhCounter's filler tally at AhCounterView.swift:556; `size: 96` for CutTheCrutch tally at CutTheCrutchView.swift:272; `size: 48` for the Timed timer at TimedPracticeView.swift:343). These read as display digits and Dynamic Type would break the visual rhythm. Body text uses scaled tokens (`Typography.headline`, `Typography.caption`, `.subheadline`, etc.) correctly. NoumCharacter's `.font(.system(size: size * 0.42))` is intentional — the symbol scales relative to the orb's owning `size` parameter so layouts stay coherent at any container size. **However**, secondary text at TimedPracticeView.swift:864 (`size: 13`), SuddenDeath.swift:487 (`size: 14`), and ProfileView.swift:931, 941 (`size: 7`, `size: 8.5`) is non-display body copy that would benefit from scaled fonts; XS sizes (≤10) are accessibility-hostile to anyone with low vision. Pre-existing — M15 did not introduce these. |

### Reduce-motion gating

| Finding | Severity | Notes |
|---|---|---|
| `Noum/CardEntrance.swift:14-30` — `CardEntranceModifier` runs an unconditional `.spring(response: 0.34, dampingFraction: 0.84)` scale-up + opacity fade on every card via `.cardEntrance(index)`. **Does not check `@Environment(\.accessibilityReduceMotion)`.** Applied to all 7 home cards in `ContentView.swift:236-279` plus other surfaces app-wide. | **SHOULD-FIX** (pre-existing) | The home screen is the most-revisited surface in the app. Reduce-motion users get a staggered spring entrance every time they open Home — exactly the vestibular pattern Apple's HIG flags. Fix is a one-line check in `CardEntrance.swift:24-26`: skip the `withAnimation` when reduceMotion is set; or use `transaction.animation = nil`. Pre-existing pattern, not M15-introduced — but Phase 4 (`1bc99fd`) re-applied `.cardEntrance(n)` to every gated card so the failure surface is the same. |
| `Noum/FirstRepCelebration.swift` proof arrival | **RESOLVED (2026-08-17)** | Proof arrival now uses `withAnimation(reduceMotion ? nil : …)`. The retired mascot/notice identity pulse was removed; the milestone emblem stays stable while the evidence slot appears, so proof—not decorative motion—owns the change. |
| `Noum/AhCounterView.swift:225` — `.animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: speechVM.isRecording)` on the listening indicator. | **SHOULD-FIX** (pre-existing) | Continuous opacity pulse on the recording indicator. `repeatForever` is the canonical vestibular concern. Wrap the animation choice in a reduceMotion check. Pre-existing — M15 only added the orb to this view, not this animation. |
| `Noum/TimedPracticeView.swift:286, 1124, 1305, 1458` — multiple `.repeatForever(autoreverses: true)` animations on spotlight pulse, breathe phase, recording pulse, and inline rec-pulse. | **SHOULD-FIX** (pre-existing) | Same vestibular-concern pattern as AhCounter. None are gated by `reduceMotion`. Pre-existing — M15 added the orb but did not introduce these. |
| `Noum/AhCounterView.swift`, `Noum/SuddenDeathPracticeView.swift`, `Noum/IMPracticeView.swift`, `Noum/TimedPracticeView.swift`, `ProfileView.swift` — multiple `.animation(.easeInOut(...), value: …)` and `withAnimation(.standardSpring) { … }` blocks that DO NOT branch on reduceMotion. Counts: 9 in AhCounter, 14 in SuddenDeath, 4 in IM, 16 in TimedPractice, 3 in Profile. | **SHOULD-FIX** (pre-existing) | Most are state-keyed transitions (score reveal, phase change) rather than vestibular full-screen motion. Still violates the documented expectation that animations gate on reduceMotion. Pre-existing across all 5 files — M15 did not add new animations to any of them outside the orb integration. The orb itself handles reduceMotion internally (NoumCharacter.swift:83, 242, 289, 318, 404), so the M15-added piece IS compliant; the surrounding containers are not. |
| `Noum/HomeSignalGate.swift` | clean | Pure-function helper, no view code, no animations expected. |
| `Noum/SpeechRecognizerViewModel.swift` | clean | View-model only, no animations. |
| `Noum/NoumCharacter.swift` | clean | All 5 `repeatForever` calls at lines 472, 485, 497, plus the wobble at 318, plus the listening arcs at 404, are gated on `reduceMotion` (verified at lines 318, 472, 485 — each guards with `guard !reduceMotion`). |
| `Noum/AskNoumView.swift:619` (`PendingPulse`), `Noum/FirstRepCelebration.swift:561` (orbs layer), `Noum/CutTheCrutchView.swift:276` (transition), `Noum/PracticeModeSelectionView.swift:306-308, 408` (expand transition + spring), `Noum/SettingsView.swift:211, 1022, 1549` | clean | All M15-introduced animations correctly check `reduceMotion`. Phases 2, 3, 5 are fully compliant. |

### VoiceOver — orb compete with header

| Finding | Severity | Notes |
|---|---|---|
| `Noum/AhCounterView.swift:139`, `Noum/CutTheCrutchView.swift:128`, `Noum/CutTheCrutchView.swift:309`, `Noum/IMPracticeView.swift:391`, `Noum/SuddenDeathPracticeView.swift:246`, `Noum/SuddenDeathPracticeView.swift:465`, `Noum/TimedPracticeView.swift:820`, `Noum/TimedPracticeView.swift:1445` — every M15-introduced orb placement carries `.accessibilityHidden(true)`. | clean | Phase 1b's a11y discipline is consistent. |
| `Noum/FirstRepCelebration.swift:182` — orb does NOT carry `.accessibilityHidden(true)`. | **SHOULD-FIX** | See "accessibility labels" row above for the same finding. |

---

## Summary table

| File | Anti-goal violations | A11y violations | Overall |
|---|---|---|---|
| `Noum/AhCounterView.swift` | 0 | 1 SHOULD-FIX (repeatForever; pre-existing) | minor (pre-existing) |
| `Noum/AskNoumView.swift` | 0 | 0 | clean |
| `Noum/ContentView.swift` | 0 | 1 SHOULD-FIX (cardEntrance reduceMotion; pre-existing) | minor (pre-existing) |
| `Noum/CutTheCrutchView.swift` | 2 NICE-TO-HAVE (hearts visual + "3 hearts, no second chances" copy; pre-existing, intra-drill pressure not meta-game) | 0 (orb hidden, headlines `accessibilityElement(.combine)`'d) | minor (pre-existing) |
| `Noum/FirstRepCelebration.swift` | 0 | 1 SHOULD-FIX (hero orb missing `.accessibilityHidden(true)`; M15-introduced) + 1 NICE-TO-HAVE (proof-line fade-in not reduceMotion-gated at line 431; M15-introduced) | minor (M15) |
| `Noum/HomeSignalGate.swift` | 0 | 0 | clean |
| `Noum/IMPracticeView.swift` | 0 | 1 SHOULD-FIX (animations not reduceMotion-gated; pre-existing) | minor (pre-existing) |
| `Noum/NoumCharacter.swift` | 0 | 0 | clean |
| `Noum/PracticeModeSelectionView.swift` | 1 NICE-TO-HAVE (Cut the Crutch subtitle "3 hearts, no second chances"; pre-existing) | 0 | clean (intent-compliant — Phase 3 explicitly reduceMotion-gates its new expansion via `animateMode(_:)` at line 407-411 and `transition` at 306-308) |
| `Noum/SettingsView.swift` | 0 | 0 | clean |
| `Noum/SpeechRecognizerViewModel.swift` | 0 | 0 | clean |
| `Noum/SuddenDeathPracticeView.swift` | 0 | 1 SHOULD-FIX (animations + tiny font; pre-existing) | minor (pre-existing) |
| `Noum/TimedPracticeView.swift` | 1 SHOULD-FIX (emoji celebration burst at line 1717; pre-existing) | 1 SHOULD-FIX (repeatForever + animations; pre-existing) | minor (pre-existing) |
| `ProfileView.swift` | 0 (and one *positive* finding — line 539 comment shows deliberate VISION-anti-goal compliance for the insights chip) | 1 NICE-TO-HAVE (`size: 7-8.5` heat-map labels; pre-existing) | clean |

---

## Headline verdict

- **No M15-introduced BLOCKER findings.** Every M15 commit honors the VISION anti-goals: no streak shame, no chirpy filler, no exclamations, no fake loading, no emoji introduced. Phase 5 in particular was designed against the anti-goal list (see ProfileView.swift:535-541 docstring) and the chip correctly hides at zero rather than producing a hollow "0 insights" loss-aversion prompt.
- **One M15-introduced SHOULD-FIX:** the hero `NoumCharacter` on `FirstRepCelebration.swift:182` is not `accessibilityHidden`. One-line fix.
- **One M15-introduced NICE-TO-HAVE:** the proof-line fade-in at `FirstRepCelebration.swift:431` (`withAnimation(.easeOut(duration: 0.45))`) is not gated on reduceMotion even though the file's `runSequence()` correctly gates everything else. Inconsistent with the rest of the entrance choreography.
- **Several pre-existing SHOULD-FIX:** the emoji celebration burst in `TimedPracticeView.swift:1717`, the `CardEntranceModifier` not checking reduce-motion, and the `repeatForever` animations across the four practice views without reduceMotion guards. These pre-date M15 but the audit surfaces them because M15 touched the surrounding files.
- **Borderline pattern worth team review:** the Cut the Crutch hearts mechanic is documented as "loss-framed" by its own engine docstring; it does NOT gate practice across the app (each heart-zero just ends one 60s round, not the day's practice), so it reads as a pressure mode rather than VISION's banned "hearts-and-lives gating game", but the visual register sits closer to that line than other modes.

## Recommended pre-release fix order

1. Add `.accessibilityHidden(true)` to `Noum/FirstRepCelebration.swift:182` (M15-introduced, trivial).
2. Replace `["🎉", "✨", "🔥", "⭐️", "💪", "🏆"]` burst in `Noum/TimedPracticeView.swift:1717` with the existing `ConfettiLayer` (SF-Symbol-based, brand-consistent, already reduce-motion-aware).
3. Gate `Noum/CardEntrance.swift:24-26` on `@Environment(\.accessibilityReduceMotion)`; one of the most-revisited modifiers in the app.
4. Audit `repeatForever` blocks in `AhCounterView.swift:225`, `TimedPracticeView.swift:286, 1124, 1305, 1458` for reduce-motion guards.
5. Optional team review: whether the Cut the Crutch hearts visual / "3 hearts, no second chances" copy crosses the VISION "hearts-and-lives" line or stays inside the pressure-mode pillar.

Items 4 and 5 are not M15-introduced and can ship as a separate pass after the M15 release cut if needed.
