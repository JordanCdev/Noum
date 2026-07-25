# V4.6 Final — SwiftUI Implementation Plan

**Date:** 2026-07-25 · **Source:** Figma page 17 `258:933` "17 V4.6 — Finalise Coaching Loop" (FINAL; page 16 `233:819` is historical)
**Handoff:** `artifacts/figma/V4_6_FINAL_HANDOFF.md` · **Exports:** `artifacts/figma/v4.6-final/` (26 validated PNGs)
**Branch:** `claude/v4-6-swiftui-implementation` (isolated worktree off `ux-overhaul` @ `97028234a`)
**Baseline:** Slice 1 (Review transformation, retry continuity, comparison payoff) landed in `97028234a` with verification evidence.

## Token contract (from SwiftUI board 258:1865)

| Token | Light | Dark | SwiftUI owner |
|---|---|---|---|
| screen | #FAF9F7 | #17151C | semantic theme background |
| coaching/ink (editorial CTA fill, improved phrase) | #4C2BB8 | #9061F9 | existing `AppColor` violet family |
| coach/accent (trace bars, marks) | #7C3AED | #9061F9 | existing |
| color/coach/live (NEW) | n/a (natively-dark only) | #9E70FA | `AppColor.voiceLive` (landed Slice 1) |
| color/neutral/receded (NEW) | #5A6474 | #8A93A4 | `AppColor.neutralReceded` (landed Slice 1; dark value to add) |
| color/action/pressed (NEW) | #3F2499 | #7A4FF0 | `AppColor.actionPressed` (landed Slice 1; dark value to add) |
| feedback/success | qualified improvement only | explicit dark mapping (never grey-bucket) | existing |
| feedback/caution | lapse rows, ALWAYS with text cue | ditto | existing |

Dark frames are semantic recolours — implementation themes via semantic color owners, Figma dark frames are visual reference, NOT the colour source.

## Type roles (Figma → device; mocks Nunito/Inter → SF Pro Rounded/SF Pro 1:1 by role)

| Role | Figma | SwiftUI |
|---|---|---|
| Hero insight | Nunito ExtraBold 26–31/32–37 | `.system(.title, design: .rounded).weight(.heavy)` |
| Screen title | Nunito Bold 22 | `.system(.title2, design: .rounded).bold()` |
| Quote / improved phrase | Nunito Bold 22–24/30 | `.system(.title3, design: .rounded).weight(.semibold)`; improved phrase tinted coaching/ink |
| Payoff line | Nunito Bold 17 | `.system(.headline, design: .rounded)` + feedback/success |
| Body | Inter Regular 15 | `.subheadline`; hero body 85% opacity |
| Meta | Inter 13 @70% | `.footnote` + `.monospacedDigit()` for clocks |
| Eyebrow | Inter Semi Bold 12, +0.06em, UPPERCASE | `.caption.weight(.semibold).tracking(0.6).textCase(.uppercase)`, ≤2/screen |
| Tertiary rows | Inter 12 @60–75% | one per screen |

## Motion contract (standard → Reduce Motion)

pushRecording SA340→fade200 · settleToProcessing SA260→fade200 · revealReview auto1.4s dissolve600→same (no drift) · transformTokens SA600→instant swap + "Show the change"/"Replay" · retrySamePrompt SA260→fade200 · arriveComparison SA600→fade260 (payoff by weight/colour only) · closeLoop SA340→fade200 · tabToProgress SA340→fade200. Rule: fades/emphasis/colour-opacity only — no parallax, no trace drift, no ambient loops. Gate on `accessibilityReduceMotion`.

## Frame map

