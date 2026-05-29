---
name: noum-screenshots
description: Capture Noum iOS app screenshots for the handoff folder. Three modes — off (skip), light (5 tab tops via `-DeepLink` launch arg), detailed (light + UI test tour). Use at end of local sessions, after any UI change, or when the user asks for screenshots / a sweep / a baseline. Only works on local Mac with the iPhone simulator booted (cloud routines on Linux must skip).
---

# noum-screenshots

Capture a coherent set of Noum app screenshots and write a `HANDOFF.md` to `.screenshots/<YYYY-MM-DD>_<run-slug>/` so the next run (local or cloud) can pick up the visual state.

## Mode toggle

The current mode lives at `.Codex/skills/noum-screenshots/.mode` — a single-line file containing `off`, `light`, or `detailed`.

When the user says "screenshots off" / "screenshots light" / "screenshots detailed" (or any clear variant), update the file with the `Write` tool and confirm in one sentence. The new mode applies to the *next* invocation; don't re-run the sweep immediately unless asked.

## Cloud sandbox guard

This skill requires the macOS iOS Simulator. **If running on Linux (cloud routines), do not attempt any `xcrun`/`xcodebuild` commands.** Detect by checking `uname` — if not `Darwin`, write a minimal `HANDOFF.md` to `.screenshots/<date>_<slug>/` noting "Cloud run — screenshots skipped, simulator unavailable on Linux" and append any "needs visual verification" items the run produced. That's it.

## Local workflow

1. **Read mode** from `.Codex/skills/noum-screenshots/.mode`. If `off`, skip to step 6 (write minimal HANDOFF only). Otherwise continue.

2. **Verify capability**:
   - `xcrun simctl list devices booted` — confirm iPhone 17 (iOS 26.4) is booted. If nothing booted, run `xcrun simctl boot "iPhone 17"` then `open -a Simulator`.
   - The Noum bundle ID is `com.jordancoaten.noum`.

3. **Build + install fresh** (only if source changed since the installed copy — check `git status` / `DerivedData` mtime; skip if not needed):
   ```
   xcodebuild -project Noum.xcodeproj -scheme Noum \
     -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' \
     -configuration Debug build
   xcrun simctl install booted /Users/jordan/Library/Developer/Xcode/DerivedData/Noum-hiuwiqmwohxjwfatrlpfulkktxtf/Build/Products/Debug-iphonesimulator/Noum.app
   ```

4. **Create folder**: `.screenshots/<YYYY-MM-DD>_<run-slug>/` where `<run-slug>` is a short kebab-case summary of what this session did (e.g. `baseline`, `m14-profile-clusters`, `cloud-handoff-pickup`).

