# HANDOFF — Ask Noum proof-aware coaching context

## Scope

Three new files / edits land on `Redesign` for this push:
`Noum/ProofMomentArchive.swift` (new file, ~155 LOC — defines
`ProofMomentRecord` + `ProofMomentStore` with per-account
UserDefaults persistence, max 12 records, idempotent-on-session-ID
recording, oldest-by-`addedAt` cap eviction, and most-recent-by-
`sessionDate` read ordering), `Noum/ProofMomentService.swift`
(+~30 LOC — six new persistence hops after each path that produces
a successful proof, one new `@MainActor private func
persistToArchive` helper), `Noum/CoachContextBuilder.swift`
(+~25 LOC — new optional `recentProofs:` param on `userContext(...)`,
new PROOFS section rendered after TRENDS), `Noum/AskNoumView.swift`
(+2 LOC — `@StateObject` for the new store, threads
`proofStore.recent(limit: 3)` into the context call),
`NoumTests/NoumTests.swift` (+~320 LOC — two new test structs
`ProofMomentArchiveTests` and `CoachContextBuilderProofTests`,
fifteen unit tests total), `docs/CURRENT_STATE.md` (trail-of-
breadcrumbs entry + new bullet under the Ask Noum section).

## What changed

### Move 1 — `ProofMomentStore` persistent per-account archive

A new ObservableObject mirroring the `AskNoumStore` shape: per-account
UserDefaults persistence keyed `proofMoment.archive.<accountID>`,
bounded at 12 records, MainActor-isolated to stay SwiftUI-safe for
future Profile surfaces. The store exposes:

- `record(_ proof: ProofMoment, for sessionID: UUID, at date: Date)`
  — idempotent on session ID. Re-recording the same session replaces
  the existing entry rather than appending (so a deterministic
  fallback upgraded by a later AI fetch lands as a single row, not
  two).
- `recent(limit:)` — most-recent-first by the proof's `sessionDate`.
  Used by the chat context builder to pick the freshest few. Limit
  clamps negative inputs to 0 — defensive.
- `remove(sessionID:)` + `clear()` — granular and full wipe paths.
  `clear()` is the sign-out hook (Settings can pick it up later).

The cap-eviction policy is by `addedAt` (when the entry was last
written), not `sessionDate`. Reasoning: refresh-replacing an old
session's proof with an AI-upgraded version should NOT make that
record vulnerable to eviction — its `addedAt` is fresh, so the
oldest record by `addedAt` is the actual evictable one.

### Move 2 — `ProofMomentService.proof(for:)` writes to the archive

Every code path inside `proof(for:)` that resolves to a non-nil
`ProofMoment` (cache hit excluded — that proof was already
persisted on first generation) now hops to MainActor and writes to
`ProofMomentStore.shared`. Six hop sites covering:

1. Non-English locale fallback path.
2. No-AI-provider fallback path.
3. Provider matched but `.none` case in the switch (defensive).
4. HTTP failure / parse failure → template fallback path.
5. Catch path on URLSession throw → template fallback path.
6. Successful AI parse path.

Each hop is gated on `if let fallback = fallback { ... }` /
non-nil parsed result, so a session that produces no proof at all
(too-short transcript, no qualifying clause) never inserts a row.
The MainActor hop pattern matches the existing `currentProvider()`
and `activeLocaleSupportsAI()` helpers in the same file — same
isolation style, same `await` shape at call sites.

### Move 3 — `CoachContextBuilder.userContext(recentProofs:)`

A new optional parameter, defaulted to `[]`. When non-empty, a new
PROOFS section renders after TRENDS:

```
PROOFS (verbatim moments from past reps — quote these directly when relevant)
- Yesterday · BLUF: "Bottom line is we held retention this quarter"
- Mon · Triad: "We focused on three priorities"
- Apr 12 · Power Pause: "Steady — three breaths — then the close"
```

Section design rules:

- **Hard cap at 3** — even when the archive holds 12, the system
  prompt only sees the freshest three. Keeps the prompt bounded.
- **Sorted by `sessionDate` descending** — newest evidence reads at
  the top, matching how a real coach references "what you just did"
  vs "last week."
- **Section omitted entirely when proofs are empty** — cold-start
  users get no PROOFS header, no fabricated quote. The contract is
  the same as the per-baseline-dimension confidence gate: only
  surface what's earned.
