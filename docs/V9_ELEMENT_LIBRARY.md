# Noum element library — the four approved parts

Approved by Jordan 2026-08-21 from the V9 "Calm Surface, Loud Moments" round
(Figma page **V9 — Calm Surface, Loud Moments**, `170:2`).

These are **parts, not a style**. No single V9 direction was chosen. What was
chosen is four devices that earn their place, to be leveraged into the app as
the surfaces they belong to get rebuilt.

> **The governing rule: do not force these.** Each one has a real home and a
> real place where it would be decoration. Those boundaries are written into
> every section below and they are the point of this document. An element used
> where it has no job is exactly the "visual noise" the UI rules ban.

---

## 1. The count-up figure

*From Q Quiet · Rep complete (`173:38`). Also implemented in T Studio (`173:14`).*

A large measured figure that visibly **counts itself up and lands**.

**Construction — it is built, not faked.** Five text layers stacked at the
identical position inside a transparent counter frame: `11%` `24%` `36%` `41%`
`43%`. The four intermediates rest at opacity 0. Each carries an OPACITY track
with **HOLD easing** so it snaps on and off with no crossfade — the digits
*change* rather than dissolve, which is what makes it read as a counter rather
than an animation.

| Property | Value |
|---|---|
| Type | 148pt SemiBold, letter-spacing −4% |
| Ink | `#15171B` on paper `#FCFCFB` |
| Digit cuts (HOLD) | 0.30 → 0.46 → 0.60 → 0.71 → 0.80s — decelerating |
| Frame SCALE_XY | 0.84 → **1.03** @1.02s → 1.00 @1.46s |
| Caption | reveals only *after* the figure settles |

Two details do the work. The **decelerating cut spacing** (160/140/110/90ms)
imitates a real counter slowing into its value. The **3% overshoot** gives the
number a physical thump so it feels earned rather than presented.

T Studio's variant adds a shared `TRANSLATION_Y` across all four layers so the
number rises as it counts, and sets the `%` at 46pt against the 104pt figure so
the unit stays quiet. Both are worth keeping.

**Belongs on:** rep complete · run result · level up · a Progress headline ·
milestone unlock — anywhere a figure the user **just earned** arrives.

**Would be forced on:** Today, or any screen the user merely navigated to.
Nothing was just measured, so a count-up there is motion without a cause. It
also must sit behind the evidence floor — never count up a figure derived from
a sample too small to claim (see the coaching invariants).

---

## 2. The waveform trace

*From V Voice · Today (`173:21`) and · Rep complete (`173:24`).*

The user's own rep, drawn as a fine-stroked trace. **The most ownable asset in
the product** — no competitor can copy a UI built from your voice.

| Property | Value |
|---|---|
| Band | 333 × 120, axis hairline at mid-height |
| Strokes | 1.6pt wide, 5pt pitch — fine, never chunky bars |
| Un-emphasised | graphite `#55504A` (52 strokes across the opening) |
| Emphasised region | ivory `#F4F0E8` (14 strokes across the final 10s) |
| Axis | `#241F1A` · region divider 1pt full-height |
| Resolved / good | Signal Teal `#35C0A8` |

**The move worth stealing** is the rep-complete beat, because it is evidence
rather than celebration: the ragged close appears in graphite labelled
`USUALLY`, holds 0.6s so it reads as a comparison, then collapses vertically
into the axis (`SCALE_Y 1 → 0.18`, fading) while the new steady close rises out
of the same axis in teal (`SCALE_Y 0.26 → 1.18 → 1.0`). The label swaps in
place. **Chaos flattens, steadiness grows out of the flat line — one continuous
gesture.** The number only arrives afterwards, so the picture proves the claim
before any figure asserts it.

**Belongs on:** Today's evidence · live recording · rep complete · the
transcript/debrief · Progress (traces over time).

**Would be forced on:** Path, You, Milestones, settings. The voice is not the
subject there, and a decorative waveform is the oldest cliché in audio UI. Also:
the trace must be **real rendered data**. A pretty synthetic squiggle standing
in for evidence is fake-progress and is banned.

---

## 3. The Focus ground

*From F Focus (`173:2` / `173:3`). Jordan: "I like the background… could increase the gradient spread."*

