# V4.6.1 — Motion, Presence & Reward Pass · Plan

**Date:** 2026-07-25 · **Branch:** `ux-overhaul` (from a6e412a2a) · **Brief:** deep-research report 20 ("presence and reward problem, not a spacing emergency")
**Scope law:** wire and strengthen what exists; no IA changes, no new stores, no new celebration overlays (their retirement is UI-test-pinned), no motion without a Reduce-Motion replacement.

## 0. What recon found (shapes everything below)

The app already has most of the machinery this brief asks for — much of it designed and then never wired:

- `DesignSystem.swift` has a **V4.6 motion-contract block that is mostly unclaimed**: `v46Settle`, `v46Dissolve`, `stagger(_:)`, `coachLineStagger`, `scoreReveal`+`scoreRevealDuration` all have **zero call sites**. This pass claims them rather than inventing parallel timings.
- `CoachHaptic` (Noum/CoachHaptic.swift) already defines **19 semantic, settings-gated patterns** with a written register map (input-ack / commitment / result-lands / completion-verdicts / milestones). The gap is not the map — it's **8 raw `UIFeedbackGenerator` call sites that bypass the gate** (TimedPracticeView ×6, SuddenDeathPracticeView:228, SessionIntentPromptView:98) and several designed beats never wired (`scoreReveal`, `timerUrgency`).
- Press feedback exists (`PressableButtonStyle`, `ImmersiveCTA` pressed-dim); ambient presence exists (VoiceTrace breath, NoumCharacter moods); the earned-state spine exists (`V46EarnedEvidenceLedger` → hero override → 10-min-floor receipt). The earned flip is currently **instant and silent** — the single biggest missed reward beat in the app.
- The calm-receipt direction is **test-pinned**: ScreenshotTour asserts `preSummary.celebration` / `path.celebration` / `tier.promotion.overlay` do NOT appear post-rep, and PathUnlockCelebrationIntegrityTests greps ContentView source. Reward here means *salience on real surfaces*, never overlays.
- The established RM idiom is `@Environment(\.accessibilityReduceMotion)` (352 refs; zero `UIAccessibility` reads), the `withTransaction(disablesAnimations)` settle for mid-session RM flips, and the scenePhase re-arm for `repeatForever` (VoiceTrace is the canonical copy). A duplicated imperative helper `updateWithMotion` exists ×3 (AhCounterView:588, TimedPracticeView:2022, PREPStackView:561) — promoted to one blessed helper this pass.

## 1. Motion token system (DesignSystem.swift — claim, alias, add)

One vocabulary, three speeds + two specials, matching the signed-off Figma motion contract (SA260 / SA340 / SA600, RM alternative per step):

| Semantic token | Binding | Timing | Status |
|---|---|---|---|
| `Animation.tapFeedback` | alias of `buttonSquish` | .15 spring | exists (rename-alias) |
| `Animation.listChange` | alias of `snappySpring` | .26 spring | exists (alias) — list compress/expand, selection dim |
| `Animation.settle` | claims `v46Settle` | .34 spring | dead → claimed — entrances, reveals, CTA arrival |
| `Animation.payoffReveal` | claims `scoreReveal` + `scoreRevealDuration` | .6 spring + settle-frame beat | dead → claimed — comparison payoff, earned flip |
| `Animation.progressAck` | alias of `progressFill` (+`progressFillDuration`) | .6 easeOut | exists — Progress bars, count acknowledgement |
| `Animation.stagger(_:)` / `coachLineStagger` | existing declarations | 50ms/idx cap 300 / per-word | dead → claimed — list entrances, changed-word emphasis |
| ambient breathing | VoiceTrace 2.4s / NoumCharacter 4s | unchanged | exists — do not add new ambient loops |
| `withMotion(_:_:_:)` | promoted `updateWithMotion` | n/a | new shared helper; 3 duplicates deleted |

Rules: no new raw durations anywhere in surface code; RM replacement is `v46ReduceMotionFade` (fade/annotation swap) or nothing; ambient loops must copy VoiceTrace's transaction-settle + scenePhase re-arm pattern.

## 2. Haptic map (CoachHaptic — extend by 1, wire the rest)

| Brief semantic | CoachHaptic pattern | Fired at |
|---|---|---|
| primary action pressed | `drillStart()` (commitment register — exists) | Today hero CTA (already :916), Train hero Begin + quickStart, Rehearsal `launch(step:)` funnel |
| selection changed | `selectionTap()` / `.sensoryFeedback(.selection)` (exists) | Train mode rows (exists) + crutch/pace rows (parity gap), Ask Noum mic arm |
| successful completion | existing completion-verdict register | unchanged (SummaryView) |
| meaningful progress earned | `trendBreakthrough()` (exists, milestone register) | comparison `improved` payoff settle-frame; Today earned-hero announcement (ledger-bound, once per event) |
| warning / unavailable | **`unavailableNotice()` — NEW** (soft double-tick, warning register) | Ask Noum banner arrival + dead-mic watchdog; never on mere `.checking` |
| score settles | `scoreReveal()` (exists, unwired) | SummaryView ring settle frame, paired with `Animation.payoffReveal` |

