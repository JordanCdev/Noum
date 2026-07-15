# Run: 2026-07-15 · branch:ux-overhaul · HEAD 8fbdbab6e · Proof Moment account/source CAS

## Mode

light

## Changes shipped (this run)

- `Noum/PracticeSupport.swift:9016` — publishes the exact loaded account/store epoch with a saved practice session.
- `Noum/ProofMomentArchive.swift:115` — binds Proof Moment writes to account lifecycle, store epoch, exact source revision, and generation identity.
- `Noum/ProofMomentArchive.swift:221` — issues generation requests only for signed-in, hydrated, exact-account source rows and compare-and-saves archive mutations.
- `Noum/ProofMomentService.swift:90` — carries the captured request through cache, provider/fallback, and the single checked archive commit path.
- `Noum/SummaryView.swift:2137`, `Noum/ContentView.swift:1662`, `Noum/FirstRepCelebration.swift:428`, and `Noum/AIWeeklyInsightCard.swift:374` — capture and revalidate the request at all four rendered consumers.
- `NoumTests/ProofMomentAccountIsolationTests.swift:1` — covers cross-account, same-account lifecycle, store reload, source drift, archive grounding, cache scoping, and invalidation order.

## Screenshots

- `01_home_top.png` — Home tab top rendered as expected.
- `01_train_top.png` — Train tab top rendered as expected.
- `01_review_top.png` — Review tab top rendered as expected.
- `01_profile_top.png` — Profile tab top rendered as expected.
- `01_settings_top.png` — Settings tab top rendered as expected.

## VISION gap

Proof Moments now fail closed when account, lifecycle, session-store ownership,
or the exact source row changes during asynchronous generation. That supports
Noum's trust and believable-progress pillars. This light sweep proves only that
the five tab tops still render; it does not visually exercise a delayed Proof
Moment request through an account transition. Same-account voice/goal/baseline
drift, post-commit source deletion, retained rendered proof state, and
cancellation during archive save remain open.

## Next steps to reach desired state

1. Live-revalidate voice, goal wording, and baseline provenance before archive commit, replay, and render.
2. Remove or suppress archived proof when the exact source session changes or is deleted.
3. Retain and revalidate the save token for already-rendered Proof Moment state.
4. Add a deterministic delayed-provider UI fixture covering account switch, cancellation, and source deletion.

## Regressions checked

- Home top — `01_home_top.png` — no obvious navigation or layout regression.
- Train top — `01_train_top.png` — no obvious navigation or layout regression.
- Review top — `01_review_top.png` — no obvious navigation or layout regression.
- Profile top — `01_profile_top.png` — no obvious navigation or layout regression.
- Settings top — `01_settings_top.png` — no obvious navigation or layout regression.
- Proof Moment transition behavior — not represented by the light sweep; covered locally by focused unit tests only.

## Surfaces needing visual verification (cloud → local queue)

- Summary Proof Moment while a delayed provider request crosses sign-out/sign-in.
- Weekly Insight retained state after account, voice, goal, baseline, or source changes.
- Growth Library and Ask Noum replay after the source session is deleted.
- Proof Moment cancellation, VoiceOver, Accessibility XXXL, and Reduce Motion behavior.

## For next run

- **If cloud**: close personalization provenance, source-delete cleanup, retained-token validation, and service-level delayed-provider tests.
- **If local**: add and run the deterministic Proof Moment transition fixture, then capture the affected Summary, Home, Growth Library, and Ask Noum states.