5. **Capture per mode**:

   **light** — 5 tab tops via launch arg:
   ```
   for tab in home train review profile settings; do
     xcrun simctl launch --terminate-running-process booted com.jordancoaten.noum -DeepLink "noum://${tab}" > /dev/null
     sleep 3   # splash + render
     xcrun simctl io booted screenshot "<folder>/01_${tab}_top.png"
   done
   ```
   Then `Read` each PNG to verify it rendered the expected screen — a built+launched app doesn't guarantee the right view; a crash on launch or a stuck splash will silently save a blank/wrong frame.

   **detailed** — light + UI test tour (13 extra screenshots, ~90s):
   - Do the light capture first.
   - Then run the tour:
     ```
     rm -rf /tmp/noum-tour.xcresult /tmp/noum-tour-attachments
     xcodebuild test -project Noum.xcodeproj -scheme Noum \
       -destination 'platform=iOS Simulator,id=BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E' \
       -only-testing:NoumUITests/ScreenshotTour/testCaptureAdvancementSurfaces \
       -resultBundlePath /tmp/noum-tour.xcresult 2>&1 | tail -10
     xcrun xcresulttool export attachments --path /tmp/noum-tour.xcresult \
       --output-path /tmp/noum-tour-attachments
     ```
   - Extract only the named PNGs (manifest has many auto-attachments to ignore):
     ```
     python3 -c "
     import json, shutil
     m = json.load(open('/tmp/noum-tour-attachments/manifest.json'))
     out = '<folder>'
     for entry in m:
         for a in entry.get('attachments', []):
             name = a['suggestedHumanReadableName']
             if name.endswith('.png') and not name.startswith('UI Snapshot'):
                 slug = name.split('_0_')[0]
                 shutil.copy(f'/tmp/noum-tour-attachments/{a[\"exportedFileName\"]}', f'{out}/tour_{slug}.png')
     "
     ```
   - The tour covers **27 surfaces** (in this order):
     - Home top/mid/bottom (3)
     - Profile top/mid/bottom (3)
     - Review top/bottom + session detail (3)
     - Settings top/mid/bottom (3)
     - Mode picker (1)
     - Every practice mode setup: Timed, Sudden Death, Ah-Counter, IM Conversation, Cut the Crutch (5)
     - Lessons home + lesson detail (2)
     - Speech Projects (1)
     - League top/bottom (2)
     - Path Journey top/bottom (2)
     - Goal Refresh sheet (1) — via `FORCE_GOAL_REFRESH` launch arg
     - Notification Pre-Prompt sheet (1) — via `FORCE_NOTIFICATION_PROMPT` launch arg
   - All seeded with the `improvingIntermediate` dev profile.
   - The tour uses `UI_TESTING_SEED_FORCE` which **destructively replaces** the simulator's practice data + clears celebration overlays. That's intentional for deterministic captures; don't run detailed mode on a sim you're using for real hand-testing.
   - **Not yet covered** (require audio-mocking or test-only hooks not built): in-rep dynamic states (Thinking / Speaking / Summary), Paywall, Friend Leaderboard, Friend invite QR. If these matter, extend `ScreenshotTour.swift` + add the required launch args.

6. **Write `HANDOFF.md`** in the same folder using this template:

   ```markdown
   # Run: <YYYY-MM-DD> · branch:<git branch> · HEAD <short SHA> · <one-line goal>

   ## Mode
   <off | light | detailed>

   ## Changes shipped (this run)
   - <file:line> — <what>

   ## Screenshots
   - 01_home_top.png — Home tab, top of view
   - 01_train_top.png — Train tab (Practice mode picker)
   - 01_review_top.png — Review tab (Session history)
   - 01_profile_top.png — Profile tab
   - 01_settings_top.png — Settings tab
   - tour_*.png — (detailed only) UI-test tour captures
   - (Any extras for this run's focus)

   ## VISION gap
   <docs/VISION.md desired state for areas touched vs. what's in the app. Be specific.>

   ## Next steps to reach desired state
   1. <concrete action with file path>

   ## Regressions checked
   - <flow> — <screenshot> — no regression / regression on X

   ## Surfaces needing visual verification (cloud → local queue)
   - <area cloud touched but couldn't verify visually>

   ## For next run
   - **If cloud**: <work that needs no simulator>
   - **If local**: <what to capture / verify next>
   ```

7. **Stage the HANDOFF** (don't auto-commit unless the user asked):
   ```
   git add .screenshots/<folder>/HANDOFF.md
   ```
   The PNGs are gitignored so this only stages the markdown — cloud runs read it on next pull.

## What this skill does NOT do

- Does not take taps/swipes itself. Scroll-to-bottom states and modal/sheet captures require the UI test tour. If `UI_TESTING_SEED` injection isn't yet fixed, those captures are empty-state — still useful, but flag honestly.
- Does not run on cloud — see "Cloud sandbox guard" above.
- Does not commit unless asked. Stages only.
- Does not block on user. If something fails (sim not booted, build broken, deep link returns wrong screen), capture what's possible, note the failure in HANDOFF, and continue.

## When to invoke proactively

- After any UI/UX change in a local session, before claiming the change complete.
- At the end of any local session (acts as a "snapshot for cloud").
- When the user says "screenshot", "sweep", "baseline", "capture", or asks what the app currently looks like.

Skip invoking when:
- Mode is `off` (still write a minimal HANDOFF so the next run knows nothing changed visually).
- The change was pure backend with zero visual surface (still write a HANDOFF noting no visual surface).
- Running on Linux (cloud) — see guard above.
