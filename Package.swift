// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "ExisOne",
    platforms: [
        .macOS(.v12),
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "ExisOne",
            targets: ["ExisOne"]
        )
    ],
    targets: [
        .target(
            name: "ExisOne",
            path: "Sources/ExisOne",
            linkerSettings: [
                .linkedFramework("IOKit", .when(platforms: [.macOS])),
                .linkedFramework("Security")
            ]
        ),
        .testTarget(
            name: "ExisOneTests",
            dependencies: ["ExisOne"],
            path: "Tests/ExisOneTests"
        )
    ]
)
