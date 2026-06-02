# Roadmap initiative #6 — "Reconcile the measured focus with the user's stated challenge, and surface agreement vs. divergence" (Stage: Diagnosis; Milestone: M16). Extend the existing diagnosis spine ONLY: PrimaryFocusMemory.selectLever (Noum/PrimaryFocusMemory.swift:1157) gains a pure stated-challenge fallback lever and CoachMemoryEngine.build (:997-1004) computes a concordance flag; CoachMemory (:625) gains two bounded, decode-safe, defaulted fields; the read renders on every existing coaching surface (CoachContextBuilder CASE FORMULATION lines :2210, CaseReviewCard :39, and through them the chat coach + post-rep CoachReadCard note). No new store/engine/screen/routing. The discipline mirrors shipped initiative #1: a pure unit-testable reducer, named asserted thresholds, hypotheses-not-facts, association-never-causation, no claim below its evidence floor, and ONE coherent read across surfaces. CORE DESIGN: stated challenge alone yields ONLY a tentative lever ("you told me X") when baseline.overallConfidence < .tentative; once baseline.overallConfidence.isReliable (>= .moderate) AND telemetry agrees, isConcordant=true (a confirming, not louder, read); on divergence the engine does NOT auto-flip the stored lever — it emits a one-line coach QUESTION for the user to confirm/reject.

Generated: 2026-06-01

> Implementation-ready spec, code-grounded. readyToImplement: false — until predecessor gate + open-question sign-off.

## Ground-truth checks (verified against real code)

- OK — CoachingProfile stores the onboarding challenge answer in field `biggestChallenge` of type `SpeakingChallenge`
    _Noum/PracticeSupport.swift:494 `var biggestChallenge: SpeakingChallenge`; struct CoachingProfile at :490; SpeakingChallenge enum at :394 (cases fillerWords/rambling/freezing/rushing). Decoded at :576 via plain decode. CONFIRMED — the roadmap's cited field name is correct._
- **MISSING / CORRECTED** — ROADMAP FIELD-NAME WARNING RESOLVED: the roadmap says 'reuse the existing SpeakingChallenge.recommendedPriority mapping' to map stated challenge -> SkillArea. `recommendedPriority` EXISTS but returns `CoachingPriority`, NOT `SkillArea` — a type mismatch. It cannot alone produce a SkillArea.
    _Noum/PracticeSupport.swift:411 `var recommendedPriority: CoachingPriority` (maps fillerWords->.reduceFillers, rambling->.moreConcise, freezing->.thinkFaster, rushing->.calmerDelivery). Target lever space is SkillArea (Noum/DrillSystem.swift:10). The roadmap chained the wrong type. FLAGGED._
- OK — An existing CoachingPriority -> SkillArea bridge exists to complete the composition (so no fresh hand-written SpeakingChallenge->SkillArea map is needed)
    _Noum/ForwardPlanService.swift:565 `nonisolated static func skillAreaForAIWeek(focus: CoachingPriority) -> SkillArea` (.reduceFillers->.fillerReduction, .moreConcise->.conciseSpeaking, .calmerDelivery->.pauseUsage, .thinkFaster->.confidence). Composition `ForwardPlanService.skillAreaForAIWeek(focus: challenge.recommendedPriority)` is total and reuses two shipped maps. (A reverse map SessionIntentStore.aligned(with:) exists at :89 but is wrong direction.)_
- OK — PrimaryFocusMemory.selectLever exists, is a pure static, already receives the CoachingProfile, and does NOT consult biggestChallenge
    _Noum/PrimaryFocusMemory.swift:1157 `private static func selectLever(profile: CoachingProfile?, baseline: CommunicationBaseline, trends: [SkillTrend]) -> LeverSelection?`. Branches at :1162 (strongest trend), :1170 (persistent blocker), :1179 (profile?.speakingStyleGoal), :1187 return nil. biggestChallenge appears NOWHERE in this function — confirms the gap. There is NO separate `resolve()` function (grep empty); the prompt's 'selectLever/resolve' = selectLever + the build-time resolution at :997-1004._
- OK — LeverSelection (the selectLever return) carries area/confidence/basis — extensible to carry concordance source
    _Noum/PrimaryFocusMemory.swift:1151-1155 `private struct LeverSelection { let area: SkillArea; let confidence: TrendConfidence?; let basis: String }`. Constructed at :1163/:1172/:1180._
