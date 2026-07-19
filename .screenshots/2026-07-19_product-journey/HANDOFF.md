# Product journey screenshot handoff

- Date: 2026-07-19
- Branch: `codex/product-journey-launch`
- Source commit: `6712ee74d`
- Baseline: `ux-overhaul` at `2bcb1ccff769d1eba71da9049e4fa82fbf1d4bb2`
- Mode: light
- Device: iPhone 17 simulator
- Resolution: 1206×2622

## Scope and product goal

This sweep checks the five tab roots after connecting Noum's existing owners
into one coaching journey. It focuses on whether Home presents one dominant
next step, Practice reads as prescribed work, Review/Progress tells one coaching
story, Profile retains the voice target, and Settings remains coherent. It also
records the cold-profile boundary rather than hiding it.

## Seeded journey captures

- `01_home_top.png` — dominant Continue prep action plus contextual Ask Noum.
- `01_train_top.png` — one Recommended rep, Timed Practice, with focused CTA.
- `01_review_top.png` — one movement story and one next focus.
- `01_profile_top.png` — voice target, rating, and coaching focus remain visible.
- `01_settings_top.png` — Settings root remains stable after adding data/debug
  destinations.

## Recovery captures

- `recovery_home_profile-not-ready.png`
- `recovery_train_profile-not-ready.png`
- `recovery_review_profile-not-ready.png`
- `recovery_profile_profile-not-ready.png`
- `recovery_settings_profile-not-ready.png`

The unseeded launch did not silently invent a coaching profile. Each deep link
showed the same explicit “Your coaching profile is not ready” recovery with a
Retry action. That is honest failure-state evidence, not successful tab-content
coverage; the seeded set provides the tab-root coverage.

## Inspection result

All ten images are nonblank 1206×2622 captures. The seeded roots preserve the
existing SwiftUI card, spacing, hierarchy, and navigation language. No detached
dashboard, new tab, or noisy progress surface was introduced. The cold-profile
set proves the initialization boundary terminates visibly and retryably.

## Regression boundary and follow-up

This light sweep does not visually prove the nested Debug trace viewer, memory
edit/delete controls, transcript ladder, largest Dynamic Type, VoiceOver,
Reduce Motion, dark mode, or a real-speech retry. The transcript ladder handoff
is covered by a focused UI test, but those nested surfaces and accessibility
extremes still need the detailed tour or physical-device QA before release.
