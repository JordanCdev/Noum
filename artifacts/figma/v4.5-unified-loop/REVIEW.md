# V4.5 — Unified Coaching Loop (page 15, `212:497`)

**Date:** 2026-07-24 · **Base:** V4.4 sign-off (page 14, LOCKED, untouched) · **Brief:** deep-research report 14 + founder V4.5 prompt.
**Caveat applied to the brief:** report 14 never rendered V4.4 (it says so — it judged V4.2/V4.3 sheets). Its recommendations were diffed against what V4.4 actually contains before execution; already-shipped items were not redone, and copy that broke the honest-ledger chain was merged, not adopted verbatim (table below).

## Frames

| Frame | Node | Notes |
|---|---|---|
| V4.5 / 01 Today | `212:498` | copy + Adjust practice + Idle trace instance + Immersive CTA instance |
| V4.5 / 02 Recording — live | `212:558` | Live trace instance + CTA instance |
| V4.5 / 03 Processing | `212:616` | Settling trace instance; cancel now wired (was dead in V4.4) |
| V4.5 / 04 Review | `212:672` | TRY THIS · Try again with the same prompt · Explore this review · Phrase-shift instance |
| V4.5 / 05 Retry recording | `212:706` | Live trace + CTA instances |
| V4.5 / 06 Comparison | `218:714` | directive copy · first-try dimmed ×0.45 · Mini receded/emphasis instances · reflection quieted |
| V4.5 / 07 Updated Today | `212:809` | Earned trace instance · Start the shorter clock · Adjust practice |
| V4.5 / 08 Progress | `212:876` | Weekly trajectory instance · comma subtitle · −1 line · Review this target on Friday · +10px chart air |
| V4.5 state / Recording — silence | `212:990` | CTA instance; I'm-done now wired (was dead) |
| V4.5 state / Recording — final seconds | `212:1048` | CTA instance; wired (was dead) |
| V4.5 state / Review — Explore open | `219:724` | NEW state V4.4 never drew — Pace/Pauses/Hedges/Score panel (score stays behind disclosure per decision #10) |
| V4.5 AX3 / Today | `220:732` | type ×~1.6, reflowed hero, no truncation |
| V4.5 AX3 / Review | `222:745` | quote 30pt wraps, CTA 84pt wraps, recede preserved |
| V4.5 dark / Today · Review · Comparison · Updated · Progress | `224:753` `224:813` `224:847` `224:892` `224:959` | same deltas; conditional swaps only where pixel-identical |
| ContactSheet — Accessibility | `226:798` | AX3×2 + RM + AX5/VO pointers + contrast rules |
| ContactSheet — Motion | `226:932` | transformation pairs (std 600ms / RM instant) + timing map |

## New components (page 04)

- **Voice Trace family** `209:497–209:504` — Idle (hero), Earned (hero), Live, Settling, Phrase shift, Mini receded, Mini emphasis, Weekly trajectory. Geometry cloned 1:1 from V4.4 sign-off frames (not redrawn). Violet bars/ink labels bound to `Noum/Theme` `color/coach/accent` + `color/coaching/ink` (54 bars + 3 labels). Live/Settling stay raw `#9e70fa` (no matching token; natively-dark screens).
- **Button / Primary / Immersive** `211:511` + **/ Editorial** `211:527` — Default/Pressed/Disabled/Loading, one geometry (345×58, r30, Nunito Bold 17, Elevation/Card), context fills per decision #6. **Supersedes the stale blue `Button / Primary` `112:501`** (gate-era `#2e63de` — drift found during this pass).

## Copy decisions (directive vs V4.4 vs shipped)

| Where | V4.4 | Directive | Shipped | Why |
|---|---|---|---|---|
| Today meta | 4 min · 60s answer clock · review tomorrow | 4 min practice · 60-second answer · review tomorrow | **4 min practice · 60s answer clock · review tomorrow** | MERGED: "the clock" is a named object the Updated-Today CTA depends on ("Start the shorter clock"); dropping it breaks the ledger chain |
| Today/Updated tertiary | Adjust — shorter, harder, or ask why › | Adjust practice | **Adjust practice ›** @75% | directive; loses the what's-inside preview — revisit if adjust-sheet discovery drops |
| Review helper | ONE STEP | Try this | **TRY THIS** | directive (kept eyebrow case system) |
| Review CTA | Retry — same prompt | Try again with the same prompt | **Try again with the same prompt** | directive; verified wrapping at AX3 (84pt pill) |
| Review disclosure | Everything Noum noticed › | Explore this review | **Explore this review ›** | directive |
| Comparison success | ✓ First hold under pressure · 9 seconds earlier | Held under pressure · answer landed 9s earlier | **✓ Held under pressure · answer landed 9s earlier** | directive — NOTE: loses the "first" milestone truth; flag at founder review |
| Comparison plan | …Next rep keeps the target and shortens the clock. | Next: 3 min practice · 45-second answer | **…Next: 3 min practice · 45s answer clock.** | MERGED: keeps the clock (see Today meta) |
| Comparison reflection | One breath — how did that feel? › | "Optional reflection" (report only) | **kept copy, @70%** | directive only asked prominence; "Optional reflection" is dead label-speak |
| Progress subtitle | …this week — including one… | comma (report) | **…this week, including one…** | directive (−density) |
| Progress explanatory | Next, Noum tests the same target on a shorter clock. | remove one line | **REMOVED** | duplicated Updated-Today's message |
| Progress CTA row | Plan review · Friday › | Review this target on Friday | **Review this target on Friday ›** | directive |
| Review provenance | WHAT NOUM HEARD · VERIFIED 0:48 | (report: "Verified answer · 0:48") | **KEPT** | not in directive; provenance framing is the trust anchor (gate-era critic fix) |
| Today hero body | Today it meets pressure. | (report: "Today we test it under pressure.") | **KEPT** | not in directive; avoids inserting "we" into the user's moment |

## Prototype (12 links, zero dead — verified by reading back every reaction)

Today → Recording (SA 340) → Processing (SA 260) → auto AFTER_TIMEOUT 1.4s → Review (dissolve 600) → Retry recording (SA 260) → Comparison (SA 600) → Updated Today (SA 340) → Progress (tab, SA 340). Review ⇄ Explore-open (SA 260). **Fixed three dead links V4.4 shipped:** Processing cancel → Today; silence/final-seconds "I'm done" → Processing.

## Verification

Every refined frame screenshot-verified during the pass (Today, Recording, Comparison ×2, Progress, Updated, dark Today, dark Comparison, disclosure-open, AX3 ×2, both sheets). One regression caught and rebuilt from the locked V4.4 source (Comparison content wrapper deleted by a greedy selector — recloned + redone with safe walk-up selectors). One AX3 defect caught and fixed (Adjust wrapper vs text positioning). Exports are 1× node renders (393pt) — V4.4's were 2×; Figma is source of truth.

## Remaining weaknesses / not done

- V4.5 screens are still raw-hex visual builds outside the swapped instances — full text-style + variable rebinding (the real componentization) is still the next task, now easier: traces + CTAs are already instances.
- Dark frames don't use variable modes yet — dark Progress trajectory intentionally kept bespoke (labels were hand-flipped to bright; component rebind would shift pixels). Mode-flip QA belongs to the componentization pass.
- Mini receded grey `#5a6474` has no theme token; state-tint (pressed) is raw hex.
- AX3 drawn for Today + Review only; Comparison/Progress AX3 covered by rules on the accessibility sheet (matches V4.4's single-screen AX5 precedent).
- "First hold" milestone loss (directive copy) needs founder eyes.
- Human tests still open (live-call identity, 4-tab IA) — unchanged from V4.4.