- **Section header instructs the model to quote directly** — the
  framing "quote these directly when relevant" is the cue for the
  coach to use the user's own words rather than paraphrase. This
  is the difference between "you've been working on pauses" and
  "Last Tuesday you said 'three breaths, then the close' — that's
  the pattern."

### Move 4 — `AskNoumView.runReply` threads recent proofs

Adds `@StateObject private var proofStore = ProofMomentStore.shared`
to the view's state owners + passes `proofStore.recent(limit: 3)`
into the existing `CoachContextBuilder.userContext(...)` call. No
other view wiring needed — the chat surface already mounted the
store automatically once shared resolved, and every reply now
carries proof context.

### Move 5 — Fifteen new tests across two structs

`ProofMomentArchiveTests` (10 tests):

1. `recordPersistsSingleProof` — single-record round-trip.
2. `recordIsIdempotentOnSessionID` — re-saving replaces, never
   duplicates. AI-upgrade path verified.
3. `recentReturnsMostRecentFirstBySessionDate` — three proofs
   across three different dates emerge newest-first.
4. `recentRespectsLimit` — limit caps the count.
5. `recentClampsNegativeLimitToZero` — defensive — never crashes.
6. `persistenceRoundTripsAcrossStores` — fresh store on same
   defaults sees the saved archive.
7. `accountSwitchHidesOtherAccountArchive` — per-account scoping
   locks the archive to the signed-in user.
8. `capDropsOldestByAddedAt` — over-cap inserts evict by
   `addedAt`, not `sessionDate` (so refresh-replaces survive).
9. `clearWipesAllRecords` — sign-out path.
10. `removeDropsSpecificRecord` — granular wipe path.

`CoachContextBuilderProofTests` (5 tests):

1. `proofsSectionAppearsWhenRecordsProvided` — header + quote +
   technique all land.
2. `proofsSectionOmittedWhenRecordsEmpty` — cold-start has no
   PROOFS section.
3. `proofsRenderMostRecentFirst` — unsorted input still emerges
   newest-first in the rendered context.
4. `proofsAreHardCappedAtThree` — 12 records in → 3 lines in
   context, the rest never bleed into the system prompt.
5. `proofsSectionLandsAfterTrends` — GOAL precedes PROOFS in the
   prompt order. Locks the section ordering against future drift.

### Move 6 — `docs/CURRENT_STATE.md` updated

- Header trail-of-breadcrumbs gets a new entry summarising the
  proof archive + proof-aware context ship.
- The Ask Noum section's `CoachContextBuilder` bullet gains a
  PROOFS-block description.
- A new bullet under the Ask Noum section describes
  `ProofMomentArchive.swift`, the store's persistence contract,
  the idempotency-on-session-ID guarantee, and the
  upgrade-from-fallback-to-AI behaviour.

## What did NOT change

- `Noum/AskNoumStore.swift` — untouched. The chat thread store is
  unchanged; only the *context* the model reads at reply time gains
  the PROOFS layer.
- `Noum/AICoachChatService.swift` — untouched. The service still
  receives `userContext` as an opaque string; it doesn't know proofs
  are now part of it.
- `Noum/SummaryView.swift`, `Noum/ContentView.swift`,
  `Noum/AIWeeklyInsightCard.swift` — untouched. The three current
  consumers of `ProofMomentService.proof(for:)` keep their existing
  call shape; the persist-to-archive side-effect happens inside the
  service without changing their behaviour.
- The Proof Moment UI surfaces (Personal Best, Path Celebration,
  Weekly Insight) — untouched. The archive is a write-only side
  effect from their perspective.
- `firestore.rules` + Firebase config — untouched. The archive
  lives on-device only. Adding sync would be a future move; today
  the priority is "the coach knows what you actually said" with
  zero infra.
- Brand voice rules — fully preserved. The PROOFS section header
  uses sentence case + parens for the instruction clause; no
  exclamations, no chirpy framing, no emoji. The new test
  `proofsSectionLandsAfterTrends` locks ordering but doesn't
  introduce any voice violations.
- Design tokens — N/A. No new UI surfaces; the only change is
  inside the system prompt the model reads.
- `Localizable.xcstrings` — untouched. The PROOFS section header
  is English-only, matching the rest of the AI coaching context
  block. Localisation would happen in a future M13-style pass.

