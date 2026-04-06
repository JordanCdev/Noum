import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
struct ShimmerProgressBar: View {
    let progress: Double
    var tint: Color
    var track: Color = Color.black.opacity(0.08)
    var animated: Bool = true

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width * min(max(progress, 0), 1), 10)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(track)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.85), tint, tint.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
                    .overlay(alignment: .leading) {
                        if animated {
                            TimelineView(.animation(minimumInterval: 1 / 24.0)) { timeline in
                                let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
                                let shimmerX = (width + 44) * phase - 22

                                Capsule()
                                    .fill(.white.opacity(0.35))
                                    .frame(width: 26)
                                    .blur(radius: 4)
                                    .offset(x: shimmerX)
                                    .mask(
                                        Capsule()
                                            .frame(width: width)
                                    )
                            }
                        } else {
                            Capsule()
                                .fill(.white.opacity(0.18))
                                .frame(width: min(width * 0.28, 30))
                                .offset(x: min(width * 0.16, 14))
                                .mask(
                                    Capsule()
                                        .frame(width: width)
                                )
                        }
                    }
            }
        }
        .frame(height: 12)
    }
}

struct PulseBadge: View {
    let systemImage: String
    let tint: Color
    var animated: Bool = true

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1 / 18.0)) { timeline in
                    let phase = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.8) / 1.8
                    let scale = 0.92 + (sin(phase * .pi * 2) + 1) * 0.06

                    badge(scale: scale)
                }
            } else {
                badge(scale: 1.0)
            }
        }
        .frame(width: 56, height: 56)
    }

    private func badge(scale: Double) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.12))
                .frame(width: 48, height: 48)
                .scaleEffect(scale + 0.08)
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: 1.5)
                .frame(width: 54, height: 54)
                .scaleEffect(scale + 0.12)
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tint)
        }
    }
}

struct SparkleRibbon: View {
    let tint: Color
    var animated: Bool = true

    var body: some View {
        Group {
            if animated {
                TimelineView(.animation(minimumInterval: 1 / 20.0)) { timeline in
                    ribbon(phase: timeline.date.timeIntervalSinceReferenceDate)
                }
            } else {
                ribbon(phase: 0)
            }
        }
    }

    private func ribbon(phase: Double) -> some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { index in
                let offset = phase + Double(index) * 0.23
                let scale = 0.8 + (sin(offset * 2.2) + 1) * 0.12
                let opacity = 0.35 + (cos(offset * 2.0) + 1) * 0.2

                Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "star.fill")
                    .font(.system(size: index.isMultiple(of: 2) ? 9 : 7, weight: .bold))
                    .foregroundStyle(tint.opacity(opacity))
                    .scaleEffect(scale)
            }
        }
    }
}
#endif
