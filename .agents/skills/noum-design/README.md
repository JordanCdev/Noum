# Noum Design System

Noum is a gamified public-speaking coach for iOS. Speakers open the app, pick a short drill, and get real-time coaching on filler words, pacing, and structure via Amazon Transcribe streaming. The product is built around short daily reps that feed an XP/rank ladder, a "Path" journey, active challenges, and an AI-driven next-best-rep recommender.

The design brief asked for **"professional but fun"** — aimed squarely at beating the notoriously low Day-7 retention of education apps. That tension — credible coaching AND delight — drives every call in this system.

## Sources

All tokens, components, and visual behaviour in this system were lifted directly from the Noum iOS source:

- **GitHub repo:** `JordanCdev/Noum` (private) — `main` branch
- **Canonical design token file:** `DesignSystem.swift` — corner radii, spacing scale, `AppColor` palette, springs, shared SwiftUI components (`CardView`, `StatCard`, `PrimaryCTA`, `PressableButtonStyle`, `LightGradientBackground`, `SectionHeader`, `ErrorCard`)
- **Gamified primitives:** `Noum/GamifiedViews.swift` — `ShimmerProgressBar`, `PulseBadge`, `SparkleRibbon`
- **Core screens referenced:** `Noum/ContentView.swift` (Home), `Noum/LoginView.swift` (auth), `Noum/PracticeModeSelectionView.swift` (drill picker), `Noum/SplashScreenView.swift`
- **Copy voice sample:** `Noum/ContentView.swift` recommendation strings, `Noum/PracticeModeSelectionView.swift` mode descriptions

The reader is not assumed to have repo access — everything needed to design on-brand lives in this folder.

## Index

| File | What's in it |
|---|---|
| `README.md` | This file — product context, content + visual foundations, iconography |
| `colors_and_type.css` | CSS custom properties for every color and type style, plus semantic element defaults |
| `SKILL.md` | Claude Code / Agent Skill descriptor |
| `fonts/` | Webfont placeholder — Noum uses SF Pro Rounded on-device; see Typography section |
| `assets/` | Logos, app icon, illustration placeholders, SF Symbol usage notes |
| `preview/` | Design-system cards (colors, type, spacing, components, brand) |
| `ui_kits/ios-app/` | Pixel-close React recreation of the Noum iOS app (Home, Mode Picker, Practice, Summary, Login) |

---

## Product context

**What it does.** Noum listens to you speak, transcribes live via Amazon Transcribe, and gives you a filler-word-aware score plus coaching. It is deliberately NOT a video-course app — all the value is in the short recorded rep.

**The four practice modes (tints are canonical):**

| Mode | Tint | What it trains |
|---|---|---|
| **Timed Practice** `modeTimed` | Brand blue `#3378F5` | Fuller, cleaner complete answers under a soft clock |
| **Sudden Death** `modeSuddenDeath` | Warm orange `#F28C26` | Pressure tolerance — one filler ends the round |
| **Ah-Counter** `modeAhCounter` | Forest green `#249970` | Real-time filler + pacing awareness while you speak freely |
| **IM Mode** `modeIM` | Indigo `#526EF0` | Live AI-driven conversation reps with tone/scenario control |

**Gamification surfaces.** Speaking Rank (XP → Speaker 1..N), weekly challenges, a Path journey, streak tracking, and sparkle/shimmer/pulse motion on anything celebratory. This is where the "fun" half of the brief is earned.

**AI surface.** A server-backed `AIHomeRecommendationService` produces the home screen's "Recommended next" card and a recent-sessions analyzer. Everything AI-generated is presented as concrete, short, imperative coaching copy — never in assistant-speak.

---

## CONTENT FUNDAMENTALS

Tone is the hardest thing to keep on-brand. Noum's voice is **a trusted speaking coach who has heard your last five reps** — direct, encouraging, specific, and a little warm. Never chirpy, never corporate, never self-conscious about being an app.

### Voice rules

