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
                VStack(alignment: .leading, spacing: 2) {
                    Text(session.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.headline)
                    Text("Duration: \(Int(session.duration))s \u{2022} Filler Words: \(session.fillerWordCount)")
                        .font(.subheadline)
                    Text(session.transcript)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
