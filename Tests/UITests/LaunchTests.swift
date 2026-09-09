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

    @MainActor
    func testLessonStepClearsExpectedMarkersForRest() {
        let app = XCUIApplication()
        app.launchArguments = ["-app.language", "en"]
        app.launch()
        let lesson = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Meet your open strings")).firstMatch
        XCTAssertTrue(lesson.waitForExistence(timeout: 10))
        lesson.click()
        let low = app.buttons["fretboard.string.6.fret.0"]
        XCTAssertTrue(low.waitForExistence(timeout: 5))
        XCTAssertEqual(low.value as? String, "Expected")
        app.buttons["lesson.step.leave-space"].click()
        XCTAssertEqual(low.value as? String, "Not selected")
        app.buttons["lesson.step.play-the-bar"].click()
        XCTAssertEqual(low.value as? String, "Expected")
        XCTAssertEqual(app.buttons["fretboard.string.1.fret.0"].value as? String, "Expected")
    }


    @MainActor
    func testTimelineKeyboardCrossesPageBoundary() {
        let app = XCUIApplication()
        app.launchArguments = ["-app.language", "en"]
        app.launch()
        app.menuBars.menuBarItems["Developer"].click()
        app.menuItems["Visual test fixtures · no audio"].click()
        let fixture = app.popUpButtons["debug.fixture"]
        XCTAssertTrue(fixture.waitForExistence(timeout: 5))
        fixture.click()
        app.menuItems["4/4 · 20 bars of sixteenth notes"].click()
        let jump = app.textFields["tab.jump"]
        jump.click(); jump.typeKey("a", modifierFlags: .command); jump.typeText("16")
        app.buttons["Show bar"].click()
        let last = app.buttons["tab.event.scale-255.bar.16"]
        XCTAssertTrue(last.waitForExistence(timeout: 5))
        last.click()
        app.typeKey(.rightArrow, modifierFlags: [])
        app.typeKey(" ", modifierFlags: [])
        let next = app.buttons["tab.event.scale-256.bar.17"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertEqual(next.value as? String, "Selected")
    }

}