1. **Second person, imperative-leaning.** Address the speaker as "you". Use imperatives for actions: *"Push a sharper timed rep."* *"Slow the pace without losing control."*
2. **"Noum" as a character, not a product name.** The app refers to itself in the third person where it must: *"Noum is already leaning toward what will help most right now."* Never *"our app"*, *"we"*, or *"the system"*.
3. **Concrete targets, not vibes.** Every recommendation carries a measurable: `<150 WPM`, `30s+`, `Zero fillers`, `<1 filler`. Targets live in their own small element next to the card copy.
4. **Speaking-world vocabulary, consistently.** *rep*, *drill*, *answer*, *opening*, *delivery*, *pacing*, *composure*, *filler*, *pressure*, *clean rep*, *push*, *lean into*. Avoid generic fitness-app language like *workout*, *session* (reserve for history).
5. **Sentence fragments are fine in UI.** Full sentences in coaching explanations.
6. **No "Let's".** No "Great job!". No emoji-in-copy. Celebrate with motion + color, not words.
7. **Never apologise for the AI.** If conversation mode is down, say *"Conversation mode is offline right now, so train the same control in a live speaking drill."* — re-route, don't excuse.

### Casing

- **Sentence case for everything** except labels that behave as micro-categories: `Recommended Practice`, `Active Challenge`, `All Drills`. These use Title Case + `textCase(.uppercase)` + `tracking 0.8` in the iOS app.
- **Button labels** are one or two words: `Start`, `Begin`, `Continue`, `Review`, `Try without an account`.
- **Nav items** are one word, uppercase, tracked: `TRAIN`, `REVIEW`, `SOCIAL`, `SETTINGS`.

### Examples lifted from production

**Hero / splash**
> noum — Sharper speaking, one rep at a time.

**Login headline**
> Speak with more clarity.
> Practice out loud. Get real-time coaching. Sound like the person you want to be.

**Home greeting**
> Hello, Jordan — Ready to level up your speaking?

**Recommendation titles (short, active)**
- *Push a sharper timed rep*
- *Step up into pressure*
- *Clean up the next opening*
- *Slow the pace without losing control*
- *Extend the next answer*
- *Lean into the pressure rep*
- *Graduate to a harder rep*
- *Start with a clean baseline rep*

**Recommendation bodies (one sentence, causal)**
- *Your filler control is strong enough to push into a harder mode.*
- *Too many fillers usually means the pressure is too high right now.*
- *The message is getting rushed, so the next rep should train calmer spacing.*
- *Your answers are ending too early to build real speaking stamina.*

**Mode descriptions (subtitle under drill titles)**
- Timed: *"Choose a difficulty, take a beat, and build a full answer with structure."*
- Sudden Death: *"Start immediately and stay alive without a single filler word."*
- Ah-Counter: *"Speak freely while Noum tracks fillers and pacing in real time."*
- IM Mode: *"Train tone, pacing, realism, and relationship impact inside a live conversation."*

### Emoji

**No emoji in product copy.** The `ios_app` codebase contains zero emoji characters in user-facing strings. All iconography is SF Symbols. When you need a celebratory feel, use `SparkleRibbon` + `PulseBadge` + tint color — not 🎉.

---

## VISUAL FOUNDATIONS

### Colors

A bright, optimistic, pastel-forward palette with four saturated mode-tints that carry real meaning. The default surface is the iOS system grouped background (a very faint warm grey); cards are pure white. No dark mode in the shipped app.

- **Backgrounds:** `screenBackground` (systemGroupedBackground), `lightGradientStart → lightGradientEnd` (a very faint blue-violet gradient used on setup/selection screens), `innerSurface` (near-white `#F7F7FA` for transcripts / inner containers).
- **Brand:** `brandBlue #3378F5` → `brandBlueLight #42A1FF` gradient. `pro #8F47EB` → `proLight #D185FF` for premium.
- **Mode tints** (see table above) are used as both solid fills (capsule CTAs) and 10–14% opacity wash fills (mode cards).
- **Semantic feedback:** `positive #199966`, `caution #D4851A`, `warning #BD3833`.
- **Text:** `textPrimary #212633` (a warm near-black), `textSecondary #697382`.
- **Strokes:** Black @ 5% for subtle borders, Black @ 4% for tag chips.

