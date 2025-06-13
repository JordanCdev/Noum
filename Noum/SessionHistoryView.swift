import SwiftUI

struct SessionHistoryView: View {
    @ObservedObject var speechVM: SpeechRecognizerViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(speechVM.pastSessions) { session in
                VStack(alignment: .leading) {
                    Text(session.date, style: .date)
                        .font(.headline)
                    Text("Duration: \(Int(session.duration))s")
                    Text("Filler Words: \(session.fillerWordCount)")
                    Text(session.transcript)
                        .lineLimit(2)
                }
            }
            .navigationTitle("Practice History")
            .toolbar {
                Button("Close") { dismiss() }
            }
        }
    }
}

#Preview {
    SessionHistoryView(speechVM: SpeechRecognizerViewModel())
}