Discipline (unchanged from the register map): ordinary buttons get the visual squish only; milestone-tier patterns only on ledger/outcome-bound events; every haptic has a visible UI cause; all routes through the `HapticsSettings` gate — and this pass **migrates the 8 raw ungated call sites** onto gated patterns.
Explicitly NOT firing: anything on `regressed` / `needsMoreEvidence` (never punish), anything while recording (mic-active suppression stays).

## 3. Surfaces — exact states to animate

### Today (HomeCoachCard, ContentView, VoiceTrace) — layout untouched
- **Hero entrance choreography** (once per appear, repeat-safe one-shot): headline+support settle (`settle`, 0ms) → trace wakes (breath arm delayed ~350ms) → CTA lands (`settle` +120ms). Total ≤ 650ms — inside ScreenshotTour's 1.5s wait and the Train-style 150ms perceptibility budget (content starts visible at 0.97/0.85, settles to 1.0 — never invisible).
- **CTA tactility**: `ImmersiveCTAButtonStyle` gains scale 0.985 + existing dim on press (RM: dim only). Haptic stays at commit (existing `drillStart`).
- **Earned announcement** (real state: `activeEarned` nil→value, acked once into `V46EarnedEvidenceLedger`): chip + headline swap + `idleHero→earnedHero` trace flip animate together with `payoffReveal` (trace bars grow bar-for-bar — geometry is 12↔12 aligned) + one `trendBreakthrough()`. RM: cross-fade, haptic kept.
- **Receipt rows** (`homeProgressReceipt`): `settle` insertion + fade dismissal; no haptic (the announcement had it; the 10-min-floor receipt is deliberately quiet).
- **Vestigial mood lifecycle** (`isBursting`/`restingMood` drive nothing): wire `isBursting` to a one-shot subtle trace brightening when the recommendation genuinely changes, or delete it — implementer verifies which is cheaper; no dead state either way.

### Ask Noum (AskNoumView, LiveCoachCallView, CoachSessionView, NoumCharacter)
- **States made visible** (all real, no fabricated motion): idle (`.calm`), listening (`.listening` + mic envelope on the call orb **only if** `AskNoumVoiceInput` exposes a real level — API exists on NoumCharacter, do not synthesize), speaking (`.coaching`), thinking (`.thinking` + existing pendingDots), unavailable (banner + orb dims to static), reconnecting (`.checking` spinner — exists), **restored** (transient "Back online" confirmation that auto-fades; counter already resets via the `.onChange(liveCoachAvailability)` observer).
- **Live pill**: breathing live-dot (RM: static).
- **Call haptics** (all currently silent): mic arm = selection; send/barge-in = `drillStart`-register; reply landed = soft input-ack at BOTH chokepoints (reveal completion :3726 AND the `isAwaitingReply→false` observer :944 — RM users only hit the second); dead-mic watchdog + banner arrival = `unavailableNotice()`.
- **Reply-landed presence**: header waveform badge `moodPulse` when a reply lands (primitive exists, currently orphaned).
- **Intro card collapse**: the empty-state card already vanishes when the first message exists — give it a compress+fade removal transition (`listChange`; RM: fade) so the conversation visibly takes the screen.
- **Banner**: unavailable→restored transition animates; "informative, not a dead footer".

### Train (PracticeModeSelectionView) — density + selection focus
- **Hero↔compact morph**: asymmetric transition on the existing conditional swap (`settle` in, `listChange` out; RM: opacity). Library groups get `stagger(_:)` entrance.
- **Selection focus**: when any selection is active, unselected library rows dim to ~0.55 opacity + selected row keeps full contrast (`listChange`; RM: instant). Crutch/pace rows gain the same `.sensoryFeedback(.selection)` the mode rows already have.
- **Floating CTA arrival**: move+opacity `settle` transition; tint crossfades only between the AA-safe *Action registers (never through raw decorative tints).
- **Bottom space**: already reserved (round-2 fix); verify no CTA-over-content regression at capture time.

