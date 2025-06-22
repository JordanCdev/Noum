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
    var showDuration: Bool = true
    var onNewSession: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

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
                Text("Score: \(score)")
                    .font(.title2)
            }
            if let feedback {
                Text(feedback)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)
            }
            Button("New Practice Session") {
                onNewSession()
                dismiss()
            }
        }
        .padding()
    }
}

#endif

#if canImport(SwiftUI)
#Preview {
    SummaryView(transcript: AttributedString("Example"), fillerCount: 0, duration: 0, score: 100, showDuration: false)
}
#endif
