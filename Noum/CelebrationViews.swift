#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Personal Best Celebration Screen

struct PersonalBestCelebrationScreen: View {
    let scoreValue: Int
    let scoreAccent: Color
    let modeName: String
    let previousBest: String?
    let onContinue: () -> Void
    /// Optional transcript-anchored proof of growth. When present,
    /// renders below the previousBest line as a small italicized
    /// quote + technique chip. When nil the row is hidden — the
    /// celebration never invents a quote it doesn't have.
    var proof: ProofMoment? = nil

    @State private var phase1 = false  // score ring
    @State private var phase2 = false  // text
    @State private var phase3 = false  // particles
    @State private var starRotation: Double = 0

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.black,
                    scoreAccent.opacity(0.15),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Floating particles
            if phase3 {
                particleField
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                Spacer()

                // Star icon
                ZStack {
                    // Outer glow rings
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(scoreAccent.opacity(phase1 ? 0.15 - Double(i) * 0.04 : 0), lineWidth: 2)
                            .frame(width: CGFloat(160 + i * 40), height: CGFloat(160 + i * 40))
                            .scaleEffect(phase1 ? 1.0 : 0.5)
                    }

                    // Score ring
                    Circle()
                        .stroke(scoreAccent.opacity(0.2), lineWidth: 10)
                        .frame(width: 140, height: 140)

                    Circle()
                        .trim(from: 0, to: phase1 ? Double(scoreValue) / 10.0 : 0)
                        .stroke(scoreAccent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(-90))

                    // Star
                    Image(systemName: "star.fill")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(scoreAccent)
                        .scaleEffect(phase1 ? 1.0 : 0.1)
                        .rotationEffect(.degrees(starRotation))
                }

                Spacer().frame(height: 40)

                // Title
                VStack(spacing: 12) {
                    Text("NEW PERSONAL BEST")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .tracking(3)
                        .foregroundStyle(scoreAccent)
                        .opacity(phase2 ? 1 : 0)
                        .offset(y: phase2 ? 0 : 20)

                    Text("\(scoreValue)/10")
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(phase2 ? 1 : 0)
                        .scaleEffect(phase2 ? 1.0 : 0.7)

                    Text(modeName)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.7))
                        .opacity(phase2 ? 1 : 0)
                        .offset(y: phase2 ? 0 : 10)

                    if let previousBest {
                        Text(previousBest)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.4))
                            .opacity(phase2 ? 1 : 0)
                            .padding(.top, 4)
                    }

                    if let proof = proof {
                        VStack(spacing: 6) {
                            Text("\u{201C}\(proof.quote)\u{201D}")
                                .font(.system(size: 16, weight: .regular, design: .default))
                                .italic()
                                .foregroundStyle(.white.opacity(0.78))
                                .multilineTextAlignment(.center)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 24)
                            Text(proof.technique.uppercased())
                                .font(.system(size: 11, weight: .heavy, design: .rounded))
                                .tracking(1.2)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        .opacity(phase2 ? 1 : 0)
                        .padding(.top, 20)
                    }
                }

                Spacer()

                // Continue button
                Button {
                    onContinue()
                } label: {
                    Text("View Results")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(scoreAccent, in: Capsule())
                }
                .buttonStyle(.pressable)
                .opacity(phase2 ? 1 : 0)
                .offset(y: phase2 ? 0 : 30)
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear { runAnimation() }
    }

    private func runAnimation() {
#if canImport(UIKit)
        // Initial heavy haptic
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred()
#endif

        // Phase 1: Score ring + star scale in
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            phase1 = true
        }
        withAnimation(.easeInOut(duration: 1.2)) {
            starRotation = 360
        }

#if canImport(UIKit)
        // Haptic burst during animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
