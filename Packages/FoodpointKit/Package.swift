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
    ],
    targets: [
        .target(name: "FoodpointKit", dependencies: ["FoodFoundation", "PantryKit"]),
        // No test target for now: composing `pantry: PantryStore` is pure
        // wiring, no logic of its own yet. Re-add FoodpointKitTests once
        // MealKit lands and AppState gains real orchestration to test
        // (see package-architecture.md §3.5, §4.2).
    ]
)
