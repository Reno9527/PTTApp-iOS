// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PTTCodec",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "PTTCodec",
            targets: ["PTTCodec"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PTTCodec",
            dependencies: []
        ),
        .testTarget(
            name: "PTTCodecTests",
            dependencies: ["PTTCodec"]
        ),
    ]
)
