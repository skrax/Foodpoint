// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "FoodpointKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "FoodpointKit", targets: ["FoodpointKit"]),
    ],
    dependencies: [
        .package(path: "../FoodFoundation"),
        .package(path: "../PantryKit"),
        .package(path: "../MealKit"),
    ],
    targets: [
        .target(name: "FoodpointKit", dependencies: ["FoodFoundation", "PantryKit", "MealKit"]),
        // FoodpointKitTests covers only cross-domain orchestration
        // (markMealEaten/undoMealEaten) — package-architecture.md §4.2's
        // "much smaller FoodpointKitTests" — not the pure wiring in
        // AppState.init, which has nothing to test.
        .testTarget(name: "FoodpointKitTests", dependencies: ["FoodpointKit", "FoodFoundation", "PantryKit", "MealKit"]),
    ]
)
