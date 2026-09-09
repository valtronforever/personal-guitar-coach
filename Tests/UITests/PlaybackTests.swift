import XCTest

final class PlaybackTests: XCTestCase {
    @MainActor func testLessonPreviewOptionsDoNotRequireMicrophoneAccess() {
        let app = XCUIApplication()
        app.launchEnvironment["COACH_UI_TEST_STORAGE"] = UUID().uuidString
        app.launchArguments = ["-app.language", "en"]
        app.launch()
        let lesson = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Meet your open strings")).firstMatch
        XCTAssertTrue(lesson.waitForExistence(timeout: 10)); lesson.click()
        let play = app.buttons["playback.play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5)); XCTAssertFalse(play.isEnabled)
        app.buttons["playback.options"].click()
        XCTAssertTrue(app.sliders["playback.seek"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.checkBoxes["Metronome"].exists)
        XCTAssertTrue(app.checkBoxes["Loop"].exists)
    }
}
