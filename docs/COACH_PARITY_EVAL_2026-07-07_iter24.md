# Coach-parity eval — iteration 24 (2026-07-07, autonomous `noum-1`)

Branch: `ux-overhaul`. Score anchor: **~7.6/10** (unchanged headline; see the honest
read in §5). This run: an 11-role workflow (ground-truth → market/UX/persona/coach
critique → adversarial verify → synthesis, 38 agents incl. retries, ~2M tokens),
**one keyless collision-safe lever shipped** (Move #2 below), and a decision-grade
executable backlog so the next real coding session lands in one sitting.

## Constraints in force this run (why the lane was narrow)
- **No `ANTHROPIC_API_KEY`.** The two axes Noum trails most — live content-substance
  critique (~4/10) and interactive roleplay (~3/10) — are genuinely key-gated, not
  policy. Jordan-only to unlock. (`ANTHROPIC_BASE_URL` is set but is harness routing,
  not a coach-arena key.)
- **A concurrent agent (pid 685) was live in this repo.** The Swift app lane is a
  collision hazard, so work stayed on cold/collision-safe files. `CoachingOnboardingView.swift`
  was verified cold (mtime Jun 21, absent from recent commits) before editing it.
- The dominant first-rep lever (`SPEC_first_rep_auto_guided.md`) is **felt-QA gated —
  not for blind autonomous build** — and lives in the hot `ContentView` router. Left
  for a device-owning session per its own spec.

## Shipped this run (keyless, collision-safe, compile-verified)
**Move #2 — onboarding coach-commitment read-back** (`Noum/CoachingOnboardingView.swift`).
The profile-summary card previously ended on a flat list of rows. Added a coach-voice
card (`coachCommitmentCard` / `coachCommitmentLine`) that (a) reads the profile back in
the coach's own voice using the *same* enum resolvers Home cold-start and the Ask Noum
day-0 greeting use (`SpeakingStyleGoal.coachingDescription`, `SpeakingChallenge.trainingFocusFragment`
— `PracticeSupport.swift:519,451`), and (b) states the honesty stance *before* the first
rep: *"I won't guess at a verdict from a form — your first rep gives me the evidence,
and then I'll name the one thing worth working on."*

Why this is the right first ship: positioning is Noum's farthest-trailing axis (~5/10)
because the honesty/evidence moat is **invisible until week two**. This makes it legible
at the highest-traffic first-run moment, with **zero pipeline change**, no new state, no
overclaim (single-rep read stays fillers+wpm; no rating/trend/league promise). Enum-derived,
so it never surfaces user-typed challenge text (lock-screen safety; custom challenge maps
to a routing bucket at `CoachingOnboardingView` ~785). a11y: combined element + explicit
label. On-token: brand blue + `waveform` glyph (brand-rule compliant), no new motion.

## Refreshed competitor snapshot (2026) — the strategic reframe
The recorded competitor delta was from 2026-06-08 (a month stale). The material change:
**the whole category converged on cloud-LLM roleplay + cross-session memory — and every
one of those features stores or transmits the user's actual speech content.** That hands
Noum a *category-of-one* privacy/honesty wedge rather than a gap to chase.

| Rival | 2026 material change | Data posture | Source |
|---|---|---|---|
| **Duolingo** (Lily / Video Call) | Persistent memory: post-call LLM appends a per-user "List of Facts" injected into future calls; transcript + tap-to-speak | LLM-invented fact list, no stated retention/consent/deletion | blog.duolingo.com/ai-and-video-call/ |
| **Yoodli** | Custom scenarios (paste a JD → generated interview), persona roleplay, **live Zoom/Teams meeting coaching**; free tier capped at 5 roleplays | Public privacy walk-back on recorded-speech reuse; train-on-your-data opt-out gated behind paid tier | yoodli.ai/privacy-policy |
| **Speeko** | **"Convos"** AI roleplay + Roger Love content + **Mac Virtual Microphone** for live Zoom/Teams coaching | Cloud-LLM roleplay stores/transmits speech | speeko.co/coaching |
| **Orai** | Camera-based facial-expression analysis + adaptive lessons + enterprise dashboard | Cloud + camera capture | orai.com/ |
| Market context | — | Bloomberg (2026-06-30) flagged consent-less AI meeting-notetakers as a 2026 privacy flashpoint | bloomberg.com/news/newsletters/2026-06-30/ |

**Read:** roleplay + memory + live-meeting coaching are now table stakes, and all of them
route the user's words through a model with weak governance. **No rival can truthfully say
"we never send your words to a chat model, and every quote we show you actually came out of
your mouth."** That is Noum's defensible position — and it is currently silent. Making it
legible (Moves #2–#5) is the largest *keyless* gain available.

## Prioritized executable backlog (keyless, adversarially verified)
22 candidate levers survived adversarial verification (verifier killed anything violating a
trust red line, secretly key-gated, already-built, or unverifiable). Ranked by
leverage × keyless × collision-safe. **Paths corrected** where the ground-truth pass
hallucinated (noted inline).

| # | Lever | File(s) | Effort | Note |
|---|---|---|---|---|
| 1 | **Flip `AutoGuidedFirstRep` default-ON** | `Noum/AutoGuidedFirstRep.swift:38`; router `Noum/ContentView.swift` ~1411 | S + felt-QA | Wiring already landed & correct; gated on on-device felt-QA (M26). Do NOT flip blind. Attacks the acquisition/first-rep gap = path to A*. |
| 2 | **Onboarding coach-commitment read-back** | `Noum/CoachingOnboardingView.swift` | S | ✅ **SHIPPED this run.** |
| 3 | **Private-by-design trust strip** | `ProfileView.swift` `coachLoopReadinessCard` ~2608 + onboarding | S–M | Ship ONLY the scoped claim: "analyzed here, not uploaded to a chat/roleplay model" + "every quote is verbatim-verified". Do NOT ship a broad "nothing leaves your device" — raw audio does go to cloud STT. Copy accuracy is the gate. |
| 4 | **Stated-stance honesty line pre-rep-5** | `Noum/HomeCoachCard.swift` / `Noum/HomeSignalGate.swift` (cold lanes) | S | "I won't fake a trend from two reps, and I won't tell you a drill fixed you." Makes the `.forming` cap visible. |
| 5 | **"Never records your meetings" line** | hosted on Move #3's strip | S | Real product boundary (no meeting-join capability by design). Counters Yoodli/Speeko live-meeting vector + Bloomberg flashpoint. Do NOT chase live-meeting coaching — it would blow up the wedge. |
| 6 | **"Recurring, not one event" Big Moment option** | `Noum/BigMomentIntakeView.swift`; enum `Noum/BigMomentStore.swift:8` | S | Answers the everyday-dread user (standups, not keynotes). **HOT lane** — new enum case forces edits across exhaustive switches; sequence off the contended lane. |
| 7 | **Thread built IM prep prompts into IM mode** | `Noum/PrepSessionView.swift:246` (passes `scenario:nil,tone:nil` for `.imConversation`) | S | Rep packs already built (`PrepSessionPlanner.plan()`); documented TODO is the wiring. Deepens "practice my actual moment." |
| 8 | **Case-history multi-entry timeline** | `Noum/CaseReviewCard.swift:91` (renders only `adaptationLog?.last`); store `PrimaryFocusMemory.swift:236` | S–M | Persistence already ships (bounded 8 dated shifts). Novel delta = render the full dated timeline so the user watches the coach change its mind. Rendering-only. |
| 9 | **Positional trend in Home hero subtitle** | `Noum/HomeCoachCard.swift`; engine `Noum/RepEventTrend.swift` (NOT a standalone `RepEventTrendEngine.swift`) | S | "Rushed the close in 4 of your last 5 reps" already feeds Summary/Ask-Noum; thread that one sentence into the Home subtitle chain. No parallel state; no second coach door. |

**Rejected / non-actionable (do not build):** on-device "structural content read" keyword
heuristic (crude proxy for a semantic question → reintroduces the overclaim the invariants
forbid); "deterministic countdown to first trend" (misreads the evidence floors; "unlocks"
wording promises a reveal the trend engine intentionally doesn't guarantee → fake progress);
rep-5 dead-zone / content-ceiling (accurate diagnoses with no keyless fix that doesn't
fabricate a trend below the floor); "Not sure yet" onboarding default (the voice-goal gate
is deliberate — a phantom default is the exact tap-through the code refused).

## Key-gated levers (deferred to Jordan — need `ANTHROPIC_API_KEY`)
The Anthropic provider is already scaffolded (`AICoachChatService.swift:777` — `.claudeReasoning`
case, `ANTHROPIC_API_KEY` env read, endpoint + headers), so the app lights up the moment a
key is supplied.

1. **Keyed "Content Read" pass behind the no-transcript wall** — the one structural lever
   for the content/substance axis. A server-side keyed LLM reads the raw transcript *once*,
   extracts a small *structured* read (claim / support / the-ask / weakest-link / did-the-point-land),
   verifies any quote through `ProofMomentService`, and writes **only that structured read**
   into `CoachMemoryStore` — never the raw transcript. Extends the M29 structured-read slot
   (`CoachContextBuilder.swift:1262`). Guardrail: distilled read only; quotes pass ProofMoment;
   self-hides below the evidence floor. Lands in the two hottest coach files — sequence carefully.
2. **Live interactive roleplay** — a counterpart that improvises, interrupts, escalates
   (today IM mode is a rubric-scored tone-drill, not a partner who pushes back). Needs live
   per-turn generation. Do it on-device/opt-in with an explicit consent boundary so it doesn't
   dissolve the privacy wedge.

**Recommendation:** keep both on a *separate* key-gated track. The keyless moves widen the
defensible wedge without ever transmitting the user's words — the exact position the market
just vacated.

## §5 — The honest 10/10 answer (unchanged by design)
A true "replaces a human coach" 10/10 is refused **by design**, and the refusal is a feature.
Splitting the parity gap into three honest buckets:

**(a) By-design refusal — leave it; do not chase.** The `.forming` cap
(`CoachParityReadiness.swift` — the validation stage structurally cannot return `.earned`),
the no-transcript-to-chat invariant (`CoachContextBuilder.swift:21`), and the verbatim-quote
gate (`ProofMomentService`) intentionally hold the ceiling below 10. Removing them would
raise a benchmark number while *lowering* real-world credibility — the exact overclaim a
senior coach never makes.

**(b) Key-gated capability — real, un-closeable without infrastructure.** Content/substance
(~4/10) and live roleplay (~3/10) are the two axes that genuinely cap parity at ~7.6. Both
require a keyed LLM. This is an infrastructure/cost decision, not a prompt problem.

**(c) Still buildable now — keyless.** Positioning (~5/10, the moat is invisible not absent):
Moves #2–#5 make the honesty/privacy wedge legible at the trust-decision moments — the
largest keyless gain, but it lifts *perceived* positioning, not the structural axes, so it
can't alone move the headline much past ~7.6–7.8. Acquisition/first-rep: Move #1 after
felt-QA. Believable-memory depth: Moves #7–#9.

**No fake certainty:** the keyless bucket is real and worth shipping, but it closes the
*visibility* gap and the *first-rep* gap — not the *content/roleplay* gap. The headline
number moves meaningfully only when (b) is funded with the key, and it is capped below 10
forever by (a), on purpose. That cap is Noum's trust moat, not a limitation to engineer away.

## Verification
- `Noum/CoachingOnboardingView.swift` edit compile-verified via isolated
  `xcodebuild build -derivedDataPath ./DerivedData/Noum-iter24` (generic iOS Simulator
  destination; isolated DD so the concurrent agent's build DB was not touched). See build log.
- No push. Staged by explicit pathspec only (this doc + the one Swift file); the concurrent
  agent's uncommitted work left untouched.
