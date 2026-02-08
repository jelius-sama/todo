// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

let shouldBuildStatic = ProcessInfo.processInfo.environment["STATIC_BUILD"] == "1"

var targets: Array<Target> = []

#if os(macOS)
    let notifierLibrary = "Resources/terminal-notifier.app"
    let swiftSettings: [SwiftSetting] = [
        .unsafeFlags(["-parse-as-library"])
    ]
#elseif os(Linux)
    let notifierLibrary = "Resources/notify-send"
    var swiftSettings: [SwiftSetting] = [
        .unsafeFlags(["-parse-as-library"])
    ]
    if shouldBuildStatic {
        swiftSettings.append(
            .unsafeFlags(["-static-stdlib"]),
        )
    }
    targets = [
        .systemLibrary(
            name: "SQLite3"
        )
    ]
#endif

targets.append(
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
        name: "todo",
        dependencies: [
            "SQLite3",
            .product(name: "NIO", package: "swift-nio"),
            .product(name: "NIOHTTP1", package: "swift-nio"),
        ],
        path: "Sources",
        resources: [
            .copy(notifierLibrary)
        ],
        swiftSettings: swiftSettings,
    ),
)

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
    targets: targets
)
