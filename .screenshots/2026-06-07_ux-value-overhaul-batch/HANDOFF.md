# Run: 2026-06-07 · branch:ux-overhaul · HEAD c245cd2 · UX value overhaul batch

## Mode
unavailable

The configured `.Codex/skills/noum-screenshots/.mode` file was missing, so no simulator screenshot sweep was run.

## Changes shipped (this run)
- `Noum/HomeSignalGate.swift` — retired Home utility, Daily Challenge, and Voice Metrics cards from Home, including the advanced-card override path.
- `Noum/SessionHistoryView.swift` — removed visible XP from rep-detail focus/metrics and added evidence-based focus labels.
- `Noum/ContentView.swift` — replaced Home peak-glow overclaim/delta copy with one restrained rating-mark presentation.
- `DesignSystem.swift`, `Noum/PracticeModeSelectionView.swift`, `Noum/HomeCoachCard.swift`, `Noum/AskNoumModeSuggestion.swift` — renamed primary pressure-mode surfaces to Pressure Drill and gated picker availability behind rated evidence.
- `Noum/FriendLeaderboardView.swift` — stopped showing the default starter rating as a social leaderboard score before rated evidence exists.

## Screenshots
- Not captured. Screenshot mode configuration was unavailable.

## VISION gap
The touched surfaces move toward the VISION constraints around believable progress, pressure fairness, and low-noise coaching. Home is less dashboard-like; review surfaces no longer reward poor reps with visible XP; pressure practice is framed as a fair drill instead of a punitive mode.

## Next steps to reach desired state
1. Run a light or detailed screenshot sweep after restoring `.Codex/skills/noum-screenshots/.mode`.
2. Continue the pre-speak funnel compression in `Noum/PracticeModeSelectionView.swift` and `Noum/HomeCoachCard.swift`.
3. Audit historical/export pressure-mode strings outside primary entry surfaces before a full product rename.

## Regressions checked
- Home card gating — focused `HomeSignalGateTests` and `HomeSignalGateEdgeTests` passed.
- Session review XP demotion — focused `SessionHistoryRowPreviewTests` passed.
- Peak glow copy — focused `PeakGlowGatingTests` passed.
- Pressure mode picker copy/gating — focused `PracticeModeRowExpansionTests` and `PracticeModePrescriptionCopyTests` passed.
- Ask Noum pressure launch label — focused `AskNoumModeSuggestionTests` passed.
- Social zero-data rating gate — focused `BelievableProgressZeroDataTests` passed.

## Surfaces needing visual verification
- Home top with returning-user data.
- Practice mode picker cold state and rated state.
- Session detail review card.
- Friend leaderboard with no rated evidence.
- Ask Noum mode suggestion card.

## For next run
- **If cloud**: continue logic/copy audits that do not need the simulator.
- **If local**: restore screenshot mode config and capture Home, Train, Review, Profile, Settings, plus a cold Practice picker.
