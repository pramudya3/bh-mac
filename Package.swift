// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BHMac",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "BHMac"),
        .executableTarget(name: "BHMacApp", dependencies: ["BHMac"]),
        .executableTarget(name: "bhmac-tests", dependencies: ["BHMac"], path: "Tests/BHMacTests"),
    ]
)
