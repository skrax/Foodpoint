// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FoodFoundation",
    platforms: [.iOS(.v16), .macOS(.v12)],
    products: [
        .library(name: "FoodFoundation", targets: ["FoodFoundation"]),
    ],
    dependencies: [
        .package(path: "../OpenFoodFactsKit"),
    ],
    targets: [
        .target(name: "FoodFoundation", dependencies: ["OpenFoodFactsKit"]),
        .testTarget(name: "FoodFoundationTests", dependencies: ["FoodFoundation", "OpenFoodFactsKit"]),
    ]
)
