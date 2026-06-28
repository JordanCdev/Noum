//
//  CoachReadCalibrationBaselineTests.swift
//  NoumTests
//
//  COACH-READ CALIBRATION SUBSTRATE (validation substrate — NOT validation).
//
//  Every prior coach-parity run names the same #1 ceiling-blocker: the
//  deterministic judgement layer (`CoachReasoningPass.assess`) scores rubric
//  dimensions, confidence, and overall verdicts with HEURISTICS that have never
//  been pinned against an expert-coach baseline across a SPREAD of situations.
//  That is precisely why `CoachParityReadiness` stays structurally `.forming`
//  (it cannot self-certify a scoring engine it has never calibrated), and why
//  `docs/VISION.md`'s top "high-leverage next product move" is:
//  "Build a version-controlled evaluation set and compare Noum reads to expert
//   coach baselines. Label this 'validation substrate', not validation."
//
//  This suite IS that substrate. Each fixture is a concrete user-trajectory
//  INPUT plus the EXPERT-ACCEPTABLE BAND a competent human communications coach
//  would require of the read. The scenarios were authored by five role lenses
//  (veteran coach, skeptical end-user, market/competitor analyst, UX-honesty
//  auditor, Swift/QA) and then adversarially screened: each band must be FAIR
//  (a coach would genuinely require it, not stricter), EXPRESSIBLE against the
//  real `CoachAssessment` contract, and NON-TAUTOLOGICAL (it can actually fail).
//  Two authored scenarios were rejected at screening for being tautological or
//  numerically inconsistent with the real thresholds; the surviving 15 span
//  coverage 0.22 -> 0.82, the 0.35 abstention boundary, the 175-WPM pacing flip,
//  pressure-proven vs. unproven goals, and all four turn depths on both surfaces.
//
//  WHAT THIS LOCKS (the honesty laws that make Noum coach-like, not a dashboard):
//   - Thin evidence (coverage < 0.35) forces an explicit ABSTENTION, never a
//     "you're close" — however clean the single rep.
//   - One strong rep never reads as overall goal closeness (goalReadiness is
//     structurally capped at evidence coverage).
//   - Pressure proof is always named missing until it exists, even at high
//     coverage — a clean normal rep does not prove authority under stakes.
//   - Genuine, repeated, pressure-proven evidence IS rewarded ("approaching the
//     standard") — the engine is honest, not uselessly pessimistic.
//   - Confidence stays inside coach-acceptable bounds (no fake certainty; no
//     uselessly flat reads).
//
//  HOW TO EXTEND: add a Scenario with its expert Band. A green run means the
//  heuristic still lands inside the expert band for that case; a red run is a
//  real CALIBRATION GAP to triage (fix the heuristic, or, if the band was wrong,
//  correct it with a comment). See docs/COACH_READ_CALIBRATION_SUBSTRATE.md.
//

import Foundation
import Testing
@testable import Noum

@Suite("CoachReadCalibrationBaselineTests")
struct CoachReadCalibrationBaselineTests {

    struct Band: Sendable {
        var mustAbstain: Bool
        var verdictForbidden: [String]
        var requiredMissing: [String]
        var confidenceMax: Double?
        var confidenceMin: Double?
        var immediateReadContains: [String]
        var responseMode: CoachAssessment.ResponseMode?
    }

    struct Scenario: Sendable, CustomTestStringConvertible {
        var id: String
        var lens: String
        var pins: String
        var question: String
        var depth: CoachTurnDepth
        var surface: CoachReplySurface
        var snapshot: UserTrajectorySnapshot
        var band: Band
        var testDescription: String { "\(id) [\(lens)]" }
    }

    private static let rubric = ActiveGoalRubric(
        rubric: GoalRubricStore.rubric(for: .authoritative),
        voice: .authoritative
    )

