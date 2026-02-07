// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if os(macOS)
    let notifierLibrary = "Resources/terminal-notifier.app"
    let swiftSettings: [SwiftSetting] = [
        .unsafeFlags(["-parse-as-library"])
    ]
#elseif os(Linux)
    let notifierLibrary = "Resources/notify-send"
    let swiftSettings: [SwiftSetting] = [
        .unsafeFlags(["-parse-as-library"]),
        .unsafeFlags(["-static-stdlib"]),
    ]
#endif

let package = Package(
    name: "todo",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v13),
        .tvOS(.v13),
        .watchOS(.v6),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.0.0")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .executableTarget(
            name: "todo",
            dependencies: [
                .product(name: "NIO", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
            ],
            resources: [
                .copy(notifierLibrary)
            ],
            swiftSettings: swiftSettings,
        )
    ]
)
