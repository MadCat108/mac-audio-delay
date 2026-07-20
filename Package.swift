// swift-tools-version: 5.10

import PackageDescription

let package = Package(
    name: "MacAudioDelay",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AudioDelay", targets: ["AudioDelay"])
    ],
    targets: [
        .executableTarget(
            name: "AudioDelay",
            path: "Sources/AudioDelay"
        ),
        .testTarget(
            name: "AudioDelayTests",
            dependencies: ["AudioDelay"],
            path: "Tests/AudioDelayTests"
        )
    ]
)
