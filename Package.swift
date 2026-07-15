// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "KeyFlow",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .library(name: "KeyFlowCore", targets: ["KeyFlowCore"]),
        .executable(name: "KeyFlowApp", targets: ["KeyFlowApp"]),
    ],
    targets: [
        .target(
            name: "KeyFlowCore"
        ),
        .target(
            name: "KeyFlowMultitouchBridge",
            publicHeadersPath: "include"
        ),
        .target(
            name: "KeyFlowWindowServerBridge",
            publicHeadersPath: "include"
        ),
        .executableTarget(
            name: "KeyFlowApp",
            dependencies: ["KeyFlowCore", "KeyFlowMultitouchBridge", "KeyFlowWindowServerBridge"]
        ),
        .testTarget(
            name: "KeyFlowCoreTests",
            dependencies: ["KeyFlowCore"]
        ),
        .testTarget(
            name: "KeyFlowAppTests",
            dependencies: ["KeyFlowApp", "KeyFlowCore"]
        ),
    ]
)
