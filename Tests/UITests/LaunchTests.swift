import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testEnglishLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        XCTAssertTrue(app.staticTexts["app.title"].waitForExistence(timeout: 10))
        let title = app.staticTexts["app.title"]
        XCTAssertTrue((title.value as? String ?? title.label).contains("Personal Guitar Coach"))
    }

    @MainActor
    func testUkrainianLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(uk)", "-AppleLocale", "uk_UA"]
        app.launch()
        XCTAssertTrue(app.staticTexts["app.title"].waitForExistence(timeout: 10))
        let title = app.staticTexts["app.title"]
        XCTAssertTrue((title.value as? String ?? title.label).contains("Персональний гітарний тренер"))
    }
}
