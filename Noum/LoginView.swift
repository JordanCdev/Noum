#if canImport(SwiftUI)
import SwiftUI
#if canImport(GoogleSignInSwift)
import GoogleSignInSwift
#endif

@available(iOS 17.0, macOS 12.0, *)
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared
    @State private var showError = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                header
                signInButtons
                Spacer()
            }
            .padding()
            .navigationTitle("")
        }
        .onChange(of: authManager.isSignedIn) { signedIn in
            if signedIn { dismiss() }
        }
        .alert("Sign In Failed", isPresented: $showError, actions: {
            Button("OK", role: .cancel) { authManager.signInError = nil }
        }, message: {
            Text(authManager.signInError ?? "Unknown error")
        })
        .onChange(of: authManager.signInError) { err in
            showError = err != nil
        }
    }

    private var header: some View {
        VStack {
            Spacer()
            Text("Welcome to Noum")
                .font(.largeTitle)
                .bold()
            Spacer()
        }
    }

    private var signInButtons: some View {
        VStack(spacing: 20) {
            Text("Already have an account?")
#if canImport(GoogleSignInSwift)
            GoogleSignInButton(action: { authManager.startGoogleSignIn() })
                .frame(height: 45)
#elseif canImport(GoogleSignIn)
            Button("Sign in with Google") {
                authManager.startGoogleSignIn()
            }
#else
            Button("Sign in with Google") { }
#endif
        }
    }
}
#endif
