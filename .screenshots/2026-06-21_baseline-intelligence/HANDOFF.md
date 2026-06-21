# Baseline Intelligence Follow-Up

- Date: 2026-06-21
- Branch: ux-overhaul
- HEAD: de38004
- Mode: light screenshot baseline
- Simulator: iPhone 17

## Scope

This pass populated the DEBUG seed baseline with the relational evidence a real coaching loop needs: reflections, weekly check-ins, real-world transfer reports, proof moments, recommendation outcomes, active big moment prep, and refreshed coach memory.

## Product Goal

Move seeded inspection from "metric history exists" to "coach has enough evidence to reason." The app can now show what it thinks is happening, why that read is tentative or reliable, what intervention is active, what carried into the real world, and what should happen next.

## Screenshots Captured

- `01_home_top.png` - Home shows seeded coaching state, including Stakeholder review in 9 days and a live coaching CTA.
- `01_train_top.png` - Train shows Coach Pick timed practice, current intervention target, and recommendation response state.
- `01_review_top.png` - Review shows 30-day history, trend surfaces, and a coach read grounded in seeded baseline data.
- `01_profile_top.png` - Profile shows Coach case file, proof moment, real-world prep, Growth Library, and History.
- `01_settings_top.png` - Settings loads normally with guest/default state.

## Intelligence From The Populated Baseline

- The improving intermediate seed now has a reliable baseline from 12 sessions, so the coach can talk in stronger but still bounded language.
- The system identifies filler words as the next leverage area while also seeing pace trending in a better direction.
- The active intervention is a timed-practice opener: "Open with the answer, then add one proof point."
- The real-world target is Stakeholder review, with transfer evidence that the opener is partially carrying but the close still softens.
- Check-ins and reflections add subjective evidence: nerves before cross-functional syncs, a tendency to soften claims, and a need for a clearer close.
- Proof moments give the coach concrete user language to reuse instead of generic praise.
- The coach context includes an explicit readiness/claim-scaling section that says this fixture does not prove coach parity.

## Verification

- Focused unit suite passed:
  - `xcodebuild test -project Noum.xcodeproj -scheme Noum -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:NoumTests/DevSeedCoachIntelligenceFixtureTests -derivedDataPath .build/transfer-debrief-test`
- Result bundle:
  - `.build/transfer-debrief-test/Logs/Test/Test-Noum-2026.06.21_21-05-53-+0100.xcresult`
- Light screenshot baseline captured for home, train, review, profile, and settings using `UI_TESTING UI_TESTING_SEED_FORCE` plus `noum://` deep links.

## Visual Notes

- Home, Train, Review, and Settings were populated and nonblank.
- Profile was populated, but the top Coach Case content appeared partially tucked under the navigation/title area in the deep-link screenshot. Treat this as a visual follow-up before calling the profile surface fully polished.

## Remaining Limits

- This fixture improves local coach-intelligence inspection; it does not validate expert-coach parity with real users.
- Full UI regression was not run in this follow-up pass. This pass verified the targeted intelligence fixture plus light top-level screenshot coverage.
