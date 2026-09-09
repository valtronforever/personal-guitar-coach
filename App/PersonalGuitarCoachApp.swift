import SwiftUI
import Domain

@main
struct PersonalGuitarCoachApp: App {
    private let environment = AppEnvironment()

    var body: some Scene {
        WindowGroup("app.name") {
            WelcomeView(defaultSource: environment.defaultInputSource)
        }
        .defaultSize(width: 1000, height: 700)
    }
}

/// The app's composition root. Hardware and repositories are added at this boundary.
struct AppEnvironment {
    let defaultInputSource: InputSource = .electricInterface
}
