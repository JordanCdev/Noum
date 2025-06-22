#if canImport(SwiftUI) && canImport(UIKit)
import SwiftUI
import UIKit

struct DisableSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        controller.view.backgroundColor = .clear
        DispatchQueue.main.async {
            controller.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        }
        return controller
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

extension View {
    func disableSwipeBack() -> some View {
        background(DisableSwipeBack())
    }
}
#endif
