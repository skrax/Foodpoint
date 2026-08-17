// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "MealKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MealKit", targets: ["MealKit"]),
    ],
    dependencies: [
        .package(path: "../FoodFoundation"),
    ],
    targets: [
        .target(name: "MealKit", dependencies: ["FoodFoundation"]),
        .testTarget(name: "MealKitTests", dependencies: ["MealKit", "FoodFoundation"]),
    ]
)
