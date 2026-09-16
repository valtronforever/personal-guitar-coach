import XCTest

final class LessonLearningModeUITests: XCTestCase {
    @MainActor func testTheoryCheckmarkSurvivesRelaunchWithoutAudioControls() {
        let app = XCUIApplication()
        app.launchEnvironment["COACH_UI_TEST_STORAGE"] = UUID().uuidString
        app.launchArguments = ["-app.language", "en"]
        app.launch()
        let search = app.textFields["lessons.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.click(); search.typeText("Before the first note")
        let lesson = app.descendants(matching: .any)["lesson.guitar-foundations"].firstMatch
        XCTAssertTrue(lesson.waitForExistence(timeout: 5)); lesson.click()
        let check = app.checkBoxes["lesson.task.setup.supported"]
        XCTAssertTrue(check.waitForExistence(timeout: 5)); check.click()
        XCTAssertEqual(check.value as? String, "1")
        XCTAssertFalse(app.buttons["playback.play"].exists)
        XCTAssertFalse(app.segmentedControls["lesson.visualMode"].exists)
        // Navigate first so the asynchronous writer can drain before terminating the app.
        app.buttons["lesson.step.check-understanding"].click()
        let wrong = app.buttons["lesson.task.string-order.thick"]
        XCTAssertTrue(wrong.waitForExistence(timeout: 5)); wrong.click()
        XCTAssertTrue(app.descendants(matching: .any)["lesson.task.feedback"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["lesson.task.retry"].click()
        app.buttons["lesson.task.string-order.thin"].click()
        XCTAssertTrue(app.buttons["lesson.task.retry"].waitForExistence(timeout: 5))
        app.terminate(); app.launch()
        let first = app.buttons["lesson.step.prepare"]
        XCTAssertTrue(first.waitForExistence(timeout: 10)); first.click()
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        XCTAssertEqual(check.value as? String, "1")
    }

    @MainActor func testListeningQuestionHidesAnswerDiagrams() {
        let app = XCUIApplication()
        app.launchEnvironment["COACH_UI_TEST_STORAGE"] = UUID().uuidString
        app.launchArguments = ["-app.language", "uk"]
        app.launch()
        let search = app.textFields["lessons.search"]
        XCTAssertTrue(search.waitForExistence(timeout: 10)); search.click(); search.typeText("Почути напрямок")
        let lesson = app.descendants(matching: .any)["lesson.hear-pitch-direction"].firstMatch
        XCTAssertTrue(lesson.waitForExistence(timeout: 5)); lesson.click()
        XCTAssertTrue(app.buttons["playback.play"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.segmentedControls["lesson.visualMode"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["lesson.variant"].firstMatch.exists)
        XCTAssertTrue(app.buttons["lesson.task.direction.higher"].exists)
        XCTAssertFalse(app.buttons["playback.options"].exists)
    }
}
