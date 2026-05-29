import SwiftUI

// MARK: - Case Review Card
//
// A compact, read-only surface for the coaching case — the persistent
// "working read" that Ask Noum carries between sessions. This card lets
// the user see what the coach is currently testing, what the active
// intervention is, and how the plan has adapted over time.
//
// Design rules:
//   • Restrained — one card, no buttons, no gamification, no urgency
//     markers. This is the coach's notebook, not a dashboard.
//   • Honest about evidence — tentative evidence says "early read", not
//     "your pattern is …". Insufficient evidence shows nothing.
//   • Read-only — the user reads; edits and conversations happen in Ask
//     Noum. The card links there as a quiet handoff.
//   • Compact — five sections max, each ≤2 lines. The card should not
//     scroll or dominate the Profile screen.

struct CaseReviewCard: View {
    let memory: CoachMemory

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Coach's Read")
                .font(Typography.micro)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            // 1. Working hypothesis or current lever
            if let hypothesis = memory.workingHypothesis,
               !hypothesis.isEmpty {
                caseRow(
                    icon: "eye",
                    label: confidenceQualifier,
                    text: hypothesis
                )
            } else if let lever = memory.currentLever {
                caseRow(
                    icon: "eye",
                    label: confidenceQualifier,
                    text: "Current focus: \(lever.displayName.lowercased())."
                )
            }

            // 2. Active intervention — what the coach prescribed
            if let intervention = memory.activeIntervention {
                interventionRow(intervention)
            }

            // 3. Latest adaptation — why the focus shifted
            if let latest = memory.adaptationLog?.last {
                caseRow(
                    icon: "arrow.triangle.branch",
                    label: "Last shift",
                    text: latest.reason
                )
            }

            // 4. Momentum signal — one quiet line
            if let momentumLine = momentumSummary {
                caseRow(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Momentum",
                    text: momentumLine
                )
            }

            // 5. Latest reflection — user's own words
            if let reflection = memory.lastReflectionSummary,
               !reflection.isEmpty {
                caseRow(
                    icon: "quote.opening",
                    label: "Last reflection",
                    text: reflection
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(
            AppColor.cardBackground,
            in: RoundedRectangle(
                cornerRadius: CornerRadius.xl,
                style: .continuous
            )
        )
    }

    // MARK: - Row Components

    private func caseRow(icon: String, label: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(Typography.captionSmall)
                .foregroundStyle(.tertiary)
                .frame(width: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(text)
                    .font(Typography.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func interventionRow(_ intervention: CoachIntervention) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "scope")
                .font(Typography.captionSmall)
                .foregroundStyle(.tertiary)
                .frame(width: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Active intervention")
                    .font(Typography.micro.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(interventionSummary(intervention))
                    .font(Typography.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                // Review status chip
                HStack(spacing: 6) {
                    Text(intervention.reviewStatus.contextLabel)
                        .font(Typography.micro)
                        .foregroundStyle(reviewStatusColor(intervention.reviewStatus))

                    if intervention.followedRepCount > 0 {
                        Text("·")
                            .foregroundStyle(.quaternary)
                        Text("\(intervention.followedRepCount) rep\(intervention.followedRepCount == 1 ? "" : "s") observed")
                            .font(Typography.micro)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.top, 1)

                // Success criterion — if defined
                if let criterion = intervention.successCriterion {
                    HStack(spacing: 4) {
                        Image(systemName: criterionIcon(intervention.criterionStatus))
                            .font(Typography.micro)
                            .foregroundStyle(criterionColor(intervention.criterionStatus))
                        Text(criterion.summary)
                            .font(Typography.micro)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 1)
                }

                // Review cadence
                if let reviewDate = intervention.reviewDueAt {
                    Text("Review by \(reviewDateLabel(reviewDate))")
                        .font(Typography.micro)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 1)
                }
            }
        }
    }

    // MARK: - Computed Helpers

    private var confidenceQualifier: String {
        switch memory.evidenceConfidence {
        case .insufficient: return "Early signal"
        case .tentative: return "Early read"
        case .moderate: return "Working read"
        case .established: return "Coaching read"
        case .stable: return "Established read"
        }
    }

    private func interventionSummary(_ intervention: CoachIntervention) -> String {
        var parts: [String] = []
        parts.append(intervention.mode.displayLabel)
        if let focus = intervention.focus, !focus.isEmpty {
            parts.append("targeting \(focus.lowercased())")
        }
        var line = parts.joined(separator: " ")
        if let target = intervention.target, !target.isEmpty {
            line += ". Goal: \(target)"
        }
        return line + "."
    }

    private func reviewStatusColor(_ status: CoachInterventionReviewStatus) -> Color {
        switch status {
        case .awaitingAttempt: return .secondary
        case .formingEvidence: return .secondary
        case .continueAndVerify: return .green.opacity(0.8)
        case .diagnoseBeforeRepeating: return .orange.opacity(0.8)
        case .adaptBeforeRepeating: return .orange.opacity(0.8)
        }
    }

    private func criterionIcon(_ status: CoachCriterionStatus?) -> String {
        switch status {
        case .met: return "checkmark.circle.fill"
        case .notYetMet: return "circle"
        case .pending, .none: return "circle.dashed"
        }
    }

    private func criterionColor(_ status: CoachCriterionStatus?) -> Color {
        switch status {
        case .met: return .green.opacity(0.8)
        case .notYetMet: return .orange.opacity(0.8)
        case .pending, .none: return .gray.opacity(0.5)
        }
    }

    private var momentumSummary: String? {
        var parts: [String] = []

        if let direction = memory.fillerTrendDirection {
            switch direction {
            case .improving: parts.append("Fillers trending down")
            case .declining: parts.append("Fillers trending up")
            case .stable: parts.append("Fillers holding steady")
            case .resolved: parts.append("Fillers resolved")
            case .newIssue: parts.append("New filler pattern emerging")
            }
        }

        if let clean = memory.consecutiveCleanReps, clean >= 2 {
            parts.append("\(clean) clean reps in a row")
        }

        if let weekly = memory.weeklyRepCount {
            let noun = weekly == 1 ? "rep" : "reps"
            parts.append("\(weekly) \(noun) this week")
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ". ") + "."
    }

    private func reviewDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: now, to: date).day ?? 0
        if days <= 0 { return "today" }
        if days == 1 { return "tomorrow" }
        if days <= 7 { return "in \(days) days" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
