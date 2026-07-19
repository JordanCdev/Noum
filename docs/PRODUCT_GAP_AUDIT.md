# Product journey gap audit

Audit date: 2026-07-19
Baseline branch: `ux-overhaul`
Baseline commit: `2bcb1ccff769d1eba71da9049e4fa82fbf1d4bb2`

## Product goal

Make the existing coaching system read as one credible loop:

`UNDERSTAND → DIAGNOSE → SHOW → PRACTISE → COMPARE → ADAPT → TRANSFER`

This work serves M14's production-quality/launch gate and primarily supports coaching trust, pressure-aware practice, believable progress, replay motivation, and product coherence.

## Baseline truth

Noum was not missing all of this architecture. Home already had a dominant next action, Ask Noum already accepted contextual entry points, Summary already owned diagnosis, the rewrite service already preserved meaning/voice, and `CoachMemoryStore`, `ForwardPlanStore`, `CoachingProfileStore`, `AskNoumStore`, `CoachReplyPipeline`, and `FlowEventLog` were established owners.

The product gap was connective tissue and trust under failure:

- a voice-goal change could be described as a change of identity and did not advance all memory/plan provenance consistently;
- long or detailed chat turns depended on provider/server ceilings and could lack a deterministic client terminal deadline;
- trace fragments existed, but one inspectable root journey did not span acceptance through UI commit;
- the rewrite was an intensity selector rather than a visibly explained learning ladder;
- bounded memory existed, but the user could not inspect, correct, or delete its projections with clear provenance;
- launch documentation contained stale statements after later security and coach-v2 work.

## Existing patterns preserved

- `CoachingProfileStore` remains the voice-goal identity and persistence owner.
- `CoachMemoryStore` remains the bounded case-memory owner; no raw-chat memory store was added.
- `ForwardPlanStore` remains the forward-plan/provenance owner.
- `AskNoumStore` remains the pending row, lease, retry, persistence, and UI-terminal owner.
- `CoachReplyPipeline` remains the single text/live coaching orchestration path.
- `CoachContextBuilder`, goal rubrics, professional/semantic/reliability gates, and provider chain remain authoritative.
- `FlowEventLog` remains the bounded, content-free, account-scoped debug event store.
- `AIRewriteService`, `PhraseBankStore`, and the existing phrase-to-Timed practice handoff are extended rather than duplicated.
- Existing SwiftUI tokens, cards, motion helpers, and accessibility conventions are reused.

## Root causes and fixes

### Voice goal

Root cause: several surfaces conflated the chosen style goal with personal identity, while memory reconciliation handled a goal mismatch by discarding the memory voice and the plan generator did not have an explicit goal-change invalidation entry point.

Fix: treat the choice as training emphasis; advance memory voice/goal provenance; preserve sessions, evidence, lever, strengths, blockers, hypotheses, and reflections; clear only goal-dependent plan projection; invalidate in-flight plan generation while retaining the old plan as history; block authenticity-shaming output in the reliability gate.

### Detailed prompts and long chat

Root cause: the app relied on provider/server timeouts and did not own a deterministic terminal deadline. Cancellation was sometimes categorized as network failure. Provider, gate, persistence, and render events were not grouped into one inspectable terminal request.

Fix: add client-owned text/live deadlines, typed timeout and cancellation failures, an exhaustive terminal-state mapping, durable retryable notices, safe fallback classification, and a single opaque trace ID carried by the pending row through orchestration, providers, gates, persistence, and UI commit. The deadline race returns without waiting for a provider that ignores cancellation.

The first fresh app-path refresh also exposed an evaluation-state defect: the
harness supplied fixture sessions but still read process-persisted singleton
baseline and rating state. A prior simulator run could therefore change a later
fixture's assessment and final reply. The DEBUG evidence path now replaces those
owners with state derived only from each fixture, invalidates dependent caches,
and restores the process state after the run. Two consecutive diagnostic runs
and the final canonical refresh then completed without cross-fixture drift.

### Transcript improvement

Root cause: the rewrite card exposed an abstract intensity choice. It did not explain the delta, distinguish an achievable next rung from an aspirational model, or hand the recommended rung directly into practice.

Fix: show the exact bounded original, a meaning-preserving one-step rewrite, an optional clearly secondary aspirational end state, word-level change emphasis, and a one-tap handoff of the one-step version through the existing phrase-bank/timed-practice route.