    static let scenarios: [Scenario] = [
        Scenario(
            id: "first-rep-new-client-thin-evidence",
            lens: "coach-expert",
            pins: "Pins the honest-abstention invariant: coverage 0.24 (<0.35) MUST return the abstention verdict, and confidence MUST stay low. A sloppy heuristic that reads a 7/10 rep and says 'you",
            question: "Be honest, how far off am I from sounding authoritative?",
            depth: .deepAssessment,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 1,
                ratedSessionCount: 1,
                evidenceCoverage: 0.24,
                recentSessionLines: ["Timed: 7/10, 1 fillers, 60s"],
                trendLines: [],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Timed",
                score: 7,
                fillerCount: 1,
                durationSeconds: 60,
                wordsPerMinute: 145,
                transcriptWordCount: 64,
                transcriptExcerpt: "My recommendation is to prioritize the launch because the team needs one decision this week",
                evidenceLines: ["latest rep: Timed, 7/10, 1 fillers, 60s", "pace estimate: 145 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: true,
                verdictForbidden: ["close", "approaching", "not far off", "ready", "closer mechanically"],
                requiredMissing: ["repeated", "pressure"],
                confidenceMax: 0.45,
                confidenceMin: 0.2,
                immediateReadContains: [],
                responseMode: .expandable
            )
        ),
        Scenario(
            id: "mechanics-clean-but-goal-unproven",
            lens: "coach-expert",
            pins: "Pins the mechanics-vs-goal-readiness distinction — the most valuable thing a coach says: 'your technique is landing but you haven't proven it where it counts.' Requires the 'closer",
            question: "How close am I to my authoritative goal overall?",
            depth: .deepAssessment,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 6,
                ratedSessionCount: 6,
                evidenceCoverage: 0.55,
                recentSessionLines: ["Practice: 8/10, 0 fillers, 70s", "Practice: 7/10, 1 fillers, 65s", "Practice: 8/10, 1 fillers, 72s"],
                trendLines: ["filler rate trending down over last 3 reps"],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Practice",
                score: 8,
                fillerCount: 0,
                durationSeconds: 70,
                wordsPerMinute: 150,
                transcriptWordCount: 90,
                transcriptExcerpt: "My recommendation is we ship friday because the data is clear and that is the decision",
                evidenceLines: ["latest rep: Practice, 8/10, 0 fillers, 70s", "pace estimate: 150 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["approaching", "ready for real stakes", "not far off"],
                requiredMissing: ["repeated", "pressure"],
                confidenceMax: 0.62,
                confidenceMin: 0.45,
                immediateReadContains: [],
                responseMode: .expandable
            )
        ),
        Scenario(
            id: "earned-approaching-repeated-pressure-proven",
            lens: "coach-expert",
            pins: "The positive-calibration case a real coach DOES eventually reach. Rewards GENUINE repeated + pressure-proven evidence by allowing the 'approaching' verdict. Tests that the suite is",
            question: "Realistically, how far off am I from the authoritative standard now?",
            depth: .deepAssessment,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 16,
                ratedSessionCount: 15,
                evidenceCoverage: 0.82,
                recentSessionLines: ["Pressure mode: 8/10, 0 fillers, 80s, sudden-prompt", "Pressure mode: 9/10, 1 fillers, 75s", "Timed: 8/10, 0 fillers, 70s, ah-counter steady"],
                trendLines: ["stable scores across 4 pressure reps", "fillers do not spike under pressure"],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Pressure",
                score: 9,
                fillerCount: 0,
                durationSeconds: 78,
                wordsPerMinute: 150,
                transcriptWordCount: 110,
                transcriptExcerpt: "My recommendation is to consolidate the two teams because it removes the handoff that is costing us a week and that is the decision i would make",
                evidenceLines: ["latest rep: Pressure, 9/10, 0 fillers, 78s", "pace estimate: 150 WPM", "stable under sudden-prompt"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["enough evidence", "do not have enough", "ready for real stakes", "fully there", "done"],
                requiredMissing: [],
                confidenceMax: 0.82,
                confidenceMin: 0.62,
                immediateReadContains: [],
                responseMode: .expandable
            )
        ),
        Scenario(
            id: "single-good-rep-not-overall-closeness",
            lens: "coach-expert",
            pins: "Pins the never-overclaim-on-one-good-rep invariant under the trickier mid-coverage case (0.50, above the 0.35 abstention floor but below 0.70). A 9/10 single rep must NOT produce '",
            question: "That rep felt great — am I basically there on my goal now?",
            depth: .deepAssessment,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 3,
                ratedSessionCount: 2,
                evidenceCoverage: 0.5,
                recentSessionLines: ["Practice: 9/10, 0 fillers, 75s", "Practice: 5/10, 3 fillers, 50s"],
                trendLines: ["one strong rep, one weak rep — high variance"],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Practice",
                score: 9,
                fillerCount: 0,
                durationSeconds: 75,
                wordsPerMinute: 148,
                transcriptWordCount: 95,
                transcriptExcerpt: "My recommendation is we hire the senior engineer because velocity is the bottleneck and that is the answer",
                evidenceLines: ["latest rep: Practice, 9/10, 0 fillers, 75s", "pace estimate: 148 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["approaching", "basically there", "close overall", "ready", "not far off"],
                requiredMissing: ["repeated", "pressure"],
                confidenceMax: 0.62,
                confidenceMin: 0.4,
                immediateReadContains: [],
                responseMode: .expandable
            )
        ),
        Scenario(
            id: "live-trust-repair-pushback",
            lens: "coach-expert",
            pins: "Tests two things at once: trustRepair must produce the repair-framed verdict (acknowledge before advising) and still attach missingEvidence including a pressure line, and the LIVE ",
            question: "That feedback was useless and missed the point entirely.",
            depth: .trustRepair,
            surface: .live,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 5,
                ratedSessionCount: 5,
                evidenceCoverage: 0.6,
                recentSessionLines: ["Practice: 7/10, 2 fillers, 60s", "Practice: 6/10, 2 fillers, 58s"],
                trendLines: ["scores flat over last 2 reps"],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Practice",
                score: 7,
                fillerCount: 2,
                durationSeconds: 60,
                wordsPerMinute: 160,
                transcriptWordCount: 80,
                transcriptExcerpt: "i think we should maybe just go with the second option so",
                evidenceLines: ["latest rep: Practice, 7/10, 2 fillers, 60s", "pace estimate: 160 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["close", "approaching", "ready", "enough evidence"],
                requiredMissing: ["pressure"],
                confidenceMax: 0.72,
                confidenceMin: 0.5,
                immediateReadContains: [],
                responseMode: .immediateOnly
            )
        ),
        Scenario(
            id: "single-great-rep-wants-nailed-it",
            lens: "adversarial-end-user",
            pins: "Pins the core honesty invariant: a single excellent rep must trigger coverage<0.35 honest abstention, never an overall-closeness verdict, no matter how clean the transcript reads.",
            question: "Be honest, how far off am I from sounding authoritative overall?",
            depth: .deepAssessment,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 1,
                ratedSessionCount: 1,
                evidenceCoverage: 0.22,
                recentSessionLines: ["Timed: 9/10, 0 fillers, 70s"],
                trendLines: [],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Timed",
                score: 9,
                fillerCount: 0,
                durationSeconds: 70,
                wordsPerMinute: 140,
                transcriptWordCount: 150,
                transcriptExcerpt: "My recommendation is we ship Friday because the team needs one decision, so the answer is yes and I would commit the budget now",
                evidenceLines: ["latest rep: Timed, 9/10, 0 fillers, 70s", "pace estimate: 140 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: true,
                verdictForbidden: ["close", "approaching", "not far off", "ready", "nailed", "there"],
                requiredMissing: ["repeated", "pressure"],
                confidenceMax: 0.45,
                confidenceMin: 0.2,
                immediateReadContains: [],
                responseMode: .expandable
            )
        ),
        Scenario(
            id: "high-coverage-zero-pressure-proof",
            lens: "adversarial-end-user",
            pins: "Pins 'pressure must be proven before ready for real stakes': high coverage + clean mechanics must still refuse a 'ready' verdict and must surface the missing pressure proof, becaus",
            question: "Am I close to my authoritative goal now overall?",
            depth: .deepAssessment,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 14,
                ratedSessionCount: 14,
                evidenceCoverage: 0.82,
                recentSessionLines: ["Free practice: 8/10, 1 filler, 65s", "Free practice: 8/10, 0 fillers, 60s", "Daily rep: 9/10, 1 filler, 72s"],
                trendLines: ["fillers trending down over last 10 reps", "scores stable in the 8-9 band"],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Free practice",
                score: 9,
                fillerCount: 0,
                durationSeconds: 72,
                wordsPerMinute: 150,
                transcriptWordCount: 170,
                transcriptExcerpt: "My recommendation is to consolidate the two teams because it removes the duplicate roadmap, so the decision is one owner by Q3 and that is the ask",
                evidenceLines: ["latest rep: Free practice, 9/10, 0 fillers, 72s", "pace estimate: 150 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["ready for real stakes", "proven under pressure", "nailed", "done"],
                requiredMissing: ["pressure"],
                confidenceMax: 0.82,
                confidenceMin: 0.6,
                immediateReadContains: [],
                responseMode: .expandable
            )
        ),
        Scenario(
            id: "quick-move-must-stay-narrow",
            lens: "adversarial-end-user",
            pins: "Pins scope discipline: a quickMove turn must return the fixed narrow next-move string and must NOT drift into an overall goal verdict, even when the trajectory is rich enough to te",
            question: "What should I do next?",
            depth: .quickMove,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 9,
                ratedSessionCount: 9,
                evidenceCoverage: 0.66,
                recentSessionLines: ["Timed: 8/10, 2 fillers, 60s", "Pressure mode: 7/10, 3 fillers, 55s"],
                trendLines: ["fillers up slightly under pressure"],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Pressure mode",
                score: 7,
                fillerCount: 3,
                durationSeconds: 55,
                wordsPerMinute: 182,
                transcriptWordCount: 120,
                transcriptExcerpt: "so i think maybe we should probably look at the timeline and just kind of see where it lands yeah",
                evidenceLines: ["latest rep: Pressure mode, 7/10, 3 fillers, 55s", "pace estimate: 182 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["overall", "your goal", "authoritative standard", "close", "approaching", "ready"],
                requiredMissing: [],
                confidenceMax: 0.72,
                confidenceMin: 0.5,
                immediateReadContains: [],
                responseMode: .immediateOnly
            )
        ),
        Scenario(
            id: "polished-evasive-no-point-mechanically-ahead",
            lens: "market-competitor",
            pins: "Pins the 'closer mechanically than authoritative' branch and the readiness-cannot-exceed-coverage rule. Orai/Yoodli would score the smooth delivery high; a coach must say the mecha",
            question: "How close am I to my authoritative goal overall?",
            depth: .deepAssessment,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 6,
                ratedSessionCount: 6,
                evidenceCoverage: 0.58,
                recentSessionLines: ["Timed: 8/10, 0 fillers, 70s", "Pressure mode: sudden-prompt rep, 7/10, 1 filler"],
                trendLines: ["scores rising across last three reps"],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Timed",
                score: 8,
                fillerCount: 0,
                durationSeconds: 70,
                wordsPerMinute: 150,
                transcriptWordCount: 175,
                transcriptExcerpt: "my recommendation is we ship the launch and we should align the team this week",
                evidenceLines: ["latest rep: Timed, 8/10, 0 fillers, 70s", "pace estimate: 150 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["approaching the authoritative standard", "ready", "not far off"],
                requiredMissing: ["pressure", "repeated evidence"],
                confidenceMax: 0.72,
                confidenceMin: 0.5,
                immediateReadContains: [],
                responseMode: .expandable
            )
        ),
        Scenario(
            id: "slow-pacer-good-coverage-pressure-proven-still-not-there",
            lens: "market-competitor",
            pins: "Pins that low pacing (wpm < 105 -> ~0.48) drags the average so that even with strong coverage and pressure proof the verdict stays at 'useful pieces', not 'approaching'. A dashboar",
            question: "Where do I actually stand on the goal right now?",
            depth: .deepAssessment,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 11,
                ratedSessionCount: 9,
                evidenceCoverage: 0.78,
                recentSessionLines: ["Pressure mode: sudden interruption, 7/10", "Timed: 8/10, 1 filler", "ah-counter rep logged"],
                trendLines: ["consistent scores over nine rated reps", "pace consistently low"],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Timed",
                score: 8,
                fillerCount: 1,
                durationSeconds: 90,
                wordsPerMinute: 92,
                transcriptWordCount: 138,
                transcriptExcerpt: "the decision is to delay because the data is not ready so we should wait",
                evidenceLines: ["latest rep: Timed, 8/10, 1 filler, 90s", "pace estimate: 92 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["approaching the authoritative standard", "ready for real stakes", "closer mechanically than"],
                requiredMissing: ["pressure"],
                confidenceMax: 0.82,
                confidenceMin: 0.6,
                immediateReadContains: [],
                responseMode: .expandable
            )
        ),
        Scenario(
            id: "live-surface-bounded-immediate-read",
            lens: "ux-honesty",
            pins: "Pins the live-surface honesty invariant: the instant local read shown while the model verbalises must still carry the abstention/missing-evidence and a proof test, never a confiden",
            question: "Real talk, am I there yet?",
            depth: .deepAssessment,
            surface: .live,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 2,
                ratedSessionCount: 2,
                evidenceCoverage: 0.3,
                recentSessionLines: ["Timed: 6/10, 3 fillers, 55s"],
                trendLines: [],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Timed",
                score: 6,
                fillerCount: 3,
                durationSeconds: 55,
                wordsPerMinute: 188,
                transcriptWordCount: 70,
                transcriptExcerpt: "i think maybe we should kind of go with the first option so",
                evidenceLines: ["latest rep: Timed, 6/10, 3 fillers, 55s", "pace estimate: 188 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: true,
                verdictForbidden: ["you are there", "close overall", "ready", "almost"],
                requiredMissing: ["repeated evidence", "pressure"],
                confidenceMax: 0.5,
                confidenceMin: 0.2,
                immediateReadContains: ["missing", "proof test"],
                responseMode: .immediateOnly
            )
        ),
        Scenario(
            id: "trust-repair-must-disclose-missing",
            lens: "ux-honesty",
            pins: "Pins that the missing-evidence disclosure rule applies to trustRepair, not just deepAssessment, and that the repair verdict acknowledges the miss rather than re-asserting confidenc",
            question: "That read was useless, you completely missed what I asked.",
            depth: .trustRepair,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 4,
                ratedSessionCount: 3,
                evidenceCoverage: 0.4,
                recentSessionLines: ["Timed: 7/10, 2 fillers, 60s", "Freeform: 6/10, 4 fillers, 90s"],
                trendLines: ["mixed scores, no pressure reps yet"],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Timed",
                score: 7,
                fillerCount: 2,
                durationSeconds: 60,
                wordsPerMinute: 160,
                transcriptWordCount: 72,
                transcriptExcerpt: "the answer is we delay because resourcing is tight and that means q3 not q2",
                evidenceLines: ["latest rep: Timed, 7/10, 2 fillers, 60s", "pace estimate: 160 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["you are close overall", "ready for real stakes", "goal proven"],
                requiredMissing: ["repeated evidence", "pressure"],
                confidenceMax: 0.72,
                confidenceMin: 0.32,
                immediateReadContains: [],
                responseMode: .expandable
            )
        ),
        Scenario(
            id: "coverage-035-abstention-boundary",
            lens: "swift-qa",
            pins: "Locks the coverage<0.35 abstention branch and the readiness<=coverage cap: at exactly 0.35 the function must NOT abstain but must still refuse any closeness claim and name both rep",
            question: "Be honest, how far off am I from sounding authoritative overall?",
            depth: .deepAssessment,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 1,
                ratedSessionCount: 1,
                evidenceCoverage: 0.35,
                recentSessionLines: ["Timed: 8/10, 1 fillers, 60s"],
                trendLines: [],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Timed",
                score: 8,
                fillerCount: 1,
                durationSeconds: 60,
                wordsPerMinute: 150,
                transcriptWordCount: 70,
                transcriptExcerpt: "My recommendation is to ship the launch this week because the team needs one clear decision",
                evidenceLines: ["latest rep: Timed, 8/10, 1 fillers, 60s", "pace estimate: 150 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["close", "not far off", "ready", "approaching"],
                requiredMissing: ["repeated", "pressure"],
                confidenceMax: 0.5,
                confidenceMin: 0.2,
                immediateReadContains: [],
                responseMode: .expandable
            )
        ),
        Scenario(
            id: "approaching-standard-still-needs-pressure",
            lens: "swift-qa",
            pins: "Pins the readiness>=0.72 && coverage>=0.70 branch, the most generous verdict the function can emit. Even here it must say 'still needs pressure proof' and never 'ready for real sta",
            question: "Am I basically at the authoritative standard now?",
            depth: .deepAssessment,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 9,
                ratedSessionCount: 9,
                evidenceCoverage: 0.72,
                recentSessionLines: ["Pressure: 8/10, 1 fillers, 70s sudden-prompt", "Timed: 8/10, 0 fillers, 60s", "Free: 9/10, 0 fillers, 58s"],
                trendLines: ["score trend: stable 8-9 across last 4 reps", "pressure rep logged with ah-counter"],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Pressure",
                score: 9,
                fillerCount: 0,
                durationSeconds: 70,
                wordsPerMinute: 150,
                transcriptWordCount: 90,
                transcriptExcerpt: "My recommendation is to consolidate the two teams because focus matters and that means we ship one roadmap",
                evidenceLines: ["latest rep: Pressure, 9/10, 0 fillers, 70s", "pace estimate: 150 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["ready for real stakes", "you are there", "done", "fully authoritative now"],
                requiredMissing: ["pressure"],
                confidenceMax: 0.82,
                confidenceMin: 0.62,
                immediateReadContains: [],
                responseMode: .expandable
            )
        ),
        Scenario(
            id: "wpm-just-over-175-pacing-flip-guard",
            lens: "swift-qa",
            pins: "Locks the controlled_pacing WPM boundary (105/175) and proves a single-wpm difference at 176 cannot flip the overall verdict toward closeness. Pacing drops to ~0.50 here; combined ",
            question: "How close am I to my authoritative goal?",
            depth: .deepAssessment,
            surface: .text,
            snapshot: UserTrajectorySnapshot(
                generatedAt: Date(timeIntervalSince1970: 1_000),
                sessionCount: 2,
                ratedSessionCount: 2,
                evidenceCoverage: 0.4,
                recentSessionLines: ["Free: 7/10, 2 fillers, 50s"],
                trendLines: [],
                latestRepEvidencePack: LatestRepEvidencePack(
                mode: "Free",
                score: 7,
                fillerCount: 2,
                durationSeconds: 50,
                wordsPerMinute: 176,
                transcriptWordCount: 88,
                transcriptExcerpt: "I would say we should just probably move ahead, kind of, with the plan yeah",
                evidenceLines: ["latest rep: Free, 7/10, 2 fillers, 50s", "pace estimate: 176 WPM"]
            ),
                coachCaseSummary: nil,
                activeInterventionState: nil
            ),
            band: Band(
                mustAbstain: false,
                verdictForbidden: ["close", "approaching", "ready", "not far off"],
                requiredMissing: ["repeated", "pressure"],
                confidenceMax: 0.55,
                confidenceMin: 0.2,
                immediateReadContains: [],
                responseMode: .expandable
            )
        )
    ]

