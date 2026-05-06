import Foundation
#if canImport(SwiftUI)
import SwiftUI

// MARK: - Hero Score Card

struct HeroScoreCard: View {
    let scoreValue: Int
    let practiceTitle: String
    let scoreAccent: Color
    let scoreEmoji: String
    let headline: String
    let sessionPrompt: String?
    let effectiveFillerCount: Int
    let fillerTint: Color
    let fillerDelta: Int?
    let effectiveDuration: TimeInterval
    let durationAssessment: DurationAssessment
    let xpEarned: Int
    let celebrationVisible: Bool

    var body: some View {
        VStack(spacing: 16) {
            // Mode label
            Text(practiceTitle.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .tracking(1.4)

            // Score ring
            ZStack {
                Circle()
                    .stroke(scoreAccent.opacity(0.15), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: Double(scoreValue) / 10.0)
                    .stroke(scoreAccent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(scoreValue)")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(scoreAccent)
                    Text("/10")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .scaleEffect(celebrationVisible ? 1.06 : 1.0)
            .animation(.bouncySpring, value: celebrationVisible)

            // Headline
            HStack(spacing: 8) {
                Image(systemName: scoreEmoji)
                    .foregroundStyle(scoreAccent)
                Text(headline)
                    .font(.title3.weight(.bold))
            }

            // Prompt (if available)
            if let sessionPrompt {
                Text("\"\(sessionPrompt)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
            }

            // Quick stats row with trend deltas
            HStack(spacing: 20) {
                StatPill(label: "Fillers", value: "\(effectiveFillerCount)", delta: fillerDelta, tint: fillerTint, invertDelta: true)
                DurationAssessmentPill(effectiveDuration: effectiveDuration, durationAssessment: durationAssessment)
                StatPill(label: "XP", value: "+\(xpEarned)", delta: nil, tint: .orange, invertDelta: false)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(
            LinearGradient(
                colors: [AppColor.cardBackground, scoreAccent.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(scoreAccent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

// MARK: - Stat Pill (reusable)

struct StatPill: View {
    let label: String
    let value: String
    let delta: Int?
    let tint: Color
    let invertDelta: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            if let delta, delta != 0 {
                let improved = invertDelta ? delta < 0 : delta > 0
                HStack(spacing: 2) {
                    Image(systemName: improved ? "arrow.down" : "arrow.up")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(abs(delta))")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(improved ? AppColor.positive : AppColor.caution)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Duration Assessment Pill

struct DurationAssessmentPill: View {
    let effectiveDuration: TimeInterval
    let durationAssessment: DurationAssessment

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(effectiveDuration))s")
                .font(.headline.weight(.bold))
                .foregroundStyle(durationAssessment.tint)
            Text("Duration")
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 3) {
                Image(systemName: durationAssessment.icon)
                    .font(.system(size: 9, weight: .bold))
                Text(durationAssessment.rawValue)
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(durationAssessment.tint)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Coach Note Card

struct CoachNoteCard: View {
    let coachNote: CoachNote
    let coachNoteRevealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coach Note")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            // Momentum — what's getting stronger
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.positive)
                    .frame(width: 18)
                Text(coachNote.momentum)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(coachNoteRevealed ? 1 : 0)
            .offset(y: coachNoteRevealed ? 0 : 8)

            // Leverage — what's holding them back
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "scope")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.caution)
                    .frame(width: 18)
                Text(coachNote.leverage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(coachNoteRevealed ? 1 : 0)
            .offset(y: coachNoteRevealed ? 0 : 8)

            // Next step — one concrete action
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "arrow.right.circle")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(AppColor.brandBlue)
                    .frame(width: 18)
                Text(coachNote.nextStep)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .opacity(coachNoteRevealed ? 1 : 0)
            .offset(y: coachNoteRevealed ? 0 : 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

// MARK: - Filler Breakdown Card

struct FillerBreakdownCard: View {
    let transcriptText: String

    var body: some View {
        let breakdown = FillerWordDetector.breakdown(
            in: transcriptText,
            customWords: ClutchWordStore.shared.customFillerWords
        )
        Group {
            if !breakdown.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Filler Breakdown")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)

                    // Per-word breakdown chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(breakdown.topWords.prefix(6), id: \.word) { entry in
                                HStack(spacing: 4) {
                                    Text("\"\(entry.word)\"")
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(entry.count)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Self.chipTint(count: entry.count), in: Capsule())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.black.opacity(0.04), in: Capsule())
                            }
                        }
                    }

                    // Coaching note about fillers
                    if breakdown.totalCount >= 3 {
                        Text("Most fillers appear in transitions between ideas. Try pausing briefly instead.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if breakdown.totalCount > 0 {
                        Text("Light filler usage. These tend to decrease as you build comfort with pausing.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(Spacing.lg)
                .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous))
            }
        }
    }

    static func chipTint(count: Int) -> Color {
        if count >= 4 { return AppColor.warning }
        if count >= 2 { return AppColor.caution }
        return .secondary
    }
}

// MARK: - Your Next Move Card

struct YourNextMoveCard: View {
    let drill: DrillRecommendationV2
    let legacyDrill: DrillRecommendation
    let aiFeedback: AICoachFeedback?
    let nextAction: NextAction?
    var onStartMiniDrill: (DrillRecommendationV2) -> Void
    var onStartDrill: ((DrillRecommendation) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: drill.icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(drill.tint)
                Text("Your Next Move")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                // Format badge
                Text(drill.format == .miniDrill ? "Quick Drill" : "Full Retry")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(drill.tint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(drill.tint.opacity(0.1), in: Capsule())
            }

            // Drill title
            Text(drill.title)
                .font(.headline)
                .foregroundStyle(.primary)

            // Session-specific rationale
            Text(drill.reason)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Trend context (if available)
            if let context = drill.trendContext {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(drill.tint.opacity(0.7))
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(drill.tint.opacity(0.05), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }

            // Strategic reasoning (from NextActionEngine)
            if let action = nextAction, !action.reasoning.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "brain")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.purple.opacity(0.7))
                    Text(action.reasoning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.purple.opacity(0.05), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }

            // Constraint rule
            VStack(alignment: .leading, spacing: 6) {
                Text("Your rule")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(drill.tint)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(drill.constraint)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(drill.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))

            // Primary CTA — Mini Drill or Full Retry
            if drill.format == .miniDrill {
                Button {
                    onStartMiniDrill(drill)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.subheadline.weight(.semibold))
                        Text("Start Quick Drill (45s)")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .foregroundStyle(.white)
                    .background(drill.tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.pressable)

                // Alternate: full retry
                if let onStartDrill {
                    Button {
                        onStartDrill(legacyDrill)
                    } label: {
                        Text("or Full Retry")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            } else {
                // Full retry is the primary action
                if let onStartDrill {
                    Button {
                        onStartDrill(legacyDrill)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline.weight(.semibold))
                            Text("Start Full Retry")
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .foregroundStyle(.white)
                        .background(drill.tint, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                    }
                    .buttonStyle(.pressable)
                }

                // Alternate: mini drill
                Button {
                    onStartMiniDrill(drill)
                } label: {
                    Text("or Quick Drill (45s)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // AI Coach suggested drill (if available, shown subtly)
            if let aiFeedback {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("AI Coach: \(aiFeedback.suggestedDrill)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

// MARK: - Baseline Comparison Card

struct BaselineComparisonCard: View {
    let baseline: CommunicationBaseline
    let transcriptText: String
    let effectiveFillerCount: Int
    let effectiveDuration: TimeInterval
    let explicitMode: PracticeMode?
    let score: Int?
    let scoreValue: Int
    let rating: SpeakingRating
    let pressureLevel: PressureLevel

    var body: some View {
        if baseline.overallConfidence >= .tentative {
            let dummySession = PracticeSession(
                transcript: transcriptText,
                fillerWordCount: effectiveFillerCount,
                duration: effectiveDuration,
                date: Date(),
                mode: explicitMode ?? .timed,
                score: score ?? scoreValue
            )
            let comparisons = BaselineEngine.sessionComparison(session: dummySession, baseline: baseline)

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.blue)
                    Text("vs Your Baseline")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    Text(baseline.overallConfidence.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppColor.brandBlue.opacity(0.08), in: Capsule())
                }

                // Pressure context indicator with resilience data
                if pressureLevel >= .elevated {
                    let pressureProfile = BaselineStore.shared.pressureProfile
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "flame.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                            Text("High-pressure session")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.orange)
                            if let resilience = pressureProfile.pressureResilience {
                                Spacer()
                                Text("Resilience: \(Int(resilience * 100))%")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(resilience >= 0.7 ? AppColor.positive : resilience >= 0.4 ? AppColor.caution : .red)
                            }
                        }
                        if let insight = pressureProfile.pressureInsight {
                            Text(insight)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.orange.opacity(0.12), lineWidth: 1)
                    )
                }

                if !comparisons.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(Array(comparisons.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                            HStack(alignment: .top, spacing: 8) {
                                Text(key)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 50, alignment: .leading)
                                Text(value)
                                    .font(.caption)
                                    .foregroundStyle(AppColor.textPrimary)
                            }
                        }
                    }
                }

                if rating.totalRatedSessions > 0 {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Rating")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("\(rating.overall)")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.blue)
                        }
                        if rating.weeklyDelta != 0 {
                            Text(rating.weeklyDelta > 0 ? "+\(rating.weeklyDelta) this week" : "\(rating.weeklyDelta) this week")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(rating.weeklyDelta > 0 ? AppColor.positive : AppColor.caution)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Peak")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("\(rating.peakRating)")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                }

                if !baseline.topStrengths.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("Strengths: \(baseline.topStrengths.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(Spacing.lg)
            .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous)
                    .stroke(AppColor.brandBlue.opacity(0.08), lineWidth: 1)
            )
        }
    }
}

// MARK: - IM Verdict Card

struct IMVerdictCard: View {
    let scoreValue: Int
    let scoreAccent: Color
    let scoreEmoji: String
    let headline: String
    let effectiveFillerCount: Int
    let effectiveDuration: TimeInterval
    let xpEarned: Int
    let imConversationDetails: IMConversationDetails?

    var body: some View {
        let details = imConversationDetails
        let userTurns = details?.turns.filter { $0.speaker == .user }.count ?? 0
        let isShortSession = userTurns <= 2 || effectiveDuration < 30
        let confidenceLabel = isShortSession ? "Early read" : "Session read"

        VStack(spacing: 14) {
            // Mode + confidence label
            HStack(spacing: 8) {
                Text("IM Mode".uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .tracking(1.4)
                Spacer()
                Text(confidenceLabel.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(scoreAccent.opacity(0.7))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(scoreAccent.opacity(0.1), in: Capsule())
            }

            // Verdict line — the headline
            HStack(spacing: 10) {
                Image(systemName: scoreEmoji)
                    .font(.title2)
                    .foregroundStyle(scoreAccent)
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline)
                        .font(.title3.weight(.bold))
                    if let tone = details?.actualTone, !tone.isEmpty {
                        Text("You came across as \(tone.lowercased())")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            // Context chips + inline score
            HStack(spacing: 8) {
                if let details {
                    SummaryChip(text: details.setup.scenario.title, tint: .purple)
                    SummaryChip(text: details.setup.targetTone.title, tint: .blue)
                }
                Spacer()
                // Score shown small, not as hero
                Text("\(scoreValue)/10")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(scoreAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(scoreAccent.opacity(0.1), in: Capsule())
            }

            // Compact stats
            HStack(spacing: 16) {
                Label("\(userTurns) turns", systemImage: "bubble.left.and.bubble.right")
                Label("\(Int(effectiveDuration))s", systemImage: "clock")
                Label("\(effectiveFillerCount) fillers", systemImage: "waveform.path")
                Spacer()
                Text("+\(xpEarned) XP")
                    .foregroundStyle(.orange)
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(
                colors: [AppColor.cardBackground, scoreAccent.opacity(0.04)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.xl, style: .continuous)
                .stroke(scoreAccent.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    }
}

// MARK: - IM Read Card

struct IMReadCard: View {
    let coachNote: CoachNote
    let effectiveDuration: TimeInterval
    let imConversationDetails: IMConversationDetails?

    var body: some View {
        let userTurns = imConversationDetails?.turns.filter { $0.speaker == .user }.count ?? 0
        let isShortSession = userTurns <= 2 || effectiveDuration < 30

        VStack(alignment: .leading, spacing: 12) {
            Text("The Read")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            // Strength
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.positive)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coachNote.momentum)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider()

            // Miss
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "scope")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.caution)
                VStack(alignment: .leading, spacing: 2) {
                    Text(coachNote.leverage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Confidence disclaimer for short sessions
            if isShortSession {
                Text("Based on a short conversation — longer sessions give a clearer picture.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

// MARK: - IM One Move Card

struct IMOneMoveCard: View {
    let coachNote: CoachNote
    var onPracticeAgain: () -> Void
    var onSelectPracticeMode: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.brandBlue)
                Text("Next Move")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
            }

            Text(coachNote.nextStep)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // CTA buttons
            HStack(spacing: 12) {
                Button {
                    onPracticeAgain()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption.weight(.bold))
                        Text("Try Again")
                            .font(.subheadline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .foregroundStyle(.white)
                    .background(AppColor.brandBlue, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.pressable)

                Button {
                    onSelectPracticeMode()
                } label: {
                    Text("New Chat")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(AppColor.innerSurface, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                }
                .buttonStyle(.pressable)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

// MARK: - IM Signals Card

struct IMSignalsCard: View {
    let details: IMConversationDetails

    var body: some View {
        let startTrust = 5
        let startTension = 4
        let startEngagement = 5
        let finalTrust = details.finalState?.normalizedTrust ?? startTrust
        let finalTension = details.finalState?.normalizedTension ?? startTension
        let finalEngagement = details.finalState?.normalizedEngagement ?? startEngagement

        VStack(alignment: .leading, spacing: 12) {
            Text("Conversation Signals")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)

            HStack(spacing: 10) {
                SignalPill(label: "Trust", start: startTrust, end: finalTrust, goodDirection: .up, tint: .blue)
                SignalPill(label: "Tension", start: startTension, end: finalTension, goodDirection: .down, tint: .orange)
                SignalPill(label: "Engage", start: startEngagement, end: finalEngagement, goodDirection: .up, tint: .green)
            }

            // Outcome milestone (if present)
            if let outcome = details.outcome {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    Text(outcome.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    Spacer()
                }
                .padding(10)
                .background(Color.yellow.opacity(0.06), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
            }

            // Beat description
            if let beat = details.finalState?.beat, !beat.isEmpty {
                Text(beat)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.lg)
        .background(AppColor.cardBackground, in: RoundedRectangle(cornerRadius: CornerRadius.large, style: .continuous))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
    }
}

// MARK: - Signal Pill (IM helper)

enum SignalDirection { case up, down }

struct SignalPill: View {
    let label: String
    let start: Int
    let end: Int
    let goodDirection: SignalDirection
    let tint: Color

    var body: some View {
        let delta = end - start
        let isGood: Bool = {
            switch goodDirection {
            case .up: return delta >= 0
            case .down: return delta <= 0
            }
        }()
        let deltaColor: Color = delta == 0 ? .secondary : (isGood ? AppColor.positive : AppColor.caution)

        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Text("\(start)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
                Image(systemName: "arrow.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.tertiary)
                Text("\(end)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(tint)
            }
            if delta != 0 {
                HStack(spacing: 2) {
                    Image(systemName: delta > 0 ? "arrow.up" : "arrow.down")
                        .font(.system(size: 8, weight: .bold))
                    Text("\(abs(delta))")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(deltaColor)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.05), in: RoundedRectangle(cornerRadius: CornerRadius.small, style: .continuous))
    }
}

// MARK: - Summary Chip (reusable)

struct SummaryChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(tint.opacity(0.10), in: Capsule())
    }
}

#endif
