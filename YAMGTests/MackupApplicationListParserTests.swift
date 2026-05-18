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

    func testParseAcceptsPlainApplicationRowsFromListOutput() throws {
        let output = """
        Supported applications:
        git
        raycast
        visual-studio-code

        3 applications supported in Mackup v0.10.3
        """

        let applications = try MackupApplicationListParser().parse(output)

        XCTAssertEqual(applications.map(\.name), ["git", "raycast", "visual-studio-code"])
    }

    func testParseAcceptsAsteriskBulletsAndIgnoresNoise() throws {
        let output = """
        Error: previous storage check failed
        Supported applications:
        * raycast
        See https://github.com/lra/mackup
        * zsh
        """

        let applications = try MackupApplicationListParser().parse(output)

        XCTAssertEqual(applications.map(\.name), ["raycast", "zsh"])
    }

    func testParseRejectsOutputWithoutApplicationRows() {
        XCTAssertThrowsError(try MackupApplicationListParser().parse("Supported applications:\n")) { error in
            XCTAssertEqual(error as? MackupApplicationListParserError, .noApplicationsFound)
        }
    }
}
