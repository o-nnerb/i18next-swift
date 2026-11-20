// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "i18next-swift",
    platforms: [
        .macOS(.v12),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v9),
        .visionOS(.v1),
    ],
    products: [
        .library(name: "I18next", targets: ["I18next"]),
        .library(name: "I18nextHTTP", targets: ["I18nextHTTP"]),
        .library(name: "I18nextFormatters", targets: ["I18nextFormatters"]),
    ],
    dependencies: [
        // Provides `Lock` (os_unfair_lock / pthread / SRWLOCK) and `AsyncSemaphore`.
        // Temporary: `Lock` may later be inlined to drop the dependency.
        .package(url: "https://github.com/o-nnerb/swift-async-stream.git", from: "3.0.2"),
        .package(
            url: "https://github.com/request-dl/request-dl-nio.git",
            from: "4.5.8"
        ),
    ],
    targets: [
        .target(
            name: "I18next",
            dependencies: [
                .product(name: "SwiftAsyncStream", package: "swift-async-stream")
            ],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
        .target(
            name: "I18nextHTTP",
            dependencies: [
                "I18next",
                .product(name: "RequestDL", package: "request-dl-nio"),
            ],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
        .target(
            name: "I18nextFormatters",
            dependencies: ["I18next"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
        .testTarget(
            name: "I18nextTests",
            dependencies: ["I18next"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
        .testTarget(
            name: "I18nextFormattersTests",
            dependencies: ["I18nextFormatters"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
        .testTarget(
            name: "I18nextHTTPTests",
            dependencies: ["I18nextHTTP"],
            swiftSettings: [
                .defaultIsolation(nil)
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
