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

## Completed after gate decision
- Components page 04: 17 variable-bound components (atoms 112:497–112:511, evidence+hero 113:497–113:515, states+nav 114:497–114:516)
- 05: five Review states (116:497 reveal / 116:528 coached absence / 116:562 failed / 116:598 Pro row / 117:506 comparison-dominant) + onboarding 1–5 (118:506/527/548/564/583)
- 06: live-call identity directions D1 breathing 115:497, D2 aurora 115:522, D3 typographic 115:548 + paywall timeline 119:497
- 07: dark Today 120:497 + accessibility contract 123:497 + AX example 123:524
- 08: prototype wired (02: Today→Review→Progress cycle + tab links; 05: onboarding chain→reveal→comparison) + pointer note
- 09: handoff board 124:497 · docs: FIGMA_GATE_DECISIONS.md, FIGMA_SWIFTUI_COMPONENT_MAP.md, FIGMA_HANDOFF.md
- Exports: artifacts/figma/approved/ (today/review/progress/dark/paywall/livecall), rejected/, gate-exports/

## Remaining (next run — see FIGMA_HANDOFF.md "Not yet designed")
Practice tab + recording states · Ask Noum set · Progress deep set (weekly review, Path visual, evaluation, real moments) · You/memory/settings · dark mode for remaining screens (components are mode-ready) · live-call full state matrices · per-screen VO annotations beyond Review/Today

## Known constraints
- use_figma: SF fonts broken (above); Inter style is "Semi Bold" (space), Nunito is "SemiBold" (no space); one setCurrentPageAsync per call; text = load font → set fontName → characters → size; width-constrained text = textAutoResize HEIGHT + resize.

## CLOSED — gate frozen 2026-07-24
Closing run: stale boards archived (21:2, 40:2 → 00), fresh foundations `128:497`, scripted lint fixed (33 texts style-bound, +4 role styles, quiet button 45pt, 2 fills bound), live-call 10-state matrices ×3 (`131:497`,`132:497`,`132:554`), six Today product states (`133:*`), H2 wired prototype (`134:*`), 17 prototype links verified zero dead. Approved frames LOCKED. Remaining tests: live-call preference test, IA task test (H1 vs H2), Stark manual run in-editor.

## V2 Production polish (in flight, 2026-07-24)
Page `137:497` "10 Production polish V2". V1 refs locked: 137:498/541/572. V2 frames: Today `138:497` (edge-to-edge hero bleed, waveform motif, context strip, overlapping CTA, journey thread), Review `139:497` (word-level transformation: struck hedges + violet-pill additions), Progress `141:497` (comparable-attempts thread, honest slip, evidence-depth meter). Motion board `142:497`; wired transformation prototypes standard `143:497→143:508` (smart-animate 600ms) + RM `143:519→143:530` (instant). Exports in artifacts/figma/production-polish-v2/. Critique round 1 DONE (3 critics) → all fixes applied. Round 2 verifier: 18/20 pass → 2 blockers fixed (Progress tab glyphs, weekly-review row). Dark V2 Today `150:497`. All 12 exports + REVIEW.md in production-polish-v2/. V2 READY FOR FOUNDER REVIEW; V1 untouched. Remaining: V2 variable rebinding + componentization after acceptance, Review/Progress dark, state re-basing, live-call preference test, IA task test.

## V4.1 Production journey (2026-07-24)
Founder approved the polish layer ("V4"). Page `161:497` "11 V4.1 Production journey": complete wired journey Today `161:498` → Practice `162:497` (NEW) → Recording `163:497` (NEW, voice-reactive) → Review `161:568` → Retry `164:497` (NEW) → Comparison `164:515` (NEW) → Progress update `161:598` (earned-arrival banner). Darks: `161:670`/`166:672`/`166:702`. States: processing/low-evidence/rewrite-unavailable/offline `166:497–590`. Handoff annotations `167:497`. 2× exports + JOURNEY.md in artifacts/figma/v4.1/. Componentization + SwiftUI deferred until V4.1 journey approval.
