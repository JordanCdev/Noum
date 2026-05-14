# Noum Motivation & Reward System Design

**Date:** 2026-04-14
**Status:** Production design — implementation guide

---

## 1. Motivation System Strategy

### Core Philosophy

The app is a **serious speaking coach**, not a game. The emotional layer exists to:
- Make progress **felt**, not just measured
- Turn effort into visible momentum
- Make the gap between "where I am" and "where I want to be" feel **closeable**
- Reward the act of practicing, not just performing well

### Five Principles

1. **Reward the work, not just the outcome.** Completing a session is a win. Showing up again is a win. Reducing fillers by 1 is a win.
2. **Show trajectory, not snapshots.** A single 5/10 score is discouraging. A 5/10 that was 3/10 last week is encouraging. Always frame within trajectory.
3. **Escalate celebration proportionally.** A subtle glow for a stat improvement. A full-screen moment for a level-up. Never oversell small things, never undersell big things.
4. **Silence is also feedback.** Not every action needs a reward. The absence of celebration is a signal to keep going — not a punishment.
5. **Trust the user's intelligence.** No fake praise. No "Great job!" for a bad session. The app earns trust by being honest and specific.

---

## 2. Reward Hierarchy

### Tier 1: Micro-wins (subtle, ambient)
- Stat improvement detected (fewer fillers, better pace)
- A "developing" skill held steady
- Completed a drill (regardless of success)
- Returned after absence
- Stayed within target duration range

**Treatment:** Inline text acknowledgment + optional light haptic. No overlay, no animation beyond the stat display itself.

### Tier 2: Medium wins (visible, satisfying)
- Score increased vs recent baseline
- A skill area improved a level (weak → developing)
- Drill completed successfully (met criteria)
- Drill streak reached (3+ successful in a row)
- Zero-filler session achieved
- Session streak milestone (3, 7 days)

**Treatment:** Animated stat change + colored accent + haptic pulse. May include a brief badge or inline celebration element. No overlay.

### Tier 3: Major wins (full celebration)
- Level-up (XP threshold crossed)
- Personal best score in a mode
- Skill reached "strong" level
- 14-day or 30-day session streak
- A recurring issue marked "resolved" by trend analysis
- First session ever completed

**Treatment:** Full-screen intermediary celebration with phased animation, particles, haptic sequence, and contextual copy. Interrupts the flow briefly.

