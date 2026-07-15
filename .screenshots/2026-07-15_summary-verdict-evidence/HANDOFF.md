# Run: 2026-07-15 · branch:ux-overhaul · base HEAD 7e6c430d · exact-session Summary and Coach Read evidence

## Mode

light

## Changes shipped (this run)

- `Noum/PracticeSupport.swift:317` — resolves Summary mechanic evidence only by the carried finalized-session identity; nil or unmatched IDs fail closed.
- `Noum/SummaryView.swift:71` — carries the finalized session ID through Summary and withholds fresh finalization when that exact persisted row cannot resolve.
- `Noum/FeedbackEngine.swift:149` — deterministic verdict filler/WPM claims consume only qualified evidence from the identified saved row while independent coaching evidence remains available.
- `Noum/SummaryFillerPresentation.swift:82` — raw filler facts remain inspectable, but rate, comparison, and tone require the exact qualified session.
- `Noum/WhatToImproveCard.swift:76` — filler and pace improvement bullets require independently qualified mechanics.
- `Noum/SessionFinalizer.swift:89` — requires the exact eligible persisted row before lifecycle effects and uses its duration for pause-rate trend evidence.
- `NoumTests/SummaryVerdictMetricEvidenceTests.swift:5` — covers identity, missing/mismatched rows, thin/confidence/schema/fixture rejection, independent evidence, rate-vs-count fairness, and finalization mutation safety.
- `Noum/PracticeSupport.swift` — premium Coach Read uses the exact saved source, score-only continuity, a transcript-quote gate, store-level output revalidation, and an account-scoped full-source compare-and-swap save token.
- `Noum/BaselineEngine.swift` — shared output policy recognizes weak-evidence mechanic language while preserving semantic speech and generic drill prescriptions; Coach Read baseline context can omit comparison mechanics entirely.
- `Noum/SummaryView.swift` and `Noum/SessionHistoryView.swift` — render only persisted evidence-safe Coach Read output and selectively suppress unsupported legacy mechanic prose.
- `NoumTests/GeneratedCoachReadMetricEvidenceTests.swift` — covers prompt/fallback quarantine, synonym rejection, generic prescriptions, quote fabrication, exact-source save races, legacy replay, and score-only continuity.
- `.gitignore:10` — ignores all `.build-roleplay-terminal*` DerivedData variants so generated Git pack files cannot re-enter the commit flow.

## Screenshots

- `01_home_top.png` — Home deep link was intercepted by the account-bootstrap error; Home content was not reached.
- `01_train_top.png` — Train deep link was intercepted by the same bootstrap error; the capture also contains persistent simulator compositing occlusion, so it is not content proof.
- `01_review_top.png` — Review deep link was intercepted by the account-bootstrap error; Review content was not reached.
- `01_profile_top.png` — Profile deep link was intercepted by the same bootstrap error and includes simulator compositing occlusion; Profile content was not reached.
- `01_settings_top.png` — Settings deep link was intercepted by the account-bootstrap error; Settings content was not reached.

All five final PNGs were visually inspected. Each normal `-DeepLink` launch rendered `Your coaching profile is not ready` / `Noum couldn't save this account on this device. Try again.` instead of the requested tab. This light sweep is therefore **blocked**, not a passing visual regression. The Summary evidence boundary is proved by deterministic tests, not by these images.

## VISION gap

Summary can no longer borrow another rep's filler/WPM mechanics or begin lifecycle effects without the identified eligible saved row. Premium Coach Read can no longer invent free-form filler/pace observations, attach an asynchronous response to a changed source, or persist a fabricated transcript quote. Product-wide closure remains incomplete: the qualitative Summary delivery line, durable CoachMemory/derived delivery reads, IM baseline comparison, Ask Noum session opener, share/request-feedback WPM, Proof Moment generation, Forward Plan inputs, and other durable narrative/reward consumers still need the same provenance boundary. The normal unsigned-simulator bootstrap also prevented any truthful tab-level visual proof in this run.

## Next steps to reach desired state

1. Audit and harden the remaining Summary qualitative delivery and durable CoachMemory/derived delivery paths without suppressing independent transcript, score, category, or duration evidence.
2. Trace the normal simulator guest-account persistence failure through `Noum/AuthManager.swift` and rerun the light five-tab sweep once `-DeepLink` can reach the requested surfaces.
3. Harden IM baseline, share/request-feedback WPM, Proof Moment, Forward Plan, and durable coach-memory consumers.
4. Obtain the five required external production artifacts through authorized device, professional-review, longitudinal, and operations workflows.

## Regressions checked

- Summary evidence selection — 58/58 passes in `.build-roleplay-terminal/Focused-SummaryEvidence-final-all-retry.xcresult`.
- Generated Coach Read/shared evidence selection — 47 unique tests / 49 device executions, zero failures and zero skips, in `.build-roleplay-terminal/Focused-GeneratedCoachRead-Commit-final-20260715.xcresult`.
- Complete unsigned unit target — 4,311 unique tests / 4,330 device executions, zero failures and zero skips, in `.build-roleplay-terminal/Full-NoumTests-Commit-20260715.xcresult`.
- Release — current-source unsigned Release simulator build succeeds.
- Light five-tab navigation — attempted from the fresh Debug app; all routes were blocked before tab content by the account-bootstrap error, so no tab regression is claimed.
- Large-file hygiene — no tracked or unignored commit candidate exceeds 95 MB; `.build-roleplay-terminal*` is ignored.

## Surfaces needing visual verification (cloud → local queue)

- Home, Train, Review, Profile, and Settings tops after normal guest bootstrap succeeds.
- Rendered Summary with qualified, unqualified, nil-ID, and mismatched-ID evidence.
- Manual VoiceOver, reduced-motion transitions, physical-device capture, and signed TestFlight behavior.

## For next run

- **If cloud**: continue the read-only metric inventory or harden pure durable consumers; do not count simulator or external proof.
- **If local**: resolve or provision the normal guest bootstrap first, rerun the five-tab light sweep, then add focused rendered Summary fixtures if UI evidence is required.
