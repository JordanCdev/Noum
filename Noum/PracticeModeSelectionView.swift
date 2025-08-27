import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

enum PracticeMode: String, Codable {
    case timed
    case suddenDeath
    case ahCounter
}

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 12.0, *)
struct PracticeModeSelectionView: View {
    @Binding var selectedMode: PracticeMode
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
            Toggle(isOn: Binding(
                get: { selectedMode == .ahCounter },
                set: { if $0 { selectedMode = .ahCounter } }
            )) {
                Label("Ah-Counter", systemImage: "ear")
            }
        }
        .navigationTitle("Practice Modes")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink("Start") {
                    switch selectedMode {
                    case .timed:
                        TimedPracticeView()
                    case .suddenDeath:
                        SuddenDeathPracticeView()
                    case .ahCounter:
                        AhCounterView()
                    }
                }
            }
        }
    }
}
#endif
