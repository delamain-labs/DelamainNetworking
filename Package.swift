// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DelamainNetworking",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "DelamainNetworking",
            targets: ["DelamainNetworking"]
        )
    ],
    targets: [
        .target(
            name: "DelamainNetworking",
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),
        .testTarget(
            name: "DelamainNetworkingTests",
            dependencies: ["DelamainNetworking"]
        )
    ]
)