| # | Frame | Node | Destination (SwiftUI) | State owner | Status |
|---|---|---|---|---|---|
| 1 | Today | 258:934 | Home/Today tab hero (fill after codebase map) | coaching plan snapshot + upcoming moment | Slice 2 |
| 2 | Recording — live | 258:981 | timed practice recording surface | recording session state | Slice 2 |
| 3 | Processing | 258:994 | post-rep analysis wait state | existing request-trace/finite states | Slice 2 |
| 4 | Review | 258:1006 | Review ladder (Slice 1 DONE @97028234a) | session summary + rewrite stores | Done, verify |
| 5 | Retry recording | 258:1032 | same recording surface, retry context (Slice 1 continuity DONE) | TranscriptRetryPrompt.resolve | Done + Slice 2 restyle |
| 6 | Comparison | 258:1045 | comparison card (Slice 1 DONE) | pair data + plan ledger | Done, verify |
| 7 | Updated Today | 258:1078 | Today variant, earned state | persisted evidence event + plan revision | Slice 3 |
| 8 | Progress | 258:1131 | Progress tab trajectory | evidence rows + review row owners | Slice 3 |
| 9 | Recording — silence | 258:1195 | recording surface state | silence detection | Slice 2 |
| 10 | Recording — final seconds | 258:1252 | recording surface state (amber clock, "Land the close") | timer | Slice 2 |
| 11 | Review — Explore open | 258:1309 | Slice 1 disclosure (verify) | — | Done, verify |
| 12–16 | Dark Today/Review/Comparison/Updated/Progress | 258:1348/1395/1421/1454/1507 | semantic recolours via theme owners | — | Slice 4 |
| 17–20 | AX3 Today/Review/Comparison/Progress | 258:1617/1630/1655/1687 | Dynamic Type proofs | — | Slice 4 |
| 21 | AX5 Review stress proof | 263:933 | wrap/recede/96pt CTA behavior | — | Slice 4 |
| 22 | RM sheet | 258:1717 | motion pairs above | — | all slices |
| 23 | Accessibility sheet | 258:1756 | VO order/labels | — | all slices |
| 24 | SwiftUI board | 258:1865 | this contract | — | reference |

## Key measured values (from get_design_context)

**Today (258:934):** hero 393×496, bottom radius 36, gradient 141° #4D3CC7→#7A45E0 (71%), shadow (0,18,44,-8) violet 28%; eyebrow "Today" ExtraBold 15 white80 @(24,70); headline 31/37 w330 @(24,138); body 15.5/22 @85% @(24,226); meta SemiBold 13.5 white85@70% @(24,278); idle trace 12 bars w4 gap4 r2 h[6,10,16,24,18,28,20,12,8,14,9,6] whiteα[.18,.26,.34,.41,.45,.48,.48,.45,.41,.34,.26,.18] centered @y326; CTA white 345×58 r30 "Start rep" Bold 17 ink @y394; "Adjust practice ›" SemiBold 12 #5A6474@60% @y520 (≥44pt hotspot); canvas wash violet 0→8% bottom 200pt; tab bar capsule white94 border white60 r32 px10 py8, item px15 py6 r22, selected bg #F3EFFB label ExtraBold 10.5 #4C2BB8, unselected SemiBold 10.5 #5A6474, glyphs 20pt = sun.max/waveform/chart.line.uptrend/person.crop.circle.

**Recording (258:981):** bg vertical #1B1625→#100D19; chip white8% capsule px12 py7: 8pt red dot + "REC · PRESSURE DRILL" ExtraBold 10 track1.2 white80 @(24,60); "0:12 left" ExtraBold 15 white85 top-right; prompt ExtraBold 25/31 white centered w320 @y150; live trace 320×140 @y330: 22 bars w5 r2.5 pitch14.5 h[6,9,19,26,27,22,37,51,60,59,50,35,44,54,55,48,36,21,18,16,9,6] α ramp .35→1→.35 (#9E70FA) + mirror bars @top74 ~45% height/α + glow ellipse 260×120; cue SemiBold 14 white65 @y508; CTA white pill "I'm done" @y700. Silence: trace dims, cue "Quiet is fine — thinking counts. The clock keeps running." Final seconds: clock amber, cue "Land the close".

**Processing (258:994):** same bg; chip violet dot + "READING YOUR REP"; headline ExtraBold 26/31 centered @y150 "Checking whether the decision lands first…"; settling trace 352×154 @(21,323) = live geometry ×1.1 with α×~0.45 + glow 286×132; cue "Your words, your timing — one read coming" @y494; Cancel = quiet TEXT (Bold 15 white65) centered in 345×58 hotspot @y700 — never a pill. Auto 1.4s → Review (dissolve 600).

