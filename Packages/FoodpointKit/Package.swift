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
        // No test target for now: composing `pantry: PantryStore`/
        // `meals: MealStore` is pure wiring, no logic of its own yet.
        // Re-add FoodpointKitTests once AppState gains real cross-domain
        // orchestration to test (see package-architecture.md §3.5, §4.2) —
        // MK-1 only wires `meals` in, MK-3 is where that orchestration lands.
    ]
)
