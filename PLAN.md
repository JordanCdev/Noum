# Noum — Personalized Drill System v2: Production Design

**Status:** Implementation plan
**Date:** 2026-04-14

---

## 1. Product Strategy

### The Core Insight

The current system treats drills as "one more rep" — a full re-practice with a constraint banner. This is fine for power users, but it creates friction for everyone else. Most people finish a session emotionally spent. Asking them to do the whole thing again is the wrong ask at the wrong time.

The redesign splits the post-session experience into two lanes:

- **Quick Drill** (30–60 seconds): Low-friction, focused, one-skill-at-a-time. This is the default recommendation for most weaknesses.
- **Full Retry**: Same prompt, same mode, with the constraint from the drill. Reserved for structural or holistic issues where a quick drill can't help.

The system should feel like a coach who says "try this one thing" rather than "do it all again."

### Design Principles

1. **One thing at a time.** Never give the user three areas to work on. Pick the one that matters most right now.
2. **Quick wins first.** The system should bias toward drills the user can succeed at quickly, to build momentum.
3. **Coached, not judged.** Every piece of feedback follows: what's getting stronger → what's holding you back → what to do next.
4. **Freshness over repetition.** Same skill area, different angle every time.
5. **Trends over snapshots.** The system should always know whether this session's weakness is new, recurring, or improving.

---

## 2. Drill System Architecture

### 2.1 Drill Format Types

Replace the single `DrillRecommendation` with a two-format system:

```swift
enum DrillFormat {
    case miniDrill    // 30–60 seconds, focused on one micro-skill
    case fullRetry    // Full re-practice with constraint overlay
}
```

**Mini-Drill** is a new, distinct practice experience:
- Fixed 45-second timer (not configurable — simplicity is the point)
- Single constraint displayed prominently
- Stripped-down UI: just the orb, the constraint, and a progress ring
- No prompt selection — uses same prompt or a randomized one from the same theme
- Immediate success/fail feedback at end (did they meet the constraint?)
- Celebrates success with haptic + micro-animation

**Full Retry** is the existing timed practice flow with the drill constraint banner already implemented in `TimedPracticeView.drillBanner()`.

### 2.2 Decision Framework: Mini-Drill vs Full Retry

```
┌─────────────────────────────────────┬──────────────┐
│ Weakness                            │ Format       │
├─────────────────────────────────────┼──────────────┤
│ High fillers (≥5)                   │ Mini-drill   │
│ Moderate fillers (2-4)              │ Mini-drill   │
│ Rushed pace (>160 WPM)             │ Mini-drill   │
│ Too slow (<100 WPM)                │ Mini-drill   │
│ Weak opening                        │ Mini-drill   │
│ Weak close                          │ Mini-drill   │
│ Answer too short (<15s)             │ Full retry   │
│ Weak structure                      │ Full retry   │
│ Shallow depth                       │ Full retry   │
│ Minimal effort (<5 words)           │ Full retry   │
│ Good session — consolidate          │ Either       │
│ Default / unclear                   │ Mini-drill   │
└─────────────────────────────────────┴──────────────┘
```

**Logic:** If the weakness can be isolated to a single behavior (opening, pace, fillers, close), use mini-drill. If the weakness requires sustained delivery to demonstrate improvement (structure, depth, duration), use full retry.

When `Either` applies, default to mini-drill but present both options in the UI. The user can always escalate to full retry.

### 2.3 Drill Families and Templates

Each skill area gets a **drill family** with 4–6 **variations**. The system rotates through them, never showing the same variation twice in a row.

```swift
struct DrillFamily {
    let skillArea: SkillArea
    let variations: [DrillVariation]
}

struct DrillVariation: Identifiable, Codable {
    let id: String                    // Stable ID for tracking
    let title: String                 // e.g., "The Declarative Open"
    let constraint: String            // The one rule
    let coachingPrinciple: String     // What speaking principle this trains
    let successCriteria: SuccessCriteria
    let format: DrillFormat
}

enum SkillArea: String, Codable, CaseIterable {
    case fillerReduction
    case openingStrength
    case closingStrength
    case paceControl
    case structure
    case answerDevelopment
    case conciseSpeaking
    case pauseUsage
    case vocalEmphasis
    case confidence
}
```

**Example family — Opening Strength:**

