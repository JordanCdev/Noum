import SwiftUI

struct SummaryView: View {
    let transcript: AttributedString
    let fillerCount: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            ScrollView {
                Text(transcript)
                    .padding()
            }
            Text("Filler Words: \(fillerCount)")
                .font(.headline)
            Button("New Practice Session") {
                dismiss()
            }
        }
        .padding()
    }
}

#Preview {
    SummaryView(transcript: AttributedString("Example"), fillerCount: 0)
}
