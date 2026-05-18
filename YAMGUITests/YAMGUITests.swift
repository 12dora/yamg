import XCTest

final class YAMGUITests: XCTestCase {
    func testAppLaunchesToDashboard() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["section-title-dashboard"].waitForExistence(timeout: 5))
    }
}
