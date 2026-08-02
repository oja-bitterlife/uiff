// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swiftUI",
    products: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executable(
            name: "swiftUI",
            targets: ["swiftUI"],
        ),
        .library(
            name: "swiftUILib",
            targets: ["swiftUILib"]
        ),
    ],
    targets: [
        // VMのコアロジック（no-allocateを意識した固定配列ベースの処理など）
        .target(
            name: "swiftUILib"
        ),
        // 仮実行用バイナリ（GbaVmCoreをインポートしてテスト実行する）
        .executableTarget(
            name: "swiftUI",
            dependencies: ["swiftUILib"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

