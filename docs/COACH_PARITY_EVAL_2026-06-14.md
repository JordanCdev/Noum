# Coach-parity multi-role evaluation — 2026-06-14

Produced by the `coach-parity-current-0614` workflow (6 role agents → adversarial
code verification → strategist synthesis). Run on branch `ux-overhaul` at HEAD
`49b96e9` — the FIRST evaluation of the tree *after* the coach-call redesign
(`7be6d71..49b96e9`: CHAT-HONESTY, CHAT-GATE, CHAT-MODEL, VOICE-DEDUP, CALL-PTT).
The 06-11 eval (`a6e7524`, 7.0) predates that redesign, so this supersedes it.

30 agents, ~5.0M subagent tokens. NB: the adversarial Verify phase suffered
heavy stalls under concurrency pressure (4 of N gaps fully re-verified against
code; the rest carried from the role evals' own cited evidence). The synthesis
and scorecard are grounded in the 6 role evaluations, all of which completed.

## Overall: 7.1 / 10

**Verdict on "without doubt replaces a human communications coach, 10/10":** No —
and by design Noum never self-certifies that claim. Two reasons, one structural
and one fixable:

- **STRUCTURAL (uncrossable in code).** `CoachParityReadiness` caps validation at
  `.forming` and `VISION.md` requires earned validation = repeated real-world
  outcomes + calibration against professional-coach judgment over time — data the
  app cannot generate from inside itself. This is a deliberate **trust feature**,
  not a defect. Forcing a 10/10 "replaces a coach" claim would violate the
  CLAUDE.md red lines and the product's core honesty contract.
- **FIXABLE-BUT-OPEN.** The coaching intelligence is substrate-grade (durable
  case file, transcript-verified quote guards, honest offline markers,
  evidence-scaled certainty — genuinely beating Speeko/Orai/Yoodli on trust
  substrate) but it stays **delivery-invisible at the exact retention moments
  adoption is decided.** The coach detects an emotional read and never shows it;
  rebuilds the case file and never restates it at the next call landing; computes
  the next prescribed move and never anchors it durably. A coach you can't see
  thinking does not feel like a coach.

Honest standing: **7.1/10 — the right architecture, the wrong visibility, and a
deliberately-uncrossable external-validation line.**

## Role scores

| Role | Score |
|------|-------|
| Market / competitive | 7.2 |
| Senior product / UX | 7.2 |
| Cold-start (nervous beginner, day 0) | 6.8 |
| Returning power user (30+ reps) | 6.8 |
| Veteran communications coach | 7.3 |
| QA / trust adversary | 7.5 |

## Did the coach-call redesign move the needle?

**Net wash-to-slightly-positive (7.1 vs prior 7.0).** It clearly HELPED on
mechanical trust: killing auto re-arm removed a real echo loop (the mic
transcribed the coach's own TTS as the user's next turn — `49b96e9`);
VOICE-DEDUP added a single-delivery latch against the timeout/engine-final race
(`8151151`); CHAT-HONESTY stopped mislabeling content-rejections as "Offline"
(`3214cfe`); CHAT-GATE stopped the quality gate killing legal live replies
(`3ee091a`). All six roles confirmed the gates and quote guards hold
post-redesign; the QA adversary found no fabrication path.

It HURT on two axes the goal cares about: (1) **push-to-talk** converts
conversation into structured turns — a human coach never makes you tap to
respond; three roles independently flagged this as making coaching feel
transactional. (2) it chose the immersive **call as the day-0 default**
(`CoachSessionView.initialMode = .live`), the wrong cold-start door for a nervous
beginner with no voice profile and possibly no mic permission.

Critically, the redesign changed the *medium* (chat→call) without surfacing the
*thinking* — so the headline blocker from the prior eval is untouched. The bug
fixes bought back exactly what the flow regressions cost. Necessary plumbing,
not the value unlock.

## Ranked, owner-local, red-line-safe build list

| # | Item | Effort | Δ | Status this session |
|---|------|--------|---|---------------------|
| 1 | Make the coach's emotional read **visible** (acknowledgment surfaced at the trust moment) | S | +0.3–0.4 | **SHIPPED (frame-instruction path) 2026-06-15** — `liveCoachingFrameLines` now appends a mandatory-open instruction when the read is **strong AND sustained** (same signal strong this turn + sustained across the arc). Words stay model-generated (passes the quality gate, no double-naming, no clinical labels). Pure + 3 tests. ⚠️ Remaining felt-QA on the *spoken* open quality is still owed before calling it fully closed — see note below. |
| 4 | **Confidence-grade** emotional detection (kill false positives) | M | +0.2 | **SHIPPED** this session — incidental-context guard + self-correction downgrade + confidence-weighted arc. Unit-tested. The upstream quality fix that makes #1 safe to ship. |
| 3 | Gate the **day-0 default** on voice availability; chat as the cold-start door | S | +0.2 | **SHIPPED** this session — `CoachSessionView.resolvedInitialMode`, pure + unit-tested. |
| 2 | Persist the next prescribed intervention in `CoachMemory`; surface as a durable call-landing anchor | M | +0.2–0.3 | **SHIPPED 2026-06-16** (`16151f9` — `COACH-ANCHOR`). `CoachCaseFile.callLandingAnchor` (pure, +6 tests) names the standing intervention + target as a continuity line ("Picking up where we left off: …"), phrasing tracking `nextMove` (review-due / adapt read as the real move). Wired top-priority into `LiveCoachCallView.coachingFocusLine`: landing leads with the *plan*, the *read* stays in the spoken open (Rank 1). Nil on cold start → no fabrication. Owner-local; regressions green. |
| 5 | Emotional-read acknowledgment **chips** (user confirms/rejects the read) | M | +0.2 | Spec'd. Depends on #1 + #4 landing first. Reuses `CoachHypothesisConfidence`. |

### Shipped this session (compiled + unit-tested, isolated DerivedData)

- **#3 — day-0 door.** `CoachSessionView.resolvedInitialMode(requested:voiceAccessible:hasCompletedReps:hasVoiceProfile:)`
  routes a `.live` request to the typed chat when voice isn't actually accessible
  (speech auth + mic record permission) or it's a true cold start (no rep AND no
  chosen voice). `.askNoumTyped` (explicit `.type`) is always honored. The live
  call already shows a permanent "Type" control, so no one is stranded — this
  fixes the *routing*, the real gap. 4 tests.
