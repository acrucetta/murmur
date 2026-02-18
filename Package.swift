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
        .executable(
            name: "MurmurMenuBarApp",
            targets: ["MurmurMenuBarApp"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/migueldeicaza/TermKit.git",
            revision: "2cdfc96f9c524251ae1f517a440f28150182b7c2"
        ),
    ],
    targets: [
        .target(
            name: "DictationAppCore",
            path: "Sources/DictationAppCore",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "DictationPreviewCLI",
            dependencies: [
                "DictationAppCore",
                "TermKit",
            ],
            path: "Sources/DictationPreviewCLI"
        ),
        .executableTarget(
            name: "MurmurMenuBarApp",
            dependencies: ["DictationAppCore"],
            path: "Sources/MurmurMenuBarApp"
        ),
        .testTarget(
            name: "DictationAppCoreTests",
            dependencies: ["DictationAppCore"],
            path: "Tests/DictationAppCoreTests"
        ),
    ]
)
