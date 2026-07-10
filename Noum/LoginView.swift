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
    @State private var showOtherSignInOptions = false

    var body: some View {
        NavigationStack {
            ZStack {
                background

                GeometryReader { geometry in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Spacer(minLength: Spacing.lg)

                            hero
                                .padding(.horizontal, Spacing.screenH)

                            Spacer(minLength: Spacing.lg)

                            authPanel
                                .padding(.horizontal, Spacing.screenH)
                                .padding(.bottom, Spacing.lg)
                        }
                        .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    }
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .safeAreaInset(edge: .top) {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                    .accessibilityHint("Returns to settings.")
                    .accessibilityIdentifier("login.close")
                }
                .padding(.horizontal, Spacing.screenH)
                .padding(.vertical, Spacing.xs)
            }
        }
        .accessibilityIdentifier("login.screen")
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
        LinearGradient(
            colors: [AppColor.lightGradientStart, AppColor.screenBackground],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 20) {
            // App name
            Text("noum")
                .font(Typography.headline)
                .foregroundStyle(AppColor.brandBlue)
                .tracking(4)
                .textCase(.uppercase)

            // Main headline
            VStack(alignment: .leading, spacing: 12) {
                Text("Speak with\nmore clarity.")
                    .font(Typography.hero)
                    .foregroundStyle(AppColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Practice out loud. Get a clear next move.\nOne focused rep at a time.")
                    .font(Typography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(3)
            }
        }
        .frame(maxWidth: 460, alignment: .leading)
    }

    private var authPanel: some View {
        CardView(cornerRadius: CornerRadius.xl, padding: Spacing.lg) {
            VStack(spacing: Spacing.sm) {
                Text("Continue with an account to keep your practice history available across devices.")
                    .font(Typography.body)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

#if canImport(AuthenticationServices)
                SignInWithAppleButton(.continue) { request in
                    authManager.prepareAppleSignIn(request)
                } onCompletion: { result in
                    authManager.handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.medium, style: .continuous))
                .accessibilityIdentifier("login.apple")
#endif

                VStack(spacing: 0) {
                    Button {
                        showOtherSignInOptions.toggle()
                    } label: {
                        HStack(spacing: Spacing.sm) {
                            Text("Other ways to continue")
                                .font(Typography.body.weight(.semibold))
                                .foregroundStyle(AppColor.textSecondary)

                            Spacer(minLength: Spacing.sm)

                            Image(systemName: showOtherSignInOptions ? "chevron.up" : "chevron.down")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(AppColor.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Other ways to continue")
                    .accessibilityValue(showOtherSignInOptions ? "Expanded" : "Collapsed")
                    .accessibilityHint(
                        showOtherSignInOptions
                            ? "Hides Google and guest options."
                            : "Shows Google and guest options."
                    )
                    .accessibilityIdentifier("login.otherOptions")

                    if showOtherSignInOptions {
                        VStack(spacing: Spacing.sm) {
                            googleButton
                                .accessibilityIdentifier("login.google")
                            guestButton
                        }
                        .padding(.top, Spacing.sm)
                    }
                }
            }
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
            Text("Continue as guest")
                .font(Typography.body.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("login.guest")
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
