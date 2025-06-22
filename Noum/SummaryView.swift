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
    let xpEarned: Int
    var showDuration: Bool = true
    var onSelectPracticeMode: () -> Void = {}
    var onHome: () -> Void = {}
    var onPracticeAgain: () -> Void = {}
    @StateObject private var profile = ProfileManager.shared
    @State private var startXP: Int = 0
    @State private var displayedXP: Int = 0
    @State private var progress: Double = 0
    @State private var displayedScore: Int = 0
    @State private var displayedEarnedXP: Int = 0
    @State private var currentLevel: String = ""
    @State private var nextLevel: String = ""
    @State private var xpToNext: Int = 0

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
            if score != nil {
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
                    Text("Score: \(displayedScore)/10")
                        .font(.title2)
                        .transition(.opacity)
                }
                if showXP {
                    Text("XP Earned: \(displayedEarnedXP)")
                        .transition(.opacity)
                    VStack(alignment: .leading) {
                        HStack {
                            Text(currentLevel)
                            Spacer()
                            Text(nextLevel)
                        }
                        ProgressView(value: progress)
                            .tint(.blue)
                        HStack {
                            Text("\(displayedXP) XP")
                            Spacer()
                            Text("\(xpToNext) to level up")
                        }
                    }
                    .transition(.opacity)
                }
            }
            if let feedback {
                Text(feedback)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            Button("Practice Again") { onPracticeAgain() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Summary")
        .onAppear(perform: setupAndAnimate)
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

    private func setupAndAnimate() {
        guard score != nil else { return }
        startXP = profile.xp
        displayedXP = startXP
        currentLevel = ProfileManager.levelTitle(forXP: startXP)
        nextLevel = ProfileManager.levelTitle(forXP: ((startXP / 1000) + 1) * 1000)
        xpToNext = ProfileManager.xpNeededToNextLevel(forXP: startXP)
        progress = ProfileManager.progressTowardsNextLevel(forXP: startXP)

        profile.addXP(xpEarned)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showBronze = progressSegments > 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { showSilver = progressSegments > 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { showGold = progressSegments > 2 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { showFiller = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            showScore = true
            animateScore()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            showXP = true
            animateXPEarned()
            animateProgress()
        }
    }

    private func animateScore() {
        guard let score else { return }
        Task {
            for i in 0...score {
                await MainActor.run { displayedScore = i }
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func animateXPEarned() {
        Task {
            for i in 0...xpEarned {
                await MainActor.run { displayedEarnedXP = i }
                try? await Task.sleep(for: .milliseconds(5))
            }
        }
    }

    private func animateProgress() {
        let endXP = startXP + xpEarned
        Task {
            for xp in stride(from: startXP, through: endXP, by: 1) {
                await MainActor.run {
                    displayedXP = xp
                    progress = ProfileManager.progressTowardsNextLevel(forXP: xp)
                }
                try? await Task.sleep(for: .milliseconds(5))
            }
            await MainActor.run {
                currentLevel = ProfileManager.levelTitle(forXP: endXP)
                nextLevel = ProfileManager.levelTitle(forXP: ((endXP / 1000) + 1) * 1000)
                xpToNext = ProfileManager.xpNeededToNextLevel(forXP: endXP)
            }
        }
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
        xpEarned: 70,
        showDuration: false,
        onPracticeAgain: {}
    )
}
#endif
