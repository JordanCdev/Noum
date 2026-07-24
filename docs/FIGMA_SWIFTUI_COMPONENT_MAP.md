# Figma ↔ SwiftUI Component Map

**Figma file:** https://www.figma.com/design/srCgE5IP3rWoNMWtHo3AnI/ · **System:** approved one-hero hybrid (see `FIGMA_GATE_DECISIONS.md`)
**Fonts:** mocks use Nunito/Inter (SF Pro renders broken metrics via Figma's plugin/server pipeline); device uses SF Pro Rounded (`.fontDesign(.rounded)`) / SF Pro. Map by role, not family.
**Variables:** components on page 04 are bound to `Noum / Theme` (Light/Dark modes). Dark = flip the mode, not new colors.

| Figma component | Node | SwiftUI | Variables used | States / variants | Accessibility | Status |
|---|---|---|---|---|---|---|
| Hero / Daily brief | 113:515 | `TodayHeroCard` (new; wraps existing `HeroGradient`) | coach/hero-start→end (gradient stops #5847D8→#7A45E0), text on-accent | default; chips wrap at AX | One VO group; label speaks eyebrow+headline+chips; no fixed height | to build |
| Button / Primary | 112:501 | `PrimaryCTA` (existing, retoken) | action/primary, text/on-accent | default/pressed (PressableButtonStyle) | 56pt target; button trait | restyle |
| Button / Quiet | 112:503 | `QuietButton` (new small) | background/surface, border/subtle, text/secondary | default/pressed | ≥44pt; real button, never inline text | to build |
| Chip / Plan | 112:505 | `PlanChip` | coaching/quiet-surface, coaching/ink | default | decorative unless tappable | to build |
| Row / Chevron (tertiary) | 112:507 | `ChevronRow` | coaching/quiet-surface, coaching/ink | default/pressed | one per screen; button trait | to build |
| Row / Provenance | 112:511 | `ProvenanceRow` | feedback/positive, text/secondary | default | ✓ is decorative; text carries meaning | to build |
| Label / Eyebrow | 112:497 | `SectionEyebrow` | coaching/ink | section intent, ≤2/screen | header trait where sectioning | to build |
| Label / Micro | 112:499 | `DataMicroLabel` | text/secondary | data annotation | caption2 minimum | to build |
| Evidence / Verified quote | 113:497 | `ReviewQuoteCard` (extract from SessionHistoryView) | coach/accent (bar), text/primary | with/without observation | One VO group: "What Noum heard, verified at 0:48: …" | extract |
| Evidence / One-step diff | 113:503 | `transcriptUpgradeCard` (existing) | background/inner, evidence/highlight | reveal / absence / failed / pro (see State comps) | VO speaks the changed lever explicitly | retoken |
| Trend / Bars | 113:506 | Swift Charts (existing usage) | coach/accent w/ opacity ramp | 8-rep default; text summary at AX3+ | AXChartDescriptor audio graph | retoken |
| State / Coached absence | 114:497 | new view in Review flow | background/inner | — | renders when `primaryWeakness == nil` (SPEC_rewrite_ladder_reliability fix 2) | to build |
| State / Generation failed | 114:500 | existing failure state, restyle | background/inner, coaching/* | retry pill | announces failure honestly | restyle |
| State / Pro row | 114:505 | new quiet upsell row | pro/quiet-surface, pro/text | — | shown outside free allowance (1 ladder/week) | to build |
| State / Loading | 114:509 | skeleton | background/inner | — | `.isBusy`? announce loading | to build |
| State / Empty | 114:513 | empty state | background/inner | — | — | to build |
| Navigation / Tab bar | 114:516 | existing capsule pill nav (rename tabs Today/Practice/Progress/You) | coaching/quiet-surface, coach/accent | active = shape+weight+fill | `.isSelected`; never colour-only | rename+retoken |
| Live call D1 breathing geometry | 115:497 | `LiveCoachCallView` orb replacement, flag-gated | dark canvas raw | idle/listen/speak per annotation | Reduce Motion: static ring | prototype |
| Live call D2 aurora field | 115:522 | ditto | — | drift/brighten/still | Reduce Motion: static gradient | prototype |
| Live call D3 typographic presence | 115:548 | ditto | — | breathe/keypoints type-on | Reduce Motion: static, instant keypoints | prototype |
| Paywall timeline | 119:497 | new `PaywallTimelineView` (post-first-retry trigger) | surface, coach accents | annual preselected | timeline rows read in order | to build |

**Added at freeze:** Today product states `133:497` first-session · `133:540` earned-arrival · `133:583` goal-changed · `133:626` low-capacity · `133:669` no-moment · `133:712` offline. Live-call state matrices `131:497` (D1) `132:497` (D2) `132:554` (D3). H2 IA prototype `134:497/134:530/134:546`. Foundations board `128:497`. New text styles: Typography/Eyebrow·Button·Chip·Row (components fully style-bound; diff text intentionally mixed for the highlight).

**Screens (page 02 approved / 05 / 06 / 07):** Today `109:497` · Review `110:497` · Progress `111:497` · Review states 1–5 `116:497/116:528/116:562/116:598/117:506` · Onboarding 1–5 `118:506/118:527/118:548/118:564/118:583` · Dark Today `120:497` · Paywall `119:497` · A11y contract `123:497`.

**Implementation order (per contract §17 slices):** Slice 1 = Review reveal + coached absence + retry (reuses most existing code) → Today hero → Progress. No new state owners; `CoachPlanSnapshot` feeds Today, existing session/rewrite stores feed Review.
