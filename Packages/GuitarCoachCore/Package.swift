// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GuitarCoachCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Audio", targets: ["Audio"])
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "RealtimeAudio", linkerSettings: [.linkedFramework("AudioToolbox")]),
        .target(name: "Audio", dependencies: ["Domain", "RealtimeAudio"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "AudioTests", dependencies: ["Audio", "RealtimeAudio"])
    ]
)
