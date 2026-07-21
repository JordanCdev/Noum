# Product journey gap audit

Audit date: 2026-07-20
Baseline branch: `ux-overhaul`
Baseline commit: `7b8552d79dbea5301e5f804f2bcc84530180a35a`
Current behavior source: `cdce32af90f64295fb2ce4bfd5ef905d4194f4c7`

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
- Path: simplified to one legible corridor and waypoint with shorter section
  copy; prior progress ownership remains unchanged.
- Train: the existing recommendation is now the primary plan, while the full
  exercise library remains available behind an explicit free-select disclosure.
- Coaching evidence: current focus/next move lead; supporting rationale and
  records use progressive disclosure.
- Weekly check-in: replaced popup-style top controls with the existing pushed
  navigation pattern and one coaching-memory save action.
- Progress: Summary, Home, and Lessons use one inline receipt language; obsolete
  personal-best, level-up, achievement, path, and progression overlays were
  removed rather than retained as dormant alternate flows.
- Settings → Developer: added a recent redacted trace viewer, trace-ID copy
  action, and content-free support-bundle export that joins trace stages with
  matching provider diagnostics and a fail-closed terminal-path replay command.
- Settings → Your Data: added coaching-memory inspection, correction, projection deletion, and full bounded-memory deletion.

No screen or tab was added. No existing state owner was duplicated. The visual
changes reinforce the same coaching case, recommendation, path, reflection, and
progress owners rather than introducing parallel state or navigation.

## Remaining product gaps

- A retry still flows through the existing phrase-practice and Summary owners; a fresh real-speech run must prove the same target survives that complete route and updates the intervention as intended.
- Long-request local contracts are now explicit rather than inferred: a 3,000-character user turn survives acceptance and account-scoped reload exactly, cancellation wins promptly even when the provider ignores cancellation, and a delayed accepted request reaches one stable terminal UI state across simulator background/foreground. A current-source live-provider lifecycle run on a physical device remains required before this becomes production evidence.
- Memory exposes the bounded case projection and its overall update date/confidence, not an independently timestamped UI row for every underlying evidence record. The model does not currently persist that granularity, so the UI does not fabricate it.
- The Debug viewer is deliberately content-free. It now makes duplicate or
  malformed request terminals visible as `trace error` and exports a versioned
  support bundle that the checked-in Coach Arena replayer validates. This
  reproduces stage ordering, provider attempts, gates, persistence, UI commit,
  and terminal status without exporting user content. Exact semantic replay is
  intentionally unavailable; a consented synthetic fixture is required to
  reproduce answer quality without weakening the privacy boundary.
- Largest-Dynamic-Type inspection found and fixed the two compressed Settings picker rows. The complete ladder, retry, memory, weekly check-in, Big Moment, and tab-root accessibility matrix still needs interactive VoiceOver, Reduce Motion, error/offline, and physical-device coverage. The root app currently forces `.preferredColorScheme(.light)`, so dark mode is a deliberate open product/implementation decision rather than a passed appearance check.
- External live-provider, professional-coach, longitudinal-user, physical-TestFlight, and launch-operations evidence remain missing. Local scores cannot close those gates.

## Launch verdict

This branch is not proof of production or TestFlight readiness. At behavior
source `cdce32af9` and coach-source fingerprint
`sha256:e1c6b655edaee8759e791ed6669a567117a17a283ef283680c3278c01e49cbad`,
the final canonical local refresh passed 53 conversations / 109 app-path turns,
50/50 scored replies (81.16 average), 50 complete real-pipeline terminal traces,
source freshness, and 22/22 static operational checks. The Swift readiness
manifest and independent Python audit agree at 20/100. The fresh light sweep
produced five nonblank tab roots plus one expanded Debug trace/export state,
all at 1206×2622 and visually inspected. No dependency or Firebase Analytics
was added.

The source-bound launch evaluator remains **NO-GO at 20/100 (20-point cap)**.
It correctly reports five external blockers: no current-source live-provider
transcript sweep, no professional-coach calibration, no real-user longitudinal
transfer outcomes, no physical TestFlight verification, and an incomplete
operational launch checklist. Same-target real-speech retry, interactive
VoiceOver and Reduce Motion inspection, the remaining accessibility extremes,
app-wide dark-mode support, signed archive/upload, and those five external
evidence artifacts remain required. The fresh serialized unit target is fully
green at **4,549/4,549 passed, 0 failed, 0 skipped** in
`/private/tmp/noum-vision-full-unit-final-pass2.xcresult`; the complete
serialized UI target is green at **79/79 passed, 0 failed, 0 skipped** in
`/private/tmp/noum-vision-full-ui-final-pass2.xcresult`; and the transcript
retry corpus is 20/20. Local scores and simulator screenshots do not close the
external boundary.
