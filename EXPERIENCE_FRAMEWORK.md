# Noum Unified Experience Framework

**Date:** 2026-04-14
**Status:** Production design — cross-mode consistency standard

---

## 1. Noum Experience Principles

### What Noum Is

Noum is a **serious private coach**. Not a game, not a classroom, not a social app. It's the space where someone works on how they speak — alone, honestly, without judgment from others.

### Five Governing Principles

**1. One coach, one voice.**
No matter which mode the user enters, the feedback should sound like it comes from the same person — direct, specific, respectful, and forward-looking. The coach adjusts intensity by context, but never changes personality.

**2. Effort is the unit of value.**
The app rewards showing up, completing reps, and following through. Not just scoring high. A 4/10 session where the user addressed their known weakness is worth more than an 8/10 that avoided the hard thing.

**3. Show trajectory, not snapshots.**
A single data point is discouraging or meaningless. Everything should be framed against where the user was and where they're heading. "Your fillers dropped from 8 to 3 over your last 5 sessions" is motivating. "You had 3 fillers" is just data.

**4. Friction is deliberate or it's a bug.**
Setup friction (choosing a scenario, selecting a tone) must serve a coaching purpose — it focuses the mind before practice. All other friction (confusing navigation, inconsistent patterns, unclear next steps) is a defect.

**5. Every mode is Noum.**
Switching modes should feel like changing exercises at the gym, not switching apps. The environment, the coach, the feedback model, the reward system, and the visual language remain constant. Only the exercise changes.

### What Kind of Coach Noum Is

- **Direct but not harsh.** Calls out the issue, never the person.
- **Specific, never generic.** "Your opening was vague" not "Try harder."
- **Forward-looking.** Every piece of feedback ends with a concrete next step.
- **Confidence-aware.** Fillers and confidence issues get gentler framing than structural issues. The coach knows these are psychologically different.
- **Quiet when there's nothing to say.** Doesn't manufacture praise. If the session was weak, it says what to fix, not "Great effort!"
- **Celebrates silently.** Major wins get attention. Small improvements get quiet acknowledgment. The coach doesn't over-celebrate.

### How Friction Should Be Handled

- **Pre-session setup:** Acceptable when it focuses intent (topic selection, tone choice, difficulty). Must never feel like bureaucracy.
- **During session:** Zero friction. The UI recedes. Only the timer, the constraint, and the recording state are visible.
- **Post-session:** One clear next step. "Start Drill" or "Go Home." Not a menu of 5 options competing for attention.
- **Navigation:** Always one tap to go home. Always one tap to retry. Never more than two taps to start a new session.

---

## 2. Unified Session Lifecycle

Every practice mode follows the same arc. What changes is the content and intensity at each stage, not the structure.

### The Seven Phases

```
┌─────────────────────────────────────────────────────────┐
│  1. INTENT     → Why am I practicing? What's the focus? │
│  2. READY      → Countdown or ceremony before start     │
│  3. ACTIVE     → The practice itself                    │
│  4. LAND       → The session ends, brief pause          │
│  5. REFLECT    → Score, feedback, trends                │
│  6. NEXT MOVE  → Drill, retry, or done                  │
│  7. PROGRESS   → XP, level, streak, milestone           │
└─────────────────────────────────────────────────────────┘
```

### Phase-by-Phase Specification

#### Phase 1: INTENT (Pre-Session Setup)

**Purpose:** Focus the user's mind on what they're about to practice.

| Mode | Intent UX | Duration |
|------|-----------|----------|
| **Timed** | Topic selection (question or free-form) | 5-15s |
| **Sudden Death** | Brief rules reminder + topic | 3-5s |
| **Ah-Counter** | Optional topic suggestion | 0-5s |
| **IM** | Scenario + tone selection | 15-30s |
| **Mini-Drill** | Constraint displayed | 2-3s |

**Shared rule:** Every mode shows the user what they're about to practice and why, even if briefly.

