# Noum V8 "Sticker Bold" — house style

Approved 2026-08-19. **Supersedes `V6_SIMPLE_STYLE.md`**, which described the glossy light
system the client rejected ("idk if I like the glossy / glass look… too boring whilst trying to
look fun"). Figma: file `xgzPGM5mWf0ZmQkzC8a7GT`, page "V8 — Sticker Bold".

Motion and audio live in `Noum/Resources/Lottie/README.md`.

## How we got here

Ten anti-gloss material directions were explored side by side (page "V7 — 10 Material
Directions"). The client picked **D8 Sticker Sheet** first and **D1 Flat Bold** second. V8 is the
fusion: D8's die-cut collectible objects, D1's full-bleed colour fields and confidence.

## The governing constraint

> "should be clean, not much going on BUT still intentional and feels like the designer put in
> effort, and overall mostly just fun and dopamine inducing."

This is enforced numerically, not by taste:

- **Maximum 5 sticker objects per screen**, plus the tab bar. A sticker object is any distinct
  card, badge, pill, button or chip. Group related things into one sticker rather than three.
- **Maximum 15 visible words** on shell screens; ~30 on coaching surfaces where the words are
  real substance.
- No grids of small repeated items, no icon walls, no dense chip rows. Six of something becomes
  three, larger.

When a screen feels thin, the fix is **detail inside existing stickers** — never a sixth sticker.

## The material

**Ground.** Deep ink `#1A1726`, full bleed. Never white, never light grey, never a gradient.
Celebration screens instead flood the whole ground with one saturated colour — *the screen
changing colour is the reward*, which is why they need no confetti.

**Stickers.** Every object is die-cut:

- matte **solid** fill — a gradient anywhere is a spec violation
- **5pt cream `#FFF6E9` keyline**, `strokeAlign: INSIDE`
- a **stamped shadow**: `#0E0B18` at 55%, offset y+7, blur **0–4 only** — never a glow
- cornerRadius 22–30 on cards, 999 on pills
- rotation −3°…+3° on secondary objects so they read as hand-placed; the primary reading card
  stays at 0° so text stays comfortable

**Locked / not-yet inverts the rule:** ink fill, cream keyline at 35%, notched corner, **no
shadow** — an empty sticker slot rather than a dimmed object.

**Depth grading.** Shadow offset encodes importance: y+4 quiet, y+7 standard, y+10 hero.

## Palette

| Token | Hex | Meaning |
|---|---|---|
| ink | `#1A1726` | ground |
| deep | `#0E0B18` | stamped shadow |
| cream | `#FFF6E9` | keylines, primary text, neutral stickers |
| blue / blue-deep | `#3B6DF5` / `#2348C8` | **core practice** |
| purple / purple-deep | `#8B5CF6` / `#6D3FE0` | **mastery, chapters** |
| gold / gold-deep | `#FFC531` / `#E09A00` | **reward — earned things only** |
| pressure | `#FF5A3D` | **live pressure only**, never achievement |

A pressure-mode *result* is an achievement, so it uses gold. Only the live round uses pressure.

## Type

**Archivo** — Black for display and micro-labels, SemiBold for body. Fallback **Nunito**
(ExtraBold / Bold). **Never SF Pro** in Figma: it lays out at zero width and vanishes.

Display 34–56pt · body 14–15pt · micro-labels 10–11pt uppercase, letterSpacing 1.6–2.4.

Set the big line **directly on the colour field with no container**. That single move is what
made the shell feel authored rather than poured into a card — it was the core diagnosis behind
"the strongest moments felt authored; the app shell did not".

Every sticker should carry at least three deliberate type steps: eyebrow → value → caption at
60–75% opacity. A sticker with one line is what "lacks detail" looks like.

## Detail vocabulary

Craft that rewards a second look, without adding objects:

- **micro-geometry** — tick marks along a progress edge, notched corners on locked items, a small
  circular seal on earned ones, a 2pt inner keyline echoing the outer on the hero
- **ground texture** — a sparse dot field (2–3pt circles, cream at 4–7%) so the ink is not dead
  flat. Grain, not decoration; if you notice it as pattern, it is too strong
- **glyph vocabulary** — circle, square, diamond, triangle, ring, triple-bar. Geometry only,
  never detailed icons
- **state craft** — pressed, locked and empty states are designed, not dimmed

## Architecture

Five tabs, each with one job: **Today** (what to do now, and why) · **Path** (the long arc) ·
**Coach** (current focus and observed patterns) · **Progress** (consistency and performance,
kept separate) · **You** (identity, milestones, settings).

## Coaching is the product

Any result or prescription carries **insight → evidence → next action**, in that order.
Improvement leads; raw counts support it. "2 fillers" is a number — **"43% fewer fillers"** with
*"2 this rep · 3.5 average"* beneath it is coaching.

## Copy rules

Never the words *pressure*, *under fire*, *hold your ground* in journey copy — name what the user
**gains**. The composure drill is "Think on your feet"; the chapter ladder is
*Clear & steady · Think on your feet · Hold the room · Own the close*. This language keeps
creeping back in every generation — check it every pass.

Never punish or shame a miss; celebrate only measured improvement. No emoji, no mascot, no
illustration of people.

## Tokens

Figma variables are live and material-agnostic: `Noum/1 Primitives` (colour ramps),
`Noum/2 Semantic` (roles, with Light and Dark modes), `Noum/3 Scale` (spacing, radii, tier
depths, motion durations). Dark mode is a mode switch, not a redesign.