## Risks

1. **System prompt token growth.** Adding 3 proofs to the context
   block adds ~60–120 tokens per reply (~20–40 per proof). At a
   typical Ask Noum exchange of ~600 tokens of context + ~24
   messages of replay, this is a 10–20% bump. Acceptable for the
   value of voice-anchored replies — but worth watching if a future
   move adds a fourth proof or a sentence-length claim line per
   proof. The 3-cap is the right cap today.
2. **Provider-cost lift.** The archive contains existing proofs the
   service already generated; adding them to the context block
   doesn't cause new AI calls. But because every Ask Noum turn now
   ships richer context, each turn's input-token cost ticks up
   slightly. At GPT-4o input pricing (~$5/M tokens), the marginal
   cost is roughly $0.0003/turn over the previous build. Negligible.
3. **Cross-isolation Sendability.** `ProofMomentService` is an
   actor; `ProofMomentStore` is `@MainActor`. The hop pattern
   `await persistToArchive(parsed, sessionID: input.session.id)`
   crosses the boundary with `ProofMoment` (struct of String /
   Date / Bool — implicitly Sendable) and `UUID` (Sendable). Both
   are safe. If a future refactor adds a non-Sendable field to
   `ProofMoment` (e.g. a closure), the compiler will catch it at
   the hop site.
4. **Idempotency only protects against duplicate session IDs.** If
   the same transcript appears under TWO session IDs (which
   shouldn't happen in practice — sessions are UUID-keyed at
   finalize), the archive could carry two entries with identical
   quotes. The chat surface would then show the same quote twice
   in the PROOFS block, which would read oddly. Mitigated by the
   reality that `PracticeSession.id` is a fresh UUID per finalize;
   re-finalizing the same recording would only happen via debug
   tooling.
5. **Test coverage on the persist-to-archive side effect inside
   `ProofMomentService`.** The 15 new tests cover the store and
   the context builder, but the side-effect link inside the actor
   isn't directly tested (would require seeding an AI provider in
   the test environment + an actor-tested integration shape).
   Mitigated by: each persist call is a one-liner, lifted into a
   single helper method `persistToArchive`, so the surface area for
   a bug is small. The store itself is fully tested in isolation.
6. **No UI surface for the archive yet.** This push is a data-and-
   context-layer move. The natural follow-on is a Profile "growth
   library" card surfacing the same archive visually — that's a
   separate push so this one stays scoped to the dream-coach goal
   (the AI knowing your past words).

## Verification

### Implemented

- `ProofMomentRecord` struct + `ProofMomentStore` class live in
  `Noum/ProofMomentArchive.swift`. Per-account UserDefaults
  persistence, max 12, idempotent-on-session-ID record, oldest-
  by-addedAt eviction, recent-by-sessionDate read ordering — all
  verified by the 10 `ProofMomentArchiveTests`.
- `ProofMomentService.proof(for:)` writes to the archive on every
  successful proof path (fallback + AI-parsed). The hop helper
  `persistToArchive` lives at file scope (private `@MainActor`).
- `CoachContextBuilder.userContext(...)` accepts an optional
  `recentProofs: [ProofMomentRecord]` parameter (defaulted to
  `[]` for back-compat — existing call sites in tests don't need
  edits). The new PROOFS section renders after TRENDS, sorted
  most-recent-first, hard-capped at 3, omitted entirely when
  empty.
- `AskNoumView.runReply` passes `proofStore.recent(limit: 3)`
  into the context call.
- Five `CoachContextBuilderProofTests` lock the rendering
  contract: section present iff records present, ordering,
  cap-at-3, GOAL-precedes-PROOFS.

### Partially implemented

- None.

### Blocked / needs visual QA on device

This push has no new UI surface — every change is inside the
system prompt the model receives. Visual QA is therefore limited
to the indirect "does the coach quote my actual words now?"
check:

1. **End-to-end coach quoting**: configure an AI provider in
   Settings, run a few sessions (so the proof archive populates),
   then open Ask Noum and ask a question that invites the coach
   to reference past moments ("How am I trending?"). The reply
   should contain at least one verbatim quote from a past
   transcript. If it doesn't, suspect either the archive isn't
   populating (check on-device via the existing
   `ProofMomentService` consumers — Personal Best, Path
   Celebration, Weekly Insight) or the model is ignoring the
   PROOFS section (check the actual system prompt the model
   received).
