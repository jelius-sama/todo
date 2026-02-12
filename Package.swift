// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

var targets: Array<Target> = []
var dependencies: Array<Target.Dependency> = [
    .product(name: "NIO", package: "swift-nio"),
    .product(name: "NIOHTTP1", package: "swift-nio"),
]

#if os(macOS)
    let notifierLibrary = "Resources/terminal-notifier.app"
#elseif os(Linux)
    let notifierLibrary = "Resources/notify-send"
    targets = [
        .systemLibrary(
            name: "SQLite3"
        )
    ]
    dependencies.append("SQLite3")
#endif

targets.append(
    // Targets are the basic building blocks of a package, defining a module or a test suite.
    // Targets can depend on other targets in this package and products from dependencies.
    .executableTarget(
        name: "todo",
        dependencies: dependencies,
        path: "Sources",
        resources: [
            // TODO: The following doesn't embed the resources to the executable
            //        We need to use some other method of embedding resources.
            //        Maybe we could use golang for this purpose.
            .copy(notifierLibrary),
            .copy("Resources/Assets"),
        ],
        swiftSettings: [
            .unsafeFlags(["-parse-as-library"])
        ],
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
