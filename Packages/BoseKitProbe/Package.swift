// swift-tools-version: 6.2
import PackageDescription

let swiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    .enableUpcomingFeature("InferIsolatedConformances"),
    .enableUpcomingFeature("MemberImportVisibility"),
]

let package = Package(
    name: "BoseKitProbe",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "bosekit-probe", targets: ["BoseKitProbe"])],
    dependencies: [.package(path: "../BoseKitEngine")],
    targets: [
        .executableTarget(
            name: "BoseKitProbe",
            dependencies: [.product(name: "BoseKitEngine", package: "BoseKitEngine")],
            swiftSettings: swiftSettings
        ),
        .testTarget(
            name: "BoseKitProbeTests",
            dependencies: ["BoseKitProbe", .product(name: "BoseKitEngine", package: "BoseKitEngine")],
            swiftSettings: swiftSettings
        ),
    ]
)
