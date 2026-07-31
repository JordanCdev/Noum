# Run: 2026-07-29 · branch:ux-overhaul · HEAD 517998349 · restore transcript trust, honest progress receipts, and visible subscription states

## Mode
light

## Changes shipped (this run)
- `Noum/SpeechRecognizerViewModel.swift:96` — distinguish provider/API capture failures from genuinely insufficient spoken evidence.
- `Noum/SpeechRecognizerViewModel.swift:807` — retire an older transient path receipt when a new microphone capture actually starts.
- `Noum/ContentView.swift:695` — replace unexplained “Landmark reached” copy with “Spoken progress saved” and require the source session to remain progress-eligible.
- `Noum/PathProgressManager.swift:246` — preserve durable unlocks while clearing superseded Home celebrations.
- `Noum/PremiumManager.swift:1383` — stop the indefinite loading presentation and render an explicit recoverable App Store error state.
- `Noum.xcodeproj/xcshareddata/xcschemes/Noum.xcscheme` — attach the checked-in StoreKit catalog to normal Test and Run actions, not only the special StoreKit scheme.
- `NoumTests/StoreKitConfigurationTests.swift:78` — enforce StoreKit configuration on both shared schemes.

## Screenshots
- `01_home_top.png` — Today tab, seeded coaching plan.
- `01_train_top.png` — Practice tab, recommended rep.
- `01_review_top.png` — Progress/Review tab, recent movement.
- `01_profile_top.png` — You/Profile tab.
- `01_settings_top.png` — Settings surface.
- `paywall_runner_limitation.png` — honest non-spinning fallback rendered by Xcode 26's UI-test runner, which did not synchronize the local StoreKit catalog.

## VISION gap
The touched flows now use evidence-led language and no longer blame the speaker for a provider failure. Normal Xcode Run is configured for real local StoreKit products, but Xcode 26's command-line UI-test runner still returns an empty StoreKit catalog; production App Store Connect products and a physical sandbox purchase remain external release verification.

## Next steps to reach desired state
1. Run the shared `Noum` scheme on a physical device and confirm Annual and Monthly render from `Noum/Configuration/Noum.storekit`.
2. Complete a sandbox annual purchase and restore before release.
3. Repeat one live spoken rep now that the migrated App Check debug token is registered, confirming the device reaches the deployed `transcriptionToken` function.

## Regressions checked
- Today — `01_home_top.png` — seeded plan renders with no stale path celebration.
- Practice — `01_train_top.png` — recommended spoken rep remains reachable.
- Review — `01_review_top.png` — saved evidence remains coherent.
- Profile — `01_profile_top.png` — current coaching focus remains visible.
- Settings — `01_settings_top.png` — settings navigation and layout render.
- Paywall failure — `paywall_runner_limitation.png` — no indefinite spinner; explicit reload state and legal links remain visible.

## Surfaces needing visual verification (cloud → local queue)
- Physical-device paywall with the shared Run scheme's StoreKit catalog. Xcode was set to `Noum-StoreKit` on Jordan’s iPhone 17, but the verification launch stopped because the phone was locked.
- Live provider-interruption copy during an actual microphone rep.

## For next run
- **If cloud**: verify source contracts and production release configuration only.
- **If local**: capture the physical-device Annual/Monthly plan cards and complete a sandbox purchase/restore lifecycle.
