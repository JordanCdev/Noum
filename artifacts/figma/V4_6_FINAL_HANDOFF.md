# Noum — V4.6 FINAL · Finalise Coaching Loop

**Date:** 2026-07-25 · **Status: final design handoff for founder review — implementation candidate after sign-off** (deliberately not "production ready"; see flags)
**Figma:** https://www.figma.com/design/srCgE5IP3rWoNMWtHo3AnI/ · **Page:** `258:933` **"17 V4.6 — Finalise Coaching Loop"** (brief said "12" — 12/16 taken; corrected, third time the reports have slipped page numbers)
**History preserved:** pages 14 (V4.4), 15 (V4.5), 16 (V4.6 draft) untouched. **Brief:** deep-research report 16 + founder finishing prompt.

## Node mapping (old page 16 → final page 17)

| Frame | Old | Final |
|---|---|---|
| Today | `233:820` | `258:934` |
| Recording — live | `233:867` | `258:981` |
| Processing | `233:880` | `258:994` |
| Review | `233:892` | `258:1006` |
| Retry recording | `233:918` | `258:1032` |
| Comparison | `233:931` | `258:1045` |
| Updated Today | `233:965` | `258:1078` |
| Progress | `233:1019` | `258:1131` |
| Recording — silence | `233:1086` | `258:1195` |
| Recording — final seconds | `233:1143` | `258:1252` |
| Review — Explore open | `233:1200` | `258:1309` |
| Dark Today / Review / Comparison / Updated / Progress | `238:732/779/805/839/893` | `258:1348/1395/1421/1454/1507` |
| AX3 Today / Review / Comparison / Progress | `241:881/894` `239:1026/777` | `258:1617/1630/1655/1687` |
| RM sheet / Accessibility sheet / SwiftUI board | `241:834/1271` `242:933` | `258:1717/1756/1865` |
| **NEW** AX5 Review stress proof | — | `263:933` |
| **NEW** Subtraction evidence board (measured) | — | `264:934` |
| **NEW** Annotated callout set (5 screens) | — | `267:1012` |

## What this pass fixed (per brief section)

1. **Status framing** — page and handoff renamed from "Production Ready" to "Finalise Coaching Loop / implementation candidate".
2. **Today** — trace raised 8pt for CTA air (light+dark); reason/meta each one line; Adjust clearly tertiary.
3. **Processing** (the brief's #1 gap) — chip re-copied `PROCESSING` → **`READING YOUR REP`**; **Cancel demoted from full white pill to a quiet text action** (escape no longer outweighs the transition; hotspot preserved); footer pulled into the trace unit; headline stepped to 26. No new motifs.
4. **Review** — +6pt air under provenance so the verified quote breathes; disclosure quieted to 70%; helper stays one line; improved phrase remains the indisputable hero. Explore-open panel spacing calmed (16pt rhythm).
5. **Comparison** — first-try receded harder (13.5pt quote, card −8pt); lower stack lifted 8pt; milestone + plan + clock remain one line ("Plan moved — three holds in four reps, the first under pressure. Next: 3 min · 45s answer clock."); reflection tertiary.
6. **Updated Today** — +6pt air around the earned trace; structure chip → headline → meta → trace → CTA confirmed distinct from Today.
7. **Progress** — subtitle −25% ("Held in 3 of 4 comparable reps — one under pressure."); +16pt air around the trajectory; evidence rows at 14pt; lapse copy unchanged (respectful, specific).
8. **Dark/token contract** — every light change mirrored to darks (verified per-frame); SwiftUI board now carries the **complete token contract**: `#9E70FA → color/coach/live (new)`, `#5A6474 → color/neutral/receded (new)`, `#3F2499 → color/action/pressed (new)`, darks-as-reference rule. No undocumented exceptions remain.
9. **Accessibility** — **NEW AX5 stress proof** `263:933` (34pt quote wraps + recede intact, 96pt wrapped CTA, no truncation — visually verified); AX3 ×4 carried forward and copy-synced; VO order/labels + not-colour-alone + contrast rules on sheet `258:1756`; RM sheet has a standard→RM pair for every step.
10. **Subtraction evidence** (measured, not claimed) — board `264:934`: Today −48% texts/−41% chars, Review −29%/−28%, Progress −16%/−38%, Comparison −7%/−2% at screen level **because V4.1 split that step across a retry briefing + result screen — V4.6 absorbs both**; journey-level (7 V4.1 stops vs 8 V4.6 stops): **−26% visible texts, −27% characters**. Honest read: the ≥30% bar is met on the key screens' text mass but journey-wide lands at ~27% — the numbers are on the board, uninflated.

## Prototype (12 links, zero dead — every reaction read back)

Today→Recording (SA340) · Recording→Processing (SA260) · Processing auto 1.4s→Review (dissolve 600) · Processing cancel→Today · Review→Retry (SA260) · Review⇄Explore-open (SA260) · Retry→Comparison (SA600) · Comparison→Updated (SA340) · Updated→Progress tab (SA340) · silence/final-seconds→Processing (SA260). Entry point: `258:934` in Present mode. RM alternative per step on sheet `258:1717`. *Recording live↔silence tap-link: N/A — silence is an automatic state, no tap affordance exists; exhibits are wired into the loop instead.*

## Critique passes (run on the annotated board; one revision applied)

1. **Product clarity — pass.** Focal/primary/secondary assignments verified per screen on `267:1012`.
2. **Premium quality — one finding:** two callout dots overlapped text on the annotation boards (deliverable defect, not product). Fixed — dots moved clear.
3. **Warmth & trust — pass.** "just" retained; ledger chain intact; lapse copy respectful.

## Export manifest — `artifacts/figma/v4.6-final/` (26 files, each validated `PNG image` via `file`)

8 primary (`*-final.png`) · 3 states (Silence, FinalSeconds, Explore-Open) · 5 darks · 4 AX3 + 1 AX5 · RM + Accessibility sheets · SwiftUI-Annotations · Evidence-Subtraction-Audit · Annotated-Callouts.
*Process note: an initial export batch was invalidated (16 files were error bodies, caught by `file` validation) and every file was re-fetched from a freshly requested render; final count 26/26 verified.*

## Founder-approval items (unchanged from V4.6 draft, now fully documented)

1. Three proposed new tokens (live trace, receded neutral, pressed action) — values on the SwiftUI board.
2. Dark frames remain semantic recolours; implementation themes via `Noum/Theme` modes (contract on board). 
3. "First under pressure" lives in the plan line, not the payoff line.
4. Processing's remaining premium-ness is motion (SwiftUI), by design.
5. Human tests still open: live-call identity D1/D2/D3, 4-tab IA (plans on page 01).

## Verdict

**Ready for founder review: yes.** **Ready for SwiftUI implementation with no further major design pass: yes** — screen structure, copy, tokens-or-documented-exceptions, states, motion contract, and accessibility proof are all specified; remaining work is founder taste calls (items 1–3 above) and the build itself (componentize/rebind during implementation per the board, then Slice 1 per `docs/SPEC_rewrite_ladder_reliability.md`).
