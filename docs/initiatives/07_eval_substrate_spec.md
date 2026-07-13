# Initiative #7 — Stand up a version-controlled evaluation set wired to the live coaching logic (Validation stage, M20). Extend the REAL session owner (`PracticeSession` + `PracticeSessionStore`, both in Noum/PracticeSupport.swift) with a bounded, decode-safe, defaulted `isEvaluationFixture` flag + stable `fixtureID`; promote the existing `#if DEBUG` `DevSeedData` seed tool into a version-controlled, RELEASE-available `EvaluationCorpus` of ~12–20 hand-curated PracticeSession fixtures spanning the five pillars (filler-heavy, pace, structure-collapse-under-pressure, strong-baseline, cold-start), each carrying a frozen absolute date and a stable fixtureID; add a `@Suite("EvaluationCorpusSnapshotTests")` (#if DEBUG) that loads each fixture, derives the same inputs the production SessionFinalizer builds (BaselineEngine.compute → CommunicationBaseline, RecommendationLearningStore ledger), runs them through BOTH live coaching entry points — `NextActionEngine.recommend(input:)` (time-INDEPENDENT, the snapshot anchor) and `CoachContextBuilder.userContext(...)` (time-DEPENDENT, asserted on time-invariant substrings only) — and snapshots a deterministic projection so any logic change is diffable against known sessions. HONEST FLOOR (load-bearing): this ships ONLY the measurement substrate. It is NOT calibration. No Validation maturity claim may be made until an expert-coach baseline is captured per fixture AND a scored Noum-vs-baseline comparison agrees at a pre-registered rate. Sequenced LAST deliberately — it measures a system the rank 1-6 work is still changing, so the snapshots are EXPECTED to churn until the loop stabilizes.

KEY GROUND-TRUTH CORRECTION: the roadmap's named owners are WRONG. `SessionStore`/`StoredSession`/`Noum/SessionStore.swift:18` and `PracticeSessionStore.swift` DO NOT EXIST. The real persisted session model is `PracticeSession` (Noum/SpeechRecognizerViewModel.swift:623) and the real owner is `PracticeSessionStore` (Noum/PracticeSupport.swift:5937). The spec is rewritten against the real types. This is exactly the wrong-field-name the brief warned about.