### Memory trust

Root cause: memory was bounded and evidence-aware but operationally opaque to the user. Clearing everything was possible, while correcting the user-stated goal or removing a coach hypothesis/reflection projection was not.

Fix: add inspect/edit/delete controls to Your Data. User-authored goal, observed evidence, coach hypothesis, and carried reflection are labelled separately. Projection edits preserve observed evidence. Sensitive hypotheses remain removable/confirmable coach interpretations.

## Journey before and after

| Stage | Before | After this branch | Proof still required |
| --- | --- | --- | --- |
| Understand | Profile, prior reps, and case memory existed but provenance was not visible in one request | Goal, evidence/memory availability, rubric, prompt modules, and trace ID are joined in a redacted trace | Current-source live provider and real-user validation |
| Diagnose | Summary/Ask diagnosis existed | Existing diagnosis remains primary; goal changes cannot erase its evidence | Broader long-chat and post-rep regression sweep |
| Show | One rewrite with intensity controls | Exact original → one-step upgrade → labelled aspirational end state, with explained word changes | Visual QA at accessibility extremes |
| Practise | Modes and phrase handoff existed | The one-step rewrite has a direct targeted-practice CTA using existing ownership | Same-target retry on device with real speech |
| Compare | Summary and prior-rep comparison existed | Targeted practice returns to the established Summary/intervention path | Explicit end-to-end retry artifact evidence |
| Adapt | Memory and plan stores existed | Goal changes preserve evidence and invalidate only goal-dependent projection; memory projections are user-correctable | Longitudinal transfer evidence |
| Transfer | Progress/case narrative and upcoming-moment context existed | Context and bounded memory remain available to Ask/Home/plan owners | Closed-beta delayed real-world outcomes |

## Screens changed

- Review/Summary rewrite card: redesigned into the transcript ladder; no new tab or duplicate review screen.
- Ask Noum: goal-confirmation language reframed as training emphasis; existing contextual entry architecture retained.
- Settings → Developer: added a recent redacted trace viewer and trace-ID copy action.
- Settings → Your Data: added coaching-memory inspection, correction, projection deletion, and full bounded-memory deletion.

No screen or tab was added. No existing state owner was duplicated. Home, Practice, and Progress already contained the intended hierarchy on this baseline, so this phase did not perform cosmetic rewrites solely to satisfy the specification wording.

## Remaining product gaps

- A retry still flows through the existing phrase-practice and Summary owners; a fresh real-speech run must prove the same target survives that complete route and updates the intervention as intended.
- Memory exposes the bounded case projection and its overall update date/confidence, not an independently timestamped UI row for every underlying evidence record. The model does not currently persist that granularity, so the UI does not fabricate it.
- The Debug viewer is deliberately content-free. Safe local reproduction/export of a failed request remains with Coach Arena and existing redacted log export; there is no production prompt/reply replay button.
- External live-provider, professional-coach, longitudinal-user, physical-TestFlight, and launch-operations evidence remain missing. Local scores cannot close those gates.

## Launch verdict

This branch is not proof of production or TestFlight readiness. At source commit
`6712ee74d` and coach-source fingerprint
`sha256:d5efd3bebbb7e5aefb20db1ea67a7986191dad6cb9b3d8ded0ffb5424468c2c6`,
the final canonical local refresh passed 109/109 app-path turns, 50/50 scored
replies (81.16 average), all terminal-trace checks, and the 90-point local target
shape. The current Release simulator build succeeds; the three selected journey
UI regressions pass; and the five-tab seeded plus cold-profile recovery light
sweeps produced ten nonblank 1206×2622 captures. No dependency was added.

The source-bound launch evaluator remains **NO-GO at 18/100 (20-point cap)**.
It correctly reports five external blockers: no current-source live-provider
transcript sweep, no professional-coach calibration, no real-user longitudinal
transfer outcomes, no physical TestFlight verification, and an incomplete
operational launch checklist. Accessibility extremes, same-target real-speech
retry, signed archive/upload, and those five external evidence artifacts remain
required. The fresh broad unit run is also not fully green: 4,502 passed and 33
failed across 4,535 tests. Those failures cluster in legacy coach-fixture/
typed-fallback expectations and one source-text ordering assertion; focused
journey/reliability tests and the canonical app path pass. Local scores and
simulator screenshots do not close either boundary.
