# Coach-parity eval — 2026-06-29 (autonomous `noum2` run)

**16th iteration. Tree was HOT — a concurrent `ultracode` session was actively
editing the coach-chat surface (`AICoachChatService.swift` touched 13 min before
this run, plus two judgement-layer test files inside 30 min). So this run did NOT
re-score and did NOT touch the coach surface. Instead it shipped the one
genuinely-new, competitor-parity slice the last 15 iterations named but always
deferred — the annotated-transcript-timeline substrate — in two brand-new files
that collide with nothing. Build + new suite GREEN in an isolated worktree at
HEAD. No push.**

## Scope

Add `Noum/TranscriptTimeline.swift` + `NoumTests/TranscriptTimelineTests.swift`.

A pure value-type engine that turns a rep's captured per-word timings
(`[TranscriptUpdate.WordTiming]`) into a typed, plottable timeline of:

- **words** — each positioned 0…1 across the rep, filler-flagged;
- **pauses** — gaps ≥ `PauseMetrics.minPauseSeconds`, classified filled/unfilled;
- **bursts** — pause-delimited phrases whose local pace ran over
  `ConversationalPaceBand.maxWPM`, with a documented sample-size floor.

## Product goal

This is the data substrate behind the **annotated transcript timeline** — the
signature review surface in Speeko and Yoodli (the transcript shown back with
every filler highlighted *in place*, every silent beat drawn as a *real-duration*
gap, and rushed stretches flagged *where they happened*). Every one of the last
15 iterations flagged it as the strongest next competitor-parity move and the
`docs/...` competitor delta lists "visible analytics surface" as a Yoodli/Speeko
edge — yet it was always deferred because the tree was busy on the coach surface.

The blocker was real: Noum *captures* the per-word timings but
`SpeechRecognizerViewModel` consumes them once for `PauseMetrics` and **discards
them** ("Word timings stay transient — we don't persist them"). So the app knows
*how many* pauses a rep had but can never SHOW *where* they fell. This engine is
the missing transform; persistence + render are the next (device-QA'd) slice.

## Existing patterns reused (reuse-first, per CLAUDE.md)

- `TranscriptUpdate.WordTiming` — the existing per-word type; no new model.
- `PauseMetrics.minPauseSeconds` (0.5s) — the *same* pause threshold, so the
  timeline and the persisted `PauseMetrics` can never disagree on pause count
  (asserted by a cross-check test against `PauseMetrics.compute`).
- `ConversationalPaceBand.maxWPM` (150) — the *same* upper pace edge the
  feedback engine already uses; bursts introduce no new pace constant.
- Filled-pause classification mirrors `PauseMetrics`' "filler start inside the
  gap" definition exactly (the word following the gap is a filler).

The only new constant is `minBurstWords = 4` — an explicit *sample-size floor*
(CLAUDE.md: "avoid fake certainty from small sample sizes"), not a pace tuning
knob, so a 2-word fragment can't be branded a "rushed burst".

## Root cause addressed

Not a bug — a capability gap. The raw signal exists end-to-end but dies at
finalize. This slice is the smallest honest unit that revives it: a pure,
testable transform, with persistence/render deliberately deferred so the slice
lands collision-free and fully verified rather than half-wired through a hot
shared surface.

## Collision discipline

- Concurrent `ultracode` session (`--effort xhigh`, PID 44880) held uncommitted
  edits to `AICoachChatService.swift`, `CoachReliabilityGate.swift`, and 3
  judgement-layer test files. **None touched.** Committed with explicit
  pathspecs (only the 2 new files); those 5 files preserved byte-for-byte.
- Project uses `PBXFileSystemSynchronizedRootGroup` (objectVersion 77) → new
  files in `Noum/` and `NoumTests/` auto-join their targets with **zero
  `project.pbxproj` edit**, so even the project file is untouched.
- Built in an isolated worktree at committed HEAD (`b8dad571`) so the concurrent
  session's in-progress edits never polluted the verification.

## Verification

- `xcodebuild test -scheme Noum -only-testing:NoumTests/TranscriptTimelineTests`
  on iPhone 17 Pro sim, isolated DerivedData, worktree at HEAD.
- Result: **`** TEST SUCCEEDED **` — 11/11 pass**, full app + test target
  compiled clean (one assertion was self-corrected mid-run: the first word's
  *midpoint*, not its start, normalizes to ~0.07 not 0 — a wrong test
  expectation, not an engine bug; fixed and re-verified green).
- 11 structural tests: empty/degenerate handling, punctuation-insensitive filler
  flagging, pause threshold at the `minPauseSeconds` boundary, **agreement with
  `PauseMetrics.compute` on pause count for the same stream**, filled-vs-unfilled
  classification, burst fires only above `maxWPM`, burst suppressed under the
  sample-size floor and inside the band, pause-splits-burst-phrases, and
  normalized-position bounds/ordering.

## 10/10 answer — unchanged, and why

The literal "with no doubt replaces a human communications coach" 10/10 stays
**REFUSED by design** (`CoachParityReadiness.forming` cap — the deliberate trust
moat; do NOT remove). That is the same answer all 15 prior iterations gave and it
has not moved, because the levers that would move it are human-gated, not code:

- proxy-not-perception scoring (keyword/threshold stands in for perceived
  delivery — audio-only ceiling);
- thresholds not yet externally calibrated against expert baselines;
- the dark acquisition lever (`AutoGuidedFirstRep` instant-start) still
  default-OFF, gated on a device felt-QA pass only Jordan can run.

What this run *does* move is the **competitive-substance** axis vs.
Speeko/Orai/Yoodli: it lays the first stone of their signature visual analytics
surface, which Noum genuinely lacked, in a form that's pure, tested, and ready
to render.

## Next buildable slice (deferred, device-QA-gated)

1. Persist `TranscriptTimeline`'s inputs (or the computed timeline) onto the
   saved session model so a review surface can re-render it later. Touches the
   shared `PracticeSession` persistence — land when the tree is quiet.
2. SwiftUI render in the rep review/summary surface — filler dots, pause gaps
   sized to duration, burst bands — respecting reduced-motion + a11y. Needs
   device felt-QA, so it stays out of an unattended run.
