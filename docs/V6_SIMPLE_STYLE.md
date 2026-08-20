# Noum V6 "Simple" — house style

> **SUPERSEDED (2026-08-19).** This describes the glossy light system the client
> rejected. The current house style is [`V8_STICKER_BOLD.md`](V8_STICKER_BOLD.md).
> Kept for the reasoning behind the three-tier material system, the colour semantics
> and the coaching triad, all of which carried forward into V8.

Approved 2026-08-19. Reference point: Duolingo. This supersedes the V3/V4/V5 explorations
on the `ux-experiment` branch. Figma source: file `xgzPGM5mWf0ZmQkzC8a7GT`,
pages "Home V6 — Simple" and "V6 Simple — Whole App".

## The governing principle

**Radical simplicity.** Duolingo's home screen carries about eight words. Ours must feel
equally uncluttered. Roughly **15 visible words per screen** is the ceiling, tab bar excluded.

Noum's substance is evidence-led coaching, and that does not change — but evidence lives
**behind a tap**, not on the surface. The home screen shows *what to do*; the debrief shows
*what happened*. Earlier drafts failed because they put the coaching essay on the home screen.

Delete before you add. If a card exists to explain something, remove it and make the
object bigger instead.

## Materials — three tiers (V6.1)

The first cut applied the full 3D treatment to everything, and the review was blunt: it read as
*"a glossy mobile game"* rather than a premium coach. Effects are now **earned**. Classify every
object into one tier.

**Tier 1 — informational (flat).** Standard cards, list rows, containers, non-reward stat tiles,
section headers. `#FFFFFF` fill, `#1E2C50` @8% 1pt stroke, `#1E2C50` @5% y2 r8 shadow, radius 16–18.
No edge, no specular, no contact shadow, no glow. **This is the default** — most objects qualify.

**Tier 2 — interactive (lightly raised).** Buttons, selectable options, inactive path nodes.
Edge offset `+4pt` only, 2-stop gradient face, 2pt white stroke @90%, own-hue shadow @22% y4 r10,
subtle specular (white 20% → 0 over the top ~35%). No contact shadow.

**Tier 3 — moment (full treatment).** The single active object, rewards, pressure elements.
Edge `+6…8pt`, 3-stop gradient, 3pt white stroke, specular white 38% → 0, contact shadow,
coloured glow. **Hard limit: two Tier-3 objects per screen.**

## The signature: 3D pressed buttons (Tier 2 and 3)

Two shapes:

1. an **edge** — solid, darker, offset on Y, drawn first (behind)
2. a **face** — gradient, white stroke, plus a colour-matched drop shadow

Objects run large: path nodes and primary buttons 72–100pt, full-width options 64–76pt tall.
The edge is what makes them read as physical — never ship a Tier-2/3 face without one.

## Colour semantics (V6.1)

Colour carries meaning and nothing else. The first cut used orange for both pressure and
achievement, which made both meaningless.

| Meaning | Ramp | Edge | Used for |
|---|---|---|---|
| **Core practice** | `#8AC5FF → #4C93F0 → #1F53C4` | `#1D4FB8` | timed reps, primary actions, the main path |
| **Mastery** | `#A78BFA → #7C5CFF → #5B3FD6` | `#4A2FB0` | levels, skills, chapter completion |
| **Reward** | `#FEE08B → #F7A72E → #D9660F` | `#B96A12` | earned XP, milestones, streak — **earned things only** |
| **Pressure** | `#FFA26B → #FF7A3D → #E8462B` | `#C0331C` | live pressure mode **only** — red-forward, never achievement |
| Locked | `#E4EAF4` flat + inner shadow | `#C4CFDF` | not yet earned |
| Neutral | `#FFFFFF` | `#D6DEEC` | secondary controls |

A pressure-mode *result* is an achievement, so it uses **reward gold**. Only the live round uses
the pressure ramp.

## Coaching is the product (V6.1)

The review scored coaching depth 4/10 — *"feedback remains generic"*. Anywhere a result appears,
three beats, in order:

**Insight** (what happened, plainly) → **Evidence** (the measurement proving it) → **Next action**
(the single thing to do).

Improvement leads; raw counts support it. "2 fillers" is a number — **"43% fewer fillers"** with
*"2 this rep · 3.5 average"* beneath it is coaching. Coaching surfaces (Today, Coach, Rep complete)
may run to ~35 words; everything else stays near 15.

## Architecture — five destinations

Each tab has one job, and they must not blur:

| Tab | Job |
|---|---|
| **Today** | the daily hub — what to do right now, and why |
| **Path** | the long arc — chapters, named outcomes, what unlocks next |
| **Coach** | the relationship — current focus, observed patterns, ask a question |
| **Progress** | the evidence — consistency and performance, kept separate |
| **You** | identity — account, milestones, settings |

