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
        .executable(name: "HerdrWidget", targets: ["HerdrWidget"]),
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
                .linkedFramework("ServiceManagement"),
                .linkedFramework("WidgetKit"),
            ]
        ),
        .executableTarget(
            name: "HerdrWidget",
            dependencies: ["HerdrCore"],
            linkerSettings: [
                .linkedFramework("WidgetKit"),
                .linkedFramework("SwiftUI"),
            ]
        ),
        .testTarget(
            name: "HerdrCoreTests",
            dependencies: ["HerdrCore"]
        ),
    ]
)
