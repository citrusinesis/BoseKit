// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BoseKit",
    platforms: [.macOS(.v14)],
    products: [.library(name: "BoseKitEngine", targets: ["BoseKitEngine"])],
    targets: [
        .target(name: "BoseKitEngine", path: "BoseKitEngine",
                linkerSettings: [.linkedFramework("IOBluetooth")]),
        .testTarget(name: "BoseKitEngineTests", dependencies: ["BoseKitEngine"],
                    path: "BoseKitEngineTests")
    ]
)
