// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MacAudioDelay",
    platforms: [
        .macOS("14.2")
    ],
    products: [
        .executable(name: "AudioDelay", targets: ["AudioDelay"]),
        .executable(name: "AudioDelayUpdater", targets: ["AudioDelayUpdater"])
    ],
    targets: [
        .executableTarget(
            name: "AudioDelay",
            dependencies: ["AudioDelayCore"],
            path: "Sources/AudioDelay"
        ),
        .target(
            name: "AudioDelayCore",
            path: "Sources/AudioDelayCore",
            publicHeadersPath: "include",
            linkerSettings: [
                .linkedFramework("CoreAudio")
            ]
        ),
        .executableTarget(
            name: "AudioDelayUpdater",
            path: "Sources/AudioDelayUpdater"
        ),
        .testTarget(
            name: "AudioDelayTests",
            dependencies: ["AudioDelay"],
            path: "Tests/AudioDelayTests"
        )
    ]
)
