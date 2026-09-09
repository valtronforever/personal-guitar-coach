// swift-tools-version: 6.0
import PackageDescription

// Command-line build of the same native app sources; Xcode remains the UI-test target.
let package = Package(
    name: "PersonalGuitarCoach",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "PersonalGuitarCoach", targets: ["PersonalGuitarCoach"])],
    dependencies: [.package(path: "Packages/GuitarCoachCore")],
    targets: [
        .executableTarget(
            name: "PersonalGuitarCoach",
            dependencies: [
                .product(name: "Domain", package: "GuitarCoachCore"),
                .product(name: "Audio", package: "GuitarCoachCore")
            ],
            path: "App",
            exclude: ["PersonalGuitarCoach.entitlements"]
        )
    ]
)
