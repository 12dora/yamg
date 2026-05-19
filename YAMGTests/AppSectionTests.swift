import XCTest
@testable import YAMG

final class AppSectionTests: XCTestCase {
    func testSidebarSectionsAreStable() {
        XCTAssertEqual(
            AppSection.allCases.map(\.rawValue),
            [
                "dashboard",
                "applications",
                "linkMode",
                "logs",
                "preferences"
            ]
        )
    }

    func testSidebarIconsArePresent() {
        XCTAssertEqual(AppSection.dashboard.systemImageName, "rectangle.grid.2x2")
        XCTAssertEqual(AppSection.linkMode.systemImageName, "link.badge.plus")
        XCTAssertEqual(AppSection.preferences.subtitleKey, .preferencesSubtitle)
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

    func testStorageSectionIsRemoved() {
        XCTAssertFalse(AppSection.allCases.contains(where: { $0.rawValue == "storage" }))
    }
}
