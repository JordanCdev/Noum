#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 12.0, *)
struct LoginView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthManager.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                Spacer()
                Text("Welcome to Noum")
                    .font(.largeTitle)
                    .bold()
                Spacer()
                VStack(spacing: 16) {
                    Text("Already have an account?")
                    Button(action: { authManager.signInWithApple() }) {
#if canImport(UIKit)
                        Label("Sign in with Apple", systemImage: "applelogo")
                            .frame(maxWidth: .infinity)
#else
                        Text("Sign in with Apple")
#endif
                    }
                    .buttonStyle(.borderedProminent)
                    Text("New to Noum?")
                    Button("Get Started") { authManager.signInWithApple() }
                        .buttonStyle(.bordered)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("")
        }
        .onChange(of: authManager.isSignedIn) { signedIn in
            if signedIn { dismiss() }
        }
    }
}
#endif