### Rehearsal (PrepSessionView, PrepSessionPlanner + its two test files)
- **Progress indicator**: "N of 3 covered" trailing the REHEARSAL PLAN header — derived from the same `stepStatuses` array the rows render (fallback-inclusive semantics, which is the plan's own truth; Profile keeps shape-honest readiness — divergence is already unit-pinned as intentional).
- **Current-step focus**: current row gets an accent leading bar + full contrast; done rows relax (existing green, opacity 1.0 but visually settled); locked rows recede further (0.75→0.6). Entrance staggers intro→steps→footer.
- **Prose weight**: split `introCopy` into `proximitySentence` + `arcSentence` in the planner (pure change); view renders proximity at body weight, arc as one quieter footnote line. Unit tests updated to pin both strings (the 4 availability variants stay verbatim, just split).
- **Buttons**: step capsules adopt `.pressable`; `launch(step:)` (single funnel) fires `drillStart()`.
- **No fake transitions**: the current→done flip happens off-screen (fresh view per navigation) — no simulated flip animation.

### Comparison / earned moments (TranscriptPracticeLoop, SummaryView, SessionHistoryView)
- **Comparison payoff** (entrance keyed on `outcome.id`, never bare onAppear): card settles in; the payoff line (`transcriptRetry.payoff` — already names the real behavioural change) lands on a `payoffReveal` settle-frame; `improved` → one `trendBreakthrough()`; `held` → quiet completion tick; `regressed`/`needsMoreEvidence` → no haptic, no emphasis beyond the existing honest copy.
- **Changed-word emphasis**: the retry rung already computes changed indexes — brief staggered brighten via `coachLineStagger` (RM: none; static highlight already exists).
- **Score-ring settle** (SummaryView): wire the designed-but-dead beat — `payoffReveal` + `CoachHaptic.scoreReveal()` + `InteractionCue.verdictReveal` on the settle frame. Respect the source-ordering pin in SpeechSessionIntegrityTests (`RewardEngine.shared.evaluateDrill(` literal must survive byte-exact).
- **Progress head**: one-time grow-in of trajectory clusters (`progressAck` + `stagger`; RM: static). Updated-Today/receipt coherence comes free via the Today work (same ledger).
- **No overlays. No confetti additions. Review-prompt gate untouched** (StoreKit sheet races live at exactly this moment).

## 4. Reduce Motion replacements (blanket contract)

| Motion | RM replacement |
|---|---|
| Entrance choreography / staggers | instant appear (CardEntrance precedent) |
| Hero earned flip, hero↔compact morph, CTA arrival | cross-fade (`v46ReduceMotionFade`) |
| Breathing (trace, live-dot) | static (existing VoiceTrace/NoumCharacter contract) |
| Changed-word stagger | none (static highlight persists) |
| Press scale | opacity/dim only (existing PressableButtonStyle RM branch) |
| Haptics | unaffected by RM (they are the RM user's feedback channel); still user-gated via Settings |

## 5. Proof plan

Per surface: before/after PNG pairs (seeded dark sim, iPhone 17 iOS 26.5) in `.screenshots/2026-07-25_v461-motion/`; motion evidence = 2–3 frame series (simctl screenshots ~400ms apart) for hero entrance, earned announcement, comparison payoff + `simctl io recordVideo` clips where frame pairs can't show causality. RM sweep: `simctl spawn <udid> defaults write com.apple.Accessibility ReduceMotionEnabled -bool true` + relaunch → recapture the same states (fall back to documenting the in-code RM branch per site if the sim override proves unreliable). VoiceOver: identifier/label diffs asserted by existing UI suites + manual AX-tree dump on changed rows.

## 6. Risks (from recon — each has an owner in the briefs)

1. **Test pins everywhere**: exact labels/identifiers (`prepSession.step.N.begin` 1-indexed, `practiceModes.start`, `transcriptRetry.comparison` + "The target moved", "Send message", home.coachCard exact strings under seed), source-scan tests (ContentView, SummaryView, AskNoum store mutations), copy-audit bans. Every agent gets its pin list; nothing renames identifiers.
2. **Retained vs fresh views**: Home/Train tab roots never remount (one-shot entrances fire once per launch; re-entry via `isSelectedAppTab`); Prep/Summary mount fresh (key entrances on data identity, not onAppear).
3. **Ledger once-per-event**: earned-hero motion must not re-trigger `resolveEarnedState` or remount the hero (would double-ack).
4. **Exposure accounting**: Train hero must stay perceptible ≤150ms into entrance.
5. **repeatForever freeze**: any new loop copies VoiceTrace's scenePhase re-arm; better — add no new loops.
6. **Haptic-gate erosion**: migration must not miss a raw generator or route through a new ungated path.
7. **ScreenshotTour timing**: total entrance ≤1.5s budget on Home.
8. **Concurrent agent** shares this branch/DerivedData: stage explicitly, one xcodebuild at a time.

## 7. Acceptance gates

1. Debug build green; full `NoumTests` target green; `PrepSessionAvailability*` + retry-comparison + contextual-Ask + RecommendationSurfaceRouting suites green.
2. Motion evidence captured for: hero entrance, earned announcement, comparison payoff, Train morph, Ask Noum banner states.
3. RM captures (or per-site branch documentation) for every added motion; zero motion without an RM branch (grep-audited).
4. Zero new raw `UIFeedbackGenerator`/`sensoryFeedback` outside the gate; the 8 legacy raw sites migrated.
5. No identifier/label changes (UI suites prove it); AX combine shapes preserved on touched rows.
6. Dark-mode captures for every changed surface.
7. No overlay celebrations reintroduced (ScreenshotTour negative assertions stay green).
8. Honest deviations documented in the final report.
