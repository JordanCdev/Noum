# Initiative #3 — Fuse the per-rep delivery reads into one durable delivery read (advances Perception + Case formulation; target M17).

ARCHITECTURE DECISION (coach-lens): The fused read is computed ONCE per finalize inside `DerivedReadsTrendEngine` (extended with a pure `fuseDeliveryRead(...)` static — NO new analyzer/engine/store), persisted as ONE bounded optional `CoachDeliveryRead?` field on `CoachCaseFile`, and surfaced through the SINGLE existing `coachCaseFileLines(memory:)` emitter (CoachContextBuilder.swift:2171). Because every coaching surface (chat coach via AskNoumView, post-rep SummaryView opener, forward plan, next-recommendation) renders the case file from that one stored field, the "one read everywhere" coach-lens invariant holds BY CONSTRUCTION — no per-surface recomputation, no drift. This mirrors how `subjectivePattern: String?` / `transferRead: String?` already live on the case file (PrimaryFocusMemory.swift:830-831).

WHY THIS IS THE MOST DANGEROUS INITIATIVE / CONSERVATISM: The fused read characterizes a person (clear / polished / evasive / timid / detached). The reducer therefore: (a) emits NO characterization below a 4-rep same-direction floor (single/few-rep windows return a `.forming` pattern, persisted but copy stays 'early read, not a characterization yet'); (b) calibrates pitch/energy bands to the user's OWN baseline (`baseline.pace`, `baseline.hedgingRate` already feed the per-session closures at CoachContextBuilder.swift:659-665, and ComposureReadEngine/ConfidenceMarkerEngine already read pace RELATIVE to baseline so soft/accented speakers are not mislabeled) — the fusion adds NO new absolute acoustic band; (c) frames every interpretive label as a hypothesis the user can reject (mirrors the subjectivePattern copy contract at CoachContextBuilder.swift:2196 + system rule 11 at :88); (d) describes combined acoustic+structural signals as association, never causation.