**Updated Today (258:1078):** Today hero variant, structure chip→headline→meta→trace→CTA (NO body line — the differentiation from Today). Earned chip white16% capsule pl10 pr12 py6 @y108: 4 mini bars white95 (h 4/7/11/6, w2.5 r1.5 gap2) + "New evidence · from your retry" ExtraBold 10.5 track0.6 white; headline 33/37 @y150 "Same target — shorter clock."; meta SemiBold 13.5 white85 @y246 "Plan moved · 3 min · 45s answer clock"; earned trace 12 bars h[8,14,22,34,26,38,28,16,10,18,12,8] whiteα[.35,.48,.59,.69,.76,.8,.8,.76,.69,.59,.48,.35] @y288; CTA "Start the shorter clock" @y354. "Adjust practice ›" here is 13.5 @75% (vs 12 @60% on plain Today).

**Progress (258:1131):** editorial canvas #FAF9F7, ink #212633; title "Progress" ExtraBold 22 @(24,64); content column x24 w345 from y118: eyebrow "ANSWER FIRST" ExtraBold 11 track1.2 #4C2BB8 → +12 → headline "Becoming reliable." ExtraBold 28/33 → +8 → subtitle Inter 15/21 #5A6474 "Held in 3 of 4 comparable reps — one under pressure." → +32 → weekly trajectory 345×120 (4 day clusters of 5 bars w4.5 r2 + dimmer reflections, coach/accent #7C3AED; TODAY cluster tallest; labels ExtraBold 9–9.5 track0.8: MON/TUE/TODAY #4C2BB8, WED #B45309 amber = lapse) → +18 → 3 attempt rows (py7 gap10: day label w46–52 + copy 14/18; held rows Inter SemiBold #212633, lapse row Inter Regular #5A6474 with amber day label) → +20 → violet rule 40×3 → +34 → plan-review row #F3EFFB r18 px16 py14 "Review this target on Friday" + trailing ›. Tab bar Progress selected (violet glyph + ExtraBold ink label + #F3EFFB pill).

## Verification per slice

Build (isolated DerivedData) → launch on newest iPhone sim (iPhone 17 Pro, iOS 26.5) → deterministic captures → compare vs `artifacts/figma/v4.6-final/*.png` → critique → fix (≤3 visual iterations) → targeted tests → local commit. Coach Arena only if coaching reply behavior changes (not expected — presentation-layer work).

## Codebase mapping (from CURRENT_STATE digest + code sweep)

Conventions that bind this work: `ObservableObject` + `static let shared` singletons (NO `@Observable`), per-account UserDefaults keys, tokens only from root `DesignSystem.swift` + `Noum/Typography.swift` (Figtree display / Manrope text, all `relativeTo:` Dynamic Type), every haptic via `CoachHaptic`, `.buttonStyle(.pressable)`, no literal hex/magic spacing in views.

