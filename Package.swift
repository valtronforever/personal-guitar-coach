// swift-tools-version: 6.0
import PackageDescription

// Command-line build of the same native app sources; Xcode remains the UI-test target.
let package = Package(
    name: "PersonalGuitarCoach",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PersonalGuitarCoach", targets: ["PersonalGuitarCoach"])],
    dependencies: [.package(path: "Packages/GuitarCoachCore"), .package(url: "https://github.com/jpsim/Yams.git", exact: "6.2.2")],
    targets: [
        .executableTarget(
            name: "PersonalGuitarCoach",
            dependencies: [
                .product(name: "Domain", package: "GuitarCoachCore"),
                .product(name: "Audio", package: "GuitarCoachCore"),
                .product(name: "Persistence", package: "GuitarCoachCore"),
                .product(name: "Learning", package: "GuitarCoachCore")
            ],
            path: "App",
            exclude: ["PersonalGuitarCoach.entitlements"]
        ),
        .testTarget(name: "AppTests", dependencies: [
            .product(name: "Yams", package: "Yams"),
            "PersonalGuitarCoach", .product(name: "Domain", package: "GuitarCoachCore"),
            .product(name: "Persistence", package: "GuitarCoachCore"), .product(name: "Learning", package: "GuitarCoachCore"),
            .product(name: "Audio", package: "GuitarCoachCore")
        ], path: "Tests/AppTests")
    ]
)