A deep, quiet, cinematic ground where elements are defined by **luminance and
space** rather than borders. No keylines, no cards, no stamped shadows.

| Layer | Spec |
|---|---|
| Ground (Today) | linear `#0B0C11` → `#0E1017` @42% → `#05060A` |
| Ground (moment) | linear `#07080C` → `#090B10` @45% → `#04050A` — darker, so the bloom has somewhere to come from |
| Ambient glow | radial 620px, `#6B8CC7`@14% → `#4D669E`@5% @55% → `#1A243D`@0 |
| Action halo | radial 348px, `#C7DBFF`@34% → `#9EBAF0`@15% → `#708CCC`@5% → 0 |
| Reward bloom | radial 600px amber `#FAD494`@26% → `#E5B875`@11% → `#9E805C`@4% → 0, with a 276px warm-white core `#FFF7EB`@60% |

**Widening the spread, as requested.** Take the ambient glow to **820–900px**,
drop its peak alpha `0.14 → 0.10`, and push the mid stop `0.55 → 0.68`. That
spreads the falloff across more of the screen without raising peak luminance —
which is what stops a wider gradient turning into a visible disc or banding on
an OLED panel. Verify on device at low brightness; near-black gradients band
where a simulator looks clean.

**Belongs on:** the immersive lane only — countdown, recording, analysing, rep
complete, live coach call. The dark is a **mode signal**: it means *you are in
it now*.

**Would be forced on:** the everyday shell (Today, Path, Progress, You). Making
those dark makes the daily surface heavy, kills the light/dark contrast that
gives the immersive lane its meaning, and walks straight back into the
"confusing, not clean" verdict. Light shell, dark moment — the split is the
system.

---

## 4. The calibrated scale

*From T Studio · Today (`173:13`) and · Rep complete (`173:14`).*

A measurement shown **against its target** — an instrument readout rather than a
chart. Jordan: "these sort of infographics are cool."

| Part | Spec |
|---|---|
| Scale | 297pt wide, 0–8 fillers/min, 9 ticks |
| Baseline | 1pt `#D8D1C4` |
| Ticks | major 11pt / minor 7pt @50%, `#A59C8E` — **tick colour never used for text** |
| Target band | `#0F6F63` @50%, spanning 0–3 |
| Needle | 3 × 26pt `#161411` with a 7pt round cap |
| Readout | 13pt SemiBold, sits above the cap |
| Plate | 345 × 369 r24 `#FCFAF6`, shadow `rgba(89,77,51,0.07)` y8 r24 spread −4 |

**The landing is the whole pleasure.** On rep complete the scale draws in, a
grey ghost marker appears at the old average (3.5), then the teal needle appears
*on top of the ghost* — you are looking at where you were — and travels to the
new value with a genuinely damped settle: `TRANSLATION_X 83.25 → −6.5 → +2.6 →
−1.0 → 0` across 1.56–2.82s, overshooting and correcting **twice**, like a
physical meter. The readout is held at zero opacity until 2.26s so nothing is
unreadable mid-sweep. A brass delta bracket then marks the distance travelled.

**Belongs on:** Today's evidence · rep complete · Progress · anywhere with a
genuine target to measure against.

**Would be forced on:** any metric with no target band — the scale's entire
argument is *here is the line you are trying to get under*. Without one it is a
dial with nothing to say. Never invent a target to justify the graphic.

---

## How the four fit together

The app has two lanes, and the elements distribute across them:

| Lane | Ground | Elements at home |
|---|---|---|
| **Everyday shell** — Today, Path, Coach, Progress, You | light paper | waveform trace, calibrated scale |
| **Immersive moment** — countdown, recording, analysing, rep complete, call | Focus ground | Focus ground, count-up figure, waveform trace, calibrated scale |

The count-up and the Focus ground are **moment-only**. The trace and the scale
cross both lanes because they are evidence, and evidence belongs everywhere.

Path, Coach, Milestones and You should use **none of the four**. That restraint
is what keeps them from being decoration.

---

## Not carried forward

Recorded so they are not re-proposed: V8 sticker material (keylines, stamped
shadows, rotation, die-cut objects), V6.1 gloss (specular caps, glass panels,
3D edge plates), mascots, illustration, emoji. All rejected by the client.
