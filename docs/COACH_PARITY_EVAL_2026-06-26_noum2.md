# Coach-parity continuation — 2026-06-26 (noum2 run)

Branch: `ux-overhaul` · HEAD at start: `2dc0f5d` · Run: autonomous `noum2`
Predecessor: `docs/COACH_PARITY_EVAL_2026-06-26.md` (7.5/10 @ `f392b01`, noum-1 run earlier the same day).
Method: forward-looking role-diverse workflow (5 roles → synthesis), code-grounded; then a
single collision-safe, build-verified code slice; documentation; no push.

## Why this run is forward-looking, not a 9th scorecard

The noum-1 run earlier today already produced a fresh role-diverse 7.5/10 against this same
HEAD. Re-scoring hours later on the same tree would reproduce 7.5 and add nothing. So this run
aimed the role panel at the *next* question — **"given the acquisition lever is now code-complete
but dark, what is the concrete collision-safe path to the realistic ceiling, and what can only
Jordan unblock?"** — and shipped the one genuinely safe code slice it surfaced.

## Score: holds at 7.5/10 (unchanged; honest)

No score movement is claimed. The big lever (`AutoGuidedFirstRep`) is still `defaultEnabled = false`
(`Noum/AutoGuidedFirstRep.swift:38`) and only a device felt-QA pass moves the number. This run's
code slice (a CTA copy fix) is real but small — polish, not a points mover.

## The straight 10/10 verdict (role synthesis, code-grounded)

- **Literal "with no doubt replaces a human coach" / 10/10: refused by construction, and correct.**
  `CoachParityReadiness` caps the validation stage at `.forming` and never returns `.earned`
  (`Noum/CoachParityReadiness.swift:21` comment is explicit; cap at ~`:182-187`). Removing it would
  convert the single biggest trust asset into the generic-AI-wrapper overclaim VISION rejects. **Do
  not chase it.** A discerning user trusts Noum *because* of the refusal.
- **Achievable axis (rival/beat Speeko·Orai·Yoodli·Duolingo on substance + trust + a real
  first-contact moment): honest 7.5 today, realistic ~9 ceiling.** The gap is almost entirely the
  first 30 seconds, not depth.

## Where Noum leads / lags (verified)

| | State | Evidence |
|---|---|---|
| Coach memory / durable case file | **LEADS** | longitudinal, not per-session scores; video delivery reaches memory (`SummaryView.swift:2328`) |
| Honesty engineering | **LEADS** | n=1 = fillers+wpm only, no fake rating/peak/league (`hasRatedEvidence` gate; `CoachParityReadiness` cap) |
| Closed transfer loop | **LEADS** | practice tied to reported real-world outcomes, n≥3 floor (`BigMomentStore`) |
| First-contact decision tax | **LAGS** | returning users still hit the picker (`ContentView.swift:1420`); fix built but dark |
| Time-to-first-word | **LAGS** | 15s thinking countdown fires before speaking even with the flag on (`TimedPracticeView.swift:690,692`) |
| Audio-only prosody | **LAGS** | no prosody→memory path for the default audio rep; Yoodli is multimodal |
| Cloud-STT SPOF on rep #1 | **LAGS** | all providers cloud, no on-device `SFSpeech` fallback (`SpeechRecognizerViewModel.swift:284-291`) |
| Signup-before-speech | **LAGS** | 3 onboarding questions before the first rep (`CoachingOnboardingView`) |

## Collision map (verified against the live working tree)

The coach surface is occupied by **two concurrent sessions' uncommitted work**:
- **Staged (~28 files):** AI-provider-diagnostics + home dock layout — all `AI*Service.swift`,
  `SettingsView`, `SummaryView`, `ProfileView`, `CoachContextBuilder`, `PracticeSupport`,
  `NoumTests.swift`, etc.
- **Unstaged (in-progress):** the **mic-readiness guard** — `PracticeMicrophonePermissionState`
  lives in `SpeechRecognizerViewModel.swift` + `TimedPracticeView.swift`, plus untracked
  `NoumTests/PracticeMicrophonePermissionStateTests.swift`. **Do not touch.**