### Typography

**SF Pro Rounded** is the signature face. The "Rounded" weight choice is the single biggest driver of Noum's "professional but fun" feel — it reads credible without being stern. Body copy uses the **system default (SF Pro Text)** via SwiftUI `.font(.subheadline)` / `.body`. Specimens:

| Role | Size / weight | Notes |
|---|---|---|
| Display (splash) | 42 / bold / rounded | `Noum` splash |
| Hero headline | 40 / bold / rounded | Login "Speak with more clarity." |
| Screen title | 30 / bold / rounded | "Choose your next rep" |
| Section hero | 26 / semibold / rounded | "Hello, Jordan" |
| Card title | 28 / bold / rounded | "Speaker 1", big stat values |
| Default headline | 18 / bold / rounded | Recommendation titles |
| Subhead | 16 / medium | Login subcopy |
| Body | 15 / regular | Mode description text |
| Caption | 13 / semibold | Labels, targets, badges |
| Micro label | 10 / bold / rounded + `tracking(0.8)` + uppercase | "RECOMMENDED PRACTICE" |
| Nav label | 10 / semibold / rounded + `tracking(0.4)` + uppercase | "TRAIN" |

Noum uses `.tracking(4)` on the uppercase `NOUM` wordmark and `.tracking(0.4–0.8)` on uppercase micro-labels. Line heights follow system defaults; `fixedSize(horizontal: false, vertical: true)` is common on multi-line titles.

### Spacing

An 8-point grid with named aliases:

```
xxs  4    (tight pairs)
xs   8    (icon+label)
sm   12   (inner)
md   16   (default content spacing)
lg   20   (section-level + screen horizontal padding)
cardGap 14 (between cards)
```

### Corner radii

Noum uses **four radii** and sticks to them:

```
small  12  chips, tags, inner containers
medium 18  stat cards, secondary containers, non-capsule buttons
large  24  primary content cards
xl     28  hero cards, full-width panels, sheets
```

Capsule shapes (`.continuous`) are used for CTAs and the bottom nav pill. **Never mix a 16 with a 20** — pick from the scale.

### Backgrounds

- Default screens use a flat warm-grey `systemGroupedBackground`.
- Setup / selection screens (Practice Mode picker, coaching onboarding) use `LightGradientBackground` — a very subtle top-leading→bottom-trailing blue-violet gradient from `#F7F7FF` to `#EDF2FF`.
- The Login screen goes dark: a `#14182D → #1E1E38 → #2D2A38` vertical gradient with three large blurred accent orbs (blue top-right, warm orange top-left, cool blue bottom) at 10–25% opacity and ~80px blur. This is the only dark surface in the product.
- The Splash screen uses light bg + two large soft-blurred orbs (blue @16%, orange @14%) that animate in opposition. Same orb motif recurs on the login background.

**No hand-drawn illustrations. No repeating textures. No grain. No image-heavy full-bleed hero.** The visual richness comes from motion + color + shape, not imagery.

### Imagery colour vibe

If product photography ever ships: warm, daylight, natural skin tones, shallow DOF. Never cool, blue-shifted, or moody. Speaking is a human act — photos should feel like someone mid-sentence, not mid-grief-ad.

### Animation & motion

Three named springs, used consistently:

```
standardSpring  response 0.34  damping 0.84   cards, toggles, selection
snappySpring    response 0.26  damping 0.88   chips, tabs, button press
bouncySpring    response 0.40  damping 0.65   celebrations, emphasis only
```

Ambient motion primitives (always running, never triggered):