- **#4 — confidence-graded emotional read** in `CoachContextBuilder`:
  - `isIncidentalStuck` drops a bare "stuck" in a physical context ("stuck in
    traffic") so it never reads as coaching frustration;
  - `gradedSignals` downgrades a turn to *tentative* when it self-corrects
    ("…but I'm managing now") or lacks first-person emotional framing;
  - the LIVE COACHING FRAME now carries a confidence qualifier ("clear in this
    turn" vs "weak signal — treat as tentative, do not lead hard with it");
  - `detectArcPattern` is confidence-WEIGHTED and requires ≥1 unambiguous turn,
    so four tentative mentions never sustain a confident pattern claim while two
    strong ones do. 4 tests. Directly serves the CLAUDE.md invariants *weak
    evidence → softer feedback* and *avoid fake certainty from small samples*.

## Genuine limitations — the honest answer to 10/10

No code change closes these:

- **External-validation ceiling (uncrossable).** Earned parity needs real-world
  outcomes + professional-coach calibration over time. Not derivable in-app;
  `CoachParityReadiness` is built to refuse the claim.
- **Perception ceiling.** A human reads pace, silence, breath, micro-expression,
  and what-didn't-get-said simultaneously. Noum reads text/transcript lexemes
  only. Confidence-grading narrows false positives but cannot reach multi-channel
  human perception — the upstream signal is fundamentally thinner.
- **No closed real-world follow-up loop.** `BigMomentStore` captures the upcoming
  moment, but there's no structured post-event check-in ("how did Thursday's
  interview go?"); the coach can report a self-reported outcome, never
  demonstrate it changed one.
- **Push-to-talk is not conversational parity.** Even with a visible Type
  affordance, the call requires a tap between turns. True ambient listening
  (end-of-turn detection + echo-trim) is an audio-architecture investment — NOT
  owner-local and out of scope for this roadmap.
- **Single coach register.** One measured-professional tone across all users;
  tuning content to a style goal isn't the same as reading warm vs direct.
  Expanding tone treads near fake-intimacy, so it's left off the red-line-safe list.
- **Conservative quality gate trades coverage for honesty.** The dual quote-guard
  + repair-or-fallback chain sometimes yields "I came up empty" where a human
  would improvise. Correct honesty posture; a genuine depth ceiling no safe
  change fully removes (loosening it risks fabrication).

## Competitor read

On trust substrate Noum already beats all four: durable `CoachCaseFile` memory,
dual transcript-verified quote guards (no competitor verifies a cited quote was
actually spoken), honest offline/quality-rejection distinction, and
evidence-scaled certainty that says "still building the picture" on day 1 instead
of a fake "90% match." Where competitors lead and Noum must close the *felt* gap:
(1) Duolingo/Yoodli/Speeko show a visible multi-week arc within the first two
interactions; (2) Yoodli/Duolingo anchor everything to a stated real-world moment
up front; (3) all four use continuous-listening conversation — Noum's
push-to-talk reads as transactional; (4) Yoodli/Duolingo show the coach's
confidence ("common pattern" vs "noticed once") — Noum scales certainty
internally but never shows it. Net: **Noum is the honest-depth leader with a
visibility deficit.** Competitors win the first 90 seconds and conversational
ease; Noum wins everything after trust is earned — but adoption is decided in
those first 90 seconds. The roadmap closes the visibility gaps without adopting
the competitors' overclaiming.
