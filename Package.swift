// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "SwiftSomeAnyMigrator",
  platforms: [
        .macOS(.v10_15)
    ],
  dependencies: [
    .package(
        url: "https://github.com/apple/swift-argument-parser",
        from: "1.2.3"
    ),
    .package(
        url: "https://github.com/apple/swift-syntax.git",
        from: "509.1.0"
    ),
  ],
  targets: [
    .executableTarget(
        name: "CommandLineTool",
        dependencies: ["SwiftSomeAnyMigrator"],
        path: "Sources/CommandLineTool"
    ),
    .target(
        name: "SwiftSomeAnyMigrator",
        dependencies: [
            .product(name: "SwiftSyntax", package: "swift-syntax"),
            .product(name: "SwiftOperators", package: "swift-syntax"),
            .product(name: "SwiftParser", package: "swift-syntax"),
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
        ],
        path: "Sources/Command"
    ),
    .testTarget(
        name: "SwiftSomeAnyMigratorTests",
        dependencies: [
            "SwiftSomeAnyMigrator"
        ]
    ),
  ]
)
