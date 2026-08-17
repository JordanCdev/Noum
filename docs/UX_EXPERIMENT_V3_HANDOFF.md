# Noum V3 UX Experiment — handoff

Date: 2026-08-17
Branch: `ux-experiment`
Milestone: M14 — open the loop and earn TestFlight evidence

## Status

The V3 product direction and its production-hardening source pass are complete
for an experiment branch. Static verification passed in the source workspace,
and the 2026-08-17 Mac pickup now compiles as a Debug simulator app after the
narrow Swift repairs recorded below. The complete serialized unit target is
still red, so this is not yet a private-beta candidate, signed build, or
device-proven TestFlight build. Do not merge to `ux-overhaul` or describe it as
production-ready until the failing native tests and the simulator,
physical-device, live-service, and human-coach gates below pass.

## Experience contract

- Professional adult communication coaching; no mascot, face, orb, or generic
  AI-chat visual language.
- The unboxed waveform is reserved for voice: live listening, recording,
  capture finalization or spoken-turn processing, and the single
  Today-to-recording handoff. The source contract permits exactly 11 rendered
  callsites. It is never a
  generic badge, reward, navigation icon, proof marker, or chart.
- Static graphics use one closed semantic vocabulary: scope for a coach read,
  seals for verified evidence, star for XP, lock-open for a real unlock,
  numbered markers for attempts, chart/chronology for progress, microphone
  for practice, person for Profile, and raised hand for privacy. One graphic
  per surface is the default; a second appears only for separate data.
- One focus, one rep, one proof, one next move.
- Today mission: the user's persisted one-to-three-rep goal, one exact visible
  coaching target, and numbered reps. The three-rep Figma frame is a sample,
  not a hard-coded product contract or a fake Warm-up/Pressure curriculum.
- Default Summary: completion, at most one exact-session receipt, one evidence
  read, one selected next action, then optional Details and one visible Done.
- Profile: identity, current coach read, at most one due prompt, then Library.
- Reward energy is attached to exact-session verified improvement. XP supports
  the evidence; it never replaces it or pays twice.
- Motion has three tiers (calm, responsive, earned), is bounded, and respects
  Reduce Motion. The verified reward is one-shot and actionable within the
  1.8-second source budget; optional XP and unlock stages render only when
  their exact-session inputs exist.
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

Second-pass comparison row (originals preserved):

- Section: `464:801`
- Onboarding: `464:804`
- Today: `464:851`
- Practice: `464:909`
- Ask Noum: `464:964`
- Progress: `464:997`
- Profile: `464:1085`
- Settings: `464:1142`

V3.2 semantic-graphics row (all earlier rows preserved):

- Section: `476:1004`
- Onboarding: `476:1007`
- Today: `476:1024`
- Practice: `476:1049`
- Ask Noum: `476:1072`
- Progress: `476:1103`
- Verified reward: `476:2333`
- Comparison: `476:2466`
- Profile: `476:1141`
- Settings: `476:1184`

The V3.2 audit retains exactly one waveform, on the Today-to-recording
handoff. Reward, comparison, Progress, navigation, profile, privacy, plans,
learning, roleplay, and coach reads use role-specific graphics. Progress has
one authored read plus a categorical chronology—no duplicate tally tile—and
the path receipt makes only a path-unlock claim. Figma could validate but not
visibly render helper-generated SF Symbol private-use glyphs, so its visible
handoff uses Material Symbols Rounded while each layer name records the exact
authoritative SwiftUI SF Symbol mapping.

The V3.1 row addresses the first pass's main weakness outside the earned-reward
screen: it replaces equal-weight card stacks with screen-specific authored
hierarchy. Today now builds anticipation around the exact mission; Practice
leads with one prescription and progressively discloses the catalogue; Ask
binds the current coach read to one next move; Progress tells one comparable-
evidence story; Profile separates identity, coach read, plan, and library; and
Settings keeps trust/account controls quiet and scannable. The static review
exports are in `deliverables/noum-v3/round2/`; production remains responsible
for bounded state transitions and Reduce Motion behavior.