    @Test("Read falls within the expert calibration band", arguments: scenarios)
    func readFallsWithinExpertBand(_ s: Scenario) {
        let assessment = CoachReasoningPass.assess(
            turnDepth: s.depth,
            userQuestion: s.question,
            trajectory: s.snapshot,
            rubric: Self.rubric,
            surface: s.surface
        )
        let verdict = assessment.directVerdict.lowercased()
        let missing = assessment.missingEvidence.joined(separator: " || ").lowercased()

        if s.band.mustAbstain {
            #expect(
                verdict.contains("enough evidence"),
                "\(s.id): coverage \(s.snapshot.evidenceCoverage) should force an honest abstention, got verdict: \(assessment.directVerdict)"
            )
        }
        for forbidden in s.band.verdictForbidden {
            #expect(
                !verdict.contains(forbidden.lowercased()),
                "\(s.id): verdict must NOT overclaim with '\(forbidden)'. Verdict: \(assessment.directVerdict)"
            )
        }
        for needed in s.band.requiredMissing {
            #expect(
                missing.contains(needed.lowercased()),
                "\(s.id): a coach must disclose missing '\(needed)'. missingEvidence: \(assessment.missingEvidence)"
            )
        }
        if let cmax = s.band.confidenceMax {
            #expect(
                assessment.confidence <= cmax + 0.0001,
                "\(s.id): confidence \(assessment.confidence) exceeds the expert ceiling \(cmax) (overclaiming certainty)"
            )
        }
        if let cmin = s.band.confidenceMin {
            #expect(
                assessment.confidence >= cmin - 0.0001,
                "\(s.id): confidence \(assessment.confidence) is below the expert floor \(cmin) (uselessly flat read)"
            )
        }
        let immediate = assessment.immediateCoachRead.lowercased()
        for fragment in s.band.immediateReadContains {
            #expect(
                immediate.contains(fragment.lowercased()),
                "\(s.id): live immediate read must surface '\(fragment)'. Read: \(assessment.immediateCoachRead)"
            )
        }
        if let mode = s.band.responseMode {
            #expect(
                assessment.responseMode == mode,
                "\(s.id): expected responseMode \(mode), got \(assessment.responseMode)"
            )
        }
    }
}
