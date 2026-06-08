#if canImport(SwiftUI)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
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
    @State private var showReportConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                VStack(spacing: 0) {
                    Spacer(minLength: 60)

                    hero
                        .padding(.horizontal, 28)

                    Spacer()

                    authPanel
                        .padding(.horizontal, 28)
                        .padding(.bottom, 48)
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: authManager.isSignedIn) { _, signedIn in
            if signedIn { dismiss() }
        }
        .alert("Sign In Failed", isPresented: $showError, actions: {
            Button("Report Issue") {
                reportCurrentSignInIssue()
            }
            Button("OK", role: .cancel) { authManager.signInError = nil }
        }, message: {
            Text(authManager.signInError ?? "Unknown error")
        })
        .alert("Issue Ready to Share", isPresented: $showReportConfirmation) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("We prepared a support report for this sign-in issue. You can paste it into a message to the Noum team.")
        }
        .onChange(of: authManager.signInError) { _, err in
            showError = err != nil
        }
    }

    private var background: some View {
        ZStack {
            // Rich dark-to-warm gradient
            LinearGradient(
                colors: [
                    Color(red: 0.08, green: 0.10, blue: 0.18),
                    Color(red: 0.12, green: 0.14, blue: 0.24),
                    Color(red: 0.18, green: 0.16, blue: 0.22)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // Accent glow - blue
            Circle()
                .fill(Color(red: 0.20, green: 0.50, blue: 0.95).opacity(0.25))
                .frame(width: 300, height: 300)
                .blur(radius: 80)
                .offset(x: 100, y: -200)

            // Accent glow - warm
            Circle()
                .fill(Color(red: 0.95, green: 0.65, blue: 0.30).opacity(0.15))
                .frame(width: 280, height: 280)
                .blur(radius: 70)
                .offset(x: -100, y: -80)

            // Subtle bottom glow
            Circle()
                .fill(Color(red: 0.30, green: 0.55, blue: 1.00).opacity(0.10))
                .frame(width: 400, height: 400)
                .blur(radius: 100)
                .offset(x: 0, y: 300)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 20) {
            // App name
            Text("noum")
                .font(Typography.headline)
                .foregroundStyle(Color.white.opacity(0.5))
                .tracking(4)
                .textCase(.uppercase)

            // Main headline
            VStack(alignment: .leading, spacing: 12) {
                Text("Speak with\nmore clarity.")
                    .font(Typography.hero)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Practice out loud. Get real-time coaching.\nSound like the person you want to be.")
                    .font(Typography.subheadline)
                    .foregroundStyle(Color.white.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: 460, alignment: .leading)
    }

    private var authPanel: some View {
        VStack(spacing: 12) {
#if canImport(AuthenticationServices)
            SignInWithAppleButton(.continue) { request in
                authManager.prepareAppleSignIn(request)
            } onCompletion: { result in
                authManager.handleAppleSignIn(result)
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
#endif

            googleButton

            // Divider
            HStack(spacing: 12) {
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
                Text("or")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.white.opacity(0.35))
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 1)
            }
            .padding(.vertical, 4)

            guestButton
        }
        .frame(maxWidth: 460)
    }

    private var googleButton: some View {
#if canImport(GoogleSignInSwift)
        GoogleSignInButton(
            viewModel: GoogleSignInButtonViewModel(
                scheme: .light,
                style: .wide,
                state: .normal
            )
        ) {
            authManager.startGoogleSignIn()
        }
        .frame(height: 54)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
#else
        Button {
            authManager.startGoogleSignIn()
        } label: {
            Text("Continue with Google")
                .font(Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(Color.white, in: RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
        }
        .buttonStyle(.plain)
#endif
    }

    private var guestButton: some View {
        Button {
            authManager.startAnonymousSession()
        } label: {
            Text("Try without an account")
                .font(Typography.body.weight(.medium))
                .foregroundStyle(Color.white.opacity(0.55))
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }

    private func reportCurrentSignInIssue() {
        let issue = authManager.supportReportPayload()
#if canImport(UIKit)
        UIPasteboard.general.string = issue
#endif
        authManager.signInError = nil
        showReportConfirmation = true
    }
}
#endif
