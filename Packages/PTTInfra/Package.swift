// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PTTInfra",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "PTTInfra",
            targets: ["PTTInfra"]
        ),
    ],
    dependencies: [
        .package(path: "../PTTCodec"),
    ],
    targets: [
        .target(
            name: "CRNNoise",
            path: "Sources/CRNNoise",
            sources: ["src"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("src"),
                .define("RNNOISE_BUILD")
            ]
        ),
        .target(
            name: "COpus",
            path: "Sources/COpus",
            sources: ["src"],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("src"),
                .headerSearchPath("src/celt"),
                .headerSearchPath("src/silk"),
                .headerSearchPath("src/silk/fixed"),
                .define("OPUS_BUILD"),
                .define("HAVE_CONFIG_H"),
                .define("FIXED_POINT", to: "1"),
                // Hide internal symbols to avoid conflicts with CRNNoise
                .unsafeFlags(["-w", "-fvisibility=hidden"])
            ]
        ),
        .target(
            name: "PTTInfra",
            dependencies: ["PTTCodec", "CRNNoise", "COpus"]
        ),
        .testTarget(
            name: "PTTInfraTests",
            dependencies: ["PTTInfra"]
        ),
    ]
)
