// README for the iOS UI Kit

# Noum · iOS UI Kit

Pixel-close React recreation of the five key screens in the Noum iOS app.

## Files

- `Primitives.jsx` — shared building blocks: `Icon`, `Card`, `Pressable`, `ShimmerBar`, `PulseBadge`, `SparkleRibbon`, `CapsuleCTA`, `MicroLabel`, `MODES` metadata
- `HomeScreen.jsx` — greeting hero, Speaking Rank card with shimmer bar + challenge, Your Path card, Recommended Practice card, bottom nav pill
- `Screens.jsx` — `ModePickerScreen` (light-gradient bg), `PracticeScreen` (live mic + transcript + big record button), `SummaryScreen` (score + stats + next-rep), `LoginScreen` (dark gradient + orbs)
- `index.html` — interactive click-through demo wiring all screens inside an iOS frame

## Mapping to source

| Screen | Source file |
|---|---|
| Home | `Noum/ContentView.swift` |
| Mode Picker | `Noum/PracticeModeSelectionView.swift` |
| Practice (live) | `Noum/TimedPracticeView.swift` (compositionally — live transcript from `SpeechRecognizerViewModel`) |
| Summary | `Noum/SummaryView.swift` |
| Login | `Noum/LoginView.swift` |

## Known liberties

- SF Symbols substituted with inline Lucide-style SVGs (see `assets/icon-map.md`)
- Nunito substituted for SF Pro Rounded (flagged)
- Live transcript is static demo text, not AWS-wired
- Recommendation card uses a fixed "Push a sharper timed rep" — real app pulls from `AIHomeRecommendationService`