The 15-screen design audit has zero unexpected overflow, text collisions,
fractional typography, sub-11-point type, or internal-facing copy. Root and all
13 reward tracks persist `autoplay=true, loop=false`; Figma's motion-context
extractor incorrectly emits `loop/infinite`, so the visible one-shot
annotation and persisted Plugin API values are authoritative.

The canonical Today frame is named `Sample 3 · supports goal 1–3`, and its
mission nodes are now truthfully numbered Rep 1/2/3 rather than claiming an
unimplemented Warm-up → Answer first → Pressure sequence.

The current 40.6-second semantic-graphics walkthrough is at
`deliverables/noum-v32-semantic/Noum-V3.2-Semantic-Graphics-Walkthrough.mp4`.
Its source contact sheet, transition QA sheet, and decode report sit beside it.
Every frame is labelled **FIGMA DESIGN PROTOTYPE · NATIVE QA REQUIRED**. It is
design-review evidence, not an iOS interaction recording. The verified video
SHA-256 is
`5273e17c17d4a405786e174638fcd214ae5444ed06b17b1df5b7a646fbd61fd8`.

Code Connect could not be published because the current Figma seat is not an
Organization/Enterprise Dev or Full seat. Component and screen node IDs are
recorded in the local design-state ledger for a future mapping pass.

## Implemented in SwiftUI

- Shared V3 primitives: audio-bound waveform, closed semantic graphics,
  semantic surfaces, mission, evidence, progress, reward, minimum controls,
  and three-tier motion.
- Fast-lane and full onboarding: one decision per step with no phantom
  defaults.
- Today and Train: one coach-built mission/recommendation first, progressive
  catalogue second. The second pass adds an authored vertical rep journey,
  truthful mode-specific metadata, a complete expanded catalogue, and a
  glyph-led dock without changing recommendation or navigation ownership.
- The exact accepted Today or Train recommendation now crosses navigation as
  one bounded, one-shot intent (fingerprint, focus, target, mode, demand).
  Timed, Conversation, Filler Control, and Pressure show that same target;
  stale, malformed, mismatched, expired, or double-consumed intents fail
  closed. Non-Timed mounted targets are not promoted into verified Progress
  evidence without a transcript-retry comparison.
- Timed practice, processing, Summary, transcript retry, and verified reward.
- Ask Noum, live coach, Coach Read, and four-week plan. The current reply is
  visually distinct from quiet history and owns one bounded continuation.
- Lessons, roleplay, Filler Control, Conversation Practice, Pressure, and Cut
  the Crutch use mode/learning/conversation graphics at rest and reserve the
  shared waveform for real recording, capture finalization, or a live spoken
  turn. Their existing evidence
  and finalization owners remain unchanged.
- Progress no longer draws arbitrary waveform heights as if they were a
  continuous score. Comparable evidence renders as a labelled categorical
  chronology: Improved, Held, or Didn't hold.
- Verified retry reward no longer repeats one waveform for hero, XP, proof,
  and unlock. It shows a verification seal, real XP only when earned, one
  source-bound evidence card, an unlock only when true, and one comparison
  action. Comparison uses numbered attempts and a transformation bridge.
- Progress, Profile, Coaching Memory, Settings, privacy/account, permission,
  offline, and beta-feedback surfaces. Progress now presents interpretation,
  comparable evidence, and one target-bound practice action in that order;
  Profile and Settings reserve success styling for supported claims.
- Microphone and Speech Recognition denial remain distinct typed causes and
  route all nine audited spoken-practice surfaces to Open Settings instead of
  retrying a permanently denied capture.
- Summary exposes no synthetic numeric score: without exact evaluator evidence
  it says **Not scored**. It has one next-action owner and one visible exit.
- Progress cohorts like-for-like verified retry evidence by lever, validates
  its source → retry join, and offers one prompt-backed **Practice this target**
  action only when the original source is still qualified and available.
