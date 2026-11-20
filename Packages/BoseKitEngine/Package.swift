// swift-tools-version: 6.2
import PackageDescription

// Mirrors the app target's SWIFT_APPROACHABLE_CONCURRENCY and member-import settings so the engine compiles with the same semantics under SwiftPM and Xcode.
let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "BoseKitEngine",
    platforms: [.macOS(.v14)],
    products: [.library(name: "BoseKitEngine", targets: ["BoseKitEngine"])],
    targets: [
        .target(
            name: "BoseKitEngine",
            swiftSettings: swiftSettings,
            linkerSettings: [.linkedFramework("IOBluetooth")]
        ),
        .testTarget(
            name: "BoseKitEngineTests",
            dependencies: ["BoseKitEngine"],
            swiftSettings: swiftSettings
        ),
    ]
)
