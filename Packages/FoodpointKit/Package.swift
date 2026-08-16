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
    ],
    targets: [
        .target(name: "FoodpointKit", dependencies: ["FoodFoundation"]),
        // No test target for now: AppState's logic moved to PantryKit (PA-4)
        // and there's nothing left here worth testing until PA-5 adds real
        // composition-root/orchestration logic. Re-add FoodpointKitTests then.
    ]
)
