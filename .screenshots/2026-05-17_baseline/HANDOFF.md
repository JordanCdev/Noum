# Run: 2026-05-17 · branch:Redesign · HEAD 9792edc · screenshot infra complete (27-shot detailed mode)

Bootstrap of the screenshot+handoff workflow. Both `light` and `detailed` modes verified end-to-end. The [noum-screenshots skill](../../.claude/skills/noum-screenshots/SKILL.md) owns capture.

## Mode
`light` (set in [.claude/skills/noum-screenshots/.mode](../../.claude/skills/noum-screenshots/.mode)). Detailed mode covers 27 surfaces — say "screenshots detailed" or "run detailed sweep" to invoke.

## Changes shipped (this run)

### Deep-link infrastructure (enables `light` mode)
- [Noum/ContentView.swift:1479-1497](Noum/ContentView.swift:1479) — tab-level `noum://` deep links: `train`, `review`, `profile`, `settings`, `home` + aliases.
- [Noum/ContentView.swift:290-294](Noum/ContentView.swift:290) — `.onAppear` consumes any pending URL set before mount.
- [Noum/NoumApp.swift](Noum/NoumApp.swift) — `-DeepLink <noum://...>` launch arg handler.

### Tour infrastructure (enables `detailed` mode)
- [Noum/NoumApp.swift:27-65](Noum/NoumApp.swift:27) — `UI_TESTING_SEED_FORCE` always reseeds. Suppresses tier-promotion / daily-goal / path-node / lesson celebration overlays after seed.
- [Noum/NoumApp.swift:66-77](Noum/NoumApp.swift:66) — `FORCE_GOAL_REFRESH` + `FORCE_NOTIFICATION_PROMPT` launch args set the respective manager flags so conditional sheets fire on demand for tour capture.
- [Noum/LeagueManager.swift:191-204](Noum/LeagueManager.swift:191) — `suppressCelebrationsForTesting()` stamps current tier as seen + clears pending promotion.
- [Noum/SessionHistoryView.swift:143](Noum/SessionHistoryView.swift:143) — added `history.row.<uuid>` accessibility identifier so the tour can tap the first row to capture session detail.
- [NoumUITests/ScreenshotTour.swift](NoumUITests/ScreenshotTour.swift) — rewritten. Captures **27 surfaces** in ~3 min via `xcodebuild test`. Uses `launchSeededAt(deepLink)` and `launchSeededWith(extraArgs:)` helpers for clean per-screen launches.

### Skill + auto-capture hook
- [.claude/skills/noum-screenshots/SKILL.md](.claude/skills/noum-screenshots/SKILL.md) — three modes (off/light/detailed) with full recipes.
- [.claude/skills/noum-screenshots/.mode](.claude/skills/noum-screenshots/.mode) — single-line mode toggle, default `light`.
- [.claude/skills/noum-screenshots/capture.sh](.claude/skills/noum-screenshots/capture.sh) — executable, runs at session end via hook. Silent no-op on non-Darwin, off mode, sim not booted, or app not installed.
- [.claude/settings.json](.claude/settings.json) — `SessionEnd` hook wired to capture.sh with 60s timeout.
- [.gitignore](.gitignore:35-39) — PNGs gitignored, HANDOFFs commit.

## Screenshots — 27 surfaces (detailed mode)

### Tabs + scroll states (12)
- `tour_01-home-top.png` → Home with Personal Best hero (624 peak), greeting, Today rep card.
- `tour_02-home-mid.png` / `tour_03-home-bottom.png` → Home scrolled.
- `tour_04-profile-top.png` / `tour_05-profile-mid.png` / `tour_06-profile-bottom.png` → Profile: hero, trend chart, Mode Mastery.
- `tour_07-review-top.png` / `tour_08-review-bottom.png` → Review: stats, Replay Misses, Mistakes to Fix, All Sessions.
- `tour_10-settings-top.png` / `tour_11-settings-mid.png` / `tour_12-settings-bottom.png` → Settings: account, difficulty, coaching profile, language, ambience.

