# UX remediation screenshot handoff

- Date: 2026-07-20
- Branch: `ux-overhaul`
- Base commit: `43f5185fd`
- Screenshot mode: `light`, with the deterministic detailed UI tour used as the authenticated fallback
- Simulator: iPhone 17, iOS 26.4 (`BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E`)

## Product intent

This pass serves M14 launch quality and reinforces believable progress, personalized coaching, and real-world transfer. It removes contradictory state, navigation chrome collisions, jargon-heavy evidence copy, and disconnected post-rep rewards while preserving the existing stores, case file, recommendation engine, destination routing, and summary state owners.

## Screenshot findings resolved

1. Path no longer reports a rhythm beside zero practiced days, uses a concrete next action, presents human gate copy, and does not let the root tab bar obscure the journey.
2. Coaching evidence is now a focused pushed destination: root tabs are hidden, duplicate Ask Noum actions are suppressed, and coach-loop language is user-facing.
3. Train and other scroll roots reserve tab clearance inside their content, eliminating the large dead viewport and clipped lower cards.
4. Coaching evidence prioritizes the active intervention over a conflicting generic trend, and malformed target punctuation is normalized.
5. The exercise picker cannot show a selected Timed Practice row while offering an active Pressure Drill CTA; unselected previews ask the user to select first.
6. Path navigation uses opaque toolbar treatment and hides root tabs on the pushed journey.
7. Personal-best celebration has an opaque dark base, readable contrast, reduced-motion behavior, and a coaching-directed CTA.
8. XP/achievement bookkeeping no longer blocks the coaching summary; meaningful progress is consolidated into one inline receipt.
9. Weekly check-in is a one-answer-first flow with optional detail and explicit save guidance.
10. Settings and history content can scroll above the floating tab bar instead of ending underneath it.
11. Profile coaching copy is coherent with the current plan, and the forming rating explains what evidence is still needed.
12. Peer comparison uses one honest unavailable state instead of simultaneously saying verification is pending and the group is forming.
13. Upcoming-moment intake has stable toolbar separation, clearer `Performance review` naming, an explicit required title, and an add/remove date action instead of a switch.
14. Level-up celebration has an opaque dark base and routes directly to the coaching read.
15. Achievement celebration uses the same calm, readable progression language and no longer chains into another reward interruption.

## Verified screenshots

- Root and scroll behavior: `tour_01-home-top.png` through `tour_13-mode-picker.png`
- Practice setups: `tour_14-timed-setup.png` through `tour_18c-roleplay-setup.png`
- Social/path destinations: `tour_22-league.png`, `tour_24-path-journey.png`, `tour_25-path-journey-bottom.png`
- Weekly reflection: `tour_28-weekly-check-in-sheet.png`
- Results-first summary: `tour_S-summary-1top.png`, `tour_S-summary-2mid.png`, `tour_S-summary-3bottom.png`
- Consolidated progress/celebrations: `tour_33-post-session-progression.png` through `tour_36-achievement-unlock-celebration.png`
- Upcoming moment: `tour_37-big-moment-intake-top.png`, `tour_38-big-moment-intake-bottom.png`

The initial `01_*` and `check_home*` captures are retained as diagnostics only: the unauthenticated light-launch harness remained on account bootstrap. The authenticated deterministic UI tour completed successfully and supplied the reviewable captures above.

## Verification

- Release simulator build: passed.
- Full `NoumTests` target: 4,551 tests passed.
- Full advancement screenshot tour: passed.
- Focused summary and celebration tour: passed.
- Focused upcoming-moment intake tour: passed.
- `git diff --check`: passed.

## Remaining visual checks

- Repeat the five-tab light sweep with a real signed-in local account when validating production account hydration; the deterministic seeded tour covers the code changes in this handoff.
- Recheck the edited sheets at the largest accessibility text sizes during the release accessibility pass.

## Files changed

- Shared layout and routing: `DesignSystem.swift`, `Noum/AppShellView.swift`, `Noum/SettingsView.swift`, `Noum/SessionHistoryView.swift`
- Path/train: `Noum/PathJourneyView.swift`, `Noum/PathProgressManager.swift`, `Noum/PracticeModeSelectionView.swift`
- Coaching/profile: `ProfileView.swift`, `Noum/CaseReviewCard.swift`, `Noum/WeeklyCheckInCard.swift`
- Social/upcoming moments: `Noum/LeagueView.swift`, `Noum/BigMomentStore.swift`, `Noum/BigMomentIntakeView.swift`
- Results/progression: `Noum/SummaryView.swift`, `Noum/AchievementIconView.swift`, `Noum/CelebrationViews.swift`
- Regression coverage: `NoumTests/*`, `NoumUITests/ScreenshotTour.swift`
