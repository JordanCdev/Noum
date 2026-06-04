# Coach Presence — Concept Directions

**Artifact:** `coach_presence_concepts.png` (3200×2080). Source: `coach_presence_concepts.html` (hand-authored SVG in Noum's real palette — `pro #8F47EB`, `proLight #D185FF`, `brandBlue #3378F5`, `modeIM #526EF0`).
**Purpose:** decide how the coach shows up *inside* the "Talk with Noum" conversation. The current chat reads IM-like partly because the existing presence (`NoumCharacter`) collapses to 28pt and vanishes as you scroll. This board spans brand-pure → most-literal.

| # | Direction | What it is | Brand stance | Build cost |
|---|-----------|-----------|--------------|-----------|
| 01 | **Living Orb** | Today's waveform orb, given a persistent breathing presence in-thread. No face. | ✅ On-brand (no illustration, no characters) | Low — extend `NoumCharacter` |
| 02 | **Orb + Face** | The orb gains blinking, you-tracking *eyes*; the waveform becomes a *mouth* that moves while speaking. | ⚠️ Stretches "no characters" — still no illustration | Low–medium — pure SwiftUI animation on `NoumCharacter` |
| 03 | **Geometric Coach** | An original abstract character (rounded body, expressive eyes, a waveform "heart"). | ⚠️⚠️ Relaxes "no characters" | Medium–high — new shape + mood/gesture animation system |
| 04 | **Rendered Avatar** | A designed coach figure with recognisable personality (calm bust). | ❌ Drops the brand rule | High — new illustrated asset set + rig/animation; tone risk |

## Recommendation

**02 — Orb + Face.** It directly answers "it needs a face" and "more literal than the orb," reads as *alive and attentive*, and is buildable in pure SwiftUI animation on the `NoumCharacter` that already exists (6 moods, audio-reactive, reduce-motion gated) — so it lands fast, costs no assets, and barely bends the brand rule (it never becomes an illustration).

- Pick **03** if you want an unmistakable *character* and are willing to relax "no characters" + invest in a small animation system.
- I'd caution against **04**: a rendered avatar risks Noum's "calm, intelligent, restrained" tone (VISION explicitly: not cartoony, not a mascot-led brand) and is the biggest lift.

## What happens after you pick

Static concepts only go so far for an *animated* presence. Once you choose a direction, I'll build a **live, animated SwiftUI prototype of just that presence inside the real chat** and screenshot it on the simulator — so you (and Codex/Gemini) judge the moving thing in context before I commit to the full Pillar-A redesign. The reply-reveal ("writing" motion) ships alongside whichever face we pick.
