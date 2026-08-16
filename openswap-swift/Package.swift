// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Openswap",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "Openswap",
            targets: ["Openswap"]
        )
    ],
    targets: [
        .binaryTarget(
            name: "OpenswapFFI",
            path: "openswap_ffi.xcframework"
        ),
        .target(
            name: "Openswap",
            dependencies: ["OpenswapFFI"],
            path: "Sources/Openswap"
        ),
        .testTarget(
            name: "OpenswapTests",
            dependencies: ["Openswap"],
            path: "Tests/OpenswapTests"
        )
    ]
)
