# Production Polish V2 — Review Record

**Date:** 2026-07-24 · **Page:** `137:497` "10 Production polish V2" · V1 frames untouched and locked (`109:497/110:497/111:497` on page 02; locked refs `137:498/541/572`).

## Node IDs

| Frame | ID |
|---|---|
| V2 Today (light) | `138:497` |
| V2 Today (dark) | `150:497` |
| V2 Review | `139:497` |
| V2 Progress | `141:497` |
| Motion spec board | `142:497` |
| Transformation prototype (standard, smart-animate 600ms) | `143:497` → `143:508` |
| Transformation prototype (Reduce Motion, instant) | `143:519` → `143:530` |
| Live-call directions (from freeze run) | D1 `115:497` · D2 `115:522` · D3 `115:548` |
| Live-call state matrices ×10 states each | `131:497` · `132:497` · `132:554` |

## What changed and why

**Today** — V1's "card floating on canvas + button" became an **edge-to-edge composition**: the violet hero bleeds through the status bar with faint composition arcs (kills the rectangular-stack read), the CTA straddles the hero seam for depth, the plan became a **journey thread** (2 ✓ nodes, glowing current, ringed next) instead of a text row, the upcoming moment folded into the hero's context strip *and* kept a tappable Prepare row anchored in the lower third, and the **waveform motif** got exactly two homes: hero presence mark + active tab glyph. Copy de-duplicated (eyebrow carries the focus, thread carries the count).

**Review** — now the signature moment: the verified quote shows the coaching *in the transcript itself* — hedges ("What I'd say is that", "probably") struck at a readable #6B7280; the one-step line is **the user's own sentence** with violet emphasis on what now leads. The round-1 coaching critic caught a genuine integrity fault here: V2 originally *inserted* "decide today:" while claiming "your words, one change" — the insertion was Noum's phrase, a second move. Cut. The caption is now literally true: "The decision now lands first — nothing added, nothing lost." Score is fully hidden behind "Noum's full notes ›" (coaching register, not "detailed evaluation").

**Progress** — the bar chart + "+2" dashboard became a **comparable-attempts narrative**: four day-rows on a violet thread, the Wednesday slip honestly marked ("WED · SLIPPED", burnt-amber ring, "Under time pressure the wind-up came back"), an **evidence-depth meter** ("building — needs a second pressure rep"), a static next-test line, and a single-purpose Weekly review row. Vocabulary unified on "wind-up" across surfaces.

## Critic findings (round 1 → fixed)

- Visual: hero+thread strongly better; motif was being stamped like a watermark (→ two homes only); Progress had App-Store-reject-grade right-edge truncations (→ restructured, gone); all three screens died at 65% height (→ anchored lower thirds); tab glyphs were four identical waveforms (→ distinct per-tab glyphs).
- Coaching: transformation integrity fault (→ insertion cut); "detailed evaluation" register (→ "Noum's full notes"); Progress subhead contradicted its own timeline (→ "including today's first under pressure"); three words for one behaviour (→ "wind-up").
- Accessibility (measured): "Why this rep?" 3.97:1 in-hero (→ moved to canvas as 44pt links); future-dot ring 1.87:1 (→ violet ring 5.4:1); struck text 2.52:1 (→ 4.83:1); amber 2.28:1 (→ #B45309 + 3pt ring + visible SLIPPED label); adjustment chips 42pt borderless (→ 44pt + hairline). Status bar verified safe on the gradient (6.31:1) — no scrim needed.

## Round 2 verification

18/20 checklist items passed; 2 failures fixed and re-exported: Progress tab bar got the distinct glyphs (the fix had only landed on Today), weekly-review row made single-purpose with correct label/spacer/chevron order. Link-row left-edge nit aligned.

## Rejected ideas

- "decide today:" insertion pill (integrity fault — and cutting it simplified the SwiftUI build from a custom TextRenderer pill to a styled AttributedString range).
- Waveform stamps beside every page title (watermark effect).
- Green status dots, raw "+2" counts, rising-bars-without-story.
- Amber as unsanctioned color → **canonized**: `color/feedback/caution` = honest-lapse marker, non-color cue (hollow ring + SLIPPED label) mandatory.

## Remaining weaknesses (honest)

1. Review's lower half is airy (~250pt under the footer links) — acceptable as a sheet, but real transcripts of varying length must prove the layout.
2. V2 frames use raw hex + direct fonts (visual-first build); rebinding to variables/styles happens at V2 componentization after founder acceptance.
3. Dark mode exists for Today only in V2; Review/Progress dark pending acceptance (recolor recipe proven).
4. The six product states + five Review states still ride the V1 base; they need re-basing onto V2 once accepted.
5. Live-call winner still untested (preference test), IA still untested (H1 vs H2 task test).
6. Motion is specified + two wired prototypes; the remaining five moments are spec-only until SwiftUI.

## Verdict

**Ready for founder review** — both critique-and-revision passes complete, all round-2 blockers fixed, improvements visible in `before-after-contact-sheet.png`.
