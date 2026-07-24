# Noum — V4.4 FINAL HANDOFF

**Date:** 2026-07-24 · **Status: V4.4 signed off as the final design layer. Design phase closed.**
**Figma file:** https://www.figma.com/design/srCgE5IP3rWoNMWtHo3AnI/Noum-%E2%80%94-Product-Journey---Design-System
**Branch:** `ux-overhaul` · **HEAD at handoff:** `08e0bc2a544939aa1eb75b78805598849bb022b6` (ahead of origin by 2, NOT pushed)

---

## 1. Approved V4.4 — exact node IDs (page `191:497` "14 V4.4 — Founder Sign-off")

### The journey (wired end-to-end, 260/340/600ms timings + processing auto-advance)
| Screen | Node | Dark |
|---|---|---|
| 01 Today | `191:498` | `194:504` |
| 02 Recording | `191:557` | natively dark |
| 03 Processing | `191:615` | natively dark |
| 04 Review | `191:671` | `194:564` |
| 05 Retry recording | `191:705` | natively dark |
| 06 Retry result | `191:763` | `194:598` |
| 07 Updated Today | `191:808` | `194:643` |
| 08 Progress | `191:874` | `194:710` |

### Recording state family
idle `192:497` · silence `192:555` · final seconds `192:613` · offline-safe `192:671` · Reduce Motion `192:731`

### Sheets and proofs
Dark contact sheet `195:497` · Failure/offline sheet `195:932` · Reduce-Motion sheet `195:1165` · AX5 proof `181:497` (page 13) · VoiceOver reading-order board `181:506` (page 13) · Transformation motion pairs: standard `176:497→176:503` (600ms smart-animate), RM `176:509→176:515` (instant) on page 12.

### Supporting layers still in force (pages 01–09)
Variables: `Noum/Primitives` (57) · `Noum/Theme` (34, Light+Dark) · `Noum/Dimensions` (32) · `Noum/Motion` (10, Standard+Reduce Motion). 17 variable-bound components (page 04). Live-call identity directions + 10-state matrices (page 06: `115:*`, `131:497`, `132:497`, `132:554`). Onboarding 1–5, five Review states, six Today product states (page 05). Paywall timeline `119:497`. IA prototypes H1 (4-tab, approved screens) + H2 Coach/Practice/You (`134:*`, page 01).

## 2. Decisions locked (full record: docs/FIGMA_GATE_DECISIONS.md + layer REVIEW.md files)

1. **Three modes:** immersive coaching (Today hero, recording, processing, live call) · editorial evidence (Review, Result, Progress) · native utility (Practice, You).
2. **One hero per app** — the violet gradient belongs to Today's brief only.
3. **One motif** — the voice trace, evolving by context: live reactive (recording) → settled (processing) → transformation mark (Review) → before/after mini-traces (Result) → per-attempt clusters (Progress) → compact earned signal (Updated Today) → idle bookend (Today).
4. **Compressed loop** — Today → Recording → Processing → Review → Retry recording → Result → Updated Today. No Practice briefing, no Retry briefing; their content lives on Today + on-mic cues.
5. **Transformation integrity** — the one-step is the user's own words with the leading clause emphasized; Noum never inserts its phrasing ("nothing added, nothing lost"). Recede, never strikethrough.
6. **Color law** — violet = coach voice/evidence (single indigo/violet action family; CTA = one geometry, context-appropriate fill: white-on-violet immersive, violet-ink editorial); green = qualified improvement only; amber (`feedback/caution`) = honest lapse with non-color cue; dark mode = semantic mapping, never inversion (greens must be explicitly mapped — the grey bucket swallows g<0.5).
7. **Honest ledger** — every number reconciles across screens (60s clock → 0:48/0:39 → "9 seconds earlier" → 3-of-4); verified quotes verbatim everywhere; "Didn't hold under time pressure", never "SLIPPED".
8. **Tab bar** — SF-Symbol-convention glyphs (sun.max / waveform / chart.line.uptrend / person.crop.circle); production uses `Image(systemName:)`.
9. **Fonts** — Figma mocks Nunito/Inter (SF Pro renders broken metrics via plugin/server pipeline); device SF Pro Rounded via `.fontDesign(.rounded)` / SF Pro, mapped 1:1 by role.
10. Score demoted behind disclosure everywhere; cards only for bounded evidence; ≤2 eyebrows/screen; one tertiary row.

## 3. Rejected directions (all preserved in-file for history)

- **Pre-session audit-era layer** (page 00): flat equal-card stacks, navy/cyan coach identity, Figtree/Manrope, label soup.
- **Gate losers** (page 02): Review-B evidence-card stack, Progress-B second hero.
- **V1 approved-gate layer** (page 02 row 2) → superseded by the polish line.
- **V2/"V4" polish layer** (page 10) → superseded by V4.1–V4.4; its rejected ideas: "decide today:" insertion pill (integrity fault), waveform stamped beside titles, green status dots, raw "+2" counts.
- **V4.1** (page 11): mandatory Practice + Retry briefing steps (removed in V4.2), journey rail, arcs, custom mini tab glyphs, "SLIPPED" label.
- **V4.2** (page 12): full-sentence strikethrough treatment, triple-celebration Result, blue/violet CTA split.
- **V4.3** (page 13): superseded by V4.4's recording family, clustered trajectory, copy polish.

