// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GarminClicker",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ClickerCore"),
        .executableTarget(name: "GarminClicker", dependencies: ["ClickerCore"]),
        .testTarget(name: "ClickerCoreTests", dependencies: ["ClickerCore"]),
    ]
)
