# Coach-parity eval — 2026-07-06 (autonomous `noum-1` run, iter-23)

Branch: `ux-overhaul`. HEAD includes parity Wave-1 initiatives 1–3
(`5e1a6052`, `c6a0320f`, `5610cf05`). Method: read-only 5-role evaluation
(market/competitor · UX designer · cold end-user · veteran coach · staff-eng/QA)
→ adversarial verification of every proposed gap → single synthesis.
14 agents, ~929k subagent tokens. **No app code changed this run** (see "Why" below).

## Headline

Wave-1 earned a real, honest **+0.2 → ~7.6/10**. The pace-on-pace prescription and the
one-tap reflection intake are disciplined coaching upgrades, not theatre. But the two
things between Noum and a **strong human coach** are untouched and both structurally
gated: it still coaches **HOW you speak, never WHAT you said** (the content engine reads
argument *shape* from the presence of connective words like "because"), and **live
roleplay is environment-blocked** with no `ANTHROPIC_API_KEY`. The only collision-safe,
high-value work available this run was docs/design — done.

## Score: 7.6 / 10 (vs a strong human communication coach)

Prior runs held ~7.4. The +0.2 is credited to Wave-1 and verified against code:

- **Pace-on-pace prescription** (`5e1a6052` + `c6a0320f`): judges a pacing bar on the
  user's own words-per-minute against the healthy-band edge, not the composite score, and
  only fires when the user's average sits *outside* the band, with a byte-exact fallback
  below the evidence floor. Genuine upgrade. **9 targeted pace tests pass**
  (`ScoreCalibrationTests`, re-run green this session).
- **One-tap post-rep reflection intake** (`5610cf05`): closes the last production-dead
  writer feeding the subjective dimension of the case file. Model + context are tested
  (`SessionReflectionTests`, re-run green — round-trip, coach-clause, bounds, account-key
  isolation). The *view* (`ReflectionCaptureRow.swift`) ships without a view test — the
  only definition-of-done brush this run found.

The score does **not** move higher because the two biggest substance ceilings are
structurally unchanged (see limitations).

## Scorecard (axis · score · strongest rival)

| Axis | Score | Best rival | Note |
|---|---|---|---|
| Coaching honesty / restraint | **9** | none in category | Evidence floors everywhere; association-not-causation; `.forming` cap. The moat. Do not touch. |
| Diagnosis / case formulation / durable memory | **8** | none (rivals hold no durable case) | `PrimaryFocusMemory.selectLever` ladder, stated-challenge reconciliation, durable `CoachCaseFile`. Ceiling: diagnosis is over *patterns*, never idea substance. |
| Intervention specificity / adaptation | **8** | Speeko | Success criterion grounded in the user's own prior average; pace judged on WPM; reinforce/vary/replace biases mode selection. Gap: the *replace rationale* isn't yet spoken in prescription copy. |
| Visual quality / cohesion | **8** | Speeko | Single token source, 62 reduce-motion guards, one-shot reveals. Crack: ~26 hardcoded system colors where `AppColor` tokens exist (a CLAUDE.md ban). |
| Analytics presentation | **6** | Yoodli / Speeko | Market-leading positional insight *is* designed; `ProfileView` carries two real Swift Charts. Residual: hand-rolled Speech-Patterns bars (`:3020-3028`); signals not composed into one Rep Report; Summary deep-read is a text list. |
| First-run / acquisition | **6** | Orai / Speeko | Verbatim first-rep celebration is best-in-class trust, but the fastest path is dark: `AutoGuidedFirstRep.defaultEnabled=false` → first-timer hits picker + 15s countdown. |
| Daily-habit ritual | **6** | Speeko / Duolingo | Real daily loop feeds the streak. Residual: no sub-2-min unit *framed* as an ungraded warm-up. |
| Positioning / branded credibility | **5** | Speeko (Roger Love) | The honesty moat + 64-card knowledge base are real but invisible to a prospect. **Worst axis.** → `docs/POSITIONING.md` (shipped this run). |
| Content / substance diagnosis (WHAT was said) | **4** | Yoodli (LLM sees full transcript) | Only content engine is lexical/positional; a fluent-but-unsound answer scores a complete argument. Needs a model + reversing the no-transcript invariant. Environment-blocked + a Jordan design call. |
| Live interactive practice / roleplay | **3** | Yoodli / Duolingo (Lily/Falstaff) | IM mode is a scored tone-drill, not a free multi-turn counterpart, and depends on a live model that is env-blocked here. Widest categorical trail. |

## Genuine limitations blocking a literal 10/10

- **[by-design]** "Replaces a human coach" is **refused** — `CoachParityReadiness` capped
  at `.forming`, the trust moat VISION.md mandates. Correct; must not be removed or
  papered over with overclaiming copy. **A literal "with no doubt replaces a human coach"
  10/10 is refused by design.**
