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
    /// S2 (additive, defaulted nil): the user's coaching profile, used only to
    /// render a chosen-voice register eyebrow when the user has explicitly
    /// picked a voice. Defaulted nil so the existing call sites and previews
    /// compile unchanged — mirrors the `secondaryStyleGoal` additive-field
    /// pattern. When nil or unchosen, the card renders exactly as before. This
    /// is read-only COPY (no model call, no numeric score, no analytics).
    var profile: CoachingProfile? = nil

    /// F4a (additive, defaulted nil): closure the Profile screen wires to
    /// `CoachMemoryStore.noteHypothesisAcknowledgement`. When non-nil, the card
    /// renders three acknowledgement chips ("does this read fit you?") beneath
    /// the case so the user can confirm / question / push back on the working
    /// hypothesis directly from Profile — the SAME durable verdict AskNoum
    /// captures, no parallel state. Defaulted nil so previews and any other call
    /// site render the card exactly as before (fully read-only).
    var onAcknowledge: ((CoachHypothesisConfidence) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Your Coach's Read")
                    .font(Typography.micro)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)

                // S2: chosen-voice register eyebrow. Only when the user has
                // EXPLICITLY chosen a voice (helper returns nil otherwise, so an
                // un-chosen profile shows nothing extra and the card is byte-for-
                // byte the prior layout). Same restrained micro/tertiary eyebrow
                // treatment — names the lens this read is written through without
                // adding a row, a button, or a glyph.
                if let registerLabel = profile?.chosenVoiceRegisterLabel {
                    Text(registerLabel)
                        .font(Typography.micro)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                }
            }

            // 1. Working hypothesis or current lever
            if let hypothesis = memory.workingHypothesis,
               !hypothesis.isEmpty {
                caseRow(
                    icon: "eye",
                    label: confidenceQualifier,
                    text: CoachDisplayCopy.normalized(hypothesis)
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

            // 3. Latest adaptation — why the focus shifted. Round 36
            // surfaces a small "2nd cycle" badge inline on the row when the
            // latest entry documents the round-33 second-cycle pushback
            // marker, so the Profile-tab history surface reads the cycle
            // distinction the post-rep `RevisedReadCard` (round 34) and the
            // chat seed (round 35) already surface. Cross-surface coherence
            // on the same predicate (`documentsSecondCyclePushback`).
            if let latest = memory.adaptationLog?.last {
                lastShiftRow(latest)
            }

            // 4. Real-world transfer — the case's latest off-app check-in.
            // If present, this wins the final coaching-context slot over
            // momentum/reflection because it answers the hardest question:
            // did the work transfer outside the app?
            if let transferLine = transferSummary {
                caseRow(
                    icon: "arrow.up.right.square",
                    label: "Real-world check-in",
                    text: transferLine
                )
            } else if let momentumLine = momentumSummary {
                caseRow(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Momentum",
                    text: momentumLine
                )
            }

            // 5. Latest reflection — user's own words
            if transferSummary == nil,
               let reflection = memory.lastReflectionSummary,
               !reflection.isEmpty {
                caseRow(
                    icon: "quote.opening",
                    label: "Last reflection",
                    text: reflection
                )
            }

            // 6. Acknowledgement — the coach asking "does this read fit you?".
            // Rendered only when ProfileView wires `onAcknowledge` AND there is a
            // working hypothesis the user has not already answered for the current
            // phrasing. Read-only call sites (previews) leave `onAcknowledge` nil
            // and render exactly as before. Persists through the SAME
            // CoachMemoryStore.noteHypothesisAcknowledgement path AskNoum uses —
            // no parallel acknowledgement state.
            acknowledgementSection
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

    // Round 36 — "Last shift" row with optional second-cycle badge.
    //
    // Renders the latest adaptation entry as the standard `caseRow` shape,
    // but when `showsSecondCycleBadge(for:)` returns true the row carries a
    // small "2nd cycle" capsule inline beside the eyebrow label. The capsule
    // uses the same `AppColor.pro` accent the post-rep `RevisedReadCard`
    // (round 34) uses for its REVISED READ eyebrow + stroke, so the two
    // surfaces read with one visual register on the cycle distinction.
    // Pure-predicate gate; no new state, no analytics, no CTA.
    private func lastShiftRow(_ latest: CoachCourseChange) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "arrow.triangle.branch")
                .font(Typography.captionSmall)
                .foregroundStyle(.tertiary)
                .frame(width: 16)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("Last shift")
                        .font(Typography.micro.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    if Self.showsSecondCycleBadge(for: latest) {
                        Text(Self.secondCycleBadgeLabel)
                            .font(Typography.micro.weight(.semibold))
                            .foregroundStyle(AppColor.pro)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColor.pro.opacity(0.10), in: Capsule())
                            .overlay(Capsule().stroke(AppColor.pro.opacity(0.32), lineWidth: 1))
                            .accessibilityLabel("Second adapt cycle")
                            .accessibilityIdentifier("profile.caseReview.lastShift.secondCycleBadge")
                    }
                }

                Text(latest.reason)
                    .font(Typography.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

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
                Text("Current coaching plan")
                    .font(Typography.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

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
                        Text("\(intervention.followedRepCount) completed rep\(intervention.followedRepCount == 1 ? "" : "s")")
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
        switch memory.evidenceCount {
        case ...2: return "Latest rep"
        case 3...4: return "Early read"
        case 5...9: return "Seen across \(memory.evidenceCount) recent reps"
        default: return "Repeated across \(memory.evidenceCount) recent reps"
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

    private var transferSummary: String? {
        guard let transfer = memory.lastTransferReview else { return nil }
        var line = "\(transfer.category.title): \(transfer.outcome.chipLabel.lowercased()); \(transfer.audienceResponse.chipLabel.lowercased())."
        if let note = transfer.note?.trimmingCharacters(in: .whitespacesAndNewlines),
           !note.isEmpty {
            line += " User note: \(note)"
        } else {
            switch transfer.nextAction {
            case .exploreWhatTransferred:
                line += " Next: ask what transferred."
            case .diagnoseBeforeNextMoment:
                line += " Next: diagnose what held and what broke down."
            case .adaptBeforeNextMoment:
                line += " Next: adapt before the next similar moment."
            }
        }
        return line
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

    // MARK: - Second-cycle history badge (round 36)
    //
    // The Profile-tab `CaseReviewCard` is the long-term coaching record
    // surface. Round 33 wrote the `secondCyclePushbackMarker` parenthetical
    // into `CoachCourseChange.reason` whenever the latest pushback rebuild
    // itself followed a prior pushback rebuild. Round 34 surfaced that
    // signal on the post-rep `RevisedReadCard` ("You flagged the rebuilt
    // read as off too."); round 35 surfaced it on the chat seed ("I flagged
    // the rebuilt read as off too."). Round 36 closes the third surface:
    // the "Last shift" row now carries a small "2nd cycle" badge inline
    // beside the eyebrow label when the latest entry documents the
    // second-cycle pattern.
    //
    // Restraint:
    //   • A badge, not a row. The case spine stays five sections; the
    //     second-cycle distinction is a qualifier on an existing row.
    //   • Reads the existing `documentsSecondCyclePushback` predicate. No
    //     new field, no new storage, no migration. Memories persisted
    //     before round 33 read `false` and surface no badge.
    //   • Calm phrasing ("2nd cycle") — no exclamation, no urgency
    //     framing. Brand voice matches `RevisedReadCard.secondCycleHeadlineCopy`.

    /// Inline badge label surfaced on the "Last shift" row when the latest
    /// adaptation entry documents a round-33 second-cycle pushback. Short
    /// + calm so the row scans without crowding. Cross-surface contract
    /// with `RevisedReadCard.secondCycleHeadlineCopy` ("You flagged the
    /// rebuilt read as off too.") on the post-rep card and the round-35
    /// chat-seed second-cycle lead — same predicate, three coordinated
    /// visual registers.
    static let secondCycleBadgeLabel: String = "2nd cycle"

    /// Pure-predicate gate for the second-cycle badge. Static + pure so
    /// tests can pin it without standing up a SwiftUI view, mirror of the
    /// `hasUnacknowledgedHypothesis(in:)` / `acknowledgedEcho(for:)`
    /// pattern. Reads `documentsSecondCyclePushback` directly — a copy
    /// edit on the marker in `CoachCourseChange` automatically ripples to
    /// the badge surface in one place.
    static func showsSecondCycleBadge(for change: CoachCourseChange) -> Bool {
        change.documentsSecondCyclePushback
    }

    // MARK: - Acknowledgement
    //
    // The coach asking "does this read fit you?" — the structured back-channel a
    // real coach uses after sharing a read. Mirrors AskNoumView's hypothesis-ack
    // chips, minus the chat-shape eligibility (there is no chat thread on
    // Profile). The durable verdict is voice-independent
    // (`CoachHypothesisConfidence`); only the chip COPY shifts per voice.

    /// Pure eligibility: is there a working hypothesis the user has not yet
    /// acknowledged for its current phrasing? Static + pure so it is locked by
    /// tests without standing up a SwiftUI view. A memory rebuild that rewrites
    /// the hypothesis drops a stale ack via `appliesTo`, which re-offers the row.
    static func hasUnacknowledgedHypothesis(in memory: CoachMemory) -> Bool {
        guard let hypothesis = memory.workingHypothesis?
                .trimmingCharacters(in: .whitespacesAndNewlines),
              !hypothesis.isEmpty else { return false }
        if let ack = memory.hypothesisAcknowledgement,
           ack.appliesTo(currentHypothesis: memory.workingHypothesis) {
            return false
        }
        return true
    }

    /// Quiet echo shown once the user has acknowledged the current hypothesis
    /// (from this card or from Ask Noum) — closes the loop without fanfare. Nil
    /// when no acknowledgement applies to the current phrasing. Brand voice:
    /// calm, no exclamation; a `.rejected` verdict reads as the user steering
    /// the coach, never as a failure state.
    static func acknowledgedEcho(for memory: CoachMemory) -> String? {
        guard let ack = memory.hypothesisAcknowledgement,
              ack.appliesTo(currentHypothesis: memory.workingHypothesis) else { return nil }
        switch ack.confidence {
        case .confirmed: return "You confirmed this read."
        case .uncertain: return "You're not sure about this read yet."
        case .rejected:  return "You asked the coach to adapt this read."
        }
    }

    @ViewBuilder
    private var acknowledgementSection: some View {
        if let onAcknowledge {
            if Self.hasUnacknowledgedHypothesis(in: memory) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Does this read fit you?")
                        .font(Typography.micro.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .accessibilityLabel("Quick verdict on your coach's working read")

                    FlowLayout(spacing: 8, runSpacing: 6) {
                        ForEach(
                            CoachContextBuilder.hypothesisAcknowledgementChips(for: memory.voice),
                            id: \.confidence
                        ) { chip in
                            Button {
                                onAcknowledge(chip.confidence)
                            } label: {
                                Text(chip.label)
                                    .font(Typography.caption.weight(.semibold))
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(AppColor.pro)
                                    .padding(.horizontal, Spacing.sm)
                                    .padding(.vertical, 6)
                                    .background(AppColor.pro.opacity(0.10), in: Capsule())
                                    .overlay(
                                        Capsule().stroke(AppColor.pro.opacity(0.32), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.pressable)
                            .accessibilityLabel("Acknowledge: \(chip.label)")
                            .accessibilityIdentifier("profile.caseReview.ack.\(chip.confidence.rawValue)")
                        }
                    }
                }
                .padding(.top, 2)
            } else if let echo = Self.acknowledgedEcho(for: memory) {
                caseRow(icon: "checkmark.bubble", label: "Your verdict", text: echo)
            }
        }
    }
}
