// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DynamicIsland",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "DynamicIsland",
            targets: ["DynamicIsland"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DynamicIsland",
            path: "DynamicIsland",
            exclude: ["Resources/Info.plist"]
        )
    ]
)