- **[by-design]** Coaching never judges the substance/soundness of the user's *ideas*,
  only communication patterns. `CoachContextBuilder` deliberately withholds the raw
  transcript from the model ("Don't dump raw transcripts"). Reversing this is a Jordan
  design decision, not a defect.
- **[environment]** Live conversational partner / free roleplay is blocked with no
  `ANTHROPIC_API_KEY`. The roleplay frontier (Yoodli panels, Duolingo Lily/Falstaff)
  cannot be exercised or advanced this run.
- **[environment]** Honest content critique of WHAT was said requires a live model reply
  AND the no-transcript invariant reversal — doubly gated right now.
- **[external-data]** A durable "recurring message" memory (the actual pitch/story the
  user keeps rehearsing) needs semantic transcript reading; no keyless lever can add it
  without fabricating a content read.
- **[hardware]** The fused delivery read is baseline-relative vocal/marker fusion only; it
  cannot sense warmth, over-rehearsal, or absolute prosody given phone-audio limits.
- **[longitudinal]** Several coaching acts (grounded success criterion, confident replace,
  fused delivery read) only activate after 3–6 reps by design; a cold user sees the
  generic fallback — honest, but depth is earned over time, not on day 1.

## Ranked levers (all keyless; collision + lane honest)

| # | Lever | Lane | Collision | Status |
|---|---|---|---|---|
| 1 | Positioning stance (`docs/POSITIONING.md`) — category one-liner + first-run "why different" beat + truthful credibility line | docs | none | **DONE this run** |
| 2 | Finalize Rep Report as 2-variant Figma review + correct spec's overbroad framing | docs/Figma | none | **Variant A done; spec corrected; Variant B blocked by Figma rate limit** |
| 3 | Credibility subline sourced from the shipped knowledge base (no named coach) | docs | low | Folded into `docs/POSITIONING.md` |
| 4 | Pre-rep framing bridge on the REAL first-run path (no countdown), NOT flipping `AutoGuidedFirstRep` | Swift routing | **high** | Spec-only; `ContentView` is a hot contended router — land when Swift lane is free |
| 5 | Argument-logic COPY fix: "you signalled a reason" not "you made a point and backed it" | Swift copy | **high** | Queue for Jordan; `PracticeSupport.swift` is active Wave-1 territory |
| 6 | Ungraded <2-min warm-up entry point (new `MiniDrillType`, inherits streak credit) | Swift new-file | **high** | Doc-only; new-file + `project.pbxproj` change must serialize after Wave-1 |

## Why no app code changed this run

A concurrent `fable-5 --ultracode` agent is **actively** shipping the Swift parity-Wave
initiatives (its commits landed hours before this run). Every code-bearing lever above is
either **high-collision** (edits a contended Swift file, or adds a new file → churns the
`project.pbxproj` the concurrent agent is committing to) or **environment-gated** (needs
the API key). The disciplined move — consistent with the repo's concurrency protocol — was
to work strictly in the **docs + Figma** lane (touches none of `PracticeSupport.swift`,
`PrimaryFocusMemory.swift`, `ReflectionCaptureRow.swift`, `SummaryView.swift`,
`NoumTests.swift`, or `project.pbxproj`) and hand the code-bearing decisions to Jordan.

## Verification this run

- `xcodebuild build-for-testing` (isolated `DerivedData/Noum-verify`, iPhone 17 Pro / iOS
  26): **TEST BUILD SUCCEEDED** — the tree incl. Wave-1 compiles clean.
- `xcodebuild test-without-building -only-testing:NoumTests/ScoreCalibrationTests
  -only-testing:NoumTests/SessionReflectionTests`: **all passed** (every pace test +
  reflection round-trip/coach-clause/bounds/account-key isolation).
- Code facts behind the scorecard spot-checked against source
  (`ProfileView.swift:1710/2054/3020-3028`, `CoachContextBuilder` no-transcript guard).
- Figma auth confirmed live (`whoami` → Jordan's team, Starter tier). Variant A
  screenshot-verified premium; Starter-plan MCP call limit then reached.

## Connectors

- **Figma**: authenticated (Jordan's team). Usable but **Starter-tier MCP call limit is a
  real ceiling** — a single 2-variant screen build exhausted it. A paid Figma tier (or
  spreading builds across sessions) is needed for larger design work.
- **Canva**: authenticated per prior runs; wrong tool for a product surface (marketing
  collateral only). No new need.
- **No new connector needed.** The one thing that would unblock the top *product* levers
  is not a connector — it is an `ANTHROPIC_API_KEY` in the run environment.