**Anti-pattern:** Starting recording immediately with no mental preparation (current Ah-Counter).

#### Phase 2: READY (Countdown)

**Purpose:** Create a moment of anticipation and focus.

**Shared standard:**
- All modes use a 3-second visual countdown.
- Countdown beats: `CoachHaptic.countdownBeat()` on each number.
- Final "Go" cue with `CoachHaptic.drillStart()`.
- Visual: Number scales in with `.snappySpring`, centered on screen.

| Mode | Variation |
|------|-----------|
| **Timed** | Standard 3-2-1 |
| **Sudden Death** | 3-2-1 with amber tint (tension) |
| **Ah-Counter** | 3-2-1 (add this — currently missing) |
| **IM** | Skip countdown (conversation starts naturally) |
| **Mini-Drill** | Standard 3-2-1 |

**Anti-pattern:** Immediate recording start with no psychological preparation.

#### Phase 3: ACTIVE (In-Session)

**Purpose:** The user is practicing. UI recedes.

**Shared standard:**
- Background is calm and uncluttered.
- Only essential information visible: timer, one metric, stop control.
- No reward UI, no celebration, no coaching text during speech.
- Progress indicator (time elapsed or remaining) always visible.
- Filler count visible in modes that track it.
- Haptics: None during recording (vibration could be audible).

| Mode | Unique Active UX |
|------|-----------------|
| **Timed** | Spotlight orb with timing state colors |
| **Sudden Death** | Pressure level indicator, pressure events |
| **Ah-Counter** | Live filler counter, streak tracker, encouragement banner |
| **IM** | Message thread, NPC responses, recording indicator |
| **Mini-Drill** | Progress ring, constraint banner |

**Rule:** Modes can show different content during the active phase, but the visual weight, information density, and emotional tone should feel equivalent. No mode should feel visually overwhelming compared to another.

#### Phase 4: LAND (Completion Moment)

**Purpose:** Mark the transition from practice to reflection. Brief pause.

**Shared standard:**
- 0.3-0.5s pause after recording stops before showing results.
- `CoachHaptic.sessionComplete()` fires (new pattern — see haptics map).
- Screen transitions smoothly to evaluation, no jarring jump.

| Mode | Variation |
|------|-----------|
| **Timed** | Fade to summary |
| **Sudden Death** | If filler-triggered: brief "Run Over" card (2s), then summary. If manual stop: fade to summary. |
| **Ah-Counter** | Fade to summary |
| **IM** | "Wrapping up" indicator (processing), then summary |
| **Mini-Drill** | Brief result overlay, then MiniDrillResultView |

**Rule:** Sudden Death's game-over overlay is acceptable as a mode-specific ceremony, but it should transition to SummaryView within 3 seconds, not require a button tap. Auto-advance.

#### Phase 5: REFLECT (Evaluation)

**Purpose:** Show what happened and frame it against trajectory.

**Shared standard (SummaryView):**
- Hero score card (score + headline)
- Coach note (3-part: momentum, leverage, next step)
- Stat pills (fillers, duration, XP)
- Category breakdown
- Trend context

All modes use the same SummaryView. The only allowed variation is additional mode-specific data (IM conversation details, Sudden Death survival time, Ah-Counter streak stats).

#### Phase 6: NEXT MOVE (Action)

**Purpose:** One clear next action.

**Shared standard:**
- "Your Next Move" card recommending a drill or retry.
- Primary CTA: Start drill or practice again.
- Secondary: Go home.
- Never more than 2 competing CTAs visible.

#### Phase 7: PROGRESS (Reward)

**Purpose:** Show what the session earned toward long-term goals.

**Shared standard:**
- XP progress bar with animated fill.
- Level-up celebration if threshold crossed.
- Milestone detection (personal best, streak, session count, skill resolved).
- Skill progress card with trend visualization.

All of this happens within SummaryView. No mode-specific reward logic.

---

## 3. Shared Feedback Framework

### The Noum Feedback Model

