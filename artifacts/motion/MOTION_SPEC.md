# Noum Motion & Haptics Contract — V4.6.1/V4.6.2

**Date:** 2026-07-25 · **Branch:** `ux-overhaul` · **Code:** f5433b653 (V4.6.1 pass) + this round
**Figma:** file `srCgE5IP3rWoNMWtHo3AnI` · page **18 V4.6.1 — Motion Contract** (`280:497`), authored via MCP this round. Frozen visual source stays page 17 (`258:933`); this page is the *temporal* contract.
**Prior plan:** `artifacts/implementation/V4_6_1_MOTION_PASS_PLAN.md` (hook map, risks, test pins).

## 1. Motion vocabulary (DesignSystem.swift — the ONLY names surface code may use)

| Token | Curve | Use |
|---|---|---|
| `Animation.tapFeedback` | .15 spring | press squish (buttons, capsules, ImmersiveCTA scale) |
| `Animation.listChange` | .26 spring | list compress/expand, selection dim, chip swaps, tab-pill glide, armed gain |
| `Animation.settle` | .34 spring | entrances, reveals, CTA arrival |
| `Animation.payoffReveal` (+`payoffRevealDuration`) | .6 spring | earned reveals: comparison payoff, earned-hero flip, score receipt |
| `Animation.progressAck` (=`progressFill`) | .6 easeOut | progress bars, count acknowledgement, trajectory grow-in |
| `Animation.stagger(_:)` / `coachLineStagger(_:)` | +80ms/idx / reading rhythm | list entrances / changed-word wave |
| `v46Quick`/`v46Settle`/`v46Dissolve` | 260/340/600ms | the signed-off V4.4 smart-animate pairs (route-level) |
| `v46ReduceMotionFade` | 200ms | THE RM replacement for any cross-fade |
| `withMotion(rm, anim) {}` | — | blessed imperative RM guard (global, DesignSystem) |

