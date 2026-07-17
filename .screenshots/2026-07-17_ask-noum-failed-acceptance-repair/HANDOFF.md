# Run: 2026-07-17 · branch:ux-overhaul · HEAD 368ade3b8 · Ask Noum availability, trust, and account-authority repair

## Mode

light

## Changes in this working tree

- `Noum/CoachChatTransport.swift:107` — classifies coach-directed complaints about weird, redundant, or non-human wording as conversational trust repair without treating user self-critique as product feedback.
- `Noum/CoachReliabilityGate.swift:558` — requires a reply to own the specific miss and state a coach-side correction; vulnerable disclosures keep their no-burden guard.
- `Noum/AuthManager.swift:611` and `Noum/LocalGuestPromotionJournal.swift:25` — give a `local-guest-*` owner one copy-first, three-phase route to a newly created anonymous Firebase identity, with target-authoritative recovery and no stranding sign-out.
- `Noum/AskNoumView.swift:2743` and `Noum/SettingsView.swift:1405` — expose explicit, accessible live-coaching connection actions while automatic retry remains non-blocking.
- `Noum/BackendSyncManager.swift:706` and `Noum/PracticeSupport.swift:5385` — bind content upload to scheduling lifecycle, exact account/provider/UID, hydration, transition fences, and the current published-plus-persisted consent receipt.
- `functions/src/recommendationState.ts:468` and `functions/src/index.ts:3794` — bind recommendation mutation schema v2 to the verified callable UID.
- `privacy/processors.json` — advances the reviewed processor manifest to v7 and regenerates the shipping Swift, Markdown, and HTML disclosures.

## Screenshots

- `01_home_top.png` — Home recommendation and Ask Noum entry point rendered.
- `02_train_top.png` — Train recommendation and practice library rendered.
- `03_review_top.png` — Review movement card and rep navigation rendered.
- `04_profile_top.png` — Profile coaching focus and reality-check card rendered.
- `05_settings_top.png` — Settings top rendered; the account connection card remains below the light-sweep viewport.
- `06_ask_top.png` — Ask Noum empty conversation and enabled composer rendered for the simulator's currently available account.

All six final frames were inspected. No blank frame, bootstrap gate, splash
screen, crash surface, or wrong deep-link destination was observed. An initial
capture accidentally installed the unsigned unit-test product and correctly
failed Keychain entitlement access; it was discarded and every frame was
recaptured from the normally signed Debug build.

## VISION gap

The app still does not meet the vision's trustworthy, always-coherent coaching
loop. Local gates now prevent the reported complaint from becoming an invented
personal diagnosis or another drill, and the local guest is no longer designed
as a permanent callable dead end. These captures do not prove promotion on a
physical device, deployed `coachChatV2` availability, or that live generated
replies sound like a concise human expert coach.

## Next steps to reach desired state

1. Add per-document ordering/revisions plus a durable outbox for ordinary profile, XP, and session sync; prove snapshot interleavings cannot regress newer state.
2. Close same-UID anonymous-session recovery, Apple/Google link-success-before-Keychain recovery, exact snapshot task ownership, and existing-target merge semantics.
3. Deploy `coachChatV2` backend-first under authorized release controls, then prove mixed v1/v2 smoke and rollback.
4. Capture current-source App Check-valid visible replies for the representative five-case set and require reporter plus independent professional-coach acceptance.
5. Add a deterministic local-guest promotion UI fixture so Connect, connecting, failure, hydration, and post-commit states can be visually checked.

## Regressions checked

- Five primary tab deep links — `01_home_top.png` through `05_settings_top.png` — no wrong-route, blank-frame, or persistent hydration regression from the normally signed app.
- Ask Noum deep link — `06_ask_top.png` — ordinary available-account layout and composer remain intact.
- Ask Noum regression — `/private/tmp/noum-ask-final-r4-20260717.xcresult` — 224/224 passed, zero failed or skipped.
- Promotion/privacy/authority regression — `/private/tmp/noum-guest-promotion-consent-20260717-r8.xcresult` — 41/41 passed, zero failed or skipped.
- Auth/Firestore/Functions emulator — 30/30 passed with Node 22.23.1, Java 21.0.11, and Firebase CLI 15.19.1.

## Surfaces needing visual verification

- Ask Noum local-guest Connect, connecting, failure, and post-promotion states.
- Ask Noum secure-session-loss recovery.
- Settings on-device guest identity, Connect action, and hidden Sign out action.
- Long generated conversations, Dynamic Type, reduced motion, VoiceOver, and physical-device presentation.

## For next run

- **If cloud**: implement ordered/versioned durable ordinary content sync; keep competitive/social upload capabilities disabled until they use the exact authority contract.
- **If local**: exercise promotion kill/relaunch at every journal phase and capture the connection states, then run the real App Check-valid five-case acceptance set after authorized backend deployment.