#endif

        // Phase 2: Text fades in
        withAnimation(.easeOut(duration: 0.5).delay(0.5)) {
            phase2 = true
        }

        // Phase 3: Particles
        withAnimation(.easeIn(duration: 0.3).delay(0.7)) {
            phase3 = true
        }
    }

    private var particleField: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 20.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<20, id: \.self) { i in
                        let seed = Double(i) * 1.618
                        let x = geo.size.width * (0.05 + (seed.truncatingRemainder(dividingBy: 0.9)))
                        let speed = 0.8 + seed.truncatingRemainder(dividingBy: 1.2)
                        let travel = (t * speed).truncatingRemainder(dividingBy: 4.0) / 4.0
                        let y = geo.size.height * (1.0 - travel)

                        Image(systemName: i.isMultiple(of: 3) ? "sparkle" : i.isMultiple(of: 2) ? "star.fill" : "circle.fill")
                            .font(.system(size: CGFloat(4 + (i % 5) * 2)))
                            .foregroundStyle(scoreAccent.opacity(0.3 * (1.0 - travel)))
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Level Up Celebration Screen

struct LevelUpCelebrationScreen: View {
    let newLevel: String
    let previousLevel: String
    let xpProgress: Double  // 0...1 towards next sub-level
    let onContinue: () -> Void

    @State private var phase1 = false
    @State private var phase2 = false
    @State private var phase3 = false
    @State private var ringRotation: Double = 0

    private var levelTint: Color {
        if newLevel.contains("Beginner") { return .blue }
        if newLevel.contains("Novice") { return .teal }
        if newLevel.contains("Average") { return .indigo }
        if newLevel.contains("Professional") { return .orange }
        return .yellow
    }

    private var levelIcon: String {
        if newLevel.contains("Beginner") { return "sparkles" }
        if newLevel.contains("Novice") { return "figure.stand" }
        if newLevel.contains("Average") { return "waveform.path.ecg" }
        if newLevel.contains("Professional") { return "shield.lefthalf.filled" }
        return "crown.fill"
    }

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [
                    Color.black,
                    levelTint.opacity(0.12),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Floating particles
            if phase3 {
                levelUpParticles
                    .transition(.opacity)
            }

            VStack(spacing: 0) {
                Spacer()

                // Icon with rings
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(levelTint.opacity(phase1 ? 0.12 - Double(i) * 0.03 : 0), lineWidth: 1.5)
                            .frame(width: CGFloat(150 + i * 35), height: CGFloat(150 + i * 35))
                            .scaleEffect(phase1 ? 1.0 : 0.4)
                    }

                    Circle()
                        .fill(levelTint.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(phase1 ? 1.0 : 0.5)

                    Circle()
                        .stroke(levelTint.opacity(0.3), lineWidth: 4)
                        .frame(width: 120, height: 120)
                        .scaleEffect(phase1 ? 1.0 : 0.5)

                    Image(systemName: levelIcon)
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(levelTint)
                        .scaleEffect(phase1 ? 1.0 : 0.1)
                        .rotationEffect(.degrees(ringRotation))
                }

                Spacer().frame(height: 44)

                // Text content
                VStack(spacing: 14) {
                    Text("LEVEL UP")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(levelTint)
                        .opacity(phase2 ? 1 : 0)
                        .offset(y: phase2 ? 0 : 20)

                    Text(newLevel)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .opacity(phase2 ? 1 : 0)
                        .scaleEffect(phase2 ? 1.0 : 0.8)

                    Text("Previously: \(previousLevel)")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.4))
                        .opacity(phase2 ? 1 : 0)
                        .offset(y: phase2 ? 0 : 10)

                    Text("Keep practicing to reach the next rank")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.3))
                        .opacity(phase2 ? 1 : 0)
                        .padding(.top, 4)
                }

                Spacer()

                // Continue button
                Button {
                    onContinue()
                } label: {
                    Text("View Results")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(levelTint, in: Capsule())
                }
                .buttonStyle(.pressable)
                .opacity(phase2 ? 1 : 0)
                .offset(y: phase2 ? 0 : 30)
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear { runLevelUpAnimation() }
    }

    private func runLevelUpAnimation() {
#if canImport(UIKit)
        let heavy = UIImpactFeedbackGenerator(style: .heavy)
        heavy.prepare()
        heavy.impactOccurred()
#endif

        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            phase1 = true
        }
        withAnimation(.easeInOut(duration: 1.0)) {
            ringRotation = 360
        }

#if canImport(UIKit)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
#endif

        withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
            phase2 = true
        }
        withAnimation(.easeIn(duration: 0.3).delay(0.6)) {
            phase3 = true
        }
    }

    private var levelUpParticles: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1 / 20.0)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<16, id: \.self) { i in
                        let seed = Double(i) * 1.618
                        let x = geo.size.width * (0.05 + (seed.truncatingRemainder(dividingBy: 0.9)))
                        let speed = 0.6 + seed.truncatingRemainder(dividingBy: 1.0)
                        let travel = (t * speed).truncatingRemainder(dividingBy: 5.0) / 5.0
                        let y = geo.size.height * (1.0 - travel)

                        Image(systemName: i.isMultiple(of: 3) ? "arrow.up" : i.isMultiple(of: 2) ? "sparkle" : "circle.fill")
                            .font(.system(size: CGFloat(3 + (i % 4) * 2)))
                            .foregroundStyle(levelTint.opacity(0.25 * (1.0 - travel)))
                            .position(x: x, y: y)
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

#endif
