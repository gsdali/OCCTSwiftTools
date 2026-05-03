// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "OCCTSwiftTools",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .visionOS(.v1),
        .tvOS(.v18)
    ],
    products: [
        .library(
            name: "OCCTSwiftTools",
            targets: ["OCCTSwiftTools"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/gsdali/OCCTSwift.git",         from: "0.168.0"),
        .package(url: "https://github.com/gsdali/OCCTSwiftViewport.git", from: "0.51.0"),
    ],
    targets: [
        .target(
            name: "OCCTSwiftTools",
            dependencies: [
                .product(name: "OCCTSwift",         package: "OCCTSwift"),
                .product(name: "OCCTSwiftViewport", package: "OCCTSwiftViewport"),
            ],
            path: "Sources/OCCTSwiftTools",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "OCCTSwiftToolsTests",
            dependencies: ["OCCTSwiftTools"],
            path: "Tests/OCCTSwiftToolsTests"
        ),
    ]
)
