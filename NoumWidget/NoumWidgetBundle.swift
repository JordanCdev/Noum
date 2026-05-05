#if canImport(WidgetKit)
import WidgetKit
import SwiftUI

// MARK: - Widget Bundle
//
// Single entry point for the NoumWidget extension. Lists every widget +
// Live Activity the bundle ships. The Xcode widget-extension target
// auto-discovers `@main`-annotated bundles.

@main
struct NoumWidgetBundle: WidgetBundle {
    var body: some Widget {
        NoumWidget()
        if #available(iOS 16.1, *) {
            PracticeLiveActivity()
        }
    }
}
#endif
