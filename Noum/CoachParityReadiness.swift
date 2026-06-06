import Foundation

// MARK: - Coach-Parity Readiness (F5 — Validation, coach-parity stage 7)
//
// The honest, code-addressable PROXY for stage 7 (Validation). True coach
// parity is "earned through durable outcomes" and external calibration — not
// something an app can self-certify (docs/VISION.md). So instead of faking a
// parity score, this measures, per user, how much real EVIDENCE Noum has
// accumulated across each stage of the coaching loop, and reports earned vs
// thin honestly.
//
// Two jobs:
//   1. Drive honest claim-scaling: the coach context surfaces which stages are
//      earned so the model never asserts more certainty than the evidence
//      supports.
//   2. Give the user a transparent "how well does Noum actually know you yet"
//      read instead of an implied "your AI coach has it all figured out."
//
// Hard rule — NOT a fake progress bar: every status is derived from real
// accumulated evidence, stays `.thin` when the evidence is thin, and the
// VALIDATION stage is structurally capped: it can never read `.earned`,
// because the app cannot self-certify parity. That cap is the whole point.

struct CoachParityReadiness: Equatable {

    enum StageStatus: String, Codable, Equatable {
        case thin       // not enough evidence yet
        case forming    // evidence accumulating, not yet solid
        case earned     // solid evidence FOR THIS USER (never used for validation)
    }

    enum Stage: String, Codable, CaseIterable, Equatable {
        case diagnosis
        case formulation
        case prescription
        case observation
        case adaptation
        case transfer
        case validation

        var title: String {
            switch self {
            case .diagnosis:    return "Diagnosis"
            case .formulation:  return "Case formulation"
            case .prescription: return "Prescription"
            case .observation:  return "Observation"
            case .adaptation:   return "Adaptation"
            case .transfer:     return "Real-world transfer"
            case .validation:   return "Validation"
            }
        }
    }

    struct StageRead: Equatable {
        let stage: Stage
        let status: StageStatus
        /// One short, honest line on WHY this status — the evidence (or its
        /// absence). Never overclaims.
        let basis: String
    }

    let stages: [StageRead]

    var earnedCount: Int { stages.filter { $0.status == .earned }.count }
    var thinCount: Int { stages.filter { $0.status == .thin }.count }

    func status(for stage: Stage) -> StageStatus {
        stages.first(where: { $0.stage == stage })?.status ?? .thin
    }

    /// Calm, honest headline. Never implies the coach has the user "figured
    /// out", and always leaves validation open by design.
    var headline: String {
        switch earnedCount {
        case 0:
            return "Noum is still getting to know you. The more you practise and check in, the sharper its read becomes."
        case 1...3:
            return "Noum has a working read on \(earnedCount) of 7 coaching stages with you — honestly, it's still building the picture."
        default:
            return "Noum has a solid read on \(earnedCount) of 7 stages. Validation stays open by design — that's earned in your real-world moments over time, not inside the app."
        }
    }

    // MARK: - Build

    /// Compose the readiness read from accumulated evidence. Pure — all inputs
    /// are plain values/counts so it's fully testable without standing up
    /// stores. Counts that are hard to source exactly at a given call site may
    /// be lower bounds; under-counting only ever biases the read toward
    /// humility (a stage reads less-earned, never more), which is the safe
    /// direction for an honesty instrument.
    static func build(
        memory: CoachMemory?,
        sessionCount: Int,
        recommendationOutcomeCount: Int,
        transferReportCount: Int,
        checkInCount: Int
    ) -> CoachParityReadiness {
        CoachParityReadiness(stages: [
            diagnosis(memory: memory, sessionCount: sessionCount),
            formulation(memory: memory, checkInCount: checkInCount),
            prescription(memory: memory),
            observation(memory: memory, recommendationOutcomeCount: recommendationOutcomeCount),
            adaptation(memory: memory, recommendationOutcomeCount: recommendationOutcomeCount),
            transfer(memory: memory, transferReportCount: transferReportCount),
            validation(transferReportCount: transferReportCount),
        ])
    }

    private static func diagnosis(memory: CoachMemory?, sessionCount: Int) -> StageRead {
        let confidence = memory?.evidenceConfidence ?? .insufficient
        let hasLever = memory?.currentLever != nil
        if confidence >= .moderate && hasLever {
            return StageRead(stage: .diagnosis, status: .earned, basis: "Baseline established and a high-leverage focus identified.")
        }
        if confidence >= .tentative || sessionCount >= 1 {
            return StageRead(stage: .diagnosis, status: .forming, basis: "An early baseline is forming from your reps.")
        }
        return StageRead(stage: .diagnosis, status: .thin, basis: "A few reps will establish your baseline.")
    }

