// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "BasketCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "BasketCore", targets: ["BasketCore"]),
    ],
    targets: [
        .target(name: "BasketCore"),
        .testTarget(name: "BasketCoreTests", dependencies: ["BasketCore"]),
    ]
)