Rules: no raw durations in surface code · no new `repeatForever` loops (VoiceTrace's transaction-settle + scenePhase re-arm is the only sanctioned ambient pattern) · every motion has an RM branch.

## 2. Haptic register (CoachHaptic — all gated by HapticsSettings)

| Semantic | Pattern | Fires at |
|---|---|---|
| commitment | `drillStart` | Today/Train/Rehearsal commit CTAs, call send/barge-in |
| selection | `selectionTap` / `.sensoryFeedback(.selection)` | theme/intent/tab/mode/mic-arm changes — genuine changes only |
| result lands | `scoreReveal` + `InteractionCue.verdictReveal` | Summary receipt settle frame |
| completion | `drillSuccess` / `drillIncomplete` | verdicts; incomplete = gentle ack, never a buzzer |
| **earned evidence** | **`earnedEvidence`** — two soft transients 0.55 → 0.85, 100ms apart | Today earned announcement (ledger-acked, once per event) · comparison `improved` only |
| warning | `unavailableNotice` — soft double-tick | entry INTO `.unavailable` (once per episode), dead-mic watchdog; never `.checking` |
| timer | `timerUrgency` (red/overtime) / `countdownBeat` | timing-state crossings |

Bans: nothing on `regressed`/`needsMoreEvidence` · nothing while the mic records (reply-landed acks suppressed) · no raw `UIFeedbackGenerator` anywhere (all 8 legacy sites migrated) · milestone patterns stay RewardEngine-gated.

## 3. VoiceTrace state family (report-21 taxonomy → implementation)

| Report state | Implementation | Notes |
|---|---|---|
| idle | `.idleHero` + 2.4s breath (±0.14s/bar stagger, 350ms wake on entrance) | RM: static silhouette |
| **armed** | `armed: Bool` render-gain — bars ×1.06, opacity +0.08, `.listChange` | bound to the commit CTA's REAL press state (`ImmersiveCTA(isPressed:)` binding). RM: instant state cue |
| live | `.live` + mic envelope (5% quantised, 120ms easeOut) | real audio only — never synthesized |
| settling | `.settling` = live ×1.1 heights / 0.45 opacities | geometry pinned by V46CoachingLoopSurfaceTests |
| earned | `.earnedHero` (sums strictly > idle, pinned) + payoffReveal flip | ledger-bound, once per event |
| reduced | RM contract on every variant | transaction-settle + scenePhase re-arm preserved |

**Deliberate rejection:** report 21's Canvas/TimelineView rebuild. The current implementation is already state-driven, audio-reactive, test-pinned, and cheap (12–22 bars); a renderer swap is churn without user-visible gain. Revisit only if profiling shows cost.

## 4. The three signature moments

**A · Today hero arming** (Figma `281:497` rest ⇄ `281:515` armed, Smart Animate 260ms wired)
Entrance: text 0ms → trace breath wakes 350ms → CTA +120ms (~460ms; content never invisible; inside ScreenshotTour's 1.5s). Press: CTA dims 84% + scale 0.985 (`tapFeedback`) while the trace gains (armed). Commit: `drillStart`. RM: instant states, dim-only press.

**B · Recording → Processing continuity** (Figma `282:497` live, `282:522` settling)
Live trace follows the real mic envelope; Processing renders the same object settling (×1.1/0.45 family) through the 1.4s ready-dwell; `v46Dissolve` 600ms into Review. No perpetual loops. RM: static silhouettes, instant swaps.

**C · Comparison payoff → Updated Today** (Figma `282:548` payoff, `282:552` receipt)
Card settles from a visible pre-state; payoff line lands on the `payoffReveal` settle frame with the result haptic (improved → `earnedEvidence`, held → gentle ack, regressed/insufficient → nothing). Announcement acks `V46EarnedEvidenceLedger` once; ≥10min later visits collapse to the quiet receipt (36h window); Updated Today + Progress read the same ledger. RM: one 200ms fade, haptics kept.

## 5. Micro-interactions (Figma `283:505` CTA set, `283:514` tab set)

- ImmersiveCTA: Default / Pressed (84% + 0.985) / Disabled (40%/45%) / Loading (3-dot 280ms, RM skips).
- Tab bar: selection pill glides via `matchedGeometryEffect` in `tabPillNamespace`, animation scoped to the BAR subtree (`.animation(value: selectedTab)`) so TabView content switches stay instant; one `selectionTap` per genuine tab change (re-tap silent). RM: pill appears without glide.
- Train browse: hero↔compact morph (settle/listChange), staggered group entrance, unselected rows dim to 0.55 on selection, CTA arrives on `settle`, tints crossfade only through AA action registers.
- Rehearsal: entrance stagger, accent bar on current step, "N of 3 covered" live count.

## 6. Reduce Motion (blanket)

Entrances/staggers → instant · cross-fades → `v46ReduceMotionFade` · breathing/live-dot → static · press scale → dim only · changed-word wave → none (static highlight stays) · haptics unaffected (RM users' feedback channel, still Settings-gated).

## 7. Proof status

- Sim (dark, seeded, iPhone 17 / iOS 26.5): `.screenshots/2026-07-25_v461-motion/` — entrance frame series (4 differing), breathing pair (differs), **RM settled pair md5-identical (fully static)**, rehearsal count/accent, Train selection-dim. This round adds armed/tab captures.
- Tests: full `NoumTests` target green (V4.6.1 run); geometry pins intact; prep suite green incl. covered-count.
- **Not provable here:** device haptics (no physical iPhone attached — simulator cannot render haptics; run the register on-device before TestFlight), sim video (headless SimRenderServer denies recordVideo; frame series stand in).
- Known pre-existing red (chip filed, verified at clean HEAD): RecommendationSurfaceRouting theme-leak ×2, GoalOutcomeLoop ladder rung.
- Rive spike: **not warranted** — the native pass delivers state-bound presence; revisit only if the coach orb needs a richer state machine after device QA.