    private static func formulation(memory: CoachMemory?, checkInCount: Int) -> StageRead {
        let hasHypothesis = (memory?.workingHypothesis?.isEmpty == false)
        let ackApplies = memory?.hypothesisAcknowledgement?.appliesTo(currentHypothesis: memory?.workingHypothesis) ?? false
        if hasHypothesis && ackApplies {
            return StageRead(stage: .formulation, status: .earned, basis: "A working read you've confirmed fits you.")
        }
        if hasHypothesis || checkInCount > 0 || memory?.reflectionPattern != nil {
            return StageRead(stage: .formulation, status: .forming, basis: "A working read is forming; confirming it deepens the case.")
        }
        return StageRead(stage: .formulation, status: .thin, basis: "No working read yet — reps and a check-in will start one.")
    }

    private static func prescription(memory: CoachMemory?) -> StageRead {
        guard let intervention = memory?.activeIntervention else {
            return StageRead(stage: .prescription, status: .thin, basis: "No active drill prescribed yet.")
        }
        let hasMeasure = intervention.successCriterion != nil || (intervention.target?.isEmpty == false)
        if hasMeasure {
            return StageRead(stage: .prescription, status: .earned, basis: "An active drill with a named target and success measure.")
        }
        return StageRead(stage: .prescription, status: .forming, basis: "A drill is active; its success measure is still forming.")
    }

    private static func observation(memory: CoachMemory?, recommendationOutcomeCount: Int) -> StageRead {
        let followed = memory?.activeIntervention?.followedRepCount ?? 0
        let minReps = memory?.activeIntervention?.minimumFollowedRepsForReview ?? 3
        if followed >= minReps && minReps > 0 {
            return StageRead(stage: .observation, status: .earned, basis: "Enough reps observed against the current drill to judge it.")
        }
        if followed > 0 || recommendationOutcomeCount > 0 {
            return StageRead(stage: .observation, status: .forming, basis: "Starting to observe how you respond to the drill.")
        }
        return StageRead(stage: .observation, status: .thin, basis: "No observed reps against a drill yet.")
    }

    private static func adaptation(memory: CoachMemory?, recommendationOutcomeCount: Int) -> StageRead {
        let changes = memory?.adaptationLog?.count ?? 0
        if changes >= 1 {
            return StageRead(stage: .adaptation, status: .earned, basis: "The plan has been adapted with a recorded rationale.")
        }
        if recommendationOutcomeCount >= 2 {
            return StageRead(stage: .adaptation, status: .forming, basis: "Enough response data to adapt the plan when needed.")
        }
        return StageRead(stage: .adaptation, status: .thin, basis: "Not enough response data to adapt yet.")
    }

    private static func transfer(memory: CoachMemory?, transferReportCount: Int) -> StageRead {
        if transferReportCount >= 2 {
            return StageRead(stage: .transfer, status: .earned, basis: "Multiple real-world moments reported back.")
        }
        if transferReportCount == 1 || memory?.lastTransferReview != nil {
            return StageRead(stage: .transfer, status: .forming, basis: "One real-world moment reported — the transfer loop has started.")
        }
        return StageRead(stage: .transfer, status: .thin, basis: "No real-world outcomes reported yet.")
    }

    /// VALIDATION is structurally capped at `.forming` — never `.earned`. The
    /// app cannot self-certify parity; true validation needs repeated
    /// real-world outcomes AND calibration against professional-coach judgment
    /// over time. This cap is the core honesty of the whole instrument.
    private static func validation(transferReportCount: Int) -> StageRead {
        if transferReportCount >= 2 {
            return StageRead(stage: .validation, status: .forming, basis: "Real-world outcomes are accumulating. True validation also needs comparison against professional-coach judgment over time — Noum will not mark this earned on its own.")
        }
        return StageRead(stage: .validation, status: .thin, basis: "Validation needs repeated real-world outcomes and, ultimately, calibration against professional coaches. Noum never self-certifies parity.")
    }

    // MARK: - Coach context (claim-scaling)

    /// Lines for the coach's USER CONTEXT block. They tell the model to scale
    /// its certainty to the earned stages and never claim validation/parity.
    var coachContextLines: [String] {
        let earned = stages.filter { $0.status == .earned }.map { $0.stage.title }
        let thin = stages.filter { $0.status == .thin }.map { $0.stage.title }
        var out: [String] = []
        out.append("- Earned with this user: \(earned.isEmpty ? "none yet" : earned.joined(separator: ", ")).")
        if !thin.isEmpty {
            out.append("- Still thin: \(thin.joined(separator: ", ")).")
        }
        out.append("- Scale your certainty to the earned stages. Never claim coach-parity, validation, or proof your coaching works — that is earned through the user's real-world outcomes over time, not self-certified.")
        return out
    }
}