Every piece of feedback in the app follows one structure:

```
1. MOMENTUM   → What is getting stronger
2. LEVERAGE   → What is currently the biggest opportunity
3. NEXT STEP  → One concrete action
```

This applies to:
- Post-session coach note
- Drill recommendation rationale
- Trend context strings
- Home screen coaching messages
- Push notification copy

### Tone Rules by Sensitivity

| Skill Area | Sensitivity | Framing |
|------------|-------------|---------|
| Fillers, Confidence, Pace | Gentle | Frame as habit/pattern, not as failure. "Your pace hit 170 WPM — worth slowing down." |
| Opening, Closing, Pauses, Vocal Emphasis | Measured | Direct but constructive. "Your opening is the biggest opportunity right now." |
| Structure, Answer Development, Concise Speaking | Direct | Call it out clearly. "The answer lacked structure — use the three-part framework." |

### Score Presentation Standard

| Score | Framing | Color |
|-------|---------|-------|
| 8-10 | "Strong session." | AppColor.positive |
| 6-7 | "Solid session." | AppColor.brandBlue |
| 4-5 | "Room to grow." | AppColor.caution |
| 1-3 | "Tough one." | AppColor.warning |

**Rule:** Never use exclamation marks for low scores. Never use "Great job!" for any score below 7.

### Verdict vs. Coaching

- **Verdict** = What happened. ("Your pace was 172 WPM.") — Shown as data.
- **Coaching** = What it means and what to do. ("That's fast enough to lose the audience. Try the Slow Start drill.") — Shown as coach note.

These are always separate UI elements. Verdicts are in stat pills. Coaching is in the coach note card.

### Drill Recommendation Logic

All modes feed into the same `DrillEngineV2.recommend()` pipeline:
1. Session metrics (fillers, pace, duration, score, categories)
2. Cross-session trends (from SkillTrendStore)
3. Sensitivity and priority weighting
4. Freshness check (from DrillHistoryStore)

No mode should generate its own drill recommendation logic.

---

## 4. Shared Reward Framework

### Reward Events (Universal)

These events are recognized regardless of which mode generated them:

| Event | Tier | Treatment |
|-------|------|-----------|
| Session completed | Micro | Stat display + XP |
| Score improved vs recent baseline | Micro | Delta badge on stat pill |
| Drill completed | Micro | Result screen |
| Score increased significantly (≥2 points) | Medium | Inline celebration text |
| Skill level up (weak→developing, etc.) | Medium | Badge in skill progress |
| Drill streak (3+ successful) | Medium | Streak badge |
| Zero-filler session (≥30s) | Medium | Badge on filler stat |
| Session streak (3, 7 days) | Medium | Compact overlay |
| Level-up (XP threshold) | Major | Full-screen celebration |
| Personal best score | Major | Full-screen celebration |
| Skill resolved | Major | Compact overlay |
| Session streak (14, 30 days) | Major | Full-screen celebration |
| Session count milestone (10, 25, 50, 100) | Major | Compact overlay |

### What Is NOT Rewarded

