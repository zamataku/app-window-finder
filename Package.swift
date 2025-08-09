// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppWindowFinder",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "AppWindowFinder", targets: ["AppWindowFinder"])
    ],
    targets: [
        .executableTarget(
            name: "AppWindowFinder",
            dependencies: [],
            swiftSettings: [
                .unsafeFlags(["-parse-as-library"]),
                .unsafeFlags(["-Xfrontend", "-disable-availability-checking"]),
                .unsafeFlags(["-Xfrontend", "-warn-concurrency"])
            ]
        ),
        .testTarget(
            name: "AppWindowFinderTests",
            dependencies: ["AppWindowFinder"]
        )
    ]
)
