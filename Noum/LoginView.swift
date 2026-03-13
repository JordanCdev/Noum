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
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.96, green: 0.93, blue: 0.88),
                        Color.white,
                        Color(red: 0.90, green: 0.95, blue: 0.99)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()
                    headerCard
                    signInCard
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("")
        }
        .onChange(of: authManager.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
        .alert("Sign In Failed", isPresented: $showError, actions: {
            Button("OK", role: .cancel) { authManager.signInError = nil }
        }, message: {
            Text(authManager.signInError ?? "Unknown error")
        })
        .onChange(of: authManager.signInError) { _, err in
            showError = err != nil
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speak with less friction")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            Text("Welcome to Noum")
                .font(.system(size: 38, weight: .bold, design: .rounded))

            Text("Practice answers out loud, catch filler words in real time, and build repeatable speaking confidence.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var signInCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("Continue with your account", systemImage: "person.crop.circle.badge.checkmark")
                .font(.headline)

            Text("Google sign-in keeps your progress tied to one identity across sessions on this device.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            signInButtons

            Text("By continuing, you’re entering the practice workspace for this device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(24)
        .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var signInButtons: some View {
        VStack(spacing: 14) {
#if canImport(GoogleSignInSwift)
            GoogleSignInButton(action: { authManager.startGoogleSignIn() })
                .frame(height: 50)
#elseif canImport(GoogleSignIn)
            Button("Sign in with Google") {
                authManager.startGoogleSignIn()
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.blue, in: Capsule())
            .foregroundStyle(.white)
#else
            Button("Sign in with Google") { }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
                .background(Color.blue, in: Capsule())
                .foregroundStyle(.white)
#endif
        }
    }
}
#endif
