#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 17.0, macOS 12.0, *)
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if authManager.isSignedIn {
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
        .onChange(of: authManager.isSignedIn) { signedIn in
            if !signedIn { dismiss() }
        }
    }
}
#endif
