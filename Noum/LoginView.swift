#if canImport(SwiftUI)
import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
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
                background

                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    content
                        .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
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

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.95, green: 0.96, blue: 0.99),
                    Color(red: 0.99, green: 0.98, blue: 0.96),
                    Color.white
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color(red: 0.24, green: 0.47, blue: 0.86).opacity(0.08))
                .frame(width: 240, height: 240)
                .blur(radius: 30)
                .offset(x: 130, y: -250)

            Circle()
                .fill(Color(red: 0.94, green: 0.73, blue: 0.48).opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 32)
                .offset(x: -120, y: 260)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Noum")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                Text("Speak with more clarity.")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(red: 0.11, green: 0.15, blue: 0.24))
                    .fixedSize(horizontal: false, vertical: true)

                Text("Track filler words, practice out loud, and get coaching tuned to how you want to sound.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(spacing: 12) {
#if canImport(AuthenticationServices)
                    SignInWithAppleButton(.continue) { request in
                        request.requestedScopes = [.fullName]
                    } onCompletion: { result in
                        authManager.handleAppleSignIn(result)
                    }
                    .frame(height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
#endif

                    if authManager.isGoogleSignInAvailable {
                        googleButton
                    }
                }
            }
            .padding(22)
            .background(Color.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Color.white.opacity(0.78), lineWidth: 1)
            )
        }
        .frame(maxWidth: 460)
    }

    private var googleButton: some View {
        Button {
            authManager.startGoogleSignIn()
        } label: {
            HStack(spacing: 8) {
                Text("Use Google instead")
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
#endif
