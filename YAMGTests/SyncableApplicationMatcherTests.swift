import XCTest
@testable import YAMG

final class SyncableApplicationMatcherTests: XCTestCase {
    func testIntersectsInstalledAppsWithMackupIdentifiers() {
        let installed = [
            MackupApplication(name: "raycast", displayName: "Raycast"),
            MackupApplication(name: "git", displayName: "Git"),
            MackupApplication(name: "sublime-text-3", displayName: "Sublime Text 3"),
            MackupApplication(name: "unsupported", displayName: "Unsupported App")
        ]
        let supported = ["raycast", "git", "sublime-text-3", "iterm2"]

        let matched = SyncableApplicationMatcher.intersect(
            supportedIdentifiers: supported,
            installed: installed
        )

        XCTAssertEqual(matched.map(\.identifier), ["git", "raycast", "sublime-text-3"])
        XCTAssertEqual(matched.map(\.displayName), ["Git", "Raycast", "Sublime Text 3"])
    }

    func testIntersectionPrefersInstalledDisplayName() {
        let installed = [
            MackupApplication(name: "raycast", displayName: "Raycast")
        ]
        let matched = SyncableApplicationMatcher.intersect(
            supportedIdentifiers: ["raycast"],
            installed: installed
        )

        XCTAssertEqual(matched.first?.displayName, "Raycast")
        XCTAssertEqual(matched.first?.identifier, "raycast")
    }

    func testIntersectionDeduplicatesByIdentifier() {
        let installed = [
            MackupApplication(name: "git", displayName: "Git"),
            MackupApplication(name: "git", displayName: "Git")
        ]
        let matched = SyncableApplicationMatcher.intersect(
            supportedIdentifiers: ["git"],
            installed: installed
        )

        XCTAssertEqual(matched.count, 1)
    }

    func testIntersectionReturnsEmptyWhenNoCommonApps() {
        let installed = [MackupApplication(name: "novel", displayName: "Novel")]
        let matched = SyncableApplicationMatcher.intersect(
            supportedIdentifiers: ["git"],
            installed: installed
        )

        XCTAssertTrue(matched.isEmpty)
    }

    func testIntersectionResolvesIdentifierFromDisplayNameSlug() {
        let installed = [
            MackupApplication(name: "Visual Studio Code", displayName: "Visual Studio Code")
        ]
        let matched = SyncableApplicationMatcher.intersect(
            supportedIdentifiers: ["visual-studio-code"],
            installed: installed
        )

        XCTAssertEqual(matched.first?.identifier, "visual-studio-code")
        XCTAssertEqual(matched.first?.displayName, "Visual Studio Code")
    }
}
