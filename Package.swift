// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Argos",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // Swift macOS app
        .executableTarget(
            name: "Argos",
            path: "Sources/Argos",
            linkerSettings: [
                // Link the compiled Rust driver
                .unsafeFlags(["-L", "driver/target/release"]),
                .linkedLibrary("argos_driver"),
                // hidapi dependency (install via: brew install hidapi)
                .linkedLibrary("hidapi"),
            ]
        ),
    ]
)