| V4.6 surface | Existing seam | Decision |
|---|---|---|
| Today hero | `Noum/HomeCoachCard.swift:362` (title :517, subtitle :527, CTA :427) inside `ContentView.cohesiveHomeCards` (:882); data = `RecommendationBiasEngine` blueprint exposure + `ForwardPlanStore.activePlan` + `HomeSignalGate` + `BigMomentStore.activeMoment` | Restyle `HomeCoachCard` into the V4.6 violet hero (gradient, one target, one reason, meta line, idle trace, white Start pill) + quiet "Adjust practice ›". Keep ids `home.coachCard.begin` etc. Keep conditional surfaces minimal below hero. NO new state owner — `CoachPlanSnapshot` does not exist and will not be created. |
| Recording | `Noum/TimedPracticeView.swift` phase machine :226 (`speaking` phase), audio level `SpeechRecognizerViewModel.audioLevel` :194 (30 Hz RMS), remaining time :1131, timing bands :190. No trace exists; `AppColor.voiceLive` unused | New `VoiceTraceView` family (idle/earned/live/settling + minis) in DesignSystem or own file; restyle speaking phase to V4.6 dark surface (REC chip, m:ss left, dominant prompt, cue, trace, I'm-done pill). Silence = presentation-only low-level window on `audioLevel` (no scoring impact). Final seconds = existing red band → amber clock + "Land the close". RM = static bars. |
| Processing | NONE — inline `await` in `stopSession()` :3463–3534 with dimmed button. Terminal vocab exists: `RecordingLifecycleState`, `FinalizedTranscript`, `RecordingCompletionGate`, `TranscriptionSessionError.finalizationTimedOut` | New `processing` presentation state on TimedPracticeView wrapping the SAME pipeline (no parallel machine): chip READING YOUR REP, headline, settling trace, cue, quiet text Cancel (hotspot 345×58). Cancel/timeout/failure → honest terminal states; log via `FlowEventLog`. |
| Review / Explore / Retry / Comparison | DONE in 97028234a: `RewriteSuggestionCard` (reveal :242, LCS :581), `TranscriptRetryPrompt.resolve` :234, `TranscriptRetryComparisonCard` :425, render `SummaryView:412` | Verify build+tests+visual only. Comparison card has no tour coverage (tour ends at retry setup) — add coverage if cheap, else document. |
| Updated Today | NO earned-arrival state exists. Verdict ledger written at `PracticeSupport.swift:11487` (`RecommendationOutcome.transcriptRetryComparison`); `homeProgressReceipt` (`ContentView.swift:967`) has the precedence/dismissal pattern | Hero variant: earned chip + revised headline/meta + earned trace + revised CTA, keyed off the latest un-acknowledged retry-comparison outcome; once-per-evidence-event via per-account seen-key, then collapse to compact signal. Extend `homeProgressReceipt` precedence, don't fork it. |
| Progress | Tab "Review" root `SessionHistoryView:241` (story :289, highlights :391, all-reps :418, disclosure :301). Trajectory currently only via Ask Noum (`TrajectoryView`). Evidence/plan rows live in Profile | Reshape SessionHistoryView's head into the V4.6 evidence-led block (eyebrow=active target, headline, subtitle, weekly trajectory from real comparable reps, 3 evidence rows incl. honest lapse, plan-review row from `ForwardPlanStore`). Keep All-reps/history below. Path stays reachable (Progress contains Path per contract). |
| Tab bar | Native 5-tab `TabView` (`AppShellView:191`), ids via UIKit bridge :336; ~15 UI tests assert ids | Slice 4: V4.6 floating capsule bar with 4 tabs Today/Practice/Progress/You (sun.max/waveform/chart.line.uptrend/person.crop.circle), Settings folds into You as pushed destination; preserve legacy accessibility ids on the new buttons where tests depend on them; update tests that assert the 5th tab. |
| Dark mode | App pinned `.preferredColorScheme(.light)` (`NoumApp.swift:245`); ALL AppColor static literals; recording surfaces force `.dark` locally | Slice 4: convert the semantic tokens used by loop surfaces to dynamic `Color(UIColor { trait })` per token contract (screen #FAF9F7→#17151C etc.), unpin root only after visual sweep proves no half-dark screens; immersive surfaces stay natively dark. `AccessibilityContrastTests` resolves `.light` explicitly — extend with dark-variant assertions. |
| Motion | `Animation` extension in DesignSystem :206; RM idioms: inline ternary or `updateWithMotion` | Add V4.6 named transitions as `Animation`/durations in DesignSystem; every use gated on `accessibilityReduceMotion` per RM sheet. |
| Tour/seeding | `ScreenshotTour.swift` (retry journey :834), `DevSeedData` profiles, launch args in `NoumApp.swift:107–211` | Extend tour with Today/Recording/Processing/Comparison/Progress captures per slice. |

Slice order: 2 = Today + Recording + Processing (screens inside existing shell) → 3 = Updated Today + Progress → 4 = states/dark/AX/capsule nav (navigation last, per mission).
