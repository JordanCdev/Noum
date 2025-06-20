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
                if authManager.isSignedIn {
                    Button("Sign Out") {
                        authManager.signOut()
                    }
                } else {
                    #if canImport(UIKit)
                    Button("Sign in with Google") {
                        if let root = UIApplication.shared.windows.first?.rootViewController {
                            authManager.signInWithGoogle(presenting: root)
                        }
                    }
                    #endif
                    Button("Sign in with Apple") {
                        authManager.signInWithApple()
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
