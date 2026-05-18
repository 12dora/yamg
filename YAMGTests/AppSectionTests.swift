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
                "section.link_mode.title",
                "section.logs.title",
                "section.preferences.title"
            ]
        )
    }

    func testSidebarIconsArePresent() {
        XCTAssertEqual(AppSection.dashboard.systemImageName, "rectangle.grid.2x2")
        XCTAssertEqual(AppSection.linkMode.systemImageName, "link.badge.plus")
        XCTAssertEqual(AppSection.preferences.subtitle, "section.preferences.subtitle")
    }

    func testSidebarLocalizationKeysAreStable() {
        XCTAssertEqual(AppSection.dashboard.titleKey, .dashboardTitle)
        XCTAssertEqual(AppSection.linkMode.titleKey, .linkModeTitle)
        XCTAssertEqual(AppSection.preferences.subtitleKey, .preferencesSubtitle)
    }

    func testVisibleSectionsHideLinkModeByDefault() {
        XCTAssertFalse(AppSection.visibleSections(showsLinkMode: false).contains(.linkMode))
        XCTAssertTrue(AppSection.visibleSections(showsLinkMode: true).contains(.linkMode))
    }
}