| # | Variation | Constraint | Principle |
|---|-----------|-----------|-----------|
| 1 | The Declarative Open | Start with a bold, clear statement. No hedging. | First impressions anchor everything. |
| 2 | The Question Hook | Open with a rhetorical question that frames your answer. | Questions create engagement and buy thinking time. |
| 3 | The Contrast Open | Start with "Most people think X. But actually..." | Contrast creates attention and signals confidence. |
| 4 | The Story Entry | Open with "Last week..." or "I remember when..." | Narrative openings are memorable and natural. |
| 5 | The One-Line Thesis | Your first sentence must contain your entire argument. | Thesis-first speaking trains executive presence. |

**Example family — Filler Reduction:**

| # | Variation | Constraint | Principle |
|---|-----------|-----------|-----------|
| 1 | Silent Transitions | Replace every urge to say "um" with a deliberate pause. | Silence is confidence. Fillers are the sound of thinking out loud. |
| 2 | The Breath Reset | Take one breath between every sentence. No exceptions. | Controlled breathing prevents filler cascades. |
| 3 | Slow First, Clean Second | Cut your pace by 20%. Slower pace = fewer fillers naturally. | Speed is the #1 filler trigger. |
| 4 | The Bridge Phrase | When transitioning, use "And so..." or "Which means..." instead of "um." | Replacing fillers with bridges keeps flow without the crutch. |
| 5 | The Point-Pause-Point | Make one point. Full stop. Pause. Make the next point. | Chunking ideas eliminates the gap where fillers live. |

**All 10 skill areas should have 4–6 variations each.** That gives ~50 distinct drill variations in the system, enough to feel fresh for months of daily use.

### 2.4 Anti-Repetition / Freshness System

```swift
struct DrillHistory: Codable {
    var recentDrills: [DrillHistoryEntry]  // Last 20 drills completed

    struct DrillHistoryEntry: Codable {
        let variationId: String
        let skillArea: SkillArea
        let date: Date
        let succeeded: Bool
    }
}
```

**Rotation rules:**

1. Never recommend the same `variationId` two sessions in a row.
2. Within a skill area, cycle through all variations before repeating any.
3. If the user has done 3+ drills in the same skill area in the last 5 sessions, and the skill is improving (trend analysis confirms), promote a different skill area even if this one still has room to grow. Message: "Your [skill] is getting stronger. Let's shift focus to [new skill]."
4. The `reason` field on every drill is dynamically generated from the current session's data, not a static template. So even when the same variation repeats, the rationale feels specific. E.g., "You used 6 filler words — most appeared after your second point" vs. "You used 3 filler words — they clustered in your opening."

---

## 3. Cross-Session Intelligence

### 3.1 Skill Trend Model

New persistent data structure, stored per-user:

```swift
struct SkillTrendStore: Codable {
    var snapshots: [SkillSnapshot]   // One per session, last 30 sessions

    struct SkillSnapshot: Codable, Identifiable {
        let id: UUID
        let sessionId: UUID
        let date: Date
        let fillerCount: Int
        let duration: TimeInterval
        let wordCount: Int
        let wpm: Double
        let score: Int
        let categoryRatings: [String: FeedbackRating]  // dimension → rating
        let drillCompleted: DrillHistoryEntry?
    }
}
```

### 3.2 Trend Analysis Engine

```swift
enum TrendAnalyzer {

    struct SkillTrend {
        let skillArea: SkillArea
        let direction: TrendDirection
        let confidence: TrendConfidence
        let windowSize: Int           // How many sessions this is based on
        let currentLevel: SkillLevel  // weak / developing / solid / strong
        let recentDelta: String       // e.g., "3 fewer fillers than 5 sessions ago"
    }

    enum TrendDirection {
        case improving
        case stable
        case declining
        case newIssue       // Wasn't a problem before, now it is
        case resolved       // Was a problem, no longer is
    }

    enum TrendConfidence {
        case low            // <3 sessions of data
        case medium         // 3-7 sessions
        case high           // 8+ sessions
    }

    enum SkillLevel {
        case weak           // Consistently rated .couldImprove or metric in bad range
        case developing     // Mixed ratings, showing improvement
        case solid          // Consistently .ok or better
        case strong         // Consistently .good
    }

    /// Analyze all skill areas across recent sessions
    static func analyze(snapshots: [SkillSnapshot]) -> [SkillTrend]

    /// Find the single highest-leverage focus area
    static func primaryFocus(
        trends: [SkillTrend],
        currentSession: SkillSnapshot,
        recentDrills: [DrillHistoryEntry]
    ) -> SkillArea
}
```

### 3.3 Focus Selection Logic

The `primaryFocus` function picks the ONE skill area for the drill recommendation. Priority:

