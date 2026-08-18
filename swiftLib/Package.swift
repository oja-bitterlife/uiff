// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swiftLib",
    products: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .library(
            name: "UIFFLib",
            targets: ["UIFFLib"]
        ),
        .library(
            name: "GBAUtil",
            targets: ["GBAUtil"]
        ),
    ],
    targets: [
        // VMのコアロジック（no-allocateを意識した固定配列ベースの処理など）
        .target(
            name: "UIFFLib",
            dependencies: []
        ),
        .target(
            name: "GBAUtil",
            dependencies: [
                "UIFFLib"
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
