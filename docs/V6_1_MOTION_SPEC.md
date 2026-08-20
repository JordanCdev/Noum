# Noum V6.1 — motion specification

Written 2026-08-19, ahead of implementation, at the design review's request: *"these mockups
depend heavily on motion… should be specified before implementation. Without those, the glossy
assets may feel static and decorative."*

Every entry below is implementation-ready: spring, duration, sound cue, haptic, and the
Reduced Motion fallback. Companion documents: `V6_SIMPLE_STYLE.md` (visual system).

## Global rules

**Springs.** Three, and only three.

| Name | SwiftUI | Use |
|---|---|---|
| `snap` | `.spring(response: 0.26, dampingFraction: 0.88)` | presses, chips, tab changes |
| `settle` | `.spring(response: 0.34, dampingFraction: 0.84)` | cards, entrances, layout changes |
| `pop` | `.spring(response: 0.40, dampingFraction: 0.62)` | rewards, unlocks, celebration only |

**Entrance grammar.** Objects arrive in reading order, ~100ms apart.
Tier 3 and Tier 2 objects *pop*: `scale 0.30 → 1.16 → 1.00`, opacity `0 → 1`, `offsetY +18 → 0`.
Tier 1 cards do **not** pop — they fade and rise only (`opacity 0 → 1`, `offsetY +14 → 0`, `settle`).
Popping a flat information card is a large part of what read as toy-like; keep the pop for things
that are earned or interactive.

**The press.** The signature. On touch-down the face translates down onto its edge
(`offsetY += edgeDepth * 0.7`, `snap`) and the shadow tightens; on release it springs back.
This is what makes the 3D treatment mean something rather than decorate.

**Contact shadows counter-phase.** When an object bobs up, its contact shadow shrinks
(`scale 1.0 → 0.88`) and softens (`opacity 1.0 → 0.55`). The shadow never moves with the object —
it stays on the ground. Getting this wrong is what makes float animations look pasted-on.

**Sound + haptic are one event.** Never fire a cue without its haptic partner, and never
schedule either off the animation clock — bind both to the same state change.

| Cue | Haptic | Fires on |
|---|---|---|
| `pop` | `.impact(.light)` | object entrance |
| `tap` | `.selection` | any press |
| `seal` | `.impact(.heavy)` | rep sealed / medal lands |
| `xp` | `.impact(.medium)` | reward count-up starts |
| `unlock` | `.notification(.success)` | node or milestone unlocks |
| `count` | `.impact(.rigid)` | each countdown tick |
| `whoosh` | — | screen transition |

**Reduced Motion.** No pops, no bobs, no bursts, no sweeps. Every state change becomes a
0.2s cross-fade. Count-ups jump to their final value. **Haptics and sound are retained** —
they carry the reward when motion cannot. Ambient loops stop entirely.

**Low Power Mode / background.** All ambient loops (bobs, breathes, shimmer, waveform idle)
suspend. One-shot beats still play.

---

## Per screen

### Today
- **Entry** — stat bar fades in; the hero rep card pops (`settle`); the week card fades+rises. Total ~600ms.
- **Idle** — hero card breathes `scale 1.0 ↔ 1.012` on a 2.4s cycle. Streak flame flickers `1.0 ↔ 1.12`, 0.7s, slightly irregular.
- **Primary** — START press → face onto edge + `tap`, then `whoosh` into the countdown.
- **Empty** — no rep yet: hero shows a calm invitation, no bob (nothing earned yet).
- **Reduced** — static card, no breathe, no flicker.

### Path
- **Entry** — nodes reveal top→bottom, 110ms apart, `pop`, each with a `pop` cue at 0.75 volume.
- **Idle** — the active node bobs ±5pt on 1.2s; its START bubble bounces ±7pt slightly out of phase (never synchronised — synchronised bobbing reads mechanical).
- **Unlock beat** — lock lifts and fades (`offsetY -26`, 180ms), face floods with colour, `scale 0.86 → 1.20 → 1.0` (`pop`), six sparkles burst radially and fade over 550ms. Cue `unlock` + `.notification(.success)`.
- **Reduced** — nodes cross-fade in together; unlock is a straight cross-fade with the haptic kept.

### Countdown
- **The count** — each numeral: `scale 1.35 → 1.0` with opacity `0 → 1` (`pop`), holds ~0.75s, then cross-fades out as the next arrives. Cue `count` + `.impact(.rigid)` per tick.
- **The dial** — the arc sweeps continuously and linearly across the full 3s. Linear, not eased — a countdown that eases lies about time.
- **Handoff** — on zero the node scales up past the frame and cross-fades into the recording screen.
- **Reduced** — numerals swap with no scale; the arc still sweeps (it is information, not decoration).