Recommended-sequence status (from the 06-26 eval):
- **#3 mic soft-ask** — **IN-PROGRESS** by a concurrent session (the unstaged mic-guard slice).
- **#4 ProfileView transfer teaser** — **BLOCKED** (`ProfileView.swift`, `SummaryView.swift` staged).
- **#5 onboarding→picker `whyNow` copy** — **BLOCKED** (`PracticeSupport.swift`, `NoumTests.swift` staged).
- **#6 delete orphaned `SessionIntentPromptView.swift`** — **SAFE** (verified zero external refs), low value.

## What shipped this run — `FirstRepCelebration.swift` CTA reframe

`Noum/FirstRepCelebration.swift` is clean (in neither diff) and is *presented* from the staged
`SummaryView.swift:907` — so the slice edits only the file's internal content and keeps the
`init(session:onContinue:)` signature stable (no staged-file touch).

The change: the post-first-rep celebration's primary CTA **"Continue" → "See the full read"**
(`:272`). It names the reward waiting underneath (dismissing the cover reveals the full `SummaryView`
read; the celebration itself shows only a one-line observation), fixing the "dead Continue" the role
panel flagged. Honest to the action — it does **not** promise a second rep the button doesn't start,
and it does not add a line (the file's design rule is "a single resonant frame, not an information
panel"). Already-present strengths confirmed by reading the file: quote-as-hero observation slot
(`:215-265`), soft per-voice non-overclaiming framing (`:512-549`), `hasRatedEvidence`-respecting
(no rating shown), reduce-motion + a11y compliant. Fires on `totalSessionCount == 1` (`:648-651`) —
including the non-pressure auto-guided rep — so it improves the cold-start payoff directly.

## The bigger first-rep fix this run could NOT ship (blocked by contention)

The role panel's highest-leverage first-rep move — **for the auto-guided rep only, suppress the 15s
thinking countdown and keep the seeded prompt visible** so the user speaks in ~2–3s, not 15 — lives
in `TimedPracticeView.swift` (`:690,692`), which is occupied by the in-progress mic-guard slice. A
build-ready spec is in `docs/SPEC_first_rep_fast_start.md`; land it *after* the mic-guard slice, with
the flag-flip felt-QA.

## What ONLY Jordan can unblock (human-only levers)

1. **Flip the flag + felt-QA on a physical device.** The simulator has no microphone, so only a real
   device can certify mic-arms-once / no-echo / <30s-to-first-word / honest-read for
   `AutoGuidedFirstRep.enabled`. Sequence it *after* the unstaged mic-guard lands (so you QA the final
   arming path) and *with* the fast-start fix above (or you certify the worst version: countdown +
   interrupt). **Highest-leverage single action — converts the largest dark asset into the A* demo
   moment.**
2. **Cloud-STT fallback decision** — whether to add an on-device `SFSpeechRecognizer` fallback for
   rep #1 (a product call against the STT philosophy, not a ticket).
3. **Deferred-signup decision** — whether to let users speak before the 3 onboarding questions
   (`AutoGuidedFirstRep.currentAccountID()` already falls back to `"guest"`, so the plumbing is
   sympathetic; the positioning is yours).
4. **Video-into-coach-memory decision** — promoting audio prosody (or routine video) into the
   coaching loop is a multi-week architecture commitment (privacy, storage, on-device vision).

## Honest ceiling statement

With the flag flipped *after* the fast-start fix and the mic-guard landing, Noum realistically reaches
**~9/10** on the achievable axis: it matches the leaders' "one tap to speaking" table-stakes while
keeping the case file, transfer loop, and anti-overclaim honesty none of them have. The permanent gap
to a literal 10 is the trust moat itself — Noum will never self-certify that it "with no doubt replaces
a human coach," because that certainty is exactly what the `.forming` cap refuses to fake. Keep the
moat; close the first 30 seconds.

## Verification

- Collision map verified directly against `git status` / `git diff` of the live tree.
- `FirstRepCelebration.swift` confirmed clean and presented from `SummaryView.swift:907` (signature
  kept stable).
- CTA slice **build-verified** in an isolated worktree at HEAD + the edit (isolated DerivedData,
  iPhone 17 sim) — see commit message / handover for the build result. (Copy-only change; no behavior,
  layout, or signature change.)
- **Not run (honest):** felt/visual QA of the celebration on device, and the auto-guided flag QA —
  both require a physical device + microphone this autonomous run does not have.
- **Not pushed** — consistent with every prior continuation; Jordan reviews before push.
