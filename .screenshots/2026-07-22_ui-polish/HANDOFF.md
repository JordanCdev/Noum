# UI polish and first-week coaching handoff

- Branch: `ux-overhaul`
- Base commit: `d90bb8922`
- Simulator: iPhone 17, iOS 26.4 (`BD2DE1AB-DAC7-4538-A5AD-BECC4D603C0E`)
- Screenshot mode: detailed manual sweep after the light five-tab baseline

## What changed

- Reframed Home around one bounded coaching focus and one primary action.
- Made Train plan-first; the exercise catalogue is secondary and collapsed.
- Simplified Path copy, replaced the footstep marker, separated the trees, and made foliage opaque.
- Converted Profile, Review, and Settings to a quieter neutral card system with shorter copy.
- Moved the weekly real-world check-in into the active coaching loop and made it a pushed page rather than a popup.
- Converted real-moment preparation into a standard pushed flow with native back navigation and one bottom action.
- Rebuilt post-rep presentation as one calm receipt: score, verified quote, one observation, one next move, then optional detail.
- Consolidated personal best, practice level, XP, and achievements into the same restrained progression language.
- Removed ambient rays, parallax, celebration stacks, score sounds, and unsolicited modal presentation from the touched journey.

## Screenshots

1. `01-home.png` — bounded daily focus and first-week read.
2. `02-train.png` — recommended rep first, free selection collapsed.
3. `03-review.png` — one movement read and two secondary destinations.
4. `04-profile.png` — neutral rating, current lever, due weekly check-in, library.
5. `05-settings.png` — grouped native controls with shorter labels.
6. `06-path.png` — opaque separated trees, open corridor, waypoint marker, shorter sections.
7. `07-prepare.png` — pushed real-moment preparation flow.
8. `08-weekly-check-in.png` — one answer, optional note, extra context collapsed.
9. `09-summary.png` — verified quote, restrained observation, prescribed next action.
10. `10-coaching-evidence.png` — current focus plus two collapsed evidence groups.
11. `11-coaching-evidence-expanded.png` — opted-in baseline detail.
12. `12-milestones.png` — recent record, one closest next milestone, full inventory collapsed.
13. `13-train-free-selection.png` — secondary free-selection mode after deliberate expansion.

## VISION gap addressed

Before this pass, important coaching features competed as separate dashboards, modals, and celebration screens. The product could feel like disconnected feature experiments despite having strong underlying evidence and state systems.

After this pass, the primary journey reads as one communication operating system: one focus, one rep, one proof moment, one next action, and a visible first-week contract. Existing state owners remain authoritative; the UI now reveals depth progressively instead of presenting all available data at once.

## Verification

- Integrated simulator build succeeded with the `Noum-StoreKit` scheme.
- Focused suites passed for first-week entry, Home/Train/Path polish, supporting surfaces, post-rep event projection, and post-rep first-pass copy.
- The focused Plan-first UI tour passed end to end and captured Train, coaching evidence, and Milestones navigation.
- `git diff --check` passed.
- All thirteen PNGs were opened and visually inspected after capture.
- Native iPhone home indicator intentionally remains visible.

## Known limits

- No physical-device or TestFlight verification was performed in this UI-focused pass.
- The coaching evidence page keeps full depth behind disclosures; PDF export was not added because a redaction/provenance contract does not yet exist.
- App Store acquisition assets and custom product pages remain launch operations rather than in-app UI.

## Next recommended checks

1. Run the detailed screenshot tour at accessibility text sizes and with Reduce Motion enabled.
2. Complete a real spoken rep on a physical device and verify microphone interruption and offline fallback.
3. Validate the paywall against live StoreKit products and trial eligibility before commercial release.
4. Use the captured surfaces as the source for App Store screenshot composition rather than the earlier gradient/celebration screens.

## Regression checklist

- Recommendation exposure and acceptance analytics still fire from Train and Home.
- Path and Profile continue to read existing stores; no parallel state owner was introduced.
- Weekly check-in still uses `CoachCheckInStore` and refreshes notification routing after save.
- Big Moment still uses `BigMomentStore` and existing scheduling callbacks.
- Summary still preserves evidence floors, review prompting, contextual paywall, persistence, and reduced-motion behavior.
- The full coach read remains available under `See details`; only the first-pass receipt is shortened.