- **ShimmerProgressBar** — a 2.4s-loop specular sweep traveling across the filled portion of a progress bar.
- **PulseBadge** — a 1.8s-loop breathing circle around any mode/rank icon (`0.92 ↔ 1.04` scale).
- **SparkleRibbon** — 5 staggered SF Symbol sparkles twinkling at 20fps.
- **Symbol pulse** — bottom nav icons use `symbolEffect(.pulse, options: .repeating.speed(0.6))`.
- **Splash orbs** — two blurred circles move in opposite directions on a 1.8s / 2.1s `easeInOut.repeatForever(autoreverses: true)`.

Transitions between recommendation states use `.move(edge: .top).combined(with: .opacity)`.

### Hover / press states

iOS has no hover. Press is standardised on `PressableButtonStyle`:

- `scaleEffect 0.97` when pressed
- `opacity 0.85` when pressed
- Animated with `snappySpring`

Web recreations MUST match: 0.97 scale + 0.85 opacity on `:active`. Hover on web uses a mild darken (filter `brightness(0.96)`) — NO underlines, no colour-shift.

### Borders, shadows, strokes

Cards use a **soft border + optional tint-coloured shadow**, never a hard stroke:

- Default card border: `Color.white.opacity(0.72)`, 1pt — this is how cards sit on the light gradient background.
- Recommendation card border: linear-gradient white-to-mode-tint @ 12%, 1.2pt.
- Selected drill card border: mode tint @ 26%, 1pt + `shadow(color: tint.opacity(0.10), radius: 16, y: 8)`.
- Inner containers (stats, transcript boxes): no border, just `innerSurface` fill.
- The bottom nav pill uses `.regularMaterial` (system blur) + `Color.white.opacity(0.55)` stroke.

**No inner shadows.** **No `box-shadow: 0 4px 6px rgba(0,0,0,.1)` defaults.** Shadows are always tinted with the mode colour.

### Transparency and blur

Blur is used sparingly, and always meaningfully:

- `.regularMaterial` behind the bottom-nav pill and behind the fixed bottom CTA on the mode picker — both cases where content scrolls beneath a floating control.
- `blur(radius: 16–100)` on background orbs (login, splash) for soft glow.
- Never blur behind regular content cards. Never blur text.

### Protection gradients vs capsules

Fixed bottom controls sit on a **vertical white-opacity gradient** (`white@2% → white@72%`) that fades content behind them, rather than a hard bar. The gradient belongs to the parent, not the pill — the pill itself is an opaque `.regularMaterial` Capsule.

### Layout rules (fixed elements)

- **Bottom nav pill** is present on every root-tab screen: Home, Train, Review, Social, Settings. Lives inside `safeAreaInset(.bottom)`, 18pt h-padding from screen edges, capsule shape.
- **Bottom "Start" CTA** appears on the Practice Mode Selection screen above the nav. Same safe-area inset pattern.
- **Scroll area** uses `showsIndicators: false` throughout.
- **Screen horizontal padding:** 20pt (`Spacing.screenH`).
- **Inter-card gap:** 14pt (`Spacing.cardGap`).
- **Hero copy** scrolls at 1:1 up to fade — `opacity: 1 + (offset / 42)` and height collapses with scroll. Do not pin headers.

### Cards — the atomic unit

A Noum card is:
- White fill (`AppColor.cardBackground`)
- 24pt (`large`) or 28pt (`xl`) continuous corner radius
- 20pt (`lg`) internal padding
- 1pt `white@72%` stroke as a soft inner edge
- Optional tint-coloured shadow at 8–10% opacity, 12–16pt radius, 4–8pt y-offset
- No gradient fills on cards themselves — gradients are reserved for CTA backgrounds and suggestion hero washes

A "mode wash" card (the suggestion link) overrides the white fill with a diagonal `tint@10% → tint@5%` linear gradient and a `tint@10%` stroke.

---

## ICONOGRAPHY

