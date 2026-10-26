// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DoomKit",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "DoomCore", targets: ["DoomCore"]),
        .library(name: "DoomServices", targets: ["DoomServices"]),
        .library(name: "DoomFeatures", targets: ["DoomFeatures"]),
    ],
    targets: [
        .target(name: "DoomCore"),
        .target(name: "DoomServices", dependencies: ["DoomCore"]),
        .target(name: "DoomFeatures", dependencies: ["DoomCore"]),
        .testTarget(name: "DoomCoreTests", dependencies: ["DoomCore"]),
        .testTarget(name: "DoomServicesTests", dependencies: ["DoomServices", "DoomCore"]),
        .testTarget(name: "DoomFeaturesTests", dependencies: ["DoomFeatures", "DoomCore"]),
    ]
)

