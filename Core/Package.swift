// swift-tools-version: 6.3
// The line above is a directive, not a comment. SwiftPM reads it before
// compiling this file, and it decides which PackageDescription API exists
// and which Swift language mode targets default to (6.0 at tools 6.x).

import PackageDescription

let package = Package(
    // The PACKAGE name. Distinct from product and target names below.
    name: "LoadyCore",

    // Package-wide minimum OS. This cannot vary per target — the test target
    // inherits it too, which is why the macOS 14 floor matters here.
    platforms: [.macOS(.v14)],

    // PRODUCTS are what a consumer (the Loady app target) adds as a dependency.
    // You add the product in Xcode, but you `import` the target.
    products: [
        .library(name: "SystemMetrics", targets: ["SystemMetrics"]),
        .executable(name: "loady-probe", targets: ["loady-probe"])
    ],

    // TARGETS are the actual modules. Sources must live at
    // Sources/<name>/ and Tests/<name>/ — that's convention, not config.
    targets: [
        // No swiftSettings yet, deliberately. Swift 6 language mode is already
        // the default at tools-version 6.x, so stating it would be a no-op.
        // The first real setting arrives in M3: .defaultIsolation(MainActor.self)
        // on the UI targets, with this one deliberately left nonisolated.
        .target(name: "SystemMetrics"),

        // A command-line harness for inspecting the metrics layer without
        // building or launching the app. This is how readers get verified
        // against `top`, `vm_stat` and Activity Monitor, and later how
        // test fixtures get recorded on machines we do not own.
        .executableTarget(name: "loady-probe", dependencies: ["SystemMetrics"]),

        .testTarget(
            name: "SystemMetricsTests",
            dependencies: ["SystemMetrics"]
        )
    ]
)
