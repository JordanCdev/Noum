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
            VStack(spacing: 30) {
                Spacer()
                Text("Welcome to Noum")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                VStack(spacing: 20) {
                    Text("Already have an account?")
                    #if canImport(AuthenticationServices)
                    SignInWithAppleButton(.signIn) { request in
                        authManager.configureAppleRequest(request)
                    } onCompletion: { result in
                        authManager.handleAppleAuthorization(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 45)
                    #else
                    Button("Sign in with Apple") { }
                    #endif
#if canImport(GoogleSignInSwift)
                    GoogleSignInButton(action: { authManager.startGoogleSignIn() })
                        .frame(height: 45)
#else
                    Button("Sign in with Google") {
                        authManager.startGoogleSignIn()
                    }
#endif
                }
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
}
#endif
