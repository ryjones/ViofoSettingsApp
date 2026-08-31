// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ViofoConfig",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ViofoConfig",
            path: "Sources/ViofoConfig",
            resources: [.process("Resources")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ViofoConfigTests",
            dependencies: ["ViofoConfig"],
            path: "Tests/ViofoConfigTests",
            resources: [.copy("Fixtures")],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
