// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FoodpointKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FoodpointKit", targets: ["FoodpointKit"]),
    ],
    dependencies: [
        .package(path: "../OpenFoodFacts"),
    ],
    targets: [
        .target(name: "FoodpointKit", dependencies: ["OpenFoodFacts"]),
        .testTarget(name: "FoodpointKitTests", dependencies: ["FoodpointKit", "OpenFoodFacts"]),
    ]
)
