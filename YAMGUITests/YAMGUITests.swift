import XCTest

final class YAMGUITests: XCTestCase {
    func testAppLaunchesToDashboard() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Dashboard"].waitForExistence(timeout: 5))
    }
}