**Noum uses Apple's SF Symbols exclusively.** There is no custom icon set, no icon font shipped with the app, no SVG sprite. Every glyph in the product is a system symbol rendered with SwiftUI `Image(systemName:)`.

### Symbol usage conventions

- **Weight:** `.bold` for mode badges, nav icons, action chevrons; `.semibold` for section headers.
- **Size:** 16–20pt inside badges; 18pt for mode tiles; 14pt (`.caption`) for inline chevrons.
- **Fill vs stroke:** Noum reaches for **filled variants first** (`bolt.fill`, `waveform.and.mic`, `checkmark.circle.fill`). Outline variants only show selection-inverse states (e.g. unselected radio: `circle`).
- **Color:** Always a single tint via `.foregroundStyle(tint)`. Symbols are never multi-colour except the `SparkleRibbon` mini-composition.

### The canonical Noum symbol vocabulary

Used across screens — lift these exact names when recreating:

| Symbol | Meaning in Noum |
|---|---|
| `timer`, `clock.fill` | Timed mode |
| `bolt.fill` | Sudden Death mode |
| `waveform`, `waveform.and.mic` | Ah-Counter / live audio |
| `bubble.left.and.bubble.right.fill`, `message.badge.waveform.fill` | IM Conversation mode |
| `dumbbell.fill` | Train (nav) |
| `book.fill` | Review / Session History (nav) |
| `person.2.fill` | Social (nav) |
| `slider.horizontal.3` | Settings (nav) |
| `sparkles`, `star.fill`, `sparkle` | Rank ornaments, sparkle ribbon |
| `figure.stand`, `figure.mind.and.body` | Rank / coaching identity |
| `waveform.path.ecg` | Analytics / rank |
| `shield.lefthalf.filled` | Professional rank |
| `crown.fill` | Top rank |
| `point.topleft.down.curvedto.point.bottomright.up.fill` | Your Path |
| `chevron.right` | Nav disclosure on cards |
| `exclamationmark.triangle.fill` | Error state |
| `checkmark.circle.fill` / `circle` | Selected / unselected |
| `arrow.right` | CTA chip |
| `mic.fill` | Recording active |

### On the web / in prototypes

SF Symbols are **not** licensed for web use, so the iOS codebase is the authoritative source, and any web/prototype work must substitute.

**Substitution (flagged to the user):** Noum's web prototypes use **Lucide Icons** at `1.75px` stroke weight (matches SF Symbols `.bold`). A one-to-one mapping lives in `assets/icon-map.md`. When an SF Symbol has no clean Lucide equivalent (`figure.mind.and.body`, `point.topleft...`), fall back to the closest Lucide match and note it in the component JSDoc.

⚠️ **Flagged substitution:** Lucide is a stand-in. For pixel-perfect iOS mocks, request rendered SF Symbol PNGs from Jordan or screenshot-import from Xcode. For web / marketing surfaces, Lucide is the design-system choice.

### Logos & brand marks

Noum does not ship a wordmark asset file in the repo — the word **"noum"** is set in SF Pro Rounded Bold, all-lowercase for the splash/launch and all-uppercase with `tracking(4)` for the login eyebrow. Both treatments are captured in `assets/logo-wordmark.svg` and `assets/logo-eyebrow.svg`.

### Emoji

**Not used.** See Content Fundamentals.

### Unicode as icon

**Not used.** Everything that looks like a glyph is an SF Symbol.

---

## Open questions / flagged substitutions

1. **SF Pro Rounded webfont** — not freely redistributable. This system substitutes **Nunito** (500/600/700/800) from Google Fonts, which is the closest open geometric-rounded available. Request: designer to supply Apple Fonts SF Pro Rounded `.otf` files + a confirmation that web use is in-scope.
2. **SF Symbols** on web — substituted with **Lucide**. Request: confirm Lucide is acceptable for marketing web, or provide a bespoke icon set.
3. **No marketing site / docs site / Android app** was in the repo — UI kit covers the iOS app only.
