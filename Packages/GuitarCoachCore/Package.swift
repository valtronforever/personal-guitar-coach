// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "GuitarCoachCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "Domain", targets: ["Domain"]),
        .library(name: "Audio", targets: ["Audio"]),
        .library(name: "Persistence", targets: ["Persistence"]),
        .library(name: "Learning", targets: ["Learning"]),
        .executable(name: "ValidateLessonContent", targets: ["ValidateLessonContent"]),
        .executable(name: "BenchmarkAudio", targets: ["BenchmarkAudio"])
    ],
    targets: [
        .target(name: "Domain"),
        .target(name: "RealtimeAudio", linkerSettings: [.linkedFramework("AudioToolbox")]),
        .target(name: "Audio", dependencies: ["Domain", "RealtimeAudio"]),
        .target(name: "AudioTestSupport"),
        .target(name: "Persistence", dependencies: ["Domain"]),
        .target(name: "Learning", dependencies: ["Domain"]),
        .executableTarget(name: "ValidateLessonContent", dependencies: ["Learning"]),
        .executableTarget(name: "BenchmarkAudio", dependencies: ["Audio", "AudioTestSupport", "Domain"]),
        .testTarget(name: "DomainTests", dependencies: ["Domain"]),
        .testTarget(name: "AudioTests", dependencies: ["Audio", "RealtimeAudio", "AudioTestSupport"]),
        .testTarget(name: "PersistenceTests", dependencies: ["Persistence", "Domain"], resources: [.copy("Fixtures")]),
        .testTarget(name: "LearningTests", dependencies: ["Learning", "Domain"])
    ]
)