- Opening the app
- Starting but not finishing a session
- Scoring the same as usual
- Maintaining a skill level (that's expected, not an achievement)

### Reward Priority

When multiple events occur simultaneously (e.g., level-up + personal best), show the highest-tier event first. Never stack more than 2 celebrations in a row.

---

## 5. Haptics System

### Global Haptic Language

Haptics in Noum have a vocabulary. Every pattern means something specific.

| Pattern | Meaning | When |
|---------|---------|------|
| **Selection tap** (light) | "I heard your tap" | Any button/toggle/selection |
| **Countdown beat** (rigid, 0.7) | "Get ready" | Each countdown number |
| **Session start** (medium) | "Go" | Recording begins |
| **Score reveal** (light, 0.6) | "Here's your result" | Score number lands |
| **XP earned** (light, 0.4) | "Quiet accumulation" | XP count finishes |
| **Trend breakthrough** (soft) | "Positive shift detected" | Stat improvement, skill resolved |
| **Drill success** (notification.success) | "You met the criteria" | Drill completed successfully |
| **Drill incomplete** (soft, 0.5) | "Not yet, keep going" | Drill criteria not met |
| **Streak achievement** (double medium) | "Consistency noted" | Session or drill streak milestone |
| **Skill level-up** (3 ascending taps) | "Your skill grew" | Skill area leveled up |
| **Level-up** (3 taps + notification) | "Major achievement" | XP level crossed |
| **Personal best** (notification + delayed heavy) | "Your best ever" | New high score in mode |

### When NOT to Haptic

- During speech recording (vibration is audible).
- On coach note text appearance (reading moment, no interruption).
- On navigation transitions (standard iOS, no extra).
- On error states (errors are visual, not tactile).
- More than 3 haptics within 2 seconds (causes fatigue).

### Cross-Mode Haptic Standard

Every mode must trigger these haptics at the corresponding lifecycle phase:

| Phase | Haptic | Required? |
|-------|--------|-----------|
| Countdown beat | `countdownBeat()` | Yes (except IM) |
| Session starts | `drillStart()` | Yes |
| Session ends | (new) `sessionComplete()` | Yes |
| Score reveals | `scoreReveal()` | Yes |
| XP finishes counting | `xpEarned()` | Yes |
| Milestone detected | Per milestone type | Yes |

---

## 6. Motion System

### Animation Vocabulary

Noum uses four motion tiers, each with a distinct purpose.

#### Tier 1: Micro-interaction (0.1-0.26s)
**Spring:** `.snappySpring` (response: 0.26, dampingFraction: 0.88)
**Purpose:** Immediate responsiveness. The user touched something and it responded.
**Used for:** Button press feedback, toggle state, chip selection, tab switch.

#### Tier 2: Content transition (0.3-0.5s)
**Spring:** `.standardSpring` (response: 0.34, dampingFraction: 0.84)
**Purpose:** Something meaningful changed. A new card appeared, content updated, a section expanded.
**Used for:** Card entrance, section expand/collapse, stat update, coach note reveal, countdown number change.

#### Tier 3: Achievement moment (0.4-0.7s)
**Spring:** `.bouncySpring` (response: 0.40, dampingFraction: 0.65) or `.achievementPop`
**Purpose:** Something worth noticing happened. A badge appeared, a milestone was hit, a skill leveled up.
**Used for:** Badge pop, streak badge, skill level-up badge, drill success ring, XP badge appearance.

#### Tier 4: Celebration (0.6-1.2s)
**Timing:** Custom phased sequence
**Purpose:** Full emotional arc. The user achieved something significant.
**Used for:** Level-up screen, personal best screen, 14+ day streak celebration.
**Never used for:** Routine completions, small improvements, navigation.

### Cross-Mode Motion Rules

1. **Same phase, same motion.** Countdown numbers always use `.snappySpring`. Score reveals always use `.scoreReveal`. No mode-specific overrides.
2. **Never animate more than 2 elements simultaneously** in the same viewport.
3. **Stagger secondary elements 0.15-0.3s** after the primary element.
4. **Progress indicators use linear timing** (bars, rings). Organic elements use springs.
5. **Reduced motion:** All animations degrade to 0.15s easeOut when `accessibilityReduceMotion` is true.
6. **First appearance only.** Don't re-animate content that was already visible. Track shown state.

### What Must Stay Static

- Body text (never animate text content appearing letter-by-letter)
- Navigation chrome (back buttons, titles, toolbars)
- Error messages (appear immediately)
- Recording indicators (steady, not bouncy)
- Coach note text (content is static after reveal animation)

---

## 7. Visual System Recommendations

### Component Hierarchy

The app uses four visual containers, in consistent order:

#### 1. Hero Card (one per screen)
- **Purpose:** The most important thing on this screen.
- **Styling:** `AppColor.cardBackground`, `CornerRadius.xl`, `Spacing.lg` padding, shadow.
- **Examples:** Score card, drill constraint card, mode hero card.
- **Rule:** Exactly one hero card per screen. It's always the first content element.

#### 2. Action Card (one per screen, below hero)
- **Purpose:** What to do next.
- **Styling:** Same as hero, but with mode tint accent on the primary CTA.
- **Examples:** "Your Next Move" card, "Start Drill" card, "Practice Again" card.
- **Rule:** Contains exactly one primary CTA and optionally one secondary.

#### 3. Detail Cards (0-3 per screen, below action)
- **Purpose:** Supporting information.
- **Styling:** Same background and corner radius. May use `DisclosureGroup` for expansion.
- **Examples:** Coach note card, skill progress card, category breakdown.
- **Rule:** Collapsed by default if there are more than 2. Never compete with hero or action.

#### 4. Ambient Cards (bottom of scroll, optional)
- **Purpose:** Long-term context.
- **Styling:** Lighter treatment. May use `AppColor.innerSurface` background.
- **Examples:** XP progress, retention challenge, session comparison.

### Button Hierarchy

| Level | Style | When |
|-------|-------|------|
| **Primary CTA** | Mode tint `.gradient`, Capsule, white text, `.pressable`, full width | One per screen. The main action. |
| **Secondary CTA** | White background, mode tint text, Capsule stroke, `.pressable` | Alternative action. "Try Another Drill" or "Go Home." |
| **Tertiary** | Text only, `.secondary` color, `.pressable` | Dismissive actions. "Skip" or "Not now." |
| **Destructive** | `Color.red` background, white text, Capsule | "Stop Recording", "End Chat." |

**Rule:** Primary CTAs always use `.gradient` modifier. Secondary CTAs never do.

### Typography Standards

| Context | Font | Weight | Design |
|---------|------|--------|--------|
| **Hero number** (score, timer) | .system(size: 48+) | .bold | .rounded |
| **Section title** | .caption | .bold | .default, .uppercased, tracking: 0.8 |
| **Card headline** | .headline or .system(size: 20) | .semibold | .default |
| **Body text** | .subheadline | .regular | .default |
| **Stat value** | .title2 or .title3 | .bold | .default |
| **Stat label** | .caption | .regular | .default |
| **Badge text** | .caption or .caption2 | .bold | .default |

### Background Standards

| Context | Background |
|---------|-----------|
| **Standard screens** | `AppColor.screenBackground` |
| **Setup/selection screens** | `LightGradientBackground` (AppColor.lightGradientStart/End) |
| **Focused practice** (drill, active session) | Mode-specific or dark (but always from a defined palette) |
| **Celebration overlays** | Dark overlay with mode-tint gradient accent |

**Rule:** No hardcoded `Color(red: X, green: Y, blue: Z)` for backgrounds. All must come from `AppColor` or be defined as new tokens.

---

## 8. Shared Coaching Taxonomy

### The 10 Skill Areas

All modes observe and evaluate the same 10 skills. Different modes may have stronger or weaker signals for each skill, but the taxonomy is universal.

| Skill Area | What It Measures | Signal Strength by Mode |
|------------|-----------------|------------------------|
| **Filler Reduction** | Frequency and placement of filler words | All modes (strong) |
| **Opening Strength** | Quality and confidence of the first sentence | Timed (strong), IM (moderate), Drill (strong) |
| **Closing Strength** | Decisiveness and clarity of the final statement | Timed (strong), IM (weak), Drill (strong) |
| **Pace Control** | Words per minute, variation, tempo | All modes (strong) |
| **Structure** | Logical organization, transitions, framework | Timed (strong), IM (moderate), SD (moderate) |
| **Answer Development** | Depth, specificity, completeness | Timed (strong), IM (strong) |
| **Concise Speaking** | Ability to make a point without over-talking | All modes (moderate) |
| **Pause Usage** | Deliberate use of silence for emphasis | Timed (moderate), Drill (strong) |
| **Vocal Emphasis** | Variation in delivery, emphasis on key words | Timed (moderate), Drill (strong) |
| **Confidence** | Absence of hedging, steady delivery, commitment | All modes (moderate) |

### Mode-to-Skill Mapping

Each mode naturally emphasizes certain skills:

| Mode | Primary Skills | Secondary Skills |
|------|---------------|-----------------|
| **Timed** | Structure, Opening, Closing, Answer Development | Pace, Fillers, Concise |
| **Sudden Death** | Fillers, Confidence, Pace | Structure, Pauses |
| **Ah-Counter** | Fillers, Pace, Pauses | Confidence |
| **IM** | Answer Development, Structure, Confidence | Concise, Pace |
| **Mini-Drill** | (Varies by drill skill area) | — |

### Unified Skill Levels

```
weak → developing → solid → strong
```

These levels apply to every skill area across all modes. A user's filler reduction level is the same whether measured in Timed, Sudden Death, or Ah-Counter mode. The modes contribute data to the same skill model.

### Cross-Session Trend Directions

```
improving → stable → declining → newIssue → resolved
```

Trends are computed from the last 8 sessions regardless of mode. A user improving their fillers across a mix of Timed and Ah-Counter sessions sees one improving trend, not two separate ones.

---

## 9. What Can Vary vs. What Must Stay Consistent

### MUST Stay Consistent (The Noum Constants)

| Element | Standard | Violation = Bug |
|---------|----------|-----------------|
| **Countdown ceremony** | 3-2-1 with countdownBeat haptic | Skipping countdown (current Ah-Counter) |
| **Post-session destination** | SummaryView | Mode-specific result screens replacing SummaryView |
| **Feedback structure** | Momentum → Leverage → Next Step | Different feedback formats per mode |
| **Score presentation** | 0-10 scale with consistent color coding | Mode-specific scoring systems |
| **Reward events** | RewardEngine.shared processes all events | Mode-specific milestone logic |
| **Haptic language** | CoachHaptic patterns only | Inline UIImpactFeedbackGenerator calls |
| **Animation springs** | Design system presets only | Ad-hoc .easeInOut(duration: X) |
| **Button hierarchy** | Primary/Secondary/Tertiary/Destructive | Custom one-off button styles |
| **Card styling** | AppColor.cardBackground + CornerRadius | Hardcoded backgrounds |
| **Coaching voice** | Direct, specific, forward-looking | Sugar-coated or harsh per mode |
| **Skill taxonomy** | 10 skill areas, 4 levels | Mode-specific skill definitions |
| **XP and leveling** | Single progression system | Mode-specific XP logic |

### CAN Vary by Mode (The Flavor)

| Element | How It Can Vary | Example |
|---------|----------------|---------|
| **Mode tint color** | Each mode has its own accent color | Timed=blue, SD=orange, AhC=green, IM=indigo |
| **Active session UI** | Content and layout during practice | IM shows messages, Timed shows orb, AhC shows counter |
| **Session intensity** | Psychological pressure and pacing | Sudden Death is high-pressure, Ah-Counter is calm |
| **Setup complexity** | How much pre-session configuration | IM needs scenario+tone, Mini-Drill needs nothing |
| **In-session coaching** | Real-time prompts and encouragement | SD has pressure events, AhC has streak messages |
| **Completion ceremony** | Brief mode-specific moment before SummaryView | SD's "Run Over" card, IM's processing indicator |
| **Evaluation emphasis** | Which skills are weighted more heavily | SD weights fillers heavily, Timed weights structure |
| **Copy personality** | Slightly different word choices per mode context | SD: "Hold your nerve" vs AhC: "Clean streak going" |

### The Line Between Flavor and Fragmentation

**Flavor:** SD uses orange tint and pressure language during the active phase.
**Fragmentation:** SD shows a completely different post-session experience with unique celebration logic.

**Flavor:** IM has a 2-stage setup because conversation context matters.
**Fragmentation:** IM uses a separate evaluation service that produces different feedback structure.

**Flavor:** Mini-Drill uses a dark background for focus.
**Fragmentation:** Mini-Drill bypasses RewardEngine and handles celebrations independently.

**Test:** If a new team member looked at two modes side by side, would they think "same app, different exercise" or "different app"? The answer must always be the first.

---

## 10. SwiftUI / Architecture Implementation Guidance

### 1. Session Lifecycle Protocol

```swift
/// Defines the shared session lifecycle that every practice mode implements.
protocol SessionLifecycle {
    /// Current phase of the session
    var phase: SessionPhase { get }
    /// Elapsed seconds since recording started
    var elapsedSeconds: Int { get }
    /// Prepare the session (topic selection, constraint display)
    func prepareSession()
    /// Start the countdown ceremony
    func beginCountdown()
    /// Begin recording
    func startRecording()
    /// End the session (manual or automatic)
    func stopSession()
}

enum SessionPhase: Equatable {
    case setup          // Intent / pre-session
    case countdown(Int) // 3, 2, 1
    case active         // Recording
    case landing        // Brief pause after stop
    case summary        // Evaluation displayed
}
```

Each practice view implements this protocol. The countdown view is a shared component that reads `phase` and renders accordingly.

### 2. Shared Countdown Component

```swift
struct CountdownOverlay: View {
    let count: Int          // Current countdown number
    let tint: Color         // Mode tint
    let visible: Bool

    var body: some View {
        if visible {
            Text("\(count)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .transition(.scale.combined(with: .opacity))
        }
    }
}
```

Used by all modes. Animated with `.snappySpring`. Haptic on each number change via `CoachHaptic.countdownBeat()`.

### 3. Unified Evaluation Interface

```swift
/// Result type shared across all evaluation systems.
struct PracticeResult {
    let score: Int                              // 0-10
    let xpEarned: Int
    let headline: String
    let feedback: String
    let segments: [PracticeScoreSegment]
    let insights: [String]
    let modeSpecificData: ModeSpecificData?
}

enum ModeSpecificData {
    case imConversation(IMConversationDetails)
    case suddenDeath(survivalTime: TimeInterval, pressureLevel: Int)
    case ahCounter(bestStreak: Int, totalFillers: Int)
}
```

All evaluators produce this type. SummaryView consumes it uniformly.

### 4. Reward Event Bus

```swift
// Already implemented in RewardEngine.swift
// All modes emit events through:
RewardEngine.shared.emit(.sessionCompleted(score: 7, xpEarned: 74))
RewardEngine.shared.emit(.scoreIncreased(from: 5, to: 7))

// SummaryView observes and displays:
@StateObject private var rewardEngine = RewardEngine.shared
```

No mode should have its own milestone detection logic. All milestone detection happens in `RewardEngine.evaluateSession()`.

### 5. Haptic Integration Points

```swift
// In every practice view's countdown:
.onChange(of: countdownValue) { _, newValue in
    if newValue > 0 { CoachHaptic.countdownBeat() }
    if newValue == 0 { CoachHaptic.drillStart() }
}

// In SummaryView's setup():
// Already wired: CoachHaptic.xpEarned() at end of XP animation
// Already wired: CoachHaptic.scoreReveal() at score landing (add this)
```

### 6. Background Color Migration

Replace all hardcoded gradients with design system tokens:

```swift
// Before (in TimedPracticeView, SuddenDeathPracticeView, IMPracticeView):
LinearGradient(colors: [Color(red: 0.97, ...), Color(red: 0.93, ...)], ...)

// After:
LightGradientBackground() // Already defined in DesignSystem.swift
// OR for mode-specific active backgrounds:
AppColor.sessionBackground(for: .timed)
```

### 7. Button Standardization

```swift
// Replace all inline button styling with:
PrimaryCTA("Start Drill", icon: "bolt.fill", tint: .blue) { startDrill() }

// For stop/destructive:
PrimaryCTA("Stop", icon: "stop.fill", tint: .red) { stopSession() }

// For secondary:
Button { goHome() } label: {
    Text("Go Home")
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
}
.buttonStyle(.pressable)
```

### 8. Animation Migration

Replace all ad-hoc animation timings:

```swift
// Before:
withAnimation(.easeInOut(duration: 0.35)) { pressurePulse.toggle() }

// After:
withAnimation(.standardSpring) { pressurePulse.toggle() }
```

Exceptions: Linear progress (bars, rings) keep `.linear(duration:)`. Timeline-based continuous animations keep their custom timing.

---

## 11. Priority Rollout Plan

### Wave 1: Consistency Foundation (Eliminate the worst inconsistencies)

1. **Add countdown to Ah-Counter.** 3-2-1 with haptics before recording starts.
2. **Add `sessionComplete()` haptic pattern** to CoachHaptic. Wire into all modes on session end.
3. **Replace inline haptics** in SuddenDeathPracticeView with CoachHaptic calls.
4. **Migrate backgrounds** in Timed, Sudden Death, IM to use AppColor tokens or `LightGradientBackground`.
5. **Replace ad-hoc button styling** with PrimaryCTA/secondary pattern in all modes.

### Wave 2: Shared Lifecycle

6. **Create `CountdownOverlay` shared component.** Use in Timed, Sudden Death, Ah-Counter, Mini-Drill.
7. **Wire `RewardEngine.evaluateSession()`** from SummaryView's setup(). Remove mode-specific milestone logic from individual views.
8. **Add haptic to score reveal** in SummaryView (`CoachHaptic.scoreReveal()`).
9. **Wire `SkillTrendStore.recordFromSession()`** from SummaryView (already done) — verify all modes pass correct data.

### Wave 3: Feedback Unification

10. **Ensure all modes pass `PracticeScoreSegment` data** to SummaryView with consistent label names matching the coaching taxonomy.
11. **Map IM conversation evaluation** dimensions to the shared 10-skill taxonomy.
12. **Add coach note (momentum/leverage/nextStep) support** for IM mode evaluations.
13. **Verify drill recommendation** works for all modes by confirming metrics flow to `DrillEngineV2.recommend()`.

### Wave 4: Animation & Motion

14. **Replace all `.easeInOut(duration: X)`** in practice views with design system springs.
15. **Audit reduced motion support.** Add `@Environment(\.accessibilityReduceMotion)` checks to celebration overlays.
16. **Standardize celebration timing** across all milestone types.

### Wave 5: Polish

17. **Coaching voice audit.** Review all user-facing strings for consistent tone.
18. **Button audit.** Verify every CTA uses the hierarchy (primary/secondary/tertiary/destructive).
19. **Haptic fatigue testing.** Run through full session flows and verify no haptic spam.
20. **Cross-mode walkthrough.** Complete a session in each mode back-to-back and verify the experience feels unified.

---

## Appendix: Current Adherence Scorecard

| Dimension | Current State | Target | Gap |
|-----------|--------------|--------|-----|
| Countdown ceremony | 3/5 modes | 4/5 (IM exempt) | Add to Ah-Counter |
| Haptic coverage | 2/5 modes | 5/5 modes | Add to Timed, Ah-Counter, IM |
| Background tokens | 1/5 views | 5/5 views | Migrate 4 views |
| Button consistency | ~65% | 100% | Audit and replace |
| Animation springs | ~60% | 100% | Replace .easeInOut calls |
| Evaluation pipeline | Fragmented | Unified | Map all modes to shared output |
| Coaching voice | Inconsistent | Unified | Tone audit across all copy |
| Skill taxonomy | Partial | Full 10-area | Map IM evaluation dimensions |
| Reward bus | New | Universal | Wire RewardEngine everywhere |
| Score presentation | Consistent | Consistent | Already good |
