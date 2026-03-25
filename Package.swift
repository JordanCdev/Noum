
// swift-tools-version: 6.0.0

import PackageDescription

let package = Package(
    name: "Noum",
    platforms: [.iOS(.v17)],
    products: [
        .executable(name: "NoumApp", targets: ["Noum"])
    ],
    dependencies: [
        .package(url: "https://github.com/awslabs/aws-sdk-swift.git", from: "1.3.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "7.0.0")
    ],
    targets: [
        .executableTarget(
            name: "Noum",
            dependencies: [
                .product(name: "AWSTranscribeStreaming", package: "aws-sdk-swift"),
                .product(name: "AWSSDKIdentity", package: "aws-sdk-swift"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS"),
                .product(name: "GoogleSignInSwift", package: "GoogleSignIn-iOS")
            ],
            path: "Noum",
            exclude: [
                // Resources only used by the Xcode project should not be
                // included when building the Swift Package, otherwise SwiftPM
                // emits warnings about unhandled files.
                "Assets.xcassets",
                "Preview Content",
                "Transcribe.plist.example",
                "Info.plist"
            ]
        ),
        .testTarget(
            name: "NoumTests",
            dependencies: ["Noum"],
            path: "NoumTests"
        )
    ]
)
