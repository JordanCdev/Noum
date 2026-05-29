# Noum Achievement System — Design Reference

Use this document to design achievement badge icons in Canva. Each achievement belongs to a **track** (family) that shares a visual identity. Within each track, tiers progress from easy to rare.

---

## Visual System Overview

Every achievement icon is a **layered badge** with these components:

1. **Container shape** — unique per track (shield, hexagon, diamond, etc.)
2. **Gradient fill** — each track has a signature two-color gradient
3. **SF Symbol** — centered icon that changes with each tier
4. **Progress ring** — circular border that fills as the user progresses
5. **Glow treatment** — higher tiers within a track glow more intensely
6. **Locked state** — desaturated/dimmed version when not yet unlocked

### Icon Sizes
- Grid (profile page): 52pt
- Detail (modal): 88pt
- Celebration (unlock screen): 120pt

---

## Track 1: Practice Volume

**Theme:** Building a practice habit through raw rep count.
**Container shape:** Shield
**Color:** Green — `#387D61` to `#23663B` gradient
**Accent:** `#4DB880` to `#2E8C5A`

| Tier | ID | Title | Description | SF Symbol | Target |
|------|----|-------|-------------|-----------|--------|
| 0 | `volume_1` | **First Rep** | Complete your first practice session. | `figure.walk` | 1 session |
| 1 | `volume_5` | **Getting Reps In** | Complete 5 practice sessions. | `figure.run` | 5 sessions |
| 2 | `volume_10` | **Double Digits** | Complete 10 practice sessions. | `figure.run.circle.fill` | 10 sessions |
| 3 | `volume_25` | **Committed** | Complete 25 practice sessions. | `flame.fill` | 25 sessions |
| 4 | `volume_100` | **Centurion** | Complete 100 practice sessions. | `crown.fill` | 100 sessions |

---

## Track 2: Consistency

**Theme:** Showing up day after day. Streak-based milestones.
**Container shape:** Hexagon
**Color:** Orange — `#EB8C1F` to `#C66114` gradient
**Accent:** `#FFAE38` to `#EB7A1A`

| Tier | ID | Title | Description | SF Symbol | Target |
|------|----|-------|-------------|-----------|--------|
| 0 | `streak_3` | **Rhythm Builder** | Practice 3 days in a row. | `flame` | 3-day streak |
| 1 | `streak_7` | **Week Warrior** | Practice 7 days in a row. | `flame.fill` | 7-day streak |
| 2 | `streak_14` | **Fortnight Force** | Practice 14 days in a row. | `flame.circle` | 14-day streak |
| 3 | `streak_30` | **Iron Habit** | Practice 30 days in a row. | `flame.circle.fill` | 30-day streak |

---

## Track 3: Clarity

**Theme:** Clean, filler-free speaking. Zero "um", "uh", "like" etc.
**Container shape:** Diamond
**Color:** Blue — `#3894EB` to `#2466BF` gradient
**Accent:** `#59B3FF` to `#3380EB`

| Tier | ID | Title | Description | SF Symbol | Target |
|------|----|-------|-------------|-----------|--------|
| 0 | `clarity_1` | **Clean Run** | Complete a session with zero filler words. | `checkmark.seal` | 1 zero-filler session (12+ words) |
| 1 | `clarity_3` | **Squeaky Clean** | Complete 3 zero-filler sessions. | `checkmark.seal.fill` | 3 zero-filler sessions |
| 2 | `clarity_10` | **Silver Tongue** | Complete 10 zero-filler sessions. | `sparkle` | 10 zero-filler sessions |

---

## Track 4: Scores

**Theme:** High performance benchmarks.
**Container shape:** Octagon
**Color:** Gold/Amber — `#E69930` to `#BF7319` gradient
**Accent:** `#FFB840` to `#E08C1F`

| Tier | ID | Title | Description | SF Symbol | Target |
|------|----|-------|-------------|-----------|--------|
| 0 | `score_8` | **Sharp Session** | Score 8 or higher in a session. | `star` | 1 session scoring 8+/10 |
| 1 | `score_8x5` | **Consistent Excellence** | Score 8+ in five different sessions. | `star.fill` | 5 sessions scoring 8+/10 |
| 2 | `score_10` | **Perfect 10** | Score a perfect 10 in any session. | `10.circle.fill` | 1 session scoring 10/10 |

---

## Track 5: Endurance

**Theme:** Speaking at length. Sustaining delivery over time.
**Container shape:** Rounded Square
**Color:** Purple — `#7F5AD9` to `#5938B3` gradient
**Accent:** `#9E7AFF` to `#734DD9`

