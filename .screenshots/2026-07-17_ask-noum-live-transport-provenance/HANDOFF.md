# Run: 2026-07-17 · branch:ux-overhaul · HEAD bb38f4d6d · Verify live Ask Noum transport and remove false reply provenance

## Mode
light

## Changes shipped (this run)
- `Noum/AskNoumStore.swift:275` — persist the existing response-kind lane on each coach turn while keeping legacy rows decodable.
- `Noum/CoachReplyPipeline.swift:439` — carry response kind through provisional, streamed, and final turn metadata.
- `Noum/AskNoumView.swift:271` — show recent-rep provenance only for personal-evidence replies; conversational, general, memory-only, and legacy rows fail closed.
- `NoumTests/CohesiveSummaryAskTests.swift:196` — cover positive personal-evidence copy and suppression for conversational/general/legacy rows.
- `docs/RESEARCH_IMPLEMENTATION_AUDIT.md:83` — record the bounded installed-app production proof and retain the quality/readiness gaps.

## Screenshots
- 01_home_top.png — Home tab, top of view
- 01_train_top.png — Train tab (Practice mode picker)
- 01_review_top.png — Review tab (Session history)
- 01_profile_top.png — Profile tab
- 01_settings_top.png — Settings tab
- 06_ask_noum_greeting_without_false_evidence.png — persisted production greeting after rebuild; unavailable banner absent and false recent-rep provenance suppressed

## VISION gap
The live callable now answers one authenticated, App Check-valid greeting and the UI no longer claims personal evidence for that conversational turn. This supports VISION's trust and truthful-feedback requirements. It does not yet establish the desired human-expert coaching quality: the only accepted live sample is the trivial reply `Hello.`, while the reporter has already rejected prior representative wording as repetitive and unnatural.

## Next steps to reach desired state
1. Run the current-source five-case live conversation set through `coachChatV2`, retaining visible replies and server traces for each representative intent.
2. Evaluate those replies against the existing coaching quality rubric and the reporter's concrete redundancy/human-expert complaints before changing prompt policy.
3. Obtain the independent authorization/security evidence still required by `docs/PRODUCTION_READINESS_RUNBOOK.md`; do not infer readiness from simulator success.

## Regressions checked
- Ask Noum persisted greeting — 06_ask_noum_greeting_without_false_evidence.png — reply remains visible; false provenance and unavailable state are absent.
- Home navigation — 01_home_top.png — expected destination rendered.
- Train navigation — 01_train_top.png — expected destination rendered.
- Review navigation — 01_review_top.png — expected destination rendered.
- Profile navigation — 01_profile_top.png — expected destination rendered.
- Settings navigation — 01_settings_top.png — expected destination rendered.

## Surfaces needing visual verification (cloud → local queue)
- Representative multi-turn Ask Noum responses after the next coaching-policy change.
- Physical-device and TestFlight behavior, including App Attest and relaunch continuity.

## For next run
- **If cloud**: inspect representative response-policy gaps and prepare deterministic tests without asserting live acceptance.
- **If local**: capture the five-case App Check-valid live conversation set and compare visible copy with server generation traces.
