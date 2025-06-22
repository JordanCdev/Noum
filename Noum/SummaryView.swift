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
    var onNewSession: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(transcript)
                    .padding()
            }
            Text("Filler Words: \(fillerCount)")
                .font(.headline)
            Text("Duration: \(Int(duration))s")
                .font(.subheadline)
            if let score {
                Text("Score: \(score)")
                    .font(.title2)
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
    SummaryView(transcript: AttributedString("Example"), fillerCount: 0, duration: 0, score: 100)
}
#endif
