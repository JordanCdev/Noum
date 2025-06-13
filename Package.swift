
// swift-tools-version: 6.1

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
            path: "Noum"
        ),
        .testTarget(
            name: "NoumTests",
            dependencies: ["Noum"],
            path: "NoumTests"
        )
    ]
)
