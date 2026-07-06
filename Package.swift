// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Lively",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "LivelyApp", targets: ["LivelyApp"]),
        .library(name: "LivelyCore", targets: ["LivelyCore"])
    ],
    targets: [
        // Core Logic (Testable)
        .target(
            name: "LivelyCore",
            path: "Sources/Lively"
        ),
        // Executable (Entry Point)
        .executableTarget(
            name: "LivelyApp",
            dependencies: ["LivelyCore"],
            path: "Sources/LivelyApp"
        ),
        // Test Suite
        .testTarget(
            name: "LivelyTests",
            dependencies: ["LivelyCore"]
        ),
    ]
)
