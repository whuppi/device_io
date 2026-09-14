// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "device_io",
    platforms: [
        .iOS("14.0"),
        .macOS("10.15"),
    ],
    products: [
        // Hyphenated: Swift Package Manager uses the library name as the
        // CFBundleIdentifier when linked dynamically, and that cannot carry
        // an underscore. Flutter's generated manifest asks for this exact name.
        .library(name: "device-io", targets: ["device_io"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "device_io",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)