### Session detail (1)
- `tour_09-session-detail.png` → Tapping a row in Review opens this view: score, focus next, mode/duration/fillers/WPM breakdown, See Full Review.

### Mode picker + every practice mode setup (6)
- `tour_13-mode-picker.png` → "Pick your next rep" — all modes listed.
- `tour_14-timed-setup.png` → Impromptu setup with Classic/Coach themes, theme filter, preferences.
- `tour_15-sudden-death-setup.png` → Pressure Drill with difficulty selector + Best: Round 3.
- `tour_16-ah-counter-setup.png` → Ah-Counter mode setup.
- `tour_17-im-conversation-setup.png` → IM Conversation mode setup.
- `tour_18-cut-the-crutch-setup.png` → Avoiding "really" with word picker + prompt.

### Lessons + Speech Projects (3)
- `tour_19-lessons-home.png` → Lessons catalog.
- `tour_20-lesson-detail.png` → "Pause Beats Filler" lesson detail (step 1 of 3).
- `tour_21-speech-projects.png` → Speech Projects view.

### League + Path Journey (4)
- `tour_22-league.png` / `tour_23-league-bottom.png` → "Your league" with Gold tier, 612 rating, sample standings.
- `tour_24-path-journey.png` / `tour_25-path-journey-bottom.png` → "Your journey" path with skill milestones.

### Conditional sheets (2 — via force-trigger launch args)
- `tour_26-goal-refresh-sheet.png` → "Still your goal?" sheet with user goal text + Update it / Still right CTAs.
- `tour_27-notification-pre-prompt.png` → "We'll only nudge you when your streak is at risk" with the three benefits + Turn on reminders / Maybe later.

### Light mode (5 — captured by SessionEnd hook)
- `01_home_top.png` / `01_train_top.png` / `01_review_top.png` / `01_profile_top.png` / `01_settings_top.png` → 5 tab tops via deep link.

## Coverage gaps (not captured by detailed)

These would each require additional code changes to capture reliably:
- **In-rep dynamic states** (Thinking → Speaking → Summary) — needs audio recording mocked so the rep advances without microphone input.
- **Paywall** — would need a `FORCE_PAYWALL` launch arg + a tour tap path through Settings.
- **Friend Leaderboard** — needs a `FORCE_FRIEND_LEADERBOARD` deep link addition.
- **Friend invite QR scanner** — requires camera permission, hard to automate.
- **Deferred capture inline card** — appears inline on SummaryView after first rep; would need a session to complete first.

Estimated effort to add: ~30 min per surface. Defer until they actually matter.

## VISION gap
Not assessed this run — workflow bootstrap, not feature pass. Any cloud or local run shipping feature work must read `docs/VISION.md` for the area touched and compare against these 27 captures.

## Regressions checked
- Existing deep links preserved (lesson/practice/league/path/lessons/friend).
- Existing `UI_TESTING_SEED` semantics preserved — only seeds when empty.
- Build green. Tour test passes ~3 min.
- Other UI tests (`testHomeScreenAndPrimaryNavigation`, etc.) untested this run — pre-existing infra flakiness per [ui_test_flakiness memory](../../.claude/projects/-Users-jordan-src-GitHub-Noum/memory/ui_test_flakiness.md), no code changes touched their paths.

## Surfaces needing visual verification (cloud → local queue)
*Empty.*

## For next run
- **If cloud**: read this HANDOFF + [screenshot_handoff_workflow memory](../../.claude/projects/-Users-jordan-src-GitHub-Noum/memory/screenshot_handoff_workflow.md). `uname` ≠ Darwin → skill's cloud guard skips capture. Do non-visual work only. Append UI changes to "Surfaces needing visual verification."
- **If local**: SessionEnd hook will auto-light-capture at session end. Detailed sweeps are invoke-only ("screenshots detailed").
