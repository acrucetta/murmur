// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "DictationApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "DictationAppCore",
            targets: ["DictationAppCore"]
        ),
        .executable(
            name: "DictationPreviewCLI",
            targets: ["DictationPreviewCLI"]
        ),
    ],
    targets: [
        .target(
            name: "DictationAppCore",
            path: "Sources/DictationAppCore"
        ),
        .executableTarget(
            name: "DictationPreviewCLI",
            dependencies: ["DictationAppCore"],
            path: "Sources/DictationPreviewCLI"
        ),
        .testTarget(
            name: "DictationAppCoreTests",
            dependencies: ["DictationAppCore"],
            path: "Tests/DictationAppCoreTests"
        ),
    ]
)
