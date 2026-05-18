import XCTest
@testable import YAMG

final class AppSectionTests: XCTestCase {
    func testSidebarSectionsAreStable() {
        XCTAssertEqual(
            AppSection.allCases.map(\.title),
            ["Dashboard", "Applications", "Storage", "Logs", "Preferences"]
        )
    }

    func testSidebarIconsArePresent() {
        XCTAssertEqual(AppSection.dashboard.systemImageName, "rectangle.grid.2x2")
        XCTAssertEqual(AppSection.preferences.subtitle, "CLI path, config path, and UI preferences.")
    }
}
