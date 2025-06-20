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
        NavigationView {
            VStack(spacing: 20) {
                Text(authManager.isSignedIn ? "Signed in" : "Not signed in")
                    .accessibilityIdentifier("signInState")
                Button("Refresh") {
                    authManager.reloadCredentials()
                }
                if authManager.isSignedIn {
                    Button("Clear") {
                        authManager.signOut()
                    }
                }
            }
            .padding()
            .navigationTitle("Settings")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}
#endif
