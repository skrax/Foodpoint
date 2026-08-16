// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "OpenFoodFactsKit",
    platforms: [.iOS(.v16), .macOS(.v12)],
    products: [
        .library(name: "OpenFoodFactsKit", targets: ["OpenFoodFactsKit"]),
    ],
    targets: [
        .target(name: "OpenFoodFactsKit"),
    ]
)
