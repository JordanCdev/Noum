import SwiftUI
#if os(watchOS)
import WatchKit
#endif

// MARK: - WatchHomeView
//
// One-screen glance for the watch. Reads `SharedNoumState` from the
// App Group at view creation and refreshes when the scene becomes
// active (the watch will dispatch `.scenePhase` changes whenever the
// user raises their wrist or returns from another complication).
//
// Layout, top to bottom:
//  1. Streak header — flame + Nd, snowflake if a freeze is available
//  2. Reps ring — repsToday / goalReps, same gradient as the iOS
//     `SmallWidgetView` for visual continuity
//  3. CTA — single tap target that opens the iPhone via
//     `WKExtension.openSystemURL(noum://practice)`
//
// Voice: short, declarative, no chirp. Matches the watch widget tone.

struct WatchHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var snapshot: SharedNoumState = SharedNoumState.read()

    var body: some View {
        VStack(spacing: 8) {
            StreakHeader(snapshot: snapshot)
            RepsRing(snapshot: snapshot, reduceMotion: reduceMotion)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            OpenOnPhoneButton()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                snapshot = SharedNoumState.read()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        let streak = snapshot.currentStreak
        let reps = snapshot.repsToday
        let goal = snapshot.goalReps
        return "Streak \(streak) days. \(reps) of \(goal) reps today."
    }
}

// MARK: - Streak header

private struct StreakHeader: View {
    let snapshot: SharedNoumState

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill")
                .font(.caption.weight(.bold))
                .foregroundStyle(.orange)
            Text("\(snapshot.currentStreak)d")
                .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            if snapshot.freezesAvailable > 0 {
                Image(systemName: "snowflake")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.cyan)
                    .accessibilityLabel("Freeze available")
            }
        }
    }
}

// MARK: - Reps ring

private struct RepsRing: View {
    let snapshot: SharedNoumState
    let reduceMotion: Bool

    private var progress: CGFloat {
        guard snapshot.goalReps > 0 else { return 0 }
        return min(1, CGFloat(snapshot.repsToday) / CGFloat(snapshot.goalReps))
    }

    private var footerCopy: String {
        if snapshot.repsToday >= snapshot.goalReps { return "Goal hit" }
        if snapshot.currentStreak == 0 { return "Today is rep one" }
        return "Hold the streak"
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.18), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(
                            colors: [Color.blue, Color.cyan],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: progress)
                VStack(spacing: 0) {
                    Text("\(snapshot.repsToday)")
                        .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("of \(snapshot.goalReps)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 8)

            Text(footerCopy)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

// MARK: - Open-on-phone CTA

private struct OpenOnPhoneButton: View {
    var body: some View {
        Button(action: openOnPhone) {
            HStack(spacing: 4) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.caption2.weight(.bold))
                Text("Open on iPhone")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
        .accessibilityLabel("Open Noum on iPhone")
    }

    private func openOnPhone() {
        #if os(watchOS)
        guard let url = URL(string: "noum://practice") else { return }
        WKExtension.shared().openSystemURL(url)
        #endif
    }
}
