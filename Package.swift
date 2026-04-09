// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "SwiftCodeSan",
    platforms: [
        .macOS(.v10_15),
    ],
    products: [
        .executable(name: "SwiftCodeSan", targets: ["SwiftCodeSan"]),
        .library(name: "SwiftCodeSanKit", targets: ["SwiftCodeSanKit"]),
        ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        .package(url: "https://github.com/apple/swift-syntax.git", from: "603.0.0")
    ],
    targets: [ 
        .target(
            name: "SwiftCodeSan",
            dependencies: [
                "SwiftCodeSanKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                ]),
        .target(
            name: "SwiftCodeSanKit",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
            ]
        ),
        .testTarget(
            name: "SwiftCodeSanTests",
            dependencies: [
                "SwiftCodeSanKit",
            ],
            path: "Tests"
        )
    ]
)

