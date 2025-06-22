import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(SwiftUI)

struct SummaryView: View {
    let transcript: AttributedString
    let fillerCount: Int
    let duration: TimeInterval
    let score: Int?
    let progressSegments: Int
    var showDuration: Bool = true
    var onSelectPracticeMode: () -> Void = {}
    var onHome: () -> Void = {}
    @StateObject private var profile = ProfileManager.shared

    private var feedback: String? {
        guard score != nil else { return nil }
        switch fillerCount {
        case 0...1:
            return "Outstanding! World-class speaking with almost no filler words."
        case 2...3:
            return "Great job! You're nearing professional level."
        case 4...5:
            return "Good work. About average filler usage."
        case 6...8:
            return "Fair effort. Try to reduce filler words."
        default:
            return "Keep practicing to minimize filler words."
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(transcript)
                    .padding()
            }
            Text("Filler Words: \(fillerCount)")
                .font(.headline)
            if showDuration {
                Text("Duration: \(Int(duration))s")
                    .font(.subheadline)
            }
            if let score {
                if showBronze {
                    Text("Bronze +1")
                        .transition(.opacity)
                }
                if showSilver {
                    Text("Silver +1")
                        .transition(.opacity)
                }
                if showGold {
                    Text("Gold +1")
                        .transition(.opacity)
                }
                if showFiller {
                    Text("Filler Words -\(fillerCount)")
                        .transition(.opacity)
                }
                if showScore {
                    Text("Score: \(score)/10")
                        .font(.title2)
                        .transition(.opacity)
                }
                if showXP {
                    Text("XP Earned: \(score * 10)")
                        .transition(.opacity)
                    VStack {
                        Text("Level: \(profile.levelTitle)")
                        ProgressView(value: profile.progressTowardsNextLevel)
                            .tint(.blue)
                    }
                    .transition(.opacity)
                }
            }
            if let feedback {
                Text(feedback)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
        }
        .padding()
        .onAppear(perform: animateBreakdown)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Practice Mode") { onSelectPracticeMode() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Home") { onHome() }
            }
        }
    }

    @State private var showBronze = false
    @State private var showSilver = false
    @State private var showGold = false
    @State private var showFiller = false
    @State private var showScore = false
    @State private var showXP = false

    private func animateBreakdown() {
        guard score != nil else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showBronze = progressSegments > 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showSilver = progressSegments > 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showGold = progressSegments > 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { showFiller = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { showScore = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { showXP = true }
    }
}

#endif

#if canImport(SwiftUI)
#Preview {
    SummaryView(
        transcript: AttributedString("Example"),
        fillerCount: 0,
        duration: 0,
        score: 7,
        progressSegments: 3,
        showDuration: false
    )
}
#endif
