#if canImport(SwiftUI)
import SwiftUI

// MARK: - Confetti Layer
//
// Reusable celebration particle system. Render-only; no state outside.
// Tap-the-screen behaviour and dismissal are the caller's concern — this
// layer just emits N particles, animates them, then disappears.
//
// Used by `FirstRepCelebration` and `PathNodeCelebration`. Tuned so a
// single celebration feels like a moment, not a screensaver: 28 pieces,
// 1.6s window, slight x-jitter + gravity-style fall.

@available(iOS 17.0, macOS 12.0, *)
struct ConfettiLayer: View {
    let active: Bool
    /// Override count for tighter or fuller bursts. Default tuned for
    /// the first-rep moment.
    var pieceCount: Int = 28
    /// How long the burst lasts before particles fully fade. The caller
    /// is responsible for tearing the layer down once this elapses.
    var duration: Double = 1.6

    @State private var pieces: [ConfettiPiece] = []

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(pieces) { piece in
                    pieceShape(piece)
                        .frame(width: piece.size, height: piece.size * 1.6)
                        .foregroundStyle(piece.color)
                        .position(
                            x: geo.size.width * piece.startX + (active ? piece.endXOffset : 0),
                            y: active ? geo.size.height * 1.05 : -40
                        )
                        .rotationEffect(.degrees(active ? piece.endRotation : piece.startRotation))
                        .opacity(active ? piece.endOpacity : 0)
                        .animation(
                            .easeOut(duration: duration)
                                .delay(piece.delay),
                            value: active
                        )
                }
            }
            .allowsHitTesting(false)
            .onAppear { generatePieces() }
        }
    }

    @ViewBuilder
    private func pieceShape(_ piece: ConfettiPiece) -> some View {
        switch piece.shape {
        case .ribbon:
            RoundedRectangle(cornerRadius: 1.5, style: .continuous)
        case .circle:
            Circle()
        case .star:
            Image(systemName: "sparkle")
                .font(.system(size: piece.size, weight: .bold))
        }
    }

    private func generatePieces() {
        guard pieces.isEmpty else { return }
        let palette: [Color] = [
            AppColor.brandBlue,
            AppColor.brandBlueLight,
            AppColor.positive,
            AppColor.modeSuddenDeath,
            AppColor.pro,
            AppColor.proLight
        ]
        pieces = (0..<pieceCount).map { i in
            ConfettiPiece(
                id: i,
                startX: Double.random(in: 0.05...0.95),
                endXOffset: Double.random(in: -60...60),
                startRotation: Double.random(in: -45...45),
                endRotation: Double.random(in: -540...540),
                size: Double.random(in: 6...11),
                color: palette.randomElement() ?? AppColor.brandBlue,
                shape: ConfettiPiece.Shape.allCases.randomElement() ?? .ribbon,
                delay: Double.random(in: 0.0...0.15),
                endOpacity: Double.random(in: 0.7...0.95)
            )
        }
    }
}

private struct ConfettiPiece: Identifiable {
    let id: Int
    let startX: Double
    let endXOffset: Double
    let startRotation: Double
    let endRotation: Double
    let size: Double
    let color: Color
    let shape: Shape
    let delay: Double
    let endOpacity: Double

    enum Shape: CaseIterable { case ribbon, circle, star }
}

#endif
