import XCTest
@testable import YAMG

final class MackupApplicationListParserTests: XCTestCase {
    func testParseExtractsApplicationsFromMackupListOutput() throws {
        let output = """
        Supported applications:
         - git
         - visual-studio-code
         - zsh

        3 applications supported in Mackup v0.10.3
        """

        let applications = try MackupApplicationListParser().parse(output)

        XCTAssertEqual(applications.map(\.name), ["git", "visual-studio-code", "zsh"])
    }

    func testParseSortsAndDeduplicatesApplications() throws {
        let output = """
        Supported applications:
         - zsh
         - git
         - git
         - alacritty
        """

        let applications = try MackupApplicationListParser().parse(output)

        XCTAssertEqual(applications.map(\.name), ["alacritty", "git", "zsh"])
    }

    func testParseRejectsOutputWithoutApplicationRows() {
        XCTAssertThrowsError(try MackupApplicationListParser().parse("Supported applications:\n")) { error in
            XCTAssertEqual(error as? MackupApplicationListParserError, .noApplicationsFound)
        }
    }
}
