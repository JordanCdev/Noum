#if canImport(SwiftUI)
import SwiftUI

@available(iOS 17.0, macOS 12.0, *)
struct SplashScreenView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Noum")
                .font(.largeTitle)
                .bold()
            ProgressView()
                .progressViewStyle(.circular)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#endif
