import XCTest
@testable import YAMG

final class AppSectionTests: XCTestCase {
    func testSidebarSectionsAreStable() {
        XCTAssertEqual(
            AppSection.allCases.map(\.title),
            [
                "section.dashboard.title",
                "section.applications.title",
                "section.storage.title",
                "section.logs.title",
                "section.preferences.title"
            ]
        )
    }

    func testSidebarIconsArePresent() {
        XCTAssertEqual(AppSection.dashboard.systemImageName, "rectangle.grid.2x2")
        XCTAssertEqual(AppSection.preferences.subtitle, "section.preferences.subtitle")
    }

    func testSidebarLocalizationKeysAreStable() {
        XCTAssertEqual(AppSection.dashboard.titleKey, .dashboardTitle)
        XCTAssertEqual(AppSection.preferences.subtitleKey, .preferencesSubtitle)
    }
}
