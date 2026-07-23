# Noum — Current-State Evidence Bundle for UX Deep Research

## What this is

A deterministic capture of the Noum iOS app's current UI state, plus the product
vision doc and current coaching-quality evaluation reports. Built for an external
UX review. Nothing here is a mockup — every screenshot is the real app built from
source and driven by an XCUITest tour against deterministic seeded data.

## Source

- Repository branch: `ux-overhaul`
- Commit: `f441dd0191eb08f79ea159583878c1558f900df7` (`f441dd019`, "chngs")
- Working tree: **clean for all tracked files** (only untracked screenshot/artifact
  directories were present; no uncommitted source changes are reflected in the build).
- Built with Xcode 26.3 on macOS 26.4, scheme `Noum-StoreKit`, run on the
  iPhone 17 Pro simulator (iOS 26.5).
- Test: `NoumUITests/ScreenshotTour/testCaptureAdvancementSurfaces` — **passed**,
  1 test, 0 failures, 243s.

## Determinism

The tour launches with `UI_TESTING_SEED_FORCE`, which seeds an
"improvingIntermediate" user profile every launch: an established user with
session history, mid-tier league placement, and partial path progress. Overlay
celebrations (tier promotion, daily goal, path node, lesson) are suppressed so
they never cover the surfaces being captured. Screens are therefore
representative of an engaged mid-journey user, not a first-run user and not a
power user.

## What is captured (`screenshots/`, 34 PNGs)

Filenames are ordered by tour sequence:

- **Home tab** — top / mid / bottom scroll states (01–03)
- **Profile tab** — top / mid / bottom (04–06)
- **Review tab** — top / bottom, session-history list, one session detail (07–09)
- **Settings tab** — top / mid / bottom (10–12)
- **Practice mode picker** and every mode's setup screen: Timed Practice,
  Sudden Death, Ah-Counter, Impromptu Conversation, Cut the Crutch,
  Pace Training, Roleplay (13–18c)
- **Lessons home** (19)
- **Speech Projects** list + one project detail (21, 21b)
- **League** — top and bottom (22–23)
- **Path journey** — top and bottom (24–25)
- **Ask Noum** — entry and typed states (25b, 25d)
- **Friend leaderboard** (25c)
- **Goal refresh inline card** (26)
- **Notification pre-prompt** (27)
- **Weekly check-in sheet** (28)

## What is NOT captured

- `20-lesson-detail` — the tour's conditional tap target
  (`lessons.row.pause_beats_filler`) did not appear in its 3-second window, so the
  lesson-detail screen is missing from this run. Lessons *home* (19) is present.
- Live practice sessions in progress (recording/speaking states), rep results /
  post-rep debrief, onboarding, and the paywall — these have separate tour tests
  that were not part of this deterministic run.
- The immersive Live Coach Call surface (push-to-talk call UI).
- Any real network-backed coach replies: the mode-picker launch points the backend
  at an invalid URL by design, so screenshots show deterministic offline-safe UI.

## Non-screenshot evidence

- `docs/VISION.md` — the product vision (what Noum is trying to be).
- `coach-arena/latest.md` + `failures.md` — most recent coaching-quality eval
  of the real coach prompt (prompt-faithful engine), 2026-07-22.
- `coach-arena/app-path/latest.md` + `failures.md` — sibling eval through the
  app-path pipeline, 2026-07-21.
- `coach-arena/transcripts/transcript-practice-latest.json` — current transcript
  artifact, 2026-07-20.
- `git-status.txt`, `git-diff-stat.txt`, `git-log.txt` — provenance.
- `available-schemes.txt`, `available-simulators.txt`, `xcodebuild-output.txt` —
  build environment and full test log.
- `manifest.json` — machine-readable metadata including Figma URLs found in
  project docs. (`screenshots/manifest.json` is the raw xcresult attachment
  manifest; PNGs were renamed to their human-readable capture names.)

Note: `docs/COACHING_SYSTEM_SPEC.md` and `docs/PRODUCT_JOURNEY_DESIGN.md` were
requested as optional evidence but do not exist in the repository.

## How Deep Research should interpret this

1. Screenshots are ground truth for the *current* shipped UI on this commit —
   critique layout, hierarchy, copy, and coherence from them directly.
2. `VISION.md` is the intent; the UX review should evaluate the gap between the
   screenshots and that intent (premium, calm, coaching-trust, believable
   progress) rather than against a generic app rubric.
3. The coach-arena reports describe coaching *content* quality, which is scored
   by an LLM judge panel — treat the absolute scores as internally calibrated,
   not comparable across products; failures.md shows real weak spots.
4. Absence of a screen in this bundle means "not captured in this run," not
   "does not exist" — see the NOT-captured list above.
