import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(SwiftUI)

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
                    Text("Transcript: \(session.transcript)")
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .navigationTitle("Practice History")
            .toolbar {
                Button("Close") { dismiss() }
            }
        }
    }
}
#endif

#if canImport(SwiftUI)
#Preview {
    SessionHistoryView(speechVM: SpeechRecognizerViewModel())
}
#endif