1. **Declining skill with high confidence** — Something that was solid is getting worse. Urgent.
2. **Weak skill that is stable** — A persistent problem the user hasn't started addressing. High leverage.
3. **New issue** — Something that just appeared this session that wasn't a pattern before. Worth flagging.
4. **Weak skill that is improving** — Still weak, but trending up. Continue the momentum.
5. **Developing skill** — Not weak anymore, but not solid yet. Good for consolidation.

**Anti-staleness override:** If the same skill area has been the primary focus for 4+ consecutive sessions, and it's at least `developing`, force-rotate to the next-highest-priority skill area. Message: "You've been working hard on [skill] and it's showing. Let's give [new skill] some attention."

### 3.4 Trend-Informed Drill Rationale

Every drill recommendation includes context from trend analysis:

- **New issue:** "This is new — your opening hasn't been a problem before, but it slipped this session. A quick drill can reset it."
- **Recurring weakness:** "Your openings have been inconsistent across the last 5 sessions. This is worth focused attention."
- **Improving:** "Your filler count dropped from 8 to 3 over your last 5 sessions. One more push and this stops being an issue."
- **Resolved + shift:** "Your pace has stabilized nicely. Your structure is now the bigger opportunity."

---

## 4. Feedback Tone Framework

### 4.1 The Three-Part Pattern

Every piece of feedback in the app follows this structure:

```
1. MOMENTUM    — What is getting stronger (even if small)
2. LEVERAGE    — What is currently holding you back most
3. NEXT STEP   — The one concrete thing to do about it
```

This is not optional. Every feedback surface — verdict, insights, drill rationale, trend summaries — uses this pattern.

### 4.2 Tone Rules

| Rule | Implementation |
|------|---------------|
| Never lead with a weakness | The first sentence of any feedback must be positive or neutral. |
| Be specific, not vague | "Your filler count dropped from 8 to 3" not "You're improving." |
| Use "getting stronger" language | "Your pace is getting more controlled" not "Your pace was too fast." |
| Frame weaknesses as opportunities | "Your opening is the biggest opportunity right now" not "Your opening was weak." |
| Never use the word "but" after a compliment | Use "and" or a period instead. "Clean delivery. Your next edge is structure." |
| Never repeat the same weakness 3 sessions in a row without acknowledging progress | If filler count is still high after 3 sessions, say "Fillers are still above target, but they've dropped from X to Y — you're moving in the right direction." |
| Confidence-sensitive issues get softer framing | Filler words, freezing, and rushing get "This is normal and trainable" language. Structure and depth get more direct language. |
| No fake praise | Don't say "Great job!" for a score of 4. Say "You showed up and practiced — that's the foundation." |
| Celebrate specific improvements | "Zero filler words this session — that's a first" not generic "Nice work." |

### 4.3 Confidence Sensitivity Tiers

```swift
enum FeedbackSensitivity {
    case direct      // Structure, depth, relevance — the user can hear it straight
    case measured    // Pace, opening, close — balance honesty with encouragement
    case gentle      // Fillers, freezing, rushing — these are anxiety-adjacent, be careful
}
```

For `.gentle` issues:
- Always acknowledge that the issue is common and trainable
- Never use words like "problem," "issue," or "failure"
- Frame metrics as data, not judgment: "6 filler words — most speakers average 4-8 in impromptu settings"
- If improving, lead with the improvement: "Down from 9 to 6 — that's real progress"
- If stagnant, reframe the approach: "Let's try a different angle on this"

### 4.4 Dynamic Verdict Generation

Replace the current static verdict system with a template engine that uses trend data:

```swift
enum VerdictEngine {
    static func generate(
        currentSession: SkillSnapshot,
        trends: [SkillTrend],
        recentDrills: [DrillHistoryEntry]
    ) -> Verdict

    struct Verdict {
        let momentum: String      // What's getting stronger
        let leverage: String      // What's holding them back
        let nextStep: String      // What to do about it
    }
}
```

---

## 5. Reward / Dopamine / Animation / Haptic Strategy

### 5.1 Reward Moments

