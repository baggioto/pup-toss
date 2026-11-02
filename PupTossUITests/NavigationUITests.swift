import XCTest

nonisolated final class NavigationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeToGameToPauseAndContinue() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let best = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Personal best'")).firstMatch
        XCTAssertTrue(best.waitForExistence(timeout: 5), "Home shows the personal best")

        app.buttons["Play"].tap()
        let pause = app.buttons["Pause"]
        XCTAssertTrue(pause.waitForExistence(timeout: 5), "Game shows the pause button")

        pause.tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 3))
        app.buttons["Resume"].tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 3), "Resume returns to the game")

        pause.tap()
        app.buttons["Home"].tap()
        // Leaving mid-round keeps it: home now offers Continue.
        XCTAssertTrue(app.buttons["Continue"].waitForExistence(timeout: 5), "Home offers Continue")
        XCTAssertTrue(best.exists)
        app.buttons["Continue"].tap()
        XCTAssertTrue(pause.waitForExistence(timeout: 5), "Continue returns to the game")
    }
}
