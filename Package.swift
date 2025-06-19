
// swift-tools-version: 6.0.0

import PackageDescription

let package = Package(
    name: "Noum",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [
        .executable(name: "NoumApp", targets: ["Noum"])
    ],
    dependencies: [
        .package(url: "https://github.com/awslabs/aws-sdk-swift.git", from: "1.3.0")
    ],
    targets: [
        .executableTarget(
            name: "Noum",
            dependencies: [
                .product(name: "AWSTranscribeStreaming", package: "aws-sdk-swift"),
                .product(name: "AWSSDKIdentity", package: "aws-sdk-swift")
            ],
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
