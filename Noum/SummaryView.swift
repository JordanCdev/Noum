import Foundation
#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 12.0, *)
struct SummaryView: View {
    let transcript: AttributedString
    let fillerCount: Int
    let duration: TimeInterval
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
            Button("New Practice Session") {
                onNewSession()
                dismiss()
            }
        }
        .padding()
    }
}
#Preview {
    SummaryView(transcript: AttributedString("Example"), fillerCount: 0, duration: 0)
}
#endif
