// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "herdr-bar",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "HerdrCore", targets: ["HerdrCore"]),
        .executable(name: "MacBar", targets: ["MacBar"]),
    ],
    targets: [
        .target(
            name: "HerdrCore"
        ),
        .executableTarget(
            name: "MacBar",
            dependencies: ["HerdrCore"],
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        ),
        .testTarget(
            name: "HerdrCoreTests",
            dependencies: ["HerdrCore"]
        ),
    ]
)