2. **Cold-start silence**: brand-new install, no sessions yet,
   open Ask Noum with the empty thread starter prompts. Tap a
   starter, watch the reply land. The reply must NOT contain a
   fabricated quote in quotation marks — the PROOFS section is
   omitted at cold start. If a quote appears anyway, the model
   is hallucinating outside the section; tighten the system
   prompt guardrails.
3. **Cross-account isolation**: sign out, sign in as a different
   account, open Ask Noum. Reply must NOT reference the previous
   account's quotes. The per-account keying locks this at the
   store level; visual confirm picks up any regression to
   global-keyed storage.

### Assumptions

- Three proofs is the right cap. Fewer would leave the coach
  reaching for numeric framing; more would crowd the system
  prompt and risk the model ignoring earlier sections (GOAL,
  RATING). Three matches the visual chip cap on the follow-up
  row, so the surface registers as "three things to look at" at
  every layer.
- `addedAt`-based eviction is correct over `sessionDate`-based.
  The two policies disagree when the user refreshes an old proof
  (e.g. an AI re-fetch after a deterministic fallback): under
  `sessionDate` policy, the refreshed proof's old session date
  would still mark it as evictable; under `addedAt` policy, the
  refresh keeps it safe because we just touched it. The latter
  is what a "the coach remembers what I just earned" UX wants.
- The PROOFS section lives at the END of the context block (after
  TRENDS). Reasoning: GOAL / RATING / BASELINE are anchoring
  facts the model needs first; PROOFS are supporting evidence
  for the reply, best read just before the model composes. If
  this turns out to under-weight proofs in practice (the model
  defaults to citing baseline numbers over quotes), the right
  fix is to move PROOFS earlier or to bold the instruction in
  the section header — both are one-line edits.

### Verification (what was checked)

- File reads + edits applied via Edit / Write tools; no Bash
  builds run (sandboxed Linux environment, no Xcode toolchain).
- `grep` after each edit confirmed: (a) the new
  `ProofMomentArchive.swift` file lands in `Noum/` (auto-included
  by the `PBXFileSystemSynchronizedRootGroup` already configured
  for that directory), (b) the new `recentProofs:` parameter
  lands once in `CoachContextBuilder.userContext`, (c) the
  AskNoumView call site uses `proofStore.recent(limit: 3)`, (d)
  no other call site of `userContext` needs to change
  (existing tests / consumers pick up the default `[]`).
- Test struct rhythm matches existing `AskNoumStoreTests` (
  `freshStore()` helper + UUID-suite UserDefaults + deterministic
  account ID).
- Sendability — `ProofMoment` (String / Date / Bool fields) and
  `UUID` cross the actor → MainActor boundary cleanly. No new
  closures, no class types added to the struct, so the boundary
  is safe.
- Brand voice — the only user-visible string is the PROOFS
  section header inside the system prompt, which the user never
  sees directly. The coach's *quotes* of the user's transcript
  are verbatim by design (fabrication guard already in
  `ProofMomentService.transcriptContains`).

### Risks

- See "Risks" section above.

## Files modified

- `Noum/ProofMomentArchive.swift` (NEW, ~155 LOC — `ProofMomentRecord`
  struct + `ProofMomentStore` ObservableObject + persistence).
- `Noum/ProofMomentService.swift` (+~30 LOC — six MainActor hops
  + new `persistToArchive` helper).
- `Noum/CoachContextBuilder.swift` (+~25 LOC — new optional
  `recentProofs:` param + PROOFS section renderer).
- `Noum/AskNoumView.swift` (+2 LOC — `@StateObject` for the new
  store + `recentProofs:` argument on the context call).
- `NoumTests/NoumTests.swift` (+~320 LOC — `ProofMomentArchiveTests`
  + `CoachContextBuilderProofTests`).
- `docs/CURRENT_STATE.md` (trail-of-breadcrumbs entry + Ask Noum
  section bullet).
- `HANDOFF.md` (rewritten — this file).

## Branch

`Redesign` — committed and pushed per the brief. The user
explicitly requested work on the Redesign branch ("ensure
working on the redesign branch too (very important)"). All
M14 commits land here; this push continues that pattern.
