// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Argos",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        // C shim — exposes the Rust FFI header to Swift
        .target(
            name: "ArgosDriver",
            path: "Sources/ArgosDriver",
            publicHeadersPath: "include"
        ),

        // Swift macOS app
        .executableTarget(
            name: "Argos",
            dependencies: ["ArgosDriver"],
            path: "Sources/Argos",
            swiftSettings: [
                .unsafeFlags(["-framework", "ScreenCaptureKit"])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L", "\(Context.packageDirectory)/driver/target/release",
                ]),
                .linkedLibrary("argos_driver"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreFoundation"),
            ]
        ),
    ]
)
