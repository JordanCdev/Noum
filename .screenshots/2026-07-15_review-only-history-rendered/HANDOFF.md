# Run: 2026-07-15 · branch:ux-overhaul · HEAD 3969c817 · keep mixed Review history honest

## Mode

light

## Changes in this run

- `Noum/SessionHistoryListView.swift` — keeps raw saved rows searchable, openable, and deletable while moving score averages and session-backed mode cards onto the shared progress-eligible projection.
- `Noum/SessionHistoryView.swift` — gives thin rows and details neutral `Saved capture` / `Not measured` provenance, suppresses stored score/praise and coaching reads, preserves prompt/replay/transcript inspection, handles non-finite duration safely, and compares only measured reps.
- `Noum/MistakeReplayCard.swift` — prevents thin low-score or filler-heavy captures from becoming targeted replay evidence.
- `ProfileView.swift` — keeps one- and two-rep copy at a neutral starting point instead of converting onboarding focus into a measured claim.
- `Noum/FlowObservability.swift` — derives review-open rate from unique event correlations that match progress-eligible session IDs, so thin, duplicate, and foreign legacy opens fail closed.
- `Noum/ReviewProgressEligibilityUITestFixture.swift`, `Noum/DevSeedData.swift`, and `Noum/ClutchWordStore.swift` — add a Release-inert five-row mixed-history fixture and reset dependent XP, Pressure-run, speech-pattern, baseline, trend, recommendation, and memory owners for coherent evidence.
- `NoumTests/ReviewOnlyHistoryEvidenceTests.swift`, `NoumTests/TransformationKPIReportTests.swift`, `NoumTests/CohesiveReviewProfileTests.swift`, and `NoumUITests/ReviewProgressEligibilityUITests.swift` — cover raw/eligible separation, neutral positive-headline suppression, comparison/replay/Profile/KPI boundaries, fixture isolation, and the rendered Review/Profile flow.
- `docs/CURRENT_STATE.md`, `docs/DEVELOPMENT_PLAN.md`, and `docs/RESEARCH_IMPLEMENTATION_AUDIT.md` — record the bounded closure and retain the external production NO-GO.

The checkout already contained substantial in-flight source, localization,
tests, documentation, and 32 staged screenshot handoffs. This run preserved
them, left source/docs unstaged, and staged only this handoff. The pre-existing
localization catalog was not edited by this run.

## Screenshots

Current-source focused captures in `verified/`:

- `C9532AB0-E296-4D86-84C1-CDFEB6F754FF.png` — Profile remains at two measured reps while exposing the raw five-saved-rep history link.
- `DCFF88EE-43D6-4145-BDA1-5EC692BE960E.png` — coaching evidence is isolated at 0 XP and two reps, with no inherited speech-pattern or Pressure-run evidence.
- `DBB0809D-D70B-41F9-8A5E-CB498CB832E1.png` — Review remains a two-rep starting point and keeps the progress chart behind its evidence gate.
- `8DBE0D16-50E7-4F2D-BCE5-00A2DA8471EE.png` — All Reps reports five saved / two measured / 6.5 average while the exact thin row remains searchable under a neutral title with no 10/10.
- `B49AD28C-7280-4B62-89D5-41CA4C57CB8F.png` — thin detail shows `Saved capture`, `Not measured`, exact prompt, replay, and transcript access without coaching cards.

Seeded light sweep:

- `01_home_top.png`
- `01_train_top.png`
- `01_review_top.png`
- `01_profile_top.png`
- `01_settings_top.png`

All ten retained images were visually inspected. The five `verified/` images
are the authoritative post-audit focused evidence. The light sweep predates only
the non-shell neutral-headline and KPI fixes; those fixes do not alter its five
tab-top states.

## VISION gap

Saved history now reinforces coaching trust instead of allowing a transport-
valid but unmeasurable capture to look like improvement. Noum preserves the
user's exact record and a low-friction retry path, while every visible score,
comparison, replay target, coaching depth, and review-open KPI claim uses the
same measured-evidence boundary. This is local deterministic simulator proof,
not evidence that the three-word / three-second floor professionally calibrates
every mode metric or produces real-world speaking improvement.

## Next steps to reach desired state

1. Freshly rank rendered Home or Summary recommendation capability loss; implement one only if it remains the highest bounded local gap.
2. Treat stricter filler/WPM quantity qualification and legacy Sudden Death run-ledger reconciliation as separate evidence/schema work, not as silently solved by this shared floor.
3. Run manual VoiceOver, the clean signed full scheme, optimized Release scan, and physical TestFlight QA when the required signing, device, and operator authority exist.
4. Collect the current-source live-provider sweep, blinded professional calibration, longitudinal real-user transfer outcomes, physical-device TestFlight artifact, and operational launch checklist. Local fixtures cannot earn any of these gates.

## Regressions checked

- Focused mixed-history and KPI contracts — `.build-roleplay-terminal/Logs/Test/Test-Noum-2026.07.15_review-history-final2.xcresult` — 31/31 passed with zero failures or skips.
- Current-source rendered lane — `.build-roleplay-terminal/Logs/Test/Test-Noum-2026.07.15_review-history-ui-final2.xcresult` — 2/2 passed with zero failures or skips; five non-failure attachments were exported to `verified/` and inspected.
- Complete current-source unsigned unit target — `.build-roleplay-terminal/Logs/Test/Test-Noum-2026.07.15_full-final.xcresult` — 4,241 unique tests / 4,260 successful device executions, zero failures or skips. This is not described as warning-free.
- Current-source unsigned Release simulator build — `xcodebuild build -configuration Release` with code signing disabled — succeeded. The optimized bundle scan and clean signed full scheme were not rerun.
- Accessibility configuration — the focused UI lane launched at Accessibility XXXL; the iPhone 17 Pro / iOS 26.5 base simulator had Reduce Motion enabled.
- Raw/evidence contrast — the fixture exposes five finite durable rows, only two progress-eligible rows, 0 XP, no inherited clutch words, and no inherited Pressure runs.
- Seeded Home / Train / Review / Profile / Settings light sweep — `01_*.png` — expected destinations rendered without a blocking shell regression.
- Localization preservation — `Noum/Resources/Localizable.xcstrings` retained SHA-256 `ee0a735ed8a3c17d5f589d5926a6f2c14e2080a5e35002ed2db3aafb80a6f16a`.

## Evidence boundaries

- Non-finite and evaluation-only sessions remain unit-only because durable user-history persistence rejects or filters those shapes.
- Sudden Death's session fallback consumes the eligible projection, but its independent historical run ledger is not retroactively reconciled; current run writes are eligibility-gated.
- The shared three-word / three-second floor excludes Review-only captures but is not the stricter quantity floor required for every filler-rate or WPM interpretation.
- Manual VoiceOver, physical devices, signed distribution, live providers, professional calibration, longitudinal user transfer, deployed operations, and all five external artifacts remain unproved.
- Production readiness remains **NO-GO at 18/100 with 0/5 required external artifacts**.

## Surfaces needing visual verification (cloud → local queue)

- Manual VoiceOver focus and announcement order across Review, All Reps, search, and thin detail.
- Real-device dynamic type, keyboard/search dismissal, replay navigation, deletion, and export behavior.
- Signed TestFlight behavior with real microphone/provider capture and legacy account data.
- Home/Summary capability loss if selected as the next bounded local candidate.

## For next run

- **If cloud**: rank or source-audit the Home/Summary recommendation-loss candidate; do not manufacture device, provider, calibration, or user-outcome evidence.
- **If local**: prioritize signed/manual/physical evidence over another deterministic seam when credentials, hardware, and operator authority are available.