EVIDENCE-FLOOR SHAPE reuses the SHIPPED `DerivedReadsTrendEngine` window math (DerivedReadsTrend.swift:106-227): recent window = latest 5 reps, prior = 5 before, `minRecentReps = 3`. The fusion adds a STRICTER `minRepsForCharacterization = 4` floor (the roadmap's '~4-5 reps' bar) before any clarity-vs-polish/evasive/timid/detached label is allowed; below it the dominant pattern is forced to `.forming` and copy is purely tentative.

Generated: 2026-06-01

> Implementation-ready spec, code-grounded. readyToImplement: false — until predecessor gate + open-question sign-off.

## Ground-truth checks (verified against real code)

- OK — CoachCaseFile exists and is the durable case spine to extend (struct, synthesized Codable, no custom init(from:)/CodingKeys — so a NEW field MUST be Optional for back-compat decode of old persisted case files)
    _Noum/PrimaryFocusMemory.swift:821 `struct CoachCaseFile: Codable, Equatable {`; fields updatedAt/hypothesis/focus/evidenceSummary/.../subjectivePattern:String?/transferRead:String? at :822-833; awk scan of :821-970 found NO `init(from:`/`enum CodingKeys`/`decodeIfPresent` inside the struct -> synthesized Codable_
- OK — DerivedReadsTrend (the roadmap-cited owner name) — ACTUAL type is `enum DerivedReadsTrendEngine` returning `[DerivedReadTrend]`; there is NO `struct DerivedReadsTrend`. Minor naming correction; the engine is the real fusion site.
    _Noum/DerivedReadsTrend.swift:80 `enum DerivedReadsTrendEngine {`; :51 `struct DerivedReadTrend` (per-dimension); grep for `struct DerivedReadsTrend` returns nothing_
- OK — PitchMetrics output shape (meanHz?/stdHz?/voicedRatio/windowCount + isReliable gate + monotoneScore 0..1)
    _Noum/PitchMetrics.swift:27-103; isReliable requires windowCount>=10 && voicedRatio>=0.20 && 70<=mean<=400 (:56-61); monotoneScore returns 0.5 when not reliable (:68-75)_
- OK — VocalEnergyMetrics output shape (meanLevel/peakLevel/stdDeviation/coefficientOfVariation/steadiness 0..1/sampleCount)
    _Noum/VocalEnergyMetrics.swift:40-83; steadiness = max(0,min(1,1.0-cv)) (:178); minimumSampleFloor=30 (:98)_
- OK — ComposureRead output shape (score 0..1/contributingChannels/inputs/readout) + ComposureReadEngine.derive(session:hedgingPerMinute:)->ComposureRead?
    _Noum/ComposureRead.swift:36-61 struct; :65 enum ComposureReadEngine; :76-79 derive signature; minimumContributingChannels=2 (:71); pitch channel maps CV<0.10 (very monotone) -> 0.4 (:99-114)_
- OK — ConfidenceMarkerRead output shape (score 0..1/contributingChannels/inputs/readout) + ConfidenceMarkerEngine.derive(session:hedgingPerMinute:paceWPM:composure:)->ConfidenceMarkerRead?
    _Noum/ConfidenceMarkerRead.swift:35-52 struct; :54 enum ConfidenceMarkerEngine; :63-68 derive signature; pace channel reads RELATIVE drift vs baseline so slow speakers not penalized (:99-125); minimumContributingChannels=2 (:59)_
- OK — StructuralRead output shape (score 0..1/contributingDimensions/inputs/readout) + StructuralReadEngine.derive(snapshot:SkillSnapshot?)->StructuralRead?
    _Noum/StructuralRead.swift:38-57 struct; :59 enum StructuralReadEngine; :69 derive(snapshot:); :76 derive(categoryRatings:) pure entry; minimumContributingDimensions=2 (:64)_
- OK — DerivedReadsTrendEngine.compute already fuses NOTHING — it returns FOUR SEPARATE per-dimension trends (parallel cards), confirming no fused read exists. This is the gap initiative #3 closes.
    _Noum/DerivedReadsTrend.swift:106-183 builds `var trends: [DerivedReadTrend] = []` and appends one entry per dimension (energy/composure/confidence/structural); returns the array — never combines into a single read_
- **MISSING / CORRECTED** — NO existing fused DeliveryRead symbol anywhere (the read must be net-new)
    _grep -rn for `DeliveryRead|fusedDelivery|deliveryRead|FusedRead|deliverySynthesis` across all *.swift returns ZERO hits; `grep -rqn 'struct DeliveryRead|enum DeliveryRead'` exit=1_
- **MISSING / CORRECTED** — Roadmap-cited `evidenceDepth` field does NOT pre-exist — it is a NEW field this spec defines (roadmap said 'define ... plus evidenceDepth', so correct, but flagging no such symbol exists today)
    _grep for `evidenceDepth` across all *.swift -> 0 hits_
- OK — CoachCaseFile.build receives ONLY (from memory: CoachMemory, now: Date) — it does NOT receive sessions/snapshots. CRITICAL: the fusion (which needs the session window) CANNOT be computed inside CoachCaseFile.build; it must be computed upstream in CoachMemoryEngine.build (sessions in scope) and stored on CoachMemory, then read by CoachCaseFile.build like subjectivePattern.
    _Noum/PrimaryFocusMemory.swift:835 `static func build(from memory: CoachMemory, now: Date) -> CoachCaseFile?`; subjectivePattern sourced from `memory.reflectionPattern?.reportedLine` at :842 — the exact pattern to mirror_
- OK — CoachMemoryEngine.build receives sessions:[PracticeSession] and trends, and calls CoachCaseFile.build at the end. But it does NOT receive snapshots:[SkillSnapshot] — required for the StructuralRead dimension of the fusion. Must add a defaulted snapshots param.
    _Noum/PrimaryFocusMemory.swift:969-985 build signature lists sessions/trends but NO snapshots; CoachCaseFile.build called at :1147 `memory.caseFile = CoachCaseFile.build(from: memory, now: now)`_
- OK — Production wiring: CoachMemoryStore.refresh is the sole production caller; SkillTrendStore.shared.snapshots IS already in scope at that call site (used 12 lines above), so threading snapshots costs no new dependency.
    _Noum/SessionFinalizer.swift:243 `CoachMemoryStore.shared.refresh(...)`; :231 `let skillTrends = TrendAnalyzer.analyze(snapshots: SkillTrendStore.shared.snapshots)` — snapshots already read in the same function; refresh signature at PrimaryFocusMemory.swift:1621-1635 also lacks snapshots_
- OK — PracticeSession carries vocalEnergyMetrics/pitchMetrics/pauseMetrics/date/id (all the closure inputs the fusion reads), all Optional+defaulted
    _Noum/SpeechRecognizerViewModel.swift:623 struct; date (:628), pauseMetrics (:647), pitchMetrics (:651), vocalEnergyMetrics (:678, struct tail)_
- OK — SkillSnapshot carries sessionId + categoryRatings (the StructuralRead input, matched to session by id)
    _Noum/TrendAnalyzer.swift:7 struct; :3 sessionId:UUID; :10 categoryRatings:[String:String]; DerivedReadsTrend.swift:175 matches `snapshots.first(where: { $0.sessionId == session.id })`_
- OK — BaselineStat (.value/.confidence/.isReliable) + BaselineConfidence ladder (insufficient/tentative/moderate/established/stable; isReliable = >= .moderate) — the per-user calibration anchor
    _Noum/BaselineEngine.swift:137-145 BaselineStat; :101-132 BaselineConfidence; baseline.pace (:174) + baseline.hedgingRate (:189) are the user's own WPM/hedge baselines feeding the closures at CoachContextBuilder.swift:659-665_
- OK — coachCaseFileLines(memory:) is the single case-file emitter feeding CoachContextBuilder.userContext; under the 'COACH CASE FILE (durable strategy)' header; caps at prefix(10); the subjectivePattern/transferRead lines here are the hypothesis-framed copy templates to mirror.
    _Noum/CoachContextBuilder.swift:2171-2204; emitted at :455 + :481-484; subjectivePattern line :2196 'Treat as self-report, not diagnosis.'; transferRead line :2199 'User-reported; not proof of causation.'; prefix(10) cap :2203_
- OK — Initiative #1 verdict-aware reviewStatus branch with below-floor fallback is the EXACT discipline template to mirror (verdict above floor, fall back to existing assessment below it)
    _Noum/PrimaryFocusMemory.swift:1499-1534; RecommendationAdaptationAnalyzer.adaptationVerdict gate at :1509-1512 with `else` fallback to summary.assessment at :1522-1533_
- OK — ForwardPlanService already carries the init#1 adaptationRationale verdict line (precedent for one-read-on-every-surface) and has sessions in scope but NOT snapshots
    _Noum/ForwardPlanService.swift:512-516 adaptationRationale appended; input.sessions at :23/:39; no snapshots field_
- **MISSING / CORRECTED** — All proposed new symbols are collision-free
    _grep counts: CoachDeliveryRead/DeliveryReadPattern/deliveryRead/DeliveryReadEngine/fuseDeliveryRead/evidenceDepth all = 0 hits across *.swift_
- OK — DerivedReadsTrendEngineTests suite + PracticeSession factory exist to reuse for the new fusion tests (Swift Testing @Suite/@Test/#expect)
    _NoumTests/NoumTests.swift:21494 `@Suite("DerivedReadsTrendEngine")`; private `session(daysAgo:energySteadiness:...)` factory at :21497 building PracticeSession with vocalEnergyMetrics; compute-call pattern at :21512_
## New types / fields

// ============================================================
// 1) NEW VALUE TYPE — in Noum/DerivedReadsTrend.swift (beside DerivedReadTrend, ~after :78).
//    Pure Codable value. Bounded: enum is finite; one clamped depth Int; one bounded String.
// ============================================================

/// One durable, fused read of HOW the user comes across, synthesized from the
/// already-sensed per-rep delivery dimensions (vocal energy, composure,
/// confidence markers, structural, pitch) over the recent window. Replaces the
/// "dashboard of parallel cards" with ONE editorial read. Every characterization
/// is a hypothesis the user can reject, never a trait. Association, never causation.
struct CoachDeliveryRead: Codable, Equatable {

    /// The dominant pattern. `.forming` is the honest below-floor state — the
    /// engine has reads but not enough same-direction agreement to characterize.
    /// The four interpretive labels match the VISION-named frontier
    /// (clear-vs-polished / evasive / timid / detached).
    enum Pattern: String, Codable, Equatable {
        case forming          // below the 4-rep characterization floor — tentative only
        case clearAndGrounded // strong + congruent across acoustic AND structural channels
        case polishedButFlat  // structure/words land but energy+pitch read flat -> reads detached/over-rehearsed
        case evasive          // structure holds but confidence markers + pause quality read as hedged/dodging
        case timid            // low energy + high hedging/filler density + monotone -> reads tentative
        case detached         // flat energy + monotone pitch + low composure variability -> emotionally distant
    }

    /// How much evidence backs this read. Drives copy register (tentative vs
    /// committed) and gates persistence of a characterization. NOT a quality score.
    enum EvidenceDepth: String, Codable, Equatable {
        case insufficient     // < minRecentReps (3) scored reps in window — pattern forced to .forming
        case forming          // 3 reps, OR >=4 reps but direction not yet consistent — pattern forced to .forming
        case established      // >= minRepsForCharacterization (4) reps AND same direction held -> a label is allowed
    }

    let pattern: Pattern
    /// Count of reps in the recent window that produced >= minContributingDimensions scored channels.
    let evidenceReps: Int
    let evidenceDepth: EvidenceDepth
    /// One-line tentative coach read. ALWAYS hypothesis-framed; never "you are X".
    /// Bounded to 220 chars at build time (mirrors `bounded(_:)` discipline in CoachCaseFile).
    let read: String
    /// Which underlying dimensions actually contributed (honest provenance for the line).
    let contributingDimensions: [String]   // e.g. ["vocal energy","composure","structural"]

    static let unpersistedForming = CoachDeliveryRead(
        pattern: .forming, evidenceReps: 0, evidenceDepth: .insufficient,
        read: "", contributingDimensions: []
    )
}

// ============================================================
// 2) NEW FIELD on CoachCaseFile — Noum/PrimaryFocusMemory.swift:821 struct.
//    OPTIONAL + defaulted -> synthesized Codable decodes old persisted case files as nil.
//    Mirrors subjectivePattern:String? / transferRead:String? exactly.
// ============================================================
var deliveryRead: CoachDeliveryRead? = nil   // add to struct fields after `transferRead` (:831)
// Add to the explicit memberwise init AND the CoachCaseFile(...) construction in build() (:854-867),
// reading it straight off memory like subjectivePattern: `deliveryRead: memory.deliveryRead`.

// ============================================================
// 3) NEW FIELD on CoachMemory — Noum/PrimaryFocusMemory.swift (beside reflectionPattern :678).
//    Computed once in CoachMemoryEngine.build (sessions in scope), read by CoachCaseFile.build.
//    OPTIONAL + defaulted; add to memberwise init (:694-725 list, defaulted) AND init(from:)
//    via `decodeIfPresent` (mirrors :806) AND CodingKeys (mirrors :773).
// ============================================================
var deliveryRead: CoachDeliveryRead? = nil

// ============================================================
// 4) NEW PURE STATIC + named thresholds — Noum/DerivedReadsTrend.swift, inside enum
//    DerivedReadsTrendEngine (NO new engine). Reuses the existing window constants.
// ============================================================
extension DerivedReadsTrendEngine {
    /// Stricter floor than minRecentReps: no clarity/polish/evasive/timid/detached
    /// LABEL until >= this many scored reps AND a consistent direction. The roadmap's
    /// "~4-5 reps" bar. Below it -> Pattern.forming, EvidenceDepth.forming, tentative copy.
    static let minRepsForCharacterization: Int = 4
    /// A rep must yield >= this many scored delivery channels to count toward evidenceReps
    /// (mirrors the per-engine minimumContributingChannels=2). Stops a one-channel rep
    /// from inflating the sample toward the characterization floor.
    static let minContributingDimensions: Int = 2
    /// Score below this on the FUSED 0-1 composite reads as a low/flat channel (used to
    /// separate polished-but-flat / detached / timid). Calibrated to the 0-1 derived-read
    /// range, NOT raw acoustics — per-user baseline calibration is already baked into the
    /// composure/confidence channels upstream.
    static let lowChannelCeiling: Double = 0.45
    /// Score at/above this reads as a strong/clear channel.
    static let strongChannelFloor: Double = 0.70
    /// Min fraction of scored reps that must share the dominant direction before a label
    /// is allowed (consistency gate against a single outlier rep flipping the read).
    static let directionConsistencyFraction: Double = 0.60

    /// PURE. Fuse the per-rep delivery reads over the recent window into ONE read.
    /// Returns `.forming`/insufficient (never nil) on cold start so the case file can
    /// always carry an honest, tentative state. A LABEL (non-forming pattern) is returned
    /// ONLY when evidenceReps >= minRepsForCharacterization AND the per-channel directions
    /// agree at >= directionConsistencyFraction. Reuses recentWindow(5)/minRecentReps(3).
    static func fuseDeliveryRead(
        sessions: [PracticeSession],
        snapshots: [SkillSnapshot],
        hedgingPerMinutePerSession: (PracticeSession) -> Double?,
        paceBaselinePerSession: (PracticeSession) -> Double?
    ) -> CoachDeliveryRead
}

## Wiring edits

- **Noum/DerivedReadsTrend.swift** @ after struct DerivedReadTrend (~:78), and inside enum DerivedReadsTrendEngine (extend the existing enum, ~after :101) — Add the `CoachDeliveryRead` value type (Pattern/EvidenceDepth enums + fields). Add the new named thresholds + the pure `fuseDeliveryRead(...)` static. REUSE the existing per-session ComposureReadEngine.derive / ConfidenceMarkerEngine.derive / StructuralReadEngine.derive(snapshot:) / session.vocalEnergyMetrics.steadiness / session.pitchMetrics.monotoneScore over `sessions.sorted{ $0.date > $1.date }.prefix(recentWindow)`. Per scored rep, build a per-channel mean (energy steadiness, composure, confidence, structural; pitch monotone INVERTED to a variation score). Map the composite + the lowest/highest channel to a Pattern only when evidenceReps>=minRepsForCharacterization AND directions agree; else Pattern.forming. Compose the one-line `read` (see copy rules). NO causal verbs; NO trait verbs.
- **Noum/PrimaryFocusMemory.swift** @ CoachMemory struct field list (~after :678 reflectionPattern); memberwise init params (:694-725, defaulted = nil); init(from:) (~:806 add `deliveryRead = try c.decodeIfPresent(CoachDeliveryRead.self, forKey: .deliveryRead)`); CodingKeys (~:773 add `deliveryRead`) — Add `var deliveryRead: CoachDeliveryRead? = nil` to CoachMemory with full Codable back-compat (decodeIfPresent so pre-M17 persisted memories decode as nil).
- **Noum/PrimaryFocusMemory.swift** @ CoachMemoryEngine.build signature (:969-985) + body just before `memory.caseFile = CoachCaseFile.build(...)` (:1147) — Add defaulted param `snapshots: [SkillSnapshot] = []` to build(...). Just before building the case file, compute `memory.deliveryRead = DerivedReadsTrendEngine.fuseDeliveryRead(sessions: sessions, snapshots: snapshots, hedgingPerMinutePerSession: { _ in baseline.hedgingRate.value }, paceBaselinePerSession: { _ in baseline.pace.value })` — EXACTLY the closures CoachContextBuilder.swift:659-665 already use, so the read is calibrated to the user's own baseline. Persist `nil` instead of a `.forming`/insufficient read so the case-file line is omitted below the window floor (honest silence). NOTE: only the most-recent rep's snapshot matters per session via sessionId match — pass the full snapshots array; the engine matches internally.
- **Noum/PrimaryFocusMemory.swift** @ CoachCaseFile struct fields (after transferRead :831); memberwise init (:692-... add defaulted param); CoachCaseFile.build(from:now:) construction (:854-867) — Add `var deliveryRead: CoachDeliveryRead? = nil` to CoachCaseFile (synthesized Codable -> optional = decode-safe). In build(from:now:), set `deliveryRead: memory.deliveryRead` (read straight off memory, exactly like subjectivePattern at :842/:863). Add `memory.deliveryRead != nil` to NOTHING in the build-guard (:845-851) — the case file already builds on other signals; a delivery read alone should not force a case file into existence on a cold profile.
- **Noum/CoachContextBuilder.swift** @ coachCaseFileLines(memory:) — after the transferRead line (:2198-2200), before the Next-coach-move line (:2201); within the existing prefix(10) cap (:2203) — Append ONE delivery-read line when `caseFile.deliveryRead` is present AND its pattern != .forming (honest floor): `lines.append("- Delivery read: \(dr.read) Hypothesis the user can confirm or reject, not a trait; combined acoustic + structural signals, association not causation.")`. This is the SINGLE coherent surface — it flows to chat (AskNoumView), the post-rep opener (sessionOpener), and any case-file consumer. Mirrors the subjectivePattern (:2196) + transferRead (:2199) hypothesis-framed copy contract verbatim in register.
- **Noum/CoachContextBuilder.swift** @ system-rules block (after rule 11 at :88, which governs SUBJECTIVE PATTERN) — Add one rule (e.g. rule 12): 'When DELIVERY READ is present, it is a fused read of how the user comes across, built from acoustic + structural signals over recent reps. Treat any characterization (clear / polished / evasive / timid / detached) as a coach hypothesis to confirm, refine, or reject with the user — never a trait or diagnosis, and never a causal claim about why.' Assert presence in a context test near NoumTests.swift:5856.
- **Noum/SessionFinalizer.swift** @ CoachMemoryStore.shared.refresh(...) call (:243-255) — Add argument `snapshots: SkillTrendStore.shared.snapshots` — the SAME value already read at :231 for TrendAnalyzer.analyze. Sole production thread of the snapshot array into the case-file build path. No other behavior change.
- **Noum/PrimaryFocusMemory.swift** @ CoachMemoryStore.refresh(...) signature (:1621-1635) + its CoachMemoryEngine.build(...) call (:1636-1651) — Add defaulted param `snapshots: [SkillSnapshot] = []` to refresh(...) and forward it to CoachMemoryEngine.build(snapshots: snapshots, ...). Defaulting keeps all non-production refresh paths (noteReflection rebuilds at :1666/:1684 call CoachCaseFile.build directly with the memory that already carries deliveryRead — no recompute needed, the stored read persists) compiling unchanged.
- **NoumTests/NoumTests.swift** @ new @Suite("CoachDeliveryReadFusionTests") beside DerivedReadsTrendEngineTests (:21494); reuse its session(daysAgo:energySteadiness:...) factory + add a snapshot factory; plus 1 build-integration test near CoachMemoryEngine.build tests (~:10548) and 1 context test near :5856 — Add the full unit matrix (testMatrix). Call DerivedReadsTrendEngine.fuseDeliveryRead directly (pure, off-main-actor, no store/UserDefaults). Add a CoachMemoryEngine.build test asserting deliveryRead is nil below the window floor and populated above it, and a context test asserting the line appears only at >= characterization floor with hypothesis framing.

## Evidence & copy model

FLOOR LADDER (every threshold named + asserted):
- Cold start / < minRecentReps(3) scored reps in window -> EvidenceDepth.insufficient, Pattern.forming. fuseDeliveryRead returns a forming read; CoachMemoryEngine.build persists `nil` (so coachCaseFileLines emits NOTHING). Honest silence below the floor — mirrors DerivedReadsTrendEngine's own .insufficient discipline (DerivedReadsTrend.swift:204) and CoachCaseFile's omit-when-nil pattern.
- 3 reps, OR >=4 reps but per-channel directions do NOT agree at >= directionConsistencyFraction(0.60) -> EvidenceDepth.forming, Pattern.forming. Persisted state stays tentative; STILL no characterization line surfaces (line gated on pattern != .forming). This is the conservative core: a label requires BOTH count AND consistency.
- >= minRepsForCharacterization(4) scored reps AND consistent direction -> EvidenceDepth.established, a real Pattern (clearAndGrounded / polishedButFlat / evasive / timid / detached) is allowed. Only now does the case-file line render a characterization.

WHEN TENTATIVE vs COMMITTED (copy register): EvidenceDepth.forming/insufficient -> the `read` string (if ever surfaced for debugging) uses 'early read', 'so far', 'not enough to characterize yet'; the rendered case-file line is SUPPRESSED. EvidenceDepth.established -> committed but still hypothesis-framed: 'reads as X' / 'comes across as X', NEVER 'you are X' / 'is X'.

ASSOCIATION-NOT-CAUSATION COPY RULES (enforced by tests + system rule 12):
- The `read` describes how the user COMES ACROSS from combined signals — 'polished words but flat energy reads as detached', never 'flat energy CAUSED detachment' or 'because your pitch was monotone'.
- BANNED tokens in every emitted read (asserted absent): 'caused', 'because', 'proves', 'guarantee', 'always', 'you are', 'is detached', 'is evasive', 'is timid' (the bare trait copula).
- REQUIRED framing tail on the case-file line: 'Hypothesis the user can confirm or reject, not a trait' + 'association not causation' — mirrors CoachContextBuilder.swift:2196/:2199.
- The labels evasive/timid/detached are the EXACT inner-life terms VISION flags as overclaim-prone; they may appear ONLY at EvidenceDepth.established and ONLY inside hypothesis framing.

CALIBRATION (no new absolute band): the fusion adds NO raw-Hz / raw-dB band. It consumes the ALREADY-baseline-calibrated upstream channels — ComposureReadEngine/ConfidenceMarkerEngine read pace RELATIVE to baseline.pace (ConfidenceMarkerRead.swift:99-125) and hedging via baseline.hedgingRate. pitchMetrics.monotoneScore self-gates on isReliable (PitchMetrics.swift:56-75, returns 0.5 not 1.0 on thin data). The lowChannelCeiling(0.45)/strongChannelFloor(0.70) operate on the 0-1 FUSED composite, not acoustics, so a soft/accented speaker who is steady-for-them is never mislabeled monotone or detached.

WHAT STAYS UNPERSISTED: any read below EvidenceDepth.established is NOT written as a characterization (build persists nil for forming/insufficient). The single-rep / few-rep delivery cards CONTINUE to surface per-rep in CoachContextBuilder (:617-647) — the fusion does not remove them; it adds the durable synthesis ON TOP, and only the synthesis persists to the case file.

## Coherence surfaces (coach-lens: one read everywhere)

The coach-lens "one read across every surface" is satisfied by SINGLE-SOURCE persistence: the fused read is computed ONCE in CoachMemoryEngine.build, stored on CoachCaseFile.deliveryRead, and every surface reads that ONE stored field — none recompute, so none can disagree.

1. CHAT COACH (Ask Noum) — AskNoumView sends CoachContextBuilder.userContext at send-time (AskNoumView.swift:9 comment, :273/:469/:507 chip+context calls). userContext emits coachCaseFileLines under 'COACH CASE FILE (durable strategy)' (CoachContextBuilder.swift:455,481-484,2171-2204). The new delivery-read line lands HERE. HOW: append in coachCaseFileLines, gated on pattern != .forming.

2. POST-REP SUMMARY — SummaryView builds its opener via CoachContextBuilder.sessionOpener (SummaryView.swift:1973). Because sessionOpener composes from the same CoachMemory/case file, the read is consistent with chat. No separate edit needed beyond the case-file line; verify the opener path carries case-file context. HOW: same stored field, no recompute.

3. FORWARD PLAN — ForwardPlanService already carries the init#1 adaptationRationale verdict line for cross-surface coherence (ForwardPlanService.swift:512-516). For FULL coherence the delivery read should ALSO appear here IF the case file is reachable in the plan input — OPEN QUESTION below (ForwardPlanInput carries sessions:[PracticeSession] at :23 but not the CoachCaseFile/snapshots; adding it is the init#1 precedent but a larger thread). Decide before shipping; do NOT fold into a recompute that could diverge.

4. NEXT RECOMMENDATION / next-practice — flows through the same CoachMemory/case-file spine; the durable read is available to whatever composes the next prescription context. No new analyzer; the read is advisory context, never a hard selection input (it must not silently override the evidence-led lever).

5. DURABLE CASE FILE — CoachCaseFile.deliveryRead IS the persistence; coachCaseFileLines is its sole emitter. This is the canonical store.

CRITICAL coherence rule: NEVER recompute the fused read at a surface. All surfaces read CoachCaseFile.deliveryRead. The only computation site is CoachMemoryEngine.build (once per finalize). This is what guarantees the read is identical everywhere — the exact failure init#1's round-31/32 deferred-slate commits were closing (silent-context divergence across surfaces).

## Test matrix

- **coldStart_emptySessions_formingInsufficient_notPersisted** — asserts: pattern == .forming; evidenceDepth == .insufficient; evidenceReps == 0; read.isEmpty || contains 'early'; AND build-integration: CoachMemoryEngine.build persists deliveryRead == nil
- **twoScoredReps_belowRecentFloor_forming** — asserts: pattern == .forming; evidenceDepth == .insufficient (below minRecentReps 3); no characterization label
- **threeScoredReps_meetsRecentFloor_butBelowCharacterizationFloor_stillForming** — asserts: evidenceReps == 3; pattern == .forming (3 < minRepsForCharacterization 4); evidenceDepth == .forming; NO clear/polished label yet — proves the stricter 4-rep gate
- **fourConsistentStrongReps_clearAndGrounded_established** — asserts: evidenceReps == 4; evidenceDepth == .established; pattern == .clearAndGrounded; read contains 'reads as'/'comes across'; read does NOT contain {caused, because, proves, 'you are'}
- **fourReps_polishedWordsFlatEnergy_polishedButFlat** — asserts: pattern == .polishedButFlat; contributingDimensions includes 'structural' and 'vocal energy'; read frames detachment as a HYPOTHESIS, association only; no causal verb
- **fourReps_hedgedConfidenceMarkers_structureHolds_evasive** — asserts: pattern == .evasive; read uses 'reads as evasive' inside hypothesis framing; BANNED 'is evasive'/'you are evasive' absent (the single most important inner-life copy lock)
- **fourReps_lowEnergyHighHedgingMonotone_timid** — asserts: pattern == .timid; hypothesis-framed; no trait copula
- **fourReps_flatEnergyMonotoneLowComposureVariability_detached** — asserts: pattern == .detached; association framing; BANNED tokens absent
- **inconsistentDirection_fourReps_noLabel_forming** — asserts: pattern == .forming; evidenceDepth == .forming; proves consistency gate — count alone is insufficient, a single-outlier-balanced window does NOT characterize
- **softSpeaker_steadyForBaseline_notMislabeledMonotoneOrDetached** — asserts: pattern != .detached && pattern != .timid; NOT polishedButFlat purely from low volume — calibration via 0-1 composite + baseline-relative channels protects quiet speakers
- **oneChannelOnlyReps_belowMinContributingDimensions_excludedFromEvidenceReps** — asserts: evidenceReps == 0 (each rep < minContributingDimensions 2); pattern == .forming — a single-channel rep cannot inflate the sample toward the characterization floor
- **pitchUnreliable_monotoneScoreDefaults_doesNotForceDetached** — asserts: pattern == .clearAndGrounded (the 0.5 neutral pitch does not drag to detached); proves unreliable pitch is not weaponized — mirrors PitchMetrics.swift:68-75
- **windowCap_olderRepsBeyondRecentWindow_excluded** — asserts: pattern == .clearAndGrounded (only latest recentWindow=5 evaluated); stale history cannot force a characterization — reuses the existing recentWindow=5 head logic
- **orderIndependence_givenDates** — asserts: identical CoachDeliveryRead (pattern, evidenceReps, evidenceDepth) across orderings — engine sorts by date internally (DerivedReadsTrend.swift:113 idiom)
- **buildIntegration_persistsNilBelowFloor_populatedAbove** — asserts: (a) memory.caseFile?.deliveryRead == nil; (b) deliveryRead != nil with evidenceDepth == .established and a non-forming pattern — proves the snapshots thread + nil-below-floor persistence
- **decodeSafety_legacyCaseFileWithoutDeliveryRead_decodesNil** — asserts: decodes successfully; deliveryRead == nil — synthesized-Codable optional back-compat (same contract as subjectivePattern/transferRead)
- **decodeSafety_legacyCoachMemoryWithoutDeliveryRead_decodesNil** — asserts: decodeIfPresent yields nil; no throw — mirrors PrimaryFocusMemory.swift:806 pattern
- **contextLine_appearsOnlyAtCharacterizationFloor_withHypothesisFraming** — asserts: (a) NO 'Delivery read:' line; (b) line present, contains 'Hypothesis the user can confirm or reject' AND 'association not causation', contains NONE of {caused, because, proves, 'you are'}
- **associationLanguage_noCausalNoTrait_everyEstablishedPattern** — asserts: every read contains a hypothesis-framing verb ('reads as'/'comes across'); NONE contains {caused, because, proves, guarantee, always, 'you are', bare 'is evasive/timid/detached'} — the master copy-safety lock

## Risks

MOST DANGEROUS INITIATIVE (VISION-flagged). Top risks + mitigations:

1. OVERCLAIM (labeling someone evasive/detached/timid on weak evidence). Mitigation: dual gate — evidenceReps >= minRepsForCharacterization(4) AND directionConsistencyFraction(0.60) — before ANY label; below it Pattern.forming and the line is suppressed; build persists nil below floor. Locked by tests threeScoredReps_stillForming, inconsistentDirection_noLabel, contextLine_appearsOnlyAtCharacterizationFloor.

2. MISCALIBRATION mislabeling quiet/accented speakers. Mitigation: the fusion adds NO absolute acoustic band; lowChannelCeiling/strongChannelFloor act on the 0-1 FUSED composite; upstream confidence/composure channels are already baseline-relative (ConfidenceMarkerRead.swift:99-125); unreliable pitch yields neutral 0.5 not flat 1.0 (PitchMetrics.swift:68-75). Locked by softSpeaker_notMislabeled + pitchUnreliable_doesNotForceDetached.

3. CAUSATION/TRAIT LANGUAGE creep. Mitigation: banned-token assertions in every emitting branch + hypothesis-framing tail on the case-file line + new system rule 12. Locked by associationLanguage_noCausalNoTrait + contextLine test.

4. DASHBOARD-OF-METERS anti-goal regression. Mitigation: this is editorial fusion — ONE line on the case file, ONE stored field. It does NOT add a meter card; the existing per-rep delivery cards (CoachContextBuilder.swift:617-647) are unchanged and only the synthesis persists. No score/percentage is surfaced in the line.

5. CROSS-SURFACE DIVERGENCE (the exact bug init#1 round-31/32 fixed). Mitigation: single computation site (CoachMemoryEngine.build), single stored field, all surfaces read it — recompute at a surface is explicitly forbidden. Locked architecturally + buildIntegration test.

6. BACK-COMPAT decode break. Mitigation: new fields are Optional+defaulted on both CoachMemory (decodeIfPresent) and CoachCaseFile (synthesized-optional). Locked by two decodeSafety tests.

7. PERSISTENCE OF A HYPOTHESIS (VISION: inner-life claims must not persist without user confirmation). TENSION/RISK: we persist a characterization at EvidenceDepth.established WITHOUT an explicit user-confirm tap (unlike the hypothesis-acknowledgement chip path). Mitigation/rationale: it persists as a coach HYPOTHESIS framed for rejection (not a fact), exactly as subjectivePattern persists `reflectionPattern.reportedLine` without a per-instance confirm; the line invites confirm/refine/reject. BUT see open question 1 — a confirm/reject affordance may be required to fully honor the invariant.

8. NO STALENESS/REVISE-DOWN PATH. The read is recomputed every finalize over a moving 5-rep window, so it self-revises as reps roll off — no latch. Lower risk than init#1's replaced-mode latch. No explicit decay needed.

PERFORMANCE: fuseDeliveryRead re-derives composure/confidence per session in the window (<=5) — same cost as the existing DerivedReadsTrendEngine.compute already paid every userContext build; negligible, and now runs once per finalize instead of per chat turn.

## Open questions

- USER-CONFIRMATION AFFORDANCE (the sharpest invariant tension): VISION says inner-life characterizations (evasive/detached/timid) must be confirmable/rejectable and 'never persisted or strengthened without asking.' This spec persists at EvidenceDepth.established framed AS a rejectable hypothesis (matching how subjectivePattern persists reflectionPattern without a per-instance tap). Is hypothesis-framing-without-an-explicit-tap sufficient, or must the established delivery read gain a confirm/reject chip (mirroring the CoachHypothesisAcknowledgement chip in AskNoumView) before it strengthens? Recommend: ship persist-as-hypothesis for v1 (line invites reject), add the chip in a follow-up — but get sign-off, this is the load-bearing invariant.
- FORWARDPLANSERVICE SCOPE (coherence gap, same shape as init#1 open-question 3): the forward plan carries the init#1 adaptationRationale line (:512-516) but ForwardPlanInput has sessions:[PracticeSession] (:23) and NOT the CoachCaseFile or snapshots. Should the delivery read also surface in the plan prompt? If yes, thread the stored CoachCaseFile.deliveryRead into ForwardPlanInput (do NOT recompute via fuseDeliveryRead there — that would risk divergence with a different window/closures). Decide before shipping.
- PATTERN DISAMBIGUATION RULES need a final decision table: polishedButFlat vs detached vs timid share overlapping signals (low energy + monotone). The spec sketches the separators (structural-strong distinguishes polished-but-flat; high-hedging distinguishes timid; low-composure-variability distinguishes detached) but the exact precedence when 2+ patterns qualify must be pinned as named constants + a deterministic ladder (like init#1's decision ladder) so a test asserts each boundary. Recommend resolving with a single ordered if-ladder and a test per arm before implementation.
- CHARACTERIZATION FLOOR VALUE: roadmap says '~4-5 reps'; spec sets minRepsForCharacterization=4 (the floor of that range) to match the existing recentWindow=5 / minRecentReps=3 family. Confirm 4 (not 5) is acceptable — 5 would require the FULL recent window every time and make the read rare given evidence-density concerns (same concern init#1 flagged for its 6-rep bar). No production telemetry on per-window scored-rep density.
- INTERACTION WITH PER-REP CARDS: the existing DERIVED READ TRENDS + per-rep COMPOSURE/CONFIDENCE/STRUCTURAL blocks (CoachContextBuilder.swift:617-673) remain. Confirm the durable fused line is meant to ADD to (not replace) those in the chat context. Roadmap says 'read one delivery read instead of many cards' — if the intent is to COLLAPSE the per-rep cards once the fused read is established, that is a larger editorial change to CoachContextBuilder and should be a separate decision.

