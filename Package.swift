// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "CleanSpace",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "CleanSpaceCore",
            targets: ["CleanSpaceCore"]
        )
    ],
    targets: [
        .target(
            name: "CleanSpaceCore",
            path: "CleanSpace/Sources"
        )
    ]
)
