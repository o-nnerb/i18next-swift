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
    ],
    traits: [
        // Forwarded to RequestDL. Linux/Windows/Android need it (`.nio` is their only executor); Apple apps
        // that only use `.urlSession` can drop SwiftNIO from the build with `traits: []` on this package.
        .trait(
            name: "NIOTransport",
            description: "Builds RequestDL with SwiftNIO. Required to run `I18nextHTTP` outside Apple platforms."
        ),
        .default(enabledTraits: ["NIOTransport"]),
    ],
    dependencies: [
        // Provides `Lock` (os_unfair_lock / pthread / SRWLOCK) and `AsyncSemaphore`.
        // Temporary: `Lock` may later be inlined to drop the dependency.
        .package(url: "https://github.com/o-nnerb/swift-async-stream.git", from: "3.0.2"),
        .package(
            url: "https://github.com/request-dl/request-dl-nio.git",
            from: "4.5.8",
            traits: [.trait(name: "NIOTransport", condition: .when(traits: ["NIOTransport"]))]
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
        .testTarget(
            name: "I18nextTests",
            dependencies: ["I18next"],
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
