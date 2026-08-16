// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PantryKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "PantryKit", targets: ["PantryKit"]),
    ],
    dependencies: [
        .package(path: "../FoodFoundation"),
    ],
    targets: [
        .target(name: "PantryKit", dependencies: ["FoodFoundation"]),
        .testTarget(name: "PantryKitTests", dependencies: ["PantryKit", "FoodFoundation"]),
    ]
)