- OK — CoachMemory is the durable struct that carries currentLever and is the only object reaching coachCaseFormulationLines (which does NOT receive profile) — so concordance MUST be a field on CoachMemory
    _Noum/PrimaryFocusMemory.swift:625 `struct CoachMemory: Codable, Equatable`; currentLever at :632, currentLeverConfidence :633, currentLeverBasis :634. coachCaseFormulationLines signature `(memory: CoachMemory)` at :2206 — no profile param, confirming the read must be precomputed onto memory._
- OK — CoachMemory already follows a strict additive-field pattern: defaulted memberwise init arg + CodingKeys case + decodeIfPresent — the exact template for two new bounded fields
    _Noum/PrimaryFocusMemory.swift memberwise init :694-758 (every optional defaulted, e.g. isLatestSessionPersonalBest: Bool? = nil :725); CodingKeys :763-777; init(from:) :779-812 uses decodeIfPresent for every optional (e.g. :811). New fields slot in identically._
- OK — CoachMemoryGoalFit is the precise precedent for a small enum flag computed in build and rendered in context lines — to be mirrored by the concordance enum
    _Noum/PrimaryFocusMemory.swift:66-71 `enum CoachMemoryGoalFit: String, Codable, Equatable { case aligned; case offGoal; case noVoice; case noLever }`; computed inline in build at :1000-1004 via `voice.aligns(with: currentLever)`; rendered in coachCaseFormulationLines :2236-2243. This is the exact shape/flow my concordance enum copies._
- OK — baseline.overallConfidence and the isReliable bar (>= .moderate) exist and are the gate the roadmap names
    _Noum/BaselineEngine.swift:211 `var overallConfidence: BaselineConfidence { BaselineConfidence.from(sessionCount: qualifyingSessionCount) }`; BaselineConfidence enum :101-106 (.insufficient=0 .tentative=1 .moderate=2 .established=3 .stable=4); :132 `var isReliable: Bool { self >= .moderate }`. CommunicationBaseline.empty has qualifyingSessionCount:0 (BaselineEngine.swift:308+) => .insufficient < .tentative (the day-zero path)._
- OK — CoachContextBuilder.coachCaseFormulationLines is the LLM-facing CASE FORMULATION surface (feeds chat coach AND post-rep note generation)
    _Noum/CoachContextBuilder.swift:2206 coachCaseFormulationLines; renders currentLever lines at :2210-2244; called from caseLines at :458. userContext signature receives profile at :225 (available if a future render needs it, but the case-formulation helper takes memory only)._
