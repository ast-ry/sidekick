// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "sidekick",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "sidekick", targets: ["SidekickApp"]),
    ],
    targets: [
        .executableTarget(
            name: "SidekickApp",
            path: "Sources"
        ),
    ]
)
