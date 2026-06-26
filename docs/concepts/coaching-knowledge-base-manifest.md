# Coaching Knowledge Base — manifest

The "brain" behind Ask Noum: a curated, on-device body of communication-coaching
expertise the model is grounded in, so its prescribed moves come from real
coaching practice instead of an averaged-out base-model guess. This is the piece
that was missing — the chat had rich *user telemetry* but zero *coaching
expertise* to cite. RAG closes that gap.

## What shipped

| File | Role |
| --- | --- |
| `Noum/CoachingKnowledgeBase.swift` | The corpus. `CoachKnowledgeCard` schema + `CoachKnowledgeBase.cards` (~64 curated cards). Pure value types, in-binary, no download, no network. |
| `Noum/KnowledgeRetriever.swift` | BM25 retriever (`KnowledgeRetriever.retrieve`) + the honesty gate + `CoachExpertiseFormatter`. Pure, deterministic, `nonisolated`. |
| `Noum/CoachContextBuilder.swift` | `userContext(...)` gained `coachingExpertise:` (defaulted) and emits a `COACHING EXPERTISE` section before `END CONTEXT`. `systemPrompt(...)` gained intelligence-floor rule **#18**. |
| `Noum/CoachReplyPipeline.swift` | `generate()` calls `KnowledgeRetriever.retrieve` and threads the result into `userContext`. Same single brain, just better-informed. |
| `NoumTests/CoachBrainTests.swift` | Corpus integrity, retriever relevance + gate, formatter honesty, context injection, and the softened anchor-gate regression. |

## Retrieval decision: BM25 primary, embeddings deferred

For an ~64-card bounded corpus, **pure-Swift BM25** (k1=1.2, b=0.75) over an
in-memory inverted index is the primary mechanism, NOT a fallback. Why:

- Deterministic, zero-dependency, sub-millisecond, works offline **and in the
  iOS Simulator**, and is fully unit-testable without a device, a model
  download, or any API key.
- An ANN/vector DB (ObjectBox/USearch/SQLiteVec) buys nothing at this size —
  brute-force over ~64 vectors is already trivial.

**Deferred (documented seam, not a dead toggle):** an optional
`NLContextualEmbedding` (iOS 17) semantic rerank of the BM25 top-K. It is
deferred because the contextual-embedding asset **does not load in the iOS
Simulator** (Apple FB22699606) and its on-device download can hang ~30s — so it
can't be part of the Simulator/CI test loop and must never be a hard dependency.
If added later it must: load off-main with a hard timeout, cache card vectors to
disk, fuse with BM25 via Reciprocal Rank Fusion (k=60), and **degrade silently
to BM25** when assets are unavailable. The reply must never block on it. Flag
ships OFF until verified on a physical device.

## The honesty contract (why this doesn't become a platitude wrapper)

1. **A card is technique reference, never a reading of the user.** The user's own
   telemetry (CONTEXT) is always the evidence; a card is only the method. System
   prompt rule #18 makes the precedence explicit: when a card conflicts with the
   user's observed data, **the user's data wins**, and the coach never states a
   card as a finding about the user or claims a technique caused a result.
2. **Evidence tiers are enforced, not decorative.** Each card carries
   `empirical` / `practitioner` / `folk`. The formatter appends a softening
   qualifier (`[established coaching practice]`, `[rule of thumb — offer it,
   don't assert it]`) for the weaker tiers, matching the app's existing
   weak-evidence → softer-language rule. `CoachKnowledgeBaseIntegrityTests`
   asserts the tiers are actually used.
3. **Readiness gate.** `retrieve` returns `[]` for a cold-start user (no
   `CoachMemory.currentLever`) UNLESS the turn explicitly asks for technique. So
   a brand-new user isn't prescribed technique on thin evidence; the coach reads
   the person.
4. **The corpus can never fight the gate.** `noCardContainsAGateBannedPhrase`
   asserts no card's formatted line contains any `AICoachChatService`
   robotic/defensive banned phrase — so retrieval can't tempt the model into a
   phrase its own reply gate would reject.

> **Sync rule:** `CoachBrainTests.bannedPhrases` mirrors the private
> `roboticPhrases` + `defensiveProductPhrases` in `AICoachChatService`. If that
> gate list changes, update the test list here too.

## Corpus sources & coverage

Hand-authored to the same evidence-honest bar as the intelligence floor, with
vocabulary aligned to what the app already detects (`EloquenceEngine` devices,
`LessonsCatalog` lessons, `SkillArea` levers). Domains map to the product pillars
and the real-world transfer surfaces in `docs/VISION.md`:

filler reduction · composure/pressure · pacing & clarity · structure · rhetoric
(the EloquenceEngine devices) · reading progress (small-sample humility) · voice
register (one per voice) · transfer: interviews / presentations / difficult
conversations / leadership / social-dating / networking.

## Day-to-day reliability fix (shipped alongside)

`AICoachChatService.replyHasObservableAnchor` was rejecting valid SOFT anchors
(no hard keyword/digit), which false-tripped `.unanchoredCoaching` and dumped
good replies to the deterministic fallback. It now also accepts a temporal
marker + a second-person action ("earlier you rushed the open…"). The change
only **admits** more replies — it never newly rejects — so the shared
`LiveCoachCallView` spoken path can't regress from it.

*Not changed (deliberately):* the `"let's"` ban. It is brand-enforced in BOTH the
gate and the system prompt (and pinned by the `rejectsLetsRegister` test), so
they're consistent; un-banning it is a brand-voice taste call for the owner, not
a bug fix.

## Agentic upgrade path (next, not now)

`KnowledgeRetriever.retrieve` and the context accessors are built **tool-shaped**
on purpose. Today the pipeline calls retrieval *for* the model (fast,
deterministic). The same function is the drop-in tool a future model-driven
tool-calling loop (Gemini function-calling) would invoke for the **text** chat
path, where an extra round-trip's latency is invisible. The voice call stays
single-shot for latency. Because the tool already exists, the agentic step is a
wiring change, not a rebuild — and it is intentionally deferred off the current
single-provider Flash path until that path is hardened, so reliability improves
before more moving parts are added.

## Known debt

- `userContext` is now a 27-parameter pure function. The new `coachingExpertise`
  param is additive + defaulted for zero-risk wiring; a future refactor could
  fold the turn-level inputs into a context struct.