- OK — CaseReviewCard is the on-screen durable 'Your Coach's Read' card that renders currentLever — the second coherence surface
    _Noum/CaseReviewCard.swift:20 `struct CaseReviewCard: View { let memory: CoachMemory }`; renders lever at :39-45 (`Current focus: <lever>`) and adaptation/transfer rows. Design header :10-18 ('coach's notebook, not a dashboard')._
- OK — CoachReadCard is the post-rep surface named by the roadmap; it consumes a PostRepCoachNote (LLM-generated), NOT currentLever directly — so it inherits the read through the CoachContextBuilder context, not a direct field read
    _Noum/CoachReadCard.swift:29-31 `struct CoachReadCard: View { let note: PostRepCoachNote }`. No currentLever read in body. The concordance read reaches it via the shared CoachContextBuilder CASE FORMULATION lines that ground note generation. Documented so the coach voice stays coherent without a parallel render path._
- OK — CoachMemoryEngine.build is the single resolution site and its test fixtures call it as CoachMemoryEngine.build(...); a defaulted profile helper hardcodes biggestChallenge:.fillerWords
    _Noum/PrimaryFocusMemory.swift:969 `enum CoachMemoryEngine`; build at :970-985 (selectLever called :997, goalFit computed :1000-1004). Tests: CoachMemoryEngineTests suite NoumTests.swift:10545; build calls e.g. :10576; private profile(voice:) at :11573 sets `biggestChallenge: .fillerWords` (:11578); makeProfile(challenge:) at :2820 allows overriding._
- OK — ORDERING HAZARD (real, must be handled): the existing test lowConfidenceTrendFallsBackToVoiceGoal asserts currentLever==.confidence with baseline:.empty and profile(voice:.authoritative). Inserting a stated-challenge branch BEFORE the voice branch changes the lever to .fillerReduction (because the helper hardcodes biggestChallenge:.fillerWords -> .reduceFillers -> .fillerReduction), breaking that test.
    _NoumTests.swift:10642 lowConfidenceTrendFallsBackToVoiceGoal: baseline .empty, profile(voice:.authoritative) (helper :11573 forces biggestChallenge:.fillerWords), asserts :10662 currentLever==.confidence, :10663 confidence==nil, :10664 basis contains 'stated voice goal'. The new stated-challenge branch must sit ABOVE the voice branch (a stated challenge is a stronger day-zero signal than a style preference), which requires updating this test's expectation to .fillerReduction + a 'you told me' basis. Flagged as a required test edit, not a silent break._
- OK — No symbol collision for any proposed concordance name
    _grep -rni 'concordan|statedChallengeLever|challengeLever|isConcordant|reconcil' across Noum/*.swift, root *.swift, NoumTests.swift returns nothing. Names are free._
- OK — Initiative #1 slice (the mirror target) is present and bounded exactly where the prompt said
    _RecommendationAdaptationAnalyzer enum Noum/PracticeSupport.swift:6320 + RecommendationAdaptationVerdict struct :6297; NextActionEngine.swift recommendationOutcomes field :113, shouldDeferReinforcement :256 used at :193; RecommendationAdaptationAnalyzerTests suite NoumTests.swift:10273-10544. Confirms the shape/discipline to mirror._
## New types / fields

// ── 1. New enum in Noum/PrimaryFocusMemory.swift, beside CoachMemoryGoalFit (after :71) ──
// Mirrors CoachMemoryGoalFit exactly: String/Codable/Equatable, small bounded case set.
// Three-state read so the surfaces can render confirm / diverge / not-yet-comparable distinctly.
enum CoachLeverConcordance: String, Codable, Equatable {
    case concordant        // telemetry reliable AND its lever == stated-challenge lever (a CONFIRM, not a louder claim)
    case divergent         // telemetry reliable AND its lever != stated-challenge lever (surfaces a QUESTION, never an auto-flip)
    case statedOnly        // stated challenge supplied the lever (telemetry below isReliable): tentative "you told me X"
    case notApplicable     // no stated challenge, or telemetry-led lever with no stated challenge to compare
}

// ── 2. Two new fields on CoachMemory (Noum/PrimaryFocusMemory.swift, struct at :625) ──
// Bounded (enum + single optional SkillArea), decode-safe, defaulted for back-compat — same
// contract as every momentum field (:687-690) and goalFit. The stored currentLever is UNCHANGED
// by this field; concordance is an annotation ON the existing lever, never a replacement of it.
var leverConcordance: CoachLeverConcordance = .notApplicable   // defaulted (NOT optional) so older memories decode to a safe neutral
var statedChallengeLever: SkillArea?                            // the SkillArea the stated challenge maps to; nil when no profile/challenge. Bounded by the SkillArea enum.

// Memberwise init (Noum/PrimaryFocusMemory.swift:694): add defaulted args + assignments
//   leverConcordance: CoachLeverConcordance = .notApplicable,
//   statedChallengeLever: SkillArea? = nil,
//   ... self.leverConcordance = leverConcordance ; self.statedChallengeLever = statedChallengeLever
// CodingKeys (:763): add `case leverConcordance, statedChallengeLever`
// init(from:) (:779): 
//   leverConcordance = try c.decodeIfPresent(CoachLeverConcordance.self, forKey: .leverConcordance) ?? .notApplicable
//   statedChallengeLever = try c.decodeIfPresent(SkillArea.self, forKey: .statedChallengeLever)

// ── 3. Extend LeverSelection (Noum/PrimaryFocusMemory.swift:1151) with a source discriminator ──
// So build() can tell a stated-challenge-sourced lever apart from a trend/blocker/voice one
// without string-sniffing the basis. Defaulted for the existing 3 construction sites.
private struct LeverSelection {
    let area: SkillArea
    let confidence: TrendConfidence?
    let basis: String
    var fromStatedChallenge: Bool = false   // true only for the new stated-challenge fallback branch
}

// ── 4. Pure mapping helper (Noum/PrimaryFocusMemory.swift, private static beside skillArea(fromBlocker:) :1556) ──
// Composes TWO shipped maps — NOT a fresh hand-written table. Total function, unit-testable off-main-actor.
private static func skillArea(forStatedChallenge challenge: SpeakingChallenge) -> SkillArea {
    // challenge.recommendedPriority is CoachingPriority (PracticeSupport.swift:411);
    // ForwardPlanService.skillAreaForAIWeek bridges CoachingPriority -> SkillArea (ForwardPlanService.swift:565).
    ForwardPlanService.skillAreaForAIWeek(focus: challenge.recommendedPriority)
}
// Resulting map (asserted in tests): fillerWords->.fillerReduction, rambling->.conciseSpeaking,
// freezing->.confidence, rushing->.pauseUsage.

// ── 5. Concordance computation (pure, inside CoachMemoryEngine.build, after currentLever resolves ~:999) ──
// Mirrors the inline goalFit computation at :1000-1004. NO new thresholds invented — reuses
// baseline.overallConfidence.isReliable (BaselineEngine.swift:132, >= .moderate) as the single named bar.
let statedChallengeLever: SkillArea? = profile.map { Self.skillArea(forStatedChallenge: $0.biggestChallenge) }
let leverConcordance: CoachLeverConcordance = {
    guard let statedChallengeLever, let currentLever else { return .notApplicable }
    if lever?.fromStatedChallenge == true { return .statedOnly }          // the lever IS the stated challenge (telemetry not yet reliable)
    guard baseline.overallConfidence.isReliable else { return .statedOnly } // telemetry-led but still below the reliable bar -> stay tentative
    return currentLever == statedChallengeLever ? .concordant : .divergent  // reliable telemetry: confirm or diverge
}()

## Wiring edits

- **Noum/PrimaryFocusMemory.swift** @ after CoachMemoryGoalFit enum (:71) — Add `enum CoachLeverConcordance: String, Codable, Equatable` (4 cases). Mirrors CoachMemoryGoalFit shape exactly.
- **Noum/PrimaryFocusMemory.swift** @ private struct LeverSelection (:1151-1155) — Add `var fromStatedChallenge: Bool = false`. Defaulted, so the 3 existing constructors (:1163,:1172,:1180) compile unchanged.
- **Noum/PrimaryFocusMemory.swift** @ selectLever fallback chain (:1179, BEFORE the speakingStyleGoal branch) — Insert a stated-challenge branch ABOVE the voice branch: `if let challenge = profile?.biggestChallenge { return LeverSelection(area: skillArea(forStatedChallenge: challenge), confidence: nil, basis: "stated challenge while evidence is still forming", fromStatedChallenge: true) }`. Rationale for ordering: a user's explicitly stated challenge is a stronger day-zero diagnostic anchor than a style-voice preference (which is an aspiration, not a problem report); the coach-lens 'what would a coach do' favours the stated problem. This makes the voice branch the final pre-nil fallback (still reached when profile is nil). NOTE: trend (:1162) and persistentBlocker (:1170) branches remain ABOVE this — real telemetry always outranks self-report, preserving the evidence-led contract.
- **Noum/PrimaryFocusMemory.swift** @ private static helper beside skillArea(fromBlocker:) (:1556) — Add `skillArea(forStatedChallenge:)` composing challenge.recommendedPriority -> ForwardPlanService.skillAreaForAIWeek. No fresh table.
- **Noum/PrimaryFocusMemory.swift** @ CoachMemoryEngine.build, immediately after `let currentLever = lever?.area` (:999) and the goalFit closure (:1000-1004) — Compute `statedChallengeLever` and `leverConcordance` (see newTypesOrFields #5), mirroring the inline goalFit pattern.
- **Noum/PrimaryFocusMemory.swift** @ the CoachMemory(...) construction inside build (currently :1095-1124, the call that sets currentLever/goalFit) — Pass `leverConcordance: leverConcordance, statedChallengeLever: statedChallengeLever` to the initializer alongside the existing currentLever/goalFit args.
- **Noum/PrimaryFocusMemory.swift** @ CoachMemory memberwise init (:694-758), CodingKeys (:763-777), init(from:) (:779-812) — Add the two fields per newTypesOrFields #2 — defaulted init args + assignments, CodingKeys cases, decodeIfPresent (leverConcordance defaults to .notApplicable when absent). Pure additive, all existing call sites + persisted blobs decode.
- **Noum/CoachContextBuilder.swift** @ coachCaseFormulationLines, inside the `if let currentLever` block, after the goalFit switch (:2244) and before the closing brace (:2245) — Append the concordance read line(s) from memory ONLY (no profile needed). statedOnly -> one tentative line: `- Diagnosis source: this focus comes from what you told me (you flagged <stated challenge title>); it is your stated read, not yet confirmed by your reps.` concordant -> one confirming line: `- Diagnosis agreement: your reps line up with what you told me — the measured focus (<lever>) matches the challenge you flagged. Reinforce, do not re-litigate.` divergent -> a QUESTION, never a switch: `- Diagnosis divergence (ASK, do not assert): you flagged <stated challenge>, but your reps point more at <lever>. Ask the user whether that fits before treating <lever> as the named focus; do not silently override their stated challenge.` notApplicable -> emit nothing (append-and-omit, mirroring the goalFit .noVoice/.noLever break at :2241).
- **Noum/CaseReviewCard.swift** @ in body, after the lever/hypothesis caseRow (after :45) and before the activeIntervention row (:48) — Render ONE compact concordance row (the same read, on-screen) ONLY for .concordant / .divergent / .statedOnly; .notApplicable shows nothing (consistent with the card's 'insufficient evidence shows nothing' rule, :13). statedOnly label 'Your stated read' text 'From what you told me — your reps haven't weighed in yet.'; concordant label 'Agreement' text 'Your reps line up with what you flagged.'; divergent label 'Worth a check' text 'Your reps point somewhere slightly different — open Ask Noum.' Keep to the existing caseRow(icon:label:text:) helper and the 5-section budget (the design header caps at five sections; fold this into the hypothesis section visually if needed).
- **Noum/PrimaryFocusMemory.swift OR Noum/CoachContextBuilder.swift** @ a small computed-copy helper next to coachCaseFormulationLines, or static methods on CoachLeverConcordance — Put the concordance copy strings behind named functions (e.g. `CoachLeverConcordance.contextLine(lever:statedChallengeTitle:)`) so the LLM-context line and the on-screen card render the SAME judgment wording (coach-lens: one read, identical everywhere). This is the single source of the concordance sentence.
- **NoumTests/NoumTests.swift** @ lowConfidenceTrendFallsBackToVoiceGoal (:10642-10665) — REQUIRED test update (not optional): because the stated-challenge branch now sits above the voice branch and profile(voice:) hardcodes biggestChallenge:.fillerWords, this build now returns .fillerReduction with a 'stated challenge' basis and .statedOnly concordance. Update assertions to currentLever==.fillerReduction, currentLeverBasis contains 'stated challenge', leverConcordance==.statedOnly. Add a SEPARATE test that nils the profile (or uses a profile with no telemetry) to keep coverage of the pure voice-goal fallback path -> .confidence. Flagged here so the change is explicit, never a silent break.

## Evidence & copy model

FLOOR (the honest floor, association never causation):
- Stated challenge alone is SELF-REPORT, never a diagnosis. When baseline.overallConfidence < .isReliable (i.e. < .moderate, BaselineEngine.swift:132) the lever it produces is explicitly tentative: copy MUST say 'you told me' / 'your stated read' / 'not yet confirmed by your reps'. It is surfaced as the working lever (so day-zero users still get a grounded focus instead of generic .structure) but flagged .statedOnly so no surface implies it is measured.
- CONFIRM (strengthen) only when BOTH (a) baseline.overallConfidence.isReliable AND (b) the telemetry-led lever (trend/blocker branch, which already outranks self-report in selectLever) EQUALS the stated-challenge lever. Then .concordant: copy is a CONFIRMATION ('your reps line up with what you told me'), explicitly NOT a louder or causal claim. Agreement raises trust, not certainty-of-mechanism.
- DIVERGENCE never auto-flips. When telemetry is reliable but its lever != stated lever, the stored currentLever stays whatever selectLever already chose (telemetry wins the lever, per existing precedence) and concordance=.divergent emits a QUESTION for the user ('you flagged X, but your reps point at Y — does that fit?'). The named focus does not change on the user's behalf; only the user's confirm/reject can. This honors hypotheses-not-facts and the roadmap's 'no silent focus switches' guardrail.
ASSOCIATION-NOT-CAUSATION COPY RULES: every line is comparative/observational — 'line up with', 'point at', 'matches', 'comes from what you told me'. BANNED tokens in all concordance copy: 'caused', 'because', 'proves', 'guarantee', 'failed', 'diagnosis confirmed', 'definitely'. The divergence line is framed as an open question, never a verdict about the user.
WHAT STAYS UNPERSISTED / NEUTRAL: leverConcordance defaults to .notApplicable and is computed fresh every build (like goalFit) — it is a derived annotation, not an independent persisted truth. statedChallengeLever is stored only to let surfaces name the comparison; it never replaces currentLever. No new threshold constant is introduced — the ONLY gate is the existing, named baseline.overallConfidence.isReliable bar, reused verbatim (the same isReliable used across BaselineEngine), satisfying 'named, test-asserted thresholds'.

## Coherence surfaces (coach-lens: one read everywhere)

The single concordance judgment (computed once in CoachMemoryEngine.build, stored on CoachMemory.leverConcordance + statedChallengeLever) must read IDENTICALLY on every surface where the coach speaks the focus — the coach-lens 'one coherent read across every surface' principle, exactly as initiative #1 surfaced its verdict on all three coaching surfaces:
1. CHAT COACH (LLM) — via Noum/CoachContextBuilder.swift coachCaseFormulationLines (:2244 append) inside the CASE FORMULATION block. statedOnly/concordant/divergent each emit the matching line; notApplicable emits nothing. This is what makes the conversational coach say 'you told me X and your reps back it up' vs 'you flagged X but the data points at Y — does that fit?'.
2. POST-REP NOTE — Noum/CoachReadCard.swift renders a PostRepCoachNote (:31) that is generated from the SAME CoachContextBuilder context, so it inherits the concordance read with no parallel field path (documented, no second source of truth).
3. ON-SCREEN CASE FILE — Noum/CaseReviewCard.swift ('Your Coach's Read', :20) renders a compact concordance row from memory.leverConcordance, using the SAME copy strings as the context line (shared helper). The user sees the same agreement/divergence judgment the coach speaks.
4. (Reachability, no new render) The forward plan / next-practice surfaces continue to read currentLever; because the stored lever is unchanged on divergence, those surfaces never contradict the question the coach is asking. They stay coherent by construction.
ENFORCEMENT OF COHERENCE: the concordance sentence lives behind ONE named copy helper (CoachLeverConcordance.contextLine(...) or equivalent) consumed by both the LLM-context builder and the SwiftUI card, so the judgment cannot drift between surfaces. A test asserts the card copy and the context line derive from the same concordance case.

## Test matrix

- **statedChallengeMapsToSkillArea_allFourCases** — asserts: fillerWords->.fillerReduction; rambling->.conciseSpeaking; freezing->.confidence; rushing->.pauseUsage. Locks the recommendedPriority∘skillAreaForAIWeek composition (PracticeSupport.swift:411 + ForwardPlanService.swift:565).
- **dayZero_noTelemetry_statedChallengeBecomesTentativeLever** — asserts: currentLever==.confidence (from .freezing, NOT the voice's .paceControl); currentLeverConfidence==nil; currentLeverBasis contains 'stated challenge'; leverConcordance==.statedOnly; statedChallengeLever==.confidence.
- **updatedExisting_lowConfidenceTrendFallsBackToVoiceGoal_REQUIRESEDIT** — asserts: AFTER edit: currentLever==.fillerReduction (stated challenge now precedes voice), basis contains 'stated challenge', leverConcordance==.statedOnly. Documents the deliberate precedence change.
- **noProfile_voiceGoalPathStillReached** — asserts: profile=nil -> currentLever==nil (or trend/blocker if present); leverConcordance==.notApplicable. Keeps coverage of the non-challenge fallback the old test guarded.
- **reliableTelemetryAgreesWithStatedChallenge_concordant** — asserts: currentLever==.fillerReduction (trend wins the lever); leverConcordance==.concordant; statedChallengeLever==.fillerReduction; context line contains 'line up' / 'matches', NOT 'caused'/'proves'.
- **reliableTelemetryDivergesFromStatedChallenge_divergent_noAutoFlip** — asserts: currentLever==.fillerReduction (UNCHANGED — telemetry lever is NOT overridden by stated challenge); statedChallengeLever==.conciseSpeaking; leverConcordance==.divergent; context line is phrased as a QUESTION ('does that fit'/'ask') and does NOT change the focus.
- **telemetryBelowReliableBar_evenIfTrendLed_staysStatedOnly_notConcordant** — asserts: leverConcordance==.statedOnly (never .concordant/.divergent below the isReliable bar — agreement/divergence is a reliable-evidence-only claim). Locks the floor.
- **decodeSafety_legacyMemoryWithoutConcordanceKeys** — asserts: Decodes without throwing; leverConcordance==.notApplicable; statedChallengeLever==nil. Locks back-compat for the defaulted-non-optional enum + optional SkillArea.
- **concordanceCopy_noCausalLanguage_everyEmittingCase** — asserts: each non-empty; none contains {caused, because, proves, guarantee, failed, definitely}; divergent contains a question marker ('?' or 'ask'/'does that fit'); .notApplicable yields empty (append-and-omit).
- **surfaceCoherence_cardAndContextShareJudgment** — asserts: both are non-empty for the same case and both reflect the same CoachLeverConcordance value (not contradictory) — proves the single-source copy helper. Covers the coach-lens invariant.
- **notApplicable_whenNoCurrentLever** — asserts: leverConcordance==.notApplicable; no concordance line emitted on either surface.
- **statedOnly_lever_doesNotMarkConcordantWithItself** — asserts: leverConcordance==.statedOnly, NOT .concordant — a stated-challenge lever cannot 'agree with itself'; agreement requires an independent reliable telemetry signal. Guards against a false-confidence self-confirmation bug.

## Risks

SELF-REPORT BIAS RE-ENTRY (primary, named in roadmap): the stated challenge must never confirm a focus alone and never override reliable telemetry. Mitigation: it sits BELOW trend+blocker in selectLever (telemetry always wins the lever); .concordant requires an independent reliable signal (test statedOnly_lever_doesNotMarkConcordantWithItself); divergence emits a question, never a flip. 
PRECEDENCE TEST BREAK (certain, not a risk but a required edit): lowConfidenceTrendFallsBackToVoiceGoal changes meaning. Mitigation: explicit test update + a new no-profile test preserving voice-fallback coverage — flagged in wiringEdits so it is never silent. 
COPY OVERCLAIM: an agreement line could read as 'your problem is confirmed/caused'. Mitigation: association-only copy, banned-token test, agreement framed as trust ('reps line up'), divergence as a question. 
SURFACE DRIFT: the chat coach and the card could phrase the judgment differently and feel like two coaches. Mitigation: one named copy helper as the single source; coherence test. 
CARD DENSITY: CaseReviewCard caps at 5 sections (design header :13-18). Mitigation: fold the concordance into the hypothesis section / show only the three meaningful cases, never .notApplicable. 
ORDERING SUBTLETY: placing stated-challenge above voice is a judgment call (a stated problem outranks a style aspiration). It is defensible by coach-lens but is a behavioral change to day-zero focus for users whose challenge and voice diverge; called out as an open question for product sign-off.

## Open questions

- selectLever precedence: confirm stated-challenge fallback should sit ABOVE the speakingStyleGoal branch (a stated problem outranks a style aspiration) vs BELOW it. The spec recommends above (coach-lens), but this changes day-zero focus for users whose challenge != voice and requires updating lowConfidenceTrendFallsBackToVoiceGoal. Product sign-off needed.
- CaseReviewCard already enforces a 5-section budget; confirm whether the concordance read gets its own row or folds into the existing hypothesis/lever row to respect the 'coach's notebook, not a dashboard' constraint.
- Divergence question wording: should the chat-coach divergence line proactively prompt the user every turn until resolved, or surface once and then go quiet (to avoid nagging)? An ack mechanism analogous to CoachHypothesisAcknowledgement (PrimaryFocusMemory.swift:657) could persist the user's confirm/reject — but that is arguably a follow-up initiative, not this slice. Confirm scope.
- Should a user CONFIRMING the divergence question (telemetry lever) or REJECTING it (keeping stated challenge) be persisted to influence the next selectLever, or stay ephemeral? Persisting it would re-touch the lever-selection precedence and likely belongs in a paired adaptation-log entry — out of scope here unless requested.
- ForwardPlanService.skillAreaForAIWeek maps .calmerDelivery->.pauseUsage and .thinkFaster->.confidence; confirm these are the intended SkillArea targets for 'rushing' and 'freezing' challenges respectively (they are the only shipped CoachingPriority->SkillArea bridge, but a coach might map 'rushing'->.paceControl rather than .pauseUsage). If a different target is wanted, a small explicit SpeakingChallenge->SkillArea table is the alternative — at the cost of not reusing a shipped map.