| Moment | Trigger | Reward |
|--------|---------|--------|
| Drill completion | Finish any mini-drill | Subtle success animation + haptic (`.success`) + "Drill complete" text |
| Drill success | Meet the success criteria | Stronger celebration + haptic (`.notification(.success)`) + confetti-lite particles + specific praise ("Zero fillers — nailed it") |
| Skill level-up | Skill moves from `weak` → `developing` or `developing` → `solid` | Full milestone card with before/after comparison + haptic burst + "Your [skill] just leveled up" |
| Streak within skill | 3 consecutive successful drills in same skill area | Badge pulse + "3 in a row — [skill] is becoming second nature" |
| First-time achievement | First zero-filler session, first 60s+ answer, first score ≥8, etc. | `MilestoneCelebrationOverlay` with achievement text |
| Trend breakthrough | A skill transitions from `declining`/`stable` → `improving` | Subtle glow on the skill in the trend view + "Turning point — [skill] is on the move" |
| Pattern resolution | A skill that was `weak` reaches `solid` | Major celebration: "You solved it. [Skill] is no longer holding you back." |

### 5.2 Haptic Design

```swift
enum CoachHaptic {
    static func drillStart() {
        // Single firm tap — marks the beginning
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func drillSuccess() {
        // Double tap — satisfying completion
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    static func drillFail() {
        // Soft single tap — not punishing
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func skillLevelUp() {
        // Three ascending taps
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            generator.impactOccurred(intensity: 0.7)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            generator.impactOccurred(intensity: 1.0)
        }
    }

    static func trendBreakthrough() {
        // Gentle pulse
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }
}
```

### 5.3 Micro-Animations

- **Drill success ring**: The progress ring around the orb fills to 100% and pulses once with the drill's tint color. Use `withAnimation(.spring(response: 0.4, dampingFraction: 0.6))`.
- **Skill level-up badge**: Small badge with the skill icon scales from 0 → 1.2 → 1.0 with a spring, then glows briefly. Reuse existing `PulseBadge` from `GamifiedViews.swift`.
- **Trend arrow**: When a trend changes direction, the arrow icon rotates to its new direction with a spring animation.
- **Score countup**: The score number in the hero card counts up from 0 → final score using a `TimelineView` or `withAnimation` on a timer. Already partially implemented — ensure it's smooth.
- **Streak flame**: For skill drill streaks, a small flame icon appears next to the skill name and pulses. Reuse shimmer pattern from `ShimmerProgressBar`.

---

## 6. Redesigned Eval-to-Drill Flow

### 6.1 New Summary Screen Layout

The current summary has 4 tiers and a lot of content. The redesign reduces cognitive load by making the drill the hero action and pushing analysis into expandable sections.

```
┌─────────────────────────────────────────────┐
│              HERO SCORE CARD                │
│    [Score ring]  [Headline]                 │
│    [Duration] [Fillers↓] [WPM]              │
│    [Trend badges: "Pace ↑" "Fillers ↓"]    │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│            COACH NOTE                       │
│  [Momentum] Your pace is getting more       │
│  controlled and your openings are stronger. │
│                                             │
│  [Leverage] Structure is now the biggest    │
│  opportunity — your points ran together.    │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│           YOUR NEXT MOVE                    │
│  [Icon] Quick Drill: Build a Framework      │
│  "Use strict 3-part structure:              │
│   opening → example → close"               │
│                                             │
│  [===== Start Quick Drill (45s) =====]     │
│                                             │
│  or [Full Retry ▸]                          │
└─────────────────────────────────────────────┘

┌─ Expandable ────────────────────────────────┐
│  ▸ Session Details                          │
│    (Category grid, moments, AI coach read)  │
│  ▸ Skill Progress                           │
│    (Trend lines per skill area)             │
│  ▸ Share / Export                            │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│  [Home]     [New Topic]     [Share]         │
└─────────────────────────────────────────────┘
```

### 6.2 Key Changes from Current Layout

1. **Verdict card → Coach Note**: Renamed and restructured to use the momentum/leverage pattern. Shorter, more focused.
2. **Next Rep Card → Your Next Move**: Now the primary CTA of the entire screen. Larger, more prominent, with the drill constraint visible immediately (no expand needed).
3. **Mini-drill is the default CTA button.** Full retry is a secondary text link below.
4. **Category grid, AI moments, and all secondary content move into an expandable "Session Details" section.** Most users should act on the drill, not get lost in analysis.
5. **New "Skill Progress" expandable section**: Shows trend data across sessions. This is where the user can see their skill levels, trends, and history. This replaces the current session comparison card with something more useful.
6. **AI Coach Read stays on-demand** but is nested inside "Session Details" — not competing with the drill CTA.
7. **Celebration screens (level-up, personal best) still appear as intermediaries** before the summary, unchanged.

### 6.3 Mini-Drill Completion Screen

