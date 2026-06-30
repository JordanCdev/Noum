# Coach-Parity Eval — 2026-06-30 (autonomous `noum2` run, 18th iteration)

Branch: `ux-overhaul`. Commit: `254a1f1f`. No push.
Method: 5-role panel (market · UX · end-user · veteran-coach · staff-eng/QA) →
adversarial verify-against-code → lead synthesis. Build+tests GREEN on
iPhone 17 / iOS 26 sim, isolated DerivedData (`RepTimelineCardTests` 6/6,
`RepEventLocationsEngineTests` + `TranscriptTimelineTests` rebuilt clean).

## What shipped — the positional-read RENDER (`RepTimelineCard`)

The one collision-safe, ship-now lever 17 priors named but always deferred:
the **visible** companion to `RepEventLocations`. The positional read ("you
rushed at the close") was computed + persisted + fed to the coach prompt
(`CoachContextBuilder:1243`) but **never shown to the user**. This is the first
stone of the annotated-analytics surface Speeko/Yoodli are known for — rendered
in Noum's calm card language, not a dense dashboard.

- `Noum/RepTimelineCard.swift` — renders the persisted `RepEventLocations` as
  three honest thirds (opening/middle/close). **Never finer than the model
  carries** (no fake per-word scrubber). Markers reuse existing tokens
  (silence=`brandBlue`, pace=`caution`, fillers=`textSecondary`); **zero new
  color or pace/pause thresholds**. Motion-free → reduced-motion safe by
  construction. One-sentence VoiceOver label.
- **Honesty invariant (load-bearing):** `RepTimelineCopy.summaryLine` reuses the
  engine's own `readout` verbatim, so the visible card **can never assert a
  finding the coach prompt didn't.** Self-hides on a non-finding (engine → nil).
- `SummaryView` wires it with the same `if let` self-hide pattern as the sibling
  speech-quality cards, between Pitch and WordChoice.
- `RepTimelineCardTests` (6) lock the engine→visible-text contract, incl. an
  end-to-end `TranscriptTimeline → derive → copy` case so the render and the
  coach's positional block can't drift.

**Collision discipline:** a concurrent session was actively running 3 xcodebuild
test passes on the coach-chat surface (`AICoachChatService` / `CoachReasoningPass`
/ `CoachReliabilityGate` + tests, 535 uncommitted lines) THROUGHOUT this run.
Built in isolated DerivedData on a different sim; committed only the 2 new files
+ the one disjoint `SummaryView` compose site via explicit pathspecs. Their diff
is preserved byte-for-byte.

## Honest scorecard — **7.5 / 10** (held; → ~7.7 once counted as shipped)

| Axis | Score | Basis (verified against code) |
|---|---|---|
| Perception / signal depth | 6.5 | Real per-word timings → positional zones, but still words-only; no breath/tension/face. |
| Judgement quality | 7.0 | Substring/threshold heuristics; the `"what i meant"` false-positive fix is real but exposes the proxy ceiling. |
| Trust calibration | 9.0 | `CoachParityReadiness` caps validation at `.forming`, never `.earned` — structural moat. Best axis. |
| Reliability / safety | 8.0 | `noAttunementOnPushback` HARD block + `missingIntentFit` gate confirmed. |
| Insight visibility (UX) | 6.0 → ~7.5 | **The closed gap.** App computed + spoke the positional read; user couldn't see it. This render closes it. |
| Longitudinal proof | 4.0 | No real-user outcome data. Unmoved, human-gated. |

The score holds at 7.5 in this doc because the render is now committed but the
whole-app re-score belongs to a quiet-tree run; the realistic post-land position
is ~7.7, driven entirely by Insight-visibility. The render surfaces existing
intelligence — it adds no new judgement, so it cannot move the number further.

## Competitive delta

- **Speeko** — Noum *leads* on coaching trust/restraint + a single coherent coach
  voice; *matches* on filler/pace metrics; *lags* slightly on onboarding polish.
- **Orai** — *matches now* on positional annotation once this render lands
  (Noum's zone-thirds are honest-blunter, not per-word-fake); *leads* on not
  over-claiming.
- **Yoodli** — *lags* on breadth (video/meeting analysis, real-time on-call);
  *leads* on calm coherence + refusal to fake certainty.
- **Duolingo** — *leads* on depth + adult/professional credibility; *lags hard*
  on the streak/retention dopamine loop + longitudinal habit proof.

## Honest limitations ledger — to a literal 10/10

| Gap | Class | What would actually close it |
|---|---|---|
| Phone reads words, not breath/tension/micro-expression | **[hardware]** | On-device camera + mic analysis of facial tension, breath cadence, vocal tremor — a perception layer the text pipeline structurally cannot add. |
| Scoring is keyword/threshold proxy, not understanding | **[external-calibration]** | A labeled corpus scored by credentialed coaches to calibrate thresholds vs human judgement; the `"what i meant"` false positive is the proxy ceiling showing. |
| No longitudinal real-user outcome proof | **[longitudinal]** | A cohort study: did users who followed Noum's advice measurably improve a real interview/pitch over weeks/months? Outside code entirely. |
| Insight computed but invisible to the user | **[closable-in-software]** | **This render.** Closed this run. |

The literal "10/10, with no doubt replaces a human coach" stays **refused by
design** via the `.forming` cap. That is the correct call and the product's trust
moat — keep it. The top three gaps are genuinely human-gated; do not chase them
with code.

## Ranked roadmap — next 3 collision-safe levers (after the render)

1. **Per-zone marker felt-QA + density polish** — render on a real device against
   varied reps; confirm 3 markers in one zone don't overflow the 48pt column and
   reduced-motion truly has zero implicit animation. Pure UI, SummaryView-local.
2. **Positional read → trend memory** — persist the dominant zone of recurring
   weakness ("you've rushed the close 4 of your last 5 reps") into
   `CoachContextBuilder`'s trend block (`:1335`). Reuses the persisted substrate;
   touches context-building, not the live chat gate — schedulable around the
   coach-chat session by staging only `CoachContextBuilder.swift` + a new file.
3. **Empty-state / first-rep honesty pass on SummaryView** — verify what the
   rep-review surface shows when *no* speech-quality card qualifies (all
   self-hidden); confirm the disclosure collapses gracefully, not a hollow shell.

All three avoid `AICoachChatService` / `CoachReliabilityGate` / `CoachReasoningPass`.

## Bottom line

Iteration 18 shipped the strongest collision-safe competitive-substance lever
the prior 17 deferred, GREEN and honest, without dragging the concurrent
coach-chat diff along. The 10/10 answer is unchanged and unchanged-by-design;
what moved is that Noum's positional intelligence is now *visible*, closing the
one purely-software gap on the ledger.
