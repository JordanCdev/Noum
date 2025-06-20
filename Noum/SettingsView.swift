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
                Text(authManager.isSignedIn ? "AWS credentials loaded" : "AWS credentials missing")
                    .accessibilityIdentifier("signInState")
                Button("Reload Credentials") {
                    authManager.reloadCredentials()
                }
                if authManager.isSignedIn {
                    Button("Clear Credentials") {
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
