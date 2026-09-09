import XCTest

final class LaunchTests: XCTestCase {
    @MainActor
    func testEnglishLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-app.language", "system"]
        app.launch()
        XCTAssertTrue(app.windows["Lessons"].waitForExistence(timeout: 10))
        let lesson = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Meet your open strings")).firstMatch
        XCTAssertTrue(lesson.waitForExistence(timeout: 10))
        lesson.click()
        XCTAssertTrue(app.descendants(matching: .any)["lesson.title"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testUkrainianLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(uk)", "-AppleLocale", "uk_UA", "-app.language", "system"]
        app.launch()
        XCTAssertTrue(app.windows["Уроки"].waitForExistence(timeout: 10))
        let lesson = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Познайомся з відкритими струнами")).firstMatch
        XCTAssertTrue(lesson.waitForExistence(timeout: 10))
        lesson.click()
        XCTAssertTrue(app.descendants(matching: .any)["lesson.title"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testKeyboardNavigationAndLanguagePreserveSelection() {
        let app = XCUIApplication()
        app.launchArguments = ["-app.language", "en"]
        app.launch()
        app.typeKey("4", modifierFlags: .command)
        app.typeKey(",", modifierFlags: .command)
        let general = app.toolbars.buttons["General"].firstMatch
        XCTAssertTrue(general.waitForExistence(timeout: 5))
        general.click()
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
