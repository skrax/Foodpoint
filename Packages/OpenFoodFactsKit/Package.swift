// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "OpenFoodFacts",
    platforms: [.iOS(.v16), .macOS(.v12)],
    products: [
        .library(name: "OpenFoodFacts", targets: ["OpenFoodFacts"]),
    ],
    targets: [
        .target(name: "OpenFoodFacts"),
    ]
)
