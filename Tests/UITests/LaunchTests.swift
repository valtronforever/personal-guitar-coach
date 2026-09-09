import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testEnglishLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-app.language", "system"]
        app.launch()
        let title = app.descendants(matching: .any)["screen.title"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue((title.value as? String ?? title.label).contains("Personal Guitar Coach"))
    }

    @MainActor
    func testUkrainianLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(uk)", "-AppleLocale", "uk_UA", "-app.language", "system"]
        app.launch()
        let title = app.descendants(matching: .any)["screen.title"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue((title.value as? String ?? title.label).contains("Персональний гітарний тренер"))
    }

    @MainActor
    func testKeyboardNavigationAndLanguagePreserveSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["-app.language", "en"]
        app.launch()
        app.typeKey("4", modifierFlags: .command)
        app.typeKey(",", modifierFlags: .command)
        let language = app.popUpButtons["settings.language"]
        XCTAssertTrue(language.waitForExistence(timeout: 5))
        language.click()
        app.menuItems["Українська"].click()
        app.typeKey("w", modifierFlags: .command)
        XCTAssertTrue(app.windows["Прогрес"].waitForExistence(timeout: 5))
        let title = app.descendants(matching: .any)["screen.title"].firstMatch
        XCTAssertTrue((title.value as? String ?? title.label).contains("Твій прогрес"))
    }
}
