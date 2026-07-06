# SPEC — the "Rep Report" surface (review artifact, NOT yet app code)

Status: **DRAFT for Jordan's design review.** Do not land as Swift without sign-off.
Owner of the composition decision: Jordan (lead UI/UX). Origin: iter-22 5-role
re-benchmark — the one genuinely-new competitive axis the 21 prior iterations
never touched (visual presentation). Rendered mockup accompanies this spec.

## Why this exists

Noum's analytics *insight* leads the market (the recurring-position read —
`RepEventTrendEngine` — is a stronger longitudinal signal than Speeko/Yoodli/Orai
ship). But it renders as a motion-free **text list** scattered across `SummaryView`
cards, and `ProfileView` draws its speech-pattern bars with a hand-rolled
`GeometryReader` that bypasses the app's own Swift Charts vocabulary
(`RatingHistoryChart`). The picture lags the insight. Yoodli's competitive edge is
a single cohesive, screenshot-able Analytics report; Noum has the better data and
the weaker frame.

**Goal:** compose the *already-existing* signals into ONE cohesive, share-worthy
Rep Report — inventing no new capability and touching no shared coaching state.

## What it composes (all already computed + persisted)

| Block | Source | Honesty rule (already enforced) |
|---|---|---|
| Rating trend | `RatingStore` / `RatingHistoryChart` | Only if `SpeakingRating.hasRatedEvidence`. |
| Recurring-position read (centrepiece) | `RepEventTrendEngine` | Self-hides below floors (3-occurrence, 0.6 dominance); names the earned denominator. |
| Positional timeline (3 thirds) | `RepTimelineCard` | Never finer than the model carries; self-hides on non-finding. |
| Filler / clutch | existing summary metrics | Weak evidence → softer copy. |
| Pace | existing summary metrics | — |
| Small-sample state | `SummaryAnalyticsEmptyState` | Renders only below `patternFloor` (iter-21). |

Nothing here is new analysis. This is a **layout / hierarchy** change only.

## Composition (top → bottom)

1. **Verdict hero** — the single vibrant gradient surface (`HeroGradient.verdict`,
   indigo→violet). Rating number (`Typography.statHero`, white-on-gradient) +
   one-line coach verdict + `HeroGlassChip`s for the two headline stats. Exactly
   one hero per screen — the existing rule.
2. **The recurring-position card** (centrepiece, calm white card) — the
   `RepEventTrend` readout as the lede, with the positional timeline
   (`RepTimelineCard`'s opening/middle/close thirds) directly beneath so the words
   and the picture agree. Markers reuse the shipped tokens: silence =
   `AppColor.brandBlue`, pace = `AppColor.caution`, fillers = `AppColor.textSecondary`.
3. **Trend strip** — `RatingHistoryChart` (real Swift Charts) at a compact height;
   the same vocabulary should replace `ProfileView`'s hand-rolled bars.
4. **Supporting stats row** — filler rate + pace as two quiet inner-surface tiles
   (`AppColor.innerSurface`), never competing with the hero.

## Tokens (single source of truth — reuse, invent nothing)

- Type: **Figtree** (display/rounded) for stats & titles, **Manrope** (body) for
  copy. Roles: `statHero` 52 / `bigStat` 28 / `cardTitle` 20 / `body` 15 /
  `caption` 13 / `micro` 10 (uppercase, tracking 0.8).
- Hero gradients: verdict `#3B6EF5→#6B4DF5→#8C3DF5`, coach `#2E7AF5→#3BA1FF→#17C7CF`,
  progress `#2E7AF5→#2B8F9C→#149E69`. Tinted shadow, never gray.
- Surfaces: card `white`, inner `#F7F7FA`, screen = systemGroupedBackground.
- Text: primary `#21262F`, secondary `#69737F`. Status: positive `#199966`,
  caution `#D4850F`, warning `#BD3833`.
- Radius `xl 28` for the hero, `large 24` for cards. Spacing rhythm `md 16` /
  `lg 20`; card gap `14`.

## Motion (restrained; reduced-motion safe by construction)

- Hero number counts up once on appear (respect `reduceMotion` → snap to final).
- Timeline markers fade/scale in staggered ≤ 300ms total; static under reduced
  motion. No looping, no parallax. Markers are position-honest, not decorative.

## Honesty invariants (load-bearing — carry over, do not weaken)

- Every block self-hides on weak/absent signal — the Rep Report must render
  *nothing but the hero* on a first quiet rep, falling through to
  `SummaryAnalyticsEmptyState`. A hollow report reads as a bug (iter-21's lesson).
- The visible recurring-position line must reuse the engine's own `readout`
  verbatim — the card can never assert a finding the coach prompt didn't
  (the `RepTimelineCopy` / `RepEventTrendCopy` contract).
- No score-as-readiness, no "replaces a coach" framing. `.forming` cap intact.
- One combined VoiceOver label per card; no per-marker chatter.

## Execution plan (connectors ready)

1. **Figma** (authenticated, Jordan's team): build the Rep Report frame in the
   `/figma-generate-design` flow from these tokens, as a review file — NOT wired to
   code. Two composition variants (hero-led vs timeline-led) for Jordan to pick.
2. Jordan reviews → picks the composition / rhythm.
3. Only then: a new `RepReportView.swift` composing the existing cards (no engine
   fork), gated behind the same `if let` self-hide pattern as its siblings, with
   tests locking the honesty invariants — same discipline as `RepTimelineCard`.

Canva is **not** the right tool here (marketing collateral, not product surface).
A Noum **brand kit** in Canva would only be worth setting up for store/marketing
assets, and would let `generate-design` stay on-palette automatically.

## Addendum — 2026-07-06 (scope correction + Figma review file)

**Scope correction (verified against code).** The "Why this exists" framing above is
slightly overbroad. `ProfileView` already renders **two real Swift Charts** — the rating
trend (`RatingHistoryChart`, `ProfileView.swift:2054`) and the progression charts
(`ProgressionChartsCard`, `ProfileView.swift:1710`). The **only** genuine hand-rolled
bypass is the Speech-Patterns filler bars (`ProfileView.swift:3020-3028`, a
`GeometryReader` + `Color.orange` fill). So the residual work is narrower than a
wholesale chart migration:

1. Replace the Speech-Patterns bars with the shipped Swift Charts vocabulary.
2. Compose the already-existing signals into the single Rep Report surface (this spec).

The Summary "Deep read" disclosure remains a flat text list — that is the real
composition gap this surface addresses.

**Figma review file (built this run).** A review file exists at
`https://www.figma.com/design/GKF8UITUcQv8ttEDgKkckP`
("Noum — Rep Report (review, 2 variants)"):

- **Variant A (hero-led): BUILT + screenshot-verified.** iPhone frame composing verdict
  hero (verdict gradient `#3B6EF5→#6B4DF5→#8C3DF5` + two `HeroGlassChip`s) → recurring-
  position centrepiece (readout lede + 3-third positional timeline with honest
  pace/pause/filler markers + legend) → rating trend strip (compact sparkline) →
  supporting stats tiles (filler rate + pace on `innerSurface`). All tokens per §Tokens
  above (Figtree/Manrope confirmed available in the file).
- **Variant B (timeline-led): NOT built this run** — the Figma MCP Starter-plan tool-call
  limit was reached mid-build (same cap iter-22 documented). Variant B should slim the
  hero into a compact band and promote the recurring-position timeline to the visual
  centrepiece. A follow-on session (or a Figma plan with more MCP calls) can add it.

Composition decision remains **Jordan's**. Nothing here is wired to code.
