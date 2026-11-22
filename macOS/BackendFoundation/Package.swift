// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChargeMotionCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ChargeMotionCore", targets: ["ChargeMotionCore"])
    ],
    targets: [
        .target(name: "ChargeMotionCore"),
        .testTarget(name: "ChargeMotionCoreTests", dependencies: ["ChargeMotionCore"])
    ]
)
