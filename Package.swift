// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "combegone",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "CombegoneCore"),
        .executableTarget(name: "combegone", dependencies: ["CombegoneCore"]),
        .testTarget(name: "CombegoneCoreTests", dependencies: ["CombegoneCore"]),
    ],
    swiftLanguageModes: [.v5]
)
