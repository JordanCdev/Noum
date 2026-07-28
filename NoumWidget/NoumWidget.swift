#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

// MARK: - Noum Lock-Screen + Home Widget
//
// Renders the user's daily-rhythm state outside the app — streak count,
// today's goal progress, freezes available. Reads from the App Group
// `group.uk.co.otherpath.noum` via `SharedNoumState`.
//
// Sizes shipped:
//  - **systemSmall** (home + lock-screen iOS 16+): 2×2 — streak ring + reps today
//  - **systemMedium** (home): wider — streak + reps + rating + next CTA
//  - **accessoryCircular** (lock screen, iOS 16+): minimal streak/goal ring
//  - **accessoryRectangular** (lock screen, iOS 16+): streak + reps inline
//  - **accessoryInline** (lock screen): one-liner
//
// The widget is read-only; tapping deep-links to the home screen via
// `noum://` URL handled by the main app.

// MARK: - Entry

struct NoumWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: SharedNoumState
}

// MARK: - Provider

struct NoumWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> NoumWidgetEntry {
        NoumWidgetEntry(date: Date(), snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (NoumWidgetEntry) -> Void) {
        completion(NoumWidgetEntry(date: Date(), snapshot: SharedNoumState.read()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NoumWidgetEntry>) -> Void) {
        // Refresh the widget once an hour. The system can throttle further;
        // calls into the App Group every refresh are essentially free.
        let entry = NoumWidgetEntry(date: Date(), snapshot: SharedNoumState.read())
        let nextRefresh = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}

// MARK: - Widget

struct NoumWidget: Widget {
    let kind: String = "NoumWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NoumWidgetProvider()) { entry in
            NoumWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Noum")
        .description("See today's goal and streak at a glance.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

// MARK: - Entry View (size dispatch)

struct NoumWidgetEntryView: View {
    let entry: NoumWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(snapshot: entry.snapshot)
        case .systemMedium:
            MediumWidgetView(snapshot: entry.snapshot)
        case .accessoryCircular:
            AccessoryCircularView(snapshot: entry.snapshot)
        case .accessoryRectangular:
            AccessoryRectangularView(snapshot: entry.snapshot)
        case .accessoryInline:
            AccessoryInlineView(snapshot: entry.snapshot)
        default:
            SmallWidgetView(snapshot: entry.snapshot)
        }
    }
}

// MARK: - Small (home / lock-screen)

private struct SmallWidgetView: View {
    let snapshot: SharedNoumState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.orange)
                Text("\(snapshot.currentStreak)d")
                    .font(.system(size: 16, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.primary)
                Spacer()
                if snapshot.freezesAvailable > 0 {
                    Image(systemName: "snowflake")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                }
            }

            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(snapshot.repsToday)")
                        .font(.system(size: 28, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("of \(snapshot.goalReps)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            Text(footerCopy)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var progress: CGFloat {
        guard snapshot.goalReps > 0 else { return 0 }
        return min(1, CGFloat(snapshot.repsToday) / CGFloat(snapshot.goalReps))
    }

    private var footerCopy: String {
        if snapshot.repsToday >= snapshot.goalReps { return "Goal hit" }
        if snapshot.currentStreak == 0 { return "Today is rep one" }
        return "Hold the streak"
    }
}

// MARK: - Medium (home)

private struct MediumWidgetView: View {
    let snapshot: SharedNoumState

    var body: some View {
        HStack(spacing: 16) {
            // Left: ring
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.15), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        LinearGradient(colors: [Color.blue, Color.cyan], startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(snapshot.repsToday)")
                        .font(.system(size: 30, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.primary)
                    Text("of \(snapshot.goalReps)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 90, height: 90)

            // Right: stats column
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                    Text("\(snapshot.currentStreak)-day streak")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    if snapshot.freezesAvailable > 0 {
                        Image(systemName: "snowflake")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.blue)
                    }
                }
                HStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.blue)
                    Text("Rating \(snapshot.rating)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.purple)
                    Text("\(snapshot.weeklyReps) reps this week")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Text(actionCopy)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue, in: Capsule())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var progress: CGFloat {
        guard snapshot.goalReps > 0 else { return 0 }
        return min(1, CGFloat(snapshot.repsToday) / CGFloat(snapshot.goalReps))
    }

    private var actionCopy: String {
        if snapshot.repsToday >= snapshot.goalReps { return "Stack a second rep" }
        if snapshot.currentStreak == 0 { return "Take your first rep" }
        return "Hold the streak"
    }
}

// MARK: - Accessory (lock-screen iOS 16+)

private struct AccessoryCircularView: View {
    let snapshot: SharedNoumState

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.caption2.weight(.bold))
                Text("\(snapshot.currentStreak)")
                    .font(.system(size: 14, weight: .bold, design: .rounded).monospacedDigit())
            }
        }
    }

    private var progress: CGFloat {
        guard snapshot.goalReps > 0 else { return 0 }
        return min(1, CGFloat(snapshot.repsToday) / CGFloat(snapshot.goalReps))
    }
}

private struct AccessoryRectangularView: View {
    let snapshot: SharedNoumState

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption2.weight(.bold))
                Text("\(snapshot.currentStreak)-day streak")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            Text("\(snapshot.repsToday)/\(snapshot.goalReps) reps today")
                .font(.caption2.weight(.semibold))
            Text(snapshot.repsToday >= snapshot.goalReps ? "Goal hit" : "Hold the streak")
                .font(.caption2)
        }
    }
}

private struct AccessoryInlineView: View {
    let snapshot: SharedNoumState

    var body: some View {
        Text("Noum · \(snapshot.currentStreak)d streak · \(snapshot.repsToday)/\(snapshot.goalReps)")
    }
}

#endif
