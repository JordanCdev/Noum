import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum PracticeMode: String, Codable {
    case timed
    case suddenDeath
}

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct PracticeModeSelectionView: View {
    @Binding var selectedMode: PracticeMode
    var startPractice: () -> Void
    var body: some View {
        Form {
            Toggle(isOn: Binding(
                get: { selectedMode == .timed },
                set: { if $0 { selectedMode = .timed } }
            )) {
                Label("Timed Practice", systemImage: "clock")
            }
            Toggle(isOn: Binding(
                get: { selectedMode == .suddenDeath },
                set: { if $0 { selectedMode = .suddenDeath } }
            )) {
                Label("Sudden-Death", systemImage: "bolt.fill")
            }
        }
        .navigationTitle("Practice Modes")
        .toolbar {
            Button("Start") { startPractice() }
        }

    }
}
#endif
