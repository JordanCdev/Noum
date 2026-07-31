# Run: 2026-07-30 · branch:ux-overhaul · HEAD 517998349 · restore physical-device practice access, transcript trust, and subscription plans

## Mode
light

## Changes implemented (this run)
- `Noum/AuthManager.swift` — local account/profile state is launch-authoritative; failed Firebase profile reconciliation no longer traps a restored user behind “Your coaching profile is not ready.”
- `Noum/SpeechRecognizerViewModel.swift` — provider/API failure is no longer misreported as insufficient speech, and a genuinely started capture retires an older transient progress receipt.
- `Noum/PathProgressManager.swift` — a new practice attempt clears only the transient celebration while preserving the durable path unlock.
- `Noum/ContentView.swift` and `Noum/SummaryView.swift` — progress receipts require the exact progress-eligible source session; copy now says “Spoken progress saved.”
- `Noum/PremiumManager.swift` — the paywall loads automatically, distinguishes an empty catalog from a storefront request failure, logs the underlying debug error, and presents a retry action instead of an endless spinner.
- `Noum.xcodeproj/xcshareddata/xcschemes/Noum.xcscheme` and `Noum-StoreKit.xcscheme` — normal and StoreKit Run/Test actions now use Xcode’s canonical `../../Noum/Configuration/Noum.storekit` reference. The prior single-`..` path resolved inside the `.xcodeproj` bundle, so Xcode silently launched with an empty product catalog.
- `NoumTests/PathUnlockCelebrationIntegrityTests.swift`, `NoumTests/PremiumGrowthContractTests.swift`, and `NoumTests/StoreKitConfigurationTests.swift` — focused contracts cover exact-session receipts, actionable product-load errors, and a StoreKit scheme path that resolves to a real checked-in file.

## External configuration completed
- Registered the current physical iPhone App Check debug token for Firebase project `noum-d0b6f`, iOS app `1:381934683469:ios:1f6d3cb46df771a7356304`, bundle `uk.co.otherpath.noum`.
- Registered the current iPhone 17 simulator App Check debug token for the same exact Firebase iOS app.
- Created the draft App Store Connect subscription group `Noum Pro`.
- Created draft `com.noum.pro.monthly` at £11.99/month.
- Created draft `com.noum.pro.annual` at £79.99/year with a seven-day free introductory offer.
- Added English (U.S.) subscription localizations and worldwide availability.
- No app version or subscription was submitted for review.

## Screenshots
- `01_home_top.png` — Today tab.
- `01_train_top.png` — Practice tab and recommended rep.
- `01_review_top.png` — Review/Progress tab.
- `01_profile_top.png` — Profile tab.
- `01_settings_top.png` — Settings.
- `paywall_top.png` and `paywall_details.png` — honest StoreKit-unavailable state produced by the Xcode 26 command-line runner; the UI no longer spins indefinitely.
- `paywall_storekit_plans.png` — corrected Xcode Run scheme loading both live local products, the Annual trial, and the actionable subscription CTA.
- `paywall_top_ax.txt` and `paywall_details_ax.txt` — accessibility trees for the paywall captures.

## Verification
- Clean physical-device Debug build passed for iPhone `00008150-001618E10A0A401C`.
- The repaired app was installed on Jordan’s iPhone without deleting its existing app data.
- Focused simulator tests passed:
  - StoreKit catalog schema and product contracts.
  - First-run friction contracts.
  - Transcript practice loop.
  - Timed Practice media lifecycle.
  - Sudden Death prompt/readout lifecycle.
  - Exact-session progress receipt integrity.
  - Premium product-load error presentation.
- The five primary surfaces and paywall fallback were visually inspected.
- A fresh simulator launch after App Check registration restored the account with no App Check 403 or Firestore permission error.
- Xcode Run loaded Annual ($79.99/year), Monthly ($11.99/month), and the one-week Annual trial from the local StoreKit catalog.
- Tapping Subscribe opened Xcode’s local confirmation sheet for `Noum Pro Annual`; it correctly stated that the local test purchase would not charge the account.
- Both corrected scheme references resolve to the checked-in catalog under `xmllint`/`realpath`, and Xcode’s scheme editor no longer reports a missing file.
- `git diff --check` passed.

## Blocked verification
- The simulator reaches Timed Practice’s real recording state, but Apple’s simulator CoreAudio process fails with `AudioDeviceStop: no device with given ID` even after selecting the Mac microphone and rebooting the simulator. A real spoken transcript therefore still requires functioning audio input, most reliably the iPhone.
- The deployed `transcriptionToken` callable remains to be exercised after explicitly allowing cloud processing in the test account. App Check and Firestore startup are already clean.
- The updated StoreKit path regression compiled, but Xcode’s test worker could not materialize while the Mac was locked. Runtime Xcode Run verification passed despite that runner-only blocker.
- App Store review screenshots, production sandbox purchase, restore, renewal, cancellation, and TestFlight product propagation remain unverified.

## Assumptions and commercial decision still required
- The App Store drafts use the executable catalog’s existing £11.99 monthly / £79.99 annual contract.
- `docs/PRODUCT_DECISION_LOG.md` contains a newer tentative £8.99 / £59.99 direction. Pricing is therefore editable draft state, not a final commercial decision.
- The App Check debug token appeared in logs/chat and should be revoked or rotated after physical-device verification.

## VISION gap
The core practice loop is no longer supposed to depend on a successful remote profile read, and provider failures now preserve coaching trust. Completion still requires one real iPhone rep that proves microphone capture, transcript persistence, exact-session Summary, and the cloud/local provider route end to end.

## Next physical-device acceptance run
1. Unlock the iPhone and keep it awake; the Mac-side Firebase, launch, and StoreKit blockers are already removed.
2. Launch the installed Debug build and confirm the blocking coaching-profile screen does not return.
3. Confirm the console has no App Check `exchangeDebugToken` 403 for the registered physical-device token.
4. Complete a 15+ second, 20+ word Timed Practice rep and confirm live capture, terminal transcript, saved Review session, and exact-session Summary.
5. Repeat with cloud processing disabled to prove Apple on-device fallback.
6. Complete a production sandbox purchase/restore only after App Store Connect products finish propagating.

## For next run
- The phone is not needed to prove routing, App Check, Firestore startup, local plan loading, or checkout presentation; those now pass on the Mac.
- Do not claim the real-microphone transcript/exercise issue fully closed until steps 2–5 pass on functioning audio hardware.
- Do not broadly deploy Firestore rules; checked-in owner-read rules are already correct and any remaining denial needs UID/deployed-state diagnosis.
- Keep the App Store products in draft until pricing and review metadata are explicitly approved.
