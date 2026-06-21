# Run: 2026-06-21 - ux-overhaul - de38004 - Voice target icons

## Mode
light + focused voice-target captures

## Changes shipped
- `Noum/DrillSystem.swift` centralizes `SpeakingStyleGoal.voiceIconSystemName`.
- `Noum/VoiceAlignmentChip.swift` adds reusable `VoiceGoalIcon` and voice tint mapping.
- `ProfileView.swift` uses the chosen voice target icon in the identity header.
- `Noum/CoachingOnboardingView.swift` uses voice-specific icons for style goal summary and option rows.
- `Noum/VoiceAnchorBanner.swift` uses the voice target icon in the live anchor banner.
- `Noum/SettingsView.swift` uses the voice target icon in the coaching profile tag.
- `NoumTests/NoumTests.swift` covers the icon mapping contract.

## Screenshots
- `01_home_top.png` - Home card with shield icon in "Toward your authoritative voice".
- `01_profile_top.png` - Profile header with large authoritative shield and small subtitle shield.
- `02_goal_refresh.png` - Direction check surface with shield icon in the voice chip.
- `01_train_top.png`, `01_review_top.png`, `01_settings_top.png` - light tab captures.

## VISION gap
Voice goals now have differentiated visual identity without replacing the live coach/mic orb where it communicates state. A custom illustrator or animator can replace these SF Symbol mappings later from one enum-backed source of truth.

## Regressions checked
- Focused tests passed.
- App compiled through edited SwiftUI files.
- Profile, Home, and goal-refresh captures render and show no obvious text overlap.

## Surfaces needing visual verification
- Onboarding style-option row icons compiled but were not manually tapped through in this screenshot pass.
- Settings coaching profile tag was updated, but `01_settings_top.png` landed in a practice settings context rather than the exact profile-card surface.