After a mini-drill completes, show a compact result:

```
┌─────────────────────────────────────────────┐
│        DRILL RESULT                         │
│                                             │
│  [✓ Success / ○ Keep Going]                │
│                                             │
│  "Zero filler words — clean run."          │
│  or                                         │
│  "2 fillers — down from 6. Progress."      │
│                                             │
│  [+15 XP]                                  │
│                                             │
│  [Done]        [Try Another Drill]          │
└─────────────────────────────────────────────┘
```

The mini-drill result screen is intentionally minimal. It should take <3 seconds to read. No analysis paralysis.

---

## 7. Data Model Updates

### 7.1 New/Modified Models

```swift
// Add to PracticeSession
struct PracticeSession: Identifiable, Codable {
    // ... existing fields ...
    var drillResult: DrillResult?       // NEW: If this session was a drill
}

struct DrillResult: Codable {
    let variationId: String
    let skillArea: SkillArea
    let format: DrillFormat
    let succeeded: Bool
    let constraintMet: Bool
    let parentSessionId: UUID?          // The session that triggered this drill
}

// New persistent stores
struct DrillHistory: Codable {
    var entries: [DrillHistoryEntry]     // Last 30 entries

    struct DrillHistoryEntry: Identifiable, Codable {
        let id: UUID
        let variationId: String
        let skillArea: SkillArea
        let date: Date
        let succeeded: Bool
        let sessionId: UUID
    }
}

struct SkillTrendStore: Codable {
    var snapshots: [SkillSnapshot]      // Last 30 sessions
    // ... as defined in §3.1
}
```

### 7.2 Storage

- `DrillHistory` → UserDefaults, keyed per account, synced via `BackendSyncManager`
- `SkillTrendStore` → UserDefaults, keyed per account, synced via `BackendSyncManager`
- Drill variation catalog → hardcoded in-app (no network dependency)

---

## 8. Implementation Recommendations

### 8.1 New Files

| File | Purpose |
|------|---------|
| `DrillSystem.swift` | `DrillFamily`, `DrillVariation`, `SkillArea`, `DrillFormat`, `DrillCatalog` (the 50+ variations), `DrillSelector` (freshness-aware selection), `DrillHistory` |
| `TrendAnalyzer.swift` | `SkillTrendStore`, `SkillSnapshot`, `TrendAnalyzer`, `SkillTrend`, trend analysis logic |
| `FeedbackEngine.swift` | `VerdictEngine`, `CoachNote`, `FeedbackSensitivity`, tone-aware feedback generation |
| `MiniDrillView.swift` | The 45-second mini-drill practice experience — stripped-down UI |
| `MiniDrillResultView.swift` | Post-mini-drill compact result screen |
| `SkillProgressView.swift` | Expandable skill trend visualization for the summary screen |
| `CoachHaptic.swift` | Centralized haptic patterns |

### 8.2 Modified Files

| File | Changes |
|------|---------|
| `PracticeSupport.swift` | Add `SkillArea` enum, `DrillFormat`, update `DrillRecommendation` to include format and variation ID. Keep `DrillEngine` but expand it to use trend data and freshness. Remove old `DrillType` in favor of `SkillArea`. |
| `SummaryView.swift` | Restructure layout per §6. Replace `nextRepCard` with `yourNextMoveCard`. Add Coach Note. Make category grid / moments / AI coach expandable. Add Skill Progress section. Add mini-drill navigation. |
| `TimedPracticeView.swift` | Add navigation to `MiniDrillView`. Update drill banner to support both formats. |
| `SpeechRecognizerViewModel.swift` | Add `drillResult` to `PracticeSession`. |
| `GamifiedViews.swift` | Add drill success animation, skill level-up badge, trend arrow animation. |
| `DesignSystem.swift` | Add drill-specific colors/tokens if needed. |
| `ProfileManager.swift` | Track skill-level milestones for celebration triggers. |

### 8.3 Implementation Order

1. **Data layer first**: `DrillSystem.swift` (catalog + history), `TrendAnalyzer.swift` (snapshots + analysis), `FeedbackEngine.swift` (verdict generation). These have no UI dependencies and can be built and tested in isolation.
2. **Mini-drill experience**: `MiniDrillView.swift` + `MiniDrillResultView.swift`. This is a self-contained new view.
3. **Summary screen restructure**: Update `SummaryView.swift` layout, add Coach Note, make drill the hero CTA, add expandable sections.
4. **Haptics and animations**: `CoachHaptic.swift`, updates to `GamifiedViews.swift`.
5. **Trend visualization**: `SkillProgressView.swift` — the expandable trend view in the summary.
6. **Wire it together**: Navigation from summary → mini-drill → result → back to summary or home.
7. **Populate the drill catalog**: Write all 50+ drill variations across 10 skill areas. This is content work, not engineering.

