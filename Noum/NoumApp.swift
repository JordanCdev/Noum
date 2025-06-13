//
//  NoumApp.swift
//  Noum
//
//  Created by Jordan Coaten on 25/01/2025.
//
import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(SwiftUI)
@main
struct NoumApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
#else
/// Minimal entry point when SwiftUI isn't available so the package links.
@main
enum NoumApp {
    static func main() {}
}
#endif