## 4. Remaining known weaknesses

- **Frames are raw-hex visual builds** — variable/style rebinding happens at componentization (first task below). The 17 page-04 components are bound; V4.4 screens are not yet.
- AX-size fallback for Progress clusters (drop under-cluster labels; legend carries days) is documented on the VO board, not drawn.
- Reduce-Motion evidence lives in `ContactSheet-ReduceMotion.png` + wired RM pairs — include it in any review packet explicitly.
- Practice tab is V4.2-era (`162:497`, page 11 lineage); Ask Noum set, You/memory/settings, Progress deep set remain at freeze-level (page 05–06) awaiting V4.4 restyle during implementation.
- Live-call identity direction (D1/D2/D3) and 4-tab vs 3-tab IA still need their human tests (plans + thresholds on page 01; ~$100–150 Maze/Lyssna or free with own recruits).
- Binding accessibility proof is on-device SwiftUI, not Figma.

## 5. Prototype + accessibility status

- **Prototype:** V4.4 loop fully wired (incl. Updated→Progress tab link and processing AFTER_TIMEOUT). Earlier layers' wiring intact (V4.2 page 12, V4.3 page 13, gate pages). Zero dead hotspots at last verification.
- **Accessibility:** AX5 proof frame, VoiceOver reading-order board (all 8 screens, traces decorative, receded/forward story in labels), Reduce-Motion variants (recording static + instant transformation), measured contrast fixes throughout (all named failures resolved; dark dim ≥4.5:1, greens mapped in dark).

## 6. Session record (this session, `36f666071..08e0bc2a5` — 22 commits, 176 files, +55.6k lines, docs/artifacts only)

- **Production Swift: untouched.** (One test-only ScreenshotTour method was added for the v2 evidence bundle, then reverted; preserved as `artifacts/research-bundles/…/test-harness-addition.diff`.)
- `docs/`: product contract installed + founder decisions + research refinements (`COACHING_SYSTEM_SPEC.md`, `PRODUCT_JOURNEY_DESIGN.md`, `PRODUCT_DECISION_LOG.md`, `FOUNDER_DECISION_SHEET_2026-07-23.md`, `DEEP_RESEARCH_BRIEF_2026-07-24.md`, `SPEC_rewrite_ladder_reliability.md`, `FIGMA_GATE_DECISIONS.md`, `FIGMA_SWIFTUI_COMPONENT_MAP.md`).
- `artifacts/figma/`: `FIGMA_PROGRESS.md` (resume log with node IDs + API traps), `FIGMA_HANDOFF.md`, layer records (`production-polish-v2/`, `v4.1/`, `v4.2/`, `v4.3-founder-final/`, `v4.4-founder-polish/` — each with REVIEW/JOURNEY.md + full exports), `gate-exports/`, `approved/`.
- `artifacts/research-bundles/`: v1 + v2 evidence bundles (34 + 17 deterministic screenshots at commit `f441dd019`).
- Uncommitted: only untracked `.screenshots/` autostop directories (concurrent scheduled agent's output — leave them).

## 7. Exact next task

**Componentize V4.4 and rebind to tokens** (Figma, fresh session): convert the eight `191:*` screens' repeated patterns onto the page-04 components, bind every fill/text to `Noum/Theme` + text styles (kills the recolor-recipe class of bugs — dark becomes a mode flip), update `docs/FIGMA_SWIFTUI_COMPONENT_MAP.md` statuses with V4.4 node IDs.
**Then SwiftUI Slice 1** (per component map + `docs/SPEC_rewrite_ladder_reliability.md`): extract `ReviewQuoteCard` from SessionHistoryView, retoken `transcriptUpgradeCard` to the recede treatment, add the coached-absence state (renders when `primaryWeakness == nil`), add the free-week ladder gate (1 free ladder/week after week one), direct retry into recording. Verify with the deterministic screenshot tour (`Noum-StoreKit` scheme).

## 8. Startup prompt for a fresh Claude session

```text
Read first, in order:
1. artifacts/figma/V4_4_FINAL_HANDOFF.md   (this file — node IDs, locked decisions, traps)
2. artifacts/figma/FIGMA_PROGRESS.md       (API constraints: SF-font trap, text-node recipe,
   clone-staleness trap, darken-recipe green bug, one setCurrentPageAsync per call)
3. docs/FIGMA_GATE_DECISIONS.md · docs/PRODUCT_DECISION_LOG.md · docs/FIGMA_SWIFTUI_COMPONENT_MAP.md
4. docs/SPEC_rewrite_ladder_reliability.md (for the SwiftUI slice)

Repo /Users/jordan/src/GitHub/Noum · branch ux-overhaul · Figma file
srCgE5IP3rWoNMWtHo3AnI (V4.4 = page 191:497; V4.4 frames are LOCKED except defects).

TASK: componentize V4.4 — rebind the eight 191:* screens to Noum/Theme variables
and text styles using the page-04 components; verify dark via mode flip, not
recolor; update the component map with V4.4 node IDs and statuses. Do NOT
create V5, do NOT redesign, do NOT start another critique pass. When
componentization is verified, proceed to SwiftUI Slice 1 exactly as defined in
handoff §7. Production code changes require the full CLAUDE.md response +
verification structure. Commit docs/Figma-artifact changes as you go; never
push without being asked. Watch for concurrent agents on this branch — stage
files explicitly.
```