## Chrome

- **Ground** `#F7FAFF`, flat. No gradient washes, no blurred blooms except at a genuine moment.
- **Status bar** "9:41" Inter Semi Bold 15 `#151B2B` at (30, 20); island 118×34 r18 `#0B0C10` at (137, 11).
- **Home indicator** 130×5 r2.5 `#151B2B` @25% at (131.5, 838).
- **Tab bar** — solid white 393×86 at y766, stroke `#1E2C50` @7%. Four items at `cx = 49 + i·98`:
  26pt circle at cy29 (active = action gradient, inactive `#C3CDDE`), Nunito Bold 11 label at y48
  (active `#2E6BE0`, inactive `#8892A8`). Today · Path · Coach · You. Omit on immersive flow screens.
- **Stat bar** — three items at x20 / x150 / x285, y62. 24pt glyph + Nunito ExtraBold 16 value.
  Flame (gold gradient, ink `#ED7C1B`), hexagon gem (blue gradient, ink `#2E6BE0`),
  circle+star (violet gradient, ink `#7C5CFF`). Home-level screens only.
- **Banner** — edge 353×72 r18 `#1D4FB8` at (20, 110); face 353×72 r18 action gradient at (20, 104),
  shadow `#2E7CFF` @35% y6 r16. Eyebrow Nunito ExtraBold 11 white@75% tracking 1.2; title ExtraBold 20 white.
- **START bubble** — white 104×44 r14 over a `#D6DEEC` edge, label Nunito ExtraBold 17 `#2E7CFF`
  tracking 1, plus an 18×12 triangle tail. Attaches to the active node.
- **Full-width CTA** — 353×60 r18, face gradient over a matching edge, label ExtraBold 18 white.

## Type

Display and UI: **Nunito** ExtraBold / Bold. Body (rare): **Inter** Medium / Semi Bold.
Headlines 24–34pt. Micro-labels 10–11pt ExtraBold uppercase, tracking ~1.2.
Ink: `#151B2B` primary, `#2E6BE0` blue, `#ED7C1B` gold, `#8892A8` tertiary.

> In Figma, SF Pro and SF Pro Rounded lay out at zero width and disappear — the mocks use
> Nunito as the stand-in. **The iOS build should use SF Pro Rounded**, which is the intended face.

## Icons

Geometric primitives only — ellipse, rect, polygon, star, and 4–5pt white vector strokes with
round caps. No illustrations, no mascot, no emoji, no photography. (Consistent with the standing
brand rule; richness comes from SF Symbols, motion, colour, and shape.)

## Motion

Bouncy but bounded. Spring with overshoot then settle — never a linear fade.

| Beat | Motion |
|---|---|
| Screen entry | Objects pop in staggered ~110ms apart: scale 0.3 → 1.16 → 1.0 |
| Idle | Active node bobs ±5pt; START bubble bounces ±7pt; flame flickers 1.0 ↔ 1.12 |
| Press | Face translates down onto its edge (the edge is what makes a press feel real) |
| Seal | Squash to 0.9, overshoot 1.12, settle; gold ring scales in; check draws |
| Reward | XP chip rises and fades over ~1.1s |
| Unlock | Lock lifts and fades, face floods with colour, scale 0.86 → 1.2 → 1.0, sparkles burst |

Reduced Motion: no bobbing, no bursts; states cross-fade and haptics are retained.

## Sound

Synthesized, not sampled — no bundled audio assets, no licensing, consistent with the existing
`SoundscapeEngine` approach. Working kit generated with ffmpeg (`aevalsrc`), shipped as WAVs:

| Cue | Character |
|---|---|
| `pop` | node appears — pitch-swept blip, fast decay |
| `bubble` | START bubble appears — brighter, softer |
| `seal` | rep sealed — 170Hz thunk + C5/G5 body |
| `tick` | check lands — 1568Hz blip |
| `xp` | reward — A5 → C♯6 → E6 → A6 arpeggio |
| `unlock` | next node opens — C major triad plus shimmer |
| `chest` | chapter reward pulses — C6/E6 shimmer |

Every sound pairs with a haptic at the same frame. All cues respect the existing haptics setting.

## Copy

Short and warm. "Cleanest rep yet." — not "You have achieved your cleanest rep this week."
No emoji. Never the word *pressure* in journey copy (the composure drill is "Think on your feet").
No calendar-gated locks — a lock shows real progress toward opening. Never punish or shame a
miss; celebrate upward only, and only on genuinely measured improvement.