### Recording
- **Waveform** — the critical one. Each bar's `scaleY` is driven by **live mic amplitude**, not a canned loop: sample the level, map to `0.55…1.45`, smooth with a short attack / longer decay (attack ~40ms, decay ~140ms) so it snaps up and falls away naturally. Bars nearer the centre respond slightly more. On silence the whole trace settles to a low idle ripple rather than going flat — flat reads as broken.
- **Timer** — `contentTransition(.numericText())`, ticking once per second.
- **Progress bar** — advances continuously, linear.
- **Finish** — "I'm done" press → `tap`, waveform collapses to a line, `whoosh` into analysing.
- **Reduced** — waveform becomes a static silhouette that changes opacity with amplitude instead of height.

### Analysing
- **Idle** — inner bars pulse in a travelling wave (each bar phase-offset ~80ms); two concentric rings expand and fade on a 1.6s repeat.
- **Exit** — rings collapse inward, then `whoosh` into the result.
- **Honesty** — this state must persist until the real analysis returns. Never fake a duration; if it finishes early, hold the last ring cycle to completion so it doesn't snap.
- **Reduced** — a static mark with a slow opacity pulse.

### Rep complete
- **The drop** — the medal falls in: `offsetY -40 → 0` with `scale 0.2 → 1.2 → 1.0` (`pop`), landing at ~340ms. Cue `seal` + `.impact(.heavy)` **on landing**, not on launch. Contact shadow expands as it lands.
- **Sparkles** — six radiate outward from behind the medal over 550ms, staggered 45ms, then settle into a slow irregular twinkle.
- **The count-up** — the improvement figure ("43% fewer fillers") counts from 0 to its value over 900ms with an ease-out curve, so it decelerates into the number. Cue `xp` + `.impact(.medium)` at the start; a soft `tap` when it lands.
- **Evidence** — the coaching card fades+rises after the count-up finishes. It must never compete with the reward beat; it arrives once the celebration has peaked.
- **Next action** — the CTA rises last and breathes gently until pressed.
- **Shine** — a slow specular sweep crosses the medal once, 2.3s → 3.3s, clipped inside the medal. Park it outside the clip in its base transform or it sits visible at rest.
- **Reduced** — medal cross-fades in at final scale, number appears at final value, haptics retained.

### Coach
- **Entry** — focus card fades+rises, then pattern rows cascade 90ms apart (fade+rise, no pop — these are information).
- **Idle** — none. The coach screen is for reading; ambient motion here would undermine its credibility.
- **Reduced** — everything appears at once.

### Progress
- **Consistency marks** — the seven day marks fill left to right, 70ms apart, `snap`.
- **Performance chart** — the trend line draws left to right over 700ms (`trimPath 0 → 1`), then the endpoint dot pops.
- **Improvement figure** — counts up over 800ms, ease-out.
- **Reduced** — line appears complete, figures at final value.

### Milestones
- **Entry** — the grid cascades on a diagonal wave (stagger by `row + column`, ~70ms per step), `pop`.
- **Idle** — at most one badge twinkles at a time. Twenty animating badges is noise.
- **Unlock** — the badge scales `1 → 1.3 → 1.0`, its material floods from flat to gradient, sparkles burst, `unlock` + `.notification(.success)`.
- **Reduced** — grid fades in as one; unlock cross-fades.

### Pressure (Round live)
- **Entry** — fast: 80ms stagger, everything in under 400ms. Urgency is set by tempo.
- **Answer window** — the bar shrinks continuously and linearly. In the final 3 seconds it shifts toward the deep end of the pressure ramp and pulses at 2Hz. **No sound on this** — a ticking clock under someone trying to speak is hostile; the visual carries it.
- **Round survived** — the pip fills with a `pop`, cue `xp`, `.impact(.medium)`.
- **Round lost** — this must never punish. The pip settles to neutral (not red), the run ends calmly, no harsh buzzer, no shame haptic. `.impact(.soft)` only.
- **Reduced** — bar still shrinks (it is the mechanic), pulse becomes an opacity change.

### Run result
- **Number** — counts up 0 → 1,240 over 1.1s, ease-out, with a subtle scale overshoot as it lands. Cue `xp` at start, `seal` on landing.
- **Medal** — drops as in Rep complete (gold, since this is achievement rather than live pressure).
- **Reduced** — final value immediately, haptics kept.

### Friend flow
- **Ask** — preview card pops; the play control pulses invitingly `1.0 ↔ 1.06` on 1.6s until pressed.
- **Reply** — the quote card arrives with a gentle settle (no pop — a friend's message is not a reward); CTA rises after.
- **Reduced** — static, cross-fade only.

---

## Implementation notes

- Drive everything from state, not from timers. `withAnimation(.spring(...))` on a published
  state change, so the animation and the sound/haptic fire from one source of truth.
- Ambient loops belong to a single owner that can suspend them all on `scenePhase != .active`,
  Low Power Mode, or Reduce Motion.
- Count-ups animate a value, not a string: interpolate the number and format on each frame,
  with `contentTransition(.numericText())` for the digit roll.
- The waveform must bind to real amplitude. A canned animation on the recording screen is the
  single most detectable fake in the app — the user is speaking and can see it not respond.
