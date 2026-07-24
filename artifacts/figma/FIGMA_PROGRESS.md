# Figma Design Gate — Progress Log

**File:** https://www.figma.com/design/srCgE5IP3rWoNMWtHo3AnI/ (main, write target)
**Reference:** https://www.figma.com/design/GKF8UITUcQv8ttEDgKkckP/ (Rep Report, read-only)
**Run started:** 2026-07-24 · resumable — read this before repeating any work.

## Completed

### Pages reorganised (00–09)
00 Archive — audit + rejected explorations (old audit board at x0; rejected core-screens board x1700; states matrix x3400; prototype screens x5100+; handoff board x8000)
01 Product journey and IA · 02 Visual directions · 03 Foundations and variables · 04 Components · 05 Core coaching loop · 06 Relationship and progress · 07 States and accessibility · 08 Interactive prototype · 09 SwiftUI handoff

### Foundations (variable collections kept from previous run, values corrected)
- `Noum / Primitives` +11 new: warm canvases (light `#FAF9F7`, dark `#17151C`), warm dark surfaces, violet coach family (`coach #7C3AED`, `deep #6356F0`, `bright #9061F9`, `quiet #F3EFFB`, `quiet-dark #2B2440`, `ink #4C2BB8`), `blue/action-deep #2E63DE`
- `Noum / Theme` (Light/Dark) repointed: screen→warm canvas, coaching/ink+quiet-surface → violet family (was navy/cyan — root cause of the rejected look), action/primary → action-deep; +4 new: `color/coach/hero-start|hero-end|accent`, `color/evidence/highlight`
- `Noum / Dimensions` +3: spacing/xl 24, 2xl 32, 3xl 40
- **Text styles retargeted to Nunito (display) + Inter (body)** — CRITICAL FINDING: SF Pro fonts are locally-installed system fonts; the plugin API/server renderer measures them as garbage (any size → h≈15, w≈0). Nunito is the design-system README's sanctioned substitute. On device, SwiftUI uses SF Pro Rounded via `.rounded`; Figma mocks use Nunito 1:1.
- New styles: `Typography/Hero insight` (Nunito ExtraBold 26/32), `Typography/Quote` (Nunito Bold 22/30)
- Effect styles: Elevation/Card (black 6%, y8 b24), Selected (violet 10%), Recommendation (violet 16%), NEW Elevation/Hero (violet 25%, y16 b40 s-4)

### Design gate variants (page 02, all 393×852, light mode)
- Today A `97:497` edge-to-edge coach letter · Today B `101:497` focal violet hero
- Review A `102:497` transcript-first sheet · Review B `103:497` evidence-object cards
- Progress A `104:497` trajectory narrative · Progress B `105:497` focal trajectory hero
- Exports in `artifacts/figma/gate-exports/` + reference-rep-report.png + rejected-prev-home.png

### Page 01: IA board `107:497` — coaching loop pills, H1 four-tab vs H2 Coach/Practice/You, task-test plan with thresholds

## Gate DECIDED (see docs/FIGMA_GATE_DECISIONS.md, commit f6ecc6da7)
- 4 critics returned (SwiftUI critic hit session limit; feasibility assessed inline from codebase knowledge).
- **Approved: one-hero hybrid** — Today = B's violet hero (fixes applied), Review = A transcript-first, Progress = A trajectory.
- APPROVED screens built on page 02 row 2: Today `109:497`, Review `110:497`, Progress `111:497` (all critic fixes: blue CTA out of hero, 100% white on darkened gradient, ✓ not green dots, real adjustment buttons, one tertiary chevron row, WHAT NOUM HEARD, +2 reps this week, score inside evaluation disclosure).

## Remaining
- Aggregate critic verdicts → choose system → FIGMA_GATE_DECISIONS.md
- Apply winner fixes; componentize (page 04) with variable bindings
- Expand: 05 core loop (onboarding→retry incl. 5 Review states), 06 relationship (live-call 3 identity directions × states, Ask Noum set, paywall timeline, You/memory), 07 dark mode + Dynamic Type + VoiceOver + Reduce Motion, 08 prototype links, 09 handoff
- FIGMA_SWIFTUI_COMPONENT_MAP.md, FIGMA_HANDOFF.md, exports to approved/rejected dirs

## Known constraints
- use_figma: SF fonts broken (above); Inter style is "Semi Bold" (space), Nunito is "SemiBold" (no space); one setCurrentPageAsync per call; text = load font → set fontName → characters → size; width-constrained text = textAutoResize HEIGHT + resize.