### What is NOT rewarded
- Simply opening the app
- Partial sessions (started but didn't complete)
- High score without improvement (user already performs at this level)
- Drill abandoned mid-way

---

## 3. Motion Design System

### Animation Vocabulary

| Category | Timing | Spring | Purpose |
|----------|--------|--------|---------|
| **Micro-interaction** | 0.15-0.26s | snappySpring | Button presses, toggles, selections. Instantaneous responsiveness. |
| **Progress update** | 0.35-0.5s | standardSpring | Score reveal, stat change, bar fill. Something changed and it matters. |
| **Achievement moment** | 0.4-0.7s | bouncySpring | Badge appearance, streak badge, skill level badge. Brief delight. |
| **Celebration** | 0.6-1.2s | custom phased | Level-up, personal best, major milestone. Full emotional arc. |
| **Transition** | 0.3-0.4s | standardSpring | View push/pop, sheet present, card expand. Navigation clarity. |

### Where Motion Should Be Used

1. **Score reveal on summary** — Number counts up from 0 to final value over 0.8s. This is the single most important animation in the app. It creates anticipation.

2. **XP bar fill** — Animates from previous XP to new XP. If it crosses a level boundary, the bar fills completely, resets to 0, and starts filling again. Level-up detected during this animation triggers the celebration.

3. **Stat delta badges** — When a stat improved vs baseline, the delta ("+2" or "−3 fillers") should scale in with bouncySpring after a 0.3s delay from the parent stat appearing.

4. **Drill completion ring** — The DrillSuccessRing already fills nicely. The checkmark should have a slight overshoot (damping: 0.5) to feel earned.

5. **Coach note card appearance** — Slides in from bottom with 0.15s stagger between momentum and leverage lines. Creates a reading rhythm.

6. **Trend arrows** — Should animate direction change only when the direction actually changed since last view. Static if unchanged.

7. **Skill level bar segments** — When a segment fills, use a 0.3s easeOut fill animation followed by a brief 1.05x scale pulse on the filled segment only.

### Where Motion Should NOT Be Used

- **Body text** — Never animate text content appearing. It slows reading.
- **Navigation chrome** — Back buttons, titles, toolbars stay static.
- **Repeated views in lists** — Don't stagger-animate every row in a list. First appearance only.
- **Error states** — Errors should appear immediately and clearly. No animation.
- **During active speech recording** — The UI should be calm and minimal during practice. Only the progress ring moves.

### Motion Rules

1. Never animate more than 2 things simultaneously in the same viewport
2. Delay secondary animations 0.15-0.3s after primary ones
3. Use spring for organic motion, easeOut for mechanical progress (bars, rings)
4. Don't repeat celebratory animations on re-visit (track with shown state)
5. Respect reduced motion — all animations should gracefully degrade

---

## 4. Haptics Map

### Event → Haptic Mapping

| Event | Pattern | Generator | Intensity | Rationale |
|-------|---------|-----------|-----------|-----------|
| Button tap | Single light | Selection | — | Standard iOS feel |
| Drill countdown beat | Single rigid | Impact(rigid) | 0.7 | Rhythmic, anticipatory |
| Drill start | Single medium | Impact(medium) | 1.0 | Clear "go" signal |
| Drill success | Success notification | Notification(.success) | — | Built-in 3-pulse satisfying |
| Drill incomplete | Single soft | Impact(soft) | 0.5 | Gentle acknowledgment |
| Score reveal | Single light | Impact(light) | 0.6 | Punctuates the number landing |
| Stat improvement detected | Single soft | Impact(soft) | 0.4 | Subtle positive |
| XP earned | Single light | Impact(light) | 0.5 | Quiet accumulation feel |
| Level-up trigger | 3-tap ascending | Impact(heavy) | 0.6→0.8→1.0 | Escalating triumph |
| Personal best | Success + delayed heavy | Notification(.success) + Impact(heavy) | — | Double-hit celebration |
| Streak milestone | Double medium | Impact(medium) ×2 | 0.8 | Rhythmic achievement |
| Skill level-up | 2-tap medium | Impact(medium) ×2 | 0.6→0.9 | Quiet but noticed |
| Trend resolved | Single soft | Impact(soft) | 0.6 | Gentle completion |
| Coach note appear | None | — | — | Reading moment, no interruption |
| Navigation | None | — | — | Standard, no haptic needed |

### Haptic Rules

1. **Maximum 3 haptic events within any 2-second window.** Beyond this causes fatigue.
2. **Never haptic during speech recording.** The phone is likely on a surface or in pocket; vibrations could be audible.
3. **Haptics follow visual, never lead.** The user sees the change, then feels confirmation.
4. **No haptic for negative feedback.** Corrections are visual/textual only.
5. **Respect system settings.** All behind `#if canImport(UIKit)` guards.

---

## 5. Reinforcement Copy Framework

### The Three-Part Pattern (already in CoachNote)

1. **Momentum** — What's getting stronger. Always leads. Always specific.
2. **Leverage** — What's currently the biggest opportunity. Honest, never harsh.
3. **Next Step** — One concrete action. Short, actionable.

### Copy Tone Rules by Scenario

| Scenario | Tone | Example |
|----------|------|---------|
| User improved significantly | Specific acknowledgment | "Your filler count dropped from 8 to 3 — that's a meaningful shift." |
| User improved slightly | Trajectory framing | "Trending in the right direction. Two sessions ago this was at 6." |
| User performed well | Quiet confidence | "Strong session. Pace was controlled, structure was clear." |
| User performed poorly | Forward-looking | "Tough one. Your opening was solid — build from there next time." |
| User fixed a recurring issue | Recognition without excess | "Fillers resolved. This hasn't been a problem for your last 3 sessions." |
| User stagnating | Challenge framing | "Your pace has been steady at 170+ WPM for a while. Time to push on that." |
| User declining on a skill | Direct but not punishing | "Structure has been slipping. The Three-Part Framework drill targets this directly." |
| First session | Orientation | "Good first rep. The app learns your patterns over time — it gets smarter the more you use it." |

### Words That Build Trust

- "shifted", "trending", "consistent", "tightened", "loosened"
- "this session", "compared to your baseline", "over your last 5 sessions"
- "targets", "opportunity", "builds on"

### Words to Avoid

- "amazing", "awesome", "incredible", "perfect" (hyperbole erodes trust)
- "you failed", "you need to", "you should" (prescriptive/judgmental)
- "don't worry", "it's okay" (patronizing)
- "just", "simply" (minimizing effort)

---

## 6. UI Surface Recommendations

### Immediate Surfaces (shown at moment of event)

| Surface | Events | Treatment |
|---------|--------|-----------|
| **Post-session summary** | Score, XP, milestones, coach note, drill rec | Primary reward surface. Score reveal → stat pills → coach note → drill card. Staggered appearance. |
| **Drill result screen** | Success/progress, streak, XP | Compact celebration. Icon + one-line feedback + XP. Fast scan. |
| **Level-up screen** | Level crossing | Full-screen intermediary. Particles, phased reveal, haptic sequence. Already built. |
| **Personal best screen** | New high score in mode | Full-screen intermediary. Already built. |

### Ambient Surfaces (always visible, updated passively)

| Surface | What it shows | Treatment |
|---------|--------------|-----------|
| **Home hero subtitle** | Dynamic contextual message | Streak, trend direction, last session callback. Rotates based on priority. |
| **XP progress bar** | Progress to next level | Always visible in summary. Subtle shimmer during fill. |
| **Skill progress card** | Per-skill trend + level | Expandable in summary. Sorted by priority (weakest first). Direction badges. |

### Long-term Progression Surfaces (visited on demand)

| Surface | What it shows | Treatment |
|---------|--------------|-----------|
| **Session history** | Past sessions with scores and deltas | Score trend line. Per-session expandable details. |
| **Journey view** | All-time stats, milestones reached, skill radar | Big-picture view. Total sessions, total XP, level progress, skill areas. |

---

## 7. Skill Progress Visualization

### Design Approach

Show **direction and level**, not raw numbers. Users care about "am I getting better?" not "what was my exact WPM delta."

### Per-Skill Card Design

```
┌──────────────────────────────────────────┐
│ 🎯 Filler Reduction        ↗ Improving  │
│ ████████░░░░  Developing                 │
│ 3 sessions improving · 🔥 4 drill streak │
└──────────────────────────────────────────┘
```

Components:
1. **Skill icon + name** — Fixed, instantly recognizable
2. **Direction badge** — Improving (green), Slipping (amber), New (red), Resolved (green check), Stable (grey)
3. **Level bar** — 4 segments: weak (1), developing (2), solid (3), strong (4). Filled segments use skill tint color.
4. **Context line** — "3 sessions improving", "stable for 5 sessions", etc. Human-readable trend window.
5. **Streak badge** — Only shown if ≥2 successful drills in this skill area.

### Skill Radar View (Journey/Dashboard)

A radar/spider chart showing 5-6 key dimensions. Not for the summary screen — this belongs on a dedicated progress page. Shows current vs. 10-sessions-ago overlay for trajectory.

### What NOT to Show

- Raw WPM numbers (meaningless to most users)
- Exact filler counts over time (depressing graph)
- Percentile rankings (competitive pressure, wrong for self-improvement)
- Daily granularity (noise, not signal)

---

## 8. Drill Completion Payoff

### Flow: Drill Complete → Result → Next Action

1. **Drill ends** (timer or manual stop)
2. **Brief pause** (0.3s) — builds micro-anticipation
3. **Result icon scales in** — Checkmark (success) or refresh arrow (keep going). bouncySpring.
4. **One-line verdict** — Skill-specific, metric-aware. "Zero fillers — clean run." or "142 WPM — right in the zone."
5. **Streak badge** — If ≥2 and succeeded, flame badge appears with 0.2s delay
6. **XP display** — "+50 XP" scales in with 0.5s delay. Uses skill tint color.
7. **Quick stats** — Duration, words, fillers. Static, no animation. Reference data.
8. **Primary CTA** — "Done" returns to summary. "Try Another Drill" selects fresh variation.
9. **Haptic** — drillSuccess() for success, drillIncomplete() for keep-going.

### Encouraging Retry Without Pressure

The "Try Another Drill" button should:
- Use secondary styling (not primary CTA color)
- Include subtle copy: "Try Another Drill" not "Try Again" (implies the attempt was a drill, not a failure)
- On the result screen, never say "failed" — say "keep going" or "getting closer"

### Skill-Specific Feedback Lines

These should reference the actual constraint and actual metrics:

| Skill | Success | Progress |
|-------|---------|----------|
| Filler Reduction | "Zero filler words — clean run." | "3 fillers — getting closer to clean." |
| Pace Control | "142 WPM — right in the zone." | "171 WPM — still running hot." |
| Opening Strength | "Strong open. 12 words, clear thesis." | "Solid start. Push for a sharper first line." |
| Concise Speaking | "22 seconds, 34 words. Tight and focused." | "38 seconds — trim the extras." |
| Structure | "Clear framework. Three distinct points." | "Good content. Needs sharper sections." |

---

## 9. Level-Up & Milestone Design

### Level-Up (already built, enhance)

The existing LevelUpCelebrationScreen is strong. Enhancements:

1. **Add skill context**: "You reached Novice Speaker II. Your strongest area: Structure."
2. **Add a progress summary**: "12 sessions · 3 skills improving"
3. **Use tier-specific tint color**: Already done (blue → teal → indigo → orange → yellow)

### Milestone Types and Treatment

| Milestone | Trigger | Treatment | Priority |
|-----------|---------|-----------|----------|
| **Level Up** | XP crosses 1000-boundary | Full-screen celebration. Phased animation + particles. | Highest |
| **Personal Best** | Score > previous best in mode | Full-screen. Star icon, previous vs new score. | High |
| **Streak Milestone** | 3, 7, 14, 30-day streak | 3/7: Compact overlay. 14/30: Full-screen. | Medium-High |
| **Skill Resolved** | TrendDirection == .resolved | Inline celebration in skill progress card. Green checkmark pulse + "Resolved" badge. | Medium |
| **First Drill** | First drill ever completed | Compact overlay: "First drill complete. This is where skill gets specific." | Medium |
| **Drill Streak** | 5+ successful drills in one skill | Compact overlay: flame icon + "5-drill streak in [skill]" | Medium |
| **Zero-Filler Session** | fillerCount == 0 and duration ≥ 30s | Inline badge on summary stat pill. Subtle glow. | Low |
| **First Session** | sessionCount == 1 | Compact overlay. Welcoming, orientation-focused. | Low (once) |
| **Session Count** | 10, 25, 50, 100 sessions | Compact overlay. "50 sessions. You're building a real skill." | Low |

### What NOT to Celebrate

- Every session completed (too frequent, becomes noise)
- Maintaining a streak (only crossing milestones)
- Marginal score changes (<1 point)
- Skill staying stable (that's expected, not an achievement)

---

## 10. What to Avoid

### Reward Anti-Patterns

| Anti-Pattern | Why It's Bad | Example |
|-------------|-------------|---------|
| **Confetti for everything** | Cheapens real achievements | Confetti on session complete regardless of performance |
| **Fake praise on bad sessions** | Erodes trust | "Great job!" after a 3/10 |
| **Loss aversion streaks** | Creates anxiety, not motivation | "Don't break your streak!" push notification |
| **Hidden progress mechanics** | Feels manipulative | XP bonuses that aren't explained |
| **Social comparison** | Wrong for self-improvement app | "You're better than 60% of users" |
| **Cosmetic unlocks** | Off-brand for serious coaching | Unlock new app themes or avatars |
| **Achievement spam** | Notification fatigue | Badge earned, trophy unlocked, reward claimed |
| **Streak shame** | Punishes life circumstances | "You lost your 14-day streak" prominently displayed |
| **Excessive particles/effects** | Feels childish | Fireworks, explosions, screen shake |
| **Sound effects** | Annoying in public, unprofessional | Coin sounds, level-up jingles |

### Animation Anti-Patterns

- Don't animate text content appearing letter-by-letter
- Don't use bounce on more than 1 element at a time
- Don't animate list items with staggered delays (slow, annoying)
- Don't use rotation except for loading indicators and the level-up icon (earned moment)
- Don't use scale > 1.1x for anything except celebrations

### Copy Anti-Patterns

- Don't use exclamation marks more than once per screen
- Don't use emoji in coach feedback (undermines authority)
- Don't use "we" language ("We noticed you...") — the app is a coach, not a friend
- Don't end feedback with questions ("Ready to try again?") — state the next step

---

## 11. SwiftUI Implementation Guidance

### Reward Event System Architecture

```swift
// Central event type — all reward moments flow through this
enum RewardEvent: Equatable {
    // Tier 1: Micro
    case statImproved(stat: String, delta: String)
    case drillCompleted(skillArea: SkillArea, succeeded: Bool)
    case sessionCompleted(score: Int, xpEarned: Int)

    // Tier 2: Medium
    case scoreIncreased(from: Int, to: Int)
    case skillLevelUp(skill: SkillArea, newLevel: SkillLevel)
    case drillStreak(skill: SkillArea, count: Int)
    case zeroFillerSession
    case sessionStreak(days: Int) // 3, 7

    // Tier 3: Major
    case levelUp(from: String, to: String)
    case personalBest(mode: String, score: Int, previousBest: Int)
    case skillResolved(skill: SkillArea)
    case majorSessionStreak(days: Int) // 14, 30
    case sessionCountMilestone(count: Int) // 10, 25, 50, 100

    var tier: RewardTier { ... }
}

enum RewardTier: Int, Comparable {
    case micro = 1
    case medium = 2
    case major = 3
}
```

### RewardEngine (Singleton ObservableObject)

```swift
@Observable
final class RewardEngine {
    static let shared = RewardEngine()

    // Current pending events (consumed by UI)
    private(set) var pendingEvents: [RewardEvent] = []
    private(set) var activeCelebration: RewardEvent?

    func emit(_ event: RewardEvent) {
        pendingEvents.append(event)
        triggerHaptic(for: event)
        if event.tier == .major {
            activeCelebration = event
        }
    }

    func consumeEvent(_ event: RewardEvent) {
        pendingEvents.removeAll { $0 == event }
    }

    func dismissCelebration() {
        activeCelebration = nil
    }

    private func triggerHaptic(for event: RewardEvent) { ... }
}
```

### View Integration Pattern

```swift
// In SummaryView or any reward surface:
@State private var rewardEngine = RewardEngine.shared

// Observe and display
.onChange(of: rewardEngine.activeCelebration) { _, celebration in
    if celebration != nil {
        showCelebrationOverlay = true
    }
}
```

### Animation Helpers

```swift
extension Animation {
    static let scoreReveal: Animation = .easeOut(duration: 0.8)
    static let statDelta: Animation = .spring(response: 0.4, dampingFraction: 0.65).delay(0.3)
    static let achievementPop: Animation = .spring(response: 0.5, dampingFraction: 0.55)
    static let progressFill: Animation = .easeOut(duration: 0.6)
    static let stagger: (Int) -> Animation = { index in
        .spring(response: 0.34, dampingFraction: 0.84).delay(Double(index) * 0.08)
    }
}
```

### Reduced Motion Support

```swift
@Environment(\.accessibilityReduceMotion) var reduceMotion

var animation: Animation {
    reduceMotion ? .easeOut(duration: 0.15) : .bouncySpring
}
```

---

## 12. Implementation Phases

### Phase 1: Foundation (implement first)
- RewardEvent enum and RewardEngine singleton
- Haptics map refinement (expand CoachHaptic)
- Animation extension presets
- Reinforcement copy catalog (ReinforcementCopy enum)

### Phase 2: Core Surfaces
- Enhanced MiniDrillResultView with proper payoff sequence
- Summary stat delta badges with improvement detection
- Coach note stagger animation
- XP bar animation with level-crossing detection

### Phase 3: Milestone System
- Expand detectMilestone with new milestone types
- Session count milestones
- Skill-resolved celebration
- Drill streak milestones

### Phase 4: Skill Progress
- Enhanced SkillProgressView with trend context lines
- Resolved skill celebration
- Skill radar view (journey page — future)

### Phase 5: Polish
- Reduced motion audit
- Haptic fatigue testing
- Copy review pass
- Animation timing QA
