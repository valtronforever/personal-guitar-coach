import XCTest

final class TunerTests: XCTestCase {
    @MainActor func testDropDManualTargetAndNoInputCannotStart() {
        let app = XCUIApplication()
        app.launchEnvironment["COACH_UI_TEST_STORAGE"] = UUID().uuidString
        app.launchArguments = ["-app.language", "en"]
        app.launch(); app.typeKey("3", modifierFlags: .command)
        let profile = app.popUpButtons["tuner.profile"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        profile.click(); app.menuItems["Drop D"].click()
        app.buttons["tuner.string.6"].click()
        let target = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "D2")).firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["tuner.capture"].isEnabled)
        XCTAssertEqual(app.buttons["tuner.string.6"].value as? String, "Selected")
    }
    @MainActor func testSyntheticFixtureClearsGreenAfterSilenceInUkrainian() {
        let app = XCUIApplication()
        app.launchArguments = ["-app.language", "uk"]
        app.launch()
        app.menuBars.menuBarItems["Розробка"].click()
        app.menuItems["Тестові стани тюнера"].click()
        let picker = app.popUpButtons["debug.tunerState"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.click(); app.menuItems["Зіграй відкриту струну"].click()
        let cleared = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "—")).firstMatch
        XCTAssertTrue(cleared.waitForExistence(timeout: 5))
    }
}
