#if canImport(ActivityKit) && canImport(WidgetKit)
import ActivityKit
import WidgetKit
import SwiftUI

// MARK: - Practice Live Activity
//
// Shows during an in-progress Pressure Drill (Sudden Death) so the user
// sees rounds + remaining time on the lock screen and Dynamic Island
// without keeping the app foregrounded.
//
// Activity is started by `PressureLiveActivityCoordinator` (in the main
// app target), updated as the round progresses, and ended when the
// session finishes. The widget extension owns the *rendering* — this
// file is purely UI + attributes.

// Attributes are defined in the shared file `PracticeLiveActivityAttributes.swift`
// which is added to both the Noum and NoumWidget targets so ActivityKit
// resolves the exact same type across IPC.

// MARK: - Widget configuration

struct PracticeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PracticeLiveActivityAttributes.self) { context in
            // Lock-screen / banner presentation
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.18))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            // Dynamic Island
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text("Round \(context.state.roundNumber)/\(context.state.totalRounds)")
                            .font(.caption.weight(.bold))
                    } icon: {
                        Image(systemName: "bolt.fill")
                            .foregroundStyle(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Label {
                        Text("\(context.state.fillerCount) filler\(context.state.fillerCount == 1 ? "" : "s")")
                            .font(.caption.weight(.bold))
                    } icon: {
                        Image(systemName: "speaker.slash.fill")
                            .foregroundStyle(.yellow)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.state.phase)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(context.state.secondsRemaining)s")
                            .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(.white)
                    }
                }
            } compactLeading: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text("\(context.state.secondsRemaining)s")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.white)
            } minimal: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<PracticeLiveActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: "bolt.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(context.attributes.modeLabel)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))
                    .textCase(.uppercase)
                    .tracking(0.6)
                Text(context.state.phase)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Round \(context.state.roundNumber)/\(context.state.totalRounds) · \(context.state.fillerCount) filler\(context.state.fillerCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(context.state.secondsRemaining)s")
                    .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                Text("Remaining")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.65))
                    .textCase(.uppercase)
                    .tracking(0.6)
            }
        }
        .padding(14)
    }
}

#endif