DISCIPLINE MIRROR (initiative #1): no new store/engine/screen/routing; new fields bounded + optional + defaulted + decodeIfPresent for back-compat; named asserted thresholds (none new here — the snapshot is a pure projection); pure functions where logic is involved (BaselineEngine.compute, NextActionEngine.recommend, RecommendationAdaptationAnalyzer are all pure statics); coach-lens coherence (the fixture flag must read consistently everywhere a session surfaces, and must NEVER leak an evaluation session into any user-facing surface, baseline, rating, league, or sync); association-never-causation and no-claim-below-floor (the snapshot test asserts the SUBSTRATE only and the spec forbids any calibration claim from it).

Generated: 2026-06-01

> Implementation-ready spec, code-grounded. readyToImplement: false — until predecessor gate + open-question sign-off.

## Ground-truth checks (verified against real code)

- **MISSING / CORRECTED** — Roadmap-cited owner `StoredSession` exists at Noum/SessionStore.swift:18
    _Noum/SessionStore.swift DOES NOT EXIST (ls: No such file). `StoredSession` appears ONLY as `clearStoredSession()` calls in Noum/AuthManager.swift:288,443,635,678 — a private auth-token helper, NOT a session-history model. The roadmap field name and file are wrong._
- OK — Roadmap-cited owner `PracticeSessionStore` (as a standalone file/type) exists
    _The TYPE exists but NOT at the implied path. `final class PracticeSessionStore: ObservableObject` is defined at Noum/PracticeSupport.swift:5937 (there is no PracticeSessionStore.swift). `.shared` singleton at :5938._
- OK — The real persisted session model is `PracticeSession`, a Codable struct
    _Noum/SpeechRecognizerViewModel.swift:623 `struct PracticeSession: Identifiable, Codable`, with explicit CodingKeys (:680-707), memberwise init (:709-763), and a hand-written `init(from decoder:)` using decodeIfPresent for every optional field (:765-793). This is the established bounded/decode-safe pattern the new fields must follow._
- OK — PracticeSessionStore persists `[PracticeSession]` via JSONEncoder to a per-account UserDefaults key
    _Noum/PracticeSupport.swift:5940 `@Published private(set) var sessions: [PracticeSession]`; persist() encodes via JSONEncoder to key `practiceSessions.<accountID>` / `.guest` (:6036-6055); loadSessions decodes via JSONDecoder sorted by date desc (:6064-6068). The whole class is inside `#if canImport(SwiftUI)` (closing #endif at :6070)._
- OK — An existing version-controlled seed tool exists and is reusable as the fixture base
    _Noum/DevSeedData.swift — `#if DEBUG`-gated (:9). `enum DevSeedData` with `SeedProfile` (beginner/improvingIntermediate/plateauedAdvanced/pressureVulnerable/fillerFree, :16-22) maps closely to four of the five pillars; `sessions(for:) -> [PracticeSession]` (:41); `makeSession(...)` factory (:407-429); `replaceAllForDebug` writes to the same UserDefaults key via JSONEncoder (:500-511). This is the proven base to promote — but it is DEBUG-only and uses Date()-relative dates (nondeterministic)._
- OK — DevSeedData is already consumed by tests (proving the fixture-from-Swift pattern compiles for the test target)
    _NoumTests/NoumTests.swift:1374-1418 `#if DEBUG struct SeedDataTests` calls `DevSeedData.sessions(for:)` (:1379,1398,1407,1413) and feeds them through `BaselineEngine.compute` (:1408,1414). Tests compile in DEBUG so #if DEBUG seed code is available. This is the exact precedent to extend._
- OK — The fixtures can run through `CoachContextBuilder` as the roadmap's first step states
    _Noum/CoachContextBuilder.swift:28 `enum CoachContextBuilder` (`@available(iOS 17.0, macOS 12.0, *)`, NOT @MainActor); :224 `static func userContext(profile:baseline:rating:sessions:[PracticeSession]:...) -> String` with all-defaulted extra params. Called directly (no @MainActor) in tests at :5411 etc. Takes sessions plus baseline/rating/outcomes the harness must derive._
- OK — The real `recommendation set` generator that initiative #1 wired the verdict into is `NextActionEngine.recommend`, and it is time-independent (snapshot-safe)
    _`NextActionEngine.recommend(input:)` is a pure value transform; the former unread, device-global `LastNextActionSnapshot` write was removed rather than being mistaken for Home integration. `NextAction` + `ActionRecommendation` remain snapshot-projectable and the recommendation tiers touch no clock._
- OK — BaselineEngine.compute is a pure static deriving qualifyingSessionCount deterministically from sessions
    _Noum/BaselineEngine.swift:594 `enum BaselineEngine`; :600 `static func compute(from sessions: [PracticeSession]) -> CommunicationBaseline`; sets baseline.qualifyingSessionCount = qualifying.count (:610). SessionFinalizer gates recommend on `baseline.qualifyingSessionCount >= 2` (Noum/SessionFinalizer.swift:288). SessionQualifier.qualifies requires duration>=15, wordCount>=20, confidence>=0.5-if-present (BaselineEngine.swift:580-587) — so cold-start pillar = sessions below these floors or empty._
- OK — CoachContextBuilder.userContext output is TIME-DEPENDENT (snapshot determinism risk)
    _Noum/CoachContextBuilder.swift embeds Date()-relative cutoffs: :396 (-7 day proof cutoff), :2102 (-30 day cutoff), :2333 caseReviewLabel(now: Date()), :2494 `let now = Date()`, :305/:1536 BigMomentStore.daysUntil. A fixture dated relative to Date() would produce a DIFFERENT context string daily, breaking diffability. MUST snapshot the time-independent NextAction projection and assert userContext only on time-invariant substrings._
- OK — PracticeMode is String-backed Codable (stable JSON + stable fixtureID derivation)
    _Noum/PracticeModeSelectionView.swift:6 `enum PracticeMode: String, Codable`. Its rawValue is already used to build outcome fingerprints in tests (NoumTests.swift:10257)._
- OK — No symbol collision for the new fields `isEvaluationFixture` / `fixtureID`
    _grep across all non-.build/.DerivedData Swift returns ZERO matches for isEvaluationFixture, fixtureID, EvaluationFixture, evaluationFixture. Safe to introduce._
- OK — RecommendationOutcome (the ledger element fixtures may seed for the adaptation pillars) is Codable and test-constructible
    _Noum/PracticeSupport.swift:6130 `struct RecommendationOutcome: Codable, Equatable, Identifiable`; ledger owner RecommendationLearningStore.outcomes:[RecommendationOutcome] at :6522/:6526. Constructed directly in tests (6 occurrences in NoumTests.swift; factory at :10247-10270)._
- OK — There is NO existing bundled-JSON-resource loading mechanism in the app or test target
    _The app bundles NO runtime .json (only Assets.xcassets/Contents.json metadata). NoumTests target contains ONLY NoumTests.swift (find returns one file). Test target is host-bundled (pbxproj :864-893: BUNDLE_LOADER/TEST_HOST=Noum.app). The entire data layer is UserDefaults+JSONEncoder on Codable structs. => committed fixtures should be Swift source (DevSeedData pattern) OR a JSON string-literal corpus decoded at test time; a bundled .json resource would require new, unprecedented pbxproj resource-phase wiring (open question)._
- OK — An existing decode-safety/back-compat test pattern exists to mirror for the new PracticeSession fields
    _NoumTests.swift:10212 `newOptionalEvidenceFieldsDecodeOlderOutcomeRecords` builds a `LegacyOutcome` struct lacking the new fields, round-trips JSON, and asserts the new fields decode to nil/defaults (:10242-10244). Mirror this with a legacy-PracticeSession JSON (no isEvaluationFixture/fixtureID) asserting isEvaluationFixture==false, fixtureID==nil._
## New types / fields

// ── 1. Two bounded, optional/defaulted, decode-safe fields on the REAL model ──
// Noum/SpeechRecognizerViewModel.swift, struct PracticeSession (:623).
// Mirror the established pattern: defaulted stored prop + CodingKeys entry +
// memberwise-init param (defaulted, appended last) + decodeIfPresent line.

/// True only for hand-curated evaluation-corpus sessions injected by the
/// version-controlled `EvaluationCorpus`. MUST be excluded from every
/// user-facing surface, baseline, rating, league, and backend sync. Optional
/// at the decode boundary (legacy + real persisted sessions decode as false).
var isEvaluationFixture: Bool = false

/// Stable, human-meaningful identifier for an evaluation fixture (e.g.
/// "filler-heavy-01", "cold-start-01"). nil for all real sessions. Lets the
/// snapshot test key output by a name that survives reordering/UUID churn,
/// so a diff names WHICH fixture's coaching output changed. Bounded (.prefix(64)
/// on construction). Decode-safe (legacy sessions decode as nil).
var fixtureID: String? = nil

// CodingKeys additions (after .vocalEnergyMetrics, :706):
case isEvaluationFixture
case fixtureID

// Memberwise init: two new params APPENDED LAST, defaulted, so all existing
// PracticeSession(...) call sites (DevSeedData.makeSession :417, store.append :5969,
// every test factory) compile unchanged:
isEvaluationFixture: Bool = false,
fixtureID: String? = nil
// ...assigned in body: self.isEvaluationFixture = isEvaluationFixture; self.fixtureID = fixtureID

// init(from decoder:) additions (after :792), decodeIfPresent for back-compat:
isEvaluationFixture = try container.decodeIfPresent(Bool.self, forKey: .isEvaluationFixture) ?? false
fixtureID = try container.decodeIfPresent(String.self, forKey: .fixtureID)

// ── 2. The version-controlled corpus (promotes DevSeedData; NOT a new store) ──
// New file Noum/EvaluationCorpus.swift OR appended to Noum/DevSeedData.swift.
// A pure enum returning frozen-date PracticeSession arrays. NOT #if DEBUG —
// it is the "version-controlled" substrate the roadmap demands, so it must
// compile in Release. (DevSeedData stays #if DEBUG; the corpus may delegate to
// DevSeedData's transcript banks but stamps frozen dates + the fixture fields.)

enum EvaluationPillar: String, CaseIterable {
    case fillerHeavy, pace, structureCollapseUnderPressure, strongBaseline, coldStart
}

struct EvaluationFixture: Identifiable {
    let id: String                 // == fixtureID, e.g. "filler-heavy-01"
    let pillar: EvaluationPillar
    let sessions: [PracticeSession]            // frozen absolute dates, isEvaluationFixture=true, fixtureID=id
    let seedOutcomes: [RecommendationOutcome]  // optional ledger to exercise the adaptation verdict; [] for most
}

enum EvaluationCorpus {
    /// Anchor so every fixture date is absolute and deterministic across runs
    /// (NOT Date()-relative). 2025-01-01T00:00:00Z.
    static let epoch = Date(timeIntervalSince1970: 1_735_689_600)
    static func date(dayOffset: Int) -> Date { epoch.addingTimeInterval(TimeInterval(dayOffset) * 86_400) }

    static let all: [EvaluationFixture]   // ~12–20 fixtures, ≥2 per pillar
    static func fixtures(for pillar: EvaluationPillar) -> [EvaluationFixture]

    /// One frozen-date session stamped as an evaluation fixture.
    static func session(fixtureID: String, dayOffset: Int, transcript: String,
                        fillers: Int, duration: TimeInterval, mode: PracticeMode,
                        score: Int?, pressure: PressureLevel,
                        confidence: Double? = 0.9) -> PracticeSession
    // builds PracticeSession(..., isEvaluationFixture: true, fixtureID: String(fixtureID.prefix(64)))
}

// ── 3. Deterministic, time-independent snapshot projection (test-side type) ──
// Lives in the test file. Captures the live coaching OUTPUT for one fixture in
// a stable, diffable string. Anchored on NextActionEngine.recommend (no clock);
// userContext is asserted only on time-invariant substrings (NOT whole-string
// snapshotted) because it embeds Date()-relative cutoffs.
struct CoachingSnapshot: Equatable, CustomStringConvertible {
    let fixtureID: String
    let pillar: String
    let qualifyingSessionCount: Int
    let overallConfidence: String          // baseline.overallConfidence.label
    let primaryTitle: String               // NextAction.primary.displayTitle  (nil-safe "n/a" when gate not met)
    let primaryReason: String              // NextAction.primary.displayReason
    let secondaryTitle: String?            // NextAction.secondary?.displayTitle
    let recommendationConfidence: String   // NextAction.confidenceLevel.label
    var description: String { /* deterministic multi-line block, the golden text */ }
}

## Wiring edits

- **Noum/SpeechRecognizerViewModel.swift** @ struct PracticeSession — stored props after vocalEnergyMetrics (~:678); CodingKeys after .vocalEnergyMetrics (:706); memberwise init params appended last (after :735) + assignments (after :762); init(from decoder:) after :792 — Add `var isEvaluationFixture: Bool = false` and `var fixtureID: String? = nil` following the exact 4-touch pattern every existing optional field uses (stored prop + CodingKeys case + defaulted init param + decodeIfPresent). No behavior change to existing call sites — both params defaulted and appended last.
- **Noum/PracticeSupport.swift** @ PracticeSessionStore.append(_:) :5968-5990 and PracticeSessionStore.replaceFromRemote :6031-6034 — GUARD against fixture leakage into real history. `append` builds sessions from a PracticeSessionDraft (no fixture fields) so it is safe as-is, but add a doc-comment + an assertion-free invariant: real ingestion never sets isEvaluationFixture. In replaceFromRemote, defensively `filter { !$0.isEvaluationFixture }` before persisting so a corrupted/synced fixture can never enter the live store. This is the coach-lens coherence guard — an evaluation session must never surface to the user.
- **Noum/PracticeSupport.swift** @ PracticeSessionStore.syncSessionIfPossible :6057-6062 — Add `guard !session.isEvaluationFixture else { return }` at the top so evaluation fixtures are NEVER uploaded to the backend (BackendSyncManager.syncSession). Fixtures are local test substrate only.
- **Noum/EvaluationCorpus.swift (NEW) or appended to Noum/DevSeedData.swift** @ new file / end of DevSeedData.swift before the trailing #endif if appended (but corpus itself must be OUTSIDE #if DEBUG) — Add `enum EvaluationPillar`, `struct EvaluationFixture`, `enum EvaluationCorpus` with ~12–20 frozen-date fixtures (≥2 per pillar): fillerHeavy (high fillers/min, short, low score — derive from DevSeedData.beginnerSessions register), pace (WPM far above/below band), structureCollapseUnderPressure (strong .casual reps + collapsing .suddenDeath/.high reps — mirror DevSeedData.pressureVulnerableSessions), strongBaseline (near-zero fillers, high score — mirror fillerFreeSessions), coldStart (0–1 sessions OR sessions below SessionQualifier floors so qualifyingSessionCount==0). Each session: isEvaluationFixture=true, fixtureID=stable id, date=EvaluationCorpus.date(dayOffset:). A few fixtures also carry seedOutcomes ([RecommendationOutcome] with frozen completedAt) to exercise the initiative-#1 reinforce/vary/replace verdict end-to-end.
- **NoumTests/NoumTests.swift** @ new `#if DEBUG @Suite("EvaluationCorpusSnapshotTests")` placed beside SeedDataTests (~:1418) or RecommendationAdaptationAnalyzerTests (:10273) — Add the snapshot suite: for each fixture, derive inputs the production SessionFinalizer builds (BaselineEngine.compute(from: fixture.sessions) → baseline; build NextActionInput exactly as SessionFinalizer.swift:289-306 from the most-recent session + baseline + fixture.seedOutcomes; gate on qualifyingSessionCount>=2 like :288), call NextActionEngine.recommend, project into CoachingSnapshot, and compare its .description against an INLINE expected golden string. Also call CoachContextBuilder.userContext(profile:nil/seed, baseline:, rating:.initial, sessions: fixture.sessions, recommendationOutcomes: fixture.seedOutcomes, ...) and assert TIME-INVARIANT substrings only (e.g. cold-start fixture → contains 'No rated sessions yet'; strong-baseline → omits fake filler lines). Include: per-fixture snapshot tests, a fixture-integrity test (every fixture isEvaluationFixture==true, unique fixtureID, frozen dates), the cold-start qualifyingSessionCount==0 test, and the decode-safety legacy test.
- **docs/initiatives/07_evaluation_substrate_spec.md (NEW, optional companion)** @ docs/initiatives/ — Commit this spec mirroring 01_adaptation_loop_spec.md, with the loud 'SUBSTRATE ONLY — NOT calibration' banner and the ground-truth correction that SessionStore/StoredSession do not exist. Documents the snapshot-churn expectation (snapshots are meant to change as rank 1-6 land) and the regeneration procedure.

## Evidence & copy model

HONEST FLOOR (the entire point of sequencing this LAST): the deliverable is the measurement SUBSTRATE, never a calibration result. Copy/claim rules: (1) No code comment, doc line, commit message, or UI string may say the coaching is 'validated', 'calibrated', 'as good as a human coach', or 'benchmarked' on the basis of this fixture set or a green snapshot test. Permitted framing only: 'evaluation substrate', 'fixtures + diffable snapshot', 'regression guard for coaching logic'. (2) The maturity needle (roadmap: Validation score 1) DOES NOT MOVE here — it moves only when an expert-coach baseline is captured per fixture AND a scored Noum-vs-baseline comparison agrees at a pre-registered rate on a majority of fixtures (both out of scope). (3) Association-never-causation is inherited automatically: the substrate snapshots EXISTING outputs (NextActionEngine + CoachContextBuilder), all of which already enforce the floor (RecommendationAdaptationAnalyzer emits association-only rationale, returns nil below the movement floor; userContext omits insufficient-confidence dimensions, CoachContextBuilder.swift:5449 test). The snapshot must therefore reproduce, not weaken, those floors: a cold-start fixture's snapshot MUST show the gate not met / 'No rated sessions yet' and MUST NOT contain a confident verdict. (4) UNPERSISTED / NON-LEAKING: evaluation fixtures never persist to the live store (replaceFromRemote filters them), never reach the backend (syncSessionIfPossible guards), never feed the user's real baseline/rating/league. They exist only inside the test harness's in-memory derivation. (5) Snapshot CHURN is expected and honest: because this measures a system the higher-ranked initiatives are still changing, a snapshot diff is a SIGNAL to review (did this logic change intend to alter coaching on known sessions?), not a failure to suppress — the spec documents a regeneration procedure and forbids treating a churn as 'validated regression-free'. (6) TENTATIVE vs CONFIDENT is not a new axis here — the snapshot records whatever confidence label the live engines already produce (NextAction.confidenceLevel.label, baseline.overallConfidence.label); the test asserts the LABEL is reproduced, never that it is correct.

## Coherence surfaces (coach-lens: one read everywhere)

COACH-LENS for this initiative is INVERTED from a normal feature: the new read (isEvaluationFixture) must appear NOWHERE on any user-facing coaching surface — coherence here means a fixture session is INVISIBLE to the coach voice in production, and VISIBLE only to the test harness. Surfaces audited: (1) PracticeSessionStore.sessions is the array every coaching surface reads (ProfileView:23, PathJourneyView:13, SummaryView:64, VoiceMetricsCard:46, SettingsView:29, SpeechRecognizerViewModel:205 pastSessions). A fixture must never enter this live array — enforced by replaceFromRemote filter + never calling append for fixtures + endSession clearing. (2) Backend sync (BackendSyncManager.syncSession via syncSessionIfPossible :6057) — guarded so fixtures never upload. (3) Baseline/rating/league — fixtures are only ever passed to BaselineEngine.compute INSIDE the test, never into BaselineStore.shared/RatingStore.shared, so the user's real numbers are untouched. (4) The SNAPSHOT itself is the one place the fixture read DOES surface, and it must be coherent across the TWO live entry points: NextActionEngine.recommend (the next-practice recommendation) is the golden anchor, and CoachContextBuilder.userContext (the chat-coach context) is asserted on time-invariant substrings — both must be driven from the SAME derived baseline/ledger so the snapshot reflects one coherent coaching read per fixture, exactly as initiative #1 surfaced its verdict on all three surfaces. (5) Within the corpus, the five pillars must each map to a recognizable coaching posture (filler-heavy → a filler-focused recommendation; cold-start → the honest 'not enough data' floor), so the snapshots read as a coherent caseload a coach would recognize, not random noise. (6) If a future initiative adds a new coaching surface, the fixture-leak guard list (this initiative's filters) is the coherence contract to re-audit.

## Test matrix

- **fixtureFields_defaultSafelyOnLegacyDecode** — asserts: decoded.isEvaluationFixture == false; decoded.fixtureID == nil; all pre-existing fields intact. Locks back-compat for the millions of already-persisted real sessions.
- **fixtureFields_roundTripStable** — asserts: Equality on the two new fields after round-trip; confirms CodingKeys + encode path wired.
- **corpusIntegrity_everyFixtureWellFormed** — asserts: count in 12...20; ≥2 fixtures per EvaluationPillar (all 5 covered); every session has isEvaluationFixture==true and fixtureID==fixture.id; all fixtureIDs unique; all dates == EvaluationCorpus.date(dayOffset:) (deterministic, < epoch+commit window, NOT near Date()); no transcript empty.
- **coldStartFixture_yieldsZeroQualifyingAndHonestFloor** — asserts: qualifyingSessionCount == 0 (sessions below SessionQualifier floors or empty); recommend gate (>=2) NOT met → snapshot.primaryTitle == "n/a"; userContext(sessions:[...]) contains "No rated sessions yet" and "No voice set yet" (mirrors :5404 coldStart test). NO confident verdict present.
- **perFixtureSnapshot_matchesGolden** — asserts: snapshot.description == the INLINE expected golden string for that fixtureID. THIS is the diffable regression guard — any coaching-logic change that alters output on a known session fails here and forces a deliberate golden update. (Each fixture gets its own #expect so a diff names the fixture.)
- **snapshotDeterminism_acrossRepeatedRuns** — asserts: Identical both times AND identical to a hard-coded copy — proves time-independence (NextAction anchor has no clock) and that frozen dates removed Date()-relative drift.
- **strongBaselineFixture_noFakeFillerClaim** — asserts: qualifyingSessionCount high, overallConfidence >= moderate; userContext does NOT fabricate a problem line for a clean speaker; recommendation is a stretch/consolidation posture, not a remedial filler drill. Time-invariant substring assertions only.
- **structureCollapsePillar_recommendationReflectsPressureGap** — asserts: snapshot.primaryReason or primaryTitle reflects the pressure/structure posture (e.g. pressureExposure or the declining/blocker tier) — the coaching read a coach would give this caseload; locks that the pillar is wired to a recognizable output, not noise.
- **adaptationLedgerFixture_verdictFlowsIntoSnapshot** — asserts: The initiative-#1 verdict is observable in the snapshot (NextActionEngine biases away from the confidently-replaced mode AND/OR userContext INTERVENTION RESPONSE carries the association-only rationale). Confirms the substrate exercises the LIVE adaptation logic, not a stub. Association-only language present; 'failed'/causal tokens absent.
- **fixtureNeverLeaksToLiveStore** — asserts: Persisted/published sessions contain NO session with isEvaluationFixture==true; the coach-lens leak guard holds.

## Risks

SUBSTRATE-MISTAKEN-FOR-VALIDATION (highest, the stage's defining trap): a green snapshot suite could be read as 'coaching is validated'. Mitigation: loud 'SUBSTRATE ONLY' banner in the spec/doc + commit message, no 'validated/calibrated' wording anywhere, maturity-needle-does-not-move stated explicitly, and the test names say 'Snapshot'/'regression guard', never 'calibration'. // SNAPSHOT NONDETERMINISM via Date() (highest engineering risk): CoachContextBuilder.userContext embeds Date()-relative cutoffs (:396,:2102,:2333,:2494) so whole-string snapshots of it would churn daily. Mitigation: anchor the golden snapshot on NextActionEngine.recommend (verified clock-free) + frozen absolute fixture dates (EvaluationCorpus.epoch) + assert userContext only on time-invariant substrings. // PREMATURE-CALIBRATION-AGAINST-A-MOVING-TARGET (roadmap's named risk): standing this up while ranks 1-6 change the logic means snapshots WILL churn. Mitigation: this is sequenced LAST by design; the spec FRAMES churn as an expected review signal with a regeneration procedure, not a failure — and forbids any maturity claim until the system stabilizes. // FIXTURE LEAKAGE into the user's real history/baseline/rating/league/backend (trust + correctness): a stray fixture in PracticeSessionStore.sessions would corrupt every coaching surface. Mitigation: isEvaluationFixture guards on syncSessionIfPossible + replaceFromRemote filter + fixtures only ever passed to PURE engines inside the test, never to .shared stores; locked by fixtureNeverLeaksToLiveStore. // RELEASE-COMPILE of a former #if DEBUG tool: the corpus must compile in Release (it is 'version-controlled' substrate) while DevSeedData stays #if DEBUG — risk of accidentally referencing DEBUG-only symbols. Mitigation: corpus is self-contained (its own frozen-date factory) and may copy, not call, DEBUG-gated transcript banks; the SNAPSHOT TEST itself stays #if DEBUG (tests run in Debug) so test-only helpers are fine, but EvaluationCorpus type is outside the guard. (Open question: is Release availability actually required, or is #if DEBUG acceptable since the corpus is test-only? Leaning Release for true 'version-controlled' substrate, but DEBUG is lower-risk and sufficient for the snapshot test.) // PracticeSession field bloat: two more fields on an already-large struct. Mitigation: both optional/defaulted/bounded, follow the exact existing pattern, zero runtime cost for real sessions. // GOLDEN-STRING BRITTLENESS: an over-detailed snapshot string makes every benign copy tweak a test failure. Mitigation: CoachingSnapshot projects a DELIBERATELY NARROW, structural set (titles/reasons/confidence/counts), not the full context string, so it tracks coaching DECISIONS not prose.

## Open questions

- Release vs #if DEBUG for the EvaluationCorpus TYPE. The roadmap says 'version-controlled fixture' (implying it should not be DEBUG-only like DevSeedData), but the only consumer is a test that runs in Debug. Decision needed: ship the corpus outside #if DEBUG (true substrate, slight binary cost, must avoid DEBUG-only deps) vs inside #if DEBUG (lower risk, sufficient for the snapshot test, but technically still a debug tool). Recommend: corpus OUTSIDE the guard so it is a real version-controlled artifact; snapshot test INSIDE #if DEBUG.
- Committed-JSON-file vs Swift-source-literal fixtures. The roadmap's first step literally says 'commit a JSON seed'. But there is ZERO precedent for a bundled-JSON resource in this app/test target (everything is UserDefaults+Codable; NoumTests has only one .swift file), and bundling a .json would require new pbxproj resource-phase wiring loadable via Bundle(for:).url. Two honest options: (A) Swift-source fixtures (DevSeedData pattern) — still version-controlled, diffable, zero new build wiring, the recommended path; (B) a committed Fixtures.json decoded at test time via a string literal or an added test-bundle resource. Recommend (A) unless the user specifically wants an inspectable .json artifact, in which case scope the pbxproj resource wiring explicitly.
- Snapshot anchor scope: golden-string on NextActionEngine.recommend ONLY (clock-free, recommended), or ALSO a normalized userContext snapshot with Date() injected via a seam? CoachContextBuilder.userContext takes no `now:` parameter today (it calls Date() internally), so a fully-snapshotted userContext would need either a new injected-clock seam (a real signature change to a hot path — heavier than this initiative should be) or substring-only assertions. Recommend substring-only for userContext now; defer a clock seam to a later initiative if whole-context snapshots become necessary.
- Do any adaptation-pillar fixtures need seeded RecommendationOutcome ledgers, or is BaselineEngine-derived session history enough? Initiative #1's verdict only fires at >=3–6 MEASURABLE reps for a (mode,focus) key, and the global ledger cap is 40 (PracticeSupport.swift open question 1). Confirm whether ~12–20 session fixtures can naturally produce enough measurable outcomes, or whether the corpus must explicitly carry seedOutcomes to exercise reinforce/vary/replace in the snapshot. Recommend: carry explicit seedOutcomes on 1–2 fixtures so the adaptation path is deterministically covered.
- Fixture count + pillar split: the roadmap says ~12–20 across five pillars. Confirm the target (recommend 15: 3 each) and whether each pillar needs sub-variants (e.g. filler-heavy at moderate vs high confidence) — more fixtures = more snapshot maintenance as ranks 1-6 churn, so keep minimal until the loop stabilizes.
- Expert-coach baseline schema (explicitly OUT OF SCOPE for this initiative, but the substrate should not foreclose it): when calibration is eventually built, will the expert baseline attach to fixtureID as a sibling artifact? If so, fixtureID being a stable string (this initiative) is the forward-compatible hook — confirm fixtureID naming is durable enough that a future expert-baseline file can key on it.