| Tier | ID | Title | Description | SF Symbol | Target |
|------|----|-------|-------------|-----------|--------|
| 0 | `endurance_120` | **Deep Dive** | Complete a session lasting 2+ minutes. | `timer` | 120s+ session |
| 1 | `endurance_300` | **Marathon Speaker** | Complete a session lasting 5+ minutes. | `figure.run` | 300s+ session |

---

## Track 6: Modes

**Theme:** Exploring and mastering different practice modes.
**Container shape:** Circle
**Color:** Purple/Violet — `#9452E6` to `#6B33B8` gradient
**Accent:** `#B873FF` to `#854DE6`

| Tier | ID | Title | Description | SF Symbol | Target |
|------|----|-------|-------------|-----------|--------|
| 0 | `modes_explorer` | **Mode Explorer** | Try every practice mode at least once. | `square.grid.2x2` | All 4 modes tried |
| 1 | `modes_pressure_60` | **Minute Man** | Survive 60+ seconds in a Pressure Drill. | `bolt.fill` | 60s in Sudden Death |
| 2 | `modes_pressure_180` | **Pressure Proof** | Survive 3+ minutes in a Pressure Drill. | `bolt.shield.fill` | 180s in Sudden Death |
| 3 | `modes_im_5` | **Connection Builder** | Complete 5 IM conversation sessions. | `bubble.left.and.bubble.right.fill` | 5 IM sessions |

---

## Track 7: Mastery

**Theme:** Rare, long-term accomplishments. The prestige tier.
**Container shape:** Medal
**Color:** Gold — `#E1B838` to `#B8851A` gradient
**Accent:** `#FFD952` to `#E6A626`

| Tier | ID | Title | Description | SF Symbol | Target |
|------|----|-------|-------------|-----------|--------|
| 0 | `mastery_rising` | **Rising Tide** | Your last 5 sessions average higher than your first 5. | `arrow.up.right` | Requires 10+ sessions |
| 1 | `mastery_1k_words` | **Thousand Words** | Speak a total of 1,000 words across all sessions. | `text.justify.leading` | 1,000 cumulative words |
| 2 | `mastery_10k_words` | **Ten Thousand Words** | Speak a total of 10,000 words across all sessions. | `book.fill` | 10,000 cumulative words |

---

## Design Notes for Canva

### Badge Construction
Each badge should feel like a premium game achievement — not flat, not overly skeuomorphic. Think Duolingo meets Apple Fitness.

- **Locked state:** Grayscale silhouette of the badge, low opacity. The shape is visible but the detail is muted.
- **In-progress state:** Badge shape is colored but slightly dimmed. A circular progress ring around the outside shows how close the user is.
- **Unlocked state:** Full color, subtle glow/shadow behind the badge. The icon is crisp and vibrant.

### Tier Progression Visual
Higher tiers within a track should feel more prestigious:
- Tier 0: Clean, simple badge
- Middle tiers: Slightly more detail, brighter glow
- Final tier: Maximum glow, gold trim or shimmer accent

### Color Palette Summary

| Track | Primary | Gradient Start | Gradient End |
|-------|---------|---------------|-------------|
| Volume | Green | `#38944D` | `#236642` |
| Consistency | Orange | `#EB8C24` | `#C66114` |
| Clarity | Blue | `#3894EB` | `#2466BF` |
| Scores | Amber | `#E69930` | `#BF7319` |
| Endurance | Purple | `#7F5AD9` | `#5938B3` |
| Modes | Violet | `#9452E6` | `#6B33B8` |
| Mastery | Gold | `#E1B838` | `#B8851A` |

### Container Shapes by Track
- **Shield** (Volume) — classic heraldic shield silhouette
- **Hexagon** (Consistency) — flat-top hexagon
- **Diamond** (Clarity) — rotated square / diamond shape
- **Octagon** (Scores) — regular octagon
- **Rounded Square** (Endurance) — squircle / rounded rectangle
- **Circle** (Modes) — standard circle
- **Medal** (Mastery) — medal/ribbon shape, the most ornate

### Practice Modes Referenced
- **Timed** — impromptu speaking with a prompt and countdown
- **Sudden Death (Pressure Drill)** — speak until you say a filler word, then the session ends
- **Ah-Counter** — focused on tracking filler words during freestyle speaking
- **IM Conversation** — simulated real-time conversation with an AI partner

---

## Full Achievement Count
- **7 tracks**, **24 total achievements**
- Volume: 5 tiers
- Consistency: 4 tiers
- Clarity: 3 tiers
- Scores: 3 tiers
- Endurance: 2 tiers
- Modes: 4 tiers
- Mastery: 3 tiers
