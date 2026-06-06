# Run: 2026-05-17 · branch:Redesign · M14 Home redesign v1 (integrated) — coach-voice hero

The Home is now a coach speaking, not a dashboard. 5 parallel agents wrote it; one integration pass merged + dedup'd it; build green; tour passes; all 27 surfaces captured cleanly.

## Mode
`light` (`.claude/skills/noum-screenshots/.mode`). Detailed tour ran this session.

## What shipped (5 agents, 1 integration pass)

| Delta | Files | Status |
|---|---|---|
| New `HomeCoachCard.swift` — one hero with NoumCharacter + coach copy + Begin CTA | [Noum/HomeCoachCard.swift](Noum/HomeCoachCard.swift) | ✓ |
| Peak hero demoted from default Home → post-session glow only | [Noum/RatingEngine.swift](Noum/RatingEngine.swift) (+ pendingPeakGlow API), [Noum/ContentView.swift](Noum/ContentView.swift), [Noum/AuthManager.swift](Noum/AuthManager.swift) | ✓ |
| `NoumCharacter.Inline` variant + `moodPulse` hook + `SectionHeader` glyph param | [Noum/NoumCharacter.swift](Noum/NoumCharacter.swift), [DesignSystem.swift](DesignSystem.swift) | ✓ (built, not yet used in Home headers — future polish) |
| `DailyChallengeTile` coach-voice rewrite (5 states) + `journeyPreviewCard` rewrite with `GatingPhrase` helper | [Noum/DailyChallengeTile.swift](Noum/DailyChallengeTile.swift), [Noum/PathProgressManager.swift](Noum/PathProgressManager.swift), [Noum/ContentView.swift](Noum/ContentView.swift) | ✓ |
| Pillars removal — pushback: no pillars existed in code | — | ✓ (correct pushback) |
| `HomeUtilityStrip.swift` — slim streak + word-of-day row under Coach Card | [Noum/HomeUtilityStrip.swift](Noum/HomeUtilityStrip.swift) | ✓ |
| Integration pass — wire HomeCoachCard + HomeUtilityStrip into ContentView populated stack | [Noum/ContentView.swift](Noum/ContentView.swift) | ✓ |
| Dedup fix — removed HomeCoachCard's built-in utility strip (was duplicating HomeUtilityStrip) | [Noum/HomeCoachCard.swift](Noum/HomeCoachCard.swift) | ✓ |
| Cleanup — removed orphaned helpers (utilityStrip, streakShortcut, wordOfDayShortcut, related vars) | [Noum/HomeCoachCard.swift](Noum/HomeCoachCard.swift) | ✓ |

## Before vs after — the Home story

**Before** (`.screenshots/2026-05-17_baseline/tour_01-home-top.png`): purple Peak Rating hero ("Your highest rating yet — 624") → greeting "Good evening, Speaker" → Quick start (Zero Filler Challenge) → Today rep card (3 to go, Goal hit) → Word of the day (Tangible) → This Week → ... = 5+ competing cards before scroll. Victory lap before today's rep.

**After** (`.screenshots/2026-05-17_redesign-v2/tour_01-home-top.png`):
- ONE Coach Card with NoumCharacter present
- Coach line: *"Filler control. Verbal clutter is still costing clarity, so awareness needs to happen live."* — directly from `RecommendationBiasEngine`'s blueprint
- Mode·time·target micro-label: `AH-COUNTER · 90 SEC · ZERO FILLER START`
- One green Begin CTA
- ONE slim utility strip: `🔥 1 day streak | Word: Tangible ›`
- Below: Today (challenge in coach voice), This Week (AI insight in coach voice), Next (path node with concrete gating: "First IM rep / One rep in IM Mode from unlocked")
- Peak hero only appears after the user finishes a rep that raises their week peak — 7s glow then fades

## Coverage gaps still open (not blocking)

- NoumCharacter.Inline glyph in section headers — agent built it, integration to Home section headers deferred (~15 min polish)
- Pause Metrics + Word Choice Metrics as first-class summary surfaces (VISION underweight, separate effort)
- In-rep goal-aware HUD (M5 stub) — wired for cloud routine 6 to grind nightly
- iMessage / Watch / Live Activity real-device QA

## VISION gap closing

Pillar 5 (personalized coaching): Home is now a per-user coach surface, not a generic dashboard. The recommendation pipeline that already existed (`RecommendationBiasEngine` + `CoachingPlanner`) finally HAS a hero surface that respects its output. This is the M14 "TestFlight-ready feel" delta.

Anti-goal honored: not punish-shaming on regression (peak glow only fires upward, journey card "next clean rep" framing only), no shallow gamification expansion (rank pill demoted from above-fold), no exclamation marks, no emoji in copy.

## Regressions checked
- Profile: PeakRatingWallCard intact, visible on scroll. Speaker rank card + trend chart preserved.
- Review: unchanged. Mistakes to Fix copy not touched (separate from Agent 4's scope).
- Settings: unchanged.
- All 27 detailed tour surfaces re-captured in v2; spot-checked Home, Profile, Review.
- Existing deep links + `UI_TESTING_SEED_FORCE` + screenshot hook all functional.

## For next run
- **If cloud**: read the routine prompts at [`.routines/`](.routines/). When Jordan installs them in claude.ai's scheduled-tasks UI, they'll start running.
- **If local**: visual verification of new Home looks great; polish opportunities = SectionHeader glyph integration, and a fresh design eye on the secondary stack (Today / This Week / Next) cards.
