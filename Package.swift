
// swift-tools-version: 6.0.0

import PackageDescription

let package = Package(
    name: "Noum",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .executable(name: "NoumApp", targets: ["Noum"])
    ],
    targets: [
        .executableTarget(
            name: "Noum",
            path: "Noum",
            exclude: [
                "ContentView.swift",
                "SessionHistoryView.swift",
                "SummaryView.swift",
                // Resources only used by the Xcode project should not be
                // included when building the Swift Package, otherwise SwiftPM
                // emits warnings about unhandled files.
                "Assets.xcassets",
                "Preview Content"
            ]
        ),
        .testTarget(
            name: "NoumTests",
            dependencies: ["Noum"],
            path: "NoumTests"
        )
    ]
)
