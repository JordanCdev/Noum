# Figma Design Gate — Handoff

**Date:** 2026-07-24 · **File:** https://www.figma.com/design/srCgE5IP3rWoNMWtHo3AnI/
**Decision record:** `docs/FIGMA_GATE_DECISIONS.md` · **Component map:** `docs/FIGMA_SWIFTUI_COMPONENT_MAP.md` · **Resume log:** `FIGMA_PROGRESS.md`

## What's in the file now

- **00 Archive** — old audit board + the entire rejected previous visual layer (preserved, clearly separated).
- **01 Product journey and IA** — coaching-loop map, both nav hypotheses (4-tab vs Coach/Practice/You), task-test plan with pass thresholds.
- **02 Visual directions** — six gate variants (row 1) + the three ✅ APPROVED screens (row 2): Today/Review/Progress. Prototype-wired (Today→Review→Progress cycle).
- **03 Foundations** — 4 variable collections (Primitives / Theme Light+Dark / Dimensions / Motion Standard+Reduce), corrected to warm canvas + violet coach identity; 19 text styles (Nunito/Inter); 4 elevation styles.
- **04 Components** — 17 variable-bound components: atoms, evidence objects, the hero, five state components, tab bar.
- **05 Core coaching loop** — five required Review states + five onboarding screens, wired as the first-value prototype (Onboarding→Review→Retry comparison).
- **06 Relationship and progress** — three live-call identity directions (breathing geometry / aurora field / typographic presence, with state + Reduce Motion annotations) + honest-timeline paywall.
- **07 States and accessibility** — dark-mode Today, accessibility contract board (VoiceOver order, Dynamic Type rules, Reduce Motion map, contrast/targets), AX-size Review example.
- **08 Interactive prototype** — pointer to the two wired flows.
- **09 SwiftUI handoff** — mapping board.

## Approved direction in one paragraph

One violet gradient hero per app — Today's prescription, the coach's daily brief — with everything else open editorial on a warm canvas: violet eyebrow, big rounded ink headline, short violet rule, evidence directly on the page. Violet = coach voice and evidence. Blue = the one startable action. Green = qualified improvement only. Two label levels, one tertiary row per screen, cards only for evidence objects. Score never leads daily coaching.

## Not yet designed (honest gaps for the next run)

- Practice tab (prescribed + manual catalogue), recording/active-rep states, shorter/stretch adjustments as sheets.
- Ask Noum contextual entry/typed set (goal change, disputed feedback, memory correction, context management).
- Progress deep set: weekly plan review, Path-inside-Progress visual, evidence history, formal evaluation, real-moment prep/reflection.
- You set: memory inspector, preferences, privacy/retention controls, settings.
- Earned-progress arrival + collapsed signal motion comps; milestone moment.
- Dark mode for all screens (components are mode-ready; screens 02/05/06 are light-only except Dark Today).
- Live-call full state matrix (9 states × 3 directions — only identity + annotations exist).
- Dynamic Type variants beyond the AX example; VoiceOver annotation per remaining screen.

## FROZEN — 2026-07-24
The gate is frozen: approved frames locked except defects, components style+variable-bound, states/prototypes verified. Two tests remain before their locks (live-call direction, IA choice) — everything else is implementable now.

## How to resume

Read `FIGMA_PROGRESS.md` (node IDs + constraints — especially the SF-font trap and text-node recipe), then continue with the gaps above using page-04 components and the approved screens as the source of truth.
