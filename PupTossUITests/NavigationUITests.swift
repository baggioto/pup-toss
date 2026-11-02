import XCTest

nonisolated final class NavigationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testHomeToGameToPauseAndBack() {
        let app = XCUIApplication()
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
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5), "Home is back")
        XCTAssertTrue(best.exists)
    }
}
