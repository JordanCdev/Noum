# Noum V3 UX Experiment — handoff

Date: 2026-08-17
Branch: `ux-experiment`
Milestone: M14 — open the loop and earn TestFlight evidence

## Status

The V3 product direction and its source implementation are complete for the
private-beta candidate. The branch is source- and static-verified, but it is not
yet a signed or device-proven TestFlight build. Do not merge to
`ux-overhaul` or describe it as production-ready until the Mac, simulator,
physical-device, and human-coach gates below pass.

## Experience contract

- Professional adult communication coaching; no mascot, face, orb, or generic
  AI-chat visual language.
- The unboxed waveform is Noum's identity and follows real states: ready,
  listening, processing, and earned improvement.
- One focus, one rep, one proof, one next move.
- Default Today mission: three bite-sized reps in about three minutes.
- Default Summary: completion, one evidence read, one selected next action,
  then optional Details and Done.
- Profile: identity, current coach read, at most one due prompt, then Library.
- Reward energy is attached to exact-session verified improvement. XP supports
  the evidence; it never replaces it or pays twice.
- Motion has three tiers (calm, responsive, earned), is bounded, and respects
  Reduce Motion. The verified reward is a one-shot 2.4-second ceremony.
- Social/friend surfaces remain hidden until their trusted authority is live.
- The beta interface is English; practice speech language remains an
  independent STT/prompt choice.

## Canonical design

Figma file:
<https://www.figma.com/design/srCgE5IP3rWoNMWtHo3AnI/Noum-%E2%80%94-Product-Journey---Design-System?node-id=432-497>

Key frames:

- Today: `434:533`
- Practice plan: `434:2292`
- Live practice: `434:2364`
- Summary: `434:2418`
- Conditional verified reward: `435:665`
- Ask Noum: `437:2318`
- Progress: `437:2351`
- Profile: `437:2439`
- Settings: `437:2493`
- Speech-permission recovery: `437:2547`

The 15-screen design audit has zero unexpected overflow, text collisions,
fractional typography, sub-11-point type, or internal-facing copy. Root and all
13 reward tracks persist `autoplay=true, loop=false`; Figma's motion-context
extractor incorrectly emits `loop/infinite`, so the visible one-shot
annotation and persisted Plugin API values are authoritative.

Code Connect could not be published because the current Figma seat is not an
Organization/Enterprise Dev or Full seat. Component and screen node IDs are
recorded in the local design-state ledger for a future mapping pass.

## Implemented in SwiftUI

- Shared V3 primitives: waveform, semantic surfaces, mission, evidence,
  progress, reward, minimum controls, and three-tier motion.
- Fast-lane and full onboarding: one decision per step with no phantom
  defaults.
- Today and Train: one coach-built mission/recommendation first, progressive
  catalogue second.
- Timed practice, processing, Summary, transcript retry, and verified reward.
- Ask Noum, live coach, Coach Read, and four-week plan.
- Lessons, roleplay, Filler Control, Conversation Practice, Pressure, and Cut
  the Crutch use the shared waveform and preserve their existing evidence and
  finalization owners.
- Progress, Profile, Coaching Memory, Settings, privacy/account, permission,
  offline, and beta-feedback surfaces.
- Speech Recognition denial now routes to Open Settings instead of retrying a
  permanently denied capture.
- Local-only fake friend requests and unavailable social destinations are
  removed from the beta surface.

## Coach-quality correction

The provider context now receives a private eight-field decision plan before
prose. The response contract is acknowledge, specific read, demonstrated
wording or delivery, then one attempt. Personal metrics are opt-in.

The intervention catalogue covers answer structure, proof, closing, pauses,
commitment, pressure, disagreement, storytelling, listening, vocal contrast,
and audience adaptation, with indications, contraindications, a model, drill,
pass rule, transfer test, and last-three novelty.

Legitimate information questions have a separate answer-only posture. Generic
benchmarks are request-bound, ranged, and caveated; they never authorize claims
about the user's telemetry. Reliability gates fail closed on wrong-question
answers, report voice, repeated interventions, omitted demonstrations,
non-answers, scaffold leakage, and unsupported benchmark certainty.

Professional-coach parity is still an outcome claim, not a source-code claim.
It requires blinded coach calibration, audio review, and longitudinal transfer
evidence.

## Verification completed here

- Operational static readiness: 22/22.
- App Store package validator: pass.
- Coach Arena Node: 118 passed, one expected skip for absent local replay
  captures.
- Coach Arena Python: 178/178.
- Release-script Python suite: 117/117.
- Cloud/static tests: 35/35.
- Combined delimiter/directive, resource, manifest, workflow, identifier, and
  source-contract audits: pass.
- `git diff --check`: pass.

This Linux environment has no Xcode, Swift compiler, CoreSimulator, signing
identity, protected plists, or physical iPhone. Historical green results from
another source revision do not prove this branch.

## Required Mac and TestFlight gates

1. Materialize the protected build configuration and bind the source commit.
2. Run a clean Release build and the complete `NoumTests` target.
3. Run the mandatory UI shard: onboarding → spoken rep → verified reward →
   Summary → return, plus beta feedback and speech-denial recovery.
4. Capture iPhone SE-size and current Pro-size screenshots, dark/light,
   Accessibility XXXL, Reduce Motion, and interruption/background states.
5. Complete a physical VoiceOver pass and real microphone/Bluetooth/offline
   pass.
6. Verify StoreKit, auth upgrade, sign-out/in, deletion, App Check, and support
   URLs on the same signed build.
7. Archive, upload, wait for TestFlight processing, and install that exact
   build.
8. Run 10–20 varied live-provider reps, then a blinded professional-coach
   review before widening the beta.
9. Run a 7-day concierge beta with baseline/retry audio and one real-world
   transfer check per tester.

Until those gates pass, the correct release verdict is: **source-complete,
private-beta candidate pending native proof**.
