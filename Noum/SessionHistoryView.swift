import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(SwiftUI)

struct SessionHistoryView: View {
    @StateObject private var sessionStore = PracticeSessionStore.shared
    @StateObject private var coachingProfileStore = CoachingProfileStore.shared
    @Environment(\.dismiss) private var dismiss

    private var plan: CoachingPlan? {
        CoachingPlanner.plan(for: sessionStore.sessions, profile: coachingProfileStore.profile)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.95, green: 0.92, blue: 0.87),
                        Color.white,
                        Color(red: 0.90, green: 0.95, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                if sessionStore.sessions.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            if let plan {
                                coachingSnapshot(plan)
                            }

                            ForEach(sessionStore.sessions) { session in
                                NavigationLink {
                                    SessionHistoryDetailView(
                                        session: session,
                                        insights: CoachingPlanner.sessionInsights(
                                            for: session,
                                            comparedTo: sessionStore.sessions,
                                            profile: coachingProfileStore.profile
                                        )
                                    )
                                } label: {
                                    sessionCard(session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(18)
                    }
                }
            }
            .navigationTitle("Practice History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "text.book.closed")
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text("No sessions yet")
                .font(.title3.weight(.bold))
            Text("Complete a few practice runs and this area will start showing transcripts, trends, and coaching notes.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(24)
    }

    private func coachingSnapshot(_ plan: CoachingPlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Coaching Snapshot")
                .font(.headline)

            Text(plan.encouragement)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: snapshotColumns, spacing: 10) {
                snapshotCard(title: "Focus", value: shortFocusText(from: plan.currentFocus), tint: .blue)
                snapshotCard(title: "Drill", value: shortDrillText(from: plan.suggestedDrill), tint: .orange)
                if let strongestMode = plan.strongestMode {
                    snapshotCard(title: "Best mode", value: label(for: strongestMode), tint: .green)
                }
                snapshotCard(title: "Pace", value: "\(Int(plan.hiddenBaseline.averageWordsPerMinute.rounded())) WPM", tint: .purple)
                snapshotCard(title: "Current voice", value: plan.hiddenBaseline.currentIdentity, tint: .pink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func sessionCard(_ session: PracticeSession) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.headline ?? label(for: session.mode))
                        .font(.headline)
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }

            Text(session.coachSummary ?? session.transcript)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 10) {
                statPill(title: "Mode", value: label(for: session.mode), tint: .purple)
                statPill(title: "Fillers", value: "\(session.fillerWordCount)", tint: .red)
                statPill(title: "Duration", value: "\(Int(session.duration))s", tint: .blue)
                statPill(title: "WPM", value: "\(session.wordsPerMinute)", tint: .indigo)
            }

            if let score = session.score {
                HStack(spacing: 10) {
                    statPill(title: "Score", value: "\(score)/10", tint: .green)
                    if let xp = session.xpEarned {
                        statPill(title: "XP", value: "\(xp)", tint: .orange)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private func statPill(title: String, value: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(tint.opacity(0.10), in: Capsule())
    }

    private var snapshotColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 0), spacing: 10),
            GridItem(.flexible(minimum: 0), spacing: 10)
        ]
    }

    private func snapshotCard(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tint)
                .lineLimit(3)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .padding(14)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func label(for mode: PracticeMode) -> String {
        switch mode {
        case .timed: return "Timed"
        case .suddenDeath: return "Sudden Death"
        case .ahCounter: return "Ah-Counter"
        }
    }

    private func shortFocusText(from text: String) -> String {
        if text.localizedCaseInsensitiveContains("filler") { return "Reduce fillers" }
        if text.localizedCaseInsensitiveContains("expand") { return "Build fuller answers" }
        if text.localizedCaseInsensitiveContains("structure") { return "Keep structure" }
        return "Stay consistent"
    }

    private func shortDrillText(from text: String) -> String {
        if text.localizedCaseInsensitiveContains("Sudden Death") { return "Sudden Death" }
        if text.localizedCaseInsensitiveContains("Ah-Counter") { return "Ah-Counter" }
        if text.localizedCaseInsensitiveContains("Easy") { return "Timed • Easy" }
        if text.localizedCaseInsensitiveContains("Medium") { return "Timed • Medium" }
        return "Timed Practice"
    }
}

private struct SessionHistoryDetailView: View {
    let session: PracticeSession
    let insights: [String]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.95, blue: 0.90),
                    Color.white,
                    Color(red: 0.92, green: 0.96, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(session.headline ?? "Session Detail")
                            .font(.title2.weight(.bold))
                        Text(session.coachSummary ?? "Review the transcript, score, and coaching notes from this practice run.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Session Metrics")
                            .font(.headline)
                        HStack(spacing: 10) {
                            metric(title: "Fillers", value: "\(session.fillerWordCount)", tint: .red)
                            metric(title: "Duration", value: "\(Int(session.duration))s", tint: .blue)
                            metric(title: "WPM", value: "\(session.wordsPerMinute)", tint: .indigo)
                            if let score = session.score {
                                metric(title: "Score", value: "\(score)/10", tint: .green)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        let identity = PracticeEvaluator.speakingIdentity(for: session.transcript, profile: CoachingProfileStore.shared.profile)
                        Text("Speaking Identity")
                            .font(.headline)
                        Text(identity.identity)
                            .font(.title3.weight(.bold))
                        Text(identity.coachingNote)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                    if let aiFeedback = session.aiCoachFeedback {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Coach Read")
                                .font(.headline)
                            Text("What you did well")
                                .font(.subheadline.weight(.semibold))
                            ForEach(aiFeedback.strengths, id: \.self) { strength in
                                Text("• \(strength)")
                                    .foregroundStyle(.secondary)
                            }
                            Text("Biggest improvement")
                                .font(.subheadline.weight(.semibold))
                            Text(aiFeedback.keyImprovement)
                                .foregroundStyle(.secondary)
                            Text("Suggested drill")
                                .font(.subheadline.weight(.semibold))
                            Text(aiFeedback.suggestedDrill)
                                .foregroundStyle(.secondary)
                            Text("Stronger opening")
                                .font(.subheadline.weight(.semibold))
                            Text(aiFeedback.revisedOpening)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text(session.aiCoachFeedback == nil ? "Session Signals" : "Supporting Signals")
                            .font(.headline)
                        ForEach(Array(insights.prefix(session.aiCoachFeedback == nil ? 3 : 2).enumerated()), id: \.offset) { index, insight in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(index + 1).")
                                    .fontWeight(.semibold)
                                Text(insight)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Transcript")
                            .font(.headline)
                        Text(session.transcript)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(Color(red: 0.97, green: 0.97, blue: 0.98), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                }
                .padding(18)
            }
        }
        .navigationTitle(session.date.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metric(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.86), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
#endif

#if canImport(SwiftUI)
#Preview {
    SessionHistoryView()
}
#endif
