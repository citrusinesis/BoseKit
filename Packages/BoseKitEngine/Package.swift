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
    products: [
        .library(name: "BoseKitEngine", targets: ["BoseKitEngine"]),
        .executable(name: "bosekit-probe", targets: ["BoseKitProbe"]),
    ],
    targets: [
        .target(
            name: "BoseKitEngine",
            swiftSettings: swiftSettings,
            linkerSettings: [.linkedFramework("IOBluetooth")]
        ),
        .executableTarget(
            name: "BoseKitProbe",
            dependencies: ["BoseKitEngine"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "BoseKitEngineTests",
            dependencies: ["BoseKitEngine"],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "BoseKitProbeTests",
            dependencies: ["BoseKitProbe", "BoseKitEngine"],
            swiftSettings: swiftSettings
        ),
    ]
)
