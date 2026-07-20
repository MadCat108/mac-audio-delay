// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MacAudioDelay",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AudioDelay", targets: ["AudioDelay"]),
        .executable(name: "AudioDelayUpdater", targets: ["AudioDelayUpdater"])
    ],
    targets: [
        .executableTarget(
            name: "AudioDelay",
            path: "Sources/AudioDelay"
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