### 8.4 What NOT to Build

- No AI-generated drills. The catalog is hand-crafted and deterministic. AI is for evaluation, not drill selection.
- No separate "drill mode" in the mode selection screen. Drills are always triggered from the post-session flow. They are not a standalone practice mode.
- No drill scheduling or push notification integration (yet). Drills are in-the-moment, post-session only.
- No social/competitive drill features. Keep it personal.
- No drill difficulty levels. The drill is what it is. Simplicity.

---

## 9. Drill Variation Catalog (Condensed)

Full catalog to be written during implementation. Here is the structure for all 10 skill areas:

### Filler Reduction (5 variations)
- Silent Transitions, Breath Reset, Slow First Clean Second, Bridge Phrases, Point-Pause-Point

### Opening Strength (5 variations)
- Declarative Open, Question Hook, Contrast Open, Story Entry, One-Line Thesis

### Closing Strength (4 variations)
- The Callback Close, The One-Sentence Summary, The Forward Look, The Decisive Stop

### Pace Control (5 variations)
- The Metronome (deliberate even pace), The Slow Start (first 10s at half speed), The Pause Punctuation (pause after every period), The Speed Check (self-monitor and adjust mid-answer), The Conversational Gear (match natural speech rhythm)

### Structure (4 variations)
- Three-Part Framework (open/point/close), The PREP Method (Point/Reason/Example/Point), The Timeline (chronological structure), The Contrast Frame (on one hand / on the other hand)

### Answer Development (4 variations)
- The Specific Example (must include one concrete story), The "So What" Test (end every point with why it matters), The Detail Layer (add sensory or emotional detail to one moment), The Evidence Stack (support your point with 2 different types of evidence)

### Concise Speaking (4 variations)
- The 3-Sentence Cap (make your point in exactly 3 sentences), The Headline First (lead with conclusion, then support), The Cut Word (remove one unnecessary word from each sentence mentally), The Time Box (make your full point in 20 seconds)

### Pause Usage (4 variations)
- The Power Pause (one 2-second pause before your key point), The Paragraph Break (pause between each distinct idea), The Landing Pause (pause after your final sentence, don't trail off), The Thinking Pause (when you need to think, pause visibly instead of filling)

### Vocal Emphasis (4 variations)
- The Key Word (emphasize the single most important word in each sentence), The Volume Shift (drop or raise volume on your key phrase), The Pace Shift (slow down for emphasis on crucial points), The Repetition Punch (repeat your key phrase once for impact)

### Confidence/Presence (4 variations)
- The Commitment Drill (no hedge words: "I think," "maybe," "sort of"), The Ownership Open (start with "I believe" or "In my experience"), The Eye Contact Hold (imagine looking someone in the eye for your full opening), The Grounded Pace (speak at 80% of your natural speed — control signals confidence)

---

## 10. Speaking Improvement Principles Referenced

Every drill variation is grounded in established speaking/coaching frameworks:

| Principle | Source | Applied In |
|-----------|--------|------------|
| Silence > fillers | Toastmasters "Ah Counter" methodology | Filler reduction drills |
| Strong openings anchor perception | Carnegie's public speaking principles | Opening strength drills |
| Structure reduces cognitive load | PREP/STAR frameworks (interview coaching) | Structure drills |
| Deliberate practice on isolated skills | Ericsson's deliberate practice research | Mini-drill format itself |
| Spaced repetition with variation | Motor learning research | Freshness/rotation system |
| Growth mindset feedback | Dweck's research on feedback framing | Tone framework |
| Specific > generic feedback | Toastmasters evaluation methodology | All feedback surfaces |
| One skill at a time | Coaching principle of "working on one thing" | Single-focus drill selection |
| Pace control as confidence proxy | Voice coaching (Patsy Rodenburg, etc.) | Pace control drills |
| Deliberate closing | Speech competition judging criteria | Closing strength drills |
| Anxiety reduction through repetition | Exposure therapy principles (CBT) | The mini-drill format reduces the "big scary re-do" into something manageable |

---

This plan is opinionated and specific. It's designed to be implemented without ambiguity. The drill catalog content (§9) will be the largest single task — but it's pure content writing, not engineering risk.