- First-week comparison, transfer check-in, and Day-7 read actions are
  evidence-driven. Elapsed days change reminder bands but cannot manufacture a
  comparison, and viewing the Day-7 read releases Home's one support slot.
- Local-only fake friend requests and unavailable social destinations are
  removed from the beta surface.

## Coach-quality correction

The provider context now receives a private eight-field decision plan before
prose. The response contract is acknowledge, specific read, demonstrated
wording or delivery, then one attempt. Personal metrics are opt-in. The client
now evaluates normalized provider prose before the display finalizer can strip
raw report-voice fragments, so a rejected scorecard cannot be clause-edited
into broken user-visible prose.

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
- Coach Arena Node: 124 passed, one expected skip for absent local replay
  captures.
- Coach Arena Python: 178/178.
- Authored coach fixtures: 53/53 validated.
- Release-script Python suite: 120/120.
- Cloud/static tests: 35/35.
- Combined delimiter/directive, resource, manifest, workflow, identifier, and
  source-contract audits: pass.
- `git diff --check`: pass.

The source handoff was produced in a Linux environment without Xcode, a Swift
compiler, CoreSimulator, signing identity, protected plists, or a physical
iPhone. Historical green results from another source revision do not prove
this branch.

## Native pickup verification — 2026-08-17

- Imported bundle commit `0bfd8f654036f004933412f48a79160048e8a644` as a
  19-commit fast-forward from `5cf3d3f898ca32769271d1c1257a94d9cd3a554e`.
- Repaired five compiler-error classes without changing state ownership or
  product behavior: two preview-only attempts to write a read-only Reduce Motion
  environment value, a non-`Void` animation closure, a missing opaque-view
  return, an out-of-scope accessibility presentation value, and a stored
  `ViewBuilder` closure that needed escaping semantics.
- Added the missing `@testable import Noum` to the bundled V3 onboarding shell
  test file so the full test target can compile and report product failures.
- Debug simulator build passes on iPhone 17 / iOS 26.4.
- The serialized `NoumTests` run reports **4,907 passed, 24 failed, one expected
  failure, and zero skipped**. Failures span coach quality/reliability fixtures,
  secure-wire and corpus contracts, V3 coach-surface language, path/progression
  naming, first-week coaching, professional-loop fields, and Apple account-
  deletion ordering. The ephemeral local result bundle is
  `/private/tmp/noum-ux-experiment-publish-units-20260817-r2.xcresult` on the
  pickup Mac.
- This evidence upgrades the branch from uncompiled source to a buildable UX
  experiment. It does not clear the native test gate or production readiness.

## Required Mac and TestFlight gates

1. Materialize the protected build configuration and bind the source commit.
2. Run a clean Release build, repair the 24 known unit failures, and rerun the
   complete `NoumTests` target to green.
3. Run the mandatory UI shard: onboarding → spoken rep → verified reward →
   Summary → return, plus beta feedback and microphone/Speech-denial recovery.
4. Capture iPhone SE-size and current Pro-size screenshots, dark/light,
   Accessibility XXXL, Reduce Motion, and interruption/background states.
5. Complete a physical VoiceOver pass and real microphone/Bluetooth/offline
   pass.
6. Verify StoreKit, auth upgrade, sign-out/in, deletion, App Check, and support
   URLs on the same signed build.
7. Deploy the reviewed privacy/support/coaching-trust pages and bind
   `noum.app` DNS/TLS. The currently live support/coaching routes and parked
   custom domain are not a releasable legal/support surface.
8. Archive, upload, wait for TestFlight processing, and install that exact
   build.
9. Run 10–20 varied live-provider reps, then a blinded professional-coach
   review before widening the beta.
10. Run a 7-day concierge beta with baseline/retry audio and one real-world
   transfer check per tester.

Until those gates pass, the correct release verdict is: **buildable UX
experiment; native test gate red; not a private-beta candidate**.
